extends CanvasLayer
## Avertissement (premier lancement), écran-titre (« Continuer » s'il existe une sauvegarde), choix du
## héros, menu pause et options (sensibilité, volume, plein écran, qualité, accessibilité, son).
## Tourne même quand le jeu est en pause. Police VT323 aux seules tailles nettes (multiples de 10 px :
## en 12 à 16 px, son « M » se lit « N »).

signal start_requested
signal continue_requested
signal resume_requested

const GREEN := Color(0.36, 1.0, 0.42)
const BEIGE := Color(0.8, 0.76, 0.66)
const FONT := 20          # texte et boutons
const FONT_SMALL := 10    # pied de page
const FONT_HEAD := 40     # titres des écrans
const FONT_TITLE := 60    # « DON'T PLAY »
const WIDTH := 552        # largeur de la colonne de texte
const WARNING_TEXT := "Ce jeu contient des éclairs, des images qui clignotent et des sursauts. Ils peuvent provoquer des malaises, voire des crises chez les personnes photosensibles. Les options « Éclairs adoucis » et « Sursauts réduits » les atténuent."

var root: Control
var title_box: Control
var pause_box: Control
var options_box: Control
var hero_box: Control
var warning_box: Control
var continue_btn: Button
var back_target := "title"


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme()
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.74)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	title_box = _build_title()
	pause_box = _build_pause()
	options_box = _build_options()
	hero_box = _build_hero()
	warning_box = _build_warning()
	for b in _boxes():
		root.add_child(b)
	hide_all()


func _boxes() -> Array:
	return [title_box, pause_box, options_box, hero_box, warning_box]


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = Connected.no_liga(Game.fonts.pixel)     # (sans la ligature « fi »)
	th.default_font_size = FONT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = GREEN
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", hover)
	th.set_stylebox("focus", "Button", normal)
	th.set_color("font_color", "Button", GREEN)
	th.set_color("font_hover_color", "Button", Color.BLACK)
	th.set_color("font_pressed_color", "Button", Color.BLACK)
	th.set_color("font_focus_color", "Button", GREEN)
	th.set_color("font_color", "Label", BEIGE)
	th.set_color("font_color", "CheckBox", BEIGE)
	th.set_color("font_hover_color", "CheckBox", GREEN)
	return th


func _vbox(x: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(x, -164)
	v.size = Vector2(WIDTH, 240)
	v.add_theme_constant_override("separation", 4)
	return v


func _text(t: String, c := BEIGE, size_ := FONT, wrap := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", c)
	l.add_theme_font_size_override("font_size", size_)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WIDTH, 0)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "> " + t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		Sfx.play("metalClick", -12.0, 1.4)
		cb.call())
	b.mouse_entered.connect(func() -> void: Sfx.play("metalClick", -26.0, 2.2))
	return b


func _build_title() -> Control:
	var v := _vbox(44)
	v.add_child(_text("DON'T PLAY", GREEN, FONT_TITLE, false))
	v.add_child(_text("Toussaint 2040. Une semaine chez tes grands-parents. Mamie t'a fait dormir dans l'ancienne chambre de ta mère. Cet après-midi, tu as réparé son vieil ordinateur et tu l'as branché sur la box. Papi t'a dit de le débrancher avant de dormir."))
	v.add_child(_text("Il est 3 h 12. L'ordinateur vient de s'allumer tout seul.", Color(0.62, 0.6, 0.54)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	continue_btn = _button("Continuer", func() -> void: continue_requested.emit())
	v.add_child(continue_btn)
	v.add_child(_button("Nouvelle partie", func() -> void: _show(hero_box)))
	v.add_child(_button("Options", func() -> void: show_options("title")))
	v.add_child(_button("Quitter", func() -> void: get_tree().quit()))
	var foot := _text("ZQSD/WASD marcher · souris regarder · E agir · F lampe · Tab inventaire\nMaj courir · C s'accroupir · Échap menu", Color(0.5, 0.49, 0.44), FONT_SMALL, false)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(44, -46)
	var warn := _text("Casque recommandé. Sursauts et éclairs clignotants : voir Options.", Color(0.5, 0.49, 0.44), FONT_SMALL, false)
	warn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	warn.position = Vector2(44, -20)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(v)
	holder.add_child(foot)
	holder.add_child(warn)
	return holder


## Avertissement de photosensibilité, montré au premier lancement seulement (Game.seen_warning,
## gardé dans settings.cfg).
func _build_warning() -> Control:
	var v := _vbox(44)
	v.add_child(_text("AVERTISSEMENT", GREEN, FONT_HEAD, false))
	v.add_child(_text(WARNING_TEXT))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	v.add_child(_button("J'ai compris", func() -> void:
		Game.seen_warning = true
		Game.save_settings()
		show_title()))
	v.add_child(_button("Options", func() -> void:
		Game.seen_warning = true
		Game.save_settings()
		show_options("title")))
	return v


func _build_hero() -> Control:
	var v := _vbox(44)
	v.add_child(_text("QUI ES-TU ?", GREEN, FONT_HEAD, false))
	v.add_child(_text("16 ans. Geek, fan de dinosaures et de tout ce qui vient des années 90. Une semaine de vacances chez Henriette et Albert, pour la Toussaint.", Color(0.62, 0.6, 0.54)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	v.add_child(_button("Alexandre", func() -> void: _pick("alexandre")))
	v.add_child(_button("Aurèlia", func() -> void: _pick("aurelia")))
	v.add_child(_button("Retour", func() -> void: show_title()))
	return v


func _pick(h: String) -> void:
	Game.hero = h
	start_requested.emit()


func _build_pause() -> Control:
	var v := _vbox(44)
	v.add_child(_text("PAUSE", GREEN, FONT_HEAD, false))
	v.add_child(_button("Reprendre", func() -> void: resume_requested.emit()))
	v.add_child(_button("Options", func() -> void: show_options("pause")))
	v.add_child(_button("Quitter le jeu", func() -> void: get_tree().quit()))
	return v


func _slider(label: String, min_v: float, max_v: float, value: float, cb: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_child(_text(label, BEIGE, FONT, false))
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = (max_v - min_v) / 100.0
	s.value = value
	s.custom_minimum_size = Vector2(220, 14)
	s.value_changed.connect(cb)
	row.add_child(s)
	return row


func _build_options() -> Control:
	var v := _vbox(44)
	v.add_child(_text("OPTIONS", GREEN, FONT_HEAD, false))
	v.add_child(_slider("Sensibilité de la souris", 0.0006, 0.006, Game.mouse_sensitivity, func(x: float) -> void:
		Game.mouse_sensitivity = x))
	v.add_child(_slider("Volume", 0.0, 1.0, Game.master_volume, func(x: float) -> void:
		Game.master_volume = x
		Game.apply_settings()))
	var fs := CheckBox.new()
	fs.text = "Plein écran"
	fs.button_pressed = Game.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		Game.fullscreen = on
		Game.apply_settings())
	v.add_child(fs)
	var hq := CheckBox.new()
	hq.text = "Qualité élevée (brouillard, ombres fines)"
	hq.button_pressed = Game.high_quality
	hq.toggled.connect(func(on: bool) -> void:
		Game.high_quality = on
		Game.apply_settings())
	v.add_child(hq)
	var rs := CheckBox.new()
	rs.text = "Sursauts réduits"
	rs.button_pressed = Game.reduced_scares
	rs.toggled.connect(func(on: bool) -> void:
		Game.reduced_scares = on
		Game.apply_settings())
	v.add_child(rs)
	var sf := CheckBox.new()
	sf.text = "Éclairs adoucis (photosensibilité)"
	sf.button_pressed = Game.soft_flashes
	sf.toggled.connect(func(on: bool) -> void:
		Game.soft_flashes = on
		Game.apply_settings())
	v.add_child(sf)
	var sc := CheckBox.new()
	sc.text = "Sous-titres des sons"
	sc.button_pressed = Game.sound_captions
	sc.toggled.connect(func(on: bool) -> void:
		Game.sound_captions = on
		Game.apply_settings())
	v.add_child(sc)
	var wh := CheckBox.new()
	wh.text = "Chuchotements (synthèse Windows)"
	wh.button_pressed = Game.whispers
	wh.toggled.connect(func(on: bool) -> void:
		Game.whispers = on
		Game.apply_settings())
	v.add_child(wh)
	v.add_child(_button("Retour", func() -> void:
		Game.save_settings()
		if back_target == "title":
			show_title()
		else:
			show_pause()))
	return v


func hide_all() -> void:
	root.visible = false


func _show(box: Control) -> void:
	root.visible = true
	for b in _boxes():
		b.visible = b == box
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Au lancement : l'avertissement de photosensibilité la première fois, sinon l'écran-titre.
func show_start() -> void:
	if not Game.seen_warning:
		_show(warning_box)
	else:
		show_title()


func show_title() -> void:
	continue_btn.visible = Game.has_save()
	_show(title_box)


func show_hero() -> void:
	_show(hero_box)


func show_pause() -> void:
	_show(pause_box)


func show_options(from: String) -> void:
	back_target = from
	_show(options_box)
