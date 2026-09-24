extends Resource
class_name Ability

@export_enum("ON_ATTACK", "ON_HIT", "ON_KILL", "ON_DEATH")
var trigger: String = "ON_ATTACK"

@export_enum("SELF", "ADJACENT_ALLY", "ALL_ALLIES", "TARGETED_ENEMY", "RANDOM_ENEMY", "FRONT_ENEMY", "TOP_ENEMY")
var target: String = "SELF"

@export_enum("DAMAGE", "HEAL", "BUFF_ATTACK", "BUFF_HP", "SUMMON")
var effect_type: String = "DAMAGE"

## How much damage/heal/buff this ability applies, or how many copies to
## summon when effect_type == SUMMON.
@export var magnitude: int = 0

## When true, the applied magnitude is multiplied by how many of the
## source's living teammates (itself included) share its evolution_line —
## e.g. Bone Beetle's on-kill buff scales with how many Bone Bugs-line
## creatures are still on the team, instead of staying flat.
@export var scales_with_owned_line_count: bool = false

## Only used when effect_type == SUMMON, null otherwise.
@export var summon_creature: CreatureData
