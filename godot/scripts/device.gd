class_name Device
extends Node3D
## Appareil connecté de la maison (télé, téléphone, ordinateur, caméra, tablette…).
## Gère l'écran (shader haunted_screen), sa lueur, son bruit, et ce que S.1.L.3.N.C.3. peut lui faire :
## s'allumer seul, neiger, écrire un message, montrer un visage, s'éteindre d'un coup.
## Le boîtier (coque, pied) est construit à part par la pièce ; on place ce nœud au centre de la dalle,
## face à +Z local.

signal possessed(dev: Device)

var kind := "tv"
var screen_size := Vector2(0.8, 0.45)
var res := Vector2i(320, 180)
var curvature := 0.0
var glow_color := Color(0.62, 0.72, 1.0)
var glow_energy := 0.9
var glow_range := 3.5
var is_on := false
var haunted := false

var mat: ShaderMaterial
var light: OmniLight3D
var vp: SubViewport
var label: Label
var bg: ColorRect
var hum: Node
var _tw: Tween
var _p := {"power": 0.0, "noise": 0.0, "face_amt": 0.0, "roll": 0.0, "tear": 0.0}   # valeurs courantes du shader


func build(face_tex: Texture2D = null) -> void:
	vp = SubViewport.new()
	vp.size = res
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp.transparent_bg = false
	add_child(vp)
	bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(res)
	vp.add_child(bg)
	label = Label.new()
	label.size = Vector2(res) - Vector2(24, 16)
	label.position = Vector2(12, 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", Game.fonts.pixel)
	label.add_theme_font_size_override("font_size", int(res.y / 4.5))
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	vp.add_child(label)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/haunted_screen.gdshader")
	mat.set_shader_parameter("content", vp.get_texture())
	mat.set_shader_parameter("has_content", true)
	mat.set_shader_parameter("res", Vector2(res))
	mat.set_shader_parameter("curvature", curvature)
	mat.set_shader_parameter("scanlines", 0.6 if curvature > 0.0 else 0.0)
	if face_tex:
		mat.set_shader_parameter("face", face_tex)
		mat.set_shader_parameter("has_face", true)
	mat.set_shader_parameter("power", 0.0)
	var q := QuadMesh.new()
	q.size = screen_size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	light = OmniLight3D.new()
	light.light_color = glow_color
	light.light_energy = 0.0
	light.omni_range = glow_range
	light.omni_attenuation = 1.6
	light.light_volumetric_fog_energy = 0.2
	light.shadow_enabled = true
	light.position = Vector3(0, 0, 0.35)
	add_child(light)


func set_param(p: String, v: Variant) -> void:
	_p[p] = v
	mat.set_shader_parameter(p, v)


func tween_param(p: String, to: float, seconds: float) -> Tween:
	var from: float = _p.get(p, 0.0)
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: set_param(p, x), from, to, seconds)
	return tw


## Allume l'écran (avec un éventuel texte).
func power_on(text := "", seconds := 0.25) -> void:
	is_on = true
	say(text)
	tween_param("power", 1.0, seconds)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", glow_energy, seconds)
	Sfx.play_at("metalClick", global_position, -18.0, 0.6)


func power_off(seconds := 0.12) -> void:
	is_on = false
	tween_param("power", 0.0, seconds)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, seconds)
	set_static(0.0)


## Écrit un message à l'écran (vide = efface).
func say(text: String, color := Color(0.9, 0.92, 1.0), bg_color := Color.BLACK) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	bg.color = bg_color


## Neige à l'écran, avec son grésillement.
func set_static(amount: float) -> void:
	set_param("noise", amount)
	set_param("tear", amount * 0.8)
	set_param("roll", minf(1.0, amount * 1.2))
	if amount > 0.01:
		if hum == null:
			hum = Sfx.loop("static_loop", -40.0, global_position, self)
			if hum:
				hum.set("max_distance", 8.0)
		if hum:
			hum.set("volume_db", lerpf(-34.0, -10.0, amount))
	elif hum:
		hum.queue_free()
		hum = null


## L'entité prend l'appareil : il s'allume seul, neige, un visage passe, puis le message.
func possess(text := "", seconds := 3.0) -> void:
	haunted = true
	possessed.emit(self)
	if not is_on:
		power_on("", 0.05)
	set_static(1.0)
	light.light_color = Color(0.9, 0.95, 1.0)
	set_param("face_amt", 0.0)
	await get_tree().create_timer(seconds * 0.35, false).timeout
	tween_param("face_amt", 0.8, seconds * 0.15)
	await get_tree().create_timer(seconds * 0.3, false).timeout
	tween_param("face_amt", 0.0, 0.1)
	set_static(0.12)
	light.light_color = glow_color
	say(text, Color(0.85, 1.0, 0.88))


func _process(_d: float) -> void:
	if is_on and light:
		# la lueur suit l'image : plus forte quand il neige
		var nz: float = _p.noise
		light.light_energy = glow_energy * (0.85 + 0.6 * nz * randf()) * float(_p.power)
