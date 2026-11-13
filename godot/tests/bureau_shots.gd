extends "res://scripts/main.gd"
## Banc d'essai (exclu de l'export) : la vraie maison, puis des captures ciblées du bureau (console et
## ses quatre caméras, tiroir, portable, box, imprimante), de la chambre des grands-parents (CAM 3), des
## ajouts du couloir (Nestor, interrupteur, câble, CAM 1) et de Clovis (par la fenêtre, et absent de CAM 2).
## godot --path godot --rendering-driver vulkan res://tests/bureau_shots.tscn -- --shots=DIR [--only=fenetre,cam2,bureau,gp,couloir]

var only: PackedStringArray = []
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	super()
	_run.call_deferred()


func _want(k: String) -> bool:
	return only.is_empty() or only.has(k)


func _check(id: String, cond: bool, detail := "") -> void:
	print("VÉRIF %s %s" % [id, "OK" if cond else "ÉCHEC : " + detail])
	if not cond:
		fails += 1


func _save(img: Image, n: String) -> void:
	if img and Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(n + ".png"))
		print("capture ", n, " ", img.get_size())


func _look_at_point(from: Vector3, at: Vector3, n: String, wait := 0.8) -> void:
	var eye := from + Vector3(0, player.EYE, 0)
	var d := at - eye
	await _view(from, atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()), n, wait)


func _run() -> void:
	menu.hide_all()
	hud.fade.color.a = 0.0
	Game.phase = "room"
	player.can_move = false
	await get_tree().create_timer(1.0).timeout
	var bureau: Node = house.rooms.get("bureau")
	var gp: Node = house.rooms.get("gp")
	var couloir: Node = house.rooms.get("couloir")
	var out: Node = room.outside
	var clovis: Node3D = out.get("clovis")
	var cam2: FeedCam = out.get("cam2")
	_check("clovis_couche12", clovis != null and _all_on_layer(clovis, Builder.LAYER_HIDDEN_FROM_FEEDS), "Clovis hors de la couche 12")
	_check("cam2_sans_12", cam2 != null and (cam2.cull_mask & Builder.layer_bit(Builder.LAYER_HIDDEN_FROM_FEEDS)) == 0, "CAM 2 voit la couche 12")
	_check("joueur_voit_12", player.camera.get_cull_mask_value(Builder.LAYER_HIDDEN_FROM_FEEDS), "le joueur ne voit pas la couche 12")
	if _want("fenetre"):
		var target := Vector3(-6.3, -2.05, 1.6)
		await _look_at_point(Vector3(-2.9, 0, -0.45), target, "fenetre_clovis", 1.5)
		player.camera.fov = 30.0
		await _look_at_point(Vector3(-2.9, 0, -0.45), target, "fenetre_clovis_zoom", 0.8)
		# éclair figé (le vrai dure 0,2 s : trop court pour le rendu logiciel)
		var bolt: SpotLight3D = out.get("bolt")
		bolt.light_energy = 50.0
		await get_tree().create_timer(0.3).timeout
		await _shot("fenetre_clovis_eclair")
		player.camera.fov = 72.0
		await _look_at_point(Vector3(-2.9, 0, -0.45), target, "fenetre_clovis_eclair_large", 0.3)
		bolt.light_energy = 0.0
		await get_tree().create_timer(2.0).timeout
	if _want("clovis"):
		# vues de près (caméra libre et lampe de travail), pour juger le modèle
		var free := Camera3D.new()
		free.fov = 50.0
		add_child(free)
		var wl := OmniLight3D.new()
		wl.light_energy = 1.2
		wl.omni_range = 6.0
		wl.shadow_enabled = true
		add_child(wl)
		wl.global_position = Vector3(-5.0, -0.8, 2.6)
		free.make_current()
		var c := Vector3(-6.1, -2.0, 1.6)
		for v in [[Vector3(-4.6, -1.7, 2.6), "clovis_face"], [Vector3(-6.2, -1.9, 3.3), "clovis_profil"], [Vector3(-4.3, -0.2, 0.8), "clovis_dessus"]]:
			free.global_position = v[0]
			free.look_at(c)
			await get_tree().create_timer(0.5).timeout
			await _shot(v[1])
		wl.queue_free()
		free.queue_free()
		player.camera.make_current()
	if _want("cerisier"):
		var free2 := Camera3D.new()
		free2.fov = 60.0
		add_child(free2)
		var wl2 := OmniLight3D.new()
		wl2.light_energy = 1.5
		wl2.omni_range = 14.0
		add_child(wl2)
		wl2.global_position = Vector3(-4.5, 1.5, 4.2)
		free2.make_current()
		free2.global_position = Vector3(-3.6, 0.2, 7.5)
		free2.look_at(Vector3(-7.4, 0.0, 4.2))
		await get_tree().create_timer(0.5).timeout
		await _shot("cerisier")
		wl2.queue_free()
		free2.queue_free()
		player.camera.make_current()
	if _want("zones"):
		# rien dans les zones de battant : P7 (bureau) et P2 (chambre des grands-parents)
		var zones := {"bureau": Rect2(4.8, 3.9, 0.95, 1.0), "gp": Rect2(2.25, -4.1, 0.95, 1.0)}
		for rid in zones:
			var r: HouseRoom = house.rooms[rid]
			var bad := []
			for ch in r.get_children():
				var n3 := ch as Node3D
				if n3 == null or not (n3.has_meta("size") or n3 is Connected or String(n3.name) in ["Tiroir", "Tour", "Multiprise", "Forme", "Ecran", "Veilleuse", "Camera3", "Pilulier", "Reveil", "Portable"]):
					continue
				var bx := r._aabb_of(n3, r)
				var rr := Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z)
				if rr.intersects(zones[rid]):
					bad.append("%s %s" % [n3.name, rr])
			_check("zone_" + rid, bad.is_empty(), str(bad))
		for rid in ["bureau", "gp", "couloir"]:
			var rm: Node = house.rooms[rid]
			if rm.has_method("restore"):
				rm.call("restore")
		_check("restore", true)
	if _want("cam2"):
		var img: Image = await cam2.capture()
		_save(img, "cam2_brut_chambre")
		_save(FeedCam.cctv_image(img, "CAM 2 JARDIN"), "cam2_still_chambre")
	if _want("couloir"):
		var c_nestor: Nestor = couloir.get("nestor")
		if not player.flash_on:
			player.toggle_flashlight()
		c_nestor.wake()
		await _look_at_point(Vector3(4.25, 0, -0.35), Vector3(3.52, 0.9, -1.0), "couloir_nestor", 1.6)
		await _look_at_point(Vector3(4.35, 0, 0.75), Vector3(3.31, 1.1, 0.75), "couloir_interrupteur", 0.6)
		couloir.call("set_switch", false)
		await _look_at_point(Vector3(4.2, 0, -1.6), Vector3(4.0, 1.4, 2.5), "couloir_eteint", 0.6)
		couloir.call("set_switch", true)
		await _look_at_point(Vector3(4.2, 0, -1.6), Vector3(4.0, 1.4, 2.5), "couloir_rallume", 0.6)
		await _look_at_point(Vector3(4.15, 0, 0.6), Vector3(3.5, 0.0, 2.6), "couloir_cable", 0.6)
		await _look_at_point(Vector3(3.9, 0, 3.0), Vector3(4.6, 0.0, 4.25), "couloir_cable_p7", 0.6)
		var fc: FeedCam = couloir.get("feed_cam")
		player.global_position = Vector3(4.0, 0, -1.0)
		player.set_look(PI, -0.1)
		await get_tree().create_timer(0.5).timeout
		var photo: Image = await couloir.photo()
		_save(photo, "cam1_photo")
		_check("cam1_titre", fc != null and fc.title.begins_with("CAM 1"), "pas de CAM 1")
	if _want("bureau") or _want("gp"):
		player.global_position = Vector3(6.9, 0, 4.2)
		player.set_look(PI, -0.1)
		await get_tree().create_timer(1.0).timeout
		_check("piece_bureau", house.current != null and house.current.room_id == "bureau", "pièce courante %s" % [house.current.room_id if house.current else "aucune"])
		var cons: HouseConsole = bureau.get("console")
		var t0 := Time.get_ticks_msec()
		await bureau.wake_up()
		# (en rendu logiciel, chaque image dure 0,1 à 0,3 s : les minuteries débordent ; on note seulement)
		_check("console_allumee", cons.booted, "console éteinte")
		print("console prête en %d ms" % (Time.get_ticks_msec() - t0))
		var titles := []
		for f in cons.feeds:
			titles.append((f as FeedCam).title if f else "PAS DE SIGNAL")
		print("vignettes : ", titles)
		_check("quatre_vignettes", cons.feeds[0] != null and cons.feeds[1] != null and cons.feeds[2] != null and cons.feeds[3] == null, str(titles))
		await get_tree().create_timer(2.0).timeout
		_check("cam2_active_bureau", cam2.active and cam2.is_rendering(), "CAM 2 coupée")
		await _look_at_point(Vector3(7.2, 0, 5.15), Vector3(7.2, 1.0, 6.12), "bureau_console", 1.0)
		_save(cons.screen_texture().get_image(), "console_ecran")
		var c2img: Image = await cam2.capture()
		_save(c2img, "cam2_brut_bureau")
		var gcam: FeedCam = gp.get("cam3")
		var c3img: Image = await gcam.capture()
		_save(c3img, "cam3_brut")
		hud.show_screen(cons.screen_texture())
		await get_tree().create_timer(0.6).timeout
		await _shot("console_hud")
		hud.close_screen()
	if _want("bureau"):
		await _look_at_point(Vector3(5.25, 0, 4.4), Vector3(8.0, 0.9, 5.0), "bureau_porte", 0.8)
		await _look_at_point(Vector3(5.25, 0, 4.4), Vector3(7.5, 1.0, 2.6), "bureau_porte_nord", 0.8)
		bureau.call("open_drawer")
		await _look_at_point(Vector3(6.8, 0, 4.85), Vector3(6.77, 0.6, 5.5), "bureau_tiroir", 0.9)
		await _use_at(Vector3(6.8, 0, 4.85), player.yaw, player.pitch, "Prendre le tournevis")
		_check("tournevis", Game.has_item("tournevis") and _kind("tournevis") == "outil", str(Game.items))
		bureau.call("use_laptop")
		await _look_at_point(Vector3(7.0, 0, 3.2), Vector3(6.95, 0.85, 2.4), "bureau_portable", 0.8)
		await bureau.use_laptop()
		await get_tree().create_timer(0.5).timeout
		await _shot("bureau_portable_pages")
		hud.close_paper()
		await _look_at_point(Vector3(5.75, 0, 3.1), Vector3(5.7, 1.4, 2.0), "bureau_tableau", 0.6)
		await _look_at_point(Vector3(5.55, 0, 5.0), Vector3(5.55, 0.0, 6.15), "bureau_box", 0.6)
		bureau.call("unplug_box")
		await get_tree().create_timer(1.0).timeout
		await _shot("bureau_box_coupee")
		await _look_at_point(Vector3(7.4, 0, 4.0), Vector3(9.0, 1.0, 4.0), "bureau_classeurs", 0.6)
		var pr: Printer = bureau.get("printer")
		pr.print_page("plan_imprime", load("res://assets/images/plan_etage.png"))
		await get_tree().create_timer(4.2).timeout
		await _look_at_point(Vector3(8.1, 0, 5.0), Vector3(8.3, 0.85, 5.95), "bureau_imprimante", 0.4)
		bureau.call("set_light", true)
		await _look_at_point(Vector3(5.25, 0, 4.4), Vector3(8.0, 0.9, 5.0), "bureau_lumiere", 0.8)
		await _look_at_point(Vector3(8.6, 0, 2.6), Vector3(6.0, 0.6, 5.8), "bureau_lumiere_diag", 0.8)
	if _want("gp"):
		player.global_position = Vector3(2.4, 0, -6.6)
		await get_tree().create_timer(0.8).timeout
		await _look_at_point(Vector3(2.4, 0, -6.6), Vector3(-0.4, 0.4, -3.6), "gp_nuit", 1.0)
		var lamp := OmniLight3D.new()
		lamp.light_energy = 1.0
		lamp.omni_range = 7.0
		lamp.shadow_enabled = true
		add_child(lamp)
		lamp.global_position = Vector3(0.5, 2.2, -5.0)
		await _look_at_point(Vector3(2.4, 0, -6.6), Vector3(-0.4, 0.4, -3.6), "gp_lampe", 1.0)
		await _look_at_point(Vector3(-2.2, 0, -5.5), Vector3(0.0, 0.5, -3.2), "gp_lampe_lit", 1.0)
		lamp.queue_free()
	print("BANC BUREAU %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit()


func _kind(id: String) -> String:
	for it in Game.items:
		if it.id == id:
			return it.kind
	return ""


func _all_on_layer(n: Node, layer: int) -> bool:
	var ok := true
	var seen := 0
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		seen += 1
		if vi.layers != Builder.layer_bit(layer):
			ok = false
	return ok and seen > 0


# outils de test (passés de main.gd à autotest.gd lors du découpage de la 0.3.1)
var _t: Autotest


func _tester() -> Autotest:
	if _t == null:
		_t = Autotest.new()
		_t.name = "Outils"
		add_child(_t)
		_t.setup(self)
	return _t


func _view(pos: Vector3, yaw: float, pitch: float, n: String, wait := 0.8) -> void:
	await _tester().view(pos, yaw, pitch, n, wait)


func _shot(n: String) -> void:
	await _tester().shot(n)


func _use_at(pos: Vector3, yaw: float, pitch: float, expected: String, n := "") -> void:
	await _tester().use_at(pos, yaw, pitch, expected, n)


func _until(cond: Callable, timeout := 60.0) -> void:
	await _tester().until(cond, timeout)
