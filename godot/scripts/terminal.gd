extends Control
## L'écran de l'ordinateur de Manon (640×480), dessiné dans un SubViewport et affiché sur le moniteur
## par le shader crt_screen. C'est le moteur du jeu-terminal RUNTIME : texte tapé lettre à lettre,
## choix minutés (touches 1, 2, 3), saisie au clavier, jauge PEUR MESURÉE qui fait virer le phosphore
## du vert à l'ambre puis au rouge, erreurs aux lettres qui brillent, texte qui se corrompt,
## extinction du tube, plantage. Le contenu des séances est écrit dans seance1.gd.
##
## Les touches arrivent par key_input(), appelé par main.gd quand le joueur est assis.
## Quand la jauge atteint 100 %, aborted passe à true : toutes les primitives rendent la main
## immédiatement et la séance enchaîne sur la fin ABSORBÉ.

signal boot_finished
signal fear_changed(value: float)
signal event(name: String)          # réactions de la chambre : knock, wardrobe, ceiling, scream…
signal ended(id: String)            # fin atteinte (absorbe, transmission, suite…)

const GREEN := Color(0.36, 1.0, 0.42)
const AMBER := Color(1.0, 0.72, 0.22)
const RED := Color(1.0, 0.24, 0.16)
const KEYGLOW := Color(1.0, 0.98, 0.78)
const SCRAMBLE := "▓▒░#¿§¤01"
const ENDS := {
	"absorbe": "ABSORBÉ",
	"transmission": "TRANSMISSION",
	"boucle": "LA BOUCLE",
	"aube": "L'AUBE",
	"extinction": "EXTINCTION",
}
const ENDS_PATH := "user://fins.cfg"

var text: RichTextLabel
var status: Control
var fear_fill: ColorRect
var fear_val: Label
var timer_box: Control
var timer_fill: ColorRect
var timer_val: Label
var ghost_lbl: Label
var watch: TextureRect
var crash_box: ColorRect
var crash_lbl: Label
var screen_mat: ShaderMaterial      # matière du tube (posée par room.gd)

var mode := "idle"                  # idle, boot, seance, done
var fear := 0.0
var aborted := false
var fast := false
var narrating := false
var hesitation := 0.0
var proche := ""                    # « Mamie », « Papi » ou « Maman »
var next_player := ""
var started_ms := 0

# lignes affichées : { segs: [[texte, est_une_lettre_qui_brille]], kind: n|dim|err|opt|picked|dead|sys, n: caractères visibles }
var lines: Array = []
var _blink := 0.0
var _idle_on := true
var _typed := 0
var _rot_t := 0.0
var _choice := {}                   # choix en cours : { n, picked }
var _ask := {}                      # saisie en cours : { buf, done, label }
var _any_key := false
var _waiting_any := false
# test automatique : réponses toutes prêtes et texte instantané
var autopicks: Array = []
var autoasks: Array = []
var turbo := false


func _ready() -> void:
	size = Vector2(640, 480)
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.028, 0.016)
	bg.size = size
	add_child(bg)
	watch = TextureRect.new()
	watch.texture = load("res://assets/images/entity_face.png")
	watch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	watch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	watch.position = Vector2(120, 60)
	watch.size = Vector2(400, 400)
	watch.modulate = Color(GREEN, 0.0)
	add_child(watch)
	text = RichTextLabel.new()
	text.position = Vector2(48, 58)
	text.size = Vector2(544, 392)
	text.bbcode_enabled = true
	text.scroll_active = false
	text.scroll_following = true
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_override("normal_font", Game.fonts.pixel)
	text.add_theme_font_size_override("normal_font_size", 28)
	text.add_theme_color_override("default_color", GREEN)
	text.add_theme_constant_override("line_separation", -2)
	add_child(text)
	ghost_lbl = Label.new()
	ghost_lbl.position = Vector2(0, 170)
	ghost_lbl.size = Vector2(640, 120)
	ghost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost_lbl.add_theme_font_override("font", Game.fonts.pixel)
	ghost_lbl.add_theme_font_size_override("font_size", 96)
	ghost_lbl.modulate.a = 0.0
	add_child(ghost_lbl)
	_build_status()
	_build_crash()
	_show_idle()


func _build_status() -> void:
	status = Control.new()
	status.position = Vector2(48, 16)
	status.size = Vector2(544, 30)
	status.visible = false
	add_child(status)
	var l := _small_label("PEUR MESURÉE", Vector2(0, 0))
	status.add_child(l)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(GREEN, 0.18)
	bar_bg.position = Vector2(130, 9)
	bar_bg.size = Vector2(120, 10)
	status.add_child(bar_bg)
	fear_fill = ColorRect.new()
	fear_fill.color = GREEN
	fear_fill.position = bar_bg.position
	fear_fill.size = Vector2(0, 10)
	status.add_child(fear_fill)
	fear_val = _small_label("00%", Vector2(258, 0))
	status.add_child(fear_val)
	timer_box = Control.new()
	timer_box.position = Vector2(330, 0)
	timer_box.visible = false
	status.add_child(timer_box)
	timer_box.add_child(_small_label("DÉLAI", Vector2(0, 0)))
	var tb := ColorRect.new()
	tb.color = Color(GREEN, 0.18)
	tb.position = Vector2(56, 9)
	tb.size = Vector2(110, 10)
	timer_box.add_child(tb)
	timer_fill = ColorRect.new()
	timer_fill.color = GREEN
	timer_fill.position = tb.position
	timer_fill.size = Vector2(110, 10)
	timer_box.add_child(timer_fill)
	timer_val = _small_label("--", Vector2(174, 0))
	timer_box.add_child(timer_val)


func _small_label(t: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_override("font", Game.fonts.pixel)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", GREEN)
	return l


func _build_crash() -> void:
	crash_box = ColorRect.new()
	crash_box.color = Color(0.0, 0.0, 0.45)
	crash_box.size = size
	crash_box.visible = false
	add_child(crash_box)
	crash_lbl = Label.new()
	crash_lbl.position = Vector2(40, 40)
	crash_lbl.size = Vector2(560, 400)
	crash_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crash_lbl.add_theme_font_override("font", Game.fonts.pixel)
	crash_lbl.add_theme_font_size_override("font_size", 24)
	crash_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 1.0))
	crash_box.add_child(crash_lbl)


# ------------------------------------------------------------------ couleur du phosphore

## Le phosphore vire du vert à l'ambre puis au rouge quand la jauge monte.
func phos() -> Color:
	var c := fear / 100.0
	if c < 0.5:
		return GREEN.lerp(AMBER, smoothstep(0.25, 0.5, c))
	return AMBER.lerp(RED, smoothstep(0.55, 0.9, c))


func _apply_colors() -> void:
	var p := phos()
	text.add_theme_color_override("default_color", p)
	for n in status.find_children("*", "Label", true, false):
		(n as Label).add_theme_color_override("font_color", p)
	fear_fill.color = p
	timer_fill.color = RED if timer_val.text.to_int() <= 3 and timer_val.text != "--" else p
	if screen_mat:
		screen_mat.set_shader_parameter("phosphor", Vector3(p.r, p.g, p.b))
	_render()


# ------------------------------------------------------------------ écran d'attente et démarrage

func _show_idle() -> void:
	lines.clear()
	_add_line("BIOS v4.51", "dim", true)
	_add_line("(C) 1996", "dim", true)
	_add_line("", "dim", true)
	_add_line("LECTEUR A: VIDE", "dim", true)
	_add_line("", "dim", true)
	if _idle_on:
		_add_line("> INSÉRER DISQUETTE", "n", true)
	_render()


func _process(delta: float) -> void:
	if mode == "idle":
		_blink += delta
		if _blink > 0.6:
			_blink = 0.0
			_idle_on = not _idle_on
			_show_idle()
	elif mode == "seance":
		_rot_t += delta
		if _rot_t > 0.9:
			_rot_t = 0.0
			_rot()


## Démarrage de la disquette (BIOS, chargement), puis la séance prend la main.
func boot() -> void:
	mode = "boot"
	lines.clear()
	_render()
	await line("BIOS v4.51 · (C) 1996", "dim", 0.006, 0.08)
	await line("PROPRIÉTÉ CERAF · INVENTAIRE N° 0312", "dim", 0.006, 0.08)
	await line("MÉMOIRE VIVE ........ 32768 Ko OK", "dim", 0.006, 0.08)
	await line("LECTEUR A: .......... DISQUETTE DÉTECTÉE", "dim", 0.006, 0.08)
	await line("SECTEURS DÉFECTUEUX .. 0", "dim", 0.006, 0.6)
	lines[-1].segs = [["SECTEURS DÉFECTUEUX .. 1", false]]
	_render()
	glitch(0.3)
	await wait(0.5)
	await progress("CHARGEMENT DE RUNTIME.EXE ")
	await wait(0.6)
	boot_finished.emit()


# ------------------------------------------------------------------ primitives

func wait(sec: float) -> void:
	if turbo:
		sec *= 0.1
	if fast or aborted or sec <= 0.0:
		await get_tree().process_frame
		return
	await get_tree().create_timer(sec, false).timeout


## Remplace {name}, {NAME}, {proche}, {next}, {time}, {temps} et les variantes {masculin|féminin}.
func fill(s: String) -> String:
	var nm := Game.hero_name()
	s = s.replace("{name}", nm).replace("{NAME}", nm.to_upper())
	s = s.replace("{proche}", proche).replace("{PROCHE}", proche.to_upper())
	s = s.replace("{next}", next_player).replace("{time}", game_clock())
	var mins := maxi(1, int(round((Time.get_ticks_msec() - started_ms) / 60000.0)))
	s = s.replace("{temps}", "%d minute%s" % [mins, "s" if mins > 1 else ""])
	var re := RegEx.create_from_string("\\{([^|{}]*)\\|([^|{}]*)\\}")
	for m in re.search_all(s):
		s = s.replace(m.get_string(0), Game.g(m.get_string(1), m.get_string(2)))
	return s


## L'heure dans la maison : 3 h 12 au début de la séance, puis le temps passe.
func game_clock() -> String:
	var mins := 3 * 60 + 12 + int((Time.get_ticks_msec() - started_ms) / 60000.0) if started_ms > 0 else 192
	return "%d h %02d" % [mins / 60, mins % 60]


func _parse(s: String) -> Array:
	# « [[A]] » marque une lettre qui brille
	var segs := []
	var parts := s.split("[[")
	for i in parts.size():
		var p: String = parts[i]
		if i == 0:
			if p != "":
				segs.append([p, false])
			continue
		var j := p.find("]]")
		if j < 0:
			segs.append([p, false])
			continue
		segs.append([p.substr(0, j), true])
		if p.substr(j + 2) != "":
			segs.append([p.substr(j + 2), false])
	return segs


func _add_line(s: String, kind := "n", full := true) -> Dictionary:
	var segs := _parse(s)
	var total := 0
	for sg in segs:
		total += (sg[0] as String).length()
	var ln := {"segs": segs, "kind": kind, "n": total if full else 0}
	lines.append(ln)
	if lines.size() > 60:
		lines.pop_front()
	return ln


func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


func _render() -> void:
	var p := phos()
	var cols := {
		"n": p, "dim": p * Color(0.55, 0.55, 0.55, 1), "err": Color(1.0, 0.5, 0.42) if fear < 50.0 else Color(1, 0.85, 0.8),
		"opt": p, "picked": KEYGLOW, "dead": p * Color(0.3, 0.3, 0.3, 1), "sys": p,
	}
	var out := ""
	for ln in lines:
		var c: Color = cols.get(ln.kind, p)
		out += "[color=#%s]" % c.to_html(false)
		var left: int = ln.n
		for sg in ln.segs:
			if left <= 0:
				break
			var t: String = sg[0]
			var part := t.substr(0, left)
			left -= part.length()
			if sg[1]:
				out += "[color=#%s][b]%s[/b][/color]" % [KEYGLOW.to_html(false), _esc(part)]
			else:
				out += _esc(part)
		out += "[/color]\n"
	text.text = out


## Écrit une ligne lettre par lettre. kind : n (normal), dim (atténué), err (erreur).
func line(s: String, kind := "n", speed := 0.024, pause := 0.28) -> void:
	if aborted:
		return
	narrating = true
	s = fill(s)
	if fear > 50.0 and kind == "n":
		s = _leet(s)
	if turbo:
		speed = 0.0
	var ln := _add_line(s, kind, false)
	var total := 0
	for sg in ln.segs:
		total += (sg[0] as String).length()
	var i := 0
	while i < total:
		if fast or speed <= 0.0 or aborted:
			ln.n = total
			break
		ln.n = i + 1
		var ch := _char_at(ln, i)
		if ch != " ":
			_typed += 1
			if _typed % 2 == 0:
				Sfx.play("metalClick", -30.0, 2.6)
		_render()
		i += 1
		await get_tree().create_timer(speed, false).timeout
	_render()
	await wait(pause)


func _char_at(ln: Dictionary, idx: int) -> String:
	for sg in ln.segs:
		var t: String = sg[0]
		if idx < t.length():
			return t[idx]
		idx -= t.length()
	return ""


## Au-delà de 50 %, un ou deux mots par ligne voient leurs voyelles changées en chiffres.
func _leet(s: String) -> String:
	var words := s.split(" ")
	var done := 0
	for k in words.size():
		if done >= 2:
			break
		var w: String = words[k]
		if w.length() >= 5 and randf() < 0.25 and not w.contains("[["):
			words[k] = w.replace("e", "3").replace("i", "1")
			done += 1
	return " ".join(words)


## Ligne d'erreur système, glitch, et brouillage avant que les lettres qui brillent se fixent.
func error(s: String) -> void:
	if aborted:
		return
	glitch(0.6)
	await line(s, "err", 0.008, 0.2)
	var ln: Dictionary = lines[-1]
	var keep: Array = ln.segs.duplicate(true)
	for k in 6:
		var scr := []
		for sg in keep:
			var t := ""
			for ch in (sg[0] as String):
				t += SCRAMBLE[randi() % SCRAMBLE.length()] if ch != " " and randf() < 0.5 else ch
			scr.append([t, sg[1]])
		ln.segs = scr
		_render()
		await wait(0.08)
	ln.segs = keep
	_render()
	await wait(0.9)


func progress(label: String) -> void:
	await line(label, "n", 0.008, 0.0)
	var ln: Dictionary = lines[-1]
	for i in 16:
		ln.segs.append(["█", false])
		ln.n += 1
		_render()
		if i % 3 == 0:
			Sfx.play("metalClick", -22.0, 0.7)
		await wait(0.9 if i == 10 else 0.07)


func clear() -> void:
	lines.clear()
	_render()


## Grand mot fantôme qui passe sous le texte (un prénom, « DERRIÈRE TOI »…).
func ghost(s: String) -> void:
	ghost_lbl.text = fill(s)
	ghost_lbl.add_theme_color_override("font_color", phos())
	var tw := create_tween()
	tw.tween_property(ghost_lbl, "modulate:a", 0.22, 0.05)
	tw.tween_interval(0.08)
	tw.tween_property(ghost_lbl, "modulate:a", 0.0, 0.25)


## Secousse de l'image (décrochages du tube) et grésillement.
func glitch(amount := 0.5) -> void:
	if screen_mat:
		var tw := create_tween()
		tw.tween_method(func(x: float) -> void: screen_mat.set_shader_parameter("glitch", x), amount * 1.5, 0.0, 0.15 + amount * 0.35)
	var p := Sfx.play("static_loop", lerpf(-22.0, -8.0, amount), 1.0)
	get_tree().create_timer(0.12 + amount * 0.3).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


## Le visage de l'entité en filigrane derrière le texte (0 = invisible).
func watch_face(opacity: float, seconds := 1.5) -> void:
	var tw := create_tween()
	tw.tween_property(watch, "modulate", Color(phos(), opacity), seconds)


func power_off() -> void:
	if not screen_mat:
		return
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: screen_mat.set_shader_parameter("collapse", x), 0.0, 1.0, 0.35)
	screen_mat.set_shader_parameter("bright_line", 1.0)
	Sfx.play("metalClick", -14.0, 0.5)
	await tw.finished
	screen_mat.set_shader_parameter("power_on", 0.0)
	await wait(0.2)


func power_on() -> void:
	if not screen_mat:
		return
	screen_mat.set_shader_parameter("power_on", 1.0)
	screen_mat.set_shader_parameter("bright_line", 0.0)
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: screen_mat.set_shader_parameter("collapse", x), 0.7, 0.0, 0.3)
	Sfx.play("drive_seek", -18.0)
	await tw.finished


## Écran de titre d'un protocole (le tube s'éteint, le titre se déchiffre).
func level(label: String, title: String) -> void:
	if aborted:
		return
	fast = false
	await power_off()
	clear()
	await power_on()
	await line(label, "dim", 0.01, 0.2)
	await line("", "n", 0.0, 0.0)
	var ln := _add_line(title.to_upper(), "n", true)
	for k in 10:
		var t := ""
		for ch in title.to_upper():
			t += SCRAMBLE[randi() % SCRAMBLE.length()] if ch != " " and randf() < 1.0 - k / 10.0 else ch
		ln.segs = [[t, false]]
		_render()
		await wait(0.09)
	ln.segs = [[title.to_upper(), false]]
	_render()
	await wait(2.0)
	clear()


## L'image se fige, plus aucun son, puis repart.
func freeze(sec: float) -> void:
	if aborted:
		return
	set_process(false)
	Sfx.music("", -60.0, 0.05)
	await wait(sec)
	set_process(true)
	glitch(0.7)
	Sfx.music("music_tension", -16.0, 3.0)


## Plantage : écran bleu, attend une touche (ou 6 s).
func crash(s: String) -> void:
	if aborted:
		return
	glitch(1.0)
	Sfx.music("", -60.0, 0.05)
	crash_lbl.text = fill(s)
	crash_box.visible = true
	_any_key = false
	_waiting_any = true
	var t := 0.0
	while not _any_key and t < (1.5 if Game.autotest else 6.0):
		await get_tree().create_timer(0.1, false).timeout
		t += 0.1
	_waiting_any = false
	crash_box.visible = false
	await power_off()
	clear()
	await wait(0.9)
	await power_on()
	Sfx.music("music_tension", -18.0, 4.0)


# ------------------------------------------------------------------ jauge

func corrupt(n: float) -> void:
	if aborted:
		return
	fear = clampf(fear + n, 0.0, 100.0)
	_update_fear()
	if n > 0.0:
		glitch(minf(1.0, n / 22.0))
	if fear >= 100.0:
		aborted = true


func set_fear(v: float) -> void:
	fear = clampf(v, 0.0, 100.0)
	_update_fear()


func _update_fear() -> void:
	var tw := create_tween()
	tw.tween_property(fear_fill, "size:x", 120.0 * fear / 100.0, 0.8)
	fear_val.text = "%02d%%" % int(fear)
	_apply_colors()
	fear_changed.emit(fear)


## Corruption progressive du texte déjà affiché (caractères, prénom qui remplace un mot).
func _rot() -> void:
	var c := fear / 100.0
	if c < 0.2 or randf() > c * 0.9 or lines.is_empty():
		return
	var cands := []
	for ln in lines:
		if ln.kind in ["n", "dim"] and ln.n > 0:
			cands.append(ln)
	if cands.is_empty():
		return
	var ln: Dictionary = cands[randi() % cands.size()]
	var sg: Array = ln.segs[randi() % ln.segs.size()]
	if sg[1]:
		return
	var t: String = sg[0]
	if t.length() < 3:
		return
	var i := randi() % t.length()
	if t[i] == " ":
		return
	if c > 0.6 and randf() < 0.2:
		var re := RegEx.create_from_string("[A-Za-zÀ-ÿ']{5,}")
		var m := re.search(t)
		if m:
			t = t.replace(m.get_string(), Game.hero_name().to_upper())
	else:
		t = t.substr(0, i) + SCRAMBLE[randi() % 7] + t.substr(i + 1)
	sg[0] = t
	_render()
	if c > 0.45 and randf() < c * 0.18:
		ghost(["DERRIÈRE TOI", proche.to_upper(), "RESTE", "REGARDE", Game.hero_name().to_upper(), "NE DORS PAS"][randi() % 6])


# ------------------------------------------------------------------ choix minutés et saisie

## Propose des choix (touches 1, 2, 3) avec un délai visible. À l'expiration, choisit « worst ».
## extra : condition physique vérifiée en continu (ex. le joueur s'est retourné) qui choisit 0.
func pick(opts: Array, time := 12.0, worst := 0, extra := Callable()) -> int:
	if aborted:
		return worst
	narrating = false
	fast = false
	var opt_lines := []
	for i in opts.size():
		opt_lines.append(_add_line("[%d] %s" % [i + 1, fill(opts[i])], "opt", true))
	_render()
	Sfx.music("music_tension", -14.0, 1.5)
	_choice = {"n": opts.size(), "picked": -1}
	timer_box.visible = true
	var elapsed := 0.0
	var prev := Time.get_ticks_msec()
	var left := time
	var last := -1
	var result := worst
	var timeout := false
	while true:
		if aborted:
			break
		var now := Time.get_ticks_msec()
		if not get_tree().paused:
			elapsed += (now - prev) / 1000.0
		prev = now
		if Game.autotest and elapsed > 0.6 and not autopicks.is_empty():
			_choice.picked = autopicks.pop_front()
		if _choice.picked >= 0:
			result = _choice.picked
			break
		if extra.is_valid() and extra.call():
			result = 0
			break
		left = time - elapsed
		if left <= 0.0:
			timeout = true
			break
		var sec := int(ceil(left))
		if sec != last:
			last = sec
			timer_val.text = "%02d" % sec
			Sfx.play("metalClick", -10.0 if sec <= 3 else -20.0, 1.6 if sec <= 3 else 1.1)
			_apply_colors()
		timer_fill.size.x = 110.0 * left / time
		await get_tree().process_frame
	hesitation = elapsed
	_choice = {}
	timer_box.visible = false
	timer_val.text = "--"
	for i in opt_lines.size():
		opt_lines[i].kind = "picked" if i == result else "dead"
	_render()
	Sfx.play("metalClick", -6.0, 0.8)
	Sfx.music("music_house", -16.0, 3.0)
	if timeout and not aborted:
		await line("> DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI.", "err", 0.01)
		corrupt(5)
	return result


## Saisie au clavier (un mot, un prénom). possess : l'entité tape d'abord à ta place, puis efface.
func ask(label: String, default_value: String, possess := "") -> String:
	if aborted:
		return default_value
	narrating = false
	fast = false
	var ln := _add_line(label + " > ", "n", true)
	_ask = {"buf": "", "done": false, "line": ln, "label": label + " > ", "locked": false}
	_ask_render()
	if possess != "":
		_possess_input(possess)
	var t := 0.0
	while not _ask.done and not aborted:
		await get_tree().process_frame
		t += get_process_delta_time()
		if Game.autotest and t > 1.5 and not _ask.locked:
			_ask.buf = autoasks.pop_front() if not autoasks.is_empty() else default_value
			_ask.done = true
	var v: String = (_ask.buf as String).strip_edges()
	if v == "":
		v = default_value
	ln.segs = [[_ask.label + v, false]]
	ln.n = (_ask.label + v).length()
	_render()
	_ask = {}
	Sfx.play("metalClick", -6.0, 0.8)
	return v


func _ask_render() -> void:
	if _ask.is_empty():
		return
	var ln: Dictionary = _ask.line
	var cursor := "█" if int(Time.get_ticks_msec() / 400) % 2 == 0 else " "
	var s: String = _ask.label + _ask.buf + cursor
	ln.segs = [[s, false]]
	ln.n = s.length()
	_render()


func _possess_input(word: String) -> void:
	await get_tree().create_timer(1.8, false).timeout
	if _ask.is_empty() or _ask.buf != "":
		return
	_ask.locked = true
	for ch in word:
		if _ask.is_empty():
			return
		_ask.buf += ch
		Sfx.play("metalClick", -18.0, 2.0)
		_ask_render()
		await get_tree().create_timer(0.14, false).timeout
	await get_tree().create_timer(1.0, false).timeout
	while not _ask.is_empty() and _ask.buf != "":
		_ask.buf = _ask.buf.substr(0, _ask.buf.length() - 1)
		_ask_render()
		await get_tree().create_timer(0.045, false).timeout
	if not _ask.is_empty():
		_ask.locked = false


## Touches clavier transmises par main.gd quand le joueur est assis devant l'écran.
## Renvoie true si la touche a servi.
func key_input(e: InputEventKey) -> bool:
	if not e.pressed or e.echo and _ask.is_empty():
		return false
	if _waiting_any:
		_any_key = true
		return true
	if not _choice.is_empty():
		var k := e.physical_keycode
		for i in _choice.n:
			if k == KEY_1 + i or k == KEY_KP_1 + i:
				_choice.picked = i
				return true
		return false
	if not _ask.is_empty():
		if _ask.locked:
			return true
		if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
			_ask.done = true
		elif e.keycode == KEY_BACKSPACE:
			_ask.buf = (_ask.buf as String).substr(0, maxi(0, (_ask.buf as String).length() - 1))
		elif e.unicode >= 32 and (_ask.buf as String).length() < 18:
			_ask.buf += char(e.unicode)
			Sfx.play("metalClick", -22.0, 2.2)
		_ask_render()
		return true
	if narrating and (e.physical_keycode == KEY_SPACE or e.keycode == KEY_ENTER):
		fast = true
		return true
	return false


func wants_keys() -> bool:
	return mode == "seance"


# ------------------------------------------------------------------ fins

func found_endings() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(ENDS_PATH) != OK:
		return []
	return cfg.get_value("fins", "trouvees", [])


func save_ending(id: String) -> Array:
	var got := found_endings()
	if not got.has(id):
		got.append(id)
	var cfg := ConfigFile.new()
	cfg.set_value("fins", "trouvees", got)
	cfg.save(ENDS_PATH)
	return got


## Affiche l'écran de fin (fins trouvées, « ???? » pour les autres) et prévient main.gd.
func show_end(id: String) -> void:
	narrating = false
	var got := save_ending(id)
	await line("", "n", 0.0, 0.0)
	await line("FIN · %s" % ENDS.get(id, id), "n", 0.03, 0.5)
	await line("FINS DÉCOUVERTES : %d / %d" % [got.size(), ENDS.size()], "dim", 0.01, 0.2)
	var list := ""
	for k in ENDS:
		list += ("%s   " % ENDS[k]) if got.has(k) else "????   "
	await line(list, "dim", 0.004, 0.4)
	mode = "done"
	ended.emit(id)
