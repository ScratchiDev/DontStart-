class_name Printer
extends Connected
## L'imprimante du bureau (jet d'encre, 0,42 × 0,2 × 0,35) : elle imprime ce que l'entité veut
## (plan, croquis, photo du couloir). La feuille sort par à-coups d'une fente à l'arrière du dessus et
## se pose dans le bac creusé sur le dessus (rien ne dépasse du meuble), puis on peut la ramasser :
## elle devient un objet « doc » de l'inventaire et s'affiche dans le lecteur de papiers.
## Repère : le nœud est sous l'imprimante, au centre (posé sur le meuble) ; la sortie regarde +Z.

signal page_printed(id: String)
signal page_taken(id: String)

## Pages connues (§ 5.4 et § 5.6.4 de la spécification) : nom, description, légende à la lecture.
## « 03:2x » est remplacé par l'heure de la maison au moment de l'impression.
const PAGES := {
	"plan_imprime": {"name": "Plan de l'étage", "desc": "Imprimé par elle. La salle de bain est entourée.",
		"legend": "Le plan de l'étage. La salle de bain est entourée. En dessous : PROTOCOLE 4."},
	"croquis_imprime": {"name": "Croquis du Fractionneur", "desc": "Imprimé par elle. « Construis-le. Je veux voir. »",
		"legend": "Le croquis de ta mère, plus net que dans le journal. En bas, imprimé : « Construis-le. Je veux voir. »"},
	"photo_couloir": {"name": "Photo du couloir, 03:2x", "desc": "Le couloir vide. Juste le rond de ta lampe.",
		"legend": "CAM 1, 03:2x. Le couloir, vide. Juste le rond de ta lampe. C'est toi."},
}
const SHEET := Vector2(0.21, 0.297)     # A4, posée à plat : x = largeur, y = longueur (vers +Z)

var body_size := Vector3(0.42, 0.2, 0.35)
var printing := false
var sheets: Array = []                  # feuilles sorties et pas encore ramassées : [{id, node, it}]
var printed: Array = []                 # identifiants imprimés (autotest)
var _queue: Array = []


func build() -> void:
	if display_name == "":
		display_name = "Imprimante"
	var w := body_size.x
	var h := body_size.y
	var d := body_size.z
	var shell := plain_mat(Color(0.74, 0.74, 0.72), 0.45)
	var dark := plain_mat(Color(0.12, 0.12, 0.13), 0.5)
	var tray := plain_mat(Color(0.3, 0.3, 0.31), 0.55)
	var top_y := _top_y()
	var hump := _hump_d()
	# corps ; à l'arrière du dessus, le capot du chemin du papier, d'où sortent les feuilles
	add_box(Vector3(w, top_y, d), Vector3(0, top_y / 2.0, 0), shell)
	add_box(Vector3(w, h - top_y, hump), Vector3(0, (top_y + h) / 2.0, -d / 2.0 + hump / 2.0), shell)
	add_box(Vector3(SHEET.x + 0.02, 0.007, 0.004), Vector3(0, top_y + 0.009, -d / 2.0 + hump + 0.0015), dark)
	# bac de sortie, creusé dans le dessus : les feuilles s'y posent, face imprimée vers le haut
	add_box(Vector3(SHEET.x + 0.03, 0.002, d - hump - 0.012), Vector3(0, top_y + 0.001, (hump - 0.012) / 2.0), tray)
	# cassette à papier en façade, avec sa poignée
	add_box(Vector3(w * 0.84, h * 0.34, 0.004), Vector3(0, h * 0.21, d / 2.0 + 0.002), plain_mat(Color(0.68, 0.68, 0.66), 0.5))
	add_box(Vector3(0.09, 0.008, 0.006), Vector3(0, h * 0.3, d / 2.0 + 0.004), dark)
	# panneau de commande, à droite du bac : deux boutons et le voyant
	var px := w / 2.0 - 0.05
	var pz := d / 2.0 - 0.045
	add_box(Vector3(0.07, 0.004, 0.06), Vector3(px, top_y + 0.002, pz), dark)
	for i in 2:
		add_mesh(cyl(0.006, 0.006, 0.004, 10), Vector3(px - 0.012 + i * 0.024, top_y + 0.005, pz + 0.01), plain_mat(Color(0.6, 0.6, 0.58), 0.4))
	make_led(Vector3(px, top_y + 0.0055, pz - 0.016), 0.004, false, Color(0.2, 1.0, 0.3))
	led_energy = 2.0
	led(Color(0.2, 1.0, 0.3))
	built = true


## Hauteur du dessus (le bac de sortie) et profondeur du capot arrière : la feuille finit avec son
## bord avant 2,5 cm devant la façade, à 2 cm au-dessus de l'imprimante (§ 5.2 : sortie en haut + 0.22).
func _top_y() -> float:
	return body_size.y * 0.84


func _hump_d() -> float:
	return body_size.z / 2.0 + _slot_z()


## Fente de sortie (z local) : la feuille entière, posée, va de là jusqu'à 2,5 cm devant la façade.
func _slot_z() -> float:
	return body_size.z / 2.0 + 0.025 - SHEET.y


## Sortie des feuilles (globale) : le bord avant de la feuille posée, en haut de la façade.
func out_pos() -> Vector3:
	return to_global(Vector3(0, body_size.y + 0.02, body_size.z / 2.0 + 0.025))


## Imprime une page : la feuille sort, puis devient ramassable. id = objet ajouté à l'inventaire
## (sorte « doc ») ; texture = ce qui est imprimé ; label = nom de l'objet (sinon celui de PAGES).
## desc, legend : description dans l'inventaire et texte affiché sous l'image à la lecture.
## instant : la feuille est posée tout de suite, sans bruit (chargement d'une sauvegarde).
func print_page(id: String, texture: Texture2D, label := "", desc := "", legend := "", instant := false) -> void:
	var known: Dictionary = PAGES.get(id, {})
	var clock := Game.house_clock()
	var page := {
		"id": id, "texture": texture,
		"name": (label if label != "" else str(known.get("name", id))).replace("03:2x", clock),
		"desc": (desc if desc != "" else str(known.get("desc", ""))).replace("03:2x", clock),
		"legend": (legend if legend != "" else str(known.get("legend", ""))).replace("03:2x", clock),
		"instant": instant,
	}
	_queue.append(page)
	if printing:
		return
	printing = true
	while not _queue.is_empty():
		var p: Dictionary = _queue.pop_front()
		await _print_one(p)
		if not is_inside_tree():
			return
	printing = false


## La page imprimée : une image en hauteur (plan, croquis) occupe la feuille ; une image en largeur
## (photo d'une caméra) est posée en haut d'une feuille blanche, avec ses marges.
static func page_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.is_compressed():
		img.decompress()
	if float(img.get_width()) / img.get_height() <= 0.85:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	var pw := 420
	var ph := 594
	var page := Image.create(pw, ph, false, Image.FORMAT_RGBA8)
	page.fill(Color(0.96, 0.95, 0.92))
	var iw := 360
	var ih := int(iw * float(img.get_height()) / img.get_width())
	var small := img.get_width() < iw
	img.resize(iw, ih, Image.INTERPOLATE_NEAREST if small else Image.INTERPOLATE_BILINEAR)
	page.fill_rect(Rect2i(29, 39, iw + 2, ih + 2), Color(0.55, 0.55, 0.55))
	page.blit_rect(img, Rect2i(0, 0, iw, ih), Vector2i(30, 40))
	# quelques lignes grises sous la photo (le pied de page de l'impression)
	for k in 3:
		page.fill_rect(Rect2i(30, 40 + ih + 18 + k * 12, 200 - k * 50, 3), Color(0.7, 0.7, 0.68))
	return ImageTexture.create_from_image(page)


func _print_one(p: Dictionary) -> void:
	var tex: Texture2D = page_texture(p.texture)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(0.97, 0.96, 0.93)
	m.roughness = 0.92
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var holder := Node3D.new()
	holder.name = "Feuille_" + str(p.id)
	add_child(holder)
	var q := QuadMesh.new()
	q.size = Vector2(SHEET.x, 0.001)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.rotation.x = -PI / 2.0   # à plat, image lisible depuis l'avant (le haut de la page vers l'imprimante)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	var slot := _slot_z()
	var land_y := _top_y() + 0.0035 + sheets.size() * 0.0012
	holder.position = Vector3(0, land_y + 0.005, 0)
	# seule la partie sortie de la fente est visible : le bas de la page sort en premier
	var show_len := func(l: float) -> void:
		var k := clampf(l / SHEET.y, 0.001, 1.0)
		q.size = Vector2(SHEET.x, SHEET.y * k)
		mi.position.z = slot + SHEET.y * k / 2.0
		m.uv1_scale = Vector3(1.0, k, 1.0)
		m.uv1_offset = Vector3(0.0, 1.0 - k, 0.0)
	if bool(p.get("instant", false)):
		show_len.call(SHEET.y)
		holder.position.y = land_y
		_sheet_ready(p, holder, slot, true)
		return
	show_len.call(0.0)
	led(Color(0.2, 1.0, 0.3))
	Sfx.play_at("printer", global_position + Vector3(0, body_size.y, 0), -6.0, 1.0, 2.0)
	# entraînement par à-coups (moteur pas à pas), pendant ~3 s
	var steps := 12
	var shown := 0.0
	for i in steps:
		pulse(1, 0.18)
		var to := SHEET.y * float(i + 1) / steps
		var tw := create_tween()
		tw.tween_method(show_len, shown, to, 0.12).set_trans(Tween.TRANS_QUAD)
		shown = to
		await get_tree().create_timer(0.25, false).timeout
		if not is_inside_tree():
			return
	show_len.call(SHEET.y)
	# elle retombe à plat dans le bac
	var tw2 := create_tween()
	tw2.tween_property(holder, "position:y", land_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	if not is_inside_tree():
		return
	led(Color(0.2, 1.0, 0.3))
	_sheet_ready(p, holder, slot, false)


## La feuille posée devient ramassable (« Prendre la feuille »). quiet : sans événement (chargement).
func _sheet_ready(p: Dictionary, holder: Node3D, slot: float, quiet: bool) -> void:
	var it := Interactable.new()
	it.label = "Prendre la feuille"
	it.reach = 2.2
	it.collision_layer = Builder.LAYER_INTERACT
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SHEET.x, 0.03, SHEET.y)
	cs.shape = bs
	it.add_child(cs)
	holder.add_child(it)
	it.position = Vector3(0, 0, slot + SHEET.y / 2.0)
	var entry := {"id": p.id, "node": holder, "it": it, "page": p}
	sheets.append(entry)
	printed.append(p.id)
	it.used.connect(func(_i: Interactable) -> void: take(p.id))
	if quiet:
		return
	page_printed.emit(p.id)
	var h := get_tree().get_first_node_in_group("haunt")
	if h and h.has_method("story_event"):
		h.story_event("page_imprimee", {"id": p.id})


## Ramasse la feuille « id » (aussi appelé par l'autotest) : objet doc, lecture de l'image.
func take(id: String) -> void:
	for i in sheets.size():
		var e: Dictionary = sheets[i]
		if e.id != id:
			continue
		sheets.remove_at(i)
		var p: Dictionary = e.page
		(e.node as Node3D).queue_free()
		Game.add_item(id, p.name, p.desc, "doc")
		Sfx.play("bookFlip1", -10.0, 1.2)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("read_image") and p.texture:
			hud.read_image(p.texture, p.legend)
		elif hud and p.legend != "":
			Game.hint(p.legend, 5.0)
		page_taken.emit(id)
		var h := get_tree().get_first_node_in_group("haunt")
		if h and h.has_method("story_event"):
			h.story_event("page_prise", {"id": id})
		return


func has_sheet(id: String) -> bool:
	for e in sheets:
		if e.id == id:
			return true
	return false
