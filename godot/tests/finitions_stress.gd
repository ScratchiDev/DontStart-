extends "res://scripts/main.gd"
## Banc « finitions » du stress léger (C4) sur les VRAIS événements écrits de l'acte II (exclu de
## l'export) : la scène du couloir (silence, Nestor N1 à N4), les coups à P2 et N5 à N7, le S.O.S., puis
## une impulsion dans la chambre de ta mère (refuge, baisse ×2). La courbe Sfx.heart_db est relevée
## toutes les 0,5 s (temps de jeu), avec le stress, les impulsions (Haunt.stress_pulses) et les
## dialogues affichés (le cœur se range dessous). Option « Sous-titres des sons » active : les coups
## et le S.O.S. doivent s'afficher entre crochets (C5).
##   XDG_DATA_HOME=… godot --headless --path godot res://tests/finitions_stress.tscn
## Dernière ligne : « STRESS OK » ou « STRESS ÉCHEC n ».

var at: Autotest
var fails := 0
var _rows: Array = []
var _rec := false
var _rec_t := 0.0
var _rec_next := 0.0
var _rec_tag := ""


func _ready() -> void:
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


func _process(delta: float) -> void:
	if not _rec:
		return
	_rec_t += delta
	if _rec_t >= _rec_next:
		_rec_next += 0.5
		var hd: Variant = hud.call("dialogue_on")
		var line := "%5.1f s  stress %.3f  cœur %6.1f dB%s" % [_rec_t, Game.stress, Sfx.heart_db, "  (dialogue)" if bool(hd) else ""]
		_rows.append(line)


func _record(tag: String) -> void:
	_rows.clear()
	_rec_t = 0.0
	_rec_next = 0.0
	_rec_tag = tag
	_rec = true


func _dump() -> void:
	_rec = false
	print("C4 courbe réelle « %s » :" % _rec_tag)
	for r in _rows:
		print("    ", r)


## Attend que le cœur se soit tu (sous −36 dB) et qu'aucune scène ne joue ; rend le temps attendu.
func _calm(max_s := 40.0) -> float:
	var t := 0.0
	# (deux images : Sfx recalcule le cœur après une impulsion donnée dans cette image)
	await get_tree().process_frame
	await get_tree().process_frame
	while (haunt.is_busy() or Sfx.heart_db >= Sfx.HEART_CALM_DB) and t < max_s:
		await get_tree().process_frame
		t += get_process_delta_time()
	await at.wait(1.0)
	return t


func _pulses_since(n: int) -> String:
	var out: Array = []
	for i in range(n, haunt.stress_pulses.size()):
		var e: Dictionary = haunt.stress_pulses[i]
		out.append("%s@%.1f s → crête %.1f dB%s" % [e.why, e.t, e.peak_db,
			(", calme %.1f s" % e.calm_s) if float(e.calm_s) >= 0.0 else (" (relayée)" if bool(e.relayed) else "")])
	return "\n      ".join(out)


func _run() -> void:
	Game.sound_captions = true
	var hn: Haunt = haunt
	var cl: Node = house.rooms["couloir"]
	await at._jump_acte2()
	await _calm()
	# 1. le couloir, première entrée : silence, Nestor s'éveille, N1 à N4
	var n0 := hn.stress_pulses.size()
	_record("couloir : silence, N1 à N4")
	at.look_from(Vector3(4.2, 0, 1.1), (cl.nestor as Nestor).speak_pos() + Vector3(0, 0.05, 0))
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N4), 60.0)
	await _calm()
	_dump()
	print("C4 impulsions : \n      ", _pulses_since(n0))
	var r1 := hn.c4_report(n0)
	print("C4 résumé couloir : ", r1)
	_check("C4 couloir : audible après l'événement, calme < 12 s", r1.ok and r1.measured >= 1, str(r1))
	# 2. P2 : on frappe (sous-titre des coups), N5 à N7, puis le S.O.S. (sous-titre, stress +0,3)
	var n1 := hn.stress_pulses.size()
	var caps0: int = hud.caption_log.size()
	_record("P2, N5 à N7, S.O.S., N8 N9")
	await at.use_at(Vector3(4.1, 0, -3.6), PI / 2.0, -0.1, "Frapper à la porte")
	await at.wait(0.3)
	var caps: Array = []
	for e in hud.caption_log.slice(caps0):
		caps.append(e.text)
	_check("C5 coups à P2 entre crochets (option active)", caps.has(Haunt.KNOCK_CAPTION), str(caps))
	at.look_from(Vector3(4.0, 0, -2.2), Vector3(4.6, 0.5, -2.9))
	await at.until(func() -> bool: return hn.has_logged("sos"), 60.0)
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N9), 60.0)
	await _calm()
	_dump()
	caps.clear()
	for e in hud.caption_log.slice(caps0):
		caps.append(e.text)
	print("C5 sous-titres de sons affichés : ", caps)
	_check("C5 S.O.S. entre crochets (option active)", caps.has(Acte2.SON_SOS), str(caps))
	print("C4 impulsions : \n      ", _pulses_since(n1))
	var r2 := hn.c4_report(n1)
	print("C4 résumé P2 et S.O.S. : ", r2)
	_check("C4 P2 et S.O.S. : audible après chaque événement, calme < 12 s", r2.ok and r2.measured >= 1, str(r2))
	# 3. la chambre de ta mère (refuge) : la même impulsion retombe deux fois plus vite
	player.global_position = Vector3(1.6, 0, 1.0)
	player.set_look(0.0, -0.05)
	await at.wait(1.0)
	var n2 := hn.stress_pulses.size()
	_record("refuge : une impulsion de 0,3")
	hn.stress(0.3, "test refuge")
	await _calm()
	_dump()
	var r3 := hn.c4_report(n2)
	print("C4 résumé refuge : ", r3, " · baisse ×", Game.stress_decay_mult)
	_check("C4 refuge (×2) : audible, calme < 12 s", r3.ok and r3.measured == 1 and is_equal_approx(Game.stress_decay_mult, 2.0), str(r3))
	var all := hn.c4_report(0)
	print("C4 résumé de tout le banc : ", all)
	_check("C4 tout le banc", all.ok, str(all.fails))
	# 4. C9 : le journal des temps de cette partie
	print("C9 journal des temps (%s) :" % Haunt.times_path())
	for l in FileAccess.get_file_as_string(Haunt.times_path()).strip_edges().split("\n"):
		print("    ", l)
	print("STRESS %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)
