extends Node

## Drives the shop/battle/result cycle. Combat resolution and the shop
## itself don't exist yet — this only sequences state and spawns teams
## into grave slots.

enum GameState { SHOP, BATTLE, RESULT }

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")

var round_number: int = 1
var state: GameState = GameState.SHOP
var player_team: Array[CreatureData] = []

var _battle: Node = null


func register_battle(battle: Node) -> void:
	_battle = battle


func start_battle_phase() -> void:
	if _battle == null:
		push_warning("RoundManager: no battle scene registered, can't start battle phase")
		return

	var enemy_team := EncounterGenerator.generate_encounter(player_team, CreaturePool.all_creatures)

	for i in enemy_team.size():
		var slot: GraveSlot = _battle.enemy_grave_slots[i]
		var unit: Unit = UNIT_SCENE.instantiate()
		unit.creature_data = enemy_team[i]
		_battle.add_child(unit)
		slot.place_unit(unit)

	print("Round %d — Player: %s vs Enemy: %s" % [
		round_number,
		_format_team(player_team),
		_format_team(enemy_team),
	])

	state = GameState.BATTLE


func end_battle_phase(player_won: bool) -> void:
	state = GameState.RESULT
	print("Round %d result — %s" % [round_number, "Player won" if player_won else "Player lost"])

	round_number += 1
	state = GameState.SHOP
	print("Starting round %d (shop phase)" % round_number)


func _format_team(team: Array[CreatureData]) -> String:
	var names: Array[String] = []
	for creature in team:
		names.append(creature.creature_name)
	return "[%s]" % ", ".join(names)
