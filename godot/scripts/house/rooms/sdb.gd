extends HouseRoom
## La salle de bain : carrelage, faïence crème jusqu'à 1,4 m, sanitaires vert d'eau des années 80,
## et, posés par-dessus, les appareils de la téléassistance : le miroir connecté (une dalle-écran et
## une caméra, « pour détecter les chutes »), le sèche-serviettes et le pèse-personne connectés.
## La baignoire est pleine d'une eau noire, derrière son rideau fermé.
## Repère : intérieur x 4.8 → 9.2, z −7.3 → −4.0, sol y = 0, plafond 2.6. Porte P4 sur le mur
## x = 4.75 en z −4.6 (zone de battant laissée libre : x 4.8 → 5.75, z −5.1 → −4.0). Fenêtre F4
## (verre dépoli) sur le mur du jardin, x = 9.25, z −5.8.
##
## Fonctions publiques (pour le scénario et l'autotest) :
##   mirror (SmartMirror, « miroir »), applique (SmartBulb, « applique »), towel_rail (Connected,
##   « seche_serviettes »), scale_dev (Connected, « balance »), curtain_real, curtain_feed, silhouette ;
##   flicker(secondes) : l'applique vacille ; run_p4() -> String (await) : le P4 réel ;
##   show_scale(texte, secondes), hide_scale() ; take_dryer() ; restore().
## Événements Haunt.story_event : « seche_cheveux_pris ».
## Drapeaux Game.flags : « seche_cheveux_pris », « applique_eclatee » (posé par le miroir).
##
## Passe « triple A » (lot V2-SDB) :
##  - baignoire en acier émaillé et WC monobloc des années 80 modelés ici (loft de superellipses, maillages
##    en cache statique, occlusion et cerne en couleur de sommet), posés SOUS props["bathtub"] et
##    props["toilet"] (les Kenney sont cachés, leurs boîtes et collisions restent) ; meuble bas en mélaminé ;
##  - l'eau noire : vraie carte, un miroir d'encre (rugosité 0,03, ondulation lente) sur la couche de rendu
##    LAYER_EAU, que la sonde figée de la pièce ne touche pas : ses reflets suivent les lumières (SSR et
##    éclairage indirect), la lampe de poche comprise ; la sonde de la pièce (miroir, émail) × SDB_PROBE_GAIN ;
##  - rideau : curtain.gdshader (plis irréguliers avec leurs normales, plastique translucide, froissures,
##    moisissure du bas) ; anneaux décalés ;
##  - applique plus douce (APPLIQUE_*_NET), à 50 % après l'épisode du miroir (APPLIQUE_APRES_P4) ;
##  - matières locales : peinture cloquée (PaintedPlaster012) et damier désaturé, sans toucher à « mats » ;
##  - dress_details : lunettes, canard, boîte à pharmacie, flacon, et l'usure (Wear) de la pièce.

const XW := 4.812        # face du papier peint, mur ouest (couloir, porte P4)
const XE := 9.188        # mur est (jardin, fenêtre F4)
const ZN := -7.288       # pignon nord (la baignoire)
const ZS := -4.012       # mur sud (lavabo, miroir ; la lingerie derrière)
const TILE := 0.022      # épaisseur de la faïence…
const TILE_H := 1.4      # … jusqu'à 1,4 m

## Trajet de la silhouette du flux (§ 5.2) : un point toutes les 2,5 s, puis la place du joueur.
const P4_PATH := [Vector3(6.6, 0, -6.9), Vector3(6.7, 0, -6.2), Vector3(6.85, 0, -5.6), Vector3(7.0, 0, -5.1)]
## Place du joueur au miroir (autotest) : debout à 0,8 m du lavabo, face au miroir.
const PLAYER_AT_MIRROR := Vector3(7.0, 0, -4.85)
const PLAYER_AT_MIRROR_YAW := PI
const MIRROR_POS := Vector3(7.0, 1.5, -4.03)
const LAMP_POS := Vector3(7.0, 2.0, -4.1)
const TUB_POS := Vector3(6.6, 0, -6.92)
const WATER_Y := 0.45
const WATER_CENTER := Vector3(6.57, 0.45, -6.894)   # l'intérieur de la baignoire n'est pas centré
const CURTAIN_Z := -6.5
const SCALE_TEXT := "58,0"

## Couche de RENDU de l'eau noire (vraie carte) : la sonde de la pièce ne l'éclaire pas (reflection_mask) ;
## caméras, lumières et caméras de flux la voient comme la couche 1. Ses reflets viennent du SSR et de
## l'éclairage indirect (VoxelGI), qui suivent toutes les lumières, la lampe de poche comprise : une sonde
## figée (essayée : « RefletsBain », 30 cm au-dessus de l'eau) ne renvoyait qu'un noir mat, capturée
## sans la lampe ni le rebond de la lumière.
const LAYER_EAU := 15
## Gain des reflets de la sonde de la pièce (salle de bain carrelée : la capture, sans la VoxelGI, perd
## une grande part de la lumière, qui y rebondit sur la faïence ; le miroir éteint et l'émail en
## paraissaient noirs).
const SDB_PROBE_GAIN := 1.5
## Eau noire, vraie carte : albédo d'encre, rugosité, spéculaire (≈ 10 % de face : une encre qui luit,
## un peu plus que l'eau claire), ondulation (pente de la normale) et sa vitesse (m/s).
const WATER_ALBEDO := Color(0.006, 0.008, 0.007)
const WATER_ROUGH := 0.03
const WATER_SPEC := 0.7
const WATER_RIPPLE := 0.07
const WATER_SPEED := 0.006
## Émail vert d'eau (vraie carte) et tablier de la baignoire (plus mat : il brûlait sous le rideau).
const ENAMEL_NET := Color(0.62, 0.69, 0.64)
const ENAMEL_ROUGH_NET := 0.11
const APRON_NET := Color(0.52, 0.59, 0.54)
const APRON_ROUGH_NET := 0.32
## Peinture cloquée de la pièce (PaintedPlaster012, gris-vert : teinte vers le crème) et damier désaturé.
const PAINT_TEX := "PaintedPlaster012/PaintedPlaster012"
const PAINT_NET := Color(1.02, 1.0, 1.06)      # (albédo linéaire ≈ 0,68 × celui de mats.wall_paint)
const PAINT_ROUGH := 0.8
const FAIENCE_K := 0.84                         # faïence de la pièce un peu plus sombre (copie locale)
const DAMIER_SAT := 0.85
const DAMIER_BRIGHT := 0.9
## Maillages modelés (une fois par lancement : cache statique).
const TUB_SEG := 52
const WC_SEG := 32
static var _tub_meshes: Array = []
static var _wc_meshes: Array = []
static var _mesh_task := -1
static var _ridge_tex: ImageTexture
static var _crinkle_tex: NoiseTexture2D
static var _ripple_tex: NoiseTexture2D
static var _water_shader: Shader
static var _damier_tex: Texture2D

var house: House
var rng := RandomNumberGenerator.new()

var mirror: SmartMirror
var applique: SmartBulb
var towel_rail: Connected
var scale_dev: Connected
var curtain_real: Node3D
var curtain_feed: Node3D
var silhouette: MeshInstance3D

var dryer: Node3D
var dryer_it: Interactable
var mirror_it: Interactable
var scale_mat: StandardMaterial3D
var scale_text := ""
var _scale_id := 0
var _p4_scale := false
var _drip_t := 4.0
var _check_t := 0.0
var _shards_done := false

var _enamel: StandardMaterial3D
var _enamel_v: StandardMaterial3D     # le même, avec l'occlusion et le cerne en couleur de sommet
var _apron: StandardMaterial3D
var _chrome: StandardMaterial3D
var _new_white: StandardMaterial3D
var _cable_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _towel_mat: StandardMaterial3D
var _faience: Material                # faïence de la pièce (vraie carte : copie locale assombrie)

var _old_traces: Array = []           # décalques d'avant (_traces), cachés quand Wear les remplace
var water: MeshInstance3D


func furnish(h: House) -> void:
	house = h
	rng.seed = 4407
	var full := not Builder.soft_render()
	# émail vert d'eau des années 80 : lisse et brillant (le reflet net de l'applique et de la lampe de
	# poche glisse dessus), avec la crasse des joints ; chrome un peu terni (pas de reflets du décor :
	# l'environnement n'en donne pas, il garde donc une part de diffus pour ne pas virer au noir)
	_enamel = _grimy(_plain(Color(0.66, 0.74, 0.69), 0.14), 0.7)
	_enamel.metallic_specular = 0.75
	if full:
		# (vraie carte : la sonde et le SSR donnent les reflets ; un émail de céramique ordinaire suffit)
		_enamel = _grimy(_plain(ENAMEL_NET, ENAMEL_ROUGH_NET), 0.7)
		_enamel.metallic_specular = 0.5
	_enamel_v = _enamel.duplicate() as StandardMaterial3D
	_enamel_v.vertex_color_use_as_albedo = true
	_apron = _grimy(_plain(APRON_NET if full else Color(0.56, 0.63, 0.57), APRON_ROUGH_NET if full else 0.25), 0.5)
	_apron.vertex_color_use_as_albedo = true
	_faience = mats.faience
	if full and mats.faience is StandardMaterial3D:
		var fa := (mats.faience as StandardMaterial3D).duplicate() as StandardMaterial3D
		var fc := fa.albedo_color
		fa.albedo_color = Color(fc.r * FAIENCE_K, fc.g * FAIENCE_K, fc.b * FAIENCE_K, fc.a)
		fa.resource_name = "FaienceSdb"
		_faience = fa
	_chrome = _plain(Color(0.78, 0.78, 0.8), 0.15, 0.65)
	_chrome.metallic_specular = 0.8
	_new_white = _plain(Color(0.74, 0.74, 0.72), 0.4)
	# (vraie carte : câble un peu moins blanc ; sous l'applique, il était écrêté)
	_cable_mat = _plain(Color(0.78, 0.78, 0.75) if full else Color(0.9, 0.9, 0.88), 0.4)
	_tape_mat = _plain(Color(0.78, 0.76, 0.68), 0.3)
	_towel_mat = _fabric(Color(0.5, 0.6, 0.68))
	_bathtub()
	_curtains()
	_sink()
	_mirror()
	_applique()
	_cabinet()
	_toilet()
	_towel_rail()
	_scale()
	_basket()
	_rug()
	_clutter()
	_window_glow()
	_silhouette()
	_traces()
	if full:
		_local_paint()


## Vraie carte : la peinture de la pièce (au-dessus de la faïence) devient une copie locale, en
## PaintedPlaster012 (plâtre peint cloqué, écaillé par l'humidité), teintée crème et plus sombre que
## mats.wall_paint (qui reste celle de la lingerie) ; la faïence aussi (_faience). Avant la cuisson
## VoxelGI : le rebond suit.
func _local_paint() -> void:
	var paint: Material = null
	if ResourceLoader.exists(Surfaces.DIR + PAINT_TEX + "_albedo.jpg"):
		paint = Surfaces.grime(Surfaces.pbr(PAINT_TEX, 1.6, PAINT_NET, 1.0, true, false, PAINT_ROUGH), 0.5, 1)
		paint.resource_name = "PeintureSdb"
		(paint as StandardMaterial3D).ao_light_affect = 0.15
	for i in mini(int(get_meta("coque", 0)), get_child_count()):
		var mi := get_child(i) as MeshInstance3D
		if mi == null:
			continue
		if paint and mi.material_override == mats.wall_paint:
			mi.material_override = paint
		elif mi.material_override == mats.faience and _faience != mats.faience:
			mi.material_override = _faience


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


## Objet émissif ou transparent : hors de l'éclairage indirect cuit, sans ombre.
func _no_gi(mi: GeometryInstance3D) -> GeometryInstance3D:
	return Connected.no_gi(mi)


## Tube droit de a à b (tringle, barre, tuyau).
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


func _log(what: String) -> void:
	var hn := Haunt.of(get_tree())
	if hn:
		hn.log({"ev": "examine", "what": what, "room": "sdb"})


func _look(label: String, size: Vector3, pos: Vector3, text: String, what: String, reach := 2.2) -> Interactable:
	var it := _interactable(label, size, pos, self, LAYER_INTERACT, reach)
	it.used.connect(func(_i: Interactable) -> void:
		_hint(text)
		_log(what))
	return it


## Câble blanc, neuf, en segments droits, scotché tous les 40 cm (même façon que le couloir).
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


## Prise de courant sur un mur (« normal » : vers la pièce), avec sa fiche blanche branchée.
func _socket(pos: Vector3, normal: Vector3, plugged := true) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Prise"
	add_child(holder)
	holder.position = pos
	holder.rotation.y = atan2(normal.x, normal.z)
	_box(Vector3(0.075, 0.075, 0.012), Vector3(0, 0, 0.006), _m(Color(0.74, 0.71, 0.62), 0.5), false, holder)
	_mesh(_cyl(0.023, 0.023, 0.004), Vector3(0, 0, 0.0125), _m(Color(0.62, 0.58, 0.5), 0.5), Vector3(PI / 2.0, 0, 0), holder)
	if plugged:
		_box(Vector3(0.036, 0.042, 0.03), Vector3(0, 0, 0.03), _new_white, false, holder)
	return holder


func _decal(tex: Texture2D, center: Vector3, normal: Vector3, up: Vector3, size_u: float, size_v: float, depth := 0.2, mod := Color.WHITE) -> Decal:
	var d := Decal.new()
	_old_traces.append(d)
	d.texture_albedo = tex
	d.size = Vector3(size_u, depth, size_v)
	d.modulate = mod
	var y := normal.normalized()
	var z := -up.normalized()
	var x := y.cross(z)
	d.transform = Transform3D(Basis(x, y, z), center)
	add_child(d)
	return d


## Remplace les matières de certaines surfaces d'un meuble Kenney (clé : nom de la matière d'origine).
func _retint(holder: Node3D, by_name: Dictionary) -> void:
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name.to_lower() if src else ""
			if by_name.has(key):
				mi.set_surface_override_material(i, by_name[key])


## Garde seulement certaines surfaces d'un maillage Kenney (retire un lavabo, un robinet…).
func _strip(holder: Node3D, mesh_name: String, keep: Array) -> void:
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not String(mi.name).begins_with(mesh_name):
			continue
		var src := mi.mesh
		var overrides := []
		for i in src.get_surface_count():
			overrides.append(mi.get_surface_override_material(i))
		var out := ArrayMesh.new()
		var mats_kept := []
		for i in src.get_surface_count():
			if keep.has(i):
				out.add_surface_from_arrays(src.surface_get_primitive_type(i), src.surface_get_arrays(i))
				out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(i))
				mats_kept.append(overrides[i])
		mi.mesh = out
		for i in mats_kept.size():
			mi.set_surface_override_material(i, mats_kept[i])


## Tissu éponge (serviettes, gant, tapis de bain) : la laine tissée des tapis (ambientCG Fabric045,
## déjà chargée par Builder), plus serrée, teintée ; un aplat mat si la texture manque.
func _fabric(c: Color, meters := 0.22) -> StandardMaterial3D:
	if ResourceLoader.exists("res://assets/textures/Fabric045/Fabric045_Color.jpg"):
		return Surfaces.pbr_acg("Fabric045/Fabric045", meters, Color(c.r * 1.3, c.g * 1.3, c.b * 1.3), 1.2)
	return _m(c, 1.0)


## Petit objet Poly Haven (CC0) posé à la main, à sa taille réelle × s : matières corrigées par Builder
## (élagage des faces arrière, verre), hors cuisson VoxelGI, sans collision. null si le modèle manque.
func _ph(id: String, pos: Vector3, rot_y := 0.0, s := 1.0, parent: Node3D = self) -> Node3D:
	if not ResourceLoader.exists(PH_PATH % [id, id]):
		return null
	var inst := _ph_instance(id, {})
	for g in inst.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	inst.name = id
	parent.add_child(inst)
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = Vector3.ONE * s
	return inst


# ------------------------------------------------------------------ modelage (lot V2-SDB)

## Les maillages modelés (baignoire, WC) se construisent en tâche de fond dès le chargement du script :
## la maison charge les scripts des pièces avant de les meubler, la tâche finit pendant les pièces
## précédentes et la mesure B16 ne la paie pas (furnish l'attend, _await_meshes).
static func _static_init() -> void:
	_mesh_task = WorkerThreadPool.add_task(func() -> void:
		_tub_meshes = _build_tub_meshes()
		_wc_meshes = _build_wc_meshes(), true, "sdb : baignoire et WC")


static func _await_meshes() -> void:
	if _mesh_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_mesh_task)
		_mesh_task = -1
	if _tub_meshes.is_empty():
		_tub_meshes = _build_tub_meshes()
	if _wc_meshes.is_empty():
		_wc_meshes = _build_wc_meshes()


## Angles des « seg » points d'un anneau de superellipse : à pas d'angle constant (x = a·cos^(2/n),
## z = b·sin^(2/n)), ce qui serre les points dans les arrondis, là où ils servent (les côtés droits n'en
## ont pas besoin) ; les anneaux d'un même loft se correspondent point à point (mêmes angles).
## (Le pas égal le long du contour, de Builder.superellipse, coûtait 2 ms de plus à la mesure B16.)
static func _se_params(_a: float, _b: float, _n: float, seg: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(seg)
	for k in seg:
		out[k] = TAU * k / seg
	return out


## Anneau de superellipse (demi-axes a en x, b en z, exposant n, centre c) aux angles « ts ».
static func _se_ring(a: float, b: float, n: float, c: Vector2, ts: PackedFloat32Array) -> PackedVector2Array:
	var e := 2.0 / n
	var out := PackedVector2Array()
	out.resize(ts.size())
	for i in ts.size():
		var co := cos(ts[i])
		var si := sin(ts[i])
		out[i] = c + Vector2(a * signf(co) * pow(absf(co), e), b * signf(si) * pow(absf(si), e))
	return out


## Loft d'anneaux décrits par [y, a, b, n, cx, cz] (Builder.loft_mesh), aux angles « ts ».
static func _loft(rings: Array, ts: PackedFloat32Array, caps := false, inside := false) -> ArrayMesh:
	var secs := []
	var ys := PackedFloat32Array()
	for r in rings:
		secs.append(_se_ring(r[1], r[2], r[3], Vector2(r[4], r[5]), ts))
		ys.append(r[0])
	return loft_mesh(secs, ys, caps, inside)


## Copie d'un maillage (surface 0) avec une couleur de sommet (la matière a vertex_color_use_as_albedo) :
## occlusion et cernes, selon « mode » (TINT_*), calculés ici sans appel par sommet (mesure B16).
enum { TINT_APRON, TINT_RIM, TINT_BOWL, TINT_WC, TINT_WC_IN }
static func _tinted(mesh: ArrayMesh, mode: int) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(verts.size())
	var white := Color(1, 1, 1)
	var ring_col := Color(0.36, 0.31, 0.22)
	var lime := Color(0.62, 0.5, 0.3)
	for i in verts.size():
		var p := verts[i]
		var c := white
		match mode:
			TINT_APRON:
				# le retrait du pied (3,5 cm) est noir ; le bas du tablier dans l'ombre
				var k := 0.1 if p.y < 0.04 else lerpf(0.5, 1.0, smoothstep(0.046, 0.2, p.y))
				c = Color(k, k, k)
			TINT_RIM:
				# un peu de crasse contre le mur, du calcaire côté robinets
				var k := 1.0 - 0.1 * smoothstep(-0.3, -0.37, p.z)
				var y := smoothstep(0.55, 0.78, p.x) * 0.12
				c = Color(k, k * (1.0 - y * 0.2), k * (1.0 - y))
			TINT_BOWL:
				# le cerne d'une eau restée des jours : une ligne noirâtre au ras de l'eau, qui s'estompe
				var dy := (p.y - WATER_Y - 0.006) / 0.007
				var ring := 0.8 if p.y < WATER_Y else clampf(exp(-dy * dy) * 0.6 + smoothstep(0.5, 0.452, p.y) * 0.22, 0.0, 0.85)
				c = white.lerp(ring_col, ring)
				var y := smoothstep(0.5, 0.72, p.x) * 0.1
				c = Color(c.r, c.g * (1.0 - y * 0.3), c.b * (1.0 - y))
			TINT_WC:
				var k := 0.25 if p.y < 0.006 else lerpf(0.5, 1.0, smoothstep(0.0, 0.1, p.y))
				c = Color(k, k, k)
			TINT_WC_IN:
				# sous le rebord, plus sombre ; cerne de calcaire jaunâtre au-dessus de l'eau
				var k := lerpf(0.55, 1.0, smoothstep(0.24, 0.36, p.y)) * (1.0 - 0.18 * smoothstep(0.39, 0.405, p.y))
				var dy := (p.y - 0.268) / 0.012
				c = Color(k, k, k).lerp(lime, exp(-dy * dy) * 0.55)
		cols[i] = c
	arr[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


## Disque plat (eau d'une cuvette, d'une baignoire) en superellipse, normale +y, UV dans le rectangle
## englobant : éventail depuis le centre.
static func _se_disc(a: float, b: float, n: float, ts: PackedFloat32Array) -> ArrayMesh:
	var ring := _se_ring(a, b, n, Vector2.ZERO, ts)
	var verts := PackedVector3Array([Vector3.ZERO])
	var norms := PackedVector3Array([Vector3.UP])
	var tans := PackedFloat32Array([1.0, 0.0, 0.0, 1.0])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	for p in ring:
		verts.append(Vector3(p.x, 0.0, p.y))
		norms.append(Vector3.UP)
		tans.append_array([1.0, 0.0, 0.0, 1.0])
		uvs.append(Vector2(p.x / (2.0 * a) + 0.5, p.y / (2.0 * b) + 0.5))
	var idx := PackedInt32Array()
	var m := ring.size()
	for i in m:
		# (Godot : face avant dans le sens horaire ; vue d'en haut, l'éventail tourne dans l'autre sens)
		idx.append_array([0, 1 + i, 1 + (i + 1) % m])
	return _arrays_mesh(verts, norms, tans, uvs, idx)


## Lissage d'une ligne brisée (Catmull-Rom, « sub » points par segment).
static func _smooth_path(p: PackedVector3Array, sub := 3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := p.size()
	for i in n - 1:
		var p0 := p[maxi(i - 1, 0)]
		var p1 := p[i]
		var p2 := p[i + 1]
		var p3 := p[mini(i + 2, n - 1)]
		for k in sub:
			var t := float(k) / sub
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(p[n - 1])
	return out


## Tube le long d'une ligne (flexible de douche, cordon) : repère transporté (pas de vrille), UV
## u = abscisse (m), v = tour ; tangente le long du tube (pour une carte de normales d'annelures).
static func _tube(p: PackedVector3Array, r: float, sides := 8) -> ArrayMesh:
	var n := p.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var prev_t := (p[1] - p[0]).normalized()
	var u := prev_t.cross(Vector3.UP)
	if u.length() < 0.1:
		u = prev_t.cross(Vector3.RIGHT)
	u = u.normalized()
	var acc := 0.0
	for i in n:
		var t := (p[mini(i + 1, n - 1)] - p[maxi(i - 1, 0)]).normalized()
		var axis := prev_t.cross(t)
		if axis.length() > 1e-6:
			u = u.rotated(axis.normalized(), prev_t.angle_to(t))
		u = (u - t * u.dot(t)).normalized()
		prev_t = t
		var v := t.cross(u)
		if i > 0:
			acc += p[i].distance_to(p[i - 1])
		for j in sides + 1:
			var a := TAU * j / sides
			var w := u * cos(a) + v * sin(a)
			verts.append(p[i] + w * r)
			norms.append(w)
			tans.append_array([t.x, t.y, t.z, 1.0])
			uvs.append(Vector2(acc, float(j) / sides))
	for i in n - 1:
		for j in sides:
			var a := i * (sides + 1) + j
			var c := a + sides + 1
			idx.append_array([a, c, a + 1, a + 1, c, c + 1])
	return _arrays_mesh(verts, norms, tans, uvs, idx)


## Carte de normales des annelures d'un flexible (une spire par répétition, le long de u).
static func _ridges() -> ImageTexture:
	if _ridge_tex == null:
		var img := Image.create_empty(16, 4, false, Image.FORMAT_RGB8)
		for x in 16:
			var nx := cos(TAU * x / 16.0) * 0.6
			var c := Color(nx * 0.5 + 0.5, 0.5, sqrt(1.0 - nx * nx) * 0.5 + 0.5)
			for y in 4:
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_ridge_tex = ImageTexture.create_from_image(img)
	return _ridge_tex


## Froissures du rideau de plastique et ondulation de l'eau : cartes de normales de bruit (générées en
## tâche de fond par Godot, une fois).
static func _noise_normal(seed_n: int, freq: float, bump: float, size := 256) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	nt.width = size
	nt.height = size
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = bump
	nt.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.seed = seed_n
	fn.frequency = freq
	fn.fractal_octaves = 3
	nt.noise = fn
	return nt


## Les maillages de la baignoire (repère de props["bathtub"] : pied au sol, centre de l'empreinte) :
## [tablier, rebord roulé, cuve, disque de l'eau (centré sur l'origine)]. Acier émaillé de 1,70 × 0,74 × 0,56 m, rebord plat de 7 à 13 cm (les
## flacons et le canard y tiennent), cuve centrée sur l'eau (WATER_CENTER), cerne noirâtre au niveau de
## l'eau, ombre au pied du tablier.
static func _build_tub_meshes() -> Array:
	var c := Vector2(WATER_CENTER.x - TUB_POS.x, WATER_CENTER.z - TUB_POS.z)
	var to := _se_params(0.85, 0.37, 8.0, TUB_SEG)
	var ti := _se_params(0.70, 0.25, 4.0, TUB_SEG)
	var o := Vector2.ZERO
	var apron := _loft([[0.0, 0.833, 0.353, 8.0, 0.0, 0.0], [0.035, 0.833, 0.353, 8.0, 0.0, 0.0], [0.046, 0.85, 0.37, 8.0, 0.0, 0.0],
		[0.2, 0.85, 0.37, 8.0, 0.0, 0.0], [0.52, 0.85, 0.37, 8.0, 0.0, 0.0]], to)
	apron = _tinted(apron, TINT_APRON)
	# rebord : l'arrondi extérieur, le plat (sur les anneaux de la cuve), la lèvre
	var rim_secs := []
	var rim_ys := PackedFloat32Array()
	for r in [[0.52, 0.85, 0.37, 8.0], [0.536, 0.85, 0.37, 8.0], [0.549, 0.846, 0.366, 8.0], [0.557, 0.838, 0.358, 8.0], [0.56, 0.826, 0.346, 8.0]]:
		rim_secs.append(_se_ring(r[1], r[2], r[3], o, to))
		rim_ys.append(r[0])
	for r in [[0.56, 0.757, 0.287, 5.0], [0.558, 0.749, 0.28, 4.8]]:
		rim_secs.append(_se_ring(r[1], r[2], r[3], c, ti))
		rim_ys.append(r[0])
	var rim := loft_mesh(rim_secs, rim_ys, false)
	rim = _tinted(rim, TINT_RIM)
	var bowl := _loft([[0.558, 0.749, 0.28, 4.8, c.x, c.y], [0.549, 0.74, 0.272, 4.6, c.x, c.y], [0.53, 0.725, 0.259, 4.4, c.x, c.y],
		[0.5, 0.707, 0.247, 4.2, c.x, c.y], [0.48, 0.695, 0.24, 4.0, c.x, c.y], [0.466, 0.688, 0.236, 3.9, c.x, c.y],
		[0.457, 0.682, 0.233, 3.85, c.x, c.y], [0.449, 0.677, 0.23, 3.8, c.x, c.y], [0.4, 0.652, 0.216, 3.6, c.x, c.y]], ti, false, true)
	bowl = _tinted(bowl, TINT_BOWL)
	var wd := _se_disc(0.69, 0.236, 3.8, _se_params(0.69, 0.236, 3.8, 48))
	return [apron, rim, bowl, wd]


## Les maillages du WC (repère de props["toilet"], avant vers +z, réservoir contre le mur en z −0,32) :
## [céramique (pied et cuvette), intérieur de la cuvette, eau, lunette, abattant, réservoir, couvercle,
## talon sous le réservoir]. Monobloc des années 80 : pied en 7 sections, cuvette à rebord roulé, eau au
## fond (cerne de calcaire au-dessus), lunette et abattant en plastique, réservoir arrondi.
static func _build_wc_meshes() -> Array:
	var tp := _se_params(0.18, 0.236, 2.4, WC_SEG)
	var outer := _loft([[0.0, 0.106, 0.152, 2.6, 0.0, 0.03], [0.012, 0.11, 0.156, 2.6, 0.0, 0.03], [0.03, 0.1, 0.145, 2.6, 0.0, 0.032],
		[0.17, 0.082, 0.115, 2.5, 0.0, 0.04], [0.27, 0.105, 0.15, 2.4, 0.0, 0.06], [0.33, 0.15, 0.2, 2.3, 0.0, 0.075],
		[0.375, 0.175, 0.228, 2.2, 0.0, 0.08], [0.395, 0.181, 0.236, 2.2, 0.0, 0.08], [0.405, 0.178, 0.232, 2.2, 0.0, 0.08],
		[0.41, 0.168, 0.222, 2.2, 0.0, 0.08], [0.41, 0.158, 0.208, 2.2, 0.0, 0.08]], tp)
	outer = _tinted(outer, TINT_WC)
	var inner := _loft([[0.41, 0.158, 0.208, 2.2, 0.0, 0.08], [0.4, 0.15, 0.198, 2.2, 0.0, 0.08], [0.36, 0.13, 0.172, 2.2, 0.0, 0.07],
		[0.3, 0.1, 0.13, 2.1, 0.0, 0.05], [0.27, 0.083, 0.104, 2.05, 0.0, 0.035], [0.25, 0.07, 0.085, 2.0, 0.0, 0.02],
		[0.22, 0.05, 0.055, 2.0, 0.0, 0.0]], tp, false, true)
	inner = _tinted(inner, TINT_WC_IN)
	var water := _se_disc(0.082, 0.1, 2.0, tp)
	# lunette : un anneau au profil arrondi (anneaux d'un tore aplati ; l'anneau du milieu est à l'extérieur)
	var so := [0.172, 0.226, 2.2]
	var si := [0.112, 0.152, 2.0]
	var cz := 0.085
	var seat_rings := []
	var prof := [[0.0, 0.414], [0.0, 0.425], [0.006, 0.4315], [0.5, 0.434], [0.994, 0.4315], [1.0, 0.424], [1.0, 0.416],
		[0.996, 0.4115], [0.5, 0.411], [0.004, 0.4115], [0.0, 0.414]]
	var seat_secs := []
	var seat_ys := PackedFloat32Array()
	var ring_i := _se_ring(si[0], si[1], si[2], Vector2(0.0, cz), tp)
	var ring_o := _se_ring(so[0], so[1], so[2], Vector2(0.0, cz), tp)
	for pr in prof:
		var sec := PackedVector2Array()
		sec.resize(tp.size())
		for k in tp.size():
			sec[k] = ring_i[k].lerp(ring_o[k], pr[0])
		seat_secs.append(sec)
		seat_ys.append(pr[1])
	var seat := loft_mesh(seat_secs, seat_ys, false)
	# abattant (relevé par la pièce) : plaque de 18 mm aux bords arrondis, centrée sur l'origine
	var lid := _loft([[-0.009, 0.169, 0.222, 2.2, 0.0, 0.0], [-0.006, 0.174, 0.227, 2.2, 0.0, 0.0], [0.006, 0.174, 0.227, 2.2, 0.0, 0.0],
		[0.009, 0.169, 0.222, 2.2, 0.0, 0.0]], tp, true)
	var tank := rounded_box_mesh(Vector3(0.38, 0.33, 0.165), 0.02, 4)
	var tank_lid := rounded_box_mesh(Vector3(0.392, 0.026, 0.177), 0.008, 2)
	var heel := rounded_box_mesh(Vector3(0.22, 0.05, 0.13), 0.015, 2)
	return [outer, inner, water, seat, lid, tank, tank_lid, heel]


# ------------------------------------------------------------------ la baignoire et l'eau noire

func _bathtub() -> void:
	var tub := prop("bathtub", TUB_POS, 0.0, Vector3(1.7, 0.56, 0.74), true)
	# la baignoire modelée (le Kenney est caché ; sa boîte et sa collision restent)
	_hide_meshes(tub)
	_await_meshes()
	_mesh(_tub_meshes[0], Vector3.ZERO, _apron, Vector3.ZERO, tub).name = "Tablier"
	_mesh(_tub_meshes[1], Vector3.ZERO, _enamel_v, Vector3.ZERO, tub).name = "Rebord"
	_mesh(_tub_meshes[2], Vector3.ZERO, _enamel_v, Vector3.ZERO, tub).name = "Cuve"
	# l'eau : noire, immobile, un peu grasse ; la lampe s'y reflète. Vraie carte : une encre qui reflète
	# (couche LAYER_EAU : SSR et éclairage indirect, pas la sonde figée) ; rendu logiciel : la matière d'avant
	var full := not Builder.soft_render()
	var wm: Material
	if full:
		wm = _water_material()
	else:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.008, 0.011, 0.01)
		sm.roughness = 0.05
		sm.metallic_specular = 0.95
		sm.normal_enabled = true
		var nt := NoiseTexture2D.new()
		nt.width = 128
		nt.height = 128
		nt.seamless = true
		nt.as_normal_map = true
		nt.bump_strength = 2.0
		var fn := FastNoiseLite.new()
		fn.seed = 12
		fn.frequency = 0.03
		nt.noise = fn
		sm.normal_texture = nt
		sm.normal_scale = 0.25
		sm.uv1_scale = Vector3(2.0, 1.0, 1.0)
		wm = sm
	water = _no_gi(_mesh(_tub_meshes[3], WATER_CENTER, wm)) as MeshInstance3D
	water.name = "EauNoire"
	if full:
		water.layers = Builder.layer_bit(LAYER_EAU)
	# robinetterie murale au bout des robinets (côté est), douchette sur son crochet
	var tx := 7.22
	var wall := ZN + TILE
	_box(Vector3(0.24, 0.05, 0.04), Vector3(tx, 0.74, wall + 0.02), _chrome)
	for s in [-1.0, 1.0]:
		_mesh(_cyl(0.022, 0.026, 0.035, 12), Vector3(tx + s * 0.1, 0.785, wall + 0.03), _chrome)
		_mesh(_cyl(0.02, 0.02, 0.008, 12), Vector3(tx + s * 0.1, 0.805, wall + 0.03), _plain(Color(0.7, 0.12, 0.1) if s < 0 else Color(0.15, 0.3, 0.7), 0.4))
	_rod(Vector3(tx, 0.72, wall + 0.03), Vector3(tx, 0.68, wall + 0.14), 0.011, _chrome)
	_mesh(_cyl(0.013, 0.009, 0.03, 10), Vector3(tx, 0.665, wall + 0.14), _chrome)
	# la douchette pend à son crochet, la tête vers la baignoire ; le flexible annelé part du mitigeur,
	# passe le rebord, plonge dans l'eau noire et remonte jusqu'à elle
	var hx := tx - 0.36
	var hand := Node3D.new()
	hand.name = "Douchette"
	add_child(hand)
	hand.position = Vector3(hx, 1.43, wall + 0.05)
	hand.rotation.x = 0.42
	var handle := lathe_mesh(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0105, 0.0), Vector2(0.011, 0.012),
		Vector2(0.0125, 0.1), Vector2(0.016, 0.135), Vector2(0.028, 0.15), Vector2(0.037, 0.158), Vector2(0.039, 0.168),
		Vector2(0.036, 0.176), Vector2(0.0, 0.177)]), 20)
	_mesh(handle, Vector3.ZERO, _chrome, Vector3.ZERO, hand)
	_mesh(_cyl(0.032, 0.032, 0.002, 20), Vector3(0, 0.1772, 0), _plain(Color(0.22, 0.23, 0.23), 0.5), Vector3.ZERO, hand)
	_mesh(rounded_box_mesh(Vector3(0.032, 0.05, 0.026), 0.006, 2), Vector3(hx, 1.535, wall + 0.013), _chrome)
	_rod(Vector3(hx, 1.52, wall + 0.02), Vector3(hx, 1.535, wall + 0.045), 0.008, _chrome)
	var hose_pts := PackedVector3Array([Vector3(tx - 0.12, 0.735, wall + 0.035), Vector3(tx - 0.13, 0.69, wall + 0.06),
		Vector3(tx - 0.14, 0.59, wall + 0.1), Vector3(tx - 0.16, 0.52, wall + 0.15), Vector3(tx - 0.2, 0.41, wall + 0.19),
		Vector3(tx - 0.27, 0.38, wall + 0.2), Vector3(tx - 0.33, 0.47, wall + 0.17), Vector3(tx - 0.355, 0.8, wall + 0.1),
		Vector3(hx - 0.004, 1.15, wall + 0.07), hand.position + Vector3(0, -0.012, -0.005)])
	var hose := _mesh(_tube(_smooth_path(hose_pts, 4), 0.0065, 8), Vector3.ZERO, _hose_mat())
	hose.name = "Flexible"
	hose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# porte-savon, savon fendillé, à l'autre bout
	_box(Vector3(0.14, 0.012, 0.09), Vector3(5.98, 0.9, wall + 0.045), _chrome)
	_box(Vector3(0.08, 0.025, 0.05), Vector3(5.98, 0.918, wall + 0.045), _m(Color(0.75, 0.66, 0.5), 0.6))
	# barre d'appui le long de la baignoire
	_rod(Vector3(6.2, 1.0, wall + 0.07), Vector3(6.8, 1.0, wall + 0.07), 0.016, _new_white)
	for x in [6.2, 6.8]:
		_rod(Vector3(x, 1.0, wall), Vector3(x, 1.0, wall + 0.07), 0.014, _new_white)
	_look("Regarder la baignoire", Vector3(1.5, 0.3, 0.6), Vector3(TUB_POS.x, 0.5, TUB_POS.z),
		"Pleine. L'eau est noire. Tu ne vois pas le fond.", "baignoire")


## Flexible de douche : chrome annelé (carte de normales en spirale, vraie carte) ; aplat avant.
func _hose_mat() -> StandardMaterial3D:
	if Builder.soft_render():
		return _plain(Color(0.6, 0.6, 0.62), 0.3, 0.6)
	var m := _plain(Color(0.72, 0.72, 0.74), 0.26, 0.85)
	m.normal_enabled = true
	m.normal_texture = _ridges()
	m.normal_scale = 0.9
	m.uv1_scale = Vector3(1.0 / 0.0045, 1.0, 1.0)
	return m


## L'eau noire sur vraie carte : une encre (albédo presque nul) au spéculaire d'eau, rugosité 0,03, deux
## couches de bruit qui glissent très lentement (un film gras qui bouge à peine) ; ses reflets viennent du
## SSR et de l'éclairage indirect. La normale est posée dans le repère du monde (pas de tangentes).
const WATER_SHADER_CODE := """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 albedo : source_color = vec3(0.006, 0.008, 0.007);
uniform float rough = 0.03;
uniform float spec = 0.62;
uniform float ripple = 0.07;
uniform float speed = 0.006;
uniform float scale = 1.3;
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;
void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz * scale;
	vec2 a = texture(ripples, p + vec2(TIME * speed, TIME * speed * 0.6)).xy * 2.0 - 1.0;
	vec2 b = texture(ripples, p * 1.73 + vec2(0.37 - TIME * speed * 0.8, TIME * speed * 0.9)).xy * 2.0 - 1.0;
	vec2 d = (a + b * 0.6) * ripple;
	vec3 n = normalize(vec3(d.x, 1.0, d.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = 0.0;
}
"""


func _water_material() -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = WATER_SHADER_CODE
	if _ripple_tex == null:
		_ripple_tex = _noise_normal(12, 0.012, 1.5)
	var m := ShaderMaterial.new()
	m.shader = _water_shader
	m.set_shader_parameter("albedo", WATER_ALBEDO)
	m.set_shader_parameter("rough", WATER_ROUGH)
	m.set_shader_parameter("spec", WATER_SPEC)
	m.set_shader_parameter("ripple", WATER_RIPPLE)
	m.set_shader_parameter("speed", WATER_SPEED)
	m.set_shader_parameter("ripples", _ripple_tex)
	return m


# ------------------------------------------------------------------ les rideaux (réel et « flux »)

## Rideau de douche sur vraie carte : vinyle vert d'eau fin (albédo ≈ 0,45 : il brûlait en bas sous
## l'applique et volait la scène à la baignoire), un peu translucide (la lumière d'en face passe),
## satiné, froissé, piqué de moisissure sur les 15 cm du bas.
const CURTAIN_NET := Color(0.38, 0.44, 0.41)
const CURTAIN_H := 1.9


func _curtain_mat(seed := 0.0) -> ShaderMaterial:
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/curtain.gdshader")
	var full := not Builder.soft_render()
	cm.set_shader_parameter("color", CURTAIN_NET if full else Color(0.52, 0.58, 0.55))
	cm.set_shader_parameter("sway", 0.008)
	cm.set_shader_parameter("seed", seed)
	cm.set_shader_parameter("height_m", CURTAIN_H)
	cm.set_shader_parameter("fold_period", 0.13)
	cm.set_shader_parameter("fold_depth", 0.022)
	cm.set_shader_parameter("bottom_gain", 1.3)
	cm.set_shader_parameter("push", 0.65)
	if full:
		if _crinkle_tex == null:
			_crinkle_tex = _noise_normal(31, 0.035, 2.5)
		cm.set_shader_parameter("roughness_v", 0.38)
		cm.set_shader_parameter("spec", 0.45)
		cm.set_shader_parameter("backlight_k", 0.32)
		cm.set_shader_parameter("cavity", 0.3)
		cm.set_shader_parameter("mold", 1.0)
		cm.set_shader_parameter("crinkle", 0.22)
		cm.set_shader_parameter("crinkle_tex", _crinkle_tex)
		cm.set_shader_parameter("crinkle_scale", Vector2(3.5, 4.0))
	return cm


## Rideau en plastique (plan plissé du shader « curtain ») et ses anneaux, de x0 à x1, le long de z = −6.5.
## width_model : largeur du plan avant mise à l'échelle (le rideau replié garde tous ses plis).
## Anneaux : un peu décalés et de travers (hachage de leur rang, aucun tirage aléatoire).
func _curtain(node_name: String, x0: float, x1: float, width_model: float, seed := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = Vector2(width_model, CURTAIN_H)
	pm.subdivide_width = 48 if Builder.soft_render() else 110
	pm.subdivide_depth = 8 if Builder.soft_render() else 14
	var mi := MeshInstance3D.new()
	mi.name = "Toile"
	mi.mesh = pm
	mi.material_override = _curtain_mat(seed)
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.position = Vector3((x0 + x1) / 2.0, 1.25, CURTAIN_Z)
	mi.scale = Vector3((x1 - x0) / width_model, 1.0, 1.0)
	holder.add_child(mi)
	# anneaux sur la tringle
	var n := int(width_model / 0.12) + 1
	for i in n:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.01
		tm.outer_radius = 0.0135
		tm.rings = 10
		tm.ring_segments = 6
		var x := lerpf(x0 + 0.02, x1 - 0.02, float(i) / maxf(1.0, n - 1))
		var j1 := sin(i * 12.9898 + seed * 78.233) * 43758.5453
		j1 -= floorf(j1)
		var j2 := sin(i * 39.3467 + seed * 11.135) * 24634.6345
		j2 -= floorf(j2)
		x += (j1 - 0.5) * 0.016 * (x1 - x0) / width_model
		var r := _mesh(tm, Vector3(x, 2.215, CURTAIN_Z), _chrome, Vector3((j2 - 0.5) * 0.5, (j1 - 0.5) * 0.35, PI / 2.0), holder)
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder


func _curtains() -> void:
	# tringle en U, fixée au pignon, et sa tige de plafond
	var y := 2.225
	var z := CURTAIN_Z
	var w := ZN + TILE
	_rod(Vector3(5.74, y, z), Vector3(7.46, y, z), 0.008, _chrome)
	_rod(Vector3(5.74, y, z), Vector3(5.74, y, w), 0.008, _chrome)
	_rod(Vector3(7.46, y, z), Vector3(7.46, y, w), 0.008, _chrome)
	for x in [5.74, 7.46]:
		_mesh(_sphere(0.011, 8), Vector3(x, y, z), _chrome)
		_mesh(_cyl(0.022, 0.022, 0.006, 12), Vector3(x, y, w + 0.003), _chrome, Vector3(PI / 2.0, 0, 0))
	_rod(Vector3(6.6, y, z), Vector3(6.6, 2.6, z), 0.006, _chrome)
	_mesh(_cyl(0.02, 0.02, 0.006, 12), Vector3(6.6, 2.597, z), _chrome)
	# le rideau réel, fermé (le miroir le passe en couche 12 pendant le P4)
	curtain_real = _curtain("RideauReel", 5.75, 7.45, 1.7, 0.0)
	# le même, replié contre le mur du fond : seule la caméra du miroir le verra (couche 11)
	curtain_feed = _curtain("RideauFlux", 7.2, 7.45, 1.7, 3.0)
	var cloth := curtain_feed.get_node("Toile") as MeshInstance3D
	cloth.scale.z = 1.6
	SmartMirror.feed_only(curtain_feed)
	curtain_feed.visible = false


# ------------------------------------------------------------------ le lavabo, la tablette

func _sink() -> void:
	var sink := prop("bathroomSink", Vector3(7.0, 0, -4.27), 180.0, Vector3(0.567, 0.933, 0.0), true)
	_lathe_sink(sink)
	# tablette en verre sous le miroir, consoles chromées
	var sy := 1.03
	var wall := ZS - TILE
	var glass := _plain(Color(0.55, 0.62, 0.6), 0.1)
	glass.metallic_specular = 0.9
	_box(Vector3(0.56, 0.008, 0.12), Vector3(7.0, sy, wall - 0.065), glass)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.012, 0.03, 0.11), Vector3(7.0 + s * 0.24, sy - 0.018, wall - 0.06), _chrome)
	var top := sy + 0.004
	# verre à dents, deux brosses (la sienne, la sienne à lui)
	var cup := _plain(Color(0.7, 0.78, 0.8), 0.15)
	_mesh(_cyl(0.028, 0.024, 0.09, 14), Vector3(6.82, top + 0.045, wall - 0.06), cup)
	for k in 2:
		var b := _box(Vector3(0.012, 0.16, 0.008), Vector3(6.815 + k * 0.012, top + 0.1, wall - 0.06 + k * 0.006),
			_plain([Color(0.2, 0.4, 0.7), Color(0.75, 0.25, 0.4)][k], 0.5))
		b.rotation = Vector3(0.15 - k * 0.3, 0, 0.12 - k * 0.24)
	# le pilulier de la semaine : L M M J V S D, deux compartiments déjà vides
	var pil := Node3D.new()
	pil.name = "Pilulier"
	add_child(pil)
	pil.position = Vector3(7.08, top, wall - 0.06)
	pil.rotation.y = 0.06
	_box(Vector3(0.17, 0.022, 0.05), Vector3(0, 0.011, 0), _plain(Color(0.85, 0.85, 0.82), 0.4), false, pil)
	var lids := [Color(0.85, 0.3, 0.3), Color(0.9, 0.6, 0.2), Color(0.9, 0.85, 0.3), Color(0.4, 0.75, 0.35),
		Color(0.3, 0.55, 0.85), Color(0.55, 0.4, 0.8), Color(0.85, 0.45, 0.65)]
	for i in 7:
		var lid := _box(Vector3(0.021, 0.004, 0.046), Vector3(-0.072 + i * 0.024, 0.024, 0), _plain(lids[i], 0.35), false, pil)
		if i >= 5:
			lid.rotation.x = -1.2
			lid.position += Vector3(0, 0.012, -0.022)
	# l'eau de Cologne, un peigne
	_mesh(_cyl(0.022, 0.024, 0.12, 12), Vector3(7.22, top + 0.06, wall - 0.05), _plain(Color(0.45, 0.6, 0.35), 0.15))
	_mesh(_cyl(0.012, 0.012, 0.02, 10), Vector3(7.22, top + 0.13, wall - 0.05), _chrome)
	var comb := _box(Vector3(0.14, 0.004, 0.025), Vector3(6.95, top + 0.002, wall - 0.1), _plain(Color(0.1, 0.1, 0.1), 0.4))
	comb.rotation.y = 0.3


# ------------------------------------------------------------------ le miroir connecté

func _mirror() -> void:
	mirror = SmartMirror.new()
	mirror.name = "Miroir"
	mirror.device_id = "miroir"
	mirror.room_id = "sdb"
	add_child(mirror)
	mirror.position = MIRROR_POS
	mirror.rotation.y = PI
	mirror.build()
	mirror.p4_path = P4_PATH.duplicate()
	mirror.p4_curtain_pos = Vector3(6.6, 2.2, CURTAIN_Z)
	# la sortie par P4 (house_data.gd), un pas dans le couloir : le joueur qui file vers elle pendant la
	# barre a fui (le point est au-delà du seuil : en le franchissant, il va toujours vers elle)
	for d in HouseData.F1_DOORS:
		if str(d.id) == "P4":
			mirror.p4_exit = Vector3(float(d.at) - 0.6, 0.0, float(d.c))
	var rr: Array = HouseData.F1_ROOMS["sdb"].rect
	mirror.p4_room_rect = Rect2(float(rr[0]), float(rr[2]), float(rr[1]) - float(rr[0]), float(rr[3]) - float(rr[2]))
	mirror.p4_event.connect(_on_p4_event)
	# son câble, neuf : monte jusque sous la corniche, file vers la porte et disparaît dans un trou
	# percé au plafond, avant la zone de la porte
	var z := ZS - 0.003
	_cable([Vector3(7.27, 1.9, z), Vector3(7.27, 2.46, z), Vector3(5.82, 2.46, z)], Vector3.FORWARD)
	_cable([Vector3(5.82, 2.46, z), Vector3(5.82, 2.46, ZS - 0.13), Vector3(5.82, 2.597, ZS - 0.13)], Vector3.DOWN, false)
	_no_gi(_mesh(_cyl(0.01, 0.01, 0.004, 10), Vector3(5.82, 2.5985, ZS - 0.13), mats.dark))
	mirror_it = _interactable("Examiner le miroir", Vector3(0.62, 0.82, 0.08), MIRROR_POS + Vector3(0, 0, -0.06), self, LAYER_INTERACT, 2.4)
	mirror_it.used.connect(func(_i: Interactable) -> void:
		if mirror.is_on:
			return
		_hint("Un miroir connecté. La téléassistance, pour détecter les chutes. Éteint.")
		_log("miroir"))


func _on_p4_event(step: String) -> void:
	match step:
		"debut":
			_p4_scale = true
			show_scale(SCALE_TEXT)
		"fin":
			_p4_scale = false
			show_scale(SCALE_TEXT, 3.0)
			_dim_after_p4(2.0)


## Après le P4 (vraie carte, hors rétro) : l'applique, si elle n'a pas éclaté, reste à APPLIQUE_APRES_P4
## (le miroir vient de la remettre à 100 % en 2 s : ce fondu-ci part d'où elle en est).
func _dim_after_p4(seconds: float) -> void:
	if applique and not applique.broken and Qualite.extras_on():
		applique.set_level(APPLIQUE_APRES_P4, seconds)


## Le P4 réel (acteurs déjà posés) : await sdb.run_p4() -> "fixe" | "retourne" | "fui".
func run_p4() -> String:
	if mirror == null:
		return ""
	mirror.p4_lamp = applique
	mirror.p4_curtain_real = curtain_real
	mirror.p4_curtain_feed = curtain_feed
	mirror.p4_silhouette = silhouette
	return await mirror.run_p4()


# ------------------------------------------------------------------ l'applique

## Applique sur vraie carte (rendu net) : énergie de la lumière et émission de l'abat-jour.
## (revues de la vague 2 : le mur au-dessus de l'applique et le cadre du miroir brûlaient, la nuit de la
## pièce n'avait plus de noir : énergie 0,28 → 0,16, abat-jour 0,25 → 0,14, lumière décollée du mur,
## reflet spéculaire adouci)
const APPLIQUE_ENERGY_NET := 0.12
const APPLIQUE_GLOW_NET := 0.12
## Décroissance de la lumière (exposant de la distance, 1,2 pour les autres ampoules) : le cadre du
## miroir et le mur sont à 20 cm de l'ampoule, la pièce à 2 m ; à 0,9, le cadre reçoit deux fois moins
## de lumière pour la même pièce.
const APPLIQUE_ATTEN_NET := 0.9
const APPLIQUE_LIGHT_Z_NET := -0.15
const APPLIQUE_SPECULAR_NET := 0.6
## Après l'épisode du miroir (vraie carte, hors rétro) : l'applique reste à 50 %, la baignoire derrière
## son rideau garde son noir.
const APPLIQUE_APRES_P4 := 0.5


func _applique() -> void:
	var lamp := prop("lampWall", Vector3(7.0, 1.94, ZS - 0.105), 180.0, Vector3(0.3, 0.0, 0.0), false)
	var shade := _plain(Color(0.92, 0.88, 0.76), 0.6)
	shade.emission_enabled = true
	shade.emission = Color(1.0, 0.78, 0.5)
	# vraie carte : abat-jour et ampoule baissés (avec le halo du rendu net, la faïence claire et le mur au-dessus
	# de l'applique brûlaient : revue DA de la vague 2) ; rendu logiciel : comme avant
	var full := not Builder.soft_render()
	var shade_glow := APPLIQUE_GLOW_NET if full else 0.5
	shade.emission_energy_multiplier = shade_glow
	_retint(lamp, {"lamp": shade, "metal": _chrome})
	for mi in lamp.find_children("*", "MeshInstance3D", true, false):
		_no_gi(mi as MeshInstance3D)
	applique = SmartBulb.new()
	applique.name = "Applique"
	applique.device_id = "applique"
	applique.room_id = "sdb"
	applique.display_name = "Applique"
	applique.energy = APPLIQUE_ENERGY_NET if full else 0.42
	applique.color = Color(1.0, 0.8, 0.58)
	applique.light_range = 5.0
	applique.bulb_radius = 0.026
	add_child(applique)
	applique.position = LAMP_POS
	applique.build()
	applique.add_glow_material(shade, shade_glow)
	# le culot de l'ampoule ne projette pas d'ombre en éventail sur le mur
	for mi in applique.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# la lueur part du milieu de la tulipe, pas du ras du mur : collée au plan du miroir (4 cm), elle
	# faisait de son cadre deux grandes ailes d'ombre sur la faïence ; la faïence claire renvoie de la
	# lumière partout, les ombres ne sont pas noires
	if applique.light:
		applique.light.position.z = APPLIQUE_LIGHT_Z_NET if full else -0.065
		applique.light.shadow_opacity = 0.8
		if full:
			applique.light.set_meta("taille", 0.04)      # ombres douces (PCSS, Ultra)
			applique.light.light_specular = APPLIQUE_SPECULAR_NET
			applique.light.omni_attenuation = APPLIQUE_ATTEN_NET
	mirror.p4_lamp = applique


## L'applique vacille (entrée dans la pièce, passage de l'entité).
func flicker(seconds := 1.0) -> void:
	if applique:
		applique.flicker(seconds)


# ------------------------------------------------------------------ l'armoire basse et le sèche-cheveux

func _cabinet() -> void:
	var cab := prop("bathroomCabinetDrawer", Vector3(7.85, 0, -4.25), 180.0, Vector3(0.6, 0.98, 0.42), false)
	# bois laqué crème, écaillé (la peinture des portes, PaintedWood009C), poignées chromées
	var lacquer := (mats.paint as StandardMaterial3D).duplicate() as StandardMaterial3D
	lacquer.albedo_color = Color(0.95, 0.93, 0.84)
	_retint(cab, {"wood": lacquer, "carpetwhite": lacquer, "metallight": _chrome})
	# une armoire basse, pas un second lavabo : on retire la vasque et le robinet du modèle
	_strip(cab, "bathroomCabinetDrawer", [0])
	var box := _aabb_of(cab, self)
	var top := box.end.y
	var mel := _melamine(cab, box)
	# dessus carrelé, de la faïence des murs, bordé d'une baguette
	_box(Vector3(0.62, 0.03, 0.43), Vector3(7.85, top + 0.015, -4.245), _faience)
	_box(Vector3(0.63, 0.036, 0.014), Vector3(7.85, top + 0.012, -4.467), mel)
	_collider(Vector3(0.6, top + 0.03, 0.42), Vector3(7.85, (top + 0.03) / 2.0, -4.25))
	top += 0.03
	# napperon, boîte de mouchoirs, brosse à cheveux (des cheveux gris)
	_box(Vector3(0.22, 0.003, 0.16), Vector3(7.98, top + 0.0015, -4.22), _fabric(Color(0.86, 0.83, 0.74), 0.08))
	_box(Vector3(0.12, 0.08, 0.12), Vector3(8.06, top + 0.043, -4.18), _m(Color(0.55, 0.62, 0.75), 0.6))
	_box(Vector3(0.03, 0.008, 0.02), Vector3(8.06, top + 0.087, -4.18), _plain(Color(0.92, 0.92, 0.9), 0.9))
	var brush := Node3D.new()
	brush.name = "Brosse"
	add_child(brush)
	brush.position = Vector3(7.64, top, -4.2)    # le manche s'arrête avant la faïence
	brush.rotation.y = -0.4
	_box(Vector3(0.07, 0.025, 0.1), Vector3(0, 0.0125, 0), _m(Color(0.3, 0.18, 0.12), 0.5), false, brush)
	_box(Vector3(0.025, 0.018, 0.12), Vector3(0, 0.01, 0.1), _m(Color(0.3, 0.18, 0.12), 0.5), false, brush)
	_box(Vector3(0.06, 0.012, 0.085), Vector3(0, 0.031, 0), _plain(Color(0.6, 0.6, 0.6), 0.9), false, brush)
	_build_dryer(Vector3(7.84, top, -4.3))


## Le meuble bas en mélaminé crème des années 80, à la place du Kenney (caché ; sa boîte, donc la hauteur
## du dessus, reste) : socle en retrait, caisson, trois tiroirs aux chants arrondis séparés par un jeu de
## 4 mm, poignées en barrette bronze. Rend la matière du mélaminé.
func _melamine(cab: Node3D, box: AABB) -> StandardMaterial3D:
	_hide_meshes(cab)
	var mel := _grimy(_plain(Color(0.85, 0.82, 0.72), 0.42), 1.4)
	mel.metallic_specular = 0.45
	var brass := _plain(Color(0.5, 0.38, 0.22), 0.38, 0.7)
	var w := box.size.x
	var d := box.size.z
	var cx := box.get_center().x
	var cz := box.get_center().z
	var zf := box.position.z          # la façade, côté pièce
	var top := box.end.y
	_box(Vector3(w - 0.03, 0.07, d - 0.06), Vector3(cx, 0.035, cz + 0.025), _plain(Color(0.06, 0.055, 0.05), 0.8))
	var ch := top - 0.07
	_mesh(rounded_box_mesh(Vector3(w, ch, d - 0.018), 0.003, 2), Vector3(cx, 0.07 + ch / 2.0, cz + 0.009), mel).name = "Caisson"
	var gap := 0.004
	var fh := (ch - gap * 4.0) / 3.0
	for i in 3:
		var y := 0.07 + gap + fh / 2.0 + i * (fh + gap)
		_mesh(rounded_box_mesh(Vector3(w - 0.008, fh, 0.018), 0.0025, 2), Vector3(cx, y, zf + 0.009), mel).name = "Tiroir%d" % (i + 1)
		var hy := y + fh * 0.22
		_rod(Vector3(cx - 0.055, hy, zf - 0.022), Vector3(cx + 0.055, hy, zf - 0.022), 0.0045, brass, self, 8)
		for sx in [-1.0, 1.0]:
			_rod(Vector3(cx + sx * 0.045, hy, zf + 0.001), Vector3(cx + sx * 0.045, hy, zf - 0.022), 0.0035, brass, self, 6)
	return mel


## Le Calor de Mamie, 1994 : couché sur le flanc, cordon enroulé, fiche posée à côté.
func _build_dryer(at: Vector3) -> void:
	dryer = Node3D.new()
	dryer.name = "SecheCheveux"
	add_child(dryer)
	dryer.position = at
	dryer.rotation.y = 0.35
	var ivory := _m(Color(0.84, 0.8, 0.72), 0.4)
	var plum := _m(Color(0.45, 0.12, 0.18), 0.4)
	var r := 0.037
	_mesh(_cyl(r, r, 0.2, 18), Vector3(0, r, 0), ivory, Vector3(0, 0, PI / 2.0), dryer)
	_mesh(_cyl(r * 0.92, r * 0.92, 0.012, 18), Vector3(-0.105, r, 0), _plain(Color(0.08, 0.08, 0.08), 0.6), Vector3(0, 0, PI / 2.0), dryer)
	for k in 4:
		_box(Vector3(0.002, r * 1.6, 0.002), Vector3(-0.112, r, -0.024 + k * 0.016), _plain(Color(0.2, 0.2, 0.2), 0.5), false, dryer)
	_mesh(_cyl(0.022, 0.031, 0.06, 16), Vector3(0.13, r, 0), plum, Vector3(0, 0, -PI / 2.0), dryer)
	_mesh(_cyl(0.017, 0.017, 0.005, 14), Vector3(0.162, r, 0), _plain(Color(0.05, 0.05, 0.05), 0.6), Vector3(0, 0, -PI / 2.0), dryer)
	# poignée (couchée, vers l'avant), gâchette prune, curseur deux vitesses
	var grip := _mesh(_cyl(0.017, 0.019, 0.13, 12), Vector3(-0.015, 0.02, 0.085), ivory, Vector3(PI / 2.0, 0, 0.25), dryer)
	grip.name = "Poignee"
	_box(Vector3(0.012, 0.016, 0.04), Vector3(0.008, 0.024, 0.06), plum, false, dryer)
	_box(Vector3(0.02, 0.006, 0.012), Vector3(-0.03, 0.038, 0.07), _plain(Color(0.25, 0.25, 0.25), 0.5), false, dryer)
	# cordon gris, enroulé en boucles lâches, fiche
	var cord := _plain(Color(0.35, 0.35, 0.36), 0.6)
	var pts: Array = []
	for k in 15:
		var a := k * 0.85
		pts.append(Vector3(-0.03 + cos(a) * 0.06 - k * 0.006, 0.006, 0.17 + sin(a) * 0.04))
	pts.push_front(Vector3(-0.035, 0.008, 0.15))
	for i in pts.size() - 1:
		_rod((pts[i] as Vector3), (pts[i + 1] as Vector3), 0.0035, cord, dryer, 6)
	var plug := _box(Vector3(0.04, 0.02, 0.03), Vector3(-0.16, 0.01, 0.2), _m(Color(0.15, 0.15, 0.15), 0.5), false, dryer)
	plug.rotation.y = 0.6
	dryer_it = _interactable("Prendre le sèche-cheveux", Vector3(0.36, 0.14, 0.3), at + Vector3(0, 0.06, 0.04), self, LAYER_INTERACT, 2.2)
	dryer_it.used.connect(func(_i: Interactable) -> void: take_dryer())


## Le joueur prend le sèche-cheveux (pièce de l'arme). Le scénario lance le P4 réel sur l'événement
## « seche_cheveux_pris ».
func take_dryer() -> void:
	if dryer == null or not dryer.visible:
		return
	var already := Game.has_item("seche_cheveux")
	_hide_dryer()
	if already:
		return
	Sfx.play_at("cloth", dryer.global_position, -14.0, 1.1)
	Game.add_item("seche_cheveux", "Sèche-cheveux de Mamie", "Un Calor de 1994. Le boîtier et la gâchette du croquis.", "arme")
	Game.set_flag("seche_cheveux_pris", true)
	_hint("Le Calor de Mamie, 1994. Le boîtier du croquis.")
	var hn := Haunt.of(get_tree())
	if hn:
		hn.story_event("seche_cheveux_pris", {"room": "sdb"})


func _hide_dryer() -> void:
	if dryer:
		dryer.visible = false
	if dryer_it:
		dryer_it.enabled = false
		dryer_it.collision_layer = 0


## Le lavabo sur colonne, tourné en émail (le Kenney octogonal est caché ; sa collision reste) : vasque
## ovale à rebord roulé, colonne en tulipe, bonde, mitigeur chromé à deux croisillons.
func _lathe_sink(sink: Node3D) -> void:
	var size: Vector3 = sink.get_meta("size")
	var c := sink.position
	var back := 1.0 if c.z + size.z / 2.0 > -4.1 else -1.0   # côté du mur (le dos de la vasque)
	var bz := c.z + back * 0.02
	var top := minf(size.y, 0.86)
	var rx := minf(size.x / 2.0, 0.285)
	var oz := minf((size.z / 2.0 - 0.01) / rx, 0.82)
	var basin := lathe_mesh(PackedVector2Array([Vector2(0.0, top - 0.17), Vector2(rx * 0.42, top - 0.17),
		Vector2(rx * 0.72, top - 0.13), Vector2(rx * 0.92, top - 0.07), Vector2(rx, top - 0.015), Vector2(rx * 0.985, top),
		Vector2(rx * 0.93, top + 0.004), Vector2(rx * 0.86, top - 0.006), Vector2(rx * 0.7, top - 0.06),
		Vector2(rx * 0.42, top - 0.1), Vector2(0.03, top - 0.11), Vector2(0.0, top - 0.11)]), 40, oz)
	_mesh(basin, Vector3(c.x, 0, bz), _enamel).name = "Vasque"
	var column := lathe_mesh(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.125, 0.025),
		Vector2(0.1, 0.06), Vector2(0.08, 0.2), Vector2(0.074, 0.4), Vector2(0.085, 0.56), Vector2(0.115, top - 0.19),
		Vector2(0.13, top - 0.16), Vector2(0.0, top - 0.16)]), 32, 0.85)
	_mesh(column, Vector3(c.x, 0, bz + back * 0.05), _enamel).name = "Colonne"
	# joint gris du carrelage autour du pied
	_mesh(_cyl(0.138, 0.138, 0.002, 32), Vector3(c.x, 0.001, bz + back * 0.05), _grimy(_plain(Color(0.2, 0.18, 0.15), 0.9), 1.0), Vector3.ZERO)
	# bonde, robinetterie
	_mesh(_cyl(0.018, 0.018, 0.004, 16), Vector3(c.x, top - 0.108, bz), _chrome)
	var tz := bz + back * (rx * oz - 0.035)
	_mesh(_cyl(0.016, 0.02, 0.05, 16), Vector3(c.x, top + 0.025, tz), _chrome)
	_rod(Vector3(c.x, top + 0.045, tz), Vector3(c.x, top + 0.04, tz - back * 0.11), 0.008, _chrome)
	_mesh(_cyl(0.009, 0.009, 0.012, 12), Vector3(c.x, top + 0.034, tz - back * 0.11), _chrome)
	for sx in [-1.0, 1.0]:
		var hx: float = c.x + sx * 0.075
		_mesh(_cyl(0.013, 0.015, 0.03, 12), Vector3(hx, top + 0.015, tz), _chrome)
		_rod(Vector3(hx - 0.022, top + 0.034, tz), Vector3(hx + 0.022, top + 0.034, tz), 0.004, _chrome)
		_rod(Vector3(hx, top + 0.034, tz - 0.022), Vector3(hx, top + 0.034, tz + 0.022), 0.004, _chrome)
		_mesh(_sphere_dot(), Vector3(hx, top + 0.036, tz), _plain(Color(0.2, 0.35, 0.75) if sx < 0.0 else Color(0.75, 0.15, 0.12), 0.3))
	_hide_meshes(sink)


func _sphere_dot() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.006
	m.height = 0.008
	m.radial_segments = 8
	m.rings = 4
	return m


# ------------------------------------------------------------------ les WC

func _toilet() -> void:
	var wc := prop("toilet", Vector3(8.85, 0, -4.55), -90.0, Vector3(0.38, 0.76, 0.64), true)
	# le WC modelé (le Kenney est caché ; sa boîte et sa collision restent)
	_hide_meshes(wc)
	_toilet_model(wc)
	# dérouleur chromé sur le mur sud (patte, bras, axe ouvert), rouleau entamé dont une feuille pend
	var wall := ZS - TILE
	var hy := 0.69
	_mesh(rounded_box_mesh(Vector3(0.05, 0.07, 0.012), 0.004, 2), Vector3(8.56, hy, wall - 0.006), _chrome)
	_rod(Vector3(8.56, hy, wall - 0.006), Vector3(8.56, hy, wall - 0.075), 0.0055, _chrome)
	_rod(Vector3(8.565, hy, wall - 0.075), Vector3(8.43, hy, wall - 0.075), 0.005, _chrome)
	_mesh(_sphere(0.0065, 8), Vector3(8.43, hy, wall - 0.075), _chrome)
	var paper := _m(Color(0.88, 0.87, 0.82), 0.95)
	var roll := lathe_mesh(PackedVector2Array([Vector2(0.021, -0.049), Vector2(0.052, -0.049), Vector2(0.054, -0.046),
		Vector2(0.054, 0.046), Vector2(0.052, 0.049), Vector2(0.021, 0.049)]), 24)
	var rc := Vector3(8.5, hy - 0.004, wall - 0.075)
	_mesh(roll, rc, paper, Vector3(0, 0, PI / 2.0)).name = "Rouleau"
	# le tube de carton, vu par les bouts
	var core := CylinderMesh.new()
	core.top_radius = 0.0212
	core.bottom_radius = 0.0212
	core.height = 0.099
	core.radial_segments = 16
	core.rings = 1
	core.cap_top = false
	core.cap_bottom = false
	var card := _plain(Color(0.5, 0.4, 0.28), 0.9)
	card.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(core, rc, card, Vector3(0, 0, PI / 2.0))
	var sheet := _box(Vector3(0.096, 0.13, 0.0012), rc + Vector3(0, -0.065, -0.055), paper)
	sheet.rotation.x = 0.06
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# barre d'appui, à côté de la cuvette (mur est)
	var ex := XE - TILE
	_rod(Vector3(ex - 0.06, 0.82, -4.92), Vector3(ex - 0.06, 0.82, -5.42), 0.016, _new_white)
	for z in [-4.92, -5.42]:
		_rod(Vector3(ex, 0.82, z), Vector3(ex - 0.06, 0.82, z), 0.014, _new_white)
		_mesh(_cyl(0.03, 0.03, 0.01, 12), Vector3(ex - 0.005, 0.82, z), _new_white, Vector3(0, 0, PI / 2.0))
	# la tirette d'alarme de la téléassistance : un cordon rouge sombre de 3 mm qui pend du plafond (à
	# peine courbé), une chaînette à billes, la poignée en triangle
	var cord := _plain(Color(0.42, 0.045, 0.035), 0.6)
	_mesh(_cyl(0.035, 0.035, 0.03, 14), Vector3(8.42, 2.585, -4.32), _new_white)
	var cord_pts := PackedVector3Array([Vector3(8.42, 2.57, -4.32), Vector3(8.421, 2.1, -4.3205), Vector3(8.4235, 1.6, -4.3215),
		Vector3(8.4245, 1.25, -4.3218), Vector3(8.424, 1.03, -4.3215)])
	_mesh(_tube(_smooth_path(cord_pts, 3), 0.0015, 6), Vector3.ZERO, cord).name = "Cordon"
	var bead := _plain(Color(0.62, 0.6, 0.56), 0.35, 0.8)
	for k in 6:
		var bm := _mesh(_sphere(0.0022, 6), Vector3(8.424, 1.025 - k * 0.0055, -4.3215), bead)
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tri := Node3D.new()
	tri.name = "Tirette"
	add_child(tri)
	tri.position = Vector3(8.42, 0.95, -4.32)
	tri.rotation.y = 0.4
	var red := _plain(Color(0.55, 0.06, 0.045), 0.45)
	_box(Vector3(0.09, 0.012, 0.01), Vector3(0, -0.035, 0), red, false, tri)
	for s in [-1.0, 1.0]:
		var side := _box(Vector3(0.012, 0.085, 0.01), Vector3(s * 0.023, 0.0, 0), red, false, tri)
		side.rotation.z = s * 0.5


## Le WC monobloc des années 80, sous son support Kenney (repère : avant vers +z, réservoir au mur) :
## céramique émaillée vert d'eau, lunette et abattant relevé en plastique crème, bouton poussoir,
## arrivée d'eau chromée et son robinet d'arrêt.
func _toilet_model(wc: Node3D) -> void:
	_await_meshes()
	_mesh(_wc_meshes[0], Vector3.ZERO, _enamel_v, Vector3.ZERO, wc).name = "Cuvette"
	_mesh(_wc_meshes[1], Vector3.ZERO, _enamel_v, Vector3.ZERO, wc).name = "CuvetteDedans"
	var wm := _plain(Color(0.13, 0.14, 0.12), 0.04)
	wm.metallic_specular = 0.55
	_no_gi(_mesh(_wc_meshes[2], Vector3(0, 0.262, 0.028), wm, Vector3.ZERO, wc))
	var plastic := _grimy(_plain(Color(0.84, 0.82, 0.74), 0.32), 1.2)
	_mesh(_wc_meshes[3], Vector3.ZERO, plastic, Vector3.ZERO, wc).name = "Lunette"
	# abattant relevé contre le réservoir (charnière à l'arrière de la lunette)
	var hinge := Vector3(0, 0.437, -0.135)
	var tilt := PI / 2.0 + 0.035
	var dir := Vector3(0, sin(tilt), cos(tilt))
	_mesh(_wc_meshes[4], hinge + dir * 0.228, plastic, Vector3(-tilt, 0, 0), wc).name = "Abattant"
	for sx in [-1.0, 1.0]:
		_mesh(_cyl(0.009, 0.009, 0.03, 12), Vector3(sx * 0.07, 0.43, -0.135), plastic, Vector3(0, 0, PI / 2.0), wc)
	_mesh(_wc_meshes[5], Vector3(0, 0.575, -0.2375), _enamel, Vector3.ZERO, wc).name = "Reservoir"
	_mesh(_wc_meshes[6], Vector3(0, 0.753, -0.2375), _enamel, Vector3.ZERO, wc)
	_mesh(_wc_meshes[7], Vector3(0, 0.385, -0.2), _enamel_v, Vector3.ZERO, wc)
	# bouton poussoir chromé (double touche)
	var btn := lathe_mesh(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.025, 0.004),
		Vector2(0.023, 0.008), Vector2(0.0, 0.009)]), 20)
	_mesh(btn, Vector3(0, 0.766, -0.24), _chrome, Vector3.ZERO, wc)
	_mesh(BoxMesh.new(), Vector3(0, 0.775, -0.24), mats.dark, Vector3.ZERO, wc).scale = Vector3(0.002, 0.002, 0.044)
	# arrivée d'eau : du mur au bas du réservoir, robinet d'arrêt à papillon
	var px := -0.13
	_rod(Vector3(px, 0.15, -0.316), Vector3(px, 0.15, -0.285), 0.0065, _chrome, wc)
	_mesh(_cyl(0.012, 0.012, 0.03, 12), Vector3(px, 0.15, -0.285), _chrome, Vector3(PI / 2.0, 0, 0), wc)
	_rod(Vector3(px, 0.15, -0.282), Vector3(px, 0.41, -0.282), 0.005, _chrome, wc)
	_box(Vector3(0.006, 0.03, 0.012), Vector3(px - 0.016, 0.15, -0.285), _plain(Color(0.6, 0.12, 0.1), 0.45), false, wc)


# ------------------------------------------------------------------ le sèche-serviettes connecté

func _towel_rail() -> void:
	towel_rail = Connected.new()
	towel_rail.name = "SecheServiettes"
	towel_rail.device_id = "seche_serviettes"
	towel_rail.room_id = "sdb"
	towel_rail.display_name = "Sèche-serviettes"
	add_child(towel_rail)
	towel_rail.position = Vector3(4.86, 0.9, -6.4)
	towel_rail.rotation.y = PI / 2.0      # face vers +x (la pièce) ; x local = −z du monde
	var tr := towel_rail
	var paint := _m(Color(0.86, 0.85, 0.8), 0.35, 0.1)
	var back := (XW + TILE) - 4.86       # face de la faïence en z local
	for s in [-1.0, 1.0]:
		_mesh(_cyl(0.016, 0.016, 1.02, 12), Vector3(s * 0.25, 0, 0.0), paint, Vector3.ZERO, tr)
		_mesh(_cyl(0.017, 0.017, 0.012, 12), Vector3(s * 0.25, 0.515, 0.0), paint, Vector3.ZERO, tr)
		_mesh(_cyl(0.017, 0.017, 0.012, 12), Vector3(s * 0.25, -0.515, 0.0), paint, Vector3.ZERO, tr)
		for y in [-0.35, 0.35]:
			_mesh(_cyl(0.008, 0.008, -back, 8), Vector3(s * 0.25, y, back / 2.0), _chrome, Vector3(PI / 2.0, 0, 0), tr)
	var by := -0.46
	while by <= 0.47:
		_mesh(_cyl(0.011, 0.011, 0.5, 8), Vector3(0, by, 0.0), paint, Vector3(0, 0, PI / 2.0), tr)
		by += 0.075 if by < 0.0 else 0.06
	# une serviette de bain bleu passé, pliée sur le barreau du haut, qui retombe devant
	var towel := _towel_mat
	var hem := _fabric(Color(0.4, 0.47, 0.53), 0.1)
	_mesh(_cyl(0.02, 0.02, 0.44, 12), Vector3(0.02, 0.435, 0.004), towel, Vector3(0, 0, PI / 2.0), tr)
	var front := _box(Vector3(0.44, 0.62, 0.016), Vector3(0.02, 0.13, 0.03), towel, false, tr)
	front.rotation.x = -0.03
	_box(Vector3(0.44, 0.03, 0.018), Vector3(0.02, -0.17, 0.034), hem, false, tr)
	_box(Vector3(0.44, 0.3, 0.012), Vector3(0.02, 0.29, -0.018), towel, false, tr)
	# un gant de toilette, plié sur le barreau du bas
	_box(Vector3(0.14, 0.18, 0.012), Vector3(-0.12, -0.38, 0.022), _fabric(Color(0.72, 0.6, 0.5)), false, tr)
	# le module connecté du fournisseur d'énergie, sous le radiateur : blanc, neuf, LED orange
	_box(Vector3(0.09, 0.13, 0.045), Vector3(-0.18, -0.6, back + 0.0225), _new_white, false, tr)
	_box(Vector3(0.05, 0.012, 0.002), Vector3(-0.18, -0.57, back + 0.046), _plain(Color(0.6, 0.6, 0.6), 0.5), false, tr)
	tr.make_led(Vector3(-0.155, -0.64, back + 0.047), 0.004, true, Color(1.0, 0.42, 0.06))
	tr.led_energy = 3.5
	tr.led(Color(1.0, 0.42, 0.06))
	_rod(Vector3(-0.18, -0.535, back + 0.02), Vector3(-0.2, -0.47, 0.0), 0.004, _cable_mat, tr, 6)
	tr.build()
	# son câble descend se brancher sur la prise, au ras de la plinthe
	var x := XW + TILE + 0.003
	_cable([Vector3(x, 0.235, -6.2), Vector3(x, 0.235, -6.02)], Vector3.RIGHT, false)
	_socket(Vector3(XW + TILE, 0.235, -5.98), Vector3.RIGHT)
	_look("Toucher le sèche-serviettes", Vector3(0.14, 1.1, 0.6), Vector3(4.88, 0.9, -6.4),
		"Brûlant. Il chauffe à fond. À 3 h du matin.", "seche_serviettes")


# ------------------------------------------------------------------ le pèse-personne connecté

func _scale() -> void:
	scale_dev = Connected.new()
	scale_dev.name = "PesePersonne"
	scale_dev.device_id = "balance"
	scale_dev.room_id = "sdb"
	scale_dev.display_name = "Pèse-personne"
	add_child(scale_dev)
	scale_dev.position = Vector3(6.0, 0.0, -5.7)
	scale_dev.rotation.y = -0.85    # l'afficheur vers la porte
	var sd := scale_dev
	_box(Vector3(0.3, 0.02, 0.3), Vector3(0, 0.01, 0), _m(Color(0.16, 0.16, 0.17), 0.45), false, sd)
	var glass := _plain(Color(0.025, 0.025, 0.03), 0.06)
	glass.metallic_specular = 1.0
	_box(Vector3(0.296, 0.005, 0.296), Vector3(0, 0.0225, 0), glass, false, sd)
	for p in [Vector2(-0.075, -0.08), Vector2(0.075, -0.08), Vector2(-0.075, 0.03), Vector2(0.075, 0.03)]:
		_box(Vector3(0.09, 0.0012, 0.07), Vector3(p.x, 0.0255, p.y), _plain(Color(0.55, 0.56, 0.58), 0.3, 0.6), false, sd)
	scale_mat = StandardMaterial3D.new()
	scale_mat.albedo_color = Color(0.01, 0.01, 0.012)
	scale_mat.roughness = 0.1
	scale_mat.emission_enabled = true
	scale_mat.emission = Color(0.75, 0.88, 1.0)
	scale_mat.emission_energy_multiplier = 0.0
	scale_mat.emission_texture = _seg7_texture(SCALE_TEXT)
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.11, 0.045)
	_no_gi(_mesh(pm, Vector3(0, 0.0258, 0.104), scale_mat, Vector3.ZERO, sd))
	sd.build()
	_look("Regarder le pèse-personne", Vector3(0.36, 0.1, 0.36), Vector3(6.0, 0.05, -5.7),
		"58,0. Personne dessus.", "balance").used.connect(func(_i: Interactable) -> void:
			if not _p4_scale:
				show_scale(SCALE_TEXT, 4.0))


## Afficheur à 7 segments (texte « 58,0 »), blanc sur noir.
func _seg7_texture(text: String) -> ImageTexture:
	var img := Image.create_empty(64, 26, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var segs := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc",
		"7": "abc", "8": "abcdefg", "9": "abfgcd", "-": "g"}
	var x := 6
	for ch in text:
		if ch == "," or ch == ".":
			img.fill_rect(Rect2i(x, 21, 3, 3), Color.WHITE)
			x += 6
			continue
		var on: String = segs.get(ch, "")
		for s in "abcdefg":
			var c := Color.WHITE if on.contains(s) else Color(0.05, 0.05, 0.05)
			var r := {"a": Rect2i(x + 2, 2, 8, 2), "b": Rect2i(x + 10, 4, 2, 8), "c": Rect2i(x + 10, 14, 2, 8),
				"d": Rect2i(x + 2, 22, 8, 2), "e": Rect2i(x, 14, 2, 8), "f": Rect2i(x, 4, 2, 8), "g": Rect2i(x + 2, 12, 8, 2)}
			img.fill_rect(r[s], c)
		x += 15
	return ImageTexture.create_from_image(img)


## Le pèse-personne s'allume sur « 58,0 » (seconds > 0 : s'éteint ensuite ; 0 : reste allumé).
func show_scale(text := SCALE_TEXT, seconds := 0.0) -> void:
	_scale_id += 1
	var my := _scale_id
	if text != scale_text:
		scale_text = text
		scale_mat.emission_texture = _seg7_texture(text)
	scale_mat.emission_energy_multiplier = 3.2
	Sfx.play_at("metalClick", scale_dev.global_position, -24.0, 2.6, 1.5)
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds, false).timeout
	if my == _scale_id and is_inside_tree():
		hide_scale()


func hide_scale() -> void:
	_scale_id += 1
	if scale_mat:
		scale_mat.emission_energy_multiplier = 0.0


func is_scale_on() -> bool:
	return scale_mat != null and scale_mat.emission_energy_multiplier > 0.01


# ------------------------------------------------------------------ panier à linge, tapis

func _wicker_texture() -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var over := ((x / 4) + (y / 4)) % 2 == 0
			var k := 0.5 + 0.5 * sin((y % 4) / 4.0 * PI) if over else 0.5 + 0.5 * sin((x % 4) / 4.0 * PI)
			var c := Color(0.5, 0.38, 0.24).lerp(Color(0.7, 0.58, 0.4), k * 0.7)
			img.set_pixel(x, y, c.darkened(rng.randf() * 0.12))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _basket() -> void:
	var at := Vector3(5.22, 0, -6.95)
	# panier à linge en osier tressé, à couvercle (Poly Haven wicker_basket_02, CC0, agrandi : le modèle
	# fait 21 cm de diamètre), le couvercle remis en place, de travers sur le linge
	var wb := _ph("wicker_basket_02", Vector3.ZERO, 0.0, 2.0)
	if wb:
		wb.name = "PanierLinge"
		var wlid := wb.get_node_or_null("wicker_basket_02_lid") as Node3D
		if wlid:
			# (repère du glTF : fond du panier à y = 0, bord à 0,200 ; couvercle : bas à −0,021 sous son origine)
			wlid.transform = Transform3D(Basis.from_euler(Vector3(0.07, 0.6, -0.05)), Vector3(0.006, 0.212, 0.004))
		wb.position = at
		wb.rotation.y = 0.4
		# une manche de chemise de nuit coincée sous le couvercle
		var sl := _box(Vector3(0.12, 0.07, 0.01), Vector3(at.x + 0.15, 0.38, at.z + 0.17), _fabric(Color(0.76, 0.7, 0.73), 0.12))
		sl.rotation = Vector3(0.25, 0.75, 0.1)
		_collider(Vector3(0.44, 0.5, 0.44), at + Vector3(0, 0.25, 0))
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = _wicker_texture()
	m.roughness = 0.95
	m.uv1_scale = Vector3(6.0, 4.0, 1.0)
	_mesh(_cyl(0.2, 0.17, 0.52, 20), at + Vector3(0, 0.26, 0), _grimy(m))
	var lid := _mesh(_cyl(0.205, 0.205, 0.03, 20), at + Vector3(0.0, 0.535, 0.0), _grimy(m.duplicate() as StandardMaterial3D))
	lid.rotation = Vector3(0.05, 0, -0.04)
	# une manche de chemise de nuit coincée sous le couvercle
	var sleeve := _box(Vector3(0.1, 0.08, 0.012), Vector3(at.x + 0.12, 0.49, at.z + 0.15), _m(Color(0.75, 0.7, 0.72), 1.0))
	sleeve.rotation.y = 0.7
	_collider(Vector3(0.4, 0.55, 0.4), at + Vector3(0, 0.275, 0))


func _rug() -> void:
	prop("rugRound", Vector3(6.6, 0.004, -5.95), 0.0, Vector3(0.9, 0.0, 0.9), false,
		{"carpet": Color(0.42, 0.5, 0.52), "carpetdarker": Color(0.34, 0.4, 0.42)})


# ------------------------------------------------------------------ la vie d'avant (objets du quotidien)

## Ce que Mamie a laissé : le tabouret au bout de la baignoire (sa serviette pliée, ses lunettes posées
## dessus), l'étagère du coin (serviettes, broc, papier toilette), la ventouse et la balayette des WC,
## l'eau de Javel, le déboucheur sous le lavabo, les flacons au bord de la baignoire.
## (Tout est hors du trajet de la silhouette, du rayon du sèche-cheveux et de la fuite vers P4.)
func _clutter() -> void:
	# --- le tabouret peint, au bout de la baignoire, côté robinets (dessus à 0,58 m)
	var stool := _ph("painted_wooden_stool", Vector3(7.8, 0, -6.98), 0.25)
	if stool:
		stool.name = "Tabouret"
		_collider(Vector3(0.4, 0.58, 0.4), Vector3(7.8, 0.29, -6.98))
		var t := _box(Vector3(0.3, 0.05, 0.22), Vector3(7.8, 0.605, -6.98), _fabric(Color(0.74, 0.58, 0.56)))
		t.rotation.y = 0.18
		var fold := _box(Vector3(0.3, 0.012, 0.05), Vector3(0.0, 0.019, 0.11), _fabric(Color(0.66, 0.5, 0.48)), false, t)
		fold.rotation.x = 0.3
		_glasses(Vector3(7.77, 0.631, -6.96), 4.9)
	# --- l'étagère peinte dans le coin nord-est (planches à 0,46 et 0,74 m, 21 cm de fond)
	var sx := 8.86
	var sz := ZN + TILE + 0.004
	var shelf := _ph("painted_wooden_shelves", Vector3(sx, 0, sz), 0.0)
	if shelf:
		shelf.name = "Etagere"
		_collider(Vector3(0.51, 1.12, 0.37), Vector3(sx, 0.56, sz + 0.185))
		# en haut : une pile de serviettes pliées, de couleurs passées
		var cols := [Color(0.52, 0.6, 0.66), Color(0.8, 0.76, 0.66), Color(0.7, 0.55, 0.55)]
		for i in 3:
			var tw := _box(Vector3(0.34, 0.05, 0.19), Vector3(sx - 0.02 + i * 0.008, 0.74 + 0.026 + i * 0.05, sz + 0.115),
				_towel_mat if i == 0 else _fabric(cols[i]))
			tw.rotation.y = (i - 1) * 0.04
		# en bas : le broc de faïence et deux rouleaux de papier
		var jug := _ph("jug_01", Vector3(sx - 0.08, 0.46, sz + 0.11), PI * 0.85)
		if jug:
			jug.name = "Broc"
		var paper := _m(Color(0.88, 0.87, 0.82), 0.95)
		for k in 2:
			_mesh(_cyl(0.055, 0.055, 0.1, 18), Vector3(sx + 0.13, 0.46 + 0.05 + k * 0.1, sz + 0.1), paper)
	# --- les WC : ventouse appuyée au mur, balayette dans son pot, l'eau de Javel
	var plunger := _ph("plunger", Vector3(9.02, 0, -4.98), 0.5)
	if plunger:
		plunger.name = "Ventouse"
		plunger.rotation.z = -0.17
	var bx := 9.03
	var bz := -4.17
	var pot := _plain(Color(0.78, 0.8, 0.76), 0.35)
	_mesh(_cyl(0.052, 0.045, 0.14, 18), Vector3(bx, 0.07, bz), pot)
	_mesh(_cyl(0.046, 0.046, 0.004, 18), Vector3(bx, 0.139, bz), _m(Color(0.25, 0.27, 0.25), 0.8))
	_rod(Vector3(bx, 0.1, bz), Vector3(bx - 0.03, 0.42, bz + 0.012), 0.008, pot, self, 8)
	_mesh(_sphere(0.011, 8), Vector3(bx - 0.03, 0.42, bz + 0.012), pot)
	var bleach := _ph("bleach_bottle", Vector3(8.9, 0, -4.12), -0.5)
	if bleach:
		bleach.name = "Javel"
	var drain := _ph("drain_cleaner", Vector3(6.68, 0, -4.13), 0.35)
	if drain:
		drain.name = "Deboucheur"
	# --- sur l'appui de la fenêtre dépolie (dessus à 1,298 m, x 9,03 → 9,26) : une plante qui aime l'humidité
	if ResourceLoader.exists(PH_PATH % ["potted_plant_04", "potted_plant_04"]):
		model("potted_plant_04", Vector3(9.15, 1.298, -5.52), 200.0, Vector3.ZERO, false, {"name": "PlanteFenetre"})
	# --- au bord de la baignoire, côté robinets : shampoing et bain moussant
	var rim := 0.56
	var b1 := _plain(Color(0.85, 0.7, 0.2), 0.3)
	_mesh(_cyl(0.026, 0.028, 0.17, 14), Vector3(7.36, rim + 0.085, -7.2), b1)
	_mesh(_cyl(0.016, 0.018, 0.02, 12), Vector3(7.36, rim + 0.18, -7.2), _plain(Color(0.9, 0.9, 0.88), 0.4))
	var b2 := _plain(Color(0.78, 0.45, 0.55), 0.25)
	_mesh(_cyl(0.034, 0.036, 0.13, 14), Vector3(7.3, rim + 0.065, -7.22), b2)
	_mesh(_cyl(0.02, 0.022, 0.025, 12), Vector3(7.3, rim + 0.142, -7.22), _plain(Color(0.92, 0.92, 0.9), 0.4))


## Les lunettes de Mamie, ouvertes, posées à plat (monture dorée fine, verres) : faites ici plutôt que
## le modèle Poly Haven round_spectacles (11 800 triangles, et un verre « transmission » dont la variante
## de shader coûtait ~0,2 s de construction en rendu logiciel).
func _glasses(at: Vector3, rot_y: float) -> void:
	var g := Node3D.new()
	g.name = "Lunettes"
	add_child(g)
	g.position = at
	g.rotation.y = rot_y
	var wire := _plain(Color(0.6, 0.48, 0.26), 0.3, 0.75)
	for sx in [-1.0, 1.0]:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.0205
		tm.outer_radius = 0.0235
		tm.rings = 16
		tm.ring_segments = 6
		_mesh(tm, Vector3(sx * 0.031, 0.0016, 0.0), wire, Vector3.ZERO, g)
		var lens := _mesh(_cyl(0.0208, 0.0208, 0.0016, 16), Vector3(sx * 0.031, 0.0016, 0.0), mats.glass, Vector3.ZERO, g)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# branche ouverte, vers l'arrière ; l'embout recourbé
		_rod(Vector3(sx * 0.054, 0.0016, -0.004), Vector3(sx * 0.058, 0.0016, -0.125), 0.0011, wire, g, 6)
		_rod(Vector3(sx * 0.058, 0.0016, -0.125), Vector3(sx * 0.055, 0.0016, -0.15), 0.0013, wire, g, 6)
	_rod(Vector3(-0.0085, 0.0028, 0.002), Vector3(0.0085, 0.0028, 0.002), 0.0012, wire, g, 6)


## La fenêtre dépolie (F4, mur est) : la nuit du jardin la blanchit à peine (un panneau émissif froid
## derrière le verre), et cette lueur glisse dans la pièce (projecteur doux, sans ombre).
func _window_glow() -> void:
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.0, 0.0, 0.0)
	gm.roughness = 1.0
	gm.emission_enabled = true
	gm.emission = Color(0.3, 0.37, 0.5)
	gm.emission_energy_multiplier = 0.16
	var q := _quad(Vector2(0.84, 0.84), Vector3(9.34, 1.7, -5.8), gm, -PI / 2.0)
	q.name = "LueurFenetre"
	_no_gi(q)
	var sp := SpotLight3D.new()
	sp.name = "LueurJardin"
	sp.light_color = Color(0.68, 0.75, 0.92)
	sp.light_energy = 0.22
	# (pas dans le brouillard volumétrique : le faisceau ne s'y voyait pas, et chaque lumière qui y entre
	# coûte à chaque image ; B12)
	sp.light_volumetric_fog_energy = 0.0
	sp.spot_range = 4.8
	sp.spot_angle = 58.0
	sp.spot_attenuation = 1.2
	sp.shadow_enabled = false
	add_child(sp)
	sp.position = Vector3(9.12, 1.75, -5.8)
	sp.look_at_from_position(sp.position, Vector3(6.6, 0.4, -6.1))
	if not Builder.soft_render():
		# vraie carte : la lueur tombe au sol devant la fenêtre, pas sur le rideau (la baignoire derrière
		# lui garde son noir ; seule la lampe du joueur l'éclaire)
		sp.light_energy = 0.14
		sp.look_at_from_position(sp.position, Vector3(7.9, 0.0, -5.5))


# ------------------------------------------------------------------ la silhouette du flux

func _silhouette() -> void:
	silhouette = mirror.make_silhouette(self)
	silhouette.name = "SilhouetteFlux"
	silhouette.global_position = P4_PATH[0]
	mirror.p4_silhouette = silhouette
	mirror.p4_curtain_real = curtain_real
	mirror.p4_curtain_feed = curtain_feed


# ------------------------------------------------------------------ traces

func _traces() -> void:
	var stain: Texture2D = load("res://assets/decals/stain_water.png")
	var mold: Texture2D = load("res://assets/decals/mold.png")
	# moisissure noire dans l'angle de la baignoire, au plafond et sur les joints du pignon
	_decal(mold, Vector3(5.2, 2.3, ZN), Vector3.BACK, Vector3.UP, 1.0, 0.7, 0.2)
	_decal(mold, Vector3(5.4, 2.6, -7.1), Vector3.DOWN, Vector3.BACK, 1.0, 0.7, 0.3, Color(1, 1, 1, 0.8))
	_decal(mold, Vector3(7.4, 0.62, ZN + TILE), Vector3.BACK, Vector3.UP, 0.5, 0.18, 0.1, Color(1, 1, 1, 0.7))
	# des piqûres de moisissure dans l'ourlet du rideau
	_decal(mold, Vector3(6.6, 0.42, CURTAIN_Z), Vector3.BACK, Vector3.UP, 1.6, 0.3, 0.08, Color(1, 1, 1, 0.75))
	# auréole au plafond au-dessus de la baignoire, coulure sous la fenêtre
	_decal(stain, Vector3(6.4, 2.6, -6.8), Vector3.DOWN, Vector3.BACK, 1.3, 1.0, 0.3, Color(1, 1, 1, 0.8))
	_decal(stain, Vector3(XE, 1.0, -5.8), Vector3.LEFT, Vector3.UP, 0.6, 0.8, 0.2, Color(1, 1, 1, 0.6))
	# eau au sol, devant la baignoire (le rideau goutte)
	_decal(stain, Vector3(6.9, 0.0, -6.38), Vector3.UP, Vector3.FORWARD, 0.6, 0.3, 0.1, Color(0.4, 0.4, 0.4, 0.5))
	# coulure de rouille sous le mitigeur de la baignoire, crasse au pied des WC, salpêtre dans l'angle
	# nord-est du plafond (au-dessus de l'étagère)
	_decal(stain, Vector3(7.22, 0.6, ZN + TILE), Vector3.BACK, Vector3.UP, 0.14, 0.3, 0.06, Color(0.75, 0.42, 0.2, 0.85))
	_decal(stain, Vector3(8.82, 0.0, -4.55), Vector3.UP, Vector3.FORWARD, 0.8, 0.62, 0.08, Color(0.3, 0.28, 0.22, 0.6))
	_decal(mold, Vector3(8.9, 2.6, -7.05), Vector3.DOWN, Vector3.BACK, 0.8, 0.55, 0.25, Color(1, 1, 1, 0.7))


# ------------------------------------------------------------------ reflets (lot V2-SDB)

## La sonde de la pièce (HouseRoom), sans l'eau noire (reflection_mask) : vraie carte seulement.
func prepare_reflections() -> void:
	super.prepare_reflections()
	if probe:
		probe.reflection_mask = probe.reflection_mask & ~Builder.layer_bit(LAYER_EAU)


## Intensité des reflets (HouseRoom.update_reflection), × SDB_PROBE_GAIN.
func update_reflection() -> void:
	if probe == null or not probe.visible:
		return
	var k := 0.0
	if active and _probe_sum > 0.0 and not reflections_muted:
		var cur := 0.0
		for e in _probe_lights:
			var l: Light3D = e[0]
			if is_instance_valid(l) and l.is_visible_in_tree():
				cur += l.light_energy
		k = clampf(cur / _probe_sum * PROBE_GAIN * SDB_PROBE_GAIN, 0.0, 3.0)
		if k < 0.02:
			k = 0.0
	if absf(k - probe.intensity) > 0.004 or (k == 0.0 and probe.intensity != 0.0):
		probe.intensity = k


# ------------------------------------------------------------------ habillage (dress_details, vraie carte)

## Appelé par Main après la mesure B16, sur vraie carte (R3) : petits objets Poly Haven, damier désaturé,
## usure de la pièce (Wear) à la place des décalques d'avant, joint de silicone jauni.
func dress_details() -> void:
	_detail_objects()
	_damier_local()
	_wear_room()


func _detail_objects() -> void:
	# les lunettes de Mamie (round_spectacles) à la place des lunettes en fil
	var g := detail("round_spectacles", Vector3(7.77, 0.631, -6.96), rad_to_deg(4.9))
	if g:
		var old := get_node_or_null("Lunettes") as Node3D
		if old:
			old.visible = false
	# le canard en plastique sur le rebord, à côté de l'eau noire ; la boîte à pharmacie en métal sur
	# l'étagère ; un flacon de nettoyant au pied du lavabo (hors du battant de P4)
	detail("rubber_duck_toy", Vector3(7.385, 0.56, -6.74), -105.0, Vector3(0, 0.085, 0))
	detail("medical_box", Vector3(8.86, 1.12, -7.08), 4.0, Vector3(0.3, 0, 0))
	detail("multi_cleaner_bottle", Vector3(7.28, 0.0, -4.12), 200.0)


## Le damier de la pièce, désaturé (copie locale de mats.carrelage : l'image d'albédo relue, désaturée de
## 15 %, une fois par lancement ; la lingerie garde l'autre).
func _damier_local() -> void:
	var src := mats.carrelage as StandardMaterial3D
	if src == null or src.albedo_texture == null:
		return
	if _damier_tex == null:
		var img := src.albedo_texture.get_image()
		if img == null or img.is_empty():
			return
		if img.is_compressed() and img.decompress() != OK:
			return
		img.clear_mipmaps()
		img.adjust_bcs(DAMIER_BRIGHT, 1.0, DAMIER_SAT)
		img.generate_mipmaps()
		_damier_tex = ImageTexture.create_from_image(img)
	var m := src.duplicate() as StandardMaterial3D
	m.resource_name = "DamierSdb"
	m.albedo_texture = _damier_tex
	for i in mini(int(get_meta("coque", 0)), get_child_count()):
		var mi := get_child(i) as MeshInstance3D
		if mi and mi.material_override == src:
			mi.material_override = m


## L'usure de la pièce (Wear : rien en Basse ni en rendu logiciel ; les décalques d'avant restent alors).
func _wear_room() -> void:
	if not Wear.deco_on():
		return
	for d in _old_traces:
		if is_instance_valid(d):
			(d as Decal).visible = false
	var north := ZN + 0.004
	# au-dessus de la baignoire : moisissure à la jonction du plafond, coulures sur la peinture, auréole et
	# colonie au plafond
	Wear.decal(self, "moisissure", Vector3(6.35, 2.46, north), Vector3.BACK, Vector3.UP, 1.9, 0.32, {"world": true, "variant": 0})
	Wear.decal(self, "coulure", Vector3(5.95, 1.95, north), Vector3.BACK, Vector3.UP, 0.55, 1.1, {"world": true, "variant": 0})
	Wear.decal(self, "coulure", Vector3(6.95, 1.88, north), Vector3.BACK, Vector3.UP, 0.4, 0.9, {"world": true, "variant": 2, "alpha": 0.8})
	Wear.decal(self, "tache_plafond", Vector3(6.4, 2.6, -6.85), Vector3.DOWN, Vector3.BACK, 1.3, 1.0, {"world": true, "variant": 3})
	Wear.decal(self, "moisissure", Vector3(5.25, 2.6, -7.05), Vector3.DOWN, Vector3.BACK, 0.9, 0.6, {"world": true, "variant": 1})
	# robinets : rouille et coulure sous le mitigeur, calcaire sur le rebord et au fond du lavabo
	Wear.decal(self, "rouille", Vector3(7.22, 0.74, north + 0.018), Vector3.BACK, Vector3.UP, 0.28, 0.08, {"world": true})
	Wear.decal(self, "coulure", Vector3(7.22, 0.64, north + 0.018), Vector3.BACK, Vector3.UP, 0.1, 0.16,
		{"world": true, "variant": 3, "color": Color(0.72, 0.42, 0.22)})
	Wear.decal(self, "cerne", Vector3(7.34, 0.56, -6.95), Vector3.UP, Vector3.FORWARD, 0.2, 0.3, {"world": true, "depth": 0.05})
	Wear.decal(self, "cerne", Vector3(7.0, 0.77, -4.29), Vector3.UP, Vector3.FORWARD, 0.3, 0.24, {"world": true, "depth": 0.15})
	# WC : calcaire dans la cuvette, crasse au pied
	Wear.decal(self, "cerne", Vector3(8.78, 0.3, -4.55), Vector3.UP, Vector3.LEFT, 0.2, 0.26, {"world": true, "depth": 0.12})
	Wear.decal(self, "salissure", Vector3(8.84, 0.0, -4.55), Vector3.UP, Vector3.LEFT, 0.42, 0.55, {"world": true, "depth": 0.06, "alpha": 0.7})
	# fenêtre dépolie : la peinture coule sous l'appui, une colonie dans l'angle haut
	Wear.decal(self, "coulure", Vector3(XE - 0.002, 1.0, -5.8), Vector3.LEFT, Vector3.UP, 0.7, 0.7, {"world": true, "variant": 1})
	Wear.decal(self, "moisissure", Vector3(XE - 0.002, 2.25, -6.3), Vector3.LEFT, Vector3.UP, 0.45, 0.45, {"world": true, "variant": 1})
	# sol : passage usé devant le lavabo, eau séchée devant la baignoire (le rideau goutte)
	Wear.decal(self, "chemin_usure", Vector3(7.0, 0.0, -4.85), Vector3.UP, Vector3.FORWARD, 0.65, 0.7,
		{"world": true, "color": Wear.PATH_TINT["carrelage"], "mix": Wear.PATH_MIX["carrelage"]})
	Wear.decal(self, "cerne", Vector3(6.75, 0.0, -6.3), Vector3.UP, Vector3.FORWARD, 0.7, 0.3, {"world": true, "depth": 0.06})
	# miroir : une traînée de chiffon dans le coin bas, hors du flux
	Wear.decal(self, "trainee", Vector3(6.82, 1.24, MIRROR_POS.z - 0.014), Vector3.FORWARD, Vector3.UP, 0.16, 0.12,
		{"world": true, "vitre": true, "depth": 0.02})
	# pied des murs (sauf derrière la baignoire, le WC, le meuble, le lavabo, le radiateur, l'étagère, le panier)
	Wear.wall_base(self, 0.22, {"gaps": [Rect2(5.7, -7.3, 1.8, 0.5), Rect2(8.5, -4.8, 0.7, 0.5), Rect2(7.5, -4.5, 0.7, 0.5),
		Rect2(6.8, -4.4, 0.4, 0.4), Rect2(4.8, -6.95, 0.15, 1.1), Rect2(8.5, -7.3, 0.7, 0.45), Rect2(4.95, -7.3, 0.55, 0.6)]})
	# le joint de silicone jauni et piqué de noir entre la baignoire et la faïence
	var sil := _grimy(_plain(Color(0.76, 0.7, 0.5), 0.45), 6.0)
	_rod(Vector3(5.76, 0.5615, ZN + TILE + 0.002), Vector3(7.44, 0.5615, ZN + TILE + 0.002), 0.0055, sil, self, 8).name = "Silicone"


# ------------------------------------------------------------------ vie de la pièce

func _process(delta: float) -> void:
	# l'interaction du miroir n'existe que miroir éteint
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.25
		if mirror_it and mirror:
			mirror_it.enabled = not mirror.is_on
	# le robinet de la baignoire goutte dans l'eau noire (coupé par le silence de l'entité)
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = rng.randf_range(5.5, 9.0)
		if active:
			Sfx.play_at("drip", Vector3(6.05, WATER_Y + 0.02, ZN + TILE + 0.14), -16.0, rng.randf_range(0.75, 0.9), 1.5, "Ambiance")


# ------------------------------------------------------------------ restauration (sauvegarde)

## Réapplique Game.flags après un chargement : sèche-cheveux pris, applique éclatée.
func restore() -> void:
	if Game.flag("seche_cheveux_pris") or Game.has_item("seche_cheveux"):
		_hide_dryer()
	if Game.flag("applique_eclatee") and applique and not applique.broken:
		applique.broken = true
		applique.set_powered(applique.powered)
		if applique.bulb_mesh:
			applique.bulb_mesh.scale = Vector3(0.55, 0.35, 0.55)
			applique.bulb_mesh.position.y = applique.bulb_radius * 0.55
		_static_shards()
	if mirror and mirror.is_on and not mirror.p4_running:
		mirror.power_off(0.0)
	if str(Game.choices.get("miroir_reel", "")) != "":
		_dim_after_p4(0.0)


## Éclats de verre déjà tombés (applique éclatée avant la sauvegarde) : dans le lavabo et au sol.
func _static_shards() -> void:
	if _shards_done:
		return
	_shards_done = true
	var glass := _plain(Color(0.82, 0.86, 0.9), 0.08)
	glass.metallic_specular = 1.0
	for i in 16:
		var p := Vector3(rng.randf_range(6.65, 7.35), 0.0, rng.randf_range(-4.75, -4.2))
		if i < 6:
			p = Vector3(rng.randf_range(6.85, 7.15), 0.79, rng.randf_range(-4.35, -4.18))
		var s := _box(Vector3(rng.randf_range(0.006, 0.02), 0.0015, rng.randf_range(0.005, 0.016)), p + Vector3(0, 0.001, 0), glass)
		s.rotation.y = rng.randf() * TAU
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
