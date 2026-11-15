extends HouseRoom
## La chambre d'Henriette et Albert. En v0.3, elle est construite au minimum : la porte P2 reste fermée
## (la clé est dans la serrure, côté intérieur) et on ne la voit que par CAM 3, sur la console du bureau.
## Le grand lit, le côté d'Albert vide et la couette rabattue (il est descendu à la cave) ; Henriette
## endormie sous la couette (ses cachets), tournée vers le mur, qui respire lentement (14 fois par
## minute) ; à son poignet, posé sur la couette, le bracelet de téléassistance clignote en vert à chaque
## battement (58 par minute). Une veilleuse orange en forme de chouette. Dans l'angle, au plafond, la
## caméra de l'assurance (CAM 3) : image en noir et blanc, « ♥ 58 » incrusté.
## Le mobilier, une chambre Henri II en chêne sombre sculpté (modèles Poly Haven, CC0, voir
## assets/ASSETS_CC0.md) : lit, chevets, armoire, commode et son miroir doré ; une comtoise arrêtée, la
## berceuse d'Henriette sous un paysage encadré, des rideaux de velours, le crucifix et son buis.
## Repère : intérieur x −3.2 → 3.2, z −7.3 → −2.7, sol y = 0, plafond 2.6. Porte P2 : mur x = 3.25 en
## z −3.6 (zone de battant laissée libre : x 2.25 → 3.2, z −4.1 → −3.1). Fenêtre F2 (store baissé) :
## mur x = −3.25 en z −5.0.
## Fonctions publiques : set_heart(bpm), set_breath(cycles_par_minute), restore().
## Propriétés : cam3 (FeedCam « CAM 3 CHAMBRE 1 »), heart_bpm, breath_cpm, shape (la forme qui respire).

const XW := -3.188       # faces du papier peint
const XE := 3.188
const ZN := -7.288
const ZS := -2.712
const BED_C := Vector3(-0.6, 0.0, -3.8)
const SHAPE_POS := Vector3(-0.2, 0.5, -3.9)
## (le plan dit y 0.62 : la LED est posée sur le bras, lui-même posé sur la forme, d'où y ≈ 0.70)
const ARM_Y := 0.665
const BRACELET_POS := Vector3(-0.05, ARM_Y + 0.036, -3.6)
const NIGHT_LIGHT_POS := Vector3(0.55, 0.3, -3.1)
const CAM_POS := Vector3(2.9, 2.35, -6.9)
const CAM_AIM := Vector3(-0.4, 0.5, -3.8)
const NIGHTSTAND_TOP := 0.56   # dessus des chevets (ClassicNightstand_01 mis à cette hauteur)
const NICHE_Y := 0.173         # sol de leur niche ouverte (0,216 × 0,8)

## Caméra de la chambre : un FeedCam qui incruste le pouls du bracelet (« ♥ 58 ») en haut à droite de
## ses vignettes ; le cœur s'allume à chaque battement.
class HeartCam extends FeedCam:
	var bpm := 58
	var _hearts: Array = []      # [TextureRect]
	var _beat := 0.0

	func make_view(view_size: Vector2, show_labels := true) -> Control:
		var root := super.make_view(view_size, show_labels)
		var tr := TextureRect.new()
		tr.name = "Pouls"
		tr.texture = heart_texture(bpm)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_KEEP
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.position = Vector2(view_size.x - tr.texture.get_width() - 3, 3)
		root.add_child(tr)
		_hearts.append(tr)
		return root

	## « ♥ n » en police 3 × 5 agrandie deux fois (le cœur en rouge pâle, le chiffre en blanc).
	static func heart_texture(n: int) -> ImageTexture:
		var digits := str(n)
		var img := Image.create_empty(8 + 8 + digits.length() * 8 + 1, 11, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		FeedCam.draw_text(img, "♥", Vector2i(0, 0), 2, Color(1.0, 0.42, 0.38))
		FeedCam.draw_text(img, digits, Vector2i(16, 0), 2)
		return ImageTexture.create_from_image(img)

	func set_bpm(n: int) -> void:
		bpm = n
		var tex := heart_texture(n)
		for tr in _hearts:
			if is_instance_valid(tr):
				(tr as TextureRect).texture = tex

	func _process(delta: float) -> void:
		super._process(delta)
		if _hearts.is_empty():
			return
		_beat += delta * bpm / 60.0
		var on := fmod(_beat, 1.0) < 0.3
		for tr in _hearts:
			if is_instance_valid(tr):
				(tr as TextureRect).modulate.a = 1.0 if on else 0.45


var house: House
var rng := RandomNumberGenerator.new()
var cam3: HeartCam
var cam3_ir: SpotLight3D
var shape: Node3D                 # la forme sous la couette (elle respire)
var heart_bpm := 58
var breath_cpm := 14.0
var bracelet_mat: StandardMaterial3D
var bracelet_light: OmniLight3D
var _shape_base := Vector3.ONE
var _breath_t := 0.0
var _beat_t := 0.0
var _quilt: StandardMaterial3D
var _cable_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _new_white: StandardMaterial3D
var _casters: Array = []          # meubles qui portent une ombre : [[GeometryInstance3D, réglage d'origine]]
var _casting := true              # leurs ombres sont-elles allumées (le joueur est dans la chambre)


func furnish(h: House) -> void:
	house = h
	rng.seed = 5812
	_cable_mat = _plain(Color(0.9, 0.9, 0.88), 0.4)
	_tape_mat = _plain(Color(0.78, 0.76, 0.68), 0.3)
	_new_white = _plain(Color(0.74, 0.74, 0.72), 0.4)
	_quilt = StandardMaterial3D.new()
	_quilt.albedo_texture = _quilt_texture()
	_quilt.roughness = 1.0
	_quilt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_quilt = _grimy(_triplanar(_quilt, 1.6), 0.7)
	_bed()
	_sleeper()
	_nightstands()
	_furniture()
	_camera()
	_key_in_lock()
	add_rug(Rect2(-1.6, -6.05, 2.0, 1.2))
	_collect_casters()


# ------------------------------------------------------------------ ombres des meubles

## Les meubles ne projettent d'ombre que quand le joueur est dans la chambre : la porte P2 reste fermée,
## aucune lumière du couloir n'y entre, et les flux (CAM 3) sont rendus sans ombres. Depuis le couloir,
## ces dizaines de milliers de triangles ne coûteraient que dans la passe d'ombre de la lampe de poche,
## qui traverse le mur (B5). Les réglages d'origine (petits objets sans ombre) sont gardés.
func _collect_casters() -> void:
	var n0 := int(get_meta("coque", 0))
	for i in range(n0, get_child_count()):
		var c := get_child(i)
		var geos: Array = c.find_children("*", "GeometryInstance3D", true, false)
		if c is GeometryInstance3D:
			geos.append(c)
		for g in geos:
			var gi := g as GeometryInstance3D
			if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				_casters.append([gi, gi.cast_shadow])
	_set_casting(house != null and house.current == self)


func _set_casting(on: bool) -> void:
	if on == _casting:
		return
	_casting = on
	for e in _casters:
		var gi: GeometryInstance3D = e[0]
		if is_instance_valid(gi):
			gi.cast_shadow = e[1] if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## (House appelle set_active sur chaque pièce quand le joueur change de pièce, après avoir mis à jour
## house.current.)
func set_active(on: bool) -> void:
	super.set_active(on)
	_set_casting(house != null and house.current == self)


# ------------------------------------------------------------------ outils

func _m(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	return _grimy(_plain(c, rough, metal))


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := _plain(c * 0.4, 0.4)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, hh: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = hh
	c.radial_segments = seg
	c.rings = 1
	return c


func _sphere(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	return s


## Boîte posée de travers (angle autour de y, en radians).
func _box_rot(size: Vector3, pos: Vector3, mat: Material, rot_y: float) -> MeshInstance3D:
	var b := _box(size, pos, mat)
	b.rotation.y = rot_y
	return b


## Petit modèle : pas d'ombre portée (une passe d'ombre de moins pour des milliers de triangles).
func _no_shadow(n: Node3D) -> Node3D:
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


func _no_gi(mi: GeometryInstance3D) -> GeometryInstance3D:
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _capsule(r: float, hh: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = hh
	c.radial_segments = 16
	c.rings = 6
	return c


## Câble blanc neuf, en segments droits (normal : la surface, vers la pièce), scotché tous les 40 cm.
func _cable(points: Array, normal: Vector3, tape := true, radius := 0.0028) -> void:
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
		mi.material_override = _cable_mat
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


## Tissu matelassé à petites fleurs (la couette d'Henriette), dessiné pixel par pixel.
func _quilt_texture() -> ImageTexture:
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var base := Color(0.62, 0.5, 0.5)
	var nz := FastNoiseLite.new()
	nz.seed = 77
	nz.frequency = 0.15
	for y in n:
		for x in n:
			var c := base.darkened(0.08 + nz.get_noise_2d(x, y) * 0.06)
			# piqûres du matelassage, en losanges
			if (x + y) % 16 == 0 or (x - y + 64) % 16 == 0:
				c = c.darkened(0.22)
			img.set_pixel(x, y, c)
	for k in 26:
		var cx := rng.randi_range(0, n - 1)
		var cy := rng.randi_range(0, n - 1)
		var pc: Color = [Color(0.72, 0.36, 0.4), Color(0.78, 0.7, 0.5), Color(0.5, 0.42, 0.62)][k % 3]
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			img.set_pixel((cx + d.x + n) % n, (cy + d.y + n) % n, pc if d != Vector2i.ZERO else Color(0.85, 0.78, 0.4))
		img.set_pixel((cx + 2) % n, (cy + 1) % n, Color(0.35, 0.45, 0.3))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ le lit

func _bed() -> void:
	# grand lit Henri II en chêne sculpté (Poly Haven GothicBed_01, CC0) : sa literie blanche fait le
	# drap et les oreillers ; matelas à 0,447 (le Kenney : 0,455), la couette et la forme n'ont pas bougé
	var bed := prop("bedDouble", BED_C, 180.0, Vector3(1.6, 0, 2.05), true,
		{"carpet": Color(0.5, 0.4, 0.4), "carpetwhite": Color(0.66, 0.64, 0.6)}, "", "GothicBed_01")
	var gothic := bed.has_meta("ph_id")
	var cover := bed.find_child("cover", true, false) as Node3D
	var box := _aabb_of(cover if cover else bed, self)
	if cover:
		cover.visible = false
	var top := box.end.y
	var bed_box := _aabb_of(bed, self)
	if gothic:
		# la couette passe au-dessus de la literie du modèle (≤ 0,46) et s'arrête devant les colonnes du
		# pied (pied du lit : z −4,825, colonnes jusqu'à −4,75) ; le drap blanc et l'oreiller d'Albert,
		# découverts, sont ceux du modèle
		_duvet(bed_box.position.x + 0.02, bed_box.end.x - 0.02, bed_box.position.z + 0.15, top, 0.06, 0.06)
		return
	_duvet(bed_box.position.x + 0.02, bed_box.end.x - 0.02, bed_box.position.z + 0.04, top)
	# l'oreiller d'Albert, creusé, et le drap blanc découvert de son côté
	var sheet := _plain(Color(0.66, 0.65, 0.61), 0.95)
	var sh := _box(Vector3(0.74, 0.012, 0.66), Vector3(-1.02, top + 0.006, -3.38), sheet)
	sh.rotation.y = 0.04
	var dent := _mesh(_capsule(0.06, 0.4), Vector3(-1.0, top + 0.07, -3.0), _plain(Color(0.62, 0.6, 0.57), 0.95), Vector3(0, 0, PI / 2.0))
	dent.scale = Vector3(1.0, 0.45, 1.0)
	_mesh(_capsule(0.012, 0.3), Vector3(-1.04, top + 0.02, -3.72), sheet, Vector3(0.0, 0.3, PI / 2.0))


## Couette générée : elle couvre le lit et retombe sur les côtés et au pied. Côté Henriette (x > −0.6),
## elle monte jusqu'aux épaules ; côté Albert, elle est rabattue en biais vers le pied.
## lift : hauteur ajoutée au-dessus du matelas ; hang_foot : longueur qui retombe au pied.
func _duvet(x0: float, x1: float, z_foot: float, top: float, lift := 0.045, hang_foot := 0.3) -> void:
	var hang := 0.3
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 1.5
	var nx := 34
	var nz := 30
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var s := lerpf(-w / 2.0 - hang, w / 2.0 + hang, float(i) / nx)
			var xs := clampf(cx + s, x0, x1)
			# bord haut de la couette (vers la tête) : épaules d'Henriette, rabat d'Albert
			var k_albert := smoothstep(-0.45, -0.8, xs)
			var z_top := lerpf(-3.18, -3.78, k_albert)
			var v := float(j) / nz
			var z := lerpf(z_foot - hang_foot, z_top, v)
			var x := cx + s
			var y := top + lift
			var over := absf(s) - w / 2.0
			if over > 0.0:
				x = cx + signf(s) * (w / 2.0 + 0.025 + over * 0.12)
				y -= over * 1.05
			var over_z := z_foot - z
			if over_z > 0.0:
				z = z_foot - 0.025 - over_z * 0.12
				y -= over_z * 1.05
			# le corps, couché sur le côté : la couette se soulève un peu autour de la forme
			var body := exp(-pow((x + 0.2) / 0.26, 2.0)) * smoothstep(-4.85, -4.35, z) * smoothstep(-3.0, -3.35, z)
			y += body * 0.07
			# le rabat d'Albert : un bourrelet le long du bord replié
			var edge := absf(z - z_top)
			y += k_albert * exp(-pow(edge / 0.07, 2.0)) * 0.06
			y += noise.get_noise_2d(x * 1.3, z * 1.3) * 0.03
			if j > nz - 2:
				y += 0.012
			x += noise.get_noise_2d(z * 4.0, x * 4.0) * 0.008
			st.set_uv(Vector2(float(i) / nx * 3.0, float(j) / nz * 4.0))
			st.add_vertex(Vector3(x, y, z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Couette"
	mi.mesh = st.commit()
	mi.material_override = _quilt
	add_child(mi)


# ------------------------------------------------------------------ Henriette, endormie

func _sleeper() -> void:
	# la forme sous la couette : couchée sur le côté, tournée vers la place vide d'Albert
	shape = Node3D.new()
	shape.name = "Forme"
	add_child(shape)
	shape.position = SHAPE_POS
	var body := _mesh(_capsule(0.2, 1.5), Vector3.ZERO, _quilt, Vector3(PI / 2.0, 0, 0), shape)
	body.scale = Vector3(1.0, 1.0, 0.95)   # (après rotation : x = largeur, z local = hauteur)
	var hip := _mesh(_capsule(0.17, 0.5), Vector3(0.03, 0.02, -0.45), _quilt, Vector3(PI / 2.0, 0, 0.2), shape)
	_shape_base = shape.scale
	# la tête sur l'oreiller : cheveux gris, chignon défait, filet ; on ne voit pas son visage
	var hair := _plain(Color(0.44, 0.42, 0.4), 1.0)
	var head := _mesh(_sphere(0.095, 16), Vector3(-0.17, 0.68, -3.0), hair)
	head.scale = Vector3(0.95, 0.9, 1.08)
	_mesh(_sphere(0.045, 10), Vector3(-0.1, 0.71, -2.94), hair)
	var net := _mesh(_sphere(0.098, 12), Vector3(-0.17, 0.685, -3.0), _plain(Color(0.3, 0.26, 0.3), 0.9))
	net.scale = Vector3(0.9, 0.5, 1.0)
	net.position.y += 0.04
	# le bras posé sur la couette, la manche de la chemise de nuit, la main
	var sleeve := _m(Color(0.66, 0.56, 0.6), 0.95)
	var skin := _plain(Color(0.7, 0.56, 0.5), 0.8)
	var arm_y := ARM_Y
	_mesh(_capsule(0.034, 0.36), Vector3(-0.07, arm_y, -3.38), sleeve, Vector3(PI / 2.0, 0.06, 0))
	_mesh(_capsule(0.026, 0.14), Vector3(-0.05, arm_y, -3.62), skin, Vector3(PI / 2.0, 0, 0))
	var hand := _mesh(_sphere(0.034, 10), Vector3(-0.045, arm_y - 0.005, -3.72), skin)
	hand.scale = Vector3(1.1, 0.5, 1.3)
	# le bracelet de téléassistance : bande noire, boîtier, LED verte (58 par minute)
	var band := TorusMesh.new()
	band.inner_radius = 0.027
	band.outer_radius = 0.036
	band.rings = 16
	band.ring_segments = 6
	_mesh(band, Vector3(-0.05, arm_y, -3.6), _plain(Color(0.06, 0.06, 0.07), 0.5), Vector3(PI / 2.0, 0, 0))
	_box(Vector3(0.03, 0.012, 0.036), BRACELET_POS + Vector3(0, -0.008, 0), _plain(Color(0.1, 0.1, 0.11), 0.35))
	bracelet_mat = _glow(Color(0.2, 1.0, 0.35), 0.4)
	var led := _no_gi(_mesh(_sphere(0.0045, 8), BRACELET_POS, bracelet_mat))
	led.name = "LedBracelet"
	bracelet_light = OmniLight3D.new()
	bracelet_light.name = "LueurBracelet"
	bracelet_light.light_color = Color(0.2, 1.0, 0.35)
	bracelet_light.light_energy = 0.0
	bracelet_light.omni_range = 0.35
	bracelet_light.shadow_enabled = false
	bracelet_light.position = BRACELET_POS + Vector3(0, 0.03, 0)
	bracelet_light.set_meta("always_on", true)
	add_child(bracelet_light)
	# ses chaussons, au pied de son côté
	var pink := _m(Color(0.6, 0.38, 0.42), 1.0)
	for k in 2:
		var sl := _mesh(_capsule(0.045, 0.26), Vector3(0.38 + k * 0.1, 0.025, -3.75 - k * 0.04), pink, Vector3(PI / 2.0, 0.25 + k * 0.2, 0))
		sl.scale = Vector3(1.0, 1.0, 0.5)


## Le pouls affiché par le bracelet et par CAM 3 (« ♥ 58 » ; la séance 2 le fait descendre à 52).
func set_heart(bpm: int) -> void:
	heart_bpm = maxi(1, bpm)
	if cam3:
		cam3.set_bpm(heart_bpm)
	if heart_bpm != 58 or Game.flags.has("pouls_henriette"):
		Game.set_flag("pouls_henriette", heart_bpm)    # gardé par la sauvegarde (restore)


## Rythme de la respiration de la forme (14 cycles par minute par défaut).
func set_breath(cycles_per_min: float) -> void:
	breath_cpm = maxf(1.0, cycles_per_min)


func _process(delta: float) -> void:
	if shape == null:
		return
	_breath_t += delta * breath_cpm / 60.0
	var b := sin(_breath_t * TAU)
	shape.scale = _shape_base * Vector3(1.0 + b * 0.012, 1.0 + b * 0.03, 1.0)
	_beat_t += delta * heart_bpm / 60.0
	var ph := fmod(_beat_t, 1.0)
	var k := 1.0 if ph < 0.12 else (0.5 if ph > 0.2 and ph < 0.28 else 0.0)
	bracelet_mat.emission_energy_multiplier = 0.35 + k * 5.0
	bracelet_light.light_energy = k * 0.05
	if cam3 and cam3_ir.visible != cam3.active:
		cam3_ir.visible = cam3.active


# ------------------------------------------------------------------ chevets, veilleuse

## Chevet Louis XV en bois sombre sculpté (Poly Haven ClassicNightstand_01, CC0), assorti au lit :
## dessus à 0,56, niche ouverte vers la pièce (−z), sol de la niche à NICHE_Y. Rend la hauteur du dessus.
func _nightstand(c: Vector3, node_name: String) -> float:
	var n := model("ClassicNightstand_01", c, 180.0, Vector3(0, NIGHTSTAND_TOP, 0), true,
		{"fit": "y", "name": node_name})
	return (n.get_meta("size") as Vector3).y


func _nightstands() -> void:
	# côté Henriette (x 0.55) : veilleuse, pilulier connecté, verre d'eau, lunettes, livre
	var top := _nightstand(Vector3(0.55, 0, -3.0), "ChevetHenriette")
	var pill := Node3D.new()
	pill.name = "Pilulier"
	add_child(pill)
	pill.position = Vector3(0.62, top, -3.08)
	pill.rotation.y = 0.18
	_box(Vector3(0.18, 0.035, 0.08), Vector3(0, 0.0175, 0), _new_white, false, pill)
	for k in 7:
		_box(Vector3(0.02, 0.002, 0.05), Vector3(-0.075 + k * 0.025, 0.036, 0.005), _plain(Color(0.35, 0.55, 0.85), 0.3), false, pill)
	_no_gi(_box(Vector3(0.006, 0.006, 0.003), Vector3(0.08, 0.022, -0.041), _glow(Color(0.2, 0.55, 1.0), 3.0), false, pill))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.8, 0.85, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	_mesh(_cyl(0.032, 0.028, 0.1, 14), Vector3(0.43, top + 0.05, -2.92), glass)
	_mesh(_cyl(0.029, 0.026, 0.06, 14), Vector3(0.43, top + 0.031, -2.92), _plain(Color(0.5, 0.55, 0.6), 0.1))
	_box_rot(Vector3(0.14, 0.025, 0.2), Vector3(0.6, top + 0.0125, -2.94), _m(Color(0.35, 0.18, 0.2), 0.8), -0.3)
	_box_rot(Vector3(0.11, 0.01, 0.03), Vector3(0.58, top + 0.031, -2.92), _plain(Color(0.25, 0.2, 0.15), 0.3, 0.5), 0.5)
	# la veilleuse : une chouette en céramique dans la niche du chevet, lumière orange
	var owl := Node3D.new()
	owl.name = "Veilleuse"
	add_child(owl)
	owl.position = Vector3(NIGHT_LIGHT_POS.x, NICHE_Y, NIGHT_LIGHT_POS.z)
	owl.rotation.y = 0.4        # elle regarde la pièce et le lit
	var ceramic := _plain(Color(1.0, 0.6, 0.25) * 0.5, 0.6)
	ceramic.emission_enabled = true
	ceramic.emission = Color(1.0, 0.5, 0.18)
	ceramic.emission_energy_multiplier = 1.6
	var ob := _no_gi(_mesh(_sphere(0.05, 12), Vector3(0, 0.07, 0), ceramic, Vector3.ZERO, owl))
	ob.scale = Vector3(0.9, 1.25, 0.85)
	_no_gi(_mesh(_sphere(0.036, 10), Vector3(0, 0.15, 0), ceramic, Vector3.ZERO, owl))
	for sx in [-1.0, 1.0]:
		_mesh(_sphere(0.009, 6), Vector3(sx * 0.014, 0.155, -0.03), _plain(Color(0.08, 0.05, 0.03), 0.4), Vector3.ZERO, owl)
		_mesh(_cyl(0.0, 0.008, 0.02, 4), Vector3(sx * 0.022, 0.19, 0), ceramic, Vector3.ZERO, owl)
	_cable([Vector3(NIGHT_LIGHT_POS.x + 0.02, NICHE_Y + 0.004, NIGHT_LIGHT_POS.z + 0.04), Vector3(NIGHT_LIGHT_POS.x + 0.02, NICHE_Y + 0.004, ZS - 0.03),
		Vector3(NIGHT_LIGHT_POS.x + 0.02, 0.24, ZS - 0.03)], Vector3.FORWARD, false)
	_socket_plug(Vector3(NIGHT_LIGHT_POS.x + 0.02, 0.26, ZS - 0.022))
	var nl := OmniLight3D.new()
	nl.name = "LumiereVeilleuse"
	nl.light_color = Color(1.0, 0.55, 0.22)
	nl.light_energy = 0.12
	nl.omni_range = 2.6
	nl.omni_attenuation = 1.3
	nl.shadow_enabled = false
	nl.position = NIGHT_LIGHT_POS
	nl.set_meta("always_on", true)    # CAM 3 la filme même quand la pièce n'est pas active
	add_child(nl)
	# côté Albert (x −1.75) : réveil mécanique, étui à lunettes, mots croisés ; il a tout laissé
	var top2 := _nightstand(Vector3(-1.75, 0, -3.0), "ChevetAlbert")
	var clock := Node3D.new()
	clock.name = "Reveil"
	add_child(clock)
	clock.position = Vector3(-1.8, top2, -2.95)
	clock.rotation.y = 0.35 - PI / 2.0     # le cadran vers l'oreiller d'Albert
	_mesh(_cyl(0.045, 0.045, 0.03, 18), Vector3(0, 0.055, 0), _m(Color(0.55, 0.5, 0.42), 0.35, 0.6), Vector3(PI / 2.0, 0, 0), clock)
	_mesh(_cyl(0.04, 0.04, 0.002, 18), Vector3(0, 0.055, -0.016), _plain(Color(0.85, 0.82, 0.72), 0.6), Vector3(PI / 2.0, 0, 0), clock)
	for sx in [-1.0, 1.0]:
		_mesh(_sphere(0.018, 8), Vector3(sx * 0.03, 0.1, 0), _m(Color(0.55, 0.5, 0.42), 0.35, 0.6), Vector3.ZERO, clock)
		_mesh(_cyl(0.004, 0.004, 0.02, 6), Vector3(sx * 0.03, 0.012, 0), _m(Color(0.3, 0.3, 0.3), 0.4, 0.6), Vector3.ZERO, clock)
	_box_rot(Vector3(0.16, 0.012, 0.03), Vector3(-1.66, top2 + 0.016, -3.08), _plain(Color(0.12, 0.1, 0.09), 0.5), 0.4)
	_box_rot(Vector3(0.21, 0.006, 0.28), Vector3(-1.72, top2 + 0.003, -3.06), _m(Color(0.75, 0.72, 0.62), 0.9), -0.15)


## Prise murale avec une fiche branchée (mur nord du lit, z = ZS : elle regarde −z).
func _socket_plug(pos: Vector3) -> void:
	_box(Vector3(0.075, 0.075, 0.012), pos + Vector3(0, 0, -0.006), _m(Color(0.72, 0.68, 0.58), 0.5))
	_box(Vector3(0.036, 0.042, 0.03), pos + Vector3(0, 0, -0.025), _new_white)


# ------------------------------------------------------------------ armoire, commode, chaise, tableau

func _furniture() -> void:
	# la chambre Henri II des grands-parents, en chêne sombre sculpté (modèles Poly Haven, CC0) : l'armoire
	# contre le mur nord (le modèle, un buffet deux corps de 1,02 m de fond, ramené à 0,67), la commode et
	# son miroir doré, la chaise où Albert pose ses habits
	var arm := model("GothicCabinet_01", Vector3(-1.75, 0, ZN + 0.015 + 0.3375), 0.0, Vector3(0, 1.96, 0), true, {"name": "Armoire"})
	arm.scale.z = 0.8
	var atop := (arm.get_meta("size") as Vector3).y
	# sur l'armoire : la boîte à chapeau d'Henriette et un carton
	var hat := _m(Color(0.5, 0.4, 0.36), 0.9)
	_mesh(_cyl(0.19, 0.19, 0.15, 24), Vector3(-2.1, atop + 0.075, -6.98), hat)
	_mesh(_cyl(0.197, 0.197, 0.035, 24), Vector3(-2.1, atop + 0.16, -6.98), _m(Color(0.36, 0.25, 0.22), 0.85))
	_box_rot(Vector3(0.52, 0.13, 0.36), Vector3(-1.42, atop + 0.065, -7.0), _m(Color(0.5, 0.41, 0.29), 0.95), 0.08)
	var com := prop("sideTableDrawers", Vector3(0.7, 0, ZN + 0.04 + 0.22), 0.0, Vector3(1.0, 0.82, 0.44))
	var ctop := (com.get_meta("size") as Vector3).y
	_no_shadow(model("ornate_mirror_01", Vector3(0.7, ctop + 0.12, ZN + 0.016), 0.0, Vector3.ZERO, false, {"name": "Miroir"}))
	# sur la commode : napperon, Vierge de Lourdes, coffret à bijoux, photo de mariage
	_mesh(_cyl(0.15, 0.15, 0.002, 28), Vector3(0.64, ctop + 0.001, ZN + 0.25), _plain(Color(0.8, 0.78, 0.72), 1.0))
	_virgin(Vector3(0.6, ctop + 0.002, ZN + 0.22))
	var casket := _m(Color(0.3, 0.1, 0.11), 0.55)
	_box_rot(Vector3(0.16, 0.05, 0.11), Vector3(0.42, ctop + 0.025, ZN + 0.31), casket, 0.12)
	_box_rot(Vector3(0.166, 0.022, 0.116), Vector3(0.42, ctop + 0.061, ZN + 0.31), _m(Color(0.38, 0.13, 0.14), 0.5), 0.12)
	var photo := StandardMaterial3D.new()
	photo.albedo_texture = _photo_texture()
	photo.roughness = 0.55
	photo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_photo_frame(Vector3(0.96, ctop, ZN + 0.27), -0.35, photo)
	prop("chair", Vector3(2.15, 0, -6.75), 200.0, Vector3(0.42, 0.88, 0.42))
	# sur la chaise (assise du modèle à 0,45), le pantalon et le gilet d'Albert, pliés
	_box_rot(Vector3(0.34, 0.04, 0.3), Vector3(2.15, 0.47, -6.74), _m(Color(0.22, 0.22, 0.26), 1.0), 0.3)
	_box_rot(Vector3(0.3, 0.05, 0.26), Vector3(2.16, 0.515, -6.73), _m(Color(0.42, 0.36, 0.28), 1.0), 0.15)
	prop("rugRectangle", Vector3(-0.6, 0.004, -5.45), 0.0, Vector3(2.0, 0.01, 1.2), false,
		{"carpet": Color(0.36, 0.26, 0.22), "carpetdarker": Color(0.2, 0.13, 0.12)})
	# la comtoise, contre le mur est (arrêtée) ; la berceuse d'Henriette près de la fenêtre, sous un
	# paysage dans un cadre doré
	model("vintage_grandfather_clock_01", Vector3(XE - 0.225, 0, -5.4), -90.0, Vector3.ZERO, true, {"name": "Comtoise"})
	model("Rockingchair_01", Vector3(-2.55, 0, -3.45), 100.0, Vector3.ZERO, true, {"name": "Berceuse"})
	_no_shadow(model("fancy_picture_frame_01", Vector3(XW + 0.012, 1.36, -3.5), 90.0, Vector3.ZERO, false, {"name": "Tableau"}))
	_curtains()
	# le plafonnier (éteint) et, au-dessus du lit, une broderie encadrée sous le crucifix
	# (sans ombre, comme celui de la chambre de ta mère : sous une lumière, ses bras faisaient de grandes
	# pales noires au plafond)
	var lamp := _no_shadow(prop("lampSquareCeiling", Vector3(-0.3, 0, -5.0), 0.0, Vector3(0, 0.34, 0), false))
	lamp.position.y = h - (lamp.get_meta("size") as Vector3).y
	var emb := _box(Vector3(0.62, 0.42, 0.025), Vector3(-0.6, 1.5, ZS - 0.0125), _m(Color(0.42, 0.3, 0.16), 0.5))
	emb.name = "Broderie"
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = _embroidery_texture()
	cloth.roughness = 1.0
	cloth.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_quad(Vector2(0.54, 0.34), Vector3(-0.6, 1.5, ZS - 0.0255), cloth, PI)
	_crucifix(Vector3(-0.6, 1.98, ZS))


## Cadre photo à poser (17 × 22 cm, laqué noir, passe-partout crème), incliné en arrière sur son
## chevalet ; « p » : milieu du pied du cadre, « yaw » : rotation (radians, 0 = la photo regarde +z).
## (Construit ici plutôt que le modèle Poly Haven : six textures de 1k à charger pour 20 cm de cadre.)
func _photo_frame(p: Vector3, yaw: float, photo: Material) -> void:
	var root := Node3D.new()
	root.name = "PhotoMariage"
	add_child(root)
	root.position = p
	root.rotation.y = yaw
	var tilt := Node3D.new()
	root.add_child(tilt)
	tilt.position = Vector3(0, 0, 0.006)
	tilt.rotation.x = -0.2
	var lacquer := _plain(Color(0.06, 0.05, 0.045), 0.3)
	var w := 0.17
	var hh := 0.22
	var b := 0.014
	_box(Vector3(w, b, 0.012), Vector3(0, b / 2.0, 0), lacquer, false, tilt)
	_box(Vector3(w, b, 0.012), Vector3(0, hh - b / 2.0, 0), lacquer, false, tilt)
	for sx in [-1.0, 1.0]:
		_box(Vector3(b, hh - 2.0 * b, 0.012), Vector3(sx * (w - b) / 2.0, hh / 2.0, 0), lacquer, false, tilt)
	_box(Vector3(w - 2.0 * b, hh - 2.0 * b, 0.003), Vector3(0, hh / 2.0, -0.004), _plain(Color(0.8, 0.77, 0.68), 0.9), false, tilt)
	var q := _quad(Vector2(w - 2.0 * b - 0.012, hh - 2.0 * b - 0.012), Vector3(0, hh / 2.0, -0.0015), photo, 0.0, tilt)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# le chevalet, derrière
	var leg := _box(Vector3(0.03, 0.162, 0.004), Vector3(0, 0.075, -0.06), lacquer, false, root)
	leg.rotation.x = 0.38


## Photo de mariage sépia dans un cache ovale : la mariée (robe et voile clairs) et Albert (costume sombre).
func _photo_texture() -> ImageTexture:
	var w := 36
	var hh := 48
	var img := Image.create_empty(w, hh, false, Image.FORMAT_RGB8)
	var shapes := [   # [centre, rayons, luminance] : du fond vers l'avant
		[Vector2(22.5, 34.0), Vector2(7.5, 16.0), 0.16],     # costume d'Albert
		[Vector2(22.0, 13.5), Vector2(3.2, 3.8), 0.66],      # son visage
		[Vector2(22.0, 10.8), Vector2(3.4, 1.8), 0.12],      # ses cheveux
		[Vector2(12.5, 23.0), Vector2(6.5, 12.0), 0.86],     # le voile
		[Vector2(12.5, 37.0), Vector2(9.5, 13.0), 0.9],      # la robe
		[Vector2(13.0, 14.5), Vector2(3.0, 3.6), 0.7],       # le visage d'Henriette
		[Vector2(15.5, 30.0), Vector2(3.0, 2.4), 0.38],      # le bouquet
	]
	for y in hh:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := (p - Vector2(w * 0.5, hh * 0.45)) / Vector2(w * 0.5, hh * 0.55)
			var l := 0.58 - 0.2 * d.length_squared()
			for sh in shapes:
				var q := (p - (sh[0] as Vector2)) / (sh[1] as Vector2)
				if q.length_squared() <= 1.0:
					l = sh[2]
			l += rng.randf_range(-0.03, 0.03)
			var c := Color(l * 1.06, l * 0.9, l * 0.68)
			# cache ovale crème autour du portrait
			var o := (p - Vector2(w * 0.5, hh * 0.5)) / Vector2(w * 0.46, hh * 0.46)
			if o.length_squared() > 1.0:
				c = Color(0.84, 0.8, 0.7)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Vierge de Lourdes en plâtre peint (souvenir de pèlerinage), 15 cm, posée en « p ».
func _virgin(p: Vector3) -> void:
	var white := _plain(Color(0.82, 0.8, 0.74), 0.4)
	var blue := _plain(Color(0.3, 0.42, 0.66), 0.4)
	_mesh(_cyl(0.03, 0.032, 0.016, 16), p + Vector3(0, 0.008, 0), _plain(Color(0.42, 0.44, 0.4), 0.6))
	_mesh(_cyl(0.013, 0.025, 0.11, 14), p + Vector3(0, 0.071, 0), white)
	_mesh(_cyl(0.0145, 0.0185, 0.012, 14), p + Vector3(0, 0.085, 0), blue)        # la ceinture bleue
	_mesh(_sphere(0.0125, 10), p + Vector3(0, 0.137, 0.002), _plain(Color(0.78, 0.66, 0.58), 0.45))
	var veil := _mesh(_sphere(0.0165, 10), p + Vector3(0, 0.139, -0.004), white)
	veil.scale = Vector3(1.0, 1.15, 0.9)
	for sx in [-1.0, 1.0]:    # mains jointes
		_mesh(_capsule(0.005, 0.045), p + Vector3(sx * 0.008, 0.108, 0.016), white, Vector3(0.5, 0, sx * 0.35))


## Crucifix de bois noirci et Christ de laiton, avec le rameau de buis des Rameaux glissé derrière ;
## « c » : centre de la croix, sur le mur de la tête du lit (z = ZS, il regarde −z).
func _crucifix(c: Vector3) -> void:
	var z := ZS - 0.008
	var wood: Material = mats.wood_dark
	_box(Vector3(0.026, 0.34, 0.014), Vector3(c.x, c.y, z), wood)
	_box(Vector3(0.2, 0.026, 0.014), Vector3(c.x, c.y + 0.075, z), wood)
	var brass := _plain(Color(0.6, 0.5, 0.32), 0.45, 0.8)
	var zc := ZS - 0.019
	_mesh(_capsule(0.0085, 0.12), Vector3(c.x, c.y + 0.0, zc), brass)
	_mesh(_sphere(0.0095, 8), Vector3(c.x + 0.003, c.y + 0.066, zc - 0.002), brass)
	for sx in [-1.0, 1.0]:
		_mesh(_capsule(0.0042, 0.09), Vector3(c.x + sx * 0.042, c.y + 0.064, zc), brass, Vector3(0, 0, sx * (PI / 2.0 - 0.32)))
	# le buis, quelques feuilles sombres en éventail derrière la traverse
	var leaf := _plain(Color(0.12, 0.2, 0.1), 0.7)
	for k in 9:
		var a := -0.9 + k * 0.22 + rng.randf_range(-0.06, 0.06)
		var l := 0.09 + rng.randf_range(-0.02, 0.02)
		var b := _box(Vector3(0.012, l, 0.003), Vector3(c.x + 0.03 + sin(a) * l * 0.5, c.y + 0.11 + cos(a) * l * 0.5, ZS - 0.003), leaf)
		b.rotation.z = -a


## Rideaux de velours bordeaux passé, ouverts, et leur tringle de laiton, devant la fenêtre F2 (mur
## ouest, x = −3.25, z −5.0) : ils tombent jusqu'au sol, devant l'appui (qui avance jusqu'à x −3.02).
func _curtains() -> void:
	var x := XW + 0.2
	var top := 2.35
	var brass := _plain(Color(0.55, 0.45, 0.28), 0.4, 0.8)
	_mesh(_cyl(0.011, 0.011, 2.12, 10), Vector3(x, top + 0.02, -5.0), brass, Vector3(PI / 2.0, 0, 0))
	for sz in [-1.0, 1.0]:
		_mesh(_sphere(0.022, 10), Vector3(x, top + 0.02, -5.0 + sz * 1.075), brass)
		_box(Vector3(0.2, 0.014, 0.014), Vector3(XW + 0.1, top + 0.02, -5.0 + sz * 0.98), brass)
	# (une matière ordinaire de la maison : couleur et crasse, pas de nouvelle variante de shader)
	var velvet := _m(Color(0.34, 0.12, 0.12), 0.9)
	var drape := _drape(0.42, top - 0.015, 5.5)
	for sz in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.name = "Rideau"
		mi.mesh = drape
		mi.material_override = velvet
		mi.position = Vector3(x, top, -5.0 + sz * 0.83)
		add_child(mi)


## Pan de tissu plissé qui tombe droit, vu depuis +x (repère local : haut du pan au centre, largeur
## « width » le long de z, hauteur « hh » vers le bas, « folds » plis). Deux faces (le dos décalé de
## 4 mm) : pas de matière double face, qui coûte cher en rendu logiciel. Normales calculées.
func _drape(width: float, hh: float, folds: float) -> ArrayMesh:
	var nu := 30
	var nv := 6
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var k1 := TAU * folds
	for side in 2:
		var sgn := 1.0 if side == 0 else -1.0
		for j in nv + 1:
			var v := float(j) / nv
			var amp := 0.026 + 0.014 * v
			for i in nu + 1:
				var u := float(i) / nu
				var a1 := u * k1 + 0.6
				var a2 := u * k1 * 2.3
				var f := sin(a1) * amp + sin(a2) * amp * 0.25
				var df := (cos(a1) * k1 * amp + cos(a2) * k1 * 2.3 * amp * 0.25) / width
				verts.append(Vector3(f - 0.004 * side, -hh * v, width * (0.5 - u)))
				norms.append(Vector3(1.0, 0.0, df).normalized() * sgn)
				uvs.append(Vector2(u, v))
		var base := side * (nu + 1) * (nv + 1)
		for j in nv:
			for i in nu:
				var a := base + j * (nu + 1) + i
				var c := a + nu + 1
				# face avant (vers +x) dans le sens horaire vue de +x ; le dos à l'envers
				if side == 0:
					idx.append_array([a, a + 1, c, a + 1, c + 1, c])
				else:
					idx.append_array([a, c, a + 1, a + 1, c, c + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Canevas brodé au point de croix : une maison, un arbre, « 1974 ».
func _embroidery_texture() -> ImageTexture:
	var img := Image.create_empty(54, 34, false, Image.FORMAT_RGB8)
	img.fill(Color(0.82, 0.78, 0.66))
	var red := Color(0.62, 0.2, 0.2)
	var green := Color(0.3, 0.45, 0.28)
	var brown := Color(0.45, 0.3, 0.18)
	for x in 54:
		img.set_pixel(x, 1, red)
		img.set_pixel(x, 32, red)
	for y in 34:
		img.set_pixel(1, y, red)
		img.set_pixel(52, y, red)
	img.fill_rect(Rect2i(12, 14, 14, 10), Color(0.8, 0.7, 0.55))
	for k in 8:
		img.fill_rect(Rect2i(10 + k, 13 - k, 18 - k * 2, 1), red)
	img.fill_rect(Rect2i(17, 18, 4, 6), brown)
	img.fill_rect(Rect2i(14, 16, 2, 2), Color(0.3, 0.4, 0.6))
	img.fill_rect(Rect2i(23, 16, 2, 2), Color(0.3, 0.4, 0.6))
	img.fill_rect(Rect2i(36, 16, 2, 8), brown)
	for y in range(6, 17):
		var half := 6 - absi(y - 11)
		img.fill_rect(Rect2i(37 - half, y, half * 2 + 1, 1), green)
	img.fill_rect(Rect2i(4, 24, 46, 1), green)
	FeedCam.draw_text(img, "1974", Vector2i(19, 26), 1, Color(0.3, 0.3, 0.5))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ CAM 3

## La caméra de l'assurance, au plafond, dans l'angle nord-est : boîtier blanc, objectif, couronne de
## LED infrarouges (rouge sombre), et son flux (CAM 3) en noir et blanc, « ♥ 58 » incrusté.
func _camera() -> void:
	var stem_top := Vector3(CAM_POS.x, h, CAM_POS.z)
	_mesh(_cyl(0.035, 0.04, 0.012, 16), stem_top + Vector3(0, -0.006, 0), _new_white)
	_mesh(_cyl(0.008, 0.008, h - CAM_POS.y - 0.04, 8), Vector3(CAM_POS.x, (h + CAM_POS.y + 0.04) / 2.0, CAM_POS.z), _new_white)
	var body := Node3D.new()
	body.name = "Camera3"
	add_child(body)
	body.position = CAM_POS
	body.look_at(CAM_AIM)
	_box(Vector3(0.07, 0.07, 0.1), Vector3(0, 0, 0.01), _new_white, false, body)
	_mesh(_cyl(0.026, 0.026, 0.012, 16), Vector3(0, 0, -0.045), _plain(Color(0.03, 0.03, 0.04), 0.3), Vector3(PI / 2.0, 0, 0), body)
	var lens := _plain(Color(0.02, 0.03, 0.06), 0.05)
	lens.metallic_specular = 1.0
	_mesh(_cyl(0.011, 0.011, 0.004, 16), Vector3(0, 0, -0.052), lens, Vector3(PI / 2.0, 0, 0), body)
	var ir := _glow(Color(0.5, 0.02, 0.02), 1.2)
	for k in 8:
		var a := TAU * k / 8.0
		_no_gi(_mesh(_sphere(0.003, 6), Vector3(cos(a) * 0.019, sin(a) * 0.019, -0.052), ir, Vector3.ZERO, body))
	# son câble : au plafond jusqu'au mur est, puis descend dans l'angle jusqu'à la prise
	var cy := h - 0.0035
	_cable([Vector3(CAM_POS.x + 0.04, cy, CAM_POS.z), Vector3(XE - 0.004, cy, CAM_POS.z)], Vector3.DOWN)
	_cable([Vector3(XE - 0.004, h - 0.13, CAM_POS.z), Vector3(XE - 0.004, 0.3, CAM_POS.z)], Vector3.LEFT)
	_box(Vector3(0.012, 0.075, 0.075), Vector3(XE - 0.006, 0.26, CAM_POS.z), _m(Color(0.72, 0.68, 0.58), 0.5))
	_box(Vector3(0.03, 0.042, 0.036), Vector3(XE - 0.025, 0.26, CAM_POS.z), _new_white)
	cam3 = HeartCam.new()
	cam3.name = "CamFlux3"
	cam3.title = "CAM 3 CHAMBRE 1"
	cam3.ir = 1.3
	cam3.exposure = 1.5
	cam3.fov = 40.0
	cam3.bpm = heart_bpm
	add_child(cam3)
	cam3.position = CAM_POS + (CAM_AIM - CAM_POS).normalized() * 0.06
	cam3.look_at(CAM_AIM)
	cam3.build()
	# l'éclairage infrarouge de la caméra (allumé seulement quand elle filme)
	cam3_ir = SpotLight3D.new()
	cam3_ir.name = "InfrarougeCam3"
	cam3_ir.light_color = Color(0.85, 0.88, 1.0)
	cam3_ir.light_energy = 1.6
	cam3_ir.spot_range = 9.0
	cam3_ir.spot_angle = 26.0
	cam3_ir.spot_attenuation = 0.7
	cam3_ir.shadow_enabled = false
	cam3_ir.visible = false
	cam3_ir.set_meta("always_on", true)
	add_child(cam3_ir)
	cam3_ir.position = cam3.position
	cam3_ir.look_at(CAM_AIM)


# ------------------------------------------------------------------ la clé dans la serrure

## Henriette s'enferme à clé : la clé est restée dans la serrure de P2, côté chambre.
func _key_in_lock() -> void:
	if house == null or not house.doors.has("P2"):
		return
	var d: Door = house.doors["P2"]
	if d.leaf == null:
		return
	var dir := 1.0 if d.hinge_left else -1.0
	var face := 0.045 / 2.0 + 0.006
	var brass := _plain(Color(0.6, 0.48, 0.24), 0.35, 0.8)
	var key := Node3D.new()
	key.name = "CleP2"
	d.leaf.add_child(key)
	key.position = Vector3(dir * (d.width - 0.075), 0.9, d.swing * face)
	_box(Vector3(0.016, 0.03, 0.004), Vector3(0, 0, d.swing * 0.002), _plain(Color(0.4, 0.36, 0.3), 0.4, 0.7), false, key)
	_box(Vector3(0.004, 0.006, 0.03), Vector3(0, 0, d.swing * 0.017), brass, false, key)
	var bow := TorusMesh.new()
	bow.inner_radius = 0.008
	bow.outer_radius = 0.014
	bow.rings = 12
	bow.ring_segments = 6
	_mesh(bow, Vector3(0, 0, d.swing * 0.04), brass, Vector3(0, PI / 2.0, PI / 2.0), key)


# ------------------------------------------------------------------ sauvegarde

## Réapplique l'état après un chargement (le pouls, s'il a déjà été changé par la séance 2).
func restore() -> void:
	var bpm: Variant = Game.flag("pouls_henriette", null)
	if bpm != null:
		set_heart(int(bpm))
