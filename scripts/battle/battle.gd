extends Node2D

# Battle scene: grave slots for player and enemy units.
# Auto-battle logic to be added later.

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")

@onready var player_grave_slots: Array[GraveSlot] = _collect_slots($PlayerGraveSlots)
@onready var enemy_grave_slots: Array[GraveSlot] = _collect_slots($EnemyGraveSlots)


func _ready() -> void:
	RoundManager.register_battle(self)
	_run_round_loop_test()


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


## Temporary manual test of the round loop — remove once the shop and
## real combat resolution exist. Manually seats a player team, starts
## a battle phase (which generates + seats the enemy team), then
## immediately ends it as a win to confirm the loop advances to
## round 2 correctly.
func _run_round_loop_test() -> void:
	var test_team: Array[CreatureData] = [
		CreaturePool.get_by_line_and_stage("bone_beasts", 1),
		CreaturePool.get_by_line_and_stage("slime_skulls", 1),
	]

	for i in test_team.size():
		var unit: Unit = UNIT_SCENE.instantiate()
		unit.creature_data = test_team[i]
		add_child(unit)
		player_grave_slots[i].place_unit(unit)

	RoundManager.player_team = test_team
	RoundManager.start_battle_phase()
	RoundManager.end_battle_phase(true)
