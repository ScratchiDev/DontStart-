extends Node
## Banc corrections032 (exclu de l'export) : compile les scripts de test touchés en 0.3.2 (le banc
## parse_check ne voit que scripts/).  godot --headless --path godot res://tests/corrections032_parse.tscn

func _ready() -> void:
	var bad := 0
	var d := DirAccess.open("res://tests/")
	for f in d.get_files():
		if not f.ends_with(".gd") or f == "corrections032_parse.gd":
			continue
		var s: Script = load("res://tests/" + f)
		if s == null or not s.can_instantiate():
			print("SCRIPT KO res://tests/", f)
			bad += 1
	print("TESTS %s" % ("OK" if bad == 0 else "ÉCHEC %d" % bad))
	get_tree().quit()
