extends Control

@onready var info_label: Label = $CenterContainer/VBoxContainer/InfoLabel
@onready var retry_button: Button = $CenterContainer/VBoxContainer/RetryButton


func _ready() -> void:
	info_label.text = "GAME OVER\nRan out of hearts on Night %d" % RoundManager.round_number
	print("=== GAME OVER === Ran out of hearts on Night %d." % RoundManager.round_number)
	retry_button.pressed.connect(_on_retry_pressed)


func _on_retry_pressed() -> void:
	RoundManager.reset_run()
	get_tree().change_scene_to_file("res://scenes/starter_pick/starter_pick.tscn")
