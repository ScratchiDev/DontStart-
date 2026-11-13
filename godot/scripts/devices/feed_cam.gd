class_name FeedCam
extends Node3D
## Caméra de flux (caméra dôme, jardin, chambre, miroir) : un SubViewport et sa Camera3D, qui filment
## le même monde que le joueur, en petit (160 × 90), à peu d'images par seconde (6), avec un
## Environment à part, sans brouillard volumétrique ni SSAO (rendu logiciel). Coupée complètement
## (render_target_update_mode = DISABLED) tant qu'on ne regarde pas son image.
## Le nœud regarde vers −Z (comme une Camera3D) : on le place puis on appelle look_at(cible).
## L'image s'affiche en noir et blanc, avec grain et horodatage, par make_view() (shader).
##
##   var cam := FeedCam.new()
##   cam.title = "CAM 2 JARDIN"
##   cam.viewer_rooms = ["bureau"]         # pièces où son image est regardée
##   add_child(cam)
##   cam.global_position = Vector3(-3.45, -0.45, 0.6)
##   cam.look_at(Vector3(-6.4, -2.2, 1.6))
##   cam.build()

const ALL_LAYERS := 0xFFFFF
const FEED_SHADER_CODE := """
shader_type canvas_item;
// Image d'une caméra de surveillance : noir et blanc, contraste, grain figé à la cadence de la
// caméra, lignes, vignettage ; « lost » = plus de signal (neige).
uniform float mono = 1.0;
uniform bool flip_h = false;
uniform float grain = 0.1;
uniform float gain = 1.15;
uniform float contrast = 1.12;
uniform float lost = 0.0;
uniform float fps = 6.0;
uniform float scan = 0.3;
uniform vec2 res = vec2(160.0, 90.0);
uniform vec3 tint : source_color = vec3(0.9, 0.95, 1.0);

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	if (flip_h) { uv.x = 1.0 - uv.x; }
	vec3 c = texture(TEXTURE, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * tint, mono);
	c = (c - 0.5) * contrast + 0.5;
	c *= gain;
	float tq = floor(TIME * fps);
	vec2 px = floor(UV * res);
	c += (rnd(px + vec2(tq * 7.13, tq * 3.71)) - 0.5) * grain;
	c *= 1.0 - scan * 0.35 * step(0.5, fract(UV.y * res.y * 0.5));
	float sn = rnd(px + vec2(floor(TIME * 24.0) * 13.0, floor(TIME * 24.0)));
	c = mix(c, vec3(sn * 0.75), clamp(lost, 0.0, 1.0));
	vec2 d = UV - 0.5;
	c *= 1.0 - dot(d, d) * 0.8;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

static var _shader: Shader

@export var title := "CAM"
var size := Vector2i(160, 90)
var fps := 6.0
var fov := 80.0
var near := 0.05
var far := 30.0
## Couches vues : toutes sauf 11 (« flux uniquement ») et 12 (« caché des caméras »).
## Le miroir ajoute la couche 11 : cull_mask = FeedCam.mask_with_feed_only().
var cull_mask := ALL_LAYERS & ~(Builder.layer_bit(Builder.LAYER_FEED_ONLY) | Builder.layer_bit(Builder.LAYER_HIDDEN_FROM_FEEDS))
var mono := true
var flip_h := false
var ir := 1.0                    # éclairage infrarouge de la caméra (lumière ambiante grise ; 0 = aucun)
var exposure := 1.35             # exposition de l'image (les caméras « voient » mieux que l'œil la nuit)
var shadows := false             # ombres des lampes dans l'image (coûteux en rendu logiciel)
## Pièces dans lesquelles son image est regardée (console : « bureau » ; miroir : « sdb »).
## Haunt.room_changed() n'active la caméra que si le joueur est dans l'une d'elles.
var viewer_rooms: PackedStringArray = []
var wanted := true               # le propriétaire veut l'image (console allumée, miroir en mode flux)

var vp: SubViewport
var cam: Camera3D
var env: Environment
var active := false
var built := false
var frames := 0                  # images rendues (autotest)
var _room_ok := false
var _t := 0.0
var _clock_t := 0.0
var _views: Array = []           # [racine, horodatage, point REC]


func _enter_tree() -> void:
	add_to_group("feed_cam")


## Masque de couches du miroir : tout sauf « caché des caméras » (il voit « flux uniquement »).
static func mask_with_feed_only() -> int:
	return ALL_LAYERS & ~Builder.layer_bit(Builder.LAYER_HIDDEN_FROM_FEEDS)


static func feed_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FEED_SHADER_CODE
	return _shader


func build() -> void:
	if built:
		return
	built = true
	vp = SubViewport.new()
	vp.name = "Flux"
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.transparent_bg = false
	vp.audio_listener_enable_3d = false
	vp.audio_listener_enable_2d = false
	vp.gui_disable_input = true
	vp.handle_input_locally = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_occlusion_culling = false
	vp.positional_shadow_atlas_size = 1024 if shadows else 0
	add_child(vp)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.ambient_light_energy = 0.3 * ir
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = exposure
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = false
	env.fog_enabled = false
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.fov = fov
	cam.near = near
	cam.far = far
	cam.cull_mask = cull_mask
	cam.environment = env
	vp.add_child(cam)
	cam.current = true
	_sync()


## Recopie la position du nœud sur la caméra (la caméra vit dans le SubViewport, hors du repère 3D).
func _sync() -> void:
	if cam and is_inside_tree():
		cam.global_transform = global_transform
		cam.cull_mask = cull_mask


func set_cull_mask(mask: int) -> void:
	cull_mask = mask
	if cam:
		cam.cull_mask = mask


## Allume ou coupe complètement le rendu (DISABLED : aucune image n'est calculée).
func set_active(on: bool) -> void:
	if not built:
		build()
	active = on
	_t = 0.0
	if on:
		_sync()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		frames += 1
	else:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_rendering() -> bool:
	return built and vp.render_target_update_mode != SubViewport.UPDATE_DISABLED


## Le joueur est-il dans une pièce où l'on regarde cette image ? (appelé par Haunt.room_changed)
func set_room(room_id: String) -> void:
	_room_ok = viewer_rooms.has(room_id)
	_refresh()


func set_wanted(on: bool) -> void:
	wanted = on
	_refresh()


func _refresh() -> void:
	var on := wanted and _room_ok
	if on != active:
		set_active(on)


func texture() -> ViewportTexture:
	if not built:
		build()
	return vp.get_texture()


## Image actuelle du flux (la dernière rendue).
func grab() -> Image:
	if not built:
		build()
	return vp.get_texture().get_image()


## Rend une image tout de suite (même coupée), puis la renvoie : await cam.capture().
func capture() -> Image:
	if not built:
		build()
	_sync()
	var before := vp.render_target_update_mode
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if before == SubViewport.UPDATE_DISABLED and not active:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return img


func _process(delta: float) -> void:
	if active:
		_t += delta
		if _t >= 1.0 / maxf(fps, 0.5):
			_t = 0.0
			_sync()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			frames += 1
	_clock_t -= delta
	if _clock_t <= 0.0 and not _views.is_empty():
		_clock_t = 0.5
		_update_views()


## Image fixe « de surveillance », prête à imprimer : rendue tout de suite, en noir et blanc, grain,
## agrandie ×2, avec le nom de la caméra et l'horodatage incrustés (await cam.capture_still()).
func capture_still(label := "") -> Image:
	var img := await capture()
	return cctv_image(img, label if label != "" else title)


## Traite une image brute comme une image de caméra de surveillance (voir capture_still).
static func cctv_image(src: Image, label := "", seed_ := 312) -> Image:
	if src == null or src.is_empty():
		return src
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			l = (l - 0.5) * 1.15 + 0.5
			l += rng.randf_range(-0.05, 0.05)
			var dx := float(x) / w - 0.5
			var dy := float(y) / h - 0.5
			l *= 1.0 - (dx * dx + dy * dy) * 0.8
			if y % 2 == 1:
				l *= 0.92
			l = clampf(l, 0.0, 1.0)
			img.set_pixel(x, y, Color(l * 0.95, l * 0.98, l, 1.0))
	img.resize(w * 2, h * 2, Image.INTERPOLATE_NEAREST)
	var text := (label + "  " if label != "" else "") + stamp()
	draw_text(img, text.to_upper(), Vector2i(6, h * 2 - 16), 2)
	return img


## Police 3 × 5 (chiffres, majuscules, ponctuation) pour incruster du texte dans une image.
const GLYPHS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
	"4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001010010",
	"8": "111101111101111", "9": "111101111001111", "A": "010101111101101", "B": "110101110101110",
	"C": "011100100100011", "D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
	"G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
	"K": "101101110101101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101",
	"O": "010101101101010", "P": "110101110100100", "Q": "010101101110011", "R": "110101110101101",
	"S": "011100010001110", "T": "111010010010010", "U": "101101101101111", "V": "101101101101010",
	"W": "101101111111101", "X": "101101010101101", "Y": "101101010010010", "Z": "111001010100111",
	":": "000010000010000", "/": "001001010100100", ".": "000000000000010", "-": "000000111000000",
	"É": "111100110100111", "È": "111100110100111", "À": "010101111101101", "♥": "000101111111010",
}


static func draw_text(img: Image, text: String, at: Vector2i, scale := 1, color := Color(0.95, 0.97, 0.95)) -> void:
	var x := at.x
	for ch in text:
		var g: String = GLYPHS.get(ch, "")
		if g != "":
			for row in 5:
				for col in 3:
					if g[row * 3 + col] == "1":
						var px := x + col * scale
						var py := at.y + row * scale
						img.fill_rect(Rect2i(px + 1, py + 1, scale, scale).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), Color(0, 0, 0))
						img.fill_rect(Rect2i(px, py, scale, scale).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), color)
		x += 4 * scale


# ------------------------------------------------------------------ affichage

## Vignette prête à poser dans une interface (console, HUD) : l'image traitée (noir et blanc, grain),
## le nom de la caméra en haut à gauche, « ● REC » et l'horodatage en bas.
func make_view(view_size: Vector2, show_labels := true) -> Control:
	if not built:
		build()
	var root := Control.new()
	root.name = "Vue_" + title.replace(" ", "_")
	root.size = view_size
	root.custom_minimum_size = view_size
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.size = view_size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = feed_shader()
	m.set_shader_parameter("mono", 1.0 if mono else 0.0)
	m.set_shader_parameter("flip_h", flip_h)
	m.set_shader_parameter("fps", fps)
	m.set_shader_parameter("res", Vector2(size))
	tr.material = m
	root.add_child(tr)
	var time_lbl: Label = null
	var rec: Control = null
	if show_labels:
		var fs := crisp_size(view_size.y / 7.0)
		var t := _small_label(title, fs)
		t.position = Vector2(3, 1)
		root.add_child(t)
		time_lbl = _small_label("", fs)
		time_lbl.size = Vector2(view_size.x - 12, fs + 2)
		time_lbl.position = Vector2(10, view_size.y - fs - 3)
		root.add_child(time_lbl)
		rec = ColorRect.new()
		(rec as ColorRect).color = Color(1.0, 0.15, 0.1)
		rec.size = Vector2(4, 4)
		rec.position = Vector2(4, view_size.y - fs * 0.5 - 4)
		rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(rec)
	_views.append([root, time_lbl, rec])
	_update_views()
	return root


## Vignette sans caméra : neige et « PAS DE SIGNAL ».
static func make_no_signal_view(view_size: Vector2, cam_title: String) -> Control:
	var root := Control.new()
	root.name = "Vue_sans_signal"
	root.size = view_size
	root.custom_minimum_size = view_size
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var snow := ColorRect.new()
	snow.size = view_size
	snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = feed_shader()
	m.set_shader_parameter("lost", 0.35)
	m.set_shader_parameter("gain", 0.12)
	m.set_shader_parameter("res", view_size)
	snow.material = m
	root.add_child(snow)
	var fs := crisp_size(view_size.y / 7.0)
	var t := _small_label(cam_title, fs)
	t.position = Vector2(3, 1)
	root.add_child(t)
	var ns := _small_label("PAS DE SIGNAL", crisp_size(view_size.y / 3.5))
	ns.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ns.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ns.size = view_size
	root.add_child(ns)
	return root


## Taille de la police pixel (VT323) la plus proche qui reste nette : 10 ou 20 px (ses tailles natives ;
## à 12, 14 ou 16 px, le « M » perd son jambage du milieu et se lit « N »).
static func crisp_size(wanted: float) -> int:
	return 20 if wanted >= 15.0 else 10


static func _small_label(text: String, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.fonts.pixel)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(0.92, 0.94, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Horodatage des caméras : « 01/11/2040 03:2x:ss » (nuit du 31 octobre au 1er novembre).
static func stamp() -> String:
	return "01/11/2040 " + Game.house_clock(true)


func _update_views() -> void:
	var s := stamp()
	var blink := int(Time.get_ticks_msec() / 500) % 2 == 0
	var keep: Array = []
	for v in _views:
		if not is_instance_valid(v[0]):
			continue
		keep.append(v)
		if v[1] and is_instance_valid(v[1]):
			(v[1] as Label).text = "REC  " + s
		if v[2] and is_instance_valid(v[2]):
			(v[2] as Control).visible = blink
	_views = keep
