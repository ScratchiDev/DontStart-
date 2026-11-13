extends Node3D
## Banc « finitions » (0.3.2, exclu de l'export) : stress léger (C4), sous-titres (C5),
## avertissement (C6), chuchotements (C7), journal des temps (C9). Sans la maison : un HUD, un Haunt
## et deux appareils de test. Lancer avec un dossier user:// isolé :
##   XDG_DATA_HOME=… godot --headless --path godot res://tests/finitions_banc.tscn [-- --partie=2]
## « --partie=2 » : second lancement (C6, settings.cfg relu) ; sans argument, tout le reste.
## Chaque vérification imprime « VÉRIF <id> OK » ou « VÉRIF <id> ÉCHEC : … » ; à la fin
## « FINITIONS OK » ou « FINITIONS ÉCHEC n ».

const MENU := preload("res://scripts/menu.gd")
const HUD := preload("res://scripts/hud.gd")
const GAME := preload("res://scripts/game.gd")
const SPEED := 4.0          # temps de jeu accéléré (les mesures sont en temps de jeu)

var player: Node3D = null   # (Haunt cherche scene.player)
var hud: HUD
var haunt: Haunt
var fails := 0
var _t := 0.0               # temps de jeu


func _ready() -> void:
	var part := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--partie="):
			part = a.substr(9)
	_run.call_deferred(part)


func _process(delta: float) -> void:
	_t += delta


func check(id: String, cond: bool, detail := "") -> void:
	print("VÉRIF %s %s" % [id, "OK" if cond else "ÉCHEC : " + detail])
	if not cond:
		fails += 1


func wait(sec: float) -> void:
	var t0 := _t
	while _t - t0 < sec:
		await get_tree().process_frame


func _run(part: String) -> void:
	if part == "2":
		await _c6_second_launch()
		_finish()
		return
	await _c6_first_launch()
	hud = HUD.new()
	add_child(hud)
	haunt = Haunt.new()
	haunt.name = "Haunt"
	add_child(haunt)
	for d in [["a", Vector3(0, 1, 0)], ["b", Vector3(6, 1, 0)]]:
		var c := Connected.new()
		c.device_id = d[0]
		c.display_name = "Appareil " + str(d[0]).to_upper()
		c.can_speak = true
		add_child(c)
		c.position = d[1]
	await get_tree().process_frame
	await get_tree().process_frame
	hud.fade.color.a = 0.0
	await _c7()
	await _c5()
	Engine.time_scale = SPEED
	await _c4()
	Engine.time_scale = 1.0
	await _c9()
	_finish()


func _finish() -> void:
	print("FINITIONS %s" % ("OK" if fails == 0 else "ÉCHEC %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


# ------------------------------------------------------------------ C4 : stress léger

## Courbe du cœur après une impulsion : volume toutes les 0,5 s (temps de jeu), premier instant
## sous −20 dB, premier instant sous −36 dB.
func _curve(label: String, mult: float) -> Dictionary:
	Game.stress_decay_mult = mult
	var rows: Array = []
	var t0 := _t
	var above_20 := 0.0
	var below_36 := -1.0
	var next := 0.0
	var peak := -80.0
	while _t - t0 < 13.0:
		await get_tree().process_frame
		var age := _t - t0
		peak = maxf(peak, Sfx.heart_db) if age < 1.5 else peak
		if Sfx.heart_db > Sfx.HEART_AUDIBLE_DB:
			above_20 = age
		if below_36 < 0.0 and Sfx.heart_db < Sfx.HEART_CALM_DB:
			below_36 = age
		if age >= next:
			rows.append("%4.1f s  stress %.3f  cœur %6.1f dB" % [age, Game.stress, Sfx.heart_db])
			next += 0.5
		if below_36 >= 0.0 and age > below_36 + 1.0:
			break
	print("C4 courbe « %s » (baisse ×%.0f) :" % [label, mult])
	for r in rows:
		print("    ", r)
	print("C4 « %s » : crête %.1f dB ; audible (> −20 dB) jusqu'à %.1f s ; sous −36 dB à %.1f s" % [label, peak, above_20, below_36])
	Game.stress_decay_mult = 1.0
	return {"peak": peak, "audible": above_20, "calm": below_36}


func _c4() -> void:
	print("C4 courbe statique Sfx.heart_volume :")
	for s in [0.0, 0.01, 0.03, 0.05, 0.064, 0.1, 0.12, 0.2, 0.3, 0.35, 0.5, 0.75, 1.0]:
		print("    stress %.3f → %6.1f dB" % [s, Sfx.heart_volume(s)])
	check("C4 courbe : 0,35 audible, 0,064 au calme, 1 sous les voix",
		Sfx.heart_volume(Haunt.STRESS_PULSE_MIN) > -20.0 and Sfx.heart_volume(0.064) <= -36.0 + 0.05 and Sfx.heart_volume(1.0) <= -10.0,
		"%.1f / %.1f / %.1f" % [Sfx.heart_volume(0.35), Sfx.heart_volume(0.064), Sfx.heart_volume(1.0)])
	# temps théorique (intégration fine de la décroissance) de 1,0 à −36 dB
	for mult in [1.0, 2.0]:
		var s := 1.0
		var tt := 0.0
		while Sfx.heart_volume(s) >= -36.0 and tt < 60.0:
			s = GAME.stress_after(s, 0.001, mult)
			tt += 0.001
		print("C4 théorie : de 1,0 à −36 dB en %.2f s (baisse ×%.0f)" % [tt, mult])
		check("C4 théorie ×%.0f : maximum → calme < 12 s" % mult, tt < 12.0, "%.2f s" % tt)
	var r0 := haunt.stress_pulses.size()
	# 1. une scène écrite (begin_scene), sans rien d'autre
	Game.stress = 0.0
	await wait(0.5)
	haunt.begin_scene()
	var a := await _curve("scène écrite", 1.0)
	haunt.end_scene()
	check("C4 scène écrite : audible puis calme < 12 s", a.peak > -20.0 and a.calm > 0.0 and a.calm < 12.0, str(a))
	# 2. le stress au maximum (plusieurs sursauts d'affilée), puis le calme
	Sfx.sting(-80.0)
	haunt.stress(0.6, "applique qui éclate")
	haunt.stress(0.5, "P4 réel")
	haunt.stress(0.4, "P4 souffle")
	var b := await _curve("maximum", 1.0)
	check("C4 maximum : calme < 12 s", b.peak > -20.0 and b.calm > 0.0 and b.calm < 12.0, str(b))
	# 3. dans la chambre de ta mère (refuge, baisse ×2)
	haunt.stress(0.3, "imitation")
	var c := await _curve("refuge, une impulsion", 2.0)
	check("C4 refuge : audible puis calme", c.peak > -20.0 and c.calm > 0.0 and c.calm < 12.0, str(c))
	haunt.stress(0.6, "a")
	haunt.stress(0.6, "b")
	var c2 := await _curve("refuge, maximum", 2.0)
	check("C4 refuge maximum : calme < 12 s", c2.peak > -20.0 and c2.calm > 0.0 and c2.calm < 12.0, str(c2))
	# 4. les autres sources passent par Haunt : silence, sursaut, événements de pièce, séance
	var n := haunt.stress_pulses.size()
	haunt.silence(0.2)
	Sfx.sting(-80.0)
	haunt.story_event("camera_led_eteinte")
	haunt.story_event("tiroir_ouvert")
	haunt._on_term_event("knock")
	var whys: Array = []
	for i in range(n, haunt.stress_pulses.size()):
		whys.append(haunt.stress_pulses[i].why)
	check("C4 sources : silence, sursaut, événement, séance (pas le tiroir)",
		whys.size() == 4 and str(whys[0]).begins_with("silence") and whys[1] == "sursaut" and whys[2] == "camera_led_eteinte" and whys[3] == "séance : knock", str(whys))
	await _curve("silence + sursaut + événement + séance", 1.0)
	# la madeleine calme
	haunt.stress(0.6, "test")
	var before := Game.stress
	haunt.story_event("madeleine_mangee")
	check("C4 madeleine : le stress baisse", Game.stress < before - 0.25, "%.2f → %.2f" % [before, Game.stress])
	await wait(10.0)
	# 5. sous un dialogue, le cœur se range dessous (−18 dB au plus) mais reste audible
	haunt.stress(1.0, "test dialogue")
	haunt.say("a", "Ici, ils m'appellent Nestor. Ta grand-mère me dit merci. Je l'ai noté.")
	await wait(0.8)
	var ducked := Sfx.heart_db
	var curve_db := Sfx.heart_curve_db
	check("C4 sous un dialogue : ≤ −18 dB et > −20 dB", ducked <= Sfx.HEART_DUCK_DB + 0.01 and ducked > -20.0 and curve_db > ducked,
		"cœur %.1f dB (courbe %.1f dB)" % [ducked, curve_db])
	hud.clear_subtitles()
	await wait(0.8)
	check("C4 dialogue fini : le cœur revient à sa courbe", absf(Sfx.heart_db - Sfx.heart_curve_db) < 0.5, "%.1f / %.1f" % [Sfx.heart_db, Sfx.heart_curve_db])
	await wait(12.0)
	# 6. le résumé du suivi (ce que l'autotest lira)
	var rep := haunt.c4_report(r0)
	print("C4 suivi Haunt : ", rep)
	check("C4 suivi : toutes les impulsions audibles, calme mesuré < 12 s", rep.ok and rep.measured >= 4 and rep.calm_max < 12.0 and rep.peak_min > -20.0, str(rep))


# ------------------------------------------------------------------ C5 : sous-titres

func _c5() -> void:
	var keep := Game.sound_captions
	# option coupée : les dialogues et les pensées s'affichent, les sons non
	Game.sound_captions = false
	hud.clear_subtitles()
	# (le premier bourdonnement est sous-titré même sans l'option, § 6.4 : vérifié à part ci-dessous)
	haunt._hum_captioned = true
	var n_sub := hud.subtitle_log.size()
	haunt.say("a", "Bonsoir, {name}.")
	haunt.say("b", "{name} ?", "Mamie")
	Game.hint("Mamie dit « mon grand ». Jamais ton prénom.", 3.0)
	haunt.sound_caption("[Coups dans le radiateur, en bas]")
	haunt.move("a", "b", 0.3)
	haunt._on_term_event("knock")
	await wait(0.4)
	check("C5 sans l'option : dialogue affiché", hud.subtitle_log.size() > n_sub and hud.subtitle_log[n_sub].text == "Bonsoir, Alexandre." and hud.sub_lbl.visible,
		str(hud.subtitle_log.slice(n_sub)))
	check("C5 sans l'option : pensée affichée", hud.hint_lbl.text.begins_with("Mamie dit") and hud.hint_lbl.modulate.a > 0.5, hud.hint_lbl.text)
	check("C5 sans l'option : aucun son entre crochets", hud.caption_log.is_empty() and not hud.snd_lbl.visible and haunt.count("son", "shown", true) == 0,
		"%s · %d" % [hud.caption_log, haunt.count("son", "shown", true)])
	await wait(4.0)
	check("C5 sans l'option : la voix imitée est affichée ensuite", hud.subtitle_log.size() >= n_sub + 2 and str(hud.subtitle_log[n_sub + 1].who).contains("voix de Mamie"),
		str(hud.subtitle_log.slice(n_sub)))
	await wait(3.0)
	hud.clear_subtitles()
	# option active : les sons s'affichent entre crochets, tout de suite, au-dessus du dialogue
	Game.sound_captions = true
	haunt.say("a", "S.O.S. Ton grand-père tape sur les tuyaux, à la cave.")
	await wait(0.3)
	haunt.sound_caption("[Coups dans le radiateur, en bas]")
	await wait(0.3)
	check("C5 avec l'option : son affiché tout de suite, entre crochets", hud.snd_lbl.visible and hud.snd_lbl.text == "[Coups dans le radiateur, en bas]" and hud.sub_lbl.visible,
		"« %s » · dialogue %s" % [hud.snd_lbl.text, hud.sub_lbl.visible])
	await get_tree().process_frame
	check("C5 avec l'option : le son au-dessus du dialogue", hud.snd_lbl.offset_bottom <= hud.sub_lbl.offset_bottom - 20.0,
		"son %.0f / dialogue %.0f" % [hud.snd_lbl.offset_bottom, hud.sub_lbl.offset_bottom])
	_shot("finitions_c5_son_et_dialogue")
	haunt.sound_caption("[Coups dans le radiateur, en bas]")
	check("C5 le même son n'est pas répété", hud.caption_log.size() == 1, str(hud.caption_log))
	haunt.move("b", "a", 0.3)
	await wait(0.2)
	check("C5 bourdonnement (avec l'option)", hud.snd_lbl.text == Haunt.HUM_CAPTION, hud.snd_lbl.text)
	haunt._on_term_event("knock")
	await wait(0.1)
	check("C5 coups à la porte (séance)", hud.snd_lbl.text == Haunt.KNOCK_CAPTION, hud.snd_lbl.text)
	for t in ["[Anneaux de rideau, derrière toi]", "[Pas mouillés sur le carrelage, derrière toi]", "[Un souffle, tout près]"]:
		haunt.sound_caption(t)
		await wait(0.1)
	var texts: Array = []
	for e in hud.caption_log:
		texts.append(e.text)
	print("C5 sous-titres de sons affichés : ", texts)
	check("C5 tous entre crochets", texts.size() == 6 and texts.all(func(x: String) -> bool: return x.begins_with("[") and x.ends_with("]")), str(texts))
	await wait(7.0)
	check("C5 le son s'efface", not hud.snd_lbl.visible and hud.current_caption == "", hud.snd_lbl.text)
	hud.clear_subtitles()
	# § 6.4 : sans l'option, le premier bourdonnement d'une session s'affiche une fois, pas les suivants
	Game.sound_captions = false
	haunt._hum_captioned = false
	var n_cap := hud.caption_log.size()
	haunt.move("a", "b", 0.3)
	await wait(0.2)
	haunt.move("b", "a", 0.3)
	await wait(0.2)
	check("C5 sans l'option : premier bourdonnement sous-titré une fois (§ 6.4)",
		hud.caption_log.size() == n_cap + 1 and hud.caption_log[n_cap].text == Haunt.HUM_CAPTION,
		str(hud.caption_log.slice(n_cap)))
	await wait(7.0)
	hud.clear_subtitles()
	Game.sound_captions = keep
	# l'option est gardée dans settings.cfg (aller-retour par un Game neuf)
	for v in [true, false]:
		Game.sound_captions = v
		Game.save_settings()
		var g: Node = GAME.new()
		g._load_settings()
		check("C5 option gardée (%s)" % v, g.sound_captions == v, str(g.sound_captions))
		g.free()
	Game.sound_captions = keep
	Game.save_settings()


func _shot(name: String) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.substr(8)
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


# ------------------------------------------------------------------ C6, C7

## Premier lancement (dossier user:// vide) : l'avertissement, « J'ai compris » le note.
func _c6_first_launch() -> void:
	var cfg_exists := FileAccess.file_exists(Game.SETTINGS_PATH)
	print("C6 premier lancement : settings.cfg %s, seen_warning %s" % ["présent" if cfg_exists else "absent", Game.seen_warning])
	var menu: MENU = MENU.new()
	add_child(menu)
	menu.show_start()
	await get_tree().process_frame
	check("C6 premier lancement : l'avertissement", not cfg_exists and menu.warning_box.visible and not menu.title_box.visible,
		"cfg %s · avertissement %s · titre %s" % [cfg_exists, menu.warning_box.visible, menu.title_box.visible])
	var ok_btn: Button = null
	for b in menu.warning_box.find_children("*", "Button", true, false):
		if (b as Button).text.contains("compris"):
			ok_btn = b
	if ok_btn:
		ok_btn.pressed.emit()
	await get_tree().process_frame
	var cfg := ConfigFile.new()
	cfg.load(Game.SETTINGS_PATH)
	check("C6 « J'ai compris » : drapeau dans settings.cfg, puis le titre",
		bool(cfg.get_value("accessibilite", "avertissement_vu", false)) and menu.title_box.visible and not menu.warning_box.visible, "")
	menu.queue_free()


## Second lancement : settings.cfg relu, pas d'avertissement ; chuchotements toujours coupés.
func _c6_second_launch() -> void:
	var menu: MENU = MENU.new()
	add_child(menu)
	menu.show_start()
	await get_tree().process_frame
	check("C6 second lancement : directement le titre", Game.seen_warning and menu.title_box.visible and not menu.warning_box.visible,
		"seen_warning %s" % Game.seen_warning)
	check("C7 second lancement : chuchotements toujours coupés", not Game.whispers, str(Game.whispers))
	menu.queue_free()


func _c7() -> void:
	var g: Node = GAME.new()
	check("C7 chuchotements coupés par défaut", g.whispers == false, str(g.whispers))
	g.free()
	check("C7 option relue : coupée", Game.whispers == false, str(Game.whispers))
	var menu: MENU = MENU.new()
	add_child(menu)
	var box: CheckBox = null
	for c in menu.options_box.find_children("*", "CheckBox", true, false):
		if (c as CheckBox).text == "Chuchotements (synthèse Windows)":
			box = c
	check("C7 case « Chuchotements (synthèse Windows) » décochée", box != null and not box.button_pressed, "")
	menu.queue_free()
	# Game.whisper ne fait rien : aucune voix demandée à la synthèse
	Game.whisper("c'est toi. c'est toi.")
	haunt.say("a", "Bonsoir, {name}.")
	await get_tree().process_frame
	check("C7 Game.whisper ne fait rien (option coupée)", not DisplayServer.tts_is_speaking(), "")
	hud.clear_subtitles()


# ------------------------------------------------------------------ C9 : journal des temps

func _read_times() -> PackedStringArray:
	return FileAccess.get_file_as_string(Haunt.times_path()).strip_edges().split("\n")


func _c9() -> void:
	Game.phase = "intro"
	Game.hero = "aurelia"
	haunt.times_new_game()
	haunt.step("sortir")
	await wait(1.2)
	haunt.step("mamie")
	haunt.step("mamie")          # même étape : pas de nouvelle ligne
	await wait(2.1)
	haunt.step("explorer")
	Game.set_flag("point_passage", "C2")
	var lines := _read_times()
	print("C9 journal après une partie neuve (%s) :" % Haunt.times_path())
	for l in lines:
		print("    ", l)
	check("C9 nouvelle partie : en-tête, début, trois étapes, point de passage", lines.size() == 6 and lines[0].contains("nouvelle partie") and lines[0].contains("Aurèlia")
		and lines[2].contains("étape « sortir »") and lines[3].contains("étape « mamie »") and lines[4].contains("étape « explorer »") and lines[5].contains("point de passage C2"),
		str(lines))
	check("C9 temps depuis l'étape précédente et depuis le début", lines[3].contains("1 s depuis l'étape « sortir »") and lines[4].contains("2 s depuis l'étape « mamie »")
		and lines[4].contains("3 s depuis le début"), lines[4])
	var re := RegEx.create_from_string("^\\d\\d:\\d\\d:\\d\\d · ")
	check("C9 heure réelle en tête de ligne", re.search(lines[2]) != null and re.search(lines[4]) != null, lines[2])
	# « Continuer » : une nouvelle scène (nouveau Haunt), étape remise en place pendant le chargement
	Game.save_checkpoint("C2", Vector3.ZERO, 0.0)
	haunt.queue_free()
	await get_tree().process_frame
	haunt = Haunt.new()
	add_child(haunt)
	Game.phase = "title"
	await wait(1.1)
	haunt.step("explorer")
	Game.phase = "room"
	await wait(1.0)
	haunt.step("convocation")
	lines = _read_times()
	print("C9 journal après « Continuer » :")
	for l in lines:
		print("    ", l)
	check("C9 « Continuer » : le journal continue", lines.size() == 10 and lines[0].contains("nouvelle partie") and lines[6] == "" and lines[7].contains("reprise")
		and lines[7].contains("C2") and lines[8].contains("étape « explorer » (remise en place)") and lines[9].contains("étape « convocation »"), str(lines))
	check("C9 « Continuer » : le temps depuis le début reprend où il était", lines[7].contains("3 s depuis le début") and lines[9].contains("4 s depuis le début"), lines[9])
	# « Nouvelle partie » : remis à zéro
	haunt.queue_free()
	await get_tree().process_frame
	haunt = Haunt.new()
	add_child(haunt)
	Game.phase = "intro"
	haunt.times_new_game()
	haunt.step("sortir")
	lines = _read_times()
	check("C9 « Nouvelle partie » : remis à zéro", lines.size() == 3 and lines[0].contains("nouvelle partie") and lines[2].contains("étape « sortir »") and lines[2].contains("0 s depuis le début"), str(lines))
	# « Nouvelle partie » depuis le titre : Acte1.start pose l'étape « debut » encore pendant « title »
	# (sauvegarde effacée, drapeaux remis à zéro), puis le menu appelle times_new_game : une seule remise à zéro
	Game.delete_save()
	Game.flags = {}
	haunt.queue_free()
	await get_tree().process_frame
	haunt = Haunt.new()
	add_child(haunt)
	Game.phase = "title"
	haunt.step("debut")
	haunt.times_new_game()
	Game.phase = "intro"
	lines = _read_times()
	print("C9 journal après « Nouvelle partie » depuis le titre :")
	for l in lines:
		print("    ", l)
	check("C9 « Nouvelle partie » depuis le titre : étape « debut », pas de reprise", lines.size() == 3 and lines[0].contains("nouvelle partie")
		and lines[2].contains("étape « debut » ·") and not lines[2].contains("remise en place"), str(lines))
	print("C9 durées : ", [Haunt._duration(4.4), Haunt._duration(65.0), Haunt._duration(3725.0)])
	check("C9 durées lisibles", Haunt._duration(4.4) == "4 s" and Haunt._duration(65.0) == "1 min 05 s" and Haunt._duration(3725.0) == "1 h 02 min 05 s", "")
	Game.delete_save()
