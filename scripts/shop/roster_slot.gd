extends Panel
class_name RosterSlot

## Reusable drag-and-drop UI piece for the Shop's active lineup slots and
## bench entries. Godot's built-in drag-threshold detection is what tells
## a click (emits `clicked`, opens the details popup) apart from a drag
## (`_get_drag_data` only fires once the pointer has moved past the OS
## drag threshold) — no manual bookkeeping needed here. Listening for
## `clicked` on the mouse-button-release event (rather than press) matters:
## a release that ends a drag is consumed by the drag system and never
## reaches `_gui_input`, so only a genuine click ever fires it.

signal creature_dropped(owned_creature: OwnedCreature, target_slot: RosterSlot)
signal clicked(owned_creature: OwnedCreature)

var owned_creature: OwnedCreature = null
## -1 means this is a bench slot (not lane-indexed); 0..MAX_ACTIVE-1 for
## active lanes — set by Shop when building each slot.
var active_index: int = -1

@onready var label: Label = $Label


func set_creature(owned: OwnedCreature) -> void:
	owned_creature = owned
	if owned == null:
		label.text = "(empty)"
		return
	var shiny_tag := "✨ " if owned.is_shiny else ""
	label.text = "%s%s\n(stage %d)" % [shiny_tag, owned.data.creature_name, owned.data.stage]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if owned_creature == null:
		return null
	var preview := Label.new()
	preview.text = label.text
	preview.add_theme_color_override("font_color", Color.WHITE)
	set_drag_preview(preview)
	return {"owned": owned_creature}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("owned")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	creature_dropped.emit(data["owned"], self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if owned_creature != null:
			clicked.emit(owned_creature)
