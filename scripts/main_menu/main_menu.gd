extends Control

# Bare-minimum stub — no visual design yet. Press Enter/Space (the
# built-in ui_accept action) to start a fresh run.


func _ready() -> void:
	print("=== MAIN MENU === Press Enter/Space to start a new run.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_game()


func _start_game() -> void:
	RoundManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
