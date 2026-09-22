extends Control

# Shown once, right after Start, before Day 1. Offers OFFER_COUNT random
# distinct creatures; picking one adds it to the roster (auto-activated)
# and heads into the Shop for Day 1.

const OFFER_COUNT := 3

@onready var offers_container: VBoxContainer = $Layout/OffersContainer

var _offered: Array[CreatureData] = []


func _ready() -> void:
	var pool := CreaturePool.purchasable_creatures.duplicate()
	pool.shuffle()
	_offered = pool.slice(0, min(OFFER_COUNT, pool.size()))

	for creature in _offered:
		var row := HBoxContainer.new()

		var info_label := Label.new()
		info_label.custom_minimum_size = Vector2(320, 0)
		info_label.text = "%s (%s) — HP %d, ATK %d" % [
			creature.creature_name, creature.evolution_line, creature.max_hp, creature.attack,
		]
		row.add_child(info_label)

		var pick_button := Button.new()
		pick_button.text = "Pick"
		pick_button.pressed.connect(_on_pick_pressed.bind(creature))
		row.add_child(pick_button)

		offers_container.add_child(row)

	var names: Array[String] = []
	for creature in _offered:
		names.append(creature.creature_name)
	print("=== CHOOSE YOUR FIRST SKULL DUDE === %s" % ", ".join(names))


func _on_pick_pressed(creature: CreatureData) -> void:
	RoundManager.add_to_roster(OwnedCreature.new(creature))
	print("Picked %s!" % creature.creature_name)
	get_tree().change_scene_to_file("res://scenes/shop/shop.tscn")
