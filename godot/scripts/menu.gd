extends CanvasLayer
## Écran-titre, menu pause et options (sensibilité, volume, plein écran, qualité).
## Tourne même quand le jeu est en pause.

signal start_requested
signal resume_requested

const GREEN := Color(0.36, 1.0, 0.42)
const BEIGE := Color(0.8, 0.76, 0.66)

var root: Control
var title_box: Control
var pause_box: Control
var options_box: Control
var hero_box: Control
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
	for b in [title_box, pause_box, options_box, hero_box]:
		root.add_child(b)
	hide_all()


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = Game.fonts.pixel
	th.default_font_size = 16
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
	v.position = Vector2(x, -156)
	v.size = Vector2(380, 240)
	v.add_theme_constant_override("separation", 4)
	return v


func _text(t: String, c := BEIGE, size_ := 16, wrap := true) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", c)
	l.add_theme_font_size_override("font_size", size_)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
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
	v.add_child(_text("DON'T PLAY", GREEN, 64, false))
	v.add_child(_text("Les vacances chez tes grands-parents. Une maison restée dans les années 90, où chaque écran est connecté. Dans l'ancienne chambre de ta mère, une disquette sans étiquette."))
	v.add_child(_text("Ne la mets pas dans l'ordinateur.", Color(0.62, 0.6, 0.54)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	v.add_child(_button("Nouvelle partie", func() -> void: _show(hero_box)))
	v.add_child(_button("Options", func() -> void: show_options("title")))
	v.add_child(_button("Quitter", func() -> void: get_tree().quit()))
	var foot := _text("ZQSD/WASD marcher · souris regarder · E agir · F lampe\nMaj courir · C s'accroupir · Échap menu", Color(0.45, 0.44, 0.4), 16, false)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(44, -64)
	var warn := _text("Casque recommandé. Contient des sursauts et des effets clignotants.", Color(0.45, 0.44, 0.4), 16, false)
	warn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	warn.position = Vector2(44, -26)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(v)
	holder.add_child(foot)
	holder.add_child(warn)
	return holder


func _build_hero() -> Control:
	var v := _vbox(44)
	v.add_child(_text("QUI ES-TU ?", GREEN, 40, false))
	v.add_child(_text("16 ans. Geek, fan de dinosaures et de tout ce qui vient des années 90. Deux semaines de vacances chez Henriette et Albert.", Color(0.62, 0.6, 0.54)))
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
	v.add_child(_text("PAUSE", GREEN, 40, false))
	v.add_child(_button("Reprendre", func() -> void: resume_requested.emit()))
	v.add_child(_button("Options", func() -> void: show_options("pause")))
	v.add_child(_button("Quitter le jeu", func() -> void: get_tree().quit()))
	return v


func _slider(label: String, min_v: float, max_v: float, value: float, cb: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_child(_text(label, BEIGE, 16, false))
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
	v.add_child(_text("OPTIONS", GREEN, 40, false))
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
	for b in [title_box, pause_box, options_box, hero_box]:
		b.visible = b == box
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_title() -> void:
	_show(title_box)


func show_pause() -> void:
	_show(pause_box)


func show_options(from: String) -> void:
	back_target = from
	_show(options_box)
