class_name Connected
extends Node3D
## Appareil connecté de la maison (classe de base) : un petit nœud autonome, posé par le script de sa
## pièce, qui s'enregistre auprès de Haunt (le seul point d'entrée des actions de l'entité).
## Il a un identifiant (« nestor », « miroir »…), une pièce, une LED émissive, et une position d'où
## sort sa voix. Repère local : l'appareil regarde vers +Z (comme Device) ; la pièce le tourne.
##
## Utilisation type (script de pièce) :
##   var n := Nestor.new()
##   n.device_id = "nestor"
##   n.room_id = "couloir"
##   add_child(n)
##   n.position = Vector3(3.52, 0.62, -1.0)
##   n.build()

signal entity_entered(dev: Connected)   # elle arrive dans l'appareil (Haunt.move)
signal entity_left(dev: Connected)

@export var device_id := ""
@export var room_id := ""
var display_name := ""          # nom affiché devant ses sous-titres (« Nestor », « Babyphone »…)
var can_speak := false          # a un haut-parleur ou un écran : Haunt.say_nearest peut l'utiliser
var inhabited := false          # elle y est (après Haunt.move vers lui)
var haunt: Node                 # le Haunt qui l'a enregistré
var built := false

var led_mesh: MeshInstance3D
var led_mat: StandardMaterial3D
var led_light: OmniLight3D
var led_color := Color.BLACK
var led_energy := 4.0
var _pulse_tw: Tween


func _enter_tree() -> void:
	add_to_group("connecte")


func _ready() -> void:
	# l'identifiant est souvent posé juste après add_child : on s'enregistre en fin d'image
	_register.call_deferred()


func _register() -> void:
	if not is_inside_tree():
		return
	var h := get_tree().get_first_node_in_group("haunt")
	if h and h.has_method("register"):
		h.register(self)


## Construit l'appareil (à surcharger). À appeler après add_child et le placement.
func build() -> void:
	built = true


# ------------------------------------------------------------------ LED

## Matière émissive simple (LED, anneau, écran LCD) : n'entre pas dans l'éclairage indirect cuit.
static func glow_mat(c: Color, energy := 4.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c * 0.35
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func plain_mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Objet émissif : pas d'éclairage indirect cuit, pas d'ombre.
static func no_gi(mi: GeometryInstance3D) -> GeometryInstance3D:
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func add_mesh(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func add_box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return add_mesh(bm, pos, mat, Vector3.ZERO, parent)


static func cyl(r_top: float, r_bot: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func sphere(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	return s


## Pose la LED de l'appareil (petite sphère émissive, éventuellement une lueur réelle).
func make_led(pos: Vector3, radius := 0.004, with_light := false, color := Color.BLACK) -> MeshInstance3D:
	led_mat = glow_mat(Color.WHITE, 0.0)
	led_mesh = no_gi(add_mesh(sphere(radius, 8), pos, led_mat)) as MeshInstance3D
	if with_light:
		led_light = OmniLight3D.new()
		led_light.name = "LueurLed"
		led_light.light_energy = 0.0
		led_light.omni_range = 0.6
		led_light.omni_attenuation = 1.5
		led_light.shadow_enabled = false
		led_light.position = pos + Vector3(0, 0, 0.02)
		add_child(led_light)
	led(color)
	return led_mesh


## Couleur de la LED (Color.BLACK = éteinte).
func led(color: Color, energy := -1.0) -> void:
	led_color = color
	if energy >= 0.0:
		led_energy = energy
	if led_mat == null:
		return
	var off := color.r + color.g + color.b < 0.02
	led_mat.albedo_color = Color(0.05, 0.05, 0.05) if off else color * 0.35
	led_mat.emission = color
	led_mat.emission_energy_multiplier = 0.0 if off else led_energy
	if led_light:
		led_light.light_color = color
		led_light.light_energy = 0.0 if off else 0.05 * led_energy / 4.0


func led_off() -> void:
	led(Color.BLACK)


## La LED s'emballe un instant (elle parle, elle écoute, elle passe).
func pulse(times := 1, seconds := 0.22) -> void:
	if led_mat == null:
		return
	if _pulse_tw:
		_pulse_tw.kill()
	var base := led_energy if led_color.r + led_color.g + led_color.b >= 0.02 else 0.0
	var c := led_color if base > 0.0 else Color(1.0, 0.1, 0.06)
	led_mat.emission = c
	_pulse_tw = create_tween()
	for i in times:
		_pulse_tw.tween_property(led_mat, "emission_energy_multiplier", maxf(base, 4.0) * 2.5, seconds * 0.3)
		_pulse_tw.tween_property(led_mat, "emission_energy_multiplier", base, seconds * 0.7)
	_pulse_tw.tween_callback(func() -> void: led(led_color))


# ------------------------------------------------------------------ ce que Haunt lui demande

## Point d'où sort sa voix (sons 3D, choix de l'appareil le plus proche).
func speak_pos() -> Vector3:
	return global_position


## Elle parle par cet appareil pendant « seconds » secondes (animation propre : à surcharger).
func speak(_text: String, seconds: float) -> void:
	pulse(maxi(1, int(seconds / 0.5)), 0.4)


## Elle arrive dans l'appareil (LED rouge par défaut).
func on_enter() -> void:
	inhabited = true
	entity_entered.emit(self)


func on_leave() -> void:
	inhabited = false
	entity_left.emit(self)
