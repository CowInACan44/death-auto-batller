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

## Only used when effect_type == SUMMON. Deliberately NOT a direct
## CreatureData reference — a summon target is typically an earlier stage
## of the same line, which already points forward to this stage via
## next_stage, and Godot's .tres loader can't resolve that 2-file resource
## cycle at parse time (confirmed: it fails both files with "referenced
## non-existent resource"). Resolved through CreaturePool at the moment
## the ability fires instead.
@export_enum("bone_beasts", "slime_skulls", "skull_wings", "bone_bugs", "skull_humanoids", "none") var summon_evolution_line: String = ""
@export_range(1, 3, 1) var summon_stage: int = 1
