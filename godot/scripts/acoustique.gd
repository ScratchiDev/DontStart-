class_name Acoustique
extends Node
## Acoustique de l'étage (passe « triple A », lot V2-SON). Sfx.on_house_built le crée sous « House » (pas
## sous une HouseRoom : furniture_boxes et _scan_rugs ne le voient pas), nommé « Acoustique ».
##
## 1) Zones et réverbération. ATTENTION, mesuré sur la 4.7.2 : un AudioStreamPlayer3D qui se trouve dans une
##    Area3D à réverbération PERD son son direct si la zone ne redirige pas aussi le bus (audio_bus_override) :
##    seule la part réverbérée reste. Chaque zone redirige donc le son direct ET envoie vers la réverbération.
##    Comme la redirection remplace le bus du lecteur, les lecteurs sont répartis en « routes » (bus d'origine,
##    occlusion ou non), chacune sur sa couche de collision (ROUTES : Master 20 = Builder.LAYER_ACOUSTIC,
##    Ambiance 21, Voix 22, Master sans occlusion 23, Ambiance sans occlusion 24, les suivantes à la demande) ;
##    chaque route a une Area3D par pièce (« Zone_<pièce>_<route> », masque 0, ni monitoring ni monitorable),
##    au rectangle intérieur de la pièce (HouseData.F1_ROOMS). area_mask d'un lecteur = la couche de sa route
##    (mask_for). Réverbérations : Rev_feutree, Rev_chambre, Rev_couloir, Rev_carrelage, Rev_cage
##    (AudioEffectReverb 100 % réverbéré, vers Master).
## 2) Occlusion : la « classe d'écoute » d'une pièce (« meme », « ouverte », « entrouverte », « fermee »,
##    « loin ») vient du plus court chemin entre la pièce de l'auditeur et elle, dans le graphe des pièces :
##    portes (Door.leaf_angle_deg(), lecture seule ; ouverte, entrouverte ou fermée, avec hystérésis) et
##    cloisons mitoyennes. Les zones d'une route occultée redirigent vers « <bus>~<classe> » (passe-bas et
##    volume, renvoyé vers le bus d'origine : le silence de l'entité coupe donc toujours l'Ambiance). La
##    réverbération d'une pièce occultée passe par « Rev_sourd » (passe-bas, puis réverbération) ; « loin »,
##    elle est coupée : pas de queue claire derrière une porte fermée.
##    Hors des zones (plan d'une porte, mur, dehors), le lecteur garde son bus, réglé ici toutes les TICK s
##    (class_at) : une source à moins de DOOR_PLANE du plan d'une porte (coups, poignée, clé) est entendue
##    directement des deux côtés ; pour la réverbération de ces sons ponctuels, Sfx joue un « jumeau » vers la
##    réverbération de la pièce de l'auditeur (twin_send). Pas de bascule pendant les MIN_AGE_MS premières
##    millisecondes d'un son. Le bus « Voix » et les lecteurs « sans_occlusion » ne sont jamais filtrés.
## 3) Selon la pièce de l'auditeur : le tonnerre (bus « Tonnerre », passe-bas selon les fenêtres de la
##    pièce) et les pas du joueur (bus « Joueur » : réverbération de la pièce, le son direct intact).
## 4) La pluie aux fenêtres : une boucle douce derrière chaque fenêtre de HouseData.F1_WINDOWS (plus
##    discrète derrière un store baissé ou un verre dépoli, plus forte derrière une fenêtre ouverte :
##    set_window_open), et un fond « pluie sur le toit », plat, sur le bus Ambiance.
## 5) La maison qui vit (lot V2-CREATURE), toujours sur le bus Ambiance, pour que le silence de l'entité
##    s'entende partout : le vent contre la maison (boucle plate), le compresseur du frigo en bas (par la
##    cage d'escalier), et de temps en temps (MAISON_EVERY s) la charpente qui travaille ou les tuyaux du
##    chauffage, dans une pièce voisine (jamais pendant un dialogue, une scène écrite ou un silence).
## La logique (fonctions statiques) est vérifiée sans nœud par tests/acoustique_banc.gd. Aucun tirage du
## hasard global (randf, randi) : l'ordre des tirages du jeu ne change pas.

const D := preload("res://scripts/house/house_data.gd")

const TICK := 0.1
const MIN_AGE_MS := 50
## Masque de la route « Master » (couche Builder.LAYER_ACOUSTIC).
const AREA_MASK := 1 << (Builder.LAYER_ACOUSTIC - 1)
## Bus d'origine dont les sons sont filtrés par l'occlusion (Sfx.ensure_bus(…, true) en ajoute).
const OCCLUDED_DEFAULT := ["Master", "Ambiance"]
## Routes connues d'avance : clé -> couche de collision. Clé : le bus, suivi de « ! » s'il n'est pas occulté.
const ROUTES := {"Master": 20, "Ambiance": 21, "Voix!": 22, "Master!": 23, "Ambiance!": 24}
const ROUTE_LAYER_MAX := 32
## Retrait des zones dans le rectangle de la pièce : le plan des portes et les murs restent hors zone.
const ZONE_INSET := 0.02

## Classes d'écoute, de la plus claire à la plus étouffée : [coupure du passe-bas (Hz), raideur
## (AudioEffectFilter.db : 0 = 12 dB par octave, 1 = 24), volume du bus (dB)]. Gains calibrés au banc
## (acoustique_banc --calibrage) pour que les sons écrits à travers une porte (pas de l'ouverture de l'acte I,
## ronflement, respiration derrière P2) gardent leur niveau perçu à ±3 dB : le passe-bas étouffe, il ne doit
## pas faire disparaître.
## Lot V2-CREATURE : derrière une porte fermée, le son s'éloigne vraiment (-5 dB ; « loin » -10 dB : on doit
## tendre l'oreille). Les sons écrits calibrés au banc (Sfx.STORY_SOUNDS, méta « recit ») gardent leur niveau :
## leur lecteur reçoit RECIT_COMP en plus dans ces classes (le calibrage de V2-SON : +0,5 et -3 dB).
const CLASSES := {
	"meme": [0.0, 0, 0.0],
	"ouverte": [7500.0, 0, -0.5],
	"entrouverte": [2400.0, 0, -1.5],
	"fermee": [1100.0, 1, -5.0],
	"loin": [420.0, 1, -10.0],
}
const RECIT_COMP := {"fermee": 5.5, "loin": 7.0}
const CLASS_ORDER := ["meme", "ouverte", "entrouverte", "fermee", "loin"]

## Coûts de passage (en « dB » d'isolement) : porte ouverte, entrouverte, fermée (P6, vitrée : moins),
## cloison mitoyenne, et chaque pièce traversée. Seuils des classes sur le coût du meilleur chemin.
const COST_OPEN := 1.5
const COST_AJAR := 4.0
const COST_SHUT := 9.0
const COST_SHUT_GLASS := 7.0
const COST_WALL := 11.0
const COST_ROOM := 1.0
const CLASS_MAX := [["ouverte", 3.0], ["entrouverte", 7.0], ["fermee", 13.0]]

## Ouverture d'une porte (angle du battant / OPEN_FULL_DEG) : 0 fermée, 1 entrouverte, 2 ouverte. On entre
## dans un état au seuil « IN », on n'en sort que sous le seuil « OUT » (pas de va-et-vient).
const OPEN_FULL_DEG := 92.8
const AJAR_IN := 0.1
const AJAR_OUT := 0.06
const OPEN_IN := 0.5
const OPEN_OUT := 0.4
const DOOR_PLANE := 0.2       # une source à moins de 20 cm du plan d'une porte est dans les deux pièces

## Réverbération de chaque pièce : [bus, part envoyée (Area3D.reverb_bus_amount), uniformité].
const PIECES := {
	"mere": ["Rev_chambre", 0.3, 0.4],
	"gp": ["Rev_chambre", 0.3, 0.4],
	"amis": ["Rev_feutree", 0.24, 0.3],
	"bureau": ["Rev_feutree", 0.22, 0.3],
	"couloir": ["Rev_couloir", 0.34, 0.55],
	"sdb": ["Rev_carrelage", 0.5, 0.5],
	"lingerie": ["Rev_carrelage", 0.42, 0.5],
	"escalier": ["Rev_cage", 0.48, 0.6],
}
## Bus de réverbération (AudioEffectReverb, dry 0, wet 1 : ce sont des envois). ATTENTION, mesuré sur la
## 4.7.2 (bande 2-6 kHz) : un « damping » ÉLEVÉ donne une queue PLUS BRILLANTE (aigus plus longs) ;
## room_size 0,05 donne déjà 0,6 s, 0,6 environ 1,5 s. D'où le carrelage à 0,92 et la moquette à 0,1.
## « hipass » coupe vite : 0,1 retire déjà 10 dB entre 120 et 250 Hz, 0,2 coupe sous 1 kHz (un coup sourd
## n'aurait plus de réverbération) : on reste entre 0 et 0,04.
const REVERBS := {
	"Rev_feutree": {"room_size": 0.05, "damping": 0.1, "spread": 0.5, "hipass": 0.04, "predelay_msec": 6.0, "predelay_feedback": 0.1},
	"Rev_chambre": {"room_size": 0.16, "damping": 0.3, "spread": 0.7, "hipass": 0.03, "predelay_msec": 9.0, "predelay_feedback": 0.15},
	"Rev_couloir": {"room_size": 0.36, "damping": 0.55, "spread": 0.9, "hipass": 0.02, "predelay_msec": 12.0, "predelay_feedback": 0.2},
	"Rev_carrelage": {"room_size": 0.42, "damping": 0.92, "spread": 0.8, "hipass": 0.02, "predelay_msec": 5.0, "predelay_feedback": 0.25},
	"Rev_cage": {"room_size": 0.62, "damping": 0.6, "spread": 1.0, "hipass": 0.02, "predelay_msec": 22.0, "predelay_feedback": 0.2},
}
## Réverbération entendue à travers une cloison ou une porte : passe-bas (Hz, raideur), puis réverbération.
const SOURD := {"cutoff_hz": 650.0, "db": 1,
	"reverb": {"room_size": 0.3, "damping": 0.2, "spread": 0.8, "hipass": 0.0, "predelay_msec": 15.0, "predelay_feedback": 0.1}}
## Part envoyée par une pièce occultée, relative à sa part normale (le son direct y est aussi plus faible).
const SOURD_SEND := {"ouverte": 0.85, "entrouverte": 0.6, "fermee": 0.45}
## Pas du joueur (bus « Joueur ») : réverbération de la pièce de l'auditeur, à cette part de son envoi.
const JOUEUR_WET := 0.7

## Tonnerre selon les fenêtres de la pièce de l'auditeur : [coupure (Hz), volume (dB)] ; la meilleure fenêtre
## de la pièce compte (vitre claire, verre dépoli, store baissé, aucune fenêtre).
const TONNERRE := {"claire": [20000.0, 0.0], "depoli": [7000.0, -1.0], "store": [3200.0, -2.0], "aucune": [1600.0, -4.0]}

## Pluie : boucle par fenêtre (rain_glass_1 à 3), volume de base et corrections.
const RAIN_SOUNDS := ["rain_glass_1", "rain_glass_2", "rain_glass_3"]
const RAIN_DB := -15.0
const RAIN_DB_EXISTING := -4.0   # F1 : outside.gd joue déjà rain_loop devant la vitre (-10 dB)
const RAIN_DB_BLIND := -5.0
const RAIN_DB_FROSTED := -1.5
const RAIN_DB_SMALL := -2.0      # petite fenêtre (moins de 1 m)
const RAIN_DB_OPEN := 7.0        # fenêtre ouverte (set_window_open)
const RAIN_UNIT := 1.1
const RAIN_MAX_DISTANCE := 14.0
const RAIN_INSIDE := 0.22        # la boucle est posée à 22 cm à l'intérieur de la vitre
const ROOF_SOUND := "rain_roof"
const ROOF_DB := -27.0

## La maison (lot V2-CREATURE) : vent (plat), frigo (en bas, sous la cage d'escalier), bruits épars.
const VENT_SOUND := "maison/vent"
const VENT_DB := -31.0
const FRIGO_SOUND := "maison/frigo"
const FRIGO_DB := -16.0
const FRIGO_POS := Vector3(7.6, -2.3, 0.9)
const FRIGO_UNIT := 1.2
const MAISON_EVERY := [25.0, 70.0]
const MAISON_FIRST := [8.0, 20.0]
## [son, nombre de variantes, volume (dB), hauteur (m au-dessus du plancher), unit_size, variation de hauteur]
const MAISON_SOUNDS := [["maison/charpente_%d", 4, -15.0, 2.45, 1.6, 0.08], ["maison/tuyau_%d", 3, -17.0, 0.25, 1.4, 0.05]]

static var occludable: Array = OCCLUDED_DEFAULT.duplicate()
static var routes := ROUTES.duplicate()        # clé de route -> couche (les nouvelles s'ajoutent)
static var _edges: Array = []     # [pièce a, pièce b, id de porte ou "" pour une cloison, porte vitrée]

var house: Node
var listener_room := ""
var door_states := {}           # id de porte -> 0, 1 ou 2
var room_class := {}            # id de pièce -> classe d'écoute (depuis la pièce de l'auditeur)
var room_cost := {}             # id de pièce -> coût du meilleur chemin
var zones := {}                 # clé de route -> {id de pièce -> Area3D}
var rain := {}                  # id de fenêtre -> AudioStreamPlayer3D
var roof: AudioStreamPlayer
var open_windows := {}          # id de fenêtre -> true
var vent: AudioStreamPlayer
var frigo: AudioStreamPlayer3D
var maison_next := 0.0          # s avant le prochain bruit de la maison
var maison_log: Array = []      # [son, pièce] des bruits joués (bancs)
var _players: Array = []        # AudioStreamPlayer3D enregistrés (register)
var _t := 0.0
var _fresh := false
var _rng := RandomNumberGenerator.new()


# ------------------------------------------------------------------ logique (statique, testée au banc)

## Pièce de l'étage qui contient p (rectangles de HouseData, à demi-cloison près), ou "". Sous le plancher,
## seule la cage d'escalier continue.
static func room_at(p: Vector3) -> String:
	if p.y > D.F1_Y + D.F1_H + 0.6:
		return ""
	var m := D.WALL / 2.0
	for id in D.F1_ROOMS:
		var r: Array = D.F1_ROOMS[id].rect
		if p.y < D.F1_Y - 0.6 and id != "escalier":
			continue
		if p.x >= r[0] - m and p.x <= r[1] + m and p.z >= r[2] - m and p.z <= r[3] + m:
			return id
	return ""


## Les deux pièces d'une porte (de part et d'autre de son mur, à 30 cm).
static func door_rooms(d: Dictionary) -> Array:
	return [room_at(Vector3(float(d.at) - 0.3, 1.0, float(d.c))), room_at(Vector3(float(d.at) + 0.3, 1.0, float(d.c)))]


## Deux pièces séparées par une seule cloison et qui se font face sur au moins 0,5 m ?
static func share_wall(a: String, b: String) -> bool:
	var ra: Array = D.F1_ROOMS[a].rect
	var rb: Array = D.F1_ROOMS[b].rect
	var gap_x := maxf(float(rb[0]) - float(ra[1]), float(ra[0]) - float(rb[1]))
	var gap_z := maxf(float(rb[2]) - float(ra[3]), float(ra[2]) - float(rb[3]))
	var over_z := minf(float(ra[3]), float(rb[3])) - maxf(float(ra[2]), float(rb[2]))
	var over_x := minf(float(ra[1]), float(rb[1])) - maxf(float(ra[0]), float(rb[0]))
	return (absf(gap_x - D.WALL) < 0.03 and over_z > 0.5) or (absf(gap_z - D.WALL) < 0.03 and over_x > 0.5)


## Arêtes du graphe des pièces : une par porte, une par cloison mitoyenne.
static func edges() -> Array:
	if _edges.is_empty():
		for d in D.F1_DOORS:
			var rr := door_rooms(d)
			if rr[0] != "" and rr[1] != "":
				_edges.append([rr[0], rr[1], String(d.id), bool(d.get("glass", false))])
		var ids: Array = D.F1_ROOMS.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				if share_wall(ids[i], ids[j]):
					_edges.append([ids[i], ids[j], "", false])
	return _edges


## État d'une porte d'après son ouverture (angle / OPEN_FULL_DEG), avec hystérésis sur l'état d'avant.
static func door_state(ratio: float, prev := -1) -> int:
	if ratio >= OPEN_IN or (prev == 2 and ratio >= OPEN_OUT):
		return 2
	if ratio >= AJAR_IN or (prev >= 1 and ratio >= AJAR_OUT):
		return 1
	return 0


static func door_cost(state: int, glass := false) -> float:
	match state:
		2:
			return COST_OPEN
		1:
			return COST_AJAR
	return COST_SHUT_GLASS if glass else COST_SHUT


## Coût du meilleur chemin de la pièce « from » à chaque pièce (Dijkstra sur 8 pièces). states : id de
## porte -> état (0, 1, 2) ; une porte absente compte fermée.
static func costs_from(from: String, states: Dictionary) -> Dictionary:
	var dist := {}
	for id in D.F1_ROOMS:
		dist[id] = INF
	if not dist.has(from):
		return dist
	dist[from] = 0.0
	var todo: Array = D.F1_ROOMS.keys()
	while not todo.is_empty():
		var best := 0
		for i in todo.size():
			if float(dist[todo[i]]) < float(dist[todo[best]]):
				best = i
		var u: String = todo[best]
		todo.remove_at(best)
		if is_inf(float(dist[u])):
			break
		for e in edges():
			var v := ""
			if e[0] == u:
				v = e[1]
			elif e[1] == u:
				v = e[0]
			else:
				continue
			var c := COST_WALL if e[2] == "" else door_cost(int(states.get(e[2], 0)), bool(e[3]))
			# chaque pièce traversée (ni celle de l'auditeur, ni celle de la source) ajoute COST_ROOM
			var nd := float(dist[u]) + c + (COST_ROOM if u != from else 0.0)
			if nd < float(dist[v]):
				dist[v] = nd
	return dist


## Classe d'écoute pour un coût de chemin.
static func class_of_cost(c: float) -> String:
	if c <= 0.0:
		return "meme"
	for k in CLASS_MAX:
		if c <= float(k[1]):
			return k[0]
	return "loin"


## Pièces d'une porte dont le plan passe à moins de DOOR_PLANE de p (coups, poignée, clé), sinon [].
static func door_plane_rooms(p: Vector3) -> Array:
	for d in D.F1_DOORS:
		if absf(p.x - float(d.at)) < DOOR_PLANE and absf(p.z - float(d.c)) < float(d.w) / 2.0 + 0.1 \
				and p.y > D.F1_Y - 0.3 and p.y < D.F1_Y + D.F1_H:
			return door_rooms(d)
	return []


## Le point est-il dans une zone (rectangle intérieur d'une pièce, moins ZONE_INSET) ?
static func in_zone(p: Vector3) -> bool:
	for id in D.F1_ROOMS:
		var r: Array = D.F1_ROOMS[id].rect
		var y_lo := D.F1_Y - (3.0 if id == "escalier" else 0.3)
		if p.y < y_lo or p.y > D.F1_Y + D.F1_H + 0.3:
			continue
		if p.x > float(r[0]) + ZONE_INSET and p.x < float(r[1]) - ZONE_INSET \
				and p.z > float(r[2]) + ZONE_INSET and p.z < float(r[3]) - ZONE_INSET:
			return true
	return false


## Pièce d'une source : celle qui la contient ; dehors, à moins de 4 m d'une fenêtre, la pièce de cette
## fenêtre (la pluie et le jardin s'entendent par la vitre) ; sinon "".
static func source_room(p: Vector3) -> String:
	var r := room_at(p)
	if r != "":
		return r
	var best := ""
	var best_d := 4.0
	for w in D.F1_WINDOWS:
		var wp := window_point(w, 0.0)
		var dd := Vector2(p.x - wp.x, p.z - wp.z).length()
		if dd < best_d:
			best_d = dd
			best = String(w.room)
	return best


## Point au centre d'une fenêtre, « inside » mètres à l'intérieur de la pièce.
static func window_point(w: Dictionary, inside: float) -> Vector3:
	var y := D.F1_Y + (float(w.y0) + float(w.y1)) / 2.0
	if w.axis == "x":
		var dir := 1.0 if float(w.at) < 3.0 else -1.0
		return Vector3(float(w.at) + dir * inside, y, float(w.c))
	var dz := 1.0 if float(w.at) < 0.0 else -1.0
	return Vector3(float(w.c), y, float(w.at) + dz * inside)


## La meilleure fenêtre d'une pièce, pour le tonnerre : « claire », « depoli », « store » ou « aucune ».
static func window_exposure(room: String) -> String:
	if room == "":
		return "claire"
	var best := "aucune"
	var rank := {"aucune": 0, "store": 1, "depoli": 2, "claire": 3}
	for w in D.F1_WINDOWS:
		if String(w.room) != room:
			continue
		var k := "claire"
		if w.get("blind", false):
			k = "store"
		elif w.get("frosted", false):
			k = "depoli"
		if int(rank[k]) > int(rank[best]):
			best = k
	return best


## Classe d'écoute d'une source pour un auditeur, les portes ouvertes de open_deg degrés (id -> degrés ;
## une porte absente est fermée). Même interface que le prototype de l'étude « présence ».
static func classify(listener: Vector3, source: Vector3, open_deg: Dictionary) -> String:
	var states := {}
	for d in D.F1_DOORS:
		states[d.id] = door_state(float(open_deg.get(d.id, 0.0)) / OPEN_FULL_DEG)
	var lr := room_at(listener)
	return class_between(lr, source, costs_from(lr, states))


## Classe d'une source à partir des coûts depuis la pièce de l'auditeur « lr ».
static func class_between(lr: String, source: Vector3, costs: Dictionary) -> String:
	if lr == "":
		return "meme"
	var plane := door_plane_rooms(source)
	if not plane.is_empty() and not in_zone(source):
		if plane.has(lr):
			return "meme"
		var c := INF
		for r in plane:
			if costs.has(r):
				c = minf(c, float(costs[r]))
		return class_of_cost(c)
	var sr := source_room(source)
	if sr == "" or not costs.has(sr):
		return "meme"
	return class_of_cost(float(costs[sr]))


## Nom du bus d'un son de bus d'origine « origin » dans la classe « cl ».
static func bus_for(origin: String, cl: String) -> String:
	return origin if cl == "meme" or not occludable.has(origin) else "%s~%s" % [origin, cl]


## Clé de route d'un bus d'origine : le bus, suivi de « ! » s'il n'est pas occulté.
static func route_key(origin: String, occlusion := true) -> String:
	return origin if occlusion and occludable.has(origin) else origin + "!"


## area_mask d'un lecteur de ce bus d'origine (la couche de sa route ; une couche neuve au besoin, 0 si
## toutes les couches sont prises : pas de réverbération, le son direct reste).
static func mask_for(origin: String, occlusion := true) -> int:
	var key := route_key(origin, occlusion)
	if not routes.has(key):
		var used: Array = routes.values()
		for layer in range(Builder.LAYER_ACOUSTIC, ROUTE_LAYER_MAX + 1):
			if not used.has(layer):
				routes[key] = layer
				break
	return (1 << (int(routes[key]) - 1)) if routes.has(key) else 0


# ------------------------------------------------------------------ zones, pluie

## Crée les zones de réverbération de chaque route, et la pluie. h : la maison (House : doors, rooms).
func build(h: Node) -> void:
	house = h
	for key in routes:
		_build_route(key)
	_build_rain()
	_build_maison()
	refresh()


func _build_route(key: String) -> void:
	if zones.has(key):
		return
	var layer_bit := 1 << (int(routes[key]) - 1)
	zones[key] = {}
	for id in D.F1_ROOMS:
		var r: Array = D.F1_ROOMS[id].rect
		var a := Area3D.new()
		a.name = "Zone_%s_%s" % [id, key.replace("!", "_seul")]
		a.collision_layer = layer_bit
		a.collision_mask = 0
		a.monitoring = false
		a.monitorable = false
		a.audio_bus_override = true
		a.reverb_bus_enabled = true
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var y_lo := D.F1_Y - (3.0 if id == "escalier" else 0.3)
		var y_hi := D.F1_Y + D.F1_H + 0.3
		box.size = Vector3(float(r[1]) - float(r[0]) - 2.0 * ZONE_INSET, y_hi - y_lo, float(r[3]) - float(r[2]) - 2.0 * ZONE_INSET)
		cs.shape = box
		a.add_child(cs)
		add_child(a)
		a.position = Vector3((float(r[0]) + float(r[1])) / 2.0, (y_lo + y_hi) / 2.0, (float(r[2]) + float(r[3])) / 2.0)
		zones[key][id] = a
	if _fresh:
		_apply_zones()


func _build_rain() -> void:
	var k := 0
	for w in D.F1_WINDOWS:
		var snd: String = RAIN_SOUNDS[k % RAIN_SOUNDS.size()]
		var p: AudioStreamPlayer3D = Sfx.play_3d(snd, window_point(w, RAIN_INSIDE), {
			"db": _rain_db(w), "unit_size": RAIN_UNIT, "max_distance": RAIN_MAX_DISTANCE, "bus": "Ambiance",
			"loop": true, "from": 2.9 * k, "pitch": 1.0 + 0.012 * ((k * 7) % 5 - 2), "parent": self, "name": "Pluie_" + String(w.id)})
		if p:
			rain[w.id] = p
		k += 1
	roof = Sfx.loop(ROOF_SOUND, ROOF_DB, Vector3.INF, self) as AudioStreamPlayer
	if roof:
		roof.name = "PluieToit"


func _rain_db(w: Dictionary) -> float:
	var db := RAIN_DB
	if w.get("existe", false):
		db += RAIN_DB_EXISTING
	if w.get("blind", false):
		db += RAIN_DB_BLIND
	elif w.get("frosted", false):
		db += RAIN_DB_FROSTED
	if float(w.w) < 1.0:
		db += RAIN_DB_SMALL
	if open_windows.has(w.id):
		db += RAIN_DB_OPEN
	return db


## La maison qui vit : vent et frigo en boucle ; les bruits épars sont tirés par _maison_tick (hasard propre).
func _build_maison() -> void:
	_rng.seed = 7_202_040
	maison_next = _rng.randf_range(float(MAISON_FIRST[0]), float(MAISON_FIRST[1]))
	vent = Sfx.loop(VENT_SOUND, VENT_DB, Vector3.INF, self) as AudioStreamPlayer
	if vent:
		vent.name = "Vent"
		if vent.stream and vent.stream.get_length() > 0.0:
			vent.seek(_rng.randf_range(0.0, vent.stream.get_length()))
	frigo = Sfx.play_3d(FRIGO_SOUND, FRIGO_POS, {"db": FRIGO_DB, "unit_size": FRIGO_UNIT, "bus": "Ambiance",
		"loop": true, "parent": self, "name": "Frigo", "max_distance": 16.0})


## Un bruit de la maison de temps en temps, dans une pièce voisine de l'auditeur (pas la sienne), jamais
## pendant un dialogue, une scène écrite ou un silence (on attend).
func _maison_tick(dt: float) -> void:
	maison_next -= dt
	if maison_next > 0.0:
		return
	# (le Haunt sans son type : acoustique.gd ne dépend pas de haunt.gd)
	var h: Node = get_tree().get_first_node_in_group("haunt")
	var busy: bool = h != null and h.has_method("is_busy") and bool(h.call("is_busy"))
	if Game.phase == "title" or Sfx.is_silent() or Sfx._dialogue_on() or busy or listener_room == "":
		maison_next = 3.0
		return
	maison_next = _rng.randf_range(float(MAISON_EVERY[0]), float(MAISON_EVERY[1]))
	var near: Array = []
	for e in edges():
		if e[0] == listener_room and not near.has(e[1]):
			near.append(e[1])
		elif e[1] == listener_room and not near.has(e[0]):
			near.append(e[0])
	if near.is_empty():
		return
	var room: String = near[_rng.randi_range(0, near.size() - 1)]
	var spec: Array = MAISON_SOUNDS[_rng.randi_range(0, MAISON_SOUNDS.size() - 1)]
	var snd: String = String(spec[0]) % _rng.randi_range(1, int(spec[1]))
	var r: Array = D.F1_ROOMS[room].rect
	var pos := Vector3(_rng.randf_range(float(r[0]) + 0.4, float(r[1]) - 0.4), D.F1_Y + float(spec[3]),
		_rng.randf_range(float(r[2]) + 0.4, float(r[3]) - 0.4))
	var p := Sfx.play_3d(snd, pos, {"db": float(spec[2]), "unit_size": float(spec[4]), "bus": "Ambiance",
		"pitch": 1.0 + _rng.randf_range(-float(spec[5]), float(spec[5])), "name": "Maison"})
	if p:
		maison_log.append([snd, room])


## Une fenêtre ouverte : sa pluie est plus forte (aucune ne s'ouvre dans cette version).
func set_window_open(id: String, on: bool) -> void:
	if on:
		open_windows[id] = true
	else:
		open_windows.erase(id)
	for w in D.F1_WINDOWS:
		if w.id == id and rain.has(id) and is_instance_valid(rain[id]):
			create_tween().tween_property(rain[id], "volume_db", _rain_db(w), 0.6)


# ------------------------------------------------------------------ lecteurs et mise à jour

## Inscrit un lecteur 3D (Sfx.attach) : sa route (area_mask) et, hors des zones, le bus de sa classe
## d'écoute. reverb faux : il ne voit aucune zone (son direct sur son bus, sans réverbération).
func register(p: AudioStreamPlayer3D, occlusion := true, reverb := true) -> void:
	if p == null:
		return
	var origin := String(p.bus)
	occlusion = occlusion and not p.has_meta("sans_occlusion") and occludable.has(origin)
	if not occlusion:
		p.set_meta("sans_occlusion", true)
	var key := route_key(origin, occlusion)
	p.area_mask = mask_for(origin, occlusion) if reverb else 0
	if reverb and not zones.has(key) and routes.has(key):
		_build_route(key)
	if not occlusion:
		return
	if not _fresh:
		refresh()
	p.set_meta("bus_origine", origin)
	p.set_meta("t0", Time.get_ticks_msec())
	_set_class(p, class_at(p.global_position))
	_players.append(p)


## Classe d'écoute d'un point, pour l'auditeur actuel.
func class_at(pos: Vector3) -> String:
	return class_between(listener_room, pos, room_cost)


## Envoi de réverbération d'un son ponctuel au plan d'une porte (hors zone) : [bus, part] — la
## réverbération de la pièce de l'auditeur s'il est d'un côté de la porte, sinon celle, étouffée, de la plus
## proche des deux pièces ; [] si rien (pas au plan d'une porte, ou trop loin).
func twin_send(pos: Vector3) -> Array:
	if in_zone(pos):
		return []
	var plane := door_plane_rooms(pos)
	if plane.is_empty() or listener_room == "":
		return []
	if plane.has(listener_room) and PIECES.has(listener_room):
		return [PIECES[listener_room][0], float(PIECES[listener_room][1])]
	var best := ""
	for r in plane:
		if room_cost.has(r) and (best == "" or float(room_cost[r]) < float(room_cost[best])):
			best = r
	if best == "":
		return []
	var cl := class_of_cost(float(room_cost[best]))
	if cl == "loin" or not SOURD_SEND.has(cl):
		return []
	return ["Rev_sourd" if cl != "ouverte" else PIECES[best][0], float(PIECES[best][1]) * float(SOURD_SEND[cl])]


func _set_class(p: AudioStreamPlayer3D, cl: String) -> void:
	p.set_meta("classe", cl)
	p.bus = bus_for(String(p.get_meta("bus_origine", "Master")), cl)
	if p.has_meta("recit"):
		# son écrit : il garde le niveau calibré au banc à travers une porte (RECIT_COMP)
		var comp := float(RECIT_COMP.get(cl, 0.0)) if occludable.has(String(p.get_meta("bus_origine", "Master"))) else 0.0
		p.volume_db += comp - float(p.get_meta("comp", 0.0))
		p.set_meta("comp", comp)


## Recalcule tout (pièce de l'auditeur, portes, classes des pièces, zones, bus de l'auditeur).
func refresh() -> void:
	_update_listener()
	_update_doors()
	_recompute()
	_fresh = true


func _process(delta: float) -> void:
	_t += delta
	if _t < TICK:
		return
	_maison_tick(_t)
	_t = 0.0
	var moved := _update_listener()
	var doors := _update_doors()
	if moved or doors or not _fresh:
		_recompute()
		_fresh = true
	var now := Time.get_ticks_msec()
	for i in range(_players.size() - 1, -1, -1):
		var p: Variant = _players[i]
		if not is_instance_valid(p) or (p as Node).is_queued_for_deletion():
			_players.remove_at(i)
			continue
		var ap := p as AudioStreamPlayer3D
		if not ap.playing or now - int(ap.get_meta("t0", 0)) < MIN_AGE_MS:
			continue
		var cl := class_at(ap.global_position)
		if cl != String(ap.get_meta("classe", "")):
			_set_class(ap, cl)


## Position de l'auditeur : la caméra courante.
func listener_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else Vector3.INF


## Pièce de l'auditeur (on y reste tant qu'on est dans son rectangle) ; vrai si elle a changé.
func _update_listener() -> bool:
	var lp := listener_pos()
	var now := ""
	if lp != Vector3.INF:
		now = listener_room if listener_room != "" and room_at(lp) != "" and _inside(listener_room, lp) else room_at(lp)
	if now == listener_room:
		return false
	listener_room = now
	return true


static func _inside(id: String, p: Vector3) -> bool:
	var r: Array = D.F1_ROOMS[id].rect
	var m := D.WALL / 2.0
	return p.x >= float(r[0]) - m and p.x <= float(r[1]) + m and p.z >= float(r[2]) - m and p.z <= float(r[3]) + m


## États des portes (lecture seule de Door.leaf_angle_deg) ; vrai si l'un a changé.
func _update_doors() -> bool:
	var changed := false
	var doors: Dictionary = house.get("doors") if house else {}
	for id in doors:
		var dr: Node = doors[id]
		if not is_instance_valid(dr) or not dr.has_method("leaf_angle_deg"):
			continue
		var st := door_state(float(dr.call("leaf_angle_deg")) / OPEN_FULL_DEG, int(door_states.get(id, -1)))
		if st != int(door_states.get(id, -1)):
			door_states[id] = st
			changed = true
	return changed


func _recompute() -> void:
	room_cost = costs_from(listener_room, door_states)
	for id in D.F1_ROOMS:
		room_class[id] = "meme" if listener_room == "" else class_of_cost(float(room_cost[id]))
	_apply_zones()
	_apply_listener_buses()


## Bus (redirection) et réverbération de chaque zone de chaque route selon la classe de sa pièce.
func _apply_zones() -> void:
	for key in zones:
		var origin: String = key.trim_suffix("!")
		var occl: bool = not key.ends_with("!")
		for id in zones[key]:
			var a: Area3D = zones[key][id]
			var cl: String = room_class.get(id, "meme")
			var spec: Array = PIECES[id]
			a.audio_bus_name = bus_for(origin, cl) if occl else origin
			a.reverb_bus_uniformity = float(spec[2])
			match cl:
				"meme":
					a.reverb_bus_enabled = true
					a.reverb_bus_name = spec[0]
					a.reverb_bus_amount = float(spec[1])
				"ouverte":
					a.reverb_bus_enabled = true
					a.reverb_bus_name = spec[0]
					a.reverb_bus_amount = float(spec[1]) * float(SOURD_SEND["ouverte"])
				"entrouverte", "fermee":
					a.reverb_bus_enabled = true
					a.reverb_bus_name = "Rev_sourd"
					a.reverb_bus_amount = float(spec[1]) * float(SOURD_SEND[cl])
				_:
					a.reverb_bus_enabled = false


## Tonnerre (fenêtres de la pièce) et pas du joueur (réverbération de la pièce).
func _apply_listener_buses() -> void:
	var t: Array = TONNERRE[window_exposure(listener_room)]
	var ti := AudioServer.get_bus_index("Tonnerre")
	if ti >= 0 and AudioServer.get_bus_effect_count(ti) > 0:
		var lp := AudioServer.get_bus_effect(ti, 0) as AudioEffectFilter
		if lp:
			lp.cutoff_hz = float(t[0])
		AudioServer.set_bus_effect_enabled(ti, 0, float(t[0]) < 19000.0)
		AudioServer.set_bus_volume_db(ti, float(t[1]))
	var ji := AudioServer.get_bus_index("Joueur")
	if ji >= 0 and AudioServer.get_bus_effect_count(ji) > 0:
		var rv := AudioServer.get_bus_effect(ji, 0) as AudioEffectReverb
		if rv:
			if PIECES.has(listener_room):
				var spec: Array = PIECES[listener_room]
				var prm: Dictionary = REVERBS[spec[0]]
				for k in prm:
					rv.set(k, prm[k])
				rv.wet = float(spec[1]) * JOUEUR_WET
			else:
				rv.wet = 0.0
