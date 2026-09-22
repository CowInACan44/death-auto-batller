extends Control

# Bare-minimum stub — no visual design yet. Triggered when RoundManager
# hits GAME_OVER (hearts reach 0). Press Enter/Space to retry.


func _ready() -> void:
	print("=== GAME OVER === Ran out of hearts on Night %d. Press Enter/Space to retry." % RoundManager.round_number)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_retry()


func _retry() -> void:
	RoundManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
