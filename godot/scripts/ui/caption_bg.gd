class_name CaptionBg
extends Control
## Fond des sous-titres (option « Fond des sous-titres », lot V3-INTERFACE) : un cartouche arrondi, noir
## translucide, ajusté à chaque ligne du texte d'une étiquette (Label ou RichTextLabel centrés) : lisible sur
## un éclair ou un mur clair sans couvrir l'image. Placé juste avant l'étiquette, dans le même parent.

var target: Control
var font: Font
var font_size := 12
var line_extra := 0.0        # interligne ajouté par l'étiquette (line_spacing / line_separation)
var pad := Vector2(7.0, 1.5)
var bottom := false          # texte aligné en bas de sa boîte (Label) ; sinon en haut (RichTextLabel)
var color := UiStyle.SCRIM
var enabled := true
var _para := TextParagraph.new()
var _key := ""
var _sb := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_sb.set_corner_radius_all(3)
	_sb.corner_detail = 5
	_sb.anti_aliasing = true


func _text() -> String:
	if target is RichTextLabel:
		return (target as RichTextLabel).get_parsed_text()
	if target is Label:
		return (target as Label).text
	return ""


## À appeler à chaque image où l'étiquette peut changer (le HUD le fait dans _process).
func refresh() -> void:
	var t := _text().strip_edges() if target else ""
	if not enabled or target == null or not target.is_visible_in_tree() or target.modulate.a < 0.02 or t == "" or font == null:
		visible = false
		return
	visible = true
	modulate.a = target.modulate.a
	position = target.position
	size = target.size
	var key := "%s|%d|%d|%s" % [t, int(size.x), font_size, font.get_instance_id()]
	if key != _key:
		_key = key
		_para.clear()
		_para.width = size.x
		_para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		_para.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_para.add_string(t, font, font_size)
	queue_redraw()


func _draw() -> void:
	var n := _para.get_line_count()
	if n == 0 or font == null:
		return
	_sb.bg_color = color
	var lh := font.get_height(font_size) + line_extra
	var y0 := size.y - n * lh if bottom else 0.0
	for i in n:
		var w := _para.get_line_width(i)
		if w <= 0.5:
			continue
		var x := (size.x - w) / 2.0
		var top := y0 + i * lh - (pad.y if i == 0 else 0.0) + (0.5 if i > 0 else 0.0)
		var bot := y0 + (i + 1) * lh + (pad.y if i == n - 1 else 0.0) - (0.5 if i < n - 1 else 0.0)
		_sb.draw(get_canvas_item(), Rect2(x - pad.x, top, w + 2.0 * pad.x, bot - top))
