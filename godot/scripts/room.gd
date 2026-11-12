extends HouseRoom
## La chambre, construite au lancement : murs texturés (ambientCG, CC0), meubles (Kenney, CC0)
## mis à l'échelle en mètres réels, fenêtre sur la nuit, ordinateur rétro, objets interactifs.
## Repère : x de -3.2 (fenêtre) à 3.2 (porte), z de -2.6 (bureau) à 2.6, y du sol (0) au plafond.

signal floppy_taken
signal pc_used

const W := 6.4
const D := 5.2
const H := 2.6

# fenêtre (mur de gauche)
const WIN_Z0 := -1.15
const WIN_Z1 := 0.25
const WIN_Y0 := 0.95
const WIN_Y1 := 2.2
const DOOR_Z := 1.4

var desk_top := 0.76
var pc_x := 1.2
var pc_z := -2.36
var seat_pos := Vector3(1.2, 0.0, -1.58)
var screen_center := Vector3.ZERO
var screen_mat: ShaderMaterial
var screen_light: OmniLight3D
var terminal: Node
var led_mat: StandardMaterial3D
var floppy: Node3D
var floppy_item: Interactable
var wardrobe_open := false
var wardrobe_doors: Array[Node3D] = []
var ceiling_light: OmniLight3D
var ceiling_on := false
var ceiling_dead := false
var moon: SpotLight3D
var door_leaf: Node3D
var door_node: Door
var chair: Node3D
var rng := RandomNumberGenerator.new()
var window_glass_mat: ShaderMaterial
var outside: Node3D
var decor: Node3D


func _ready() -> void:
	setup("mere", Rect2(-W / 2.0, -D / 2.0, W, D), 0.0, H, "Chambre de ta mère")
	rng.seed = 312
	_make_materials()
	_build_shell()
	_build_window()
	_build_furniture()
	_build_pc()
	_build_wall_things()
	_build_lights()
	_build_dust()
	outside = (load("res://scripts/outside.gd") as GDScript).new()
	outside.name = "Outside"
	add_child(outside)
	outside.build(self, window_glass_mat)
	decor = (load("res://scripts/decor.gd") as GDScript).new()
	decor.name = "Decor"
	add_child(decor)
	decor.build(self)


# ------------------------------------------------------------------ murs, sol, plafond

func _build_shell() -> void:
	var t := 0.1
	# sol et plafond jusqu'aux plans médians des murs : les pièces voisines prennent le reste
	_box(Vector3(W + t, t, D + t), Vector3(0, -t / 2.0, 0), mats.floor, true)
	_box(Vector3(W + t, t, D + t), Vector3(0, H + t / 2.0, 0), mats.ceil, true)
	_box(Vector3(W + 2 * t, H, t), Vector3(0, H / 2.0, -D / 2.0 - t / 2.0), mats.wall, true)
	_box(Vector3(W + 2 * t, H, t), Vector3(0, H / 2.0, D / 2.0 + t / 2.0), mats.wall, true)
	# mur du couloir, percé pour la porte
	wall("z", -D / 2.0, D / 2.0, W / 2.0 + t / 2.0, H, [Builder.door_hole(DOOR_Z)], mats.wall, t)
	# mur de la façade, percé pour la fenêtre
	wall("z", -D / 2.0, D / 2.0, -W / 2.0 - t / 2.0, H, [[WIN_Z0, WIN_Z1, WIN_Y0, WIN_Y1]], mats.wall, t)
	# lambris (0 à 0,92 m), cimaise, plinthes, moulures au plafond
	trim("x", -W / 2.0, W / 2.0, -D / 2.0, 1.0, H)
	trim("x", -W / 2.0, W / 2.0, D / 2.0, -1.0, H)
	trim("z", -D / 2.0, D / 2.0, -W / 2.0, 1.0, H)
	var dh: Array = Builder.door_hole(DOOR_Z)
	trim("z", -D / 2.0, D / 2.0, W / 2.0, -1.0, H, [[dh[0], dh[1]]])


func _build_window() -> void:
	var x := -W / 2.0
	var fw := WIN_Z1 - WIN_Z0
	var fh := WIN_Y1 - WIN_Y0
	var fz := (WIN_Z0 + WIN_Z1) / 2.0
	var fy := (WIN_Y0 + WIN_Y1) / 2.0
	var p: Material = mats.paint
	_box(Vector3(0.14, 0.06, fw + 0.12), Vector3(x, WIN_Y0 - 0.03, fz), p)
	_box(Vector3(0.14, 0.06, fw + 0.12), Vector3(x, WIN_Y1 + 0.03, fz), p)
	_box(Vector3(0.14, fh, 0.06), Vector3(x, fy, WIN_Z0 - 0.03), p)
	_box(Vector3(0.14, fh, 0.06), Vector3(x, fy, WIN_Z1 + 0.03), p)
	_box(Vector3(0.05, fh, 0.04), Vector3(x - 0.02, fy, fz), p)
	_box(Vector3(0.05, 0.04, fw), Vector3(x - 0.02, fy + 0.08, fz), p)
	_box(Vector3(0.26, 0.035, fw + 0.32), Vector3(x + 0.1, WIN_Y0 - 0.02, fz), mats.wood)
	window_glass_mat = ShaderMaterial.new()
	window_glass_mat.shader = load("res://shaders/rain_glass.gdshader")
	window_glass_mat.set_shader_parameter("glass_size", Vector2(fw, fh))
	var glass := _quad(Vector2(fw, fh), Vector3(x - 0.03, fy, fz), window_glass_mat, PI / 2.0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var look := _interactable("Regarder dehors", Vector3(0.1, fh, fw), Vector3(x, fy, fz))
	look.used.connect(func(_i: Interactable) -> void:
		if outside.someone_there:
			Game.hint("La pluie, le lampadaire. Et en face, à la fenêtre allumée, quelqu'un qui regarde par ici.", 4.5)
		else:
			Game.hint("La pluie, le lampadaire. La fenêtre d'en face est vide, maintenant.", 4.5))
	# rideaux (plis animés par un shader)
	var curtain := ShaderMaterial.new()
	curtain.shader = load("res://shaders/curtain.gdshader")
	for side in [-1.0, 1.0]:
		var pm := PlaneMesh.new()
		pm.orientation = PlaneMesh.FACE_Z
		pm.size = Vector2(0.5, fh + 0.5)
		pm.subdivide_width = 28
		pm.subdivide_depth = 6
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = curtain
		mi.position = Vector3(x + 0.17, fy + 0.12, fz + side * (fw / 2.0 + 0.12))
		mi.rotation.y = PI / 2.0
		add_child(mi)
	_box(Vector3(0.03, 0.03, fw + 0.8), Vector3(x + 0.17, WIN_Y1 + 0.36, fz), mats.metal)
	# radiateur sous la fenêtre
	for i in 9:
		_box(Vector3(0.07, 0.52, 0.06), Vector3(x + 0.13, 0.48, fz - 0.4 + i * 0.1), mats.paint)
	_box(Vector3(0.04, 0.04, 1.0), Vector3(x + 0.13, 0.76, fz), mats.paint)
	_collider(Vector3(0.2, 0.6, 1.0), Vector3(x + 0.13, 0.4, fz))


# ------------------------------------------------------------------ meubles

func _build_furniture() -> void:
	# bureau (mur du fond) : l'ordinateur est posé dessus dans _build_pc
	var desk := prop("desk", Vector3(1.25, 0, -2.25), 0.0, Vector3(1.45, 0.76, 0.7))
	desk_top = (desk.get_meta("size") as Vector3).y
	prop("computerKeyboard", Vector3(pc_x, desk_top, -2.0), 0.0, Vector3(0.44, 0, 0), false)
	prop("computerMouse", Vector3(1.62, desk_top, -2.02), -8.0, Vector3(0.065, 0, 0), false)
	prop("books", Vector3(0.68, desk_top, -2.08), -14.0, Vector3(0.26, 0, 0), false)
	prop("lampRoundTable", Vector3(0.6, desk_top, -2.42), 20.0, Vector3(0, 0.4, 0), false)
	chair = prop("chairDesk", seat_pos, 180.0, Vector3(0.56, 0.95, 0.56), true, {"carpet": Color(0.08, 0.09, 0.12)})
	prop("trashcan", Vector3(0.32, 0, -2.32), 0.0, Vector3(0, 0.36, 0))
	var speaker := prop("speaker", Vector3(2.12, 0, -2.38), 0.0, Vector3(0, 0.78, 0))
	var radio := prop("radio", Vector3(2.12, (speaker.get_meta("size") as Vector3).y, -2.38), 0.0, Vector3(0.36, 0, 0), false, {}, "Allumer la radio")
	radio.get_meta("interactable").used.connect(_on_radio)
	var shelf := prop("bookcaseOpen", Vector3(2.78, 0, -2.36), 0.0, Vector3(0.75, 1.8, 0.4))
	prop("televisionVintage", Vector3(2.78, (shelf.get_meta("size") as Vector3).y, -2.36), 0.0, Vector3(0.48, 0, 0), false)

	# lit (mur de gauche, tête vers la fenêtre), chevet, réveil, nounours
	var bed := prop("bedSingle", Vector3(-2.65, 0, 1.58), 0.0, Vector3(1.05, 0.55, 2.0), true,
		{"carpet": Color(0.24, 0.12, 0.15), "carpetwhite": Color(0.52, 0.5, 0.46)}, "Se coucher")
	bed.get_meta("interactable").used.connect(func(_i: Interactable) -> void:
		Game.hint("Pas maintenant. Tu n'as pas sommeil. Tu n'auras plus jamais sommeil."))
	_build_duvet(bed)
	prop("bear", Vector3(-2.35, 0.55, 2.25), -110.0, Vector3(0, 0.34, 0), false)
	var night := prop("cabinetBedDrawerTable", Vector3(-2.92, 0, 0.3), 90.0, Vector3(0.48, 0.55, 0.42))
	_build_clock(Vector3(-2.95, (night.get_meta("size") as Vector3).y, 0.32))

	# armoire (coin du fond à gauche) : la disquette est dedans
	var wardrobe := prop("bookcaseClosedDoors", Vector3(-2.55, 0, -2.3), 0.0, Vector3(1.0, 2.05, 0.55), true, {}, "Ouvrir l'armoire")
	wardrobe.get_meta("interactable").used.connect(_on_wardrobe)
	for n in wardrobe.find_children("door*", "Node3D", true, false):
		wardrobe_doors.append(n as Node3D)
	_box(Vector3(0.86, 0.02, 0.45), Vector3(-2.55, 1.02, -2.3), mats.wood_dark)
	_build_floppy(Vector3(-2.42, 1.035, -2.22))

	# porte (mur de droite), fermée
	_build_door(Vector3(W / 2.0, 0, 1.4))

	# commode, photo encadrée (visages rayés), linge par terre
	var dresser := prop("sideTableDrawers", Vector3(0.75, 0, 2.36), 180.0, Vector3(1.1, 0.8, 0.45))
	var dtop := (dresser.get_meta("size") as Vector3).y
	_build_photo(Vector3(0.95, dtop, 2.42))
	prop("plantSmall1", Vector3(0.38, dtop, 2.4), 0.0, Vector3(0, 0.26, 0), false)
	prop("pillowLong", Vector3(1.6, 0.0, 1.9), 64.0, Vector3(0.55, 0, 0), false, {"carpet": Color(0.17, 0.2, 0.27)})
	# le reste
	prop("coatRackStanding", Vector3(2.82, 0, 2.25), 0.0, Vector3(0, 1.75, 0))
	prop("lampRoundFloor", Vector3(-1.45, 0, 2.32), 0.0, Vector3(0, 1.55, 0))
	prop("cardboardBoxOpen", Vector3(-1.5, 0, -2.3), 18.0, Vector3(0, 0.42, 0))
	prop("cardboardBoxClosed", Vector3(-1.05, 0, -2.36), -9.0, Vector3(0, 0.36, 0))
	prop("plantSmall2", Vector3(-W / 2.0 + 0.12, WIN_Y0, WIN_Z0 + 0.25), 0.0, Vector3(0, 0.3, 0), false)
	prop("rugRectangle", Vector3(0.1, 0.004, 0.5), 0.0, Vector3(2.4, 0.01, 1.5), false,
		{"carpet": Color(0.27, 0.11, 0.12), "carpetdarker": Color(0.14, 0.06, 0.07)})
	var lamp := prop("lampSquareCeiling", Vector3(0.15, H - 0.38, 0.45), 0.0, Vector3(0, 0.38, 0), false)
	lamp.position.y = H - (lamp.get_meta("size") as Vector3).y


## La porte de la chambre : fermée à clé de l'extérieur (par Albert) jusqu'à ce que la clé glisse dessous.
func _build_door(_at: Vector3) -> void:
	door_node = door("z", Vector3(W / 2.0 + 0.05, 0.0, DOOR_Z), 1.0, true, 0.1)
	door_node.name = "DoorP1"
	door_node.locked = true
	door_node.key_id = "cle_chambre"
	door_node.locked_msg = "Fermée. De l'extérieur."
	door_node.key_msg = "La clé de Papi tourne dans la serrure."
	door_leaf = door_node.leaf


## Couette froissée qui recouvre le lit et retombe sur les côtés (maillage généré).
func _build_duvet(bed: Node3D) -> void:
	var cover := bed.find_child("cover", true, false) as Node3D
	var box := _aabb_of(cover if cover else bed, self)
	var top := box.end.y
	var cx := box.get_center().x
	var w := box.size.x
	var hang := 0.3
	var zs := box.position.z + box.size.z * 0.24
	var ze := box.end.z + 0.03
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.frequency = 1.6
	var nx := 30
	var nz := 34
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var s := lerpf(-w / 2.0 - hang, w / 2.0 + hang, float(i) / nx)
			var z := lerpf(zs, ze, float(j) / nz)
			var over := absf(s) - w / 2.0
			var x := cx + s
			var y := top + 0.045
			if over > 0.0:
				x = cx + signf(s) * (w / 2.0 + 0.025 + over * 0.12)
				y = top + 0.045 - over * 1.05
			y += noise.get_noise_2d(s * 1.3, z * 1.3) * 0.04
			if j < 3:
				y += 0.03 * (3 - j) / 3.0
			x += noise.get_noise_2d(z * 4.0, s * 4.0) * 0.008
			st.set_uv(Vector2(float(i) / nx * 3.0, float(j) / nz * 4.0))
			st.add_vertex(Vector3(x, y, z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _grimy(_plain(Color(0.3, 0.13, 0.14), 1.0), 0.8)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)


func _build_clock(top: Vector3) -> void:
	_box(Vector3(0.09, 0.08, 0.2), top + Vector3(0, 0.04, 0), mats.black_plastic)
	var lbl := Label3D.new()
	lbl.text = "3:12"
	lbl.font = Game.fonts.pixel
	lbl.font_size = 64
	lbl.pixel_size = 0.0011
	lbl.modulate = Color(4.0, 0.35, 0.2)
	lbl.shaded = false
	lbl.outline_size = 0
	lbl.position = top + Vector3(0.047, 0.04, 0)
	lbl.rotation.y = PI / 2.0
	add_child(lbl)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.15, 0.08)
	glow.light_energy = 0.25
	glow.omni_range = 0.6
	glow.position = top + Vector3(0.15, 0.05, 0)
	add_child(glow)
	var blink := Timer.new()
	blink.wait_time = 1.0
	blink.autostart = true
	blink.timeout.connect(func() -> void: lbl.text = "3 12" if lbl.text == "3:12" else "3:12")
	add_child(blink)
	var it := _interactable("Regarder le réveil", Vector3(0.12, 0.1, 0.22), top + Vector3(0, 0.05, 0))
	it.used.connect(func(_i: Interactable) -> void: Game.hint("3:12. Il est 3:12 depuis que tu es entré."))


func _build_photo(base: Vector3) -> void:
	var frame := Node3D.new()
	frame.position = base
	frame.rotation = Vector3(-0.18, PI + 0.12, 0)
	add_child(frame)
	_box(Vector3(0.27, 0.21, 0.012), Vector3(0, 0.105, 0), mats.wood_dark, false, frame)
	var pic := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.18)
	pic.mesh = q
	pic.material_override = _image_mat("photo.png", 0.4)
	pic.position = Vector3(0, 0.105, 0.0065)
	frame.add_child(pic)
	var it := _interactable("Regarder la photo", Vector3(0.3, 0.26, 0.12), base + Vector3(0, 0.12, 0))
	it.used.connect(func(_i: Interactable) -> void:
		Game.hint("Toi et ta mère, devant l'ancienne maison. Tu ne te souviens pas d'avoir rayé vos visages."))


func _build_floppy(pos: Vector3) -> void:
	floppy = Node3D.new()
	floppy.position = pos
	floppy.rotation.y = 0.35
	add_child(floppy)
	_box(Vector3(0.09, 0.0035, 0.09), Vector3.ZERO, mats.dark, false, floppy)
	var label := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.072, 0.027)
	label.mesh = q
	label.material_override = _image_mat("floppy_label.png")
	label.rotation.x = -PI / 2.0
	label.position = Vector3(0, 0.0019, -0.028)
	floppy.add_child(label)
	_box(Vector3(0.03, 0.0038, 0.018), Vector3(0, 0, 0.036), mats.metal, false, floppy)
	floppy_item = _interactable("Prendre la disquette", Vector3(0.5, 0.32, 0.42), Vector3(-2.55, pos.y + 0.12, -1.86))
	floppy_item.enabled = false
	floppy_item.used.connect(_on_floppy)


# ------------------------------------------------------------------ l'ordinateur

func _build_pc() -> void:
	var x := pc_x
	var z := pc_z
	var base := desk_top
	# unité centrale beige, fente de disquette, voyant
	_box(Vector3(0.52, 0.13, 0.44), Vector3(x, base + 0.065, z), mats.beige)
	_box(Vector3(0.2, 0.012, 0.01), Vector3(x - 0.09, base + 0.075, z + 0.221), mats.dark)
	_box(Vector3(0.05, 0.02, 0.01), Vector3(x + 0.17, base + 0.06, z + 0.221), mats.dark)
	led_mat = _plain(Color(0.15, 0.1, 0.03), 0.4)
	_box(Vector3(0.016, 0.01, 0.006), Vector3(x + 0.03, base + 0.075, z + 0.223), led_mat)
	# moniteur cathodique : coque avec un creux pour la dalle (CSG)
	var my := base + 0.13
	var csg := CSGCombiner3D.new()
	add_child(csg)
	var body := CSGBox3D.new()
	body.size = Vector3(0.46, 0.4, 0.3)
	body.position = Vector3(x, my + 0.2, z + 0.07)
	body.material = mats.beige
	csg.add_child(body)
	var back := CSGBox3D.new()
	back.size = Vector3(0.34, 0.31, 0.2)
	back.position = Vector3(x, my + 0.19, z - 0.15)
	back.material = mats.beige
	csg.add_child(back)
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(0.39, 0.3, 0.06)
	hole.position = Vector3(x, my + 0.215, z + 0.22)
	hole.material = mats.black_plastic
	csg.add_child(hole)
	# l'écran : le terminal est dessiné dans un SubViewport, puis affiché avec un shader de tube
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	terminal = (load("res://scripts/terminal.gd") as GDScript).new()
	vp.add_child(terminal)
	screen_mat = ShaderMaterial.new()
	screen_mat.shader = load("res://shaders/crt_screen.gdshader")
	screen_mat.set_shader_parameter("screen", vp.get_texture())
	terminal.screen_mat = screen_mat
	screen_center = Vector3(x, my + 0.215, z + 0.193)
	var screen := _quad(Vector2(0.38, 0.29), screen_center, screen_mat)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var it := _interactable("Insérer la disquette", Vector3(1.0, 0.8, 0.8), Vector3(x, base + 0.3, z + 0.2))
	it.used.connect(func(_i: Interactable) -> void:
		if Game.has_floppy:
			it.enabled = false
			pc_used.emit()
		else:
			Game.hint("L'écran clignote. Il attend quelque chose."))
	_collider(Vector3(0.52, 0.56, 0.6), Vector3(x, base + 0.28, z), self)
	var hum: Node = Sfx.loop("crt_hum", -30.0, screen_center, self)
	hum.set("max_distance", 6.0)


func insert_floppy() -> void:
	floppy.visible = true
	floppy.rotation = Vector3(0, 0, 0)
	var start := screen_center + Vector3(0.18, -0.25, 0.45)
	var slot := Vector3(pc_x - 0.09, desk_top + 0.075, pc_z + 0.28)
	floppy.position = start
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(floppy, "position", slot, 0.9)
	tw.tween_property(floppy, "position", slot + Vector3(0, 0, -0.12), 0.35)
	await tw.finished
	floppy.visible = false
	Sfx.play_at("metalClick", slot, -6.0, 0.8)
	led_mat.albedo_color = Color(1, 0.7, 0.18)
	led_mat.emission_enabled = true
	led_mat.emission = Color(1, 0.65, 0.15)
	led_mat.emission_energy_multiplier = 3.0
	Sfx.play_at("drive_seek", slot, -4.0)
	await get_tree().create_timer(1.2).timeout


# ------------------------------------------------------------------ murs : affiches, mot, interrupteur

func _build_wall_things() -> void:
	var back := -D / 2.0 + 0.006
	_quad(Vector2(0.62, 0.89), Vector3(-0.55, 1.55, back), _image_mat("poster_choisis.png"))
	var note := _quad(Vector2(0.22, 0.275), Vector3(0.42, 1.42, back + 0.001), _image_mat("note.png"))
	note.rotation.z = 0.06
	var nit := _interactable("Lire le mot", Vector3(0.26, 0.31, 0.05), Vector3(0.42, 1.42, back + 0.02))
	nit.used.connect(func(_i: Interactable) -> void: get_tree().call_group("hud", "read_paper",
		"ne pas jouer\naprès minuit.\n\nsi l'écran te parle,\nne réponds pas.\n\n— M."))
	_quad(Vector2(0.55, 0.55), Vector3(W / 2.0 - 0.006, 1.62, -0.9), _image_mat("poster_spectres.png"), -PI / 2.0)
	# interrupteur
	var sw_pos := Vector3(W / 2.0 - 0.01, 1.25, 0.72)
	_box(Vector3(0.015, 0.11, 0.075), sw_pos, mats.paint)
	_box(Vector3(0.012, 0.04, 0.025), sw_pos + Vector3(-0.012, 0, 0), mats.paint)
	var sw := _interactable("Allumer la lumière", Vector3(0.08, 0.16, 0.12), sw_pos, self, LAYER_INTERACT, 1.8)
	sw.used.connect(_on_switch)


# ------------------------------------------------------------------ lumières, poussière

func _build_lights() -> void:
	# clair de lune : vient de dehors, traverse la vitre et dessine les croisillons au sol
	moon = SpotLight3D.new()
	moon.light_color = Color(0.55, 0.66, 0.92)
	moon.light_energy = 3.0
	moon.light_volumetric_fog_energy = 1.0
	moon.spot_range = 16.0
	moon.spot_angle = 20.0
	moon.spot_attenuation = 0.6
	moon.shadow_enabled = true
	moon.shadow_bias = 0.03
	add_child(moon)
	moon.global_position = Vector3(-7.0, 3.6, -0.35)
	moon.look_at(Vector3(-1.2, 0.0, 0.55))
	# lueur verte de l'écran
	screen_light = OmniLight3D.new()
	screen_light.light_color = Color(0.36, 1.0, 0.42)
	screen_light.light_energy = 0.32
	screen_light.light_volumetric_fog_energy = 0.12
	screen_light.omni_range = 2.5
	screen_light.omni_attenuation = 1.8
	screen_light.shadow_enabled = true
	add_child(screen_light)
	screen_light.global_position = screen_center + Vector3(0, 0.12, 0.7)
	# plafonnier, éteint
	ceiling_light = OmniLight3D.new()
	ceiling_light.light_color = Color(1.0, 0.82, 0.58)
	ceiling_light.light_energy = 0.0
	ceiling_light.omni_range = 7.0
	ceiling_light.shadow_enabled = true
	add_child(ceiling_light)
	ceiling_light.global_position = Vector3(0.15, H - 0.45, 0.45)


func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 260
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(Vector3(-W / 2.0, 0, -D / 2.0), Vector3(W, H, D))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(W / 2.0, H / 2.0, D / 2.0)
	pm.gravity = Vector3(0, -0.004, 0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.005
	pm.initial_velocity_max = 0.03
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_speed_random = 0.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.007, 0.007)
	var dm := StandardMaterial3D.new()
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(1, 0.95, 0.85, 0.6)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.proximity_fade_enabled = true
	dm.proximity_fade_distance = 0.3
	dm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	dm.distance_fade_min_distance = 0.25
	dm.distance_fade_max_distance = 1.1
	q.material = dm
	p.draw_pass_1 = q
	p.position = Vector3(0, H / 2.0, 0)
	add_child(p)


# ------------------------------------------------------------------ actions

func _on_wardrobe(it: Interactable) -> void:
	if wardrobe_open:
		if not Game.has_floppy:
			return
		Game.hint("Rien d'autre. Juste l'odeur.")
		return
	wardrobe_open = true
	it.label = "Fouiller l'armoire"
	var c := (props["bookcaseClosedDoors"] as Node3D).global_position + Vector3(0, 1.2, 0.3)
	Sfx.play_at("creak", c, -2.0, 0.8)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for d in wardrobe_doors:
		var sign_ := -1.0 if String(d.name).to_lower().contains("left") else 1.0
		tw.tween_property(d, "rotation:y", sign_ * 1.85, 1.4)
	await tw.finished
	Sfx.play_at("metalLatch", c, -12.0)
	floppy_item.enabled = true
	Game.hint("Une disquette. Posée sur l'étagère, comme si elle t'attendait.")


func _on_floppy(_it: Interactable) -> void:
	floppy_item.enabled = false
	floppy.visible = false
	Game.has_floppy = true
	Sfx.play("handleSmallLeather", -8.0)
	floppy_taken.emit()


func _on_switch(it: Interactable) -> void:
	Sfx.play_at("metalClick", it.global_position, -8.0)
	if ceiling_dead:
		Game.hint("Plus rien. L'ampoule a éclaté.")
		return
	if ceiling_on:
		ceiling_on = false
		ceiling_light.light_energy = 0.0
		return
	ceiling_on = true
	it.enabled = false
	for k in 14:
		ceiling_light.light_energy = 2.4 if rng.randf() < 0.5 else 0.15
		await get_tree().create_timer(rng.randf_range(0.04, 0.16)).timeout
	ceiling_light.light_energy = 6.0
	await get_tree().create_timer(0.12).timeout
	ceiling_light.light_energy = 0.0
	ceiling_dead = true
	ceiling_on = false
	it.enabled = true
	Sfx.play_at("glass", ceiling_light.global_position, 0.0)
	Sfx.play_at("metal", ceiling_light.global_position, -10.0, 0.7)


func _on_radio(it: Interactable) -> void:
	Sfx.play_at("metalClick", it.global_position, -8.0)
	Sfx.play_at("cloth", it.global_position, -14.0, 0.6)
	Game.whisper("c'est toi. c'est toi. c'est toi.")
	Game.hint("Un souffle. Puis, très bas, quelqu'un répète ton nom.")


# ------------------------------------------------------------------ réactions pendant la séance

func door_center() -> Vector3:
	return Vector3(W / 2.0, 1.1, DOOR_Z)


## Trois coups à la porte (c'est Albert, mais on ne le sait pas encore).
func door_knock() -> void:
	var p := door_center()
	for k in 3:
		Sfx.play_at("thud", p, 2.0, 1.25 + 0.05 * k, 3.0)
		await get_tree().create_timer(0.48, false).timeout


func door_rattle() -> void:
	door_node.rattle()
	await get_tree().create_timer(0.4, false).timeout
	door_node.rattle()


func wardrobe_close_silent() -> void:
	for d in wardrobe_doors:
		d.rotation.y = 0.0


## L'armoire s'entrouvre lentement dans le dos du joueur.
func wardrobe_creak_open() -> void:
	var c := (props["bookcaseClosedDoors"] as Node3D).global_position + Vector3(0, 1.2, 0.3)
	Sfx.play_at("creak", c, 0.0, 0.62, 3.0)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for d in wardrobe_doors:
		var sign_ := -1.0 if String(d.name).to_lower().contains("left") else 1.0
		tw.tween_property(d, "rotation:y", sign_ * 0.55, 3.5)


## Le plafonnier s'allume tout seul, en grésillant (le champ de l'entité déborde).
func ceiling_flicker_on() -> void:
	if ceiling_dead:
		return
	ceiling_on = true
	Sfx.play_at("metalClick", ceiling_light.global_position, -6.0, 0.7)
	for k in 10:
		ceiling_light.light_energy = 1.6 if rng.randf() < 0.5 else 0.1
		await get_tree().create_timer(rng.randf_range(0.05, 0.2), false).timeout
	ceiling_light.light_energy = 0.9


## L'ampoule éclate : noir complet, sauf l'écran.
func ceiling_burst() -> void:
	if ceiling_dead:
		return
	ceiling_light.light_energy = 6.0
	await get_tree().create_timer(0.1, false).timeout
	ceiling_light.light_energy = 0.0
	ceiling_dead = true
	ceiling_on = false
	Sfx.play_at("glass", ceiling_light.global_position, 2.0)
	Sfx.play_at("metal", ceiling_light.global_position, -8.0, 0.7)


## Le seul vrai sursaut de l'acte I : le visage (celui du docteur Ferrand, copié par l'entité),
## à quelques centimètres, quand le joueur se retourne. Orbites vides, lumière par en dessous.
func face_scare(p: Node) -> void:
	var cam: Camera3D = p.camera
	var face: Node3D = (load("res://assets/models/face/LeePerrySmith.glb") as PackedScene).instantiate()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/models/face/Map-COL.jpg")
	mat.albedo_color = Color(0.55, 0.53, 0.5)
	mat.roughness = 0.7
	for mi in face.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	# orbites vides (repère du modèle scanné)
	var black := _plain(Color(0.0, 0.0, 0.0), 1.0)
	for ex in [-0.92, 0.92]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 0.7
		eye.mesh = sm
		eye.material_override = black
		eye.position = Vector3(ex, 1.95, 1.72)
		face.add_child(eye)
	var under := OmniLight3D.new()
	under.light_color = Color(1.0, 0.82, 0.75)
	under.omni_range = 12.0
	under.light_energy = 0.0
	face.add_child(under)
	under.position = Vector3(0, -3.0, 4.0)
	add_child(face)
	face.scale = Vector3.ONE * 0.034
	face.visible = false
	# le joueur se retourne d'un coup
	var from_yaw: float = p.yaw
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float) -> void: p.set_look(from_yaw + PI * 0.92 * k, 0.02), 0.0, 1.0, 0.3)
	await tw.finished
	var fwd := -cam.global_transform.basis.z
	face.global_position = cam.global_position + fwd * 0.5 + Vector3(0, -0.07, 0)
	face.look_at(cam.global_position + Vector3(0, -0.07, 0), Vector3.UP, true)
	face.visible = true
	Sfx.sting(0.0)
	var post := get_tree().get_first_node_in_group("retro")
	if post:
		post.material.set_shader_parameter("corruption", 1.0)
	var head: Node3D = p.head
	var base := head.position
	var t := 0.0
	while t < 1.0:
		face.global_position -= fwd * 0.006   # il avance
		under.light_energy = 3.0 if rng.randf() < 0.65 else 0.4
		if not ceiling_dead:
			ceiling_light.light_energy = 2.5 if rng.randf() < 0.5 else 0.2
		head.position = base + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * 0.012 * (1.0 - t)
		await get_tree().create_timer(0.04, false).timeout
		t += 0.04
	head.position = base
	face.visible = false
	if post:
		post.material.set_shader_parameter("corruption", 0.15)
	if not ceiling_dead:
		await ceiling_burst()
	face.queue_free()
	await get_tree().create_timer(1.2, false).timeout
	var back := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var y2: float = p.yaw
	back.tween_method(func(k: float) -> void: p.set_look(lerpf(y2, p.seat_yaw, k), lerpf(0.02, -0.05, k)), 0.0, 1.0, 1.4)
	await back.finished

## Fin de la séance : la clé de la chambre et un mot d'Albert glissent sous la porte.
func key_under_door() -> void:
	var at := Vector3(W / 2.0 - 0.32, 0.0, 1.32)
	Sfx.play_at("metalClick", at + Vector3(0, 0.1, 0), -2.0, 0.6, 3.0)
	Sfx.play_at("cloth", at + Vector3(0, 0.1, 0), -6.0, 1.3, 3.0)
	var holder := Node3D.new()
	holder.name = "KeyAndNote"
	add_child(holder)
	holder.position = at
	var paper := _quad(Vector2(0.15, 0.1), Vector3(-0.04, 0.003, 0.05), _image_mat("note.png"), 0.0, holder)
	paper.rotation = Vector3(-PI / 2.0, 0.3, 0)
	var key := _box(Vector3(0.06, 0.006, 0.022), Vector3(0.05, 0.004, -0.04), mats.metal, false, holder)
	key.rotation.y = 0.7
	var it := _interactable("Ramasser la clé et le mot", Vector3(0.4, 0.3, 0.4), Vector3(0, 0.15, 0), holder, LAYER_INTERACT, 2.6)
	it.used.connect(func(_i: Interactable) -> void:
		holder.queue_free()
		Sfx.play("handleSmallLeather", -8.0)
		Game.add_item("cle_chambre", "Clé de la chambre", "Glissée sous la porte par Papi.", "cle")
		Game.add_item("mot_albert", "Mot de Papi", "« N'ouvre à personne. Même pas à moi. »", "doc")
		get_tree().get_first_node_in_group("hud").read_paper("Ferme à clé de l'intérieur.\nN'ouvre à personne.\nMême pas à moi.\n\n— A.")
		Game.objective("Sors de la chambre"))
