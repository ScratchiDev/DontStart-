class_name Builder
extends Node3D
## Outils communs pour construire les pièces de la maison : matières partagées (papier peint,
## lambris, parquet, bois, peinture…), boîtes, collisions, objets interactifs, images, et meubles
## mis à l'échelle en mètres réels : modèles réalistes Poly Haven (CC0) quand il y en a un, sinon
## Kenney (CC0). Chaque pièce hérite de ce script.

const LAYER_WORLD := 1
const LAYER_INTERACT := 4   # couche 3 : visable mais ne bloque pas le joueur

## Couches de RENDU (visibilité, numéros 1 à 20, à ne pas confondre avec les couches de collision) :
## 11 = « flux uniquement » : vu seulement par les caméras de flux qui l'acceptent (le miroir),
##      jamais par le joueur (sa caméra n'a pas cette couche) ;
## 12 = « caché des caméras » : vu par le joueur, jamais par les caméras de flux.
const LAYER_FEED_ONLY := 11
const LAYER_HIDDEN_FROM_FEEDS := 12

## Couche de COLLISION (1 à 32) des zones acoustiques (Area3D de réverbération par pièce, lot V2-SON),
## lue par la présence du joueur (V2-PRESENCE). Le rayon d'interaction (masque 5) et les autres rayons
## (couches 1 et 4) ne la voient pas.
const LAYER_ACOUSTIC := 20

static var _cache := {}
static var _grime_tex_s: Texture2D


## Bit d'une couche de rendu (1 à 20) dans un masque (layers, cull_mask).
static func layer_bit(n: int) -> int:
	return 1 << (n - 1)


## Pose les couches de rendu d'un nœud et de tous ses descendants visuels (maillages, lumières,
## décalques…). « layers » : un masque (int) ou une liste de numéros de couche, par exemple
## Builder.set_vis_layers(silhouette, [Builder.LAYER_FEED_ONLY]).
static func set_vis_layers(node: Node, layers: Variant) -> void:
	var mask := 0
	if layers is Array or layers is PackedInt32Array:
		for n in layers:
			mask |= layer_bit(int(n))
	else:
		mask = int(layers)
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = mask
	for c in node.get_children():
		set_vis_layers(c, mask)


## Range un objet de décor dans le groupe « analogique » (vieille télé, radio, radiateur : elle ne peut
## pas les prendre) ou « connecte » (les appareils Connected s'y mettent tout seuls). Prépare le Bac à sable.
static func tag(node: Node, group: String) -> Node:
	if group == "analogique" or group == "connecte":
		node.add_to_group(group)
	return node

var mats := {}
var props := {}


func _notification(what: int) -> void:
	# libérer le cache partagé en quittant (sinon Godot signale des ressources encore utilisées)
	if what == NOTIFICATION_PREDELETE and not _cache.is_empty():
		_cache = {}
		_grime_tex_s = null
	if what == NOTIFICATION_PREDELETE:
		_rug_mats = {}
		_kenney_mats = {}
		_bevel_cache = {}


# ------------------------------------------------------------------ matériaux

func _tex(file: String) -> Texture2D:
	return load("res://assets/textures/" + file)


func _triplanar(m: StandardMaterial3D, scale: float) -> StandardMaterial3D:
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


func _normal_from_height(file: String, strength: float) -> Texture2D:
	var img: Image = _tex(file).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(strength)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Crasse et usure : une texture de saleté multipliée par-dessus, projetée dans l'espace
## (pas de répétition visible d'un meuble à l'autre).
func _grimy(m: StandardMaterial3D, scale := 0.9) -> StandardMaterial3D:
	m.detail_enabled = true
	# (masque HD de V1-USURE si le remplacement a déjà eu lieu ; grime.png avant, et en rendu logiciel)
	m.detail_albedo = Surfaces.grime_texture(m) if _grime_tex_s != null else _grime_tex_s
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	m.uv2_triplanar = true
	m.uv2_world_triplanar = true
	m.uv2_scale = Vector3.ONE * scale
	return m


## Matières de la maison, créées une seule fois et partagées par toutes les pièces.
func _make_materials() -> void:
	if not _cache.is_empty():
		mats = _cache
		return
	_grime_tex_s = _tex("grime.png")
	# surfaces de la maison (plâtre, plafonds, papiers peints, lambris, parquet, carrelage, moquette,
	# bois, bois peint des portes et fenêtres) : matières PBR de scripts/surfaces.gd (agent A)
	Surfaces.build(mats)
	mats.beige = _grimy(_plain(Color(0.56, 0.52, 0.43), 0.55), 2.0)
	mats.dark = _plain(Color(0.05, 0.05, 0.055), 0.6)
	mats.metal = _plain(Color(0.55, 0.53, 0.5), 0.35, 0.8)
	mats.black_plastic = _plain(Color(0.08, 0.08, 0.08), 0.45)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.7, 0.85, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	mats.glass = glass
	var frosted := StandardMaterial3D.new()
	frosted.albedo_color = Color(0.7, 0.75, 0.8, 0.55)
	frosted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frosted.roughness = 0.9
	mats.frosted = frosted
	_cache = mats


func _plain(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


## Sanitaires Kenney (pas d'équivalent réaliste chez Poly Haven) : matière Kenney -> céramique
## émaillée, chrome ou plastique sombre (les pièces peuvent encore les reteindre avec _retint).
const SANITARY := {
	"toilet": {"carpetwhite": "ceramic", "_defaultmat": "ceramic", "metallight": "chrome", "metaldark": "dark"},
	"toiletSquare": {"carpetwhite": "ceramic", "_defaultmat": "ceramic", "metallight": "chrome", "metaldark": "dark"},
	"bathtub": {"carpetwhite": "ceramic", "metallight": "ceramic", "metaldark": "chrome"},
	"bathroomSink": {"_defaultmat": "ceramic", "metallight": "chrome", "carpetwhite": "chrome"},
	"bathroomSinkSquare": {"_defaultmat": "ceramic", "metallight": "chrome", "carpetwhite": "chrome"},
	"bathroomCabinetDrawer": {"carpetwhite": "ceramic", "metallight": "chrome", "metaldark": "chrome"},
	"bathroomCabinet": {"carpetwhite": "ceramic", "metallight": "chrome", "metaldark": "chrome"},
	"shower": {"carpetwhite": "ceramic", "metallight": "chrome", "metaldark": "chrome", "_defaultmat": "ceramic"},
	"showerRound": {"carpetwhite": "ceramic", "metallight": "chrome", "metaldark": "chrome", "_defaultmat": "ceramic"},
}


func _sanitary_mat(kind: String) -> Material:
	if _kenney_mats.has(kind):
		return _kenney_mats[kind]
	var m: StandardMaterial3D
	match kind:
		"ceramic":     # émail un peu jauni, très lisse, une crasse légère dans les creux
			m = _grimy(_plain(Color(0.8, 0.79, 0.74), 0.08), 0.6)
			m.metallic_specular = 0.65
		"chrome":
			m = _plain(Color(0.78, 0.78, 0.8), 0.14, 1.0)
		_:
			m = _plain(Color(0.06, 0.06, 0.065), 0.45)
	_kenney_mats[kind] = m
	return m


## Remplace les aplats de couleur des modèles Kenney par des matières éclairables et assombries.
func _remap(m: Material, tint: Dictionary, model_name := "") -> Material:
	var key := m.resource_name.to_lower() if m else ""
	if tint.has(key):
		return _grimy(_plain(tint[key], 0.95))
	if SANITARY.has(model_name) and (SANITARY[model_name] as Dictionary).has(key):
		return _sanitary_mat(SANITARY[model_name][key])
	match key:
		"wood":
			return mats.wood
		"wooddark":
			return mats.wood_dark
		"glass":
			return mats.glass
		"lamp":
			return _grimy(_plain(Color(0.9, 0.86, 0.74), 0.7))
		"fur":
			return _grimy(_plain(Color(0.33, 0.24, 0.17), 1.0))
		"plant":
			return _grimy(_plain(Color(0.16, 0.24, 0.13), 1.0))
		"metaldark":
			return _grimy(_plain(Color(0.12, 0.12, 0.12), 0.5, 0.4))
	var base := Color(0.5, 0.5, 0.5)
	if m is BaseMaterial3D:
		base = (m as BaseMaterial3D).albedo_color
	if key.begins_with("metal"):
		return _grimy(_plain(base * 0.8, 0.38, 0.7))
	if key.begins_with("carpet"):
		return _grimy(_plain(base.darkened(0.45), 1.0))
	return _grimy(_plain(base.darkened(0.25), 0.8))


# ------------------------------------------------------------------ outils de construction

## Boîte de « size » centrée en « pos » : chanfreinée hors rendu logiciel (box_mesh : arêtes qui accrochent
## la lumière, même boîte englobante), un BoxMesh sinon. bevel : rayon du biseau (< 0 : automatique,
## 0 : aucun, pour des boîtes qui se raccordent bord à bord). collide : collision séparée (_collider).
func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node3D = self, bevel := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size, bevel, mat)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		_collider(size, pos, parent)
	return mi


func _collider(size: Vector3, pos: Vector3, parent: Node3D = self, layer := LAYER_WORLD) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)
	return sb


func _interactable(label: String, size: Vector3, pos: Vector3, parent: Node3D = self, layer := LAYER_INTERACT, reach := 2.2) -> Interactable:
	var it := Interactable.new()
	it.label = label
	it.reach = reach
	it.collision_layer = layer
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	it.add_child(cs)
	it.position = pos
	parent.add_child(it)
	return it


func _quad(size: Vector2, pos: Vector3, mat: Material, rot_y := 0.0, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _image_mat(file: String, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/images/" + file)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _aabb_of(root: Node3D, ref: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := ref.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var box: AABB = inv * mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	if root is MeshInstance3D:
		var own: AABB = inv * root.global_transform * (root as MeshInstance3D).get_aabb()
		out = own if first else out.merge(own)
	return out


## Pose un meuble : « size » en mètres (x = largeur, y = hauteur, z = profondeur, 0 = proportionnel).
## Le pied du meuble est posé en « pos », tourné de « rot » degrés (face avant vers +z à 0°).
## Si la table PH_FOR_KENNEY a un modèle réaliste (Poly Haven, CC0) pour ce nom Kenney, c'est lui qui
## est posé (mis à l'échelle sans déformation, voir model()), sauf exception (KEEP_KENNEY, « label »,
## proportions trop éloignées de la boîte demandée). Les tapis (« rug… ») deviennent un tapis texturé.
## « ph » : "" = choix automatique, "kenney" = forcer le modèle Kenney, "<id Poly Haven>" = forcer ce modèle.
func prop(model: String, pos: Vector3, rot := 0.0, size := Vector3(0, 0, 0), solid := true, tint := {}, label := "", ph := "") -> Node3D:
	if ph != "kenney" and model.begins_with("rug") and not OS.get_cmdline_user_args().has("--kenney"):
		return _woven_rug(model, pos, rot, size, tint)
	var real := _real_for(model, size, label, ph)
	if not real.is_empty():
		var opts: Dictionary = real.duplicate()
		opts["name"] = model
		opts["label"] = label
		return self.model(real.id, pos, rot, real.get("box", size), solid, opts)
	var holder := Node3D.new()
	holder.name = model
	add_child(holder)
	var inst: Node3D = (load("res://assets/models/kenney/%s.glb" % model) as PackedScene).instantiate()
	holder.add_child(inst)
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _remap(mi.mesh.surface_get_material(i), tint, model))
	var raw := _aabb_of(inst, holder)
	var s := Vector3.ONE
	var known: Array[float] = []
	for a in 3:
		if size[a] > 0.0:
			s[a] = size[a] / maxf(raw.size[a], 0.001)
			known.append(s[a])
	if not known.is_empty():
		var avg := 0.0
		for k in known:
			avg += k
		avg /= known.size()
		for a in 3:
			if size[a] <= 0.0:
				s[a] = avg
	inst.scale = s
	var box := _aabb_of(inst, holder)
	inst.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.position = pos
	holder.rotation_degrees.y = rot
	box = _aabb_of(inst, holder)
	holder.set_meta("size", box.size)
	if label != "":
		var it := _interactable(label, box.size, Vector3(0, box.size.y / 2.0, 0), holder, LAYER_WORLD | LAYER_INTERACT)
		holder.set_meta("interactable", it)
	elif solid:
		_collider(box.size * Vector3(0.96, 1.0, 0.96), Vector3(0, box.size.y / 2.0, 0), holder)
	props[model] = holder
	if Game.autotest:
		print("prop %-22s brut %s -> %s" % [model, _fmt(raw.size), _fmt(box.size)])
	return holder


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


# ------------------------------------------------------------------ modèles réalistes (Poly Haven, CC0)

const PH_PATH := "res://assets/models/polyhaven/%s/%s.gltf"

## Nom Kenney -> modèle Poly Haven qui le remplace dans prop(). Clés de chaque entrée :
##   id    : identifiant Poly Haven (dossier assets/models/polyhaven/<id>/, voir tools/assets_cc0.py) ;
##   yaw   : rotation (degrés) ajoutée au modèle pour que son avant regarde +z, comme le Kenney ;
##   fit   : "box" (défaut : échelle uniforme, tient dans la boîte demandée), "xz" (l'empreinte
##           seulement, hauteur libre : lits), "y" (hauteur exacte : un dessus qui porte des objets),
##           "real" (taille réelle du modèle, sans mise à l'échelle : chaises) ;
##   fill, over : chaque côté demandé doit être rempli entre « fill » (défaut 0,7) et « over » (défaut
##           1,1) ; sinon prop() garde le Kenney (mieux vaut un Kenney qu'un meuble nain ou géant) ;
##   anchor : "back" : si le modèle est plus profond que la boîte, son dos reste au dos de la boîte et
##           il déborde vers l'avant (une chaise contre un mur avance un peu dans la pièce) ;
##   close : referme les portes et tiroirs entrouverts du modèle ;
##   cover : lits : [haut du matelas, marge en x, début z, fin z] en fractions de la boîte posée →
##           boîte invisible « cover » (room.gd, gp.gd y posent leur couette, comme sur le Kenney) ;
##   tint  : couleur multipliée à l'albédo (un modèle trop neuf, trop clair pour la maison) ;
##   gi    : true pour que le modèle compte dans la cuisson VoxelGI (défaut : non, voir model()) ;
##   stretch : true : échelle par axe (meubles à faces planes : métal, étagères, caisses) : chaque côté
##           demandé est rempli, entre STRETCH_MIN et STRETCH_MAX fois l'échelle de la hauteur ; refusé pour
##           le bois sculpté (Gothic*, Classic*), qui reste à l'échelle uniforme.
const PH_FOR_KENNEY := {
	"chair": {"id": "painted_wooden_chair_01", "fit": "real", "over": 1.35, "anchor": "back", "tint": Color(0.74, 0.7, 0.62)},
	"chairDesk": {"id": "dining_chair_02", "fit": "real", "over": 1.3, "anchor": "back"},
	"table": {"id": "wooden_table_02", "fit": "y"},
	"cabinetBedDrawer": {"id": "ClassicNightstand_01", "fit": "y"},
	"cabinetBedDrawerTable": {"id": "painted_wooden_nightstand", "fit": "y", "close": true},
	"sideTableDrawers": {"id": "GothicCommode_01", "fit": "y", "fill": 0.75, "close": true},
	"televisionVintage": {"id": "Television_01"},
	"lampSquareCeiling": {"id": "Chandelier_02"},
	"lampRoundTable": {"id": "desk_lamp_arm_01", "tint": Color(0.8, 0.8, 0.8)},
	"cardboardBoxClosed": {"id": "cardboard_box_01", "yaw": 90.0, "fit": "real", "over": 1.3},
	"plantSmall1": {"id": "potted_plant_04"},
	"plantSmall2": {"id": "potted_plant_04"},
	"bedDouble": {"id": "GothicBed_01", "fit": "xz", "cover": [0.29, 0.06, 0.08, 0.9]},
}

## Réglages par défaut de model() pour des modèles du catalogue (assets/models/polyhaven/), vérifiés dans
## tests/galerie_modeles.tscn : ce que model() applique quand l'appel ne le précise pas.
const PH_DEFAULTS := {
	"standing_picture_frame_01": {"yaw": -90.0},    # la photo regarde +x dans le glTF
	# teintes : celles de PH_FOR_KENNEY, pour toutes les copies (la chaise peinte, la lampe d'architecte) ;
	# la table en pin (orange vif) prend le ton du noyer et du chêne de la maison
	"painted_wooden_chair_01": {"tint": Color(0.74, 0.7, 0.62)},
	"desk_lamp_arm_01": {"tint": Color(0.8, 0.8, 0.8)},
	"wooden_table_02": {"tint": Color(0.6, 0.47, 0.38)},
	"GothicCabinet_01": {"close": true},
	"painted_wooden_cabinet": {"close": true},
	"painted_wooden_cabinet_02": {"close": true},
	"WoodenTable_03": {"close": true},
	"GothicCommode_01": {"close": true},
	"painted_wooden_nightstand": {"close": true},
	# caisses aux faces planes (lot V1-ASSETS) : mises à la taille demandée, à ±30 % près
	"wooden_crate_01": {"stretch": true},
	"plastic_crate_01": {"stretch": true},
}

## Appels qui gardent le modèle Kenney (« <script de la pièce>:<nom Kenney> ») : le script de la pièce
## lit des nœuds ou des matières du Kenney, ou pose des objets à des hauteurs réglées pour lui.
## (Les objets interactifs, appelés avec un « label », gardent toujours le Kenney.)
const KEEP_KENNEY := {
	"amis:bedDouble": "la bâche est modelée sur des hauteurs fixes (matelas 0,445, tête 0,645)",
	"gp:bedDouble": "couette générée et forme d'Henriette réglées sur le Kenney (pied du lit, matelas)",
	"amis:televisionVintage": "l'écran (Device) est placé en coordonnées du modèle Kenney",
	"bureau:lampSquareCeiling": "l'abat-jour (matière Kenney « lamp ») s'allume avec l'ampoule",
}

static var _ph_scenes := {}        # id -> PackedScene (gardée : les copies suivantes ne relisent pas le .scn)
static var _ph_raw_cache := {}     # « id|yaw|close » -> AABB brute (après yaw, avant échelle)
static var _kenney_raw := {}       # nom Kenney -> AABB brute du .glb
## Boîtes brutes des .glb Kenney de PH_FOR_KENNEY (mesurées une fois, outil _aabb_in) : _kenney_box() n'a
## pas à charger le Kenney qu'il remplace (en rendu logiciel, ce chargement coûtait jusqu'à 0,3 s).
const KENNEY_RAW := {
	"chair": AABB(Vector3(0.0, 0.0, -0.2), Vector3(0.2, 0.47, 0.2)),
	"chairDesk": AABB(Vector3(0.0, 0.0, -0.314299), Vector3(0.33495, 0.6076, 0.314299)),
	"table": AABB(Vector3(0.0, 0.0, -0.447373), Vector3(0.841488, 0.326734, 0.447373)),
	"cabinetBedDrawer": AABB(Vector3(-0.01, 0.0, -0.205), Vector3(0.266, 0.2632, 0.2173)),
	"cabinetBedDrawerTable": AABB(Vector3(-0.01, 0.0, -0.205), Vector3(0.266, 0.2632, 0.2173)),
	"sideTableDrawers": AABB(Vector3(-0.01, 0.0, -0.21), Vector3(0.534475, 0.384408, 0.2223)),
	"televisionVintage": AABB(Vector3(0.0, 0.0, -0.27), Vector3(0.41, 0.27, 0.27)),
	"lampSquareCeiling": AABB(Vector3(0.0, 0.0, -0.12), Vector3(0.12, 0.23, 0.12)),
	"lampRoundTable": AABB(Vector3(-0.01602, 0.0, -0.14778), Vector3(0.152039, 0.31425, 0.17556)),
	"cardboardBoxClosed": AABB(Vector3(0.0, 0.0, -0.2125), Vector3(0.2125, 0.281, 0.2125)),
	"plantSmall1": AABB(Vector3(-0.04733, 0.0, -0.04733), Vector3(0.094661, 0.14, 0.094661)),
	"plantSmall2": AABB(Vector3(-0.04733, 0.0, -0.04733), Vector3(0.094661, 0.14, 0.094661)),
	"bedDouble": AABB(Vector3(0.0, 0.0, -1.125), Vector3(0.956, 0.375, 1.125)),
}
static var _rug_mats := {}         # couleur (_rug_mat), « motif:<motif> », « franges:<motif> » -> matière
static var _kenney_mats := {}      # matières des sanitaires Kenney (céramique, chrome)
static var _all_kenney := -1       # 1 : option « --kenney » (aucun modèle Poly Haven ni tapis tissé)


## Nom du script de la pièce qui construit (« room », « amis », « bureau »…), pour KEEP_KENNEY.
func _room_key() -> String:
	var s := get_script() as Script
	return s.resource_path.get_file().get_basename() if s else ""


## L'entrée PH_FOR_KENNEY à utiliser pour ce prop(), ou {} pour garder le Kenney.
func _real_for(model: String, size: Vector3, label: String, ph: String) -> Dictionary:
	if ph == "kenney" or (label != "" and ph == ""):
		return {}       # objet interactif : sa boîte d'interaction suit le modèle Kenney, on n'y touche pas
	if _kenney_all():
		return {}       # « -- --kenney » : tout en Kenney, pour comparer (avant / après)
	var entry: Dictionary = (PH_FOR_KENNEY.get(model, {}) as Dictionary).duplicate()
	if ph != "":
		if entry.get("id", "") != ph:
			entry = {}
		entry["id"] = ph
	elif entry.is_empty() or KEEP_KENNEY.has("%s:%s" % [_room_key(), model]):
		return {}
	if not ResourceLoader.exists(PH_PATH % [entry.id, entry.id]):
		return {}
	if entry.get("fit", "box") in ["y", "real"]:
		# la boîte complète du Kenney (côtés à 0 compris) : hauteur exacte d'un dessus qui porte des
		# objets (« y ») ; place réellement libre autour d'un meuble à sa taille réelle (« real »)
		entry["box"] = _kenney_box(model, size)
	if ph == "":
		var why := _fit_problem(entry, entry.get("box", size))
		if why != "":
			if Game.autotest:
				print("prop %-22s garde le Kenney (%s : %s)" % [model, entry.id, why])
			return {}
	return entry


## Taille qu'aurait le meuble Kenney posé par prop() avec cette « size » (les côtés à 0 suivent les autres).
func _kenney_box(model_name: String, size: Vector3) -> Vector3:
	if not _kenney_raw.has(model_name) and KENNEY_RAW.has(model_name):
		_kenney_raw[model_name] = KENNEY_RAW[model_name]
	if not _kenney_raw.has(model_name):
		var inst := (load("res://assets/models/kenney/%s.glb" % model_name) as PackedScene).instantiate()
		_kenney_raw[model_name] = _aabb_in(inst, Transform3D())
		inst.free()
	var raw: AABB = _kenney_raw[model_name]
	var s := Vector3.ONE
	var known := 0
	var avg := 0.0
	for a in 3:
		if size[a] > 0.0:
			s[a] = size[a] / maxf(raw.size[a], 0.001)
			avg += s[a]
			known += 1
	if known > 0:
		for a in 3:
			if size[a] <= 0.0:
				s[a] = avg / known
	return raw.size * s


## Boîte d'un nœud et de ses maillages, dans le repère donné par xf (transformée du nœud dans ce
## repère). Ne demande pas que le nœud soit dans l'arbre.
func _aabb_in(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = xf * (node as MeshInstance3D).get_aabb()
		first = false
	for c in node.get_children():
		if not (c is Node3D):
			continue
		var b := _aabb_in(c, xf * (c as Node3D).transform)
		if b.size == Vector3.ZERO and b.position == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out


## La scène du modèle, gardée après le premier chargement (les copies suivantes ne relisent pas le .scn).
static func _ph_scene(ph_id: String) -> PackedScene:
	if not _ph_scenes.has(ph_id):
		if _detail_loading.has(ph_id):
			# (chargement lancé en arrière-plan par detail() ou preload_details() : on l'attend)
			_ph_scenes[ph_id] = ResourceLoader.load_threaded_get(PH_PATH % [ph_id, ph_id]) as PackedScene
			_detail_loading.erase(ph_id)
		else:
			_ph_scenes[ph_id] = load(PH_PATH % [ph_id, ph_id]) as PackedScene
	return _ph_scenes[ph_id]


## Charge le modèle, corrige ses matières (une fois par modèle) et referme portes et tiroirs.
func _ph_instance(ph_id: String, opts: Dictionary) -> Node3D:
	var inst := _ph_scene(ph_id).instantiate() as Node3D
	_fix_ph_materials(inst, opts.get("tint", Color.WHITE), ph_id)
	if opts.get("close", false):
		for n in inst.find_children("*", "Node3D", true, false):
			var nm := String(n.name).to_lower()
			if nm.contains("door") or nm.contains("drawer"):
				(n as Node3D).rotation = Vector3.ZERO
	return inst


## Les glTF de Poly Haven sont exportés « double face » : Godot en fait des matières sans élagage des
## faces arrière (deux fois plus de pixels, et une variante de shader qui peut bloquer llvmpipe). On
## remet l'élagage ; le découpage alpha (feuillages) devient opaque, le verre (fondu alpha) reste.
## Les matières sont partagées par toutes les copies du modèle : corrigées une seule fois (méta « ph_ok »).
## Le verre se reconnaît à « glass » ou « lens » dans le nom de la matière, l'id du modèle retiré (sinon
## la matière principale « magnifying_glass_01 » de la loupe sortait toute en verre).
func _fix_ph_materials(inst: Node, tint: Color, ph_id := "") -> void:
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null or m.has_meta("ph_ok"):
				continue
			m.set_meta("ph_ok", true)
			m.cull_mode = BaseMaterial3D.CULL_BACK
			if m.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]:
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			elif m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA    # « BLEND » du glTF : fondu simple
			var mat_name := m.resource_name.to_lower()
			if not ph_id.is_empty():
				mat_name = mat_name.trim_prefix(ph_id.to_lower())
			if mat_name.contains("glass") or mat_name.contains("lens"):
				# vitres des horloges, cadres, lanternes : Blender les rend transparentes par transmission,
				# que Godot ignore (le verre sortait opaque, de la couleur de la texture) : un verre teinté
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_texture = null
				m.albedo_color = Color(0.82, 0.86, 0.88, 0.14)
				m.metallic = 0.0
				m.metallic_texture = null
				m.roughness = 0.06
				m.roughness_texture = null
				m.metallic_specular = 0.8
			if m.albedo_texture == null and m.normal_texture == null and m.roughness_texture == null and m.metallic_texture == null:
				# sans texture (verres, métaux unis) : la même variante de shader que les matières unies des
				# pièces (déjà compilée ; chaque variante neuve coûte en rendu logiciel au premier chargement)
				m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			else:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if tint != Color.WHITE:
			# la teinte est propre à cette copie (les matières du glTF sont partagées : teintées une fois,
			# elles imposaient la teinte de la première copie à toutes les autres)
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
				if m:
					mi.set_surface_override_material(i, _ph_tinted(m, tint))


## Copie teintée d'une matière de modèle (une par matière et par teinte, partagée par les copies).
static var _ph_tints := {}


static func _ph_tinted(m: BaseMaterial3D, tint: Color) -> BaseMaterial3D:
	var key := "%d|%s" % [m.get_instance_id(), tint.to_html()]
	if not _ph_tints.has(key):
		var d := m.duplicate() as BaseMaterial3D
		d.albedo_color = m.albedo_color * tint
		_ph_tints[key] = d
	return _ph_tints[key]


## Boîte brute d'un modèle (après « yaw », avant mise à l'échelle), mise en cache.
func _ph_raw(entry: Dictionary) -> AABB:
	var key := "%s|%s|%s" % [entry.id, entry.get("yaw", 0.0), entry.get("close", false)]
	if _ph_raw_cache.has(key):
		return _ph_raw_cache[key]
	var inst := _ph_instance(entry.id, entry)
	var raw := _aabb_in(inst, Transform3D(Basis(Vector3.UP, deg_to_rad(entry.get("yaw", 0.0))), Vector3.ZERO))
	inst.free()
	_ph_raw_cache[key] = raw
	return raw


## Échelle uniforme qui fait tenir la boîte brute « raw » dans « size » selon le mode « fit ».
static func _fit_scale(entry: Dictionary, raw: AABB, size: Vector3) -> float:
	var mode: String = entry.get("fit", "box")
	if mode == "real":
		return 1.0
	if mode == "y" and size.y > 0.0:
		return size.y / maxf(raw.size.y, 0.001)
	var axes := [0, 2] if mode == "xz" else [0, 1, 2]
	var s := INF
	for a in axes:
		if size[a] > 0.0:
			s = minf(s, size[a] / maxf(raw.size[a], 0.001))
	if s == INF:
		s = size.y / maxf(raw.size.y, 0.001) if size.y > 0.0 else 1.0
	return s


## Échelle par axe, dans le repère de la pièce (après « yaw ») : celle de _fit_scale sur les trois axes, sauf
## avec « stretch » (_can_stretch) : la hauteur à son échelle, et chaque côté demandé rempli exactement, dans
## la limite de STRETCH_MIN à STRETCH_MAX fois l'échelle de la hauteur.
const STRETCH_MIN := 0.7
const STRETCH_MAX := 1.3


static func _fit_scale3(entry: Dictionary, raw: AABB, size: Vector3) -> Vector3:
	var s := _fit_scale(entry, raw, size)
	if not _can_stretch(entry):
		return Vector3.ONE * s
	var sy := size.y / maxf(raw.size.y, 0.001) if size.y > 0.0 else s
	var out := Vector3.ONE * sy
	for a in [0, 2]:
		if size[a] > 0.0:
			out[a] = clampf(size[a] / maxf(raw.size[a], 0.001), sy * STRETCH_MIN, sy * STRETCH_MAX)
	return out


## « stretch » demandé, et pas pour du bois sculpté (Gothic*, Classic* : la déformation se verrait).
static func _can_stretch(entry: Dictionary) -> bool:
	if not entry.get("stretch", false):
		return false
	var id := String(entry.get("id", ""))
	return not (id.begins_with("Gothic") or id.begins_with("Classic"))


## "" si le modèle, mis à l'échelle, remplit assez la boîte demandée (chaque axe, échelle par axe avec
## « stretch ») ; sinon la raison.
func _fit_problem(entry: Dictionary, size: Vector3) -> String:
	var raw := _ph_raw(entry)
	var fitted := raw.size * _fit_scale3(entry, raw, size)
	var fill: float = entry.get("fill", 0.7)
	var over: float = entry.get("over", 1.1)
	for a in 3:
		if size[a] <= 0.0 or (a == 1 and entry.get("fit", "box") == "xz"):
			continue
		var r := fitted[a] / size[a]
		if r < fill - 0.001:
			return "%s rempli à %d %%" % ["xyz"[a], roundi(r * 100.0)]
		if r > over + 0.001:
			return "%s déborde de %d %%" % ["xyz"[a], roundi(r * 100.0) - 100]
	return ""


## Pose un modèle réaliste Poly Haven (CC0) : mis à l'échelle UNIFORMÉMENT pour tenir dans « fit_size »
## (mètres, x = largeur, y = hauteur, z = profondeur ; 0 = libre ; tout à 0 = taille réelle), pied au
## sol en « pos », centré sur son empreinte, tourné de « rot_deg » degrés (avant vers +z à 0°).
## solid : collision en boîte (la boîte du modèle posé). opts : les clés de PH_FOR_KENNEY (yaw, fit,
## close, cover, tint, stretch), plus « name » (nom du nœud, et clé dans « props »), « label » (objet
## interactif, comme prop()), « parent » (nœud parent, défaut : la pièce).
## Le nœud rendu a les métas « size » (taille posée) et « ph_id ». Le modèle doit avoir été téléchargé :
##   python3 -I godot/tools/assets_cc0.py model <id> --godot <binaire Godot>
func model(ph_id: String, pos: Vector3, rot_deg := 0.0, fit_size := Vector3.ZERO, solid := true, opts := {}) -> Node3D:
	var entry: Dictionary = (PH_DEFAULTS.get(ph_id, {}) as Dictionary).merged(opts, true)
	entry["id"] = ph_id
	var holder := Node3D.new()
	holder.name = opts.get("name", ph_id)
	var parent: Node3D = opts.get("parent", self)
	parent.add_child(holder)
	var inst := _ph_instance(ph_id, entry)
	inst.rotation_degrees.y = entry.get("yaw", 0.0)
	holder.add_child(inst)
	if not entry.get("gi", false):
		# hors de la cuisson VoxelGI (des milliers de triangles pour une ombre de rebond invisible) : le
		# modèle reçoit quand même l'éclairage indirect de la pièce
		for g in inst.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var raw := _ph_raw(entry)
	var s3 := _fit_scale3(entry, raw, fit_size)
	if s3.x == s3.y and s3.y == s3.z:
		inst.scale = Vector3.ONE * s3.y
	else:
		# échelle par axe dans le repère de la pièce, appliquée après la rotation « yaw » du modèle
		inst.transform.basis = Basis.from_scale(s3) * Basis(Vector3.UP, deg_to_rad(entry.get("yaw", 0.0)))
	var box := _aabb_in(inst, inst.transform)
	inst.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	if entry.get("anchor", "") == "back" and fit_size.z > 0.0 and box.size.z > fit_size.z:
		inst.position.z += (box.size.z - fit_size.z) / 2.0
	box = _aabb_in(inst, inst.transform)
	holder.position = pos
	holder.rotation_degrees.y = rot_deg
	holder.set_meta("size", box.size)
	holder.set_meta("ph_id", ph_id)
	if entry.has("cover"):
		_bed_cover(holder, box, entry.cover)
	var label: String = opts.get("label", "")
	if label != "":
		var it := _interactable(label, box.size, box.get_center(), holder, LAYER_WORLD | LAYER_INTERACT)
		holder.set_meta("interactable", it)
	elif solid:
		_collider(box.size * Vector3(0.96, 1.0, 0.96), box.get_center(), holder)
	if opts.get("_detail", false):
		return holder         # objet de détail (detail()) : jamais dans props
	props[opts.get("name", ph_id)] = holder
	if Game.autotest:
		var sc := "x%.3f" % s3.y if s3.x == s3.y and s3.y == s3.z else "x(%.3f, %.3f, %.3f)" % [s3.x, s3.y, s3.z]
		print("prop %-22s ph:%s %s -> %s" % [opts.get("name", ph_id), ph_id, sc, _fmt(box.size)])
	return holder


## Lit réaliste : boîte invisible « cover » posée sur le matelas (fractions de la boîte du lit).
func _bed_cover(holder: Node3D, box: AABB, c: Array) -> void:
	var top := box.position.y + box.size.y * float(c[0])
	var mx := box.size.x * float(c[1])
	var z0 := box.position.z + box.size.z * float(c[2])
	var z1 := box.position.z + box.size.z * float(c[3])
	var mi := MeshInstance3D.new()
	mi.name = "cover"
	var bm := BoxMesh.new()
	bm.size = Vector3(box.size.x - 2.0 * mx, 0.02, z1 - z0)
	mi.mesh = bm
	mi.position = Vector3(box.get_center().x, top - 0.01, (z0 + z1) / 2.0)
	mi.visible = false
	holder.add_child(mi)


# ------------------------------------------------------------------ tapis

const RUG_TEX := "res://assets/textures/Fabric045/Fabric045_%s.jpg"
## Motifs des tapis (tools/make_rugs.py) : rug_<motif>.png, RGB = laines, A = rugosité (usure comprise).
const RUG_DIR := "res://assets/textures/rugs/"
## Motif par script de pièce (prop() d'un « rug… » sans tint["design"]).
const RUG_ROOM_DESIGN := {"room": "oriental", "gp": "frise", "bureau": "geometrique", "sdb": "bain"}
## Teinte des franges par motif (coton écru, plus ou moins jauni).
const RUG_FRINGE_TINT := {"oriental": Color(1.0, 0.98, 0.94), "frise": Color(0.96, 0.92, 0.86),
	"geometrique": Color(0.86, 0.78, 0.66), "bain": Color(0.9, 0.92, 0.92)}
## Profil du tapis (repère du tapis, posé 4 mm au-dessus du sol par les pièces) : dessus du velours à
## RUG_TOP (±0,5 mm d'ondulations), chant arrondi qui descend jusqu'au sol (RUG_FOOT : 0,5 mm au-dessus
## du sol) sur RUG_EDGE, coin relevé d'au plus RUG_LIFT. Hauteur totale au plus 0,004 + 0,008 + 0,0075 =
## 1,95 cm < Door.LEAF_GAP (le battant passe au-dessus : autotest B1) et < 8 cm (HouseRoom._scan_rugs).
const RUG_TOP := 0.0075
const RUG_TOP_BAIN := 0.009
const RUG_FOOT := -0.0035
const RUG_EDGE := 0.008
const RUG_LIFT := 0.0075
const RUG_LIFT_R := 0.22
const RUG_FRINGE := 0.05
const RUG_WEAVE := 0.3                 # une répétition du tissage de Fabric045 tous les 30 cm (UV2)
## Couleur moyenne de chaque motif : la matière la porte le temps que son motif se charge.
const RUG_AVERAGE := {"oriental": Color(0.33, 0.13, 0.13), "frise": Color(0.42, 0.29, 0.25),
	"geometrique": Color(0.33, 0.2, 0.1), "bain": Color(0.45, 0.53, 0.55)}
static var _flat_normal_tex: ImageTexture
static var _rug_tex_wait := {}         # chemin d'un motif -> matières qui l'attendent (chargement en arrière-plan)


## Vrai tapis à la place du tapis Kenney (« rug… ») : un seul maillage (rug_mesh) : le velours, champ et
## bordure du motif, bombé de 7,5 mm ; un chant arrondi de 8 mm qui descend jusqu'au sol ; des franges en
## cartes découpées sur les petits côtés (tapis rectangulaires) ; un coin un peu relevé (au plus 7,5 mm,
## jamais à moins de 0,35 m d'un battant de porte, et seulement si le tapis est hors de toute zone de
## battant). En rendu allégé (soft_render) : ni franges ni tissage (le motif seul, en UV : moins cher que
## l'ancienne laine triplanaire, et l'empreinte au sol de la 0.3.3). Motif : tint["design"] s'il est donné (« oriental », « frise », « geometrique », « bain »),
## sinon celui de la pièce (RUG_ROOM_DESIGN), sinon « bain » (rond) ou « oriental ». Sans le motif sur le
## disque : l'ancien tapis teint par tint["carpet"] et tint["carpetdarker"].
## Nom du nœud, position, rotation, méta « size » (largeur, épaisseur, profondeur, franges non comprises)
## et props[nom] : comme avant (HouseRoom._scan_rugs, autotest B1).
func _woven_rug(model_name: String, pos: Vector3, rot: float, size: Vector3, tint: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = model_name
	add_child(holder)
	holder.position = pos
	holder.rotation_degrees.y = rot
	var w := size.x if size.x > 0.0 else 2.0
	var d := size.z if size.z > 0.0 else (w if model_name == "rugRound" else w * 0.65)
	var round_ := model_name == "rugRound"
	var design: String = tint.get("design", "")
	if design == "":
		design = RUG_ROOM_DESIGN.get(_room_key(), "bain" if round_ else "oriental")
	var mat := _rug_pattern_mat(design)
	if mat == null:
		_flat_rug(holder, w, d, round_, tint)
	else:
		var lift := Vector3.ZERO if round_ else _rug_lift(holder, w, d, model_name)
		var mi := MeshInstance3D.new()
		mi.name = "tapis"
		# (rendu allégé : ni franges ni tissage, rien de plus à dessiner que l'ancien tapis)
		var fringe := 0.0 if round_ or soft_render() else RUG_FRINGE
		var mesh := rug_mesh(w, d, round_, RUG_TOP_BAIN if round_ else RUG_TOP, lift, fringe)
		mesh.surface_set_material(0, mat)
		if mesh.get_surface_count() > 1:
			mesh.surface_set_material(1, _rug_fringe_mat(design))
		mi.mesh = mesh
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		holder.add_child(mi)
	holder.set_meta("size", Vector3(w, RUG_TOP, d))
	holder.set_meta("design", design)
	props[model_name] = holder
	return holder


## L'ancien tapis (sans motif) : bordure et champ teints, en boîtes.
func _flat_rug(holder: Node3D, w: float, d: float, round_: bool, tint: Dictionary) -> void:
	var field: Color = tint.get("carpet", Color(0.42, 0.2, 0.18))
	var border: Color = tint.get("carpetdarker", field.darkened(0.45))
	var inset := clampf(minf(w, d) * 0.07, 0.05, 0.11)
	for k in 2:
		var hh := 0.007 if k == 0 else 0.0085
		var mesh: Mesh
		if round_:
			var cm := CylinderMesh.new()
			cm.top_radius = w / 2.0 - (0.0 if k == 0 else inset)
			cm.bottom_radius = cm.top_radius
			cm.height = hh
			cm.radial_segments = 56
			cm.rings = 1
			mesh = cm
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3(w - (0.0 if k == 0 else 2.0 * inset), hh, d - (0.0 if k == 0 else 2.0 * inset))
			mesh = bm
		var mi := MeshInstance3D.new()
		mi.name = "bordure" if k == 0 else "champ"
		mi.mesh = mesh
		mi.material_override = _rug_mat(border if k == 0 else field)
		mi.position.y = hh / 2.0
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		holder.add_child(mi)


## Coin relevé d'un tapis rectangulaire : Vector3(x, z, hauteur) dans le repère du tapis, ou zéro. Le coin
## est choisi sans tirage (hachage du nom de la pièce et du tapis), parmi ceux à plus de 0,35 m de toute
## zone de battant (HouseData.F1_DOORS, comme l'autotest B1) ; aucun si le tapis touche une de ces zones.
func _rug_lift(holder: Node3D, w: float, d: float, model_name: String) -> Vector3:
	var xf := holder.global_transform if holder.is_inside_tree() else holder.transform
	var zones := _door_zones()
	var foot := AABB()
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lc := Vector3(sx * (w / 2.0 + RUG_FRINGE), 0.0, sz * (d / 2.0 + RUG_FRINGE))
			var g: Vector3 = xf * lc
			foot = AABB(g, Vector3.ZERO) if corners.is_empty() else foot.expand(g)
			corners.append(Vector3(sx * w / 2.0, 0.0, sz * d / 2.0))
	var frect := Rect2(foot.position.x, foot.position.z, foot.size.x, foot.size.z)
	for z in zones:
		if frect.intersects(z):
			return Vector3.ZERO
	var start := absi(hash(_room_key() + ":" + model_name)) % 4
	for k in 4:
		var c: Vector3 = corners[(start + k) % 4]
		var g: Vector3 = xf * c
		var ok := true
		for z in zones:
			if (z as Rect2).grow(0.35).has_point(Vector2(g.x, g.z)):
				ok = false
				break
		if ok:
			return Vector3(c.x, c.z, RUG_LIFT)
	return Vector3.ZERO


## Zones balayées par les battants des portes de l'étage, au sol (comme Autotest.door_zone : 0,95 m depuis
## la face du mur, 0,5 m de part et d'autre de l'axe de la porte, du côté où elle s'ouvre).
static func _door_zones() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for d in HouseData.F1_DOORS:
		var sr: Array = HouseData.F1_ROOMS[d.swing].rect
		var side := -1.0 if (float(sr[0]) + float(sr[1])) / 2.0 < float(d.at) else 1.0
		var face: float = float(d.at) + side * HouseData.WALL / 2.0
		out.append(Rect2(face if side > 0.0 else face - 0.95, float(d.c) - 0.5, 0.95, 1.0))
	return out


## Maillage d'un tapis, dans son repère (centre au sol du tapis, x : largeur w, z : profondeur d) :
##   surface 0 : le velours (dessus en champ de hauteurs, chant arrondi jusqu'au sol, et dessous si un
##               coin se relève) ; UV = le motif (0 à 1 sur tout le tapis), UV2 = le tissage (m / RUG_WEAVE) ;
##   surface 1 : les franges (si fringe > 0 et tapis rectangulaire), sur les deux petits côtés : cartes à
##               plat, u = 10 cm de bord par répétition, v = 0 au tapis, 1 à la pointe.
## lift = Vector3(x, z, hauteur) du coin relevé (zéro : aucun). top : hauteur du velours.
static func rug_mesh(w: float, d: float, round_: bool, top := RUG_TOP, lift := Vector3.ZERO, fringe := RUG_FRINGE) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if round_:
		_rug_round_surface(mesh, w / 2.0, top)
		return mesh
	var hw := w / 2.0
	var hd := d / 2.0
	var xs := _rug_axis(hw, 0.16, lift.x if lift.z > 0.0 else INF)
	var zs := _rug_axis(hd, 0.16, lift.y if lift.z > 0.0 else INF)
	var nx := xs.size()
	var nz := zs.size()
	var ys := PackedFloat32Array()
	ys.resize(nx * nz)
	for j in nz:
		for i in nx:
			ys[j * nx + i] = _rug_height(xs[i], zs[j], hw, hd, top) + _rug_lift_at(xs[i], zs[j], lift)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in nz:
		for i in nx:
			var y := ys[j * nx + i]
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, nx - 1)
			var j0 := maxi(j - 1, 0)
			var j1 := mini(j + 1, nz - 1)
			var dx := (ys[j * nx + i1] - ys[j * nx + i0]) / (xs[i1] - xs[i0])
			var dz := (ys[j1 * nx + i] - ys[j0 * nx + i]) / (zs[j1] - zs[j0])
			var n := Vector3(-dx, 1.0, -dz).normalized()
			var t := Vector3(1.0, dx, 0.0)
			t = (t - n * n.dot(t)).normalized()
			verts.append(Vector3(xs[i], y, zs[j]))
			norms.append(n)
			tans.append_array([t.x, t.y, t.z, 1.0])
			uvs.append(Vector2((xs[i] + hw) / w, (zs[j] + hd) / d))
			uv2.append(Vector2(xs[i], zs[j]) / RUG_WEAVE)
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx + 1, a, a + nx + 1, a + nx])
	if lift.z > 0.0:
		# dessous, seulement sous le coin relevé (ailleurs il est contre le sol) : à RUG_FOOT, relevé comme
		# le dessus ; ses bords libres restent sous le tapis
		var i0 := nx
		var i1 := -1
		var j0 := nz
		var j1 := -1
		for i in nx:
			if absf(xs[i] - lift.x) < RUG_LIFT_R + 0.05:
				i0 = mini(i0, i)
				i1 = maxi(i1, i)
		for j in nz:
			if absf(zs[j] - lift.y) < RUG_LIFT_R + 0.05:
				j0 = mini(j0, j)
				j1 = maxi(j1, j)
		var bw := i1 - i0 + 1
		var base := verts.size()
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				verts.append(Vector3(xs[i], RUG_FOOT + _rug_lift_at(xs[i], zs[j], lift), zs[j]))
				norms.append(Vector3.DOWN)
				tans.append_array([1.0, 0.0, 0.0, -1.0])
				uvs.append(Vector2((xs[i] + hw) / w, (zs[j] + hd) / d))
				uv2.append(Vector2(xs[i], zs[j]) / RUG_WEAVE)
		for j in j1 - j0:
			for i in bw - 1:
				var a := base + j * bw + i
				idx.append_array([a, a + bw + 1, a + 1, a, a + bw, a + bw + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if fringe > 0.0:
		_rug_fringes(mesh, hw, hd, fringe, lift)
	return mesh


## Coordonnées d'un axe du tapis : les trois anneaux du chant (2,5 ; 5,5 et 8 mm du bord) de chaque côté,
## un pas d'environ « step » au milieu, et des lignes de plus près du coin relevé (à « refine »).
static func _rug_axis(half: float, step: float, refine: float) -> PackedFloat32Array:
	var xs := [-half, -half + 0.0025, -half + 0.0055, -half + RUG_EDGE, half - RUG_EDGE, half - 0.0055, half - 0.0025, half]
	var inner := 2.0 * (half - RUG_EDGE)
	var n := maxi(1, ceili(inner / step))
	for i in range(1, n):
		xs.append(-half + RUG_EDGE + inner * i / n)
	if refine != INF:
		var sg := signf(refine)
		for o in [0.035, 0.07, 0.11, 0.16, 0.22, 0.29]:
			xs.append(sg * (half - o))
	xs.sort()
	var out := PackedFloat32Array()
	for x in xs:
		var edge_ring := absf(absf(x) - half) <= RUG_EDGE + 0.0001
		if out.is_empty() or edge_ring or x - out[out.size() - 1] > 0.012:
			out.append(x)
		elif absf(absf(out[out.size() - 1]) - half) > RUG_EDGE + 0.0001:
			out[out.size() - 1] = (out[out.size() - 1] + x) / 2.0
	return out


## Hauteur du velours en (x, z) : chant arrondi près du bord, ondulations très douces au milieu.
static func _rug_height(x: float, z: float, hw: float, hd: float, top: float) -> float:
	var e := minf(minf(x + hw, hw - x), minf(z + hd, hd - z))
	return _rug_profile(e, top) + _rug_wave(x, z) * clampf((e - 0.01) / 0.07, 0.0, 1.0)


## Chant du tapis : de RUG_FOOT au bord (e = 0) à « top » à RUG_EDGE du bord, bombé (surjet).
static func _rug_profile(e: float, top: float) -> float:
	if e >= RUG_EDGE:
		return top
	return RUG_FOOT + (top - RUG_FOOT) * pow(sin(clampf(e / RUG_EDGE, 0.0, 1.0) * PI / 2.0), 0.75)


## Ondulations du velours (±0,5 mm) : un tapis n'est jamais tout à fait plat.
static func _rug_wave(x: float, z: float) -> float:
	return 0.00033 * (sin(x * 5.1 + 1.3) * sin(z * 4.3 + 0.7) + 0.5 * sin(x * 11.7 + z * 7.9 + 2.0))


static func _rug_lift_at(x: float, z: float, lift: Vector3) -> float:
	if lift.z <= 0.0:
		return 0.0
	var k := 1.0 - Vector2(x - lift.x, z - lift.y).length() / RUG_LIFT_R
	return lift.z * k * k if k > 0.0 else 0.0


## Tapis rond (tapis de bain) : disque en anneaux, chant arrondi, sans franges.
static func _rug_round_surface(mesh: ArrayMesh, r: float, top: float) -> void:
	var seg := 72
	var rings := PackedFloat32Array([0.0])
	var inner := r - RUG_EDGE
	var n := maxi(2, ceili(inner / 0.07))
	for k in range(1, n + 1):
		rings.append(inner * k / n)
	for e in [0.0055, 0.0025, 0.0]:
		rings.append(r - e)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var hts := PackedFloat32Array()
	for rr in rings:
		hts.append(_rug_profile(r - rr, top))
	# centre
	verts.append(Vector3(0.0, hts[0], 0.0))
	norms.append(Vector3.UP)
	tans.append_array([1.0, 0.0, 0.0, 1.0])
	uvs.append(Vector2(0.5, 0.5))
	uv2.append(Vector2.ZERO)
	for k in range(1, rings.size()):
		var rr := rings[k]
		var k1 := mini(k + 1, rings.size() - 1)
		var dydr := (hts[k1] - hts[k - 1]) / (rings[k1] - rings[k - 1])
		for j in seg:
			var a := TAU * j / seg
			var ca := cos(a)
			var sa := sin(a)
			var x := rr * ca
			var z := rr * sa
			var y := hts[k] + _rug_wave(x, z) * clampf((r - rr - 0.01) / 0.07, 0.0, 1.0)
			var nn := Vector3(-dydr * ca, 1.0, -dydr * sa).normalized()
			var t := (Vector3.RIGHT - nn * nn.x).normalized()
			verts.append(Vector3(x, y, z))
			norms.append(nn)
			tans.append_array([t.x, t.y, t.z, 1.0])
			uvs.append(Vector2(0.5 + x / (2.0 * r), 0.5 + z / (2.0 * r)))
			uv2.append(Vector2(x, z) / RUG_WEAVE)
	for j in seg:
		idx.append_array([0, 1 + j, 1 + (j + 1) % seg])
	for k in range(1, rings.size() - 1):
		var a0 := 1 + (k - 1) * seg
		var b0 := a0 + seg
		for j in seg:
			var j1 := (j + 1) % seg
			idx.append_array([a0 + j, b0 + j, a0 + j1, a0 + j1, b0 + j, b0 + j1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## Franges : sur les deux petits côtés, des cartes à plat qui sortent de sous le chant (6 mm) et
## s'étalent sur « fringe » mètres, posées juste au-dessus du sol, relevées avec le coin.
static func _rug_fringes(mesh: ArrayMesh, hw: float, hd: float, fringe: float, lift: Vector3) -> void:
	var along_z := hw >= hd           # franges sur les côtés x = ±hw (les petits côtés), le long de z
	var half_e := hd if along_z else hw
	var half_n := hw if along_z else hd
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var s0 := -half_e + 0.025
	var s1 := half_e - 0.025
	var ns := maxi(2, ceili((s1 - s0) / 0.1))
	var ts := [0.0, 0.4, 1.0]
	for side in [-1.0, 1.0]:
		var base := verts.size()
		for k in ns + 1:
			var s := s0 + (s1 - s0) * k / ns
			for t in ts:
				var o: float = half_n - 0.006 + (fringe + 0.006) * float(t)
				var p := Vector3(side * o, 0.0, s) if along_z else Vector3(s, 0.0, side * o)
				p.y = RUG_FOOT + 0.0009 - 0.0004 * float(t) + _rug_lift_at(p.x, p.z, lift)
				verts.append(p)
				norms.append(Vector3.UP)
				var tn := Vector3(0.0, 0.0, 1.0) if along_z else Vector3(1.0, 0.0, 0.0)
				tans.append_array([tn.x, tn.y, tn.z, 1.0])
				uvs.append(Vector2((s - s0) / 0.1, float(t)))
		for k in ns:
			for q in ts.size() - 1:
				var a := base + k * ts.size() + q
				var b := a + ts.size()
				# (matière sans élagage des faces : le sens des triangles importe peu)
				idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## Matière d'un motif de tapis (partagée par motif) : le motif en UV (couleur ; rugosité dans l'alpha,
## usure comprise), le tissage de Fabric045 (ambientCG, CC0 : normale et occlusion) en détail, en UV2.
## null si le motif n'est pas sur le disque. Le motif (1 Mo) se charge en arrière-plan s'il n'est pas déjà
## en mémoire : la construction de la pièce ne l'attend pas (B16) ; d'ici là, la couleur moyenne.
## En rendu allégé (soft_render) : le motif seul, sans le tissage (une autre matière, « motif_leger »).
static func _rug_pattern_mat(design: String) -> StandardMaterial3D:
	var soft := soft_render()
	var key := ("motif_leger:" if soft else "motif:") + design
	if _rug_mats.has(key):
		return _rug_mats[key]
	var path := RUG_DIR + "rug_%s.png" % design
	if not ResourceLoader.exists(path):
		return null
	var m := StandardMaterial3D.new()
	m.resource_name = "tapis_" + design
	m.roughness = 1.0
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	if ResourceLoader.has_cached(path) or not (Engine.get_main_loop() is SceneTree):
		_rug_set_pattern(m, load(path))
	elif _rug_tex_wait.has(path):
		(_rug_tex_wait[path] as Array).append(m)
		m.albedo_color = RUG_AVERAGE.get(design, Color(0.35, 0.25, 0.2))
	elif ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
		_rug_tex_wait[path] = [m]
		m.albedo_color = RUG_AVERAGE.get(design, Color(0.35, 0.25, 0.2))
		_detail_hook()
	else:
		_rug_set_pattern(m, load(path))
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if not soft and ResourceLoader.exists(RUG_TEX % "NormalGL"):
		# le tissage remplace la normale (plate) du motif ; l'occlusion du tissage creuse les fils
		m.normal_enabled = true
		m.normal_texture = _flat_normal()
		m.normal_scale = 1.1
		m.detail_enabled = true
		m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
		m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.detail_normal = load(RUG_TEX % "NormalGL")
		m.ao_enabled = true
		m.ao_on_uv2 = true
		m.ao_texture = load(RUG_TEX % "AmbientOcclusion")
		m.ao_light_affect = 0.25
	_rug_mats[key] = m
	return m


static func _rug_set_pattern(m: StandardMaterial3D, tex: Texture2D) -> void:
	m.albedo_texture = tex
	m.roughness_texture = tex
	m.albedo_color = Color.WHITE


## Reprend les motifs de tapis chargés en arrière-plan (appelé à chaque image par _detail_tick).
static func _rug_tex_tick() -> void:
	for path in _rug_tex_wait.keys():
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var tex: Texture2D = ResourceLoader.load_threaded_get(path) if st == ResourceLoader.THREAD_LOAD_LOADED else load(path)
		for m in _rug_tex_wait[path]:
			_rug_set_pattern(m, tex)
		_rug_tex_wait.erase(path)


## Franges : coton découpé (ALPHA_SCISSOR), sans élagage des faces, teinte du motif.
static func _rug_fringe_mat(design: String) -> StandardMaterial3D:
	var key := "franges:" + design
	if _rug_mats.has(key):
		return _rug_mats[key]
	var m := StandardMaterial3D.new()
	m.resource_name = "franges_" + design
	if ResourceLoader.exists(RUG_DIR + "rug_franges.png"):
		m.albedo_texture = load(RUG_DIR + "rug_franges.png")
	m.albedo_color = RUG_FRINGE_TINT.get(design, Color(0.95, 0.92, 0.85))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rug_mats[key] = m
	return m


## Carte de normales plate (4 × 4) : la normale du motif, que le détail (le tissage) remplace.
static func _flat_normal() -> ImageTexture:
	if _flat_normal_tex == null:
		var img := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color(0.5, 0.5, 1.0))
		_flat_normal_tex = ImageTexture.create_from_image(img)
	return _flat_normal_tex


## Cache les maillages d'un meuble Kenney redessiné en code (son nœud, sa collision et ses données
## restent : decor.gd lit les hauteurs d'étagère dans le maillage de la bibliothèque de la chambre, desk_top
## vient de la boîte du bureau…).
func _hide_meshes(node: Node3D) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = false


## Surface de révolution (tour de potier) : « profile » = points (rayon, hauteur) parcourus de bas en
## haut à l'extérieur (puis, pour une vasque, redescendant à l'intérieur) ; « seg » côtés ; scale_z
## aplatit en ovale. Normales lissées (pas d'UV : pour des matières unies, crasse en coordonnées du monde).
## chamfer > 0 : angles vifs du profil chanfreinés, UV et tangentes (voir _lathe_chamfered).
static func lathe_mesh(profile: PackedVector2Array, seg := 32, scale_z := 1.0, chamfer := 0.0) -> ArrayMesh:
	if chamfer > 0.0:
		return _lathe_chamfered(profile, seg, scale_z, chamfer)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in profile:
		for j in seg:
			var a := TAU * j / seg
			st.add_vertex(Vector3(p.x * cos(a), p.y, p.x * sin(a) * scale_z))
	for k in profile.size() - 1:
		for j in seg:
			var a := k * seg + j
			var b := k * seg + (j + 1) % seg
			var c := a + seg
			var e := b + seg
			for i in [a, b, c, b, e, c]:
				st.add_index(i)
	st.generate_normals()
	return st.commit()


## Coussin ou oreiller : deux faces bombées (largeur w en x, profondeur d en z, épaisseur t au centre)
## qui se rejoignent sur une couture plate au pourtour ; centré sur l'origine, la couture à y = 0.
static func pillow_mesh(w: float, d: float, t: float, n := 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for side in [1.0, -1.0]:
		for j in n + 1:
			for i in n + 1:
				var u := -1.0 + 2.0 * i / n
				var v := -1.0 + 2.0 * j / n
				var puff := (1.0 - pow(absf(u), 3.0)) * (1.0 - pow(absf(v), 3.0))
				# (les coins tirent un peu vers l'intérieur, comme un vrai coussin rembourré)
				var pinch := 1.0 - 0.05 * absf(u * v)
				st.set_uv(Vector2(float(i) / n, float(j) / n))
				st.add_vertex(Vector3(u * w / 2.0 * pinch, side * t / 2.0 * pow(puff, 0.55), v * d / 2.0 * pinch))
		for j in n:
			for i in n:
				var a := base + j * (n + 1) + i
				var b := a + 1
				var c := a + n + 1
				var e := c + 1
				var tri: Array = [a, b, c, b, e, c] if side > 0.0 else [a, c, b, b, c, e]
				for k in tri:
					st.add_index(k)
		base += (n + 1) * (n + 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _rug_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _rug_mats.has(key):
		return _rug_mats[key]
	# la laine est d'un gris clair (≈ 0,75) : la teinte des pièces (pensée pour un aplat) est relevée
	var tint := Color(c.r * 1.3, c.g * 1.3, c.b * 1.3)
	var m: StandardMaterial3D
	if ResourceLoader.exists(RUG_TEX % "Color"):
		m = Surfaces.pbr_acg("Fabric045/Fabric045", 0.5, tint, 1.4)   # un motif tous les 50 cm
	else:
		m = _plain(tint, 1.0)
	_rug_mats[key] = m
	return m


# ------------------------------------------------------------------ géométrie : biseaux, arrondis, lofts

## Biseaux posés par _box() hors rendu logiciel (voir box_mesh) : rayon de 20 % du plus petit côté, entre
## BEVEL_MIN et BEVEL_MAX ; aucun biseau sous BEVEL_SKIP (verres, papiers, étiquettes), ni pour une dalle
## (deux côtés d'au moins SLAB, ou un plateau d'au moins 1 × 1 m sur 12 cm au plus : sols et plafonds, qui
## se raccordent aux seuils des portes), ni pour les morceaux de mur de wall() (ils se raccordent
## bord à bord : un biseau y creuserait un joint), ni quand la matière lit ses textures dans les UV de la
## boîte (le BoxMesh les range en atlas 3 × 2 : l'image changerait).
const BEVEL_MIN := 0.0015
## (7 mm au plus : environ 1 pixel à 2,5 m en 960 × 540, 2 à 3 pixels en 1440p ; l'arête attrape la
## lumière sans que le meuble paraisse moulé)
const BEVEL_MAX := 0.007
const BEVEL_SKIP := 0.006
const SLAB := 2.2

static var _bevel_cache := {}                 # (taille et rayon au 1/10 de mm) -> ArrayMesh partagé
static var _bevel_tpl := PackedInt32Array()   # indices des 44 triangles (6 faces, 12 chanfreins, 8 coins)
## Banc d'essai : (boîtes demandées à bevel_box_mesh, maillages construits).
static var bevel_stats := Vector2i.ZERO
static var _qualite: Variant = null           # script Qualite (lot V1-RENDU) s'il existe, sinon false
## Coins d'une face, dans l'ordre des sommets (signes sur ses deux axes, b puis c).
const _SB := [-1.0, 1.0, 1.0, -1.0]
const _SC := [-1.0, -1.0, 1.0, 1.0]


## Rendu « allégé » : rendu logiciel (Main.software_renderer(), donc pas avec « -- --rendu-complet »), ou
## Qualite.soft() quand ce script existe. Tout ce qui coûte est alors coupé : biseaux, objets de détail.
static func soft_render() -> bool:
	if Main.software_renderer():
		return true
	if _qualite == null:
		_qualite = false
		for c in ProjectSettings.get_global_class_list():
			if String(c.get("class", "")) == "Qualite":
				var s: Script = load(String(c.get("path", "")))
				if s:
					for m in s.get_script_method_list():
						if String(m.get("name", "")) == "soft":
							_qualite = s
							break
	if _qualite is Script:
		return bool((_qualite as Object).call("soft"))
	return false


## Le maillage d'une boîte de _box() : bevel_box_mesh() si le rendu n'est pas allégé (soft_render), sinon
## un BoxMesh comme avant. bevel < 0 : rayon automatique (voir BEVEL_MIN…), 0 : jamais de biseau.
## Pour les meubles fondus en un maillage (SurfaceTool.append_from), à la place d'un BoxMesh.
static func box_mesh(size: Vector3, bevel := -1.0, mat: Material = null) -> Mesh:
	var m := minf(size.x, minf(size.y, size.z))
	if bevel != 0.0 and m >= BEVEL_SKIP and not soft_render():
		var r := bevel
		if r < 0.0:
			r = clampf(m * 0.2, BEVEL_MIN, BEVEL_MAX)
			var big := int(size.x >= SLAB) + int(size.y >= SLAB) + int(size.z >= SLAB)
			var floor_like := size.x >= 1.0 and size.z >= 1.0 and size.y <= 0.12
			if big >= 2 or floor_like or not _uv_free(mat):
				r = 0.0
		if r > 0.0:
			return bevel_box_mesh(size, r)
	var bm := BoxMesh.new()
	bm.size = size
	return bm


## Vrai si la matière ne lit aucune texture dans les UV du maillage (couleur unie, ou coordonnées prises
## dans le monde) : le dépliage de la boîte peut changer sans rien changer à l'image.
static func _uv_free(mat: Material) -> bool:
	if mat == null:
		return true
	var m := mat as BaseMaterial3D
	if m == null:
		return false          # ShaderMaterial : on ne sait pas ce qu'il lit
	if m.uv1_triplanar:
		return true
	if m.albedo_texture or m.roughness_texture or m.metallic_texture:
		return false
	if (m.normal_enabled and m.normal_texture) or (m.emission_enabled and m.emission_texture):
		return false
	if m.ao_enabled and m.ao_texture and not m.ao_on_uv2:
		return false
	if m.heightmap_enabled and m.heightmap_texture:
		return false
	if m.detail_enabled and m.detail_uv_layer == BaseMaterial3D.DETAIL_UV_1 and (m.detail_albedo or m.detail_normal):
		return false
	if m is ORMMaterial3D and (m as ORMMaterial3D).orm_texture:
		return false
	return true


## Boîte chanfreinée centrée sur l'origine, de même boîte englobante qu'un BoxMesh de cette taille :
## 6 faces, 12 chanfreins et 8 coins de rayon r (au plus 45 % du plus petit demi-côté), 24 sommets et
## 44 triangles. Les sommets des chanfreins portent la normale de leur face : la lumière glisse d'une
## face à l'autre comme sur une arête arrondie, et les faces restent planes. UV en mètres, propres à
## chaque face, u le long du plus grand côté de la boîte (le fil du bois) ; sur les faces verticales,
## l'image est à l'endroit. Tangentes pour les cartes de normales. Construite en tableaux bruts et
## gardée en cache par taille (au dixième de millimètre près) et rayon : le maillage est partagé, ne
## pas le modifier (la matière se pose sur le MeshInstance3D).
static func bevel_box_mesh(size: Vector3, r := 0.005) -> ArrayMesh:
	bevel_stats.x += 1
	var key := Vector4i(roundi(size.x * 10000.0), roundi(size.y * 10000.0), roundi(size.z * 10000.0), roundi(r * 100000.0))
	var hit: ArrayMesh = _bevel_cache.get(key)
	if hit:
		return hit
	bevel_stats.y += 1
	var h := size.abs() / 2.0
	var rr := clampf(r, 0.0, 0.45 * minf(h.x, minf(h.y, h.z)))
	if _bevel_tpl.is_empty():
		_bevel_tpl = _bevel_indices()
	var lng := 0
	if size.y > size[lng]:
		lng = 1
	if size.z > size[lng]:
		lng = 2
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	verts.resize(24)
	norms.resize(24)
	tans.resize(96)
	uvs.resize(24)
	for f in 6:
		var a := f >> 1
		var s := 1.0 if (f & 1) == 0 else -1.0
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		var n := Vector3.ZERO
		n[a] = s
		var ru := _face_right(a, s, b, c, size, lng)
		var dv := ru.cross(n)
		var hu := absf(h.dot(ru))
		var hv := absf(h.dot(dv))
		for k in 4:
			var p := Vector3.ZERO
			p[a] = s * h[a]
			p[b] = _SB[k] * (h[b] - rr)
			p[c] = _SC[k] * (h[c] - rr)
			var i := f * 4 + k
			verts[i] = p
			norms[i] = n
			uvs[i] = Vector2(p.dot(ru) + hu, p.dot(dv) + hv)
			tans[i * 4] = ru.x
			tans[i * 4 + 1] = ru.y
			tans[i * 4 + 2] = ru.z
			tans[i * 4 + 3] = 1.0
	var mesh := _arrays_mesh(verts, norms, tans, uvs, _bevel_tpl if rr > 0.00001 else _bevel_tpl.slice(0, 36))
	_bevel_cache[key] = mesh
	return mesh


## Direction des u croissants sur une face (axe a, signe s ; axes du plan b et c) : le plus grand côté de
## la boîte s'il est dans le plan de la face, sinon le plus grand des deux. Sur une face verticale dont le
## u est horizontal : vers la droite de qui la regarde (la direction des v, vers le bas, s'en déduit).
static func _face_right(a: int, s: float, b: int, c: int, size: Vector3, lng: int) -> Vector3:
	var u := lng if (lng == b or lng == c) else (b if size[b] >= size[c] else c)
	if a != 1 and u != 1:
		var n := Vector3.ZERO
		n[a] = s
		return Vector3.UP.cross(n)
	var e := Vector3.ZERO
	e[u] = 1.0
	return e


## Indices de la boîte chanfreinée (une fois pour toutes) : sens des triangles vérifié sur une boîte de
## référence (Godot : face avant dans le sens des aiguilles d'une montre).
static func _bevel_indices() -> PackedInt32Array:
	var pos := PackedVector3Array()
	pos.resize(24)
	for f in 6:
		var a := f >> 1
		var s := 1.0 if (f & 1) == 0 else -1.0
		for k in 4:
			var p := Vector3.ZERO
			p[a] = s
			p[(a + 1) % 3] = _SB[k] * 0.75
			p[(a + 2) % 3] = _SC[k] * 0.75
			pos[f * 4 + k] = p
	var out := PackedInt32Array()
	for f in 6:
		var n := Vector3.ZERO
		n[f >> 1] = 1.0 if (f & 1) == 0 else -1.0
		out.append_array(_wind(pos, f * 4, f * 4 + 1, f * 4 + 2, n))
		out.append_array(_wind(pos, f * 4, f * 4 + 2, f * 4 + 3, n))
	# 12 chanfreins : entre les faces (a1, s1) et (a2, s2), le long du troisième axe
	for a1 in 3:
		for a2 in range(a1 + 1, 3):
			var a3 := 3 - a1 - a2
			for s1 in [-1, 1]:
				for s2 in [-1, 1]:
					var q := []
					for s3 in [-1, 1]:
						var sg := Vector3i.ZERO
						sg[a1] = s1
						sg[a2] = s2
						sg[a3] = s3
						q.append([_corner_vid(a1, sg), _corner_vid(a2, sg)])
					var out_dir := Vector3.ZERO
					out_dir[a1] = s1
					out_dir[a2] = s2
					out.append_array(_wind(pos, q[0][0], q[1][0], q[1][1], out_dir))
					out.append_array(_wind(pos, q[0][0], q[1][1], q[0][1], out_dir))
	# 8 coins : un triangle entre les trois faces
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var sg := Vector3i(sx, sy, sz)
				out.append_array(_wind(pos, _corner_vid(0, sg), _corner_vid(1, sg), _corner_vid(2, sg), Vector3(sg)))
	return out


## Sommet de la face d'axe a (côté sg[a]) au coin de signes sg.
static func _corner_vid(a: int, sg: Vector3i) -> int:
	var f := a * 2 + (0 if sg[a] > 0 else 1)
	var sb := float(sg[(a + 1) % 3])
	var sc := float(sg[(a + 2) % 3])
	for k in 4:
		if _SB[k] == sb and _SC[k] == sc:
			return f * 4 + k
	return f * 4


## Les trois indices dans l'ordre qui fait face à « n » (Godot : sens horaire vu de devant).
static func _wind(pos: PackedVector3Array, i0: int, i1: int, i2: int, n: Vector3) -> PackedInt32Array:
	if (pos[i1] - pos[i0]).cross(pos[i2] - pos[i0]).dot(n) > 0.0:
		return PackedInt32Array([i0, i2, i1])
	return PackedInt32Array([i0, i1, i2])


static func _arrays_mesh(verts: PackedVector3Array, norms: PackedVector3Array, tans: PackedFloat32Array,
		uvs: PackedVector2Array, idx: PackedInt32Array, uv2 := PackedVector2Array()) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	if not tans.is_empty():
		arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	if not uv2.is_empty():
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Boîte aux arêtes arrondies (rayon r, « seg » segments par quart de cercle, arrondi au pair) : coins
## sphériques, normales exactes, UV en mètres par face comme bevel_box_mesh (u le long du plus grand côté),
## tangentes. Centrée sur l'origine, même boîte englobante qu'un BoxMesh. Pour les objets doux ou moulés :
## réservoir de WC, coussins fermes, plastiques des années 80. r = 0 : boîte nette.
static func rounded_box_mesh(size: Vector3, r: float, seg := 4) -> ArrayMesh:
	var h := size.abs() / 2.0
	r = clampf(r, 0.0, minf(h.x, minf(h.y, h.z)))
	if r <= 0.00001:
		return bevel_box_mesh(size, 0.0)
	var mk := maxi(1, (seg + 1) / 2)
	var ih := h - Vector3.ONE * r
	var lng := 0
	if size.y > size[lng]:
		lng = 1
	if size.z > size[lng]:
		lng = 2
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for f in 6:
		var a := f >> 1
		var s := 1.0 if (f & 1) == 0 else -1.0
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		var n := Vector3.ZERO
		n[a] = s
		var ru := _face_right(a, s, b, c, size, lng)
		var dv := ru.cross(n)
		var hu := absf(h.dot(ru))
		var hv := absf(h.dot(dv))
		var cb := _round_coords(ih[b], r, mk)
		var cc := _round_coords(ih[c], r, mk)
		var base := verts.size()
		for j in cc.size():
			for i in cb.size():
				var q := Vector3.ZERO
				q[a] = s * h[a]
				q[b] = cb[i]
				q[c] = cc[j]
				var inner := q.clamp(-ih, ih)
				var nn := (q - inner).normalized()
				verts.append(inner + nn * r)
				norms.append(nn)
				uvs.append(Vector2(q.dot(ru) + hu, q.dot(dv) + hv))
				var t := (ru - nn * nn.dot(ru)).normalized()
				tans.append_array([t.x, t.y, t.z, 1.0])
		var nb := cb.size()
		for j in cc.size() - 1:
			for i in nb - 1:
				var v00 := base + j * nb + i
				var v10 := v00 + 1
				var v01 := v00 + nb
				var v11 := v01 + 1
				if s > 0.0:
					idx.append_array([v00, v11, v10, v00, v01, v11])
				else:
					idx.append_array([v00, v10, v11, v00, v11, v01])
	return _arrays_mesh(verts, norms, tans, uvs, idx)


## Coordonnées d'une face de rounded_box_mesh le long d'un axe : la bande arrondie de chaque côté (angles
## de 0 à 45°, le reste du quart de cercle est sur la face voisine), et le plat entre -ih et ih.
static func _round_coords(ih: float, r: float, mk: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in range(mk, 0, -1):
		out.append(-(ih + r * tan(PI / 4.0 * k / mk)))
	out.append(-ih)
	if ih > 0.00001:
		out.append(ih)
	for k in range(1, mk + 1):
		out.append(ih + r * tan(PI / 4.0 * k / mk))
	return out


## Superellipse |x/a|^n + |z/b|^n = 1 : « seg » points (x, z), angle croissant depuis (a, 0). n = 2 :
## ellipse ; 2,5 à 4 : rectangle arrondi (cuvette, réservoir, baignoire, buste) ; n < 2 : losange bombé.
## even : points également espacés le long du contour (avec seg multiple de 4, les points seg/4, seg/2…
## tombent sur les axes : des sections de formes différentes se correspondent). Sinon, angle constant.
static func superellipse(a: float, b: float, n: float, seg := 48, even := true) -> PackedVector2Array:
	var e := 2.0 / maxf(n, 0.01)
	var dense := seg * 8 if even else seg
	var pts := PackedVector2Array()
	pts.resize(dense)
	for i in dense:
		var t := TAU * i / dense
		var c := cos(t)
		var s := sin(t)
		pts[i] = Vector2(a * signf(c) * pow(absf(c), e), b * signf(s) * pow(absf(s), e))
	if not even:
		return pts
	var cum := PackedFloat32Array()
	cum.resize(dense + 1)
	cum[0] = 0.0
	for i in dense:
		cum[i + 1] = cum[i] + pts[i].distance_to(pts[(i + 1) % dense])
	var total := cum[dense]
	var out := PackedVector2Array()
	out.resize(seg)
	var j := 0
	for k in seg:
		var target := total * k / seg
		while j < dense - 1 and cum[j + 1] < target:
			j += 1
		var span := cum[j + 1] - cum[j]
		var w := (target - cum[j]) / span if span > 0.0 else 0.0
		out[k] = pts[j].lerp(pts[(j + 1) % dense], w)
	return out


## Loft : des anneaux fermés (« sections » : PackedVector2Array de points (x, z), tous du même nombre de
## points, dans le même sens) posés aux hauteurs « ys », reliés en une surface. Normales lissées (vers
## l'extérieur ; inside = true : vers l'intérieur, pour l'intérieur d'une cuvette ou d'une baignoire),
## UV : u = abscisse curviligne sur l'anneau (m), v = hauteur (m) ; tangentes. caps : fonds plats en haut et
## en bas (éventail depuis le centre de l'anneau, arête nette). Ex. : superellipse() pour chaque section.
static func loft_mesh(sections: Array, ys: PackedFloat32Array, caps := true, inside := false) -> ArrayMesh:
	var nr := sections.size()
	if nr < 2 or ys.size() != nr:
		push_error("loft_mesh : %d sections pour %d hauteurs" % [nr, ys.size()])
		return ArrayMesh.new()
	var n := (sections[0] as PackedVector2Array).size()
	for sec in sections:
		if (sec as PackedVector2Array).size() != n or n < 3:
			push_error("loft_mesh : les anneaux doivent avoir le même nombre de points (au moins 3)")
			return ArrayMesh.new()
	var P := []
	for i in nr:
		var ring := PackedVector3Array()
		ring.resize(n)
		var sec: PackedVector2Array = sections[i]
		for j in n:
			ring[j] = Vector3(sec[j].x, ys[i], sec[j].y)
		P.append(ring)
	# sens des normales : vers l'extérieur des anneaux (vérifié sur l'anneau du milieu)
	var mid := nr / 2
	var rm: PackedVector3Array = P[mid]
	var ctr := Vector3.ZERO
	for p in rm:
		ctr += p
	ctr /= n
	var test := 0.0
	for j in n:
		var tr: Vector3 = rm[(j + 1) % n] - rm[(j - 1 + n) % n]
		var th: Vector3 = (P[mini(mid + 1, nr - 1)] as PackedVector3Array)[j] - (P[maxi(mid - 1, 0)] as PackedVector3Array)[j]
		test += th.cross(tr).dot(rm[j] - ctr)
	var sgn := 1.0 if test >= 0.0 else -1.0
	if inside:
		sgn = -sgn
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in nr:
		var ring: PackedVector3Array = P[i]
		var lo: PackedVector3Array = P[maxi(i - 1, 0)]
		var hi: PackedVector3Array = P[mini(i + 1, nr - 1)]
		var vsign := signf(ys[mini(i + 1, nr - 1)] - ys[maxi(i - 1, 0)])
		var u := 0.0
		for j in n + 1:
			var jj := j % n
			if j > 0:
				u += ring[jj].distance_to(ring[j - 1])
			var tr: Vector3 = ring[(jj + 1) % n] - ring[(jj - 1 + n) % n]
			var th: Vector3 = hi[jj] - lo[jj]
			var nn := (th.cross(tr) * sgn).normalized()
			if nn == Vector3.ZERO:
				nn = Vector3.UP * signf(ys[nr - 1] - ys[0]) * (-1.0 if i == 0 else 1.0)
			var t := (tr - nn * nn.dot(tr)).normalized()
			var w := 1.0 if nn.cross(t).dot(-th * vsign) >= 0.0 else -1.0
			verts.append(ring[jj])
			norms.append(nn)
			uvs.append(Vector2(u, ys[i]))
			tans.append_array([t.x, t.y, t.z, w])
	# sens des triangles : vérifié une fois (sur l'anneau du milieu), le même partout
	var flip := false
	var tsum := 0.0
	var i0 := mini(mid, nr - 2)
	for j in n:
		var a := i0 * (n + 1) + j
		tsum += (verts[a + 1] - verts[a]).cross(verts[a + n + 1] - verts[a]).dot(norms[a])
	flip = tsum > 0.0
	for i in nr - 1:
		for j in n:
			var a := i * (n + 1) + j
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			if flip:
				idx.append_array([a, c, b, b, c, d])
			else:
				idx.append_array([a, b, c, b, d, c])
	if caps:
		for end in [0, nr - 1]:
			var ring: PackedVector3Array = P[end]
			var other := 1 if end == 0 else nr - 2
			var cn := Vector3.UP * signf(ys[end] - ys[other])
			if inside:
				cn = -cn
			var cc := Vector3.ZERO
			for p in ring:
				cc += p
			cc /= n
			var base := verts.size()
			var cw := 1.0 if cn.y > 0.0 else -1.0
			verts.append(cc)
			norms.append(cn)
			uvs.append(Vector2(cc.x, cc.z))
			tans.append_array([1.0, 0.0, 0.0, cw])
			for j in n:
				verts.append(ring[j])
				norms.append(cn)
				uvs.append(Vector2(ring[j].x, ring[j].z))
				tans.append_array([1.0, 0.0, 0.0, cw])
			var cflip := false
			var csum := 0.0
			for j in n:
				csum += (verts[base + 1 + j] - verts[base]).cross(verts[base + 1 + (j + 1) % n] - verts[base]).dot(cn)
			cflip = csum > 0.0
			for j in n:
				var p1 := base + 1 + j
				var p2 := base + 1 + (j + 1) % n
				if cflip:
					idx.append_array([base, p2, p1])
				else:
					idx.append_array([base, p1, p2])
	return _arrays_mesh(verts, norms, tans, uvs, idx)


## Cylindre (ou tronc de cône) centré sur l'origine comme un CylinderMesh (y de -h/2 à h/2) : avec un
## chanfrein aux bords des fonds (lathe_mesh, chamfer) si le rendu n'est pas allégé, sinon un CylinderMesh
## (rings = 1) comme avant. chamfer < 0 : 15 % du plus petit de (2 r, h), entre 1 et 4 mm.
static func cylinder_mesh(r_top: float, r_bot: float, h: float, seg := 24, chamfer := -1.0, cap_top := true, cap_bottom := true) -> Mesh:
	var c := chamfer
	if c < 0.0:
		c = clampf(minf(2.0 * minf(r_top, r_bot), h) * 0.15, 0.001, 0.004)
	if c <= 0.0 or soft_render() or minf(r_top, r_bot) < 0.003:
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = seg
		cm.rings = 1
		cm.cap_top = cap_top
		cm.cap_bottom = cap_bottom
		return cm
	var prof := PackedVector2Array()
	if cap_bottom:
		prof.append(Vector2(0.0, -h / 2.0))
	prof.append(Vector2(r_bot, -h / 2.0))
	prof.append(Vector2(r_top, h / 2.0))
	if cap_top:
		prof.append(Vector2(0.0, h / 2.0))
	return lathe_mesh(prof, seg, 1.0, c)


## lathe_mesh avec chanfreins (chamfer > 0) : chaque angle vif du profil (plus de 35°) est coupé de
## « chamfer » mètres de part et d'autre ; les deux points du chanfrein portent les normales des
## segments voisins (la lumière y glisse, les surfaces voisines restent nettes) ; ailleurs, normales
## lissées. UV : u = tour (0 à 1), v = longueur du profil (m) ; tangentes. Sommet de couture doublé.
static func _lathe_chamfered(profile: PackedVector2Array, seg: int, scale_z: float, chamfer: float) -> ArrayMesh:
	var np := profile.size()
	var pts := PackedVector2Array()
	var nrm := PackedVector2Array()
	for i in np:
		var p := profile[i]
		var d0 := (p - profile[i - 1]) if i > 0 else Vector2.ZERO
		var d1 := (profile[i + 1] - p) if i < np - 1 else Vector2.ZERO
		var n0 := Vector2(d0.y, -d0.x).normalized()
		var n1 := Vector2(d1.y, -d1.x).normalized()
		if i == 0:
			pts.append(p)
			nrm.append(n1)
			continue
		if i == np - 1:
			pts.append(p)
			nrm.append(n0)
			continue
		var turn := absf(d0.normalized().angle_to(d1.normalized()))
		if turn > deg_to_rad(35.0):
			var c := minf(chamfer, 0.45 * minf(d0.length(), d1.length()))
			pts.append(p - d0.normalized() * c)
			nrm.append(n0)
			pts.append(p + d1.normalized() * c)
			nrm.append(n1)
		else:
			pts.append(p)
			nrm.append((n0 + n1).normalized())
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var vlen := 0.0
	for k in pts.size():
		if k > 0:
			vlen += pts[k].distance_to(pts[k - 1])
		var p := pts[k]
		var q := nrm[k]
		var up_dir := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		for j in seg + 1:
			var a := TAU * j / seg
			var ca := cos(a)
			var sa := sin(a)
			verts.append(Vector3(p.x * ca, p.y, p.x * sa * scale_z))
			var nn := Vector3(q.x * ca, q.y, q.x * sa / scale_z).normalized()
			norms.append(nn)
			uvs.append(Vector2(float(j) / seg, vlen))
			var t := Vector3(-sa, 0.0, ca * scale_z)
			t = (t - nn * nn.dot(t)).normalized()
			var dp := Vector3(up_dir.x * ca, up_dir.y, up_dir.x * sa * scale_z)
			var w := 1.0 if nn.cross(t).dot(-dp) >= 0.0 else -1.0
			tans.append_array([t.x, t.y, t.z, w])
	var row := seg + 1
	for k in pts.size() - 1:
		for j in seg:
			var a := k * row + j
			var b := a + 1
			var c := a + row
			var e := c + 1
			idx.append_array([a, b, c, b, e, c])
	return _arrays_mesh(verts, norms, tans, uvs, idx)


# ------------------------------------------------------------------ habillage différé : objets de détail

## Objets de détail (detail()) : coupés en rendu allégé, sans collision, hors de « props », hors de la
## cuisson VoxelGI, sans ombre portée sous DETAIL_NO_SHADOW, cachés au-delà de DETAIL_RANGE.
const DETAIL_RANGE := 7.0
const DETAIL_NO_SHADOW := 0.3
const DETAIL_FRAME_US := 4000          # temps de pose par image (µs) : le reste attend l'image suivante
static var _detail_count := {}         # id -> copies déjà posées (noms « Detail_<id>_<n> »)
static var _detail_queue: Array = []   # [support, id, fit, opts, pièce] : en attente de leur modèle
static var _detail_loading := {}       # id -> true : chargement en arrière-plan lancé, pas encore repris
static var _detail_failed := {}        # id -> true : chargement raté (les supports restent vides)
static var _detail_hooked := false


## Objet de décor (habillage, R3 : à appeler depuis dress_details(), jamais depuis furnish()) : un modèle
## Poly Haven posé comme model() (pied en « pos », tourné de rot_deg, mis à l'échelle dans « fit » ; opts :
## yaw, fit, close, tint, stretch, parent…), mais sans collision, jamais inscrit dans « props », nommé
## « Detail_<id>_<n> » (unique), hors de la cuisson VoxelGI, sans ombre portée si sa plus grande dimension
## est sous 0,3 m (opts.shadow = true pour la garder), caché au-delà de 7 m (opts.range, 0 = jamais).
## Rend null en rendu allégé (soft_render) et avec « -- --kenney » : l'appelant doit l'accepter.
## Sinon, rend tout de suite le support (Node3D à sa place, méta « ph_id ») ; le modèle est chargé en
## arrière-plan (ResourceLoader.load_threaded_request au premier appel), puis posé dans le support
## quelques images plus tard (méta « size » et « ready » alors posées). opts.sync = true : tout de suite.
func detail(ph_id: String, pos: Vector3, rot_deg := 0.0, fit := Vector3.ZERO, opts := {}) -> Node3D:
	if soft_render() or _kenney_all():
		return null
	if not ResourceLoader.exists(PH_PATH % [ph_id, ph_id]):
		push_warning("detail() : modèle absent : %s" % ph_id)
		return null
	var n: int = int(_detail_count.get(ph_id, 0)) + 1
	_detail_count[ph_id] = n
	var holder := Node3D.new()
	holder.name = "Detail_%s_%d" % [ph_id, n]
	var parent: Node3D = opts.get("parent", self)
	parent.add_child(holder)
	holder.position = pos
	holder.rotation_degrees.y = rot_deg
	holder.set_meta("ph_id", ph_id)
	holder.add_to_group("details")
	if _ph_scenes.has(ph_id) or opts.get("sync", false):
		_detail_fill(holder, ph_id, fit, opts)
	else:
		_detail_request(ph_id)
		_detail_queue.append([holder, ph_id, fit, opts, self])
		_detail_hook()
	return holder


## Lance tout de suite le chargement en arrière-plan de ces modèles (écran-titre, avant la partie) :
## les detail() suivants les trouveront prêts.
static func preload_details(ids: PackedStringArray) -> void:
	for id in ids:
		if ResourceLoader.exists(PH_PATH % [id, id]):
			_detail_request(id)


## Objets de détail encore en attente de leur modèle (0 : tout est posé).
static func details_pending() -> int:
	return _detail_queue.size()


static func _detail_request(ph_id: String) -> void:
	if _ph_scenes.has(ph_id) or _detail_loading.has(ph_id) or _detail_failed.has(ph_id):
		return
	if ResourceLoader.load_threaded_request(PH_PATH % [ph_id, ph_id], "PackedScene") == OK:
		_detail_loading[ph_id] = true
	else:
		_ph_scene(ph_id)


static func _detail_hook() -> void:
	if _detail_hooked:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.process_frame.connect(_detail_tick)
	_detail_hooked = true


## À chaque image, tant qu'il reste des objets de détail à poser (ou des motifs de tapis à reprendre) :
## reprend les modèles chargés, puis pose les objets qui les attendent (au plus DETAIL_FRAME_US par image).
static func _detail_tick() -> void:
	if not _rug_tex_wait.is_empty():
		_rug_tex_tick()
	for id in _detail_loading.keys():
		var path := PH_PATH % [id, id]
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_ph_scenes[id] = ResourceLoader.load_threaded_get(path) as PackedScene
			_detail_loading.erase(id)
		elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_detail_loading.erase(id)
			_detail_failed[id] = true
			push_warning("detail() : chargement raté : %s" % id)
	var t0 := Time.get_ticks_usec()
	var i := 0
	while i < _detail_queue.size():
		var e: Array = _detail_queue[i]
		var id: String = e[1]
		if _detail_loading.has(id):
			i += 1
			continue
		_detail_queue.remove_at(i)
		var b: Object = e[4]
		var holder: Object = e[0]
		if is_instance_valid(b) and is_instance_valid(holder) and _ph_scenes.get(id) != null:
			(b as Builder)._detail_fill(holder as Node3D, id, e[2], e[3])
		if Time.get_ticks_usec() - t0 > DETAIL_FRAME_US:
			break
	if _detail_queue.is_empty() and _detail_loading.is_empty() and _rug_tex_wait.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.process_frame.is_connected(_detail_tick):
			tree.process_frame.disconnect(_detail_tick)
		_detail_hooked = false


## Pose le modèle dans son support (enfant « Modele », placé par model()) et règle ses instances.
func _detail_fill(holder: Node3D, ph_id: String, fit: Vector3, opts: Dictionary) -> void:
	if not is_instance_valid(holder):
		return
	var o: Dictionary = opts.duplicate()
	o["parent"] = holder
	o["name"] = "Modele"
	o["_detail"] = true
	o.erase("sync")
	var m := model(ph_id, Vector3.ZERO, 0.0, fit, false, o)
	var size: Vector3 = m.get_meta("size")
	holder.set_meta("size", size)
	var small: bool = maxf(size.x, maxf(size.y, size.z)) < DETAIL_NO_SHADOW and not opts.get("shadow", false)
	var rng: float = opts.get("range", DETAIL_RANGE)
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if small:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if rng > 0.0:
			gi.visibility_range_end = rng
			gi.visibility_range_end_margin = 0.5
	holder.set_meta("ready", true)


## « -- --kenney » : tout en Kenney (ni modèle Poly Haven, ni tapis tissé, ni objet de détail).
static func _kenney_all() -> bool:
	if _all_kenney < 0:
		_all_kenney = 1 if OS.get_cmdline_user_args().has("--kenney") else 0
	return _all_kenney == 1


# ------------------------------------------------------------------ murs, pièces, portes

## Mur droit parallèle à l'axe X (axis = "x") ou Z (axis = "z"), de u0 à u1 le long de l'axe,
## centré sur c (l'autre coordonnée), d'épaisseur t, du sol y0 jusqu'à y0 + h.
## holes : ouvertures [u_début, u_fin, y_bas, y_haut] (u absolu le long du mur, y relatif au sol).
func wall(axis: String, u0: float, u1: float, c: float, h: float, holes := [], mat: Material = null, t := 0.1, y0 := 0.0, parent: Node3D = self) -> void:
	if mat == null:
		mat = mats.wall
	var hs := holes.duplicate()
	hs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var u := u0
	for hl in hs:
		if hl[0] > u + 0.001:
			_wall_piece(axis, u, hl[0], c, y0, y0 + h, mat, t, parent)
		if hl[2] > 0.001:
			_wall_piece(axis, hl[0], hl[1], c, y0, y0 + hl[2], mat, t, parent)
		if hl[3] < h - 0.001:
			_wall_piece(axis, hl[0], hl[1], c, y0 + hl[3], y0 + h, mat, t, parent)
		u = maxf(u, hl[1])
	if u < u1 - 0.001:
		_wall_piece(axis, u, u1, c, y0, y0 + h, mat, t, parent)


func _wall_piece(axis: String, a: float, b: float, c: float, ya: float, yb: float, mat: Material, t: float, parent: Node3D) -> void:
	var size: Vector3
	var pos: Vector3
	if axis == "x":
		size = Vector3(b - a, yb - ya, t)
		pos = Vector3((a + b) / 2.0, (ya + yb) / 2.0, c)
	else:
		size = Vector3(t, yb - ya, b - a)
		pos = Vector3(c, (ya + yb) / 2.0, (a + b) / 2.0)
	# (sans biseau : les morceaux d'un mur percé se raccordent bord à bord)
	_box(size, pos, mat, true, parent, 0.0)


## Habillage d'un mur côté pièce : lambris (ou carrelage), cimaise, plinthe, corniche.
## face : coordonnée de la face du mur ; dir : +1 ou -1, vers l'intérieur de la pièce.
## gaps : passages [u_début, u_fin] où le bas du mur est interrompu (portes).
## style : dado_h (hauteur du lambris, 0 = aucun), dado (matière), rail (cimaise), base (plinthe), crown (corniche).
func trim(axis: String, u0: float, u1: float, face: float, dir: float, h: float, gaps := [], style := {}, y0 := 0.0, parent: Node3D = self) -> void:
	var dado_h: float = style.get("dado_h", 0.92)
	var dado: Material = style.get("dado", mats.wainscot)
	var wood: Material = style.get("wood", mats.wood_dark)
	var crown: Material = style.get("crown_mat", mats.paint)
	var spans := _spans(u0, u1, gaps)
	var wt := 0.022
	for s in spans:
		if dado_h > 0.0:
			_trim_piece(axis, s[0], s[1], face + dir * wt / 2.0, y0 + dado_h / 2.0, dado_h, wt, dado, parent)
			if style.get("rail", true):
				_trim_piece(axis, s[0], s[1], face + dir * 0.022, y0 + dado_h + 0.02, 0.045, 0.045, wood, parent)
		if style.get("base", true):
			var off := (wt if dado_h > 0.0 else 0.0) + 0.017
			_trim_piece(axis, s[0], s[1], face + dir * off, y0 + 0.055, 0.11, 0.035, wood, parent)
	if style.get("crown", true):
		_trim_piece(axis, u0, u1, face + dir * 0.035, y0 + h - 0.035, 0.07, 0.07, crown, parent)
		_trim_piece(axis, u0, u1, face + dir * 0.055, y0 + h - 0.085, 0.03, 0.11, crown, parent)


func _spans(u0: float, u1: float, gaps: Array) -> Array:
	var gs := gaps.duplicate()
	gs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := []
	var u := u0
	for g in gs:
		if g[0] > u + 0.01:
			out.append([u, g[0]])
		u = maxf(u, g[1])
	if u < u1 - 0.01:
		out.append([u, u1])
	return out


func _trim_piece(axis: String, a: float, b: float, c: float, y: float, hh: float, depth: float, mat: Material, parent: Node3D) -> void:
	if axis == "x":
		_box(Vector3(b - a, hh, depth), Vector3((a + b) / 2.0, y, c), mat, false, parent)
	else:
		_box(Vector3(depth, hh, b - a), Vector3(c, y, (a + b) / 2.0), mat, false, parent)


## Pièce fermée : sol, plafond, quatre murs posés à l'extérieur du rectangle intérieur r
## (r.position = (x0, z0), r.size = (largeur en x, profondeur en z)), et habillage intérieur.
## holes : {"n": [...], "s": [...], "w": [...], "e": [...]} ouvertures de chaque mur
## (n = côté z0, s = côté z1, w = côté x0, e = côté x1), au format de wall().
## style : wall, floor, ceil (matières), t (épaisseur des murs) + options de trim().
func room_shell(r: Rect2, h: float, y0 := 0.0, holes := {}, style := {}, parent: Node3D = self) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var t: float = style.get("t", 0.1)
	var wm: Material = style.get("wall", mats.wall)
	var ft := 0.1
	_box(Vector3(r.size.x + 2 * t, ft, r.size.y + 2 * t), Vector3((x0 + x1) / 2.0, y0 - ft / 2.0, (z0 + z1) / 2.0), style.get("floor", mats.floor), true, parent)
	_box(Vector3(r.size.x + 2 * t, ft, r.size.y + 2 * t), Vector3((x0 + x1) / 2.0, y0 + h + ft / 2.0, (z0 + z1) / 2.0), style.get("ceil", mats.ceil), true, parent)
	wall("x", x0 - t, x1 + t, z0 - t / 2.0, h, holes.get("n", []), wm, t, y0, parent)
	wall("x", x0 - t, x1 + t, z1 + t / 2.0, h, holes.get("s", []), wm, t, y0, parent)
	wall("z", z0, z1, x0 - t / 2.0, h, holes.get("w", []), wm, t, y0, parent)
	wall("z", z0, z1, x1 + t / 2.0, h, holes.get("e", []), wm, t, y0, parent)
	trim("x", x0, x1, z0, 1.0, h, _door_gaps(holes.get("n", [])), style, y0, parent)
	trim("x", x0, x1, z1, -1.0, h, _door_gaps(holes.get("s", [])), style, y0, parent)
	trim("z", z0, z1, x0, 1.0, h, _door_gaps(holes.get("w", [])), style, y0, parent)
	trim("z", z0, z1, x1, -1.0, h, _door_gaps(holes.get("e", [])), style, y0, parent)


func _door_gaps(hs: Array) -> Array:
	var out := []
	for hl in hs:
		if hl[2] < 0.3:
			out.append([hl[0], hl[1]])
	return out


## Ouverture de porte standard centrée en u (format de wall()).
static func door_hole(u: float, w := 0.86, h := 2.04) -> Array:
	return [u - w / 2.0 - 0.02, u + w / 2.0 + 0.02, 0.0, h + 0.02]


## Porte à panneaux dans une ouverture. axis : direction du mur ("x" ou "z") ; at : centre de
## l'ouverture au sol (sur le plan médian du mur) ; swing : +1/-1, côté vers lequel elle s'ouvre.
func door(axis: String, at: Vector3, swing := 1.0, hinge_left := true, wall_t := 0.1, parent: Node3D = self) -> Door:
	var d := Door.new()
	d.wall_t = wall_t
	d.swing = swing
	d.hinge_left = hinge_left
	parent.add_child(d)
	d.position = at
	d.rotation.y = 0.0 if axis == "x" else -PI / 2.0
	d.build(self)
	return d
