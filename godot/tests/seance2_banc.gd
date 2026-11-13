extends Node
## Banc de la séance 2 (sans rendu) : godot --headless --path godot res://tests/seance2_banc.tscn
## Seance2.results_lines (9 combinaisons), duration_text, prix_word, other_options ; le cœur du
## terminal (show_heart, set_heart, hide_heart) et pick (last_timeout, timeout_fear). Exclu de l'export.

var bad := 0


func _check(id: String, cond: bool, detail := "") -> void:
	if cond:
		print("BANC %s OK" % id)
	else:
		bad += 1
		print("BANC %s ÉCHEC : %s" % [id, detail])


func _ready() -> void:
	for a in ["retourne", "fixe", "yeux_fermes"]:
		for b in ["fixe", "retourne", "fui"]:
			print("%s / %s → %s" % [a, b, Seance2.results_lines(a, b)])
	_check("constant retourne", Seance2.results_lines("retourne", "retourne")[2] == "Constant. J'aime les sujets constants.")
	_check("constant fixe", Seance2.results_lines("fixe", "fixe") == ["PROTOCOLE 4 · SIMULATION ..... FIXÉ", "PROTOCOLE 4 · ESSAI RÉEL ..... RECONNU", "Constant. J'aime les sujets constants."])
	_check("changé", Seance2.results_lines("yeux_fermes", "fui") == ["PROTOCOLE 4 · SIMULATION ..... YEUX FERMÉS", "PROTOCOLE 4 · ESSAI RÉEL ..... FUITE", "Tu as changé. Je l'ai noté."])
	for s in [3.0, 40.0, 57.0, 58.0, 60.0, 64.0, 66.0, 90.0, 121.0, 128.0, 190.0, 594.0, 596.0, 734.0, 3600.0, 3900.0, 7300.0]:
		print("%6.0f s → %s" % [s, Seance2.duration_text(s)])
	_check("40 s", Seance2.duration_text(40.0) == "40 secondes")
	_check("2 min", Seance2.duration_text(121.0) == "2 minutes")
	_check("3 min 10", Seance2.duration_text(190.0) == "3 minutes et 10 secondes")
	_check("1 min", Seance2.duration_text(60.0) == "1 minute")
	_check("prix_word", Seance2.prix_word("toi", "Papi") == "Moi" and Seance2.prix_word("proche", "Papi") == "Papi" and Seance2.prix_word("personne", "Papi") == "Personne")
	_check("other_options", Seance2.other_options("personne") == [0, 1] and Seance2.other_options("proche") == [0, 2] and Seance2.other_options("toi") == [1, 2])
	# le terminal (hors de l'écran) : l'afficheur du cœur
	var T: Control = (load("res://scripts/terminal.gd") as GDScript).new()
	add_child(T)
	await get_tree().process_frame
	T.show_heart(58)
	T.set_heart(57)
	T.set_heart(55)
	T.set_heart(52)
	_check("cœur", T.heart_log == [58, 57, 55, 52] and T.heart_box.visible and T.heart_val.text == "52" and T.heart_val.get_theme_font_size("font_size") == T.HEART_FONT, str(T.heart_log))
	T.hide_heart()
	_check("cœur caché", not T.heart_box.visible and T.heart_bpm == 0)
	T.turbo = true
	var p0: float = Game.peur
	var r: int = await T.pick(["Confirmer", "Changer d'avis"], 0.3, 1, Callable(), 0.0)
	_check("pick délai", r == 1 and T.last_timeout and is_equal_approx(Game.peur, p0), "r %d · délai %s · peur %.1f → %.1f" % [r, T.last_timeout, p0, Game.peur])
	print("BANC %s" % ("OK" if bad == 0 else "ÉCHEC %d" % bad))
	get_tree().quit(0 if bad == 0 else 1)
