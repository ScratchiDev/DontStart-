class_name MenuEntry
extends Button
## Entrée d'un menu (lot V3-INTERFACE) : texte seul ; survolée ou choisie au clavier ou à la manette, un filet
## vert à gauche et un voile à peine visible (style net), ou le surlignage vert d'avant (style rétro).
## Le survol de la souris prend le focus : une seule entrée en évidence à la fois.

var net := true


func _init(label: String = "", is_net := true) -> void:
	net = is_net
	text = label if net else "> " + label
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func() -> void:
		if not disabled and not has_focus():
			grab_focus())
	focus_entered.connect(func() -> void:
		UiStyle.play_ui("hover")
		queue_redraw())
	focus_exited.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	if not net:
		return
	if has_focus() or (is_hovered() and not disabled):
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.05))
		draw_rect(Rect2(0, 3, 1.5, size.y - 6.0), UiStyle.ACCENT)
