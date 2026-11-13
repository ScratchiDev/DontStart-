extends "res://scripts/main.gd"
## Banc verif032_c2c3 (exclu de l'export) : le point de passage C2 du P4 réel peut-il être écrit APRÈS
## C3 (convocation) et l'écraser ? Vrai chemin du jeu, sans --autotest (user://sauvegarde.json), sans
## rendu :
##   XDG_DATA_HOME=<dossier vide> godot --headless --path godot res://tests/verif032_c2c3.tscn -- --cas=<cas>
## Cas :
##   fixe      : l'antenne est déjà dans l'inventaire ; le joueur prend le sèche-cheveux (P4 réel), fixe
##               le miroir pendant toute la barre (issue « fixe »), puis, pendant M9a / M10a, marche
##               jusqu'au seuil de P4 et y reste (zone Acte2._in_doorway()).
##   fui       : même départ ; vers 12,5 s de barre, il file vers P4 (issue « fui ») et reste sur le seuil.
##   fixe_hors : témoin : issue « fixe », le joueur reste devant le miroir (hors de l'embrasure).
## Le banc relève chaque écriture de la sauvegarde (ordre C1, C2, C3), puis, ~40 s de jeu après la fin
## du P4, imprime « DERNIER POINT : C2|C3 » et « VERDICT … ».

const SDB := preload("res://scripts/house/rooms/sdb.gd")
const THRESHOLD := Vector3(4.40, 0.0, -4.60)      # seuil de P4, côté couloir (dans _in_doorway, hors de la pièce)
const DOORWAY_IN := Vector3(4.65, 0.0, -4.60)     # embrasure de P4 (dans _in_doorway)

var at: Autotest
var cas := "fixe"
var vitesse := 3.0
var writes: Array = []
var _last_txt := ""
var _last_state := ""
var mirror: SmartMirror


func _ready() -> void:
	super()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cas="):
			cas = a.substr(6)
		elif a.begins_with("--vitesse="):
			vitesse = float(a.substr(10))
	at = Autotest.new()
	at.name = "AT"
	add_child(at)
	at.setup(self)
	get_tree().process_frame.connect(_watch)
	_run.call_deferred()


func _t() -> float:
	return at.game_t if at else 0.0


## Chaque image : relève toute nouvelle écriture du fichier de sauvegarde, et les changements d'état
## de la course P4 / convocation.
func _watch() -> void:
	var p := Game.save_path()
	if FileAccess.file_exists(p):
		var txt := FileAccess.get_file_as_string(p)
		if txt != _last_txt:
			_last_txt = txt
			var d: Variant = JSON.parse_string(txt)
			if d is Dictionary:
				var fl: Dictionary = (d as Dictionary).get("flags", {})
				var row := {"t": _t(), "cp": str(d.get("checkpoint", "?")), "conv": bool(fl.get("convocation", false)),
					"pp": str(fl.get("point_passage", "")), "peur": float(d.get("peur", -1.0)), "pos": d.get("pos", [])}
				writes.append(row)
				print("VERIF032 ÉCRITURE #%d t=%.2f s : checkpoint=%s · point_passage=%s · convocation=%s · peur=%.1f · pos=%s"
					% [writes.size(), row.t, row.cp, row.pp, row.conv, row.peur, row.pos])
	if acte2 == null or mirror == null:
		return
	var st := "p4_busy=%s conv_busy=%s flag_conv=%s p4_issue=%s mirror_running=%s haunt_busy=%s embrasure=%s phase=%s" % [
		acte2._p4_busy, acte2._conv_busy, bool(Game.flag("convocation", false)), acte2.p4_issue,
		mirror.p4_running, haunt.is_busy(), acte2._in_doorway(), Game.phase]
	if st != _last_state:
		_last_state = st
		print("VERIF032 ÉTAT t=%.2f s : %s · joueur %s" % [_t(), st, player.global_position.snapped(Vector3(0.01, 0.01, 0.01))])


func _run() -> void:
	print("VERIF032 cas=%s · version %s · sauvegarde %s · %s" % [cas, ProjectSettings.get_setting("application/config/version"),
		ProjectSettings.globalize_path(Game.save_path()), DisplayServer.get_name()])
	var sb: Node = house.rooms["sdb"]
	mirror = sb.mirror
	# --- jusqu'à l'acte II, comme l'autotest : la clé, le mot d'Albert, C1
	await at._jump_acte2()
	# --- le couloir (N1 à N4), joué
	Engine.time_scale = vitesse
	await at._through_couloir()
	Engine.time_scale = 1.0
	# --- précondition : l'antenne (et le tournevis qui la dévisse) déjà dans l'inventaire, P4 ouverte
	for row in Autotest.ITEMS_03:
		if row[0] in ["cle_bureau", "tournevis", "antenne"]:
			Game.add_item(row[0], row[1], row[2], row[3])
	Game.set_flag("antenne_prise", true)
	Game.set_flag("antenne_examinee", true)
	var p4d: Door = house.doors["P4"]
	p4d.unlock()
	p4d.set_open_now(true)
	# (jauge haute mais sous 100 : le P4 ajoute +10 ou +12 ; C3 la plafonne à 83, C2 non)
	Game.set_peur(75.0, "banc verif032")
	print("VERIF032 précondition : antenne %s · sèche-cheveux %s · P4 réel fait %s · peur %.1f" % [
		Game.has_item("antenne"), Game.has_item("seche_cheveux"), acte2._p4_done(), Game.peur])
	var events := {}
	mirror.p4_event.connect(func(s: String) -> void:
		events[s] = _t()
		if s in ["barre", "issue", "fin"]:
			print("VERIF032 miroir « %s » t=%.2f s" % [s, _t()]))
	# --- le vrai P4 : prendre le sèche-cheveux (rayon + E)
	await at.use_on(sb.dryer_it, Vector3(7.65, 0, -5.0), "Prendre le sèche-cheveux")
	var started: bool = await at.until(func() -> bool: return mirror.is_on and mirror.p4_running, 3.0)
	print("VERIF032 P4 réel démarré : %s · sèche-cheveux %s" % [started, Game.has_item("seche_cheveux")])
	Engine.time_scale = vitesse
	var watch_at := Vector3(6.2, 0, -4.7) if cas == "fui" else SDB.PLAYER_AT_MIRROR
	at.look_from(watch_at, mirror.global_position)
	await at.until(func() -> bool: return events.has("barre"), 120.0)
	match cas:
		"fui":
			await at.until(func() -> bool: return mirror.p4_time >= 12.5 or mirror.p4_issue != "", 30.0)
			print("VERIF032 fuite à %.2f s de barre" % mirror.p4_time)
			var exit_to := Vector3(3.9, 0, -4.6)
			player.set_look(at.aim(player.global_position, exit_to + Vector3(0, player.EYE, 0)).x, 0.0)
			Input.action_press("move_forward")
			await at.until(func() -> bool: return player.global_position.x < 4.55 or mirror.p4_issue != "", 6.0)
			Input.action_release("move_forward")
			await at.until(func() -> bool: return mirror.p4_issue != "", 5.0)
			await at.wait(0.3)
			print("VERIF032 issue « %s » · joueur %s · embrasure %s" % [mirror.p4_issue, player.global_position, acte2._in_doorway()])
			if not acte2._in_doorway():
				player.global_position = THRESHOLD
				print("VERIF032 joueur replacé sur le seuil %s (embrasure %s)" % [THRESHOLD, acte2._in_doorway()])
		"fixe":
			await at.until(func() -> bool: return events.has("issue"), 60.0)
			# (M9a et M10a ne demandent plus le regard : il recule vers la porte et s'arrête sur le seuil)
			player.set_look(at.aim(player.global_position, DOORWAY_IN + Vector3(0, player.EYE, 0)).x, 0.0)
			Input.action_press("move_forward")
			await at.until(func() -> bool: return player.global_position.x < 4.85, 6.0)
			Input.action_release("move_forward")
			await at.wait(0.3)
			print("VERIF032 issue « %s » · joueur %s · embrasure %s · miroir encore actif %s" % [
				mirror.p4_issue, player.global_position, acte2._in_doorway(), mirror.p4_running])
			if not acte2._in_doorway():
				player.global_position = DOORWAY_IN
				print("VERIF032 joueur replacé dans l'embrasure %s (embrasure %s)" % [DOORWAY_IN, acte2._in_doorway()])
		_:
			await at.until(func() -> bool: return events.has("issue"), 60.0)
	await at.until(func() -> bool: return acte2.p4_issue != "", 60.0)
	var t_end := _t()
	print("VERIF032 Acte2._p4 : sdb.run_p4() rendu « %s » t=%.2f s · embrasure %s" % [acte2.p4_issue, t_end, acte2._in_doorway()])
	# --- ~40 s de jeu, le joueur ne bouge plus
	await at.until(func() -> bool: return _t() - t_end >= 40.0, 120.0)
	Engine.time_scale = 1.0
	await at.wait(0.2)
	_report()


func _report() -> void:
	var d := Game.load_checkpoint()
	var fl: Dictionary = d.get("flags", {})
	var seq := []
	for w in writes:
		seq.append(w.cp)
	print("VERIF032 SÉQUENCE DES ÉCRITURES : %s" % " → ".join(seq))
	print("VERIF032 SAUVEGARDE FINALE : checkpoint=%s · point_passage=%s · convocation=%s · p4_reel_fait=%s · miroir_reel=%s · peur=%.1f · pos=%s · yaw=%.2f"
		% [d.get("checkpoint", "rien"), fl.get("point_passage", ""), fl.get("convocation", false), fl.get("p4_reel_fait", false),
		(d.get("choices", {}) as Dictionary).get("miroir_reel", ""), float(d.get("peur", -1.0)), d.get("pos", Vector3.ZERO), float(d.get("yaw", 0.0))])
	var i2 := seq.rfind("C2")
	var i3 := seq.rfind("C3")
	print("VERIF032 état du jeu : convocation=%s · N11 dit %s · issue %s · Game.peur %.1f" % [
		bool(Game.flag("convocation", false)), at.has_said("nestor", Acte2.N11), acte2.p4_issue, Game.peur])
	print("VERIF032 DERNIER POINT : %s" % d.get("checkpoint", "rien"))
	var code := 0
	if not bool(Game.flag("convocation", false)) or i3 < 0:
		print("VERIF032 VERDICT : INVALIDE (la convocation n'a pas eu lieu, C3 jamais écrit)")
		code = 2
	elif d.get("checkpoint") == "C2" and i2 > i3:
		print("VERIF032 VERDICT : BOGUE REPRODUIT (C2 écrit après C3, la sauvegarde de la convocation est écrasée)")
		code = 1
	elif d.get("checkpoint") == "C3":
		print("VERIF032 VERDICT : CORRECT (C3 est le dernier point écrit%s)" % (", C2 avant lui" if i2 >= 0 and i2 < i3 else ", C2 jamais écrit"))
	else:
		print("VERIF032 VERDICT : INATTENDU")
		code = 3
	print("VERIF032 FIN cas=%s code=%d" % [cas, code])
	if Game.has_method("quit_game"):
		Game.call("quit_game", code)
	else:
		get_tree().quit(code)
