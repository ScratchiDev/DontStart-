extends Node3D
## Dehors, derrière la fenêtre. La chambre est au premier étage : on voit le jardin, la clôture,
## la rue mouillée, le lampadaire orange, la maison d'en face (une fenêtre allumée, quelqu'un
## derrière), des arbres nus dans le vent. Pluie continue, éclairs et tonnerre.

signal lightning_struck

const GROUND := -2.8          # le sol du jardin, 2,8 m sous le plancher de la chambre
const WINDOW := Vector3(-3.2, 1.575, -0.45)

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


func build(r: Node3D, glass: ShaderMaterial) -> void:
	room = r
	glass_mat = glass
	rng.seed = 1984
	_ground()
	_fence()
	_trees()
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
	for spec in [[Vector3(-6.2, GROUND, -4.6), 8.0, 3], [Vector3(-7.4, GROUND, 4.2), 9.5, 7],
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
	_clock += delta
	if Game.phase != "title" and _clock > _next_bolt:
		_clock = 0.0
		_next_bolt = rng.randf_range(28.0, 70.0)
		strike()
	# le lampadaire grésille de temps en temps
	if rng.randf() < 0.004:
		_sputter()


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
