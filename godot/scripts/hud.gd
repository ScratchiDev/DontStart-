extends CanvasLayer
## Interface en jeu : point de visée, invite [E], objectif, messages, disquette en main,
## mot à lire en plein écran, fondu au noir. Tout est en 640×360, police pixel VT323.

const GREEN := Color(0.36, 1.0, 0.42)
const PAPER := Color(0.94, 0.9, 0.82)
const INK := Color(0.15, 0.16, 0.42)

var player: Node
var root: Control
var crosshair: ColorRect
var prompt: Label
var objective: Label
var hint_lbl: Label
var hand: Control
var paper: Control
var paper_text: Label
var fade: ColorRect
var paper_open := false
var paper_foot: Label
var _pages: Array = []
var _page_i := 0
var _hint_left := 0.0
var inv: Control
var inv_list: RichTextLabel
var inv_open := false
var toast: Label
var _toast_tw: Tween


func _ready() -> void:
	add_to_group("hud")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = Game.fonts.pixel
	th.default_font_size = 16
	root.theme = th
	add_child(root)

	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.45)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.size = Vector2(2, 2)
	crosshair.position = Vector2(-1, -1)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	prompt = _label(GREEN)
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.position = Vector2(-160, 26)
	prompt.size = Vector2(320, 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	prompt.add_theme_stylebox_override("normal", sb)
	prompt.visible = false
	root.add_child(prompt)

	objective = _label(Color(0.62, 0.66, 0.6, 0.85))
	objective.position = Vector2(10, 6)
	root.add_child(objective)

	hint_lbl = _label(Color(0.85, 0.82, 0.74))
	hint_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_lbl.offset_left = 72
	hint_lbl.offset_right = -72
	hint_lbl.offset_top = -52
	hint_lbl.offset_bottom = -10
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_constant_override("outline_size", 4)
	hint_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_lbl.modulate.a = 0.0
	root.add_child(hint_lbl)

	hand = _build_hand()
	hand.visible = false
	root.add_child(hand)

	paper = _build_paper()
	paper.visible = false
	root.add_child(paper)

	inv = _build_inventory()
	inv.visible = false
	root.add_child(inv)

	toast = _label(GREEN)
	toast.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast.position = Vector2(-250, -84)
	toast.size = Vector2(240, 18)
	toast.add_theme_constant_override("outline_size", 4)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast.modulate.a = 0.0
	root.add_child(toast)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	Game.objective_changed.connect(func(t: String) -> void: objective.text = t)
	Game.hint_requested.connect(show_hint)
	Game.inventory_changed.connect(_refresh_inventory)
	Game.item_added.connect(_on_item_added)


func _label(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_hand() -> Control:
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.07)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.size = Vector2(40, 40)
	box.position = Vector2(-52, -52)
	box.rotation = 0.18
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := TextureRect.new()
	lab.texture = load("res://assets/images/floppy_label.png")
	lab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lab.stretch_mode = TextureRect.STRETCH_SCALE
	lab.position = Vector2(4, 3)
	lab.size = Vector2(32, 12)
	box.add_child(lab)
	var hub := ColorRect.new()
	hub.color = Color(0.38, 0.35, 0.3)
	hub.position = Vector2(16, 22)
	hub.size = Vector2(8, 8)
	box.add_child(hub)
	return box


func _build_paper() -> Control:
	var wrap := ColorRect.new()
	wrap.color = Color(0, 0, 0, 0.7)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sheet := ColorRect.new()
	sheet.color = PAPER
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.size = Vector2(190, 250)
	sheet.position = Vector2(-95, -132)
	sheet.rotation = -0.025
	wrap.add_child(sheet)
	for i in 10:
		var line := ColorRect.new()
		line.color = Color(0.6, 0.64, 0.82, 0.45)
		line.position = Vector2(0, 38 + i * 21)
		line.size = Vector2(190, 1)
		sheet.add_child(line)
	paper_text = Label.new()
	paper_text.add_theme_font_override("font", Game.fonts.hand)
	paper_text.add_theme_font_size_override("font_size", 26)
	paper_text.add_theme_color_override("font_color", INK)
	paper_text.add_theme_constant_override("line_spacing", -7)
	paper_text.position = Vector2(20, 18)
	paper_text.size = Vector2(160, 220)
	paper_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(paper_text)
	var foot := _label(Color(0.7, 0.68, 0.6))
	paper_foot = foot
	foot.text = "E OU ÉCHAP POUR REPOSER"
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.position = Vector2(-80, -22)
	wrap.add_child(foot)
	return wrap


func _build_inventory() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.02, 0.01, 0.82)
	sb.border_color = Color(GREEN, 0.5)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-236, -120)
	panel.size = Vector2(224, 240)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_list = RichTextLabel.new()
	inv_list.bbcode_enabled = true
	inv_list.fit_content = false
	inv_list.scroll_active = false
	inv_list.custom_minimum_size = Vector2(208, 224)
	inv_list.add_theme_font_override("normal_font", Game.fonts.pixel)
	inv_list.add_theme_font_size_override("normal_font_size", 16)
	inv_list.add_theme_color_override("default_color", Color(0.8, 0.78, 0.7))
	inv_list.add_theme_constant_override("line_separation", -3)
	inv_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inv_list)
	_refresh_inventory.call_deferred()
	return panel


func _refresh_inventory() -> void:
	var g := GREEN.to_html(false)
	var dim := "6f7a68"
	var t := "[color=#%s]INVENTAIRE[/color]   [color=#%s][Tab][/color]\n" % [g, dim]
	if Game.items.is_empty():
		t += "\n[color=#%s]Rien. Tes poches sont vides.[/color]" % dim
	for kind in ["arme", "cle", "doc", "objet"]:
		var first := true
		for it in Game.items:
			if it.kind != kind:
				continue
			if first:
				var title: String = {"arme": "PIÈCES DE L'ARME", "cle": "CLÉS", "doc": "DOCUMENTS", "objet": "OBJETS"}[kind]
				t += "\n[color=#%s]%s[/color]\n" % [g, title]
				first = false
			t += "· %s\n" % it.name
			if it.desc != "":
				t += "  [color=#%s]%s[/color]\n" % [dim, it.desc]
	inv_list.text = t


func toggle_inventory() -> void:
	inv_open = not inv_open
	inv.visible = inv_open
	Sfx.play("cloth", -14.0, 1.2)


func _on_item_added(_id: String, label: String) -> void:
	toast.text = "+ " + label
	if _toast_tw:
		_toast_tw.kill()
	toast.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.6)
	_toast_tw.tween_property(toast, "modulate:a", 0.0, 0.8)


func set_prompt(it: Interactable) -> void:
	if it and Game.phase == "room":
		prompt.text = "[E] " + it.label
		prompt.visible = true
		crosshair.color = Color(GREEN, 0.9)
		crosshair.size = Vector2(3, 3)
		crosshair.position = Vector2(-1.5, -1.5)
	else:
		prompt.visible = false
		crosshair.color = Color(1, 1, 1, 0.45)
		crosshair.size = Vector2(2, 2)
		crosshair.position = Vector2(-1, -1)


func show_hint(text: String, seconds := 3.5) -> void:
	hint_lbl.text = text
	_hint_left = seconds
	create_tween().tween_property(hint_lbl, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	if player and prompt.visible and player.current:
		prompt.text = "[E] " + player.current.label
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0:
			create_tween().tween_property(hint_lbl, "modulate:a", 0.0, 0.6)


func show_crosshair(v: bool) -> void:
	crosshair.visible = v


func show_hand(v: bool) -> void:
	hand.visible = v


## Carnet de plusieurs pages : E pour tourner la page.
func read_pages(pages: Array, font_size := 21) -> void:
	_pages = pages
	_page_i = 0
	paper_text.add_theme_font_size_override("font_size", font_size)
	read_paper(pages[0])
	paper_foot.text = "E : PAGE SUIVANTE (1/%d)" % pages.size()


func _next_page() -> void:
	_page_i += 1
	if _page_i >= _pages.size():
		_pages = []
		paper_text.add_theme_font_size_override("font_size", 26)
		close_paper()
		return
	paper_text.text = _pages[_page_i]
	Sfx.play("bookFlip1", -10.0)
	paper_foot.text = ("E : PAGE SUIVANTE (%d/%d)" if _page_i < _pages.size() - 1 else "E OU ÉCHAP POUR REPOSER (%d/%d)") % [_page_i + 1, _pages.size()]


func read_paper(text: String) -> void:
	paper_text.text = text
	if _pages.is_empty():
		paper_foot.text = "E OU ÉCHAP POUR REPOSER"
	paper.visible = true
	paper_open = true
	prompt.visible = false
	if player:
		player.can_move = false
		player.can_look = false
	Sfx.play("bookOpen", -10.0)


func close_paper() -> void:
	_pages = []
	paper_text.add_theme_font_size_override("font_size", 26)
	paper.visible = false
	paper_open = false
	if player:
		player.can_move = true
		player.can_look = true
	Sfx.play("bookClose", -12.0)


func _unhandled_input(event: InputEvent) -> void:
	if paper_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if not _pages.is_empty():
			_next_page()
		else:
			close_paper()
	elif event.is_action_pressed("inventory") and Game.phase == "room" and not get_tree().paused:
		get_viewport().set_input_as_handled()
		toggle_inventory()


func fade_to(alpha: float, seconds := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, seconds)
	await tw.finished


## Carton de texte sur fond noir (épilogue, fin d'acte). Le fondu doit déjà être au noir.
func card(lines: Array, seconds := 5.0) -> void:
	var l := Label.new()
	l.text = "\n".join(lines)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.offset_left = 60
	l.offset_right = -60
	l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	l.add_theme_constant_override("line_spacing", 4)
	l.modulate.a = 0.0
	root.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 1.2)
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	await tw.finished
	l.queue_free()
