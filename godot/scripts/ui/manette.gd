class_name Manette
extends Node
## Manette (lot V3-INTERFACE), nœud enfant de Game, actif même en pause :
##  - regard au stick droit : converti en InputEventMouseMotion (Input.parse_input_event), que le joueur lit
##    comme la souris (player.gd n'est pas modifié). Zone morte radiale, courbe de réponse, sensibilité et
##    inversion verticale réglables (Game.pad_sensitivity, pad_invert_y, pad_deadzone) ;
##  - dernier périphérique utilisé (clavier et souris, ou manette) : les invites affichent la touche ou le
##    bouton (signal Game.input_device_changed) ; en manette, le curseur de la souris se cache dans les menus.
## Aucun tirage du hasard.

## Device des mouvements de souris fabriqués ici (ils ne font pas repasser l'interface en « clavier »).
const FAKE_DEVICE := 77
## Vitesse de rotation à fond, sensibilité 1 (rad/s) : un demi-tour en 1,2 s environ.
const LOOK_SPEED := 2.6
const CURVE := 1.7               # réponse du stick (au-delà de la zone morte) : précis au centre
const PITCH_K := 0.75            # le vertical tourne un peu moins vite

var pad_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(func(_d: int, connected: bool) -> void:
		if not connected and Input.get_connected_joypads().is_empty():
			_set_pad(false))


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_set_pad(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			_set_pad(true)
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			_set_pad(false)
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_set_pad(false)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device != FAKE_DEVICE and mm.relative.length() > 3.0:
			_set_pad(false)


func _set_pad(v: bool) -> void:
	if v == pad_active:
		return
	pad_active = v
	Game.pad_active = v
	# curseur caché quand on joue à la manette dans un menu (il reviendra au premier mouvement de souris)
	if v and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif not v and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.input_device_changed.emit(v)


## Le stick droit, après la zone morte et la courbe (−1..1 sur chaque axe), toutes manettes confondues.
func look_vector() -> Vector2:
	var v := Vector2.ZERO
	for d in Input.get_connected_joypads():
		v += Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
	return shape(v, Game.pad_deadzone)


## Zone morte radiale, puis courbe de réponse (la direction est gardée).
static func shape(v: Vector2, deadzone: float) -> Vector2:
	var l := v.length()
	if l <= deadzone:
		return Vector2.ZERO
	var k := clampf((l - deadzone) / maxf(1.0 - deadzone, 0.01), 0.0, 1.0)
	return v / l * pow(k, CURVE)


func _process(delta: float) -> void:
	if get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var v := look_vector()
	if v == Vector2.ZERO:
		return
	_set_pad(true)
	if Game.pad_invert_y:
		v.y = -v.y
	# radians voulus pendant cette image → pixels logiques de souris (player.gd : angle = relatif × sensibilité),
	# → pixels de la fenêtre (le viewport ramène le relatif dans la grille 640×360)
	var rad := Vector2(v.x, v.y * PITCH_K) * LOOK_SPEED * Game.pad_sensitivity * delta
	var rel := rad / maxf(Game.mouse_sensitivity, 0.0001)
	var ev := InputEventMouseMotion.new()
	ev.device = FAKE_DEVICE
	ev.relative = rel * _canvas_scale()
	ev.screen_relative = ev.relative
	var vp := get_viewport()
	ev.position = vp.get_visible_rect().size / 2.0 if vp else Vector2.ZERO
	ev.global_position = ev.position
	Input.parse_input_event(ev)


## Échelle fenêtre / grille de l'interface (étirement canvas_items).
func _canvas_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var s := vp.get_final_transform().get_scale()
	return maxf(s.x, 0.0001)
