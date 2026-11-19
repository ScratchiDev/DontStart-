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
signal saved(id: String)                 # un point de passage vient d'être écrit (indice d'enregistrement du HUD)
signal input_device_changed(pad: bool)   # dernier périphérique utilisé : manette (vrai) ou clavier et souris
signal ui_settings_changed               # réglage d'interface, de son ou de commandes (sans réappliquer l'image)

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
## Préréglage d'image : Qualite.BASSE, MOYENNE, ELEVEE ou ULTRA (scripts/qualite.gd ; settings.cfg
## « video/qualite »). Au premier lancement, d'après la carte graphique (Qualite.detect). En rendu
## logiciel, le niveau appliqué est plafonné à Élevée (Qualite.effective).
var quality: int = Qualite.ELEVEE
## Vrai si aucun réglage n'a choisi le niveau (ni settings.cfg, ni --qualite) : détecté (Main le refait
## après la construction, si l'autoload a interrogé la carte trop tôt).
var quality_auto := false
var _quality_saved := -1      # --qualite=… : le niveau d'avant, celui qu'on enregistre
## L'ancienne case « Qualité élevée » (0.3.3) : vraie à partir d'Élevée ; la cocher donne Élevée, la
## décocher Basse.
var high_quality: bool:
	get:
		return quality >= Qualite.ELEVEE
	set(v):
		quality = Qualite.ELEVEE if v else Qualite.BASSE
## Luminosité (0 = sombre, 1 = clair ; 0,5 par défaut) : point noir et pied de courbe du rendu net
## (Main.net_curve) ; sans effet en style rétro.
var luminosite := 0.5
## Champ de vision vertical de la caméra du joueur, en degrés (55 à 80 ; 62 par défaut, soit environ
## 95° en horizontal en 16:9). Appliqué par le joueur (lot V2-PRESENCE).
const FOV_DEFAULT := 62.0
const FOV_MIN := 55.0
const FOV_MAX := 80.0
var fov := FOV_DEFAULT
## « Mouvements de la caméra » (0 à 1) : multiplie la respiration, l'impact des pas, le roulis et les
## secousses de la caméra (couche « présence », lot V2-PRESENCE). 0 = la caméra de la 0.3.3.
var mouvements_camera := 1.0
## « Mains visibles » : les mains du joueur et sa lampe de poche à l'écran (Viewmodel) ; sinon, la lampe
## éclaire depuis l'épaule, comme en 0.3.3.
var mains_visibles := true
## Style rétro (pixels) : image 640×360 agrandie sans lissage, palette réduite et tramage (l'aspect des
## versions 0.1 à 0.3). Désactivé : rendu net à la résolution de l'écran (main.gd, _apply_video).
var style_retro := false
var reduced_scares := false   # le visage reste sur l'écran, sons de sursaut plus bas, pas de secousse
var soft_flashes := false     # éclairs adoucis, pas de flash plein écran
var whispers := false         # chuchotements par la synthèse vocale de Windows (désactivés par défaut, C7)
var sound_captions := false   # sous-titres des sons importants (« [Coups dans le radiateur, en bas] »)
var seen_warning := false     # avertissement de photosensibilité déjà montré (premier lancement)
# --- réglages ajoutés par le lot V3-INTERFACE (écran Options à onglets)
## Touches clavier et souris des actions remappables : { action: ["k<code physique>"|"m<bouton>"|"", …] }
## (scripts/ui/controles.gd ; settings.cfg, section [touches]). La manette garde sa disposition.
var bindings := Controles.defaults()
var pad_sensitivity := 1.0     # regard au stick droit (0,3 à 2,5)
var pad_invert_y := false
var pad_deadzone := 0.15       # zone morte radiale du stick droit (0,05 à 0,35)
var pad_active := false        # dernier périphérique utilisé : manette (écrit par Manette)
## Respiration du personnage : 0 « Oui », 1 « Discrète » (−6 dB), 2 « Non » (Sfx.breath_on, breath_gain_db).
var respiration := 0
var vol_ambiance := 1.0        # musique et ambiance (bus Ambiance), 0 à 1
var vol_voix := 1.0            # voix et entité (bus Voix), 0 à 1
var aberration := true         # aberration chromatique (post : repos et peur) ; coupée = 0
var subtitle_bg := true        # fond des sous-titres (cartouche noir translucide)
var subtitle_size := 0         # 0 normale, 1 grande
var crosshair_mode := 0        # point de visée : 0 contextuel (seulement sur un objet), 1 toujours
var chapter_cards := true      # cartes de chapitre (« Acte I — Lecteur A: »)
var objective_mode := 0        # objectif : 0 s'efface (revient au changement, à Tab, après 60 s), 1 toujours
var transcript_always := false # transcription des documents : affichée d'office (sinon touche T / X)
var manette: Manette

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
## Stress caché (0..1) : battement de cœur (Sfx), grain. Les impulsions viennent de Haunt (scènes
## écrites, événements, sursauts). Il retombe tout seul de (STRESS_DECAY + STRESS_DECAY_K × stress) par
## seconde, × stress_decay_mult : vite quand il est haut, doucement à la fin (≈ 0,08/s vers 0,25).
## De 1 (le maximum), le cœur repasse sous −36 dB en 9 s ; d'une impulsion de 0,35, en 4 s (C4).
var stress := 0.0
var stress_decay_mult := 1.0     # 2 dans la chambre de Manon (refuge) : le scénario le règle
const STRESS_DECAY := 0.04       # part constante de la baisse (par seconde)
const STRESS_DECAY_K := 0.15     # part proportionnelle au stress (par seconde)
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
var quality_arg := -1      # --qualite=basse|moyenne|elevee|ultra : niveau imposé, non enregistré

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
		elif a.begins_with("--qualite="):
			quality_arg = Qualite.from_name(a.substr(10))
			if quality_arg < 0:
				push_warning("--qualite : basse, moyenne, elevee ou ultra (reçu « %s »)" % a.substr(10))
	_load_settings()
	apply_bindings()
	# --qualite=… : le niveau est imposé pour ce lancement, sans être enregistré
	if quality_arg >= 0:
		_quality_saved = quality
		quality = quality_arg
		quality_auto = false
	if autotest:
		fullscreen = false
	apply_settings()


func _ready() -> void:
	# Alt+F4 ou la croix de la fenêtre : la même sortie que « Quitter » (voir quit_game)
	get_tree().auto_accept_quit = false
	manette = Manette.new()
	manette.name = "Manette"
	add_child(manette)
	# (les bus de Sfx, chargé après Game, existent à la fin de la première image)
	apply_ui_settings.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


var _quitting := false

## Quitte le jeu (menu « Quitter », fermeture de la fenêtre, fin de l'autotest).
## Contourne un blocage de Godot 4.7.2 : si l'on quitte pendant que des compilations de pipelines de
## basse priorité attendent dans la file du WorkerThreadPool (les premières secondes après l'affichage
## d'une vue neuve, par exemple juste après « Continuer »), la sortie attend des fils qui ne se
## réveillent jamais et la fenêtre se fige. On arrête le rendu (plus aucune compilation demandée), puis
## une tâche « barrière » de basse priorité passe après toutes celles déjà en file : quand elle a fini,
## la file est vide et la sortie ne peut plus se bloquer.
## Pendant cette attente (en général une fraction de seconde), le jeu ne tourne plus : arbre en pause,
## entrées ignorées, son coupé. Au-delà de 15 s, sortie forcée (la partie est déjà sauvegardée).
func quit_game(code := 0) -> void:
	if _quitting:
		return
	_quitting = true
	RenderingServer.render_loop_enabled = false
	get_tree().paused = true
	get_viewport().gui_disable_input = true
	AudioServer.set_bus_mute(0, true)
	var id := WorkerThreadPool.add_task(func() -> void: pass, false, "barrière avant la sortie")
	var t0 := Time.get_ticks_msec()
	while not WorkerThreadPool.is_task_completed(id):
		if Time.get_ticks_msec() - t0 > 15000:
			push_warning("Sortie : la file de tâches ne se vide pas, sortie forcée")
			OS.kill(OS.get_process_id())
			return
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(id)
	get_tree().quit(code)


## Actions et touches par défaut (scripts/ui/controles.gd) : les mêmes qu'avant (touches physiques : « W »
## est la touche en haut à gauche, donc Z sur un clavier AZERTY ; clic gauche pour agir), plus la manette et
## « transcript » (T : transcription d'un document). Les touches remappées sont appliquées après la lecture
## des réglages (apply_bindings).
func _setup_input() -> void:
	Controles.setup()


## Applique Game.bindings à l'InputMap (clavier et souris ; la manette ne change pas).
func apply_bindings() -> void:
	Controles.apply(bindings)


func _load_fonts() -> void:
	var pixel: FontFile = load("res://assets/fonts/VT323-Regular.ttf")
	pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel.hinting = TextServer.HINTING_NONE
	# VT323 a une ligature « fi » qui tient dans une seule case : « Tu confirmes ? » se lisait
	# « Tu confrmes ? », « vérifie » « vérine ». Coupée pour tout le jeu (terminal compris).
	pixel.opentype_feature_overrides = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
	fonts.pixel = pixel
	# aux 10 px des petites inscriptions (vignettes et bandeaux de la console), sans lissage, le « 1 »
	# de VT323 perd son drapeau et se lit « L » (« CAM L », « 0L/LL/2040 ») : la même police, lissée
	var small := pixel.duplicate() as FontFile
	small.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	fonts.pixel_small = small
	fonts.hand = load("res://assets/fonts/ReenieBeanie.ttf")
	fonts.mono = load("res://assets/fonts/IBMPlexMono-Regular.ttf")


## Lit les réglages (settings.cfg ; « path » : un autre fichier, pour les vérifications de l'autotest).
## Qualité : « video/qualite » (0 à 3) s'il existe, sinon l'ancienne case « video/high_quality » de la
## 0.3.3 (cochée → Élevée, décochée → Basse), sinon la détection de la carte (quality_auto).
func _load_settings(path := SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		quality = Qualite.detect()
		quality_auto = true
		return
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	master_volume = cfg.get_value("audio", "master_volume", master_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	quality_auto = false
	if cfg.has_section_key("video", "qualite"):
		quality = clampi(int(cfg.get_value("video", "qualite")), Qualite.BASSE, Qualite.ULTRA)
	elif cfg.has_section_key("video", "high_quality"):
		quality = Qualite.ELEVEE if bool(cfg.get_value("video", "high_quality")) else Qualite.BASSE
	else:
		quality = Qualite.detect()
		quality_auto = true
	luminosite = clampf(float(cfg.get_value("video", "luminosite", luminosite)), 0.0, 1.0)
	fov = clampf(float(cfg.get_value("video", "fov", fov)), FOV_MIN, FOV_MAX)
	mouvements_camera = clampf(float(cfg.get_value("confort", "mouvements_camera", mouvements_camera)), 0.0, 1.0)
	mains_visibles = bool(cfg.get_value("video", "mains_visibles", mains_visibles))
	style_retro = cfg.get_value("video", "style_retro", style_retro)
	reduced_scares = cfg.get_value("accessibilite", "sursauts_reduits", reduced_scares)
	soft_flashes = cfg.get_value("accessibilite", "eclairs_adoucis", soft_flashes)
	whispers = cfg.get_value("audio", "chuchotements", whispers)
	sound_captions = cfg.get_value("accessibilite", "sous_titres_sons", sound_captions)
	seen_warning = cfg.get_value("accessibilite", "avertissement_vu", seen_warning)
	# (V3-INTERFACE)
	var raw := {}
	if cfg.has_section("touches"):
		for k in cfg.get_section_keys("touches"):
			raw[k] = cfg.get_value("touches", k)
	bindings = Controles.sanitize(raw)
	pad_sensitivity = clampf(float(cfg.get_value("manette", "sensibilite", pad_sensitivity)), 0.3, 2.5)
	pad_invert_y = bool(cfg.get_value("manette", "inverser_vertical", pad_invert_y))
	pad_deadzone = clampf(float(cfg.get_value("manette", "zone_morte", pad_deadzone)), 0.05, 0.35)
	respiration = clampi(int(cfg.get_value("audio", "respiration", respiration)), 0, 2)
	vol_ambiance = clampf(float(cfg.get_value("audio", "volume_ambiance", vol_ambiance)), 0.0, 1.0)
	vol_voix = clampf(float(cfg.get_value("audio", "volume_voix", vol_voix)), 0.0, 1.0)
	aberration = bool(cfg.get_value("video", "aberration_chromatique", aberration))
	subtitle_bg = bool(cfg.get_value("accessibilite", "fond_sous_titres", subtitle_bg))
	subtitle_size = clampi(int(cfg.get_value("accessibilite", "taille_sous_titres", subtitle_size)), 0, 1)
	crosshair_mode = clampi(int(cfg.get_value("jeu", "point_de_visee", crosshair_mode)), 0, 1)
	chapter_cards = bool(cfg.get_value("jeu", "cartes_de_chapitre", chapter_cards))
	objective_mode = clampi(int(cfg.get_value("jeu", "objectif", objective_mode)), 0, 1)
	transcript_always = bool(cfg.get_value("jeu", "transcription", transcript_always))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	# (les deux clés : une 0.3.3 qui relirait ce fichier retrouverait sa case « Qualité élevée »)
	var q := quality if _quality_saved < 0 else _quality_saved
	cfg.set_value("video", "qualite", q)
	cfg.set_value("video", "high_quality", q >= Qualite.ELEVEE)
	cfg.set_value("video", "luminosite", luminosite)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "style_retro", style_retro)
	cfg.set_value("video", "mains_visibles", mains_visibles)
	cfg.set_value("confort", "mouvements_camera", mouvements_camera)
	cfg.set_value("accessibilite", "sursauts_reduits", reduced_scares)
	cfg.set_value("accessibilite", "eclairs_adoucis", soft_flashes)
	cfg.set_value("audio", "chuchotements", whispers)
	cfg.set_value("accessibilite", "sous_titres_sons", sound_captions)
	cfg.set_value("accessibilite", "avertissement_vu", seen_warning)
	# (V3-INTERFACE)
	for a in Controles.ACTIONS:
		cfg.set_value("touches", a[0], bindings.get(a[0], Controles.DEFAULTS[a[0]]))
	cfg.set_value("manette", "sensibilite", pad_sensitivity)
	cfg.set_value("manette", "inverser_vertical", pad_invert_y)
	cfg.set_value("manette", "zone_morte", pad_deadzone)
	cfg.set_value("audio", "respiration", respiration)
	cfg.set_value("audio", "volume_ambiance", vol_ambiance)
	cfg.set_value("audio", "volume_voix", vol_voix)
	cfg.set_value("video", "aberration_chromatique", aberration)
	cfg.set_value("accessibilite", "fond_sous_titres", subtitle_bg)
	cfg.set_value("accessibilite", "taille_sous_titres", subtitle_size)
	cfg.set_value("jeu", "point_de_visee", crosshair_mode)
	cfg.set_value("jeu", "cartes_de_chapitre", chapter_cards)
	cfg.set_value("jeu", "objectif", objective_mode)
	cfg.set_value("jeu", "transcription", transcript_always)
	cfg.save(SETTINGS_PATH)


## Le joueur choisit un niveau (menu « Qualité ») : il remplace aussi un --qualite de la ligne de commande.
func set_quality(q: int) -> void:
	quality = clampi(q, Qualite.BASSE, Qualite.ULTRA)
	_quality_saved = -1
	quality_auto = false
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	if not autotest:
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()
	if is_inside_tree():
		apply_ui_settings.call_deferred()


## Réglages légers (V3-INTERFACE) : touches, respiration, volumes par bus, aberration chromatique ; puis
## ui_settings_changed (HUD, menus). Sans réappliquer l'image (contrairement à apply_settings).
func apply_ui_settings() -> void:
	apply_bindings()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.set("breath_on", respiration != 2)
		sfx.set("breath_gain_db", -6.0 if respiration == 1 else 0.0)
	_bus_gain("Ambiance", vol_ambiance)
	_bus_gain("Voix", vol_voix)
	_apply_aberration()
	ui_settings_changed.emit()


## Gain d'un bus par un AudioEffectAmplify ajouté en fin de chaîne (marqué « reglage_volume ») : le volume du
## bus lui-même reste à Sfx (silence de l'entité, canard), les effets d'avant gardent leur rang.
func _bus_gain(bus_name: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	var amp: AudioEffectAmplify = null
	for k in AudioServer.get_bus_effect_count(i):
		var e := AudioServer.get_bus_effect(i, k)
		if e is AudioEffectAmplify and e.has_meta("reglage_volume"):
			amp = e
	if amp == null:
		if is_equal_approx(lin, 1.0):
			return
		amp = AudioEffectAmplify.new()
		amp.set_meta("reglage_volume", true)
		AudioServer.add_bus_effect(i, amp)
	amp.volume_db = linear_to_db(maxf(lin, 0.0001))


## « Aberration chromatique » coupée : le filtre plein écran (groupe « retro ») n'en met plus, ni au repos ni
## avec la peur. Appliqué après main._apply_video (appel différé), qui remet la valeur du style à chaque
## changement de réglage d'image.
func _apply_aberration() -> void:
	if not is_inside_tree():
		return
	var retro := get_tree().get_first_node_in_group("retro") as CanvasItem
	if retro == null or not retro.material is ShaderMaterial:
		return
	var sm := retro.material as ShaderMaterial
	if not aberration:
		sm.set_shader_parameter("aberration", 0.0)
		sm.set_shader_parameter("corruption_aberration", 0.0)
	else:
		sm.set_shader_parameter("corruption_aberration", 0.0044)


var objective_text := ""     # objectif affiché (première ligne)
var objective_sub := ""      # seconde ligne (« Croquis de Maman : 1/4 · Papi est à la cave »)


## Objectif du HUD, sur deux lignes : « text » puis, plus petit, « sub ».
func objective(text: String, sub := "") -> void:
	objective_text = text
	objective_sub = sub
	objective_changed.emit(text if sub == "" else text + "\n" + sub)


func hint(text: String, seconds := 3.5) -> void:
	hint_requested.emit(text, seconds)


## Voix chuchotée du système (synthèse vocale de Windows), si l'option est cochée et qu'une voix
## française est installée. Option coupée : ne fait rien du tout.
func whisper(text: String) -> void:
	if not whispers or autotest:
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


## Ajoute « v » au stress (négatif pour calmer), borné entre 0 et 1 ; « at_least » : après l'ajout, le
## stress vaut au moins cette valeur (une impulsion rend toujours le cœur audible).
func add_stress(v: float, at_least := 0.0) -> void:
	stress = clampf(maxf(stress + v, at_least), 0.0, 1.0)


## Baisse du stress pendant « delta » secondes. Écart au § 5.5 (« −0,08 par seconde »), à faire
## valider par l'auteur : (0,04 + 0,15 × stress) par seconde, plus rapide quand le cœur bat fort, pour
## que C4 tienne avec de la marge (depuis le maximum, le cœur se tait en 9 s au lieu de 11,7 s).
static func stress_after(s: float, delta: float, mult := 1.0) -> float:
	return maxf(0.0, s - (STRESS_DECAY + STRESS_DECAY_K * s) * mult * delta)


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
		stress = stress_after(stress, delta, stress_decay_mult)
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
func save_checkpoint(id: String, pos: Vector3, yaw: float, peur_max := 100.0) -> bool:
	var d := {
		"version": ProjectSettings.get_setting("application/config/version", ""),
		"checkpoint": id,
		"hero": hero,
		"items": items.duplicate(true),
		"choices": choices.duplicate(true),
		"flags": flags.duplicate(true),
		"peur": minf(peur, peur_max),
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
	saved.emit(id)
	if autotest:
		print("SAUVEGARDE %s · peur %.1f · %d objets · %d drapeaux" % [id, float(d.peur), items.size(), flags.size()])
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
