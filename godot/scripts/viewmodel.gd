class_name Viewmodel
extends Node3D
## Les mains du joueur et sa lampe de poche, vues à la première personne. Nœud posé sous la caméra du
## joueur (player.tscn : Head/Camera/Viewmodel) ; le joueur lui passe sa lampe (SpotLight3D) par setup().
##
## Modèles : assets/models/mains/main_<héros>.glb (tools/make_hands.py : main droite MakeHuman, CC0,
## doigts posés en prise autour de la lampe, pouce allongé sur l'interrupteur ; manche de sweat ; lampe
## des années 90 ; bracelet brésilien d'Aurèlia). Repère du modèle : origine au centre de la prise,
## -Z = l'axe de la lampe (vers la tête), +Y = le dos de la main ; nœud « Tete » au centre du verre.
##
## Rendu :
##  - couche de rendu LAYER (14) seule : la caméra du joueur la voit ; les caméras de flux (CAM 1 à 4, le
##    miroir), les sondes de reflets et les vues de l'autotest l'excluent ; pas dans la VoxelGI
##    (gi_mode désactivé), pas d'ombre portée ;
##  - jamais dans les murs : Z_CLIP_SCALE de Godot 4.7 (BaseMaterial3D.use_z_clip_scale). Le moteur écrit
##    « clip.z = mix(clip.w, clip.z, s) » dans le sommet (hors passes d'ombre) : avec la profondeur
##    inversée de Godot (plan proche à 1, l'infini à 0), la profondeur de la vue est ramenée dans
##    [1 - s, 1], devant tout ce qui est à plus de near / (1 - s) de l'œil ; la position à l'écran ne
##    change pas. Champ de vision propre à la vue (use_fov_override) ;
##  - éclairage propre à la vue. L'éclairage se calcule à la vraie place de la main, 45 cm devant l'œil :
##    collée à l'écran de l'ordinateur ou dans une lampe de bureau, elle brûlait (vert fluo devant le PC).
##    Les lumières de la maison de portée < NEAR_RANGE n'éclairent donc plus la couche de la vue ; des
##    lumières de remplacement (PROXY_COUNT, couche de la vue seule) rejouent les plus fortes, vues de
##    l'œil, à PROXY_MIN_DIST au moins de la main, énergie bornée ; une lumière d'appoint douce prend la
##    couleur de l'ambiance ; le « rebond » de la lampe de poche (la lumière renvoyée par ce qu'elle
##    éclaire, teintée par sa matière) sculpte les jointures en lumière rasante. Le soleil, la lune et les
##    lumières de grande portée éclairent la vue normalement ;
##  - peau : diffusion sous la surface (SSS) et transmittance, coupées en rendu logiciel. La diffusion se
##    calcule à la profondeur lue (comprimée par Z_CLIP_SCALE) : sa force est corrigée à chaque image
##    par le rapport profondeur vraie / profondeur lue.
##
## Mouvements (multipliés par Game.mouvements_camera ; aucun en autotest : pose figée, reproductible) :
## retard à la souris, balancement à la marche, respiration, tremblement de la peur (Game.peur), lampe
## levée quand elle s'allume et baissée (tournée vers le sol) quand elle s'éteint, la lampe qui suit le
## regard vers le sol, recul devant un mur, main baissée quand un obstacle est tout près du poing.
##
## La lampe du joueur (SpotLight3D) : l'axe de la lampe à l'écran vise le centre de l'image (à 3-5 m) ;
## la lumière vise ce même point, sur l'axe « tête de la lampe → point visé », mais RECULÉE derrière la
## tête jusqu'à la profondeur de sa place d'origine (sous la caméra). Le rond de lumière, sa taille et son
## énergie sont donc ceux de la 0.3.3 (mains cachées), quelle que soit la pose de la main : partie de la
## tête (60 cm devant l'œil), elle éclairait deux fois moins de surface en regardant le sol et brûlait un
## mur proche. La tête de la lampe reste l'origine visible (ampoule, verre). Elle n'éclaire pas la main.
## Mains cachées (réglage « Mains visibles », Game.mains_visibles) : la lampe reprend sa place exacte.
##
## Équilibre de l'éclairage de la main, mesuré sur l'image (_balance_*) : quelques carrés de 8 px de
## l'image précédente sont copiés sur la carte (lecture asynchrone, sans attente) : autour de la main
## (la scène), sur le dos de la main et sur le pouce. L'appoint monte tant que le dos de la main est plus
## sombre que la scène autour, ou que l'écart pouce / dos dépasse 2,2 ; il redescend si la main est
## nettement plus claire que la scène. Aucune lumière de remplacement ne donne plus de 2 fois la suivante.

const LAYER := 14
const MODELS := {
	"alexandre": "res://assets/models/mains/main_alexandre.glb",
	"aurelia": "res://assets/models/mains/main_aurelia.glb",
}
const TEX := "res://assets/models/mains/"
## Présentation (repère de la caméra, m et degrés : tangage, lacet, roulis ; ordre YXZ) : le poing en bas
## à droite, la lampe vue de trois quarts par-dessus, la tête vers le centre bas de l'image, le pouce
## allongé sur l'interrupteur côté œil, l'avant-bras qui sort en diagonale par le coin bas droit.
## L'axe de la lampe, prolongé, passe à ~60-70 px du centre d'une image de 960 px entre 3 et 5 m (moins de
## 10 % de la largeur) : la lampe vise là où va la lumière. Lampe vue de trois quarts arrière, raccourcie
## par la perspective (la présentation des jeux à lampe torche), pouce allongé sur l'interrupteur côté œil,
## avant-bras qui sort par le bas de l'image ; le poignet de la pose (make_hands.py, POSE) suit.
const REST_POS := Vector3(0.225, -0.185, -0.41)
const REST_ROT := Vector3(3.0, 12.0, 28.0)
## Lampe éteinte : le bras se détend, la lampe pend vers le sol (tête qui sort par le bas de l'image),
## tournée vers l'intérieur : le culot n'est plus face à l'œil.
const LOWER_POS := Vector3(-0.015, -0.035, -0.02)
const LOWER_ROT := Vector3(-26.0, 14.0, -4.0)
## Regard vers le sol (tangage de la caméra de -25° à -60°) : la lampe accompagne le regard (un peu plus
## bas et en avant ; à peine inclinée, l'axe reste près du centre de l'image).
const LOOK_DOWN_POS := Vector3(-0.01, 0.03, -0.01)
const LOOK_DOWN_ROT := Vector3(2.0, 0.0, 0.0)
const Z_CLIP := 0.05
const FOV := 62.0
## Distance du point visé par le faisceau (le centre de l'image).
const AIM_DIST := 5.0
## Diffusion sous la surface de la peau voulue (à la vraie distance).
const SSS_STRENGTH := 0.45
## Lumières de la maison remplacées pour la vue (portée en m), nombre de remplaçantes, distance minimale
## d'une remplaçante à la main (m), énergie maximale (fraction de celle de la lumière d'origine).
const NEAR_RANGE := 3.0
const PROXY_COUNT := 3
const PROXY_MIN_DIST := 0.8
const PROXY_MAX_FACTOR := 0.6
## Un obstacle à moins de CLEARANCE (m) au-delà du poing ou de la tête de la lampe fait baisser la main.
const CLEARANCE := 0.35
## Équilibre mesuré sur l'image : taille d'un carré (px), carrés par lecture (atlas 8 × 4), images entre
## deux lectures en jeu, gain maximal de l'appoint, bornes du rapport dos de la main / scène.
const BAL_PATCH := 8
const BAL_COLS := 8
const BAL_ROWS := 4
const BAL_EVERY := 10
const BAL_GAIN_MAX := 12.0
const BAL_LOW := 0.9
const BAL_HIGH := 1.7
const BAL_CONTRAST := 2.2
## Pose figée (bancs de captures) ; l'autotest fige aussi la pose.
static var figee := false

var player: Node3D
var camera: Camera3D
var light: SpotLight3D
var light_rest := Transform3D.IDENTITY     # place d'origine de la lampe du joueur (sous la caméra)
var light_mask_rest := 0                   # son masque d'éclairage d'origine
var pivot: Node3D
var model: Node3D
var head: Node3D
var bounce: OmniLight3D
var fill: OmniLight3D
var proxies: Array[OmniLight3D] = []
var hero := ""
var mats := {}
var bulb_mat: StandardMaterial3D
var skin_mat: BaseMaterial3D

var _lower := 0.0          # 0 = levée, 1 = baissée
var _lag := Vector2.ZERO   # retard (lacet, tangage), en radians
var _lag_v := Vector2.ZERO
var _last_look := Vector2.INF
var _t := 0.0
var _retreat := 0.0
var _obst := 0.0
var _down := 0.0
var _bob_amp := 0.0
var _near: Array[Light3D] = []         # lumières de la maison qui n'éclairent plus la vue
var _tints := {}                       # teinte des matières touchées par le faisceau (par collisionneur)
var _beam_tint := Color(0.8, 0.7, 0.6)
var _beam_dist := INF
var _sss_gain := 1.0
# équilibre mesuré sur l'image
var _rd: RenderingDevice
var _atlas := RID()
var _atlas_fmt := -1
var _bal_frame := 0
var _bal_pending := false
var _bal_result: Array = []
var _bal_gain := 1.0
var _bal_cap := 1.0                       # facteur appliqué aux remplaçantes (borné par l'écart pouce / dos)
var bal_stats := {}                       # dernière mesure (bancs) : scène, dos, pouce, gain
var balance_on := true                    # (les bancs le coupent pendant leur passe de masque)
var _marks := {}                          # nœuds de mesure du modèle (Dos, Pouce, Culot, Poignet)


func _ready() -> void:
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	# rebond de la lampe de poche : côté tête de lampe, rasant sur les jointures (repère du modèle)
	bounce = _vm_light("Rebond", 1.2)
	bounce.light_color = Color(1.0, 0.86, 0.68)
	bounce.omni_attenuation = 1.2
	bounce.light_specular = 0.05      # (lumière renvoyée par une surface mate : large, presque sans reflet)
	add_child(bounce)
	# appoint doux (couleur de l'ambiance), venu d'en haut, un peu devant la main : il éclaire le dos de la
	# main et le dessus du pouce, laisse le dessous dans l'ombre (du relief, pas un gant éclairé de face)
	fill = _vm_light("Appoint", 1.4)
	fill.light_specular = 0.0             # (lumière d'ambiance : sans reflet)
	add_child(fill)
	fill.position = Vector3(0.0, 0.30, -0.30)
	for i in PROXY_COUNT:
		var p := _vm_light("Proche%d" % i, 2.0)
		p.light_specular = 0.08           # (reflet lilas cireux sous une lumière colorée : presque pas de reflet)
		add_child(p)
		proxies.append(p)


func _vm_light(n: String, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.light_energy = 0.0
	l.omni_range = rng
	l.omni_attenuation = 1.0
	l.shadow_enabled = false
	l.light_cull_mask = 1 << (LAYER - 1)     # n'éclaire que la main, la manche et la lampe
	l.layers = 1 << (LAYER - 1)
	l.light_bake_mode = Light3D.BAKE_DISABLED
	l.light_volumetric_fog_energy = 0.0
	l.visible = false
	return l


## Branche la vue sur le joueur : sa caméra (parent) et sa lampe de poche.
func setup(p: Node3D, cam: Camera3D, flash: SpotLight3D) -> void:
	player = p
	camera = cam
	light = flash
	light_rest = flash.transform
	light_mask_rest = flash.light_cull_mask
	_load_hero()
	_adopt_lights.call_deferred()


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
	_marks = {}
	for k in ["Dos", "Pouce", "Culot", "Poignet"]:
		var n := model.get_node_or_null(k) as Node3D
		if n:
			_marks[k] = n
	_apply_materials()


# ------------------------------------------------------------------ lumières de la maison

## Les lumières de faible portée de la maison n'éclairent plus la couche de la vue (celles d'aujourd'hui,
## puis celles qui arrivent : pièces chargées, appareils allumés…).
func _adopt_lights() -> void:
	if not is_inside_tree():
		return
	for n in get_tree().root.find_children("*", "Light3D", true, false):
		_adopt(n as Light3D)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Light3D and not (n is DirectionalLight3D):
		_adopt.call_deferred(n)


func _adopt(l: Light3D) -> void:
	if not is_instance_valid(l) or l == light or l is DirectionalLight3D or is_ancestor_of(l):
		return
	var r := _range(l)
	if r <= 0.0 or r >= NEAR_RANGE or _near.has(l):
		return
	l.light_cull_mask &= ~(1 << (LAYER - 1))
	_near.append(l)


static func _range(l: Light3D) -> float:
	if l is OmniLight3D:
		return (l as OmniLight3D).omni_range
	if l is SpotLight3D:
		return (l as SpotLight3D).spot_range
	return 0.0


static func _decay(l: Light3D) -> float:
	if l is OmniLight3D:
		return (l as OmniLight3D).omni_attenuation
	if l is SpotLight3D:
		return (l as SpotLight3D).spot_attenuation
	return 1.0


## Affaiblissement de Godot 4 (omni et spot) : fenêtre (1 - (d/r)^4)^2, puis d^-decay.
static func _att(d: float, r: float, decay: float) -> float:
	var nd := d / r
	nd *= nd
	nd *= nd
	nd = maxf(1.0 - nd, 0.0)
	return nd * nd * pow(maxf(d, 0.0001), -decay)


## Part d'un projecteur reçue en un point (cône, bord adouci) ; 1 pour une omni.
static func _cone(l: Light3D, p: Vector3) -> float:
	if not (l is SpotLight3D):
		return 1.0
	var s := l as SpotLight3D
	var to := (p - s.global_position).normalized()
	var c := to.dot(-s.global_transform.basis.z.normalized())
	var c0 := cos(deg_to_rad(s.spot_angle))
	return clampf((c - c0) / maxf(1.0 - c0, 0.001) * 4.0, 0.0, 1.0)


func _ray_hits(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	return space.intersect_ray(q)


## Les remplaçantes : les plus fortes des lumières proches, vues de l'œil (et non de la main), posées
## dans la même direction à PROXY_MIN_DIST au moins de la main, énergie bornée.
func _update_proxies(delta: float) -> void:
	var eye := camera.global_position
	var fist := pivot.global_position
	var cands := []
	var i := 0
	while i < _near.size():
		var l := _near[i]
		if not is_instance_valid(l):
			_near.remove_at(i)
			continue
		i += 1
		if not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		var lp := l.global_position
		var d := eye.distance_to(lp)
		var r := _range(l)
		if d >= r:
			continue
		var e := l.light_energy * _att(d, r, _decay(l)) * _cone(l, eye)
		if e > 0.003:
			cands.append([e, l, d])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var k := 0
	var rays := 0
	var amb := Color(0, 0, 0)
	var amb_w := 0.0
	for c in cands:
		if k >= PROXY_COUNT or rays >= 6:
			break
		var l: Light3D = c[1]
		var d: float = c[2]
		rays += 1
		# (une lumière derrière un mur ne compte pas)
		var hit := _ray_hits(eye, l.global_position)
		if not hit.is_empty() and eye.distance_to(hit.position) < d - 0.15:
			continue
		var dir := (l.global_position - eye) / maxf(d, 0.001)
		var d2 := maxf(d, PROXY_MIN_DIST)
		var p := proxies[k]
		p.global_position = fist + dir * d2
		p.omni_range = d2 + 1.2
		p.light_color = _soft_color(l.light_color, 0.5)
		var want := minf(float(c[0]) / maxf(_att(d2, p.omni_range, 1.0), 0.0001), PROXY_MAX_FACTOR * l.light_energy) * _bal_cap
		p.light_energy = want if figee or Game.autotest else lerpf(p.light_energy, want, 1.0 - exp(-10.0 * delta))
		p.visible = true
		amb += l.light_color * float(c[0])
		amb_w += float(c[0])
		k += 1
	while k < PROXY_COUNT:
		proxies[k].light_energy = move_toward(proxies[k].light_energy, 0.0, delta * 4.0)
		proxies[k].visible = proxies[k].light_energy > 0.001 and not (figee or Game.autotest)
		k += 1
	# appoint : la couleur de l'ambiance (lumière ambiante du monde, mêlée à celle des lampes proches)
	var env := get_world_3d().environment if get_world_3d() else null
	var base := Color(0.35, 0.35, 0.4)
	var lvl := 0.2
	if env:
		base = env.ambient_light_color
		lvl = clampf(env.ambient_light_energy * base.get_luminance() * 6.0, 0.08, 1.0)
	var col := base
	if amb_w > 0.0:
		col = base.lerp(amb / amb_w, clampf(amb_w * 2.0, 0.0, 0.6))
	fill.light_color = _soft_color(Color(col.r, col.g, col.b), 0.3).lightened(0.05)
	fill.light_energy = (0.07 * lvl + 0.05 * clampf(amb_w, 0.0, 1.0)) * _bal_gain
	fill.visible = true
	_limit_proxies()


## Couleur adoucie : mêlée à son gris de même luminance (la peau garde sa teinte sous une lumière verte,
## bleue ou violette).
static func _soft_color(c: Color, k: float) -> Color:
	var l := c.get_luminance()
	return Color(c.r, c.g, c.b).lerp(Color(l, l, l), k)


## Aucune lumière de la vue (remplaçantes, rebond) ne donne à la main plus de 2 fois la suivante
## (l'appoint compte) : pas de pouce brûlant à côté d'un dos de main noir.
func _limit_proxies() -> void:
	var fist := pivot.global_position
	var recv := []
	for l: OmniLight3D in proxies + [bounce, fill]:
		if not l.visible or l.light_energy <= 0.0:
			continue
		var r := l.light_energy * _att(fist.distance_to(l.global_position), l.omni_range, l.omni_attenuation)
		recv.append([r, l])
	if recv.size() < 2:
		return
	recv.sort_custom(func(a, b): return a[0] > b[0])
	for i in range(recv.size() - 1):
		var l: OmniLight3D = recv[i][1]
		var nxt: float = recv[i + 1][0]
		if l != fill and float(recv[i][0]) > 2.0 * nxt and nxt > 0.0:
			l.light_energy *= 2.0 * nxt / float(recv[i][0])
			recv[i][0] = 2.0 * nxt


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
		m.normal_scale = 1.5          # (jointures, plis, pores : lisibles à 45 cm)
	var o := _tex("peau_%s_orm.jpg" % hero)
	if o:
		m.orm_texture = o
		m.ao_enabled = true
		m.ao_light_affect = 0.55      # (creux des doigts, ombre de la lampe : aussi en lumière directe)
	else:
		m.roughness = 0.5
	m.metallic = 0.0
	m.metallic_specular = 0.35          # (rugosité ≥ 0,55 dans la carte ORM : peau mate, pas cireuse)
	if not Main.software_renderer():
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = SSS_STRENGTH
		m.subsurf_scatter_skin_mode = true
		m.subsurf_scatter_transmittance_enabled = true
		m.subsurf_scatter_transmittance_color = Color(0.85, 0.25, 0.16)
		m.subsurf_scatter_transmittance_depth = 0.06
		m.subsurf_scatter_transmittance_boost = 0.0
	skin_mat = m
	return m


func _sleeve_mat() -> BaseMaterial3D:
	var m := StandardMaterial3D.new()
	_base(m)
	m.resource_name = "manche"
	var a := _tex("manche_%s_albedo.jpg" % hero)
	if a:
		m.albedo_texture = a
	else:
		m.albedo_color = Color(0.36, 0.38, 0.44) if hero == "alexandre" else Color(0.48, 0.27, 0.35)
	var n := _tex("manche_%s_normal.jpg" % hero)
	if n:
		m.normal_enabled = true
		m.normal_texture = n
	m.roughness = 0.9
	m.vertex_color_use_as_albedo = true      # (occlusion des plis, cuite dans les couleurs de sommet)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# lustre de tissu, léger : la manche reste un volume la nuit, sans briller plus que la peau le jour
	# (elle est éclairée par les mêmes lumières de la vue que la main)
	m.rim_enabled = true
	m.rim = 0.08
	m.rim_tint = 0.5
	return m


func _bracelet_mat() -> BaseMaterial3D:
	var m := StandardMaterial3D.new()
	_base(m)
	m.resource_name = "bracelet"
	var a := _tex("bracelet_%s_albedo.jpg" % hero)
	if a:
		m.albedo_texture = a
	else:
		m.albedo_color = Color(0.6, 0.2, 0.2)
	var n := _tex("bracelet_%s_normal.png" % hero)
	if n:
		m.normal_enabled = true
		m.normal_texture = n
	m.roughness = 0.88
	m.rim_enabled = true
	m.rim = 0.2
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
				o.albedo_color = Color(0.03, 0.03, 0.03)
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
			m.albedo_color = Color(0.035, 0.035, 0.035)
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
				"Bracelet":
					m = _bracelet_mat()
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
		if light and light.get_parent() == camera:
			if light.transform != light_rest:
				light.transform = light_rest
			light.light_cull_mask = light_mask_rest
		return
	_t += delta
	var frozen := Game.autotest or figee
	var k := 0.0 if frozen else clampf(Game.mouvements_camera, 0.0, 1.0)
	var on := bool(player.get("flash_on"))
	# lampe levée / baissée ; baissée aussi devant un obstacle tout proche du poing
	var obst := _obstacle()
	_obst = obst if frozen else move_toward(_obst, obst, delta * (3.0 if obst > _obst else 1.5))
	var target_lower := maxf(0.0 if on else 1.0, _obst * 0.7)
	if frozen:
		_lower = target_lower
	else:
		_lower = move_toward(_lower, target_lower, delta * (3.2 if target_lower < _lower else 2.2))
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
	# regard vers le sol : la lampe accompagne
	var want_down := clampf((-25.0 - rad_to_deg(look.y)) / 35.0, 0.0, 1.0)
	_down = want_down if frozen else lerpf(_down, want_down, 1.0 - exp(-6.0 * delta))
	var dw := _down * _down * (3.0 - 2.0 * _down)
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
	var pos := REST_POS.lerp(REST_POS + LOWER_POS, lw) + LOOK_DOWN_POS * dw + bpos + bpos2 + tr * 0.0012
	pos += Vector3(-0.01, -0.02, 0.07) * _retreat
	var rot := REST_ROT.lerp(REST_ROT + LOWER_ROT, lw) + LOOK_DOWN_ROT * dw + brot + brot2 + tr * 0.5
	rot += Vector3(8.0, 6.0, 0.0) * _retreat
	rot += Vector3(rad_to_deg(_lag.y), rad_to_deg(_lag.x), rad_to_deg(_lag.x) * 0.6)
	pivot.position = pos
	pivot.rotation_degrees = rot
	_update_sss()
	_update_light(on, wall)
	_update_proxies(delta)
	_balance(delta, frozen)


## Distance du premier obstacle devant la caméra (rayon de 0,8 m), INF sinon.
func _wall_distance() -> float:
	if camera == null:
		return INF
	var from := camera.global_position
	var hit := _ray_hits(from, from - camera.global_transform.basis.z * 0.8)
	return INF if hit.is_empty() else from.distance_to(hit.position)


## Obstacle tout près du poing ou de la tête de la lampe (à leur place de repos, pour ne pas osciller) :
## 0 = rien à moins de CLEARANCE au-delà, 1 = la main doit se baisser.
func _obstacle() -> float:
	if camera == null or head == null:
		return 0.0
	var cam := camera.global_transform
	var rest := Transform3D(Basis.from_euler(REST_ROT * (PI / 180.0)), REST_POS)
	var worst := 0.0
	for p: Vector3 in [Vector3.ZERO, head.position]:
		var target := cam * (rest * p)
		var from := cam.origin
		var dist := from.distance_to(target)
		var dir := (target - from) / maxf(dist, 0.001)
		var hit := _ray_hits(from, target + dir * CLEARANCE)
		if hit.is_empty():
			continue
		var clearance := from.distance_to(hit.position) - dist
		worst = maxf(worst, clampf((CLEARANCE - clearance) / 0.3, 0.0, 1.0))
	return worst


## Diffusion de la peau : la profondeur lue par l'effet est la profondeur comprimée (Z_CLIP_SCALE) ;
## la force est divisée par le rapport profondeur vraie / profondeur lue (la main à ~45 cm y paraît à
## quelques cm), recalculé avec la vraie distance de la main.
func _update_sss() -> void:
	if skin_mat == null or not skin_mat.subsurf_scatter_enabled or camera == null:
		return
	var dtrue := maxf(-pivot.position.z, 0.05)
	var near := camera.near
	var dread := near / (1.0 - Z_CLIP + Z_CLIP * near / dtrue)
	var g := dtrue / maxf(dread, 0.0001)
	if absf(g - _sss_gain) / _sss_gain > 0.03:
		_sss_gain = g
		skin_mat.subsurf_scatter_strength = SSS_STRENGTH / g


## Teinte de la matière d'un collisionneur (sa MeshInstance3D voisine) : la couleur de rebond.
func _tint_of(collider: Object) -> Color:
	if collider == null:
		return Color(0.8, 0.7, 0.6)
	var id := collider.get_instance_id()
	if _tints.has(id):
		return _tints[id]
	var c := Color(0.78, 0.68, 0.56)      # (la maison : bois, papiers peints chauds)
	var n := collider as Node
	var mi: MeshInstance3D = null
	if n:
		if n.get_parent() is MeshInstance3D:
			mi = n.get_parent()
		else:
			for ch in n.get_children():
				if ch is MeshInstance3D:
					mi = ch
					break
			if mi == null and n.get_parent():
				for ch in n.get_parent().get_children():
					if ch is MeshInstance3D:
						mi = ch
						break
	if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
		var m := mi.get_active_material(0) as BaseMaterial3D
		if m:
			var a := m.albedo_color
			if m.albedo_texture:
				a = a * Color(0.78, 0.68, 0.56)
			c = Color(a.r, a.g, a.b)
	var mx := maxf(c.r, maxf(c.g, c.b))
	if mx > 0.0:
		c = c * (0.85 / mx)          # (la teinte, pas la clarté : celle-ci vient de la distance)
	_tints[id] = c
	return c


## La lampe du joueur vise le centre de l'image ; elle est posée sur l'axe « tête de la lampe → point
## visé », reculée jusqu'à la profondeur de sa place d'origine (sous la caméra) : même rond de lumière
## que mains cachées. Sans traverser un mur ; elle n'éclaire pas la main (couche de la vue retirée).
func _update_light(on: bool, wall: float) -> void:
	if light == null or head == null:
		return
	var cam := camera.global_transform
	var hp := head.global_position
	# (la tête de la lampe peut être au-delà d'un mur tout proche : on reste de ce côté)
	var hit := _ray_hits(cam.origin, hp)
	if not hit.is_empty():
		hp = cam.origin + (hit.position - cam.origin) * 0.85
	var fwd := -cam.basis.z
	# le faisceau suit un peu les mouvements de la main (retard, marche, peur)
	var anim := pivot.transform.basis * Basis.from_euler(REST_ROT * (PI / 180.0)).inverse()
	var dir := (cam.basis * (anim * (cam.basis.inverse() * fwd))).normalized()
	dir = fwd.lerp(dir, 0.6).normalized()
	var aim := cam.origin + dir * AIM_DIST
	var up := cam.basis.y
	var axis := (aim - hp).normalized()
	var depth_rest := (cam * light_rest.origin - cam.origin).dot(fwd)
	var back := ((hp - cam.origin).dot(fwd) - depth_rest) / maxf(axis.dot(fwd), 0.3)
	var lp := hp - axis * maxf(back, 0.0)
	var h2 := _ray_hits(cam.origin, lp)
	if not h2.is_empty():
		lp = cam.origin + (h2.position - cam.origin) * 0.8
	light.global_transform = Transform3D(Basis.looking_at(aim - lp, up), lp)
	light.light_cull_mask = light_mask_rest & ~(1 << (LAYER - 1))
	# l'ampoule et le rebond sur la main suivent la puissance de la lampe
	var base := float(player.get("flash_base"))
	var f := light.light_energy / maxf(base, 0.001) if on and light.visible else 0.0
	if bulb_mat:
		bulb_mat.emission_energy_multiplier = 9.0 * clampf(f, 0.0, 1.5)
	# rebond : la lumière renvoyée par ce que le faisceau éclaire (teinte de sa matière, 1/d² borné)
	var bh := _ray_hits(hp, hp + (aim - hp).normalized() * 6.0)
	if bh.is_empty():
		_beam_dist = INF
	else:
		_beam_dist = hp.distance_to(bh.position)
		_beam_tint = _beam_tint.lerp(_soft_color(_tint_of(bh.collider), 0.5), 0.25 if not (figee or Game.autotest) else 1.0)
	var k := 0.0 if _beam_dist == INF else clampf(0.45 / (_beam_dist * _beam_dist + 0.2), 0.0, 1.0)
	var near := clampf(1.0 - (wall - 0.3) / 1.6, 0.0, 1.0) if wall < INF else 0.0
	# (la lumière revient de là où le faisceau éclaire : devant la main, un peu au-dessus ; elle rase le
	# dos de la main et frappe les jointures et les doigts repliés)
	var bdir := (aim - hp).normalized()
	bounce.global_position = pivot.global_position + bdir * 0.38 + cam.basis.y * 0.10 - cam.basis.x * 0.04
	var lc := light.light_color
	bounce.light_color = Color(lc.r * _beam_tint.r, lc.g * _beam_tint.g, lc.b * _beam_tint.b).lightened(0.1)
	bounce.light_energy = (0.22 + 0.4 * maxf(k, near)) * clampf(f, 0.0, 1.5) * lerpf(1.0, _bal_cap, 0.7)
	bounce.visible = bounce.light_energy > 0.0005


# ------------------------------------------------------------------ équilibre mesuré sur l'image

func _exit_tree() -> void:
	if _rd and _atlas.is_valid():
		_rd.free_rid(_atlas)
		_atlas = RID()


## Point du repère de la caméra → pixel, avec la projection de la vue (champ FOV, use_fov_override).
func _vm_pixel(p_cam: Vector3, size: Vector2) -> Vector2:
	var t := tan(deg_to_rad(FOV) * 0.5)
	var asp := size.x / size.y
	var z := maxf(-p_cam.z, 0.01)
	return Vector2((p_cam.x / z / (t * asp) * 0.5 + 0.5) * size.x, (0.5 - p_cam.y / z / t * 0.5) * size.y)


## Rectangle de la vue à l'écran (boîtes des maillages projetées), en pixels.
func _vm_rect(size: Vector2) -> Rect2:
	var inv := camera.global_transform.affine_inverse()
	var r := Rect2()
	var first := true
	for mi in _meshes(model):
		if not mi.visible or mi.mesh == null:
			continue
		var bb := mi.get_aabb()
		var xf := inv * mi.global_transform
		for i in 8:
			var pc := xf * bb.get_endpoint(i)
			if pc.z > -0.05:
				continue        # (le bout de la manche, derrière le plan de l'œil)
			var q := _vm_pixel(pc, size)
			if first:
				r = Rect2(q, Vector2.ZERO)
				first = false
			else:
				r = r.expand(q)
	return r


## Carrés à lire : la scène autour de la vue (à gauche et au-dessus de son rectangle à l'écran), le dos
## de la main, le pouce. Rend [[pixel (Vector2i), "s" | "d" | "p"], …].
func _balance_points(size: Vector2) -> Array:
	var pts := []
	var inv := camera.global_transform.affine_inverse()
	var half := Vector2(BAL_PATCH, BAL_PATCH) * 0.5
	for k in ["Dos", "Pouce"]:
		if _marks.has(k):
			var q := _vm_pixel(inv * (_marks[k] as Node3D).global_position, size)
			pts.append([Vector2i(q - half), "d" if k == "Dos" else "p"])
	var r := _vm_rect(size)
	var m := size.y * 0.035
	var top := clampf(r.position.y, size.y * 0.25, size.y - m)
	var left := clampf(r.position.x, size.x * 0.2, size.x - m)
	# à gauche du rectangle, de son haut au bas de l'image
	for i in 7:
		var y := lerpf(top, size.y - m, float(i) / 6.0)
		pts.append([Vector2i(Vector2(left - m, y) - half), "s"])
		pts.append([Vector2i(Vector2(left - 3.0 * m, y) - half), "s"])
	# au-dessus du rectangle, de sa gauche au bord droit
	for i in 6:
		var x := lerpf(left, size.x - m, float(i) / 5.0)
		pts.append([Vector2i(Vector2(x, top - m) - half), "s"])
		pts.append([Vector2i(Vector2(x, top - 3.0 * m) - half), "s"])
	return pts.slice(0, BAL_COLS * BAL_ROWS)


func _balance(delta: float, frozen: bool) -> void:
	if not balance_on:
		_bal_result = []
		return
	if not _bal_result.is_empty():
		var res := _bal_result
		_bal_result = []
		_balance_apply(res[0], res[1], res[2], frozen, delta)
	_bal_frame += 1
	if _bal_pending or (not frozen and _bal_frame % BAL_EVERY != 0):
		return
	_balance_request()


func _balance_request() -> void:
	if _rd == null:
		_rd = RenderingServer.get_rendering_device()
		if _rd == null:
			return
	var vt := get_viewport().get_texture()
	if vt == null:
		return
	var src := RenderingServer.texture_get_rd_texture(vt.get_rid())
	if not src.is_valid() or not _rd.texture_is_valid(src):
		return
	var f := _rd.texture_get_format(src)
	if f == null or f.width < 64 or f.height < 64:
		return
	if not _atlas.is_valid() or _atlas_fmt != f.format:
		if _atlas.is_valid():
			_rd.free_rid(_atlas)
		var tf := RDTextureFormat.new()
		tf.format = f.format
		tf.width = BAL_PATCH * BAL_COLS
		tf.height = BAL_PATCH * BAL_ROWS
		tf.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		_atlas = _rd.texture_create(tf, RDTextureView.new())
		_atlas_fmt = f.format
		if not _atlas.is_valid():
			return
	var size := Vector2(f.width, f.height)
	var pts := _balance_points(size)
	var hi := Vector2i(f.width - BAL_PATCH, f.height - BAL_PATCH)
	for i in pts.size():
		var p: Vector2i = (pts[i][0] as Vector2i).clamp(Vector2i.ZERO, hi)
		pts[i][0] = p
		_rd.texture_copy(src, _atlas, Vector3(p.x, p.y, 0), Vector3((i % BAL_COLS) * BAL_PATCH, floori(float(i) / BAL_COLS) * BAL_PATCH, 0),
			Vector3(BAL_PATCH, BAL_PATCH, 1), 0, 0, 0, 0)
	_bal_pending = true
	var err := _rd.texture_get_data_async(_atlas, 0, _balance_read.bind(pts, f.format))
	if err != OK:
		_bal_pending = false


func _balance_read(data: PackedByteArray, pts: Array, fmt: int) -> void:
	_bal_pending = false
	_bal_result = [data, pts, fmt]


## Luminance (valeurs affichées, Rec. 709) moyenne d'un carré de l'atlas.
static func _patch_lum(data: PackedByteArray, fmt: int, i: int) -> float:
	var bpp := 8 if fmt == RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT else 4
	var w := BAL_PATCH * BAL_COLS
	var x0 := (i % BAL_COLS) * BAL_PATCH
	var y0 := floori(float(i) / BAL_COLS) * BAL_PATCH
	var s := 0.0
	for y in BAL_PATCH:
		for x in BAL_PATCH:
			var o := ((y0 + y) * w + x0 + x) * bpp
			if o + bpp > data.size():
				return -1.0
			var r: float
			var g: float
			var b: float
			if bpp == 8:
				r = _to_srgb(data.decode_half(o))
				g = _to_srgb(data.decode_half(o + 2))
				b = _to_srgb(data.decode_half(o + 4))
			elif fmt == RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32:
				var v := data.decode_u32(o)
				r = float(v & 1023) / 1023.0
				g = float((v >> 10) & 1023) / 1023.0
				b = float((v >> 20) & 1023) / 1023.0
			else:
				r = data[o] / 255.0
				g = data[o + 1] / 255.0
				b = data[o + 2] / 255.0
			s += 0.2126 * r + 0.7152 * g + 0.0722 * b
	return s / float(BAL_PATCH * BAL_PATCH)


static func _to_srgb(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * 12.92 if x < 0.0031308 else 1.055 * pow(x, 1.0 / 2.4) - 0.055


## Réglage : l'appoint (gain) monte tant que le dos de la main est plus sombre que BAL_LOW × la scène
## autour (médiane) ou que l'écart pouce / dos dépasse BAL_CONTRAST ; il redescend au-dessus de
## BAL_HIGH × la scène. Les remplaçantes baissent (_bal_cap) quand l'écart reste trop fort.
func _balance_apply(data: PackedByteArray, pts: Array, fmt: int, frozen: bool, delta: float) -> void:
	var scene := PackedFloat32Array()
	var back := -1.0
	var thumb := -1.0
	for i in pts.size():
		var l := _patch_lum(data, fmt, i)
		if l < 0.0:
			return
		match String(pts[i][1]):
			"s":
				scene.append(l)
			"d":
				back = l
			"p":
				thumb = l
	if scene.is_empty() or back < 0.0:
		return
	scene.sort()
	var sc := scene[floori(scene.size() * 0.5)]
	var want := 1.0
	var lo := back if thumb < 0.0 else minf(back, thumb)
	var hi := back if thumb < 0.0 else maxf(back, thumb)
	var contrast := hi / maxf(lo, 0.008)
	if back < BAL_LOW * sc:
		want = BAL_LOW * sc / maxf(back, 0.01)
	elif back > BAL_HIGH * sc and back > 0.06:
		want = BAL_HIGH * sc / back
	if contrast > BAL_CONTRAST:
		# (trop d'écart : on baisse d'abord les remplaçantes et le rebond ; l'appoint ne monte que si le dos
		# de la main est aussi plus sombre que la scène)
		_bal_cap = maxf(_bal_cap * 0.85, 0.3)
		if back < BAL_LOW * sc or _bal_cap <= 0.31:
			want = maxf(want, minf(contrast / BAL_CONTRAST, 1.6))
	else:
		_bal_cap = minf(_bal_cap * 1.05, 1.0)
	# (dans la bande : l'appoint redescend doucement, il reste au plus bas qui suffit)
	var step := clampf(pow(want, 0.75), 0.7, 1.45) if want != 1.0 else 0.97
	_bal_gain = clampf(_bal_gain * step, 1.0, BAL_GAIN_MAX)
	bal_stats = {"scene": sc, "dos": back, "pouce": thumb, "gain": _bal_gain, "cap": _bal_cap, "ecart": contrast}
