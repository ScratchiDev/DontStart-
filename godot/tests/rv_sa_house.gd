extends "res://tests/sa_house.gd"
## Relecture (exclu de l'export) : comme sa_house.gd, mais retient le nombre d'enfants de chaque pièce
## avant son ameublement (méta « pre »), pour séparer les murs des meubles.


func _make_room(id: String, d: Dictionary, y0_: float, h_: float) -> HouseRoom:
	var r := super._make_room(id, d, y0_, h_)
	r.set_meta("pre", r.get_child_count())
	return r
