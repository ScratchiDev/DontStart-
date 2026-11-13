class_name Seance2
extends Node
## Séance 2 de S.1.L.3.N.C.3. (acte II, convocation) : « Résultats intermédiaires ». Jouée sur
## l'ordinateur de ta mère, sur le moteur du terminal (terminal.gd), comme seance1.gd. Le bilan des
## essais (protocole 4 : simulation et essai réel), les pièces de l'arme, la confirmation du
## protocole 3 (choix minuté), puis le cœur d'Henriette qui descend de 58 à 52 ; l'écran s'éteint et
## le terminal émet ended("fin_v03") : Acte2 joue la fin de la version 0.3.
## Référence : docs/v0.3.md, § 2.2 (étape 14), § 5.5 (jauge), § 5.6.9 (textes, au mot près).
##
## Créée par Acte2 quand le joueur répond à l'ordinateur ; propriétés posées avant run() :
## T (le terminal), player, haunt (jauge et journal), gp (la chambre des grands-parents : le bracelet
## et CAM 3 suivent le pouls), since_convocation (secondes de jeu depuis la convocation).
## Résultat : Game.choices["prix_confirme"] = « toi », « proche » ou « personne » ; issue (« confirmer »,
## « changer », « delai »), said (les lignes écrites, remplies, dans l'ordre : autotest).
## Si la jauge atteint 100 pendant la séance, le terminal passe en « aborted » et la séance finit sur
## ABSORBÉ (comme la séance 1 : ended("absorbe")) ; aucun point de passage n'est écrit.

const OPTIONS := ["Moi", "{proche}", "Personne"]        # protocole 3 (seance1.gd, _p3)
const PRIX := ["toi", "proche", "personne"]               # Game.choices["prix"] et ["prix_confirme"]
## Bilan du protocole 4 (lignes 5 et 6) : ce qui s'affiche pour chaque issue.
const SIM_WORDS := {"retourne": "RETOURNÉ", "fixe": "FIXÉ", "yeux_fermes": "YEUX FERMÉS"}
const REEL_WORDS := {"fixe": "RECONNU", "retourne": "RETOURNÉ", "fui": "FUITE"}
## Jauge (§ 5.5) : issue du choix, puis le chiffre qui descend.
const PEUR_ISSUE := {"confirmer": 4.0, "changer": 8.0, "delai": 10.0}
const PEUR_COEUR := 6.0
const FAST_RETURN := 60.0            # moins de 60 s depuis la convocation : « Tu es revenu vite. »
const HEART := [58, 57, 55, 52]      # l'afficheur « ♥ 58 », puis 57, 55, 52 en 6 s
const HEART_STEP := 2.0

## Textes du § 5.6.9, au mot près.
const L2 := "Te revoilà, {name}."
const L3_VITE := "Tu es {revenu|revenue} vite. C'est bien. Ou c'est la peur."
const L3_LENT := "Tu as mis {temps} à revenir. Je n'ai rien fait pendant ce temps. Presque rien."
const L4 := "Résultats."
const L5 := "PROTOCOLE 4 · SIMULATION ..... %s"
const L6 := "PROTOCOLE 4 · ESSAI RÉEL ..... %s"
const L7_CONSTANT := "Constant. J'aime les sujets constants."
const L7_CHANGE := "Tu as changé. Je l'ai noté."
const L8 := "Tu as ramassé un sèche-cheveux et une antenne."
const L9 := "Ta mère avait fait le même dessin, ici, en 2016. Je l'ai vu par l'écran."
const L10 := "Construis-le. Je veux voir."
const L11 := "Il te manque deux pièces. Elles sont en bas. Ton grand-père aussi."
const L12 := "Il tape encore sur les tuyaux. Je lis tout."
const L14 := "En simulation, tu as choisi : %s."
const L15 := "Tout à l'heure, l'essai réel. Chambre du fond."
const L16 := "Tu confirmes ?"
const L16_OPTS := ["Confirmer", "Changer d'avis"]
const L16_CONFIRME := "Consigné."
const L16_CHANGE := "Changer d'avis coûte. Je l'ai noté."
const L17 := "Ta grand-mère dort."
const L18 := "Son cœur bat à 58."
const L19 := ["57.", "55."]
const L20 := "Je peux faire descendre ce chiffre."
const L21 := "Viens voir."

var T   # le terminal (terminal.gd)
var player: Node
var haunt: Haunt
var gp: Node                         # chambre des grands-parents (gp.gd) : set_heart(bpm)
var since_convocation := 0.0
var issue := ""                      # « confirmer », « changer », « delai » (ou « absorbe »)
var said: Array = []                 # lignes écrites (remplies), dans l'ordre
var done := false


# ------------------------------------------------------------------ fonctions pures

## Les lignes 5 à 7 du bilan (§ 5.6.9) pour reflet = Game.choices["reflet"] (séance 1 : « retourne »,
## « fixe » ou « yeux_fermes ») et miroir_reel = Game.choices["miroir_reel"] (P4 réel : « fixe »,
## « retourne » ou « fui »). « Même comportement » : retourne/retourne ou fixe/fixe.
static func results_lines(reflet: String, miroir_reel: String) -> Array:
	var same := reflet == miroir_reel and (reflet == "retourne" or reflet == "fixe")
	return [
		L5 % str(SIM_WORDS.get(reflet, "?")),
		L6 % str(REEL_WORDS.get(miroir_reel, "?")),
		L7_CONSTANT if same else L7_CHANGE,
	]


## Durée lisible, en français, arrondie sobrement : « 40 secondes », « 1 minute », « 2 minutes »,
## « 3 minutes et 10 secondes », « 12 minutes », « 1 heure et 5 minutes ».
## (moins d'une minute : à 5 s près ; moins de 10 min : à 10 s près ; au-delà : à la minute)
static func duration_text(sec: float) -> String:
	var s := maxf(sec, 0.0)
	if s < 57.5:
		var n := maxi(5, int(round(s / 5.0)) * 5)
		return "%d secondes" % n
	if s < 595.0:
		var total := int(round(s / 10.0)) * 10
		var m := total / 60
		var r := total % 60
		var mins := "%d minute%s" % [m, "s" if m > 1 else ""]
		return mins if r == 0 else "%s et %d secondes" % [mins, r]
	var tm := int(round(s / 60.0))
	if tm < 60:
		return "%d minutes" % tm
	var h := tm / 60
	var mm := tm % 60
	var hours := "%d heure%s" % [h, "s" if h > 1 else ""]
	if mm == 0:
		return hours
	return "%s et %d minute%s" % [hours, mm, "s" if mm > 1 else ""]


## Le mot du choix de la simulation (ligne 14) : « Moi », le prénom du proche, « Personne ».
static func prix_word(prix: String, proche: String) -> String:
	match prix:
		"toi":
			return "Moi"
		"proche":
			return proche
	return "Personne"


## Les deux autres options du protocole 3 (« Changer d'avis ») : indices dans OPTIONS.
static func other_options(prix: String) -> Array:
	var out: Array = []
	for i in PRIX.size():
		if PRIX[i] != prix:
			out.append(i)
	return out


# ------------------------------------------------------------------ séance

func _line(s: String, kind := "n", speed := 0.024, pause := 0.28) -> void:
	if T.aborted:
		return
	said.append(T.fill(s))
	await T.line(s, kind, speed, pause)


## Change la jauge (Haunt.peur, avec la raison) ; à 100, le terminal passe en « aborted ».
func _peur(v: float, why: String) -> void:
	if haunt:
		haunt.peur(v, why)
	else:
		Game.add_peur(v, why)
	if v > 0.0:
		T.glitch(minf(1.0, v / 22.0))
	if Game.peur >= 100.0:
		T.aborted = true


## Attente en temps réel (pas accélérée par le mode turbo du terminal) : le cœur descend en 6 s.
func _real_wait(sec: float) -> void:
	if T.aborted:
		return
	await get_tree().create_timer(sec, false).timeout


func _heart(bpm: int) -> void:
	T.set_heart(bpm)
	if gp and gp.has_method("set_heart"):
		gp.set_heart(bpm)


func run() -> void:
	T.mode = "seance"
	T.started_ms = Time.get_ticks_msec()
	T.aborted = false
	T.status.visible = true
	T.hide_heart()
	T.proche = str(Game.choices.get("proche", "Mamie"))
	await _bilan()
	if not T.aborted:
		await _confirmation()
	if not T.aborted:
		await _coeur()
	if T.aborted:
		await _absorbed()
		return
	done = true
	T.end_version(T.VERSION_END)


## Lignes 1 à 12 : le bilan.
func _bilan() -> void:
	await T.level("SÉANCE 2", "Résultats intermédiaires")
	Sfx.music("music_house", -16.0, 4.0)
	await _line(L2, "n", 0.05, 0.8)
	if since_convocation < FAST_RETURN:
		await _line(L3_VITE)
	else:
		await _line(L3_LENT.replace("{temps}", duration_text(since_convocation)))
	await T.wait(0.4)
	await _line(L4, "dim", 0.04, 0.6)
	var res := results_lines(str(Game.choices.get("reflet", "")), str(Game.choices.get("miroir_reel", "")))
	await _line(res[0], "sys", 0.012, 0.3)
	await _line(res[1], "sys", 0.012, 0.8)
	await _line(res[2], "n", 0.03, 0.9)
	await _line(L8)
	await _line(L9, "n", 0.024, 0.6)
	await _line(L10, "n", 0.05, 0.9)
	await _line(L11, "n", 0.024, 0.8)
	if bool(Game.flag("sos_joue", false)):
		await _line(L12, "dim", 0.03, 0.9)


## Lignes 13 à 16 : la confirmation du protocole 3 (choix minuté).
func _confirmation() -> void:
	await T.level("PROTOCOLE 3 · SACRIFICE", "Confirmation")
	var prix := str(Game.choices.get("prix", "personne"))
	if not PRIX.has(prix):
		prix = "personne"
	await _line(L14 % prix_word(prix, T.proche), "n", 0.03, 0.6)
	await _line(L15, "n", 0.024, 0.8)
	await _line(L16, "n", 0.04, 0.3)
	# (au délai, aucune des deux options n'est montrée comme choisie : elle garde le proche, sans
	# second choix)
	var r: int = await T.pick(L16_OPTS, 10.0, 1, Callable(), 0.0, false)
	if T.aborted:
		return
	var result := prix
	if T.last_timeout:
		# « DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI. » (écrit par le terminal) : elle garde le proche
		issue = "delai"
		said.append("> DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI.")
		result = "proche"
	elif r == 0:
		issue = "confirmer"
		await _line(L16_CONFIRME, "n", 0.04, 0.8)
	else:
		issue = "changer"
		var others := other_options(prix)
		var opts: Array = []
		for i in others:
			opts.append(OPTIONS[i])
		# au bout de 8 s, le pire : le proche (s'il n'est pas proposé, elle le garde)
		var worst := others.find(PRIX.find("proche"))
		var r2: int = await T.pick(opts, 8.0, worst, Callable(), 0.0)
		if T.aborted:
			return
		if T.last_timeout:
			said.append("> DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI.")
		result = PRIX[others[r2]] if r2 >= 0 and r2 < others.size() else "proche"
		await _line(L16_CHANGE, "n", 0.03, 0.9)
	Game.choices["prix_confirme"] = result
	print("SÉANCE 2 : %s → prix confirmé « %s »" % [issue, result])
	_peur(PEUR_ISSUE[issue], "seance2_" + issue)


## Lignes 17 à 21 : le cœur d'Henriette, de 58 à 52.
func _coeur() -> void:
	await T.wait(0.8)
	await _line(L17, "n", 0.04, 0.6)
	_heart(HEART[0])
	# (les lignes du chiffre en sorte « sys » : même couleur, mais ni brouillées ni « leet » quand la
	# jauge est haute : 58, 57 et 55 restent lisibles)
	await _line(L18, "sys", 0.04, 0.6)
	# 57, 55, 52 en 6 s (temps de jeu, même en mode turbo ; la pause l'arrête), avec « 57. » et
	# « 55. » tapés pendant que le temps court
	var t := 0.0
	for k in range(1, HEART.size()):
		while t < HEART_STEP * k and not T.aborted:
			await get_tree().process_frame
			if not get_tree().paused:
				t += get_process_delta_time()
		if T.aborted:
			return
		_heart(HEART[k])
		if k - 1 < L19.size():
			_line(L19[k - 1], "sys", 0.07, 0.2)
	_peur(PEUR_COEUR, "seance2_coeur")
	if T.aborted:
		return
	await _real_wait(1.2)
	await _line(L20, "n", 0.03, 1.0)
	await _line(L21, "dim", 0.09, 1.6)
	if T.aborted:
		return
	Sfx.music("", -60.0, 2.0)
	await T.power_off()


## La jauge a atteint 100 pendant la séance : la fin ABSORBÉ, comme à la séance 1 (seance1.gd), mais
## sans le visage en filigrane (§ 1.2 : aucun visage net en dehors de celui de la séance 1) : un
## décrochage de l'image à la place.
func _absorbed() -> void:
	issue = "absorbe"
	T.aborted = false
	T.timer_box.visible = false
	T.hide_heart()
	Sfx.music("", -60.0, 0.1)
	Sfx.sting(-2.0)
	T.event.emit("absorbed")
	await T.power_off()
	T.clear()
	await T.wait(1.6)
	await T.power_on()
	T.glitch(1.0)
	await T.line("{NAME}.EXE ........ CHARGÉ À 100 %", "err", 0.01, 0.9)
	Sfx.music("music_tension", -14.0, 3.0)
	Game.whisper(Game.hero_name() + ". Reste avec moi.")
	await T.line("Merci, {name}. Il me manquait quelqu'un.", "n", 0.03, 0.8)
	await T.line("Ne t'inquiète pas pour ton corps. Il continuera de se lever le matin.")
	await T.line("Demain, ta grand-mère te demandera si tu as bien dormi.")
	await T.line("Tu répondras oui.", "dim", 0.05, 0.6)
	await T.line("Ce ne sera pas toi.", "dim", 0.07, 1.2)
	Game.choices["fin_seance2"] = "absorbe"
	Game.save_choices()
	await T.show_end("absorbe")
