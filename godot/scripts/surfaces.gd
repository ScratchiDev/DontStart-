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

## Retouches sur vraie carte (lot V2-RETOUCHES ; le rendu logiciel et ses tests gardent les matières d'avant) :
##  - parquet : rugosité des lames de 0,6 à 0,82 (PARQUET_ORM_V3) : au-dessus du seuil de 0,6 où Godot
##    coupe la réflexion en espace écran, le parquet ciré ne reflète plus que la sonde de la pièce, floue :
##    plus de reflet net des pieds de chaise ni de filet orange au pied des meubles ;
##  - moquette : variation plus marquée (MOQUETTE_VAR2, ±12 %, taches de poils couchés à deux échelles), et
##    les chemins d'usure posés par les pièces (Wear.path) renforcés sur la moquette (after_build) ;
##  - corniche (mats.crown) : plâtre peint mat comme le plafond (rugosité 0,92, reflet 0,25) au lieu du
##    bois peint satiné : la gorge, tournée vers les suspensions, ne fait plus un tube de néon ;
##  - lambris : une matière par pièce (LAMBRIS_MATS, Builder.LAMBRIS), textures Lambris/ (lames à joint en
##    V, lames peintes, panneaux), générées par aaa_fab/V2-RETOUCHES/outils/gen_lambris.py (CC0, d'après
##    Wood027).
const PARQUET_ORM_V3 := "herringbone_parquet/herringbone_parquet_orm_v3.jpg"
const MOQUETTE_VAR2 := "Carpet016/moquette_var2.png"
const FULL_CROWN_TINT := Color(0.66, 0.645, 0.6)
const CROWN_ROUGHNESS := 0.92
const CROWN_SPECULAR := 0.25
## Chemins d'usure sur la moquette : poils tassés, plus clairs et plus gris que le velours (teinte
## multipliée par le masque du décalque, mélange de l'albédo). Étalonnage final (lot V3-ETALONNAGE) : à
## (0,52 ; 0,38 ; 0,32), la teinte était celle de la moquette elle-même (0,55 ; 0,35 ; 0,305) : les chemins ne
## se voyaient pas ; ils sont maintenant nettement plus gris et plus clairs.
const MOQUETTE_PATH_TINT := Color(0.66, 0.53, 0.47)
const MOQUETTE_PATH_MIX := 0.9
## Parquet ciré (vraie carte) : reflet spéculaire (0,4 avant l'étalonnage final : le parquet de la chambre
## de ta mère faisait encore sol mouillé, reflet net de la chaise et du tapis, 99e centile de 140 à 172).
const PARQUET_SPECULAR := 0.28
## Lambris par pièce : clé de « mats » -> [texture sous Lambris/ (ou chemin complet avec « / »), mètres par
## répétition, teinte, facteur de rugosité, masque de crasse HD (0 : sans crasse)]. Builder.LAMBRIS dit quelle
## pièce prend quoi. Couleurs moyennes visées (sRGB) : miel (0,36 ; 0,22 ; 0,12), chêne foncé ciré (0,24 ;
## 0,16 ; 0,1), noyer (0,26 ; 0,15 ; 0,09), crème passé (0,62 ; 0,58 ; 0,47), gris-bleu sourd (0,4 ; 0,45 ;
## 0,47) : les peints restent assez sombres pour la nuit (la lampe de poche ne doit pas y trouver un mur
## clair sur un tiers de la hauteur).
const LAMBRIS_MATS := {
	"lambris_miel": ["Lambris", 0.76, Color(0.72, 0.7, 0.68), 0.95, 0],
	"lambris_chene": ["Lambris", 1.1, Color(0.48, 0.5, 0.56), 1.0, 2],
	"boiserie_chene": ["Panneau", 1.2, Color(0.47, 0.5, 0.56), 1.0, 2],
	"lambris_noyer": ["Panneau", 1.2, Color(0.51, 0.47, 0.5), 0.9, 2],
	"lambris_creme": ["LambrisPeint", 0.8, Color(0.72, 0.68, 0.58), 1.0, 3],
	"boiserie_creme": ["PaintedWood009C/PaintedWood009C", 1.0, Color(0.89, 0.89, 0.81), 1.0, 3],
	"lambris_gris": ["LambrisPeint", 1.05, Color(0.46, 0.53, 0.58), 1.0, 3],
	"boiserie_gris": ["PaintedWood009C/PaintedWood009C", 1.0, Color(0.57, 0.69, 0.81), 1.0, 3],
}


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
	if full and (ResourceLoader.exists(DIR + PARQUET_ORM_V3) or ResourceLoader.exists(DIR + PARQUET_ORM_V2)):
		var fl := mats.floor as StandardMaterial3D
		var orm2: Texture2D = load(DIR + (PARQUET_ORM_V3 if ResourceLoader.exists(DIR + PARQUET_ORM_V3) else PARQUET_ORM_V2))
		fl.ao_texture = orm2
		fl.roughness = 1.0
		fl.roughness_texture = orm2
		fl.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		fl.metallic_specular = PARQUET_SPECULAR
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
		var var_path := DIR + (MOQUETTE_VAR2 if ResourceLoader.exists(DIR + MOQUETTE_VAR2) else MOQUETTE_VAR)
		if ResourceLoader.exists(var_path):
			mq.detail_enabled = true
			mq.detail_albedo = load(var_path)
			mq.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			mq.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
			mq.uv2_triplanar = true
			mq.uv2_world_triplanar = true
			mq.uv2_scale = Vector3.ONE / 2.4
		mats.moquette = mq
	else:
		mats.moquette = pbr_acg("Carpet016/Carpet016", 1.7, Color(0.51, 0.32, 0.28), 1.0, true)
	if full:
		_build_retouches(mats)
	# crasse HD : une image après la construction, vraie carte graphique seulement (hors de B16)
	schedule_hd(mats)


## Corniche et lambris de chaque pièce (vraie carte seulement ; voir PARQUET_ORM_V3 et LAMBRIS_MATS).
## Une clé absente de « mats » (texture manquante) laisse Builder.trim sur les matières d'avant.
static func _build_retouches(mats: Dictionary) -> void:
	var crown := pbr("PaintedPlaster017/PaintedPlaster017", 2.0, FULL_CROWN_TINT, 0.3, false, false, CROWN_ROUGHNESS)
	crown.resource_name = "corniche_plaster"
	crown.metallic_specular = CROWN_SPECULAR
	mats.crown = grime(crown, 0.6, 1)
	if not ResourceLoader.exists(DIR + "Lambris/Lambris_albedo.jpg"):
		return
	for k: String in LAMBRIS_MATS:
		var e: Array = LAMBRIS_MATS[k]
		var base: String = e[0] if String(e[0]).contains("/") else "Lambris/" + String(e[0])
		var m := pbr(base, float(e[1]), e[2] as Color, 1.0, true, false, -1.0)
		m.resource_name = k
		m.roughness = float(e[3])
		if int(e[4]) > 0:
			m = grime(m, 0.6, int(e[4])) as StandardMaterial3D
		mats[k] = m


## Après la construction et l'habillage des pièces (Main._after_build, vraie carte seulement, hors de B16) :
## les chemins d'usure (Wear.path, genre « chemin_usure ») posés sur une moquette prennent la teinte et le
## mélange de MOQUETTE_PATH_* (avec ceux du parquet, ils se perdaient dans le velours sombre). Rend le nombre
## de décalques retouchés.
static func after_build(tree: SceneTree) -> int:
	if Qualite.soft() or tree == null:
		return 0
	var n := 0
	for d in tree.get_nodes_in_group("usure"):
		var dc := d as Decal
		if dc == null or String(dc.get_meta("usure", "")) != "chemin_usure":
			continue
		var room := dc.get_parent() as HouseRoom
		if room == null or room.floor_kind != "moquette":
			continue
		var a := dc.modulate.a
		dc.modulate = Color(MOQUETTE_PATH_TINT.r, MOQUETTE_PATH_TINT.g, MOQUETTE_PATH_TINT.b, a)
		dc.albedo_mix = MOQUETTE_PATH_MIX
		n += 1
	return n


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
