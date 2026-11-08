class_name Interactable
extends StaticBody3D
## Objet qu'on peut viser et utiliser avec E. Le texte affiché vient de « label ».

signal used(by: Interactable)

@export var label := "Examiner"
@export var reach := 2.2
@export var enabled := true


func use() -> void:
	if enabled:
		used.emit(self)
