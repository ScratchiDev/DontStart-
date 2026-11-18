extends Node3D
## Banc de la bibliothèque d'usure (lot V1-USURE), sans rendu (exclu de l'export) :
##   godot --headless --path godot res://tests/wear_banc.tscn
##   … -- --maison : construit aussi la maison (main.tscn) avec le profil des vraies cartes et mesure le
##   remplacement de la crasse HD (matières changées, millisecondes, aucune matière oubliée)
## Vérifie : chaque genre trouve au moins un fichier (et compte ses variantes) ; les réglages de chaque
## décalque (textures, normal_fade, fondus, distance, cull_mask, repère, groupe) ; variante choisie par
## hachage, stable, ou imposée ; repli sur la variante suivante si un fichier manque ; decal() rend null
## en rendu logiciel forcé et en Basse, sauf avec story ; wall_base (aucune bande devant une porte,
## tronçons raccordés), ceiling_corners, path, footprints (positions exactes, pieds alternés, ±8°,
## fondu) ; Surfaces : rien de programmé en rendu logiciel, masques HD posés sur les matières de
## Surfaces.grime et de Builder._grimy, même moyenne que grime.png ; aucun tirage aléatoire consommé.
## Dernière ligne : « USURE OK » ou « USURE ÉCHEC <n> ».

var fails := 0
var checks := 0
var rooms := {}


func check(what: String, ok: bool, info := "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("USURE %s : %s%s" % [what, "OK" if ok else "ÉCHEC", ("  (" + info + ")") if info != "" else ""])


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--maison"):
		await _house()
		return
	var was_soft: int = Main._soft
	var was_q: int = Game.quality
	seed(4242)
	var witness := randf()
	seed(4242)
	Main._soft = 0
	Game.quality = Qualite.ELEVEE
	_kinds()
	_decal_rules()
	_fallback()
	_soft_rules()
	_make_rooms()
	_wall_base()
	_corners_and_paths()
	_footprints()
	_surfaces()
	check("aucun tirage aléatoire consommé", is_equal_approx(randf(), witness))
	Main._soft = was_soft
	Game.quality = was_q
	print("%d vérifications, %d échec(s)" % [checks, fails])
	print("USURE %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit()


# ------------------------------------------------------------------ genres et fichiers

func _kinds() -> void:
	var all_ok := true
	var lines := []
	for kind in Wear.KINDS:
		var list: Array = Wear.KINDS[kind]
		var found := 0
		var with_normal := 0
		for i in list.size():
			var f := Wear.files(kind, i)
			if not f.is_empty() and int(f.index) == i:
				found += 1
				if f.normal != "":
					with_normal += 1
				if f.orm == "":
					all_ok = false
					lines.append("%s/%d sans ORM" % [kind, i])
		lines.append("%s %d/%d%s" % [kind, found, list.size(), (" (relief %d)" % with_normal) if with_normal > 0 else ""])
		check("genre « %s » : au moins un fichier" % kind, found > 0, "%d/%d variantes" % [found, list.size()])
		if found < list.size():
			print("USURE   (variantes absentes de %s : repli sur la suivante)" % kind)
	check("chaque variante présente a son ORM", all_ok)
	print("USURE inventaire : " + ", ".join(lines))


# ------------------------------------------------------------------ règles d'un décalque

func _decal_rules() -> void:
	var d := Wear.decal(self, "tache_plafond", Vector3(1, 2.6, 1), Vector3.DOWN, Vector3.BACK, 1.2, 1.0)
	check("decal() sur vraie carte : un Decal", d != null)
	if d == null:
		return
	check("textures albédo, normale et ORM", d.texture_albedo != null and d.texture_normal != null and d.texture_orm != null)
	check("normal_fade 0,35, fondus haut et bas", is_equal_approx(d.normal_fade, 0.35) and d.upper_fade > 0.0 and d.lower_fade > 0.0)
	check("distance_fade : début 9 m, longueur 2 m", d.distance_fade_enabled and is_equal_approx(d.distance_fade_begin, 9.0)
		and is_equal_approx(d.distance_fade_length, 2.0))
	check("cull_mask : couche 1 seulement", d.cull_mask == 1)
	check("taille (u, profondeur, v)", d.size.is_equal_approx(Vector3(1.2, 0.3, 1.0)), str(d.size))
	check("repère : Y = normale, -Z = haut de l'image", d.transform.basis.y.is_equal_approx(Vector3.DOWN)
		and (-d.transform.basis.z).is_equal_approx(Vector3.BACK) and d.position.is_equal_approx(Vector3(1, 2.6, 1)))
	check("groupe « usure » et métas", d.is_in_group("usure") and d.get_meta("usure", "") == "tache_plafond" and d.has_meta("variante"))
	var d2 := Wear.decal(self, "tache_plafond", Vector3(1, 2.6, 1), Vector3.DOWN, Vector3.BACK, 1.2, 1.0)
	check("même position, même variante", d2 != null and d2.get_meta("variante") == d.get_meta("variante"))
	var seen := {}
	for i in 12:
		var di := Wear.decal(self, "tache_plafond", Vector3(i * 0.7 - 3.0, 2.6, i * 0.31), Vector3.DOWN, Vector3.BACK, 1.0, 1.0)
		if di:
			seen[di.get_meta("variante")] = true
	check("variantes tirées du hachage de la position (12 positions)", seen.size() >= 3, "%d variantes" % seen.size())
	var d3 := Wear.decal(self, "tache_plafond", Vector3(0, 2.6, 0), Vector3.DOWN, Vector3.BACK, 1.0, 1.0, {"variant": 2})
	check("variante imposée", d3 != null and int(d3.get_meta("variante")) == 2)
	var d4 := Wear.decal(self, "crasse_pied_mur", Vector3(0, 0.11, 0), Vector3.RIGHT, Vector3.UP, 2.0, 0.22, {"rot": 90.0})
	check("rotation autour de la normale (90°)", d4 != null and d4.transform.basis.y.is_equal_approx(Vector3.RIGHT)
		and absf((-d4.transform.basis.z).dot(Vector3.UP)) < 1e-4)
	check("décalque sans relief : pas de normale", d4 != null and d4.texture_normal == null and d4.texture_orm != null)
	var holder := Node3D.new()
	holder.position = Vector3(10, 0, 0)
	add_child(holder)
	var d5 := Wear.decal(holder, "suie", Vector3(11, 2.6, 0), Vector3.DOWN, Vector3.FORWARD, 0.6, 0.6, {"world": true})
	check("opts.world : position du monde", d5 != null and d5.global_position.is_equal_approx(Vector3(11, 2.6, 0))
		and d5.position.is_equal_approx(Vector3(1, 2.6, 0)))
	var all_kinds := true
	var bad := []
	for kind in Wear.KINDS:
		var dk := Wear.decal(self, kind, Vector3(0, 1, 0), Vector3.BACK, Vector3.UP, 0.5, 0.5)
		if dk == null or dk.texture_albedo == null or dk.texture_orm == null:
			all_kinds = false
			bad.append(kind)
	check("un décalque pour chaque genre", all_kinds, ", ".join(bad))
	var d6 := Wear.decal(self, "trainee", Vector3.ZERO, Vector3.BACK, Vector3.UP, 0.3, 0.3, {"color": Color(1, 0.9, 0.8, 0.5), "alpha": 0.5, "mix": 0.2})
	check("teinte, alpha et albedo_mix", d6 != null and is_equal_approx(d6.modulate.a, 0.25) and is_equal_approx(d6.albedo_mix, 0.2))
	var d7 := Wear.decal(self, "traces_doigts", Vector3.ZERO, Vector3.BACK, Vector3.UP, 0.3, 0.3, {"vitre": true})
	check("vitre : albedo_mix × VITRE_MIX (la trace se voit dans le reflet)", d7 != null
		and is_equal_approx(d7.albedo_mix, float(Wear.STYLE.traces_doigts.mix) * Wear.VITRE_MIX) and d7.texture_orm != null)


func _fallback() -> void:
	var f := Wear.first_existing(["inexistant_1", "tache_plafond_2"], 0)
	check("fichier absent : variante suivante", not f.is_empty() and f.name == "tache_plafond_2" and int(f.index) == 1, str(f.get("name", "")))
	check("aucune variante : vide, sans erreur", Wear.first_existing(["inexistant_1", "inexistant_2"], 1).is_empty())
	check("genre inconnu : null", Wear.decal(self, "inconnu", Vector3.ZERO, Vector3.UP, Vector3.FORWARD, 1, 1) == null)


func _soft_rules() -> void:
	Main._soft = 1
	check("rendu logiciel forcé : decal() → null", Wear.decal(self, "coulure", Vector3.ZERO, Vector3.BACK, Vector3.UP, 1, 1) == null)
	var s := Wear.decal(self, "empreinte", Vector3.ZERO, Vector3.UP, Vector3.FORWARD, 0.17, 0.29, {"story": true})
	check("rendu logiciel forcé : story = true → un Decal", s != null)
	check("rendu logiciel forcé : footprints (récit) posées", Wear.footprints(self, [Vector3(0, 0, 0), Vector3(1, 0, 0)]).size() > 0)
	var r := HouseRoom.new()
	r.setup("essai", Rect2(-1, -1, 2, 2))
	add_child(r)
	check("rendu logiciel forcé : aides décoratives vides", Wear.wall_base(r).is_empty() and Wear.ceiling_corners(r).is_empty()
		and Wear.path(r, [Vector2(0, 0), Vector2(1, 0)]).is_empty())
	Main._soft = 0
	Game.quality = Qualite.BASSE
	check("Basse : decal() → null, sauf story", Wear.decal(self, "coulure", Vector3.ZERO, Vector3.BACK, Vector3.UP, 1, 1) == null
		and Wear.decal(self, "empreinte", Vector3.ZERO, Vector3.UP, Vector3.FORWARD, 0.17, 0.29, {"story": true}) != null)
	Game.quality = Qualite.ELEVEE
	r.queue_free()


# ------------------------------------------------------------------ aides

func _make_rooms() -> void:
	for id in HouseData.F1_ROOMS:
		var d: Dictionary = HouseData.F1_ROOMS[id]
		var rc: Array = d.rect
		var r := HouseRoom.new()
		r.name = "Essai_" + id
		r.setup(id, Rect2(rc[0], rc[2], rc[1] - rc[0], rc[3] - rc[2]), HouseData.F1_Y, HouseData.F1_H, d.title)
		r.floor_kind = d.get("floor", "parquet")
		add_child(r)
		rooms[id] = r


func _wall_base() -> void:
	var total := 0
	var bad := []
	var per := []
	var seam_ok := true
	for id in rooms:
		var r: HouseRoom = rooms[id]
		var ds := Wear.wall_base(r)
		total += ds.size()
		per.append("%s %d" % [id, ds.size()])
		var by_side := {}
		for d in ds:
			var dd := d as Decal
			var n := dd.global_transform.basis.y.normalized()
			var p := dd.global_position
			# le long du mur : z pour un mur d'axe x (normale ±x), x sinon
			var along_x: bool = absf(n.z) > 0.5
			var u0 := (p.x if along_x else p.z) - dd.size.x / 2.0
			var u1 := (p.x if along_x else p.z) + dd.size.x / 2.0
			var face := (p.z if along_x else p.x) - n.dot(Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)) * 0.04
			for door in HouseData.F1_DOORS:
				if not along_x and absf(float(door.at) - face) < 0.1:
					var a := float(door.c) - float(door.w) / 2.0
					var b := float(door.c) + float(door.w) / 2.0
					if u1 > a + 0.001 and u0 < b - 0.001:
						bad.append("%s devant %s" % [id, door.id])
			if not (absf(p.y - 0.11) < 1e-4 and is_equal_approx(dd.size.z, 0.22) and dd.size.x <= Wear.BAND_MAX + 1e-4):
				bad.append("%s : hauteur ou taille" % id)
			var to_c := r.center() - p
			to_c.y = 0.0
			if n.dot(to_c) <= 0.0:
				bad.append("%s : normale vers l'extérieur" % id)
			var key := "%.2f %.2f" % [n.x, n.z]
			if by_side.has(key) and by_side[key] != dd.get_meta("variante"):
				seam_ok = false
			by_side[key] = dd.get_meta("variante")
	check("wall_base : aucune bande devant une porte, hauteur 0,22 m, tournée vers la pièce", bad.is_empty(), ", ".join(bad))
	check("wall_base : une même variante par mur (raccords sans couture)", seam_ok)
	check("wall_base : bandes posées", total > 20, "%d bandes : %s" % [total, ", ".join(per)])
	# P1 (chambre de la mère, x = 3,2) : la bande du mur est coupée en deux
	var mere := Wear.wall_base(rooms["mere"], 0.22, {"sides": ["x1"]})
	check("wall_base : mur de la porte P1 coupé en deux tronçons", mere.size() == 3, "%d décalques" % mere.size())
	var gap := Wear.wall_base(rooms["mere"], 0.22, {"sides": ["z0"], "gaps": [Rect2(-1.0, -2.6, 1.0, 0.6)]})
	var gap_ok := true
	for d in gap:
		var dd := d as Decal
		if dd.global_position.x + dd.size.x / 2.0 > -1.0 + 0.001 and dd.global_position.x - dd.size.x / 2.0 < 0.0 - 0.001:
			gap_ok = false
	check("wall_base : zones libres (opts.gaps)", gap_ok and gap.size() >= 2, "%d décalques" % gap.size())


func _corners_and_paths() -> void:
	var r: HouseRoom = rooms["gp"]
	var cs := Wear.ceiling_corners(r)
	var ok := cs.size() == 4
	for d in cs:
		var dd := d as Decal
		var n := dd.global_transform.basis.y
		var to_c := r.center() - dd.global_position
		if not (n.y < -0.5 and Vector2(n.x, n.z).dot(Vector2(to_c.x, to_c.z)) > 0.0 and is_equal_approx(dd.global_position.y, 2.6)):
			ok = false
	check("ceiling_corners : 4 coins, tournés vers la pièce et vers le bas", ok, "%d" % cs.size())
	var pts := [Vector2(3.0, -3.6), Vector2(1.0, -3.9), Vector2(-1.0, -5.0)]
	var ps := Wear.path(r, pts, 0.5)
	check("path : un décalque par segment, teinte et mélange du parquet", ps.size() == 2
		and (ps[0] as Decal).modulate.is_equal_approx(Wear.PATH_TINT.parquet)
		and is_equal_approx((ps[0] as Decal).albedo_mix, Wear.PATH_MIX.parquet) and is_equal_approx((ps[0] as Decal).global_position.y, 0.0))
	var pm := Wear.path(rooms["amis"], [Vector3(2.5, 0, 3.4), Vector3(0, 0, 4.5)], 0.6)
	check("path : teinte et mélange de la moquette", pm.size() == 1 and (pm[0] as Decal).modulate.is_equal_approx(Wear.PATH_TINT.moquette)
		and is_equal_approx((pm[0] as Decal).albedo_mix, Wear.PATH_MIX.moquette))


func _footprints() -> void:
	# les positions de decor._traces (0.3.3) : de la porte de la chambre jusque sous le lit
	var start := Vector3(2.7, 0.0, 1.45)
	var step := 0.34
	var n := int((start.x - -2.0) / step)
	var pts := []
	for i in n:
		var left := i % 2 == 0
		var p := start + Vector3(-i * step, 0, 0.09 if left else -0.09)
		p.z += sin(i * 0.7) * 0.05
		pts.append(p)
	var holder := Node3D.new()
	add_child(holder)
	var fs := Wear.footprints(holder, pts, {"each": true})
	var pos_ok := fs.size() == n
	var side_ok := true
	var rot_ok := true
	var fade_ok := true
	var max_ang := 0.0
	var last_a := 2.0
	for i in fs.size():
		var d := fs[i] as Decal
		if not d.position.is_equal_approx(pts[i]):
			pos_ok = false
		var left := i % 2 == 0
		if (int(d.get_meta("variante")) % 2 == 0) != left or String(d.get_meta("pied")) != ("gauche" if left else "droit"):
			side_ok = false
		var toe := -d.transform.basis.z
		var ang := rad_to_deg(Vector2(-1, 0).angle_to(Vector2(toe.x, toe.z)))
		max_ang = maxf(max_ang, absf(ang))
		if absf(ang) > 5.0 + 8.0 + 3.0:
			rot_ok = false
		if d.modulate.a > last_a + 1e-6:
			fade_ok = false
		last_a = d.modulate.a
		if not d.is_in_group("usure"):
			side_ok = false
	check("footprints (positions exactes) : même nombre de pas, mêmes positions", pos_ok, "%d/%d" % [fs.size(), n])
	check("footprints : pieds gauche et droit alternés (variantes paires et impaires)", side_ok)
	check("footprints : pointe tournée de 5° ± 8° au plus", rot_ok, "écart max %.1f°" % max_ang)
	check("footprints : fondu le long du chemin", fade_ok and fs.size() > 1 and is_equal_approx((fs[0] as Decal).modulate.a, 1.0)
		and is_equal_approx((fs[-1] as Decal).modulate.a, 0.45))
	var line := Wear.footprints(holder, [Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(2, 0, 2)], {"each": false})
	var stride_ok := line.size() >= 10 and line.size() <= 14
	for i in range(1, line.size()):
		var a := (line[i - 1] as Decal).position
		var b := (line[i] as Decal).position
		var dd := Vector2(b.x - a.x, b.z - a.z).length()
		if dd < 0.2 or dd > 0.5:
			stride_ok = false
	check("footprints (ligne brisée) : pas irréguliers de 0,31 à 0,37 m", stride_ok, "%d pas" % line.size())


# ------------------------------------------------------------------ crasse HD (Surfaces)

func _lin_mean(t: Texture2D) -> float:
	var img := t.get_image()
	if img == null:
		return -1.0
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var s := 0.0
	var k := 0
	for y in range(0, img.get_height(), maxi(1, img.get_height() / 64)):
		for x in range(0, img.get_width(), maxi(1, img.get_width() / 64)):
			s += img.get_pixel(x, y).srgb_to_linear().r
			k += 1
	return s / k


func _surfaces() -> void:
	var tree := get_tree()
	Main._soft = 1
	var soft_mats := {}
	Surfaces.build(soft_mats)
	check("Surfaces en rendu logiciel : aucun remplacement programmé", not tree.process_frame.is_connected(Surfaces._swap_hd)
		and (soft_mats.plaster as StandardMaterial3D).detail_albedo == Surfaces.grime_texture_old())
	Main._soft = 0
	var mats := {}
	Surfaces.build(mats)
	check("Surfaces sur vraie carte : remplacement programmé à l'image suivante", tree.process_frame.is_connected(Surfaces._swap_hd))
	# une matière de Builder._grimy (détail grime.png), portée par un maillage de la scène
	var furn := StandardMaterial3D.new()
	furn.albedo_color = Color(0.5, 0.4, 0.3)
	furn.detail_enabled = true
	furn.detail_albedo = Surfaces.grime_texture_old()
	furn.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.set_surface_override_material(0, furn)
	add_child(mi)
	tree.process_frame.disconnect(Surfaces._swap_hd)
	Surfaces._swap_hd()
	var hd := []
	for p in Surfaces.GRIME_HD:
		hd.append(load(p))
	check("crasse HD : plâtre → masque 1, bois → 2, boiseries peintes → 3",
		(mats.plaster as StandardMaterial3D).detail_albedo == hd[0] and (mats.wall_olive as StandardMaterial3D).detail_albedo == hd[0]
		and (mats.wood as StandardMaterial3D).detail_albedo == hd[1] and (mats.door as StandardMaterial3D).detail_albedo == hd[2]
		and (mats.paint as StandardMaterial3D).detail_albedo == hd[2])
	check("crasse HD : matière de Builder._grimy dans la scène → patine", furn.detail_albedo == hd[1])
	check("crasse HD : les matières restent des StandardMaterial3D", mats.plaster is StandardMaterial3D and mats.door is StandardMaterial3D)
	check("crasse HD : matières sans crasse inchangées", (mats.ceil as StandardMaterial3D).detail_albedo == null)
	check("crasse HD : soft_mats (autre construction) non touchées", (soft_mats.plaster as StandardMaterial3D).detail_albedo == Surfaces.grime_texture_old())
	var late := Surfaces.grime(Surfaces.pbr("PaintedWood009C/PaintedWood009C", 1.0), 1.0)
	check("crasse HD : matière créée après le remplacement → masque HD (d'après son nom)", late.detail_albedo == hd[2])
	print("USURE   remplacement : %d matières en %d ms" % [Surfaces.hd_stats.x, Surfaces.hd_stats.y])
	var m0 := _lin_mean(Surfaces.grime_texture_old())
	var ok := true
	var info := []
	for t in hd:
		var m := _lin_mean(t)
		info.append("%.3f" % m)
		if absf(m - m0) > 0.012:
			ok = false
	check("crasse HD : même moyenne (lumière linéaire) que grime.png", ok, "%.3f → %s" % [m0, ", ".join(info)])
	var sz_ok := true
	for t in hd:
		if (t as Texture2D).get_width() != 1024:
			sz_ok = false
	check("crasse HD : masques de 1024 px", sz_ok)
	# remise à zéro (les autres bancs voient grime.png)
	Surfaces._hd.clear()
	mi.queue_free()


# ------------------------------------------------------------------ maison complète

func _house() -> void:
	Main._soft = 0
	var t0 := Time.get_ticks_msec()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var old := Surfaces.grime_texture_old()
	var left := 0
	var seen := {}
	for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var mats := []
		var g := node as GeometryInstance3D
		mats.append(g.material_override)
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var mi := g as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				mats.append(mi.get_surface_override_material(i))
				mats.append(mi.mesh.surface_get_material(i))
		for m in mats:
			var bm := m as BaseMaterial3D
			if bm and not seen.has(bm) and bm.detail_enabled and bm.detail_albedo == old:
				left += 1
			if bm:
				seen[bm] = true
	var ng := get_tree().root.find_children("*", "GeometryInstance3D", true, false).size()
	print("MAISON (profil complet) : %d ms ; %d objets visuels ; crasse HD : %d matières en %d ms ; oubliées : %d" % [
		Time.get_ticks_msec() - t0, ng, Surfaces.hd_stats.x, Surfaces.hd_stats.y, left])
	print("USURE MAISON %s" % ("OK" if left == 0 and Surfaces.hd_stats.x > 0 else "ÉCHEC"))
	get_tree().quit()
