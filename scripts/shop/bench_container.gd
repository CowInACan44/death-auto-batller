extends HFlowContainer
class_name BenchContainer

## Accepts a drag dropped on empty space between/after the bench's
## RosterSlot children rather than directly on one of them. Bench order
## carries no meaning (only active lineup order does), so this is
## equivalent to dropping on any existing bench slot.
signal creature_dropped(owned_creature: OwnedCreature)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("owned")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	creature_dropped.emit(data["owned"])
