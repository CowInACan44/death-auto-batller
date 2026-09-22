extends Node2D

# Battle scene: grave slots for player and enemy units. Combat itself is
# resolved by CombatResolver via RoundManager.resolve_combat(). Each load
# of this scene plays exactly one Night; _advance_after_battle() decides
# whether to reload for the next Night or hand off to GameOver/GameWon.

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")

@onready var player_grave_slots: Array[GraveSlot] = _collect_slots($PlayerGraveSlots)
@onready var enemy_grave_slots: Array[GraveSlot] = _collect_slots($EnemyGraveSlots)
@onready var hud_label: Label = $HUD/HUDLabel

## Guards against _run_round_loop_test() somehow firing twice on the same
## scene instance (e.g. a re-entrant _ready()) stacking two battles' worth
## of round/heart/bone state changes on top of each other silently.
var _battle_resolved := false


func _ready() -> void:
	RoundManager.register_battle(self)
	_update_hud()
	_run_round_loop_test()


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


## Temporary stand-in for a real Shop day — there's no Shop <-> Battle
## scene transition yet, so each Night re-seats the same fixed 2-unit
## test team (one forced shiny, to prove the stat boost carries into
## combat) rather than a persisted, shop-grown roster. Runs a real
## battle and feeds the result into end_battle_phase(), then hands off
## to _advance_after_battle() to route to the next Night, GameOver, or
## GameWon.
func _run_round_loop_test() -> void:
	if _battle_resolved:
		push_warning("Battle: _run_round_loop_test() called again on an already-resolved instance, ignoring")
		return
	_battle_resolved = true

	var test_team: Array[OwnedCreature] = [
		OwnedCreature.new(CreaturePool.get_by_line_and_stage("bone_beasts", 1), true), # forced shiny
		OwnedCreature.new(CreaturePool.get_by_line_and_stage("slime_skulls", 1)),
	]

	for i in test_team.size():
		var unit: Unit = UNIT_SCENE.instantiate()
		unit.creature_data = test_team[i].data
		unit.is_shiny = test_team[i].is_shiny
		add_child(unit)
		player_grave_slots[i].place_unit(unit)

	RoundManager.player_team = test_team
	RoundManager.start_battle_phase()

	var result := RoundManager.resolve_combat()
	# A draw (timeout with survivors on both sides) counts as not a win.
	RoundManager.end_battle_phase(result == CombatResolver.Result.PLAYER_WIN)

	_update_hud()
	_advance_after_battle()


## Routes to the scene end_battle_phase() decided on. GAME_OVER/GAME_WON
## hand off to their stub screens; anything else (still SHOP) reloads
## this scene as a stand-in for visiting a real Shop day.
func _advance_after_battle() -> void:
	match RoundManager.state:
		RoundManager.GameState.GAME_OVER:
			get_tree().change_scene_to_file("res://scenes/game_over/game_over.tscn")
		RoundManager.GameState.GAME_WON:
			get_tree().change_scene_to_file("res://scenes/game_won/game_won.tscn")
		_:
			get_tree().reload_current_scene()
