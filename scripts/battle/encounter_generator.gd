class_name EncounterGenerator
extends RefCounted

## Rough combat-power estimate for a single creature.
## Placeholder formula — will be revisited once real stats are balanced.
static func creature_power(creature: CreatureData) -> float:
	return creature.max_hp * 0.1 + creature.attack * creature.attack_speed


## Combat-power estimate for a full team.
static func team_power(team: Array[CreatureData]) -> float:
	var total := 0.0
	for creature in team:
		total += creature_power(creature)
	return total


## Randomly assembles an enemy team from `pool`, picking creatures until
## its power roughly matches `player_team`'s power (or the unit cap /
## pool is exhausted). No two runs with the same player team are
## guaranteed to produce the same enemy team.
static func generate_encounter(
	player_team: Array[CreatureData],
	pool: Array[CreatureData],
	max_units: int = 4
) -> Array[CreatureData]:
	var target_power := team_power(player_team)
	var candidates := pool.duplicate()
	candidates.shuffle()

	var enemy_team: Array[CreatureData] = []
	var enemy_power := 0.0

	while enemy_team.size() < max_units and enemy_power < target_power and not candidates.is_empty():
		var pick: CreatureData = candidates.pop_back()
		enemy_team.append(pick)
		enemy_power += creature_power(pick)

	return enemy_team
