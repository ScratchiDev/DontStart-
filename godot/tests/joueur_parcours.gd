extends "res://scripts/main.gd"
## Relecture « joueur » (banc exclu de l'export) : l'étage de la 0.3.1 joué comme un vrai joueur.
## Pas de téléportation : on marche (Z/Q/S/D par Input.action_press, avec la physique et les
## collisions), on tourne le regard peu à peu (comme à la souris), on appuie sur E par un vrai
## événement clavier. Chaque interaction est visée depuis une place où un joueur se tiendrait.
## godot --path godot --rendering-driver vulkan res://tests/joueur_parcours.tscn -- --shots=DIR [--voie=principal|retourne|fui|direct]

var voie := "principal"
var fails := 0
var checks := 0
var gt := 0.0                 # temps de jeu (somme des delta)
var shot_n := 0
var real_e := false           # l'appui sur E passe-t-il par le vrai chemin (souris capturée) ?
var stuck_log: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--voie="):
			voie = a.substr(7)
	if Engine.has_meta("joueur_vu"):
		print("JOUEUR : scène rechargée (épilogue), fin du banc")
		get_tree().quit.call_deferred(0)
		return
	Engine.set_meta("joueur_vu", true)
	super()
	Game.autotest = true          # (après _ready : pas d'Autotest) sauvegarde de test, pas de voix
	Engine.max_physics_steps_per_frame = 60
	_run.call_deferred()


func _process(delta: float) -> void:
	gt += delta


# ------------------------------------------------------------------ outils

func ck(id: String, cond: bool, detail := "") -> bool:
	checks += 1
	if cond:
		print("VÉRIF %s OK" % id)
	else:
		fails += 1
		print("VÉRIF %s ÉCHEC : %s" % [id, detail])
	return cond


func wait(sec: float) -> void:
	var t0 := gt
	while gt - t0 < sec:
		await get_tree().process_frame


func until(cond: Callable, timeout := 30.0) -> bool:
	var t0 := gt
	while not cond.call():
		if gt - t0 > timeout:
			print("ATTENTE TROP LONGUE (%.0f s)" % timeout)
			return false
		await get_tree().process_frame
	return true


func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	shot_n += 1
	var nm := "%02d_%s" % [shot_n, n]
	if Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(nm + ".png"))
	print("capture %s (t=%.1f, pos %s, pièce %s)" % [nm, gt, _v(player.global_position), house.current.room_id if house.current else "?"])


static func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


## Tourne le regard vers « target » en « sec » secondes (souris). Rien si le regard est bloqué.
func turn_to(target: Vector3, sec := 0.45) -> void:
	if not player.can_look:
		print("  (regard bloqué : can_look = false)")
		return
	var eye: Vector3 = player.global_position + Vector3(0, player.EYE, 0)
	var d := target - eye
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var y0: float = player.yaw
	var p0: float = player.pitch
	var dy := wrapf(yaw - y0, -PI, PI)
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / sec, 0.0, 1.0)
		if player.can_look:
			player.set_look(y0 + dy * k, lerpf(p0, pitch, k))
	if player.can_look:
		player.set_look(y0 + dy, pitch)


func look_dir(yaw: float, pitch := -0.05, sec := 0.45) -> void:
	var eye: Vector3 = player.global_position + Vector3(0, player.EYE, 0)
	var f := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	await turn_to(eye + f * 3.0, sec)


## Marche (touche avant) de point en point ; le regard suit la direction de la marche. Si le joueur
## n'avance plus pendant 2,5 s : BLOQUÉ (on note l'obstacle), puis on le pose au point visé.
func walk(points: Array, tag: String, run := false) -> bool:
	var ok := true
	for p in points:
		var target: Vector3 = p
		var best := INF
		var best_t := 0.0
		var pt := 0.0
		var frozen := 0.0
		if run:
			Input.action_press("sprint")
		Input.action_press("move_forward")
		while true:
			var d := target - player.global_position
			d.y = 0.0
			var dist := d.length()
			if dist < 0.2:
				break
			if not player.can_move:
				frozen += get_physics_process_delta_time()
				if frozen > 40.0:
					print("  joueur figé plus de 40 s (%s)" % tag)
					ok = false
					break
				await get_tree().physics_frame
				continue
			player.set_look(atan2(-d.x, -d.z), -0.05)
			await get_tree().physics_frame
			pt += get_physics_process_delta_time()
			if dist < best - 0.04:
				best = dist
				best_t = pt
			elif pt - best_t > 2.5:
				var col := player.get_last_slide_collision()
				var what := "?"
				if col and col.get_collider():
					var c: Object = col.get_collider()
					what = "%s (%s) à %s" % [c.get("name"), (c as Node).get_parent().name if c is Node else "", _v(col.get_position())]
				print("  BLOQUÉ en %s vers %s (%s) : %s" % [_v(player.global_position), _v(target), tag, what])
				stuck_log.append("%s : %s → %s, %s" % [tag, _v(player.global_position), _v(target), what])
				ok = false
				break
		Input.action_release("move_forward")
		Input.action_release("sprint")
		if not ok:
			await snap("bloque_" + tag)
			player.global_position = Vector3(target.x, player.global_position.y, target.z)
			ok = true
			ck("passage " + tag, false, stuck_log[-1])
			await get_tree().physics_frame
	return ok


## Appuie sur E comme au clavier (événement réel) ; sans souris capturée, use() direct.
func press_e() -> void:
	if real_e:
		var ev := InputEventKey.new()
		ev.keycode = KEY_E
		ev.physical_keycode = KEY_E
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up := ev.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().process_frame
	elif hud.paper_open:
		hud.close_paper()
	elif hud.screen_open:
		hud.close_screen()
	elif player.current:
		player.current.use()


## Vise « target » (point visible de l'objet), vérifie le libellé, capture, puis E.
func use(expected: String, target: Vector3, tag := "", press := true) -> bool:
	await turn_to(target, 0.4)
	await wait(0.4)
	var got: String = player.current.label if player.current else "rien"
	if got != expected:
		# un vrai joueur ajuste un peu son regard : petit balayage autour du point
		for o in [Vector3(0, 0.06, 0), Vector3(0, -0.06, 0), Vector3(0.06, 0, 0.06), Vector3(-0.06, 0, -0.06), Vector3(0, 0.12, 0), Vector3(0, -0.12, 0)]:
			await turn_to(target + o, 0.15)
			await wait(0.15)
			got = player.current.label if player.current else "rien"
			if got == expected:
				print("  (trouvé après un petit ajustement du regard : %s)" % _v(o))
				break
	var ray: RayCast3D = player.ray
	var col: Object = ray.get_collider() if ray.is_colliding() else null
	var dist: float = ray.global_position.distance_to(ray.get_collision_point()) if col else -1.0
	ck("vise « %s »%s" % [expected, " (" + tag + ")" if tag != "" else ""], got == expected,
		"le rayon touche %s à %.2f m, libellé « %s », depuis %s" % [col.get("name") if col else "rien", dist, got, _v(player.global_position)])
	if tag != "":
		await snap(tag)
	if got == expected and press:
		await press_e()
		return true
	return false


func p(x: float, z: float) -> Vector3:
	return Vector3(x, 0, z)


func hint_text() -> String:
	return hud.hint_lbl.text


# ------------------------------------------------------------------ déroulé

func _run() -> void:
	menu.hide_all()
	hud.fade.color.a = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await wait(0.6)
	real_e = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	print("JOUEUR début · voie %s · souris capturée %s" % [voie, real_e])
	hud.subtitle_shown.connect(func(who: String, text: String) -> void:
		print("SOUS-TITRE t=%.1f %s : %s" % [gt, who, text]))
	Game.hint_requested.connect(func(text: String, sec: float) -> void:
		if text != "":
			print("PENSÉE t=%.1f (%.1f s) %s" % [gt, sec, text]))
	Game.objective_changed.connect(func(text: String) -> void:
		print("OBJECTIF t=%.1f %s" % [gt, text.replace("\n", " / ")]))
	await _after_seance()
	match voie:
		"principal":
			await _principal()
		"presse":
			await _presse()
		"absorbe":
			await _absorbe_couloir()
		"inventaire":
			await _inventaire()
		"absorbe_e":
			await _absorbe_e()
		_:
			await _direct()
	print("couloir bloqué : ", stuck_log)
	print("%d vérifications, %d échec(s)" % [checks, fails])
	print("JOUEUR OK" if fails == 0 else "JOUEUR ÉCHEC %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


## L'état juste après une séance 1 « suite » : le joueur se lève, la clé et le mot sont sous la porte.
func _after_seance() -> void:
	Game.phase = "room"
	Game.choices = {"proche": "Mamie", "verres": "gauche", "porte": "preuve", "prix": "personne", "reflet": "fixe", "fin_seance1": "suite", "peur_seance1": 41}
	terminal.set_fear(41.0)
	acte1.seance_result = "suite"
	room.restore_after_seance()
	terminal.show_static(Acte1.SCREEN_AFTER)
	hud.show_hand(false)
	hud.show_crosshair(true)
	room.key_under_door()
	player.stand(Vector3(room.seat_pos.x, 0.0, room.seat_pos.z + 0.75), 0.0)
	Game.objective("Ramasse ce qu'on a glissé sous la porte")
	await wait(0.5)
	# la clé, près de la porte
	await walk([p(2.0, 1.2)], "chambre vers la clé")
	await use("Ramasser la clé et le mot", Vector3(2.88, 0.02, 1.32), "cle")
	await wait(0.8)
	ck("C1 écrit", Game.load_checkpoint().get("checkpoint") == "C1" and acte2.active, str(Game.load_checkpoint().get("checkpoint")))
	await press_e()      # repose le mot
	await wait(0.4)
	ck("mot reposé", not hud.paper_open, "")
	await use("Ouvrir la porte", Vector3(3.2, 1.2, 1.25), "p1")
	await wait(1.6)
	ck("P1 ouverte", room.door_node.is_open, "")


func _principal() -> void:
	var cl: Node = house.rooms["couloir"]
	var am: Node = house.rooms["amis"]
	var bu: Node = house.rooms["bureau"]
	var sb: Node = house.rooms["sdb"]
	var hn: Haunt = haunt
	# --- étape 6 : on sort dans le couloir (première entrée)
	await walk([p(2.7, 1.4), p(3.75, 1.4)], "P1 vers le couloir")
	var t_in := gt
	await snap("couloir_premier_regard")
	# le joueur entend « Bonsoir » : il tourne la tête vers la voix (Nestor, sur la console au nord)
	await until(func() -> bool: return (cl.nestor as Nestor).ring_on, 6.0)
	await turn_to((cl.nestor as Nestor).speak_pos(), 0.8)
	await wait(0.6)
	await snap("nestor_anneau")
	await wait(1.2)
	await snap("chaine_ampoules")
	await until(func() -> bool: return hn.said("nestor").size() >= 2, 20.0)
	await look_dir(PI / 2.0 * 0.0, -0.05)      # (vers le nord, le fond du couloir)
	await snap("couloir_vers_le_fond_N2")
	await until(func() -> bool: return not hn.is_busy(), 40.0)
	print("scène du couloir : %.1f s" % (gt - t_in))
	ck("O2 affiché", Game.objective_text == "Va voir ta grand-mère", Game.objective_text)
	await snap("couloir_apres_N4")
	# --- l'interrupteur : son libellé dans le noir
	await walk([p(3.75, 0.75)], "vers l'interrupteur")
	await use("Allumer la lumière", Vector3(3.31, 1.1, 0.75), "interrupteur_libelle", false)
	# --- étape 7 : P2 (la porte du fond, côté chambres)
	await walk([p(3.95, -1.0), p(3.85, -3.6)], "couloir vers P2")
	var t_knock := gt
	await use("Frapper à la porte", Vector3(3.25, 1.2, -3.45), "p2_frapper")
	await until(func() -> bool: return hint_text() != "" and hint_text().begins_with("Tu frappes"), 5.0)
	await snap("p2_hp2a")
	await until(func() -> bool: return hn.said("nestor").has(hn.fill(Acte2.N7)), 40.0)
	await snap("p2_n7")
	await until(func() -> bool: return not hn.is_busy(), 20.0)
	await use("Frapper à la porte", Vector3(3.25, 1.2, -3.45), "")
	await until(func() -> bool: return hint_text().begins_with("Fermée à clé, de l'intérieur"), 5.0)
	await snap("p2_hp2b")
	ck("O3 après P2", Game.objective_text == "Elle t'attend dans la salle de bain", Game.objective_text)
	# --- étape 8 : le S.O.S. (on reste près de P2 : le radiateur est à ~1 m)
	await until(func() -> bool: return hn.has_logged("sos"), 30.0)
	print("S.O.S. %.1f s après le 1er appui (%s)" % [gt - t_knock, acte2.sos_source])
	await wait(1.0)
	await look_dir(-PI / 2.0, -0.35)     # le joueur regarde vers le radiateur, à l'est
	await snap("sos_radiateur")
	await until(func() -> bool: return hn.said("nestor").size() >= 9, 40.0)
	await snap("sos_n9")
	await until(func() -> bool: return not hn.is_busy(), 20.0)
	# --- P4 entrouverte, juste en face : on la regarde (le joueur y ira plus tard)
	await walk([p(4.0, -4.3)], "vers P4")
	await look_dir(-PI / 2.0, -0.05)
	await wait(0.3)
	await snap("p4_entrouverte_vue_joueur")
	# --- étape 9 : portes fermées P5, P6, P7
	await walk([p(4.15, -1.2)], "vers P5")
	await use("Ouvrir la porte", Vector3(4.75, 1.1, -1.2), "p5")
	await wait(0.5)
	print("P5 : « %s »" % hint_text())
	await walk([p(4.1, 1.35)], "vers P6")
	await use("Ouvrir la porte", Vector3(4.75, 1.3, 1.35), "p6_vitree")
	await wait(0.5)
	print("P6 : « %s »" % hint_text())
	await walk([p(4.1, 4.4)], "vers P7")
	await use("Ouvrir la porte", Vector3(4.75, 1.1, 4.25), "p7")
	await wait(0.5)
	print("P7 : « %s »" % hint_text())
	# le câble sous la porte P7
	await use("Regarder le câble", Vector3(4.3, 0.02, 4.15), "cable_sol", true)
	await wait(0.4)
	print("câble : « %s »" % hint_text())
	# --- étape 10 : P3 (chambre d'amis), deux fois
	await walk([p(3.85, 3.4)], "vers P3")
	await use("Ouvrir la porte", Vector3(3.25, 1.1, 3.25), "p3_1")
	await wait(0.6)
	await use("Forcer la porte", Vector3(3.25, 1.1, 3.25), "p3_2")
	await wait(1.2)
	ck("P3 ouverte", (house.doors["P3"] as Door).is_open, "")
	var t_amis := gt
	await walk([p(2.7, 3.45), p(2.0, 4.0)], "P3 vers la chambre d'amis")
	await snap("amis_entree")
	# la voix vient du babyphone (chevet, au fond) : le joueur la cherche
	var bp: Babyphone = am.babyphone
	await until(func() -> bool: return hn.said("babyphone").size() >= 1, 15.0)
	await turn_to(bp.speak_pos(), 0.8)
	await wait(0.4)
	await snap("amis_babyphone_b1")
	await until(func() -> bool: return hn.said("babyphone").size() >= 2, 20.0)
	await snap("amis_b2_voix_mamie")
	var tv: Device = am.tv
	await until(func() -> bool: return float(tv._p.noise) >= 0.5, 20.0)
	await wait(0.3)
	await snap("amis_tele_neige_derriere")      # où la télé est-elle, pour le joueur ?
	await turn_to(tv.global_position, 0.6)
	await snap("amis_tele_neige_vue")
	await until(func() -> bool: return not hn.is_busy(), 25.0)
	print("scène du babyphone : %.1f s" % (gt - t_amis))
	# boîte à biscuits (coin couture, sous la fenêtre), madeleine
	await walk([p(0.4, 3.75), p(-1.0, 3.75), p(-2.05, 4.0)], "vers le coin couture")
	await use("Ouvrir la boîte à biscuits", Vector3(-2.9, 0.83, 3.88), "boite")
	await wait(1.0)
	ck("clé du bureau", Game.has_item("cle_bureau"), "")
	var mad: Interactable = am.madeleine_it
	await use("Manger la madeleine", mad.global_position, "madeleine")
	await wait(0.6)
	# la télé et l'antenne, sans tournevis
	await walk([p(-1.2, 3.75)], "vers la télé")
	await use("Examiner la télé", tv.global_position, "tele")
	await wait(0.5)
	print("télé : « %s »" % hint_text())
	var ant: Interactable = am.antenna_it
	await use("Examiner l'antenne", ant.global_position, "antenne_sans")
	await wait(0.5)
	print("antenne : « %s »" % hint_text())
	# la fenêtre de la chambre d'amis (Clovis, avant les caméras)
	await walk([p(-2.4, 4.6)], "vers la fenêtre F3")
	await turn_to((room.outside.clovis as Node3D).global_position + Vector3(0, 0.5, 0), 0.6)
	await wait(0.5)
	await snap("amis_fenetre_clovis_avant")
	# --- étape 11 : le bureau (P7 avec la clé)
	await walk([p(-1.0, 3.75), p(0.4, 3.75), p(2.0, 3.9), p(2.7, 3.45), p(3.85, 3.5), p(4.05, 4.4)], "chambre d'amis vers P7")
	await use("Ouvrir la porte", Vector3(4.75, 1.1, 4.25), "p7_cle")
	await wait(1.6)
	ck("P7 ouverte", (house.doors["P7"] as Door).is_open, "")
	var t_bu := gt
	await walk([p(5.3, 4.4), p(6.2, 4.6)], "P7 vers le bureau")
	await snap("bureau_entree")
	var console: HouseConsole = bu.console
	await until(func() -> bool: return console.booted, 12.0)
	print("console démarrée %.1f s après l'entrée" % (gt - t_bu))
	await turn_to(console.global_position, 0.6)
	await wait(0.4)
	await snap("bureau_console_c1")
	await until(func() -> bool: return not hn.is_busy(), 30.0)
	await snap("bureau_console_c4")
	# le tiroir
	await walk([p(6.65, 4.95)], "vers le tiroir")
	var dr_it: Interactable = bu.drawer_it
	await use("Ouvrir le tiroir", dr_it.global_position, "tiroir")
	await wait(0.8)
	await use("Prendre le tournevis", dr_it.global_position + Vector3(0, -0.02, -0.05), "tournevis")
	await wait(0.8)
	ck("tournevis", Game.has_item("tournevis"), "")
	# l'imprimante : le plan et le croquis
	var pr: Printer = bu.printer
	await until(func() -> bool: return pr.printed.has("croquis_imprime"), 20.0)
	await walk([p(7.9, 5.1)], "vers l'imprimante")
	for k in 2:
		if pr.sheets.is_empty():
			break
		var e: Dictionary = pr.sheets[pr.sheets.size() - 1]
		await use("Prendre la feuille", (e.it as Node3D).global_position, "feuille_%d" % k)
		await wait(0.8)
		await snap("feuille_lue_%d" % k)
		await press_e()
		await wait(0.4)
	ck("plan et croquis", Game.has_item("plan_imprime") and Game.has_item("croquis_imprime"), str(pr.printed))
	# les caméras
	await walk([p(7.2, 4.85)], "devant la console")
	await use("Regarder les caméras", console.global_position, "cameras")
	await wait(1.2)
	await snap("cameras_grand")
	await press_e()
	await wait(0.4)
	ck("écran fermé par E", not hud.screen_open and player.can_move, "")
	await until(func() -> bool: return bool(Game.flag("cameras_vues", false)), 25.0)
	await snap("cameras_indices")
	# le portable de Mamie
	await walk([p(7.0, 3.3)], "vers le portable")
	var lap: Vector3 = Vector3(7.0, 0.85, 2.4)
	await use("Regarder l'ordinateur portable", lap, "portable")
	await wait(0.8)
	await use("Taper le mot de passe", lap, "")
	await wait(2.0)
	await snap("portable_pages")
	for k in 3:
		if hud.paper_open:
			await press_e()
			await wait(0.4)
	# la sortie du bureau : la photo
	await walk([p(5.3, 4.4), p(4.0, 4.2)], "bureau vers le couloir")
	await turn_to(Vector3(3.3, 0.8, 2.6), 0.5)
	await until(func() -> bool: return pr.printed.has("photo_couloir"), 20.0)
	print("photo imprimée : ", pr.printed.has("photo_couloir"))
	await wait(1.0)
	await walk([p(5.3, 4.4), p(7.9, 5.1)], "retour à l'imprimante")
	for e in pr.sheets:
		if e.id == "photo_couloir":
			await use("Prendre la feuille", (e.it as Node3D).global_position, "photo_prise")
			await wait(0.8)
			await snap("photo_lue")
			await press_e()
			break
	ck("photo du couloir", Game.has_item("photo_couloir"), "")
	# --- l'antenne avec le tournevis ; Clovis par la fenêtre après les caméras
	await walk([p(5.3, 4.4), p(4.0, 4.0), p(3.85, 3.45), p(2.7, 3.45), p(2.0, 4.0), p(0.4, 3.75), p(-1.2, 3.75)], "bureau vers la télé")
	await use("Dévisser l'antenne", ant.global_position, "antenne_devisser")
	await until(func() -> bool: return Game.has_item("antenne"), 6.0)
	ck("antenne", Game.has_item("antenne"), "")
	await walk([p(-2.4, 4.6)], "vers la fenêtre F3 (après les caméras)")
	await turn_to((room.outside.clovis as Node3D).global_position + Vector3(0, 0.5, 0), 0.6)
	await wait(1.0)
	await snap("amis_fenetre_clovis_apres")
	print("Clovis vu : %s · pensée « %s »" % [Game.flag("clovis_vu", false), hint_text()])
	ck("Clovis à la fenêtre de la chambre d'amis", bool(Game.flag("clovis_vu", false)), "drapeau clovis_vu absent")
	# --- étape 12 : la salle de bain
	await walk([p(-1.0, 3.75), p(0.4, 3.75), p(2.0, 3.9), p(2.7, 3.45), p(3.95, 3.3), p(4.0, -4.3)], "chambre d'amis vers P4")
	await _sdb("fixe")


## Voie directe : de la chambre de ta mère droit à la salle de bain (le joueur suit l'objectif O3
## sans rien explorer, ou ne frappe même pas à P2) puis l'issue voulue du P4 réel.
func _direct() -> void:
	var hn: Haunt = haunt
	await walk([p(2.7, 1.4), p(3.75, 1.4)], "P1 vers le couloir")
	await until(func() -> bool: return not hn.is_busy(), 40.0)
	await walk([p(3.95, -1.0), p(4.0, -4.3)], "couloir vers P4")
	if voie == "p4absorbe":
		await _p4_absorbe()
		return
	var issue := voie if voie in ["retourne", "fui"] else "fixe"
	await _sdb(issue)


## Voie « P4 qui absorbe » : jauge à 86 avant le P4 réel ; le joueur se retourne (+16 → 100, ABSORBÉ).
## Que contient le point de passage écrit ensuite (C2) ?
func _p4_absorbe() -> void:
	var sb: Node = house.rooms["sdb"]
	var mirror: SmartMirror = sb.mirror
	await use("Ouvrir la porte", Vector3(4.75, 1.1, -4.4), "")
	await wait(1.4)
	await walk([p(5.5, -4.6), p(6.3, -4.9), p(7.0, -4.9)], "vers le miroir")
	var c1 := Game.load_checkpoint()
	print("avant le P4 : point %s, jauge sauvée %.1f" % [c1.get("checkpoint"), float(c1.get("peur", -1))])
	Game.set_peur(86.0, "test joueur : jauge haute")
	var events := {}
	mirror.p4_event.connect(func(st: String) -> void: events[st] = gt)
	await use("Prendre le sèche-cheveux", (sb.dryer_it as Node3D).global_position, "")
	await turn_to(mirror.global_position, 0.5)
	await until(func() -> bool: return events.has("barre"), 60.0)
	await until(func() -> bool: return events.has("rideau"), 10.0)
	await look_dir(0.0, -0.1, 0.4)
	await until(func() -> bool: return acte2.absorbed_screen != "", 10.0)
	await wait(4.0)
	await snap("p4absorbe_sequence")
	var sv := Game.load_checkpoint()
	print("après l'absorption : point %s, jauge sauvée %.1f, phase %s" % [sv.get("checkpoint"), float(sv.get("peur", -1)), Game.phase])
	ck("pas de point de passage écrit après ABSORBÉ", sv.get("checkpoint") == "C1" or float(sv.get("peur", 0.0)) < 100.0,
		"%s écrit avec la jauge %.1f : « Continuer » reprend à 100" % [sv.get("checkpoint"), float(sv.get("peur", -1))])


func _sdb(issue: String) -> void:
	var sb: Node = house.rooms["sdb"]
	var mirror: SmartMirror = sb.mirror
	var hn: Haunt = haunt
	var p4: Door = house.doors["P4"]
	await use("Ouvrir la porte", Vector3(4.75, 1.1, -4.4), "p4_ouvrir")
	await wait(1.4)
	await walk([p(5.5, -4.6), p(6.3, -4.9)], "P4 vers la salle de bain")
	await snap("sdb_entree")
	await walk([p(7.45, -4.95)], "vers l'armoire basse")
	var events := {}
	mirror.p4_event.connect(func(st: String) -> void:
		events[st] = gt
		print("P4 t=%.1f %s" % [gt, st]))
	await use("Prendre le sèche-cheveux", (sb.dryer_it as Node3D).global_position, "seche_cheveux")
	var t_take := gt
	await until(func() -> bool: return mirror.is_on, 3.0)
	print("miroir allumé %.2f s après le sèche-cheveux" % (gt - t_take))
	await wait(0.3)
	await snap("p4_m0_regard_seche_cheveux")     # ce que voit le joueur, encore tourné vers l'armoire
	# le joueur se tourne vers la lumière du miroir, sans bouger
	await turn_to(mirror.global_position, 0.7)
	await wait(1.0)
	await snap("p4_m0_vu_de_cote")
	# il se place devant (un pas), comme devant un lavabo
	await walk([p(7.0, -4.9)], "devant le miroir")
	await turn_to(mirror.global_position, 0.4)
	await until(func() -> bool: return events.has("mode_miroir"), 20.0)
	await wait(1.0)
	await snap("p4_m1_mode_miroir")
	await until(func() -> bool: return mirror.text_lines.size() > 0 and str(mirror.text_lines[0]).begins_with("Tu n"), 40.0)
	await wait(1.0)
	await snap("p4_m5")
	await until(func() -> bool: return events.has("barre"), 40.0)
	match issue:
		"retourne":
			await until(func() -> bool: return events.has("rideau"), 10.0)
			# les anneaux du rideau, derrière : le joueur se retourne (souris)
			await wait(0.5)
			await look_dir(0.0, -0.1, 0.5)
			await wait(0.3)
			await snap("retourne_derriere_soi")
			await until(func() -> bool: return events.has("issue"), 10.0)
			await wait(1.2)
			await snap("retourne_applique")
			await wait(2.0)
			await turn_to(mirror.global_position, 0.5)
			await wait(2.5)
			await snap("retourne_retour_miroir_m9b")
			await wait(4.0)
			await snap("retourne_m9b_suite")
		"fui":
			await until(func() -> bool: return events.has("rideau"), 10.0)
			await wait(0.6)
			await walk([p(6.0, -4.7), p(5.4, -4.6), p(4.1, -4.5)], "fuite vers le couloir", true)
			await until(func() -> bool: return events.has("issue"), 10.0)
			await snap("fui_couloir")
			await until(func() -> bool: return hn.said("nestor").has("Tu as fui. Ça compte aussi. Consigné."), 15.0)
			await snap("fui_m9c")
		_:
			await until(func() -> bool: return events.has("rideau"), 10.0)
			await wait(0.3)
			await snap("fixe_rideau_t2")
			await until(func() -> bool: return events.has("silhouette"), 10.0)
			await wait(0.4)
			await snap("fixe_silhouette_t5")
			await until(func() -> bool: return events.has("saut"), 10.0)
			await wait(2.6)
			await snap("fixe_saut_t10")
			await until(func() -> bool: return events.has("souffle"), 10.0)
			await snap("fixe_souffle_t13")
			await until(func() -> bool: return events.has("issue"), 10.0)
			await wait(1.0)
			await snap("fixe_issue")
	await until(func() -> bool: return acte2.p4_issue != "", 30.0)
	print("P4 réel « %s » : %.1f s après le sèche-cheveux" % [acte2.p4_issue, gt - t_take])
	ck("issue " + issue, acte2.p4_issue == issue, acte2.p4_issue)
	await until(func() -> bool: return Game.load_checkpoint().get("checkpoint") == "C2", 10.0)
	ck("C2", Game.load_checkpoint().get("checkpoint") == "C2", str(Game.load_checkpoint().get("checkpoint")))
	print("objectif après le P4 : %s / %s" % [Game.objective_text, Game.objective_sub])
	# libre : on ressort de la salle de bain par P4 (à pied)
	await wait(1.0)
	if house.current and house.current.room_id == "sdb":
		await walk([p(6.0, -4.7), p(5.4, -4.6), p(4.1, -4.5)], "sortie de la salle de bain après le P4")
	await snap("apres_p4_couloir")
	ck("joueur libre après le P4", player.can_move and house.current.room_id == "couloir", house.current.room_id)
	# fin provisoire (si les trois conditions sont réunies), sinon l'indice qui guide
	if Game.has_item("antenne"):
		await until(func() -> bool: return acte2.end_card_shown, 40.0)
		await wait(2.0)
		await snap("fin_031")
		await until(func() -> bool: return Game.phase == "title", 20.0)
		await wait(0.6)
		await snap("titre_apres")
	else:
		await wait(2.0)
		print("indice suivant : ", acte2.explore_hint())


## Voie « pressé » : le joueur sort et va tout droit à la porte du fond (P2) pendant que Nestor parle
## encore (N1 à N4), et frappe. On relève l'ordre des sous-titres.
func _presse() -> void:
	var hn: Haunt = haunt
	await walk([p(2.7, 1.4), p(3.75, 1.4)], "P1 vers le couloir")
	await until(func() -> bool: return hn.said("nestor").size() >= 1, 8.0)
	await walk([p(3.95, -1.0), p(3.85, -3.6)], "couloir vers P2 (pressé)")
	await use("Frapper à la porte", Vector3(3.25, 1.2, -3.45), "presse_p2")
	await wait(3.0)
	await snap("presse_apres_coups")
	await until(func() -> bool: return not hn.is_busy() and hud.current_subtitle == "", 80.0)
	var order: Array = hn.said("nestor")
	print("ORDRE des répliques de Nestor : ")
	for t in order:
		print("   · ", t)
	var want: Array = []
	for l in [Acte2.N1, Acte2.N2, Acte2.N3, Acte2.N4, Acte2.N5, Acte2.N6, Acte2.N7]:
		want.append(hn.fill(l))
	ck("ordre N1…N4 puis N5…N7", order.slice(0, 7) == want, str(order))
	ck("objectif O3 après la double scène", Game.objective_text == Acte2.O3, Game.objective_text)
	await snap("presse_fin")


## Voie « absorbé » : après l'éveil du couloir, la jauge atteint 100 (B15). Ce que voit le joueur,
## sans le mode turbo du terminal, toutes les 1,5 s.
func _absorbe_couloir() -> void:
	var hn: Haunt = haunt
	await walk([p(2.7, 1.4), p(3.75, 1.4), p(4.0, 0.4)], "P1 vers le couloir")
	await until(func() -> bool: return not hn.is_busy(), 40.0)
	await look_dir(0.0, -0.05)
	Game.set_peur(100.0, "test joueur")
	var t0 := gt
	for k in 18:
		await wait(1.5)
		await snap("absorbe_%02d" % k)
		print("  absorbé t+%.1f : écran « %s » · grand écran %s · fondu %.2f · phase %s" % [gt - t0, acte2.absorbed_screen, hud.screen_open, hud.fade.color.a, Game.phase])
	await until(func() -> bool: return hud.fade.color.a > 0.95, 30.0)
	await wait(3.0)
	await snap("absorbe_epilogue")


## Voie « inventaire » : l'inventaire plein de la fin de l'étage (objets du § 5.4), tel que le joueur le voit.
func _inventaire() -> void:
	Game.add_item("journal_manon", "Journal de Maman (2016)", "", "doc")
	Game.add_item("cle_bureau", "Clé du bureau", "Un double. Étiquette de Mamie : BUREAU. Il était dans la boîte à biscuits.", "cle")
	Game.add_item("tournevis", "Tournevis de Papi", "Une étiquette « A. » sur le manche. Évidemment.", "outil")
	Game.add_item("plan_imprime", "Plan de l'étage", "Imprimé par elle. La salle de bain est entourée.", "doc")
	Game.add_item("croquis_imprime", "Croquis du Fractionneur", "Imprimé par elle. « Construis-le. Je veux voir. »", "doc")
	Game.add_item("photo_couloir", "Photo du couloir, 03:2x", "Le couloir vide. Juste le rond de ta lampe.", "doc")
	Game.add_item("seche_cheveux", "Sèche-cheveux de Mamie", "Un Calor de 1994. Le boîtier et la gâchette du croquis.", "arme")
	Game.add_item("antenne", "Antenne télescopique", "Les oreilles de lapin de la vieille télé.", "arme")
	await wait(0.5)
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(0.6)
	await snap("inventaire_plein")
	ck("inventaire ouvert par Tab", hud.inv_open, "")
	ck("inventaire dans l'écran", hud.inv.get_global_rect().end.y <= 360.5 and hud.inv.get_global_rect().end.x <= 640.5, str(hud.inv.get_global_rect()))
	print("textes de l'inventaire : ", hud.inv_list.text if "text" in hud.inv_list else "")


## Voie « absorbé, puis E » : pendant la séquence ABSORBÉ (grand écran), le joueur appuie sur E (le pied
## de l'écran dit « E OU ÉCHAP POUR FERMER »). Peut-il refermer l'écran et marcher ?
func _absorbe_e() -> void:
	var hn: Haunt = haunt
	await walk([p(2.7, 1.4), p(3.75, 1.4), p(4.0, 0.4)], "P1 vers le couloir")
	await until(func() -> bool: return not hn.is_busy(), 40.0)
	Game.set_peur(100.0, "test joueur")
	await until(func() -> bool: return hud.screen_open, 10.0)
	await wait(2.0)
	await snap("absorbe_e_avant")
	await press_e()
	await wait(0.5)
	print("après E : grand écran %s · can_move %s · can_look %s · phase %s" % [hud.screen_open, player.can_move, player.can_look, Game.phase])
	var p0: Vector3 = player.global_position
	Input.action_press("move_forward")
	await wait(1.5)
	Input.action_release("move_forward")
	var moved: float = player.global_position.distance_to(p0)
	await snap("absorbe_e_apres")
	ck("ABSORBÉ : l'écran ne se ferme pas et le joueur ne marche pas", hud.screen_open and moved < 0.05,
		"grand écran %s, le joueur a marché %.2f m pendant la séquence (phase %s)" % [hud.screen_open, moved, Game.phase])
