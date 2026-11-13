class_name Builder
extends Node3D
## Outils communs pour construire les pièces de la maison : matières partagées (papier peint,
## lambris, parquet, bois, peinture…), boîtes, collisions, objets interactifs, images, et meubles
## Kenney (CC0) mis à l'échelle en mètres réels. Chaque pièce hérite de ce script.

const LAYER_WORLD := 1
const LAYER_INTERACT := 4   # couche 3 : visable mais ne bloque pas le joueur

## Couches de RENDU (visibilité, numéros 1 à 20, à ne pas confondre avec les couches de collision) :
## 11 = « flux uniquement » : vu seulement par les caméras de flux qui l'acceptent (le miroir),
##      jamais par le joueur (sa caméra n'a pas cette couche) ;
## 12 = « caché des caméras » : vu par le joueur, jamais par les caméras de flux.
const LAYER_FEED_ONLY := 11
const LAYER_HIDDEN_FROM_FEEDS := 12

static var _cache := {}
static var _grime_tex_s: Texture2D


## Bit d'une couche de rendu (1 à 20) dans un masque (layers, cull_mask).
static func layer_bit(n: int) -> int:
	return 1 << (n - 1)


## Pose les couches de rendu d'un nœud et de tous ses descendants visuels (maillages, lumières,
## décalques…). « layers » : un masque (int) ou une liste de numéros de couche, par exemple
## Builder.set_vis_layers(silhouette, [Builder.LAYER_FEED_ONLY]).
static func set_vis_layers(node: Node, layers: Variant) -> void:
	var mask := 0
	if layers is Array or layers is PackedInt32Array:
		for n in layers:
			mask |= layer_bit(int(n))
	else:
		mask = int(layers)
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = mask
	for c in node.get_children():
		set_vis_layers(c, mask)


## Range un objet de décor dans le groupe « analogique » (vieille télé, radio, radiateur : elle ne peut
## pas les prendre) ou « connecte » (les appareils Connected s'y mettent tout seuls). Prépare le Bac à sable.
static func tag(node: Node, group: String) -> Node:
	if group == "analogique" or group == "connecte":
		node.add_to_group(group)
	return node

var mats := {}
var props := {}


func _notification(what: int) -> void:
	# libérer le cache partagé en quittant (sinon Godot signale des ressources encore utilisées)
	if what == NOTIFICATION_PREDELETE and not _cache.is_empty():
		_cache = {}
		_grime_tex_s = null


# ------------------------------------------------------------------ matériaux

func _tex(file: String) -> Texture2D:
	return load("res://assets/textures/" + file)


func _triplanar(m: StandardMaterial3D, scale: float) -> StandardMaterial3D:
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


func _normal_from_height(file: String, strength: float) -> Texture2D:
	var img: Image = _tex(file).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(strength)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Crasse et usure : une texture de saleté multipliée par-dessus, projetée dans l'espace
## (pas de répétition visible d'un meuble à l'autre).
func _grimy(m: StandardMaterial3D, scale := 0.9) -> StandardMaterial3D:
	m.detail_enabled = true
	m.detail_albedo = _grime_tex_s
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_scale = Vector3.ONE * scale
	return m


## Matières de la maison, créées une seule fois et partagées par toutes les pièces.
func _make_materials() -> void:
	if not _cache.is_empty():
		mats = _cache
		return
	_grime_tex_s = _tex("grime.png")
	var plaster := StandardMaterial3D.new()
	plaster.albedo_texture = _tex("wall_plaster_dirty_color.jpg")
	plaster.albedo_color = Color(0.66, 0.6, 0.47)
	plaster.normal_enabled = true
	plaster.normal_texture = _tex("wall_plaster_dirty_normalgl.jpg")
	plaster.roughness_texture = _tex("wall_plaster_dirty_roughness.jpg")
	mats.plaster = _triplanar(plaster, 0.5)

	# papier peint années 80 (le motif fait 0,6 m), avec le relief du plâtre dessous
	var wall := StandardMaterial3D.new()
	wall.albedo_texture = _tex("wallpaper.png")
	wall.albedo_color = Color(0.8, 0.76, 0.68)
	wall.normal_enabled = true
	wall.normal_texture = _normal_from_height("wallpaper_height.png", 1.4)
	wall.normal_scale = 0.6
	wall.roughness = 0.92
	mats.wall = _grimy(_triplanar(wall, 1.0 / 0.6), 0.35)

	# lambris en bas des murs
	var wains := StandardMaterial3D.new()
	wains.albedo_texture = _tex("beadboard.png")
	wains.albedo_color = Color(0.82, 0.78, 0.74)
	wains.normal_enabled = true
	wains.normal_texture = _normal_from_height("beadboard_height.png", 5.0)
	wains.roughness = 0.55
	mats.wainscot = _grimy(_triplanar(wains, 1.0), 0.6)

	var ceil := plaster.duplicate() as StandardMaterial3D
	ceil.albedo_color = Color(0.5, 0.48, 0.43)
	mats.ceil = _grimy(ceil, 0.3)

	var floor_ := StandardMaterial3D.new()
	floor_.albedo_texture = _tex("hardwood2_diffuse.jpg")
	floor_.albedo_color = Color(0.62, 0.5, 0.4)
	floor_.normal_enabled = true
	floor_.normal_texture = _normal_from_height("hardwood2_bump.jpg", 6.0)
	floor_.roughness_texture = _tex("hardwood2_roughness.jpg")
	mats.floor = _grimy(_triplanar(floor_, 0.42), 0.25)

	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _tex("hardwood2_diffuse.jpg")
	wood.albedo_color = Color(0.46, 0.31, 0.21)
	wood.roughness = 0.62
	mats.wood = _grimy(_triplanar(wood, 3.2))
	var wood_dark := wood.duplicate() as StandardMaterial3D
	wood_dark.albedo_color = Color(0.3, 0.2, 0.14)
	mats.wood_dark = wood_dark

	mats.paint = _grimy(_plain(Color(0.74, 0.7, 0.62), 0.55), 1.2)
	mats.beige = _grimy(_plain(Color(0.56, 0.52, 0.43), 0.55), 2.0)
	mats.door = _grimy(_plain(Color(0.66, 0.63, 0.56), 0.6), 0.8)
	mats.dark = _plain(Color(0.05, 0.05, 0.055), 0.6)
	mats.metal = _plain(Color(0.55, 0.53, 0.5), 0.35, 0.8)
	mats.black_plastic = _plain(Color(0.08, 0.08, 0.08), 0.45)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.7, 0.85, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	mats.glass = glass

	# --- autres pièces de la maison
	var floral := wall.duplicate() as StandardMaterial3D
	floral.albedo_texture = _tex("wallpaper_floral.png")
	floral.normal_texture = _normal_from_height("wallpaper_floral_height.png", 1.4)
	floral.albedo_color = Color(0.82, 0.78, 0.74)
	mats.wall_floral = floral
	var stripes := wall.duplicate() as StandardMaterial3D
	stripes.albedo_texture = _tex("wallpaper_stripes.png")
	stripes.normal_texture = _normal_from_height("wallpaper_stripes_height.png", 1.4)
	stripes.albedo_color = Color(0.8, 0.78, 0.7)
	mats.wall_stripes = stripes
	var stripes_dark := stripes.duplicate() as StandardMaterial3D
	stripes_dark.albedo_color = Color(0.5, 0.46, 0.4)
	mats.wall_stripes_dark = stripes_dark
	mats.wall_paint = _grimy(_triplanar(_plain(Color(0.78, 0.76, 0.7), 0.85), 0.5), 0.5)
	var faience := StandardMaterial3D.new()
	faience.albedo_texture = _tex("tiles_wall.png")
	faience.normal_enabled = true
	faience.normal_texture = _normal_from_height("tiles_wall_height.png", 3.0)
	faience.roughness = 0.25
	mats.faience = _grimy(_triplanar(faience, 1.0 / 0.6), 0.4)
	var tiles := StandardMaterial3D.new()
	tiles.albedo_texture = _tex("tiles_floor.png")
	tiles.normal_enabled = true
	tiles.normal_texture = _normal_from_height("tiles_floor_height.png", 3.0)
	tiles.roughness = 0.4
	mats.carrelage = _grimy(_triplanar(tiles, 1.0 / 0.8), 0.3)
	var carpet := StandardMaterial3D.new()
	carpet.albedo_texture = _tex("carpet.png")
	carpet.normal_enabled = true
	carpet.normal_texture = _normal_from_height("carpet_height.png", 2.0)
	carpet.roughness = 1.0
	mats.moquette = _triplanar(carpet, 1.0)
	var frosted := StandardMaterial3D.new()
	frosted.albedo_color = Color(0.7, 0.75, 0.8, 0.55)
	frosted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frosted.roughness = 0.9
	mats.frosted = frosted
	_cache = mats


func _plain(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Remplace les aplats de couleur des modèles Kenney par des matières éclairables et assombries.
func _remap(m: Material, tint: Dictionary) -> Material:
	var key := m.resource_name.to_lower() if m else ""
	if tint.has(key):
		return _grimy(_plain(tint[key], 0.95))
	match key:
		"wood":
			return mats.wood
		"wooddark":
			return mats.wood_dark
		"glass":
			return mats.glass
		"lamp":
			return _grimy(_plain(Color(0.9, 0.86, 0.74), 0.7))
		"fur":
			return _grimy(_plain(Color(0.33, 0.24, 0.17), 1.0))
		"plant":
			return _grimy(_plain(Color(0.16, 0.24, 0.13), 1.0))
		"metaldark":
			return _grimy(_plain(Color(0.12, 0.12, 0.12), 0.5, 0.4))
	var base := Color(0.5, 0.5, 0.5)
	if m is BaseMaterial3D:
		base = (m as BaseMaterial3D).albedo_color
	if key.begins_with("metal"):
		return _grimy(_plain(base * 0.8, 0.38, 0.7))
	if key.begins_with("carpet"):
		return _grimy(_plain(base.darkened(0.45), 1.0))
	return _grimy(_plain(base.darkened(0.25), 0.8))


# ------------------------------------------------------------------ outils de construction

func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		_collider(size, pos, parent)
	return mi


func _collider(size: Vector3, pos: Vector3, parent: Node3D = self, layer := LAYER_WORLD) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)
	return sb


func _interactable(label: String, size: Vector3, pos: Vector3, parent: Node3D = self, layer := LAYER_INTERACT, reach := 2.2) -> Interactable:
	var it := Interactable.new()
	it.label = label
	it.reach = reach
	it.collision_layer = layer
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	it.add_child(cs)
	it.position = pos
	parent.add_child(it)
	return it


func _quad(size: Vector2, pos: Vector3, mat: Material, rot_y := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _image_mat(file: String, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/images/" + file)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _aabb_of(root: Node3D, ref: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := ref.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box: AABB = inv * mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	if root is MeshInstance3D:
		var own: AABB = inv * root.global_transform * (root as MeshInstance3D).get_aabb()
		out = own if first else out.merge(own)
	return out


## Pose un meuble Kenney : « size » en mètres (x = largeur, y = hauteur, z = profondeur,
## 0 = proportionnel). Le pied du meuble est posé en « pos », tourné de « rot » degrés.
func prop(model: String, pos: Vector3, rot := 0.0, size := Vector3(0, 0, 0), solid := true, tint := {}, label := "") -> Node3D:
	var holder := Node3D.new()
	holder.name = model
	add_child(holder)
	var inst: Node3D = (load("res://assets/models/kenney/%s.glb" % model) as PackedScene).instantiate()
	holder.add_child(inst)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _remap(mi.mesh.surface_get_material(i), tint))
	var raw := _aabb_of(inst, holder)
	var s := Vector3.ONE
	var known: Array[float] = []
	for a in 3:
		if size[a] > 0.0:
			s[a] = size[a] / maxf(raw.size[a], 0.001)
			known.append(s[a])
	if not known.is_empty():
		var avg := 0.0
		for k in known:
			avg += k
		avg /= known.size()
		for a in 3:
			if size[a] <= 0.0:
				s[a] = avg
	inst.scale = s
	var box := _aabb_of(inst, holder)
	inst.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.position = pos
	holder.rotation_degrees.y = rot
	box = _aabb_of(inst, holder)
	holder.set_meta("size", box.size)
	if label != "":
		var it := _interactable(label, box.size, Vector3(0, box.size.y / 2.0, 0), holder, LAYER_WORLD | LAYER_INTERACT)
		holder.set_meta("interactable", it)
	elif solid:
		_collider(box.size * Vector3(0.96, 1.0, 0.96), Vector3(0, box.size.y / 2.0, 0), holder)
	props[model] = holder
	if Game.autotest:
		print("prop %-22s brut %s -> %s" % [model, _fmt(raw.size), _fmt(box.size)])
	return holder


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


# ------------------------------------------------------------------ murs, pièces, portes

## Mur droit parallèle à l'axe X (axis = "x") ou Z (axis = "z"), de u0 à u1 le long de l'axe,
## centré sur c (l'autre coordonnée), d'épaisseur t, du sol y0 jusqu'à y0 + h.
## holes : ouvertures [u_début, u_fin, y_bas, y_haut] (u absolu le long du mur, y relatif au sol).
func wall(axis: String, u0: float, u1: float, c: float, h: float, holes := [], mat: Material = null, t := 0.1, y0 := 0.0, parent: Node3D = self) -> void:
	if mat == null:
		mat = mats.wall
	var hs := holes.duplicate()
	hs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var u := u0
	for hl in hs:
		if hl[0] > u + 0.001:
			_wall_piece(axis, u, hl[0], c, y0, y0 + h, mat, t, parent)
		if hl[2] > 0.001:
			_wall_piece(axis, hl[0], hl[1], c, y0, y0 + hl[2], mat, t, parent)
		if hl[3] < h - 0.001:
			_wall_piece(axis, hl[0], hl[1], c, y0 + hl[3], y0 + h, mat, t, parent)
		u = maxf(u, hl[1])
	if u < u1 - 0.001:
		_wall_piece(axis, u, u1, c, y0, y0 + h, mat, t, parent)


func _wall_piece(axis: String, a: float, b: float, c: float, ya: float, yb: float, mat: Material, t: float, parent: Node3D) -> void:
	var size: Vector3
	var pos: Vector3
	if axis == "x":
		size = Vector3(b - a, yb - ya, t)
		pos = Vector3((a + b) / 2.0, (ya + yb) / 2.0, c)
	else:
		size = Vector3(t, yb - ya, b - a)
		pos = Vector3(c, (ya + yb) / 2.0, (a + b) / 2.0)
	_box(size, pos, mat, true, parent)


## Habillage d'un mur côté pièce : lambris (ou carrelage), cimaise, plinthe, corniche.
## face : coordonnée de la face du mur ; dir : +1 ou -1, vers l'intérieur de la pièce.
## gaps : passages [u_début, u_fin] où le bas du mur est interrompu (portes).
## style : dado_h (hauteur du lambris, 0 = aucun), dado (matière), rail (cimaise), base (plinthe), crown (corniche).
func trim(axis: String, u0: float, u1: float, face: float, dir: float, h: float, gaps := [], style := {}, y0 := 0.0, parent: Node3D = self) -> void:
	var dado_h: float = style.get("dado_h", 0.92)
	var dado: Material = style.get("dado", mats.wainscot)
	var wood: Material = style.get("wood", mats.wood_dark)
	var crown: Material = style.get("crown_mat", mats.paint)
	var spans := _spans(u0, u1, gaps)
	var wt := 0.022
	for s in spans:
		if dado_h > 0.0:
			_trim_piece(axis, s[0], s[1], face + dir * wt / 2.0, y0 + dado_h / 2.0, dado_h, wt, dado, parent)
			if style.get("rail", true):
				_trim_piece(axis, s[0], s[1], face + dir * 0.022, y0 + dado_h + 0.02, 0.045, 0.045, wood, parent)
		if style.get("base", true):
			var off := (wt if dado_h > 0.0 else 0.0) + 0.017
			_trim_piece(axis, s[0], s[1], face + dir * off, y0 + 0.055, 0.11, 0.035, wood, parent)
	if style.get("crown", true):
		_trim_piece(axis, u0, u1, face + dir * 0.035, y0 + h - 0.035, 0.07, 0.07, crown, parent)
		_trim_piece(axis, u0, u1, face + dir * 0.055, y0 + h - 0.085, 0.03, 0.11, crown, parent)


func _spans(u0: float, u1: float, gaps: Array) -> Array:
	var gs := gaps.duplicate()
	gs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := []
	var u := u0
	for g in gs:
		if g[0] > u + 0.01:
			out.append([u, g[0]])
		u = maxf(u, g[1])
	if u < u1 - 0.01:
		out.append([u, u1])
	return out


func _trim_piece(axis: String, a: float, b: float, c: float, y: float, hh: float, depth: float, mat: Material, parent: Node3D) -> void:
	if axis == "x":
		_box(Vector3(b - a, hh, depth), Vector3((a + b) / 2.0, y, c), mat, false, parent)
	else:
		_box(Vector3(depth, hh, b - a), Vector3(c, y, (a + b) / 2.0), mat, false, parent)


## Pièce fermée : sol, plafond, quatre murs posés à l'extérieur du rectangle intérieur r
## (r.position = (x0, z0), r.size = (largeur en x, profondeur en z)), et habillage intérieur.
## holes : {"n": [...], "s": [...], "w": [...], "e": [...]} ouvertures de chaque mur
## (n = côté z0, s = côté z1, w = côté x0, e = côté x1), au format de wall().
## style : wall, floor, ceil (matières), t (épaisseur des murs) + options de trim().
func room_shell(r: Rect2, h: float, y0 := 0.0, holes := {}, style := {}, parent: Node3D = self) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var t: float = style.get("t", 0.1)
	var wm: Material = style.get("wall", mats.wall)
	var ft := 0.1
	_box(Vector3(r.size.x + 2 * t, ft, r.size.y + 2 * t), Vector3((x0 + x1) / 2.0, y0 - ft / 2.0, (z0 + z1) / 2.0), style.get("floor", mats.floor), true, parent)
	_box(Vector3(r.size.x + 2 * t, ft, r.size.y + 2 * t), Vector3((x0 + x1) / 2.0, y0 + h + ft / 2.0, (z0 + z1) / 2.0), style.get("ceil", mats.ceil), true, parent)
	wall("x", x0 - t, x1 + t, z0 - t / 2.0, h, holes.get("n", []), wm, t, y0, parent)
	wall("x", x0 - t, x1 + t, z1 + t / 2.0, h, holes.get("s", []), wm, t, y0, parent)
	wall("z", z0, z1, x0 - t / 2.0, h, holes.get("w", []), wm, t, y0, parent)
	wall("z", z0, z1, x1 + t / 2.0, h, holes.get("e", []), wm, t, y0, parent)
	trim("x", x0, x1, z0, 1.0, h, _door_gaps(holes.get("n", [])), style, y0, parent)
	trim("x", x0, x1, z1, -1.0, h, _door_gaps(holes.get("s", [])), style, y0, parent)
	trim("z", z0, z1, x0, 1.0, h, _door_gaps(holes.get("w", [])), style, y0, parent)
	trim("z", z0, z1, x1, -1.0, h, _door_gaps(holes.get("e", [])), style, y0, parent)


func _door_gaps(hs: Array) -> Array:
	var out := []
	for hl in hs:
		if hl[2] < 0.3:
			out.append([hl[0], hl[1]])
	return out


## Ouverture de porte standard centrée en u (format de wall()).
static func door_hole(u: float, w := 0.86, h := 2.04) -> Array:
	return [u - w / 2.0 - 0.02, u + w / 2.0 + 0.02, 0.0, h + 0.02]


## Porte à panneaux dans une ouverture. axis : direction du mur ("x" ou "z") ; at : centre de
## l'ouverture au sol (sur le plan médian du mur) ; swing : +1/-1, côté vers lequel elle s'ouvre.
func door(axis: String, at: Vector3, swing := 1.0, hinge_left := true, wall_t := 0.1, parent: Node3D = self) -> Door:
	var d := Door.new()
	d.wall_t = wall_t
	d.swing = swing
	d.hinge_left = hinge_left
	parent.add_child(d)
	d.position = at
	d.rotation.y = 0.0 if axis == "x" else -PI / 2.0
	d.build(self)
	return d
