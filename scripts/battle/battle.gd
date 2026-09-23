extends Node2D

# Battle scene: grave slots for player and enemy units. RoundManager seats
# both sides (active lineup + generated encounter) and CombatResolver runs
# the fight, pausing briefly after each attack (see
# CombatResolver.ATTACK_DELAY) so it's actually watchable. Each load plays
# exactly one Night, waits for the player to hit Continue, then routes to
# the next Day (Shop), GameOver, or GameWon based on what
# end_battle_phase() decided.

@onready var player_grave_slots: Array[GraveSlot] = _collect_slots($PlayerGraveSlots)
@onready var enemy_grave_slots: Array[GraveSlot] = _collect_slots($EnemyGraveSlots)
@onready var hud_label: Label = $HUD/HUDLabel
@onready var result_label: Label = $HUD/ResultLabel
@onready var continue_button: Button = $HUD/ContinueButton

## Guards against _run_night() somehow firing twice on the same scene
## instance, stacking two nights' worth of round/heart/bone changes.
var _battle_resolved := false


func _ready() -> void:
	RoundManager.register_battle(self)
	_update_hud()
	continue_button.pressed.connect(_on_continue_pressed)
	_run_night()


func _collect_slots(container: Node) -> Array[GraveSlot]:
	var slots: Array[GraveSlot] = []
	for child in container.get_children():
		if child is GraveSlot:
			slots.append(child)
	return slots


func get_empty_slot(team: GraveSlot.Team) -> GraveSlot:
	var slots := player_grave_slots if team == GraveSlot.Team.PLAYER else enemy_grave_slots
	for slot in slots:
		if slot.is_empty():
			return slot
	return null


func _update_hud() -> void:
	var hearts_display := "❤".repeat(RoundManager.hearts) + "🖤".repeat(RoundManager.MAX_HEARTS - RoundManager.hearts)
	hud_label.text = "Night %d   Bones: %d   %s" % [RoundManager.round_number, Economy.bones, hearts_display]


func _run_night() -> void:
	if _battle_resolved:
		push_warning("Battle: _run_night() called again on an already-resolved instance, ignoring")
		return
	_battle_resolved = true

	RoundManager.start_battle_phase()

	# CombatResolver.resolve() awaits a short real-time pause after every
	# attack, so this line doesn't return until the fight has actually
	# played out visibly on screen.
	var result: CombatResolver.Result = await RoundManager.resolve_combat()
	var player_won := result == CombatResolver.Result.PLAYER_WIN
	RoundManager.end_battle_phase(player_won)

	_update_hud()
	result_label.text = "Night result: %s — tap Continue" % ("WIN" if player_won else "LOSS")
	result_label.visible = true
	continue_button.visible = true


func _on_continue_pressed() -> void:
	result_label.visible = false
	continue_button.visible = false
	_advance_after_battle()


## Routes to the scene end_battle_phase() decided on. GAME_OVER/GAME_WON
## hand off to their stub screens; anything else (still SHOP) heads to
## the Shop for the next Day.
func _advance_after_battle() -> void:
	match RoundManager.state:
		RoundManager.GameState.GAME_OVER:
			get_tree().change_scene_to_file("res://scenes/game_over/game_over.tscn")
		RoundManager.GameState.GAME_WON:
			get_tree().change_scene_to_file("res://scenes/game_won/game_won.tscn")
		_:
			get_tree().change_scene_to_file("res://scenes/shop/shop.tscn")
