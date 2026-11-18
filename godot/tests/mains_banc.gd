extends Node
## Banc des mains du joueur (Viewmodel) : la vraie maison (scenes/main.tscn), le joueur posé dans des
## situations précises, une capture AVEC les mains puis une SANS (réglage « Mains visibles » coupé :
## la lampe reprend sa place de la 0.3.3), au même cadrage. Pose des mains figée (Viewmodel.figee).
##   godot --path godot --rendering-driver vulkan --resolution 960x540 res://tests/mains_banc.tscn
##         -- --shots=DIR [--rendu-complet] [--hero=aurelia] [--vues=mere_nuit,mur_20cm,…] [--seul=avec|sans]
## Vues : mere_nuit, couloir_nuit, sdb_eclairee, chambre_jour (jour simulé : soleil et ciel clair, pour
## juger la peau en pleine lumière), mur_20cm (face au mur, l'œil à 20 cm : intersection), regard_bas,
## devant_pc (debout devant l'ordinateur allumé : la lueur verte de l'écran, toute proche de la main),
## inventaire (regard au sol près de la porte, comme l'autotest 22_inventaire).
## Peau : une passe de plus où la peau est peinte en magenta (masque) ; sur la capture AVEC, luminance et
## saturation verte des pixels de peau (centile 99,5) : M7 « devant_pc », pas de peau brûlée ni verte.
## « --retro » : style rétro (pixels) pour ce lancement.
## Chaque capture : <vue>_avec.png, <vue>_sans.png ; journal « MAINS <vue> … ».

const MAIN := preload("res://scenes/main.tscn")
const VUES := ["mere_nuit", "couloir_nuit", "sdb_eclairee", "chambre_jour", "mur_20cm", "regard_bas", "devant_pc", "inventaire"]

var main: Main
var player: CharacterBody3D
var shots := ""
var _mask_name := ""
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
		"devant_pc":
			_flash(true)
			_place(Vector3(1.2, 0.0, -1.0), 0.0, -0.3)
		"inventaire":
			_flash(true)
			_place(Vector3(2.2, 0.0, 1.32), -PI / 2.0, -1.1)
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
		print("MAINS %s %s · lampe %s · œil %s · baissée %.2f obstacle %.2f sol %.2f rebond %.2f" % [v, w, lp, player.camera.global_position, vm._lower, vm._obst, vm._down, vm.bounce.light_energy])
		if w == "avec" and v == "mur_20cm":
			# la lumière reste de ce côté du mur (x < 3,2)
			check("M6 face au mur : la lampe ne passe pas le mur", lp.x < 3.2, "x = %.3f" % lp.x)
		if w == "avec":
			_mask_name = "%s_masque.png" % v
			var st: Dictionary = await _skin_stats(img)
			print("MAINS %s peau : %d px, luminance p99,5 %.2f (max %.2f), saturation verte p99,5 %.2f (max %.2f)" % [
				v, st.n, st.lum, st.lum_max, st.green, st.green_max])
			# (pas en style rétro : palette réduite, tramage et franges colorées font des pixels saturés)
			if (v == "devant_pc" or v == "inventaire") and not Game.style_retro:
				check("M7 %s : peau ni brûlée ni verte" % v, st.n > 200 and st.lum <= 0.9 and st.green <= 0.35,
					"%d px, luminance %.2f, vert %.2f" % [st.n, st.lum, st.green])
	Game.mains_visibles = true


static func _magenta(m: Image, x: int, y: int) -> bool:
	var c := m.get_pixel(x, y)
	return c.r > 0.75 and c.b > 0.75 and c.r - c.g > 0.25 and c.b - c.g > 0.25


## Masque de la peau (une passe où la peau est peinte en magenta, sans éclairage) ; statistiques des
## pixels de peau de la capture « img » : luminance (Rec. 709, valeurs affichées) et saturation des
## teintes vertes (75° à 165°), centile 99,5 et maximum.
func _skin_stats(img: Image) -> Dictionary:
	var vm: Viewmodel = player.viewmodel
	var mi := vm.model.get_node_or_null("Main") as MeshInstance3D
	var out := {"n": 0, "lum": 0.0, "lum_max": 0.0, "green": 0.0, "green_max": 0.0}
	if mi == null:
		return out
	var mk := StandardMaterial3D.new()
	mk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mk.albedo_color = Color(1, 0, 1)
	mk.use_z_clip_scale = true
	mk.z_clip_scale = Viewmodel.Z_CLIP
	mk.use_fov_override = true
	mk.fov_override = Viewmodel.FOV
	var old := mi.get_surface_override_material(0)
	mi.set_surface_override_material(0, mk)
	await wait(0.4)
	var m := get_viewport().get_texture().get_image()
	mi.set_surface_override_material(0, old)
	if shots != "" and _mask_name != "":
		m.save_png(shots.path_join(_mask_name))
	await wait(0.2)
	var lums := PackedFloat32Array()
	var greens := PackedFloat32Array()
	# (masque érodé de 2 px : les bords, mêlés au fond par l'anticrénelage, ne comptent pas)
	for y in range(2, m.get_height() - 2, 2):
		for x in range(2, m.get_width() - 2, 2):
			if not (_magenta(m, x, y) and _magenta(m, x - 2, y) and _magenta(m, x + 2, y) and _magenta(m, x, y - 2) and _magenta(m, x, y + 2)):
				continue
			var p := img.get_pixel(x, y)
			lums.append(0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b)
			var mx := maxf(p.r, maxf(p.g, p.b))
			var mn := minf(p.r, minf(p.g, p.b))
			var sat := (mx - mn) / mx if mx > 0.0 else 0.0
			greens.append(sat if p.h * 360.0 >= 75.0 and p.h * 360.0 <= 165.0 else 0.0)
	out.n = lums.size()
	if lums.size() > 0:
		lums.sort()
		greens.sort()
		var i := clampi(int(lums.size() * 0.995), 0, lums.size() - 1)
		out.lum = lums[i]
		out.lum_max = lums[lums.size() - 1]
		out.green = greens[i]
		out.green_max = greens[greens.size() - 1]
	return out
