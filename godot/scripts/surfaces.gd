class_name Surfaces
## Matières PBR des surfaces de la maison (murs, sols, plafonds, lambris, plinthes, portes, fenêtres) :
## textures CC0 (ambientCG, Poly Haven) dans assets/textures/<id>/, préparées par l'agent A (couleur
## « _albedo », normale OpenGL « _normal_gl », « _orm » : R = occlusion, G = rugosité). Chaque texture
## est posée en coordonnées du monde (triplanaire) à sa taille réelle en mètres : pas d'étirement, et
## elle continue d'une boîte à l'autre. Les couleurs gardent l'ambiance de chaque pièce.
## Appelé une fois par Builder._make_materials (remplit le dictionnaire partagé « mats »).
##
## Ajouter une surface texturée : déposer <id>_albedo.jpg, <id>_normal_gl.jpg, <id>_orm.jpg dans
## assets/textures/<id>/ (avec leurs .import : VRAM compressé, mipmaps, normal map), puis
##     var m := Surfaces.pbr("<id>/<id>", 1.2, Color(0.9, 0.85, 0.8))   # 1,2 m par répétition
##     m = Surfaces.grime(m, 0.5)                                       # crasse (facultatif)
## (Builder._grimy et Surfaces.grime posent grime.png ; une image après la construction, avec une vraie
## carte graphique, les masques HD de assets/decals/gen/ la remplacent : voir GRIME_HD.)

const DIR := "res://assets/textures/"
## Crasse en haute définition (lot V1-USURE, tools/make_wear.py) : trois masques de 1024 px, périodiques,
## de même moyenne que grime.png (256 px) : 1 = plâtre, 2 = patine (bois, meubles), 3 = peinture
## (portes, boiseries). Ils remplacent grime.png sur toutes les matières qui l'utilisent (Surfaces.grime
## et Builder._grimy), UNE image après la construction et seulement avec une vraie carte graphique :
## hors de la mesure B16, et rien ne change en rendu logiciel. Les matières restent des StandardMaterial3D
## (HouseRoom._bake_proxy).
const GRIME_HD := ["res://assets/decals/gen/grime_hd_1.png", "res://assets/decals/gen/grime_hd_2.png",
	"res://assets/decals/gen/grime_hd_3.png"]

static var _grime_tex: Texture2D
static var _hd: Array[Texture2D] = []      # masques HD chargés (vide tant que le remplacement n'a pas eu lieu)
static var _hd_mats := {}                  # le dictionnaire « mats » de la construction en cours
## Dernier remplacement : [matières changées, millisecondes] (bancs d'essai, journaux).
static var hd_stats := Vector2i(-1, 0)


## Matière PBR (StandardMaterial3D) d'une texture « <base>_albedo.jpg / _normal_gl.jpg / _orm.jpg »,
## posée en triplanaire dans le monde, une répétition tous les « meters » mètres, teintée par « tint ».
## ao = false : pas d'occlusion ; rough < 0 : rugosité lue dans _orm, sinon rugosité constante (une carte
## de moins à lire, trois fois en triplanaire). Albédo RGBA : « <base>_albedo.png » est pris quand le .jpg
## manque (CardboardSet001, Tape004 : atlas de morceaux découpés). metal = true : métal lu dans le canal
## bleu de _orm (Metal049B, Metal046B, PaintedMetal010).
static func pbr(base: String, meters: float, tint := Color(1, 1, 1), normal_scale := 1.0, ao := true, aniso := false, rough := -1.0, metal := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = base.get_file()
	var albedo := DIR + base + "_albedo.jpg"
	if not ResourceLoader.exists(albedo) and ResourceLoader.exists(DIR + base + "_albedo.png"):
		albedo = DIR + base + "_albedo.png"
	m.albedo_texture = load(albedo)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(DIR + base + "_normal_gl.jpg")
	m.normal_scale = normal_scale
	var orm: Texture2D = load(DIR + base + "_orm.jpg") if ao or rough < 0.0 or metal else null
	if metal:
		m.metallic = 1.0
		m.metallic_texture = orm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	if rough < 0.0:
		m.roughness = 1.0
		m.roughness_texture = orm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	else:
		m.roughness = rough
	if ao:
		m.ao_enabled = true
		m.ao_texture = orm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.2
	world_uv(m, meters, aniso)
	return m


## Même chose avec des cartes séparées (Color / NormalGL / Roughness / AmbientOcclusion d'ambientCG).
static func pbr_acg(base: String, meters: float, tint := Color(1, 1, 1), normal_scale := 1.0, aniso := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = base.get_file()
	m.albedo_texture = load(DIR + base + "_Color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(DIR + base + "_NormalGL.jpg")
	m.normal_scale = normal_scale
	m.roughness = 1.0
	m.roughness_texture = load(DIR + base + "_Roughness.jpg")
	if ResourceLoader.exists(DIR + base + "_AmbientOcclusion.jpg"):
		m.ao_enabled = true
		m.ao_texture = load(DIR + base + "_AmbientOcclusion.jpg")
		m.ao_light_affect = 0.2
	world_uv(m, meters, aniso)
	return m


## Coordonnées de texture prises dans le monde (triplanaire), « meters » mètres par répétition. Filtrage
## anisotrope (aniso) pour les sols, vus très en biais ; trilinéaire ailleurs (moins cher). Le niveau
## d'anisotropie suit « Qualité élevée » (main.gd, Viewport.anisotropic_filtering_level).
static func world_uv(m: BaseMaterial3D, meters: float, aniso := false) -> BaseMaterial3D:
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE / meters
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if aniso \
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


## Crasse et usure : grime.png multipliée par-dessus (couche de détail), en coordonnées du monde, une
## répétition tous les 1/scale mètres. (Même effet que Builder._grimy.) hd : masque HD voulu (1 plâtre,
## 2 patine, 3 peinture ; 0 = d'après la matière), posé en méta « grime_hd » ; une matière créée après le
## remplacement reçoit tout de suite son masque HD.
static func grime(m: BaseMaterial3D, scale := 0.5, hd := 0) -> BaseMaterial3D:
	if _grime_tex == null:
		_grime_tex = load(DIR + "grime.png")
		_hook_release()
	m.detail_enabled = true
	m.detail_albedo = _grime_tex
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_scale = Vector3.ONE * scale
	if hd > 0:
		m.set_meta("grime_hd", hd)
	if not _hd.is_empty():
		m.detail_albedo = _hd_for(m)
	return m


## La texture de crasse à poser sur une matière créée maintenant : le masque HD (selon « m ») une fois le
## remplacement fait, grime.png avant (et toujours en rendu logiciel). Pour Builder._grimy et les autres.
static func grime_texture(m: BaseMaterial3D = null) -> Texture2D:
	if not _hd.is_empty():
		return _hd_for(m)
	if _grime_tex == null:
		_grime_tex = load(DIR + "grime.png")
		_hook_release()
	return _grime_tex


## Masque HD d'une matière : méta « grime_hd » si posée, sinon d'après son nom (plâtre → 1, bois peint →
## 3), son métal (3) ; tout le reste (bois, meubles, tissus) → 2.
static func _hd_for(m: BaseMaterial3D) -> Texture2D:
	var k := 2
	if m:
		if m.has_meta("grime_hd"):
			k = int(m.get_meta("grime_hd"))
		else:
			var n := String(m.resource_name).to_lower()
			if n.contains("plaster"):
				k = 1
			elif n.contains("painted") or m.metallic >= 0.3:
				k = 3
	return _hd[clampi(k, 1, _hd.size()) - 1]


## Programme le remplacement de grime.png par les masques HD à la prochaine image (vraie carte
## graphique seulement). Appelé par build() ; sans effet en rendu logiciel.
static func schedule_hd(mats: Dictionary) -> void:
	if Qualite.soft():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_hd_mats = mats
	# (les masques se décodent en arrière-plan pendant la construction : rien sur le fil principal)
	if _hd.is_empty():
		for p in GRIME_HD:
			if ResourceLoader.exists(p) and ResourceLoader.load_threaded_get_status(p) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				ResourceLoader.load_threaded_request(p, "Texture2D")
	if not tree.process_frame.is_connected(_swap_hd):
		tree.process_frame.connect(_swap_hd, CONNECT_ONE_SHOT)
	_hook_release()


## Oublie les textures gardées en variables statiques (grime.png, masques HD) quand Godot quitte : sans
## cela, Godot signale des ressources encore utilisées à la sortie.
static func _release() -> void:
	_hd.clear()
	_hd_mats = {}
	_grime_tex = null


static func _hook_release() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and not tree.root.tree_exiting.is_connected(_release):
		tree.root.tree_exiting.connect(_release)


## Le remplacement : charge les trois masques, puis parcourt les matières du dictionnaire partagé et de
## tous les objets de la scène ; celles dont la couche de détail est grime.png reçoivent leur masque HD.
static func _swap_hd() -> void:
	var t0 := Time.get_ticks_usec()
	if _hd.is_empty():
		for p in GRIME_HD:
			if ResourceLoader.exists(p):
				var st := ResourceLoader.load_threaded_get_status(p)
				var t: Texture2D = null
				if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS or st == ResourceLoader.THREAD_LOAD_LOADED:
					t = ResourceLoader.load_threaded_get(p) as Texture2D
				else:
					t = load(p) as Texture2D
				if t:
					_hd.append(t)
	if _hd.size() < GRIME_HD.size():
		_hd.clear()
		_hd_mats = {}
		return
	var old := grime_texture_old()
	var seen := {}
	var n := 0
	for m in _hd_mats.values():
		if m is Material:
			n += _swap_one(m, old, seen)
	_hd_mats = {}
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		for node in tree.root.find_children("*", "GeometryInstance3D", true, false):
			var g := node as GeometryInstance3D
			n += _swap_one(g.material_override, old, seen)
			n += _swap_one(g.material_overlay, old, seen)
			if g is MeshInstance3D:
				var mi := g as MeshInstance3D
				if mi.mesh:
					for i in mi.mesh.get_surface_count():
						n += _swap_one(mi.get_surface_override_material(i), old, seen)
						n += _swap_one(mi.mesh.surface_get_material(i), old, seen)
			elif g is CSGPrimitive3D:
				n += _swap_one((g as CSGPrimitive3D).get("material"), old, seen)
			elif g is MultiMeshInstance3D:
				var mm := (g as MultiMeshInstance3D).multimesh
				if mm and mm.mesh:
					for i in mm.mesh.get_surface_count():
						n += _swap_one(mm.mesh.surface_get_material(i), old, seen)
	hd_stats = Vector2i(n, roundi((Time.get_ticks_usec() - t0) / 1000.0))
	print("CRASSE HD : %d matières en %d ms" % [hd_stats.x, hd_stats.y])


static func grime_texture_old() -> Texture2D:
	if _grime_tex == null:
		_grime_tex = load(DIR + "grime.png")
	return _grime_tex


static func _swap_one(m: Material, old: Texture2D, seen: Dictionary) -> int:
	if m == null or seen.has(m):
		return 0
	seen[m] = true
	var c := 0
	var bm := m as BaseMaterial3D
	if bm and bm.detail_enabled and bm.detail_albedo == old:
		bm.detail_albedo = _hd_for(bm)
		c = 1
	if m.next_pass:
		c += _swap_one(m.next_pass, old, seen)
	return c


## Matières communes sur vraie carte (lot V2-NUIT ; le rendu logiciel, profil des tests, garde celles
## d'avant) :
##  - peinture de la salle de bain et de la lingerie un peu moins blanche (FULL_WALL_PAINT) ;
##  - faïence neuve (Faience15, tools : aaa_fab/V2-NUIT/outils/gen_faience.py, œuvre originale CC0) :
##    carreaux de 15 cm, joints gris clair de 2 mm, émail brillant (rugosité 0,14), ±3 % d'un carreau à
##    l'autre, 2048 px pour 1,2 m (1 700 px/m au lieu de 570) ; la grille tombe juste en haut du lambris
##    (1,4 m) et dans les angles (FAIENCE_OFFSET) ;
##  - moquette : fibres plus fines (0,9 m par répétition au lieu de 1,7), relief ×1,6, variation lente
##    de ±8 % (moquette_var.png), rugosité de tissu et reflet rasant (rim) ;
##  - parquet : rugosité variée de 0,53 à 0,8 selon les lames et le passage, joints et pores à 0,9
##    (herringbone_parquet_orm_v2.jpg), reflet spéculaire 0,4 : il ne fait plus sol mouillé.
const FULL_WALL_PAINT := Color(0.76, 0.745, 0.7)
const FULL_FAIENCE_TINT := Color(0.62, 0.6, 0.58)
const FAIENCE_M := 1.2
const FAIENCE_OFFSET := Vector3(0.0, -0.0416667, -0.0416667)
const FULL_MOQUETTE_TINT := Color(0.55, 0.35, 0.305)
const MOQUETTE_M := 0.9
const PARQUET_ORM_V2 := "herringbone_parquet/herringbone_parquet_orm_v2.jpg"
const MOQUETTE_VAR := "Carpet016/moquette_var.png"


## Remplit « mats » (dictionnaire partagé des pièces) : les clés et leur rôle ne changent pas, seules
## les matières deviennent photographiques. Les teintes reprennent la couleur moyenne d'avant.
static func build(mats: Dictionary) -> void:
	var full := not Qualite.soft()
	# (coût en rendu logiciel : chaque carte est lue trois fois en triplanaire ; la crasse et l'occlusion
	# ne sont gardées que là où elles se voient : papiers peints et lambris ont leurs taches dans la texture)
	# plâtre peint (murs porteurs nus, embrasures) et plafonds : PaintedPlaster017 (2 m)
	var plaster := "PaintedPlaster017/PaintedPlaster017"
	mats.plaster = grime(pbr(plaster, 2.0, Color(0.8, 0.76, 0.68), 1.0, false, false, 0.9), 0.4, 1)
	# (plafond lissé : relief de normale à 30 %, sinon il faisait crépi ou papier alu froissé en vue rasante)
	mats.ceil = pbr(plaster, 2.0, Color(0.68, 0.66, 0.61), 0.3, false, false, 0.92)
	# (peinture et faïence de la salle de bain un peu moins blanches : sous l'applique, la nuit, elle était
	# presque aussi claire qu'en plein jour)
	mats.wall_paint = grime(pbr(plaster, 2.0, FULL_WALL_PAINT if full else Color(0.86, 0.84, 0.79), 1.0, false, false, 0.85), 0.5, 1)
	# papiers peints : deux lés de 0,53 m par répétition (1,06 m), motifs d'avant, vieillis
	var pp := "decrepit_wallpaper/papier_peint_"
	# (teintes : couleur moyenne d'avant, crasse comprise ; elle assombrissait d'environ 15 %)
	mats.wall = _paper(pp + "mere", Color(0.75, 0.73, 0.69))
	mats.wall_floral = _paper(pp + "fleurs", Color(0.74, 0.72, 0.7))
	mats.wall_stripes = _paper(pp + "rayures", Color(0.71, 0.7, 0.67))
	mats.wall_stripes_dark = _paper(pp + "rayures", Color(0.57, 0.55, 0.52))
	# variantes sans texture de plus (même shader) : chaque pièce a sa couleur, on s'y repère mieux
	mats.wall_floral_blue = _paper(pp + "fleurs", Color(0.6, 0.66, 0.72))           # chambre d'amis
	mats.wall_olive = grime(pbr(plaster, 2.0, Color(0.46, 0.49, 0.38), 1.0, false, false, 0.85), 0.5, 1)   # bureau
	# lambris en lames verticales vernies (stair_planks : lames de 14 cm)
	mats.wainscot = pbr("stair_planks/stair_planks", 0.7, Color(0.68, 0.72, 0.76))
	# parquet en point de Hongrie (herringbone_parquet, 3,4 m réels)
	# (rugosité constante 0,6 : la carte d'origine, très lisse, donnait un sol mouillé ; une carte de moins)
	mats.floor = pbr("herringbone_parquet/herringbone_parquet", 3.4, Color(0.88, 0.82, 0.77), 1.0, true, true, 0.6)
	(mats.floor as StandardMaterial3D).ao_light_affect = 0.35
	if full and ResourceLoader.exists(DIR + PARQUET_ORM_V2):
		var fl := mats.floor as StandardMaterial3D
		var orm2: Texture2D = load(DIR + PARQUET_ORM_V2)
		fl.ao_texture = orm2
		fl.roughness = 1.0
		fl.roughness_texture = orm2
		fl.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		fl.metallic_specular = 0.4
	# bois des meubles, appuis de fenêtre, cimaises et plinthes (Wood027, éclairci)
	mats.wood = grime(pbr("Wood027/Wood027", 1.2, Color(1, 1, 1), 1.0, false), 0.5, 2)
	mats.wood_dark = grime(pbr("Wood027/Wood027", 1.2, Color(0.72, 0.7, 0.7), 1.0, false), 0.5, 2)
	# bois peint : portes, chambranles, croisées, corniches (PaintedWood009C)
	var pw := "PaintedWood009C/PaintedWood009C"
	mats.paint = grime(pbr(pw, 1.0, Color(1.0, 1.0, 0.97), 0.4, false), 1.2, 3)
	# (portes un peu plus sombres que les boiseries : à 0,92, elles brillaient dans le noir)
	mats.door = grime(pbr(pw, 1.0, Color(0.8, 0.78, 0.72), 0.4, false), 0.8, 3)
	# salle de bain : faïence 15 cm (Tiles133B) et damier crème et brun-rouge 20 cm (floor_tiles_06)
	if full and ResourceLoader.exists(DIR + "Faience15/Faience15_albedo.jpg"):
		mats.faience = pbr("Faience15/Faience15", FAIENCE_M, FULL_FAIENCE_TINT)
		(mats.faience as StandardMaterial3D).uv1_offset = FAIENCE_OFFSET
	else:
		mats.faience = pbr("Tiles133B/Tiles133B", 1.8, Color(0.75, 0.69, 0.66))
	mats.carrelage = pbr("floor_tiles_06/floor_tiles_06_damier", 0.8, Color(0.76, 0.73, 0.71), 1.0, true, true)
	(mats.carrelage as StandardMaterial3D).ao_light_affect = 0.35
	# moquette rouille (Carpet016, 1,7 m réels)
	if full:
		var mq := pbr_acg("Carpet016/Carpet016", MOQUETTE_M, FULL_MOQUETTE_TINT, 1.6, true)
		# (rugosité de tissu : la carte d'origine, vers 0,65, donnait un reflet de plastique)
		mq.roughness_texture = null
		mq.roughness = 0.93
		mq.rim_enabled = true
		mq.rim = 0.35
		mq.rim_tint = 0.5
		if ResourceLoader.exists(DIR + MOQUETTE_VAR):
			mq.detail_enabled = true
			mq.detail_albedo = load(DIR + MOQUETTE_VAR)
			mq.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			mq.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
			mq.uv2_triplanar = true
			mq.uv2_world_triplanar = true
			mq.uv2_scale = Vector3.ONE / 2.4
		mats.moquette = mq
	else:
		mats.moquette = pbr_acg("Carpet016/Carpet016", 1.7, Color(0.51, 0.32, 0.28), 1.0, true)
	# crasse HD : une image après la construction, vraie carte graphique seulement (hors de B16)
	schedule_hd(mats)


static func _paper(base: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = base.get_file()
	m.albedo_texture = load(DIR + base + "_albedo.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(DIR + "decrepit_wallpaper/papier_peint_normal_gl.jpg")
	m.normal_scale = 0.8
	m.roughness = 0.88   # (papier_peint_orm.jpg : rugosité variable, plus utilisée — une carte de moins à lire)
	world_uv(m, 1.06)
	return m
