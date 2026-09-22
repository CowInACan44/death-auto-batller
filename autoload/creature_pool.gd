extends Node

## Central registry of all known CreatureData resources, loaded once at
## startup. Other systems (shop, encounter generation, etc.) draw from this
## instead of touching the filesystem directly.

const CREATURE_PATHS: Array[String] = [
	"res://resources/creatures/bone_beasts/stage_1.tres",
	"res://resources/creatures/bone_beasts/stage_2.tres",
	"res://resources/creatures/bone_beasts/stage_3.tres",
	"res://resources/creatures/slime_skulls/stage_1.tres",
	"res://resources/creatures/slime_skulls/stage_2.tres",
	"res://resources/creatures/slime_skulls/stage_3.tres",
	"res://resources/creatures/skull_wings/stage_1.tres",
	"res://resources/creatures/skull_wings/stage_2.tres",
	"res://resources/creatures/skull_wings/stage_3.tres",
	"res://resources/creatures/bone_bugs/stage_1.tres",
	"res://resources/creatures/bone_bugs/stage_2.tres",
	"res://resources/creatures/bone_bugs/stage_3.tres",
	"res://resources/creatures/skull_humanoids/stage_1.tres",
	"res://resources/creatures/skull_humanoids/stage_2.tres",
	"res://resources/creatures/skull_humanoids/stage_3.tres",
	"res://resources/creatures/bonus/crawler.tres",
	"res://resources/creatures/bonus/mushroom.tres",
	"res://resources/creatures/bonus/ghost.tres",
	"res://resources/creatures/bonus/imp.tres",
	"res://resources/creatures/bonus/golem.tres",
]

## Every known creature (all 3 stages of all 5 lines, plus the 5 bonus
## creatures) — the full registry, mainly for lookups.
var all_creatures: Array[CreatureData] = []

## The subset actually offerable in the shop / drawable into an encounter:
## stage-1 line creatures and bonus creatures. Stage 2/3 creatures exist
## only as evolution targets, never a direct pull.
var purchasable_creatures: Array[CreatureData] = []


func _ready() -> void:
	for path in CREATURE_PATHS:
		all_creatures.append(load(path) as CreatureData)

	purchasable_creatures = all_creatures.filter(func(c): return c.stage == 1)


func get_by_line_and_stage(evolution_line: String, stage: int) -> CreatureData:
	for creature in all_creatures:
		if creature.evolution_line == evolution_line and creature.stage == stage:
			return creature
	return null
