class_name Main
extends Node3D
## Chef d'orchestre : environnement (brouillard, lumière, post-traitement), qualité, construction de
## la maison, pause, chargement d'une sauvegarde (continue_game) et routage des signaux.
## Le déroulé vit ailleurs, dans des nœuds enfants qui gardent une référence vers Main :
## acte1.gd (la chambre, la séance 1, ses fins), acte2.gd (l'étage), autotest.gd (tests automatiques,
## --autotest, --preview=…, --seance=…, --charger=…).

@onready var room: Node3D = $Room
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var menu: CanvasLayer = $Menu
@onready var retro: ColorRect = $Post/Retro
@onready var world: WorldEnvironment = $WorldEnvironment

## Méta de l'Engine (survit au rechargement de la scène) : la scène neuve reprend la sauvegarde.
const CONTINUE_META := "continuer_partie"

var env: Environment
var house: House
var haunt: Haunt
var terminal: Control      # l'écran de l'ordinateur de Manon (room.terminal)
var acte1: Acte1
var acte2: Acte2
var autotest: Autotest
var build_ms := 0          # temps de construction de la maison et de cuisson de la GI de la chambre (B16)
var gi_ms := 0
## Captures des sondes de reflets en cours (une pièce après l'autre, voir _capture_reflections) ;
## « reflections_settled » quand il n'y en a plus.
signal reflections_settled
var _capture_running := false
var _capture_again := false


func _ready() -> void:
	# Game (autoload) survit au rechargement de la scène (épilogue d'une fin, fin de la 0.3.1,
	# « Continuer ») : sans remise à zéro, les drapeaux et les objets de la partie d'avant seraient
	# réappliqués au monde neuf par house.restore_all() (boîte vidée, sèche-cheveux caché, portes
	# ouvertes…), et ni « Continuer » ni « Nouvelle partie » ne pourraient les remettre. Le héros et
	# les réglages restent ; « Continuer » relit la sauvegarde sur le disque.
	Game.reset_state()
	retro.add_to_group("retro")
	# l'entité dans la maison : seul point d'entrée de ses actions (créé avant la maison, pour que
	# les appareils posés par les pièces s'enregistrent auprès de lui)
	haunt = Haunt.new()
	haunt.name = "Haunt"
	haunt.add_to_group("haunt")
	add_child(haunt)
	# la couche 11 (« flux uniquement ») n'est jamais vue par le joueur, ni l'infrarouge des captures des
	# caméras de flux (FeedCam.LAYER_IR : une lumière de cette couche n'éclaire que leur image)
	player.camera.set_cull_mask_value(Builder.LAYER_FEED_ONLY, false)
	player.camera.set_cull_mask_value(FeedCam.LAYER_IR, false)
	terminal = room.terminal
	_build_environment()
	_build_house()
	_after_build()
	_apply_quality()
	Game.settings_changed.connect(_apply_quality)
	get_tree().root.size_changed.connect(_on_window_resized)
	hud.player = player
	player.global_position = Acte1.START_POS
	player.set_look(Acte1.START_YAW, -0.05)
	player.looking_at.connect(hud.set_prompt)
	acte1 = Acte1.new()
	acte1.name = "Acte1"
	add_child(acte1)
	acte1.setup(self)
	acte2 = Acte2.new()
	acte2.name = "Acte2"
	add_child(acte2)
	acte2.setup(self)
	_route_signals()
	Sfx.loop("room_tone", -16.0)
	Game.phase = "title"
	if Game.autotest:
		autotest = Autotest.new()
		autotest.name = "Autotest"
		add_child(autotest)
		autotest.setup(self)
		autotest.run()
		return
	# banc d'essai des préréglages (« -- --banc », lot V3-ETALONNAGE) : à la place du menu
	if Banc.wanted():
		var b := Banc.new()
		b.name = "Banc"
		add_child(b)
		b.setup(self)
		b.run()
		return
	hud.fade.color.a = 0.0
	if Engine.has_meta(CONTINUE_META):
		Engine.remove_meta(CONTINUE_META)
		continue_game()
		return
	menu.show_start()


## Les signaux de la chambre, du terminal, de la maison et de l'entité vers le déroulé.
func _route_signals() -> void:
	room.floppy_taken.connect(acte1._on_floppy_taken)
	room.pc_used.connect(acte1._on_pc_used)
	room.key_taken.connect(acte1._on_key_taken)
	room.pc_answered.connect(acte2._on_pc_answered)
	terminal.event.connect(acte1._on_term_event)
	terminal.ended.connect(acte1._on_seance_end)
	terminal.ended.connect(acte2.on_seance_end)     # (« fin_v03 » : la fin de la version)
	terminal.fear_changed.connect(_on_fear)      # (le terminal suit Game.peur, séance ou pas)
	house.entered_room.connect(acte2.on_room_entered)
	house.door_tried.connect(acte2.on_door_tried)
	house.door_opened.connect(acte2.on_door_opened)
	haunt.story.connect(acte2.on_story)
	Game.absorbed.connect(acte2.on_absorbed)
	menu.start_requested.connect(start_game)
	menu.continue_requested.connect(continue_game)
	menu.resume_requested.connect(resume)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/sky/moonless_golf_1k.hdr")
	pano.energy_multiplier = 0.22
	sky.sky_material = pano
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.07, 0.075, 0.1)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.glow_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_albedo = Color(0.72, 0.76, 0.85)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 14.0
	env.ssao_enabled = true
	env.adjustment_enabled = true
	world.environment = env
	# étalonnage (LUT 32³, rendu net sur vraie carte seulement ; lot V3-ETALONNAGE) : calculée une fois, hors
	# du chrono de B16 ; le filtre la lit quand lut_mix > 0 (jamais en rétro ni en rendu logiciel)
	var m := retro_mat()
	if m and not Qualite.soft():
		var t0 := Time.get_ticks_usec()
		m.set_shader_parameter("lut", lut_texture())
		m.set_shader_parameter("lut_size", float(LUT_SIZE))
		print("LUT %d³ calculée en %.1f ms" % [LUT_SIZE, (Time.get_ticks_usec() - t0) / 1000.0])


## Le premier étage autour de la chambre (couloir, salle de bain, lingerie, bureau, chambre d'amis…),
## l'éclairage indirect de chaque pièce (cuit au lancement, la lumière reste dynamique), puis l'état
## des pièces (restore_all : rien à faire pour une nouvelle partie).
func _build_house() -> void:
	var t0 := Time.get_ticks_msec()
	house = House.new()
	house.name = "House"
	add_child(house)
	house.build(room)
	for id in house.rooms:
		if id != "mere":
			(house.rooms[id] as HouseRoom).bake_gi()
	house.finish(player)
	build_ms = Time.get_ticks_msec() - t0
	print("maison construite en %d ms" % build_ms)
	# la chambre de ta mère : une pièce comme les autres, avec une GI plus fine (écran, lampadaire,
	# éclairs, lampe de poche)
	var t1 := Time.get_ticks_msec()
	(room as HouseRoom).bake_gi(VoxelGI.SUBDIV_128)
	gi_ms = Time.get_ticks_msec() - t1
	print("VoxelGI cuit en %d ms" % gi_ms)
	house.restore_all()


## Crochet de fin de construction (passe « triple A »), juste après _build_house : hors du chrono de
## B16 (build_ms, gi_ms), avant le réglage de l'image et l'autotest.
##  - avec une vraie carte graphique (Qualite.details_on()) : la sonde de reflets de chaque pièce
##    (prepare_reflections, capturée plus tard, voir _capture_reflections), puis ses objets de décor
##    (dress_details, Builder.detail) ; la chambre de la mère comprise ; puis Surfaces.after_build
##    (chemins d'usure des moquettes) ;
##  - dans tous les cas : le groupe « apres_maison » reçoit on_house_built(main).
func _after_build() -> void:
	# (premier lancement : la détection de la carte, refaite ici si l'autoload l'a faite trop tôt)
	if Game.quality_auto:
		Game.quality = Qualite.detect()
	if Qualite.details_on():
		var t0 := Time.get_ticks_msec()
		for id in house.rooms:
			var r: HouseRoom = house.rooms[id]
			r.prepare_reflections()
			r.dress_details()
		# la lampe de poche (et ce qui suit le joueur) n'apparaît jamais dans les reflets figés
		Qualite.hide_from_probes(player.flashlight)
		# (chemins d'usure des moquettes, posés par les pièces : teinte et mélange des poils tassés)
		Surfaces.after_build(get_tree())
		print("détails et sondes posés en %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().call_group("apres_maison", "on_house_built", self)


## Préréglage d'image (Qualite) puis aspect du rendu (_apply_video), et sondes de reflets. Appelé au
## lancement et à chaque changement de réglage (Game.settings_changed).
func _apply_quality() -> void:
	Qualite.apply(self)
	_apply_video()
	_update_reflections()


## La fenêtre change de taille : l'échelle de FSR 2 (Ultra) suit sa hauteur.
func _on_window_resized() -> void:
	if Qualite.effective() == Qualite.ULTRA and not Game.style_retro:
		Qualite.apply(self)


## Aspect du rendu net (par défaut) ou du « Style rétro (pixels) » (Game.style_retro) : courbe, halo,
## filtre plein écran. Le niveau de qualité (résolution de la 3D, anticrénelage, GI, brouillard, SSAO,
## ombres, reflets) est réglé par Qualite.apply, appelé juste avant.
##  - net : la 3D est calculée à la résolution de la fenêtre (étirement « canvas_items » : l'interface,
##    pensée en 640×360, est agrandie sans perdre sa mise en page), AgX (blanc à 6 : les ampoules et
##    les reflets atteignent le blanc), SSAO, halo des ampoules et des écrans, brouillard volumétrique
##    discret, filtre « pellicule » léger, pied de courbe réglé par la « Luminosité » ;
##  - rétro : l'image d'avant, exactement (640×360 agrandie sans lissage, ACES, palette de 16 niveaux
##    et tramage de Bayer, aberration chromatique).
## Énergies des lumières : les mêmes dans les deux modes (l'exposition d'AgX compense ACES).
## Nuit, halo et aberration du rendu net (lot V2-NUIT) : sur vraie carte seulement (FULL_* ci-dessous) ;
## le rendu logiciel (profil des tests) garde les réglages d'avant (valeurs en dur, FLASH_GI_SOFT), le
## rétro les siens.
func _apply_video() -> void:
	var retro_on := Game.style_retro
	var full := not Qualite.soft()
	if retro_on:
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.05
		env.glow_intensity = 0.7
		env.glow_strength = 1.0
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 0.9
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		for i in 7:
			env.set_glow_level(i, [0.0, 0.8, 0.4, 0.1, 0.0, 0.0, 0.0][i])
		env.volumetric_fog_density = 0.028
		# (valeur par défaut de Godot, celle d'avant : remise si l'on revient du rendu net)
		env.volumetric_fog_gi_inject = 1.0
		env.ssao_radius = 0.9
		env.ssao_intensity = 1.8
		env.ssao_power = 1.5
		env.ssao_detail = 0.5
		env.ssao_light_affect = 0.0
		env.ssil_enabled = false
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 0.82
		env.ambient_light_energy = 0.5
	else:
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = agx_exposure()
		# (blanc et contraste d'AgX : voir AGX_WHITE, AGX_CONTRAST)
		env.tonemap_agx_white = AGX_WHITE
		env.tonemap_agx_contrast = AGX_CONTRAST
		# halo : vraie carte, seuil plus haut et petits rayons seulement (FULL_GLOW_*) ; rendu logiciel,
		# celui d'avant
		env.glow_intensity = FULL_GLOW_INTENSITY if full else 0.55
		env.glow_strength = 1.0
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = FULL_GLOW_THRESHOLD if full else 1.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		var levels: Array = FULL_GLOW_LEVELS if full else [0.0, 0.5, 0.7, 0.5, 0.25, 0.0, 0.0]
		for i in 7:
			env.set_glow_level(i, levels[i])
		env.volumetric_fog_density = 0.018
		# (ce que le brouillard reprend de la VoxelGI : voir FULL_FOG_GI_INJECT)
		env.volumetric_fog_gi_inject = fog_gi_inject() if full else 1.0
		env.ssao_radius = 0.7
		env.ssao_intensity = 1.6
		env.ssao_power = 1.6
		env.ssao_detail = 0.6
		env.ssao_light_affect = 0.15
		# (pas de SSIL : la VoxelGI des pièces fait déjà rebondir la lumière ; le SSIL coûtait ~7 % de
		# l'image en rendu logiciel pour un gain à peine visible ; Ultra sur vraie carte : Qualite.ssil_on)
		env.ssil_enabled = Qualite.ssil_on()
		if env.ssil_enabled:
			env.ssil_radius = Qualite.SSIL_RADIUS
			env.ssil_intensity = tune("ssil_k", Qualite.SSIL_INTENSITY)
			env.ssil_sharpness = Qualite.SSIL_SHARPNESS
		# (contraste porté par AgX : celui de l'environnement, appliqué après la courbe, mettait à 0 tout ce
		# qui sortait sous 17/255 ; les nuits étaient noires à 35-50 % de pixels nuls)
		env.adjustment_contrast = 1.0
		# (vraie carte : la saturation passe dans la LUT d'étalonnage)
		env.adjustment_saturation = 1.0 if lut_on() else 0.9
		# (lumière ambiante plus basse qu'en rétro : les ombres viennent des lampes ; la nuit, de la
		# lampe de poche et de la lune)
		env.ambient_light_energy = tune("ambiant", NET_AMBIENT) if full else NET_AMBIENT
	# lampe de poche : point chaud, anneau du réflecteur et halo (rendu net seulement ; vraie carte : le
	# masque de l'étalonnage final) ; son rebond dans la VoxelGI de la pièce (rendu net : la nuit, on lit les
	# volumes autour du faisceau)
	var cookie: Texture2D = FLASH_COOKIE
	if full and tune("cookie", 1.0) > 0.5:
		cookie = flash_cookie_net()
	player.flashlight.light_projector = null if retro_on else cookie
	if _flash_spec0 < 0.0:
		_flash_spec0 = player.flashlight.light_specular
	player.flashlight.light_specular = player.FLASH_SPECULAR_NET if full and not retro_on else _flash_spec0
	player.flashlight.light_indirect_energy = 1.0 if retro_on else (flash_gi_net() if full else FLASH_GI_SOFT)
	# lune de la chambre de ta mère (vraie carte, hors rétro : MERE_MOON_*)
	var mn := room.get("moon") as SpotLight3D
	if mn:
		mn.light_energy = tune("lune_mere", MERE_MOON_NET) if full and not retro_on else 3.0
		mn.light_volumetric_fog_energy = tune("lune_mere_fog", MERE_MOON_FOG_NET) if full and not retro_on else 1.0
	_apply_auto_exposure(full and not retro_on)
	if room.has_method("set_screen_glow_style"):
		room.set_screen_glow_style(retro_on)
	var m := retro_mat()
	if m:
		m.set_shader_parameter("levels", 16.0 if retro_on else 0.0)
		m.set_shader_parameter("dither_strength", 1.0 if retro_on else 0.0)
		m.set_shader_parameter("grain_mult", 1.0 if retro_on else 0.8)
		m.set_shader_parameter("vignette", 0.85 if retro_on else NET_VIGNETTE)
		m.set_shader_parameter("vignette_inner", 0.12 if retro_on else NET_VIGNETTE_INNER)
		# aberration chromatique : rétro, celle d'avant ; rendu net sur vraie carte, aucune au repos, elle ne
		# vient qu'avec la peur (corruption au-dessus de FULL_ABERRATION_FLOOR, montée quadratique) ;
		# rendu logiciel, celle d'avant
		m.set_shader_parameter("aberration", 0.0011 if retro_on else (0.0 if full else 0.00015))
		m.set_shader_parameter("corruption_floor", FULL_ABERRATION_FLOOR if full and not retro_on else 0.0)
		# rendu net : noir ramené à 0 (AgX et le brouillard relèvent le noir), pied de courbe réglé par
		# la « Luminosité » (Game.luminosite), grain de pellicule
		var c := net_curve(Game.luminosite)
		m.set_shader_parameter("black_point", 0.0 if retro_on else c.x)
		m.set_shader_parameter("white_point", 1.0 if retro_on else NET_WHITE_POINT)
		m.set_shader_parameter("shoulder_knee", NET_SHOULDER_KNEE)
		m.set_shader_parameter("toe", 0.0 if retro_on else c.y)
		m.set_shader_parameter("grain_net", 0.0 if retro_on else 1.0)
		# LUT d'étalonnage : rendu net sur vraie carte seulement (0 en rétro et en rendu logiciel)
		if lut_on():
			m.set_shader_parameter("lut", lut_texture())
		m.set_shader_parameter("lut_mix", 1.0 if lut_on() else 0.0)


## La LUT d'étalonnage s'applique : rendu net sur vraie carte (« -- --tune=lut:0 » la coupe).
static func lut_on() -> bool:
	return Qualite.extras_on() and tune("lut", 1.0) > 0.5


## Exposition automatique bornée (voir AUTO_EXPO_*) : sur la caméra du joueur (pas sur l'environnement,
## que partagent les caméras de flux), dès Moyenne, rendu net sur vraie carte, hors autotest (sauf
## « -- --tune=expo_auto:1 »). Bornes : la luminance mesurée est ramenée dans [s, s × 2^-AUTO_EXPO_MIN_EV] ;
## sous le seuil s, le facteur vaut 1 (jamais d'éclaircissement).
func _apply_auto_exposure(net: bool) -> void:
	var on := net and Qualite.at_least(Qualite.MOYENNE) and tune("expo_auto", 0.0 if Game.autotest else 1.0) > 0.5
	if not on:
		if player.camera.attributes == _cam_attr:
			player.camera.attributes = null
		return
	if _cam_attr == null:
		_cam_attr = CameraAttributesPractical.new()
		_cam_attr.resource_name = "exposition_bornee"
		var o: Node = room.get("outside")
		if o and o.has_signal("lightning_struck"):
			o.connect("lightning_struck", _on_lightning)
	var s := tune("expo_seuil", AUTO_EXPO_SCALE)
	_cam_attr.auto_exposure_enabled = true
	_cam_attr.auto_exposure_scale = s
	_cam_attr.auto_exposure_min_sensitivity = s / ISO_TO_LUM
	_cam_attr.auto_exposure_max_sensitivity = s * pow(2.0, -AUTO_EXPO_MIN_EV) / ISO_TO_LUM
	_cam_attr.auto_exposure_speed = AUTO_EXPO_SPEED
	player.camera.attributes = _cam_attr


## Un éclair : l'exposition s'adapte plus vite pendant AUTO_EXPO_BOOST_S (l'œil ébloui), puis revient.
func _on_lightning() -> void:
	if _cam_attr == null or player.camera.attributes != _cam_attr:
		return
	_cam_attr.auto_exposure_speed = AUTO_EXPO_SPEED_BOLT
	var my := Time.get_ticks_msec() + int(AUTO_EXPO_BOOST_S * 1000.0)
	_expo_boost_until = my
	await get_tree().create_timer(AUTO_EXPO_BOOST_S + 0.4, false).timeout
	if _expo_boost_until == my and _cam_attr:
		_cam_attr.auto_exposure_speed = AUTO_EXPO_SPEED


## Courbe du rendu net (passe « triple A »), calée sur les aperçus des pièces (captures « --etalonnage »
## rejouées hors du jeu avec la courbe d'AgX de Godot 4.7.2, mesurée puis réécrite à l'identique :
## aaa_fab/V1-RENDU/outils) : médiane de 55 à 85/255 dans les pièces éclairées et 99,9e centile ≥ 240
## (avant : 190 à 215, l'image paraissait grise), nuits moins bouchées.
## Exposition d'AgX : les énergies des lumières sont celles du style rétro (ACES, exposition 1,05 ;
## l'ACES de Godot multiplie l'image par 1,8 avant la courbe, AgX non).
const AGX_EXPOSURE := 1.3
## Blanc d'AgX (16,29 par défaut) : il ne joue qu'au-dessus de 1 (mesuré : 0,18 donne 118/255 et 1,0
## donne 203 à 210, quel que soit le blanc) ; à 3, les ampoules, les écrans et les éclairs saturent au blanc.
const AGX_WHITE := 3.0
## Contraste d'AgX (pied de la courbe, sans rien écrêter). Il remplace le contraste de l'environnement
## (1,15), qui, appliqué après la courbe, mettait à 0 tout ce qui sortait d'AgX sous 17/255.
const AGX_CONTRAST := 1.35
## Épaule du filtre plein écran : la valeur NET_WHITE_POINT devient le blanc, l'étirement commence au
## genou et se raccorde sans cassure (les tons moyens ne bougent pas) : les hautes lumières d'AgX, qui
## plafonnent vers 0,7-0,8 dans les pièces (une lampe de 1 m de rayon ne dépasse guère 0,7 en linéaire),
## montent au blanc.
const NET_WHITE_POINT := 0.74
const NET_SHOULDER_KNEE := 0.45
## Vignettage du rendu net : plus léger et plus tardif qu'avant (0,55 dès un quart de l'écran assombrissait
## le plafond et les coins de 20 à 55 %) ; le rétro garde le sien (0,85).
const NET_VIGNETTE := 0.35
const NET_VIGNETTE_INNER := 0.25
## Pied de courbe du rendu net (retro_post.gdshader) à la luminosité par défaut (0,5) : noir ramené à 0
## (le brouillard relève le noir) et basses lumières enfoncées, sans boucher les nuits (on lit les
## volumes à la lampe sans y voir clair).
const NET_BLACK_POINT := 0.008
## Vraie carte (lot V2-NUIT) : point noir moitié moins fort. Avec la lampe qui découvre et le halo resserré,
## 0,008 écrasait à 0 les ombres de la nuit (23 à 45 % de pixels nuls) ; à 0,004, elles gardent leurs
## dégradés (le pied de courbe, lui, ne change pas).
const FULL_BLACK_POINT := 0.004
const NET_TOE := 0.06
## « Luminosité » de 0 à 1 : le point noir bouge de ±0,01 et le pied de courbe de ±0,06 autour du défaut
## (de 0,018 et 0,12, sombre, à 0 et 0, clair).
const LUMINOSITE_BLACK := 0.02
const LUMINOSITE_TOE := 0.12
## Lumière ambiante du rendu net (le rétro garde 0,5).
const NET_AMBIENT := 0.22
const FLASH_COOKIE := preload("res://assets/textures/flashlight_cookie.png")
## Énergie indirecte de la lampe de poche (rendu net ; 1 en rétro) : ce qu'elle fait rebondir dans la
## VoxelGI de la pièce. À 1, tout ce qui sortait du faisceau restait à 0 (35 à 80 % de l'image la nuit) ;
## à 6 (étalonnage de la vague 1, gardé en rendu logiciel), la pièce entière se lisait autour du faisceau
## et la lampe ne révélait plus rien (médiane de nuit 13 à 33/255). Vraie carte (lot V2-NUIT) : le
## faisceau découvre, le reste de la pièce se devine à peine. Étalonnage final (V3-ETALONNAGE) : à 3, le
## rebond remplissait encore la pièce (couloir de 27 à 16 sans lui, salle de bain de 34 à 19) ; avec le
## masque et le débordement resserrés, à 2 le rebond fait un halo autour du rond et les volumes de la pièce
## se devinent (médianes de nuit 4 à 10/255 dans les chambres).
const FLASH_GI_NET := 2.0
const FLASH_GI_SOFT := 6.0
## Brouillard volumétrique, rendu net sur vraie carte : part de la VoxelGI qu'il diffuse (1 par défaut).
## Avec FLASH_GI_NET, il fait le fond de la nuit (le produit des deux : 6 avant, 3 ici). Le voile gris de
## la vague 2 venait surtout du halo (FULL_GLOW_*) : une fois le halo resserré, une injection de 0,3 à 0,6
## renvoyait les pièces à moquette dans le noir bouché de la 0.3.3 (médiane 0,2 à 3/255, jusqu'à 61 % de
## pixels nuls) ; à 1, les formes (bâche, lampadaire, étagères) se devinent autour du faisceau.
const FULL_FOG_GI_INJECT := 1.0
## Halo du rendu net sur vraie carte : seuil au-dessus des papiers et des murs pris dans le faisceau, et
## petits rayons seulement (les niveaux 3 à 5 faisaient un voile de 250 px autour des appliques).
const FULL_GLOW_THRESHOLD := 1.3
const FULL_GLOW_INTENSITY := 0.45
const FULL_GLOW_LEVELS := [0.0, 0.6, 0.45, 0.15, 0.0, 0.0, 0.0]
## Aberration chromatique du rendu net sur vraie carte : seulement au-dessus de cette corruption (la peur),
## en montée quadratique (retro_post.gdshader, corruption_floor).
const FULL_ABERRATION_FLOOR := 0.2
## Étalonnage final (lot V3-ETALONNAGE), rendu net sur vraie carte (le rendu logiciel et le rétro gardent
## leur image, voir FLASH_GI_SOFT et FLASH_COOKIE) :
##  - LUT 32³ calculée en code (lut_texture, _grade), appliquée par le filtre plein écran après la courbe :
##    saturation d'avant (LUT_SATURATION, l'ancien adjustment_saturation), −30 % dans les ombres, ombres un
##    peu froides et hautes lumières un peu ambrées (teintes multiplicatives : le noir reste noir), courbe
##    en S de 12 % sur la luminance autour de LUT_PIVOT (les tons moyens du jour ne bougent presque pas,
##    les nuits s'enfoncent) ;
##  - masque de la lampe de poche (flash_cookie_net) : point chaud de ~9°, anneau sombre du réflecteur,
##    couronne à −1,3 IL jusqu'à ~22°, bord net ; légères irrégularités du réflecteur ;
##  - exposition automatique BORNÉE (camera_attributes) : elle n'éclaircit jamais (la nuit reste celle de
##    l'étalonnage) ; elle assombrit jusqu'à AUTO_EXPO_MIN_EV quand l'image dépasse AUTO_EXPO_SCALE (éclair,
##    lampe dans les yeux), puis revient lentement (l'œil ébloui par l'éclair : le noir est plus noir juste
##    après). Dès Moyenne, jamais en rétro, en rendu logiciel ni dans les autotests (captures stables).
const LUT_SIZE := 32
const LUT_SATURATION := 0.9
const LUT_SHADOW_DESAT := 0.3
const LUT_SHADOW_TINT := Vector3(0.97, 0.995, 1.045)
const LUT_HIGH_TINT := Vector3(1.035, 1.0, 0.93)
const LUT_S := 0.12
const LUT_PIVOT := 0.3
const LUMA := Vector3(0.2126, 0.7152, 0.0722)
## Masque de la lampe (rendu net, vraie carte) : taille (px) ; rayons relatifs au cône (tan θ / tan 27°).
const COOKIE_NET_SIZE := 192
const COOKIE_CORONA := 0.42
## Exposition automatique : seuil (moyenne de max(r, g, b) du tampon HDR avant exposition, ce que mesure
## Godot ; estimée sur les captures : pièces et nuits de 0,02 à 0,3, éclairs 0,6 à 1+), assombrissement
## maximal (IL), vitesses (normale, après un éclair pendant AUTO_EXPO_BOOST_S).
const AUTO_EXPO_SCALE := 0.4
const AUTO_EXPO_MIN_EV := -1.5
const AUTO_EXPO_SPEED := 0.5
const AUTO_EXPO_SPEED_BOLT := 2.5
const AUTO_EXPO_BOOST_S := 1.0
## Sensibilité (ISO) -> luminance de l'exposition automatique de Godot (CameraAttributesPractical :
## 12,5 / 100 / sensibilité d'exposition, 100 par défaut).
const ISO_TO_LUM := 12.5 / 100.0 / 100.0
## Lune de la chambre de ta mère (room.moon), rendu net sur vraie carte : moins forte et presque hors du
## brouillard (la revue voyait une colonne de brume bleue sous la tringle) ; rétro et logiciel : 3 et 1.
const MERE_MOON_NET := 2.4
const MERE_MOON_FOG_NET := 0.25
## Profondeur de champ contextuelle (même CameraAttributesPractical, donc dès Moyenne, vraie carte, hors rétro
## et hors autotest) : assis face à l'écran (Game.phase « seated » et player.turned_away() < DOF_SEATED_TURN),
## le fond de la pièce derrière l'écran se floute ; document ouvert (hud.paper_open), toute la pièce. Fondu
## de DOF_FADE_S ; coupée dès qu'on se retourne. (La pause floutée est celle du menu, lot V3-INTERFACE.)
const DOF_SEATED_TURN := 0.5
const DOF_SEATED := Vector3(1.2, 1.2, 0.05)     # distance, transition (m), force
const DOF_PAPER := Vector3(0.4, 0.8, 0.09)
const DOF_FADE_S := 0.35
var _cam_attr: CameraAttributesPractical
var _expo_boost_until := 0
var _dof_k := 0.0
var _flash_spec0 := -1.0
var _dof_kind := Vector3.ZERO
static var _lut: ImageTexture3D
static var _lut_identity := false
static var _cookie_net: ImageTexture
static var _cookie_corona := -1.0

## Réglages d'étalonnage surchargés : « -- --tune=clé:valeur,clé:valeur » (lus une fois) et Main.tunes,
## modifiable à chaud (autotest « --etal » : plusieurs variantes dans un même lancement, appliquées par
## Game.settings_changed). Clés lues par Main.tune(clé, défaut) dans les scripts du lot V3-ETALONNAGE
## (liste dans l'API du lot) ; sans surcharge, la constante.
static var tunes := {}
static var _tunes_cmd := {}
static var _tunes_read := false


static func tune(key: String, fallback: float) -> float:
	if tunes.has(key):
		return float(tunes[key])
	if not _tunes_read:
		_tunes_read = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--tune="):
				for kv in a.substr(7).split(",", false):
					var p := kv.split(":")
					if p.size() == 2:
						_tunes_cmd[p[0].strip_edges()] = float(p[1])
	return float(_tunes_cmd.get(key, fallback))


## La LUT d'étalonnage (32³, RGBA8), calculée une fois ; « -- --tune=lut:2 » : la LUT identité (contrôle).
static func lut_texture() -> ImageTexture3D:
	var ident := tune("lut", 1.0) > 1.5
	if _lut == null or _lut_identity != ident:
		_lut_identity = ident
		var n := LUT_SIZE
		var imgs: Array[Image] = []
		for b in n:
			var data := PackedByteArray()
			data.resize(n * n * 4)
			var i := 0
			for g in n:
				for r in n:
					var c := Vector3(r, g, b) / float(n - 1)
					if not ident:
						c = _grade(c)
					data[i] = clampi(roundi(c.x * 255.0), 0, 255)
					data[i + 1] = clampi(roundi(c.y * 255.0), 0, 255)
					data[i + 2] = clampi(roundi(c.z * 255.0), 0, 255)
					data[i + 3] = 255
					i += 4
			imgs.append(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data))
		_lut = ImageTexture3D.new()
		_lut.create(Image.FORMAT_RGBA8, n, n, n, false, imgs)
	return _lut


## L'étalonnage d'une couleur affichée (0..1) : voir LUT_*.
static func _grade(c: Vector3) -> Vector3:
	var y := c.dot(LUMA)
	var ws := 1.0 - smoothstep(0.02, 0.35, y)
	var wh := smoothstep(0.55, 1.0, y)
	var sat := LUT_SATURATION * (1.0 - LUT_SHADOW_DESAT * ws)
	c = Vector3(y, y, y).lerp(c, sat)
	c *= Vector3.ONE.lerp(LUT_SHADOW_TINT, ws)
	c *= Vector3.ONE.lerp(LUT_HIGH_TINT, wh)
	var y2 := c.dot(LUMA)
	if y2 > 0.0001:
		var s: float
		if y2 < LUT_PIVOT:
			s = LUT_PIVOT * pow(y2 / LUT_PIVOT, 1.5)
		else:
			s = 1.0 - (1.0 - LUT_PIVOT) * pow(maxf(1.0 - y2, 0.0) / (1.0 - LUT_PIVOT), 1.5)
		c *= (y2 + LUT_S * (s - y2)) / y2
	return c.clamp(Vector3.ZERO, Vector3.ONE)


## Masque de la lampe de poche en rendu net sur vraie carte (le rendu logiciel garde FLASH_COOKIE) : profil
## radial (r = tan θ / tan 27°) : point chaud plein jusqu'à 0,24 (~7°), épaule jusqu'à 0,34 (~10°), anneau
## sombre du réflecteur vers 0,40, couronne de 0,42 à 0,34 (−1,3 à −1,6 IL) jusqu'à 0,80 (~22°), bord net en 0,05 ;
## 6 facettes du réflecteur (±4 %) et un point chaud un peu décentré.
static func flash_cookie_net() -> Texture2D:
	var cor := tune("couronne", COOKIE_CORONA)
	if _cookie_net == null or not is_equal_approx(cor, _cookie_corona):
		_cookie_corona = cor
		var n := COOKIE_NET_SIZE
		var prof := PackedFloat32Array()
		prof.resize(512)
		for i in 512:
			prof[i] = _cookie_profile(i / 511.0, cor)
		var data := PackedByteArray()
		data.resize(n * n * 4)
		var k := 0
		for y in n:
			var dy := (y + 0.5) / n * 2.0 - 1.0
			for x in n:
				var dx := (x + 0.5) / n * 2.0 - 1.0
				var r := sqrt(dx * dx + dy * dy)
				var v := 0.0
				if r < 1.0:
					v = prof[mini(int(r * 511.0), 511)]
					var a := atan2(dy, dx)
					# facettes du réflecteur dans la couronne, point chaud décalé de 2 % vers le haut à gauche
					v *= 1.0 + 0.04 * sin(6.0 * a + 9.0 * r) * smoothstep(0.3, 0.55, r)
					var hx := dx + 0.02
					var hy := dy + 0.015
					v += 0.06 * exp(-(hx * hx + hy * hy) / 0.006)
				var b := clampi(roundi(clampf(v, 0.0, 1.0) * 255.0), 0, 255)
				data[k] = b
				data[k + 1] = b
				data[k + 2] = b
				data[k + 3] = 255
				k += 4
		var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
		img.generate_mipmaps()
		_cookie_net = ImageTexture.create_from_image(img)
	return _cookie_net


static func _cookie_profile(r: float, cor := COOKIE_CORONA) -> float:
	var hot := 1.0 - 0.55 * smoothstep(0.24, 0.34, r)
	var corona := lerpf(cor, cor * 0.8, smoothstep(0.45, 0.8, r))
	var v := hot if r < 0.34 else lerpf(hot, corona, smoothstep(0.34, 0.45, r))
	v *= 1.0 - 0.2 * exp(-pow((r - 0.40) / 0.035, 2.0))
	return v * (1.0 - smoothstep(0.80, 0.85, r))


## « -- --expo=1.4 » : exposition d'AgX imposée (étalonnage ; rendu net seulement).
static var _expo_arg := -2.0
## Réglages imposés pour l'étalonnage (rendu net, vraie carte) : « -- --flash-gi=2.5 » (énergie
## indirecte de la lampe), « -- --fog-gi=0.8 » (injection de la VoxelGI dans le brouillard).
static var _cmd_floats := {}


static func agx_exposure() -> float:
	if _expo_arg < -1.0:
		_expo_arg = -1.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--expo="):
				_expo_arg = float(a.substr(7))
	return _expo_arg if _expo_arg > 0.0 else AGX_EXPOSURE


## Énergie indirecte de la lampe de poche en rendu net sur vraie carte (FLASH_GI_NET, ou « --flash-gi= »).
static func flash_gi_net() -> float:
	return tune("flash_gi", _cmd_float("--flash-gi=", FLASH_GI_NET))


## Injection de la VoxelGI dans le brouillard, rendu net sur vraie carte (FULL_FOG_GI_INJECT, ou « --fog-gi= »).
static func fog_gi_inject() -> float:
	return _cmd_float("--fog-gi=", FULL_FOG_GI_INJECT)


## Valeur « -- <prefixe><nombre> » de la ligne de commande (lue une fois), sinon fallback.
static func _cmd_float(prefix: String, fallback: float) -> float:
	if not _cmd_floats.has(prefix):
		_cmd_floats[prefix] = -1.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with(prefix):
				_cmd_floats[prefix] = float(a.substr(prefix.length()))
	var v: float = _cmd_floats[prefix]
	return v if v >= 0.0 else fallback


## Point noir (x) et pied de courbe (y) du rendu net pour une « Luminosité » de 0 (sombre) à 1 (clair).
static func net_curve(luminosite: float) -> Vector2:
	var d := 0.5 - clampf(luminosite, 0.0, 1.0)
	var bp := NET_BLACK_POINT if Qualite.soft() else FULL_BLACK_POINT
	return Vector2(maxf(bp + d * LUMINOSITE_BLACK, 0.0), maxf(NET_TOE + d * LUMINOSITE_TOE, 0.0))


## Ce que le filtre plein écran fait d'une valeur v (0..1, après AgX) avec ce point noir et ce pied de
## courbe : la mire de la « Luminosité » (menu) s'en sert pour montrer ce que verra le joueur.
static func net_display(v: float, curve: Vector2) -> float:
	var c := maxf(v - curve.x, 0.0) / (1.0 - curve.x)
	return c * (1.0 - curve.y * (1.0 - clampf(c / 0.25, 0.0, 1.0)))


## Rendu logiciel (pas de carte graphique : llvmpipe/lavapipe de Mesa, SwiftShader, pilote de rendu de
## base de Windows) : chaque passe plein écran et chaque lecture de texture coûtent cher au processeur.
## Le rendu net s'y passe d'anticrénelage et de filtrage anisotrope, et calcule l'éclairage indirect à
## demi-résolution ; le niveau de qualité y est plafonné à Élevée et les nouveautés de la passe « triple
## A » (reflets, objets de détail…) y sont coupées (Qualite). (Les autotests tournent ainsi : leurs
## minuteries suivent la durée des images. « -- --rendu-complet » garde les réglages d'une vraie carte
## graphique, pour les captures de revue.) Sans affichage (--headless, bancs sans rendu) : profil
## logiciel aussi, quoi qu'il arrive. Un banc peut imposer le profil : Main._soft = 1 (ou 0).
static var _soft := -1


static func software_renderer() -> bool:
	if _soft < 0:
		var n := RenderingServer.get_video_adapter_name().to_lower()
		_soft = 0
		if DisplayServer.get_name() == "headless":
			_soft = 1
		elif not OS.get_cmdline_user_args().has("--rendu-complet"):
			for k in ["llvmpipe", "lavapipe", "swiftshader", "basic render"]:
				if n.contains(k):
					_soft = 1
	return _soft == 1


## La matière du filtre plein écran (Post/Retro).
func retro_mat() -> ShaderMaterial:
	return retro.material as ShaderMaterial if retro else null


func _on_fear(v: float) -> void:
	# la peur déteint sur l'image : grain et aberration montent avec la jauge
	retro.material.set_shader_parameter("corruption", clampf((v - 30.0) / 140.0, 0.0, 0.5))


# ------------------------------------------------------------------ partie

## « Nouvelle partie » (héros choisi) : la sauvegarde à un emplacement est abandonnée. Sinon, une
## nouvelle partie finie dès l'acte I (TRANSMISSION, ABSORBÉ) laisserait « Continuer » recharger
## l'ancienne, peut-être avec l'autre héros.
func start_game() -> void:
	Game.delete_save()
	menu.hide_all()
	acte1.start()


## « Continuer » : reprend au dernier point de passage. Le monde est construit par _ready() (scène
## neuve) ; on charge la sauvegarde (Game.load_checkpoint), on l'applique, puis Acte1.restore(),
## Acte2.restore() et House.restore_all(), et on place le joueur (position, lacet).
## Appelée sur une scène déjà jouée, elle recharge d'abord la scène.
func continue_game() -> void:
	if Game.phase != "title":
		Engine.set_meta(CONTINUE_META, true)
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	var d := Game.load_checkpoint()
	if d.is_empty():
		menu.show_title()
		return
	menu.hide_all()
	Game.reset_state()
	Game.apply_checkpoint(d)
	if player.seated:
		player.stand(d.pos, float(d.yaw))     # (autotest : la scène n'est pas rechargée après la fin)
	acte1.restore()
	acte2.restore()
	house.restore_all()
	player.global_position = d.pos
	player.set_look(float(d.yaw), 0.0)
	player.head.position.y = player.EYE
	player.can_move = true
	player.can_look = true
	Game.phase = "room"
	if not Game.autotest:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.fade.color.a = 1.0
	print("REPRISE %s · peur %.1f · %d objets" % [d.get("checkpoint", "?"), Game.peur, Game.items.size()])
	# (vraie carte : les sondes de reflets se capturent, lampes des pièces allumées, sous le noir du fondu)
	if _capture_running:
		await reflections_settled
	hud.fade_to(0.0, 1.5)


## Écrit le point de passage « id » (C1, C2, C3) à la position du joueur (ou à « pos », lacet « yaw »,
## si elle est donnée), avec l'heure de la maison.
func checkpoint(id: String, pos := Vector3.INF, yaw := 0.0, peur_max := 100.0) -> bool:
	if bool(Game.flag("acte2", false)):
		Game.set_flag("horloge_s", snappedf((Time.get_ticks_msec() - Game.clock_origin_ms) / 1000.0, 0.1))
	if pos == Vector3.INF:
		return Game.save_checkpoint(id, player.global_position, player.yaw, peur_max)
	return Game.save_checkpoint(id, pos, yaw, peur_max)


## Ajoute un drapeau à la sauvegarde existante, sans rien changer d'autre (le point de passage, la
## position, la jauge restent) : la fin de la version 0.3 garde C3 et note « fin_v03 ».
func save_flag(id: String, v: Variant = true) -> bool:
	var path := Game.save_path()
	if not FileAccess.file_exists(path):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return false
	var flags: Dictionary = (d as Dictionary).get("flags", {})
	flags[id] = v
	(d as Dictionary)["flags"] = flags
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if Game.autotest:
		print("SAUVEGARDE %s · drapeau %s = %s" % [(d as Dictionary).get("checkpoint", "?"), id, v])
	return true


func _unhandled_input(event: InputEvent) -> void:
	# assis devant l'ordinateur : le clavier sert au terminal (choix 1, 2, 3, saisie, Espace)
	if event is InputEventKey and Game.phase == "seated" and not get_tree().paused \
			and terminal.wants_keys() and not event.is_action_pressed("pause"):
		if terminal.key_input(event):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if hud.paper_open:
			hud.close_paper()
		elif Game.phase in ["room", "seated"] and not get_tree().paused:
			pause()
		get_viewport().set_input_as_handled()
	elif acte1.waiting_stand and event.is_action_pressed("interact"):
		acte1._stand_up()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Game.phase in ["room", "seated"] \
			and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func pause() -> void:
	get_tree().paused = true
	menu.show_pause()


func resume() -> void:
	menu.hide_all()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ reflets (sondes des pièces)

## Les sondes de reflets des pièces (HouseRoom.probe) : montrées dès Élevée sur vraie carte, hors rétro
## (Qualite.reflections_on()), cachées sinon. Une sonde qu'on montre se capture (une fois) : on la
## capture tout de suite, pièce après pièce, lampes de la pièce à leur énergie de base.
func _update_reflections() -> void:
	if house == null:
		return
	var on := Qualite.reflections_on()
	var todo := false
	for id in house.rooms:
		var r: HouseRoom = house.rooms[id]
		if r.probe == null:
			continue
		if not on:
			r.hide_reflection()
		elif not r.probe.visible:
			todo = true
	if todo:
		_capture_reflections()


## Captures des sondes (asynchrone ; une image après l'appel, pour que la reprise d'une sauvegarde ait
## déjà remis les lampes dans leur état). Une sonde UPDATE_ONCE ne se capture que si une caméra la voit,
## et une seule à la fois (≈ 10 images chacune, ses 6 faces dès la première ; mesuré sur lavapipe) :
## une petite vue de 16 px, caméra orthogonale au-dessus de l'étage, les voit toutes. La pièce du joueur
## passe en premier. Sur une vraie carte : 8 pièces × 16 images à l'écran-titre (1 à 3 s).
func _capture_reflections() -> void:
	if _capture_running:
		_capture_again = true
		return
	_capture_running = true
	await RenderingServer.frame_post_draw
	var vp := SubViewport.new()
	vp.name = "CaptureReflets"
	vp.size = Vector2i(16, 16)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = 0
	add_child(vp)
	var cam := Camera3D.new()
	cam.environment = Environment.new()     # (ni brouillard, ni SSAO, ni halo pour cette petite vue)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for id in house.rooms:
		var r: HouseRoom = house.rooms[id]
		lo = lo.min(Vector3(r.rect.position.x, r.y0, r.rect.position.y))
		hi = hi.max(Vector3(r.rect.end.x, r.y0 + r.h, r.rect.end.y))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(hi.x - lo.x, hi.z - lo.z) + 4.0
	cam.near = 0.05
	cam.far = hi.y - lo.y + 12.0
	vp.add_child(cam)
	cam.global_position = Vector3((lo.x + hi.x) / 2.0, hi.y + 5.0, (lo.z + hi.z) / 2.0)
	cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	cam.current = true
	var again := true
	var n := 0
	var t0 := Time.get_ticks_msec()
	# (autotest : il attend la fin des captures ; la vue du joueur ne sert à rien pendant ce temps, et sur
	# un rendu logiciel en profil complet chaque image coûte une seconde)
	var hide_3d := Game.autotest and not get_viewport().disable_3d
	if hide_3d:
		get_viewport().disable_3d = true
	while again:
		_capture_again = false
		var order: Array[HouseRoom] = []
		var here: HouseRoom = house.current
		for id in house.rooms:
			var r: HouseRoom = house.rooms[id]
			if r.probe and not r.probe.visible:
				if r == here or (here == null and r == room):
					order.push_front(r)
				else:
					order.append(r)
		for r in order:
			if not Qualite.reflections_on():
				break
			await r.capture_reflection()
			n += 1
		again = _capture_again and Qualite.reflections_on()
	vp.queue_free()
	if hide_3d:
		get_viewport().disable_3d = false
	_capture_running = false
	print("REFLETS %d sonde(s) capturée(s) en %d ms" % [n, Time.get_ticks_msec() - t0])
	reflections_settled.emit()


## Vrai tant que des sondes se capturent (l'autotest attend la fin avant ses captures).
func reflections_busy() -> bool:
	return _capture_running


func _process(_delta: float) -> void:
	_update_dof(_delta)
	# intensité des reflets de chaque pièce : celle de ses lampes (clignotements, coupures, interrupteur)
	if house:
		for id in house.rooms:
			var r: HouseRoom = house.rooms[id]
			if r.probe:
				r.update_reflection()


## Profondeur de champ contextuelle (voir DOF_*) : seulement quand l'exposition bornée est sur la caméra.
func _update_dof(delta: float) -> void:
	if _cam_attr == null:
		return
	var want := 0.0
	if player.camera.attributes == _cam_attr and Qualite.at_least(Qualite.MOYENNE):
		if hud and bool(hud.get("paper_open")):
			want = 1.0
			_dof_kind = DOF_PAPER
		elif Game.phase == "seated" and float(player.call("turned_away")) < DOF_SEATED_TURN:
			want = 1.0
			_dof_kind = DOF_SEATED
	var was := _dof_k
	# (on se retourne : la netteté revient tout de suite)
	_dof_k = move_toward(_dof_k, want, delta / DOF_FADE_S) if want > 0.0 or Game.phase != "seated" else 0.0
	if _dof_k == was and (was == 0.0 or was == 1.0):
		return
	_cam_attr.dof_blur_far_enabled = _dof_k > 0.001
	if _cam_attr.dof_blur_far_enabled:
		_cam_attr.dof_blur_far_distance = _dof_kind.x
		_cam_attr.dof_blur_far_transition = _dof_kind.y
		_cam_attr.dof_blur_amount = _dof_kind.z * _dof_k
