extends "res://scripts/main.gd"
## Banc du relecteur 0.3.2 « textes et règles », dans la vraie maison, sans rendu (exclu de l'export) :
##   XDG_DATA_HOME=… godot --headless --path godot res://tests/relecteur032_textes_jeu.tscn
## 1. Convocation : N10, N11 (au mot près, par Nestor), O4, « Répondre à l'ordinateur ».
## 2. Indice de 90 s de l'étape « convocation » (§ 5.6.8) : texte, appareil (Nestor), jauge +1.
## 3. Séance 2 « Changer d'avis » dans le jeu : raisons de jauge au journal de Haunt (+8, +6), aucun
##    autre changement de jauge pendant la séance, prix_confirme.
## 4. Fin : carte § 5.6.10 au mot près ; la sauvegarde C3 garde sa jauge et note fin_v03.

var at: Autotest
var fails := 0


func _ready() -> void:
	super()
	Game.autotest = true          # (autopicks, sauvegarde de test ; l'autotest lui-même ne part pas)
	at = Autotest.new()
	at.name = "AT"
	add_child(at)
	at.setup(self)
	_run.call_deferred()


func _check(id: String, cond: bool, detail := "") -> void:
	print("R032J %s %s" % [id, "OK" if cond else "ÉCHEC : " + detail])
	if not cond:
		fails += 1


func _peur_events(from: int) -> Array:
	var out: Array = []
	for i in range(from, haunt.journal.size()):
		var e: Dictionary = haunt.journal[i]
		if e.get("ev") == "peur":
			out.append([e.get("why"), e.get("v")])
	return out


func _run() -> void:
	await at._jump_convocation(45.0, true, true, "fixe")
	var hn: Haunt = haunt
	await at.until(func() -> bool: return bool(Game.flag("convocation", false)), 60.0)
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N11) and not hn.is_busy(), 60.0)
	await at.wait(0.3)
	# ---------------------------------------------------------------- 1. textes de la convocation
	var said: Array = hn.said("nestor")
	_check("N10 N11 au mot près", said.slice(-2) == ["Ta mère avait une sonnerie pour moi. Celle-ci.", "Reviens dans sa chambre. On fait le point."], str(said.slice(-2)))
	var subs: Array = []
	for e in hud.subtitle_log:
		subs.append("%s|%s" % [e.get("who", ""), e.get("text", "")])
	print("  sous-titres (fin) : ", subs.slice(-3))
	_check("N10 N11 affichés par Nestor", subs.has("Nestor|Ta mère avait une sonnerie pour moi. Celle-ci.") and subs.has("Nestor|Reviens dans sa chambre. On fait le point."), str(subs.slice(-3)))
	_check("O4 au mot près", Game.objective_text == "Retourne à l'ordinateur de ta mère" and Game.objective_sub == "", "« %s » « %s »" % [Game.objective_text, Game.objective_sub])
	_check("libellé « Répondre à l'ordinateur »", room.pc_it.label == "Répondre à l'ordinateur" and room.pc_it.enabled, room.pc_it.label)
	var c3 := Game.load_checkpoint()
	var c3_peur := float(c3.get("peur", -1.0))
	print("  C3 : point %s · jauge %.1f" % [c3.get("checkpoint", "?"), c3_peur])
	# ---------------------------------------------------------------- 2. indice de l'étape « convocation »
	player.global_position = Vector3(4.0, 0.0, 0.6)       # au couloir (hors du refuge)
	var j0 := hn.journal.size()
	var p0 := Game.peur
	hn.hint_speed = 30.0
	var got_hint: bool = await at.until(func() -> bool: return hn.has_logged("indice", "step", "convocation"), 20.0)
	hn.hint_speed = 1.0
	var hint_e: Dictionary = {}
	for i in range(j0, hn.journal.size()):
		if hn.journal[i].get("ev") == "indice":
			hint_e = hn.journal[i]
	print("  indice : ", hint_e, " · jauge %.1f → %.1f" % [p0, Game.peur])
	_check("indice « convocation » (§ 5.6.8)", got_hint and str(hint_e.get("text", "")) == "L'ordinateur de ta mère sonne pour toi. Tu l'entends ?"
		and str(hint_e.get("dev", "")) == "nestor" and _peur_events(j0).has(["indice", 1.0]), str(hint_e))
	await at.until(func() -> bool: return not hn.is_busy(), 20.0)
	# ---------------------------------------------------------------- 3. séance 2 « Changer d'avis » → Mamie
	terminal.turbo = true
	terminal.autopicks = [1, 1]
	var j1 := hn.journal.size()
	var p1 := Game.peur
	await at.use_at(Vector3(1.2, 0, -1.0), 0.0, -0.3, "Répondre à l'ordinateur")
	await at.until(func() -> bool: return acte2.seance != null and (acte2.seance as Seance2).done, 120.0)
	var sc: Seance2 = acte2.seance
	var pe := _peur_events(j1)
	print("  séance 2 : issue %s · prix_confirme %s · jauge %.1f → %.1f · %s" % [sc.issue, Game.choices.get("prix_confirme"), p1, Game.peur, pe])
	_check("séance 2 changer : prix_confirme « proche » (Mamie)", sc.issue == "changer" and Game.choices.get("prix_confirme") == "proche", "%s %s" % [sc.issue, Game.choices.get("prix_confirme")])
	_check("séance 2 : jauge seance2_changer +8 puis seance2_coeur +6, rien d'autre", pe == [["seance2_changer", 8.0], ["seance2_coeur", 6.0]] and is_equal_approx(Game.peur - p1, 14.0), str(pe))
	_check("séance 2 : second choix « Moi » / « Mamie »", sc.said.has("Changer d'avis coûte. Je l'ai noté."), str(sc.said))
	# ---------------------------------------------------------------- 4. carte de fin et sauvegarde
	await at.until(func() -> bool: return acte2.end_card_shown, 40.0)
	await at.wait(0.5)
	var card_ok := false
	var texts: Array = []
	for n in hud.find_children("*", "Label", true, false):
		var l := n as Label
		if l.is_visible_in_tree() and l.text.contains("VERSION"):
			texts.append(l.text)
			if l.text == "FIN DE LA VERSION 0.3\n\nActe II · Essais réels — la suite : la chambre d'Henriette et Albert (version 0.4).\n\nLe cœur de ta grand-mère bat à 52.\n\nTa partie est gardée.":
				card_ok = true
	_check("carte § 5.6.10 au mot près", card_ok, str(texts))
	var sv := Game.load_checkpoint()
	_check("C3 garde sa jauge, note fin_v03", sv.get("checkpoint") == "C3" and is_equal_approx(float(sv.get("peur", -1.0)), c3_peur)
		and (sv.get("flags", {}) as Dictionary).get("fin_v03", false) == true, "point %s · jauge %.1f (C3 %.1f)" % [sv.get("checkpoint"), float(sv.get("peur", -1.0)), c3_peur])
	await at.until(func() -> bool: return Game.phase == "title", 30.0)
	print("R032J %s" % ("BANC OK" if fails == 0 else "BANC ÉCHEC %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)
