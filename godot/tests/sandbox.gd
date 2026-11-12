extends Builder
## Banc d'essai (exclu de l'export) : pièce fermée, porte, écran hanté. Prend des captures.
## godot --path godot --rendering-driver vulkan res://tests/sandbox.tscn -- --shots=/chemin

var cam: Camera3D
var shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	_make_materials()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.25, 0.3)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	# pièce A (4 × 3) et couloir B à l'est, reliés par une porte
	var ra := Rect2(0, 0, 4, 3)
	room_shell(ra, 2.5, 0.0, {"e": [Builder.door_hole(1.5)], "n": [[1.2, 2.6, 0.95, 2.1]]})
	var rb := Rect2(4.2, 0.5, 2.0, 4.0)
	room_shell(rb, 2.5, 0.0, {"w": [Builder.door_hole(1.5)]}, {"wall": mats.plaster, "dado_h": 0.0})
	var d := door("z", Vector3(4.1, 0, 1.5), -1.0, true, 0.2)
	# une télé hantée sur le mur sud
	var dev := Device.new()
	dev.screen_size = Vector2(0.72, 0.42)
	add_child(dev)
	dev.position = Vector3(2.0, 1.3, 2.9)
	dev.rotation.y = PI
	dev.build(load("res://assets/images/entity_face.png"))
	_box(Vector3(0.8, 0.5, 0.06), Vector3(2.0, 1.3, 2.94), mats.black_plastic)
	var l := OmniLight3D.new()
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.shadow_enabled = true
	l.position = Vector3(1.0, 2.2, 1.0)
	add_child(l)
	cam = Camera3D.new()
	cam.fov = 72
	add_child(cam)
	await _shot(Vector3(0.6, 1.5, 0.5), Vector3(4.0, 1.2, 1.5), "a_porte_fermee")
	d.open(0.3)
	await get_tree().create_timer(0.6).timeout
	await _shot(Vector3(0.6, 1.5, 0.5), Vector3(4.0, 1.2, 1.5), "b_porte_ouverte")
	dev.power_on("ALLUMÉE")
	await _shot(Vector3(2.0, 1.4, 0.6), Vector3(2.0, 1.3, 2.9), "c_tele_allumee")
	dev.possess("TU NE DORS PAS.", 1.2)
	await get_tree().create_timer(0.3).timeout
	await _shot(Vector3(2.0, 1.4, 0.6), Vector3(2.0, 1.3, 2.9), "d_tele_neige", 0.05)
	dev.set_param("face_amt", 0.8)
	await _shot(Vector3(2.0, 1.4, 0.6), Vector3(2.0, 1.3, 2.9), "e_tele_visage", 0.05)
	await get_tree().create_timer(1.4).timeout
	await _shot(Vector3(2.0, 1.4, 0.6), Vector3(2.0, 1.3, 2.9), "f_tele_message")
	await _shot(Vector3(5.6, 1.5, 4.0), Vector3(4.0, 1.2, 1.5), "g_couloir_vers_porte")
	dev.set_static(0.5)
	dev.set_param("face_amt", 1.0)
	await _shot(Vector3(2.0, 1.4, 1.6), Vector3(2.0, 1.3, 2.9), "h_visage_fixe", 0.1)
	print("SANDBOX OK")
	get_tree().quit()


func _shot(from: Vector3, at: Vector3, name: String, wait := 0.4) -> void:
	cam.position = from
	cam.look_at(at)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	if shots != "":
		get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
		print("capture ", name)
