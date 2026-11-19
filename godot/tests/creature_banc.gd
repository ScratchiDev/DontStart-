extends Node
## Banc des sons de l'entité (lot V2-CREATURE), sans rendu (exclu de l'export). Le pilote audio factice mixe
## aussi en --headless : AudioEffectRecord y enregistre la sortie de Master (après le limiteur).
##   godot --headless --path godot res://tests/creature_banc.tscn [-- --out=<dossier>]
##       bus (Entite, Tonnerre -> Ambiance), silence (tonnerre coupé et retenu, silence tenu), sons écrits
##       derrière une porte (méta « recit »), la maison (vent, frigo, bruits épars), le souffle qui suit l'appareil
##       habité, la signature (délai), les imitations, le corps, le sursaut (enregistré : énergie 1-6 kHz, crête),
##       « Sursauts réduits », hasard du jeu intact. Dernière ligne : « BANC CRÉATURE OK » ou « … ÉCHEC <n> ».
##   … -- --ecoute --out=<dossier>   le montage d'écoute (ecoute_creature.wav, ecoute_creature.json : repères) :
##       signature, souffle qui passe d'un appareil à l'autre, imitations, silence soudain, à-coups, sursaut.

const A := preload("res://scripts/acoustique.gd")

var fails := 0
var checks := 0
var main: Node
var out_dir := ""
var _rec: AudioEffectRecord


func check(what: String, ok: bool, info := "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("VÉRIF %s : %s%s" % [what, "OK" if ok else "ÉCHEC", ("  (" + info + ")") if info != "" else ""])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	_buses()
	await _build_house()
	if args.has("--ecoute"):
		await _ecoute()
	else:
		await _checks()
	print("%d vérifications, %d échec(s)" % [checks, fails])
	print("BANC CRÉATURE %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	if main:
		main.queue_free()
		main = null
	for k in 3:
		await get_tree().process_frame
	get_tree().quit(1 if fails else 0)


func _bus_send(name: String) -> String:
	var i := AudioServer.get_bus_index(name)
	return String(AudioServer.get_bus_send(i)) if i >= 0 else "?"


func _buses() -> void:
	check("bus Entite (occulté) et ses classes", AudioServer.get_bus_index("Entite") > 0 and _bus_send("Entite") == "Master"
		and _bus_send("Entite~fermee") == "Entite" and A.occludable.has("Entite"))
	var t := AudioServer.get_bus_index("Tonnerre")
	check("Tonnerre envoie vers Ambiance (le silence le coupe)", _bus_send("Tonnerre") == "Ambiance"
		and t > AudioServer.get_bus_index("Ambiance"))
	check("Sfx.creature", Sfx.creature != null and Sfx.creature.is_inside_tree())
	check("classes : fermée -5 dB, loin -10 dB ; récit compensé (+5,5 / +7)",
		is_equal_approx(float(A.CLASSES.fermee[2]), -5.0) and is_equal_approx(float(A.CLASSES.loin[2]), -10.0)
		and is_equal_approx(float(A.CLASSES.fermee[2]) + float(A.RECIT_COMP.fermee), 0.5)
		and is_equal_approx(float(A.CLASSES.loin[2]) + float(A.RECIT_COMP.loin), -3.0))


func _build_house() -> void:
	var t0 := Time.get_ticks_msec()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for k in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	print("maison du banc prête en %d ms" % (Time.get_ticks_msec() - t0))


func _ac() -> Acoustique:
	return main.get_node_or_null("House/Acoustique") as Acoustique


func _haunt() -> Haunt:
	return main.get("haunt") as Haunt


func _go(p: Vector3, yaw := 0.0) -> void:
	var pl: Node3D = main.get("player")
	pl.global_position = p
	if pl.has_method("set_look"):
		pl.call("set_look", yaw, 0.0)
	await get_tree().create_timer(0.25).timeout


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _rec_start() -> void:
	_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _rec)
	await get_tree().process_frame
	_rec.set_recording_active(true)


func _rec_stop(file: String) -> AudioStreamWAV:
	_rec.set_recording_active(false)
	var w := _rec.get_recording()
	if w and out_dir != "" and file != "":
		w.save_to_wav(out_dir.path_join(file))
	for k in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, k) == _rec:
			AudioServer.remove_bus_effect(0, k)
			break
	return w


## Crête (dBFS) et part de l'énergie entre 1 et 6 kHz d'un enregistrement (16 bits stéréo), par une DFT
## grossière (blocs de 1024, 64 fréquences).
static func _analyse(w: AudioStreamWAV) -> Dictionary:
	var data := w.data
	var n := data.size() / 4
	var mono := PackedFloat32Array()
	mono.resize(n)
	var peak := 0.0
	for i in n:
		var l := data.decode_s16(i * 4) / 32768.0
		var r := data.decode_s16(i * 4 + 2) / 32768.0
		peak = maxf(peak, maxf(absf(l), absf(r)))
		mono[i] = (l + r) * 0.5
	var rate := float(w.mix_rate)
	var hi := 0.0
	var tot := 0.0
	var blk := 1024
	var start := 0
	while start + blk <= n:
		for k in range(1, 256, 2):
			var f := k * rate / blk
			var re := 0.0
			var im := 0.0
			for j in range(0, blk, 2):
				var v := mono[start + j]
				var ph := TAU * f * j / rate
				re += v * cos(ph)
				im += v * sin(ph)
			var e := re * re + im * im
			tot += e
			if f >= 1000.0 and f <= 6000.0:
				hi += e
		start += blk * 4
	return {"peak_db": linear_to_db(maxf(peak, 1e-6)), "part_1_6k": hi / maxf(tot, 1e-12)}


func _checks() -> void:
	var ac := _ac()
	var h := _haunt()
	check("nœuds de la maison : Vent, Frigo", ac != null and ac.vent != null and ac.frigo != null
		and ac.vent.bus == &"Ambiance" and String(ac.frigo.get_meta("bus_origine", "")) == "Ambiance")
	Game.phase = "room"
	await _go(Vector3(4.0, 0.0, 0.5), 0.0)
	# --- silence : le tonnerre est coupé, retenu, puis éclate après
	var ti := AudioServer.get_bus_index("Tonnerre")
	Sfx.silence(0.8)
	var th := Sfx.play("thunder", -3.0)
	check("silence : tonnerre retenu (pas encore joué) et Ambiance coupée", th != null and not th.playing and Sfx.is_silent()
		and not Sfx.can_flash())
	await _wait(1.3)
	check("après le silence : le tonnerre éclate", is_instance_valid(th) and th.playing and not Sfx.is_silent())
	if is_instance_valid(th):
		th.stop()
		th.queue_free()
	await _wait(0.6)
	check("can_flash après le silence", Sfx.can_flash())
	var th2 := Sfx.thunder(2.6)
	check("thunder(2,6 s) : plus bas et plus grave", th2 != null and th2.volume_db < -8.0 and th2.pitch_scale < 0.99 and th2.playing,
		"%.1f dB · %.3f" % [th2.volume_db, th2.pitch_scale])
	th2.stop()
	# --- silence tenu (son corps tout près)
	Sfx.silence_hold(true)
	await _wait(0.3)
	check("silence tenu", Sfx.is_silent() and is_inf(Sfx.silence_remaining()))
	Sfx.silence_hold(false)
	await _wait(0.9)
	check("silence tenu relâché : la maison revient", not Sfx.is_silent())
	# --- sons écrits derrière une porte : compensation
	var br: AudioStreamPlayer3D = Sfx.loop("breath_slow", -14.0, Vector3(2.6, 0.9, -3.6), self) as AudioStreamPlayer3D
	var thud := Sfx.play_at("cloth", Vector3(2.6, 0.9, -3.6), -14.0)
	await _wait(0.3)
	check("respiration derrière P2 : Ambiance~fermee, +5,5 dB (récit)", br.bus == &"Ambiance~fermee" and is_equal_approx(br.volume_db, -8.5),
		"%s %.1f" % [br.bus, br.volume_db])
	check("autre son derrière P2 : sans compensation", thud.bus == &"Master~fermee" and is_equal_approx(thud.volume_db, -14.0),
		"%s %.1f" % [thud.bus, thud.volume_db])
	br.queue_free()
	# --- le souffle suit l'appareil habité
	var cr := Sfx.creature
	h.inhabited_id = "nestor"
	await _wait(0.6)
	var b1 := cr._breath
	check("souffle dans Nestor (haut-parleur, bus Entite)", b1 != null and is_instance_valid(b1)
		and b1.global_position.distance_to(h.device("nestor").speak_pos()) < 0.01
		and String(b1.get_meta("bus_origine", "")) == "Entite" and String(b1.stream.resource_path).ends_with("souffle_hp.wav"))
	var nb := h.device("babyphone")
	var nn := h.device("nestor")
	h.move("nestor", "babyphone", 0.8)
	await _wait(0.3)
	check("pendant le déplacement : plus de souffle à Nestor", cr._breath == null or not is_instance_valid(cr._breath)
		or cr._breath.global_position.distance_to(nn.speak_pos()) > 0.01)
	await _wait(1.2)
	check("arrivée : souffle (radio) dans le babyphone, signature jouée", cr._breath != null and is_instance_valid(cr._breath)
		and cr._breath.global_position.distance_to(nb.speak_pos()) < 0.01 and String(cr._breath.stream.resource_path).ends_with("souffle_babyphone.wav")
		and cr.since_signature() < 1.5)
	check("signature : pas deux fois de suite (délai)", not cr.announce(nb))
	var j0 := h.journal.size()
	cr.on_say(nb, "Mamie", 3.0)
	cr.on_say(nb, "Mamie", 3.0)
	var toux := 0
	for i in range(j0, h.journal.size()):
		if h.journal[i].get("ev") == "son" and h.journal[i].get("text") == CreatureSfx.TOUX_CAPTION:
			toux += 1
	check("imitation : la toux une seule fois par appareil (sous-titre)", toux == 1, str(toux))
	# --- corps : à-coups ; tout près, la maison se tait
	await _go(Vector3(4.0, 0.0, 0.5), 0.0)
	cr.body_jump(Vector3(4.0, 0.3, -6.5))
	await _wait(0.2)
	check("à-coup loin : la maison continue", not Sfx.is_silent())
	cr.body_jump(Vector3(4.0, 0.3, -1.5))
	await _wait(0.2)
	check("à-coup tout près : silence tenu", Sfx.is_silent())
	cr.body_gone()
	await _wait(0.9)
	check("corps parti : la maison revient", not Sfx.is_silent())
	# --- la maison : un bruit épars dans une pièce voisine
	ac.maison_next = 0.05
	await _wait(0.4)
	check("bruit de la maison joué dans une pièce voisine", ac.maison_log.size() >= 1 and String(ac.maison_log[-1][1]) != ac.listener_room,
		str(ac.maison_log))
	# --- hasard du jeu : le sursaut (complet ou réduit) tire autant que l'ancien play("sting")
	for reduced in [false, true]:
		Game.reduced_scares = reduced
		seed(1234)
		var _a := randf_range(0.96, 1.04)
		var want := randf()
		seed(1234)
		Sfx.sting(-14.0 if reduced else 0.0)
		check("hasard du jeu intact après le sursaut (%s)" % ("réduit" if reduced else "complet"), is_equal_approx(randf(), want))
		await _wait(2.5)
	Game.reduced_scares = false
	# --- le sursaut enregistré : complet, puis réduit (la maison au calme : pluie, vent, frigo en pause)
	_pause_ambiance()
	# (les éclairs d'outside.gd tombent au hasard : le tonnerre se tait pendant les mesures)
	# (et la maison : ses bruits épars continuent de tomber)
	for b in ["Tonnerre", "Ambiance", "Entite"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(b), true)
	await _wait(3.0)
	for reduced in [false, true]:
		Game.reduced_scares = reduced
		await _rec_start()
		await _wait(0.1)
		Sfx.sting(-14.0 if reduced else 0.0)
		var found := _sting_players()
		await _wait(1.6)
		var w := _rec_stop("sursaut_%s.wav" % ("reduit" if reduced else "complet"))
		var an := _analyse(w)
		print("sursaut %s : crête %.1f dBFS, part 1-6 kHz %.0f %%" % ["réduit" if reduced else "complet", an.peak_db, 100.0 * float(an.part_1_6k)])
		if reduced:
			# (le cœur, sur Master, bat aussi : il fait partie de la réponse au sursaut, réduit ou non)
			check("sursaut réduit : ni choc grave ni souffle large bande ; la signature seule, à plat, ≤ -10 dB",
				int(found.sting) == 0 and int(found.sursaut) == 0 and int(found.signature) == 1 and float(found.sig_db) <= -9.9,
				str(found))
		else:
			check("sursaut : crête de sortie ≤ -1 dBFS", float(an.peak_db) <= -0.9, "%.1f" % an.peak_db)
			check("sursaut : au moins 30 % de l'énergie entre 1 et 6 kHz", float(an.part_1_6k) >= 0.3, "%.0f %%" % (100.0 * float(an.part_1_6k)))
		await _wait(4.5)
	Game.reduced_scares = false
	for b in ["Tonnerre", "Ambiance", "Entite"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(b), false)


var _paused: Array = []


## Lecteurs du sursaut qui viennent de partir : sting.ogg, « sursaut », signature (et son volume).
func _sting_players() -> Dictionary:
	var out := {"sting": 0, "sursaut": 0, "signature": 0, "sig_db": 0.0}
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is AudioStreamPlayer or n is AudioStreamPlayer3D) or not n.get("playing"):
			continue
		var st: AudioStream = n.get("stream")
		var path := st.resource_path if st else ""
		if path.ends_with("sting.ogg"):
			out.sting += 1
		elif path.ends_with("creature/sursaut.wav"):
			out.sursaut += 1
		elif path.contains("creature/signature_") and n is AudioStreamPlayer:
			out.signature += 1
			out.sig_db = float(n.get("volume_db"))
	return out


func _list_playing() -> void:
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.playing and not n.get("stream_paused"):
			print("JOUE ", n.get_path(), " ", n.get("bus"), " ", n.get("volume_db"), " ", (n.get("stream") as AudioStream).resource_path if n.get("stream") else "")


func _pause_ambiance() -> void:
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.playing and (String(n.get("bus")).begins_with("Ambiance")
				or String(n.get("bus")).begins_with("Entite")):
			n.set("stream_paused", true)
			_paused.append(n)


# ------------------------------------------------------------------ le montage d'écoute

func _ecoute() -> void:
	var h := _haunt()
	var cr := Sfx.creature
	var house: Node = main.get("house")
	var marks := []
	var t0 := [0]
	var mark := func(what: String) -> void:
		marks.append([snappedf((Time.get_ticks_msec() - int(t0[0])) / 1000.0, 0.01), what])
		print("REPÈRE %.1f s : %s" % [(Time.get_ticks_msec() - int(t0[0])) / 1000.0, what])
	Game.phase = "room"
	Game.peur = 35.0
	h.inhabited_id = ""
	(house.doors["P3"] as Door).set_open_now(true)
	var nestor := h.device("nestor")
	var bp := h.device("babyphone")
	await _go(Vector3(4.0, 0.0, 1.2), 0.0)
	await _wait(1.5)
	await _rec_start()
	t0[0] = Time.get_ticks_msec()
	mark.call("couloir, la nuit : pluie à la fenêtre du bout, sur le toit, vent, frigo en bas")
	await _wait(4.0)
	mark.call("SA SIGNATURE dans Nestor : un bip qui se déforme et devient souffle")
	cr.announce(nestor, true)
	await _wait(3.5)
	mark.call("elle habite Nestor : son souffle électrique (haut-parleur), qui gonfle quand elle « parle »")
	h.inhabited_id = "nestor"
	await _wait(2.0)
	cr.swell(2.5)
	for k in 5:
		Sfx.voice_at("chirp", nestor.speak_pos(), -12.0, 0.9 + 0.06 * k, 1.6)
		await _wait(0.4)
	await _wait(1.5)
	mark.call("interférence dans Nestor (on le débranche : elle reste)")
	cr.parasite(nestor.speak_pos())
	await _wait(2.5)
	mark.call("elle passe dans le babyphone : bourdonnement à travers le mur, le souffle la suit (radio)")
	h.move("nestor", "babyphone", 1.4)
	await _wait(0.6)
	await _go(Vector3(2.4, 0.0, 4.6), PI * 0.5)
	await _wait(5.0)
	mark.call("IMITATION : la toux de Mamie au babyphone (quatre fois la même, la dernière à l'envers)")
	cr.on_say(bp, "Mamie", 4.0)
	await _wait(4.5)
	mark.call("couloir, face à la caméra : SES PANTOUFLES au métronome, qui s'approchent derrière toi")
	await _go(Vector3(4.0, 0.0, -1.0), 0.0)
	h.inhabited_id = "ampoule_couloir_2"
	await _wait(1.0)
	cr.on_story("camera_led_eteinte", {})
	await _wait(7.0)
	mark.call("tu frappes à P2 : DES COUPS RÉPONDENT de l'autre côté, à l'envers")
	await _go(Vector3(4.0, 0.0, -3.2), PI * 0.5)
	for k in 3:
		Sfx.play_at("thud", (house.doors["P2"] as Node3D).global_position + Vector3(0, 1.0, 0), -3.0, 1.2 + 0.05 * k, 3.0)
		await _wait(0.42)
	cr._imitated.erase("coups")
	cr.on_knock(house.doors["P2"] as Node3D, "P2")
	await _wait(5.0)
	mark.call("trop réguliers : trois fois trois coups identiques, dans la salle de bain (porte fermée)")
	cr.imitate("coups_reguliers", Vector3(6.4, 1.25, -5.6))
	await _wait(5.5)
	mark.call("un éclair proche : le tonnerre roule…")
	Sfx.thunder(0.9)
	await _wait(1.8)
	mark.call("LE SILENCE : tout se coupe d'un coup (tonnerre, pluie, vent, frigo, maison) ; il ne reste que son souffle, ton cœur")
	Sfx.silence(3.0)
	await _wait(1.0)
	Sfx.thunder(2.4)   # (demandé pendant le silence : il attend sa fin)
	await _wait(2.6)
	mark.call("SON CORPS par à-coups, du fond du couloir jusqu'à toi (craquement numérique, choc sourd)")
	await _go(Vector3(4.0, 0.0, 1.0), 0.0)
	var steps := [Vector3(4.0, 0.4, -6.8), Vector3(3.9, 0.4, -4.6), Vector3(4.1, 0.4, -2.6), Vector3(4.0, 0.4, -0.9)]
	for k in steps.size():
		cr.body_jump(steps[k])
		await _wait(1.25 - 0.15 * k)
	await _wait(0.6)
	mark.call("LE VISAGE : le sursaut (grave + souffle électrique large bande + signature écrasée)")
	cr.body_gone()
	Sfx.sting(0.0)
	await _wait(4.0)
	mark.call("la maison revient ; le tonnerre lointain, retenu pendant le silence, a roulé après lui")
	await _wait(6.0)
	mark.call("fin")
	_rec_stop("ecoute_creature.wav")
	if out_dir != "":
		var f := FileAccess.open(out_dir.path_join("ecoute_creature.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"reperes": marks, "sous_titres": h.journal.filter(func(e: Dictionary) -> bool: return e.get("ev") == "son")}, "  "))
		f.close()
