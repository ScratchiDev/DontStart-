class_name House
extends Builder
## La maison d'Henriette et Albert, construite à partir de HouseData : murs porteurs percés aux portes
## et aux fenêtres, puis chaque pièce (sol, plafond, papier peint, lambris, plinthes, corniche),
## les portes (avec leurs serrures) et les fenêtres. La chambre de la mère (room.gd) existe déjà ;
## les autres pièces sont des HouseRoom, meublées par leur script dans scripts/house/rooms/.
## Gère aussi quelles pièces sont « actives » (lumières, éclairage indirect, caméras de flux) selon la
## position du joueur, relaie les portes essayées vers le scénario (door_tried), garde l'état des portes
## dans Game.flags (« porte_P3 » = « libre » ou « ouverte ») et le réapplique au chargement (restore_all).
##
## Passe « triple A » (lot V2-MAISON), sur vraie carte (rendu logiciel : la 0.3.3 à l'identique) :
##  - stores à lames (aluminium laqué crème de 25 mm, légèrement entrouverts, une lame tordue, échelles de
##    cordon, barre de charge, coulisses, tirette ; le coffre et la LED du moteur restent) ;
##  - une lune par fenêtre (F2 à F8 ; F1 a la sienne dans room.gd) : SpotLight « Lune » parentée à la pièce
##    (set_active la coupe hors des pièces actives), avec un masque calculé par projection exacte de la
##    fenêtre (croisée, lames du store : rayures au sol) : rien ne passe à travers les murs ; ombre (meubles)
##    en Élevée et Ultra, dans la pièce courante seulement ; groupe « lune_fenetre » (l'éclair d'outside.gd
##    les pousse) ; coupées en style rétro (énergie 0) ;
##  - liseré de lumière sous les portes (Door.set_seam), d'après la lumière des pièces de part et d'autre ;
##  - vitres des fenêtres claires : rain_glass_net.gdshader hors rétro ;
##  - portes : style et grincement par porte (Door.style, Door.creak_k, DOOR_CREAK).
## Imprime « LUMIÈRES <n> (lunes <m>) » à finish() : n = Light3D des pièces de l'étage (rendu logiciel : m = 0,
## n identique à la 0.3.3).

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
## Grincement des portes (Door.creak_k) : P3 au bois gonflé, P4 qui bâille sur la salle de bain ; la porte
## vitrée et le chêne du bureau, plus sourds.
const DOOR_CREAK := {"P3": 1.5, "P4": 1.3, "P6": 0.7, "P7": 0.8}
## Lunes (voir l'en-tête) : élévation et distance de la source, couleur (celle de room.gd), énergie par
## fenêtre (les stores ne laissent passer que leurs fentes : énergie plus haute), côté jardin plus faible
## (la lune est côté rue : là-bas, c'est le ciel).
const MOON_ELEV_DEG := 32.0
const MOON_DIST := 4.5
const MOON_COLOR := Color(0.55, 0.66, 0.92)
const MOON_ENERGY := {"F2": 3.2, "F3": 1.1, "F4": 0.5, "F5": 2.4, "F7": 3.2, "F8": 0.75}
const MOON_GARDEN_K := 0.55
const MOON_TAILLE := 0.06          # (méta « taille » : PCSS en Ultra)
## Stores : pas des lames, largeur, inclinaison (depuis l'horizontale), demi-largeur des fentes de lumière
## dans le masque de la lune, et la lame tordue.
const SLAT_PITCH := 0.025
const SLAT_W := 0.025
const SLAT_TILT_DEG := 70.0
const SLAT_GAP := 0.0022
const SLAT_COLOR := Color(0.74, 0.72, 0.66)
## Liseré sous les portes : énergie de référence d'une pièce (Σ énergies des lampes dans la pièce).
const SEAM_REF := 0.3
const GLASS_NET := "res://shaders/rain_glass_net.gdshader"
const GLASS_OLD := "res://shaders/rain_glass.gdshader"

var rooms := {}          # id -> HouseRoom
var doors := {}          # id -> Door (P1, celle de la chambre de la mère, comprise)
var player: Node3D
var current: HouseRoom
var _t := 0.0
var moons: Array[SpotLight3D] = []      # lunes des fenêtres (vraie carte)
var _seams: Array = []                  # [Door, pièce A, pièce B] : liserés sous les portes
var _glass_mats: Array[ShaderMaterial] = []


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
	if not Qualite.soft():
		Game.settings_changed.connect(_on_settings_changed)
	# voisinages (pour n'allumer que ce qui peut se voir)
	for d in D.F1_DOORS:
		var a := _room_at_door(d, -1.0)
		var b := _room_at_door(d, 1.0)
		if a and b:
			a.link(b)
			var dr: Door = doors.get(d.id)
			if dr and dr.seam:
				_seams.append([dr, a, b])
	for id in rooms:
		var r: HouseRoom = rooms[id]
		if r.has_method("furnish"):
			# (nombre d'enfants de la coque : les suivants sont les meubles, voir Autotest.furniture_boxes, B1)
			r.set_meta("coque", r.get_child_count())
			# (chrono par pièce, budget R5 de la passe : « ÉTAGE <id> meublé en N ms »)
			var tf := Time.get_ticks_usec()
			r.furnish(self)
			print("ÉTAGE %s meublé en %d ms" % [id, roundi((Time.get_ticks_usec() - tf) / 1000.0)])


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
		"paint": mats.wall_paint, "floral_blue": mats.wall_floral_blue, "olive": mats.wall_olive,
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
	dr.style = d.id
	dr.creak_k = float(DOOR_CREAK.get(d.id, 1.0))
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
	var kind := "clair"
	if d.get("blind", false):
		kind = "store"
		if Builder.soft_render():
			# store connecté baissé : lames grises, petite LED verte du moteur
			# (lames qui se chevauchent, inclinées de 6° : les joints se lisent par l'ombre ; avec des fentes de
			# 5 mm sur la vitre noire, elles crénelaient en tirets. Un seul maillage pour tout le store.)
			var slat := _plain(Color(0.32, 0.33, 0.34), 0.6, 0.3)
			var st := SurfaceTool.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(fw, 0.054, 0.006)
			for i in int(fh / 0.05):
				st.append_from(bm, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(6.0)), Vector3(0, d.y0 + 0.027 + i * 0.05, 0.03)))
			var blind := MeshInstance3D.new()
			blind.name = "Store"
			blind.mesh = st.commit()
			blind.material_override = slat
			holder.add_child(blind)
		else:
			_blind(holder, d, fw, fh)
		var led := _plain(Color(0.1, 1.0, 0.3))
		led.emission_enabled = true
		led.emission = Color(0.1, 1.0, 0.3)
		led.emission_energy_multiplier = 3.0
		_box(Vector3(0.012, 0.012, 0.01), Vector3(fw / 2.0 - 0.05, d.y1 - 0.04, 0.045), led, false, holder)
		_box(Vector3(fw + 0.06, 0.1, 0.12), Vector3(0, d.y1 - 0.05, 0.04), _plain(Color(0.85, 0.85, 0.83), 0.5), false, holder)
	elif d.get("frosted", false):
		kind = "depoli"
		_box(Vector3(fw, fh, 0.01), Vector3(0, fy, -0.02), mats.frosted, false, holder)
		# petits bois de la croisée (une vitre unie faisait panneau vide)
		_box(Vector3(0.035, fh, 0.045), Vector3(0, fy, -0.005), p, false, holder)
		_box(Vector3(fw, 0.035, 0.045), Vector3(0, fy + fh * 0.12, -0.005), p, false, holder)
	else:
		var gm := ShaderMaterial.new()
		gm.shader = load(GLASS_NET if Qualite.extras_on() else GLASS_OLD)
		gm.set_shader_parameter("glass_size", Vector2(fw, fh))
		_glass_mats.append(gm)
		var q := _quad(Vector2(fw, fh), Vector3(0, fy, -0.03), gm, 0.0, holder)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(0.04, fh, 0.05), Vector3(0, fy, -0.02), p, false, holder)
	if not Qualite.soft():
		_moon(d, holder, fw, fh, fy, kind)


# ------------------------------------------------------------------ stores (vraie carte)

## Store vénitien baissé, lames presque fermées : un plan texturé (lames bombées de 25 mm en albédo et en
## carte de normales, fentes sombres ; les mipmaps les fondent au loin : des lames en géométrie faisaient un
## moiré) et une lame tordue en vrai relief au tiers haut. Échelles de cordon, barre de charge, coulisses,
## tirette. Rien ne projette d'ombre : les fentes de lumière viennent du masque de la lune.
func _blind(holder: Node3D, d: Dictionary, fw: float, fh: float) -> void:
	var mat := _slat_mat()
	var hh := fh - 0.11
	var plane := MeshInstance3D.new()
	plane.name = "Store"
	var q := QuadMesh.new()
	q.size = Vector2(fw - 0.026, hh)
	plane.mesh = q
	var m2 := mat.duplicate() as StandardMaterial3D
	m2.uv1_scale = Vector3((fw - 0.026) / (SLAT_PITCH * 8.0), hh / (SLAT_PITCH * 8.0), 1.0)
	plane.material_override = m2
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.position = Vector3(0, d.y0 + 0.01 + hh / 2.0, 0.026)
	holder.add_child(plane)
	# la lame tordue (vrai relief, 50 cm)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(hh / SLAT_PITCH)
	var yc: float = d.y0 + 0.01 + SLAT_PITCH * (int(n * 0.32) + 0.5)
	var xc := -fw * 0.12
	var x0 := xc - 0.25
	var x1 := xc + 0.25
	var segs := 6
	var xs := 12
	for xi in xs:
		var xa := lerpf(x0, x1, float(xi) / xs)
		var xb := lerpf(x0, x1, float(xi + 1) / xs)
		for sgi in segs:
			var ca := -SLAT_W / 2.0 + SLAT_W * float(sgi) / segs
			var cb := -SLAT_W / 2.0 + SLAT_W * float(sgi + 1) / segs
			var quad_pts := []
			var quad_n := []
			for corner in [[xa, ca], [xb, ca], [xb, cb], [xa, cb]]:
				var x: float = corner[0]
				var c: float = corner[1]
				var u := (x - xc) / 0.12
				var tilt := deg_to_rad(SLAT_TILT_DEG) - deg_to_rad(32.0) * exp(-u * u)
				var chord := Vector3(0.0, sin(tilt), cos(tilt))
				var crown := Vector3(0.0, -cos(tilt), sin(tilt))
				var k := 2.0 * c / SLAT_W
				quad_pts.append(Vector3(x, yc, 0.03) + chord * c + crown * (0.002 * (1.0 - k * k)))
				quad_n.append((crown + chord * (0.008 * k / SLAT_W)).normalized())
			for face in [1.0, -1.0]:
				var off: Vector3 = quad_n[0] * (0.00015 * face)
				var v := [quad_pts[0] + off, quad_pts[1] + off, quad_pts[2] + off, quad_pts[3] + off]
				var nv := [quad_n[0] * face, quad_n[1] * face, quad_n[2] * face, quad_n[3] * face]
				_emit_quad(st, v, nv, (nv[0] + nv[2]).normalized())
	var bent := MeshInstance3D.new()
	bent.name = "LameTordue"
	bent.mesh = st.commit()
	var bm := StandardMaterial3D.new()
	bm.albedo_color = SLAT_COLOR
	bm.metallic = 0.35
	bm.roughness = 0.42
	bent.material_override = bm
	bent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(bent)
	var top: float = d.y1 - 0.1
	var bottom: float = d.y0 + 0.012
	# échelles de cordon (devant et derrière les lames), barre de charge, coulisses, tirette
	var cord := _plain(Color(0.78, 0.76, 0.7), 0.85)
	var hw := SurfaceTool.new()
	for cx in [-fw * 0.3, fw * 0.3]:
		for cz in [-0.011, 0.011]:
			hw.append_from(Builder.cylinder_mesh(0.0009, 0.0009, top - bottom, 5, 0.0), 0,
				Transform3D(Basis(), Vector3(cx, (top + bottom) / 2.0, 0.03 + cz)))
	hw.append_from(Builder.cylinder_mesh(0.0011, 0.0011, 0.75, 5, 0.0), 0, Transform3D(Basis(), Vector3(fw / 2.0 - 0.06, d.y1 - 0.1 - 0.375, 0.085)))
	var cords := MeshInstance3D.new()
	cords.name = "Cordons"
	cords.mesh = hw.commit()
	cords.material_override = cord
	cords.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cords)
	_box(Vector3(fw - 0.01, 0.011, 0.022), Vector3(0, bottom - 0.004, 0.03), bm, false, holder)
	var acorn := _plain(Color(0.86, 0.84, 0.78), 0.4)
	_box(Vector3(0.012, 0.035, 0.012), Vector3(fw / 2.0 - 0.06, d.y1 - 0.1 - 0.76, 0.085), acorn, false, holder)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.011, fh - 0.1, 0.03), Vector3(sx * (fw / 2.0 - 0.0055), d.y0 + (fh - 0.1) / 2.0, 0.03), bm, false, holder)


## Lames du store en texture (8 lames par répétition, 16 pixels par lame) : albédo (crème, ombre de la lame
## du dessus, fente sombre) et normales (lame bombée : le haut regarde vers le haut). Partagée.
static var _slat_cache: StandardMaterial3D


static func _slat_mat() -> StandardMaterial3D:
	if _slat_cache:
		return _slat_cache
	var hpx := 128
	var alb := Image.create_empty(8, hpx, false, Image.FORMAT_RGB8)
	var nrm := Image.create_empty(8, hpx, false, Image.FORMAT_RGB8)
	for r in hpx:
		var p := (float(r % 16) + 0.5) / 16.0
		var a := 1.0
		var ny := 0.0
		if p > 0.9:
			a = 0.05
		else:
			var x := p / 0.9
			ny = lerpf(0.5, -0.32, x)
			a = (1.0 - 0.32 * (1.0 - smoothstep(0.0, 0.18, x))) * (1.0 - 0.2 * smoothstep(0.75, 1.0, x))
		var nz := sqrt(maxf(0.0, 1.0 - ny * ny))
		for c in 8:
			alb.set_pixel(c, r, Color(a, a, a))
			nrm.set_pixel(c, r, Color(0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5))
	alb.generate_mipmaps()
	nrm.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_color = SLAT_COLOR
	m.albedo_texture = ImageTexture.create_from_image(alb)
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(nrm)
	m.metallic = 0.35
	m.roughness = 0.42
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_slat_cache = m
	return m


## Quadrilatère dans un SurfaceTool, montré du côté de « facing » (face avant : sens horaire vue de devant).
static func _emit_quad(st: SurfaceTool, v: Array, nv: Array, facing: Vector3) -> void:
	var flip: bool = ((v[1] - v[0]) as Vector3).cross(v[2] - v[0]).dot(facing) > 0.0
	for i in ([0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]):
		st.set_normal(nv[i])
		st.add_vertex(v[i])


# ------------------------------------------------------------------ lunes (vraie carte, hors rétro)

## La lune d'une fenêtre : SpotLight posée dehors, à MOON_ELEV_DEG au-dessus de l'horizon, dans le plan
## perpendiculaire à la fenêtre (le masque se calcule alors rangée par rangée), visée sur son centre ; masque
## (light_projector) calculé pour cette fenêtre-là. Parentée à la pièce de la fenêtre.
func _moon(d: Dictionary, holder: Node3D, fw: float, fh: float, fy: float, kind: String) -> void:
	var r: HouseRoom = rooms.get(d.get("room", ""))
	if r == null:
		return
	var c := holder.global_transform * Vector3(0, fy, 0)
	var nrm := holder.global_transform.basis.z.normalized()
	var xw := holder.global_transform.basis.x.normalized()
	var e := deg_to_rad(MOON_ELEV_DEG)
	var lpos := c - nrm * cos(e) * MOON_DIST + Vector3.UP * sin(e) * MOON_DIST
	var l := SpotLight3D.new()
	l.name = "Lune"
	r.add_child(l)
	l.global_position = lpos
	l.look_at(c, Vector3.UP)
	# cône juste assez large pour la fenêtre
	var dc := (c - lpos).normalized()
	var a := 0.0
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			var corner: Vector3 = c + xw * (fw * sx) + Vector3.UP * (fh * sy)
			a = maxf(a, dc.angle_to((corner - lpos).normalized()))
	a += deg_to_rad(1.0)
	l.spot_angle = rad_to_deg(a)
	l.spot_angle_attenuation = 0.25
	l.spot_range = MOON_DIST + maxf(r.rect.size.x, r.rect.size.y) + 1.0
	l.spot_attenuation = 0.5
	l.light_color = MOON_COLOR
	var energy: float = MOON_ENERGY.get(d.id, 1.2) * (MOON_GARDEN_K if float(d.at) > 0.0 and d.axis == "x" else 1.0)
	l.set_meta("lune_energie", energy)
	l.light_energy = energy if Qualite.extras_on() else 0.0
	l.light_specular = 0.45
	# (ni éclairage indirect ni brouillard : la VoxelGI et le brouillard ignorent le masque, toute la pièce
	# s'éclairait par le cône entier)
	l.light_indirect_energy = 0.0
	l.light_volumetric_fog_energy = 0.0
	l.shadow_enabled = false
	l.shadow_bias = 0.05
	l.shadow_normal_bias = 1.2
	l.shadow_blur = 1.0
	l.set_meta("taille", MOON_TAILLE)
	l.set_meta("energie_base", 0.0)
	l.set_meta("lune", String(d.id))
	Qualite.hide_from_probes(l)
	# (posé après Main._ready : changer le filtre des masques (Qualite.apply) pendant que leurs textures
	# arrivent donnait parfois « Invalid Task ID » dans le journal)
	l.set_deferred("light_projector", _moon_cookie(l, c, nrm, xw, fw, fh, kind, tan(a)))
	l.add_to_group("lune_fenetre")
	moons.append(l)


## Masque de la lune : pour chaque rangée de pixels, le plan de la lumière qui la porte coupe la fenêtre sur
## une ligne horizontale (la lune est dans le plan perpendiculaire à la fenêtre) : couverture verticale
## intégrée sur la rangée (huit sous-rangées : ouverture, traverses, fentes du store), puis l'ouverture en
## largeur moins les montants, convertie en colonnes avec des bords antialiasés. Rangée 0 = bas du cône.
static func _moon_cookie(l: SpotLight3D, c: Vector3, nrm: Vector3, xw: Vector3, fw: float, fh: float, kind: String, tan_a: float) -> ImageTexture:
	var wpx := 128 if kind == "store" else 192
	var hpx := 512 if kind == "store" else 192
	if kind == "depoli":
		wpx = 64
		hpx = 64
	var img := Image.create_empty(wpx, hpx, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var b := l.global_transform.basis
	var zl := b.z.normalized()
	var yl := b.y.normalized()
	var xl := b.x.normalized()
	var lpos := l.global_position
	var cl := (c - lpos).dot(nrm)
	var sx := signf(xl.dot(xw))
	var sub := 8
	var spans: Array
	match kind:
		"store":
			spans = [[-fw / 2.0 + 0.012, fw / 2.0 - 0.012]]
		"depoli":
			spans = [[-fw / 2.0, -0.0175], [0.0175, fw / 2.0]]
		_:
			spans = [[-fw / 2.0, -0.02], [0.02, fw / 2.0]]
	for j in hpx:
		var cov := 0.0
		var lam_sum := 0.0
		var nlam := 0
		for k in sub:
			var t := ((j + (k + 0.5) / sub) / hpx) * 2.0 - 1.0
			var ray := -zl + yl * (t * tan_a)
			var rn := ray.dot(nrm)
			if rn <= 0.0001:
				continue
			var lam := cl / rn
			var yw := (lpos + ray * lam - c).y
			cov += _window_v(yw, fh, kind)
			lam_sum += lam
			nlam += 1
		cov /= sub
		if cov <= 0.003 or nlam == 0:
			continue
		var lam_c := lam_sum / nlam
		for sp in spans:
			var s0: float = float(sp[0]) * sx / (lam_c * tan_a)
			var s1: float = float(sp[1]) * sx / (lam_c * tan_a)
			_fill_span(img, j, (minf(s0, s1) + 1.0) * 0.5 * wpx, (maxf(s0, s1) + 1.0) * 0.5 * wpx, cov)
	if kind == "depoli":
		# verre dépoli : la lumière diffuse en une tache sans croisée
		img.resize(10, 10, Image.INTERPOLATE_BILINEAR)
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	elif kind == "clair":
		# vitre sous la pluie : la lumière arrive marbrée (gouttes, coulures), pas en aplat ; voile noir
		# calculé en 48 × 48 puis agrandi, posé par blend_rect (rapide)
		var fn := FastNoiseLite.new()
		fn.seed = int(absf(c.x * 13.0 + c.z * 7.0))
		fn.frequency = 0.36
		var streak := FastNoiseLite.new()
		streak.seed = fn.seed + 1
		streak.frequency = 0.2
		var veil := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
		for y in 48:
			for x in 48:
				var k := clampf(0.74 + 0.2 * fn.get_noise_2d(x, y) + 0.12 * streak.get_noise_2d(x * 5.0, y * 0.25), 0.0, 1.0)
				veil.set_pixel(x, y, Color(0, 0, 0, 1.0 - k))
		veil.resize(wpx, hpx, Image.INTERPOLATE_BILINEAR)
		img.convert(Image.FORMAT_RGBA8)
		img.blend_rect(veil, Rect2i(0, 0, wpx, hpx), Vector2i.ZERO)
		img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Transmission de la fenêtre à la hauteur yw (m, depuis son centre) : 0 hors de l'ouverture et sur les
## traverses ; store : les fentes entre les lames (SLAT_GAP de demi-largeur, bords doux).
static func _window_v(yw: float, fh: float, kind: String) -> float:
	if yw < -fh / 2.0 or yw > fh / 2.0:
		return 0.0
	match kind:
		"store":
			var ph := fposmod(yw + fh / 2.0 - 0.022 - SLAT_PITCH / 2.0, SLAT_PITCH)
			var dist := absf(ph - SLAT_PITCH / 2.0)
			return 1.0 - smoothstep(SLAT_GAP * 0.4, SLAT_GAP * 1.6, dist)
		"depoli":
			if absf(yw - fh * 0.12) < 0.0175:
				return 0.0
			return 1.0
	return 1.0


## Ajoute la couverture v sur la rangée « row », des colonnes c0 à c1 (réelles), bords partiels.
static func _fill_span(img: Image, row: int, c0: float, c1: float, v: float) -> void:
	var w := img.get_width()
	c0 = clampf(c0, 0.0, float(w))
	c1 = clampf(c1, 0.0, float(w))
	if c1 <= c0:
		return
	var i0 := int(floor(c0))
	var i1 := int(floor(c1))
	if i0 == i1:
		_add_px(img, i0, row, (c1 - c0) * v)
		return
	_add_px(img, i0, row, (float(i0 + 1) - c0) * v)
	if i1 - i0 - 1 > 0:
		img.fill_rect(Rect2i(i0 + 1, row, i1 - i0 - 1, 1), Color(v, v, v))
	if i1 < w:
		_add_px(img, i1, row, (c1 - float(i1)) * v)


static func _add_px(img: Image, x: int, y: int, v: float) -> void:
	if x < 0 or x >= img.get_width():
		return
	var k := minf(1.0, img.get_pixel(x, y).r + v)
	img.set_pixel(x, y, Color(k, k, k))


## Lunes de la pièce courante : ombres (meubles) en Élevée et Ultra seulement ; énergie 0 en style rétro.
func _update_moons() -> void:
	var extras := Qualite.extras_on()
	var shadows := extras and Qualite.at_least(Qualite.ELEVEE)
	for l in moons:
		if not is_instance_valid(l):
			continue
		l.light_energy = float(l.get_meta("lune_energie", 1.0)) if extras else 0.0
		l.shadow_enabled = shadows and current != null and l.get_parent() == current


## Un réglage a changé (style rétro, qualité) : lunes, vitres.
func _on_settings_changed() -> void:
	_update_moons()
	var sh: Shader = load(GLASS_NET if Qualite.extras_on() else GLASS_OLD)
	for gm in _glass_mats:
		if gm.shader != sh:
			var gs: Variant = gm.get_shader_parameter("glass_size")
			gm.shader = sh
			gm.set_shader_parameter("glass_size", gs)


# ------------------------------------------------------------------ liserés sous les portes

## Lumière d'une pièce pour le liseré : somme des énergies des lampes visibles DANS la pièce (pas la lune ni
## le dehors), relative à SEAM_REF ; [k, couleur moyenne].
func _room_glow(r: HouseRoom, cache: Dictionary) -> Array:
	if cache.has(r):
		return cache[r]
	var sum := 0.0
	var col := Color(0, 0, 0)
	for l in r._lights:
		if not is_instance_valid(l) or not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		if (l.light_cull_mask & 1) == 0 or l.has_meta("lune") or not r.contains(l.global_position, 0.2):
			continue
		# (seulement les vraies lampes : pas les voyants, l'anneau d'une enceinte, la LED d'une caméra)
		if (l is OmniLight3D and (l as OmniLight3D).omni_range < 2.0) or (l is SpotLight3D and (l as SpotLight3D).spot_range < 3.0):
			continue
		var e := l.light_energy * (0.35 if l is SpotLight3D else 1.0)
		sum += e
		col += l.light_color * e
	var out := [sum / SEAM_REF, (col / sum) if sum > 0.0 else Color(1.0, 0.72, 0.45)]
	cache[r] = out
	return out


func _update_seams() -> void:
	if _seams.is_empty():
		return
	var cache := {}
	for e in _seams:
		var dr: Door = e[0]
		if not is_instance_valid(dr):
			continue
		var ga: Array = _room_glow(e[1], cache)
		var gb: Array = _room_glow(e[2], cache)
		var k := maxf(float(ga[0]), float(gb[0]))
		var col: Color = ga[1] if float(ga[0]) >= float(gb[0]) else gb[1]
		dr.set_seam(k, col)


# ------------------------------------------------------------------ pièce courante et lumières

func finish(p: Node3D) -> void:
	player = p
	var n_lights := 0
	for id in rooms:
		var r: HouseRoom = rooms[id]
		r.collect_lights()
		n_lights += r._lights.size()
	print("LUMIÈRES %d (lunes %d)" % [n_lights, moons.size()])
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
	_update_seams()
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
	if not moons.is_empty():
		_update_moons()
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
