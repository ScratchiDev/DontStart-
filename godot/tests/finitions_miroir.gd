extends Node3D
## Banc « finitions » : lisibilité des textes de la dalle du miroir connecté (144 × 200 px), exclu de
## l'export. Écrit l'image brute de la dalle pour l'en-tête (« TÉLÉASSISTANCE », « MODE MIROIR ») et
## chaque texte du P4 réel (M0 à M10), plus une vue 3D du miroir. Rendu réel (pas en --headless) :
##   godot --path godot --rendering-driver vulkan res://tests/finitions_miroir.tscn -- --shots=DIR

var player: Node3D = null      # (Haunt et le miroir cherchent scene.player)
var mirror: SmartMirror
var cam: Camera3D
var shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.3, 0.32)
	we.environment = e
	add_child(we)
	mirror = SmartMirror.new()
	mirror.device_id = "miroir"
	add_child(mirror)
	mirror.position = Vector3(0, 1.5, 0)
	mirror.build()
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(0, 1.55, 1.15)
	cam.look_at(Vector3(0, 1.5, 0))
	cam.current = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _raw(name: String) -> void:
	await _frames(3)
	var img := mirror.screen_texture().get_image()
	if shots != "":
		img.save_png(shots.path_join(name + ".png"))
	print("MIROIR %s : %dx%d · « %s » · en-tête « %s »" % [name, img.get_width(), img.get_height(),
		mirror.text_lbl.text.replace("\n", " / "), mirror.header_lbl.text])


func _view(name: String) -> void:
	await _frames(3)
	if shots != "":
		get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))


func _run() -> void:
	await _frames(4)
	mirror.power_on(0.05)
	await _frames(10)
	var t := SmartMirror.P4_TEXTS
	mirror.show_text([mirror._p4_fill(t["M0"])])
	await _raw("fm_00_teleassistance_m0")
	await _view("fm_00_vue")
	mirror.show_feed(true)
	var keys := ["M1", "M2", "M3_retourne", "M3_fixe", "M3_yeux_fermes", "M4", "M5", "M6", "M7", "M8",
		"M9a", "M10a", "M9b", "M9b_constant", "M9b_change", "M9b_fin"]
	var i := 1
	for k in keys:
		mirror.show_text([mirror._p4_fill(t[k])])
		await _raw("fm_%02d_%s" % [i, k.to_lower()])
		i += 1
	await _view("fm_99_vue_mode_miroir")
	print("MIROIR FINI")
	get_tree().quit(0)
