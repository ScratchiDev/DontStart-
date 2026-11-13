extends Builder
## Banc d'essai du P4 réel (SmartMirror.run_p4), exclu de l'export : une salle de bain simplifiée
## aux coordonnées de la spécification (§ 5.2), le miroir, l'applique, la baignoire, les deux rideaux.
## godot --path godot --rendering-driver vulkan res://tests/p4_test.tscn -- --issue=fixe|retourne|fui --shots=DIR

const HUD_SCRIPT := preload("res://scripts/hud.gd")

var shots := ""
var issue_wanted := "fixe"
var cam: Camera3D
var player: Node3D            # lu par Haunt et par le miroir
var haunt: Haunt
var hud: CanvasLayer
var mirror: SmartMirror
var lamp: SmartBulb
var curtain_real: MeshInstance3D
var curtain_feed: MeshInstance3D
var fails := 0
var steps_seen: Array = []
const EYE := Vector3(7.0, 1.6, -4.85)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--issue="):
			issue_wanted = a.substr(8)
	_make_materials()
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.07, 0.075, 0.1)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = e
	add_child(we)
	room_shell(Rect2(4.8, -7.3, 4.4, 3.3), 2.6)
	haunt = Haunt.new()
	haunt.name = "Haunt"
	add_child(haunt)
	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.fade.color.a = 0.0
	player = Node3D.new()
	player.name = "Joueur"
	add_child(player)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.03
	cam.set_cull_mask_value(Builder.LAYER_FEED_ONLY, false)
	player.add_child(cam)
	cam.current = true
	var flash := SpotLight3D.new()
	flash.light_color = Color(1, 0.88, 0.7)
	flash.light_energy = 5.0
	flash.spot_range = 13.0
	flash.spot_angle = 27.0
	flash.shadow_enabled = true
	flash.position = Vector3(0.16, -0.16, 0.05)
	cam.add_child(flash)
	# baignoire, lavabo, rideaux
	_box(Vector3(1.7, 0.55, 0.75), Vector3(6.6, 0.275, -6.92), mats.paint, true)
	_box(Vector3(0.6, 0.85, 0.45), Vector3(7.0, 0.425, -4.27), mats.paint, true)
	var cm := _plain(Color(0.55, 0.6, 0.62), 0.7)
	curtain_real = _box(Vector3(1.7, 1.9, 0.02), Vector3(6.6, 1.25, -6.5), cm)
	curtain_real.name = "RideauReel"
	curtain_feed = _box(Vector3(0.25, 1.9, 0.06), Vector3(7.325, 1.25, -6.5), cm)
	curtain_feed.name = "RideauFlux"
	curtain_feed.visible = false
	# applique
	lamp = SmartBulb.new()
	lamp.device_id = "applique"
	lamp.room_id = "sdb"
	lamp.energy = 0.5
	add_child(lamp)
	lamp.position = Vector3(7.0, 2.0, -4.12)
	lamp.build()
	# miroir
	mirror = SmartMirror.new()
	mirror.device_id = "miroir"
	mirror.room_id = "sdb"
	add_child(mirror)
	mirror.position = Vector3(7.0, 1.5, -4.03)
	mirror.rotation.y = PI
	mirror.build()
	mirror.p4_lamp = lamp
	mirror.p4_curtain_real = curtain_real
	mirror.p4_curtain_feed = curtain_feed
	mirror.p4_event.connect(func(s: String) -> void: steps_seen.append(s))
	await get_tree().create_timer(0.3).timeout
	await _run()
	print("BANC P4 %s %s" % [issue_wanted, "OK" if fails == 0 else "ÉCHEC %d" % fails])
	get_tree().quit()


func _check(id: String, cond: bool, detail := "") -> void:
	if cond:
		print("VÉRIF %s OK" % id)
	else:
		fails += 1
		print("VÉRIF %s ÉCHEC : %s" % [id, detail])


func _look(at: Vector3, from := EYE) -> void:
	player.global_position = Vector3(from.x, 0, from.z)
	cam.look_at_from_position(from, at)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if shots != "":
		get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("capture ", name)


func _save_img(img: Image, name: String) -> void:
	if shots != "" and img and not img.is_empty():
		img.save_png(shots.path_join(name + ".png"))


func _run() -> void:
	Game.autotest = true
	Game.phase = "room"
	Game.sound_captions = true
	Game.choices["reflet"] = "retourne"
	haunt.room_changed("sdb")
	_look(Vector3(7.0, 1.5, -4.03))
	await _shot("p00_miroir_eteint")
	Engine.time_scale = 3.0
	var t0 := Time.get_ticks_msec()
	var p0 := Game.peur
	var result: Array = [""]
	var runner := func() -> void: result[0] = await mirror.run_p4()
	runner.call()
	await get_tree().create_timer(0.9).timeout
	_check("allume_vite", mirror.is_on, "miroir éteint à 0,9 s")
	while not mirror.feed_shown:
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	Engine.time_scale = 0.0
	await get_tree().process_frame
	await _shot("p01_mode_miroir")
	_save_img(mirror.screen_texture().get_image(), "p01b_dalle")
	Engine.time_scale = 3.0
	while not steps_seen.has("barre"):
		await get_tree().process_frame
	print("barre après %.1f s de jeu (réel %.1f s)" % [0.0, (Time.get_ticks_msec() - t0) / 1000.0])
	print("dit : ", haunt.said("miroir"))
	match issue_wanted:
		"fixe":
			while mirror.p4_time < 8.2:
				await get_tree().process_frame
			Engine.time_scale = 0.0
			await get_tree().create_timer(0.3, true, false, true).timeout
			await _shot("p10_miroir_silhouette")
			_save_img(mirror.screen_texture().get_image(), "p10b_dalle_silhouette")
			_look(Vector3(6.6, 0.9, -6.9))
			await get_tree().create_timer(0.2, true, false, true).timeout
			await _shot("p11_baignoire_reelle")
			_look(Vector3(7.0, 1.5, -4.03))
			await get_tree().process_frame
			Engine.time_scale = 3.0
			while mirror.p4_issue == "":
				await get_tree().process_frame
			await get_tree().create_timer(1.0).timeout
			Engine.time_scale = 0.0
			await get_tree().create_timer(0.3, true, false, true).timeout
			_save_img(mirror.screen_texture().get_image(), "p12_dalle_fixe")
			await _shot("p12_fixe")
			Engine.time_scale = 3.0
		"retourne":
			while mirror.p4_time < 9.0:
				await get_tree().process_frame
			_look(Vector3(6.6, 0.9, -6.9))
			while mirror.p4_issue == "":
				await get_tree().process_frame
			await get_tree().create_timer(1.2).timeout
			Engine.time_scale = 1.0
			await _shot("p20_retourne_rideau_ferme")
			_look(Vector3(7.0, 1.6, -4.03))
			await get_tree().create_timer(2.0).timeout
			await _shot("p21_retour_miroir")
			_save_img(mirror.screen_texture().get_image(), "p21b_dalle_m9b")
			Engine.time_scale = 3.0
		"fui":
			while mirror.p4_time < 6.0:
				await get_tree().process_frame
			player.global_position = Vector3(4.0, 0, -4.6)
			haunt.room_changed("couloir")
			while mirror.p4_issue == "":
				await get_tree().process_frame
	while result[0] == "":
		await get_tree().process_frame
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	print("issue %s après %.1f s réelles (×3)" % [result[0], dt])
	_check("issue", result[0] == issue_wanted, result[0])
	_check("choix", Game.choices.get("miroir_reel") == issue_wanted, str(Game.choices.get("miroir_reel")))
	var want: float = SmartMirror.P4_PEUR[issue_wanted]
	_check("jauge", is_equal_approx(Game.peur - p0, want), "%.1f" % (Game.peur - p0))
	# la suite en tâche de fond se termine
	var guard := 0
	while mirror.p4_running and guard < 3000:
		await get_tree().process_frame
		guard += 1
	_check("fin", not mirror.p4_running, "tourne encore")
	await get_tree().create_timer(2.5).timeout
	_check("eteint", not mirror.is_on, "miroir encore allumé")
	_check("rideau_reel_rendu", curtain_real.layers == 1, str(curtain_real.layers))
	_check("rideau_flux_cache", not curtain_feed.visible, "visible")
	if issue_wanted == "retourne":
		_check("applique_eclatee", lamp.broken, "pas éclatée")
		_check("m9b", haunt.said("miroir").has("Tu t'es retourné.") and haunt.said("miroir").has("Comme en simulation. Constant."), str(haunt.said("miroir")))
	else:
		_check("applique_rendue", not lamp.broken and lamp.level > 0.9, "niveau %.2f" % lamp.level)
	if issue_wanted == "fui":
		_check("m9c", haunt.said("nestor").has("Tu as fui. Ça compte aussi. Consigné."), str(haunt.said()))
	print("étapes : ", steps_seen)
	print("sous-titres : ", hud.subtitle_log.map(func(x: Dictionary) -> String: return x.text))
	Engine.time_scale = 1.0
