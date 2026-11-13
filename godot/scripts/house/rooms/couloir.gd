extends HouseRoom
## Le couloir du premier étage : long, étroit, resté dans les années 90 (tapis rouge élimé, radiateur
## en fonte, console et téléphone sans fil, photos de famille), mais truffé d'appareils imposés de
## l'extérieur : ampoules connectées du fournisseur d'énergie, caméra dôme de l'assurance, thermostat,
## détecteur de fumée, boîtier de téléassistance. Leurs câbles blancs, neufs, sont scotchés sur le
## vieux papier peint.
## Repère : intérieur x 3.3 → 4.7, z −7.3 → 6.3, sol y = 0, plafond 2.6.
## Portes : mur x = 3.25 en z −3.6 (P2), 1.4 (P1), 3.4 (P3) ; mur x = 4.75 en z −4.6 (P4), −1.2 (P5),
## 1.35 (P6, vitrée, s'ouvre dans le couloir), 4.4 (P7). Fenêtre F8 au bout sud (mur z = 6.35).
## Fonctions publiques : flicker(secondes), set_dim(k), chain_lights(), track(cible), look_at_player_once(),
## set_switch(on, quiet, keep_level) (l'interrupteur : coupe ou rend le courant aux trois ampoules),
## unplug_nestor(quiet) (avec le tournevis), photo() (await : image de CAM 1, prête à imprimer), restore().
## Propriétés : nestor (Nestor, « nestor »), feed_cam (FeedCam « CAM 1 COULOIR », sur la tête de la
## caméra dôme), switch_on, nestor_unplugged.
## Ampoules L1 à L3 : smart_bulbs (SmartBulb « ampoule_couloir_1 » à « _3 »).
## Caméra dôme : cam_led_on (LED éteinte 5 s quand on fixe l'objectif 3 s). Radiateur : RADIATOR_POS.
## Événements Haunt.story_event : « lumiere » {room: "couloir", on}, « nestor_debranche »,
## « camera_led_eteinte ».

const XW := 3.312        # face du papier peint, mur ouest (côté chambres)
const XE := 4.688        # face du papier peint, mur est (côté salle de bain, escalier, bureau)
const ZN := -7.288       # mur nord (le portrait)
const ZS := 6.288        # mur sud (la fenêtre)
const DADO := 0.022      # épaisseur du lambris (sous 0,92 m)
const LIGHT_Z := [-5.0, -0.5, 4.0]
const LIGHT_ENERGY := 0.35
const BULB_GLOW := 2.6
const CAM_POS := Vector3(4.0, 2.6, -7.1)   # assez loin du mur pour ne pas mordre sur la corniche
const RADIATOR_POS := Vector3(4.62, 0.45, -2.9)   # centre du radiateur (§ 5.2) : les S.O.S. d'Albert
const STARE_SEC := 3.0           # fixer l'objectif de la caméra dôme 3 s…
const STARE_DEG := 10.0          # (à moins de 10° du centre du regard)
const LED_OFF_SEC := 5.0         # … et sa LED s'éteint 5 s
const TXT_CAMERA := "Une caméra. LED rouge. Elle tourne quand tu bouges."
const TXT_CAMERA_LED := "Elle a éteint sa lumière. Elle sait que tu sais."
const TXT_PORTRAIT := "Mamie et Papi, 1996, surexposés. Ils rient. Tu ne les as jamais vus rire comme ça."

var house: House
var rng := RandomNumberGenerator.new()
var bulbs: Array[OmniLight3D] = []          # les lumières de L1, L2, L3 (celles des SmartBulb)
var smart_bulbs: Array[SmartBulb] = []     # L1, L2, L3 : « ampoule_couloir_1 » à « _3 », du nord au sud
var bulb_mats: Array[StandardMaterial3D] = []
var shade_mats: Array[StandardMaterial3D] = []
var dim := 1.0
var _flicker_id := 0
var _chain_id := 0
var _dim_tw: Tween

var cam_pivot: Node3D
var cam_target: Node3D
var cam_led: OmniLight3D
var _cam_rest := Vector2(-0.42, PI)   # (tangage, lacet) au repos : vers le sud, vers le bas
var _cam_once := false
var _motor_t := 0.0
var cam_led_mat: StandardMaterial3D
var cam_led_on := true           # la LED rouge de la caméra dôme (éteinte 5 s quand on la fixe 3 s)
var _stare_t := 0.0
var _led_off_t := 0.0

var thermostat: Device
var nestor: Nestor
var nestor_it: Interactable
var nestor_plug: Node3D
var nestor_unplugged := false
var switch_on := true            # l'interrupteur mural des trois ampoules
var switch_rocker: Node3D
var switch_it: Interactable
var feed_cam: FeedCam
var smoke_led: StandardMaterial3D
var phone_led: StandardMaterial3D
var _cable_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _new_white: StandardMaterial3D
var _glass: StandardMaterial3D


func furnish(h: House) -> void:
	house = h
	rng.seed = 1031
	_cable_mat = _plain(Color(0.9, 0.9, 0.88), 0.4)
	_tape_mat = _plain(Color(0.78, 0.76, 0.68), 0.3)
	_new_white = _plain(Color(0.72, 0.72, 0.7), 0.4)
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.7, 0.75, 0.8, 0.06)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.18
	_glass.metallic_specular = 0.45
	_runner()
	_radiator(RADIATOR_POS.z)
	_console()
	_plant()
	_frames()
	_portrait()
	_ceiling_lights()
	_camera()
	_thermostat()
	_smoke_detector()
	_traces()
	_nestor()
	_switch()
	_network_cable()
	_feed_cam()


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
	s.rings = seg / 2
	return s


## Objet émissif : n'entre pas dans l'éclairage indirect cuit (sinon il brillerait encore éteint).
func _no_gi(mi: GeometryInstance3D) -> GeometryInstance3D:
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _look(label: String, size: Vector3, pos: Vector3, text: String, reach := 2.2) -> Interactable:
	var it := _interactable(label, size, pos, self, LAYER_INTERACT, reach)
	it.used.connect(func(_i: Interactable) -> void: Game.hint(text, 4.5))
	return it


## Câble blanc, neuf, en segments droits, scotché tous les 40 cm. « normal » : la surface sur laquelle il
## court (mur ou plafond), vers la pièce. Les points sont déjà décollés de la surface.
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


## Prise de courant (ancienne, jaunie) ou conjoncteur téléphonique en T, sur un mur.
func _socket(pos: Vector3, normal: Vector3, kind := "secteur") -> Node3D:
	var holder := Node3D.new()
	holder.name = "Prise"
	add_child(holder)
	holder.position = pos
	holder.rotation.y = atan2(normal.x, normal.z)
	var plate := _m(Color(0.72, 0.68, 0.58), 0.5)
	if kind == "T":
		_box(Vector3(0.07, 0.05, 0.028), Vector3(0, 0, 0.014), plate, false, holder)
		_box(Vector3(0.03, 0.005, 0.003), Vector3(0, 0.008, 0.029), mats.dark, false, holder)
		_box(Vector3(0.005, 0.022, 0.003), Vector3(0, -0.004, 0.029), mats.dark, false, holder)
	else:
		_box(Vector3(0.075, 0.075, 0.012), Vector3(0, 0, 0.006), plate, false, holder)
		_mesh(_cyl(0.023, 0.023, 0.004), Vector3(0, 0, 0.0125), _m(Color(0.6, 0.56, 0.48), 0.5), Vector3(PI / 2.0, 0, 0), holder)
	return holder


## Fiche blanche branchée dans une prise (repère de la prise).
func _plug(socket: Node3D, grey := false) -> void:
	var m: Material = _m(Color(0.6, 0.6, 0.58), 0.45) if grey else _new_white
	_box(Vector3(0.036, 0.042, 0.03), Vector3(0, 0, 0.03), m, false, socket)


## Décalque (tache, moisissure…) posé sur une surface (même convention que decor.gd).
func _decal(tex: Texture2D, center: Vector3, normal: Vector3, up: Vector3, size_u: float, size_v: float, depth := 0.2, mod := Color.WHITE, mix := 1.0) -> Decal:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(size_u, depth, size_v)
	d.modulate = mod
	d.albedo_mix = mix
	var y := normal.normalized()
	var z := -up.normalized()
	var x := y.cross(z)
	d.transform = Transform3D(Basis(x, y, z), center)
	add_child(d)
	return d


# ------------------------------------------------------------------ images générées (photos, tapis)

func _px_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - ry)), mini(img.get_height(), int(cy + ry) + 1)):
		for x in range(maxi(0, int(cx - rx)), mini(img.get_width(), int(cx + rx) + 1)):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c)


func _px_rect(img: Image, x: float, y: float, w: float, hh: float, c: Color) -> void:
	img.fill_rect(Rect2i(int(x), int(y), maxi(1, int(w)), maxi(1, int(hh))), c)


func _px_vgrad(img: Image, y0_: int, y1: int, c0: Color, c1: Color) -> void:
	for y in range(y0_, y1):
		_px_rect(img, 0, y, img.get_width(), 1, c0.lerp(c1, float(y - y0_) / maxf(1.0, y1 - y0_ - 1)))


## Fond tacheté (fond de studio, mur) : une couleur et un peu de bruit.
func _px_mottle(img: Image, base: Color, amount: float, freq := 0.08, seed_ := 1) -> void:
	var nz := FastNoiseLite.new()
	nz.seed = seed_
	nz.frequency = freq
	for y in img.get_height():
		for x in img.get_width():
			var k := nz.get_noise_2d(x, y) * amount
			img.set_pixel(x, y, base.lightened(k) if k > 0.0 else base.darkened(-k))


## Personnage en pied, vu de loin : jambes, buste (ou robe), tête, cheveux.
func _px_person(img: Image, x: float, foot: float, hgt: float, body: Color, hair: Color, dress := false, skin := Color(0.82, 0.62, 0.5), legs := Color(0.15, 0.15, 0.2)) -> void:
	var hr := hgt * 0.1
	var hy := foot - hgt + hr
	var waist := foot - hgt * 0.45
	if dress:
		for y in range(int(hy + hr), int(foot - hgt * 0.08)):
			var k := (y - (hy + hr)) / (foot - hgt * 0.08 - hy - hr)
			var half := hgt * (0.1 + 0.08 * k)
			_px_rect(img, x - half, y, half * 2.0, 1, body)
		_px_rect(img, x - hgt * 0.05, foot - hgt * 0.08, hgt * 0.035, hgt * 0.08, skin)
		_px_rect(img, x + hgt * 0.015, foot - hgt * 0.08, hgt * 0.035, hgt * 0.08, skin)
	else:
		_px_rect(img, x - hgt * 0.08, waist, hgt * 0.07, foot - waist, legs)
		_px_rect(img, x + hgt * 0.01, waist, hgt * 0.07, foot - waist, legs)
		_px_rect(img, x - hgt * 0.12, hy + hr, hgt * 0.24, waist - hy - hr + 1, body)
	_px_ellipse(img, x, hy - hr * 0.15, hr * 0.95, hr * 0.95, hair)
	_px_ellipse(img, x, hy + hr * 0.12, hr * 0.75, hr * 0.85, skin)


## Buste de face, en gros plan (portraits de studio).
func _px_bust(img: Image, x: float, head_y: float, hr: float, body: Color, hair: Color, skin := Color(0.8, 0.62, 0.52), hair_big := 1.0) -> void:
	_px_ellipse(img, x, head_y + hr * 3.4, hr * 2.6, hr * 2.4, body)
	_px_rect(img, x - hr * 0.35, head_y + hr * 0.6, hr * 0.7, hr * 0.9, skin.darkened(0.1))
	_px_ellipse(img, x, head_y - hr * 0.25, hr * 1.02 * hair_big, hr * 1.0 * hair_big, hair)
	_px_ellipse(img, x, head_y + hr * 0.12, hr * 0.8, hr * 0.95, skin)


func _px_eyes(img: Image, x: float, y: float, gap: float, c := Color(0.08, 0.06, 0.05), look := 0.0) -> void:
	img.set_pixel(int(x - gap + look), int(y), c)
	img.set_pixel(int(x + gap + look), int(y), c)


## Le tirage vieillit : jauni, contraste écrasé, grain, coins assombris.
func _develop(img: Image, warm := 0.16, sepia := false, vignette := 0.55, grain := 0.045) -> ImageTexture:
	var w := img.get_width()
	var hh := img.get_height()
	for y in hh:
		for x in w:
			var c := img.get_pixel(x, y)
			if sepia:
				var l := c.get_luminance()
				c = Color(l * 1.08, l * 0.93, l * 0.72)
			c = c.lerp(Color(0.92, 0.8, 0.6), warm)
			c = c.lerp(Color(0.5, 0.46, 0.4), 0.12) * 0.82
			var u := (x + 0.5) / w - 0.5
			var v := (y + 0.5) / hh - 0.5
			var vig := 1.0 - vignette * (u * u + v * v) * 2.0
			var n := rng.randf_range(-grain, grain)
			img.set_pixel(x, y, Color(clampf(c.r * vig + n, 0, 1), clampf(c.g * vig + n, 0, 1), clampf(c.b * vig + n, 0, 1)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Photos de famille des années 90, dessinées pixel par pixel (pas de fichier image).
func _photo(kind: String) -> ImageTexture:
	var img: Image
	var skin := Color(0.82, 0.62, 0.5)
	match kind:
		"plage":   # Mamie et ta mère petite, à la mer, sous un parasol
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_vgrad(img, 0, 20, Color(0.5, 0.68, 0.84), Color(0.78, 0.84, 0.88))
			_px_vgrad(img, 20, 28, Color(0.15, 0.36, 0.48), Color(0.25, 0.48, 0.55))
			_px_rect(img, 0, 27, 64, 1, Color(0.85, 0.88, 0.85))
			_px_vgrad(img, 28, 48, Color(0.8, 0.72, 0.55), Color(0.72, 0.62, 0.46))
			_px_rect(img, 49, 14, 1, 30, Color(0.3, 0.3, 0.3))
			for y in range(9, 16):
				var half := (y - 8) * 1.6
				for x in range(int(49 - half), int(49 + half)):
					img.set_pixel(x, y, Color(0.75, 0.18, 0.15) if (x / 3) % 2 == 0 else Color(0.9, 0.88, 0.82))
			_px_person(img, 21, 44, 27, Color(0.7, 0.16, 0.18), Color(0.35, 0.22, 0.12), false, skin, skin)
			_px_person(img, 32, 45, 15, Color(0.85, 0.7, 0.2), Color(0.3, 0.18, 0.1), false, skin, skin)
			return _develop(img, 0.2)
		"jardin":   # Papi devant la maison, l'été où il a repeint les volets
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_vgrad(img, 0, 14, Color(0.55, 0.62, 0.72), Color(0.7, 0.74, 0.78))
			_px_rect(img, 6, 10, 52, 26, Color(0.8, 0.74, 0.62))
			for y in range(3, 11):
				var inset := (10 - y) * 2.5
				_px_rect(img, 4 + inset, y, 56 - inset * 2.0, 1, Color(0.38, 0.22, 0.18))
			for wx in [12, 40]:
				_px_rect(img, wx - 1, 15, 12, 10, Color(0.2, 0.32, 0.25))
				_px_rect(img, wx + 1, 16, 8, 8, Color(0.1, 0.1, 0.12))
			_px_rect(img, 27, 21, 9, 15, Color(0.28, 0.2, 0.15))
			_px_vgrad(img, 35, 48, Color(0.3, 0.44, 0.2), Color(0.22, 0.34, 0.15))
			_px_person(img, 20, 45, 28, Color(0.25, 0.3, 0.42), Color(0.3, 0.28, 0.26), false, skin, Color(0.3, 0.27, 0.2))
			_px_person(img, 30, 46, 13, Color(0.75, 0.2, 0.2), Color(0.3, 0.18, 0.1), false, skin, Color(0.2, 0.25, 0.45))
			return _develop(img, 0.18)
		"mariage":   # le mariage d'Henriette et Albert, en sépia
			img = Image.create_empty(48, 64, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.55, 0.5, 0.42), 0.18, 0.1, 4)
			_px_ellipse(img, 24, 22, 16, 22, Color(0.32, 0.27, 0.22))
			_px_rect(img, 8, 22, 32, 42, Color(0.32, 0.27, 0.22))
			_px_person(img, 19, 62, 46, Color(0.08, 0.08, 0.08), Color(0.12, 0.1, 0.08), false, skin, Color(0.06, 0.06, 0.06))
			_px_rect(img, 18, 25, 2, 8, Color(0.9, 0.9, 0.88))
			_px_person(img, 30, 63, 42, Color(0.92, 0.9, 0.86), Color(0.25, 0.18, 0.12), true, skin)
			_px_ellipse(img, 31, 30, 3, 2.5, Color(0.85, 0.8, 0.7))
			return _develop(img, 0.1, true, 0.8)
		"noel":   # ta mère, petite, au flash, devant le sapin (les yeux rouges)
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.18, 0.12, 0.08), 0.25, 0.12, 9)
			for y in range(4, 42):
				var half := (y - 4) * 0.42
				_px_rect(img, 46 - half, y, half * 2.0, 1, Color(0.1, 0.24, 0.12))
			for k in 14:
				img.set_pixel(rng.randi_range(38, 54), rng.randi_range(12, 40), [Color(0.95, 0.8, 0.3), Color(0.9, 0.2, 0.2), Color(0.4, 0.6, 1.0)][k % 3])
			_px_rect(img, 44, 41, 4, 7, Color(0.3, 0.2, 0.12))
			_px_rect(img, 4, 40, 60, 8, Color(0.35, 0.18, 0.12))
			_px_bust(img, 22, 20, 6.5, Color(0.62, 0.12, 0.14), Color(0.32, 0.2, 0.1), Color(0.95, 0.78, 0.68))
			_px_eyes(img, 22, 21, 2, Color(0.95, 0.1, 0.08))
			_px_rect(img, 28, 34, 10, 8, Color(0.2, 0.35, 0.7))
			_px_rect(img, 32, 34, 2, 8, Color(0.9, 0.8, 0.3))
			return _develop(img, 0.12, false, 1.3, 0.05)
		"labo":   # Papi devant le labo, le jour de sa retraite
			img = Image.create_empty(64, 48, false, Image.FORMAT_RGB8)
			_px_vgrad(img, 0, 16, Color(0.6, 0.62, 0.64), Color(0.68, 0.69, 0.7))
			_px_rect(img, 0, 8, 64, 30, Color(0.52, 0.52, 0.5))
			for row in 3:
				for col in 9:
					_px_rect(img, 3 + col * 7, 11 + row * 8, 4, 4, Color(0.2, 0.24, 0.28))
			_px_rect(img, 20, 3, 24, 6, Color(0.78, 0.78, 0.75))
			for k in 5:
				_px_rect(img, 23 + k * 4, 5, 2, 2, Color(0.1, 0.15, 0.35))
			_px_vgrad(img, 38, 48, Color(0.4, 0.4, 0.4), Color(0.32, 0.32, 0.32))
			_px_person(img, 32, 46, 30, Color(0.2, 0.24, 0.36), Color(0.4, 0.38, 0.36), false, skin, Color(0.18, 0.18, 0.2))
			return _develop(img, 0.14)
		"ecole":   # photo de classe de ta mère, fond bleu marbré
			img = Image.create_empty(48, 60, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.38, 0.48, 0.64), 0.3, 0.07, 12)
			_px_bust(img, 24, 26, 9.0, Color(0.55, 0.6, 0.35), Color(0.3, 0.18, 0.1), Color(0.86, 0.68, 0.58), 1.15)
			_px_rect(img, 18, 20, 12, 3, Color(0.3, 0.18, 0.1))
			_px_eyes(img, 24, 27, 3)
			_px_rect(img, 22, 32, 5, 1, Color(0.55, 0.25, 0.22))
			return _develop(img, 0.15)
		"aieule":   # l'arrière-grand-mère, médaillon ovale
			img = Image.create_empty(48, 60, false, Image.FORMAT_RGB8)
			_px_mottle(img, Color(0.5, 0.45, 0.38), 0.15, 0.1, 21)
			_px_bust(img, 24, 25, 8.5, Color(0.12, 0.1, 0.09), Color(0.62, 0.6, 0.56), Color(0.72, 0.62, 0.55), 1.05)
			_px_eyes(img, 24, 26, 3)
			_px_rect(img, 21, 31, 6, 1, Color(0.3, 0.22, 0.2))
			for y in 60:
				for x in 48:
					var dx := (x + 0.5 - 24.0) / 22.0
					var dy := (y + 0.5 - 30.0) / 28.0
					if dx * dx + dy * dy > 1.0:
						img.set_pixel(x, y, Color(0.85, 0.8, 0.68))
			return _develop(img, 0.12, true, 0.4)
	return _family()


## Le grand portrait de famille (studio, vers 2006) : Mamie assise, Papi debout, ta mère à six ans devant.
func _family() -> ImageTexture:
	var img := Image.create_empty(120, 150, false, Image.FORMAT_RGB8)
	_px_mottle(img, Color(0.22, 0.25, 0.3), 0.35, 0.05, 3)
	_px_ellipse(img, 60, 70, 55, 50, Color(0.3, 0.33, 0.37))
	var halo := FastNoiseLite.new()
	halo.seed = 5
	halo.frequency = 0.06
	for y in 150:
		for x in 120:
			var dx := (x - 60.0) / 55.0
			var dy := (y - 70.0) / 50.0
			if dx * dx + dy * dy < 1.0:
				var k := halo.get_noise_2d(x, y) * 0.2
				img.set_pixel(x, y, img.get_pixel(x, y).lightened(maxf(0.0, k)))
	# Papi, debout à droite : costume sombre, cravate, lunettes, bouche fermée
	_px_bust(img, 82, 50, 11.0, Color(0.1, 0.1, 0.12), Color(0.45, 0.44, 0.42), Color(0.76, 0.6, 0.5))
	_px_ellipse(img, 82, 54, 9.0, 10.5, Color(0.76, 0.6, 0.5))
	for y in range(64, 96):
		var half := maxf(0.0, 7.0 - (y - 64) * 0.2)
		_px_rect(img, 82 - half, y, half * 2.0, 1, Color(0.86, 0.85, 0.8))
	_px_rect(img, 81, 66, 3, 28, Color(0.4, 0.08, 0.09))
	_px_rect(img, 74, 51, 5, 3, Color(0.1, 0.1, 0.1))
	_px_rect(img, 85, 51, 5, 3, Color(0.1, 0.1, 0.1))
	_px_rect(img, 79, 52, 6, 1, Color(0.1, 0.1, 0.1))
	_px_rect(img, 79, 59, 7, 1, Color(0.35, 0.22, 0.2))
	# Mamie, assise à gauche : robe à fleurs, permanente, collier, sourire
	_px_bust(img, 40, 72, 11.0, Color(0.48, 0.18, 0.22), Color(0.62, 0.56, 0.48), Color(0.84, 0.66, 0.56), 1.3)
	for k in 70:
		var p := Vector2(rng.randf_range(16, 64), rng.randf_range(92, 150))
		if (p - Vector2(40, 110)).length() < 34:
			img.set_pixel(int(p.x), int(p.y), Color(0.85, 0.7, 0.68) if k % 2 == 0 else Color(0.9, 0.85, 0.7))
	for k in 11:
		var a := lerpf(0.4, PI - 0.4, k / 10.0)
		img.set_pixel(int(40 + cos(a) * 9.0), int(84 + sin(a) * 5.0), Color(0.95, 0.92, 0.85))
	_px_eyes(img, 40, 73, 3)
	_px_rect(img, 37, 79, 7, 1, Color(0.5, 0.2, 0.2))
	img.set_pixel(36, 78, Color(0.5, 0.2, 0.2))
	img.set_pixel(44, 78, Color(0.5, 0.2, 0.2))
	# ta mère, six ans, devant : robe jaune, col blanc, carré brun. Elle regarde à côté.
	_px_bust(img, 62, 112, 8.0, Color(0.78, 0.62, 0.2), Color(0.3, 0.18, 0.1), Color(0.88, 0.7, 0.6), 1.15)
	_px_rect(img, 54, 104, 16, 3, Color(0.3, 0.18, 0.1))
	_px_ellipse(img, 62, 124, 8, 3, Color(0.92, 0.9, 0.84))
	_px_eyes(img, 62, 113, 3, Color(0.06, 0.04, 0.04), -2.0)
	_px_rect(img, 60, 118, 4, 1, Color(0.45, 0.22, 0.2))
	# signature du photographe
	_px_rect(img, 96, 142, 14, 1, Color(0.7, 0.6, 0.35))
	_px_rect(img, 98, 140, 1, 2, Color(0.7, 0.6, 0.35))
	return _develop(img, 0.14, false, 0.75, 0.035)


## Tapis de couloir : champ rouge, galon bleu nuit, médaillons ; râpé jusqu'à la trame au milieu.
func _runner_texture(w: int, hgt: int) -> ImageTexture:
	var img := Image.create_empty(w, hgt, false, Image.FORMAT_RGB8)
	var red := Color(0.4, 0.075, 0.065)
	var red2 := Color(0.52, 0.14, 0.1)
	var navy := Color(0.1, 0.09, 0.15)
	var ochre := Color(0.56, 0.4, 0.17)
	var dark := Color(0.16, 0.035, 0.03)
	var weft := Color(0.46, 0.38, 0.32)
	var nz := FastNoiseLite.new()
	nz.seed = 31
	nz.frequency = 0.04
	var stains := FastNoiseLite.new()
	stains.seed = 7
	stains.frequency = 0.09
	var period := 64
	var fw := (w - 18) / 2.0
	for y in hgt:
		for x in w:
			var e := mini(x, w - 1 - x)
			var c: Color = red
			if e < 2:
				c = dark
			elif e == 2 or e == 8:
				c = ochre
			elif e < 8:
				c = navy
				if e == 5 and y % 6 < 2:
					c = ochre
			else:
				var dx := absf(x - (w - 1) / 2.0) / fw
				var dy := absf(float(y % period) - period / 2.0) / (period * 0.42)
				var dd := dx + dy
				if dd < 0.3:
					c = ochre
				elif dd < 0.55:
					c = red2
				elif dd < 0.7:
					c = navy
				elif dd > 0.98 and dd < 1.08:
					c = dark
			var u := float(x) / (w - 1)
			var path := exp(-pow((u - 0.5) / 0.26, 2.0))
			var wear := clampf(path * (0.7 + 1.1 * nz.get_noise_2d(x, y * 0.5)), 0.0, 1.0)
			var ends := clampf(1.0 - minf(y, hgt - 1 - y) / 40.0, 0.0, 1.0)
			c = c.lerp(weft, clampf(wear * 0.85 + ends * 0.4, 0.0, 0.9))
			c = c.lerp(Color(0.3, 0.24, 0.2), 0.28)
			if stains.get_noise_2d(x, y) > 0.42:
				c = c.darkened(0.35)
			c = c.darkened(rng.randf() * 0.14)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _fringe_texture() -> ImageTexture:
	var img := Image.create_empty(96, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(0, 96, 2):
		var l := rng.randi_range(4, 8)
		for y in l:
			img.set_pixel(x, y, Color(0.6, 0.54, 0.44, 1.0).darkened(rng.randf() * 0.25))
	return ImageTexture.create_from_image(img)


## Napperon en dentelle (crochet de Mamie).
func _lace_texture() -> ImageTexture:
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0) / (n / 2.0)
			var r := p.length()
			if r > 1.0:
				continue
			var a := atan2(p.y, p.x)
			var holes := sin(a * 14.0) * sin(r * PI * 7.0)
			var edge := r > 0.9 and sin(a * 28.0) < 0.2
			if holes < 0.45 and not edge:
				img.set_pixel(x, y, Color(0.82, 0.78, 0.68, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Trace laissée sur le papier peint par un cadre qu'on a décroché : le papier a jauni et noirci
## autour, pas dessous. On dessine le liseré sombre autour du rectangle resté propre.
func _ghost_texture() -> ImageTexture:
	var w := 40
	var hh := 48
	var m := 6
	var img := Image.create_empty(w, hh, false, Image.FORMAT_RGBA8)
	for y in hh:
		for x in w:
			var dx := maxf(0.0, maxf(m - x, x - (w - 1 - m)))
			var dy := maxf(0.0, maxf(m - y, y - (hh - 1 - m)))
			var d := Vector2(dx, dy).length()
			var a := 0.0
			if d > 0.0:
				a = clampf(1.0 - d / m, 0.0, 1.0) * 0.75
			img.set_pixel(x, y, Color(0.16, 0.12, 0.08, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ sol : tapis, radiateur, plante

func _runner() -> void:
	var z0 := -6.75
	var z1 := 5.65
	var w := 0.8
	var l := z1 - z0
	var holder := Node3D.new()
	holder.name = "Tapis"
	add_child(holder)
	holder.position = Vector3(4.0, 0, (z0 + z1) / 2.0)
	holder.rotation.y = 0.005   # posé à la main, pas tout à fait droit
	_box(Vector3(w, 0.007, l), Vector3(0, 0.0035, 0), _plain(Color(0.1, 0.035, 0.03), 1.0), false, holder)
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, l)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _runner_texture(48, int(l * 60.0))
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mesh(pm, Vector3(0, 0.0072, 0), _grimy(mat, 0.5), Vector3.ZERO, holder)
	var fr := StandardMaterial3D.new()
	fr.albedo_texture = _fringe_texture()
	fr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fr.roughness = 1.0
	for s in [-1.0, 1.0]:
		var fp := PlaneMesh.new()
		fp.size = Vector2(w * 0.96, 0.055)
		_mesh(fp, Vector3(0, 0.0022, s * (l / 2.0 + 0.026)), fr, Vector3(0, 0.0 if s > 0.0 else PI, 0), holder)


## Radiateur en fonte à colonnes (1 m, 0,6 m de haut, centré en y 0,45), peint crème (la peinture
## s'écaille), avec sa tête thermostatique connectée toute neuve. Contre le mur est (§ 5.2), centré en z :
## c'est lui qui transmet les S.O.S. d'Albert.
func _radiator(z: float) -> void:
	var n := 16
	var step := 0.062
	var l := n * step
	var depth := 0.15
	var x := XE - DADO - 0.04 - depth / 2.0
	var paint := _m(Color(0.6, 0.56, 0.48), 0.55, 0.25)
	var y0_ := RADIATOR_POS.y - 0.3
	var hh := 0.6
	for i in n:
		var zz := z - l / 2.0 + step * (i + 0.5)
		for side in [-1.0, 1.0]:
			_mesh(_cyl(0.019, 0.019, hh - 0.06, 8), Vector3(x + side * 0.045, y0_ + hh / 2.0, zz), paint)
		_box(Vector3(depth - 0.02, 0.05, 0.052), Vector3(x, y0_ + hh - 0.03, zz), paint)
		_box(Vector3(depth - 0.02, 0.05, 0.052), Vector3(x, y0_ + 0.03, zz), paint)
		_box(Vector3(0.03, hh - 0.1, 0.05), Vector3(x, y0_ + hh / 2.0, zz), paint)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.1, y0_ + 0.02, 0.05), Vector3(x, (y0_ + 0.02) / 2.0, z + side * (l / 2.0 - 0.09)), paint)
	# tuyau d'arrivée qui sort du parquet, robinet, tête connectée blanche
	var pipe := _m(Color(0.5, 0.47, 0.4), 0.45, 0.5)
	var pz := z + l / 2.0 + 0.045
	_mesh(_cyl(0.011, 0.011, y0_ + hh - 0.06, 8), Vector3(x + 0.03, (y0_ + hh - 0.06) / 2.0, pz), pipe)
	_mesh(_cyl(0.011, 0.011, 0.06, 8), Vector3(x + 0.03, y0_ + hh - 0.06, pz - 0.03), pipe, Vector3(PI / 2.0, 0, 0))
	_mesh(_cyl(0.016, 0.016, 0.04, 10), Vector3(x + 0.03, y0_ + hh - 0.04, pz), _m(Color(0.55, 0.45, 0.22), 0.35, 0.7))
	_mesh(_cyl(0.026, 0.026, 0.075, 16), Vector3(x + 0.03, y0_ + hh + 0.02, pz), _new_white)
	var led := _no_gi(_mesh(_sphere(0.0035, 6), Vector3(x + 0.03 - 0.024, y0_ + hh + 0.035, pz), _glow(Color(0.2, 1.0, 0.35), 2.5)))
	led.name = "LedVanne"
	_collider(Vector3(depth + 0.04, y0_ + hh + 0.08, l + 0.1), Vector3(x, (y0_ + hh + 0.08) / 2.0, z + 0.02))


func _plant() -> void:
	# sous la fenêtre du bout : la plante verte de Mamie, qu'elle arrose tous les dimanches
	prop("pottedPlant", Vector3(4.02, 0.0, ZS - 0.24), 25.0, Vector3(0, 0.82, 0), true,
		{"plant": Color(0.13, 0.2, 0.1)})


# ------------------------------------------------------------------ la console et le téléphone

func _console() -> void:
	var cz := -1.0          # § 5.2 : console en (3.52, 0, −1.0) ; Nestor au milieu, la base du téléphone en z −0.8
	var phz := cz + 0.2     # base du téléphone sans fil
	var taz := cz - 0.2     # boîtier de téléassistance
	var depth := 0.38
	var cx := XW + DADO + 0.01 + depth / 2.0
	var table := prop("sideTable", Vector3(cx, 0, cz), 90.0, Vector3(0.9, 0.8, depth))
	var top := (table.get_meta("size") as Vector3).y
	# napperon au crochet
	var lace := StandardMaterial3D.new()
	lace.albedo_texture = _lace_texture()
	lace.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lace.roughness = 1.0
	var lq := PlaneMesh.new()
	lq.size = Vector2(0.3, 0.3)
	# (pas de _grimy ici : détail + transparence découpée bloque le rendu avec llvmpipe)
	_mesh(lq, Vector3(cx + 0.02, top + 0.0015, phz + 0.04), lace, Vector3(0, 0.3, 0))
	# téléphone sans fil sur sa base : combiné debout, petite antenne, LED verte
	var ph := Node3D.new()
	ph.name = "Telephone"
	add_child(ph)
	ph.position = Vector3(cx + 0.02, top + 0.003, phz)
	ph.rotation.y = PI / 2.0 - 0.25
	var grey := _m(Color(0.16, 0.16, 0.17), 0.45)
	_box(Vector3(0.12, 0.032, 0.15), Vector3(0, 0.016, 0), grey, false, ph)
	_box(Vector3(0.07, 0.03, 0.05), Vector3(0, 0.045, -0.035), grey, false, ph)
	var hs := _box(Vector3(0.05, 0.19, 0.03), Vector3(0, 0.125, -0.03), _m(Color(0.2, 0.2, 0.21), 0.4), false, ph)
	hs.rotation.x = -0.22
	_box(Vector3(0.036, 0.03, 0.002), Vector3(0, 0.07, 0.016), _m(Color(0.4, 0.4, 0.38), 0.5), false, hs)
	_no_gi(_box(Vector3(0.03, 0.018, 0.002), Vector3(0, 0.045, 0.016), _glow(Color(0.35, 0.55, 0.3), 0.35), false, hs))
	_mesh(_cyl(0.005, 0.006, 0.05, 6), Vector3(0.018, 0.115, -0.003), grey, Vector3.ZERO, hs)
	phone_led = _glow(Color(0.15, 1.0, 0.3), 4.0)
	_no_gi(_box(Vector3(0.008, 0.005, 0.004), Vector3(0.035, 0.024, 0.075), phone_led, false, ph))
	# l'étiquette de la téléassistance collée au feutre sous la base : on ne la voit pas, on la lit
	# boîtier de téléassistance : blanc, neuf, gros bouton rouge
	var ta := Node3D.new()
	ta.name = "Teleassistance"
	add_child(ta)
	ta.position = Vector3(cx + 0.03, top, taz)
	ta.rotation.y = PI / 2.0 + 0.08
	_box(Vector3(0.16, 0.045, 0.11), Vector3(0, 0.0225, 0), _new_white, false, ta)
	_mesh(_cyl(0.026, 0.028, 0.014, 16), Vector3(0, 0.052, 0.005), _glow(Color(0.7, 0.06, 0.05), 0.25), Vector3.ZERO, ta)
	_no_gi(_box(Vector3(0.006, 0.004, 0.003), Vector3(0.06, 0.03, 0.056), _glow(Color(0.2, 1.0, 0.3), 3.0), false, ta))
	# carnet et stylo (les numéros importants, de la main de Mamie)
	var pad := _box(Vector3(0.1, 0.012, 0.15), Vector3(cx + 0.06, top + 0.006, cz - 0.36), _m(Color(0.8, 0.76, 0.62), 0.9))
	pad.rotation.y = 0.2
	_mesh(_cyl(0.004, 0.004, 0.13, 6), Vector3(cx + 0.1, top + 0.016, cz - 0.34), _m(Color(0.1, 0.15, 0.4), 0.4), Vector3(PI / 2.0, 0.5, 0))
	# prises sous la console : l'ancien conjoncteur en T et une prise ; câbles qui pendent
	var t_sock := _socket(Vector3(XW + DADO, 0.24, cz + 0.62), Vector3.RIGHT, "T")
	_plug(t_sock, true)
	var p_sock := _socket(Vector3(XW + DADO, 0.24, cz + 0.76), Vector3.RIGHT)
	_plug(p_sock)
	var bx := XW + DADO + 0.012
	_cable([Vector3(cx - 0.03, top + 0.004, phz), Vector3(bx + 0.02, top + 0.004, phz + 0.06),
		Vector3(bx + 0.02, top + 0.004, cz + 0.43), Vector3(bx, top - 0.03, cz + 0.5), Vector3(bx + 0.01, 0.262, cz + 0.62)],
		Vector3.RIGHT, false, _m(Color(0.62, 0.62, 0.6), 0.5))
	_cable([Vector3(cx - 0.04, top + 0.004, taz), Vector3(bx + 0.03, top + 0.004, taz + 0.06),
		Vector3(bx + 0.03, top + 0.004, cz + 0.44), Vector3(bx + 0.006, top - 0.02, cz + 0.52), Vector3(bx + 0.01, 0.262, cz + 0.76)],
		Vector3.RIGHT, false)
	# (boîte basse et étroite : elle ne doit pas masquer Nestor, juste derrière, au joueur qui arrive du sud)
	_look("Regarder le téléphone", Vector3(0.18, 0.12, 0.18), Vector3(cx + 0.02, top + 0.06, phz),
		"Le sans-fil de Mamie. Sous la base, l'étiquette de la téléassistance : « En cas de chute, ne bougez pas. On vous voit. »")
	# la chaise du téléphone, de l'autre côté
	prop("chair", Vector3(XW + DADO + 0.222, 0, cz - 0.9), 90.0 + 5.0, Vector3(0.4, 0.86, 0.4))


# ------------------------------------------------------------------ murs : cadres, portrait

## Cadre accroché au mur. « facing » : vers la pièce. tilt : de travers (radians).
func _frame(pos: Vector3, facing: Vector3, size: Vector2, tex: Texture2D, style := "bois", tilt := 0.0, margin := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Cadre"
	add_child(holder)
	holder.position = pos
	holder.rotation = Vector3(0, atan2(facing.x, facing.z), tilt)
	var b := 0.026 if size.x < 0.5 else 0.06
	var d := 0.022 if size.x < 0.5 else 0.04
	var fm: Material
	match style:
		"dore":
			fm = _m(Color(0.52, 0.4, 0.18), 0.4, 0.6)
		"pin":
			fm = mats.wood
		"noir":
			fm = _m(Color(0.05, 0.05, 0.05), 0.3)
		_:
			fm = mats.wood_dark
	_box(Vector3(size.x - 0.01, size.y - 0.01, 0.006), Vector3(0, 0, 0.003), mats.dark, false, holder)
	_box(Vector3(size.x, b, d), Vector3(0, size.y / 2.0 - b / 2.0, d / 2.0), fm, false, holder)
	_box(Vector3(size.x, b, d), Vector3(0, -size.y / 2.0 + b / 2.0, d / 2.0), fm, false, holder)
	_box(Vector3(b, size.y - 2.0 * b, d), Vector3(-size.x / 2.0 + b / 2.0, 0, d / 2.0), fm, false, holder)
	_box(Vector3(b, size.y - 2.0 * b, d), Vector3(size.x / 2.0 - b / 2.0, 0, d / 2.0), fm, false, holder)
	var inner := size - Vector2(2.0 * b, 2.0 * b)
	var pic := StandardMaterial3D.new()
	pic.albedo_texture = tex
	pic.roughness = 0.8
	pic.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if margin > 0.0:
		_quad(inner, Vector3(0, 0, d * 0.4), _m(Color(0.78, 0.74, 0.64), 0.9), 0.0, holder)
		_quad(inner - Vector2(2.0 * margin, 2.0 * margin), Vector3(0, 0, d * 0.4 + 0.001), pic, 0.0, holder)
	else:
		_quad(inner, Vector3(0, 0, d * 0.4), pic, 0.0, holder)
	var g := _quad(inner, Vector3(0, 0, d * 0.8), _glass, 0.0, holder)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


func _frames() -> void:
	var w := Vector3.RIGHT     # accrochés au mur ouest, ils regardent vers +x
	var e := Vector3.LEFT      # mur est, vers -x
	# bout nord, mur est : Papi au labo, la plage
	_frame(Vector3(XE, 1.66, -6.3), e, Vector2(0.34, 0.27), _photo("labo"), "noir", 0.0, 0.03)
	# mur ouest, entre le portrait et la porte des grands-parents : l'arrière-grand-mère
	_frame(Vector3(XW, 1.6, -5.6), w, Vector2(0.3, 0.38), _photo("aieule"), "dore", -0.025)
	# mur ouest, de part et d'autre de la console : le mariage, la photo de classe ; Noël au-dessus
	_frame(Vector3(XW, 1.72, -2.0), w, Vector2(0.26, 0.34), _photo("mariage"), "dore", 0.02, 0.025)
	_frame(Vector3(XW, 1.5, -1.0), w, Vector2(0.36, 0.28), _photo("noel"), "pin", -0.015)
	_frame(Vector3(XW, 1.66, 0.2), w, Vector2(0.2, 0.25), _photo("ecole"), "bois", 0.04)
	# mur est, au-dessus du radiateur : la trace d'un cadre décroché
	_decal(_ghost_texture(), Vector3(XE, 1.62, -2.5), Vector3.LEFT, Vector3.UP, 0.34, 0.41, 0.06)
	_mesh(_cyl(0.003, 0.003, 0.02, 6), Vector3(XE - 0.01, 1.83, -2.5), mats.metal, Vector3(0, 0, PI / 2.0))
	# bout sud, mur ouest : la plage ; mur est, près de la fenêtre : le jardin
	_frame(Vector3(XW, 1.6, 5.2), w, Vector2(0.4, 0.31), _photo("plage"), "bois", 0.03, 0.03)
	_frame(Vector3(XE, 1.58, 5.6), e, Vector2(0.42, 0.32), _photo("jardin"), "pin", 0.0, 0.03)
	# mur est, entre l'escalier et le bureau
	_frame(Vector3(XE, 1.62, 2.6), e, Vector2(0.3, 0.38), _photo("ecole"), "dore", -0.03)


## Le portrait « 1996 » au bout nord (§ 5.2) : image 0,6 × 0,8 (portrait_1996.png, surexposé, sans
## visages) dans un cadre doré.
func _portrait() -> void:
	var c := Vector3(4.0, 1.6, ZN)
	_frame(c, Vector3.BACK, Vector2(0.72, 0.92), load("res://assets/images/portrait_1996.png"), "dore", 0.0)
	# le cordon, le clou
	_mesh(_cyl(0.004, 0.004, 0.02, 6), Vector3(4.0, 2.16, ZN + 0.01), mats.metal, Vector3(PI / 2.0, 0, 0))
	_cable([Vector3(3.85, 2.05, ZN + 0.008), Vector3(4.0, 2.16, ZN + 0.008), Vector3(4.15, 2.05, ZN + 0.008)],
		Vector3.BACK, false, _m(Color(0.3, 0.25, 0.15), 0.8), 0.0015)
	_look("Regarder le portrait", Vector3(0.76, 0.96, 0.1), c + Vector3(0, 0, 0.05), TXT_PORTRAIT)


# ------------------------------------------------------------------ plafond : ampoules connectées

## L1, L2, L3 : tulipes des années 70 et, dedans, les ampoules connectées du fournisseur d'énergie
## (SmartBulb « ampoule_couloir_1 » à « _3 », du nord au sud) : Haunt.move les fait vaciller quand elle
## passe ; le couloir les pilote (flicker, set_dim, chain_lights) par leur niveau.
func _ceiling_lights() -> void:
	for li in LIGHT_Z.size():
		var z: float = LIGHT_Z[li]
		var top := Vector3(4.0, 2.6, z)
		_mesh(_cyl(0.05, 0.055, 0.022), top + Vector3(0, -0.011, 0), _m(Color(0.7, 0.66, 0.58), 0.6))
		_mesh(_cyl(0.0035, 0.0035, 0.22, 6), top + Vector3(0, -0.13, 0), _plain(Color(0.12, 0.08, 0.05), 0.8))
		_mesh(_cyl(0.018, 0.02, 0.05), top + Vector3(0, -0.26, 0), _m(Color(0.5, 0.4, 0.2), 0.4, 0.7))
		# tulipe en verre ambré, des années 70, et dedans l'ampoule du fournisseur d'énergie
		var shade := _cyl(0.03, 0.115, 0.14, 20)
		# (pas de CULL_DISABLED : avec llvmpipe, cette variante de shader bloque le rendu)
		var sm := _plain(Color(0.55, 0.36, 0.18), 0.35)
		sm.emission_enabled = true
		sm.emission = Color(1.0, 0.6, 0.3)
		sm.emission_energy_multiplier = 0.35
		shade_mats.append(sm)
		_no_gi(_mesh(shade, top + Vector3(0, -0.31, 0), sm))
		_mesh(_cyl(0.02, 0.02, 0.03, 12), top + Vector3(0, -0.3, 0), _new_white)
		var bm := _glow(Color(1.0, 0.78, 0.5), BULB_GLOW)
		bulb_mats.append(bm)
		_no_gi(_mesh(_sphere(0.032), top + Vector3(0, -0.37, 0), bm))
		var sb := SmartBulb.new()
		sb.name = "L%d" % (li + 1)
		sb.device_id = "ampoule_couloir_%d" % (li + 1)
		sb.room_id = "couloir"
		sb.energy = LIGHT_ENERGY
		sb.light_range = 4.0
		sb.bulb_glow = BULB_GLOW
		sb.show_bulb = false          # (l'ampoule visible est celle de la tulipe)
		add_child(sb)
		sb.position = top + Vector3(0, -0.345, 0)
		sb.build()
		sb.add_glow_material(bm, BULB_GLOW)
		sb.add_glow_material(sm, 0.35)
		smart_bulbs.append(sb)
		bulbs.append(sb.light)


func _apply_bulb(i: int, k: float) -> void:
	if not switch_on:
		k = 0.0                  # interrupteur coupé : plus de courant, rien ne s'allume
	# (l'ampoule connectée applique le niveau à sa lumière, à l'ampoule et à la tulipe)
	smart_bulbs[i].set_level(k)


func _apply_all() -> void:
	for i in bulbs.size():
		_apply_bulb(i, dim)


## Les ampoules connectées vacillent pendant « seconds » secondes, puis reviennent à leur niveau
## (celui de set_dim, même s'il a changé pendant ce temps).
func flicker(seconds := 1.5) -> void:
	_flicker_id += 1
	_chain_id += 1
	var my := _flicker_id
	var t := 0.0
	if not bulbs.is_empty():
		Sfx.play_at("metalClick", bulbs[1].global_position, -16.0, 0.45)
	while t < seconds and my == _flicker_id:
		for i in bulbs.size():
			var k := 0.0 if rng.randf() < 0.45 else rng.randf_range(0.25, 1.6)
			_apply_bulb(i, k * dim)
		var step := rng.randf_range(0.04, 0.15)
		await get_tree().create_timer(step, false).timeout
		if not is_inside_tree():
			return
		t += step
	if my == _flicker_id:
		_apply_all()


## Les ampoules s'allument l'une après l'autre, du sud vers le nord (vers la porte d'Henriette),
## puis s'éteignent toutes et restent éteintes (dim = 0). Un flicker() ou un set_dim() lancé pendant
## la séquence l'interrompt.
func chain_lights(step := 0.7, hold := 1.0) -> void:
	_flicker_id += 1
	_chain_id += 1
	var my := _chain_id
	if _dim_tw:
		_dim_tw.kill()
	for i in bulbs.size():
		_apply_bulb(i, 0.0)
	for i in range(bulbs.size() - 1, -1, -1):   # LIGHT_Z va du nord au sud : on part du sud
		await get_tree().create_timer(step, false).timeout
		if not is_inside_tree() or my != _chain_id:
			return
		_apply_bulb(i, 1.0)
		Sfx.play_at("metalClick", bulbs[i].global_position, -20.0, 0.5)
	await get_tree().create_timer(hold, false).timeout
	if not is_inside_tree() or my != _chain_id:
		return
	dim = 0.0
	_apply_all()


## Règle les ampoules : 1 = normal, 0 = éteintes. « seconds » : fondu.
func set_dim(k: float, seconds := 0.0) -> void:
	_chain_id += 1
	if _dim_tw:
		_dim_tw.kill()
	k = clampf(k, 0.0, 1.0)
	if seconds <= 0.0:
		dim = k
		_apply_all()
		return
	_dim_tw = create_tween()
	_dim_tw.tween_method(func(v: float) -> void:
		dim = v
		_apply_all(), dim, k, seconds)


# ------------------------------------------------------------------ la caméra de l'assurance

func _camera() -> void:
	var root := Node3D.new()
	root.name = "CameraDome"
	add_child(root)
	root.position = CAM_POS
	_mesh(_cyl(0.075, 0.08, 0.028, 24), Vector3(0, -0.014, 0), _new_white, Vector3.ZERO, root)
	_mesh(_cyl(0.066, 0.072, 0.012, 24), Vector3(0, -0.034, 0), _plain(Color(0.7, 0.7, 0.68), 0.35), Vector3.ZERO, root)
	# le micro, côté couloir : Papi a mis un bout de scotch dessus
	_box(Vector3(0.006, 0.006, 0.004), Vector3(0, -0.014, 0.078), mats.dark, false, root)
	var tape := _box(Vector3(0.032, 0.02, 0.003), Vector3(0.002, -0.014, 0.0805), _plain(Color(0.7, 0.62, 0.45), 0.5), false, root)
	tape.rotation.z = 0.15
	# la tête mobile, sous le dôme fumé
	cam_pivot = Node3D.new()
	cam_pivot.name = "Tete"
	cam_pivot.position = Vector3(0, -0.07, 0)
	root.add_child(cam_pivot)
	cam_pivot.rotation = Vector3(_cam_rest.x, _cam_rest.y, 0)
	var black := _plain(Color(0.05, 0.05, 0.055), 0.35)
	_mesh(_sphere(0.034, 16), Vector3.ZERO, black, Vector3.ZERO, cam_pivot)
	_mesh(_cyl(0.017, 0.017, 0.034, 16), Vector3(0, 0, -0.03), black, Vector3(PI / 2.0, 0, 0), cam_pivot)
	var lens := _plain(Color(0.03, 0.04, 0.08), 0.05)
	lens.metallic_specular = 1.0
	_mesh(_cyl(0.011, 0.011, 0.003, 16), Vector3(0, 0, -0.048), lens, Vector3(PI / 2.0, 0, 0), cam_pivot)
	cam_led_mat = _glow(Color(1.0, 0.06, 0.04), 7.0)
	_no_gi(_mesh(_sphere(0.0045, 8), Vector3(0.021, 0.012, -0.036), cam_led_mat, Vector3.ZERO, cam_pivot))
	cam_led = OmniLight3D.new()
	cam_led.name = "LedCamera"
	cam_led.light_color = Color(1.0, 0.08, 0.05)
	cam_led.light_energy = 0.08
	cam_led.omni_range = 0.5
	cam_led.position = Vector3(0.02, 0.0, -0.08)
	cam_pivot.add_child(cam_led)
	var dome := SphereMesh.new()
	dome.radius = 0.066
	dome.height = 0.132
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 8
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.05, 0.06, 0.5)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.06
	glass.metallic_specular = 1.0
	var dm := _mesh(dome, Vector3(0, -0.04, 0), glass, Vector3(PI, 0, 0), root)
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# son câble : au plafond jusqu'au coin, puis dans l'angle des murs, jusqu'à l'alimentation
	var cy := 2.6 - 0.0035
	_cable([Vector3(4.07, cy, CAM_POS.z), Vector3(4.56, cy, CAM_POS.z), Vector3(4.56, cy, -7.25)], Vector3.DOWN)
	_cable([Vector3(4.683, 2.49, ZN + 0.005), Vector3(4.683, 1.19, ZN + 0.005), Vector3(4.665, 1.165, ZN + 0.005)], Vector3.BACK)
	_box(Vector3(0.07, 0.11, 0.035), Vector3(4.645, 1.12, ZN + 0.0175), _new_white)
	_no_gi(_box(Vector3(0.006, 0.006, 0.003), Vector3(4.66, 1.15, ZN + 0.036), _glow(Color(0.2, 0.6, 1.0), 3.0)))
	var zc := ZN + 0.004
	_cable([Vector3(4.645, 1.065, zc), Vector3(4.645, 0.97, zc), Vector3(4.645, 0.97, ZN + 0.06),
		Vector3(4.645, 0.913, ZN + 0.06), Vector3(4.645, 0.913, ZN + DADO + 0.004), Vector3(4.645, 0.3, ZN + DADO + 0.004),
		Vector3(4.625, 0.262, ZN + DADO + 0.03)], Vector3.BACK)
	var sock := _socket(Vector3(4.62, 0.24, ZN + DADO), Vector3.BACK)
	_plug(sock)
	var it := _interactable("Regarder la caméra", Vector3(0.24, 0.2, 0.24), CAM_POS + Vector3(0, -0.07, 0), self, LAYER_INTERACT, 2.8)
	it.used.connect(func(_i: Interactable) -> void:
		Game.hint(TXT_CAMERA, 4.5)
		look_at_player_once())


## La caméra suit doucement une cible (null : elle retourne au repos).
func track(target: Node3D) -> void:
	cam_target = target
	_cam_once = false


## La caméra se tourne vers le joueur, une fois, et reste pointée là (si elle le suit déjà, elle continue).
func look_at_player_once() -> void:
	var p: Node3D = house.player if house else null
	if p == null or (cam_target == p and not _cam_once):
		return
	cam_target = p
	_cam_once = true


func _aim_of(target: Node3D) -> Vector2:
	var tp := target.global_position
	if target is CharacterBody3D:
		tp.y += 1.35
	var d := tp - cam_pivot.global_position
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	return Vector2(clampf(pitch, -1.45, -0.05), yaw)


func _process(delta: float) -> void:
	if cam_pivot == null:
		return
	_update_cam_led(delta)
	var want := _cam_rest
	if cam_target and is_instance_valid(cam_target):
		want = _aim_of(cam_target)
	var dyaw := wrapf(want.y - cam_pivot.rotation.y, -PI, PI)
	var dpitch := want.x - cam_pivot.rotation.x
	# moteur pas à pas : vitesse limitée, ralentit en arrivant
	var vy := clampf(absf(dyaw) * 2.2, 0.1, 0.9) * delta
	var vp := clampf(absf(dpitch) * 2.2, 0.08, 0.6) * delta
	cam_pivot.rotation.y += clampf(dyaw, -vy, vy)
	cam_pivot.rotation.x += clampf(dpitch, -vp, vp)
	var moving := absf(dyaw) > 0.015 or absf(dpitch) > 0.015
	if moving:
		_motor_t -= delta
		if _motor_t <= 0.0:
			_motor_t = 0.26
			Sfx.play_at("metalClick", cam_pivot.global_position, -27.0, 0.42, 1.2)
	else:
		_motor_t = 0.0
		if _cam_once:
			_cam_once = false
			_cam_rest = Vector2(cam_pivot.rotation.x, cam_pivot.rotation.y)
			cam_target = null


## LED de la caméra dôme : si le joueur, dans le couloir, fixe l'objectif STARE_SEC secondes, elle
## s'éteint LED_OFF_SEC secondes (indice « Elle a éteint sa lumière… », événement « camera_led_eteinte »).
func _update_cam_led(delta: float) -> void:
	if _led_off_t > 0.0:
		_led_off_t -= delta
		if _led_off_t <= 0.0:
			_set_cam_led(true)
		return
	var p: Node3D = house.player if house else null
	var watching := p != null and house.current == self and p.has_method("looking_at_point") \
		and bool(p.call("looking_at_point", cam_pivot.global_position, STARE_DEG, 9.0))
	_stare_t = _stare_t + delta if watching else 0.0
	if _stare_t >= STARE_SEC:
		_stare_t = 0.0
		_led_off_t = LED_OFF_SEC
		_set_cam_led(false)
		Game.hint(TXT_CAMERA_LED, 4.0)
		var hn := Haunt.of(get_tree())
		if hn:
			hn.story_event("camera_led_eteinte")


func _set_cam_led(on: bool) -> void:
	cam_led_on = on
	if cam_led_mat:
		cam_led_mat.emission_energy_multiplier = 7.0 if on else 0.0
	if cam_led:
		cam_led.light_energy = 0.08 if on else 0.0


# ------------------------------------------------------------------ thermostat, détecteur de fumée

func _thermostat() -> void:
	var c := Vector3(XE, 1.5, -0.1)
	_box(Vector3(0.024, 0.13, 0.12), c + Vector3(-0.012, 0, 0), _new_white)
	_box(Vector3(0.004, 0.06, 0.086), c + Vector3(-0.025, 0.014, 0), _plain(Color(0.02, 0.02, 0.025), 0.2))
	for k in 2:
		_box(Vector3(0.006, 0.014, 0.022), c + Vector3(-0.026, -0.042, -0.02 + k * 0.04), _plain(Color(0.75, 0.75, 0.73), 0.4))
	thermostat = Device.new()
	thermostat.name = "Thermostat"
	thermostat.kind = "thermostat"
	thermostat.screen_size = Vector2(0.078, 0.052)
	thermostat.res = Vector2i(120, 80)
	thermostat.glow_color = Color(0.55, 0.8, 1.0)
	thermostat.glow_energy = 0.1
	thermostat.glow_range = 1.2
	add_child(thermostat)
	thermostat.position = c + Vector3(-0.0275, 0.014, 0)
	thermostat.rotation.y = -PI / 2.0
	thermostat.build()
	thermostat.label.add_theme_font_size_override("font_size", 34)
	thermostat.say("3:12", Color(0.75, 0.92, 1.0), Color(0.01, 0.02, 0.03))
	thermostat.is_on = true
	thermostat.set_param("power", 1.0)
	thermostat.set_param("brightness", 0.75)
	thermostat.light.light_energy = thermostat.glow_energy
	thermostat.light.shadow_enabled = false
	for mi in thermostat.find_children("*", "MeshInstance3D", false, false):
		_no_gi(mi as MeshInstance3D)
	# son câble monte se cacher derrière la corniche
	_cable([Vector3(XE - 0.004, 1.565, -0.1), Vector3(XE - 0.004, 2.5, -0.1)], Vector3.LEFT)
	_look("Regarder le thermostat", Vector3(0.1, 0.18, 0.18), c + Vector3(-0.03, 0, 0),
		"Le thermostat du fournisseur d'énergie. Il devrait afficher la température. Il affiche 3:12.")


func _smoke_detector() -> void:
	var p := Vector3(4.0, 2.6, 2.2)
	_mesh(_cyl(0.06, 0.066, 0.034, 24), p + Vector3(0, -0.017, 0), _new_white)
	_mesh(_cyl(0.04, 0.04, 0.006, 20), p + Vector3(0, -0.036, 0), _plain(Color(0.45, 0.45, 0.44), 0.6))
	for k in 3:
		_mesh(_cyl(0.012 + k * 0.01, 0.012 + k * 0.01, 0.002, 20), p + Vector3(0, -0.0405 - (2 - k) * 0.0005, 0), _plain(Color(0.2, 0.2, 0.2) if k % 2 == 0 else Color(0.6, 0.6, 0.58), 0.6))
	smoke_led = _glow(Color(0.15, 1.0, 0.3), 0.0)
	_no_gi(_mesh(_sphere(0.004, 8), p + Vector3(0.042, -0.034, 0), smoke_led))
	var tw := create_tween().set_loops()
	tw.tween_interval(2.3)
	tw.tween_callback(func() -> void: smoke_led.emission_energy_multiplier = 8.0)
	tw.tween_interval(0.08)
	tw.tween_callback(func() -> void: smoke_led.emission_energy_multiplier = 0.0)
	# détecteur « connecté » : son câble file au plafond vers le mur est
	var cy := 2.6 - 0.0035
	_cable([Vector3(4.066, cy, 2.2), Vector3(4.635, cy, 2.2)], Vector3.DOWN)   # jusque sous la corniche


# ------------------------------------------------------------------ traces

func _traces() -> void:
	var stain: Texture2D = load("res://assets/decals/stain_water.png")
	var mold: Texture2D = load("res://assets/decals/mold.png")
	# infiltration sous la fenêtre du bout, et auréole au plafond
	_decal(stain, Vector3(4.15, 2.6, 5.5), Vector3.DOWN, Vector3.BACK, 1.1, 0.9, 0.3)
	_decal(stain, Vector3(3.7, 0.55, ZS), Vector3.FORWARD, Vector3.UP, 0.6, 0.7, 0.2, Color(1, 1, 1, 0.7))
	# moisissure dans l'angle nord-ouest, sous le plafond
	_decal(mold, Vector3(XW, 2.25, -6.95), Vector3.RIGHT, Vector3.UP, 0.9, 0.7, 0.2)
	_decal(mold, Vector3(3.55, 2.3, ZN), Vector3.BACK, Vector3.UP, 0.6, 0.6, 0.2, Color(1, 1, 1, 0.6))


# ------------------------------------------------------------------ Nestor, sur la console

const NESTOR_POS := Vector2(3.52, -1.0)   # (x, z) ; posé sur le plateau de la console
const TXT_NESTOR := "L'enceinte de la téléassistance. Un anneau de lumière, %s selon la jauge."
const TXT_NESTOR_DEBRANCHE := "La prise est débranchée. L'anneau reste allumé : batterie interne, dix heures, dit l'étiquette."
const TXT_CABLE := "Ton câble. Quinze mètres, de la box du bureau jusqu'à la chambre. Scotché par toi, cet après-midi."


## L'enceinte Nestor, entre le téléphone et le boîtier de téléassistance ; son câble blanc descend
## derrière la console jusqu'à une prise que l'installateur a fermée d'un cache vissé.
func _nestor() -> void:
	var table: Node3D = props.get("sideTable")
	var top := 0.8
	if table:
		top = (table.get_meta("size") as Vector3).y
	nestor = Nestor.new()
	nestor.name = "Nestor"
	nestor.device_id = "nestor"
	nestor.room_id = "couloir"
	add_child(nestor)
	nestor.position = Vector3(NESTOR_POS.x, top, NESTOR_POS.y)
	nestor.rotation.y = PI / 2.0      # face avant vers le couloir (+x)
	nestor.build()
	# câble : de l'arrière de l'enceinte au bord du plateau, puis le long du mur jusqu'à la prise
	var bx := XW + DADO + 0.012
	var sz := NESTOR_POS.y - 0.42
	_cable([Vector3(NESTOR_POS.x - 0.05, top + 0.004, NESTOR_POS.y), Vector3(bx + 0.04, top + 0.004, NESTOR_POS.y - 0.02),
		Vector3(bx + 0.04, top + 0.004, NESTOR_POS.y - 0.25), Vector3(bx + 0.01, top - 0.02, NESTOR_POS.y - 0.3),
		Vector3(bx + 0.006, 0.4, sz), Vector3(bx + 0.006, 0.28, sz)], Vector3.RIGHT, false)
	var sock := _socket(Vector3(XW + DADO, 0.24, sz), Vector3.RIGHT)
	nestor_plug = Node3D.new()
	nestor_plug.name = "FicheNestor"
	sock.add_child(nestor_plug)
	_box(Vector3(0.036, 0.042, 0.03), Vector3(0, 0, 0.03), _new_white, false, nestor_plug)
	# le cache-prise vissé de l'installateur (il faut un tournevis)
	var cover := _plain(Color(0.85, 0.85, 0.83, 1.0), 0.35)
	_box(Vector3(0.09, 0.1, 0.004), Vector3(0, 0, 0.047), cover, false, nestor_plug)
	_mesh(_cyl(0.004, 0.004, 0.003, 8), Vector3(0, 0.04, 0.05), mats.metal, Vector3(PI / 2.0, 0, 0), nestor_plug)
	_mesh(_cyl(0.004, 0.004, 0.003, 8), Vector3(0, -0.04, 0.05), mats.metal, Vector3(PI / 2.0, 0, 0), nestor_plug)
	nestor_it = _interactable("Regarder l'enceinte", Vector3(0.14, 0.22, 0.14), Vector3(NESTOR_POS.x, top + 0.09, NESTOR_POS.y), self, LAYER_INTERACT, 2.2)
	nestor_it.used.connect(func(_i: Interactable) -> void:
		if not nestor_unplugged and Game.has_item("tournevis"):
			unplug_nestor()
		elif nestor_unplugged:
			Game.hint(TXT_NESTOR_DEBRANCHE, 5.0)
		else:
			Game.hint(TXT_NESTOR % nestor.ring_color_name(), 4.5))
	Game.inventory_changed.connect(_update_nestor_label)
	_update_nestor_label()


func _update_nestor_label() -> void:
	if nestor_it == null or not is_instance_valid(nestor_it):
		return
	nestor_it.label = "Débrancher l'enceinte" if Game.has_item("tournevis") and not nestor_unplugged else "Regarder l'enceinte"


## Débrancher Nestor (avec le tournevis) : la fiche sort, l'anneau reste allumé (batterie interne).
func unplug_nestor(quiet := false) -> void:
	if nestor_unplugged:
		return
	nestor_unplugged = true
	Game.set_flag("nestor_debranche", true)
	if nestor_plug:
		nestor_plug.visible = false
	_update_nestor_label()
	if quiet:
		return
	Sfx.play_at("metalClick", nestor.global_position, -10.0, 0.9, 1.5)
	Game.hint(TXT_NESTOR_DEBRANCHE, 5.5)
	var hn := Haunt.of(get_tree())
	if hn:
		hn.story_event("nestor_debranche")


# ------------------------------------------------------------------ l'interrupteur des trois ampoules

const SWITCH_POS := Vector3(3.31, 1.1, 0.75)


func _switch() -> void:
	var holder := Node3D.new()
	holder.name = "Interrupteur"
	add_child(holder)
	holder.position = Vector3(XW, SWITCH_POS.y, SWITCH_POS.z)
	holder.rotation.y = PI / 2.0      # face +x
	_box(Vector3(0.082, 0.082, 0.006), Vector3(0, 0, 0.003), _m(Color(0.5, 0.47, 0.4), 0.5), false, holder)
	_box(Vector3(0.074, 0.074, 0.01), Vector3(0, 0, 0.005), _m(Color(0.66, 0.62, 0.53), 0.5), false, holder)
	for sy in [-1.0, 1.0]:
		_mesh(_cyl(0.003, 0.003, 0.002, 8), Vector3(0, sy * 0.028, 0.0105), mats.metal, Vector3(PI / 2.0, 0, 0), holder)
	switch_rocker = Node3D.new()
	switch_rocker.position = Vector3(0, 0, 0.011)
	holder.add_child(switch_rocker)
	_box(Vector3(0.034, 0.042, 0.008), Vector3(0, 0, 0.003), _m(Color(0.7, 0.67, 0.58), 0.45), false, switch_rocker)
	switch_rocker.rotation.x = -0.16 if switch_on else 0.16
	switch_it = _interactable("Éteindre la lumière", Vector3(0.12, 0.14, 0.14), Vector3(XW + 0.05, SWITCH_POS.y, SWITCH_POS.z), self, LAYER_INTERACT, 2.0)
	switch_it.used.connect(func(_i: Interactable) -> void:
		set_switch(not switch_on)
		var hn := Haunt.of(get_tree())
		if hn:
			hn.story_event("lumiere", {"room": "couloir", "on": switch_on}))


## L'interrupteur mural : coupé, plus aucune ampoule ne s'allume (ni chain_lights, ni flicker) ;
## remis, les ampoules connectées repartent à pleine puissance (comme toutes les ampoules connectées
## après une coupure), jusqu'à ce qu'elle les baisse.
## keep_level : ne pas remettre les ampoules à pleine puissance (rechargement d'une sauvegarde).
func set_switch(on: bool, quiet := false, keep_level := false) -> void:
	switch_on = on
	Game.set_flag("interrupteur_couloir", on)
	if switch_rocker:
		switch_rocker.rotation.x = -0.16 if on else 0.16
	if switch_it:
		switch_it.label = "Éteindre la lumière" if on else "Allumer la lumière"
	for n in find_children("*", "", true, false):
		if n is SmartBulb:
			(n as SmartBulb).set_powered(on)
	if on and not keep_level:
		_chain_id += 1
		_flicker_id += 1
		if _dim_tw:
			_dim_tw.kill()
		dim = 1.0
	_apply_all()
	if not quiet:
		Sfx.play_at("metalClick", Vector3(XW, SWITCH_POS.y, SWITCH_POS.z), -10.0, 1.3, 1.5)


# ------------------------------------------------------------------ le câble réseau d'Alexandre

## Le câble blanc d'Alexandre : il sort sous la porte de la chambre (P1), longe la plinthe ouest,
## traverse le couloir sur le tapis et passe sous la porte du bureau (P7). Scotch gris aux endroits
## du plan (z 1.6, 2.6, 3.6 et x 4.0). La suite, dans le bureau, est posée par bureau.gd.
func _network_cable() -> void:
	var xw := XW + DADO + 0.04   # devant la plinthe (le plan dit 3.34 : la plinthe est là)
	var z := 4.15
	var y := 0.008
	var yr := 0.0105             # sur le tapis
	var pts := [Vector3(3.26, 0.012, 1.0), Vector3(3.3, y, 1.0), Vector3(xw, y, 1.0), Vector3(xw, y, z),
		Vector3(3.585, y, z), Vector3(3.6, yr, z), Vector3(4.4, yr, z), Vector3(4.415, y, z),
		Vector3(4.68, y, z), Vector3(4.69, 0.015, z), Vector3(4.81, 0.015, z)]
	var mat := _plain(Color(0.92, 0.92, 0.9), 0.35)
	_cable(pts, Vector3.UP, false, mat, 0.003)
	var grey := _plain(Color(0.66, 0.66, 0.64), 0.35, 0.3)
	for p in [Vector3(xw, y, 1.6), Vector3(xw, y, 2.6), Vector3(xw, y, 3.6), Vector3(4.0, yr, z)]:
		var along := Vector3.BACK if p.z != z else Vector3.RIGHT
		var t := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.055, 0.0074, 0.036)
		t.mesh = tb
		t.material_override = grey
		t.transform = Transform3D(Basis(Vector3.UP.cross(along).normalized(), Vector3.UP, along), p + Vector3(0, -0.0006, 0))
		t.rotate_object_local(Vector3.UP, rng.randf_range(-0.15, 0.15))
		add_child(t)
	var it := _interactable("Regarder le câble", Vector3(0.16, 0.1, 1.0), Vector3(xw + 0.02, 0.05, 2.4), self, LAYER_INTERACT, 2.0)
	it.used.connect(func(_i: Interactable) -> void: Game.hint(TXT_CABLE, 5.0))


# ------------------------------------------------------------------ CAM 1, dans la caméra dôme

## Le flux de la caméra dôme (CAM 1 COULOIR, 160 × 90, 6 images/s, fov 80°) : posé sur la tête mobile,
## il suit ses mouvements. Coupé tant qu'on ne regarde pas son image (console du bureau).
func _feed_cam() -> void:
	if cam_pivot == null:
		return
	feed_cam = FeedCam.new()
	feed_cam.name = "CamFlux1"
	feed_cam.title = "CAM 1 COULOIR"
	feed_cam.fov = 80.0
	feed_cam.ir = 1.2
	cam_pivot.add_child(feed_cam)
	feed_cam.position = Vector3(0, 0, -0.055)
	feed_cam.build()


## Une image de CAM 1, telle que l'imprimante la sort (await couloir.photo()).
func photo() -> Image:
	if feed_cam == null:
		return null
	return await feed_cam.capture_still("CAM 1")


# ------------------------------------------------------------------ sauvegarde

## Réapplique l'état après un chargement (interrupteur, enceinte débranchée). Le niveau des ampoules
## (set_dim) appartient au scénario.
func restore() -> void:
	set_switch(bool(Game.flag("interrupteur_couloir", true)), true, true)
	if Game.flag("nestor_debranche", false):
		unplug_nestor(true)
