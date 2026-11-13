extends "res://scripts/main.gd"
## Banc du relecteur « textes et règles » (exclu de l'export), n° 2 : la séquence ABSORBÉ hors séance
## (B15) montrée en grand peut-elle être fermée par E, ce qui rend la main au joueur ?
## godot --path godot --rendering-driver vulkan res://tests/relecteur_textes_banc2.tscn -- --shots=DIR

var at: Autotest


func _ready() -> void:
	super()
	Game.autotest = true
	_run.call_deferred()


func _run() -> void:
	at = Autotest.new()
	at.name = "AutotestRelecteur"
	add_child(at)
	at.setup(self)
	await at._jump_acte2()
	Game.set_peur(100.0, "banc relecteur B15")
	await at.until(func() -> bool: return hud.screen_open, 10.0)
	await at.wait(1.0)
	print("R4 : avant E · écran ouvert %s · can_move %s · can_look %s · phase %s" % [hud.screen_open, player.can_move, player.can_look, Game.phase])
	await at.shot("r4_avant_e")
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await at.wait(0.1)
	var up := InputEventAction.new()
	up.action = "interact"
	up.pressed = false
	Input.parse_input_event(up)
	await at.wait(0.5)
	print("R4 : après E · écran ouvert %s · can_move %s · can_look %s · phase %s" % [hud.screen_open, player.can_move, player.can_look, Game.phase])
	await at.shot("r4_apres_e")
	at.check("R4 séquence ABSORBÉ non fermable", hud.screen_open and not player.can_move,
		"écran ouvert %s · can_move %s · phase %s" % [hud.screen_open, player.can_move, Game.phase])
	at.finish()
