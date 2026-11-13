extends House
## Banc d'essai (exclu de l'export) : la maison de house.gd, mais seules la salle de bain et la chambre
## d'amis reçoivent leur script de pièce (les autres pièces restent nues). Sert à tester sdb.gd et
## amis.gd sans dépendre de l'état des autres pièces. Voir tests/sa_test.gd.

const MINE := {"sdb": "res://scripts/house/rooms/sdb.gd", "amis": "res://scripts/house/rooms/amis.gd"}


func _make_room(id: String, d: Dictionary, y0_: float, h_: float) -> HouseRoom:
	var script_path: String = MINE.get(id, "")
	var r: HouseRoom
	if script_path != "":
		r = (load(script_path) as GDScript).new()
	else:
		r = HouseRoom.new()
	var rc: Array = d.rect
	r.setup(id, Rect2(rc[0], rc[2], rc[1] - rc[0], rc[3] - rc[2]), y0_, h_, d.get("title", id))
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
	r._box(Vector3(x1 - x0 + D.WALL, 0.1, z1 - z0 + D.WALL), Vector3(cx, y0_ - 0.05, cz), floor_mat, true)
	r._box(Vector3(x1 - x0 + D.WALL, 0.1, z1 - z0 + D.WALL), Vector3(cx, y0_ + h_ + 0.05, cz), mats.ceil, true)
	var sides := [
		["x", x0, x1, z0, 1.0, "z", z0 - D.WALL / 2.0],
		["x", x0, x1, z1, -1.0, "z", z1 + D.WALL / 2.0],
		["z", z0, z1, x0, 1.0, "x", x0 - D.WALL / 2.0],
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
		r.wall(axis, sd[1], sd[2], face + dir * 0.006, h_, holes, wall_mat, 0.012, y0_)
		var gaps := []
		for hl in holes:
			if hl[2] < 0.3:
				gaps.append([hl[0], hl[1]])
		r.trim(axis, sd[1], sd[2], face + dir * 0.012, dir, h_, gaps, style, y0_)
	return r
