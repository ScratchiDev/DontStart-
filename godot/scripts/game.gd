extends Node
## Singleton « Game » : touches, réglages sauvegardés, état de la partie, utilitaires communs.

signal objective_changed(text: String)
signal hint_requested(text: String, seconds: float)
signal settings_changed
signal inventory_changed
signal item_added(id: String, label: String)
signal peur_changed(v: float)      # PEUR MESURÉE (0..100) a changé
signal absorbed                    # la jauge vient d'atteindre 100 (fin ABSORBÉ ; à l'écouteur de voir s'il est en séance)
signal flag_changed(id: String, v: Variant)

const SETTINGS_PATH := "user://settings.cfg"
## Sauvegarde à un emplacement, écrite aux points de passage (C1 « acte2 », C2 « miroir », C3 « convocation »).
const SAVE_PATH := "user://sauvegarde.json"
const SAVE_PATH_TEST := "user://sauvegarde_autotest.json"   # l'autotest n'écrase jamais la partie du joueur
## Sortes d'objets de l'inventaire, dans l'ordre d'affichage.
const KINDS := ["arme", "outil", "cle", "doc", "objet"]
## Les quatre pièces de l'arme dessinées par Manon (croquis du Fractionneur).
const WEAPON_PARTS := ["seche_cheveux", "antenne", "boussole", "bobine"]

# --- réglages (sauvegardés) ---
var mouse_sensitivity := 0.0022
var master_volume := 0.85
var fullscreen := true
var high_quality := true
var reduced_scares := false   # le visage reste sur l'écran, sons de sursaut plus bas, pas de secousse
var soft_flashes := false     # éclairs adoucis, pas de flash plein écran
var whispers := true          # chuchotements par la synthèse vocale de Windows
var sound_captions := false   # sous-titres des sons importants (« [Coups dans le radiateur, en bas] »)
var seen_warning := false     # avertissement de photosensibilité déjà montré (premier lancement)

# --- état de la partie ---
var hero := "alexandre"   # « alexandre » ou « aurelia », choisi sur l'écran-titre
var has_floppy := false
## Inventaire : liste de { id, name, desc, kind } ; kind = "arme" (pièce de l'arme), "outil", "cle", "doc" ou "objet".
var items: Array[Dictionary] = []
## Choix faits pendant les séances (repris par les versions suivantes) : enregistrés dans user://choix.cfg.
var choices := {}
var face_scares := 0     # sursauts « visage » joués (au plus un par acte)
var phase := "title"   # title, room, seated, end
## État du monde (sauvegardé) : drapeaux posés par le scénario et les pièces (« p4_reel_fait », « box_debranchee »…).
var flags := {}
## PEUR MESURÉE hors du terminal : la puissance de l'entité (0..100). Chaque acte relève le plancher.
var peur := 0.0
var peur_floor := 0.0
var _absorbed_sent := false
## Stress caché (0..1) : battement de cœur, grain. Retombe tout seul (0,08 par seconde, × stress_decay_mult).
var stress := 0.0
var stress_decay_mult := 1.0     # 2 dans la chambre de Manon (refuge) : le scénario le règle
const STRESS_DECAY := 0.08
var _grain_base := -1.0
var _grain_set := 0.0
## Heure de la maison pour les écrans (« 03:2x ») : minutes après 3 h 20 depuis clock_origin_ms.
var clock_origin_ms := 0

# --- tests automatisés : godot --path godot -- --autotest --shots=/chemin ---
var autotest := false
var shots_dir := ""
var preview_room := ""
var seance_picks: Array = []   # --seance=2,1,0/aube : séance seule, choix et saisies imposés (tests des fins)
var seance_asks: Array = []
var seance_only := false   # --preview=<pièce> : vues d'une pièce de la maison, puis quitte
var load_arg := ""         # --charger=C1|C2|C3 : recharger ce point de passage
var miroir_arg := ""       # --miroir=fixe|retourne|fui : issue imposée du P4 réel (autotest)
var seance2_arg := ""      # --seance2=confirmer|changer|delai : issue imposée de la séance 2 (autotest)
var indices := false       # --indices : minuteries des indices accélérées (×30)
var absorbe_test := false  # --absorbe : jauge forcée à 100 dans le couloir (autotest)

var fonts := {}


func _enter_tree() -> void:
	_setup_input()
	_load_fonts()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--preview="):
			preview_room = a.substr(10)
			autotest = true
		elif a.begins_with("--seance="):
			seance_only = true
			var parts := a.substr(9).split("/")
			for x in parts[0].split(","):
				if x != "":
					seance_picks.append(int(x))
			if parts.size() > 1:
				for x in parts[1].split(","):
					if x != "":
						seance_asks.append(x)
		elif a.begins_with("--hero="):
			hero = a.substr(7)
		elif a.begins_with("--charger="):
			load_arg = a.substr(10).to_upper()
		elif a.begins_with("--miroir="):
			miroir_arg = a.substr(9)
		elif a.begins_with("--seance2="):
			seance2_arg = a.substr(10)
		elif a == "--indices":
			indices = true
		elif a == "--absorbe":
			absorbe_test = true
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
	_keys("inventory", [KEY_TAB, KEY_I])
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
	reduced_scares = cfg.get_value("accessibilite", "sursauts_reduits", reduced_scares)
	soft_flashes = cfg.get_value("accessibilite", "eclairs_adoucis", soft_flashes)
	whispers = cfg.get_value("audio", "chuchotements", whispers)
	sound_captions = cfg.get_value("accessibilite", "sous_titres_sons", sound_captions)
	seen_warning = cfg.get_value("accessibilite", "avertissement_vu", seen_warning)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "high_quality", high_quality)
	cfg.set_value("accessibilite", "sursauts_reduits", reduced_scares)
	cfg.set_value("accessibilite", "eclairs_adoucis", soft_flashes)
	cfg.set_value("audio", "chuchotements", whispers)
	cfg.set_value("accessibilite", "sous_titres_sons", sound_captions)
	cfg.set_value("accessibilite", "avertissement_vu", seen_warning)
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	if not autotest:
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()


var objective_text := ""     # objectif affiché (première ligne)
var objective_sub := ""      # seconde ligne (« Croquis de Maman : 1/4 · Papi est à la cave »)


## Objectif du HUD, sur deux lignes : « text » puis, plus petit, « sub ».
func objective(text: String, sub := "") -> void:
	objective_text = text
	objective_sub = sub
	objective_changed.emit(text if sub == "" else text + "\n" + sub)


func hint(text: String, seconds := 3.5) -> void:
	hint_requested.emit(text, seconds)


## Voix chuchotée du système (synthèse vocale de Windows), si une voix française est installée.
func whisper(text: String) -> void:
	if autotest or not whispers:
		return
	var voices := DisplayServer.tts_get_voices_for_language("fr")
	if voices.is_empty():
		return
	DisplayServer.tts_speak(text, voices[0], int(master_volume * 45.0), 0.3, 0.6)


## Prénom du personnage joué.
func hero_name() -> String:
	return "Aurèlia" if hero == "aurelia" else "Alexandre"


## Accord en genre : Game.g("assis", "assise").
func g(masc: String, fem: String) -> String:
	return fem if hero == "aurelia" else masc


# ------------------------------------------------------------------ inventaire

func add_item(id: String, label: String, desc := "", kind := "objet") -> void:
	if has_item(id):
		return
	items.append({"id": id, "name": label, "desc": desc, "kind": kind})
	item_added.emit(id, label)
	inventory_changed.emit()


func has_item(id: String) -> bool:
	for it in items:
		if it.id == id:
			return true
	return false


func remove_item(id: String) -> void:
	for i in items.size():
		if items[i].id == id:
			items.remove_at(i)
			inventory_changed.emit()
			return


func count_kind(kind: String) -> int:
	var n := 0
	for it in items:
		if it.kind == kind:
			n += 1
	return n


# ------------------------------------------------------------------ choix des séances

const CHOICES_PATH := "user://choix.cfg"


func save_choices() -> void:
	if autotest:
		return
	var cfg := ConfigFile.new()
	for k in choices:
		cfg.set_value("seance1", k, choices[k])
	cfg.set_value("seance1", "heros", hero)
	cfg.save(CHOICES_PATH)


# ------------------------------------------------------------------ PEUR MESURÉE, stress, drapeaux

## Ajoute « v » à la jauge (négatif pour la faire baisser), bornée entre le plancher de l'acte et 100.
## À 100 : signal « absorbed » (une fois, jusqu'à ce que la jauge redescende).
func add_peur(v: float, why := "") -> void:
	set_peur(peur + v, why)


func set_peur(v: float, why := "") -> void:
	var nv := clampf(v, peur_floor, 100.0)
	if is_equal_approx(nv, peur):
		return
	peur = nv
	if autotest and why != "":
		print("PEUR %.1f (%s)" % [peur, why])
	peur_changed.emit(peur)
	if peur >= 100.0 and not _absorbed_sent:
		_absorbed_sent = true
		absorbed.emit()
	elif peur < 100.0:
		_absorbed_sent = false


## Relève le plancher de l'acte (II : 25) ; la jauge remonte au moins jusque-là.
func set_peur_floor(v: float) -> void:
	peur_floor = clampf(v, 0.0, 100.0)
	if peur < peur_floor:
		set_peur(peur_floor, "plancher")


## Couleur de la jauge (anneau de Nestor, phosphore) : vert < 34, ambre < 67, rouge sinon.
func peur_color(v := -1.0) -> Color:
	var x := peur if v < 0.0 else v
	if x < 34.0:
		return Color(0.25, 1.0, 0.35)
	if x < 67.0:
		return Color(1.0, 0.62, 0.12)
	return Color(1.0, 0.12, 0.08)


func add_stress(v: float) -> void:
	stress = clampf(stress + v, 0.0, 1.0)


func flag(id: String, default_value: Variant = false) -> Variant:
	return flags.get(id, default_value)


func set_flag(id: String, v: Variant = true) -> void:
	flags[id] = v
	flag_changed.emit(id, v)


## Heure de la maison sur les écrans : « 03:2x » (x avance d'une minute par minute de jeu, jusqu'à 03:29).
func house_clock(seconds := false) -> String:
	var t := (Time.get_ticks_msec() - clock_origin_ms) / 1000.0
	var m := mini(20 + int(t / 60.0), 29)
	if seconds:
		return "03:%02d:%02d" % [m, int(t) % 60]
	return "03:%02d" % m


func _process(delta: float) -> void:
	if stress > 0.0:
		stress = maxf(0.0, stress - STRESS_DECAY * stress_decay_mult * delta)
	# le stress déteint sur le grain de l'image (filtre rétro)
	var want := snappedf(stress * 0.05, 0.001)
	if want == _grain_set:
		return
	var retro := get_tree().get_first_node_in_group("retro") as CanvasItem
	if retro and retro.material is ShaderMaterial:
		var sm := retro.material as ShaderMaterial
		if _grain_base < 0.0:
			var g: Variant = sm.get_shader_parameter("grain")
			_grain_base = float(g) if g != null else 0.045
		sm.set_shader_parameter("grain", _grain_base + want)
		_grain_set = want


# ------------------------------------------------------------------ nouvelle partie, sauvegarde

## Remet l'état de la partie à zéro (nouvelle partie). Les réglages et les fins trouvées restent.
func reset_state() -> void:
	items.clear()
	choices = {}
	flags = {}
	has_floppy = false
	face_scares = 0
	peur = 0.0
	peur_floor = 0.0
	_absorbed_sent = false
	stress = 0.0
	stress_decay_mult = 1.0
	objective_text = ""
	objective_sub = ""
	inventory_changed.emit()
	peur_changed.emit(peur)


func save_path() -> String:
	return SAVE_PATH_TEST if autotest else SAVE_PATH


## Écrit le point de passage « id » (C1, C2, C3…) : héros, objets, choix, drapeaux, jauge, position.
func save_checkpoint(id: String, pos: Vector3, yaw: float) -> bool:
	var d := {
		"version": ProjectSettings.get_setting("application/config/version", ""),
		"checkpoint": id,
		"hero": hero,
		"items": items.duplicate(true),
		"choices": choices.duplicate(true),
		"flags": flags.duplicate(true),
		"peur": peur,
		"peur_floor": peur_floor,
		"face_scares": face_scares,
		"pos": [pos.x, pos.y, pos.z],
		"yaw": yaw,
		"date": Time.get_datetime_string_from_system(),
	}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		push_warning("sauvegarde impossible : %s" % save_path())
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if autotest:
		print("SAUVEGARDE %s · peur %.1f · %d objets · %d drapeaux" % [id, peur, items.size(), flags.size()])
	return true


func has_save() -> bool:
	return FileAccess.file_exists(save_path())


## Lit la sauvegarde (dictionnaire vide s'il n'y en a pas). « pos » est rendu en Vector3.
func load_checkpoint() -> Dictionary:
	if not has_save():
		return {}
	var txt := FileAccess.get_file_as_string(save_path())
	var d: Variant = JSON.parse_string(txt)
	if not d is Dictionary:
		return {}
	var out: Dictionary = d
	var p: Array = out.get("pos", [0.0, 0.0, 0.0])
	out["pos"] = Vector3(float(p[0]), float(p[1]), float(p[2]))
	out["yaw"] = float(out.get("yaw", 0.0))
	return out


## Remet l'état de la partie tel qu'il était au point de passage (sans toucher au monde 3D :
## les pièces s'en chargent avec leur restore()).
func apply_checkpoint(d: Dictionary) -> void:
	if d.is_empty():
		return
	hero = d.get("hero", hero)
	items.clear()
	for it in d.get("items", []):
		var x: Dictionary = it
		items.append({"id": str(x.get("id", "")), "name": str(x.get("name", "")), "desc": str(x.get("desc", "")), "kind": str(x.get("kind", "objet"))})
	choices = (d.get("choices", {}) as Dictionary).duplicate(true)
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	face_scares = int(d.get("face_scares", face_scares))
	peur_floor = float(d.get("peur_floor", 0.0))
	peur = clampf(float(d.get("peur", peur_floor)), peur_floor, 100.0)
	_absorbed_sent = peur >= 100.0
	has_floppy = false
	stress = 0.0
	inventory_changed.emit()
	peur_changed.emit(peur)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()))
