class_name CombatResolver
extends RefCounted

## Runs one lane-based, tick-driven auto-battle between two sides' grave
## slots and returns the outcome. Each creature attacks whatever's directly
## across its lane; if that lane's enemy is dead, it stays idle rather than
## retargeting. A creature's abilities (see Ability) fire on ON_ATTACK,
## ON_HIT, ON_KILL, and ON_DEATH — DAMAGE, BUFF_ATTACK, HEAL, BUFF_HP, and
## SUMMON all resolve.
##
## A full wipe of either side ends combat immediately with a clean win/loss.
## If MAX_TIME runs out with survivors on both sides, the side with more
## living units wins (total remaining HP as a tiebreak) rather than it
## automatically scoring a draw — see _score_timeout().

enum Result { PLAYER_WIN, ENEMY_WIN, DRAW }

const TICK := 0.1
const MAX_TIME := 30.0
## Real-world pause after each attack so a human watching the Battle
## scene can actually see HP tick down instead of the whole fight
## resolving within a single engine frame. Tune freely.
const ATTACK_DELAY := 0.3
const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")

## "Slot 1" in human-facing terms (the frontmost grave slot) is
## GraveSlot.slot_index 0 in code — TOP_ENEMY always targets whoever
## currently occupies that literal slot, regardless of the attacker's own
## lane, and simply no-ops if that slot's original occupant has already
## died (no fallback to the next slot, at least for now).
const TOP_ENEMY_LANE_INDEX := 0

## Per-battle combat state for one creature. Wraps a CreatureData instead
## of mutating it directly, since the same CreatureData resource is shared
## across every copy of that creature in the pool.
class CombatUnit:
	var creature_data: CreatureData
	var slot: GraveSlot
	var team: GraveSlot.Team
	var lane_index: int
	var max_hp: int
	var current_hp: int
	var current_attack: int
	var attack_speed: float
	var attack_timer: float = 0.0
	var alive: bool = true

	func _init(p_creature_data: CreatureData, p_is_shiny: bool, p_slot: GraveSlot, p_team: GraveSlot.Team, p_lane_index: int) -> void:
		creature_data = p_creature_data
		slot = p_slot
		team = p_team
		lane_index = p_lane_index
		max_hp = OwnedCreature.calc_effective_max_hp(p_creature_data, p_is_shiny)
		current_hp = max_hp
		current_attack = OwnedCreature.calc_effective_attack(p_creature_data, p_is_shiny)
		attack_speed = p_creature_data.attack_speed


var player_units: Array[CombatUnit] = []
var enemy_units: Array[CombatUnit] = []
var log_lines: Array[String] = []

var player_slots: Array[GraveSlot] = []
var enemy_slots: Array[GraveSlot] = []
## The Battle scene, so a SUMMON effect can instantiate and add a real
## visual Unit node, not just internal combat state. Null is tolerated
## (summoned units just go visual-less) so this stays testable headless.
var _battle_node: Node = null


func resolve(p_player_slots: Array[GraveSlot], p_enemy_slots: Array[GraveSlot], battle_node: Node = null) -> Result:
	player_slots = p_player_slots
	enemy_slots = p_enemy_slots
	_battle_node = battle_node
	player_units = _build_units(player_slots, GraveSlot.Team.PLAYER)
	enemy_units = _build_units(enemy_slots, GraveSlot.Team.ENEMY)
	_log_unmatched_lanes()

	var elapsed := 0.0
	while elapsed < MAX_TIME and _team_alive(player_units) and _team_alive(enemy_units):
		elapsed += TICK
		# Player units are processed before enemy units each tick, so a
		# lane where both sides land a simultaneous killing blow favors
		# whichever unit already died and can't swing back — a simple,
		# documented tie-break rather than true simultaneity.
		for unit in player_units + enemy_units:
			if not unit.alive:
				continue
			var interval := 1.0 / unit.attack_speed if unit.attack_speed > 0.0 else INF
			unit.attack_timer += TICK
			if unit.attack_timer >= interval:
				unit.attack_timer -= interval
				await _perform_attack(unit)
				if not _team_alive(player_units) or not _team_alive(enemy_units):
					break

	var player_alive := _team_alive(player_units)
	var enemy_alive := _team_alive(enemy_units)

	var result: Result
	if player_alive and not enemy_alive:
		result = Result.PLAYER_WIN
	elif enemy_alive and not player_alive:
		result = Result.ENEMY_WIN
	elif not player_alive and not enemy_alive:
		# Not reachable under the current sequential tie-break (one side
		# always gets to act before the other, so a true simultaneous
		# double-wipe can't happen) — kept as a defensive true-draw case.
		result = Result.DRAW
	else:
		# Timeout with survivors on both sides. A near-wipe (e.g. 3 of 4
		# enemies dead) used to score identically to a total stalemate
		# here — now the side with more living units wins outright, with
		# total remaining HP as a tiebreak, and only an exact tie on both
		# is a genuine draw.
		result = _score_timeout()

	var player_count := _alive_count(player_units)
	var enemy_count := _alive_count(enemy_units)
	_log("Combat ended after %.1fs — %s (survivors: P=%d, E=%d)" % [
		elapsed, Result.find_key(result), player_count, enemy_count,
	])
	return result


func _score_timeout() -> Result:
	var player_count := _alive_count(player_units)
	var enemy_count := _alive_count(enemy_units)
	if player_count != enemy_count:
		return Result.PLAYER_WIN if player_count > enemy_count else Result.ENEMY_WIN

	var player_hp := _total_hp(player_units)
	var enemy_hp := _total_hp(enemy_units)
	if player_hp != enemy_hp:
		return Result.PLAYER_WIN if player_hp > enemy_hp else Result.ENEMY_WIN

	return Result.DRAW


func _alive_count(units: Array[CombatUnit]) -> int:
	var count := 0
	for unit in units:
		if unit.alive:
			count += 1
	return count


func _total_hp(units: Array[CombatUnit]) -> int:
	var total := 0
	for unit in units:
		if unit.alive:
			total += unit.current_hp
	return total


## RefCounted has no direct tree access, so reach it via the running
## SceneTree singleton instead of requiring a Node reference to be
## threaded through the whole combat resolver.
func _real_pause(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		await tree.create_timer(seconds).timeout


func _build_units(slots: Array[GraveSlot], team: GraveSlot.Team) -> Array[CombatUnit]:
	var units: Array[CombatUnit] = []
	for slot in slots:
		if slot.occupant == null:
			continue
		units.append(CombatUnit.new(slot.occupant.creature_data, slot.occupant.is_shiny, slot, team, slot.slot_index))
	return units


func _team_alive(units: Array[CombatUnit]) -> bool:
	for unit in units:
		if unit.alive:
			return true
	return false


func _team_units(team: GraveSlot.Team) -> Array[CombatUnit]:
	return player_units if team == GraveSlot.Team.PLAYER else enemy_units


func _other_team(team: GraveSlot.Team) -> GraveSlot.Team:
	return GraveSlot.Team.ENEMY if team == GraveSlot.Team.PLAYER else GraveSlot.Team.PLAYER


func _lane_opponent(unit: CombatUnit) -> CombatUnit:
	for opponent in _team_units(_other_team(unit.team)):
		if opponent.lane_index == unit.lane_index:
			return opponent
	return null


func _team_tag(team: GraveSlot.Team) -> String:
	return "P" if team == GraveSlot.Team.PLAYER else "E"


func _name(unit: CombatUnit) -> String:
	return "[%s] %s" % [_team_tag(unit.team), unit.creature_data.creature_name]


## A unit whose lane has no opponent at all (unequal team sizes) will sit
## idle for the whole fight and can make the loser side look "unkillable"
## in the log — call this out once, up front, instead of leaving it silent.
func _log_unmatched_lanes() -> void:
	for unit in player_units + enemy_units:
		if _lane_opponent(unit) == null:
			_log("%s (lane %d) has no opponent this fight and will stay idle." % [_name(unit), unit.lane_index])


func _refresh_display(unit: CombatUnit) -> void:
	if unit.slot and unit.slot.occupant:
		unit.slot.occupant.update_display(unit.current_hp, unit.current_attack)


## Plays the attacker's lunge animation toward the target's on-screen
## position; its duration is also this fight's real-time pacing beat.
## Falls back to a bare pause if either unit's visual node is missing.
func _play_attack_animation(attacker: CombatUnit, target: CombatUnit) -> void:
	if attacker.slot and attacker.slot.occupant and target.slot and target.slot.occupant:
		await attacker.slot.occupant.play_attack_animation(target.slot.occupant.global_position)
	else:
		await _real_pause(ATTACK_DELAY)


func _perform_attack(attacker: CombatUnit) -> void:
	var target := _lane_opponent(attacker)
	if target == null or not target.alive:
		return # lane opponent is dead — idle rather than retarget

	_fire_trigger(attacker, "ON_ATTACK", {"target": target})
	if not attacker.alive:
		return # an ON_ATTACK ability could theoretically kill its own source later

	await _play_attack_animation(attacker, target)

	var damage := attacker.current_attack
	target.current_hp = max(target.current_hp - damage, 0)
	_log("%s attacks %s for %d damage. %s HP: %d/%d" % [
		_name(attacker), _name(target), damage,
		_name(target), target.current_hp, target.max_hp,
	])
	_refresh_display(target)

	# Death is checked before ON_HIT fires (not after) so a self-heal or
	# other HP-restoring ON_HIT effect can't pull a unit back above 0 once
	# it's already been struck down — a unit that died from this hit only
	# gets its ON_DEATH abilities, never a last-gasp ON_HIT one.
	if target.current_hp <= 0:
		_kill(target, attacker)
	else:
		_fire_trigger(target, "ON_HIT", {"attacker": attacker})


func _kill(target: CombatUnit, killer: CombatUnit) -> void:
	if not target.alive:
		return

	target.alive = false
	_log("%s has died!" % _name(target))
	if target.slot:
		target.slot.clear()

	if killer:
		_fire_trigger(killer, "ON_KILL", {"target": target})
	_fire_trigger(target, "ON_DEATH", {"killer": killer})


func _fire_trigger(unit: CombatUnit, trigger: String, context: Dictionary) -> void:
	for ability in unit.creature_data.abilities:
		if ability.trigger != trigger:
			continue
		var targets := _resolve_ability_targets(unit, ability, context)
		_apply_ability_effect(unit, ability, targets)


## Every branch builds its result via explicit Array[CombatUnit] append
## calls rather than .filter()/array-literal returns. GDScript's static
## checker accepts a bare Array from .filter() (or a literal like [x])
## being returned where -> Array[CombatUnit] is declared, but the runtime
## coercion isn't reliable for every construction path — it can throw
## "Trying to assign an array of type 'Array' to a variable of type
## 'Array[CombatUnit]'" when the caller does `var targets := ...`. Explicit
## typed-array construction sidesteps that entirely.
func _resolve_ability_targets(unit: CombatUnit, ability: Ability, context: Dictionary) -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []

	match ability.target:
		"SELF":
			result.append(unit)

		"ADJACENT_ALLY":
			for ally in _team_units(unit.team):
				if ally == unit or not ally.alive:
					continue
				if abs(ally.lane_index - unit.lane_index) == 1:
					result.append(ally)

		"ALL_ALLIES":
			for ally in _team_units(unit.team):
				if ally.alive:
					result.append(ally)

		"TARGETED_ENEMY":
			var event_unit: CombatUnit = context.get("target", context.get("attacker", context.get("killer")))
			if event_unit != null and event_unit.alive:
				result.append(event_unit)

		"RANDOM_ENEMY":
			var alive_enemies: Array[CombatUnit] = []
			for enemy in _team_units(_other_team(unit.team)):
				if enemy.alive:
					alive_enemies.append(enemy)
			if not alive_enemies.is_empty():
				result.append(alive_enemies.pick_random())

		"FRONT_ENEMY":
			var front_candidates: Array[CombatUnit] = []
			for enemy in _team_units(_other_team(unit.team)):
				if enemy.alive:
					front_candidates.append(enemy)
			if not front_candidates.is_empty():
				front_candidates.sort_custom(func(a, b): return a.lane_index < b.lane_index)
				result.append(front_candidates[0])

		"TOP_ENEMY":
			# Fixed slot, not the dynamically-retargeting FRONT_ENEMY — if
			# whoever started in that slot has died, this just no-ops.
			for enemy in _team_units(_other_team(unit.team)):
				if enemy.lane_index == TOP_ENEMY_LANE_INDEX and enemy.alive:
					result.append(enemy)
					break

	return result


## Flat by default; if ability.scales_with_owned_line_count is set, the
## magnitude is multiplied by how many of source's living teammates
## (source included) share its evolution_line.
func _effective_magnitude(source: CombatUnit, ability: Ability) -> int:
	if not ability.scales_with_owned_line_count:
		return ability.magnitude
	return ability.magnitude * _count_line_members(source)


func _count_line_members(source: CombatUnit) -> int:
	var line := source.creature_data.evolution_line
	if line == "none":
		return 1
	var count := 0
	for unit in _team_units(source.team):
		if unit.alive and unit.creature_data.evolution_line == line:
			count += 1
	return count


func _apply_ability_effect(source: CombatUnit, ability: Ability, targets: Array[CombatUnit]) -> void:
	var magnitude := _effective_magnitude(source, ability)

	match ability.effect_type:
		"DAMAGE":
			for target in targets:
				if not target.alive:
					continue
				target.current_hp = max(target.current_hp - magnitude, 0)
				_log("%s's ability deals %d damage to %s. %s HP: %d/%d" % [
					_name(source), magnitude, _name(target),
					_name(target), target.current_hp, target.max_hp,
				])
				_refresh_display(target)
				if target.current_hp <= 0:
					_kill(target, source)

		"BUFF_ATTACK":
			for target in targets:
				if not target.alive:
					continue
				target.current_attack += magnitude
				_log("%s's ability triggers: %s attack buffed to %d" % [
					_name(source), _name(target), target.current_attack,
				])
				_refresh_display(target)

		"HEAL":
			for target in targets:
				if not target.alive:
					continue
				target.current_hp = min(target.current_hp + magnitude, target.max_hp)
				_log("%s's ability heals %s for %d. %s HP: %d/%d" % [
					_name(source), _name(target), magnitude,
					_name(target), target.current_hp, target.max_hp,
				])
				_refresh_display(target)

		"BUFF_HP":
			for target in targets:
				if not target.alive:
					continue
				target.max_hp += magnitude
				target.current_hp += magnitude
				_log("%s's ability triggers: %s HP buffed — now %d/%d" % [
					_name(source), _name(target), target.current_hp, target.max_hp,
				])
				_refresh_display(target)

		"SUMMON":
			if ability.summon_creature == null or magnitude <= 0:
				return
			var empty_slots := _find_empty_slots(source.team, source.slot, magnitude)
			if empty_slots.is_empty():
				_log("%s's ability tries to summon %s, but there's no room." % [
					_name(source), ability.summon_creature.creature_name,
				])
				return
			for slot in empty_slots:
				_spawn_unit(ability.summon_creature, slot, source.team)


func _slots_for_team(team: GraveSlot.Team) -> Array[GraveSlot]:
	return player_slots if team == GraveSlot.Team.PLAYER else enemy_slots


## Picks up to `count` empty slots for a SUMMON effect: the dying unit's
## own slot first (already vacated by _kill() before ON_DEATH fires), then
## any other empty slot on that team in ascending lane order. Fewer empty
## slots than `count` just means fewer copies spawn — never errors.
func _find_empty_slots(team: GraveSlot.Team, priority_slot: GraveSlot, count: int) -> Array[GraveSlot]:
	var result: Array[GraveSlot] = []
	if priority_slot != null and priority_slot.is_empty():
		result.append(priority_slot)

	var sorted_slots := _slots_for_team(team).duplicate()
	sorted_slots.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	for slot in sorted_slots:
		if result.size() >= count:
			break
		if slot == priority_slot:
			continue
		if slot.is_empty():
			result.append(slot)

	return result


## Adds a brand-new CombatUnit to the fight — never shiny (a fresh summon,
## not a copy of whatever the parent was) — and gives it a real visual
## Unit node in the vacated slot if a Battle scene is registered.
func _spawn_unit(creature_data: CreatureData, slot: GraveSlot, team: GraveSlot.Team) -> void:
	var new_unit := CombatUnit.new(creature_data, false, slot, team, slot.slot_index)
	_team_units(team).append(new_unit)

	if _battle_node:
		var visual: Unit = UNIT_SCENE.instantiate()
		visual.creature_data = creature_data
		visual.is_shiny = false
		_battle_node.add_child(visual)
		slot.place_unit(visual)

	_log("%s summons %s into lane %d!" % [_team_tag(team), creature_data.creature_name, slot.slot_index])


func _log(text: String) -> void:
	log_lines.append(text)
	print(text)
