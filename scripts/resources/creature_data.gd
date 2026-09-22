extends Resource
class_name CreatureData

## Identity
@export var creature_name: String = ""
@export_enum("bone_beasts", "slime_skulls", "skull_wings", "bone_bugs", "skull_humanoids")
var evolution_line: String = "bone_beasts"
@export_range(1, 4, 1) var stage: int = 1

## Combat stats
@export var max_hp: int = 0
@export var attack: int = 0
@export var attack_speed: float = 1.0

## Economy
@export var shop_cost: int = 0
@export var bone_value: int = 0

## Visuals
@export var sprite: Texture2D

## Evolution — the CreatureData this becomes when merged, null at stage 4
@export var next_stage: CreatureData
