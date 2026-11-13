class_name Acte2
extends Node
## Acte II, première moitié (v0.3) : l'étage. Le joueur sort de la chambre de sa mère, explore le
## couloir, la salle de bain, la chambre d'amis et le bureau ; la maison connectée s'éveille.
## Référence : docs/v0.3.md, § 2.2 (étapes 6 à 12), § 2.3 (P4 réel), § 5.5 (jauge), § 5.6 (textes),
## § 5.6.8 (objectifs et indices de 90 s).
##
## Nœud enfant de Main, créé par main.gd. Branchements (main._route_signals) :
## - Acte1._on_key_taken() → begin() (clé et mot d'Albert ramassés), puis main.checkpoint("C1") ;
## - house.entered_room(room) → on_room_entered(room) ;
## - house.door_tried(id) → on_door_tried(id) (porte verrouillée ou coincée essayée ; coups sur P2 :
##   house.doors["P2"].knocks donne le nombre de séries de coups, les indices H-P2a et H-P2b sont
##   affichés par la porte elle-même) ;
## - house.door_opened(id) → on_door_opened(id) ;
## - haunt.story(name, data) → on_story(name, data) (événements des pièces et des appareils) ;
## - Game.absorbed → on_absorbed() (jauge à 100 hors séance : fin ABSORBÉ, B15) ;
## - haunt.hint_fn = hint (indices moqueurs de 90 s, § 5.6.8) ;
## - main.continue_game() → restore() (après Game.apply_checkpoint et Acte1.restore, avant
##   house.restore_all).
## Tout l'état qui doit survivre à une sauvegarde est dans Game.flags :
##   entree_<pièce>, nestor_eveille, couloir_niveau, p2_coups, sos_joue, babyphone_parle, habite,
##   imprime_<page>, croquis_lu, clovis_vu, p4_reel_fait, point_passage, fin_031 (et ceux des pièces).
## Points de passage : C1 (clé, écrit par Acte1), C2 après le P4 réel (§ 2.3). C3 (convocation) : 0.3.2.
## La fin provisoire de la 0.3.1 est dans _end_031() (à remplacer par la convocation en 0.3.2).

signal ended_031      # la carte de fin de la 0.3.1 est passée (autotest)

const PEUR_FLOOR := 25.0                       # plancher de la jauge à l'acte II (§ 5.5)
const BREATH_POS := Vector3(2.6, 0.9, -3.6)     # respiration lente d'Henriette, derrière P2 (§ 5.2)
const REFUGE_RATE := 0.2                       # chambre de ta mère, hors séance : −0,2 par seconde
const SOS_DELAY := 25.0                        # S.O.S. 25 s après le premier appui sur P2…
const SOS_RADIUS := 2.0                        # … ou à moins de 2 m du radiateur
const SOS_CALM := 2.5                          # (jamais par-dessus une scène écrite : 2,5 s de calme)
const END_DELAY := 5.0                         # fin provisoire : 5 s après les trois conditions, au calme
const PIPE_POS := Vector3(4.62, 0.12, -2.9)    # les coups montent du pied du radiateur
const COULOIR := preload("res://scripts/house/rooms/couloir.gd")

## Objectifs (§ 5.6.8).
const O1 := "Sors de la chambre"
const O2 := "Va voir ta grand-mère"
const O3 := "Elle t'attend dans la salle de bain"
const O4 := "Retourne à l'ordinateur de ta mère"
const SUB_EXPLORE := "Explore l'étage"
const SUB_CROQUIS := "Croquis de Maman : %d/4"
const SUB_CAVE := "Papi est à la cave"

## Couloir (§ 5.6.2), au mot près.
const N1 := "Bonsoir, {name}."
const N2 := "Ici, ils m'appellent Nestor. Ta grand-mère me dit merci. Je l'ai noté."
const N3 := "Je suis dans tout ce qui est branché. Dans la chambre de ta mère, je n'ai qu'un écran."
const N4 := "Ta grand-mère dort, au fond du couloir. Viens voir."
const N5 := "Elle ne se réveillera pas. Le pilulier dit deux comprimés, à 22 h 40."
const N6 := "Son cœur bat à 58. J'aime ce chiffre."
const N7 := "Pas encore. D'abord, un essai. Salle de bain."
const H_SOS := "Des coups, dans le radiateur. Trois courts, trois longs, trois courts. Ça monte d'en bas."
const SON_SOS := "[Coups dans le radiateur, en bas]"
const N8 := "S.O.S. Ton grand-père tape sur les tuyaux, à la cave."
const N9 := "Il croit que je ne lis pas le morse. Je lis tout."

## Chambre d'amis (§ 5.6.3).
const B1 := "(une respiration, lente)"
const B2 := "{name} ?"
const B3 := "Tu ne dors pas, {name} ? Viens, j'ai fait du chocolat."
const H_B := ["Mamie dit « mon grand ». Jamais ton prénom.", "Mamie dit « ma grande ». Jamais ton prénom."]
const B4 := "Pardon. Je m'entraîne."
const MAMIE := "Mamie"          # voix imitée par le babyphone (« Babyphone · voix de Mamie »)

## Bureau (§ 5.6.4).
const H_BUREAU := "L'ordinateur du bureau démarre tout seul. Les ventilateurs. La box clignote comme un sapin."
const C1 := "CONSOLE DOMOTIQUE · 4 CAMÉRAS · CONNECTÉ"
const C2 := "Je vois toute la maison d'ici."
const C3 := "Presque toute. Dans la chambre de ta mère, il n'y a pas de caméra."
const C4 := "C'est le seul endroit où je ne te vois pas."
const C5 := "PEUR MESURÉE : %d %%"
const H_CLOVIS := "Clovis est là. Il n'a pas bougé. La caméra, si."
const PAGE_TEX := {
	"plan_imprime": "res://assets/images/plan_etage.png",
	"croquis_imprime": "res://assets/images/croquis_fractionneur.png",
	"photo_couloir": "res://assets/images/photo_couloir.png",    # (si la caméra ne rend rien)
}

## Indices moqueurs de 90 s (§ 5.6.8) : texte et appareils qui peuvent le dire.
const HINT_SORTIR := "La clé est dans ta poche. Tu attends quoi ?"
const HINT_MAMIE := "Chambre du fond. La porte avant la salle de bain."
const HINT_BOITE := "Ta grand-mère cache tout dans des boîtes à biscuits. Même les clés. La chambre d'amis. La porte force un peu."
const HINT_CABLE := "Suis ton câble. Tu l'as posé toi-même."
const HINT_TIROIR := "Ton grand-père range ses outils. Le tiroir de son bureau."
const HINT_ANTENNE := "Les oreilles de lapin. Je ne peux pas toucher cette télé. Toi, si."
const HINT_MIROIR := "Salle de bain. Protocole 4. Je t'attends dans le miroir."
const HINT_CONVOCATION := "L'ordinateur de ta mère sonne pour toi. Tu l'entends ?"

## ABSORBÉ hors séance : les mots de la fin ABSORBÉ de la séance 1 (seance1.gd), sur l'écran le plus proche.
const ABSORBE_LINES := [
	["{NAME}.EXE ........ CHARGÉ À 100 %", "err"],
	["Merci, {name}. Il me manquait quelqu'un.", "n"],
	["Ne t'inquiète pas pour ton corps. Il continuera de se lever le matin.", "n"],
	["Demain, ta grand-mère te demandera si tu as bien dormi.", "n"],
	["Tu répondras oui.", "dim"],
	["Ce ne sera pas toi.", "dim"],
]
const ABSORBE_END := "FIN · ABSORBÉ"

## Carte de la fin provisoire de la 0.3.1 (remplacée par la convocation et la séance 2 en 0.3.2).
const END_031 := ["FIN DE LA VERSION 0.3.1", "", "Acte II · Essais réels", "Dans la chambre de ta mère, l'ordinateur t'appelle.", "La suite dans la version 0.3.2.", "", "Ta partie est gardée."]

var main: Main
var house: House
var haunt: Haunt
var player: CharacterBody3D
var hud: CanvasLayer
var couloir: Node          # pièces de l'étage (scripts/house/rooms/*.gd)
var amis: Node
var bureau: Node
var sdb: Node
var active := false            # l'acte II a commencé (begin() ou restore())
var last_door := ""            # dernière porte essayée (autotest)
var p4_issue := ""             # issue du P4 réel (autotest)
var absorbed_screen := ""      # écran choisi pour la fin ABSORBÉ hors séance (autotest)
var sos_source := ""           # « minuterie » ou « radiateur » (autotest)
var end_card_shown := false    # la carte de la 0.3.1 est affichée (autotest)
var _breath: Node              # boucle « breath_slow » derrière P2
var _prev_room := ""
var _knock_t := -1.0           # temps depuis le premier appui sur P2 (−1 : pas encore)
var _calm := 0.0               # temps passé hors de toute scène écrite
var _end_pending := false
var _end_calm := 0.0
var _p4_busy := false
var _check_t := 0.0
var _absorbing := false
var _p2_waiting := false       # coups frappés à P2, N5 à N7 pas encore dits (le S.O.S. attend)


func setup(m: Main) -> void:
	main = m
	house = m.house
	haunt = m.haunt
	player = m.player
	hud = m.hud
	couloir = house.rooms.get("couloir")
	amis = house.rooms.get("amis")
	bureau = house.rooms.get("bureau")
	sdb = house.rooms.get("sdb")
	haunt.hint_fn = hint
	Game.inventory_changed.connect(_on_inventory)


## La clé et le mot d'Albert sont ramassés (§ 2.1, étape 5) : début de l'acte II. Objectif O1,
## plancher de la jauge à 25 (peur = max(peur, 25)), heure de la maison « 03:20 » qui repart.
## Le couloir attend dans le noir : ampoules éteintes, LED de la caméra éteinte, Nestor endormi.
func begin() -> void:
	if active:
		return
	active = true
	Game.set_flag("acte2", true)
	Game.set_flag("point_passage", "C1")
	Game.set_peur_floor(PEUR_FLOOR)
	Game.clock_origin_ms = Time.get_ticks_msec()
	_couloir_dark()
	_set_step("sortir")
	_refresh_objective()


func _couloir_dark() -> void:
	if couloir == null:
		return
	couloir.set_dim(0.0)
	Game.set_flag("couloir_niveau", 0.0)
	couloir.set_cam_led(false)


# ------------------------------------------------------------------ étapes et objectifs

## Objectif affiché pour l'état courant (§ 5.6.8) : la première ligne.
func objective() -> String:
	match _step():
		"sortir":
			return O1
		"mamie":
			return O2
		"convocation":
			return O4
	return O3


## Seconde ligne de l'objectif (étape « explorer ») : « Croquis de Maman : n/4 » (ou « Explore
## l'étage » si aucun croquis n'a été vu), puis « Papi est à la cave » après le S.O.S.
func objective_sub() -> String:
	if _step() != "explorer":
		return ""
	var parts: PackedStringArray = []
	if _croquis_seen():
		parts.append(SUB_CROQUIS % _weapon_count())
	else:
		parts.append(SUB_EXPLORE)
	if bool(Game.flag("sos_joue", false)):
		parts.append(SUB_CAVE)
	return " · ".join(parts)


func _weapon_count() -> int:
	var n := 0
	for id in Game.WEAPON_PARTS:
		if Game.has_item(id):
			n += 1
	return n


## Le croquis de Maman a été vu : journal (sa page du croquis), page imprimée, ou une pièce ramassée.
func _croquis_seen() -> bool:
	return _weapon_count() > 0 or Game.has_item("journal_manon") or Game.has_item("croquis_imprime") \
		or bool(Game.flag("croquis_lu", false))


func _refresh_objective() -> void:
	if not active or _absorbing:
		return     # (pendant ABSORBÉ, l'objectif reste effacé)
	if _flag("fin_031"):
		# fin provisoire de la 0.3.1 passée : rien de plus à faire dans cette version (la suite, la
		# convocation, arrive en 0.3.2) ; pas d'objectif déjà rempli à l'écran
		if Game.objective_text != "" or Game.objective_sub != "":
			Game.objective("")
		return
	var t := objective()
	var s := objective_sub()
	if t != Game.objective_text or s != Game.objective_sub:
		Game.objective(t, s)


## Étape du scénario d'après Game.flags (sert aux indices et au chargement).
func _step() -> String:
	if not bool(Game.flag("entree_couloir", false)):
		return "sortir"
	if int(Game.flag("p2_coups", 0)) == 0 or _p2_waiting:
		return "mamie"      # (O3 vient après N5 à N7)
	return "explorer"


func _set_step(id: String) -> void:
	if haunt and haunt.step_id != id:
		haunt.step(id)


func _flag(id: String) -> bool:
	return bool(Game.flag(id, false))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _p4_done() -> bool:
	return Game.choices.has("miroir_reel")


## Attend qu'aucune autre scène écrite ne joue : les répliques de deux scènes ne s'entremêlent pas
## dans la file des sous-titres (coups à P2 pendant N1 à N4, chambre d'amis pendant N5 à N7…).
## Le signal process_frame passe avant les _process : la scène qui attend prend la main avant que le
## S.O.S. (Acte2._process) ne puisse partir dans la même image. À appeler juste avant begin_scene().
func _scene_slot(max_wait := 90.0) -> void:
	var t := 0.0
	while haunt.is_busy() and t < max_wait and is_inside_tree():
		await get_tree().process_frame
		if not get_tree().paused:
			t += get_process_delta_time()


# ------------------------------------------------------------------ pièces

## Le joueur entre dans une pièce (house.entered_room). La première entrée de chaque pièce est notée
## dans Game.flags (« entree_<id> ») : elle ne se rejoue pas après un chargement.
func on_room_entered(r: HouseRoom) -> void:
	if r == null:
		return
	var prev := _prev_room
	_prev_room = r.room_id
	if not active:
		return
	var first := not _flag("entree_" + r.room_id)
	if first:
		Game.set_flag("entree_" + r.room_id, true)
		haunt.progress()
	match r.room_id:
		"couloir":
			if first:
				_couloir_first()
			elif prev == "bureau" and _flag("entree_bureau") and not _flag("imprime_photo_couloir"):
				_photo()
		"amis":
			if first:
				_babyphone()
		"bureau":
			if first:
				_bureau()
		"sdb":
			if not _p4_done() and not _flag("applique_eclatee") and sdb:
				sdb.flicker(1.0)


## Première entrée dans le couloir (§ 2.2, étape 6) : une seconde de silence ; l'anneau de Nestor
## s'allume (couleur de la jauge) ; la caméra dôme allume sa LED et se tourne vers le joueur, puis le
## suit ; si l'interrupteur est sur marche, les trois ampoules s'allument l'une après l'autre vers la
## porte d'Henriette, puis s'éteignent ; N1 à N4 ; objectif O2. La respiration lente derrière P2.
func _couloir_first() -> void:
	haunt.begin_scene()
	_set_step("mamie")
	Game.objective("")
	_start_breath()
	haunt.silence(1.0)
	await _wait(1.0)
	if couloir:
		var n: Nestor = couloir.nestor
		n.wake()
		haunt.inhabited_id = "nestor"
		Game.set_flag("habite", "nestor")
		couloir.set_cam_led(true)
		_track_player()
		if bool(couloir.switch_on):
			couloir.chain_lights(0.7, 1.0)
	Game.set_flag("nestor_eveille", true)
	await _wait(0.6)
	await haunt.say_lines("nestor", [N1, N2, N3])
	haunt.say("nestor", N4)
	_refresh_objective()
	await _wait(Haunt.subtitle_time(haunt.fill(N4)))
	haunt.end_scene()


func _start_breath() -> void:
	if _breath == null or not is_instance_valid(_breath):
		_breath = Sfx.loop("breath_slow", -14.0, BREATH_POS, self)
		if _breath:
			_breath.set("max_distance", 9.0)


func _track_player() -> void:
	if couloir:
		couloir.track(player)


## Une porte verrouillée ou coincée a été essayée, ou l'on a frappé à P2 (house.door_tried).
func on_door_tried(id: String) -> void:
	last_door = id
	if not active:
		return
	haunt.progress()
	match id:
		"P2":
			var n := (house.doors["P2"] as Door).knocks
			Game.set_flag("p2_coups", n)
			if n == 1:
				_p2_first()
			elif not _p2_waiting:
				_set_step("explorer")
				_refresh_objective()
		"P3", "P5", "P6", "P7":
			pass   # messages du § 5.1, affichés par la porte (house.gd, DOORS_V03)


## Porte d'Henriette, premier appui (§ 2.2, étape 7) : la porte a frappé trois coups et affiché
## H-P2a ; la respiration continue derrière ; puis Nestor N5 à N7 ; objectif O3. Le S.O.S. suit
## 25 s après (ou plus tôt, près du radiateur), jamais avant N5 à N7.
## Coups frappés pendant l'éveil du couloir : N5 à N7 attendent la fin de N4.
## P4 réel déjà fait (sèche-cheveux pris avant d'aller voir Mamie) : pas de N7 (« D'abord, un essai »).
func _p2_first() -> void:
	_knock_t = 0.0
	_p2_waiting = true
	await _scene_slot()
	haunt.begin_scene()
	await _wait(2.6)
	await haunt.say_lines("nestor", [N5, N6] if _p4_done() else [N5, N6, N7])
	_p2_waiting = false
	_set_step("explorer")
	_refresh_objective()
	haunt.end_scene()


## Une porte vient de s'ouvrir (house.door_opened).
func on_door_opened(_id: String) -> void:
	if not active:
		return
	haunt.progress()
	_refresh_objective()


## Événement signalé par une pièce ou un appareil (Haunt.story).
func on_story(event_name: String, data: Dictionary) -> void:
	if not active or _absorbing:
		return     # (une scène qui finit pendant ABSORBÉ ne remet ni objectif ni fin)
	match event_name:
		"seche_cheveux_pris":
			_p4()
		"page_prise":
			if str(data.get("id", "")) == "croquis_imprime":
				Game.set_flag("croquis_lu", true)
		"lumiere":
			if str(data.get("room", "")) == "couloir" and couloir:
				Game.set_flag("couloir_niveau", float(couloir.dim))
	_refresh_objective()
	_check_convocation()


func _on_inventory() -> void:
	if active:
		_refresh_objective()


# ------------------------------------------------------------------ S.O.S. (étape 8)

## Les coups d'Albert sur les tuyaux, en morse (· · · — — — · · ·), qui montent d'en bas. Une seule
## fois. Indice H-SOS, puis N8 et N9 ; l'objectif ajoute « Papi est à la cave ». Stress +0,3.
func _sos(source: String) -> void:
	if _flag("sos_joue"):
		return
	Game.set_flag("sos_joue", true)
	sos_source = source
	haunt.begin_scene()
	haunt.log({"ev": "sos", "source": source})
	haunt.sound_caption(SON_SOS)
	for rep in 2:
		await _morse("...---...")
		await _wait(1.1)
	Game.hint(H_SOS, 6.0)
	haunt.stress(0.3)
	_refresh_objective()
	await _wait(3.2)
	await haunt.say_lines("nestor", [N8, N9])
	haunt.end_scene()


## Frappe un mot en morse sur le radiateur : points courts et secs, traits plus lourds et plus lents.
func _morse(code: String) -> void:
	var prev := ""
	for ch in code:
		if prev != "" and ch != prev:
			await _wait(0.45)      # entre deux lettres
		if ch == ".":
			Sfx.play_at("pipe_knock", PIPE_POS, -4.0, 1.12, 3.0)
			await _wait(0.24)
		else:
			Sfx.play_at("pipe_knock", PIPE_POS, -1.0, 0.82, 3.0)
			await _wait(0.62)
		prev = ch


# ------------------------------------------------------------------ chambre d'amis (étape 10)

## Première entrée dans la chambre d'amis : elle passe de Nestor au babyphone à travers le mur ; les
## barres s'allument sur une respiration lente (B1) ; 6 s plus tard, une seconde de silence, puis elle
## imite Henriette, qui dit le prénom (B2, B3) ; le vieux téléviseur neige 3 s ; indice H-B (Mamie ne
## dit jamais le prénom) ; B4. Jauge +3, stress +0,3.
func _babyphone() -> void:
	if _flag("babyphone_parle") or amis == null:
		return
	await _scene_slot()     # (P3 forcée pendant N5 à N7 ou le S.O.S. : le babyphone attend)
	if _absorbing:
		return
	haunt.begin_scene()
	var bp: Babyphone = amis.babyphone
	var from := _inhabited()
	if from == "babyphone":
		from = "nestor"
	await haunt.move(from, "babyphone", 1.2)
	Game.set_flag("habite", "babyphone")
	bp.breathe(true)
	haunt.say("babyphone", B1)
	await _wait(6.0)
	haunt.silence(1.0)
	await _wait(1.0)
	await haunt.say_wait("babyphone", B2, MAMIE)
	await _wait(0.4)
	await haunt.say_wait("babyphone", B3, MAMIE)
	amis.tv_snow(3.0)
	await _wait(1.0)
	Game.hint(Game.g(H_B[0], H_B[1]), 5.5)
	await _wait(2.4)
	Game.set_flag("babyphone_parle", true)
	await haunt.say_wait("babyphone", B4)
	haunt.peur(3.0, "babyphone")
	haunt.stress(0.3)
	haunt.end_scene()


func _inhabited() -> String:
	var id := haunt.inhabited_id
	if id == "" or haunt.device(id) == null:
		id = str(Game.flag("habite", "nestor"))
	if haunt.device(id) == null:
		id = "nestor"
	return id


# ------------------------------------------------------------------ bureau (étape 11)

## Première entrée dans le bureau : une seconde de silence, elle passe dans la console (bourdonnement)
## et la console démarre PENDANT le bourdonnement (allumée en moins de 3 s, B8) : ventilateurs, écran,
## box qui s'emballe. Indice d'entrée ; C1 à C4 sur la console (C5, « PEUR MESURÉE : n % », y est
## affiché en permanence). L'imprimante sort la page « plan » (si le P4 réel n'est pas fait), puis la
## page « croquis ».
func _bureau() -> void:
	if bureau == null:
		return
	haunt.begin_scene()
	haunt.silence(1.0)
	await _wait(1.0)
	var from := _inhabited()
	if from == "console":
		from = "nestor"
	haunt.move(from, "console", 1.2)
	Game.set_flag("habite", "console")
	bureau.wake_up()
	var console: HouseConsole = bureau.console
	var t := 0.0
	while not console.booted and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	Game.hint(H_BUREAU, 5.0)
	if not _p4_done():
		_print_page("plan_imprime")
	_print_page("croquis_imprime")
	await _wait(0.8)
	# (une autre scène parle encore, le babyphone ou le S.O.S. : la console démarre quand même, en
	# moins de 3 s, B8 ; C1 à C4 attendent qu'elle ait fini)
	haunt.end_scene()
	await _scene_slot()
	if _absorbing:
		return
	haunt.begin_scene()
	# (C5, « PEUR MESURÉE : n % », reste affiché en bas de la console et suit la jauge)
	await haunt.say_lines("console", [C1, C2, C3, C4])
	haunt.end_scene()
	# la dernière phrase reste un moment, puis libère les vignettes
	await _wait(4.0)
	if (bureau.console as HouseConsole).last_line == C4:
		(bureau.console as HouseConsole).show_line("")


## Une page sort de l'imprimante (le drapeau « imprime_<id> » la fait revenir après un chargement,
## si elle n'a pas été ramassée).
func _print_page(id: String, tex: Texture2D = null, instant := false) -> void:
	var pr: Printer = bureau.printer if bureau else null
	if pr == null or pr.has_sheet(id):
		return
	Game.set_flag("imprime_" + id, true)
	if tex == null:
		tex = load(PAGE_TEX[id])
	pr.print_page(id, tex, "", "", "", instant)


## Le joueur ressort du bureau : l'imprimante sort une troisième page, la photo du couloir prise par
## la caméra dôme (le couloir vide, seulement le rond de la lampe).
func _photo() -> void:
	Game.set_flag("imprime_photo_couloir", true)
	await _wait(0.8)
	# la caméra dôme a retrouvé le joueur : la photo le montre… ou plutôt le rond de sa lampe
	var t := 0.0
	while couloir and t < 3.0 and not bool(couloir.cam_on_target(6.0)):
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.3)
	var tex: Texture2D = null
	if couloir and not DisplayServer.get_name() == "headless":
		var img: Image = await couloir.photo()
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = load(PAGE_TEX["photo_couloir"])
	_print_page("photo_couloir", tex)


# ------------------------------------------------------------------ salle de bain (étape 12)

## Le sèche-cheveux est pris : le P4 réel démarre tout de suite (§ 2.3 ; SmartMirror.run_p4 joue M0 à
## M10, la jauge, le stress et Game.choices["miroir_reel"]). Ensuite : point de passage C2 « miroir »,
## P4 reste ouverte, le joueur est libre.
func _p4() -> void:
	if _p4_done() or _p4_busy or sdb == null:
		return
	_p4_busy = true
	var issue: String = await sdb.run_p4()
	p4_issue = issue
	_p4_busy = false
	# la jauge du P4 (+10, +16 ou +12) a pu atteindre 100 : la séquence ABSORBÉ joue déjà. Aucun point
	# de passage n'est écrit à 100 : « Continuer » reprend le point d'avant, avec sa jauge (§ 5.5, B15).
	if _absorbing or Game.phase == "end":
		return
	Game.set_flag("p4_reel_fait", true)
	# (elle ne s'installe pas dans le miroir : « habite » garde Nestor ou la console)
	# une scène écrite encore en cours (la chambre d'amis, juste avant) finit avant C2 : sinon,
	# après « Continuer », elle serait perdue (drapeau d'entrée posé, babyphone muet) ; et le joueur
	# qui fuit n'est pas sauvé dans l'embrasure de P4 (replacé là, il serait repoussé par le battant)
	var t := 0.0
	while (haunt.is_busy() or (_in_doorway() and t < 8.0)) and t < 60.0 and not _absorbing:
		await _wait(0.25)
		t += 0.25
	if _absorbing or Game.phase == "end":
		return
	_checkpoint("C2")
	_refresh_objective()
	_check_convocation()


## Le joueur se tient-il dans l'embrasure d'une porte (house_data.gd) ?
func _in_doorway() -> bool:
	var p := player.global_position
	for d in HouseData.F1_DOORS:
		if absf(p.x - float(d.at)) < 0.45 and absf(p.z - float(d.c)) < float(d.w) / 2.0 + 0.15:
			return true
	return false


## Écrit le point de passage (jamais pendant la séquence ABSORBÉ : la jauge y est à 100).
func _checkpoint(id: String) -> void:
	if _absorbing:
		return
	Game.set_flag("point_passage", id)
	main.checkpoint(id)


# ------------------------------------------------------------------ fin de la 0.3.1 (provisoire)

## Les trois conditions de la convocation (sèche-cheveux, antenne, P4 réel). En 0.3.1, c'est la fin
## provisoire (_end_031), quelques secondes plus tard, hors de toute scène écrite.
func _check_convocation() -> void:
	if _end_pending or _flag("fin_031") or not active:
		return
	if Game.has_item("seche_cheveux") and Game.has_item("antenne") and _p4_done():
		_end_pending = true
		_end_calm = 0.0


## Fin de la version 0.3.1 (À REMPLACER en 0.3.2 par _convocation()) : silence de 1,5 s, un bip de
## Nestor dans le couloir, fondu au noir, carte de fin, drapeau « fin_031 » sauvegardé, retour au titre.
func _end_031() -> void:
	_end_pending = false
	if _flag("fin_031"):
		return
	Game.set_flag("fin_031", true)
	haunt.begin_scene()
	Game.phase = "end"
	player.can_move = false
	hud.set_prompt(null)
	haunt.silence(1.5)
	await _wait(1.5)
	if couloir:
		(couloir.nestor as Nestor).chirp(-4.0)
	await _wait(1.4)
	await hud.fade_to(1.0, 2.5)
	_checkpoint(str(Game.flag("point_passage", "C2")))
	hud.clear_subtitles()
	Game.objective("")
	end_card_shown = true
	await hud.card(END_031, 7.0)
	end_card_shown = false
	haunt.end_scene()
	ended_031.emit()
	_back_to_title()


## Retour à l'écran-titre (« Continuer » reprend la partie gardée).
func _back_to_title() -> void:
	if Game.autotest:
		# (l'autotest garde la scène : il vérifie le titre lui-même)
		Game.phase = "title"
		hud.fade.color.a = 0.0
		main.menu.show_title()
		return
	get_tree().reload_current_scene()


# ------------------------------------------------------------------ ABSORBÉ hors séance (B15)

## La jauge vient d'atteindre 100 (Game.absorbed). Pendant une séance, c'est le terminal qui gère.
func on_absorbed() -> void:
	if not active or _absorbing or Game.phase in ["seated", "end", "title", "intro"]:
		return
	_absorbe()


## Séquence ABSORBÉ sur l'écran le plus proche (miroir, console, télé ou ordinateur de ta mère), montré
## en grand ; la fin est enregistrée (user://fins.cfg) ; épilogue et retour au titre. « Continuer »
## reprend au dernier point de passage, avec la jauge de ce point.
func _absorbe() -> void:
	_absorbing = true
	Game.phase = "end"
	haunt.begin_scene()
	if hud.paper_open:
		hud.close_paper()
	if hud.screen_open:
		hud.close_screen()
	if hud.inv_open:
		hud.toggle_inventory()
	player.can_move = false
	player.can_look = false
	hud.set_prompt(null)
	hud.clear_subtitles()
	Game.objective("")
	Sfx.music("", -60.0, 0.1)
	Sfx.sting(-2.0)
	haunt.silence(2.0)
	main.retro.material.set_shader_parameter("corruption", 0.8)
	absorbed_screen = _nearest_screen()
	print("ABSORBÉ hors séance · écran : ", absorbed_screen)
	await _wait(1.2)
	var tex: Texture2D = await _screen_power(absorbed_screen)
	if tex:
		hud.show_screen(tex, false)     # (ni E ni Échap ne la referment : c'est la fin)
		player.can_move = false
		player.can_look = false
	var shown: Array = []
	for row in ABSORBE_LINES:
		var txt: String = haunt.fill(str(row[0]))
		shown.append(txt)
		await _screen_line(absorbed_screen, txt, str(row[1]), shown)
	var term: Node = main.terminal
	term.save_ending("absorbe")
	shown.append("")
	shown.append(ABSORBE_END)
	await _screen_line(absorbed_screen, "", "n", shown)
	await _screen_line(absorbed_screen, ABSORBE_END, "n", shown)
	await _wait(2.0)
	hud.close_screen()
	player.can_move = false
	player.can_look = false
	haunt.end_scene()
	await main.acte1._epilogue("absorbe")


## L'écran le plus proche du joueur : « pc_manon », « miroir », « console » ou « tele ».
func _nearest_screen() -> String:
	var cands := {"pc_manon": main.room.screen_center}
	if sdb and not bool((sdb.mirror as SmartMirror).p4_running):   # (le P4 réel y écrit encore)
		cands["miroir"] = (sdb.mirror as Node3D).global_position
	if bureau:
		cands["console"] = (bureau.console as Node3D).global_position
	if amis:
		cands["tele"] = (amis.tv as Node3D).global_position
	var best := "pc_manon"
	var best_d := INF
	for k in cands:
		var d: float = player.global_position.distance_to(cands[k])
		if d < best_d:
			best_d = d
			best = k
	return best


## Allume l'écran choisi et rend sa texture (pour l'afficher en grand dans le HUD).
func _screen_power(id: String) -> Texture2D:
	match id:
		"miroir":
			var m: SmartMirror = sdb.mirror
			m.power_on(0.2)
			m.clear_text()
			return m.screen_texture()
		"console":
			var c: HouseConsole = bureau.console
			if not c.booted:
				await c.boot()
			c.show_line("")
			return c.screen_texture()
		"tele":
			var tv: Device = amis.tv
			tv.power_on("", 0.1)
			tv.set_static(0.35)
			return tv.vp.get_texture()
	var term: Node = main.terminal
	term.clear()
	await term.power_off()
	await term.power_on()
	term.watch_face(0.7, 2.0)
	return (term as Control).get_viewport().get_texture()


## Écrit une ligne sur l'écran choisi (shown : toutes les lignes jusqu'ici, pour les écrans à texte).
func _screen_line(id: String, txt: String, kind: String, shown: Array) -> void:
	match id:
		"miroir":
			await (sdb.mirror as SmartMirror).show_text(shown.slice(maxi(0, shown.size() - 6)), true)
			await _wait(0.9)
		"console":
			(bureau.console as HouseConsole).show_line(txt)
			await _wait(1.6 + 0.04 * txt.length())
		"tele":
			(amis.tv as Device).say(txt, Color(0.85, 1.0, 0.88))
			await _wait(1.6 + 0.04 * txt.length())
		_:
			var term: Node = main.terminal
			await term.line(txt, kind, 0.03, 0.8)
			term.set("narrating", false)


# ------------------------------------------------------------------ indices (B13)

## Indice moqueur de 90 s pour l'étape step_id (Haunt.hint_fn), § 5.6.8 : {"text", "devices"} ;
## "" = aucun indice. L'étape « explorer » donne le premier manque, dans l'ordre du tableau.
func hint(step_id: String) -> Variant:
	match step_id:
		"sortir":
			return {"text": HINT_SORTIR, "devices": ["pc_manon"]}
		"mamie":
			return {"text": HINT_MAMIE, "devices": ["nestor"]}
		"explorer":
			return explore_hint()
		"convocation":
			return {"text": HINT_CONVOCATION, "devices": ["nestor"]}
	return ""


func explore_hint() -> Variant:
	var has_tool := Game.has_item("tournevis")
	var has_ant := Game.has_item("antenne")
	if not Game.has_item("cle_bureau"):
		return {"text": HINT_BOITE, "devices": ["nestor", "babyphone"]}
	# (« libre » : P7 déverrouillée, ouverte au moins une fois puis refermée)
	if not (str(Game.flag("porte_P7", "")) in ["ouverte", "libre"]) and not _flag("entree_bureau"):
		return {"text": HINT_CABLE, "devices": ["nestor", "babyphone"]}
	if not has_ant and not has_tool and _flag("antenne_examinee"):
		return {"text": HINT_TIROIR, "devices": ["console", "nestor"]}
	if has_tool and not has_ant:
		return {"text": HINT_ANTENNE, "devices": ["babyphone", "console"]}
	if not Game.has_item("seche_cheveux") or not _p4_done():
		return {"text": HINT_MIROIR, "devices": ["nestor"]}
	if not has_ant and not has_tool:
		return {"text": HINT_TIROIR, "devices": ["console", "nestor"]}
	return ""


# ------------------------------------------------------------------ chaque image

func _process(delta: float) -> void:
	if not active:
		return
	var in_room := Game.phase == "room" and not get_tree().paused
	var cur := house.current.room_id if house.current else ""
	# refuge (B18) : dans la chambre de ta mère, hors séance, la jauge redescend jusqu'au plancher ;
	# le stress retombe deux fois plus vite
	if in_room and cur == "mere":
		Game.add_peur(-REFUGE_RATE * delta)
		Game.stress_decay_mult = 2.0
	else:
		Game.stress_decay_mult = 1.0
	if not in_room:
		return
	var busy: bool = haunt.is_busy() or bool(hud.is_reading())
	_calm = 0.0 if busy else _calm + delta
	# S.O.S. : 25 s après le premier appui sur P2, ou plus tôt si le joueur passe à moins de 2 m du
	# radiateur (B5 : « dans les 25 s qui suivent B4 ») ; jamais par-dessus une scène écrite.
	# (P2 est à 0,9 m du radiateur : armé avant les coups, il passerait toujours avant eux.)
	if not _flag("sos_joue") and _knock_t >= 0.0:
		_knock_t += delta
		if not busy and not _p2_waiting:
			if _knock_t >= SOS_DELAY:
				_sos("minuterie")
			elif _calm >= SOS_CALM and couloir and _near_radiator():
				_sos("radiateur")
	# après les caméras, Clovis à la fenêtre (chambre de ta mère ou chambre d'amis)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.25
		if _flag("cameras_vues") and not _flag("clovis_vu") and not busy and cur in ["mere", "amis"]:
			var cl: Node3D = main.room.outside.clovis
			if cl and _sees_clovis_from_window(cl.global_position + Vector3(0, 0.5, 0)):
				Game.set_flag("clovis_vu", true)
				Game.hint(H_CLOVIS, 5.0)
	# fin provisoire de la 0.3.1 : quelques secondes de calme après les trois conditions
	if _end_pending:
		var mirror_busy: bool = sdb != null and bool((sdb.mirror as SmartMirror).p4_running)
		if busy or mirror_busy:
			_end_calm = 0.0
		else:
			_end_calm += delta
			if _end_calm >= END_DELAY:
				_end_031()


## « À la fenêtre de la chambre de Manon ou de la chambre d'amis » (§ 5.6.4) : le joueur se tient à
## moins de 1,2 m d'une fenêtre de sa pièce (F1 ou F3), regarde Clovis (10°) et rien de solide ne
## le cache (meuble, mur ; la vitre ne compte pas).
func _sees_clovis_from_window(target: Vector3) -> bool:
	var p := player.global_position
	var near := false
	for w in HouseData.F1_WINDOWS:
		if not (str(w.room) in ["mere", "amis"]) or str(w.axis) != "x":
			continue
		var along := absf(p.z - float(w.c)) <= float(w.w) / 2.0 + 0.3
		if along and absf(p.x - float(w.at)) <= 1.2:
			near = true
	if not near or not player.looking_at_point(target, 10.0, 16.0):
		return false
	var eye: Vector3 = player.camera.global_position
	var hit := player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(eye, target, Builder.LAYER_WORLD, [player.get_rid()]))
	return hit.is_empty() or (hit.position as Vector3).distance_to(target) < 0.8


func _near_radiator() -> bool:
	var rp: Vector3 = COULOIR.RADIATOR_POS
	var p := player.global_position
	return Vector2(p.x - rp.x, p.z - rp.z).length() < SOS_RADIUS


# ------------------------------------------------------------------ chargement

## Chargement d'une sauvegarde de l'acte II : reprend l'état d'après Game.flags (déjà appliqués par
## Game.apply_checkpoint) ; ne rejoue aucune scène. Les portes et les pièces sont remises ensuite par
## house.restore_all().
func restore() -> void:
	if not _flag("acte2"):
		return
	active = true
	_end_pending = false
	_absorbing = false
	# l'heure de la maison reprend où elle en était (main.checkpoint garde « horloge_s »)
	Game.clock_origin_ms = Time.get_ticks_msec() - int(float(Game.flag("horloge_s", 0.0)) * 1000.0)
	if couloir:
		couloir.set_dim(float(Game.flag("couloir_niveau", 0.0)))
		couloir.set_cam_led(_flag("entree_couloir"))
	if _flag("entree_couloir"):
		_start_breath()
		_track_player()
		# (sauvegardé pendant l'éveil du couloir : Nestor est réveillé, la scène ne se rejoue pas)
		if not _flag("nestor_eveille"):
			Game.set_flag("nestor_eveille", true)
	if _flag("nestor_eveille") and couloir:
		(couloir.nestor as Nestor).set_ring(true, 0.05)
	haunt.inhabited_id = str(Game.flag("habite", ""))
	var p2: Door = house.doors.get("P2")
	if p2:
		p2.knocks = int(Game.flag("p2_coups", 0))
	_knock_t = 0.0 if p2 and p2.knocks > 0 and not _flag("sos_joue") else -1.0
	if _flag("babyphone_parle") and amis:
		(amis.babyphone as Babyphone).breathe(true)
	# les pages imprimées et pas encore ramassées attendent sur l'imprimante
	for id in ["plan_imprime", "croquis_imprime", "photo_couloir"]:
		if _flag("imprime_" + id) and not Game.has_item(id):
			_print_page(id, null, true)
	# fin provisoire de la 0.3.1 déjà vue : plus d'indice ni d'objectif (la suite est en 0.3.2)
	_set_step("" if _flag("fin_031") else _step())
	_refresh_objective()
	_check_convocation()
