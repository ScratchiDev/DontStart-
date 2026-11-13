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
	gi.bake()
	if gi.data:
		gi.data.interior = true
		gi.data.energy = energy
		gi.data.propagation = 0.8
		gi.data.use_two_bounces = true


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
