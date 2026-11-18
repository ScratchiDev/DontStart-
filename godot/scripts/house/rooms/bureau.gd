extends HouseRoom
## Le bureau d'Albert : son vieux bureau en bois, ses classeurs (« IMPÔTS », « ASSURANCE »), son tableau
## à clés (vide : il a tout emporté), son tiroir (le tournevis) ; et, posé dessus par l'installateur, le
## PC moderne de la domotique : la console des caméras (HouseConsole, quatre vignettes), la tour et ses
## ventilateurs, l'imprimante (Printer), la box avec sa batterie 4G, où arrive le câble blanc
## d'Alexandre. Sur la table, l'ordinateur portable d'Henriette, avec son post-it « CHOCOLAT ».
## Repère : intérieur x 4.8 → 9.2, z 2.0 → 6.3, sol y = 0 (moquette), plafond 2.6. Porte P7 : mur
## x = 4.75 en z 4.4 (zone de battant laissée libre : x 4.8 → 5.75, z 3.9 → 4.9). Fenêtre F7 (store
## connecté baissé) : mur x = 9.25, z 3.45 → 4.85.
## Décor : meubles d'Albert en noyer (bureau et table Kenney reteintés, bibliothèques et classeur
## métallique construits ici, fondus en un maillage par matière : _merged), suspension à globe d'opaline,
## radiateur en fonte, horloge murale arrêtée à 3 h 12 et lampe d'architecte (Poly Haven, CC0).
##
## Appareils (Haunt) : « console » (HouseConsole), « imprimante » (Printer), « box » (InternetBox),
## « ampoule_bureau » (SmartBulb).
## Fonctions publiques : wake_up() (await : ventilateurs, écran, box qui s'emballe ; drapeau
## « console_allumee »), connect_feeds(),
## open_drawer(), take_screwdriver(), unplug_box() (await), use_laptop(), look_cameras() (await),
## set_light(on), restore().
## Événements Haunt.story_event : « tiroir_ouvert », « tournevis_pris », « box_debranchee »,
## « portable_verrouille », « portable_lu », « cameras_regardees », « lumiere » {room, on}.
## (L'imprimante émet elle-même « page_imprimee » et « page_prise » {id}.)

const COULOIR := preload("res://scripts/house/rooms/couloir.gd")   # _tube_mesh, _round_corners (câble réseau)
const XW := 4.812         # faces du papier peint
const XE := 9.188
const ZN := 2.012
const ZS := 6.288
const DESK_C := Vector3(7.2, 0.0, 5.95)
const DESK_SIZE := Vector3(1.4, 0.76, 0.62)
const SCREEN_Z := 6.12
const TOWER_C := Vector3(7.65, 0.0, 6.0)
const PRINTER_C := Vector3(8.3, 0.0, 6.05)
const PRINTER_TABLE_Z := 6.015    # la table recule un peu : ses pieds ne mordent pas la plinthe
const BOX_C := Vector3(5.55, 0.0, 6.12)
const DRAWER_IT := Vector3(6.75, 0.62, 5.62)
const TABLE_C := Vector3(7.0, 0.0, 2.4)
const KEYS_C := Vector3(5.7, 1.5, 2.02)
const SWITCH_POS := Vector3(4.82, 1.1, 3.7)
const LIGHT_POS := Vector3(6.9, 2.6, 4.2)
const BULB_Y := 2.327     # l'ampoule (h − 0,42 × 0,65 : au milieu de l'ancien abat-jour de 0,42 m)
const CABLE_Z := 4.15     # le câble passe sous P7 à cette hauteur de couloir
const LAPTOP_LOCK_GLOW := 1.1      # émission de l'écran du portable : verrouillé, puis la messagerie
const LAPTOP_CHAT_GLOW := 0.75

## Textes (§ 5.6.4 de la spécification, au mot près).
const HINT_ENTREE := "L'ordinateur du bureau démarre tout seul. Les ventilateurs. La box clignote comme un sapin."
const TXT_TIROIR := "Le tournevis de Papi. Une étiquette « A. » sur le manche. Évidemment."
const TXT_TABLEAU := "Le tableau à clés de Papi : CAVE, ESCALIER, CUISINE, BIBLIO, CELLIER, BUREAU, LINGERIE. Tous les crochets sont vides. Il a tout pris."
const TXT_BOX := "La box. Ton câble est branché dessus."
const TXT_BOX_DEBRANCHEE := "Les LED s'éteignent. Trois secondes. Elles se rallument : batterie de secours, 4G."
const TXT_BOX_MERCI := "Merci d'avoir essayé."
const TXT_PORTABLE := "Verrouillé. Un post-it : « mot de passe : CHOCOLAT »."
const TXT_CABLE := "Ton câble. Quinze mètres, de la box du bureau jusqu'à la chambre. Scotché par toi, cet après-midi."
const H_CAM := [
	"CAM 2, le jardin. Le socle de Clovis est vide. Clovis pèse quatre-vingts kilos.",
	"CAM 3, la chambre de Mamie. Une forme sous la couette. 58.",
	"CAM 4. PAS DE SIGNAL. L'entrée, en bas.",
]
const CHAT_PAGES := [
	"Messagerie · Manon · hier\n\nmanon 22:41 — maman tu dors\nmanon 22:41 — dis à papa que le vieux pc doit rester débranché\nmanon 22:42 — je sais c'est bête",
	"Messagerie · Manon · hier\n\nHenriette 22:50 — Ne t'inquiète pas ma chérie… Papi a vérifié. Bonne nuit, gros bisous.\nmanon 22:51 — ok\nmanon 22:51 — embrasse mon cœur de ma part",
]
## Texte ajouté (hors spécification) : les classeurs.
const TXT_CLASSEURS := "Les classeurs de Papi. IMPÔTS, une année par classeur. ASSURANCE. Tout est rangé, étiqueté, daté."


## La box internet : boîtier blanc plat, six LED en façade (alimentation, internet, wifi, téléphone,
## télé, 4G de secours). Elles s'emballent quand elle passe par là ou quand elle parle.
## Repère : le nœud est sous la box, au centre ; la façade (LED) regarde +Z.
class InternetBox extends Connected:
	const SIZE := Vector3(0.25, 0.04, 0.18)
	const COLORS := [Color(0.95, 0.95, 1.0), Color(0.2, 1.0, 0.35), Color(0.2, 1.0, 0.35), Color(0.2, 1.0, 0.35),
		Color(0.25, 0.55, 1.0), Color(1.0, 0.6, 0.12)]
	var leds: Array[StandardMaterial3D] = []
	var cut := false                 # débranchée (quelques secondes)
	var _frenzy := 0.0
	var _t := 0.0
	var _blink := 0.0

	func build() -> void:
		if display_name == "":
			display_name = "Box"
		var shell := plain_mat(Color(0.88, 0.88, 0.86), 0.25)
		add_box(Vector3(SIZE.x, SIZE.y - 0.006, SIZE.z), Vector3(0, 0.006 + (SIZE.y - 0.006) / 2.0, 0), shell)
		add_box(Vector3(SIZE.x - 0.02, 0.006, SIZE.z - 0.02), Vector3(0, 0.003, 0), plain_mat(Color(0.2, 0.2, 0.2), 0.8))
		# bande noire brillante en façade, avec les six LED
		add_box(Vector3(SIZE.x - 0.03, 0.012, 0.002), Vector3(0, SIZE.y * 0.55, SIZE.z / 2.0 + 0.001), plain_mat(Color(0.03, 0.03, 0.035), 0.15))
		for i in 6:
			var m := glow_mat(COLORS[i], 3.0)
			leds.append(m)
			no_gi(add_mesh(sphere(0.0028, 6), Vector3(-0.075 + i * 0.03, SIZE.y * 0.55, SIZE.z / 2.0 + 0.0025), m))
		# aérations sur le dessus, logo de l'opérateur
		for k in 7:
			add_box(Vector3(0.12, 0.001, 0.004), Vector3(0.03, SIZE.y + 0.0005, -0.05 + k * 0.012), plain_mat(Color(0.55, 0.55, 0.55), 0.6))
		add_box(Vector3(0.04, 0.001, 0.014), Vector3(-0.08, SIZE.y + 0.0005, 0.05), plain_mat(Color(0.85, 0.35, 0.1), 0.4))
		make_led(Vector3(0.11, SIZE.y * 0.55, SIZE.z / 2.0 + 0.0025), 0.001, true, COLORS[1])
		led_energy = 1.5
		built = true

	## Les LED s'emballent pendant « seconds » secondes (elle passe, elle parle).
	func frenzy(seconds := 3.0) -> void:
		_frenzy = maxf(_frenzy, seconds)

	## Débranchée : tout s'éteint pendant « seconds » secondes, puis se rallume (batterie de secours).
	func power_cut(seconds := 3.0) -> void:
		cut = true
		_apply_all(0.0)
		await get_tree().create_timer(seconds, false).timeout
		if not is_inside_tree():
			return
		cut = false
		Sfx.play_at("metalClick", global_position, -18.0, 1.8, 1.5)
		frenzy(1.2)

	func speak(_text: String, seconds: float) -> void:
		frenzy(seconds)

	func on_enter() -> void:
		super.on_enter()
		frenzy(1.5)

	func _apply_all(k: float) -> void:
		for m in leds:
			m.emission_energy_multiplier = 3.0 * k
		if led_light:
			led_light.light_energy = 0.012 * k

	func _process(delta: float) -> void:
		if leds.is_empty() or cut:
			return
		_t += delta
		if _frenzy > 0.0:
			_frenzy -= delta
			_blink -= delta
			if _blink <= 0.0:
				_blink = randf_range(0.03, 0.08)
				for m in leds:
					m.emission_energy_multiplier = 0.0 if randf() < 0.5 else 4.5
				if led_light:
					led_light.light_energy = randf_range(0.0, 0.03)
			return
		# régime normal : alimentation et 4G fixes, internet et wifi qui clignotent doucement
		for i in leds.size():
			var k := 1.0
			if i == 1:
				k = 1.0 if fmod(_t, 2.4) > 0.12 else 0.0
			elif i == 2:
				k = 1.0 if sin(_t * 9.0) + sin(_t * 3.1) > -0.6 else 0.2
			elif i == 4:
				k = 0.0
			leds[i].emission_energy_multiplier = 3.0 * k
		if led_light:
			led_light.light_energy = 0.012


var house: House
var rng := RandomNumberGenerator.new()
var console: HouseConsole
var printer: Printer
var box: InternetBox
var bulb: SmartBulb
var light_on := false
var drawer_open := false
var drawer_it: Interactable
var screwdriver: Node3D
var laptop_state := 0             # 0 en veille, 1 écran verrouillé, 2 déverrouillé
var laptop_mat: StandardMaterial3D
var laptop_light: OmniLight3D
var _laptop_busy := false
var cams_it: Interactable
var box_it: Interactable
var box_unplugged := false
var webcam_led: StandardMaterial3D
var fans: Array[Node3D] = []
var tower_leds: Array[StandardMaterial3D] = []
var switch_rocker: Node3D
var _fan_speed := 0.0
var _was_booted := false
var _kenney_drawer: Node3D
var _my_drawer: Node3D
var _drawer_closed_z := 0.0
var _tex_lock: Texture2D
var _tex_chat: Texture2D
var _cable_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _new_white: StandardMaterial3D
var _cams_busy := false
var _walnut: StandardMaterial3D
var _brass_m: StandardMaterial3D
var _ubox: BoxMesh
var _tri_cache := {}


func furnish(h: House) -> void:
	house = h
	rng.seed = 4402
	_cable_mat = _plain(Color(0.9, 0.9, 0.88), 0.4)
	_tape_mat = _plain(Color(0.66, 0.66, 0.64), 0.35, 0.3)
	_new_white = _plain(Color(0.74, 0.74, 0.72), 0.4)
	_rug()
	_ceiling_light()
	_switch()
	_desk()
	_console()
	_tower()
	_printer()
	_internet_box()
	_network_cable()
	_bookcases()
	_laptop_table()
	_key_board()
	_filing_cabinet()
	_wall_things()
	connect_feeds()


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


func _no_gi(mi: GeometryInstance3D) -> GeometryInstance3D:
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _box_rot(size: Vector3, pos: Vector3, mat: Material, rot_y: float, parent: Node3D = self) -> MeshInstance3D:
	var b := _box(size, pos, mat, false, parent)
	b.rotation.y = rot_y
	return b


func _look(label: String, size: Vector3, pos: Vector3, text: String, reach := 2.2) -> Interactable:
	var it := _interactable(label, size, pos, self, LAYER_INTERACT, reach)
	it.used.connect(func(_i: Interactable) -> void: Game.hint(text, 4.5))
	return it


func _tex_mat(tex: Texture2D, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## Noyer ciré des meubles d'Albert (Wood027 assombri) : bureau, table de l'imprimante, bibliothèques.
func _wood() -> StandardMaterial3D:
	if _walnut == null:
		_walnut = (mats.wood_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
		_walnut.albedo_color = Color(0.6, 0.45, 0.35)
	return _walnut


## Laiton patiné (poignées, suspension, robinet du radiateur).
func _brass() -> StandardMaterial3D:
	if _brass_m == null:
		_brass_m = _plain(Color(0.58, 0.45, 0.24), 0.4, 0.85)
	return _brass_m


## Meuble Kenney gardé : son bois devient le noyer, ses ferrures le laiton.
func _retint(node: Node3D) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name.to_lower() if src else ""
			if key.begins_with("wood"):
				mi.set_surface_override_material(i, _wood())
			elif key.begins_with("metal"):
				mi.set_surface_override_material(i, _brass())


## Clavier et souris Kenney : plastique noir mat (au lieu du métal).
func _plastic(node: Node3D) -> void:
	var body := _plain(Color(0.05, 0.05, 0.055), 0.55)
	var keys := _plain(Color(0.1, 0.1, 0.11), 0.65)
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name.to_lower() if src else ""
			mi.set_surface_override_material(i, keys if key == "metalmedium" else body)


## Plusieurs primitives [maillage, transformée] fondues en un seul maillage (un seul appel de rendu).
## Les sommets sont recopiés en C++ (Transform3D × PackedVector3Array) : pas de maillage jetable par
## pièce (chaque BoxMesh neuf coûte une allocation au serveur de rendu). gi : compte dans la cuisson
## VoxelGI de la pièce (les grands meubles seulement ; le petit mobilier reçoit l'éclairage indirect).
func _merged(parts: Array, mat: Material, parent: Node3D = self, gi := false) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for p in parts:
		var src: Array = _tri_arrays(p[0] as Mesh)
		var xf: Transform3D = p[1]
		verts.append_array(xf * (src[0] as PackedVector3Array))
		norms.append_array(Transform3D(xf.basis.orthonormalized(), Vector3.ZERO) * (src[1] as PackedVector3Array))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	if not gi:
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


## Sommets et normales d'une primitive, en triangles sans index (lus une fois par maillage).
func _tri_arrays(m: Mesh) -> Array:
	if _tri_cache.has(m):
		return _tri_cache[m]
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var out := [v, n]
	if a[Mesh.ARRAY_INDEX] != null:
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var v2 := PackedVector3Array()
		var n2 := PackedVector3Array()
		v2.resize(idx.size())
		n2.resize(idx.size())
		for i in idx.size():
			v2[i] = v[idx[i]]
			n2[i] = n[idx[i]]
		out = [v2, n2]
	_tri_cache[m] = out
	return out


## Pièces pour _merged : une boîte (cube unité mis à l'échelle), ou un maillage, posés en « pos »,
## tournés de « rot ».
func _bp(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> Array:
	if _ubox == null:
		_ubox = BoxMesh.new()
	return [_ubox, Transform3D(Basis.from_euler(rot) * Basis.from_scale(size), pos)]


static func _mp(mesh: Mesh, pos: Vector3, rot := Vector3.ZERO) -> Array:
	return [mesh, Transform3D(Basis.from_euler(rot), pos)]


func _haunt() -> Haunt:
	return Haunt.of(get_tree()) if is_inside_tree() else null


func _story(ev: String, data := {}) -> void:
	var hn := _haunt()
	if hn:
		hn.story_event(ev, data)


## Câble blanc neuf en segments droits ; « normal » : la surface où il court (vers la pièce).
## tape : scotch gris tous les 40 cm ; ou une liste de points où poser le scotch.
func _cable(points: Array, normal: Vector3, tape: Variant = true, radius := 0.0028, mat: Material = null) -> void:
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
		if not (tape is bool and tape) or absf(dir.dot(normal)) > 0.1 or l < 0.25:
			continue
		var n := maxi(1, int(l / 0.4))
		for k in n:
			_tape(a + dir * (l * (k + 0.5) / n), dir, normal, radius)
	if tape is Array:
		for p in tape:
			var best := 0
			var best_d := INF
			for i in points.size() - 1:
				var dd := Haunt._seg_dist(p, points[i], points[i + 1])
				if dd < best_d:
					best_d = dd
					best = i
			var sd: Vector3 = (points[best + 1] - points[best]).normalized()
			_tape(p, sd, normal, radius)


func _tape(p: Vector3, dir: Vector3, normal: Vector3, radius: float) -> void:
	var across := normal.cross(dir).normalized()
	var t := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.05, radius * 2.0 + 0.0014, 0.034)
	t.mesh = tb
	t.material_override = _tape_mat
	t.transform = Transform3D(Basis(across, normal, dir), p - normal * 0.0004)
	t.rotate_object_local(Vector3.UP, rng.randf_range(-0.15, 0.15))
	add_child(t)


## Prise murale (repère : « normal » vers la pièce), avec ou sans fiche branchée.
func _socket(pos: Vector3, normal: Vector3, plugged := true) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Prise"
	add_child(holder)
	holder.position = pos
	holder.rotation.y = atan2(normal.x, normal.z)
	_box(Vector3(0.075, 0.075, 0.012), Vector3(0, 0, 0.006), _m(Color(0.72, 0.68, 0.58), 0.5), false, holder)
	_mesh(_cyl(0.023, 0.023, 0.004), Vector3(0, 0, 0.0125), _m(Color(0.6, 0.56, 0.48), 0.5), Vector3(PI / 2.0, 0, 0), holder)
	if plugged:
		_box(Vector3(0.036, 0.042, 0.03), Vector3(0, 0, 0.03), _new_white, false, holder)
	return holder


## Texte en police 3 × 5 (celle des caméras, plus « Ô », « ' » et « , ») dans une image, sans ombre.
const EXTRA_GLYPHS := {"Ô": "010111101101111", "'": "010010000000000", ",": "000000000010100", "É": "010111110100111"}


static func px_text(img: Image, text: String, at: Vector2i, scale := 1, color := Color.WHITE) -> void:
	var x := at.x
	for ch in text:
		var g: String = EXTRA_GLYPHS.get(ch, FeedCam.GLYPHS.get(ch, ""))
		if g != "":
			for row in 5:
				for col in 3:
					if g[row * 3 + col] == "1":
						var r := Rect2i(x + col * scale, at.y + row * scale, scale, scale).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
						if r.size.x > 0 and r.size.y > 0:
							img.fill_rect(r, color)
		x += 4 * scale


static func px_text_width(text: String, scale := 1) -> int:
	return text.length() * 4 * scale - scale


# ------------------------------------------------------------------ sol, plafonnier, interrupteur

func _rug() -> void:
	prop("rugRectangle", Vector3(6.9, 0.004, 4.2), 0.0, Vector3(2.0, 0.01, 1.5), false,
		{"carpet": Color(0.2, 0.22, 0.3), "carpetdarker": Color(0.12, 0.1, 0.12)})


## Suspension des années 1960 : rosace, tige et galerie en laiton, globe en opaline ; l'ampoule
## connectée est au centre du globe (là où elle était dans l'abat-jour d'avant). Rien n'y porte d'ombre.
func _ceiling_light() -> void:
	var lamp := Node3D.new()
	lamp.name = "Suspension"
	add_child(lamp)
	lamp.position = Vector3(LIGHT_POS.x, 0, LIGHT_POS.z)
	var parts := [
		_mp(_cyl(0.05, 0.058, 0.022, 24), Vector3(0, h - 0.011, 0)),                 # rosace
		_mp(_cyl(0.0045, 0.0045, 0.09, 8), Vector3(0, h - 0.065, 0)),                # tige
		_mp(_cyl(0.022, 0.03, 0.02, 16), Vector3(0, BULB_Y + 0.175, 0)),             # écrou
		_mp(_cyl(0.034, 0.05, 0.045, 24), Vector3(0, BULB_Y + 0.14, 0)),             # galerie
		_mp(_cyl(0.052, 0.052, 0.008, 24), Vector3(0, BULB_Y + 0.118, 0)),           # bague
	]
	_no_gi(_merged(parts, _brass(), lamp))
	var glass := _plain(Color(0.9, 0.88, 0.84), 0.3)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.84, 0.62)
	glass.emission_energy_multiplier = 1.5
	_no_gi(_mesh(_sphere(0.125, 28), Vector3(0, BULB_Y, 0), glass, Vector3.ZERO, lamp))
	bulb = SmartBulb.new()
	bulb.name = "AmpouleBureau"
	bulb.device_id = "ampoule_bureau"
	bulb.room_id = "bureau"
	bulb.energy = 0.55
	bulb.light_range = 5.0
	bulb.show_bulb = false
	add_child(bulb)
	bulb.position = Vector3(LIGHT_POS.x, BULB_Y, LIGHT_POS.z)
	bulb.build()
	# le globe s'éclaire avec l'ampoule
	bulb.add_glow_material(glass, 1.5)
	bulb.set_powered(false)


func _switch() -> void:
	var holder := Node3D.new()
	holder.name = "Interrupteur"
	add_child(holder)
	holder.position = Vector3(XW, SWITCH_POS.y, SWITCH_POS.z)
	holder.rotation.y = PI / 2.0   # face +x
	_box(Vector3(0.08, 0.08, 0.01), Vector3(0, 0, 0.005), _m(Color(0.76, 0.72, 0.62), 0.5), false, holder)
	switch_rocker = Node3D.new()
	switch_rocker.position = Vector3(0, 0, 0.011)
	holder.add_child(switch_rocker)
	_box(Vector3(0.036, 0.044, 0.008), Vector3(0, 0, 0.003), _m(Color(0.8, 0.77, 0.68), 0.45), false, switch_rocker)
	switch_rocker.rotation.x = 0.16
	var it := _interactable("Allumer la lumière", Vector3(0.14, 0.14, 0.1), Vector3(XW + 0.04, SWITCH_POS.y, SWITCH_POS.z))
	it.used.connect(func(_i: Interactable) -> void:
		set_light(not light_on)
		_story("lumiere", {"room": "bureau", "on": light_on}))
	set_meta("switch_it", it)
	# son câble d'origine monte dans la moulure, jusqu'au plafond
	_box(Vector3(0.012, 1.4, 0.022), Vector3(XW + 0.006, SWITCH_POS.y + 0.04 + 0.7, SWITCH_POS.z), _m(Color(0.74, 0.7, 0.6), 0.6))


## L'interrupteur du bureau (le plafonnier connecté garde son niveau).
func set_light(on: bool) -> void:
	light_on = on
	Game.set_flag("lumiere_bureau", on)
	if bulb:
		bulb.set_powered(on)
	if switch_rocker:
		switch_rocker.rotation.x = -0.16 if on else 0.16
	Sfx.play_at("metalClick", SWITCH_POS, -10.0, 1.3, 1.5)
	if has_meta("switch_it"):
		(get_meta("switch_it") as Interactable).label = "Éteindre la lumière" if on else "Allumer la lumière"


# ------------------------------------------------------------------ le bureau d'Albert, son tiroir

func _desk() -> void:
	var desk := prop("desk", DESK_C, 180.0, DESK_SIZE)
	_retint(desk)
	# le tiroir du modèle est à gauche : on retourne le meuble pour l'avoir côté x −, comme le plan
	var inst := desk.get_child(0) as Node3D
	inst.scale.x = -inst.scale.x
	inst.position.x = -inst.position.x
	var top := (desk.get_meta("size") as Vector3).y
	desk.set_meta("top", top)
	_kenney_drawer = desk.find_child("drawer", true, false) as Node3D
	var dbox := AABB(Vector3(6.55, 0.54, 5.64), Vector3(0.4, 0.1, 0.35))
	if _kenney_drawer:
		dbox = _aabb_of(_kenney_drawer, self)
	_my_drawer = _hollow_drawer(dbox)
	_my_drawer.visible = false
	_drawer_closed_z = _my_drawer.position.z
	drawer_it = _interactable("Ouvrir le tiroir", Vector3(0.42, 0.12, 0.16), Vector3(dbox.get_center().x, DRAWER_IT.y, DRAWER_IT.z), self, LAYER_INTERACT, 2.0)
	drawer_it.used.connect(func(_i: Interactable) -> void:
		if not drawer_open:
			open_drawer()
		elif screwdriver and screwdriver.visible:
			take_screwdriver())
	# sous-main en cuir, pot à crayons, vieille calculatrice, papiers, loupe
	_box(Vector3(0.62, 0.004, 0.4), Vector3(7.12, top + 0.002, 5.86), _m(Color(0.12, 0.2, 0.14), 0.7))
	var pot := Vector3(6.62, top, 6.12)
	_mesh(_cyl(0.035, 0.032, 0.1, 14), pot + Vector3(0, 0.05, 0), _m(Color(0.42, 0.3, 0.18), 0.5))
	for k in 4:
		var pc := _mesh(_cyl(0.004, 0.004, 0.16, 6), pot + Vector3(rng.randf_range(-0.015, 0.015), 0.12, rng.randf_range(-0.015, 0.015)),
			_m([Color(0.1, 0.15, 0.45), Color(0.65, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.8, 0.65, 0.1)][k], 0.5),
			Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)))
		pc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var calc := Node3D.new()
	add_child(calc)
	calc.position = Vector3(7.74, top, 5.84)
	calc.rotation.y = -0.3
	_box(Vector3(0.1, 0.018, 0.16), Vector3(0, 0.009, 0), _m(Color(0.2, 0.19, 0.18), 0.5), false, calc)
	_box(Vector3(0.08, 0.002, 0.03), Vector3(0, 0.019, -0.05), _plain(Color(0.42, 0.46, 0.38), 0.3), false, calc)
	for r in 4:
		for c in 4:
			_box(Vector3(0.014, 0.004, 0.012), Vector3(-0.03 + c * 0.02, 0.019, -0.01 + r * 0.022), _plain(Color(0.6, 0.58, 0.55), 0.5), false, calc)
	for k in 5:
		_box_rot(Vector3(0.21, 0.002, 0.297), Vector3(6.66, top + 0.001 + k * 0.0022, 5.78), _m(Color(0.86, 0.84, 0.78), 0.9), rng.randf_range(-0.2, 0.2))
	var loupe := Node3D.new()
	add_child(loupe)
	loupe.position = Vector3(6.72, top + 0.006, 5.76)
	loupe.rotation.y = 0.7
	var ring := TorusMesh.new()
	ring.inner_radius = 0.034
	ring.outer_radius = 0.04
	ring.rings = 20
	ring.ring_segments = 6
	_mesh(ring, Vector3.ZERO, _m(Color(0.1, 0.1, 0.1), 0.4), Vector3.ZERO, loupe)
	_mesh(_cyl(0.008, 0.008, 0.1, 8), Vector3(0, 0, 0.088), _m(Color(0.25, 0.15, 0.08), 0.5), Vector3(PI / 2.0, 0, 0), loupe)
	# la chaise de bureau, repoussée de travers
	prop("chairDesk", Vector3(7.2, 0, 5.35), 14.0, Vector3(0.56, 0.95, 0.56), true, {"carpet": Color(0.1, 0.1, 0.12)})
	# la lampe d'architecte de Papi, éteinte, penchée sur le sous-main ; la corbeille à papier
	var lamp := model("desk_lamp_arm_01", Vector3(7.72, top, 6.02), 20.0, Vector3(0, 0.55, 0), false,
		{"name": "LampeArchitecte", "tint": Color(0.8, 0.8, 0.8)})
	for n in lamp.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var lm := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if lm:
				# (matière partagée avec la chambre : une copie, l'orange passé par les années)
				var dm := lm.duplicate() as StandardMaterial3D
				dm.albedo_color = lm.albedo_color * Color(0.6, 0.62, 0.6)
				mi.set_surface_override_material(i, dm)
	_waste_bin(Vector3(6.3, 0, 5.93))


## Corbeille à papier en tôle peinte (vert bouteille), bord roulé, quelques boulettes de papier.
func _waste_bin(p: Vector3) -> void:
	var hb := 0.3
	var outer := _cyl(0.125, 0.105, hb, 20)
	outer.cap_top = false
	var inner := _cyl(0.121, 0.101, hb - 0.004, 20)
	inner.cap_top = false
	inner.cap_bottom = false
	inner.flip_faces = true
	var rim := TorusMesh.new()
	rim.inner_radius = 0.119
	rim.outer_radius = 0.131
	rim.rings = 24
	rim.ring_segments = 6
	_merged([_mp(outer, p + Vector3(0, hb / 2.0, 0)), _mp(inner, p + Vector3(0, hb / 2.0 + 0.002, 0)), _mp(rim, p + Vector3(0, hb, 0))],
		_m(Color(0.1, 0.17, 0.12), 0.45, 0.6))
	var balls := []
	for k in 5:
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.035, 0.05)
		s.height = s.radius * 1.7
		s.radial_segments = 7
		s.rings = 4
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.0, 0.06)
		balls.append(_mp(s, p + Vector3(cos(a) * rr, 0.06 + k * 0.035, sin(a) * rr), Vector3(rng.randf() * 3.0, rng.randf() * 3.0, rng.randf() * 3.0)))
	_merged(balls, _m(Color(0.84, 0.82, 0.76), 0.95))
	_collider(Vector3(0.24, hb, 0.24), p + Vector3(0, hb / 2.0, 0))


## Tiroir creux (fond, côtés, façade) aligné sur le tiroir du modèle, avec ce qu'Albert y range.
func _hollow_drawer(b: AABB) -> Node3D:
	var d := Node3D.new()
	d.name = "Tiroir"
	add_child(d)
	d.position = Vector3(b.get_center().x, b.position.y, b.position.z)
	var w := b.size.x
	var hh := b.size.y
	var depth := b.size.z
	var wood: Material = _wood()
	var inner := _m(Color(0.42, 0.32, 0.22), 0.85)
	_box(Vector3(w, hh, 0.016), Vector3(0, hh / 2.0, 0.008), wood, false, d)              # façade
	_box(Vector3(w - 0.03, 0.008, depth - 0.02), Vector3(0, 0.012, depth / 2.0 + 0.004), inner, false, d)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.012, hh - 0.012, depth - 0.016), Vector3(sx * (w / 2.0 - 0.012), hh / 2.0, depth / 2.0 + 0.008), inner, false, d)
	_box(Vector3(w - 0.024, hh - 0.012, 0.012), Vector3(0, hh / 2.0, depth - 0.006), inner, false, d)
	_mesh(_cyl(0.006, 0.006, 0.08, 8), Vector3(0, hh / 2.0, -0.012), _brass(), Vector3(0, 0, PI / 2.0), d)
	# le tournevis de Papi : manche rouge, étiquette « A. », tige d'acier
	screwdriver = Node3D.new()
	screwdriver.name = "Tournevis"
	d.add_child(screwdriver)
	screwdriver.position = Vector3(-0.02, 0.032, depth * 0.45)
	screwdriver.rotation.y = 0.12
	_mesh(_cyl(0.014, 0.013, 0.1, 10), Vector3(-0.05, 0, 0), _plain(Color(0.62, 0.08, 0.06), 0.35), Vector3(0, 0, PI / 2.0), screwdriver)
	_mesh(_cyl(0.0035, 0.0035, 0.11, 8), Vector3(0.055, 0, 0), _plain(Color(0.7, 0.7, 0.72), 0.3, 0.9), Vector3(0, 0, PI / 2.0), screwdriver)
	_box(Vector3(0.008, 0.0015, 0.007), Vector3(0.112, 0, 0), _plain(Color(0.6, 0.6, 0.62), 0.3, 0.9), false, screwdriver)
	var lbl := Image.create_empty(24, 12, false, Image.FORMAT_RGB8)
	lbl.fill(Color(0.88, 0.86, 0.78))
	px_text(lbl, "A.", Vector2i(7, 3), 1, Color(0.1, 0.1, 0.35))
	var lm := _tex_mat(ImageTexture.create_from_image(lbl))
	var q := _quad(Vector2(0.034, 0.016), Vector3(-0.05, 0.0145, 0), lm, 0.0, screwdriver)
	q.rotation.x = -PI / 2.0
	# crayons, élastiques, mètre ruban
	_mesh(_cyl(0.004, 0.004, 0.15, 6), Vector3(0.08, 0.02, depth * 0.25), _m(Color(0.8, 0.65, 0.1), 0.5), Vector3(0, 0.3, PI / 2.0), d)
	_mesh(_cyl(0.004, 0.004, 0.12, 6), Vector3(0.06, 0.02, depth * 0.72), _m(Color(0.15, 0.3, 0.6), 0.5), Vector3(0, -0.2, PI / 2.0), d)
	_mesh(_cyl(0.028, 0.028, 0.02, 14), Vector3(0.11, 0.026, depth * 0.62), _m(Color(0.85, 0.7, 0.1), 0.45), Vector3.ZERO, d)
	for k in 3:
		var band := TorusMesh.new()
		band.inner_radius = 0.012
		band.outer_radius = 0.015
		band.rings = 10
		band.ring_segments = 4
		_mesh(band, Vector3(-0.1 + k * 0.022, 0.018, depth * 0.78), _m(Color(0.6, 0.35, 0.2), 0.8), Vector3.ZERO, d)
	return d


## Ouvre le tiroir du bureau (le tournevis est dedans).
func open_drawer(seconds := 0.45, quiet := false) -> void:
	if drawer_open:
		return
	drawer_open = true
	Game.set_flag("tiroir_bureau_ouvert", true)
	if _kenney_drawer:
		_kenney_drawer.visible = false
	_my_drawer.visible = true
	Sfx.play_at("door_slide", _my_drawer.global_position, -10.0, 1.5, 1.5)
	if seconds <= 0.0:
		_my_drawer.position.z = _drawer_closed_z - 0.24
	else:
		create_tween().tween_property(_my_drawer, "position:z", _drawer_closed_z - 0.24, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drawer_it.label = "Prendre le tournevis" if screwdriver.visible else "Ouvrir le tiroir"
	drawer_it.enabled = screwdriver.visible
	drawer_it.position.z = DRAWER_IT.z - 0.2
	if not quiet:
		_story("tiroir_ouvert")


## Prend le tournevis de Papi (objet « outil »).
func take_screwdriver() -> void:
	if Game.has_item("tournevis") and not screwdriver.visible:
		return
	if not drawer_open:
		open_drawer(0.0)
	screwdriver.visible = false
	drawer_it.enabled = false
	Game.add_item("tournevis", "Tournevis de Papi", "Une étiquette « A. » sur le manche. Évidemment.", "outil")
	Game.hint(TXT_TIROIR, 5.0)
	Sfx.play("metalClick", -12.0, 1.6)
	_story("tournevis_pris")


# ------------------------------------------------------------------ l'écran de la console, la tour

func _console() -> void:
	var top := DESK_SIZE.y
	var c := Vector3(DESK_C.x, top + 0.25, SCREEN_Z)
	# écran 24 pouces : dalle noire mince, menton, pied, socle ; webcam posée dessus
	var black := _plain(Color(0.04, 0.04, 0.045), 0.35)
	var mon := Node3D.new()
	mon.name = "Ecran"
	add_child(mon)
	mon.position = c
	mon.rotation.y = PI      # face −z, vers la chaise
	_box(Vector3(0.56, 0.345, 0.022), Vector3(0, 0, -0.011), black, false, mon)
	_box(Vector3(0.4, 0.24, 0.03), Vector3(0, 0.0, -0.035), black, false, mon)
	_box(Vector3(0.05, 0.004, 0.002), Vector3(0, -0.16, 0.0012), _plain(Color(0.4, 0.4, 0.42), 0.3, 0.6), false, mon)
	_box(Vector3(0.05, 0.2, 0.02), Vector3(0, -0.15, -0.06), _plain(Color(0.12, 0.12, 0.13), 0.4, 0.5), false, mon)
	_box(Vector3(0.24, 0.012, 0.17), Vector3(0, -0.244, -0.04), _plain(Color(0.12, 0.12, 0.13), 0.4, 0.5), false, mon)
	_box(Vector3(0.07, 0.024, 0.026), Vector3(0, 0.185, -0.01), black, false, mon)
	_mesh(_cyl(0.006, 0.006, 0.004, 12), Vector3(0, 0.185, 0.004), _plain(Color(0.02, 0.03, 0.06), 0.05), Vector3(PI / 2.0, 0, 0), mon)
	webcam_led = _glow(Color(0.2, 1.0, 0.3), 0.0)
	_no_gi(_mesh(_sphere(0.0018, 6), Vector3(0.016, 0.185, 0.004), webcam_led, Vector3.ZERO, mon))
	console = HouseConsole.new()
	console.name = "Console"
	console.device_id = "console"
	console.room_id = "bureau"
	add_child(console)
	console.position = c + Vector3(0, 0, -0.001)
	console.rotation.y = PI
	console.build()
	console.fan_pos = TOWER_C + Vector3(0, 0.3, -0.2)
	# clavier, souris
	_keyboard(Vector3(DESK_C.x, top, 5.8))
	_plastic(prop("computerMouse", Vector3(7.56, top, 5.82), 172.0, Vector3(0.065, 0, 0), false))
	# regarder les caméras (seulement quand la console est allumée)
	cams_it = _interactable("Regarder les caméras", Vector3(0.6, 0.4, 0.12), c + Vector3(0, 0, -0.06), self, LAYER_INTERACT, 2.4)
	cams_it.enabled = false
	cams_it.used.connect(func(_i: Interactable) -> void: look_cameras())


## Clavier de la console (posé par l'installateur) : coque noire mate, touches grises (texture),
## tourné vers la chaise (−z).
func _keyboard(p: Vector3) -> void:
	var kb := Node3D.new()
	kb.name = "Clavier"
	add_child(kb)
	kb.position = p
	kb.rotation.y = PI
	var w := 0.44
	var d := 0.14
	_merged([_bp(Vector3(w, 0.016, d), Vector3(0, 0.008, 0)), _bp(Vector3(w, 0.01, 0.03), Vector3(0, 0.02, -d / 2.0 + 0.015))],
		_plain(Color(0.04, 0.04, 0.045), 0.5), kb)
	var img := Image.create_empty(176, 52, false, Image.FORMAT_RGB8)
	img.fill(Color(0.025, 0.025, 0.03))
	var cap := Color(0.15, 0.15, 0.16)
	for c in 13:
		img.fill_rect(Rect2i(3 + c * 9, 2, 7, 5), cap)                          # touches de fonction
	for r in 5:
		for c in 15:
			if r == 4 and c > 3 and c < 11:
				continue
			img.fill_rect(Rect2i(3 + c * 8, 10 + r * 8, 7, 7), cap)
		for c in 3:
			if r < 2 or (r == 3 and c == 1) or r == 4:
				img.fill_rect(Rect2i(127 + c * 8, 10 + r * 8, 7, 7), cap)        # édition, flèches
			img.fill_rect(Rect2i(152 + c * 8, 10 + r * 8, 7, 7), cap)            # pavé numérique
	img.fill_rect(Rect2i(35, 42, 55, 7), cap)                                    # barre d'espace
	img.generate_mipmaps()
	var q := _quad(Vector2(0.43, 0.127), Vector3(0, 0.0162, 0.004), _tex_mat(ImageTexture.create_from_image(img), 0.6), 0.0, kb)
	q.rotation.x = -PI / 2.0


## Tasse en faïence : anse, fond de café froid.
func _mug(p: Vector3, rot: float, col: Color) -> void:
	var outer := _cyl(0.04, 0.037, 0.09, 16)
	outer.cap_top = false
	var inner := _cyl(0.036, 0.033, 0.086, 16)
	inner.cap_top = false
	inner.cap_bottom = false
	inner.flip_faces = true
	var rim := TorusMesh.new()
	rim.inner_radius = 0.035
	rim.outer_radius = 0.041
	rim.rings = 16
	rim.ring_segments = 4
	var handle := TorusMesh.new()
	handle.inner_radius = 0.017
	handle.outer_radius = 0.025
	handle.rings = 12
	handle.ring_segments = 5
	var b := Basis(Vector3.UP, rot)
	_merged([_mp(outer, p + Vector3(0, 0.045, 0)), _mp(inner, p + Vector3(0, 0.047, 0)), _mp(rim, p + Vector3(0, 0.09, 0)),
		[handle, Transform3D(b * Basis(Vector3.RIGHT, PI / 2.0), p + b * Vector3(0.044, 0.05, 0))]], _m(col, 0.25))
	_mesh(_cyl(0.034, 0.034, 0.002, 14), p + Vector3(0, 0.055, 0), _plain(Color(0.06, 0.035, 0.02), 0.1))


## Branche les caméras sur la console : CAM 1 (couloir), CAM 2 (jardin), CAM 3 (chambre des
## grands-parents), CAM 4 (« PAS DE SIGNAL »). Les caméras sont trouvées par leur titre.
func connect_feeds() -> void:
	if console == null or not is_inside_tree():
		return
	var found := {}
	for n in get_tree().get_nodes_in_group("feed_cam"):
		var fc := n as FeedCam
		if fc == null:
			continue
		for k in ["CAM 1", "CAM 2", "CAM 3"]:
			if fc.title == k or fc.title.begins_with(k + " "):
				found[k] = fc
	var c1: FeedCam = found.get("CAM 1")
	var c2: FeedCam = found.get("CAM 2")
	var c3: FeedCam = found.get("CAM 3")
	console.set_feed(0, c1, "CAM 1 COULOIR")
	console.set_feed(1, c2, "CAM 2 JARDIN")
	console.set_feed(2, c3, "CAM 3 CHAMBRE 1")
	console.set_feed(3, null, "CAM 4 ENTRÉE")
	if found.size() < 3 and not has_meta("feeds_retry"):
		set_meta("feeds_retry", true)
		connect_feeds.call_deferred()


## La tour du PC, sous le bureau : façade ajourée, deux ventilateurs, bouton, liseré bleu.
func _tower() -> void:
	var t := Node3D.new()
	t.name = "Tour"
	add_child(t)
	t.position = TOWER_C
	t.rotation.y = PI       # façade vers −z
	var w := 0.2
	var hh := 0.45
	var d := 0.45
	var black := _plain(Color(0.05, 0.05, 0.055), 0.45, 0.2)
	_box(Vector3(w, hh - 0.02, d), Vector3(0, 0.02 + (hh - 0.02) / 2.0, 0), black, false, t)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.03, 0.02, 0.05), Vector3(sx * 0.07, 0.01, sz * 0.18), _plain(Color(0.1, 0.1, 0.1), 0.8), false, t)
	# façade : cadre, deux ventilateurs derrière une grille à barreaux
	var fz := d / 2.0
	var frame := _plain(Color(0.08, 0.08, 0.085), 0.3, 0.3)
	_box(Vector3(w, 0.09, 0.01), Vector3(0, hh - 0.045, fz + 0.005), frame, false, t)
	_box(Vector3(w, 0.03, 0.01), Vector3(0, 0.035, fz + 0.005), frame, false, t)
	_box(Vector3(0.02, hh - 0.14, 0.01), Vector3(-w / 2.0 + 0.01, 0.05 + (hh - 0.14) / 2.0, fz + 0.005), frame, false, t)
	_box(Vector3(0.02, hh - 0.14, 0.01), Vector3(w / 2.0 - 0.01, 0.05 + (hh - 0.14) / 2.0, fz + 0.005), frame, false, t)
	_box(Vector3(w - 0.04, hh - 0.14, 0.004), Vector3(0, 0.05 + (hh - 0.14) / 2.0, fz - 0.03), _plain(Color(0.02, 0.02, 0.02), 0.9), false, t)
	for k in 9:
		_box(Vector3(w - 0.04, 0.004, 0.004), Vector3(0, 0.07 + k * 0.035, fz + 0.006), frame, false, t)
	var blade_mat := _plain(Color(0.14, 0.14, 0.15), 0.5)
	for fy in [0.14, 0.29]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.068
		ring.outer_radius = 0.076
		ring.rings = 24
		ring.ring_segments = 6
		_mesh(ring, Vector3(0, fy, fz - 0.015), _plain(Color(0.1, 0.1, 0.11), 0.5), Vector3(PI / 2.0, 0, 0), t)
		var fan := Node3D.new()
		fan.position = Vector3(0, fy, fz - 0.016)
		t.add_child(fan)
		_mesh(_cyl(0.02, 0.02, 0.012, 12), Vector3.ZERO, _plain(Color(0.2, 0.2, 0.21), 0.5), Vector3(PI / 2.0, 0, 0), fan)
		for b in 7:
			var bl := _box(Vector3(0.022, 0.05, 0.003), Vector3.ZERO, blade_mat, false, fan)
			var a := TAU * b / 7.0
			bl.position = Vector3(cos(a), sin(a), 0) * 0.044
			bl.rotation = Vector3(0, 0, a + PI / 2.0)
			bl.rotate_object_local(Vector3.UP, 0.45)
		fans.append(fan)
	# bouton d'alimentation et liseré bleu
	var blue := _glow(Color(0.25, 0.55, 1.0), 0.0)
	tower_leds.append(blue)
	_no_gi(_box(Vector3(w - 0.05, 0.004, 0.002), Vector3(0, hh - 0.075, fz + 0.011), blue, false, t))
	_mesh(_cyl(0.012, 0.012, 0.004, 14), Vector3(0, hh - 0.04, fz + 0.011), _plain(Color(0.2, 0.2, 0.22), 0.3, 0.6), Vector3(PI / 2.0, 0, 0), t)
	var ringb := _glow(Color(0.25, 0.55, 1.0), 0.0)
	tower_leds.append(ringb)
	var tr := TorusMesh.new()
	tr.inner_radius = 0.012
	tr.outer_radius = 0.0145
	tr.rings = 16
	tr.ring_segments = 4
	_no_gi(_mesh(tr, Vector3(0, hh - 0.04, fz + 0.012), ringb, Vector3(PI / 2.0, 0, 0), t))
	_collider(Vector3(w, hh, d), Vector3(TOWER_C.x, hh / 2.0, TOWER_C.z))
	# câbles : de la tour à l'écran (derrière le bureau), et la multiprise au sol
	var top := DESK_SIZE.y
	_cable([TOWER_C + Vector3(0.02, 0.3, 0.226), Vector3(TOWER_C.x + 0.02, 0.3, 6.245), Vector3(7.25, 0.3, 6.245),
		Vector3(7.25, top + 0.02, 6.245), Vector3(DESK_C.x, top + 0.13, 6.2)], Vector3.FORWARD, false, 0.0035, _plain(Color(0.06, 0.06, 0.06), 0.5))
	var strip := Node3D.new()
	strip.name = "Multiprise"
	add_child(strip)
	strip.position = Vector3(7.05, 0, 6.17)
	_box(Vector3(0.3, 0.035, 0.055), Vector3(0, 0.0175, 0), _new_white, false, strip)
	for k in 4:
		_mesh(_cyl(0.014, 0.014, 0.002, 12), Vector3(-0.105 + k * 0.07, 0.036, 0), _plain(Color(0.6, 0.6, 0.58), 0.5), Vector3.ZERO, strip)
	for k in 3:
		_box(Vector3(0.03, 0.036, 0.034), Vector3(-0.105 + k * 0.07, 0.054, 0), _new_white, false, strip)
	_no_gi(_box(Vector3(0.008, 0.004, 0.004), Vector3(0.13, 0.036, 0), _glow(Color(1.0, 0.3, 0.1), 3.0), false, strip))
	_cable([Vector3(7.215, 0.07, 6.17), Vector3(7.215, 0.012, 6.24), Vector3(7.6, 0.012, 6.24), Vector3(7.6, 0.1, 6.24)], Vector3.FORWARD, false, 0.0035)
	_cable([Vector3(6.895, 0.02, 6.17), Vector3(6.4, 0.008, 6.22), Vector3(6.3, 0.008, 6.25), Vector3(6.3, 0.24, 6.27)], Vector3.FORWARD, false, 0.0035)
	_socket(Vector3(6.3, 0.26, ZS - 0.022), Vector3.FORWARD)


# ------------------------------------------------------------------ l'imprimante

func _printer() -> void:
	var table := prop("sideTable", Vector3(PRINTER_C.x, 0, PRINTER_TABLE_Z), 180.0, Vector3(0.6, 0.72, 0.44))
	_retint(table)
	var top := (table.get_meta("size") as Vector3).y
	printer = Printer.new()
	printer.name = "Imprimante"
	printer.device_id = "imprimante"
	printer.room_id = "bureau"
	add_child(printer)
	printer.position = Vector3(PRINTER_C.x, top, PRINTER_C.z)
	printer.rotation.y = PI
	printer.build()
	# (sous le bac de sortie : un collisionneur jusqu'en haut arrêterait le rayon avant les feuilles)
	_collider(Vector3(0.42, 0.15, 0.35), Vector3(PRINTER_C.x, top + 0.075, PRINTER_C.z))
	# sous la table : une ramette de papier, la notice de la domotique encore sous plastique
	_box_rot(Vector3(0.21, 0.05, 0.297), Vector3(8.2, 0.025, 6.02), _plain(Color(0.86, 0.85, 0.82), 0.9), 0.1)
	var notice := _box_rot(Vector3(0.2, 0.012, 0.28), Vector3(8.42, 0.006, 6.0), _m(Color(0.25, 0.45, 0.62), 0.5), -0.25)
	notice.name = "Notice"
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = Color(0.9, 0.92, 0.95, 0.18)
	wrap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wrap.roughness = 0.1
	wrap.metallic_specular = 0.8
	_box_rot(Vector3(0.205, 0.014, 0.285), Vector3(8.42, 0.0072, 6.0), wrap, -0.25)
	_cable([Vector3(PRINTER_C.x + 0.12, top + 0.05, PRINTER_C.z + 0.17), Vector3(PRINTER_C.x + 0.12, top - 0.02, 6.25),
		Vector3(PRINTER_C.x + 0.12, 0.3, 6.25), Vector3(7.75, 0.012, 6.24), Vector3(7.25, 0.012, 6.24)], Vector3.FORWARD, false, 0.003)


# ------------------------------------------------------------------ la box et le câble

func _internet_box() -> void:
	box = InternetBox.new()
	box.name = "Box"
	box.device_id = "box"
	box.room_id = "bureau"
	add_child(box)
	box.position = BOX_C
	box.rotation.y = PI      # LED vers −z
	box.build()
	# la clé 4G de secours, branchée sur le côté ; l'étiquette d'Henriette sur le dessus
	var dongle := Node3D.new()
	box.add_child(dongle)
	dongle.position = Vector3(-0.15, 0.02, -0.03)
	_box(Vector3(0.05, 0.014, 0.022), Vector3.ZERO, _new_white, false, dongle)
	_no_gi(_box(Vector3(0.004, 0.003, 0.004), Vector3(-0.015, 0.008, 0), _glow(Color(0.25, 0.55, 1.0), 2.5), false, dongle))
	var img := Image.create_empty(96, 24, false, Image.FORMAT_RGB8)
	img.fill(Color(0.86, 0.8, 0.6))
	px_text(img, "NE PAS", Vector2i(26, 3), 2, Color(0.12, 0.14, 0.4))
	px_text(img, "DÉBRANCHER", Vector2i(9, 14), 1, Color(0.12, 0.14, 0.4))
	var q := _quad(Vector2(0.11, 0.03), Vector3(0.02, InternetBox.SIZE.y + 0.0012, 0.03), _tex_mat(ImageTexture.create_from_image(img)), 0.0, box)
	q.rotation = Vector3(-PI / 2.0, 0.0, 0.05)
	# alimentation : bloc secteur blanc jusqu'à la prise du mur sud
	_cable([BOX_C + Vector3(0.1, 0.02, 0.09), Vector3(BOX_C.x + 0.1, 0.008, 6.235), Vector3(5.95, 0.008, 6.235), Vector3(5.95, 0.24, 6.26)], Vector3.FORWARD, false)
	_socket(Vector3(5.95, 0.26, ZS - 0.022), Vector3.FORWARD)
	box_it = _interactable("Regarder la box", Vector3(0.32, 0.14, 0.26), BOX_C + Vector3(0, 0.05, 0), self, LAYER_INTERACT, 2.2)
	box_it.used.connect(func(_i: Interactable) -> void:
		if box_it.label == "Débrancher la box":
			unplug_box()
		else:
			Game.hint(TXT_BOX, 4.0)
			if not box_unplugged:
				box_it.label = "Débrancher la box")


## Débrancher la box : tout s'éteint trois secondes, puis se rallume (batterie de secours, 4G) ;
## la console : « Merci d'avoir essayé. » ; jauge +1 (une fois).
func unplug_box() -> void:
	if box.cut:
		return
	var first := not box_unplugged
	box_unplugged = true
	Game.set_flag("box_debranchee", true)
	box_it.label = "Regarder la box"
	Sfx.play_at("metalClick", BOX_C, -8.0, 0.8, 1.5)
	Game.hint(TXT_BOX_DEBRANCHEE, 5.5)
	await box.power_cut(3.0)
	if not is_inside_tree():
		return
	var hn := _haunt()
	if hn and first:
		await get_tree().create_timer(0.6, false).timeout
		hn.say("console", TXT_BOX_MERCI)
		hn.peur(1.0, "box")
	_story("box_debranchee", {"premiere": first})


func _network_cable() -> void:
	# du seuil de P7 (le morceau du couloir s'arrête là) le long du mur ouest, puis du mur sud, jusqu'à la box ;
	# le même câble que dans le couloir (couloir.gd : tube rond de 6 mm blanc cassé, coudes arrondis, posé au sol)
	var r := 0.003
	var y := r + 0.0005
	var xw := XW + 0.059      # devant la plinthe
	var pts := [Vector3(4.81, 0.015, CABLE_Z), Vector3(4.83, y, CABLE_Z), Vector3(xw, y, CABLE_Z), Vector3(xw, y, 6.2),
		Vector3(5.38, y, 6.2), Vector3(5.41, 0.016, 6.17)]
	var cable := MeshInstance3D.new()
	cable.name = "Cable"
	cable.mesh = COULOIR._tube_mesh(COULOIR._round_corners(PackedVector3Array(pts)), r, 6 if Builder.soft_render() else 8)
	cable.material_override = _plain(Color(0.62, 0.62, 0.59), 0.5)
	add_child(cable, true)
	# scotch gris aux mêmes endroits (un tirage chacun, dans le même ordre qu'avant)
	for p in [Vector3(xw, y, 4.7), Vector3(xw, y, 5.4), Vector3(xw, y, 6.0), Vector3(5.1, y, 6.2)]:
		var best := 0
		var best_d := INF
		for i in pts.size() - 1:
			var dd := Haunt._seg_dist(p, pts[i], pts[i + 1])
			if dd < best_d:
				best_d = dd
				best = i
		_tape(p, (pts[best + 1] - pts[best]).normalized(), Vector3.UP, r)
	_box(Vector3(0.016, 0.012, 0.02), Vector3(5.42, 0.018, 6.16), _plain(Color(0.85, 0.87, 0.9), 0.2))
	_look("Regarder le câble", Vector3(0.12, 0.08, 1.2), Vector3(xw, 0.04, 5.5), TXT_CABLE, 2.0)


# ------------------------------------------------------------------ les classeurs

func _bookcases() -> void:
	var sets := [
		[2.6, ["IMPÔTS 2032", "IMPÔTS 2033", "IMPÔTS 2034", "IMPÔTS 2035", "IMPÔTS 2036", "IMPÔTS 2037", "IMPÔTS 2038", "IMPÔTS 2039", "IMPÔTS 2040",
			"BANQUE", "BANQUE", "RETRAITE", "RETRAITE", "CAISSE", "NOTAIRE", "SUCCESSION", "MAISON", "TRAVAUX", "TOITURE", "CHAUDIÈRE", "JARDIN",
			"EDF", "EAU", "TÉLÉPHONE", "", "", "1998", "1999", "2000", "2001", "2002"]],
		[5.4, ["ASSURANCE", "ASSURANCE AUTO", "ASSURANCE MAISON", "ASSURANCE VIE", "MUTUELLE", "SANTÉ", "SANTÉ HENRIETTE", "ORDONNANCES",
			"TÉLÉASSISTANCE", "DOMOTIQUE", "GARANTIES", "NOTICES", "VOITURE", "CARTE GRISE", "MANON", "MANON ÉCOLE", "PHOTOS",
			"RECETTES", "", "COURRIER", "COURRIER", "DIVERS", "", "", "", "", "", "", ""]],
	]
	for s in sets:
		var zc: float = s[0]
		_bookcase(zc)
		var labels: Array = s[1]
		var li := 0
		for row in 3:
			var y0: float = [0.29, 0.83, 1.36][row]
			var used := _binder_row(XE - 0.058 - 0.175 - 0.119, y0, zc - 0.4, zc + 0.4, labels.slice(li, li + 10), int(zc * 10) + row)
			li += used
		_look("Regarder les classeurs", Vector3(0.3, 1.6, 0.9), Vector3(XE - 0.308, 1.05, zc), TXT_CLASSEURS, 2.2)
	# sur les bibliothèques : un carton d'archives, des boîtes d'archives en carton brun étiquetées
	var top := 1.946
	model("cardboard_box_01", Vector3(XE - 0.058 - 0.2, top, 2.52), 4.0, Vector3.ZERO, false, {"name": "CartonArchives"})
	var kraft := []
	var tags := []
	for k in 3:
		var bz := 5.12 + k * 0.105
		kraft.append(_bp(Vector3(0.33, 0.25, 0.1), Vector3(XE - 0.058 - 0.175, top + 0.125, bz), Vector3(0, rng.randf_range(-0.03, 0.03), 0)))
		tags.append(_bp(Vector3(0.002, 0.07, 0.06), Vector3(XE - 0.058 - 0.341, top + 0.15, bz)))
	kraft.append(_bp(Vector3(0.33, 0.1, 0.25), Vector3(XE - 0.058 - 0.175, top + 0.05, 5.62), Vector3(0, 0.04, 0)))
	_merged(kraft, _m(Color(0.46, 0.34, 0.21), 0.9))
	_merged(tags, _m(Color(0.86, 0.84, 0.76), 0.9))


## Bibliothèque en noyer contre le mur est (façade vers −x, 0,9 × 1,9 × 0,35, comme le meuble Kenney
## d'avant), tablettes aux hauteurs des rangées de classeurs (dessus : 0,29 · 0,83 · 1,36), socle fermé,
## montants de façade, corniche moulurée : un seul maillage.
func _bookcase(zc: float) -> void:
	var xb := XE - 0.058           # dos
	var d := 0.35
	var w := 0.9
	var xf := xb - d                # façade
	var xm := xb - d / 2.0
	var hh := 1.9
	var t := 0.022
	var wi := w - 2.0 * t
	var parts := []
	for s in [-1.0, 1.0]:
		parts.append(_bp(Vector3(d, hh, t), Vector3(xm, hh / 2.0, zc + s * (w / 2.0 - t / 2.0))))           # côtés
		parts.append(_bp(Vector3(0.02, hh - 0.08, 0.05), Vector3(xf + 0.006, 0.08 + (hh - 0.08) / 2.0, zc + s * (w / 2.0 - 0.025))))   # montants
	parts.append(_bp(Vector3(0.01, hh - 0.03, wi), Vector3(xb - 0.006, hh / 2.0, zc)))                       # fond
	# socle : plinthe en saillie, panneau, cimaise
	parts.append(_bp(Vector3(0.03, 0.08, w + 0.012), Vector3(xf + 0.005, 0.04, zc)))
	parts.append(_bp(Vector3(0.02, 0.2, wi), Vector3(xf + 0.014, 0.08 + 0.1, zc)))
	parts.append(_bp(Vector3(0.024, 0.02, w - 0.08), Vector3(xf + 0.008, 0.255, zc)))
	for y0 in [0.29, 0.83, 1.36]:
		parts.append(_bp(Vector3(d - 0.014, 0.022, wi), Vector3(xm + 0.003, y0 - 0.011, zc)))               # tablette
		parts.append(_bp(Vector3(0.022, 0.034, wi), Vector3(xf + 0.013, y0 - 0.017, zc)))                   # chant
	parts.append(_bp(Vector3(d, 0.028, w), Vector3(xm, hh - 0.014, zc)))                                    # dessus
	parts.append(_bp(Vector3(0.024, 0.06, wi), Vector3(xf + 0.014, hh - 0.058, zc)))                        # bandeau
	parts.append(_bp(Vector3(d + 0.02, 0.022, w + 0.03), Vector3(xm - 0.01, hh + 0.011, zc)))               # corniche
	parts.append(_bp(Vector3(d + 0.036, 0.024, w + 0.06), Vector3(xm - 0.018, hh + 0.034, zc)))
	var mi := _merged(parts, _wood(), self, true)
	mi.name = "Bibliotheque"
	_collider(Vector3(d * 0.96, hh, w * 0.96), Vector3(xm, hh / 2.0, zc))


## Une rangée de classeurs sur une étagère : dos colorés, étiquettes écrites, trou pour le doigt.
## x_front : face avant (les dos regardent −x) ; y0 : dessus de l'étagère ; de z0 à z1. Renvoie le
## nombre d'étiquettes utilisées.
func _binder_row(x_front: float, y0: float, z0: float, z1: float, labels: Array, seed_: int) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var palette := [Color(0.1, 0.13, 0.3), Color(0.38, 0.08, 0.1), Color(0.12, 0.25, 0.14), Color(0.28, 0.28, 0.3),
		Color(0.55, 0.48, 0.32), Color(0.08, 0.08, 0.09), Color(0.42, 0.2, 0.08)]
	var hh := 0.32
	var depth := 0.23
	var ppm := 300.0
	var widths: Array[float] = []
	var mat_cache := {}
	var total := 0.0
	var n := 0
	while n < labels.size() and total < (z1 - z0) - 0.1:
		var w := r.randf_range(0.055, 0.078)
		widths.append(w)
		total += w + 0.002
		n += 1
	if n == 0:
		return 0
	var img := Image.create_empty(int(total * ppm) + 1, int(hh * ppm), false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.05, 0.05))
	var z := z0 + 0.01
	var px := 0
	var cols: Array = []
	for i in n:
		var w := widths[i]
		var col: Color = palette[r.randi_range(0, palette.size() - 1)].darkened([0.0, 0.12, 0.24][r.randi_range(0, 2)])
		cols.append(col)
		var bw := int(w * ppm)
		img.fill_rect(Rect2i(px, 0, bw, img.get_height()), col)
		img.fill_rect(Rect2i(px, 0, 1, img.get_height()), col.darkened(0.4))
		# fenêtre d'étiquette (en haut), trou pour le doigt (en bas)
		var lw := bw - 6
		var lh := int(img.get_height() * 0.55)
		var label: String = labels[i]
		if label != "":
			var paper := Color(0.86, 0.84, 0.76).darkened(r.randf_range(0.0, 0.15))
			img.fill_rect(Rect2i(px + 3, 8, lw, lh), paper)
			var sc := 2 if px_text_width(label, 2) <= lh - 6 else 1
			var tw := px_text_width(label, sc)
			var tmp := Image.create_empty(tw + 2, 5 * sc + 2, false, Image.FORMAT_RGB8)
			tmp.fill(paper)
			px_text(tmp, label, Vector2i(1, 1), sc, Color(0.1, 0.1, 0.25) if r.randf() < 0.6 else Color(0.05, 0.05, 0.05))
			tmp.rotate_90(COUNTERCLOCKWISE)
			var ox := px + 3 + (lw - tmp.get_width()) / 2
			var oy := 8 + (lh - tmp.get_height()) / 2
			img.blit_rect(tmp, Rect2i(0, 0, tmp.get_width(), mini(tmp.get_height(), lh)), Vector2i(ox, maxi(8, oy)))
		var hy := int(img.get_height() * 0.8)
		var cx := px + bw / 2
		for yy in range(hy - 6, hy + 7):
			for xx in range(cx - 6, cx + 7):
				if Vector2(xx - cx, yy - hy).length() <= 6.0 and xx >= 0 and xx < img.get_width():
					img.set_pixel(xx, yy, Color(0.02, 0.02, 0.02))
		# le classeur lui-même
		if not mat_cache.has(col):
			mat_cache[col] = _m(col, 0.5)
		var bm: Material = mat_cache[col]
		_box(Vector3(depth, hh, w - 0.002), Vector3(x_front + depth / 2.0 + 0.002, y0 + hh / 2.0, z + w / 2.0), bm)
		z += w + 0.002
		px += int((w + 0.002) * ppm)
	img.generate_mipmaps()
	var q := _quad(Vector2(total, hh), Vector3(x_front + 0.0005, y0 + hh / 2.0, z0 + 0.01 + total / 2.0), _tex_mat(ImageTexture.create_from_image(img), 0.6), -PI / 2.0)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


# ------------------------------------------------------------------ la table et l'ordinateur portable

func _laptop_table() -> void:
	var table := prop("table", TABLE_C, 0.0, Vector3(1.1, 0.74, 0.62))
	var top := (table.get_meta("size") as Vector3).y
	prop("chair", Vector3(TABLE_C.x, 0, 2.95), 186.0, Vector3(0.42, 0.88, 0.42))
	# l'ordinateur portable d'Henriette, ouvert, tourné vers la chaise (+z)
	var lp := Node3D.new()
	lp.name = "Portable"
	add_child(lp)
	lp.position = Vector3(TABLE_C.x - 0.05, top, 2.42)
	lp.rotation.y = 0.08
	var silver := _plain(Color(0.5, 0.5, 0.52), 0.35, 0.6)
	var bw := 0.33
	var bd := 0.23
	_box(Vector3(bw, 0.02, bd), Vector3(0, 0.01, 0), silver, false, lp)
	var keys := Image.create_empty(66, 24, false, Image.FORMAT_RGB8)
	keys.fill(Color(0.1, 0.1, 0.11))
	for r in 5:
		for c in 15:
			keys.fill_rect(Rect2i(1 + c * 4 + (r % 2), 1 + r * 4 + 2, 3, 3), Color(0.22, 0.22, 0.24))
	keys.fill_rect(Rect2i(16, 21, 30, 3), Color(0.22, 0.22, 0.24))
	keys.generate_mipmaps()
	var kq := _quad(Vector2(0.29, 0.105), Vector3(0, 0.0205, -0.035), _tex_mat(ImageTexture.create_from_image(keys), 0.6), 0.0, lp)
	kq.rotation.x = -PI / 2.0
	_box(Vector3(0.09, 0.001, 0.055), Vector3(0, 0.0205, 0.067), _plain(Color(0.44, 0.44, 0.46), 0.3, 0.5), false, lp)
	# l'écran, sur la charnière arrière, incliné
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.02, -bd / 2.0)
	lid.rotation.x = -0.28
	lp.add_child(lid)
	_box(Vector3(bw, 0.22, 0.008), Vector3(0, 0.11, -0.004), silver, false, lid)
	_box(Vector3(bw - 0.01, 0.21, 0.002), Vector3(0, 0.11, 0.001), _plain(Color(0.03, 0.03, 0.035), 0.2), false, lid)
	_tex_lock = _laptop_screen(false)
	_tex_chat = _laptop_screen(true)
	laptop_mat = StandardMaterial3D.new()
	laptop_mat.albedo_color = Color(0.01, 0.01, 0.012)
	laptop_mat.roughness = 0.45
	laptop_mat.emission_enabled = true
	# (opérateur « ajouter » : émission = couleur + texture ; en noir, seule l'image de l'écran brille)
	laptop_mat.emission = Color.BLACK
	laptop_mat.emission_texture = _tex_lock
	laptop_mat.emission_energy_multiplier = 0.0
	_no_gi(_quad(Vector2(0.29, 0.18), Vector3(0, 0.115, 0.0025), laptop_mat, 0.0, lid))
	# le post-it collé dans le coin de l'écran
	var pm := _tex_mat(load("res://assets/images/postit_chocolat.png"), 0.95)
	var pq := _quad(Vector2(0.065, 0.065), Vector3(0.12, 0.038, 0.0038), pm, 0.0, lid)
	pq.rotation.z = -0.12
	laptop_light = OmniLight3D.new()
	laptop_light.name = "LueurPortable"
	laptop_light.light_color = Color(0.6, 0.72, 1.0)
	laptop_light.light_energy = 0.0
	laptop_light.omni_range = 1.4
	laptop_light.shadow_enabled = false
	laptop_light.position = Vector3(0, 0.14, 0.12)
	lid.add_child(laptop_light)
	# chargeur blanc jusqu'à la prise du mur nord
	_cable([Vector3(TABLE_C.x + 0.12, top + 0.01, 2.31), Vector3(TABLE_C.x + 0.3, top + 0.004, 2.15), Vector3(TABLE_C.x + 0.36, top + 0.004, ZN + 0.07),
		Vector3(TABLE_C.x + 0.38, 0.3, ZN + 0.03), Vector3(TABLE_C.x + 0.38, 0.27, ZN + 0.03)], Vector3.BACK, false)
	_socket(Vector3(TABLE_C.x + 0.38, 0.26, ZN + 0.022), Vector3.BACK)
	# une tasse oubliée, des lunettes de lecture
	_mug(Vector3(TABLE_C.x + 0.35, top, 2.5), 2.2, Color(0.8, 0.75, 0.66))
	var it := _interactable("Regarder l'ordinateur portable", Vector3(0.4, 0.3, 0.32), lp.position + Vector3(0, 0.12, 0), self, LAYER_INTERACT, 2.0)
	it.used.connect(func(_i: Interactable) -> void: use_laptop())
	set_meta("laptop_it", it)


## Écran du portable : verrouillé (fond bleu, « HENRIETTE », champ du mot de passe) ou la messagerie.
func _laptop_screen(chat: bool) -> ImageTexture:
	var w := 160
	var hh := 100
	var img := Image.create_empty(w, hh, false, Image.FORMAT_RGB8)
	if not chat:
		for y in hh:
			img.fill_rect(Rect2i(0, y, w, 1), Color(0.05, 0.12, 0.3).lerp(Color(0.2, 0.35, 0.55), float(y) / hh))
		px_text(img, "03:21", Vector2i(w / 2 - 19, 12), 2, Color(0.9, 0.93, 1.0))
		for yy in range(36, 56):
			for xx in range(70, 90):
				if Vector2(xx - 80, yy - 46).length() < 10.0:
					img.set_pixel(xx, yy, Color(0.75, 0.6, 0.55))
		px_text(img, "HENRIETTE", Vector2i(w / 2 - 17, 60), 1, Color.WHITE)
		img.fill_rect(Rect2i(45, 70, 70, 9), Color(0.9, 0.92, 0.95))
		px_text(img, "MOT DE PASSE", Vector2i(50, 72), 1, Color(0.5, 0.5, 0.55))
	else:
		img.fill(Color(0.92, 0.92, 0.9))
		img.fill_rect(Rect2i(0, 0, w, 12), Color(0.2, 0.42, 0.75))
		px_text(img, "MANON", Vector2i(6, 4), 1, Color.WHITE)
		var y := 18
		for b in [[false, 40], [false, 120], [false, 70], [true, 130], [false, 18], [false, 96]]:
			var mine: bool = b[0]
			var bw: int = b[1]
			var lines := 1 if bw < 100 else 2
			var bh := 6 + lines * 5
			var x := w - bw - 6 if mine else 6
			img.fill_rect(Rect2i(x, y, bw, bh), Color(0.35, 0.6, 0.95) if mine else Color(0.78, 0.78, 0.8))
			for l in lines:
				img.fill_rect(Rect2i(x + 4, y + 4 + l * 5, (bw - 8) if l < lines - 1 else (bw - 8) * 2 / 3, 2), Color(1, 1, 1) if mine else Color(0.3, 0.3, 0.32))
			y += bh + 3
		img.fill_rect(Rect2i(0, hh - 12, w, 12), Color(0.85, 0.85, 0.84))
		img.fill_rect(Rect2i(6, hh - 9, w - 30, 6), Color.WHITE)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## L'ordinateur portable d'Henriette : 1er appui, il se réveille (verrouillé, le post-it) ; 2e appui,
## « CHOCOLAT », la conversation avec Manon (lecteur de pages).
func use_laptop() -> void:
	if _laptop_busy:
		return
	match laptop_state:
		0:
			laptop_state = 1
			_laptop_label()
			_laptop_glow(_tex_lock, LAPTOP_LOCK_GLOW)
			Sfx.play_at("metalClick", Vector3(TABLE_C.x, 0.8, 2.4), -20.0, 2.0, 1.2)
			Game.hint(TXT_PORTABLE, 5.0)
			_story("portable_verrouille")
		1:
			laptop_state = 2
			_laptop_label()
			_laptop_busy = true
			Game.set_flag("portable_lu", true)
			for i in 8:
				get_tree().create_timer(0.09 * i, false).timeout.connect(func() -> void:
					Sfx.play_at("metalClick", Vector3(TABLE_C.x, 0.8, 2.4), -24.0, randf_range(2.4, 3.0), 1.2))
			await get_tree().create_timer(0.85, false).timeout
			_laptop_busy = false
			if not is_inside_tree():
				return
			_laptop_glow(_tex_chat, LAPTOP_CHAT_GLOW)
			_read_chat()
			_story("portable_lu")
		_:
			_read_chat()


## Libellé du portable selon son état (aussi quand le scénario appelle use_laptop() directement).
func _laptop_label() -> void:
	if has_meta("laptop_it"):
		(get_meta("laptop_it") as Interactable).label = ["Regarder l'ordinateur portable", "Taper le mot de passe", "Lire la conversation"][laptop_state]


func _read_chat() -> void:
	get_tree().call_group("hud", "read_pages", CHAT_PAGES.duplicate(), 19)


func _laptop_glow(tex: Texture2D, energy: float) -> void:
	laptop_mat.emission_texture = tex
	laptop_mat.emission_energy_multiplier = energy
	laptop_light.light_energy = 0.05 * energy


# ------------------------------------------------------------------ tableau à clés, classeur à tiroirs

func _key_board() -> void:
	var w := 0.42
	var hh := 0.315
	var c := Vector3(KEYS_C.x, KEYS_C.y, ZN + 0.012)
	_box(Vector3(w + 0.02, hh + 0.02, 0.024), c, mats.wood_dark)
	var img_mat := _image_mat("tableau_cles.png", 0.85)
	_quad(Vector2(w, hh), c + Vector3(0, 0, 0.0125), img_mat)
	var brass := _plain(Color(0.62, 0.5, 0.24), 0.35, 0.8)
	# les sept crochets (positions des étiquettes de l'image), tous vides
	var hooks := [Vector2(64, 78), Vector2(193, 78), Vector2(321, 78), Vector2(449, 78), Vector2(128, 240), Vector2(257, 240), Vector2(385, 240)]
	for p in hooks:
		var hp := c + Vector3((p.x / 512.0 - 0.5) * w, (0.5 - p.y / 384.0) * hh, 0.0125)
		_mesh(_cyl(0.0025, 0.0025, 0.026, 6), hp + Vector3(0, 0, 0.013), brass, Vector3(PI / 2.0, 0, 0))
		_mesh(_cyl(0.0025, 0.0025, 0.012, 6), hp + Vector3(0, 0.005, 0.025), brass)
	_mesh(_cyl(0.003, 0.003, 0.02, 6), c + Vector3(0, hh / 2.0 + 0.03, 0.005), mats.metal, Vector3(PI / 2.0, 0, 0))
	_look("Regarder le tableau à clés", Vector3(w + 0.06, hh + 0.06, 0.12), c + Vector3(0, 0, 0.05), TXT_TABLEAU, 2.2)


## Classeur métallique à trois tiroirs (tôle vert administration), façade vers +x, dans le coin nord-ouest ;
## dessus : la corbeille à courrier et les lettres de la banque.
func _filing_cabinet() -> void:
	var zc := 2.33
	var d := 0.52
	var w := 0.47
	var hh := 1.02
	var xb := XW + 0.062
	var xf := xb + d
	var xm := xb + d / 2.0
	var steel := _m(Color(0.33, 0.37, 0.33), 0.42, 0.5)
	var chrome := _plain(Color(0.72, 0.72, 0.74), 0.22, 1.0)
	var dark := _plain(Color(0.03, 0.03, 0.03), 0.8)
	var body := [
		_bp(Vector3(d - 0.02, hh - 0.05, w), Vector3(xm - 0.01, 0.05 + (hh - 0.05) / 2.0, zc)),
		_bp(Vector3(d + 0.004, 0.012, w + 0.006), Vector3(xm + 0.002, hh - 0.006, zc)),                 # dessus
	]
	var black := [_bp(Vector3(d - 0.06, 0.05, w - 0.04), Vector3(xm - 0.02, 0.025, zc))]                 # socle en retrait
	var shiny := []
	var cards := []
	var dh := (hh - 0.07) / 3.0
	for k in 3:
		var yc := 0.055 + dh * (k + 0.5)
		body.append(_bp(Vector3(0.018, dh - 0.008, w - 0.012), Vector3(xf - 0.011, yc, zc)))               # façade du tiroir
		black.append(_bp(Vector3(0.004, 0.026, 0.13), Vector3(xf - 0.0005, yc + dh * 0.08, zc)))          # creux de la poignée
		shiny.append(_bp(Vector3(0.016, 0.012, 0.14), Vector3(xf + 0.004, yc + dh * 0.08 - 0.016, zc)))   # poignée
		for sz in [-1.0, 1.0]:
			shiny.append(_bp(Vector3(0.016, 0.022, 0.008), Vector3(xf + 0.002, yc + dh * 0.08 - 0.008, zc + sz * 0.066)))
		shiny.append(_bp(Vector3(0.004, 0.044, 0.094), Vector3(xf - 0.001, yc + dh * 0.3, zc)))           # porte-étiquette
		cards.append(_bp(Vector3(0.002, 0.034, 0.084), Vector3(xf + 0.0015, yc + dh * 0.3, zc)))
	shiny.append(_mp(_cyl(0.011, 0.011, 0.01, 12), Vector3(xf - 0.001, hh - 0.04, zc + w / 2.0 - 0.045), Vector3(0, 0, PI / 2.0)))   # serrure
	_merged(body, steel, self, true)
	_merged(black, dark)
	_merged(shiny, chrome)
	_merged(cards, _m(Color(0.85, 0.82, 0.72), 0.9))
	_collider(Vector3(d, hh, w), Vector3(xm, hh / 2.0, zc))
	# corbeille à courrier en plastique noir (ouverte vers +x) et lettres
	var c := Vector3(xm, hh, zc)
	var tray := [_bp(Vector3(0.33, 0.006, 0.25), c + Vector3(0, 0.003, 0)), _bp(Vector3(0.006, 0.06, 0.25), c + Vector3(-0.162, 0.03, 0))]
	for sz in [-1.0, 1.0]:
		tray.append(_bp(Vector3(0.33, 0.045, 0.006), c + Vector3(0, 0.0225, sz * 0.122)))
	_merged(tray, _plain(Color(0.06, 0.06, 0.065), 0.5))
	var letters := []
	for k in 5:
		letters.append(_bp(Vector3(0.22, 0.003, 0.11 if k % 2 == 0 else 0.16), c + Vector3(rng.randf_range(-0.04, 0.02), 0.008 + k * 0.004, rng.randf_range(-0.04, 0.04)),
			Vector3(0, rng.randf_range(-0.12, 0.12), 0)))
	_merged(letters, _m(Color(0.88, 0.86, 0.8), 0.9))
	# par terre, à côté : une pile de vieux journaux ficelée
	var news := []
	var np := Vector3(5.12, 0, 2.86)
	for k in 9:
		news.append(_bp(Vector3(0.3, 0.012, 0.4), np + Vector3(rng.randf_range(-0.012, 0.012), 0.006 + k * 0.0125, rng.randf_range(-0.012, 0.012)),
			Vector3(0, rng.randf_range(-0.06, 0.06), 0)))
	_merged(news, _m(Color(0.6, 0.58, 0.5), 0.95, 0.0))
	var twine := [_bp(Vector3(0.006, 0.006, 0.41), np + Vector3(0, 0.116, 0)), _bp(Vector3(0.31, 0.006, 0.006), np + Vector3(0, 0.117, 0))]
	_merged(twine, _m(Color(0.6, 0.5, 0.34), 0.95))


# ------------------------------------------------------------------ murs

func _wall_things() -> void:
	# calendrier de la pharmacie, octobre 2040, les jours barrés par Papi
	var img := Image.create_empty(60, 84, false, Image.FORMAT_RGB8)
	img.fill(Color(0.9, 0.88, 0.82))
	for y in 36:
		img.fill_rect(Rect2i(3, 3 + y, 54, 1), Color(0.45, 0.6, 0.75).lerp(Color(0.35, 0.5, 0.3), float(y) / 36.0))
	img.fill_rect(Rect2i(3, 26, 54, 13), Color(0.3, 0.45, 0.25))
	img.fill_rect(Rect2i(36, 14, 9, 14), Color(0.55, 0.45, 0.4))
	px_text(img, "OCTOBRE 2040", Vector2i(7, 42), 1, Color(0.6, 0.12, 0.1))
	for d in 31:
		var col := (d + 2) % 7
		var row := (d + 2) / 7
		var x := 4 + col * 7 + 2
		var y := 50 + row * 6
		img.fill_rect(Rect2i(x, y, 4, 3), Color(0.35, 0.35, 0.38))
		if d < 30:
			for k in 5:
				img.set_pixel(clampi(x - 1 + k, 0, 59), clampi(y + 3 - k, 0, 83), Color(0.7, 0.12, 0.1))
	img.generate_mipmaps()
	var cm := _tex_mat(ImageTexture.create_from_image(img))
	var cal := _quad(Vector2(0.3, 0.42), Vector3(6.2, 1.55, ZS - 0.002), cm, PI)
	cal.name = "Calendrier"
	_mesh(_cyl(0.003, 0.003, 0.02, 6), Vector3(6.2, 1.78, ZS - 0.01), mats.metal, Vector3(PI / 2.0, 0, 0))
	_radiator()
	_wall_clock()
	_diploma()


## Sous la fenêtre, un radiateur en fonte à colonnes (14 éléments, peinture crème écaillée), sur pieds,
## son tuyau de cuivre et son robinet à volant.
func _radiator() -> void:
	var x := XE - 0.022 - 0.04 - 0.07
	var n := 14
	var step := 0.062
	var z0 := 3.73
	var z1 := z0 + (n - 1) * step
	var y0 := 0.14
	var y1 := 0.66
	var col := CapsuleMesh.new()
	col.radius = 0.019
	col.height = y1 - y0 + 0.05
	col.radial_segments = 8
	col.rings = 1
	var hub := _cyl(0.026, 0.026, step - 0.006, 10)
	hub.cap_top = false
	hub.cap_bottom = false
	var parts := []
	for i in n:
		var zz := z0 + i * step
		for sx in [-0.03, 0.03]:
			parts.append(_mp(col, Vector3(x + sx, (y0 + y1) / 2.0, zz)))
		parts.append(_bp(Vector3(0.05, y1 - y0 - 0.06, 0.008), Vector3(x, (y0 + y1) / 2.0, zz)))       # voile entre les colonnes
		# moyeux haut et bas (ils se touchent d'un élément à l'autre)
		for yy in [y0, y1]:
			parts.append(_mp(hub, Vector3(x, yy, zz), Vector3(PI / 2.0, 0, 0)))
	for zz in [z0 + step, z1 - step]:
		parts.append(_bp(Vector3(0.11, y0, 0.045), Vector3(x, y0 / 2.0, zz)))                          # pieds
	_merged(parts, _grimy(_plain(Color(0.64, 0.6, 0.51), 0.42, 0.2), 1.6))
	# tuyaux de cuivre : retour en bas (côté nord), arrivée et robinet en haut (côté sud)
	var copper := _plain(Color(0.5, 0.32, 0.22), 0.4, 0.85)
	var pipe := [
		_mp(_cyl(0.011, 0.011, 0.08, 10), Vector3(x, y0, z0 - 0.06), Vector3(PI / 2.0, 0, 0)),
		_mp(_cyl(0.011, 0.011, y0, 10), Vector3(x, y0 / 2.0, z0 - 0.1)),
		_mp(_cyl(0.011, 0.011, 0.06, 10), Vector3(x, y1, z1 + 0.05), Vector3(PI / 2.0, 0, 0)),
		_mp(_cyl(0.011, 0.011, y1 - 0.04, 10), Vector3(x, (y1 - 0.04) / 2.0, z1 + 0.11)),
	]
	_merged(pipe, copper)
	var valve := [
		_mp(_cyl(0.02, 0.02, 0.07, 12), Vector3(x, y1 - 0.01, z1 + 0.11)),
		_mp(_cyl(0.006, 0.006, 0.04, 8), Vector3(x, y1 + 0.04, z1 + 0.11)),
	]
	_merged(valve, _brass())
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.022
	wheel.outer_radius = 0.032
	wheel.rings = 16
	wheel.ring_segments = 6
	_mesh(wheel, Vector3(x, y1 + 0.06, z1 + 0.11), _plain(Color(0.08, 0.07, 0.06), 0.5))
	_collider(Vector3(0.16, 0.72, 0.9), Vector3(x, 0.36, 4.13))


## Horloge murale (wall_clock, Poly Haven) au-dessus de l'écran, arrêtée à 3 h 12 (comme la comtoise du
## couloir). Ses aiguilles sont des nœuds du modèle, tournés autour du centre du cadran.
func _wall_clock() -> void:
	var c := Vector3(7.2, 1.98, ZS)
	var clk := model("wall_clock", Vector3(c.x, c.y - 0.15, c.z - 0.024), 180.0, Vector3(0.3, 0, 0), false, {"name": "HorlogeMurale"})
	for n in clk.find_children("*", "MeshInstance3D", true, false):
		var nm := String(n.name)
		# angle de chaque aiguille dans le modèle (sens horaire depuis midi) -> 3 h 12 min 40 s
		# (pointe des aiguilles dans le glTF : heures −53,2°, minutes 57°, secondes 170,5°)
		var turn := {"wall_clock_hours_hand": 96.0 + 53.2, "wall_clock_minute_hand": 72.0 - 57.0, "wall_clock_second_hand": 240.0 - 170.5}
		if turn.has(nm):
			(n as Node3D).rotation.z = -deg_to_rad(turn[nm])


## Diplôme de la médaille d'honneur du travail d'Albert, encadré (baguette de noyer, passe-partout,
## verre) au-dessus de la table.
func _diploma() -> void:
	var iw := 120
	var ih := 90
	var img := Image.create_empty(iw, ih, false, Image.FORMAT_RGB8)
	img.fill(Color(0.86, 0.82, 0.7))
	var gold := Color(0.6, 0.47, 0.22)
	for k in [3, 6]:
		img.fill_rect(Rect2i(k, k, iw - 2 * k, 1), gold)
		img.fill_rect(Rect2i(k, ih - k - 1, iw - 2 * k, 1), gold)
		img.fill_rect(Rect2i(k, k, 1, ih - 2 * k), gold)
		img.fill_rect(Rect2i(iw - k - 1, k, 1, ih - 2 * k), gold)
	img.fill_rect(Rect2i(57, 10, 2, 7), Color(0.15, 0.2, 0.5))
	img.fill_rect(Rect2i(59, 10, 2, 7), Color(0.92, 0.9, 0.85))
	img.fill_rect(Rect2i(61, 10, 2, 7), Color(0.7, 0.12, 0.1))
	var title := "MÉDAILLE D'HONNEUR"
	px_text(img, title, Vector2i((iw - px_text_width(title)) / 2, 21), 1, Color(0.25, 0.18, 0.1))
	px_text(img, "DU TRAVAIL", Vector2i((iw - px_text_width("DU TRAVAIL")) / 2, 28), 1, Color(0.25, 0.18, 0.1))
	px_text(img, "VERMEIL", Vector2i((iw - px_text_width("VERMEIL")) / 2, 38), 1, Color(0.55, 0.12, 0.1))
	for k in 5:
		var lw: int = [80, 92, 70, 86, 40][k]
		img.fill_rect(Rect2i((iw - lw) / 2, 50 + k * 5, lw, 1), Color(0.45, 0.42, 0.38))
	for yy in range(70, 82):
		for xx in range(14, 26):
			if Vector2(xx - 20, yy - 76).length() <= 5.5:
				img.set_pixel(xx, yy, Color(0.62, 0.14, 0.1))
	for k in 14:
		img.set_pixel(84 + k, 78 - int(abs(sin(k * 0.9)) * 3.0), Color(0.12, 0.12, 0.3))
	img.generate_mipmaps()
	var c := Vector3(7.0, 1.6, ZN)
	var fw := 0.44
	var fh := 0.34
	var b := 0.03
	var frame := [
		_bp(Vector3(fw, b, 0.022), c + Vector3(0, fh / 2.0 - b / 2.0, 0.011)), _bp(Vector3(fw, b, 0.022), c + Vector3(0, -fh / 2.0 + b / 2.0, 0.011)),
		_bp(Vector3(b, fh - 2.0 * b, 0.022), c + Vector3(-fw / 2.0 + b / 2.0, 0, 0.011)), _bp(Vector3(b, fh - 2.0 * b, 0.022), c + Vector3(fw / 2.0 - b / 2.0, 0, 0.011)),
		_bp(Vector3(fw - 2.0 * b, fh - 2.0 * b, 0.004), c + Vector3(0, 0, 0.004)),
	]
	_merged(frame, _wood())
	_quad(Vector2(fw - 2.0 * b, fh - 2.0 * b), c + Vector3(0, 0, 0.0065), _m(Color(0.8, 0.76, 0.66), 0.9))
	_quad(Vector2(fw - 2.0 * b - 0.05, fh - 2.0 * b - 0.05), c + Vector3(0, 0, 0.0075), _tex_mat(ImageTexture.create_from_image(img), 0.85))
	var g := _quad(Vector2(fw - 2.0 * b, fh - 2.0 * b), c + Vector3(0, 0, 0.016), mats.glass)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh(_cyl(0.002, 0.002, 0.02, 6), c + Vector3(0, fh / 2.0 + 0.02, 0.006), mats.metal, Vector3(PI / 2.0, 0, 0))


# ------------------------------------------------------------------ les caméras, le réveil du bureau

## Le bureau se réveille (appelé par le scénario à l'entrée) : ventilateurs, écran, quatre caméras,
## la box qui s'emballe. Rend la main quand la console est prête (moins de 3 s). Drapeau
## « console_allumee » (restore() rallume la console après un chargement).
func wake_up() -> void:
	Game.set_flag("console_allumee", true)
	if box:
		box.frenzy(4.0)
	if console:
		await console.boot()


## « Regarder les caméras » : la console en grand ; les indices H-CAM2, H-CAM3, H-CAM4 ; jauge +2 et
## stress +0,3 la première fois.
func look_cameras() -> void:
	if console == null or not console.booted or _cams_busy:
		return
	_cams_busy = true
	var first: bool = not Game.flag("cameras_vues", false)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_screen"):
		hud.show_screen(console.screen_texture())
		# (le grand écran couvre la ligne des indices : on pense après l'avoir refermé)
		if hud.has_signal("screen_closed") and bool(hud.get("screen_open")):
			await hud.screen_closed
	await get_tree().create_timer(0.4, false).timeout
	for t in H_CAM:
		if not is_inside_tree():
			return
		Game.hint(t, Haunt.subtitle_time(t) + 0.5)
		await get_tree().create_timer(Haunt.subtitle_time(t) + 0.6, false).timeout
	_cams_busy = false
	if first:
		Game.set_flag("cameras_vues", true)
		var hn := _haunt()
		if hn:
			hn.peur(2.0, "cameras")
			hn.stress(0.3, "caméras")
	_story("cameras_regardees", {"premiere": first})


func _process(delta: float) -> void:
	if console == null:
		return
	var on := console.booted or console.booting
	if on != _was_booted:
		_was_booted = on
		cams_it.enabled = console.booted
		webcam_led.emission_energy_multiplier = 3.0 if on else 0.0
		for m in tower_leds:
			m.emission_energy_multiplier = 2.5 if on else 0.0
		if on and box:
			box.frenzy(3.5)
	if console.booted and not cams_it.enabled:
		cams_it.enabled = true
	_fan_speed = move_toward(_fan_speed, 22.0 if on else 0.0, delta * (14.0 if on else 6.0))
	if _fan_speed > 0.01:
		for f in fans:
			f.rotation.z += _fan_speed * delta


# ------------------------------------------------------------------ sauvegarde

## Réapplique l'état après un chargement : console allumée, tiroir ouvert, tournevis pris, box déjà
## débranchée, portable déverrouillé, lumière.
func restore() -> void:
	if Game.flag("console_allumee", false) and console and not console.booted:
		wake_up()
	if Game.flag("tiroir_bureau_ouvert", false) or Game.has_item("tournevis"):
		open_drawer(0.0, true)
	if Game.has_item("tournevis"):
		screwdriver.visible = false
		drawer_it.enabled = false
	if Game.flag("box_debranchee", false):
		box_unplugged = true
		box_it.label = "Regarder la box"
	if Game.flag("portable_lu", false):
		laptop_state = 2
		_laptop_glow(_tex_chat, LAPTOP_CHAT_GLOW)
		_laptop_label()
	var lit: bool = Game.flag("lumiere_bureau", false)
	if lit != light_on:
		light_on = lit
		bulb.set_powered(lit)
		switch_rocker.rotation.x = -0.16 if lit else 0.16
		(get_meta("switch_it") as Interactable).label = "Éteindre la lumière" if lit else "Allumer la lumière"
