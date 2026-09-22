extends Control

# Minimal main menu — no real art, just a title and a Start button.

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton


func _ready() -> void:
	print("=== MAIN MENU ===")
	start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	RoundManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
