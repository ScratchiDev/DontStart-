extends "res://scripts/main.gd"
## Banc de l'agent autotest032 (exclu de l'export) : Godot qui ne quitte pas après une convocation
## suivie d'un rechargement de la scène (--charger=C3, --seance2=absorbe). Sans rendu, sans --autotest
## (le menu s'affiche, le banc pilote la partie avec les raccourcis de l'autotest) :
##   XDG_DATA_HOME=… godot --headless --path godot res://tests/autotest032_sortie.tscn -- --cas=<cas>
## Cas : « conv » (convocation, rechargement, « Continuer », quitter), « conv_off » (l'ordinateur se
## tait avant le rechargement), « sans_reprise » (rechargement, quitter depuis le titre), « sans_recharge »
## (convocation, quitter), « sans_conv » (le raccourci sans convocation), « sans_ejection » (convocation,
## sans viser le bouton d'éjection), « stop_apres », « modem_apres », « tween_apres » (convocation,
## rechargement, « Continuer », puis tout, le chant du modem seul ou le clignotement seul arrêté avant
## de quitter), « son_court », « son_fini », « son_sans_filtre » (le chant du modem seul, dans les deux
## scènes : coupé par le rechargement, fini avant, sans le filtre d'atténuation), « p_conv », « p_blink »,
## « p_shape » (un morceau de room.convocation dans les deux scènes), « q_c3 », « q_voix », « q_silence »,
## « q_scene » (le drapeau et C3 seuls, ou avec N10 et N11, le silence, une scène écrite ; la scène 2
## reprend convoquée), « conv_vite » (« Continuer » puis quitter 0,3 s après), « fermer » (comme
## « conv », mais par la fermeture de la fenêtre). Dernière ligne : « SORTIE <cas> : quit() demandé » ;
## si le processus ne se termine pas ensuite, le blocage est reproduit. (Avant Game.quit_game, « conv »
## bloquait à chaque fois en rendu ; corrigé : voir game.gd, quit_game.)

const META := "autotest032_sortie_etape"
var at: Autotest
var cas := "conv"


func _ready() -> void:
	super()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cas="):
			cas = a.substr(6)
	at = Autotest.new()
	at.name = "AT"
	add_child(at)
	at.setup(self)
	_run.call_deferred()


func _run() -> void:
	# (Game.autotest reste faux : sinon, après le rechargement, main.gd lancerait le parcours principal)
	var stage := int(Engine.get_meta(META, 1))
	print("SORTIE %s : étape %d" % [cas, stage])
	if stage == 1:
		if cas == "sans_conv":
			await at._jump_convocation(45.0, true, false)
		elif cas.begins_with("q_"):
			# des morceaux d'Acte2._convocation, puis le drapeau et C3 (la scène 2 reprend convoquée)
			await at._jump_convocation(45.0, true, false)
			match cas:
				"q_voix":
					await haunt.say_lines("nestor", [Acte2.N10, Acte2.N11])
				"q_silence":
					haunt.silence(1.5)
					haunt.stress(0.5)
					await at.wait(2.0)
				"q_scene":
					haunt.begin_scene()
					await at.wait(1.0)
					haunt.end_scene()
			Game.set_flag("convocation", true)
			acte2._checkpoint("C3", Acte2.C3_POS, Acte2.C3_YAW)
			await at.wait(0.5)
		elif cas.begins_with("p_"):
			# un morceau de room.convocation, dans les deux scènes
			await at._jump_convocation(45.0, true, false)
			await _piece()
		elif cas.begins_with("son_"):
			# le chant du modem seul (sans convocation), dans les deux scènes
			await at._jump_convocation(45.0, true, false)
			_modem_seul()
			await at.wait(9.5 if cas == "son_fini" else 3.0)
		elif cas.begins_with("piece_"):
			# un seul morceau de la convocation (Acte2._convocation), puis rechargement et titre
			await at._jump_convocation(45.0, true, false)
			match cas:
				"piece_modem":
					room.convocation(true)
					await at.wait(3.0)
				"piece_modem_off":
					room.convocation(true)
					await at.wait(3.0)
					room.convocation(false)
					await at.wait(1.0)
				"piece_voix":
					await haunt.say_lines("nestor", [Acte2.N10, Acte2.N11])
				"piece_c3":
					Game.set_flag("convocation", true)
					acte2._checkpoint("C3", Acte2.C3_POS, Acte2.C3_YAW)
				"piece_silence":
					haunt.silence(1.5)
					haunt.stress(0.5)
					await at.wait(2.0)
		elif cas == "sans_ejection":
			await at._jump_convocation(45.0, true, false)
			acte2._check_convocation()
			await at.check_convocation()
		else:
			await at._jump_convocation()
			await at.check_convocation()
		print("SORTIE %s : convocation faite (%s)" % [cas, Game.load_checkpoint().get("checkpoint", "rien")])
		if cas == "sans_recharge":
			_quit()
			return
		if cas == "conv_off":
			room.convocation(false)
			await at.wait(0.5)
		Engine.set_meta(META, 2)
		get_tree().reload_current_scene()
		return
	Engine.remove_meta(META)
	hud.fade.color.a = 0.0
	menu.show_title()
	await at.wait(1.0)
	if cas != "sans_reprise" and not cas.begins_with("piece_"):
		menu.continue_btn.pressed.emit()
		if cas == "conv_vite":
			# (quitter 0,3 s après « Continuer » : la vue neuve compile encore ses pipelines)
			await at.wait(0.3)
			_quit()
			return
		await at.wait(2.5)
		print("SORTIE %s : reprise, modem %s, objectif « %s »" % [cas, room.convoking, Game.objective_text])
		if cas.begins_with("son_"):
			_modem_seul()
			await at.wait(3.0)
		if cas.begins_with("p_"):
			await _piece()
		# (après la reprise : un seul morceau de la convocation arrêté avant de quitter)
		match cas:
			"stop_apres":
				room.convocation(false)
			"modem_apres":
				var m: Node = room.get("modem")
				if m and is_instance_valid(m):
					m.call("stop")
					m.queue_free()
				var tm: Timer = room.get("_modem_timer")
				if tm:
					tm.stop()
			"tween_apres":
				var tw: Tween = room.get("_blink_tw")
				if tw:
					tw.kill()
		await at.wait(1.0)
	_quit()


## Un morceau de room.convocation(true) : tout (p_conv), le clignotement de l'écran seul (p_blink), la
## forme de collision de l'ordinateur seule (p_shape).
func _piece() -> void:
	match cas:
		"p_conv":
			room.convocation(true)
		"p_blink":
			var tw := room.create_tween().set_loops()
			tw.tween_method(Callable(room, "_screen_blink"), 1.0, 0.0, 0.45)
			tw.tween_method(Callable(room, "_screen_blink"), 0.0, 1.0, 0.45)
		"p_shape":
			room.call("_set_pc_shape", true)
	print("SORTIE %s : morceau joué" % cas)
	await at.wait(3.0)


## Le chant du modem joué comme room._modem_chant (sans rien d'autre de la convocation).
func _modem_seul() -> void:
	var p := Sfx.play_at("modem_chant", room.screen_center, -3.0, 1.0, 6.0)
	if p and cas != "son_sans_filtre":
		p.max_distance = 40.0
		p.attenuation_filter_cutoff_hz = 3500.0
	print("SORTIE %s : chant du modem" % cas)


func _quit() -> void:
	print("SORTIE %s : quit() demandé" % cas)
	if cas == "fermer":
		# la croix de la fenêtre / Alt+F4 (auto_accept_quit est faux : Game._notification quitte)
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	else:
		Game.quit_game(0)
