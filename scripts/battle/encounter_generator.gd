class_name EncounterGenerator
extends RefCounted

## Rough combat-power estimate from raw stats.
## Placeholder formula — will be revisited once real stats are balanced.
static func _power(max_hp: int, attack: int, attack_speed: float) -> float:
	return max_hp * 0.1 + attack * attack_speed


## Power of a pool candidate (no shiny concept — pool entries are shared,
## unowned CreatureData).
static func power_for_data(creature: CreatureData) -> float:
	return _power(creature.max_hp, creature.attack, creature.attack_speed)


## Power of an owned creature, using its effective (shiny-boosted, if
## applicable) stats rather than its base CreatureData stats.
static func power_for_owned(owned: OwnedCreature) -> float:
	return _power(owned.effective_max_hp(), owned.effective_attack(), owned.data.attack_speed)


## Combat-power estimate for the player's owned team.
static func team_power(team: Array[OwnedCreature]) -> float:
	var total := 0.0
	for owned in team:
		total += power_for_owned(owned)
	return total


## Randomly assembles an enemy team from `pool`, picking creatures until
## its power roughly matches `player_team`'s power times `power_multiplier`
## (or the unit cap / pool is exhausted) — a boss encounter passes a
## multiplier > 1.0 to scale up the fight. No two runs with the same
## player team are guaranteed to produce the same enemy team. Enemies are
## plain CreatureData — encounters don't roll shiny, that's a shop-only
## concept for now.
static func generate_encounter(
	player_team: Array[OwnedCreature],
	pool: Array[CreatureData],
	max_units: int = 4,
	power_multiplier: float = 1.0
) -> Array[CreatureData]:
	var target_power := team_power(player_team) * power_multiplier
	var candidates := pool.duplicate()
	candidates.shuffle()

	var enemy_team: Array[CreatureData] = []
	var enemy_power := 0.0

	while enemy_team.size() < max_units and enemy_power < target_power and not candidates.is_empty():
		var pick: CreatureData = candidates.pop_back()
		enemy_team.append(pick)
		enemy_power += power_for_data(pick)

	return enemy_team
