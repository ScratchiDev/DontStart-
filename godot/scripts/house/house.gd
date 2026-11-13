class_name House
extends Builder
## La maison d'Henriette et Albert, construite à partir de HouseData : murs porteurs percés aux portes
## et aux fenêtres, puis chaque pièce (sol, plafond, papier peint, lambris, plinthes, corniche),
## les portes (avec leurs serrures) et les fenêtres. La chambre de la mère (room.gd) existe déjà ;
## les autres pièces sont des HouseRoom, meublées par leur script dans scripts/house/rooms/.
## Gère aussi quelles pièces sont « actives » (lumières, éclairage indirect) selon la position du joueur.

signal entered_room(room: HouseRoom)

const D := preload("res://scripts/house/house_data.gd")
const ROOM_SCRIPTS := {
	"couloir": "res://scripts/house/rooms/couloir.gd",
	"amis": "res://scripts/house/rooms/amis.gd",
	"sdb": "res://scripts/house/rooms/sdb.gd",
	"lingerie": "res://scripts/house/rooms/lingerie.gd",
	"bureau": "res://scripts/house/rooms/bureau.gd",
	"gp": "res://scripts/house/rooms/gp.gd",
	"escalier": "res://scripts/house/rooms/escalier.gd",
}

## v0.3 : seul le couloir est ouvert (fin de version devant la chambre des grands-parents).
var teaser := true
const TEASER_MSG := {
	"P2": "Fermée à clé, de l'intérieur. Derrière, quelqu'un respire. Très lentement.",
	"P3": "Coincée. Le bois a gonflé avec l'humidité.",
	"P4": "Fermée. Sous la porte, une petite lumière bleue s'allume, puis s'éteint.",
	"P5": "Fermée à clé.",
	"P6": "Fermée. Derrière le verre, l'escalier descend dans le noir.",
	"P7": "Fermée à clé. Sous la porte, une LED clignote : la box.",
}
var rooms := {}          # id -> HouseRoom
var doors := {}          # id -> Door
var player: Node3D
var current: HouseRoom
var _t := 0.0


## mother : la chambre de la mère (room.gd), déjà construite.
func build(mother: HouseRoom) -> void:
	_make_materials()
	rooms["mere"] = mother
	var y0 := D.F1_Y
	var h := D.F1_H
	# murs porteurs et cloisons (plâtre), percés aux portes et aux fenêtres
	for w in D.F1_WALLS:
		var axis: String = "z" if w.axis == "x" else "x"
		var holes := _holes_on_wall(w.axis, w.at)
		var spans := [[w.from, w.to]]
		if w.has("skip"):
			spans = [[w.from, w.skip[0]], [w.skip[1], w.to]]
		for sp in spans:
			var hs := []
			for hl in holes:
				if hl[0] >= sp[0] - 0.01 and hl[1] <= sp[1] + 0.01:
					hs.append(hl)
			wall(axis, sp[0], sp[1], w.at, h, hs, mats.plaster, D.WALL, y0)
	# les pièces
	for id in D.F1_ROOMS:
		var d: Dictionary = D.F1_ROOMS[id]
		if d.get("existe", false):
			continue
		var r := _make_room(id, d, y0, h)
		rooms[id] = r
	# les portes
	for d in D.F1_DOORS:
		if d.get("existe", false):
			continue
		doors[d.id] = _make_door(d, y0)
	# les fenêtres
	for d in D.F1_WINDOWS:
		if d.get("existe", false):
			continue
		_make_window(d, y0)
	# voisinages (pour n'allumer que ce qui peut se voir)
	for d in D.F1_DOORS:
		var a := _room_at_door(d, -1.0)
		var b := _room_at_door(d, 1.0)
		if a and b:
			a.link(b)
	for id in rooms:
		var r: HouseRoom = rooms[id]
		if r.has_method("furnish"):
			r.furnish(self)


func _make_room(id: String, d: Dictionary, y0: float, h: float) -> HouseRoom:
	var script_path: String = ROOM_SCRIPTS.get(id, "")
	var r: HouseRoom
	if script_path != "" and ResourceLoader.exists(script_path):
		r = (load(script_path) as GDScript).new()
	else:
		r = HouseRoom.new()
	var rc: Array = d.rect
	r.setup(id, Rect2(rc[0], rc[2], rc[1] - rc[0], rc[3] - rc[2]), y0, h, d.get("title", id))
	r.floor_kind = d.get("floor", "parquet")
	add_child(r)
	r._make_materials()
	var x0: float = rc[0]
	var x1: float = rc[1]
	var z0: float = rc[2]
	var z1: float = rc[3]
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var floor_mat: Material = {"parquet": mats.floor, "moquette": mats.moquette, "carrelage": mats.carrelage}.get(d.get("floor", "parquet"), mats.floor)
	var wall_mat: Material = {
		"floral": mats.wall_floral, "stripes": mats.wall_stripes, "stripes_dark": mats.wall_stripes_dark,
		"paint": mats.wall_paint,
	}.get(d.get("wall", ""), mats.wall)
	var style := {"dado_h": 0.92, "dado": mats.wainscot}
	match d.get("dado", ""):
		"faience":
			style = {"dado_h": 1.4, "dado": mats.faience, "rail": false, "wood": mats.paint}
		"none":
			style = {"dado_h": 0.0, "wood": mats.paint}
	# sol et plafond jusqu'aux plans médians des murs (pas de chevauchement entre pièces)
	r._box(Vector3(x1 - x0 + D.WALL, 0.1, z1 - z0 + D.WALL), Vector3(cx, y0 - 0.05, cz), floor_mat, true)
	r._box(Vector3(x1 - x0 + D.WALL, 0.1, z1 - z0 + D.WALL), Vector3(cx, y0 + h + 0.05, cz), mats.ceil, true)
	# papier peint posé sur les murs porteurs (1,2 cm), percé comme eux, puis habillage
	var sides := [
		["x", x0, x1, z0, 1.0, "z", z0 - D.WALL / 2.0],   # côté z0 : mur parallèle à x
		["x", x0, x1, z1, -1.0, "z", z1 + D.WALL / 2.0],
		["z", z0, z1, x0, 1.0, "x", x0 - D.WALL / 2.0],   # côté x0 : mur parallèle à z
		["z", z0, z1, x1, -1.0, "x", x1 + D.WALL / 2.0],
	]
	for sd in sides:
		var axis: String = sd[0]
		var face: float = sd[3]
		var dir: float = sd[4]
		var holes := []
		for hl in _holes_on_wall(sd[5], sd[6]):
			if hl[1] > sd[1] and hl[0] < sd[2]:
				holes.append([maxf(hl[0], sd[1]), minf(hl[1], sd[2]), hl[2], hl[3]])
		r.wall(axis, sd[1], sd[2], face + dir * 0.006, h, holes, wall_mat, 0.012, y0)
		var gaps := []
		for hl in holes:
			if hl[2] < 0.3:
				gaps.append([hl[0], hl[1]])
		r.trim(axis, sd[1], sd[2], face + dir * 0.012, dir, h, gaps, style, y0)
	# seuil en bois à chaque porte de la pièce
	return r


## Ouvertures d'un mur (format de Builder.wall) : portes et fenêtres posées sur ce plan médian.
## data_axis : "x" = mur placé en x = at (il court le long de z), "z" = mur placé en z = at.
func _holes_on_wall(data_axis: String, at: float) -> Array:
	var out := []
	for d in D.F1_DOORS:
		if data_axis == "x" and absf(d.at - at) < 0.02:
			out.append(Builder.door_hole(d.c, d.w))
	for d in D.F1_WINDOWS:
		if d.axis == data_axis and absf(d.at - at) < 0.02:
			out.append([d.c - d.w / 2.0, d.c + d.w / 2.0, d.y0 - D.F1_Y, d.y1 - D.F1_Y])
	return out


func _room_at_door(d: Dictionary, side: float) -> HouseRoom:
	var p := Vector3(d.at + side * 0.3, D.F1_Y + 1.0, d.c)
	for id in rooms:
		var r: HouseRoom = rooms[id]
		if r.contains(p):
			return r
	return null


func _make_door(d: Dictionary, y0: float) -> Door:
	var swing_room: Dictionary = D.F1_ROOMS[d.swing]
	var swing_x: float = (swing_room.rect[0] + swing_room.rect[1]) / 2.0
	# axe local +Z de la porte (mur le long de z) = -x du monde
	var sw := 1.0 if swing_x < d.at else -1.0
	var dr := Door.new()
	dr.width = d.w
	dr.glass = d.get("glass", false)
	var lock: String = d.get("lock", "")
	if lock.begins_with("key:"):
		dr.locked = true
		dr.key_id = lock.substr(4)
		dr.locked_msg = _key_hint(dr.key_id)
	elif lock == "stuck":
		dr.stuck = 2
		dr.locked_msg = "Coincée. Le bois a gonflé avec l'humidité. Encore un coup d'épaule."
		dr.label_open = "Ouvrir la porte"
	elif lock == "never" or lock.begins_with("event:"):
		dr.locked = true
		dr.locked_msg = {
			"P2": "Fermée à clé, de l'intérieur. Derrière, quelqu'un respire.",
			"P6": "Fermée. Derrière le verre, l'escalier descend dans le noir.",
		}.get(d.id, "Fermée.")
	if teaser and TEASER_MSG.has(d.id):
		dr.locked = true
		dr.key_id = ""
		dr.stuck = 0
		dr.locked_msg = TEASER_MSG[d.id]
	add_child(dr)
	dr.name = d.id
	dr.width = d.w
	dr.wall_t = D.WALL
	dr.swing = sw
	dr.hinge_left = true
	dr.position = Vector3(d.at, y0, d.c)
	dr.rotation.y = -PI / 2.0
	dr.build(self)
	# seuil
	_box(Vector3(D.WALL + 0.02, 0.012, d.w + 0.04), Vector3(d.at, y0 + 0.006, d.c), mats.wood_dark)
	return dr


func _key_hint(key: String) -> String:
	return {
		"cle_bureau": "Fermée à clé. Le bureau de Papi. Mamie cache des doubles partout.",
		"cle_lingerie": "Fermée à clé. Papi range ses clés sur un tableau, quelque part.",
		"cle_chambre": "Fermée. De l'extérieur.",
	}.get(key, "Fermée à clé.")


func _make_window(d: Dictionary, y0: float) -> void:
	var fw: float = d.w
	var fh: float = d.y1 - d.y0
	var fy: float = (d.y0 + d.y1) / 2.0
	var p: Material = mats.paint
	var holder := Node3D.new()
	holder.name = d.id
	add_child(holder)
	# repère local : X le long du mur, Z vers l'intérieur de la maison
	var inward := 1.0
	if d.axis == "x":
		holder.position = Vector3(d.at, 0, d.c)
		inward = 1.0 if d.at < 0.0 else -1.0
		holder.rotation.y = PI / 2.0 if inward > 0.0 else -PI / 2.0
	else:
		holder.position = Vector3(d.c, 0, d.at)
		inward = 1.0 if d.at < 0.0 else -1.0
		holder.rotation.y = 0.0 if inward > 0.0 else PI
	# dormant, croisillon, appui
	_box(Vector3(fw + 0.12, 0.06, 0.14), Vector3(0, d.y0 - 0.03, 0), p, false, holder)
	_box(Vector3(fw + 0.12, 0.06, 0.14), Vector3(0, d.y1 + 0.03, 0), p, false, holder)
	_box(Vector3(0.06, fh, 0.14), Vector3(-fw / 2.0 - 0.03, fy, 0), p, false, holder)
	_box(Vector3(0.06, fh, 0.14), Vector3(fw / 2.0 + 0.03, fy, 0), p, false, holder)
	_box(Vector3(fw + 0.32, 0.035, 0.26), Vector3(0, d.y0 - 0.02, 0.1), mats.wood, false, holder)
	if d.get("blind", false):
		# store connecté baissé : lames grises, petite LED verte du moteur
		var slat := _plain(Color(0.32, 0.33, 0.34), 0.6, 0.3)
		for i in int(fh / 0.05):
			_box(Vector3(fw, 0.045, 0.012), Vector3(0, d.y0 + 0.025 + i * 0.05, 0.03), slat, false, holder)
		var led := _plain(Color(0.1, 1.0, 0.3))
		led.emission_enabled = true
		led.emission = Color(0.1, 1.0, 0.3)
		led.emission_energy_multiplier = 3.0
		_box(Vector3(0.012, 0.012, 0.01), Vector3(fw / 2.0 - 0.05, d.y1 - 0.04, 0.045), led, false, holder)
		_box(Vector3(fw + 0.06, 0.1, 0.12), Vector3(0, d.y1 - 0.05, 0.04), _plain(Color(0.85, 0.85, 0.83), 0.5), false, holder)
	elif d.get("frosted", false):
		_box(Vector3(fw, fh, 0.01), Vector3(0, fy, -0.02), mats.frosted, false, holder)
	else:
		var gm := ShaderMaterial.new()
		gm.shader = load("res://shaders/rain_glass.gdshader")
		gm.set_shader_parameter("glass_size", Vector2(fw, fh))
		var q := _quad(Vector2(fw, fh), Vector3(0, fy, -0.03), gm, 0.0, holder)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(0.04, fh, 0.05), Vector3(0, fy, -0.02), p, false, holder)


# ------------------------------------------------------------------ pièce courante et lumières

func finish(p: Node3D) -> void:
	player = p
	for id in rooms:
		var r: HouseRoom = rooms[id]
		r.collect_lights()
	if "floor_provider" in p:
		p.set("floor_provider", self)


## Nature du sol au point p (bruits de pas) : "parquet", "moquette", "carrelage" ou "tapis".
func floor_kind_at(p: Vector3) -> String:
	var pos := p + Vector3(0, 0.5, 0)
	if current and current.contains(pos, 0.05):
		return current.floor_kind_at(p)
	for id in rooms:
		var r: HouseRoom = rooms[id]
		if r.contains(pos, 0.05):
			return r.floor_kind_at(p)
	return "parquet"


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	var pos := player.global_position + Vector3(0, 0.5, 0)
	var now: HouseRoom = current
	if now == null or not now.contains(pos, 0.05):
		now = null
		for id in rooms:
			if (rooms[id] as HouseRoom).contains(pos, 0.05):
				now = rooms[id]
				break
	if now == null or now == current:
		return
	current = now
	for id in rooms:
		var r: HouseRoom = rooms[id]
		r.set_active(r == current or current.neighbors.has(r))
	entered_room.emit(current)
