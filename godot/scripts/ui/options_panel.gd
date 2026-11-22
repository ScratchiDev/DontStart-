class_name OptionsPanel
extends Control
## Écran Options à onglets (lot V3-INTERFACE) : Image, Son, Commandes, Accessibilité, Jeu. Ouvert depuis
## l'écran-titre et depuis le menu pause (menu.gd). À gauche les réglages (OptionRow : une ligne focalisable,
## ← → pour régler), à droite l'aide de la ligne choisie (et la mire de la luminosité), en bas les touches.
## Onglets : clic, LB / RB à la manette, Q / E ou Page ↑ / Page ↓ au clavier. Échap (B) : retour.
## Remappage (onglet Commandes) : Entrée ou clic sur une ligne, puis la nouvelle touche ; Retour arrière
## efface ; Échap annule ; une touche déjà prise est échangée avec l'autre action. Enregistré au retour
## (Game.save_settings), appliqué tout de suite (InputMap).
## Les libellés d'avant n'ont pas changé : « Qualité : ‹ … › », « Luminosité », « Champ de vision : … »,
## « Mouvements de la caméra : … », « Style rétro (pixels) », « Plein écran », « Sous-titres des sons »,
## « Chuchotements (synthèse Windows) » (C7 retrouve cette case par son texte).

signal back_requested

const TABS := ["Image", "Son", "Commandes", "Accessibilité", "Jeu"]
## Valeur (après AgX, avant le filtre plein écran) du logo de la mire : à la luminosité par défaut,
## il sort à environ 8/255, « à peine visible » sur un écran bien réglé.
const MIRE_VALUE := 0.04
const MOUSE_DEFAULT := 0.0022

var net := true
var tab := 0
var tab_btns: Array[Button] = []
var pages: Array[VBoxContainer] = []
var scroll: ScrollContainer
var help_title: Label
var help_text: Label
var help_extra: Control
var notice: Label
var mire_logo: Label
var quality_row: OptionRow
var bind_rows := {}            # action -> OptionRow
var _capture: OptionRow = null
var _capture_ms := 0
var _focused: OptionRow = null
var _row_w := 350.0
var _value_w := 140.0
var _row_h := 17.0


func _init(is_net := true) -> void:
	net = is_net
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	show_tab(0, false)


# ------------------------------------------------------------------ construction

func _build() -> void:
	var lx := 40.0 if net else 24.0
	_row_w = 350.0 if net else 404.0
	_value_w = 184.0 if net else 170.0
	_row_h = 17.0 if net else 22.0
	var top := 22.0 if net else 8.0
	var head: Label
	if net:
		head = UiStyle.label("Options", UiStyle.sans_semi(), UiStyle.HEAD, UiStyle.INK, true)
	else:
		head = Label.new()
		head.text = "OPTIONS"
		head.add_theme_color_override("font_color", UiStyle.GREEN)
		head.add_theme_font_size_override("font_size", 40)
	head.position = Vector2(lx, top)
	add_child(head)
	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16 if net else 14)
	tabs.position = Vector2(lx, top + (26.0 if net else 42.0))
	add_child(tabs)
	if net:
		tabs.add_child(_tab_key("=Q", "LB"))
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i].to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		if net:
			b.add_theme_font_override("font", UiStyle.tracked(UiStyle.sans_semi(), 2))
			b.add_theme_font_size_override("font_size", UiStyle.SMALL)
		else:
			b.add_theme_font_size_override("font_size", 20)
		var idx := i
		b.pressed.connect(func() -> void: show_tab(idx))
		b.draw.connect(func() -> void:
			if idx == tab:
				if net:
					b.draw_rect(Rect2(0, b.size.y - 1.5, b.size.x, 1.5), UiStyle.ACCENT)
				else:
					b.draw_rect(Rect2(0, b.size.y - 2.0, b.size.x, 2.0), UiStyle.GREEN))
		tabs.add_child(b)
		tab_btns.append(b)
	if net:
		tabs.add_child(_tab_key("=E", "RB"))
	var y0 := top + (50.0 if net else 70.0)
	if net:
		var line := ColorRect.new()
		line.color = UiStyle.LINE
		line.position = Vector2(lx, y0 - 6.0)
		line.size = Vector2(560, 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
	# réglages (une page par onglet), dans un défilement qui suit le focus
	scroll = ScrollContainer.new()
	scroll.position = Vector2(lx - 2.0, y0)
	scroll.size = Vector2(_row_w + 6.0, (360.0 - y0 - 36.0) if net else (360.0 - y0 - 26.0))
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(_row_w, 0)
	scroll.add_child(holder)
	for builder in [_page_image, _page_son, _page_commandes, _page_access, _page_jeu]:
		var p := VBoxContainer.new()
		p.add_theme_constant_override("separation", 1 if net else 0)
		holder.add_child(p)
		pages.append(p)
		builder.call(p)
	# aide de la ligne choisie
	var hx := lx + _row_w + (26.0 if net else 14.0)
	var hw := 600.0 - hx if net else 628.0 - hx
	var help := VBoxContainer.new()
	help.position = Vector2(hx, y0 + 2.0)
	help.custom_minimum_size = Vector2(hw, 0)
	help.add_theme_constant_override("separation", 5 if net else 2)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help)
	if net:
		help_title = UiStyle.label("", UiStyle.sans_semi(), UiStyle.BODY, UiStyle.INK, true)
		help_text = UiStyle.label("", UiStyle.sans(), UiStyle.SMALL + 1, UiStyle.INK_DIM, true)
		help_text.label_settings.line_spacing = 1.5
	else:
		help_title = _px_label("", UiStyle.GREEN, 20)
		help_text = _px_label("", UiStyle.BEIGE, 10)
	help_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_title.custom_minimum_size = Vector2(hw, 0)
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.custom_minimum_size = Vector2(hw, 0)
	help.add_child(help_title)
	help.add_child(help_text)
	help_extra = _build_mire(hw)
	help.add_child(help_extra)
	if net:
		notice = UiStyle.label("", UiStyle.sans_it(), UiStyle.SMALL + 1, UiStyle.WARN, true)
	else:
		notice = _px_label("", Color(1.0, 0.7, 0.3), 10)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size = Vector2(hw, 0)
	help.add_child(notice)
	# touches en bas
	if net:
		var hints := KeyHints.new([["=Échap", "Retour", "B"], ["=Entrée", "Choisir", "A"], ["=← →", "Régler", "Croix ← →"]], UiStyle.SMALL)
		hints.position = Vector2(lx, 360.0 - 24.0)
		add_child(hints)
		var line2 := ColorRect.new()
		line2.color = UiStyle.LINE
		line2.position = Vector2(lx, 360.0 - 31.0)
		line2.size = Vector2(560, 1)
		line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line2)
	else:
		var back := MenuEntry.new("Retour", false)
		back.position = Vector2(lx, 360.0 - 26.0)
		back.pressed.connect(func() -> void: back_requested.emit())
		add_child(back)
	_update_quality()
	_update_mire()
	_refresh_bindings()


func _tab_key(k: String, pad: String) -> KeyHints:
	var h := KeyHints.new([[k, "", pad]], UiStyle.TINY)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return h


func _px_label(t: String, c: Color, fs: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", c)
	l.add_theme_font_size_override("font_size", fs)
	if fs <= 10:
		l.add_theme_font_override("font", Connected.no_liga(Game.fonts.pixel_small))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _row() -> OptionRow:
	var r := OptionRow.new()
	r.net = net
	r.custom_minimum_size = Vector2(_row_w, _row_h)
	r.value_w = _value_w
	r.focused_row.connect(_on_row_focus)
	return r


func _section(p: VBoxContainer, t: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6 if net else 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(gap)
	var l: Label
	if net:
		l = UiStyle.label(t.to_upper(), UiStyle.tracked(UiStyle.sans_semi(), 2), UiStyle.TINY, UiStyle.ACCENT_DIM, false)
	else:
		l = _px_label(t.to_upper(), Color(0.5, 0.49, 0.44), 10)
	p.add_child(l)


## En-tête des colonnes de touches (« Touche », « Autre », « Manette »), alignées sur les emplacements.
func _binding_header() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(_row_w, 9 if net else 12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var f: Font = UiStyle.tracked(UiStyle.sans_semi(), 1) if net else Connected.no_liga(Game.fonts.pixel_small)
		var fs := UiStyle.TINY if net else 10
		var col := UiStyle.INK_FAINT if net else Color(0.5, 0.49, 0.44)
		var vx := _row_w - _value_w
		var w := (_value_w - 52.0) / 2.0
		var y := 7.0 if net else 10.0
		c.draw_string(f, Vector2(vx, y), "TOUCHE", HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
		c.draw_string(f, Vector2(vx + w + 4.0, y), "AUTRE", HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
		c.draw_string(f, Vector2(vx + 2.0 * w + 8.0, y), "MANETTE", HORIZONTAL_ALIGNMENT_RIGHT, _row_w - (vx + 2.0 * w + 8.0) - 4.0, fs, col))
	return c


func _toggle(p: VBoxContainer, name_: String, on: bool, help_: String, cb: Callable) -> OptionRow:
	var r := _row().setup_toggle(name_, on, help_)
	r.value_changed.connect(func(v: Variant) -> void: cb.call(bool(v)))
	p.add_child(r)
	return r


func _choice(p: VBoxContainer, name_: String, ch: Array, idx: int, help_: String, cb: Callable) -> OptionRow:
	var r := _row().setup_choice(name_, ch, idx, help_)
	r.value_changed.connect(func(v: Variant) -> void: cb.call(int(v)))
	p.add_child(r)
	return r


func _slider(p: VBoxContainer, name_: String, lo: float, hi: float, v: float, step_: float, fmt: Callable, help_: String, cb: Callable) -> OptionRow:
	var r := _row().setup_slider(name_, lo, hi, v, step_, fmt, help_)
	r.value_changed.connect(func(x: Variant) -> void: cb.call(float(x)))
	p.add_child(r)
	return r


static func _pct(x: float) -> String:
	return "%d %%" % roundi(x * 100.0)


# ------------------------------------------------------------------ pages

func _page_image(p: VBoxContainer) -> void:
	quality_row = _choice(p, "Qualité", Qualite.NOMS, Game.quality, "", func(q: int) -> void:
		Game.set_quality(q)
		_update_quality())
	_slider(p, "Luminosité", 0.0, 1.0, Game.luminosite, 0.01, _pct,
		"Règle jusqu'à ce que le logo, sur le noir, soit à peine visible.", func(x: float) -> void:
			Game.luminosite = x
			_update_mire()
			Game.apply_settings())
	var fov_fmt := func(x: float) -> String:
		return "%d° (%d° horiz.)" % [roundi(x), roundi(rad_to_deg(2.0 * atan(tan(deg_to_rad(x) / 2.0) * 16.0 / 9.0)))]
	var fov_set := func(x: float) -> void:
		Game.fov = x
		Game.apply_settings()
	_slider(p, "Champ de vision", Game.FOV_MIN, Game.FOV_MAX, Game.fov, 1.0, fov_fmt,
		"Angle de vue vertical (en 16:9). Plus large, on voit davantage, mais les pièces paraissent plus grandes.", fov_set)
	_toggle(p, "Plein écran", Game.fullscreen, "Le jeu occupe tout l'écran.", func(on: bool) -> void:
		Game.fullscreen = on
		Game.apply_settings())
	_toggle(p, "Style rétro (pixels)", Game.style_retro,
		"L'aspect des premières versions : image en 640 × 360, palette réduite, tramage, police pixel.", func(on: bool) -> void:
			Game.style_retro = on
			Game.apply_settings())
	_toggle(p, "Mains visibles", Game.mains_visibles,
		"Les mains du personnage et sa lampe de poche à l'écran. Sinon, la lampe éclaire depuis l'épaule.", func(on: bool) -> void:
			Game.mains_visibles = on
			Game.apply_settings())
	_toggle(p, "Aberration chromatique", Game.aberration,
		"Les couleurs qui se séparent au bord de l'image, et davantage quand la peur monte.", func(on: bool) -> void:
			Game.aberration = on
			Game.apply_settings())


func _page_son(p: VBoxContainer) -> void:
	_slider(p, "Volume général", 0.0, 1.0, Game.master_volume, 0.01, _pct, "Le volume de tout le jeu.", func(x: float) -> void:
		Game.master_volume = x
		Game.apply_settings())
	_slider(p, "Musique et ambiance", 0.0, 1.0, Game.vol_ambiance, 0.01, _pct,
		"La pluie, le souffle de la maison, la musique.", func(x: float) -> void:
			Game.vol_ambiance = x
			Game.apply_ui_settings())
	_slider(p, "Voix", 0.0, 1.0, Game.vol_voix, 0.01, _pct, "Les voix, et les bips et le bourdonnement de l'entité.", func(x: float) -> void:
		Game.vol_voix = x
		Game.apply_ui_settings())
	_choice(p, "Respiration du personnage", ["Oui", "Discrète", "Non"], Game.respiration,
		"La respiration du personnage, qui suit sa peur. « Discrète » : 6 dB plus bas.", func(i: int) -> void:
			Game.respiration = i
			Game.apply_ui_settings())
	_toggle(p, "Chuchotements (synthèse Windows)", Game.whispers,
		"Quelques phrases de l'entité chuchotées par la synthèse vocale de Windows (une voix française doit être installée).",
		func(on: bool) -> void:
			Game.whispers = on
			Game.apply_settings())


func _page_commandes(p: VBoxContainer) -> void:
	var ms_fmt := func(x: float) -> String:
		return _pct(x / MOUSE_DEFAULT)
	var ms_set := func(x: float) -> void:
		Game.mouse_sensitivity = x
	_slider(p, "Sensibilité de la souris", 0.0006, 0.006, Game.mouse_sensitivity, 0.0001, ms_fmt, "Vitesse du regard à la souris.", ms_set)
	_section(p, "Manette")
	_slider(p, "Sensibilité du stick droit", 0.3, 2.5, Game.pad_sensitivity, 0.05, _pct,
		"Vitesse du regard au stick droit.", func(x: float) -> void:
			Game.pad_sensitivity = x)
	_toggle(p, "Inverser l'axe vertical", Game.pad_invert_y,
		"Pousser le stick droit vers le haut fait regarder vers le bas.", func(on: bool) -> void:
			Game.pad_invert_y = on)
	_slider(p, "Zone morte du stick", 0.05, 0.35, Game.pad_deadzone, 0.01, _pct,
		"Le mouvement du stick droit ignoré autour du centre (un stick usé dérive).", func(x: float) -> void:
			Game.pad_deadzone = x)
	_section(p, "Clavier et souris")
	p.add_child(_binding_header())
	for a in Controles.ACTIONS:
		var r := _row().setup_binding(a[1], ["—", "—"], "",
			"Entrée ou clic : changer la touche. ← → : choisir l'emplacement. Retour arrière : effacer. Une touche déjà prise est échangée.")
		var id: String = a[0]
		r.pressed.connect(func() -> void: _start_capture(r, id))
		p.add_child(r)
		bind_rows[id] = r
	p.add_child(_row().setup_info("Menu, pause", "Échap · Menu", "Échap (Menu à la manette) ouvre et ferme le menu ; cette touche ne se change pas."))
	p.add_child(_row().setup_info("Regarder", "Souris · stick droit", "Le regard suit la souris, ou le stick droit de la manette."))
	var reset := _row().setup_action("Rétablir les touches par défaut", "", "Remet toutes les touches du clavier et de la souris comme au premier lancement.")
	reset.pressed.connect(func() -> void:
		UiStyle.play_ui("click")
		Game.bindings = Controles.defaults()
		Game.apply_bindings()
		notice.text = "Touches par défaut rétablies."
		_refresh_bindings())
	p.add_child(reset)


func _page_access(p: VBoxContainer) -> void:
	_toggle(p, "Sous-titres des sons", Game.sound_captions,
		"Les sons importants écrits entre crochets, au-dessus des dialogues : [Coups dans le radiateur, en bas].", func(on: bool) -> void:
			Game.sound_captions = on
			Game.apply_settings())
	_toggle(p, "Fond des sous-titres", Game.subtitle_bg,
		"Un cartouche sombre derrière les sous-titres et les pensées : lisibles sur un mur clair ou pendant un éclair.", func(on: bool) -> void:
			Game.subtitle_bg = on
			Game.apply_ui_settings())
	_choice(p, "Taille des sous-titres", ["Normale", "Grande"], Game.subtitle_size,
		"La taille des sous-titres et des pensées du personnage.", func(i: int) -> void:
			Game.subtitle_size = i
			Game.apply_ui_settings())
	_toggle(p, "Sursauts réduits", Game.reduced_scares,
		"Le visage reste sur l'écran, les sons de sursaut sont plus bas, la caméra ne tremble pas.", func(on: bool) -> void:
			Game.reduced_scares = on
			Game.apply_settings())
	_toggle(p, "Éclairs adoucis (photosensibilité)", Game.soft_flashes,
		"Pas de flash plein écran : les éclairs restent doux.", func(on: bool) -> void:
			Game.soft_flashes = on
			Game.apply_settings())
	_slider(p, "Mouvements de la caméra", 0.0, 1.0, Game.mouvements_camera, 0.05, _pct,
		"Respiration, pas, roulis et secousses de la caméra. À 0 %, la caméra ne bouge qu'avec la souris.", func(x: float) -> void:
			Game.mouvements_camera = x
			Game.apply_settings())


func _page_jeu(p: VBoxContainer) -> void:
	_choice(p, "Point de visée", ["Contextuel", "Toujours"], Game.crosshair_mode,
		"« Contextuel » : il n'apparaît que sur un objet avec lequel agir.", func(i: int) -> void:
			Game.crosshair_mode = i
			Game.apply_ui_settings())
	_choice(p, "Objectif à l'écran", ["S'efface", "Toujours"], Game.objective_mode,
		"« S'efface » : l'objectif disparaît au bout de 8 s ; il revient quand il change, avec l'inventaire et après une minute sans progrès.",
		func(i: int) -> void:
			Game.objective_mode = i
			Game.apply_ui_settings())
	_toggle(p, "Cartes de chapitre", Game.chapter_cards, "Le titre de l'acte, au début de chaque acte.", func(on: bool) -> void:
		Game.chapter_cards = on
		Game.apply_ui_settings())
	_choice(p, "Transcription des documents", ["Sur demande", "Toujours"], 1 if Game.transcript_always else 0,
		"Le texte des mots et des carnets en caractères lisibles, à côté de la feuille. « Sur demande » : touche T (X à la manette).",
		func(i: int) -> void:
			Game.transcript_always = i == 1
			Game.apply_ui_settings())


# ------------------------------------------------------------------ onglets, aide

func show_tab(i: int, sound := true) -> void:
	tab = posmod(i, TABS.size())
	for k in pages.size():
		pages[k].visible = k == tab
	for k in tab_btns.size():
		var b := tab_btns[k]
		var on := k == tab
		var c := (UiStyle.INK if on else UiStyle.INK_FAINT) if net else (UiStyle.GREEN if on else Color(0.5, 0.49, 0.44))
		b.add_theme_color_override("font_color", c)
		b.add_theme_color_override("font_hover_color", UiStyle.INK if net else UiStyle.GREEN)
		b.add_theme_color_override("font_pressed_color", c)
		b.add_theme_color_override("font_focus_color", c)
		b.queue_redraw()
	notice.text = ""
	if sound:
		UiStyle.play_ui("tick")
	scroll.scroll_vertical = 0
	focus_first.call_deferred()


func focus_first() -> void:
	if not is_visible_in_tree():
		return
	for c in pages[tab].get_children():
		if c is OptionRow and (c as OptionRow).focus_mode != Control.FOCUS_NONE:
			(c as OptionRow).grab_focus()
			return


func _on_row_focus(r: OptionRow) -> void:
	_focused = r
	help_title.text = r.label_text
	help_text.text = r.help
	help_extra.visible = r.label_text == "Luminosité"
	if r == quality_row:
		_update_quality()


func _update_quality() -> void:
	if quality_row == null:
		return
	quality_row.set_choice(Game.quality)
	var help: String = Qualite.AIDE[clampi(Game.quality, 0, 3)]
	if Qualite.soft() and Game.quality > Qualite.ELEVEE:
		help += " · rendu logiciel : Élevée au plus"
	quality_row.help = help + "."
	if _focused == quality_row:
		help_text.text = quality_row.help


## Mire de la luminosité : sur un fond noir, le logo à la valeur MIRE_VALUE passée dans la même courbe
## que l'image (Main.net_curve, Main.net_display) ; on règle jusqu'à ce qu'il soit à peine visible.
func _build_mire(w: float) -> Control:
	var box := ColorRect.new()
	box.color = Color.BLACK
	box.custom_minimum_size = Vector2(minf(w, 170.0), 46.0 if net else 30.0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mire_logo = Label.new()
	mire_logo.text = "DON'T PLAY"
	if net:
		mire_logo.add_theme_font_override("font", UiStyle.tracked(UiStyle.sans_semi(), 3))
		mire_logo.add_theme_font_size_override("font_size", 14)
	else:
		mire_logo.add_theme_font_size_override("font_size", 20)
	mire_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mire_logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mire_logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(mire_logo)
	box.visible = false
	return box


func _update_mire() -> void:
	if mire_logo == null:
		return
	var g := Main.net_display(MIRE_VALUE, Main.net_curve(Game.luminosite))
	mire_logo.add_theme_color_override("font_color", Color(g, g, g))


# ------------------------------------------------------------------ remappage

func _refresh_bindings() -> void:
	var conf := Controles.conflicts(Game.bindings)
	for id in bind_rows:
		var r: OptionRow = bind_rows[id]
		var slots: Array = Game.bindings.get(id, Controles.DEFAULTS[id])
		var names: Array = []
		for s in slots:
			names.append(Controles.slot_name(str(s)))
		r.set_slots(names, Controles.pad_glyphs(id))
		r.warn = conf.has("%s/0" % id) or conf.has("%s/1" % id) or (str(slots[0]) == "" and str(slots[1]) == "")


func _start_capture(r: OptionRow, _id: String) -> void:
	if _capture:
		return
	_capture = r
	_capture_ms = Time.get_ticks_msec()
	r.capturing = true
	r.queue_redraw()
	UiStyle.play_ui("click")
	notice.text = "Appuie sur une touche ou un bouton de la souris pour « %s ». Échap : annuler · Retour arrière : effacer." % r.label_text


func _end_capture(slot: Variant) -> void:
	var r := _capture
	_capture = null
	if r == null:
		return
	r.capturing = false
	var id := ""
	for k in bind_rows:
		if bind_rows[k] == r:
			id = k
	if slot == null or id == "":
		notice.text = ""
		r.queue_redraw()
		return
	var swapped := Controles.assign(Game.bindings, id, r.slot_i, str(slot))
	Game.apply_bindings()
	_refresh_bindings()
	if swapped != "":
		notice.text = "« %s » était aussi sur « %s » : les deux touches ont été échangées." % [Controles.slot_name(str(slot)), Controles.label_of(swapped)]
	else:
		notice.text = ""
	UiStyle.play_ui("click")
	r.grab_focus()


func capturing() -> bool:
	return _capture != null


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _capture:
		if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			var k := event as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if code == KEY_ESCAPE:
				_end_capture(null)
			elif code == KEY_BACKSPACE or code == KEY_DELETE:
				_end_capture("")
			else:
				var s := Controles.from_event(k)
				if s != "":
					_end_capture(s)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			if Time.get_ticks_msec() - _capture_ms > 150:
				var s2 := Controles.from_event(event)
				if s2 != "":
					_end_capture(s2)
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			if (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
				_end_capture(null)
			get_viewport().set_input_as_handled()
		return
	var prev := false
	var next := false
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		prev = (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER
		next = (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var pk := (event as InputEventKey).physical_keycode
		prev = pk == KEY_Q or pk == KEY_PAGEUP
		next = pk == KEY_E or pk == KEY_PAGEDOWN
	if prev or next:
		show_tab(tab + (1 if next else -1))
		get_viewport().set_input_as_handled()
