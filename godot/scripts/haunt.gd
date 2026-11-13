class_name Haunt
extends Node
## L'entité dans la maison (S.1.L.3.N.C.3.) : le SEUL point d'entrée de ce qu'elle fait hors de
## l'écran de Manon. Parler par un appareil (sous-titre + bips de données), se déplacer d'un appareil à
## l'autre (bourdonnement qui traverse les murs, ampoules qui vacillent sur le trajet), faire silence
## (elle va agir), changer la jauge, donner un indice moqueur au bout de 90 s sans progrès.
## Les pièces lui signalent ce qui arrive (story_event) ; le scénario écoute le signal « story ».
## Tout est noté dans un journal en mémoire (journal), consultable par l'autotest.
## Le directeur de la v0.5 se branchera ici, sans toucher aux pièces.
##
## C'est aussi ici que passent :
## - le stress léger (C4) : chaque scène écrite (begin_scene), chaque silence de l'entité, chaque
##   sursaut (Sfx.sting, réactions de la séance par terminal.event, sursauts du P4) et certains
##   événements de pièce (story_event, table STORY_STRESS) donnent une impulsion de stress (stress()) :
##   le cœur s'entend (> −20 dB), puis retombe sous −36 dB en moins de 12 s au calme. Chaque impulsion
##   est suivie dans stress_pulses (crête et temps de retour au calme) ; c4_report() résume ;
## - les sous-titres des sons importants (C5, sound_caption, seulement avec l'option), y compris les
##   coups aux portes (P2, séance 1) et le bourdonnement qui traverse les murs ;
## - le journal des temps (C9) : chaque changement d'étape (step) écrit une ligne dans
##   user://journal.txt (heure réelle, temps depuis l'étape précédente et depuis le début).
##
## Accès : Haunt.of(get_tree()) (le nœud est dans le groupe « haunt », créé par main.gd).
## Attention : à l'intérieur de ce script, appeler self.log(...) (log() seul est la fonction
## mathématique de Godot) ; de l'extérieur, haunt.log(...) marche normalement.

signal story(name: String, data: Dictionary)       # événement de scénario (« seche_cheveux_pris »…)
signal spoke(dev_id: String, text: String, who: String)
signal moved(from_id: String, to_id: String)
signal hint_due(step_id: String)                    # 90 s sans progrès (avant l'indice éventuel)
signal logged(event: Dictionary)

const HINT_DELAY := 90.0
const BULB_RADIUS := 2.0          # les ampoules à moins de 2 m du trajet vacillent
const HUM_CAPTION := "[Bourdonnement électrique, qui traverse le mur]"
## Coups frappés à une porte (P2 « Frapper à la porte » ; la porte de la chambre pendant la séance 1).
const KNOCK_CAPTION := "[Trois coups à la porte]"
## Sous-titres de sons des réactions de la chambre pendant les séances (terminal.event).
const TERM_CAPTIONS := {"knock": KNOCK_CAPTION, "handle": "[La poignée de la porte tourne]"}

# --- stress léger (C4) ---
const STRESS_PULSE_MIN := 0.35    # après une impulsion, le stress vaut au moins 0,35 (cœur à −15 dB)
const STRESS_SCENE := 0.3         # début d'une scène écrite (begin_scene)
const STRESS_SILENCE := 0.25      # une seconde de silence : elle va agir (le cœur, seul dans le silence)
const STRESS_STING := 0.5         # sursaut (Sfx.sting)
const STRESS_HINT := 0.3          # indice moqueur au bout de 90 s (elle parle d'un coup)
## Événements de pièce (story_event) qui touchent le joueur ; négatif : ça calme. Les autres
## (tiroir ouvert, page ramassée, lumière…) sont les gestes du joueur : rien.
const STORY_STRESS := {
	"camera_led_eteinte": 0.3,    # la caméra éteint sa LED : elle sait que tu sais
	"box_debranchee": 0.3,        # la box se rallume toute seule (la première fois)
	"page_imprimee": 0.3,         # l'imprimante démarre toute seule
	"nestor_debranche": 0.25,     # l'anneau reste allumé
	"madeleine_mangee": -0.3,     # « Ça va un peu mieux. »
}
## Réactions de la chambre pendant les séances (signal terminal.event) ; défaut : TERM_STRESS_DEFAULT.
const TERM_STRESS := {
	"knock": 0.35, "handle": 0.35, "wardrobe": 0.3, "silhouette": 0.3, "ceiling_on": 0.25,
	"ceiling_burst": 0.5, "scream": 0.6, "absorbed": 0.6, "undawn": 0.4, "dawn": -0.4,
}
const TERM_STRESS_DEFAULT := 0.3
const C4_PEAK_WINDOW := 1.5       # la crête du cœur est cherchée dans les 1,5 s qui suivent l'impulsion

# --- journal des temps (C9) ---
const TIMES_PATH := "user://journal.txt"
const TIMES_PATH_TEST := "user://journal_autotest.txt"   # l'autotest n'écrase jamais celui du joueur

var devices := {}                 # device_id -> Connected
var journal: Array = []           # [{t, ev, …}]
## Le premier bourdonnement est sous-titré même sans l'option (§ 6.4). Haunt est recréé à chaque
## chargement : c'est le premier de la session (après « Continuer », il l'est de nouveau, exprès).
var _hum_captioned := false
var inhabited_id := ""            # l'appareil où elle est
var room_id := ""                 # pièce du joueur (dernier room_changed)
var step_id := ""                 # étape du scénario (pour les indices)
var hint_delay := HINT_DELAY
var hint_speed := 1.0             # ×30 avec --indices
## Fournisseur des indices : func(step_id) -> String, ou {"text": String, "devices": [ids]}.
## Si le texte est vide, aucun indice n'est donné.
var hint_fn: Callable
var hints_given := 0
var _busy := 0
var _idle := 0.0
var _t0 := 0
## C4 : une entrée par impulsion de stress, dans l'ordre : {t (s de jeu), why, v, stress, peak_db (crête de
## Sfx.heart_db dans les 1,5 s), calm_s (temps jusqu'à Sfx.heart_db < −36 dB ; −1 tant que ce n'est pas
## arrivé), relayed (une autre impulsion est venue avant le calme : pas de mesure de retour)}.
var stress_pulses: Array = []
var _game_t := 0.0
var _knocks_seen := {}
## C9 : lignes écrites dans le journal des temps par cette scène (copie en mémoire, pour l'autotest).
var times_lines: Array = []
var _times_open := false          # le journal a été ouvert (nouvelle partie ou reprise) dans cette scène
var _times_new_ms := -100000      # heure où il a été remis à zéro dans cette scène (nouvelle partie)
var _times_origin_ms := 0         # début de la partie, ramené à cette session (temps cumulé)
var _times_last_ms := 0           # heure de la dernière étape (ou de la reprise)
var _times_last_step := ""


## Le Haunt de la scène (ou null).
static func of(tree: SceneTree) -> Haunt:
	return tree.get_first_node_in_group("haunt") as Haunt


## Durée d'affichage d'un sous-titre : 2 s + 0,06 s par caractère.
static func subtitle_time(text: String) -> float:
	return 2.0 + 0.06 * text.length()


func _enter_tree() -> void:
	add_to_group("haunt")


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	if Game.indices:
		hint_speed = 30.0
	Sfx.silenced.connect(_on_silenced)
	Sfx.stung.connect(_on_stung)
	Game.flag_changed.connect(_on_flag_changed)
	_late_setup.call_deferred()


func _late_setup() -> void:
	for n in get_tree().get_nodes_in_group("connecte"):
		register(n as Connected)
	# les caméras de flux ne tournent que dans la pièce où l'on regarde leur image
	var scene := get_tree().current_scene
	var house: Variant = scene.get("house") if scene else null
	if house is Node and (house as Node).has_signal("entered_room"):
		(house as Node).connect("entered_room", func(r: Node) -> void: room_changed(str(r.get("room_id"))))
		var cur: Variant = (house as Node).get("current")
		if cur is Node:
			room_changed(str((cur as Node).get("room_id")))
	Game.absorbed.connect(_on_absorbed)
	# coups frappés aux portes (P2 « Frapper à la porte ») : sous-titre de son
	var doors: Variant = (house as Node).get("doors") if house is Node else null
	if doors is Dictionary:
		for id in doors:
			var dr: Node = doors[id] as Node
			var it: Variant = dr.get("it") if dr else null
			if it is Interactable:
				(it as Interactable).used.connect(_on_door_used.bind(dr, str(id)))
	# réactions de la chambre pendant les séances : stress et sous-titres de sons
	var term: Variant = scene.get("terminal") if scene else null
	if term is Node and (term as Node).has_signal("event"):
		(term as Node).connect("event", _on_term_event)
	# « Nouvelle partie » : le journal des temps repart de zéro
	var menu: Variant = scene.get("menu") if scene else null
	if menu is Node and (menu as Node).has_signal("start_requested"):
		(menu as Node).connect("start_requested", times_new_game)


# ------------------------------------------------------------------ appareils

func register(dev: Connected) -> void:
	if dev == null or dev.device_id == "":
		return
	if devices.get(dev.device_id) == dev:
		return
	if devices.has(dev.device_id) and is_instance_valid(devices[dev.device_id]):
		print("Haunt : identifiant d'appareil en double « %s »" % dev.device_id)
	devices[dev.device_id] = dev
	dev.haunt = self
	self.log({"ev": "register", "dev": dev.device_id, "room": dev.room_id})


func device(id: String) -> Connected:
	var d: Variant = devices.get(id)
	if d != null and is_instance_valid(d):
		return d as Connected
	# pas encore enregistré (posé dans la même image) : on le cherche
	for n in get_tree().get_nodes_in_group("connecte"):
		var c := n as Connected
		if c and c.device_id == id:
			register(c)
			return c
	return null


func devices_in(room: String) -> Array:
	var out: Array = []
	for id in devices:
		var d: Connected = device(id)
		if d and d.room_id == room:
			out.append(d)
	return out


func _player() -> Node3D:
	var scene := get_tree().current_scene
	var p: Variant = scene.get("player") if scene else null
	return p as Node3D


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


## L'appareil qui parle le plus proche du joueur (parmi « among » si la liste n'est pas vide).
func nearest(among: Array = [], speaking_only := true) -> Connected:
	var p := _player()
	var best: Connected = null
	var best_d := INF
	for id in devices:
		if not among.is_empty() and not among.has(id):
			continue
		var d: Connected = device(id)
		if d == null or not d.is_inside_tree() or (speaking_only and not d.can_speak):
			continue
		var dist := 0.0 if p == null else p.global_position.distance_to(d.speak_pos())
		if dist < best_d:
			best_d = dist
			best = d
	return best


# ------------------------------------------------------------------ ce qu'elle fait

## Remplace {name}, {NAME}, {masculin|féminin} et « 03:2x » (heure de la maison).
func fill(text: String) -> String:
	var nm := Game.hero_name()
	var s := text.replace("{name}", nm).replace("{NAME}", nm.to_upper()).replace("03:2x", Game.house_clock())
	var re := RegEx.create_from_string("\\{([^|{}]*)\\|([^|{}]*)\\}")
	for m in re.search_all(s):
		s = s.replace(m.get_string(0), Game.g(m.get_string(1), m.get_string(2)))
	return s


## Elle parle par l'appareil dev_id : sous-titre (« Nestor : … », vert phosphore ; « Babyphone · voix
## de Mamie : … » en beige quand elle imite), bips de données et animation de l'appareil quand la ligne
## s'affiche, chuchotement Windows en option. Renvoie le temps (s) jusqu'à la fin de la ligne
## (file d'attente comprise) ; await haunt.say_wait(...) pour attendre.
func say(dev_id: String, text: String, who := "elle", whisper := true) -> float:
	var dev := device(dev_id)
	var t := fill(text)
	var label: String = dev.display_name if dev and dev.display_name != "" else dev_id.capitalize()
	if who != "elle" and who != "":
		label += " · voix de " + who
	var dur := subtitle_time(t)
	var kind := "elle" if who == "elle" or who == "" else "proche"
	var show := func() -> void: _voice(dev, t, dur, whisper)
	var hud := _hud()
	var total := dur
	if hud and hud.has_method("subtitle"):
		total = hud.subtitle(label, t, kind, show)
	else:
		show.call()
	self.log({"ev": "say", "dev": dev_id, "text": t, "who": who})
	spoke.emit(dev_id, t, who)
	return total


func say_wait(dev_id: String, text: String, who := "elle") -> void:
	var d := say(dev_id, text, who)
	await get_tree().create_timer(d, false).timeout


## Plusieurs lignes à la suite par le même appareil (N1 à N4…), en attendant chacune.
func say_lines(dev_id: String, lines: Array, who := "elle", gap := 0.35) -> void:
	for l in lines:
		await say_wait(dev_id, str(l), who)
		if gap > 0.0:
			await get_tree().create_timer(gap, false).timeout


## Par l'appareil qui parle le plus proche du joueur (indices). Renvoie son identifiant ("" si aucun).
func say_nearest(text: String, who := "elle", among: Array = []) -> String:
	var d := nearest(among)
	if d == null and not among.is_empty():
		d = nearest()
	if d == null:
		Game.hint(fill(text), subtitle_time(text))
		self.log({"ev": "say", "dev": "", "text": fill(text), "who": who})
		return ""
	say(d.device_id, text, who)
	return d.device_id


func _voice(dev: Connected, text: String, dur: float, whisper: bool) -> void:
	if dev and is_instance_valid(dev):
		dev.speak(text, dur)
		var pos := dev.speak_pos()
		var n := clampi(text.length() / 14, 2, 6)
		for i in n:
			var delay := (dur * 0.7) * float(i) / n + randf_range(0.0, 0.12)
			get_tree().create_timer(delay, false).timeout.connect(func() -> void:
				Sfx.voice_at("chirp", pos, -12.0, randf_range(0.85, 1.2), 1.6))
	if whisper:
		Game.whisper(text)


## Sous-titre d'un son important (« [Coups dans le radiateur, en bas] ») : affiché seulement si
## l'option « Sous-titres des sons » est active (C5) ; force = true est réservé aux captures de test.
## Les dialogues (say) et les pensées du héros (Game.hint), eux, s'affichent toujours.
## Le journal note {"ev": "son", "text", "shown"} (shown : le sous-titre a été affiché).
func sound_caption(text: String, force := false) -> void:
	var hud := _hud()
	var shown := 0.0
	if hud and hud.has_method("sound_caption"):
		shown = float(hud.sound_caption(text, force))
	self.log({"ev": "son", "text": text, "shown": shown > 0.0})


## Elle se déplace de from_id à to_id : bourdonnement en ligne droite à travers les murs, les
## ampoules connectées à moins de 2 m du trajet vacillent. await haunt.move(...) attend l'arrivée.
func move(from_id: String, to_id: String, sec := 1.2) -> void:
	var a := device(from_id)
	var b := device(to_id)
	if a == null or b == null:
		print("Haunt.move : appareil inconnu « %s » ou « %s »" % [from_id, to_id])
		return
	var pa := a.speak_pos()
	var pb := b.speak_pos()
	Sfx.hum_move(pa, pb, sec)
	# § 6.4 : le bourdonnement est toujours sous-titré à sa première occurrence (sinon il n'est pas
	# compris) ; ensuite, seulement avec l'option « Sous-titres des sons » (C5)
	sound_caption(HUM_CAPTION, not _hum_captioned)
	_hum_captioned = true
	for n in get_tree().get_nodes_in_group("connecte"):
		var bulb := n as SmartBulb
		if bulb and bulb.is_inside_tree() and _seg_dist(bulb.global_position, pa, pb) < BULB_RADIUS:
			bulb.flicker(sec + 0.25)
	a.on_leave()
	inhabited_id = to_id
	self.log({"ev": "move", "from": from_id, "to": to_id, "sec": sec})
	moved.emit(from_id, to_id)
	await get_tree().create_timer(sec, false).timeout
	if is_instance_valid(b):
		b.on_enter()


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var k := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * k)


## Une seconde de silence total (pluie, musique, souffle coupés) : elle va agir.
func silence(sec := 1.0) -> void:
	Sfx.silence(sec)
	self.log({"ev": "silence", "sec": sec})


## Change la PEUR MESURÉE (négatif pour la faire baisser) ; « why » est noté au journal.
func peur(v: float, why := "") -> void:
	Game.add_peur(v, why)
	self.log({"ev": "peur", "v": v, "why": why, "peur": Game.peur})


## Impulsion de stress caché (cœur, grain) : +0,3 imitation, S.O.S., caméras ; +0,5 P4 réel, chant du
## modem ; +0,6 applique qui éclate (§ 5.5). Une impulsion positive laisse le stress à au moins
## STRESS_PULSE_MIN : le cœur s'entend toujours après un événement écrit (C4). Négatif : ça calme.
func stress(v: float, why := "") -> void:
	Game.add_stress(v, STRESS_PULSE_MIN if v > 0.0 else 0.0)
	Sfx.refresh_heart()
	self.log({"ev": "stress", "v": v, "why": why, "stress": snappedf(Game.stress, 0.001)})
	if v > 0.0:
		_track_pulse(v, why)


## Événement de scénario signalé par une pièce ou un appareil (« seche_cheveux_pris »,
## « antenne_prise », « porte_essayee »…). Le scénario écoute le signal « story ».
func story_event(event_name: String, data := {}) -> void:
	var e := {"ev": "story", "name": event_name}
	e.merge(data)
	self.log(e)
	progress()
	if STORY_STRESS.has(event_name) and bool(data.get("premiere", true)):
		stress(float(STORY_STRESS[event_name]), event_name)
	story.emit(event_name, data)


## Note un événement au journal (String ou Dictionary avec la clé « ev »).
func log(event: Variant) -> void:
	var e: Dictionary
	if event is Dictionary:
		e = (event as Dictionary).duplicate()
	else:
		e = {"ev": str(event)}
	e["t"] = snappedf((Time.get_ticks_msec() - _t0) / 1000.0, 0.01)
	journal.append(e)
	if Game.autotest and e.get("ev") != "register":
		print("HAUNT ", e)
	logged.emit(e)


## Nombre d'événements du journal de type « ev » (et dont data[key] == value, si key est donné).
func count(ev: String, key := "", value: Variant = null) -> int:
	var n := 0
	for e in journal:
		if e.get("ev") != ev:
			continue
		if key != "" and e.get(key) != value:
			continue
		n += 1
	return n


func has_logged(ev: String, key := "", value: Variant = null) -> bool:
	return count(ev, key, value) > 0


## Textes dits (dans l'ordre), éventuellement par un seul appareil.
func said(dev_id := "") -> Array:
	var out: Array = []
	for e in journal:
		if e.get("ev") == "say" and (dev_id == "" or e.get("dev") == dev_id):
			out.append(e.get("text"))
	return out


# ------------------------------------------------------------------ pièces et caméras de flux

## Le joueur entre dans une pièce : seules les caméras de flux regardées depuis cette pièce tournent.
func room_changed(id: String) -> void:
	room_id = id
	for n in get_tree().get_nodes_in_group("feed_cam"):
		var cam := n as FeedCam
		if cam:
			cam.set_room(id)
	self.log({"ev": "piece", "room": id})


# ------------------------------------------------------------------ indices de 90 s

## Étape du scénario (« sortir », « mamie », « explorer », « convocation »…) : remet le compteur à zéro.
## Un changement d'étape écrit une ligne dans le journal des temps (C9).
func step(id: String) -> void:
	var changed := id != step_id
	step_id = id
	_idle = 0.0
	self.log({"ev": "etape", "step": id})
	if changed:
		_times_step(id)


## Le joueur a progressé : le compteur des indices repart de zéro.
func progress() -> void:
	_idle = 0.0


## Scène écrite en cours : pas d'indice (à appeler par paires). Le cœur du héros s'emballe (C4).
func begin_scene() -> void:
	_busy += 1
	stress(STRESS_SCENE, "scène")


func end_scene() -> void:
	_busy = maxi(0, _busy - 1)
	_idle = 0.0


func is_busy() -> bool:
	return _busy > 0


func _reading() -> bool:
	var hud := _hud()
	if hud == null:
		return false
	if hud.has_method("is_reading"):
		return hud.is_reading()
	return bool(hud.get("paper_open"))


func _process(delta: float) -> void:
	_watch_pulses(delta)
	if step_id == "" or _busy > 0 or Game.phase != "room" or _reading():
		return
	_idle += delta * hint_speed
	if _idle < hint_delay:
		return
	_idle = 0.0
	hint_due.emit(step_id)
	if not hint_fn.is_valid():
		return
	var r: Variant = hint_fn.call(step_id)
	var text := ""
	var among: Array = []
	if r is String:
		text = r
	elif r is Dictionary:
		text = str((r as Dictionary).get("text", ""))
		among = (r as Dictionary).get("devices", [])
	if text == "":
		return
	var id := say_nearest(text, "elle", among)
	peur(1.0, "indice")
	stress(STRESS_HINT, "indice")
	hints_given += 1
	self.log({"ev": "indice", "step": step_id, "dev": id, "text": fill(text)})


# ------------------------------------------------------------------ stress léger (C4)

func _on_silenced(seconds: float) -> void:
	stress(STRESS_SILENCE, "silence %.1f s" % seconds)


func _on_stung(_db: float) -> void:
	stress(STRESS_STING, "sursaut")


## Réaction de la chambre pendant une séance (terminal.event) : stress, et sous-titre de son.
func _on_term_event(what: String) -> void:
	var v: float = float(TERM_STRESS.get(what, TERM_STRESS_DEFAULT))
	stress(v, "séance : " + what)
	if TERM_CAPTIONS.has(what):
		sound_caption(str(TERM_CAPTIONS[what]))


## Une porte qu'on « frappe » (P2) : le sous-titre des coups (une fois par série de coups).
func _on_door_used(_it: Interactable, dr: Node, id: String) -> void:
	if not is_instance_valid(dr):
		return
	var n := int(dr.get("knocks"))
	if n > int(_knocks_seen.get(id, 0)):
		_knocks_seen[id] = n
		sound_caption(KNOCK_CAPTION)


func _on_absorbed() -> void:
	self.log({"ev": "absorbe", "peur": Game.peur})
	_times_event("ABSORBÉ (jauge à 100)")


func _track_pulse(v: float, why: String) -> void:
	for e in stress_pulses:
		if float(e.calm_s) < 0.0:
			e.relayed = true
	# (Sfx vient d'appliquer le volume de ce stress : c'est la première mesure ; puis les images suivantes)
	stress_pulses.append({"t": _game_t, "frame": Engine.get_process_frames(), "why": why, "v": v,
		"stress": snappedf(Game.stress, 0.001), "peak_db": Sfx.heart_db, "calm_s": -1.0, "relayed": false})
	if stress_pulses.size() > 500:
		stress_pulses.pop_front()


## Suit les impulsions (en temps de jeu : le mode turbo et la pause sont respectés) : crête du cœur
## dans les 1,5 s qui suivent, puis le moment où il repasse sous −36 dB.
func _watch_pulses(delta: float) -> void:
	_game_t += delta
	var frame := Engine.get_process_frames()
	for i in range(stress_pulses.size() - 1, -1, -1):
		var e: Dictionary = stress_pulses[i]
		var age := _game_t - float(e.t)
		if int(e.frame) >= frame:
			continue
		# (la première image d'après compte toujours : une image très longue, en rendu logiciel,
		# peut sauter toute la fenêtre de 1,5 s)
		if age <= C4_PEAK_WINDOW or not e.has("seen"):
			e.peak_db = maxf(float(e.peak_db), Sfx.heart_db)
			e.seen = true
		elif bool(e.relayed) and not e.has("printed"):
			e.printed = true
			if Game.autotest:
				print("C4 impulsion « %s » à %.1f s : crête %.1f dB, relayée avant le calme" % [e.why, e.t, e.peak_db])
		elif i < stress_pulses.size() - 2:
			break
	if stress_pulses.is_empty():
		return
	var last: Dictionary = stress_pulses[-1]
	var last_age := _game_t - float(last.t)
	if float(last.calm_s) < 0.0 and not bool(last.relayed) and int(last.frame) < frame and Sfx.heart_db < Sfx.HEART_CALM_DB:
		last.calm_s = snappedf(last_age, 0.01)
		last.printed = true
		if Game.autotest:
			print("C4 impulsion « %s » à %.1f s : crête %.1f dB, sous −36 dB après %.1f s" % [last.why, last.t, last.peak_db, last.calm_s])


## Résumé C4 depuis l'impulsion n° « from » : {n, peak_min (dB), calm_max (s), measured (retours au calme
## mesurés), open (pas encore retombée, sans relais), fails ([textes]), ok}. Critère : chaque crête
## > −20 dB ; chaque retour au calme mesuré < 12 s. (Une impulsion relayée n'a pas de retour à mesurer.)
func c4_report(from := 0) -> Dictionary:
	var n := 0
	var peak_min := 0.0
	var calm_max := 0.0
	var measured := 0
	var open := 0
	var fails: Array = []
	for i in range(from, stress_pulses.size()):
		var e: Dictionary = stress_pulses[i]
		n += 1
		var pk := float(e.peak_db)
		peak_min = pk if n == 1 else minf(peak_min, pk)
		if pk <= Sfx.HEART_AUDIBLE_DB and _game_t - float(e.t) > C4_PEAK_WINDOW:
			fails.append("%s à %.1f s : crête %.1f dB" % [e.why, e.t, pk])
		if float(e.calm_s) >= 0.0:
			measured += 1
			calm_max = maxf(calm_max, float(e.calm_s))
			if float(e.calm_s) >= 12.0:
				fails.append("%s à %.1f s : calme après %.1f s" % [e.why, e.t, e.calm_s])
		elif not bool(e.relayed):
			open += 1
			if _game_t - float(e.t) >= 12.0:
				fails.append("%s à %.1f s : pas retombé en 12 s" % [e.why, e.t])
	return {"n": n, "peak_min": peak_min, "calm_max": calm_max, "measured": measured, "open": open,
		"fails": fails, "ok": n > 0 and fails.is_empty()}


# ------------------------------------------------------------------ journal des temps (C9)

## Le fichier du journal des temps (celui de l'autotest est à part).
static func times_path() -> String:
	return TIMES_PATH_TEST if Game.autotest else TIMES_PATH


## « Nouvelle partie » (menu.start_requested, ou appel direct) : le journal repart de zéro.
func times_new_game() -> void:
	if _times_open and Time.get_ticks_msec() - _times_new_ms < 5000:
		return      # (déjà remis à zéro pour cette partie, par sa première étape : rien à refaire)
	_times_begin(false)


## « Continuer » : le journal continue (le temps depuis le début reprend où il s'était arrêté).
## Appelée toute seule par la première étape remise en place pendant le chargement (_restoring()).
func times_resume() -> void:
	if not _times_open:
		_times_begin(true)


func _times_begin(resume: bool) -> void:
	var now := Time.get_ticks_msec()
	var base_s := _times_previous_total() if resume else 0.0
	_times_open = true
	_times_origin_ms = now - int(base_s * 1000.0)
	_times_last_ms = now
	_times_last_step = ""
	times_lines.clear()
	var d := Time.get_datetime_dict_from_system()
	var date := "%02d/%02d/%04d à %02d:%02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute, d.second]
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if resume:
		var cp := str(Game.load_checkpoint().get("checkpoint", "?"))
		if FileAccess.file_exists(times_path()):
			_times_write("", false)
		else:
			# (première reprise d'une partie commencée sans journal, par exemple en 0.3.1 : le temps
			# joué avant est inconnu ; « depuis le début » compte depuis cette reprise)
			_times_write("Don't Play %s · journal des temps · partie reprise le %s · %s · temps joué avant : inconnu" % [
				version, date, Game.hero_name()], true)
		_times_write("%s · reprise (« Continuer ») au point de passage %s, le %s · %s depuis le début" % [
			_clock(), cp, date, _duration(base_s)], false)
	else:
		_times_new_ms = now
		_times_write("Don't Play %s · journal des temps · nouvelle partie le %s · %s" % [version, date, Game.hero_name()], true)
		_times_write("%s · début de la partie" % _clock(), false)


## Une étape posée pendant le chargement d'une sauvegarde (« Continuer ») : Game.phase vaut encore
## « title », la sauvegarde existe et ses drapeaux sont déjà rendus. (« Nouvelle partie » efface la
## sauvegarde et les drapeaux avant sa première étape, posée elle aussi pendant « title ».)
static func _restoring() -> bool:
	return Game.phase == "title" and not Game.flags.is_empty() and Game.has_save()


func _times_step(id: String) -> void:
	var restoring := _restoring()
	if not _times_open:
		if restoring:
			times_resume()           # étape remise en place par « Continuer »
		else:
			_times_begin(false)      # première étape d'une partie neuve
	var now := Time.get_ticks_msec()
	var since := (now - _times_last_ms) / 1000.0
	var total := (now - _times_origin_ms) / 1000.0
	var what := ("étape « %s »" % id) if id != "" else "plus d'étape en cours (fin)"
	if restoring:
		what += " (remise en place)"
	if _times_last_step != "":
		_times_write("%s · %s · %s depuis l'étape « %s » · %s depuis le début" % [
			_clock(), what, _duration(since), _times_last_step, _duration(total)], false)
	else:
		_times_write("%s · %s · %s depuis le début" % [_clock(), what, _duration(total)], false)
	_times_last_ms = now
	_times_last_step = id


## Une ligne d'événement (point de passage, ABSORBÉ…), sans changer d'étape.
func _times_event(what: String) -> void:
	if not _times_open:
		return
	var total := (Time.get_ticks_msec() - _times_origin_ms) / 1000.0
	_times_write("%s · %s · %s depuis le début" % [_clock(), what, _duration(total)], false)


func _on_flag_changed(id: String, v: Variant) -> void:
	if id == "point_passage" and str(v) != "":
		_times_event("point de passage %s" % str(v))


## Temps depuis le début écrit à la fin du journal (pour « Continuer ») : la dernière mention
## « … depuis le début ».
func _times_previous_total() -> float:
	var path := times_path()
	if not FileAccess.file_exists(path):
		return 0.0
	var txt := FileAccess.get_file_as_string(path)
	var re := RegEx.create_from_string("(?:(\\d+) h )?(?:(\\d+) min )?(\\d+) s depuis le début")
	var last: RegExMatch = null
	for m in re.search_all(txt):
		last = m
	if last == null:
		return 0.0
	var h := last.get_string(1).to_int() if last.get_string(1) != "" else 0
	var mn := last.get_string(2).to_int() if last.get_string(2) != "" else 0
	return h * 3600.0 + mn * 60.0 + last.get_string(3).to_int()


func _times_write(line: String, truncate: bool) -> void:
	times_lines.append(line)
	var path := times_path()
	var f: FileAccess = null
	if truncate or not FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	if f == null:
		push_warning("journal des temps impossible : %s" % path)
		return
	f.store_line(line)
	f.close()
	if Game.autotest:
		print("JOURNAL ", line)


## Heure réelle, « 21:04:05 ».
static func _clock() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [t.hour, t.minute, t.second]


## Durée lisible : « 45 s », « 3 min 05 s », « 1 h 02 min 09 s ».
static func _duration(sec: float) -> String:
	var n := maxi(0, int(round(sec)))
	var h := n / 3600
	var m := (n % 3600) / 60
	var s := n % 60
	if h > 0:
		return "%d h %02d min %02d s" % [h, m, s]
	if m > 0:
		return "%d min %02d s" % [m, s]
	return "%d s" % s
