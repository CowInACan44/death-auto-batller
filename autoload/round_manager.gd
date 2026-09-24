extends Node

## Drives the shop/battle/result cycle: seats the active lineup into grave
## slots, hands them to CombatResolver, and feeds the outcome back into
## the round result.
##
## Shop phase = "Day N", battle phase = "Night N". A 7-night run: Night 7
## is a boosted boss encounter, and beating it is the win condition. 3
## hearts total across the whole run — losing a night costs one; hitting
## 0 is GAME_OVER.
##
## roster = everything the player owns (bench + active). active_lineup =
## a fixed MAX_ACTIVE-length array of lane slots, seated into grave slots
## index-for-index each Night; a null entry means that lane is empty. Any
## roster member not present in active_lineup is considered benched.

enum GameState { SHOP, BATTLE, RESULT, GAME_OVER, GAME_WON }

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")
const MERGE_COUNT := 3
const MAX_ACTIVE := 4

const MAX_HEARTS := 3
const FINAL_NIGHT := 7
const BOSS_NAME := "The Gravekeeper's Champion"
const BOSS_POWER_MULTIPLIER := 1.75

var round_number: int = 1
var state: GameState = GameState.SHOP
var roster: Array[OwnedCreature] = []
var active_lineup: Array[OwnedCreature] = [null, null, null, null]
var hearts: int = MAX_HEARTS

var _battle: Node = null


func register_battle(battle: Node) -> void:
	_battle = battle


## The single entry point for adding a bought/acquired creature to the
## player's roster — always route additions through here (not a direct
## roster.append()) so auto-activation and the merge check both run.
## Auto-activates into the lineup if there's room, so a fresh purchase
## (or the starter pick) doesn't require a manual extra step to fight.
func add_to_roster(creature: OwnedCreature) -> void:
	roster.append(creature)
	var empty_index := active_lineup.find(null)
	if empty_index != -1:
		active_lineup[empty_index] = creature
	check_for_merge(creature)


## Places creature into active_lineup[index], swapping with whatever was
## already there. If creature came from another active slot, the displaced
## occupant (if any) takes its vacated spot — a true swap. If creature came
## from the bench, the displaced occupant simply becomes benched, since
## nothing reclaims its old spot.
func set_active_slot(creature: OwnedCreature, index: int) -> void:
	if index < 0 or index >= MAX_ACTIVE:
		return
	var source_index := active_lineup.find(creature)
	var displaced := active_lineup[index]
	active_lineup[index] = creature
	if source_index != -1 and source_index != index:
		active_lineup[source_index] = displaced


## Removes creature from the active lineup (benches it), if present.
func clear_active_slot_for(creature: OwnedCreature) -> void:
	var idx := active_lineup.find(creature)
	if idx != -1:
		active_lineup[idx] = null


## Sells a roster member (bench or active) for its bone_value in bones,
## removing it from both the roster and the active lineup. Same bones
## payout a creature earns for dying in battle — selling is just cashing
## it in early instead.
func sell_creature(creature: OwnedCreature) -> void:
	if creature not in roster:
		return
	clear_active_slot_for(creature)
	roster.erase(creature)
	Economy.award_bones(creature.data.bone_value)
	print("Sold %s for %d bones" % [creature.data.creature_name, creature.data.bone_value])


## Checks whether the roster now holds MERGE_COUNT copies of the exact
## same creature (same CreatureData reference — line/name/stage all
## match by construction — AND same is_shiny status; a shiny and a
## non-shiny copy never merge together). If so, consumes 3 of them and
## adds 1 instance of next_stage, carrying is_shiny forward. If any
## consumed copy was active, the evolved result takes over that lane
## (the first such lane found, preserving lineup order/position). No-ops
## if next_stage is null (stage 3, or a bonus creature with no evolution).
func check_for_merge(creature_instance: OwnedCreature) -> void:
	var matches: Array[OwnedCreature] = []
	for owned in roster:
		if owned.data == creature_instance.data and owned.is_shiny == creature_instance.is_shiny:
			matches.append(owned)

	if matches.size() < MERGE_COUNT:
		return

	var next_stage: CreatureData = creature_instance.data.next_stage
	if next_stage == null:
		return

	var active_slot_index := -1
	for i in MERGE_COUNT:
		var consumed := matches[i]
		var idx := active_lineup.find(consumed)
		if idx != -1:
			if active_slot_index == -1:
				active_slot_index = idx
			active_lineup[idx] = null
		roster.erase(consumed)

	var evolved := OwnedCreature.new(next_stage, creature_instance.is_shiny)
	roster.append(evolved)
	if active_slot_index != -1:
		active_lineup[active_slot_index] = evolved

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

	for i in MAX_ACTIVE:
		var owned: OwnedCreature = active_lineup[i]
		if owned == null:
			continue
		var slot: GraveSlot = _battle.player_grave_slots[i]
		var unit: Unit = UNIT_SCENE.instantiate()
		unit.creature_data = owned.data
		unit.is_shiny = owned.is_shiny
		_battle.add_child(unit)
		slot.place_unit(unit)

	var is_boss_night := round_number == FINAL_NIGHT
	var power_multiplier := BOSS_POWER_MULTIPLIER if is_boss_night else 1.0
	var enemy_team := EncounterGenerator.generate_encounter(
		active_lineup, CreaturePool.purchasable_creatures, MAX_ACTIVE, power_multiplier
	)

	for i in enemy_team.size():
		var slot: GraveSlot = _battle.enemy_grave_slots[i]
		var unit: Unit = UNIT_SCENE.instantiate()
		unit.creature_data = enemy_team[i]
		_battle.add_child(unit)
		slot.place_unit(unit)

	if is_boss_night:
		print("🌙 Night %d — BOSS ENCOUNTER: %s approaches!" % [round_number, BOSS_NAME])

	print("Night %d — Player: %s vs Enemy: %s" % [
		round_number,
		_format_owned_team(active_lineup),
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
	return await resolver.resolve(_battle.player_grave_slots, _battle.enemy_grave_slots, _battle)


func end_battle_phase(player_won: bool) -> void:
	state = GameState.RESULT
	print("Night %d result — %s" % [round_number, "Player won" if player_won else "Player lost"])

	# No real per-unit death tracking yet — simulate a handful of deaths
	# and award bones off their bone_value as a placeholder.
	var deaths := randi_range(1, 4)
	var bones_earned := 0
	for i in deaths:
		var fallen: CreatureData = CreaturePool.purchasable_creatures.pick_random()
		bones_earned += fallen.bone_value
	print("%d creatures died this round" % deaths)
	Economy.award_bones(bones_earned)

	if player_won and round_number == FINAL_NIGHT:
		state = GameState.GAME_WON
		print("=== YOU WIN — %s defeated on Night %d! ===" % [BOSS_NAME, round_number])
		return

	if not player_won:
		hearts -= 1
		print("💀 Lost a heart! Hearts remaining: %d/%d" % [hearts, MAX_HEARTS])
		if hearts <= 0:
			state = GameState.GAME_OVER
			print("=== GAME OVER — ran out of hearts on Night %d ===" % round_number)
			return

	# Nights never advance past FINAL_NIGHT — losing the boss night retries
	# the boss instead of rolling into a night that doesn't exist.
	round_number = min(round_number + 1, FINAL_NIGHT)
	state = GameState.SHOP
	print("Starting Day %d (shop phase) — Bones: %d" % [round_number, Economy.bones])


## Fully resets run state for a new game (Start from MainMenu, or Retry
## from GameOverScreen/GameWonScreen). Does NOT touch the Battle scene
## reference — a freshly loaded Battle scene re-registers itself anyway.
func reset_run() -> void:
	round_number = 1
	state = GameState.SHOP
	roster = []
	active_lineup = [null, null, null, null]
	hearts = MAX_HEARTS
	Economy.reset()
	print("=== New run started — Day 1, %d hearts ===" % hearts)


func _format_owned_team(team: Array[OwnedCreature]) -> String:
	var names: Array[String] = []
	for owned in team:
		if owned == null:
			continue
		names.append(("✨" if owned.is_shiny else "") + owned.data.creature_name)
	return "[%s]" % ", ".join(names)


func _format_data_team(team: Array[CreatureData]) -> String:
	var names: Array[String] = []
	for creature in team:
		names.append(creature.creature_name)
	return "[%s]" % ", ".join(names)
