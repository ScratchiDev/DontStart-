class_name Banc
extends Node
## Banc d'essai des préréglages (lot V3-ETALONNAGE), pour l'auteur et les testeurs : « -- --banc ».
##
##   Windows : "Don't Play.exe" -- --banc        (ou un raccourci avec ces arguments)
##   Linux   : ./DontPlay.x86_64 -- --banc
##   « -- --banc=rapide » : 1 s de mesure par vue au lieu de MEASURE_S ;
##   « -- --banc=ultra » (ou basse, moyenne, elevee) : ce seul niveau ;
##   « -- --banc --resolution 2560x1440 » : la taille de la fenêtre (sinon celle des réglages du jeu).
##
## À la place du menu, après la construction de la maison : pour chaque niveau (Basse, Moyenne, Élevée,
## Ultra), le joueur est posé dans les 6 pièces, de « jour » (une lampe de service au plafond, comme les
## aperçus) et de nuit (au centre, à la lampe de poche), soit 12 vues. Pour chaque vue : WARMUP_S de
## chauffe (compilations, FSR 2, exposition), puis MEASURE_S de mesure, synchronisation verticale coupée et
## images par seconde illimitées. Mesures :
##  - durée de chaque image (horloge) : images par seconde moyennes et « 1 % bas » (1 / 99e centile des
##    durées) ;
##  - temps de rendu de la carte et du processeur (RenderingServer.viewport_get_measured_render_time_gpu /
##    _cpu, en ms, moyennes) ;
##  - appels de dessin (Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME, moyenne), mémoire vidéo
##    (Performance.RENDER_VIDEO_MEM_USED, en Mo, maximum) et mémoire du jeu (Performance.MEMORY_STATIC) ;
##  - une fois : construction de la maison et cuisson de la VoxelGI (Main.build_ms, Main.gi_ms), démarrage
##    jusqu'au banc.
## Résultats : user://banc.csv (une ligne par niveau et par vue, séparateur « ; ») et user://banc.txt (rapport
## lisible : machine, résumé par niveau, verdict 60 i/s), chemins complets affichés à la fin dans la console.
## Sous Windows : %APPDATA%\Godot\app_userdata\Don't Play\ (ou le dossier du jeu exporté). Les réglages du
## joueur ne sont pas modifiés (le niveau est rétabli, rien n'est enregistré). Le jeu quitte à la fin.
## Sur un rendu logiciel (lavapipe), le niveau est plafonné à Élevée (Qualite.effective) et chaque vue ne
## mesure que quelques images : le banc s'y termine, mais ses chiffres n'ont pas de sens.

const ROOMS := ["mere", "couloir", "sdb", "amis", "bureau", "gp"]
const WARMUP_S := 1.5
const MEASURE_S := 4.0
const SOFT_FRAMES := 3                 # (rendu logiciel : images mesurées par vue)
const TARGET_FPS := 60.0
const CSV_PATH := "user://banc.csv"
const LAUNCH_META := "banc_demande"
const TXT_PATH := "user://banc.txt"

var main: Main
var rows: Array = []
var _t_start_ms := 0
var _times: PackedFloat32Array = []
var _gpu := 0.0
var _cpu := 0.0
var _draws := 0.0
var _vram := 0.0
var _ram := 0.0
var _n := 0
var _measuring := false
var _last_us := 0


static func wanted() -> bool:
	if Engine.has_meta(LAUNCH_META):
		return true
	for a in OS.get_cmdline_user_args():
		if a == "--banc" or a.begins_with("--banc="):
			return true
	return false


## Lance le banc depuis le jeu (bouton d'un menu) : la scène se recharge et Main démarre le banc au lieu du
## menu ; le jeu quitte à la fin (rapport dans user://banc.txt).
static func launch(tree: SceneTree) -> void:
	Engine.set_meta(LAUNCH_META, true)
	tree.paused = false
	tree.reload_current_scene()


static func _option() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--banc="):
			return a.substr(7).to_lower()
	return ""


func setup(m: Main) -> void:
	main = m


func run() -> void:
	_t_start_ms = Time.get_ticks_msec()
	if Engine.has_meta(LAUNCH_META):
		Engine.remove_meta(LAUNCH_META)
	var opt := _option()
	var measure_s := 1.0 if opt == "rapide" else MEASURE_S
	var levels := [Qualite.BASSE, Qualite.MOYENNE, Qualite.ELEVEE, Qualite.ULTRA]
	if Qualite.from_name(opt) >= 0:
		levels = [Qualite.from_name(opt)]
	main.menu.hide_all()
	main.hud.fade.color.a = 0.0
	var player := main.player
	player.can_move = false
	player.can_look = false
	var keep_q: int = Game.quality
	var keep_auto: bool = Game.quality_auto
	var keep_vsync := DisplayServer.window_get_vsync_mode()
	var keep_fps := Engine.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("BANC début · %s · %s · fenêtre %s" % [RenderingServer.get_video_adapter_name(), Qualite.describe(), DisplayServer.window_get_size()])
	for q in levels:
		Game.quality = q
		Game.quality_auto = false
		Game.apply_settings()
		await _settle()
		for id in ROOMS:
			var r: HouseRoom = main.house.rooms.get(id)
			if r == null:
				continue
			for kind in ["jour", "nuit"]:
				var lamp: OmniLight3D = null
				var c := r.center()
				if kind == "jour":
					lamp = OmniLight3D.new()
					lamp.light_energy = 1.1
					lamp.omni_range = r.rect.size.length() + 1.0
					lamp.shadow_enabled = false
					main.add_child(lamp)
					lamp.global_position = Vector3(c.x, r.y0 + r.h - 1.1, c.z)
					var p := Vector2(r.rect.position.x + 0.6, r.rect.position.y + 0.6)
					var to := Vector2(c.x, c.z) - p
					player.global_position = Vector3(p.x, r.y0, p.y)
					player.set_look(atan2(-to.x, -to.y), -0.2)
				else:
					player.global_position = Vector3(c.x, r.y0, c.z)
					player.set_look(0.0, -0.1)
				player.head.position.y = player.EYE
				var row := await _measure(q, "%s_%s" % [id, kind], measure_s, vp_rid)
				rows.append(row)
				print("BANC %-8s %-14s %6.1f i/s · 1 %% bas %6.1f · carte %5.2f ms · proc %5.2f ms · %5d appels · %5.0f Mo vidéo" % [
					Qualite.name_of(q), row.vue, row.fps, row.fps_1pc, row.gpu_ms, row.cpu_ms, roundi(row.draws), row.vram_mo])
				if lamp:
					lamp.queue_free()
	RenderingServer.viewport_set_measure_render_time(vp_rid, false)
	Game.quality = keep_q
	Game.quality_auto = keep_auto
	DisplayServer.window_set_vsync_mode(keep_vsync)
	Engine.max_fps = keep_fps
	_write()
	Game.quit_game(0)


## Après un changement de niveau : les sondes de reflets se capturent, FSR 2 et les ombres se refont.
func _settle() -> void:
	await get_tree().process_frame
	if main.reflections_busy():
		await main.reflections_settled
	await get_tree().create_timer(0.5).timeout


func _process(_delta: float) -> void:
	if not _measuring:
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_times.append((now - _last_us) / 1000.0)
		var rid := get_viewport().get_viewport_rid()
		_gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_vram = maxf(_vram, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		_ram = maxf(_ram, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		_n += 1
	_last_us = now


func _measure(q: int, vue: String, measure_s: float, _rid: RID) -> Dictionary:
	var soft := Qualite.soft()
	# chauffe
	if soft:
		for i in 2:
			await RenderingServer.frame_post_draw
	else:
		await get_tree().create_timer(WARMUP_S).timeout
	_times = PackedFloat32Array()
	_gpu = 0.0
	_cpu = 0.0
	_draws = 0.0
	_vram = 0.0
	_ram = 0.0
	_n = 0
	_last_us = 0
	_measuring = true
	var t0 := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		if soft and _n >= SOFT_FRAMES:
			break
		if not soft and Time.get_ticks_msec() - t0 >= measure_s * 1000.0 and _n >= 30:
			break
	_measuring = false
	var n := maxi(_n, 1)
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in _times:
		total += t
	var mean_ms := total / maxf(_times.size(), 1.0)
	var p99: float = sorted[mini(int(ceil(sorted.size() * 0.99)) - 1, sorted.size() - 1)] if sorted.size() > 0 else mean_ms
	return {
		"niveau": Qualite.name_of(q), "effectif": Qualite.name_of(Qualite.effective()), "vue": vue,
		"images": _times.size(), "fps": 1000.0 / maxf(mean_ms, 0.001), "fps_1pc": 1000.0 / maxf(p99, 0.001),
		"ms": mean_ms, "gpu_ms": _gpu / n, "cpu_ms": _cpu / n, "draws": _draws / n, "vram_mo": _vram, "ram_mo": _ram,
	}


func _write() -> void:
	var size := DisplayServer.window_get_size()
	var csv := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if csv:
		csv.store_line("niveau;effectif;vue;images;ips_moy;ips_1pc_bas;ms_moy;carte_ms;proc_ms;appels_dessin;video_mo;memoire_mo;largeur;hauteur")
		for r in rows:
			csv.store_line("%s;%s;%s;%d;%.1f;%.1f;%.2f;%.2f;%.2f;%d;%.0f;%.0f;%d;%d" % [r.niveau, r.effectif, r.vue, r.images, r.fps, r.fps_1pc,
				r.ms, r.gpu_ms, r.cpu_ms, roundi(r.draws), r.vram_mo, r.ram_mo, size.x, size.y])
		csv.close()
	var lines: PackedStringArray = []
	lines.append("DON'T PLAY — BANC D'ESSAI DES PRÉRÉGLAGES (%s)" % ProjectSettings.get_setting("application/config/version", ""))
	lines.append("Date : %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Carte : %s (%s) · API %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version()])
	lines.append("Processeur : %s (%d fils) · système : %s %s" % [OS.get_processor_name(), OS.get_processor_count(), OS.get_name(), OS.get_version()])
	lines.append("Fenêtre : %d × %d%s · rendu %s" % [size.x, size.y, " (plein écran)" if DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN else "",
		"logiciel (chiffres sans valeur)" if Qualite.soft() else "carte graphique"])
	lines.append("Construction de la maison : %d ms · cuisson de la VoxelGI : %d ms · démarrage jusqu'au banc : %d ms" % [main.build_ms, main.gi_ms, _t_start_ms])
	lines.append("")
	lines.append("%-8s %-8s %9s %11s %9s %9s %8s %9s" % ["Niveau", "Effectif", "i/s moy", "1 % bas", "carte ms", "proc ms", "appels", "vidéo Mo"])
	var by_level := {}
	for r in rows:
		if not by_level.has(r.niveau):
			by_level[r.niveau] = []
		(by_level[r.niveau] as Array).append(r)
	for lv in by_level:
		var a: Array = by_level[lv]
		var fps := 0.0
		var low := INF
		var gpu := 0.0
		var cpu := 0.0
		var dr := 0.0
		var vram := 0.0
		for r in a:
			fps += 1.0 / maxf(float(r.fps), 0.001)
			low = minf(low, float(r.fps_1pc))
			gpu += float(r.gpu_ms)
			cpu += float(r.cpu_ms)
			dr += float(r.draws)
			vram = maxf(vram, float(r.vram_mo))
		var k := float(a.size())
		lines.append("%-8s %-8s %9.1f %11.1f %9.2f %9.2f %8d %9.0f" % [lv, a[0].effectif, k / fps, low, gpu / k, cpu / k, roundi(dr / k), vram])
	lines.append("")
	lines.append("(i/s moy : moyenne harmonique des vues ; 1 % bas : la pire vue ; vidéo : maximum.)")
	for lv in by_level:
		var worst := INF
		var worst_v := ""
		for r in by_level[lv]:
			if float(r.fps) < worst:
				worst = float(r.fps)
				worst_v = r.vue
		lines.append("%s : %s (vue la plus lente : %s, %.0f i/s)" % [lv, "60 i/s tenus partout" if worst >= TARGET_FPS else "sous 60 i/s", worst_v, worst])
	lines.append("")
	lines.append("Détail par vue : banc.csv (même dossier).")
	var txt := FileAccess.open(TXT_PATH, FileAccess.WRITE)
	if txt:
		txt.store_string("\n".join(lines) + "\n")
		txt.close()
	print("\n".join(lines))
	print("BANC FINI · %d vues · rapport : %s · détail : %s" % [rows.size(), ProjectSettings.globalize_path(TXT_PATH), ProjectSettings.globalize_path(CSV_PATH)])
