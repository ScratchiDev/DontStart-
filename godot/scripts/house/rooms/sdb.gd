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
var _chrome: StandardMaterial3D
var _new_white: StandardMaterial3D
var _cable_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _towel_mat: StandardMaterial3D


func furnish(h: House) -> void:
	house = h
	rng.seed = 4407
	# émail vert d'eau des années 80 : lisse et brillant (le reflet net de l'applique et de la lampe de
	# poche glisse dessus), avec la crasse des joints ; chrome un peu terni (pas de reflets du décor :
	# l'environnement n'en donne pas, il garde donc une part de diffus pour ne pas virer au noir)
	_enamel = _grimy(_plain(Color(0.66, 0.74, 0.69), 0.14), 0.7)
	_enamel.metallic_specular = 0.75
	_chrome = _plain(Color(0.78, 0.78, 0.8), 0.15, 0.65)
	_chrome.metallic_specular = 0.8
	_new_white = _plain(Color(0.74, 0.74, 0.72), 0.4)
	_cable_mat = _plain(Color(0.9, 0.9, 0.88), 0.4)
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


## Plan horizontal en forme de stade (eau d'une baignoire) : longueur en x, largeur en z, normale +y.
func _stadium(length: float, width: float, seg := 12) -> ArrayMesh:
	var r := width / 2.0
	var half := length / 2.0 - r
	var pts: Array[Vector2] = []
	for i in seg + 1:
		var a := -PI / 2.0 + PI * i / seg
		pts.append(Vector2(half + cos(a) * r, sin(a) * r))
	for i in seg + 1:
		var a := PI / 2.0 + PI * i / seg
		pts.append(Vector2(-half + cos(a) * r, sin(a) * r))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		for v in [Vector2.ZERO, p, q]:
			var w: Vector2 = v
			st.set_uv(Vector2(w.x / length + 0.5, w.y / width + 0.5))
			st.add_vertex(Vector3(w.x, 0, w.y))
	return st.commit()


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


## Lisse les facettes d'un sanitaire Kenney (normales plates, « low poly ») : chaque sommet prend la
## moyenne des normales des faces qui le touchent (même position) et font moins de « angle_deg » avec
## la sienne. Les arrondis (vasque octogonale, cuvette, angles de la baignoire) deviennent lisses, les
## arêtes vives (rebord, socle) restent nettes. Maillage propre à cette instance (le .glb n'est pas touché).
func _auto_smooth(holder: Node3D, angle_deg := 50.0) -> void:
	var cos_max := cos(deg_to_rad(angle_deg))
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var src := mi.mesh
		if src == null:
			continue
		var overrides := []
		for i in src.get_surface_count():
			overrides.append(mi.get_surface_override_material(i))
		var out := ArrayMesh.new()
		for s in src.get_surface_count():
			var arr := src.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if src.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES and norms.size() == verts.size():
				if idx.is_empty():
					idx.resize(verts.size())
					for i in verts.size():
						idx[i] = i
				# normale (pondérée par l'aire) de chaque face, et faces par position de sommet
				var faces := {}
				var fn := PackedVector3Array()
				fn.resize(idx.size() / 3)
				for t in idx.size() / 3:
					var a := verts[idx[t * 3]]
					var c := (verts[idx[t * 3 + 1]] - a).cross(verts[idx[t * 3 + 2]] - a)
					fn[t] = c if c.dot(norms[idx[t * 3]]) >= 0.0 else -c    # (orientée comme la facette)
					for k in 3:
						var key := Vector3i((verts[idx[t * 3 + k]] * 10000.0).round())
						if not faces.has(key):
							faces[key] = []
						(faces[key] as Array).append(t)
				var out_n := norms.duplicate()
				for v in verts.size():
					var own := norms[v].normalized()
					var sum := Vector3.ZERO
					for t in faces.get(Vector3i((verts[v] * 10000.0).round()), []):
						var f: Vector3 = fn[t]
						if f.length_squared() > 0.0 and f.normalized().dot(own) >= cos_max:
							sum += f
					if sum.length_squared() > 0.0:
						out_n[v] = sum.normalized()
				arr[Mesh.ARRAY_NORMAL] = out_n
				arr[Mesh.ARRAY_TANGENT] = null
			out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr)
			out.surface_set_material(s, src.surface_get_material(s))
		mi.mesh = out
		for i in overrides.size():
			mi.set_surface_override_material(i, overrides[i])


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


# ------------------------------------------------------------------ la baignoire et l'eau noire

func _bathtub() -> void:
	var tub := prop("bathtub", TUB_POS, 0.0, Vector3(1.7, 0.56, 0.74), true)
	_auto_smooth(tub)
	_retint(tub, {"metallight": _enamel, "carpetwhite": _grimy(_plain(Color(0.56, 0.63, 0.57), 0.25), 0.5),
		"metaldark": _chrome})
	# l'eau : noire, immobile, un peu grasse ; la lampe s'y reflète
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.008, 0.011, 0.01)
	wm.roughness = 0.05
	wm.metallic_specular = 0.95
	wm.normal_enabled = true
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
	wm.normal_texture = nt
	wm.normal_scale = 0.25
	wm.uv1_scale = Vector3(2.0, 1.0, 1.0)
	var water := _no_gi(_mesh(_stadium(1.34, 0.47, 14), WATER_CENTER, wm))
	water.name = "EauNoire"
	# robinetterie murale au bout des robinets (côté est), douchette sur son crochet
	var tx := 7.22
	var wall := ZN + TILE
	_box(Vector3(0.24, 0.05, 0.04), Vector3(tx, 0.74, wall + 0.02), _chrome)
	for s in [-1.0, 1.0]:
		_mesh(_cyl(0.022, 0.026, 0.035, 12), Vector3(tx + s * 0.1, 0.785, wall + 0.03), _chrome)
		_mesh(_cyl(0.02, 0.02, 0.008, 12), Vector3(tx + s * 0.1, 0.805, wall + 0.03), _plain(Color(0.7, 0.12, 0.1) if s < 0 else Color(0.15, 0.3, 0.7), 0.4))
	_rod(Vector3(tx, 0.72, wall + 0.03), Vector3(tx, 0.68, wall + 0.14), 0.011, _chrome)
	_mesh(_cyl(0.013, 0.009, 0.03, 10), Vector3(tx, 0.665, wall + 0.14), _chrome)
	# le flexible tombe dans l'eau, puis remonte au crochet
	var hose := _plain(Color(0.6, 0.6, 0.62), 0.3, 0.6)
	_rod(Vector3(tx - 0.12, 0.74, wall + 0.035), Vector3(tx - 0.22, WATER_Y - 0.01, wall + 0.16), 0.007, hose)
	_rod(Vector3(tx - 0.22, WATER_Y - 0.01, wall + 0.16), Vector3(tx - 0.36, 1.5, wall + 0.04), 0.007, hose)
	_box(Vector3(0.03, 0.04, 0.04), Vector3(tx - 0.36, 1.55, wall + 0.02), _chrome)
	var head := _mesh(_cyl(0.035, 0.028, 0.05, 14), Vector3(tx - 0.36, 1.62, wall + 0.05), _chrome, Vector3(-0.5, 0, 0))
	head.name = "Douchette"
	# porte-savon, savon fendillé, à l'autre bout
	_box(Vector3(0.14, 0.012, 0.09), Vector3(5.98, 0.9, wall + 0.045), _chrome)
	_box(Vector3(0.08, 0.025, 0.05), Vector3(5.98, 0.918, wall + 0.045), _m(Color(0.75, 0.66, 0.5), 0.6))
	# barre d'appui le long de la baignoire
	_rod(Vector3(6.2, 1.0, wall + 0.07), Vector3(6.8, 1.0, wall + 0.07), 0.016, _new_white)
	for x in [6.2, 6.8]:
		_rod(Vector3(x, 1.0, wall), Vector3(x, 1.0, wall + 0.07), 0.014, _new_white)
	_look("Regarder la baignoire", Vector3(1.5, 0.3, 0.6), Vector3(TUB_POS.x, 0.5, TUB_POS.z),
		"Pleine. L'eau est noire. Tu ne vois pas le fond.", "baignoire")


# ------------------------------------------------------------------ les rideaux (réel et « flux »)

const CURTAIN_NET := Color(0.44, 0.49, 0.47)


func _curtain_mat() -> ShaderMaterial:
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/curtain.gdshader")
	# (vraie carte : un peu plus sombre, il brûlait en bas sous le plafonnier et volait la scène à la baignoire)
	cm.set_shader_parameter("color", Color(0.52, 0.58, 0.55) if Builder.soft_render() else CURTAIN_NET)
	cm.set_shader_parameter("sway", 0.008)
	return cm


## Rideau en plastique (plan plissé du shader « curtain ») et ses anneaux, de x0 à x1, le long de z = −6.5.
## width_model : largeur du plan avant mise à l'échelle (le rideau replié garde tous ses plis).
func _curtain(node_name: String, x0: float, x1: float, width_model: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	pm.size = Vector2(width_model, 1.9)
	pm.subdivide_width = 48
	pm.subdivide_depth = 8
	var mi := MeshInstance3D.new()
	mi.name = "Toile"
	mi.mesh = pm
	mi.material_override = _curtain_mat()
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
		var r := _mesh(tm, Vector3(x, 2.215, CURTAIN_Z), _chrome, Vector3(0, 0, PI / 2.0), holder)
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
	curtain_real = _curtain("RideauReel", 5.75, 7.45, 1.7)
	# le même, replié contre le mur du fond : seule la caméra du miroir le verra (couche 11)
	curtain_feed = _curtain("RideauFlux", 7.2, 7.45, 1.7)
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
const APPLIQUE_ENERGY_NET := 0.28
const APPLIQUE_GLOW_NET := 0.25


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
		applique.light.position.z = -0.12 if full else -0.065
		applique.light.shadow_opacity = 0.8
		if full:
			applique.light.set_meta("taille", 0.04)      # ombres douces (PCSS, Ultra)
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
	# dessus carrelé, de la faïence des murs, bordé d'une baguette de bois laqué
	_box(Vector3(0.62, 0.03, 0.43), Vector3(7.85, top + 0.015, -4.245), mats.faience)
	_box(Vector3(0.63, 0.036, 0.014), Vector3(7.85, top + 0.012, -4.467), lacquer)
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
	_auto_smooth(wc)
	_retint(wc, {"carpetwhite": _enamel, "_defaultmat": _grimy(_plain(Color(0.64, 0.71, 0.65), 0.3), 0.6),
		"metallight": _chrome, "metaldark": mats.dark})
	# dérouleur et rouleau, sur le mur sud
	var wall := ZS - TILE
	_rod(Vector3(8.5, 0.66, wall), Vector3(8.5, 0.66, wall - 0.09), 0.006, _chrome)
	_rod(Vector3(8.44, 0.66, wall - 0.09), Vector3(8.56, 0.66, wall - 0.09), 0.006, _chrome)
	_mesh(_cyl(0.055, 0.055, 0.1, 18), Vector3(8.5, 0.66, wall - 0.09), _m(Color(0.88, 0.87, 0.82), 0.95), Vector3(0, 0, PI / 2.0))
	# barre d'appui, à côté de la cuvette (mur est)
	var ex := XE - TILE
	_rod(Vector3(ex - 0.06, 0.82, -4.92), Vector3(ex - 0.06, 0.82, -5.42), 0.016, _new_white)
	for z in [-4.92, -5.42]:
		_rod(Vector3(ex, 0.82, z), Vector3(ex - 0.06, 0.82, z), 0.014, _new_white)
		_mesh(_cyl(0.03, 0.03, 0.01, 12), Vector3(ex - 0.005, 0.82, z), _new_white, Vector3(0, 0, PI / 2.0))
	# la tirette d'alarme de la téléassistance : un cordon rouge qui pend du plafond
	var cord := _plain(Color(0.65, 0.06, 0.05), 0.6)
	_mesh(_cyl(0.035, 0.035, 0.03, 14), Vector3(8.42, 2.585, -4.32), _new_white)
	_rod(Vector3(8.42, 2.57, -4.32), Vector3(8.42, 1.02, -4.32), 0.0026, cord, self, 6)
	var tri := Node3D.new()
	tri.name = "Tirette"
	add_child(tri)
	tri.position = Vector3(8.42, 0.95, -4.32)
	tri.rotation.y = 0.4
	var red := _plain(Color(0.75, 0.08, 0.06), 0.45)
	_box(Vector3(0.09, 0.012, 0.01), Vector3(0, -0.035, 0), red, false, tri)
	for s in [-1.0, 1.0]:
		var side := _box(Vector3(0.012, 0.085, 0.01), Vector3(s * 0.023, 0.0, 0), red, false, tri)
		side.rotation.z = s * 0.5


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
