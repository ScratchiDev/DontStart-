extends CharacterBody3D
## Joueur à la première personne : souris, ZQSD/WASD (touches physiques), course, accroupi,
## balancement de la tête, bruits de pas, lampe de poche, rayon d'interaction, position assise.
## Passe « triple A » (lot V2-PRESENCE) :
##  - champ de vision : Game.fov (vertical, 55-80°, 62 par défaut), lu à chaque image (le curseur des
##    options agit en direct) ; assis, il se resserre jusqu'à SEAT_FOV ; debout, il revient ;
##  - couche « présence » (scripts/presence.gd, nœud « Presence ») : caméra vivante, poids et ratés de la
##    lampe, lissage entre deux pas de physique ; coupée en autotest (sauf --presence). Le balancement de
##    la tête est multiplié par Game.mouvements_camera ;
##  - la visée logique (aim_angle_to, looking_at_point, le rayon d'interaction) est celle de Head : les
##    mouvements de la caméra ne la changent pas ;
##  - pas talon-plante sans répétition (assets/audio/pas, outil tools/make_pas.py), 8 par sol, joués aux
##    pieds (PasG, PasD : bus « Joueur », la réverbération de la pièce de V2-SON) ; lattes qui grincent
##    (HouseData.LATTES).

signal looking_at(target: Interactable)

const PRESENCE := preload("res://scripts/presence.gd")
const WALK := 1.8
const RUN := 2.9
const CROUCH := 0.95
const EYE := 1.58
const EYE_CROUCH := 1.0
const GRAVITY := 9.8
## Champ de vision assis devant l'écran (vertical) ; le retour debout dure STAND_FOV_TIME s (présence active).
const SEAT_FOV := 46.0
const STAND_FOV_TIME := 0.9
## Pas : assets/audio/pas/<sol>_<n>.wav (make_pas.py), un AudioStreamRandomizer par sol (sans répétition
## immédiate, hauteur ×/÷ 1,08, ±2 dB), volume par sol ; en course plus fort et plus grave, accroupi plus bas.
const PAS_FILE := "res://assets/audio/pas/%s_%d.wav"
const PAS_VARIANTS := 8
## (sons normalisés à -20 dBFS efficaces ; un lecteur 3D centré rend 3 dB de moins qu'un lecteur 2D : le pas
## sur parquet sonne vers -29 dBFS efficaces, comme les pas RPG Audio de la 0.3.3 sur le carrelage)
const PAS_DB := {"parquet": -6.0, "tapis": -8.5, "moquette": -9.5, "carrelage": -5.0}
const PAS_RUN_DB := 2.0
const PAS_RUN_PITCH := 0.94
const PAS_CROUCH_DB := -6.0
const PAS_RANDOM_PITCH := 1.08
const PAS_RANDOM_DB := 2.0
## Les deux pieds, de part et d'autre (repère du joueur) ; une alternance gauche-droite discrète. (Mesuré sur
## la 4.7.2 : le panoramique 3D ne dépend que de la direction horizontale ; un pied à 10 cm du centre est
## donc entièrement d'un côté à panning_strength 2, à 2,5 dB près à 0,5.)
const PAS_FOOT := Vector3(0.1, 0.06, 0.0)
const PAS_PANNING := 0.5
## Lattes (HouseData.LATTES) : grincement, plus bas sous un tapis, puis la lame se tait LATTE_WAIT s.
const LATTE_FILE := "res://assets/audio/pas/latte_%d.wav"
const LATTE_VARIANTS := 6
const LATTE_DB := -8.0
const LATTE_RUG_DB := -4.0
const LATTE_WAIT := 6.0
## Débordement de la lampe (rendu net, vraie carte seulement) : le halo large et faible autour du faisceau
## (une vraie lampe de poche éclaire aussi à côté de son rond) ; sans ombre, pas dans le brouillard.
## Étalonnage final (lot V3-ETALONNAGE) : à 4 % sur 65°, il lavait des murs entiers (mère nuit_b : 22/255
## de médiane avec lui, 9 sans) ; resserré et plus faible, il ne fait plus qu'un liseré autour du rond.
const SPILL_ANGLE := 45.0
const SPILL_ENERGY := 0.012
const SPILL_ATTENUATION := 2.5
const SPILL_RANGE := 6.0
const SPILL_SPECULAR := 0.3
## Puissance de la lampe en rendu net sur vraie carte (× l'énergie de la scène, 5) : le masque de
## l'étalonnage final concentre la lumière dans le point chaud ; le reste du rond suit.
const FLASH_NET_K := 1.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var flashlight: SpotLight3D = $Head/Camera/Flashlight
@onready var ray: RayCast3D = $Head/Camera/Ray
@onready var steps: AudioStreamPlayer = $Steps
## Les mains et la lampe de poche à l'écran (scripts/viewmodel.gd, réglage « Mains visibles ») : la vue
## pilote alors la lampe (sa place, sa visée, le poids de la présence) ; mains cachées, la lampe de V2-PRESENCE.
@onready var viewmodel: Viewmodel = $Head/Camera/Viewmodel

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
var flash_near := 1.0     # baisse de la lampe quand une surface est tout près (sinon tout blanchit)
const FLASH_NEAR_FULL := 2.4     # pleine puissance au-delà de 2,4 m ; plus près, l'éclairement reste
const FLASH_NEAR_MIN := 0.08     # celui d'un mur à 2,4 m (compensation en d²), sans descendre sous 8 %
const FLASH_NEAR_POW_NET := 1.3   # rendu net sur vraie carte : compensation plus douce, et plancher à 18 %
const FLASH_NEAR_MIN_NET := 0.18
## … et 35 % sur l'objet qu'on peut prendre ou utiliser (couche d'interaction) : on doit le voir. (Étalonnage
## final : 25 % et 45 % avant ; un montant de croisée ou un appui de fenêtre peint, à 1 m, restaient écrêtés.)
const FLASH_NEAR_MIN_ITEM_NET := 0.35
## Reflet de la lampe en rendu net sur vraie carte (0,5 par défaut) : les vernis et les peintures laquées à
## moins d'un mètre (appuis, montants, cadres) ne renvoient plus un reflet blanc ; appliqué par Main.
const FLASH_SPECULAR_NET := 0.2
## Rendu net sur vraie carte : rayons dans le rond (angle depuis l'axe) et part de la lumière du centre qu'y
## porte le masque de la lampe (Main.flash_cookie_net : épaule du point chaud ≈ 0,6 vers 9°, couronne ≈ 0,42).
const FLASH_NEAR_EDGE := [[9.0, 0.6], [18.0, 0.42]]
var current: Interactable = null
var _flash_before_sit := true
var rug_rect := Rect2(-1.1, -0.25, 2.4, 1.5)   # x, z, largeur, profondeur : le tapis étouffe les pas (sans maison)
## Qui connaît le sol (House : floor_kind_at(pos) -> "parquet", "moquette", "carrelage" ou "tapis").
var floor_provider: Object
## La couche « présence » (presence.gd) : caméra, poids de la lampe (lamp_rot, lamp_pos), ratés.
var presence: Node
## 0 = debout, 1 = assis (le champ de vision va de Game.fov à SEAT_FOV).
var seat_k := 0.0

var _pas := {}              # sol -> AudioStreamRandomizer
var _latte_stream: AudioStreamRandomizer
var _pas_feet: Array[AudioStreamPlayer3D] = []
var _latte_player: AudioStreamPlayer3D
var _foot := 0
var _clock := 0.0
var _latte_free := {}       # id de latte -> heure (_clock) où elle peut grincer de nouveau
var _rng := RandomNumberGenerator.new()
var _seat_tw: Tween
var _spill: SpotLight3D


func _ready() -> void:
	_build_steps()
	flash_base = flashlight.light_energy
	# la couche 11 (« flux uniquement ») n'est vue que par les caméras de flux, jamais par le joueur
	camera.set_cull_mask_value(Builder.LAYER_FEED_ONLY, false)
	camera.fov = fov_now()
	_rng.seed = 5309
	_build_spill()
	presence = PRESENCE.new()
	presence.name = "Presence"
	add_child(presence)
	presence.setup(self)
	viewmodel.setup(self, camera, flashlight)
	Game.settings_changed.connect(apply_settings)


## Réglages (Game.settings_changed : curseurs « Champ de vision » et « Mouvements de la caméra ») : appliqués
## tout de suite (le champ de vision est aussi relu à chaque image ; la présence relit son réglage à chaque image).
func apply_settings() -> void:
	camera.fov = fov_now()


## Champ de vision voulu maintenant (Game.fov debout, SEAT_FOV assis).
func fov_now() -> float:
	return lerpf(clampf(float(Game.fov), Game.FOV_MIN, Game.FOV_MAX), SEAT_FOV, seat_k)


func _process(_delta: float) -> void:
	var f := fov_now()
	if not is_equal_approx(camera.fov, f):
		camera.fov = f


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
	if presence.enabled:
		# l'interrupteur en deux temps (appui, relâche) et la lampe qui plonge d'un degré
		presence.on_toggle(flash_on)
		get_tree().create_timer(0.075, false).timeout.connect(func() -> void: Sfx.play("metalClick", -21.0, 1.75))


func _physics_process(delta: float) -> void:
	_clock += delta
	# lampe de poche vivante : léger tremblement, et des ratés (en rafales avec la couche « présence » ;
	# sans elle, en autotest, le raté d'une image de la 0.3.3)
	if flash_on:
		var f := 1.0 + sin(Time.get_ticks_msec() * 0.023) * sin(Time.get_ticks_msec() * 0.0071) * 0.05
		if presence.enabled:
			f *= presence.flash_factor
		elif randf() < 0.0025:
			f = 0.15
		flash_near = move_toward(flash_near, _flash_near_target(), delta * 4.0)
		if Qualite.extras_on():
			f *= Main.tune("flash_k", FLASH_NET_K)
		flashlight.light_energy = flash_base * f * flash_near
	_update_spill()
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
	# tête : hauteur (accroupi), balancement (× « Mouvements de la caméra »), pas
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
	var mv := clampf(float(Game.mouvements_camera), 0.0, 1.0)
	head.position.y = eye + sin(bob * 2.0) * 0.025 * minf(horizontal, 2.5) / 2.0 * mv
	head.position.x = cos(bob) * 0.015 * minf(horizontal, 2.5) / 2.0 * mv
	if not presence.enabled:
		camera.rotation.z = sin(bob) * 0.006 * mv     # (sinon : la couche « présence » écrit la caméra)
	_update_ray()


## Le débordement : enfant de la lampe (il suit son poids, son allumage et la vue des mains), coupé en
## rendu logiciel et en style rétro (Qualite.extras_on, relu à chaque pas : on peut basculer en jeu).
func _build_spill() -> void:
	_spill = SpotLight3D.new()
	_spill.name = "Debordement"
	_spill.light_color = flashlight.light_color
	_spill.spot_angle = SPILL_ANGLE
	_spill.spot_angle_attenuation = SPILL_ATTENUATION
	_spill.spot_range = SPILL_RANGE
	_spill.spot_attenuation = flashlight.spot_attenuation
	_spill.shadow_enabled = false
	_spill.light_volumetric_fog_energy = 0.0
	_spill.light_specular = SPILL_SPECULAR
	_spill.light_indirect_energy = 0.0
	_spill.visible = false
	flashlight.add_child(_spill)


func _update_spill() -> void:
	if _spill == null:
		return
	var on := flash_on and Qualite.extras_on()
	if _spill.visible != on:
		_spill.visible = on
	if on:
		_spill.light_energy = flashlight.light_energy * Main.tune("spill", SPILL_ENERGY)
		var sa := Main.tune("spill_angle", SPILL_ANGLE)
		if _spill.spot_angle != sa:
			_spill.spot_angle = sa
		_spill.light_cull_mask = flashlight.light_cull_mask
		_spill.layers = flashlight.layers


## Puissance de la lampe selon la distance de ce qu'elle éclaire (rayon partant de l'œil, dans l'axe de
## la lampe : son retard et son poids compris) : une porte, une faïence brillante à 50 cm ne doivent pas
## virer au blanc (le reflet et le bloom). Rendu net sur vraie carte (lot V3-ETALONNAGE) : le rayon part de
## la lampe elle-même, vers là où elle vise (mains visibles : la vue la place sous la caméra et la fait
## converger sur la surface regardée) ; le rendu logiciel garde le rayon de l'œil.
func _flash_near_target() -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return 1.0
	var from := camera.global_position
	if Qualite.extras_on():
		from = flashlight.global_position
	var to := from - flashlight.global_transform.basis.z.normalized() * FLASH_NEAR_FULL
	# (les objets sans collision « monde », comme la télé sur son meuble, ont leur boîte d'interaction)
	var q := PhysicsRayQueryParameters3D.create(from, to, Builder.LAYER_WORLD | Builder.LAYER_INTERACT, [get_rid()])
	var hit := space.intersect_ray(q)
	if not Qualite.extras_on():
		if hit.is_empty():
			return 1.0
		var d0 := from.distance_to(hit.position) / FLASH_NEAR_FULL
		return clampf(d0 * d0, FLASH_NEAR_MIN, 1.0)
	# rendu net sur vraie carte (AgX et son épaule absorbent le surplus) : l'objet qu'on regarde de près reste
	# éclairé ; plus encore un objet qu'on peut prendre (revues « peur » : la disquette, l'antenne de la télé)
	var k := 1.0
	if not hit.is_empty():
		var d := from.distance_to(hit.position) / FLASH_NEAR_FULL
		var low := FLASH_NEAR_MIN_ITEM_NET if hit.collider is Interactable else FLASH_NEAR_MIN_NET
		k = clampf(pow(d, FLASH_NEAR_POW_NET), low, 1.0)
	# (lot V3-ETALONNAGE) le reste du rond aussi : un appui de fenêtre, un montant de croisée à 50 cm dans la
	# couronne brûlaient quand l'axe passait au loin (06b, 38 : les fenêtres). Quatre rayons par cercle de
	# FLASH_NEAR_EDGE, chacun pondéré par la part de lumière que le masque y porte.
	var b := flashlight.global_transform.basis
	var ax := -b.z.normalized()
	for ring: Array in FLASH_NEAR_EDGE:
		for i in 4:
			var side := (b.x if i < 2 else b.y).normalized() * (1.0 if i % 2 == 0 else -1.0)
			var dir := ax.rotated(side.cross(ax).normalized(), deg_to_rad(float(ring[0])))
			var qe := PhysicsRayQueryParameters3D.create(from, from + dir * FLASH_NEAR_FULL, Builder.LAYER_WORLD, [get_rid()])
			var he := space.intersect_ray(qe)
			if he.is_empty():
				continue
			var de := from.distance_to(he.position) / FLASH_NEAR_FULL
			k = minf(k, clampf(pow(de, FLASH_NEAR_POW_NET) / float(ring[1]), FLASH_NEAR_MIN_NET, 1.0))
	return k


## Le sol sous les pieds : demandé à la maison ; sans maison, le tapis de la chambre.
func floor_kind() -> String:
	var p := global_position
	if floor_provider and floor_provider.has_method("floor_kind_at"):
		return floor_provider.floor_kind_at(p)
	return "tapis" if rug_rect.has_point(Vector2(p.x, p.z)) else "parquet"


## Les sons de pas (un AudioStreamRandomizer par sol) et les lecteurs aux pieds.
func _build_steps() -> void:
	for kind: String in PAS_DB:
		var r := AudioStreamRandomizer.new()
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		r.random_pitch = PAS_RANDOM_PITCH
		r.random_volume_offset_db = PAS_RANDOM_DB
		for i in PAS_VARIANTS:
			var path := PAS_FILE % [kind, i]
			if ResourceLoader.exists(path):
				r.add_stream(-1, load(path), 1.0)
		if r.streams_count == 0:     # (sons pas encore importés : ceux de la 0.3.3)
			var old := {"parquet": "footstep0%d.ogg", "tapis": "footstep_carpet_00%d.ogg", "moquette": "footstep_carpet_00%d.ogg",
				"carrelage": "footstep0%d.ogg"}
			for i in 2:
				r.add_stream(-1, load("res://assets/audio/" + (old[kind] as String) % (i + (5 if kind == "parquet" else 0))), 1.0)
		_pas[kind] = r
	_latte_stream = AudioStreamRandomizer.new()
	_latte_stream.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	_latte_stream.random_pitch = 1.05
	_latte_stream.random_volume_offset_db = 2.0
	for i in LATTE_VARIANTS:
		var path := LATTE_FILE % i
		if ResourceLoader.exists(path):
			_latte_stream.add_stream(-1, load(path), 1.0)
	if _latte_stream.streams_count == 0:
		_latte_stream.add_stream(-1, load("res://assets/audio/creak1.ogg"), 1.0)
	for side in [-1.0, 1.0]:
		_pas_feet.append(_foot_player("PasG" if side < 0.0 else "PasD", Vector3(PAS_FOOT.x * side, PAS_FOOT.y, PAS_FOOT.z)))
	_latte_player = _foot_player("Latte", PAS_FOOT)
	_latte_player.top_level = true       # (la lame reste où elle est)
	_latte_player.stream = _latte_stream


## Un lecteur aux pieds : bus « Joueur » (le son direct et la réverbération de la pièce où l'on est, réglée
## par l'acoustique de V2-SON), sans zone (area_mask 0) ni atténuation : seulement la place gauche-droite.
func _foot_player(n: String, at: Vector3) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.bus = &"Joueur"
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.attenuation_filter_cutoff_hz = 20500.0
	p.panning_strength = PAS_PANNING
	p.max_db = 0.0
	p.area_mask = 0
	add_child(p)
	p.position = at
	Sfx.attach(p, false, false)
	return p


func _footstep(speed: float) -> void:
	var kind := floor_kind()
	if not _pas.has(kind):
		kind = "parquet"
	presence.step_impact(speed)
	var db: float = PAS_DB[kind]
	var pitch := 1.0
	if speed > 2.5:
		db += PAS_RUN_DB
		pitch = PAS_RUN_PITCH
	elif eye < (EYE + EYE_CROUCH) * 0.5:
		db += PAS_CROUCH_DB
	_foot = 1 - _foot
	var p := _pas_feet[_foot]
	p.stream = _pas[kind]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
	if kind == "parquet" or kind == "tapis":
		_latte(kind)


## Une latte qui grince sous le pied (HouseData.LATTES), puis se tait LATTE_WAIT s.
func _latte(kind: String) -> void:
	var at := global_position
	for l: Dictionary in HouseData.LATTES:
		if Vector2(at.x - float(l.x), at.z - float(l.z)).length() > float(l.r):
			continue
		if _clock < float(_latte_free.get(l.id, -1.0)):
			return
		_latte_free[l.id] = _clock + LATTE_WAIT
		_latte_player.global_position = Vector3(float(l.x), PAS_FOOT.y, float(l.z))
		_latte_player.volume_db = LATTE_DB + (LATTE_RUG_DB if kind == "tapis" else 0.0)
		_latte_player.pitch_scale = _rng.randf_range(0.94, 1.05)
		_latte_player.play()
		return


## Angle (en degrés) entre la direction du regard (Head : la visée logique, sans les mouvements de la
## caméra) et la direction vers le point p.
func aim_angle_to(p: Vector3) -> float:
	var eye_t := head.global_transform
	var to := p - eye_t.origin
	if to.length_squared() < 0.000001:
		return 0.0
	var fwd := -eye_t.basis.z
	return rad_to_deg(fwd.angle_to(to))


## Le joueur regarde-t-il le point p, à moins de max_deg degrés du centre et à moins de max_dist mètres ?
func looking_at_point(p: Vector3, max_deg: float, max_dist := INF) -> bool:
	if head.global_position.distance_to(p) > max_dist:
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
	if _seat_tw:
		_seat_tw.kill()
	var from_pos := global_position
	var from_yaw := yaw
	var from_pitch := pitch
	var from_eye := head.position.y
	var from_k := seat_k
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
		seat_k = lerpf(from_k, 1.0, k)
		camera.fov = fov_now(), 0.0, 1.0, duration)
	await tw.finished
	seated = true
	seat_yaw = yaw
	can_look = true


## Se lève : la position logique est posée tout de suite ; avec la couche « présence », la caméra (et le
## champ de vision) rejoignent la place debout en STAND_FOV_TIME s.
func stand(at: Vector3, new_yaw: float) -> void:
	var cam_before := camera.global_transform
	seated = false
	$Collision.disabled = false
	global_position = at
	set_look(new_yaw, 0.0)
	head.position = Vector3(0, EYE, 0)
	if _seat_tw:
		_seat_tw.kill()
	if presence.enabled:
		presence.blend_from(cam_before)
		_seat_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_seat_tw.tween_property(self, "seat_k", 0.0, STAND_FOV_TIME)
	else:
		seat_k = 0.0
	camera.fov = fov_now()
	if _flash_before_sit and not flash_on:
		toggle_flashlight()
	can_move = true
	can_look = true


## Le joueur s'est-il retourné par rapport à l'écran ? (0 = face à l'écran, PI = dos à l'écran)
func turned_away() -> float:
	return absf(wrapf(yaw - seat_yaw, -PI, PI)) if seated else 0.0
