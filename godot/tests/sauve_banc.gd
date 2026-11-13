extends "res://scripts/main.gd"
## Banc de relecture « sauvegarde et anti-blocage » (exclu de l'export). Joue le VRAI chemin du jeu
## (sans --autotest : la fin provisoire et ABSORBÉ rechargent la scène comme chez le joueur, et
## « Continuer » / « Nouvelle partie » passent par les boutons du menu).
## Lancer avec un dossier user:// isolé (XDG_DATA_HOME) pour ne pas toucher aux sauvegardes d'autrui :
##   XDG_DATA_HOME=… godot --headless --path godot res://tests/sauve_banc.tscn -- --cas=<cas>
## Cas : absorbe (ABSORBÉ après la boîte, puis « Continuer » → C1), nouvelle (fin 0.3.1, puis
## « Nouvelle partie »), fin_continuer (fin 0.3.1, « Continuer », puis ABSORBÉ et « Continuer » encore),
## p4_100 (jauge 90 avant le P4 « fixe » → ABSORBÉ pendant le P4).

const AMIS := preload("res://scripts/house/rooms/amis.gd")
const SDB := preload("res://scripts/house/rooms/sdb.gd")
const ETAPE := "sauve_etape"
const MEMO := "sauve_memo"

var cas := ""
var at: Autotest
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cas="):
			cas = a.substr(6)
	super()
	at = Autotest.new()
	at.name = "AT"
	add_child(at)
	at.setup(self)
	_run.call_deferred()


func _check(id: String, cond: bool, detail := "") -> void:
	print("VÉRIF %s %s" % [id, "OK" if cond else "ÉCHEC : " + detail])
	if not cond:
		fails += 1


func _end() -> void:
	Engine.remove_meta(ETAPE)
	print("SAUVE %s : %d échec(s)" % [cas, fails])
	print("SAUVE FINI")
	get_tree().quit(0)


func _run() -> void:
	var stage := int(Engine.get_meta(ETAPE, 1))
	print("SAUVE cas=%s étape=%d phase=%s" % [cas, stage, Game.phase])
	match cas:
		"absorbe":
			if stage == 1:
				await _absorbe_1()
			else:
				await _absorbe_2()
		"nouvelle":
			if stage == 1:
				await _full_to_end()
			else:
				await _nouvelle_2()
		"fin_continuer":
			if stage == 1:
				await _full_to_end()
			elif stage == 2:
				await _fin_continuer_2()
			else:
				await _fin_continuer_3()
		"p4_100":
			if stage == 1:
				await _p4_100_1()
			else:
				await _p4_100_2()
		"ordre":
			await _ordre()
		"nouvelle_vite":
			if stage == 1:
				await _nv_1()
			else:
				await _nv_2()
		_:
			print("cas inconnu")
			_end()


# ------------------------------------------------------------------ outils

func _world() -> Dictionary:
	var am: Node = house.rooms["amis"]
	var sb: Node = house.rooms["sdb"]
	var bu: Node = house.rooms["bureau"]
	var p1: Door = room.door_node
	return {
		"P1_ouverte": p1.is_open, "P1_verrouillee": p1.locked,
		"P3_ouverte": (house.doors["P3"] as Door).is_open, "P7_ouverte": (house.doors["P7"] as Door).is_open,
		"boite_active": am.tin_it.enabled, "cle_bureau_visible": am.tin_key.visible if am.tin_key else false,
		"antenne_active": am.antenna_it.enabled, "antenne_visible": am.antenna.visible,
		"seche_active": sb.dryer_it.enabled, "seche_visible": (sb.dryer as Node3D).visible,
		"tiroir_actif": bu.drawer_it.enabled, "tournevis_visible": (bu.screwdriver as Node3D).visible,
		"console_demarree": (bu.console as HouseConsole).booted,
		"applique_eclatee": (sb.applique as SmartBulb).broken,
		"feuilles": _sheets(bu.printer), "anneau_nestor": (house.rooms["couloir"].nestor as Nestor).ring_on,
		"babyphone_respire": (am.babyphone as Babyphone).breathing, "tele_allumee": (am.tv as Device).is_on,
		"miroir_allume": (sb.mirror as SmartMirror).is_on, "led_camera": house.rooms["couloir"].cam_led_on,
		"interrupteur": house.rooms["couloir"].switch_on, "niveau_couloir": snappedf(float(house.rooms["couloir"].dim), 0.01),
		"P4_angle": roundi((house.doors["P4"] as Door).leaf_angle_deg()),
	}


func _sheets(pr: Printer) -> Array:
	var out := []
	for e in pr.sheets:
		out.append(str(e.id))
	out.sort()
	return out


func _items() -> Array:
	var ids := []
	for it in Game.items:
		ids.append(it.id)
	return ids


func _press(label: String) -> void:
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text.trim_prefix("> ") == label and (b as Button).is_visible_in_tree():
			print("bouton « %s »" % label)
			(b as Button).pressed.emit()
			return
	print("bouton « %s » introuvable" % label)


## L'acte II jusqu'à la boîte à biscuits : couloir (N1 à N4), P2, P3 forcée, babyphone, boîte.
func _to_tin() -> void:
	var hn: Haunt = haunt
	var am: Node = house.rooms["amis"]
	await at._jump_acte2()
	at.look_from(Vector3(4.2, 0, 1.1), (house.rooms["couloir"].nestor as Nestor).speak_pos())
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N4), 60.0)
	await at.until(func() -> bool: return not hn.is_busy(), 30.0)
	await at.use_at(Vector3(4.1, 0, -3.6), PI / 2.0, -0.1, "Frapper à la porte")
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N7), 40.0)
	await at.until(func() -> bool: return not hn.is_busy(), 20.0)
	await at.use_at(Vector3(4.1, 0, 3.4), PI / 2.0, -0.1, "Ouvrir la porte")
	await at.wait(0.5)
	await at.use_at(Vector3(4.1, 0, 3.4), PI / 2.0, -0.1, "Forcer la porte")
	await at.wait(1.0)
	at.look_from(Vector3(2.0, 0, 4.3), (am.babyphone as Babyphone).speak_pos())
	await at.until(func() -> bool: return at.has_said("babyphone", Acte2.B4), 40.0)
	await at.until(func() -> bool: return not hn.is_busy(), 10.0)
	await at.use_on(am.tin_it, Vector3(-2.15, 0, 4.15), "Ouvrir la boîte à biscuits")
	await at.wait(0.8)
	print("progrès : objets %s · peur %.1f" % [_items(), Game.peur])


## Tout l'étage jusqu'à la fin provisoire 0.3.1 (P4 « fui »), par le vrai chemin ; la fin recharge la scène.
func _full_to_end() -> void:
	var hn: Haunt = haunt
	var am: Node = house.rooms["amis"]
	var bu: Node = house.rooms["bureau"]
	var sb: Node = house.rooms["sdb"]
	await _to_tin()
	await at.use_at(Vector3(3.9, 0, 4.4), -PI / 2.0, -0.1, "Ouvrir la porte")
	await at.wait(1.4)
	at.look_from(Vector3(6.75, 0, 4.85), (bu.console as Node3D).global_position)
	await at.until(func() -> bool: return at.has_said("console", Acte2.C4), 40.0)
	await at.until(func() -> bool: return not hn.is_busy(), 20.0)
	await at.use_on(bu.drawer_it, Vector3(6.6, 0, 4.85), "Ouvrir le tiroir")
	await at.wait(0.8)
	await at.use_on(bu.drawer_it, Vector3(6.6, 0, 4.85), "Prendre le tournevis")
	await at.wait(0.6)
	at.look_from(Vector3(4.25, 0, 3.9), Vector3(3.3, 0.8, 2.6))
	await at.wait(5.0)
	await at.use_on(am.antenna_it, AMIS.PLAYER_AT_TV, "Dévisser l'antenne")
	await at.until(func() -> bool: return Game.has_item("antenne"), 8.0)
	Engine.time_scale = 3.0
	await at.use_on(sb.dryer_it, Vector3(7.65, 0, -5.0), "Prendre le sèche-cheveux")
	at.look_from(SDB.PLAYER_AT_MIRROR, (sb.mirror as Node3D).global_position)
	await at.until(func() -> bool: return (sb.mirror as SmartMirror).p4_time > 0.5, 90.0)
	player.global_position = Vector3(4.0, 0, -4.4)
	player.set_look(0.0, 0.0)
	await at.until(func() -> bool: return acte2.p4_issue != "", 60.0)
	Engine.time_scale = 1.0
	print("P4 : %s · point %s · objets %s · peur %.1f" % [acte2.p4_issue, Game.load_checkpoint().get("checkpoint"), _items(), Game.peur])
	# on va dans le couloir et on attend la fin provisoire (elle recharge la scène) ; le miroir, qui
	# continue seul après « fui », a fini avant qu'on relève le monde
	player.global_position = Vector3(4.0, 0, 0.0)
	await at.until(func() -> bool: return not (sb.mirror as SmartMirror).p4_running, 40.0)
	Engine.set_meta(ETAPE, 2)
	Engine.set_meta(MEMO, {"monde": _world(), "objets": _items(), "flags": Game.flags.duplicate(true), "peur": Game.peur})
	print("monde à la fin : ", _world())
	await at.until(func() -> bool: return acte2.end_card_shown, 90.0)
	print("carte de fin 0.3.1 affichée ; on attend le rechargement")
	await at.wait(60.0)
	print("PAS DE RECHARGEMENT ?")
	_end()


# ------------------------------------------------------------------ cas « absorbe »

func _absorbe_1() -> void:
	await _to_tin()
	_check("progrès : clé du bureau prise", Game.has_item("cle_bureau"), str(_items()))
	var c1 := Game.load_checkpoint()
	print("sauvegarde : %s · objets %s" % [c1.get("checkpoint"), (c1.get("items", []) as Array).size()])
	player.global_position = Vector3(4.0, 0, 0.6)
	await at.wait(1.0)
	Engine.set_meta(ETAPE, 2)
	print("jauge forcée à 100 dans le couloir (B15)")
	Game.set_peur(100.0, "test")
	await at.wait(90.0)
	print("PAS DE RECHARGEMENT ?")
	_end()


func _absorbe_2() -> void:
	print("scène rechargée (épilogue ABSORBÉ) · drapeaux encore en mémoire : %d · objets %s" % [Game.flags.size(), _items()])
	await at.wait(1.0)
	print("monde à l'écran-titre : ", _world())
	_press("Continuer")
	await at.wait(3.0)
	var d := Game.load_checkpoint()
	print("REPRISE %s · objets %s · peur %.1f" % [d.get("checkpoint"), _items(), Game.peur])
	var w := _world()
	print("monde après « Continuer » : ", w)
	_check("reprise C1", d.get("checkpoint") == "C1" and not Game.has_item("cle_bureau"), str(d.get("checkpoint")))
	_check("C1 : boîte à biscuits encore utilisable", w.boite_active and w.cle_bureau_visible, "boîte active %s · clé visible %s" % [w.boite_active, w.cle_bureau_visible])
	at.check_unstuck("C1 après ABSORBÉ")
	_check("B14 (banc)", at.failures == 0, "voir la ligne B14")
	_end()


# ------------------------------------------------------------------ cas « nouvelle »

func _nouvelle_2() -> void:
	print("scène rechargée (fin 0.3.1) · drapeaux encore en mémoire : %d" % Game.flags.size())
	await at.wait(1.0)
	print("monde à l'écran-titre : ", _world())
	_press("Nouvelle partie")
	await at.wait(0.3)
	_press("Alexandre")
	await at.until(func() -> bool: return Game.phase == "room", 60.0)
	await at.wait(1.0)
	var w := _world()
	print("NOUVELLE PARTIE · objets %s · drapeaux %s · phase %s" % [_items(), Game.flags, Game.phase])
	print("monde de la nouvelle partie : ", w)
	_check("nouvelle partie : P1 fermée à clé (A3)", not w.P1_ouverte and w.P1_verrouillee, "P1 ouverte %s · verrouillée %s" % [w.P1_ouverte, w.P1_verrouillee])
	_check("nouvelle partie : sèche-cheveux à sa place", w.seche_active and w.seche_visible, "actif %s · visible %s" % [w.seche_active, w.seche_visible])
	_check("nouvelle partie : boîte à biscuits", w.boite_active and w.cle_bureau_visible, "active %s · clé visible %s" % [w.boite_active, w.cle_bureau_visible])
	_check("nouvelle partie : antenne", w.antenne_active and w.antenne_visible, "active %s · visible %s" % [w.antenne_active, w.antenne_visible])
	_check("nouvelle partie : tournevis", w.tiroir_actif and w.tournevis_visible, "tiroir %s · visible %s" % [w.tiroir_actif, w.tournevis_visible])
	_check("nouvelle partie : console éteinte", not w.console_demarree, "")
	_check("nouvelle partie : applique intacte", not w.applique_eclatee, "")
	_check("nouvelle partie : P3 et P7 fermées", not w.P3_ouverte and not w.P7_ouverte, "P3 %s · P7 %s" % [w.P3_ouverte, w.P7_ouverte])
	# la porte de la chambre, utilisée avant la clé (A3)
	var p1: Door = room.door_node
	at.look_from(Vector3(1.6, 0, 1.4), p1.global_position + Vector3(0, 1.0, 0))
	await at.wait(0.8)
	print("P1 visée : « %s »" % (player.current.label if player.current else "rien"))
	_end()


# ------------------------------------------------------------------ cas « fin_continuer »

func _fin_continuer_2() -> void:
	var memo: Dictionary = Engine.get_meta(MEMO, {})
	await at.wait(1.0)
	_check("titre : Continuer", menu.continue_btn.visible, "")
	_press("Continuer")
	await at.wait(3.0)
	var d := Game.load_checkpoint()
	print("REPRISE %s · objets %s · peur %.1f · objectif « %s » / « %s »" % [d.get("checkpoint"), _items(), Game.peur, Game.objective_text, Game.objective_sub])
	print("monde : ", _world())
	_check("reprise après la fin : même monde", same_world(memo.get("monde", {}), _world()), "%s / %s" % [memo.get("monde"), _world()])
	_check("reprise après la fin : fin_031", bool(Game.flag("fin_031", false)) and Game.phase == "room", "")
	await at.wait(8.0)
	print("8 s plus tard : phase %s · carte %s · objectif « %s »" % [Game.phase, acte2.end_card_shown, Game.objective_text])
	# deuxième rechargement : ABSORBÉ, puis « Continuer » encore
	Engine.set_meta(ETAPE, 3)
	Engine.set_meta(MEMO, {"monde": _world(), "objets": _items(), "peur": Game.peur, "point": d.get("checkpoint")})
	Game.set_peur(100.0, "test")
	await at.wait(90.0)
	print("PAS DE RECHARGEMENT ?")
	_end()


func _fin_continuer_3() -> void:
	var memo: Dictionary = Engine.get_meta(MEMO, {})
	await at.wait(1.0)
	_press("Continuer")
	await at.wait(3.0)
	var d := Game.load_checkpoint()
	print("2e REPRISE %s · objets %s · peur %.1f (avant %.1f)" % [d.get("checkpoint"), _items(), Game.peur, float(memo.get("peur", -1))])
	_check("2e reprise : même monde", same_world(memo.get("monde", {}), _world()), "%s / %s" % [memo.get("monde"), _world()])
	_check("2e reprise : mêmes objets", Autotest.same(_items(), memo.get("objets", [])), "")
	_end()


func same_world(a: Dictionary, b: Dictionary) -> bool:
	var bad := []
	for k in a:
		if a[k] != b.get(k):
			bad.append(k)
	if not bad.is_empty():
		print("  différences : ", bad)
	return bad.is_empty()


# ------------------------------------------------------------------ cas « p4_100 »

func _p4_100_1() -> void:
	var sb: Node = house.rooms["sdb"]
	await at._jump_acte2()
	await at.until(func() -> bool: return Game.flag("entree_couloir", false) == true, 5.0)
	at.look_from(Vector3(4.0, 0, -1.0), Vector3(4.0, 1.5, -3.0))
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N4), 60.0)
	await at.until(func() -> bool: return not haunt.is_busy(), 30.0)
	Game.set_peur(90.0, "test : séance 1 à 90")
	var c1 := Game.load_checkpoint()
	print("C1 écrit avec peur %.1f" % float(c1.get("peur", -1)))
	Engine.time_scale = 3.0
	await at.use_on(sb.dryer_it, Vector3(7.65, 0, -5.0), "Prendre le sèche-cheveux")
	at.look_from(SDB.PLAYER_AT_MIRROR, (sb.mirror as Node3D).global_position)
	Engine.set_meta(ETAPE, 2)
	await at.until(func() -> bool: return acte2.p4_issue != "" or acte2.absorbed_screen != "", 120.0)
	Engine.time_scale = 1.0
	await at.wait(1.0)
	var d := Game.load_checkpoint()
	print("P4 « %s » · ABSORBÉ sur « %s » · point écrit %s avec peur %.1f · phase %s" % [acte2.p4_issue, acte2.absorbed_screen, d.get("checkpoint"), float(d.get("peur", -1)), Game.phase])
	Engine.set_meta(MEMO, {"point": d.get("checkpoint"), "peur_point": float(d.get("peur", -1)), "peur_c1": float(c1.get("peur", -1))})
	await at.wait(90.0)
	print("PAS DE RECHARGEMENT ?")
	_end()


func _p4_100_2() -> void:
	var memo: Dictionary = Engine.get_meta(MEMO, {})
	await at.wait(1.0)
	_press("Continuer")
	await at.wait(3.0)
	var d := Game.load_checkpoint()
	print("REPRISE %s · peur %.1f · phase %s · miroir_reel %s" % [d.get("checkpoint"), Game.peur, Game.phase, Game.choices.get("miroir_reel", "-")])
	_check("ABSORBÉ pendant le P4 : point repris sous 100", float(d.get("peur", 100.0)) < 100.0, "point %s écrit et repris avec peur %.2f (C1 avait %.1f)" % [d.get("checkpoint"), float(d.get("peur", -1)), float(memo.get("peur_c1", -1))])
	# un indice moqueur (+1) au bout de 90 s sans progrès : ABSORBÉ revient-il ? (minuteries ×30, comme --indices)
	haunt.hint_speed = 30.0
	var t0 := Time.get_ticks_msec()
	await at.until(func() -> bool: return acte2.absorbed_screen != "", 20.0)
	print("après la reprise : ABSORBÉ %s (écran « %s ») %.1f s plus tard · indices %d · peur %.1f" % [acte2.absorbed_screen != "", acte2.absorbed_screen, (Time.get_ticks_msec() - t0) / 1000.0, haunt.hints_given, Game.peur])
	_check("pas de nouvel ABSORBÉ juste après la reprise", acte2.absorbed_screen == "", "ABSORBÉ rejoué à cause d'un indice +1")
	_end()


# ------------------------------------------------------------------ cas « ordre » (ordre inattendu)

## Le sèche-cheveux pris pendant N1 à N4 (avant Mamie et avant la chambre d'amis), pause pendant le P4,
## fuite à 1 s de barre ; puis dix coups sur P2 ; puis la chaise de l'ordinateur de ta mère.
func _ordre() -> void:
	var sb: Node = house.rooms["sdb"]
	var mirror: SmartMirror = sb.mirror
	var p2: Door = house.doors["P2"]
	await at._jump_acte2()
	at.look_from(Vector3(4.0, 0, 0.6), Vector3(4.0, 1.3, -3.0))
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N1), 10.0)
	print("N1 dit ; on file à la salle de bain")
	await at.use_on(sb.dryer_it, Vector3(7.65, 0, -5.0), "Prendre le sèche-cheveux")
	at.look_from(SDB.PLAYER_AT_MIRROR, mirror.global_position)
	await at.until(func() -> bool: return mirror.p4_running and mirror.feed_shown, 30.0)
	# pause pendant le P4
	var said_before: int = haunt.said("miroir").size()
	pause()
	await at.wait(4.0)
	var said_paused: int = haunt.said("miroir").size()
	_check("pause pendant le P4 : rien n'avance", said_paused == said_before and get_tree().paused, "%d → %d lignes" % [said_before, said_paused])
	resume()
	await at.until(func() -> bool: return mirror.p4_time > 1.0, 90.0)
	print("barre à %.2f s : on sort de la salle de bain" % mirror.p4_time)
	player.global_position = Vector3(4.0, 0, -4.4)
	player.set_look(0.0, 0.0)
	await at.until(func() -> bool: return acte2.p4_issue != "", 20.0)
	await at.wait(1.0)
	var d := Game.load_checkpoint()
	print("P4 « %s » · point %s · étape %s · objectif « %s » / « %s » · Nestor %s" % [acte2.p4_issue, d.get("checkpoint"), acte2._step(), Game.objective_text, Game.objective_sub, haunt.said("nestor")])
	_check("P4 avant Mamie : issue fui, C2", acte2.p4_issue == "fui" and d.get("checkpoint") == "C2", "")
	await at.until(func() -> bool: return not haunt.is_busy(), 40.0)
	await at.wait(18.0)     # (le miroir finit seul)
	print("scènes en cours : %s · miroir en marche %s" % [haunt.is_busy(), mirror.p4_running])
	_check("plus aucune scène écrite en cours", not haunt.is_busy() and not mirror.p4_running, "")
	# dix coups sur P2, à la file
	for k in 10:
		await at.use_at(Vector3(4.1, 0, -3.6), PI / 2.0, -0.1, "Frapper à la porte")
		await at.wait(0.2)
	await at.until(func() -> bool: return not haunt.is_busy(), 40.0)
	await at.wait(30.0)
	var n57 := 0
	for l in haunt.said("nestor"):
		if l == haunt.fill(Acte2.N7):
			n57 += 1
	print("P2 : %d coups · N7 dit %d fois · S.O.S. %d · objectif « %s » / « %s » · indice « %s »" % [p2.knocks, n57, haunt.count("sos"), Game.objective_text, Game.objective_sub, hud.hint_lbl.text])
	# (P4 réel déjà fait avant les coups : N7, « D'abord, un essai. Salle de bain. », n'est plus dit)
	var n5 := haunt.said("nestor").count(haunt.fill(Acte2.N5))
	var want_n7 := 0 if acte2._p4_done() else 1
	_check("dix coups : N5 une fois, N7 %d fois, S.O.S. une fois" % want_n7, n5 == 1 and n57 == want_n7 and haunt.count("sos") == 1,
		"N5 %d · N7 %d · S.O.S. %d" % [n5, n57, haunt.count("sos")])
	# retour dans la chambre de ta mère : la chaise et l'ordinateur
	at.look_from(Vector3(0.4, 0, -0.3), room.screen_center)
	await at.wait(1.0)
	print("PC visé après la séance : « %s »" % (player.current.label if player.current else "rien"))
	_check("PC : pas de seconde séance", player.current == null or not player.current.label.contains("disquette"), player.current.label if player.current else "")
	at.check_unstuck("C2 (ordre inattendu)")
	_end()


# ------------------------------------------------------------------ cas « nouvelle_vite » (rendu, captures)

## Version courte de « nouvelle », pour les captures : P3 forcée, boîte ouverte, sèche-cheveux pris (P4
## « fui », C2), puis ABSORBÉ (la scène se recharge) ; à l'écran-titre, « Nouvelle partie ».
func _nv_1() -> void:
	var am: Node = house.rooms["amis"]
	var sb: Node = house.rooms["sdb"]
	await at._jump_acte2()
	at.look_from(Vector3(4.0, 0, 0.6), Vector3(4.0, 1.3, -3.0))
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N4), 60.0)
	await at.until(func() -> bool: return not haunt.is_busy(), 30.0)
	await at.use_at(Vector3(4.1, 0, 3.4), PI / 2.0, -0.1, "Ouvrir la porte")
	await at.wait(0.5)
	await at.use_at(Vector3(4.1, 0, 3.4), PI / 2.0, -0.1, "Forcer la porte")
	await at.wait(1.0)
	await at.use_on(am.tin_it, Vector3(-2.15, 0, 4.15), "Ouvrir la boîte à biscuits")
	await at.wait(0.8)
	await at.use_on(sb.dryer_it, Vector3(7.65, 0, -5.0), "Prendre le sèche-cheveux")
	await at.wait(0.3)
	player.global_position = Vector3(4.0, 0, -4.4)
	await at.until(func() -> bool: return acte2.p4_issue != "", 30.0)
	await at.until(func() -> bool: return not haunt.is_busy(), 40.0)
	print("avant ABSORBÉ : objets %s · point %s" % [_items(), Game.load_checkpoint().get("checkpoint")])
	Engine.set_meta(ETAPE, 2)
	Game.set_peur(100.0, "test")
	await at.wait(120.0)
	print("PAS DE RECHARGEMENT ?")
	_end()


func _nv_2() -> void:
	await at.wait(1.5)
	await at.shot("n0_titre_apres_absorbe")
	_press("Nouvelle partie")
	await at.wait(0.3)
	_press("Alexandre")
	await at.until(func() -> bool: return Game.phase == "room", 60.0)
	await at.wait(2.5)
	var w := _world()
	print("NOUVELLE PARTIE · objets %s · objectif « %s »" % [_items(), Game.objective_text])
	print("monde : ", w)
	_check("nouvelle partie : P1 fermée à clé (A3)", not w.P1_ouverte and w.P1_verrouillee, "P1 ouverte %s · verrouillée %s" % [w.P1_ouverte, w.P1_verrouillee])
	await at.view(Vector3(1.6, 0, 1.4), -PI / 2.0, -0.05, "n1_acte1_p1_ouverte", 1.5)
	print("P1 visée : « %s »" % (player.current.label if player.current else "rien"))
	var am: Node = house.rooms["amis"]
	var sb: Node = house.rooms["sdb"]
	at.look_from(Vector3(-2.15, 0, 4.15), (am.tin_it as Node3D).global_position)
	await at.wait(1.5)
	await at.shot("n2_boite_ouverte_vide")
	print("boîte visée : « %s »" % (player.current.label if player.current else "rien"))
	at.look_from(Vector3(7.65, 0, -5.0), (sb.dryer_it as Node3D).global_position)
	await at.wait(1.5)
	await at.shot("n3_seche_cheveux_absent")
	print("armoire basse visée : « %s »" % (player.current.label if player.current else "rien"))
	_check("nouvelle partie : boîte et sèche-cheveux", w.boite_active and w.seche_active, "boîte %s · sèche-cheveux %s" % [w.boite_active, w.seche_active])
	_end()
