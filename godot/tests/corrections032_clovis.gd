extends "res://scripts/main.gd"
## Banc corrections032 (exclu de l'export) : Clovis vu par la fenêtre de la chambre d'amis, après les
## caméras, juste après avoir dévissé l'antenne (là où le banc joueur_parcours échouait).
##   XDG_DATA_HOME=… godot --headless --path godot res://tests/corrections032_clovis.tscn

var at: Autotest


func _ready() -> void:
	Game.seen_warning = true
	super()
	at = Autotest.new()
	at.name = "AT"
	add_child(at)
	at.setup(self)
	_run.call_deferred()


func _state(tag: String) -> void:
	var cl: Node3D = room.outside.clovis
	var target := cl.global_position + Vector3(0, 0.5, 0)
	print("CLOVIS %s : vu %s · occupé %s · lecture %s · pièce %s · regard %s · fenêtre %s · indice « %s »" % [tag,
		Game.flag("clovis_vu", false), haunt.is_busy(), hud.is_reading(), house.current.room_id if house.current else "?",
		player.looking_at_point(target, 10.0, 16.0), acte2._sees_clovis_from_window(target), hud.hint_lbl.text])
	var eye: Vector3 = player.camera.global_position
	var hit := player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(eye, target, Builder.LAYER_WORLD, [player.get_rid()]))
	if not hit.is_empty():
		var c: Object = hit.collider
		print("  rayon : %s (%s) à %s, cible %s, distance à la cible %.2f" % [c, (c as Node).get_path() if c is Node else "", hit.position, target, (hit.position as Vector3).distance_to(target)])
	var near := false
	for w in HouseData.F1_WINDOWS:
		if str(w.room) == "amis":
			print("  fenêtre ", w, " · joueur ", player.global_position)


func _run() -> void:
	await at._jump_acte2()
	await at.until(func() -> bool: return at.has_said("nestor", Acte2.N4), 60.0)
	await at.until(func() -> bool: return not haunt.is_busy(), 30.0)
	for k in ["entree_amis", "babyphone_parle", "tele_a_neige", "cameras_vues", "entree_bureau"]:
		Game.set_flag(k, true)
	Game.add_item("tournevis", "Tournevis", "", "outil")
	var am: Node = house.rooms["amis"]
	var cl: Node3D = room.outside.clovis
	player.global_position = Vector3(-1.2, 0, 3.75)
	await at.wait(1.0)
	_state("dans la chambre d'amis")
	am.unscrew_antenna()
	await at.wait(2.0)
	at.look_from(Vector3(-2.31, 0, 4.52), cl.global_position + Vector3(0, 0.5, 0))
	for i in 2:
		await at.wait(0.5)
		_state("t+%.1f" % (0.5 * (i + 1)))
	# plus près de la vitre (le banc joueur_parcours se tenait à 0,94 m : le regard passait sous l'appui)
	player.global_position = Vector3(-2.31, 0, 4.52)
	await at.wait(0.3)
	var pos0 := player.global_position
	var walk_to := Vector3(-2.85, 0, 4.5)
	for i in 60:
		var dir := (walk_to - player.global_position)
		dir.y = 0
		if dir.length() < 0.05:
			break
		player.global_position += dir.normalized() * minf(0.03, dir.length())
		await get_tree().physics_frame
	print("  déplacement %s → %s" % [pos0, player.global_position])
	at.look_from(player.global_position, cl.global_position + Vector3(0, 0.5, 0))
	for i in 4:
		await at.wait(0.5)
		_state("près de la vitre t+%.1f" % (0.5 * (i + 1)))
	print("CLOVIS FINI")
	get_tree().quit(0)
