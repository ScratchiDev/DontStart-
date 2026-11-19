class_name OptionRow
extends CheckBox
## Une ligne de l'écran Options (lot V3-INTERFACE) : le nom à gauche, la valeur à droite (« Oui », « ‹ Élevée › »,
## un curseur et sa valeur, des touches). Une seule commande focalisable par ligne : ↑ ↓ passent d'une ligne à
## l'autre, ← → règlent, Entrée (A) bascule ou choisit ; la souris survole, clique, fait glisser le curseur.
## C'est une CheckBox (C7 retrouve « Chuchotements (synthèse Windows) » par son texte et lit button_pressed) ;
## « text » garde le nom complet de la ligne, valeur comprise (« Qualité : ‹ Élevée › ») : les textes
## qu'attendent les tests et les lecteurs d'écran. Le dessin est fait ici (texte transparent pour la CheckBox).

signal value_changed(v: Variant)
signal focused_row(row: OptionRow)

enum Kind { TOGGLE, CHOICE, SLIDER, ACTION, BINDING, INFO }

var kind := Kind.ACTION
var label_text := ""
var value_text := ""
var help := ""
var choices: Array = []
var index := 0
var min_v := 0.0
var max_v := 1.0
var step_v := 0.01
var value := 0.0
var fmt: Callable
var net := true
var row_h := 17.0
var warn := false               # (touches) conflit, emplacement vide…
var slots: Array = ["", ""]     # (touches) noms affichés des deux emplacements
var slot_i := 0                 # (touches) emplacement choisi
var capturing := false          # (touches) en attente d'une touche
var pad_text := ""              # (touches) bouton de la manette
var _drag := false
const SLIDER_W := 84.0
var value_w := 150.0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	toggle_mode = false
	theme_type_variation = &"OptionRow"
	mouse_entered.connect(func() -> void:
		if not disabled and not has_focus():
			grab_focus())
	focus_entered.connect(func() -> void:
		UiStyle.play_ui("hover")
		focused_row.emit(self)
		queue_redraw())
	focus_exited.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func setup_toggle(name_: String, on: bool, help_: String = "") -> OptionRow:
	kind = Kind.TOGGLE
	label_text = name_
	text = name_
	help = help_
	toggle_mode = true
	set_pressed_no_signal(on)
	toggled.connect(func(v: bool) -> void:
		UiStyle.play_ui("click")
		value_changed.emit(v)
		queue_redraw())
	return self


func setup_choice(name_: String, choices_: Array, idx: int, help_: String = "") -> OptionRow:
	kind = Kind.CHOICE
	label_text = name_
	choices = choices_
	index = clampi(idx, 0, choices.size() - 1)
	help = help_
	_sync_text()
	pressed.connect(func() -> void: step_choice(1, true))
	return self


func setup_slider(name_: String, lo: float, hi: float, v: float, step_: float, fmt_: Callable, help_: String = "") -> OptionRow:
	kind = Kind.SLIDER
	label_text = name_
	min_v = lo
	max_v = hi
	step_v = step_ if step_ > 0.0 else (hi - lo) / 100.0
	value = clampf(v, lo, hi)
	fmt = fmt_
	help = help_
	_sync_text()
	return self


func setup_action(name_: String, value_: String = "", help_: String = "") -> OptionRow:
	kind = Kind.ACTION
	label_text = name_
	value_text = value_
	text = name_
	help = help_
	return self


func setup_info(name_: String, value_: String, help_: String = "") -> OptionRow:
	kind = Kind.INFO
	label_text = name_
	value_text = value_
	text = "%s : %s" % [name_, value_]
	help = help_
	focus_mode = Control.FOCUS_ALL
	return self


func setup_binding(name_: String, slots_: Array, pad_: String, help_: String = "") -> OptionRow:
	kind = Kind.BINDING
	label_text = name_
	help = help_
	set_slots(slots_, pad_)
	return self


func set_slots(slots_: Array, pad_: String) -> void:
	slots = slots_
	pad_text = pad_
	text = "%s : %s" % [label_text, " / ".join(slots_.filter(func(x: String) -> bool: return x != "—"))]
	queue_redraw()


func _sync_text() -> void:
	match kind:
		Kind.CHOICE:
			value_text = str(choices[index]) if not choices.is_empty() else ""
			text = "%s : ‹ %s ›" % [label_text, value_text]
		Kind.SLIDER:
			value_text = str(fmt.call(value)) if fmt.is_valid() else str(value)
			text = "%s : %s" % [label_text, value_text]
	queue_redraw()


func set_choice(i: int) -> void:
	index = clampi(i, 0, choices.size() - 1)
	_sync_text()


func set_value(v: float, emit := true) -> void:
	var nv := clampf(snappedf(v - min_v, step_v) + min_v, min_v, max_v)
	if is_equal_approx(nv, value):
		return
	value = nv
	_sync_text()
	if emit:
		value_changed.emit(value)


func step_choice(d: int, wrap := false) -> void:
	if choices.is_empty():
		return
	var n := index + d
	if wrap:
		n = posmod(n, choices.size())
	n = clampi(n, 0, choices.size() - 1)
	if n == index:
		return
	index = n
	_sync_text()
	UiStyle.play_ui("click")
	value_changed.emit(index)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	var left := event.is_action_pressed("ui_left", true)
	var right := event.is_action_pressed("ui_right", true)
	if left or right:
		var d := -1 if left else 1
		match kind:
			Kind.CHOICE:
				step_choice(d)
			Kind.SLIDER:
				set_value(value + d * step_v * (1.0 if (max_v - min_v) / step_v <= 40.0 else 5.0))
				UiStyle.play_ui("tick")
			Kind.TOGGLE:
				if (d > 0) != button_pressed:
					button_pressed = d > 0
			Kind.BINDING:
				slot_i = clampi(slot_i + d, 0, 1)
				UiStyle.play_ui("tick")
				queue_redraw()
		accept_event()
		return
	if kind == Kind.SLIDER and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed and _track_rect().grow(4.0).has_point(mb.position):
			_drag = true
			_set_from_x(mb.position.x)
			accept_event()
		elif not mb.pressed and _drag:
			_drag = false
			UiStyle.play_ui("tick")
			accept_event()
	elif kind == Kind.SLIDER and event is InputEventMouseMotion and _drag:
		_set_from_x((event as InputEventMouseMotion).position.x)
		accept_event()
	elif kind == Kind.BINDING and event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var x := (event as InputEventMouseButton).position.x
		var r1 := _slot_rect(1)
		slot_i = 1 if x >= r1.position.x - 4.0 else 0
		queue_redraw()


func _set_from_x(x: float) -> void:
	var r := _track_rect()
	set_value(lerpf(min_v, max_v, clampf((x - r.position.x) / r.size.x, 0.0, 1.0)))


func _value_x() -> float:
	return size.x - value_w


func _track_rect() -> Rect2:
	var y := size.y / 2.0
	return Rect2(_value_x() + 4.0, y - 1.0, SLIDER_W, 2.0)


func _slot_rect(i: int) -> Rect2:
	var w := (value_w - 52.0) / 2.0
	return Rect2(_value_x() + i * (w + 4.0), 2.0, w, size.y - 4.0)


func _draw() -> void:
	var font := get_theme_font("font")
	var fs := get_theme_font_size("font_size")
	var hot := has_focus() or (is_hovered() and not disabled)
	var c_name: Color
	var c_val: Color
	var c_dim: Color
	if net:
		if hot:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.055))
			draw_rect(Rect2(0, 2, 1.5, size.y - 4.0), UiStyle.ACCENT)
		c_name = UiStyle.INK if hot else Color(UiStyle.INK, 0.78)
		c_val = UiStyle.INK if hot else UiStyle.INK_DIM
		c_dim = UiStyle.INK_FAINT
		if disabled or kind == Kind.INFO:
			c_name = Color(UiStyle.INK_DIM, 0.9) if hot else UiStyle.INK_FAINT
	else:
		if hot:
			draw_rect(Rect2(Vector2.ZERO, size), UiStyle.GREEN)
		c_name = Color.BLACK if hot else UiStyle.BEIGE
		c_val = Color.BLACK if hot else UiStyle.GREEN
		c_dim = Color(0, 0, 0, 0.6) if hot else Color(0.5, 0.49, 0.44)
	var base := (size.y + font.get_ascent(fs) - font.get_descent(fs)) / 2.0
	var x0 := 8.0 if net else 6.0
	draw_string(font, Vector2(x0, base), label_text, HORIZONTAL_ALIGNMENT_LEFT, _value_x() - x0 - 6.0, fs, c_name)
	var vx := _value_x()
	match kind:
		Kind.TOGGLE:
			_draw_choice(font, fs, base, "Oui" if button_pressed else "Non", hot, c_val, c_dim)
		Kind.CHOICE:
			_draw_choice(font, fs, base, value_text, hot, c_val, c_dim)
		Kind.SLIDER:
			var r := _track_rect()
			var k := (value - min_v) / maxf(max_v - min_v, 0.0001)
			if net:
				draw_rect(r, Color(1, 1, 1, 0.16))
				draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), UiStyle.ACCENT if hot else Color(UiStyle.INK, 0.7))
				draw_circle(Vector2(r.position.x + r.size.x * k, r.get_center().y), 3.2 if hot else 2.6, UiStyle.INK, true, -1.0, true)
			else:
				draw_rect(Rect2(r.position.x, r.position.y - 1.0, r.size.x, 4.0), Color(0, 0, 0, 0.5) if hot else Color(0.2, 0.3, 0.2))
				draw_rect(Rect2(r.position.x, r.position.y - 1.0, r.size.x * k, 4.0), Color.BLACK if hot else UiStyle.GREEN)
			draw_string(font, Vector2(r.end.x + 8.0, base), value_text, HORIZONTAL_ALIGNMENT_LEFT, value_w - SLIDER_W - 12.0, fs, c_val)
		Kind.ACTION, Kind.INFO:
			if value_text != "":
				draw_string(font, Vector2(vx, base), value_text, HORIZONTAL_ALIGNMENT_LEFT, value_w, fs, c_val if kind == Kind.ACTION else c_dim)
		Kind.BINDING:
			for i in 2:
				var sr := _slot_rect(i)
				var sel := hot and i == slot_i
				var t := "…" if (capturing and i == slot_i) else str(slots[i] if i < slots.size() else "—")
				if net:
					var sb := UiStyle.box(Color(1, 1, 1, 0.10 if sel else 0.04), 2,
						(UiStyle.WARN if warn else UiStyle.ACCENT) if sel else Color(1, 1, 1, 0.14), 1)
					sb.draw(get_canvas_item(), sr)
				else:
					draw_rect(sr, Color(0, 0, 0, 0.35) if sel else Color(0, 0, 0, 0), true)
				var cc := (UiStyle.WARN if warn and t != "—" else c_val) if net else c_val
				if t == "—":
					cc = c_dim
				var sfs := fs - 1 if net else fs
				draw_string(font, Vector2(sr.position.x, base), t, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, sfs, cc)
			if pad_text != "":
				var sfs2 := (fs - 2) if net else fs
				draw_string(font, Vector2(_slot_rect(1).end.x + 4.0, base), pad_text, HORIZONTAL_ALIGNMENT_RIGHT,
					size.x - _slot_rect(1).end.x - 8.0, sfs2, c_dim)


func _draw_choice(font: Font, fs: int, base: float, t: String, hot: bool, c_val: Color, c_dim: Color) -> void:
	var vx := _value_x()
	var w := value_w - 10.0
	if hot:
		draw_string(font, Vector2(vx, base), "‹", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c_dim)
		draw_string(font, Vector2(vx + w - 4.0, base), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c_dim)
	draw_string(font, Vector2(vx, base), t, HORIZONTAL_ALIGNMENT_CENTER, w, fs, c_val)
