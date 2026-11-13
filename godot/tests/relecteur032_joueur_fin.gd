extends "res://scripts/main.gd"
## Relecture « joueur » de la 0.3.2 (banc de relecteur032_joueur, exclu de l'export) : la fin de
## l'acte II jouée comme un joueur qui ne connaît pas le jeu. On marche (actions de déplacement, avec la
## physique), on tourne le regard peu à peu, on appuie sur E, 1, 2, Échap par de vrais événements
## clavier. Game.autotest reste faux : sauvegarde, titre et rechargement de la scène comme dans le jeu.
## Raccourcis seulement pour l'étage déjà exploré (objets, drapeaux, portes) ; la convocation, la
## séance 2 et la fin passent par le vrai chemin.
##   XDG_DATA_HOME=… godot --path godot --rendering-driver vulkan res://tests/relecteur032_joueur_fin.tscn -- --shots=DIR --voie=traine|presse
## Voies :
## - traine : P4 réel en dernier (« fixe »), la convocation part dans la salle de bain ; le joueur va
##   dans le bureau et y traîne 10 minutes de jeu ; il revient par le couloir, répond, appuie sur Échap
##   pendant le choix minuté et pendant le cœur, laisse passer le délai ; fin, titre, « Continuer ».
## - presse : P4 réel fait d'abord, l'antenne en dernier (Aurèlia) : la convocation part dans la
##   chambre d'amis ; le joueur court à l'ordinateur et répond pendant N10/N11 ; « Changer d'avis » puis
##   « Moi » ; il essaie de se lever ; fin, titre, « Continuer ».

const META := "relecteur032_joueur_etape"

var voie := "traine"
var stage := 1
var fails := 0
var checks := 0
var gt := 0.0                 # temps de jeu (somme des delta)
var shot_n := 0
var real_e := false
var meas_bus := -1
var amb_bus := -1
var zone := ""                # où l'on mesure le chant du modem
var peaks := {}               # zone → [crête du modem (dB), crête de l'ambiance (dB), échantillons]
var modem_seen := 0
var t_conv := -1.0


func _ready() -> void:
	stage = int(Engine.get_meta(META, 1))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--voie="):
			voie = a.substr(7)
	super()
	Engine.max_physics_steps_per_frame = 60
	if stage == 1:
		Engine.set_meta(META, 2)
		_run.call_deferred()
	else:
		_stage2.call_deferred()


func _process(delta: float) -> void:
	gt += delta
	# le chant du modem passe par un bus de mesure (renvoyé tel quel vers Master : on n'entend rien
	# de différent) pour lire son niveau à l'oreille du joueur
	if meas_bus >= 0 and room.modem and is_instance_valid(room.modem):
		if room.modem.bus != "Mesure":
			room.modem.bus = "Mesure"
			modem_seen += 1
		if room.modem.playing and zone != "":
			var m := maxf(AudioServer.get_bus_peak_volume_left_db(meas_bus, 0), AudioServer.get_bus_peak_volume_right_db(meas_bus, 0))
			var a := maxf(AudioServer.get_bus_peak_volume_left_db(amb_bus, 0), AudioServer.get_bus_peak_volume_right_db(amb_bus, 0))
			var e: Array = peaks.get(zone, [-200.0, -200.0, 0])
			e[0] = maxf(float(e[0]), m)
			e[1] = maxf(float(e[1]), a)
			e[2] = int(e[2]) + 1
			peaks[zone] = e


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


## Attente en temps réel (les choix du terminal se comptent à l'horloge).
func wait_real(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame


func until(cond: Callable, timeout := 30.0) -> bool:
	var t0 := gt
	var r0 := Time.get_ticks_msec()
	while not cond.call():
		# (pause : gt n'avance plus ; on borne aussi à l'horloge)
		if gt - t0 > timeout or Time.get_ticks_msec() - r0 > int(timeout * 1000.0) + 60000:
			print("ATTENTE TROP LONGUE (%.0f s)" % timeout)
			return false
		await get_tree().process_frame
	return true


func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	shot_n += 1
	var nm := "%d_%02d_%s" % [stage, shot_n, n]
	if Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(nm + ".png"))
	print("capture %s (t=%.1f, pos %s, pièce %s, objectif « %s »)" % [nm, gt, _v(player.global_position), house.current.room_id if house.current else "?", Game.objective_text])


## L'écran de l'ordinateur à plat (texture du terminal).
func snap_term(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := (terminal as Control).get_viewport().get_texture().get_image()
	shot_n += 1
	var nm := "%d_%02d_%s" % [stage, shot_n, n]
	if Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(nm + ".png"))
	print("capture %s (écran du terminal)" % nm)


static func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


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
				ok = false
				break
		Input.action_release("move_forward")
		Input.action_release("sprint")
		if not ok:
			await snap("bloque_" + tag)
			player.global_position = Vector3(target.x, player.global_position.y, target.z)
			ok = true
			ck("passage " + tag, false, "bloqué")
			await get_tree().physics_frame
	return ok


func key(code: Key, hold := 0.0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	if hold > 0.0:
		await wait_real(hold)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func press_e() -> void:
	if real_e:
		await key(KEY_E)
	elif player.current:
		player.current.use()


func use(expected: String, target: Vector3, tag := "", press := true) -> bool:
	await turn_to(target, 0.4)
	await wait(0.4)
	var got: String = player.current.label if player.current else "rien"
	if got != expected:
		for o in [Vector3(0, 0.06, 0), Vector3(0, -0.06, 0), Vector3(0.06, 0, 0.06), Vector3(-0.06, 0, -0.06), Vector3(0, 0.12, 0), Vector3(0, -0.12, 0)]:
			await turn_to(target + o, 0.15)
			await wait(0.15)
			got = player.current.label if player.current else "rien"
			if got == expected:
				break
	ck("vise « %s »%s" % [expected, " (" + tag + ")" if tag != "" else ""], got == expected,
		"libellé « %s » depuis %s" % [got, _v(player.global_position)])
	if tag != "":
		await snap(tag)
	if got == expected and press:
		await press_e()
		return true
	return false


func p(x: float, z: float) -> Vector3:
	return Vector3(x, 0, z)


func _pause_btn(text: String) -> Button:
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "> " + text and (b as Button).is_visible_in_tree():
			return b
	return null


func _setup_meas() -> void:
	AudioServer.add_bus()
	meas_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(meas_bus, "Mesure")
	AudioServer.set_bus_send(meas_bus, "Master")
	amb_bus = AudioServer.get_bus_index("Ambiance")


func _peak_report() -> void:
	for z in peaks:
		var e: Array = peaks[z]
		print("NIVEAU modem « %s » : crête %.1f dB (ambiance %.1f dB, %d images)" % [z, float(e[0]), float(e[1]), int(e[2])])


# ------------------------------------------------------------------ déroulé

func _run() -> void:
	menu.hide_all()
	Game.seen_warning = true
	Game.fullscreen = false
	Game.sound_captions = voie == "traine"
	Game.save_settings()
	Game.apply_settings()
	hud.fade.color.a = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# (presse : le niveau du modem est déjà mesuré ; sans bus de mesure, le chemin audio est celui du jeu)
	if voie != "presse":
		_setup_meas()
	await wait(0.6)
	real_e = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	print("JOUEUR032 début · voie %s · souris capturée %s · sous-titres des sons %s" % [voie, real_e, Game.sound_captions])
	hud.subtitle_shown.connect(func(who: String, text: String) -> void:
		print("SOUS-TITRE t=%.1f %s : %s" % [gt, who, text]))
	Game.hint_requested.connect(func(text: String, sec: float) -> void:
		if text != "":
			print("PENSÉE t=%.1f (%.1f s) %s" % [gt, sec, text]))
	Game.objective_changed.connect(func(text: String) -> void:
		print("OBJECTIF t=%.1f « %s » / « %s »" % [gt, text.replace("\n", " / "), Game.objective_sub]))
	Game.peur_changed.connect(func(v: float) -> void:
		if absf(v - roundf(v)) < 0.01:
			print("JAUGE t=%.1f %.1f" % [gt, v]))
	if voie == "presse":
		Game.hero = "aurelia"
	if voie == "ecran":
		await _ecran()
		return
	await _after_seance()
	await _couloir()
	match voie:
		"presse":
			await _presse()
		"absorbe":
			await _absorbe_s2()
		_:
			await _traine()
	print("%d vérifications, %d échec(s) (étape 1)" % [checks, fails])


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
	await wait(0.5)
	await walk([p(2.0, 1.2)], "chambre vers la clé")
	await use("Ramasser la clé et le mot", Vector3(2.88, 0.02, 1.32), "")
	await wait(0.8)
	await press_e()
	await wait(0.4)
	await use("Ouvrir la porte", Vector3(3.2, 1.2, 1.25), "")
	await wait(1.6)


## Le couloir (première entrée, N1 à N4), puis l'étage déjà exploré par raccourci.
func _couloir() -> void:
	await walk([p(2.7, 1.4), p(3.75, 1.4)], "P1 vers le couloir")
	await until(func() -> bool: return haunt.said("nestor").size() >= 4 and not haunt.is_busy(), 60.0)
	print("couloir : N1 à N4 dits, t=%.1f" % gt)


func _shortcut_floor(with_antenna: bool, with_p4: bool) -> void:
	var items := [
		["cle_bureau", "Clé du bureau", "Un double. Étiquette de Mamie : BUREAU. Il était dans la boîte à biscuits.", "cle"],
		["tournevis", "Tournevis de Papi", "Une étiquette « A. » sur le manche. Évidemment.", "outil"],
		["plan_imprime", "Plan de l'étage", "Imprimé par elle. La salle de bain est entourée.", "doc"],
		["croquis_imprime", "Croquis du Fractionneur", "Imprimé par elle. « Construis-le. Je veux voir. »", "doc"],
		["photo_couloir", "Photo du couloir, 03:2x", "Le couloir vide. Juste le rond de ta lampe.", "doc"],
	]
	if with_antenna:
		items.append(["antenne", "Antenne télescopique", "Les oreilles de lapin de la vieille télé.", "arme"])
	if with_p4:
		items.append(["seche_cheveux", "Sèche-cheveux de Mamie", "Un Calor de 1994. Le boîtier et la gâchette du croquis.", "arme"])
	for k in ["entree_amis", "entree_bureau", "babyphone_parle", "tele_a_neige", "boite_ouverte", "antenne_examinee",
			"cameras_vues", "croquis_lu", "imprime_plan_imprime", "imprime_croquis_imprime", "imprime_photo_couloir"]:
		Game.set_flag(k, true)
	if with_antenna:
		Game.set_flag("antenne_prise", true)
	Game.set_flag("p2_coups", 2)
	(house.doors["P2"] as Door).knocks = 2
	Game.set_flag("sos_joue", true)
	Game.set_flag("habite", "console")
	for id in ["P3", "P7"]:
		var dr: Door = house.doors[id]
		dr.unlock()
		dr.set_open_now(true)
		Game.set_flag("porte_" + id, "ouverte")
	if with_p4:
		Game.set_flag("entree_sdb", true)
		Game.set_flag("seche_cheveux_pris", true)
		Game.set_flag("p4_reel_fait", true)
		Game.choices["miroir_reel"] = "retourne"
		var p4: Door = house.doors["P4"]
		p4.set_open_now(true)
		Game.set_flag("porte_P4", "ouverte")
	# (les objets en dernier : comme dans le jeu, le dernier ramassé vérifie la convocation)
	for it in items:
		Game.add_item(it[0], it[1], it[2], it[3])
	acte2._set_step(acte2._step())
	acte2._refresh_objective()
	await wait(0.4)


## Indice de 90 s (accéléré ×30), pour l'étape courante : texte dit.
func _hint_now(tag: String) -> String:
	var n0: int = haunt.hints_given
	haunt.hint_speed = 30.0
	await until(func() -> bool: return haunt.hints_given > n0, 20.0)
	haunt.hint_speed = 1.0
	var txt := ""
	for i in range(haunt.journal.size() - 1, -1, -1):
		var e: Variant = haunt.journal[i]
		if e is Dictionary and str(e.get("ev", "")) == "indice":
			txt = str(e.get("text", ""))
			break
	print("INDICE (%s) : « %s »" % [tag, txt])
	return txt


# ------------------------------------------------------------------ voie « traine »

func _traine() -> void:
	await _shortcut_floor(true, false)
	# sans le P4 réel : pas de convocation, l'indice envoie au miroir
	var h := await _hint_now("sans P4")
	ck("sans P4 : indice du miroir, pas de convocation", h == Acte2.HINT_MIROIR and not bool(Game.flag("convocation", false)), h)
	await walk([p(3.95, -1.0), p(4.0, -4.3)], "couloir vers P4")
	await look_dir(PI, -0.05)
	await snap("couloir_vers_le_fond_noir")
	await use("Ouvrir la porte", Vector3(4.75, 1.1, -4.4), "")
	await wait(1.4)
	await walk([p(5.5, -4.6), p(6.3, -4.9), p(7.45, -4.95)], "vers l'armoire basse")
	var sb: Node = house.rooms["sdb"]
	var mirror: SmartMirror = sb.mirror
	var events := {}
	mirror.p4_event.connect(func(st: String) -> void: events[st] = gt)
	await use("Prendre le sèche-cheveux", (sb.dryer_it as Node3D).global_position, "")
	await turn_to(mirror.global_position, 0.7)
	await walk([p(7.0, -4.9)], "devant le miroir")
	await turn_to(mirror.global_position, 0.4)
	Engine.time_scale = 2.0
	await until(func() -> bool: return events.has("issue"), 120.0)
	Engine.time_scale = 1.0
	await until(func() -> bool: return acte2.p4_issue != "", 30.0)
	var t_issue := gt
	print("P4 « %s »" % acte2.p4_issue)
	zone = "salle de bain (devant le miroir)"
	await until(func() -> bool: return bool(Game.flag("convocation", false)), 60.0)
	t_conv = gt
	print("CONVOCATION %.1f s après l'issue du P4 · C3 %s" % [t_conv - t_issue, Game.load_checkpoint().get("pos")])
	await until(func() -> bool: return room.convoking, 10.0)
	await wait(0.8)
	await snap("convoc_modem_salle_de_bain")
	print("cœur pendant le chant : %.1f dB" % Sfx.heart_db)
	await until(func() -> bool: return haunt.said("nestor").has(haunt.fill(Acte2.N10)), 20.0)
	await wait(0.6)
	await snap("convoc_n10")
	print("SOUS-TITRES sous N10 : son « %s » visible %s rect %s · dialogue visible %s rect %s · pensée « %s »" % [hud.snd_lbl.text, hud.snd_lbl.visible, hud.snd_lbl.get_global_rect(),
		hud.sub_lbl.visible, hud.sub_lbl.get_global_rect(), hud.hint_lbl.text if hud.hint_lbl.modulate.a > 0.05 else ""])
	print("cœur sous N10 : %.1f dB (courbe %.1f dB)" % [Sfx.heart_db, Sfx.heart_curve_db])
	await until(func() -> bool: return haunt.said("nestor").has(haunt.fill(Acte2.N11)), 20.0)
	await wait(0.6)
	await snap("convoc_n11")
	await until(func() -> bool: return Game.objective_text == Acte2.O4, 20.0)
	await wait(0.3)
	await snap("convoc_o4")
	ck("O4 après N10 N11", Game.objective_text == Acte2.O4, Game.objective_text)
	# le joueur ne revient pas : il va au fond du bureau et traîne
	await walk([p(6.3, -4.9), p(5.5, -4.6), p(4.1, -4.5), p(4.0, 0.4)], "salle de bain vers le couloir")
	zone = "couloir (milieu)"
	await wait(3.0)
	await walk([p(4.0, 4.2), p(5.3, 4.4), p(6.4, 4.4), p(8.2, 3.6)], "couloir vers le fond du bureau")
	zone = "bureau (fond)"
	await look_dir(PI / 2.0, -0.05)
	await wait(2.0)
	await snap("bureau_on_entend")
	var p0 := Game.peur
	var h0: int = haunt.hints_given
	var m0: int = room.modem_plays
	Engine.time_scale = 6.0
	await until(func() -> bool: return haunt.hints_given > h0, 200.0)
	Engine.time_scale = 1.0
	await wait(0.3)
	await snap("bureau_indice")
	Engine.time_scale = 6.0
	await until(func() -> bool: return acte2.conv_elapsed >= 600.0, 700.0)
	Engine.time_scale = 1.0
	print("TRAÎNE : %.0f s de jeu depuis la convocation · indices %d · chants du modem %d · jauge %.1f → %.1f" % [acte2.conv_elapsed, haunt.hints_given - h0, room.modem_plays - m0, p0, Game.peur])
	ck("traîne : le modem appelle encore", room.convoking and room.modem_plays > m0, "")
	await snap("bureau_apres_10_min")
	# retour : bureau, couloir dans le noir, chambre
	await walk([p(6.4, 4.4), p(5.3, 4.4), p(4.0, 4.0)], "bureau vers le couloir")
	await look_dir(0.0, -0.05)
	zone = "couloir (devant P7)"
	await wait(0.5)
	await snap("retour_couloir_vers_p1")
	await walk([p(3.95, 1.4)], "couloir vers P1")
	await look_dir(PI / 2.0, -0.05)
	await wait(0.5)
	await snap("retour_seuil_chambre")
	await walk([p(2.7, 1.4), p(1.6, 0.2), p(1.25, -0.95)], "chambre vers l'ordinateur")
	zone = ""
	await use("Répondre à l'ordinateur", room.screen_center + Vector3(0, -0.12, 0), "vise_ordinateur")
	await _seance_traine()


func _seance_traine() -> void:
	await until(func() -> bool: return acte2.seance != null and player.seated, 15.0)
	var sc: Seance2 = acte2.seance
	await until(func() -> bool: return sc.said.size() >= 2, 60.0)
	await wait(2.0)
	await snap("seance_ligne3")
	await snap_term("ecran_ligne3")
	print("LIGNE 3 : « %s »" % sc.said[1])
	ck("ligne 3 après 10 min", str(sc.said[1]) == "Tu as mis 10 minutes à revenir. Je n'ai rien fait pendant ce temps. Presque rien.", str(sc.said[1]))
	# le choix minuté
	await until(func() -> bool: return not terminal._choice.is_empty(), 900.0)
	await wait_real(2.5)
	await snap("choix_compte_a_rebours")
	await snap_term("ecran_choix")
	var before := str(terminal.timer_val.text)
	var fill_before: float = terminal.timer_fill.size.x
	await key(KEY_ESCAPE)
	await wait_real(0.5)
	ck("Échap pendant le choix : pause", get_tree().paused and menu.pause_box.visible, "pause %s" % get_tree().paused)
	await snap("choix_pause")
	await wait_real(5.0)
	ck("pause : le délai ne court pas", str(terminal.timer_val.text) == before and is_equal_approx(terminal.timer_fill.size.x, fill_before) and not terminal._choice.is_empty(),
		"%s → %s" % [before, terminal.timer_val.text])
	var b := _pause_btn("Reprendre")
	ck("bouton « Reprendre »", b != null, "")
	if b:
		b.pressed.emit()
	await wait_real(0.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# on ne répond pas : le délai passe
	await until(func() -> bool: return terminal._choice.is_empty(), 30.0)
	await wait_real(1.5)
	await snap("choix_delai")
	await snap_term("ecran_delai")
	await until(func() -> bool: return Game.choices.has("prix_confirme"), 20.0)
	print("DÉLAI : issue %s · prix_confirme %s" % [sc.issue, Game.choices.get("prix_confirme")])
	ck("délai : elle garde le proche", sc.issue == "delai" and Game.choices.get("prix_confirme") == "proche", str(Game.choices.get("prix_confirme")))
	# le cœur
	await until(func() -> bool: return terminal.heart_bpm == 58, 40.0)
	await wait(0.6)
	await snap("coeur_58")
	await until(func() -> bool: return terminal.heart_bpm == 55, 20.0)
	await key(KEY_ESCAPE)
	await wait_real(3.0)
	ck("pause pendant le cœur : il ne descend plus", terminal.heart_bpm == 55 and get_tree().paused, "♥ %d" % terminal.heart_bpm)
	var b2 := _pause_btn("Reprendre")
	if b2:
		b2.pressed.emit()
	await wait_real(0.3)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await until(func() -> bool: return terminal.heart_bpm == 52, 20.0)
	await wait(0.8)
	await snap("coeur_52")
	await snap_term("ecran_coeur_52")
	print("cœur du héros pendant la séance : %.1f dB" % Sfx.heart_db)
	await _fin()


func _fin() -> void:
	var sc: Seance2 = acte2.seance
	await until(func() -> bool: return sc.done, 40.0)
	print("SÉANCE 2 écrite : ")
	for l in sc.said:
		print("   · ", l)
	await until(func() -> bool: return acte2.end_card_shown, 40.0)
	await wait(2.5)
	await snap("carte_fin")
	_peak_report()
	print("%d vérifications, %d échec(s) avant le rechargement" % [checks, fails])
	print("ATTENTE du rechargement (retour au titre)")


# ------------------------------------------------------------------ voie « presse »

func _presse() -> void:
	await _shortcut_floor(false, true)
	var h := await _hint_now("P4 fait, tournevis, sans antenne")
	ck("indice de l'antenne", h == Acte2.HINT_ANTENNE, h)
	var am: Node = house.rooms["amis"]
	await walk([p(3.9, 3.45), p(2.7, 3.45), p(2.0, 4.0), p(0.4, 3.75), p(-1.2, 3.75)], "couloir vers la télé")
	zone = "chambre d'amis (télé)"
	var ant: Interactable = am.antenna_it
	await use("Dévisser l'antenne", ant.global_position, "")
	await until(func() -> bool: return bool(Game.flag("convocation", false)), 30.0)
	t_conv = gt
	var c3 := Game.load_checkpoint()
	print("CONVOCATION dans la chambre d'amis · C3 %s" % c3.get("pos"))
	ck("C3 au couloir devant la chambre", (c3.get("pos", Vector3.ZERO) as Vector3).distance_to(Acte2.C3_POS) < 0.05, str(c3.get("pos")))
	await until(func() -> bool: return room.convoking, 10.0)
	await wait(1.0)
	await snap("convoc_amis")
	# le joueur court à l'ordinateur dès qu'il entend le modem
	zone = ""
	await walk([p(0.4, 3.75), p(2.0, 3.9), p(2.7, 3.45), p(3.85, 3.3), p(3.9, 1.4), p(2.7, 1.4), p(1.6, 0.2), p(1.25, -0.95)], "course vers l'ordinateur", true)
	var t_arrive := gt
	var said_n := haunt.said("nestor").size()
	print("ARRIVÉE %.1f s après la convocation · N10 dit %s · N11 dit %s · scène %s" % [t_arrive - t_conv, haunt.said("nestor").has(haunt.fill(Acte2.N10)),
		haunt.said("nestor").has(haunt.fill(Acte2.N11)), haunt.is_busy()])
	await use("Répondre à l'ordinateur", room.screen_center + Vector3(0, -0.12, 0), "vise_ordinateur_presse")
	await until(func() -> bool: return acte2.seance != null and player.seated, 15.0)
	await wait(1.0)
	await snap("assis_pendant_n10_n11")
	await until(func() -> bool: return not haunt.is_busy(), 30.0)
	await wait(0.5)
	print("après N11 : objectif « %s » · phase %s · assis %s" % [Game.objective_text, Game.phase, player.seated])
	ck("assis : pas d'objectif O4 qui revient", Game.objective_text == "", Game.objective_text)
	var sc: Seance2 = acte2.seance
	await until(func() -> bool: return sc.said.size() >= 2, 60.0)
	print("LIGNE 3 : « %s »" % sc.said[1])
	ck("ligne 3 « revenue vite »", str(sc.said[1]) == "Tu es revenue vite. C'est bien. Ou c'est la peur.", str(sc.said[1]))
	# il essaie de se lever, d'ouvrir l'inventaire
	var pos0: Vector3 = player.global_position
	Input.action_press("move_back")
	await wait_real(1.0)
	Input.action_release("move_back")
	await key(KEY_E)
	await key(KEY_TAB)
	await wait(0.4)
	await snap("essaie_de_partir")
	print("se lever : assis %s · déplacé %.2f m · inventaire %s · papier %s" % [player.seated, player.global_position.distance_to(pos0), hud.inv_open, hud.paper_open])
	ck("assis : on ne part pas", player.seated and player.global_position.distance_to(pos0) < 0.05, "")
	if hud.inv_open:
		await key(KEY_TAB)
	# « Changer d'avis » (2), puis le premier des deux autres (1)
	await until(func() -> bool: return not terminal._choice.is_empty(), 900.0)
	await wait_real(1.5)
	await snap_term("ecran_premier_choix")
	await key(KEY_2)
	await until(func() -> bool: return terminal._choice.is_empty(), 20.0)
	await until(func() -> bool: return not terminal._choice.is_empty(), 60.0)
	await wait_real(1.5)
	await snap("second_choix")
	await snap_term("ecran_second_choix")
	await key(KEY_1)
	await until(func() -> bool: return Game.choices.has("prix_confirme"), 60.0)
	ck("changer d'avis : « Moi »", sc.issue == "changer" and Game.choices.get("prix_confirme") == "toi", "%s %s" % [sc.issue, Game.choices.get("prix_confirme")])
	await until(func() -> bool: return terminal.heart_bpm == 52, 60.0)
	await wait(0.8)
	await snap("coeur_52_presse")
	await _fin()


# ------------------------------------------------------------------ voie « ecran »

## Lisibilité, assis devant l'ordinateur (vue du joueur) : l'afficheur « ♥ 52 » et le compte à rebours
## « DÉLAI » tels qu'ils sont, puis avec les réglages proposés (appliqués ici au terminal, pas au jeu).
func _ecran() -> void:
	Game.phase = "room"
	Game.choices = {"proche": "Mamie", "prix": "personne", "reflet": "fixe"}
	terminal.set_fear(55.0)
	room.restore_after_seance()
	await player.sit(room.seat_pos, room.screen_center)
	terminal.show_static([["Ta grand-mère dort.", "n"], ["Son cœur bat à 58.", "n"], ["57.", "n"], ["55.", "n"]])
	terminal.mode = "seance"
	terminal.status.visible = true
	await wait(1.0)
	terminal.set_heart(52)
	await wait(1.5)
	await snap("coeur_52_tel_quel")
	await snap_term("ecran_coeur_52_tel_quel")
	# proposition : chiffre en 40 px, cœur ×2, plus au centre et un peu plus bas (hors du vignetage)
	terminal.heart_val.add_theme_font_size_override("font_size", 40)
	terminal.heart_val.position = Vector2(34, -6)
	terminal.heart_icon.scale = Vector2(2, 2)
	terminal.heart_icon.position = Vector2(0, 4)
	terminal.heart_box.position = Vector2(300, 8)
	await wait(1.5)
	await snap("coeur_52_propose")
	await snap_term("ecran_coeur_52_propose")
	# le compte à rebours, tel quel puis décalé à gauche
	terminal.hide_heart()
	terminal.timer_box.visible = true
	terminal.timer_val.text = "07"
	terminal.timer_fill.size.x = 77.0
	await wait(1.5)
	await snap("delai_tel_quel")
	terminal.timer_box.position = Vector2(300, 0)
	await wait(1.5)
	await snap("delai_decale_300")
	print("JOUEUR032 FIN écran")
	print("QUIT demandé")
	get_tree().quit(0)


# ------------------------------------------------------------------ voie « absorbe »

## La jauge est haute (92) quand la convocation part au couloir ; le joueur répond et laisse passer le
## délai (+10) : ABSORBÉ pendant la séance 2, « Te lever », épilogue, titre (scène rechargée), puis
## « Continuer » et « Quitter » : le jeu se ferme-t-il ?
func _absorbe_s2() -> void:
	Game.set_peur(92.0, "test joueur : jauge haute")
	await _shortcut_floor(true, true)
	await until(func() -> bool: return bool(Game.flag("convocation", false)), 30.0)
	var c3 := Game.load_checkpoint()
	print("CONVOCATION au couloir · C3 %s · jauge sauvée %.1f" % [c3.get("pos"), float(c3.get("peur", -1))])
	await until(func() -> bool: return room.convoking, 10.0)
	await walk([p(2.7, 1.4), p(1.6, 0.2), p(1.25, -0.95)], "vers l'ordinateur")
	await until(func() -> bool: return room.pc_it.enabled, 15.0)
	await use("Répondre à l'ordinateur", room.screen_center + Vector3(0, -0.12, 0), "")
	await until(func() -> bool: return acte2.seance != null and player.seated, 15.0)
	var sc: Seance2 = acte2.seance
	if sc == null:
		ck("séance 2 commencée", false, "")
		return
	await until(func() -> bool: return sc.issue == "absorbe", 900.0)
	await wait(3.0)
	await snap("s2_absorbe")
	await until(func() -> bool: return acte1.waiting_stand, 120.0)
	await wait(0.5)
	await snap("s2_absorbe_te_lever")
	print("ABSORBÉ : jauge %.1f · phase %s · étape %s · C3 gardé %s" % [Game.peur, Game.phase, haunt.step_id, Game.load_checkpoint().get("checkpoint")])
	await key(KEY_E)
	await wait(2.0)
	await snap("s2_absorbe_epilogue")
	print("ATTENTE du rechargement (épilogue)")


# ------------------------------------------------------------------ étape 2 : après le rechargement

func _stage2() -> void:
	print("JOUEUR032 étape 2 · voie %s · titre %s · continuer %s · phase %s" % [voie, menu.title_box.visible, menu.continue_btn.visible, Game.phase])
	await wait(1.0)
	await snap("titre")
	ck("titre avec « Continuer »", menu.title_box.visible and menu.continue_btn.visible, "")
	var sv := Game.load_checkpoint()
	print("sauvegarde : %s · fin_v03 %s · pos %s · jauge %.1f" % [sv.get("checkpoint"), (sv.get("flags", {}) as Dictionary).get("fin_v03"), sv.get("pos"), float(sv.get("peur", -1))])
	menu.continue_btn.pressed.emit()
	await wait(3.0)
	await snap("reprise")
	print("reprise : phase %s · modem %s · objectif « %s » · étape %s · position %s · jauge %.1f" % [Game.phase, room.convoking, Game.objective_text, haunt.step_id, _v(player.global_position), Game.peur])
	ck("reprise : la convocation", Game.phase == "room" and room.convoking and Game.objective_text == Acte2.O4, "")
	await wait(1.0)
	print("JOUEUR032 FIN · %d vérifications, %d échec(s) (étape 2)" % [checks, fails])
	print("QUIT demandé")
	get_tree().quit(0)
