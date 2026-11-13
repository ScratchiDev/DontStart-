extends "res://scripts/main.gd"
## Banc du relecteur « textes et règles » (exclu de l'export) : trois défauts supposés du scénario
## de l'étage (acte2.gd), rejoués dans la vraie maison avec les outils d'Autotest.
## R1 : coups sur P2 pendant l'éveil du couloir → ordre d'affichage des répliques de Nestor.
## R2 : P7 ouverte puis refermée → indice de l'étape « explorer ».
## R3 : P4 réel qui fait atteindre 100 → point de passage C2 écrit après ABSORBÉ ?
## godot --path godot --rendering-driver vulkan res://tests/relecteur_textes_banc.tscn -- --shots=DIR

var at: Autotest


func _ready() -> void:
	super()
	Game.autotest = true      # (sauvegarde de test, pas de chuchotements)
	_run.call_deferred()


func _run() -> void:
	at = Autotest.new()
	at.name = "AutotestRelecteur"
	add_child(at)
	at.setup(self)
	await at._jump_acte2()
	var hn: Haunt = haunt
	# ---------------------------------------------------------------- R1
	at.look_from(Vector3(4.0, 0, 1.0), Vector3(4.0, 1.3, -3.6))
	await at.until(func() -> bool: return hn.said("nestor").size() >= 1, 15.0)
	await at.wait(1.0)
	await at.use_at(Vector3(4.1, 0, -3.6), PI / 2.0, -0.1, "Frapper à la porte")
	# capture quand N5 s'affiche alors que N4 n'est pas encore dite
	var n5 := hn.fill(Acte2.N5)
	await at.until(func() -> bool: return hud.current_subtitle == n5, 40.0)
	print("R1 : N5 affichée ; N4 déjà dite : ", at.has_said("nestor", Acte2.N4), " ; objectif « ", Game.objective_text, " »")
	await at.wait(0.5)
	await at.shot("r1_n5_avant_n3")
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N7) and at.has_said("nestor", Acte2.N4), 90.0)
	await at.until(func() -> bool: return not hn.is_busy(), 40.0)
	var shown: Array = []
	for e in hud.subtitle_log:
		if str(e.who) == "Nestor":
			shown.append(str(e.text))
	print("R1 : ordre affiché : ", shown)
	var want: Array = []
	for l in [Acte2.N1, Acte2.N2, Acte2.N3, Acte2.N4, Acte2.N5, Acte2.N6, Acte2.N7]:
		want.append(hn.fill(l))
	at.check("R1 N1 à N7 dans l'ordre (coups pendant l'éveil)", shown.slice(0, 7) == want, str(shown))
	# ---------------------------------------------------------------- R2
	Game.add_item("cle_bureau", "Clé du bureau", "", "cle")
	var p7: Door = house.doors["P7"]
	p7.unlock()
	p7.open(0.2)
	await at.wait(0.6)
	var h_open := at._hint_text()
	p7.close(0.2)
	await at.wait(0.6)
	var h_closed := at._hint_text()
	print("R2 : porte_P7 = ", Game.flag("porte_P7", ""), " · indice ouverte « ", h_open, " » · refermée « ", h_closed, " »")
	at.check("R2 indice après P7 refermée", h_closed != Acte2.HINT_CABLE, "porte_P7 = %s · « %s »" % [Game.flag("porte_P7", ""), h_closed])
	# ---------------------------------------------------------------- R3
	await at.until(func() -> bool: return hn.has_logged("sos") and not hn.is_busy(), 60.0)
	var sb: Node = house.rooms["sdb"]
	(house.doors["P4"] as Door).set_open_now(true)
	Game.set_peur(90.0, "banc relecteur")
	await at.use_on(sb.dryer_it, Vector3(7.65, 0, -5.0), "Prendre le sèche-cheveux")
	var mirror: SmartMirror = sb.mirror
	await at.until(func() -> bool: return mirror.p4_running, 3.0)
	await at.wait(1.0)
	player.global_position = Vector3(4.0, 0, -4.4)      # le joueur sort : « fui » (+12)
	await at.until(func() -> bool: return acte2.p4_issue != "", 30.0)
	await at.wait(0.3)
	var sv := Game.load_checkpoint()
	print("R3 : issue %s · écran ABSORBÉ « %s » · phase %s · sauvegarde %s, peur %.1f, objectif « %s »" % [acte2.p4_issue,
		acte2.absorbed_screen, Game.phase, sv.get("checkpoint", "?"), float(sv.get("peur", -1.0)), Game.objective_text])
	at.check("R3 pas de C2 à 100 écrit pendant ABSORBÉ", not (str(sv.get("checkpoint", "")) == "C2" and float(sv.get("peur", 0.0)) >= 100.0),
		"sauvegarde %s · peur %.1f · ABSORBÉ « %s »" % [sv.get("checkpoint", "?"), float(sv.get("peur", -1.0)), acte2.absorbed_screen])
	await at.wait(1.5)
	await at.shot("r3_absorbe")
	at.finish()
