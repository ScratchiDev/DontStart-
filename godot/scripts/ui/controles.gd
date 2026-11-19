class_name Controles
extends RefCounted
## Commandes du jeu (lot V3-INTERFACE) : actions, touches par défaut, remappage clavier et souris (deux
## emplacements par action, enregistrés par game.gd dans settings.cfg, section [touches]), boutons et sticks
## de la manette (fixes), noms affichés des touches et des boutons (texte simple, aucun logo).
## Appliqué à l'exécution par InputMap ; project.godot n'est pas modifié.
## Touches physiques : « W » est la touche en haut à gauche (Z sur un clavier AZERTY) ; le nom affiché suit la
## disposition du clavier (DisplayServer.keyboard_get_keycode_from_physical).

## Actions remappables, dans l'ordre de l'écran Commandes : [id, libellé].
const ACTIONS := [
	["move_forward", "Avancer"],
	["move_back", "Reculer"],
	["move_left", "Aller à gauche"],
	["move_right", "Aller à droite"],
	["sprint", "Courir"],
	["crouch", "S'accroupir"],
	["interact", "Agir, ramasser, lire"],
	["flashlight", "Lampe de poche"],
	["inventory", "Inventaire"],
	["transcript", "Transcription d'un document"],
]
## Action fixe (jamais remappée : on ne peut pas s'enfermer dehors) : Échap ouvre et ferme le menu.
const FIXED := {"pause": KEY_ESCAPE}
const SLOTS := 2

## Emplacements par défaut : "k<code physique>" (clavier), "m<bouton>" (souris), "" (vide).
const DEFAULTS := {
	"move_forward": ["k%d" % KEY_W, "k%d" % KEY_UP],
	"move_back": ["k%d" % KEY_S, "k%d" % KEY_DOWN],
	"move_left": ["k%d" % KEY_A, "k%d" % KEY_LEFT],
	"move_right": ["k%d" % KEY_D, "k%d" % KEY_RIGHT],
	"sprint": ["k%d" % KEY_SHIFT, ""],
	"crouch": ["k%d" % KEY_C, "k%d" % KEY_CTRL],
	"interact": ["k%d" % KEY_E, "m%d" % MOUSE_BUTTON_LEFT],
	"flashlight": ["k%d" % KEY_F, ""],
	"inventory": ["k%d" % KEY_TAB, "k%d" % KEY_I],
	"transcript": ["k%d" % KEY_T, ""],
}
## Manette (disposition « Xbox », la plus répandue sur PC) : boutons, ou [axe, sens] pour les sticks.
const PAD := {
	"move_forward": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [[JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"sprint": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_LEFT_STICK],
	"crouch": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_STICK],
	"interact": [JOY_BUTTON_A],
	"flashlight": [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER],
	"inventory": [JOY_BUTTON_BACK],
	"transcript": [JOY_BUTTON_X],
	"pause": [JOY_BUTTON_START],
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "Vue",
	JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "Croix ↑",
	JOY_BUTTON_DPAD_DOWN: "Croix ↓", JOY_BUTTON_DPAD_LEFT: "Croix ←", JOY_BUTTON_DPAD_RIGHT: "Croix →",
}
## Même manette, noms d'une manette PlayStation (texte, pas de symbole).
const PAD_NAMES_PS := {
	JOY_BUTTON_A: "Croix", JOY_BUTTON_B: "Rond", JOY_BUTTON_X: "Carré", JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_BACK: "Partage", JOY_BUTTON_START: "Options", JOY_BUTTON_LEFT_SHOULDER: "L1",
	JOY_BUTTON_RIGHT_SHOULDER: "R1",
}
const KEY_FR := {
	"Shift": "Maj", "Ctrl": "Ctrl", "Escape": "Échap", "Space": "Espace", "Enter": "Entrée", "Tab": "Tab",
	"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Backspace": "Retour arr.", "BackSpace": "Retour arr.",
	"Delete": "Suppr", "CapsLock": "Verr. maj", "Alt": "Alt", "Insert": "Inser", "Home": "Début", "End": "Fin",
	"PageUp": "Page ↑", "PageDown": "Page ↓", "Kp Enter": "Entrée (pavé)", "Meta": "Windows",
}


static func label_of(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return action


static func defaults() -> Dictionary:
	var d := {}
	for k in DEFAULTS:
		d[k] = (DEFAULTS[k] as Array).duplicate()
	return d


## Crée les actions (touches par défaut, manette) : une fois, au lancement (Game._setup_input).
static func setup() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
	for k in FIXED:
		if not InputMap.has_action(k):
			InputMap.add_action(k)
		var e := InputEventKey.new()
		e.physical_keycode = FIXED[k]
		InputMap.action_add_event(k, e)
	for k in PAD:
		if not InputMap.has_action(k):
			InputMap.add_action(k)
		for p in PAD[k]:
			if p is Array:
				var m := InputEventJoypadMotion.new()
				m.axis = p[0]
				m.axis_value = p[1]
				m.device = -1
				InputMap.action_add_event(k, m)
			else:
				var b := InputEventJoypadButton.new()
				b.button_index = p
				b.device = -1
				InputMap.action_add_event(k, b)
	apply(defaults())


## Remplace les touches clavier et souris des actions remappables (la manette ne change pas).
static func apply(bindings: Dictionary) -> void:
	for a in ACTIONS:
		var id: String = a[0]
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		for e in InputMap.action_get_events(id):
			if e is InputEventKey or e is InputEventMouseButton:
				InputMap.action_erase_event(id, e)
		var slots: Array = bindings.get(id, DEFAULTS[id])
		for s in slots:
			var ev := to_event(str(s))
			if ev:
				InputMap.action_add_event(id, ev)


## Lit les emplacements enregistrés (settings.cfg, [touches]) ; ce qui manque ou est illisible garde la valeur
## par défaut.
static func sanitize(raw: Variant) -> Dictionary:
	var d := defaults()
	if not raw is Dictionary:
		return d
	for k in raw:
		if not DEFAULTS.has(k):
			continue
		var v: Variant = raw[k]
		if not v is Array:
			continue
		var out: Array = []
		for i in SLOTS:
			var s := str((v as Array)[i]) if i < (v as Array).size() else ""
			out.append(s if s == "" or to_event(s) != null else "")
		d[k] = out
	return d


static func to_event(s: String) -> InputEvent:
	if s.length() < 2 or not s.substr(1).is_valid_int():
		return null
	var n := s.substr(1).to_int()
	if s[0] == "k" and n > 0:
		var e := InputEventKey.new()
		e.physical_keycode = n as Key
		return e
	if s[0] == "m" and n > 0:
		var m := InputEventMouseButton.new()
		m.button_index = n as MouseButton
		return m
	return null


## L'emplacement d'un événement de remappage (touche ou bouton de la souris appuyés), "" s'il ne convient pas.
static func from_event(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if code == KEY_NONE or code == KEY_ESCAPE:
			return ""
		return "k%d" % code
	if e is InputEventMouseButton:
		var b := (e as InputEventMouseButton).button_index
		if b in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return ""
		return "m%d" % b
	return ""


## Nom affiché d'un emplacement (« Z », « Maj », « Clic gauche ») ; « — » s'il est vide.
static func slot_name(s: String) -> String:
	if s == "":
		return "—"
	var n := s.substr(1).to_int()
	if s[0] == "m":
		match n:
			MOUSE_BUTTON_LEFT: return "Clic gauche"
			MOUSE_BUTTON_RIGHT: return "Clic droit"
			MOUSE_BUTTON_MIDDLE: return "Clic milieu"
			MOUSE_BUTTON_XBUTTON1: return "Souris 4"
			MOUSE_BUTTON_XBUTTON2: return "Souris 5"
		return "Souris %d" % n
	return key_name(n)


static func key_name(physical: int) -> String:
	var code := physical
	if DisplayServer.get_name() != "headless":
		var k := DisplayServer.keyboard_get_keycode_from_physical(physical as Key)
		if k != KEY_NONE:
			code = k
	var t := OS.get_keycode_string(code)
	if KEY_FR.has(t):
		return KEY_FR[t]
	if t.length() == 1:
		return t.to_upper()
	return t


## Conflits : { "action/emplacement": [autres actions sur la même touche] } (vide s'il n'y en a pas).
static func conflicts(bindings: Dictionary) -> Dictionary:
	var by_key := {}
	for a in ACTIONS:
		var slots: Array = bindings.get(a[0], [])
		for i in slots.size():
			var s := str(slots[i])
			if s == "":
				continue
			if not by_key.has(s):
				by_key[s] = []
			if not (by_key[s] as Array).has(a[0]):
				(by_key[s] as Array).append(a[0])
	var out := {}
	for a in ACTIONS:
		var slots: Array = bindings.get(a[0], [])
		for i in slots.size():
			var s := str(slots[i])
			if s != "" and (by_key[s] as Array).size() > 1:
				out["%s/%d" % [a[0], i]] = (by_key[s] as Array).filter(func(x: String) -> bool: return x != a[0])
	return out


## Assigne « slot » (touche) à l'emplacement i de l'action ; si une autre action l'utilise, les deux
## emplacements échangent leurs touches. Renvoie l'action avec qui l'échange s'est fait ("" sinon).
static func assign(bindings: Dictionary, action: String, i: int, slot: String) -> String:
	var mine: Array = bindings[action]
	var old := str(mine[i])
	var swapped := ""
	if slot != "":
		for a in ACTIONS:
			var other: Array = bindings[a[0]]
			for j in other.size():
				if str(other[j]) == slot and not (a[0] == action and j == i):
					other[j] = old if a[0] != action else ""
					swapped = a[0] if a[0] != action else ""
	mine[i] = slot
	return swapped


## Le nom de la première touche (ou du premier bouton de manette) d'une action, pour les invites.
static func glyph(action: String, pad: bool) -> String:
	if pad:
		var names := pad_names()
		for e in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
			if e is InputEventJoypadButton:
				return str(names.get((e as InputEventJoypadButton).button_index, "B%d" % (e as InputEventJoypadButton).button_index))
		return "?"
	if FIXED.has(action):
		return key_name(FIXED[action])
	var slots: Array = Game.bindings.get(action, DEFAULTS.get(action, [""]))
	for s in slots:
		if str(s) != "":
			var n := slot_name(str(s))
			return "Clic" if n == "Clic gauche" else n
	return "—"


## Noms des boutons selon la manette branchée (PlayStation si son nom l'indique, sinon disposition Xbox).
static func pad_names() -> Dictionary:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		var n := Input.get_joy_name(pads[0]).to_lower()
		if n.contains("ps4") or n.contains("ps5") or n.contains("dualsense") or n.contains("dualshock") or n.contains("playstation") or n.contains("ps3"):
			var d := PAD_NAMES.duplicate()
			d.merge(PAD_NAMES_PS, true)
			return d
	return PAD_NAMES


## Le bouton de manette d'une action (« A », « Croix »…), pour l'écran Commandes.
static func pad_glyphs(action: String) -> String:
	if not PAD.has(action):
		return ""
	var names := pad_names()
	var parts: Array[String] = []
	for p in PAD[action]:
		if p is Array:
			var ax: int = p[0]
			var neg: bool = float(p[1]) < 0.0
			parts.append("Stick G " + (("↑" if neg else "↓") if ax == JOY_AXIS_LEFT_Y else ("←" if neg else "→")))
		else:
			parts.append(str(names.get(p, "B%d" % p)))
	return " / ".join(parts)
