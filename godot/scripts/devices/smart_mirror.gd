class_name SmartMirror
extends Connected
## Le miroir connecté de la salle de bain (téléassistance, « détection des chutes ») : un cadre
## 0,6 × 0,8, une dalle-écran 0,5 × 0,7 (Device réutilisé par composition, 144 × 200 px) derrière un
## verre sombre, et une caméra (FeedCam) au-dessus, qui filme la pièce. En « mode miroir », l'écran
## montre ce flux retourné horizontalement : la salle de bain derrière le joueur… sans le joueur.
## Primitives : power_on, power_off, show_text, clear_text, show_feed, set_progress, progress.
## Le P4 réel entier : await run_p4() -> "fixe" | "retourne" | "fui" (acteurs p4_* posés par la pièce).
## Repère : le nœud est au centre du miroir, la face regarde vers +Z (vers la pièce).

signal typed

const RES := Vector2i(144, 200)
const TEXT_COLOR := Color(0.82, 0.92, 1.0)
const HEADER_FONT := 20     # taille de l'en-tête (VT323 n'est nette qu'en 10 et 20 px ; 10 px abîme M et O)
const TEXT_FONT := 20       # taille du texte tapé (M0 à M10)
const TEXT_LINE_SPACING := 0   # interligne du texte tapé (M7, six lignes, tient : 27 + 6 × 20 = 147 px)

var screen_size := Vector2(0.5, 0.7)
var frame_size := Vector2(0.6, 0.8)
var screen: Device
var feed: FeedCam
var is_on := false
var feed_shown := false
var text_lines: Array = []        # lignes affichées (autotest)
var progress_value := -1.0

var glass: MeshInstance3D
var ui: Control
var feed_rect: TextureRect
var header_lbl: Label
var text_panel: PanelContainer
var text_lbl: Label
var bar_root: Control
var bar_fill: ColorRect
var _type_id := 0
var _bar_tw: Tween


func build() -> void:
	if display_name == "":
		display_name = "Miroir"
	can_speak = true
	var white := plain_mat(Color(0.86, 0.86, 0.84), 0.35)
	var fw := frame_size.x
	var fh := frame_size.y
	var b := 0.035
	# cadre en plastique blanc et dos
	add_box(Vector3(fw, fh, 0.012), Vector3(0, 0, 0.006), plain_mat(Color(0.3, 0.3, 0.3), 0.6))
	add_box(Vector3(fw, b, 0.03), Vector3(0, fh / 2.0 - b / 2.0, 0.015), white)
	add_box(Vector3(fw, b, 0.03), Vector3(0, -fh / 2.0 + b / 2.0, 0.015), white)
	add_box(Vector3(b, fh - 2 * b, 0.03), Vector3(-fw / 2.0 + b / 2.0, 0, 0.015), white)
	add_box(Vector3(b, fh - 2 * b, 0.03), Vector3(fw / 2.0 - b / 2.0, 0, 0.015), white)
	# l'œil de la caméra, en haut du cadre
	add_mesh(cyl(0.008, 0.008, 0.004, 12), Vector3(0, fh / 2.0 - b / 2.0, 0.031), plain_mat(Color(0.02, 0.02, 0.03), 0.1), Vector3(PI / 2.0, 0, 0))
	make_led(Vector3(0.025, fh / 2.0 - b / 2.0, 0.031), 0.0025, false, Color.BLACK)
	# la dalle-écran
	screen = Device.new()
	screen.name = "Dalle"
	screen.kind = "miroir"
	screen.screen_size = screen_size
	screen.res = RES
	screen.curvature = 0.0
	screen.glow_color = Color(0.75, 0.85, 1.0)
	screen.glow_energy = 0.18      # (à 0,45, la dalle brûlait la faïence brillante tout autour)
	screen.glow_range = 2.2
	add_child(screen)
	screen.position = Vector3(0, 0, 0.0125)
	screen.build()
	screen.say("")
	screen.mat.set_shader_parameter("brightness", 1.3)    # (le flux sombre doit rester lisible)
	screen.mat.set_shader_parameter("tint", Color(0.95, 0.97, 1.0))
	screen.mat.set_shader_parameter("idle", Color(0.0, 0.0, 0.0))
	screen.light.shadow_enabled = false
	for mi in screen.find_children("*", "MeshInstance3D", false, false):
		no_gi(mi as MeshInstance3D)
	# le verre : un miroir sombre tant que l'écran est éteint
	var gm := plain_mat(Color(0.42, 0.45, 0.48), 0.08, 0.85)
	gm.metallic_specular = 1.0
	var q := QuadMesh.new()
	q.size = screen_size
	glass = add_mesh(q, Vector3(0, 0, 0.0135), gm)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# la caméra, juste devant le haut du miroir, qui regarde la pièce
	feed = FeedCam.new()
	feed.name = "CameraMiroir"
	feed.title = "MIROIR"
	feed.size = RES
	feed.fps = 15.0
	feed.fov = 80.0
	feed.mono = false
	feed.flip_h = true
	feed.ir = 0.5
	feed.exposure = 2.6      # (à 1,6, la salle de bain à 20 % était noire : la silhouette sombre s'y perdait)
	feed.shadows = true
	feed.cull_mask = FeedCam.mask_with_feed_only()
	feed.wanted = false
	if room_id != "":
		feed.viewer_rooms = PackedStringArray([room_id])
	add_child(feed)
	feed.position = Vector3(0, 0.05, 0.07)
	feed.rotation = Vector3(-0.11, PI, 0)
	feed.build()
	_build_ui()
	built = true


func _label(fs: int, c := TEXT_COLOR) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", no_liga(Game.fonts.pixel))     # (« fixé », « vérifie » : sans ligature)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	ui = Control.new()
	ui.name = "Interface"
	ui.size = Vector2(RES)
	ui.visible = false
	screen.vp.add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.01, 0.025)
	bg.size = Vector2(RES)
	ui.add_child(bg)
	# le flux (retourné, couleurs un peu lavées)
	feed_rect = TextureRect.new()
	feed_rect.texture = feed.texture()
	feed_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	feed_rect.size = Vector2(RES)
	var m := ShaderMaterial.new()
	m.shader = FeedCam.feed_shader()
	m.set_shader_parameter("mono", 0.35)
	m.set_shader_parameter("flip_h", true)
	m.set_shader_parameter("grain", 0.06)
	m.set_shader_parameter("scan", 0.12)
	m.set_shader_parameter("fps", 15.0)
	m.set_shader_parameter("gain", FEED_GAIN)
	m.set_shader_parameter("contrast", 1.0)
	m.set_shader_parameter("res", Vector2(RES))
	feed_rect.material = m
	feed_rect.visible = false
	ui.add_child(feed_rect)
	# en-tête (« TÉLÉASSISTANCE », « MODE MIROIR ») en 20 px, la taille nette de VT323 : en 10 px,
	# chaque pixel de la police tombe sur un demi-pixel de la dalle et « MODE MIROIR » se lisait
	# « MXDE MIRXIR » (14 lettres × 8 px = 112 px : ça tient dans les 144 px)
	header_lbl = _label(HEADER_FONT, Color(0.55, 0.7, 0.9))
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.size = Vector2(RES.x, HEADER_FONT)
	header_lbl.position = Vector2(0, 1)
	ui.add_child(header_lbl)
	# le texte (tapé), sur un fond sombre quand le flux est derrière
	text_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	sb.set_content_margin_all(4)
	text_panel.add_theme_stylebox_override("panel", sb)
	text_panel.position = Vector2(6, 23)
	text_panel.size = Vector2(RES.x - 12, 20)
	ui.add_child(text_panel)
	text_lbl = _label(TEXT_FONT)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_lbl.custom_minimum_size = Vector2(RES.x - 20, 0)
	# (interligne 0 : à −3, l'accent d'une capitale touchait la ligne du dessus : « À VOS » sous
	# « 03:20 » faisait lire « Q3:20 », et l'accent de « RÉEL » marquait « MIROIR »)
	text_lbl.add_theme_constant_override("line_spacing", TEXT_LINE_SPACING)
	text_lbl.add_theme_constant_override("outline_size", 3)
	text_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	text_panel.add_child(text_lbl)
	# barre de progression
	bar_root = Control.new()
	bar_root.position = Vector2(14, RES.y - 18)
	bar_root.size = Vector2(RES.x - 28, 7)
	bar_root.visible = false
	ui.add_child(bar_root)
	var frame := ReferenceRect.new()
	frame.border_color = TEXT_COLOR
	frame.border_width = 1.0
	frame.editor_only = false
	frame.size = bar_root.size
	bar_root.add_child(frame)
	bar_fill = ColorRect.new()
	bar_fill.color = TEXT_COLOR
	bar_fill.position = Vector2(2, 2)
	bar_fill.size = Vector2(0, bar_root.size.y - 4)
	bar_root.add_child(bar_fill)


func speak_pos() -> Vector3:
	return global_position


## Le miroir s'allume (interface de téléassistance). Le verre sombre disparaît.
func power_on(seconds := 0.5) -> void:
	if is_on:
		return
	is_on = true
	glass.visible = false
	ui.visible = true
	header_lbl.text = "TÉLÉASSISTANCE"
	screen.power_on("", seconds)
	led(Color(0.2, 0.5, 1.0), 3.0)


func power_off(seconds := 0.15) -> void:
	is_on = false
	show_feed(false)
	clear_text()
	set_progress(-1.0)
	screen.power_off(seconds)
	ui.visible = false
	glass.visible = true
	led_off()


## Affiche des lignes. typed = tapées une lettre après l'autre (await mirror.show_text(...)).
func show_text(lines: Array, typed_out := false, cps := 28.0) -> void:
	_type_id += 1
	var my := _type_id
	text_lines = lines.duplicate()
	# affichage : le « · » reste collé au mot qui le précède (jamais en début de ligne)
	var full := "\n".join(PackedStringArray(lines)).replace(" · ", "\u00a0· ")
	_text_bg()
	if not typed_out:
		text_lbl.text = full
		typed.emit()
		return
	text_lbl.text = ""
	var n := full.length()
	var shown := 0
	var acc := 0.0
	while shown < n:
		await get_tree().process_frame
		if my != _type_id or not is_inside_tree():
			return
		if get_tree().paused:
			continue
		acc += get_process_delta_time() * cps
		var k := mini(n, shown + int(acc))
		if k > shown:
			acc -= k - shown
			shown = k
			text_lbl.text = full.substr(0, shown)
			if shown % 3 == 0:
				Sfx.voice_at("metalClick", speak_pos(), -30.0, 2.6, 1.0)
	typed.emit()


func clear_text() -> void:
	_type_id += 1
	text_lines = []
	text_lbl.text = ""
	_text_bg()


## Ses paroles par le miroir : le texte s'affiche tel quel.
func speak(text: String, seconds: float) -> void:
	super.speak(text, seconds)
	if is_on:
		show_text([text])


func _text_bg() -> void:
	var sb := text_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.bg_color = Color(0, 0, 0, 0.55 if feed_shown and text_lbl.text != "" else 0.0)
	text_panel.reset_size()
	text_panel.size.x = RES.x - 12


## Mode miroir : l'écran montre le flux de la caméra, retourné. La caméra ne tourne que dans ce mode
## (et seulement si le joueur est dans la pièce du miroir).
func show_feed(on: bool) -> void:
	feed_shown = on
	feed_rect.visible = on
	if on and not is_on:
		power_on(0.05)
	if room_id != "" and not feed.viewer_rooms.has(room_id):
		feed.viewer_rooms.append(room_id)
	var h := Haunt.of(get_tree())
	if h and h.room_id != "":
		feed.set_room(h.room_id)
	feed.set_wanted(on)
	screen.mat.set_shader_parameter("brightness", FEED_BRIGHTNESS if on else 1.3)
	if on and feed.viewer_rooms.is_empty():
		feed.set_active(true)    # sans pièce déclarée (banc d'essai), la caméra tourne dès qu'on la montre
	header_lbl.text = "MODE MIROIR" if on else ("TÉLÉASSISTANCE" if is_on else "")
	_text_bg()


## Barre de progression (0..1) ; négatif = cachée.
func set_progress(v: float) -> void:
	progress_value = v
	if _bar_tw and v < 0.0:
		_bar_tw.kill()
	bar_root.visible = v >= 0.0
	bar_fill.size.x = (bar_root.size.x - 4) * clampf(v, 0.0, 1.0)


## La barre se remplit en « seconds » secondes (await mirror.progress(15.0)).
func progress(seconds: float) -> void:
	if _bar_tw:
		_bar_tw.kill()
	set_progress(0.0)
	_bar_tw = create_tween()
	_bar_tw.tween_method(set_progress, 0.0, 1.0, seconds)
	await _bar_tw.finished


## Image actuelle de la dalle (capture du miroir pour l'autotest).
func screen_texture() -> Texture2D:
	return screen.vp.get_texture()


# ------------------------------------------------------------------ P4 réel (§ 2.3 et § 5.6.7)

signal p4_event(step: String)     # debut, m0, mode_miroir, barre, rideau, goutte, silhouette, saut, souffle, issue, fin

## Textes du P4 réel (§ 5.6.7), à la lettre. « {m|f} » : accord ; « 03:2x » : heure de la maison.
const P4_TEXTS := {
	"M0": "BONJOUR HENRIETTE · 03:2x · PENSEZ À VOS CACHETS",
	"H-M0": "Ce n'est pas un miroir. C'est un écran.",
	"M1": "MODE MIROIR",
	"M2": "PROTOCOLE 4 · MIROIR · ESSAI RÉEL",
	"M3_retourne": "En simulation, tu t'es {retourné|retournée}.",
	"M3_fixe": "En simulation, tu as fixé l'écran.",
	"M3_yeux_fermes": "En simulation, tu as fermé les yeux.",
	"M4": "Ici, on vérifie.",
	"M5": "Tu n'apparais pas.",
	"M6": "Moi non plus.",
	"M7": "Au laboratoire, le sujet 12 regardait un miroir comme celui-ci.",
	"M8": "Ne te retourne pas. Regarde.",
	"M9a": "Reconnu.",
	"M10a": "Le sujet 12 aussi s'était reconnu. Il n'a plus jamais parlé.",
	"M9b": "Tu t'es {retourné|retournée}.",
	"M9b_constant": "Comme en simulation. Constant.",
	"M9b_change": "Pas comme en simulation. Intéressant.",
	"M9b_fin": "Consigné.",
	"M9c": "Tu as fui. Ça compte aussi. Consigné.",
	"son_rideau": "[Anneaux de rideau, derrière toi]",
	"son_pas": "[Pas mouillés sur le carrelage, derrière toi]",
	"son_souffle": "[Un souffle, tout près]",
}
const P4_BAR := 15.0            # durée de la barre (s)
const P4_CONE := 30.0           # « fixe » : le miroir dans un cône de 30°…
const P4_DIST := 2.5            # … à moins de 2,5 m (de l'œil au centre du miroir)
const P4_AWAY_TOL := 0.8        # regard ailleurs toléré, cumulé (au-delà, la barre attend le regard)
const P4_TURN_DEG := 100.0      # « retourne » : regard à plus de 100° du miroir…
const P4_TURN_TIME := 0.3       # … pendant plus de 0,3 s
const P4_FLEE_SPEED := 0.6      # mais le dos tourné de qui file vers la porte (m/s vers la sortie)…
const P4_FLEE_GRACE := 1.6      # … laisse ce délai pour sortir (« fui ») avant de compter « retourne »
const FEED_BRIGHTNESS := 2.3    # dalle en mode miroir (1,3 sinon) : vu de devant, sous l'applique et la
                                # lampe, le flux paraissait noir et la silhouette s'y perdait
const FEED_GAIN := 1.9          # gain de l'image du flux (1,2 avant) : le fond de la salle de bain
                                # s'éclaircit, la silhouette (sombre, non éclairée) s'en détache
const P4_PEUR := {"fixe": 10.0, "retourne": 16.0, "fui": 12.0}
## Sursauts du P4 (stress, C4) : ce qu'on entend derrière soi, ce qu'on voit dans le flux, l'issue.
const P4_JOLTS := {"rideau": 0.25, "silhouette": 0.25, "pas": 0.2, "souffle": 0.4, "fixe": 0.5, "fui": 0.3}
const P4_TEXT_CLEAR := 3.0      # pendant la barre, M8 s'efface à t = 3 s (la silhouette vient à 5 s)
const P4_HOLDS := {"M2": 2.5, "M3": 3.0, "M4": 2.0, "M5": 2.5, "M6": 2.5, "M7": 3.5, "M8": 1.5}
const SILHOUETTE_TEX := "res://assets/images/silhouette_feed.png"

## Acteurs posés par la salle de bain avant run_p4() (tous facultatifs) :
var p4_lamp: SmartBulb                  # l'applique : 20 % au début, éclate si « retourne »
var p4_curtain_real: Node3D             # rideau réel, fermé : caché du flux (couche 12) à partir de t = 2 s
var p4_curtain_feed: Node3D             # rideau ouvert, « flux uniquement » (couche 11) : montré à t = 2 s
var p4_silhouette: Node3D               # silhouette du flux ; si null, run_p4() en pose une (make_silhouette)
## Trajet de la silhouette (repère du jeu, au sol), un point toutes les 2,5 s à partir de t = 5 s ;
## à t = 15 s, elle est à la place du joueur (issue « fixe »).
var p4_path: Array = [Vector3(6.6, 0, -6.9), Vector3(6.7, 0, -6.2), Vector3(6.85, 0, -5.6), Vector3(7.0, 0, -5.1)]
var p4_curtain_pos := Vector3.INF       # d'où viennent les anneaux du rideau (défaut : au-dessus du 1er point)
var p4_exit := Vector3.INF              # la porte de la pièce (P4), au sol : sert à reconnaître une fuite
var p4_room_rect := Rect2()             # la pièce du miroir au sol (x, z) : hors d'elle, le joueur est sorti
var p4_running := false                 # la séquence (ou sa suite en tâche de fond) tourne encore
var p4_issue := ""                      # "fixe", "retourne" ou "fui", dès que l'issue est connue
var p4_time := 0.0                      # temps de barre écoulé (s)
var p4_away := 0.0                      # regard ailleurs cumulé pendant la barre (s)
var _p4_sil: Node3D
var _p4_glow: MeshInstance3D
var _p4_done := {}
var _p4_real_mask := -1


## Le P4 réel en entier (60 à 90 s) : await mirror.run_p4() rend l'issue, "fixe", "retourne" ou "fui".
## Joue M0 à M8 (texte tapé sur le miroir, indice H-M0), le mode miroir (flux retourné, sans le joueur),
## la barre de 15 s (rideau, silhouette « flux uniquement », bruits derrière le joueur), détecte l'issue,
## applique la jauge (+10, +16 ou +12) et le stress par Haunt, écrit Game.choices["miroir_reel"].
## Le joueur reste libre. Rend la main dès l'issue jouée ; après « retourne », le miroir attend en tâche
## de fond que le joueur le regarde de nouveau pour écrire M9b ; après « fui », il continue seul.
## Le scénario n'a plus qu'à écrire le point de passage C2.
func run_p4() -> String:
	if p4_running or p4_issue != "":
		return p4_issue
	p4_running = true
	_p4_done = {}
	var h := Haunt.of(get_tree())
	if h:
		h.begin_scene()
	_p4_signal("debut")
	# M0 : une seconde de silence ; l'applique descend à 20 % ; le miroir s'allume (moins de 1 s après)
	if h:
		h.silence(1.0)
	else:
		Sfx.silence(1.0)
	# (0,3 s : le miroir s'allume moins de 1 s après le sèche-cheveux, B11, même quand le rendu est lent ;
	# le silence, lui, dure sa seconde entière)
	var ok := await _p4_hold(0.3)
	if p4_lamp:
		p4_lamp.set_level(0.2, 0.5)
	power_on(0.4)
	_p4_signal("m0")
	if ok:
		ok = await _p4_say("M0", 3.0)
	if ok:
		Game.hint(P4_TEXTS["H-M0"], 4.0)
	# M1 : le mode miroir, la salle de bain derrière le joueur… sans le joueur
	if ok:
		show_feed(true)
		_p4_signal("mode_miroir")
		ok = await _p4_say("M1", 4.5)
	var reflet := str(Game.choices.get("reflet", ""))
	for key in ["M2", "M3_" + reflet, "M4", "M5", "M6", "M7", "M8"]:
		if not ok:
			break
		if not P4_TEXTS.has(key):
			continue      # pas de séance 1 jouée (tests) : pas de rappel
		ok = await _p4_say(key, float(P4_HOLDS.get(key.substr(0, 2), 2.0)))
	var issue := "fui"
	if ok and is_inside_tree():
		issue = await _p4_bar()
	if not is_inside_tree():
		return issue
	p4_issue = issue
	Game.choices["miroir_reel"] = issue
	_p4_signal("issue")
	if h:
		h.log({"ev": "p4", "issue": issue})
	match issue:
		"fixe":
			await _p4_fixe()
		"retourne":
			_p4_retourne()
		_:
			_p4_fui()
	if h:
		h.end_scene()
		h.story_event("p4_reel_fini", {"issue": issue})
	return issue


## Silhouette plate et sombre du flux (quad 0,55 × 1,75, silhouette_feed.png), couche 11 (seule la
## caméra du miroir la voit), toujours tournée vers la caméra, sans ombre. Cachée ; origine aux pieds.
func make_silhouette(parent: Node = null) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 1.75)
	q.center_offset = Vector3(0, 0.875, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 1)
	if ResourceLoader.exists(SILHOUETTE_TEX):
		m.albedo_texture = load(SILHOUETTE_TEX)
	else:
		m.albedo_color = Color(0.02, 0.02, 0.025, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var mi := MeshInstance3D.new()
	mi.name = "SilhouetteFlux"
	mi.mesh = q
	mi.material_override = m
	feed_only(mi)
	mi.visible = false
	(parent if parent else get_tree().current_scene).add_child(mi)
	return mi


## Un nœud (et ses enfants) ne se voit plus que dans le flux du miroir : couche 11, sans ombre ni GI.
static func feed_only(node: Node) -> void:
	Builder.set_vis_layers(node, [Builder.LAYER_FEED_ONLY])
	for gi in [node] + node.find_children("*", "GeometryInstance3D", true, false):
		if gi is GeometryInstance3D:
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(gi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func _p4_signal(step: String) -> void:
	p4_event.emit(step)


## Remplace « 03:2x » et les accords « {m|f} ».
func _p4_fill(text: String) -> String:
	var h := Haunt.of(get_tree())
	if h:
		return h.fill(text)
	var s := text.replace("03:2x", Game.house_clock())
	var re := RegEx.create_from_string("\\{([^|{}]*)\\|([^|{}]*)\\}")
	for mt in re.search_all(s):
		s = s.replace(mt.get_string(0), Game.g(mt.get_string(1), mt.get_string(2)))
	return s


## Une image de jeu ; 0 pendant la pause.
func _p4_tick() -> float:
	await get_tree().process_frame
	if not is_inside_tree() or get_tree().paused:
		return 0.0
	return get_process_delta_time()


## Attend « sec » secondes de jeu ; rend false si le joueur est sorti de la pièce (watch) ou si le
## miroir a disparu.
func _p4_hold(sec: float, watch := true) -> bool:
	var t := 0.0
	while t < sec:
		t += await _p4_tick()
		if not is_inside_tree():
			return false
		if watch and _p4_player_left():
			return false
	return true


## Tape la ligne « key » sur le miroir (notée au journal de Haunt comme une parole du miroir), puis
## attend « hold » secondes après la frappe.
func _p4_say(key: String, hold: float, watch := true) -> bool:
	var t := _p4_fill(P4_TEXTS[key])
	var h := Haunt.of(get_tree())
	if h:
		h.log({"ev": "say", "dev": device_id, "text": t, "who": "elle", "ecran": true})
		h.spoke.emit(device_id, t, "elle")
	show_text([t], true)
	return await _p4_hold(float(t.length()) / 28.0 + hold, watch)


func _p4_player() -> Node3D:
	var scene := get_tree().current_scene
	var p: Variant = scene.get("player") if scene else null
	return p as Node3D


## Angle (degrés) entre le regard du joueur et le centre du miroir.
func _p4_gaze_angle() -> float:
	var p := _p4_player()
	if p and p.has_method("aim_angle_to"):
		return p.aim_angle_to(global_position)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var to := global_position - cam.global_position
	if to.length_squared() < 0.000001:
		return 0.0
	return rad_to_deg((-cam.global_transform.basis.z).angle_to(to))


## Distance de l'œil du joueur au centre du miroir.
func _p4_gaze_dist() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam.global_position.distance_to(global_position)
	var p := _p4_player()
	return p.global_position.distance_to(global_position) if p else 0.0


## Vitesse (m/s) à laquelle le joueur s'approche de la sortie (p4_exit) ; sans sortie connue, vitesse
## à laquelle il s'éloigne du miroir.
func _p4_flee_speed() -> float:
	var p := _p4_player()
	if p == null or not (p is CharacterBody3D):
		return 0.0
	var v := (p as CharacterBody3D).velocity
	var to: Vector3 = (p4_exit if p4_exit != Vector3.INF else global_position) - p.global_position
	var d := Vector2(to.x, to.z)
	if (p4_exit != Vector3.INF and d.length() < 0.35) or _p4_outside(p):
		return 99.0      # (déjà sur la sortie, ou passé : il sort)
	if d.length() < 0.01:
		return 0.0
	var s := Vector2(v.x, v.z).dot(d.normalized())
	return s if p4_exit != Vector3.INF else -s


## Le joueur est-il nettement hors de la pièce du miroir (p4_room_rect, plus 0,35 m : le seuil franchi,
## pas dans l'embrasure, où un point de passage le replacerait contre le battant) ? Haunt ne note le
## changement de pièce qu'à l'image suivante : sur une image longue (rendu lent), le joueur peut avoir
## franchi le seuil sans que la pièce suivie ait changé.
func _p4_outside(p: Node3D) -> bool:
	return p != null and p4_room_rect.has_area() \
		and not p4_room_rect.grow(0.35).has_point(Vector2(p.global_position.x, p.global_position.z))


## Le joueur a-t-il quitté la pièce du miroir ? (pièce suivie par Haunt ; sans pièce : plus de 6 m)
func _p4_player_left() -> bool:
	if _p4_outside(_p4_player()):
		return true
	var h := Haunt.of(get_tree())
	if h and h.room_id != "" and room_id != "":
		return h.room_id != room_id
	return _p4_gaze_dist() > 6.0


## La barre de 15 s : rend "fixe", "retourne" ou "fui".
func _p4_bar() -> String:
	var h := Haunt.of(get_tree())
	if h:
		h.stress(0.5, "P4 réel")
	_p4_signal("barre")
	_p4_sil = p4_silhouette if p4_silhouette else make_silhouette()
	_p4_sil.visible = false
	set_progress(0.0)
	p4_time = 0.0
	p4_away = 0.0
	var turn_t := 0.0
	var flee_t := 0.0
	while true:
		var dt := await _p4_tick()
		if not is_inside_tree():
			return "fui"
		if _p4_player_left():
			return "fui"
		var ang := _p4_gaze_angle()
		var watching := ang <= P4_CONE and _p4_gaze_dist() <= P4_DIST
		# se retourner : plus de 100° du miroir pendant plus de 0,3 s. Pour sortir à pied, il faut
		# tourner le dos au miroir : tant que le joueur file vers la porte, il a P4_FLEE_GRACE secondes
		# pour franchir le seuil (« fui ») ; s'il s'arrête ou reste dans la pièce, il s'est retourné.
		if ang > P4_TURN_DEG:
			turn_t += dt
			if turn_t > P4_TURN_TIME:
				if flee_t < P4_FLEE_GRACE and _p4_flee_speed() > P4_FLEE_SPEED:
					flee_t += dt
				else:
					return "retourne"
		else:
			turn_t = 0.0
			flee_t = 0.0
		if not watching:
			p4_away += dt
		# la barre n'avance que sous le regard (0,8 s de regard ailleurs tolérées, en tout)
		if watching or p4_away <= P4_AWAY_TOL:
			var before := p4_time
			p4_time = minf(P4_BAR, p4_time + dt)
			_p4_timeline(before, p4_time)
			# M8 s'efface avant que la silhouette n'arrive : rien ne cache plus le flux
			if before < P4_TEXT_CLEAR and p4_time >= P4_TEXT_CLEAR:
				clear_text()
		set_progress(p4_time / P4_BAR)
		if p4_time >= P4_BAR:
			return "fixe"
	return "fixe"


## Ce qui arrive pendant la barre (temps de barre t0 → t1) : dans le flux seulement, le rideau s'ouvre
## (2 s), la silhouette apparaît dans la baignoire (5 s) puis avance par sauts toutes les 2,5 s ; dans
## la réalité, derrière le joueur : anneaux du rideau, goutte, pas mouillés, un souffle (13 s).
## « sounds » = false : le miroir continue seul (le joueur a fui), sans bruits ni sous-titres.
func _p4_timeline(t0: float, t1: float, sounds := true) -> void:
	var cross := func(t: float) -> bool: return t0 < t and t1 >= t
	if cross.call(2.0):
		_p4_curtains(true)
		var cp := p4_curtain_pos
		if cp == Vector3.INF:
			cp = (p4_path[0] as Vector3) + Vector3(0, 2.0, 0.4) if not p4_path.is_empty() else global_position
		if sounds:
			Sfx.play_at("curtain_rings", cp, -6.0, 1.0, 2.5)
			_p4_caption("son_rideau")
			_p4_jolt(P4_JOLTS["rideau"], "P4 rideau")
		_p4_signal("rideau")
	if cross.call(3.5) and not p4_path.is_empty():
		if sounds:
			Sfx.play_at("drip", (p4_path[0] as Vector3) + Vector3(0, 0.45, 0), -10.0, 1.0, 2.0)
		_p4_signal("goutte")
	if cross.call(5.0) and _p4_sil and not p4_path.is_empty():
		_p4_place(0)
		_p4_sil.visible = true
		if Game.reduced_scares:
			_p4_fade_in(_p4_sil, 1.2)
		if sounds:
			_p4_jolt(P4_JOLTS["silhouette"], "P4 silhouette")
		_p4_signal("silhouette")
	for k in 3:
		var tj := 7.5 + 2.5 * k
		if cross.call(tj):
			_p4_place(k + 1)
			if sounds and not p4_path.is_empty():
				var at: Vector3 = p4_path[mini(k + 1, p4_path.size() - 1)]
				Sfx.play_at("wet_step", at + Vector3(0, 0.05, 0), -12.0 if Game.reduced_scares else -3.0, 1.0, 2.5)
			if sounds and k == 0:
				_p4_caption("son_pas")
			if sounds:
				_p4_jolt(P4_JOLTS["pas"], "P4 pas mouillés")
			_p4_signal("saut")
	if cross.call(13.0):
		var cam := get_viewport().get_camera_3d()
		if sounds and cam:
			var back := cam.global_transform.basis.z.normalized()
			Sfx.play_at("breath_near", cam.global_position + back * 0.35 + Vector3(0, -0.05, 0), -8.0 if Game.reduced_scares else -2.0, 1.0, 1.0)
		if sounds:
			_p4_caption("son_souffle")
			_p4_jolt(P4_JOLTS["souffle"], "P4 souffle")
		_p4_signal("souffle")


func _p4_caption(key: String) -> void:
	var h := Haunt.of(get_tree())
	if h:
		h.sound_caption(P4_TEXTS[key])


## Sursaut du P4 : impulsion de stress par Haunt (le cœur s'emballe, C4).
func _p4_jolt(v: float, why: String) -> void:
	var h := Haunt.of(get_tree())
	if h:
		h.stress(v, why)


## Silhouette au point i du trajet (au-delà du dernier : le dernier).
func _p4_place(i: int) -> void:
	if _p4_sil == null or p4_path.is_empty():
		return
	_p4_sil.global_position = p4_path[clampi(i, 0, p4_path.size() - 1)]


func _p4_fade_in(node: Node3D, sec: float) -> void:
	for gi in [node] + node.find_children("*", "GeometryInstance3D", true, false):
		if gi is GeometryInstance3D:
			var g := gi as GeometryInstance3D
			g.transparency = 1.0
			create_tween().tween_property(g, "transparency", 0.0, sec)


## Rideau ouvert dans le flux (le réel passe en couche 12, le replié « flux uniquement » apparaît), ou
## remis comme avant.
func _p4_curtains(open_in_feed: bool) -> void:
	if p4_curtain_real:
		if _p4_real_mask < 0:
			_p4_real_mask = _first_layers(p4_curtain_real)
		if open_in_feed:
			Builder.set_vis_layers(p4_curtain_real, [Builder.LAYER_HIDDEN_FROM_FEEDS])
		else:
			Builder.set_vis_layers(p4_curtain_real, _p4_real_mask if _p4_real_mask > 0 else 1)
	if p4_curtain_feed:
		if open_in_feed:
			feed_only(p4_curtain_feed)
		p4_curtain_feed.visible = open_in_feed


static func _first_layers(node: Node) -> int:
	if node is VisualInstance3D:
		return (node as VisualInstance3D).layers
	for c in node.find_children("*", "VisualInstance3D", true, false):
		return (c as VisualInstance3D).layers
	return 1


## Issue « fixe » : la silhouette s'arrête exactement à la place du joueur (le rond de sa lampe sort de
## sa poitrine, dans le flux), M9a, M10a, le miroir s'éteint. Jauge +10.
func _p4_fixe() -> void:
	var p := _p4_player()
	var cam := get_viewport().get_camera_3d()
	var at: Vector3 = p.global_position if p else (cam.global_position if cam else global_position)
	if _p4_sil:
		var floor_y: float = (p4_path[0] as Vector3).y if not p4_path.is_empty() else at.y
		_p4_sil.global_position = Vector3(at.x, floor_y, at.z)
		# le rond de lumière de la lampe sort de sa poitrine (dans le flux seulement)
		var toward := feed.global_position - _p4_sil.global_position
		toward.y = 0.0
		_p4_glow = _make_chest_glow()
		_p4_glow.global_position = Vector3(at.x, floor_y + 1.25, at.z) + toward.normalized() * 0.09
	set_progress(-1.0)
	_p4_jolt(P4_JOLTS["fixe"], "P4 reconnu")
	await _p4_say("M9a", 2.0, false)
	await _p4_say("M10a", 3.0, false)
	var h := Haunt.of(get_tree())
	if h:
		h.peur(P4_PEUR["fixe"], "p4_fixe")
	power_off(0.3)
	_p4_cleanup()


## Issue « retourne » : dans la réalité, le rideau est fermé, rien. L'applique éclate (jamais de dégât ;
## la lampe de poche reste). Jauge +16. En revenant au miroir : M9b et la remarque de cohérence.
func _p4_retourne() -> void:
	if _p4_sil:
		_p4_sil.visible = false
	_p4_curtains(false)
	set_progress(-1.0)
	clear_text()
	var h := Haunt.of(get_tree())
	if p4_lamp:
		p4_lamp.burst()
		Game.set_flag("applique_eclatee", true)
	if h:
		h.stress(0.6, "applique qui éclate")
		h.peur(P4_PEUR["retourne"], "p4_retourne")
	_p4_after_turn()


func _p4_after_turn() -> void:
	var t := 0.0
	while t < 40.0 and is_inside_tree():
		t += await _p4_tick()
		if not is_inside_tree():
			return
		if _p4_player_left():
			break
		if _p4_gaze_angle() <= P4_CONE and _p4_gaze_dist() <= 4.0:
			await _p4_say("M9b", 1.2, false)
			var same := str(Game.choices.get("reflet", "")) == "retourne"
			await _p4_say("M9b_constant" if same else "M9b_change", 1.8, false)
			await _p4_say("M9b_fin", 2.5, false)
			break
	if not is_inside_tree():
		return
	power_off(0.3)
	_p4_cleanup()


## Issue « fui » : Nestor le dit, jauge +12 ; le miroir continue seul jusqu'au bout de la barre.
func _p4_fui() -> void:
	var h := Haunt.of(get_tree())
	if h:
		h.say("nestor", P4_TEXTS["M9c"])
		h.peur(P4_PEUR["fui"], "p4_fui")
		h.stress(P4_JOLTS["fui"], "P4 fui")
	_p4_alone()


func _p4_alone() -> void:
	if not feed_shown:
		show_feed(true)
	if _p4_sil == null:
		_p4_sil = p4_silhouette if p4_silhouette else make_silhouette()
	show_text([_p4_fill(P4_TEXTS["M8"])])
	while p4_time < P4_BAR and is_inside_tree():
		var dt := await _p4_tick()
		var before := p4_time
		p4_time = minf(P4_BAR, p4_time + dt)
		_p4_timeline(before, p4_time, false)
		set_progress(p4_time / P4_BAR)
	if not is_inside_tree():
		return
	# à la fin, elle se tient devant le miroir, à la place du joueur absent
	if _p4_sil:
		var floor_y: float = (p4_path[0] as Vector3).y if not p4_path.is_empty() else 0.0
		var stand := to_global(Vector3(0, 0, 0.82))
		_p4_sil.global_position = Vector3(stand.x, floor_y, stand.z)
	await _p4_hold(3.0, false)
	if not is_inside_tree():
		return
	power_off(0.3)
	_p4_cleanup()


## Lueur ronde « flux uniquement » (la lampe du joueur vue par la caméra du miroir).
func _make_chest_glow() -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.97, 0.9, 1.0))
	g.set_color(1, Color(1.0, 0.85, 0.6, 0.0))
	g.add_point(0.18, Color(1.0, 0.95, 0.85, 0.95))
	g.add_point(0.5, Color(1.0, 0.9, 0.7, 0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	m.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	var mi := MeshInstance3D.new()
	mi.name = "LueurFlux"
	mi.mesh = q
	mi.material_override = m
	feed_only(mi)
	get_tree().current_scene.add_child(mi)
	return mi


func _p4_cleanup() -> void:
	if _p4_glow:
		_p4_glow.queue_free()
		_p4_glow = null
	if _p4_sil:
		_p4_sil.visible = false
	_p4_curtains(false)
	if p4_lamp and not p4_lamp.broken:
		p4_lamp.set_level(1.0, 2.0)
	set_progress(-1.0)
	p4_running = false
	_p4_signal("fin")
