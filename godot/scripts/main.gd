extends Node3D
## Chef d'orchestre : environnement (brouillard, lumière, post-traitement), enchaînement
## écran-titre → chambre → ordinateur, pause, qualité, et le test automatique (--autotest).

@onready var room: Node3D = $Room
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var menu: CanvasLayer = $Menu
@onready var retro: ColorRect = $Post/Retro
@onready var world: WorldEnvironment = $WorldEnvironment

const START_POS := Vector3(2.15, 0.0, 1.85)
const START_YAW := 0.32

var env: Environment
var waiting_stand := false
var explore_time := 0.0
var creaks_done := 0


func _ready() -> void:
	_build_environment()
	_apply_quality()
	Game.settings_changed.connect(_apply_quality)
	hud.player = player
	player.global_position = START_POS
	player.set_look(START_YAW, -0.05)
	player.looking_at.connect(hud.set_prompt)
	room.floppy_taken.connect(_on_floppy_taken)
	room.pc_used.connect(_on_pc_used)
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
	pano.energy_multiplier = 0.35
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


func _apply_quality() -> void:
	var hq := Game.high_quality
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
	await player.sit(room.seat_pos, room.screen_center)
	await room.insert_floppy()
	await room.terminal.boot()
	Game.hint("[E] Te lever", 9999.0)
	waiting_stand = true


func _stand_up() -> void:
	waiting_stand = false
	Game.hint("", 0.1)
	room.chair.visible = true
	player.stand(Vector3(room.seat_pos.x, 0.0, room.seat_pos.z + 0.75), 0.0)
	hud.show_crosshair(true)
	Game.phase = "room"
	Game.objective("Version 0.1 · merci d'avoir testé")


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
	# parcours joué comme un joueur : on vise avec le rayon, puis on « appuie sur E »
	await _use_at(Vector3(-2.5, 0, -1.25), 0.0, -0.25, "Ouvrir l'armoire")
	await get_tree().create_timer(2.0).timeout
	await _use_at(Vector3(-2.5, 0, -1.25), 0.0, -0.55, "Prendre la disquette", "07_armoire_ouverte")
	print("disquette en main : ", Game.has_floppy)
	await _use_at(Vector3(0.95, 0, 1.45), PI, -0.6, "Regarder la photo", "08_photo")
	await _use_at(Vector3(1.2, 0, -1.0), 0.0, -0.3, "Insérer la disquette", "09_devant_pc")
	await room.terminal.boot_finished
	await get_tree().create_timer(0.5).timeout
	await _shot("10_assis_ecran")
	player.set_look(player.seat_yaw + PI * 0.9, 0.0)
	await get_tree().create_timer(0.6).timeout
	await _shot("11_assis_retourne")
	_stand_up()
	await get_tree().create_timer(0.3).timeout
	print("AUTOTEST OK")
	get_tree().quit()
