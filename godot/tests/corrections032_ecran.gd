extends "res://scripts/main.gd"
## Banc corrections032 (exclu de l'export) : lisibilité dans la vue du joueur, après les corrections
## de la relecture 0.3.2.
##  1. HUD : un son entre crochets (le chant du modem) et un dialogue d'une ligne (N10), puis de deux
##     lignes, puis avec une pensée du héros : le texte du son reste au-dessus de celui du dialogue.
##  2. Assis devant l'ordinateur : l'afficheur « ♥ 52 » (jauge 55, lignes 17 à 19 de la séance 2) et le
##     compte à rebours « DÉLAI 07 ».
##   XDG_DATA_HOME=… godot --path godot [--rendering-driver vulkan] res://tests/corrections032_ecran.tscn -- --shots=DIR
## Lignes « CORR032 VÉRIF <id> OK|ÉCHEC : … » ; dernière ligne « CORR032 FINI n échec(s) ».

const SEANCE2 := preload("res://scripts/seance2.gd")
const ROOM := preload("res://scripts/room.gd")

var fails := 0
var n_checks := 0
var shot_n := 0


func _ready() -> void:
	Game.seen_warning = true
	super()
	_run.call_deferred()


func ck(id: String, cond: bool, detail := "") -> void:
	n_checks += 1
	if cond:
		print("CORR032 VÉRIF %s OK" % id)
	else:
		fails += 1
		print("CORR032 VÉRIF %s ÉCHEC : %s" % [id, detail])


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func snap(n: String) -> void:
	shot_n += 1
	if Game.shots_dir == "" or DisplayServer.get_name() == "headless":
		return      # (sans rendu, frame_post_draw ne vient jamais)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(Game.shots_dir.path_join("%02d_%s.png" % [shot_n, n]))
	print("CORR032 capture %02d_%s" % [shot_n, n])


func snap_term(n: String) -> void:
	shot_n += 1
	if Game.shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := (terminal as Control).get_viewport().get_texture().get_image()
	img.save_png(Game.shots_dir.path_join("%02d_%s.png" % [shot_n, n]))
	print("CORR032 capture %02d_%s (écran du terminal)" % [shot_n, n])


## Rectangles (y haut, y bas) des textes dessinés : le dialogue en haut de sa boîte, le son en bas.
func _rects() -> String:
	var a: Rect2 = hud.sub_lbl.get_global_rect()
	var b: Rect2 = hud.snd_lbl.get_global_rect()
	return "dialogue %.0f→%.0f (texte %.0f px, %d ligne(s)) · son boîte %.0f→%.0f" % [a.position.y, a.end.y,
		hud.sub_lbl.get_content_height(), hud.sub_lbl.get_line_count(), b.position.y, b.end.y]


func _run() -> void:
	menu.hide_all()
	hud.fade.color.a = 0.0
	Game.phase = "room"
	Game.sound_captions = true
	Game.choices = {"proche": "Mamie", "prix": "personne", "reflet": "fixe"}
	player.global_position = Vector3(1.6, 0, 0.6)
	player.set_look(PI, -0.05)
	await wait(1.5)
	# 1. le son puis, 1,6 s plus tard, N10 (comme à la convocation)
	hud.sound_caption(ROOM.MODEM_CAPTION)
	await wait(1.6)
	hud.subtitle("Nestor", Acte2.N10, "elle")
	await wait(0.6)
	print("CORR032 une ligne : ", _rects())
	var o1: float = hud.caption_overlap()
	ck("son au-dessus d'un dialogue d'une ligne", o1 > -INF and o1 <= 0.0, "chevauchement %.0f px · %s" % [o1, _rects()])
	await snap("son_et_dialogue_1_ligne")
	hud.clear_subtitles()
	await wait(0.3)
	# un dialogue de deux lignes
	hud.sound_caption(ROOM.MODEM_CAPTION)
	hud.subtitle("Nestor", "Ta mère avait une sonnerie pour moi. Celle-ci. Reviens dans sa chambre. On fait le point.", "elle")
	await wait(0.6)
	print("CORR032 deux lignes : ", _rects())
	var o2: float = hud.caption_overlap()
	ck("son au-dessus d'un dialogue de deux lignes", o2 > -INF and o2 <= 0.0 and hud.sub_lbl.get_line_count() == 2, "chevauchement %.0f px · %s" % [o2, _rects()])
	await snap("son_et_dialogue_2_lignes")
	# avec une pensée du héros (le tout remonte)
	Game.hint("Le chant du modem. Ça vient de la chambre de Maman.", 6.0)
	await wait(0.8)
	print("CORR032 avec la pensée : ", _rects())
	var o3: float = hud.caption_overlap()
	ck("son au-dessus du dialogue, pensée affichée", o3 > -INF and o3 <= 0.0, "chevauchement %.0f px · %s" % [o3, _rects()])
	await snap("son_dialogue_pensee")
	hud.clear_subtitles()
	await wait(4.0)
	# 2. assis devant l'ordinateur, jauge 55 : les lignes 17 à 19, « ♥ 52 »
	terminal.set_fear(55.0)
	room.restore_after_seance()
	await player.sit(room.seat_pos, room.screen_center)
	terminal.show_static([[SEANCE2.L17, "n"], [SEANCE2.L18, "sys"], [SEANCE2.L19[0], "sys"], [SEANCE2.L19[1], "sys"]])
	terminal.mode = "seance"
	terminal.status.visible = true
	await wait(1.0)
	terminal.set_heart(52)
	await wait(2.0)
	ck("afficheur « ♥ 52 » en 40 px", terminal.heart_box.visible and terminal.heart_val.text == "52"
		and terminal.heart_val.get_theme_font_size("font_size") == 40, "")
	await snap("assis_coeur_52")
	await snap_term("ecran_coeur_52")
	# le compte à rebours (la barre aux 7/10 de sa longueur)
	terminal.hide_heart()
	terminal.timer_box.visible = true
	terminal.timer_val.text = "07"
	terminal.timer_fill.size.x = terminal.TIMER_W * 0.7
	await wait(1.5)
	var tv: Rect2 = terminal.timer_val.get_global_rect()
	ck("chiffre du délai sous x 450 du terminal", tv.end.x < 450.0, "chiffre %.0f→%.0f" % [tv.position.x, tv.end.x])
	await snap("assis_delai_07")
	await snap_term("ecran_delai_07")
	print("CORR032 FINI %d vérifications, %d échec(s)" % [n_checks, fails])
	get_tree().quit(0)
