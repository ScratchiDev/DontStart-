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

var desk_top := 0.76
var _tv_id := 0
var _antenna_busy := false
var _drip: MeshInstance3D
var _ripple: MeshInstance3D
var _drip_t := 0.0
var _ripple_t := -1.0
var _dripped := false

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


## Chromo encadré au-dessus de la télé : lac de montagne, chalet, sapins. Jauni.
func _painting() -> ImageTexture:
	var img := Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
	for y in 48:
		for x in 64:
			var c: Color
			if y < 20:
				c = Color(0.55, 0.66, 0.8).lerp(Color(0.86, 0.8, 0.7), y / 20.0)
			else:
				c = Color(0.25, 0.4, 0.45).lerp(Color(0.16, 0.26, 0.3), (y - 20) / 28.0)
			img.set_pixel(x, y, c)
	# montagnes, neige
	for x in 64:
		var m1 := 20.0 - 12.0 * maxf(0.0, 1.0 - absf(x - 20.0) / 18.0) - 6.0 * maxf(0.0, 1.0 - absf(x - 46.0) / 14.0)
		for y in range(int(m1), 21):
			var snow := y < m1 + 3.0 and m1 < 14.0
			img.set_pixel(x, y, Color(0.9, 0.9, 0.92) if snow else Color(0.35, 0.38, 0.45))
		# reflet dans le lac
		for y in range(21, int(21 + (21 - m1) * 0.5)):
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.35, 0.4, 0.48), 0.5))
	# rive, sapins, chalet
	for x in 64:
		for y in range(38, 48):
			img.set_pixel(x, y, Color(0.22, 0.32, 0.16).darkened((y - 38) * 0.03))
	for k in 7:
		var tx := 4 + k * 4 + (k % 2) * 2
		for y in range(26, 40):
			var half := (y - 26) * 0.18
			for x in range(int(tx - half), int(tx + half) + 1):
				if x >= 0 and x < 64:
					img.set_pixel(x, y, Color(0.1, 0.2, 0.12))
	for y in range(31, 39):
		for x in range(44, 54):
			img.set_pixel(x, y, Color(0.55, 0.35, 0.2))
	for y in range(27, 31):
		for x in range(42 + (31 - y), 56 - (31 - y)):
			img.set_pixel(x, y, Color(0.4, 0.16, 0.12))
	img.set_pixel(47, 34, Color(0.95, 0.85, 0.5))
	img.set_pixel(50, 34, Color(0.95, 0.85, 0.5))
	# jauni, grain, vignette
	for y in 48:
		for x in 64:
			var c := img.get_pixel(x, y).lerp(Color(0.9, 0.78, 0.55), 0.2) * 0.85
			var vig := 1.0 - 0.6 * (pow((x + 0.5) / 64.0 - 0.5, 2.0) + pow((y + 0.5) / 48.0 - 0.5, 2.0)) * 2.0
			var n := rng.randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(clampf(c.r * vig + n, 0, 1), clampf(c.g * vig + n, 0, 1), clampf(c.b * vig + n, 0, 1)))
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
	var cb := _box(Vector3(0.42, 0.3, 0.38), Vector3(0.34, top + 0.15, 4.65), _m(Color(0.5, 0.36, 0.22), 0.95))
	cb.rotation.y = 0.12
	for k in 3:
		_box(Vector3(0.52 - k * 0.02, 0.04, 0.58 - k * 0.03), Vector3(-0.36, top + 0.02 + k * 0.04, 4.85),
			_m([Color(0.55, 0.45, 0.32), Color(0.3, 0.35, 0.45), Color(0.6, 0.3, 0.25)][k], 1.0))
	# la bâche : un drap de plastique laiteux, plissé, qui retombe jusqu'au sol
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
	var tarp := StandardMaterial3D.new()
	tarp.albedo_color = Color(0.72, 0.75, 0.78, 0.32)
	tarp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tarp.roughness = 0.1
	tarp.metallic_specular = 0.9
	var mi := _no_gi(_mesh(st.commit(), Vector3.ZERO, tarp))
	mi.name = "Bache"
	# deux bandes de scotch brun pour la tenir à la tête de lit
	for x in [-0.55, 0.55]:
		_box(Vector3(0.05, 0.002, 0.14), Vector3(x, 0.652, 6.16), _plain(Color(0.45, 0.32, 0.18), 0.4))


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
	_mesh(_cyl(0.028, 0.025, 0.09, 14), Vector3(1.0, top + 0.048, 6.06), _plain(Color(0.7, 0.75, 0.75), 0.1))
	_mesh(_cyl(0.025, 0.022, 0.04, 14), Vector3(1.0, top + 0.024, 6.06), _plain(Color(0.25, 0.3, 0.28), 0.05))
	# le câble du chargeur : blanc, neuf, scotché le long du lambris jusqu'à la prise
	var bz := ZS - DADO - 0.003
	var back := babyphone.to_global(Vector3(0, 0.02, -0.03))
	_cable([back, Vector3(1.2, top + 0.004, 6.1), Vector3(1.2, top - 0.02, bz), Vector3(1.2, 0.262, bz),
		Vector3(1.5, 0.262, bz)], Vector3.FORWARD)
	_socket(Vector3(1.53, 0.25, ZS - DADO), Vector3.FORWARD, _new_white)


# ------------------------------------------------------------------ le lampadaire (éteint)

func _floor_lamp() -> void:
	var lp := prop("lampRoundFloor", Vector3(-1.6, 0, 6.0), 0.0, Vector3(0.0, 1.6, 0.0), true)
	lamp_shade = _plain(Color(0.78, 0.66, 0.48), 0.9)
	lamp_shade.emission_enabled = true
	lamp_shade.emission = Color(1.0, 0.7, 0.4)
	lamp_shade.emission_energy_multiplier = 0.0
	_retint(lp, {"lamp": lamp_shade, "metal": _m(Color(0.45, 0.38, 0.25), 0.4, 0.6)})
	for mi in lp.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		g.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
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
		lamp_light.light_energy = 0.55 if on else 0.0
		lamp_light.shadow_enabled = on
		lamp_shade.emission_energy_multiplier = 0.9 if on else 0.0
		lamp_it.label = "Éteindre le lampadaire" if on else "Allumer le lampadaire"
		if is_inside_tree():
			Sfx.play_at("metalClick", lamp_light.global_position + Vector3(0, -0.6, 0), -18.0, 0.8)


# ------------------------------------------------------------------ le meuble télé et le vieux téléviseur

func _tv() -> void:
	var cab := prop("cabinetTelevision", TV_POS, 0.0, Vector3(1.0, 0.42, 0.32), true)
	var ctop := (cab.get_meta("size") as Vector3).y
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
		_mesh(_cyl(0.016, 0.018, 0.016, 14), Vector3((0.31 + k * 0.05 - 0.205) * s, 0.2 * s, 0.135 * s + 0.006), knob, Vector3(PI / 2.0, 0, 0), tv_holder)
	_mesh(_sphere(0.004, 6), Vector3((0.36 - 0.205) * s, 0.04 * s, 0.135 * s + 0.002), _plain(Color(0.25, 0.04, 0.03), 0.4), Vector3.ZERO, tv_holder)
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


func _tv_has_snowed() -> bool:
	if Game.flag("tele_a_neige") or Game.flag("babyphone_parle"):
		return true
	var hn := _haunt()
	return hn != null and not hn.said("babyphone").is_empty()


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
	var lead := _plain(Color(0.35, 0.25, 0.16), 0.6)
	var to_ant := antenna.transform.affine_inverse()
	var back := -ts.z / 2.0
	var a: Vector3 = to_ant * Vector3(0.02, ts.y + 0.012, -0.085)
	var b: Vector3 = to_ant * Vector3(0.05, ts.y + 0.002, back + 0.004)
	var c: Vector3 = to_ant * Vector3(0.08, ts.y - 0.08, back - 0.003)
	for pair in [[a, b], [b, c]]:
		var seg := _rod(pair[0], pair[1], 0.003, lead, antenna, 6)
		seg.scale = Vector3(2.2, 1.0, 0.5)
	for k in 2:
		var screw := _mesh(_cyl(0.005, 0.005, 0.004, 8), to_ant * Vector3(0.07 + k * 0.025, ts.y - 0.08, back - 0.002), _chrome, Vector3(PI / 2.0, 0, 0), antenna)
		screw.rotation.y = -antenna.rotation.y
	var world := tv_holder.position + Vector3(0.02, ts.y + 0.2, -0.04)
	antenna_it = _interactable("Examiner l'antenne", Vector3(0.72, 0.4, 0.26), world, self, LAYER_INTERACT, 2.4)
	antenna_it.used.connect(func(_i: Interactable) -> void:
		if Game.has_item("tournevis"):
			unscrew_antenna()
		else:
			examine_antenna())


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
	var desk := prop("desk", DESK_POS, 90.0, Vector3(1.1, 0.76, 0.55), true)
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
	_box(Vector3(0.38, 0.03, 0.18), Vector3(0, 0.06, 0), cream, false, sm)
	_box(Vector3(0.09, 0.2, 0.13), Vector3(0.13, 0.17, -0.01), cream, false, sm)
	_box(Vector3(0.34, 0.075, 0.11), Vector3(0.0, 0.275, -0.01), cream, false, sm)
	_box(Vector3(0.08, 0.13, 0.115), Vector3(-0.15, 0.235, -0.01), cream, false, sm)
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

func _mannequin() -> void:
	var mq := Node3D.new()
	mq.name = "Mannequin"
	add_child(mq)
	mq.position = Vector3(-2.6, 0, 5.9)
	mq.rotation.y = 1.95      # il « regarde » la porte
	var wood := _m(Color(0.25, 0.17, 0.11), 0.5)
	var linen := _m(Color(0.66, 0.6, 0.48), 0.95)
	# trépied
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		_rod(Vector3(0, 0.34, 0), Vector3(cos(a) * 0.26, 0.015, sin(a) * 0.26), 0.012, wood, mq, 8)
		_mesh(_sphere(0.016, 8), Vector3(cos(a) * 0.26, 0.012, sin(a) * 0.26), _plain(Color(0.08, 0.08, 0.08), 0.5), Vector3.ZERO, mq)
	_mesh(_cyl(0.03, 0.035, 0.06, 12), Vector3(0, 0.34, 0), wood, Vector3.ZERO, mq)
	_mesh(_cyl(0.013, 0.013, 0.7, 10), Vector3(0, 0.7, 0), _plain(Color(0.4, 0.38, 0.35), 0.35, 0.6), Vector3.ZERO, mq)
	_mesh(_cyl(0.03, 0.03, 0.025, 12), Vector3(0, 0.77, 0), _plain(Color(0.4, 0.38, 0.35), 0.35, 0.6), Vector3.ZERO, mq)
	# le buste, en lin, sans tête
	_ellipsoid(Vector3(0.34, 0.24, 0.24), Vector3(0, 1.04, 0), linen, mq)
	_ellipsoid(Vector3(0.26, 0.24, 0.19), Vector3(0, 1.2, 0), linen, mq)
	_ellipsoid(Vector3(0.33, 0.24, 0.24), Vector3(0, 1.35, 0.005), linen, mq)
	for s in [-1.0, 1.0]:
		_ellipsoid(Vector3(0.12, 0.11, 0.1), Vector3(s * 0.065, 1.355, 0.075), linen, mq, 10)
	_ellipsoid(Vector3(0.39, 0.12, 0.21), Vector3(0, 1.47, 0), linen, mq)
	_mesh(_cyl(0.045, 0.05, 0.1, 14), Vector3(0, 1.55, 0), linen, Vector3.ZERO, mq)
	_mesh(_cyl(0.05, 0.05, 0.02, 14), Vector3(0, 1.61, 0), wood, Vector3.ZERO, mq)
	_mesh(_sphere(0.018, 10), Vector3(0, 1.63, 0), wood, Vector3.ZERO, mq)
	# la robe : jupe bleu marine à pois, corsage épinglé sur la moitié gauche seulement
	var dots := StandardMaterial3D.new()
	dots.albedo_texture = _dots_texture()
	dots.roughness = 0.9
	dots.uv1_scale = Vector3(4.0, 3.0, 1.0)
	var dress := _grimy(dots, 0.8)
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.165
	skirt.bottom_radius = 0.29
	skirt.height = 0.52
	skirt.radial_segments = 20
	skirt.rings = 1
	_mesh(skirt, Vector3(0, 0.73, 0), dress, Vector3.ZERO, mq)
	var half := SphereMesh.new()
	half.radius = 0.5
	half.height = 1.0
	half.is_hemisphere = true
	half.radial_segments = 16
	half.rings = 6
	for part in [[Vector3(0.0, 1.06, 0), Vector3(0.36, 0.25, 0.26)], [Vector3(0.0, 1.2, 0), Vector3(0.275, 0.25, 0.2)],
			[Vector3(0.0, 1.35, 0.005), Vector3(0.35, 0.25, 0.26)]]:
		var hm := _mesh(half, part[0], dress, Vector3(0, 0, PI / 2.0), mq)
		var sz: Vector3 = part[1]
		hm.scale = Vector3(sz.y, sz.x, sz.z)
	# épingles le long du bord, et quelques-unes à l'ourlet
	var pin_heads := [Color(0.9, 0.9, 0.85), Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85), Color(0.95, 0.75, 0.2)]
	for k in 9:
		var y := 0.98 + k * 0.05
		_mesh(_sphere(0.004, 6), Vector3(0.004, y, 0.13 - absf(y - 1.2) * 0.12), _plain(pin_heads[k % 4], 0.3), Vector3.ZERO, mq)
	for k in 6:
		var a := -0.6 + k * 0.4
		_mesh(_sphere(0.004, 6), Vector3(cos(a) * 0.29, 0.48, sin(a) * 0.29 + 0.0), _plain(pin_heads[(k + 1) % 4], 0.3), Vector3.ZERO, mq)
	# le mètre ruban autour du cou
	var tape := _plain(Color(0.85, 0.7, 0.2), 0.6)
	for s in [-1.0, 1.0]:
		var strip := _box(Vector3(0.016, 0.36, 0.002), Vector3(s * 0.07, 1.36, 0.135), tape, false, mq)
		strip.rotation = Vector3(-0.28, 0, s * 0.12)
	var neck := TorusMesh.new()
	neck.inner_radius = 0.05
	neck.outer_radius = 0.056
	neck.rings = 16
	neck.ring_segments = 4
	_mesh(neck, Vector3(0, 1.525, 0.01), tape, Vector3(0.25, 0, 0), mq)
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


# ------------------------------------------------------------------ la fuite du toit et le seau

func _bucket() -> void:
	var zinc := _m(Color(0.4, 0.41, 0.4), 0.5, 0.55)
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
	_decal(stain, Vector3(BUCKET_POS.x, LEAK_Y, BUCKET_POS.z), Vector3.DOWN, Vector3.BACK, 1.3, 1.1, 0.3, Color(0.8, 0.75, 0.65, 1.0))
	_decal(stain, Vector3(BUCKET_POS.x + 0.05, LEAK_Y, BUCKET_POS.z - 0.04), Vector3.DOWN, Vector3.BACK, 0.45, 0.4, 0.3, Color(0.45, 0.4, 0.32, 1.0))
	_decal(stain, Vector3(BUCKET_POS.x, 0.0, BUCKET_POS.z), Vector3.UP, Vector3.FORWARD, 0.8, 0.7, 0.1, Color(0.35, 0.33, 0.3, 0.7))
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

func _wardrobe() -> void:
	# la grande armoire (les draps, les nappes) contre le mur de ta mère
	var wd := prop("bookcaseClosedDoors", Vector3(0.75, 0, 3.02), 0.0, Vector3(1.1, 1.95, 0.5), true)
	wd.name = "Armoire"
	# un bois sombre et ciré : la texture de parquet des meubles, sur deux mètres de haut, faisait un
	# mur de briques
	var varnish := _m(Color(0.27, 0.17, 0.1), 0.5)
	_retint(wd, {"wood": varnish, "wooddark": _m(Color(0.2, 0.13, 0.08), 0.5)})
	var sz := wd.get_meta("size") as Vector3
	# une valise et un carton à chapeau sur le dessus
	_box(Vector3(0.6, 0.16, 0.4), Vector3(0.68, sz.y + 0.08, 3.0), _m(Color(0.3, 0.22, 0.16), 0.6))
	_mesh(_cyl(0.13, 0.13, 0.17, 18), Vector3(0.95, sz.y + 0.16 + 0.085, 3.02), _m(Color(0.62, 0.55, 0.45), 0.8))


func _drapes() -> void:
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/curtain.gdshader")
	cm.set_shader_parameter("color", Color(0.4, 0.24, 0.24))
	cm.set_shader_parameter("sway", 0.004)
	var x := XW + 0.115
	for side in [[3.47, 3.98], [5.02, 5.53]]:
		var pm := PlaneMesh.new()
		pm.orientation = PlaneMesh.FACE_Z
		pm.size = Vector2(1.0, 1.38)
		pm.subdivide_width = 30
		pm.subdivide_depth = 6
		var mi := MeshInstance3D.new()
		mi.name = "Rideau"
		mi.mesh = pm
		mi.material_override = cm
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


func _frame(pos: Vector3, facing: Vector3, size: Vector2, tex: Texture2D) -> void:
	var holder := Node3D.new()
	holder.name = "Cadre"
	add_child(holder)
	holder.position = pos
	holder.rotation = Vector3(0, atan2(facing.x, facing.z), 0.015)
	var b := 0.04
	var fm := _m(Color(0.5, 0.38, 0.17), 0.4, 0.55)
	_box(Vector3(size.x, b, 0.03), Vector3(0, size.y / 2.0 - b / 2.0, 0.015), fm, false, holder)
	_box(Vector3(size.x, b, 0.03), Vector3(0, -size.y / 2.0 + b / 2.0, 0.015), fm, false, holder)
	_box(Vector3(b, size.y - 2.0 * b, 0.03), Vector3(-size.x / 2.0 + b / 2.0, 0, 0.015), fm, false, holder)
	_box(Vector3(b, size.y - 2.0 * b, 0.03), Vector3(size.x / 2.0 - b / 2.0, 0, 0.015), fm, false, holder)
	var pic := StandardMaterial3D.new()
	pic.albedo_texture = tex
	pic.roughness = 0.75
	pic.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_quad(size - Vector2(2.0 * b, 2.0 * b), Vector3(0, 0, 0.01), pic, 0.0, holder)


func _walls() -> void:
	# le chromo au-dessus de la télé
	_frame(Vector3(TV_POS.x, 1.6, ZN), Vector3.BACK, Vector2(0.56, 0.44), _painting())
	# le crucifix et son brin de buis, au-dessus du lit
	var cx := Node3D.new()
	cx.name = "Crucifix"
	add_child(cx)
	cx.position = Vector3(0.0, 1.5, ZS)
	cx.rotation.y = PI
	var wood := _m(Color(0.3, 0.2, 0.12), 0.45)
	_box(Vector3(0.032, 0.3, 0.018), Vector3(0, 0, 0.009), wood, false, cx)
	_box(Vector3(0.17, 0.032, 0.018), Vector3(0, 0.06, 0.009), wood, false, cx)
	_box(Vector3(0.012, 0.075, 0.008), Vector3(0, 0.02, 0.022), _plain(Color(0.6, 0.55, 0.42), 0.35, 0.6), false, cx)
	var buis := _m(Color(0.16, 0.24, 0.12), 0.9)
	for k in 6:
		var leaf := _box(Vector3(0.02, 0.009, 0.004), Vector3(0.03 + k * 0.012, 0.11 + (k % 2) * 0.012, 0.004), buis, false, cx)
		leaf.rotation.z = 0.5 + k * 0.2
	# l'ancien emplacement d'un cadre, et la moisissure de la fuite qui descend le long du mur
	var mold: Texture2D = load("res://assets/decals/mold.png")
	_decal(mold, Vector3(XE, 2.3, 4.7), Vector3.LEFT, Vector3.UP, 1.0, 0.7, 0.2, Color(1, 1, 1, 0.7))
	_decal(mold, Vector3(2.6, LEAK_Y, 5.9), Vector3.DOWN, Vector3.RIGHT, 0.9, 0.7, 0.3, Color(1, 1, 1, 0.6))


func _ceiling() -> void:
	# la suspension en opaline, éteinte (l'ampoule est grillée depuis longtemps)
	var p := Vector3(0.0, LEAK_Y, 4.6)
	_mesh(_cyl(0.05, 0.055, 0.025, 16), p + Vector3(0, -0.0125, 0), _m(Color(0.7, 0.66, 0.58), 0.6))
	_mesh(_cyl(0.004, 0.004, 0.38, 6), p + Vector3(0, -0.21, 0), _plain(Color(0.12, 0.1, 0.08), 0.8))
	_mesh(_cyl(0.025, 0.03, 0.04, 12), p + Vector3(0, -0.41, 0), _m(Color(0.5, 0.4, 0.2), 0.4, 0.6))
	var globe := _mesh(_sphere(0.13, 18), p + Vector3(0, -0.53, 0), _m(Color(0.82, 0.78, 0.68), 0.35))
	globe.scale = Vector3(1, 0.85, 1)


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
		lamp_light.light_energy = 0.55 if lamp_on else 0.0
		lamp_light.shadow_enabled = lamp_on
		lamp_shade.emission_energy_multiplier = 0.9 if lamp_on else 0.0
		lamp_it.label = "Éteindre le lampadaire" if lamp_on else "Allumer le lampadaire"
	if tv and tv.is_on:
		tv.set_static(0.0)
		tv.power_off(0.0)
