extends Node

## Central registry of all known CreatureData resources, loaded once at
## startup. Other systems (shop, encounter generation, etc.) draw from this
## instead of touching the filesystem directly.

const CREATURE_PATHS: Array[String] = [
	"res://resources/creatures/bone_beasts/stage_1.tres",
	"res://resources/creatures/slime_skulls/stage_1.tres",
	"res://resources/creatures/skull_wings/stage_1.tres",
	"res://resources/creatures/bone_bugs/stage_1.tres",
	"res://resources/creatures/skull_humanoids/stage_1.tres",
]

var all_creatures: Array[CreatureData] = []


func _ready() -> void:
	for path in CREATURE_PATHS:
		all_creatures.append(load(path) as CreatureData)


func get_by_line_and_stage(evolution_line: String, stage: int) -> CreatureData:
	for creature in all_creatures:
		if creature.evolution_line == evolution_line and creature.stage == stage:
			return creature
	return null
