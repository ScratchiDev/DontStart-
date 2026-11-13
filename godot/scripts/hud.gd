extends CanvasLayer
## Interface en jeu : point de visée, invite [E], objectif (deux lignes), messages, sous-titres,
## disquette en main, mot ou image à lire en plein écran, écran en grand (console), inventaire,
## fondu au noir. Tout est en 640×360, police pixel VT323.

signal subtitle_shown(who: String, text: String)
signal screen_closed

const GREEN := Color(0.36, 1.0, 0.42)
const PAPER := Color(0.94, 0.9, 0.82)
const INK := Color(0.15, 0.16, 0.42)
## Couleurs des sous-titres : l'entité (vert phosphore), les proches (beige), les sons (gris).
const SUB_COLORS := {
	"elle": Color(0.42, 1.0, 0.5), "proche": Color(0.9, 0.82, 0.64), "son": Color(0.62, 0.62, 0.6),
	"autre": Color(0.88, 0.88, 0.86),
}
const ENTITY_NAMES := ["elle", "nestor", "console", "babyphone", "miroir", "imprimante", "télé", "enceinte"]
const PROCHE_NAMES := ["mamie", "papi", "henriette", "albert", "manon", "maman"]
## Les quatre pièces de l'arme (croquis de Manon), dans l'ordre de l'inventaire.
const WEAPON_LABELS := {"seche_cheveux": "Sèche-cheveux", "antenne": "Antenne", "boussole": "Boussole", "bobine": "Bobine"}

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
var objective_sub: Label
# sous-titres
var sub_lbl: RichTextLabel
var subtitle_log: Array = []        # lignes affichées, dans l'ordre : {who, text, kind}
var current_subtitle := ""          # texte affiché en ce moment ("" = rien)
var _sub_queue: Array = []
var _sub_left := 0.0
# image dans le lecteur de papiers, écran en grand
var paper_image: TextureRect
var paper_legend: Label
var _paper_lines: Array[Control] = []
var screen_view: Control
var screen_rect: TextureRect
var screen_open := false


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
	objective_sub = _label(Color(0.5, 0.54, 0.48, 0.8))
	objective_sub.add_theme_font_size_override("font_size", 14)
	objective_sub.position = Vector2(12, 21)
	root.add_child(objective_sub)

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

	sub_lbl = RichTextLabel.new()
	sub_lbl.bbcode_enabled = true
	sub_lbl.fit_content = true
	sub_lbl.scroll_active = false
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub_lbl.offset_left = 60
	sub_lbl.offset_right = -60
	sub_lbl.offset_top = -48
	sub_lbl.offset_bottom = -10
	sub_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub_lbl.add_theme_font_override("normal_font", Game.fonts.pixel)
	sub_lbl.add_theme_font_size_override("normal_font_size", 16)
	sub_lbl.add_theme_constant_override("outline_size", 4)
	sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	sub_lbl.add_theme_constant_override("line_separation", -2)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.visible = false
	root.add_child(sub_lbl)

	hand = _build_hand()
	hand.visible = false
	root.add_child(hand)

	paper = _build_paper()
	paper.visible = false
	root.add_child(paper)

	screen_view = _build_screen_view()
	screen_view.visible = false
	root.add_child(screen_view)

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

	Game.objective_changed.connect(_on_objective)
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
		_paper_lines.append(line)
	# feuille imprimée (plan, croquis, photo) : l'image remplace l'écriture
	paper_image = TextureRect.new()
	paper_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	paper_image.position = Vector2(8, 8)
	paper_image.size = Vector2(174, 234)
	paper_image.visible = false
	sheet.add_child(paper_image)
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
	paper_legend = _label(Color(0.85, 0.82, 0.74))
	paper_legend.set_anchors_preset(Control.PRESET_CENTER)
	paper_legend.position = Vector2(-280, 121)
	paper_legend.size = Vector2(560, 34)
	paper_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paper_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper_legend.add_theme_constant_override("line_spacing", -3)
	paper_legend.add_theme_constant_override("outline_size", 4)
	paper_legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	paper_legend.visible = false
	wrap.add_child(paper_legend)
	return wrap


## Un écran montré en grand (la console du bureau) : E ou Échap pour fermer.
func _build_screen_view() -> Control:
	var wrap := ColorRect.new()
	wrap.color = Color(0, 0, 0, 0.88)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bezel := ColorRect.new()
	bezel.color = Color(0.07, 0.07, 0.08)
	bezel.set_anchors_preset(Control.PRESET_CENTER)
	bezel.size = Vector2(588, 334)
	bezel.position = Vector2(-294, -175)
	wrap.add_child(bezel)
	screen_rect = TextureRect.new()
	screen_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen_rect.position = Vector2(6, 6)
	screen_rect.size = Vector2(576, 322)
	bezel.add_child(screen_rect)
	var foot := _label(Color(0.7, 0.68, 0.6))
	foot.text = "E OU ÉCHAP POUR FERMER"
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.position = Vector2(-80, -20)
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
	panel.position = Vector2(-244, -160)
	panel.size = Vector2(232, 40)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_list = RichTextLabel.new()
	inv_list.bbcode_enabled = true
	inv_list.fit_content = true
	inv_list.scroll_active = false
	inv_list.custom_minimum_size = Vector2(216, 0)
	inv_list.add_theme_font_override("normal_font", Game.fonts.pixel)
	inv_list.add_theme_font_size_override("normal_font_size", 15)
	inv_list.add_theme_color_override("default_color", Color(0.8, 0.78, 0.7))
	inv_list.add_theme_constant_override("line_separation", -4)
	inv_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inv_list)
	_refresh_inventory.call_deferred()
	return panel


func _refresh_inventory() -> void:
	var g := GREEN.to_html(false)
	var dim := "6f7a68"
	var grey := "4a4f48"
	var t := "[color=#%s]INVENTAIRE[/color]   [color=#%s][lb]Tab[rb][/color]\n" % [g, dim]
	if Game.items.is_empty():
		t += "\n[color=#%s]Rien. Tes poches sont vides.[/color]" % dim
	var titles := {"arme": "PIÈCES DE L'ARME", "outil": "OUTILS", "cle": "CLÉS", "doc": "DOCUMENTS", "objet": "OBJETS"}
	for kind in Game.KINDS:
		if kind == "arme":
			if weapon_section_visible():
				t += "\n[color=#%s]%s[/color]\n" % [g, titles[kind]]
				t += "Croquis de Maman : %d/4\n" % weapon_count()
				for id in Game.WEAPON_PARTS:
					var it := _item(id)
					if it.is_empty():
						t += "[color=#%s]· %s[/color]\n" % [grey, WEAPON_LABELS[id]]
					else:
						t += "· %s\n" % _esc(it.name)
						if it.desc != "":
							t += "[font_size=13][color=#%s]  %s[/color][/font_size]\n" % [dim, _esc(it.desc)]
			# autres objets de sorte « arme » (aucun en v0.3)
			for it in Game.items:
				if it.kind == "arme" and not Game.WEAPON_PARTS.has(it.id):
					t += "· %s\n" % _esc(it.name)
			continue
		var first := true
		for it in Game.items:
			if it.kind != kind:
				continue
			if first:
				t += "\n[color=#%s]%s[/color]\n" % [g, titles.get(kind, kind.to_upper())]
				first = false
			t += "· %s\n" % _esc(it.name)
			if it.desc != "":
				t += "[font_size=13][color=#%s]  %s[/color][/font_size]\n" % [dim, _esc(it.desc)]
	inv_list.text = t.strip_edges(false, true)
	if inv:
		inv.reset_size.call_deferred()


func _item(id: String) -> Dictionary:
	for it in Game.items:
		if it.id == id:
			return it
	return {}


## Nombre de pièces de l'arme ramassées (sur les quatre du croquis).
func weapon_count() -> int:
	var n := 0
	for id in Game.WEAPON_PARTS:
		if Game.has_item(id):
			n += 1
	return n


## La section « Pièces de l'arme » apparaît dès qu'on a vu le croquis (journal, impression) ou une pièce.
func weapon_section_visible() -> bool:
	return weapon_count() > 0 or Game.has_item("journal_manon") or Game.has_item("croquis_imprime") or bool(Game.flag("croquis_lu"))


## Échappe les crochets pour le BBCode.
static func _esc(s: String) -> String:
	var out := ""
	for ch in s:
		if ch == "[":
			out += "[lb]"
		elif ch == "]":
			out += "[rb]"
		else:
			out += ch
	return out


func _on_objective(text: String) -> void:
	var parts := text.split("\n", true, 1)
	objective.text = parts[0]
	objective_sub.text = parts[1] if parts.size() > 1 else ""


func toggle_inventory() -> void:
	inv_open = not inv_open
	inv.visible = inv_open
	if inv_open:
		# l'inventaire ouvert dit déjà ce qu'on vient de ramasser : pas de bandeau par-dessus
		if _toast_tw:
			_toast_tw.kill()
		toast.modulate.a = 0.0
	Sfx.play("cloth", -14.0, 1.2)


func _on_item_added(_id: String, label: String) -> void:
	toast.text = "+ " + label
	if _toast_tw:
		_toast_tw.kill()
	if inv_open:
		toast.modulate.a = 0.0
		return
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
	# sous-titres : la ligne courante, puis la suivante de la file
	if current_subtitle != "":
		_sub_left -= delta
		if _sub_left <= 0.0:
			_next_subtitle()
	if sub_lbl.visible:
		# au-dessus de la pensée du héros quand elle est affichée
		var above := hint_lbl.modulate.a > 0.05 and hint_lbl.text != ""
		sub_lbl.offset_bottom = -58.0 if above else -12.0
		sub_lbl.offset_top = sub_lbl.offset_bottom - 38.0


# ------------------------------------------------------------------ sous-titres

## Sous-titre « qui : texte », coloré selon le locuteur (kind : "elle", "proche", "son", "autre" ;
## vide = deviné d'après « who »). Durée : 2 s + 0,06 s par caractère ; les lignes attendent leur tour.
## on_show est appelé quand la ligne s'affiche. Renvoie le temps (s) jusqu'à la fin de cette ligne.
func subtitle(who: String, text: String, kind := "", on_show := Callable()) -> float:
	if kind == "":
		kind = speaker_kind(who)
	var dur := 2.0 + 0.06 * text.length()
	var wait := maxf(_sub_left, 0.0) if current_subtitle != "" else 0.0
	for q in _sub_queue:
		wait += float(q.dur)
	_sub_queue.append({"who": who, "text": text, "kind": kind, "dur": dur, "cb": on_show})
	if current_subtitle == "":
		_next_subtitle()
	return wait + dur


## Sous-titre d'un son important, entre crochets et en gris, seulement si l'option est active
## (ou force = true). Renvoie sa durée (0 s'il n'est pas affiché).
func sound_caption(text: String, force := false) -> float:
	if not Game.sound_captions and not force:
		return 0.0
	var t := text if text.begins_with("[") else "[" + text + "]"
	return subtitle("", t, "son")


static func speaker_kind(who: String) -> String:
	var w := who.to_lower()
	if w == "":
		return "son"
	for n in PROCHE_NAMES:
		if w.contains(n):
			return "proche"
	for n in ENTITY_NAMES:
		if w.begins_with(n):
			return "elle"
	return "autre"


func _next_subtitle() -> void:
	if _sub_queue.is_empty():
		current_subtitle = ""
		_sub_left = 0.0
		var tw := create_tween()
		tw.tween_property(sub_lbl, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			if current_subtitle == "":
				sub_lbl.visible = false)
		return
	var q: Dictionary = _sub_queue.pop_front()
	var c: Color = SUB_COLORS.get(q.kind, SUB_COLORS.autre)
	var body := "[color=#%s]%s[/color]" % [c.to_html(false), _esc(q.text)]
	if q.who != "":
		var cw := c.darkened(0.25) if q.kind != "son" else c
		body = "[color=#%s]%s\u00a0:[/color] %s" % [cw.to_html(false), _esc(q.who), body]
	sub_lbl.text = "[center]%s[/center]" % body
	sub_lbl.visible = true
	sub_lbl.modulate.a = 1.0
	current_subtitle = q.text
	_sub_left = q.dur
	subtitle_log.append({"who": q.who, "text": q.text, "kind": q.kind})
	subtitle_shown.emit(q.who, q.text)
	var cb: Callable = q.cb
	if cb.is_valid():
		cb.call()


## Efface les sous-titres (la ligne courante et la file).
func clear_subtitles() -> void:
	_sub_queue.clear()
	current_subtitle = ""
	_sub_left = 0.0
	sub_lbl.visible = false


## Lecture en cours (papier, image, écran) : pas d'indice, pas de déplacement.
func is_reading() -> bool:
	return paper_open or screen_open


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
	_paper_mode_image(false)
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


## Feuille imprimée : l'image sur la feuille, la légende (pensée du héros) dessous.
func read_image(texture: Texture2D, legend := "") -> void:
	_pages = []
	read_paper("")
	_paper_mode_image(true)
	paper_image.texture = texture
	paper_legend.text = legend
	paper_legend.visible = legend != ""


func _paper_mode_image(on: bool) -> void:
	paper_image.visible = on
	paper_text.visible = not on
	for l in _paper_lines:
		l.visible = not on
	if not on:
		paper_legend.visible = false


func close_paper() -> void:
	_pages = []
	paper_text.add_theme_font_size_override("font_size", 26)
	_paper_mode_image(false)
	paper.visible = false
	paper_open = false
	if player:
		player.can_move = true
		player.can_look = true
	Sfx.play("bookClose", -12.0)


## Montre un écran en grand (la console et ses caméras) ; E ou Échap pour fermer.
func show_screen(texture: Texture2D) -> void:
	screen_rect.texture = texture
	screen_view.visible = true
	screen_open = true
	prompt.visible = false
	if player:
		player.can_move = false
		player.can_look = false
	Sfx.play("metalClick", -18.0, 1.6)


func close_screen() -> void:
	if not screen_open:
		return
	screen_view.visible = false
	screen_open = false
	screen_rect.texture = null
	if player:
		player.can_move = true
		player.can_look = true
	screen_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if screen_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close_screen()
		return
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
