extends Node

## Drives the shop/battle/result cycle: seats teams into grave slots,
## hands them to CombatResolver, and feeds the outcome back into the
## round result. The shop itself isn't wired in yet.

enum GameState { SHOP, BATTLE, RESULT }

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")
const MERGE_COUNT := 3

var round_number: int = 1
var state: GameState = GameState.SHOP
var player_team: Array[OwnedCreature] = []

var _battle: Node = null


func register_battle(battle: Node) -> void:
	_battle = battle


## The single entry point for adding a bought/acquired creature to the
## player's roster — always route additions through here (not a direct
## player_team.append()) so the merge check actually runs.
func add_to_roster(creature: OwnedCreature) -> void:
	player_team.append(creature)
	check_for_merge(creature)


## Checks whether the roster now holds MERGE_COUNT copies of the exact
## same creature (same CreatureData reference — line/name/stage all
## match by construction — AND same is_shiny status; a shiny and a
## non-shiny copy never merge together). If so, consumes 3 of them and
## adds 1 instance of next_stage, carrying is_shiny forward. No-ops if
## next_stage is null (stage 3, or a bonus creature with no evolution).
func check_for_merge(creature_instance: OwnedCreature) -> void:
	var matches: Array[OwnedCreature] = []
	for owned in player_team:
		if owned.data == creature_instance.data and owned.is_shiny == creature_instance.is_shiny:
			matches.append(owned)

	if matches.size() < MERGE_COUNT:
		return

	var next_stage: CreatureData = creature_instance.data.next_stage
	if next_stage == null:
		return

	for i in MERGE_COUNT:
		player_team.erase(matches[i])

	var evolved := OwnedCreature.new(next_stage, creature_instance.is_shiny)
	player_team.append(evolved)

	print("%dx %s merged into %s!%s" % [
		MERGE_COUNT,
		creature_instance.data.creature_name,
		evolved.data.creature_name,
		" ✨" if evolved.is_shiny else "",
	])

	# The evolved copy could itself complete a further merge if 2 more
	# of that stage were already sitting on the roster.
	check_for_merge(evolved)


func start_battle_phase() -> void:
	if _battle == null:
		push_warning("RoundManager: no battle scene registered, can't start battle phase")
		return

	var enemy_team := EncounterGenerator.generate_encounter(player_team, CreaturePool.purchasable_creatures)

	for i in enemy_team.size():
		var slot: GraveSlot = _battle.enemy_grave_slots[i]
		var unit: Unit = UNIT_SCENE.instantiate()
		unit.creature_data = enemy_team[i]
		_battle.add_child(unit)
		slot.place_unit(unit)

	print("Round %d — Player: %s vs Enemy: %s" % [
		round_number,
		_format_owned_team(player_team),
		_format_data_team(enemy_team),
	])

	state = GameState.BATTLE


## Runs the actual auto-battle between the registered Battle scene's grave
## slots and returns the outcome for end_battle_phase() to consume.
func resolve_combat() -> CombatResolver.Result:
	if _battle == null:
		push_warning("RoundManager: no battle scene registered, can't resolve combat")
		return CombatResolver.Result.DRAW

	var resolver := CombatResolver.new()
	return resolver.resolve(_battle.player_grave_slots, _battle.enemy_grave_slots)


func end_battle_phase(player_won: bool) -> void:
	state = GameState.RESULT
	print("Round %d result — %s" % [round_number, "Player won" if player_won else "Player lost"])

	# No real per-unit death tracking yet — simulate a handful of deaths
	# and award bones off their bone_value as a placeholder.
	var deaths := randi_range(1, 4)
	var bones_earned := 0
	for i in deaths:
		var fallen: CreatureData = CreaturePool.purchasable_creatures.pick_random()
		bones_earned += fallen.bone_value
	print("%d creatures died this round" % deaths)
	Economy.award_bones(bones_earned)

	round_number += 1
	state = GameState.SHOP
	print("Starting round %d (shop phase) — Bones: %d" % [round_number, Economy.bones])


func _format_owned_team(team: Array[OwnedCreature]) -> String:
	var names: Array[String] = []
	for owned in team:
		names.append(("✨" if owned.is_shiny else "") + owned.data.creature_name)
	return "[%s]" % ", ".join(names)


func _format_data_team(team: Array[CreatureData]) -> String:
	var names: Array[String] = []
	for creature in team:
		names.append(creature.creature_name)
	return "[%s]" % ", ".join(names)
