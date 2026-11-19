extends CanvasLayer
## Interface en jeu : point de visée, invite d'interaction, objectif (deux lignes), pensées du héros,
## sous-titres, disquette en main, mot ou image à lire, écran en grand (console), inventaire, fondu au noir,
## cartes de chapitre, indice d'enregistrement.
## L'interface est pensée en 640×360 (étirement « canvas_items »). Deux styles (lot V3-INTERFACE) :
##  - net (par défaut) : Source Sans Pro rendue à la résolution de l'écran (UiStyle), invite discrète sous le
##    réticule (touche ou bouton du dernier périphérique utilisé, fondu de 0,12 s), objectif qui s'efface au bout
##    de 8 s et revient (changement, Tab, 60 s sans progrès), sous-titres blanc cassé sur cartouche
##    translucide (option), documents sur une feuille texturée avec transcription (T), inventaire en panneau ;
##  - rétro (Game.style_retro) : la mise en page d'avant, en VT323 aux seules tailles nettes (20 et 10 px ; en
##    12 à 16 px, le « M » de cette police se lit « N »).
## Les textes (hint_lbl.text, sous-titres, pages, objectif) ne changent jamais : seuls la police, la place et
## la transparence changent.

signal subtitle_shown(who: String, text: String)
signal sound_captioned(text: String)     # un sous-titre de son vient de s'afficher (option active)
signal screen_closed

const GREEN := Color(0.36, 1.0, 0.42)
const PAPER := Color(0.94, 0.9, 0.82)
const INK := Color(0.15, 0.16, 0.42)
## Couleurs des sous-titres du style rétro : l'entité (vert phosphore), les proches (beige), les sons (gris).
const SUB_COLORS := {
	"elle": Color(0.42, 1.0, 0.5), "proche": Color(0.9, 0.82, 0.64), "son": Color(0.62, 0.62, 0.6),
	"autre": Color(0.88, 0.88, 0.86),
}
const ENTITY_NAMES := ["elle", "nestor", "console", "babyphone", "miroir", "imprimante", "télé", "enceinte"]
const PROCHE_NAMES := ["mamie", "papi", "henriette", "albert", "manon", "maman"]
const FONT := 20          # taille du texte du HUD rétro (nette)
const FONT_SMALL := 10    # descriptions de l'inventaire rétro (nette)
const INV_COL_W := 248    # largeur d'une colonne de l'inventaire (rétro)
const INV_COL_W_NET := 196
const INV_MAX_H := 300    # au-delà (en pixels estimés), l'inventaire passe sur deux colonnes
## Les quatre pièces de l'arme (croquis de Manon), dans l'ordre de l'inventaire.
const WEAPON_LABELS := {"seche_cheveux": "Sèche-cheveux", "antenne": "Antenne", "boussole": "Boussole", "bobine": "Bobine"}
# --- style net
const PROMPT_Y := 40.0       # invite : sous le réticule (pixels logiques depuis le centre)
const PROMPT_FADE := 0.12
const OBJ_SHOW := 8.0        # objectif : visible 8 s, puis s'efface
const OBJ_IDLE := 60.0       # … et revient après 60 s sans progrès
const NET_BOT := 22.0        # marge du bas (sous-titres, pensées)
const NET_SIDE := 128.0      # sous-titres et pensées : 60 % de la largeur, centrés
const SHEET := Vector2(190, 250)

var player: Node
var root: Control
var crosshair: ColorRect
var prompt: Label
var objective: Label
var hint_lbl: Label
var hand: Control
var paper: Control
var paper_text: Label
var fade: ColorRect
var paper_open := false
var paper_foot: Label
var _pages: Array = []
var _page_i := 0
var _hint_left := 0.0
var inv: Control
var inv_head: RichTextLabel
var inv_list: RichTextLabel         # première colonne
var inv_list2: RichTextLabel        # seconde colonne (inventaire bien rempli)
var inv_open := false
var toast: Label
var _toast_tw: Tween
var objective_sub: Label
# sous-titres
var sub_lbl: RichTextLabel
var caption_both := 0              # images où un son et un dialogue sont affichés ensemble (C5)
var caption_overlap_max := -INF    # pire chevauchement de leurs textes (px ; ≤ 0 : jamais)
var subtitle_log: Array = []        # lignes affichées, dans l'ordre : {who, text, kind}
var current_subtitle := ""          # texte affiché en ce moment ("" = rien)
var current_kind := ""              # sorte de la ligne affichée : "elle", "proche", "son", "autre"
var _sub_queue: Array = []
var _sub_left := 0.0
var _sub_cur: Dictionary = {}
# sous-titres des sons importants (option) : une ligne à part, au-dessus des dialogues, tout de suite
var snd_lbl: Label
var caption_log: Array = []         # sous-titres de sons affichés, dans l'ordre : {text, t (s)}
var current_caption := ""
var _snd_left := 0.0
var _snd_tw: Tween
# image dans le lecteur de papiers, écran en grand
var _paper_fs := 26                 # taille de l'écriture manuscrite (rapetisse si la page déborde)
const PAPER_TEXT_H := 220.0         # hauteur disponible pour l'écriture sur la feuille
var paper_image: TextureRect
var paper_legend: Label
var _paper_lines: Array[Control] = []
var screen_view: Control
var screen_rect: TextureRect
var screen_bezel: ColorRect
var screen_foot: Label
var screen_open := false
var screen_locked := false          # séquence ABSORBÉ : l'écran ne se ferme ni par E ni par Échap
var _screen_foot_tw: Tween

# --- ajouts du lot V3-INTERFACE
var net := true                     # style net (faux : rétro), relu à chaque changement de réglage
var reticle: Control                # point de visée du style net (dessiné : net à toute résolution)
var _ret_on := false                # l'invite est montrée (un objet visé)
var _ret_t := 0.0                   # 0 : point simple, 1 : point et anneau (objet visé)
var _crosshair_shown := true        # show_crosshair()
var prompt_pill: PanelContainer     # style net : [touche] verbe, sur un fond à peine visible
var prompt_row: HBoxContainer
var prompt_key: PanelContainer
var _prompt_tw: Tween
var _prompt_on := false
var obj_bg: Control                 # dégradé sombre derrière l'objectif (style net)
var _obj_t := 0.0
var _obj_idle := 0.0
var _obj_alpha := 1.0
var sub_bg: CaptionBg
var snd_bg: CaptionBg
var hint_bg: CaptionBg
var _bot := 12.0
var _lh_sub := 20.0
var _lh_snd := 20.0
var _lh_hint := 20.0
var paper_sheet: ColorRect
var paper_shadow: Panel
var paper_hints: KeyHints
var paper_page: Label
var transcript: PanelContainer
var transcript_lbl: Label
var transcript_on := false
var screen_hints: KeyHints
var save_ind: Control
var _save_tw: Tween
var _save_spin := 0.0
var chapter: Control
var _chapter_tw: Tween
var _ui_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group("hud")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.45)
	_crosshair_size(2.0)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	reticle = Control.new()
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.draw.connect(_draw_reticle)
	root.add_child(reticle)

	prompt = _label(GREEN)
	prompt.visible = false
	root.add_child(prompt)
	prompt_pill = PanelContainer.new()
	prompt_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_pill.set_anchors_preset(Control.PRESET_CENTER)
	prompt_pill.offset_left = 0
	prompt_pill.offset_right = 0
	prompt_pill.offset_top = PROMPT_Y
	prompt_pill.offset_bottom = PROMPT_Y
	prompt_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_pill.grow_vertical = Control.GROW_DIRECTION_END
	prompt_pill.add_theme_stylebox_override("panel", UiStyle.box(Color(0, 0, 0, 0.22), 3, Color(0, 0, 0, 0), 0, 5.0, 2.0))
	prompt_pill.modulate.a = 0.0
	prompt_pill.visible = false
	root.add_child(prompt_pill)
	prompt_row = HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 5)
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_pill.add_child(prompt_row)
	prompt_key = UiStyle.keycap("E")
	prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_row.add_child(prompt_key)

	obj_bg = Control.new()
	obj_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_bg.draw.connect(_draw_obj_bg)
	root.add_child(obj_bg)
	objective = _label(Color(0.62, 0.66, 0.6, 0.85))
	root.add_child(objective)
	objective_sub = _label(Color(0.5, 0.54, 0.48, 0.8))
	root.add_child(objective_sub)

	hint_bg = CaptionBg.new()
	hint_bg.bottom = true
	root.add_child(hint_bg)
	hint_lbl = _label(Color(0.85, 0.82, 0.74))
	hint_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.modulate.a = 0.0
	root.add_child(hint_lbl)
	hint_bg.target = hint_lbl

	sub_bg = CaptionBg.new()
	root.add_child(sub_bg)
	sub_lbl = RichTextLabel.new()
	sub_lbl.bbcode_enabled = true
	sub_lbl.fit_content = true
	sub_lbl.scroll_active = false
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub_lbl.offset_top = -52
	sub_lbl.offset_bottom = -12
	sub_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.visible = false
	root.add_child(sub_lbl)
	sub_bg.target = sub_lbl

	snd_bg = CaptionBg.new()
	snd_bg.bottom = true
	root.add_child(snd_bg)
	snd_lbl = _label(SUB_COLORS.son)
	snd_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	snd_lbl.offset_top = -52
	snd_lbl.offset_bottom = -12
	snd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	snd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	snd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snd_lbl.visible = false
	root.add_child(snd_lbl)
	snd_bg.target = snd_lbl

	hand = _build_hand()
	hand.visible = false
	root.add_child(hand)

	paper = _build_paper()
	paper.visible = false
	root.add_child(paper)

	screen_view = _build_screen_view()
	screen_view.visible = false
	root.add_child(screen_view)

	inv = _build_inventory()
	inv.visible = false
	root.add_child(inv)

	# « + objet » : en haut à droite (l'objectif est en haut à gauche, les sous-titres et les pensées en bas)
	toast = _label(GREEN)
	toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast.position = Vector2(-330, 4)
	toast.size = Vector2(320, 20)
	toast.modulate.a = 0.0
	root.add_child(toast)

	save_ind = _build_save_indicator()
	root.add_child(save_ind)

	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = &"Master"
	add_child(_ui_player)

	Game.objective_changed.connect(_on_objective)
	Game.hint_requested.connect(show_hint)
	Game.inventory_changed.connect(_refresh_inventory)
	Game.item_added.connect(_on_item_added)
	Game.settings_changed.connect(_apply_style)
	Game.ui_settings_changed.connect(_apply_style)
	Game.input_device_changed.connect(func(_p: bool) -> void: _on_device())
	Game.saved.connect(func(_id: String) -> void: show_saving())
	_apply_style()


## Place un contrôle ancré en un point (CENTER, TOP_RIGHT…) : « rel » depuis ce point, taille « sz ». (En
## Godot 4, « position » se compte depuis le coin du parent : elle ne vaut décalage que tant que le parent
## n'a pas encore sa taille.)
static func _place(c: Control, rel: Vector2, sz: Vector2) -> void:
	c.offset_left = rel.x
	c.offset_top = rel.y
	c.offset_right = rel.x + sz.x
	c.offset_bottom = rel.y + sz.y


func _label(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ------------------------------------------------------------------ style (net ou rétro)

## Applique le style courant (Game.style_retro) et les options d'interface (fond et taille des sous-titres,
## point de visée…) aux mêmes nœuds : leurs textes ne changent pas.
func _apply_style() -> void:
	net = UiStyle.net()
	var th := Theme.new()
	th.default_font = UiStyle.sans() if net else UiStyle.pixel()
	th.default_font_size = UiStyle.BODY if net else FONT
	root.theme = th
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if net else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	var big := Game.subtitle_size == 1
	var fs_sub := (UiStyle.SUB_LARGE if big else UiStyle.SUB) if net else FONT
	var fs_hint := (UiStyle.SUB_LARGE - 1 if big else UiStyle.SUB - 1) if net else FONT
	var fs_snd := (UiStyle.SUB_LARGE - 2 if big else UiStyle.SUB - 1) if net else FONT
	var out_c := Color(0, 0, 0, 0.9)
	# --- objectif
	if net:
		UiStyle.apply_label(objective, UiStyle.sans_semi(), UiStyle.BODY, Color(UiStyle.INK, 0.92), true)
		UiStyle.apply_label(objective_sub, UiStyle.sans(), UiStyle.SMALL + 1, Color(UiStyle.INK_DIM, 0.95), true)
		objective.position = Vector2(20, 13)
		objective_sub.position = Vector2(20, 27)
	else:
		_retro_label(objective, Color(0.62, 0.66, 0.6, 0.85), 4, Color(0, 0, 0, 0.7))
		_retro_label(objective_sub, Color(0.5, 0.54, 0.48, 0.8), 4, Color(0, 0, 0, 0.7))
		objective.position = Vector2(10, 4)
		objective_sub.position = Vector2(10, 22)
	obj_bg.visible = net
	# --- pensées du héros
	hint_lbl.label_settings = null
	if net:
		var ls := LabelSettings.new()
		ls.font = UiStyle.sans_it()
		ls.font_size = fs_hint
		ls.font_color = UiStyle.INK
		ls.line_spacing = 4.0
		ls.shadow_color = Color(0, 0, 0, 0.6)
		ls.shadow_size = 2
		ls.shadow_offset = Vector2(0, 0.6)
		hint_lbl.label_settings = ls
		_lh_hint = ls.font.get_height(fs_hint) + ls.line_spacing
		hint_lbl.offset_left = NET_SIDE - 20.0
		hint_lbl.offset_right = -(NET_SIDE - 20.0)
		hint_lbl.offset_bottom = -NET_BOT
		hint_lbl.offset_top = -NET_BOT - 3.0 * _lh_hint - 2.0
		_bot = NET_BOT
	else:
		_retro_label(hint_lbl, Color(0.85, 0.82, 0.74), 4, out_c)
		_lh_hint = FONT
		hint_lbl.offset_left = 40
		hint_lbl.offset_right = -40
		hint_lbl.offset_top = -72      # trois lignes de 20 px
		hint_lbl.offset_bottom = -10
		_bot = 12.0
	hint_bg.font = UiStyle.sans_it() if net else null
	hint_bg.font_size = fs_hint
	hint_bg.line_extra = 4.0
	hint_bg.enabled = net and Game.subtitle_bg
	# --- dialogues
	if net:
		sub_lbl.add_theme_font_override("normal_font", UiStyle.sans())
		sub_lbl.add_theme_font_override("bold_font", UiStyle.sans_semi())
		sub_lbl.add_theme_font_size_override("normal_font_size", fs_sub)
		sub_lbl.add_theme_font_size_override("bold_font_size", fs_sub)
		sub_lbl.add_theme_constant_override("outline_size", 0)
		sub_lbl.add_theme_constant_override("shadow_offset_x", 0)
		sub_lbl.add_theme_constant_override("shadow_offset_y", 1)
		sub_lbl.add_theme_constant_override("shadow_outline_size", 2)
		sub_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0 if Game.subtitle_bg else 0.75))
		sub_lbl.add_theme_constant_override("line_separation", 1)
		sub_lbl.offset_left = NET_SIDE
		sub_lbl.offset_right = -NET_SIDE
		_lh_sub = UiStyle.sans().get_height(fs_sub) + 1.0
	else:
		sub_lbl.add_theme_font_override("normal_font", UiStyle.pixel())
		sub_lbl.add_theme_font_override("bold_font", UiStyle.pixel())
		sub_lbl.add_theme_font_size_override("normal_font_size", FONT)
		sub_lbl.add_theme_font_size_override("bold_font_size", FONT)
		sub_lbl.add_theme_constant_override("outline_size", 4)
		sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		sub_lbl.add_theme_constant_override("shadow_outline_size", 0)
		sub_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		sub_lbl.add_theme_constant_override("line_separation", 0)
		sub_lbl.offset_left = 50
		sub_lbl.offset_right = -50
		_lh_sub = FONT
	sub_bg.font = UiStyle.sans()
	sub_bg.font_size = fs_sub
	sub_bg.line_extra = 1.0
	sub_bg.enabled = net and Game.subtitle_bg
	# --- sons
	snd_lbl.label_settings = null
	if net:
		var ls2 := LabelSettings.new()
		ls2.font = UiStyle.sans()
		ls2.font_size = fs_snd
		ls2.font_color = UiStyle.SPEAKER.son
		ls2.shadow_color = Color(0, 0, 0, 0.0 if Game.subtitle_bg else 0.75)
		ls2.shadow_size = 2
		ls2.shadow_offset = Vector2(0, 0.6)
		snd_lbl.label_settings = ls2
		snd_lbl.offset_left = NET_SIDE
		snd_lbl.offset_right = -NET_SIDE
		_lh_snd = ls2.font.get_height(fs_snd)
	else:
		_retro_label(snd_lbl, SUB_COLORS.son, 4, Color(0, 0, 0, 0.92))
		snd_lbl.add_theme_constant_override("line_spacing", 0)
		snd_lbl.offset_left = 50
		snd_lbl.offset_right = -50
		_lh_snd = FONT
	snd_bg.font = UiStyle.sans()
	snd_bg.font_size = fs_snd
	snd_bg.enabled = net and Game.subtitle_bg
	if current_subtitle != "" and not _sub_cur.is_empty():
		_show_sub_line(_sub_cur)
	# --- invite
	_place_prompt()
	# --- toast
	if net:
		UiStyle.apply_label(toast, UiStyle.sans_semi(), UiStyle.SMALL + 1, UiStyle.INK, true)
		_place(toast, Vector2(-338, 13), Vector2(320, 14))
	else:
		toast.label_settings = null
		_retro_label(toast, GREEN, 4, Color(0, 0, 0, 0.9))
		_place(toast, Vector2(-330, 4), Vector2(320, 20))
	obj_bg.queue_redraw()
	_style_hand()
	_style_paper()
	_style_screen()
	_style_inventory()
	_style_save()
	_update_reticle()
	_refresh_inventory()


func _retro_label(l: Label, c: Color, outline: int, oc: Color) -> void:
	l.label_settings = null
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", oc)


func _on_device() -> void:
	_place_prompt()
	if paper_open:
		_update_paper_hints()


# ------------------------------------------------------------------ point de visée, invite

## Invite : style net, [touche] verbe dans une pastille sous le réticule ; rétro, le bandeau « [E] … » d'avant.
func _place_prompt() -> void:
	var it: Interactable = player.current if player and _prompt_on else null
	if net:
		if prompt.get_parent() != prompt_row:
			prompt.get_parent().remove_child(prompt)
			prompt_row.add_child(prompt)
		prompt.remove_theme_stylebox_override("normal")
		UiStyle.apply_label(prompt, UiStyle.sans(), UiStyle.BODY, Color(UiStyle.INK, 0.86), true)
		prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
		prompt.custom_minimum_size = Vector2.ZERO
		prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		prompt.visible = true
		UiStyle.set_keycap(prompt_key, Controles.glyph("interact", Game.pad_active), Game.pad_active)
		if it:
			prompt.text = it.label
		prompt_pill.visible = _prompt_on or prompt_pill.modulate.a > 0.01
		prompt_pill.reset_size()
	else:
		if prompt.get_parent() != root:
			prompt.get_parent().remove_child(prompt)
			root.add_child(prompt)
			root.move_child(prompt, reticle.get_index() + 1)
		_retro_label(prompt, GREEN, 0, Color(0, 0, 0, 0))
		prompt.set_anchors_preset(Control.PRESET_CENTER)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_place(prompt, Vector2(-200, 24), Vector2(400, 20))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.6)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		prompt.add_theme_stylebox_override("normal", sb)
		prompt_pill.visible = false
		prompt.visible = _prompt_on
		if it:
			prompt.text = "[%s] %s" % [Controles.glyph("interact", Game.pad_active), it.label]


func set_prompt(it: Interactable) -> void:
	var on := it != null and Game.phase == "room"
	_prompt_on = on
	if on:
		if net:
			prompt.text = it.label
			UiStyle.set_keycap(prompt_key, Controles.glyph("interact", Game.pad_active), Game.pad_active)
			prompt_pill.reset_size()
			_fade_prompt(not inv_open and not is_reading())
		else:
			prompt.text = "[%s] %s" % [Controles.glyph("interact", Game.pad_active), it.label]
			prompt.visible = true
		crosshair.color = Color(GREEN, 0.9)
		_crosshair_size(3.0)
	else:
		if net:
			_fade_prompt(false)
		else:
			prompt.visible = false
		crosshair.color = Color(1, 1, 1, 0.45)
		_crosshair_size(2.0)
	_update_reticle()


func _fade_prompt(show_: bool) -> void:
	if _prompt_tw:
		_prompt_tw.kill()
	if show_:
		prompt_pill.visible = true
	_prompt_tw = create_tween()
	_prompt_tw.tween_property(prompt_pill, "modulate:a", 1.0 if show_ else 0.0, PROMPT_FADE)
	if not show_:
		_prompt_tw.tween_callback(func() -> void:
			if not _prompt_on or inv_open or is_reading():
				prompt_pill.visible = false)


## Le réticule, carré de « s » px centré sur l'écran : ancré au centre, décalages autour de l'ancre.
## (En Godot 4, « position » se compte depuis le coin du parent : le réticule partait en haut à gauche
## dès que le HUD avait sa vraie taille.)
func _crosshair_size(s: float) -> void:
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -s / 2.0
	crosshair.offset_top = -s / 2.0
	crosshair.offset_right = s / 2.0
	crosshair.offset_bottom = s / 2.0


## Point de visée du style net : un point discret (option « Toujours ») ; sur un objet, le point et un anneau.
## Option « Contextuel » (par défaut) : rien tant qu'aucun objet n'est visé.
func _update_reticle() -> void:
	crosshair.visible = _crosshair_shown and not net
	reticle.visible = _crosshair_shown and net
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void:
		_ret_t = x
		reticle.queue_redraw(), _ret_t, 1.0 if _prompt_on else 0.0, PROMPT_FADE)


func _draw_reticle() -> void:
	var always := Game.crosshair_mode == 1
	var a_dot := lerpf(0.42 if always else 0.0, 0.9, _ret_t)
	if a_dot > 0.01:
		reticle.draw_circle(Vector2.ZERO, lerpf(0.9, 1.15, _ret_t), Color(1, 1, 1, a_dot), true, -1.0, true)
	if _ret_t > 0.01:
		reticle.draw_arc(Vector2.ZERO, lerpf(2.5, 4.6, _ret_t), 0.0, TAU, 32, Color(1, 1, 1, 0.45 * _ret_t), 0.6, true)


func show_crosshair(v: bool) -> void:
	_crosshair_shown = v
	crosshair.visible = v and not net
	reticle.visible = v and net


# ------------------------------------------------------------------ objectif

func _on_objective(text: String) -> void:
	var parts := text.split("\n", true, 1)
	objective.text = parts[0]
	objective_sub.text = parts[1] if parts.size() > 1 else ""
	_obj_t = 0.0
	_obj_idle = 0.0
	if obj_bg:
		obj_bg.queue_redraw()


## Dégradé sombre derrière l'objectif (lisible sur un mur clair), plus long que le texte.
func _draw_obj_bg() -> void:
	if objective.text == "":
		return
	var w := maxf(objective.get_minimum_size().x, objective_sub.get_minimum_size().x) + 70.0
	var h := 44.0 if objective_sub.text != "" else 31.0
	var c0 := Color(0, 0, 0, 0.5)
	var c1 := Color(0, 0, 0, 0.0)
	obj_bg.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([c0, c1, c1, c0]))
	obj_bg.draw_rect(Rect2(13, 15, 1.2, h - 22.0), Color(UiStyle.ACCENT, 0.8))


func _process_objective(delta: float) -> void:
	if not net:
		_obj_alpha = 1.0
	else:
		var target := 0.0
		if objective.text != "":
			if Game.objective_mode == 1 or inv_open:
				target = 1.0
				_obj_t = 0.0
			else:
				_obj_t += delta
				_obj_idle += delta
				if _obj_idle >= OBJ_IDLE:
					_obj_idle = 0.0
					_obj_t = 0.0
				target = 1.0 if _obj_t < OBJ_SHOW else 0.0
		_obj_alpha = move_toward(_obj_alpha, target, delta / (0.35 if target > _obj_alpha else 1.4))
	objective.modulate.a = _obj_alpha
	objective_sub.modulate.a = _obj_alpha
	obj_bg.modulate.a = _obj_alpha


# ------------------------------------------------------------------ disquette en main, enregistrement

func _build_hand() -> Control:
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.07)
	sb.set_corner_radius_all(2)
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.size = Vector2(40, 40)
	box.position = Vector2(-52, -52)
	box.rotation = 0.18
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := TextureRect.new()
	lab.texture = load("res://assets/images/floppy_label.png")
	lab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lab.stretch_mode = TextureRect.STRETCH_SCALE
	lab.position = Vector2(4, 3)
	lab.size = Vector2(32, 12)
	box.add_child(lab)
	var hub := ColorRect.new()
	hub.color = Color(0.38, 0.35, 0.3)
	hub.position = Vector2(16, 22)
	hub.size = Vector2(8, 8)
	box.add_child(hub)
	return box


## Style net : la disquette tenue en bas à gauche (la main et la lampe sont à droite), plus petite.
func _style_hand() -> void:
	var sb := hand.get_theme_stylebox("panel") as StyleBoxFlat
	if net:
		hand.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		hand.scale = Vector2(0.8, 0.8)
		_place(hand, Vector2(22, -54), Vector2(40, 40))
		hand.rotation = -0.12
		if sb:
			sb.shadow_color = Color(0, 0, 0, 0.5)
			sb.shadow_size = 6
			sb.set_corner_radius_all(2)
	else:
		hand.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hand.scale = Vector2.ONE
		_place(hand, Vector2(-52, -52), Vector2(40, 40))
		hand.rotation = 0.18
		if sb:
			sb.shadow_size = 0


func show_hand(v: bool) -> void:
	hand.visible = v


## Indice d'enregistrement (Game.saved) : en haut à droite, un anneau qui tourne et « Enregistrement », 2,4 s.
func _build_save_indicator() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.modulate.a = 0.0
	c.visible = false
	var l := Label.new()
	l.name = "Txt"
	l.text = "Enregistrement"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	c.add_child(l)
	c.draw.connect(func() -> void:
		if not net:
			return
		var ctr := Vector2(-10.0, 5.0)
		c.draw_arc(ctr, 3.2, 0.0, TAU, 24, Color(1, 1, 1, 0.15), 0.9, true)
		c.draw_arc(ctr, 3.2, _save_spin, _save_spin + 1.9, 16, Color(UiStyle.INK, 0.85), 0.9, true))
	return c


func _style_save() -> void:
	var l := save_ind.get_node("Txt") as Label
	save_ind.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	if net:
		UiStyle.apply_label(l, UiStyle.sans(), UiStyle.SMALL, UiStyle.INK_DIM, true)
		l.text = "Enregistrement"
		_place(save_ind, Vector2(-20, 32), Vector2.ZERO)
		l.position = Vector2(-122, -1)
		l.size = Vector2(104, 12)
	else:
		l.label_settings = null
		l.add_theme_font_size_override("font_size", FONT_SMALL)
		l.add_theme_font_override("font", Game.fonts.pixel_small)
		l.add_theme_color_override("font_color", GREEN)
		l.text = "ENREGISTREMENT…"
		_place(save_ind, Vector2(-10, 26), Vector2.ZERO)
		l.position = Vector2(-160, 0)
		l.size = Vector2(160, 12)


func show_saving() -> void:
	if save_ind == null:
		return
	save_ind.visible = true
	if _save_tw:
		_save_tw.kill()
	_save_tw = create_tween()
	_save_tw.tween_property(save_ind, "modulate:a", 1.0, 0.3)
	_save_tw.tween_interval(1.9)
	_save_tw.tween_property(save_ind, "modulate:a", 0.0, 0.6)
	_save_tw.tween_callback(func() -> void: save_ind.visible = false)


# ------------------------------------------------------------------ cartes de chapitre

## Carte de chapitre (lot V3-INTERFACE) : « ACTE II » puis le titre (« Essais réels »), qui apparaît et
## s'efface sans rien bloquer. Option « Cartes de chapitre » (Game.chapter_cards). Sous le fondu au noir.
func chapter_card(act: String, title: String, delay := 0.6) -> void:
	if not Game.chapter_cards:
		return
	if chapter and is_instance_valid(chapter):
		chapter.queue_free()
	# une bande sombre, douce, sur toute la largeur (le titre reste lisible sur un mur éclairé), puis le titre
	chapter = Control.new()
	chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter.set_anchors_preset(Control.PRESET_FULL_RECT)
	if net:
		chapter.draw.connect(func() -> void:
			var w := chapter.size.x
			var cy := chapter.size.y / 2.0 - 46.0
			var t := Color(0, 0, 0, 0.0)
			var m := Color(0, 0, 0, 0.42)
			chapter.draw_polygon(PackedVector2Array([Vector2(0, cy - 44), Vector2(w, cy - 44), Vector2(w, cy), Vector2(0, cy)]),
				PackedColorArray([t, t, m, m]))
			chapter.draw_polygon(PackedVector2Array([Vector2(0, cy), Vector2(w, cy), Vector2(w, cy + 44), Vector2(0, cy + 44)]),
				PackedColorArray([m, m, t, t])))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.offset_top = -46
	col.offset_bottom = -46
	col.add_theme_constant_override("separation", 3 if net else 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	chapter.add_child(col)
	var a: Label
	var t: Label
	if net:
		a = UiStyle.label(act.to_upper(), UiStyle.tracked(UiStyle.sans_semi(), 3), UiStyle.SMALL, Color(UiStyle.INK, 0.75), true)
		t = UiStyle.label(title, UiStyle.serif_it(), 26, UiStyle.INK, true)
	else:
		a = Label.new()
		a.text = act.to_upper()
		a.add_theme_color_override("font_color", Color(GREEN, 0.8))
		a.add_theme_constant_override("outline_size", 4)
		a.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		t = Label.new()
		t.text = title
		t.add_theme_font_size_override("font_size", 40)
		t.add_theme_color_override("font_color", GREEN)
		t.add_theme_constant_override("outline_size", 6)
		t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(a)
	if net:
		var line := ColorRect.new()
		line.color = Color(UiStyle.ACCENT, 0.7)
		line.custom_minimum_size = Vector2(28, 1)
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(line)
	col.add_child(t)
	chapter.modulate.a = 0.0
	root.add_child(chapter)
	root.move_child(chapter, fade.get_index())
	var c := chapter
	_chapter_tw = create_tween()
	_chapter_tw.tween_interval(delay)
	_chapter_tw.tween_property(c, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	_chapter_tw.parallel().tween_property(col, "offset_top", -50.0, 6.0).set_trans(Tween.TRANS_SINE)
	_chapter_tw.parallel().tween_property(col, "offset_bottom", -50.0, 6.0).set_trans(Tween.TRANS_SINE)
	_chapter_tw.tween_interval(3.0)
	_chapter_tw.tween_property(c, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	_chapter_tw.tween_callback(c.queue_free)


# ------------------------------------------------------------------ papier, image, écran en grand

func _build_paper() -> Control:
	var wrap := ColorRect.new()
	wrap.color = Color(0, 0, 0, 0.7)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper_shadow = Panel.new()
	paper_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper_shadow.set_anchors_preset(Control.PRESET_CENTER)
	wrap.add_child(paper_shadow)
	var sheet := ColorRect.new()
	paper_sheet = sheet
	sheet.color = PAPER
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.size = SHEET
	sheet.position = Vector2(-95, -132)
	sheet.rotation = -0.025
	wrap.add_child(sheet)
	for i in 10:
		var line := ColorRect.new()
		line.color = Color(0.6, 0.64, 0.82, 0.45)
		line.position = Vector2(0, 38 + i * 21)
		line.size = Vector2(190, 1)
		sheet.add_child(line)
		_paper_lines.append(line)
	# feuille imprimée (plan, croquis, photo) : l'image remplace l'écriture
	paper_image = TextureRect.new()
	paper_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	paper_image.position = Vector2(8, 8)
	paper_image.size = Vector2(174, 234)
	paper_image.visible = false
	sheet.add_child(paper_image)
	paper_text = Label.new()
	paper_text.add_theme_font_override("font", Game.fonts.hand)
	paper_text.add_theme_font_size_override("font_size", 26)
	paper_text.add_theme_color_override("font_color", INK)
	paper_text.add_theme_constant_override("line_spacing", -7)
	paper_text.position = Vector2(20, 18)
	paper_text.size = Vector2(160, 220)
	paper_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(paper_text)
	var foot := _label(Color(0.7, 0.68, 0.6))
	paper_foot = foot
	foot.text = "E OU ÉCHAP POUR REPOSER"
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(-200, -20)
	foot.size = Vector2(400, 20)
	wrap.add_child(foot)
	paper_legend = _label(Color(0.85, 0.82, 0.74))
	paper_legend.set_anchors_preset(Control.PRESET_CENTER)
	paper_legend.position = Vector2(-290, 120)
	paper_legend.size = Vector2(580, 40)
	paper_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paper_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper_legend.visible = false
	wrap.add_child(paper_legend)
	# style net : aides de touches, numéro de page, transcription lisible
	paper_hints = KeyHints.new([], UiStyle.SMALL)
	paper_hints.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	paper_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	paper_hints.offset_top = -24
	paper_hints.offset_bottom = -24
	wrap.add_child(paper_hints)
	paper_page = UiStyle.label("", UiStyle.tracked(UiStyle.sans_semi(), 2), UiStyle.TINY, UiStyle.INK_DIM, true)
	paper_page.set_anchors_preset(Control.PRESET_CENTER)
	paper_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(paper_page, Vector2(-60, 124), Vector2(120, 12))
	wrap.add_child(paper_page)
	transcript = PanelContainer.new()
	transcript.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transcript.set_anchors_preset(Control.PRESET_CENTER)
	transcript.custom_minimum_size = Vector2(230, 0)
	transcript.add_theme_stylebox_override("panel", UiStyle.box(Color(0.03, 0.03, 0.035, 0.82), 3, UiStyle.LINE, 1, 14.0, 12.0))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transcript.add_child(tv)
	tv.add_child(UiStyle.label("TRANSCRIPTION", UiStyle.tracked(UiStyle.sans_semi(), 2), UiStyle.TINY, UiStyle.ACCENT, false))
	transcript_lbl = UiStyle.label("", UiStyle.sans(), UiStyle.BODY, UiStyle.INK, false)
	transcript_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transcript_lbl.custom_minimum_size = Vector2(202, 0)
	transcript_lbl.label_settings.line_spacing = 2.0
	tv.add_child(transcript_lbl)
	transcript.visible = false
	wrap.add_child(transcript)
	return wrap


func _style_paper() -> void:
	paper.color = Color(0, 0, 0, 0.78 if net else 0.7)
	if net:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/ui_paper.gdshader")
		var alb: Texture2D = load("res://assets/textures/Paper002/Paper002_albedo.jpg")
		var nrm: Texture2D = load("res://assets/textures/Paper002/Paper002_normal_gl.jpg")
		sm.set_shader_parameter("albedo", alb)
		sm.set_shader_parameter("normal_map", nrm)
		sm.set_shader_parameter("sheet_px", SHEET)
		paper_sheet.material = sm
		paper_sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var sh := UiStyle.box(Color(0, 0, 0, 0.0), 2)
		sh.shadow_color = Color(0, 0, 0, 0.55)
		sh.shadow_size = 14
		sh.shadow_offset = Vector2(3, 7)
		paper_shadow.add_theme_stylebox_override("panel", sh)
		paper_shadow.visible = true
		for l in _paper_lines:
			(l as ColorRect).color = Color(0.45, 0.52, 0.72, 0.32)
		paper_foot.visible = false
		paper_hints.visible = true
		paper_page.visible = true
		UiStyle.apply_label(paper_legend, UiStyle.sans_it(), UiStyle.SUB - 1, UiStyle.INK, true)
		paper_legend.label_settings.line_spacing = 2.0
		_place(paper_legend, Vector2(-200, 128), Vector2(400, 34))
	else:
		paper_sheet.material = null
		paper_sheet.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
		paper_shadow.visible = false
		for l in _paper_lines:
			(l as ColorRect).color = Color(0.6, 0.64, 0.82, 0.45)
		paper_foot.visible = true
		paper_hints.visible = false
		paper_page.visible = false
		transcript.visible = false
		paper_legend.label_settings = null
		_retro_label(paper_legend, Color(0.85, 0.82, 0.74), 4, Color(0, 0, 0, 0.9))
		paper_legend.add_theme_constant_override("line_spacing", 0)
		_place(paper_legend, Vector2(-290, 120), Vector2(580, 40))
	_layout_sheet(false)


## Feuille au centre ; transcription ouverte (style net) : la feuille glisse à gauche, le texte lisible à droite.
func _layout_sheet(animate := true) -> void:
	var show_t := net and transcript_on and paper_open and paper_text.visible and paper_text.text.strip_edges() != ""
	var sx := -215.0 if show_t else -95.0
	var from := paper_sheet.offset_left
	var set_x := func(x: float) -> void:
		_place(paper_sheet, Vector2(x, -132), SHEET)
		_place(paper_shadow, Vector2(x, -132), SHEET)
	if animate and paper.visible and not is_equal_approx(from, sx):
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(set_x, from, sx, 0.22)
	else:
		set_x.call(sx)
	paper_shadow.rotation = paper_sheet.rotation
	transcript.visible = show_t
	if show_t:
		transcript_lbl.text = paper_text.text
		transcript.reset_size()
		var h := transcript.get_combined_minimum_size().y
		_place(transcript, Vector2(4, -h / 2.0 - 8.0), Vector2(230, h))


func _update_paper_hints() -> void:
	if not net:
		return
	var h: Array = []
	var multi := not _pages.is_empty()
	var last := multi and _page_i >= _pages.size() - 1
	if multi and not last:
		h.append(["interact", "Page suivante"])
		h.append(["pause", "Reposer"])
	else:
		h.append([["interact", "pause"], "Reposer"])
	if paper_text.visible and paper_text.text.strip_edges() != "":
		h.append(["transcript", "Masquer la transcription" if transcript_on else "Transcription"])
	paper_hints.set_hints(h)
	paper_page.text = ("%d / %d" % [_page_i + 1, _pages.size()]) if multi else ""
	paper_page.visible = multi
	# la légende d'une feuille imprimée prend la place du numéro de page
	paper_hints.offset_top = -22
	paper_hints.offset_bottom = -22


## Un écran montré en grand (la console du bureau ; l'écran de la séquence ABSORBÉ) : E ou Échap pour
## fermer. Placement dans _layout_screen() : les pixels de l'écran restent nets.
func _build_screen_view() -> Control:
	var wrap := ColorRect.new()
	wrap.color = Color(0, 0, 0, 0.88)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_bezel = ColorRect.new()
	screen_bezel.color = Color(0.07, 0.07, 0.08)
	wrap.add_child(screen_bezel)
	screen_rect = TextureRect.new()
	screen_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen_rect.stretch_mode = TextureRect.STRETCH_SCALE
	wrap.add_child(screen_rect)
	screen_foot = _label(Color(0.7, 0.68, 0.6))
	screen_foot.text = "E OU ÉCHAP POUR FERMER"
	screen_foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	screen_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_foot.position = Vector2(-110, -20)
	screen_foot.size = Vector2(220, 20)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0.8)
	screen_foot.add_theme_stylebox_override("normal", fsb)
	wrap.add_child(screen_foot)
	screen_hints = KeyHints.new([[["interact", "pause"], "Fermer"]], UiStyle.SMALL)
	screen_hints.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_foot.add_child(screen_hints)
	return wrap


## Style net : le pied « E OU ÉCHAP POUR FERMER » devient une pastille [E] [Échap] Fermer (mêmes nœud et
## visibilité : B15 lit screen_foot.visible).
func _style_screen() -> void:
	if net:
		screen_foot.text = ""
		screen_foot.add_theme_stylebox_override("normal", UiStyle.box(Color(0, 0, 0, 0.72), 3))
		_place(screen_foot, Vector2(-52, -26), Vector2(104, 18))
		screen_hints.visible = true
	else:
		screen_foot.text = "E OU ÉCHAP POUR FERMER"
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(0, 0, 0, 0.8)
		screen_foot.add_theme_stylebox_override("normal", fsb)
		_place(screen_foot, Vector2(-110, -20), Vector2(220, 20))
		screen_hints.visible = false


## Taille et place de l'écran montré en grand. Un agrandissement non entier, sans lissage (le projet
## filtre « au plus proche »), fait sauter des colonnes de pixels : « CAM 1 » se lisait « CAM L ».
## Quand l'image tient au moins deux fois dans la vue, elle est agrandie d'un facteur entier (la
## console, 320 × 180, passe à × 2 : toute la vue) ; sinon elle remplit le cadre, lissée.
func _layout_screen() -> void:
	var tex := screen_rect.texture
	if tex == null:
		return
	var view := root.size if root.size.x > 1.0 else Vector2(640, 360)
	var ts := tex.get_size()
	if ts.x < 1.0 or ts.y < 1.0:
		return
	var k := floorf(minf(view.x / ts.x, view.y / ts.y))
	var sz: Vector2
	if k >= 2.0:
		sz = ts * k
		screen_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		screen_bezel.visible = false
	else:
		var fit := minf(576.0 / ts.x, 322.0 / ts.y)
		sz = (ts * fit).floor()
		screen_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if is_equal_approx(fit, roundf(fit)) \
			else CanvasItem.TEXTURE_FILTER_LINEAR
		screen_bezel.visible = true
	screen_rect.size = sz
	screen_rect.position = ((view - sz) / 2.0).floor()
	screen_bezel.size = sz + Vector2(12, 12)
	screen_bezel.position = screen_rect.position - Vector2(6, 6)
	# le pied « E OU ÉCHAP POUR FERMER » : sur un écran qui couvre le bas de la vue, il s'efface
	# au bout de 3 s (il cacherait le bandeau du bas de la console)
	if _screen_foot_tw:
		_screen_foot_tw.kill()
	screen_foot.modulate.a = 1.0
	if screen_rect.position.y + sz.y > view.y - 24.0:
		_screen_foot_tw = create_tween()
		_screen_foot_tw.tween_interval(3.0)
		_screen_foot_tw.tween_property(screen_foot, "modulate:a", 0.0, 0.8)


# ------------------------------------------------------------------ inventaire

## Inventaire : un panneau à droite, sur une colonne, ou sur deux quand il est bien rempli (il doit
## tenir dans les 360 px de haut).
func _build_inventory() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	inv_head = _inv_text()
	v.add_child(inv_head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	inv_list = _inv_text()
	row.add_child(inv_list)
	inv_list2 = _inv_text()
	row.add_child(inv_list2)
	_refresh_inventory.call_deferred()
	return panel


func _inv_text() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(INV_COL_W, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _style_inventory() -> void:
	if net:
		inv.add_theme_stylebox_override("panel", UiStyle.box(Color(0.03, 0.03, 0.035, 0.84), 4, UiStyle.LINE, 1, 14.0, 12.0))
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.02, 0.01, 0.94)
		sb.border_color = Color(GREEN, 0.5)
		sb.set_border_width_all(1)
		sb.set_content_margin_all(8)
		inv.add_theme_stylebox_override("panel", sb)
	for r in [inv_head, inv_list, inv_list2]:
		var rt := r as RichTextLabel
		if net:
			rt.add_theme_font_override("normal_font", UiStyle.sans())
			rt.add_theme_font_override("bold_font", UiStyle.tracked(UiStyle.sans_semi(), 2))
			rt.add_theme_font_override("italics_font", UiStyle.sans_it())
			rt.add_theme_font_size_override("normal_font_size", UiStyle.BODY)
			rt.add_theme_font_size_override("bold_font_size", UiStyle.TINY)
			rt.add_theme_font_size_override("italics_font_size", UiStyle.SMALL)
			rt.add_theme_color_override("default_color", UiStyle.INK)
			rt.add_theme_constant_override("line_separation", 1)
			rt.custom_minimum_size = Vector2(INV_COL_W_NET, 0)
		else:
			rt.add_theme_font_override("normal_font", UiStyle.pixel())
			rt.add_theme_font_override("bold_font", UiStyle.pixel())
			rt.add_theme_font_override("italics_font", UiStyle.pixel())
			rt.add_theme_font_size_override("normal_font_size", FONT)
			rt.add_theme_font_size_override("bold_font_size", FONT)
			rt.add_theme_font_size_override("italics_font_size", FONT)
			rt.add_theme_color_override("default_color", Color(0.8, 0.78, 0.7))
			rt.add_theme_constant_override("line_separation", -2)
			rt.custom_minimum_size = Vector2(INV_COL_W, 0)
	((inv_list.get_parent()) as HBoxContainer).add_theme_constant_override("separation", 22 if net else 16)


## Description d'un objet, en 10 px, sous son nom ; renvoie aussi sa hauteur estimée (px).
func _desc_line(desc: String, dim: String) -> Array:
	if net:
		var h := UiStyle.sans_it().get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, INV_COL_W_NET - 8, UiStyle.SMALL).y
		return ["[i][color=#%s]%s[/color][/i]\n" % [dim, _esc(desc)], int(ceil(h)) + 2]
	var chars_per_line := INV_COL_W / 4 - 2
	var n := maxi(1, ceili(float(desc.length() + 2) / chars_per_line))
	return ["[font_size=%d][color=#%s]  %s\n[/color][/font_size]" % [FONT_SMALL, dim, _esc(desc)], n * FONT_SMALL + 2]


func _refresh_inventory() -> void:
	if inv_head == null:
		return
	var g := GREEN.to_html(false)
	var dim := "a3ab9a"      # descriptions (10 px) : assez claires pour se lire
	var grey := "4a4f48"
	var line_h := FONT
	var gap_h := FONT_SMALL
	if net:
		g = UiStyle.ACCENT.to_html(false)
		dim = UiStyle.INK_DIM.to_html(false)
		grey = UiStyle.INK_FAINT.to_html(false)
		line_h = int(ceil(UiStyle.sans().get_height(UiStyle.BODY))) + 1
		gap_h = 8
		inv_head.text = "[b][color=#%s]INVENTAIRE[/color][/b]   [font_size=%d][color=#%s]%s[/color][/font_size]" % [
			UiStyle.INK.to_html(false), UiStyle.SMALL, dim, _esc(Controles.glyph("inventory", Game.pad_active))]
	else:
		inv_head.text = "[color=#%s]INVENTAIRE[/color]   [color=#%s][lb]Tab[rb][/color]" % [g, dim]
	var sections: Array = []      # [texte BBCode, hauteur estimée en px]
	if Game.items.is_empty():
		sections.append(["[color=#%s]Rien. Tes poches sont vides.[/color]" % dim, line_h])
	var titles := {"arme": "PIÈCES DE L'ARME", "outil": "OUTILS", "cle": "CLÉS", "doc": "DOCUMENTS", "objet": "OBJETS"}
	var head_fmt := "[b][color=#%s]%s[/color][/b]\n" if net else "[color=#%s]%s[/color]\n"
	var head_h := (int(ceil(UiStyle.sans_semi().get_height(UiStyle.TINY))) + 3) if net else FONT
	for kind in Game.KINDS:
		var t := ""
		var hh := 0
		if kind == "arme":
			if weapon_section_visible():
				t += head_fmt % [g, titles[kind]]
				hh += head_h
				t += ("[color=#%s]Croquis de Maman : %d/4[/color]\n" % [dim, weapon_count()]) if net else ("Croquis de Maman : %d/4\n" % weapon_count())
				hh += line_h
				for id in Game.WEAPON_PARTS:
					var it := _item(id)
					if it.is_empty():
						t += ("[color=#%s]–  %s[/color]\n" if net else "[color=#%s]· %s[/color]\n") % [grey, WEAPON_LABELS[id]]
						hh += line_h
					else:
						t += ("[color=#%s]✓[/color]  %s\n" % [g, _esc(it.name)]) if net else ("· %s\n" % _esc(it.name))
						hh += line_h
						if it.desc != "":
							var dl := _desc_line(it.desc, dim)
							t += dl[0]
							hh += dl[1]
			# autres objets de sorte « arme » (aucun en v0.3)
			for it in Game.items:
				if it.kind == "arme" and not Game.WEAPON_PARTS.has(it.id):
					t += "· %s\n" % _esc(it.name)
					hh += line_h
		else:
			for it in Game.items:
				if it.kind != kind:
					continue
				if t == "":
					t += head_fmt % [g, titles.get(kind, kind.to_upper())]
					hh += head_h
				t += ("%s\n" if net else "· %s\n") % _esc(it.name)
				hh += line_h
				if it.desc != "":
					var dl := _desc_line(it.desc, dim)
					t += dl[0]
					hh += dl[1]
		if t != "":
			sections.append([t, hh])
	# une colonne si ça tient, sinon deux (les sections dans l'ordre, la coupure au plus près du milieu)
	var total := 0
	for sc in sections:
		total += int(sc[1]) + gap_h
	var col1 := ""
	var col2 := ""
	var h1 := 0
	for sc in sections:
		var into_first: bool = total <= INV_MAX_H or col1 == "" or (col2 == "" and h1 + int(sc[1]) / 2 <= total / 2)
		var gap := "[font_size=%d]\n[/font_size]" % gap_h     # entre deux sections
		if into_first:
			col1 += (gap if col1 != "" else "") + str(sc[0])
			h1 += int(sc[1]) + gap_h
		else:
			col2 += (gap if col2 != "" else "") + str(sc[0])
	inv_list.text = _trim_end(col1)
	inv_list2.text = _trim_end(col2)
	inv_list2.visible = col2 != ""
	if inv:
		_place_inventory.call_deferred()


## Retire le dernier saut de ligne d'une colonne (il est parfois dans les balises de la description).
static func _trim_end(t: String) -> String:
	if t.ends_with("\n"):
		return t.left(-1)
	var tail := "\n[/color][/font_size]"
	if t.ends_with(tail):
		return t.left(-tail.length()) + "[/color][/font_size]"
	return t


## Le panneau, collé au bord droit, centré en hauteur.
func _place_inventory() -> void:
	if inv == null:
		return
	inv.reset_size()
	var area: Vector2 = root.size if root.size.x > 0.0 else Vector2(640, 360)
	# sous l'objectif (deux lignes en haut à gauche) quand la place le permet
	var y := maxf(48.0, (area.y - inv.size.y) / 2.0)
	if y + inv.size.y > area.y - 4.0:
		y = maxf(4.0, area.y - 4.0 - inv.size.y)
	inv.position = Vector2(area.x - inv.size.x - (18.0 if net else 10.0), y)


func _item(id: String) -> Dictionary:
	for it in Game.items:
		if it.id == id:
			return it
	return {}


## Nombre de pièces de l'arme ramassées (sur les quatre du croquis).
func weapon_count() -> int:
	var n := 0
	for id in Game.WEAPON_PARTS:
		if Game.has_item(id):
			n += 1
	return n


## La section « Pièces de l'arme » apparaît dès qu'on a vu le croquis (journal, impression) ou une pièce.
func weapon_section_visible() -> bool:
	return weapon_count() > 0 or Game.has_item("journal_manon") or Game.has_item("croquis_imprime") or bool(Game.flag("croquis_lu"))


## Échappe les crochets pour le BBCode.
static func _esc(s: String) -> String:
	var out := ""
	for ch in s:
		if ch == "[":
			out += "[lb]"
		elif ch == "]":
			out += "[rb]"
		else:
			out += ch
	return out


func toggle_inventory() -> void:
	inv_open = not inv_open
	if net:
		if inv_open:
			inv.visible = true
			inv.modulate.a = 0.0
			create_tween().tween_property(inv, "modulate:a", 1.0, 0.16)
			_obj_t = 0.0
		else:
			inv.visible = false
		if _prompt_on:
			_fade_prompt(not inv_open)
	else:
		inv.visible = inv_open
	if inv_open:
		_refresh_inventory()
		_place_inventory.call_deferred()
		# l'inventaire ouvert dit déjà ce qu'on vient de ramasser : pas de bandeau par-dessus
		if _toast_tw:
			_toast_tw.kill()
		toast.modulate.a = 0.0
	Sfx.play("cloth", -14.0, 1.2)


func _on_item_added(_id: String, label: String) -> void:
	_obj_idle = 0.0
	toast.text = "+ " + label
	if _toast_tw:
		_toast_tw.kill()
	if inv_open:
		toast.modulate.a = 0.0
		return
	toast.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.6)
	_toast_tw.tween_property(toast, "modulate:a", 0.0, 0.8)


# ------------------------------------------------------------------ pensées, boucle

func show_hint(text: String, seconds := 3.5) -> void:
	hint_lbl.text = text
	_hint_left = seconds
	create_tween().tween_property(hint_lbl, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	if player and _prompt_on and player.current:
		if net:
			if prompt.text != player.current.label:
				prompt.text = player.current.label
				prompt_pill.reset_size()
		else:
			prompt.text = "[%s] %s" % [Controles.glyph("interact", Game.pad_active), player.current.label]
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0:
			create_tween().tween_property(hint_lbl, "modulate:a", 0.0, 0.6)
	_process_objective(delta)
	if save_ind.visible:
		_save_spin = fmod(_save_spin + delta * 5.0, TAU)
		save_ind.queue_redraw()
	# sous-titres : la ligne courante, puis la suivante de la file
	if current_subtitle != "":
		_sub_left -= delta
		if _sub_left <= 0.0:
			_next_subtitle()
	if current_caption != "":
		_snd_left -= delta
		if _snd_left <= 0.0:
			_end_caption()
	if sub_lbl.visible or snd_lbl.visible:
		# au-dessus de la pensée du héros quand elle est affichée (1 à 3 lignes)
		var above := hint_lbl.modulate.a > 0.05 and hint_lbl.text != ""
		var hint_h := 0.0
		if above:
			var n := clampi(hint_lbl.get_line_count(), 1, 3)
			# (au moins 20 px par ligne : la mesure de l'autotest compte ainsi)
			hint_h = maxf(n * _lh_hint + 6.0, n * 20.0 - 2.0) if net else n * float(FONT) + 6.0
		sub_lbl.offset_bottom = -_bot - hint_h
		# la boîte du dialogue a la hauteur de son texte (une ligne ou deux) : le texte, dessiné en haut
		# de la boîte, touche ainsi le bas, et le son posé juste au-dessus ne le chevauche jamais
		var sub_h := float(sub_lbl.get_content_height())
		if sub_h < _lh_sub:
			sub_h = clampi(sub_lbl.get_line_count(), 1, 3) * _lh_sub
		sub_lbl.offset_top = sub_lbl.offset_bottom - sub_h
		# le son, au-dessus du dialogue (s'il y en a un), sinon à sa place
		var sb := sub_lbl.offset_bottom
		if sub_lbl.visible and sub_lbl.modulate.a > 0.05:
			sb -= sub_h + (5.0 if net else 2.0)
		snd_lbl.offset_bottom = sb
		snd_lbl.offset_top = sb - 2.0 * _lh_snd
		var o := caption_overlap()
		if o > -INF:
			caption_both += 1
			caption_overlap_max = maxf(caption_overlap_max, o)
	if net:
		sub_bg.refresh()
		snd_bg.refresh()
		hint_bg.refresh()
	elif sub_bg.visible or snd_bg.visible or hint_bg.visible:
		sub_bg.visible = false
		snd_bg.visible = false
		hint_bg.visible = false


# ------------------------------------------------------------------ sous-titres

## Sous-titre « qui : texte », coloré selon le locuteur (kind : "elle", "proche", "son", "autre" ;
## vide = deviné d'après « who »). Durée : 2 s + 0,06 s par caractère ; les lignes attendent leur tour.
## on_show est appelé quand la ligne s'affiche. Renvoie le temps (s) jusqu'à la fin de cette ligne.
func subtitle(who: String, text: String, kind := "", on_show := Callable()) -> float:
	if kind == "":
		kind = speaker_kind(who)
	var dur := 2.0 + 0.06 * text.length()
	var wait := maxf(_sub_left, 0.0) if current_subtitle != "" else 0.0
	for q in _sub_queue:
		wait += float(q.dur)
	_sub_queue.append({"who": who, "text": text, "kind": kind, "dur": dur, "cb": on_show})
	if current_subtitle == "":
		_next_subtitle()
	return wait + dur


## Sous-titre d'un son important (C5), entre crochets et en gris, seulement si l'option « Sous-titres
## des sons » est active (force = true : toujours ; réservé aux captures de test). Il s'affiche tout de
## suite, sur sa propre ligne au-dessus du dialogue en cours (il n'attend pas dans la file des
## dialogues) ; le même son déjà affiché est seulement prolongé. Durée : 2 s + 0,06 s par caractère.
## Renvoie sa durée (0 s'il n'est pas affiché).
func sound_caption(text: String, force := false) -> float:
	if not Game.sound_captions and not force:
		return 0.0
	var t := text if text.begins_with("[") else "[" + text + "]"
	var dur := 2.0 + 0.06 * t.length()
	if _snd_tw:
		_snd_tw.kill()
	snd_lbl.modulate.a = 1.0
	snd_lbl.visible = true
	if t == current_caption:
		_snd_left = maxf(_snd_left, dur)
		return dur
	snd_lbl.text = t
	current_caption = t
	_snd_left = dur
	caption_log.append({"text": t, "t": snappedf(Time.get_ticks_msec() / 1000.0, 0.01)})
	subtitle_log.append({"who": "", "text": t, "kind": "son"})
	subtitle_shown.emit("", t)
	sound_captioned.emit(t)
	return dur


func _end_caption() -> void:
	current_caption = ""
	_snd_left = 0.0
	_snd_tw = create_tween()
	_snd_tw.tween_property(snd_lbl, "modulate:a", 0.0, 0.25)
	_snd_tw.tween_callback(func() -> void:
		if current_caption == "":
			snd_lbl.visible = false)


## Le son et le dialogue sont-ils affichés ensemble ? Renvoie alors de combien de pixels le bas du
## texte du son descend sous le haut du texte du dialogue (> 0 : ils se chevauchent ; le son est
## aligné en bas de sa boîte, le dialogue en haut de la sienne) ; sinon −INF. (C5, autotest.)
func caption_overlap() -> float:
	if not (sub_lbl.visible and snd_lbl.visible and sub_lbl.modulate.a > 0.05 and snd_lbl.modulate.a > 0.05):
		return -INF
	if current_subtitle == "" or current_caption == "":
		return -INF
	return snd_lbl.get_global_rect().end.y - sub_lbl.get_global_rect().position.y


## Un dialogue (l'entité, une voix imitée, un autre locuteur) est-il affiché ? (Sfx range le cœur
## dessous.) Les sous-titres de sons ne comptent pas.
func dialogue_on() -> bool:
	return current_subtitle != "" and current_kind != "son"


static func speaker_kind(who: String) -> String:
	var w := who.to_lower()
	if w == "":
		return "son"
	for n in PROCHE_NAMES:
		if w.contains(n):
			return "proche"
	for n in ENTITY_NAMES:
		if w.begins_with(n):
			return "elle"
	return "autre"


func _next_subtitle() -> void:
	if _sub_queue.is_empty():
		current_subtitle = ""
		current_kind = ""
		_sub_left = 0.0
		_sub_cur = {}
		var tw := create_tween()
		tw.tween_property(sub_lbl, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void:
			if current_subtitle == "":
				sub_lbl.visible = false)
		return
	var q: Dictionary = _sub_queue.pop_front()
	_sub_cur = q
	_show_sub_line(q)
	sub_lbl.visible = true
	sub_lbl.modulate.a = 1.0
	current_subtitle = q.text
	current_kind = q.kind
	_sub_left = q.dur
	subtitle_log.append({"who": q.who, "text": q.text, "kind": q.kind})
	subtitle_shown.emit(q.who, q.text)
	var cb: Callable = q.cb
	if cb.is_valid():
		cb.call()


## Le texte BBCode d'une ligne : rétro, tout en couleur du locuteur ; net, le nom en couleur (demi-gras), la
## réplique en blanc cassé (un son reste gris).
func _show_sub_line(q: Dictionary) -> void:
	var body := ""
	if net:
		var cn: Color = UiStyle.SPEAKER.get(q.kind, UiStyle.SPEAKER.autre)
		var ct: Color = UiStyle.SPEAKER.son if q.kind == "son" else UiStyle.INK
		body = "[color=#%s]%s[/color]" % [ct.to_html(false), _esc(q.text)]
		if q.who != "":
			body = "[b][color=#%s]%s :[/color][/b] %s" % [cn.to_html(false), _esc(q.who), body]
	else:
		var c: Color = SUB_COLORS.get(q.kind, SUB_COLORS.autre)
		body = "[color=#%s]%s[/color]" % [c.to_html(false), _esc(q.text)]
		if q.who != "":
			var cw := c.darkened(0.25) if q.kind != "son" else c
			body = "[color=#%s]%s :[/color] %s" % [cw.to_html(false), _esc(q.who), body]
	sub_lbl.text = "[center]%s[/center]" % body


## Efface les sous-titres (la ligne courante et la file, et le son affiché).
func clear_subtitles() -> void:
	_sub_queue.clear()
	current_subtitle = ""
	current_kind = ""
	_sub_left = 0.0
	_sub_cur = {}
	sub_lbl.visible = false
	current_caption = ""
	_snd_left = 0.0
	snd_lbl.visible = false


## Lecture en cours (papier, image, écran) : pas d'indice, pas de déplacement.
func is_reading() -> bool:
	return paper_open or screen_open


# ------------------------------------------------------------------ lecture

## Carnet de plusieurs pages : E pour tourner la page.
func read_pages(pages: Array, font_size := 21) -> void:
	_pages = pages
	_page_i = 0
	_paper_fs = font_size
	read_paper(pages[0])
	paper_foot.text = "E : PAGE SUIVANTE (1/%d)" % pages.size()
	_update_paper_hints()


func _next_page() -> void:
	_page_i += 1
	if _page_i >= _pages.size():
		_pages = []
		_paper_fs = 26
		close_paper()
		return
	paper_text.text = _pages[_page_i]
	_fit_paper_text()
	Sfx.play("bookFlip1", -10.0)
	paper_foot.text = ("E : PAGE SUIVANTE (%d/%d)" if _page_i < _pages.size() - 1 else "E OU ÉCHAP POUR REPOSER (%d/%d)") % [_page_i + 1, _pages.size()]
	_update_paper_hints()
	if transcript.visible:
		_layout_sheet(false)


func read_paper(text: String) -> void:
	_paper_mode_image(false)
	if _pages.is_empty():
		_paper_fs = 26
	paper_text.text = text
	_fit_paper_text()
	if _pages.is_empty():
		paper_foot.text = "E OU ÉCHAP POUR REPOSER"
	paper.visible = true
	paper_open = true
	prompt.visible = net
	if net:
		_fade_prompt(false)
	transcript_on = Game.transcript_always
	_update_paper_hints()
	_layout_sheet(false)
	if net:
		paper.modulate.a = 0.0
		create_tween().tween_property(paper, "modulate:a", 1.0, 0.18)
	if player:
		player.can_move = false
		player.can_look = false
	Sfx.play("bookOpen", -10.0)


## Feuille imprimée : l'image sur la feuille, la légende (pensée du héros) dessous.
func read_image(texture: Texture2D, legend := "") -> void:
	_pages = []
	read_paper("")
	_paper_mode_image(true)
	paper_image.texture = texture
	paper_legend.text = legend
	paper_legend.visible = legend != ""
	_update_paper_hints()
	_layout_sheet(false)
	if net and legend != "":
		paper_hints.offset_top = -16
		paper_hints.offset_bottom = -16


## L'écriture garde sa taille (_paper_fs) si la page tient sur la feuille, sinon elle rapetisse.
func _fit_paper_text() -> void:
	var f: Font = paper_text.get_theme_font("font")
	var ls := paper_text.get_theme_constant("line_spacing")
	var fs := _paper_fs
	while true:
		paper_text.add_theme_font_size_override("font_size", fs)
		if fs <= 14 or paper_text.get_line_count() * (f.get_height(fs) + ls) <= PAPER_TEXT_H:
			break
		fs -= 1


func _paper_mode_image(on: bool) -> void:
	paper_image.visible = on
	paper_text.visible = not on
	for l in _paper_lines:
		l.visible = not on
	if not on:
		paper_legend.visible = false


func close_paper() -> void:
	_pages = []
	_paper_fs = 26
	paper_text.add_theme_font_size_override("font_size", 26)
	_paper_mode_image(false)
	paper.visible = false
	paper_open = false
	transcript.visible = false
	if player:
		player.can_move = true
		player.can_look = true
	if net and _prompt_on:
		_fade_prompt(true)
	Sfx.play("bookClose", -12.0)


## Transcription lisible (style net) : T (ou X à la manette) pendant la lecture.
func toggle_transcript() -> void:
	if not paper_open or not net:
		return
	transcript_on = not transcript_on
	_layout_sheet(true)
	_update_paper_hints()
	_ui_click()


func _ui_click() -> void:
	var st: AudioStream = Sfx.call("_stream", "metalClick") if Sfx.has_method("_stream") else null
	if st == null:
		return
	_ui_player.stream = st
	_ui_player.volume_db = -20.0
	_ui_player.pitch_scale = 1.8
	_ui_player.play()


## Montre un écran en grand (la console et ses caméras) ; E ou Échap pour fermer.
## closable = false (séquence ABSORBÉ hors séance) : pas de pied, E et Échap ne font rien ; seul le
## scénario le referme (close_screen).
func show_screen(texture: Texture2D, closable := true) -> void:
	screen_rect.texture = texture
	screen_locked = not closable
	screen_foot.visible = closable
	screen_view.visible = true
	screen_open = true
	if net:
		_fade_prompt(false)
	else:
		prompt.visible = false
	_layout_screen()
	if player:
		player.can_move = false
		player.can_look = false
	Sfx.play("metalClick", -18.0, 1.6)


func close_screen() -> void:
	if not screen_open:
		return
	screen_view.visible = false
	screen_open = false
	screen_locked = false
	screen_rect.texture = null
	if player:
		player.can_move = true
		player.can_look = true
	if net and _prompt_on:
		_fade_prompt(true)
	screen_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if screen_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		if not screen_locked:
			close_screen()
		return
	if paper_open and event.is_action_pressed("transcript"):
		get_viewport().set_input_as_handled()
		toggle_transcript()
	elif paper_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if not _pages.is_empty():
			_next_page()
		else:
			close_paper()
	elif event.is_action_pressed("inventory") and Game.phase == "room" and not get_tree().paused:
		get_viewport().set_input_as_handled()
		toggle_inventory()


func fade_to(alpha: float, seconds := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, seconds)
	await tw.finished


## Carton de texte sur fond noir (épilogue, fin d'acte). Le fondu doit déjà être au noir.
func card(lines: Array, seconds := 5.0) -> void:
	var l := Label.new()
	l.text = "\n".join(lines)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.offset_left = 60
	l.offset_right = -60
	if net:
		UiStyle.apply_label(l, UiStyle.sans(), UiStyle.SUB, UiStyle.INK, false)
		l.label_settings.line_spacing = 6.0
		l.offset_left = 120
		l.offset_right = -120
	else:
		l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
		l.add_theme_constant_override("line_spacing", 4)
	l.modulate.a = 0.0
	root.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 1.2)
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	await tw.finished
	l.queue_free()
