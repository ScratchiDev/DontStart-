extends Node
## Banc du relecteur 0.3.2 « textes et règles » (sans rendu, exclu de l'export) :
## XDG_DATA_HOME=… godot --headless --path godot res://tests/relecteur032_textes_banc.tscn [-- --cas=a,b]
## Les textes attendus sont écrits ici en toutes lettres, d'après docs/v0.3.md § 5.6.9 (ils ne lisent
## aucune constante de seance2.gd). La séance 2 est jouée en entier sur un terminal qui enregistre
## (relecteur032_textes_term.gd), en mode turbo, choix posés par autopicks.

const TERM := preload("res://tests/relecteur032_textes_term.gd")

var bad := 0
var only: PackedStringArray = []


func _check(id: String, cond: bool, detail := "") -> void:
	if cond:
		print("R032 %s OK" % id)
	else:
		bad += 1
		print("R032 %s ÉCHEC : %s" % [id, detail])


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cas="):
			only = a.substr(6).split(",")
	Game.autotest = true          # (autopicks ; pas de choix.cfg ni de chuchotements)
	_run.call_deferred()


func _want(id: String) -> bool:
	return only.is_empty() or only.has(id)


# ------------------------------------------------------------------ attendus (§ 5.6.9, au mot près)

const SIM := {"retourne": "RETOURNÉ", "fixe": "FIXÉ", "yeux_fermes": "YEUX FERMÉS"}
const REEL := {"fixe": "RECONNU", "retourne": "RETOURNÉ", "fui": "FUITE"}


func _expected_results(reflet: String, miroir: String) -> Array:
	var same := (reflet == "retourne" and miroir == "retourne") or (reflet == "fixe" and miroir == "fixe")
	return ["PROTOCOLE 4 · SIMULATION ..... " + SIM[reflet], "PROTOCOLE 4 · ESSAI RÉEL ..... " + REEL[miroir],
		"Constant. J'aime les sujets constants." if same else "Tu as changé. Je l'ai noté."]


# ------------------------------------------------------------------ une séance 2 complète

## Joue Seance2.run() ; rend {said, rec, ended, peur0, peur_steps, prix_confirme, issue, T}.
func play(hero: String, prix: String, proche: String, reflet: String, miroir: String, sos: bool,
		since: float, picks: Array, peur0 := 45.0) -> Dictionary:
	Game.reset_state()
	Game.hero = hero
	Game.set_peur_floor(0.0)
	Game.set_peur(peur0)
	Game.choices = {"prix": prix, "proche": proche, "reflet": reflet, "miroir_reel": miroir}
	if sos:
		Game.set_flag("sos_joue", true)
	var T = TERM.new()
	add_child(T)
	await get_tree().process_frame
	T.turbo = true
	T.autopicks = picks.duplicate()
	var res := {"ended": [], "peur_steps": []}
	T.ended.connect(func(id: String) -> void: (res.ended as Array).append(id))
	var on_peur := func(v: float) -> void: (res.peur_steps as Array).append(v)
	Game.peur_changed.connect(on_peur)
	var s := Seance2.new()
	s.T = T
	s.since_convocation = since
	add_child(s)
	var t0 := Time.get_ticks_msec()
	await s.run()
	Game.peur_changed.disconnect(on_peur)
	res.secs = (Time.get_ticks_msec() - t0) / 1000.0
	res.said = s.said.duplicate()
	res.rec = T.rec.duplicate()
	res.issue = s.issue
	res.done = s.done
	res.peur0 = peur0
	res.peur = Game.peur
	res.prix_confirme = Game.choices.get("prix_confirme", "")
	res.fin_seance2 = Game.choices.get("fin_seance2", "")
	res.T = T
	res.s = s
	return res


func _lines(rec: Array) -> Array:
	var out: Array = []
	for e in rec:
		if e[0] == "line":
			out.append(e[1])
	return out


func _find(rec: Array, kind: String, text := "") -> int:
	for i in rec.size():
		if rec[i][0] == kind and (text == "" or str(rec[i][1]) == text):
			return i
	return -1


## Toutes les lignes écrites, du début (attendues pour un cas sans ABSORBÉ).
func _expected_all(hero: String, prix: String, proche: String, reflet: String, miroir: String, sos: bool,
		temps: String, middle: Array) -> Array:
	var nm := "Aurèlia" if hero == "aurelia" else "Alexandre"
	var out: Array = ["SÉANCE 2", "", "Te revoilà, %s." % nm]
	if temps == "":
		out.append("Tu es %s vite. C'est bien. Ou c'est la peur." % ("revenue" if hero == "aurelia" else "revenu"))
	else:
		out.append("Tu as mis %s à revenir. Je n'ai rien fait pendant ce temps. Presque rien." % temps)
	out.append("Résultats.")
	out.append_array(_expected_results(reflet, miroir))
	out.append_array(["Tu as ramassé un sèche-cheveux et une antenne.",
		"Ta mère avait fait le même dessin, ici, en 2016. Je l'ai vu par l'écran.",
		"Construis-le. Je veux voir.",
		"Il te manque deux pièces. Elles sont en bas. Ton grand-père aussi."])
	if sos:
		out.append("Il tape encore sur les tuyaux. Je lis tout.")
	out.append_array(["PROTOCOLE 3 · SACRIFICE", ""])
	var mot: String = {"toi": "Moi", "proche": proche, "personne": "Personne"}[prix]
	out.append("En simulation, tu as choisi : %s." % mot)
	out.append_array(["Tout à l'heure, l'essai réel. Chambre du fond.", "Tu confirmes ?"])
	out.append_array(middle)
	out.append_array(["Ta grand-mère dort.", "Son cœur bat à 58.", "57.", "55.",
		"Je peux faire descendre ce chiffre.", "Viens voir."])
	return out


func _diff(a: Array, b: Array) -> String:
	for i in maxi(a.size(), b.size()):
		var x: String = str(a[i]) if i < a.size() else "(rien)"
		var y: String = str(b[i]) if i < b.size() else "(rien)"
		if x != y:
			return "ligne %d : « %s » au lieu de « %s »" % [i, x, y]
	return ""


## Vérifications communes d'un cas complet (sans ABSORBÉ).
func check_case(tag: String, r: Dictionary, want_lines: Array, want_prix: String, want_issue: String, want_gain: float) -> void:
	var got := _lines(r.rec)
	_check("%s : lignes au mot près" % tag, got == want_lines, _diff(got, want_lines))
	_check("%s : issue « %s », prix_confirme « %s »" % [tag, want_issue, want_prix],
		r.issue == want_issue and r.prix_confirme == want_prix, "issue %s · prix %s" % [r.issue, r.prix_confirme])
	var steps: Array = r.peur_steps
	var deltas: Array = []
	var prev: float = r.peur0
	for v in steps:
		deltas.append(snappedf(float(v) - prev, 0.01))
		prev = float(v)
	_check("%s : jauge +%d puis +6 (cœur)" % [tag, int(want_gain)], deltas == [want_gain, 6.0], "pas %s (de %.0f à %.1f)" % [str(deltas), r.peur0, r.peur])
	_check("%s : fin de version" % tag, r.ended == ["fin_v03"] and r.done, str(r.ended))
	# genres : « Résultats. » dim ; ligne 12 dim ; « Viens voir. » dim et lent ; niveaux exacts
	var rec: Array = r.rec
	var k_res := _find(rec, "line", "Résultats.")
	var k_vv := _find(rec, "line", "Viens voir.")
	var k_12 := _find(rec, "line", "Il tape encore sur les tuyaux. Je lis tout.")
	_check("%s : « Résultats. » dim, « Viens voir. » dim et lent" % tag, k_res >= 0 and rec[k_res][2] == "dim"
		and k_vv >= 0 and rec[k_vv][2] == "dim" and float(rec[k_vv][3]) > 0.05 and (k_12 < 0 or rec[k_12][2] == "dim"),
		"%s %s %s" % [rec[k_res] if k_res >= 0 else "", rec[k_vv] if k_vv >= 0 else "", rec[k_12] if k_12 >= 0 else ""])
	var lv: Array = []
	for e in rec:
		if e[0] == "level":
			lv.append([e[1], e[2]])
	_check("%s : niveaux 1 et 13" % tag, lv == [["SÉANCE 2", "Résultats intermédiaires"], ["PROTOCOLE 3 · SACRIFICE", "Confirmation"]], str(lv))
	# le cœur : apparaît après la ligne 17, 58 puis 57, 55, 52 en 6 s ; « 57. » et « 55. » ; power_off après 21
	var k17 := _find(rec, "line", "Ta grand-mère dort.")
	var k58 := _find(rec, "heart")
	var hearts: Array = []
	var times: Array = []
	for e in rec:
		if e[0] == "heart":
			hearts.append(e[1])
			times.append(e[2])
	var span := (int(times[-1]) - int(times[0])) / 1000.0 if times.size() > 1 else -1.0
	_check("%s : ♥ 58 après la ligne 17, puis 57, 55, 52 en 6 s" % tag, k17 >= 0 and k58 > k17 and hearts == [58, 57, 55, 52]
		and absf(span - 6.0) < 0.35, "après 17 : %s · %s en %.2f s" % [k58 > k17, str(hearts), span])
	var kpo := -1
	for i in rec.size():
		if rec[i][0] == "power_off":
			kpo = i
	_check("%s : écran éteint après « Viens voir. »" % tag, kpo > k_vv and k_vv > 0, "%d %d" % [kpo, k_vv])
	# said (lignes remplies) = lignes écrites (hors niveaux)
	var said_ok := true
	for l in r.said:
		if not got.has(l) and not str(l).begins_with("> DÉLAI"):
			said_ok = false
	_check("%s : said cohérent" % tag, said_ok, str(r.said))


func _pick_recs(rec: Array) -> Array:
	var out: Array = []
	for e in rec:
		if e[0] == "pick":
			out.append(e)
	return out


func _run() -> void:
	# ---------------------------------------------------------------- results_lines : 9 combinaisons
	if _want("res"):
		var n := 0
		for a in SIM:
			for b in REEL:
				var got: Array = Seance2.results_lines(a, b)
				var want := _expected_results(a, b)
				if got == want:
					n += 1
				else:
					print("  results_lines(%s, %s) = %s ; attendu %s" % [a, b, got, want])
		_check("C2 results_lines 9 combinaisons (attendus écrits à la main)", n == 9, "%d/9" % n)
		# littéraux, pour lever tout doute sur la construction
		_check("results fixe/fixe", Seance2.results_lines("fixe", "fixe") == ["PROTOCOLE 4 · SIMULATION ..... FIXÉ", "PROTOCOLE 4 · ESSAI RÉEL ..... RECONNU", "Constant. J'aime les sujets constants."])
		_check("results retourne/retourne", Seance2.results_lines("retourne", "retourne") == ["PROTOCOLE 4 · SIMULATION ..... RETOURNÉ", "PROTOCOLE 4 · ESSAI RÉEL ..... RETOURNÉ", "Constant. J'aime les sujets constants."])
		_check("results yeux_fermes/fixe", Seance2.results_lines("yeux_fermes", "fixe") == ["PROTOCOLE 4 · SIMULATION ..... YEUX FERMÉS", "PROTOCOLE 4 · ESSAI RÉEL ..... RECONNU", "Tu as changé. Je l'ai noté."])
		_check("results retourne/fixe", Seance2.results_lines("retourne", "fixe")[2] == "Tu as changé. Je l'ai noté.")
		_check("results fixe/retourne", Seance2.results_lines("fixe", "retourne")[2] == "Tu as changé. Je l'ai noté.")
		_check("results retourne/fui", Seance2.results_lines("retourne", "fui") == ["PROTOCOLE 4 · SIMULATION ..... RETOURNÉ", "PROTOCOLE 4 · ESSAI RÉEL ..... FUITE", "Tu as changé. Je l'ai noté."])
		for s in [0.0, 2.0, 30.0, 59.9, 60.0, 61.0, 75.0, 89.0, 130.0, 299.0, 600.0, 3599.0, 3600.0, 3661.0]:
			print("  {temps} %7.1f s → « %s »" % [s, Seance2.duration_text(s)])
	# ---------------------------------------------------------------- confirmer, Alexandre, vite, S.O.S.
	if _want("confirmer"):
		var r := await play("alexandre", "proche", "Mamie", "retourne", "retourne", true, 30.0, [0])
		check_case("confirmer (Alexandre, 30 s, S.O.S., prix proche)", r,
			_expected_all("alexandre", "proche", "Mamie", "retourne", "retourne", true, "", ["Consigné."]),
			"proche", "confirmer", 4.0)
		var pk := _pick_recs(r.rec)
		_check("confirmer : pick([Confirmer, Changer d'avis], 10 s, pire 1)", pk.size() == 1 and pk[0][1] == ["Confirmer", "Changer d'avis"]
			and is_equal_approx(float(pk[0][2]), 10.0) and int(pk[0][3]) == 1, str(pk))
	# ---------------------------------------------------------------- confirmer, Aurèlia, lent, sans S.O.S., prix toi
	if _want("confirmer_f"):
		var r := await play("aurelia", "toi", "Papi", "fixe", "fixe", false, 130.0, [0])
		check_case("confirmer (Aurèlia, 130 s, sans S.O.S., prix toi)", r,
			_expected_all("aurelia", "toi", "Papi", "fixe", "fixe", false, "2 minutes et 10 secondes", ["Consigné."]),
			"toi", "confirmer", 4.0)
	# ---------------------------------------------------------------- confirmer, Aurèlia, vite, prix personne
	if _want("confirmer_p"):
		var r := await play("aurelia", "personne", "Maman", "yeux_fermes", "fui", true, 12.0, [0])
		check_case("confirmer (Aurèlia, 12 s, prix personne)", r,
			_expected_all("aurelia", "personne", "Maman", "yeux_fermes", "fui", true, "", ["Consigné."]),
			"personne", "confirmer", 4.0)
	# ---------------------------------------------------------------- {temps} à 60 s pile et 59,9 s
	if _want("temps"):
		var r := await play("alexandre", "proche", "Papi", "fixe", "retourne", false, 60.0, [0])
		var l: Array = _lines(r.rec)
		_check("{temps} à 60 s : « Tu as mis 1 minute à revenir. »", l.has("Tu as mis 1 minute à revenir. Je n'ai rien fait pendant ce temps. Presque rien."), str(l.slice(2, 4)))
		var r2 := await play("aurelia", "proche", "Papi", "fixe", "retourne", false, 59.9, [0])
		_check("59,9 s : « Tu es revenue vite. »", _lines(r2.rec).has("Tu es revenue vite. C'est bien. Ou c'est la peur."), str(_lines(r2.rec).slice(2, 4)))
	# ---------------------------------------------------------------- changer d'avis : prix personne → Moi
	if _want("changer"):
		var r := await play("alexandre", "personne", "Mamie", "retourne", "fixe", true, 40.0, [1, 0])
		check_case("changer (personne → Moi)", r,
			_expected_all("alexandre", "personne", "Mamie", "retourne", "fixe", true, "", ["Changer d'avis coûte. Je l'ai noté."]),
			"toi", "changer", 8.0)
		var pk := _pick_recs(r.rec)
		_check("changer : second choix « Moi », « Mamie », 8 s, pire = le proche (indice 1)", pk.size() == 2 and pk[1][1] == ["Moi", "Mamie"]
			and is_equal_approx(float(pk[1][2]), 8.0) and int(pk[1][3]) == 1, str(pk[1] if pk.size() > 1 else pk))
	# ---------------------------------------------------------------- changer d'avis : prix toi → Personne
	if _want("changer_f"):
		var r := await play("aurelia", "toi", "Papi", "fixe", "fixe", false, 70.0, [1, 1])
		check_case("changer (toi → Personne, Aurèlia)", r,
			_expected_all("aurelia", "toi", "Papi", "fixe", "fixe", false, "1 minute et 10 secondes", ["Changer d'avis coûte. Je l'ai noté."]),
			"personne", "changer", 8.0)
	# ---------------------------------------------------------------- changer, puis délai au second choix (prix toi)
	if _want("changer_delai"):
		var r := await play("alexandre", "toi", "Mamie", "retourne", "fui", false, 20.0, [1])
		var pk := _pick_recs(r.rec)
		print("  changer puis délai : ", pk[-1])
		_check("changer puis délai (toi) : 8 s, le proche retenu", r.prix_confirme == "proche" and pk.size() == 2
			and absf(float(pk[1][7]) - 8.0) < 0.3 and bool(pk[1][6]), "prix %s · %.2f s · délai %s" % [r.prix_confirme, float(pk[1][7]) if pk.size() > 1 else -1.0, pk[1][6] if pk.size() > 1 else "?"])
		print("  jauge : ", r.peur0, " → ", r.peur_steps)
		print("  lignes : ", _lines(r.rec).slice(15, 24))
	# ---------------------------------------------------------------- changer, puis délai au second choix (prix proche : options Moi, Personne)
	if _want("changer_delai_p"):
		var r := await play("alexandre", "proche", "Maman", "retourne", "fui", false, 20.0, [1])
		var pk := _pick_recs(r.rec)
		print("  changer puis délai (prix proche) : ", pk[-1])
		print("  prix_confirme : ", r.prix_confirme, " · jauge ", r.peur0, " → ", r.peur_steps)
		print("  lignes : ", _lines(r.rec).slice(15, 24))
	# ---------------------------------------------------------------- délai au premier choix
	if _want("delai"):
		var r := await play("aurelia", "personne", "Mamie", "yeux_fermes", "retourne", true, 200.0, [])
		check_case("délai (Aurèlia, 200 s, prix personne)", r,
			_expected_all("aurelia", "personne", "Mamie", "yeux_fermes", "retourne", true, "3 minutes et 20 secondes", ["> DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI."]),
			"proche", "delai", 10.0)
		var pk := _pick_recs(r.rec)
		print("  délai : options à l'écran ", pk[0][8], " · %.2f s" % float(pk[0][7]))
		_check("délai : 10 s, aucune jauge du terminal en plus (timeout_fear 0)", absf(float(pk[0][7]) - 10.0) < 0.3 and is_equal_approx(float(pk[0][4]), 0.0), str(pk[0]))
	# ---------------------------------------------------------------- ABSORBÉ au choix (97 + 4)
	if _want("absorbe"):
		var r := await play("alexandre", "proche", "Mamie", "retourne", "retourne", false, 30.0, [0], 97.0)
		var l: Array = _lines(r.rec)
		print("  ABSORBÉ (choix) : fin ", r.ended, " · jauge ", r.peur, " · prix ", r.prix_confirme, " · fin_seance2 ", r.fin_seance2)
		print("  lignes après « Consigné. » : ", l.slice(l.find("Consigné."), l.size()))
		var face := _find(r.rec, "face")
		print("  visage : ", r.rec[face] if face >= 0 else "aucun")
		_check("ABSORBÉ (choix) : fin « absorbe », pas de fin de version, rien du cœur", r.ended == ["absorbe"] and is_equal_approx(r.peur, 100.0)
			and not l.has("Ta grand-mère dort.") and r.fin_seance2 == "absorbe", "%s %s" % [r.ended, l])
		_check("ABSORBÉ (séance 2) : aucun visage (§ 1.2 ; GDD § 4.6 : acte II, visage seulement au couloir en boucle, v0.4)", face < 0,
			"watch_face(%s) appelé" % (str(r.rec[face][1]) if face >= 0 else ""))
	# ---------------------------------------------------------------- ABSORBÉ au cœur (94 + 4 + 6)
	if _want("absorbe_coeur"):
		var r := await play("aurelia", "toi", "Papi", "fixe", "fixe", false, 30.0, [0], 92.0)
		var l: Array = _lines(r.rec)
		print("  ABSORBÉ (cœur) : fin ", r.ended, " · jauge ", r.peur, " · lignes ", l.slice(l.find("Ta grand-mère dort."), l.size()))
		_check("ABSORBÉ (cœur, 92 + 4 + 6) : fin « absorbe » sans « Je peux faire descendre ce chiffre. »", r.ended == ["absorbe"]
			and not l.has("Je peux faire descendre ce chiffre.") and not l.has("Viens voir."), str(r.ended))
	print("R032 %s" % ("BANC OK" if bad == 0 else "BANC ÉCHEC %d" % bad))
	get_tree().quit(0 if bad == 0 else 1)
