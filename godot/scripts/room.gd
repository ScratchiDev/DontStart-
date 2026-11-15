extends HouseRoom
## La chambre, construite au lancement : murs texturés (ambientCG, CC0), meubles (Kenney, CC0)
## mis à l'échelle en mètres réels, fenêtre sur la nuit, ordinateur rétro, objets interactifs.
## Repère : x de -3.2 (fenêtre) à 3.2 (porte), z de -2.6 (bureau) à 2.6, y du sol (0) au plafond.

signal floppy_taken
signal pc_used
signal key_taken        # la clé et le mot d'Albert sont ramassés (début de l'acte II, point de passage C1)
signal pc_answered      # convocation : le joueur répond à l'ordinateur (séance 2, Acte2)

const W := 6.4
const D := 5.2
const H := 2.6

# fenêtre (mur de gauche)
const WIN_Z0 := -1.15
const WIN_Z1 := 0.25
const WIN_Y0 := 0.95
const WIN_Y1 := 2.2
const DOOR_Z := 1.4
## Convocation (§ 2.2, étape 13) : le chant du modem, repris tant qu'on n'a pas répondu.
const MODEM_EVERY := 22.0
const MODEM_DB := -3.0
const LABEL_ANSWER := "Répondre à l'ordinateur"
const LABEL_INSERT := "Insérer la disquette"
const EJECT_MSG := "Elle ne sort pas."
const MODEM_CAPTION := "[Chant de modem, dans la chambre de ta mère]"   # (texte à valider par l'auteur)

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
var pc_it: Interactable            # « Insérer la disquette »
var wardrobe_it: Interactable      # « Ouvrir l'armoire »
var rng := RandomNumberGenerator.new()
var window_glass_mat: ShaderMaterial
var outside: Node3D
var decor: Node3D
var pc_dev: Connected               # l'ordinateur, vu par l'entité comme un écran de la maison (« pc_manon »)
var eject_it: Interactable         # bouton d'éjection de la disquette : elle ne sort pas
var convoking := false             # convocation : le modem chante, l'écran clignote (convocation(on))
var modem_plays := 0               # chants du modem joués depuis le lancement (autotest)
var modem: AudioStreamPlayer3D     # le chant en cours (ou null)
var _modem_timer: Timer
var _blink_tw: Tween
var _screen_light_e := 0.32
var _bulb_mat: StandardMaterial3D     # ampoules du lustre : elles brillent avec le plafonnier
var _bulb_e := -1.0
var _tape_mat: StandardMaterial3D
var _furn_wood: StandardMaterial3D
var _brass_mat: StandardMaterial3D
var _key_mat: StandardMaterial3D


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
	# la fenêtre a été vissée (par Albert, en 2016)
	for sz in [WIN_Z0 + 0.05, WIN_Z1 - 0.05]:
		for sy in [WIN_Y0 + 0.06, WIN_Y1 - 0.06]:
			_box(Vector3(0.012, 0.014, 0.014), Vector3(x + 0.075, sy, sz), mats.metal)
	var shut := _interactable("Ouvrir la fenêtre", Vector3(0.12, 0.3, fw), Vector3(x + 0.1, WIN_Y0 + 0.15, fz))
	shut.used.connect(func(_i: Interactable) -> void:
		Sfx.play_at("metalLatch", Vector3(x, WIN_Y0 + 0.2, fz), -6.0, 0.7)
		Game.hint("Vissée. Quatre grosses vis dans le cadre, rouillées. Par Papi, sans doute. Il y a longtemps."))
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
	_retint(desk)
	_dress_desk(desk)
	_build_keyboard(Vector3(pc_x, desk_top, -2.0))
	prop("computerMouse", Vector3(1.62, desk_top, -2.02), -8.0, Vector3(0.065, 0, 0), false)
	_hide_meshes(prop("books", Vector3(0.68, desk_top, -2.08), -14.0, Vector3(0.26, 0, 0), false))
	_book_stack(Vector3(0.68, desk_top, -2.08), deg_to_rad(-14.0))
	prop("lampRoundTable", Vector3(0.6, desk_top, -2.42), 20.0, Vector3(0, 0.4, 0), false)
	chair = prop("chairDesk", seat_pos, 180.0, Vector3(0.56, 0.95, 0.56), true, {"carpet": Color(0.08, 0.09, 0.12)})
	_build_bin(Vector3(0.32, 0, -2.32))
	# enceinte colonne (le pied de la radio : même hauteur que l'enceinte Kenney d'avant, 0,78 m)
	var stand_h := 0.78
	_build_hifi(Vector3(2.12, 0, -2.38), stand_h)
	var radio := prop("radio", Vector3(2.12, stand_h, -2.38), 0.0, Vector3(0.36, 0, 0), false, {}, "Allumer la radio")
	radio.get_meta("interactable").used.connect(_on_radio)
	_dress_radio(radio)
	var shelf := prop("bookcaseOpen", Vector3(2.78, 0, -2.36), 0.0, Vector3(0.75, 1.8, 0.4))
	_retint(shelf)
	_dress_bookcase(shelf)
	prop("televisionVintage", Vector3(2.78, (shelf.get_meta("size") as Vector3).y, -2.36), 0.0, Vector3(0.48, 0, 0), false)

	# lit (mur de gauche, tête vers la fenêtre), chevet, réveil, nounours
	var bed := prop("bedSingle", Vector3(-2.65, 0, 1.58), 0.0, Vector3(1.05, 0.55, 2.0), true,
		{"carpet": Color(0.24, 0.12, 0.15), "carpetwhite": Color(0.52, 0.5, 0.46)}, "Se coucher")
	bed.get_meta("interactable").used.connect(func(_i: Interactable) -> void:
		Game.hint("Pas maintenant. Tu n'as pas sommeil. Tu n'auras plus jamais sommeil."))
	_build_duvet(bed)
	_dress_bed(bed)
	_build_teddy(Vector3(-2.35, 0.43, 2.25), -110.0)
	var night := prop("cabinetBedDrawerTable", Vector3(-2.92, 0, 0.3), 90.0, Vector3(0.48, 0.55, 0.42))
	_build_clock(Vector3(-2.95, (night.get_meta("size") as Vector3).y, 0.32))

	# armoire (coin du fond à gauche) : la disquette est dedans
	var wardrobe := prop("bookcaseClosedDoors", Vector3(-2.55, 0, -2.3), 0.0, Vector3(1.0, 2.05, 0.55), true, {}, "Ouvrir l'armoire")
	wardrobe_it = wardrobe.get_meta("interactable")
	wardrobe_it.used.connect(_on_wardrobe)
	for n in wardrobe.find_children("door*", "Node3D", true, false):
		wardrobe_doors.append(n as Node3D)
	# l'étagère de la disquette, garnie d'un vieux papier d'étagère clair (la disquette noire s'y détache
	# dans le rond de la lampe de poche)
	_box(Vector3(0.86, 0.02, 0.45), Vector3(-2.55, 1.02, -2.3), _grimy(_plain(Color(0.6, 0.56, 0.47), 0.9), 1.5))
	_build_floppy(Vector3(-2.42, 1.035, -2.22))
	_dress_wardrobe(wardrobe)

	# porte (mur de droite), fermée
	_build_door(Vector3(W / 2.0, 0, 1.4))

	# commode (bois peint, Poly Haven), photo encadrée (visages rayés), linge par terre. Le dessus reste
	# à 0,80 m (la photo et son interaction sont posées dessus) ; dos contre le mur.
	var dresser := model("painted_wooden_cabinet", Vector3(0.75, 0, 2.38), 180.0, Vector3(0, 0.8, 0), true,
		{"fit": "y", "name": "sideTableDrawers"})
	var dtop := (dresser.get_meta("size") as Vector3).y
	_build_photo(Vector3(0.95, dtop, 2.42))
	prop("plantSmall1", Vector3(0.5, dtop, 2.42), 0.0, Vector3(0, 0.26, 0), false)
	# coussin tombé par terre (tissu tissé, comme les tapis) : gonflé au centre, cousu sur le pourtour
	var cushion := MeshInstance3D.new()
	cushion.name = "Coussin"
	cushion.mesh = pillow_mesh(0.42, 0.42, 0.12)
	cushion.material_override = _rug_mat(Color(0.26, 0.27, 0.32))
	cushion.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	cushion.position = Vector3(1.6, 0.05, 1.9)
	cushion.rotation = Vector3(0.0, deg_to_rad(64.0), 0.05)
	add_child(cushion)
	# le reste
	_build_coat_rack(Vector3(2.82, 0, 2.25))
	_build_floor_lamp(Vector3(-1.45, 0, 2.32))
	# cartons de déménagement (Poly Haven), contre le mur du fond
	model("cardboard_box_01", Vector3(-1.6, 0, -2.35), 101.0, Vector3.ZERO, true, {"name": "Carton1"})
	model("cardboard_box_01", Vector3(-1.07, 0, -2.4), 84.0, Vector3(0, 0.29, 0), true, {"name": "Carton2"})
	prop("plantSmall2", Vector3(-W / 2.0 + 0.12, WIN_Y0, WIN_Z0 + 0.25), 0.0, Vector3(0, 0.3, 0), false)
	prop("rugRectangle", Vector3(0.1, 0.004, 0.5), 0.0, Vector3(2.4, 0.01, 1.5), false,
		{"carpet": Color(0.27, 0.11, 0.12), "carpetdarker": Color(0.14, 0.06, 0.07)})
	# lustre (Poly Haven) : 0,5 m de haut (0,38 le rendait minuscule), le bas à 2,10 m du sol
	var lamp := prop("lampSquareCeiling", Vector3(0.15, H - 0.5, 0.45), 0.0, Vector3(0, 0.5, 0), false)
	lamp.position.y = H - (lamp.get_meta("size") as Vector3).y
	_bulbs_glow(lamp)


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
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	# couvre-lit en laine tissée (la matière des tapis) ; faces avant vers le haut et vers l'extérieur
	mi.material_override = _rug_mat(Color(0.3, 0.13, 0.14))
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
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
	it.used.connect(func(_i: Interactable) -> void: Game.hint("3:12. Il clignote, comme s'il venait de se rallumer après une coupure."))


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
		Game.hint("Ta mère à seize ans, assise à ce bureau. Derrière elle, l'écran est allumé. Son visage est rayé au stylo."))


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


# ------------------------------------------------------------------ habillage : meubles et objets réalistes
# (purement décoratif : aucun objet interactif, aucune boîte d'interaction ni position utilisée par le jeu
# ne change ; les collisions restent à la place des meubles Kenney qu'elles remplacent)

## Pièces de décor fondues en un seul maillage (un seul appel de dessin) : [maillage, Transform3D]. Hors
## de la cuisson VoxelGI (sauf gi), comme les modèles Poly Haven : la lumière rebondie les éclaire quand même.
func _merged(parts: Array, mat: Material, parent: Node3D, gi := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	for p in parts:
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if not gi:
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


func _bm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cm(r_top: float, r_bot: float, h: float, seg := 24, cap_top := true, cap_bottom := true, flip := false) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = cap_top
	c.cap_bottom = cap_bottom
	c.flip_faces = flip
	return c


func _sm(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 3)
	return s


static func _at(pos: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)


## Tige (cylindre) de a à b, de rayon r : [maillage, Transform3D] pour _merged.
func _rod(a: Vector3, b: Vector3, r: float, seg := 8) -> Array:
	var v := b - a
	return [_cm(r, r, v.length(), seg), Transform3D(Basis(Quaternion(Vector3.UP, v.normalized())), (a + b) / 2.0)]


## L'armoire de la disquette (Kenney, gardée : ses portes s'ouvrent, sa boîte d'interaction et l'étagère de
## la disquette sont réglées sur elle) habillée en armoire de campagne : bois sombre ciré, portes à
## panneaux moulurés (enfants des portes : ils tournent avec elles), corniche, ceinture, côté mouluré,
## ferrures en laiton, et une vieille valise posée dessus. Rien ne change pour le jeu.
func _dress_wardrobe(wardrobe: Node3D) -> void:
	var wood := (mats.wood_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
	wood.albedo_color = Color(0.6, 0.47, 0.38)
	var brass := _brass()
	var inst: Node3D = null
	for c in wardrobe.get_children():
		if not (c is Interactable):
			inst = c as Node3D
	for n in wardrobe.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var metal := src != null and src.resource_name.to_lower().begins_with("metal")
			mi.set_surface_override_material(i, brass if metal else wood)
	if inst == null:
		return
	var s := inst.scale
	# portes : deux panneaux moulurés chacune, dans le repère de la porte (un nœud qui défait l'échelle
	# du modèle : on y travaille en mètres ; la face avant de la porte est en z = 0)
	for d in wardrobe_doors:
		var dm := d as MeshInstance3D
		if dm == null:
			continue
		var ab := dm.get_aabb()
		var x0 := ab.position.x * s.x
		var x1 := ab.end.x * s.x
		var h := ab.size.y * s.y
		var holder := Node3D.new()
		holder.name = "Moulures"
		holder.scale = Vector3(1.0 / s.x, 1.0 / s.y, 1.0 / s.z)
		d.add_child(holder)
		var parts := []
		var cx := (x0 + x1) / 2.0
		var pw := (x1 - x0) - 0.12
		# panneau bas, panneau haut (la poignée Kenney, à 0,67-0,81 m du bas de la porte, reste entre les deux)
		for r in [[0.09, 0.6], [0.88, h - 0.09]]:
			var y0: float = r[0]
			var y1: float = r[1]
			var ph := y1 - y0
			var cy := (y0 + y1) / 2.0
			var fw := 0.024      # largeur de la moulure
			parts.append([_bm(Vector3(pw, fw, 0.016)), _at(Vector3(cx, y1 - fw / 2.0, 0.008))])
			parts.append([_bm(Vector3(pw, fw, 0.016)), _at(Vector3(cx, y0 + fw / 2.0, 0.008))])
			parts.append([_bm(Vector3(fw, ph - 2.0 * fw, 0.016)), _at(Vector3(cx - pw / 2.0 + fw / 2.0, cy, 0.008))])
			parts.append([_bm(Vector3(fw, ph - 2.0 * fw, 0.016)), _at(Vector3(cx + pw / 2.0 - fw / 2.0, cy, 0.008))])
			# le panneau, en relief à l'intérieur du cadre (une gorge de 1,6 cm tout autour)
			parts.append([_bm(Vector3(pw - 2.0 * fw - 0.032, ph - 2.0 * fw - 0.032, 0.009)), _at(Vector3(cx, cy, 0.0045))])
		_merged(parts, wood, holder)
	# caisse : corniche, ceinture sous les portes, côté visible mouluré (repère du meuble, en mètres)
	var size: Vector3 = wardrobe.get_meta("size")
	var fz := size.z / 2.0           # face avant
	var bz := -size.z / 2.0          # dos (contre le mur)
	var top := size.y
	var cp := []
	cp.append([_bm(Vector3(size.x + 0.02, 0.02, size.z + 0.01)), _at(Vector3(0, top - 0.01, 0.005))])
	cp.append([_bm(Vector3(size.x + 0.05, 0.06, size.z + 0.025)), _at(Vector3(0, top + 0.03, (fz + 0.025 + bz) / 2.0))])
	cp.append([_bm(Vector3(size.x + 0.1, 0.035, size.z + 0.05)), _at(Vector3(0, top + 0.0775, (fz + 0.05 + bz) / 2.0))])
	cp.append([_bm(Vector3(size.x + 0.02, 0.06, 0.022)), _at(Vector3(0, 0.24, fz + 0.011))])
	for sx in [-1.0, 1.0]:
		var xf: float = sx * (size.x / 2.0 + 0.008)
		cp.append([_bm(Vector3(0.016, 1.56, 0.024)), _at(Vector3(xf, 1.16, bz + 0.07))])
		cp.append([_bm(Vector3(0.016, 1.56, 0.024)), _at(Vector3(xf, 1.16, fz - 0.07))])
		cp.append([_bm(Vector3(0.016, 0.024, size.z - 0.164)), _at(Vector3(xf, 1.928, 0.0))])
		cp.append([_bm(Vector3(0.016, 0.024, size.z - 0.164)), _at(Vector3(xf, 0.392, 0.0))])
	_merged(cp, wood, wardrobe)
	# une vieille valise, couchée sur la corniche (une des deux du modèle Poly Haven)
	var case_ := _ph_instance("vintage_suitcase", {}) if ResourceLoader.exists(PH_PATH % ["vintage_suitcase", "vintage_suitcase"]) else null
	if case_ == null:
		return
	for n in case_.get_children():
		if String(n.name).contains("_02"):
			n.free()
	for g in case_.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var lay := Node3D.new()
	lay.name = "Valise"
	wardrobe.add_child(lay)
	lay.add_child(case_)
	case_.rotation.x = PI / 2.0      # couchée sur le dos, la poignée vers la pièce
	var box := _aabb_in(case_, case_.transform)
	case_.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	lay.position = Vector3(0.03, top + 0.095, -0.02)
	lay.rotation.y = deg_to_rad(-7.0)


## Bois des meubles Kenney gardés (bureau, étagère) : noyer foncé ciré plutôt que le bois clair des
## Kenney ; leurs poignées en laiton.
func _retint(node: Node3D) -> void:
	if _furn_wood == null:
		_furn_wood = (mats.wood_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
		_furn_wood.albedo_color = Color(0.68, 0.53, 0.43)
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name.to_lower() if src else ""
			if key.begins_with("wood"):
				mi.set_surface_override_material(i, _furn_wood)
			elif key.begins_with("metal"):
				mi.set_surface_override_material(i, _brass())


func _brass() -> StandardMaterial3D:
	if _brass_mat == null:
		_brass_mat = _plain(Color(0.5, 0.38, 0.18), 0.32, 0.9)
	return _brass_mat


## La bibliothèque ouverte (Kenney : montants carrés et planches épaisses) redessinée en noyer : côtés
## fins, fond, tablettes à chant mouluré aux hauteurs du Kenney (0,27 · 0,76 · 1,25 : decor.gd y range
## les livres et les cassettes), socle en retrait, dessus à 1,80 m (la télévision y est posée), bandeau.
func _dress_bookcase(shelf: Node3D) -> void:
	var size: Vector3 = shelf.get_meta("size")
	var c := shelf.position
	var w := size.x
	var hh := size.y
	var d := size.z
	var t := 0.022
	var zf := c.z + d / 2.0           # façade (+z)
	var zb := c.z - d / 2.0           # dos
	var wi := w - 2.0 * t
	var parts := []
	for sx in [-1.0, 1.0]:
		parts.append([_bm(Vector3(t, hh, d)), Transform3D(Basis(), Vector3(c.x + sx * (w / 2.0 - t / 2.0), hh / 2.0, c.z))])
		parts.append([_bm(Vector3(0.035, hh - 0.09, 0.018)), Transform3D(Basis(), Vector3(c.x + sx * (w / 2.0 - 0.0175), 0.09 + (hh - 0.09) / 2.0, zf - 0.006))])
	parts.append([_bm(Vector3(wi, hh - 0.03, 0.01)), Transform3D(Basis(), Vector3(c.x, hh / 2.0, zb + 0.008))])
	# socle en retrait, fond bas
	parts.append([_bm(Vector3(wi, 0.075, 0.02)), Transform3D(Basis(), Vector3(c.x, 0.0375, zf - 0.03))])
	parts.append([_bm(Vector3(wi, 0.02, d - 0.03)), Transform3D(Basis(), Vector3(c.x, 0.085, c.z))])
	var levels := [0.27, 0.76, 1.25]
	for y in levels:
		parts.append([_bm(Vector3(wi, 0.02, d - 0.025)), Transform3D(Basis(), Vector3(c.x, y - 0.01, c.z - 0.005))])
		parts.append([_bm(Vector3(wi, 0.032, 0.016)), Transform3D(Basis(), Vector3(c.x, y - 0.016, zf - 0.012))])
	# dessus (à fleur de 1,80 m), bandeau et moulure sous le dessus
	parts.append([_bm(Vector3(w + 0.016, 0.024, d + 0.012)), Transform3D(Basis(), Vector3(c.x, hh - 0.012, c.z + 0.006))])
	parts.append([_bm(Vector3(wi, 0.05, 0.018)), Transform3D(Basis(), Vector3(c.x, hh - 0.049, zf - 0.008))])
	parts.append([_bm(Vector3(w + 0.03, 0.016, d + 0.02)), Transform3D(Basis(), Vector3(c.x, hh - 0.032, c.z + 0.01))])
	_merged(parts, _furn_wood, self, true).name = "BibliothequeNoyer"
	_hide_meshes(shelf)


## Le bureau (Kenney : pieds-blocs) redessiné en bureau de noyer : plateau à desk_top (le PC et le
## clavier y sont posés), ceinture, deux tiroirs à boutons de laiton, pieds fuselés. Même emprise, même
## collision (celle du Kenney).
func _dress_desk(desk: Node3D) -> void:
	var size: Vector3 = desk.get_meta("size")
	var c := desk.position
	var w := size.x
	var d := size.z
	var top := size.y
	var parts := []
	parts.append([_bm(Vector3(w, 0.03, d)), Transform3D(Basis(), Vector3(c.x, top - 0.015, c.z))])
	# ceinture (dos, côtés, façade) sous le plateau
	var ay := top - 0.03 - 0.055
	parts.append([_bm(Vector3(w - 0.08, 0.11, 0.02)), Transform3D(Basis(), Vector3(c.x, ay, c.z - d / 2.0 + 0.05))])
	for sx in [-1.0, 1.0]:
		parts.append([_bm(Vector3(0.02, 0.11, d - 0.1)), Transform3D(Basis(), Vector3(c.x + sx * (w / 2.0 - 0.05), ay, c.z))])
	parts.append([_bm(Vector3(w - 0.08, 0.11, 0.02)), Transform3D(Basis(), Vector3(c.x, ay, c.z + d / 2.0 - 0.05))])
	# pieds fuselés (section carrée : cylindres à 4 côtés tournés de 45°)
	var leg := _cm(0.026, 0.017, top - 0.03, 4)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			parts.append([leg, Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(c.x + sx * (w / 2.0 - 0.055), (top - 0.03) / 2.0, c.z + sz * (d / 2.0 - 0.055)))])
	_merged(parts, _furn_wood, self, true).name = "BureauNoyer"
	# deux tiroirs dans la ceinture, de part et d'autre de la place des genoux
	var dark := _furn_wood.duplicate() as StandardMaterial3D
	dark.albedo_color = _furn_wood.albedo_color.darkened(0.25)
	var fronts := []
	var knobs := []
	for sx in [-1.0, 1.0]:
		var dx: float = c.x + sx * (w / 2.0 - 0.27)
		fronts.append([_bm(Vector3(0.36, 0.085, 0.008)), Transform3D(Basis(), Vector3(dx, ay, c.z + d / 2.0 - 0.036))])
		knobs.append([_sm(0.011, 10), Transform3D(Basis(), Vector3(dx, ay, c.z + d / 2.0 - 0.026))])
	_merged(fronts, dark, self)
	_merged(knobs, _brass(), self)
	_hide_meshes(desk)


## Trois livres empilés sur le bureau (à la place des pavés Kenney « books ») : reliures, pages.
func _book_stack(at: Vector3, rot_y: float) -> void:
	var holder := Node3D.new()
	holder.name = "LivresBureau"
	holder.position = at
	holder.rotation.y = rot_y
	add_child(holder)
	var covers := [Color(0.3, 0.1, 0.09), Color(0.12, 0.18, 0.26), Color(0.2, 0.24, 0.15)]
	var dims := [Vector3(0.18, 0.035, 0.25), Vector3(0.16, 0.028, 0.23), Vector3(0.15, 0.04, 0.21)]
	var pages := _plain(Color(0.8, 0.76, 0.66), 0.9)
	var y := 0.0
	for k in 3:
		var sz: Vector3 = dims[k]
		var bk := Node3D.new()
		bk.position = Vector3(0.01 * k, y, -0.01 * k)
		bk.rotation.y = [0.0, 0.12, -0.08][k]
		holder.add_child(bk)
		var cover := _plain(covers[k], 0.7)
		for yb in [0.0015, sz.y - 0.0015]:
			_box(Vector3(sz.x, 0.003, sz.z), Vector3(0, yb, 0), cover, false, bk)
		_box(Vector3(0.005, sz.y, sz.z), Vector3(-sz.x / 2.0 + 0.0025, sz.y / 2.0, 0), cover, false, bk)
		_box(Vector3(sz.x - 0.009, sz.y - 0.006, sz.z - 0.008), Vector3(0.0005, sz.y / 2.0, 0), pages, false, bk)
		y += sz.y


## Le lit (objet interactif « Se coucher » : sa boîte et la couette restent réglées sur le Kenney) dessiné
## en lit de fer ancien : tête et pied à barreaux en fer peint noir, boules de laiton, sommier, matelas
## au drap blanc, oreiller. Le Kenney est caché (son nœud « cover » sert encore de repère à la couette).
func _dress_bed(bed: Node3D) -> void:
	var size: Vector3 = bed.get_meta("size")
	for c in bed.get_children():
		if not (c is Interactable):
			(c as Node3D).visible = false
	var hx := size.x / 2.0 - 0.025          # axe des montants
	var hz := size.z / 2.0 - 0.012
	var iron := _grimy(_plain(Color(0.055, 0.055, 0.06), 0.42, 0.55), 1.2)
	var parts := []
	var knobs := []
	# tête (vers -z, côté fenêtre) et pied : montants, traverses, barreaux
	for end in [[-hz, 1.02, 0.97, 0.56], [hz, 0.8, 0.75, 0.5]]:
		var z: float = end[0]
		var hp: float = end[1]
		var r_top: float = end[2]
		var r_mid: float = end[3]
		for sx in [-1.0, 1.0]:
			parts.append([_cm(0.019, 0.019, hp, 10), _at(Vector3(sx * hx, hp / 2.0, z))])
			knobs.append([_sm(0.03, 10), _at(Vector3(sx * hx, hp + 0.022, z))])
		for y in [r_top, r_mid, 0.26]:
			parts.append(_rod(Vector3(-hx, y, z), Vector3(hx, y, z), 0.012 if y != r_top else 0.015, 8))
		var n := 9
		for k in n:
			var x := lerpf(-hx, hx, float(k + 1) / float(n + 1))
			parts.append(_rod(Vector3(x, r_mid, z), Vector3(x, r_top, z), 0.0065, 6))
	# longerons
	for sx in [-1.0, 1.0]:
		parts.append([_bm(Vector3(0.03, 0.05, 2.0 * hz)), _at(Vector3(sx * hx, 0.255, 0))])
	var holder := Node3D.new()
	holder.name = "LitFer"
	bed.add_child(holder)
	_merged(parts, iron, holder)
	_merged(knobs, _brass(), holder)
	# sommier, matelas (drap blanc), oreiller
	_merged([[_bm(Vector3(2.0 * hx - 0.04, 0.03, 2.0 * hz - 0.04)), _at(Vector3(0, 0.235, 0))]], mats.dark, holder)
	var sheet := _grimy(_plain(Color(0.72, 0.7, 0.64), 1.0), 1.0)
	_merged([[_bm(Vector3(2.0 * hx - 0.05, 0.15, 2.0 * hz - 0.05)), _at(Vector3(0, 0.3, 0))]], sheet, holder)
	var pillow := MeshInstance3D.new()
	pillow.mesh = _sm(0.5, 16)
	pillow.material_override = sheet
	pillow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	pillow.position = Vector3(0.02, 0.43, -hz + 0.25)
	pillow.rotation = Vector3(-0.12, 0.05, 0.0)
	pillow.scale = Vector3(0.66, 0.13, 0.34)
	holder.add_child(pillow)


## Clavier beige de l'ordinateur (à la place du Kenney, même place, 0,44 m) : socle légèrement incliné,
## cinq rangées de touches et la barre d'espace.
func _build_keyboard(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Clavier"
	root.position = at
	add_child(root)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(3.0))
	_merged([[_bm(Vector3(0.44, 0.024, 0.17)), Transform3D(tilt, Vector3(0, 0.014, 0))]], mats.beige, root)
	var keys := []
	var pitch := 0.0255
	var key := _bm(Vector3(0.021, 0.011, 0.021))
	for r in 5:
		var n := 15 if r < 4 else 0
		var z := -0.06 + r * pitch
		var x0 := -0.19 + (r % 2) * 0.006
		for k in n:
			keys.append([key, Transform3D(tilt, tilt * Vector3(x0 + k * pitch, 0.031, z))])
	# rangée du bas : quelques touches et la barre d'espace
	var zb := -0.06 + 4 * pitch
	for x in [-0.19, -0.164, -0.138, 0.112, 0.138, 0.164, 0.19]:
		keys.append([key, Transform3D(tilt, tilt * Vector3(x, 0.031, zb))])
	keys.append([_bm(Vector3(0.2, 0.011, 0.021)), Transform3D(tilt, tilt * Vector3(-0.012, 0.031, zb))])
	if _key_mat == null:
		_key_mat = _grimy(_plain(Color(0.47, 0.45, 0.4), 0.55), 2.0)
	_merged(keys, _key_mat, root)


## Le nounours, assis sur la couette au pied du lit (sphères : peluche brune, museau clair, yeux et truffe).
func _build_teddy(at: Vector3, rot_deg: float) -> void:
	var root := Node3D.new()
	root.name = "Nounours"
	root.position = at
	root.rotation_degrees.y = rot_deg
	add_child(root)
	var ball := _sm(0.5, 14)
	var small := _sm(0.5, 8)
	var sc := func(v: Vector3, p: Vector3, r := Vector3.ZERO) -> Array:
		return [ball, Transform3D(Basis.from_euler(r).scaled_local(v), p)]
	var fur := [
		sc.call(Vector3(0.16, 0.19, 0.14), Vector3(0, 0.1, 0)),                       # ventre
		sc.call(Vector3(0.135, 0.125, 0.12), Vector3(0, 0.255, 0.01)),                # tête
		sc.call(Vector3(0.055, 0.055, 0.03), Vector3(-0.058, 0.32, 0.0)),             # oreilles
		sc.call(Vector3(0.055, 0.055, 0.03), Vector3(0.058, 0.32, 0.0)),
		sc.call(Vector3(0.05, 0.12, 0.05), Vector3(-0.085, 0.12, 0.035), Vector3(0.5, 0, 0.35)),   # bras
		sc.call(Vector3(0.05, 0.12, 0.05), Vector3(0.085, 0.12, 0.035), Vector3(0.5, 0, -0.35)),
		sc.call(Vector3(0.065, 0.06, 0.11), Vector3(-0.055, 0.03, 0.08)),             # jambes
		sc.call(Vector3(0.065, 0.06, 0.11), Vector3(0.055, 0.03, 0.08)),
	]
	_merged(fur, _grimy(_plain(Color(0.36, 0.25, 0.16), 1.0), 2.0), root)
	_merged([sc.call(Vector3(0.06, 0.048, 0.05), Vector3(0, 0.232, 0.066))], _grimy(_plain(Color(0.62, 0.5, 0.36), 1.0), 2.0), root)
	_merged([[small, Transform3D(Basis().scaled(Vector3(0.026, 0.018, 0.018)), Vector3(0, 0.247, 0.092))],
		[small, Transform3D(Basis().scaled(Vector3(0.016, 0.016, 0.016)), Vector3(-0.032, 0.272, 0.07))],
		[small, Transform3D(Basis().scaled(Vector3(0.016, 0.016, 0.016)), Vector3(0.032, 0.272, 0.07))]],
		_plain(Color(0.02, 0.02, 0.02), 0.3), root)


## La radio (objet interactif : sa boîte reste celle du modèle Kenney) : un radiocassette réaliste
## (Poly Haven) dessiné à sa place, dans la même boîte.
func _dress_radio(radio: Node3D) -> void:
	if not ResourceLoader.exists(PH_PATH % ["boombox", "boombox"]):
		return
	for c in radio.get_children():
		if not (c is Interactable):
			(c as Node3D).visible = false
	var box: Vector3 = radio.get_meta("size")
	model("boombox", Vector3.ZERO, 0.0, Vector3(box.x, box.y, 0.0), false, {"parent": radio, "name": "Radiocassette"})


## Enceinte colonne (le pied de la radio) : caisse en bois plaqué sur un socle en retrait, toile noire.
func _build_hifi(at: Vector3, h: float) -> void:
	var root := Node3D.new()
	root.name = "Enceinte"
	root.position = at
	add_child(root)
	var w := 0.28
	var d := 0.27
	var plinth := 0.025
	_merged([[_bm(Vector3(w, h - plinth, d)), _at(Vector3(0, plinth + (h - plinth) / 2.0, 0))]], mats.wood_dark, root)
	_merged([[_bm(Vector3(w - 0.03, plinth, d - 0.03)), _at(Vector3(0, plinth / 2.0, 0))]], mats.black_plastic, root)
	var cloth := _grimy(_plain(Color(0.035, 0.035, 0.04), 1.0), 1.6)
	_merged([[_bm(Vector3(w - 0.03, h - plinth - 0.05, 0.01)), _at(Vector3(0, plinth + (h - plinth) / 2.0, d / 2.0 + 0.004))]], cloth, root)
	_merged([[_bm(Vector3(0.05, 0.012, 0.004)), _at(Vector3(0, plinth + 0.05, d / 2.0 + 0.01))]], mats.metal, root)
	_collider(Vector3(w, h, d), at + Vector3(0, h / 2.0, 0))


## Corbeille à papier en tôle peinte, ouverte (on voit le fond et deux boulettes de papier).
func _build_bin(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Corbeille"
	root.position = at
	add_child(root)
	var h := 0.3
	var paint := _grimy(_plain(Color(0.13, 0.17, 0.15), 0.5, 0.4), 1.4)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.118
	rim.outer_radius = 0.131
	rim.rings = 28
	rim.ring_segments = 6
	_merged([[_cm(0.125, 0.105, h, 28, false, true), _at(Vector3(0, h / 2.0, 0))],
		[_cm(0.12, 0.1, h - 0.004, 28, false, false, true), _at(Vector3(0, h / 2.0 + 0.002, 0))],
		[_cm(0.1, 0.1, 0.004, 28), _at(Vector3(0, 0.006, 0))],
		[rim, _at(Vector3(0, h, 0))]], paint, root)
	var paper := _grimy(_plain(Color(0.8, 0.78, 0.72), 1.0))
	_merged([[_sm(0.042, 8), _at(Vector3(0.03, 0.05, 0.02), Vector3(0.4, 1.0, 0.2))],
		[_sm(0.036, 8), _at(Vector3(-0.04, 0.045, -0.03), Vector3(1.0, 0.3, 0.7))]], paper, root)
	_collider(Vector3(0.26, h, 0.26), at + Vector3(0, h / 2.0, 0))


## Lampadaire (éteint) : pied en laiton bruni, abat-jour conique en tissu sur sa doublure (faces retournées :
## vu d'en haut, on voit l'intérieur), croisillon, ampoule.
func _build_floor_lamp(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Lampadaire"
	root.position = at
	add_child(root)
	var brass := _grimy(_plain(Color(0.36, 0.28, 0.17), 0.4, 0.85), 1.5)
	var ys := 1.24           # bas de l'abat-jour
	var hs := 0.3            # hauteur de l'abat-jour
	var rt := 0.13
	var rb := 0.21
	var parts := [
		[_cm(0.12, 0.15, 0.03, 32), _at(Vector3(0, 0.015, 0))],
		[_cm(0.035, 0.05, 0.03, 16), _at(Vector3(0, 0.045, 0))],
		[_cm(0.011, 0.011, ys + 0.1 - 0.06, 10), _at(Vector3(0, 0.06 + (ys + 0.1 - 0.06) / 2.0, 0))],
		[_cm(0.017, 0.017, 0.03, 12), _at(Vector3(0, 0.62, 0))],
		[_cm(0.019, 0.016, 0.05, 12), _at(Vector3(0, ys + 0.12, 0))],
		[_sm(0.014, 8), _at(Vector3(0, ys + hs + 0.012, 0))],
	]
	var ring := TorusMesh.new()
	ring.inner_radius = rt - 0.006
	ring.outer_radius = rt - 0.001
	ring.rings = 32
	ring.ring_segments = 4
	parts.append([ring, _at(Vector3(0, ys + hs - 0.004, 0))])
	for k in 3:
		var a := TAU * k / 3.0
		parts.append(_rod(Vector3(0, ys + hs - 0.004, 0), Vector3(cos(a), 0, sin(a)) * (rt - 0.004) + Vector3(0, ys + hs - 0.004, 0), 0.0025, 4))
	parts.append(_rod(Vector3(0, ys + 0.2, 0), Vector3(0, ys + hs, 0), 0.004, 6))
	_merged(parts, brass, root)
	var cloth := _grimy(_plain(Color(0.6, 0.52, 0.38), 1.0), 1.3)
	var liner := _grimy(_plain(Color(0.66, 0.6, 0.48), 1.0), 1.3)
	_merged([[_cm(rt, rb, hs, 40, false, false), _at(Vector3(0, ys + hs / 2.0, 0))]], cloth, root)
	_merged([[_cm(rt - 0.003, rb - 0.003, hs - 0.002, 40, false, false, true), _at(Vector3(0, ys + hs / 2.0, 0))]], liner, root)
	_merged([[_sm(0.032, 12), _at(Vector3(0, ys + 0.175, 0))]], _plain(Color(0.86, 0.84, 0.78), 0.3), root)
	_collider(Vector3(0.3, ys + hs, 0.3), at + Vector3(0, (ys + hs) / 2.0, 0))


## Portemanteau sur pied en bois sombre : fût tourné, quatre pieds, six patères à boule ; un long manteau
## sombre accroché.
func _build_coat_rack(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "PorteManteau"
	root.position = at
	root.rotation.y = 0.5
	add_child(root)
	var parts := [
		[_cm(0.017, 0.023, 1.7, 12), _at(Vector3(0, 0.87, 0))],
		[_sm(0.03, 10), _at(Vector3(0, 1.74, 0))],
		[_cm(0.028, 0.028, 0.04, 12), _at(Vector3(0, 1.3, 0))],
		[_cm(0.03, 0.03, 0.05, 12), _at(Vector3(0, 0.3, 0))],
	]
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		parts.append(_rod(Vector3(0, 0.3, 0) + dir * 0.02, dir * 0.27 + Vector3(0, 0.02, 0), 0.016, 8))
		parts.append([_sm(0.02, 8), _at(dir * 0.27 + Vector3(0, 0.018, 0))])
	var tips: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var y := 1.62 if k % 2 == 0 else 1.52
		var p0 := dir * 0.018 + Vector3(0, y, 0)
		var p1 := p0 + dir * 0.11 + Vector3(0, 0.075, 0)
		parts.append(_rod(p0, p1, 0.008, 6))
		parts.append([_sm(0.015, 8), _at(p1)])
		tips.append(p1)
	_merged(parts, mats.wood_dark, root)
	# le manteau, pendu à la première patère (cône aplati, épaules arrondies)
	var wool := _grimy(_plain(Color(0.085, 0.08, 0.075), 1.0), 1.2)
	var dir0 := Vector3(1, 0, 0)
	var coat := MeshInstance3D.new()
	coat.mesh = _cm(0.085, 0.23, 0.98, 18)
	coat.material_override = wool
	coat.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	coat.position = tips[0] + dir0 * 0.03 + Vector3(0, -0.04 - 0.49, 0)
	coat.rotation = Vector3(0, PI / 2.0, 0.03)
	coat.scale = Vector3(1.0, 1.0, 0.42)
	root.add_child(coat)
	var shoulders := MeshInstance3D.new()
	shoulders.mesh = _sm(0.11, 12)
	shoulders.material_override = wool
	shoulders.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	shoulders.position = tips[0] + dir0 * 0.03 + Vector3(0, -0.1, 0)
	shoulders.rotation = Vector3(0, PI / 2.0, 0)
	shoulders.scale = Vector3(1.25, 0.55, 0.5)
	root.add_child(shoulders)
	_collider(Vector3(0.5, 1.75, 0.5), at + Vector3(0, 0.875, 0))


## Les ampoules du lustre brillent avec le plafonnier (au-dessus de 1, le halo de la lueur les entoure).
func _bulbs_glow(lamp: Node3D) -> void:
	_bulb_mat = _plain(Color(0.86, 0.82, 0.74), 0.25)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color(1.0, 0.74, 0.42)
	_bulb_mat.emission_energy_multiplier = 0.0
	for n in lamp.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# l'ampoule du plafonnier est au cœur du lustre : ses bras ne projettent pas d'ombre (sinon de
		# grandes pales sombres au plafond ; et 21 000 triangles de moins dans les six faces de l'ombre)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src and src.resource_name.to_lower().contains("bulb"):
				mi.set_surface_override_material(i, _bulb_mat)


func _process(_delta: float) -> void:
	if _bulb_mat == null or ceiling_light == null:
		return
	var e := ceiling_light.light_energy if ceiling_light.is_visible_in_tree() else 0.0
	if not is_equal_approx(e, _bulb_e):
		_bulb_e = e
		_bulb_mat.emission_energy_multiplier = e * 1.6


## Bouts de ruban adhésif aux quatre coins d'une affiche (centre, taille, rotation du quad : face vers +z à 0).
func _tape(center: Vector3, size: Vector2, rot_y: float) -> void:
	if _tape_mat == null:
		_tape_mat = _plain(Color(0.74, 0.7, 0.56), 0.5)
	var b := Basis(Vector3.UP, rot_y)
	var parts := []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var local := Vector3(sx * (size.x / 2.0 - 0.014), sy * (size.y / 2.0 - 0.014), 0.0012)
			parts.append([_bm(Vector3(0.06, 0.022, 0.0008)), Transform3D(b * Basis(Vector3.BACK, sx * sy * 0.785), center + b * local)])
	var mi := _merged(parts, _tape_mat, self)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ l'ordinateur

func _build_pc() -> void:
	var x := pc_x
	var z := pc_z
	var base := desk_top
	# unité centrale beige, fente de disquette, voyant
	_box(Vector3(0.52, 0.13, 0.44), Vector3(x, base + 0.065, z), mats.beige)
	_box(Vector3(0.2, 0.012, 0.01), Vector3(x - 0.09, base + 0.075, z + 0.221), mats.dark)
	_box(Vector3(0.05, 0.02, 0.01), Vector3(x + 0.17, base + 0.06, z + 0.221), mats.dark)
	# autocollant d'inventaire du laboratoire, sur le flanc de l'unité centrale
	var sticker := _quad(Vector2(0.13, 0.049), Vector3(x + 0.2615, base + 0.07, z + 0.08), _image_mat("ceraf_label.png", 0.5), PI / 2.0)
	sticker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var st_it := _interactable("Regarder l'autocollant", Vector3(0.06, 0.1, 0.18), Vector3(x + 0.28, base + 0.07, z + 0.08))
	st_it.used.connect(func(_i: Interactable) -> void:
		Game.hint("« CERAF · INVENTAIRE N° 0312. Propriété du CERAF, ne pas sortir du site. » L'ordinateur de ta mère vient d'un laboratoire.", 5.0))
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
	var it := _interactable(LABEL_INSERT, Vector3(1.0, 0.8, 0.8), Vector3(x, base + 0.3, z + 0.2))
	pc_it = it
	it.used.connect(func(_i: Interactable) -> void:
		if convoking:
			it.enabled = false
			_set_pc_shape(false)
			pc_answered.emit()
		elif Game.has_floppy:
			it.enabled = false
			_set_pc_shape(false)
			pc_used.emit()
		else:
			Game.hint("L'écran clignote. Il attend quelque chose."))
	# le bouton d'éjection, sous la fente : la disquette ne ressort pas (§ 4.3). Il n'est visé qu'une
	# fois la disquette dans le lecteur (la grande boîte « Insérer la disquette » est alors coupée).
	_box(Vector3(0.022, 0.009, 0.006), Vector3(x + 0.035, base + 0.052, z + 0.222), mats.dark)
	# (la boîte dépasse de 3 cm le collisionneur de l'unité centrale, pour que le rayon la trouve)
	eject_it = _interactable("Éjecter la disquette", Vector3(0.3, 0.1, 0.12), Vector3(x - 0.05, base + 0.065, z + 0.29))
	eject_it.enabled = false
	eject_it.used.connect(func(_i: Interactable) -> void:
		Sfx.play_at("metalClick", eject_it.global_position, -8.0, 1.3)
		Game.hint(EJECT_MSG, 3.0))
	_collider(Vector3(0.52, 0.56, 0.6), Vector3(x, base + 0.28, z), self)
	var hum: Node = Sfx.loop("crt_hum", -30.0, screen_center, self)
	hum.set("max_distance", 6.0)
	# pour l'entité, un écran parmi les appareils de la maison (indice de l'étape « sortir »)
	var pc := ManonPc.new()
	pc.name = "PcManon"
	pc.device_id = "pc_manon"
	pc.room_id = "mere"
	pc.term = terminal
	add_child(pc)
	pc.position = screen_center
	pc.build()
	pc_dev = pc


## L'ordinateur de ta mère vu comme un appareil de la maison (« pc_manon ») : il n'est pas connecté,
## mais elle y a un écran (« Dans la chambre de ta mère, je n'ai qu'un écran. »). Ce qu'elle y dit
## (l'indice de l'étape « sortir ») s'écrit sur le terminal, sous les derniers mots de la séance.
class ManonPc extends Connected:
	var term: Node

	func build() -> void:
		display_name = "Ordinateur"
		can_speak = true
		built = true

	func speak(text: String, _seconds: float) -> void:
		if term and str(term.get("mode")) == "done":
			_type(text)

	func _type(text: String) -> void:
		await term.line(text, "n", 0.03, 0.2)
		if is_instance_valid(term):
			term.set("narrating", false)


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
	eject_it.enabled = true
	await get_tree().create_timer(1.2).timeout


# ------------------------------------------------------------------ murs : affiches, mot, interrupteur

func _build_wall_things() -> void:
	var back := -D / 2.0 + 0.006
	_quad(Vector2(0.62, 0.89), Vector3(-0.55, 1.55, back), _image_mat("poster_choisis.png"))
	_tape(Vector3(-0.55, 1.55, back), Vector2(0.62, 0.89), 0.0)
	var note := _quad(Vector2(0.22, 0.275), Vector3(0.42, 1.42, back + 0.001), _image_mat("note.png"))
	note.rotation.z = 0.06
	var nit := _interactable("Lire le mot", Vector3(0.26, 0.31, 0.05), Vector3(0.42, 1.42, back + 0.02))
	nit.used.connect(func(_i: Interactable) -> void: get_tree().call_group("hud", "read_paper",
		"ne pas jouer\naprès minuit.\n\nsi l'écran te parle,\nne réponds pas.\n\n— M."))
	_quad(Vector2(0.55, 0.55), Vector3(W / 2.0 - 0.006, 1.62, -0.9), _image_mat("poster_spectres.png"), -PI / 2.0)
	_tape(Vector3(W / 2.0 - 0.006, 1.62, -0.9), Vector2(0.55, 0.55), -PI / 2.0)
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


## Lueur de l'écran selon le style d'image (main.gd, _apply_video). Rétro : celle d'avant. Rendu net :
## AgX relève ce vert ; plus pâle et de plus courte portée, elle éclaire le bureau et la chaise sans
## repeindre le plafond en vert fluo. (L'énergie, elle, suit le scénario : _screen_light_e.)
func set_screen_glow_style(retro: bool) -> void:
	if screen_light == null:
		return
	screen_light.light_color = Color(0.36, 1.0, 0.42) if retro else Color(0.55, 0.92, 0.62)
	screen_light.omni_range = 2.5 if retro else 1.9
	screen_light.omni_attenuation = 1.8 if retro else 2.4
	if screen_mat:
		# l'écran : tube presque noir et vignette dans les coins seulement (en rendu net, l'ancienne vignette
		# serrée dessinait une ellipse grise floue)
		screen_mat.set_shader_parameter("base_glow", 0.035 if retro else 0.012)
		screen_mat.set_shader_parameter("vig_outer", 0.62 if retro else 0.95)
		screen_mat.set_shader_parameter("vig_inner", 0.18 if retro else 0.45)


func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.amount = 150
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	q.size = Vector2(0.005, 0.005)
	var dm := StandardMaterial3D.new()
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# un point rond et flou (pas un carré : en rendu net, un grain de 7 mm faisait 10 px à 50 cm)
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.35, Color(1, 1, 1, 0.55))
	dot.gradient = gr
	dm.albedo_texture = dot
	dm.albedo_color = Color(1, 0.95, 0.85, 0.4)
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
	Game.hint("Une disquette. « NE PAS JOUER », de l'écriture de Papi. Elle est tiède.")


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
	Game.hint("Un souffle. Puis, très bas, quelqu'un répète ton prénom.")


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
	Game.face_scares += 1
	if Game.reduced_scares:
		# sursauts réduits : le visage reste sur l'écran, son plus bas, aucune secousse
		Sfx.sting(-14.0)
		terminal.watch_face(0.55, 0.4)
		await get_tree().create_timer(1.4, false).timeout
		terminal.watch_face(0.0, 0.8)
		if not ceiling_dead:
			await ceiling_burst()
		return
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
	for ex in [-0.70, 0.52]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.42
		eye.mesh = sm
		eye.material_override = black
		eye.position = Vector3(ex, 1.68, 1.98)
		face.add_child(eye)
	var under := OmniLight3D.new()
	under.light_color = Color(1.0, 0.82, 0.75)
	under.omni_range = 12.0
	under.light_energy = 0.0
	face.add_child(under)
	under.position = Vector3(0, -7.0, 7.0)
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
	var screen_e := screen_light.light_energy
	screen_light.light_energy = 0.03
	Sfx.sting(0.0)
	var post := get_tree().get_first_node_in_group("retro")
	if post:
		post.material.set_shader_parameter("corruption", 1.0)
	var head: Node3D = p.head
	var base := head.position
	var t := 0.0
	while t < 1.0:
		face.global_position -= fwd * 0.006   # il avance
		under.light_energy = 0.9 if rng.randf() < 0.65 else 0.15
		if not ceiling_dead:
			ceiling_light.light_energy = 2.5 if rng.randf() < 0.5 else 0.2
		head.position = base + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * 0.012 * (1.0 - t)
		await get_tree().create_timer(0.04, false).timeout
		t += 0.04
	head.position = base
	face.visible = false
	screen_light.light_energy = screen_e
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
	Sfx.play_at("door_slide", at + Vector3(0.3, 0.1, 0), 0.0, 1.0, 3.0)
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
		key_taken.emit())


# ------------------------------------------------------------------ sauvegarde

## La chambre telle qu'elle est après la séance 1 (chargement d'une sauvegarde de l'acte II) : armoire
## ouverte, disquette dans le lecteur (voyant allumé), plafonnier éclaté, chaise à sa place.
## La porte P1 et l'écran sont remis par Acte1.restore().
func restore_after_seance() -> void:
	wardrobe_open = true
	if wardrobe_it:
		wardrobe_it.label = "Fouiller l'armoire"
	for d in wardrobe_doors:
		var sign_ := -1.0 if String(d.name).to_lower().contains("left") else 1.0
		d.rotation.y = sign_ * 1.85
	floppy.visible = false
	floppy_item.enabled = false
	if pc_it and not convoking:
		pc_it.enabled = false
		pc_it.label = LABEL_INSERT
		_set_pc_shape(false)
	eject_it.enabled = true
	led_mat.albedo_color = Color(1, 0.7, 0.18)
	led_mat.emission_enabled = true
	led_mat.emission = Color(1, 0.65, 0.15)
	led_mat.emission_energy_multiplier = 3.0
	ceiling_on = false
	ceiling_dead = true
	ceiling_light.light_energy = 0.0
	chair.visible = true


# ------------------------------------------------------------------ convocation (acte II)

## La grande boîte d'interaction de l'ordinateur : coupée quand elle ne sert pas (on vise alors le
## bouton d'éjection, qu'elle recouvre), rendue pour la convocation.
func _set_pc_shape(on: bool) -> void:
	if pc_it == null:
		return
	for c in pc_it.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not on)


## Convocation (§ 2.2, étape 13 ; § 4.3) : le chant du modem, joué depuis l'ordinateur et entendu dans
## tout l'étage, repris toutes les MODEM_EVERY secondes ; l'écran clignote ; « Répondre à
## l'ordinateur » (pc_answered). convocation(false) : tout s'arrête (le joueur a répondu, ou la fin).
func convocation(on: bool) -> void:
	convoking = on
	if _modem_timer == null:
		_modem_timer = Timer.new()
		_modem_timer.name = "ModemRepete"
		_modem_timer.wait_time = MODEM_EVERY
		_modem_timer.timeout.connect(_modem_chant)
		add_child(_modem_timer)
	if _blink_tw:
		_blink_tw.kill()
		_blink_tw = null
	if on:
		pc_it.label = LABEL_ANSWER
		pc_it.enabled = true
		_set_pc_shape(true)
		_modem_chant()
		_modem_timer.start()
		# l'écran clignote (luminosité du tube et sa lueur dans la pièce)
		_blink_tw = create_tween().set_loops()
		_blink_tw.tween_method(_screen_blink, 1.0, 0.0, 0.45)
		_blink_tw.tween_method(_screen_blink, 0.0, 1.0, 0.45)
		return
	_modem_timer.stop()
	if modem and is_instance_valid(modem):
		var p := modem
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", -50.0, 0.4)
		tw.tween_callback(p.queue_free)
	modem = null
	_screen_blink(1.0)
	pc_it.enabled = false
	pc_it.label = LABEL_INSERT
	_set_pc_shape(false)


func _screen_blink(k: float) -> void:
	if screen_mat:
		screen_mat.set_shader_parameter("brightness", lerpf(0.55, 1.45, k))
	if screen_light:
		screen_light.light_energy = lerpf(0.1, _screen_light_e, k)


## Un chant du modem (8 s : tonalité, numérotation, poignée de main) depuis l'ordinateur, assez fort
## pour traverser l'étage (assourdi de loin), et son sous-titre « [Chant de modem…] » (si l'option des
## sous-titres des sons est active).
func _modem_chant() -> void:
	if not convoking:
		return
	if modem and is_instance_valid(modem) and modem.playing:
		return
	modem = Sfx.play_at("modem_chant", screen_center, MODEM_DB, 1.0, 6.0)
	if modem:
		modem.max_distance = 40.0
		modem.attenuation_filter_cutoff_hz = 3500.0
		modem.pitch_scale = 1.0
	modem_plays += 1
	var h := Haunt.of(get_tree())
	if h:
		h.sound_caption(MODEM_CAPTION)
		h.log({"ev": "modem", "dev": "pc_manon", "n": modem_plays})
