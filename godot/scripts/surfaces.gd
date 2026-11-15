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

const DIR := "res://assets/textures/"

static var _grime_tex: Texture2D


## Matière PBR (StandardMaterial3D) d'une texture « <base>_albedo.jpg / _normal_gl.jpg / _orm.jpg »,
## posée en triplanaire dans le monde, une répétition tous les « meters » mètres, teintée par « tint ».
## ao = false : pas d'occlusion ; rough < 0 : rugosité lue dans _orm, sinon rugosité constante (une carte
## de moins à lire, trois fois en triplanaire).
static func pbr(base: String, meters: float, tint := Color(1, 1, 1), normal_scale := 1.0, ao := true, aniso := false, rough := -1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = base.get_file()
	m.albedo_texture = load(DIR + base + "_albedo.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(DIR + base + "_normal_gl.jpg")
	m.normal_scale = normal_scale
	var orm: Texture2D = load(DIR + base + "_orm.jpg") if ao or rough < 0.0 else null
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
## répétition tous les 1/scale mètres. (Même effet que Builder._grimy.)
static func grime(m: BaseMaterial3D, scale := 0.5) -> BaseMaterial3D:
	if _grime_tex == null:
		_grime_tex = load(DIR + "grime.png")
	m.detail_enabled = true
	m.detail_albedo = _grime_tex
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_scale = Vector3.ONE * scale
	return m


## Remplit « mats » (dictionnaire partagé des pièces) : les clés et leur rôle ne changent pas, seules
## les matières deviennent photographiques. Les teintes reprennent la couleur moyenne d'avant.
static func build(mats: Dictionary) -> void:
	# (coût en rendu logiciel : chaque carte est lue trois fois en triplanaire ; la crasse et l'occlusion
	# ne sont gardées que là où elles se voient : papiers peints et lambris ont leurs taches dans la texture)
	# plâtre peint (murs porteurs nus, embrasures) et plafonds : PaintedPlaster017 (2 m)
	var plaster := "PaintedPlaster017/PaintedPlaster017"
	mats.plaster = grime(pbr(plaster, 2.0, Color(0.8, 0.76, 0.68), 1.0, false, false, 0.9), 0.4)
	# (plafond lissé : relief de normale à 30 %, sinon il faisait crépi ou papier alu froissé en vue rasante)
	mats.ceil = pbr(plaster, 2.0, Color(0.68, 0.66, 0.61), 0.3, false, false, 0.92)
	# (peinture et faïence de la salle de bain un peu moins blanches : sous l'applique, la nuit, elle était
	# presque aussi claire qu'en plein jour)
	mats.wall_paint = grime(pbr(plaster, 2.0, Color(0.86, 0.84, 0.79), 1.0, false, false, 0.85), 0.5)
	# papiers peints : deux lés de 0,53 m par répétition (1,06 m), motifs d'avant, vieillis
	var pp := "decrepit_wallpaper/papier_peint_"
	# (teintes : couleur moyenne d'avant, crasse comprise ; elle assombrissait d'environ 15 %)
	mats.wall = _paper(pp + "mere", Color(0.75, 0.73, 0.69))
	mats.wall_floral = _paper(pp + "fleurs", Color(0.74, 0.72, 0.7))
	mats.wall_stripes = _paper(pp + "rayures", Color(0.71, 0.7, 0.67))
	mats.wall_stripes_dark = _paper(pp + "rayures", Color(0.57, 0.55, 0.52))
	# variantes sans texture de plus (même shader) : chaque pièce a sa couleur, on s'y repère mieux
	mats.wall_floral_blue = _paper(pp + "fleurs", Color(0.6, 0.66, 0.72))           # chambre d'amis
	mats.wall_olive = grime(pbr(plaster, 2.0, Color(0.46, 0.49, 0.38), 1.0, false, false, 0.85), 0.5)   # bureau
	# lambris en lames verticales vernies (stair_planks : lames de 14 cm)
	mats.wainscot = pbr("stair_planks/stair_planks", 0.7, Color(0.68, 0.72, 0.76))
	# parquet en point de Hongrie (herringbone_parquet, 3,4 m réels)
	# (rugosité constante 0,6 : la carte d'origine, très lisse, donnait un sol mouillé ; une carte de moins)
	mats.floor = pbr("herringbone_parquet/herringbone_parquet", 3.4, Color(0.88, 0.82, 0.77), 1.0, true, true, 0.6)
	(mats.floor as StandardMaterial3D).ao_light_affect = 0.35
	# bois des meubles, appuis de fenêtre, cimaises et plinthes (Wood027, éclairci)
	mats.wood = grime(pbr("Wood027/Wood027", 1.2, Color(1, 1, 1), 1.0, false))
	mats.wood_dark = grime(pbr("Wood027/Wood027", 1.2, Color(0.72, 0.7, 0.7), 1.0, false))
	# bois peint : portes, chambranles, croisées, corniches (PaintedWood009C)
	var pw := "PaintedWood009C/PaintedWood009C"
	mats.paint = grime(pbr(pw, 1.0, Color(1.0, 1.0, 0.97), 0.4, false), 1.2)
	# (portes un peu plus sombres que les boiseries : à 0,92, elles brillaient dans le noir)
	mats.door = grime(pbr(pw, 1.0, Color(0.8, 0.78, 0.72), 0.4, false), 0.8)
	# salle de bain : faïence 15 cm (Tiles133B) et damier crème et brun-rouge 20 cm (floor_tiles_06)
	mats.faience = pbr("Tiles133B/Tiles133B", 1.8, Color(0.75, 0.69, 0.66))
	mats.carrelage = pbr("floor_tiles_06/floor_tiles_06_damier", 0.8, Color(0.76, 0.73, 0.71), 1.0, true, true)
	(mats.carrelage as StandardMaterial3D).ao_light_affect = 0.35
	# moquette rouille (Carpet016, 1,7 m réels)
	mats.moquette = pbr_acg("Carpet016/Carpet016", 1.7, Color(0.51, 0.32, 0.28), 1.0, true)


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
