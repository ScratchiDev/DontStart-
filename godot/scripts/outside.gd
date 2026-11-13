extends Node3D
## Dehors, derrière la fenêtre. La chambre est au premier étage : on voit le jardin, la clôture,
## la rue mouillée, le lampadaire orange, la maison d'en face (une fenêtre allumée, quelqu'un
## derrière), des arbres nus dans le vent. Pluie continue, éclairs et tonnerre.
## Dans le jardin de devant : Clovis, le vélociraptor en béton coulé par Albert (1,10 m), sur son socle,
## tourné vers la maison, à contre-jour sous le lampadaire ; le cerisier. Clovis est sur la couche de
## rendu 12 (« caché des caméras ») : le joueur le voit par la fenêtre, CAM 2 (sur la façade) montre
## le socle vide.
## Propriétés publiques : clovis (Node3D, couche 12), socle (Node3D), cam2 (FeedCam « CAM 2 JARDIN »).

signal lightning_struck

const GROUND := -2.8          # le sol du jardin, 2,8 m sous le plancher de la chambre
const WINDOW := Vector3(-3.2, 1.575, -0.45)
const SOCLE_POS := Vector3(-6.4, GROUND, 1.6)      # pied du socle (centre)
const SOCLE_SIZE := Vector3(0.6, 0.3, 0.4)
const CHERRY_POS := Vector3(-7.4, GROUND, 4.2)
const CAM2_POS := Vector3(-3.45, -0.45, 0.6)
const CAM2_AIM := Vector3(-6.4, -2.2, 1.6)
const FACADE_X := -3.3       # face extérieure du mur de façade

var room: Node3D
var lamp_down: SpotLight3D
var lamp_in: SpotLight3D
var lamp_bulb: StandardMaterial3D
var bolt: SpotLight3D
var glass_mat: ShaderMaterial
var neighbor_mat: StandardMaterial3D
var neighbor_on: Texture2D
var neighbor_off: Texture2D
var someone_there := true
var rng := RandomNumberGenerator.new()
var _next_bolt := 20.0
var _clock := 0.0
var _lamp_energy := 0.0
var _in_energy := 0.0
var clovis: Node3D
var socle: Node3D
var cam2: FeedCam
var cam2_ir: SpotLight3D
var _cam2_was := false
var _concrete: StandardMaterial3D


func build(r: Node3D, glass: ShaderMaterial) -> void:
	room = r
	glass_mat = glass
	rng.seed = 1984
	_ground()
	_fence()
	_trees()
	_cherry()
	_socle()
	_clovis()
	_cam2()
	_house()
	_streetlamp()
	_rain()
	_bolt()
	_clear_air()
	Sfx.loop("rain_loop", -10.0, WINDOW + Vector3(-0.2, 0, 0), self)
	_next_bolt = rng.randf_range(14.0, 24.0)


func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


# ------------------------------------------------------------------ sol, rue, clôture

func _ground() -> void:
	var grass := _mat(Color(0.06, 0.075, 0.045), 0.85)
	_box(Vector3(6.0, 0.2, 30.0), Vector3(-6.3, GROUND - 0.1, 0), grass)
	_box(Vector3(14.0, 0.2, 30.0), Vector3(-26.5, GROUND - 0.1, 0), grass)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_texture = load("res://assets/textures/asphalt_wet_color.jpg")
	asphalt.albedo_color = Color(0.45, 0.45, 0.47)
	asphalt.normal_enabled = true
	asphalt.normal_texture = load("res://assets/textures/asphalt_wet_normalgl.jpg")
	asphalt.roughness_texture = load("res://assets/textures/asphalt_wet_roughness.jpg")
	asphalt.roughness = 0.5
	asphalt.uv1_triplanar = true
	asphalt.uv1_world_triplanar = true
	asphalt.uv1_scale = Vector3.ONE * 0.4
	_box(Vector3(7.0, 0.2, 30.0), Vector3(-13.0, GROUND - 0.12, 0), asphalt)
	var curb := _mat(Color(0.2, 0.2, 0.2), 0.7)
	_box(Vector3(0.25, 0.14, 30.0), Vector3(-9.45, GROUND - 0.01, 0), curb)
	_box(Vector3(0.25, 0.14, 30.0), Vector3(-16.55, GROUND - 0.01, 0), curb)
	# lignes blanches au milieu de la rue
	var paint := _mat(Color(0.5, 0.5, 0.46), 0.6)
	for i in 8:
		_box(Vector3(0.12, 0.01, 1.6), Vector3(-13.0, GROUND - 0.015, -13.0 + i * 3.6), paint)


func _fence() -> void:
	var wood := _mat(Color(0.18, 0.15, 0.12), 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var picket := BoxMesh.new()
	picket.size = Vector3(0.03, 1.1, 0.09)
	mm.mesh = picket
	var n := 150
	mm.instance_count = n
	for i in n:
		var z := -12.0 + i * 0.16
		var h := rng.randf_range(-0.04, 0.04)
		var xf := Transform3D(Basis(Vector3.FORWARD, rng.randf_range(-0.05, 0.05)), Vector3(-9.1, GROUND + 0.55 + h, z))
		mm.set_instance_transform(i, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = wood
	add_child(mmi)
	_box(Vector3(0.05, 0.08, 24.0), Vector3(-9.06, GROUND + 0.85, 0), wood)
	_box(Vector3(0.05, 0.08, 24.0), Vector3(-9.06, GROUND + 0.3, 0), wood)


# ------------------------------------------------------------------ arbres nus

func _trees() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tree.gdshader")
	mat.set_shader_parameter("base_y", GROUND)
	# (l'arbre en (−7.4, 4.2) est devenu le cerisier : voir _cherry())
	for spec in [[Vector3(-6.2, GROUND, -4.6), 8.0, 3],
			[Vector3(-19.5, GROUND, 6.5), 10.0, 11], [Vector3(-14.0, GROUND, -8.5), 8.5, 13],
			[Vector3(-4.6, GROUND, 9.0), 7.0, 17]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var trng := RandomNumberGenerator.new()
		trng.seed = spec[2]
		var h: float = spec[1]
		_branch(st, trng, Transform3D(Basis(), spec[0]), h * 0.42, h * 0.028, 0)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		add_child(mi)


func _branch(st: SurfaceTool, trng: RandomNumberGenerator, xf: Transform3D, length: float, radius: float, depth: int) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = radius
	cyl.top_radius = radius * 0.68
	cyl.height = length
	cyl.radial_segments = 5
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	st.append_from(cyl, 0, xf * Transform3D(Basis(), Vector3(0, length / 2.0, 0)))
	if depth >= 4:
		return
	var tip := xf * Transform3D(Basis(), Vector3(0, length * 0.96, 0))
	var count := 2 + trng.randi() % 2
	for k in count:
		var yaw := Basis(Vector3.UP, trng.randf() * TAU)
		var tilt := Basis(Vector3.RIGHT, trng.randf_range(0.3, 0.85))
		_branch(st, trng, Transform3D(tip.basis * yaw * tilt, tip.origin),
			length * trng.randf_range(0.58, 0.78), radius * 0.62, depth + 1)


# ------------------------------------------------------------------ le cerisier

## Le cerisier du jardin de devant (au pied, la boîte à biscuits enterrée par Albert et Alexandre en
## 2032). Plus bas et plus étalé que les autres arbres, écorce brun rouge, quelques feuilles sèches
## restées accrochées, les autres par terre.
func _cherry() -> void:
	var h := 6.2
	var bark := ShaderMaterial.new()
	bark.shader = load("res://shaders/tree.gdshader")
	bark.set_shader_parameter("base_y", GROUND)
	bark.set_shader_parameter("height", h)
	bark.set_shader_parameter("wind", 0.7)
	bark.set_shader_parameter("color", Color(0.085, 0.05, 0.042))
	var leaf_mat := ShaderMaterial.new()
	leaf_mat.shader = bark.shader
	leaf_mat.set_shader_parameter("base_y", GROUND)
	leaf_mat.set_shader_parameter("height", h)
	leaf_mat.set_shader_parameter("wind", 0.7)
	leaf_mat.set_shader_parameter("color", Color(0.2, 0.07, 0.04))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trng := RandomNumberGenerator.new()
	trng.seed = 2032
	# tronc court, un peu penché, qui se divise bas (port en coupe)
	var trunk := Transform3D(Basis(Vector3.FORWARD, 0.08), CHERRY_POS)
	_cherry_branch(st, leaves, trng, trunk, 1.5, 0.15, 0)
	for mesh_st in [[st, bark], [leaves, leaf_mat]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (mesh_st[0] as SurfaceTool).commit()
		mi.material_override = mesh_st[1]
		add_child(mi)
	# feuilles tombées, plaquées par la pluie sur l'herbe
	var fallen := SurfaceTool.new()
	fallen.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lb := BoxMesh.new()
	lb.size = Vector3(0.05, 0.004, 0.035)
	for k in 160:
		var a := trng.randf() * TAU
		var r := sqrt(trng.randf()) * 2.6
		var p := CHERRY_POS + Vector3(cos(a) * r, 0.003, sin(a) * r)
		if p.x > FACADE_X - 0.1:
			continue
		fallen.append_from(lb, 0, Transform3D(Basis(Vector3.UP, trng.randf() * TAU), p))
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.17, 0.07, 0.04)
	fm.roughness = 0.45
	var fmi := MeshInstance3D.new()
	fmi.mesh = fallen.commit()
	fmi.material_override = fm
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)


func _cherry_branch(st: SurfaceTool, leaves: SurfaceTool, trng: RandomNumberGenerator, xf: Transform3D, length: float, radius: float, depth: int) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = radius
	cyl.top_radius = radius * 0.7
	cyl.height = length
	cyl.radial_segments = 6 if depth < 2 else 5
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	st.append_from(cyl, 0, xf * Transform3D(Basis(), Vector3(0, length / 2.0, 0)))
	var tip := xf * Transform3D(Basis(), Vector3(0, length * 0.96, 0))
	if depth >= 5:
		# quelques feuilles sèches encore accrochées
		if trng.randf() < 0.45:
			var lb := BoxMesh.new()
			lb.size = Vector3(0.05, 0.003, 0.035)
			for k in trng.randi_range(1, 2):
				var lx := Transform3D(Basis(Vector3(trng.randf(), trng.randf(), trng.randf()).normalized(), trng.randf() * TAU),
					tip.origin + Vector3(trng.randf_range(-0.05, 0.05), trng.randf_range(-0.05, 0.02), trng.randf_range(-0.05, 0.05)))
				leaves.append_from(lb, 0, lx)
		return
	var count := 3 if depth == 0 else 2 + trng.randi() % 2
	for k in count:
		var yaw := Basis(Vector3.UP, TAU * (k + trng.randf_range(-0.2, 0.2)) / count + depth * 0.7)
		var spread := trng.randf_range(0.55, 0.95) if depth == 0 else trng.randf_range(0.35, 0.8)
		var tilt := Basis(Vector3.RIGHT, spread)
		_cherry_branch(st, leaves, trng, Transform3D(tip.basis * yaw * tilt, tip.origin),
			length * (trng.randf_range(0.8, 1.0) if depth == 0 else trng.randf_range(0.62, 0.8)), radius * 0.6, depth + 1)


# ------------------------------------------------------------------ Clovis et son socle

## Béton gris mouillé : pores, coulures de pluie, taches de lichen. Texture générée, projetée.
func _concrete_mat(base: Color, seed_: int) -> StandardMaterial3D:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var hgt := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var blot := FastNoiseLite.new()
	blot.seed = seed_
	blot.frequency = 0.035
	var streak := FastNoiseLite.new()
	streak.seed = seed_ + 1
	streak.frequency = 0.12
	var lichen := FastNoiseLite.new()
	lichen.seed = seed_ + 2
	lichen.frequency = 0.05
	var trng := RandomNumberGenerator.new()
	trng.seed = seed_
	for y in n:
		for x in n:
			var c := base
			var b := blot.get_noise_2d(x, y)
			c = c.lightened(b * 0.25) if b > 0.0 else c.darkened(-b * 0.35)
			var sk := streak.get_noise_2d(x * 1.0, y * 0.08)
			if sk > 0.25:
				c = c.darkened((sk - 0.25) * 0.9)
			var li := lichen.get_noise_2d(x, y)
			if li > 0.42:
				c = c.lerp(Color(0.32, 0.36, 0.2), clampf((li - 0.42) * 3.0, 0.0, 0.6))
			var pore := trng.randf() < 0.05
			if pore:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
			var hv := 0.5 + b * 0.3 - (0.35 if pore else 0.0) + trng.randf_range(-0.06, 0.06)
			hgt.set_pixel(x, y, Color(hv, hv, hv))
	img.generate_mipmaps()
	hgt.bump_map_to_normal_map(2.0)
	hgt.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(hgt)
	m.normal_scale = 0.7
	m.roughness = 0.3            # mouillé : il brille sous le lampadaire
	m.metallic_specular = 0.65
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.8
	return m


## Repère orthonormé dont l'axe Y suit « dir » (pour poser cylindres et capsules d'un point à un autre).
static func _basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _part(parent: Node3D, mesh: Mesh, xf: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi


## Os en capsule de a à b (rayon r).
func _bone(parent: Node3D, r: float, a: Vector3, b: Vector3, mat: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = a.distance_to(b) + r * 2.0
	c.radial_segments = 12
	c.rings = 4
	var bs := _basis_y(b - a)
	bs = Basis(bs.x * squash.x, bs.y * squash.y, bs.z * squash.z)
	return _part(parent, c, Transform3D(bs, (a + b) / 2.0), mat)


## Cône (rayon ra en a, rb en b).
func _cone(parent: Node3D, ra: float, rb: float, a: Vector3, b: Vector3, mat: Material, seg := 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = ra
	c.top_radius = rb
	c.height = a.distance_to(b)
	c.radial_segments = seg
	c.rings = 1
	return _part(parent, c, Transform3D(_basis_y(b - a), (a + b) / 2.0), mat)


func _cube(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _part(parent, bm, Transform3D(Basis.from_euler(rot), pos), mat)


## Le socle (couche normale : CAM 2 le voit, vide) et sa plaque « CLOVIS — 2032 », face à la maison.
## Sur le dessus, deux fers à béton rouillés et deux empreintes plus claires, là où sont les pieds :
## cachés par Clovis pour le joueur, ils sont tout ce que montre la caméra.
func _socle() -> void:
	socle = Node3D.new()
	socle.name = "SocleClovis"
	add_child(socle)
	socle.position = SOCLE_POS
	var old := _concrete_mat(Color(0.42, 0.41, 0.38), 61)
	_cube(socle, SOCLE_SIZE, Vector3(0, SOCLE_SIZE.y / 2.0, 0), old)
	_cube(socle, Vector3(SOCLE_SIZE.x + 0.06, 0.04, SOCLE_SIZE.z + 0.06), Vector3(0, 0.02, 0), old)
	var plaque := StandardMaterial3D.new()
	plaque.albedo_texture = load("res://assets/images/clovis_plaque.png")
	plaque.roughness = 0.4
	plaque.metallic = 0.5
	plaque.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.12)
	_part(socle, q, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(SOCLE_SIZE.x / 2.0 + 0.003, SOCLE_SIZE.y * 0.55, 0)), plaque)
	_cube(socle, Vector3(0.006, 0.13, 0.33), Vector3(SOCLE_SIZE.x / 2.0 + 0.001, SOCLE_SIZE.y * 0.55, 0), _mat(Color(0.2, 0.16, 0.1), 0.5))
	var rust := _mat(Color(0.28, 0.12, 0.06), 0.8)
	var clean := _mat(Color(0.5, 0.49, 0.46), 0.6)
	for s in [-1.0, 1.0]:
		_cube(socle, Vector3(0.17, 0.002, 0.09), Vector3(0.05, SOCLE_SIZE.y + 0.001, s * 0.1), clean)
		_cone(socle, 0.007, 0.006, Vector3(0.03, SOCLE_SIZE.y, s * 0.1), Vector3(0.035, SOCLE_SIZE.y + 0.04, s * 0.1), rust, 6)


## Clovis : vélociraptor en béton fait main, 1,10 m, tourné vers la maison (+x). Corps en capsule
## horizontale, queue en cône, cou et tête (mâchoire en boîte, entrouverte), pattes épaisses, bras trop
## longs, yeux peints délavés. Couche de rendu 12 : invisible pour les caméras de flux.
func _clovis() -> void:
	clovis = Node3D.new()
	clovis.name = "Clovis"
	add_child(clovis)
	clovis.position = SOCLE_POS + Vector3(0, SOCLE_SIZE.y, 0)
	var c := _concrete
	if c == null:
		c = _concrete_mat(Color(0.53, 0.52, 0.49), 2032)
		_concrete = c
	for s in [-1.0, 1.0]:
		var z: float = s * 0.1
		# pied, deux doigts en avant, la griffe relevée
		_cube(clovis, Vector3(0.17, 0.05, 0.09), Vector3(0.05, 0.025, z), c)
		for t in [-1.0, 1.0]:
			_cube(clovis, Vector3(0.09, 0.035, 0.032), Vector3(0.17, 0.0175, z + t * 0.024), c, Vector3(0, t * 0.12, 0))
		_cone(clovis, 0.016, 0.003, Vector3(0.07, 0.05, z - s * 0.03), Vector3(0.12, 0.11, z - s * 0.03), c, 8)
		# patte épaisse : métatarse, tibia, cuisse
		_bone(clovis, 0.05, Vector3(0.0, 0.05, z), Vector3(-0.07, 0.24, z * 1.05), c)
		_bone(clovis, 0.065, Vector3(-0.07, 0.24, z * 1.05), Vector3(0.07, 0.46, z * 1.15), c)
		_bone(clovis, 0.1, Vector3(0.07, 0.46, z * 1.15), Vector3(-0.04, 0.66, z * 0.9), c, Vector3(1.0, 1.0, 0.8))
		# bras trop longs : de l'épaule presque jusqu'aux genoux, trois griffes
		var sh := Vector3(0.36, 0.7, s * 0.12)
		var el := Vector3(0.43, 0.5, s * 0.15)
		var wr := Vector3(0.52, 0.32, s * 0.15)
		_bone(clovis, 0.032, sh, el, c)
		_bone(clovis, 0.027, el, wr, c)
		for f in 3:
			var off := Vector3(0.0, 0.0, (f - 1) * 0.016)
			_cone(clovis, 0.011, 0.002, wr + off, wr + off + Vector3(0.05, -0.06, 0.0), c, 6)
	# corps : capsule horizontale de 0,9 m, un peu relevée vers l'avant
	var body_dir := Vector3(cos(0.12), sin(0.12), 0)
	_bone(clovis, 0.16, Vector3(0.03, 0.72, 0) - body_dir * 0.29, Vector3(0.03, 0.72, 0) + body_dir * 0.29, c, Vector3(1.0, 1.0, 0.85))
	# queue : cône de 0,8 m, raide (le béton), légèrement tombante
	_cone(clovis, 0.12, 0.022, Vector3(-0.36, 0.69, 0), Vector3(-1.15, 0.6, 0), c)
	# cou, tête : la tête est levée vers la maison (vers la fenêtre de la chambre de Manon) ; crâne et
	# museau en boîtes, arcade, mâchoire entrouverte, dents peintes
	_bone(clovis, 0.075, Vector3(0.4, 0.78, 0), Vector3(0.53, 0.95, 0), c)
	var head := Node3D.new()
	head.name = "Tete"
	clovis.add_child(head)
	head.position = Vector3(0.55, 0.97, 0)
	head.rotation.z = 0.32
	_cube(head, Vector3(0.24, 0.115, 0.125), Vector3(0.06, 0.0, 0), c)
	_cube(head, Vector3(0.15, 0.08, 0.095), Vector3(0.21, -0.015, 0), c, Vector3(0, 0, -0.08))
	_cube(head, Vector3(0.12, 0.035, 0.135), Vector3(0.04, 0.06, 0), c)
	_cube(head, Vector3(0.22, 0.038, 0.09), Vector3(0.13, -0.075, 0), c, Vector3(0, 0, -0.2))
	var paint := _mat(Color(0.64, 0.62, 0.54), 0.6)
	for k in 6:
		var tx := 0.11 + k * 0.028
		for sz in [0.034, -0.034]:
			_cone(head, 0.008, 0.001, Vector3(tx, -0.05 + k * 0.002, sz), Vector3(tx + 0.004, -0.078 + k * 0.002, sz), paint, 5)
	# yeux peints, délavés par les pluies (l'un plus haut que l'autre)
	var white := _mat(Color(0.66, 0.64, 0.54), 0.5)
	var pupil := _mat(Color(0.24, 0.23, 0.2), 0.5)
	for sd in [-1.0, 1.0]:
		var ey: float = 0.02 + (0.008 if sd > 0.0 else 0.0)
		var disc := CylinderMesh.new()
		disc.top_radius = 0.03
		disc.bottom_radius = 0.03
		disc.height = 0.004
		disc.radial_segments = 14
		var rot := Basis(Vector3.RIGHT, PI / 2.0)
		_part(head, disc, Transform3D(rot, Vector3(0.1, ey, sd * 0.0635)), white)
		var pd := CylinderMesh.new()
		pd.top_radius = 0.012
		pd.bottom_radius = 0.012
		pd.height = 0.004
		pd.radial_segments = 10
		_part(head, pd, Transform3D(rot, Vector3(0.11, ey - 0.003, sd * 0.0655)), pupil)
	Builder.set_vis_layers(clovis, [Builder.LAYER_HIDDEN_FROM_FEEDS])


# ------------------------------------------------------------------ CAM 2, sur la façade

## La caméra du jardin : support métallique vissé sur la façade, caméra « bullet » blanche avec sa
## visière, LED infrarouges ; son flux (CAM 2 JARDIN) ne voit pas la couche 12 : le socle est vide.
func _cam2() -> void:
	var white := _mat(Color(0.82, 0.82, 0.8), 0.35)
	var grey := _mat(Color(0.3, 0.3, 0.31), 0.4)
	var mount := Node3D.new()
	mount.name = "SupportCam2"
	add_child(mount)
	_box(Vector3(0.012, 0.14, 0.1), Vector3(FACADE_X - 0.006, CAM2_POS.y, CAM2_POS.z), grey)
	var arm_a := Vector3(FACADE_X - 0.012, CAM2_POS.y, CAM2_POS.z)
	var arm_b := CAM2_POS + Vector3(0.03, 0.04, 0)
	_cone(mount, 0.016, 0.016, arm_a, arm_b, grey, 8)
	var body := Node3D.new()
	body.name = "Cam2"
	add_child(body)
	body.position = CAM2_POS + Vector3(0, 0.04, 0)
	body.look_at(CAM2_AIM)
	_cube(body, Vector3(0.075, 0.075, 0.2), Vector3(0, 0, 0.02), white)
	_cube(body, Vector3(0.09, 0.006, 0.17), Vector3(0, 0.044, -0.01), white)
	var lens := _mat(Color(0.02, 0.02, 0.03), 0.05)
	_cone(body, 0.024, 0.024, Vector3(0, 0, -0.08), Vector3(0, 0, -0.083), lens, 14)
	var ir := StandardMaterial3D.new()
	ir.albedo_color = Color(0.2, 0.02, 0.02)
	ir.emission_enabled = true
	ir.emission = Color(0.6, 0.03, 0.02)
	ir.emission_energy_multiplier = 1.0
	for k in 6:
		var a := TAU * k / 6.0
		_cube(body, Vector3(0.006, 0.006, 0.003), Vector3(cos(a) * 0.03, sin(a) * 0.03, -0.0815), ir)
	cam2 = FeedCam.new()
	cam2.name = "CamFlux2"
	cam2.title = "CAM 2 JARDIN"
	cam2.ir = 1.0
	cam2.exposure = 1.6
	cam2.fov = 46.0
	add_child(cam2)
	cam2.global_position = body.global_position + (CAM2_AIM - body.global_position).normalized() * 0.1
	cam2.look_at(CAM2_AIM)
	cam2.build()
	# éclairage infrarouge de la caméra : il n'éclaire le jardin que pendant qu'elle filme (le joueur
	# est alors dans le bureau, loin des fenêtres de la façade)
	cam2_ir = SpotLight3D.new()
	cam2_ir.name = "InfrarougeCam2"
	cam2_ir.light_color = Color(0.85, 0.88, 1.0)
	cam2_ir.light_energy = 4.0
	cam2_ir.spot_range = 9.0
	cam2_ir.spot_angle = 32.0
	cam2_ir.spot_attenuation = 0.8
	cam2_ir.shadow_enabled = false
	cam2_ir.visible = false
	cam2_ir.set_meta("always_on", true)
	add_child(cam2_ir)
	cam2_ir.global_position = cam2.global_position
	cam2_ir.look_at(CAM2_AIM)


# ------------------------------------------------------------------ la maison d'en face

func _house() -> void:
	var siding := _mat(Color(0.16, 0.17, 0.19), 0.85)
	var roof := _mat(Color(0.07, 0.065, 0.07), 0.8)
	var front := -21.5
	_box(Vector3(8.0, 6.4, 11.0), Vector3(front - 4.0, GROUND + 3.2, -1.0), siding)
	# toit à deux pans (prisme)
	var pm := PrismMesh.new()
	pm.size = Vector3(11.4, 3.0, 8.6)
	var r := MeshInstance3D.new()
	r.mesh = pm
	r.material_override = roof
	r.rotation.y = PI / 2.0
	r.position = Vector3(front - 4.0, GROUND + 6.4 + 1.5, -1.0)
	add_child(r)
	var dark := _mat(Color(0.02, 0.025, 0.03), 0.15)
	for floor_y in [GROUND + 1.6, GROUND + 4.4]:
		for z in [-4.0, -1.0, 2.0]:
			if floor_y > GROUND + 3.0 and z == -1.0:
				continue
			_box(Vector3(0.05, 1.3, 1.0), Vector3(front + 0.02, floor_y, z), dark)
	_box(Vector3(0.05, 2.1, 1.0), Vector3(front + 0.02, GROUND + 1.05, 3.6), _mat(Color(0.12, 0.08, 0.06), 0.7))
	# la fenêtre allumée de l'étage, face à ta chambre
	neighbor_on = load("res://assets/images/neighbor_window.png")
	neighbor_off = load("res://assets/images/neighbor_window_empty.png")
	neighbor_mat = StandardMaterial3D.new()
	neighbor_mat.albedo_color = Color.BLACK
	neighbor_mat.emission_enabled = true
	neighbor_mat.emission_texture = neighbor_on
	neighbor_mat.emission = Color.WHITE
	neighbor_mat.emission_energy_multiplier = 0.85
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.3)
	var win := MeshInstance3D.new()
	win.mesh = q
	win.material_override = neighbor_mat
	win.rotation.y = PI / 2.0
	win.position = Vector3(front + 0.04, GROUND + 4.4, -1.0)
	add_child(win)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.62, 0.3)
	glow.light_energy = 0.5
	glow.omni_range = 4.0
	glow.position = Vector3(front + 0.8, GROUND + 4.4, -1.0)
	add_child(glow)


## Quelqu'un se tient derrière la fenêtre d'en face, ou plus personne.
func set_someone(v: bool) -> void:
	someone_there = v
	neighbor_mat.emission_texture = neighbor_on if v else neighbor_off


# ------------------------------------------------------------------ le lampadaire

func _streetlamp() -> void:
	var metal := _mat(Color(0.12, 0.12, 0.13), 0.5)
	var base := Vector3(-10.1, GROUND, 2.6)
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.09
	cm.height = 5.2
	pole.mesh = cm
	pole.material_override = metal
	pole.position = base + Vector3(0, 2.6, 0)
	add_child(pole)
	_box(Vector3(1.3, 0.07, 0.07), base + Vector3(0.6, 5.15, 0), metal)
	var head := base + Vector3(1.2, 5.0, 0)
	_box(Vector3(0.5, 0.12, 0.28), head + Vector3(0, 0.08, 0), metal)
	lamp_bulb = StandardMaterial3D.new()
	lamp_bulb.albedo_color = Color(1, 0.7, 0.4)
	lamp_bulb.emission_enabled = true
	lamp_bulb.emission = Color(1.0, 0.58, 0.24)
	lamp_bulb.emission_energy_multiplier = 5.0
	_box(Vector3(0.36, 0.05, 0.2), head, lamp_bulb)
	lamp_down = SpotLight3D.new()
	lamp_down.light_color = Color(1.0, 0.58, 0.26)
	lamp_down.light_energy = 9.0
	lamp_down.light_volumetric_fog_energy = 0.3
	lamp_down.spot_range = 9.0
	lamp_down.spot_angle = 58.0
	lamp_down.shadow_enabled = true
	add_child(lamp_down)
	lamp_down.global_position = head + Vector3(0, -0.05, 0)
	lamp_down.look_at(head + Vector3(0.01, -5.0, 0.0))
	# la même lumière, vue depuis la chambre : elle traverse la fenêtre et projette les croisillons
	lamp_in = SpotLight3D.new()
	lamp_in.light_color = Color(1.0, 0.6, 0.3)
	lamp_in.light_energy = 14.0
	lamp_in.light_volumetric_fog_energy = 0.35
	lamp_in.spot_range = 16.0
	lamp_in.spot_angle = 9.0
	lamp_in.spot_attenuation = 0.5
	lamp_in.shadow_enabled = true
	lamp_in.shadow_bias = 0.08
	lamp_in.shadow_normal_bias = 2.0
	lamp_in.shadow_blur = 1.5
	add_child(lamp_in)
	lamp_in.global_position = head + Vector3(0, -0.1, 0)
	lamp_in.look_at(WINDOW + Vector3(1.4, -0.9, 0.5))
	_lamp_energy = lamp_down.light_energy
	_in_energy = lamp_in.light_energy


# ------------------------------------------------------------------ pluie, éclairs

func _rain() -> void:
	var p := GPUParticles3D.new()
	p.amount = 2600
	p.lifetime = 1.1
	p.preprocess = 1.0
	p.visibility_aabb = AABB(Vector3(-5, -6, -8), Vector3(10, 12, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.6, 0.2, 7.0)
	pm.direction = Vector3(0.08, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.01, 0.34)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.32)
	m.roughness = 0.2
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(-7.0, 5.0, -0.5)
	add_child(p)


## Dehors, on retire l'essentiel du brouillard de la chambre : sinon la vue se noie dans un halo.
func _clear_air() -> void:
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(27.0, 14.0, 32.0)
	fv.position = Vector3(-17.0, 0.0, 0.0)
	var fm := FogMaterial.new()
	fm.density = -0.022
	fv.material = fm
	add_child(fv)


func _bolt() -> void:
	bolt = SpotLight3D.new()
	bolt.light_color = Color(0.75, 0.83, 1.0)
	bolt.light_energy = 0.0
	bolt.light_volumetric_fog_energy = 1.0
	bolt.spot_range = 20.0
	bolt.spot_angle = 24.0
	bolt.spot_attenuation = 0.3
	bolt.shadow_enabled = true
	bolt.shadow_bias = 0.1
	bolt.shadow_normal_bias = 2.5
	bolt.shadow_blur = 2.5
	add_child(bolt)
	bolt.global_position = Vector3(-9.0, 6.5, -2.0)
	bolt.look_at(WINDOW + Vector3(2.5, -1.6, 0.9))


func _sky() -> PanoramaSkyMaterial:
	var we := get_tree().current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment and we.environment.sky:
		return we.environment.sky.sky_material as PanoramaSkyMaterial
	return null


## Un éclair : deux ou trois flashs, la pièce s'illumine à travers la fenêtre, puis le tonnerre.
func strike() -> void:
	lightning_struck.emit()
	var sky := _sky()
	var sky_base := sky.energy_multiplier if sky else 0.0
	# éclairs adoucis (photosensibilité) : une seule lueur douce, sans stroboscope
	var pattern := [[42.0, 0.05], [0.0, 0.07], [60.0, 0.09], [10.0, 0.18], [0.0, 0.0]]
	if Game.soft_flashes:
		pattern = [[6.0, 0.12], [12.0, 0.25], [6.0, 0.25], [0.0, 0.0]]
	for e in pattern:
		bolt.light_energy = e[0]
		if sky:
			sky.energy_multiplier = sky_base + e[0] * 0.06
		if glass_mat:
			glass_mat.set_shader_parameter("flash", e[0] / 60.0)
		if e[1] > 0.0:
			await get_tree().create_timer(e[1]).timeout
	if sky:
		sky.energy_multiplier = sky_base
	if rng.randf() < 0.5:
		set_someone(not someone_there)
	await get_tree().create_timer(rng.randf_range(0.7, 2.6)).timeout
	Sfx.play("thunder", -3.0, rng.randf_range(0.8, 1.1))


func _process(delta: float) -> void:
	_update_cam2_lights()
	_clock += delta
	if Game.phase != "title" and _clock > _next_bolt:
		_clock = 0.0
		_next_bolt = rng.randf_range(28.0, 70.0)
		strike()
	# le lampadaire grésille de temps en temps
	if rng.randf() < 0.004:
		_sputter()


## Quand CAM 2 filme (le joueur est dans le bureau, la chambre de Manon n'est pas active), le jardin
## garde son lampadaire et la caméra allume son infrarouge ; ensuite, tout revient comme avant.
func _update_cam2_lights() -> void:
	var on := cam2 != null and cam2.active
	if on == _cam2_was:
		if on and not lamp_down.visible:
			lamp_down.visible = true
		return
	_cam2_was = on
	cam2_ir.visible = on
	var room_on := true
	if room and "active" in room:
		room_on = bool(room.get("active"))
	lamp_down.visible = on or room_on


func _sputter() -> void:
	for k in rng.randi_range(2, 5):
		var f := rng.randf_range(0.05, 0.5)
		lamp_down.light_energy = _lamp_energy * f
		lamp_in.light_energy = _in_energy * f
		lamp_bulb.emission_energy_multiplier = 5.0 * f
		await get_tree().create_timer(rng.randf_range(0.03, 0.09)).timeout
		lamp_down.light_energy = _lamp_energy
		lamp_in.light_energy = _in_energy
		lamp_bulb.emission_energy_multiplier = 5.0
		await get_tree().create_timer(rng.randf_range(0.03, 0.12)).timeout
