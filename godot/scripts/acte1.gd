class_name Acte1
extends Node
## Acte I : la chambre de ta mère (sorti de main.gd, inchangé). L'ouverture dans le noir, la
## disquette, l'ordinateur, la séance 1 (seance1.gd, sur le moteur du terminal), ses fins et leurs
## épilogues, puis la clé et le mot d'Albert glissés sous la porte. Quand le joueur les ramasse,
## l'acte II commence (main.acte2.begin()) et le point de passage C1 « acte2 » est écrit.
## restore() remet la chambre dans son état d'après la séance (chargement d'une sauvegarde).
##
## Nœud enfant de Main, créé par main.gd, qui lui branche les signaux de la chambre et du terminal :
## room.floppy_taken → _on_floppy_taken, room.pc_used → _on_pc_used, room.key_taken → _on_key_taken,
## terminal.event → _on_term_event, terminal.ended → _on_seance_end ; E quand waiting_stand → _stand_up.
## Étapes notées par Haunt.step (journal des temps) : debut, seance1, fin_seance1.

const SEANCE1 := preload("res://scripts/seance1.gd")
const START_POS := Vector3(2.15, 0.0, 1.85)
const START_YAW := 0.32
## Ce que l'écran affiche encore après la séance (fin de seance1._suite), rendu au chargement.
const SCREEN_AFTER := [["Ta grand-mère dort. Son cœur bat à 58.", "n"], ["Viens voir.", "dim"]]

var main: Main
var room: Node3D           # la chambre de la mère (room.gd)
var player: CharacterBody3D
var hud: CanvasLayer
var terminal: Control      # l'écran de l'ordinateur (terminal.gd)
var seance: Node
var seance_result := ""    # fin de la séance 1 : « suite », « transmission », « absorbe »
var waiting_stand := false # fin de séance : E pour se lever (main.gd route la touche)
var explore_time := 0.0
var creaks_done := 0


func setup(m: Main) -> void:
	main = m
	room = m.room
	player = m.player
	hud = m.hud
	terminal = m.terminal


## Nouvelle partie : le noir, l'ouverture, puis la main est rendue dans la chambre.
func start() -> void:
	Game.reset_state()
	_step("debut")
	Game.phase = "intro"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.fade.color.a = 1.0
	player.can_move = false
	player.can_look = false
	await _opening()
	Game.phase = "room"
	player.can_move = true
	player.can_look = true
	hud.fade_to(0.0, 2.0)
	Game.objective("Trouve la disquette")
	await get_tree().create_timer(2.2).timeout
	Game.hint("L'écran réclame une disquette. Cet après-midi, il y en avait une dans l'armoire. Tu n'avais pas osé y toucher.", 6.0)


## Dans le noir, avant de rendre la main : derrière le mur, le ronflement de Papi s'arrête net.
## Des pas dans le couloir. La clé tourne dans la serrure de la chambre. Les pas descendent.
func _opening() -> void:
	var t := func(sec: float) -> void: await get_tree().create_timer(sec, false).timeout
	var snore: Node = Sfx.loop("snore", -8.0, Vector3(-0.6, 0.7, -2.9), main)
	await t.call(5.5)
	if snore:
		snore.queue_free()
	Sfx.silence(2.0)
	await t.call(2.2)
	for i in 6:
		Sfx.play_at("footstep_wood_00%d" % (i % 5), Vector3(4.0, 0.05, -3.2 + i * 0.75), -4.0, 0.9)
		await t.call(0.62)
	var door_p: Vector3 = room.door_center()
	await t.call(0.8)
	Sfx.play_at("metalLatch", door_p, -2.0, 0.85)
	await t.call(0.45)
	Sfx.play_at("metalClick", door_p, -4.0, 0.6)
	await t.call(1.6)
	for i in 6:
		Sfx.play_at("footstep_wood_00%d" % ((i + 2) % 5), Vector3(4.3 + i * 0.45, 0.05 - i * 0.22, 1.2 - i * 0.1), -6.0 - i * 3.0, 0.85)
		await t.call(0.7)
	await t.call(1.2)


func _on_floppy_taken() -> void:
	hud.show_hand(true)
	Game.objective("Insère la disquette dans l'ordinateur")
	Game.hint("Elle est tiède. Comme si quelqu'un venait de la tenir.", 4.0)
	Game.whisper("insère-moi")


func _on_pc_used() -> void:
	_step("seance1")
	Game.phase = "seated"
	hud.set_prompt(null)
	hud.show_hand(false)
	hud.show_crosshair(false)
	Game.objective("")
	room.chair.visible = false
	room.wardrobe_close_silent()
	await player.sit(room.seat_pos, room.screen_center)
	await room.insert_floppy()
	await terminal.boot()
	seance = SEANCE1.new()
	seance.name = "Seance1"
	seance.T = terminal
	seance.player = player
	add_child(seance)
	seance.run()


## Ce que l'entité fait dans la chambre pendant la séance.
func _on_term_event(what: String) -> void:
	match what:
		"knock":
			room.door_knock()
		"handle":
			room.door_rattle()
		"wardrobe":
			room.wardrobe_creak_open()
		"silhouette":
			room.outside.set_someone(true)
		"ceiling_on":
			room.ceiling_flicker_on()
		"ceiling_burst":
			room.ceiling_burst()
		"scream":
			room.face_scare(player)
		"dawn":
			_dawn(true)
		"undawn":
			_dawn(false)
		"absorbed":
			main.retro.material.set_shader_parameter("corruption", 0.8)


## Fausse aube : le ciel pâlit derrière la fenêtre (puis tout revient).
func _dawn(on: bool) -> void:
	var env: Environment = main.env
	var tw := create_tween().set_parallel()
	tw.tween_property(env, "background_energy_multiplier", 1.6 if on else 1.0, 3.0 if on else 0.15)
	tw.tween_property(env, "ambient_light_energy", 1.4 if on else 0.5, 3.0 if on else 0.15)
	tw.tween_property(room.moon, "light_color", Color(1.0, 0.85, 0.7) if on else Color(0.55, 0.66, 0.92), 3.0 if on else 0.15)
	if not on:
		room.outside.strike()


func _on_seance_end(id: String) -> void:
	if id == "fin_v03":
		return     # (la fin de la séance 2 : Acte2 la joue)
	if id != "absorbe" or not main.acte2.active:
		_step("fin_seance1")
	seance_result = id
	if id == "suite":
		await get_tree().create_timer(1.5, false).timeout
		room.key_under_door()
		Game.hint("Quelque chose a glissé sous la porte. [E] Te lever", 9999.0)
	else:
		await get_tree().create_timer(4.0, false).timeout
		Game.hint("[E] Te lever", 9999.0)
	waiting_stand = true


func _stand_up() -> void:
	waiting_stand = false
	Game.hint("", 0.1)
	room.chair.visible = true
	player.stand(Vector3(room.seat_pos.x, 0.0, room.seat_pos.z + 0.75), 0.0)
	hud.show_crosshair(true)
	Game.phase = "room"
	match seance_result:
		"suite":
			Game.objective("Ramasse ce qu'on a glissé sous la porte")
		"transmission", "absorbe":
			await _epilogue(seance_result)
		_:
			Game.objective("")


## Épilogue d'une fin, puis retour à l'écran-titre.
func _epilogue(id: String) -> void:
	await get_tree().create_timer(1.0, false).timeout
	await hud.fade_to(1.0, 2.5)
	var text: Array = {
		"transmission": ["Le dimanche, c'est le vide-grenier de ta grand-mère.", "Dans le carton marqué « TOUT À 2 € », il y a une disquette.", "Un enfant l'achète. Il ne veut pas qu'on lui rende la monnaie."],
		"absorbe": ["Au matin, ta grand-mère frappe à la porte.", "« Bien dormi, mon grand ? »".replace("mon grand", Game.g("mon grand", "ma grande")), "« Oui. »", "Ce n'est plus toi qui réponds."],
	}.get(id, [])
	await hud.card(text, 7.0)
	get_tree().reload_current_scene()


## La clé et le mot d'Albert sont ramassés : l'acte II commence (objectif O1, plancher de la jauge à
## 25), puis le point de passage C1 « acte2 » est écrit.
func _on_key_taken() -> void:
	Game.set_flag("acte1_fini", true)
	main.acte2.begin()
	main.checkpoint("C1")


## Chargement d'une sauvegarde de l'acte II : la chambre comme après la séance (armoire ouverte,
## disquette dans le lecteur, plafonnier éclaté, écran figé sur ses derniers mots), la clé prise, le
## carnet ramassé s'il est dans l'inventaire, la porte P1 déverrouillée et ouverte.
func restore() -> void:
	if not bool(Game.flag("acte1_fini", false)):
		return
	seance_result = str(Game.choices.get("fin_seance1", "suite"))
	waiting_stand = false
	room.restore_after_seance()
	terminal.show_static(SCREEN_AFTER)
	if Game.has_item("journal_manon"):
		_hide_journal()
	var p1: Door = room.door_node
	p1.unlock()
	p1.set_open_now(true)
	hud.show_hand(false)
	hud.show_crosshair(true)
	Sfx.music("music_house", -14.0, 2.0)


## Le carnet de Manon, déjà ramassé : son interaction (« Ramasser le carnet », decor.gd) et le carnet
## posé à côté disparaissent.
func _hide_journal() -> void:
	var decor: Node = room.decor
	if decor == null:
		return
	for n in decor.find_children("*", "Interactable", true, false):
		var it := n as Interactable
		if it == null or it.label != "Ramasser le carnet":
			continue
		it.enabled = false
		for c in decor.get_children():
			var n3 := c as Node3D
			if n3 and not n3 is Interactable and n3.get_child_count() > 0 \
					and Vector2(n3.position.x, n3.position.z).distance_to(Vector2(it.position.x, it.position.z)) < 0.2:
				n3.visible = false


## Étape du déroulé (Haunt.step : journal des temps, compteur des indices).
func _step(id: String) -> void:
	if main and main.haunt:
		main.haunt.step(id)


func _process(delta: float) -> void:
	if Game.phase != "room" or get_tree().paused:
		return
	# de temps en temps, un craquement de plancher derrière le joueur
	explore_time += delta
	if explore_time > 22.0 + creaks_done * 17.0 and creaks_done < 4:
		creaks_done += 1
		var behind := player.global_transform.basis.z * 2.2
		Sfx.play_at("creak", player.global_position + behind + Vector3(0, 0.2, 0), -4.0, randf_range(0.65, 0.9))
