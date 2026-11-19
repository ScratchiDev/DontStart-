class_name Door
extends Node3D
## Porte à panneaux qui pivote sur ses gonds. Le nœud est au centre de l'ouverture, au sol, sur le
## plan médian du mur ; son axe X local longe le mur ; elle s'ouvre du côté +Z local × swing.
## Construite par un Builder (pour partager ses matières). Peut être verrouillée (avec ou sans clé),
## coincée (« Forcer la porte »), entrouverte (set_ajar), ou fermée de l'autre côté : avec label_locked
## (« Frapper à la porte »), on frappe au lieu d'essayer la poignée (signal knocked, messages knock_msgs).
## Le libellé suit l'état (ouverte, verrouillée sans la clé, coincée) et l'inventaire.
##
## Passe « triple A » (lot V2-MAISON) :
##  - vraie carte (not Builder.soft_render()) : vraie porte de menuiserie, construite en un maillage :
##    montants, traverses et montant central à fil du bois, quatre panneaux à plate-bande biseautée
##    (25 mm à 12°) entourés d'une doucine de 18 mm, chant plein chanfreiné, jeu de 4 mm, deux paumelles,
##    têtière de serrure, et sur chaque face une plaque de propreté avec sa béquille (bec-de-cane) qui
##    s'abaisse de 35° quand on ouvre ou qu'on secoue la porte. Peinture ou bois selon la pièce (STYLES,
##    style = id de la porte). Rendu logiciel : la porte de la 0.3.3, à l'identique ;
##  - mouvement, dans les mêmes durées et avec les mêmes signaux : entrebâillement de 3° quand le pêne
##    lâche, course qui ralentit, dépassement de 1,5° posé exactement sur l'angle d'ouverture à 1,05 s
##    (sur 1,1 s) ; fermeture qui approche à 4° puis claque au pêne (0,72 s sur 0,8 s) ; claquement avec
##    rebond et secousse de caméra (« Sursauts réduits » la coupe) ; grincement selon la vitesse du battant
##    (Sfx.play_3d, hasard propre : les tirages d'avant ne changent pas) ;
##  - liseré de lumière sous la porte (vraie carte, hors style rétro) : décalque émissif au seuil,
##    réglé par set_seam() (House le fait suivre la lumière des pièces de part et d'autre).

signal opened
signal closed
signal tried          # quelqu'un a essayé d'ouvrir alors qu'elle est verrouillée ou coincée
signal knocked        # on a frappé (porte verrouillée sans clé, avec label_locked) ; knocks = nombre de fois
signal unlocked       # déverrouillée (clé, porte forcée, ou unlock())

## Jeu sous le battant : 2 cm du sol, 8 mm au-dessus du seuil (12 mm) ; le câble réseau d'Alexandre
## passe sous P7 sans être écrasé (autotest B1 : rien de plus haut ne doit être dans la zone du battant).
const LEAF_GAP := 0.02

# ------------------------------------------------------------------ mouvement (toutes versions)
## En fractions de la durée demandée (open : 1,1 s ; close : 0,8 s).
const OPEN_AJAR_DEG := 3.0          # le pêne lâche : le battant s'entrebâille de 3°…
const OPEN_AJAR_U := 0.12 / 1.1     # … pendant les 0,12 premières secondes
const OPEN_PUSH := 1.2              # vitesse de départ de la course (1 = régulière) ; elle ralentit jusqu'au bout
const OPEN_OVER_DEG := 1.5          # dépassement en fin de course…
const OPEN_OVER_U := 0.95 / 1.1     # … atteint à 0,95 s…
const OPEN_SETTLE_U := 1.05 / 1.1   # … puis posé exactement sur _target_angle() à 1,05 s
const CLOSE_NEAR_DEG := 4.0         # la fermeture approche jusqu'à 4°…
const CLOSE_NEAR_U := 0.62 / 0.8
const CLOSE_LATCH_U := 0.72 / 0.8   # … puis le pêne claque à 0,72 s (le son est à 0,9 × la durée)
const SLAM_SEC := 0.18
const SLAM_BOUNCE_DEG := 1.5
const SLAM_BOUNCE_SEC := 0.22
const SLAM_TRAUMA := 0.4            # secousse de caméra (groupe « presence ») si le joueur est à moins de…
const SLAM_TRAUMA_DIST := 4.0       # … 4 m
const HANDLE_DEG := 35.0            # la béquille s'abaisse de 35°
## Grincement : un « creak » quand le battant tourne lentement (entre CREAK_MIN_DPS et CREAK_MAX_DPS degrés
## par seconde : le début et la fin de la course), plus grave quand c'est lent. creak_k : 0 = muet.
const CREAK_MIN_DPS := 5.0
const CREAK_MAX_DPS := 80.0
const CREAK_DB := -23.0

# ------------------------------------------------------------------ menuiserie (vraie carte)
const STILE := 0.115                # montants
const MULLION := 0.09               # montant central
const RAIL_BOTTOM := 0.24           # haut de la traverse basse
const RAIL_LOCK := Vector2(0.93, 1.13)   # traverse de serrure (la béquille est à 1 m)
const RAIL_TOP := 0.115
const EDGE_CHAMFER := 0.002
## Profil autour des panneaux : [retrait depuis le bord de l'ouverture, profondeur sous le parement,
## lisse (1) ou arête (0)] : doucine de 18 mm (9 mm de chute), grain d'orge de 4 mm, plate-bande de
## 25 mm à 12° (5,3 mm), listel, table à 6 mm sous le parement.
const PANEL_PROFILE := [
	Vector3(0.0, 0.0, 0.0), Vector3(0.0018, -0.0007, 1.0), Vector3(0.0045, -0.0024, 1.0), Vector3(0.0072, -0.0043, 1.0),
	Vector3(0.0099, -0.0060, 1.0), Vector3(0.0126, -0.0076, 1.0), Vector3(0.0153, -0.0086, 1.0), Vector3(0.018, -0.009, 0.0),
	Vector3(0.018, -0.013, 0.0), Vector3(0.043, -0.0077, 0.0), Vector3(0.0445, -0.006, 0.0),
]
## Ouverture vitrée (P6) : petite doucine de 12 mm puis feuillure jusqu'au verre, au milieu du battant.
const GLASS_PROFILE := [
	Vector3(0.0, 0.0, 0.0), Vector3(0.003, -0.0012, 1.0), Vector3(0.006, -0.0035, 1.0), Vector3(0.009, -0.0055, 1.0),
	Vector3(0.012, -0.006, 0.0), Vector3(0.012, -0.0225, 0.0),
]
## Une teinte, une matière et une quincaillerie par porte (clé : id de la porte ; P1 par défaut, celle de
## room.gd, construite avant que la maison lui donne son id).
const STYLES := {
	"P1": {"bois": false, "teinte": Color(0.8, 0.77, 0.7), "crasse": 1.6, "metal": "laiton"},     # ta chambre : peinture fatiguée
	"P2": {"bois": false, "teinte": Color(0.79, 0.74, 0.62), "crasse": 1.1, "metal": "laiton"},   # Henriette : ivoire jauni
	"P3": {"bois": false, "teinte": Color(0.69, 0.71, 0.69), "crasse": 1.0, "metal": "laiton"},   # chambre d'amis : gris perle
	"P4": {"bois": false, "teinte": Color(0.88, 0.88, 0.85), "crasse": 0.6, "metal": "chrome", "laque": 0.4},  # salle de bain
	"P5": {"bois": false, "teinte": Color(0.6, 0.63, 0.56), "crasse": 1.3, "metal": "fer"},      # lingerie : vert de gris
	"P6": {"bois": true, "teinte": Color(0.86, 0.7, 0.53), "metal": "laiton"},                  # escalier : chêne blond vitré
	"P7": {"bois": true, "teinte": Color(0.56, 0.42, 0.32), "metal": "laiton"},                 # bureau d'Albert : chêne foncé
}
const METALS := {
	"laiton": [Color(0.56, 0.43, 0.25), 0.36, 0.9],
	"chrome": [Color(0.72, 0.72, 0.74), 0.16, 1.0],
	"fer": [Color(0.2, 0.19, 0.18), 0.5, 0.7],
}
## Liseré sous la porte : décalque émissif (taille : largeur + 2 cm, 12 cm de haut, 50 cm de profondeur,
## centré sur le battant ; la lumière s'étale de part et d'autre).
const SEAM_DEPTH := 0.5
const SEAM_HEIGHT := 0.12
const SEAM_ENERGY := 0.8

var door_id := ""                 # « P1 » à « P7 » (posé par la maison)
var style := ""                   # clé de STYLES (vide : door_id, sinon « P1 »)
var creak_k := 1.0                # force du grincement (DOORS_V03 « grince »)
var width := 0.86
var height := 2.04
var wall_t := 0.1
var swing := 1.0
var hinge_left := true
var open_angle := 1.62
var locked := false
var locked_msg := "Fermée à clé."
var key_id := ""                  # objet de l'inventaire qui la déverrouille (Game.items)
var key_msg := "Tu déverrouilles la porte."
var stuck := 0                    # porte coincée : nombre d'appuis encore nécessaires (« Forcer »)
var glass := false                # porte vitrée (verre cathédrale) : on devine ce qu'il y a derrière
var label_open := "Ouvrir la porte"
var label_close := "Fermer la porte"
var label_forced := "Forcer la porte"
## Libellé quand elle est verrouillée et qu'on n'a pas sa clé (« Frapper à la porte ») ; vide = label_open.
## Non vide : utiliser la porte frappe trois coups (knock) au lieu d'essayer la poignée.
var label_locked := ""
var knock_msgs: Array = []        # message après chaque série de coups (le dernier se répète ; vide = rien)
var knocks := 0                   # nombre de fois qu'on a frappé
var ajar_deg := 0.0               # entrouverte de tant de degrés (0 = fermée), voir set_ajar
var is_open := false
var leaf: Node3D
var it: Interactable
var levers: Array[Node3D] = []    # béquilles (vraie carte), une par face
var seam: Decal                   # liseré de lumière (vraie carte), voir set_seam
var _tw: Tween
var _htw: Tween
var _forcing := false             # on a déjà donné un coup d'épaule : le libellé devient « Forcer la porte »
var _knocking := false
var _last_rot := 0.0
var _creak_next_ms := 0
var _seam_k := 0.0
static var _rng := RandomNumberGenerator.new()
static var _rng_seeded := false


func build(b: Builder) -> void:
	if Builder.soft_render():
		_build_0_3_3(b)
	else:
		_build_joinery(b)
	# collision qui suit le battant (pousse le joueur au lieu de le traverser)
	var w := width
	var h := height
	var t := 0.045
	var cx := (1.0 if hinge_left else -1.0) * w / 2.0
	var body := AnimatableBody3D.new()
	body.collision_layer = Builder.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, t + 0.02)
	cs.shape = bs
	cs.position = Vector3(cx, h / 2.0, 0)
	body.add_child(cs)
	leaf.add_child(body)
	it = b._interactable(label_open, Vector3(w, h, t + 0.14), Vector3(cx, h / 2.0, 0), leaf)
	it.used.connect(_on_used)
	Game.inventory_changed.connect(refresh_label)
	refresh_label()
	if not Qualite.soft():
		_make_seam()
	_last_rot = leaf.rotation.y
	if not _rng_seeded:
		_rng_seeded = true
		_rng.seed = 7077


## La porte de la 0.3.3, à l'identique (rendu logiciel : le parcours testé ne change pas).
func _build_0_3_3(b: Builder) -> void:
	var w := width
	var h := height
	var t := 0.045
	var casing: Material = b.mats.paint
	# chambranles sur les deux faces + habillage de l'épaisseur du mur
	for side in [-1.0, 1.0]:
		var z: float = side * (wall_t / 2.0 + 0.0175)
		b._box(Vector3(0.085, h + 0.1, 0.035), Vector3(-w / 2.0 - 0.042, (h + 0.1) / 2.0, z), casing, false, self)
		b._box(Vector3(0.085, h + 0.1, 0.035), Vector3(w / 2.0 + 0.042, (h + 0.1) / 2.0, z), casing, false, self)
		b._box(Vector3(w + 0.17, 0.09, 0.035), Vector3(0, h + 0.045, z), casing, false, self)
	b._box(Vector3(0.02, h + 0.02, wall_t), Vector3(-w / 2.0 - 0.01, (h + 0.02) / 2.0, 0), casing, false, self)
	b._box(Vector3(0.02, h + 0.02, wall_t), Vector3(w / 2.0 + 0.01, (h + 0.02) / 2.0, 0), casing, false, self)
	b._box(Vector3(w + 0.04, 0.02, wall_t), Vector3(0, h + 0.01, 0), casing, false, self)
	_make_leaf(t)
	var dir := 1.0 if hinge_left else -1.0   # le battant s'étend de ce côté du gond
	var cx := dir * w / 2.0
	if glass:
		# battant à petits bois : bas plein, haut vitré (verre cathédrale dépoli)
		b._box(Vector3(w - 0.008, 1.066 - LEAF_GAP, t), Vector3(cx, (1.066 + LEAF_GAP) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(w - 0.008, 0.1, t), Vector3(cx, h - 0.05, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.1, h - 1.16, t), Vector3(dir * 0.05, 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.1, h - 1.16, t), Vector3(dir * (w - 0.058), 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		b._box(Vector3(0.04, h - 1.16, t * 0.8), Vector3(cx, 1.07 + (h - 1.16) / 2.0, 0), b.mats.door, false, leaf)
		var pane := b._box(Vector3(w - 0.2, h - 1.16, 0.006), Vector3(cx, 1.07 + (h - 1.16) / 2.0, 0), b.mats.frosted, false, leaf)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		b._box(Vector3(w - 0.008, h - LEAF_GAP, t), Vector3(cx, (h + LEAF_GAP) / 2.0, 0), b.mats.door, false, leaf)
	# panneaux moulurés sur les deux faces : cadre en saillie (12 mm), gorge plus sombre (4 mm de plus, la
	# crasse des recoins), table en relief (6 mm de plus). Deux maillages par battant (un par matière) au
	# lieu d'une boîte par pièce. (Avec 5 mm de relief, les ombres crénelaient en pointillés.)
	var raised := []
	var groove := []
	for face_side in [-1.0, 1.0]:
		var face: float = face_side * (t / 2.0 + 0.005)
		var lf: float = face_side * t / 2.0
		for py in [0.62, 1.58]:
			if glass and py > 1.0:
				continue
			for pu in [0.24, w - 0.24]:
				var ph := 0.78 if py < 1.0 else 0.66
				raised.append([Vector3(0.3, ph, 0.012), Vector3(dir * pu, py, lf + face_side * 0.006)])
				groove.append([Vector3(0.255, ph - 0.045, 0.004), Vector3(dir * pu, py, lf + face_side * 0.014)])
				raised.append([Vector3(0.2, ph - 0.1, 0.006), Vector3(dir * pu, py, lf + face_side * 0.019)])
		_knob(b, Vector3(dir * (w - 0.075), 1.0, face), face_side)
	_panel_mesh(raised, b.mats.door)
	_panel_mesh(groove, _groove_mat(b.mats.door))


## Le battant, articulé sur le gond.
func _make_leaf(t: float) -> void:
	leaf = Node3D.new()
	leaf.name = "Leaf"
	var hx := -width / 2.0 if hinge_left else width / 2.0
	leaf.position = Vector3(hx, 0, swing * (wall_t / 2.0 - t / 2.0 - 0.004))
	add_child(leaf)


## Boîtes [taille, centre] fondues en un maillage, enfant du battant.
func _panel_mesh(boxes: Array, mat: Material) -> void:
	if boxes.is_empty():
		return
	var st := SurfaceTool.new()
	var bm := BoxMesh.new()
	for bx in boxes:
		st.append_from(bm, 0, Transform3D(Basis.from_scale(bx[0]), bx[1]))
	var mi := MeshInstance3D.new()
	mi.name = "Panneaux"
	mi.mesh = st.commit()
	mi.material_override = mat
	leaf.add_child(mi)


## La peinture des portes, assombrie dans les gorges (une copie par matière, partagée par les portes).
static var _grooves := {}


static func _groove_mat(m: Material) -> Material:
	if not _grooves.has(m):
		var g := m
		if m is BaseMaterial3D:
			g = (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			(g as BaseMaterial3D).albedo_color = (m as BaseMaterial3D).albedo_color.darkened(0.3)
		_grooves[m] = g
	return _grooves[m]


func _knob(b: Builder, at: Vector3, face_side: float) -> void:
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.028
	sm.height = 0.05
	knob.mesh = sm
	knob.material_override = b.mats.metal
	knob.position = at + Vector3(0, 0, face_side * 0.055)
	leaf.add_child(knob)
	var neck := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.009
	cm.bottom_radius = 0.009
	cm.height = 0.05
	neck.mesh = cm
	neck.material_override = b.mats.metal
	neck.rotation.x = PI / 2.0
	neck.position = at + Vector3(0, 0, face_side * 0.025)
	leaf.add_child(neck)
	b._box(Vector3(0.05, 0.09, 0.006), at, b.mats.metal, false, leaf)


# ------------------------------------------------------------------ menuiserie (vraie carte)

## Maillage du battant, en coordonnées « canoniques » (x de 0 au gond vers la largeur côté serrure) puis
## retourné selon le côté des gonds ; les triangles sont remis à l'endroit d'après la normale voulue.
class Mesher:
	var st := SurfaceTool.new()
	var dir := 1.0

	func _init(d: float) -> void:
		dir = d
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func _m(v: Vector3) -> Vector3:
		return Vector3(v.x * dir, v.y, v.z)

	## Quadrilatère (sommets dans l'ordre du tour), normales et UV par sommet, montré du côté de « facing ».
	func quad(v: Array, nrm: Array, uv: Array, facing: Vector3) -> void:
		var p := [_m(v[0]), _m(v[1]), _m(v[2]), _m(v[3])]
		var f := _m(facing)
		# (Godot : face avant dans le sens des aiguilles d'une montre, vue de devant)
		var flip: bool = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(f) > 0.0
		var order := [0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]
		for i in order:
			st.set_normal(_m(nrm[i]))
			st.set_uv(uv[i])
			st.add_vertex(p[i])

	## Rectangle plat [x0, x1] × [y0, y1] à la profondeur z, tourné vers « n » ; grain : "v" (fil vertical)
	## ou "h" ; off : décalage des UV (m).
	func rect_z(x0: float, x1: float, y0: float, y1: float, z: float, n: Vector3, grain: String, off: Vector2) -> void:
		var v := [Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)]
		var uv := []
		for q in v:
			uv.append((Vector2(q.y, q.x) if grain == "v" else Vector2(q.x, q.y)) + off)
		quad(v, [n, n, n, n], uv, n)

	func commit() -> ArrayMesh:
		st.generate_tangents()
		return st.commit()


## Profil d'une ouverture [x0, x1] × [y0, y1] sur la face zs (+1 ou -1), parement à zf : rectangles
## emboîtés (coupes d'onglet d'elles-mêmes). Renvoie le rectangle du fond [x0, x1, y0, y1, profondeur].
static func _sweep(ms: Mesher, x0: float, x1: float, y0: float, y1: float, zs: float, zf: float, prof: Array, off: Vector2) -> Array:
	var n := prof.size()
	# normales 2D (retrait, profondeur) de chaque segment, puis aux sommets (lissées où le profil l'est)
	var seg_n: Array[Vector2] = []
	for j in n - 1:
		var a: Vector3 = prof[j]
		var b: Vector3 = prof[j + 1]
		seg_n.append(Vector2(-(b.y - a.y), b.x - a.x).normalized())
	var sides := [
		[Vector2(1, 0), "v"], [Vector2(-1, 0), "v"], [Vector2(0, 1), "h"], [Vector2(0, -1), "h"],
	]
	var s_acc := 0.0
	for j in n - 1:
		var a: Vector3 = prof[j]
		var b: Vector3 = prof[j + 1]
		var na: Vector2 = seg_n[j]
		var nb: Vector2 = seg_n[j]
		if a.z > 0.5 and j > 0:
			na = (seg_n[j - 1] + seg_n[j]).normalized()
		if b.z > 0.5 and j + 1 < n - 1:
			nb = (seg_n[j] + seg_n[j + 1]).normalized()
		var s0 := s_acc
		s_acc += Vector2(b.x - a.x, b.y - a.y).length()
		var za := zs * (zf + a.y)
		var zb := zs * (zf + b.y)
		for sd in sides:
			var inw: Vector2 = sd[0]
			var n3a := Vector3(inw.x * na.x, inw.y * na.x, zs * na.y)
			var n3b := Vector3(inw.x * nb.x, inw.y * nb.x, zs * nb.y)
			var v: Array
			if inw.x > 0.0:      # gauche
				v = [Vector3(x0 + a.x, y0 + a.x, za), Vector3(x0 + a.x, y1 - a.x, za), Vector3(x0 + b.x, y1 - b.x, zb), Vector3(x0 + b.x, y0 + b.x, zb)]
			elif inw.x < 0.0:    # droite
				v = [Vector3(x1 - a.x, y0 + a.x, za), Vector3(x1 - a.x, y1 - a.x, za), Vector3(x1 - b.x, y1 - b.x, zb), Vector3(x1 - b.x, y0 + b.x, zb)]
			elif inw.y > 0.0:    # bas
				v = [Vector3(x0 + a.x, y0 + a.x, za), Vector3(x1 - a.x, y0 + a.x, za), Vector3(x1 - b.x, y0 + b.x, zb), Vector3(x0 + b.x, y0 + b.x, zb)]
			else:                # haut
				v = [Vector3(x0 + a.x, y1 - a.x, za), Vector3(x1 - a.x, y1 - a.x, za), Vector3(x1 - b.x, y1 - b.x, zb), Vector3(x0 + b.x, y1 - b.x, zb)]
			var uv := []
			for k in 4:
				var q: Vector3 = v[k]
				var s := s0 if k < 2 else s_acc
				uv.append((Vector2(q.y, s) if sd[1] == "v" else Vector2(q.x, s)) + off)
			ms.quad(v, [n3a, n3a, n3b, n3b], uv, (n3a + n3b).normalized())
	var last: Vector3 = prof[n - 1]
	return [x0 + last.x, x1 - last.x, y0 + last.x, y1 - last.x, zs * (zf + last.y)]


func _build_joinery(b: Builder) -> void:
	var w := width
	var h := height
	var t := 0.045
	var zf := t / 2.0
	var key := style if style != "" else (door_id if STYLES.has(door_id) else "P1")
	var sty: Dictionary = STYLES.get(key, STYLES["P1"])
	_casings(b)
	_make_leaf(t)
	var dir := 1.0 if hinge_left else -1.0
	var ms := Mesher.new(dir)
	var off := Vector2(fposmod(float(key.hash() % 997) * 0.137, 1.0), fposmod(float(key.hash() % 991) * 0.291, 1.0))
	var xa := 0.004
	var xb := w - 0.004
	var ya := LEAF_GAP
	var yb := h
	var c := EDGE_CHAMFER
	var mid := (xa + xb) / 2.0
	var top := yb - RAIL_TOP
	# parements : montants (fil vertical), traverses (fil horizontal), montant central
	for zs in [1.0, -1.0]:
		var n := Vector3(0, 0, zs)
		var z: float = zs * zf
		ms.rect_z(xa + c, xa + STILE, ya + c, yb - c, z, n, "v", off)
		ms.rect_z(xb - STILE, xb - c, ya + c, yb - c, z, n, "v", off + Vector2(0.31, 0.0))
		ms.rect_z(xa + STILE, xb - STILE, ya + c, RAIL_BOTTOM, z, n, "h", off)
		ms.rect_z(xa + STILE, xb - STILE, RAIL_LOCK.x, RAIL_LOCK.y, z, n, "h", off + Vector2(0.0, 0.17))
		ms.rect_z(xa + STILE, xb - STILE, top, yb - c, z, n, "h", off + Vector2(0.0, 0.4))
		ms.rect_z(mid - MULLION / 2.0, mid + MULLION / 2.0, RAIL_BOTTOM, RAIL_LOCK.x, z, n, "v", off + Vector2(0.0, 0.53))
		if not glass:
			ms.rect_z(mid - MULLION / 2.0, mid + MULLION / 2.0, RAIL_LOCK.y, top, z, n, "v", off + Vector2(0.0, 0.53))
		# panneaux : doucine, plate-bande, table (fil vertical)
		var openings := [[xa + STILE, mid - MULLION / 2.0, RAIL_BOTTOM, RAIL_LOCK.x], [mid + MULLION / 2.0, xb - STILE, RAIL_BOTTOM, RAIL_LOCK.x]]
		if not glass:
			openings.append([xa + STILE, mid - MULLION / 2.0, RAIL_LOCK.y, top])
			openings.append([mid + MULLION / 2.0, xb - STILE, RAIL_LOCK.y, top])
		for o in openings:
			var f: Array = _sweep(ms, o[0], o[1], o[2], o[3], zs, zf, PANEL_PROFILE, off)
			ms.rect_z(f[0], f[1], f[2], f[3], f[4], n, "v", off + Vector2(0.11, 0.07))
		if glass:
			_sweep(ms, xa + STILE, xb - STILE, RAIL_LOCK.y, top, zs, zf, GLASS_PROFILE, off)
	# chant plein (une seule face par côté) et chanfreins de 2 mm
	var ze := zf - c
	var edges := [   # [normale, 4 sommets du chant]
		[Vector3(-1, 0, 0), [Vector3(xa, ya, -ze), Vector3(xa, ya, ze), Vector3(xa, yb, ze), Vector3(xa, yb, -ze)]],
		[Vector3(1, 0, 0), [Vector3(xb, ya, -ze), Vector3(xb, ya, ze), Vector3(xb, yb, ze), Vector3(xb, yb, -ze)]],
		[Vector3(0, -1, 0), [Vector3(xa, ya, -ze), Vector3(xb, ya, -ze), Vector3(xb, ya, ze), Vector3(xa, ya, ze)]],
		[Vector3(0, 1, 0), [Vector3(xa, yb, -ze), Vector3(xb, yb, -ze), Vector3(xb, yb, ze), Vector3(xa, yb, ze)]],
	]
	for e in edges:
		var n: Vector3 = e[0]
		var v: Array = e[1]
		var uv := []
		for q in v:
			uv.append(Vector2(q.y if n.y == 0.0 else q.x, q.z) + off)
		ms.quad(v, [n, n, n, n], uv, n)
		for zs in [1.0, -1.0]:
			# chanfrein entre le parement (retrait c) et le chant (retrait c en profondeur)
			var nc := (n + Vector3(0, 0, zs)).normalized()
			var cv: Array
			if n.x != 0.0:
				var xo := xa if n.x < 0.0 else xb
				var xi := xo - n.x * c
				cv = [Vector3(xi, ya + c, zs * zf), Vector3(xi, yb - c, zs * zf), Vector3(xo, yb, zs * ze), Vector3(xo, ya, zs * ze)]
			else:
				var yo := ya if n.y < 0.0 else yb
				var yi := yo - n.y * c
				cv = [Vector3(xa + c, yi, zs * zf), Vector3(xb - c, yi, zs * zf), Vector3(xb, yo, zs * ze), Vector3(xa, yo, zs * ze)]
			var cuv := []
			for q in cv:
				cuv.append(Vector2(q.y if n.y == 0.0 else q.x, q.z) + off)
			ms.quad(cv, [nc, nc, nc, nc], cuv, nc)
	var mi := MeshInstance3D.new()
	mi.name = "Panneaux"
	mi.mesh = ms.commit()
	mi.material_override = _joinery_mat(key, sty)
	leaf.add_child(mi)
	var metal := _metal_mat(String(sty.get("metal", "laiton")))
	if glass:
		_glazing(b, dir, xa + STILE, xb - STILE, RAIL_LOCK.y, top, mi.material_override)
	_hardware(dir, xa, xb, ya, yb, zf, metal)


## Verre cathédrale dépoli de P6 et ses petits bois (une croix), dans l'ouverture vitrée.
func _glazing(b: Builder, dir: float, x0: float, x1: float, y0: float, y1: float, wood: Material) -> void:
	var g: float = (GLASS_PROFILE[GLASS_PROFILE.size() - 1] as Vector3).x
	var gx0 := x0 + g
	var gx1 := x1 - g
	var gy0 := y0 + g
	var gy1 := y1 - g
	var pane := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(gx1 - gx0, gy1 - gy0)
	pane.mesh = q
	pane.material_override = _cathedral_mat(q.size)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pane.position = Vector3(dir * (gx0 + gx1) / 2.0, (gy0 + gy1) / 2.0, 0.0)
	pane.name = "Vitre"
	leaf.add_child(pane)
	var pane_b := pane.duplicate() as MeshInstance3D
	pane_b.rotation.y = PI
	leaf.add_child(pane_b)
	var st := SurfaceTool.new()
	var cx := (gx0 + gx1) / 2.0
	var cy := (gy0 + gy1) / 2.0
	st.append_from(Builder.bevel_box_mesh(Vector3(0.026, gy1 - gy0, 0.028), 0.003), 0, Transform3D(Basis(), Vector3(dir * cx, cy, 0)))
	for k in [0.5]:
		st.append_from(Builder.bevel_box_mesh(Vector3(gx1 - gx0, 0.026, 0.028), 0.003), 0,
			Transform3D(Basis(), Vector3(dir * cx, gy0 + (gy1 - gy0) * k, 0)))
	var bars := MeshInstance3D.new()
	bars.name = "PetitsBois"
	bars.mesh = st.commit()
	bars.material_override = wood
	leaf.add_child(bars)


## Paumelles, têtière, plaques de propreté, béquilles et entrées de clé (vraie carte).
func _hardware(dir: float, xa: float, xb: float, ya: float, yb: float, zf: float, metal: Material) -> void:
	var hw := SurfaceTool.new()
	# deux paumelles sur l'arête des gonds, côté où la porte s'ouvre
	for hy in [ya + 0.26, yb - 0.24]:
		hw.append_from(Builder.cylinder_mesh(0.0075, 0.0075, 0.11, 12), 0, Transform3D(Basis(), Vector3(0.0, hy, swing * (zf + 0.001))))
		hw.append_from(Builder.cylinder_mesh(0.0045, 0.0045, 0.012, 8), 0, Transform3D(Basis(), Vector3(0.0, hy + 0.061, swing * (zf + 0.001))))
	# têtière de la serrure, sur le chant
	hw.append_from(Builder.box_mesh(Vector3(0.0025, 0.24, 0.022), 0.0), 0, Transform3D(Basis(), Vector3(dir * (xb + 0.0012), 0.96, 0.0)))
	var hx := width - 0.075
	for zs in [1.0, -1.0]:
		# plaque de propreté (béquille à 1 m, entrée de clé à 0,9 m)
		hw.append_from(Builder.bevel_box_mesh(Vector3(0.042, 0.205, 0.004), 0.0014), 0,
			Transform3D(Basis(), Vector3(dir * hx, 0.955, zs * (zf + 0.002))))
	var mi := MeshInstance3D.new()
	mi.name = "Quincaillerie"
	mi.mesh = hw.commit()
	mi.material_override = metal
	leaf.add_child(mi)
	# entrées de clé (trou noir)
	var kh := SurfaceTool.new()
	for zs in [1.0, -1.0]:
		var xf := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(dir * hx, 0.9, zs * (zf + 0.0045)))
		kh.append_from(Builder.cylinder_mesh(0.0042, 0.0042, 0.0012, 12, 0.0), 0, xf)
		kh.append_from(Builder.box_mesh(Vector3(0.003, 0.009, 0.0012), 0.0), 0, Transform3D(Basis(), Vector3(dir * hx, 0.894, zs * (zf + 0.0045))))
	var kmi := MeshInstance3D.new()
	kmi.name = "EntreeCle"
	kmi.mesh = kh.commit()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.015, 0.012, 0.01)
	dark.roughness = 0.9
	kmi.material_override = dark
	kmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(kmi)
	# béquilles : rosace, tige, levier qui s'élargit vers le bout, bout arrondi recourbé vers la porte
	levers.clear()
	for zs in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.name = "Bequille"
		pivot.position = Vector3(dir * hx, 1.0, zs * (zf + 0.004))
		leaf.add_child(pivot)
		var ls := SurfaceTool.new()
		var along := -dir        # le levier pointe vers les gonds
		var zx := Basis(Vector3.RIGHT, PI / 2.0)
		ls.append_from(Builder.cylinder_mesh(0.0115, 0.0125, 0.009, 20), 0, Transform3D(zx, Vector3(0, 0, zs * 0.0045)))
		ls.append_from(Builder.cylinder_mesh(0.0068, 0.0072, 0.04, 14), 0, Transform3D(zx, Vector3(0, 0, zs * 0.029)))
		ls.append_from(Builder.lathe_mesh(PackedVector2Array([Vector2(0.0, -0.006), Vector2(0.0095, -0.006), Vector2(0.0095, 0.004), Vector2(0.0, 0.009)]), 14),
			0, Transform3D(zx, Vector3(0, 0, zs * 0.049)))
		# levier : axe le long de x (cylindre couché), légèrement recourbé vers la porte au bout
		var arm := Basis(Vector3.BACK, -along * PI / 2.0)
		var bend := Basis(Vector3.UP, along * zs * deg_to_rad(7.0))
		ls.append_from(Builder.cylinder_mesh(0.0082, 0.0066, 0.105, 14), 0,
			Transform3D(bend * arm, Vector3(along * 0.0525, 0, zs * (0.049 - 0.0064))))
		ls.append_from(Builder.lathe_mesh(PackedVector2Array([Vector2(0.0, -0.0085), Vector2(0.0086, -0.004), Vector2(0.0086, 0.003), Vector2(0.0, 0.0085)]), 14),
			0, Transform3D(bend * arm, Vector3(along * 0.104, 0, zs * (0.049 - 0.0127))))
		var lm := MeshInstance3D.new()
		lm.mesh = ls.commit()
		lm.material_override = metal
		pivot.add_child(lm)
		levers.append(pivot)


## Chambranles moulurés (vraie carte) : même encombrement que ceux de la 0.3.3 (8,5 cm × 3,5 cm,
## Builder.CASING_OUT / CASING_IN), profil à doucine et baguette, coupes d'onglet en haut ; habillage de
## l'épaisseur du mur.
func _casings(b: Builder) -> void:
	var w := width
	var h := height
	var casing: Material = b.mats.paint
	# profil en travers (de l'ouverture vers l'extérieur) : [u (m depuis le bord intérieur), saillie (m)]
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 0.016), Vector2(0.004, 0.019), Vector2(0.009, 0.0205),
		Vector2(0.014, 0.019), Vector2(0.018, 0.016), Vector2(0.024, 0.0215), Vector2(0.032, 0.026), Vector2(0.042, 0.029),
		Vector2(0.056, 0.031), Vector2(0.07, 0.032), Vector2(0.078, 0.0335), Vector2(0.082, 0.035), Vector2(0.085, 0.034),
		Vector2(0.085, 0.0)])
	var smooth := [false, false, true, true, true, false, true, true, true, true, true, true, true, false, false]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u_in := w / 2.0 + 0.042 - 0.0425     # bord intérieur du chambranle (0,0005 m dans l'ouverture : comme avant)
	var top_in := h + 0.0                     # bas de la traverse
	for side in [-1.0, 1.0]:
		var face: float = side * (wall_t / 2.0)
		# trois pièces : montant gauche, montant droit, traverse ; chacune : profil balayé le long de la pièce
		for piece in 3:
			for j in prof.size() - 1:
				var a := prof[j]
				var c := prof[j + 1]
				var d2 := Vector2(c.x - a.x, c.y - a.y)
				var n2 := Vector2(-d2.y, d2.x).normalized()     # (vers l'extérieur de la pièce, saillie)
				if n2.y < 0.0:
					n2 = -n2
				var na := n2
				var nc := n2
				if smooth[j] and j > 0:
					var p0 := prof[j - 1]
					var dp := Vector2(a.x - p0.x, a.y - p0.y)
					var np := Vector2(-dp.y, dp.x).normalized()
					if np.y < 0.0:
						np = -np
					na = (np + n2).normalized()
				if smooth[j + 1] and j + 2 < prof.size():
					var p2 := prof[j + 2]
					var dn := Vector2(p2.x - c.x, p2.y - c.y)
					var nn := Vector2(-dn.y, dn.x).normalized()
					if nn.y < 0.0:
						nn = -nn
					nc = (n2 + nn).normalized()
				var verts := []
				var norms := []
				# (un point du profil u à la hauteur y le long d'un montant, ou à x le long de la traverse ;
				# onglet : sur les montants, le haut s'arrête en top_in + u ; sur la traverse, x de ±(u_in + u))
				for pt in [[a, na, 0], [c, nc, 0], [c, nc, 1], [a, na, 1]]:
					var q: Vector2 = pt[0]
					var nq: Vector2 = pt[1]
					var end: int = pt[2]
					var pos: Vector3
					var nrm: Vector3
					if piece < 2:
						var sx := -1.0 if piece == 0 else 1.0
						var y := 0.0 if end == 0 else top_in + q.x
						pos = Vector3(sx * (u_in + q.x), y, face + side * q.y)
						nrm = Vector3(sx * nq.x, 0.0, side * nq.y)
					else:
						var sx2 := -1.0 if end == 0 else 1.0
						pos = Vector3(sx2 * (u_in + q.x), top_in + q.x, face + side * q.y)
						nrm = Vector3(0.0, nq.x, side * nq.y)
					verts.append(pos)
					norms.append(nrm.normalized())
				var facing: Vector3 = (norms[0] + norms[1]).normalized()
				var p := verts
				var flip: bool = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(facing) > 0.0
				var order := [0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]
				for i in order:
					st.set_normal(norms[i])
					st.add_vertex(p[i])
	var mi := MeshInstance3D.new()
	mi.name = "Chambranles"
	mi.mesh = st.commit()
	mi.material_override = casing
	add_child(mi)
	# habillage de l'épaisseur du mur (comme avant)
	b._box(Vector3(0.02, h + 0.02, wall_t), Vector3(-w / 2.0 - 0.01, (h + 0.02) / 2.0, 0), casing, false, self)
	b._box(Vector3(0.02, h + 0.02, wall_t), Vector3(w / 2.0 + 0.01, (h + 0.02) / 2.0, 0), casing, false, self)
	b._box(Vector3(w + 0.04, 0.02, wall_t), Vector3(0, h + 0.01, 0), casing, false, self)


## Matières des portes (une par style, partagées) : UV du maillage en mètres (le fil suit chaque pièce),
## crasse en triplanaire LOCAL (elle suit le battant quand il tourne).
static var _joinery_mats := {}
static var _metal_mats := {}


static func _joinery_mat(key: String, sty: Dictionary) -> Material:
	if _joinery_mats.has(key):
		return _joinery_mats[key]
	var tint: Color = sty.get("teinte", Color(0.8, 0.78, 0.72))
	var m: StandardMaterial3D
	if bool(sty.get("bois", false)):
		m = Surfaces.pbr("Wood027/Wood027", 1.2, tint, 1.0, false)
		m.clearcoat_enabled = true          # vernis
		m.clearcoat = 0.18
		m.clearcoat_roughness = 0.5
		_local_uv(m, 1.2)
		Surfaces.grime(m, 0.6, 2)
	else:
		m = Surfaces.pbr("PaintedWood009C/PaintedWood009C", 1.0, tint, 0.4, false)
		if sty.has("laque"):
			m.roughness_texture = null
			m.roughness = float(sty.laque)
			m.metallic_specular = 0.6
		_local_uv(m, 1.0)
		Surfaces.grime(m, 0.8 * float(sty.get("crasse", 1.0)), 3)
	m.uv2_world_triplanar = false
	_joinery_mats[key] = m
	return m


static func _local_uv(m: StandardMaterial3D, meters: float) -> void:
	m.uv1_triplanar = false
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3(1.0 / meters, 1.0 / meters, 1.0)


static func _metal_mat(kind: String) -> Material:
	if _metal_mats.has(kind):
		return _metal_mats[kind]
	var spec: Array = METALS.get(kind, METALS["laiton"])
	var m := StandardMaterial3D.new()
	m.albedo_color = spec[0]
	m.roughness = spec[1]
	m.metallic = spec[2]
	_metal_mats[kind] = m
	return m


## Verre cathédrale (vraie carte) : verre martelé à peine teinté, brillant, dont les cupules (bruit
## cellulaire, en carte de normales calculée par Godot hors du fil principal) brisent ce qu'on voit
## derrière (réfraction) et accrochent la lampe en éclats. L'ancienne matière dépolie (albédo 0,7, alpha
## 0,55, rugosité 0,9) devenait sous la lampe de poche un panneau blanc uni, comme du papier.
static var _cathedral_normal: NoiseTexture2D


static func _cathedral_mat(size: Vector2) -> StandardMaterial3D:
	if _cathedral_normal == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		n.cellular_jitter = 0.85
		n.frequency = 0.075              # une cupule tous les ~13 px : ~2,5 cm sur une tuile de 0,5 m
		n.seed = 6
		_cathedral_normal = NoiseTexture2D.new()
		_cathedral_normal.width = 256
		_cathedral_normal.height = 256
		_cathedral_normal.seamless = true
		_cathedral_normal.as_normal_map = true
		_cathedral_normal.bump_strength = 7.0
		_cathedral_normal.noise = n
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.6, 0.52, 0.34)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.16
	m.metallic_specular = 0.6
	m.normal_enabled = true
	m.normal_texture = _cathedral_normal
	m.normal_scale = 0.9
	m.refraction_enabled = true
	m.refraction_scale = 0.035
	m.uv1_scale = Vector3(size.x / 0.5, size.y / 0.5, 1.0)
	return m


# ------------------------------------------------------------------ liseré de lumière sous la porte

static var _seam_tex: ImageTexture


## Dégradé du liseré : très lumineux sur la ligne du battant, puis la lumière s'étale sur le sol (un pic
## de 3 cm et une traîne de 12 cm), fondue aux deux bouts de la porte.
static func _seam_texture() -> ImageTexture:
	if _seam_tex:
		return _seam_tex
	var wpx := 64
	var hpx := 64
	var img := Image.create_empty(wpx, hpx, false, Image.FORMAT_RGBA8)
	for y in hpx:
		var dz := absf((y + 0.5) / hpx - 0.5) * SEAM_DEPTH
		var k := exp(-dz / 0.03) * 0.8 + exp(-dz / 0.12) * 0.2
		for x in wpx:
			var u := (x + 0.5) / wpx
			var e := smoothstep(0.0, 0.07, u) * smoothstep(1.0, 0.93, u)
			var v := clampf(k * e, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, v))
	img.generate_mipmaps()
	_seam_tex = ImageTexture.create_from_image(img)
	return _seam_tex


func _make_seam() -> void:
	seam = Decal.new()
	seam.name = "Liseré"
	seam.size = Vector3(width + 0.02, SEAM_HEIGHT, SEAM_DEPTH)
	seam.texture_emission = _seam_texture()
	seam.emission_energy = 0.0
	seam.modulate = Color(1.0, 0.72, 0.45)
	seam.albedo_mix = 0.0
	seam.normal_fade = 0.5
	seam.upper_fade = 0.0
	seam.lower_fade = 0.0
	seam.cull_mask = 1
	seam.visible = false
	add_child(seam)
	# (centré sur le battant fermé, au ras du sol : la ligne du seuil sous la porte)
	seam.position = Vector3(0.0, 0.0, swing * (wall_t / 2.0 - 0.045 / 2.0 - 0.004))


## Lumière qui passe sous la porte : k (0 = rien ; 1 = une ampoule de couloir) et sa couleur. Rien en rendu
## logiciel ni en style rétro ; s'éteint quand la porte s'ouvre (la vraie lumière passe alors).
func set_seam(k: float, col := Color(1.0, 0.72, 0.45)) -> void:
	if seam == null:
		return
	var closed_k := 1.0 - smoothstep(1.0, 6.0, leaf_angle_deg())
	var target := clampf(k, 0.0, 1.6) * closed_k
	if Game.style_retro or not Qualite.extras_on():
		target = 0.0
	_seam_k = target
	seam.emission_energy = SEAM_ENERGY * target
	seam.modulate = col
	seam.visible = target > 0.005


# ------------------------------------------------------------------ jeu

func _target_angle() -> float:
	return -swing * open_angle if hinge_left else swing * open_angle


func _has_key() -> bool:
	return key_id != "" and Game.has_item(key_id)


## Libellé de l'interaction selon l'état : « Fermer la porte », « Frapper à la porte » (verrouillée sans
## la clé), « Forcer la porte » (coincée, après un premier coup d'épaule) ou « Ouvrir la porte ».
func refresh_label() -> void:
	if it == null:
		return
	if is_open:
		it.label = label_close
	elif locked and label_locked != "" and not _has_key():
		it.label = label_locked
	elif not locked and stuck > 0 and _forcing:
		it.label = label_forced
	else:
		it.label = label_open


func _on_used(_it: Interactable) -> void:
	if is_open:
		close()
		return
	if locked and _has_key():
		unlock()
		Sfx.play_at("metalLatch", global_position + Vector3(0, 1.0, 0), -2.0, 0.85)
		Game.hint(key_msg)
		await get_tree().create_timer(0.4, false).timeout
	if locked:
		if label_locked != "":
			knock()
			return
		rattle()
		Game.hint(locked_msg)
		tried.emit()
	elif stuck > 0:
		stuck -= 1
		rattle()
		Sfx.play_at("thud", global_position + Vector3(0, 1.0, 0), -6.0, 0.9)
		if stuck > 0:
			_forcing = true
			refresh_label()
			Game.hint(locked_msg)
			tried.emit()
		else:
			unlock()
			open(0.5)
	else:
		open()


## Déverrouille la porte (et la décoince) : elle s'ouvre ensuite normalement.
func unlock() -> void:
	var was := locked or stuck > 0
	locked = false
	stuck = 0
	_forcing = false
	refresh_label()
	if was:
		unlocked.emit()


## Trois coups contre la porte, puis le message suivant de knock_msgs (le dernier se répète).
func knock() -> void:
	if _knocking:
		return
	_knocking = true
	knocks += 1
	var p := global_position + Vector3(0, 1.25, 0)
	for k in 3:
		Sfx.play_at("thud", p, -3.0, 1.2 + 0.05 * k, 3.0)
		await get_tree().create_timer(0.42, false).timeout
	if not is_inside_tree():
		return
	_knocking = false
	if not knock_msgs.is_empty():
		Game.hint(str(knock_msgs[mini(knocks - 1, knock_msgs.size() - 1)]), 5.0)
	knocked.emit()


func open(seconds := 1.1) -> void:
	if is_open:
		return
	is_open = true
	ajar_deg = 0.0
	refresh_label()
	Sfx.play_at("doorOpen_1", global_position + Vector3(0, 1.0, 0), -4.0)
	Sfx.play_at("creak", global_position + Vector3(0, 1.2, 0), -14.0, 0.8)
	var from := leaf.rotation.y
	if absf(from) < deg_to_rad(1.0):
		_press_handle(0.06, 0.1)
	_animate(0, from, _target_angle(), seconds)
	opened.emit()


func close(seconds := 0.8) -> void:
	if not is_open:
		return
	is_open = false
	ajar_deg = 0.0
	refresh_label()
	_animate(1, leaf.rotation.y, 0.0, seconds)
	get_tree().create_timer(seconds * 0.9).timeout.connect(func() -> void:
		Sfx.play_at("doorClose_1", global_position + Vector3(0, 1.0, 0), -4.0))
	closed.emit()


## Claque la porte (événement de peur) : 0,18 s, un rebond de 1,5°, et la caméra encaisse si l'on est près.
func slam() -> void:
	is_open = false
	ajar_deg = 0.0
	refresh_label()
	_animate(2, leaf.rotation.y, 0.0, SLAM_SEC + SLAM_BOUNCE_SEC)
	get_tree().create_timer(0.16).timeout.connect(func() -> void:
		Sfx.play_at("thud", global_position + Vector3(0, 1.0, 0), 2.0, 0.8))
	get_tree().create_timer(SLAM_SEC).timeout.connect(func() -> void:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam and cam.global_position.distance_to(global_position + Vector3(0, 1.0, 0)) < SLAM_TRAUMA_DIST:
			get_tree().call_group("presence", "add_trauma", SLAM_TRAUMA, true))
	closed.emit()


## Entrouverte de « angle_deg » degrés, du côté où elle s'ouvre (P4 : 20°). Elle reste « fermée »
## pour le jeu (libellé « Ouvrir la porte ») ; l'utiliser l'ouvre en grand.
func set_ajar(angle_deg: float, seconds := 0.0) -> void:
	is_open = false
	ajar_deg = angle_deg
	refresh_label()
	var a := _target_angle() * deg_to_rad(angle_deg) / open_angle
	if seconds <= 0.0:
		if _tw:
			_tw.kill()
		leaf.rotation.y = a
		_last_rot = a
	else:
		_turn(a, seconds)


## Ouverte ou fermée tout de suite, sans bruit (restauration d'une sauvegarde). Émet opened / closed.
func set_open_now(on: bool) -> void:
	if _tw:
		_tw.kill()
	is_open = on
	ajar_deg = 0.0
	leaf.rotation.y = _target_angle() if on else 0.0
	_last_rot = leaf.rotation.y
	refresh_label()
	if on:
		opened.emit()
	else:
		closed.emit()


## Angle d'ouverture actuel du battant, en degrés (0 = fermée).
func leaf_angle_deg() -> float:
	return absf(rad_to_deg(leaf.rotation.y)) if leaf else 0.0


func rattle() -> void:
	Sfx.play_at("metalLatch", global_position + Vector3(0, 1.0, 0), -2.0)
	var base := leaf.rotation.y
	if _tw:
		_tw.kill()
	_tw = create_tween()
	for k in 6:
		_tw.tween_property(leaf, "rotation:y", base + (0.012 if k % 2 == 0 else -0.012) * swing, 0.05)
	_tw.tween_property(leaf, "rotation:y", base, 0.05)
	_jiggle_handle()


func _turn(angle: float, seconds: float) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(leaf, "rotation:y", angle, seconds)


## Course du battant de « from » à « to » en « seconds » : kind 0 = ouverture, 1 = fermeture, 2 = claquement.
## L'angle final est posé exactement (fin du tween).
func _animate(kind: int, from: float, to: float, seconds: float) -> void:
	if _tw:
		_tw.kill()
	var latched := absf(from) < deg_to_rad(1.0)
	_tw = create_tween()
	_tw.tween_method(func(u: float) -> void:
		leaf.rotation.y = _curve(kind, from, to, u, latched, seconds), 0.0, 1.0, seconds)
	_tw.tween_callback(func() -> void: leaf.rotation.y = to)


## Angle du battant au temps relatif u (0 à 1) de la course (voir _animate).
static func _curve(kind: int, from: float, to: float, u: float, latched: bool, seconds: float) -> float:
	if u >= 1.0:
		return to
	match kind:
		0:
			var sg := signf(to - from)
			var start := from
			var u0 := 0.0
			if latched:
				var ajar := deg_to_rad(OPEN_AJAR_DEG) * sg
				if u < OPEN_AJAR_U:
					var x := u / OPEN_AJAR_U
					return from + ajar * (1.0 - (1.0 - x) * (1.0 - x))
				start = from + ajar
				u0 = OPEN_AJAR_U
			var over := to + deg_to_rad(OPEN_OVER_DEG) * sg
			if u < OPEN_OVER_U:
				var x := (u - u0) / (OPEN_OVER_U - u0)
				# (Hermite : départ à OPEN_PUSH, arrivée à vitesse nulle sur le dépassement)
				var s := OPEN_PUSH * (x * x * x - 2.0 * x * x + x) + 3.0 * x * x - 2.0 * x * x * x
				return lerpf(start, over, s)
			if u < OPEN_SETTLE_U:
				var x := (u - OPEN_OVER_U) / (OPEN_SETTLE_U - OPEN_OVER_U)
				return lerpf(over, to, x * x * (3.0 - 2.0 * x))
			return to
		1:
			var near := deg_to_rad(CLOSE_NEAR_DEG) * signf(from - to)
			if absf(from - to) <= absf(near):
				var x := clampf(u / CLOSE_LATCH_U, 0.0, 1.0)
				return lerpf(from, to, x * x)
			if u < CLOSE_NEAR_U:
				var x := u / CLOSE_NEAR_U
				return lerpf(from, to + near, 0.5 - 0.5 * cos(PI * x))
			if u < CLOSE_LATCH_U:
				var x := (u - CLOSE_NEAR_U) / (CLOSE_LATCH_U - CLOSE_NEAR_U)
				return lerpf(to + near, to, x * x)
			return to
		_:
			var t := u * seconds
			if t < SLAM_SEC:
				var x := t / SLAM_SEC
				return lerpf(from, to, x * x)
			var bounce := deg_to_rad(SLAM_BOUNCE_DEG) * signf(from - to)
			var x2 := (t - SLAM_SEC) / SLAM_BOUNCE_SEC
			return to + bounce * sin(PI * x2) * (1.0 - x2) * 1.6
	return to


## La béquille s'abaisse (down s), reste (hold s) puis remonte (ressort).
func _press_handle(down: float, hold: float) -> void:
	if levers.is_empty():
		return
	if _htw:
		_htw.kill()
	var a := deg_to_rad(HANDLE_DEG) * (1.0 if hinge_left else -1.0)
	_htw = create_tween().set_parallel(false)
	_htw.tween_method(_set_handle, _handle_angle(), a, down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_htw.tween_interval(hold)
	_htw.tween_method(_set_handle, a, 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## On secoue la porte : la béquille descend, bute, remonte un peu, redescend, puis revient.
func _jiggle_handle() -> void:
	if levers.is_empty():
		return
	if _htw:
		_htw.kill()
	var a := deg_to_rad(HANDLE_DEG) * (1.0 if hinge_left else -1.0)
	_htw = create_tween()
	_htw.tween_method(_set_handle, _handle_angle(), a, 0.06)
	for k in 3:
		_htw.tween_method(_set_handle, a, a * 0.7, 0.05)
		_htw.tween_method(_set_handle, a * 0.7, a, 0.05)
	_htw.tween_method(_set_handle, a, 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_handle(a: float) -> void:
	for l in levers:
		l.rotation.z = a


func _handle_angle() -> float:
	return levers[0].rotation.z if not levers.is_empty() else 0.0


# ------------------------------------------------------------------ grincement

func _process(delta: float) -> void:
	if leaf == null or delta <= 0.0:
		return
	var r := leaf.rotation.y
	var dps := absf(rad_to_deg(r - _last_rot)) / delta
	_last_rot = r
	if creak_k <= 0.0 or dps < CREAK_MIN_DPS or dps > CREAK_MAX_DPS:
		return
	var now := Time.get_ticks_msec()
	if now < _creak_next_ms:
		return
	var x := clampf((dps - CREAK_MIN_DPS) / (CREAK_MAX_DPS - CREAK_MIN_DPS), 0.0, 1.0)
	var hinge := leaf.global_position + Vector3(0, 1.0, 0)
	var heavy := 0.86 if (style == "P7" or door_id == "P7" or door_id == "P6") else 1.0
	Sfx.play_3d("creak", hinge, {"db": CREAK_DB + 20.0 * log(creak_k) / log(10.0) + 4.0 * (1.0 - x),
		"pitch": lerpf(0.62, 1.02, x) * heavy, "jitter": 0.06, "unit_size": 2.0, "name": "Grincement"})
	_creak_next_ms = now + int(_rng.randf_range(380.0, 650.0))
