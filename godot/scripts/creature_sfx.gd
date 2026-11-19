class_name CreatureSfx
extends Node
## Les sons de l'entité S.1.L.3.N.C.3. (passe « triple A », lot V2-CREATURE). Elle n'a pas de voix : la peur
## passe par le son. Nœud enfant de Sfx (Sfx.creature), créé dans Sfx._ready ; Haunt l'appelle aux moments
## écrits (présence, déplacement, paroles, impulsions de stress, coups, appareils). Sons : assets/audio/creature/
## (godot/tools/make_creature.py, 48 kHz).
##
## - SA SIGNATURE (signature) : un bip électronique net qui se déforme puis se dissout en souffle. Elle annonce
##   sa présence : à son arrivée dans un appareil (Haunt.move) et à ses premiers mots après un temps de calme
##   (Haunt.say, indices compris). Au plus une fois toutes les SIGNATURE_COOLDOWN s.
## - SON SOUFFLE ÉLECTRIQUE : une boucle dans l'appareil habité (Haunt.inhabited_id), qui la suit d'appareil en
##   appareil (fondu pendant le bourdonnement de Sfx.hum_move) ; trois couleurs : haut-parleur, radio du
##   babyphone, fils dans les murs (ampoules, sèche-serviettes…). Il gonfle quand elle parle (swell) et à
##   chaque impulsion de stress ; son volume monte avec la jauge (PEUR MESURÉE). Bus « Entite » (occulté :
##   on l'entend à travers les murs, étouffé), avec la réverbération de la pièce. Le silence de l'entité ne le
##   coupe pas : quand tout se tait, il ne reste qu'elle.
## - SES IMITATIONS, sans paroles (imitate) : la toux de Mamie (quatre fois la même, la dernière à l'envers),
##   ses pantoufles (au métronome, qui s'approchent derrière toi), des coups à une porte (trop réguliers, ou à
##   l'envers). Branchées : la toux sous la première ligne imitée d'un appareil (babyphone, B2) ; les
##   pantoufles derrière le joueur la première fois que la caméra éteint sa LED ; des coups à l'envers qui
##   répondent, de l'autre côté de la porte, la première fois que le joueur frappe.
## - L'INTERFÉRENCE (parasite) : rafales d'un téléphone près d'un haut-parleur, dans l'appareil qui fait
##   quelque chose tout seul (box, imprimante, Nestor débranché).
## - SON CORPS (pour plus tard, l'acte III) : body_jump(pos) joue un à-coup (craquement numérique, choc sourd
##   dans les basses) ; à moins de BODY_SILENCE_M de l'auditeur, la maison se tait (Sfx.silence_hold) jusqu'à
##   body_gone().
## - LE SURSAUT (sting, appelé par Sfx.sting) : sting.ogg pour le grave, plus « sursaut » (souffle électrique
##   large bande, 1 à 6 kHz, attaque < 5 ms) placé devant le visage, sur le bus « Voix » (l'ambiance se range
##   dessous). « Sursauts réduits » : seulement la signature, à STING_REDUCED_DB au plus, sans choc.
## Tout son significatif a son sous-titre entre crochets (Haunt.sound_caption : affiché avec l'option).
## Hasard : le sien (graine fixe), jamais celui du jeu (randf, randi) : l'ordre des tirages ne change pas.

const DIR := "res://assets/audio/creature/%s.wav"
const BUS := "Entite"
const SIGNATURES := ["signature_1", "signature_2", "signature_3"]
const SIGNATURE_COOLDOWN := 40.0
const SIGNATURE_DB := -6.0
const SIGNATURE_UNIT := 1.6
## Souffle électrique : volume (jauge à 0), en plus à jauge 100, portée, fondus, gonflement.
const BREATH_DB := -15.0
const BREATH_PEUR_DB := 7.0
const BREATH_UNIT := 0.7
const BREATH_MAX_DISTANCE := 10.0
const BREATH_FADE_IN := 2.5
const BREATH_FADE_OUT := 0.6
const SWELL_DB := 6.0
const POLL := 0.25
## Couleur du souffle selon l'appareil (défaut : « mur », les fils dans les murs).
const BREATH_KIND := {"nestor": "hp", "console": "hp", "pc_manon": "hp", "miroir": "hp", "imprimante": "hp",
	"box": "hp", "babyphone": "babyphone"}
## Imitations : son, volume, portée.
const IMIT := {
	"toux_radio": [-1.0, 1.4], "toux_piece": [-3.0, 1.6], "pantoufles_piece": [-3.0, 1.8],
	"coups_reguliers": [-2.0, 2.2], "coups_envers": [-2.0, 2.2],
}
const PARASITE_DB := -10.0
const ACOUP_DB := 0.0
const BODY_SILENCE_M := 3.0
## Sursaut : grave (sting.ogg, abaissé pour laisser la place aux aigus), souffle large bande devant le visage,
## canard de l'ambiance ; en « Sursauts réduits », la signature seule, plafonnée.
const STING_LOW_DB := -9.0
const STING_HIGH_DB := 1.0
const STING_DUCK := [-12.0, 1.0, 0.02, 0.8]
const STING_REDUCED_DB := -14.0
const STING_REDUCED_GAIN := 4.0   # la signature (fichier à -16 LUFS) au niveau d'un sursaut à -12 dB du complet

## Sous-titres (courts, comme ceux du jeu : une ligne à 640 px de large, au-dessus des dialogues).
const SIGNATURE_CAPTION := "[Un bip qui se déforme en souffle]"
const PARASITE_CAPTION := "[Interférence qui grésille dans l'appareil]"
const TOUX_CAPTION := "[Une toux, quatre fois la même]"
const PANTOUFLES_CAPTION := "[Des pantoufles qui traînent, derrière toi]"
const COUPS_CAPTION := "[Des coups répondent, à l'envers]"
const STING_CAPTION := "[Souffle électrique, contre ton visage]"
const ACOUP_CAPTION := "[Craquement numérique, choc sourd]"

var _rng := RandomNumberGenerator.new()
var _cache := {}
var _breath: AudioStreamPlayer3D
var _breath_dev := ""
var _breath_base_db := -80.0
var _swell_db := 0.0
var _swell_tw: Tween
var _poll_t := 0.0
var _last_sig_ms := -1000000
var _last_sig := -1
var _moving_to := ""
var _imitated := {}             # imitations déjà faites dans cette scène (une fois chacune)
var _body_hold := false
var _haunt_id := 0              # le Haunt de la scène en cours (un neuf à chaque chargement : on repart à zéro)
## Désactivé : plus aucun son de l'entité d'ici (comparaisons, bancs).
var enabled := true


func _ready() -> void:
	_rng.seed = 51_212_040


# ------------------------------------------------------------------ flux, lecture

func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var p: String = DIR % sound
		_cache[sound] = load(p) if ResourceLoader.exists(p) else null
		if _cache[sound] == null:
			print("son absent (rien n'est joué) : creature/", sound)
	return _cache[sound]


func _haunt() -> Haunt:
	return Haunt.of(get_tree()) if is_inside_tree() else null


func _caption(text: String) -> void:
	var h := _haunt()
	if h:
		h.sound_caption(text)


## Lecture 3D d'un son de l'entité (bus « Entite », occulté, réverbération de la pièce). opts : ceux de
## Sfx.play_3d (db, unit_size, bus…).
func play(sound: String, pos: Vector3, opts := {}) -> AudioStreamPlayer3D:
	var st := stream(sound)
	if st == null or not enabled or not is_inside_tree() or get_tree().current_scene == null:
		return null
	var o := {"bus": BUS, "stream": st, "unit_size": 1.5, "max_db": 3.0}
	o.merge(opts, true)
	return Sfx.play_3d(sound, pos, o)


## Gain (dB) que la jauge ajoute aux sons de l'entité : de 0 (jauge vide) à « span » (jauge pleine).
func peur_db(span: float) -> float:
	return span * clampf(Game.peur / 100.0, 0.0, 1.0)


## Point « derrière toi » : à dist m derrière la caméra, à hauteur d'oreille (un peu de côté).
func behind_listener(dist := 1.0, side := 0.25) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return Vector3.ZERO
	var b := cam.global_transform.basis
	var back := Vector3(b.z.x, 0.0, b.z.z).normalized()
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	return cam.global_position + back * dist + right * side + Vector3(0, -0.15, 0)


func _listener() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else Vector3.INF


# ------------------------------------------------------------------ la signature

## Joue la signature en pos (une variante, jamais deux fois de suite la même). Renvoie le lecteur.
func signature(pos: Vector3, db_extra := 0.0, caption := true) -> AudioStreamPlayer3D:
	var k := _rng.randi_range(0, SIGNATURES.size() - 1)
	if k == _last_sig:
		k = (k + 1) % SIGNATURES.size()
	_last_sig = k
	_last_sig_ms = Time.get_ticks_msec()
	var p := play(String(SIGNATURES[k]), pos, {"db": SIGNATURE_DB + peur_db(4.0) + db_extra, "unit_size": SIGNATURE_UNIT})
	if p and caption:
		_caption(SIGNATURE_CAPTION)
	return p


## Elle annonce sa présence dans l'appareil dev (signature), sauf si elle l'a fait il y a moins de
## SIGNATURE_COOLDOWN s (ou force). Vrai si la signature a joué.
func announce(dev: Node3D, force := false) -> bool:
	if dev == null or not is_instance_valid(dev) or not dev.is_inside_tree():
		return false
	if not force and (Time.get_ticks_msec() - _last_sig_ms) < SIGNATURE_COOLDOWN * 1000.0:
		return false
	var pos: Vector3 = dev.call("speak_pos") if dev.has_method("speak_pos") else dev.global_position
	return signature(pos) != null


func since_signature() -> float:
	return (Time.get_ticks_msec() - _last_sig_ms) / 1000.0


# ------------------------------------------------------------------ le souffle électrique (appareil habité)

func _process(delta: float) -> void:
	_poll_t += delta
	if _poll_t < POLL:
		return
	_poll_t = 0.0
	var h := _haunt()
	if h and h.get_instance_id() != _haunt_id:
		_haunt_id = h.get_instance_id()
		_imitated.clear()
		_last_sig_ms = -1000000
		_moving_to = ""
		_breath_dev = ""
	var want := ""
	if h and enabled and Game.phase != "title":
		want = h.inhabited_id
	if want == _moving_to and want != "":
		return
	var lost := want != "" and (_breath == null or not is_instance_valid(_breath))
	if want != _breath_dev or lost:
		_set_breath_device(want, h)
	elif _breath and is_instance_valid(_breath):
		_breath_base_db = _breath_target_db(h.device(want) if h else null)
		_apply_breath_db()


func _breath_target_db(dev: Node) -> float:
	var db := BREATH_DB + peur_db(BREATH_PEUR_DB)
	# le babyphone a déjà son souffle (babyphone_breath) quand il « respire » : le sien reste dessous
	if dev and is_instance_valid(dev):
		var own: Variant = dev.get("_breath_snd")
		if own is Node and is_instance_valid(own):
			db -= 9.0
	return db


func _breath_kind(dev_id: String) -> String:
	return String(BREATH_KIND.get(dev_id, "mur"))


## Le souffle passe dans l'appareil dev_id ("" : nulle part), en fondu.
func _set_breath_device(dev_id: String, h: Haunt) -> void:
	_fade_out_breath()
	_breath_dev = dev_id
	if dev_id == "" or h == null:
		return
	var dev: Connected = h.device(dev_id)
	if dev == null or not dev.is_inside_tree():
		return
	var snd := "souffle_" + _breath_kind(dev_id)
	var st := stream(snd)
	if st == null:
		return
	_breath_base_db = _breath_target_db(dev)
	_breath = Sfx.play_3d(snd, dev.speak_pos(), {"bus": BUS, "stream": st, "loop": true, "db": -60.0,
		"unit_size": BREATH_UNIT, "max_distance": BREATH_MAX_DISTANCE, "max_db": 0.0,
		"from": _rng.randf_range(0.0, 24.0), "pitch": _rng.randf_range(0.97, 1.03), "name": "SouffleEntite"})
	if _breath:
		var tw := _breath.create_tween()
		tw.tween_method(func(v: float) -> void: _breath_fade(v), 0.0, 1.0, BREATH_FADE_IN)


func _breath_fade(k: float) -> void:
	if _breath and is_instance_valid(_breath):
		_breath.set_meta("fondu", k)
		_apply_breath_db()


func _apply_breath_db() -> void:
	if _breath == null or not is_instance_valid(_breath):
		return
	var k := float(_breath.get_meta("fondu", 1.0))
	_breath.volume_db = lerpf(-60.0, _breath_base_db + _swell_db, clampf(k, 0.0, 1.0) ** 0.5)


func _fade_out_breath() -> void:
	if _breath and is_instance_valid(_breath):
		var old := _breath
		var tw := old.create_tween()
		tw.tween_property(old, "volume_db", -60.0, BREATH_FADE_OUT)
		tw.tween_callback(old.queue_free)
	_breath = null


## Le souffle gonfle de db pendant seconds s (elle parle, une impulsion de stress), puis revient.
func swell(seconds: float, db := SWELL_DB) -> void:
	if _swell_tw:
		_swell_tw.kill()
	_swell_tw = create_tween()
	_swell_tw.tween_method(_set_swell, _swell_db, maxf(db, _swell_db), 0.35)
	_swell_tw.tween_interval(maxf(0.0, seconds))
	_swell_tw.tween_method(_set_swell, maxf(db, _swell_db), 0.0, 1.5)


func _set_swell(v: float) -> void:
	_swell_db = v
	_apply_breath_db()


# ------------------------------------------------------------------ imitations, interférence

## Une imitation (toux_radio, toux_piece, pantoufles_piece, coups_reguliers, coups_envers) en pos.
func imitate(sound: String, pos: Vector3, caption := "", db_extra := 0.0) -> AudioStreamPlayer3D:
	var spec: Array = IMIT.get(sound, [-4.0, 1.5])
	var p := play(sound, pos, {"db": float(spec[0]) + peur_db(3.0) + db_extra, "unit_size": float(spec[1])})
	if p and caption != "":
		_caption(caption)
	return p


## L'interférence d'un téléphone dans le haut-parleur de l'appareil (en pos).
func parasite(pos: Vector3, caption := true) -> AudioStreamPlayer3D:
	var k := _rng.randi_range(1, 3)
	var p := play("parasite_%d" % k, pos, {"db": PARASITE_DB + peur_db(3.0), "unit_size": 1.2})
	if p and caption:
		_caption(PARASITE_CAPTION)
	return p


# ------------------------------------------------------------------ son corps (acte III : API prête)

## Un à-coup de son corps en pos (craquement numérique, choc sourd). À moins de BODY_SILENCE_M de l'auditeur,
## la maison se tait jusqu'à body_gone(). Renvoie le lecteur.
func body_jump(pos: Vector3, db_extra := 0.0, caption := true) -> AudioStreamPlayer3D:
	var p := play("acoup_%d" % _rng.randi_range(1, 4), pos, {"db": ACOUP_DB + peur_db(3.0) + db_extra,
		"unit_size": 2.5, "pitch": _rng.randf_range(0.94, 1.06)})
	if p and caption:
		_caption(ACOUP_CAPTION)
	var lp := _listener()
	if lp != Vector3.INF and lp.distance_to(pos) < BODY_SILENCE_M and not _body_hold:
		_body_hold = true
		Sfx.silence_hold(true)
	return p


## Son corps avance par à-coups le long de points (positions globales), un saut toutes les interval s (de
## plus en plus vite : × accel à chaque saut) ; le sous-titre au premier saut. await creature.body_approach(…).
## Ne relâche pas le silence : appeler body_gone() quand elle disparaît.
func body_approach(points: Array, interval := 1.2, accel := 0.88) -> void:
	var dt := interval
	for i in points.size():
		body_jump(points[i] as Vector3, 0.0, i == 0)
		if i < points.size() - 1:
			await get_tree().create_timer(maxf(0.15, dt), false).timeout
			dt *= accel


## Son corps n'est plus là : la maison reprend (si elle s'était tue).
func body_gone() -> void:
	if _body_hold:
		_body_hold = false
		Sfx.silence_hold(false)


# ------------------------------------------------------------------ le sursaut

## Le sursaut (Sfx.sting). db : le niveau demandé par la scène (0 pour le visage, -14 en « Sursauts réduits »).
func sting(db: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var front := Vector3.INF
	if cam:
		front = cam.global_position - cam.global_transform.basis.z * 0.5
	if Game.reduced_scares:
		# sursauts réduits : pas de choc, pas de pic ; la signature seule, à plat, plafonnée (Sfx.play fait le
		# même tirage du hasard du jeu que l'ancien play("sting") : l'ordre des tirages ne change pas)
		var k := _rng.randi_range(0, SIGNATURES.size() - 1)
		Sfx.play("creature/" + String(SIGNATURES[k]), minf(db, STING_REDUCED_DB) + STING_REDUCED_GAIN, 1.0)
		_last_sig_ms = Time.get_ticks_msec()
		_caption(STING_CAPTION)
		return
	Sfx.play("sting", db + STING_LOW_DB, 1.0)
	if front != Vector3.INF and enabled:
		Sfx.play_3d("sursaut", front, {"stream": stream("sursaut"), "bus": "Voix", "occlusion": false,
			"db": db + STING_HIGH_DB, "unit_size": 1.0, "max_db": 2.0, "name": "Sursaut"})
	Sfx.duck_ambiance(float(STING_DUCK[0]), float(STING_DUCK[1]), float(STING_DUCK[2]), float(STING_DUCK[3]))
	_last_sig_ms = Time.get_ticks_msec()
	_caption(STING_CAPTION)


# ------------------------------------------------------------------ branchements (appelés par Haunt)

## Elle se déplace (Haunt.move) : le souffle quitte a, file avec le bourdonnement, arrive dans b avec la
## signature.
func on_move(a: Connected, b: Connected, sec: float) -> void:
	if b == null:
		return
	_moving_to = b.device_id
	_fade_out_breath()
	_breath_dev = ""
	get_tree().create_timer(maxf(0.05, sec), false).timeout.connect(func() -> void:
		_moving_to = ""
		if is_instance_valid(b) and b.is_inside_tree():
			announce(b))


## Elle parle par dev (Haunt.say) : première ligne imitée par cet appareil, la toux de Mamie ; sinon, après
## un temps de calme, la signature ; le souffle gonfle pendant la ligne. Renvoie le temps (s) à laisser avant
## ses bips de données (SAY_LEAD si la signature ou la toux vient de partir, sinon 0).
const SAY_LEAD := 0.8
func on_say(dev: Connected, who: String, dur: float) -> float:
	if dev == null or not is_instance_valid(dev) or not dev.is_inside_tree():
		return 0.0
	var lead := 0.0
	var imitation := who != "elle" and who != ""
	var key := "toux_" + dev.device_id
	if imitation and not _imitated.has(key):
		_imitated[key] = true
		var radio := dev.device_id == "babyphone" or BREATH_KIND.has(dev.device_id)
		if imitate("toux_radio" if radio else "toux_piece", dev.speak_pos(), TOUX_CAPTION):
			lead = SAY_LEAD
		_last_sig_ms = Time.get_ticks_msec()
	elif not imitation and announce(dev):
		lead = SAY_LEAD
	if dev.device_id == _breath_dev:
		swell(dur)
	return lead


## Impulsion de stress (Haunt.stress) : le souffle gonfle un peu.
func on_stress(v: float, _why: String) -> void:
	if v > 0.0:
		swell(1.5 + 3.0 * v, SWELL_DB * clampf(v / 0.5, 0.4, 1.2))


## Événement de pièce (Haunt.story_event) : les appareils qui font quelque chose tout seuls grésillent ;
## la première fois que la caméra éteint sa LED, ses pantoufles s'approchent derrière toi.
func on_story(event_name: String, _data: Dictionary) -> void:
	var h := _haunt()
	if h == null:
		return
	match event_name:
		"camera_led_eteinte":
			if not _imitated.has("pantoufles"):
				_imitated["pantoufles"] = true
				imitate("pantoufles_piece", behind_listener(1.1, -0.3), PANTOUFLES_CAPTION)
		"nestor_debranche":
			var n: Connected = h.device("nestor")
			if n:
				parasite(n.speak_pos())
				swell(4.0)
		"box_debranchee":
			var bx: Connected = h.device("box")
			if bx:
				parasite(bx.speak_pos())
		"page_imprimee":
			if not _imitated.has("imprimante"):
				_imitated["imprimante"] = true
				var pr: Connected = h.device("imprimante")
				if pr:
					parasite(pr.speak_pos(), false)


## Le joueur a frappé à une porte (Haunt._on_door_used) : la première fois, des coups lui répondent de
## l'autre côté, à l'envers. door : le nœud Door ; door_id : P1 à P7.
func on_knock(door: Node3D, door_id: String) -> void:
	if _imitated.has("coups") or door == null or not is_instance_valid(door):
		return
	_imitated["coups"] = true
	var lp := _listener()
	var at := door.global_position
	var c := at.z
	for d in Acoustique.D.F1_DOORS:
		if String(d.id) == door_id:
			at = Vector3(float(d.at), 0.0, float(d.c))
			c = float(d.c)
	var side := 1.0 if lp == Vector3.INF or lp.x < at.x else -1.0
	var pos := Vector3(at.x + side * 0.04, Acoustique.D.F1_Y + 1.25, c)
	get_tree().create_timer(1.8, false).timeout.connect(func() -> void:
		imitate("coups_envers", pos, COUPS_CAPTION))
