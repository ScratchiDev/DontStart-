extends Node
## Vérifie la nature du sol (bruits de pas) dans la maison construite : godot --headless --path godot
## res://tests/floor_test.tscn (exclu de l'export).

func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var house: House = main.house
	var player: Node3D = main.player
	var cases := [
		[Vector3(0.1, 0, 0.5), "tapis"], [Vector3(-2.0, 0, -2.0), "parquet"],
		[Vector3(4.0, 0, 0.0), "tapis"], [Vector3(3.4, 0, 0.0), "parquet"],
		[Vector3(6.0, 0, -5.0), "carrelage"], [Vector3(7.0, 0, 3.0), "moquette"], [Vector3(0.0, 0, 4.0), "moquette"],
	]
	var bad := 0
	for c in cases:
		var got := house.floor_kind_at(c[0])
		print("sol %s : %s (attendu %s)" % [c[0], got, c[1]])
		if got != c[1]:
			bad += 1
	player.global_position = Vector3(6.0, 0, -5.0)
	print("joueur : ", player.floor_kind(), " · fournisseur : ", player.floor_provider != null)
	if player.floor_kind() != "carrelage":
		bad += 1
	print("couche 11 vue par le joueur : ", player.camera.get_cull_mask_value(Builder.LAYER_FEED_ONLY))
	print("Haunt : ", Haunt.of(get_tree()) != null)
	print("SOL %s" % ("OK" if bad == 0 else "ÉCHEC %d" % bad))
	get_tree().quit()
