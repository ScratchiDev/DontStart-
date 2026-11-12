class_name Door
extends Node3D
## Porte à panneaux qui pivote sur ses gonds. Le nœud est au centre de l'ouverture, au sol, sur le
## plan médian du mur ; son axe X local longe le mur ; elle s'ouvre du côté +Z local × swing.
## Construite par un Builder (pour partager ses matières). Peut être verrouillée.

signal opened
signal closed
signal tried          # quelqu'un a essayé d'ouvrir alors qu'elle est verrouillée

var width := 0.86
var height := 2.04
var wall_t := 0.1
var swing := 1.0
var hinge_left := true
var open_angle := 1.62
var locked := false
var locked_msg := "Fermée à clé."
var key_id := ""                  # objet de l'inventaire qui la déverrouille (Game.items)
var key_msg := "Tu déverrouilles la porte."
var stuck := 0                    # porte coincée : nombre d'appuis encore nécessaires (« Forcer »)
var glass := false                # porte vitrée (verre cathédrale) : on devine ce qu'il y a derrière
var label_open := "Ouvrir la porte"
var label_close := "Fermer la porte"
var is_open := false
var leaf: Node3D
var it: Interactable
var _tw: Tween


func build(b: Builder) -> void:
	var w := width
	var h := height
	var t := 0.045
	var casing: Material = b.mats.paint
	# chambranles sur les deux faces + habillage de l'épaisseur du mur
	for side in [-1.0, 1.0]:
		var z: float = side * (wall_t / 2.0 + 0.0175)
		b._box(Vector3(0.085, h + 0.1, 0.035), Vector3(-w / 2.0 - 0.042, (h + 0.1) / 2.0, z), casing, false, self)
		b._box(Vector3(0.085, h + 0.1, 0.035), Vector3(w / 2.0 + 0.042, (h + 0.1) / 2.0, z), casing, false, self)
		b._box(Vector3(w + 0.17, 0.09, 0.035), Vector3(0, h + 0.045, z), casing, false, self)
	b._box(Vector3(0.02, h + 0.02, wall_t), Vector3(-w / 2.0 - 0.01, (h + 0.02) / 2.0, 0), casing, false, self)
	b._box(Vector3(0.02, h + 0.02, wall_t), Vector3(w / 2.0 + 0.01, (h + 0.02) / 2.0, 0), casing, false, self)
	b._box(Vector3(w + 0.04, 0.02, wall_t), Vector3(0, h + 0.01, 0), casing, false, self)
	# battant, articulé sur le gond
	leaf = Node3D.new()
	leaf.name = "Leaf"
	var hx := -w / 2.0 if hinge_left else w / 2.0
	leaf.position = Vector3(hx, 0, swing * (wall_t / 2.0 - t / 2.0 - 0.004))
	add_child(leaf)
	var dir := 1.0 if hinge_left else -1.0   # le battant s'étend de ce côté du gond
	var cx := dir * w / 2.0
	if glass:
		# battant à petits bois : bas plein, haut vitré (verre cathédrale dépoli)
		b._box(Vector3(w - 0.008, 1.06, t), Vector3(cx, 0.536, 0), b.mats.door, false, leaf)
		b._box(Vector3(w - 0.008, 0.1, t), Vector3(cx, h - 0.05, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.1, h - 1.16, t), Vector3(dir * 0.05, 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.1, h - 1.16, t), Vector3(dir * (w - 0.058), 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.04, h - 1.16, t * 0.8), Vector3(cx, 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		var pane := b._box(Vector3(w - 0.2, h - 1.16, 0.006), Vector3(cx, 1.07 + (h - 1.16) / 2.0, 0), b.mats.frosted, false, leaf)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		b._box(Vector3(w - 0.008, h - 0.012, t), Vector3(cx, h / 2.0 + 0.006, 0), b.mats.door, false, leaf)
	for face_side in [-1.0, 1.0]:
		var face: float = face_side * (t / 2.0 + 0.005)
		for py in [0.62, 1.58]:
			if glass and py > 1.0:
				continue
			for pu in [0.24, w - 0.24]:
				var ph := 0.78 if py < 1.0 else 0.66
				b._box(Vector3(0.3, ph, 0.01), Vector3(dir * pu, py, face), b.mats.door, false, leaf)
				b._box(Vector3(0.22, ph - 0.08, 0.006), Vector3(dir * pu, py, face + face_side * 0.007), b.mats.door, false, leaf)
		_knob(b, Vector3(dir * (w - 0.075), 1.0, face), face_side)
	# collision qui suit le battant (pousse le joueur au lieu de le traverser)
	var body := AnimatableBody3D.new()
	body.collision_layer = Builder.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, t + 0.02)
	cs.shape = bs
	cs.position = Vector3(cx, h / 2.0, 0)
	body.add_child(cs)
	leaf.add_child(body)
	it = b._interactable(label_open, Vector3(w, h, t + 0.14), Vector3(cx, h / 2.0, 0), leaf)
	it.used.connect(_on_used)


func _knob(b: Builder, at: Vector3, face_side: float) -> void:
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.028
	sm.height = 0.05
	knob.mesh = sm
	knob.material_override = b.mats.metal
	knob.position = at + Vector3(0, 0, face_side * 0.055)
	leaf.add_child(knob)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.009
	cm.bottom_radius = 0.009
	cm.height = 0.05
	neck.mesh = cm
	neck.material_override = b.mats.metal
	neck.rotation.x = PI / 2.0
	neck.position = at + Vector3(0, 0, face_side * 0.025)
	leaf.add_child(neck)
	b._box(Vector3(0.05, 0.09, 0.006), at, b.mats.metal, false, leaf)


func _target_angle() -> float:
	return -swing * open_angle if hinge_left else swing * open_angle


func _on_used(_it: Interactable) -> void:
	if is_open:
		close()
		return
	if locked and key_id != "" and Game.has_item(key_id):
		locked = false
		Sfx.play_at("metalLatch", global_position + Vector3(0, 1.0, 0), -2.0, 0.85)
		Game.hint(key_msg)
		await get_tree().create_timer(0.4, false).timeout
	if locked:
		rattle()
		Game.hint(locked_msg)
		tried.emit()
	elif stuck > 0:
		stuck -= 1
		rattle()
		Sfx.play_at("thud", global_position + Vector3(0, 1.0, 0), -6.0, 0.9)
		if stuck > 0:
			Game.hint(locked_msg)
			it.label = "Forcer la porte"
			tried.emit()
		else:
			open(0.5)
	else:
		open()


func open(seconds := 1.1) -> void:
	if is_open:
		return
	is_open = true
	it.label = label_close
	Sfx.play_at("doorOpen_1", global_position + Vector3(0, 1.0, 0), -4.0)
	Sfx.play_at("creak", global_position + Vector3(0, 1.2, 0), -14.0, 0.8)
	_turn(_target_angle(), seconds)
	opened.emit()


func close(seconds := 0.8) -> void:
	if not is_open:
		return
	is_open = false
	it.label = label_open
	_turn(0.0, seconds)
	get_tree().create_timer(seconds * 0.9).timeout.connect(func() -> void:
		Sfx.play_at("doorClose_1", global_position + Vector3(0, 1.0, 0), -4.0))
	closed.emit()


## Claque la porte (événement de peur).
func slam() -> void:
	is_open = false
	it.label = label_open
	_turn(0.0, 0.18)
	get_tree().create_timer(0.16).timeout.connect(func() -> void:
		Sfx.play_at("thud", global_position + Vector3(0, 1.0, 0), 2.0, 0.8))
	closed.emit()


func rattle() -> void:
	Sfx.play_at("metalLatch", global_position + Vector3(0, 1.0, 0), -2.0)
	var base := leaf.rotation.y
	if _tw:
		_tw.kill()
	_tw = create_tween()
	for k in 6:
		_tw.tween_property(leaf, "rotation:y", base + (0.012 if k % 2 == 0 else -0.012) * swing, 0.05)
	_tw.tween_property(leaf, "rotation:y", base, 0.05)


func _turn(angle: float, seconds: float) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(leaf, "rotation:y", angle, seconds)
