class_name Babyphone
extends Connected
## Le babyphone Wi-Fi gardé depuis la petite enfance du héros (chambre d'amis, sur le chevet) :
## un boîtier blanc 0,08 × 0,14 × 0,05, une antenne, une grille de haut-parleur et une barre de
## 5 LED de niveau (vert, vert, jaune, orange, rouge) qui suivent ce qu'il « entend » : une
## respiration lente (breathe), puis sa voix (say, par Haunt).
## Repère : le nœud est sous le boîtier (posé sur le meuble), la face avant regarde +Z.

const SIZE := Vector3(0.08, 0.14, 0.05)
const LED_COLORS := [Color(0.2, 1.0, 0.3), Color(0.2, 1.0, 0.3), Color(1.0, 0.9, 0.15), Color(1.0, 0.5, 0.1), Color(1.0, 0.12, 0.08)]

var level := 0.0                 # niveau affiché (0..5)
var breathing := false
var breath_period := 4.2         # une respiration toutes les 4,2 s (endormie)
var leds: Array[StandardMaterial3D] = []
var _breath_snd: Node
var _speak_t := 0.0
var _t := 0.0
var _manual := -1.0


func build() -> void:
	if display_name == "":
		display_name = "Babyphone"
	can_speak = true
	var white := plain_mat(Color(0.86, 0.85, 0.8), 0.45)
	var grey := plain_mat(Color(0.55, 0.56, 0.58), 0.5)
	# boîtier arrondi (deux boîtes et un dessus en demi-cylindre), socle
	add_box(Vector3(SIZE.x, SIZE.y - 0.02, SIZE.z), Vector3(0, (SIZE.y - 0.02) / 2.0, 0), white)
	add_mesh(cyl(SIZE.z / 2.0, SIZE.z / 2.0, SIZE.x, 16), Vector3(0, SIZE.y - 0.02, 0), white, Vector3(0, 0, PI / 2.0))
	add_box(Vector3(SIZE.x * 1.1, 0.008, SIZE.z * 1.15), Vector3(0, 0.004, 0), grey)
	# antenne souple, à droite
	add_mesh(cyl(0.004, 0.006, 0.09, 8), Vector3(SIZE.x * 0.32, SIZE.y + 0.03, -0.008), plain_mat(Color(0.2, 0.2, 0.21), 0.6), Vector3(0, 0, -0.12))
	# grille du haut-parleur
	var front := SIZE.z / 2.0
	add_box(Vector3(SIZE.x * 0.7, 0.05, 0.003), Vector3(0, 0.085, front + 0.0015), grey)
	for i in 5:
		add_box(Vector3(SIZE.x * 0.6, 0.003, 0.002), Vector3(0, 0.068 + i * 0.0085, front + 0.0035), plain_mat(Color(0.25, 0.25, 0.27), 0.6))
	# barre de LED de niveau, sur un bandeau noir
	add_box(Vector3(SIZE.x * 0.86, 0.016, 0.002), Vector3(0, 0.036, front + 0.001), plain_mat(Color(0.03, 0.03, 0.035), 0.3))
	for i in 5:
		var m := glow_mat(LED_COLORS[i], 0.0)
		m.albedo_color = Color(0.12, 0.12, 0.12)
		leds.append(m)
		no_gi(add_box(Vector3(0.01, 0.007, 0.003), Vector3(-0.0272 + i * 0.0136, 0.036, front + 0.0022), m))
	# voyant de marche (bleu)
	make_led(Vector3(SIZE.x * 0.36, 0.015, front + 0.001), 0.0025, false, Color(0.2, 0.45, 1.0))
	led_energy = 2.5
	led(Color(0.2, 0.45, 1.0))
	built = true
	_apply_level(0.0)


func speak_pos() -> Vector3:
	return to_global(Vector3(0, 0.085, SIZE.z / 2.0))


## Barre de niveau : n LED allumées (0..5, fractions = la dernière à moitié).
func _apply_level(v: float) -> void:
	level = clampf(v, 0.0, 5.0)
	for i in leds.size():
		var k := clampf(level - i, 0.0, 1.0)
		leds[i].emission_energy_multiplier = 1.5 * k
		leds[i].albedo_color = (LED_COLORS[i] as Color) * 0.15 if k > 0.05 else Color(0.08, 0.08, 0.08)


## Impose un niveau (−1 = le babyphone reprend la main).
func set_level(v: float) -> void:
	_manual = v
	if v >= 0.0:
		_apply_level(v)


## Il « entend » une respiration lente : souffle derrière un bruit radio, barres qui montent et descendent.
## Le son passe par le bus Ambiance : le silence de l'entité le coupe.
func breathe(on: bool, db := -14.0) -> void:
	breathing = on
	if on and _breath_snd == null:
		_breath_snd = Sfx.loop("babyphone_breath", db, speak_pos(), self)
		if _breath_snd:
			_breath_snd.set("max_distance", 9.0)
	elif not on and _breath_snd:
		_breath_snd.queue_free()
		_breath_snd = null


## Elle parle par le babyphone (sous-titre, bips et barres) : passe par Haunt.
## who : "elle" (sa voix) ou le nom de la personne imitée (« Mamie »).
func say(text: String, who := "elle") -> float:
	var h := get_tree().get_first_node_in_group("haunt")
	if h and h.has_method("say"):
		return h.say(device_id, text, who)
	speak(text, 2.0 + 0.06 * text.length())
	return 2.0 + 0.06 * text.length()


func speak(_text: String, seconds: float) -> void:
	_speak_t = maxf(_speak_t, seconds)


func _process(delta: float) -> void:
	_t += delta
	if _manual >= 0.0:
		return
	var v := 0.0
	if _speak_t > 0.0:
		_speak_t = maxf(0.0, _speak_t - delta)
		# une voix : les barres sautent
		v = 1.5 + 3.5 * absf(sin(_t * 13.0) * sin(_t * 4.1 + 1.0)) + randf_range(-0.4, 0.4)
	elif breathing:
		# inspiration lente, expiration plus longue
		var ph := fmod(_t, breath_period) / breath_period
		var b := sin(ph * PI) if ph < 0.45 else sin(PI * 0.45 + (ph - 0.45) / 0.55 * PI * 0.55)
		v = 0.3 + 2.1 * maxf(b, 0.0) + randf_range(0.0, 0.25)
	_apply_level(v)
