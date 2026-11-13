class_name HouseConsole
extends Connected
## La console domotique : l'écran du PC moderne du bureau (Device réutilisé par composition,
## 320 × 180). En haut « CONSOLE DOMOTIQUE · 03:2x » ; quatre vignettes de 150 × 74 (CAM 1 COULOIR,
## CAM 2 JARDIN, CAM 3 CHAMBRE 1, CAM 4 ENTRÉE « PAS DE SIGNAL ») ; en bas, ses lignes et
## « PEUR MESURÉE : n % ». Les caméras ne tournent que si le bureau est la pièce active
## (FeedCam.viewer_rooms = ["bureau"]) et que la console est allumée.
## Repère : le nœud est au centre de la dalle, l'écran regarde vers +Z.

const RES := Vector2i(320, 180)
const THUMB := Vector2(150, 74)
const GREEN := Color(0.4, 1.0, 0.5)
const LINE_W := 214.0           # ses phrases, à gauche du bandeau du bas (à droite : la jauge)

var screen_size := Vector2(0.5, 0.3)
var screen: Device
var titles := ["CAM 1 COULOIR", "CAM 2 JARDIN", "CAM 3 CHAMBRE 1", "CAM 4 ENTRÉE"]
var feeds: Array = [null, null, null, null]     # FeedCam (ou null : « PAS DE SIGNAL »)
var booted := false
var booting := false
var fan_pos := Vector3.INF      # où jouer les ventilateurs (la tour) ; par défaut, l'écran
var last_line := ""

var ui: Control
var boot_lbl: Label
var top_lbl: Label
var peur_lbl: Label
var line_lbl: Label
var line_panel: PanelContainer
var _slots: Array[Control] = []
var _clock_t := 0.0


func build() -> void:
	if display_name == "":
		display_name = "Console"
	can_speak = true
	screen = Device.new()
	screen.name = "Ecran"
	screen.kind = "console"
	screen.screen_size = screen_size
	screen.res = RES
	screen.curvature = 0.0
	screen.glow_color = Color(0.72, 0.8, 1.0)
	screen.glow_energy = 0.55
	screen.glow_range = 3.0
	add_child(screen)
	screen.position = Vector3(0, 0, 0.002)
	screen.build()
	screen.say("")
	screen.mat.set_shader_parameter("brightness", 1.0)
	screen.mat.set_shader_parameter("tint", Color(0.92, 0.96, 1.0))
	screen.light.shadow_enabled = false
	for mi in screen.find_children("*", "MeshInstance3D", false, false):
		no_gi(mi as MeshInstance3D)
	_build_ui()
	# voyant d'alimentation, sous la dalle
	make_led(Vector3(screen_size.x / 2.0 - 0.025, -screen_size.y / 2.0 - 0.012, 0.004), 0.0025, false, Color(1.0, 0.55, 0.1))
	Game.peur_changed.connect(func(_v: float) -> void: _update_peur())
	built = true


func _label(fs: int, c := Color(0.85, 0.9, 0.86)) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Game.fonts.pixel)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	ui = Control.new()
	ui.name = "Interface"
	ui.size = Vector2(RES)
	ui.visible = false
	screen.vp.add_child(ui)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.03)
	bg.size = Vector2(RES)
	ui.add_child(bg)
	# bandeau du haut
	var band := ColorRect.new()
	band.color = Color(0.09, 0.13, 0.2)
	band.size = Vector2(RES.x, 12)
	ui.add_child(band)
	top_lbl = _label(10, Color(0.78, 0.86, 1.0))
	top_lbl.position = Vector2(5, 0)
	ui.add_child(top_lbl)
	var dot := ColorRect.new()
	dot.color = GREEN
	dot.size = Vector2(4, 4)
	dot.position = Vector2(RES.x - 9, 4)
	ui.add_child(dot)
	# quatre emplacements de vignettes (2 × 2)
	for i in 4:
		var slot := Control.new()
		slot.name = "Vignette%d" % (i + 1)
		slot.position = Vector2(6 + (i % 2) * (THUMB.x + 8), 14 + (i / 2) * (THUMB.y + 2))
		slot.size = THUMB
		slot.clip_contents = true
		ui.add_child(slot)
		_slots.append(slot)
		_fill_slot(i)
	# bandeau du bas : ses lignes, et la jauge
	var bottom := ColorRect.new()
	bottom.color = Color(0.0, 0.0, 0.0)
	bottom.position = Vector2(0, 165)
	bottom.size = Vector2(RES.x, 15)
	ui.add_child(bottom)
	peur_lbl = _label(10, Color(1.0, 0.75, 0.3))
	peur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	peur_lbl.position = Vector2(LINE_W, 167)
	peur_lbl.size = Vector2(RES.x - LINE_W - 5, 14)
	ui.add_child(peur_lbl)
	# ses phrases : une ligne au-dessus du bandeau, qui grandit vers le haut si elle est longue
	line_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.82)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	line_panel.add_theme_stylebox_override("panel", sb)
	line_panel.position = Vector2(0, 165)
	line_panel.size = Vector2(LINE_W, 15)
	line_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	line_panel.visible = false
	ui.add_child(line_panel)
	line_lbl = _label(20, GREEN)
	line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_lbl.custom_minimum_size = Vector2(LINE_W - 8, 0)
	line_lbl.add_theme_constant_override("line_spacing", -5)
	line_panel.add_child(line_lbl)
	# texte du démarrage
	boot_lbl = _label(20, Color(0.75, 0.82, 0.95))
	boot_lbl.position = Vector2(8, 6)
	boot_lbl.size = Vector2(RES.x - 16, RES.y - 12)
	boot_lbl.add_theme_constant_override("line_spacing", -4)
	boot_lbl.visible = false
	screen.vp.add_child(boot_lbl)
	_update_peur()
	_update_clock()


func _fill_slot(i: int) -> void:
	if _slots.size() <= i:
		return
	var slot := _slots[i]
	for c in slot.get_children():
		c.queue_free()
	var cam: FeedCam = feeds[i]
	var view: Control
	if cam:
		cam.title = titles[i]
		view = cam.make_view(THUMB)
	else:
		view = FeedCam.make_no_signal_view(THUMB, titles[i])
	slot.add_child(view)
	# liseré
	var frame := ReferenceRect.new()
	frame.border_color = Color(0.3, 0.4, 0.55, 0.9)
	frame.border_width = 1.0
	frame.editor_only = false
	frame.size = THUMB
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(frame)


## Branche une caméra sur la vignette i (0 à 3) ; null = « PAS DE SIGNAL ».
func set_feed(i: int, cam: FeedCam, cam_title := "") -> void:
	if cam_title != "":
		titles[i] = cam_title
	feeds[i] = cam
	if cam:
		if not cam.viewer_rooms.has(room_id) and room_id != "":
			cam.viewer_rooms.append(room_id)
		var h: Haunt = Haunt.of(get_tree()) if is_inside_tree() else null
		if h and h.room_id != "":
			cam.set_room(h.room_id)
		cam.set_wanted(booted)
	if built:
		_fill_slot(i)


func set_feeds(cams: Array) -> void:
	for i in mini(cams.size(), 4):
		set_feed(i, cams[i])


## Démarrage : ventilateurs, écran, quelques lignes système, puis les quatre caméras (moins de 3 s).
func boot() -> void:
	if booted or booting:
		return
	booting = true
	var at := fan_pos if fan_pos != Vector3.INF else speak_pos()
	Sfx.play_at("fans_spinup", at, -8.0, 1.0, 2.0)
	led(Color(0.2, 0.6, 1.0))
	screen.power_on("", 0.3)
	boot_lbl.visible = true
	boot_lbl.text = ""
	for l in ["DOMOBOX OS 7.4 · DÉMARRAGE", "MÉMOIRE ............ OK", "RÉSEAU 4G .......... OK",
			"TÉLÉASSISTANCE ..... OK", "CAMÉRAS ............ 3/4"]:
		boot_lbl.text += l + "\n"
		Sfx.play_at("metalClick", speak_pos(), -26.0, 2.2, 1.2)
		await get_tree().create_timer(0.22, false).timeout
		if not is_inside_tree():
			return
	await get_tree().create_timer(0.3, false).timeout
	boot_lbl.visible = false
	ui.visible = true
	booted = true
	booting = false
	for cam in feeds:
		if cam:
			(cam as FeedCam).set_wanted(true)
	_update_peur()


## Éteint l'écran ; les caméras s'arrêtent.
func power_off() -> void:
	screen.power_off()
	ui.visible = false
	boot_lbl.visible = false
	booted = false
	led(Color(1.0, 0.55, 0.1))
	for cam in feeds:
		if cam:
			(cam as FeedCam).set_wanted(false)


## Une de ses lignes dans le bandeau du bas (vide = efface).
func show_line(text: String) -> void:
	last_line = text
	line_lbl.text = text
	line_panel.visible = text != ""
	line_panel.reset_size()
	line_panel.size.x = LINE_W
	line_panel.position.y = RES.y - line_panel.size.y


func speak(text: String, seconds: float) -> void:
	super.speak(text, seconds)
	if booted:
		show_line(text)


## Image de l'écran (pour l'afficher en grand dans le HUD : hud.show_screen(console.screen_texture())).
func screen_texture() -> Texture2D:
	return screen.vp.get_texture()


func speak_pos() -> Vector3:
	return global_position


func _update_peur() -> void:
	if peur_lbl:
		peur_lbl.text = "PEUR MESURÉE : %d %%" % int(Game.peur)
		peur_lbl.add_theme_color_override("font_color", Game.peur_color())


func _update_clock() -> void:
	if top_lbl:
		top_lbl.text = "CONSOLE DOMOTIQUE · " + Game.house_clock()


func _process(delta: float) -> void:
	_clock_t -= delta
	if _clock_t <= 0.0:
		_clock_t = 1.0
		_update_clock()
