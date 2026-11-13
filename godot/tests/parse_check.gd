extends Node
## Charge tous les scripts du jeu et des appareils (erreurs de compilation) : godot --headless --path godot
## res://tests/parse_check.tscn (exclu de l'export).

func _ready() -> void:
	var bad := 0
	for dir in ["res://scripts/", "res://scripts/devices/", "res://scripts/house/", "res://scripts/house/rooms/"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var s: Script = load(dir + f)
			if s == null or not s.can_instantiate():
				print("SCRIPT KO ", dir + f)
				bad += 1
	print("ANALYSE %s" % ("OK" if bad == 0 else "ÉCHEC %d" % bad))
	get_tree().quit()
