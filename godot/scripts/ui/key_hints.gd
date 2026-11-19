class_name KeyHints
extends HBoxContainer
## Rangée d'aides de touches du style net (lot V3-INTERFACE) : [E] Reposer   [T] Transcription.
## Chaque aide : une action (sa touche ou son bouton selon le dernier périphérique utilisé) ou un texte fixe
## (« Entrée »), puis son libellé. Se met à jour quand on passe du clavier à la manette.

var _hints: Array = []      # [[action ou "=texte", libellé], ...]
var _size := UiStyle.SMALL
var _color := UiStyle.INK_DIM


func _init(hints: Array = [], size := UiStyle.SMALL, color := UiStyle.INK_DIM) -> void:
	_hints = hints
	_size = size
	_color = color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 5)


func _ready() -> void:
	Game.input_device_changed.connect(func(_p: bool) -> void: _rebuild())
	_rebuild()


func set_hints(hints: Array) -> void:
	_hints = hints
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var pad := bool(Game.pad_active)
	var first := true
	for h in _hints:
		if not first:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(8, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(gap)
		first = false
		var keys: Array = h[0] if h[0] is Array else [h[0]]
		for k in keys:
			var t := str(k)
			var g := t.substr(1) if t.begins_with("=") else Controles.glyph(t, pad)
			if t.begins_with("=") and pad and h.size() > 2:
				g = str(h[2])
			add_child(UiStyle.keycap(g, _size, pad and g.length() == 1))
		if str(h[1]) != "":
			var l := UiStyle.label(str(h[1]), UiStyle.sans(), _size + 1, _color, true)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(l)
