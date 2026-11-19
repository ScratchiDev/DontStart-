extends HouseRoom
## La chambre d'amis : plus personne n'y dort. Le lit est sous une bâche (la fuite du toit), le
## vide-grenier de Mamie attend dans des cartons, le mannequin de couture garde le coin de la fenêtre.
## Deux choses y parlent : le babyphone Wi-Fi (connecté, sur le chevet) et le vieux téléviseur à tube,
## qui n'est PAS connecté (elle ne peut pas le prendre, seulement le déranger : il neige).
## Repère : intérieur x −3.2 → 3.2, z 2.7 → 6.3, sol y = 0, plafond 2.6. Porte P3 sur le mur x = 3.25
## en z 3.4 (zone de battant laissée libre : x 2.25 → 3.2, z 2.9 → 3.9). Fenêtre F3 sur la façade,
## x = −3.25, z 3.8 → 5.2 (allège 0,95).
##
## Fonctions publiques (pour le scénario et l'autotest) :
##   babyphone (Babyphone, « babyphone »), tv (Device du vieux téléviseur), tv_holder, antenna,
##   tin, madeleine, tin_it, madeleine_it, antenna_it, tv_it ;
##   tv_snow(secondes) (await possible), tv_crackle(secondes), open_tin(), eat_madeleine(),
##   examine_antenna(), unscrew_antenna(), set_lamp(on), restore().
## Événements Haunt.story_event : « cle_bureau_prise », « madeleine_mangee », « antenne_examinee »,
## « antenne_prise ». (Les simples regards sont notés au journal : {"ev": "examine", "what": …}.)
## Drapeaux Game.flags : « boite_ouverte », « madeleine_mangee », « antenne_examinee »,
## « antenne_prise », « tele_a_neige », « amis_lampadaire ».

const XW := -3.188       # face du papier peint, façade (fenêtre F3)
const XE := 3.188        # mur du couloir (porte P3)
const ZN := 2.712        # mur de la chambre de ta mère
const ZS := 6.288        # pignon (tête du lit)
const DADO := 0.022      # lambris (sous 0,92 m)

## Place du joueur devant le téléviseur (autotest) : debout sur le tapis, face à la télé.
const PLAYER_AT_TV := Vector3(-1.2, 0, 3.8)
const PLAYER_AT_TV_YAW := 0.0
const TV_POS := Vector3(-1.2, 0, 2.95)
const TV_SCALE := 1.42            # televisionVintage : 0,41 m de large au naturel
const BUCKET_POS := Vector3(1.3, 0, 3.6)
const LEAK_Y := 2.6
const DRIP_PERIOD := 3.0          # une goutte toutes les trois secondes
const BUCKET_WATER_Y := 0.17
const DESK_POS := Vector3(-2.85, 0, 3.45)
const TIN_POS := Vector3(-2.9, 0.0, 3.88)   # y : posée sur le plateau (calculé)

## Passe « triple A », lot V2-AMIS. Toiles simulées HORS JEU (godot/tools/gen_bache.py : dynamique par
## positions, collisions avec le lit, le carton, les couvertures, la tête de lit, le chevet et le sol ;
## maillages double face, UV en mètres de toile) : rien n'est calculé à la construction. Si un fichier
## manque, l'ancien champ de hauteurs revient.
const COULOIR := preload("res://scripts/house/rooms/couloir.gd")   # _tube_mesh (pied du mannequin)
const TARP_MESH := "res://assets/models/amis/bache_lit.res"           # repère de la pièce
const HOUSSE_MESH := "res://assets/models/amis/housse_bergere.res"    # repère du fauteuil (avant +z)
## Froissure du polyéthylène (gen_bache.py froissure) : plis d'emballage et faux plis, 0,8 m par tuile.
const TARP_NORMAL := "res://assets/textures/amis/bache_normal_gl.jpg"
const TARP_TILE := 0.8
## Vraie carte : vieille bâche gris laiteux (albédo ≈ 0,48), satinée, un peu translucide.
const TARP_ROUGH_NET := 0.46
const TARP_BACKLIGHT_NET := 0.2
const TARP_ALBEDO_NET := Color(0.43, 0.45, 0.47)
## Robe du mannequin : tissu marine à pois crème de 1 cm (gen_bache.py pois), 8 pois de 2,4 cm par tuile.
const DRESS_DOTS := "res://assets/textures/amis/robe_pois.png"
const DRESS_TILE := 0.192
## Ancienne texture de pois (rendu logiciel) : 4 pois par tuile de 64 px, à 2,6 cm.
const DRESS_TILE_OLD := 0.104

var house: House
var rng := RandomNumberGenerator.new()

var babyphone: Babyphone
var tv: Device
var tv_holder: Node3D
var tv_it: Interactable
var antenna: Node3D
var antenna_it: Interactable
var tin: Node3D
var tin_lid: Node3D
var tin_inside: Node3D
var tin_key: Node3D
var tin_it: Interactable
var madeleine: Node3D
var madeleine_it: Interactable
var lamp_light: OmniLight3D
var lamp_shade: StandardMaterial3D
var lamp_it: Interactable
var lamp_on := false
var _lamp_liner: StandardMaterial3D
var _lamp_bulb: StandardMaterial3D

var desk_top := 0.76
var _tv_id := 0
var _antenna_busy := false
var _drip: MeshInstance3D
var _ripple: MeshInstance3D
var _drip_t := 0.0
var _ripple_t := -1.0
var _dripped := false

var _vhs: Array[Node3D] = []          # cassettes posées sur le meuble télé
var _tv_kenney: Array[Node3D] = []    # molettes et voyant de la télé Kenney (cachés avec elle)
var _antenna_lead: Node3D             # fil plat et vis de l'antenne (refaits sur la télé de 1990)
var _old_stains: Array[Decal] = []    # auréoles d'avant (remplacées par Wear en vraie carte)

var _new_white: StandardMaterial3D
var _cable_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _old_cable: StandardMaterial3D
var _chrome: StandardMaterial3D


func furnish(h: House) -> void:
	house = h
	rng.seed = 2703
	_new_white = _plain(Color(0.74, 0.74, 0.72), 0.4)
	_cable_mat = _plain(Color(0.9, 0.9, 0.88), 0.4)
	_tape_mat = _plain(Color(0.78, 0.76, 0.68), 0.3)
	_old_cable = _plain(Color(0.22, 0.15, 0.1), 0.6)
	_chrome = _plain(Color(0.74, 0.74, 0.76), 0.25, 0.6)
	_rug()
	_bed()
	_nightstand()
	_floor_lamp()
	_tv()
	_antenna()
	_sewing()
	_mannequin()
	_boxes()
	_covered_armchair()
	_bucket()
	_wardrobe()
	_drapes()
	_walls()
	_ceiling()
	_update_antenna_label()
	Game.inventory_changed.connect(_update_antenna_label)


# ------------------------------------------------------------------ outils

func _m(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	return _grimy(_plain(c, rough, metal))


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, hh: float, seg := 16) -> CylinderMesh:
	return Connected.cyl(r_top, r_bot, hh, seg)


func _sphere(r: float, seg := 12) -> SphereMesh:
	return Connected.sphere(r, seg)


func _ellipsoid(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self, seg := 16) -> MeshInstance3D:
	var mi := _mesh(_sphere(0.5, seg), pos, mat, Vector3.ZERO, parent)
	mi.scale = size
	return mi


func _no_gi(mi: GeometryInstance3D) -> GeometryInstance3D:
	return Connected.no_gi(mi)


## Tube droit de a à b.
func _rod(a: Vector3, b: Vector3, r: float, mat: Material, parent: Node3D = self, seg := 10) -> MeshInstance3D:
	var d := b - a
	var l := d.length()
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(r, r, l, seg)
	mi.material_override = mat
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) / 2.0)
	parent.add_child(mi)
	return mi


## Pièces de décor fondues en un seul maillage (un seul appel de dessin) : [maillage, Transform3D]. Hors
## de la cuisson VoxelGI, comme les modèles Poly Haven (la lumière rebondie les éclaire quand même).
func _merged(parts: Array, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var st := SurfaceTool.new()
	for p in parts:
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


func _cm(r_top: float, r_bot: float, hh: float, seg := 24, cap_top := true, cap_bottom := true, flip := false) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = hh
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = cap_top
	c.cap_bottom = cap_bottom
	c.flip_faces = flip
	return c


func _sm(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 3)
	return s


static func _at(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


## Tige de a à b (rayon r) : [maillage, Transform3D] pour _merged.
func _rod_part(a: Vector3, b: Vector3, r: float, seg := 8) -> Array:
	var v := b - a
	return [_cm(r, r, v.length(), seg), Transform3D(Basis(Quaternion(Vector3.UP, v.normalized())), (a + b) / 2.0)]


const LINEN := "res://assets/textures/terlenka/terlenka_%s_1k.jpg"

## Toile de coton fine (terlenka, Poly Haven, CC0) posée dans le monde (triplanaire, « meters » mètres par
## répétition), teintée, avec la crasse de la maison : la housse du fauteuil, le buste du mannequin.
## Vraie carte : bâche du lit et drap de la bergère moins clairs (albédo ≈ 0,5 à 0,6 en linéaire).
const TARP_NET := Color(0.5, 0.53, 0.56)
const HOUSSE_NET := Color(0.74, 0.78, 0.8)


func _linen(tint: Color, meters := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(LINEN % "diff")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(LINEN % "nor_gl")
	m.roughness = 1.0
	m.roughness_texture = load(LINEN % "arm")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	Surfaces.world_uv(m, meters)
	return _grimy(m, 1.1)


## Une partie d'un modèle Poly Haven (les maillages dont le nom commence par « keep » : une des deux
## valises du glTF, par exemple), matières corrigées comme par model(), orientée par « basis » (avant du
## modèle vers +z), pied en « pos », centrée en x et z. Méta « size » : sa boîte posée (repère du nœud).
func _ph_part(ph_id: String, keep: String, pos: Vector3, basis: Basis, node_name: String, solid := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	var inst := _ph_instance(ph_id, {})
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(n) and not String(n.name).begins_with(keep):
			n.free()
	for g in inst.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	holder.add_child(inst)
	inst.transform = Transform3D(basis, Vector3.ZERO)
	var box := _aabb_in(inst, inst.transform)
	inst.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.position = pos
	holder.set_meta("size", box.size)
	holder.set_meta("ph_id", ph_id)
	if solid:
		_collider(box.size * Vector3(0.96, 1.0, 0.96), Vector3(0, box.size.y / 2.0, 0), holder)
	return holder


func _hint(text: String) -> void:
	Game.hint(text, clampf(Haunt.subtitle_time(text), 3.5, 9.0))


func _haunt() -> Haunt:
	return Haunt.of(get_tree())


func _log(what: String) -> void:
	var hn := _haunt()
	if hn:
		hn.log({"ev": "examine", "what": what, "room": "amis"})


func _story(event_name: String) -> void:
	var hn := _haunt()
	if hn:
		hn.story_event(event_name, {"room": "amis"})


func _look(label: String, size: Vector3, pos: Vector3, text: String, what: String, reach := 2.2) -> Interactable:
	var it := _interactable(label, size, pos, self, LAYER_INTERACT, reach)
	it.used.connect(func(_i: Interactable) -> void:
		_hint(text)
		_log(what))
	return it


func _retire(it: Interactable) -> void:
	if it:
		it.enabled = false
		it.collision_layer = 0


## Câble en segments droits ; neuf et blanc il est scotché tous les 40 cm (comme dans le couloir).
func _cable(points: Array, normal: Vector3, tape := true, mat: Material = null, radius := 0.0028) -> void:
	if mat == null:
		mat = _cable_mat
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var d := b - a
		var l := d.length()
		if l < 0.001:
			continue
		var dir := d / l
		var up := normal if absf(dir.dot(normal)) < 0.9 else (Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(radius * 2.0, radius * 2.0, l + radius * 2.0)
		mi.mesh = bm
		mi.material_override = mat
		mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) / 2.0)
		add_child(mi)
		if not tape or absf(dir.dot(normal)) > 0.1 or l < 0.25:
			continue
		var n := maxi(1, int(l / 0.4))
		var across := normal.cross(dir).normalized()
		for k in n:
			var p := a + dir * (l * (k + 0.5) / n)
			var t := MeshInstance3D.new()
			var tb := BoxMesh.new()
			tb.size = Vector3(0.038, radius * 2.0 + 0.0012, 0.024)
			t.mesh = tb
			t.material_override = _tape_mat
			t.transform = Transform3D(Basis(across, normal, dir), p - normal * 0.0004)
			t.rotate_object_local(Vector3.UP, rng.randf_range(-0.12, 0.12))
			add_child(t)


func _socket(pos: Vector3, normal: Vector3, plug: Material = null) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Prise"
	add_child(holder)
	holder.position = pos
	holder.rotation.y = atan2(normal.x, normal.z)
	_box(Vector3(0.075, 0.075, 0.012), Vector3(0, 0, 0.006), _m(Color(0.74, 0.7, 0.6), 0.5), false, holder)
	_mesh(_cyl(0.023, 0.023, 0.004), Vector3(0, 0, 0.0125), _m(Color(0.62, 0.58, 0.5), 0.5), Vector3(PI / 2.0, 0, 0), holder)
	if plug:
		_box(Vector3(0.036, 0.042, 0.03), Vector3(0, 0, 0.03), plug, false, holder)
	return holder


func _decal(tex: Texture2D, center: Vector3, normal: Vector3, up: Vector3, size_u: float, size_v: float, depth := 0.2, mod := Color.WHITE) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size_u, depth, size_v)
	d.modulate = mod
	var y := normal.normalized()
	var z := -up.normalized()
	var x := y.cross(z)
	d.transform = Transform3D(Basis(x, y, z), center)
	add_child(d)
	return d


func _retint(holder: Node3D, by_name: Dictionary) -> void:
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name.to_lower() if src else ""
			if by_name.has(key):
				mi.set_surface_override_material(i, by_name[key])


## Cylindre ouvert (seau, boîte en fer) : paroi extérieure, rebord, paroi intérieure, fond intérieur et
## dessous. r_bot / r_top : rayons extérieurs ; wall : épaisseur ; bottom : épaisseur du fond.
func _open_cyl(r_bot: float, r_top: float, hh: float, wall: float, seg := 24, bottom := 0.004) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP * hh
	var tilt := (r_bot - r_top) / hh
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0 := (d0 + Vector3.UP * tilt).normalized()
		var n1 := (d1 + Vector3.UP * tilt).normalized()
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		# paroi extérieure
		var A := d0 * r_bot
		var B := d1 * r_bot
		var C := d1 * r_top + up
		var D := d0 * r_top + up
		_tri(st, [A, B, C], [n0, n1, n1], [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)])
		_tri(st, [A, C, D], [n0, n1, n0], [Vector2(u0, 1), Vector2(u1, 0), Vector2(u0, 0)])
		# paroi intérieure (normales vers le centre)
		var ri_b := r_bot - wall
		var ri_t := r_top - wall
		var A2 := d0 * ri_b + Vector3.UP * bottom
		var B2 := d1 * ri_b + Vector3.UP * bottom
		var C2 := d1 * ri_t + up
		var D2 := d0 * ri_t + up
		_tri(st, [A2, C2, B2], [-n0, -n1, -n1], [Vector2(u0, 1), Vector2(u1, 0), Vector2(u1, 1)])
		_tri(st, [A2, D2, C2], [-n0, -n0, -n1], [Vector2(u0, 1), Vector2(u0, 0), Vector2(u1, 0)])
		# rebord
		_tri(st, [D, C, C2], [Vector3.UP, Vector3.UP, Vector3.UP], [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 0.02)])
		_tri(st, [D, C2, D2], [Vector3.UP, Vector3.UP, Vector3.UP], [Vector2(u0, 0), Vector2(u1, 0.02), Vector2(u0, 0.02)])
		# fond intérieur, dessous
		var cb := Vector3.UP * bottom
		_tri(st, [cb, A2, B2], [Vector3.UP, Vector3.UP, Vector3.UP], [Vector2(0.5, 0.5), Vector2(0.5 + d0.x * 0.5, 0.5 + d0.z * 0.5), Vector2(0.5 + d1.x * 0.5, 0.5 + d1.z * 0.5)])
		_tri(st, [Vector3.ZERO, B, A], [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5)])
	return st.commit()


func _tri(st: SurfaceTool, v: Array, n: Array, uv: Array) -> void:
	for k in 3:
		st.set_normal(n[k])
		st.set_uv(uv[k])
		st.add_vertex(v[k])


## Disque horizontal (normale +y), texture plaquée de haut en bas (couvercle, eau d'un seau).
func _disc(r: float, seg := 32) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p := Vector3(cos(a0), 0, sin(a0)) * r
		var q := Vector3(cos(a1), 0, sin(a1)) * r
		_tri(st, [Vector3.ZERO, p, q], [Vector3.UP, Vector3.UP, Vector3.UP],
			[Vector2(0.5, 0.5), Vector2(0.5 + p.x / (2.0 * r), 0.5 + p.z / (2.0 * r)), Vector2(0.5 + q.x / (2.0 * r), 0.5 + q.z / (2.0 * r))])
	return st.commit()


# ------------------------------------------------------------------ images générées

## Tapis de laine des années 70 : bordure, champ grenat, médaillon central, usé au passage.
func _rug_texture(w: int, hh: int) -> ImageTexture:
	var img := Image.create_empty(w, hh, false, Image.FORMAT_RGB8)
	var field := Color(0.36, 0.1, 0.09)
	var navy := Color(0.11, 0.12, 0.2)
	var ochre := Color(0.58, 0.42, 0.2)
	var cream := Color(0.66, 0.6, 0.48)
	var weft := Color(0.46, 0.4, 0.34)
	var nz := FastNoiseLite.new()
	nz.seed = 77
	nz.frequency = 0.05
	for y in hh:
		for x in w:
			var e := mini(mini(x, w - 1 - x), mini(y, hh - 1 - y))
			var c := field
			if e < 2:
				c = navy.darkened(0.3)
			elif e < 9:
				c = navy
				if (x + y) % 6 < 2 and e > 3 and e < 8:
					c = ochre
			elif e == 9 or e == 11:
				c = cream
			elif e == 10:
				c = ochre
			else:
				var dx := absf(x - (w - 1) / 2.0) / (w * 0.32)
				var dy := absf(y - (hh - 1) / 2.0) / (hh * 0.3)
				var dd := dx + dy
				if dd < 0.25:
					c = ochre
				elif dd < 0.45:
					c = navy
				elif dd < 0.55:
					c = cream
				elif dd < 0.95 and (int(dd * 20.0) % 3 == 0):
					c = field.lightened(0.12)
				# coins du champ
				var cx := minf(x - 11.0, w - 12.0 - x)
				var cy := minf(y - 11.0, hh - 12.0 - y)
				if cx + cy < 9.0 and cx >= 0.0 and cy >= 0.0:
					c = navy
			# usure : le chemin entre la porte et le lit
			var u := float(x) / (w - 1)
			var v := float(y) / (hh - 1)
			var wear := clampf((1.0 - absf(v - 0.55) * 2.2) * (0.5 + 0.8 * nz.get_noise_2d(x, y)) * (0.4 + 0.6 * u), 0.0, 1.0)
			c = c.lerp(weft, wear * 0.55)
			c = c.lerp(Color(0.3, 0.25, 0.22), 0.25)
			c = c.darkened(rng.randf() * 0.12)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Fond de boîte à couture : des boutons de toutes les couleurs.
func _buttons_texture() -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.09, 0.07))
	var cols := [Color(0.85, 0.82, 0.75), Color(0.15, 0.15, 0.18), Color(0.6, 0.12, 0.12), Color(0.2, 0.3, 0.6),
		Color(0.55, 0.4, 0.2), Color(0.3, 0.5, 0.3), Color(0.9, 0.75, 0.3)]
	for k in 90:
		var cx := rng.randf_range(0, 64)
		var cy := rng.randf_range(0, 64)
		var r := rng.randf_range(2.0, 4.5)
		var c: Color = cols[rng.randi() % cols.size()]
		for y in range(int(cy - r), int(cy + r) + 1):
			for x in range(int(cx - r), int(cx + r) + 1):
				if x < 0 or y < 0 or x >= 64 or y >= 64:
					continue
				var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
				if d <= r:
					var hole := d < r * 0.35 and (absf(x + 0.5 - cx) > 0.6 or absf(y + 0.5 - cy) > 0.6) and d > r * 0.12
					img.set_pixel(x, y, c.darkened(0.45) if hole else c.darkened(d / r * 0.25))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Tissu bleu marine à petits pois blancs (la robe en cours) : pois en quinconce, bords adoucis.
func _dots_texture() -> ImageTexture:
	var n := 64
	var cell := 16.0
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var navy := Color(0.1, 0.12, 0.22)
	var cream := Color(0.85, 0.83, 0.78)
	for y in n:
		for x in n:
			var row := int(y / cell)
			var cx := cell * 0.5 + (cell * 0.5 if row % 2 == 1 else 0.0)
			var dx := fposmod(x + 0.5 - cx, cell) - cell * 0.5
			var dy := fposmod(y + 0.5, cell) - cell * 0.5
			var k := clampf(3.4 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			img.set_pixel(x, y, navy.darkened(rng.randf() * 0.1).lerp(cream, k))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ le tapis

func _rug() -> void:
	var holder := Node3D.new()
	holder.name = "TapisAmis"
	add_child(holder)
	holder.position = Vector3(-0.2, 0, 3.9)
	holder.rotation.y = -0.03
	var w := 1.75
	var d := 1.05
	_box(Vector3(w, 0.008, d), Vector3(0, 0.004, 0), _plain(Color(0.12, 0.05, 0.04), 1.0), false, holder)
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _rug_texture(120, 72)
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mesh(pm, Vector3(0, 0.0082, 0), _grimy(mat, 0.5), Vector3.ZERO, holder)


# ------------------------------------------------------------------ le lit sous sa bâche

func _bed() -> void:
	prop("bedDouble", Vector3(0.0, 0, 5.25), 180.0, Vector3(1.5, 0.0, 2.0), true,
		{"carpet": Color(0.46, 0.3, 0.3), "carpetwhite": Color(0.72, 0.68, 0.6)})
	var top := 0.445
	# sous la bâche : un carton et des couvertures pliées, posés là « en attendant »
	var cb := _box(Vector3(0.4, 0.285, 0.36), Vector3(0.34, top + 0.1425, 4.65), _m(Color(0.5, 0.36, 0.22), 0.95))
	# (droit : la toile a été simulée sur une boîte alignée sur les axes ; tourné, ses coins la perçaient)
	cb.rotation.y = 0.0
	for k in 3:
		_box(Vector3(0.52 - k * 0.02, 0.04, 0.58 - k * 0.03), Vector3(-0.36, top + 0.02 + k * 0.04, 4.85),
			_m([Color(0.55, 0.45, 0.32), Color(0.3, 0.35, 0.45), Color(0.6, 0.3, 0.25)][k], 1.0))
	# la bâche : un drap de plastique laiteux, plissé, qui retombe jusqu'au sol
	var tarp := StandardMaterial3D.new()
	tarp.albedo_color = Color(0.6, 0.64, 0.68)
	tarp.roughness = 0.42
	tarp.metallic_specular = 0.6
	if not Builder.soft_render():
		# vraie carte : vieille bâche de peintre gris laiteux, satinée et froissée (plis d'emballage, faux
		# plis), un peu translucide ; poussiéreuse. Elle redevient une silhouette dans le faisceau (elle
		# brûlait en beige sous la lampe : revues de la vague 2)
		tarp.albedo_color = TARP_ALBEDO_NET
		tarp.roughness = TARP_ROUGH_NET
		tarp.metallic_specular = 0.4
		if ResourceLoader.exists(TARP_NORMAL):
			tarp.normal_enabled = true
			tarp.normal_texture = load(TARP_NORMAL)
			tarp.normal_scale = 1.5
			tarp.uv1_scale = Vector3(1.0 / TARP_TILE, 1.0 / TARP_TILE, 1.0)
		tarp.backlight_enabled = true
		tarp.backlight = Color(TARP_BACKLIGHT_NET, TARP_BACKLIGHT_NET, TARP_BACKLIGHT_NET)
		tarp = _grimy(tarp, 1.3)
	var draped: Mesh = load(TARP_MESH) as Mesh if ResourceLoader.exists(TARP_MESH) else null
	if draped:
		# la toile simulée : elle déborde du matelas de 10 à 15 cm, tombe en plis évasés jusqu'à 1 ou 2 cm
		# du sol, se tend en plis du carton vers la tête de lit ; coin du chevet recoupé
		var dm := _no_gi(_mesh(draped, Vector3.ZERO, tarp))
		dm.name = "Bache"
		_tarp_tape(true)
		return
	_tarp_heightfield(top, tarp)
	_tarp_tape(false)


## Les deux bandes de scotch qui tiennent la bâche à la tête de lit (vraie carte, toile simulée : du
## ruban adhésif brun, Tape004, sinon deux plaques).
func _tarp_tape(draped: bool) -> void:
	if draped and not Builder.soft_render() and ResourceLoader.exists("res://assets/textures/Tape004/Tape004_albedo.png"):
		for x in [-0.52, 0.5]:
			# (bande couchée sur le dessus de la tête de lit, dans le sens du lit, qui mord sur la bâche)
			var q := _tape_quad(Vector2(0.17, 0.05), 0 if x < 0.0 else 2)
			q.position = Vector3(x, 0.6505, 6.17)
			q.rotation = Vector3(-PI / 2.0, PI / 2.0 + (0.08 if x < 0.0 else -0.06), 0.0)
			q.name = "Scotch"
		return
	for x in [-0.55, 0.55]:
		_box(Vector3(0.05, 0.002, 0.14), Vector3(x, 0.652, 6.16), _plain(Color(0.45, 0.32, 0.18), 0.4))


## Morceau de ruban adhésif (atlas Tape004 : 0, 1, 2 = bandes horizontales aux bouts déchirés), dans le
## plan x-y du nœud (QuadMesh), de taille « size » (m : x le long de la bande).
func _tape_quad(size: Vector2, piece: int, parent: Node3D = self) -> MeshInstance3D:
	# rectangles des morceaux dans l'atlas (u0, v0, u1, v1), relevés sur l'image
	var rects := [Rect2(0.141, 0.016, 0.445, 0.185), Rect2(0.148, 0.262, 0.44, 0.215),
		Rect2(0.146, 0.531, 0.395, 0.184)]
	var r: Rect2 = rects[clampi(piece, 0, 2)]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/Tape004/Tape004_albedo.png")
	m.albedo_color = Color(0.5, 0.4, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.35
	m.metallic_specular = 0.6
	m.uv1_scale = Vector3(r.size.x, r.size.y, 1.0)
	m.uv1_offset = Vector3(r.position.x, r.position.y, 0.0)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return _no_gi(mi) as MeshInstance3D


## L'ancienne bâche (si le maillage simulé manque) : un champ de hauteurs posé sur le lit.
func _tarp_heightfield(top: float, tarp: Material) -> void:
	var supports := [
		[Rect2(-0.75, 4.25, 1.5, 1.82), top + 0.008],         # matelas
		[Rect2(-0.58, 5.72, 1.16, 0.35), top + 0.05],          # oreillers
		[Rect2(-0.75, 6.07, 1.5, 0.18), 0.645],                # tête de lit
		[Rect2(0.12, 4.45, 0.44, 0.42), top + 0.315],          # le carton
		[Rect2(-0.62, 4.55, 0.54, 0.6), top + 0.135],          # les couvertures
	]
	var x0 := -0.9
	var x1 := 0.9
	var z0 := 4.0
	var z1 := 6.24
	var step := 0.025
	var nx := int((x1 - x0) / step) + 1
	var nz := int((z1 - z0) / step) + 1
	var hmap := PackedFloat32Array()
	hmap.resize(nx * nz)
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 4.0
	for j in nz:
		for i in nx:
			var p := Vector2(x0 + i * step, z0 + j * step)
			var hv := 0.016
			var near := 1.0
			for s in supports:
				var r: Rect2 = s[0]
				var tp: float = s[1]
				var dx := maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x))
				var dz := maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))
				var dist := sqrt(dx * dx + dz * dz)
				near = minf(near, dist)
				hv = maxf(hv, tp - (9.0 * dist + 30.0 * dist * dist))
			var wr := noise.get_noise_2d(p.x, p.y)
			hv += wr * (0.006 + 0.01 * clampf(near * 10.0, 0.0, 1.0)) if hv > 0.03 else absf(wr) * 0.02
			hmap[j * nx + i] = hv
	# un léger lissage, pour que le plastique tombe sans marches
	var sm := hmap.duplicate()
	for j in range(1, nz - 1):
		for i in range(1, nx - 1):
			var acc := 0.0
			for dj in [-1, 0, 1]:
				for di in [-1, 0, 1]:
					acc += hmap[(j + dj) * nx + (i + di)]
			sm[j * nx + i] = acc / 9.0
	# des faux plis fins, après le lissage : le plastique froissé
	var crinkle := FastNoiseLite.new()
	crinkle.seed = 31
	crinkle.frequency = 14.0
	crinkle.fractal_octaves = 2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var px := x0 + i * step
			var pz := z0 + j * step
			var cy := crinkle.get_noise_2d(px, pz) * 0.009
			st.set_uv(Vector2(float(i) / nx, float(j) / nz))
			st.add_vertex(Vector3(px, sm[j * nx + i] + cy, pz))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	# (bâche de peintre en polyéthylène épais, opaque et laiteuse : transparente, elle faisait bloc de
	# gélatine : pas d'occlusion ni d'ombre reçue dans la passe transparente, et une ombre pleine quand même)
	var mi := _no_gi(_mesh(st.commit(), Vector3.ZERO, tarp))
	mi.name = "Bache"


# ------------------------------------------------------------------ le chevet et le babyphone

func _nightstand() -> void:
	var ns := prop("cabinetBedDrawer", Vector3(1.15, 0, 5.95), 180.0, Vector3(0.45, 0.0, 0.0), true)
	var top := (ns.get_meta("size") as Vector3).y
	_box(Vector3(0.3, 0.003, 0.24), Vector3(1.13, top + 0.0015, 5.95), _m(Color(0.84, 0.8, 0.7), 0.95))
	babyphone = Babyphone.new()
	babyphone.name = "Babyphone"
	babyphone.device_id = "babyphone"
	babyphone.room_id = "amis"
	add_child(babyphone)
	babyphone.position = Vector3(1.08, top + 0.003, 5.93)
	babyphone.rotation.y = PI - 0.55      # tourné vers la porte
	babyphone.build()
	# un réveil mécanique arrêté, un verre d'eau oublié
	var clock := Node3D.new()
	clock.name = "Reveil"
	add_child(clock)
	clock.position = Vector3(1.27, top + 0.003, 6.0)
	clock.rotation.y = PI - 0.2
	var brass := _m(Color(0.6, 0.48, 0.25), 0.35, 0.6)
	_mesh(_cyl(0.045, 0.045, 0.035, 20), Vector3(0, 0.055, 0), brass, Vector3(PI / 2.0, 0, 0), clock)
	var face := StandardMaterial3D.new()
	face.albedo_texture = load("res://assets/images/clock_face.png")
	face.roughness = 0.6
	var fq := _mesh(_disc(0.039, 24), Vector3(0, 0.055, 0.018), face, Vector3(PI / 2.0, 0, 0), clock)
	fq.name = "Cadran"
	for s in [-1.0, 1.0]:
		_mesh(_sphere(0.017, 10), Vector3(s * 0.028, 0.1, -0.004), brass, Vector3.ZERO, clock)
		_rod(Vector3(s * 0.025, 0.0, 0.0), Vector3(s * 0.03, 0.025, 0.0), 0.004, brass, clock, 6)
	_no_gi(_mesh(_cyl(0.028, 0.025, 0.09, 14), Vector3(1.005, top + 0.048, 6.035), mats.glass))
	_mesh(_cyl(0.0255, 0.0225, 0.04, 14), Vector3(1.005, top + 0.024, 6.035), _plain(Color(0.2, 0.24, 0.22), 0.05))
	# le câble du chargeur : blanc, neuf, scotché le long du lambris jusqu'à la prise
	var bz := ZS - DADO - 0.003
	var back := babyphone.to_global(Vector3(0, 0.02, -0.03))
	_cable([back, Vector3(1.2, top + 0.004, 6.1), Vector3(1.2, top - 0.02, bz), Vector3(1.2, 0.262, bz),
		Vector3(1.5, 0.262, bz)], Vector3.FORWARD)
	_socket(Vector3(1.53, 0.25, ZS - DADO), Vector3.FORWARD, _new_white)


# ------------------------------------------------------------------ le lampadaire (éteint)

## Lampadaire des années 60 (remplace le Kenney « lampRoundFloor », même place, même clé dans props) :
## socle lesté et fût en laiton bruni, abat-jour conique en toile (sa doublure, plus claire, et
## l'ampoule s'allument avec lui : set_lamp). La toile laisse passer la lumière (pas d'ombre portée).
func _floor_lamp() -> void:
	var at := Vector3(-1.6, 0, 6.0)
	var lp := Node3D.new()
	lp.name = "lampRoundFloor"
	add_child(lp)
	lp.position = at
	lp.rotation.y = 0.4
	var ys := 1.22        # bas de l'abat-jour
	var hs := 0.3         # hauteur de l'abat-jour
	var rt := 0.125
	var rb := 0.205
	var brass := _grimy(_plain(Color(0.36, 0.28, 0.17), 0.4, 0.85), 1.5)
	var parts := [
		[_cm(0.125, 0.15, 0.028, 32), _at(Vector3(0, 0.014, 0))],
		[_cm(0.03, 0.06, 0.04, 16), _at(Vector3(0, 0.048, 0))],
		[_cm(0.011, 0.011, ys + 0.12 - 0.068, 10), _at(Vector3(0, 0.068 + (ys + 0.12 - 0.068) / 2.0, 0))],
		[_cm(0.016, 0.016, 0.03, 12), _at(Vector3(0, 0.66, 0))],
		[_cm(0.019, 0.016, 0.05, 12), _at(Vector3(0, ys + 0.12, 0))],
		# l'interrupteur à molette, sous la douille
		[_cm(0.006, 0.006, 0.05, 8), _at(Vector3(0.03, ys + 0.105, 0), Vector3(0, 0, PI / 2.0))],
		[_cm(0.009, 0.009, 0.012, 10), _at(Vector3(0.058, ys + 0.105, 0), Vector3(0, 0, PI / 2.0))],
	]
	_merged(parts, brass, lp)
	# l'armature du haut de l'abat-jour (cercle, croisillon, tige, bouton) : autour de l'ampoule, sans
	# ombre portée (sinon un grand cercle sombre au plafond quand la lampe est allumée)
	var ring := TorusMesh.new()
	ring.inner_radius = rt - 0.006
	ring.outer_radius = rt - 0.001
	ring.rings = 32
	ring.ring_segments = 4
	var top_parts := [[ring, _at(Vector3(0, ys + hs - 0.004, 0))], [_sm(0.012, 8), _at(Vector3(0, ys + hs + 0.014, 0))]]
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		top_parts.append(_rod_part(Vector3(0, ys + hs - 0.004, 0), Vector3(cos(a), 0, sin(a)) * (rt - 0.004) + Vector3(0, ys + hs - 0.004, 0), 0.0025, 4))
	top_parts.append(_rod_part(Vector3(0, ys + 0.2, 0), Vector3(0, ys + hs, 0), 0.004, 6))
	_merged(top_parts, brass, lp).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp_shade = _plain(Color(0.6, 0.48, 0.33), 1.0)
	lamp_shade.emission_enabled = true
	lamp_shade.emission = Color(1.0, 0.68, 0.38)
	lamp_shade.emission_energy_multiplier = 0.0
	_lamp_liner = _plain(Color(0.7, 0.62, 0.48), 1.0)
	_lamp_liner.emission_enabled = true
	_lamp_liner.emission = Color(1.0, 0.74, 0.45)
	_lamp_liner.emission_energy_multiplier = 0.0
	_lamp_bulb = _plain(Color(0.86, 0.84, 0.78), 0.3)
	_lamp_bulb.emission_enabled = true
	_lamp_bulb.emission = Color(1.0, 0.8, 0.55)
	_lamp_bulb.emission_energy_multiplier = 0.0
	for p in [[_cm(rt, rb, hs, 40, false, false), lamp_shade], [_cm(rt - 0.003, rb - 0.003, hs - 0.002, 40, false, false, true), _lamp_liner],
			[_sm(0.03, 12), _lamp_bulb]]:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.material_override = p[1]
		mi.position.y = ys + 0.17 if p[1] == _lamp_bulb else ys + hs / 2.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		lp.add_child(mi)
	_collider(Vector3(0.34, ys + hs, 0.34), Vector3(0, (ys + hs) / 2.0, 0), lp)
	lp.set_meta("size", Vector3(rb * 2.0, ys + hs + 0.03, rb * 2.0))
	props["lampRoundFloor"] = lp
	Builder.tag(lp, "analogique")
	lamp_light = OmniLight3D.new()
	lamp_light.name = "Lampadaire"
	lamp_light.light_color = Color(1.0, 0.72, 0.42)
	lamp_light.light_energy = 0.0
	lamp_light.omni_range = 4.5
	lamp_light.omni_attenuation = 1.3
	lamp_light.shadow_enabled = false     # l'ombre seulement quand il est allumé (set_lamp)
	lamp_light.shadow_bias = 0.05
	lamp_light.position = Vector3(-1.6, 1.4, 6.0)
	if not Builder.soft_render():
		# (vraie carte : ombres douces de la taille de l'abat-jour en Ultra ; énergie allumée pour la sonde)
		lamp_light.set_meta("taille", 0.08)
		lamp_light.set_meta("energie_base", 0.55)
		lamp_light.light_size = Qualite.pcss_size(0.08)
	add_child(lamp_light)
	# son cordon, vieux, marron, jusqu'à la prise du pignon
	var bz := ZS - DADO - 0.003
	_cable([Vector3(-1.6, 0.012, 6.0), Vector3(-1.75, 0.006, 6.19), Vector3(-2.0, 0.006, 6.215), Vector3(-2.0, 0.13, bz),
		Vector3(-2.0, 0.235, bz)], Vector3.FORWARD, false, _old_cable, 0.0035)
	_socket(Vector3(-2.0, 0.25, ZS - DADO), Vector3.FORWARD, _m(Color(0.2, 0.18, 0.15), 0.5))
	lamp_it = _interactable("Allumer le lampadaire", Vector3(0.4, 1.6, 0.4), Vector3(-1.6, 0.8, 6.0), self, LAYER_INTERACT, 2.2)
	lamp_it.used.connect(func(_i: Interactable) -> void: set_lamp(not lamp_on))


## Le lampadaire de la chambre d'amis (analogique : elle ne le commande pas).
func set_lamp(on: bool) -> void:
	lamp_on = on
	Game.set_flag("amis_lampadaire", on)
	if lamp_light:
		_apply_lamp()
		if is_inside_tree():
			Sfx.play_at("metalClick", lamp_light.global_position + Vector3(0, -0.6, 0), -18.0, 0.8)


## Lumière, abat-jour, doublure et ampoule du lampadaire selon lamp_on (au-dessus de 1, l'ampoule et
## l'intérieur de l'abat-jour ont leur halo).
func _apply_lamp() -> void:
	lamp_light.light_energy = 0.55 if lamp_on else 0.0
	lamp_light.shadow_enabled = lamp_on
	lamp_shade.emission_energy_multiplier = 0.9 if lamp_on else 0.0
	_lamp_liner.emission_energy_multiplier = 1.5 if lamp_on else 0.0
	_lamp_bulb.emission_energy_multiplier = 3.5 if lamp_on else 0.0
	lamp_it.label = "Éteindre le lampadaire" if lamp_on else "Allumer le lampadaire"


# ------------------------------------------------------------------ le meuble télé et le vieux téléviseur

func _tv() -> void:
	var cab := prop("cabinetTelevision", TV_POS, 0.0, Vector3(1.0, 0.42, 0.32), true)
	var ctop := (cab.get_meta("size") as Vector3).y
	# (le meuble Kenney, gardé pour la hauteur de la télé : un bois sombre et ciré, des années 70)
	var teak := (mats.wood_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
	teak.albedo_color = Color(0.5, 0.38, 0.3)
	_retint(cab, {"wood": teak, "wooddark": teak})
	# napperon sous la télé, cassettes VHS à côté
	_box(Vector3(0.64, 0.003, 0.3), Vector3(TV_POS.x, ctop + 0.0015, TV_POS.z + 0.01), _m(Color(0.86, 0.82, 0.72), 0.95))
	var vhs := _m(Color(0.07, 0.07, 0.075), 0.5)
	var label_mat := _m(Color(0.86, 0.84, 0.76), 0.9)
	for k in 4:
		var t := Node3D.new()
		t.name = "VHS"
		add_child(t)
		t.position = Vector3(-0.8, ctop + 0.013 + k * 0.026, TV_POS.z + 0.02)
		t.rotation.y = rng.randf_range(-0.12, 0.12)
		_vhs.append(t)
		_box(Vector3(0.105, 0.025, 0.19), Vector3.ZERO, vhs, false, t)
		_box(Vector3(0.002, 0.016, 0.15), Vector3(0.0535, 0.0, 0.0), label_mat, false, t)
	# le téléviseur : une télé à tube de 1990, caisse façon bois, pas de prise réseau
	tv_holder = prop("televisionVintage", Vector3(TV_POS.x, ctop + 0.003, TV_POS.z + 0.02), 0.0, Vector3(0.41 * TV_SCALE, 0.0, 0.0), false)
	tv_holder.name = "Televiseur"
	Builder.tag(tv_holder, "analogique")
	var glass_dark := _plain(Color(0.03, 0.035, 0.035), 0.2)
	_retint(tv_holder, {"metal": glass_dark, "metalmedium": _m(Color(0.16, 0.12, 0.09), 0.5),
		"metaldark": _m(Color(0.07, 0.065, 0.06), 0.6), "wood": mats.wood_dark})
	var s := TV_SCALE
	var ts := tv_holder.get_meta("size") as Vector3
	_collider(ts, Vector3(0, ts.y / 2.0, 0), tv_holder)
	# la dalle : un Device à courbure (0,32 × 0,24), derrière le cadre ; une vitre bombée devant
	tv = Device.new()
	tv.name = "Ecran"
	tv.kind = "tv"
	tv.screen_size = Vector2(0.32, 0.24)
	tv.res = Vector2i(160, 120)
	tv.curvature = 0.16
	tv.glow_color = Color(0.72, 0.8, 1.0)
	tv.glow_energy = 0.8
	tv.glow_range = 3.8
	tv_holder.add_child(tv)
	tv.position = Vector3((0.156 - 0.205) * s, 0.136 * s, (0.135 - 0.004) * s)
	tv.build()
	for mi in tv.find_children("*", "MeshInstance3D", false, false):
		_no_gi(mi as MeshInstance3D)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.05, 0.06, 0.06, 0.25)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.07
	gm.metallic_specular = 1.0
	var dome := SphereMesh.new()
	dome.radius = 0.5
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 8
	var g := _no_gi(_mesh(dome, tv.position, gm, Vector3(PI / 2.0, 0, 0), tv_holder))
	g.name = "VitreBombee"
	g.scale = Vector3(0.335, 0.05, 0.255)
	# boutons du panneau de droite : deux molettes, le voyant de veille (éteint)
	var knob := _m(Color(0.1, 0.09, 0.08), 0.4)
	for k in 2:
		_tv_kenney.append(_mesh(_cyl(0.016, 0.018, 0.016, 14), Vector3((0.31 + k * 0.05 - 0.205) * s, 0.2 * s, 0.135 * s + 0.006), knob, Vector3(PI / 2.0, 0, 0), tv_holder))
	_tv_kenney.append(_mesh(_sphere(0.004, 6), Vector3((0.36 - 0.205) * s, 0.04 * s, 0.135 * s + 0.002), _plain(Color(0.25, 0.04, 0.03), 0.4), Vector3.ZERO, tv_holder))
	# son cordon d'alimentation, marron, derrière le meuble, jusqu'à la prise
	var back_z := TV_POS.z + 0.02 - ts.z / 2.0
	var wz := ZN + DADO + 0.004
	_cable([Vector3(TV_POS.x + 0.18, ctop + 0.06, back_z + 0.01), Vector3(TV_POS.x + 0.18, ctop + 0.03, wz),
		Vector3(TV_POS.x + 0.18, 0.13, wz), Vector3(-0.56, 0.13, wz), Vector3(-0.56, 0.235, wz)], Vector3.BACK, false, _old_cable, 0.0035)
	_socket(Vector3(-0.56, 0.25, ZN + DADO), Vector3.BACK, _m(Color(0.2, 0.18, 0.15), 0.5))
	tv_it = _interactable("Examiner la télé", ts + Vector3(0.03, 0.03, 0.05), tv_holder.position + Vector3(0, ts.y / 2.0 + 0.012, 0.022), self, LAYER_INTERACT, 2.2)
	tv_it.used.connect(func(_i: Interactable) -> void: examine_tv())


func examine_tv() -> void:
	var t := "Une télé à tube. Pas de Wi-Fi, pas de prise réseau. Elle ne peut pas la prendre."
	if _tv_has_snowed():
		t += " Tout à l'heure, elle a neigé toute seule. La déranger, ça, elle peut."
	_hint(t)
	_log("tele")


## La télé a-t-elle neigé toute seule (tv_snow) ? Seul le drapeau posé au moment où elle neige compte :
## le babyphone parle avant (B1, ou un indice), la phrase « Tout à l'heure, elle a neigé » serait fausse.
func _tv_has_snowed() -> bool:
	return bool(Game.flag("tele_a_neige", false))


## Le vieux téléviseur neige tout seul pendant « seconds » secondes (elle le dérange : elle ne peut
## pas le prendre). Le paramètre « noise » de son Device vaut 1 pendant ce temps.
func tv_snow(seconds := 3.0) -> void:
	_tv_id += 1
	var my := _tv_id
	Game.set_flag("tele_a_neige", true)
	tv.power_on("", 0.06)
	tv.set_static(1.0)
	await get_tree().create_timer(seconds, false).timeout
	if my != _tv_id or not is_inside_tree():
		return
	tv.set_static(0.0)
	tv.power_off(0.25)


## Un grésillement bref (le fil de l'antenne qu'on tire).
func tv_crackle(seconds := 0.45) -> void:
	_tv_id += 1
	var my := _tv_id
	tv.power_on("", 0.03)
	tv.set_static(0.6)
	await get_tree().create_timer(seconds, false).timeout
	if my != _tv_id or not is_inside_tree():
		return
	tv.set_static(0.0)
	tv.power_off(0.1)


# ------------------------------------------------------------------ l'antenne (pièce de l'arme)

func _antenna() -> void:
	var ts := tv_holder.get_meta("size") as Vector3
	antenna = Node3D.new()
	antenna.name = "Antenne"
	tv_holder.add_child(antenna)
	antenna.position = Vector3(0.02, ts.y, -0.04)
	antenna.rotation.y = 0.08
	var base := _m(Color(0.12, 0.1, 0.09), 0.4)
	_mesh(_cyl(0.042, 0.05, 0.026, 18), Vector3(0, 0.013, 0), base, Vector3.ZERO, antenna)
	var dome := _mesh(_sphere(0.032, 14), Vector3(0, 0.028, 0), base, Vector3.ZERO, antenna)
	dome.scale = Vector3(1, 0.55, 1)
	var rod := _plain(Color(0.76, 0.76, 0.78), 0.22, 0.65)
	for side in [-1.0, 1.0]:
		var dir := Vector3(side * sin(deg_to_rad(36.0)), cos(deg_to_rad(36.0)), -0.12).normalized()
		var p := Vector3(side * 0.012, 0.036, 0)
		_mesh(_sphere(0.008, 8), p, _chrome, Vector3.ZERO, antenna)
		for k in 3:
			var l: float = [0.19, 0.17, 0.15][k]
			var r: float = [0.0042, 0.0033, 0.0025][k]
			var q := p + dir * l
			_rod(p, q, r, rod, antenna, 8)
			if k < 2:
				_mesh(_cyl(r * 1.35, r * 1.35, 0.008, 8), q, rod, Vector3.ZERO, antenna)
			p = q
		_mesh(_sphere(0.0048, 8), p, rod, Vector3.ZERO, antenna)
	# le fil plat, marron, qui descend derrière la télé jusqu'aux deux vis, posées sur le dos de la
	# caisse (points donnés dans le repère du téléviseur, puis ramenés dans celui de l'antenne)
	var back := -ts.z / 2.0
	_antenna_wire([Vector3(0.02, ts.y + 0.012, -0.085), Vector3(0.05, ts.y + 0.002, back + 0.004),
		Vector3(0.08, ts.y - 0.08, back - 0.003)], [Vector3(0.07, ts.y - 0.08, back - 0.002),
		Vector3(0.095, ts.y - 0.08, back - 0.002)])
	var world := tv_holder.position + Vector3(0.02, ts.y + 0.2, -0.04)
	antenna_it = _interactable("Examiner l'antenne", Vector3(0.72, 0.4, 0.26), world, self, LAYER_INTERACT, 2.4)
	antenna_it.used.connect(func(_i: Interactable) -> void:
		if Game.has_item("tournevis"):
			unscrew_antenna()
		else:
			examine_antenna())


## Fil plat de l'antenne (ligne brisée « pts ») et ses vis (« screws ») : points dans le repère du
## téléviseur (tv_holder), ramenés dans celui de l'antenne ; nœud « Fil » (remplacé s'il existe).
func _antenna_wire(pts: Array, screws: Array) -> void:
	if _antenna_lead:
		_antenna_lead.free()
	_antenna_lead = Node3D.new()
	_antenna_lead.name = "Fil"
	antenna.add_child(_antenna_lead)
	var lead := _plain(Color(0.35, 0.25, 0.16), 0.6)
	var to_ant := antenna.transform.affine_inverse()
	for i in pts.size() - 1:
		var seg := _rod(to_ant * (pts[i] as Vector3), to_ant * (pts[i + 1] as Vector3), 0.003, lead, _antenna_lead, 6)
		seg.scale = Vector3(2.2, 1.0, 0.5)
	for p in screws:
		var screw := _mesh(_cyl(0.005, 0.005, 0.004, 8), to_ant * (p as Vector3), _chrome, Vector3(PI / 2.0, 0, 0), _antenna_lead)
		screw.rotation.y = -antenna.rotation.y


func _update_antenna_label() -> void:
	if antenna_it == null:
		return
	antenna_it.label = "Dévisser l'antenne" if Game.has_item("tournevis") else "Examiner l'antenne"


## Sans tournevis : la pensée du héros, et l'étape « antenne examinée » pour les indices.
func examine_antenna() -> void:
	_hint("Les oreilles de lapin. Sur le croquis de ta mère. Les fils sont vissés derrière la télé : il faut un tournevis.")
	if not Game.flag("antenne_examinee"):
		Game.set_flag("antenne_examinee", true)
		_story("antenne_examinee")
	else:
		_log("antenne")


## Avec le tournevis : 1,5 s de vis, la télé grésille, l'antenne rejoint l'inventaire (pièce de l'arme).
func unscrew_antenna() -> void:
	if _antenna_busy or Game.has_item("antenne"):
		return
	_antenna_busy = true
	_retire(antenna_it)
	var at := antenna.global_position + Vector3(0, -0.05, -0.15)
	for k in 4:
		Sfx.play_at("metalClick", at, -15.0, rng.randf_range(1.7, 2.2), 1.5)
		await get_tree().create_timer(0.28, false).timeout
		if not is_inside_tree():
			return
	_hint("Deux vis. La télé grésille quand tu tires le fil.")
	tv_crackle(0.45)
	await get_tree().create_timer(0.38, false).timeout
	if not is_inside_tree():
		return
	_hide_antenna()
	Sfx.play_at("cloth", at, -16.0, 1.2)
	Game.add_item("antenne", "Antenne télescopique", "Les oreilles de lapin de la vieille télé.", "arme")
	Game.set_flag("antenne_prise", true)
	_antenna_busy = false
	_story("antenne_prise")


func _hide_antenna() -> void:
	if antenna:
		antenna.visible = false
	_retire(antenna_it)


# ------------------------------------------------------------------ le coin couture

func _sewing() -> void:
	# la table de couture : une vieille table en bois (Poly Haven, wooden_table_02, la même que celle du
	# bureau : chargée une fois pour la maison), à la hauteur exacte du bureau Kenney qu'elle remplace
	# (« fit y » : la boîte à biscuits, la machine restent où elles étaient) ; plus profonde (0,67 m), elle
	# est poussée de 2,4 cm vers la pièce pour que son plateau ne rentre pas dans le lambris
	var desk := model("wooden_table_02", DESK_POS + Vector3(0.024, 0, 0), 90.0, Vector3(1.1, 0.76, 0.55), true, {"fit": "y", "name": "desk"})
	desk_top = (desk.get_meta("size") as Vector3).y
	var chair := prop("chair", Vector3(-2.3, 0, 3.45), -90.0 + 6.0, Vector3(0.42, 0.88, 0.42), true)
	chair.name = "ChaiseCouture"
	_sewing_machine(Vector3(-2.88, desk_top, 3.3))
	# pelote à épingles (une tomate), ciseaux, mètre ruban, coupons de tissu
	var pin := _mesh(_sphere(0.032, 12), Vector3(-2.72, desk_top + 0.025, 3.62), _m(Color(0.62, 0.12, 0.1), 0.8))
	pin.scale = Vector3(1, 0.75, 1)
	for k in 7:
		var a := k * 0.9
		var hp := Vector3(-2.72 + cos(a) * 0.022, desk_top + 0.05 + (k % 3) * 0.004, 3.62 + sin(a) * 0.022)
		_mesh(_sphere(0.0035, 6), hp, _plain([Color(0.9, 0.9, 0.85), Color(0.2, 0.4, 0.8), Color(0.9, 0.7, 0.2)][k % 3], 0.3))
	for k in 2:
		var bl := _box(Vector3(0.11, 0.003, 0.012), Vector3(-2.66, desk_top + 0.002 + k * 0.002, 3.12), _chrome)
		bl.rotation.y = 0.35 - k * 0.5
	# le mètre ruban enroulé, à côté de la machine (pas là où se posera le couvercle de la boîte)
	_mesh(_cyl(0.028, 0.028, 0.012, 16), Vector3(-2.66, desk_top + 0.006, 3.32), _m(Color(0.85, 0.72, 0.2), 0.6))
	var f1 := _box(Vector3(0.28, 0.006, 0.22), Vector3(-2.97, desk_top + 0.003, 3.02), _m(Color(0.35, 0.3, 0.55), 1.0))
	f1.rotation.y = 0.2
	var f2 := _box(Vector3(0.22, 0.004, 0.2), Vector3(-2.93, desk_top + 0.008, 3.06), _m(Color(0.7, 0.62, 0.45), 1.0))
	f2.rotation.y = -0.35
	# la pédale de la machine, par terre, et son cordon
	var ped := _box(Vector3(0.12, 0.05, 0.18), Vector3(-2.75, 0.025, 3.25), _m(Color(0.2, 0.18, 0.16), 0.5))
	ped.rotation.y = 0.4
	_cable([Vector3(-2.75, 0.03, 3.16), Vector3(-2.95, 0.006, 3.05), Vector3(-3.05, desk_top - 0.01, 3.2)], Vector3.UP, false, _old_cable, 0.003)
	_tin()
	_madeleine()


func _sewing_machine(at: Vector3) -> void:
	var sm := Node3D.new()
	sm.name = "MachineACoudre"
	add_child(sm)
	sm.position = at
	sm.rotation.y = PI / 2.0 + 0.05     # l'aiguille face à la chaise
	var cream := _m(Color(0.74, 0.7, 0.58), 0.35)
	var brown := _m(Color(0.32, 0.22, 0.15), 0.4)
	_box(Vector3(0.4, 0.045, 0.2), Vector3(0, 0.0225, 0), brown, false, sm)
	# le bâti en fonte émaillée, aux formes arrondies : plateau, colonne, bras, tête
	var arm := CapsuleMesh.new()
	arm.radius = 0.042
	arm.height = 0.37
	arm.radial_segments = 16
	arm.rings = 4
	var col := CapsuleMesh.new()
	col.radius = 0.052
	col.height = 0.25
	col.radial_segments = 16
	col.rings = 4
	var head := CapsuleMesh.new()
	head.radius = 0.048
	head.height = 0.17
	head.radial_segments = 16
	head.rings = 4
	var slab := BoxMesh.new()
	slab.size = Vector3(0.38, 0.03, 0.18)
	_merged([[slab, _at(Vector3(0, 0.06, 0))],
		[col, _at(Vector3(0.13, 0.17, -0.01), Vector3.ZERO, Vector3(0.95, 1.0, 1.25))],
		[arm, _at(Vector3(0.0, 0.272, -0.01), Vector3(0, 0, PI / 2.0), Vector3(1.0, 1.0, 1.25))],
		[head, _at(Vector3(-0.15, 0.225, -0.01), Vector3.ZERO, Vector3(0.95, 1.0, 1.2))]], cream, sm)
	_rod(Vector3(-0.16, 0.17, 0.035), Vector3(-0.16, 0.085, 0.035), 0.004, _chrome, sm, 6)
	_box(Vector3(0.03, 0.006, 0.03), Vector3(-0.16, 0.079, 0.035), _chrome, false, sm)
	_mesh(_cyl(0.05, 0.05, 0.022, 20), Vector3(0.19, 0.22, -0.01), _chrome, Vector3(0, 0, PI / 2.0), sm)
	_mesh(_cyl(0.004, 0.004, 0.05, 6), Vector3(0.05, 0.33, -0.03), _chrome, Vector3.ZERO, sm)
	_mesh(_cyl(0.013, 0.013, 0.03, 12), Vector3(0.05, 0.33, -0.03), _plain(Color(0.6, 0.1, 0.12), 0.8), Vector3.ZERO, sm)
	# le fil descend jusqu'à l'aiguille ; un coupon rouge sous le pied-de-biche
	_rod(Vector3(0.05, 0.33, -0.017), Vector3(-0.16, 0.18, 0.04), 0.0008, _plain(Color(0.6, 0.1, 0.12), 0.8), sm, 4)
	var fab := _box(Vector3(0.22, 0.004, 0.2), Vector3(-0.1, 0.077, 0.03), _m(Color(0.45, 0.1, 0.12), 1.0), false, sm)
	fab.rotation.y = 0.25
	_collider(Vector3(0.42, 0.33, 0.22), Vector3(0, 0.165, 0), sm)


## La boîte à biscuits bleue (couvercle tin_lid.png) : boutons, bobines, la madeleine et la clé du bureau.
func _tin() -> void:
	tin = Node3D.new()
	tin.name = "BoiteBiscuits"
	add_child(tin)
	tin.position = Vector3(TIN_POS.x, desk_top, TIN_POS.z)
	var blue := _plain(Color(0.08, 0.13, 0.38), 0.3, 0.45)
	var gold := _plain(Color(0.6, 0.48, 0.2), 0.3, 0.6)
	var hh := 0.075
	_mesh(_open_cyl(0.1, 0.1, hh, 0.003, 32, 0.004), Vector3.ZERO, blue, Vector3.ZERO, tin)
	for y in [0.012, hh - 0.012]:
		_mesh(_cyl(0.1012, 0.1012, 0.004, 32), Vector3(0, y, 0), gold, Vector3.ZERO, tin)
	# l'intérieur : un lit de boutons, des bobines, la clé à étiquette (caché tant que c'est fermé)
	tin_inside = Node3D.new()
	tin_inside.name = "Contenu"
	tin.add_child(tin_inside)
	tin_inside.visible = false
	var bt := StandardMaterial3D.new()
	bt.albedo_texture = _buttons_texture()
	bt.roughness = 0.6
	_mesh(_disc(0.096, 28), Vector3(0, 0.05, 0), bt, Vector3.ZERO, tin_inside)
	var thread := [Color(0.7, 0.12, 0.15), Color(0.15, 0.25, 0.6), Color(0.85, 0.82, 0.7)]
	for k in 3:
		var bob := Node3D.new()
		tin_inside.add_child(bob)
		bob.position = Vector3(-0.05 + k * 0.035, 0.062, 0.035 - k * 0.02)
		bob.rotation = Vector3(PI / 2.0, k * 0.8, 0)
		_mesh(_cyl(0.012, 0.012, 0.026, 12), Vector3.ZERO, _plain(thread[k], 0.9), Vector3.ZERO, bob)
		for s in [-1.0, 1.0]:
			_mesh(_cyl(0.015, 0.015, 0.003, 12), Vector3(0, s * 0.014, 0), _m(Color(0.6, 0.45, 0.28), 0.6), Vector3.ZERO, bob)
	tin_key = Node3D.new()
	tin_key.name = "CleBureau"
	tin_inside.add_child(tin_key)
	tin_key.position = Vector3(0.03, 0.056, -0.03)
	tin_key.rotation.y = 0.6
	var brass := _plain(Color(0.66, 0.52, 0.25), 0.3, 0.7)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.008
	ring.outer_radius = 0.013
	ring.rings = 12
	ring.ring_segments = 6
	_mesh(ring, Vector3(-0.025, 0, 0), brass, Vector3.ZERO, tin_key)
	_box(Vector3(0.04, 0.003, 0.007), Vector3(0.008, 0, 0), brass, false, tin_key)
	_box(Vector3(0.008, 0.003, 0.012), Vector3(0.022, 0, 0.007), brass, false, tin_key)
	_box(Vector3(0.03, 0.001, 0.018), Vector3(-0.05, 0.002, 0.012), _plain(Color(0.88, 0.85, 0.75), 0.9), false, tin_key)
	# le couvercle
	tin_lid = Node3D.new()
	tin_lid.name = "Couvercle"
	tin.add_child(tin_lid)
	tin_lid.position = Vector3(0, hh, 0)
	tin_lid.rotation.y = -PI / 2.0      # le dessin lisible depuis la chaise
	_mesh(_cyl(0.1035, 0.1035, 0.016, 32), Vector3(0, 0.006, 0), blue, Vector3.ZERO, tin_lid)
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = load("res://assets/images/tin_lid.png")
	lm.roughness = 0.35
	lm.metallic = 0.3
	lm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mesh(_disc(0.1035, 40), Vector3(0, 0.0142, 0), lm, Vector3.ZERO, tin_lid)
	tin_it = _interactable("Ouvrir la boîte à biscuits", Vector3(0.24, 0.12, 0.24), tin.position + Vector3(0, 0.05, 0), self, LAYER_INTERACT, 2.2)
	tin_it.used.connect(func(_i: Interactable) -> void: open_tin())


## La boîte s'ouvre : la clé du bureau rejoint l'inventaire ; la madeleine reste sur le bureau.
func open_tin() -> void:
	if Game.flag("boite_ouverte") and Game.has_item("cle_bureau"):
		return
	_set_tin_open(false)
	Sfx.play_at("metalClick", tin.global_position, -12.0, 1.35, 1.5)
	Sfx.play_at("cloth", tin.global_position, -18.0, 1.3, 1.5)
	_hint("Des boutons, des bobines de fil, une madeleine sous plastique. Et une clé, avec une étiquette de l'écriture de Mamie : BUREAU.")
	Game.add_item("cle_bureau", "Clé du bureau", "Un double. Étiquette de Mamie : BUREAU. Il était dans la boîte à biscuits.", "cle")
	Game.set_flag("boite_ouverte", true)
	_story("cle_bureau_prise")


## Boîte ouverte : couvercle posé à côté, contenu visible, clé retirée, madeleine sortie sur le plateau.
func _set_tin_open(instant: bool) -> void:
	_retire(tin_it)
	tin_inside.visible = true
	if tin_key:
		tin_key.visible = false
	var lid_to := Vector3(-0.06, 0.001, -0.245)
	if instant or not is_inside_tree():
		tin_lid.position = lid_to
		tin_lid.rotation = Vector3(0, 0.4, 0)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(tin_lid, "position", lid_to, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(tin_lid, "rotation", Vector3(0, 0.4, 0), 0.35)
	if not Game.flag("madeleine_mangee"):
		madeleine.visible = true
		madeleine_it.enabled = true
		madeleine_it.collision_layer = LAYER_INTERACT


func _madeleine() -> void:
	madeleine = Node3D.new()
	madeleine.name = "Madeleine"
	add_child(madeleine)
	madeleine.position = Vector3(-2.74, desk_top, 3.78)
	madeleine.rotation.y = 0.5
	var cake := _m(Color(0.72, 0.48, 0.2), 0.75)
	var shell := SphereMesh.new()
	shell.radius = 0.5
	shell.height = 1.0
	shell.is_hemisphere = true
	shell.radial_segments = 16
	shell.rings = 6
	var body := _mesh(shell, Vector3(0, 0.001, 0), cake, Vector3.ZERO, madeleine)
	body.scale = Vector3(0.075, 0.045, 0.05)
	var bump := _mesh(_sphere(0.5, 10), Vector3(0.008, 0.02, 0), _m(Color(0.62, 0.38, 0.14), 0.75), Vector3.ZERO, madeleine)
	bump.scale = Vector3(0.03, 0.016, 0.022)
	for k in 5:
		var groove := _box(Vector3(0.065, 0.002, 0.002), Vector3(0, 0.019, -0.016 + k * 0.008), _plain(Color(0.5, 0.3, 0.12), 0.8), false, madeleine)
		groove.rotation.y = (k - 2) * 0.12
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = Color(0.9, 0.92, 0.95, 0.22)
	wrap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wrap.roughness = 0.15
	wrap.metallic_specular = 0.9
	_no_gi(_box(Vector3(0.095, 0.034, 0.07), Vector3(0, 0.017, 0), wrap, false, madeleine))
	_no_gi(_box(Vector3(0.012, 0.004, 0.072), Vector3(0.05, 0.003, 0), wrap, false, madeleine))
	madeleine.visible = false
	madeleine_it = _interactable("Manger la madeleine", Vector3(0.14, 0.09, 0.12), madeleine.position + Vector3(0, 0.03, 0), self, LAYER_INTERACT, 2.2)
	madeleine_it.used.connect(func(_i: Interactable) -> void: eat_madeleine())
	_retire(madeleine_it)


## Jauge −5, une seule fois ; l'interaction disparaît ensuite.
func eat_madeleine() -> void:
	if Game.flag("madeleine_mangee"):
		return
	Game.set_flag("madeleine_mangee", true)
	_hide_madeleine()
	Sfx.play_at("cloth", madeleine.global_position, -16.0, 1.5, 1.5)
	var hn := _haunt()
	if hn:
		hn.peur(-5.0, "madeleine")
	else:
		Game.add_peur(-5.0, "madeleine")
	_hint("Molle. Trop sucrée. Mamie en cache partout. Ça va un peu mieux.")
	_story("madeleine_mangee")


func _hide_madeleine() -> void:
	if madeleine:
		madeleine.visible = false
	_retire(madeleine_it)


# ------------------------------------------------------------------ le mannequin de couture (immobile)

## Buste de couture, taille 40 (repère du mannequin, avant vers +z) : [hauteur, largeur, profondeur,
## exposant de superellipse devant, derrière (dos aplati), bosses de poitrine (m)], interpolé entre deux
## lignes. Mesures de l'étude « assets » : hanches 0,36 × 0,27 à 0,80 m, taille 0,27 × 0,20 à 1,06,
## poitrine 0,34 × 0,25 à 1,25, carrure 0,40 × 0,15 à 1,42 (emmanchures aplaties), cou de 10 cm.
const BUST := [
	[0.735, 0.33, 0.245, 2.2, 3.2, 0.0],
	[0.80, 0.36, 0.27, 2.2, 3.4, 0.0],
	[0.88, 0.345, 0.255, 2.2, 3.4, 0.0],
	[0.97, 0.305, 0.222, 2.1, 3.4, 0.0],
	[1.06, 0.27, 0.20, 2.0, 3.4, 0.0],
	[1.12, 0.278, 0.205, 2.0, 3.4, 0.0],
	[1.17, 0.30, 0.22, 2.0, 3.5, 0.004],
	[1.215, 0.325, 0.24, 2.0, 3.5, 0.012],
	[1.25, 0.34, 0.25, 2.0, 3.5, 0.015],
	[1.29, 0.35, 0.235, 2.1, 3.5, 0.01],
	[1.34, 0.368, 0.205, 2.4, 3.5, 0.002],
	[1.385, 0.39, 0.172, 2.8, 3.5, 0.0],
	[1.42, 0.40, 0.152, 3.3, 3.5, 0.0],
	[1.45, 0.34, 0.138, 3.0, 3.2, 0.0],
	[1.468, 0.22, 0.118, 2.4, 2.6, 0.0],
	[1.478, 0.106, 0.10, 2.0, 2.0, 0.0],
]
const BUST_SEG := 96
## Passepoils du buste (degrés, multiples de 360 / BUST_SEG ; 90 = milieu devant, 0 = côté +x) : milieux,
## côtés, coutures princesse (par la pointe des seins).
const BUST_SEAMS := [90.0, 270.0, 0.0, 180.0, 52.5, 127.5, 232.5, 307.5]
const BUST_PIPING := 0.0016
const DRESS_OFF := 0.006           # la robe, décollée du buste
const SKIRT_HEM := 0.44            # ourlet de la jupe (au sol : le trépied dessous)
const SKIRT_FLARE := 1.45          # évasement sous les hanches (par m)
const SKIRT_FOLD := 0.07           # amplitude des seize plis à l'ourlet


## Une ligne de BUST à la hauteur y (interpolée ; bornée aux deux bouts).
static func _bust_row(y: float) -> Array:
	var rows: Array = BUST
	if y <= float(rows[0][0]):
		return rows[0]
	for i in range(1, rows.size()):
		var b: Array = rows[i]
		if y <= float(b[0]):
			var a: Array = rows[i - 1]
			var t := (y - float(a[0])) / (float(b[0]) - float(a[0]))
			var out := [y]
			for k in range(1, 6):
				out.append(lerpf(float(a[k]), float(b[k]), t))
			return out
	return rows[rows.size() - 1]


## Point (x, z) du contour du buste à l'angle th (radians ; 0 = côté +x, PI / 2 = milieu devant), poussé
## de « off » m vers l'extérieur.
static func _bust_xz(row: Array, th: float, off := 0.0) -> Vector2:
	var a: float = float(row[1]) / 2.0
	var b: float = float(row[2]) / 2.0
	var c := cos(th)
	var s := sin(th)
	var e := 2.0 / float(row[3] if s >= 0.0 else row[4])
	var p := Vector2(a * signf(c) * pow(absf(c), e), b * signf(s) * pow(absf(s), e))
	var bump: float = row[5]
	if bump > 0.0 and p.y > 0.0:
		p.y += bump * exp(-pow((absf(p.x) - 0.088) / 0.05, 2.0)) * clampf(p.y / b * 1.6, 0.0, 1.0)
	if off != 0.0:
		var l := p.length()
		if l > 1e-5:
			p *= (l + off) / l
	return p


## Surface en grille : « rows » (PackedVector3Array de même taille, du haut vers le bas), refermées sur
## elles-mêmes si « closed ». Normales et tangentes calculées sur la grille (sans couture à la fermeture),
## orientées à l'opposé de l'axe vertical du nœud ; UV en mètres (u le long des lignes, v = hauteur).
## both : une face intérieure en plus (1,5 mm en dedans, normales inversées), pour un tissu vu des deux côtés.
static func _grid_mesh(rows: Array, closed: bool, both := false) -> ArrayMesh:
	var nr := rows.size()
	var nc: int = (rows[0] as PackedVector3Array).size()
	var cols := nc + 1 if closed else nc
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	for i in nr:
		var r: PackedVector3Array = rows[i]
		var up: PackedVector3Array = rows[maxi(i - 1, 0)]
		var dn: PackedVector3Array = rows[mini(i + 1, nr - 1)]
		var u := 0.0
		for j in cols:
			var jj := j % nc
			if j > 0:
				u += r[jj].distance_to(r[(j - 1) % nc])
			var jn := (jj + 1) % nc if closed else mini(jj + 1, nc - 1)
			var jp := (jj - 1 + nc) % nc if closed else maxi(jj - 1, 0)
			var du := r[jn] - r[jp]
			var dv := up[jj] - dn[jj]
			var n := du.cross(dv)
			var radial := Vector3(r[jj].x, 0.0, r[jj].z)
			if n.dot(radial) < 0.0:
				n = -n
			n = n.normalized() if n.length() > 1e-9 else radial.normalized()
			var t := (du - n * n.dot(du)).normalized()
			var w := 1.0 if n.cross(t).dot(dv) >= 0.0 else -1.0
			verts.append(r[jj])
			norms.append(n)
			tans.append_array([t.x, t.y, t.z, w])
			uvs.append(Vector2(u, -r[jj].y))
	var idx := PackedInt32Array()
	# sens des triangles : face avant dans le sens des normales (vérifié sur le premier quadrilatère)
	var a0 := verts[0]
	var flip := (verts[1] - a0).cross(verts[cols] - a0).dot(norms[0]) > 0.0
	for i in nr - 1:
		for j in cols - 1:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if flip:
				idx.append_array([a, c, b, b, c, d])
			else:
				idx.append_array([a, b, c, b, d, c])
	if both:
		var n0 := verts.size()
		for k in n0:
			verts.append(verts[k] - norms[k] * 0.0015)
			norms.append(-norms[k])
			tans.append_array([tans[k * 4], tans[k * 4 + 1], tans[k * 4 + 2], -tans[k * 4 + 3]])
			uvs.append(uvs[k])
		var m := idx.size()
		for k in range(0, m, 3):
			idx.append_array([idx[k] + n0, idx[k + 2] + n0, idx[k + 1] + n0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Le mannequin de couture de Mamie (lot V2-AMIS) : un vrai buste de couture en loft de superellipses
## (poitrine, taille, hanches, dos aplati, emmanchures nettes, passepoils des coutures princesse), en lin
## écru ; bouchons en bois ; pied chromé à molette sur un trépied en fonte. La robe en cours : jupe
## marine à pois de 1 cm, à seize plis qui s'évasent vers un ourlet irrégulier, et corsage épinglé sur
## la moitié gauche. Nœud « Mannequin », position, rotation, collision et regard inchangés.
func _mannequin() -> void:
	var mq := Node3D.new()
	mq.name = "Mannequin"
	add_child(mq)
	mq.position = Vector3(-2.6, 0, 5.9)
	mq.rotation.y = 1.95      # il « regarde » la porte
	# (l'ancienne robe à pois : ses 4 096 tirages restent ici, dans l'ordre du hasard de la pièce, R4)
	var old_dots := _dots_texture()
	var soft := Builder.soft_render()
	var linen: StandardMaterial3D
	var wood: StandardMaterial3D
	var chrome: StandardMaterial3D
	var iron: StandardMaterial3D
	var dress := StandardMaterial3D.new()
	dress.roughness = 0.88
	if soft:
		linen = _linen(Color(0.86, 0.9, 0.82))
		wood = _m(Color(0.25, 0.17, 0.11), 0.5)
		chrome = _plain(Color(0.4, 0.38, 0.35), 0.35, 0.6)
		iron = _plain(Color(0.07, 0.068, 0.065), 0.5, 0.3)
		dress.albedo_texture = old_dots
		dress.uv1_scale = Vector3(1.0 / DRESS_TILE_OLD, 1.0 / DRESS_TILE_OLD, 1.0)
	else:
		# lin écru (Fabric045, neutre, teinté), posé sur les UV du loft (mètres) ; bois sombre ciré ;
		# chrome terni ; fonte noire
		linen = Surfaces.pbr_acg("Fabric045/Fabric045", 0.3, Color(0.8, 0.73, 0.6), 0.8)
		linen.uv1_triplanar = false
		linen.uv1_world_triplanar = false
		linen.uv1_scale = Vector3(1.0 / 0.3, 1.0 / 0.3, 1.0)
		linen = _grimy(linen, 1.2)
		wood = _grimy(Surfaces.pbr("Wood008/Wood008", 0.35, Color(0.62, 0.5, 0.42)), 1.5)
		chrome = Surfaces.pbr("Metal049B/Metal049B", 0.25, Color(0.86, 0.85, 0.83), 1.0, true, false, -1.0, true)
		iron = Surfaces.pbr("Metal046B/Metal046B", 0.3, Color(0.42, 0.41, 0.4), 1.0, true, false, -1.0, true)
		dress.albedo_texture = load(DRESS_DOTS)
		dress.uv1_scale = Vector3(1.0 / DRESS_TILE, 1.0 / DRESS_TILE, 1.0)
		dress.normal_enabled = true
		dress.normal_texture = load("res://assets/textures/Fabric045/Fabric045_NormalGL.jpg")
		dress.normal_scale = 0.5
		dress.rim_enabled = true
		dress.rim = 0.25
		dress.rim_tint = 0.5
		dress.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	dress = _grimy(dress, 0.8)
	# --- le buste
	var seams := {}
	for d in BUST_SEAMS:
		seams[int(round(float(d) / 360.0 * BUST_SEG)) % BUST_SEG] = true
	var secs := []
	var ys := PackedFloat32Array()
	for row in BUST:
		var ring := PackedVector2Array()
		ring.resize(BUST_SEG)
		var piping := BUST_PIPING if float(row[0]) < 1.462 else 0.0
		for k in BUST_SEG:
			ring[k] = _bust_xz(row, TAU * k / BUST_SEG, piping if seams.has(k) else 0.0)
		secs.append(ring)
		ys.append(float(row[0]))
	var torso := _mesh(Builder.loft_mesh(secs, ys, true), Vector3.ZERO, linen, Vector3.ZERO, mq)
	torso.name = "Buste"
	# cou, bouchon du haut (bois, bouton), plaque du bas
	_mesh(Builder.cylinder_mesh(0.046, 0.052, 0.09, 28), Vector3(0, 1.476 + 0.045, 0), linen, Vector3.ZERO, mq)
	_mesh(Builder.cylinder_mesh(0.049, 0.049, 0.012, 28), Vector3(0, 1.572, 0), wood, Vector3.ZERO, mq)
	_mesh(Builder.cylinder_mesh(0.007, 0.009, 0.02, 10), Vector3(0, 1.588, 0), wood, Vector3.ZERO, mq)
	_ellipsoid(Vector3(0.026, 0.02, 0.026), Vector3(0, 1.602, 0), wood, mq, 12)
	_mesh(Builder.cylinder_mesh(0.072, 0.075, 0.014, 32), Vector3(0, 0.729, 0), wood, Vector3.ZERO, mq)
	# --- le pied : colonne chromée télescopique, molette crantée, trépied en fonte à patins
	_mesh(Builder.cylinder_mesh(0.0145, 0.0145, 0.27, 16), Vector3(0, 0.45, 0), chrome, Vector3.ZERO, mq)
	_mesh(Builder.cylinder_mesh(0.011, 0.011, 0.16, 14), Vector3(0, 0.645, 0), chrome, Vector3.ZERO, mq)
	_mesh(Builder.cylinder_mesh(0.023, 0.023, 0.03, 20), Vector3(0, 0.585, 0), chrome, Vector3.ZERO, mq)
	for k in 12:
		var a := TAU * k / 12.0
		_mesh(Builder.cylinder_mesh(0.0035, 0.0035, 0.028, 6), Vector3(cos(a) * 0.0235, 0.585, sin(a) * 0.0235), chrome, Vector3.ZERO, mq)
	_mesh(Builder.cylinder_mesh(0.006, 0.006, 0.05, 10), Vector3(0.045, 0.585, 0), chrome, Vector3(0, 0, PI / 2.0), mq)
	_ellipsoid(Vector3(0.024, 0.024, 0.024), Vector3(0.072, 0.585, 0), iron, mq, 10)
	_mesh(Builder.cylinder_mesh(0.03, 0.04, 0.08, 20), Vector3(0, 0.29, 0), iron, Vector3.ZERO, mq)
	var leg_r := 0.0105
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		var dir := Vector3(cos(a), 0.0, sin(a))
		var pts := PackedVector3Array()
		for i in 9:
			var t := i / 8.0
			pts.append(dir * (0.028 + 0.25 * t) + Vector3.UP * (0.012 + 0.262 * pow(1.0 - t, 1.6)))
		var leg := MeshInstance3D.new()
		leg.mesh = COULOIR._tube_mesh(pts, leg_r, 6 if soft else 10)
		leg.material_override = iron
		mq.add_child(leg)
		_mesh(Builder.cylinder_mesh(0.019, 0.021, 0.012, 16), dir * 0.278 + Vector3.UP * 0.006, _plain(Color(0.05, 0.05, 0.05), 0.7), Vector3.ZERO, mq)
	# --- la robe : jupe (cercle complet, plis et ourlet), corsage épinglé sur la moitié gauche
	var sk_y := [1.082, 1.072, 1.052, 1.04, 1.0, 0.95, 0.9, 0.85, 0.8, 0.76, 0.71, 0.66, 0.61, 0.56, 0.51, 0.47, SKIRT_HEM]
	var rows := []
	for y in sk_y:
		var yy: float = y
		var row := PackedVector3Array()
		row.resize(BUST_SEG)
		var t := clampf((0.83 - yy) / 0.39, 0.0, 1.0)
		# ceinture : un bourrelet de 1,2 cm entre 1,04 et 1,072
		var off := DRESS_OFF + (0.005 if yy > 1.045 and yy < 1.075 else 0.0) + 0.008 * clampf((1.04 - yy) / 0.24, 0.0, 1.0)
		var brow := _bust_row(maxf(yy, 0.8))
		var flare := 1.0 + maxf(0.8 - yy, 0.0) * SKIRT_FLARE
		for k in BUST_SEG:
			var th := TAU * k / BUST_SEG
			var p := _bust_xz(brow, th, off) * flare
			var fold := 1.0 + SKIRT_FOLD * pow(t, 1.3) * sin(16.0 * th + 0.35 * sin(3.0 * th) + 0.6) + 0.015 * t * sin(5.0 * th + 1.3)
			p *= fold
			var py := yy
			if yy <= SKIRT_HEM + 0.001:
				# ourlet irrégulier : la jupe pend plus bas d'un côté, les creux des plis un peu plus bas
				py += 0.01 * sin(th + 0.9) - 0.004 * sin(16.0 * th + 0.35 * sin(3.0 * th) + 0.6)
			row[k] = Vector3(p.x, py, p.y)
		rows.append(row)
	var skirt := _mesh(_grid_mesh(rows, true, true), Vector3.ZERO, dress, Vector3.ZERO, mq)
	skirt.name = "Jupe"
	# corsage : du milieu du dos (−90°) au milieu devant (+90°) par le côté +x ; encolure creusée devant,
	# emmanchure sur le côté
	var cols := 49
	var nrow := 14
	var brows := []
	for i in nrow:
		var row := PackedVector3Array()
		row.resize(cols)
		for j in cols:
			var deg := -90.0 + 180.0 * j / (cols - 1)
			var y_top := 1.44 - 0.11 * exp(-pow(deg / 26.0, 2.0)) - 0.12 * exp(-pow((deg - 90.0) / 32.0, 2.0)) \
				- 0.03 * exp(-pow((deg + 90.0) / 30.0, 2.0))
			var yy := lerpf(y_top, 1.05, float(i) / (nrow - 1))
			var p := _bust_xz(_bust_row(yy), deg_to_rad(deg), DRESS_OFF + 0.002)
			row[j] = Vector3(p.x, yy, p.y)
		brows.append(row)
	var bodice := _mesh(_grid_mesh(brows, false, true), Vector3.ZERO, dress, Vector3.ZERO, mq)
	bodice.name = "Corsage"
	# épingles : le long du bord du corsage (milieu devant), à la couture de côté, à l'ourlet
	var pin_heads := [Color(0.9, 0.9, 0.85), Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.95, 0.75, 0.2)]
	for k in 9:
		var yy := 1.07 + k * 0.028
		var p := _bust_xz(_bust_row(yy), PI / 2.0 - 0.05, DRESS_OFF + 0.006)
		_mesh(_sphere(0.0038, 6), Vector3(p.x, yy, p.y), _plain(pin_heads[k % 4], 0.3), Vector3.ZERO, mq)
	for k in 4:
		var yy := 1.1 + k * 0.05
		var p := _bust_xz(_bust_row(yy), 0.04, DRESS_OFF + 0.006)
		_mesh(_sphere(0.0038, 6), Vector3(p.x, yy, p.y), _plain(pin_heads[(k + 2) % 4], 0.3), Vector3.ZERO, mq)
	for k in 6:
		var th := 0.75 + k * 0.33
		var yy := SKIRT_HEM + 0.035
		var p := _bust_xz(_bust_row(0.8), th, DRESS_OFF + 0.008) * (1.0 + (0.8 - yy) * SKIRT_FLARE)
		p *= 1.0 + SKIRT_FOLD * 0.92 * sin(16.0 * th + 0.35 * sin(3.0 * th) + 0.6) + 0.015 * sin(5.0 * th + 1.3) + 0.012
		_mesh(_sphere(0.0038, 6), Vector3(p.x, yy, p.y), _plain(pin_heads[(k + 1) % 4], 0.3), Vector3.ZERO, mq)
	# le mètre ruban : un tour du cou, les deux bouts sur la poitrine
	var tape := _plain(Color(0.85, 0.7, 0.2), 0.6)
	var neck := TorusMesh.new()
	neck.inner_radius = 0.052
	neck.outer_radius = 0.058
	neck.rings = 24
	neck.ring_segments = 4
	var collar := _mesh(neck, Vector3(0, 1.49, 0.006), tape, Vector3(0.22, 0, 0), mq)
	collar.scale = Vector3(1.0, 0.35, 1.0)
	for sgn in [-1.0, 1.0]:
		# une ligne brisée posée sur la surface : du cou, par-dessus la carrure, jusque sur la poitrine
		# (côté du corsage, +x : par-dessus le tissu)
		var pts: Array[Vector3] = []
		var hs := [1.49, 1.476, 1.462, 1.44, 1.4, 1.35, 1.3, 1.25, 1.21 + (0.03 if sgn > 0.0 else 0.0)]
		for k in hs.size():
			var yy: float = hs[k]
			var ang := lerpf(1.05, 0.42, clampf((1.476 - yy) / 0.12, 0.0, 1.0))
			var th: float = PI / 2.0 - sgn * ang
			var off := 0.0035 + (DRESS_OFF + 0.006 if sgn > 0.0 and yy < 1.4 else 0.0)
			if yy >= 1.476:
				pts.append(Vector3(cos(th), 0.0, sin(th)) * (0.05 + off) + Vector3.UP * yy)
			else:
				var p := _bust_xz(_bust_row(yy), th, off)
				pts.append(Vector3(p.x, yy, p.y))
		for k in pts.size() - 1:
			var a0: Vector3 = pts[k]
			var a1: Vector3 = pts[k + 1]
			var yv := (a0 - a1).normalized()
			var zv := Vector3((a0.x + a1.x) / 2.0, 0.0, (a0.z + a1.z) / 2.0).normalized()
			zv = (zv - yv * zv.dot(yv)).normalized()
			var strip := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.016, a0.distance_to(a1) + 0.002, 0.0012)
			strip.mesh = sb
			strip.material_override = tape
			strip.transform = Transform3D(Basis(yv.cross(zv), yv, zv), (a0 + a1) / 2.0)
			mq.add_child(strip)
	# (hors de la cuisson VoxelGI, comme les modèles Poly Haven : 15 000 triangles pour un rebond invisible)
	for g in mq.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_collider(Vector3(0.42, 1.65, 0.42), Vector3(0, 0.825, 0), mq)
	_look("Regarder le mannequin", Vector3(0.5, 1.2, 0.45), mq.position + Vector3(0, 1.0, 0),
		"Le mannequin de couture de Mamie. Une robe à moitié épinglée.", "mannequin")


# ------------------------------------------------------------------ les cartons du vide-grenier

func _boxes() -> void:
	var tint := {"wood": Color(0.52, 0.38, 0.23), "wooddark": Color(0.62, 0.55, 0.42)}
	var open := prop("cardboardBoxOpen", Vector3(2.75, 0, 4.6), -90.0, Vector3(0.0, 0.42, 0.42), true, tint)
	var osz := open.get_meta("size") as Vector3
	# le panneau « TOUT À 2 € », sur le flanc tourné vers la pièce
	_quad(Vector2(0.33, 0.206), Vector3(2.75 - osz.z / 2.0 - 0.006, osz.y * 0.5, 4.6), _image_mat("carton_2euros.png", 0.95), -PI / 2.0)
	# dedans : des VHS debout, un walkman, une boîte à disquettes vide
	var vhs := _m(Color(0.07, 0.07, 0.075), 0.5)
	for k in 4:
		var t := _box(Vector3(0.026, 0.19, 0.105), Vector3(2.66 + k * 0.03, 0.31, 4.55 + (k % 2) * 0.02), vhs)
		t.rotation = Vector3(0, rng.randf_range(-0.1, 0.1), rng.randf_range(-0.15, 0.15))
	var wk := Node3D.new()
	wk.name = "Walkman"
	add_child(wk)
	wk.position = Vector3(2.82, 0.4, 4.72)
	wk.rotation = Vector3(0.5, 0.3, 0.2)
	_box(Vector3(0.115, 0.03, 0.082), Vector3.ZERO, _m(Color(0.75, 0.6, 0.15), 0.4), false, wk)
	_box(Vector3(0.07, 0.002, 0.045), Vector3(0.01, 0.016, 0), _plain(Color(0.05, 0.05, 0.06), 0.1), false, wk)
	var fb := Node3D.new()
	fb.name = "BoiteDisquettes"
	add_child(fb)
	fb.position = Vector3(2.84, 0.33, 4.45)
	fb.rotation = Vector3(0, 0.2, -0.12)
	_box(Vector3(0.1, 0.07, 0.11), Vector3(0, 0, 0), _m(Color(0.32, 0.33, 0.34), 0.4), false, fb)
	var flap := _box(Vector3(0.1, 0.004, 0.11), Vector3(0, 0.06, -0.06), _plain(Color(0.25, 0.28, 0.3), 0.15), false, fb)
	flap.rotation.x = -1.1
	_box(Vector3(0.094, 0.004, 0.104), Vector3(0, -0.02, 0), _plain(Color(0.06, 0.06, 0.06), 0.5), false, fb)
	_look("Regarder le carton", Vector3(osz.z + 0.04, osz.y + 0.12, osz.x), Vector3(2.75, osz.y / 2.0 + 0.04, 4.6),
		"« TOUT À 2 € ». Le vide-grenier de Mamie, dimanche. Des VHS, un walkman, une boîte à disquettes. Vide.", "carton")
	prop("cardboardBoxClosed", Vector3(2.75, 0, 5.4), -84.0, Vector3(0.44, 0.42, 0.44), true, tint)
	prop("cardboardBoxClosed", Vector3(2.75, 0, 6.0), -97.0, Vector3(0.4, 0.38, 0.4), true, tint)


# ------------------------------------------------------------------ le fauteuil sous sa housse

const ARMCHAIR_POS := Vector3(1.95, 0, 5.74)

## Entre le chevet et les cartons, une bergère sous un drap de coton. Opaque : rien n'est modelé dessous.
## Le drap est une toile simulée hors jeu (HOUSSE_MESH) ; sans elle, un champ de hauteurs posé sur
## l'assise, le dossier et les accoudoirs, qui tombe droit jusqu'au sol (l'ancienne housse).
func _covered_armchair() -> void:
	var holder := Node3D.new()
	holder.name = "FauteuilHousse"
	add_child(holder)
	holder.position = ARMCHAIR_POS
	holder.rotation.y = PI + 0.12      # dos au pignon, tourné un peu vers le lit
	var linen := _linen(Color(0.9, 0.95, 0.98) if Builder.soft_render() else HOUSSE_NET, 0.5)
	var draped: Mesh = load(HOUSSE_MESH) as Mesh if ResourceLoader.exists(HOUSSE_MESH) else null
	if draped:
		# le drap simulé (gen_bache.py) : jeté par-dessus le dossier, rentré dans l'assise (plis
		# d'écrasement), il marque les manchettes des accoudoirs et le chapeau de gendarme, pend en pointes
		# aux quatre coins ; contre le chevet et les cartons, il glisse sans s'y poser
		var dm := MeshInstance3D.new()
		dm.name = "Housse"
		dm.mesh = draped
		dm.material_override = linen
		dm.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		holder.add_child(dm)
		_collider(Vector3(0.8, 1.0, 0.78), Vector3(0, 0.5, 0.0), holder)
		return
	# repère du fauteuil, avant vers +z : [rectangle (x, z), hauteur du dessus]
	var supports := [
		[Rect2(-0.25, -0.2, 0.5, 0.55), 0.47],      # coussin d'assise
		[Rect2(-0.3, -0.37, 0.6, 0.12), 0.88],      # dossier
		[Rect2(-0.16, -0.37, 0.32, 0.1), 0.99],     # chapeau du dossier (bergère)
		[Rect2(-0.38, -0.3, 0.09, 0.6), 0.65],      # accoudoirs
		[Rect2(0.29, -0.3, 0.09, 0.6), 0.65],
	]
	var x0 := -0.45
	var z0 := -0.46
	var step := 0.025
	var nx := 37
	var nz := 39
	var hmap := PackedFloat32Array()
	hmap.resize(nx * nz)
	for j in nz:
		for i in nx:
			var p := Vector2(x0 + i * step, z0 + j * step)
			var hv := 0.0
			for s in supports:
				var r: Rect2 = s[0]
				var dx := maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x))
				var dz := maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))
				var dist := sqrt(dx * dx + dz * dz)
				hv = maxf(hv, float(s[1]) - (6.0 * dist + 45.0 * dist * dist))
			hmap[j * nx + i] = hv
	# lissage (deux passes) : le drap arrondit les arêtes
	for _pass in 2:
		var sm := hmap.duplicate()
		for j in range(1, nz - 1):
			for i in range(1, nx - 1):
				var acc := 0.0
				for dj in [-1, 0, 1]:
					for di in [-1, 0, 1]:
						acc += hmap[(j + dj) * nx + (i + di)]
				sm[j * nx + i] = acc / 9.0
		hmap = sm
	var folds := FastNoiseLite.new()
	folds.seed = 41
	folds.frequency = 7.0
	var crinkle := FastNoiseLite.new()
	crinkle.seed = 43
	crinkle.frequency = 16.0
	crinkle.fractal_octaves = 2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var px := x0 + i * step
			var pz := z0 + j * step
			var hv := hmap[j * nx + i]
			var gx := (hmap[j * nx + mini(i + 1, nx - 1)] - hmap[j * nx + maxi(i - 1, 0)]) / (2.0 * step)
			var gz := (hmap[mini(j + 1, nz - 1) * nx + i] - hmap[maxi(j - 1, 0) * nx + i]) / (2.0 * step)
			var g := Vector2(gx, gz)
			var steep := clampf(g.length() / 6.0, 0.0, 1.0)
			var out := -g.normalized() if g.length() > 0.001 else Vector2.ZERO
			# plis verticaux sur les flancs, ourlet froissé au sol, grain fin sur le dessus
			var f := folds.get_noise_3d(px, hv * 0.12, pz) * 0.03 * steep
			var y := hv + crinkle.get_noise_2d(px, pz) * 0.006 * (1.0 - steep)
			if hv < 0.04:
				y = maxf(y, 0.004) + absf(folds.get_noise_2d(px * 1.3, pz * 1.3)) * 0.035 * (1.0 - hv / 0.04)
			st.set_uv(Vector2(px, pz))
			st.add_vertex(Vector3(px + out.x * f, y, pz + out.y * f))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Housse"
	mi.mesh = st.commit()
	mi.material_override = linen
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	holder.add_child(mi)
	_collider(Vector3(0.8, 1.0, 0.78), Vector3(0, 0.5, 0.0), holder)


# ------------------------------------------------------------------ la fuite du toit et le seau

func _bucket() -> void:
	var zinc := _m(Color(0.5, 0.51, 0.5), 0.45, 0.4)
	var b := Node3D.new()
	b.name = "Seau"
	add_child(b)
	b.position = BUCKET_POS
	_mesh(_open_cyl(0.12, 0.15, 0.27, 0.003, 28, 0.006), Vector3.ZERO, zinc, Vector3.ZERO, b)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.146
	rim.outer_radius = 0.156
	rim.rings = 28
	rim.ring_segments = 6
	_mesh(rim, Vector3(0, 0.27, 0), zinc, Vector3.ZERO, b)
	for y in [0.07, 0.17]:
		var band := TorusMesh.new()
		band.inner_radius = 0.12 + 0.03 * y / 0.27
		band.outer_radius = band.inner_radius + 0.007
		band.rings = 28
		band.ring_segments = 4
		_mesh(band, Vector3(0, y, 0), zinc, Vector3.ZERO, b)
	# l'anse, couchée sur le côté
	for s in [-1.0, 1.0]:
		_mesh(_cyl(0.012, 0.012, 0.012, 8), Vector3(s * 0.15, 0.24, 0), zinc, Vector3(0, 0, PI / 2.0), b)
	var pts: Array = []
	for k in 9:
		var a := PI * k / 8.0
		pts.append(Vector3(cos(a) * 0.155, 0.24 + sin(a) * 0.03, -sin(a) * 0.15))
	for i in pts.size() - 1:
		_rod(pts[i], pts[i + 1], 0.0025, _chrome, b, 6)
	# l'eau, presque à mi-hauteur
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.06, 0.06, 0.05)
	wm.roughness = 0.04
	wm.metallic_specular = 0.95
	var water_r := 0.12 + 0.03 * BUCKET_WATER_Y / 0.27 - 0.004
	_no_gi(_mesh(_disc(water_r, 28), Vector3(0, BUCKET_WATER_Y, 0), wm, Vector3.ZERO, b))
	_collider(Vector3(0.3, 0.28, 0.3), Vector3(0, 0.14, 0), b)
	# la goutte, et l'onde qu'elle fait
	var dm := _plain(Color(0.75, 0.8, 0.85), 0.05)
	dm.metallic_specular = 1.0
	_drip = _no_gi(_mesh(_sphere(0.0045, 8), Vector3(BUCKET_POS.x, LEAK_Y - 0.01, BUCKET_POS.z), dm)) as MeshInstance3D
	_drip.name = "Goutte"
	var rp := TorusMesh.new()
	rp.inner_radius = 0.1
	rp.outer_radius = 0.11
	rp.rings = 20
	rp.ring_segments = 3
	var rm := _plain(Color(0.35, 0.37, 0.38), 0.05)
	rm.metallic_specular = 1.0
	_ripple = _no_gi(_mesh(rp, Vector3(BUCKET_POS.x, BUCKET_WATER_Y + 0.001, BUCKET_POS.z), rm)) as MeshInstance3D
	_ripple.name = "Onde"
	_ripple.visible = false
	_ripple.scale = Vector3(0.1, 0.2, 0.1)
	# auréole au plafond, tache sur la moquette
	var stain: Texture2D = load("res://assets/decals/stain_water.png")
	_old_stains.append(_decal(stain, Vector3(BUCKET_POS.x, LEAK_Y, BUCKET_POS.z), Vector3.DOWN, Vector3.BACK, 1.3, 1.1, 0.3, Color(0.8, 0.75, 0.65, 1.0)))
	_old_stains.append(_decal(stain, Vector3(BUCKET_POS.x + 0.05, LEAK_Y, BUCKET_POS.z - 0.04), Vector3.DOWN, Vector3.BACK, 0.45, 0.4, 0.3, Color(0.45, 0.4, 0.32, 1.0)))
	_old_stains.append(_decal(stain, Vector3(BUCKET_POS.x, 0.0, BUCKET_POS.z), Vector3.UP, Vector3.FORWARD, 0.8, 0.7, 0.1, Color(0.35, 0.33, 0.3, 0.7)))
	_look("Regarder le seau", Vector3(0.36, 0.32, 0.36), BUCKET_POS + Vector3(0, 0.16, 0),
		"La fuite du toit. Une goutte toutes les trois secondes. Tu comptes malgré toi.", "seau")


func _process(delta: float) -> void:
	if _drip == null:
		return
	_drip_t = fmod(_drip_t + delta, DRIP_PERIOD)
	var form := DRIP_PERIOD - sqrt(2.0 * (LEAK_Y - 0.012 - BUCKET_WATER_Y) / 9.8)
	if _drip_t < form:
		# la goutte se forme au plafond
		var k := _drip_t / form
		_drip.visible = true
		_drip.scale = Vector3.ONE * lerpf(0.3, 1.0, k)
		_drip.position = Vector3(BUCKET_POS.x, LEAK_Y - 0.004 - 0.005 * k, BUCKET_POS.z)
		_dripped = false
	else:
		var t := _drip_t - form
		var y := LEAK_Y - 0.012 - 0.5 * 9.8 * t * t
		_drip.scale = Vector3(0.9, 1.7, 0.9)
		_drip.position = Vector3(BUCKET_POS.x, maxf(y, BUCKET_WATER_Y), BUCKET_POS.z)
		if y <= BUCKET_WATER_Y + 0.02 and not _dripped:
			_dripped = true
			_drip.visible = false
			_ripple_t = 0.0
			if active:
				Sfx.play_at("drip", BUCKET_POS + Vector3(0, BUCKET_WATER_Y, 0), -11.0, rng.randf_range(0.95, 1.05), 2.0, "Ambiance")
	if _ripple_t >= 0.0:
		_ripple_t += delta
		var r := lerpf(0.1, 1.0, _ripple_t / 0.7)
		_ripple.visible = _ripple_t < 0.7
		_ripple.scale = Vector3(r, 0.2, r)
		if _ripple_t >= 0.7:
			_ripple_t = -1.0


# ------------------------------------------------------------------ armoire, rideaux, murs, plafond

## Contre le mur de ta mère (place de l'ancienne armoire Kenney, x 0,2 → 1,3) : le vieux buffet de cuisine
## de Mamie, peinture blanche écaillée, monté ici quand elle a refait sa cuisine ; dessus, une valise à
## plat et le carton à chapeau ; l'autre valise, couverte d'étiquettes de voyage, debout contre le mur.
func _wardrobe() -> void:
	var back := ZN + DADO + 0.006
	var bf := model("painted_wooden_cabinet", Vector3(0.75, 0, 3.02), 0.0, Vector3(1.1, 0.0, 0.0), true, {"name": "Buffet"})
	var sz := bf.get_meta("size") as Vector3
	bf.position.z = back + sz.z / 2.0
	bf.rotation.y = 0.012
	# valise à plat (couvercle en haut, poignée vers la pièce)
	var flat := Basis(Vector3.UP, PI - 0.06) * Basis(Vector3.RIGHT, -PI / 2.0)
	var v1 := _ph_part("vintage_suitcase", "vintage_suitcase_01", Vector3(0.68, sz.y, back + 0.3), flat, "ValiseDessus")
	var vs := v1.get_meta("size") as Vector3
	_hatbox(Vector3(0.82, sz.y + vs.y, back + 0.27))
	# l'autre, debout contre le mur, entre le buffet et la porte (hors de la zone du battant, x < 2,25)
	var up := Basis(Vector3.UP, 0.04)
	_ph_part("vintage_suitcase", "vintage_suitcase_02", Vector3(1.76, 0, back + 0.125), up, "ValiseDebout", true)


## Carton à chapeau rond, papier rose passé, ruban, couvercle un peu de travers.
func _hatbox(at: Vector3) -> void:
	var hb := Node3D.new()
	hb.name = "CartonAChapeau"
	add_child(hb)
	hb.position = at
	hb.rotation.y = 0.5
	var paper := _grimy(_plain(Color(0.62, 0.5, 0.47), 0.85), 1.6)
	var ribbon := _plain(Color(0.36, 0.22, 0.24), 0.6)
	_merged([[_cm(0.15, 0.15, 0.15, 28, false, true), _at(Vector3(0, 0.075, 0))],
		[_cm(0.156, 0.156, 0.035, 28), _at(Vector3(0.004, 0.152, 0), Vector3(0.03, 0, -0.02))]], paper, hb)
	_merged([[_cm(0.152, 0.152, 0.022, 28, false, false), _at(Vector3(0, 0.05, 0))],
		[_cm(0.1575, 0.1575, 0.012, 28, false, false), _at(Vector3(0.004, 0.152, 0), Vector3(0.03, 0, -0.02))]], ribbon, hb)


func _drapes() -> void:
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/curtain.gdshader")
	cm.set_shader_parameter("color", Color(0.4, 0.24, 0.24))
	cm.set_shader_parameter("sway", 0.004)
	var x := XW + 0.115
	var full := not Builder.soft_render()
	if full:
		# vraie carte (curtain.gdshader du lot V2-SDB : plis aux vraies normales) : rose passé mat, lisière
		# de velours sous la lumière rasante, plis serrés sous la tringle ; un pan diffère de l'autre
		cm.set_shader_parameter("height_m", 1.38)
		cm.set_shader_parameter("rim_k", 0.4)
		cm.set_shader_parameter("roughness_v", 0.88)
		cm.set_shader_parameter("fold_period", 0.1)
	var pan := 0
	for side in [[3.47, 3.98], [5.02, 5.53]]:
		var pm := PlaneMesh.new()
		pm.orientation = PlaneMesh.FACE_Z
		pm.size = Vector2(1.0, 1.38)
		pm.subdivide_width = 48 if full else 30
		pm.subdivide_depth = 12 if full else 6
		var mi := MeshInstance3D.new()
		mi.name = "Rideau"
		mi.mesh = pm
		mi.material_override = cm
		if full:
			var own := cm.duplicate() as ShaderMaterial
			own.set_shader_parameter("seed", 3.7 + pan * 5.3)
			mi.material_override = own
		pan += 1
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var z0: float = side[0]
		var z1: float = side[1]
		mi.position = Vector3(x, 1.67, (z0 + z1) / 2.0)
		mi.rotation.y = PI / 2.0
		mi.scale = Vector3((z1 - z0) / 1.0, 1.0, 1.0)
		add_child(mi)
	_rod(Vector3(x, 2.37, 3.4), Vector3(x, 2.37, 5.6), 0.012, _m(Color(0.42, 0.32, 0.2), 0.4, 0.5))
	for z in [3.4, 5.6]:
		_mesh(_sphere(0.02, 10), Vector3(x, 2.37, z), _m(Color(0.42, 0.32, 0.2), 0.4, 0.5))
		_rod(Vector3(XW, 2.37, z + (0.05 if z < 4.0 else -0.05)), Vector3(x, 2.37, z + (0.05 if z < 4.0 else -0.05)), 0.006, _m(Color(0.42, 0.32, 0.2), 0.4, 0.5))


func _walls() -> void:
	# au-dessus de la télé : un paysage à l'huile (moulin, pont, collines) dans un cadre doré, un peu de
	# travers (Poly Haven, fancy_picture_frame_01, 0,60 × 0,46 m ; il remplace le chromo généré)
	var pic := model("fancy_picture_frame_01", Vector3(TV_POS.x, 1.6 - 0.232, ZN + 0.012), 0.0, Vector3.ZERO, false, {"name": "Tableau"})
	pic.rotation.z = 0.018
	# entre la télé et le buffet, une pendule de cuisine à quartz, arrêtée (la pile est morte)
	model("wall_clock", Vector3(-0.22, 1.5, ZN + 0.025), 0.0, Vector3.ZERO, false, {"name": "Pendule"})
	# le crucifix et son brin de buis, au-dessus du lit
	var cx := Node3D.new()
	cx.name = "Crucifix"
	add_child(cx)
	cx.position = Vector3(0.0, 1.5, ZS)
	cx.rotation.y = PI
	# (bois sombre mat : à 0,45 de rugosité, la lampe de poche en faisait du plastique gris) ; un christ en
	# laiton patiné, bras ouverts
	var wood := _m(Color(0.22, 0.14, 0.08), 0.72)
	_box(Vector3(0.032, 0.3, 0.018), Vector3(0, 0, 0.009), wood, false, cx)
	_box(Vector3(0.17, 0.032, 0.018), Vector3(0, 0.06, 0.009), wood, false, cx)
	_box(Vector3(0.04, 0.028, 0.004), Vector3(0, 0.14, 0.02), _m(Color(0.62, 0.58, 0.48), 0.8), false, cx)   # titulus
	var brass := _plain(Color(0.52, 0.42, 0.24), 0.4, 0.8)
	_box(Vector3(0.012, 0.075, 0.008), Vector3(0, 0.02, 0.022), brass, false, cx)
	_box(Vector3(0.11, 0.008, 0.006), Vector3(0, 0.063, 0.021), brass, false, cx)
	var head := _box(Vector3(0.011, 0.012, 0.009), Vector3(0, 0.068, 0.023), brass, false, cx)
	head.rotation.x = 0.3
	var buis := _m(Color(0.16, 0.24, 0.12), 0.9)
	for k in 6:
		var leaf := _box(Vector3(0.02, 0.009, 0.004), Vector3(0.03 + k * 0.012, 0.11 + (k % 2) * 0.012, 0.004), buis, false, cx)
		leaf.rotation.z = 0.5 + k * 0.2
	# l'ancien emplacement d'un cadre, et la moisissure de la fuite qui descend le long du mur
	var mold: Texture2D = load("res://assets/decals/mold.png")
	_old_stains.append(_decal(mold, Vector3(XE, 2.3, 4.7), Vector3.LEFT, Vector3.UP, 1.0, 0.7, 0.2, Color(1, 1, 1, 0.7)))
	_old_stains.append(_decal(mold, Vector3(2.6, LEAK_Y, 5.9), Vector3.DOWN, Vector3.RIGHT, 0.9, 0.7, 0.3, Color(1, 1, 1, 0.6)))


func _ceiling() -> void:
	# la suspension en opaline, éteinte (l'ampoule est grillée depuis longtemps)
	var p := Vector3(0.0, LEAK_Y, 4.6)
	_mesh(_cyl(0.05, 0.055, 0.025, 16), p + Vector3(0, -0.0125, 0), _m(Color(0.7, 0.66, 0.58), 0.6))
	_mesh(_cyl(0.004, 0.004, 0.38, 6), p + Vector3(0, -0.21, 0), _plain(Color(0.12, 0.1, 0.08), 0.8))
	_mesh(_cyl(0.025, 0.03, 0.04, 12), p + Vector3(0, -0.41, 0), _m(Color(0.5, 0.4, 0.2), 0.4, 0.6))
	var globe := _mesh(_sphere(0.13, 18), p + Vector3(0, -0.53, 0), _m(Color(0.82, 0.78, 0.68), 0.35))
	globe.scale = Vector3(1, 0.85, 1)


# ------------------------------------------------------------------ habillage différé (lot V2-AMIS)

## Télé de 1990 (Poly Haven television_02, taille réelle) : verre bombé de la coque, z(x, dy) relevé sur le
## modèle (moindres carrés, écart 0,5 mm) : [1, x, x², dy, dy², x²·dy²] avec dy = y − 0,26.
const TV_PH := "television_02"
const TV_GLASS := [0.1222, -0.0033, -0.9944, -0.0034, -1.1354, 15.91]
## Centre du verre dans le repère du support posé (modèle centré : x + 0,002, z + 0,053).
const TV_GLASS_C := Vector3(0.002, 0.26, 0.053)
## Dessus de la coque (plat de z = 0,033 à 0,173 dans le support), où se pose l'antenne.
const TV_TOP := 0.4114
const TV_ANTENNA_AT := Vector3(0.02, TV_TOP, 0.088)
## Neige de la télé en vraie carte : grain et lignes deux fois plus fins (160 × 120 avant).
const TV_SNOW_RES := Vector2(320.0, 240.0)


## Objets de décor (Builder.detail), télé de 1990, moquette et usure (Wear) : appelé par Main après la
## mesure de B16, seulement avec une vraie carte graphique (R3). Rien d'interactif, aucune collision ;
## les Kenney remplacés (meuble télé, téléviseur) restent dans l'arbre, cachés : props[], collisions et
## boîtes d'interaction ne changent pas. Le vide-grenier est posé contre les murs, hors du battant de P3
## (x 2,25 → 3,2 ; z 2,9 → 3,9) et des chemins vers la boîte à biscuits, la télé et l'antenne. Aucun
## tirage dans le hasard de la pièce.
func dress_details() -> void:
	_dress_tv()
	_dress_floor()
	_vide_grenier()
	_wear_room()


## Profondeur du verre de television_02 (repère du modèle) en (x, dy).
static func _tv_glass_z(x: float, dy: float) -> float:
	var c: Array = TV_GLASS
	return c[0] + c[1] * x + c[2] * x * x + c[3] * dy + c[4] * dy * dy + c[5] * x * x * dy * dy


## Plaque courbe de w × h m qui épouse le verre, « lift » m devant ; origine au sommet du verre ; UV d'un
## QuadMesh (u de gauche à droite, v de haut en bas), face avant vers +z.
static func _tv_curved(w: float, h: float, lift: float, nx := 24, ny := 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := _tv_glass_z(0.0, 0.0)
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / ny
			var x := (u - 0.5) * w
			var y := (0.5 - v) * h
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(x, y, _tv_glass_z(x, y) - apex + lift))
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			var c := a + nx + 1
			for k in [a, a + 1, c, a + 1, c + 1, c]:
				st.add_index(k)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## La télé de 1990 sur une petite table en bois, à la place des deux Kenney (cachés : leurs collisions,
## props et boîtes restent). La dalle (Device) et la vitre épousent le verre bombé, 2,5 et 4,5 mm devant ;
## l'antenne est reposée sur le dessus de la coque, son fil descend le dos jusqu'aux vis.
func _dress_tv() -> void:
	var cab: Node3D = props.get("cabinetTelevision")
	if cab == null or tv_holder == null or tv == null:
		return
	var ctop := (cab.get_meta("size") as Vector3).y
	var table := detail("small_wooden_table_01", cab.position, 0.0, Vector3(0.0, ctop, 0.0),
		{"sync": true, "fit": "y", "range": 0.0, "shadow": true})
	if table and table.has_meta("size"):
		(cab.get_child(0) as Node3D).visible = false
		# (plus étroite que le Kenney : les cassettes se rangent à côté de la télé)
		for t in _vhs:
			t.position.x = TV_POS.x + 0.285
	var tvset := detail(TV_PH, Vector3.ZERO, 0.0, Vector3.ZERO, {"sync": true, "parent": tv_holder, "range": 0.0, "shadow": true})
	if tvset == null or not tvset.has_meta("size"):
		return
	(tv_holder.get_child(0) as Node3D).visible = false
	for n in _tv_kenney:
		n.visible = false
	tv.position = TV_GLASS_C + Vector3(0.0, 0.0, _tv_glass_z(0.0, 0.0))
	for c in tv.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).mesh = _tv_curved(0.32, 0.24, 0.0025)
	var glass := tv_holder.get_node_or_null("VitreBombee") as MeshInstance3D
	if glass:
		glass.mesh = _tv_curved(0.312, 0.226, 0.0045)
		glass.rotation = Vector3.ZERO
		glass.scale = Vector3.ONE
		glass.position = tv.position
	if tv.mat:
		tv.mat.set_shader_parameter("res", TV_SNOW_RES)
	antenna.position = TV_ANTENNA_AT
	# le fil : du socle, par l'arête du dessus, le long du dos en pente, jusqu'aux deux vis du panneau
	_antenna_wire([Vector3(0.03, TV_TOP + 0.006, 0.05), Vector3(0.045, TV_TOP + 0.004, 0.03),
		Vector3(0.052, 0.351, 0.0), Vector3(0.062, 0.296, -0.075), Vector3(0.07, 0.226, -0.15),
		Vector3(0.075, 0.2, -0.176)], [Vector3(0.07, 0.19, -0.177), Vector3(0.095, 0.19, -0.177)])


## Moquette de la chambre d'amis (vraie carte) : une copie de mats.moquette, au relief et à l'occlusion de
## dirty_carpet (boucles tassées, crasse au pied du poil), même teinte rouille. La moquette du bureau ne
## change pas.
func _dress_floor() -> void:
	var base := mats.moquette as StandardMaterial3D
	const DC := "res://assets/textures/dirty_carpet/dirty_carpet_%s.jpg"
	if base == null or not ResourceLoader.exists(DC % "normal_gl"):
		return
	for c in get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.material_override != base:
			continue
		var m := base.duplicate() as StandardMaterial3D
		m.resource_name = "moquette_amis"
		m.normal_texture = load(DC % "normal_gl")
		m.normal_scale = 1.1
		m.ao_enabled = true
		m.ao_texture = load(DC % "orm")
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.3
		mi.material_override = m
		break


## Morceau de carton déchiré (atlas CardboardSet001, 4 × 4 morceaux) couché sur le sol.
func _scrap(piece: Rect2, size: Vector2, pos: Vector3, rot: float) -> void:
	const CB := "res://assets/textures/CardboardSet001/CardboardSet001_%s"
	if not ResourceLoader.exists(CB % "albedo.png"):
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(CB % "albedo.png")
	m.albedo_color = Color(0.56, 0.5, 0.42)
	m.normal_enabled = true
	m.normal_texture = load(CB % "normal_gl.jpg")
	m.roughness_texture = load(CB % "orm.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.uv1_scale = Vector3(piece.size.x, piece.size.y, 1.0)
	m.uv1_offset = Vector3(piece.position.x, piece.position.y, 0.0)
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := _no_gi(_mesh(pm, pos, m, Vector3(0.0, rot, 0.0))) as MeshInstance3D
	mi.name = "Carton_dechire"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Le vide-grenier de Mamie : cartons empilés contre les murs, une caisse en bois, une caisse en plastique,
## et ce qu'elle voulait vendre (la lampe-tempête, le cheval en porcelaine, le service à thé, les vases, le
## vieux portable beige). Positions relevées sur le banc du lot (boîtes des meubles voisins).
func _vide_grenier() -> void:
	var nwall := ZN + DADO      # face du lambris, mur de ta mère
	var wwall := XW + DADO      # face du lambris, façade
	# (préréglage Basse : sans les trois bibelots les plus lourds, 96 000 triangles à eux trois)
	var rich := Qualite.effective() > Qualite.BASSE
	# 1. le coin entre la table de couture et la télé : la caisse en bois, la lampe-tempête, le cheval
	var crate := detail("wooden_crate_01", Vector3(-2.03, 0, nwall + 0.19), 0.0, Vector3(0.72, 0.0, 0.36), {"sync": true, "shadow": true})
	var crate_top := (crate.get_meta("size") as Vector3).y if crate and crate.has_meta("size") else 0.3
	if rich:
		detail("Lantern_01", Vector3(-1.8, crate_top, nwall + 0.2), 25.0, Vector3.ZERO, {"sync": true})
		detail("horse_statue_01", Vector3(-2.2, crate_top, nwall + 0.17), 28.0, Vector3.ZERO, {"sync": true})
	# 2. contre le mur de ta mère, entre la télé et le buffet (la prise du cordon de la télé reste libre) :
	# deux cartons, le portable fermé dessus
	var low := detail("cardboard_box_01", Vector3(-0.2, 0, nwall + 0.205), 90.0, Vector3.ZERO, {"sync": true, "shadow": true})
	var h1 := (low.get_meta("size") as Vector3).y if low and low.has_meta("size") else 0.342
	var high := detail("cardboard_box_01", Vector3(-0.18, h1, nwall + 0.2), 274.0, Vector3(0.0, h1 * 0.9, 0.0), {"sync": true, "fit": "y", "shadow": true})
	var h2 := h1 + ((high.get_meta("size") as Vector3).y if high and high.has_meta("size") else 0.31)
	# (le modèle fait 65 cm de large : ramené aux 33 cm d'un portable de 1992)
	var lap := detail("classic_laptop", Vector3(-0.2, h2, nwall + 0.2), 176.0, Vector3(0.33, 0.0, 0.0), {"sync": true})
	if lap:
		var stand := lap.find_child("classic_laptop_stand", true, false) as Node3D
		if stand:
			stand.visible = false
		var lid := lap.find_child("classic_laptop_screen", true, false) as Node3D
		if lid:
			lid.rotation.x = deg_to_rad(88.0)        # rabattu
	# 3. sous la fenêtre : une caisse en plastique (un vase dedans), deux cartons, un vase dessus (il se
	# découpe sur la vitre)
	detail("plastic_crate_01", Vector3(wwall + 0.165, 0, 4.33), 0.0, Vector3.ZERO, {"sync": true, "shadow": true})
	detail("ceramic_vase_02", Vector3(wwall + 0.165, 0.012, 4.34), 40.0, Vector3.ZERO, {"sync": true})
	var wl := detail("cardboard_box_01", Vector3(wwall + 0.205, 0, 4.88), 2.0, Vector3.ZERO, {"sync": true, "shadow": true})
	var w1 := (wl.get_meta("size") as Vector3).y if wl and wl.has_meta("size") else 0.342
	var wh := detail("cardboard_box_01", Vector3(wwall + 0.215, w1, 4.87), 185.0, Vector3(0.0, w1 * 0.92, 0.0), {"sync": true, "fit": "y", "shadow": true})
	var w2 := w1 + ((wh.get_meta("size") as Vector3).y if wh and wh.has_meta("size") else 0.315)
	detail("antique_ceramic_vase_01", Vector3(wwall + 0.22, w2, 4.86), 0.0, Vector3.ZERO, {"sync": true, "shadow": true})
	# 4. sur le carton fermé du mur du couloir : le service à thé de Mamie, resserré (la théière, le sucrier,
	# deux tasses sur leurs soucoupes ; les grands plats rangés)
	var tea := detail("tea_set_01", Vector3(2.74, 0.342, 5.4), -84.0, Vector3.ZERO, {"sync": true}) if rich else null
	if tea:
		var model := tea.get_node_or_null("Modele") as Node3D
		var inst := model.get_child(0) as Node3D if model and model.get_child_count() > 0 else null
		if inst:
			inst.position = Vector3.ZERO
			var layout := {
				"tea_set_01_teapot_01": Vector3(-0.07, 0.0, -0.07), "tea_set_01_teapot_01_lid": Vector3(-0.07, 0.002, -0.07),
				"tea_set_01_sugar_cup_01": Vector3(0.1, 0.0, -0.09), "tea_set_01_sugar_cup_01_lid": Vector3(0.1, 0.0, -0.09),
				"tea_set_01_saucer_circular_03": Vector3(0.09, 0.0, 0.1), "tea_set_01_cup_small_01": Vector3(0.09, 0.012, 0.1),
				"tea_set_01_saucer_circular_04": Vector3(-0.1, 0.0, 0.12), "tea_set_01_cup_small_02": Vector3(-0.1, 0.012, 0.12),
			}
			for n in inst.get_children():
				var nd := n as Node3D
				if nd == null:
					continue
				if layout.has(String(nd.name)):
					nd.position = layout[String(nd.name)]
					if String(nd.name).begins_with("tea_set_01_cup_small_02"):
						nd.rotation.y = 2.2
				else:
					nd.visible = false
	# 5. chutes de carton déchiré sur la moquette (CardboardSet001)
	_scrap(Rect2(0.758, 0.543, 0.234, 0.184), Vector2(0.24, 0.19), Vector3(2.38, 0.006, 4.72), 0.5)
	_scrap(Rect2(0.043, 0.027, 0.184, 0.215), Vector2(0.17, 0.2), Vector3(-2.66, 0.006, 4.62), -0.3)


## Usure de la chambre (Wear, vraie carte, pas en Basse) : la fuite (auréole au plafond, coulures et
## moisissure sur le mur du couloir, cerne autour du seau), la crasse du pied des murs et des coins, le
## passage de la porte au lit et vers la table de couture, la poussière sur les cartons et l'appui de la
## fenêtre. Les anciennes taches (stain_water, mold) sont cachées.
func _wear_room() -> void:
	if not Wear.deco_on():
		return
	for d in _old_stains:
		if is_instance_valid(d):
			d.visible = false
	var b := BUCKET_POS
	Wear.decal(self, "tache_plafond", Vector3(b.x, LEAK_Y, b.z), Vector3.DOWN, Vector3.BACK, 1.25, 1.1,
		{"world": true, "variant": 2})
	Wear.decal(self, "cerne", Vector3(b.x + 0.02, 0.0, b.z - 0.03), Vector3.UP, Vector3.FORWARD, 0.75, 0.68,
		{"world": true, "variant": 0, "color": Color(0.36, 0.25, 0.21), "mix": 0.6})
	# l'eau a coulé le long du mur du couloir, au-dessus des cartons
	Wear.decal(self, "coulure", Vector3(XE - 0.012, 2.05, 4.72), Vector3.LEFT, Vector3.UP, 0.42, 1.05,
		{"world": true, "variant": 1, "alpha": 0.85})
	Wear.decal(self, "coulure", Vector3(XE - 0.012, 1.95, 5.15), Vector3.LEFT, Vector3.UP, 0.3, 0.8,
		{"world": true, "variant": 4, "alpha": 0.7})
	Wear.decal(self, "moisissure", Vector3(XE - 0.01, LEAK_Y - 0.12, 4.85), Vector3.LEFT, Vector3.UP, 1.1, 0.3,
		{"world": true, "variant": 0, "alpha": 0.85})
	Wear.decal(self, "moisissure", Vector3(2.6, LEAK_Y, 5.9), Vector3.DOWN, Vector3.RIGHT, 0.8, 0.65,
		{"world": true, "variant": 1, "alpha": 0.75})
	Wear.wall_base(self, 0.22, {"gaps": [Rect2(0.19, 2.71, 1.13, 0.62), Rect2(-1.6, 2.71, 0.82, 0.45),
		Rect2(-3.19, 2.9, 0.72, 1.1), Rect2(2.5, 4.25, 0.7, 2.05), Rect2(-2.45, 2.71, 0.86, 0.45),
		Rect2(-0.5, 2.71, 0.6, 0.45), Rect2(-3.19, 4.1, 0.45, 1.1), Rect2(-0.8, 6.0, 1.6, 0.3),
		Rect2(0.95, 5.78, 0.42, 0.52)]})
	Wear.ceiling_corners(self)
	# passages : de la porte au lit (en évitant le seau), du tapis à la table de couture
	Wear.path(self, [Vector2(3.0, 3.42), Vector2(2.1, 3.95), Vector2(1.25, 4.6), Vector2(0.98, 5.3)], 0.5)
	Wear.path(self, [Vector2(-1.15, 4.25), Vector2(-2.1, 4.12)], 0.45)
	# poussière : l'appui de la fenêtre, le dessus des cartons, du buffet et de la télé
	Wear.decal(self, "poussiere", Vector3(XW + 0.07, 0.948, 4.5), Vector3.UP, Vector3.RIGHT, 1.4, 0.2,
		{"world": true, "alpha": 0.8})
	for top in [Vector3(-0.2, 0.68, ZN + DADO + 0.2), Vector3(XW + DADO + 0.21, 0.66, 4.87), Vector3(2.75, 0.42, 4.6),
			Vector3(2.75, 0.342, 6.0), Vector3(-2.03, 0.31, ZN + DADO + 0.19)]:
		Wear.decal(self, "poussiere", top, Vector3.UP, Vector3.BACK, 0.55, 0.5, {"world": true, "alpha": 0.85, "depth": 0.06})


# ------------------------------------------------------------------ restauration (sauvegarde)

## Réapplique Game.flags après un chargement : boîte ouverte, madeleine mangée, antenne prise,
## lampadaire.
func restore() -> void:
	if Game.flag("boite_ouverte") or Game.has_item("cle_bureau"):
		_set_tin_open(true)
	if Game.flag("madeleine_mangee"):
		_hide_madeleine()
	if Game.flag("antenne_prise") or Game.has_item("antenne"):
		_hide_antenna()
	_update_antenna_label()
	if bool(Game.flag("amis_lampadaire")) != lamp_on:
		lamp_on = bool(Game.flag("amis_lampadaire"))
		_apply_lamp()
	if tv and tv.is_on:
		tv.set_static(0.0)
		tv.power_off(0.0)
