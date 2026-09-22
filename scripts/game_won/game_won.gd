extends Control

@onready var info_label: Label = $CenterContainer/VBoxContainer/InfoLabel
@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton


func _ready() -> void:
	info_label.text = "YOU WIN!\n%s defeated!" % RoundManager.BOSS_NAME
	print("=== YOU WIN === %s defeated!" % RoundManager.BOSS_NAME)
	retry_button.pressed.connect(_on_retry_pressed)


func _on_retry_pressed() -> void:
	RoundManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
