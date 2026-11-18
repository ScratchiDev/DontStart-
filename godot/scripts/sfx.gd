extends Node
## Singleton « Sfx » : sons ponctuels, à plat (play) ou placés dans la pièce (play_at, play_3d), boucles,
## musique, silence de l'entité, voix et bips (bus « Voix »), bourdonnement qui se déplace, battement de
## cœur et respiration du héros pilotés par le stress.
## Un son absent (fichier pas encore livré) ne joue rien, sans erreur : le lecteur rendu est muet.
##
## Mixage (passe « triple A », lot V2-SON) — bus créés ici, dans cet ordre (un bus n'envoie qu'à un bus
## d'indice plus petit, sinon il retombe sur Master) :
##   Master        … AudioEffectHardLimiter en dernier (plafond LIMIT_CEILING_DB) : ni sursaut ni tonnerre
##                 n'écrêtent ; le volume général (Game.master_volume) s'applique après.
##   Ambiance      pluie, ton de la pièce, musique, ronflements… : Sfx.silence() la coupe. Compresseur à
##                 chaîne latérale déclenché par « Voix » : l'ambiance se range sous la voix de l'entité.
##   Voix          l'entité (bips, bourdonnement), les voix : ni silence, ni occlusion.
##   Rev_feutree, Rev_chambre, Rev_couloir, Rev_carrelage, Rev_cage, Rev_sourd
##                 réverbérations des pièces (envois des Area3D d'Acoustique), vers Master ; silence() les
##                 baisse avec l'Ambiance (sinon la queue de la pluie survivrait au silence).
##   Master~<classe>, Ambiance~<classe>   (classe : ouverte, entrouverte, fermee, loin)
##                 occlusion : passe-bas et volume, renvoyés vers leur bus d'origine (voir acoustique.gd).
##   Tonnerre      le tonnerre (play("thunder")) : passe-bas selon les fenêtres de la pièce, vers Master.
##   Joueur        les pas du joueur (nœud Steps) : réverbération de la pièce où il est, vers Master.
## Les lecteurs 3D de Sfx voient les zones acoustiques (area_mask = Acoustique.AREA_MASK) et sont inscrits
## auprès de l'Acoustique de la maison (occlusion), créée par on_house_built (groupe « apres_maison »).
## Aucun tirage du hasard global n'est ajouté (la respiration et la pluie ont leur propre hasard).

const VARIANTS := {
	"creak": ["creak1", "creak2", "creak3"],
	"thud": ["impactWood_heavy_000", "impactWood_heavy_001", "impactWood_heavy_002"],
	"glass": ["impactGlass_heavy_000", "impactGlass_heavy_001"],
	"metal": ["impactMetal_heavy_000", "impactMetal_heavy_001"],
	"cloth": ["cloth1", "cloth2"],
	"chirp": ["chirp_1", "chirp_2", "chirp_3", "chirp_4"],
	"wet_step": ["wet_step_1", "wet_step_2", "wet_step"],
	"step_tile": ["footstep00", "footstep01", "footstep02", "footstep03", "footstep04"],
}
## Sons fabriqués en code tant que le fichier n'existe pas (voir _synth).
const SYNTH := ["heartbeat_loop", "hum_move", "chirp_1", "chirp_2", "chirp_3", "chirp_4"]

## Fin de chaîne de Master.
const LIMIT_CEILING_DB := -1.0
const LIMIT_RELEASE := 0.12
## L'ambiance sous la voix de l'entité (compresseur du bus Ambiance, chaîne latérale « Voix »). Mesuré au banc
## (acoustique_banc --canard) : des bips de Nestor (-12 dB) à 2 m baissent l'ambiance d'environ 5 dB, elle
## revient en moins d'une seconde ; plus loin, moins.
const AMB_DUCK := {"threshold": -24.0, "ratio": 2.5, "attack_us": 12000.0, "release_ms": 450.0}

var _cache := {}
var _missing := {}
var _music := {}        # nom de la piste -> AudioStreamPlayer
var _music_now := ""
var _amb_bus := -1
var _voice_bus := -1
var _rev_buses: Array[int] = []
var _silence_tw: Tween
var _duck_tw: Tween
var _amb_silence_db := 0.0     # part du silence de l'entité dans le volume de l'Ambiance
var _amb_duck_db := 0.0        # part du « canard » (duck_ambiance)
var _heart: AudioStreamPlayer
var heart_db := -80.0   # volume appliqué au battement de cœur, baisse sous les dialogues comprise (C4)
var heart_curve_db := -80.0   # volume que donne le stress seul (avant la baisse sous les dialogues)
var _duck := 0.0        # 0..1 : un dialogue s'affiche (le cœur se range dessous)
## L'acoustique de la maison en cours (null avant la maison, ou après un rechargement de la scène).
var acoustique: Acoustique
## Interrupteur général de l'acoustique (zones, occlusion) : faux = le son d'avant (comparaisons au banc).
var acoustique_on := true
var _player: Node3D
var _rng := RandomNumberGenerator.new()

## Le silence de l'entité (avant qu'elle agisse) et les sursauts : Haunt les écoute pour le stress.
signal silenced(seconds: float)
signal stung(db: float)


func _ready() -> void:
	_rng.seed = 31_102_040
	add_to_group("apres_maison")
	# bus « Ambiance » : pluie, souffle de la pièce, musique… tout ce que le silence de l'entité coupe
	_amb_bus = _ensure_bus("Ambiance")
	# bus « Voix » : l'entité qui parle (bips, bourdonnement), les voix ; le silence ne le coupe pas
	_voice_bus = _ensure_bus("Voix")
	_setup_mix()


## Index d'un bus, créé s'il manque (à la fin : il peut envoyer vers tous ceux d'avant).
func _ensure_bus(bus_name: String, send := "Master") -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, send)
	return i


## Crée un bus (API des lots suivants). « occludable » : ses sons 3D passent aussi par l'occlusion
## (les sous-bus « <nom>~<classe> » sont créés avec lui). Le bus d'envoi doit déjà exister.
func ensure_bus(bus_name: String, send := "Master", occludable := false) -> int:
	var i := _ensure_bus(bus_name, send)
	if occludable and not Acoustique.occludable.has(bus_name):
		Acoustique.occludable.append(bus_name)
		_class_buses(bus_name)
	return i


## Réverbérations des pièces, occlusion, tonnerre, pas, limiteur et compresseur (une fois, au lancement).
func _setup_mix() -> void:
	for rev_name in Acoustique.REVERBS:
		var i := _ensure_bus(rev_name)
		if AudioServer.get_bus_effect_count(i) == 0:
			AudioServer.add_bus_effect(i, _reverb(Acoustique.REVERBS[rev_name], 0.0, 1.0))
		_rev_buses.append(i)
	var s := _ensure_bus("Rev_sourd")
	if AudioServer.get_bus_effect_count(s) == 0:
		AudioServer.add_bus_effect(s, _lowpass(float(Acoustique.SOURD.cutoff_hz), int(Acoustique.SOURD.db)))
		AudioServer.add_bus_effect(s, _reverb(Acoustique.SOURD.reverb, 0.0, 1.0))
	_rev_buses.append(s)
	for origin in Acoustique.OCCLUDED_DEFAULT:
		_class_buses(origin)
	var t := _ensure_bus("Tonnerre")
	if AudioServer.get_bus_effect_count(t) == 0:
		AudioServer.add_bus_effect(t, _lowpass(20000.0, 0))
		AudioServer.set_bus_effect_enabled(t, 0, false)
	var j := _ensure_bus("Joueur")
	if AudioServer.get_bus_effect_count(j) == 0:
		AudioServer.add_bus_effect(j, _reverb(Acoustique.REVERBS["Rev_chambre"], 1.0, 0.0))
	# fin de Master : le limiteur
	var has_lim := false
	for k in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, k) is AudioEffectHardLimiter:
			has_lim = true
	if not has_lim:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = LIMIT_CEILING_DB
		lim.release = LIMIT_RELEASE
		AudioServer.add_bus_effect(0, lim)
	# l'ambiance se range sous la voix de l'entité
	if AudioServer.get_bus_effect_count(_amb_bus) == 0:
		var c := AudioEffectCompressor.new()
		c.threshold = AMB_DUCK.threshold
		c.ratio = AMB_DUCK.ratio
		c.attack_us = AMB_DUCK.attack_us
		c.release_ms = AMB_DUCK.release_ms
		c.sidechain = &"Voix"
		AudioServer.add_bus_effect(_amb_bus, c)


## Sous-bus d'occlusion « <origin>~<classe> » : passe-bas et volume, renvoyés vers « origin ».
func _class_buses(origin: String) -> void:
	for cl in Acoustique.CLASS_ORDER:
		if cl == "meme":
			continue
		var spec: Array = Acoustique.CLASSES[cl]
		var i := _ensure_bus("%s~%s" % [origin, cl], origin)
		if AudioServer.get_bus_effect_count(i) == 0:
			AudioServer.add_bus_effect(i, _lowpass(float(spec[0]), int(spec[1])))
		AudioServer.set_bus_volume_db(i, float(spec[2]))


static func _lowpass(hz: float, steep: int) -> AudioEffectLowPassFilter:
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = hz
	lp.db = steep
	return lp


static func _reverb(prm: Dictionary, dry: float, wet: float) -> AudioEffectReverb:
	var rv := AudioEffectReverb.new()
	for k in prm:
		rv.set(k, prm[k])
	rv.dry = dry
	rv.wet = wet
	return rv


## Maison construite (Main._after_build, groupe « apres_maison ») : l'acoustique de l'étage (zones,
## occlusion, pluie aux fenêtres), et les pas du joueur sur le bus « Joueur ».
func on_house_built(main: Node) -> void:
	var house: Node = main.get("house") as Node
	_player = main.get("player") as Node3D
	if house == null or not acoustique_on:
		return
	var old := house.get_node_or_null("Acoustique")
	if old:
		old.free()
	acoustique = Acoustique.new()
	acoustique.name = "Acoustique"
	house.add_child(acoustique)
	acoustique.build(house)
	var steps: AudioStreamPlayer = null
	if _player:
		steps = _player.get_node_or_null("Steps") as AudioStreamPlayer
	if steps and steps.bus == &"Master":
		steps.bus = &"Joueur"


func _acoustique() -> Acoustique:
	if acoustique and is_instance_valid(acoustique) and acoustique.is_inside_tree():
		return acoustique
	return null


## Juste avant qu'elle agisse : tous les sons d'ambiance se coupent net (et les réverbérations), puis
## reviennent.
func silence(seconds := 1.0) -> void:
	silenced.emit(seconds)
	if _silence_tw:
		_silence_tw.kill()
	_set_silence_db(-80.0)
	_silence_tw = create_tween()
	_silence_tw.tween_interval(seconds)
	_silence_tw.tween_method(_set_silence_db, -40.0, 0.0, 0.6)


func _set_silence_db(v: float) -> void:
	_amb_silence_db = v
	_apply_amb()


func _apply_amb() -> void:
	AudioServer.set_bus_volume_db(_amb_bus, maxf(-80.0, _amb_silence_db + _amb_duck_db))
	for i in _rev_buses:
		AudioServer.set_bus_volume_db(i, maxf(-80.0, _amb_silence_db))


func is_silent() -> bool:
	return AudioServer.get_bus_volume_db(_amb_bus) < -30.0


## Baisse l'Ambiance de « db » (négatif) en « attack » s, la garde « hold » s, puis la rend en « release » s
## (API des lots suivants : l'entité approche, une voix…). hold < 0 : reste baissée jusqu'à duck_ambiance(0).
## Indépendant du silence de l'entité (les deux s'additionnent ; is_silent ne voit que le silence).
func duck_ambiance(db: float, hold := 0.0, attack := 0.15, release := 0.8) -> void:
	if _duck_tw:
		_duck_tw.kill()
	_duck_tw = create_tween()
	_duck_tw.tween_method(_set_duck_db, _amb_duck_db, minf(db, 0.0), maxf(attack, 0.01))
	if hold >= 0.0 and db < 0.0:
		_duck_tw.tween_interval(hold)
		_duck_tw.tween_method(_set_duck_db, minf(db, 0.0), 0.0, maxf(release, 0.01))


func _set_duck_db(v: float) -> void:
	_amb_duck_db = v
	_apply_amb()


## Le son existe-t-il (fichier livré ou fabriqué en code) ?
func exists(sound: String) -> bool:
	return _stream(sound) != null


func _path_of(pick: String) -> String:
	for ext in ["ogg", "wav"]:
		var p := "res://assets/audio/%s.%s" % [pick, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


## Flux d'un son (une variante au hasard pour les noms de VARIANTS). own_rng : le hasard propre à Sfx
## (play_3d), pas celui du jeu (play, play_at, loop : leurs tirages restent ceux d'avant).
func _stream(sound: String, own_rng := false) -> AudioStream:
	var pick: String = sound
	if VARIANTS.has(sound):
		var list: Array = []
		for v in VARIANTS[sound]:
			if _path_of(v) != "" or SYNTH.has(v):
				list.append(v)
		if list.is_empty():
			_warn_missing(sound)
			return null
		pick = list[(_rng.randi() if own_rng else randi()) % list.size()]
	if not _cache.has(pick):
		var path := _path_of(pick)
		if path != "":
			_cache[pick] = load(path)
		elif SYNTH.has(pick):
			_cache[pick] = _synth(pick)
		else:
			_warn_missing(pick)
			return null
	return _cache[pick]


func _warn_missing(sound: String) -> void:
	if _missing.has(sound):
		return
	_missing[sound] = true
	print("son absent (rien n'est joué) : ", sound)


## Son à plat. « bus » : "Master" (défaut), "Ambiance" (coupé par le silence) ou "Voix". Le tonnerre passe
## par le bus « Tonnerre » (étouffé dans les pièces sans fenêtre claire).
func play(sound: String, db := 0.0, pitch := 1.0, bus := "Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound)
	p.volume_db = db
	p.bus = "Tonnerre" if sound == "thunder" and bus == "Master" and acoustique_on else bus
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	add_child(p)
	if p.stream == null:
		p.queue_free.call_deferred()
		return p
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Son placé dans la pièce (réverbération de la pièce où il est, occlusion selon le bus).
func play_at(sound: String, pos: Vector3, db := 0.0, pitch := 1.0, unit_size := 2.0, bus := "Master") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(sound)
	p.volume_db = db
	p.unit_size = unit_size
	p.bus = bus
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	var root := get_tree().current_scene
	root.add_child(p)
	p.global_position = pos
	if p.stream == null:
		p.queue_free.call_deferred()
		return p
	attach(p)
	p.play()
	_twin(p)
	p.finished.connect(p.queue_free)
	return p


## Voix ou bip de l'entité, placé sur l'appareil (bus « Voix » : ni silence, ni occlusion ; la
## réverbération de la pièce, si).
func voice_at(sound: String, pos: Vector3, db := 0.0, pitch := 1.0, unit_size := 2.0) -> AudioStreamPlayer3D:
	return play_at(sound, pos, db, pitch, unit_size, "Voix")


## Prépare un lecteur 3D créé ailleurs (API des lots suivants), déjà dans l'arbre, à sa place, et sur son
## bus d'origine (p.bus) ; à appeler avant play(). « reverb » : il voit les zones acoustiques de sa route
## (réverbération de la pièce où il est ; attention, dans une zone, c'est la zone qui choisit son bus : celui
## de sa route et de la classe d'écoute de la pièce). « occlusion » : passe-bas et volume selon portes et
## cloisons (bus Master, Ambiance et ceux créés par ensure_bus(…, true) ; jamais Voix).
func attach(p: AudioStreamPlayer3D, occlusion := true, reverb := true) -> void:
	if not acoustique_on or p == null:
		return
	if not occlusion:
		p.set_meta("sans_occlusion", true)
	var ac := _acoustique()
	if ac:
		ac.register(p, occlusion, reverb)
	elif reverb:
		p.area_mask = Acoustique.mask_for(String(p.bus), occlusion and not p.has_meta("sans_occlusion"))


## Son ponctuel au plan d'une porte (hors des zones : coups, poignée, clé) : un « jumeau » joue le même son
## vers la réverbération de la pièce de l'auditeur (Acoustique.twin_send), pour qu'il ne sonne pas sec.
func _twin(p: AudioStreamPlayer3D) -> void:
	var ac := _acoustique()
	if ac == null or p == null or p.stream == null or p.has_meta("sans_occlusion"):
		return
	var send := ac.twin_send(p.global_position)
	if send.is_empty():
		return
	var t := AudioStreamPlayer3D.new()
	t.name = "EnvoiReverb"
	t.stream = p.stream
	t.volume_db = p.volume_db + linear_to_db(float(send[1]))
	t.unit_size = p.unit_size
	t.max_distance = p.max_distance
	t.max_db = p.max_db
	t.pitch_scale = p.pitch_scale
	t.attenuation_filter_cutoff_hz = p.attenuation_filter_cutoff_hz
	t.panning_strength = 0.4      # la réverbération vient de partout
	t.bus = StringName(send[0])
	t.area_mask = 0
	p.add_child(t)
	t.play()


## Lecture 3D complète (API des lots suivants : V2-CREATURE…). Options, toutes facultatives :
##   db (0), pitch (1, exact), jitter (0 : hauteur ± jitter, hasard propre à Sfx, pas celui du jeu),
##   unit_size (2), max_distance (0 = sans limite), max_db (3), bus ("Master"), occlusion (true),
##   reverb (true), loop (false : sinon il se libère à la fin), from (0 s), parent (Node : le lecteur en
##   devient l'enfant et le suit ; pos reste une position globale), stream (AudioStream, à la place du nom :
##   AudioStreamRandomizer…), filter_hz (attenuation_filter_cutoff_hz), panning (panning_strength), name.
## Renvoie le lecteur (null si le son n'existe pas).
func play_3d(sound: String, pos: Vector3, opts := {}) -> AudioStreamPlayer3D:
	var st: AudioStream = opts.get("stream", null)
	if st == null:
		st = _stream(sound, true)
	if st == null:
		return null
	var looping := bool(opts.get("loop", false))
	if looping:
		st = _looped(st)
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	if opts.has("name"):
		p.name = String(opts.name)
	p.volume_db = float(opts.get("db", 0.0))
	p.unit_size = float(opts.get("unit_size", 2.0))
	p.max_distance = float(opts.get("max_distance", 0.0))
	p.max_db = float(opts.get("max_db", 3.0))
	p.bus = StringName(opts.get("bus", "Master"))
	var jitter := float(opts.get("jitter", 0.0))
	p.pitch_scale = float(opts.get("pitch", 1.0)) * (1.0 + (_rng.randf_range(-jitter, jitter) if jitter > 0.0 else 0.0))
	if opts.has("filter_hz"):
		p.attenuation_filter_cutoff_hz = float(opts.filter_hz)
	if opts.has("panning"):
		p.panning_strength = float(opts.panning)
	var holder: Node = opts.get("parent", null)
	if holder == null or not is_instance_valid(holder):
		holder = get_tree().current_scene
	holder.add_child(p)
	p.global_position = pos
	attach(p, bool(opts.get("occlusion", true)), bool(opts.get("reverb", true)))
	var from := float(opts.get("from", 0.0))
	if looping and st.get_length() > 0.0:
		from = fmod(from, st.get_length())
	p.play(from)
	if not looping:
		_twin(p)
		p.finished.connect(p.queue_free)
	return p


## Le flux en boucle (WAV : boucle avant sur toute la longueur ; OGG : loop).
func _looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif s is AudioStreamOggVorbis:
		s.loop = true
	return s


## Pièce de l'étage où est « pos » (HouseData), ou "" ; pièce de l'auditeur ; classe d'écoute d'un point
## (« meme », « ouverte », « entrouverte », « fermee », « loin ») pour l'auditeur actuel.
func room_of(pos: Vector3) -> String:
	return Acoustique.room_at(pos)


func listener_room() -> String:
	var ac := _acoustique()
	return ac.listener_room if ac else ""


func hearing_class(pos: Vector3) -> String:
	var ac := _acoustique()
	return ac.class_at(pos) if ac else "meme"


## Fenêtre ouverte (sa pluie est plus forte). Aucune ne s'ouvre dans cette version.
func set_window_open(id: String, on: bool) -> void:
	var ac := _acoustique()
	if ac:
		ac.set_window_open(id, on)


## Boucle continue (ambiance, ronflement de l'écran). Renvoie le lecteur pour régler le volume.
func loop(sound: String, db := 0.0, at := Vector3.INF, parent: Node = null, bus := "Ambiance") -> Node:
	var s := _stream(sound)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif s is AudioStreamOggVorbis:
		s.loop = true
	var holder: Node = parent if parent else get_tree().current_scene
	if at == Vector3.INF:
		var flat := AudioStreamPlayer.new()
		flat.stream = s
		flat.volume_db = db
		flat.bus = bus
		holder.add_child(flat)
		if s:
			flat.play()
		return flat
	var spatial := AudioStreamPlayer3D.new()
	spatial.unit_size = 1.5
	spatial.stream = s
	spatial.volume_db = db
	spatial.bus = bus
	holder.add_child(spatial)
	spatial.global_position = at
	if s:
		attach(spatial)
		spatial.play()
	return spatial


## Elle se déplace : un bourdonnement électrique (50 Hz) file en ligne droite de « from » à « to »
## en « seconds », à travers les murs. Renvoie le lecteur (il se libère tout seul à l'arrivée).
## (Réverbération des pièces traversées ; jamais d'occlusion : la traversée des murs est voulue.)
func hum_move(from: Vector3, to: Vector3, seconds := 1.2, db := -6.0) -> AudioStreamPlayer3D:
	var s := _stream("hum_move")
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif s is AudioStreamOggVorbis:
		s.loop = true
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "Voix"
	p.unit_size = 3.0
	p.max_db = 3.0
	p.attenuation_filter_cutoff_hz = 2200.0   # assourdi de loin : on l'entend derrière le mur
	p.volume_db = -40.0
	p.set_meta("sans_occlusion", true)
	get_tree().current_scene.add_child(p)
	p.global_position = from
	if s == null:
		p.queue_free.call_deferred()
		return p
	attach(p, false)
	p.play()
	var tw := p.create_tween()
	tw.set_parallel()
	tw.tween_property(p, "global_position", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(p, "volume_db", db, minf(0.25, seconds * 0.3))
	tw.tween_property(p, "pitch_scale", 1.12, seconds * 0.5).set_delay(seconds * 0.25)
	tw.chain().tween_property(p, "volume_db", -60.0, 0.35)
	tw.chain().tween_callback(p.queue_free)
	return p


## Musique de fond, en fondu enchaîné : « music_house » (la maison la nuit), « music_tension »
## (l'entité est là). Nom vide = silence. Continue de jouer dans les menus.
func music(track: String, db := -12.0, fade := 3.0) -> void:
	if track == _music_now:
		if track != "" and _music.has(track):
			create_tween().tween_property(_music[track], "volume_db", db, fade)
		return
	if _music_now != "" and _music.has(_music_now):
		var old: AudioStreamPlayer = _music[_music_now]
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	_music_now = track
	if track == "":
		return
	if not _music.has(track):
		var p := AudioStreamPlayer.new()
		var st := _stream(track)
		if st is AudioStreamOggVorbis:
			st.loop = true
		p.stream = st
		p.bus = "Ambiance"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_music[track] = p
	var cur: AudioStreamPlayer = _music[track]
	if cur.stream == null:
		return
	cur.volume_db = -60.0
	cur.play()
	create_tween().tween_property(cur, "volume_db", db, fade)


## Coup de sursaut (à utiliser avec parcimonie).
func sting(db := -2.0) -> void:
	stung.emit(db)
	play("sting", db, 1.0)


# ------------------------------------------------------------------ battement de cœur (stress)

## Volume du cœur (dB) selon le stress (0..1), points reliés en ligne droite : muet au calme, −36 dB
## vers 0,064, −20 dB à 0,12 (une impulsion de Haunt, au moins 0,35, donne −15 dB), −10 dB au maximum.
## Le cœur reste ainsi sous les voix et les bips de l'entité (−12 dB sur l'appareil) ; sa boucle
## (heartbeat_loop, 95 % de l'énergie sous 80 Hz) ne masque ni les bips (1,2 à 4 kHz) ni une voix.
const HEART_POINTS := [[0.01, -56.0], [0.05, -40.0], [0.12, -20.0], [0.4, -14.0], [1.0, -10.0]]
const HEART_AUDIBLE_DB := -20.0   # C4 : au-dessus, le cœur s'entend
const HEART_CALM_DB := -36.0      # C4 : au-dessous, il s'est tu
## Pendant un dialogue (sous-titre de l'entité ou d'un proche, chuchotement Windows), le cœur ne
## dépasse pas ce volume : il reste audible (> −20 dB) mais passe sous les voix.
const HEART_DUCK_DB := -18.0
const HEART_DUCK_SPEED := 2.5     # passage d'un état à l'autre en 0,4 s


static func heart_volume(stress: float) -> float:
	if stress <= float(HEART_POINTS[0][0]):
		return -80.0
	for i in range(1, HEART_POINTS.size()):
		var a: Array = HEART_POINTS[i - 1]
		var b: Array = HEART_POINTS[i]
		if stress <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (stress - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(HEART_POINTS[-1][1])


## Un dialogue s'affiche-t-il (le HUD le dit), ou la synthèse vocale parle-t-elle ?
func _dialogue_on() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("dialogue_on") and bool(hud.dialogue_on()):
		return true
	return Game.whispers and DisplayServer.tts_is_speaking()


func _process(delta: float) -> void:
	_update_heart(delta)
	_update_breath(delta)


## Recalcule et applique tout de suite le volume du cœur (Haunt l'appelle à chaque impulsion de stress :
## le cœur part au moment de l'événement, pas à l'image suivante, qui peut être longue en rendu logiciel).
func refresh_heart() -> void:
	_update_heart(0.0)


func _update_heart(delta: float) -> void:
	var s: float = Game.stress
	heart_curve_db = heart_volume(s)
	_duck = move_toward(_duck, 1.0 if _dialogue_on() else 0.0, HEART_DUCK_SPEED * delta)
	heart_db = heart_curve_db
	if heart_curve_db > HEART_DUCK_DB:
		heart_db = lerpf(heart_curve_db, HEART_DUCK_DB, _duck)
	if heart_curve_db <= -80.0:
		if _heart and _heart.playing:
			_heart.stop()
		return
	if _heart == null:
		_heart = AudioStreamPlayer.new()
		_heart.name = "Coeur"
		_heart.stream = _stream("heartbeat_loop")
		if _heart.stream is AudioStreamWAV:
			var w := _heart.stream as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
		elif _heart.stream is AudioStreamOggVorbis:
			(_heart.stream as AudioStreamOggVorbis).loop = true
		_heart.bus = "Master"
		add_child(_heart)
	if _heart.stream == null:
		return
	_heart.volume_db = heart_db
	_heart.pitch_scale = 0.95 + 0.55 * s    # 57 → 90 battements par minute
	if not _heart.playing:
		_heart.play()


# ------------------------------------------------------------------ respiration du héros (stress, effort)

## Le héros respire : sec (sans réverbération), sur Master, sur ses deux lecteurs « Inspiration » et
## « Expiration » (une expiration peut commencer pendant la fin de l'inspiration). Rythme de BREATH_RATE[0]
## à BREATH_RATE[1] respirations par minute selon max(Game.stress, effort) ; l'effort monte après
## BREATH_EFFORT_AFTER s de course et retombe en BREATH_EFFORT_DOWN s ; Game.peur ajoute un fond (+4 par
## minute à 100). Volume selon BREATH_POINTS : on ne l'entend presque pas au calme, après une course si.
## Elle se range sous les dialogues (comme le cœur), elle n'est pas coupée par le silence de l'entité :
## dans ce silence, on n'entend que son souffle et son cœur. Le cœur (C4) n'en dépend pas.
## Sons : breath_<calme|tendu|panique>_<in|out>_<1..4> (make_assets.py son ; synthèse, en attendant de
## vrais enregistrements). Aurélia : hauteur × BREATH_PITCH_AURELIA.
## Pour la caméra (presence.gd) : breath_phase (0..1 dans le cycle, 0 = début de l'inspiration),
## breath_inhaling, breath_rate (par minute), breath_drive (0..1).
const BREATH_POINTS := [[0.0, -38.0], [0.2, -33.0], [0.45, -26.0], [0.7, -21.0], [1.0, -17.0]]
const BREATH_RATE := [14.0, 34.0]
const BREATH_PEUR_RATE := 4.0
const BREATH_DUCK_DB := -32.0
const BREATH_EFFORT_AFTER := 3.0
const BREATH_EFFORT_UP := 5.0
const BREATH_EFFORT_DOWN := 8.0
const BREATH_EFFORT_MAX := 0.8
const BREATH_RUN_SPEED := 2.4
const BREATH_SETS := {"calme": 0.0, "tendu": 0.3, "panique": 0.62}   # seuil d'entrée (drive)
const BREATH_VARIANTS := 4
const BREATH_PITCH_AURELIA := 1.08
var breath_phase := 0.0
var breath_inhaling := false
var breath_rate := 14.0
var breath_drive := 0.0
var breath_db := -80.0
var breath_gain_db := 0.0       # réglage (« Respiration du personnage »), 0 par défaut
var breath_on := true
var _effort := 0.0
var _run_t := 0.0
var _br_in: AudioStreamPlayer
var _br_out: AudioStreamPlayer
var _br_next := 0.0
var _br_stage := 0               # 0 : inspiration à lancer, 1 : expiration, 2 : pause
var _br_cycle := 4.0
var _br_elapsed := 0.0
var _br_set := "calme"
var _br_last := {}
var _br_pitch := 1.0


static func breath_volume(drive: float) -> float:
	for i in range(1, BREATH_POINTS.size()):
		var a: Array = BREATH_POINTS[i - 1]
		var b: Array = BREATH_POINTS[i]
		if drive <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (drive - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(BREATH_POINTS[-1][1])


func _breath_drive(delta: float) -> float:
	var v := 0.0
	if _player and is_instance_valid(_player) and _player is CharacterBody3D:
		var vel := (_player as CharacterBody3D).velocity
		v = Vector2(vel.x, vel.z).length()
	if v > BREATH_RUN_SPEED:
		_run_t += delta
	else:
		_run_t = maxf(0.0, _run_t - delta * 2.0)
	if _run_t > BREATH_EFFORT_AFTER:
		_effort = minf(1.0, _effort + delta / BREATH_EFFORT_UP)
	else:
		_effort = maxf(0.0, _effort - delta / BREATH_EFFORT_DOWN)
	return clampf(maxf(Game.stress, _effort * BREATH_EFFORT_MAX), 0.0, 1.0)


func _update_breath(delta: float) -> void:
	if not breath_on or Game.phase == "title" or _player == null or not is_instance_valid(_player):
		breath_db = -80.0
		breath_phase = 0.0
		breath_inhaling = false
		_br_stage = 0
		_br_next = 0.0
		return
	breath_drive = _breath_drive(delta)
	breath_rate = lerpf(float(BREATH_RATE[0]), float(BREATH_RATE[1]), breath_drive) \
		+ BREATH_PEUR_RATE * clampf(Game.peur / 100.0, 0.0, 1.0)
	var curve := breath_volume(breath_drive) + breath_gain_db
	breath_db = curve
	if curve > BREATH_DUCK_DB:
		breath_db = lerpf(curve, BREATH_DUCK_DB, _duck)
	for p in [_br_in, _br_out]:
		if p and p.playing:
			p.volume_db = breath_db
	_br_elapsed += delta
	breath_phase = clampf(_br_elapsed / maxf(_br_cycle, 0.1), 0.0, 1.0)
	_br_next -= delta
	if _br_next > 0.0:
		return
	match _br_stage:
		0:
			_br_set = _breath_set(breath_drive)
			_br_cycle = 60.0 / breath_rate
			_br_elapsed = 0.0
			breath_phase = 0.0
			var inh := _breath_pick("in")
			var exh := _breath_pick("out")
			if inh == null or exh == null:
				_br_next = 1.0
				return
			# hauteur : le héros, et un cycle trop court pour ces sons les accélère un peu (15 % au plus)
			var base := BREATH_PITCH_AURELIA if Game.hero == "aurelia" else 1.0
			var need := (inh.get_length() + exh.get_length()) / base
			_br_pitch = base * clampf(need / (_br_cycle * 0.94), 1.0, 1.15) * _rng.randf_range(0.97, 1.03)
			_br_in = _breath_player(_br_in, "Inspiration")
			_br_in.stream = inh
			_br_in.pitch_scale = _br_pitch
			_br_in.volume_db = breath_db
			_br_in.play()
			_br_out = _breath_player(_br_out, "Expiration")
			_br_out.stream = exh
			breath_inhaling = true
			_br_next = inh.get_length() / _br_pitch * 0.96
			_br_stage = 1
		1:
			_br_out.pitch_scale = _br_pitch
			_br_out.volume_db = breath_db
			_br_out.play()
			breath_inhaling = false
			_br_next = _br_out.stream.get_length() / _br_pitch
			_br_stage = 2
		_:
			_br_next = maxf(0.05, _br_cycle - _br_elapsed)
			_br_stage = 0


func _breath_player(p: AudioStreamPlayer, nm: String) -> AudioStreamPlayer:
	if p and is_instance_valid(p):
		return p
	p = AudioStreamPlayer.new()
	p.name = nm
	p.bus = "Master"
	add_child(p)
	return p


func _breath_set(drive: float) -> String:
	var best := "calme"
	for k in BREATH_SETS:
		# hystérésis : on garde l'ensemble en cours jusqu'à 0,05 sous son seuil
		var th := float(BREATH_SETS[k]) - (0.05 if k == _br_set else 0.0)
		if drive >= th:
			best = k
	return best


## Un son de l'ensemble en cours (« in » ou « out »), jamais deux fois de suite le même.
func _breath_pick(kind: String) -> AudioStream:
	var key := "%s_%s" % [_br_set, kind]
	var n := BREATH_VARIANTS
	var k := _rng.randi_range(1, n)
	if n > 1 and k == int(_br_last.get(key, 0)):
		k = k % n + 1
	_br_last[key] = k
	var snd := "breath_%s_%d" % [key, k]
	if _path_of(snd) == "":
		_warn_missing(snd)
		return null
	return _stream(snd)


# ------------------------------------------------------------------ sons fabriqués en code

## Remplaçants synthétiques, utilisés seulement si le fichier n'existe pas encore.
func _synth(sound: String) -> AudioStreamWAV:
	var rate := 22050
	var data := PackedFloat32Array()
	match sound:
		"heartbeat_loop":
			# « poum-poum » à 60 par minute : deux coups sourds (55 et 48 Hz), le second plus doux
			var n := rate
			data.resize(n)
			for i in n:
				var t := float(i) / rate
				var v := 0.0
				for beat in [[0.0, 1.0, 55.0], [0.29, 0.62, 48.0]]:
					var dt: float = t - beat[0]
					if dt >= 0.0 and dt < 0.22:
						var env := (1.0 - exp(-dt * 90.0)) * exp(-dt * 22.0)
						v += beat[1] * env * sin(TAU * beat[2] * dt * (1.0 + 0.6 * exp(-dt * 30.0)))
				data[i] = clampf(v * 0.95, -1.0, 1.0)
		"hum_move":
			# bourdonnement du secteur (50 Hz et ses harmoniques impaires), qui grésille un peu
			var n := rate   # 1 s : 50 périodes exactes, boucle propre
			data.resize(n)
			var rng := RandomNumberGenerator.new()
			rng.seed = 50
			for i in n:
				var t := float(i) / rate
				var v := 0.55 * sin(TAU * 50.0 * t) + 0.3 * sin(TAU * 150.0 * t) + 0.18 * sin(TAU * 250.0 * t) \
					+ 0.1 * sin(TAU * 350.0 * t) + 0.06 * sin(TAU * 1050.0 * t)
				v += rng.randf_range(-0.08, 0.08) * (0.5 + 0.5 * sin(TAU * 100.0 * t))
				data[i] = clampf(v * 0.7, -1.0, 1.0)
		_:
			# bips de données (« chirp ») : rafales de tons carrés entre 1,2 et 4 kHz
			var k := sound.right(1).to_int() if sound.begins_with("chirp_") else 1
			var rng := RandomNumberGenerator.new()
			rng.seed = 700 + k
			var n := int(rate * (0.09 + 0.03 * k))
			data.resize(n)
			var seg := int(rate * 0.018)
			var f := 2000.0
			for i in n:
				if i % seg == 0:
					f = rng.randf_range(1200.0, 4000.0)
				var t := float(i) / rate
				var sq := 1.0 if sin(TAU * f * t) >= 0.0 else -1.0
				var env := minf(1.0, float(n - i) / (rate * 0.01))
				data[i] = sq * 0.22 * env
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(data[i] * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w
