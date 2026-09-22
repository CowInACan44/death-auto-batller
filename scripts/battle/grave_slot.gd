extends Marker2D
class_name GraveSlot

enum Team { PLAYER, ENEMY }

@export var team: Team = Team.PLAYER
@export var slot_index: int = 0

var occupant: Unit = null


func is_empty() -> bool:
	return occupant == null


func place_unit(unit: Unit) -> void:
	occupant = unit
	unit.reparent(self)
	unit.position = Vector2.ZERO


func clear() -> void:
	if occupant:
		occupant.queue_free()
	occupant = null
