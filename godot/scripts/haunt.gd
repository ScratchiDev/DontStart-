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

var devices := {}                 # device_id -> Connected
var journal: Array = []           # [{t, ev, …}]
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
var _hum_captioned := false
var _t0 := 0


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
	Game.absorbed.connect(func() -> void: self.log({"ev": "absorbe", "peur": Game.peur}))


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
## l'option « Sous-titres des sons » est active, sauf force = true.
func sound_caption(text: String, force := false) -> void:
	var hud := _hud()
	if hud and hud.has_method("sound_caption"):
		hud.sound_caption(text, force)
	self.log({"ev": "son", "text": text})


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
	if not _hum_captioned:
		_hum_captioned = true
		sound_caption(HUM_CAPTION, true)
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


## Stress caché (cœur, grain) : +0,3 imitation, S.O.S. ; +0,5 P4 réel ; +0,6 ampoule qui éclate.
func stress(v: float) -> void:
	Game.add_stress(v)
	self.log({"ev": "stress", "v": v})


## Événement de scénario signalé par une pièce ou un appareil (« seche_cheveux_pris »,
## « antenne_prise », « porte_essayee »…). Le scénario écoute le signal « story ».
func story_event(event_name: String, data := {}) -> void:
	var e := {"ev": "story", "name": event_name}
	e.merge(data)
	self.log(e)
	progress()
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
func step(id: String) -> void:
	step_id = id
	_idle = 0.0
	self.log({"ev": "etape", "step": id})


## Le joueur a progressé : le compteur des indices repart de zéro.
func progress() -> void:
	_idle = 0.0


## Scène écrite en cours : pas d'indice (à appeler par paires).
func begin_scene() -> void:
	_busy += 1


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
	hints_given += 1
	self.log({"ev": "indice", "step": step_id, "dev": id, "text": fill(text)})
