extends "res://scripts/main.gd"
## Banc du relecteur032_sauve (exclu de l'export) : sauvegarde, reprise et non-régression de la 0.3.2,
## par le VRAI chemin du jeu (sans --autotest : user://sauvegarde.json, user://journal.txt, la fin de
## la version et l'épilogue rechargent la scène comme chez le joueur).
##   XDG_DATA_HOME=<dossier avec une sauvegarde 0.3.1> godot [--headless] --path godot \
##       res://tests/relecteur032_sauve_banc.tscn -- [--shots=DIR]
## Étapes (méta de l'Engine, survit aux rechargements) :
##   A  sauvegarde 0.3.1 (fin_031) → « Continuer » → convocation, C3 → séance 2 « Confirmer » → fin
##      de la version (la scène se recharge toute seule) ;
##   B  titre → « Continuer » : C3 sans carte fantôme, modem qui rappelle → ABSORBÉ hors séance juste
##      après la convocation (l'épilogue recharge) ;
##   C  titre → « Continuer » : C3 intact → rechargement (relance du jeu) ;
##   D  titre → « Nouvelle partie » : tout est effacé, journal.txt remis à zéro → quitter.
## Lignes « SAUVE VÉRIF <id> OK|ÉCHEC : … » ; dernière ligne « SAUVE FINI n échec(s) ».

const META := "relecteur032_sauve_etape"
const META_N := "relecteur032_sauve_compte"
const META_C3 := "relecteur032_sauve_c3"
var shots := ""
var n_ok := 0
var n_ko := 0
var cas := ""         # --cas=s2abs : ABSORBÉ pendant la séance 2 (vrai chemin), reprise de C3, quitter
var quit_at := ""      # --quitter=B : quitter le jeu (comme « Quitter le jeu ») juste après la reprise de C3


func _ready() -> void:
	super()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--quitter="):
			quit_at = a.substr(10)
		elif a.begins_with("--cas="):
			cas = a.substr(6)
		elif a.begins_with("--pas="):
			# (comme Autotest.real_time_pace : pas de physique par image ; diagnostic du blocage à la sortie)
			Engine.max_physics_steps_per_frame = int(a.substr(6))
	var c: Array = Engine.get_meta(META_N, [0, 0])
	n_ok = int(c[0])
	n_ko = int(c[1])
	_run.call_deferred()


func ck(id: String, cond: bool, detail := "") -> void:
	if cond:
		n_ok += 1
		print("SAUVE VÉRIF %s OK" % id)
	else:
		n_ko += 1
		print("SAUVE VÉRIF %s ÉCHEC : %s" % [id, detail])
	Engine.set_meta(META_N, [n_ok, n_ko])


func w(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func until(cond: Callable, timeout := 60.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= timeout:
		print("SAUVE attente trop longue")
		return false
	return true


func snap(n: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(shots.path_join(n + ".png"))
		print("SAUVE capture ", n)


func save_file() -> Dictionary:
	var p := Game.save_path()
	if not FileAccess.file_exists(p):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


func journal_txt() -> String:
	var p := Haunt.times_path()
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func card_visible() -> String:
	for c in hud.root.find_children("*", "Label", true, false):
		var l := c as Label
		if l.is_visible_in_tree() and l.modulate.a > 0.01 and (l.text.contains("FIN DE LA VERSION") or l.text.contains("Au matin")):
			return l.text.substr(0, 40)
	return ""


func _run() -> void:
	var stage := str(Engine.get_meta(META, "A"))
	print("SAUVE étape ", stage, " · autotest ", Game.autotest, " · sauvegarde ", Game.save_path())
	match stage:
		"A" when cas == "s2abs":
			await _s2abs_a()
		"A" when cas == "convabs":
			await _convabs_a()
		"S":
			await _s2abs_s()
		"A":
			await _stage_a()
		"B":
			await _stage_b()
		"C":
			await _stage_c()
		"D":
			await _stage_d()


func _from_title() -> void:
	await w(0.5)
	menu.show_title()
	await w(0.5)


## A : la sauvegarde de la 0.3.1 (fin_031), écrite par le code 0.3.1.
func _stage_a() -> void:
	var before := save_file()
	ck("A sauvegarde 0.3.1 présente", before.get("version") == "0.3.1" and (before.get("flags", {}) as Dictionary).get("fin_031", false) == true,
		"%s" % [before.get("version")])
	await _from_title()
	ck("A titre : « Continuer » visible", menu.continue_btn.visible and Game.has_save(), "")
	await snap("a0_titre")
	menu.continue_btn.pressed.emit()
	await w(0.3)
	ck("A fin_031 effacé à la reprise", not Game.flags.has("fin_031") and acte2.active, str(Game.flags.keys()))
	var pos0: Vector3 = Vector3(before.pos[0], before.pos[1], before.pos[2])
	ck("A position de la sauvegarde 0.3.1", player.global_position.distance_to(pos0) < 0.1, "%s / %s" % [player.global_position, pos0])
	await until(func() -> bool: return bool(Game.flag("convocation", false)), 30.0)
	ck("A convocation déclenchée", bool(Game.flag("convocation", false)), "")
	var d := save_file()
	var p: Array = d.get("pos", [0, 0, 0])
	var pos := Vector3(p[0], p[1], p[2])
	ck("A C3 écrit sans fin_031", d.get("checkpoint") == "C3" and not (d.get("flags", {}) as Dictionary).has("fin_031")
		and (d.get("flags", {}) as Dictionary).get("convocation", false) == true, "%s %s" % [d.get("checkpoint"), (d.get("flags", {}) as Dictionary).keys()])
	ck("A C3 au couloir devant la chambre (joueur dans la salle de bain)", pos.distance_to(Acte2.C3_POS) < 0.05, str(pos))
	ck("A C3 jauge de la 0.3.1", absf(float(d.get("peur", -1)) - float(before.get("peur", -2))) < 0.6, "%s / %s" % [d.get("peur"), before.get("peur")])
	print("SAUVE A : version écrite dans C3 : « %s »" % d.get("version"))
	await until(func() -> bool: return haunt.said("nestor").has(Acte2.N11), 30.0)
	await until(func() -> bool: return not haunt.is_busy(), 20.0)
	await w(0.3)
	ck("A O4, modem, libellé", Game.objective_text == Acte2.O4 and room.convoking and room.pc_it.enabled
		and room.pc_it.label == "Répondre à l'ordinateur" and room.modem_plays >= 1, "« %s » %s" % [Game.objective_text, room.pc_it.label])
	var jt := journal_txt()
	print("SAUVE A journal.txt :\n" + jt)
	ck("A journal : reprise d'une sauvegarde 0.3.1 notée", jt.contains("reprise (« Continuer ») au point de passage C2") and jt.contains("étape « convocation »"), "")
	await snap("a1_convocation")
	# le joueur répond (dans la chambre, devant l'ordinateur)
	player.global_position = Vector3(1.2, 0, -1.0)
	player.set_look(0.0, -0.3)
	await w(0.5)
	terminal.turbo = true
	room.pc_it.used.emit(room.pc_it)
	await until(func() -> bool: return acte2.seance != null and Game.phase == "seated", 10.0)
	ck("A séance 2 commencée", acte2.seance != null and Game.phase == "seated", "")
	await until(func() -> bool: return not terminal._choice.is_empty() or acte2.seance.issue != "", 120.0)
	await w(0.8)
	if not terminal._choice.is_empty():
		terminal._choice.picked = 0
	var c3_peur := float(save_file().get("peur", -1))
	Engine.set_meta(META_C3, c3_peur)
	Engine.set_meta(META, "B")
	await until(func() -> bool: return acte2.end_card_shown, 120.0)
	await w(2.0)
	ck("A carte de fin", acte2.end_card_shown and card_visible().contains("FIN DE LA VERSION 0.3"), card_visible())
	var s2 := save_file()
	ck("A fin_v03 ajouté à C3, jauge de C3 gardée", s2.get("checkpoint") == "C3" and (s2.get("flags", {}) as Dictionary).get("fin_v03", false) == true
		and is_equal_approx(float(s2.get("peur", -1)), c3_peur) and Game.choices.get("prix_confirme") == "personne",
		"%s · peur %s / %s · %s" % [s2.get("checkpoint"), s2.get("peur"), c3_peur, Game.choices.get("prix_confirme")])
	await snap("a2_carte")
	print("SAUVE A : la fin de la version va recharger la scène")


## B : après la fin de la version, la scène neuve (rechargée par Acte2._back_to_title).
func _stage_b() -> void:
	var c3_peur := float(Engine.get_meta(META_C3, -1.0))
	await w(0.3)
	ck("B titre neuf, pas de carte fantôme", card_visible() == "" and hud.fade.color.a < 0.05 and Game.phase == "title", "carte « %s » · fondu %.2f" % [card_visible(), hud.fade.color.a])
	await _from_title()
	await snap("b0_titre")
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur
	await w(2.5)
	var d := save_file()
	var p: Array = d.get("pos", [0, 0, 0])
	var pos := Vector3(p[0], p[1], p[2])
	ck("B « Continuer » recharge C3", acte2.active and Game.phase == "room" and not player.seated and player.can_move
		and player.global_position.distance_to(pos) < 0.1 and absf(wrapf(player.yaw - float(d.get("yaw", 0)), -PI, PI)) < 0.01,
		"%s / %s · lacet %.2f" % [player.global_position, pos, player.yaw])
	ck("B jauge de C3", is_equal_approx(peur_loaded, c3_peur), "%.2f / %.2f" % [peur_loaded, c3_peur])
	ck("B drapeaux fin_v03 et convocation", bool(Game.flag("fin_v03", false)) and bool(Game.flag("convocation", false)) and not Game.flags.has("fin_031"), str(Game.flags.keys()))
	ck("B O4, libellé, modem, étape", Game.objective_text == Acte2.O4 and room.convoking and room.pc_it.enabled
		and room.pc_it.label == "Répondre à l'ordinateur" and room.modem_plays >= 1 and haunt.step_id == "convocation",
		"« %s » · %s · %d · %s" % [Game.objective_text, room.pc_it.label, room.modem_plays, haunt.step_id])
	ck("B pas de carte fantôme après la reprise", card_visible() == "" and not acte2.end_card_shown and hud.fade.color.a < 0.05,
		"carte « %s » · fondu %.2f" % [card_visible(), hud.fade.color.a])
	ck("B objets et choix de C3", Game.has_item("antenne") and Game.has_item("seche_cheveux") and not Game.choices.has("prix_confirme"), str(Game.choices))
	await snap("b1_reprise_c3")
	var n0: int = room.modem_plays
	await w(24.0)
	ck("B le modem rappelle (22 s)", room.modem_plays > n0, "%d → %d" % [n0, room.modem_plays])
	if quit_at == "B":
		# le chemin du joueur : fin de la version → titre → « Continuer » → menu de pause → « Quitter le jeu »
		pause()
		await get_tree().create_timer(1.0, true).timeout
		print("SAUVE FINI %d vérifications, %d échec(s) (quitter après la reprise de C3)" % [n_ok + n_ko, n_ko])
		Engine.remove_meta(META)
		get_tree().quit(0)
		return
	# ABSORBÉ hors séance, juste après la convocation (au couloir, à C3)
	var before := FileAccess.get_file_as_string(Game.save_path())
	Engine.set_meta(META, "C")
	Game.set_peur(100.0, "test relecteur")
	await w(1.5)
	ck("B ABSORBÉ hors séance lancé", acte2.get("_absorbing") == true and Game.phase == "end" and not room.convoking, "phase %s · modem %s" % [Game.phase, room.convoking])
	await w(6.0)
	await snap("b2_absorbe")
	ck("B ABSORBÉ : sauvegarde inchangée", FileAccess.get_file_as_string(Game.save_path()) == before, "")
	print("SAUVE B : l'épilogue va recharger la scène")


## C : après l'épilogue d'ABSORBÉ.
func _stage_c() -> void:
	var c3_peur := float(Engine.get_meta(META_C3, -1.0))
	await w(0.3)
	ck("C titre neuf, pas de carte fantôme", card_visible() == "" and Game.phase == "title", card_visible())
	await _from_title()
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur
	await w(2.5)
	ck("C « Continuer » après ABSORBÉ : C3 et sa jauge", Game.load_checkpoint().get("checkpoint") == "C3" and is_equal_approx(peur_loaded, c3_peur)
		and room.convoking and Game.objective_text == Acte2.O4 and (cas == "convabs" or bool(Game.flag("fin_v03", false))) and Game.phase == "room",
		"peur %.2f / %.2f · modem %s · « %s »" % [peur_loaded, c3_peur, room.convoking, Game.objective_text])
	await snap("c1_reprise")
	if quit_at == "C":
		pause()
		await get_tree().create_timer(1.0, true).timeout
		print("SAUVE FINI %d vérifications, %d échec(s) (quitter après la reprise de C3, étape C)" % [n_ok + n_ko, n_ko])
		Engine.remove_meta(META)
		get_tree().quit(0)
		return
	Engine.set_meta(META, "D")
	print("SAUVE C : on relance (rechargement)")
	get_tree().reload_current_scene()


## D : « Nouvelle partie » depuis le titre (avec une sauvegarde et un journal remplis).
func _stage_d() -> void:
	await _from_title()
	var jt0 := journal_txt()
	ck("D avant : sauvegarde et journal remplis", Game.has_save() and menu.continue_btn.visible and jt0.contains("reprise"), "")
	menu.show_hero()
	await w(0.5)
	menu.call("_pick", "aurelia")
	await w(1.0)
	var jt := journal_txt()
	print("SAUVE D journal.txt :\n" + jt)
	ck("D « Nouvelle partie » : sauvegarde effacée", not Game.has_save() and not FileAccess.file_exists(Game.SAVE_PATH), "")
	ck("D état remis à zéro", Game.items.is_empty() and Game.flags.size() <= 1 and Game.choices.is_empty() and Game.peur == 0.0 and Game.peur_floor == 0.0 and Game.hero == "aurelia",
		"objets %d · drapeaux %s · choix %s · peur %.1f/%.1f" % [Game.items.size(), Game.flags.keys(), Game.choices, Game.peur, Game.peur_floor])
	ck("D journal.txt remis à zéro", jt.begins_with("Don't Play") and jt.contains("nouvelle partie") and not jt.contains("reprise") and not jt.contains("convocation"), "")
	ck("D aucune trace de la convocation", not room.convoking and not acte2.active and Game.objective_text != Acte2.O4, "")
	await w(3.0)
	await snap("d1_nouvelle_partie")
	print("SAUVE FINI %d vérifications, %d échec(s)" % [n_ok + n_ko, n_ko])
	Engine.remove_meta(META)
	get_tree().quit(0)


## --cas=s2abs : la jauge atteint 100 pendant la séance 2 (vrai chemin, comme --seance2=absorbe) ;
## on se lève, l'épilogue recharge ; « Continuer » reprend C3 ; puis « Quitter le jeu ».
func _s2abs_a() -> void:
	await _from_title()
	menu.continue_btn.pressed.emit()
	await until(func() -> bool: return bool(Game.flag("convocation", false)), 30.0)
	await until(func() -> bool: return haunt.said("nestor").has(Acte2.N11), 30.0)
	await until(func() -> bool: return not haunt.is_busy(), 20.0)
	var c3 := save_file()
	Engine.set_meta(META_C3, float(c3.get("peur", -1)))
	Game.set_peur(97.0, "test relecteur")
	player.global_position = Vector3(1.2, 0, -1.0)
	player.set_look(0.0, -0.3)
	await w(0.5)
	terminal.turbo = true
	room.pc_it.used.emit(room.pc_it)
	await until(func() -> bool: return acte2.seance != null and Game.phase == "seated", 10.0)
	await until(func() -> bool: return not terminal._choice.is_empty() or terminal.aborted, 120.0)
	await w(0.8)
	if not terminal._choice.is_empty():
		terminal._choice.picked = 0
	await until(func() -> bool: return acte1.waiting_stand, 120.0)
	var sv := save_file()
	ck("S ABSORBÉ pendant la séance 2, C3 intact", acte2.seance.issue == "absorbe" and sv.get("checkpoint") == "C3"
		and is_equal_approx(float(sv.get("peur", -1)), float(c3.get("peur", -2))) and not (sv.get("flags", {}) as Dictionary).has("fin_v03"),
		"issue %s · %s · peur %s / %s" % [acte2.seance.issue, sv.get("checkpoint"), sv.get("peur"), c3.get("peur")])
	await snap("s0_absorbe_seance2")
	Engine.set_meta(META, "S")
	acte1._stand_up()


func _s2abs_s() -> void:
	var c3_peur := float(Engine.get_meta(META_C3, -1.0))
	await _from_title()
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur
	await w(2.5)
	ck("S « Continuer » reprend C3 et sa jauge", is_equal_approx(peur_loaded, c3_peur) and room.convoking and Game.objective_text == Acte2.O4
		and Game.phase == "room" and card_visible() == "", "peur %.2f / %.2f · modem %s · « %s »" % [peur_loaded, c3_peur, room.convoking, Game.objective_text])
	await snap("s1_reprise")
	pause()
	await get_tree().create_timer(1.0, true).timeout
	print("SAUVE FINI %d vérifications, %d échec(s) (ABSORBÉ séance 2, reprise, quitter)" % [n_ok + n_ko, n_ko])
	Engine.remove_meta(META)
	get_tree().quit(0)


## --cas=convabs --quitter=C : la convocation jouée en direct (modem qui sonne), puis ABSORBÉ hors séance
## pendant qu'elle sonne ; l'épilogue recharge ; « Continuer » ; « Quitter le jeu » (le motif du blocage
## à la sortie vu par l'autotest : convocation, rechargement, reprise, quitter).
func _convabs_a() -> void:
	await _from_title()
	menu.continue_btn.pressed.emit()
	await until(func() -> bool: return bool(Game.flag("convocation", false)), 30.0)
	await until(func() -> bool: return haunt.said("nestor").has(Acte2.N11), 30.0)
	await until(func() -> bool: return not haunt.is_busy(), 20.0)
	Engine.set_meta(META_C3, float(save_file().get("peur", -1)))
	await w(3.0)
	ck("CA convocation en direct, l'ordinateur appelle", room.convoking and room.modem_plays >= 1, "")
	Engine.set_meta(META, "C")
	Game.set_peur(100.0, "test relecteur")
