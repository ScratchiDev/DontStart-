extends Builder
## Banc des outils de géométrie de Builder (lot V1-GEOMETRIE), sans rendu (exclu de l'export) :
##   godot --headless --path godot res://tests/geometrie_banc.tscn
##   … -- --maison : construit aussi la maison (main.tscn) et compte les boîtes chanfreinées (cache)
##   … -- --maison --logiciel : la même chose, rendu logiciel forcé (biseaux coupés), pour comparer
## Vérifie : boîte chanfreinée (boîte englobante = taille demandée à 0,5 mm près, normales unitaires,
## triangles tournés vers leurs normales, tangentes comme SurfaceTool.generate_tangents, 500 boîtes en
## moins de 45 ms), boîte arrondie, superellipse, loft (moins de 4 ms), tour chanfreiné, choix de
## box_mesh (rendu logiciel, verres, dalles, UV), échelle par axe (« stretch »), tapis (hauteurs, coin
## relevé hors des battants), detail() (null en rendu logiciel forcé ; sinon posé en différé, hors de
## props), et qu'aucun tirage aléatoire du jeu n'est consommé. Dernière ligne : « GEOMETRIE OK » ou
## « GEOMETRIE ÉCHEC <n> ».

var fails := 0
var checks := 0


func check(what: String, ok: bool, info := "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("GEO %s : %s%s" % [what, "OK" if ok else "ÉCHEC", ("  (" + info + ")") if info != "" else ""])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--maison"):
		await _house(args.has("--logiciel"))
		return
	# profil des vraies cartes (biseaux), même sans rendu : depuis la passe, main.gd range le mode sans
	# affichage (--headless) dans le rendu logiciel ; les cas « logiciel » le forcent ensuite eux-mêmes
	Main._soft = 0
	_make_materials()
	seed(4242)
	var witness := randf()
	seed(4242)
	_bevel_tests()
	_rounded_tests()
	_profile_tests()
	_box_rules()
	_stretch_tests()
	_rug_tests()
	check("aucun tirage aléatoire consommé", is_equal_approx(randf(), witness))
	check("couche acoustique", Builder.LAYER_ACOUSTIC == 20)
	await _detail_tests()
	print("%d vérifications, %d échec(s)" % [checks, fails])
	print("GEOMETRIE %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit()


# ------------------------------------------------------------------ maillages : contrôles communs

## [normales unitaires, triangles tournés vers leurs normales (sens horaire vu de devant), tangentes
## unitaires et perpendiculaires aux normales] pour la surface s.
func _mesh_sane(m: Mesh, s := 0) -> Array:
	var arr := m.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var unit := true
	for x in n:
		if absf(x.length() - 1.0) > 0.001:
			unit = false
	var facing := true
	var bad := 0
	for k in range(0, idx.size(), 3):
		var a := v[idx[k]]
		var b := v[idx[k + 1]]
		var c := v[idx[k + 2]]
		var cr := (b - a).cross(c - a)
		if cr.length() < 1e-10:
			continue
		var avg := n[idx[k]] + n[idx[k + 1]] + n[idx[k + 2]]
		if cr.dot(avg) >= 0.0:
			bad += 1
	facing = bad == 0
	var tan_ok := true
	if arr[Mesh.ARRAY_TANGENT] != null:
		var t: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		for i in v.size():
			var tv := Vector3(t[i * 4], t[i * 4 + 1], t[i * 4 + 2])
			if absf(tv.length() - 1.0) > 0.01 or absf(tv.dot(n[i])) > 0.02 or absf(absf(t[i * 4 + 3]) - 1.0) > 0.001:
				tan_ok = false
	return [unit, facing, tan_ok, bad]


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		t += idx.size() / 3
	return t


# ------------------------------------------------------------------ boîte chanfreinée

func _bevel_tests() -> void:
	var sizes := [Vector3(0.3, 0.4, 0.2), Vector3(0.86, 2.02, 0.045), Vector3(5.0, 0.11, 0.035),
		Vector3(0.0125, 0.3, 0.2), Vector3(0.006, 0.006, 0.006), Vector3(1.234567, 0.0234, 0.78901)]
	var aabb_ok := true
	var worst := 0.0
	var sane := true
	for sz in sizes:
		var m := Builder.bevel_box_mesh(sz, 0.005)
		var bb := m.get_aabb()
		for a in 3:
			worst = maxf(worst, absf(bb.size[a] - sz[a]))
			worst = maxf(worst, absf(bb.get_center()[a]))
		var st := _mesh_sane(m)
		if not (st[0] and st[1] and st[2]):
			sane = false
			print("  boîte %s : %s" % [sz, st])
	aabb_ok = worst <= 0.0005
	check("boîte chanfreinée : boîte englobante = taille demandée", aabb_ok, "écart max %.4f mm" % (worst * 1000.0))
	check("boîte chanfreinée : normales unitaires, faces vers l'extérieur, tangentes", sane)
	var m0 := Builder.bevel_box_mesh(Vector3(0.5, 0.3, 0.2), 0.006)
	check("boîte chanfreinée : 24 sommets, 44 triangles", (m0.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 24 and _tris(m0) == 44)
	check("boîte chanfreinée : même maillage pour la même taille (cache)", Builder.bevel_box_mesh(Vector3(0.5, 0.3, 0.2), 0.006) == m0)
	# tangentes : mêmes directions et même signe que SurfaceTool.generate_tangents (MikkTSpace) sur les six
	# faces (boîte sans chanfrein : les sommets des chanfreins, partagés, mêleraient deux faces)
	var arr := Builder.bevel_box_mesh(Vector3(0.5, 0.3, 0.2), 0.0).surface_get_arrays(0)
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_tangents()
	var ra := st.commit_to_arrays()
	var ref: PackedFloat32Array = ra[Mesh.ARRAY_TANGENT]
	var rv: PackedVector3Array = ra[Mesh.ARRAY_VERTEX]
	var rn: PackedVector3Array = ra[Mesh.ARRAY_NORMAL]
	var mine: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
	var mv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var mn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var same := true
	var info := ""
	for i in mv.size():
		for k in rv.size():
			if rv[k].is_equal_approx(mv[i]) and rn[k].is_equal_approx(mn[i]):
				var a := Vector3(mine[i * 4], mine[i * 4 + 1], mine[i * 4 + 2])
				var b := Vector3(ref[k * 4], ref[k * 4 + 1], ref[k * 4 + 2])
				if a.dot(b) < 0.9 or signf(mine[i * 4 + 3]) != signf(ref[k * 4 + 3]):
					same = false
					if info == "":
						info = "n %s : %s / %s w %.0f / %.0f" % [mn[i], a, b, mine[i * 4 + 3], ref[k * 4 + 3]]
	check("boîte chanfreinée : tangentes comme generate_tangents", same, info)
	# UV en mètres, u le long du plus grand côté (le fil du bois) : planche de 1,2 × 0,02 × 0,3
	var plank := Builder.bevel_box_mesh(Vector3(1.2, 0.02, 0.3), 0.004)
	var pa := plank.surface_get_arrays(0)
	var pv: PackedVector3Array = pa[Mesh.ARRAY_VERTEX]
	var pu: PackedVector2Array = pa[Mesh.ARRAY_TEX_UV]
	var grain := true
	for f in 6:
		var u_span := 0.0
		var x_span := 0.0
		for k in 4:
			for k2 in 4:
				u_span = maxf(u_span, absf(pu[f * 4 + k].x - pu[f * 4 + k2].x))
				x_span = maxf(x_span, absf(pv[f * 4 + k].x - pv[f * 4 + k2].x))
		if f >= 2 and absf(u_span - x_span) > 0.001:     # faces ±y et ±z : u suit x (1,2 m)
			grain = false
	check("boîte chanfreinée : u le long du grand côté, en mètres", grain)
	# 500 boîtes de tailles toutes différentes (cache vidé), puis 500 de nouveau (cache)
	var dt := INF
	var t0 := 0
	for k in 3:
		Builder._bevel_cache = {}
		t0 = Time.get_ticks_usec()
		for i in 500:
			Builder.bevel_box_mesh(Vector3(0.3 + i * 0.001, 0.4 + (i % 7) * 0.01, 0.2), 0.005)
		dt = minf(dt, (Time.get_ticks_usec() - t0) / 1000.0)
	t0 = Time.get_ticks_usec()
	for i in 500:
		Builder.bevel_box_mesh(Vector3(0.3 + i * 0.001, 0.4 + (i % 7) * 0.01, 0.2), 0.005)
	var dt2 := (Time.get_ticks_usec() - t0) / 1000.0
	check("500 boîtes chanfreinées en moins de 45 ms (meilleur de 3)", dt < 45.0, "%.1f ms, %.3f ms par boîte ; en cache : %.1f ms" % [dt, dt / 500.0, dt2])


# ------------------------------------------------------------------ boîte arrondie

func _rounded_tests() -> void:
	var sz := Vector3(0.38, 0.36, 0.17)
	var m := Builder.rounded_box_mesh(sz, 0.02, 4)
	var bb := m.get_aabb()
	var err := 0.0
	for a in 3:
		err = maxf(err, absf(bb.size[a] - sz[a]))
	var st := _mesh_sane(m)
	check("boîte arrondie : taille, normales, faces, tangentes", err < 0.0005 and st[0] and st[1] and st[2], "écart %.4f mm, %s, %d triangles" % [err * 1000.0, st, _tris(m)])
	# les normales des coins sont radiales : (p - centre intérieur) / r
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ih := sz / 2.0 - Vector3.ONE * 0.02
	var radial := true
	for i in v.size():
		var inner := v[i].clamp(-ih, ih)
		if absf(v[i].distance_to(inner) - 0.02) > 0.0002 or n[i].dot((v[i] - inner).normalized()) < 0.999:
			radial = false
	check("boîte arrondie : surface à r du noyau, normales exactes", radial)


# ------------------------------------------------------------------ superellipse, loft, tour

func _profile_tests() -> void:
	var se := Builder.superellipse(0.18, 0.235, 2.6, 48)
	var ok := se.size() == 48 and se[0].distance_to(Vector2(0.18, 0.0)) < 0.0005 \
		and se[12].distance_to(Vector2(0.0, 0.235)) < 0.002 and se[24].distance_to(Vector2(-0.18, 0.0)) < 0.002
	var dmin := INF
	var dmax := 0.0
	for i in se.size():
		var dd := se[i].distance_to(se[(i + 1) % se.size()])
		dmin = minf(dmin, dd)
		dmax = maxf(dmax, dd)
	check("superellipse : 48 points, axes aux quarts, pas régulier", ok and dmax / dmin < 1.05, "pas %.4f à %.4f m" % [dmin, dmax])
	# loft de 14 sections de 48 points (pied de WC : du sol à la cuvette)
	var secs: Array = []
	var ys := PackedFloat32Array()
	var t0 := Time.get_ticks_usec()
	for i in 14:
		var t := i / 13.0
		secs.append(Builder.superellipse(lerpf(0.1, 0.18, t * t), lerpf(0.14, 0.235, t * t), lerpf(2.6, 2.2, t), 48))
		ys.append(0.4 * t)
	var dts := (Time.get_ticks_usec() - t0) / 1000.0
	# (le meilleur de trois : la machine est partagée, une mesure isolée peut tomber sur un pic de charge)
	var dt := INF
	var m: ArrayMesh
	for k in 3:
		t0 = Time.get_ticks_usec()
		m = Builder.loft_mesh(secs, ys, true)
		dt = minf(dt, (Time.get_ticks_usec() - t0) / 1000.0)
	var st := _mesh_sane(m)
	var bb := m.get_aabb()
	check("loft 14 × 48 en moins de 4 ms", dt < 4.0, "%.2f ms (sections : %.2f ms), %d triangles" % [dt, dts, _tris(m)])
	check("loft : normales, faces vers l'extérieur, tangentes, hauteur", st[0] and st[1] and st[2] and absf(bb.size.y - 0.4) < 0.0001, str(st))
	var arr := m.surface_get_arrays(0)
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	check("loft : u = abscisse curviligne (m), v = hauteur", absf(uv[48].x - _perimeter(secs[0])) < 0.001 and is_equal_approx(uv[49].y, ys[1]))
	var inner := Builder.loft_mesh(secs, ys, false, true)
	var sti := _mesh_sane(inner)
	var an: PackedVector3Array = inner.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var av: PackedVector3Array = inner.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("loft intérieur (cuvette) : normales vers le dedans", sti[0] and sti[1] and an[5].dot(Vector3(av[5].x, 0, av[5].z)) < 0.0)
	# tour chanfreiné (cylindre à fonds) et cylindre de remplacement
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0.12), Vector2(0, 0.12)])
	var lm := Builder.lathe_mesh(prof, 24, 1.0, 0.003)
	var stl := _mesh_sane(lm)
	var lb := lm.get_aabb()
	check("tour chanfreiné : normales, faces, tangentes, taille", stl[0] and stl[1] and stl[2] and absf(lb.size.x - 0.1) < 0.0005 and absf(lb.size.y - 0.12) < 0.0001, str(stl))
	var old := Builder.lathe_mesh(prof, 24)
	check("tour sans chanfrein : inchangé (SurfaceTool, normales lissées)", old.get_surface_count() == 1 and _tris(old) == 3 * 24 * 2)
	var cyl := Builder.cylinder_mesh(0.04, 0.04, 0.1, 24)
	check("cylindre chanfreiné : même boîte qu'un CylinderMesh", cyl is ArrayMesh and absf(cyl.get_aabb().size.y - 0.1) < 0.0001 and absf(cyl.get_aabb().get_center().y) < 0.0001)


func _perimeter(p: PackedVector2Array) -> float:
	var t := 0.0
	for i in p.size():
		t += p[i].distance_to(p[(i + 1) % p.size()])
	return t


# ------------------------------------------------------------------ _box et box_mesh

func _box_rules() -> void:
	var plain := _plain(Color(0.5, 0.4, 0.3), 0.6)
	var tri := Surfaces.world_uv(_plain(Color.WHITE), 1.0)
	var img := StandardMaterial3D.new()
	img.albedo_texture = PlaceholderTexture2D.new()
	var mi := _box(Vector3(0.4, 0.3, 0.2), Vector3.ZERO, plain)
	check("_box : boîte chanfreinée (matière unie)", mi.mesh is ArrayMesh and _tris(mi.mesh) == 44)
	check("_box : matière en coordonnées du monde : chanfreinée", Builder.box_mesh(Vector3(0.4, 0.3, 0.2), -1.0, tri) is ArrayMesh)
	check("_box : image dans les UV de la boîte : BoxMesh gardé", Builder.box_mesh(Vector3(0.4, 0.3, 0.2), -1.0, img) is BoxMesh)
	check("_box : verre de 6 mm : BoxMesh", Builder.box_mesh(Vector3(0.6, 1.0, 0.005), -1.0, plain) is BoxMesh)
	check("_box : dalle (sol, plafond) : BoxMesh", Builder.box_mesh(Vector3(4.0, 0.1, 3.0), -1.0, plain) is BoxMesh
		and Builder.box_mesh(Vector3(1.5, 0.1, 13.7), -1.0, plain) is BoxMesh and Builder.box_mesh(Vector3(1.4, 0.03, 0.62), -1.0, plain) is ArrayMesh)
	check("_box : bevel = 0 (morceaux de mur) : BoxMesh", Builder.box_mesh(Vector3(1.0, 2.6, 0.1), 0.0, plain) is BoxMesh)
	var r := (mi.mesh as ArrayMesh).get_aabb()
	check("_box : même boîte qu'avant", r.size.is_equal_approx(Vector3(0.4, 0.3, 0.2)) and mi.position == Vector3.ZERO)
	mi.queue_free()
	# rendu logiciel forcé : biseaux coupés
	var was: int = Main._soft
	Main._soft = 1
	check("_box en rendu logiciel : BoxMesh (comme la 0.3.3)", Builder.box_mesh(Vector3(0.4, 0.3, 0.2), -1.0, plain) is BoxMesh
		and Builder.cylinder_mesh(0.04, 0.04, 0.1) is CylinderMesh and Builder.soft_render())
	Main._soft = was


# ------------------------------------------------------------------ échelle par axe

func _stretch_tests() -> void:
	var raw := AABB(Vector3(-0.5, 0, -0.13), Vector3(1.0, 2.08, 0.26))    # Shelf_01
	var want := Vector3(0.75, 1.8, 0.4)
	var u := Builder._fit_scale3({"id": "Shelf_01"}, raw, want)
	var s := Builder._fit_scale3({"id": "Shelf_01", "stretch": true}, raw, want)
	var g := Builder._fit_scale3({"id": "GothicCabinet_01", "stretch": true}, raw, want)
	var c := Builder._fit_scale3({"id": "ClassicNightstand_01", "stretch": true}, raw, want)
	var sy := 1.8 / 2.08
	check("stretch : uniforme sans la clé", u.x == u.y and u.y == u.z)
	check("stretch : hauteur exacte, x rempli, z borné à 1,3 × y", is_equal_approx(s.y, sy) and is_equal_approx(s.x, 0.75)
		and is_equal_approx(s.z, sy * Builder.STRETCH_MAX), str(s))
	check("stretch : refusé pour Gothic* et Classic*", g.x == g.y and g.y == g.z and c.x == c.y and c.y == c.z)
	var low := Builder._fit_scale3({"id": "metal_office_desk", "stretch": true}, AABB(Vector3.ZERO, Vector3(2.0, 0.79, 0.95)), Vector3(1.4, 0.76, 0.62))
	var sy2 := 0.76 / 0.79
	check("stretch : borné à 0,7 × y vers le bas", is_equal_approx(low.x, 0.7) and is_equal_approx(low.z, 0.7 * sy2), str(low))


# ------------------------------------------------------------------ tapis

func _rug_tests() -> void:
	var t0 := Time.get_ticks_usec()
	var m := Builder.rug_mesh(2.4, 1.5, false, Builder.RUG_TOP, Vector3(1.2, -0.75, Builder.RUG_LIFT), Builder.RUG_FRINGE)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	var bb := m.get_aabb()
	var st := _mesh_sane(m, 0)
	check("tapis : velours (normales, faces vers le haut et le bas, tangentes)", st[0] and st[1] and st[2], str(st))
	check("tapis : hauteur < 2 cm une fois posé à 4 mm (battants B1) et < 8 cm (_scan_rugs)",
		0.004 + bb.end.y < Door.LEAF_GAP and bb.size.y < 0.08, "dessus à %.1f mm du sol" % ((0.004 + bb.end.y) * 1000.0))
	check("tapis : chant jusqu'au sol, franges sur les petits côtés (5 cm)", absf(0.004 + bb.position.y - 0.0005) < 0.0002
		and absf(bb.size.x - 2.5) < 0.002 and absf(bb.size.z - 1.5) < 0.002 and m.get_surface_count() == 2, "%s" % bb)
	check("tapis : construit en moins de 6 ms", dt < 6.0, "%.2f ms, %d triangles" % [dt, _tris(m)])
	var rm := Builder.rug_mesh(0.9, 0.9, true, Builder.RUG_TOP_BAIN)
	var rs := _mesh_sane(rm)
	check("tapis rond : normales, faces, sans franges", rs[0] and rs[1] and rs[2] and rm.get_surface_count() == 1 and absf(rm.get_aabb().size.x - 0.9) < 0.002)
	# coin relevé : jamais si le tapis touche une zone de battant (ici devant P7, côté bureau)
	var z := Builder._door_zones()
	check("zones de battant : 7 portes", z.size() == 7)
	var near := _woven_rug("rugRectangle", Vector3(5.6, 0.004, 4.4), 0.0, Vector3(1.0, 0.01, 0.7), {})
	var far := _woven_rug("rugRound", Vector3(6.6, 0.004, -5.95), 0.0, Vector3(0.9, 0, 0.9), {})
	var nb := _aabb_of(near, self)
	check("tapis dans une zone de battant : aucun coin relevé", nb.end.y < Door.LEAF_GAP and nb.size.y < 0.0125, "%.1f mm" % (nb.end.y * 1000.0))
	check("tapis : nom, props et méta inchangés", near.name == "rugRectangle" and props.get("rugRectangle") == near and props.get("rugRound") == far
		and (near.get_meta("size") as Vector3).x == 1.0 and far.get_meta("design") == "bain")
	var lifted := _woven_rug("rugRectangle", Vector3(0.1, 0.004, 0.5), 0.0, Vector3(2.4, 0.01, 1.5), {"design": "oriental"})
	var lb := _aabb_of(lifted, self)
	check("tapis de la chambre : un coin relevé, sous 2 cm", lb.size.y > 0.014 and lb.end.y < Door.LEAF_GAP, "%.1f mm" % (lb.end.y * 1000.0))
	# rendu logiciel : ni franges ni tissage ; l'empreinte au sol est exactement celle du tapis (0.3.3)
	Main._soft = 1
	var soft := _woven_rug("rugRectangle", Vector3(0.1, 0.004, 9.5), 0.0, Vector3(2.4, 0.01, 1.5), {"design": "oriental"})
	var sb := _aabb_of(soft, self)
	var smi := soft.get_child(0) as MeshInstance3D
	var sm := smi.mesh.surface_get_material(0) as StandardMaterial3D
	check("tapis en rendu logiciel : sans franges ni tissage, même empreinte qu'avant", smi.mesh.get_surface_count() == 1
		and not sm.detail_enabled and not sm.normal_enabled and absf(sb.size.x - 2.4) < 0.001 and absf(sb.size.z - 1.5) < 0.001, _fmt(sb.size))
	Main._soft = 0
	for n in [near, far, lifted, soft]:
		n.queue_free()


# ------------------------------------------------------------------ detail()

func _detail_tests() -> void:
	var was: int = Main._soft
	Main._soft = 1
	check("detail() en rendu logiciel forcé : null", detail("jug_01", Vector3(1, 0, 1)) == null)
	Main._soft = 0
	var id := "jug_01"
	if not ResourceLoader.exists(PH_PATH % [id, id]):
		check("detail() : modèle de test présent", false, id)
		Main._soft = was
		return
	var n0 := props.size()
	var a := detail(id, Vector3(1, 0, 1), 30.0, Vector3(0, 0.2, 0))
	var b := detail(id, Vector3(2, 0, 1))
	check("detail() : support rendu tout de suite, noms uniques", a != null and b != null and String(a.name).begins_with("Detail_jug_01_")
		and a.name != b.name and a.get_child_count() == 0, "%s %s" % [a.name if a else "null", b.name if b else "null"])
	var frames := 0
	while Builder.details_pending() > 0 and frames < 600:
		await get_tree().process_frame
		frames += 1
	var ok := is_instance_valid(a) and a.has_meta("ready") and a.get_child_count() == 1
	check("detail() : modèle posé en différé (chargement en arrière-plan)", ok, "%d images" % frames)
	if ok:
		var sz: Vector3 = a.get_meta("size")
		var gis := a.find_children("*", "GeometryInstance3D", true, false)
		var flags := not gis.is_empty()
		for g in gis:
			var gi := g as GeometryInstance3D
			if gi.gi_mode != GeometryInstance3D.GI_MODE_DISABLED or gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
					or not is_equal_approx(gi.visibility_range_end, 7.0):
				flags = false
		check("detail() : hors de props, sans collision, sans GI, sans ombre (< 0,3 m), caché après 7 m",
			props.size() == n0 and a.find_children("*", "CollisionObject3D", true, false).is_empty() and flags, "taille %s" % sz)
		check("detail() : mis à l'échelle demandée (hauteur 0,2 m)", absf(sz.y - 0.2) < 0.001, str(sz))
	var c := detail(id, Vector3(3, 0, 1), 0.0, Vector3.ZERO, {"sync": true})
	check("detail() sync : posé tout de suite", c != null and c.has_meta("ready"))
	Main._soft = was
	# les motifs des tapis posés plus haut se chargent en arrière-plan, puis rejoignent leur matière
	frames = 0
	while not Builder._rug_tex_wait.is_empty() and frames < 600:
		await get_tree().process_frame
		frames += 1
	var mo := Builder._rug_pattern_mat("oriental")
	var mb := Builder._rug_pattern_mat("bain")
	check("tapis : motifs chargés en arrière-plan, puis posés", mo.albedo_texture != null and mo.roughness_texture == mo.albedo_texture
		and mb.albedo_texture != null and mo.albedo_color == Color.WHITE, "%d images" % frames)


# ------------------------------------------------------------------ la maison (relevé)

## Construit le jeu (comme tests/floor_test.tscn) et relève le temps de construction (imprimé par main.gd)
## et l'usage des boîtes chanfreinées. software : rendu logiciel forcé (biseaux coupés).
func _house(software: bool) -> void:
	Main._soft = 1 if software else 0
	Builder.bevel_stats = Vector2i.ZERO
	var t0 := Time.get_ticks_msec()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	print("MAISON %s : %d ms (scène), boîtes chanfreinées : %d demandées, %d maillages construits" % [
		"logiciel" if software else "complet", Time.get_ticks_msec() - t0, Builder.bevel_stats.x, Builder.bevel_stats.y])
	get_tree().quit()
