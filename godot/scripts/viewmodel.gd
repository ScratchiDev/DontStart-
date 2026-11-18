class_name Viewmodel
extends Node3D
## Les mains du joueur et sa lampe de poche, vues à la première personne. Nœud posé sous la caméra du
## joueur (player.tscn : Head/Camera/Viewmodel) ; le joueur lui passe sa lampe (SpotLight3D) par setup().
##
## Modèles : assets/models/mains/main_<héros>.glb (tools/make_hands.py : main droite MakeHuman, CC0,
## doigts posés en prise autour de la lampe ; manche de sweat ; lampe des années 90). Repère du modèle :
## origine au centre de la prise, -Z = l'avant de la lampe, nœud « Tete » au centre du verre.
##
## Rendu :
##  - couche de rendu LAYER (14) seule : la caméra du joueur la voit ; les caméras de flux (CAM 1 à 4, le
##    miroir), les sondes de reflets et les vues de l'autotest l'excluent ; pas dans la VoxelGI
##    (gi_mode désactivé), pas d'ombre portée ;
##  - jamais dans les murs : Z_CLIP_SCALE de Godot 4.7 (BaseMaterial3D.use_z_clip_scale). Le moteur écrit
##    « clip.z = mix(clip.w, clip.z, s) » dans le sommet (hors passes d'ombre) : avec la profondeur
##    inversée de Godot (plan proche à 1, l'infini à 0), la profondeur de la vue est ramenée dans
##    [1 - s, 1], devant tout ce qui est à plus de near / (1 - s) de l'œil (3,2 cm ici) ; la position à
##    l'écran et l'éclairage (calculé à la vraie position) ne changent pas. Champ de vision propre à la vue
##    (use_fov_override) : la main garde la même taille quel que soit le réglage « Champ de vision » ;
##  - peau : diffusion sous la surface (SSS) et transmittance, coupées en rendu logiciel.
##
## Mouvements (multipliés par Game.mouvements_camera ; aucun en autotest : pose figée, reproductible) :
## retard à la souris, balancement à la marche, respiration, tremblement de la peur (Game.peur), lampe
## levée quand elle s'allume et baissée quand elle s'éteint, recul devant un mur.
## La lampe du joueur part de la tête de la lampe (son faisceau vise le centre de l'image, au loin), sauf
## si les mains sont cachées (réglage « Mains visibles », Game.mains_visibles) : elle reprend alors sa place.

const LAYER := 14
const MODELS := {
	"alexandre": "res://assets/models/mains/main_alexandre.glb",
	"aurelia": "res://assets/models/mains/main_aurelia.glb",
}
const TEX := "res://assets/models/mains/"
## Place de la prise dans le repère de la caméra (m) et orientation de présentation (degrés : tangage,
## lacet) : en bas à droite, la lampe pointée vers l'avant, un peu vers le centre.
const REST_POS := Vector3(0.15, -0.12, -0.38)
const REST_ROT := Vector3(-4.0, 14.0, 0.0)
## Lampe éteinte : baissée et rentrée (bras détendu).
const LOWER_POS := Vector3(0.015, -0.05, 0.03)
const LOWER_ROT := Vector3(-24.0, 4.0, -6.0)
const Z_CLIP := 0.05
const FOV := 62.0
## Distance du point visé par le faisceau (le centre de l'image).
const AIM_DIST := 5.0
## Pose figée (bancs de captures) ; l'autotest fige aussi la pose.
static var figee := false

var player: Node3D
var camera: Camera3D
var light: SpotLight3D
var light_rest := Transform3D.IDENTITY     # place d'origine de la lampe du joueur (sous la caméra)
var pivot: Node3D
var model: Node3D
var head: Node3D
var bounce: OmniLight3D
var hero := ""
var mats := {}
var bulb_mat: StandardMaterial3D

var _lower := 0.0          # 0 = levée, 1 = baissée
var _lag := Vector2.ZERO   # retard (lacet, tangage), en radians
var _lag_v := Vector2.ZERO
var _last_look := Vector2.INF
var _t := 0.0
var _retreat := 0.0
var _bob_amp := 0.0


func _ready() -> void:
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	bounce = OmniLight3D.new()
	bounce.name = "Rebond"
	bounce.light_color = Color(1.0, 0.86, 0.68)
	bounce.light_energy = 0.0
	bounce.omni_range = 0.7
	bounce.omni_attenuation = 1.4
	bounce.light_specular = 0.25
	bounce.shadow_enabled = false
	bounce.light_cull_mask = 1 << (LAYER - 1)     # n'éclaire que la main et la lampe
	bounce.layers = 1 << (LAYER - 1)
	bounce.light_bake_mode = Light3D.BAKE_DISABLED
	pivot.add_child(bounce)
	bounce.position = Vector3(-0.03, 0.06, -0.30)


## Branche la vue sur le joueur : sa caméra (parent) et sa lampe de poche.
func setup(p: Node3D, cam: Camera3D, flash: SpotLight3D) -> void:
	player = p
	camera = cam
	light = flash
	light_rest = flash.transform
	_load_hero()


func _load_hero() -> void:
	var h := Game.hero if MODELS.has(Game.hero) else "alexandre"
	if h == hero and model:
		return
	hero = h
	if model:
		model.queue_free()
		model = null
	var ps := load(MODELS[h]) as PackedScene
	if ps == null:
		push_warning("Viewmodel : modèle introuvable " + MODELS[h])
		return
	model = ps.instantiate() as Node3D
	model.name = "Modele"
	pivot.add_child(model)
	head = model.get_node_or_null("Tete") as Node3D
	_apply_materials()


# ------------------------------------------------------------------ matières

func _tex(name: String) -> Texture2D:
	var p := TEX + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _base(m: BaseMaterial3D) -> BaseMaterial3D:
	m.use_z_clip_scale = true
	m.z_clip_scale = Z_CLIP
	m.use_fov_override = true
	m.fov_override = FOV
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _skin_mat() -> BaseMaterial3D:
	var m := ORMMaterial3D.new()
	_base(m)
	m.resource_name = "peau"
	var a := _tex("peau_%s_albedo.jpg" % hero)
	if a:
		m.albedo_texture = a
	else:
		m.albedo_color = Color(0.78, 0.56, 0.46)
	var n := _tex("peau_%s_normal.png" % hero)
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 1.0
	var o := _tex("peau_%s_orm.jpg" % hero)
	if o:
		m.orm_texture = o
		m.ao_enabled = true
		m.ao_light_affect = 0.35
	else:
		m.roughness = 0.5
	m.metallic = 0.0
	m.metallic_specular = 0.38
	if not Main.software_renderer():
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.55
		m.subsurf_scatter_skin_mode = true
		m.subsurf_scatter_transmittance_enabled = true
		m.subsurf_scatter_transmittance_color = Color(0.95, 0.32, 0.2)
		m.subsurf_scatter_transmittance_depth = 0.08
		m.subsurf_scatter_transmittance_boost = 0.15
	return m


func _sleeve_mat() -> BaseMaterial3D:
	var m := StandardMaterial3D.new()
	_base(m)
	m.resource_name = "manche"
	var a := _tex("manche_%s_albedo.jpg" % hero)
	if a:
		m.albedo_texture = a
	else:
		m.albedo_color = Color(0.13, 0.15, 0.19) if hero == "alexandre" else Color(0.24, 0.12, 0.15)
	var n := _tex("manche_%s_normal.png" % hero)
	if n:
		m.normal_enabled = true
		m.normal_texture = n
	m.roughness = 0.92
	m.vertex_color_use_as_albedo = true      # (occlusion des plis, cuite dans les couleurs de sommet)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


func _lamp_mat(kind: String) -> BaseMaterial3D:
	var m: BaseMaterial3D
	match kind:
		"lampe_corps":
			var o := ORMMaterial3D.new()
			var a := _tex("lampe_albedo.jpg")
			if a:
				o.albedo_texture = a
			else:
				o.albedo_color = Color(0.035, 0.035, 0.04)
			var n := _tex("lampe_normal.png")
			if n:
				o.normal_enabled = true
				o.normal_texture = n
			var t := _tex("lampe_%s_orm.jpg" % hero)
			if t:
				o.orm_texture = t
				o.ao_enabled = true
				o.ao_light_affect = 0.3
			else:
				o.roughness = 0.4
				o.metallic = 0.4
			m = o
		"lampe_bouton":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.03, 0.03, 0.03)
			m.roughness = 0.72
		"lampe_reflecteur":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.86, 0.86, 0.84)
			m.metallic = 1.0
			m.roughness = 0.12
		"lampe_verre":
			m = StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.85, 0.9, 0.95, 0.1)
			m.roughness = 0.04
			m.metallic_specular = 0.6
		"lampe_ampoule":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.9, 0.85, 0.75)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.74, 0.44)
			m.emission_energy_multiplier = 0.0
			m.roughness = 0.1
			bulb_mat = m as StandardMaterial3D
		_:
			m = StandardMaterial3D.new()
	_base(m)
	m.resource_name = kind
	return m


func _apply_materials() -> void:
	mats = {}
	for mi in _meshes(model):
		mi.layers = 1 << (LAYER - 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.ignore_occlusion_culling = true
		mi.extra_cull_margin = 0.5
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var nm := src.resource_name if src else ""
			var m: Material
			match mi.name:
				"Main":
					m = _skin_mat()
				"Manche":
					m = _sleeve_mat()
				_:
					m = _lamp_mat(nm)
			mats[nm if nm != "" else String(mi.name)] = m
			mi.set_surface_override_material(s, m)


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


# ------------------------------------------------------------------ mouvements

## La vue est-elle montrée ? (réglage, phase de jeu, joueur assis)
func wanted() -> bool:
	if player == null or not Game.mains_visibles:
		return false
	if bool(player.get("seated")):
		return false
	return Game.phase == "room" or Game.autotest


func _process(delta: float) -> void:
	if player == null:
		return
	if Game.hero != hero:
		_load_hero()
	var show := wanted() and model != null
	visible = show
	if not show:
		if light and light.transform != light_rest and light.get_parent() == camera:
			light.transform = light_rest
		return
	_t += delta
	var frozen := Game.autotest or figee
	var k := 0.0 if frozen else clampf(Game.mouvements_camera, 0.0, 1.0)
	var on := bool(player.get("flash_on"))
	# lampe levée / baissée
	var target_lower := 0.0 if on else 1.0
	if frozen:
		_lower = target_lower
	else:
		_lower = move_toward(_lower, target_lower, delta * (3.2 if on else 2.2))
	var lw := _lower * _lower * (3.0 - 2.0 * _lower)
	# retard à la souris (ressort amorti)
	var look := Vector2(float(player.get("yaw")), float(player.get("pitch")))
	if _last_look == Vector2.INF or frozen:
		_last_look = look
	var d := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y)
	_last_look = look
	if frozen:
		_lag = Vector2.ZERO
		_lag_v = Vector2.ZERO
	else:
		_lag -= d * 0.55 * k
		_lag = _lag.clamp(Vector2(-0.12, -0.09), Vector2(0.12, 0.09))
		var acc := -_lag * 170.0 - _lag_v * 2.0 * sqrt(170.0)
		_lag_v += acc * delta
		_lag += _lag_v * delta
	# marche : balancement
	var vel: Vector3 = player.get("velocity")
	var speed := Vector2(vel.x, vel.z).length()
	_bob_amp = lerpf(_bob_amp, clampf(speed / 2.5, 0.0, 1.0), 1.0 - exp(-6.0 * delta))
	var bob := float(player.get("bob"))
	var bpos := Vector3(cos(bob) * 0.006, -absf(sin(bob)) * 0.007 + 0.0035, 0.0) * _bob_amp * k
	var brot := Vector3(-absf(sin(bob)) * 1.2, cos(bob) * 0.8, cos(bob) * 1.4) * _bob_amp * k
	# respiration
	var br := sin(_t * TAU * 0.23)
	var bpos2 := Vector3(0.0, br * 0.0022, br * 0.001) * k
	var brot2 := Vector3(br * 0.45, 0.0, br * 0.2) * k
	# peur : tremblement (bruit de plusieurs sinus), à partir de 30
	var fear := smoothstep(30.0, 100.0, Game.peur) * k
	var tr := Vector3(
		sin(_t * 31.0) * 0.6 + sin(_t * 47.3 + 1.3) * 0.4,
		sin(_t * 27.1 + 0.7) * 0.6 + sin(_t * 53.9) * 0.4,
		sin(_t * 39.7 + 2.1)) * fear
	# recul devant un mur (la vue passe devant, mais on « rentre » le bras)
	var wall := _wall_distance()
	var want_retreat := clampf((0.5 - wall) / 0.3, 0.0, 1.0)
	_retreat = want_retreat if frozen else move_toward(_retreat, want_retreat, delta * 2.5)
	var pos := REST_POS.lerp(REST_POS + LOWER_POS, lw) + bpos + bpos2 + tr * 0.0012
	pos += Vector3(-0.01, -0.02, 0.07) * _retreat
	var rot := REST_ROT.lerp(REST_ROT + LOWER_ROT, lw) + brot + brot2 + tr * 0.5
	rot += Vector3(8.0, 6.0, 0.0) * _retreat
	rot += Vector3(rad_to_deg(_lag.y), rad_to_deg(_lag.x), rad_to_deg(_lag.x) * 0.6)
	pivot.position = pos
	pivot.rotation_degrees = rot
	_update_light(on, wall)


## Distance du premier obstacle devant la caméra (rayon de 0,8 m), INF sinon.
func _wall_distance() -> float:
	var space := get_world_3d().direct_space_state
	if space == null or camera == null:
		return INF
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	return INF if hit.is_empty() else from.distance_to(hit.position)


## La lampe du joueur part de la tête de la lampe (sans traverser un mur) et vise le centre de l'image.
func _update_light(on: bool, wall: float) -> void:
	if light == null or head == null:
		return
	var cam := camera.global_transform
	var hp := head.global_position
	# (la tête de la lampe peut être au-delà d'un mur tout proche : la lumière reste de ce côté)
	var space := get_world_3d().direct_space_state
	if space:
		var q := PhysicsRayQueryParameters3D.create(cam.origin, hp, 1)
		if player is CollisionObject3D:
			q.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			hp = cam.origin + (hit.position - cam.origin) * 0.85
	var fwd := -cam.basis.z
	# le faisceau suit un peu les mouvements de la main (retard, marche, peur)
	var anim := pivot.transform.basis * Basis.from_euler(REST_ROT * (PI / 180.0)).inverse()
	var dir := (cam.basis * (anim * (cam.basis.inverse() * fwd))).normalized()
	dir = fwd.lerp(dir, 0.6).normalized()
	var aim := cam.origin + dir * AIM_DIST
	var up := cam.basis.y
	light.global_transform = Transform3D(Basis.looking_at(aim - hp, up), hp)
	# l'ampoule et le rebond sur la main suivent la puissance de la lampe
	var base := float(player.get("flash_base"))
	var f := light.light_energy / maxf(base, 0.001) if on and light.visible else 0.0
	if bulb_mat:
		bulb_mat.emission_energy_multiplier = 9.0 * clampf(f, 0.0, 1.5)
	var near := clampf(1.0 - (wall - 0.3) / 1.6, 0.0, 1.0) if wall < INF else 0.0
	bounce.light_energy = (0.05 + 0.35 * near) * clampf(f, 0.0, 1.5)
