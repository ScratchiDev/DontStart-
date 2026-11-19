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
## Sonde de reflets « Reflets » (prepare_reflections ; vraie carte seulement, montrée dès Élevée).
var probe: ReflectionProbe
var _probe_lights: Array = []     # [[Light3D, énergie de base], …] : les lampes de la capture
var _probe_sum := 0.0             # somme de leurs énergies de base
var _probe_base := {}             # Light3D -> énergie de base, relevée à la construction


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
		gi.visible = on and Qualite.gi_on()
	# (la sonde de reflets reste montrée : la cacher puis la remontrer la ferait recapturer avec les lampes
	# du moment et la lampe de poche ; une pièce inactive a ses reflets à l'intensité 0, update_reflection)


## Objets de décor de la pièce (passe « triple A ») : appelé par Main après la mesure de B16, seulement
## avec une vraie carte graphique (Qualite.details_on()), jamais dans furnish(). Les scripts des pièces
## la redéfinissent et y posent leurs Builder.detail(…) ; ici, rien.
func dress_details() -> void:
	pass


# ------------------------------------------------------------------ reflets

## Délais d'une capture, en images (mesurés sur lavapipe : une sonde UPDATE_ONCE rend ses 6 faces dans
## les 2 images qui suivent son apparition, puis filtre ses niveaux de rugosité en moins de 10 images ;
## la suivante attend son tour).
const PROBE_FACE_FRAMES := 3
const PROBE_TOTAL_FRAMES := 12
## Énergie prise pour une lampe éteinte dont on ne connaît pas l'énergie d'allumage (méta
## « energie_base » absente), quand la pièce n'a aucune autre lampe connue.
const PROBE_DEFAULT_ENERGY := 0.5
## Gain des reflets figés. La capture ne voit que les lampes de la pièce (ni la lampe de service des
## aperçus, ni, semble-t-il, le rebond de la VoxelGI) : sur les aperçus en Ultra, les sondes assombrissent
## un peu le spéculaire (−1 à −5/255 en moyenne). À régler sur une vraie carte (lot V3-ETALONNAGE).
const PROBE_GAIN := 1.0


## Sonde de reflets de la pièce (vraie carte seulement ; Main l'appelle après la construction) : une
## ReflectionProbe « Reflets » à la taille de la pièce, projetée en boîte, intérieure, sans lumière
## ambiante (l'éclairage ambiant ne change pas), capturée UNE fois (UPDATE_ONCE), cachée jusqu'à sa
## capture (Main._capture_reflections, puis capture_reflection). Couches exclues : 11 (flux
## uniquement) et Qualite.LAYER_NO_PROBE (lampe de poche).
func prepare_reflections() -> void:
	if probe or Qualite.soft():
		return
	probe = ReflectionProbe.new()
	probe.name = "Reflets"
	probe.size = Vector3(rect.size.x + 0.3, h + 0.2, rect.size.y + 0.3)
	probe.position = center() - global_position
	# (point de capture à hauteur des yeux ; la projection en boîte corrige le reste)
	probe.origin_offset = Vector3(0.0, clampf(1.5 - h / 2.0, -h / 2.0 + 0.2, h / 2.0 - 0.2), 0.0)
	probe.box_projection = true
	probe.interior = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.blend_distance = 0.15
	probe.mesh_lod_threshold = 4.0
	probe.enable_shadows = true          # (une seule capture : les ombres ne coûtent qu'une fois)
	# (ni la couche 11, ni la lampe de poche, ni les mains du joueur : Viewmodel.LAYER)
	probe.cull_mask = 0xFFFFF & ~(Builder.layer_bit(LAYER_FEED_ONLY) | Builder.layer_bit(Qualite.LAYER_NO_PROBE) | Builder.layer_bit(Viewmodel.LAYER))
	probe.intensity = 0.0
	probe.visible = false
	add_child(probe)
	# (énergies de base relevées maintenant : toutes les pièces sont encore actives, rien n'a clignoté)
	for l in _lights:
		if is_instance_valid(l):
			_probe_base[l] = _base_energy(l)


## Énergie de base d'une lampe : méta « energie_base », sinon celle de son ampoule connectée (SmartBulb,
## même éteinte), sinon son énergie si elle est allumée ; 0 = elle ne compte pas (veilleuses
## infrarouges, lumières des seules caméras de flux…). -1 : éteinte, énergie d'allumage inconnue.
static func _base_energy(l: Light3D) -> float:
	if l.has_meta("energie_base"):
		return float(l.get_meta("energie_base"))
	if (l.light_cull_mask & 1) == 0:
		return 0.0
	var p := l.get_parent()
	if p is SmartBulb:
		return (p as SmartBulb).energy
	if l.visible and l.light_energy > 0.0:
		return l.light_energy
	if not l.visible or l.has_meta("always_on"):
		return 0.0
	return -1.0


## Capture la sonde (appelée par Main, une pièce à la fois, caméra de capture en place) : les lampes de
## la pièce à leur énergie de base pendant les images où la sonde rend ses faces, puis remises comme
## elles étaient (sauf si le jeu les a changées entre-temps), puis le filtrage. Coroutine.
func capture_reflection() -> void:
	if probe == null:
		return
	_probe_lights.clear()
	_probe_sum = 0.0
	var unknown: Array[Light3D] = []
	for l in _lights:
		if not is_instance_valid(l):
			continue
		var e: float = _probe_base[l] if _probe_base.has(l) else _base_energy(l)
		if e > 0.0:
			_probe_lights.append([l, e])
			_probe_sum += e
		elif e < 0.0:
			unknown.append(l)
	if _probe_sum <= 0.0:
		for l in unknown:
			_probe_lights.append([l, PROBE_DEFAULT_ENERGY])
			_probe_sum += PROBE_DEFAULT_ENERGY
	var saved := []      # [lampe, visible, énergie, énergie imposée]
	for e in _probe_lights:
		var l: Light3D = e[0]
		saved.append([l, l.visible, l.light_energy, float(e[1])])
		l.visible = true
		l.light_energy = float(e[1])
	# (les autres lampes de la pièce, allumées hors de leur état de base : éteintes le temps de la capture)
	for l in _lights:
		if is_instance_valid(l) and l.visible and l.light_energy > 0.0 and not _counted(l):
			saved.append([l, true, l.light_energy, 0.0])
			l.visible = false
	probe.intensity = 1.0
	probe.visible = true
	var was_active := active
	for i in PROBE_FACE_FRAMES:
		await RenderingServer.frame_post_draw
	for sv in saved:
		var l: Light3D = sv[0]
		if not is_instance_valid(l):
			continue
		var forced: float = sv[3]
		var untouched := (l.visible and is_equal_approx(l.light_energy, forced)) if forced > 0.0 else not l.visible
		if untouched:
			# (la pièce a changé d'état entre-temps : la visibilité suit set_active)
			l.visible = sv[1] if active == was_active else (active or l.has_meta("always_on"))
			l.light_energy = sv[2]
	update_reflection()
	for i in PROBE_TOTAL_FRAMES - PROBE_FACE_FRAMES:
		await RenderingServer.frame_post_draw


func _counted(l: Light3D) -> bool:
	for e in _probe_lights:
		if e[0] == l:
			return true
	return false


## Vrai : toutes les sondes à l'intensité 0 sans les cacher (comparaison avec / sans reflets de
## l'étalonnage de l'autotest ; cacher une sonde la ferait recapturer).
static var reflections_muted := false


## Intensité des reflets (appelée à chaque image par Main) : la somme des énergies actuelles des lampes
## de la capture sur leur somme de base. Lampes éteintes ou pièce inactive : 0, plus aucun reflet figé
## (la VoxelGI et le SSR restent).
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
		k = clampf(cur / _probe_sum * PROBE_GAIN, 0.0, 2.5)
		if k < 0.02:
			k = 0.0
	if absf(k - probe.intensity) > 0.004 or (k == 0.0 and probe.intensity != 0.0):
		probe.intensity = k


## Qualité trop basse ou style rétro : la sonde se cache (elle se recapturera si on la remontre).
func hide_reflection() -> void:
	if probe:
		probe.visible = false
		probe.intensity = 0.0


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
