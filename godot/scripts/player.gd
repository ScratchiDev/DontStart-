extends CharacterBody3D
## Joueur à la première personne : souris, ZQSD/WASD (touches physiques), course, accroupi,
## balancement de la tête, bruits de pas, lampe de poche, rayon d'interaction, position assise.

signal looking_at(target: Interactable)

const WALK := 1.8
const RUN := 2.9
const CROUCH := 0.95
const EYE := 1.58
const EYE_CROUCH := 1.0
const GRAVITY := 9.8

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var flashlight: SpotLight3D = $Head/Camera/Flashlight
@onready var ray: RayCast3D = $Head/Camera/Ray
@onready var steps: AudioStreamPlayer = $Steps

var yaw := 0.0
var pitch := 0.0
var can_move := false
var can_look := false
var seated := false
var seat_yaw := 0.0
var seat_yaw_range := PI * 0.95
var bob := 0.0
var step_phase := 0.0
var eye := EYE
var flash_on := true
var flash_base := 5.0
var current: Interactable = null
var _flash_before_sit := true
var rug_rect := Rect2(-1.1, -0.25, 2.4, 1.5)   # x, z, largeur, profondeur : le tapis étouffe les pas (sans maison)
## Qui connaît le sol (House : floor_kind_at(pos) -> "parquet", "moquette", "carrelage" ou "tapis").
var floor_provider: Object

var _wood: Array[AudioStream] = []
var _carpet: Array[AudioStream] = []
var _tile: Array[AudioStream] = []


func _ready() -> void:
	for i in 5:
		_wood.append(load("res://assets/audio/footstep_wood_00%d.ogg" % i))
	for i in 3:
		_carpet.append(load("res://assets/audio/footstep_carpet_00%d.ogg" % i))
	for i in 5:
		_tile.append(load("res://assets/audio/footstep0%d.ogg" % i))
	flash_base = flashlight.light_energy
	# la couche 11 (« flux uniquement ») n'est vue que par les caméras de flux, jamais par le joueur
	camera.set_cull_mask_value(Builder.LAYER_FEED_ONLY, false)


func set_look(new_yaw: float, new_pitch := 0.0) -> void:
	yaw = new_yaw
	pitch = new_pitch
	_apply_look()


func _apply_look() -> void:
	rotation.y = yaw
	head.rotation.x = pitch


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and can_look and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * Game.mouse_sensitivity
		pitch -= event.relative.y * Game.mouse_sensitivity
		pitch = clampf(pitch, -1.35, 1.35)
		if seated:
			var d := wrapf(yaw - seat_yaw, -PI, PI)
			yaw = seat_yaw + clampf(d, -seat_yaw_range, seat_yaw_range)
			pitch = clampf(pitch, -0.7, 0.6)
		_apply_look()
	elif event.is_action_pressed("flashlight") and can_move:
		toggle_flashlight()
	elif event.is_action_pressed("interact") and current and can_move and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		current.use()


func toggle_flashlight() -> void:
	flash_on = not flash_on
	flashlight.visible = flash_on
	Sfx.play("metalClick", -14.0, 1.3)


func _physics_process(delta: float) -> void:
	# lampe de poche vivante : léger tremblement, et parfois un raté
	if flash_on:
		var f := 1.0 + sin(Time.get_ticks_msec() * 0.023) * sin(Time.get_ticks_msec() * 0.0071) * 0.05
		if randf() < 0.0025:
			f = 0.15
		flashlight.light_energy = flash_base * f
	if seated:
		velocity = Vector3.ZERO
		_update_ray()
		return
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var crouching := can_move and Input.is_action_pressed("crouch")
	var speed := CROUCH if crouching else (RUN if Input.is_action_pressed("sprint") else WALK)
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, 14.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 14.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# tête : hauteur (accroupi), balancement, pas
	eye = lerpf(eye, EYE_CROUCH if crouching else EYE, 1.0 - exp(-10.0 * delta))
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 0.2 and is_on_floor():
		bob += delta * horizontal * 4.6
		var prev := step_phase
		step_phase = fmod(bob, PI)
		if step_phase < prev:
			_footstep(horizontal)
	else:
		bob = lerpf(bob, roundf(bob / PI) * PI, 1.0 - exp(-8.0 * delta))
	head.position.y = eye + sin(bob * 2.0) * 0.025 * minf(horizontal, 2.5) / 2.0
	head.position.x = cos(bob) * 0.015 * minf(horizontal, 2.5) / 2.0
	camera.rotation.z = sin(bob) * 0.006
	_update_ray()


## Le sol sous les pieds : demandé à la maison ; sans maison, le tapis de la chambre.
func floor_kind() -> String:
	var p := global_position
	if floor_provider and floor_provider.has_method("floor_kind_at"):
		return floor_provider.floor_kind_at(p)
	return "tapis" if rug_rect.has_point(Vector2(p.x, p.z)) else "parquet"


func _footstep(speed: float) -> void:
	var kind := floor_kind()
	var list := _wood
	var db := -9.0
	var pitch := randf_range(0.88, 1.05)
	match kind:
		"moquette", "tapis":
			list = _carpet
			db = -13.0
		"carrelage":
			list = _tile
			db = -12.0
			pitch = randf_range(1.05, 1.2)
	steps.stream = list[randi() % list.size()]
	steps.pitch_scale = pitch
	steps.volume_db = db + (2.0 if speed > 2.5 else 0.0)
	steps.play()


## Angle (en degrés) entre la direction du regard et la direction vers le point p.
func aim_angle_to(p: Vector3) -> float:
	var from := camera.global_position
	var to := p - from
	if to.length_squared() < 0.000001:
		return 0.0
	var fwd := -camera.global_transform.basis.z
	return rad_to_deg(fwd.angle_to(to))


## Le joueur regarde-t-il le point p, à moins de max_deg degrés du centre et à moins de max_dist mètres ?
func looking_at_point(p: Vector3, max_deg: float, max_dist := INF) -> bool:
	if camera.global_position.distance_to(p) > max_dist:
		return false
	return aim_angle_to(p) <= max_deg


func _update_ray() -> void:
	var found: Interactable = null
	if ray.is_colliding():
		var it := ray.get_collider() as Interactable
		if it and it.enabled:
			var dist := ray.global_position.distance_to(ray.get_collision_point())
			if dist <= it.reach:
				found = it
	if found != current:
		current = found
		looking_at.emit(current)


## S'assoit : la caméra glisse jusqu'à la place assise, regard limité autour de l'écran.
func sit(seat_pos: Vector3, look_at_point: Vector3, duration := 1.6) -> void:
	can_move = false
	can_look = false
	$Collision.disabled = true
	_flash_before_sit = flash_on
	if flash_on:
		toggle_flashlight()   # assis, seul l'écran éclaire la pièce
	var from_pos := global_position
	var from_yaw := yaw
	var from_pitch := pitch
	var from_eye := head.position.y
	var flat := look_at_point - seat_pos
	var target_yaw := atan2(-flat.x, -flat.z)
	var seat_eye := 1.12
	var target_pitch := atan2(look_at_point.y - (seat_pos.y + seat_eye), Vector2(flat.x, flat.z).length())
	var d_yaw := wrapf(target_yaw - from_yaw, -PI, PI)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float) -> void:
		global_position = from_pos.lerp(seat_pos, k)
		head.position = Vector3(0, lerpf(from_eye, seat_eye, k), 0)
		set_look(from_yaw + d_yaw * k, lerpf(from_pitch, target_pitch, k))
		camera.fov = lerpf(72.0, 46.0, k), 0.0, 1.0, duration)
	await tw.finished
	seated = true
	seat_yaw = yaw
	can_look = true


func stand(at: Vector3, new_yaw: float) -> void:
	seated = false
	$Collision.disabled = false
	global_position = at
	set_look(new_yaw, 0.0)
	head.position = Vector3(0, EYE, 0)
	camera.fov = 72.0
	if _flash_before_sit and not flash_on:
		toggle_flashlight()
	can_move = true
	can_look = true


## Le joueur s'est-il retourné par rapport à l'écran ? (0 = face à l'écran, PI = dos à l'écran)
func turned_away() -> float:
	return absf(wrapf(yaw - seat_yaw, -PI, PI)) if seated else 0.0
