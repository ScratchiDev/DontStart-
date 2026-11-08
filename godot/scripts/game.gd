extends Node
## Singleton « Game » : touches, réglages sauvegardés, état de la partie, utilitaires communs.

signal objective_changed(text: String)
signal hint_requested(text: String, seconds: float)
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

# --- réglages (sauvegardés) ---
var mouse_sensitivity := 0.0022
var master_volume := 0.85
var fullscreen := true
var high_quality := true

# --- état de la partie ---
var has_floppy := false
var phase := "title"   # title, room, seated, end

# --- tests automatisés : godot --path godot -- --autotest --shots=/chemin ---
var autotest := false
var shots_dir := ""

var fonts := {}


func _enter_tree() -> void:
	_setup_input()
	_load_fonts()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
	_load_settings()
	if autotest:
		fullscreen = false
	apply_settings()


func _setup_input() -> void:
	# Touches physiques : « W » ici est la touche en haut à gauche, donc Z sur un clavier AZERTY.
	_keys("move_forward", [KEY_W, KEY_UP])
	_keys("move_back", [KEY_S, KEY_DOWN])
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("sprint", [KEY_SHIFT])
	_keys("crouch", [KEY_C, KEY_CTRL])
	_keys("interact", [KEY_E])
	_keys("flashlight", [KEY_F])
	_keys("pause", [KEY_ESCAPE])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interact", click)


func _keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _load_fonts() -> void:
	var pixel: FontFile = load("res://assets/fonts/VT323-Regular.ttf")
	pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel.hinting = TextServer.HINTING_NONE
	fonts.pixel = pixel
	fonts.hand = load("res://assets/fonts/ReenieBeanie.ttf")
	fonts.goth = load("res://assets/fonts/UnifrakturMaguntia-Book.ttf")
	fonts.mono = load("res://assets/fonts/IBMPlexMono-Regular.ttf")


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	high_quality = cfg.get_value("video", "high_quality", high_quality)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "high_quality", high_quality)
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	if not autotest:
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()


func objective(text: String) -> void:
	objective_changed.emit(text)


func hint(text: String, seconds := 3.5) -> void:
	hint_requested.emit(text, seconds)


## Voix chuchotée du système (synthèse vocale de Windows), si une voix française est installée.
func whisper(text: String) -> void:
	if autotest:
		return
	var voices := DisplayServer.tts_get_voices_for_language("fr")
	if voices.is_empty():
		return
	DisplayServer.tts_speak(text, voices[0], int(master_volume * 45.0), 0.3, 0.6)
