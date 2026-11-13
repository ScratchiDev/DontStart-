class_name House
extends Builder
## La maison d'Henriette et Albert, construite à partir de HouseData : murs porteurs percés aux portes
## et aux fenêtres, puis chaque pièce (sol, plafond, papier peint, lambris, plinthes, corniche),
## les portes (avec leurs serrures) et les fenêtres. La chambre de la mère (room.gd) existe déjà ;
## les autres pièces sont des HouseRoom, meublées par leur script dans scripts/house/rooms/.
## Gère aussi quelles pièces sont « actives » (lumières, éclairage indirect, caméras de flux) selon la
## position du joueur, relaie les portes essayées vers le scénario (door_tried), garde l'état des portes
## dans Game.flags (« porte_P3 » = « libre » ou « ouverte ») et le réapplique au chargement (restore_all).

signal entered_room(room: HouseRoom)
## Une porte verrouillée ou coincée a été essayée, ou l'on a frappé à P2 (Door.knocks donne le nombre).
signal door_tried(id: String)
signal door_opened(id: String)

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

## Les portes en v0.3 (docs/v0.3.md, § 5.1) : serrure, libellé, messages. Prime sur le « lock » de
## HouseData. lock : "" (aucune), "stuck" (coincée, « stuck » appuis), "key:<objet>", "locked" (fermée de
## l'intérieur, sans clé dans cette version). P1 est la porte de la chambre de la mère (room.gd).
const H_P2A := "Tu frappes. Rien. Derrière, une respiration lente. Ses cachets."
const H_P2B := "Fermée à clé, de l'intérieur. La clé est dans la serrure, de l'autre côté."
const DOORS_V03 := {
	"P1": {"lock": "key:cle_chambre", "msg": "Fermée. De l'extérieur."},
	"P2": {"lock": "locked", "label_locked": "Frapper à la porte", "knock_msgs": [H_P2A, H_P2B]},
	"P3": {"lock": "stuck", "stuck": 2, "msg": "Coincée. Le bois a gonflé avec l'humidité. Encore un coup d'épaule."},
	"P4": {"lock": "", "ajar": 20.0},
	"P5": {"lock": "key:cle_lingerie", "msg": "Fermée à clé. La lingerie. Papi range ses clés sur un tableau, quelque part."},
	"P6": {"lock": "key:cle_escalier", "msg": "Fermée à clé. Derrière le verre, l'escalier descend dans le noir. Papi est passé par là."},
	"P7": {"lock": "key:cle_bureau", "msg": "Fermée à clé. Le bureau de Papi. Ton câble passe sous la porte."},
}
var rooms := {}          # id -> HouseRoom
var doors := {}          # id -> Door (P1, celle de la chambre de la mère, comprise)
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
	# les portes (P1, celle de la chambre de la mère, est construite par room.gd)
	for d in D.F1_DOORS:
		if d.get("existe", false):
			continue
		doors[d.id] = _make_door(d, y0)
	var p1: Variant = mother.get("door_node")
	if p1 is Door:
		doors["P1"] = p1
		(p1 as Door).door_id = "P1"
		_body_follows_leaf(p1)
	for id in doors:
		_watch_door(id, doors[id])
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
			# (nombre d'enfants de la coque : les suivants sont les meubles, voir Autotest.furniture_boxes, B1)
			r.set_meta("coque", r.get_child_count())
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
	dr.door_id = d.id
	dr.width = d.w
	dr.glass = d.get("glass", false)
	_set_lock(dr, DOORS_V03.get(d.id, {"lock": d.get("lock", "")}))
	add_child(dr)
	dr.name = d.id
	dr.width = d.w
	dr.wall_t = D.WALL
	dr.swing = sw
	dr.hinge_left = true
	dr.position = Vector3(d.at, y0, d.c)
	dr.rotation.y = -PI / 2.0
	dr.build(self)
	_body_follows_leaf(dr)
	var ajar: float = DOORS_V03.get(d.id, {}).get("ajar", 0.0)
	if ajar > 0.0:
		dr.set_ajar(ajar)
	# seuil
	_box(Vector3(D.WALL + 0.02, 0.012, d.w + 0.04), Vector3(d.at, y0 + 0.006, d.c), mats.wood_dark)
	return dr


## Le corps physique du battant (AnimatableBody3D) suit le battant quand il tourne. Avec
## sync_to_physics (le réglage par défaut), il n'écoute que ses propres déplacements, pas ceux de son
## parent : la porte ouverte (ou P4 entrouverte) gardait un mur invisible à sa place fermée, que le
## joueur ne pouvait pas traverser et que le rayon visait à la place de la porte.
func _body_follows_leaf(dr: Door) -> void:
	if dr.leaf == null:
		return
	for n in dr.leaf.find_children("*", "AnimatableBody3D", true, false):
		var b := n as AnimatableBody3D
		b.sync_to_physics = false
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, b.global_transform)


## Serrure, libellé et messages d'une porte (une entrée de DOORS_V03).
func _set_lock(dr: Door, st: Dictionary) -> void:
	var lock: String = st.get("lock", "")
	dr.locked = false
	dr.key_id = ""
	dr.stuck = 0
	if lock.begins_with("key:"):
		dr.locked = true
		dr.key_id = lock.substr(4)
	elif lock == "stuck":
		dr.stuck = int(st.get("stuck", 2))
	elif lock == "locked" or lock == "never" or lock.begins_with("event:"):
		dr.locked = true
	dr.locked_msg = st.get("msg", "Fermée à clé.")
	dr.label_locked = st.get("label_locked", "")
	dr.knock_msgs = st.get("knock_msgs", [])
	dr.refresh_label()


## Relaie les portes vers le scénario et garde leur état dans Game.flags (« porte_<id> »).
func _watch_door(id: String, dr: Door) -> void:
	dr.door_id = id
	dr.tried.connect(func() -> void: door_tried.emit(id))
	dr.knocked.connect(func() -> void: door_tried.emit(id))
	dr.opened.connect(func() -> void:
		Game.set_flag("porte_" + id, "ouverte")
		door_opened.emit(id))
	dr.closed.connect(func() -> void: Game.set_flag("porte_" + id, "libre"))
	dr.unlocked.connect(func() -> void:
		if not dr.is_open:
			Game.set_flag("porte_" + id, "libre"))


## Après la construction (nouvelle partie) et après un chargement : chaque pièce réapplique les
## drapeaux de Game.flags (restore()), et les portes leur état (« libre » = déverrouillée et fermée,
## « ouverte »). La chambre de la mère est restaurée par Acte1.restore().
func restore_all() -> void:
	for id in doors:
		var st: Variant = Game.flag("porte_" + id, "")
		var dr: Door = doors[id]
		if st == "ouverte" or st == "libre":
			dr.unlock()
			dr.set_open_now(st == "ouverte")
	for id in rooms:
		var r: HouseRoom = rooms[id]
		if id != "mere" and r.has_method("restore"):
			r.call("restore")
	if current:
		_update_feeds(current.room_id)


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
	_update_feeds(current.room_id)
	entered_room.emit(current)


## Caméras de flux (B16) : une caméra ne se met à jour que si le joueur est dans une pièce qui regarde
## son image (FeedCam.viewer_rooms : le bureau pour CAM 1 à CAM 3, la console ; la salle de bain pour
## le miroir) ; partout ailleurs, render_target_update_mode = DISABLED. (Haunt.room_changed fait de même.)
func _update_feeds(room_id: String) -> void:
	for n in get_tree().get_nodes_in_group("feed_cam"):
		var cam := n as FeedCam
		if cam:
			cam.set_room(room_id)


## Noms des caméras de flux qui se mettent à jour en ce moment (autotest, B16).
func rendering_feeds() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("feed_cam"):
		var cam := n as FeedCam
		if cam and cam.is_rendering():
			out.append(cam.title)
	return out
