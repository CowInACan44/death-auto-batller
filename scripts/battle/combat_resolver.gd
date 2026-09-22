class_name CombatResolver
extends RefCounted

## Runs one lane-based, tick-driven auto-battle between two sides' grave
## slots and returns the outcome. Each creature attacks whatever's directly
## across its lane; if that lane's enemy is dead, it stays idle rather than
## retargeting. A creature's abilities (see Ability) fire on ON_ATTACK,
## ON_HIT, ON_KILL, and ON_DEATH. Only DAMAGE and BUFF_ATTACK effects
## actually resolve — HEAL, BUFF_HP, and SUMMON are stubbed as no-ops.

enum Result { PLAYER_WIN, ENEMY_WIN, DRAW }

const TICK := 0.1
const MAX_TIME := 30.0

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

	func _init(p_creature_data: CreatureData, p_slot: GraveSlot, p_team: GraveSlot.Team, p_lane_index: int) -> void:
		creature_data = p_creature_data
		slot = p_slot
		team = p_team
		lane_index = p_lane_index
		max_hp = p_creature_data.max_hp
		current_hp = p_creature_data.max_hp
		current_attack = p_creature_data.attack
		attack_speed = p_creature_data.attack_speed


var player_units: Array[CombatUnit] = []
var enemy_units: Array[CombatUnit] = []
var log_lines: Array[String] = []


func resolve(player_slots: Array[GraveSlot], enemy_slots: Array[GraveSlot]) -> Result:
	player_units = _build_units(player_slots, GraveSlot.Team.PLAYER)
	enemy_units = _build_units(enemy_slots, GraveSlot.Team.ENEMY)

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
				_perform_attack(unit)

	var player_alive := _team_alive(player_units)
	var enemy_alive := _team_alive(enemy_units)

	var result: Result
	if player_alive and not enemy_alive:
		result = Result.PLAYER_WIN
	elif enemy_alive and not player_alive:
		result = Result.ENEMY_WIN
	else:
		result = Result.DRAW

	_log("Combat ended after %.1fs — %s" % [elapsed, Result.find_key(result)])
	return result


func _build_units(slots: Array[GraveSlot], team: GraveSlot.Team) -> Array[CombatUnit]:
	var units: Array[CombatUnit] = []
	for slot in slots:
		if slot.occupant == null:
			continue
		units.append(CombatUnit.new(slot.occupant.creature_data, slot, team, slot.slot_index))
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


func _perform_attack(attacker: CombatUnit) -> void:
	var target := _lane_opponent(attacker)
	if target == null or not target.alive:
		return # lane opponent is dead — idle rather than retarget

	_fire_trigger(attacker, "ON_ATTACK", {"target": target})
	if not attacker.alive:
		return # an ON_ATTACK ability could theoretically kill its own source later

	var damage := attacker.current_attack
	target.current_hp = max(target.current_hp - damage, 0)
	_log("%s attacks %s for %d damage. %s HP: %d/%d" % [
		attacker.creature_data.creature_name, target.creature_data.creature_name, damage,
		target.creature_data.creature_name, target.current_hp, target.max_hp,
	])

	_fire_trigger(target, "ON_HIT", {"attacker": attacker})

	if target.current_hp <= 0:
		_kill(target, attacker)


func _kill(target: CombatUnit, killer: CombatUnit) -> void:
	if not target.alive:
		return

	target.alive = false
	if target.slot:
		target.slot.clear()
	_log("%s has died!" % target.creature_data.creature_name)

	if killer:
		_fire_trigger(killer, "ON_KILL", {"target": target})
	_fire_trigger(target, "ON_DEATH", {"killer": killer})


func _fire_trigger(unit: CombatUnit, trigger: String, context: Dictionary) -> void:
	for ability in unit.creature_data.abilities:
		if ability.trigger != trigger:
			continue
		var targets := _resolve_ability_targets(unit, ability, context)
		_apply_ability_effect(unit, ability, targets)


func _resolve_ability_targets(unit: CombatUnit, ability: Ability, context: Dictionary) -> Array[CombatUnit]:
	match ability.target:
		"SELF":
			return [unit]

		"ADJACENT_ALLY":
			var result: Array[CombatUnit] = []
			for ally in _team_units(unit.team):
				if ally == unit or not ally.alive:
					continue
				if abs(ally.lane_index - unit.lane_index) == 1:
					result.append(ally)
			return result

		"ALL_ALLIES":
			return _team_units(unit.team).filter(func(a): return a.alive)

		"TARGETED_ENEMY":
			var event_unit: CombatUnit = context.get("target", context.get("attacker", context.get("killer")))
			return [event_unit] if event_unit != null and event_unit.alive else []

		"RANDOM_ENEMY":
			var alive_enemies := _team_units(_other_team(unit.team)).filter(func(e): return e.alive)
			return [alive_enemies.pick_random()] if not alive_enemies.is_empty() else []

		"FRONT_ENEMY":
			var alive_enemies2 := _team_units(_other_team(unit.team)).filter(func(e): return e.alive)
			if alive_enemies2.is_empty():
				return []
			alive_enemies2.sort_custom(func(a, b): return a.lane_index < b.lane_index)
			return [alive_enemies2[0]]

	return []


func _apply_ability_effect(source: CombatUnit, ability: Ability, targets: Array[CombatUnit]) -> void:
	match ability.effect_type:
		"DAMAGE":
			for target in targets:
				if not target.alive:
					continue
				target.current_hp = max(target.current_hp - ability.magnitude, 0)
				_log("%s's ability deals %d damage to %s. %s HP: %d/%d" % [
					source.creature_data.creature_name, ability.magnitude, target.creature_data.creature_name,
					target.creature_data.creature_name, target.current_hp, target.max_hp,
				])
				if target.current_hp <= 0:
					_kill(target, source)

		"BUFF_ATTACK":
			for target in targets:
				if not target.alive:
					continue
				target.current_attack += ability.magnitude
				_log("%s's ability triggers: %s attack buffed to %d" % [
					source.creature_data.creature_name, target.creature_data.creature_name, target.current_attack,
				])

		"HEAL", "BUFF_HP", "SUMMON":
			pass # not implemented yet — stubbed no-op


func _log(text: String) -> void:
	log_lines.append(text)
	print(text)
