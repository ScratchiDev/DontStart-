extends Node
## Singleton « Sfx » : sons ponctuels, à plat (play) ou placés dans la pièce (play_at), boucles,
## musique, silence de l'entité, voix et bips (bus « Voix »), bourdonnement qui se déplace,
## battement de cœur piloté par le stress.
## Un son absent (fichier pas encore livré) ne joue rien, sans erreur : le lecteur rendu est muet.

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

var _cache := {}
var _missing := {}
var _music := {}        # nom de la piste -> AudioStreamPlayer
var _music_now := ""
var _amb_bus := -1
var _voice_bus := -1
var _silence_tw: Tween
var _heart: AudioStreamPlayer
var heart_db := -80.0   # volume courant du battement de cœur (lu par l'autotest)


func _ready() -> void:
	# bus « Ambiance » : pluie, souffle de la pièce, musique… tout ce que le silence de l'entité coupe
	_amb_bus = _ensure_bus("Ambiance")
	# bus « Voix » : l'entité qui parle (bips, bourdonnement), les voix ; le silence ne le coupe pas
	_voice_bus = _ensure_bus("Voix")


func _ensure_bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


## Juste avant qu'elle agisse : tous les sons d'ambiance se coupent net, puis reviennent.
func silence(seconds := 1.0) -> void:
	if _silence_tw:
		_silence_tw.kill()
	AudioServer.set_bus_volume_db(_amb_bus, -80.0)
	_silence_tw = create_tween()
	_silence_tw.tween_interval(seconds)
	_silence_tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(_amb_bus, v), -40.0, 0.0, 0.6)


func is_silent() -> bool:
	return AudioServer.get_bus_volume_db(_amb_bus) < -30.0


## Le son existe-t-il (fichier livré ou fabriqué en code) ?
func exists(sound: String) -> bool:
	return _stream(sound) != null


func _path_of(pick: String) -> String:
	for ext in ["ogg", "wav"]:
		var p := "res://assets/audio/%s.%s" % [pick, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


func _stream(sound: String) -> AudioStream:
	var pick: String = sound
	if VARIANTS.has(sound):
		var list: Array = []
		for v in VARIANTS[sound]:
			if _path_of(v) != "" or SYNTH.has(v):
				list.append(v)
		if list.is_empty():
			_warn_missing(sound)
			return null
		pick = list[randi() % list.size()]
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


## Son à plat. « bus » : "Master" (défaut), "Ambiance" (coupé par le silence) ou "Voix".
func play(sound: String, db := 0.0, pitch := 1.0, bus := "Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound)
	p.volume_db = db
	p.bus = bus
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	add_child(p)
	if p.stream == null:
		p.queue_free.call_deferred()
		return p
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Son placé dans la pièce.
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
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Voix ou bip de l'entité, placé sur l'appareil (bus « Voix » : le silence ne le coupe pas).
func voice_at(sound: String, pos: Vector3, db := 0.0, pitch := 1.0, unit_size := 2.0) -> AudioStreamPlayer3D:
	return play_at(sound, pos, db, pitch, unit_size, "Voix")


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
		spatial.play()
	return spatial


## Elle se déplace : un bourdonnement électrique (50 Hz) file en ligne droite de « from » à « to »
## en « seconds », à travers les murs. Renvoie le lecteur (il se libère tout seul à l'arrivée).
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
	get_tree().current_scene.add_child(p)
	p.global_position = from
	if s == null:
		p.queue_free.call_deferred()
		return p
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
	play("sting", db, 1.0)


# ------------------------------------------------------------------ battement de cœur (stress)

## Volume du cœur selon le stress (0..1) : muet au calme, audible (> −20 dB) dès 0,3,
## sous −36 dB quand le stress retombe sous 0,05.
static func heart_volume(stress: float) -> float:
	if stress <= 0.001:
		return -80.0
	var x := clampf((stress - 0.05) / 0.55, 0.0, 1.0)
	return -44.0 + 38.0 * sqrt(x)


func _process(_delta: float) -> void:
	var s: float = Game.stress
	heart_db = heart_volume(s)
	if s <= 0.001:
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
