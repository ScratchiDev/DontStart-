class_name SmartBulb
extends Connected
## Ampoule connectée (fournisseur d'énergie) : une OmniLight et une ampoule émissive. Le script de la
## pièce pose l'abat-jour (modèle Kenney) autour et peut lui confier ses matières émissives
## (add_glow_material) pour qu'elles suivent le niveau.
## État : powered (l'interrupteur, le courant), level (0..1, l'entité la pilote), broken (éclatée).
## Repère : le nœud est au centre de l'ampoule.

signal burst_done

var powered := true
var level := 1.0
var broken := false
var energy := 0.35               # énergie de la lumière à plein niveau
var color := Color(1.0, 0.74, 0.46)
var light_range := 4.0
var shadows := true
var bulb_radius := 0.032
var bulb_glow := 2.6             # émission de l'ampoule à plein niveau
var show_bulb := true

var light: OmniLight3D
var bulb_mat: StandardMaterial3D
var bulb_mesh: MeshInstance3D
var _extra: Array = []           # [matière, émission de base]
var _flicker_k := 1.0
var _flicker_id := 0
var _level_tw: Tween


func build() -> void:
	if display_name == "":
		display_name = "Ampoule"
	bulb_mat = glow_mat(Color(1.0, 0.8, 0.55), bulb_glow)
	if show_bulb:
		bulb_mesh = no_gi(add_mesh(sphere(bulb_radius, 12), Vector3.ZERO, bulb_mat)) as MeshInstance3D
		# culot de l'ampoule
		add_mesh(cyl(bulb_radius * 0.55, bulb_radius * 0.5, bulb_radius * 0.9, 10), Vector3(0, bulb_radius * 1.1, 0),
			plain_mat(Color(0.75, 0.74, 0.7), 0.35, 0.6))
	light = OmniLight3D.new()
	light.name = "Lumiere"
	light.light_color = color
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.light_volumetric_fog_energy = 0.6
	light.shadow_enabled = shadows
	light.shadow_bias = 0.04
	light.position = Vector3(0, -bulb_radius * 0.6, 0)
	add_child(light)
	built = true
	_apply()


## Matière (abat-jour, tulipe…) dont l'émission suivra l'ampoule.
func add_glow_material(m: StandardMaterial3D, base_energy := -1.0) -> void:
	if base_energy < 0.0:
		base_energy = m.emission_energy_multiplier
	_extra.append([m, base_energy])
	_apply()


## Coefficient réellement affiché (0 = noir, 1 = plein).
func current_k() -> float:
	if broken or not powered:
		return 0.0
	return level * _flicker_k


func is_lit() -> bool:
	return current_k() > 0.01


func _apply() -> void:
	if not built:
		return
	var k := current_k()
	light.light_energy = energy * k
	light.visible = k > 0.001
	bulb_mat.emission_energy_multiplier = bulb_glow * k
	bulb_mat.albedo_color = Color(0.85, 0.82, 0.75) if not broken else Color(0.12, 0.11, 0.1)
	for e in _extra:
		(e[0] as StandardMaterial3D).emission_energy_multiplier = float(e[1]) * k


## Interrupteur, courant (le niveau est gardé).
func set_powered(on: bool) -> void:
	powered = on
	_apply()


## Niveau 0..1 (l'entité baisse la lumière). « seconds » : fondu.
func set_level(v: float, seconds := 0.0) -> void:
	if _level_tw:
		_level_tw.kill()
	v = clampf(v, 0.0, 1.0)
	if seconds <= 0.0:
		level = v
		_apply()
		return
	_level_tw = create_tween()
	_level_tw.tween_method(func(x: float) -> void:
		level = x
		_apply(), level, v, seconds)


## Vacille pendant « seconds » secondes (bourdonnement qui passe, elle qui arrive), puis revient.
func flicker(seconds := 1.0, strength := 1.0) -> void:
	if broken:
		return
	_flicker_id += 1
	var my := _flicker_id
	var end_ms := Time.get_ticks_msec() + int(seconds * 1000.0)
	if is_lit():
		Sfx.play_at("metalClick", global_position, -22.0, 0.45, 1.5)
	while Time.get_ticks_msec() < end_ms and my == _flicker_id:
		_flicker_k = (0.0 if randf() < 0.45 else randf_range(0.2, 1.5))
		_flicker_k = lerpf(1.0, _flicker_k, strength)
		_apply()
		await get_tree().create_timer(randf_range(0.035, 0.14), false).timeout
		if not is_inside_tree():
			return
	if my == _flicker_id:
		_flicker_k = 1.0
		_apply()


## L'ampoule éclate : éclair, verre qui tombe, noir définitif. Jamais de dégât au joueur.
func burst() -> void:
	if broken:
		return
	_flicker_id += 1
	_flicker_k = 1.0
	var pos := global_position
	# un dernier éclair, très bref
	light.visible = true
	light.light_energy = energy * 6.0
	bulb_mat.emission_energy_multiplier = bulb_glow * 4.0
	Sfx.play_at("glass", pos, -16.0 if Game.reduced_scares else -3.0, 1.25, 3.0)
	Sfx.play_at("metalClick", pos, -12.0, 0.35, 2.0)
	await get_tree().create_timer(0.06, false).timeout
	if not is_inside_tree():
		return
	broken = true
	_apply()
	if bulb_mesh:
		bulb_mesh.scale = Vector3(0.55, 0.35, 0.55)
		bulb_mesh.position.y = bulb_radius * 0.55
	_shards(pos)
	burst_done.emit()


## Éclats de verre : quelques petits morceaux qui tombent jusqu'au sol et y restent.
func _shards(from: Vector3) -> void:
	var glass := plain_mat(Color(0.82, 0.86, 0.9), 0.08)
	glass.metallic_specular = 1.0
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var floor_y := _surface_y(space, from, from.y - 3.0)
	var holder := Node3D.new()
	holder.name = "Eclats"
	get_tree().current_scene.add_child(holder)
	for i in 14:
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.006, 0.02), 0.0015, randf_range(0.005, 0.016))
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = glass
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		mi.global_position = from
		# chaque éclat tombe sur ce qui est sous lui (lavabo, meuble ou sol) : jamais en l'air
		var land := Vector3(from.x + randf_range(-0.45, 0.45), from.y, from.z + randf_range(-0.45, 0.45))
		if space:
			# pas à travers le mur : l'éclat s'arrête avant
			var wq := PhysicsRayQueryParameters3D.create(from, land, 1)
			var wall := space.intersect_ray(wq)
			if wall:
				var hp: Vector3 = wall.position
				land = from + (hp - from) * maxf(0.0, 1.0 - 0.04 / maxf(0.001, from.distance_to(hp)))
		land.y = _surface_y(space, Vector3(land.x, from.y, land.z), floor_y) + 0.001
		var drop := maxf(0.05, from.y - land.y)
		var dur := sqrt(2.0 * drop / 9.8) * randf_range(0.95, 1.1)
		var start := mi.global_position
		var tw := mi.create_tween()
		tw.tween_method(func(k: float) -> void:
			var p := start.lerp(land, k)
			p.y = lerpf(start.y, land.y, k * k)
			mi.global_position = p
			mi.rotation = Vector3(k * 9.0, k * 5.0, k * 7.0), 0.0, 1.0, dur)
		tw.tween_callback(func() -> void: mi.rotation = Vector3(0, randf() * TAU, 0))
	get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
		Sfx.play_at("glass", Vector3(from.x, floor_y + 0.05, from.z), -22.0, 1.6, 2.0))


## Hauteur de la première surface sous le point p (couche du monde), ou « fallback ».
func _surface_y(space: PhysicsDirectSpaceState3D, p: Vector3, fallback: float) -> float:
	if space == null:
		return fallback
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, -0.06, 0), p + Vector3(0, -4.0, 0), 1)
	var hit := space.intersect_ray(q)
	if hit:
		return (hit.position as Vector3).y
	return fallback
