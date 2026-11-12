extends Node3D
## Rend le visage scanné (Lee Perry-Smith, CC BY 3.0) éclairé par en dessous, sur fond noir,
## pour fabriquer l'image du visage de S.1.L.3.N.C.3. sur les écrans (retouchée ensuite par make_assets.py).

func _ready() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.05, 0.05, 0.06)
	env.environment = e
	add_child(env)
	var head: Node3D = (load("res://assets/models/face/LeePerrySmith.glb") as PackedScene).instantiate()
	add_child(head)
	var ab := AABB()
	var first := true
	for mi in head.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		ab = b if first else ab.merge(b)
		first = false
	print("tête ", ab)
	var c := ab.get_center()
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	var face_c := c + Vector3(0, ab.size.y * 0.17, 0)
	cam.position = face_c + Vector3(0, -ab.size.y * 0.02, ab.size.y * 1.25)
	cam.look_at(face_c)
	var key := SpotLight3D.new()
	key.light_energy = 3.2
	key.spot_range = ab.size.y * 8
	key.spot_angle = 35
	key.shadow_enabled = true
	add_child(key)
	key.position = face_c + Vector3(ab.size.x * 0.05, -ab.size.y * 0.75, ab.size.y * 0.55)
	key.look_at(face_c)
	var rim := OmniLight3D.new()
	rim.light_energy = 0.25
	rim.omni_range = ab.size.y * 4
	rim.light_color = Color(0.6, 0.7, 1.0)
	add_child(rim)
	rim.position = c + Vector3(ab.size.x * 0.9, ab.size.y * 0.6, -ab.size.y * 0.2)
	get_viewport().size = Vector2i(512, 512)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("visage rendu ", img.get_size())
	get_tree().quit()
