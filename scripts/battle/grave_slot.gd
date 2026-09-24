extends Marker2D
class_name GraveSlot

enum Team { PLAYER, ENEMY }

@export var team: Team = Team.PLAYER
@export var slot_index: int = 0

var occupant: Unit = null


func is_empty() -> bool:
	return occupant == null


func place_unit(unit: Unit) -> void:
	_clear_stale_occupant_visuals()
	occupant = unit
	unit.reparent(self)
	unit.position = Vector2.ZERO


func clear() -> void:
	if occupant:
		occupant.die()
	occupant = null


## clear() keeps a dead unit's corpse visible (queue_free() would erase it
## immediately) so it reads correctly after a normal death. But a SUMMON
## effect can place a brand-new living unit into that same slot within the
## same fight — without this, the old corpse would still be sitting here
## as a leftover child, visually overlapping the new arrival.
func _clear_stale_occupant_visuals() -> void:
	for child in get_children():
		if child is Unit:
			child.queue_free()
