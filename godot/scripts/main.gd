extends Node3D
## Chef d'orchestre : environnement (brouillard, lumière, post-traitement), enchaînement
## écran-titre → chambre → ordinateur, pause, qualité, et le test automatique (--autotest).

@onready var room: Node3D = $Room
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var menu: CanvasLayer = $Menu
@onready var retro: ColorRect = $Post/Retro
@onready var world: WorldEnvironment = $WorldEnvironment

const SEANCE1 := preload("res://scripts/seance1.gd")
const START_POS := Vector3(2.15, 0.0, 1.85)
const START_YAW := 0.32

var env: Environment
var gi: VoxelGI
var waiting_stand := false
var explore_time := 0.0
var creaks_done := 0
var seance: Node
var seance_result := ""
var house: House


func _ready() -> void:
	retro.add_to_group("retro")
	_build_environment()
	_build_house()
	_build_gi()
	_apply_quality()
	Game.settings_changed.connect(_apply_quality)
	hud.player = player
	player.global_position = START_POS
	player.set_look(START_YAW, -0.05)
	player.looking_at.connect(hud.set_prompt)
	room.floppy_taken.connect(_on_floppy_taken)
	room.pc_used.connect(_on_pc_used)
	room.terminal.event.connect(_on_term_event)
	room.terminal.ended.connect(_on_seance_end)
	room.terminal.fear_changed.connect(_on_fear)
	menu.start_requested.connect(start_game)
	menu.resume_requested.connect(resume)
	Sfx.loop("room_tone", -16.0)
	if Game.autotest:
		_autotest()
		return
	hud.fade.color.a = 0.0
	menu.show_title()


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
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.028
	env.volumetric_fog_albedo = Color(0.72, 0.76, 0.85)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 14.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.8
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.82
	world.environment = env


## Éclairage indirect : la lumière rebondit sur les murs (écran, lampadaire, éclairs, lampe de poche).
## Le volume est « cuit » au lancement, la lumière, elle, reste dynamique.
func _build_gi() -> void:
	gi = VoxelGI.new()
	gi.name = "VoxelGI"
	gi.subdiv = VoxelGI.SUBDIV_128
	gi.size = Vector3(6.8, 3.0, 5.6)
	gi.position = Vector3(0, 1.3, 0)
	add_child(gi)
	var t0 := Time.get_ticks_msec()
	gi.bake()
	if gi.data:
		gi.data.interior = true
		gi.data.energy = 1.5
		gi.data.propagation = 0.8
		gi.data.use_two_bounces = true
	print("VoxelGI cuit en %d ms" % (Time.get_ticks_msec() - t0))


## Le premier étage autour de la chambre (couloir, salle de bain, lingerie, bureau, chambre d'amis…).
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
	print("maison construite en %d ms" % (Time.get_ticks_msec() - t0))


func _apply_quality() -> void:
	var hq := Game.high_quality
	gi.visible = hq
	if house:
		for id in house.rooms:
			var r: HouseRoom = house.rooms[id]
			if r.gi:
				r.gi.visible = hq and r.active
	env.volumetric_fog_enabled = hq
	env.ssao_enabled = hq
	room.screen_light.shadow_enabled = hq
	room.ceiling_light.shadow_enabled = hq
	RenderingServer.positional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if hq else RenderingServer.SHADOW_QUALITY_HARD)


# ------------------------------------------------------------------ déroulé

func start_game() -> void:
	menu.hide_all()
	Game.phase = "room"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.fade.color.a = 1.0
	player.can_move = true
	player.can_look = true
	hud.fade_to(0.0, 2.0)
	Game.objective("Trouve la disquette")
	await get_tree().create_timer(2.2).timeout
	Game.hint("Tu l'as rangée quelque part en rentrant. Dans l'armoire, peut-être.", 5.0)


func _on_floppy_taken() -> void:
	hud.show_hand(true)
	Game.objective("Insère la disquette dans l'ordinateur")
	Game.hint("Elle est tiède. Comme si quelqu'un venait de la tenir.", 4.0)
	Game.whisper("insère-moi")


func _on_pc_used() -> void:
	Game.phase = "seated"
	hud.set_prompt(null)
	hud.show_hand(false)
	hud.show_crosshair(false)
	Game.objective("")
	room.chair.visible = false
	room.wardrobe_close_silent()
	await player.sit(room.seat_pos, room.screen_center)
	await room.insert_floppy()
	await room.terminal.boot()
	seance = SEANCE1.new()
	seance.name = "Seance1"
	seance.T = room.terminal
	seance.player = player
	add_child(seance)
	seance.run()


## Ce que l'entité fait dans la chambre pendant la séance.
func _on_term_event(what: String) -> void:
	match what:
		"knock":
			room.door_knock()
		"handle":
			room.door_rattle()
		"wardrobe":
			room.wardrobe_creak_open()
		"silhouette":
			room.outside.set_someone(true)
		"ceiling_on":
			room.ceiling_flicker_on()
		"ceiling_burst":
			room.ceiling_burst()
		"scream":
			room.face_scare(player)
		"dawn":
			_dawn(true)
		"undawn":
			_dawn(false)
		"absorbed":
			retro.material.set_shader_parameter("corruption", 0.8)


func _on_fear(v: float) -> void:
	# la peur déteint sur l'image : grain et aberration montent avec la jauge
	retro.material.set_shader_parameter("corruption", clampf((v - 30.0) / 140.0, 0.0, 0.5))


## Fausse aube : le ciel pâlit derrière la fenêtre (puis tout revient).
func _dawn(on: bool) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(env, "background_energy_multiplier", 1.6 if on else 1.0, 3.0 if on else 0.15)
	tw.tween_property(env, "ambient_light_energy", 1.4 if on else 0.5, 3.0 if on else 0.15)
	tw.tween_property(room.moon, "light_color", Color(1.0, 0.85, 0.7) if on else Color(0.55, 0.66, 0.92), 3.0 if on else 0.15)
	if not on:
		room.outside.strike()


func _on_seance_end(id: String) -> void:
	seance_result = id
	if id == "suite":
		await get_tree().create_timer(1.5, false).timeout
		room.key_under_door()
		Game.hint("Quelque chose a glissé sous la porte. [E] Te lever", 9999.0)
	else:
		await get_tree().create_timer(4.0, false).timeout
		Game.hint("[E] Te lever", 9999.0)
	waiting_stand = true


func _stand_up() -> void:
	waiting_stand = false
	Game.hint("", 0.1)
	room.chair.visible = true
	player.stand(Vector3(room.seat_pos.x, 0.0, room.seat_pos.z + 0.75), 0.0)
	hud.show_crosshair(true)
	Game.phase = "room"
	match seance_result:
		"suite":
			Game.objective("Ramasse ce qu'on a glissé sous la porte")
		"transmission", "absorbe":
			await _epilogue(seance_result)
		_:
			Game.objective("")


## Épilogue d'une fin, puis retour à l'écran-titre.
func _epilogue(id: String) -> void:
	await get_tree().create_timer(1.0, false).timeout
	await hud.fade_to(1.0, 2.5)
	var text: Array = {
		"transmission": ["Le dimanche, c'est le vide-grenier de ta grand-mère.", "Dans le carton marqué « TOUT À 2 € », il y a une disquette.", "Un enfant l'achète. Il ne veut pas qu'on lui rende la monnaie."],
		"absorbe": ["Au matin, ta grand-mère frappe à la porte.", "« Bien dormi, mon grand ? »".replace("mon grand", Game.g("mon grand", "ma grande")), "« Oui. »", "Ce n'est plus toi qui réponds."],
	}.get(id, [])
	await hud.card(text, 7.0)
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if Game.phase != "room" or get_tree().paused:
		return
	# de temps en temps, un craquement de plancher derrière le joueur
	explore_time += delta
	if explore_time > 22.0 + creaks_done * 17.0 and creaks_done < 4:
		creaks_done += 1
		var behind := player.global_transform.basis.z * 2.2
		Sfx.play_at("creak", player.global_position + behind + Vector3(0, 0.2, 0), -4.0, randf_range(0.65, 0.9))


func _unhandled_input(event: InputEvent) -> void:
	# assis devant l'ordinateur : le clavier sert au terminal (choix 1, 2, 3, saisie, Espace)
	if event is InputEventKey and Game.phase == "seated" and not get_tree().paused \
			and room.terminal.wants_keys() and not event.is_action_pressed("pause"):
		if room.terminal.key_input(event):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if hud.paper_open:
			hud.close_paper()
		elif Game.phase in ["room", "seated"] and not get_tree().paused:
			pause()
		get_viewport().set_input_as_handled()
	elif waiting_stand and event.is_action_pressed("interact"):
		_stand_up()
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


# ------------------------------------------------------------------ test automatique

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(name + ".png"))
	print("capture ", name, " ", img.get_size())


func _view(pos: Vector3, yaw: float, pitch: float, name: String, wait := 0.8) -> void:
	player.global_position = pos
	player.set_look(yaw, pitch)
	player.head.position.y = player.EYE
	await get_tree().create_timer(wait).timeout
	await _shot(name)


func _until(cond: Callable, timeout := 60.0) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= timeout:
		print("ATTENTE TROP LONGUE")


## Place le joueur, vérifie que le rayon vise bien l'objet attendu, prend une capture, puis l'utilise.
func _use_at(pos: Vector3, yaw: float, pitch: float, expected: String, shot := "") -> void:
	player.global_position = pos
	player.set_look(yaw, pitch)
	await get_tree().create_timer(0.6).timeout
	var got: String = player.current.label if player.current else "rien"
	print("vise : %s (attendu : %s) %s" % [got, expected, "OK" if got == expected else "ÉCHEC"])
	if shot != "":
		await _shot(shot)
	if player.current:
		player.current.use()


func _autotest() -> void:
	print("AUTOTEST début")
	hud.fade.color.a = 0.0
	menu.show_title()
	await get_tree().create_timer(1.0).timeout
	await _shot("00_titre")
	menu.hide_all()
	Game.phase = "room"
	await get_tree().create_timer(1.0).timeout
	await _view(START_POS, START_YAW, -0.05, "01_depart")
	await _view(Vector3(0.2, 0, 1.2), 0.15, -0.1, "02_bureau")
	await _view(Vector3(0.6, 0, 0.6), PI * 0.62, -0.12, "03_fenetre_lit")
	await _view(Vector3(-1.0, 0, 0.2), 0.45, -0.05, "04_armoire")
	await _view(Vector3(-0.5, 0, -0.6), -PI * 0.5, -0.05, "05_porte")
	await _view(Vector3(0.5, 0, -1.2), PI, -0.15, "06_vers_le_fond")
	await _view(Vector3(-2.2, 0, -0.45), PI / 2.0, -0.08, "06b_fenetre_dehors", 1.5)
	await _view(Vector3(1.7, 0, 1.45), PI / 2.0, -0.75, "06c_empreintes")
	await _view(Vector3(1.4, 0, -0.55), -0.35, 0.05, "06d_etagere_tableau")
	await _view(Vector3(-1.1, 0, 1.3), PI / 2.0, 0.55, "06e_plafond_lit")
	await _view(Vector3(0.3, 0, 0.9), PI * 0.62, 0.0, "06f_avant_eclair", 0.4)
	room.outside.strike()
	await get_tree().create_timer(0.14).timeout
	await _shot("06g_eclair")
	# parcours joué comme un joueur : on vise avec le rayon, puis on « appuie sur E »
	await _use_at(Vector3(-2.5, 0, -1.25), 0.0, -0.25, "Ouvrir l'armoire")
	await get_tree().create_timer(2.0).timeout
	await _use_at(Vector3(-2.5, 0, -1.25), 0.0, -0.55, "Prendre la disquette", "07_armoire_ouverte")
	print("disquette en main : ", Game.has_floppy)
	await _use_at(Vector3(0.95, 0, 1.45), PI, -0.6, "Regarder la photo", "08_photo")
	await _use_at(Vector3(1.2, 0, -1.0), 0.0, -0.3, "Insérer la disquette", "09_devant_pc")
	await room.terminal.boot_finished
	await _shot("10_demarrage")
	# la séance 1, jouée avec des réponses fixées : Mamie, verre de droite, demander une preuve,
	# personne, se retourner (le visage), prononcer le mot → AUBE → fausse fin → suite
	room.terminal.turbo = true
	room.terminal.autopicks = [0, 1, 1, 2, 0, 2]
	room.terminal.autoasks = ["aube"]
	var names := ["11_choix_proche", "12_choix_verres", "13_choix_porte", "14_choix_prix", "15_choix_reflet", "17_choix_fin"]
	for i in names.size():
		await _until(func() -> bool: return not room.terminal._choice.is_empty())
		await get_tree().create_timer(0.3).timeout
		await _shot(names[i])
		await _until(func() -> bool: return room.terminal._choice.is_empty())
		if i == 4:
			await get_tree().create_timer(0.55).timeout
			await _shot("16_visage")
	await _until(func() -> bool: return not room.terminal._ask.is_empty())
	await _shot("18_saisie_mot")
	await _until(func() -> bool: return seance_result != "", 120.0)
	print("fin de séance : ", seance_result, " · peur : ", room.terminal.fear)
	await get_tree().create_timer(2.5).timeout
	await _shot("19_fin_seance")
	_stand_up()
	await get_tree().create_timer(0.5).timeout
	await _use_at(Vector3(2.2, 0, 1.32), -PI / 2.0, -1.1, "Ramasser la clé et le mot", "20_cle_sous_porte")
	await get_tree().create_timer(0.8).timeout
	await _shot("21_mot_albert")
	hud.close_paper()
	hud.toggle_inventory()
	await get_tree().create_timer(0.4).timeout
	await _shot("22_inventaire")
	hud.toggle_inventory()
	print("clé : ", Game.has_item("cle_chambre"), " · objets : ", Game.items.size())
	# la porte s'ouvre avec la clé d'Albert : le premier étage
	await _use_at(Vector3(2.4, 0, 1.4), -PI / 2.0, -0.1, "Ouvrir la porte")
	await get_tree().create_timer(2.0).timeout
	await _view(Vector3(1.6, 0, 1.4), -PI / 2.0, -0.05, "23_porte_ouverte", 1.0)
	await _view(Vector3(4.0, 0, 2.2), 0.0, -0.05, "24_couloir_vers_nord", 1.2)
	await _view(Vector3(4.0, 0, -1.0), PI, -0.05, "25_couloir_vers_sud", 1.2)
	await _use_at(Vector3(3.9, 0, -4.6), -PI / 2.0, -0.1, "Ouvrir la porte")
	await get_tree().create_timer(1.6).timeout
	await _view(Vector3(5.4, 0, -4.6), -PI / 2.0 - 0.3, -0.1, "26_salle_de_bain", 1.2)
	await _use_at(Vector3(3.95, 0, 3.4), PI / 2.0, -0.1, "Ouvrir la porte")
	await get_tree().create_timer(0.8).timeout
	await _use_at(Vector3(3.95, 0, 3.4), PI / 2.0, -0.1, "Forcer la porte")
	await get_tree().create_timer(1.2).timeout
	await _view(Vector3(2.4, 0, 3.4), PI / 2.0 + 0.2, -0.05, "27_chambre_amis", 1.2)
	await _use_at(Vector3(4.0, 0, 4.4), -PI / 2.0, -0.1, "Ouvrir la porte", "28_bureau_ferme")
	print("pièce courante : ", house.current.room_id if house.current else "aucune")
	print("AUTOTEST OK")
	get_tree().quit()
