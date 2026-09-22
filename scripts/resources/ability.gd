extends Resource
class_name Ability

@export_enum("ON_ATTACK", "ON_HIT", "ON_KILL", "ON_DEATH")
var trigger: String = "ON_ATTACK"

@export_enum("SELF", "ADJACENT_ALLY", "ALL_ALLIES", "TARGETED_ENEMY", "RANDOM_ENEMY", "FRONT_ENEMY")
var target: String = "SELF"

@export_enum("DAMAGE", "HEAL", "BUFF_ATTACK", "BUFF_HP", "SUMMON")
var effect_type: String = "DAMAGE"

## How much damage/heal/buff this ability applies.
@export var magnitude: int = 0

## Only used when effect_type == SUMMON, null otherwise.
@export var summon_creature: CreatureData
