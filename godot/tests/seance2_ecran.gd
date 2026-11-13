extends Node
## Rendu de l'écran du terminal seul (séance 2 : l'afficheur « ♥ 52 ») : godot --path godot
## res://tests/seance2_ecran.tscn -- --shots=DIR. Exclu de l'export.

func _ready() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var T: Control = (load("res://scripts/terminal.gd") as GDScript).new()
	vp.add_child(T)
	await get_tree().process_frame
	T.mode = "seance"
	T.status.visible = true
	Game.set_peur(54.0)
	T.turbo = true
	for l in ["Ta grand-mère dort.", "Son cœur bat à 58.", "57.", "55."]:
		await T.line(l)
	T.show_heart(58)
	T.set_heart(52)
	for k in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(dir.path_join("ecran_coeur.png"))
	print("capture ecran_coeur ", img.get_size(), " cœur ", T.heart_box.get_global_rect())
	get_tree().quit()
