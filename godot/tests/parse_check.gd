extends Node
## Charge tous les scripts du jeu et des appareils (erreurs de compilation) : godot --headless --path godot
## res://tests/parse_check.tscn (exclu de l'export).

func _ready() -> void:
	var bad := 0
	for dir in ["res://scripts/", "res://scripts/devices/", "res://scripts/house/", "res://scripts/house/rooms/"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var s: Script = load(dir + f)
			if s == null or not s.can_instantiate():
				print("SCRIPT KO ", dir + f)
				bad += 1
	print("ANALYSE %s" % ("OK" if bad == 0 else "ÉCHEC %d" % bad))
	# sdb.gd lance, dès son chargement (_static_init), une tâche de fond (baignoire et WC) qui a besoin que
	# le fil principal tourne pour finir : la laisser finir avant de quitter, sinon Godot se fige en
	# quittant (WorkerThreadPool attend la tâche, la tâche attend le fil principal).
	var sdb: Script = load("res://scripts/house/rooms/sdb.gd")
	var t0 := Time.get_ticks_msec()
	while sdb and int(sdb.get("_mesh_task")) >= 0 and Time.get_ticks_msec() - t0 < 30000 \
			and not WorkerThreadPool.is_task_completed(int(sdb.get("_mesh_task"))):
		await get_tree().process_frame
	if sdb and int(sdb.get("_mesh_task")) >= 0:
		sdb.call("_await_meshes")
	get_tree().quit()
