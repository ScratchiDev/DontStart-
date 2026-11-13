extends "res://scripts/terminal.gd"
## Terminal qui enregistre tout ce qu'on lui demande (relecteur 0.3.2, textes et règles ; exclu de
## l'export). Chaque appel est noté dans « rec » : [genre, …, temps en ms].

var rec: Array = []


func line(s: String, kind := "n", speed := 0.024, pause := 0.28) -> void:
	rec.append(["line", fill(s), kind, speed, Time.get_ticks_msec()])
	await super(s, kind, speed, pause)


func level(label: String, title: String) -> void:
	rec.append(["level", label, title, Time.get_ticks_msec()])
	await super(label, title)


func pick(opts: Array, time := 12.0, worst := 0, extra := Callable(), timeout_fear := 5.0, mark_worst := true) -> int:
	var filled: Array = []
	for o in opts:
		filled.append(fill(str(o)))
	var t0 := Time.get_ticks_msec()
	var r: int = await super(opts, time, worst, extra, timeout_fear, mark_worst)
	# options telles qu'affichées : [n] texte et leur état final (picked / dead)
	var shown: Array = []
	for ln in lines:
		if str(ln.kind) in ["picked", "dead", "opt"]:
			var t := ""
			for sg in ln.segs:
				t += str(sg[0])
			shown.append([t, str(ln.kind)])
	rec.append(["pick", filled, time, worst, timeout_fear, r, last_timeout, (Time.get_ticks_msec() - t0) / 1000.0, shown, Time.get_ticks_msec()])
	return r


func set_heart(bpm: int) -> void:
	rec.append(["heart", bpm, Time.get_ticks_msec()])
	super(bpm)


func power_off() -> void:
	rec.append(["power_off", Time.get_ticks_msec()])
	await super()


func watch_face(opacity: float, seconds := 1.5) -> void:
	rec.append(["face", opacity, Time.get_ticks_msec()])
	super(opacity, seconds)
