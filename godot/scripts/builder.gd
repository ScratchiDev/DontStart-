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
	m.detail_albedo = _grime_tex_s
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

func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
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
##   gi    : true pour que le modèle compte dans la cuisson VoxelGI (défaut : non, voir model()).
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
static var _rug_mats := {}         # couleur -> matière de tapis
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
	if _all_kenney < 0:
		_all_kenney = 1 if OS.get_cmdline_user_args().has("--kenney") else 0
	if _all_kenney == 1:
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
		_ph_scenes[ph_id] = load(PH_PATH % [ph_id, ph_id]) as PackedScene
	return _ph_scenes[ph_id]


## Charge le modèle, corrige ses matières (une fois par modèle) et referme portes et tiroirs.
func _ph_instance(ph_id: String, opts: Dictionary) -> Node3D:
	var inst := _ph_scene(ph_id).instantiate() as Node3D
	_fix_ph_materials(inst, opts.get("tint", Color.WHITE))
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
func _fix_ph_materials(inst: Node, tint: Color) -> void:
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
			if m.resource_name.to_lower().contains("glass"):
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


## "" si le modèle, mis à l'échelle, remplit assez la boîte demandée ; sinon la raison.
func _fit_problem(entry: Dictionary, size: Vector3) -> String:
	var raw := _ph_raw(entry)
	var fitted := raw.size * _fit_scale(entry, raw, size)
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
## close, cover, tint), plus « name » (nom du nœud, et clé dans « props »), « label » (objet
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
	var s := _fit_scale(entry, raw, fit_size)
	inst.scale = Vector3.ONE * s
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
	props[opts.get("name", ph_id)] = holder
	if Game.autotest:
		print("prop %-22s ph:%s x%.3f -> %s" % [opts.get("name", ph_id), ph_id, s, _fmt(box.size)])
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


## Tapis texturé (laine tissée ambientCG, CC0) à la place du tapis Kenney : un champ teinté par
## tint["carpet"] et une bordure teintée par tint["carpetdarker"], 8,5 mm d'épaisseur, posé en « pos ».
func _woven_rug(model_name: String, pos: Vector3, rot: float, size: Vector3, tint: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = model_name
	add_child(holder)
	var w := size.x if size.x > 0.0 else 2.0
	var d := size.z if size.z > 0.0 else (w if model_name == "rugRound" else w * 0.65)
	var field: Color = tint.get("carpet", Color(0.42, 0.2, 0.18))
	var border: Color = tint.get("carpetdarker", field.darkened(0.45))
	var round_ := model_name == "rugRound"
	var inset := clampf(minf(w, d) * 0.07, 0.05, 0.11)
	var hb := 0.007
	var hf := 0.0085
	for k in 2:
		var hh := hb if k == 0 else hf
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
	holder.position = pos
	holder.rotation_degrees.y = rot
	holder.set_meta("size", Vector3(w, hf, d))
	props[model_name] = holder
	return holder


## Cache les maillages d'un meuble Kenney redessiné en code (son nœud, sa collision et ses données
## restent : decor.gd lit les hauteurs d'étagère dans le maillage de la bibliothèque de la chambre, desk_top
## vient de la boîte du bureau…).
func _hide_meshes(node: Node3D) -> void:
	for n in node.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = false


## Surface de révolution (tour de potier) : « profile » = points (rayon, hauteur) parcourus de bas en
## haut à l'extérieur (puis, pour une vasque, redescendant à l'intérieur) ; « seg » côtés ; scale_z
## aplatit en ovale. Normales lissées (pas d'UV : pour des matières unies, crasse en coordonnées du monde).
static func lathe_mesh(profile: PackedVector2Array, seg := 32, scale_z := 1.0) -> ArrayMesh:
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
	_box(size, pos, mat, true, parent)


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
