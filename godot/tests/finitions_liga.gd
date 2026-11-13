extends Node
## Banc « finitions » : la ligature « fi » de VT323, et sa suppression (exclu de l'export).
##   godot --headless --path godot res://tests/finitions_liga.tscn
func _ready() -> void:
	print("LIGA début")
	var f: FontFile = load("res://assets/fonts/VT323-Regular.ttf")
	print("LIGA police chargée")
	var ts := TextServerManager.get_primary_interface()
	var tag := ts.name_to_tag("liga")
	print("LIGA tag ", tag)
	var v := FontVariation.new()
	v.base_font = f
	v.opentype_features = {tag: 0}
	for word in ["fixé", "vérifie", "fermé", "Bonjour"]:
		var a := TextLine.new()
		a.add_string(word, f, 20)
		var b := TextLine.new()
		b.add_string(word, v, 20)
		print("LIGA %s : %d glyphes, %.0f px ; sans ligature : %d glyphes, %.0f px" % [word, ts.shaped_text_get_glyph_count(a.get_rid()), a.get_size().x, ts.shaped_text_get_glyph_count(b.get_rid()), b.get_size().x])
	get_tree().quit()
