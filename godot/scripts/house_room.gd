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
