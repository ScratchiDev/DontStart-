extends Node
## Singleton « Sfx » : sons ponctuels, à plat (play) ou placés dans la pièce (play_at).

const VARIANTS := {
	"creak": ["creak1", "creak2", "creak3"],
	"thud": ["impactWood_heavy_000", "impactWood_heavy_001", "impactWood_heavy_002"],
	"glass": ["impactGlass_heavy_000", "impactGlass_heavy_001"],
	"metal": ["impactMetal_heavy_000", "impactMetal_heavy_001"],
	"cloth": ["cloth1", "cloth2"],
}

var _cache := {}
var _music := {}        # nom de la piste -> AudioStreamPlayer
var _music_now := ""


func _stream(name: String) -> AudioStream:
	var pick: String = name
	if VARIANTS.has(name):
		var list: Array = VARIANTS[name]
		pick = list[randi() % list.size()]
	if not _cache.has(pick):
		var path := "res://assets/audio/%s.ogg" % pick
		if not ResourceLoader.exists(path):
			path = "res://assets/audio/%s.wav" % pick
		_cache[pick] = load(path)
	return _cache[pick]


func play(name: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(name)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func play_at(name: String, pos: Vector3, db := 0.0, pitch := 1.0, unit_size := 2.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(name)
	p.volume_db = db
	p.unit_size = unit_size
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	var root := get_tree().current_scene
	root.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Boucle continue (ambiance, ronflement de l'écran). Renvoie le lecteur pour régler le volume.
func loop(name: String, db := 0.0, at := Vector3.INF, parent: Node = null) -> Node:
	var s := _stream(name)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif s is AudioStreamOggVorbis:
		s.loop = true
	if at == Vector3.INF:
		var flat := AudioStreamPlayer.new()
		flat.stream = s
		flat.volume_db = db
		(parent if parent else get_tree().current_scene).add_child(flat)
		flat.play()
		return flat
	var spatial := AudioStreamPlayer3D.new()
	spatial.unit_size = 1.5
	spatial.stream = s
	spatial.volume_db = db
	(parent if parent else get_tree().current_scene).add_child(spatial)
	spatial.global_position = at
	spatial.play()
	return spatial


## Musique de fond, en fondu enchaîné : « music_house » (la maison la nuit), « music_tension »
## (l'entité est là). Nom vide = silence. Continue de jouer dans les menus.
func music(name: String, db := -12.0, fade := 3.0) -> void:
	if name == _music_now:
		if name != "" and _music.has(name):
			create_tween().tween_property(_music[name], "volume_db", db, fade)
		return
	if _music_now != "" and _music.has(_music_now):
		var old: AudioStreamPlayer = _music[_music_now]
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.tween_callback(old.stop)
	_music_now = name
	if name == "":
		return
	if not _music.has(name):
		var p := AudioStreamPlayer.new()
		var st := _stream(name)
		if st is AudioStreamOggVorbis:
			st.loop = true
		p.stream = st
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_music[name] = p
	var cur: AudioStreamPlayer = _music[name]
	cur.volume_db = -60.0
	cur.play()
	create_tween().tween_property(cur, "volume_db", db, fade)


## Coup de sursaut (à utiliser avec parcimonie).
func sting(db := -2.0) -> void:
	play("sting", db, 1.0)
