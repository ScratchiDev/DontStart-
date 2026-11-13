class_name Nestor
extends Connected
## « Nestor », l'enceinte de la téléassistance : un cylindre en tissu gris (Ø 0,1 × 0,16) posé sur la
## console du couloir, avec un anneau de LED en haut dont la couleur dit la jauge (Game.peur) :
## vert < 34, ambre < 67, rouge au-delà. Elle parle par lui (Haunt.say), avec des bips de données.
## Repère : le nœud est au pied de l'enceinte (posé sur le meuble), face avant vers +Z.

const RADIUS := 0.05
const HEIGHT := 0.16

var ring_on := false             # l'anneau est allumé (il s'éveille à la première entrée dans le couloir)
var ring_mat: StandardMaterial3D
var ring_light: OmniLight3D
var ring_energy := 3.0
var _speak_t := 0.0
var _wake_tw: Tween
var _wake_k := 0.0


func build() -> void:
	if display_name == "":
		display_name = "Nestor"
	can_speak = true
	var fabric := plain_mat(Color(0.2, 0.2, 0.21), 0.95)
	var plastic := plain_mat(Color(0.13, 0.13, 0.14), 0.4)
	# corps en tissu, socle en caoutchouc, dessus en plastique mat
	add_mesh(cyl(RADIUS, RADIUS, HEIGHT - 0.012, 28), Vector3(0, 0.006 + (HEIGHT - 0.012) / 2.0, 0), fabric)
	add_mesh(cyl(RADIUS * 0.94, RADIUS * 0.94, 0.006, 28), Vector3(0, 0.003, 0), plain_mat(Color(0.05, 0.05, 0.05), 0.9))
	add_mesh(cyl(RADIUS * 0.98, RADIUS, 0.006, 28), Vector3(0, HEIGHT - 0.003, 0), plastic)
	# anneau de lumière, juste sous le bord du dessus
	var tor := TorusMesh.new()
	tor.inner_radius = RADIUS * 0.8
	tor.outer_radius = RADIUS * 0.93
	tor.rings = 32
	tor.ring_segments = 8
	ring_mat = glow_mat(Game.peur_color(), 0.0)
	no_gi(add_mesh(tor, Vector3(0, HEIGHT + 0.0005, 0), ring_mat))
	# boutons du dessus (micro coupé, volume) et logo
	for i in 2:
		add_mesh(cyl(0.006, 0.006, 0.002, 10), Vector3(-0.012 + i * 0.024, HEIGHT + 0.001, 0.0), plain_mat(Color(0.3, 0.3, 0.31), 0.5))
	add_box(Vector3(0.03, 0.006, 0.001), Vector3(0, 0.03, RADIUS + 0.0005), plain_mat(Color(0.55, 0.55, 0.52), 0.5))
	# lueur réelle de l'anneau sur le meuble et le mur
	ring_light = OmniLight3D.new()
	ring_light.name = "LueurAnneau"
	ring_light.light_energy = 0.0
	ring_light.omni_range = 1.1
	ring_light.omni_attenuation = 1.4
	ring_light.shadow_enabled = false
	ring_light.position = Vector3(0, HEIGHT + 0.03, 0)
	add_child(ring_light)
	Game.peur_changed.connect(func(_v: float) -> void: _apply_ring())
	built = true
	_apply_ring()


func speak_pos() -> Vector3:
	return to_global(Vector3(0, HEIGHT * 0.5, 0))


## Couleur actuelle de l'anneau (selon la jauge).
func ring_color() -> Color:
	return Game.peur_color()


## Nom de la couleur de l'anneau, pour les textes : « vert », « ambre » ou « rouge ».
func ring_color_name() -> String:
	if Game.peur < 34.0:
		return "vert"
	if Game.peur < 67.0:
		return "ambre"
	return "rouge"


## L'anneau s'allume (« seconds » : fondu) ou s'éteint.
func set_ring(on: bool, seconds := 0.8) -> void:
	ring_on = on
	if _wake_tw:
		_wake_tw.kill()
	_wake_tw = create_tween()
	_wake_tw.tween_method(func(k: float) -> void:
		_wake_k = k
		_apply_ring(), _wake_k, 1.0 if on else 0.0, maxf(seconds, 0.01))
	if on:
		Sfx.voice_at("chirp", speak_pos(), -14.0, 0.8)


## Il s'éveille : l'anneau monte en tournant (couleur de la jauge).
func wake() -> void:
	set_ring(true, 1.2)


func _apply_ring() -> void:
	if ring_mat == null:
		return
	var c := ring_color()
	var talk := 0.0
	if _speak_t > 0.0:
		talk = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.03) * sin(Time.get_ticks_msec() * 0.011)
	var k := _wake_k * (1.0 + talk * 1.3)
	ring_mat.emission = c
	ring_mat.albedo_color = c * 0.3 if _wake_k > 0.01 else Color(0.18, 0.18, 0.18)
	ring_mat.emission_energy_multiplier = ring_energy * k
	ring_light.light_color = c
	# lueur discrète sur le meuble et le mur ; le vert porte plus que le rouge à énergie égale
	var lum := 0.5 if c.g > 0.8 else 1.0
	ring_light.light_energy = 0.035 * lum * _wake_k * (1.0 + talk * 0.5)


## Petits bips de données (avant ou sous une phrase).
func chirp(db := -10.0) -> void:
	Sfx.voice_at("chirp", speak_pos(), db, randf_range(0.9, 1.15), 1.6)


func speak(_text: String, seconds: float) -> void:
	_speak_t = maxf(_speak_t, seconds)


func _process(delta: float) -> void:
	if _speak_t > 0.0:
		_speak_t = maxf(0.0, _speak_t - delta)
		_apply_ring()
