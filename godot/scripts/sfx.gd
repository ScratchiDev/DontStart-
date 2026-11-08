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
