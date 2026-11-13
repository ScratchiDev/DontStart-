extends Builder
## Banc d'essai des appareils connectés (exclu de l'export) : une petite pièce, chaque appareil posé
## dedans, Haunt et le HUD ; prend des captures et vérifie quelques règles (couches de rendu, caméras
## coupées hors de leur pièce, sauvegarde).
## godot --path godot --rendering-driver vulkan res://tests/devices_test.tscn -- --shots=/chemin

const HUD_SCRIPT := preload("res://scripts/hud.gd")

var shots := ""
var cam: Camera3D
var lamp: SpotLight3D
var player: Node3D            # lu par Haunt (appareil le plus proche)
var haunt: Haunt
var hud: CanvasLayer
var bulbs: Array[SmartBulb] = []
var nestor: Nestor
var console: HouseConsole
var mirror: SmartMirror
var printer: Printer
var baby: Babyphone
var feeds: Array[FeedCam] = []
var ghost: MeshInstance3D
var statue: MeshInstance3D
var fails := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	_make_materials()
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.07, 0.075, 0.1)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_hdr_threshold = 0.9
	we.environment = e
	add_child(we)
	# une pièce 7 × 5 m, papier peint et parquet
	room_shell(Rect2(0, 0, 7, 5), 2.6)
	haunt = Haunt.new()
	haunt.name = "Haunt"
	add_child(haunt)
	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	hud.fade.color.a = 0.0
	# le « joueur » : la caméra de test et sa lampe de poche
	player = Node3D.new()
	player.name = "Joueur"
	add_child(player)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.03
	cam.set_cull_mask_value(Builder.LAYER_FEED_ONLY, false)
	player.add_child(cam)
	cam.current = true
	lamp = SpotLight3D.new()
	lamp.light_color = Color(1, 0.88, 0.7)
	lamp.light_energy = 5.0
	lamp.spot_range = 13.0
	lamp.spot_angle = 27.0
	lamp.spot_angle_attenuation = 1.7
	lamp.shadow_enabled = true
	lamp.position = Vector3(0.16, -0.16, 0.05)
	cam.add_child(lamp)
	_furnish()
	await get_tree().create_timer(0.3).timeout
	await _run()
	print("BANC APPAREILS %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit()


func _check(id: String, cond: bool, detail := "") -> void:
	if cond:
		print("VÉRIF %s OK" % id)
	else:
		fails += 1
		print("VÉRIF %s ÉCHEC : %s" % [id, detail])


func _table(pos: Vector3, size: Vector3) -> float:
	_box(size, pos + Vector3(0, size.y / 2.0, 0), mats.wood, true)
	return pos.y + size.y


func _furnish() -> void:
	# trois ampoules connectées au plafond, sous une tulipe
	for i in 3:
		var b := SmartBulb.new()
		b.device_id = "ampoule_%d" % (i + 1)
		b.room_id = "test"
		add_child(b)
		b.position = Vector3(1.2 + i * 2.3, 2.2, 2.6)
		b.build()
		var shade := StandardMaterial3D.new()
		shade.albedo_color = Color(0.55, 0.36, 0.18)
		shade.roughness = 0.35
		shade.emission_enabled = true
		shade.emission = Color(1.0, 0.6, 0.3)
		shade.emission_energy_multiplier = 0.35
		var sm := Connected.no_gi(b.add_mesh(Connected.cyl(0.03, 0.115, 0.14, 20), Vector3(0, 0.05, 0), shade))
		sm.name = "Tulipe"
		b.add_glow_material(shade)
		b.add_mesh(Connected.cyl(0.004, 0.004, 0.3, 6), Vector3(0, 0.27, 0), mats.dark)
		bulbs.append(b)
	# console du bureau sur une table, contre le mur nord
	var top := _table(Vector3(1.4, 0, 0.35), Vector3(1.2, 0.74, 0.6))
	_box(Vector3(0.56, 0.36, 0.04), Vector3(1.4, top + 0.25, 0.24), mats.black_plastic)
	_box(Vector3(0.06, 0.08, 0.06), Vector3(1.4, top + 0.04, 0.26), mats.black_plastic)
	console = HouseConsole.new()
	console.device_id = "console"
	console.room_id = "test"
	add_child(console)
	console.position = Vector3(1.4, top + 0.25, 0.262)
	console.build()
	# imprimante, Nestor, babyphone, sur des tables le long du mur nord
	top = _table(Vector3(3.3, 0, 0.3), Vector3(0.6, 0.6, 0.5))
	printer = Printer.new()
	printer.device_id = "imprimante"
	printer.room_id = "test"
	add_child(printer)
	printer.position = Vector3(3.3, top, 0.28)
	printer.build()
	top = _table(Vector3(4.6, 0, 0.3), Vector3(0.5, 0.7, 0.4))
	nestor = Nestor.new()
	nestor.device_id = "nestor"
	nestor.room_id = "test"
	add_child(nestor)
	nestor.position = Vector3(4.6, top, 0.3)
	nestor.build()
	top = _table(Vector3(5.7, 0, 0.3), Vector3(0.45, 0.55, 0.4))
	baby = Babyphone.new()
	baby.device_id = "babyphone"
	baby.room_id = "test"
	add_child(baby)
	baby.position = Vector3(5.7, top, 0.3)
	baby.build()
	# miroir connecté au mur sud, qui regarde la pièce (vers −z)
	mirror = SmartMirror.new()
	mirror.device_id = "miroir"
	mirror.room_id = "test"
	add_child(mirror)
	mirror.position = Vector3(3.5, 1.5, 4.985)
	mirror.rotation.y = PI
	mirror.build()
	mirror.feed.look_at(Vector3(3.5, 1.1, 0.0))
	_box(Vector3(0.7, 0.85, 0.2), Vector3(3.5, 0.425, 4.85), mats.paint, true)   # lavabo, pour la forme
	# trois caméras de flux pour la console (la quatrième : pas de signal)
	var spots := [[Vector3(6.8, 2.4, 4.8), Vector3(3.5, 0.6, 1.0), "CAM 1 COULOIR"],
		[Vector3(0.2, 2.4, 4.8), Vector3(3.3, 0.6, 0.3), "CAM 2 JARDIN"],
		[Vector3(6.8, 2.4, 0.2), Vector3(3.5, 1.0, 4.8), "CAM 3 CHAMBRE 1"]]
	for i in spots.size():
		var fc := FeedCam.new()
		fc.title = spots[i][2]
		add_child(fc)
		fc.position = spots[i][0]
		fc.look_at(spots[i][1])
		fc.build()
		feeds.append(fc)
		console.set_feed(i, fc)
	console.set_feed(3, null)
	# silhouette « flux uniquement » (couche 11) : le miroir la voit, pas le joueur
	var caps := CapsuleMesh.new()
	caps.radius = 0.22
	caps.height = 1.7
	ghost = MeshInstance3D.new()
	ghost.mesh = caps
	ghost.material_override = _plain(Color(0.02, 0.02, 0.025), 0.9)
	add_child(ghost)
	ghost.position = Vector3(3.5, 0.85, 2.4)
	Builder.set_vis_layers(ghost, [Builder.LAYER_FEED_ONLY])
	# « statue » cachée des caméras (couche 12) : le joueur la voit, pas les flux
	statue = _box(Vector3(0.4, 1.1, 0.4), Vector3(1.0, 0.55, 3.6), _plain(Color(0.5, 0.5, 0.48), 0.9), false)
	Builder.set_vis_layers(statue, [Builder.LAYER_HIDDEN_FROM_FEEDS])


func _shot(name: String, from: Vector3, at: Vector3, wait := 0.5) -> void:
	player.global_position = from
	cam.look_at_from_position(from, at)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	if shots != "":
		get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("capture ", name)


func _save_img(img: Image, name: String) -> void:
	if shots != "" and img and not img.is_empty():
		img.save_png(shots.path_join(name + ".png"))
		print("capture ", name, " ", img.get_size())


func _run() -> void:
	Game.autotest = true
	Game.phase = "room"
	haunt.room_changed("test")
	await _shot("a_vue_generale", Vector3(3.5, 1.6, 3.9), Vector3(3.5, 1.0, 0.0), 1.0)
	# --- ampoules
	await _shot("b_ampoule_allumee", Vector3(3.0, 1.6, 3.6), Vector3(3.5, 2.2, 2.6))
	bulbs[1].flicker(3.0)
	var lo := 9.0
	var hi := 0.0
	for i in 12:
		await get_tree().process_frame
		lo = minf(lo, bulbs[1].current_k())
		hi = maxf(hi, bulbs[1].current_k())
		if bulbs[1].current_k() < 0.05 and not FileAccess.file_exists(shots.path_join("c_ampoule_vacille.png")):
			await _shot("c_ampoule_vacille", Vector3(3.0, 1.6, 3.6), Vector3(3.5, 2.2, 2.6), 0.0)
	_check("ampoule_vacille", lo < 0.3 and hi - lo > 0.15, "k de %.2f à %.2f" % [lo, hi])
	await get_tree().create_timer(3.0).timeout
	_check("ampoule_revient", is_equal_approx(bulbs[1].current_k(), 1.0), str(bulbs[1].current_k()))
	bulbs[1].burst()
	await get_tree().create_timer(1.6).timeout
	await _shot("d_ampoule_eclatee", Vector3(3.0, 1.6, 3.9), Vector3(3.5, 0.3, 2.4))
	_check("ampoule_eclatee", bulbs[1].broken and not bulbs[1].light.visible, "light encore visible")
	# --- Nestor : l'anneau aux trois couleurs
	nestor.wake()
	for v in [[10.0, "e_nestor_vert"], [50.0, "f_nestor_ambre"], [80.0, "g_nestor_rouge"]]:
		Game.set_peur(v[0], "banc")
		if v[0] == 10.0:
			haunt.say("nestor", "Bonsoir, {name}.")
		await _shot(v[1], Vector3(4.6, 1.25, 1.1), Vector3(4.6, 0.75, 0.3), 1.3)
	_check("nestor_couleur", nestor.ring_mat.emission.is_equal_approx(Game.peur_color(80.0)), str(nestor.ring_mat.emission))
	Game.set_peur(27.0, "banc")
	# --- console : démarrage, quatre vignettes, en grand dans le HUD
	console.boot()
	await _shot("h_console_demarrage", Vector3(1.4, 1.25, 1.2), Vector3(1.4, 1.0, 0.26), 0.6)
	await get_tree().create_timer(2.5).timeout
	haunt.say("console", "Je vois toute la maison d'ici.")
	await _shot("i_console_vignettes", Vector3(1.4, 1.1, 0.75), Vector3(1.4, 1.0, 0.26), 1.2)
	_check("console_allumee", console.booted and console.ui.visible, "pas démarrée")
	var rendering := 0
	for f in feeds:
		if f.is_rendering() or f.frames > 0:
			rendering += 1
	_check("console_flux_actifs", rendering == 3, "%d flux" % rendering)
	hud.show_screen(console.screen_texture())
	await _shot("j_hud_console_en_grand", Vector3(1.4, 1.2, 0.95), Vector3(1.4, 1.0, 0.26), 0.8)
	hud.close_screen()
	haunt.say("console", "Presque toute. Dans la chambre de ta mère, il n'y a pas de caméra.")
	await get_tree().create_timer(0.3).timeout
	hud.show_screen(console.screen_texture())
	await _shot("j2_console_ligne_longue", Vector3(1.4, 1.2, 0.95), Vector3(1.4, 1.0, 0.26), 0.6)
	hud.close_screen()
	# --- miroir : éteint, allumé (texte), mode miroir (flux retourné, silhouette, barre)
	await _shot("k_miroir_eteint", Vector3(3.5, 1.6, 3.7), Vector3(3.5, 1.5, 5.0), 0.6)
	mirror.power_on()
	await mirror.show_text(["BONJOUR HENRIETTE · 03:2x · PENSEZ À VOS CACHETS".replace("03:2x", Game.house_clock())], true, 60.0)
	await _shot("l_miroir_allume_texte", Vector3(3.5, 1.6, 4.1), Vector3(3.5, 1.5, 5.0), 0.6)
	mirror.show_feed(true)
	mirror.show_text(["PROTOCOLE 4 · MIROIR · ESSAI RÉEL"])
	mirror.progress(6.0)
	await _shot("m_miroir_flux", Vector3(3.5, 1.6, 4.1), Vector3(3.5, 1.5, 5.0), 2.0)
	var mimg: Image = mirror.screen_texture().get_image()
	_save_img(mimg, "m2_dalle_miroir")
	var fimg := await mirror.feed.capture()
	_save_img(fimg, "m3_flux_miroir_brut")
	# la silhouette : visible dans le flux, invisible pour le joueur
	_check("couche11_joueur", not (cam.cull_mask & Builder.layer_bit(Builder.LAYER_FEED_ONLY)), "caméra du joueur voit la couche 11")
	_check("couche11_miroir", mirror.feed.cam.cull_mask & Builder.layer_bit(Builder.LAYER_FEED_ONLY) != 0, "miroir aveugle à la couche 11")
	_check("couche12_flux", feeds[0].cam.cull_mask & Builder.layer_bit(Builder.LAYER_HIDDEN_FROM_FEEDS) == 0, "flux voit la couche 12")
	await _shot("n_vue_reelle_sans_silhouette", Vector3(3.5, 1.6, 4.1), Vector3(3.5, 0.9, 2.4), 0.6)
	# --- imprimante : la photo prise par CAM 3, puis le plan
	var photo := await feeds[0].capture_still("CAM 1")
	_save_img(photo, "o0_photo_cam1")
	printer.print_page("photo_couloir", ImageTexture.create_from_image(photo))
	await get_tree().create_timer(1.2).timeout
	await _shot("o_imprimante_sortie", Vector3(3.3, 1.3, 1.25), Vector3(3.3, 0.65, 0.4), 0.2)
	await get_tree().create_timer(3.2).timeout
	await _shot("p_imprimante_feuille", Vector3(3.3, 1.2, 1.0), Vector3(3.3, 0.62, 0.5), 0.4)
	_check("feuille_sortie", printer.has_sheet("photo_couloir"), "pas de feuille")
	printer.take("photo_couloir")
	await _shot("q_lecture_image", Vector3(3.3, 1.3, 1.15), Vector3(3.3, 0.65, 0.45), 0.6)
	_check("photo_ramassee", Game.has_item("photo_couloir") and hud.paper_image.visible, "objet ou image absent")
	hud.close_paper()
	# --- babyphone : respiration, puis l'imitation (sous-titre beige)
	baby.breathe(true)
	await _shot("r_babyphone_respiration", Vector3(5.7, 0.95, 0.75), Vector3(5.7, 0.62, 0.3), 1.6)
	baby.say("{name} ?", "Mamie")
	await _shot("s_babyphone_voix_mamie", Vector3(5.7, 0.95, 0.75), Vector3(5.7, 0.62, 0.3), 0.8)
	# --- elle se déplace : bourdonnement, ampoules qui vacillent, sous-titre de son
	Game.sound_captions = true
	haunt.move("nestor", "miroir", 1.2)
	await _shot("t_deplacement", Vector3(1.0, 1.6, 4.2), Vector3(4.5, 1.8, 1.5), 0.5)
	await get_tree().create_timer(1.5).timeout
	# --- inventaire : outils, clés, pièces de l'arme
	Game.add_item("tournevis", "Tournevis de Papi", "Une étiquette « A. » sur le manche. Évidemment.", "outil")
	Game.add_item("cle_bureau", "Clé du bureau", "Un double. Étiquette de Mamie : BUREAU.", "cle")
	Game.add_item("seche_cheveux", "Sèche-cheveux de Mamie", "Un Calor de 1994. Le boîtier et la gâchette du croquis.", "arme")
	hud.toggle_inventory()
	await _shot("u_inventaire", Vector3(3.5, 1.6, 3.9), Vector3(3.5, 1.0, 0.0), 0.6)
	hud.toggle_inventory()
	Game.objective("Elle t'attend dans la salle de bain", "Croquis de Maman : 1/4 · Papi est à la cave")
	Game.hint("Des coups, dans le radiateur. Trois courts, trois longs, trois courts. Ça monte d'en bas.", 4.0)
	haunt.sound_caption("[Coups dans le radiateur, en bas]")
	haunt.say("nestor", "S.O.S. Ton grand-père tape sur les tuyaux, à la cave.")
	await _shot("v_objectif_sous_titres", Vector3(3.5, 1.6, 3.9), Vector3(3.5, 1.0, 0.0), 0.8)
	# --- indices de 90 s (accélérés ici) : jamais pendant une lecture
	await get_tree().create_timer(4.0).timeout
	haunt.hint_delay = 1.0
	haunt.hint_fn = func(step: String) -> Dictionary:
		return {"text": "Suis ton câble. Tu l'as posé toi-même." if step == "explorer" else "", "devices": ["nestor"]}
	var p0 := Game.peur
	haunt.step("explorer")
	await get_tree().create_timer(1.6).timeout
	_check("indice_donne", haunt.hints_given == 1 and is_equal_approx(Game.peur, p0 + 1.0), "%d indices, peur %.1f" % [haunt.hints_given, Game.peur])
	hud.read_paper("Un mot.")
	await get_tree().create_timer(2.5).timeout
	_check("pas_indice_en_lecture", haunt.hints_given == 1, "%d indices" % haunt.hints_given)
	hud.close_paper()
	haunt.step("")
	# --- caméras coupées hors de leur pièce (B16)
	haunt.room_changed("ailleurs")
	await get_tree().process_frame
	var on := 0
	for n in get_tree().get_nodes_in_group("feed_cam"):
		var f := n as FeedCam
		if f.vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			on += 1
	_check("flux_coupes", on == 0, "%d flux tournent encore" % on)
	# --- jauge, stress, cœur
	Game.peur_floor = 25.0
	Game.set_peur(20.0)
	_check("plancher", Game.peur >= 25.0, str(Game.peur))
	var absorbed := [false]
	Game.absorbed.connect(func() -> void: absorbed[0] = true)
	Game.add_peur(200.0, "banc")
	_check("absorbe", absorbed[0] and Game.peur == 100.0, str(Game.peur))
	Game.set_peur(30.0)
	Game.add_stress(0.3)
	await get_tree().create_timer(0.2).timeout
	_check("coeur_audible", Sfx.heart_db > -20.0, "%.1f dB" % Sfx.heart_db)
	_check("coeur_calme", Sfx.heart_volume(0.04) < -36.0, "%.1f dB" % Sfx.heart_volume(0.04))
	# --- sauvegarde : écrire, relire, comparer
	Game.set_flag("test_flag", 3)
	Game.choices["reflet"] = "fixe"
	var before := {"items": Game.items.duplicate(true), "flags": Game.flags.duplicate(true), "peur": Game.peur, "choices": Game.choices.duplicate(true)}
	Game.save_checkpoint("C9", Vector3(1, 2, 3), 0.5)
	Game.reset_state()
	var d := Game.load_checkpoint()
	Game.apply_checkpoint(d)
	_check("sauvegarde", d.get("checkpoint") == "C9" and (d.pos as Vector3).is_equal_approx(Vector3(1, 2, 3))
		and Game.items.size() == before.items.size() and Game.flags.get("test_flag") == 3 and is_equal_approx(Game.peur, before.peur)
		and Game.choices.get("reflet") == "fixe", str(d))
	Game.delete_save()
	# journal de Haunt
	_check("journal", haunt.count("say") >= 4 and haunt.has_logged("move"), str(haunt.journal.size()))
	print("dit : ", haunt.said())
	print("sous-titres : ", hud.subtitle_log.map(func(x: Dictionary) -> String: return x.text))
