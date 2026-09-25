extends Node2D
class_name Unit

## Base creature/unit scene: shows creature_data.sprite if one's been set,
## otherwise falls back to a colored placeholder body (color is just a
## per-evolution-line differentiator until every creature has real art).
## A name label sits above, and a heart/sword icon pair below shows
## current HP/Attack (Super Auto Pets style).
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
@onready var sprite_rect: TextureRect = $SpriteRect
@onready var name_label: Label = $NameLabel
@onready var hp_label: Label = $HPLabel
@onready var attack_label: Label = $AttackLabel

var _is_dead := false


func _ready() -> void:
	_apply_visual()
	_update_name()
	update_display(_effective_max_hp(), _effective_attack())


## Real art wins when a creature has it; otherwise falls back to the
## colored placeholder body. Both nodes occupy the same rect, so this
## just toggles which one is visible.
func _apply_visual() -> void:
	if creature_data != null and creature_data.sprite != null:
		sprite_rect.texture = creature_data.sprite
		sprite_rect.modulate = SHINY_TINT if is_shiny else Color.WHITE
		sprite_rect.visible = true
		body.visible = false
		return

	sprite_rect.visible = false
	body.visible = true
	if creature_data == null:
		body.color = DEFAULT_COLOR
		return
	var base_color: Color = LINE_COLORS.get(creature_data.evolution_line, DEFAULT_COLOR)
	body.color = base_color * SHINY_TINT if is_shiny else base_color


func _update_name() -> void:
	if creature_data == null:
		name_label.text = ""
		return
	var shiny_prefix := "✨" if is_shiny else ""
	name_label.text = "%s%s" % [shiny_prefix, creature_data.creature_name]


func _effective_max_hp() -> int:
	return OwnedCreature.calc_effective_max_hp(creature_data, is_shiny) if creature_data else 0


func _effective_attack() -> int:
	return OwnedCreature.calc_effective_attack(creature_data, is_shiny) if creature_data else 0


## Called by CombatResolver whenever this unit's HP or Attack changes, so
## the icons stay live during a fight instead of only reflecting the
## starting values.
func update_display(current_hp: int, current_attack: int) -> void:
	if _is_dead or creature_data == null:
		return
	hp_label.text = "♥ %d" % current_hp
	attack_label.text = "⚔ %d" % current_attack


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
	sprite_rect.modulate = Color(0.6, 0.6, 0.6)
	name_label.modulate = Color(0.6, 0.6, 0.6)
	hp_label.modulate = Color(0.6, 0.6, 0.6)
	attack_label.modulate = Color(0.6, 0.6, 0.6)
	name_label.text += " (dead)"
