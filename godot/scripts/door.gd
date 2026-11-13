class_name Door
extends Node3D
## Porte à panneaux qui pivote sur ses gonds. Le nœud est au centre de l'ouverture, au sol, sur le
## plan médian du mur ; son axe X local longe le mur ; elle s'ouvre du côté +Z local × swing.
## Construite par un Builder (pour partager ses matières). Peut être verrouillée (avec ou sans clé),
## coincée (« Forcer la porte »), entrouverte (set_ajar), ou fermée de l'autre côté : avec label_locked
## (« Frapper à la porte »), on frappe au lieu d'essayer la poignée (signal knocked, messages knock_msgs).
## Le libellé suit l'état (ouverte, verrouillée sans la clé, coincée) et l'inventaire.

signal opened
signal closed
signal tried          # quelqu'un a essayé d'ouvrir alors qu'elle est verrouillée ou coincée
signal knocked        # on a frappé (porte verrouillée sans clé, avec label_locked) ; knocks = nombre de fois
signal unlocked       # déverrouillée (clé, porte forcée, ou unlock())

## Jeu sous le battant : 2 cm du sol, 8 mm au-dessus du seuil (12 mm) ; le câble réseau d'Alexandre
## passe sous P7 sans être écrasé (autotest B1 : rien de plus haut ne doit être dans la zone du battant).
const LEAF_GAP := 0.02

var door_id := ""                 # « P1 » à « P7 » (posé par la maison)
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
var label_forced := "Forcer la porte"
## Libellé quand elle est verrouillée et qu'on n'a pas sa clé (« Frapper à la porte ») ; vide = label_open.
## Non vide : utiliser la porte frappe trois coups (knock) au lieu d'essayer la poignée.
var label_locked := ""
var knock_msgs: Array = []        # message après chaque série de coups (le dernier se répète ; vide = rien)
var knocks := 0                   # nombre de fois qu'on a frappé
var ajar_deg := 0.0               # entrouverte de tant de degrés (0 = fermée), voir set_ajar
var is_open := false
var leaf: Node3D
var it: Interactable
var _tw: Tween
var _forcing := false             # on a déjà donné un coup d'épaule : le libellé devient « Forcer la porte »
var _knocking := false


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
		b._box(Vector3(w - 0.008, 1.066 - LEAF_GAP, t), Vector3(cx, (1.066 + LEAF_GAP) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(w - 0.008, 0.1, t), Vector3(cx, h - 0.05, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.1, h - 1.16, t), Vector3(dir * 0.05, 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.1, h - 1.16, t), Vector3(dir * (w - 0.058), 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.04, h - 1.16, t * 0.8), Vector3(cx, 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		var pane := b._box(Vector3(w - 0.2, h - 1.16, 0.006), Vector3(cx, 1.07 + (h - 1.16) / 2.0, 0), b.mats.frosted, false, leaf)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		b._box(Vector3(w - 0.008, h - LEAF_GAP, t), Vector3(cx, (h + LEAF_GAP) / 2.0, 0), b.mats.door, false, leaf)
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
	Game.inventory_changed.connect(refresh_label)
	refresh_label()


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


func _has_key() -> bool:
	return key_id != "" and Game.has_item(key_id)


## Libellé de l'interaction selon l'état : « Fermer la porte », « Frapper à la porte » (verrouillée sans
## la clé), « Forcer la porte » (coincée, après un premier coup d'épaule) ou « Ouvrir la porte ».
func refresh_label() -> void:
	if it == null:
		return
	if is_open:
		it.label = label_close
	elif locked and label_locked != "" and not _has_key():
		it.label = label_locked
	elif not locked and stuck > 0 and _forcing:
		it.label = label_forced
	else:
		it.label = label_open


func _on_used(_it: Interactable) -> void:
	if is_open:
		close()
		return
	if locked and _has_key():
		unlock()
		Sfx.play_at("metalLatch", global_position + Vector3(0, 1.0, 0), -2.0, 0.85)
		Game.hint(key_msg)
		await get_tree().create_timer(0.4, false).timeout
	if locked:
		if label_locked != "":
			knock()
			return
		rattle()
		Game.hint(locked_msg)
		tried.emit()
	elif stuck > 0:
		stuck -= 1
		rattle()
		Sfx.play_at("thud", global_position + Vector3(0, 1.0, 0), -6.0, 0.9)
		if stuck > 0:
			_forcing = true
			refresh_label()
			Game.hint(locked_msg)
			tried.emit()
		else:
			unlock()
			open(0.5)
	else:
		open()


## Déverrouille la porte (et la décoince) : elle s'ouvre ensuite normalement.
func unlock() -> void:
	var was := locked or stuck > 0
	locked = false
	stuck = 0
	_forcing = false
	refresh_label()
	if was:
		unlocked.emit()


## Trois coups contre la porte, puis le message suivant de knock_msgs (le dernier se répète).
func knock() -> void:
	if _knocking:
		return
	_knocking = true
	knocks += 1
	var p := global_position + Vector3(0, 1.25, 0)
	for k in 3:
		Sfx.play_at("thud", p, -3.0, 1.2 + 0.05 * k, 3.0)
		await get_tree().create_timer(0.42, false).timeout
	if not is_inside_tree():
		return
	_knocking = false
	if not knock_msgs.is_empty():
		Game.hint(str(knock_msgs[mini(knocks - 1, knock_msgs.size() - 1)]), 5.0)
	knocked.emit()


func open(seconds := 1.1) -> void:
	if is_open:
		return
	is_open = true
	ajar_deg = 0.0
	refresh_label()
	Sfx.play_at("doorOpen_1", global_position + Vector3(0, 1.0, 0), -4.0)
	Sfx.play_at("creak", global_position + Vector3(0, 1.2, 0), -14.0, 0.8)
	_turn(_target_angle(), seconds)
	opened.emit()


func close(seconds := 0.8) -> void:
	if not is_open:
		return
	is_open = false
	ajar_deg = 0.0
	refresh_label()
	_turn(0.0, seconds)
	get_tree().create_timer(seconds * 0.9).timeout.connect(func() -> void:
		Sfx.play_at("doorClose_1", global_position + Vector3(0, 1.0, 0), -4.0))
	closed.emit()


## Claque la porte (événement de peur).
func slam() -> void:
	is_open = false
	ajar_deg = 0.0
	refresh_label()
	_turn(0.0, 0.18)
	get_tree().create_timer(0.16).timeout.connect(func() -> void:
		Sfx.play_at("thud", global_position + Vector3(0, 1.0, 0), 2.0, 0.8))
	closed.emit()


## Entrouverte de « angle_deg » degrés, du côté où elle s'ouvre (P4 : 20°). Elle reste « fermée »
## pour le jeu (libellé « Ouvrir la porte ») ; l'utiliser l'ouvre en grand.
func set_ajar(angle_deg: float, seconds := 0.0) -> void:
	is_open = false
	ajar_deg = angle_deg
	refresh_label()
	var a := _target_angle() * deg_to_rad(angle_deg) / open_angle
	if seconds <= 0.0:
		if _tw:
			_tw.kill()
		leaf.rotation.y = a
	else:
		_turn(a, seconds)


## Ouverte ou fermée tout de suite, sans bruit (restauration d'une sauvegarde). Émet opened / closed.
func set_open_now(on: bool) -> void:
	if _tw:
		_tw.kill()
	is_open = on
	ajar_deg = 0.0
	leaf.rotation.y = _target_angle() if on else 0.0
	refresh_label()
	if on:
		opened.emit()
	else:
		closed.emit()


## Angle d'ouverture actuel du battant, en degrés (0 = fermée).
func leaf_angle_deg() -> float:
	return absf(rad_to_deg(leaf.rotation.y)) if leaf else 0.0


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
