extends Node2D
class_name Unit

## Base creature/unit scene. Auto-battle logic to be added later.
@export var creature_data: CreatureData
@export var is_shiny: bool = false

## Placeholder gold tint until real shiny art exists — swap for an actual
## shiny sprite/shader once art is in.
const SHINY_TINT := Color(1.4, 1.2, 0.4)


func _ready() -> void:
	if is_shiny and has_node("Sprite"):
		$Sprite.modulate = SHINY_TINT
