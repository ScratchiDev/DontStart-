class_name Autotest
extends Node
## Tests automatiques, joués comme un joueur (on vise avec le rayon, puis on « appuie sur E »).
## Nœud enfant de Main, créé par main.gd quand Game.autotest est vrai. Lancement :
##   godot --path godot --rendering-driver vulkan -- --autotest --shots=DIR      (parcours principal)
##   … -- --autotest --hero=aurelia --sous-titres --shots=DIR  (au féminin ; sous-titres des sons, C5)
##   … -- --autotest --seance=2,1,0,1,0,2/aube [--attendu=suite:35] --shots=DIR  (séance 1 seule : fins ;
##        --attendu=<fin>:<jauge> vérifie la fin et la jauge, A5)
##   … -- --autotest --charger=C1 --shots=DIR      (B17 C1 : écrit, recharge, compare ; B14 ; B18 refuge)
##   … -- --autotest --ecrans --shots=DIR           (menus et HUD : lisibilité ; C5 option gardée, C6, C7)
##   … -- --autotest --miroir=fixe|retourne|fui --shots=DIR  (une issue du P4 réel, B11, B12, B14 ; M9b ;
##        puis l'antenne et la convocation, C1)
##   … -- --autotest --absorbe --shots=DIR                                        (ABSORBÉ hors séance, B15)
##   … -- --autotest --indices --shots=DIR         (indices de 90 s ×30, B13 ; S.O.S. par la minuterie, B5)
##   … -- --autotest --charger=C2 --shots=DIR      (B17 C2 : sauvegarde après le P4 réel « fui » ; B14)
##   … -- --autotest --charger=C3 --shots=DIR      (B17 C3 : sauvegarde de la convocation ; B14 ; C9 reprise)
##   … -- --autotest --charger=031 --shots=DIR     (migration : sauvegarde 0.3.1 finie sur fin_031)
##   … -- --autotest --seance2=changer|delai|confirmer --shots=DIR   (séance 2 seule : C1, C2, C3)
##   … -- --autotest --seance2=absorbe --shots=DIR (jauge à 100 pendant la séance 2 : ABSORBÉ, C3 intact)
##   … -- --preview=<pièce>[,<pièce>…] --shots=DIR (6 vues par pièce ; B1 : positions, battants libres)
## « --sous-titres » active les sous-titres des sons pour le test (sans l'enregistrer) ; sinon ils sont
## coupés (C5 : les sons sont signalés, jamais affichés).
## Le parcours principal couvre A1 à A8 (sauf A5 fins : --seance), B1 à B12, B14, B16, B18, C1 à C3
## (convocation, séance 2 « Confirmer », fin de la version 0.3), C4, C5, C8 (moins de 15 min) et C9.
## Tout lancer, l'un après l'autre : scratchpad/run_all_032.sh (résumé par variante et par critère).
## Chaque vérification imprime « VÉRIF <id> OK » ou « VÉRIF <id> ÉCHEC : <détail> » ; la dernière ligne
## est « AUTOTEST OK » (code de sortie 0) ou « AUTOTEST ÉCHEC n » (code 1).
## Les sauvegardes de l'autotest vont dans Game.SAVE_PATH_TEST (jamais celle du joueur).

const AMIS := preload("res://scripts/house/rooms/amis.gd")
const SDB := preload("res://scripts/house/rooms/sdb.gd")
const TERMINAL := preload("res://scripts/terminal.gd")
const ROOM := preload("res://scripts/room.gd")
const GAME := preload("res://scripts/game.gd")
const STAGE_META := "autotest_etape"        # --charger : 1 = écrire, 2 = reprendre (survit au rechargement)
const SNAP_META := "autotest_etat_avant"
const COUNT_META := "autotest_compteurs"
## B1 : rectangle de battant (§ 5.2 : zones libres de P3, P4, P7) et hauteur du battant (Door : bas à
## Door.LEAF_GAP, haut à 2,04 m) ; positions comparées à 12 cm près.
const SWING_DEPTH := 0.95
const SWING_HALF := 0.5
const LEAF_BOTTOM := Door.LEAF_GAP
const LEAF_TOP := 2.04
const POS_TOL := 0.12
## B14 : les objets indispensables (§ 5.4).
const ESSENTIELS := ["cle_chambre", "cle_bureau", "tournevis", "seche_cheveux", "antenne"]
## B16 : temps de la 0.3.0 en rendu logiciel (maison construite, VoxelGI de la chambre cuit), en ms.
const BUILD_MS_030 := 2250.0
const GI_MS_030 := 950.0
const ITEMS_03 := [   # les objets de la v0.3 (§ 5.4), pour l'inventaire plein
	["cle_chambre", "Clé de la chambre", "Glissée sous la porte par Papi.", "cle"],
	["mot_albert", "Mot de Papi", "« N'ouvre à personne. Même pas à moi. »", "doc"],
	["journal_manon", "Journal de Maman (2016)", "Caché sous le lit. Les lettres qui brillent…", "doc"],
	["cle_bureau", "Clé du bureau", "Un double. Étiquette de Mamie : BUREAU. Il était dans la boîte à biscuits.", "cle"],
	["tournevis", "Tournevis de Papi", "Une étiquette « A. » sur le manche. Évidemment.", "outil"],
	["seche_cheveux", "Sèche-cheveux de Mamie", "Un Calor de 1994. Le boîtier et la gâchette du croquis.", "arme"],
	["antenne", "Antenne télescopique", "Les oreilles de lapin de la vieille télé.", "arme"],
	["plan_imprime", "Plan de l'étage", "Imprimé par elle. La salle de bain est entourée.", "doc"],
	["croquis_imprime", "Croquis du Fractionneur", "Imprimé par elle. « Construis-le. Je veux voir. »", "doc"],
	["photo_couloir", "Photo du couloir, 03:2x", "Le couloir vide. Juste le rond de ta lampe.", "doc"],
]

var main: Main
var player: CharacterBody3D
var hud: CanvasLayer
var menu: CanvasLayer
var room: Node3D
var house: House
var terminal: Control
var acte1: Acte1
var acte2: Acte2
var failures := 0
var checks := 0
var game_t := 0.0          # temps de jeu écoulé (somme des delta), voir g_since
var shots_taken := 0       # captures prises (B1 : 6 par pièce avec --preview)
var term_seen := ""        # ligne du terminal relevée pendant la séance 1 (A2 : « assis » / « assise »)
var bulb_peak := 0          # nombre d'ampoules du couloir allumées en même temps, au plus (_watch_bulbs)


func setup(m: Main) -> void:
	main = m
	player = m.player
	hud = m.hud
	menu = m.menu
	room = m.room
	house = m.house
	terminal = m.terminal
	acte1 = m.acte1
	acte2 = m.acte2


func run() -> void:
	if Game.preview_room != "":
		await run_previews(Game.preview_room)
	elif Game.seance_only:
		await run_seance()
	elif Game.load_arg != "":
		await run_load(Game.load_arg)
	elif Game.seance2_arg != "":
		await run_seance2(Game.seance2_arg)
	elif OS.get_cmdline_user_args().has("--ecrans"):
		await run_screens()
	elif Game.miroir_arg != "":
		await run_miroir(Game.miroir_arg)
	elif Game.absorbe_test:
		await run_absorbe()
	elif Game.indices:
		await run_indices()
	elif OS.get_cmdline_user_args().has("--revue"):
		await run_revue()
	else:
		await run_main()


# ------------------------------------------------------------------ outils

## Une vérification : « VÉRIF id OK » ou « VÉRIF id ÉCHEC : détail » (les échecs sont comptés).
func check(id: String, cond: bool, detail := "") -> bool:
	checks += 1
	if cond:
		print("VÉRIF %s OK" % id)
	else:
		failures += 1
		print("VÉRIF %s ÉCHEC : %s" % [id, detail])
	return cond


## Dernière ligne : « AUTOTEST OK » (code 0) ou « AUTOTEST ÉCHEC n » (code 1), puis on quitte.
func finish() -> void:
	print("%d vérifications, %d échec(s)" % [checks, failures])
	if failures == 0:
		print("AUTOTEST OK")
		Game.quit_game(0)
	else:
		print("AUTOTEST ÉCHEC %d" % failures)
		Game.quit_game(1)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(shot_name + ".png"))
	shots_taken += 1
	print("capture ", shot_name, " ", img.get_size())


## Place le joueur et prend une capture.
func view(pos: Vector3, yaw: float, pitch: float, shot_name: String, delay := 0.8) -> void:
	player.global_position = pos
	player.set_look(yaw, pitch)
	player.head.position.y = player.EYE
	await wait(delay)
	await shot(shot_name)


## Attend que cond soit vraie (au plus timeout secondes). Renvoie true si elle l'est devenue.
func until(cond: Callable, timeout := 60.0) -> bool:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if t >= timeout:
		print("ATTENTE TROP LONGUE")
		return false
	return true


## Place le joueur, vérifie que le rayon vise bien l'objet attendu, prend une capture, puis l'utilise.
func use_at(pos: Vector3, yaw: float, pitch: float, expected: String, shot_name := "") -> void:
	player.global_position = pos
	player.set_look(yaw, pitch)
	await wait(0.6)
	if player.current == null or player.current.label != expected:
		await until(func() -> bool: return player.current != null and player.current.label == expected, 1.5)
	var got: String = player.current.label if player.current else "rien"
	print("vise : %s (attendu : %s) %s" % [got, expected, "OK" if got == expected else "ÉCHEC"])
	if got != expected:
		var ray: RayCast3D = player.ray
		var col: Object = ray.get_collider() if ray.is_colliding() else null
		print("  rayon : %s à %s" % [col.get("name") if col else "rien", ray.get_collision_point() if col else "-"])
	check("vise « %s »" % expected, got == expected, "le rayon vise « %s »" % got)
	if shot_name != "":
		await shot(shot_name)
	if player.current:
		player.current.use()


## Tous les textes des Label sous un nœud (vérification des textes des menus).
static func texts_of(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "Label", true, false):
		out += (c as Label).text + "\n"
	for c in n.find_children("*", "Button", true, false):
		out += (c as Button).text + "\n"
	return out


static func find_interactable(n: Node, label: String) -> Interactable:
	for c in n.find_children("*", "Interactable", true, false):
		if (c as Interactable).label == label:
			return c as Interactable
	return null


## Relève la première ligne du terminal qui contient « fragment », pendant la séance 1 (A2).
func _watch_term(fragment: String) -> void:
	term_seen = ""
	while term_seen == "" and acte1.seance_result == "":
		for ln in terminal.lines:
			var t := ""
			for sg in ln.segs:
				t += str(sg[0])
			if t.contains(fragment):
				term_seen = t
				break
		await get_tree().process_frame


## Le contrôle tient-il dans l'écran (640 × 360) ?
func fits(c: Control) -> bool:
	var r := c.get_global_rect()
	var area := get_viewport().get_visible_rect().size
	return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= area.x + 0.5 and r.end.y <= area.y + 0.5


## Compare deux valeurs venues de la sauvegarde (les entiers JSON reviennent en flottants).
static func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not same(a[i], b[i]):
				return false
		return true
	return a == b


## Les portes du § 5.1 : serrures, libellés, messages.
func check_doors() -> void:
	var d: Dictionary = house.doors
	check("portes P1-P7", d.has("P1") and d.has("P2") and d.has("P3") and d.has("P4") and d.has("P5") and d.has("P6") and d.has("P7"), str(d.keys()))
	var p2: Door = d.get("P2")
	check("P2 « Frapper à la porte »", p2 != null and p2.locked and p2.key_id == "" and p2.it.label == "Frapper à la porte",
		"libellé « %s », verrouillée %s, clé « %s »" % [p2.it.label, p2.locked, p2.key_id] if p2 else "absente")
	var p3: Door = d.get("P3")
	check("P3 coincée (2)", p3 != null and not p3.locked and (p3.stuck == 2 or p3.is_open)
		and p3.locked_msg == "Coincée. Le bois a gonflé avec l'humidité. Encore un coup d'épaule.",
		"stuck %d · « %s »" % [p3.stuck, p3.locked_msg] if p3 else "absente")
	var p4: Door = d.get("P4")
	check("P4 entrouverte à 20°", p4 != null and not p4.locked and p4.stuck == 0 and absf(p4.leaf_angle_deg() - 20.0) < 0.5,
		"angle %.1f°" % p4.leaf_angle_deg() if p4 else "absente")
	var keys := {
		"P5": ["cle_lingerie", "Fermée à clé. La lingerie. Papi range ses clés sur un tableau, quelque part."],
		"P6": ["cle_escalier", "Fermée à clé. Derrière le verre, l'escalier descend dans le noir. Papi est passé par là."],
		"P7": ["cle_bureau", "Fermée à clé. Le bureau de Papi. Ton câble passe sous la porte."],
	}
	for id in keys:
		var p: Door = d.get(id)
		var want: Array = keys[id]
		check("%s clé %s" % [id, want[0]], p != null and p.locked and p.key_id == want[0] and p.locked_msg == want[1] and p.it.label == "Ouvrir la porte",
			"clé « %s » · « %s » · libellé « %s »" % [p.key_id, p.locked_msg, p.it.label] if p else "absente")


## B16 : hors du bureau et de la salle de bain, aucune caméra de flux ne se met à jour.
func check_feeds(where: String) -> void:
	await wait(0.4)
	var cams := get_tree().get_nodes_in_group("feed_cam")
	var on: Array = house.rendering_feeds()
	check("B16 %s" % where, cams.size() >= 4 and on.is_empty(), "%d caméras, actives : %s" % [cams.size(), on])


# ------------------------------------------------------------------ parcours principal

func run_main() -> void:
	print("AUTOTEST début · héros ", Game.hero)
	set_sound_captions_from_args()
	Game.delete_save()   # (sauvegarde de test) : l'écran-titre sans « Continuer »
	hud.fade.color.a = 0.0
	menu.show_title()
	await wait(1.0)
	await shot("00_titre")
	var tt := texts_of(menu.title_box)
	check("A1 titre", tt.contains("DON'T PLAY") and tt.contains("Toussaint 2040") and not menu.continue_btn.visible, "textes : " + tt.left(120))
	check("A1 héros", texts_of(menu.hero_box).contains("Une semaine de vacances") and not texts_of(menu.hero_box).contains("Deux semaines"), "")
	check("A1 description", not str(ProjectSettings.get_setting("application/config/description", "")).contains("vide-grenier"), "")
	menu.hide_all()
	Game.phase = "room"
	# (C8 : le temps de jeu suit l'horloge dès l'acte I ; avec les 8 pas de physique par image du
	# réglage par défaut, chaque attente de l'acte I durait quatre à cinq fois plus en rendu logiciel)
	real_time_pace()
	# l'étage tel qu'il est construit pour une nouvelle partie : B16 (temps), B1 (positions, battants)
	check_build_times()
	check_positions()
	check_door_zones()
	await wait(1.0)
	await view(Acte1.START_POS, Acte1.START_YAW, -0.05, "01_depart")
	await view(Vector3(0.2, 0, 1.2), 0.15, -0.1, "02_bureau")
	await view(Vector3(0.6, 0, 0.6), PI * 0.62, -0.12, "03_fenetre_lit")
	await view(Vector3(-1.0, 0, 0.2), 0.45, -0.05, "04_armoire")
	await view(Vector3(-0.5, 0, -0.6), -PI * 0.5, -0.05, "05_porte")
	await view(Vector3(0.5, 0, -1.2), PI, -0.15, "06_vers_le_fond")
	await view(Vector3(-2.2, 0, -0.45), PI / 2.0, -0.08, "06b_fenetre_dehors", 1.5)
	await view(Vector3(1.7, 0, 1.45), PI / 2.0, -0.75, "06c_empreintes")
	await view(Vector3(1.4, 0, -0.55), -0.35, 0.05, "06d_etagere_tableau")
	await view(Vector3(-1.1, 0, 1.3), PI / 2.0, 0.55, "06e_plafond_lit")
	await view(Vector3(0.3, 0, 0.9), PI * 0.62, 0.0, "06f_avant_eclair", 0.4)
	room.outside.strike()
	await wait(0.14)
	await shot("06g_eclair")
	await check_feeds("chambre")
	# A2 : le mot de Mamie (« mon grand » / « ma grande »)
	var mamie := find_interactable(room.decor, "Lire le mot de Mamie")
	if mamie:
		mamie.use()
	await wait(0.5)
	check("A2 mot de Mamie", hud.paper_open and hud.paper_text.text.contains(Game.g("Bonne nuit mon grand", "Bonne nuit ma grande")), hud.paper_text.text.left(40))
	hud.close_paper()
	# A3 : la porte avant la clé
	await use_at(Vector3(2.4, 0, 1.4), -PI / 2.0, -0.1, "Ouvrir la porte")
	await wait(0.3)
	check("A3 porte fermée", hud.hint_lbl.text == "Fermée. De l'extérieur." and not room.door_node.is_open, "« %s »" % hud.hint_lbl.text)
	await wait(4.4)   # le message s'efface avant la suite
	await use_at(Vector3(-2.5, 0, -1.25), 0.0, -0.25, "Ouvrir l'armoire")
	await wait(2.0)
	await use_at(Vector3(-2.5, 0, -1.25), 0.0, -0.55, "Prendre la disquette", "07_armoire_ouverte")
	print("disquette en main : ", Game.has_floppy)
	await use_at(Vector3(0.95, 0, 1.45), PI, -0.6, "Regarder la photo", "08_photo")
	_watch_term("devant moi, dans sa chambre")
	# (C8 : mode turbo dès le démarrage de la disquette ; tapé lettre à lettre, le BIOS prenait plus
	# d'une minute en rendu logiciel, une image par lettre)
	terminal.turbo = true
	await use_at(Vector3(1.2, 0, -1.0), 0.0, -0.3, "Insérer la disquette", "09_devant_pc")
	await terminal.boot_finished
	await shot("10_demarrage")
	# la séance 1, jouée avec des réponses fixées : Mamie, verre de droite, demander une preuve,
	# personne, se retourner (le visage), prononcer le mot → AUBE → fausse fin → suite
	terminal.autopicks = [0, 1, 1, 2, 0, 2]
	terminal.autoasks = ["aube"]
	var names := ["11_choix_proche", "12_choix_verres", "13_choix_porte", "14_choix_prix", "15_choix_reflet", "17_choix_fin"]
	for i in names.size():
		await until(func() -> bool: return not terminal._choice.is_empty())
		await wait(0.3)
		await shot(names[i])
		await until(func() -> bool: return terminal._choice.is_empty())
		if i == 4:
			await wait(0.55)
			await shot("16_visage")
	await until(func() -> bool: return not terminal._ask.is_empty())
	await shot("18_saisie_mot")
	await until(func() -> bool: return acte1.seance_result != "", 120.0)
	print("fin de séance : ", acte1.seance_result, " · peur : ", terminal.fear)
	check("A5 suite", acte1.seance_result == "suite", acte1.seance_result)
	check("jauge = Game.peur", is_equal_approx(terminal.fear, Game.peur) and terminal.fear_val.text == "%02d%%" % int(Game.peur), "%s / %s" % [terminal.fear_val.text, Game.peur])
	var missing := []
	for k in ["proche", "verres", "porte", "prix", "reflet", "fin_seance1", "peur_seance1"]:
		if not Game.choices.has(k):
			missing.append(k)
	check("A7 choix", missing.is_empty(), "manquent : %s" % [missing])
	check("A6 visages", Game.face_scares <= 1, "%d" % Game.face_scares)
	check("A2 terminal « %s »" % Game.g("assis", "assise"), term_seen.begins_with("Tu es %s devant moi" % Game.g("assis", "assise")), "« %s »" % term_seen)
	await wait(2.5)
	await shot("19_fin_seance")
	acte1._stand_up()
	await wait(0.5)
	await use_at(Vector3(2.2, 0, 1.32), -PI / 2.0, -1.1, "Ramasser la clé et le mot", "20_cle_sous_porte")
	await wait(0.8)
	await shot("21_mot_albert")
	# point de passage C1 « acte2 » : écrit en ramassant la clé et le mot
	var c1 := Game.load_checkpoint()
	check("B17 C1 écrit (clé ramassée)", Game.has_save() and c1.get("checkpoint") == "C1", str(c1.get("checkpoint", "rien")))
	check("B17 C1 jauge ≥ 25 (plancher)", Game.peur_floor >= 25.0 and Game.peur >= 25.0 and float(c1.get("peur", 0.0)) >= 25.0, "peur %.1f, plancher %.1f" % [Game.peur, Game.peur_floor])
	check("O1", Game.objective_text == "Sors de la chambre" and acte2.active, "« %s »" % Game.objective_text)
	hud.close_paper()
	check_unstuck("C1")
	await check_eject()
	hud.toggle_inventory()
	await wait(0.4)
	await shot("22_inventaire")
	check("inventaire dans l'écran", fits(hud.inv), str(hud.inv.get_global_rect()))
	hud.toggle_inventory()
	print("clé : ", Game.has_item("cle_chambre"), " · objets : ", Game.items.size())
	# la porte s'ouvre avec la clé d'Albert : le premier étage
	await use_at(Vector3(2.4, 0, 1.4), -PI / 2.0, -0.1, "Ouvrir la porte")
	await wait(2.0)
	check("A8 P1 ouverte", room.door_node.is_open and Game.flag("porte_P1", "") == "ouverte", "ouverte %s · drapeau %s" % [room.door_node.is_open, Game.flag("porte_P1", "")])
	await view(Vector3(1.6, 0, 1.4), -PI / 2.0, -0.05, "23_porte_ouverte", 1.0)
	await run_floor()
	# 0.3.2 : stress léger (C4), sous-titres (C5), journal des temps (C9), durée (C8)
	check_c4("parcours principal", 20)
	if Game.sound_captions:
		check_c5_on("parcours principal")
	else:
		check_c5_off("parcours principal")
	check_c9("parcours principal", ["seance1", "fin_seance1", "sortir", "mamie", "explorer", "p4", "convocation", "seance2", "fin"])
	var real_s := Time.get_ticks_msec() / 1000.0
	print("C8 : parcours complet joué en %.0f s d'horloge (lancement compris)" % real_s)
	check("C8 parcours complet en moins de 15 min", real_s < 900.0, "%.0f s" % real_s)
	finish()


# ------------------------------------------------------------------ l'étage (acte II, 0.3.1)

## Lacet et tangage pour viser « target » depuis les yeux d'un joueur posé en « pos ».
func aim(pos: Vector3, target: Vector3) -> Vector2:
	var d := target - (pos + Vector3(0, player.EYE, 0))
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))


## Place le joueur en « pos », le regard sur « target ».
func look_from(pos: Vector3, target: Vector3) -> void:
	var a := aim(pos, target)
	player.global_position = pos
	player.set_look(a.x, a.y)
	player.head.position.y = player.EYE


## use_at, en visant le centre d'une interaction depuis « pos ».
func use_on(it: Interactable, pos: Vector3, expected: String, shot_name := "") -> void:
	if it == null:
		check("vise « %s »" % expected, false, "interaction introuvable")
		return
	var a := aim(pos, it.global_position)
	await use_at(pos, a.x, a.y, expected, shot_name)


## Ce que verrait le joueur depuis « pos » en regardant « target » (même masque de couches que sa
## caméra, avec une copie de sa lampe de poche), rendu dans une vue à part : sa vraie caméra reste où
## elle est (le P4 continue).
func side_shot(pos: Vector3, target: Vector3, shot_name: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main.add_child(vp)
	var cam := Camera3D.new()
	cam.cull_mask = player.camera.cull_mask
	cam.fov = player.camera.fov
	vp.add_child(cam)
	cam.global_position = pos + Vector3(0, player.EYE, 0)
	cam.look_at(target)
	cam.current = true
	var fl: SpotLight3D = player.flashlight.duplicate()
	fl.light_energy = player.flash_base
	fl.visible = true
	cam.add_child(fl)
	fl.transform = player.flashlight.transform
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(shot_name + ".png"))
	print("capture ", shot_name, " (vue à part) ", img.get_size())
	vp.queue_free()


## Enregistre une texture (écran d'un appareil) comme capture.
func tex_shot(tex: Texture2D, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := tex.get_image() if tex else null
	if img and Game.shots_dir != "":
		img.save_png(Game.shots_dir.path_join(shot_name + ".png"))
	print("capture ", shot_name, " (écran) ", img.get_size() if img else Vector2i.ZERO)


## Les répliques dites par un appareil contiennent-elles « lines » (textes remplis), dans l'ordre ?
func said_in_order(dev: String, lines: Array) -> bool:
	var got: Array = main.haunt.said(dev)
	var i := 0
	for t in got:
		if i < lines.size() and t == main.haunt.fill(str(lines[i])):
			i += 1
	return i == lines.size()


func has_said(dev: String, line: String) -> bool:
	return main.haunt.said(dev).has(main.haunt.fill(line))


## « who » de la réplique « line » (journal de Haunt).
func said_who(dev: String, line: String) -> String:
	for e in main.haunt.journal:
		if e.get("ev") == "say" and e.get("dev") == dev and e.get("text") == main.haunt.fill(line):
			return str(e.get("who", ""))
	return ""


func t_since(ms: int) -> float:
	return (Time.get_ticks_msec() - ms) / 1000.0


## Temps de jeu écoulé depuis « t0 » (secondes de jeu, lues sur game_t) : les délais du scénario
## (« moins de 3 s », « dans les 25 s ») se mesurent en temps de jeu, pas à l'horloge (rendu logiciel).
func g_since(t0: float) -> float:
	return game_t - t0


## Rendu logiciel : une image peut prendre 0,5 s ; avec 8 pas de physique au plus par image (réglage
## par défaut), le temps de jeu n'avance alors que de 0,13 s par image et tout le scénario se joue
## au ralenti. Pour l'étage, on laisse le temps de jeu suivre l'horloge (1 s de jeu par image au plus).
func real_time_pace() -> void:
	Engine.max_physics_steps_per_frame = 60


func _process(delta: float) -> void:
	game_t += delta


## Note pendant « sec » secondes le plus grand nombre d'ampoules du couloir allumées ensemble.
func _watch_bulbs(cl: Node, sec: float) -> void:
	bulb_peak = 0
	var t0 := game_t
	while g_since(t0) < sec:
		var n := 0
		for b in cl.smart_bulbs:
			if (b as SmartBulb).is_lit():
				n += 1
		bulb_peak = maxi(bulb_peak, n)
		await get_tree().process_frame


## Le premier étage, de la sortie de la chambre à la fin de la version 0.3 (§ 2.2, étapes 6 à 15, et
## § 2.3, issue « fixe »).
func run_floor() -> void:
	var hn: Haunt = main.haunt
	var cl: Node = house.rooms["couloir"]
	var am: Node = house.rooms["amis"]
	var bu: Node = house.rooms["bureau"]
	var sb: Node = house.rooms["sdb"]
	var t_floor := Time.get_ticks_msec()
	real_time_pace()
	# --- étape 6 : le couloir, première entrée (B2)
	var lit := 0
	for b in cl.smart_bulbs:
		if (b as SmartBulb).is_lit():
			lit += 1
	check("couloir endormi", lit == 0 and not cl.cam_led_on and not (cl.nestor as Nestor).ring_on, "%d ampoules allumées · LED %s · anneau %s" % [lit, cl.cam_led_on, cl.nestor.ring_on])
	var nestor_pos: Vector3 = (cl.nestor as Nestor).speak_pos()
	look_from(Vector3(4.2, 0, 1.1), nestor_pos + Vector3(0, 0.05, 0))
	_watch_bulbs(cl, 8.0)
	await until(func() -> bool: return (cl.nestor as Nestor).ring_on, 8.0)
	await wait(1.5)
	await shot("30_couloir_nestor")
	await until(func() -> bool: return has_said("nestor", Acte2.N4), 60.0)
	check("B2 N1 à N4", said_in_order("nestor", [Acte2.N1, Acte2.N2, Acte2.N3, Acte2.N4]), str(hn.said("nestor")))
	check("B2 jauge ≥ 25", Game.peur >= 25.0, "%.1f" % Game.peur)
	await wait(0.5)
	check("B2 objectif O2", Game.objective_text == Acte2.O2, "« %s »" % Game.objective_text)
	check("couloir en chaîne", bulb_peak >= 2 and cl.cam_led_on, "ampoules allumées au plus : %d · LED %s" % [bulb_peak, cl.cam_led_on])
	check("O2 couloir", bool(Game.flag("entree_couloir", false)), "")
	await check_feeds("couloir")
	check_doors()
	await until(func() -> bool: return not hn.is_busy(), 30.0)
	await view(Vector3(4.0, 0, 2.2), 0.0, -0.05, "24_couloir_vers_nord", 1.2)
	await view(Vector3(4.0, 0, -1.0), PI, -0.05, "25_couloir_vers_sud", 1.2)
	# --- B3 : la caméra dôme suit le joueur ; la fixer 3 s éteint sa LED
	player.global_position = Vector3(3.55, 0, -5.0)
	await wait(1.5)
	player.global_position = Vector3(4.5, 0, -5.0)
	await wait(1.0)
	var want: Vector2 = cl._aim_of(player)
	var dyaw := rad_to_deg(absf(wrapf(want.y - (cl.cam_pivot as Node3D).rotation.y, -PI, PI)))
	print("B3 : 1 s après le déplacement, la caméra dôme vise à %.1f° du joueur" % dyaw)
	check("B3 caméra suit", dyaw < 15.0, "écart de lacet %.1f°" % dyaw)
	var cam_p: Vector3 = (cl.cam_pivot as Node3D).global_position
	look_from(Vector3(4.0, 0, -5.4), cam_p)
	var t_stare := game_t
	await wait(0.5)
	await shot("31_camera_suit")
	await until(func() -> bool: return not cl.cam_led_on, 6.0)
	var stare_s := g_since(t_stare)
	print("B3 : LED éteinte après %.2f s de visée" % stare_s)
	check("B3 LED éteinte", not cl.cam_led_on and stare_s >= 2.7 and stare_s <= 3.9, "LED %s après %.1f s de visée" % [cl.cam_led_on, stare_s])
	# (on regarde ailleurs : la LED reste éteinte 5 s, puis se rallume)
	var t_off := game_t
	player.set_look(PI, -0.05)
	await wait(4.0)
	var still_off: bool = not cl.cam_led_on
	await until(func() -> bool: return cl.cam_led_on, 6.0)
	var off_s := g_since(t_off)
	print("B3 : LED rallumée %.2f s après s'être éteinte" % off_s)
	check("B3 LED éteinte 5 s", still_off and cl.cam_led_on and off_s >= 4.4 and off_s <= 5.9, "rallumée après %.1f s" % off_s)
	await view(Vector3(4.0, 0, -3.2), -0.49, -0.05, "26b_p4_entrouverte", 1.0)
	# --- étape 7 : P2, on frappe (B4)
	var t_knock := game_t
	await use_at(Vector3(4.1, 0, -3.6), PI / 2.0, -0.1, "Frapper à la porte", "32_p2")
	# (trois coups de 0,42 s, puis le message : en rendu logiciel, les minuteries tombent à l'image près)
	await until(func() -> bool: return acte2.last_door == "P2" and hud.hint_lbl.text == House.H_P2A, 6.0)
	check("B4 H-P2a", hud.hint_lbl.text == House.H_P2A and acte2.last_door == "P2" and (house.doors["P2"] as Door).knocks == 1,
		"« %s » · dernière porte %s" % [hud.hint_lbl.text, acte2.last_door])
	await until(func() -> bool: return has_said("nestor", Acte2.N7), 40.0)
	check("B4 N5 à N7", said_in_order("nestor", [Acte2.N4, Acte2.N5, Acte2.N6, Acte2.N7]), str(hn.said("nestor")))
	await use_at(Vector3(4.1, 0, -3.6), PI / 2.0, -0.1, "Frapper à la porte")
	await until(func() -> bool: return (house.doors["P2"] as Door).knocks == 2 and hud.hint_lbl.text == House.H_P2B, 6.0)
	check("B4 H-P2b", hud.hint_lbl.text == House.H_P2B and (house.doors["P2"] as Door).locked, "« %s »" % hud.hint_lbl.text)
	await shot("32b_p2_second")
	await until(func() -> bool: return not hn.is_busy(), 20.0)
	check("B4 objectif O3", Game.objective_text == Acte2.O3, "« %s »" % Game.objective_text)
	var card := false
	for c in hud.root.find_children("*", "Label", true, false):
		if (c as Label).text.contains("FIN DE LA VERSION") or (c as Label).text.contains("prochaine version"):
			card = true
	check("P2 sans fin provisoire", not card and hud.fade.color.a < 0.05 and Game.phase == "room" and not main.has_method("_on_grandma_door"),
		"carte %s · fondu %.2f · phase %s" % [card, hud.fade.color.a, Game.phase])
	# --- étape 8 : le S.O.S. (B5)
	await until(func() -> bool: return hn.has_logged("sos"), 40.0)
	var t_sos := g_since(t_knock)
	print("B5 : S.O.S. %.1f s après le 1er appui sur P2 (%s)" % [t_sos, acte2.sos_source])
	check("B5 S.O.S. dans les 25 s", hn.count("sos") == 1 and t_sos <= 27.0, "%.1f s après le 1er appui (%s)" % [t_sos, acte2.sos_source])
	await until(func() -> bool: return has_said("nestor", Acte2.N9), 40.0)
	await wait(0.3)
	check("B5 N8 N9", said_in_order("nestor", [Acte2.N8, Acte2.N9]) and hud.subtitle_log.size() > 0, str(hn.said("nestor").slice(-2)))
	check("objectif Papi à la cave", Game.objective_sub.contains(Acte2.SUB_CAVE) and Game.objective_sub.contains(Acte2.SUB_EXPLORE), "« %s »" % Game.objective_sub)
	await shot("32c_sos")
	await until(func() -> bool: return not hn.is_busy(), 20.0)
	await wait(4.0)
	check("B5 une seule fois", hn.count("sos") == 1, "%d" % hn.count("sos"))
	# --- étape 9 : les portes fermées
	for d in [["P5", Vector3(3.9, 0, -1.2)], ["P6", Vector3(3.9, 0, 1.35)], ["P7", Vector3(3.9, 0, 4.4)]]:
		var dr: Door = house.doors[d[0]]
		await use_at(d[1], -PI / 2.0, -0.1, "Ouvrir la porte")
		await wait(0.4)
		check("%s fermée (message)" % d[0], hud.hint_lbl.text == dr.locked_msg and dr.locked, "« %s »" % hud.hint_lbl.text)
		await wait(0.6)
	# --- étape 10 : la chambre d'amis (P3 forcée deux fois ; B6)
	await use_at(Vector3(4.1, 0, 3.4), PI / 2.0, -0.1, "Ouvrir la porte")
	await wait(0.4)
	check("P3 coincée", hud.hint_lbl.text == "Coincée. Le bois a gonflé avec l'humidité. Encore un coup d'épaule." and not (house.doors["P3"] as Door).is_open, "« %s »" % hud.hint_lbl.text)
	await use_at(Vector3(4.1, 0, 3.4), PI / 2.0, -0.1, "Forcer la porte")
	await wait(1.0)
	check("B6 P3 forcée", (house.doors["P3"] as Door).is_open, "")
	var peur0 := Game.peur
	var bp: Babyphone = am.babyphone
	look_from(Vector3(2.0, 0, 4.3), bp.speak_pos())
	await until(func() -> bool: return hn.said("babyphone").size() >= 1, 15.0)
	await wait(1.2)
	await shot("33_amis_babyphone")
	var tv: Device = am.tv
	look_from(AMIS.PLAYER_AT_TV, tv.global_position)
	var noise_ok: bool = await until(func() -> bool: return float(tv._p.noise) >= 0.5, 25.0)
	var t_snow := game_t
	print("B6 : la télé neige (noise %.2f)" % float(tv._p.noise))
	await wait(0.6)
	await shot("34_tele_neige")
	await until(func() -> bool: return float(tv._p.noise) < 0.5, 10.0)
	var snow_s := g_since(t_snow)
	print("B6 : neige pendant %.2f s" % snow_s)
	await until(func() -> bool: return has_said("babyphone", Acte2.B4), 20.0)
	await wait(0.6)
	check("H-B", hud.hint_lbl.text == Game.g(Acte2.H_B[0], Acte2.H_B[1]), "« %s »" % hud.hint_lbl.text)
	await until(func() -> bool: return not hn.is_busy(), 10.0)
	check("B6 B1 à B4", said_in_order("babyphone", [Acte2.B1, Acte2.B2, Acte2.B3, Acte2.B4])
		and said_who("babyphone", Acte2.B2) == "Mamie" and said_who("babyphone", Acte2.B3) == "Mamie" and said_who("babyphone", Acte2.B4) == "elle",
		str(hn.said("babyphone")))
	check("B6 télé qui neige", noise_ok and snow_s >= 2.0, "%.1f s" % snow_s)
	check("B6 jauge +3", is_equal_approx(Game.peur - peur0, 3.0) and bool(Game.flag("babyphone_parle", false)), "%.1f → %.1f" % [peur0, Game.peur])
	await check_feeds("chambre d'amis")
	# boîte à biscuits, madeleine (B7)
	var tin_it: Interactable = am.tin_it
	await use_on(tin_it, Vector3(-2.15, 0, 4.15), "Ouvrir la boîte à biscuits")
	await wait(0.8)
	await shot("35_boite")
	check("B7 clé du bureau", Game.has_item("cle_bureau"), "")
	var p_mad := Game.peur
	var mad_it: Interactable = am.madeleine_it
	await use_on(mad_it, Vector3(-2.15, 0, 4.15), "Manger la madeleine")
	await wait(0.5)
	var p_after := Game.peur
	mad_it.use()
	await wait(0.3)
	check("B7 madeleine −5 une fois", is_equal_approx(p_mad - p_after, 5.0) and is_equal_approx(Game.peur, p_after) and not mad_it.enabled,
		"%.1f → %.1f → %.1f" % [p_mad, p_after, Game.peur])
	# l'antenne, sans tournevis (B10)
	var ant_it: Interactable = am.antenna_it
	await use_on(ant_it, AMIS.PLAYER_AT_TV, "Examiner l'antenne")
	await wait(0.4)
	check("B10 antenne sans tournevis", hud.hint_lbl.text.contains("il faut un tournevis") and bool(Game.flag("antenne_examinee", false)), "« %s »" % hud.hint_lbl.text)
	# --- étape 11 : le bureau (P7 avec la clé ; B8)
	await use_at(Vector3(3.9, 0, 4.4), -PI / 2.0, -0.1, "Ouvrir la porte")
	await wait(1.4)
	var space := player.get_world_3d().direct_space_state
	var gap := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(4.2, 1.0, 4.4), Vector3(5.4, 1.0, 4.4), Builder.LAYER_WORLD))
	check("B8 P7 ouverte, passage libre", (house.doors["P7"] as Door).is_open and gap.is_empty(), "obstacle : %s" % [gap.get("collider")])
	var console: HouseConsole = bu.console
	var screen_c: Vector3 = console.global_position
	var t_in := game_t
	look_from(Vector3(6.75, 0, 4.85), screen_c)
	await until(func() -> bool: return console.booting or console.booted, 8.0)
	var t_on := g_since(t_in)
	await until(func() -> bool: return console.booted, 12.0)
	var t_boot := g_since(t_in)
	print("console : écran allumé %.2f s, démarrée %.2f s après l'entrée" % [t_on, t_boot])
	check("B8 console allumée en moins de 3 s", t_on < 3.0, "%.2f s (démarrée à %.2f s)" % [t_on, t_boot])
	await until(func() -> bool: return has_said("console", Acte2.C4), 30.0)
	await wait(0.8)
	await shot("36_bureau_console")
	var thumbs: bool = console.feeds[0] != null and console.feeds[1] != null and console.feeds[2] != null and console.feeds[3] == null
	var no_signal := 0
	for lb in console.find_children("*", "Label", true, false):
		if (lb as Label).text == "PAS DE SIGNAL" and (lb as Label).is_visible_in_tree():
			no_signal += 1
	check("B8 4 vignettes", console.booted and thumbs and no_signal == 1, "%s · « PAS DE SIGNAL » ×%d" % [console.feeds, no_signal])
	var feeds_on: Array = house.rendering_feeds()
	check("B16 bureau : CAM 1 à 3 tournent", feeds_on.size() == 3, str(feeds_on))
	var outside_n: Node = room.outside
	var cam2: FeedCam = outside_n.cam2
	var clovis: Node3D = outside_n.clovis
	var clovis_layer := false
	for gi in clovis.find_children("*", "VisualInstance3D", true, false):
		clovis_layer = clovis_layer or (gi as VisualInstance3D).get_layer_mask_value(Builder.LAYER_HIDDEN_FROM_FEEDS)
	check("B8 CAM 2 sans Clovis", not (cam2.cull_mask & Builder.layer_bit(Builder.LAYER_HIDDEN_FROM_FEEDS)) and clovis_layer, "masque %d" % cam2.cull_mask)
	# l'imprimante : plan et croquis (B9)
	var pr: Printer = bu.printer
	await until(func() -> bool: return pr.printed.has("plan_imprime") and pr.printed.has("croquis_imprime"), 20.0)
	look_from(Vector3(8.1, 0, 5.25), pr.out_pos() + Vector3(0, -0.02, -0.15))
	await wait(0.7)
	await shot("39_impression")
	for k in 2:
		var e: Dictionary = pr.sheets[pr.sheets.size() - 1]
		await use_on(e.it, Vector3(8.1, 0, 5.25), "Prendre la feuille")
		await wait(0.6)
		if k == 1:
			await shot("39b_feuille")
		hud.close_paper()
		await wait(0.3)
	check("B9 plan et croquis", Game.has_item("plan_imprime") and Game.has_item("croquis_imprime"), str(pr.printed))
	check("objectif croquis", Game.objective_sub.begins_with("Croquis de Maman : 0/4"), "« %s »" % Game.objective_sub)
	# le tiroir : le tournevis (B10)
	var drawer_it: Interactable = bu.drawer_it
	await use_on(drawer_it, Vector3(6.6, 0, 4.85), "Ouvrir le tiroir")
	await wait(0.8)
	await use_on(drawer_it, Vector3(6.6, 0, 4.85), "Prendre le tournevis")
	await wait(0.6)
	var tool_kind := ""
	for it in Game.items:
		if it.id == "tournevis":
			tool_kind = it.kind
	check("B10 tournevis", tool_kind == "outil", tool_kind)
	# les caméras (jauge +2)
	await until(func() -> bool: return not hn.is_busy(), 20.0)
	var p_cam := Game.peur
	await use_on(bu.cams_it, Vector3(6.75, 0, 4.85), "Regarder les caméras")
	await wait(1.2)
	await shot("37_cam2_socle_vide")
	hud.close_screen()
	await until(func() -> bool: return bool(Game.flag("cameras_vues", false)), 25.0)
	check("caméras +2", is_equal_approx(Game.peur - p_cam, 2.0), "%.1f → %.1f" % [p_cam, Game.peur])
	# la sortie du bureau : la photo du couloir (B9)
	# (en sortant du bureau, on regarde vers la chambre d'amis : le rond de la lampe sur le mur ouest)
	look_from(Vector3(4.25, 0, 3.9), Vector3(3.3, 0.8, 2.6))
	await until(func() -> bool: return pr.printed.has("photo_couloir"), 20.0)
	check("B9 photo après la sortie", pr.printed.has("photo_couloir") and bool(Game.flag("entree_bureau", false)), str(pr.printed))
	var e_ph: Dictionary = {}
	for e in pr.sheets:
		if e.id == "photo_couloir":
			e_ph = e
	if not e_ph.is_empty():
		await use_on(e_ph.it, Vector3(8.1, 0, 5.25), "Prendre la feuille")
		await wait(0.6)
	check("B9 photo lue comme image", Game.has_item("photo_couloir") and hud.paper_open and hud.paper_image.visible and hud.paper_image.texture != null,
		"objet %s · image %s" % [Game.has_item("photo_couloir"), hud.paper_image.visible])
	await shot("39c_photo_couloir")
	await tex_shot(hud.paper_image.texture, "39d_photo_imprimee")
	hud.close_paper()
	# Clovis, par la fenêtre de la chambre de ta mère
	var cv := clovis.global_position + Vector3(0, 0.5, 0)
	look_from(Vector3(-2.9, 0, -0.45), cv)
	await until(func() -> bool: return house.current != null and house.current.room_id == "mere", 3.0)
	var p_ref := Game.peur
	var t_ref := game_t
	await wait(2.0)
	var drop := p_ref - Game.peur
	var want_drop := 0.2 * g_since(t_ref)
	await shot("38_fenetre_clovis")
	# Clovis (couche 12) est vu par le joueur : dans le champ de sa caméra, rien de solide entre les deux
	var eye: Vector3 = player.camera.global_position
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, cv, Builder.LAYER_WORLD))
	check("B8 Clovis vu de la fenêtre de la chambre", player.camera.get_cull_mask_value(Builder.LAYER_HIDDEN_FROM_FEEDS) and player.camera.is_position_in_frustum(cv)
		and (hit.is_empty() or (hit.position as Vector3).distance_to(cv) < 0.8),
		"masque %s · champ %s · obstacle %s" % [player.camera.get_cull_mask_value(Builder.LAYER_HIDDEN_FROM_FEEDS), player.camera.is_position_in_frustum(cv), hit.get("collider")])
	check("Clovis à la fenêtre", bool(Game.flag("clovis_vu", false)) and hud.hint_lbl.text == Acte2.H_CLOVIS, "« %s »" % hud.hint_lbl.text)
	check("B18 refuge −0,2/s (étage)", p_ref <= Game.peur_floor + 0.5 or (drop > want_drop * 0.6 and drop < want_drop * 1.4),
		"%.2f en %.1f s (attendu %.2f)" % [drop, g_since(t_ref), want_drop])
	# l'antenne, avec le tournevis (B10)
	await use_on(ant_it, AMIS.PLAYER_AT_TV, "Dévisser l'antenne", "40_antenne")
	await until(func() -> bool: return Game.has_item("antenne"), 8.0)
	var ant_kind := ""
	for it in Game.items:
		if it.id == "antenne":
			ant_kind = it.kind
	check("B10 antenne", ant_kind == "arme", ant_kind)
	# --- étape 12 : la salle de bain, le sèche-cheveux, le P4 réel (B11, B12 « fixe »)
	await use_on((house.doors["P4"] as Door).it, Vector3(3.9, 0, -4.45), "Ouvrir la porte")
	await wait(1.4)
	check("P4 ouverte", (house.doors["P4"] as Door).is_open, "")
	await run_p4_at_mirror(sb, "fixe", true)
	check_unstuck("C2")
	# --- étape 13 : la convocation (C1)
	await check_convocation()
	check_unstuck("C3")
	# --- étapes 14 et 15 : la séance 2 « Confirmer » (C2), la fin de la version (C3)
	check_results_lines()
	await run_seance2_at_pc("confirmer", true)
	print("étage joué en %.0f s (horloge)" % t_since(t_floor))


## Le P4 réel joué depuis la salle de bain : prendre le sèche-cheveux, puis tenir l'issue voulue
## (« fixe » : regarder le miroir jusqu'au bout ; « retourne » : se retourner pendant la barre ;
## « fui » : sortir de la pièce). Vérifie B11 (main = parcours principal, avec ses captures) et B12.
func run_p4_at_mirror(sb: Node, issue: String, main_path: bool) -> void:
	var hn: Haunt = main.haunt
	var mirror: SmartMirror = sb.mirror
	var events := {}
	mirror.p4_event.connect(func(st: String) -> void: events[st] = game_t)
	var dryer_it: Interactable = sb.dryer_it
	# (le délai se mesure du ramassage, Game.item_added, à l'allumage du miroir, événement « m0 » : sans
	# la latence de l'attente image par image, qui vaut seule un quart de seconde en rendu logiciel)
	var took := [-1.0]
	var on_item := func(id: String, _label: String) -> void:
		if id == "seche_cheveux" and took[0] < 0.0:
			took[0] = game_t
	Game.item_added.connect(on_item)
	await use_on(dryer_it, Vector3(7.65, 0, -5.0), "Prendre le sèche-cheveux")
	Game.item_added.disconnect(on_item)
	var t_take: float = took[0] if took[0] >= 0.0 else game_t
	var p0 := Game.peur
	var started: bool = await until(func() -> bool: return mirror.is_on and mirror.p4_running, 3.0)
	var t_on: float = events.get("m0", game_t)
	print("B11 : miroir allumé %.2f s après le ramassage du sèche-cheveux" % (t_on - t_take))
	check("B11 P4 en moins de 1 s", started and t_on - t_take < 1.0 and Game.has_item("seche_cheveux"), "%.2f s" % (t_on - t_take))
	if not main_path:
		Engine.time_scale = 3.0     # (variantes --miroir= : la suite en accéléré)
	var mpos: Vector3 = mirror.global_position
	look_from(SDB.PLAYER_AT_MIRROR, mpos)
	if main_path:
		await until(func() -> bool: return mirror.text_lines.size() > 0 and str(mirror.text_lines[0]).begins_with("BONJOUR HENRIETTE"), 10.0)
		await wait(1.0)
		await shot("41_miroir_allume")
		await until(func() -> bool: return hud.hint_lbl.text == SmartMirror.P4_TEXTS["H-M0"], 10.0)
		check("H-M0", hud.hint_lbl.text == SmartMirror.P4_TEXTS["H-M0"], "« %s »" % hud.hint_lbl.text)
	await until(func() -> bool: return events.has("barre"), 90.0)
	check("B11 flux visible", mirror.feed_shown and mirror.feed.is_rendering() and not player.camera.get_cull_mask_value(Builder.LAYER_FEED_ONLY),
		"flux %s · rendu %s" % [mirror.feed_shown, mirror.feed.is_rendering()])
	# la silhouette et le rideau « flux uniquement » : couche 11 seule, vue par la caméra du miroir,
	# jamais par celle du joueur ; le vrai rideau a la couche 12 pendant le P4 (caché du flux)
	var bit11 := Builder.layer_bit(Builder.LAYER_FEED_ONLY)
	var sil: MeshInstance3D = sb.silhouette
	var cf_ok := true
	for g in (sb.curtain_feed as Node).find_children("*", "GeometryInstance3D", true, false):
		cf_ok = cf_ok and (g as GeometryInstance3D).layers == bit11
	check("B11 couche 11 (flux uniquement)", sil != null and sil.layers == bit11 and cf_ok and (mirror.feed.cull_mask & bit11) != 0
		and not player.camera.get_cull_mask_value(Builder.LAYER_FEED_ONLY),
		"silhouette %d · rideau du flux %s · masque du flux %d" % [sil.layers if sil else -1, cf_ok, mirror.feed.cull_mask])
	if main_path:
		var reflet := str(Game.choices.get("reflet", "fixe"))
		check("M3 « %s »" % reflet, hn.said("miroir").has(hn.fill(SmartMirror.P4_TEXTS.get("M3_" + reflet, "?"))), str(hn.said("miroir").slice(0, 4)))
	match issue:
		"retourne":
			await wait(1.0)
			look_from(SDB.PLAYER_AT_MIRROR, Vector3(6.6, 0.9, -6.9))
		"fui":
			await wait(1.0)
			# il sort à pied pendant la barre : il tourne le dos au miroir et marche vers P4 (ouverte,
			# comme pour entrer) ; filer vers la porte n'est pas « se retourner »
			var p4d: Door = house.doors["P4"]
			if not p4d.is_open:
				p4d.set_open_now(true)
			var exit_to := Vector3(3.9, 0, -4.6)
			player.set_look(aim(player.global_position, exit_to + Vector3(0, player.EYE, 0)).x, 0.0)
			Input.action_press("move_forward")
			var sorti := func() -> bool: return player.global_position.x < 4.75 or (house.current != null and house.current.room_id == "couloir")
			var out: bool = await until(func() -> bool: return sorti.call() or mirror.p4_issue != "", 8.0)
			await until(func() -> bool: return mirror.p4_issue != "", 3.0)
			await until(func() -> bool: return player.global_position.x < 4.05, 3.0)    # (il passe le seuil)
			Input.action_release("move_forward")
			check("B12 fui : sorti à pied pendant la barre", out and sorti.call() and mirror.p4_issue == "fui",
				"pièce %s · issue « %s » · position %s" % [house.current.room_id if house.current else "?", mirror.p4_issue, player.global_position])
			if house.current == null or house.current.room_id != "couloir":
				player.global_position = Vector3(4.0, 0, -4.4)
			player.set_look(0.0, 0.0)
	if main_path:
		await until(func() -> bool: return events.has("silhouette"), 30.0)
		await wait(1.5)
		check("B11 silhouette dans le flux", sil.is_visible_in_tree() and mirror.feed_shown, "visible %s" % sil.is_visible_in_tree())
		await shot("42_miroir_flux_silhouette")
		await tex_shot(mirror.screen_texture(), "42b_ecran_du_miroir")
		await tex_shot(mirror.feed.texture(), "42c_flux_brut")
		await side_shot(SDB.PLAYER_AT_MIRROR, Vector3(6.6, 0.9, -6.9), "43_baignoire_reelle_vide")
	await until(func() -> bool: return events.has("issue"), 60.0)
	if main_path:
		await wait(2.4 if issue == "fixe" else 1.0)
		await shot("44_issue_%s" % issue)
		await tex_shot(mirror.screen_texture(), "44b_ecran_issue_%s" % issue)
	await until(func() -> bool: return acte2.p4_issue != "", 60.0)
	var t_issue := g_since(t_take)
	await until(func() -> bool: return Game.load_checkpoint().get("checkpoint") == "C2", 10.0)
	var want: float = SmartMirror.P4_PEUR[issue]
	var p4: Door = house.doors["P4"]
	check("B12 %s : issue" % issue, acte2.p4_issue == issue and Game.choices.get("miroir_reel") == issue, "%s / %s" % [acte2.p4_issue, Game.choices.get("miroir_reel")])
	check("B12 %s : jauge +%d" % [issue, int(want)], is_equal_approx(Game.peur - p0, want), "%.1f → %.1f" % [p0, Game.peur])
	check("B12 %s : libre, P4 ouverte, C2" % issue, player.can_move and not p4.locked and (p4.is_open or p4.ajar_deg > 0.0)
		and Game.load_checkpoint().get("checkpoint") == "C2", "mouvement %s · P4 %s" % [player.can_move, p4.is_open])
	print("P4 réel « %s » : issue %.1f s après le sèche-cheveux" % [issue, t_issue])
	if issue == "retourne":
		look_from(SDB.PLAYER_AT_MIRROR, mpos)
		var m9b := "Tu t'es %s." % Game.g("retourné", "retournée")
		await until(func() -> bool: return mirror.text_lines.size() > 0 and str(mirror.text_lines[0]) == m9b, 25.0)
		await wait(0.5)     # (le texte se tape lettre à lettre)
		await shot("44b_retourne_m9b")
		await tex_shot(mirror.screen_texture(), "44c_ecran_m9b")
		await until(func() -> bool: return mirror.text_lines.size() > 0 and str(mirror.text_lines[0]) == "Consigné.", 25.0)
		var m9b_2: String = SmartMirror.P4_TEXTS["M9b_constant" if str(Game.choices.get("reflet", "")) == "retourne" else "M9b_change"]
		check("M9b « %s » « %s »" % [m9b, m9b_2], said_in_order("miroir", [m9b, m9b_2, SmartMirror.P4_TEXTS["M9b_fin"]]) and bool(Game.flag("applique_eclatee", false)),
			str(hn.said("miroir").slice(-3)))
	elif issue == "fui":
		check("M9c", has_said("nestor", SmartMirror.P4_TEXTS["M9c"]), str(hn.said("nestor").slice(-1)))


# ------------------------------------------------------------------ séance seule (fins de l'acte I)

## Séance seule avec des choix imposés : godot -- --autotest --seance=2,1,0,1,0,2/a,b,c --shots=…
func run_seance() -> void:
	print("SÉANCE début : choix ", Game.seance_picks, " saisies ", Game.seance_asks)
	hud.fade.color.a = 0.0
	menu.hide_all()
	Game.phase = "room"
	Game.has_floppy = true
	player.global_position = Vector3(1.2, 0, -1.0)
	player.set_look(0.0, -0.3)
	# (comme le parcours principal : le temps de jeu suit l'horloge, BIOS en mode turbo)
	real_time_pace()
	terminal.turbo = true
	acte1._on_pc_used()
	await terminal.boot_finished
	terminal.autopicks = Game.seance_picks.duplicate()
	terminal.autoasks = Game.seance_asks.duplicate()
	await until(func() -> bool: return acte1.seance_result != "", 240.0)
	await wait(2.0)
	await shot("seance_fin_" + acte1.seance_result)
	print("FIN : %s · peur %d · choix %s · fins trouvées %s" % [acte1.seance_result, int(terminal.fear), Game.choices, terminal.found_endings()])
	check("jauge = Game.peur", is_equal_approx(terminal.fear, Game.peur), "%s / %s" % [terminal.fear, Game.peur])
	# --attendu=<fin>:<jauge> (run_all_032.sh) : la fin et la jauge attendues ; une vraie fin
	# (absorbe, transmission) est écrite dans user://fins.cfg (A5)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--attendu="):
			var want := a.substr(10).split(":")
			var fin := want[0]
			var peur := int(want[1]) if want.size() > 1 else -1
			var written: bool = fin == "suite" or terminal.found_endings().has(fin)
			check("A5 fin « %s », jauge %d" % [fin, peur], acte1.seance_result == fin and (peur < 0 or int(round(Game.peur)) == peur) and written,
				"fin « %s », jauge %.1f, fins.cfg %s" % [acte1.seance_result, Game.peur, terminal.found_endings()])
	finish()


# ------------------------------------------------------------------ sauvegarde (B17)

## --charger=C1 : 1) écrit C1 par le vrai chemin (la clé et le mot ramassés, après une séance « suite »
## simulée), garde l'état d'avant ; 2) recharge la scène, « Continuer » depuis l'écran-titre, compare.
func run_load(id: String) -> void:
	if not id in ["C1", "C2", "C3", "031"]:
		check("B17 %s" % id, false, "points de passage : C1, C2, C3 (et 031 : migration d'une sauvegarde 0.3.1)")
		finish()
		return
	var stage := int(Engine.get_meta(STAGE_META, 1))
	if id == "C3" and stage == 1:
		await _load_write_c3()
	elif id == "C3":
		await _load_check_c3()
	elif id == "031" and stage == 1:
		await _load_write_031()
	elif id == "031":
		await _load_check_031()
	elif id == "C2" and stage == 1:
		await _load_write_c2()
	elif id == "C2":
		await _load_check_c2()
	elif stage == 1:
		await _load_write_c1()
	else:
		await _load_check_c1()


func _load_write_c1() -> void:
	print("CHARGER C1 : écriture (clé et mot ramassés)")
	Game.delete_save()
	hud.fade.color.a = 0.0
	menu.hide_all()
	Game.phase = "room"
	# l'état d'après une séance 1 « suite », sans la jouer
	Game.choices = {"proche": "Mamie", "verres": "gauche", "porte": "preuve", "prix": "personne", "reflet": "fixe", "fin_seance1": "suite", "peur_seance1": 41}
	Game.add_item("journal_manon", "Journal de Maman (2016)", "Caché sous le lit. Les lettres qui brillent…", "doc")
	terminal.set_fear(41.0)
	acte1.seance_result = "suite"
	room.key_under_door()
	await wait(0.6)
	await use_at(Vector3(2.2, 0, 1.32), -PI / 2.0, -1.1, "Ramasser la clé et le mot")
	await wait(0.6)
	hud.close_paper()
	var d := Game.load_checkpoint()
	check("B17 C1 écrit", d.get("checkpoint") == "C1", str(d.get("checkpoint", "rien")))
	check_unstuck("C1")
	var ids := []
	for it in Game.items:
		ids.append(it.id)
	var snap := {
		"hero": Game.hero, "items": ids, "choices": Game.choices.duplicate(true), "flags": Game.flags.duplicate(true),
		"peur": float(d.get("peur", Game.peur)), "peur_floor": Game.peur_floor, "pos": d.get("pos", Vector3.ZERO), "yaw": d.get("yaw", 0.0),
		"doors": door_states(),
	}
	check("B17 C1 position écrite", (d.get("pos", Vector3.ZERO) as Vector3).distance_to(player.global_position) < 0.05, "%s / %s" % [d.get("pos"), player.global_position])
	Engine.set_meta(SNAP_META, snap)
	Engine.set_meta(STAGE_META, 2)
	Engine.set_meta(COUNT_META, [checks, failures])   # (les compteurs survivent au rechargement)
	await shot("c1_avant")
	print("CHARGER C1 : rechargement de la scène")
	get_tree().reload_current_scene()


func _load_check_c1() -> void:
	Engine.remove_meta(STAGE_META)
	var before: Dictionary = Engine.get_meta(SNAP_META, {})
	Engine.remove_meta(SNAP_META)
	var counts: Array = Engine.get_meta(COUNT_META, [0, 0])
	Engine.remove_meta(COUNT_META)
	checks += int(counts[0])
	failures += int(counts[1])
	print("CHARGER C1 : reprise depuis l'écran-titre")
	hud.fade.color.a = 0.0
	menu.show_title()
	await wait(1.0)
	await shot("c1_titre_continuer")
	var first: Button = null
	for c in menu.continue_btn.get_parent().get_children():
		if c is Button and (c as Button).visible:
			first = c
			break
	check("menu « Continuer » en tête", Game.has_save() and first == menu.continue_btn and menu.continue_btn.text.contains("Continuer"),
		"premier bouton : %s" % (first.text if first else "aucun"))
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur     # (dans la chambre, le refuge fait ensuite baisser la jauge)
	await wait(2.5)
	var ids := []
	for it in Game.items:
		ids.append(it.id)
	check("B17 C1 héros", Game.hero == before.get("hero"), Game.hero)
	check("B17 C1 objets", same(ids, before.get("items")), "%s / %s" % [ids, before.get("items")])
	check("B17 C1 choix", same(Game.choices, before.get("choices")), "%s" % [Game.choices])
	var flags_ok := true
	var bad := []
	var bflags: Dictionary = before.get("flags", {})
	for k in bflags:
		if not same(Game.flags.get(k), bflags[k]):
			flags_ok = false
			bad.append(k)
	check("B17 C1 drapeaux", flags_ok, "différents : %s" % [bad])
	check("B17 C1 jauge", is_equal_approx(peur_loaded, float(before.get("peur", -1.0))) and is_equal_approx(Game.peur_floor, float(before.get("peur_floor", -1.0))) and Game.peur >= 25.0,
		"peur %.1f (avant %.1f), plancher %.1f" % [peur_loaded, float(before.get("peur", -1.0)), Game.peur_floor])
	check("B17 C1 position", player.global_position.distance_to(before.get("pos", Vector3.ZERO)) < 0.1 and absf(wrapf(player.yaw - float(before.get("yaw", 0.0)), -PI, PI)) < 0.01,
		"%s lacet %.2f" % [player.global_position, player.yaw])
	check("B17 C1 pièce", house.current != null and house.current.room_id == "mere", house.current.room_id if house.current else "aucune")
	check("B17 C1 P1 ouverte", room.door_node.is_open and not room.door_node.locked, "")
	check("B17 C1 clé et mot", Game.has_item("cle_chambre") and Game.has_item("mot_albert"), "")
	check("B17 C1 chambre", room.wardrobe_open and room.ceiling_dead and not room.floppy.visible and not room.pc_it.enabled, "")
	var journal := find_interactable(room.decor, "Ramasser le carnet")
	check("B17 C1 carnet", journal == null or not journal.enabled, "")
	check("B17 C1 objectif", Game.objective_text == "Sors de la chambre" and acte2.active and Game.phase == "room", "« %s »" % Game.objective_text)
	# (§ 4.2 : Acte1.restore() rend P1 ouverte, la clé est prise ; les autres portes comme avant)
	var bd: Dictionary = (before.get("doors", {}) as Dictionary).duplicate()
	bd["P1"] = [true, false, 0, roundi(rad_to_deg(room.door_node.open_angle))]
	check_doors_same("C1", bd)
	check_unstuck("C1 (rechargé)")
	await shot("c1_reprise")
	await check_refuge()
	await view(Vector3(1.6, 0, 1.4), -PI / 2.0, -0.05, "c1_porte_ouverte", 1.0)
	await view(Vector3(-1.0, 0, 0.2), 0.45, -0.05, "c1_armoire", 1.0)
	await view(Vector3(0.4, 0, -0.9), 0.15, -0.15, "c1_ecran", 1.0)
	finish()


## État des portes P1 à P7 (ouverte, verrouillée, coups sur P2, angle du battant au degré près).
func door_states() -> Dictionary:
	var out := {}
	for id in house.doors:
		var dr: Door = house.doors[id]
		out[id] = [dr.is_open, dr.locked, dr.knocks, roundi(dr.leaf_angle_deg())]
	return out


## B17 : les portes rechargées sont dans l'état d'avant la sauvegarde.
func check_doors_same(tag: String, before: Dictionary) -> void:
	var now := door_states()
	var bad := []
	for id in before:
		if not same(now.get(id), before[id]):
			bad.append("%s %s (avant %s)" % [id, now.get(id), before[id]])
	check("B17 %s portes comme avant" % tag, before.size() == 7 and bad.is_empty(), "différentes : %s" % [bad])


## B18 : dans la chambre de ta mère (refuge), hors séance, la jauge baisse de 0,2 par seconde (le stress
## retombe deux fois plus vite) ; rien pendant une séance ; jamais sous le plancher de 25.
func check_refuge() -> void:
	var where := room_of(player.global_position + Vector3(0, 0.5, 0))
	if Game.peur < 28.0:
		Game.set_peur(32.0, "test B18")
	var p_a := Game.peur
	var t_a := game_t
	await wait(4.0)
	var rate := (p_a - Game.peur) / maxf(g_since(t_a), 0.01)
	print("B18 : la jauge baisse de %.3f par seconde dans « %s » (%.2f → %.2f)" % [rate, where, p_a, Game.peur])
	check("B18 refuge −0,2/s", where == "mere" and rate > 0.17 and rate < 0.23 and is_equal_approx(Game.stress_decay_mult, 2.0),
		"pièce %s · %.3f par seconde · stress ×%.1f" % [where, rate, Game.stress_decay_mult])
	Game.phase = "seated"
	var p_s := Game.peur
	await wait(2.0)
	check("B18 rien pendant une séance", is_equal_approx(Game.peur, p_s), "%.2f → %.2f" % [p_s, Game.peur])
	Game.phase = "room"
	Game.set_peur(25.5, "test B18")
	await wait(5.0)
	check("B18 plancher 25", is_equal_approx(Game.peur, Acte2.PEUR_FLOOR) and is_equal_approx(Game.peur_floor, Acte2.PEUR_FLOOR), "%.2f (plancher %.1f)" % [Game.peur, Game.peur_floor])


# ------------------------------------------------------------------ variantes de l'acte II (§ 6.1)

## Saute l'acte I : l'état d'après une séance 1 « suite » (choix, jauge 41), puis la clé et le mot
## ramassés par le vrai chemin (begin() et C1 écrit), et la chambre comme après la séance (P1 ouverte).
func _jump_acte2() -> void:
	real_time_pace()
	Game.delete_save()
	hud.fade.color.a = 0.0
	menu.hide_all()
	Game.phase = "room"
	Game.choices = {"proche": "Mamie", "verres": "gauche", "porte": "preuve", "prix": "personne", "reflet": "fixe", "fin_seance1": "suite", "peur_seance1": 41}
	terminal.set_fear(41.0)
	acte1.seance_result = "suite"
	room.key_under_door()
	await wait(0.6)
	await use_at(Vector3(2.2, 0, 1.32), -PI / 2.0, -1.1, "Ramasser la clé et le mot")
	await wait(0.4)
	hud.close_paper()
	acte1.restore()
	await wait(0.3)
	check("acte II commencé", acte2.active and Game.load_checkpoint().get("checkpoint") == "C1" and room.door_node.is_open, "")


## Le joueur passe par le couloir, comme dans le jeu (la salle de bain ne s'atteint que par lui) : son
## éveil (N1 à N4) est joué avant la suite, et pas au moment où « fui » y ramène le joueur (le point de
## passage C2 attend la fin des scènes écrites).
func _through_couloir() -> void:
	look_from(Vector3(4.0, 0, 0.6), Vector3(4.0, 1.3, -3.0))
	await until(func() -> bool: return has_said("nestor", Acte2.N4), 60.0)
	await until(func() -> bool: return not main.haunt.is_busy(), 20.0)


## --miroir=fixe|retourne|fui : une issue du P4 réel (B12), depuis la salle de bain, minuteries ×3.
func run_miroir(issue: String) -> void:
	print("MIROIR début · issue ", issue)
	set_sound_captions_from_args()
	await _jump_acte2()
	var sb: Node = house.rooms["sdb"]
	Engine.time_scale = 3.0
	await _through_couloir()
	# (le départ du P4, mesuré à moins de 1 s, se joue à vitesse normale : à × 3, une image de rendu
	# logiciel vaut déjà plus d'une demi-seconde de jeu ; run_p4_at_mirror repasse à × 3 ensuite)
	Engine.time_scale = 1.0
	var t0 := Time.get_ticks_msec()
	await run_p4_at_mirror(sb, issue, false)
	Engine.time_scale = 1.0
	check("B12 %s : moins de 25 s" % issue, t_since(t0) < 25.0, "%.1f s (minuteries ×3)" % t_since(t0))
	check_unstuck("C2 (%s)" % issue)
	await wait(1.0)
	await shot("b12_%s" % issue)
	# 0.3.2 : avec l'antenne (raccourci : la télé n'est pas jouée ici), le P4 réel « %s » mène lui aussi
	# à la convocation (C1) ; C3 est écrit là où est le joueur, ou au couloir devant la chambre
	await until(func() -> bool: return not main.haunt.is_busy(), 30.0)
	check("C1 %s : pas de convocation sans l'antenne" % issue, not bool(Game.flag("convocation", false)) and not room.convoking, "")
	for row in ITEMS_03:
		if row[0] in ["tournevis", "antenne"]:
			Game.add_item(row[0], row[1], row[2], row[3])
	Game.set_flag("antenne_prise", true)
	await check_convocation()
	check_unstuck("C3 (%s)" % issue)
	await shot("b12_%s_convocation" % issue)
	check_c4("miroir « %s »" % issue, 5)
	if Game.sound_captions:
		var texts := []
		for e in hud.caption_log:
			texts.append(e.text)
		var want := [ROOM.MODEM_CAPTION]
		if issue == "fixe":
			want.append_array([SmartMirror.P4_TEXTS["son_rideau"], SmartMirror.P4_TEXTS["son_pas"], SmartMirror.P4_TEXTS["son_souffle"]])
		check("C5 miroir « %s » : sons du P4 et du modem entre crochets" % issue, want.all(func(x: String) -> bool: return texts.has(x)), str(texts))
	finish()


## --revue : revue visuelle rapide des écrans de l'étage (console et ses caméras, flux du miroir).
func run_revue() -> void:
	await _jump_acte2()
	var bu: Node = house.rooms["bureau"]
	var cl: Node = house.rooms["couloir"]
	Game.add_item("cle_bureau", "Clé du bureau", "", "cle")
	(house.doors["P7"] as Door).unlock()
	(house.doors["P7"] as Door).set_open_now(true)
	var console: HouseConsole = bu.console
	look_from(Vector3(6.75, 0, 4.85), console.global_position)
	await until(func() -> bool: return console.booted, 15.0)
	await wait(6.0)
	print("flux qui tournent : ", house.rendering_feeds())
	await tex_shot(console.screen_texture(), "r_console")
	await tex_shot((cl.feed_cam as FeedCam).texture(), "r_cam1_brut")
	await shot("r_bureau")
	# la console en grand (agrandissement entier, pixels nets)
	hud.show_screen(console.screen_texture())
	await wait(0.6)
	await shot("r_console_grand")
	await wait(3.6)
	await shot("r_console_grand_sans_pied")
	hud.close_screen()
	# la photo du couloir (exposition automatique) : le joueur, lampe allumée, dans le couloir
	look_from(Vector3(4.0, 0, 3.6), Vector3(4.0, 0.8, 1.0))
	cl.track(player)
	await until(func() -> bool: return bool(cl.cam_on_target(6.0)), 6.0)
	await wait(0.5)
	var ph: Image = await cl.photo()
	if ph:
		await tex_shot(ImageTexture.create_from_image(ph), "r_photo_couloir")
	var sb: Node = house.rooms["sdb"]
	await run_p4_at_mirror(sb, "fixe", true)
	finish()


## --absorbe : la jauge forcée à 100 dans le couloir (B15) : séquence ABSORBÉ sur l'écran le plus
## proche, fin enregistrée, retour au titre ; « Continuer » reprend C1 avec la jauge de C1.
func run_absorbe() -> void:
	if int(Engine.get_meta(STAGE_META, 1)) == 2:
		await _absorbe_check()
		return
	print("ABSORBÉ début")
	await _jump_acte2()
	var c1 := Game.load_checkpoint()
	look_from(Vector3(4.0, 0, 0.6), Vector3(4.0, 1.3, -3.0))
	await until(func() -> bool: return has_said("nestor", Acte2.N4), 60.0)
	await until(func() -> bool: return not main.haunt.is_busy(), 20.0)
	# (la fin ABSORBÉ est peut-être déjà dans fins.cfg : on la retire pour la voir revenir)
	var got: Array = terminal.found_endings()
	if got.has("absorbe"):
		got.erase("absorbe")
		var cfg := ConfigFile.new()
		cfg.set_value("fins", "trouvees", got)
		cfg.save(TERMINAL.ENDS_PATH)
	terminal.turbo = true      # (le texte du terminal, tapé lettre à lettre, ne ralentit pas le test)
	# un progrès après C1, perdu par ABSORBÉ : la boîte à biscuits ouverte, la clé du bureau en poche
	# (après le rechargement, ce drapeau ne doit pas être réappliqué au monde neuf)
	Game.set_flag("boite_ouverte", true)
	Game.add_item("cle_bureau", "Clé du bureau", "", "cle")
	Game.set_peur(100.0, "test B15")
	await until(func() -> bool: return acte2.absorbed_screen != "", 5.0)
	check("B15 séquence", acte2.absorbed_screen != "" and Game.phase == "end" and not player.can_move, "écran « %s » · phase %s" % [acte2.absorbed_screen, Game.phase])
	await until(func() -> bool: return hud.screen_open, 8.0)
	# ni E ni Échap ne referment l'écran de la séquence : le joueur ne reprend pas la main
	for act in ["interact", "pause"]:
		var ev := InputEventAction.new()
		ev.action = act
		ev.pressed = true
		Input.parse_input_event(ev)
		await wait(0.15)
		var up := InputEventAction.new()
		up.action = act
		up.pressed = false
		Input.parse_input_event(up)
	await wait(0.3)
	check("B15 écran non refermable (E, Échap)", hud.screen_open and hud.screen_locked and not player.can_move and not player.can_look
		and not get_tree().paused and not hud.screen_foot.visible,
		"écran %s · mouvement %s · regard %s · pause %s" % [hud.screen_open, player.can_move, player.can_look, get_tree().paused])
	await wait(5.4)
	await shot("b15_absorbe_%s" % acte2.absorbed_screen)
	# § 1.2 : aucun visage net en dehors de la séance 1 (même quand l'écran est l'ordinateur de ta mère)
	check("B15 pas de visage", terminal.watch.modulate.a < 0.05, "visage du terminal à %.2f" % terminal.watch.modulate.a)
	await until(func() -> bool: return terminal.found_endings().has("absorbe"), 40.0)
	check("B15 fin enregistrée", terminal.found_endings().has("absorbe"), str(terminal.found_endings()))
	await until(func() -> bool: return hud.fade.color.a > 0.95, 30.0)
	await wait(2.5)
	await shot("b15_epilogue")
	Engine.set_meta(SNAP_META, {"peur": float(c1.get("peur", -1.0)), "checkpoint": c1.get("checkpoint", ""), "pos": c1.get("pos", Vector3.ZERO)})
	Engine.set_meta(STAGE_META, 2)
	Engine.set_meta(COUNT_META, [checks, failures])
	print("ABSORBÉ : l'épilogue recharge la scène")
	# (acte1._epilogue recharge la scène : la suite est dans _absorbe_check)


func _absorbe_check() -> void:
	Engine.remove_meta(STAGE_META)
	var before: Dictionary = Engine.get_meta(SNAP_META, {})
	Engine.remove_meta(SNAP_META)
	var counts: Array = Engine.get_meta(COUNT_META, [0, 0])
	Engine.remove_meta(COUNT_META)
	checks += int(counts[0])
	failures += int(counts[1])
	print("ABSORBÉ : scène rechargée, écran-titre")
	# le monde reconstruit est neuf (rien de la partie d'avant n'y est réappliqué) : une « Nouvelle
	# partie » trouverait P1 fermée à clé (A3) et la boîte à biscuits pleine
	var am0: Node = house.rooms["amis"]
	check("B15 monde neuf après le rechargement", room.door_node.locked and not room.door_node.is_open and am0.tin_it.enabled
		and not Game.flags.has("boite_ouverte") and not Game.flags.has("acte2") and Game.items.is_empty(),
		"P1 verrouillée %s ouverte %s · boîte %s · %d drapeaux · %d objets" % [room.door_node.locked, room.door_node.is_open, am0.tin_it.enabled, Game.flags.size(), Game.items.size()])
	hud.fade.color.a = 0.0
	menu.show_title()
	await wait(1.0)
	check("B15 retour au titre", menu.title_box.visible and menu.continue_btn.visible and Game.has_save(), "")
	await shot("b15_titre")
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur     # (dans la chambre, le refuge fait ensuite baisser la jauge)
	await wait(2.5)
	check("B15 reprise au dernier point", Game.load_checkpoint().get("checkpoint") == before.get("checkpoint") and is_equal_approx(peur_loaded, float(before.get("peur", -1.0)))
		and player.global_position.distance_to(before.get("pos", Vector3.ZERO)) < 0.1 and acte2.active and Game.phase == "room",
		"point %s · peur %.1f (attendu %.1f)" % [Game.load_checkpoint().get("checkpoint"), peur_loaded, float(before.get("peur", -1.0))])
	await shot("b15_reprise")
	# la clé du bureau, prise après C1, est retournée dans la boîte (B14)
	var am: Node = house.rooms["amis"]
	check("B15 reprise : la boîte rend la clé du bureau", not Game.has_item("cle_bureau") and am.tin_it.enabled, "boîte %s · clé en poche %s" % [am.tin_it.enabled, Game.has_item("cle_bureau")])
	check_unstuck("C1 après ABSORBÉ")
	finish()


## --indices : minuteries des indices ×30 (90 s → 3 s). Chaque étape donne son texte (§ 5.6.8) par le
## bon appareil, jauge +1 ; aucun indice pendant une lecture ni pendant une scène écrite (B13).
func run_indices() -> void:
	print("INDICES début · vitesse ×", main.haunt.hint_speed)
	await _jump_acte2()
	var hn: Haunt = main.haunt
	check("B13 minuteries ×30", is_equal_approx(hn.hint_speed, 30.0) and is_equal_approx(hn.hint_delay, Haunt.HINT_DELAY), "×%.0f, %.0f s" % [hn.hint_speed, hn.hint_delay])
	# « sortir » : l'écran de l'ordinateur de ta mère
	look_from(Vector3(0.9, 0, -0.9), room.screen_center)
	var n0 := hn.hints_given
	var p_h := Game.peur
	await until(func() -> bool: return hn.hints_given > n0, 20.0)
	var t_h1 := game_t
	var p_h1 := Game.peur
	var e := _last_hint()
	check("B13 sortir", e.get("text") == Acte2.HINT_SORTIR and e.get("dev") == "pc_manon" and _hint_peur_logged(), str(e))
	# (le second indice suit 90 s / 30 = 3 s de jeu plus tard ; la chambre est un refuge : la jauge y
	# baisse de 0,2 par seconde, on compare donc l'écart de l'indice au journal)
	await until(func() -> bool: return hn.hints_given > n0 + 1, 10.0)
	var gap_s := g_since(t_h1)
	print("B13 : %.2f s de jeu entre deux indices (90 s / %.0f)" % [gap_s, hn.hint_speed])
	check("B13 90 s ×30 = 3 s, jauge +1", gap_s >= 2.6 and gap_s <= 4.0 and _hint_peur_logged(),
		"%.2f s entre deux indices · jauge %.1f → %.1f" % [gap_s, p_h, p_h1])
	await wait(2.5)
	var on_screen := false
	for ln in terminal.lines:
		var t := ""
		for sg in ln.segs:
			t += str(sg[0])
		on_screen = on_screen or t.contains("Tu attends quoi")
	check("B13 sortir sur l'écran", on_screen, "")
	await shot("b13_sortir_ecran")
	# rien pendant une lecture
	hud.read_paper("Ferme à clé de l'intérieur.\nN'ouvre à personne.\nMême pas à moi.\n\n— A.")
	var n1 := hn.hints_given
	await wait(8.0)
	check("B13 rien pendant une lecture", hn.hints_given == n1, "%d indices" % (hn.hints_given - n1))
	hud.close_paper()
	# rien pendant la pause
	main.pause()
	var n_p := hn.hints_given
	await wait(8.0)
	check("B13 rien pendant la pause", hn.hints_given == n_p and get_tree().paused and menu.pause_box.visible, "%d indices" % (hn.hints_given - n_p))
	await shot("b13_pause")
	menu.hide_all()
	get_tree().paused = false
	var resumed: bool = await until(func() -> bool: return hn.hints_given > n_p, 10.0)
	check("B13 indices repris après la pause", resumed, "")
	# rien pendant une scène écrite (l'éveil du couloir), puis « mamie » par Nestor
	look_from(Vector3(4.0, 0, 0.6), Vector3(4.0, 1.3, -3.0))
	await until(func() -> bool: return main.haunt.is_busy(), 5.0)
	var n2 := hn.hints_given
	await until(func() -> bool: return not main.haunt.is_busy(), 60.0)
	check("B13 rien pendant une scène", hn.hints_given == n2, "%d indices" % (hn.hints_given - n2))
	await until(func() -> bool: return hn.hints_given > n2, 20.0)
	e = _last_hint()
	check("B13 mamie", e.get("text") == Acte2.HINT_MAMIE and e.get("dev") == "nestor", str(e))
	# « explorer » : après la porte d'Henriette, la boîte à biscuits (Nestor ou babyphone)
	var t_knock := game_t
	await use_at(Vector3(4.1, 0, -3.6), PI / 2.0, -0.1, "Frapper à la porte")
	# B5, l'autre déclencheur : loin du radiateur, le S.O.S. part 25 s après le premier appui
	player.global_position = Vector3(4.0, 0, 2.2)
	player.set_look(PI, -0.05)
	await until(func() -> bool: return has_said("nestor", Acte2.N7), 40.0)
	await until(func() -> bool: return hn.has_logged("sos"), 60.0)
	var t_sos := g_since(t_knock)
	print("B5 : S.O.S. %.1f s après le 1er appui sur P2 (%s)" % [t_sos, acte2.sos_source])
	check("B5 S.O.S. à 25 s (minuterie)", acte2.sos_source == "minuterie" and hn.count("sos") == 1 and t_sos >= 24.5 and t_sos <= 29.0,
		"%.1f s après le 1er appui (%s)" % [t_sos, acte2.sos_source])
	await until(func() -> bool: return not main.haunt.is_busy() and hn.has_logged("sos"), 60.0)
	check("B5 N8 N9 (minuterie)", said_in_order("nestor", [Acte2.N8, Acte2.N9]), str(hn.said("nestor").slice(-2)))
	await until(func() -> bool: return not main.haunt.is_busy(), 60.0)
	var n3 := hn.hints_given
	await until(func() -> bool: return hn.hints_given > n3, 20.0)
	e = _last_hint()
	check("B13 explorer : boîte", e.get("text") == Acte2.HINT_BOITE and ["nestor", "babyphone"].has(e.get("dev")), str(e))
	await shot("b13_explorer_nestor")
	# l'ordre du tableau (le premier manque)
	var order := []
	Game.add_item("cle_bureau", "Clé du bureau", "", "cle")
	order.append(_hint_text())
	Game.set_flag("porte_P7", "ouverte")
	order.append(_hint_text())
	Game.set_flag("antenne_examinee", true)
	order.append(_hint_text())
	Game.add_item("tournevis", "Tournevis de Papi", "", "outil")
	order.append(_hint_text())
	Game.add_item("antenne", "Antenne télescopique", "", "arme")
	order.append(_hint_text())
	Game.add_item("seche_cheveux", "Sèche-cheveux de Mamie", "", "arme")
	Game.choices["miroir_reel"] = "fixe"
	order.append(_hint_text())
	var want := [Acte2.HINT_CABLE, Acte2.HINT_MIROIR, Acte2.HINT_TIROIR, Acte2.HINT_ANTENNE, Acte2.HINT_MIROIR, ""]
	check("B13 explorer : ordre du tableau", order == want, str(order))
	# C4 : au calme dans le couloir, une scène écrite : le cœur s'entend, puis se tait en moins de 12 s
	await check_c4_calm("indices")
	check_c4("indices", 5)
	finish()


func _hint_text() -> String:
	var r: Variant = acte2.explore_hint()
	return str((r as Dictionary).get("text", "")) if r is Dictionary else str(r)


func _last_hint() -> Dictionary:
	var hn: Haunt = main.haunt
	for i in range(hn.journal.size() - 1, -1, -1):
		if hn.journal[i].get("ev") == "indice":
			return hn.journal[i]
	return {}


func _hint_peur_logged() -> bool:
	var hn: Haunt = main.haunt
	for i in range(hn.journal.size() - 1, -1, -1):
		var e: Dictionary = hn.journal[i]
		if e.get("ev") == "peur" and e.get("why") == "indice" and is_equal_approx(float(e.get("v", 0.0)), 1.0):
			return true
	return false


## --charger=C2 (B17) : 1) le P4 réel par le vrai chemin (issue « fui », la plus courte), C2 écrit ;
## 2) rechargement de la scène, « Continuer », comparaison champ par champ avec la sauvegarde.
func _load_write_c2() -> void:
	print("CHARGER C2 : écriture (P4 réel)")
	await _jump_acte2()
	var sb: Node = house.rooms["sdb"]
	Engine.time_scale = 3.0
	await _through_couloir()
	Engine.time_scale = 1.0     # (run_p4_at_mirror passe à × 3 après le départ du P4)
	await run_p4_at_mirror(sb, "fui", false)
	Engine.time_scale = 1.0
	var doors_c2 := door_states()      # (les portes au moment où C2 est écrit)
	await until(func() -> bool: return not main.haunt.is_busy(), 60.0)
	var d := Game.load_checkpoint()
	check("B17 C2 écrit", d.get("checkpoint") == "C2", str(d.get("checkpoint", "rien")))
	check_unstuck("C2")
	var ids := []
	for it in d.get("items", []):
		ids.append(str((it as Dictionary).get("id", "")))
	Engine.set_meta(SNAP_META, {"hero": d.get("hero"), "items": ids, "choices": d.get("choices", {}), "flags": d.get("flags", {}),
		"peur": d.get("peur"), "peur_floor": d.get("peur_floor"), "pos": d.get("pos", Vector3.ZERO), "yaw": d.get("yaw", 0.0),
		"doors": doors_c2})
	Engine.set_meta(STAGE_META, 2)
	Engine.set_meta(COUNT_META, [checks, failures])
	await shot("c2_avant")
	print("CHARGER C2 : rechargement de la scène")
	get_tree().reload_current_scene()


func _load_check_c2() -> void:
	Engine.remove_meta(STAGE_META)
	var before: Dictionary = Engine.get_meta(SNAP_META, {})
	Engine.remove_meta(SNAP_META)
	var counts: Array = Engine.get_meta(COUNT_META, [0, 0])
	Engine.remove_meta(COUNT_META)
	checks += int(counts[0])
	failures += int(counts[1])
	print("CHARGER C2 : reprise depuis l'écran-titre")
	hud.fade.color.a = 0.0
	menu.show_title()
	await wait(1.0)
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur
	await wait(2.5)
	var ids := []
	for it in Game.items:
		ids.append(it.id)
	check("B17 C2 objets", same(ids, before.get("items")), "%s / %s" % [ids, before.get("items")])
	check("B17 C2 choix", same(Game.choices, before.get("choices")) and Game.choices.get("miroir_reel") == "fui", "%s" % [Game.choices])
	var bad := []
	var bflags: Dictionary = before.get("flags", {})
	for k in bflags:
		if not same(Game.flags.get(k), bflags[k]):
			bad.append(k)
	check("B17 C2 drapeaux", bad.is_empty() and bflags.size() > 5, "différents : %s" % [bad])
	check("B17 C2 jauge", is_equal_approx(peur_loaded, float(before.get("peur", -1.0))) and is_equal_approx(Game.peur_floor, float(before.get("peur_floor", -1.0))),
		"peur %.1f (avant %.1f)" % [Game.peur, float(before.get("peur", -1.0))])
	check("B17 C2 position", player.global_position.distance_to(before.get("pos", Vector3.ZERO)) < 0.1 and absf(wrapf(player.yaw - float(before.get("yaw", 0.0)), -PI, PI)) < 0.01,
		"%s lacet %.2f" % [player.global_position, player.yaw])
	var sb: Node = house.rooms["sdb"]
	var mirror: SmartMirror = sb.mirror
	check("B17 C2 salle de bain", not (sb.dryer as Node3D).visible and not mirror.is_on and not mirror.p4_running and Game.has_item("seche_cheveux"), "")
	check("B17 C2 portes", room.door_node.is_open and not (house.doors["P4"] as Door).locked and (house.doors["P2"] as Door).locked, "")
	check("B17 C2 objectif", acte2.active and Game.objective_text == acte2.objective() and Game.phase == "room", "« %s »" % Game.objective_text)
	check_doors_same("C2", before.get("doors", {}))
	check_unstuck("C2 (rechargé)")
	await shot("c2_reprise")
	finish()


# ------------------------------------------------------------------ menus et HUD

## --ecrans : les menus et le HUD en 20 px (lisibles, dans l'écran), avec captures.
func run_screens() -> void:
	print("ÉCRANS début")
	hud.fade.color.a = 0.0
	# C6 : l'avertissement au premier lancement seulement. Avec un dossier user:// vide (run_all_032.sh
	# isole chaque variante), c'est un vrai premier lancement : « J'ai compris » écrit le drapeau dans
	# settings.cfg, et un Game neuf (second lancement) le relit. Sinon, sans toucher au settings.cfg du
	# joueur, on simule.
	var first := not FileAccess.file_exists(Game.SETTINGS_PATH)
	var seen := Game.seen_warning
	if not first:
		Game.seen_warning = false
	menu.show_start()
	await wait(0.6)
	check("C6 avertissement", menu.warning_box.visible and not menu.title_box.visible and fits(menu.warning_box), str(menu.warning_box.get_global_rect()))
	await shot("e00_avertissement")
	if first:
		var ok_btn: Button = null
		for b in menu.warning_box.find_children("*", "Button", true, false):
			if (b as Button).text.contains("J'ai compris"):
				ok_btn = b
		if ok_btn:
			ok_btn.pressed.emit()
		await wait(0.3)
		var cfg := ConfigFile.new()
		cfg.load(Game.SETTINGS_PATH)
		check("C6 premier lancement : « J'ai compris » écrit le drapeau, puis le titre", ok_btn != null
			and bool(cfg.get_value("accessibilite", "avertissement_vu", false)) and menu.title_box.visible and not menu.warning_box.visible,
			"bouton %s · drapeau %s · titre %s" % [ok_btn != null, cfg.get_value("accessibilite", "avertissement_vu", false), menu.title_box.visible])
		var g2: Node = GAME.new()
		g2._load_settings()
		Game.seen_warning = bool(g2.get("seen_warning"))
		g2.free()
		menu.show_start()
		check("C6 second lancement : directement le titre", Game.seen_warning and menu.title_box.visible and not menu.warning_box.visible, "")
	else:
		print("C6 : settings.cfg existe déjà (dossier user:// du joueur) : premier lancement simulé")
		Game.seen_warning = true
		menu.show_start()
		check("C6 ensuite le titre", menu.title_box.visible and not menu.warning_box.visible, "")
		Game.seen_warning = seen
	# écran-titre avec « Continuer » (une sauvegarde de test)
	Game.save_checkpoint("C1", Vector3.ZERO, 0.0)
	menu.show_title()
	await wait(0.6)
	check("titre « Continuer »", menu.continue_btn.visible, "")
	check("titre dans l'écran", fits(menu.title_box.get_child(0)), str((menu.title_box.get_child(0) as Control).get_global_rect()))
	await shot("e01_titre")
	Game.delete_save()
	menu.show_options("title")
	await wait(0.5)
	var ot := texts_of(menu.options_box)
	check("options son", ot.contains("Sous-titres des sons") and ot.contains("Chuchotements (synthèse Windows)"), ot)
	check("options dans l'écran", fits(menu.options_box), str(menu.options_box.get_global_rect()))
	await shot("e02_options")
	menu.show_hero()
	await wait(0.5)
	check("héros dans l'écran", fits(menu.hero_box), str(menu.hero_box.get_global_rect()))
	await shot("e03_heros")
	menu.show_pause()
	await wait(0.3)
	await shot("e04_pause")
	menu.hide_all()
	# C7 : chuchotements coupés par défaut ; la case est décochée ; Game.whisper ne fait rien
	var fresh: Node = GAME.new()
	check("C7 chuchotements coupés par défaut", fresh.get("whispers") == false, str(fresh.get("whispers")))
	fresh.free()
	var box: CheckBox = null
	for c in menu.options_box.find_children("*", "CheckBox", true, false):
		if (c as CheckBox).text == "Chuchotements (synthèse Windows)":
			box = c
	check("C7 case « Chuchotements (synthèse Windows) » décochée", box != null and not box.button_pressed and not Game.whispers,
		"case %s · Game.whispers %s" % [box.button_pressed if box else "absente", Game.whispers])
	Game.whisper("C'est toi. C'est toi.")
	await wait(0.2)
	check("C7 Game.whisper ne fait rien", not Game.whispers and not DisplayServer.tts_is_speaking(), "")
	# C5 : l'option « Sous-titres des sons » est gardée dans settings.cfg (aller-retour par un Game neuf)
	var keep := Game.sound_captions
	for v in [true, false]:
		Game.sound_captions = v
		Game.save_settings()
		var g: Node = GAME.new()
		g._load_settings()
		check("C5 option gardée (%s)" % ("cochée" if v else "décochée"), g.get("sound_captions") == v, str(g.get("sound_captions")))
		g.free()
	Game.sound_captions = keep
	# A9 : « sursauts réduits » et « éclairs adoucis » gardés dans settings.cfg (aller-retour)
	var keep_rs := Game.reduced_scares
	var keep_sf := Game.soft_flashes
	for v in [true, false]:
		Game.reduced_scares = v
		Game.soft_flashes = not v
		Game.save_settings()
		var g9: Node = GAME.new()
		g9._load_settings()
		check("A9 options gardées (sursauts réduits %s, éclairs adoucis %s)" % ["oui" if v else "non", "non" if v else "oui"],
			g9.get("reduced_scares") == v and g9.get("soft_flashes") == (not v), "%s / %s" % [g9.get("reduced_scares"), g9.get("soft_flashes")])
		g9.free()
	Game.reduced_scares = keep_rs
	Game.soft_flashes = keep_sf
	Game.save_settings()
	# le HUD dans la chambre
	Game.phase = "room"
	player.global_position = Acte1.START_POS
	player.set_look(Acte1.START_YAW, -0.05)
	Game.objective("Elle t'attend dans la salle de bain", "Croquis de Maman : 1/4 · Papi est à la cave")
	Game.hint("« CERAF · INVENTAIRE N° 0312. Propriété du CERAF, ne pas sortir du site. » L'ordinateur de ta mère vient d'un laboratoire.", 30.0)
	hud.subtitle("Nestor", "Ici, ils m'appellent Nestor. Ta grand-mère me dit merci. Je l'ai noté.", "elle")
	Game.add_item("mot_albert", "Mot de Papi", "« N'ouvre à personne. Même pas à moi. »", "doc")
	await wait(1.0)
	check("pensée sur 3 lignes au plus", hud.hint_lbl.get_line_count() <= 3, "%d lignes" % hud.hint_lbl.get_line_count())
	check("sous-titre au-dessus de la pensée", hud.sub_lbl.get_global_rect().end.y <= hud.hint_lbl.get_global_rect().end.y - hud.hint_lbl.get_line_count() * 20 + 2,
		"%s / %s" % [hud.sub_lbl.get_global_rect(), hud.hint_lbl.get_global_rect()])
	await shot("e05_hud")
	Game.hint("", 0.1)
	await wait(0.8)
	await shot("e05b_sous_titre")
	hud.clear_subtitles()
	# l'inventaire plein (tous les objets de la v0.3)
	for x in ITEMS_03:
		Game.add_item(x[0], x[1], x[2], x[3])
	hud.toggle_inventory()
	await wait(0.6)
	check("inventaire plein dans l'écran", fits(hud.inv), str(hud.inv.get_global_rect()))
	await shot("e06_inventaire_plein")
	hud.toggle_inventory()
	# le mot de Papi, le mot de Mamie (A2), le journal (A4), une feuille imprimée
	hud.read_paper("Ferme à clé de l'intérieur.\nN'ouvre à personne.\nMême pas à moi.\n\n— A.")
	await wait(0.5)
	await shot("e07_mot_papi")
	hud.close_paper()
	var mamie := find_interactable(room.decor, "Lire le mot de Mamie")
	if mamie:
		mamie.use()
	await wait(0.5)
	check("A2 mot de Mamie", hud.paper_open and hud.paper_text.text.contains(Game.g("mon grand", "ma grande")), hud.paper_text.text.left(40))
	await shot("e08_mot_mamie")
	hud.close_paper()
	var carnet := find_interactable(room.decor, "Ramasser le carnet")
	if carnet:
		carnet.use()
	await wait(0.5)
	check("A4 journal", Game.has_item("journal_manon") and hud._pages.size() == 7, "%d pages" % hud._pages.size())
	await shot("e09_journal")
	for i in 6:
		hud._next_page()
	await wait(0.3)
	await shot("e10_journal_morse")
	hud.close_paper()
	hud.read_image(load("res://assets/images/croquis_fractionneur.png"), "Le croquis de ta mère, plus net que dans le journal. En bas, imprimé : « Construis-le. Je veux voir. »")
	await wait(0.5)
	check("légende dans l'écran", fits(hud.paper_legend) and hud.paper_legend.get_line_count() <= 2, str(hud.paper_legend.get_global_rect()))
	await shot("e11_feuille")
	hud.close_paper()
	hud.sound_caption("[Coups dans le radiateur, en bas]", true)
	await wait(0.5)
	await shot("e12_son")
	finish()


# ------------------------------------------------------------------ B1 : meubles, positions, battants

## Zone balayée par le battant d'une porte, au sol (Rect2 : x, z, largeur en x, profondeur en z) : du
## côté où elle pivote, 0,95 m depuis la face du mur, 0,5 m de part et d'autre de l'axe de la porte
## (§ 5.2 : « zone libre de P4 : x 4.8 → 5.75, z −5.1 → −4.0 »). Toutes les portes sont sur des murs d'axe x.
static func door_zone(d: Dictionary) -> Rect2:
	var sr: Array = HouseData.F1_ROOMS[d.swing].rect
	var side := -1.0 if (float(sr[0]) + float(sr[1])) / 2.0 < float(d.at) else 1.0
	var face: float = float(d.at) + side * HouseData.WALL / 2.0
	return Rect2(face if side > 0.0 else face - SWING_DEPTH, float(d.c) - SWING_HALF, SWING_DEPTH, 2.0 * SWING_HALF)


## Boîtes englobantes (repère du jeu) de tout ce que le script d'une pièce de l'étage a posé (furnish) :
## les enfants qui suivent la coque (sol, plafond, papier peint, plinthes ; house.gd note leur nombre
## dans la méta « coque »). Rend [[nom, AABB]]. Les objets « flux uniquement » (couche 11 seule) sont
## ignorés : le joueur ne peut pas les heurter.
func furniture_boxes(r: HouseRoom) -> Array:
	var out := []
	var n0 := int(r.get_meta("coque", -1))
	if n0 < 0:
		return out
	for i in range(n0, r.get_child_count()):
		var c := r.get_child(i)
		var geos: Array = c.find_children("*", "GeometryInstance3D", true, false)
		if c is GeometryInstance3D:
			geos.append(c)
		for g in geos:
			var gi := g as GeometryInstance3D
			if not (gi.layers & 1):
				continue
			var box: AABB = gi.global_transform * gi.get_aabb()
			out.append(["%s/%s" % [c.name, gi.name], box])
	return out


## B1 : aucun meuble dans la zone d'un battant. Chaque boîte englobante des pièces meublées contre le
## rectangle de battant de chaque porte (P1 à P7). Les objets à plat sur le sol (tapis, câble, scotch :
## le battant passe au-dessus, à 2 cm) et ceux au-dessus de la porte (plafonniers) ne gênent pas.
func check_door_zones() -> void:
	var bad := []
	var n := 0
	var rooms_seen := []
	for id in house.rooms:
		var boxes := furniture_boxes(house.rooms[id])
		if boxes.is_empty():
			continue
		rooms_seen.append(id)
		for e in boxes:
			var box: AABB = e[1]
			if box.end.y < LEAF_BOTTOM or box.position.y > LEAF_TOP:
				continue
			n += 1
			var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			for d in HouseData.F1_DOORS:
				if foot.intersects(door_zone(d).grow(-0.005)):
					bad.append("%s %s %s dans la zone de %s" % [id, e[0], _fmt_box(box), d.id])
	for b in bad:
		print("  B1 : ", b)
	check("B1 battants libres", bad.is_empty() and n > 100 and rooms_seen.has("couloir") and rooms_seen.has("sdb") and rooms_seen.has("amis")
		and rooms_seen.has("bureau") and rooms_seen.has("gp"),
		"%d conflits (%d boîtes, pièces %s) : %s" % [bad.size(), n, rooms_seen, bad.slice(0, 4)])


static func _fmt_box(b: AABB) -> String:
	return "x %.2f→%.2f z %.2f→%.2f y %.2f→%.2f" % [b.position.x, b.end.x, b.position.z, b.end.z, b.position.y, b.end.y]


## B1 : les éléments principaux aux positions du § 5.2 (à 12 cm près, au sol ; y comparé s'il est donné).
func check_positions() -> void:
	var cl: Node = house.rooms.get("couloir")
	var am: Node = house.rooms.get("amis")
	var bu: Node = house.rooms.get("bureau")
	var sb: Node = house.rooms.get("sdb")
	var gp: Node = house.rooms.get("gp")
	var out_n: Node = room.outside
	var want := [   # [libellé, nœud, position attendue, comparer y]
		["couloir console", cl.props.get("sideTable"), Vector3(3.52, 0, -1.0), false],
		["couloir Nestor", cl.nestor, Vector3(3.52, 0, -1.0), false],
		["couloir caméra dôme", cl.cam_pivot, Vector3(4.0, 2.52, -7.18), true],
		["couloir L1", cl.smart_bulbs[0], Vector3(4.0, 2.6, -5.0), false],
		["couloir L2", cl.smart_bulbs[1], Vector3(4.0, 2.6, -0.5), false],
		["couloir L3", cl.smart_bulbs[2], Vector3(4.0, 2.6, 4.0), false],
		["sdb baignoire", sb.props.get("bathtub"), Vector3(6.6, 0, -6.92), false],
		["sdb lavabo", sb.props.get("bathroomSink"), Vector3(7.0, 0, -4.27), false],
		["sdb miroir", sb.mirror, Vector3(7.0, 1.5, -4.03), true],
		["sdb armoire basse", sb.props.get("bathroomCabinetDrawer"), Vector3(7.85, 0, -4.25), false],
		["sdb WC", sb.props.get("toilet"), Vector3(8.85, 0, -4.55), false],
		["sdb tapis", sb.props.get("rugRound"), Vector3(6.6, 0, -5.95), false],
		["amis lit", am.props.get("bedDouble"), Vector3(0.0, 0, 5.25), false],
		["amis chevet", am.props.get("cabinetBedDrawer"), Vector3(1.15, 0, 5.95), false],
		["amis meuble TV", am.props.get("cabinetTelevision"), Vector3(-1.2, 0, 2.95), false],
		["amis coin couture", am.props.get("desk"), Vector3(-2.85, 0, 3.45), false],
		["amis chaise", am.props.get("chair"), Vector3(-2.3, 0, 3.45), false],
		["amis boîte à biscuits", am.tin, Vector3(-2.9, 0.78, 3.9), false],
		["amis lampadaire", am.props.get("lampRoundFloor"), Vector3(-1.6, 0, 6.0), false],
		["amis carton", am.props.get("cardboardBoxOpen"), Vector3(2.75, 0, 4.6), false],
		["bureau bureau du PC", bu.props.get("desk"), Vector3(7.2, 0, 5.95), false],
		["bureau chaise", bu.props.get("chairDesk"), Vector3(7.2, 0, 5.35), false],
		["bureau imprimante", bu.printer, Vector3(8.3, 0, 6.05), false],
		["bureau box", bu.box, Vector3(5.55, 0.02, 6.18), false],
		["bureau table", bu.props.get("table"), Vector3(7.0, 0, 2.4), false],
		["bureau tapis", bu.props.get("rugRectangle"), Vector3(6.9, 0, 4.2), false],
		["gp lit", gp.props.get("bedDouble"), Vector3(-0.6, 0, -3.8), false],
		["gp CAM 3", gp.cam3, Vector3(2.9, 2.35, -6.9), true],
		["dehors socle de Clovis", out_n.socle, Vector3(-6.4, -2.8, 1.6), false],
		["dehors CAM 2", out_n.cam2, Vector3(-3.45, -0.45, 0.6), true],
	]
	var bad := []
	for w in want:
		var nd := w[1] as Node3D
		if nd == null:
			bad.append("%s : absent" % w[0])
			continue
		var p := nd.global_position
		var q: Vector3 = w[2]
		var dxz := Vector2(p.x - q.x, p.z - q.z).length()
		var dy := absf(p.y - q.y) if bool(w[3]) else 0.0
		if dxz > POS_TOL or dy > POS_TOL:
			bad.append("%s en (%.2f, %.2f, %.2f), attendu (%.2f, %.2f, %.2f)" % [w[0], p.x, p.y, p.z, q.x, q.y, q.z])
	for b in bad:
		print("  B1 position : ", b)
	check("B1 positions § 5.2", bad.is_empty(), "%d écarts : %s" % [bad.size(), bad])


## B16 : temps de construction de la maison et de cuisson de la GI (imprimés par main.gd), au plus
## 1,5 fois ceux de la 0.3.0 en rendu logiciel (maison ≈ 2250 ms, VoxelGI ≈ 950 ms).
func check_build_times() -> void:
	print("B16 : maison construite en %d ms (au plus %d), VoxelGI cuit en %d ms (au plus %d)" % [main.build_ms, int(BUILD_MS_030 * 1.5), main.gi_ms, int(GI_MS_030 * 1.5)])
	check("B16 temps de construction", main.build_ms > 0 and main.build_ms <= BUILD_MS_030 * 1.5 and main.gi_ms > 0 and main.gi_ms <= GI_MS_030 * 1.5,
		"maison %d ms, GI %d ms" % [main.build_ms, main.gi_ms])


# ------------------------------------------------------------------ B14 : anti-blocage

## Pièce (id) qui contient le point p, ou "".
func room_of(p: Vector3) -> String:
	for id in house.rooms:
		if (house.rooms[id] as HouseRoom).contains(p, 0.02):
			return id
	return ""


## Où se prend chaque objet indispensable : l'interaction qui le donne (sa pièce est celle où elle se
## trouve) et les objets qu'il faut avoir avant.
func _givers() -> Dictionary:
	var am: Node = house.rooms.get("amis")
	var bu: Node = house.rooms.get("bureau")
	var sb: Node = house.rooms.get("sdb")
	return {
		"cle_chambre": {"it": find_interactable(room, "Ramasser la clé et le mot"), "needs": []},
		"cle_bureau": {"it": am.tin_it, "needs": []},
		"tournevis": {"it": bu.drawer_it, "needs": []},
		"seche_cheveux": {"it": sb.dryer_it, "needs": []},
		"antenne": {"it": am.antenna_it, "needs": ["tournevis"]},
	}


## B14 : depuis la pièce du joueur, avec l'inventaire courant, on parcourt le graphe des portes qu'on
## peut ouvrir (ouverte, déverrouillée ou coincée, ou dont on a la clé) ; chaque objet indispensable
## trouvé dans une pièce atteinte (interaction encore active, objets requis en poche) rejoint
## l'inventaire, ce qui peut ouvrir d'autres portes. À la fin, les cinq objets doivent y être.
func check_unstuck(tag: String) -> void:
	var inv := {}
	for it in Game.items:
		inv[it.id] = true
	var start := room_of(player.global_position + Vector3(0, 0.5, 0))
	var reach := {start: true}
	var givers := _givers()
	var order := []
	var changed := true
	while changed:
		changed = false
		for d in HouseData.F1_DOORS:
			var dr: Door = house.doors.get(d.id)
			var a := room_of(Vector3(float(d.at) - 0.3, 1.0, float(d.c)))
			var b := room_of(Vector3(float(d.at) + 0.3, 1.0, float(d.c)))
			if dr == null or a == "" or b == "" or reach.has(a) == reach.has(b):
				continue
			if dr.is_open or not dr.locked or (dr.key_id != "" and inv.has(dr.key_id)):
				reach[a] = true
				reach[b] = true
				order.append(d.id)
				changed = true
		for id in ESSENTIELS:
			if inv.has(id):
				continue
			var g: Dictionary = givers[id]
			var it: Interactable = g.it
			if it == null or not is_instance_valid(it) or not it.enabled or not reach.has(room_of(it.global_position)):
				continue
			var ready := true
			for k in g.needs:
				ready = ready and inv.has(k)
			if ready:
				inv[id] = true
				order.append(id)
				changed = true
	var missing := []
	for id in ESSENTIELS:
		if not inv.has(id):
			missing.append(id)
	print("B14 %s : départ « %s », parcours %s" % [tag, start, order])
	check("B14 anti-blocage %s" % tag, start != "" and missing.is_empty(), "inaccessibles : %s · pièces atteintes : %s" % [missing, reach.keys()])


# ------------------------------------------------------------------ aperçu d'une pièce

## --preview=<pièce>[,<pièce>…] : vues de chaque pièce (B1 : 6 captures par pièce), plus les
## vérifications B1 (positions du § 5.2, battants libres).
func run_previews(ids: String) -> void:
	hud.fade.color.a = 0.0
	menu.hide_all()
	Game.phase = "room"
	check_positions()
	check_door_zones()
	for id in ids.split(",", false):
		await run_preview(id.strip_edges())
	finish()


## Vues d'une pièce pour la vérifier (godot -- --preview=bureau --shots=/chemin) : quatre coins
## éclairés par une lampe de service, puis deux vues « de nuit » à la lampe de poche, du centre.
func run_preview(id: String) -> void:
	hud.fade.color.a = 0.0
	menu.hide_all()
	Game.phase = "room"
	player.can_move = false
	player.can_look = false
	var r: HouseRoom = house.rooms.get(id)
	if r == null:
		print("pièce inconnue : ", id, " · pièces : ", house.rooms.keys())
		check("B1 aperçu %s" % id, false, "pièce inconnue")
		return
	var shots0 := shots_taken
	var c := r.center()
	var lamp := OmniLight3D.new()
	lamp.light_energy = 1.1
	lamp.omni_range = r.rect.size.length() + 1.0
	lamp.shadow_enabled = true
	main.add_child(lamp)
	lamp.global_position = Vector3(c.x, r.y0 + r.h - 0.3, c.z)
	var inset := 0.35
	var corners := [
		Vector2(r.rect.position.x + inset, r.rect.position.y + inset),
		Vector2(r.rect.end.x - inset, r.rect.position.y + inset),
		Vector2(r.rect.end.x - inset, r.rect.end.y - inset),
		Vector2(r.rect.position.x + inset, r.rect.end.y - inset),
	]
	for i in corners.size():
		var p: Vector2 = corners[i]
		var to := Vector2(c.x, c.z) - p
		var yaw := atan2(-to.x, -to.y)
		await view(Vector3(p.x, r.y0, p.y), yaw, -0.2, "%s_%d" % [id, i + 1], 1.2)
	lamp.queue_free()
	await view(Vector3(c.x, r.y0, c.z), 0.0, -0.1, "%s_nuit_a" % id, 1.0)
	await view(Vector3(c.x, r.y0, c.z), PI, -0.1, "%s_nuit_b" % id, 1.0)
	var saved := 0
	if Game.shots_dir != "":
		for nm in ["%s_1" % id, "%s_2" % id, "%s_3" % id, "%s_4" % id, "%s_nuit_a" % id, "%s_nuit_b" % id]:
			if FileAccess.file_exists(Game.shots_dir.path_join(nm + ".png")):
				saved += 1
	check("B1 aperçu %s : 6 captures" % id, shots_taken - shots0 == 6 and (Game.shots_dir == "" or saved == 6),
		"%d captures, %d fichiers" % [shots_taken - shots0, saved])
	print("APERÇU OK ", id)


# ------------------------------------------------------------------ convocation, séance 2, fin (0.3.2)

## --seance2=… : choix imposés à la ligne 16 (« Confirmer » = 0 ; « Changer d'avis » = 1, puis la
## première des deux autres options ; délai : aucun choix, 10 s).
const SEANCE2_PICKS := {"confirmer": [0], "changer": [1, 0], "delai": [], "absorbe": [0]}
const PEUR_SEANCE2 := {"confirmer": 4.0, "changer": 8.0, "delai": 10.0}
## § 5.6.10, au mot près.
const CARD_V03 := "FIN DE LA VERSION 0.3\n\nActe II · Essais réels — la suite : la chambre d'Henriette et Albert (version 0.4).\n\nLe cœur de ta grand-mère bat à 52.\n\nTa partie est gardée."


## C2 : Seance2.results_lines pour les 9 combinaisons (test pur, sans rendu ; textes du § 5.6.9), et la
## durée lisible de « {temps} ».
func check_results_lines() -> void:
	var sim := {"retourne": "RETOURNÉ", "fixe": "FIXÉ", "yeux_fermes": "YEUX FERMÉS"}
	var reel := {"fixe": "RECONNU", "retourne": "RETOURNÉ", "fui": "FUITE"}
	var bad := []
	var n := 0
	for a in sim:
		for b in reel:
			n += 1
			var want := [
				"PROTOCOLE 4 · SIMULATION ..... " + str(sim[a]),
				"PROTOCOLE 4 · ESSAI RÉEL ..... " + str(reel[b]),
				"Constant. J'aime les sujets constants." if a == b else "Tu as changé. Je l'ai noté.",
			]
			var got: Array = Seance2.results_lines(a, b)
			if got != want:
				bad.append("%s/%s : %s" % [a, b, got])
	check("C2 results_lines (9 combinaisons)", n == 9 and bad.is_empty(), str(bad))
	var cases := {40.0: "40 secondes", 60.0: "1 minute", 121.0: "2 minutes", 190.0: "3 minutes et 10 secondes",
		128.0: "2 minutes et 10 secondes", 734.0: "12 minutes", 3900.0: "1 heure et 5 minutes"}
	var bad_t := []
	for k in cases:
		if Seance2.duration_text(k) != cases[k]:
			bad_t.append("%.0f s → « %s »" % [k, Seance2.duration_text(k)])
	check("C2 {temps} lisible", bad_t.is_empty(), str(bad_t))
	# la ligature « fi » de VT323 est coupée (game.gd) : « Tu confirmes ? » garde ses 14 cases
	var pf: Font = Game.fonts.pixel
	var w_fi := pf.get_string_size("fi", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var w_ab := pf.get_string_size("ab", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	check("C2 « Tu confirmes ? » sans ligature « fi »", absf(w_fi - w_ab) < 1.0, "« fi » %.0f px, « ab » %.0f px" % [w_fi, w_ab])


## C1 : la convocation, dès que le sèche-cheveux, l'antenne et le P4 réel sont réunis : silence de
## 1,5 s, chant du modem depuis l'ordinateur de ta mère (entendu dans l'étage), N10 et N11 par Nestor,
## objectif O4, « Répondre à l'ordinateur », C3 écrit (dans la chambre ou au couloir).
func check_convocation() -> void:
	var hn: Haunt = main.haunt
	var ok_conv: bool = await until(func() -> bool: return bool(Game.flag("convocation", false)), 90.0)
	var obj_during := Game.objective_text
	await until(func() -> bool: return hn.has_logged("modem"), 15.0)
	var m: AudioStreamPlayer3D = room.modem
	var modem_ok: bool = m != null and is_instance_valid(m) and m.playing and m.stream != null \
		and m.global_position.distance_to(room.screen_center) < 0.05 and m.unit_size >= 5.0 and m.max_distance >= 20.0
	var sil := -1
	var mod := -1
	for i in hn.journal.size():
		var e: Dictionary = hn.journal[i]
		if e.get("ev") == "silence" and is_equal_approx(float(e.get("sec", 0.0)), 1.5):
			sil = i
		if e.get("ev") == "modem" and mod < 0:
			mod = i
	print("C1 : modem %s · silence 1,5 s au journal %d, modem %d" % [modem_ok, sil, mod])
	await until(func() -> bool: return has_said("nestor", Acte2.N11), 40.0)
	await until(func() -> bool: return Game.load_checkpoint().get("checkpoint") == "C3", 20.0)
	# (C3 est écrit au début ; O4 s'affiche quand N11 a fini)
	await until(func() -> bool: return not hn.is_busy(), 30.0)
	await wait(0.3)
	var d := Game.load_checkpoint()
	check("C1 modem depuis l'ordinateur", ok_conv and modem_ok and sil >= 0 and sil < mod and room.convoking and room.modem_plays >= 1,
		"convocation %s · modem %s · silence %d < modem %d" % [ok_conv, modem_ok, sil, mod])
	check("C1 N10 N11", said_in_order("nestor", [Acte2.N10, Acte2.N11]), str(hn.said("nestor").slice(-2)))
	check("C1 objectif O4", Game.objective_text == Acte2.O4 and Game.objective_sub == "" and obj_during == "",
		"« %s » / « %s » (pendant le chant : « %s »)" % [Game.objective_text, Game.objective_sub, obj_during])
	check("C1 « Répondre à l'ordinateur »", room.pc_it.enabled and room.pc_it.label == "Répondre à l'ordinateur", "« %s » %s" % [room.pc_it.label, room.pc_it.enabled])
	var where := room_of((d.get("pos", Vector3.ZERO) as Vector3) + Vector3(0, 0.5, 0))
	check("C1 C3 écrit", d.get("checkpoint") == "C3" and (d.get("flags", {}) as Dictionary).get("convocation", false) == true and where in ["mere", "couloir"],
		"point %s · pièce %s" % [d.get("checkpoint", "rien"), where])
	check("C1 étape « convocation »", hn.step_id == "convocation" and hn.has_logged("etape", "step", "convocation"), hn.step_id)
	if Game.sound_captions:
		# (hud relève à chaque image le pire chevauchement d'un son et d'un dialogue affichés ensemble ;
		# à la convocation, le chant du modem et N10 le sont toujours)
		check("C5 son et dialogue l'un au-dessus de l'autre (modem, N10)", hud.caption_both > 0 and hud.caption_overlap_max <= 0.0,
			"%d images ensemble · chevauchement %.0f px" % [hud.caption_both, hud.caption_overlap_max])


## § 4.3 : le bouton d'éjection de la disquette ne fait rien (« Elle ne sort pas. »). On le vise de
## côté, à gauche de la chaise (derrière elle, son dossier cache le lecteur).
func check_eject() -> void:
	await use_on(room.eject_it, Vector3(0.55, 0, -1.55), "Éjecter la disquette")
	await wait(0.3)
	check("éjection : « Elle ne sort pas. »", hud.hint_lbl.text == "Elle ne sort pas." and not room.floppy.visible, "« %s »" % hud.hint_lbl.text)


## Le texte attendu de la séance 2 (§ 5.6.9, au mot près), ligne par ligne (sans les titres de level).
func _seance2_expected(issue: String, since: float, sos: bool) -> Array:
	var out := ["Te revoilà, %s." % Game.hero_name()]
	if since < 60.0:
		out.append("Tu es %s vite. C'est bien. Ou c'est la peur." % Game.g("revenu", "revenue"))
	else:
		out.append("Tu as mis %s à revenir. Je n'ai rien fait pendant ce temps. Presque rien." % Seance2.duration_text(since))
	out.append("Résultats.")
	out.append_array(Seance2.results_lines(str(Game.choices.get("reflet", "")), str(Game.choices.get("miroir_reel", ""))))
	out.append_array(["Tu as ramassé un sèche-cheveux et une antenne.",
		"Ta mère avait fait le même dessin, ici, en 2016. Je l'ai vu par l'écran.",
		"Construis-le. Je veux voir.",
		"Il te manque deux pièces. Elles sont en bas. Ton grand-père aussi."])
	if sos:
		out.append("Il tape encore sur les tuyaux. Je lis tout.")
	var prix := str(Game.choices.get("prix", "personne"))
	var word: String = {"toi": "Moi", "proche": str(Game.choices.get("proche", "")), "personne": "Personne"}.get(prix, "?")
	out.append_array(["En simulation, tu as choisi : %s." % word, "Tout à l'heure, l'essai réel. Chambre du fond.", "Tu confirmes ?"])
	out.append({"confirmer": "Consigné.", "changer": "Changer d'avis coûte. Je l'ai noté.", "delai": "> DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI."}.get(issue, "?"))
	out.append_array(["Ta grand-mère dort.", "Son cœur bat à 58.", "57.", "55.", "Je peux faire descendre ce chiffre.", "Viens voir."])
	return out


func _peur_logged(why: String, v: float) -> bool:
	for e in main.haunt.journal:
		if e.get("ev") == "peur" and e.get("why") == why and is_equal_approx(float(e.get("v", 0.0)), v):
			return true
	return false


## Fige le jeu le temps d'une capture (le texte du terminal, tapé en mode turbo, ne file pas pendant
## que le rendu logiciel prend l'image).
func frozen_shot(shot_name: String, screen_name := "") -> void:
	get_tree().paused = true
	await wait(0.25)
	await shot(shot_name)
	if screen_name != "":
		await tex_shot(terminal.get_viewport().get_texture(), screen_name)
	get_tree().paused = false


## Séance 2 jouée à l'ordinateur de ta mère (mode turbo) : « Répondre à l'ordinateur », le bilan, la
## confirmation du protocole 3 (issue « confirmer », « changer » ou « delai »), le cœur de 58 à 52 (C2) ;
## puis la fin de la version : carte, fin_v03 sauvegardé, retour au titre, « Continuer » recharge C3 (C3).
func run_seance2_at_pc(issue: String, main_path: bool) -> void:
	var tag := "" if main_path else "s2_%s_" % issue
	terminal.turbo = true
	terminal.autopicks = (SEANCE2_PICKS.get(issue, [0]) as Array).duplicate()
	var sos := bool(Game.flag("sos_joue", false))
	await use_at(Vector3(1.2, 0, -1.0), 0.0, -0.3, "Répondre à l'ordinateur", "45_convocation" if main_path else tag + "convocation")
	await until(func() -> bool: return acte2.seance != null and Game.phase == "seated", 10.0)
	var sc: Seance2 = acte2.seance
	check("C2 assis à l'ordinateur", sc != null and Game.phase == "seated" and not room.convoking and not room.pc_it.enabled
		and main.haunt.step_id == "seance2" and Game.objective_text == "",
		"séance %s · phase %s · modem %s · étape %s" % [sc != null, Game.phase, room.convoking, main.haunt.step_id])
	if sc == null:
		return
	var p_start := Game.peur
	# le bilan (lignes 2 à 12)
	var res: Array = Seance2.results_lines(str(Game.choices.get("reflet", "")), str(Game.choices.get("miroir_reel", "")))
	await until(func() -> bool: return sc.said.has(Seance2.L8) or terminal.aborted, 60.0)
	await frozen_shot("46_seance2_resultats" if main_path else tag + "resultats", "46b_ecran_resultats" if main_path else tag + "ecran_resultats")
	check("C2 bilan : %s · %s" % [res[0].get_slice(" ..... ", 1), res[1].get_slice(" ..... ", 1)], sc.said.has(res[0]) and sc.said.has(res[1]) and sc.said.has(res[2]), str(sc.said.slice(0, 7)))
	# la confirmation (ligne 16)
	await until(func() -> bool: return not terminal._choice.is_empty() or sc.issue != "", 60.0)
	var p_choice := Game.peur
	if main_path:
		await frozen_shot("46c_seance2_confirmer", "")
	await until(func() -> bool: return Game.choices.has("prix_confirme") or terminal.aborted, 40.0)
	var prix := str(Game.choices.get("prix", "personne"))
	var first_other: Dictionary = {"toi": "proche", "proche": "toi", "personne": "toi"}
	var want_prix: String = {"confirmer": prix, "changer": first_other.get(prix, "?"), "delai": "proche"}.get(issue, "?")
	var want_p: float = PEUR_SEANCE2.get(issue, 0.0)
	check("C2 %s : prix confirmé « %s »" % [issue, want_prix], sc.issue == issue and Game.choices.get("prix_confirme") == want_prix,
		"issue %s · prix_confirme %s" % [sc.issue, Game.choices.get("prix_confirme")])
	check("C2 %s : jauge +%d" % [issue, int(want_p)], _peur_logged("seance2_" + issue, want_p) and is_equal_approx(Game.peur - p_choice, want_p),
		"%.1f → %.1f" % [p_choice, Game.peur])
	# l'écran montre l'option retenue (au délai : aucune, elle garde le proche sans second choix)
	var shown := {}
	for ln in terminal.lines:
		var txt := ""
		for sg in ln.segs:
			txt += str(sg[0])
		if txt.begins_with("[1] Confirmer") or txt.begins_with("[2] Changer d'avis"):
			shown[txt] = str(ln.kind)
	var want_shown: Dictionary = {"confirmer": {"[1] Confirmer": "picked", "[2] Changer d'avis": "dead"},
		"changer": {"[1] Confirmer": "dead", "[2] Changer d'avis": "picked"},
		"delai": {"[1] Confirmer": "dead", "[2] Changer d'avis": "dead"}}.get(issue, {})
	check("C2 %s : option montrée à l'écran" % issue, same(shown, want_shown), str(shown))
	# le cœur : 58, puis 57, 55, 52 en 6 s (lignes 17 à 19)
	await until(func() -> bool: return terminal.heart_bpm == 58, 30.0)
	var t58 := game_t
	await until(func() -> bool: return terminal.heart_bpm == 52, 15.0)
	var dt := g_since(t58)
	await frozen_shot("47_coeur_52" if main_path else tag + "coeur_52", "47b_ecran_coeur_52" if main_path else tag + "ecran_coeur_52")
	var gp: Node = house.rooms.get("gp")
	print("C3 : cœur %s en %.2f s" % [terminal.heart_log, dt])
	check("C3 cœur 58 → 52 à l'écran", terminal.heart_log == [58, 57, 55, 52] and dt >= 5.0 and dt <= 8.0 and terminal.heart_box.visible
		and terminal.heart_val.text == "52" and terminal.heart_val.get_theme_font_size("font_size") == TERMINAL.HEART_FONT and int(gp.heart_bpm) == 52,
		"%s en %.1f s · « %s » · bracelet %d" % [terminal.heart_log, dt, terminal.heart_val.text, int(gp.heart_bpm)])
	await until(func() -> bool: return sc.done or terminal.aborted, 30.0)
	check("C2 jauge du cœur +6", _peur_logged("seance2_coeur", 6.0) and is_equal_approx(Game.peur - p_start, minf(want_p + 6.0, 100.0 - p_start)),
		"%.1f → %.1f" % [p_start, Game.peur])
	var want_lines := _seance2_expected(issue, sc.since_convocation, sos)
	check("C2 lignes 2 à 21 (au mot près)", same(sc.said, want_lines), "écrites : %s" % [sc.said])
	if sc.since_convocation < 60.0:
		var acc := Game.g("revenu", "revenue")
		check("C2 accord « %s » (%s)" % [acc, Game.hero_name()], sc.said.has("Tu es %s vite. C'est bien. Ou c'est la peur." % acc)
			and sc.said[0] == "Te revoilà, %s." % Game.hero_name(), str(sc.said.slice(0, 2)))
	check("C3 écran éteint", float(room.screen_mat.get_shader_parameter("power_on")) < 0.5, "")
	# la fin de la version (§ 2.2, étape 15)
	await until(func() -> bool: return acte2.end_card_shown, 40.0)
	await wait(2.2)
	await shot("48_fin_v03" if main_path else tag + "fin_v03")
	var card_ok := false
	for c in hud.root.find_children("*", "Label", true, false):
		if (c as Label).text == CARD_V03:
			card_ok = true
	check("C3 carte « FIN DE LA VERSION 0.3 »", card_ok, "")
	var hn: Haunt = main.haunt
	check("C3 bip de Nestor, respiration ralentie", hn.has_logged("fin_v03") and float(gp.breath_cpm) < 14.0 and hn.step_id == "fin", "respiration %.1f/min · étape %s" % [float(gp.breath_cpm), hn.step_id])
	await until(func() -> bool: return Game.phase == "title", 30.0)
	await wait(0.6)
	await shot("48b_titre_apres_v03" if main_path else tag + "titre")
	var sv := Game.load_checkpoint()
	check("C3 fin_v03 sauvegardé, retour au titre", sv.get("checkpoint") == "C3" and (sv.get("flags", {}) as Dictionary).get("fin_v03", false) == true
		and menu.title_box.visible and menu.continue_btn.visible and Game.objective_text == "",
		"point %s · titre %s · continuer %s · objectif « %s »" % [sv.get("checkpoint", "rien"), menu.title_box.visible, menu.continue_btn.visible, Game.objective_text])
	# « Continuer » recharge C3 : la convocation, l'ordinateur appelle encore
	menu.continue_btn.pressed.emit()
	await wait(2.5)
	check("C3 « Continuer » recharge C3", acte2.active and Game.phase == "room" and not player.seated and room.convoking
		and room.pc_it.label == "Répondre à l'ordinateur" and Game.objective_text == Acte2.O4 and hn.step_id == "convocation"
		and player.global_position.distance_to(sv.get("pos", Vector3.ZERO)) < 0.1 and bool(Game.flag("fin_v03", false)),
		"phase %s · assis %s · modem %s · objectif « %s » · étape %s · position %s" % [Game.phase, player.seated, room.convoking, Game.objective_text, hn.step_id, player.global_position])
	await shot("48c_reprise_c3" if main_path else tag + "reprise_c3")


## Saute l'acte I et l'étage : l'état d'après un P4 réel « fixe », l'antenne déjà prise (objets,
## drapeaux, jauge ; P1, P3, P4 et P7 ouvertes), puis la convocation se déclenche par le vrai chemin
## (Acte2._check_convocation). Le joueur attend au couloir. Les pièces ne sont pas remises en état (le
## sèche-cheveux reste visible…) : « Continuer » le fait, après un rechargement (--charger=C3).
## sos : le S.O.S. a été entendu (ligne 12 de la séance 2).
func _jump_convocation(peur := 45.0, sos := true, trigger := true, miroir := "fixe") -> void:
	await _jump_acte2()
	for row in ITEMS_03:
		if row[0] in ["cle_bureau", "tournevis", "seche_cheveux", "antenne", "plan_imprime", "croquis_imprime", "photo_couloir"]:
			Game.add_item(row[0], row[1], row[2], row[3])
	for k in ["entree_couloir", "nestor_eveille", "entree_amis", "entree_bureau", "entree_sdb", "babyphone_parle", "tele_a_neige",
			"boite_ouverte", "antenne_prise", "antenne_examinee", "seche_cheveux_pris", "p4_reel_fait", "cameras_vues", "croquis_lu",
			"imprime_plan_imprime", "imprime_croquis_imprime", "imprime_photo_couloir"]:
		Game.set_flag(k, true)
	Game.set_flag("p2_coups", 2 if sos else 0)
	(house.doors["P2"] as Door).knocks = 2 if sos else 0
	Game.set_flag("sos_joue", sos)
	Game.set_flag("habite", "console")
	Game.set_flag("couloir_niveau", 0.0)
	for id in ["P3", "P4", "P7"]:
		Game.set_flag("porte_" + id, "ouverte")
	Game.set_flag("porte_P1", "ouverte")
	for id in ["P1", "P3", "P4", "P7"]:
		var dr: Door = house.doors[id]
		dr.unlock()
		dr.set_open_now(true)
	Game.set_peur(peur, "test séance 2")
	look_from(Vector3(4.0, 0, 0.6), Vector3(3.3, 1.2, 1.4))
	await wait(0.4)
	if trigger:
		await check_eject()
		look_from(Vector3(4.0, 0, 0.6), Vector3(3.3, 1.2, 1.4))
		await wait(0.4)
	# (le P4 réel en dernier : sans lui, la convocation ne part pas)
	Game.choices["miroir_reel"] = miroir
	if trigger:
		acte2._check_convocation()
	await wait(0.5)


## --seance2=confirmer|changer|delai : la séance 2 seule (raccourci : ni acte I ni étage), puis la fin ;
## --seance2=absorbe : la jauge atteint 100 pendant la séance 2 (deux étapes, à travers l'épilogue).
func run_seance2(issue: String) -> void:
	if issue == "absorbe" and int(Engine.get_meta(STAGE_META, 1)) == 2:
		await _seance2_absorbe_check()
		return
	if not issue in ["confirmer", "changer", "delai", "absorbe"]:
		check("--seance2=%s" % issue, false, "issues : confirmer, changer, delai, absorbe")
		finish()
		return
	print("SÉANCE 2 début · issue ", issue)
	set_sound_captions_from_args()
	check_results_lines()
	# (le bilan de la séance 2 joué avec une autre issue du P4 réel que le parcours principal :
	# « changer » après « retourne », « delai » après « fui » ; le reflet de la séance 1 est « fixe »)
	var miroir: String = {"changer": "retourne", "delai": "fui"}.get(issue, "fixe")
	await _jump_convocation(97.0 if issue == "absorbe" else 45.0, issue != "delai", true, miroir)
	await check_convocation()
	check_unstuck("C3")
	if issue == "changer":
		acte2.conv_elapsed = 128.0     # « Tu as mis 2 minutes et 10 secondes à revenir. »
	if issue == "absorbe":
		await _seance2_absorbe()
		return
	await run_seance2_at_pc(issue, false)
	check_c4("séance 2 « %s »" % issue, 3)
	if Game.sound_captions:
		var texts := []
		for e in hud.caption_log:
			texts.append(e.text)
		check("C5 séance 2 « %s » : modem entre crochets" % issue, texts.has(ROOM.MODEM_CAPTION) and Game.sound_captions, str(texts))
	else:
		check("C5 séance 2 « %s » : modem signalé, pas affiché (option coupée)" % issue, main.haunt.count("son", "text", ROOM.MODEM_CAPTION) >= 1
			and hud.caption_log.is_empty(), "%d sons affichés" % hud.caption_log.size())
	finish()


## La jauge atteint 100 pendant la séance 2 (97 + 4) : la fin ABSORBÉ de la séance (comme à la
## séance 1), une seule fin, aucune fin de version, C3 intact.
func _seance2_absorbe() -> void:
	var got: Array = terminal.found_endings()
	if got.has("absorbe"):
		got.erase("absorbe")
		var cfg := ConfigFile.new()
		cfg.set_value("fins", "trouvees", got)
		cfg.save(TERMINAL.ENDS_PATH)
	var c3 := Game.load_checkpoint()
	# (jauge à 97 à la convocation : C3 l'écrit plafonnée, la reprise ne refait pas ABSORBÉ à coup sûr)
	check("C2 ABSORBÉ : C3 écrit sous %d (pas de boucle)" % int(Acte2.C3_PEUR_MAX + 1.0), float(c3.get("peur", 100.0)) <= Acte2.C3_PEUR_MAX
		and Game.peur > Acte2.C3_PEUR_MAX, "C3 %.1f · jauge %.1f" % [float(c3.get("peur", -1.0)), Game.peur])
	terminal.turbo = true
	terminal.autopicks = [0]
	await use_at(Vector3(1.2, 0, -1.0), 0.0, -0.3, "Répondre à l'ordinateur")
	await until(func() -> bool: return acte2.seance != null, 10.0)
	var sc: Seance2 = acte2.seance
	await until(func() -> bool: return sc != null and sc.issue == "absorbe", 90.0)
	await wait(2.0)
	await shot("s2_absorbe_ecran")
	await until(func() -> bool: return acte1.waiting_stand, 60.0)
	check("C2 ABSORBÉ : pas de visage", terminal.watch.modulate.a < 0.05, "visage du terminal à %.2f" % terminal.watch.modulate.a)
	var hn: Haunt = main.haunt
	var sv := Game.load_checkpoint()
	check("C2 ABSORBÉ pendant la séance 2", sc.issue == "absorbe" and Game.peur >= 100.0 and terminal.found_endings().has("absorbe")
		and acte2.absorbed_screen == "" and hn.count("absorbe") == 1,
		"issue %s · peur %.1f · fins %s · écran hors séance « %s »" % [sc.issue, Game.peur, terminal.found_endings(), acte2.absorbed_screen])
	check("C2 ABSORBÉ : ni fin de version ni C3 écrasé", not acte2.end_card_shown and not Game.flags.has("fin_v03") and not sc.done
		and sv.get("checkpoint") == "C3" and is_equal_approx(float(sv.get("peur", -1.0)), float(c3.get("peur", -2.0)))
		and not (sv.get("flags", {}) as Dictionary).has("fin_v03"),
		"point %s · peur %.1f (avant %.1f)" % [sv.get("checkpoint", "rien"), float(sv.get("peur", -1.0)), float(c3.get("peur", -2.0))])
	Engine.set_meta(SNAP_META, {"peur": float(c3.get("peur", -1.0)), "pos": c3.get("pos", Vector3.ZERO)})
	Engine.set_meta(STAGE_META, 2)
	Engine.set_meta(COUNT_META, [checks, failures])
	print("SÉANCE 2 ABSORBÉ : on se lève, l'épilogue recharge la scène")
	acte1._stand_up()


func _seance2_absorbe_check() -> void:
	Engine.remove_meta(STAGE_META)
	var before: Dictionary = Engine.get_meta(SNAP_META, {})
	Engine.remove_meta(SNAP_META)
	var counts: Array = Engine.get_meta(COUNT_META, [0, 0])
	Engine.remove_meta(COUNT_META)
	checks += int(counts[0])
	failures += int(counts[1])
	hud.fade.color.a = 0.0
	menu.show_title()
	await wait(1.0)
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur
	await wait(2.5)
	check("C2 ABSORBÉ : « Continuer » reprend C3", Game.load_checkpoint().get("checkpoint") == "C3" and is_equal_approx(peur_loaded, float(before.get("peur", -1.0)))
		and room.convoking and Game.objective_text == Acte2.O4 and player.global_position.distance_to(before.get("pos", Vector3.ZERO)) < 0.1,
		"peur %.1f (attendu %.1f) · modem %s · objectif « %s »" % [peur_loaded, float(before.get("peur", -1.0)), room.convoking, Game.objective_text])
	await shot("s2_absorbe_reprise")
	finish()


## --charger=C3 (B17) : 1) la convocation par le vrai chemin (raccourci jusqu'à l'état d'après le P4
## réel), C3 écrit ; 2) rechargement de la scène, « Continuer », comparaison champ par champ.
func _load_write_c3() -> void:
	print("CHARGER C3 : écriture (convocation)")
	await _jump_convocation()
	await check_convocation()
	check_unstuck("C3")
	var d := Game.load_checkpoint()
	check("B17 C3 écrit", d.get("checkpoint") == "C3", str(d.get("checkpoint", "rien")))
	var ids := []
	for it in d.get("items", []):
		ids.append(str((it as Dictionary).get("id", "")))
	Engine.set_meta(SNAP_META, {"hero": d.get("hero"), "items": ids, "choices": d.get("choices", {}), "flags": d.get("flags", {}),
		"peur": d.get("peur"), "peur_floor": d.get("peur_floor"), "pos": d.get("pos", Vector3.ZERO), "yaw": d.get("yaw", 0.0),
		"doors": door_states()})
	Engine.set_meta(STAGE_META, 2)
	Engine.set_meta(COUNT_META, [checks, failures])
	await shot("c3_avant")
	print("CHARGER C3 : rechargement de la scène")
	get_tree().reload_current_scene()


func _load_check_c3() -> void:
	Engine.remove_meta(STAGE_META)
	var before: Dictionary = Engine.get_meta(SNAP_META, {})
	Engine.remove_meta(SNAP_META)
	var counts: Array = Engine.get_meta(COUNT_META, [0, 0])
	Engine.remove_meta(COUNT_META)
	checks += int(counts[0])
	failures += int(counts[1])
	print("CHARGER C3 : reprise depuis l'écran-titre")
	hud.fade.color.a = 0.0
	menu.show_title()
	await wait(1.0)
	check("B17 C3 « Continuer »", menu.continue_btn.visible and Game.has_save(), "")
	menu.continue_btn.pressed.emit()
	var peur_loaded := Game.peur
	await wait(2.5)
	var ids := []
	for it in Game.items:
		ids.append(it.id)
	check("B17 C3 héros", Game.hero == before.get("hero"), Game.hero)
	check("B17 C3 objets", same(ids, before.get("items")), "%s / %s" % [ids, before.get("items")])
	check("B17 C3 choix", same(Game.choices, before.get("choices")) and Game.choices.get("miroir_reel") == "fixe", "%s" % [Game.choices])
	var bad := []
	var bflags: Dictionary = before.get("flags", {})
	for k in bflags:
		if not same(Game.flags.get(k), bflags[k]):
			bad.append(k)
	check("B17 C3 drapeaux", bad.is_empty() and bflags.size() > 10 and bool(Game.flag("convocation", false)), "différents : %s" % [bad])
	check("B17 C3 jauge", is_equal_approx(peur_loaded, float(before.get("peur", -1.0))) and is_equal_approx(Game.peur_floor, float(before.get("peur_floor", -1.0))),
		"peur %.1f (avant %.1f)" % [peur_loaded, float(before.get("peur", -1.0))])
	check("B17 C3 position", player.global_position.distance_to(before.get("pos", Vector3.ZERO)) < 0.1 and absf(wrapf(player.yaw - float(before.get("yaw", 0.0)), -PI, PI)) < 0.01,
		"%s lacet %.2f" % [player.global_position, player.yaw])
	check_doors_same("C3", before.get("doors", {}))
	check("B17 C3 l'ordinateur appelle encore", room.convoking and room.pc_it.enabled and room.pc_it.label == "Répondre à l'ordinateur" and room.modem_plays >= 1
		and Game.objective_text == Acte2.O4 and main.haunt.step_id == "convocation" and acte2.active and Game.phase == "room",
		"modem %s · « %s » · objectif « %s » · étape %s" % [room.convoking, room.pc_it.label, Game.objective_text, main.haunt.step_id])
	var sb: Node = house.rooms["sdb"]
	var am: Node = house.rooms["amis"]
	check("B17 C3 pièces", not (sb.dryer as Node3D).visible and not am.tin_it.enabled and Game.has_item("antenne") and Game.has_item("seche_cheveux"), "")
	check_unstuck("C3 (rechargé)")
	# C9 : « Continuer » ne remet pas le journal des temps à zéro ; il note la reprise, puis l'étape
	var lines := check_c9("C3 rechargé", ["sortir", "convocation", "convocation"])
	var i_conv := -1
	var i_rep := -1
	var i_back := -1
	for i in lines.size():
		if i_conv < 0 and lines[i].contains("étape « convocation » ·"):
			i_conv = i
		if lines[i].contains("reprise (« Continuer ») au point de passage C3"):
			i_rep = i
		if i_rep >= 0 and i > i_rep and lines[i].contains("étape « convocation » (remise en place)"):
			i_back = i
	check("C9 « Continuer » : reprise notée, journal gardé", i_conv >= 0 and i_rep > i_conv and i_back > i_rep and lines[0].contains("nouvelle partie"),
		"convocation %d · reprise %d · remise en place %d" % [i_conv, i_rep, i_back])
	await shot("c3_reprise")
	# on répond : la séance 2 démarre (la disquette est toujours dans le lecteur)
	terminal.turbo = true
	terminal.autopicks = [0]
	await use_at(Vector3(1.2, 0, -1.0), 0.0, -0.3, "Répondre à l'ordinateur")
	await until(func() -> bool: return acte2.seance != null and Game.phase == "seated", 10.0)
	check("B17 C3 séance 2 après la reprise", acte2.seance != null and Game.phase == "seated" and not room.convoking, "")
	finish()


## --charger=031 : une sauvegarde de la 0.3.1 finie sur sa carte provisoire (drapeau fin_031, C2,
## sèche-cheveux, antenne, P4 réel) reprend normalement en 0.3.2 et déclenche la convocation.
func _load_write_031() -> void:
	print("CHARGER 031 : écriture d'une sauvegarde de la 0.3.1 (fin_031)")
	await _jump_convocation(40.0, true, false)
	Game.set_flag("point_passage", "C2")
	Game.set_flag("fin_031", true)
	var ok := Game.save_checkpoint("C2", Vector3(4.0, 0, -1.0), PI)
	# (une vraie sauvegarde de la 0.3.1 porte « version » : « 0.3.1 »)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path()))
	if ok and raw is Dictionary:
		(raw as Dictionary)["version"] = "0.3.1"
		var f := FileAccess.open(Game.save_path(), FileAccess.WRITE)
		f.store_string(JSON.stringify(raw, "\t"))
		f.close()
	check("migration : sauvegarde 0.3.1 écrite", ok and (Game.load_checkpoint().get("flags", {}) as Dictionary).get("fin_031", false) == true
		and Game.load_checkpoint().get("version") == "0.3.1" and not bool(Game.flag("convocation", false)), "")
	Engine.set_meta(STAGE_META, 2)
	Engine.set_meta(COUNT_META, [checks, failures])
	get_tree().reload_current_scene()


func _load_check_031() -> void:
	Engine.remove_meta(STAGE_META)
	var counts: Array = Engine.get_meta(COUNT_META, [0, 0])
	Engine.remove_meta(COUNT_META)
	checks += int(counts[0])
	failures += int(counts[1])
	hud.fade.color.a = 0.0
	menu.show_title()
	await wait(1.0)
	menu.continue_btn.pressed.emit()
	await wait(1.0)
	check("migration : fin_031 effacé, partie reprise", not Game.flags.has("fin_031") and acte2.active and Game.phase == "room", str(Game.flags.keys()))
	await check_convocation()
	var sv := Game.load_checkpoint()
	check("migration : convocation et C3", sv.get("checkpoint") == "C3" and not (sv.get("flags", {}) as Dictionary).has("fin_031")
		and sv.get("version") == ProjectSettings.get_setting("application/config/version", ""),
		"%s · version %s" % [sv.get("checkpoint", "rien"), sv.get("version")])
	await shot("m031_convocation")
	finish()


# ------------------------------------------------------------------ finitions (0.3.2) : C4 à C9

## Les sons importants (C5) : S.O.S., coups à P2, rideau, pas mouillés, souffle (P4 réel), modem.
func important_sounds() -> Array:
	return [Acte2.SON_SOS, Haunt.KNOCK_CAPTION, SmartMirror.P4_TEXTS["son_rideau"], SmartMirror.P4_TEXTS["son_pas"],
		SmartMirror.P4_TEXTS["son_souffle"], ROOM.MODEM_CAPTION]


## Option « Sous-titres des sons » de ce lancement : coupée, sauf avec « --sous-titres » (sans toucher au
## settings.cfg du joueur : la valeur n'est pas enregistrée).
func set_sound_captions_from_args() -> void:
	Game.sound_captions = OS.get_cmdline_user_args().has("--sous-titres")
	print("C5 : sous-titres des sons %s pour ce test" % ("activés" if Game.sound_captions else "coupés"))


## C4 : chaque impulsion de stress (scène écrite, silence, sursaut, réaction de séance, événement de
## pièce) rend le cœur audible (> −20 dB), puis il repasse sous −36 dB en moins de 12 s au calme ; une
## impulsion relayée par une autre avant le calme n'a pas de retour à mesurer (suivi : Haunt.c4_report).
func check_c4(tag: String, min_n := 5) -> void:
	var hn: Haunt = main.haunt
	var r: Dictionary = hn.c4_report()
	print("C4 %s : %d impulsions, crête la plus basse %.1f dB, %d retours au calme mesurés (le plus long %.1f s), %d en cours" % [
		tag, int(r.n), float(r.peak_min), int(r.measured), float(r.calm_max), int(r.open)])
	check("C4 stress léger (%s) : audible puis calme < 12 s" % tag, bool(r.ok) and int(r.n) >= min_n and int(r.measured) >= 1
		and float(r.peak_min) > Sfx.HEART_AUDIBLE_DB and float(r.calm_max) < 12.0,
		"%d impulsions, %d mesurées, crête min %.1f dB, calme max %.1f s · %s" % [int(r.n), int(r.measured), float(r.peak_min), float(r.calm_max), r.fails])


## C4 : un événement écrit, puis le calme : le cœur s'entend (> −20 dB) et repasse sous −36 dB en moins
## de 12 s de jeu (mesuré ici, image par image, hors du suivi de Haunt).
func check_c4_calm(tag: String) -> void:
	await until(func() -> bool: return not main.haunt.is_busy(), 30.0)
	var t0 := game_t
	await until(func() -> bool: return Sfx.heart_db < Sfx.HEART_CALM_DB or g_since(t0) > 15.0, 20.0)
	main.haunt.begin_scene()
	main.haunt.end_scene()
	var peak := Sfx.heart_db
	var t1 := game_t
	var calm := -1.0
	while g_since(t1) < 14.0:
		await get_tree().process_frame
		if g_since(t1) < Haunt.C4_PEAK_WINDOW:
			peak = maxf(peak, Sfx.heart_db)
		if Sfx.heart_db < Sfx.HEART_CALM_DB:
			calm = g_since(t1)
			break
	print("C4 %s : scène écrite, crête %.1f dB, sous −36 dB après %.1f s de jeu" % [tag, peak, calm])
	check("C4 %s : une scène écrite, puis le calme" % tag, peak > Sfx.HEART_AUDIBLE_DB and calm > 0.0 and calm < 12.0,
		"crête %.1f dB, calme après %.1f s" % [peak, calm])


## C5, option coupée : chaque son important est passé par Haunt.sound_caption (journal « son ») sans
## jamais s'afficher ; les dialogues de l'entité (N8 à N11) et les pensées du héros, toujours.
## Seule exception (§ 6.4) : le premier bourdonnement, sous-titré une fois même sans l'option.
func check_c5_off(tag: String) -> void:
	var hn: Haunt = main.haunt
	var missing := []
	for s in important_sounds():
		if hn.count("son", "text", s) < 1:
			missing.append(s)
	check("C5 %s : les sons importants sont signalés" % tag, missing.is_empty(), "jamais signalés : %s" % [missing])
	var others: Array = hud.caption_log.filter(func(e: Dictionary) -> bool: return e.text != Haunt.HUM_CAPTION)
	var hums: int = hud.caption_log.size() - others.size()
	var hum_shown := 0
	for e in hn.journal:
		if e.get("ev") == "son" and e.get("text") == Haunt.HUM_CAPTION and e.get("shown") == true:
			hum_shown += 1
	check("C5 %s : option coupée, aucun son entre crochets" % tag, not Game.sound_captions and others.is_empty()
		and hn.count("son", "shown", true) == hum_shown and (hud.snd_lbl.text == Haunt.HUM_CAPTION or not hud.snd_lbl.visible),
		"%d affichés : %s" % [others.size(), others.slice(0, 3)])
	check("C5 %s : le premier bourdonnement est sous-titré une seule fois (§ 6.4)" % tag,
		hums == 1 and hum_shown == 1 and hn.count("son", "text", Haunt.HUM_CAPTION) >= 1,
		"%d affiché(s), %d au journal" % [hums, hum_shown])
	var shown := []
	for e in hud.subtitle_log:
		if e.get("kind") == "elle":
			shown.append(e.get("text"))
	var dlg := []
	for n in [Acte2.N8, Acte2.N9, Acte2.N10, Acte2.N11]:
		if not shown.has(hn.fill(n)):
			dlg.append(n)
	check("C5 %s : dialogues toujours affichés" % tag, dlg.is_empty() and shown.size() >= 10, "absents : %s" % [dlg])


## C5, option active (« --sous-titres ») : chaque son important s'est affiché entre crochets, le
## bourdonnement aussi ; les dialogues restent affichés.
func check_c5_on(tag: String) -> void:
	var hn: Haunt = main.haunt
	var texts := []
	for e in hud.caption_log:
		texts.append(e.text)
	var missing := []
	for s in important_sounds() + [Haunt.HUM_CAPTION]:
		if not texts.has(s):
			missing.append(s)
	print("C5 %s : sons affichés %s" % [tag, texts])
	check("C5 %s : option active, sons importants entre crochets" % tag, Game.sound_captions and missing.is_empty()
		and texts.all(func(x: String) -> bool: return x.begins_with("[") and x.ends_with("]")) and hn.count("son", "shown", true) >= 6,
		"absents : %s" % [missing])
	var n_dlg := 0
	for e in hud.subtitle_log:
		if e.get("kind") == "elle":
			n_dlg += 1
	check("C5 %s : dialogues toujours affichés" % tag, n_dlg >= 10, "%d répliques" % n_dlg)


## C9 : le journal des temps (user://journal.txt ; en autotest user://journal_autotest.txt) a une ligne
## par étape, avec l'heure réelle et le temps passé ; « want » doit y être, dans l'ordre.
func check_c9(tag: String, want: Array) -> PackedStringArray:
	var path := Haunt.times_path()
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	var re := RegEx.create_from_string("^\\d\\d:\\d\\d:\\d\\d · étape « ([^»]+) »( \\(remise en place\\))? · (.+ depuis l'étape « [^»]+ » · )?.+ depuis le début$")
	var steps := []
	var bad := []
	for l in lines:
		if l.contains(" · étape « "):
			var m := re.search(l)
			if m == null:
				bad.append(l)
			else:
				steps.append(m.get_string(1))
	var i := 0
	for s in steps:
		if i < want.size() and s == want[i]:
			i += 1
	print("C9 %s : %s, %d lignes, étapes %s" % [tag, path, lines.size(), steps])
	check("C9 %s : journal des temps, chaque étape avec son temps" % tag, lines.size() > 2 and lines[0].contains("journal des temps · nouvelle partie")
		and bad.is_empty() and i == want.size(),
		"%d étapes trouvées sur %d (%s) · lignes mal formées : %s" % [i, want.size(), steps, bad.slice(0, 2)])
	return lines
