class_name HouseData
## Plan de la maison (repère du jeu, mètres). x va de la rue (x < 0) vers le jardin de derrière ;
## z suit la façade ; y vers le haut. Rectangles = faces intérieures des murs [x0, x1, z0, z1].
## Tous les murs font 0,1 m et sont posés entre les rectangles (plan médian donné par "at").
## Source : docs/GDD.md (plan de la maison, 1er étage).

const WALL := 0.1

# ------------------------------------------------------------------ 1er étage (sol y = 0)
const F1_Y := 0.0
const F1_H := 2.6

## style : papier peint (wall), sol (floor), lambris (dado_h) de chaque pièce.
const F1_ROOMS := {
	"mere":     {"rect": [-3.2, 3.2, -2.6, 2.6], "title": "Chambre de ta mère", "existe": true},
	"gp":       {"rect": [-3.2, 3.2, -7.3, -2.7], "title": "Chambre d'Henriette et Albert", "wall": "floral", "floor": "parquet"},
	"amis":     {"rect": [-3.2, 3.2, 2.7, 6.3], "title": "Chambre d'amis", "wall": "stripes", "floor": "moquette"},
	"couloir":  {"rect": [3.3, 4.7, -7.3, 6.3], "title": "Couloir", "wall": "stripes_dark", "floor": "parquet"},
	"sdb":      {"rect": [4.8, 9.2, -7.3, -4.0], "title": "Salle de bain", "wall": "paint", "floor": "carrelage", "dado": "faience"},
	"lingerie": {"rect": [4.8, 9.2, -3.9, -0.5], "title": "Lingerie", "wall": "paint", "floor": "carrelage", "dado": "none"},
	"escalier": {"rect": [4.8, 9.2, -0.4, 1.9], "title": "Cage d'escalier", "wall": "stripes_dark", "floor": "parquet"},
	"bureau":   {"rect": [4.8, 9.2, 2.0, 6.3], "title": "Bureau", "wall": "stripes", "floor": "moquette"},
}

## Murs : axis "x" = mur parallèle à z, placé en x = at, de z = from à z = to (et inversement pour "z").
## skip : segments déjà construits par la chambre de la mère (room.gd).
const F1_WALLS := [
	{"axis": "x", "at": -3.25, "from": -7.4, "to": 6.4, "skip": [-2.7, 2.7]},   # façade rue
	{"axis": "x", "at": 9.25, "from": -7.4, "to": 6.4},                          # façade jardin
	{"axis": "z", "at": -7.35, "from": -3.3, "to": 9.3},                         # pignon z-
	{"axis": "z", "at": 6.35, "from": -3.3, "to": 9.3},                          # pignon z+
	{"axis": "x", "at": 3.25, "from": -7.3, "to": 6.3, "skip": [-2.7, 2.7]},     # chambres | couloir
	{"axis": "x", "at": 4.75, "from": -7.3, "to": 6.3},                          # couloir | rangée arrière
	{"axis": "z", "at": -3.95, "from": 4.8, "to": 9.2},                          # salle de bain | lingerie
	{"axis": "z", "at": -0.45, "from": 4.8, "to": 9.2},                          # lingerie | escalier
	{"axis": "z", "at": 1.95, "from": 4.8, "to": 9.2},                           # escalier | bureau
]

## Portes (toutes sur des murs d'axe x) : c = centre le long de z ; swing = pièce où pivote le battant.
## lock : "" ouverte | "stuck" (coincée : deux appuis) | "key:<id>" | "event:<id>" | "never" (pas dans cette version).
const F1_DOORS := [
	{"id": "P1", "at": 3.25, "c": 1.40, "w": 0.86, "swing": "mere", "lock": "key:cle_chambre", "existe": true},
	{"id": "P2", "at": 3.25, "c": -3.60, "w": 0.86, "swing": "gp", "lock": "never"},
	{"id": "P3", "at": 3.25, "c": 3.40, "w": 0.86, "swing": "amis", "lock": "stuck"},
	{"id": "P4", "at": 4.75, "c": -4.60, "w": 0.86, "swing": "sdb", "lock": ""},
	{"id": "P5", "at": 4.75, "c": -1.20, "w": 0.86, "swing": "lingerie", "lock": "key:cle_lingerie"},
	{"id": "P6", "at": 4.75, "c": 1.35, "w": 0.86, "swing": "couloir", "lock": "never", "glass": true},
	{"id": "P7", "at": 4.75, "c": 4.40, "w": 0.86, "swing": "bureau", "lock": "key:cle_bureau"},
]

## Fenêtres : c = centre le long du mur, w = largeur, y0 = allège, y1 = linteau.
## blind : store connecté baissé ; frosted : verre dépoli.
const F1_WINDOWS := [
	{"id": "F1", "room": "mere", "axis": "x", "at": -3.25, "c": -0.45, "w": 1.4, "y0": 0.95, "y1": 2.2, "existe": true},
	{"id": "F2", "room": "gp", "axis": "x", "at": -3.25, "c": -5.0, "w": 1.4, "y0": 0.95, "y1": 2.2, "blind": true},
	{"id": "F3", "room": "amis", "axis": "x", "at": -3.25, "c": 4.5, "w": 1.4, "y0": 0.95, "y1": 2.2},
	{"id": "F4", "room": "sdb", "axis": "x", "at": 9.25, "c": -5.8, "w": 0.8, "y0": 1.3, "y1": 2.1, "frosted": true},
	{"id": "F5", "room": "lingerie", "axis": "x", "at": 9.25, "c": -2.2, "w": 0.8, "y0": 1.3, "y1": 2.1, "blind": true},
	{"id": "F7", "room": "bureau", "axis": "x", "at": 9.25, "c": 4.15, "w": 1.4, "y0": 0.95, "y1": 2.2, "blind": true},
	{"id": "F8", "room": "couloir", "axis": "z", "at": 6.35, "c": 4.0, "w": 0.7, "y0": 0.95, "y1": 2.2},
]

## Trappe du grenier, au plafond de la lingerie.
const ATTIC_HATCH := {
	"rect": [4.9, 5.6, -3.2, -2.0],
	"ladder_foot": Vector3(5.25, 0.0, -3.3),
	"switch": Vector3(4.82, 1.3, -1.95),
}
