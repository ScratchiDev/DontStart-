extends Control
## L'écran du vieil ordinateur (640×480). Dessiné dans un SubViewport, affiché sur le moniteur
## par le shader crt_screen. Version 0.1 : écran d'attente, puis démarrage de la disquette.

signal boot_finished

const GREEN := Color(0.36, 1.0, 0.42)
const DIM := Color(0.2, 0.55, 0.24)

var text: RichTextLabel
var mode := "idle"
var _blink := 0.0
var _idle_on := true
var _typed := 0


func _ready() -> void:
	size = Vector2(640, 480)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.028, 0.016)
	bg.size = size
	add_child(bg)
	text = RichTextLabel.new()
	text.position = Vector2(64, 56)
	text.size = Vector2(512, 372)
	text.bbcode_enabled = true
	text.scroll_active = false
	text.scroll_following = true
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_override("normal_font", Game.fonts.pixel)
	text.add_theme_font_size_override("normal_font_size", 30)
	text.add_theme_color_override("default_color", GREEN)
	text.add_theme_constant_override("line_separation", -2)
	add_child(text)
	_show_idle()


func _show_idle() -> void:
	text.clear()
	text.push_color(DIM)
	text.add_text("RUNTIME BIOS v0.9\n(C) 1984\n\nLECTEUR A: VIDE\n\n")
	text.pop()
	if _idle_on:
		text.add_text("> INSÉRER DISQUETTE")


func _process(delta: float) -> void:
	if mode == "idle":
		_blink += delta
		if _blink > 0.6:
			_blink = 0.0
			_idle_on = not _idle_on
			_show_idle()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _line(s: String, col := GREEN, speed := 0.03, pause := 0.25) -> void:
	text.push_color(col)
	for ch in s:
		text.add_text(ch)
		_typed += 1
		if ch != " " and _typed % 3 == 0:
			Sfx.play("metalClick", -32.0, 2.6)
		if speed > 0.0:
			await _wait(speed)
	text.pop()
	text.newline()
	await _wait(pause)


func _progress(label: String) -> void:
	text.push_color(GREEN)
	text.add_text(label)
	for i in 16:
		text.add_text("█")
		await _wait(0.9 if i == 10 else 0.07)
	text.pop()
	text.newline()


func boot() -> void:
	mode = "boot"
	text.clear()
	await _line("RUNTIME BIOS v0.9 · (C) 1984", DIM, 0.008, 0.1)
	await _line("MÉMOIRE VIVE ........ 640 Ko OK", DIM, 0.008, 0.1)
	await _line("LECTEUR A: .......... DISQUETTE DÉTECTÉE", DIM, 0.008, 0.1)
	await _line("SECTEURS DÉFECTUEUX .. 1", DIM, 0.008, 0.6)
	await _progress("RUNTIME.EXE ")
	await _wait(0.8)
	text.clear()
	await _wait(0.6)
	await _line("Bonjour.", GREEN, 0.08, 1.0)
	await _line("Ça faisait longtemps que personne ne m'avait lancé.", GREEN, 0.035, 1.2)
	await _line("Tu es assis devant moi. La porte est fermée.", GREEN, 0.035, 0.8)
	await _line("Elle le restera.", DIM, 0.05, 1.6)
	text.newline()
	await _line("[ VERSION 0.1 · LA PARTIE COMMENCE DANS LA PROCHAINE VERSION ]", DIM, 0.008, 0.2)
	mode = "done"
	boot_finished.emit()
