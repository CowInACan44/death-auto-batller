extends Resource
class_name CreatureData

## Identity
@export var creature_name: String = ""
@export var evolution_line: String = ""
@export var evolution_stage: int = 1

## Stats (placeholders — values to be defined)
@export var max_hp: int = 0
@export var attack_damage: int = 0

## Economy
@export var bone_cost: int = 0

## Visuals
@export var icon: Texture2D
