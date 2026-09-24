extends Resource
class_name CreatureData

## Identity
@export var creature_name: String = ""
## "none" marks a standalone bonus creature with no evolution line.
@export_enum("bone_beasts", "slime_skulls", "skull_wings", "bone_bugs", "skull_humanoids", "none")
var evolution_line: String = "bone_beasts"
@export_range(1, 3, 1) var stage: int = 1
## Pokedex-style flavor text shown in the Shop details popup.
@export_multiline var description: String = ""

## Combat stats
@export var max_hp: int = 0
@export var attack: int = 0
@export var attack_speed: float = 1.0

## Economy
@export var shop_cost: int = 0
@export var bone_value: int = 0

## Visuals
@export var sprite: Texture2D

## Evolution — the CreatureData this becomes when merged, null at stage 3
@export var next_stage: CreatureData

## Combat-event abilities (Super Auto Pets-style). Empty by default —
## trigger resolution doesn't exist yet, this is data shape only.
@export var abilities: Array[Ability] = []
