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
	# (la couette ne respire à l'écran que si on la voit : pièce active ou CAM 3 regardée ; sinon pas de
	# mise à jour de matière à chaque image)
	if not _breath_mats.is_empty() and (active or (cam3 != null and cam3.active)):
		for bm in _breath_mats:
			(bm as ShaderMaterial).set_shader_parameter("breath", b)
	if not _pending.is_empty():
		_poll_pending()
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


# ------------------------------------------------------------------ habillage (passe « triple A », lot V2-GP)
#
# Vraie carte seulement (Main._after_build appelle dress_details() après la mesure de B16 si
# Qualite.details_on()) : en rendu logiciel, la chambre reste celle de la 0.3.3, nœud pour nœud. Les objets
# remplacés restent dans l'arbre, cachés (« la couette », la forme en capsules, la chouette en sphères, les
# rideaux plats, le cadre photo fait main) : les noms, la forme qui respire (shape), le bracelet et sa LED
# ne bougent pas. Aucun tirage aléatoire (rng n'est pas touché), aucune collision.
#
# Henriette dort sur le côté, tournée vers la place vide d'Albert (ouest) : CAM 3, dans l'angle nord-est, ne
# voit que son dos sous la couette remontée jusqu'à l'oreille, l'arrière de sa tête (cheveux gris, chignon)
# enfoncée dans l'oreiller, et sa main posée sur sa hanche, au bracelet qui clignote. Aucun visage n'est
# modélisé (GDD : pas de visage humain généré).

const TEX_DIR := "res://assets/textures/gp/"
## Couvre-lit matelassé (couette_albedo/normal.jpg, tools : aaa_fab/V2-GP/outils/gen_gp.py) : une répétition
## de 0,56 m (4 losanges de 10 cm de côté par côté de tuile).
const COUETTE_TILE := 0.56
## Respiration de la couette (m, le long de la normale, au plus fort de l'inspiration) : la forme d'avant
## (capsules, échelle 1,03 en hauteur sur 0,2 m de rayon) bougeait de 6 mm.
const BREATH_AMP := 0.007
## Le corps sous la couette, de l'épaule aux pieds : [z, centre en x, hauteur au-dessus du lit, demi-largeur].
## Couchée sur le côté (la largeur des hanches à la verticale), genoux un peu repliés vers la place d'Albert.
const BODY := [
	[-3.20, -0.14, 0.19, 0.17], [-3.42, -0.12, 0.165, 0.16], [-3.62, -0.10, 0.15, 0.15],
	[-3.95, -0.11, 0.21, 0.18], [-4.15, -0.20, 0.155, 0.14], [-4.32, -0.31, 0.12, 0.12],
	[-4.50, -0.25, 0.10, 0.11], [-4.63, -0.16, 0.09, 0.10],
]
## Bord haut de la couette du côté d'Henriette : sur l'oreiller (DUVET_TOP_H), remontée jusqu'à l'oreille
## autour de son épaule (DUVET_TOP_EAR, en x = HEAD_C.x) ; côté d'Albert, rabattue en biais.
const DUVET_TOP_H := -3.17
const DUVET_TOP_EAR := -3.03
const DUVET_TOP_A := -3.78
## Sa tête sur l'oreiller (centre) et l'arrière de son crâne (vers l'est et le haut : vers CAM 3) ; le
## visage, de l'autre côté, est enfoncé dans l'oreiller (aucun visage n'est modélisé).
const HEAD_C := Vector3(-0.19, 0.636, -2.985)
const BACK_DIR := Vector3(0.55, 0.7, 0.1)
const HAIR_TINT := Color(0.84, 0.82, 0.79)
const SKIN := Color(0.74, 0.58, 0.52)

const BREATH_SHADER := """
shader_type spatial;
render_mode cull_back;
// Couvre-lit matelassé (vraie carte) : coton satiné imprimé, piqûres en losanges (normale), plis ombrés
// (COLOR.g), respiration (COLOR.r : poids, uniform breath de -1 à 1).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_depth = 0.8;
uniform float rough = 0.78;
uniform float sheen = 0.3;
uniform float breath = 0.0;
uniform float breath_amp = 0.007;
void vertex() {
	VERTEX += NORMAL * (breath * 0.5 + 0.5) * COLOR.r * breath_amp;
}
void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb * mix(0.55, 1.0, COLOR.g);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	RIM = sheen;
	RIM_TINT = 0.7;
	AO = COLOR.g;
	AO_LIGHT_AFFECT = 0.4;
}
"""

const OWL_SHADER := """
shader_type spatial;
// Veilleuse en porcelaine émaillée, éclairée de l'intérieur : la paroi brille plus là où on la voit de
// face et à mi-hauteur (plus mince), moins au pied et sur les bords.
uniform vec3 glaze : source_color = vec3(0.96, 0.8, 0.6);
uniform vec3 glow : source_color = vec3(1.0, 0.52, 0.2);
uniform float energy = 1.7;
varying float hy;
void vertex() {
	hy = VERTEX.y;
}
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float body = smoothstep(0.0, 0.035, hy) * (1.0 - 0.45 * smoothstep(0.1, 0.15, hy));
	ALBEDO = glaze * 0.35;
	ROUGHNESS = 0.22;
	SPECULAR = 0.6;
	EMISSION = glow * energy * body * (0.2 + 0.8 * pow(facing, 1.6));
}
"""

var _breath_mat: ShaderMaterial   # couette HD (vraie carte) : la respiration passe par son shader
var _breath_mats: Array = []      # matières qui respirent (uniform « breath ») : la couette HD
var _extra_casters: Array = []    # nœuds ajoutés sous des nœuds de furnish() (ombres à inscrire)
var _mattress := 0.445            # dessus du matelas (boîte « cover » du lit), relevé par _dress_bed
var _pending: Array = []          # [support, Callable] : objets de détail chargés en arrière-plan, à finir


func dress_details() -> void:
	var t0 := Time.get_ticks_usec()
	var n0 := get_child_count()
	_extra_casters.clear()
	var steps := [_dress_bed, _dress_night_light, _dress_nightstands, _dress_commode, _dress_room, _dress_curtains, _wear_room]
	var ms := []
	for f in steps:
		var t1 := Time.get_ticks_usec()
		(f as Callable).call()
		ms.append((Time.get_ticks_usec() - t1) / 1000)
	# (les ombres de ces objets suivent celles des meubles : coupées quand le joueur n'est pas là)
	for i in range(n0, get_child_count()):
		var c := get_child(i)
		if c.has_meta("ph_id") and not c.has_meta("ready"):
			_when_ready(c as Node3D, Callable())     # (modèle pas encore posé : ses ombres plus tard)
		else:
			_add_casters(c)
	for n in _extra_casters:
		_add_casters(n)
	if Game.autotest:
		print("ÉTAGE gp habillé en %d ms (lit, veilleuse, chevets, commode, pièce, rideaux, usure : %s)" % [(Time.get_ticks_usec() - t0) / 1000, ms])


## Quand le modèle d'un objet de détail est posé (méta « ready ») : « cb » (support), puis ses ombres
## inscrites dans _casters. Tout de suite s'il l'est déjà ; sinon _process le surveille.
func _when_ready(holder: Node3D, cb: Callable) -> void:
	if holder == null:
		return
	for e in _pending:
		if e[0] == holder:
			if cb.is_valid():
				e[1] = cb
			return
	if holder.has_meta("ready"):
		if cb.is_valid():
			cb.call(holder)
		_add_casters(holder)
		return
	_pending.append([holder, cb])


func _poll_pending() -> void:
	var i := 0
	while i < _pending.size():
		var e: Array = _pending[i]
		var h: Node3D = e[0]
		if not is_instance_valid(h):
			_pending.remove_at(i)
			continue
		if h.has_meta("ready"):
			_pending.remove_at(i)
			var cb: Callable = e[1]
			if cb.is_valid():
				cb.call(h)
			_add_casters(h)
			continue
		i += 1


## Inscrit les instances de « root » qui portent une ombre dans _casters (et l'éteint tout de suite si les
## ombres de la chambre sont coupées).
func _add_casters(root: Node) -> void:
	if root == null:
		return
	var geos: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		geos.append(root)
	for g in geos:
		var gi := g as GeometryInstance3D
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_casters.append([gi, gi.cast_shadow])
			if not _casting:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Enfant direct de la pièce (MeshInstance3D) posé en « p » : les objets sans nom de furnish(), à cacher.
func _old_at(p: Vector3, tol := 0.003) -> MeshInstance3D:
	for c in get_children():
		var mi := c as MeshInstance3D
		if mi and mi.position.distance_to(p) < tol:
			return mi
	return null


func _hide_old(p: Vector3) -> void:
	var mi := _old_at(p)
	if mi:
		mi.visible = false


func _tex_mat(file: String, tint := Color.WHITE, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(file):
		m.albedo_texture = load(file)
	m.albedo_color = tint
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Tissu Poly Haven (velour_velvet, cotton_jersey…) : albédo teinté et normale, « meters » m par motif
## (sur des UV en mètres).
func _fabric(id: String, tint: Color, meters: float, rough := 0.85, normal := 1.0) -> StandardMaterial3D:
	var dir := "res://assets/textures/%s/%s_" % [id, id]
	var m := _tex_mat(dir + "albedo.jpg", tint, rough)
	if ResourceLoader.exists(dir + "normal_gl.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(dir + "normal_gl.jpg")
		m.normal_scale = normal
	m.uv1_scale = Vector3(1.0 / meters, 1.0 / meters, 1.0)
	return m


func _mi(mesh: Mesh, mat: Material, parent: Node3D, xf := Transform3D.IDENTITY, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if node_name != "":
		mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ le lit, Henriette

func _dress_bed() -> void:
	var bed := props.get("bedDouble") as Node3D
	if bed == null:
		return
	var cover := bed.find_child("cover", true, false) as Node3D
	var top := _aabb_of(cover if cover else bed, self).end.y
	var bed_box := _aabb_of(bed, self)
	var base := top + 0.06
	_mattress = top
	var old := get_node_or_null("Couette") as Node3D
	if old:
		old.visible = false
	# la forme d'avant (capsules : corps, hanche) ; sa tête, son chignon, son filet ; le bras, la main ; les
	# chaussons (elle reste : « shape » respire toujours, invisible)
	for c in shape.get_children():
		(c as Node3D).visible = false
	for p in [Vector3(-0.17, 0.68, -3.0), Vector3(-0.1, 0.71, -2.94), Vector3(-0.17, 0.725, -3.0),
			Vector3(-0.07, ARM_Y, -3.38), Vector3(-0.05, ARM_Y, -3.62), Vector3(-0.045, ARM_Y - 0.005, -3.72),
			Vector3(0.38, 0.025, -3.75), Vector3(0.48, 0.025, -3.79)]:
		_hide_old(p)
	var sleeper := Node3D.new()
	sleeper.name = "Henriette"
	add_child(sleeper)
	_duvet_hd(bed_box.position.x + 0.02, bed_box.end.x - 0.02, bed_box.position.z + 0.15, base, sleeper)
	_pillow_hd(top, sleeper)
	_head(sleeper)
	_arm(base, sleeper)
	_slippers()


## Hauteur du corps sous la couette au-dessus de son plan de base (m), en (x, z) de la pièce.
func _hump(x: float, z: float) -> float:
	var b: Array = BODY
	var s: Array = b[0]
	if z >= float(s[0]):
		return float(s[2]) * _hump_x(x, float(s[1]), float(s[3]))
	for i in b.size() - 1:
		var a: Array = b[i]
		var c: Array = b[i + 1]
		if z <= float(a[0]) and z >= float(c[0]):
			var t := smoothstep(0.0, 1.0, (float(a[0]) - z) / (float(a[0]) - float(c[0])))
			return lerpf(float(a[2]), float(c[2]), t) * _hump_x(x, lerpf(float(a[1]), float(c[1]), t), lerpf(float(a[3]), float(c[3]), t))
	var e: Array = b[b.size() - 1]
	var fall := exp(-pow((float(e[0]) - z) / 0.1, 2.0))
	return float(e[2]) * fall * _hump_x(x, float(e[1]), float(e[3]))


## _hump, plus le pli de la couette sur le haut du bras (pour la couette seulement).
func _hump_duvet(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var d := Geometry2D.get_closest_point_to_segment(q, UPPER_ARM_A, UPPER_ARM_B).distance_to(q)
	return _hump(x, z) + 0.03 * exp(-pow(d / 0.05, 2.0))


## Le haut du bras d'Henriette, sous la couette, de l'épaule au point où la manche sort.
const UPPER_ARM_A := Vector2(-0.14, -3.13)
const UPPER_ARM_B := Vector2(-0.1, -3.25)


func _hump_x(x: float, cx: float, w: float) -> float:
	return exp(-pow(absf(x - cx) / (0.85 * w), 3.2))


## Poids de la respiration (0 à 1) en (x, z) : l'épaule et les côtes, pas sous l'avant-bras (le bras ne
## respire pas).
func _breath_w(x: float, z: float) -> float:
	var chest := exp(-pow((z + 3.36) / 0.2, 2.0)) * _hump_x(x, -0.13, 0.2)
	var q := Vector2(x, z)
	var d_arm := Geometry2D.get_closest_point_to_segment(q, Vector2(-0.06, -3.45), Vector2(-0.07, -3.76)).distance_to(q)
	return clampf(chest * (1.0 - 0.95 * exp(-pow(d_arm / 0.06, 2.0))), 0.0, 1.0)


## Hauteur de la couette (sans le bruit des plis), pour y poser le bras et la main.
func _surf(base: float, x: float, z: float) -> float:
	return base + _hump(x, z)


func _surf_normal(base: float, x: float, z: float) -> Vector3:
	var e := 0.01
	var dx := (_surf(base, x + e, z) - _surf(base, x - e, z)) / (2.0 * e)
	var dz := (_surf(base, x, z + e) - _surf(base, x, z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()


## Couvre-lit matelassé HD : la couette d'avant (mêmes bords, même rabat côté Albert), plus fine (68 × 64),
## modelée sur le corps d'Henriette (BODY) jusqu'à l'oreille ; plis ombrés et poids de respiration en
## couleur de sommet ; UV en mètres / COUETTE_TILE.
func _duvet_hd(x0: float, x1: float, z_foot: float, base: float, parent: Node3D) -> void:
	var hang := 0.3
	var hang_foot := 0.06
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 1.5
	var nx := 68
	var nz := 64
	var w := x1 - x0
	var cx := (x0 + x1) / 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var s := lerpf(-w / 2.0 - hang, w / 2.0 + hang, float(i) / nx)
			var xs := clampf(cx + s, x0, x1)
			var k_albert := smoothstep(-0.45, -0.8, xs)
			var z_h := lerpf(DUVET_TOP_H, DUVET_TOP_EAR, exp(-pow((xs - HEAD_C.x) / 0.17, 2.0)))
			var z_top := lerpf(z_h, DUVET_TOP_A, k_albert)
			var v := float(j) / nz
			var z := lerpf(z_foot - hang_foot, z_top, v)
			var x := cx + s
			var y := base
			var over := absf(s) - w / 2.0
			if over > 0.0:
				x = cx + signf(s) * (w / 2.0 + 0.025 + over * 0.12)
				y -= over * 1.05
			var over_z := z_foot - z
			if over_z > 0.0:
				z = z_foot - 0.025 - over_z * 0.12
				y -= over_z * 1.05
			var hb := _hump_duvet(xs, z) if over <= 0.0 else _hump(xs, z) * maxf(0.0, 1.0 - over / 0.08)
			y += hb
			# le rabat d'Albert : un bourrelet le long du bord replié
			var edge := absf(z - z_top)
			var roll := k_albert * exp(-pow(edge / 0.07, 2.0)) * 0.06
			y += roll
			# plis : moins sur le corps (le tissu y est tendu)
			var body_k := clampf(hb / 0.12, 0.0, 1.0)
			var nz_ := noise.get_noise_2d(x * 1.3, z * 1.3)
			y += nz_ * 0.026 * (1.0 - 0.75 * body_k)
			# au-dessus de l'oreiller ; puis le bord épais de la couette (un ourlet roulé, qui rentre dessous)
			if z > -3.24 and xs > -0.63 and xs < 0.09:
				y = maxf(y, _pillow_y(xs, z, true, _mattress) + 0.01)
			if j == nz - 1:
				y += 0.008
			elif j == nz:
				y -= 0.022
				z += 0.004
			x += noise.get_noise_2d(z * 4.0, x * 4.0) * 0.006
			var chest := _breath_w(xs, z)
			# occlusion des plis : creux du bruit, pied du corps, dessous du rabat
			var occ := clampf(0.86 + nz_ * 0.35, 0.55, 1.0)
			occ *= 1.0 - 0.25 * smoothstep(0.05, 0.25, over)
			st.set_color(Color(clampf(chest, 0.0, 1.0), occ, 0.0))
			st.set_uv(Vector2(s / COUETTE_TILE, z / COUETTE_TILE))
			st.add_vertex(Vector3(x, y, z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			for k in [a, b, c, b, d, c]:
				st.add_index(k)
	st.generate_normals()
	st.generate_tangents()
	_breath_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BREATH_SHADER
	_breath_mat.shader = sh
	_breath_mat.set_shader_parameter("albedo_tex", load(TEX_DIR + "couette_albedo.jpg"))
	_breath_mat.set_shader_parameter("normal_tex", load(TEX_DIR + "couette_normal.jpg"))
	_breath_mat.set_shader_parameter("breath_amp", BREATH_AMP)
	_breath_mats.append(_breath_mat)
	var mi := _mi(st.commit(), _breath_mat, parent, Transform3D.IDENTITY, "CouetteHD")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


const PILLOW_C := Vector3(-0.27, 0.0, -3.02)
const PILLOW_W := 0.7
const PILLOW_D := 0.41
const PILLOW_T := 0.19


func _pillow_y(x: float, z: float, top_side: bool, mattress := 0.445) -> float:
	var u := clampf((x - PILLOW_C.x) / (PILLOW_W / 2.0), -1.0, 1.0)
	var v := clampf((z - PILLOW_C.z) / (PILLOW_D / 2.0), -1.0, 1.0)
	var puff := (1.0 - pow(absf(u), 3.0)) * (1.0 - pow(absf(v), 3.0))
	var seam := mattress + PILLOW_T * 0.42
	if not top_side:
		return seam - PILLOW_T * 0.42 * pow(puff, 0.8)
	var dent := 0.05 * exp(-pow((x - HEAD_C.x) / 0.1, 2.0) - pow((z - HEAD_C.z) / 0.085, 2.0))
	return seam + PILLOW_T / 2.0 * pow(puff, 0.55) - dent


## L'oreiller d'Henriette, en coton blanc cassé, creusé par sa tête (il recouvre celui du modèle).
func _pillow_hd(mattress: float, parent: Node3D) -> void:
	var n := 22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var basev := 0
	for side in [1.0, -1.0]:
		for j in n + 1:
			for i in n + 1:
				var u := -1.0 + 2.0 * i / n
				var v := -1.0 + 2.0 * j / n
				var pinch := 1.0 - 0.05 * absf(u * v)
				var x := PILLOW_C.x + u * PILLOW_W / 2.0 * pinch
				var z := PILLOW_C.z + v * PILLOW_D / 2.0 * pinch
				var y := _pillow_y(x, z, side > 0.0, mattress)
				st.set_uv(Vector2(x / 0.26, z / 0.26))
				st.add_vertex(Vector3(x, y, z))
		for j in n:
			for i in n:
				var a := basev + j * (n + 1) + i
				var b := a + 1
				var c := a + n + 1
				var e := c + 1
				var tri: Array = [a, b, c, b, e, c] if side > 0.0 else [a, c, b, b, c, e]
				for k in tri:
					st.add_index(k)
		basev += (n + 1) * (n + 1)
	st.generate_normals()
	st.generate_tangents()
	var m := _plain(Color(0.8, 0.78, 0.74), 0.9)
	var nrm := "res://assets/textures/cotton_jersey/cotton_jersey_normal_gl.jpg"
	if ResourceLoader.exists(nrm):
		m.normal_enabled = true
		m.normal_texture = load(nrm)
		m.normal_scale = 0.6
	var pm := _mi(st.commit(), m, parent, Transform3D.IDENTITY, "OreillerHenriette")
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## La tête d'Henriette, de dos : un crâne couvert de cheveux gris tirés vers le chignon (les mèches suivent
## les méridiens, qui se rejoignent au chignon), le visage tourné vers l'ouest et dans l'oreiller.
func _head(parent: Node3D) -> void:
	var hair := _tex_mat(TEX_DIR + "cheveux.png", HAIR_TINT, 0.55)
	hair.uv1_scale = Vector3(16.0, 1.0, 1.0)
	hair.rim_enabled = true
	hair.rim = 0.35
	hair.rim_tint = 0.4
	# repère du crâne : y = vers le chignon (arrière du crâne, vers le sommet), z = vers le sommet, x = d'une
	# oreille à l'autre ; les mèches (méridiens de la sphère) partent du front (dans l'oreiller) au chignon
	var back := BACK_DIR.normalized()
	var crown0 := (Vector3.BACK - back * back.dot(Vector3.BACK)).normalized()
	var b := (back * 0.8 + crown0 * 0.45).normalized()
	var third := (crown0 - b * b.dot(crown0)).normalized()
	var ear := b.cross(third).normalized()
	var root := Node3D.new()
	root.name = "Tete"
	parent.add_child(root)
	root.position = HEAD_C
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 28
	sph.rings = 18
	var basis := Basis(ear * 0.07, b * 0.1, third * 0.088)
	var skull := _mi(sph, hair, root, Transform3D(basis, Vector3.ZERO), "Cheveux")
	skull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# le chignon : une torsade (tore) et son cœur, piqués d'épingles
	var bun_c := b * 0.088
	var bb := Basis(ear, b, third).orthonormalized()
	var bun := SphereMesh.new()
	bun.radius = 1.0
	bun.height = 2.0
	bun.radial_segments = 20
	bun.rings = 12
	var bun_mat := hair.duplicate() as StandardMaterial3D
	bun_mat.uv1_scale = Vector3(4.0, 0.6, 1.0)
	_mi(bun, bun_mat, root, Transform3D(Basis(bb.x * 0.037, bb.y * 0.026, bb.z * 0.034), bun_c + b * 0.006), "Chignon")
	var pin := _plain(Color(0.2, 0.18, 0.16), 0.35, 0.7)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var dir := (ear * cos(a) + third * sin(a)).normalized()
		var p := bun_c + dir * 0.024 + b * 0.012
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0012
		cm.bottom_radius = 0.0012
		cm.height = 0.03
		cm.radial_segments = 4
		cm.rings = 1
		var pb := Basis(dir.cross(b).normalized(), dir, b).orthonormalized()
		_mi(cm, pin, root, Transform3D(pb, p))
	# quelques mèches folles autour du chignon et sur la tempe (cartes à découpe alpha)
	var wisp := _tex_mat(TEX_DIR + "cheveux.png", HAIR_TINT * 1.05, 0.6)
	wisp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	wisp.alpha_scissor_threshold = 0.45
	wisp.cull_mode = BaseMaterial3D.CULL_DISABLED
	wisp.uv1_scale = Vector3(0.35, 1.0, 1.0)
	for k in 9:
		var a := -1.6 + k * 0.4
		var dir := (b * 0.8 + ear * sin(a) * 0.6 + third * cos(a) * 0.6).normalized()
		var q := QuadMesh.new()
		q.size = Vector2(0.035, 0.06)
		var nrm := dir.cross(ear).normalized()
		var qb := Basis(dir.cross(nrm).normalized(), dir, nrm).orthonormalized()
		_mi(q, wisp, root, Transform3D(qb, dir * 0.088 + dir * 0.018))


## Tube à section elliptique le long d'une ligne de points : rayons (x : sur le côté, y : vers « up »),
## « sides » côtés, bouts fermés (éventails). UV : u autour, v le long (m). Normales et tangentes.
static func _tube(points: PackedVector3Array, radii: PackedVector2Array, up: Vector3, sides := 10, caps := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var vlen := 0.0
	var frames := []
	for i in n:
		var t: Vector3
		if i == 0:
			t = points[1] - points[0]
		elif i == n - 1:
			t = points[i] - points[i - 1]
		else:
			t = points[i + 1] - points[i - 1]
		t = t.normalized()
		var s := t.cross(up).normalized()
		var nn := s.cross(t).normalized()
		frames.append([t, s, nn])
		if i > 0:
			vlen += points[i].distance_to(points[i - 1])
		for k in sides + 1:
			var a := TAU * k / sides
			var r: Vector2 = radii[i]
			st.set_normal((s * cos(a) / maxf(r.x, 0.0001) + nn * sin(a) / maxf(r.y, 0.0001)).normalized())
			st.set_uv(Vector2(float(k) / sides, vlen))
			st.add_vertex(points[i] + s * cos(a) * r.x + nn * sin(a) * r.y)
	for i in n - 1:
		for k in sides:
			var a := i * (sides + 1) + k
			var b := a + 1
			var c := a + sides + 1
			var d := c + 1
			for q in [a, b, c, b, d, c]:
				st.add_index(q)
	if caps:
		for e in [0, n - 1]:
			var f: Array = frames[e]
			var t: Vector3 = f[0] * (-1.0 if e == 0 else 1.0)
			st.set_normal(t)
			st.set_uv(Vector2(0.5, vlen if e > 0 else 0.0))
			st.add_vertex(points[e] + t * minf(radii[e].x, radii[e].y) * 0.6)
		var c0 := n * (sides + 1)
		for k in sides:
			# (début : vu de -t ; fin : vu de +t)
			st.add_index(c0)
			st.add_index(k + 1)
			st.add_index(k)
			var o := (n - 1) * (sides + 1)
			st.add_index(c0 + 1)
			st.add_index(o + k)
			st.add_index(o + k + 1)
	st.generate_tangents()
	return st.commit()


## Le bras d'Henriette, posé le long de son flanc sur la couette : la manche de la chemise de nuit (sortie de
## sous la couette à l'épaule), le volant du poignet, l'avant-bras, la main sur la hanche. Le poignet passe
## dans le bracelet (BRACELET_POS, inchangé) ; le bras ne respire pas (la couette, sous lui, non plus).
func _arm(base: float, parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "BrasHenriette"
	parent.add_child(root)
	var wrist := Vector3(-0.05, ARM_Y, -3.6)
	var cuff := Vector3(-0.046, ARM_Y + 0.006, -3.548)
	var elbow := Vector3(-0.01, 0.0, -3.41)
	elbow.y = _surf(base, elbow.x, elbow.z) + 0.022
	var sh := Vector3(-0.1, 0.0, -3.24)
	sh.y = _surf(base, sh.x, sh.z) + 0.016
	var start := Vector3(-0.14, 0.0, -3.13)
	start.y = _surf(base, start.x, start.z) - 0.035
	# la manche : froncée (rayon qui ondule), un peu aplatie
	var pts := PackedVector3Array()
	var rad := PackedVector2Array()
	var path := [start, sh, elbow, cuff]
	var steps := 16
	var curve := Curve3D.new()
	for p in path:
		curve.add_point(p)
	for i in [1, 2]:
		var p0: Vector3 = path[i - 1]
		var p2: Vector3 = path[i + 1]
		curve.set_point_in(i, (p0 - p2) * 0.18)
		curve.set_point_out(i, (p2 - p0) * 0.18)
	for k in steps + 1:
		var t := float(k) / steps
		pts.append(curve.sample(int(t * 2.999), fmod(t * 2.999, 1.0)))
		var r := lerpf(0.042, 0.037, t) * (1.0 + 0.12 * sin(k * 2.3 + 0.7) * (1.0 - t * 0.4))
		rad.append(Vector2(r * 1.1, r * 0.62))
	var gown := _fabric("cotton_jersey", Color(1.0, 0.97, 0.93), 0.12, 0.92, 1.4)
	_mi(_tube(pts, rad, Vector3.UP, 12), gown, root, Transform3D.IDENTITY, "Manche")
	# le volant du poignet (dentelle claire)
	var fr := TorusMesh.new()
	fr.inner_radius = 0.026
	fr.outer_radius = 0.04
	fr.rings = 18
	fr.ring_segments = 6
	var d := (wrist - cuff).normalized()
	var fx := d.cross(Vector3.UP).normalized()
	var fz := fx.cross(d).normalized()
	_mi(fr, _fabric("cotton_jersey", Color(1.0, 0.98, 0.95), 0.05, 0.95, 1.0), root, Transform3D(Basis(fx, d * 0.3, fz * 0.8), cuff + d * 0.004), "Volant")
	var skin := _plain(SKIN, 0.55)
	skin.rim_enabled = true
	skin.rim = 0.25
	skin.rim_tint = 0.5
	# l'avant-bras, jusqu'au dos de la main
	var hand_end := Vector3(-0.072, 0.0, -3.69)
	hand_end.y = _surf(base, hand_end.x, hand_end.z) + 0.011
	var up := _surf_normal(base, -0.06, -3.67)
	var fa := PackedVector3Array([cuff - d * 0.01, wrist, wrist.lerp(hand_end, 0.5) + up * 0.002, hand_end])
	var fr2 := PackedVector2Array([Vector2(0.026, 0.023), Vector2(0.023, 0.019), Vector2(0.034, 0.014), Vector2(0.038, 0.012)])
	_mi(_tube(fa, fr2, up, 12), skin, root, Transform3D.IDENTITY, "AvantBras")
	# les doigts : quatre, légèrement repliés sur la couette ; le pouce, rentré
	var f := (hand_end - wrist).normalized()
	var side := f.cross(up).normalized()
	var lens := [0.07, 0.078, 0.073, 0.058]
	var offs := [-0.026, -0.009, 0.008, 0.024]
	for k in 4:
		var k0: Vector3 = hand_end + side * float(offs[k]) - f * 0.004
		var fp := PackedVector3Array([k0])
		var dir := (f + side * float(offs[k]) * 1.5).normalized()
		var bend := 0.0
		var l: float = lens[k]
		for seg in [0.42, 0.32, 0.26]:
			bend += 0.32
			dir = (dir * cos(bend * 0.6) - up * sin(bend * 0.6)).normalized()
			var p: Vector3 = fp[fp.size() - 1] + dir * l * float(seg)
			p.y = maxf(p.y, _surf(base, p.x, p.z) + 0.005)
			fp.append(p)
		var fr3 := PackedVector2Array([Vector2(0.0088, 0.0078), Vector2(0.0082, 0.0074), Vector2(0.0072, 0.0066), Vector2(0.0058, 0.0052)])
		_mi(_tube(fp, fr3, up, 8), skin, root)
	var t0 := wrist + f * 0.03 - side * 0.03
	var t1 := t0 + (f * 0.6 - side * 0.5 - up * 0.2).normalized() * 0.03
	var t2 := t1 + (f * 0.85 - side * 0.15 - up * 0.3).normalized() * 0.028
	t2.y = maxf(t2.y, _surf(base, t2.x, t2.z) + 0.006)
	_mi(_tube(PackedVector3Array([t0, t1, t2]), PackedVector2Array([Vector2(0.012, 0.01), Vector2(0.0095, 0.0085), Vector2(0.0072, 0.0066)]), up, 8), skin, root)


## Ses charentaises, côte à côte sur la descente de lit, la pointe vers la pièce : feutre bordeaux (velours),
## semelle noire de 1 cm, talon rabattu ; l'intérieur plus sombre.
func _slippers() -> void:
	var m := _fabric("velour_velvet", Color(0.4, 0.46, 0.44), 0.12, 0.95, 0.6)
	m.vertex_color_use_as_albedo = true
	var mesh := _slipper_mesh()
	var y := 0.004 + RUG_TOP + 0.001
	for k in 2:
		var mi := _mi(mesh, m, self, Transform3D.IDENTITY, "Charentaise%d" % (k + 1))
		mi.position = Vector3(0.47 + k * 0.025, y, -3.64 - k * 0.12)
		mi.rotation.y = PI / 2.0 + (0.12 if k == 0 else -0.2)
		mi.scale = Vector3(-1.0 if k == 1 else 1.0, 1.0, 1.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Une charentaise (longueur 0,26 m le long de +z, pointe en +z), en champ de hauteurs fermé sur le sol.
func _slipper_mesh() -> ArrayMesh:
	var nu := 30
	var nv := 16
	var L := 0.26
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nu + 1:
		var u := float(j) / nu
		var hw := 0.047 * (0.74 + 0.26 * sin(PI * minf(u, 0.7) / 1.4))
		if u > 0.8:
			hw *= sqrt(maxf(0.0, 1.0 - pow((u - 0.8) / 0.2, 2.0)))
		if u < 0.1:
			hw *= sqrt(maxf(0.0, 1.0 - pow((0.1 - u) / 0.1, 2.0)))
		hw = maxf(hw, 0.002)
		# (la pointe un peu tournée vers l'intérieur du pied)
		var bend := 0.012 * smoothstep(0.5, 1.0, u)
		var dome := 0.046 * smoothstep(0.42, 0.6, u) * (1.0 - 0.6 * smoothstep(0.66, 1.0, u))
		for i in nv + 1:
			var v := -1.0 + 2.0 * i / nv
			var av := absf(v)
			var x := v * hw - bend
			var y := 0.0
			var c := Color(1, 1, 1)
			if av > 0.999:
				y = 0.0
				c = Color(0.12, 0.1, 0.09)
			else:
				var upper := dome * pow(maxf(0.0, 1.0 - v * v), 0.6)
				# l'ouverture (le pied entre là) : la semelle intérieure, et le bord du feutre tout autour,
				# rabattu au talon
				var rim := (0.026 - 0.012 * smoothstep(0.25, 0.0, u)) * smoothstep(0.55, 0.95, av) * (1.0 - smoothstep(0.45, 0.6, u))
				var inner := 0.015
				y = 0.012 + maxf(maxf(upper, rim), inner - 0.012)
				if upper < 0.003 and rim < 0.012:
					c = Color(0.3, 0.24, 0.22)
				if av > 0.93:
					c = c.darkened(0.15)
			st.set_color(c)
			st.set_uv(Vector2(x / 0.12, u * L / 0.12))
			st.add_vertex(Vector3(x, y, u * L - L / 2.0))
	for j in nu:
		for i in nv:
			var a := j * (nv + 1) + i
			var b := a + 1
			var c2 := a + nv + 1
			var d := c2 + 1
			for q in [a, b, c2, b, d, c2]:
				st.add_index(q)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# ------------------------------------------------------------------ veilleuse

## La chouette de la veilleuse, tournée (porcelaine émaillée, éclairée de l'intérieur) à la place des sphères.
func _dress_night_light() -> void:
	var owl := get_node_or_null("Veilleuse") as Node3D
	if owl == null:
		return
	for c in owl.get_children():
		(c as Node3D).visible = false
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = OWL_SHADER
	m.shader = sh
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.034, 0.0), Vector2(0.043, 0.01), Vector2(0.047, 0.035),
		Vector2(0.045, 0.065), Vector2(0.039, 0.092), Vector2(0.035, 0.108), Vector2(0.037, 0.124), Vector2(0.035, 0.14),
		Vector2(0.027, 0.153), Vector2(0.012, 0.158), Vector2(0.0, 0.159)])
	var lift := Vector3(0.0, 0.012, 0.0)
	var body := _mi(Builder.lathe_mesh(prof, 28, 0.86), m, owl, Transform3D(Basis.IDENTITY, lift), "Chouette")
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# oreilles (aigrettes), yeux cerclés d'émail sombre, bec ; socle de bois
	var dark := _plain(Color(0.16, 0.1, 0.07), 0.3)
	var amber := _plain(Color(0.55, 0.32, 0.12), 0.25)
	amber.emission_enabled = true
	amber.emission = Color(1.0, 0.5, 0.15)
	amber.emission_energy_multiplier = 0.8
	for sx in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.011
		ear.height = 0.028
		ear.radial_segments = 8
		ear.rings = 1
		_mi(ear, m, owl, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -sx * 0.35)), lift + Vector3(sx * 0.022, 0.163, 0.0)))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.008
		ring.outer_radius = 0.0125
		ring.rings = 14
		ring.ring_segments = 5
		var eye_p := lift + Vector3(sx * 0.0145, 0.128, -0.029)
		var eb := Basis.from_euler(Vector3(-PI / 2.0 + 0.15, -sx * 0.35, 0.0))
		_mi(ring, dark, owl, Transform3D(eb, eye_p))
		var pupil := SphereMesh.new()
		pupil.radius = 0.0075
		pupil.height = 0.008
		pupil.radial_segments = 10
		pupil.rings = 5
		_mi(pupil, amber, owl, Transform3D(eb, eye_p))
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.005
	beak.height = 0.014
	beak.radial_segments = 6
	beak.rings = 1
	_mi(beak, dark, owl, Transform3D(Basis.from_euler(Vector3(-PI / 2.0 - 0.5, 0.0, 0.0)), lift + Vector3(0.0, 0.114, -0.034)))
	_mi(Builder.cylinder_mesh(0.052, 0.054, 0.012, 24), _m(Color(0.3, 0.2, 0.13), 0.5), owl, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.006, 0.0)), "Socle")
	var nl := get_node_or_null("LumiereVeilleuse") as Light3D
	if nl:
		nl.set_meta("taille", 0.05)


# ------------------------------------------------------------------ les chevets

func _dress_nightstands() -> void:
	var cv := get_node_or_null("ChevetHenriette") as Node3D
	if cv:
		var top := (cv.get_meta("size") as Vector3).y
		# le verre d'eau (tourné, eau à mi-hauteur), à la place des deux cylindres
		_hide_old(Vector3(0.43, top + 0.05, -2.92))
		_hide_old(Vector3(0.43, top + 0.031, -2.92))
		_water_glass(Vector3(0.43, top, -2.92), 0.55)
		# ses lunettes rondes, sur le livre, à la place de la barrette de laiton
		if detail("round_spectacles", Vector3(0.6, top + 0.025, -2.95), -20.0, Vector3(0.13, 0.0, 0.0)):
			_hide_old(Vector3(0.58, top + 0.031, -2.92))
		# ses médicaments : la boîte de somnifères ouverte, la plaquette, le bêtabloquant ; un mouchoir
		_med_box(Vector3(0.405, top, -3.075), 0.35, Vector3(0.115, 0.032, 0.055), 0)
		_med_box(Vector3(0.39, top + 0.032, -3.07), 0.62, Vector3(0.105, 0.03, 0.05), 1)
		_blister(Vector3(0.47, top, -3.13), -0.4)
		_tissue(Vector3(0.36, top, -2.96), 0.026, 0)
		Wear.decal(self, "rond_tasse", Vector3(0.45, top, -2.93), Vector3.UP, Vector3.BACK, 0.13, 0.13,
			{"world": true, "color": Wear.RING_LIGHT, "mix": 0.6, "depth": 0.03})
	var ca := get_node_or_null("ChevetAlbert") as Node3D
	if ca:
		var top2 := (ca.get_meta("size") as Vector3).y
		# la montre de gousset d'Albert, posée sur la grille de mots croisés (il ne la quitte jamais : il est
		# descendu sans elle)
		var w := detail("vintage_pocket_watch", Vector3(-1.69, top2 + 0.0075, -3.02), 160.0, Vector3(0.0, 0.0, 0.0))
		if w:
			w.rotation = Vector3(-PI / 2.0, deg_to_rad(160.0), 0.0)
		Wear.decal(self, "rond_tasse", Vector3(-1.6, top2, -2.93), Vector3.UP, Vector3.BACK, 0.12, 0.12,
			{"world": true, "color": Wear.RING_LIGHT, "mix": 0.55, "depth": 0.03, "variant": 1})
	# un mouchoir froissé tombé près des charentaises
	_tissue(Vector3(0.66, 0.004 + RUG_TOP, -3.42), 0.03, 1)


## Verre d'eau tourné : verre épais au fond, eau jusqu'à « fill » de la hauteur, ménisque.
func _water_glass(p: Vector3, fill: float) -> void:
	var root := Node3D.new()
	root.name = "VerreEau"
	add_child(root)
	root.position = p
	var hh := 0.095
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.027, 0.0), Vector2(0.029, 0.004), Vector2(0.032, hh),
		Vector2(0.0295, hh), Vector2(0.0268, 0.009), Vector2(0.0, 0.009)])
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.86, 0.9, 0.92, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.04
	glass.metallic_specular = 0.9
	glass.rim_enabled = true
	glass.rim = 0.4
	glass.rim_tint = 0.0
	var gm := _mi(Builder.lathe_mesh(prof, 32), glass, root, Transform3D.IDENTITY, "Verre")
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wy := 0.009 + (hh - 0.009) * fill
	var wr := lerpf(0.0268, 0.0295, fill)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.7, 0.78, 0.8, 0.22)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.02
	water.metallic_specular = 1.0
	var wp := PackedVector2Array([Vector2(0.0, 0.0095), Vector2(0.0266, 0.0095), Vector2(wr - 0.0004, wy - 0.0015),
		Vector2(wr - 0.0012, wy), Vector2(0.0, wy - 0.0006)])
	var wm := _mi(Builder.lathe_mesh(wp, 32), water, root, Transform3D.IDENTITY, "Eau")
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Boîte de médicament (carton blanc à coins arrondis, étiquette de l'atlas boites.png sur le dessus ;
## « k » : 0 somnifère, 1 bêtabloquant).
func _med_box(p: Vector3, yaw: float, size: Vector3, k: int) -> void:
	var root := Node3D.new()
	root.name = "Medicament%d" % (k + 1)
	add_child(root)
	root.position = p
	root.rotation.y = yaw
	_mi(Builder.rounded_box_mesh(size, 0.0015, 2), _plain(Color(0.84, 0.84, 0.82), 0.7), root,
		Transform3D(Basis.IDENTITY, Vector3(0.0, size.y / 2.0, 0.0)))
	var lab := _tex_mat(TEX_DIR + "boites.png", Color(0.9, 0.9, 0.88), 0.75)
	lab.uv1_scale = Vector3(0.5, 1.0, 1.0)
	lab.uv1_offset = Vector3(0.5 * k, 0.0, 0.0)
	var q := QuadMesh.new()
	q.size = Vector2(size.x - 0.004, size.z - 0.004)
	_mi(q, lab, root, Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0)), Vector3(0.0, size.y + 0.0004, 0.0)))


## Plaquette de comprimés (aluminium, deux rangées de cinq alvéoles, trois déjà percées).
func _blister(p: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "Plaquette"
	add_child(root)
	root.position = p
	root.rotation.y = yaw
	var alu := _plain(Color(0.78, 0.78, 0.8), 0.32, 0.85)
	_mi(Builder.box_mesh(Vector3(0.1, 0.0015, 0.046)), alu, root, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0008, 0.0)))
	var pvc := StandardMaterial3D.new()
	pvc.albedo_color = Color(0.92, 0.94, 0.95, 0.35)
	pvc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pvc.roughness = 0.15
	var pill := _plain(Color(0.92, 0.9, 0.86), 0.6)
	var cell := Builder.lathe_mesh(PackedVector2Array([Vector2(0.0075, 0.0), Vector2(0.007, 0.004), Vector2(0.0, 0.0055)]), 12)
	for r in 2:
		for c in 5:
			var cp := Vector3(-0.04 + c * 0.02, 0.0015, -0.011 + r * 0.022)
			if r == 0 and c < 3:
				# (percées : la feuille déchirée, plus sombre)
				_mi(Builder.box_mesh(Vector3(0.013, 0.0004, 0.013)), _plain(Color(0.42, 0.42, 0.44), 0.6, 0.6), root, Transform3D(Basis.IDENTITY, cp))
				continue
			var cm := _mi(cell, pvc, root, Transform3D(Basis.IDENTITY, cp))
			cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_mi(Builder.cylinder_mesh(0.0045, 0.0045, 0.0032, 10, 0.0), pill, root, Transform3D(Basis.IDENTITY, cp + Vector3(0, 0.0017, 0)))


## Mouchoir en papier froissé : une boule bosselée (déterministe : « seed »), aplatie, blanche et mate.
func _tissue(p: Vector3, r: float, seed_: int) -> void:
	var nz := FastNoiseLite.new()
	nz.seed = 900 + seed_
	nz.frequency = 9.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := 12
	for j in rings + 1:
		var th := PI * j / rings
		for i in segs + 1:
			var ph := TAU * i / segs
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var k := 1.0 + nz.get_noise_3dv(d) * 0.45
			st.add_vertex(Vector3(d.x * r * k, (d.y * 0.55 + 0.5) * r * k * 0.9, d.z * r * k))
	for j in rings:
		for i in segs:
			var a := j * (segs + 1) + i
			var b := a + 1
			var c := a + segs + 1
			var e := c + 1
			for q in [a, b, c, b, e, c]:
				st.add_index(q)
	st.generate_normals()
	var mi := _mi(st.commit(), _plain(Color(0.86, 0.86, 0.84), 1.0), self, Transform3D(Basis.IDENTITY, p), "Mouchoir%d" % (seed_ + 1))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ la commode, le miroir, la photo

func _dress_commode() -> void:
	var com := props.get("sideTableDrawers") as Node3D
	if com == null:
		return
	var ctop := (com.get_meta("size") as Vector3).y
	# la pendule de cheminée, posée sur la commode (arrêtée, comme la comtoise)
	detail("mantel_clock_01", Vector3(0.39, ctop, ZN + 0.115), 6.0, Vector3(0.27, 0.0, 0.0))
	# la photo de mariage (photos/gp_mariage.png : de dos, sous le porche) dans le cadre à poser du modèle
	var old := get_node_or_null("PhotoMariage") as Node3D
	var fr := detail("standing_picture_frame_02", Vector3(0.93, ctop, ZN + 0.33), -90.0 - 22.0, Vector3(0.0, 0.25, 0.0))
	if fr:
		_when_ready(fr, func(h: Node3D) -> void:
			if old:
				old.visible = false
			var art := _photo_art()
			for n in h.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				for i in mi.mesh.get_surface_count():
					var sm := mi.mesh.surface_get_material(i)
					if sm and sm.resource_name.ends_with("_artwork"):
						mi.set_surface_override_material(i, art))
	_mirror_glass()
	Wear.decal(self, "poussiere", Vector3(0.7, ctop, ZN + 0.26), Vector3.UP, Vector3.BACK, 0.98, 0.42,
		{"world": true, "alpha": 0.75, "depth": 0.04})


## La photo de mariage pour l'image du cadre du modèle (son image occupe u 0,143-0,861, v 0,005-0,995 de
## sa texture) ; sinon l'ancienne photo sépia dessinée.
func _photo_art() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var path := "res://assets/images/photos/gp_mariage.png"
	m.albedo_texture = load(path) if ResourceLoader.exists(path) else _photo_texture()
	m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(1.0 / 0.718, 1.0 / 0.99, 1.0)
	m.uv1_offset = Vector3(-0.143 / 0.718, -0.005 / 0.99, 0.0)
	paper_albedo(m, 0.6)
	return m


## La glace du miroir doré (ornate_mirror_01) : une arche lisse (éventail de 48 pas) posée 0,6 mm devant
## celle du modèle, en vieux tain : piqué et dépoli sur les bords (miroir.png : RGB = teinte, A =
## rugosité), métal pur, rugosité 0,05 au centre. Le haut de l'arche n'a plus de marches, et le reflet
## (sonde de la pièce, SSR) s'éteint en douceur vers le cadre.
func _mirror_glass() -> void:
	var mir := get_node_or_null("Miroir") as Node3D
	if mir == null or mir.get_child_count() == 0:
		return
	var inst := mir.get_child(0) as Node3D
	var a := 0.2
	var yb := -0.366
	var ys := 0.19
	var ya := 0.302
	var pts := PackedVector2Array([Vector2(-a, yb), Vector2(a, yb)])
	for k in 49:
		var t := PI * k / 48.0
		pts.append(Vector2(a * cos(t), ys + (ya - ys) * sin(t)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector2(0.0, (yb + ya) / 2.0)
	st.set_normal(Vector3.BACK)
	st.set_uv(Vector2(0.5, (ya - c.y) / (ya - yb)))
	st.add_vertex(Vector3(c.x, c.y, 0.008))
	for p in pts:
		st.set_normal(Vector3.BACK)
		st.set_uv(Vector2((p.x + a) / (2.0 * a), (ya - p.y) / (ya - yb)))
		st.add_vertex(Vector3(p.x, p.y, 0.008))
	var n := pts.size()
	for i in n:
		# (vu de +z, sens horaire)
		st.add_index(0)
		st.add_index(1 + (i + 1) % n)
		st.add_index(1 + i)
	st.generate_tangents()
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(TEX_DIR + "miroir.png"):
		var tex: Texture2D = load(TEX_DIR + "miroir.png")
		m.albedo_texture = tex
		m.roughness_texture = tex
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	m.metallic = 1.0
	m.roughness = 1.0
	m.metallic_specular = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var gm := _mi(st.commit(), m, inst, Transform3D.IDENTITY, "GlaceMiroir")
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ le reste de la chambre

func _dress_room() -> void:
	# la descente de lit, côté Henriette (ses charentaises dessus)
	var rug := Node3D.new()
	rug.name = "DescenteDeLit"
	add_child(rug)
	rug.position = Vector3(0.56, 0.004, -3.86)
	rug.rotation.y = 0.04
	var mat := Builder._rug_pattern_mat("oriental")
	if mat:
		var mesh := Builder.rug_mesh(0.62, 1.12, false, RUG_TOP, Vector3.ZERO, RUG_FRINGE)
		mesh.surface_set_material(0, mat)
		if mesh.get_surface_count() > 1:
			mesh.surface_set_material(1, Builder._rug_fringe_mat("oriental"))
		_mi(mesh, null, rug)
	# le coffre de mariage au pied du lit, en chêne ciré, et le plaid plié dessus
	_chest(Vector3(-0.6, 0.0, -5.13))
	# le guéridon près de la berceuse : la lampe à pétrole (électrifiée), le tricot
	var gt := detail("side_table_tall_01", Vector3(-2.66, 0.0, -4.12), 15.0, Vector3(0.0, 0.62, 0.0), {"shadow": true})
	if gt:
		var gtop := 0.62     # (« fit » en hauteur : le dessus est à 0,62 exactement)
		_mi(Builder.cylinder_mesh(0.15, 0.15, 0.002, 32, 0.0), _plain(Color(0.84, 0.82, 0.76), 1.0), self,
			Transform3D(Basis.IDENTITY, Vector3(-2.66, gtop + 0.001, -4.12)), "Napperon")
		detail("vintage_oil_lamp", Vector3(-2.7, gtop + 0.002, -4.16), 30.0, Vector3(0.0, 0.42, 0.0))
		_knitting(Vector3(-2.57, gtop + 0.002, -4.04))
	# le gilet d'Albert jeté sur le dossier de sa chaise ; son fauteuil, tourné vers le lit, le journal plié
	_cardigan()
	var fa := detail("ArmChair_01", Vector3(2.47, 0.0, -4.7), -82.0, Vector3(0.0, 0.95, 0.0), {"tint": Color(0.56, 0.58, 0.5)})
	if fa:
		_newspaper(Vector3(2.45, 0.0, -4.69), -82.0)
	# deux photos de famille au mur nord, à droite du miroir
	_wall_photo(Vector3(1.48, 1.62, ZN), Vector2(0.18, 0.24), "res://assets/images/photos/famille.png", -1.5)
	_wall_photo(Vector3(1.8, 1.52, ZN), Vector2(0.21, 0.165), "res://assets/images/photos/plage.png", 2.0)


## Le gilet de laine d'Albert, jeté sur le dossier de la chaise (painted_wooden_chair_01) : un pan qui
## retombe devant (vers l'assise), l'autre derrière, plis et manche pendante ; repère de la chaise (son
## dossier à l'arrière, −z, en haut de sa boîte).
func _cardigan() -> void:
	var chair := props.get("chair") as Node3D
	if chair == null or not chair.has_meta("size"):
		return
	var sz: Vector3 = chair.get_meta("size")
	var top := sz.y
	var zb := -minf(sz.z, 0.42) / 2.0 + 0.03     # (chaise posée « dos au fond » de sa boîte de 0,42)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 9.0
	var nu := 18
	var nv := 26
	var w := 0.34
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		var v := float(j) / nv          # 0 : bas du pan de devant, 1 : bas du pan de derrière
		var ang := clampf((v - 0.5) / 0.14, -1.0, 1.0) * PI / 2.0
		for i in nu + 1:
			var u := float(i) / nu
			var x := (u - 0.5) * w
			var hang_f := 0.26 + 0.07 * sin(u * 7.0 + 0.5) + 0.04 * (1.0 - u)
			var hang_b := 0.2 + 0.05 * cos(u * 6.0)
			var y: float
			var z: float
			if v < 0.36:
				var t := v / 0.36
				y = top - hang_f * (1.0 - t) - 0.01
				z = zb + 0.024 + 0.02 * (1.0 - t)
			elif v > 0.64:
				var t := (v - 0.64) / 0.36
				y = top - hang_b * t - 0.01
				z = zb - 0.024 - 0.015 * t
			else:
				y = top + 0.012 * cos(ang) - 0.01
				z = zb - 0.024 * sin(ang)
			# les plis verticaux, plus marqués en bas des pans
			var low := 1.0 - clampf(absf(v - 0.5) * 2.0, 0.0, 1.0)
			var fold := noise.get_noise_2d(x * 3.0, 0.0) * 0.018 * (1.0 - low)
			z += fold if v < 0.5 else -fold
			x += noise.get_noise_2d(v * 2.0, u * 2.0) * 0.01 * (1.0 - low)
			st.set_uv(Vector2(x, y))
			st.add_vertex(Vector3(x, y, z))
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			var b := a + 1
			var c := a + nu + 1
			var d := c + 1
			for q in [a, b, c, b, d, c]:
				st.add_index(q)
	st.generate_normals()
	st.generate_tangents()
	var knit := _fabric("cotton_jersey", Color(0.42, 0.36, 0.3), 0.06, 0.95, 1.6)
	knit.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := _mi(st.commit(), knit, chair, Transform3D.IDENTITY, "GiletAlbert")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_extra_casters.append(mi)
	# une manche qui pend devant, le long du pied de la chaise
	var sl := PackedVector3Array([Vector3(0.17, top - 0.04, zb + 0.04), Vector3(0.2, top - 0.2, zb + 0.06), Vector3(0.21, top - 0.42, zb + 0.07)])
	var sr := PackedVector2Array([Vector2(0.034, 0.024), Vector2(0.032, 0.022), Vector2(0.028, 0.02)])
	_extra_casters.append(_mi(_tube(sl, sr, Vector3.BACK, 10), knit, chair, Transform3D.IDENTITY, "ManchePendante"))


## Le journal d'Albert, plié en deux sur l'assise de son fauteuil (repère : pied du fauteuil, « yaw » en
## degrés ; l'assise du modèle ArmChair_01 mis à 0,95 m de haut est vers 0,43 m).
func _newspaper(p: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "Journal"
	add_child(root)
	root.position = p + Vector3(0.0, 0.445, 0.0)
	root.rotation.y = deg_to_rad(yaw + 12.0)
	var paper := _plain(Color(0.7, 0.68, 0.62), 0.95)
	paper_albedo(paper, 0.8)
	_mi(Builder.box_mesh(Vector3(0.3, 0.008, 0.21), 0.002), paper, root, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 0.03)), Vector3.ZERO))
	# la page du dessus, un peu soulevée au pli
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.19)
	var ink := _plain(Color(0.55, 0.54, 0.5), 0.95)
	_mi(q, ink, root, Transform3D(Basis.from_euler(Vector3(-PI / 2.0 + 0.06, 0.0, 0.0)), Vector3(0.0, 0.0055, 0.004)))


## Coffre de mariage (chêne sombre ciré, Wood027) : caisse sur plinthe, couvercle débordant, ferrures
## noires, entrée de serrure ; un plaid de laine plié dessus.
func _chest(p: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Coffre"
	add_child(root)
	root.position = p
	var wood: Material = mats.wood_dark
	var iron := _plain(Color(0.08, 0.075, 0.07), 0.45, 0.7)
	var W := 0.94
	var D := 0.44
	_mi(Builder.box_mesh(Vector3(W, 0.06, D), 0.006), wood, root, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)))
	_mi(Builder.box_mesh(Vector3(W - 0.04, 0.33, D - 0.04), 0.004), wood, root, Transform3D(Basis.IDENTITY, Vector3(0, 0.225, 0)))
	_mi(Builder.box_mesh(Vector3(W + 0.02, 0.035, D + 0.02), 0.008), wood, root, Transform3D(Basis.IDENTITY, Vector3(0, 0.4075, 0)))
	# panneaux en relief sur la face (vers le lit : +z) et à l'arrière
	for sz in [1.0, -1.0]:
		for k in 3:
			var px := -0.28 + k * 0.28
			_mi(Builder.box_mesh(Vector3(0.22, 0.2, 0.012), 0.004), wood, root,
				Transform3D(Basis.IDENTITY, Vector3(px, 0.225, sz * ((D - 0.04) / 2.0 + 0.006))))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mi(Builder.box_mesh(Vector3(0.05, 0.05, 0.004)), iron, root,
				Transform3D(Basis.IDENTITY, Vector3(sx * (W / 2.0 - 0.045), 0.36, sz * ((D - 0.04) / 2.0 + 0.003))))
	_mi(Builder.box_mesh(Vector3(0.045, 0.06, 0.004)), iron, root, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.355, -(D - 0.04) / 2.0 - 0.003)))
	_mi(Builder.box_mesh(Vector3(0.006, 0.016, 0.002)), _plain(Color(0.0, 0.0, 0.0), 1.0), root,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.352, -(D - 0.04) / 2.0 - 0.0055)))
	# le plaid plié, la dernière épaisseur retombe sur le côté
	var wool := _fabric("cotton_jersey", Color(0.66, 0.56, 0.44), 0.16, 0.95, 1.2)
	var plaid := Builder.rounded_box_mesh(Vector3(0.52, 0.07, 0.38), 0.025, 4)
	var pm := _mi(plaid, wool, root, Transform3D(Basis.from_euler(Vector3(0.0, 0.08, 0.0)), Vector3(0.12, 0.46, 0.0)))
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Le tricot d'Henriette : une pelote de laine et l'ouvrage commencé, deux aiguilles plantées dans la pelote.
func _knitting(p: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Tricot"
	add_child(root)
	root.position = p
	var yarn := _fabric("cotton_jersey", Color(0.62, 0.66, 0.78), 0.03, 0.95, 1.5)
	var ball := SphereMesh.new()
	ball.radius = 0.04
	ball.height = 0.074
	ball.radial_segments = 16
	ball.rings = 10
	_mi(ball, yarn, root, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.036, 0.0)))
	_mi(Builder.rounded_box_mesh(Vector3(0.12, 0.012, 0.08), 0.005, 2), yarn, root,
		Transform3D(Basis.from_euler(Vector3(0.0, 0.5, 0.05)), Vector3(-0.09, 0.006, 0.03)))
	var steel := _plain(Color(0.6, 0.6, 0.62), 0.3, 0.9)
	for k in 2:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0018
		cm.bottom_radius = 0.0018
		cm.height = 0.26
		cm.radial_segments = 6
		cm.rings = 1
		_mi(cm, steel, root, Transform3D(Basis.from_euler(Vector3(0.9 + k * 0.25, 0.3 + k * 0.6, 0.2)), Vector3(0.0, 0.07, 0.0)))


## Photo encadrée accrochée au mur nord (z = ZN, elle regarde +z) : baguette de bois sombre, passe-partout
## crème, l'image (photos/*.png, sans visage) ; « tilt » : penchée de quelques degrés.
func _wall_photo(c: Vector3, size: Vector2, path: String, tilt_deg: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var root := Node3D.new()
	root.name = "CadreMur"
	add_child(root)
	root.position = Vector3(c.x, c.y, c.z + 0.012)
	root.rotation.z = deg_to_rad(tilt_deg)
	var wood: Material = mats.wood_dark
	var b := 0.018
	for sy in [-1.0, 1.0]:
		_mi(Builder.box_mesh(Vector3(size.x, b, 0.02), 0.003), wood, root, Transform3D(Basis.IDENTITY, Vector3(0, sy * (size.y - b) / 2.0, 0)))
	for sx in [-1.0, 1.0]:
		_mi(Builder.box_mesh(Vector3(b, size.y - 2.0 * b, 0.02), 0.003), wood, root, Transform3D(Basis.IDENTITY, Vector3(sx * (size.x - b) / 2.0, 0, 0)))
	_mi(Builder.box_mesh(Vector3(size.x - 2.0 * b, size.y - 2.0 * b, 0.004)), _plain(Color(0.78, 0.75, 0.66), 0.9), root,
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.004)))
	var img := StandardMaterial3D.new()
	img.albedo_texture = load(path)
	img.roughness = 0.5
	img.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	paper_albedo(img, 0.8)
	var iw := size.x - 2.0 * b - 0.03
	var tex := img.albedo_texture
	var ih := minf(size.y - 2.0 * b - 0.03, iw * float(tex.get_height()) / float(tex.get_width()))
	var q := QuadMesh.new()
	q.size = Vector2(iw, ih)
	_mi(q, img, root, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.0015)))
	# le verre
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.88, 0.9, 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.8
	var gq := QuadMesh.new()
	gq.size = Vector2(size.x - 2.0 * b + 0.004, size.y - 2.0 * b + 0.004)
	var gm := _mi(gq, glass, root, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.004)))
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ rideaux

## Rideaux de velours bordeaux passé (velour_velvet, Poly Haven, CC0 : albédo et normale), plis modelés (trois
## ondes de 9 à 16 cm, plus amples en bas, froncées sous la tringle), ourlet droit retourné, reflet rasant ;
## à la place des pans plats (mêmes places, même tringle).
func _dress_curtains() -> void:
	var old := []
	for sz in [-1.0, 1.0]:
		var c := _old_at(Vector3(XW + 0.2, 2.35, -5.0 + sz * 0.83))
		if c:
			old.append(c)
	if old.is_empty():
		return
	var velvet := _fabric("velour_velvet", Color(0.54, 0.74, 0.5), 0.28, 0.88, 1.0)
	velvet.rim_enabled = true
	velvet.rim = 0.5
	velvet.rim_tint = 0.6
	var top := 2.35
	var k := 0
	for c in old:
		var o := c as MeshInstance3D
		o.visible = false
		var mi := _mi(_drape_hd(0.5, top - 0.015, 1.3 + 2.1 * k), velvet, self, o.transform, "RideauHD%d" % (k + 1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		k += 1


## Pan de velours (repère du pan comme _drape : haut au centre, largeur le long de z, vers le bas, vu de +x).
## Deux faces (le dos à 4 mm), normales et tangentes calculées, UV en mètres.
func _drape_hd(width: float, hh: float, ph: float) -> ArrayMesh:
	var nu := 56
	var nv := 28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 2:
		for j in nv + 1:
			var v := float(j) / nv
			for i in nu + 1:
				var u := float(i) / nu
				var zz := width * (0.5 - u)
				var amp := 0.02 + 0.03 * v * v
				var f := amp * (sin(zz / 0.016 + ph) * 0.5 + sin(zz / 0.024 + ph * 1.7 + v * 0.8) * 0.33 + sin(zz / 0.013 + ph * 0.6) * 0.17)
				f += (1.0 - smoothstep(0.0, 0.07, v)) * 0.012 * sin(zz / 0.0095 + ph)
				f += smoothstep(0.97, 1.0, v) * 0.004
				var y := -hh * v
				st.set_uv(Vector2(zz, -y) if side == 0 else Vector2(-zz, -y))
				st.add_vertex(Vector3(f - 0.004 * side, y, zz * (1.0 - 0.04 * v)))
		var base := side * (nu + 1) * (nv + 1)
		for j in nv:
			for i in nu:
				var a := base + j * (nu + 1) + i
				var c := a + nu + 1
				if side == 0:
					for q in [a, a + 1, c, a + 1, c + 1, c]:
						st.add_index(q)
				else:
					for q in [a, c, a + 1, a + 1, c, c + 1]:
						st.add_index(q)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# ------------------------------------------------------------------ usure

## Poussière (dessus de la commode et de l'armoire), crasse des pieds de murs, l'auréole d'eau du plafond
## (variante « gp »), le chemin usé du lit à la porte. (Les ronds de verre des chevets : _dress_nightstands.)
func _wear_room() -> void:
	if not Wear.deco_on():
		return
	Wear.wall_base(self, 0.22, {"gaps": [Rect2(-2.05, -3.3, 0.6, 0.6), Rect2(-1.45, -2.95, 1.7, 0.25),
		Rect2(0.28, -3.3, 0.55, 0.6), Rect2(-2.4, -7.3, 1.3, 0.75), Rect2(0.15, -7.3, 1.1, 0.5),
		Rect2(2.85, -5.7, 0.35, 0.6)]})
	var arm := get_node_or_null("Armoire") as Node3D
	if arm:
		var atop := (arm.get_meta("size") as Vector3).y
		Wear.decal(self, "poussiere", Vector3(-1.75, atop, ZN + 0.33), Vector3.UP, Vector3.BACK, 1.1, 0.56,
			{"world": true, "alpha": 0.95, "depth": 0.06})
	Wear.decal(self, "tache_plafond", Vector3(-2.45, h, -6.55), Vector3.DOWN, Vector3.BACK, 0.75, 0.6,
		{"world": true, "variant": 3})
	Wear.ceiling_corners(self, {"only": [0, 2], "size": 0.7})
	Wear.path(self, [Vector2(0.95, -3.95), Vector2(2.0, -3.75), Vector2(2.6, -3.62)], 0.42)
