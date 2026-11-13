extends Node
## Banc de relecteur032_joueur (exclu de l'export) : compile ses scripts de test.

func _ready() -> void:
	var s: Script = load("res://tests/relecteur032_joueur_fin.gd")
	print("PARSE relecteur032 %s" % ("OK" if s != null and s.can_instantiate() else "ÉCHEC"))
	get_tree().quit()
