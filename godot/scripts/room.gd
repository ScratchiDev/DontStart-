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
## Passe « triple A » (lot V2-MERE) : l'ordinateur cathodique, le lit, le visage, l'usure.
var screen_mesh: MeshInstance3D      # l'écran : le quad de 0,38 × 0,29 (calotte bombée hors rendu logiciel)
var screen_glass: MeshInstance3D     # vitre bombée devant le tube (vraie carte seulement ; cachée en rétro)
var _plastic: StandardMaterial3D     # plastique ivoire jauni de l'ordinateur (vraie carte)
var _mon_led: StandardMaterial3D     # voyant vert du moniteur : il suit l'écran (power_on)
var _mon_led_on := -1
var _night_top := 0.55               # dessus du chevet, de la commode (objets de détail posés dessus)
var _dresser_top := 0.8
## Gain HDR du phosphore en rendu net : brightness 1,45 (séance, convocation) × 1,52 ≈ 2,2, au-dessus du
## seuil du halo (1,0) : les lettres irradient. Rétro : 1, l'écran d'avant.
const SCREEN_HDR_GAIN := 2.2 / 1.45
const SCREEN_HALATION := 0.3
## Couche de rendu de la vitre de l'écran (vue par toutes les caméras) : la lueur de l'écran (screen_light,
## une lampe placée devant lui) ne l'éclaire pas, sinon son reflet faisait une tache au milieu de la dalle.
const LAYER_SCREEN_GLASS := 16


func _notification(what: int) -> void:
	# (atlas des légendes du clavier et ouïes, gardés d'une partie à l'autre, rendus en quittant ; le
	# _notification de Builder libère ses propres caches)
	if what == NOTIFICATION_PREDELETE:
		_kb_atlas = null
		_kb_cells = {}
		_vent_tex = []
		_mouse_tex = null


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
	# rideaux (plis animés par un shader). Vraie carte (lot V2-MERE-FIN) : des pans de velours modelés (plis
	# en relief avec leurs normales, froncés sous la tringle, ourlet droit), anneaux sur la tringle ; rendu
	# logiciel : les plans d'avant et curtain.gdshader.
	if Builder.soft_render():
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
	else:
		_velvet_curtains(x, fy, fz, fw, fh)
	_box(Vector3(0.03, 0.03, fw + 0.8), Vector3(x + 0.17, WIN_Y1 + 0.36, fz), mats.metal)
	# radiateur sous la fenêtre (vraie carte : en fonte, à colonnes ; rendu logiciel : les neuf barres d'avant)
	if Builder.soft_render():
		for i in 9:
			_box(Vector3(0.07, 0.52, 0.06), Vector3(x + 0.13, 0.48, fz - 0.4 + i * 0.1), mats.paint)
		_box(Vector3(0.04, 0.04, 1.0), Vector3(x + 0.13, 0.76, fz), mats.paint)
	else:
		_build_radiator(x + 0.13, fz)
	_collider(Vector3(0.2, 0.6, 1.0), Vector3(x + 0.13, 0.4, fz))


## Radiateur en fonte à colonnes sous la fenêtre (lot V2-MERE-FIN, vraie carte) : 14 éléments à deux
## colonnes arrondies reliées par un voile, moyeux haut et bas qui se touchent presque d'un élément à
## l'autre, deux paires de pieds, peinture crème écaillée (PaintedMetal010 : la fonte sombre dans les éclats,
## rugosité 0,6), tuyau de cuivre qui sort du parquet, robinet à volant noir. Le collider reste celui d'avant.
func _build_radiator(cx: float, fz: float) -> void:
	var n := 14
	var step := 0.061
	var z0 := fz - (n - 1) * step / 2.0
	var z1 := fz + (n - 1) * step / 2.0
	var y0 := 0.2
	var y1 := 0.72
	var col := CapsuleMesh.new()
	col.radius = 0.0165
	col.height = y1 - y0 + 0.04
	col.radial_segments = 10
	col.rings = 2
	var hub := Builder.cylinder_mesh(0.024, 0.024, step - 0.006, 12, 0.004)
	var nipple := Builder.cylinder_mesh(0.017, 0.017, step, 10, 0.0)
	var web := Builder.bevel_box_mesh(Vector3(0.036, y1 - y0 - 0.06, 0.007), 0.0025)
	var crown := Builder.bevel_box_mesh(Vector3(0.07, 0.022, step - 0.012), 0.008)
	var parts := []
	for i in n:
		var zz := z0 + i * step
		for sx in [-0.025, 0.025]:
			parts.append([col, _at(Vector3(cx + sx, (y0 + y1) / 2.0, zz))])
		parts.append([web, _at(Vector3(cx, (y0 + y1) / 2.0, zz))])
		parts.append([crown, _at(Vector3(cx, y1 + 0.004, zz))])
		for yy in [y0, y1]:
			parts.append([hub, _at(Vector3(cx, yy, zz), Vector3(PI / 2.0, 0, 0))])
			if i < n - 1:
				parts.append([nipple, _at(Vector3(cx, yy, zz + step / 2.0), Vector3(PI / 2.0, 0, 0))])
	for zz in [z0 + step, z1 - step]:
		for sx in [-0.025, 0.025]:
			parts.append([Builder.cylinder_mesh(0.012, 0.016, y0 - 0.02, 10), _at(Vector3(cx + sx, (y0 - 0.02) / 2.0, zz))])
	var paint := Surfaces.pbr("PaintedMetal010/PaintedMetal010", 0.3, Color(0.93, 0.87, 0.74), 1.0, true, false, 0.6, true)
	var rad := _merged(parts, Surfaces.grime(paint, 0.5, 3), self, true)
	rad.name = "Radiateur"
	# tuyaux de cuivre (retour en bas côté fenêtre, arrivée et robinet en haut de l'autre côté)
	var copper := _grimy(_plain(Color(0.5, 0.31, 0.2), 0.42, 0.85), 1.4)
	var pipe := [
		[Builder.cylinder_mesh(0.011, 0.011, 0.07, 10, 0.0), _at(Vector3(cx, y0, z0 - 0.055), Vector3(PI / 2.0, 0, 0))],
		[_sm(0.0135, 10), _at(Vector3(cx, y0, z0 - 0.09))],
		[Builder.cylinder_mesh(0.011, 0.011, y0, 10, 0.0), _at(Vector3(cx, y0 / 2.0, z0 - 0.09))],
		[Builder.cylinder_mesh(0.011, 0.011, 0.07, 10, 0.0), _at(Vector3(cx, y1, z1 + 0.055), Vector3(PI / 2.0, 0, 0))],
		[Builder.cylinder_mesh(0.011, 0.011, y1 - 0.05, 10, 0.0), _at(Vector3(cx, (y1 - 0.05) / 2.0, z1 + 0.1))],
		[Builder.cylinder_mesh(0.02, 0.02, 0.012, 14, 0.0), _at(Vector3(cx, 0.006, z0 - 0.09))],
		[Builder.cylinder_mesh(0.02, 0.02, 0.012, 14, 0.0), _at(Vector3(cx, 0.006, z1 + 0.1))],
	]
	_merged(pipe, copper, self)
	_merged([[Builder.cylinder_mesh(0.019, 0.021, 0.075, 14), _at(Vector3(cx, y1 - 0.012, z1 + 0.1))],
		[Builder.cylinder_mesh(0.006, 0.006, 0.04, 8, 0.0), _at(Vector3(cx, y1 + 0.04, z1 + 0.1))]], _brass(), self)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.02
	wheel.outer_radius = 0.03
	wheel.rings = 18
	wheel.ring_segments = 6
	_merged([[wheel, _at(Vector3(cx, y1 + 0.062, z1 + 0.1))]], _plain(Color(0.07, 0.06, 0.05), 0.45), self)


## Rideaux de velours (lot V2-MERE-FIN, vraie carte) : deux pans modelés, plis en relief (trois ondes de
## 9 à 16 cm, phases fixes, plus amples en bas, serrées et froncées sous la tringle), ourlet droit avec un
## repli, normales et tangentes calculées ; velours (velour_velvet, Poly Haven, CC0) bordeaux, rugosité
## 0,85, reflet rasant (rim) 0,5 ; le même petit courant d'air qu'avant (CURTAIN_SHADER, en haut immobile).
## Anneaux de laiton sur la tringle.
func _velvet_curtains(x: float, fy: float, fz: float, fw: float, fh: float) -> void:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CURTAIN_SHADER
	m.shader = sh
	m.set_shader_parameter("albedo_tex", load("res://assets/textures/velour_velvet/velour_velvet_albedo.jpg"))
	m.set_shader_parameter("normal_tex", load("res://assets/textures/velour_velvet/velour_velvet_normal_gl.jpg"))
	var top := WIN_Y1 + 0.34
	var h := fh + 0.5
	var bottom := top - h
	var rings := []
	for side in [-1.0, 1.0]:
		var zc: float = fz + side * (fw / 2.0 + 0.12)
		var mesh := _curtain_mesh(0.5, h, 1.7 if side < 0.0 else 4.3)
		var mi := _mesh_node(mesh, m, self, "Rideau", true)
		mi.position = Vector3(x + 0.17, bottom, zc)
		mi.rotation.y = PI / 2.0
		for k in 7:
			var t := TorusMesh.new()
			t.inner_radius = 0.019
			t.outer_radius = 0.025
			t.rings = 12
			t.ring_segments = 5
			rings.append([t, _at(Vector3(x + 0.17, WIN_Y1 + 0.36, zc - 0.22 + k * 0.073), Vector3(0, 0, PI / 2.0))])
	_merged(rings, _brass(), self)


## Un pan de rideau : largeur w (le long de x du maillage), hauteur h (y de 0 à h, le haut à la tringle),
## plis vers +z et -z. ph : phase propre au pan.
static func _curtain_mesh(w: float, h: float, ph: float) -> ArrayMesh:
	var nx := 56
	var ny := 30
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	var uvs := []
	for j in ny + 1:
		var v := float(j) / ny            # 0 en bas, 1 en haut
		var y := v * h
		var row := []
		var urow := []
		var u_len := 0.0
		var prev := Vector3.ZERO
		for i in nx + 1:
			var u := float(i) / nx
			var xx := (u - 0.5) * w
			var low := 1.0 - v
			# trois ondes (9 à 16 cm), plus amples vers le bas ; froncées en haut (onde courte, 6 cm)
			var amp := 0.018 + 0.03 * low * low
			var d := amp * (sin(xx / 0.016 + ph) * 0.5 + sin(xx / 0.024 + ph * 1.7 + v * 0.8) * 0.33 + sin(xx / 0.013 + ph * 0.6) * 0.17)
			d += smoothstep(0.88, 1.0, v) * 0.012 * sin(xx / 0.0095 + ph)
			# l'ourlet : une bande retournée de 5 cm, légèrement plus épaisse
			d += smoothstep(0.05, 0.0, y) * 0.004
			# le pan tombe un peu vers l'intérieur en bas (poids du tissu)
			var p := Vector3(xx * (1.0 - 0.04 * low), y, d)
			if i > 0:
				u_len += p.distance_to(prev)
			prev = p
			row.append(p)
			urow.append(Vector2(u_len, h - y))
		pts.append(row)
		uvs.append(urow)
	for j in ny:
		for i in nx:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var c: Vector3 = pts[j + 1][i]
			var d2: Vector3 = pts[j + 1][i + 1]
			var ua: Vector2 = uvs[j][i]
			var ub: Vector2 = uvs[j][i + 1]
			var uc: Vector2 = uvs[j + 1][i]
			var ud: Vector2 = uvs[j + 1][i + 1]
			for q in [[a, ua], [b, ub], [c, uc], [b, ub], [d2, ud], [c, uc]]:
				st.set_uv(q[1])
				st.add_vertex(q[0])
	st.index()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


const CURTAIN_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint = vec3(0.25, 0.5, 0.33);
uniform float meters = 0.35;
uniform float sway = 0.015;
uniform float height = 1.75;
void vertex() {
	float low = clamp(1.0 - VERTEX.y / height, 0.0, 1.0);
	VERTEX.z += sin(TIME * 0.7 + VERTEX.y * 2.0) * sway * low;
}
void fragment() {
	vec2 uv = UV / meters;
	vec3 a = texture(albedo_tex, uv).rgb * tint;
	// envers (côté vitre) : la doublure, un peu plus terne
	ALBEDO = FRONT_FACING ? a : a * 0.7;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = 0.85;
	RIM = 0.5;
	RIM_TINT = 0.6;
	SPECULAR = 0.3;
}
"""


# ------------------------------------------------------------------ meubles

func _build_furniture() -> void:
	# bureau (mur du fond) : l'ordinateur est posé dessus dans _build_pc
	var desk := prop("desk", Vector3(1.25, 0, -2.25), 0.0, Vector3(1.45, 0.76, 0.7))
	desk_top = (desk.get_meta("size") as Vector3).y
	_retint(desk)
	_dress_desk(desk)
	_build_keyboard(Vector3(pc_x, desk_top, -2.0))
	var mouse := prop("computerMouse", Vector3(1.62, desk_top, -2.02), -8.0, Vector3(0.065, 0, 0), false)
	if not Builder.soft_render():
		# (vraie carte) une souris à deux boutons des années 1990, modelée, à la place du Kenney caché
		_hide_meshes(mouse)
		var mm := _mesh_node(_mouse_mesh(), _mouse_mat(), self, "Souris")
		mm.position = mouse.position
		mm.rotation.y = mouse.rotation.y
	_hide_meshes(prop("books", Vector3(0.68, desk_top, -2.08), -14.0, Vector3(0.26, 0, 0), false))
	_book_stack(Vector3(0.68, desk_top, -2.08), deg_to_rad(-14.0))
	# (vraie carte, lot V2-MERE-FIN : la lampe d'architecte à sa vraie taille, 0,52 m comme au bureau, au lieu
	# d'un jouet de 0,4 m ; rendu logiciel : la taille d'avant)
	prop("lampRoundTable", Vector3(0.6, desk_top, -2.42), 20.0, Vector3(0, 0.4 if Builder.soft_render() else 0.52, 0), false)
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
	# une télé à tube de 1990 (Poly Haven, television_02) : chargée ici, avant la mesure de B16, elle est
	# en cache pour la chambre d'amis
	prop("televisionVintage", Vector3(2.78, (shelf.get_meta("size") as Vector3).y, -2.36), 0.0, Vector3(0.44, 0, 0), false, {}, "", "television_02")

	# lit (mur de gauche, tête vers la fenêtre), chevet, réveil, nounours
	var bed := prop("bedSingle", Vector3(-2.65, 0, 1.58), 0.0, Vector3(1.05, 0.55, 2.0), true,
		{"carpet": Color(0.24, 0.12, 0.15), "carpetwhite": Color(0.52, 0.5, 0.46)}, "Se coucher")
	bed.get_meta("interactable").used.connect(func(_i: Interactable) -> void:
		Game.hint("Pas maintenant. Tu n'as pas sommeil. Tu n'auras plus jamais sommeil."))
	_build_duvet(bed)
	_dress_bed(bed)
	_build_teddy(Vector3(-2.35, 0.43, 2.25), -110.0)
	var night := prop("cabinetBedDrawerTable", Vector3(-2.92, 0, 0.3), 90.0, Vector3(0.48, 0.55, 0.42))
	_night_top = (night.get_meta("size") as Vector3).y
	_build_clock(Vector3(-2.95, _night_top, 0.32))

	# armoire (coin du fond à gauche) : la disquette est dedans
	var wardrobe := prop("bookcaseClosedDoors", Vector3(-2.55, 0, -2.3), 0.0, Vector3(1.0, 2.05, 0.55), true, {}, "Ouvrir l'armoire")
	wardrobe_it = wardrobe.get_meta("interactable")
	wardrobe_it.used.connect(_on_wardrobe)
	for n in wardrobe.find_children("door*", "Node3D", true, false):
		wardrobe_doors.append(n as Node3D)
	# l'étagère de la disquette, garnie d'un vieux papier d'étagère clair (la disquette noire s'y détache
	# dans le rond de la lampe de poche)
	if Builder.soft_render():
		_box(Vector3(0.86, 0.02, 0.45), Vector3(-2.55, 1.02, -2.3), _grimy(_plain(Color(0.6, 0.56, 0.47), 0.9), 1.5))
	else:
		_wardrobe_shelf(Vector3(-2.55, 1.02, -2.3))
	_build_floppy(Vector3(-2.42, 1.035, -2.22))
	_dress_wardrobe(wardrobe)

	# porte (mur de droite), fermée
	_build_door(Vector3(W / 2.0, 0, 1.4))

	# commode (bois peint, Poly Haven), photo encadrée (visages rayés), linge par terre. Le dessus reste
	# à 0,80 m (la photo et son interaction sont posées dessus) ; dos contre le mur.
	var dresser := model("painted_wooden_cabinet", Vector3(0.75, 0, 2.38), 180.0, Vector3(0, 0.8, 0), true,
		{"fit": "y", "name": "sideTableDrawers"})
	var dtop := (dresser.get_meta("size") as Vector3).y
	_dresser_top = dtop
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
	# couverture en lin lavé bordeaux (Poly Haven rough_linen) ; faces avant vers le haut et vers l'extérieur
	mi.material_override = _linen(Color(0.3, 0.12, 0.13))
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)


## Lin lavé (Poly Haven rough_linen, CC0 : une répétition tous les 27 cm, en coordonnées du monde) teint
## de la couleur « c » : le lin d'origine est bleu clair, d'environ (0,57 ; 0,67 ; 0,8), d'où la division.
## Sans la texture : la laine tissée des tapis, comme avant.
func _linen(c: Color) -> StandardMaterial3D:
	if not ResourceLoader.exists("res://assets/textures/rough_linen/rough_linen_albedo.jpg"):
		return _rug_mat(c)
	return Surfaces.pbr("rough_linen/rough_linen", 0.27, Color(c.r / 0.57, c.g / 0.67, c.b / 0.8), 0.9)


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
	# (bouts chanfreinés hors rendu logiciel : Builder.cylinder_mesh ; un CylinderMesh comme avant sinon)
	return [Builder.cylinder_mesh(r, r, v.length(), seg), Transform3D(Basis(Quaternion(Vector3.UP, v.normalized())), (a + b) / 2.0)]


## L'étagère de la disquette, vraie carte (lot V2-MERE-FIN) : une planche de chêne clair (chant visible,
## arrondi à l'avant) garnie d'un vieux papier d'étagère à petits carreaux délavés, un peu jauni, dont le
## bord avant retombe de 1 cm ; la disquette noire s'y détache toujours dans le rond de la lampe de poche.
## Même encombrement que la planche d'avant (0,86 × 0,02 × 0,45, centre en « c »).
func _wardrobe_shelf(c: Vector3) -> void:
	var oak := (mats.wood as StandardMaterial3D).duplicate() as StandardMaterial3D
	oak.albedo_color = Color(0.95, 0.85, 0.72)
	var plank := _mesh_node(Builder.rounded_box_mesh(Vector3(0.86, 0.02, 0.45), 0.004, 3), oak, self, "Etagere")
	plank.position = c
	var img := Image.create_empty(128, 128, true, Image.FORMAT_RGB8)
	var base := Color(0.86, 0.82, 0.7)
	var ink := Color(0.52, 0.6, 0.66)
	for yy in 128:
		for xx in 128:
			var bx := 1.0 if (xx % 32) < 12 else 0.0
			var by := 1.0 if (yy % 32) < 12 else 0.0
			var k := 0.28 * (bx + by) + 0.12 * bx * by
			var grain := 0.03 * sin(xx * 1.7 + yy * 0.9) * sin(yy * 2.3)
			img.set_pixel(xx, yy, base.lerp(ink, k) * (1.0 + grain))
	img.generate_mipmaps()
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = ImageTexture.create_from_image(img)
	paper.roughness = 0.9
	Surfaces.world_uv(paper, 0.12)
	paper = _grimy(paper, 1.5)
	var liner := _mesh_node(Builder.box_mesh(Vector3(0.84, 0.0015, 0.43), 0.0), paper, self, "PapierEtagere")
	liner.position = c + Vector3(0, 0.011, 0)
	var lip := _mesh_node(Builder.box_mesh(Vector3(0.84, 0.012, 0.0015), 0.0), paper, self, "PapierBord")
	lip.position = c + Vector3(0, 0.005, 0.2265)


## L'armoire de la disquette (Kenney, gardée : ses portes s'ouvrent, sa boîte d'interaction et l'étagère de
## la disquette sont réglées sur elle) habillée en armoire de campagne : bois sombre ciré, portes à
## panneaux moulurés (enfants des portes : ils tournent avec elles), corniche, ceinture, côté mouluré,
## ferrures en laiton, et une vieille valise posée dessus. Rien ne change pour le jeu.
func _dress_wardrobe(wardrobe: Node3D) -> void:
	var wood := (mats.wood_dark as StandardMaterial3D).duplicate() as StandardMaterial3D
	var fancy := not Builder.soft_render()
	# (vraie carte, lot V2-MERE-FIN : un chêne foncé ciré plutôt que le bordeaux d'avant)
	wood.albedo_color = Color(0.62, 0.53, 0.48) if fancy else Color(0.6, 0.47, 0.38)
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
			if fancy:
				# (vraie carte) moulures arrondies et panneau à plate-bande : un relief chanfreiné qui accroche
				# la lumière sur ses quatre pentes
				parts.append([Builder.bevel_box_mesh(Vector3(pw, fw, 0.016), 0.006), _at(Vector3(cx, y1 - fw / 2.0, 0.008))])
				parts.append([Builder.bevel_box_mesh(Vector3(pw, fw, 0.016), 0.006), _at(Vector3(cx, y0 + fw / 2.0, 0.008))])
				parts.append([Builder.bevel_box_mesh(Vector3(fw, ph - 2.0 * fw + 0.004, 0.016), 0.006), _at(Vector3(cx - pw / 2.0 + fw / 2.0, cy, 0.008))])
				parts.append([Builder.bevel_box_mesh(Vector3(fw, ph - 2.0 * fw + 0.004, 0.016), 0.006), _at(Vector3(cx + pw / 2.0 - fw / 2.0, cy, 0.008))])
				parts.append([Builder.bevel_box_mesh(Vector3(pw - 2.0 * fw - 0.03, ph - 2.0 * fw - 0.03, 0.016), 0.011), _at(Vector3(cx, cy, 0.004))])
				continue
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
	if fancy:
		# (vraie carte) corniche profilée en doucine (un loft de rectangles aux coins vifs, le dos au ras du
		# meuble), socle mouluré sur trois côtés avec quatre pieds d'angle et un tablier en retrait
		_merged([[_cornice_mesh(size.x, size.z, top), Transform3D.IDENTITY]], wood, wardrobe, true)
		for sx in [-1.0, 1.0]:
			for zz in [fz - 0.045, bz + 0.05]:
				cp.append([Builder.bevel_box_mesh(Vector3(0.085, 0.13, 0.09), 0.008), _at(Vector3(sx * (size.x / 2.0 - 0.035), 0.065, zz + (0.02 if zz > 0.0 else 0.0)))])
		cp.append([Builder.bevel_box_mesh(Vector3(size.x - 0.12, 0.075, 0.024), 0.006), _at(Vector3(0, 0.1, fz))])
		cp.append([Builder.bevel_box_mesh(Vector3(size.x + 0.024, 0.03, 0.03), 0.01), _at(Vector3(0, 0.15, fz + 0.01))])
		for sx in [-1.0, 1.0]:
			cp.append([Builder.bevel_box_mesh(Vector3(0.024, 0.075, size.z - 0.17), 0.006), _at(Vector3(sx * (size.x / 2.0 + 0.006), 0.1, 0.0))])
			cp.append([Builder.bevel_box_mesh(Vector3(0.03, 0.03, size.z + 0.01), 0.01), _at(Vector3(sx * (size.x / 2.0 + 0.012), 0.15, 0.005))])
	else:
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


## Corniche de l'armoire (vraie carte) : un loft de rectangles à coins vifs qui suit un profil en doucine
## (talon, gorge, quart-de-rond, listel) sur 9,5 cm ; le dos reste au ras du meuble (contre le mur).
static func _cornice_mesh(w: float, d: float, top: float) -> ArrayMesh:
	# [hauteur au-dessus du dessus du meuble, saillie]
	var prof := [[-0.012, 0.0], [-0.004, 0.006], [0.006, 0.008], [0.012, 0.006], [0.02, 0.01], [0.032, 0.02],
		[0.045, 0.034], [0.056, 0.042], [0.066, 0.046], [0.074, 0.05], [0.09, 0.052], [0.095, 0.05]]
	var secs := []
	var ys := PackedFloat32Array()
	for e in prof:
		var o := float(e[1])
		var hx := w / 2.0 + o
		var hz := d / 2.0 + o / 2.0
		var ring := PackedVector2Array()
		# rectangle à coins vifs, sens trigonométrique, 4 points par côté (les normales restent nettes)
		var pts := [Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz)]
		for k in 4:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[(k + 1) % 4]
			for q in 4:
				ring.append(a.lerp(b, q / 4.0) + Vector2(0.0, o / 2.0))
		secs.append(ring)
		ys.append(top + float(e[0]))
	return Builder.loft_mesh(secs, ys, true)


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
	if not Builder.soft_render():
		# vraie carte : de vraies reliures (covers.json, decor.gd) : Stendhal, Molière, Lamartine
		var dec := load("res://scripts/decor.gd") as GDScript
		if not (dec.call("_book_data") as Dictionary).is_empty():
			var bufs := {}
			var yb := 0.0
			for k in 3:
				var sz: Vector3 = dims[k]
				var foot := Vector3(0.01 * k, yb, -0.01 * k)
				dec.call("book_add", bufs, dec.call("flat_book_xf", sz, foot, [0.0, 0.12, -0.08][k]), sz.y, sz.z, sz.x, [12, 25, 30][k])
				yb += sz.y
			dec.call("books_commit", bufs, holder, "Reliures")
			return
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
	var soft := Builder.soft_render()
	var parts := []
	var knobs := []
	# tête (vers -z, côté fenêtre) et pied : montants, traverses, barreaux (tubes aux bouts chanfreinés hors
	# rendu logiciel : Builder.cylinder_mesh)
	for end in [[-hz, 1.02, 0.97, 0.56], [hz, 0.8, 0.75, 0.5]]:
		var z: float = end[0]
		var hp: float = end[1]
		var r_top: float = end[2]
		var r_mid: float = end[3]
		for sx in [-1.0, 1.0]:
			parts.append([Builder.cylinder_mesh(0.019, 0.019, hp, 10 if soft else 16), _at(Vector3(sx * hx, hp / 2.0, z))])
			knobs.append([_sm(0.03, 10 if soft else 16), _at(Vector3(sx * hx, hp + 0.022, z))])
			# bague de laiton sous la boule
			if not soft:
				knobs.append([Builder.cylinder_mesh(0.023, 0.021, 0.018, 16), _at(Vector3(sx * hx, hp - 0.004, z))])
		for y in [r_top, r_mid, 0.26]:
			parts.append(_rod(Vector3(-hx, y, z), Vector3(hx, y, z), 0.012 if y != r_top else 0.015, 8 if soft else 12))
		var n := 9
		for k in n:
			var x := lerpf(-hx, hx, float(k + 1) / float(n + 1))
			parts.append(_rod(Vector3(x, r_mid, z), Vector3(x, r_top, z), 0.0065, 6 if soft else 8))
	# longerons
	for sx in [-1.0, 1.0]:
		parts.append([Builder.box_mesh(Vector3(0.03, 0.05, 2.0 * hz)), _at(Vector3(sx * hx, 0.255, 0))])
	var holder := Node3D.new()
	holder.name = "LitFer"
	bed.add_child(holder)
	_merged(parts, iron, holder)
	_merged(knobs, _brass(), holder)
	# sommier, matelas (drap blanc, arêtes arrondies hors rendu logiciel), oreiller rembourré
	_merged([[Builder.box_mesh(Vector3(2.0 * hx - 0.04, 0.03, 2.0 * hz - 0.04)), _at(Vector3(0, 0.235, 0))]], mats.dark, holder)
	var sheet := _grimy(_plain(Color(0.72, 0.7, 0.64), 1.0), 1.0)
	var msize := Vector3(2.0 * hx - 0.05, 0.15, 2.0 * hz - 0.05)
	_merged([[_bm(msize) if soft else Builder.rounded_box_mesh(msize, 0.04, 4), _at(Vector3(0, 0.3, 0))]], sheet, holder)
	var pillow := MeshInstance3D.new()
	pillow.name = "Oreiller"
	pillow.mesh = pillow_mesh(0.64, 0.38, 0.14, 16)
	pillow.material_override = _linen(Color(0.74, 0.72, 0.67))
	pillow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	pillow.position = Vector3(0.02, 0.375 + 0.06, -hz + 0.42)
	pillow.rotation = Vector3(-0.06, 0.06, 0.02)
	holder.add_child(pillow)


## Clavier beige de l'ordinateur (à la place du Kenney, même place, 0,44 m) : socle légèrement incliné,
## cinq rangées de touches et la barre d'espace.
func _build_keyboard(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Clavier"
	root.position = at
	add_child(root)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(3.0))
	if not Builder.soft_render():
		_build_keyboard_aaa(root, tilt)
		return
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


## Clavier AZERTY de 105 touches (années 1990) : par rangée, [z de la rangée (en pas de touche, depuis la
## rangée des fonctions), [[légende, largeur, profondeur], …]] ; « | » : un vide de cette largeur. Les
## touches de 2 de profondeur (Entrée, + et Entrée du pavé) descendent sur la rangée suivante.
const KB_U := 0.0185
const KB_ROWS := [
	[0.0, [["ESC", 1], ["|", 1], ["F1", 1], ["F2", 1], ["F3", 1], ["F4", 1], ["|", 0.5], ["F5", 1], ["F6", 1], ["F7", 1],
		["F8", 1], ["|", 0.5], ["F9", 1], ["F10", 1], ["F11", 1], ["F12", 1], ["|", 0.25], ["IMPR", 1], ["DEF", 1], ["PAU", 1]]],
	[1.5, [["²", 1], ["1", 1], ["2", 1], ["3", 1], ["4", 1], ["5", 1], ["6", 1], ["7", 1], ["8", 1], ["9", 1], ["0", 1],
		[")", 1], ["=", 1], ["←", 2], ["|", 0.25], ["INS", 1], ["ORIG", 1], ["PG↑", 1], ["|", 0.25], ["NUM", 1], ["/", 1],
		["*", 1], ["-", 1]]],
	[2.5, [["TAB", 1.5], ["A", 1], ["Z", 1], ["E", 1], ["R", 1], ["T", 1], ["Y", 1], ["U", 1], ["I", 1], ["O", 1], ["P", 1],
		["^", 1], ["$", 1], ["|", 0.25], ["↵", 1.25, 2], ["|", 0.25], ["SUP", 1], ["FIN", 1], ["PG↓", 1], ["|", 0.25],
		["7", 1], ["8", 1], ["9", 1], ["+", 1, 2]]],
	[3.5, [["VERR", 1.75], ["Q", 1], ["S", 1], ["D", 1], ["F", 1], ["G", 1], ["H", 1], ["J", 1], ["K", 1], ["L", 1], ["M", 1],
		["Ù", 1], ["*", 1], ["|", 4.75], ["4", 1], ["5", 1], ["6", 1]]],
	[4.5, [["⇧", 1.25], ["<", 1], ["W", 1], ["X", 1], ["C", 1], ["V", 1], ["B", 1], ["N", 1], [",", 1], [";", 1], [":", 1],
		["!", 1], ["⇧", 2.75], ["|", 1.25], ["↑", 1], ["|", 1.25], ["1", 1], ["2", 1], ["3", 1], ["ENT", 1, 2]]],
	[5.5, [["CTRL", 1.5], ["|", 1], ["ALT", 1.5], [" ", 7], ["AGR", 1.5], ["|", 1], ["CTRL", 1.5], ["|", 0.25], ["←", 1],
		["↓", 1], ["→", 1], ["|", 0.25], ["0", 2], [".", 1]]],
]
## Touches gris foncé (fonctions, modificateurs, pavé de direction, opérateurs du pavé numérique).
const KB_DARK := ["ESC", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "IMPR", "DEF", "PAU",
	"INS", "ORIG", "PG↑", "SUP", "FIN", "PG↓", "NUM", "/", "*", "-", "+", "ENT", "TAB", "↵", "VERR", "⇧", "CTRL", "ALT",
	"AGR", "←", "↑", "↓", "→"]
## Les touches les plus tapées : un peu plus claires et lustrées, l'encre usée.
const KB_WORN := ["E", "A", "S", "R", "T", "I", "N", " ", "↵", "O", "L"]
## Police des légendes : 5 × 7 points par caractère (bits de gauche à droite, 7 lignes).
const KB_FONT := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 17, 25, 21, 19, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [31, 2, 4, 2, 1, 17, 14], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12],
	"²": [12, 2, 4, 14, 0, 0, 0], ")": [8, 4, 2, 2, 2, 4, 8], "=": [0, 0, 31, 0, 31, 0, 0], "^": [4, 10, 17, 0, 0, 0, 0],
	"$": [4, 15, 20, 14, 5, 30, 4], "Ù": [8, 4, 17, 17, 17, 17, 14], "*": [0, 4, 21, 14, 21, 4, 0],
	"<": [2, 4, 8, 16, 8, 4, 2], ",": [0, 0, 0, 0, 12, 4, 8], ";": [0, 12, 12, 0, 12, 4, 8], ":": [0, 12, 12, 0, 12, 12, 0],
	"!": [4, 4, 4, 4, 4, 0, 4], "/": [0, 1, 2, 4, 8, 16, 0], "-": [0, 0, 0, 31, 0, 0, 0], "+": [0, 4, 4, 31, 4, 4, 0],
	".": [0, 0, 0, 0, 0, 12, 12], "←": [0, 4, 8, 31, 8, 4, 0], "→": [0, 4, 2, 31, 2, 4, 0], "↑": [4, 14, 21, 4, 4, 4, 4],
	"↓": [4, 4, 4, 4, 21, 14, 4], "↵": [1, 1, 5, 9, 31, 8, 4], "⇧": [4, 10, 17, 27, 10, 10, 14],
}
static var _kb_atlas: ImageTexture
static var _kb_cells := {}             # légende -> case de l'atlas (1, 2… ; 0 = aucune)


## Atlas des légendes (1024², 16 × 16 cases de 64 px, niveaux de gris : 1 = encre) : une case par légende,
## la légende en haut à gauche (un caractère : points de 3 px, soit environ 4 mm sur la touche ; plusieurs :
## points de 2 px), comme une sérigraphie.
static func _kb_legends() -> void:
	if _kb_atlas != null:
		return
	var img := Image.create(1024, 1024, false, Image.FORMAT_L8)
	var n := 0
	for row in KB_ROWS:
		for e in row[1]:
			var lab: String = e[0]
			if lab == "|" or lab == " " or _kb_cells.has(lab):
				continue
			n += 1
			_kb_cells[lab] = n
			var s := 3 if lab.length() == 1 else 2
			var x0 := (n % 16) * 64 + 10
			var y0 := (n / 16) * 64 + 9
			for ch in lab:
				var g: Array = KB_FONT.get(ch, [])
				for ry in g.size():
					var bits: int = g[ry]
					for cx in 5:
						if bits & (16 >> cx):
							img.fill_rect(Rect2i(x0 + cx * s, y0 + ry * s, s, s), Color.WHITE)
				x0 += 6 * s
	img.generate_mipmaps()
	_kb_atlas = ImageTexture.create_from_image(img)


const KEY_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D legends : hint_default_black, filter_linear_mipmap_anisotropic;
uniform vec3 light_cap : source_color = vec3(0.72, 0.69, 0.62);
uniform vec3 dark_cap : source_color = vec3(0.47, 0.45, 0.41);
uniform vec3 ink : source_color = vec3(0.1, 0.095, 0.09);
// INSTANCE_CUSTOM : r = case de la légende / 255 (0 : aucune), g = usure (0 à 1), b = 1 touche claire, 0 foncée
varying flat float v_cell;
varying float v_wear;
varying float v_shade;
void vertex() {
	v_cell = INSTANCE_CUSTOM.r * 255.0;
	v_wear = INSTANCE_CUSTOM.g;
	v_shade = INSTANCE_CUSTOM.b;
}
void fragment() {
	vec3 base = mix(dark_cap, light_cap, v_shade) * (1.0 + 0.07 * v_wear);
	float k = 0.0;
	if (v_cell >= 0.5 && UV2.x >= 0.0 && UV2.x <= 1.0 && UV2.y >= 0.0 && UV2.y <= 1.0) {
		float c = floor(v_cell + 0.5);
		vec2 cell = vec2(mod(c, 16.0), floor(c / 16.0));
		k = texture(legends, (cell + clamp(UV2, 0.02, 0.98)) / 16.0).r;
	}
	ALBEDO = mix(base, ink, k * (1.0 - 0.55 * v_wear));
	ROUGHNESS = mix(0.6, 0.34, v_wear);
	SPECULAR = 0.45;
}
"""


## Le clavier, vraie carte : socle de plastique ivoire (rebord chanfreiné, cuvette des touches), 102 touches
## sculptées (bords inclinés, dessus arrondi) en MultiMesh, une par taille de touche, légendes de l'atlas
## (_kb_legends) choisies par instance (KEY_SHADER), touches claires et foncées, touches usées ; trois voyants
## (« verr num » allumé). Même place et même emprise que le clavier d'avant (0,455 × 0,175).
func _build_keyboard_aaa(root: Node3D, tilt: Basis) -> void:
	var kb := Node3D.new()
	kb.name = "Socle"
	kb.transform.basis = tilt
	root.add_child(kb)
	# socle : profil qui monte (repère tourné : z du balayage = hauteur, y du balayage = vers le fond)
	var up := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	var case_buf := MeshBuf.new()
	var well_y := -0.012                 # la cuvette est décalée de 12 mm vers l'avant (voyants au fond)
	_rr_sweep(case_buf, [[0.2275, 0.0875, 0.012, 0.0, 0.0], [0.2275, 0.0875, 0.012, 0.0145, 0.0],
		[0.2245, 0.0845, 0.009, 0.018, 0.0], [0.2115, 0.0665, 0.004, 0.018, well_y], [0.2105, 0.0655, 0.0035, 0.008, well_y]],
		"fcff", Vector3.ZERO, Vector3.BACK, up, 4, Callable(), true)
	_mesh_node(case_buf.mesh(), _pc_plastic(false), kb, "Coque")
	# touches
	_kb_legends()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = KEY_SHADER
	sm.shader = sh
	sm.set_shader_parameter("legends", _kb_atlas)
	var groups := {}                     # « largeur×profondeur » -> [[x, z, case, usure, clair], …]
	for row in KB_ROWS:
		var zr: float = row[0]
		var xu := 0.0
		for e in row[1]:
			var lab: String = e[0]
			var w := float(e[1])
			var d := float(e[2]) if e.size() > 2 else 1.0
			if lab != "|":
				var key := "%s×%s" % [w, d]
				if not groups.has(key):
					groups[key] = []
				(groups[key] as Array).append([(xu + w / 2.0 - 11.25) * KB_U, (zr + d / 2.0 - 3.25) * KB_U - well_y,
					int(_kb_cells.get(lab, 0)), 1.0 if KB_WORN.has(lab) else 0.0, 0.0 if KB_DARK.has(lab) else 1.0])
			xu += w
	for key in groups:
		var wd: PackedStringArray = (key as String).split("×")
		var mesh := _keycap_mesh(float(wd[0]) * KB_U, float(wd[1]) * KB_U)
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var k: Array = list[i]
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(k[0], 0.0105, k[1])))
			mm.set_instance_custom_data(i, Color(float(k[2]) / 255.0, k[3], k[4], 0.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Touches_" + key.replace("×", "x")
		mmi.multimesh = mm
		mmi.material_override = sm
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		kb.add_child(mmi)
	# voyants au-dessus du pavé numérique (verr num allumé, en vert)
	var off := _plain(Color(0.08, 0.1, 0.08), 0.3)
	var on := _plain(Color(0.2, 0.5, 0.2), 0.3)
	on.emission_enabled = true
	on.emission = Color(0.3, 1.0, 0.3)
	on.emission_energy_multiplier = 2.0
	for i in 3:
		_box(Vector3(0.005, 0.0012, 0.0028), Vector3((19.0 + i - 11.25) * KB_U + 0.009, 0.0182, -0.071), on if i == 0 else off, false, kb, 0.0)


## Une touche sculptée de « w » × « d » (m, emprise au pied), base à y = 0, dessus à 11,5 mm : flancs
## inclinés (2,1 mm de retrait), dessus un peu vers l'arrière, arête du dessus chanfreinée ; UV2 du dessus
## : la case de légende sur le carré de gauche (0 à 1, haut de la légende vers le fond du clavier).
static func _keycap_mesh(w: float, d: float) -> ArrayMesh:
	var hw0 := w / 2.0 - 0.0008
	var hd0 := d / 2.0 - 0.0008
	var hw1 := hw0 - 0.0021
	var hd1 := hd0 - 0.0024
	var yc1 := 0.0004
	var h := 0.0115
	var side := minf(2.0 * hw1, 2.0 * hd1)
	var up := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
	var buf := MeshBuf.new()
	var legend := func(p: Vector3) -> Vector2:
		return Vector2((p.x + hw1) / side, (yc1 + hd1 - p.y) / side)
	_rr_sweep(buf, [[hw0, hd0, 0.0016, 0.0, 0.0], [hw1 + 0.0007, hd1 + 0.0007, 0.0024, h - 0.0009, yc1],
		[hw1, hd1, 0.0018, h, yc1]], "fc", Vector3.ZERO, Vector3.BACK, up, 3, Callable(), true, legend)
	return buf.mesh(true)


## Souris (vraie carte) : coque bombée sur un contour en superellipse (5,8 × 9,8 cm), plus haute vers
## l'arrière (3,4 cm), flancs presque droits, dessous plat. UV : la vue de dessus (fentes des boutons dans
## _mouse_mat). L'avant (le câble) vers -z.
static func _mouse_mesh() -> ArrayMesh:
	var a := 0.029
	var b := 0.049
	var na := 48
	var nr := 12
	var outline := Builder.superellipse(a, b, 2.6, na)
	var buf := MeshBuf.new()
	var hmax := func(z: float) -> float:
		return 0.034 * (0.68 + 0.32 * smoothstep(-0.045, 0.03, z))
	for i in nr:
		var rho := 1.0 - float(i) / nr
		for j in na:
			var o: Vector2 = outline[j] * rho
			var y: float = hmax.call(o.y) * sqrt(maxf(0.0, 1.0 - pow(rho, 5.0)))
			buf.add(Vector3(o.x, y, o.y), Vector3.ZERO, Vector2(o.x / (2.0 * a) + 0.5, o.y / (2.0 * b) + 0.5))
	var top := buf.add(Vector3(0.0, hmax.call(0.0), 0.0), Vector3.ZERO, Vector2(0.5, 0.5))
	var ctr := Vector3(0.0, -0.01, 0.0)
	for i in nr - 1:
		for j in na:
			var p0 := i * na + j
			var p1 := i * na + (j + 1) % na
			var q0 := p0 + na
			var q1 := p1 + na
			buf.tri(p0, p1, q1, buf.v[p0] - ctr)
			buf.tri(p0, q1, q0, buf.v[p0] - ctr)
	for j in na:
		var p0 := (nr - 1) * na + j
		var p1 := (nr - 1) * na + (j + 1) % na
		buf.tri(p0, p1, top, Vector3.UP)
	buf.smooth_normals()
	# dessous plat (sommets à part : arête nette)
	var c0 := buf.add(Vector3.ZERO, Vector3.DOWN, Vector2(0.5, 0.5))
	var ring := PackedInt32Array()
	for j in na:
		var o: Vector2 = outline[j]
		ring.append(buf.add(Vector3(o.x, 0.0, o.y), Vector3.DOWN, Vector2(o.x / (2.0 * a) + 0.5, o.y / (2.0 * b) + 0.5)))
	for j in na:
		buf.tri(c0, ring[j], ring[(j + 1) % na], Vector3.DOWN)
	return buf.mesh()


static var _mouse_tex: ImageTexture


## Plastique de la souris : l'ivoire du clavier, les fentes des deux boutons (une en travers à 1,2 cm
## de l'avant du sommet, une au milieu jusqu'au bout) dessinées dans une petite image vue de dessus.
func _mouse_mat() -> StandardMaterial3D:
	if _mouse_tex == null:
		var img := Image.create(128, 256, true, Image.FORMAT_L8)
		img.fill(Color.WHITE)
		var vs := int((-0.012 / 0.098 + 0.5) * 256.0)
		img.fill_rect(Rect2i(14, vs - 1, 100, 3), Color(0.18, 0.18, 0.18))
		img.fill_rect(Rect2i(63, 0, 3, vs), Color(0.18, 0.18, 0.18))
		img.generate_mipmaps()
		_mouse_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _mouse_tex
	var t := _pc_tint(Vector3(0, 0.2, 0))
	m.albedo_color = Color(0.66 * t.r, 0.62 * t.g, 0.52 * t.b)
	m.roughness = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _grimy(m, 2.0)


## Le nounours, assis sur la couette au pied du lit (sphères : peluche brune, museau clair, yeux et truffe).
func _build_teddy(at: Vector3, rot_deg: float) -> void:
	var root := Node3D.new()
	root.name = "Nounours"
	root.position = at
	root.rotation_degrees.y = rot_deg
	add_child(root)
	var soft := Builder.soft_render()
	var ball := _sm(0.5, 14 if soft else 24)
	var small := _sm(0.5, 8 if soft else 12)
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
	# peluche bouclée (Poly Haven curly_teddy_natural, CC0 ; crème d'origine, d'environ (0,91 ; 0,83 ; 0,73),
	# teinte en brun) ; sans la texture, l'aplat d'avant
	var curly := ResourceLoader.exists("res://assets/textures/curly_teddy_natural/curly_teddy_natural_albedo.jpg")
	var fur_mat := Surfaces.pbr("curly_teddy_natural/curly_teddy_natural", 0.2, Color(0.39, 0.3, 0.22), 1.2) if curly \
		else _grimy(_plain(Color(0.36, 0.25, 0.16), 1.0), 2.0)
	var snout_mat := Surfaces.pbr("curly_teddy_natural/curly_teddy_natural", 0.12, Color(0.68, 0.6, 0.49), 0.8) if curly \
		else _grimy(_plain(Color(0.62, 0.5, 0.36), 1.0), 2.0)
	_merged(fur, fur_mat, root)
	_merged([sc.call(Vector3(0.06, 0.048, 0.05), Vector3(0, 0.232, 0.066))], snout_mat, root)
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
	if Builder.soft_render():
		var cloth := _grimy(_plain(Color(0.6, 0.52, 0.38), 1.0), 1.3)
		var liner := _grimy(_plain(Color(0.66, 0.6, 0.48), 1.0), 1.3)
		_merged([[_cm(rt, rb, hs, 40, false, false), _at(Vector3(0, ys + hs / 2.0, 0))]], cloth, root)
		_merged([[_cm(rt - 0.003, rb - 0.003, hs - 0.002, 40, false, false, true), _at(Vector3(0, ys + hs / 2.0, 0))]], liner, root)
	else:
		_lamp_shade(root, ys, hs, rt, rb)
	_merged([[_sm(0.032, 12), _at(Vector3(0, ys + 0.175, 0))]], _plain(Color(0.86, 0.84, 0.78), 0.3), root)
	_collider(Vector3(0.3, ys + hs, 0.3), at + Vector3(0, (ys + hs) / 2.0, 0))


## Abat-jour plissé (lot V2-MERE-FIN, vraie carte) : tissu tissé (Fabric045, CC0) couleur parchemin, 44 plis
## creux, translucide (backlight 0,4 : la lumière passe à travers la toile), doublure intérieure plus claire,
## galons tressés en haut et en bas, cercle bas de l'armature. ys : bas de l'abat-jour, hs : hauteur,
## rt / rb : rayons du haut et du bas.
func _lamp_shade(root: Node3D, ys: float, hs: float, rt: float, rb: float) -> void:
	var cloth := Surfaces.pbr_acg("Fabric045/Fabric045", 0.12, Color(0.98, 0.86, 0.64), 0.5)
	cloth.backlight_enabled = true
	cloth.backlight = Color(0.4, 0.33, 0.22)
	cloth.resource_name = "AbatJour"
	var liner := Surfaces.pbr_acg("Fabric045/Fabric045", 0.12, Color(1.0, 0.95, 0.82), 0.3)
	liner.backlight_enabled = true
	liner.backlight = Color(0.32, 0.27, 0.18)
	var outer := []
	var inner := []
	var ysl := PackedFloat32Array()
	var nring := 6
	var ns := 176
	for i in nring + 1:
		var t := float(i) / nring
		var r := lerpf(rb, rt, t)
		var ro := PackedVector2Array()
		var ri := PackedVector2Array()
		for j in ns:
			var th := TAU * j / ns
			# pli en V arrondi : 44 plis
			var w := absf(fposmod(th * 44.0 / TAU, 1.0) - 0.5) * 2.0
			var d := (w * w * (3.0 - 2.0 * w) - 0.5) * 0.009 * (0.85 + 0.15 * t)
			ro.append(Vector2(cos(th), sin(th)) * (r + d))
			ri.append(Vector2(cos(th), sin(th)) * (r + d - 0.0025))
		outer.append(ro)
		inner.append(ri)
		ysl.append(ys + t * hs)
	var o := _mesh_node(Builder.loft_mesh(outer, ysl, false), cloth, root, "AbatJour", true)
	o.position = Vector3.ZERO
	_mesh_node(Builder.loft_mesh(inner, ysl, false, true), liner, root, "Doublure")
	# galons (haut et bas) et cercle bas de l'armature
	var braid := _grimy(_plain(Color(0.42, 0.33, 0.22), 0.9), 1.3)
	var gal := []
	for e in [[ys + 0.006, rb + 0.004], [ys + hs - 0.006, rt + 0.004]]:
		var tor := TorusMesh.new()
		tor.inner_radius = float(e[1]) - 0.005
		tor.outer_radius = float(e[1]) + 0.004
		tor.rings = 64
		tor.ring_segments = 6
		var tr := _at(Vector3(0, float(e[0]), 0))
		tr.basis = tr.basis.scaled(Vector3(1.0, 1.4, 1.0))
		gal.append([tor, tr])
	_merged(gal, braid, root)
	var wire := TorusMesh.new()
	wire.inner_radius = rb - 0.006
	wire.outer_radius = rb - 0.002
	wire.rings = 48
	wire.ring_segments = 4
	_merged([[wire, _at(Vector3(0, ys + 0.004, 0))]], _grimy(_plain(Color(0.36, 0.28, 0.17), 0.4, 0.85), 1.5), root)


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
	if not Builder.soft_render():
		# (vraie carte, lot V2-MERE-FIN) un vrai manteau de laine, pendu par sa bride à la patère qui
		# regarde la pièce : quelqu'un debout dans le coin, de face
		_hang_coat(root, tips[4], Vector3(cos(TAU * 4.0 / 6.0), 0, sin(TAU * 4.0 / 6.0)))
		_collider(Vector3(0.5, 1.75, 0.5), at + Vector3(0, 0.875, 0))
		return
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


## Le manteau (lot V2-MERE-FIN, vraie carte) : un long pardessus de laine anthracite, pendu par la bride
## de son col au bout de la patère « tip » (repère du portemanteau), le dos contre le fût, le devant vers
## « dir » : épaules de 0,42 m qui tombent depuis le crochet, col, revers croisé, sept plis verticaux qui se
## creusent vers le bas, bas évasé à 1,14 m sous le crochet (on voit le vide dessous), deux manches
## pendantes un peu en avant, trois boutons. Laine : le tissage de Fabric045 (ambientCG, CC0) en normale,
## albédo ≈ 0,06 linéaire, rugosité 1, reflet rasant 0,3 ; dans la cuisson VoxelGI (la lampe accroche les plis).
func _hang_coat(root: Node3D, tip: Vector3, dir: Vector3) -> void:
	var wool := Surfaces.pbr_acg("Fabric045/Fabric045", 0.08, Color(0.29, 0.28, 0.285), 0.7)
	wool.rim_enabled = true
	wool.rim = 0.25
	wool.rim_tint = 0.5
	wool.resource_name = "LaineManteau"
	var holder := Node3D.new()
	holder.name = "Manteau"
	root.add_child(holder)
	holder.position = tip + dir * 0.085 + Vector3(0, 0.012, 0)
	# devant (+z du manteau) vers « dir »
	holder.rotation.y = atan2(dir.x, dir.z)
	var mi := _mesh_node(_coat_mesh(), wool, holder, "Laine", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var btn := []
	for y in [-0.5, -0.66, -0.82]:
		var r := _coat_ring_at(y, 256)
		var q: Vector2 = r[int(round((PI / 2.0 - 0.2) / TAU * 256.0))]
		btn.append([Builder.cylinder_mesh(0.011, 0.011, 0.007, 12, 0.0015), _at(Vector3(q.x, y, q.y + 0.002), Vector3(PI / 2.0, 0, 0))])
	_merged(btn, _plain(Color(0.06, 0.05, 0.045), 0.35), holder)


## L'anneau du corps du manteau à la hauteur y (profil interpolé), « ns » points.
static func _coat_ring_at(y: float, ns: int) -> PackedVector2Array:
	var prof := COAT_PROFILE
	var v := [0.2, 0.1, 0.0]
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		if y >= float(a[0]) and y <= float(b[0]):
			var k := (y - float(a[0])) / (float(b[0]) - float(a[0]))
			v = [lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k)]
			break
	return _coat_ring(v[0], v[1], v[2], y, ns, 0.0045 * smoothstep(-0.02, -0.12, y), 0.0, _coat_top_z(y))


## Le haut du manteau revient vers le crochet (la bride du col est dessus) : décalage du centre des anneaux.
static func _coat_top_z(y: float) -> float:
	return -0.085 * smoothstep(-0.17, 0.0, y)


## [y, demi-largeur, demi-épaisseur, profondeur des plis] du bas (y = -1,14) jusqu'au crochet (y = 0).
const COAT_PROFILE := [
	[-1.14, 0.25, 0.118, 0.032], [-1.0, 0.24, 0.114, 0.028], [-0.85, 0.226, 0.109, 0.022],
	[-0.7, 0.213, 0.105, 0.016], [-0.55, 0.204, 0.102, 0.012], [-0.42, 0.201, 0.101, 0.008],
	[-0.3, 0.207, 0.103, 0.005], [-0.2, 0.212, 0.105, 0.003], [-0.14, 0.206, 0.102, 0.001],
	[-0.1, 0.18, 0.093, 0.0], [-0.07, 0.145, 0.083, 0.0], [-0.045, 0.108, 0.07, 0.0],
	[-0.025, 0.07, 0.052, 0.0], [-0.01, 0.04, 0.034, 0.0], [0.0, 0.018, 0.02, 0.0]]


static func _coat_ring(a: float, b: float, fold: float, y: float, ns: int, lapel: float, cx := 0.0, cz := 0.0) -> PackedVector2Array:
	var ring := PackedVector2Array()
	ring.resize(ns)
	var e := 2.0 / 2.6
	for j in ns:
		var th := TAU * j / ns
		var c := cos(th)
		var sn := sin(th)
		var px := a * signf(c) * pow(absf(c), e)
		var pz := b * signf(sn) * pow(absf(sn), e)
		var nrm := Vector2(px / (a * a), pz / (b * b)).normalized()
		# plis : deux ondes autour du corps, phases fixes, plus marqués sur les grandes faces
		var f := fold * (sin(th * 7.0 + 0.6 + y * 1.3) * 0.55 + sin(th * 12.0 + 2.1 - y * 2.0) * 0.25 + sin(th * 3.0 + 1.3) * 0.35) * (0.45 + 0.55 * absf(sn))
		# le bord du devant (revers croisé) : un ressaut le long de la ligne de boutonnage
		var dl := wrapf(th - (PI / 2.0 - 0.32), -PI, PI)
		f += lapel * exp(-dl * dl / 0.003)
		ring[j] = Vector2(cx, cz) + Vector2(px, pz) + nrm * f
	return ring


static func _coat_mesh() -> ArrayMesh:
	var ns := 64
	var secs := []
	var ys := PackedFloat32Array()
	for r in COAT_PROFILE:
		var y := float(r[0])
		var lap := 0.0045 * smoothstep(-0.02, -0.12, y)
		secs.append(_coat_ring(float(r[1]), float(r[2]), float(r[3]), y, ns, lap, 0.0, _coat_top_z(y)))
		ys.append(y)
	# ourlet inégal : le bas du manteau n'est pas une ligne droite (le tissu pend plus bas par endroits)
	var body := Builder.loft_mesh(secs, ys, false)
	var arr := body.surface_get_arrays(0)
	var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in vv.size():
		var q := vv[i]
		var k := smoothstep(-0.9, -1.14, q.y)
		if k > 0.0:
			var th := atan2(q.z, q.x)
			q.y += k * (0.017 * sin(th * 3.0 + 1.0) + 0.008 * sin(th * 7.0 + 0.4) - 0.01)
			vv[i] = q
	arr[Mesh.ARRAY_VERTEX] = vv
	var body2 := ArrayMesh.new()
	body2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.append_from(body2, 0, Transform3D.IDENTITY)
	# manches : tubes aplatis pendus le long du corps, un peu en avant ; coude froissé, poignet évasé
	for sx in [-1.0, 1.0]:
		var ssecs := []
		var sys := PackedFloat32Array()
		var k := 12
		for i in k + 1:
			var t := float(i) / k              # 0 au poignet, 1 à l'épaule
			var y := lerpf(-0.8, -0.135, t)
			var cx: float = sx * lerpf(0.235, 0.17, t * t)
			var cz := lerpf(0.035, 0.0, t)
			var elbow := exp(-pow((t - 0.45) / 0.12, 2.0))
			var rx := lerpf(0.052, 0.058, t) + 0.006 * (1.0 - t)
			var rz := lerpf(0.06, 0.07, t)
			ssecs.append(_coat_ring(rx, rz, 0.006 + 0.008 * elbow, y * 3.0 + sx, 24, 0.0, cx, cz))
			sys.append(y)
		st.append_from(Builder.loft_mesh(ssecs, sys, false), 0, Transform3D.IDENTITY)
	return st.commit()


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
	# voyant vert du moniteur : allumé avec l'écran (terminal : power_on, extinction du tube)
	if _mon_led and screen_mat:
		var po: Variant = screen_mat.get_shader_parameter("power_on")
		var lit := 1 if po == null or float(po) > 0.5 else 0
		if lit != _mon_led_on:
			_mon_led_on = lit
			_mon_led.emission_energy_multiplier = 2.5 * lit
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
	var soft := Builder.soft_render()
	# (lot V2-MERE) coques modelées en code : unité centrale aux arêtes arrondies, moniteur à façade
	# chanfreinée, dalle en retrait, capot et entonnoir arrière (_build_pc_shell) ; plastique ivoire jauni
	# vers le haut. Mêmes places, même collision, mêmes objets interactifs qu'avant.
	var pcf := Node3D.new()
	pcf.name = "Ordinateur"
	pcf.position = Vector3(x, base, z)
	add_child(pcf)
	_build_pc_shell(pcf, soft)
	# autocollant d'inventaire du laboratoire, sur le flanc de l'unité centrale
	var sticker := _quad(Vector2(0.13, 0.049), Vector3(x + 0.2615, base + 0.07, z + 0.08), _image_mat("ceraf_label.png", 0.5), PI / 2.0)
	sticker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var st_it := _interactable("Regarder l'autocollant", Vector3(0.06, 0.1, 0.18), Vector3(x + 0.28, base + 0.07, z + 0.08))
	st_it.used.connect(func(_i: Interactable) -> void:
		Game.hint("« CERAF · INVENTAIRE N° 0312. Propriété du CERAF, ne pas sortir du site. » L'ordinateur de ta mère vient d'un laboratoire.", 5.0))
	led_mat = _plain(Color(0.15, 0.1, 0.03), 0.4)
	_box(Vector3(0.012, 0.006, 0.003), Vector3(0.03, 0.075, 0.2255), led_mat, false, pcf)
	var my := base + 0.13
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
	screen.name = "Ecran"
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen_mesh = screen
	if not soft:
		# le tube : une calotte bombée de 1,5 cm (même cadre de 0,38 × 0,29, mêmes UV que le quad), et
		# devant, une vitre transparente (reflets de la pièce, une main grasse dans la rugosité)
		screen.mesh = _dome_mesh(0.19, 0.145, 0.015)
		screen.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_build_screen_glass()
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
	_box(Vector3(0.022, 0.009, 0.004), Vector3(0.035, 0.052, 0.2255), mats.dark, false, pcf)
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


## Les coques de l'ordinateur, dans le repère « Ordinateur » (origine au pied de l'unité centrale, sur le
## bureau ; avant vers +z) : unité centrale (0,52 × 0,13 × 0,44, arêtes arrondies, façade chanfreinée),
## façade du lecteur 3½ (fente, voyant et bouton d'éjection aux places d'avant), interrupteur, moniteur
## (_MONITOR_RINGS), plaque de marque, bouton et voyant du moniteur, ouïes (vraie carte). En rendu logiciel :
## les mêmes formes dans la matière beige d'avant, sans ouïes.
func _build_pc_shell(pcf: Node3D, soft: bool) -> void:
	var plastic := _pc_plastic(soft)
	var unit := MeshBuf.new()
	_rr_sweep(unit, [[0.253, 0.058, 0.007, 0.22, 0.0], [0.26, 0.065, 0.011, 0.214, 0.0],
		[0.26, 0.065, 0.011, -0.214, 0.0], [0.253, 0.058, 0.007, -0.22, 0.0]], "cfc",
		Vector3.BACK, Vector3.FORWARD, Transform3D(Basis(), Vector3(0, 0.065, 0)), 4, _pc_tint)
	_mesh_node(unit.mesh(), plastic, pcf, "UniteCentrale", true)
	var mon := MeshBuf.new()
	_rr_sweep(mon, _MONITOR_RINGS, "ffcfcfcffc", Vector3.BACK, Vector3.FORWARD,
		Transform3D(Basis(), Vector3(0, MONITOR_Y, 0)), 3 if soft else 6, _pc_tint)
	_mesh_node(mon.mesh(), plastic, pcf, "Moniteur", true)
	# lecteur de disquettes 3½ dans une baie : façade sombre, fente (la disquette y entre : insert_floppy),
	# voyant (led_mat, posé par _build_pc) et bouton d'éjection
	var bezel := _plain(Color(0.16, 0.155, 0.15), 0.5)
	var parts := [[Builder.box_mesh(Vector3(0.21, 0.04, 0.005)), _at(Vector3(-0.05, 0.066, 0.2215))]]
	_merged(parts, bezel, pcf)
	_box(Vector3(0.1, 0.008, 0.002), Vector3(-0.09, 0.075, 0.2245), mats.dark, false, pcf, 0.0)
	# l'interrupteur (à la place du pavé sombre d'avant) et la rainure du capot
	_box(Vector3(0.05, 0.02, 0.008), Vector3(0.17, 0.06, 0.222), mats.black_plastic, false, pcf)
	_box(Vector3(0.012, 0.012, 0.004), Vector3(0.17, 0.06, 0.2265), mats.dark, false, pcf, 0.0)
	_box(Vector3(0.5, 0.0016, 0.0012), Vector3(0, 0.112, 0.2203), mats.dark, false, pcf, 0.0)
	# moniteur : plaque de marque (sombre, un filet d'aluminium), bouton marche, voyant vert
	var mz := 0.222
	var my := MONITOR_Y
	_box(Vector3(0.062, 0.013, 0.0016), Vector3(-0.15, my + 0.03, mz + 0.0008), mats.dark, false, pcf, 0.0)
	_box(Vector3(0.05, 0.0022, 0.0006), Vector3(-0.15, my + 0.0315, mz + 0.0019), mats.metal, false, pcf, 0.0)
	_box(Vector3(0.024, 0.012, 0.007), Vector3(0.165, my + 0.03, mz + 0.0025), plastic, false, pcf)
	for k in 2:
		var knob := MeshInstance3D.new()
		knob.mesh = Builder.cylinder_mesh(0.0065, 0.007, 0.006, 16)
		knob.material_override = mats.black_plastic
		knob.rotation.x = PI / 2.0
		knob.position = Vector3(0.09 + 0.026 * k, my + 0.03, mz + 0.003)
		knob.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		pcf.add_child(knob)
	_mon_led = _plain(Color(0.05, 0.12, 0.05), 0.35)
	_mon_led.emission_enabled = true
	_mon_led.emission = Color(0.35, 1.0, 0.3)
	_mon_led.emission_energy_multiplier = 0.0
	_box(Vector3(0.006, 0.004, 0.003), Vector3(0.138, my + 0.03, mz + 0.0012), _mon_led, false, pcf, 0.0)
	if soft:
		return
	# ouïes : sur le dessus de l'entonnoir (plan entre ses anneaux 8 et 9) et sur la façade de l'unité
	var r8: Array = _MONITOR_RINGS[8]
	var r9: Array = _MONITOR_RINGS[9]
	var y8: float = r8[4] + r8[1]
	var y9: float = r9[4] + r9[1]
	var z8: float = r8[3]
	var z9: float = r9[3]
	var k := (y8 - y9) / (z8 - z9)
	var zc := -0.075
	var vent := MeshInstance3D.new()
	vent.name = "Ouies"
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.22, 0.2)
	vent.mesh = pm
	vent.material_override = _vent_mat(plastic)
	vent.rotation.x = -atan(k)
	vent.position = Vector3(0, my + y8 + (zc - z8) * k, zc) + Vector3(0, cos(atan(k)), -sin(atan(k))) * 0.0007
	vent.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	vent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pcf.add_child(vent)
	var grille := MeshInstance3D.new()
	grille.name = "OuiesUnite"
	var gq := QuadMesh.new()
	gq.size = Vector2(0.075, 0.034)
	grille.mesh = gq
	grille.material_override = vent.material_override
	grille.position = Vector3(-0.2, 0.066, 0.2206)
	grille.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	grille.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pcf.add_child(grille)


## Bas du moniteur au-dessus du bureau (il repose sur l'unité centrale, haute de 0,13 m, sur deux patins).
const MONITOR_Y := 0.134
## Profil du moniteur, de la dalle vers l'arrière : [demi-largeur, demi-hauteur, rayon des coins, z, centre
## en y] (repère du moniteur : son pied à y = 0, sa façade à z = 0,222 ; l'écran, centré à y = 0,215 et
## z = 0,193, est posé par _build_pc). 0 : fond du creux, derrière le tube ; 1 : bord du cadre (il couvre le
## bord du tube) ; 1→2 : pente intérieure ; 2→3 et 4→5 : chanfreins de 5 mm ; 3→4 : la façade ; 5→6 : le
## capot ; 6→7 : chanfrein ; 7→8 : épaulement ; 8→9 : l'entonnoir (dessus en pente, ouïes) ; 9→10 : le dos.
const _MONITOR_RINGS := [
	[0.193, 0.148, 0.02, 0.187, 0.215],
	[0.186, 0.141, 0.018, 0.205, 0.215],
	[0.202, 0.157, 0.024, 0.2195, 0.215],
	[0.206, 0.161, 0.026, 0.222, 0.215],
	[0.225, 0.195, 0.026, 0.222, 0.2],
	[0.23, 0.2, 0.031, 0.217, 0.2],
	[0.23, 0.2, 0.031, 0.075, 0.2],
	[0.224, 0.194, 0.028, 0.069, 0.199],
	[0.205, 0.178, 0.03, 0.06, 0.196],
	[0.172, 0.152, 0.045, -0.205, 0.162],
	[0.165, 0.145, 0.04, -0.229, 0.161],
]


## Plastique de l'ordinateur et du clavier : ambientCG Plastic004 (CC0 ; grain dans la carte de normales),
## teint en ivoire, satiné, jauni vers le haut par la couleur des sommets (_pc_tint), crasse fine. En rendu
## logiciel : le beige d'avant (aucune variante de shader neuve).
func _pc_plastic(soft: bool) -> StandardMaterial3D:
	if soft or not ResourceLoader.exists("res://assets/textures/Plastic004/Plastic004_albedo.jpg"):
		return mats.beige
	if _plastic == null:
		var m := Surfaces.pbr("Plastic004/Plastic004", 0.6, Color(1.55, 1.56, 1.34), 0.45, false, false, 0.52)
		m.vertex_color_use_as_albedo = true
		_plastic = _grimy(m, 2.0)
	return _plastic


## Jaunissement du plastique (couleur des sommets, multipliée à l'albédo) : ivoire en bas, jaune paille sur
## le dessus du moniteur (la lumière et la chaleur du tube). p : repère « Ordinateur », y au-dessus du bureau.
func _pc_tint(p: Vector3) -> Color:
	var k := smoothstep(0.03, 0.56, p.y)
	return Color(1.0, 0.985 - 0.04 * k, 0.95 - 0.13 * k)


## MeshInstance3D d'un maillage construit, dans « parent ». gi : compté dans la cuisson VoxelGI.
func _mesh_node(mesh: Mesh, mat: Material, parent: Node3D, nm: String, gi := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	if not gi:
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	return mi


## Ouïes moulées : fentes en creux (albédo sombre au fond, relief tiré d'une carte de hauteur par
## Image.bump_map_to_normal_map, comme Builder._normal_from_height), sur le plastique ivoire. Image faite
## une fois (256 × 128, 14 fentes dans le sens de v).
static var _vent_tex: Array = []


func _vent_mat(plastic: StandardMaterial3D) -> StandardMaterial3D:
	if _vent_tex.is_empty():
		var w := 256
		var hh := 128
		var hgt := Image.create(w, hh, false, Image.FORMAT_RGBA8)
		var alb := Image.create(w, hh, false, Image.FORMAT_RGBA8)
		for y in hh:
			for x in w:
				# fentes de 7 px tous les 18 px, arrondies aux bouts, à 10 px des bords
				var cx := fposmod(float(x) - 6.0, 18.0)
				var dx := absf(cx - 4.5) / 3.5
				var dy := maxf(0.0, maxf(14.0 - y, y - (hh - 14.0))) / 3.5
				var inside := Vector2(dx, dy).length() if dy > 0.0 else dx
				var e := 1.0 if x < 8 or x > w - 9 else smoothstep(0.75, 1.15, inside)
				hgt.set_pixel(x, y, Color(e, e, e))
				var a := lerpf(0.08, 1.0, e)
				alb.set_pixel(x, y, Color(a, a, a))
		hgt.bump_map_to_normal_map(6.0)
		hgt.generate_mipmaps()
		alb.generate_mipmaps()
		_vent_tex = [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(hgt)]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _vent_tex[0]
	# (couleur du dessus du moniteur : celle du plastique jauni, à plat)
	var t := _pc_tint(Vector3(0, 0.5, 0))
	var base := Color(0.66, 0.62, 0.52)
	m.albedo_color = Color(base.r * t.r, base.g * t.g, base.b * t.b)
	m.normal_enabled = true
	m.normal_texture = _vent_tex[1]
	m.normal_scale = 0.8
	m.roughness = plastic.roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _grimy(m, 2.0)


## Calotte d'écran : un rectangle de 2 hw × 2 hh bombé de « sag » au centre (bord plan, à z = 0), mêmes UV
## qu'un QuadMesh (u vers la droite, v vers le bas), normales exactes, face vers +z.
static func _dome_mesh(hw: float, hh: float, sag: float, nx := 20, ny := 16) -> ArrayMesh:
	var buf := MeshBuf.new()
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / ny
			var px := (u - 0.5) * 2.0 * hw
			var py := (0.5 - v) * 2.0 * hh
			var fx := 1.0 - (px / hw) * (px / hw)
			var fy := 1.0 - (py / hh) * (py / hh)
			var dzx := sag * (-2.0 * px / (hw * hw)) * fy
			var dzy := sag * fx * (-2.0 * py / (hh * hh))
			buf.add(Vector3(px, py, sag * fx * fy), Vector3(-dzx, -dzy, 1.0).normalized(), Vector2(u, v))
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			buf.tri(a, a + 1, a + nx + 2, Vector3.BACK)
			buf.tri(a, a + nx + 2, a + nx + 1, Vector3.BACK)
	return buf.mesh()


## La vitre du tube, 3 mm devant le phosphore : verre presque noir et transparent, reflet net (sonde de la
## pièce, lampes), fresnel aux bords, et une main grasse (ambientCG Fingerprints004, CC0) qui ne se voit que
## dans le reflet (rugosité). Vraie carte seulement ; cachée en rétro (set_screen_glow_style).
func _build_screen_glass() -> void:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GLASS_SHADER
	m.shader = sh
	var prints := "res://assets/decals/acg/Fingerprints004_albedo.png"
	if ResourceLoader.exists(prints):
		m.set_shader_parameter("prints", load(prints))
	screen_glass = MeshInstance3D.new()
	screen_glass.name = "VitreEcran"
	screen_glass.mesh = _dome_mesh(0.19, 0.145, 0.0155)
	screen_glass.material_override = m
	screen_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen_glass.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	screen_glass.position = screen_center + Vector3(0, 0, 0.003)
	screen_glass.layers = Builder.layer_bit(LAYER_SCREEN_GLASS)
	add_child(screen_glass)


const GLASS_SHADER := """
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_never, cull_back, specular_schlick_ggx;
uniform sampler2D prints : hint_default_transparent, filter_linear_mipmap, repeat_disable;
// la main : 0,2 m de large, posée en bas à droite de la dalle (mètres depuis le coin haut gauche)
uniform vec2 print_at = vec2(0.17, 0.09);
uniform float print_size = 0.2;
void fragment() {
	vec2 m = UV * vec2(0.38, 0.29);
	vec2 pu = (m - print_at) / print_size;
	float p = 0.0;
	if (pu.x >= 0.0 && pu.x <= 1.0 && pu.y >= 0.0 && pu.y <= 1.0) {
		p = texture(prints, pu).a;
	}
	vec2 e = abs(UV - 0.5) * 2.0;
	float edge = smoothstep(0.75, 1.0, max(e.x, e.y));
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	ALBEDO = vec3(0.012, 0.014, 0.014);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ROUGHNESS = clamp(0.06 + p * 0.32 + edge * 0.12, 0.0, 1.0);
	ALPHA = clamp(0.05 + f * 0.45 + p * 0.04 + edge * 0.06, 0.0, 1.0);
}
"""


## Tampon de maillage (sommets, normales, UV, UV2, couleurs, indices) pour les coques modelées en code.
## Chaque triangle est tourné vers la normale voulue (sens des aiguilles d'une montre vu de devant, comme
## Godot l'attend).
class MeshBuf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	func add(p: Vector3, nn: Vector3, t: Vector2, c := Color.WHITE, t2 := Vector2(-1.0, -1.0)) -> int:
		v.append(p)
		n.append(nn)
		uv.append(t)
		uv2.append(t2)
		col.append(c)
		return v.size() - 1

	func tri(a: int, b: int, c: int, want: Vector3) -> void:
		if (v[b] - v[a]).cross(v[c] - v[a]).dot(want) < 0.0:
			idx.append_array([a, b, c])
		else:
			idx.append_array([a, c, b])

	## Normales lissées d'après les triangles (pondérées par leur aire), pour les formes libres.
	func smooth_normals() -> void:
		for i in n.size():
			n[i] = Vector3.ZERO
		for t in range(0, idx.size(), 3):
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			var f := -(v[b] - v[a]).cross(v[c] - v[a])
			n[a] += f
			n[b] += f
			n[c] += f
		for i in n.size():
			n[i] = n[i].normalized() if n[i].length() > 1e-12 else Vector3.UP

	func mesh(with_uv2 := false) -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		if with_uv2:
			arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		var raw := ArrayMesh.new()
		raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var st := SurfaceTool.new()
		st.create_from(raw, 0)
		st.generate_tangents()
		return st.commit()


## Coque balayée le long de rectangles arrondis. rings : [a, b, r, z, yc] = demi-largeur (x), demi-hauteur
## (y), rayon des coins, position en z, centre en y. Le profil va de l'intérieur vers l'extérieur et de
## l'avant (+z) vers l'arrière (fond d'un creux → bord → façade → flancs → dos) ; flip = true pour un profil
## qui monte vers +z (touches, socle du clavier, une fois tournés). kinds : une lettre par bande, « f »
## face plane (sa normale), « c » chanfrein (à chaque bout, la normale de la bande voisine ou du fond : la
## lumière y glisse comme sur une arête arrondie, les faces restent planes). cap0, cap1 : normale d'un fond
## plat au premier, au dernier anneau (Vector3.ZERO : pas de fond). xf : placement ; tint(xf * p) : couleur de
## sommet ; uv2_cap(p) : UV2 des sommets du fond cap1 (légendes des touches), (-1, -1) ailleurs. UV : u =
## abscisse le long du contour (m), v = longueur du profil (m). seg : segments par coin.
static func _rr_sweep(buf: MeshBuf, rings: Array, kinds: String, cap0: Vector3, cap1: Vector3, xf := Transform3D(),
		seg := 4, tint := Callable(), flip := false, uv2_cap := Callable()) -> void:
	var nr := rings.size()
	var m := 4 * (seg + 1)
	var P: Array = []
	var tc := PackedVector3Array()
	tc.resize(m)
	for i in nr:
		var rg: Array = rings[i]
		var a: float = rg[0]
		var b: float = rg[1]
		var r: float = minf(rg[2], minf(a, b))
		var ring := PackedVector3Array()
		ring.resize(m)
		var j := 0
		for k in 4:
			var sx := 1.0 if k == 0 or k == 3 else -1.0
			var sy := 1.0 if k < 2 else -1.0
			for s in seg + 1:
				var th := PI / 2.0 * (k + float(s) / seg)
				ring[j] = Vector3(sx * (a - r) + r * cos(th), float(rg[4]) + sy * (b - r) + r * sin(th), float(rg[3]))
				tc[j] = Vector3(-sin(th), cos(th), 0.0)
				j += 1
		P.append(ring)
	var sg := -1.0 if flip else 1.0
	var bn: Array = []
	for i in nr - 1:
		var lo: PackedVector3Array = P[i]
		var hi: PackedVector3Array = P[i + 1]
		var row := PackedVector3Array()
		row.resize(m)
		for j in m:
			var nn := (hi[j] - lo[j]).cross(tc[j]) * sg
			row[j] = nn.normalized() if nn.length() > 1e-10 else Vector3(tc[j].y, -tc[j].x, 0.0)
		bn.append(row)
	var vlen := PackedFloat32Array()
	vlen.resize(nr)
	vlen[0] = 0.0
	for i in nr - 1:
		var lo: PackedVector3Array = P[i]
		var hi: PackedVector3Array = P[i + 1]
		var s := 0.0
		for j in m:
			s += (hi[j] - lo[j]).length()
		vlen[i + 1] = vlen[i] + s / m
	var nb := xf.basis.orthonormalized()
	for i in nr - 1:
		var kind := kinds.substr(i, 1) if i < kinds.length() else "f"
		var rows := [PackedInt32Array(), PackedInt32Array()]
		for e in 2:
			var ri := i + e
			var ring: PackedVector3Array = P[ri]
			var u := 0.0
			var ids := PackedInt32Array()
			for j in m + 1:
				var jj := j % m
				if j > 0:
					u += ring[jj].distance_to(ring[j - 1])
				var nn: Vector3 = bn[i][jj]
				if kind == "c":
					var other := i - 1 if e == 0 else i + 1
					if other >= 0 and other < nr - 1:
						nn = bn[other][jj]
					elif e == 0 and cap0 != Vector3.ZERO:
						nn = cap0
					elif e == 1 and cap1 != Vector3.ZERO:
						nn = cap1
				var p := xf * ring[jj]
				ids.append(buf.add(p, (nb * nn).normalized(), Vector2(u, vlen[ri]), tint.call(p) if tint.is_valid() else Color.WHITE))
			rows[e] = ids
		for j in m:
			var want := nb * (bn[i][j] as Vector3)
			var a0: int = rows[0][j]
			var a1: int = rows[0][j + 1]
			var b1: int = rows[1][j + 1]
			var b0: int = rows[1][j]
			buf.tri(a0, a1, b1, want)
			buf.tri(a0, b1, b0, want)
	for e in 2:
		var dir: Vector3 = cap0 if e == 0 else cap1
		if dir == Vector3.ZERO:
			continue
		var ri := 0 if e == 0 else nr - 1
		var ring: PackedVector3Array = P[ri]
		var rg: Array = rings[ri]
		var ctr := Vector3(0.0, float(rg[4]), float(rg[3]))
		var nn := (nb * dir).normalized()
		var with2 := e == 1 and uv2_cap.is_valid()
		var pc := xf * ctr
		var c0 := buf.add(pc, nn, Vector2(ctr.x, ctr.y), tint.call(pc) if tint.is_valid() else Color.WHITE,
			uv2_cap.call(ctr) if with2 else Vector2(-1.0, -1.0))
		var ids := PackedInt32Array()
		for j in m:
			var p := xf * ring[j]
			ids.append(buf.add(p, nn, Vector2(ring[j].x, ring[j].y), tint.call(p) if tint.is_valid() else Color.WHITE,
				uv2_cap.call(ring[j]) if with2 else Vector2(-1.0, -1.0)))
		for j in m:
			buf.tri(c0, ids[j], ids[(j + 1) % m], nn)


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
	screen_light.light_cull_mask = 0xFFFFF & ~Builder.layer_bit(LAYER_SCREEN_GLASS)
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
		# (lot V2-MERE) rendu net : le phosphore au-dessus de 1 (le halo de l'image le fait irradier), un
		# peu de halation, lignes de balayage sans moiré ; rétro : l'écran d'avant
		screen_mat.set_shader_parameter("hdr_gain", 1.0 if retro else SCREEN_HDR_GAIN)
		screen_mat.set_shader_parameter("halation", 0.0 if retro else SCREEN_HALATION)
		screen_mat.set_shader_parameter("scan_aa", 0.0 if retro else 1.0)
	if screen_glass:
		screen_glass.visible = not retro


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


# ------------------------------------------------------------------ habillage différé (lot V2-MERE)

## Objets de décor (Builder.detail) et usure (Wear) de la chambre : appelé par Main après la mesure de B16,
## seulement avec une vraie carte graphique (R3). Rien d'interactif, aucune collision, rien sur le trajet
## départ → bureau → armoire → porte : tout est posé sur des meubles ou contre les murs.
func dress_details() -> void:
	_detail_objects()
	_fill_room()
	_wear_room()
	if decor and decor.has_method("dress"):
		decor.dress()


func _detail_objects() -> void:
	# un réveil mécanique sur la commode, arrêté lui aussi à 3 h 12 (le radio-réveil du chevet clignote)
	var clk := detail("alarm_clock_01", Vector3(0.665, _dresser_top, 2.46), 194.0, Vector3.ZERO, {"sync": true})
	if clk:
		_set_clock_hands(clk, 3, 12, 41)
	# trois cartes postales scotchées au mur, autour du tableau en liège
	_postcard(4, Vector3(0.78, 1.84, -2.6 + 0.0035), -7.0)
	_postcard(11, Vector3(0.72, 1.64, -2.6 + 0.0045), 5.0)
	_postcard(17, Vector3(1.94, 1.76, -2.6 + 0.0035), 4.0)
	# le baladeur, couché sur le chevet ; la manette rangée à côté des cassettes vidéo
	var wk := detail("portable_cassette_player", Vector3(-2.84, _night_top + 0.021, 0.16), 0.0, Vector3.ZERO, {"sync": true})
	if wk:
		wk.rotation = Vector3(-PI / 2.0, deg_to_rad(104.0), 0.0)
	detail("gamepad", Vector3(2.9, 0.762, -2.36), 200.0, Vector3(0.32, 0.0, 0.34), {"sync": true})
	# un coussin carré à chevrons, debout contre la tête du lit, derrière l'oreiller (le coussin droit du
	# modèle, tourné face à la pièce ; l'autre, couché, est caché)
	var tp := detail("throw_pillows_01", Vector3(-2.64, 0.375, 0.9), 0.0, Vector3(0.8, 0.0, 0.0), {"sync": true})
	if tp:
		var p1 := tp.find_child("throw_pillows_01_pillow01", true, false) as Node3D
		if p1:
			p1.visible = false
		var p2 := tp.find_child("throw_pillows_01_pillow02", true, false) as Node3D
		if p2:
			tp.rotation_degrees.y = 14.6
			var b := _aabb_of(p2, self)
			tp.position += Vector3(-2.66 - b.get_center().x, 0.0, 0.615 - b.position.z)
	# câbles du clavier et de la souris, jusqu'à l'arrière de l'unité centrale (par sa droite)
	if decor and decor.has_method("_tube"):
		var t := desk_top
		var cable := _grimy(_plain(Color(0.55, 0.53, 0.48), 0.55), 2.0)
		decor._tube([Vector3(1.25, t + 0.012, -2.086), Vector3(1.4, t + 0.0035, -2.112), Vector3(1.495, t + 0.0035, -2.17),
			Vector3(1.5, t + 0.0035, -2.4), Vector3(1.44, t + 0.03, -2.56)], 0.0032, cable)
		decor._tube([Vector3(1.616, t + 0.01, -2.07), Vector3(1.6, t + 0.0032, -2.13), Vector3(1.54, t + 0.0032, -2.2),
			Vector3(1.535, t + 0.0032, -2.42), Vector3(1.45, t + 0.04, -2.57)], 0.0026, cable)


## Habiter la chambre (lot V2-MERE-FIN ; vraie carte, après la mesure de B16) : la pièce de 6,4 × 5,2 m
## paraissait vide entre le tapis et les murs. Un fauteuil bergère (ArmChair_01, Poly Haven, CC0) contre le
## mur de la porte, tourné vers la fenêtre, un plaid plié dessus ; un guéridon et ses livres à côté ; un
## carton ouvert (des pulls, des papiers) au pied du mur sud ; des pantoufles au bord du lit. Tout est hors
## du trajet départ → bureau → armoire → porte, loin des boîtes d'interaction et des empreintes ; le
## fauteuil et le guéridon ont leur collision (nommées « Fauteuil » et « Gueridon »).
func _fill_room() -> void:
	var chair_at := Vector3(2.72, 0.0, -0.82)
	# (tissu gris clair du modèle passé en vieux rose fané, bois plus sombre : il ne doit pas briller dans la
	# vue de départ, à côté de l'écran)
	var arm := detail("ArmChair_01", chair_at, -80.0, Vector3.ZERO, {"sync": true, "shadow": true, "tint": Color(0.6, 0.47, 0.44)})
	if arm == null:
		return
	var col := _collider(Vector3(0.76, 0.95, 0.84), chair_at + Vector3(0, 0.475, 0))
	col.name = "Fauteuil"
	# plaid de laine plié en quatre sur l'assise
	var plaid := MeshInstance3D.new()
	plaid.name = "Plaid"
	plaid.mesh = pillow_mesh(0.42, 0.34, 0.05)
	plaid.material_override = _rug_mat(Color(0.33, 0.2, 0.16))
	plaid.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	arm.add_child(plaid)
	plaid.position = Vector3(0.04, PLAID_Y, 0.1)
	plaid.rotation = Vector3(0.04, 0.32, 0.02)
	# guéridon, entre le fauteuil et la bibliothèque, trois livres dessus
	var table_at := Vector3(2.95, 0.0, -1.62)
	var gt := detail("side_table_tall_01", table_at, 15.0, Vector3(0, 0.66, 0), {"sync": true, "shadow": true})
	if gt:
		_collider(Vector3(0.36, 0.66, 0.36), table_at + Vector3(0, 0.33, 0)).name = "Gueridon"
		var top := 0.66
		if gt.has_meta("size"):
			top = (gt.get_meta("size") as Vector3).y
		var dk := DECOR_GD
		if not dk._book_data().is_empty():
			var bufs := {}
			var y := top
			var books := [[0.15, 0.035, 0.22, 0.3, 12], [0.14, 0.028, 0.2, -0.15, 33], [0.12, 0.02, 0.18, 0.5, 5]]
			for b in books:
				dk.book_add(bufs, dk.flat_book_xf(Vector3(b[0], b[1], b[2]), table_at + Vector3(0.02, y, 0.0), b[3]), b[1], b[2], b[0], b[4])
				y += float(b[1])
			dk.books_commit(bufs, self, "LivresGueridon")
	_open_box(Vector3(-0.55, 0.0, 2.3), PI - 0.1)
	_slippers(Vector3(-1.9, 0.0, 1.0))


const PLAID_Y := 0.43
const DECOR_GD := preload("res://scripts/decor.gd")


## Un carton de déménagement ouvert (kraft du modèle cardboard_box_01 en triplanaire), rabats ouverts, des
## pulls pliés et des papiers dedans. « at » : le pied du carton ; rot : lacet.
func _open_box(at: Vector3, rot: float) -> void:
	var holder := Node3D.new()
	holder.name = "CartonOuvert"
	add_child(holder)
	holder.position = at
	holder.rotation.y = rot
	var kraft := StandardMaterial3D.new()
	kraft.albedo_texture = load("res://assets/models/polyhaven/cardboard_box_01/textures/cardboard_box_01_diff_1k.jpg")
	kraft.normal_enabled = true
	kraft.normal_texture = load("res://assets/models/polyhaven/cardboard_box_01/textures/cardboard_box_01_nor_gl_1k.jpg")
	kraft.normal_scale = 0.6
	kraft.roughness = 0.88
	Surfaces.world_uv(kraft, 0.6)
	var L := 0.5
	var H := 0.34
	var D := 0.36
	var t := 0.005
	var parts := [
		[Builder.box_mesh(Vector3(L, t, D), 0.0), _at(Vector3(0, t / 2.0, 0))],
		[Builder.box_mesh(Vector3(L, H, t), 0.0), _at(Vector3(0, H / 2.0, D / 2.0 - t / 2.0))],
		[Builder.box_mesh(Vector3(L, H, t), 0.0), _at(Vector3(0, H / 2.0, -D / 2.0 + t / 2.0))],
		[Builder.box_mesh(Vector3(t, H, D - 2.0 * t), 0.0), _at(Vector3(L / 2.0 - t / 2.0, H / 2.0, 0))],
		[Builder.box_mesh(Vector3(t, H, D - 2.0 * t), 0.0), _at(Vector3(-L / 2.0 + t / 2.0, H / 2.0, 0))],
	]
	# rabats : le long de devant (+z) retombe vers la pièce, celui de derrière reste dressé contre le mur,
	# les courts s'ouvrent sur les côtés
	var flaps := [[Vector3(0, H, D / 2.0), Vector3(L - 0.004, D / 2.0, t), Vector3(2.1, 0, 0), 1.0],
		[Vector3(0, H, -D / 2.0), Vector3(L - 0.004, D / 2.0, t), Vector3(-0.35, 0, 0), -1.0],
		[Vector3(L / 2.0, H, 0), Vector3(t, L / 2.0 * 0.62, D - 0.01), Vector3(0, 0, -2.0), 1.0],
		[Vector3(-L / 2.0, H, 0), Vector3(t, L / 2.0 * 0.62, D - 0.01), Vector3(0, 0, 1.55), -1.0]]
	for f in flaps:
		var hinge: Vector3 = f[0]
		var size: Vector3 = f[1]
		var b := Basis.from_euler(f[2])
		parts.append([Builder.box_mesh(size, 0.0), Transform3D(b, hinge + b * Vector3(0, size.y / 2.0, 0))])
	var box := _merged(parts, _grimy(kraft, 1.6), holder, false)
	box.name = "Carton"
	# dedans : deux pulls pliés, une liasse de papiers debout
	var p1 := MeshInstance3D.new()
	p1.mesh = pillow_mesh(0.4, 0.28, 0.1)
	p1.material_override = _rug_mat(Color(0.3, 0.32, 0.38))
	p1.position = Vector3(0.02, H - 0.06, -0.02)
	p1.rotation = Vector3(0.06, 0.1, -0.04)
	holder.add_child(p1)
	var p2 := MeshInstance3D.new()
	p2.mesh = pillow_mesh(0.34, 0.24, 0.08)
	p2.material_override = _rug_mat(Color(0.5, 0.42, 0.33))
	p2.position = Vector3(-0.04, H + 0.02, 0.03)
	p2.rotation = Vector3(-0.1, -0.35, 0.12)
	holder.add_child(p2)
	var paper := _plain(Color(0.84, 0.81, 0.72), 0.95)
	_merged([[Builder.box_mesh(Vector3(0.21, 0.29, 0.012), 0.0), _at(Vector3(0.12, H - 0.02, -0.14), Vector3(-0.25, 0.1, 0.05))],
		[Builder.box_mesh(Vector3(0.21, 0.29, 0.004), 0.0), _at(Vector3(0.1, H - 0.0, -0.12), Vector3(-0.4, -0.05, -0.08))]], paper, holder)
	_collider(Vector3(0.5, 0.36, 0.38), at + Vector3(0, 0.18, 0)).name = "CartonOuvertCol"


## Pantoufles en feutre au bord du lit, l'une un peu de travers.
func _slippers(at: Vector3) -> void:
	var felt := _rug_mat(Color(0.42, 0.27, 0.28))
	var sole := _plain(Color(0.12, 0.1, 0.09), 0.85)
	for k in 2:
		var h := Node3D.new()
		h.name = "Pantoufle%d" % (k + 1)
		add_child(h)
		h.position = at + Vector3(0.0, 0.0, -0.06 if k == 0 else 0.07)
		h.rotation.y = deg_to_rad(-84.0 if k == 0 else -62.0)
		var up := MeshInstance3D.new()
		up.mesh = pillow_mesh(0.1, 0.25, 0.065)
		up.material_override = felt
		up.position = Vector3(0, 0.04, 0)
		h.add_child(up)
		var so := MeshInstance3D.new()
		so.mesh = Builder.rounded_box_mesh(Vector3(0.098, 0.016, 0.26), 0.007, 3)
		so.material_override = sole
		so.position = Vector3(0, 0.008, 0)
		h.add_child(so)
		# l'ouverture : un creux sombre sur l'arrière du dessus
		var hole := MeshInstance3D.new()
		hole.mesh = pillow_mesh(0.07, 0.1, 0.02)
		hole.material_override = _plain(Color(0.08, 0.06, 0.06), 1.0)
		hole.position = Vector3(0, 0.066, 0.055)
		h.add_child(hole)


## Règle les aiguilles d'un réveil Poly Haven (alarm_clock_01 : nœuds « houd_hand », « minute_hand »,
## « second_hand », tournant autour de leur origine, cadran vers +z) sur h:m:s.
func _set_clock_hands(holder: Node3D, h: int, mnt: int, s: int) -> void:
	var want := {"houd_hand": (float(h % 12) + mnt / 60.0) / 12.0, "minute_hand": (mnt + s / 60.0) / 60.0,
		"second_hand": s / 60.0}
	for nm in want:
		var hand := holder.find_child(nm, true, false) as MeshInstance3D
		if hand == null or hand.mesh == null:
			continue
		# la pointe : le sommet le plus loin de l'axe, dans le repère du cadran
		var tip := Vector2.ZERO
		for si in hand.mesh.get_surface_count():
			var verts: PackedVector3Array = hand.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for p in verts:
				var q := hand.transform.basis * p
				if Vector2(q.x, q.y).length() > tip.length():
					tip = Vector2(q.x, q.y)
		var now := atan2(tip.x, tip.y)          # angle depuis midi, sens des aiguilles d'une montre
		hand.transform.basis = Basis(Vector3.BACK, now - TAU * float(want[nm])) * hand.transform.basis


## Une carte postale de postcard_set_01 (Poly Haven ; la k-ième des 20), au mur en « pos » (centre de la
## carte, face vers +z), penchée de « roll » degrés, deux bouts de ruban adhésif en haut.
func _postcard(k: int, pos: Vector3, roll: float) -> void:
	var h := detail("postcard_set_01", pos, 0.0, Vector3.ZERO, {"sync": true})
	if h == null:
		return
	var keep := "postcard_%02d" % k
	var card: Node3D = null
	for n in h.find_children("postcard_*", "MeshInstance3D", true, false):
		if String(n.name) == keep:
			card = n as Node3D
		else:
			(n as Node3D).visible = false
	var model := h.get_node_or_null("Modele") as Node3D
	if card == null or model == null:
		return
	var box := _aabb_of(card, h)
	model.position -= box.get_center()
	h.rotation.z = deg_to_rad(roll)
	if _tape_mat == null:
		_tape_mat = _plain(Color(0.74, 0.7, 0.56), 0.5)
	for sx in [-1.0, 1.0]:
		var t := _box(Vector3(0.034, 0.012, 0.0006), Vector3(sx * (box.size.x / 2.0 - 0.01), box.size.y / 2.0 - 0.006, 0.0008), _tape_mat, false, h, 0.0)
		t.rotation.z = sx * 0.6
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Usure de la chambre (Wear, lot V1-USURE) : crasse de pied de mur, coulures sous la fenêtre, traces de
## doigts autour de l'interrupteur et des poignées de l'armoire, chemins usés (porte → bureau, porte → lit),
## poussière sur l'appui de fenêtre et sur l'armoire. (Taches du plafond et moisissure : decor.dress.)
## Rien en Basse ni en rendu logiciel (Wear.deco_on).
func _wear_room() -> void:
	if not Wear.deco_on():
		return
	Wear.wall_base(self, 0.22, {"gaps": [Rect2(-3.06, -2.6, 1.02, 0.6), Rect2(2.4, -2.6, 0.77, 0.46),
		Rect2(1.97, -2.6, 0.3, 0.42)]})
	var fz := (WIN_Z0 + WIN_Z1) / 2.0
	# (l'eau blanchit le vernis sombre du lambris : des coulures plus claires que le bois)
	var wood_leak := Color(0.85, 0.76, 0.63)
	Wear.decal(self, "coulure", Vector3(-W / 2.0 + 0.012, 0.6, -1.06), Vector3.RIGHT, Vector3.UP, 0.3, 0.62,
		{"world": true, "variant": 0, "color": wood_leak, "mix": 0.85})
	Wear.decal(self, "coulure", Vector3(-W / 2.0 + 0.012, 0.66, 0.16), Vector3.RIGHT, Vector3.UP, 0.24, 0.5,
		{"world": true, "variant": 3, "color": wood_leak, "mix": 0.75})
	# traces de doigts : l'interrupteur (plaque et mur autour), les poignées des portes de l'armoire
	Wear.decal(self, "traces_doigts", Vector3(W / 2.0 - 0.012, 1.24, 0.72), Vector3.LEFT, Vector3.UP, 0.2, 0.24,
		{"world": true, "variant": 0, "color": Color(0.5, 0.46, 0.4), "mix": 0.45})
	for d in wardrobe_doors:
		var holder := d.get_node_or_null("Moulures") as Node3D
		var dm := d as MeshInstance3D
		if holder == null or dm == null or holder.scale.x == 0.0:
			continue
		var ab := dm.get_aabb()
		var s := Vector3(1.0 / holder.scale.x, 1.0 / holder.scale.y, 1.0 / holder.scale.z)
		var x0 := ab.position.x * s.x
		var x1 := ab.end.x * s.x
		# la charnière est à l'origine de la porte : la poignée, du côté opposé
		var inner := x1 if absf(x0) < absf(x1) else x0
		var c := Vector3(inner - signf(inner) * 0.07, ab.position.y * s.y + 0.74, 0.004)
		Wear.decal(holder, "traces_doigts", c, Vector3.BACK, Vector3.UP, 0.16, 0.22,
			{"variant": 0, "color": Color(0.45, 0.36, 0.3), "mix": 0.4, "depth": 0.03})
	# chemins usés dans le vernis du parquet : de la porte au bureau, de la porte au lit (le long du tapis)
	Wear.path(self, [Vector2(2.85, 1.42), Vector2(1.75, 1.5), Vector2(1.62, 0.3), Vector2(1.36, -1.28)], 0.5)
	Wear.path(self, [Vector2(1.75, 1.55), Vector2(0.2, 1.63), Vector2(-1.85, 1.5)], 0.45)
	# poussière : l'appui de la fenêtre, le dessus de l'armoire
	Wear.decal(self, "poussiere", Vector3(-W / 2.0 + 0.1, WIN_Y0 - 0.002, fz), Vector3.UP, Vector3.RIGHT, 1.6, 0.24,
		{"world": true, "alpha": 0.8})
	Wear.decal(self, "poussiere", Vector3(-2.55, 2.14, -2.3), Vector3.UP, Vector3.BACK, 1.05, 0.6, {"world": true})
	# (lot V2-MERE-FIN) poussière dans les angles du fond de l'étagère de la disquette, loin de la disquette
	Wear.decal(self, "poussiere", Vector3(-2.88, 1.032, -2.46), Vector3.UP, Vector3.BACK, 0.22, 0.14,
		{"world": true, "alpha": 0.75, "depth": 0.03})
	Wear.decal(self, "poussiere", Vector3(-2.2, 1.032, -2.47), Vector3.UP, Vector3.BACK, 0.24, 0.12,
		{"world": true, "alpha": 0.75, "depth": 0.03})


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
	var soft := Builder.soft_render()
	var mat: Material
	if soft:
		# (rendu logiciel : la matière d'avant, aucune variante de shader neuve pendant le sursaut)
		var sm0 := StandardMaterial3D.new()
		sm0.albedo_texture = load("res://assets/models/face/Map-COL.jpg")
		sm0.albedo_color = Color(0.55, 0.53, 0.5)
		sm0.roughness = 0.7
		mat = sm0
	else:
		mat = _face_material()
	for mi in face.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	# orbites vides (repère du modèle scanné) ; vraie carte : plus profondes (le pourtour s'assombrit dans
	# FACE_SHADER), et un fond humide qui accroche la lumière d'en dessous
	var black := _plain(Color(0.0, 0.0, 0.0), 1.0)
	if not soft:
		black = _plain(Color(0.006, 0.004, 0.004), 0.07)
		black.metallic_specular = 0.9
	for ex in [-0.70, 0.52]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.42
		eye.mesh = sm
		eye.material_override = black
		eye.position = Vector3(ex, 1.68, 1.98 if soft else 1.9)
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
	# le joueur se retourne d'un coup. Réglage « Mouvements de la caméra » (Game.mouvements_camera, 1 par
	# défaut : le virage d'avant, 0,3 s) : en dessous de 50 %, une coupe franche (deux images noires, et l'on
	# est déjà retourné) ; au-dessus, le virage s'allonge jusqu'à 0,42 s à 50 %. Aucun tirage en plus.
	var from_yaw: float = p.yaw
	var moves := clampf(float(Game.mouvements_camera), 0.0, 1.0)
	var hud: Node = null
	var hud_a := -1.0
	if moves < 0.5:
		hud = get_tree().get_first_node_in_group("hud")
		var fade_rect: ColorRect = hud.get("fade") if hud else null
		if fade_rect:
			hud_a = fade_rect.color.a
			fade_rect.color.a = 1.0
		for i in 2:
			await get_tree().process_frame
		p.set_look(from_yaw + PI * 0.92, 0.02)
	else:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(k: float) -> void: p.set_look(from_yaw + PI * 0.92 * k, 0.02), 0.0, 1.0, 0.3 * (1.6 - 0.6 * moves))
		await tw.finished
	var fwd := -cam.global_transform.basis.z
	face.global_position = cam.global_position + fwd * 0.5 + Vector3(0, -0.07, 0)
	face.look_at(cam.global_position + Vector3(0, -0.07, 0), Vector3.UP, true)
	face.visible = true
	if hud_a >= 0.0 and is_instance_valid(hud):
		(hud.get("fade") as ColorRect).color.a = hud_a
	var screen_e := screen_light.light_energy
	screen_light.light_energy = 0.03
	Sfx.sting(0.0)
	var post := get_tree().get_first_node_in_group("retro")
	if post:
		post.material.set_shader_parameter("corruption", 1.0)
	# la secousse de la tête : la couche « présence » de la caméra (lot V2-PRESENCE ; sans effet tant
	# qu'elle n'existe pas). Jamais en « Sursauts réduits » (ce chemin-là s'arrête plus haut).
	get_tree().call_group("presence", "add_trauma", 1.0, true)
	# (rendu net hors rétro, lot V2-MERE-FIN : le plafonnier bat plus bas, 0,9 / 0,05 au lieu de 2,5 / 0,2 :
	# la pièce reste dans la pénombre et le visage, éclairé par en dessous, en sort ; mêmes tirages)
	var hi_e := 2.5
	var lo_e := 0.2
	var under_hi := 0.9
	var under_lo := 0.15
	if Qualite.extras_on():
		hi_e = 0.9
		lo_e = 0.05
		under_hi = 1.3
		under_lo = 0.25
	var t := 0.0
	while t < 1.0:
		face.global_position -= fwd * 0.006   # il avance
		under.light_energy = under_hi if rng.randf() < 0.65 else under_lo
		if not ceiling_dead:
			ceiling_light.light_energy = hi_e if rng.randf() < 0.5 else lo_e
		# (les deux tirages de l'ancienne secousse, gardés : la suite des tirages ne change pas)
		rng.randf_range(-1, 1)
		rng.randf_range(-1, 1)
		await get_tree().create_timer(0.04, false).timeout
		t += 0.04
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

## La peau du visage, vraie carte (lots V2-MERE et V2-MERE-FIN) : la carte de normales du scan (déjà
## livrée) ; rugosité de peau mate (crâne 0,55, front 0,42, joues et lèvres 0,45 ; SPECULAR 0,35 : plus de
## crâne chromé sous le plafonnier) ; orbites creusées (le pourtour des yeux s'assombrit). Sous le cou, le
## buste ne noircit plus : il se DISSOUT (alpha haché, ALPHA_HASH_SCALE : la matière reste opaque, avec sa
## profondeur et ses ombres ; FSR 2 et le TAA lissent la trame), le long d'une limite déchiquetée par deux
## octaves de bruit dans le repère du modèle : la pièce se voit à travers, plus de masse noire découpée.
## Transluminescence de la peau (passe plein écran) seulement à partir d'Élevée, ni en rendu logiciel, ni en
## rétro. Repère du modèle scanné (non mis à l'échelle) : yeux en (-0,70 ; 1,68) et (0,52 ; 1,68), haut du
## crâne à y = 4, menton vers -1, épaules à -4.
func _face_material() -> ShaderMaterial:
	var sss := Qualite.extras_on() and Qualite.at_least(Qualite.ELEVEE)
	var sh := Shader.new()
	sh.code = FACE_SHADER.replace("{MODE}", ", sss_mode_skin" if sss else "") \
		.replace("{SSS}", "SSS_STRENGTH = 0.5;" if sss else "")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo_tex", load("res://assets/models/face/Map-COL.jpg"))
	m.set_shader_parameter("normal_tex", load("res://assets/models/face/Infinite-Level_02_Tangent_SmoothUV.jpg"))
	return m


const FACE_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx{MODE};
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec3 tint = vec3(0.55, 0.53, 0.5);
uniform vec3 eye_l = vec3(-0.7, 1.68, 1.95);
uniform vec3 eye_r = vec3(0.52, 1.68, 1.95);
uniform vec2 neck = vec2(-2.9, -1.3);
uniform float ragged = 1.3;
varying vec3 obj;
float h3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vn(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	obj = VERTEX;
}
void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb * tint;
	float d = min(distance(obj, eye_l), distance(obj, eye_r));
	float sock = smoothstep(0.3, 1.05, d);
	float n = vn(obj * 0.9) * 0.65 + vn(obj * 2.7 + vec3(7.1)) * 0.35;
	float fade = smoothstep(neck.x, neck.y, obj.y + (n - 0.5) * ragged);
	ALBEDO = a * mix(0.1, 1.0, sock);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	float skull = smoothstep(2.7, 3.3, obj.y);
	float brow = smoothstep(1.95, 2.35, obj.y) * (1.0 - skull);
	ROUGHNESS = mix(mix(0.45, 0.42, brow), 0.55, skull);
	SPECULAR = 0.35 * mix(0.3, 1.0, sock);
	AO = mix(0.3, 1.0, sock);
	AO_LIGHT_AFFECT = 0.7;
	ALPHA = fade;
	ALPHA_HASH_SCALE = 1.0;
	{SSS}
}
"""


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
