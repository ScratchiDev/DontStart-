extends Builder
## Galerie de la bibliothèque d'usure (lot V1-USURE, exclue de l'export) : une pièce témoin de 6 × 4 m
## (mur, plafond, sol, plinthes, meubles simples) qui porte CHAQUE genre de Wear, avec son nom, et deux
## panneaux de comparaison de la crasse (grime.png contre les masques HD de Surfaces). Pour une capture :
##   godot --path godot --resolution 960x540 res://tests/wear_galerie.tscn -- --rendu-complet --shots=<dossier>
## Sans « --rendu-complet », le rendu logiciel prend le profil allégé : seuls les décalques du récit
## (empreintes) apparaissent. Sans affichage (--headless), la pièce est construite puis le banc quitte
## (contrôle de l'analyse et des appels). Vues écrites : usure_<vue>.png, puis Godot quitte.
## Vues : mur, plafond, sol, sol_rasant (lampe en face : empreintes mouillées et chemin mat), vitre_lampe
## (lampe de poche sur une vitre noire : traces de doigts, traînée), crasse_hd, pied_mur, details.

const XW := -3.0
const XE := 3.0
const ZN := -2.0
const ZS := 2.0
const H := 2.6

var shots := ""
var cam: Camera3D
var lamp: OmniLight3D
var front: OmniLight3D
var torch: SpotLight3D
var sconce: OmniLight3D
var room: HouseRoom
var env: Environment
var placed := {}      # genre -> nombre de décalques posés


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	# (sans affichage, « --rendu-complet » force aussi le profil des vraies cartes : contrôle des appels)
	if OS.get_cmdline_user_args().has("--rendu-complet") and DisplayServer.get_name() == "headless":
		Main._soft = 0
	_make_materials()
	_environment()
	_build_room()
	# (crasse HD de Surfaces : remplacée une image après la construction, comme dans le jeu)
	await get_tree().process_frame
	await get_tree().process_frame
	_compare_panels()
	_wear()
	var kinds := []
	for k in Wear.KINDS:
		kinds.append("%s %d" % [k, int(placed.get(k, 0))])
	print("GALERIE décalques par genre : " + ", ".join(kinds))
	var missing := []
	for k in Wear.KINDS:
		if int(placed.get(k, 0)) == 0:
			missing.append(k)
	print("GALERIE %s (rendu %s)" % ["chaque genre posé" if missing.is_empty() else "genres absents : " + ", ".join(missing),
		"logiciel" if Main.software_renderer() else "complet"])
	if DisplayServer.get_name() != "headless" and shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		await _views()
	print("GALERIE FINIE")
	get_tree().quit()


# ------------------------------------------------------------------ décor

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.58)
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.tonemap_agx_white = 3.0
	env.tonemap_agx_contrast = 1.35
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_depth_tolerance = 0.15
	we.environment = env
	add_child(we)
	cam = Camera3D.new()
	cam.current = true
	add_child(cam)


func _build_room() -> void:
	room = HouseRoom.new()
	room.name = "Galerie"
	room.setup("galerie", Rect2(XW, ZN, XE - XW, ZS - ZN), 0.0, H, "Galerie d'usure")
	room.floor_kind = "parquet"
	add_child(room)
	var w := XE - XW
	var d := ZS - ZN
	# sol : parquet à gauche, moquette à droite ; plafond ; murs (peinture, papier peint, vert du bureau)
	_box(Vector3(w / 2.0, 0.1, d), Vector3(-1.5, -0.05, 0.0), mats.floor)
	_box(Vector3(w / 2.0, 0.1, d), Vector3(1.5, -0.05, 0.0), mats.moquette)
	_box(Vector3(w, 0.1, d), Vector3(0.0, H + 0.05, 0.0), mats.ceil)
	_box(Vector3(w, H, 0.1), Vector3(0.0, H / 2.0, ZN - 0.05), mats.wall_paint)
	_box(Vector3(w, H, 0.1), Vector3(0.0, H / 2.0, ZS + 0.05), mats.wall_paint)
	_box(Vector3(0.1, H, d), Vector3(XW - 0.05, H / 2.0, 0.0), mats.wall)
	_box(Vector3(0.1, H, d), Vector3(XE + 0.05, H / 2.0, 0.0), mats.wall_olive)
	# plinthes (comme Builder.trim : 11 cm de haut, 3,5 cm d'épaisseur)
	_box(Vector3(w, 0.11, 0.035), Vector3(0.0, 0.055, ZN + 0.0175), mats.wood)
	_box(Vector3(0.035, 0.11, d), Vector3(XW + 0.0175, 0.055, 0.0), mats.wood)
	_box(Vector3(0.035, 0.11, d), Vector3(XE - 0.0175, 0.055, 0.0), mats.wood)
	# vitre noire (écran, cadre, fenêtre de nuit) : les traces n'y changent que la rugosité
	var glass := _plain(Color(0.015, 0.015, 0.018), 0.05)
	_box(Vector3(1.4, 0.75, 0.012), Vector3(-0.85, 1.35, ZN + 0.006), glass)
	_box(Vector3(1.48, 0.04, 0.03), Vector3(-0.85, 1.745, ZN + 0.015), mats.wood_dark)
	_box(Vector3(1.48, 0.04, 0.03), Vector3(-0.85, 0.955, ZN + 0.015), mats.wood_dark)
	# interrupteur, plaque de métal peint, applique
	_box(Vector3(0.085, 0.085, 0.012), Vector3(-2.4, 1.3, ZN + 0.006), _plain(Color(0.86, 0.83, 0.75), 0.35))
	_box(Vector3(0.6, 0.42, 0.03), Vector3(2.4, 1.32, ZN + 0.015), _plain(Color(0.33, 0.39, 0.4), 0.38, 0.6))
	_box(Vector3(0.1, 0.06, 0.08), Vector3(1.2, 1.6, ZN + 0.04), mats.metal)
	var bulb := _plain(Color(1.0, 0.85, 0.6))
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.8, 0.55)
	bulb.emission_energy_multiplier = 3.0
	_box(Vector3(0.05, 0.07, 0.05), Vector3(1.2, 1.66, ZN + 0.06), bulb)
	sconce = OmniLight3D.new()
	sconce.position = Vector3(1.2, 1.7, ZN + 0.15)
	sconce.light_color = Color(1.0, 0.82, 0.6)
	sconce.light_energy = 0.35
	sconce.omni_range = 1.4
	add_child(sconce)
	# coffre (poussière dessus) et petite table vernie (ronds de tasse)
	_box(Vector3(0.9, 0.45, 0.45), Vector3(-2.2, 0.225, -1.55), mats.wood_dark)
	var varnish := _plain(Color(0.36, 0.22, 0.13), 0.22)
	_box(Vector3(0.8, 0.03, 0.55), Vector3(-0.5, 0.72, -1.25), varnish)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.04, 0.705, 0.04), Vector3(-0.5 + sx * 0.35, 0.3525, -1.25 + sz * 0.23), varnish)
	# suspension au centre
	# (sans ombre portée : l'ampoule est juste au-dessus de la lumière)
	_box(Vector3(0.012, 0.3, 0.012), Vector3(0.0, H - 0.15, 0.0), mats.dark).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(0.09, 0.11, 0.09), Vector3(0.0, H - 0.34, 0.0), bulb).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0.0, H - 0.45, 0.0)
	lamp.light_color = Color(1.0, 0.86, 0.68)
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	lamp.shadow_enabled = true
	add_child(lamp)
	front = OmniLight3D.new()
	front.light_color = Color(1.0, 0.9, 0.78)
	front.omni_range = 5.0
	front.visible = false
	add_child(front)
	torch = SpotLight3D.new()
	torch.light_color = Color(1.0, 0.95, 0.86)
	torch.light_energy = 3.0
	torch.spot_range = 6.0
	torch.spot_angle = 30.0
	torch.spot_angle_attenuation = 0.6
	torch.visible = false
	add_child(torch)


## Panneaux de comparaison sur le mur sud : plâtre et bois, avec grime.png (à gauche de chaque paire) et
## avec le masque HD (à droite). Posés après le remplacement, avec des matières neuves.
func _compare_panels() -> void:
	var y := 1.3
	var specs := [
		["plâtre · grime.png", -1.3, "PaintedPlaster017/PaintedPlaster017", Color(0.86, 0.84, 0.79), 0.5, 0, 0.85],
		["plâtre · grime_hd_1", -0.45, "PaintedPlaster017/PaintedPlaster017", Color(0.86, 0.84, 0.79), 0.5, 1, 0.85],
		["bois · grime.png", 0.45, "Wood027/Wood027", Color(1, 1, 1), 0.5, 0, -1.0],
		["bois · grime_hd_2", 1.3, "Wood027/Wood027", Color(1, 1, 1), 0.5, 2, -1.0],
	]
	for s in specs:
		var m := Surfaces.pbr(s[2], 2.0 if String(s[2]).begins_with("Painted") else 1.2, s[3], 1.0, false, false, s[6])
		m = Surfaces.grime(m, s[4], maxi(1, int(s[5])))
		if int(s[5]) == 0:
			m.detail_albedo = Surfaces.grime_texture_old()
		_box(Vector3(0.8, 1.0, 0.02), Vector3(s[1], y, ZS - 0.01), m)
		_label(s[0], Vector3(s[1], y - 0.6, ZS - 0.03), 0.0011)


# ------------------------------------------------------------------ usure

func _put(kind: String, center: Vector3, normal: Vector3, up: Vector3, su: float, sv: float, opts := {}, label := "") -> Decal:
	var d := Wear.decal(room, kind, center, normal, up, su, sv, opts)
	if d:
		placed[kind] = int(placed.get(kind, 0)) + 1
	if label != "":
		_label(label, center + normal * 0.03 + _label_offset(normal, sv), 0.0011)
	return d


func _label_offset(normal: Vector3, sv: float) -> Vector3:
	if absf(normal.y) > 0.5:
		return Vector3(0, 0, sv / 2.0 + 0.08)
	return Vector3(0, -sv / 2.0 - 0.07, 0)


func _label(text: String, pos: Vector3, px := 0.0011) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = px
	l.outline_size = 10
	l.modulate = Color(1.0, 0.86, 0.45)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)


func _wear() -> void:
	var nb := Vector3.BACK
	var up := Vector3.UP
	var z := ZN
	# mur nord : en haut, ce qui descend du plafond
	_put("coulure", Vector3(-2.4, 2.32, z), nb, up, 1.1, 0.55, {"variant": 0}, "coulure")
	_put("moisissure", Vector3(-1.2, 2.2, z), nb, up, 1.0, 0.8, {"variant": 0}, "moisissure")
	_put("fissure", Vector3(0.15, 2.05, z), nb, up, 1.1, 0.55, {"variant": 1}, "fissure")
	_put("suie", Vector3(1.2, 2.08, z), nb, up, 0.5, 0.82, {"variant": 1}, "suie (panache)")
	_put("salissure", Vector3(2.4, 2.1, z), nb, up, 0.75, 0.75, {}, "salissure")
	# à hauteur de main
	_put("traces_doigts", Vector3(-2.4, 1.3, z), nb, up, 0.3, 0.3, {"variant": 0}, "traces_doigts")
	_put("trainee", Vector3(-1.15, 1.38, z), nb, up, 0.62, 0.5, {"variant": 0, "vitre": true}, "")
	_put("traces_doigts", Vector3(-0.45, 1.33, z), nb, up, 0.26, 0.3, {"variant": 1, "vitre": true}, "")
	_label("trainee · traces_doigts (vitre)", Vector3(-0.85, 0.88, z + 0.05))
	_put("cerne", Vector3(1.2, 1.15, z), nb, up, 0.7, 0.7, {"variant": 0}, "cerne")
	_put("rouille", Vector3(2.4, 1.18, z + 0.02), nb, up, 0.6, 0.16, {"depth": 0.06}, "rouille")
	# en bas : éraflures au-dessus de la plinthe, crasse de pied de mur sur les trois murs
	_put("eraflure", Vector3(0.6, 0.42, z), nb, up, 0.9, 0.45, {"variant": 0}, "eraflure")
	# éraflures claires dans le vernis du parquet, devant le coffre (meuble traîné)
	_put("eraflure", Vector3(-2.05, 0.0, -0.85), Vector3.UP, Vector3.RIGHT, 0.5, 0.9, {"variant": 1}, "eraflure (parquet)")
	var wb := Wear.wall_base(room, 0.22, {"sides": ["z0", "x0", "x1"]})
	placed["crasse_pied_mur"] = wb.size()
	_label("crasse_pied_mur", Vector3(1.9, 0.3, z + 0.08))
	# meubles : poussière sur le coffre, ronds de tasse sur la table vernie
	_put("poussiere", Vector3(-2.2, 0.45, -1.55), up, Vector3.BACK, 0.86, 0.42, {}, "poussiere")
	_put("rond_tasse", Vector3(-0.5, 0.735, -1.25), up, Vector3.BACK, 0.55, 0.45, {"variant": 0, "color": Wear.RING_LIGHT}, "rond_tasse")
	# plafond : quatre auréoles, halo de suie au-dessus de la suspension, colonie de moisissure, coins
	var dn := Vector3.DOWN
	var ceil_y := H
	for i in 4:
		var c: Vector3 = [Vector3(-2.0, ceil_y, -0.95), Vector3(-0.55, ceil_y, 1.0), Vector3(1.05, ceil_y, -0.95), Vector3(2.15, ceil_y, 1.05)][i]
		var sz: Vector2 = [Vector2(1.2, 1.2), Vector2(1.4, 1.0), Vector2(1.1, 1.1), Vector2(1.25, 1.25)][i]
		_put("tache_plafond", c, dn, Vector3.BACK, sz.x, sz.y, {"variant": i}, "tache_plafond %d" % (i + 1))
	_put("suie", Vector3(0.0, ceil_y, 0.0), dn, Vector3.BACK, 0.95, 0.95, {"variant": 0}, "suie (halo)")
	_put("moisissure", Vector3(-2.45, ceil_y, 1.45), dn, Vector3.BACK, 0.9, 0.9, {"variant": 1}, "moisissure 2")
	var cc := Wear.ceiling_corners(room)
	placed["coin"] = cc.size()
	_label("coin", Vector3(XE - 0.3, H - 0.25, ZN + 0.3))
	# sol : empreintes mouillées sur le parquet, usure de passage sur la moquette et le parquet
	var fp := Wear.footprints(room, [Vector3(-1.75, 0.0, 1.75), Vector3(-0.95, 0.0, -0.75)], {"fade_to": 0.6})
	placed["empreinte"] = fp.size()
	_label("empreinte (pieds nus mouillés)", Vector3(-1.9, 0.05, 1.2))
	var pm := Wear.path(room, [Vector2(2.4, 1.85), Vector2(1.6, 0.4), Vector2(1.15, -1.3)], 0.6, {"color": Wear.PATH_TINT.moquette, "mix": Wear.PATH_MIX.moquette})
	var pp := Wear.path(room, [Vector2(-0.15, 1.85), Vector2(-0.35, -0.2)], 0.5)
	placed["chemin_usure"] = pm.size() + pp.size()
	_label("chemin_usure (moquette)", Vector3(1.9, 0.05, 1.3))
	_label("chemin_usure (parquet)", Vector3(-0.2, 0.05, 1.0))


# ------------------------------------------------------------------ vues

func _views() -> void:
	var day := func() -> void:
		lamp.light_energy = 1.6
		front.visible = false
		torch.visible = false
	day.call()
	await _shot("mur", Vector3(0.0, 1.35, 1.9), Vector3(0.0, 1.35, ZN), 62.0)
	await _shot("mur_gauche", Vector3(-1.45, 1.55, 0.2), Vector3(-1.45, 1.5, ZN), 60.0)
	await _shot("mur_droite", Vector3(1.45, 1.55, 0.2), Vector3(1.45, 1.5, ZN), 60.0)
	await _shot("plafond", Vector3(0.0, 1.2, 1.9), Vector3(0.0, H, -0.5), 72.0)
	await _shot("sol", Vector3(0.2, 2.35, 2.0), Vector3(0.1, 0.0, -0.1), 68.0)
	# lampe basse en face : son reflet sur le sol montre la rugosité (mouillé = net, usé = mat)
	lamp.light_energy = 0.5
	front.visible = true
	front.position = Vector3(-1.2, 0.7, -1.7)
	front.light_energy = 2.2
	await _shot("sol_rasant", Vector3(-1.25, 0.62, 2.1), Vector3(-1.2, 0.0, -0.3), 52.0)
	front.position = Vector3(1.5, 0.7, -1.8)
	await _shot("moquette_rasant", Vector3(1.6, 0.62, 2.1), Vector3(1.4, 0.0, -0.3), 52.0)
	# lampe de poche sur la vitre noire : traces de doigts et traînée dans le reflet
	front.visible = false
	lamp.light_energy = 0.25
	torch.visible = true
	torch.position = Vector3(-0.72, 1.48, 0.1)
	torch.look_at(Vector3(-0.85, 1.35, ZN))
	await _shot("vitre_lampe", Vector3(-0.95, 1.4, 0.15), Vector3(-0.85, 1.35, ZN), 45.0)
	# meubles à la lampe de poche
	torch.position = Vector3(-1.2, 1.5, -0.15)
	torch.look_at(Vector3(-1.35, 0.6, -1.4))
	await _shot("details", Vector3(-1.35, 1.45, -0.2), Vector3(-1.35, 0.6, -1.4), 58.0)
	day.call()
	await _shot("crasse_hd", Vector3(0.0, 1.3, -0.45), Vector3(0.0, 1.3, ZS), 50.0)
	await _shot("crasse_hd_pres", Vector3(-0.875, 1.3, 1.25), Vector3(-0.875, 1.3, ZS), 45.0)
	await _shot("pied_mur", Vector3(-2.1, 0.62, -0.4), Vector3(-2.9, 0.08, -1.9), 55.0)


func _shot(view: String, pos: Vector3, target: Vector3, fov: float) -> void:
	cam.position = pos
	cam.look_at(target, Vector3.UP)
	cam.fov = fov
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(shots.path_join("usure_%s.png" % view))
		print("GALERIE vue %s" % view)
