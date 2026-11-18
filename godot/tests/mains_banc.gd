extends Node
## Banc des mains du joueur (Viewmodel) : la vraie maison (scenes/main.tscn), le joueur posé dans des
## situations précises, une capture AVEC les mains puis une SANS (réglage « Mains visibles » coupé :
## la lampe reprend sa place de la 0.3.3), au même cadrage. Pose des mains figée (Viewmodel.figee).
##   godot --path godot --rendering-driver vulkan --resolution 960x540 res://tests/mains_banc.tscn
##         -- --shots=DIR [--rendu-complet] [--hero=aurelia] [--vues=mere_nuit,mur_20cm,…] [--seul=avec|sans]
## Vues : mere_nuit, couloir_nuit, sdb_eclairee, chambre_jour (jour simulé : soleil et ciel clair, pour
## juger la peau en pleine lumière), mur_20cm (face au mur, l'œil à 20 cm : intersection), regard_bas.
## « --retro » : style rétro (pixels) pour ce lancement.
## Chaque capture : <vue>_avec.png, <vue>_sans.png ; journal « MAINS <vue> … ».

const MAIN := preload("res://scenes/main.tscn")
const VUES := ["mere_nuit", "couloir_nuit", "sdb_eclairee", "chambre_jour", "mur_20cm", "regard_bas"]

var main: Main
var player: CharacterBody3D
var shots := ""
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	_run.call_deferred()


func wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func check(id: String, cond: bool, detail := "") -> void:
	print("VÉRIF %s %s" % [id, "OK" if cond else "ÉCHEC : " + detail])
	if not cond:
		fails += 1


func _run() -> void:
	var vues: Array = VUES.duplicate()
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vues="):
			vues = Array(a.substr(7).split(",", false))
		elif a.begins_with("--seul="):
			seul = a.substr(7)
		elif a == "--retro":
			Game.style_retro = true
	if Game.style_retro:
		Game.apply_settings()
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	for i in 3:
		await get_tree().process_frame
	if main.reflections_busy():
		await main.reflections_settled
	Viewmodel.figee = true
	main.menu.hide_all()
	main.hud.fade.color.a = 0.0
	Game.phase = "room"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.can_move = false
	player.can_look = false
	player.set_physics_process(false)      # (pas de dépénétration : l'œil peut être à 20 cm d'un mur)
	print(Qualite.describe())
	print("MAINS héros %s · rendu %s" % [Game.hero, RenderingServer.get_video_adapter_name()])
	_checks()
	for v in vues:
		await _view(String(v), seul)
	print("MAINS BANC %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	Game.quit_game(0 if fails == 0 else 1)   # (sortie propre : la file de tâches vidée)


## Couches : la vue n'est vue que par la caméra du joueur.
func _checks() -> void:
	var vm: Viewmodel = player.viewmodel
	var bit := Builder.layer_bit(Viewmodel.LAYER)
	var ok := vm.model != null
	var layers_ok := true
	var shadows_ok := true
	var gi_ok := true
	for mi in Viewmodel._meshes(vm.model):
		layers_ok = layers_ok and mi.layers == bit
		shadows_ok = shadows_ok and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi_ok = gi_ok and mi.gi_mode == GeometryInstance3D.GI_MODE_DISABLED
	check("M1 modèle chargé (%s)" % vm.hero, ok, "")
	check("M2 couche %d seule, sans ombre, hors GI" % Viewmodel.LAYER, layers_ok and shadows_ok and gi_ok, "%s %s %s" % [layers_ok, shadows_ok, gi_ok])
	check("M3 caméra du joueur : couche vue", player.camera.get_cull_mask_value(Viewmodel.LAYER), "")
	var feeds_ok := true
	for fc in get_tree().get_nodes_in_group("feed_cam"):
		feeds_ok = feeds_ok and (int(fc.get("cull_mask")) & bit) == 0
	check("M4 caméras de flux et miroir : couche exclue", feeds_ok and (FeedCam.mask_with_feed_only() & bit) == 0, "")
	var probes_ok := true
	for id in main.house.rooms:
		var r: HouseRoom = main.house.rooms[id]
		if r.probe:
			probes_ok = probes_ok and (r.probe.cull_mask & bit) == 0
	check("M5 sondes de reflets : couche exclue", probes_ok, "")


func _room_lights(id: String, on: bool) -> void:
	var r: HouseRoom = main.house.rooms.get(id)
	if r == null:
		return
	for l in r._lights:
		if not is_instance_valid(l):
			continue
		var e := HouseRoom._base_energy(l)
		if on and e != 0.0:
			l.visible = true
			l.light_energy = 1.6 if e < 0.0 else e
		elif not on and not l.has_meta("always_on"):
			pass


var _sun: DirectionalLight3D
var _env_saved := {}


func _day(on: bool) -> void:
	var env := main.env
	if on:
		_env_saved = {"amb": env.ambient_light_energy, "sky": (env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier,
			"col": env.ambient_light_color}
		(env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = 3.0
		env.ambient_light_color = Color(0.55, 0.6, 0.68)
		env.ambient_light_energy = 0.9
		_sun = DirectionalLight3D.new()
		_sun.light_color = Color(1.0, 0.95, 0.86)
		_sun.light_energy = 2.2
		_sun.shadow_enabled = true
		_sun.rotation_degrees = Vector3(-32.0, -70.0, 0.0)
		main.add_child(_sun)
	else:
		if _sun:
			_sun.queue_free()
			_sun = null
		if not _env_saved.is_empty():
			(env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = _env_saved.sky
			env.ambient_light_energy = _env_saved.amb
			env.ambient_light_color = _env_saved.col


func _place(pos: Vector3, yaw: float, pitch: float) -> void:
	player.global_position = pos
	player.set_look(yaw, pitch)
	player.head.position = Vector3(0, player.EYE, 0)
	player.camera.rotation.z = 0.0


func _flash(on: bool) -> void:
	if player.flash_on != on:
		player.toggle_flashlight()
	player.flashlight.light_energy = player.flash_base * 0.75


func _view(v: String, seul: String) -> void:
	_day(false)
	match v:
		"mere_nuit":
			_flash(true)
			_place(Acte1.START_POS, Acte1.START_YAW, -0.12)
		"couloir_nuit":
			_flash(true)
			_place(Vector3(4.0, 0.0, 4.6), 0.0, -0.06)
		"sdb_eclairee":
			_flash(true)
			_room_lights("sdb", true)
			_place(Vector3(5.35, 0.0, -4.75), -PI / 2.0 + 0.35, -0.18)
		"chambre_jour":
			_flash(false)
			_room_lights("mere", true)
			_day(true)
			_place(Vector3(1.2, 0.0, 1.2), PI / 2.0 - 0.25, -0.12)
		"mur_20cm":
			_flash(true)
			_place(Vector3(3.0, 0.0, -1.0), -PI / 2.0, -0.05)
		"regard_bas":
			_flash(true)
			_place(Acte1.START_POS, Acte1.START_YAW, -1.15)
		_:
			print("vue inconnue : ", v)
			return
	for w in ["avec", "sans"]:
		if seul != "" and seul != w:
			continue
		Game.mains_visibles = w == "avec"
		await wait(1.2)
		var img := get_viewport().get_texture().get_image()
		if shots != "":
			img.save_png(shots.path_join("%s_%s.png" % [v, w]))
		var vm: Viewmodel = player.viewmodel
		var lp: Vector3 = player.flashlight.global_position
		print("MAINS %s %s · lampe %s · œil %s" % [v, w, lp, player.camera.global_position])
		if w == "avec" and v == "mur_20cm":
			# la lumière reste de ce côté du mur (x < 3,2)
			check("M6 face au mur : la lampe ne passe pas le mur", lp.x < 3.2, "x = %.3f" % lp.x)
	Game.mains_visibles = true
