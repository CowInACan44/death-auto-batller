class_name OwnedCreature
extends RefCounted

## Wraps a CreatureData reference with per-instance state that must NOT
## live on the shared resource itself (the same CreatureData is reused
## across every copy of that creature — bench, shop offers, etc.). Shiny
## is the first such field; evolution stage-tracking will likely join it
## here later.

const SHINY_STAT_MULTIPLIER := 1.2

var data: CreatureData
var is_shiny: bool = false


func _init(p_data: CreatureData, p_is_shiny: bool = false) -> void:
	data = p_data
	is_shiny = p_is_shiny


func effective_max_hp() -> int:
	return calc_effective_max_hp(data, is_shiny)


func effective_attack() -> int:
	return calc_effective_attack(data, is_shiny)


## Shared formula so shop offers (not yet "owned") can preview boosted
## stats without constructing an OwnedCreature just to display them.
static func calc_effective_max_hp(creature: CreatureData, shiny: bool) -> int:
	return int(round(creature.max_hp * (SHINY_STAT_MULTIPLIER if shiny else 1.0)))


static func calc_effective_attack(creature: CreatureData, shiny: bool) -> int:
	return int(round(creature.attack * (SHINY_STAT_MULTIPLIER if shiny else 1.0)))
