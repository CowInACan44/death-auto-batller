extends Node2D
class_name Unit

## Base creature/unit scene: a colored placeholder body + a name/HP label.
## No real art yet — color is just a per-evolution-line differentiator.
@export var creature_data: CreatureData
@export var is_shiny: bool = false

const LINE_COLORS := {
	"bone_beasts": Color(0.55, 0.35, 0.15),
	"slime_skulls": Color(0.55, 0.25, 0.75),
	"skull_wings": Color(0.3, 0.5, 0.9),
	"bone_bugs": Color(0.3, 0.6, 0.3),
	"skull_humanoids": Color(0.8, 0.8, 0.8),
	"none": Color(0.9, 0.6, 0.1),
}
const DEFAULT_COLOR := Color(0.5, 0.5, 0.5)
const DEAD_COLOR := Color(0.2, 0.2, 0.2)
## Placeholder gold tint until real shiny art exists.
const SHINY_TINT := Color(1.4, 1.2, 0.4, 1.0)

## Attack animation — a lunge toward the target and back. No art yet, just
## enough motion to read as "an attack happened" alongside the HP change.
const ATTACK_LUNGE_DISTANCE := 20.0
const ATTACK_LUNGE_LEG_DURATION := 0.15 # each leg (out, then back)

@onready var body: ColorRect = $Body
@onready var info_label: Label = $InfoLabel

var _is_dead := false


func _ready() -> void:
	_apply_color()
	var max_hp := _effective_max_hp()
	update_display(max_hp, max_hp)


func _apply_color() -> void:
	if creature_data == null:
		body.color = DEFAULT_COLOR
		return
	var base_color: Color = LINE_COLORS.get(creature_data.evolution_line, DEFAULT_COLOR)
	body.color = base_color * SHINY_TINT if is_shiny else base_color


func _effective_max_hp() -> int:
	return OwnedCreature.calc_effective_max_hp(creature_data, is_shiny) if creature_data else 0


## Called by CombatResolver whenever this unit's HP changes, so the label
## stays live during a fight instead of only reflecting the starting value.
func update_display(current_hp: int, max_hp: int) -> void:
	if _is_dead or creature_data == null:
		return
	var shiny_prefix := "✨" if is_shiny else ""
	info_label.text = "%s%s\n%d/%d" % [shiny_prefix, creature_data.creature_name, current_hp, max_hp]


## Lunges toward target_global_position and back — the total duration
## (2x ATTACK_LUNGE_LEG_DURATION) is what CombatResolver waits on between
## attacks, so this doubles as the fight's real-time pacing beat.
func play_attack_animation(target_global_position: Vector2) -> void:
	if _is_dead:
		return

	var lunge_offset := (target_global_position - global_position).normalized() * ATTACK_LUNGE_DISTANCE
	var original_position := position

	var tween := create_tween()
	tween.tween_property(self, "position", original_position + lunge_offset, ATTACK_LUNGE_LEG_DURATION)
	tween.tween_property(self, "position", original_position, ATTACK_LUNGE_LEG_DURATION)
	await tween.finished


## Visual death marker — grays the unit out and leaves it in place rather
## than freeing it immediately, since Battle reloads the whole scene each
## Night anyway. Called by GraveSlot.clear() instead of queue_free().
func die() -> void:
	_is_dead = true
	body.color = DEAD_COLOR
	info_label.modulate = Color(0.6, 0.6, 0.6)
	info_label.text += "\n(dead)"
