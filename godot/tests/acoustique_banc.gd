extends Node
## Banc de l'acoustique de l'étage (lot V2-SON), sans rendu (exclu de l'export). Le pilote audio factice de
## Godot mixe aussi en --headless : AudioEffectRecord y enregistre ce que l'on entendrait.
##   godot --headless --path godot res://tests/acoustique_banc.tscn
##       logique (les 10 cas du prototype de l'étude « présence », et d'autres), bus et effets, puis la maison
##       (main.tscn) : zones, pluie, pas, classes d'écoute selon les portes, silence, canard, respiration,
##       hasard global intact. Dernière ligne : « BANC ACOUSTIQUE OK » ou « BANC ACOUSTIQUE ÉCHEC <n> ».
##   … -- --calibrage --out=<dossier>   les sons écrits à travers les portes (ouverture de l'acte I, ronflement,
##       respiration derrière P2, clé, coups, radiateur, modem), acoustique coupée puis active : un WAV par cas
##       et calibrage.json (à lire avec l'analyse du lot : niveau perçu à ±3 dB).
##   … -- --ecoute --out=<dossier>      60 s dans le couloir et alentour (ecoute_couloir.wav, ecoute.json : les
##       repères), puis des coups secs sans ambiance pour les mesures (mesures_*.wav).

const A := preload("res://scripts/acoustique.gd")
const START := Vector3(2.15, 0.0, 1.85)
const BREATH_POS := Vector3(2.6, 0.9, -3.6)
const PIPE_POS := Vector3(4.62, 0.12, -2.9)

var fails := 0
var checks := 0
var main: Node
var out_dir := ""


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
	if args.has("--calibrage"):
		await _build_house()
		await _calibrage()
		await _free_house()
		get_tree().quit()
		return
	if args.has("--canard"):
		await _build_house()
		await _canard_reglages()
		await _free_house()
		get_tree().quit()
		return
	if args.has("--ecoute"):
		await _build_house()
		await _ecoute()
		await _free_house()
		get_tree().quit()
		return
	_logic()
	_buses()
	await _build_house()
	await _house_checks()
	print("%d vérifications, %d échec(s)" % [checks, fails])
	print("BANC ACOUSTIQUE %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	await _free_house()
	get_tree().quit(1 if fails else 0)


func _free_house() -> void:
	if main:
		main.queue_free()
		main = null
	for k in 3:
		await get_tree().process_frame


# ------------------------------------------------------------------ logique pure

func _logic() -> void:
	var shut := {}
	var p4 := {"P4": 20.0}
	var p1 := {"P1": 92.8}
	# les 10 cas du prototype (aaa_etude/presence/proto/test_acoustique.gd)
	check("pas du couloir, P1 fermée", A.classify(Vector3(2.15, 1.58, 1.85), Vector3(4.0, 0.05, -1.0), shut) == "fermee")
	check("ronflement de Papi (gp), mur mitoyen", A.classify(Vector3(2.15, 1.58, 1.85), Vector3(-0.6, 0.7, -2.9), shut) == "fermee")
	check("clé dans la serrure de P1 (plan de la porte)", A.classify(Vector3(2.15, 1.58, 1.85), Vector3(3.25, 1.0, 1.4), shut) == "meme")
	check("coups à P2 depuis le couloir", A.classify(Vector3(3.9, 1.58, -3.6), Vector3(3.25, 1.25, -3.6), shut) == "meme")
	check("respiration derrière P2 (gp), depuis le couloir", A.classify(Vector3(3.9, 1.58, -3.6), Vector3(2.0, 0.8, -4.5), shut) == "fermee")
	check("salle de bain depuis le couloir, P4 à 20°", A.classify(Vector3(4.0, 1.58, -4.6), Vector3(6.6, 0.5, -6.9), p4) == "entrouverte")
	check("chambre de la mère depuis le couloir, P1 ouverte", A.classify(Vector3(4.0, 1.58, 1.4), Vector3(1.2, 1.0, -1.0), p1) == "ouverte")
	check("bureau depuis la chambre de la mère", A.classify(Vector3(0.0, 1.58, 0.0), Vector3(7.0, 1.0, 4.0), shut) == "loin")
	check("même pièce", A.classify(Vector3(7.0, 1.58, -5.0), Vector3(6.6, 0.5, -6.9), shut) == "meme")
	check("sdb ↔ lingerie (mur mitoyen)", A.classify(Vector3(7.0, 1.58, -5.0), Vector3(7.0, 1.0, -2.0), shut) == "fermee")
	# au-delà du prototype
	check("modem entendu de la salle de bain (P4 à 20°, P1 ouverte) : entrouverte (reconnaissable)",
		A.classify(Vector3(7.0, 1.58, -5.5), Vector3(-1.0, 1.0, 0.5), {"P4": 20.0, "P1": 92.8}) == "entrouverte")
	check("deux portes ouvertes et le couloir entre elles : entrouverte",
		A.classify(Vector3(0.0, 1.58, 4.5), Vector3(0.0, 1.0, 0.0), {"P3": 92.8, "P1": 92.8}) == "entrouverte")
	check("bureau depuis le couloir, P7 ouverte", A.classify(Vector3(4.0, 1.58, 4.4), Vector3(7.0, 1.0, 4.0), {"P7": 92.8}) == "ouverte")
	check("cage d'escalier derrière P6 vitrée fermée : entrouverte",
		A.classify(Vector3(4.0, 1.58, 1.0), Vector3(7.0, 1.0, 1.0), shut) == "entrouverte")
	check("auditeur hors de la maison : rien n'est filtré", A.classify(Vector3(-8.0, 1.0, 0.0), Vector3(7.0, 1.0, 4.0), shut) == "meme")
	check("pluie de F1 (dehors, devant la vitre) : chambre de la mère", A.source_room(Vector3(-3.4, 1.575, -0.45)) == "mere")
	check("sous le plancher : seule la cage continue", A.room_at(Vector3(6.0, -1.5, 0.5)) == "escalier" and A.room_at(Vector3(0.0, -1.5, 0.0)) == "")
	check("hystérésis des portes", A.door_state(0.55) == 2 and A.door_state(0.45, 2) == 2 and A.door_state(0.45, 1) == 1
		and A.door_state(0.08, 1) == 1 and A.door_state(0.08, 0) == 0 and A.door_state(0.3, 2) == 1)
	var c := A.costs_from("mere", {})
	check("coûts : mère → bureau, tout fermé = 19 (P1, couloir, P7)", is_equal_approx(float(c["bureau"]), 19.0), str(c["bureau"]))
	check("fenêtres pour le tonnerre", A.window_exposure("mere") == "claire" and A.window_exposure("gp") == "store"
		and A.window_exposure("sdb") == "depoli" and A.window_exposure("escalier") == "aucune" and A.window_exposure("couloir") == "claire")
	check("bus de classe", A.bus_for("Master", "fermee") == "Master~fermee" and A.bus_for("Voix", "fermee") == "Voix"
		and A.bus_for("Ambiance", "meme") == "Ambiance")
	check("masque des zones = couche acoustique", A.AREA_MASK == 1 << 19 and Builder.LAYER_ACOUSTIC == 20)
	var n_edges := A.edges().size()
	check("graphe : 7 portes et des cloisons mitoyennes", n_edges >= 14, "%d arêtes" % n_edges)


# ------------------------------------------------------------------ bus et effets (Sfx._ready)

func _bus_ok(name: String, send: String) -> bool:
	var i := AudioServer.get_bus_index(name)
	var j := AudioServer.get_bus_index(send)
	return i > 0 and j >= 0 and i > j and AudioServer.get_bus_send(i) == StringName(send)


func _buses() -> void:
	for rev in A.REVERBS:
		var i := AudioServer.get_bus_index(rev)
		var rv: AudioEffectReverb = null
		if i >= 0 and AudioServer.get_bus_effect_count(i) > 0:
			rv = AudioServer.get_bus_effect(i, 0) as AudioEffectReverb
		check("bus %s (réverbération 100 %% réverbérée vers Master)" % rev, _bus_ok(rev, "Master") and rv != null
			and is_zero_approx(rv.dry) and is_equal_approx(rv.wet, 1.0) and is_equal_approx(rv.room_size, float(A.REVERBS[rev].room_size)))
	var s := AudioServer.get_bus_index("Rev_sourd")
	check("bus Rev_sourd (passe-bas puis réverbération)", _bus_ok("Rev_sourd", "Master")
		and AudioServer.get_bus_effect(s, 0) is AudioEffectLowPassFilter and AudioServer.get_bus_effect(s, 1) is AudioEffectReverb)
	for origin in ["Master", "Ambiance"]:
		for cl in ["ouverte", "entrouverte", "fermee", "loin"]:
			var nm := "%s~%s" % [origin, cl]
			var i := AudioServer.get_bus_index(nm)
			var lp: AudioEffectLowPassFilter = null
			if i >= 0 and AudioServer.get_bus_effect_count(i) > 0:
				lp = AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
			check("bus %s → %s" % [nm, origin], _bus_ok(nm, origin) and lp != null
				and is_equal_approx(lp.cutoff_hz, float(A.CLASSES[cl][0]))
				and is_equal_approx(AudioServer.get_bus_volume_db(i), float(A.CLASSES[cl][2])))
	check("bus Tonnerre et Joueur", _bus_ok("Tonnerre", "Master") and _bus_ok("Joueur", "Master")
		and AudioServer.get_bus_effect(AudioServer.get_bus_index("Joueur"), 0) is AudioEffectReverb)
	var last := AudioServer.get_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1) as AudioEffectHardLimiter
	check("limiteur en fin de Master (plafond -1 dB)", last != null and is_equal_approx(last.ceiling_db, -1.0))
	var amb := AudioServer.get_bus_index("Ambiance")
	var comp: AudioEffectCompressor = null
	if AudioServer.get_bus_effect_count(amb) > 0:
		comp = AudioServer.get_bus_effect(amb, 0) as AudioEffectCompressor
	check("compresseur de l'Ambiance, chaîne latérale « Voix »", comp != null and comp.sidechain == &"Voix")
	check("cœur inchangé (C4)", is_equal_approx(Sfx.heart_volume(0.12), -20.0) and Sfx.HEART_CALM_DB == -36.0)


# ------------------------------------------------------------------ la maison

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


## Place l'auditeur (le joueur, donc sa caméra) et laisse passer deux mises à jour de l'acoustique.
func _go(p: Vector3, yaw := 0.0) -> void:
	var pl: Node3D = main.get("player")
	pl.global_position = p
	if pl.has_method("set_look"):
		pl.call("set_look", yaw, 0.0)
	await get_tree().create_timer(0.25).timeout


func _house_checks() -> void:
	var ac := _ac()
	check("nœud House/Acoustique", ac != null)
	if ac == null:
		return
	var zones_ok := ac.zones.size() >= 5
	for key in ac.zones:
		zones_ok = zones_ok and (ac.zones[key] as Dictionary).size() == 8
		for id in ac.zones[key]:
			var z: Area3D = ac.zones[key][id]
			zones_ok = zones_ok and z.collision_layer == 1 << (int(A.routes[key]) - 1) and z.collision_mask == 0 \
				and not z.monitoring and not z.monitorable and z.audio_bus_override and z.get_parent() == ac
	check("zones : 8 par route (Master 20, Ambiance 21, Voix 22…), masque 0, redirection du bus", zones_ok,
		"%d routes, %s" % [ac.zones.size(), str(A.routes)])
	var rain_ok := ac.rain.size() == 7
	for id in ac.rain:
		var p: AudioStreamPlayer3D = ac.rain[id]
		rain_ok = rain_ok and p.playing and String(p.bus).begins_with("Ambiance") and p.area_mask == A.mask_for("Ambiance")
	check("pluie : une boucle par fenêtre (7), sur l'Ambiance", rain_ok, str(ac.rain.keys()))
	check("pluie sur le toit (plate, Ambiance)", ac.roof != null and ac.roof.playing and ac.roof.bus == &"Ambiance")
	var steps := main.get("player").get_node_or_null("Steps") as AudioStreamPlayer
	check("pas du joueur sur le bus Joueur", steps != null and steps.bus == &"Joueur")
	# depuis la chambre de la mère (porte fermée à clé)
	await _go(START)
	check("auditeur dans la chambre de la mère", ac.listener_room == "mere", ac.listener_room)
	var thud := Sfx.play_at("thud", Vector3(4.0, 1.0, -1.0), -40.0)
	check("coup dans le couloir, P1 fermée : Master~fermee", thud.bus == &"Master~fermee", String(thud.bus))
	var near := Sfx.play_at("thud", Vector3(0.5, 1.0, 0.5), -40.0)
	check("coup dans la pièce : Master", near.bus == &"Master" and near.area_mask == A.AREA_MASK and near.get_node_or_null("EnvoiReverb") == null)
	var key := Sfx.play_at("metalLatch", Vector3(3.2, 1.1, 1.4), -40.0)
	check("clé dans la serrure de P1 : Master", key.bus == &"Master")
	var v := Sfx.voice_at("chirp", Vector3(4.0, 1.0, -1.0), -40.0)
	check("voix derrière la porte : jamais filtrée", v.bus == &"Voix" and v.area_mask == A.mask_for("Voix", false)
		and ac.zones["Voix!"]["couloir"].audio_bus_name == &"Voix")
	var hm := Sfx.hum_move(Vector3(-1, 1, -4), Vector3(7, 1, 4), 0.5, -40.0)
	check("bourdonnement : Voix, sans occlusion, réverbération des pièces", hm.bus == &"Voix" and hm.has_meta("sans_occlusion") and hm.area_mask == A.mask_for("Voix", false))
	check("pluie de F1 (même pièce) / de F8 (couloir, P1 fermée)", ac.rain["F1"].bus == &"Ambiance" and ac.rain["F8"].bus == &"Ambiance~fermee",
		"%s / %s" % [ac.rain["F1"].bus, ac.rain["F8"].bus])
	var zm: Dictionary = ac.zones["Master"]
	check("zones depuis la chambre : la sienne, le couloir étouffé, le bureau sans réverbération",
		zm["mere"].reverb_bus_name == &"Rev_chambre" and zm["mere"].audio_bus_name == &"Master"
		and zm["couloir"].reverb_bus_name == &"Rev_sourd" and zm["couloir"].audio_bus_name == &"Master~fermee"
		and not zm["bureau"].reverb_bus_enabled and zm["bureau"].audio_bus_name == &"Master~loin"
		and ac.zones["Ambiance"]["couloir"].audio_bus_name == &"Ambiance~fermee")
	var kt := Sfx.play_at("metalLatch", Vector3(3.25, 1.0, 1.4), -40.0)
	var twin := kt.get_node_or_null("EnvoiReverb") as AudioStreamPlayer3D
	check("son au plan de P1 : un jumeau vers la réverbération de la chambre", twin != null and twin.bus == &"Rev_chambre"
		and twin.area_mask == 0 and absf(twin.volume_db - (-40.0 + linear_to_db(float(A.PIECES["mere"][1])))) < 0.01)
	var jr := AudioServer.get_bus_effect(AudioServer.get_bus_index("Joueur"), 0) as AudioEffectReverb
	check("pas du joueur : réverbération de la chambre", is_equal_approx(jr.room_size, float(A.REVERBS["Rev_chambre"].room_size)))
	# dans le couloir
	await _go(Vector3(3.9, 0.0, -3.6), PI / 2.0)
	var br := Sfx.loop("breath_slow", -40.0, BREATH_POS, self) as AudioStreamPlayer3D
	var knock := Sfx.play_at("thud", Vector3(3.25, 1.25, -3.6), -40.0)
	var sdb := Sfx.play_at("thud", Vector3(6.6, 0.5, -6.9), -40.0)
	check("auditeur dans le couloir", ac.listener_room == "couloir", ac.listener_room)
	check("respiration derrière P2 : Ambiance~fermee", br.bus == &"Ambiance~fermee", String(br.bus))
	check("coups à P2 (plan de la porte) : Master", knock.bus == &"Master")
	check("salle de bain, P4 à 20° : Master~entrouverte", sdb.bus == &"Master~entrouverte", String(sdb.bus))
	check("pluie de F8 (couloir) : Ambiance", ac.rain["F8"].bus == &"Ambiance")
	check("tonnerre, couloir (fenêtre claire) : sans filtre", not AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("Tonnerre"), 0))
	check("pas du joueur : réverbération du couloir", is_equal_approx(jr.room_size, float(A.REVERBS["Rev_couloir"].room_size)))
	# une porte s'ouvre : les sons en cours changent de bus (après 50 ms)
	var loopm := Sfx.loop("crt_hum", -40.0, Vector3(1.0, 1.0, -1.0), self) as AudioStreamPlayer3D
	var was := String(loopm.bus)
	(main.get("house").doors["P1"] as Door).set_open_now(true)
	await get_tree().create_timer(0.3).timeout
	check("P1 ouverte : la chambre passe de fermée à ouverte", was == "Ambiance~fermee" and loopm.bus == &"Ambiance~ouverte"
		and ac.zones["Master"]["mere"].reverb_bus_name == &"Rev_chambre" and ac.zones["Ambiance"]["mere"].audio_bus_name == &"Ambiance~ouverte",
		"%s → %s" % [was, loopm.bus])
	(main.get("house").doors["P1"] as Door).set_open_now(false)
	await get_tree().create_timer(0.3).timeout
	check("P1 refermée : fermée", loopm.bus == &"Ambiance~fermee", String(loopm.bus))
	br.queue_free()
	loopm.queue_free()
	# cage d'escalier : le tonnerre étouffé
	await _go(Vector3(6.5, 0.0, 0.8))
	var ti := AudioServer.get_bus_index("Tonnerre")
	check("tonnerre dans la cage (sans fenêtre) : passe-bas", ac.listener_room == "escalier" and AudioServer.is_bus_effect_enabled(ti, 0)
		and is_equal_approx((AudioServer.get_bus_effect(ti, 0) as AudioEffectFilter).cutoff_hz, float(A.TONNERRE["aucune"][0])))
	await _go(START)
	# le silence de l'entité coupe l'Ambiance ET les réverbérations ; le canard ne compte pas comme silence
	var amb := AudioServer.get_bus_index("Ambiance")
	var rev := AudioServer.get_bus_index("Rev_couloir")
	Sfx.silence(0.4)
	check("silence : Ambiance et réverbérations coupées, is_silent", Sfx.is_silent() and AudioServer.get_bus_volume_db(rev) <= -79.0)
	await get_tree().create_timer(1.3).timeout
	check("après le silence : tout revient", not Sfx.is_silent() and absf(AudioServer.get_bus_volume_db(amb)) < 0.5
		and absf(AudioServer.get_bus_volume_db(rev)) < 0.5)
	Sfx.duck_ambiance(-10.0, 0.3, 0.05, 0.1)
	await get_tree().create_timer(0.15).timeout
	check("canard : Ambiance à -10 dB, pas un silence", absf(AudioServer.get_bus_volume_db(amb) + 10.0) < 0.6 and not Sfx.is_silent()
		and absf(AudioServer.get_bus_volume_db(rev)) < 0.5)
	await get_tree().create_timer(0.6).timeout
	check("canard : l'Ambiance revient", absf(AudioServer.get_bus_volume_db(amb)) < 0.5)
	# le tonnerre passe par son bus
	var th := Sfx.play("thunder", -60.0)
	check("tonnerre sur le bus Tonnerre", th.bus == &"Tonnerre")
	# play_3d : options, inscription, hasard global intact
	seed(777)
	var witness := randf()
	seed(777)
	var p3 := Sfx.play_3d("thud", Vector3(4.0, 1.0, -1.0), {"db": -40.0, "jitter": 0.05, "unit_size": 1.5, "max_distance": 9.0})
	var po := Sfx.play_3d("thud", Vector3(4.0, 1.0, -1.0), {"db": -40.0, "occlusion": false})
	ac.refresh()
	Sfx.call("_update_breath", 0.1)
	check("play_3d : occlusion et options", p3.bus == &"Master~fermee" and is_equal_approx(p3.max_distance, 9.0) and po.bus == &"Master")
	check("Acoustique, play_3d et respiration ne tirent rien du hasard global", is_equal_approx(randf(), witness))
	check("classe d'un point, pièce de l'auditeur", Sfx.hearing_class(Vector3(4.0, 1.0, -1.0)) == "fermee" and Sfx.listener_room() == "mere")
	await _breath_checks()


func _breath_checks() -> void:
	var was_phase := Game.phase
	Game.phase = "room"
	Game.stress = 0.0
	await get_tree().create_timer(4.6).timeout
	var calm_ok: bool = Sfx.breath_db < -35.0 and Sfx.breath_rate < 16.0 and Sfx.get("_br_set") == "calme"
	check("respiration calme : -38 dB, 14 par minute", calm_ok, "%.1f dB, %.1f/min, %s" % [Sfx.breath_db, Sfx.breath_rate, Sfx.get("_br_set")])
	var heard := false
	var panic_seen := false
	var max_rate := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		Game.stress = 1.0
		await get_tree().create_timer(0.1).timeout
		var a: AudioStreamPlayer = Sfx.get("_br_in")
		var b: AudioStreamPlayer = Sfx.get("_br_out")
		heard = heard or (a != null and a.playing) or (b != null and b.playing)
		panic_seen = panic_seen or Sfx.get("_br_set") == "panique"
		max_rate = maxf(max_rate, Sfx.breath_rate)
	check("respiration en panique : ensemble « panique », 34 par minute, -17 dB", heard and panic_seen and max_rate > 33.0
		and Sfx.breath_db > -18.5, "%.1f dB, %.1f/min" % [Sfx.breath_db, max_rate])
	check("le cœur suit toujours le stress seul (C4)", is_equal_approx(Sfx.heart_curve_db, Sfx.heart_volume(Game.stress)))
	Game.stress = 0.0
	Game.phase = was_phase
	await get_tree().create_timer(0.2).timeout
	check("à l'écran-titre, plus de respiration", Game.phase != "title" or Sfx.breath_db <= -80.0)


# ------------------------------------------------------------------ enregistrements

var _rec: AudioEffectRecord


func _rec_start() -> void:
	_rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _rec)
	await get_tree().process_frame
	_rec.set_recording_active(true)


func _rec_stop(file: String) -> void:
	_rec.set_recording_active(false)
	var w := _rec.get_recording()
	if w and out_dir != "":
		w.save_to_wav(out_dir.path_join(file))
	for k in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, k) == _rec:
			AudioServer.remove_bus_effect(0, k)
			break


## Met en pause (ou relance) les ambiances déjà là (pluie, toit, ton de la pièce, ronflement de l'écran) pour
## des mesures au calme ; les boucles créées ensuite par le banc ne sont pas touchées.
var _paused: Array = []


func _ambiance(on: bool) -> void:
	if on:
		for p in _paused:
			if is_instance_valid(p):
				p.stream_paused = false
		_paused.clear()
		return
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.playing and String(n.get("bus")).begins_with("Ambiance"):
			n.set("stream_paused", true)
			_paused.append(n)


## Les sons écrits, acoustique coupée (le son d'avant) puis active : un WAV par cas et par état.
func _calibrage() -> void:
	_ambiance(false)
	var room: Node = main.get("room")
	var house: Node = main.get("house")
	var cases := []
	for on in [false, true]:
		Sfx.acoustique_on = on
		var tag := "apres" if on else "avant"
		# 1) ouverture de l'acte I : les pas dans le couloir, P1 fermée (acte1.gd)
		await _go(START)
		await _rec_start()
		for i in 6:
			Sfx.play_at("footstep_wood_00%d" % (i % 5), Vector3(4.0, 0.05, -3.2 + i * 0.75), -4.0, 0.9)
			await get_tree().create_timer(0.62).timeout
		await get_tree().create_timer(0.8).timeout
		_rec_stop("cal_pas_%s.wav" % tag)
		# 2) la clé dans la serrure (plan de P1)
		await _rec_start()
		Sfx.play_at("metalLatch", room.call("door_center"), -2.0, 0.85)
		await get_tree().create_timer(0.45).timeout
		Sfx.play_at("metalClick", room.call("door_center"), -4.0, 0.6)
		await get_tree().create_timer(1.2).timeout
		_rec_stop("cal_cle_%s.wav" % tag)
		# 3) le ronflement de Papi derrière le mur (8 s)
		await _rec_start()
		var snore: Node = Sfx.loop("snore", -8.0, Vector3(-0.6, 0.7, -2.9), self)
		await get_tree().create_timer(8.0).timeout
		snore.queue_free()
		_rec_stop("cal_ronflement_%s.wav" % tag)
		# 4) la respiration d'Henriette derrière P2, depuis le couloir (acte2.gd)
		await _go(Vector3(3.9, 0.0, -3.6), PI / 2.0)
		await _rec_start()
		var br: Node = Sfx.loop("breath_slow", -14.0, BREATH_POS, self)
		if br:
			br.set("max_distance", 9.0)
		await get_tree().create_timer(10.0).timeout
		br.queue_free()
		_rec_stop("cal_respiration_%s.wav" % tag)
		# 5) les coups à P2 (le joueur frappe)
		await _rec_start()
		for k in 3:
			Sfx.play_at("thud", (house.doors["P2"] as Node3D).global_position + Vector3(0, 1.25, 0), -3.0, 1.2 + 0.05 * k, 3.0)
			await get_tree().create_timer(0.42).timeout
		await get_tree().create_timer(1.0).timeout
		_rec_stop("cal_coups_%s.wav" % tag)
		# 6) le radiateur (S.O.S.), depuis le couloir
		await _go(Vector3(4.2, 0.0, -2.0), PI)
		await _rec_start()
		for k in 6:
			Sfx.play_at("pipe_knock", PIPE_POS, -4.0 if k % 2 == 0 else -1.0, 1.12 if k % 2 == 0 else 0.82, 3.0)
			await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(1.0).timeout
		_rec_stop("cal_radiateur_%s.wav" % tag)
		# 7) le modem depuis la salle de bain (P4 à 20°, P1 ouverte)
		(house.doors["P1"] as Door).set_open_now(true)
		await _go(Vector3(7.0, 0.0, -5.5))
		await _rec_start()
		var m := Sfx.play_at("modem_chant", room.get("screen_center"), -3.0, 1.0, 6.0)
		if m:
			m.max_distance = 40.0
			m.attenuation_filter_cutoff_hz = 3500.0
			m.pitch_scale = 1.0
		await get_tree().create_timer(8.5).timeout
		_rec_stop("cal_modem_sdb_%s.wav" % tag)
		(house.doors["P1"] as Door).set_open_now(false)
		await get_tree().create_timer(0.3).timeout
	# l'ambiance de chaque pièce (5 s, rien d'autre) : avant = le ton de la pièce et la pluie de F1 seulement
	_ambiance(true)
	var ac := _ac()
	var rooms := {"mere": Vector3(0.5, 0.0, 0.5), "couloir": Vector3(4.0, 0.0, -1.0), "sdb": Vector3(6.5, 0.0, -5.6),
		"amis": Vector3(0.0, 0.0, 4.5), "gp": Vector3(0.0, 0.0, -5.0), "bureau": Vector3(7.0, 0.0, 4.2), "escalier": Vector3(6.5, 0.0, 0.8)}
	for on in [false, true]:
		Sfx.acoustique_on = on
		for id in ac.rain:
			ac.rain[id].stream_paused = not on
		ac.roof.stream_paused = not on
		for room_id in rooms:
			await _go(rooms[room_id])
			await get_tree().create_timer(0.3).timeout
			await _rec_start()
			await get_tree().create_timer(5.0).timeout
			_rec_stop("cal_ambiance_%s_%s.wav" % [room_id, "apres" if on else "avant"])
	Sfx.acoustique_on = true
	var f := FileAccess.open(out_dir.path_join("calibrage.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cas": ["pas", "cle", "ronflement", "respiration", "coups", "radiateur", "modem_sdb",
		"ambiance_mere", "ambiance_couloir", "ambiance_sdb", "ambiance_amis", "ambiance_gp", "ambiance_bureau", "ambiance_escalier"]}))
	f.close()
	print("CALIBRAGE ÉCRIT dans ", out_dir)


## 60 s d'écoute (couloir, salle de bain, chambre d'amis, cage d'escalier), puis des mesures au calme.
func _ecoute() -> void:
	var house: Node = main.get("house")
	var marks := []
	var t0 := 0
	var mark := func(what: String) -> void:
		marks.append([snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.01), what])
	var wait := func(s: float) -> void:
		await get_tree().create_timer(s).timeout
	await _go(Vector3(4.0, 0.0, -2.0), 0.0)
	await _rec_start()
	t0 = Time.get_ticks_msec()
	mark.call("couloir : ambiance seule (pluie à F8 au bout du couloir, toit, ton de la pièce)")
	await wait.call(3.0)
	mark.call("coup dans le couloir (même pièce, Rev_couloir)")
	Sfx.play_at("thud", Vector3(4.0, 1.0, -4.5), -3.0)
	await wait.call(3.0)
	mark.call("coup dans la salle de bain, P4 entrouverte à 20° (entrouverte, Rev_sourd)")
	Sfx.play_at("thud", Vector3(6.6, 1.0, -6.0), -3.0)
	await wait.call(3.0)
	(house.doors["P4"] as Door).set_open_now(true)
	await wait.call(0.3)
	mark.call("coup dans la salle de bain, P4 grande ouverte (ouverte, Rev_carrelage)")
	Sfx.play_at("thud", Vector3(6.6, 1.0, -6.0), -3.0)
	await wait.call(2.7)
	await _go(Vector3(6.0, 0.0, -5.5), PI)
	mark.call("dans la salle de bain : coup au carrelage (même pièce)")
	Sfx.play_at("thud", Vector3(6.8, 1.0, -6.4), -3.0)
	await wait.call(2.75)
	await _go(Vector3(0.0, 0.0, 4.5), PI / 2.0)
	mark.call("chambre d'amis : coup sur la moquette (même pièce, Rev_feutree)")
	Sfx.play_at("thud", Vector3(0.6, 1.0, 5.0), -3.0)
	await wait.call(2.75)
	mark.call("chambre d'amis : coup dans le couloir, P3 fermée (fermée)")
	Sfx.play_at("thud", Vector3(4.0, 1.0, 3.6), -3.0)
	await wait.call(3.0)
	(house.doors["P3"] as Door).set_open_now(true)
	await wait.call(0.3)
	mark.call("chambre d'amis : le même coup, P3 ouverte (ouverte)")
	Sfx.play_at("thud", Vector3(4.0, 1.0, 3.6), -3.0)
	await wait.call(2.7)
	await _go(Vector3(4.0, 0.0, -2.8), 0.0)
	mark.call("couloir : coups à P2 (plan de la porte)")
	for k in 3:
		Sfx.play_at("thud", (house.doors["P2"] as Node3D).global_position + Vector3(0, 1.25, 0), -3.0, 1.2 + 0.05 * k, 3.0)
		await wait.call(0.42)
	await wait.call(0.8)
	mark.call("couloir : la respiration d'Henriette derrière P2 (fermée)")
	var br: Node = Sfx.loop("breath_slow", -14.0, BREATH_POS, self)
	await wait.call(5.0)
	br.queue_free()
	mark.call("silence de l'entité (1,5 s), puis elle passe à travers les murs (bourdonnement)")
	Sfx.silence(1.5)
	await wait.call(1.5)
	Sfx.hum_move(Vector3(1.0, 1.2, -4.5), Vector3(7.0, 1.2, 4.0), 1.4, -6.0)
	await wait.call(2.0)
	mark.call("bips de l'entité dans le couloir : l'ambiance se range dessous (chaîne latérale)")
	for k in 6:
		Sfx.voice_at("chirp", Vector3(4.2, 1.2, -1.0), -12.0, 0.9 + 0.05 * k, 1.6)
		await wait.call(0.35)
	await wait.call(1.0)
	mark.call("tonnerre, dans le couloir (fenêtre F8 claire)")
	Sfx.play("thunder", -3.0)
	await wait.call(6.0)
	await _go(Vector3(6.5, 0.0, 0.8), 0.0)
	mark.call("cage d'escalier : tonnerre étouffé (pas de fenêtre), puis un coup (Rev_cage)")
	Sfx.play("thunder", -3.0)
	await wait.call(3.0)
	Sfx.play_at("thud", Vector3(7.5, 1.0, 1.2), -3.0)
	await wait.call(3.0)
	mark.call("fin")
	_rec_stop("ecoute_couloir.wav")
	(house.doors["P4"] as Door).set_ajar(20.0)
	(house.doors["P3"] as Door).set_open_now(false)
	# mesures au calme : deux sons fixes (un coup sourd, un loquet clair ; ni variante ni hauteur au hasard)
	# par situation, 2,5 s chacun ; l'Ambiance muette (les gouttes de la salle de bain naissent sans cesse)
	_ambiance(false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambiance"), true)
	var cases := [
		["carrelage", Vector3(6.0, 0.0, -5.5), Vector3(6.8, 1.0, -6.4), ""],
		["moquette", Vector3(0.0, 0.0, 4.5), Vector3(0.6, 1.0, 5.0), ""],
		["couloir", Vector3(4.0, 0.0, -2.0), Vector3(4.0, 1.0, -3.5), ""],
		["cage", Vector3(6.5, 0.0, 0.8), Vector3(7.5, 1.0, 1.2), ""],
		["chambre", Vector3(0.5, 0.0, 0.5), Vector3(1.2, 1.0, -0.5), ""],
		["gp_porte_ouverte", Vector3(3.9, 0.0, -3.0), Vector3(1.5, 1.0, -4.8), "P2"],
		["gp_porte_fermee", Vector3(3.9, 0.0, -3.0), Vector3(1.5, 1.0, -4.8), ""],
		["sec_sans_acoustique", Vector3(4.0, 0.0, -2.0), Vector3(4.0, 1.0, -3.5), "off"],
	]
	for c in cases:
		Sfx.acoustique_on = c[3] != "off"
		if c[3] == "P2":
			(house.doors["P2"] as Door).set_open_now(true)
		await _go(c[1])
		await wait.call(0.2)
		var acx := _ac()
		print("MESURE %s : auditeur %s, classes %s, portes %s" % [c[0], acx.listener_room, acx.room_class, acx.door_states])
		for probe in [["coup", "impactWood_heavy_000"], ["loquet", "metalLatch"]]:
			await _rec_start()
			Sfx.play_3d(probe[1], c[2], {"db": -3.0})
			await wait.call(2.5)
			_rec_stop("mesure_%s_%s.wav" % [c[0], probe[0]])
		# balayage sinusoïdal exponentiel (50 Hz - 16 kHz, 1 s) : la réponse impulsionnelle du trajet, par
		# déconvolution (analyse du lot), insensible aux autres bruits de la maison
		await _rec_start()
		Sfx.play_3d("", c[2], {"db": -3.0, "stream": _sweep()})
		await wait.call(3.0)
		_rec_stop("balayage_%s.wav" % c[0])
		if c[3] == "P2":
			(house.doors["P2"] as Door).set_open_now(false)
	Sfx.acoustique_on = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambiance"), false)
	_ambiance(true)
	# l'ambiance sous les bips de l'entité (compresseur à chaîne latérale) : le bus Ambiance seul, 2 s sans,
	# 2 s de bips à 2 m (-12 dB, comme Nestor), 2 s sans
	await _go(Vector3(4.0, 0.0, -2.0), 0.0)
	await wait.call(0.5)
	var amb := AudioServer.get_bus_index("Ambiance")
	var ra := AudioEffectRecord.new()
	AudioServer.add_bus_effect(amb, ra)
	await get_tree().process_frame
	ra.set_recording_active(true)
	await wait.call(2.0)
	for k in 7:
		Sfx.voice_at("chirp", Vector3(4.2, 1.2, -0.2), -12.0, 0.9 + 0.04 * k, 1.6)
		await wait.call(0.3)
	await wait.call(2.0)
	ra.set_recording_active(false)
	ra.get_recording().save_to_wav(out_dir.path_join("canard_ambiance.wav"))
	AudioServer.remove_bus_effect(amb, AudioServer.get_bus_effect_count(amb) - 1)
	var f := FileAccess.open(out_dir.path_join("ecoute.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"reperes": marks, "mesures": cases.map(func(c: Array) -> String: return c[0])}, "  "))
	f.close()
	print("ÉCOUTE ÉCRITE dans ", out_dir)


## Réglage du compresseur de l'Ambiance : pour plusieurs seuils et rapports, l'Ambiance (pluie, toit, ton de la
## pièce, depuis le couloir) avant / pendant des bips de l'entité à 2 m (-12 dB, comme Nestor) / 1 s après.
func _canard_reglages() -> void:
	var amb := AudioServer.get_bus_index("Ambiance")
	var comp := AudioServer.get_bus_effect(amb, 0) as AudioEffectCompressor
	await _go(Vector3(4.0, 0.0, -2.0), 0.0)
	# une ambiance stable (bruit, -30 dBFS environ, plate) à la place de la pluie, qui varie trop pour mesurer
	_ambiance(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var b := PackedByteArray()
	b.resize(44100 * 2)
	for i in 44100:
		b.encode_s16(i * 2, rng.randi_range(-1800, 1800))
	var bw := AudioStreamWAV.new()
	bw.data = b
	bw.mix_rate = 44100
	bw.format = AudioStreamWAV.FORMAT_16_BITS
	bw.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bw.loop_end = 44100
	var bed := AudioStreamPlayer.new()
	bed.stream = bw
	bed.bus = &"Ambiance"
	add_child(bed)
	bed.play()
	await get_tree().create_timer(1.0).timeout
	for th in [-34.0, -26.0, -22.0, -18.0, -14.0]:
		for ra in [2.0, 3.0]:
			comp.threshold = th
			comp.ratio = ra
			var ra_rec := AudioEffectRecord.new()
			AudioServer.add_bus_effect(amb, ra_rec)
			await get_tree().process_frame
			ra_rec.set_recording_active(true)
			await get_tree().create_timer(1.5).timeout
			for k in 6:
				Sfx.voice_at("chirp", Vector3(4.2, 1.2, -0.2), -12.0, 0.9 + 0.04 * k, 1.6)
				await get_tree().create_timer(0.3).timeout
			await get_tree().create_timer(1.6).timeout
			ra_rec.set_recording_active(false)
			var d := ra_rec.get_recording().data
			AudioServer.remove_bus_effect(amb, AudioServer.get_bus_effect_count(amb) - 1)
			var e := []
			for w in [[0.2, 1.4], [1.7, 3.2], [4.3, 4.9]]:
				var sum := 0.0
				var n := 0
				for i in range(int(w[0] * 44100) * 4, mini(int(w[1] * 44100) * 4, d.size() - 4), 4):
					var v := d.decode_s16(i) / 32768.0
					sum += v * v
					n += 1
				e.append(10.0 * log(sum / maxi(n, 1) + 1e-20) / log(10.0))
			print("CANARD seuil %.0f rapport %.1f : avant %.1f dB, pendant %+.1f dB, 1 s après %+.1f dB" % [th, ra, e[0], e[1] - e[0], e[2] - e[0]])
			await get_tree().create_timer(1.0).timeout


var _sweep_wav: AudioStreamWAV


## Balayage sinusoïdal exponentiel de 50 Hz à 16 kHz en 1 s (amplitude 0,5), mono 44,1 kHz.
func _sweep() -> AudioStreamWAV:
	if _sweep_wav:
		return _sweep_wav
	var rate := 44100
	var n := rate
	var f1 := 50.0
	var f2 := 16000.0
	var k := log(f2 / f1)
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var ph := TAU * f1 * 1.0 / k * (exp(t * k) - 1.0)
		var env := minf(1.0, minf(t / 0.005, (1.0 - t) / 0.005))
		b.encode_s16(i * 2, int(sin(ph) * 0.5 * env * 32767.0))
	_sweep_wav = AudioStreamWAV.new()
	_sweep_wav.data = b
	_sweep_wav.mix_rate = rate
	_sweep_wav.format = AudioStreamWAV.FORMAT_16_BITS
	return _sweep_wav
