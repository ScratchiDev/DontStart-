extends Node
## Couche « présence » du joueur (passe « triple A », lot V2-PRESENCE) : ce que le corps fait voir et
## sentir, sans JAMAIS toucher au joueur logique. Nœud « Presence » créé par player._ready (groupe
## « presence » : get_tree().call_group("presence", "add_trauma", v, sursaut)).
##
## Ce qu'elle écrit, et seulement ça :
##  - camera.transform (local, sous Head) : respiration (calée sur le souffle entendu, Sfx.breath_*), impact
##    du talon, roulis de marche et de pas chassés, hochement à l'arrêt, secousses (trauma²), lissage entre
##    deux pas de physique, et la caméra qui rejoint la place debout en 0,9 s après stand() ;
##  - ray.transform = l'inverse exact de camera.transform : le rayon d'interaction reste dans l'axe de Head
##    (la visée logique ne bouge pas : aim_angle_to et looking_at_point lisent Head) ;
##  - flashlight.transform = le POIDS de la lampe (lamp_local()), sauf quand une vue des mains (nœud
##    Head/Camera/Viewmodel visible) pilote la lampe : elle lit alors lamp_rot / lamp_pos ;
##  - flash_factor : les ratés de la lampe, en rafales (lu par player._physics_process).
## Le poids de la lampe : retard sur le regard (ressort : environ 45 ms, 5° au plus, léger dépassement),
## huit à la marche, tenue plus basse et de côté en course, tremblement des mains (stress², et un fond de
## peur), plongée de 1° à l'interrupteur. Ratés : rafales de 3 à 6 battements toutes les 45 à 120 s, et une
## rafale quand l'entité est à moins de 2 m (appareil habité, ou son passage entre deux appareils) ; avec
## « Éclairs adoucis », jamais plus de 3 battements par seconde, et moins profonds.
## Le tout est multiplié par Game.mouvements_camera (0 = la caméra et la lampe de la 0.3.3 ; le lissage
## entre deux pas de physique reste : ce n'est pas un mouvement ajouté). Les secousses de sursaut
## (add_trauma(v, true)) sont coupées par « Sursauts réduits ».
## Coupée en autotest (rien n'est écrit : le jeu testé reste celui d'avant), sauf avec « --presence » : elle
## imprime alors les vérifications « VÉRIF PRÉSENCE P1 » à « P9 » (banc sur une maquette, au démarrage) et
## « VÉRIF PRÉSENCE J1 » à « J3 » (le jeu lui-même, à la sortie).
## Hasard : un FastNoiseLite et un RandomNumberGenerator à graines fixes, et un temps cumulé (somme des
## delta) : mêmes entrées, mêmes images. Aucun tirage du hasard global.

## respiration (repli quand le souffle de Sfx est coupé : sinus de 13 à 33 par minute selon le stress)
const BREATH_POS := 0.0035          # m, haut-bas de la tête au repos
const BREATH_ROT_DEG := 0.12        # tangage au repos
const BREATH_HZ := Vector2(0.22, 0.55)
const IDLE_SWAY_DEG := 0.08         # lacet très lent à l'arrêt (la tête ne tient jamais tout à fait)
## pas
const STEP_V := 0.2                 # m/s : le talon touche le sol (≈ 5 mm de chute, remontée en 0,2 s)
const STEP_V_RUN := 0.1             # en plus, de la marche à la course
const STEP_NOD_DEG := 0.35          # tangage pour 6 mm de chute
const LEAN_DEG := 1.1               # roulis en pas chassés, à la vitesse de course
const WALK_ROLL := 0.006            # rad : roulis de marche (celui de la 0.3.3)
const STOP_NOD_DEG := 0.4           # hochement quand on s'arrête (le corps continue un peu)
## secousses
const SHAKE_DEG := Vector3(1.6, 1.2, 2.2)
const SHAKE_POS := 0.012
const TRAUMA_DECAY := 1.1
const STING_TRAUMA := 0.35          # Sfx.stung (un sursaut)
## bornes de sûreté (vérifiées par « --presence »)
const MAX_OFFSET_POS := 0.03
const MAX_OFFSET_DEG := 3.0
## suspension : assis (la moitié de la respiration seulement), scènes écrites (can_look faux)
const SUSPEND_RATE := 10.0          # 1/s (≈ 0,3 s)
## lissage entre deux pas de physique ; la caméra qui rejoint la place debout
const INTERP_RESET := 0.5           # m : au-delà, c'est une téléportation (aucun lissage)
const STAND_BLEND := 0.9            # s
const STAND_BLEND_MAX := 1.5        # m : plus loin (reprise d'une sauvegarde), on coupe
## lampe : ressort du retard (rad), huit, course, tremblement, interrupteur
const LAG_K := 700.0                # 1/s² (ω ≈ 26 rad/s)
const LAG_C := 31.5                 # 1/s : retard ≈ LAG_C / LAG_K = 45 ms, amortissement 0,6 (dépassement ≈ 9 %)
const LAG_MAX_DEG := 5.0
const LOOK_CUT := 0.35              # rad en une image : une coupe (set_look, téléportation) : pas de retard
const WALK_SWAY_DEG := Vector2(0.9, 0.55)     # lacet, tangage
const WALK_BOB_POS := 0.004                    # m : la lampe monte et descend avec le pas
const SPRINT_DEG := Vector2(-4.0, -7.0)        # lacet (vers l'extérieur), tangage (vers le sol)
const SPRINT_POS := Vector3(0.012, -0.045, 0.03)
const SPRINT_SWING_DEG := 1.6                  # le bras qui balance en course
const TREMOR_DEG := 0.55            # au stress maximal (stress²)
const FEAR_TREMOR := 0.35           # fond : part du tremblement selon Game.peur (de 30 à 100)
const TREMOR_HZ := 9.0
const TOGGLE_DIP_DEG := 1.0
## ratés de la lampe
const BURST_EVERY := Vector2(45.0, 120.0)
const BURST_BEATS := Vector2i(3, 6)
const BURST_NEAR := 2.0             # m : l'entité à moins de 2 m
const BURST_NEAR_OUT := 2.6         # (hystérésis)
const SOFT_BEAT := 0.34             # s : « Éclairs adoucis », au plus 3 battements par seconde
const NEAR_POLL := 0.25

var game: Object                    # Game (autoload) ; un faux au banc
var player: Node3D
var head: Node3D
var camera: Node3D
var flashlight: Node3D
var ray: Node3D
var flash_rest := Transform3D.IDENTITY
var enabled := false
var amount := 1.0
var trauma := 0.0
## Mouvement ajouté à la caméra (repère de Head), après les bornes et × amount.
var cosmetic := Transform3D.IDENTITY
## Transformation écrite dans camera.transform (cosmetic + lissage + retour debout).
var camera_local := Transform3D.IDENTITY
## Poids de la lampe, repère de la caméra, autour de la prise (la tête de la lampe pour la SpotLight3D,
## le poing pour une vue des mains) : rotation (rad ; x tangage, y lacet, z roulis ; Basis.from_euler)
## et décalage (m). × amount. lamp_local(rest) = Transform3D(Basis.from_euler(lamp_rot) * rest.basis,
## rest.origin + lamp_pos).
var lamp_rot := Vector3.ZERO
var lamp_pos := Vector3.ZERO
## Puissance de la lampe (1, ou moins pendant un raté) : multiplie son énergie (player._physics_process).
var flash_factor := 1.0

var _t := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _w_breath := 1.0
var _w_move := 1.0
var _bphase := 0.0
var _lung := 0.5
var _dip := 0.0
var _dip_v := 0.0
var _lean := 0.0
var _vz_prev := 0.0
var _nod := 0.0
var _nod_v := 0.0
var _walk := 0.0
var _sprint := 0.0
var _prev_look := Vector2.INF
var _lag := Vector2.ZERO
var _lag_v := Vector2.ZERO
var _tdip := 0.0
var _tdip_v := 0.0
var _burst_next := 60.0
var _beats: Array = []              # [début, fin, niveau] en secondes depuis le début de la rafale
var _burst_t := -1.0
var _near := false
var _near_poll := 0.0
var _haunt_linked := false
## lissage : positions aux deux derniers pas de physique (corps : monde ; tête : repère du joueur)
var _body_prev := Vector3.INF
var _body_cur := Vector3.INF
var _head_prev := Vector3.ZERO
var _head_cur := Vector3.ZERO
var _smooth := Vector3.ZERO
var _blend_from := Transform3D.IDENTITY
var _blend_left := 0.0
var _late: Node
## suivi en jeu (autotest --presence) : J1 visée = Head, J2 corps intact, J3 bornes
var _monitor := false
var _mon := {"frames": 0, "ray": 0.0, "body": 0.0, "pos": 0.0, "deg": 0.0}
var _mon_failed := {}
static var _bench_done := false


## Le joueur réel (player.gd, dans _ready) : ses nœuds, Game, et l'activation.
func setup(p: Node3D) -> void:
	_rig(p, p.get_node("Head"), p.get_node("Head/Camera"), p.get_node("Head/Camera/Flashlight"), p.get_node("Head/Camera/Ray"))
	game = Game
	var args := OS.get_cmdline_user_args()
	enabled = not Game.autotest or args.has("--presence")
	_monitor = enabled and Game.autotest
	process_priority = -10              # avant la vue des mains (qui lit la caméra et la lampe)
	process_physics_priority = 100      # après le joueur : la position de ce pas de physique
	add_to_group("presence")
	if enabled:
		_late = _Late.new()
		_late.name = "Lampe"
		_late.presence = self
		add_child(_late)
		if Sfx.has_signal("stung") and not Sfx.stung.is_connected(_on_sting):
			Sfx.stung.connect(_on_sting)
	if _monitor and not _bench_done:
		_bench_done = true
		for line in bench():
			print(line)


func _rig(p: Node3D, h: Node3D, c: Node3D, f: Node3D, r: Node3D) -> void:
	player = p
	head = h
	camera = c
	flashlight = f
	ray = r
	flash_rest = f.transform
	_noise.seed = 7
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_rng.seed = 31213
	_burst_next = _rng.randf_range(BURST_EVERY.x, BURST_EVERY.y)


# ------------------------------------------------------------------ API

## Secousse (0..1, s'additionne, plafonnée à 1). scare = true : un sursaut, coupé par « Sursauts réduits ».
func add_trauma(v: float, scare := false) -> void:
	if not enabled or (scare and bool(game.get("reduced_scares"))):
		return
	trauma = clampf(trauma + v, 0.0, 1.0)


## Le talon touche le sol (player._footstep, vitesse horizontale en m/s).
func step_impact(speed: float) -> void:
	_dip_v -= STEP_V + STEP_V_RUN * clampf((speed - 1.8) / 1.1, 0.0, 1.0)


## Interrupteur de la lampe : elle plonge de 1° et revient.
func on_toggle(_on: bool) -> void:
	_tdip_v -= deg_to_rad(TOGGLE_DIP_DEG) * 26.0


## Une rafale de ratés (beats = 0 : tirée au hasard propre).
func burst(beats := 0, strong := false) -> void:
	var n := beats if beats > 0 else _rng.randi_range(BURST_BEATS.x, BURST_BEATS.y)
	var soft := bool(game.get("soft_flashes"))
	_beats.clear()
	var t := 0.0
	if soft:
		n = mini(n, 3)
	for i in n:
		var off := _rng.randf_range(0.025, 0.07)
		var lvl := _rng.randf_range(0.05, 0.3) if strong else _rng.randf_range(0.12, 0.45)
		if soft:
			lvl = maxf(lvl, 0.5)
		_beats.append([t, t + off, lvl])
		t += off + (SOFT_BEAT - off if soft else _rng.randf_range(0.03, 0.09))
	_burst_t = 0.0


## La caméra était en « from » (globale) : elle y reste puis rejoint sa place en STAND_BLEND s (stand()).
func blend_from(from: Transform3D) -> void:
	if not enabled:
		return
	_track_reset()
	var target := head.global_transform * cosmetic
	if from.origin.distance_to(target.origin) > STAND_BLEND_MAX:
		_blend_left = 0.0
		return
	_blend_from = from
	_blend_left = STAND_BLEND


## Transformation de la lampe à sa place de repos « rest », avec son poids.
func lamp_local(rest := flash_rest) -> Transform3D:
	return Transform3D(Basis.from_euler(lamp_rot) * rest.basis, rest.origin + lamp_pos)


# ------------------------------------------------------------------ chaque image

func _physics_process(_d: float) -> void:
	if not enabled or player == null:
		return
	var b := player.global_position
	if _body_cur == Vector3.INF or b.distance_to(_body_cur) > INTERP_RESET:
		_body_prev = b
		_head_prev = head.position
	else:
		_body_prev = _body_cur
		_head_prev = _head_cur
	_body_cur = b
	_head_cur = head.position


func _process(delta: float) -> void:
	if not enabled or player == null or delta <= 0.0:
		return
	var before := player.global_transform
	var head_before := head.transform
	step(delta, _gather(delta))
	if _monitor:
		_watch(before, head_before)


## Les entrées d'une image, lues sur le joueur (le banc fournit les siennes).
func _gather(delta: float) -> Dictionary:
	var vel: Vector3 = player.get("velocity")
	var local := player.global_transform.basis.inverse() * vel
	var inp := {
		"yaw": float(player.get("yaw")), "pitch": float(player.get("pitch")), "bob": float(player.get("bob")),
		"speed": Vector2(vel.x, vel.z).length(), "local_vel": local,
		"stress": float(Game.stress), "peur": float(Game.peur),
		"seated": bool(player.get("seated")), "can_look": bool(player.get("can_look")),
		"smooth": _smooth_offset(),
	}
	if bool(Sfx.get("breath_on")) and Game.phase != "title":
		inp["breath"] = Vector3(float(Sfx.breath_phase), 1.0 if Sfx.breath_inhaling else 0.0, float(Sfx.breath_rate))
		inp["breath_drive"] = float(Sfx.breath_drive)
	_near_poll -= delta
	if _near_poll <= 0.0:
		_near_poll = NEAR_POLL
		_poll_entity()
	return inp


## Décalage du lissage (repère de Head) : la position interpolée entre les deux derniers pas de physique,
## moins la position réelle. Nul si le joueur a été déplacé hors de la physique (téléportation, tween).
func _smooth_offset() -> Vector3:
	if _body_cur == Vector3.INF:
		return Vector3.ZERO
	var b := player.global_position
	if b.distance_to(_body_cur) > 0.001:
		_track_reset()
		return Vector3.ZERO
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	var w := (_body_prev.lerp(_body_cur, f) - b) + player.global_transform.basis * (_head_prev.lerp(_head_cur, f) - head.position)
	if w.length() > INTERP_RESET:
		return Vector3.ZERO
	return head.global_transform.basis.inverse() * w


func _track_reset() -> void:
	if player == null:
		return
	_body_prev = player.global_position
	_body_cur = _body_prev
	_head_prev = head.position
	_head_cur = _head_prev


func step(delta: float, inp: Dictionary) -> void:
	amount = clampf(float(game.get("mouvements_camera")), 0.0, 1.0)
	_t += delta
	var stress := clampf(float(inp.stress), 0.0, 1.0)
	var speed := float(inp.speed)
	var lv: Vector3 = inp.local_vel
	var bob := float(inp.bob)
	var still := 1.0 - clampf(speed / 0.8, 0.0, 1.0)
	var k := 1.0 - exp(-SUSPEND_RATE * delta)
	var seated := bool(inp.seated)
	var looking := bool(inp.can_look)
	_w_breath = lerpf(_w_breath, (0.5 if seated else 1.0) if (looking or seated) else 0.0, k)
	_w_move = lerpf(_w_move, 1.0 if looking and not seated else 0.0, k)
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	# 1. respiration : la poitrine monte à l'inspiration (le souffle entendu), redescend ensuite
	var br := 0.0
	var depth := 1.0 + stress
	if inp.has("breath"):
		var b: Vector3 = inp.breath
		var cycle := 60.0 / maxf(b.z, 6.0)
		_lung = lerpf(_lung, b.y, 1.0 - exp(-delta / (cycle * 0.2)))
		br = _lung * 2.0 - 1.0
		depth = 0.7 + 1.3 * clampf(float(inp.get("breath_drive", stress)), 0.0, 1.0)
	else:
		_bphase += delta * TAU * lerpf(BREATH_HZ.x, BREATH_HZ.y, stress)
		br = sin(_bphase)
	var wb := _w_breath * lerpf(0.35, 1.0, still)
	pos.y += br * BREATH_POS * depth * wb
	rot.x += deg_to_rad(br * BREATH_ROT_DEG * depth) * wb
	rot.y += deg_to_rad(IDLE_SWAY_DEG * sin(_t * TAU * 0.11)) * still * _w_breath
	# 2. impact du talon : ressort amorti
	var n := maxi(1, ceili(delta * 120.0))      # (pas de 1/120 s au plus : stable aux images lentes)
	var h := delta / n
	for i in n:
		_dip_v += (-_dip * 260.0 - _dip_v * 26.0) * h
		_dip += _dip_v * h
	pos.y += clampf(_dip, -0.02, 0.02) * _w_move
	rot.x += _dip / 0.006 * deg_to_rad(STEP_NOD_DEG) * _w_move
	# 3. roulis : pas chassés, et la marche (celui de la 0.3.3)
	var lean_target := -clampf(lv.x / 2.9, -1.0, 1.0) * deg_to_rad(LEAN_DEG)
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-6.0 * delta))
	rot.z += (_lean + sin(bob) * WALK_ROLL) * _w_move
	# 4. hochement à l'arrêt : le corps freine, la tête continue un peu (ressort)
	var acc := (lv.z - _vz_prev) / delta
	_vz_prev = lv.z
	var push := clampf(acc / 14.0, -1.0, 1.0) * 6.0
	for i in n:
		_nod_v += (-_nod * 120.0 - _nod_v * 16.0 + push) * h
		_nod += _nod_v * h
	rot.x -= clampf(_nod, -1.0, 1.0) * deg_to_rad(STOP_NOD_DEG) * _w_move
	# 5. secousses (trauma², bruit cohérent à graine fixe ; jamais suspendues)
	var sh := trauma * trauma
	if sh > 0.0:
		var nk := _t * 18.0
		rot += Vector3(deg_to_rad(SHAKE_DEG.x) * _noise.get_noise_2d(nk, 1.0), deg_to_rad(SHAKE_DEG.y) * _noise.get_noise_2d(nk, 50.0),
			deg_to_rad(SHAKE_DEG.z) * _noise.get_noise_2d(nk, 99.0)) * sh
		pos += Vector3(_noise.get_noise_2d(nk, 150.0), _noise.get_noise_2d(nk, 200.0), 0.0) * SHAKE_POS * sh
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	# bornes de sûreté, puis le réglage « Mouvements de la caméra »
	var lim := deg_to_rad(MAX_OFFSET_DEG)
	pos = pos.limit_length(MAX_OFFSET_POS) * amount
	rot = rot.clamp(Vector3(-lim, -lim, -lim), Vector3(lim, lim, lim)) * amount
	cosmetic = Transform3D(Basis.from_euler(rot), pos)
	# lissage entre deux pas de physique, puis retour à la place debout
	var cam := cosmetic
	cam.origin += inp.get("smooth", Vector3.ZERO)
	if _blend_left > 0.0 and head.is_inside_tree():
		_blend_left = maxf(0.0, _blend_left - delta)
		var e := smoothstep(0.0, 1.0, 1.0 - _blend_left / STAND_BLEND)
		var hg := head.global_transform
		cam = hg.affine_inverse() * _blend_from.interpolate_with(hg * cam, e)
	camera_local = cam
	camera.transform = cam
	# le rayon d'interaction reste exactement dans l'axe de Head
	ray.transform = cam.affine_inverse()
	_update_lamp(delta, inp, stress)
	_update_flicker(delta)


## Le poids de la lampe (lamp_rot, lamp_pos), appliqué par _late_lamp (après la vue des mains).
func _update_lamp(delta: float, inp: Dictionary, stress: float) -> void:
	var look := Vector2(float(inp.yaw), float(inp.pitch))
	if _prev_look == Vector2.INF:
		_prev_look = look
	var d := Vector2(wrapf(look.x - _prev_look.x, -PI, PI), look.y - _prev_look.y)
	_prev_look = look
	if d.length() > LOOK_CUT:
		_lag = Vector2.ZERO
		_lag_v = Vector2.ZERO
	else:
		_lag -= d                         # la lampe reste où elle était, le regard est parti…
	var n := maxi(1, ceili(delta * 120.0))
	var h := delta / n
	for i in n:                           # … et un ressort la ramène (pas de 1/120 s au plus : stable)
		_lag_v += (-_lag * LAG_K - _lag_v * LAG_C) * h
		_lag += _lag_v * h
		_tdip_v += (-_tdip * 500.0 - _tdip_v * 30.0) * h
		_tdip += _tdip_v * h
	var lim := deg_to_rad(LAG_MAX_DEG)
	if absf(_lag.x) > lim:
		_lag.x = signf(_lag.x) * lim
		_lag_v.x = 0.0
	if absf(_lag.y) > lim:
		_lag.y = signf(_lag.y) * lim
		_lag_v.y = 0.0
	var speed := float(inp.speed)
	var bob := float(inp.bob)
	var wm := _w_move
	_walk = lerpf(_walk, clampf(speed / 1.8, 0.0, 1.0) * wm, 1.0 - exp(-5.0 * delta))
	_sprint = lerpf(_sprint, (1.0 if speed > 2.4 else 0.0) * wm, 1.0 - exp(-4.0 * delta))
	var walk_only := _walk * (1.0 - _sprint)
	var yaw := _lag.x + deg_to_rad(WALK_SWAY_DEG.x) * cos(bob) * walk_only \
		+ deg_to_rad(SPRINT_DEG.x) * _sprint + deg_to_rad(SPRINT_SWING_DEG) * sin(bob) * _sprint
	var pitch := _lag.y + deg_to_rad(WALK_SWAY_DEG.y) * sin(bob * 2.0) * walk_only \
		+ deg_to_rad(SPRINT_DEG.y) * _sprint + _tdip
	# tremblement des mains : pics de stress (au carré) et fond de peur
	var fear := smoothstep(30.0, 100.0, float(inp.peur)) * FEAR_TREMOR
	var tr := deg_to_rad(TREMOR_DEG) * maxf(stress * stress, fear)
	if tr > 0.0:
		yaw += tr * _noise.get_noise_2d(_t * TREMOR_HZ, 300.0)
		pitch += tr * _noise.get_noise_2d(_t * TREMOR_HZ, 400.0)
	var roll := _lag.x * 0.5 + deg_to_rad(1.2) * sin(bob) * _sprint
	lamp_rot = Vector3(pitch, yaw, roll) * amount
	lamp_pos = (SPRINT_POS * _sprint + Vector3(0.0, -WALK_BOB_POS * absf(sin(bob)), 0.0) * walk_only) * amount


## Ratés : la rafale en cours, et la prochaine.
func _update_flicker(delta: float) -> void:
	_burst_next -= delta
	if _burst_next <= 0.0:
		_burst_next = _rng.randf_range(BURST_EVERY.x, BURST_EVERY.y)
		burst()
	flash_factor = 1.0
	if _burst_t < 0.0:
		return
	_burst_t += delta
	var done := true
	for bt: Array in _beats:
		if _burst_t < float(bt[1]):
			done = false
		if _burst_t >= float(bt[0]) and _burst_t < float(bt[1]):
			flash_factor = float(bt[2])
	if done:
		_burst_t = -1.0


## Après la vue des mains (process_priority 100) : la lampe reçoit son poids, sauf si les mains la pilotent.
func _late_lamp() -> void:
	if not enabled or flashlight == null:
		return
	var vm := camera.get_node_or_null("Viewmodel") as Node3D
	if vm and vm.visible:
		return
	flashlight.transform = lamp_local()


class _Late extends Node:
	var presence: Node

	func _ready() -> void:
		process_priority = 100

	func _process(_d: float) -> void:
		presence._late_lamp()


# ------------------------------------------------------------------ l'entité près de la lampe

func _poll_entity() -> void:
	var haunt := get_tree().get_first_node_in_group("haunt")
	if haunt == null:
		return
	if not _haunt_linked and haunt.has_signal("moved"):
		haunt.connect("moved", _on_haunt_moved)
		_haunt_linked = true
	var id := str(haunt.get("inhabited_id"))
	var devs: Variant = haunt.get("devices")
	var dev: Node3D = null
	if id != "" and devs is Dictionary and (devs as Dictionary).has(id):
		dev = (devs as Dictionary)[id] as Node3D
	var dist := INF
	if dev and is_instance_valid(dev) and dev.is_inside_tree():
		dist = dev.global_position.distance_to(head.global_position)
	if dist < BURST_NEAR and not _near:
		_near = true
		burst(_rng.randi_range(5, 7), true)
	elif dist > BURST_NEAR_OUT:
		_near = false


func _on_haunt_moved(from_id: String, to_id: String) -> void:
	var haunt := get_tree().get_first_node_in_group("haunt")
	if haunt == null or not enabled:
		return
	var devs: Variant = haunt.get("devices")
	if not devs is Dictionary:
		return
	var a := (devs as Dictionary).get(from_id) as Node3D
	var b := (devs as Dictionary).get(to_id) as Node3D
	if a == null or b == null or not a.is_inside_tree() or not b.is_inside_tree():
		return
	var p := head.global_position
	var ab := b.global_position - a.global_position
	var u := clampf((p - a.global_position).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	if (a.global_position + ab * u).distance_to(p) < BURST_NEAR:
		burst(_rng.randi_range(4, 6), true)


func _on_sting(_db: float) -> void:
	add_trauma(STING_TRAUMA, true)


# ------------------------------------------------------------------ vérifications (--autotest --presence)

## Suivi de chaque image : J1 rayon = Head, J2 corps et tête jamais déplacés par la couche, J3 bornes.
func _watch(before: Transform3D, head_before: Transform3D) -> void:
	_mon.frames += 1
	var hg := head.global_transform
	var rg := ray.global_transform
	var err := (rg.origin - hg.origin).length()
	for i in 3:
		err = maxf(err, (rg.basis[i] - hg.basis[i]).length())
	_mon.ray = maxf(_mon.ray, err)
	var moved := maxf((player.global_transform.origin - before.origin).length(), (head.transform.origin - head_before.origin).length())
	moved = maxf(moved, (player.global_transform.basis.x - before.basis.x).length())
	_mon.body = maxf(_mon.body, moved)
	_mon.pos = maxf(_mon.pos, cosmetic.origin.length())
	_mon.deg = maxf(_mon.deg, rad_to_deg(cosmetic.basis.get_euler().abs()[cosmetic.basis.get_euler().abs().max_axis_index()]))
	if err > 1e-5:
		_fail("J1", "rayon à %s de Head" % _sci(err))
	if moved > 0.0:
		_fail("J2", "corps déplacé de %s" % _sci(moved))
	if _mon.pos > MAX_OFFSET_POS + 1e-6 or _mon.deg > MAX_OFFSET_DEG + 1e-3:
		_fail("J3", "%.4f m, %.3f°" % [_mon.pos, _mon.deg])


## Écriture scientifique courte (« 2.7e-7 ») : le « % » de GDScript n'a pas de %e.
static func _sci(x: float) -> String:
	if x == 0.0:
		return "0"
	var ex := floori(log(absf(x)) / log(10.0))
	return "%.1fe%d" % [x / pow(10.0, ex), ex]


func _fail(id: String, detail: String) -> void:
	if _mon_failed.has(id):
		return
	_mon_failed[id] = true
	print("VÉRIF PRÉSENCE %s ÉCHEC : %s" % [id, detail])


## À la sortie (Game.quit_game met l'arbre en pause) ou au rechargement de la scène : le bilan du suivi.
func _notification(what: int) -> void:
	if not _monitor:
		return
	if (what == NOTIFICATION_PAUSED and bool(Game.get("_quitting"))) or what == NOTIFICATION_PREDELETE:
		_report()


func _report() -> void:
	if _mon.frames == 0 or _mon.has("reported"):
		return
	_mon["reported"] = true
	var n := int(_mon.frames)
	if not _mon_failed.has("J1"):
		print("VÉRIF PRÉSENCE J1 en jeu : visée dans l'axe de Head (%d images, écart max %s) OK" % [n, _sci(_mon.ray)])
	if not _mon_failed.has("J2"):
		print("VÉRIF PRÉSENCE J2 en jeu : corps et tête jamais déplacés par la couche (%d images) OK" % n)
	if not _mon_failed.has("J3"):
		print("VÉRIF PRÉSENCE J3 en jeu : décalage borné (%.4f m, %.2f° au plus) OK" % [_mon.pos, _mon.deg])


# ------------------------------------------------------------------ banc (maquette, sans rendu)

class _FakeGame extends RefCounted:
	var reduced_scares := false
	var soft_flashes := false
	var mouvements_camera := 1.0


## Banc sur une maquette (Head, Camera, Flashlight, Ray en Node3D, hors de tout calcul du jeu) : P1 à P9.
## Renvoie les lignes « VÉRIF PRÉSENCE … ». Aucun effet sur le jeu (maquette libérée à la fin).
func bench() -> Array[String]:
	var out: Array[String] = []
	var host := Node3D.new()
	host.name = "BancPresence"
	host.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(host)
	var r1 := _bench_run(host, 1.0, false, true)
	var r1b := _bench_run(host, 1.0, false, true)
	var r0 := _bench_run(host, 0.0, false, true)
	var rh := _bench_run(host, 0.5, false, true)
	var rr := _bench_run(host, 1.0, true, true)
	var roff := _bench_run(host, 1.0, false, false)
	host.queue_free()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--presence-trace="):
			_write_trace(arg.substr(17), r1)
	var line := func(id: String, ok: bool, what: String, detail: String) -> void:
		out.append("VÉRIF PRÉSENCE %s %s%s" % [id, what, (" OK" if ok else " ÉCHEC : " + detail)])
	line.call("P1", r1.ray < 1e-5, "rayon d'interaction dans l'axe de Head (écart max %s)" % _sci(r1.ray), "écart %s" % _sci(r1.ray))
	line.call("P2", r1.body == 0.0, "joueur logique jamais déplacé", _sci(r1.body))
	line.call("P3", r1.pos <= MAX_OFFSET_POS and r1.deg <= MAX_OFFSET_DEG and r1.pos > 0.002,
		"décalage borné (%.4f m, %.2f° au plus ; ≤ 3 cm, ≤ 3°)" % [r1.pos, r1.deg], "hors bornes ou nul")
	line.call("P4", r1.lamp_rest < 0.05 and r1.lamp_max > 1.0 and r1.lamp_max <= LAG_MAX_DEG + 9.0,
		"lampe : retard et poids (%.2f° au plus), revenue au repos (%.3f°)" % [r1.lamp_max, r1.lamp_rest], "repos %.3f°, max %.2f°" % [r1.lamp_rest, r1.lamp_max])
	line.call("P5", r1.frames == r1b.frames, "reproductible (mêmes entrées, mêmes images)", "les deux passes diffèrent")
	line.call("P6", roff.cam_moved == 0.0 and roff.flash_moved == 0.0 and enabled == (not Game.autotest or OS.get_cmdline_user_args().has("--presence")),
		"couche coupée : rien n'est écrit (autotest sans --presence)", "caméra %s, lampe %s" % [_sci(roff.cam_moved), _sci(roff.flash_moved)])
	line.call("P7", rr.scare_trauma == 0.0 and rr.door_trauma > 0.0 and r1.scare_trauma > 0.5,
		"« Sursauts réduits » : le sursaut ne secoue pas (%.2f), la porte si (%.2f)" % [rr.scare_trauma, rr.door_trauma], "sursaut %.2f" % rr.scare_trauma)
	line.call("P8", r0.pos == 0.0 and r0.deg == 0.0 and r0.lamp_max == 0.0, "« Mouvements de la caméra » à 0 : caméra et lampe de la 0.3.3", "%s m, %s°" % [_sci(r0.pos), _sci(r0.deg)])
	var ratio_p: float = rh.pos / maxf(r1.pos, 1e-9)
	var ratio_d: float = rh.deg / maxf(r1.deg, 1e-9)
	line.call("P9", absf(ratio_p - 0.5) < 0.025 and absf(ratio_d - 0.5) < 0.025, "réglage à 50 %% : décalages divisés par deux (%.3f, %.3f)" % [ratio_p, ratio_d],
		"rapports %.3f, %.3f" % [ratio_p, ratio_d])
	return out


## --presence-trace=<fichier.csv> : la passe de référence du banc, image par image (pour régler à l'œil :
## temps, position de la caméra en mm, angles de la caméra et de la lampe en degrés, puissance de la lampe).
func _write_trace(path: String, r: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("t,cx,cy,cz,cp,cyaw,cr,lp,lyaw,lr,flash")
	for fr: Array in r.frames:
		var c: Transform3D = fr[0]
		var l: Transform3D = fr[1]
		var ce := c.basis.get_euler() * (180.0 / PI)
		var le := l.basis.get_euler() * (180.0 / PI)
		f.store_line("%.4f,%.3f,%.3f,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.3f" % [float(fr[3]), c.origin.x * 1000.0, c.origin.y * 1000.0,
			c.origin.z * 1000.0, ce.x, ce.y, ce.z, le.x, le.y, le.z, float(fr[2])])
	print("PRÉSENCE trace : %s" % path)


## Une passe du banc : 9 s d'entrées fixes (repos, marche avec virage, pas chassés, course sous stress,
## arrêt, sursaut et porte, retour au calme), à 60 images par seconde avec quelques images lentes.
func _bench_run(host: Node3D, amt: float, reduced: bool, on: bool) -> Dictionary:
	var fake := _FakeGame.new()
	fake.mouvements_camera = amt
	fake.reduced_scares = reduced
	var pl := Node3D.new()
	host.add_child(pl)
	pl.position = Vector3(1.0, 0.0, -2.0)
	pl.rotation.y = 0.4
	var h := Node3D.new()
	pl.add_child(h)
	h.position = Vector3(0, 1.58, 0)
	h.rotation.x = -0.1
	var c := Node3D.new()
	h.add_child(c)
	var f := Node3D.new()
	c.add_child(f)
	f.position = Vector3(0.16, -0.16, 0.05)
	var r := Node3D.new()
	c.add_child(r)
	var p: Node = get_script().new()
	p._rig(pl, h, c, f, r)
	p.game = fake
	p.enabled = on
	var res := {"ray": 0.0, "body": 0.0, "pos": 0.0, "deg": 0.0, "lamp_max": 0.0, "lamp_rest": 0.0, "frames": [],
		"scare_trauma": 0.0, "door_trauma": 0.0, "cam_moved": 0.0, "flash_moved": 0.0}
	var body0 := pl.global_transform
	var head0 := h.transform
	var flash0 := f.transform
	var yaw := 0.0
	var pitch := 0.0
	var bob := 0.0
	var phase := 0.0
	var t := 0.0
	var i := 0
	while t < 9.0:
		var dt := 1.0 / 60.0 if i % 97 != 50 else 1.0 / 12.0
		t += dt
		i += 1
		var speed := 0.0
		var lv := Vector3.ZERO
		var stress := 0.0
		if t > 1.0 and t < 3.0:
			speed = 1.8
			lv = Vector3(0, 0, -1.8)
			if t > 1.5 and t < 2.2:
				yaw += deg_to_rad(110.0) * dt
		elif t >= 3.0 and t < 3.8:
			speed = 1.8
			lv = Vector3(1.8, 0, 0)
		elif t >= 3.8 and t < 4.6:
			speed = 2.9
			lv = Vector3(0, 0, -2.9)
			stress = 1.0
			pitch = lerpf(pitch, -0.2, 0.05)
		if speed > 0.2:
			bob += dt * speed * 4.6
			var prev := phase
			phase = fmod(bob, PI)
			if on and phase < prev:
				p.step_impact(speed)
		else:
			bob = lerpf(bob, roundf(bob / PI) * PI, 1.0 - exp(-8.0 * dt))
			pitch = lerpf(pitch, 0.0, 0.05)
		if absf(t - 5.0) < dt * 0.5 + 1e-6:
			p.add_trauma(1.0, true)
			res.scare_trauma = p.trauma
		if absf(t - 6.0) < dt * 0.5 + 1e-6:
			p.trauma = 0.0
			p.add_trauma(0.3, false)
			res.door_trauma = p.trauma
		if absf(t - 6.2) < dt * 0.5 + 1e-6:
			p.on_toggle(true)
		var inp := {"yaw": yaw, "pitch": pitch, "bob": bob, "speed": speed, "local_vel": lv, "stress": stress,
			"peur": 0.0, "seated": false, "can_look": true, "smooth": Vector3.ZERO}
		if on:
			p.step(dt, inp)
			p._late_lamp()
		var hg := h.global_transform
		var rg := r.global_transform
		var err := (rg.origin - hg.origin).length()
		for k in 3:
			err = maxf(err, (rg.basis[k] - hg.basis[k]).length())
		res.ray = maxf(res.ray, err)
		res.body = maxf(res.body, maxf((pl.global_transform.origin - body0.origin).length(), (h.transform.origin - head0.origin).length()))
		var cp: Vector3 = p.cosmetic.origin
		var ce: Vector3 = p.cosmetic.basis.get_euler().abs()
		res.pos = maxf(res.pos, cp.length())
		res.deg = maxf(res.deg, rad_to_deg(maxf(ce.x, maxf(ce.y, ce.z))))
		var le: Vector3 = (p.lamp_rot as Vector3).abs()
		var lamp_deg := rad_to_deg(maxf(le.x, maxf(le.y, le.z)))
		res.lamp_max = maxf(res.lamp_max, lamp_deg)
		res.lamp_rest = lamp_deg
		res.cam_moved = maxf(res.cam_moved, (c.transform.origin.length() + (c.transform.basis.x - Vector3.RIGHT).length()))
		res.flash_moved = maxf(res.flash_moved, (f.transform.origin - flash0.origin).length() + (f.transform.basis.z - flash0.basis.z).length())
		(res.frames as Array).append([c.transform, f.transform, p.flash_factor, t])
	pl.free()
	p.free()
	return res
