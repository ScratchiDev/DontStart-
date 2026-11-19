class_name UiStyle
extends RefCounted
## Style de l'interface (lot V3-INTERFACE). Deux styles :
##  - net (par défaut) : Source Sans Pro / Source Serif Pro (OFL), blanc cassé sur fonds sombres translucides,
##    un seul accent (vert phosphore adouci). L'interface reste pensée en 640×360 (étirement « canvas_items ») ;
##    Godot 4.7 rastérise le texte et les tracés (draw_*) à la résolution de l'écran (oversampling) : les
##    tailles ci-dessous sont des pixels logiques (× 3 en 1920×1080, × 1,5 en 960×540).
##  - rétro (Game.style_retro) : VT323 aux seules tailles nettes (10 et 20 px), vert phosphore : l'aspect d'avant.
## Rien ici ne tire au hasard ni ne coûte au rendu.

# --- couleurs du style net
const INK := Color(0.93, 0.91, 0.87)            # blanc cassé : texte principal
const INK_DIM := Color(0.68, 0.66, 0.62)        # texte secondaire
const INK_FAINT := Color(0.45, 0.44, 0.42)      # légendes, éléments inactifs
const ACCENT := Color(0.58, 0.87, 0.64)         # phosphore adouci : sélection, titres de section
const ACCENT_DIM := Color(0.38, 0.58, 0.43)
const WARN := Color(0.95, 0.66, 0.34)           # ambre : conflits de touches, avertissements
const PANEL := Color(0.035, 0.035, 0.04, 0.88)  # fond des panneaux
const SCRIM := Color(0.0, 0.0, 0.0, 0.55)       # fond des sous-titres (option « Fond des sous-titres »)
const LINE := Color(1.0, 1.0, 1.0, 0.10)        # filets
## Noms des locuteurs (le texte des sous-titres est blanc cassé) : l'entité, les proches, les sons, les autres.
const SPEAKER := {
	"elle": Color(0.56, 0.9, 0.63), "proche": Color(0.93, 0.8, 0.6), "son": Color(0.72, 0.72, 0.7),
	"autre": Color(0.8, 0.8, 0.78),
}
# --- couleurs du style rétro (celles d'avant)
const GREEN := Color(0.36, 1.0, 0.42)
const BEIGE := Color(0.8, 0.76, 0.66)

# --- tailles du style net (pixels logiques de la grille 640×360)
const SUB := 12          # sous-titres (36 px en 1080p)
const SUB_LARGE := 15    # sous-titres, option « Grande »
const BODY := 10         # texte courant, lignes d'options
const MENU := 12         # entrées des menus
const SMALL := 8         # descriptions, aides
const TINY := 7          # petites capitales espacées (titres de section, touches)
const HEAD := 16         # titres d'écran
const LOGO := 30         # « DON'T PLAY »

const FONT_DIR := "res://assets/fonts/"
static var _fonts := {}


## Style net (vrai : nouvelle interface ; faux : style rétro, interface d'avant).
static func net() -> bool:
	return not bool(Game.style_retro)


static func _load(file: String) -> Font:
	if _fonts.has(file):
		return _fonts[file]
	var f: FontFile = load(FONT_DIR + file)
	if f == null:
		return ThemeDB.fallback_font
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.generate_mipmaps = false
	_fonts[file] = f
	return f


static func sans() -> Font:
	return _load("SourceSansPro-Regular.otf")


static func sans_semi() -> Font:
	return _load("SourceSansPro-Semibold.otf")


static func sans_it() -> Font:
	return _load("SourceSansPro-It.otf")


static func serif_it() -> Font:
	return _load("SourceSerifPro-It.otf")


static func mono() -> Font:
	return _load("IBMPlexMono-Regular.ttf")


## Police espacée (petites capitales, titres) : « spacing » pixels logiques entre les lettres.
static func tracked(base: Font, spacing: int) -> Font:
	var key := "%s|%d" % [base.get_instance_id(), spacing]
	if _fonts.has(key):
		return _fonts[key]
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = spacing
	_fonts[key] = v
	return v


## La police pixel d'avant (VT323 sans la ligature « fi »).
static func pixel() -> Font:
	return Connected.no_liga(Game.fonts.pixel)


static func box(bg: Color, radius := 3, border := Color(0, 0, 0, 0), bw := 0, mx := 0.0, my := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 6
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


static func empty_box(mx := 0.0, my := 0.0) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


## Étiquette du style net : police, taille, couleur ; ombre douce (lisible sur un mur clair) si « shadow ».
static func label(text: String, font: Font, size: int, color: Color, shadow := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_label(l, font, size, color, shadow)
	return l


static func apply_label(l: Label, font: Font, size: int, color: Color, shadow := false) -> void:
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	if shadow:
		ls.shadow_color = Color(0, 0, 0, 0.7)
		ls.shadow_size = 2
		ls.shadow_offset = Vector2(0.0, 0.6)
		ls.outline_size = 1
		ls.outline_color = Color(0, 0, 0, 0.35)
	l.label_settings = ls


## Une touche ou un bouton dessiné comme une touche de clavier (texte simple, aucun logo) : PanelContainer.
static func keycap(text: String, size := TINY + 1, round_ := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, sans_semi(), size, INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.name = "Txt"
	p.add_child(l)
	set_keycap(p, text, round_)
	return p


static func set_keycap(p: PanelContainer, text: String, round_ := false) -> void:
	var l := p.get_node_or_null("Txt") as Label
	if l:
		l.text = text
	var r := 7 if round_ else 2
	var sb := box(Color(1, 1, 1, 0.08), r, Color(INK, 0.55), 1, 3.0 if text.length() > 1 else 2.5, 0.0)
	sb.content_margin_top = 0.5
	sb.content_margin_bottom = 0.5
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(11, 10)


# --- sons de l'interface : un lecteur à part (créé par le menu, actif en pause), hauteur fixe : aucun tirage
static var sound_player: AudioStreamPlayer


static func play_ui(kind: String) -> void:
	if sound_player == null or not is_instance_valid(sound_player) or not sound_player.is_inside_tree():
		return
	var sfx := sound_player.get_node_or_null("/root/Sfx")
	if sfx == null or not sfx.has_method("_stream"):
		return
	var st: AudioStream = sfx.call("_stream", "metalClick")
	if st == null:
		return
	var p: Array = {"hover": [-30.0, 2.3], "tick": [-26.0, 2.0], "click": [-15.0, 1.4], "back": [-18.0, 1.05]}.get(kind, [-20.0, 1.6])
	sound_player.stream = st
	sound_player.volume_db = p[0]
	sound_player.pitch_scale = p[1]
	sound_player.play()
