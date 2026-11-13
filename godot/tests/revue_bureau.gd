extends "res://scripts/main.gd"
## Relecture (exclue de l'export) : vérifications ciblées du bureau, de la chambre des grands-parents,
## des ajouts du couloir et de Clovis, jouées comme un joueur (rayon de visée, E).
## godot --path godot --rendering-driver vulkan res://tests/revue_bureau.tscn -- --shots=DIR

var fails := 0


func _ready() -> void:
	super()
	_run.call_deferred()


func _check(id: String, cond: bool, detail := "") -> void:
	print("VÉRIF %s %s" % [id, "OK" if cond else "ÉCHEC : " + detail])
	if not cond:
		fails += 1


func _aim(from: Vector3, at: Vector3) -> Vector2:
	var eye := from + Vector3(0, player.EYE, 0)
	var d := at - eye
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _look(from: Vector3, at: Vector3, n: String, wait := 0.8) -> void:
	var a := _aim(from, at)
	await _view(from, a.x, a.y, n, wait)


## Vise « at » depuis « from » et renvoie le libellé visé.
func _target(from: Vector3, at: Vector3) -> String:
	var a := _aim(from, at)
	player.global_position = from
	player.set_look(a.x, a.y)
	player.head.position.y = player.EYE
	await get_tree().create_timer(0.4).timeout
	return player.current.label if player.current else "rien"


func _run() -> void:
	menu.hide_all()
	hud.fade.color.a = 0.0
	Game.phase = "room"
	player.can_move = false
	await get_tree().create_timer(1.0).timeout
	var bureau: Node = house.rooms.get("bureau")
	var gp: Node = house.rooms.get("gp")
	var couloir: Node = house.rooms.get("couloir")
	# --- zones de battant : tous les maillages (sauf câbles et scotch au sol) contre P7 et P2
	var zones := {"bureau": Rect2(4.8, 3.9, 0.95, 1.0), "gp": Rect2(2.25, -4.1, 0.95, 1.0)}
	for rid in zones:
		var r: HouseRoom = house.rooms[rid]
		var bad := []
		for n in r.find_children("*", "VisualInstance3D", true, false):
			var vi := n as VisualInstance3D
			if vi is Light3D or not vi.is_visible_in_tree():
				continue
			var bx: AABB = vi.global_transform * vi.get_aabb()
			if bx.end.y < 0.03 or bx.position.y > 2.3:
				continue   # câbles et scotch au sol, plafond
			var rr := Rect2(bx.position.x, bx.position.z, bx.size.x, bx.size.z)
			var z: Rect2 = zones[rid]
			var inter := rr.intersection(z)
			if rr.intersects(z) and inter.size.x > 0.005 and inter.size.y > 0.005:
				# les murs et l'habillage de la pièce (lambris, plinthes) sont exclus : enfants directs sans nom propre
				var p := vi.get_parent()
				var path := str(r.get_path_to(vi))
				if p == r and (bx.size.y > 2.0 or bx.size.x < 0.06 or bx.size.z < 0.06):
					continue
				bad.append("%s %s" % [path, rr])
		_check("zone_toutes_" + rid, bad.is_empty(), str(bad.slice(0, 6)))
	# --- le bureau : console, portable, imprimante, box
	player.global_position = Vector3(6.9, 0, 4.2)
	await get_tree().create_timer(1.0).timeout
	var cons: HouseConsole = bureau.get("console")
	await bureau.wake_up()
	_check("drapeau_console", Game.flag("console_allumee", false) == true, "pas de drapeau")
	if not player.flash_on:
		player.toggle_flashlight()
	# portable : écran verrouillé, puis la messagerie
	var l0: String = await _target(Vector3(7.0, 0, 3.2), Vector3(6.95, 0.85, 2.42))
	_check("portable_libelle", l0 == "Regarder l'ordinateur portable", l0)
	player.current.use()
	await get_tree().create_timer(0.5).timeout
	await _look(Vector3(7.0, 0, 3.2), Vector3(6.95, 0.85, 2.4), "r_portable_verrouille", 0.4)
	var l1: String = await _target(Vector3(7.0, 0, 3.2), Vector3(6.95, 0.85, 2.42))
	_check("portable_libelle2", l1 == "Taper le mot de passe", l1)
	player.current.use()
	player.current.use()     # double appui pendant la saisie : une seule lecture
	await get_tree().create_timer(1.3).timeout
	_check("portable_pages", hud.paper_open and Game.flag("portable_lu", false) == true, "pas de pages")
	hud.close_paper()
	await get_tree().create_timer(0.3).timeout
	await _look(Vector3(7.0, 0, 3.0), Vector3(6.95, 0.85, 2.4), "r_portable_messagerie", 0.4)
	# imprimante : la feuille sortie se ramasse au rayon
	var pr: Printer = bureau.get("printer")
	pr.print_page("plan_imprime", load("res://assets/images/plan_etage.png"))
	await _until(func() -> bool: return pr.has_sheet("plan_imprime"), 20.0)
	var sheet_c: Vector3 = pr.to_global(Vector3(0, 0.17, pr.body_size.z / 2.0 + 0.025 - Printer.SHEET.y / 2.0))
	var l2: String = await _target(Vector3(8.3, 0, 5.05), sheet_c)
	_check("feuille_visee", l2 == "Prendre la feuille", l2)
	await _shot("r_imprimante_feuille")
	if player.current:
		player.current.use()
	await get_tree().create_timer(0.4).timeout
	_check("feuille_prise", Game.has_item("plan_imprime"), str(Game.items))
	hud.close_paper()
	# box : regarder, débrancher (jauge +1 une fois)
	var p0 := Game.peur
	var l3: String = await _target(Vector3(5.55, 0, 5.2), Vector3(5.55, 0.03, 6.12))
	_check("box_libelle", l3 == "Regarder la box", l3)
	player.current.use()
	var l4: String = await _target(Vector3(5.55, 0, 5.2), Vector3(5.55, 0.03, 6.12))
	_check("box_libelle2", l4 == "Débrancher la box", l4)
	player.current.use()
	await get_tree().create_timer(5.0).timeout
	_check("box_peur", absf(Game.peur - p0 - 1.0) < 0.01, "peur %s -> %s" % [p0, Game.peur])
	# caméras : grand écran, puis H-CAM2..4, jauge +2
	var p1 := Game.peur
	var l5: String = await _target(Vector3(7.2, 0, 5.15), Vector3(7.2, 1.0, 6.1))
	_check("cameras_libelle", l5 == "Regarder les caméras", l5)
	var hints: Array = []
	Game.hint_requested.connect(func(t: String, _s: float) -> void: hints.append(t))
	player.current.use()
	await get_tree().create_timer(0.5).timeout
	_check("grand_ecran", hud.screen_open, "écran fermé")
	await _shot("r_cameras_ecran")
	hud.close_screen()
	await get_tree().create_timer(21.0).timeout
	var want: Array = bureau.get("H_CAM")
	_check("hcam", hints.slice(0, 3) == want, str(hints))
	_check("cameras_peur", absf(Game.peur - p1 - 2.0) < 0.01 and Game.flag("cameras_vues", false) == true, "peur %s -> %s" % [p1, Game.peur])
	# tiroir : ouvrir puis prendre le tournevis
	var l6: String = await _target(Vector3(6.78, 0, 4.85), Vector3(6.78, 0.6, 5.6))
	_check("tiroir_libelle", l6 == "Ouvrir le tiroir", l6)
	player.current.use()
	await get_tree().create_timer(0.8).timeout
	var l7: String = await _target(Vector3(6.78, 0, 4.85), Vector3(6.78, 0.6, 5.45))
	_check("tiroir_libelle2", l7 == "Prendre le tournevis", l7)
	if player.current:
		player.current.use()
	_check("tournevis", Game.has_item("tournevis"), str(Game.items))
	# lumière
	var l8: String = await _target(Vector3(5.3, 0, 3.7), Vector3(4.82, 1.1, 3.7))
	_check("interrupteur_bureau", l8 == "Allumer la lumière", l8)
	player.current.use()
	_check("lumiere_bureau", bureau.get("light_on") == true and Game.flag("lumiere_bureau", false) == true, "éteinte")
	# couloir : Nestor (avec le tournevis), interrupteur qui bloque l'enchaînement des ampoules
	var l9: String = await _target(Vector3(4.2, 0, -0.6), Vector3(3.52, 0.9, -1.0))
	_check("nestor_libelle", l9 == "Débrancher l'enceinte", l9)
	var l9b: String = await _target(Vector3(3.95, 0, 0.3), Vector3(3.52, 0.9, -1.0))
	_check("nestor_depuis_le_sud", l9b == "Débrancher l'enceinte", l9b)
	var l9c: String = await _target(Vector3(4.2, 0, -0.2), Vector3(3.55, 0.85, -0.8))
	_check("telephone", l9c == "Regarder le téléphone", l9c)
	await _look(Vector3(4.3, 0, 0.2), Vector3(3.52, 0.8, -1.0), "r_console_couloir", 0.4)
	l9 = await _target(Vector3(4.2, 0, -0.6), Vector3(3.52, 0.9, -1.0))
	player.current.use()
	_check("nestor_debranche", Game.flag("nestor_debranche", false) == true, "branchée")
	var l10: String = await _target(Vector3(4.0, 0, 0.75), Vector3(3.31, 1.1, 0.75))
	_check("interrupteur_couloir", l10 == "Éteindre la lumière", l10)
	player.current.use()
	couloir.chain_lights()
	await get_tree().create_timer(1.2).timeout
	var lit := 0.0
	for b in couloir.get("bulbs"):
		lit += (b as OmniLight3D).light_energy
	_check("interrupteur_coupe", lit < 0.001, "énergie %s" % lit)
	await _look(Vector3(4.0, 0, 2.0), Vector3(4.0, 1.2, -4.0), "r_couloir_coupe", 0.5)
	# restauration : rien ne casse quand on rappelle restore()
	for rid in ["bureau", "gp", "couloir"]:
		house.rooms[rid].call("restore")
	_check("restore_tiroir", bureau.get("drawer_open") == true and bureau.get("laptop_state") == 2, "état perdu")
	# CAM 3 : pouls changé, puis restauré
	gp.set_heart(55)
	_check("pouls", int(Game.flag("pouls_henriette", 0)) == 55, str(Game.flags))
	gp.set_heart(58)
	# couloir : interrupteur remis, portrait « 1996 », radiateur du plan, LED de la caméra fixée 3 s
	couloir.set_switch(true)
	var rp: Vector3 = couloir.get("RADIATOR_POS")
	var rad_box := AABB()
	var first := true
	for n in couloir.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var bx: AABB = mi.global_transform * mi.get_aabb()
		if absf(bx.get_center().z - rp.z) < 0.55 and bx.get_center().x > 4.4 and bx.end.y < 0.9:
			rad_box = bx if first else rad_box.merge(bx)
			first = false
	print("radiateur : ", rad_box)
	_check("radiateur_plan", absf(rad_box.get_center().z - rp.z) < 0.08 and absf(rad_box.get_center().y - rp.y) < 0.08 and rad_box.end.x < 4.69, str(rad_box))
	await _look(Vector3(3.8, 0, -0.8), Vector3(4.3, 0.5, -2.9), "r_couloir_radiateur", 0.6)
	await _look(Vector3(4.0, 0, -4.6), Vector3(4.0, 1.6, -7.29), "r_couloir_portrait", 0.6)
	var hints2: Array = []
	Game.hint_requested.connect(func(t: String, _s: float) -> void: hints2.append(t))
	var cp: Node3D = couloir.get("cam_pivot")
	var a := _aim(Vector3(4.0, 0, -3.0), cp.global_position)
	player.global_position = Vector3(4.0, 0, -3.0)
	player.set_look(a.x, a.y)
	await get_tree().create_timer(1.5).timeout
	a = _aim(player.global_position, cp.global_position)
	player.set_look(a.x, a.y)
	await get_tree().create_timer(2.5).timeout
	_check("camera_led_eteinte", couloir.get("cam_led_on") == false and hints2.has(couloir.get("TXT_CAMERA_LED")), "led %s indices %s" % [couloir.get("cam_led_on"), hints2])
	await _shot("r_camera_led_eteinte")
	player.set_look(PI, 0.0)
	await get_tree().create_timer(5.5).timeout
	_check("camera_led_rallumee", couloir.get("cam_led_on") == true, "toujours éteinte")
	print("BANC REVUE %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit()
