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
	# la couche 11 (« flux uniquement ») n'est jamais vue par le joueur
	player.camera.set_cull_mask_value(Builder.LAYER_FEED_ONLY, false)
	terminal = room.terminal
	_build_environment()
	_build_house()
	_apply_quality()
	Game.settings_changed.connect(_apply_quality)
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


func _apply_quality() -> void:
	var hq := Game.high_quality
	if house:
		for id in house.rooms:
			var r: HouseRoom = house.rooms[id]
			if r.gi:
				r.gi.visible = hq and r.active
	env.volumetric_fog_enabled = hq
	env.ssao_enabled = hq
	room.screen_light.shadow_enabled = hq
	room.ceiling_light.shadow_enabled = hq
	_apply_video()


## Rendu net (par défaut) ou « Style rétro (pixels) » (Game.style_retro), selon « Qualité élevée »
## (Game.high_quality). Appelé au lancement et à chaque changement de réglage (Game.settings_changed).
##  - net : la 3D est calculée à la résolution de la fenêtre (étirement « canvas_items » : l'interface,
##    pensée en 640×360, est agrandie sans perdre sa mise en page), anticrénelage SMAA, AgX, SSAO,
##    halo des ampoules et des écrans, brouillard volumétrique discret, filtre « pellicule » léger ;
##    qualité basse : 3D à 75 % (FSR), FXAA, sans SSAO ni brouillard volumétrique ;
##  - rétro : l'image d'avant, exactement (640×360 agrandie sans lissage, ACES, palette de 16 niveaux
##    et tramage de Bayer, aberration chromatique).
## Énergies des lumières : les mêmes dans les deux modes (l'exposition d'AgX compense ACES).
func _apply_video() -> void:
	var hq := Game.high_quality
	var retro_on := Game.style_retro
	var soft := software_renderer()
	var win := get_tree().root
	var vp := get_viewport()
	if retro_on:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_debanding = false
	else:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if hq else Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 1.0 if hq else 0.75
		if soft:
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		else:
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if hq else Viewport.SCREEN_SPACE_AA_FXAA
		vp.use_debanding = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	# (éclairage indirect des VoxelGI : à demi-résolution en rendu logiciel, -10 % par image)
	RenderingServer.gi_set_use_half_resolution(soft)
	# (filtrage anisotrope des sols, Surfaces.world_uv)
	if soft:
		vp.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
	else:
		vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X if hq else Viewport.ANISOTROPY_2X
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
		env.tonemap_exposure = AGX_EXPOSURE
		env.glow_intensity = 0.55
		env.glow_strength = 1.0
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		for i in 7:
			env.set_glow_level(i, [0.0, 0.5, 0.7, 0.5, 0.25, 0.0, 0.0][i])
		env.volumetric_fog_density = 0.018
		env.ssao_radius = 0.7
		env.ssao_intensity = 1.6
		env.ssao_power = 1.6
		env.ssao_detail = 0.6
		env.ssao_light_affect = 0.15
		# (pas de SSIL : la VoxelGI des pièces fait déjà rebondir la lumière ; le SSIL coûtait ~7 % de
		# l'image en rendu logiciel pour un gain à peine visible)
		env.ssil_enabled = false
		env.adjustment_contrast = 1.15
		env.adjustment_saturation = 0.9
		# (lumière ambiante plus basse qu'en rétro : la courbe d'AgX remontait le noir des pièces éclairées)
		env.ambient_light_energy = 0.32
	RenderingServer.positional_soft_shadow_filter_set_quality(_shadow_quality(hq, retro_on))
	# lampe de poche : point chaud, anneau du réflecteur et halo (rendu net seulement)
	player.flashlight.light_projector = null if retro_on else FLASH_COOKIE
	if room.has_method("set_screen_glow_style"):
		room.set_screen_glow_style(retro_on)
	var m := retro_mat()
	if m:
		m.set_shader_parameter("levels", 16.0 if retro_on else 0.0)
		m.set_shader_parameter("dither_strength", 1.0 if retro_on else 0.0)
		m.set_shader_parameter("grain_mult", 1.0 if retro_on else 0.8)
		m.set_shader_parameter("vignette", 0.85 if retro_on else 0.55)
		m.set_shader_parameter("aberration", 0.0011 if retro_on else 0.00015)
		# rendu net : nuits vraiment noires (AgX et le brouillard relèvent le noir), grain de pellicule
		m.set_shader_parameter("black_point", 0.0 if retro_on else NET_BLACK_POINT)
		m.set_shader_parameter("toe", 0.0 if retro_on else NET_TOE)
		m.set_shader_parameter("grain_net", 0.0 if retro_on else 1.0)


## Exposition d'AgX (rendu net) : réglée pour que les lumières de la maison donnent à peu près la
## même luminosité qu'avec ACES (exposition 1,05) dans le style rétro (l'ACES de Godot multiplie
## l'image par 1,8 avant la courbe ; AgX non). Les énergies des lumières restent donc celles d'avant ;
## les ombres sont un peu moins écrasées qu'en rétro (plus de détails dans le noir).
const AGX_EXPOSURE := 1.65
## Pied de courbe du rendu net (retro_post.gdshader) : noir ramené à 0 et basses lumières enfoncées.
const NET_BLACK_POINT := 0.03
const NET_TOE := 0.3
const FLASH_COOKIE := preload("res://assets/textures/flashlight_cookie.png")


## Rendu logiciel (pas de carte graphique : llvmpipe/lavapipe de Mesa, SwiftShader, pilote de rendu de
## base de Windows) : chaque passe plein écran et chaque lecture de texture coûtent cher au processeur.
## Le rendu net s'y passe d'anticrénelage et de filtrage anisotrope, et calcule l'éclairage indirect à
## demi-résolution. (Les autotests tournent ainsi : leurs minuteries suivent la durée des images.
## « -- --rendu-complet » garde les réglages d'une vraie carte graphique, pour les captures de revue.)
static var _soft := -1


static func software_renderer() -> bool:
	if _soft < 0:
		var n := RenderingServer.get_video_adapter_name().to_lower()
		_soft = 0
		if not OS.get_cmdline_user_args().has("--rendu-complet"):
			for k in ["llvmpipe", "lavapipe", "swiftshader", "basic render"]:
				if n.contains(k):
					_soft = 1
	return _soft == 1


static func _shadow_quality(hq: bool, retro: bool) -> RenderingServer.ShadowQuality:
	if retro:
		return RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if hq else RenderingServer.SHADOW_QUALITY_HARD
	return RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if hq else RenderingServer.SHADOW_QUALITY_SOFT_LOW


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
	hud.fade_to(0.0, 1.5)
	print("REPRISE %s · peur %.1f · %d objets" % [d.get("checkpoint", "?"), Game.peur, Game.items.size()])


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
