extends "res://tests/sa_test.gd"
## Relecture de la salle de bain et de la chambre d'amis (exclu de l'export) : analyse géométrique de
## tout ce que posent sdb.gd et amis.gd (hors de la pièce, sous le sol, dans une zone de battant, en
## l'air), puis des gros plans. godot --path godot --rendering-driver vulkan res://tests/rv_sa.tscn --
## --shots=DIR [--rv=geo,vues]

const RV_HOUSE := preload("res://tests/rv_sa_house.gd")

var rv_parts := ["geo", "vues"]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--rv="):
			rv_parts = Array(a.substr(5).split(","))
	Game.autotest = false
	Game.phase = "room"
	_environment()
	haunt = Haunt.new()
	haunt.name = "Haunt"
	haunt.add_to_group("haunt")
	add_child(haunt)
	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	hud.player = player
	player.looking_at.connect(hud.set_prompt)
	hud.fade.color.a = 0.0
	var mother := HouseRoom.new()
	mother.setup("mere", Rect2(-3.2, -2.6, 6.4, 5.2), 0.0, 2.6, "Chambre de ta mère")
	add_child(mother)
	house = RV_HOUSE.new()
	house.name = "House"
	add_child(house)
	house.build(mother)
	sdb = house.rooms["sdb"]
	amis = house.rooms["amis"]
	for id in ["sdb", "amis", "couloir"]:
		(house.rooms[id] as HouseRoom).bake_gi()
	print("VoxelGI cuit")
	house.finish(player)
	lamp = OmniLight3D.new()
	lamp.light_energy = 0.0
	lamp.omni_range = 6.0
	lamp.shadow_enabled = true
	add_child(lamp)
	await get_tree().create_timer(0.5).timeout
	if rv_parts.has("geo"):
		_geo(sdb, [Rect2(4.8, -5.1, 0.95, 1.1)])
		_geo(amis, [Rect2(2.25, 2.9, 0.95, 1.0)])
	if rv_parts.has("vues") or rv_parts.has("amis"):
		await _vues()
	print("RELECTURE FIN, %d anomalies" % fails)
	get_tree().quit()


## Tout ce que la pièce a posé elle-même (après ses murs) : boîte englobante monde.
func _geo(room: HouseRoom, zones: Array) -> void:
	var pre: int = room.get_meta("pre", 0)
	var r := room.rect
	print("--- géométrie ", room.room_id, " (", room.get_child_count() - pre, " nœuds posés)")
	for i in range(pre, room.get_child_count()):
		var c := room.get_child(i)
		if not (c is Node3D) or c is Light3D or c is VoxelGI:
			continue
		var n := c as Node3D
		var box := AABB()
		if n is Interactable or n is StaticBody3D:
			var cs := n.get_child(0) as CollisionShape3D
			if cs == null or not (cs.shape is BoxShape3D):
				continue
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			box = AABB(n.global_position - sz / 2.0, sz)
		elif n is Decal:
			continue
		else:
			box = room._aabb_of(n, room)
		if box.size == Vector3.ZERO:
			continue
		var tag := ""
		if box.position.x < r.position.x - 0.012 or box.end.x > r.end.x + 0.012 \
				or box.position.z < r.position.y - 0.012 or box.end.z > r.end.y + 0.012:
			tag += " HORS-PIECE"
		if box.position.y < -0.01:
			tag += " SOUS-SOL"
		if box.end.y > 2.61:
			tag += " DANS-PLAFOND"
		for z in zones:
			if Rect2(box.position.x, box.position.z, box.size.x, box.size.z).intersects(z) and not (n is Interactable and not (n as Interactable).enabled):
				tag += " BATTANT"
		if tag != "" or n.get_child_count() > 0 or not (n is MeshInstance3D):
			print("%-24s %-14s x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f%s" % [n.name.substr(0, 24), n.get_class().substr(0, 14),
				box.position.x, box.end.x, box.position.y, box.end.y, box.position.z, box.end.z, tag])
		if tag.contains("BATTANT"):
			fails += 1


func _vues() -> void:
	# la grande armoire de la chambre d'amis (décor ajouté), de face et de côté
	_service(true, Vector3(1.0, 2.2, 4.2))
	await _view(Vector3(0.75, 0, 4.6), Vector3(0.75, 1.0, 3.0), "rv_amis_armoire_face")
	await _view(Vector3(2.4, 0, 3.6), Vector3(0.75, 1.0, 3.0), "rv_amis_armoire_cote")
	# le passage entre l'armoire, le seau et le lit, vu de la porte
	await _view(Vector3(2.8, 0, 3.4), Vector3(0.0, 0.4, 3.6), "rv_amis_passage")
	# la bâche sur le lit, de près, éclairée
	_service(true, Vector3(0.0, 2.2, 4.0))
	await _view(Vector3(1.2, 0, 3.9), Vector3(0.0, 0.5, 5.0), "rv_amis_bache")
	# la tête de lit, la tête de la bâche, le crucifix
	await _view(Vector3(0.0, 0, 4.0), Vector3(0.0, 1.0, 6.25), "rv_amis_tete_lit")
	# le chromo, l'antenne, la télé de face, éclairés
	_service(true, Vector3(-1.2, 2.2, 4.2))
	await _view(Vector3(-1.2, 0, 4.4), Vector3(-1.2, 0.95, 2.9), "rv_amis_tele_face")
	# le coin couture vu de la chaise
	_service(true, Vector3(-2.2, 2.2, 3.6))
	await _view(Vector3(-1.9, 0, 3.45), Vector3(-2.9, 0.8, 3.45), "rv_amis_couture")
	# mannequin
	_service(true, Vector3(-1.8, 2.2, 5.2))
	await _view(Vector3(-1.4, 0, 4.9), Vector3(-2.6, 1.1, 5.9), "rv_amis_mannequin")
	# l'arrière de la télé : fil plat et vis de l'antenne
	_service(true, Vector3(-0.6, 2.2, 3.4))
	await _view(Vector3(-0.55, 0, 3.15), Vector3(-1.05, 0.75, 2.76), "rv_amis_tele_dos")
	await _view(Vector3(0.0, 0, 4.8), Vector3(0.0, 1.5, 6.28), "rv_amis_crucifix")
	if not rv_parts.has("vues"):
		_service(false)
		return
	# salle de bain : applique, câble du miroir, tirette, éclairées
	_service(true, Vector3(6.8, 2.2, -5.5))
	await _view(Vector3(6.2, 0, -5.6), Vector3(6.8, 2.0, -4.1), "rv_sdb_applique_cable")
	await _view(Vector3(7.6, 0, -5.4), Vector3(8.6, 1.2, -4.3), "rv_sdb_wc_tirette")
	await _view(Vector3(7.8, 0, -5.6), Vector3(6.6, 0.5, -7.0), "rv_sdb_baignoire_eau")
	await _view(Vector3(5.6, 0, -5.4), Vector3(4.86, 0.7, -6.4), "rv_sdb_seche_serviettes")
	await _view(Vector3(5.3, 0, -4.6), Vector3(5.5, 1.2, -7.0), "rv_sdb_panier_coin")
	_service(false)
