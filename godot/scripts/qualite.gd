class_name Qualite
extends RefCounted
## Préréglages d'image : Basse, Moyenne, Élevée, Ultra (passe « triple A », lot V1-RENDU). Fonctions
## statiques, sans état : le niveau voulu est Game.quality (settings.cfg « video/qualite », ou
## « -- --qualite=basse|moyenne|elevee|ultra », non enregistré).
##
## Invariants :
##  - Basse reproduit exactement l'ancienne case « Qualité élevée » décochée, Élevée l'ancienne case
##    cochée (Game.high_quality reste lisible : vrai dès Élevée) ;
##  - rendu logiciel (soft(), autotests) : le niveau est ramené à Élevée au plus, et rien de ce qui est
##    nouveau (reflets, SSR, FSR 2, anisotrope, atlas 8192, ombres PCSS…) ne s'allume : le parcours
##    testé reste celui de la 0.3.3 ;
##  - style rétro : le chemin d'avant, ligne pour ligne (Élevée et Ultra s'y comportent comme l'ancien
##    « haut », Moyenne aussi, Basse comme l'ancien « bas ») ; aucune nouveauté de lumière ni de
##    post-traitement ;
##  - le grain, le halo, l'aberration et le vignettage ne dépendent pas du niveau : c'est la direction
##    artistique, pas la qualité.
##
## Pour les autres lots :
##  - Qualite.soft() : rendu logiciel (pas de vraie carte graphique, ou --headless) ; tout ce qui coûte
##    au rendu y est coupé (R2) ;
##  - Qualite.details_on() : les objets de décor de dress_details() et Builder.detail() existent ;
##  - Qualite.extras_on() : nouveautés de lumière et de post-traitement permises (ni logiciel, ni rétro) ;
##  - Qualite.at_least(Qualite.ELEVEE) : le niveau effectif atteint Élevée ;
##  - méta « taille » (float, en m) sur une Light3D : taille de la source pour les ombres douces à
##    durcissement de contact (PCSS), posée en light_size en Ultra seulement (0 ailleurs) ;
##  - méta « energie_base » (float) sur une Light3D d'une pièce : son énergie quand elle est allumée,
##    pour la capture de la sonde de reflets (HouseRoom) ;
##  - Qualite.hide_from_probes(lumiere) : la lumière n'apparaît jamais dans les sondes de reflets (lampe
##    de poche et tout ce qui suit le joueur).

enum { BASSE, MOYENNE, ELEVEE, ULTRA }
const NOMS := ["Basse", "Moyenne", "Élevée", "Ultra"]
const CLES := ["basse", "moyenne", "elevee", "ultra"]      # « --qualite=… »
## Texte d'aide de chaque niveau (bouton « Qualité » des options).
const AIDE := [
	"PC portables, puces graphiques intégrées",
	"Steam Deck, petites cartes graphiques",
	"Cartes graphiques courantes",
	"Cartes récentes (8 Go et plus)",
]

## Couche de RENDU des lumières que les sondes de reflets ne voient pas (lampe de poche) : la caméra du
## joueur et les caméras de flux la gardent, le cull_mask des sondes l'exclut (vérifié sur lavapipe :
## une lumière de cette seule couche éclaire toujours la couche 1, et la sonde l'ignore).
const LAYER_NO_PROBE := 13

# Une colonne par niveau : [Basse, Moyenne, Élevée, Ultra] (rendu net ; le rétro garde son chemin).
const SCALE_3D := [0.75, 0.87, 1.0, 1.0]
const ANISO := [Viewport.ANISOTROPY_2X, Viewport.ANISOTROPY_4X, Viewport.ANISOTROPY_8X, Viewport.ANISOTROPY_16X]
const LOD := [1.0, 2.0, 1.0, 0.5]
const FOG_GRID := [96, 64, 96, 128]
const ATLAS := [4096, 2048, 4096, 8192]
const SSR_STEPS := [0, 0, 48, 96]


## Rendu logiciel (llvmpipe/lavapipe, SwiftShader, pilote de base de Windows, ou --headless).
static func soft() -> bool:
	return Main.software_renderer()


## Le niveau voulu (Game.quality), borné.
static func wanted() -> int:
	return clampi(int(Game.quality), BASSE, ULTRA)


## Le niveau appliqué : en rendu logiciel, jamais au-dessus d'Élevée.
static func effective() -> int:
	var q := wanted()
	return mini(q, ELEVEE) if soft() else q


static func at_least(q: int) -> bool:
	return effective() >= q


## Les objets de détail (dress_details, Builder.detail) : seulement avec une vraie carte graphique.
static func details_on() -> bool:
	return not soft()


## Nouveautés de lumière et de post-traitement de la passe : ni en rendu logiciel, ni en style rétro.
static func extras_on() -> bool:
	return not soft() and not Game.style_retro


## Sondes de reflets et SSR : à partir d'Élevée, sur vraie carte, hors rétro.
static func reflections_on() -> bool:
	return extras_on() and at_least(ELEVEE)


## L'ancienne case « Qualité élevée » telle que le rendu la voit : en rétro, Moyenne compte comme
## l'ancien « haut » (brouillard, GI, SSAO, ombres de l'écran) ; en rendu net, c'est Élevée et plus.
static func old_high() -> bool:
	var q := effective()
	return q >= MOYENNE if Game.style_retro else q >= ELEVEE


## Éclairage indirect (VoxelGI des pièces), brouillard volumétrique, SSAO, ombres de l'écran et du
## plafonnier de la chambre : à partir de Moyenne.
static func gi_on() -> bool:
	return old_high() if Game.style_retro else effective() >= MOYENNE


static func name_of(q: int) -> String:
	return NOMS[clampi(q, BASSE, ULTRA)]


## « basse », « Moyenne », « élevée », « elevee », « ultra », « 0 » à « 3 » → niveau ; -1 sinon.
static func from_name(s: String) -> int:
	var k := s.strip_edges().to_lower().replace("é", "e").replace("è", "e")
	if k.is_valid_int():
		var n := int(k)
		return n if n >= BASSE and n <= ULTRA else -1
	return CLES.find(k)


## Premier lancement (pas de réglage enregistré) : d'après la carte. Puce intégrée (Steam Deck
## compris) → Moyenne ; tout le reste (carte dédiée, rendu logiciel des autotests) → Élevée. Ultra
## n'est jamais choisi d'office.
static func detect() -> int:
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return MOYENNE
	return ELEVEE


## La lumière n'apparaît pas dans les sondes de reflets (voir LAYER_NO_PROBE).
static func hide_from_probes(l: Light3D) -> void:
	if l:
		l.layers = 1 << (LAYER_NO_PROBE - 1)


## Une ligne pour les journaux : « QUALITÉ effective Élevée (voulue Ultra · rendu logiciel · net) ».
static func describe() -> String:
	return "QUALITÉ effective %s (voulue %s · %s · %s)" % [name_of(effective()), name_of(wanted()),
		"rendu logiciel" if soft() else "carte graphique", "rétro" if Game.style_retro else "net"]


# ------------------------------------------------------------------ application

## Anticrénelage temporel (FSR 2 « natif ») : Ultra, et Élevée depuis le lot V2-RETOUCHES (la revue voyait
## les fils fins, câbles, tirettes et arêtes de plinthe en pointillés avec le SMAA seul) ; rendu net sur
## vraie carte seulement (le rendu logiciel garde l'image bilinéaire d'avant, le rétro son chemin). Coût :
## celui d'Ultra, de l'ordre de 1 ms par image en 1440p natif pour une carte de la classe d'une RTX 3070
## (ordre de grandeur publié par AMD ; le TAA de Godot coûte moins mais floute et laisse des traînées).
## Moyenne garde FSR 1 et FXAA, Basse FSR 1.
## (« -- --aa-elevee=smaa » : Élevée comme avant, bilinéaire et SMAA, pour les comparaisons et les bancs.)
static func fsr2_on(q: int, s: bool) -> bool:
	if s:
		return false
	return q == ULTRA or (q == ELEVEE and not OS.get_cmdline_user_args().has("--aa-elevee=smaa"))

const FSR2_SHARPNESS := 0.2


## Échelle de la 3D en Élevée et Ultra (FSR 2) : native jusqu'en 1440p, « qualité » au-delà.
static func fsr2_scale(window_h: int) -> float:
	if window_h <= 1440:
		return 1.0
	return 0.77 if window_h <= 1800 else 0.67


## Taille de source (light_size) d'une lumière de « taille » m : la taille en Ultra (rendu net, vraie
## carte), 0 ailleurs. Pour les lumières créées après le lancement ; les autres reçoivent leur méta
## « taille » à chaque apply().
static func pcss_size(taille: float) -> float:
	return taille if extras_on() and effective() == ULTRA else 0.0


## Dernier état appliqué aux réglages globaux du serveur de rendu (brouillard, SSAO, atlas, filtres) :
## les curseurs du menu (volume, luminosité) rappellent apply() à chaque cran, sans tout réallouer.
static var _last_key := ""


## Valeur d'un réglage du projet (pour revenir aux valeurs d'origine en quittant un niveau).
static func _ps(key: String, default_value: Variant) -> Variant:
	return ProjectSettings.get_setting(key, default_value)


## Applique le niveau effectif au rendu (Main._apply_quality et Main._apply_video y délèguent).
## Appelé au lancement, à chaque changement de réglage (Game.settings_changed) et quand la fenêtre
## change de taille (FSR 2).
static func apply(main: Main) -> void:
	var q := effective()
	var retro := bool(Game.style_retro)
	var s := soft()
	var extras := not s and not retro
	var hq := old_high()
	var env := main.env
	var vp := main.get_viewport()
	var win := main.get_tree().root
	var key := "%d %s %s %d %d" % [q, retro, s, win.size.y, main.get_instance_id()]
	var changed := key != _last_key
	_last_key = key
	# --- éclairage indirect, brouillard, SSAO, ombres des lampes de la chambre (l'ancien _apply_quality)
	var gi := gi_on()
	if main.house:
		for id in main.house.rooms:
			var r: HouseRoom = main.house.rooms[id]
			if r.gi:
				r.gi.visible = gi and r.active
	env.volumetric_fog_enabled = gi
	env.ssao_enabled = gi
	if main.room.get("screen_light"):
		main.room.screen_light.shadow_enabled = gi
	if main.room.get("ceiling_light"):
		main.room.ceiling_light.shadow_enabled = gi
	# --- image (l'ancien _apply_video)
	if retro:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.use_debanding = false
	else:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		var fsr2 := fsr2_on(q, s)
		if q <= MOYENNE:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = SCALE_3D[q]
		elif fsr2:
			# FSR 2 « natif » : l'anticrénelage temporel (papier peint rayé, fils fins, reflets)
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
			vp.scaling_3d_scale = fsr2_scale(win.size.y)
			vp.fsr_sharpness = FSR2_SHARPNESS
		else:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
		if s:
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		elif fsr2:
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED     # (FSR 2 fait le sien)
		else:
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if q >= ELEVEE else Viewport.SCREEN_SPACE_AA_FXAA
		vp.use_debanding = true
	vp.use_taa = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	# (éclairage indirect des VoxelGI : à demi-résolution en rendu logiciel, -10 % par image, et en Moyenne)
	RenderingServer.gi_set_use_half_resolution(s or (q == MOYENNE and not retro))
	# (filtrage anisotrope des sols, Surfaces.world_uv)
	if s:
		vp.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
	elif retro or q == BASSE:
		vp.anisotropic_filtering_level = Viewport.ANISOTROPY_4X if hq else Viewport.ANISOTROPY_2X
	else:
		vp.anisotropic_filtering_level = ANISO[q]
	vp.mesh_lod_threshold = LOD[q] if extras else 1.0
	# --- brouillard, SSAO, ombres : finesse par niveau (nouveau : rendu net sur vraie carte seulement)
	var fq := q if extras else ELEVEE
	env.volumetric_fog_temporal_reprojection_amount = 0.8 if fq == ULTRA else 0.9
	# --- reflets : SSR (Élevée en demi-résolution, Ultra plein) ; les sondes sont posées par HouseRoom
	env.ssr_enabled = reflections_on()
	if env.ssr_enabled:
		env.ssr_max_steps = SSR_STEPS[q]
		# (entrée en fondu plus longue : au contact des pieds de chaise et des meubles, le parquet ne fait plus
		# miroir mouillé)
		env.ssr_fade_in = 0.35
		env.ssr_fade_out = 2.0
		# (portes et cloisons de 10 cm : la tolérance par défaut, 0,5, étirait les reflets derrière elles)
		env.ssr_depth_tolerance = 0.15
	if not changed:
		return
	RenderingServer.environment_set_volumetric_fog_volume_size(FOG_GRID[fq] if fq != BASSE else int(_ps("rendering/environment/volumetric_fog/volume_size", 96)),
		FOG_GRID[fq] if fq != BASSE else int(_ps("rendering/environment/volumetric_fog/volume_depth", 96)))
	match fq:
		MOYENNE:
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
		ULTRA:
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA, false, 1.0, 3, 50.0, 300.0)
		_:
			RenderingServer.environment_set_ssao_quality(int(_ps("rendering/environment/ssao/quality", 2)),
				bool(_ps("rendering/environment/ssao/half_size", true)), float(_ps("rendering/environment/ssao/adaptive_target", 0.5)),
				int(_ps("rendering/environment/ssao/blur_passes", 2)), float(_ps("rendering/environment/ssao/fadeout_from", 50.0)),
				float(_ps("rendering/environment/ssao/fadeout_to", 300.0)))
	vp.positional_shadow_atlas_size = ATLAS[fq] if fq != BASSE else int(_ps("rendering/lights_and_shadows/positional_shadow/atlas_size", 4096))
	RenderingServer.positional_soft_shadow_filter_set_quality(shadow_quality(q, retro, extras))
	if env.ssr_enabled:
		# (environment_set_ssr_roughness_quality ne fait plus rien en 4.7.2 et avertissait à chaque
		# lancement : la rugosité des reflets est prise en compte d'office)
		RenderingServer.environment_set_ssr_half_size(q != ULTRA)
	# filtrage des décalques (taches, empreintes) et des masques de projection (lampe de poche)
	RenderingServer.decals_set_filter(RenderingServer.DECAL_FILTER_LINEAR_MIPMAPS_ANISOTROPIC if extras and q >= ELEVEE
		else int(_ps("rendering/textures/decals/filter", RenderingServer.DECAL_FILTER_LINEAR_MIPMAPS)))
	RenderingServer.light_projectors_set_filter(RenderingServer.LIGHT_PROJECTOR_FILTER_LINEAR_MIPMAPS_ANISOTROPIC if extras and q >= ELEVEE
		else int(_ps("rendering/textures/light_projectors/filter", RenderingServer.LIGHT_PROJECTOR_FILTER_LINEAR_MIPMAPS)))
	# ombres douces à durcissement de contact (Ultra) : la taille réelle des sources (méta « taille »)
	if not s:
		var pcss := extras and q == ULTRA
		for n in main.find_children("*", "Light3D", true, false):
			var l := n as Light3D
			if l.has_meta("taille"):
				l.light_size = float(l.get_meta("taille")) if pcss else 0.0


## Filtre des ombres douces : l'ancien réglage (rétro, Basse, Élevée), SOFT_LOW en Moyenne et
## SOFT_HIGH en Ultra (rendu net sur vraie carte).
static func shadow_quality(q: int, retro: bool, extras := true) -> RenderingServer.ShadowQuality:
	var hq := q >= MOYENNE if retro else q >= ELEVEE
	if retro:
		return RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if hq else RenderingServer.SHADOW_QUALITY_HARD
	if extras and q == ULTRA:
		return RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	return RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if hq else RenderingServer.SHADOW_QUALITY_SOFT_LOW
