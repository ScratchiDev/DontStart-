extends Node
## Relecteur 0.3.2 (exclu de l'export) : la police du terminal (Game.fonts.pixel, VT323) fusionne-t-elle
## « fi » dans les textes de la séance 2 ? Largeur mesurée avec et sans la ligature (Connected.no_liga).

func _ready() -> void:
	var f: Font = Game.fonts.pixel
	var nl: Font = Connected.no_liga(f)
	for s in ["Tu confirmes ?", "[1] Confirmer", "Confirmation", "CONFIRMATION", "Consigné."]:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var w2 := nl.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var cell := nl.get_string_size("a", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		print("LIGA « %s » : %d caractères · police du terminal %.0f px (%.1f cases) · sans ligature %.0f px (%.1f cases)" % [s, s.length(), w, w / cell, w2, w2 / cell])
	get_tree().quit()
