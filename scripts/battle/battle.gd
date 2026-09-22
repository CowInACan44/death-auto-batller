extends Node2D

# Battle scene: grave slots for player and enemy units.
# Auto-battle logic to be added later.

@onready var player_grave_slots: Array[GraveSlot] = _collect_slots($PlayerGraveSlots)
@onready var enemy_grave_slots: Array[GraveSlot] = _collect_slots($EnemyGraveSlots)


func _collect_slots(container: Node) -> Array[GraveSlot]:
	var slots: Array[GraveSlot] = []
	for child in container.get_children():
		if child is GraveSlot:
			slots.append(child)
	return slots


func get_empty_slot(team: GraveSlot.Team) -> GraveSlot:
	var slots := player_grave_slots if team == GraveSlot.Team.PLAYER else enemy_grave_slots
	for slot in slots:
		if slot.is_empty():
			return slot
	return null
