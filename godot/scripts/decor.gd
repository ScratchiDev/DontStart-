extends Node3D
## Ce qui fait qu'une chambre est habitée : livres, cassettes, disquettes, papiers, mug, crayons,
## câble, tableau en liège, calendrier, horloge arrêtée, linge, chaussures, sac.
## Et ce qui fait qu'elle fait peur : taches, moisissure, griffures, empreintes de pieds nus.

var room
var rng := RandomNumberGenerator.new()
var top := 0.76
const BOOK_COLORS := [Color(0.35, 0.1, 0.09), Color(0.12, 0.2, 0.3), Color(0.18, 0.24, 0.14), Color(0.5, 0.42, 0.22),
	Color(0.15, 0.14, 0.13), Color(0.42, 0.32, 0.24), Color(0.26, 0.12, 0.2), Color(0.55, 0.52, 0.45)]


func build(r: Node3D) -> void:
	room = r
	rng.seed = 77
	top = room.desk_top
	_desk()
	_shelf()
	_walls()
	_floor()
	_traces()
	_journal()


# ------------------------------------------------------------------ outils

func _m(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	return room._grimy(room._plain(c, rough, metal))


func _b(size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mi: MeshInstance3D = room._box(size, pos, mat, false, parent)
	mi.rotation.y = rot_y
	return mi


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scale_ := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale_
	add_child(mi)
	return mi


func _cyl(r: float, h: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c


## Feuille ou image posée à plat (au sol, sur le bureau).
func _flat(file: String, size: Vector2, pos: Vector3, rot_y: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := _mesh(q, pos, room._image_mat(file, 0.9), Vector3(-PI / 2.0, rot_y, 0))
	mi.rotation_order = EULER_ORDER_YXZ
	mi.rotation = Vector3(-PI / 2.0, rot_y, 0)
	return mi


## Image accrochée au mur. « facing » = direction vers laquelle elle regarde (vers la pièce).
func _hang(file: String, size: Vector2, pos: Vector3, facing: Vector3, alpha := false) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mat: StandardMaterial3D = room._image_mat(file, 0.85)
	if alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var mi := _mesh(q, pos, mat)
	mi.rotation.y = atan2(facing.x, facing.z)
	return mi


func _look(label: String, size: Vector3, pos: Vector3, text: String) -> void:
	var it: Interactable = room._interactable(label, size, pos, self)
	it.used.connect(func(_i: Interactable) -> void: Game.hint(text, 4.5))


# ------------------------------------------------------------------ le bureau

func _desk() -> void:
	# pile de disquettes
	var cols := [Color(0.05, 0.05, 0.055), Color(0.13, 0.17, 0.24), Color(0.62, 0.58, 0.48), Color(0.05, 0.05, 0.055)]
	for i in 4:
		var f := Node3D.new()
		f.position = Vector3(1.8, top + 0.002 + i * 0.0038, -2.36)
		f.rotation.y = rng.randf_range(-0.35, 0.35)
		add_child(f)
		_b(Vector3(0.09, 0.0035, 0.09), Vector3.ZERO, _m(cols[i], 0.5), 0.0, f)
		var lab := QuadMesh.new()
		lab.size = Vector2(0.07, 0.026)
		var lm := MeshInstance3D.new()
		lm.mesh = lab
		lm.material_override = room._image_mat("vhs_label.png", 0.9)
		lm.rotation.x = -PI / 2.0
		lm.position = Vector3(0, 0.0019, -0.026)
		f.add_child(lm)
	# le manuel du jeu, posé de travers
	var man := Node3D.new()
	man.position = Vector3(1.72, top + 0.004, -2.08)
	man.rotation.y = 0.42
	add_child(man)
	_b(Vector3(0.15, 0.008, 0.21), Vector3.ZERO, _m(Color(0.85, 0.84, 0.8), 0.7), 0.0, man)
	var mq := QuadMesh.new()
	mq.size = Vector2(0.148, 0.208)
	var mmi := MeshInstance3D.new()
	mmi.mesh = mq
	mmi.material_override = room._image_mat("manual.png", 0.8)
	mmi.rotation.x = -PI / 2.0
	mmi.position.y = 0.0045
	man.add_child(mmi)
	_look("Lire le manuel", Vector3(0.2, 0.06, 0.24), Vector3(1.72, top + 0.03, -2.08),
		"« RUNTIME, manuel de l'utilisateur ». Toutes les pages sont blanches, sauf la dernière : ton prénom.")
	# le chocolat de Mamie, froid, avec sa peau
	var red := _m(Color(0.5, 0.12, 0.1), 0.35)
	_mesh(_cyl(0.042, 0.095), Vector3(1.9, top + 0.0475, -2.5), red)
	_mesh(_cyl(0.036, 0.004), Vector3(1.9, top + 0.08, -2.5), _m(Color(0.32, 0.2, 0.13), 0.9))
	_look("Regarder le chocolat", Vector3(0.12, 0.14, 0.12), Vector3(1.9, top + 0.06, -2.5),
		"Le chocolat de Mamie. Froid depuis longtemps, avec une peau dessus. Elle en fait toujours trop.")
	# son mot, plié contre le clavier
	_flat("note.png", Vector2(0.13, 0.16), Vector3(1.58, top + 0.002, -1.9), 0.3)
	var hn: Interactable = room._interactable("Lire le mot de Mamie", Vector3(0.18, 0.05, 0.2), Vector3(1.58, top + 0.02, -1.9), self)
	hn.used.connect(func(_i: Interactable) -> void:
		get_tree().call_group("hud", "read_paper", Game.g("Bonne nuit mon grand…", "Bonne nuit ma grande…") +
			"\nJe t'ai monté un chocolat, il sera froid, comme d'habitude…\nPapi a dit de débrancher l'ordinateur avant de dormir. Fais-le pour lui, d'accord ?\n\nMamie"))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.018
	handle.outer_radius = 0.026
	_mesh(handle, Vector3(1.945, top + 0.05, -2.5), red, Vector3(PI / 2.0, 0, 0))
	# pot à crayons
	_mesh(_cyl(0.035, 0.1), Vector3(0.88, top + 0.05, -2.48), _m(Color(0.2, 0.22, 0.25), 0.6))
	for k in 5:
		var pc := _mesh(_cyl(0.004, 0.17, 6), Vector3(0.88 + rng.randf_range(-0.015, 0.015), top + 0.12, -2.48 + rng.randf_range(-0.015, 0.015)),
			_m([Color(0.8, 0.6, 0.1), Color(0.15, 0.3, 0.6), Color(0.6, 0.12, 0.1)][k % 3], 0.6),
			Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
		pc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# la feuille couverte de « 3:12 »
	_flat("paper_312.png", Vector2(0.21, 0.28), Vector3(0.98, top + 0.002, -2.05), -0.45)
	_look("Lire la feuille", Vector3(0.24, 0.04, 0.3), Vector3(0.98, top + 0.02, -2.05),
		"« ne pas jouer », « 3:12 », encore et encore. C'est l'écriture de ta mère, à seize ans. Elle ressemble à la tienne.")
	# câble : du moniteur jusqu'à la prise, en passant par le sol
	var socket := Vector3(2.0, 0.3, -2.6 + 0.024)
	_b(Vector3(0.08, 0.12, 0.012), socket, _m(Color(0.75, 0.72, 0.66), 0.5))
	_tube([Vector3(1.32, top + 0.25, -2.56), Vector3(1.6, top + 0.01, -2.57), Vector3(1.62, top - 0.05, -2.585),
		Vector3(1.66, 0.012, -2.55), Vector3(1.86, 0.008, -2.48), Vector3(1.99, 0.015, -2.55), Vector3(2.0, 0.24, -2.575)],
		0.0055, _m(Color(0.04, 0.04, 0.04), 0.5))


## Câble souple : un tube qui suit une courbe.
func _tube(points: Array, radius: float, mat: Material) -> void:
	var curve := Curve3D.new()
	for i in points.size():
		var p: Vector3 = points[i]
		var tangent := Vector3.ZERO
		if i > 0 and i < points.size() - 1:
			tangent = (points[i + 1] - points[i - 1]) * 0.25
		curve.add_point(p, -tangent, tangent)
	curve.bake_interval = 0.03
	var pts := curve.get_baked_points()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := 6
	for i in pts.size():
		var fwd: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.1:
			side = fwd.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(fwd).normalized()
		for k in ring:
			var a := TAU * k / ring
			st.add_vertex(pts[i] + (side * cos(a) + up * sin(a)) * radius)
	for i in pts.size() - 1:
		for k in ring:
			var a := i * ring + k
			var b := i * ring + (k + 1) % ring
			var c := a + ring
			var d := b + ring
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := mat.duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)


# ------------------------------------------------------------------ l'étagère

## Hauteurs des surfaces horizontales d'un meuble (ses étagères), relevées dans son maillage.
func _levels(holder: Node3D) -> Array[float]:
	var ys := {}
	var inv := global_transform.affine_inverse()
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				if (xf.basis * norms[i]).normalized().y > 0.95:
					ys[snappedf((xf * verts[i]).y, 0.01)] = true
	var out: Array[float] = []
	for y in ys.keys():
		out.append(y)
	out.sort()
	return out


func _shelf() -> void:
	var shelf: Node3D = room.props.get("bookcaseOpen")
	if not shelf:
		return
	var size: Vector3 = shelf.get_meta("size")
	var all := _levels(shelf)
	var levels: Array[float] = []
	for y in all:
		if y > 0.05 and y < size.y - 0.15:
			levels.append(y)
	if Game.autotest:
		print("étagères : ", levels)
	var x0 := shelf.position.x - size.x / 2.0 + 0.05
	var x1 := shelf.position.x + size.x / 2.0 - 0.05
	var z := shelf.position.z
	for li in levels.size():
		var y: float = levels[li]
		var x := x0
		if li == 1:
			# cassettes vidéo debout, étiquette vers la pièce
			for k in 7:
				_b(Vector3(0.026, 0.19, 0.105), Vector3(x + 0.013, y + 0.095, z + 0.02), _m(Color(0.04, 0.04, 0.045), 0.4))
				_b(Vector3(0.022, 0.12, 0.002), Vector3(x + 0.013, y + 0.1, z + 0.074), _m(Color(0.86, 0.84, 0.78), 0.8))
				x += 0.03
			continue
		while x < x1 - 0.05:
			var thick := rng.randf_range(0.018, 0.045)
			var h := rng.randf_range(0.16, 0.25)
			var d := rng.randf_range(0.13, 0.18)
			var col: Color = BOOK_COLORS[rng.randi() % BOOK_COLORS.size()]
			var bk := _b(Vector3(thick, h, d), Vector3(x + thick / 2.0, y + h / 2.0, z + 0.02), _m(col, 0.75))
			if rng.randf() < 0.12 and x > x0 + 0.1:
				bk.rotation.z = -0.32
				bk.position.x += 0.03
				x += 0.06
			x += thick + 0.002


# ------------------------------------------------------------------ les murs

func _walls() -> void:
	var back := -2.6
	# tableau en liège au-dessus du bureau
	_b(Vector3(0.74, 0.56, 0.02), Vector3(1.38, 1.68, back + 0.012), _m(Color(0.27, 0.18, 0.11), 0.7))
	_hang("corkboard.png", Vector2(0.7, 0.525), Vector3(1.38, 1.68, back + 0.0225), Vector3(0, 0, 1))
	_look("Regarder le tableau", Vector3(0.76, 0.58, 0.08), Vector3(1.38, 1.68, back + 0.04),
		"Des photos de 2016, des places de concert… et « elle me regarde la nuit ». L'écriture de ta mère.")
	# calendrier sur le mur de la porte
	_hang("calendar.png", Vector2(0.3, 0.42), Vector3(3.2 - 0.006, 1.5, -1.62), Vector3(-1, 0, 0))
	_look("Regarder le calendrier", Vector3(0.06, 0.45, 0.34), Vector3(3.17, 1.5, -1.62),
		"Octobre 2016. Tous les jours barrés jusqu'au 30. Le 31 est entouré en rouge, si fort que le papier est troué.")
	# horloge arrêtée au-dessus de la commode
	var clock_pos := Vector3(0.75, 1.95, 2.6 - 0.025)
	_mesh(_cyl(0.165, 0.045, 24), clock_pos, _m(Color(0.12, 0.1, 0.09), 0.5), Vector3(PI / 2.0, 0, 0))
	_hang("clock_face.png", Vector2(0.3, 0.3), clock_pos + Vector3(0, 0, -0.024), Vector3(0, 0, -1), true)
	_look("Regarder l'horloge", Vector3(0.34, 0.34, 0.08), clock_pos + Vector3(0, 0, -0.04),
		"L'horloge est arrêtée. 3 h 12, elle aussi.")
	# affiche au-dessus du lit
	_hang("poster_corbeaux.png", Vector2(0.5, 0.7), Vector3(-3.2 + 0.006, 1.62, 1.8), Vector3(1, 0, 0))


# ------------------------------------------------------------------ le sol

func _floor() -> void:
	# linge en tas au pied du lit
	var sm := SphereMesh.new()
	sm.radial_segments = 10
	sm.rings = 6
	for c in [[Vector3(-1.78, 0.05, 2.18), Vector3(0.36, 0.12, 0.26), Color(0.12, 0.17, 0.27)],
			[Vector3(-1.62, 0.09, 2.26), Vector3(0.28, 0.1, 0.22), Color(0.3, 0.3, 0.3)],
			[Vector3(-1.85, 0.11, 2.3), Vector3(0.22, 0.09, 0.2), Color(0.32, 0.08, 0.08)]]:
		_mesh(sm, c[0], _m(c[2], 1.0), Vector3(0, rng.randf() * TAU, 0), c[1])
	# chaussures près de la porte
	for k in 2:
		var shoe := Node3D.new()
		shoe.position = Vector3(2.72 + k * 0.14, 0, 0.6 + k * 0.06)
		shoe.rotation.y = 0.2 - k * 0.35
		add_child(shoe)
		var cap := CapsuleMesh.new()
		cap.radius = 0.05
		cap.height = 0.27
		var body := MeshInstance3D.new()
		body.mesh = cap
		body.material_override = _m(Color(0.16, 0.1, 0.07), 0.6)
		body.rotation.x = PI / 2.0
		body.scale = Vector3(1.0, 1.0, 0.8)
		body.position.y = 0.045
		shoe.add_child(body)
		_b(Vector3(0.1, 0.015, 0.28), Vector3(0, 0.008, 0), _m(Color(0.05, 0.05, 0.05), 0.8), 0.0, shoe)
	# sac d'école contre le bureau
	var bag := CapsuleMesh.new()
	bag.radius = 0.16
	bag.height = 0.42
	_mesh(bag, Vector3(0.33, 0.2, -1.78), _m(Color(0.1, 0.14, 0.24), 0.95), Vector3(0, 0.4, 0.12), Vector3(1.0, 1.0, 0.55))
	_mesh(sm, Vector3(0.37, 0.15, -1.68), _m(Color(0.09, 0.12, 0.2), 0.95), Vector3(0, 0.4, 0), Vector3(0.22, 0.14, 0.08))
	# pile de livres par terre, près du lit
	var y := 0.0
	for k in 4:
		var h := rng.randf_range(0.03, 0.05)
		_b(Vector3(rng.randf_range(0.17, 0.22), h, rng.randf_range(0.24, 0.3)), Vector3(-1.85, y + h / 2.0, 0.42),
			_m(BOOK_COLORS[rng.randi() % BOOK_COLORS.size()], 0.75), rng.randf_range(-0.4, 0.4))
		y += h
	# boulettes de papier à côté de la corbeille
	var ball := SphereMesh.new()
	ball.radius = 0.035
	ball.height = 0.06
	ball.radial_segments = 6
	ball.rings = 4
	for p in [Vector3(0.52, 0.03, -2.12), Vector3(0.64, 0.03, -1.97), Vector3(0.18, 0.03, -2.02)]:
		_mesh(ball, p, _m(Color(0.82, 0.8, 0.74), 1.0), Vector3(rng.randf(), rng.randf(), rng.randf()))
	# une feuille tombée près du lit
	_flat("paper_312.png", Vector2(0.21, 0.28), Vector3(-1.55, 0.006, 0.95), 0.7)


# ------------------------------------------------------------------ les traces

## Décalque (tache, empreinte…) posé sur une surface. « normal » sort de la surface,
## « up » indique où va le haut de l'image.
func _decal(file: String, center: Vector3, normal: Vector3, up: Vector3, size_u: float, size_v: float, depth := 0.2, mod := Color.WHITE) -> Decal:
	var d := Decal.new()
	d.texture_albedo = load("res://assets/decals/" + file)
	d.size = Vector3(size_u, depth, size_v)
	d.modulate = mod
	var y := normal.normalized()
	var z := -up.normalized()
	var x := y.cross(z)
	d.transform = Transform3D(Basis(x, y, z), center)
	add_child(d)
	return d


## Le journal de Manon (octobre 2016), glissé sous le lit, au bout des empreintes.
func _journal() -> void:
	var at := Vector3(-2.02, 0.012, 1.42)
	var j := Node3D.new()
	j.position = at
	j.rotation.y = 0.5
	add_child(j)
	_b(Vector3(0.15, 0.022, 0.21), Vector3.ZERO, _m(Color(0.16, 0.2, 0.34), 0.75), 0.0, j)
	_b(Vector3(0.14, 0.018, 0.2), Vector3(0.006, 0.0, 0.0), _m(Color(0.86, 0.83, 0.74), 0.9), 0.0, j)
	var it: Interactable = room._interactable("Ramasser le carnet", Vector3(0.3, 0.12, 0.32), at + Vector3(0, 0.05, 0), self, 4, 2.4)
	it.used.connect(func(_i: Interactable) -> void:
		j.visible = false
		it.enabled = false
		Game.add_item("journal_manon", "Journal de Maman (2016)", "Caché sous le lit. Les lettres qui brillent…", "doc")
		get_tree().call_group("hud", "read_pages", JOURNAL))


const JOURNAL := [
	"27 octobre 2016\n\nTrouvé au grenier une boîte de disquettes dans les affaires du boulot de Papa. Une seule marche. RUNTIME. C'est un jeu, je crois.\nIl connaît mon prénom.",
	"29 octobre\n\nIl pose des questions et il compte le temps que je mets à répondre. Si je mets trop longtemps, il choisit à ma place.\nIl choisit toujours mal.",
	"30 octobre\n\nIl dit que demain soir c'est son anniversaire et qu'on jouera « pour de vrai ». Papa a vu l'écran. Il est devenu tout blanc. Il connaît ce programme. Il ne veut pas dire d'où.",
	"1er novembre, le matin\n\nLes lettres qui brillent dans ses erreurs, c'était un mot. Je l'ai tapé. Il a écrit PARTIE SUSPENDUE.\nSuspendue, pas finie.\nJe n'arrive plus à dormir.",
	"Si quelqu'un lit ça :\nne branche pas cet ordinateur.\n\n— M.",
	"(au dos, un croquis)\nun sèche-cheveux, une antenne, une boussole, une bobine.\n« Son signal, c'est des ondes. Si on le coupe en morceaux, il ne tient plus. Papa saurait le construire. Il ne veut pas. »",
	"(collée sur la couverture : la grille de morse de Papa)\nA ·—     N —·\nB —···   O ———\nC —·—·   P ·——·\nD —··     Q ——·—\nE ·         R ·—·\nF ··—·   S ···\nG ——·    T —\nH ····    U ··—\nI ··        V ···—\nJ ·———   W ·——\nK —·—    X —··—\nL ·—··    Y —·——\nM ——     Z ——··\nS.O.S. = ··· ——— ···",
]


func _traces() -> void:
	# auréoles d'humidité au plafond
	_decal("stain_water.png", Vector3(-2.2, 2.6, 1.45), Vector3.DOWN, Vector3.RIGHT, 1.5, 1.3, 0.3)
	_decal("stain_water.png", Vector3(-2.75, 2.6, -1.9), Vector3.DOWN, Vector3.BACK, 0.8, 0.8, 0.3)
	# moisissure dans le coin de la fenêtre et derrière l'armoire
	_decal("mold.png", Vector3(-3.2, 2.15, -1.95), Vector3.RIGHT, Vector3.UP, 1.1, 0.9, 0.2)
	_decal("mold.png", Vector3(-2.2, 2.2, -2.6), Vector3.BACK, Vector3.UP, 1.0, 0.8, 0.2)
	# griffures et mots grattés au-dessus de la tête du lit
	_decal("scratches.png", Vector3(-3.2, 1.2, 0.95), Vector3.RIGHT, Vector3.UP, 0.72, 0.36, 0.16)
	# empreintes de pieds nus : de la porte fermée jusque sous le lit
	var start := Vector3(2.7, 0.0, 1.45)
	var stop_x := -2.0
	var step := 0.34
	var n := int((start.x - stop_x) / step)
	for i in n:
		var left := i % 2 == 0
		var p := start + Vector3(-i * step, 0, 0.09 if left else -0.09)
		p.z += sin(i * 0.7) * 0.05
		var fade := clampf(1.0 - float(i) / n * 0.5, 0.0, 1.0)
		_decal("foot_left.png" if left else "foot_right.png", p, Vector3.UP, Vector3.LEFT, 0.27, 0.32, 0.25, Color(1, 1, 1, fade))
