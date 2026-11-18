class_name Wear
extends RefCounted
## Bibliothèque d'usure (passe « triple A », lot V1-USURE) : décalques PBR (couleur, relief, rugosité)
## qui font passer les surfaces de « neuves » à « habitées ». Fonctions statiques, sans état de jeu.
##
## Une seule entrée, decal(), et quatre aides (wall_base, ceiling_corners, path, footprints). À appeler
## depuis dress_details() (R3, après la mesure de B16) ; les traces du récit (story = true) peuvent l'être
## depuis furnish() ou _ready (elles existent aussi en rendu logiciel).
##
## Règles :
##  - rendu logiciel (Qualite.soft(), c'est-à-dire Main.software_renderer()) : decal() rend null, SAUF avec
##    opts.story = true (empreintes, taches du récit) ; les aides rendent alors un tableau vide ;
##  - préréglage Basse (Qualite.effective() == BASSE) : pas de décalques décoratifs non plus (rien n'est
##    chargé) ; le changement de préréglage prend effet au prochain lancement ;
##  - aucun tirage aléatoire : la variante et les petites rotations viennent d'un hachage de la position
##    (déterministe d'un lancement à l'autre), jamais de randf() ;
##  - chaque décalque : texture_albedo, texture_orm et (si le genre a du relief) texture_normal ;
##    normal_fade 0,35 ; upper_fade et lower_fade ; distance_fade (début 9 m, longueur 2 m) ; cull_mask
##    sur la couche 1 seulement (les couches 11 et 12 des caméras de flux ne sont pas touchées) ;
##    groupe « usure » ; méta « usure » (genre) et « variante » ;
##  - un fichier absent : on passe à la variante suivante, sans erreur ; aucune variante : null.
##
## Godot mélange la couleur d'un décalque selon alpha × albedo_mix, mais sa normale et son ORM selon
## l'alpha seul : opts.mix bas = la tache change surtout la rugosité (reflet mat ou mouillé). Sur une
## vitre, un miroir ou un écran (opts.vitre = true), albedo_mix est multiplié par VITRE_MIX et l'alpha
## par VITRE_ALPHA : une trace de doigts ou une traînée s'y voit dans le reflet (gras = plus mat), pas
## comme une peinture blanche.
##
## Le décalque ne fait que remplacer (en partie) la couleur, il ne la multiplie pas : sa teinte doit être
## proche de celle de la surface (PATH_TINT pour les sols ; opts.color sinon, valeurs > 1 permises pour
## éclaircir, comme RING_LIGHT). Godot ne change pas la transparence d'une matière (verre alpha).
##
## Coût : un décalque lit 2 ou 3 textures par pixel couvert (Forward+ par grappes) : viser 8 à 15
## décalques décoratifs par pièce, de taille raisonnable.

const ACG_DIR := "res://assets/decals/acg/"
const GEN_DIR := "res://assets/decals/gen/"

## Genres et leurs variantes, dans l'ordre. « acg:<Id> » : décalque ambientCG (lot V1-ASSETS) dans
## acg/<Id>_{albedo,normal,orm}.png, avec l'albédo aux bords adoucis de gen/acg/<Id>_albedo.png s'il
## existe ; sinon gen/<nom>_{albedo,normal,orm}.png (tools/make_wear.py ; _normal seulement s'il y a
## du relief). Format des images et sens : voir make_wear.py (le haut de l'image va vers « up »).
const KINDS := {
	# coulures depuis un plafond, une fenêtre, un tuyau (haut de l'image = la source)
	"coulure": ["acg:Leaking001", "acg:Leaking003", "acg:Leaking005", "acg:Leaking002", "acg:Leaking007", "acg:Leaking009"],
	# cernes, dépôts de calcaire, marques d'eau séchée
	"cerne": ["acg:SurfaceImperfections009", "acg:SurfaceImperfections010"],
	# ronds de tasse ou de verre (plusieurs anneaux) : bruns (café) par défaut ; sur bois sombre verni,
	# opts.color = RING_LIGHT donne les auréoles blanchâtres de l'eau dans le vernis
	"rond_tasse": ["acg:SurfaceImperfections006", "acg:SurfaceImperfections005"],
	# poussière posée (dessus des meubles)
	"poussiere": ["acg:SurfaceImperfections014"],
	# salissure grasse, crasse de contact
	"salissure": ["acg:SurfaceImperfections017"],
	# traces de doigts (taches abstraites ; 1 = paume entière) : interrupteurs, poignées, portes ; verres,
	# miroirs, écrans avec opts.vitre = true
	"traces_doigts": ["acg:Fingerprints001", "acg:Fingerprints004"],
	# traînées (chiffon, savon, gras) : miroirs, vitres (opts.vitre = true), faïence
	"trainee": ["acg:Smear002", "acg:Smear005"],
	# éraflures fines (rayures parallèles, horizontales dans l'image) : plinthes, bas de portes, sols
	"eraflure": ["acg:Scratches001", "acg:Scratches004"],
	# rouille (bande, rouille en bas de l'image) : sous les robinets, pieds métalliques
	"rouille": ["acg:Rust001"],
	# auréoles d'eau au plafond (une variante par pièce : mere, couloir, amis, gp)
	"tache_plafond": ["tache_plafond_1", "tache_plafond_2", "tache_plafond_3", "tache_plafond_4"],
	# moisissure noire : 1 = bande le long du haut de l'image (jonction mur-plafond, coin à gauche),
	# 2 = colonie ronde
	"moisissure": ["moisissure_1", "moisissure_2"],
	# fissures de plâtre (2 : en diagonale depuis le coin bas gauche, comme d'un angle de porte)
	"fissure": ["fissure_1", "fissure_2", "fissure_3"],
	# suie : 1 = halo au plafond au-dessus d'une ampoule ; 2 = panache sur un mur (source en bas)
	"suie": ["suie_1", "suie_2"],
	# usure de passage sur un sol (v = le long du chemin), teintée selon le sol (path)
	"chemin_usure": ["chemin_usure_1", "chemin_usure_2"],
	# pieds nus mouillés (rugosité 0,2), orteils en haut ; variantes paires (0, 2, 4) = pied gauche
	"empreinte": ["empreinte_1", "empreinte_2", "empreinte_3", "empreinte_4", "empreinte_5", "empreinte_6"],
	# bande de pied de mur de 0,22 m (wall_base) : crasse juste au-dessus de la plinthe de 11 cm
	# (Builder.trim), poussière sur la plinthe et dans l'angle du sol ; périodique le long du mur
	"crasse_pied_mur": ["crasse_pied_mur_1", "crasse_pied_mur_2", "crasse_pied_mur_3"],
	# crasse d'angle, projetée en diagonale dans un coin de plafond (ceiling_corners)
	"coin": ["coin_1"],
}

## Réglages par genre (remplacés par opts) : profondeur de projection (m), albedo_mix, teinte (modulate),
## fondus le long de la normale.
const STYLE := {
	"coulure": {"depth": 0.16, "mix": 0.85},
	"cerne": {"depth": 0.1, "mix": 0.7},
	"rond_tasse": {"depth": 0.05, "mix": 0.75},
	"poussiere": {"depth": 0.08, "mix": 0.55, "color": Color(1.35, 1.32, 1.26)},
	"salissure": {"depth": 0.1, "mix": 0.55},
	"traces_doigts": {"depth": 0.05, "mix": 0.4},
	"trainee": {"depth": 0.05, "mix": 0.4},
	"eraflure": {"depth": 0.06, "mix": 0.7},
	"rouille": {"depth": 0.06, "mix": 0.95},
	"tache_plafond": {"depth": 0.3, "mix": 0.9},
	"moisissure": {"depth": 0.2, "mix": 0.95},
	"fissure": {"depth": 0.1, "mix": 1.0},
	"suie": {"depth": 0.3, "mix": 0.9},
	"chemin_usure": {"depth": 0.1, "mix": 0.65},
	"empreinte": {"depth": 0.08, "mix": 0.4},
	"crasse_pied_mur": {"depth": 0.12, "mix": 0.9},
	"coin": {"depth": 0.9, "mix": 0.9},
}

const NORMAL_FADE := 0.35
const FADE_BEGIN := 9.0
const FADE_LENGTH := 2.0
## Bande de pied de mur : longueur maximale d'un décalque (m) ; un tronçon plus long est coupé en
## morceaux égaux de la même variante (la texture est périodique : pas de couture).
const BAND_MAX := 3.2
## Largeur laissée libre de part et d'autre d'une porte (chambranle compris), en m.
const DOOR_MARGIN := 0.09
## Usure de passage selon le sol (HouseRoom.floor_kind) : teinte (proche de la couleur moyenne du sol,
## plus claire et plus grise : bois dont le vernis est parti, moquette tassée, carreaux ternis) et
## albedo_mix ; la rugosité (0,88, mélangée selon l'alpha) rend le chemin mat sur le parquet verni et
## sur l'émail des carreaux.
const PATH_TINT := {
	"parquet": Color(0.63, 0.51, 0.39), "moquette": Color(0.47, 0.32, 0.27), "carrelage": Color(0.57, 0.5, 0.44),
}
const PATH_MIX := {"parquet": 0.6, "moquette": 0.55, "carrelage": 0.3}
## Vitres, miroirs, écrans (opts.vitre = true) : facteurs sur albedo_mix et sur l'alpha (donc sur la
## rugosité apportée : un gras à 0,8 sur un verre à 0,05 brillait comme de la craie sous la lampe).
const VITRE_MIX := 0.3
const VITRE_ALPHA := 0.6
## Fondus le long de la normale des aides wall_base et ceiling_corners (leur boîte n'est pas centrée sur
## la surface : avec les 0,3 par défaut, la bande perdait un quart de sa force).
const HELPER_FADE := 0.08
## Auréoles d'eau blanchâtres dans un vernis sombre (rond_tasse, opts.color).
const RING_LIGHT := Color(1.6, 1.55, 1.45)
## Empreinte : taille du décalque (largeur, longueur) en m ; le pied en occupe environ 62 % × 88 %.
const FOOT_SIZE := Vector2(0.17, 0.29)

static var _tex := {}          # chemin -> Texture2D (null : absent)


# ------------------------------------------------------------------ fichiers

## Les fichiers de la première variante présente à partir de « variant » (en boucle) :
## {"albedo", "normal", "orm" (chemins, "" si absent), "name", "index"} ; {} si aucune.
static func files(kind: String, variant := 0) -> Dictionary:
	var list: Array = KINDS.get(kind, [])
	return first_existing(list, variant)


## Même chose pour une liste de variantes quelconque (pour les bancs d'essai).
static func first_existing(list: Array, start := 0) -> Dictionary:
	var n := list.size()
	for k in n:
		var i := posmod(start + k, n)
		var f := _paths(String(list[i]))
		if ResourceLoader.exists(f.albedo):
			f["index"] = i
			if not ResourceLoader.exists(f.normal):
				f.normal = ""
			if not ResourceLoader.exists(f.orm):
				f.orm = ""
			return f
	return {}


static func _paths(entry: String) -> Dictionary:
	if entry.begins_with("acg:"):
		var id := entry.substr(4)
		var soft_alb := GEN_DIR + "acg/" + id + "_albedo.png"
		var alb := soft_alb if ResourceLoader.exists(soft_alb) else ACG_DIR + id + "_albedo.png"
		return {"name": id, "albedo": alb, "normal": ACG_DIR + id + "_normal.png", "orm": ACG_DIR + id + "_orm.png"}
	return {"name": entry, "albedo": GEN_DIR + entry + "_albedo.png", "normal": GEN_DIR + entry + "_normal.png",
		"orm": GEN_DIR + entry + "_orm.png"}


static func _load(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex.has(path):
		if _tex.is_empty():
			_hook_release()
		_tex[path] = load(path) as Texture2D
	return _tex[path]


## Vide le cache des textures. Appelé tout seul quand Godot quitte (sortie de la racine de l'arbre) :
## sinon Godot signale des ressources encore utilisées à la sortie.
static func release() -> void:
	_tex = {}


static func _hook_release() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and not tree.root.tree_exiting.is_connected(release):
		tree.root.tree_exiting.connect(release)


## Nombre de variantes d'un genre (0 : genre inconnu).
static func variants(kind: String) -> int:
	return (KINDS.get(kind, []) as Array).size()


# ------------------------------------------------------------------ règles

## Décalques décoratifs permis : vraie carte graphique et préréglage au-dessus de Basse.
static func deco_on() -> bool:
	if Qualite.soft():
		return false
	return Qualite.effective() > Qualite.BASSE


## Hachage entier déterministe (32 bits) d'une position, au centimètre, et d'un sel.
static func hash_pos(p: Vector3, salt := 0) -> int:
	var h := 2166136261
	for c in [roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0), salt]:
		h = ((h ^ (int(c) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 2246822519) & 0xFFFFFFFF
	h ^= h >> 13
	return h


## Nombre pseudo-aléatoire déterministe dans [0, 1) tiré de la position (aucun randf()).
static func hash01(p: Vector3, salt := 0) -> float:
	return float(hash_pos(p, salt) % 65521) / 65521.0


## Repère d'un décalque : Y = normale (sortant de la surface), -Z = « up » (le haut de l'image),
## tourné de « rot » radians autour de la normale.
static func basis_for(normal: Vector3, up: Vector3, rot := 0.0) -> Basis:
	var y := normal.normalized()
	var u := up - y * up.dot(y)
	if u.length() < 1e-4:
		u = Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT
		u = u - y * u.dot(y)
	var z := -u.normalized()
	var x := y.cross(z)
	var b := Basis(x, y, z)
	if rot != 0.0:
		b = Basis(y, rot) * b
	return b


# ------------------------------------------------------------------ décalque

## Pose un décalque d'usure sur « parent ». center, normal, up : dans le repère de « parent » (comme
## position), ou du monde avec opts.world = true. normal sort de la surface ; up = le haut de l'image.
## size_u × size_v : taille sur la surface (m).
## opts : variant (int ; sinon hachage de la position), story (bool : existe aussi en rendu logiciel),
##   depth (m, épaisseur de projection), color (Color : teinte et alpha), alpha (multiplie l'alpha),
##   mix (albedo_mix), vitre (bool : vitre, miroir, écran ; mix × VITRE_MIX, alpha × VITRE_ALPHA), rot (degrés autour de la
##   normale), normal_fade, upper_fade, lower_fade,
##   fade_begin, fade_length (distance_fade), cull_mask, name, world (bool).
## Rend le Decal (déjà dans l'arbre), ou null (rendu logiciel hors récit, Basse, genre ou fichiers absents).
static func decal(parent: Node, kind: String, center: Vector3, normal: Vector3, up: Vector3, size_u: float, size_v: float, opts := {}) -> Decal:
	var story := bool(opts.get("story", false))
	if parent == null or (not story and not deco_on()):
		return null
	if not KINDS.has(kind):
		push_warning("Wear.decal : genre inconnu : %s" % kind)
		return null
	var vi := int(opts.get("variant", -1))
	if vi < 0:
		vi = hash_pos(center, kind.hash() & 0xFFFF)
	var f := files(kind, vi)
	if f.is_empty():
		return null
	var st: Dictionary = STYLE.get(kind, {})
	var d := Decal.new()
	d.name = String(opts.get("name", "Usure_" + kind))
	d.texture_albedo = _load(f.albedo)
	d.texture_normal = _load(f.normal)
	d.texture_orm = _load(f.orm)
	d.size = Vector3(maxf(size_u, 0.001), maxf(float(opts.get("depth", st.get("depth", 0.2))), 0.001), maxf(size_v, 0.001))
	var col: Color = opts.get("color", st.get("color", Color.WHITE))
	col.a *= float(opts.get("alpha", 1.0))
	if bool(opts.get("vitre", false)):
		col.a *= VITRE_ALPHA
	d.modulate = col
	var mix := float(opts.get("mix", st.get("mix", 1.0)))
	if bool(opts.get("vitre", false)):
		mix *= VITRE_MIX
	d.albedo_mix = clampf(mix, 0.0, 1.0)
	d.normal_fade = float(opts.get("normal_fade", NORMAL_FADE))
	d.upper_fade = float(opts.get("upper_fade", st.get("upper_fade", 0.3)))
	d.lower_fade = float(opts.get("lower_fade", st.get("lower_fade", 0.3)))
	d.distance_fade_enabled = true
	d.distance_fade_begin = float(opts.get("fade_begin", FADE_BEGIN))
	d.distance_fade_length = float(opts.get("fade_length", FADE_LENGTH))
	d.cull_mask = int(opts.get("cull_mask", 1))
	var xf := Transform3D(basis_for(normal, up, deg_to_rad(float(opts.get("rot", 0.0)))), center)
	var world := bool(opts.get("world", false)) and parent is Node3D
	if not world:
		d.transform = xf
	parent.add_child(d, true)
	if world:
		var p3 := parent as Node3D
		if p3.is_inside_tree():
			d.global_transform = xf
		else:
			d.transform = p3.transform.affine_inverse() * xf
	d.add_to_group("usure")
	d.set_meta("usure", kind)
	d.set_meta("variante", int(f.index))
	return d


# ------------------------------------------------------------------ aides

## Les ouvertures (portes et fenêtres de HouseData) qui coupent une bande de « band_top » m de haut sur
## le mur de la pièce dont la face intérieure est à « face » (axis "x" : mur placé en x = face, qui court
## le long de z ; "z" : l'inverse) : [[de, à], …] le long du mur, chambranles compris.
static func openings(axis: String, face: float, band_top: float) -> Array:
	var out := []
	if axis == "x":
		for d in HouseData.F1_DOORS:
			if absf(float(d.at) - face) < 0.1:
				out.append([float(d.c) - float(d.w) / 2.0 - DOOR_MARGIN, float(d.c) + float(d.w) / 2.0 + DOOR_MARGIN])
	for w in HouseData.F1_WINDOWS:
		if String(w.axis) == axis and absf(float(w.at) - face) < 0.1 and float(w.y0) - HouseData.F1_Y < band_top:
			out.append([float(w.c) - float(w.w) / 2.0 - 0.06, float(w.c) + float(w.w) / 2.0 + 0.06])
	return out


## [[a, b]] moins les intervalles « gaps » ; tronçons de plus de « min_len » m.
static func subtract_spans(a: float, b: float, gaps: Array, min_len := 0.15) -> Array:
	var spans := [[a, b]]
	for g in gaps:
		var nxt := []
		for s in spans:
			var g0 := float(g[0])
			var g1 := float(g[1])
			if g1 <= s[0] or g0 >= s[1]:
				nxt.append(s)
				continue
			if g0 > s[0]:
				nxt.append([s[0], g0])
			if g1 < s[1]:
				nxt.append([g1, s[1]])
		spans = nxt
	var out := []
	for s in spans:
		if s[1] - s[0] >= min_len:
			out.append(s)
	return out


## Crasse de pied de mur : une bande de « h » m (0,22 par défaut) par tronçon de mur plein de la pièce,
## en sautant les portes et les fenêtres basses de HouseData (lecture seule) ; un tronçon de plus de
## BAND_MAX est coupé en morceaux égaux qui se raccordent. Projetée à 4 cm de la face du mur sur 12 cm
## d'épaisseur : papier peint, lambris et plinthe. opts : ceux de decal() (color, alpha, mix, variant…),
## plus sides (Array de "x0", "x1", "z0", "z1" : côtés à traiter, tous par défaut) et gaps (Array de
## Rect2 en x, z : zones à laisser libres, meubles encastrés, radiateurs…).
## Rend les décalques posés (tableau vide en rendu logiciel ou en Basse).
static func wall_base(room: HouseRoom, h := 0.22, opts := {}) -> Array:
	var out := []
	if room == null or not deco_on():
		return out
	var r := room.rect
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	# [nom, axe du mur, face, de, à, normale vers l'intérieur]
	var sides := [
		["x0", "x", x0, z0, z1, Vector3.RIGHT], ["x1", "x", x1, z0, z1, Vector3.LEFT],
		["z0", "z", z0, x0, x1, Vector3.BACK], ["z1", "z", z1, x0, x1, Vector3.FORWARD],
	]
	var only: Array = opts.get("sides", [])
	var extra: Array = opts.get("gaps", [])
	for sd in sides:
		if not only.is_empty() and not only.has(sd[0]):
			continue
		var axis: String = sd[1]
		var face: float = sd[2]
		var gaps := openings(axis, face, h)
		for g in extra:
			var rc := (g as Rect2).grow(0.02)
			var near: bool = (rc.position.x <= face + 0.15 and rc.end.x >= face - 0.15) if axis == "x" \
				else (rc.position.y <= face + 0.15 and rc.end.y >= face - 0.15)
			if near:
				gaps.append([rc.position.y, rc.end.y] if axis == "x" else [rc.position.x, rc.end.x])
		var inward: Vector3 = sd[5]
		var o := opts.duplicate()
		o.world = true
		if not o.has("upper_fade"):
			o.upper_fade = HELPER_FADE
		if not o.has("lower_fade"):
			o.lower_fade = HELPER_FADE
		if not o.has("variant"):
			o.variant = hash_pos(Vector3(face, room.y0, 0.0), (String(room.room_id).hash() & 0xFFFF) + int(axis == "z"))
		for sp in subtract_spans(sd[3], sd[4], gaps):
			var n := ceili((sp[1] - sp[0]) / BAND_MAX - 0.001)
			var seg: float = (sp[1] - sp[0]) / n
			for i in n:
				var mid: float = sp[0] + seg * (i + 0.5)
				var c := Vector3(face, room.y0 + h / 2.0, mid) if axis == "x" else Vector3(mid, room.y0 + h / 2.0, face)
				c += inward * 0.04
				var d := decal(room, "crasse_pied_mur", c, inward, Vector3.UP, seg, h, o)
				if d:
					out.append(d)
	return out


## Crasse dans les quatre coins du plafond (genre « coin », projeté en diagonale : les deux murs et le
## plafond). opts : ceux de decal(), plus size (m, 0,8 par défaut), kind (autre genre) et only (Array
## d'indices de coins : 0 = (x0, z0), 1 = (x1, z0), 2 = (x0, z1), 3 = (x1, z1)).
static func ceiling_corners(room: HouseRoom, opts := {}) -> Array:
	var out := []
	if room == null or not deco_on():
		return out
	var r := room.rect
	var size := float(opts.get("size", 0.8))
	var kind := String(opts.get("kind", "coin"))
	var only: Array = opts.get("only", [])
	var top := room.y0 + room.h
	var corners := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)]
	for i in corners.size():
		if not only.is_empty() and not only.has(i):
			continue
		var cxz: Vector2 = corners[i]
		var sx := 1.0 if i % 2 == 0 else -1.0
		var sz := 1.0 if i < 2 else -1.0
		var c := Vector3(cxz.x, top, cxz.y)
		var nrm := Vector3(sx, -1.0, sz).normalized()
		var o := opts.duplicate()
		o.world = true
		if not o.has("depth"):
			o.depth = size * 1.2
		if not o.has("upper_fade"):
			o.upper_fade = HELPER_FADE
		if not o.has("lower_fade"):
			o.lower_fade = HELPER_FADE
		if not o.has("rot"):
			o.rot = hash01(c, 7) * 360.0
		var d := decal(room, kind, c, nrm, Vector3.UP, size, size, o)
		if d:
			out.append(d)
	return out


## Usure de passage sur le sol de la pièce (genre « chemin_usure » : plus clair et plus mat), le long
## d'une ligne brisée « points » (Vector3 du monde, ou Vector2 en x, z), « width » m de large. Teinte et
## albedo_mix selon room.floor_kind (PATH_TINT, PATH_MIX), sinon opts.color et opts.mix. Un décalque par
## segment, prolongé de width / 4 aux deux bouts (les fondus des extrémités se recouvrent).
static func path(room: HouseRoom, points: Array, width := 0.5, opts := {}) -> Array:
	var out := []
	if room == null or points.size() < 2 or not deco_on():
		return out
	var pts: Array[Vector3] = []
	for p in points:
		pts.append(Vector3(p.x, room.y0, p.y) if p is Vector2 else Vector3(p.x, room.y0, p.z))
	var base_v := int(opts.get("variant", hash_pos(pts[0], 31)))
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := b - a
		var ln := dir.length()
		if ln < 0.05:
			continue
		var o := opts.duplicate()
		o.world = true
		o.variant = base_v + i
		if not o.has("color"):
			o.color = PATH_TINT.get(room.floor_kind, PATH_TINT.parquet)
		if not o.has("mix"):
			o.mix = PATH_MIX.get(room.floor_kind, PATH_MIX.parquet)
		var d := decal(room, "chemin_usure", (a + b) / 2.0, Vector3.UP, dir / ln, width, ln + width * 0.5, o)
		if d:
			out.append(d)
	return out


## Empreintes de pieds nus mouillés (genre « empreinte », story = true par défaut : elles existent aussi
## en rendu logiciel). Deux façons :
##  - opts.each = true : une empreinte par point de « points » (positions exactes, pied gauche d'abord
##    sauf opts.first_left = false), orientée selon les points de même côté (i - 2, i + 2) ou opts.dir ;
##  - sinon : « points » est une ligne brisée parcourue à pas irréguliers (opts.stride, 0,34 m ± 10 %),
##    pieds écartés de opts.spread (0,17 m).
## Chaque pied : pointe tournée vers l'extérieur de 5°, plus ±8° tirés du hachage de sa position.
## Alpha : opts.alphas (Array, un par pas) ou un fondu de opts.fade_from (1,0) à opts.fade_to (0,45).
## Autres opts : size (Vector2, FOOT_SIZE), color, mix, depth, world, story, et ceux de decal().
## points : Vector3 dans le repère de « parent » (ou du monde avec opts.world). Rend les décalques.
static func footprints(parent: Node, points: Array, opts := {}) -> Array:
	var out := []
	var story := bool(opts.get("story", true))
	if parent == null or points.is_empty() or (not story and not deco_on()):
		return out
	var steps := []      # [position, direction, gauche ?]
	var first_left := bool(opts.get("first_left", true))
	var n := points.size()
	if bool(opts.get("each", false)):
		var gdir: Vector3 = opts.get("dir", (points[n - 1] - points[0]) if n > 1 else Vector3.FORWARD)
		for i in n:
			var j1 := i - 2 if i >= 2 else i
			var j2 := i + 2 if i + 2 < n else i
			var t: Vector3 = points[j2] - points[j1] if j1 != j2 else gdir
			steps.append([points[i], t, (i % 2 == 0) == first_left])
	else:
		var stride := float(opts.get("stride", 0.34))
		var spread := float(opts.get("spread", 0.17))
		var total := 0.0
		for i in n - 1:
			total += (points[i + 1] - points[i]).length()
		var s := 0.0
		var k := 0
		var seg := 0
		var seg_start := 0.0
		while s <= total + 1e-4 and n > 1:
			while seg < n - 2 and s > seg_start + (points[seg + 1] - points[seg]).length():
				seg_start += (points[seg + 1] - points[seg]).length()
				seg += 1
			var a: Vector3 = points[seg]
			var b: Vector3 = points[seg + 1]
			var sl := (b - a).length()
			var t := (b - a) / maxf(sl, 1e-5)
			var p := a + t * clampf(s - seg_start, 0.0, sl)
			var left := (k % 2 == 0) == first_left
			var side := Vector3.UP.cross(t).normalized()          # vers la gauche de la marche
			p += side * (spread / 2.0) * (1.0 if left else -1.0)
			steps.append([p, t, left])
			s += stride * (0.9 + 0.2 * hash01(p, 11))
			k += 1
	var alphas: Array = opts.get("alphas", [])
	var fa := float(opts.get("fade_from", 1.0))
	var fb := float(opts.get("fade_to", 0.45))
	var size: Vector2 = opts.get("size", FOOT_SIZE)
	var nv := variants("empreinte")
	for i in steps.size():
		var p: Vector3 = steps[i][0]
		var t: Vector3 = steps[i][1]
		var left: bool = steps[i][2]
		t.y = 0.0
		if t.length() < 1e-4:
			t = Vector3.FORWARD
		var o := opts.duplicate()
		o.erase("each")
		o.story = story
		var al := float(alphas[i]) if i < alphas.size() else lerpf(fa, fb, float(i) / maxf(1.0, steps.size() - 1.0))
		var col: Color = opts.get("color", Color.WHITE)
		col.a *= al
		o.color = col
		# pointe vers l'extérieur (gauche : vers la gauche = rotation positive autour du haut) et ±8°
		o.rot = (5.0 if left else -5.0) + (hash01(p, 13) * 2.0 - 1.0) * 8.0
		# variante du bon pied : paires = gauche, impaires = droit ; la suivante du même pied si absente
		var k3 := hash_pos(p, 17) % 3
		var chosen := -1
		for tries in 3:
			var vi := ((k3 + tries) % 3) * 2 + (0 if left else 1)
			if vi < nv and not files("empreinte", vi).is_empty() and int(files("empreinte", vi).index) == vi:
				chosen = vi
				break
		if chosen < 0:
			continue
		o.variant = chosen
		var d := decal(parent, "empreinte", p, Vector3.UP, t, size.x, size.y, o)
		if d:
			d.set_meta("pied", "gauche" if left else "droit")
			out.append(d)
	return out
