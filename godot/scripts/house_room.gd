class_name HouseRoom
extends Builder
## Une pièce de la maison : son rectangle intérieur, sa hauteur, son éclairage indirect (VoxelGI) et
## ses voisines (les pièces qu'on peut voir depuis elle par une porte ou un escalier).
## Le manager de la maison n'allume que les lumières de la pièce où se trouve le joueur et de ses
## voisines : le reste de la maison ne coûte rien à l'affichage.

@export var room_id := ""
@export var title := ""          # nom affiché (« Couloir », « Chambre d'Henriette et Albert »…)
var rect := Rect2()              # intérieur : position = (x0, z0), size = (largeur x, profondeur z)
var y0 := 0.0                    # hauteur du sol
var h := 2.6
var neighbors: Array[HouseRoom] = []
var gi: VoxelGI
var active := true
var _lights: Array[Light3D] = []
## Sol de la pièce (bruits de pas) : "parquet", "moquette" ou "carrelage" (HouseData), et ses tapis.
var floor_kind := "parquet"
var rugs: Array[Rect2] = []      # tapis (x, z, largeur, profondeur) : les pas y sont étouffés
var _rugs_scanned := -1
var _rugs_auto: Array[Rect2] = []


func setup(id: String, r: Rect2, floor_y := 0.0, height := 2.6, name_shown := "") -> void:
	room_id = id
	rect = r
	y0 = floor_y
	h = height
	title = name_shown


func contains(p: Vector3, margin := 0.0) -> bool:
	return p.y >= y0 - 0.5 and p.y <= y0 + h + 0.5 \
		and p.x >= rect.position.x - margin and p.x <= rect.end.x + margin \
		and p.z >= rect.position.y - margin and p.z <= rect.end.y + margin


func center() -> Vector3:
	return Vector3(rect.get_center().x, y0 + h / 2.0, rect.get_center().y)


func link(other: HouseRoom) -> void:
	if not neighbors.has(other):
		neighbors.append(other)
	if not other.neighbors.has(self):
		other.neighbors.append(self)


## Éclairage indirect de la pièce (la lumière rebondit sur les murs). Cuit au chargement (~0,5 s).
func bake_gi(subdiv := VoxelGI.SUBDIV_64, energy := 1.5) -> void:
	gi = VoxelGI.new()
	gi.name = "GI"
	gi.subdiv = subdiv
	gi.size = Vector3(rect.size.x + 0.4, h + 0.4, rect.size.y + 0.4)
	gi.position = center() - global_position
	add_child(gi)
	var swapped := _bake_proxies_on()
	gi.bake()
	_bake_proxies_off(swapped)
	if gi.data:
		gi.data.interior = true
		gi.data.energy = energy
		gi.data.propagation = 0.8
		gi.data.use_two_bounces = true


## Cuisson VoxelGI : pour chaque matière, Godot relit sa texture d'albédo (copie depuis la carte
## graphique, décompression, conversion, réduction bicubique à 128 px), et recommence à chaque pièce. Les
## surfaces PBR (murs, sols, plafonds : 1 à 2k) coûtaient ainsi près d'une seconde au chargement. Pendant
## la cuisson, ces matières sont remplacées par une matière unie de leur couleur moyenne (la même pour
## l'éclairage indirect, dont les voxels font 5 à 10 cm) ; le rendu ne change pas.
## Les objets plus petits que BAKE_MIN_SIZE (m) ne sont pas cuits (ils restent éclairés par la GI).
const BAKE_MIN_SIZE := 0.12
static var _proxy_of := {}         # matière -> matière unie de cuisson
static var _avg_of := {}           # texture -> couleur moyenne


static func _avg_color(tex: Texture2D) -> Color:
	if _avg_of.has(tex):
		return _avg_of[tex]
	var c := Color(0.5, 0.5, 0.5)
	var img := tex.get_image()
	if img and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		if not img.has_mipmaps():
			img.resize(4, 4, Image.INTERPOLATE_BILINEAR)
		var last := img.get_mipmap_count()
		var w := maxi(img.get_width() >> last, 1)
		var hh := maxi(img.get_height() >> last, 1)
		var px := Image.create_from_data(w, hh, false, img.get_format(), img.get_data().slice(img.get_mipmap_offset(last)))
		c = px.get_pixel(0, 0)
		c.a = 1.0
	_avg_of[tex] = c
	return c


static func _bake_proxy(m: Material) -> Material:
	if _proxy_of.has(m):
		return _proxy_of[m]
	var out: Material = null
	var bm := m as BaseMaterial3D
	if bm and bm.albedo_texture and bm.albedo_texture.get_width() >= 512 \
			and bm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not bm.emission_enabled:
		var p := StandardMaterial3D.new()
		var a := _avg_color(bm.albedo_texture)
		p.albedo_color = Color(a.r * bm.albedo_color.r, a.g * bm.albedo_color.g, a.b * bm.albedo_color.b)
		out = p
	_proxy_of[m] = out
	return out


## Pose les matières de cuisson ; rend [[maillage, surface (-1 : material_override), matière d'avant]].
func _bake_proxies_on() -> Array:
	var swapped := []
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.gi_mode != GeometryInstance3D.GI_MODE_STATIC or not mi.is_visible_in_tree():
			continue
		var ext := (mi.global_transform.basis * mi.mesh.get_aabb().size).abs()
		if maxf(ext.x, maxf(ext.y, ext.z)) < BAKE_MIN_SIZE:
			# petit objet (livre, tasse, bibelot) : rien à faire rebondir à l'échelle des voxels ; il reçoit
			# quand même l'éclairage indirect
			swapped.append([mi, -2, null])
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			continue
		if mi.material_override:
			var po := _bake_proxy(mi.material_override)
			if po:
				swapped.append([mi, -1, mi.material_override])
				mi.material_override = po
			continue
		for i in mi.mesh.get_surface_count():
			var own := mi.get_surface_override_material(i)
			var m: Material = own if own else mi.mesh.surface_get_material(i)
			if m == null:
				continue
			var p := _bake_proxy(m)
			if p:
				swapped.append([mi, i, own])
				mi.set_surface_override_material(i, p)
	return swapped


func _bake_proxies_off(swapped: Array) -> void:
	for s in swapped:
		var mi := s[0] as MeshInstance3D
		if s[1] == -2:
			mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		elif s[1] < 0:
			mi.material_override = s[2]
		else:
			mi.set_surface_override_material(s[1], s[2])


func collect_lights() -> void:
	_lights.clear()
	for l in find_children("*", "Light3D", true, false):
		_lights.append(l as Light3D)


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	for l in _lights:
		if is_instance_valid(l) and not l.has_meta("always_on"):
			l.visible = on
	if gi:
		gi.visible = on and Game.high_quality


## Ajoute un tapis (rectangle au sol, repère du jeu : x, z, largeur en x, profondeur en z).
func add_rug(r: Rect2) -> void:
	rugs.append(r)


## Nature du sol au point p : "tapis" sur un tapis, sinon floor_kind. Les tapis Kenney (« rug… ») et les
## nœuds « Tapis… » posés par le script de la pièce sont reconnus tout seuls.
func floor_kind_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for r in rugs:
		if r.has_point(q):
			return "tapis"
	if _rugs_scanned != get_child_count():
		_scan_rugs()
	for r in _rugs_auto:
		if r.has_point(q):
			return "tapis"
	return floor_kind


func _scan_rugs() -> void:
	_rugs_scanned = get_child_count()
	_rugs_auto.clear()
	for c in get_children():
		var n := c as Node3D
		if n == null:
			continue
		var nm := String(n.name).to_lower()
		if not (nm.begins_with("rug") or nm.begins_with("tapis")):
			continue
		var box := _aabb_of(n, self)
		if box.size.x <= 0.0 or box.size.y > 0.08:
			continue   # pas un tapis à plat
		var g := global_transform * box.position
		_rugs_auto.append(Rect2(g.x, g.z, box.size.x, box.size.z))
