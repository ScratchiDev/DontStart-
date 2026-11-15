extends Builder
## Banc d'essai (exclu de l'export) : la galerie des modèles réalistes. Pour chaque nom Kenney de la
## table PH_FOR_KENNEY, le modèle Kenney (à gauche) puis le ou les modèles Poly Haven, posés comme
## prop() les pose : même boîte demandée (arêtes jaunes), même rotation (0°). Une flèche au sol
## montre l'avant attendu par le jeu (+z), un mètre-étalon rouge et blanc (bandes de 25 cm) donne
## l'échelle. Une image par nom Kenney (vue de trois quarts avant) et une vue de côté.
## Imprime, pour chaque modèle Poly Haven, ses triangles et l'état de ses matières.
##   godot --path godot --rendering-driver vulkan --resolution 960x540 res://tests/galerie_modeles.tscn \
##       -- --autotest --shots=DIR [--only=chair,table] [--extra=id1,id2] [--catalogue] [--cote]
## --extra : modèles Poly Haven à leur taille réelle (5 par image) ; --catalogue : tout le décor
## téléchargé (CATALOGUE) ; --only=aucun : pas de planche Kenney ; --cote : ajoute la vue de côté.

## [nom Kenney, boîte demandée (comme dans les pièces), modèles Poly Haven à comparer]
const ENTRIES := [
	["chair", Vector3(0.42, 0.88, 0.42), ["gallinera_chair"]],
	["chairDesk", Vector3(0.56, 0.95, 0.56), ["gallinera_chair"]],
	["table", Vector3(1.1, 0.74, 0.62), ["small_wooden_table_01", "side_table_01"]],
	["cabinetBedDrawer", Vector3(0.45, 0.0, 0.0), ["ClassicNightstand_01"]],
	["cabinetBedDrawerTable", Vector3(0.48, 0.55, 0.42), ["painted_wooden_nightstand"]],
	["bookcaseClosedDoors", Vector3(1.2, 2.0, 0.58), ["GothicCabinet_01", "painted_wooden_cabinet"]],
	["sideTableDrawers", Vector3(1.1, 0.8, 0.45), ["WoodenTable_03", "painted_wooden_cabinet"]],
	["televisionVintage", Vector3(0.48, 0.0, 0.0), []],
	["lampSquareCeiling", Vector3(0.0, 0.38, 0.0), ["lantern_chandelier_01", "pull_chain_light_socket"]],
	["lampRoundTable", Vector3(0.0, 0.4, 0.0), []],
	["cardboardBoxClosed", Vector3(0.44, 0.42, 0.44), []],
	["plantSmall1", Vector3(0.0, 0.26, 0.0), []],
	["bedDouble", Vector3(1.6, 0.0, 2.05), ["old_bed_frame"]],
	["rugRectangle", Vector3(2.0, 0.01, 1.2), []],
	["toilet", Vector3(0.38, 0.76, 0.64), []],
]

## Modèles Poly Haven téléchargés pour les pièces (décor), montrés à leur taille réelle avec --catalogue.
const CATALOGUE := ["GothicBed_01", "old_bed_frame", "GothicCabinet_01", "painted_wooden_cabinet",
	"painted_wooden_cabinet_02", "WoodenTable_03", "wooden_bookshelf_worn", "wooden_display_shelves_01",
	"painted_wooden_shelves", "side_table_01", "side_table_tall_01", "small_wooden_table_01", "gallinera_chair",
	"Rockingchair_01", "ArmChair_01", "Ottoman_01", "lantern_chandelier_01", "pull_chain_light_socket",
	"industrial_wall_sconce", "vintage_oil_lamp", "vintage_grandfather_clock_01", "wall_clock", "mantel_clock_01",
	"alarm_clock_01", "ornate_mirror_01", "fancy_picture_frame_01", "hanging_picture_frame_01",
	"hanging_picture_frame_02", "standing_picture_frame_01", "vintage_suitcase", "vintage_radio_transceiver",
	"ceramic_vase_01", "jug_01"]

var cam: Camera3D
var shots := ""
var only: PackedStringArray = []
var extra: PackedStringArray = []
var side_views := false
var catalogue := false
var sheet: Node3D
var line_mat: StandardMaterial3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--extra="):
			extra = a.substr(8).split(",")
		elif a == "--cote":
			side_views = true
		elif a == "--catalogue":
			catalogue = true
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(960, 540)
	_make_materials()
	_stage()
	_run.call_deferred()


func _stage() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.35
	add_child(fill)
	var floor_ := _box(Vector3(60, 0.02, 60), Vector3(10, -0.01, 0), _plain(Color(0.42, 0.42, 0.43), 0.9))
	floor_.name = "Sol"
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	line_mat = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1.0, 0.85, 0.1)


func _run() -> void:
	await get_tree().process_frame
	var n := 0
	for e in ENTRIES:
		var kname: String = e[0]
		if not only.is_empty() and not only.has(kname):
			continue
		var ids: Array = []
		var mapped: Dictionary = PH_FOR_KENNEY.get(kname, {})
		if not mapped.is_empty():
			ids.append(mapped.id)
		for i in e[2]:
			if not ids.has(i):
				ids.append(i)
		await _sheet(kname, e[1], ids)
		n += 1
	if catalogue:
		for id in CATALOGUE:      # (seulement les modèles encore dans le projet)
			if ResourceLoader.exists("res://assets/models/polyhaven/%s/%s.gltf" % [id, id]):
				extra.append(id)
	for k in range(0, extra.size(), 5):
		await _sheet("", Vector3.ZERO, Array(extra.slice(k, k + 5)), "extra_%d" % (k / 5 + 1))
	print("GALERIE OK %d planches" % n)
	get_tree().quit()


## Une planche : le Kenney puis chaque modèle Poly Haven, côte à côte le long de x.
func _sheet(kname: String, box: Vector3, ids: Array, sheet_name := "") -> void:
	sheet = Node3D.new()
	sheet.name = "Planche"
	add_child(sheet)
	var x := 0.0
	var hmax := 0.5
	var items: Array = []
	if kname != "":
		items.append(["kenney", kname])
	for i in ids:
		items.append(["ph", i])
	for it in items:
		var node: Node3D
		var title := ""
		if it[0] == "kenney":
			node = prop(kname, Vector3.ZERO, 0.0, box, false, {}, "", "kenney")
			title = "Kenney %s" % kname
		else:
			var id: String = it[1]
			if not ResourceLoader.exists(PH_PATH % [id, id]):
				print("GALERIE %s : %s absent" % [kname, id])
				continue
			var opts: Dictionary = {}
			var mapped: Dictionary = PH_FOR_KENNEY.get(kname, {})
			if mapped.get("id", "") == id:
				opts = mapped.duplicate()
			else:
				opts["close"] = true
			var target := box
			if kname != "" and opts.get("fit", "box") in ["y", "real"]:
				target = _kenney_box(kname, box)
			if kname != "" and box != Vector3.ZERO:
				var prob := _fit_problem(opts.merged({"id": id}), target)
				if prob != "":
					title = "(prop() garde le Kenney : %s)\n" % prob
			node = model(id, Vector3.ZERO, 0.0, target, false, opts)
			var tris := _tris(node)
			title += "ph:%s\n%d tri" % [id, tris]
			_report_materials(id, node, tris)
		remove_child(node)
		sheet.add_child(node)
		var sz: Vector3 = node.get_meta("size")
		var w := maxf(sz.x, box.x)
		x += w / 2.0
		node.position = Vector3(x, 0, 0)
		hmax = maxf(hmax, sz.y)
		title += "\n%.2f x %.2f x %.2f m" % [sz.x, sz.y, sz.z]
		_decorate(Vector3(x, 0, 0), sz, box, title)
		x += w / 2.0 + 0.9
	var span := x - 0.9
	var center := Vector3(span / 2.0, hmax * 0.45, 0.0)
	var label := kname if kname != "" else sheet_name
	await _shoot(center, span, hmax, 28.0, label)
	if side_views:
		await _shoot(center, span, hmax, 70.0, label + "_cote")
	sheet.queue_free()
	await get_tree().process_frame


## Mètre-étalon (bandes de 25 cm), flèche « avant » (+z), boîte demandée en arêtes jaunes, titre.
func _decorate(at: Vector3, sz: Vector3, box: Vector3, title: String) -> void:
	var red := _plain(Color(0.75, 0.08, 0.06), 0.6)
	var white := _plain(Color(0.9, 0.9, 0.88), 0.6)
	var px := at.x - maxf(sz.x, box.x) / 2.0 - 0.18
	for k in 4:
		_box(Vector3(0.03, 0.25, 0.03), Vector3(px, 0.125 + k * 0.25, at.z + sz.z / 2.0), red if k % 2 == 0 else white, false, sheet)
	var arrow := _plain(Color(0.1, 0.6, 0.95), 0.5)
	var z0 := at.z + maxf(sz.z, box.z) / 2.0 + 0.08
	_box(Vector3(0.04, 0.006, 0.3), Vector3(at.x, 0.003, z0 + 0.15), arrow, false, sheet)
	for s in [-1.0, 1.0]:
		var head := _box(Vector3(0.035, 0.006, 0.14), Vector3(at.x + s * 0.042, 0.003, z0 + 0.25), arrow, false, sheet)
		head.rotation.y = -s * 0.7
	if box.x > 0.0 and box.z > 0.0:
		var bh := box.y if box.y > 0.0 else sz.y
		_wire_box(Vector3(at.x, bh / 2.0, at.z), Vector3(box.x, bh, box.z))
	var lb := Label3D.new()
	lb.text = title
	lb.font_size = 28
	lb.pixel_size = 0.0035
	lb.outline_size = 8
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = Vector3(at.x, maxf(sz.y, 0.3) + 0.3, at.z)
	sheet.add_child(lb)


func _wire_box(c: Vector3, s: Vector3) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, line_mat)
	var h := s / 2.0
	var p := []
	for i in 8:
		p.append(c + Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		im.surface_add_vertex(p[e[0]])
		im.surface_add_vertex(p[e[1]])
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.add_child(mi)


func _shoot(center: Vector3, span: float, hmax: float, az_deg: float, n: String) -> void:
	var vhalf := deg_to_rad(cam.fov / 2.0)
	var hhalf := atan(tan(vhalf) * 16.0 / 9.0)
	var d := maxf((span / 2.0 + 0.35) / tan(hhalf), (hmax / 2.0 + 0.45) / tan(vhalf)) + 0.6
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(18.0)
	cam.position = center + Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) * d
	cam.look_at(center, Vector3.UP)
	for k in 6:
		await RenderingServer.frame_post_draw
	if shots != "":
		var img := get_viewport().get_texture().get_image()
		img.save_png(shots.path_join("galerie_%s.png" % n))
		print("capture galerie_%s %s" % [n, img.get_size()])


func _tris(node: Node) -> int:
	var t := 0
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		for i in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(i)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			t += idx.size() / 3 if idx.size() > 0 else verts.size() / 3
	return t


func _report_materials(id: String, node: Node, tris: int) -> void:
	var out := []
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			out.append("%s[cull=%d transp=%d detail=%s lods=%d]" % [m.resource_name, m.cull_mode, m.transparency,
				m.detail_enabled, (mi.mesh as ArrayMesh).get_surface_count() if mi.mesh is ArrayMesh else 0])
	print("MODELE %-26s %6d tri  %s" % [id, tris, ", ".join(out)])
