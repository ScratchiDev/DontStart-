extends Node
## Banc des mains du joueur (Viewmodel) : la vraie maison (scenes/main.tscn), le joueur posé dans des
## situations précises, une capture AVEC les mains puis une SANS (réglage « Mains visibles » coupé :
## la lampe reprend sa place de la 0.3.3), au même cadrage. Pose des mains figée (Viewmodel.figee).
##   godot --path godot --rendering-driver vulkan --resolution 960x540 res://tests/mains_banc.tscn
##         -- --shots=DIR [--rendu-complet] [--hero=aurelia] [--vues=mere_nuit,mur_20cm,…] [--seul=avec|sans]
## Vues : mere_nuit, couloir_nuit, sdb_eclairee, chambre_jour (jour simulé : soleil et ciel clair, pour
## juger la peau en pleine lumière), mur_20cm (face au mur, l'œil à 20 cm : intersection), regard_bas,
## devant_pc (debout devant l'ordinateur allumé : la lueur verte de l'écran, toute proche de la main),
## inventaire (regard au sol près de la porte, comme l'autotest 22_inventaire).
## Masque : une passe de plus où la peau est peinte en magenta, la manche en cyan, la lampe en jaune.
## Sur la capture AVEC : M7 (devant_pc, inventaire) peau ni brûlée ni verte (luminance et saturation verte
## des pixels de peau, centile 99,5) ; M9 (toutes les vues) écart de luminance pouce / dos de la main ≤ 2,5
## (médianes autour des points « Pouce » et « Dos » du modèle) et teinte médiane de la peau entre 10° et
## 30° ; M10 (chambre_jour) manche / peau ≤ 1,2 en luminance. AVEC et SANS : M8 (regard_bas, inventaire,
## mur_20cm, devant_pc) la lampe éclaire autant avec les mains : hors de la vue (masque dilaté), luminance
## moyenne et part de l'image éclairée (L > 60/255) à ± 10 % de la capture sans les mains.
## « --retro » : style rétro (pixels) pour ce lancement.
## Chaque capture : <vue>_avec.png, <vue>_sans.png ; journal « MAINS <vue> … ».

const MAIN := preload("res://scenes/main.tscn")
const VUES := ["mere_nuit", "couloir_nuit", "sdb_eclairee", "chambre_jour", "mur_20cm", "regard_bas", "devant_pc", "inventaire"]

var main: Main
var player: CharacterBody3D
var shots := ""
var _mask_name := ""
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	_run.call_deferred()


func wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func check(id: String, cond: bool, detail := "") -> void:
	print("VÉRIF %s %s" % [id, "OK" if cond else "ÉCHEC : " + detail])
	if not cond:
		fails += 1


func _run() -> void:
	var vues: Array = VUES.duplicate()
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vues="):
			vues = Array(a.substr(7).split(",", false))
		elif a.begins_with("--seul="):
			seul = a.substr(7)
		elif a == "--retro":
			Game.style_retro = true
	if Game.style_retro:
		Game.apply_settings()
	main = MAIN.instantiate()
	add_child(main)
	player = main.player
	for i in 3:
		await get_tree().process_frame
	if main.reflections_busy():
		await main.reflections_settled
	Viewmodel.figee = true
	main.menu.hide_all()
	main.hud.fade.color.a = 0.0
	Game.phase = "room"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.can_move = false
	player.can_look = false
	player.set_physics_process(false)      # (pas de dépénétration : l'œil peut être à 20 cm d'un mur)
	print(Qualite.describe())
	print("MAINS héros %s · rendu %s" % [Game.hero, RenderingServer.get_video_adapter_name()])
	_checks()
	for v in vues:
		await _view(String(v), seul)
	print("MAINS BANC %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	Game.quit_game(0 if fails == 0 else 1)   # (sortie propre : la file de tâches vidée)


## Couches : la vue n'est vue que par la caméra du joueur.
func _checks() -> void:
	var vm: Viewmodel = player.viewmodel
	var bit := Builder.layer_bit(Viewmodel.LAYER)
	var ok := vm.model != null
	var layers_ok := true
	var shadows_ok := true
	var gi_ok := true
	for mi in Viewmodel._meshes(vm.model):
		layers_ok = layers_ok and mi.layers == bit
		shadows_ok = shadows_ok and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi_ok = gi_ok and mi.gi_mode == GeometryInstance3D.GI_MODE_DISABLED
	check("M1 modèle chargé (%s)" % vm.hero, ok, "")
	check("M2 couche %d seule, sans ombre, hors GI" % Viewmodel.LAYER, layers_ok and shadows_ok and gi_ok, "%s %s %s" % [layers_ok, shadows_ok, gi_ok])
	check("M3 caméra du joueur : couche vue", player.camera.get_cull_mask_value(Viewmodel.LAYER), "")
	var feeds_ok := true
	for fc in get_tree().get_nodes_in_group("feed_cam"):
		feeds_ok = feeds_ok and (int(fc.get("cull_mask")) & bit) == 0
	check("M4 caméras de flux et miroir : couche exclue", feeds_ok and (FeedCam.mask_with_feed_only() & bit) == 0, "")
	var probes_ok := true
	for id in main.house.rooms:
		var r: HouseRoom = main.house.rooms[id]
		if r.probe:
			probes_ok = probes_ok and (r.probe.cull_mask & bit) == 0
	check("M5 sondes de reflets : couche exclue", probes_ok, "")


func _room_lights(id: String, on: bool) -> void:
	var r: HouseRoom = main.house.rooms.get(id)
	if r == null:
		return
	for l in r._lights:
		if not is_instance_valid(l):
			continue
		var e := HouseRoom._base_energy(l)
		if on and e != 0.0:
			l.visible = true
			l.light_energy = 1.6 if e < 0.0 else e
		elif not on and not l.has_meta("always_on"):
			pass


var _sun: DirectionalLight3D
var _env_saved := {}


func _day(on: bool) -> void:
	var env := main.env
	if on:
		_env_saved = {"amb": env.ambient_light_energy, "sky": (env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier,
			"col": env.ambient_light_color}
		(env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = 3.0
		env.ambient_light_color = Color(0.55, 0.6, 0.68)
		env.ambient_light_energy = 0.9
		_sun = DirectionalLight3D.new()
		_sun.light_color = Color(1.0, 0.95, 0.86)
		_sun.light_energy = 2.2
		_sun.shadow_enabled = true
		_sun.rotation_degrees = Vector3(-32.0, -70.0, 0.0)
		main.add_child(_sun)
	else:
		if _sun:
			_sun.queue_free()
			_sun = null
		if not _env_saved.is_empty():
			(env.sky.sky_material as PanoramaSkyMaterial).energy_multiplier = _env_saved.sky
			env.ambient_light_energy = _env_saved.amb
			env.ambient_light_color = _env_saved.col


func _place(pos: Vector3, yaw: float, pitch: float) -> void:
	player.global_position = pos
	player.set_look(yaw, pitch)
	player.head.position = Vector3(0, player.EYE, 0)
	player.camera.rotation.z = 0.0


func _flash(on: bool) -> void:
	if player.flash_on != on:
		player.toggle_flashlight()
	player.flashlight.light_energy = player.flash_base * 0.75


func _view(v: String, seul: String) -> void:
	_day(false)
	match v:
		"mere_nuit":
			_flash(true)
			_place(Acte1.START_POS, Acte1.START_YAW, -0.12)
		"couloir_nuit":
			_flash(true)
			_place(Vector3(4.0, 0.0, 4.6), 0.0, -0.06)
		"sdb_eclairee":
			_flash(true)
			_room_lights("sdb", true)
			_place(Vector3(5.35, 0.0, -4.75), -PI / 2.0 + 0.35, -0.18)
		"chambre_jour":
			_flash(false)
			_room_lights("mere", true)
			_day(true)
			_place(Vector3(1.2, 0.0, 1.2), PI / 2.0 - 0.25, -0.12)
		"mur_20cm":
			_flash(true)
			_place(Vector3(3.0, 0.0, -1.0), -PI / 2.0, -0.05)
		"regard_bas":
			_flash(true)
			_place(Acte1.START_POS, Acte1.START_YAW, -1.15)
		"devant_pc":
			_flash(true)
			_place(Vector3(1.2, 0.0, -1.0), 0.0, -0.3)
		"inventaire":
			_flash(true)
			_place(Vector3(2.2, 0.0, 1.32), -PI / 2.0, -1.1)
		_:
			print("vue inconnue : ", v)
			return
	var imgs := {}
	var mask: Image = null
	for w in ["avec", "sans"]:
		if seul != "" and seul != w:
			continue
		Game.mains_visibles = w == "avec"
		# (avec : le temps que l'équilibre mesuré sur l'image se règle)
		await wait(3.0 if w == "avec" else 1.2)
		var img := get_viewport().get_texture().get_image()
		imgs[w] = img
		if shots != "":
			img.save_png(shots.path_join("%s_%s.png" % [v, w]))
		var vm: Viewmodel = player.viewmodel
		var lp: Vector3 = player.flashlight.global_position
		print("MAINS %s %s · lampe %s · œil %s · baissée %.2f obstacle %.2f sol %.2f rebond %.2f · équilibre %s" % [v, w, lp, player.camera.global_position, vm._lower, vm._obst, vm._down, vm.bounce.light_energy, vm.bal_stats])
		if w == "avec" and v == "mur_20cm":
			# la lumière reste de ce côté du mur (x < 3,2)
			check("M6 face au mur : la lampe ne passe pas le mur", lp.x < 3.2, "x = %.3f" % lp.x)
		if w == "avec":
			_mask_name = "%s_masque.png" % v
			mask = await _mask_pass()
			var st: Dictionary = _skin_stats(img, mask)
			print("MAINS %s peau : %d px, luminance p99,5 %.2f (max %.2f), saturation verte p99,5 %.2f (max %.2f)" % [
				v, st.n, st.lum, st.lum_max, st.green, st.green_max])
			# (pas en style rétro : palette réduite, tramage et franges colorées font des pixels saturés)
			if (v == "devant_pc" or v == "inventaire") and not Game.style_retro:
				check("M7 %s : peau ni brûlée ni verte" % v, st.n > 200 and st.lum <= 0.9 and st.green <= 0.35,
					"%d px, luminance %.2f, vert %.2f" % [st.n, st.lum, st.green])
			var pr: Dictionary = _thumb_back(img, mask)
			print("MAINS %s pouce %.3f dos %.3f écart %.2f · teinte médiane %.0f° (p10 %.0f°, p90 %.0f°) · manche %.3f peau %.3f" % [
				v, pr.pouce, pr.dos, pr.ecart, pr.hue, pr.hue10, pr.hue90, pr.manche, pr.peau])
			if not Game.style_retro:
				check("M9 %s : écart pouce / dos ≤ 2,5, teinte de la peau 10-30°" % v,
					pr.ecart <= 2.5 and pr.hue >= 10.0 and pr.hue <= 30.0,
					"écart %.2f, teinte %.0f°" % [pr.ecart, pr.hue])
				if v == "chambre_jour":
					check("M10 chambre_jour : manche / peau ≤ 1,2", pr.peau > 0.0 and pr.manche / pr.peau <= 1.2,
						"manche %.3f, peau %.3f" % [pr.manche, pr.peau])
	if imgs.size() == 2 and mask and v in ["regard_bas", "inventaire", "mur_20cm", "devant_pc"]:
		var a := _beam_stats(imgs.avec, mask)
		var b := _beam_stats(imgs.sans, mask)
		var dl: float = a.lum / maxf(b.lum, 0.001) - 1.0
		var da: float = a.lit / maxf(b.lit, 0.001) - 1.0
		print("MAINS %s faisceau : luminance hors de la vue %.1f / %.1f (%+.0f %%), part éclairée %.1f %% / %.1f %% (%+.0f %%)" % [
			v, a.lum * 255.0, b.lum * 255.0, dl * 100.0, a.lit * 100.0, b.lit * 100.0, da * 100.0])
		check("M8 %s : la lampe éclaire autant avec les mains (± 10 %%)" % v, absf(dl) <= 0.10 and (absf(da) <= 0.10 or absf(a.lit - b.lit) < 0.004),
			"luminance %+.0f %%, part éclairée %+.0f %%" % [dl * 100.0, da * 100.0])
	Game.mains_visibles = true


static func _magenta(m: Image, x: int, y: int) -> bool:
	var c := m.get_pixel(x, y)
	return c.r > 0.75 and c.b > 0.75 and c.r - c.g > 0.25 and c.b - c.g > 0.25


static func _cyan(m: Image, x: int, y: int) -> bool:
	var c := m.get_pixel(x, y)
	return c.g > 0.75 and c.b > 0.75 and c.g - c.r > 0.25 and c.b - c.r > 0.25


## Pixel de la vue (peau, manche, lampe…) : magenta, cyan ou jaune dans le masque.
static func _any_vm(m: Image, x: int, y: int) -> bool:
	var c := m.get_pixel(x, y)
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	return mx > 0.6 and mx - mn > 0.35


## Passe de masque : la peau en magenta, la manche en cyan, le reste de la vue (lampe, bracelet) en jaune,
## sans éclairage ; rend l'image (et l'écrit si « shots »).
func _mask_pass() -> Image:
	var vm: Viewmodel = player.viewmodel
	vm.balance_on = false
	var old := {}
	for mi in Viewmodel._meshes(vm.model):
		var col := Color(1, 1, 0)
		if mi.name == "Main":
			col = Color(1, 0, 1)
		elif mi.name == "Manche":
			col = Color(0, 1, 1)
		var mk := StandardMaterial3D.new()
		mk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mk.albedo_color = col
		mk.use_z_clip_scale = true
		mk.z_clip_scale = Viewmodel.Z_CLIP
		mk.use_fov_override = true
		mk.fov_override = Viewmodel.FOV
		var mats := []
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(s))
			mi.set_surface_override_material(s, mk)
		old[mi] = mats
	await wait(0.4)
	var m := get_viewport().get_texture().get_image()
	for mi: MeshInstance3D in old:
		for s in (old[mi] as Array).size():
			mi.set_surface_override_material(s, old[mi][s])
	if shots != "" and _mask_name != "":
		m.save_png(shots.path_join(_mask_name))
	await wait(0.3)
	vm.balance_on = true
	return m


## Pouce / dos de la main : médianes de luminance des pixels de peau à moins de r px des points « Pouce »
## et « Dos » du modèle projetés ; teinte des pixels de peau (médiane, p10, p90 ; pixels assez clairs) ;
## médianes de luminance de la manche et de la peau.
func _thumb_back(img: Image, m: Image) -> Dictionary:
	var vm: Viewmodel = player.viewmodel
	var size := Vector2(img.get_width(), img.get_height())
	var inv: Transform3D = player.camera.global_transform.affine_inverse()
	var pp := Vector2(-1000, -1000)
	var pd := Vector2(-1000, -1000)
	if vm._marks.has("Pouce"):
		pp = vm._vm_pixel(inv * (vm._marks["Pouce"] as Node3D).global_position, size)
	if vm._marks.has("Dos"):
		pd = vm._vm_pixel(inv * (vm._marks["Dos"] as Node3D).global_position, size)
	var r := size.y * 0.028
	var th := PackedFloat32Array()
	var bk := PackedFloat32Array()
	var hues := PackedFloat32Array()
	var skin := PackedFloat32Array()
	var sleeve := PackedFloat32Array()
	for y in range(2, m.get_height() - 2, 2):
		for x in range(2, m.get_width() - 2, 2):
			var p := img.get_pixel(x, y)
			var l := 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
			if _cyan(m, x, y) and _cyan(m, x - 2, y) and _cyan(m, x + 2, y):
				sleeve.append(l)
				continue
			if not (_magenta(m, x, y) and _magenta(m, x - 2, y) and _magenta(m, x + 2, y) and _magenta(m, x, y - 2) and _magenta(m, x, y + 2)):
				continue
			skin.append(l)
			var q := Vector2(x, y)
			if q.distance_to(pp) < r:
				th.append(l)
			elif q.distance_to(pd) < r * 1.6:
				bk.append(l)
			if l > 0.03 and p.s > 0.08:
				var h := p.h * 360.0
				hues.append(h - 360.0 if h > 300.0 else h)
	var out := {"pouce": _med(th), "dos": _med(bk), "ecart": 0.0, "hue": _pct(hues, 0.5), "hue10": _pct(hues, 0.1),
		"hue90": _pct(hues, 0.9), "manche": _med(sleeve), "peau": _med(skin)}
	var lo := minf(out.pouce, out.dos)
	var hi := maxf(out.pouce, out.dos)
	out.ecart = hi / maxf(lo, 0.004) if lo >= 0.0 else 99.0
	return out


static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return -1.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(b.size() * q), 0, b.size() - 1)]


static func _med(a: PackedFloat32Array) -> float:
	return _pct(a, 0.5)


## Hors de la vue (masque dilaté de 12 px : bords, halo de l'ampoule) : luminance moyenne et part des
## pixels éclairés (L > 60/255).
func _beam_stats(img: Image, m: Image) -> Dictionary:
	var w := m.get_width()
	var h := m.get_height()
	var excl := PackedByteArray()
	excl.resize(w * h)
	var d := 12
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if _any_vm(m, x, y):
				for yy in range(maxi(y - d, 0), mini(y + d + 1, h)):
					for xx in range(maxi(x - d, 0), mini(x + d + 1, w), 2):
						excl[yy * w + xx] = 1
	var s := 0.0
	var lit := 0
	var n := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if excl[y * w + x] != 0:
				continue
			var p := img.get_pixel(x, y)
			var l := 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
			s += l
			n += 1
			if l > 60.0 / 255.0:
				lit += 1
	return {"lum": s / maxf(n, 1.0), "lit": float(lit) / maxf(n, 1.0)}


## Statistiques des pixels de peau (magenta dans le masque) de la capture « img » : luminance (Rec. 709,
## valeurs affichées) et saturation des teintes vertes (75° à 165°), centile 99,5 et maximum.
func _skin_stats(img: Image, m: Image) -> Dictionary:
	var out := {"n": 0, "lum": 0.0, "lum_max": 0.0, "green": 0.0, "green_max": 0.0}
	var lums := PackedFloat32Array()
	var greens := PackedFloat32Array()
	# (masque érodé de 2 px : les bords, mêlés au fond par l'anticrénelage, ne comptent pas)
	for y in range(2, m.get_height() - 2, 2):
		for x in range(2, m.get_width() - 2, 2):
			if not (_magenta(m, x, y) and _magenta(m, x - 2, y) and _magenta(m, x + 2, y) and _magenta(m, x, y - 2) and _magenta(m, x, y + 2)):
				continue
			var p := img.get_pixel(x, y)
			lums.append(0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b)
			var mx := maxf(p.r, maxf(p.g, p.b))
			var mn := minf(p.r, minf(p.g, p.b))
			var sat := (mx - mn) / mx if mx > 0.0 else 0.0
			greens.append(sat if p.h * 360.0 >= 75.0 and p.h * 360.0 <= 165.0 else 0.0)
	out.n = lums.size()
	if lums.size() > 0:
		lums.sort()
		greens.sort()
		var i := clampi(int(lums.size() * 0.995), 0, lums.size() - 1)
		out.lum = lums[i]
		out.lum_max = lums[lums.size() - 1]
		out.green = greens[i]
		out.green_max = greens[greens.size() - 1]
	return out
