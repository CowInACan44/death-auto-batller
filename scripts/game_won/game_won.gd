extends Control

# Bare-minimum stub — no visual design yet. Triggered when RoundManager
# hits GAME_WON (Night 7 boss defeated). Press Enter/Space to play again.


func _ready() -> void:
	print("=== YOU WIN === %s defeated! Press Enter/Space to play again." % RoundManager.BOSS_NAME)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_retry()


func _retry() -> void:
	RoundManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
