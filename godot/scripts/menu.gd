extends CanvasLayer
## Avertissement (premier lancement), écran-titre (« Continuer » s'il existe une sauvegarde), choix du
## héros, menu pause et écran Options à onglets (scripts/ui/options_panel.gd : Image, Son, Commandes,
## Accessibilité, Jeu), ouvert depuis le titre et depuis la pause.
## Tourne même quand le jeu est en pause. Deux styles (lot V3-INTERFACE) :
##  - net : Source Sans Pro rendue à la résolution de l'écran ; la pause floute et assombrit l'image figée du
##    jeu (shaders/ui_blur.gdshader), met aussi en pause la musique (les autres sons s'arrêtent avec l'arbre) ;
##    seuls les sons de l'interface jouent. Entrées : Reprendre, Options, Commandes, Quitter vers le titre,
##    Quitter le jeu. Navigation complète au clavier et à la manette (focus), transitions douces ;
##  - rétro : VT323 aux seules tailles nettes (multiples de 10 px : en 12 à 16 px, son « M » se lit « N »),
##    surlignage vert, voile noir : l'aspect d'avant.
## L'écran-titre garde sa composition (il sera remplacé par le prologue) : seul son style suit.

signal start_requested
signal continue_requested
signal resume_requested

const GREEN := Color(0.36, 1.0, 0.42)
const BEIGE := Color(0.8, 0.76, 0.66)
const FONT := 20          # texte et boutons (rétro)
const FONT_SMALL := 10    # pied de page (rétro)
const FONT_HEAD := 40     # titres des écrans (rétro)
const FONT_TITLE := 60    # « DON'T PLAY » (rétro)
const WIDTH := 552        # largeur de la colonne de texte (rétro)
const WIDTH_NET := 330    # largeur de la colonne de texte (net)
const WARNING_TEXT := "Ce jeu contient des éclairs, des images qui clignotent et des sursauts. Ils peuvent provoquer des malaises, voire des crises chez les personnes photosensibles. Les options « Éclairs adoucis » et « Sursauts réduits » les atténuent."
## Valeur (après AgX, avant le filtre plein écran) du logo de la mire : voir OptionsPanel.MIRE_VALUE.
const MIRE_VALUE := 0.04
const ACT_TITLES := {"I": "Lecteur A:", "II": "Essais réels"}

var root: Control
var title_box: Control
var pause_box: Control
var options_box: Control
var hero_box: Control
var warning_box: Control
var confirm_box: Control
var continue_btn: Button
var back_target := "title"
var options: OptionsPanel
var net := true
var shade: ColorRect             # voile (rétro, titre)
var blur: ColorRect              # image du jeu floutée (pause, style net)
var _blur_mat: ShaderMaterial
var _current: Control
var _built_retro := false
var _confirm_action := ""
var _sounds_paused := false
var _paused_players: Array = []
var _ui_player: AudioStreamPlayer
var _pause_info: VBoxContainer
var _tw: Tween


func _ready() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = &"Master"
	_ui_player.max_polyphony = 3
	add_child(_ui_player)
	UiStyle.sound_player = _ui_player
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_build()
	hide_all()
	Game.settings_changed.connect(_on_settings_changed)


func _boxes() -> Array:
	return [title_box, pause_box, options_box, hero_box, warning_box, confirm_box]


## Construit tous les écrans dans le style courant (au lancement, puis à chaque changement de style).
func _build() -> void:
	net = UiStyle.net()
	_built_retro = not net
	root.theme = _theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if net else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	blur = ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = load("res://shaders/ui_blur.gdshader")
	blur.material = _blur_mat
	root.add_child(blur)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.74)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if net:
		shade.color = Color(1, 1, 1, 1)
		shade.material = _gradient_mat()
	root.add_child(shade)
	title_box = _build_title()
	pause_box = _build_pause()
	options_box = _build_options()
	hero_box = _build_hero()
	warning_box = _build_warning()
	confirm_box = _build_confirm()
	for b in _boxes():
		root.add_child(b)


func _gradient_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float left_a = 0.9;\nuniform float right_a = 0.42;\nvoid fragment() {\n\tfloat k = smoothstep(0.0, 1.0, UV.x);\n\tfloat v = 1.0 - 0.25 * pow(abs(UV.y - 0.5) * 2.0, 2.0);\n\tCOLOR = vec4(0.0, 0.0, 0.0, mix(left_a, right_a, k) / max(v, 0.5));\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _on_settings_changed() -> void:
	if UiStyle.net() == (not _built_retro):
		return
	_rebuild.call_deferred()


## Change de style (« Style rétro (pixels) ») sans fermer l'écran ouvert ni perdre l'onglet des options.
func _rebuild() -> void:
	var was := ""
	for k in ["title", "pause", "options", "hero", "warning"]:
		var b: Control = get(k + "_box")
		if b and b.visible:
			was = k
	var was_visible := root.visible
	var t := options.tab if options else 0
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	_build()
	for b in _boxes():
		b.visible = false
	if not was_visible:
		root.visible = false
		return
	match was:
		"title": show_title()
		"pause": show_pause()
		"options":
			show_options(back_target)
			options.show_tab(t, false)
		"hero": show_hero()
		"warning": _show(warning_box)


func _theme() -> Theme:
	var th := Theme.new()
	var empty := StyleBoxEmpty.new()
	var no_icon := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	th.set_type_variation("OptionRow", "CheckBox")
	for s in ["checked", "unchecked", "checked_disabled", "unchecked_disabled", "radio_checked", "radio_unchecked"]:
		th.set_icon(s, "OptionRow", no_icon)
	for s in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		th.set_stylebox(s, "OptionRow", empty)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "font_outline_color"]:
		th.set_color(c, "OptionRow", Color(0, 0, 0, 0))
	th.set_constant("h_separation", "OptionRow", 0)
	if net:
		th.default_font = UiStyle.sans()
		th.default_font_size = UiStyle.BODY
		var normal := UiStyle.empty_box(10.0, 1.0)
		th.set_stylebox("normal", "Button", normal)
		th.set_stylebox("hover", "Button", normal)
		th.set_stylebox("pressed", "Button", normal)
		th.set_stylebox("focus", "Button", empty)
		th.set_stylebox("disabled", "Button", normal)
		th.set_color("font_color", "Button", Color(UiStyle.INK, 0.72))
		th.set_color("font_hover_color", "Button", UiStyle.INK)
		th.set_color("font_pressed_color", "Button", UiStyle.INK)
		th.set_color("font_focus_color", "Button", UiStyle.INK)
		th.set_color("font_hover_pressed_color", "Button", UiStyle.INK)
		th.set_font("font", "Button", UiStyle.sans())
		th.set_font_size("font_size", "Button", UiStyle.MENU)
		th.set_color("font_color", "Label", UiStyle.INK_DIM)
	else:
		th.default_font = UiStyle.pixel()
		th.default_font_size = FONT
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0, 0, 0, 0)
		normal.content_margin_left = 6
		normal.content_margin_right = 6
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = GREEN
		th.set_stylebox("normal", "Button", normal)
		th.set_stylebox("hover", "Button", hover)
		th.set_stylebox("pressed", "Button", hover)
		th.set_stylebox("focus", "Button", hover)
		th.set_color("font_color", "Button", GREEN)
		th.set_color("font_hover_color", "Button", Color.BLACK)
		th.set_color("font_pressed_color", "Button", Color.BLACK)
		th.set_color("font_focus_color", "Button", Color.BLACK)
		th.set_color("font_hover_pressed_color", "Button", Color.BLACK)
		th.set_color("font_color", "Label", BEIGE)
	th.set_font_size("font_size", "OptionRow", UiStyle.BODY if net else FONT)
	th.set_font("font", "OptionRow", UiStyle.sans() if net else UiStyle.pixel())
	return th


func _vbox(x: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(x, -164)
	v.size = Vector2(WIDTH_NET if net else WIDTH, 240)
	v.add_theme_constant_override("separation", 3 if net else 4)
	return v


## Texte d'un écran : style net, Source Sans (« role » : body, dim, head, small) ; rétro, VT323 d'avant.
func _text(t: String, c := BEIGE, size_ := FONT, wrap := true, role := "body") -> Label:
	var l := Label.new()
	l.text = t
	if net:
		match role:
			"head":
				UiStyle.apply_label(l, UiStyle.tracked(UiStyle.sans_semi(), 2), UiStyle.HEAD, UiStyle.INK, true)
			"logo":
				UiStyle.apply_label(l, UiStyle.tracked(UiStyle.sans_semi(), 6), UiStyle.LOGO, UiStyle.INK, true)
			"dim":
				UiStyle.apply_label(l, UiStyle.sans_it(), UiStyle.BODY, UiStyle.INK_DIM, true)
			"small":
				UiStyle.apply_label(l, UiStyle.sans(), UiStyle.SMALL, UiStyle.INK_FAINT, true)
			"caps":
				UiStyle.apply_label(l, UiStyle.tracked(UiStyle.sans_semi(), 2), UiStyle.TINY, UiStyle.ACCENT, false)
			_:
				UiStyle.apply_label(l, UiStyle.sans(), UiStyle.BODY + 1, Color(UiStyle.INK, 0.86), true)
		if l.label_settings and role in ["body", "dim"]:
			l.label_settings.line_spacing = 2.0
	else:
		l.add_theme_color_override("font_color", c)
		l.add_theme_font_size_override("font_size", size_)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WIDTH_NET if net else WIDTH, 0)
	return l


func _button(t: String, cb: Callable) -> Button:
	var b := MenuEntry.new(t, net)
	b.pressed.connect(func() -> void:
		UiStyle.play_ui("click")
		cb.call())
	return b


func _gap(h: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, h)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _build_title() -> Control:
	var v := _vbox(48 if net else 44)
	v.add_child(_text("DON'T PLAY", GREEN, FONT_TITLE, false, "logo"))
	if net:
		v.add_child(_gap(4))
	v.add_child(_text("Toussaint 2040. Une semaine chez tes grands-parents. Mamie t'a fait dormir dans l'ancienne chambre de ta mère. Cet après-midi, tu as réparé son vieil ordinateur et tu l'as branché sur la box. Papi t'a dit de le débrancher avant de dormir."))
	v.add_child(_text("Il est 3 h 12. L'ordinateur vient de s'allumer tout seul.", Color(0.62, 0.6, 0.54), FONT, true, "dim"))
	v.add_child(_gap(10 if net else 6))
	continue_btn = _button("Continuer", func() -> void: continue_requested.emit())
	v.add_child(continue_btn)
	v.add_child(_button("Nouvelle partie", func() -> void: _show(hero_box)))
	v.add_child(_button("Options", func() -> void: show_options("title")))
	v.add_child(_button("Quitter", func() -> void: Game.quit_game()))
	var foot := _text(_controls_footer(), Color(0.5, 0.49, 0.44), FONT_SMALL, false, "small")
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(48 if net else 44, -46 if not net else -44)
	var warn := _text("Casque recommandé. Sursauts et éclairs clignotants : voir Options.", Color(0.5, 0.49, 0.44), FONT_SMALL, false, "small")
	warn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	warn.position = Vector2(48 if net else 44, -20)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(v)
	holder.add_child(foot)
	holder.add_child(warn)
	return holder


## Rappel des commandes au bas du titre : le texte d'avant tant que les touches sont celles par défaut,
## sinon les touches choisies.
func _controls_footer() -> String:
	if Game.bindings == Controles.defaults():
		return "ZQSD/WASD marcher · souris regarder · E agir · F lampe · Tab inventaire\nMaj courir · C s'accroupir · Échap menu"
	var g := func(a: String) -> String: return Controles.glyph(a, false)
	return "%s/%s/%s/%s marcher · souris regarder · %s agir · %s lampe · %s inventaire\n%s courir · %s s'accroupir · Échap menu" % [
		g.call("move_forward"), g.call("move_left"), g.call("move_back"), g.call("move_right"), g.call("interact"),
		g.call("flashlight"), g.call("inventory"), g.call("sprint"), g.call("crouch")]


## Avertissement de photosensibilité, montré au premier lancement seulement (Game.seen_warning,
## gardé dans settings.cfg).
func _build_warning() -> Control:
	var v := _vbox(48 if net else 44)
	v.add_child(_text("AVERTISSEMENT", GREEN, FONT_HEAD, false, "head"))
	if net:
		v.add_child(_gap(2))
	v.add_child(_text(WARNING_TEXT))
	v.add_child(_gap(8 if net else 6))
	v.add_child(_button("J'ai compris", func() -> void:
		Game.seen_warning = true
		Game.save_settings()
		show_title()))
	v.add_child(_button("Options", func() -> void:
		Game.seen_warning = true
		Game.save_settings()
		show_options("title")))
	return v


func _build_hero() -> Control:
	var v := _vbox(48 if net else 44)
	v.add_child(_text("QUI ES-TU ?", GREEN, FONT_HEAD, false, "head"))
	if net:
		v.add_child(_gap(2))
	v.add_child(_text("16 ans. Geek, fan de dinosaures et de tout ce qui vient des années 90. Une semaine de vacances chez Henriette et Albert, pour la Toussaint.", Color(0.62, 0.6, 0.54), FONT, true, "dim"))
	v.add_child(_gap(8 if net else 6))
	v.add_child(_button("Alexandre", func() -> void: _pick("alexandre")))
	v.add_child(_button("Aurèlia", func() -> void: _pick("aurelia")))
	v.add_child(_button("Retour", func() -> void: show_title()))
	return v


func _pick(h: String) -> void:
	Game.hero = h
	start_requested.emit()


func _build_pause() -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _vbox(56 if net else 44)
	if net:
		v.position = Vector2(56, -96)
		v.add_child(_text("PAUSE", GREEN, FONT_HEAD, false, "caps"))
		v.add_child(_gap(6))
	else:
		v.add_child(_text("PAUSE", GREEN, FONT_HEAD, false))
	var resume := _button("Reprendre", func() -> void: resume_requested.emit())
	v.add_child(resume)
	v.add_child(_button("Options", func() -> void: show_options("pause")))
	v.add_child(_button("Commandes", func() -> void:
		show_options("pause")
		options.show_tab(2, false)))
	v.add_child(_button("Quitter vers le titre", func() -> void: _ask("titre")))
	v.add_child(_button("Quitter le jeu", func() -> void: _ask("jeu")))
	holder.add_child(v)
	if net:
		# en bas à gauche : l'acte, l'objectif en cours et l'heure de la maison
		_pause_info = VBoxContainer.new()
		_pause_info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_pause_info.position = Vector2(56, -96)
		_pause_info.add_theme_constant_override("separation", 2)
		_pause_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(_pause_info)
		var hints := KeyHints.new([["=Entrée", "Choisir", "A"], ["=Échap", "Reprendre", "B"]], UiStyle.SMALL)
		hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		hints.position = Vector2(56, -24)
		holder.add_child(hints)
	return holder


## L'acte, l'objectif et l'heure de la maison, sous les entrées du menu pause.
func _fill_pause_info() -> void:
	if _pause_info == null:
		return
	for c in _pause_info.get_children():
		c.queue_free()
	var act := "II" if bool(Game.flag("acte2", false)) else "I"
	var t := UiStyle.label("ACTE %s — %s" % [act, ACT_TITLES[act].to_upper()], UiStyle.tracked(UiStyle.sans_semi(), 2), UiStyle.TINY, UiStyle.INK_DIM, true)
	_pause_info.add_child(t)
	if Game.objective_text != "":
		_pause_info.add_child(UiStyle.label(Game.objective_text, UiStyle.sans(), UiStyle.BODY + 1, UiStyle.INK, true))
	if Game.objective_sub != "":
		_pause_info.add_child(UiStyle.label(Game.objective_sub, UiStyle.sans(), UiStyle.SMALL + 1, UiStyle.INK_DIM, true))
	if bool(Game.flag("acte2", false)):
		_pause_info.add_child(UiStyle.label(Game.house_clock(), UiStyle.mono(), UiStyle.SMALL, UiStyle.INK_FAINT, true))
	var h := _pause_info.get_combined_minimum_size().y
	_pause_info.position = Vector2(56, (root.size.y if root.size.y > 1.0 else 360.0) - 34.0 - h)


## Confirmation avant de quitter (la partie reprend au dernier point de passage).
func _build_confirm() -> Control:
	var v := _vbox(56 if net else 44)
	if net:
		v.position = Vector2(56, -60)
	v.add_child(_text("", GREEN, FONT_HEAD, false, "head"))
	v.add_child(_text("La partie reprendra au dernier point de passage enregistré.", Color(0.62, 0.6, 0.54), FONT, true, "dim"))
	v.add_child(_gap(8 if net else 6))
	v.add_child(_button("Quitter", func() -> void: _do_quit()))
	v.add_child(_button("Annuler", func() -> void: show_pause()))
	return v


func _ask(what: String) -> void:
	_confirm_action = what
	var head := confirm_box.get_child(0) as Label
	head.text = ("Quitter vers le titre ?" if what == "titre" else "Quitter le jeu ?") if net else \
		("QUITTER VERS LE TITRE ?" if what == "titre" else "QUITTER LE JEU ?")
	_show(confirm_box)


func _do_quit() -> void:
	if _confirm_action == "jeu":
		Game.quit_game()
		return
	# vers le titre : la scène est rechargée (main.gd la reconstruit et montre le titre)
	_pause_sounds(false)
	Game.save_settings()
	root.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _build_options() -> Control:
	options = OptionsPanel.new(net)
	options.back_requested.connect(_options_back)
	return options


func _options_back() -> void:
	UiStyle.play_ui("back")
	Game.save_settings()
	if back_target == "title":
		show_title()
	else:
		show_pause()


# ------------------------------------------------------------------ affichage

func hide_all() -> void:
	root.visible = false
	_pause_sounds(false)


func _show(box: Control) -> void:
	root.visible = true
	var in_game := get_tree().paused and back_target == "pause" and (box == pause_box or box == options_box or box == confirm_box)
	var game_bg := in_game or box == pause_box or box == confirm_box
	blur.visible = net and game_bg
	shade.visible = true
	if net:
		# voile : à gauche sous le texte ; l'écran Options est plus sombre partout (sa colonne d'aide est à droite)
		var la := 0.9
		var ra := 0.45
		if box == options_box:
			la = 0.72 if game_bg else 0.9
			ra = 0.72 if game_bg else 0.8
		elif game_bg:
			la = 0.62
			ra = 0.12
		shade.material.set_shader_parameter("left_a", la)
		shade.material.set_shader_parameter("right_a", ra)
	for b in _boxes():
		b.visible = b == box
	if box == pause_box:
		_fill_pause_info()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if Game.pad_active else Input.MOUSE_MODE_VISIBLE
	var was := _current
	_current = box
	if net and was != box:
		if _tw:
			_tw.kill()
		box.modulate.a = 0.0
		_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tw.tween_property(box, "modulate:a", 1.0, 0.2)
		if blur.visible and (was == null or not was.visible or not (was in [pause_box, options_box, confirm_box])):
			_blur_mat.set_shader_parameter("amount", 0.0)
			_tw.parallel().tween_method(func(x: float) -> void: _blur_mat.set_shader_parameter("amount", x), 0.0, 1.0, 0.3)
	elif not net:
		box.modulate.a = 1.0
	_focus_first.call_deferred(box)


func _focus_first(box: Control) -> void:
	if not box.is_visible_in_tree():
		return
	if box == options_box:
		options.focus_first()
		return
	var list := box.find_children("*", "Button", true, false)
	if box == confirm_box:
		list.reverse()      # (« Annuler » d'abord : quitter n'est jamais le choix par défaut)
	for b in list:
		var bt := b as Button
		if bt.is_visible_in_tree() and bt.focus_mode != Control.FOCUS_NONE:
			bt.grab_focus()
			return


## Au lancement : l'avertissement de photosensibilité la première fois, sinon l'écran-titre.
func show_start() -> void:
	back_target = "title"
	if not Game.seen_warning:
		_show(warning_box)
	else:
		show_title()


func show_title() -> void:
	back_target = "title"
	continue_btn.visible = Game.has_save()
	var foot := (title_box.get_child(1) as Label)
	foot.text = _controls_footer()
	_show(title_box)


func show_hero() -> void:
	_show(hero_box)


func show_pause() -> void:
	back_target = "pause"
	_pause_sounds(true)
	_show(pause_box)


func show_options(from: String) -> void:
	back_target = from
	options._update_quality()
	options._refresh_bindings()
	_show(options_box)


## Pause complète : l'arbre en pause arrête les sons du jeu ; la musique et ce qui tourne même en pause
## (lecteurs PROCESS_MODE_ALWAYS) sont suspendus ici, puis repris. Les sons de l'interface restent.
func _pause_sounds(on: bool) -> void:
	if on == _sounds_paused:
		return
	_sounds_paused = on
	if on:
		_paused_players.clear()
		for cls in ["AudioStreamPlayer", "AudioStreamPlayer3D", "AudioStreamPlayer2D"]:
			for n in get_tree().root.find_children("*", cls, true, false):
				if n == _ui_player or not n.can_process():
					continue
				if bool(n.get("playing")) and not bool(n.get("stream_paused")):
					n.set("stream_paused", true)
					_paused_players.append(n)
		if Game.whispers and DisplayServer.tts_is_speaking():
			DisplayServer.tts_pause()
	else:
		for n in _paused_players:
			if is_instance_valid(n):
				n.set("stream_paused", false)
		_paused_players.clear()
		if Game.whispers and DisplayServer.tts_is_paused():
			DisplayServer.tts_resume()


func _unhandled_input(event: InputEvent) -> void:
	if not root.visible:
		return
	if options.capturing():
		return
	var back := event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")
	if not back:
		return
	if options_box.visible:
		_options_back()
	elif confirm_box.visible:
		UiStyle.play_ui("back")
		show_pause()
	elif pause_box.visible and get_tree().paused:
		UiStyle.play_ui("back")
		resume_requested.emit()
	elif hero_box.visible:
		UiStyle.play_ui("back")
		show_title()
	else:
		return
	get_viewport().set_input_as_handled()
