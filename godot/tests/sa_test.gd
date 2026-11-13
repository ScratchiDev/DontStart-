extends Node3D
## Banc d'essai de la salle de bain et de la chambre d'amis (exclu de l'export) : la maison réduite de
## sa_house.gd, le vrai joueur, Haunt et le HUD ; captures, interactions, P4 réel.
## godot --path godot --rendering-driver vulkan res://tests/sa_test.tscn -- --shots=DIR [--sa=sdb,p4,amis]
## Chaque vérification imprime « VÉRIF <id> OK » ou « VÉRIF <id> ÉCHEC : … » ; fin : « BANC SDB-AMIS OK ».

const SA_HOUSE := preload("res://tests/sa_house.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")

var shots := ""
var parts := ["sdb", "p4", "amis"]
var player: CharacterBody3D       # lu par Haunt et par le miroir (current_scene.player)
var house: House                  # lu par Haunt (current_scene.house)
var haunt: Haunt
var hud: CanvasLayer
var sdb: HouseRoom
var amis: HouseRoom
var lamp: OmniLight3D
var fails := 0
var p4_steps: Array = []
var stories: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
		elif a.begins_with("--sa="):
			parts = Array(a.substr(5).split(","))
	Game.autotest = true
	Game.phase = "room"
	Game.sound_captions = true
	_environment()
	haunt = Haunt.new()
	haunt.name = "Haunt"
	haunt.add_to_group("haunt")
	add_child(haunt)
	haunt.story.connect(func(n: String, _d: Dictionary) -> void: stories.append(n))
	hud = HUD_SCRIPT.new()
	hud.name = "HUD"
	add_child(hud)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	hud.player = player
	player.looking_at.connect(hud.set_prompt)
	hud.fade.color.a = 0.0
	var t0 := Time.get_ticks_msec()
	var mother := HouseRoom.new()
	mother.setup("mere", Rect2(-3.2, -2.6, 6.4, 5.2), 0.0, 2.6, "Chambre de ta mère")
	add_child(mother)
	house = SA_HOUSE.new()
	house.name = "House"
	add_child(house)
	house.build(mother)
	print("maison (réduite) construite en %d ms" % (Time.get_ticks_msec() - t0))
	sdb = house.rooms["sdb"]
	amis = house.rooms["amis"]
	t0 = Time.get_ticks_msec()
	for id in ["sdb", "amis", "couloir"]:
		(house.rooms[id] as HouseRoom).bake_gi()
	print("VoxelGI cuit en %d ms" % (Time.get_ticks_msec() - t0))
	house.finish(player)
	lamp = OmniLight3D.new()
	lamp.light_energy = 0.0
	lamp.omni_range = 6.0
	lamp.shadow_enabled = true
	add_child(lamp)
	await get_tree().create_timer(0.5).timeout
	_zone_check(sdb, Rect2(4.8, -5.1, 0.95, 1.1), "x0")
	_zone_check(amis, Rect2(2.25, 2.9, 0.95, 1.0), "x1")
	if parts.has("sdb"):
		await _sdb()
	if parts.has("p4"):
		await _p4()
	if parts.has("amis"):
		await _amis()
	print("histoire : ", stories)
	print("BANC SDB-AMIS %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.07, 0.075, 0.1)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.028
	env.volumetric_fog_albedo = Color(0.72, 0.76, 0.85)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 14.0
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.8
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.82
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ------------------------------------------------------------------ outils

func _check(id: String, cond: bool, detail := "") -> void:
	if cond:
		print("VÉRIF %s OK" % id)
	else:
		fails += 1
		print("VÉRIF %s ÉCHEC : %s" % [id, detail])


func _aim(feet: Vector3, at: Vector3) -> void:
	player.global_position = feet
	player.velocity = Vector3.ZERO
	var eye := feet + Vector3(0, player.EYE, 0)
	var d := at - eye
	player.set_look(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	if shots != "":
		get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
	print("capture ", name)


func _save_img(img: Image, name: String) -> void:
	if shots != "" and img and not img.is_empty():
		img.save_png(shots.path_join(name + ".png"))
		print("capture ", name)


func _view(feet: Vector3, at: Vector3, name: String, wait := 0.8) -> void:
	_aim(feet, at)
	await _shot(name, wait)


## Vise, vérifie le libellé, puis utilise.
func _use(feet: Vector3, at: Vector3, expected: String, use := true) -> void:
	_aim(feet, at)
	await get_tree().create_timer(0.35).timeout
	var got: String = player.current.label if player.current else "rien"
	_check("vise " + expected, got == expected, "vise « %s »" % got)
	if use and player.current:
		player.current.use()


func _service(on: bool, at := Vector3.ZERO) -> void:
	lamp.light_energy = 1.0 if on else 0.0
	if on:
		lamp.global_position = at


## Zone de battant d'une porte (rectangle x, z) : aucun objet posé par le script de la pièce ne doit y
## entrer. Les murs, plinthes et corniches (posés par house.gd) longent le mur de la porte : on les
## ignore (côté « x0 » ou « x1 » du rectangle de la pièce).
func _zone_check(room: HouseRoom, zone: Rect2, door_side: String) -> void:
	var bad := []
	for c in room.get_children():
		var box := AABB()
		if c is Interactable:
			var cs := (c as Node3D).get_child(0) as CollisionShape3D
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			box = AABB((c as Node3D).global_position - sz / 2.0, sz)
		elif c is Decal:
			var d := c as Decal
			box = AABB(d.global_position - Vector3(0.05, 0.05, 0.05), Vector3(0.1, 0.1, 0.1))
		elif c is Node3D and not (c is StaticBody3D) and not (c is Light3D):
			box = room._aabb_of(c as Node3D, room)
			if c is MeshInstance3D:
				var wall_x: float = room.rect.position.x if door_side == "x0" else room.rect.end.x
				if absf((box.position.x if door_side == "x0" else box.end.x) - wall_x) < 0.08 or box.size.x > 2.0 or box.size.z > 2.0:
					continue   # mur, plinthe, corniche, sol, plafond
		else:
			continue
		if box.size == Vector3.ZERO:
			continue
		var r2 := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if r2.intersects(zone):
			bad.append("%s %s" % [c.name, r2])
	_check("zone_battant_" + room.room_id, bad.is_empty(), str(bad))


# ------------------------------------------------------------------ salle de bain

func _sdb() -> void:
	print("--- salle de bain")
	await _view(Vector3(5.3, 0, -4.55), Vector3(7.4, 0.9, -6.6), "sdb_01_porte")
	await _view(Vector3(7.0, 0, -6.0), Vector3(7.3, 1.25, -4.1), "sdb_02_miroir")
	await _view(Vector3(8.4, 0, -6.1), Vector3(6.5, 0.4, -6.9), "sdb_03_baignoire")
	await _view(Vector3(6.4, 0, -5.4), Vector3(8.9, 0.75, -4.55), "sdb_04_wc")
	await _view(Vector3(6.3, 0, -5.2), Vector3(4.86, 0.85, -6.5), "sdb_05_seche_serviettes")
	# le pèse-personne s'allume sur 58,0 quand on le regarde
	await _use(Vector3(5.5, 0, -5.0), Vector3(6.0, 0.02, -5.7), "Regarder le pèse-personne")
	await get_tree().create_timer(0.3).timeout
	_check("balance_allumee", sdb.call("is_scale_on"), "éteinte")
	await _shot("sdb_06_balance", 0.2)
	await _use(Vector3(5.6, 0, -6.0), Vector3(4.9, 0.9, -6.4), "Toucher le sèche-serviettes")
	await _use(Vector3(8.4, 0, -6.4), Vector3(6.8, 0.5, -6.9), "Regarder la baignoire")
	await _use(Vector3(7.0, 0, -4.9), Vector3(7.0, 1.5, -4.03), "Examiner le miroir")
	await _use(Vector3(7.6, 0, -4.95), Vector3(7.84, 0.75, -4.3), "Prendre le sèche-cheveux", false)
	await _shot("sdb_07_seche_cheveux", 0.2)
	await _view(Vector3(5.9, 0, -6.0), Vector3(4.86, 0.9, -6.4), "sdb_09_serviette")
	# vue de nuit, à la lampe de poche seulement, applique éteinte
	(sdb.get("applique") as SmartBulb).set_level(0.0)
	await _view(Vector3(5.3, 0, -4.55), Vector3(6.6, 1.0, -6.7), "sdb_08_nuit")
	(sdb.get("applique") as SmartBulb).set_level(1.0)


func _p4() -> void:
	print("--- P4 réel")
	var mirror := sdb.get("mirror") as SmartMirror
	mirror.p4_event.connect(func(s: String) -> void: p4_steps.append(s))
	Game.choices["reflet"] = "retourne"
	_aim(Vector3(7.0, 0, -4.85), Vector3(7.0, 1.5, -4.03))
	await get_tree().create_timer(0.6).timeout
	_check("piece_sdb", haunt.room_id == "sdb", haunt.room_id)
	await _use(Vector3(7.6, 0, -4.95), Vector3(7.84, 0.75, -4.3), "Prendre le sèche-cheveux")
	_check("seche_cheveux", Game.has_item("seche_cheveux") and stories.has("seche_cheveux_pris"), str(Game.items))
	_check("seche_cheveux_cache", not (sdb.get("dryer") as Node3D).visible, "visible")
	# le scénario lancerait le P4 ici
	_aim(Vector3(7.0, 0, -4.85), Vector3(7.0, 1.5, -4.03))
	var p0 := Game.peur
	var result: Array = [""]
	var runner := func() -> void: result[0] = await sdb.call("run_p4")
	runner.call()
	await get_tree().create_timer(0.9).timeout
	_check("p4_allume_vite", mirror.is_on, "miroir éteint à 0,9 s")
	_check("balance_58", sdb.call("is_scale_on"), "pèse-personne éteint au début du P4")
	Engine.time_scale = 3.0
	while not mirror.feed_shown:
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	Engine.time_scale = 0.0
	await _shot("p4_01_mode_miroir", 0.3)
	_save_img(mirror.screen_texture().get_image(), "p4_01b_dalle")
	Engine.time_scale = 3.0
	while mirror.p4_time < 8.2:
		await get_tree().process_frame
	Engine.time_scale = 0.0
	await _shot("p4_02_miroir_silhouette", 0.4)
	_save_img(mirror.screen_texture().get_image(), "p4_02b_dalle_silhouette")
	_aim(Vector3(7.0, 0, -4.85), Vector3(6.6, 0.9, -6.9))
	await _shot("p4_03_baignoire_reelle", 0.4)
	_aim(Vector3(7.0, 0, -4.85), Vector3(7.0, 1.5, -4.03))
	await get_tree().create_timer(0.2, true, false, true).timeout
	Engine.time_scale = 3.0
	while mirror.p4_issue == "":
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 0.0
	_save_img(mirror.screen_texture().get_image(), "p4_04b_dalle_fixe")
	await _shot("p4_04_fixe", 0.3)
	Engine.time_scale = 3.0
	while result[0] == "":
		await get_tree().process_frame
	var guard := 0
	while mirror.p4_running and guard < 3000:
		await get_tree().process_frame
		guard += 1
	Engine.time_scale = 1.0
	_check("p4_issue", result[0] == "fixe" and Game.choices.get("miroir_reel") == "fixe", str(result[0]))
	_check("p4_jauge", is_equal_approx(Game.peur - p0, 10.0), "%.1f" % (Game.peur - p0))
	_check("p4_rideau_rendu", ((sdb.get("curtain_real") as Node3D).get_node("Toile") as VisualInstance3D).layers == 1, "couches")
	_check("p4_rideau_flux_cache", not (sdb.get("curtain_feed") as Node3D).visible, "visible")
	print("étapes P4 : ", p4_steps)
	# restauration : applique éclatée (comme après l'issue « retourne »)
	Game.set_flag("applique_eclatee", true)
	sdb.call("restore")
	_check("restore_applique", (sdb.get("applique") as SmartBulb).broken, "pas éclatée")
	await _view(Vector3(6.3, 0, -5.6), Vector3(7.0, 1.2, -4.1), "p4_05_applique_eclatee_restauree")


# ------------------------------------------------------------------ chambre d'amis

func _amis() -> void:
	print("--- chambre d'amis")
	await _view(Vector3(2.7, 0, 3.4), Vector3(-1.5, 0.8, 4.9), "amis_01_porte")
	await _view(Vector3(-0.2, 0, 3.0), Vector3(-2.6, 1.1, 5.9), "amis_02_mannequin")
	await _view(Vector3(1.9, 0, 3.6), Vector3(0.2, 0.5, 5.6), "amis_03_lit")
	await _view(Vector3(0.9, 0, 4.2), Vector3(2.75, 0.3, 5.0), "amis_04_cartons")
	await _view(Vector3(1.3, 0, 4.4), Vector3(1.3, 0.6, 3.5), "amis_05_seau")
	var baby := amis.get("babyphone") as Babyphone
	baby.breathe(true)
	await _view(Vector3(1.6, 0, 5.0), Vector3(1.1, 0.5, 5.95), "amis_06_babyphone")
	baby.breathe(false)
	# la télé
	await _use(Vector3(-1.2, 0, 3.8), Vector3(-1.2, 0.62, 2.97), "Examiner la télé")
	await _shot("amis_07_tele", 0.3)
	amis.call("tv_snow", 3.0)
	await get_tree().create_timer(1.0).timeout
	var tv := amis.get("tv") as Device
	_check("tele_neige", float(tv._p.noise) >= 0.5, "noise %.2f" % float(tv._p.noise))
	await _shot("amis_08_tele_neige", 0.1)
	await get_tree().create_timer(2.5).timeout
	_check("tele_eteinte", not tv.is_on, "allumée")
	# l'antenne : sans tournevis, puis avec
	await _use(Vector3(-1.2, 0, 3.8), Vector3(-1.2, 1.0, 2.95), "Examiner l'antenne")
	_check("antenne_examinee", Game.flag("antenne_examinee") and stories.has("antenne_examinee"), "drapeau")
	Game.add_item("tournevis", "Tournevis de Papi", "Une étiquette « A. » sur le manche. Évidemment.", "outil")
	await _use(Vector3(-1.2, 0, 3.8), Vector3(-1.2, 1.0, 2.95), "Dévisser l'antenne")
	var wait := 0.0
	while not Game.has_item("antenne") and wait < 8.0:
		await get_tree().create_timer(0.2).timeout
		wait += 0.2
	_check("antenne", Game.has_item("antenne") and not (amis.get("antenna") as Node3D).visible and stories.has("antenne_prise"), str(Game.items))
	await _view(Vector3(-1.2, 0, 3.8), Vector3(-1.2, 0.8, 2.95), "amis_09_sans_antenne")
	# le coin couture
	await _use(Vector3(-2.15, 0, 4.25), Vector3(-2.9, 0.8, 3.88), "Ouvrir la boîte à biscuits", false)
	await _shot("amis_10_boite", 0.2)
	if player.current:
		player.current.use()
	await get_tree().create_timer(0.6).timeout
	_check("cle_bureau", Game.has_item("cle_bureau") and stories.has("cle_bureau_prise"), str(Game.items))
	await _shot("amis_11_boite_ouverte", 0.2)
	var p0 := Game.peur
	await _use(Vector3(-2.15, 0, 4.25), Vector3(-2.74, 0.78, 3.78), "Manger la madeleine")
	await get_tree().create_timer(0.3).timeout
	_check("madeleine", Game.flag("madeleine_mangee") and not (amis.get("madeleine_it") as Interactable).enabled, "drapeau")
	_check("madeleine_jauge", is_equal_approx(Game.peur, maxf(Game.peur_floor, p0 - 5.0)), "%.1f -> %.1f" % [p0, Game.peur])
	await _use(Vector3(-2.15, 0, 4.25), Vector3(-2.74, 0.78, 3.78), "rien", false)
	await _use(Vector3(1.0, 0, 4.3), Vector3(2.75, 0.3, 4.6), "Regarder le carton")
	await _use(Vector3(1.3, 0, 4.4), Vector3(1.3, 0.2, 3.6), "Regarder le seau")
	await _use(Vector3(-1.5, 0, 4.8), Vector3(-2.6, 1.1, 5.9), "Regarder le mannequin")
	# le lampadaire allumé, vue d'ensemble
	await _use(Vector3(-0.8, 0, 5.2), Vector3(-1.6, 1.0, 6.0), "Allumer le lampadaire")
	await _view(Vector3(2.7, 0, 3.4), Vector3(-1.5, 0.8, 4.9), "amis_12_lampadaire")
	await _view(Vector3(-2.2, 0, 4.6), Vector3(-1.2, 0.7, 2.95), "amis_13_vers_tele")
	await _view(Vector3(1.7, 0, 4.6), Vector3(2.55, 0.25, 4.6), "amis_14_panneau")
	await _view(Vector3(-2.2, 0, 4.1), Vector3(-2.9, 0.76, 3.75), "amis_15_boite_couvercle")
	# restauration
	amis.call("restore")
	_check("restore_amis", not (amis.get("antenna") as Node3D).visible and not (amis.get("madeleine") as Node3D).visible, "")
