extends Control

# Shop scene: Gravedigger shop UI for buying creatures, managing the
# active lineup (max RoundManager.MAX_ACTIVE), and heading into the next
# Night. Buying (RoundManager.add_to_roster) triggers merge/evolve
# automatically — see RoundManager.check_for_merge().

const SHOP_SIZE := 5
const REROLL_COST := 1
const OWNED_LINE_WEIGHT_BONUS := 2.0
const SHINY_CHANCE := 0.05

class ShopSlot:
	var creature: CreatureData
	var locked: bool = false
	## Rolled once when the slot is populated (offer time, not purchase
	## time) so the shop can display the boosted stats before it's bought.
	var is_shiny: bool = false

var slots: Array[ShopSlot] = []

@onready var bones_label: Label = $Layout/BonesLabel
@onready var lineup_label: Label = $Layout/LineupLabel
@onready var lineup_container: VBoxContainer = $Layout/LineupContainer
@onready var slots_container: VBoxContainer = $Layout/SlotsContainer
@onready var reroll_button: Button = $Layout/RerollButton
@onready var fight_button: Button = $Layout/FightButton

## One HBoxContainer row (info label + Buy/Lock buttons) per shop slot,
## built once in _ready() and refreshed (not rebuilt) on every change.
var _row_nodes: Array[HBoxContainer] = []


func _ready() -> void:
	for i in SHOP_SIZE:
		slots.append(ShopSlot.new())

	# Standalone testing fallback (e.g. running this scene directly via
	# F6 without going through StarterPick first) — the real flow always
	# arrives here with a non-empty roster already.
	if RoundManager.roster.is_empty():
		var bone_pup := CreaturePool.get_by_line_and_stage("bone_beasts", 1)
		RoundManager.add_to_roster(OwnedCreature.new(bone_pup))
		print("(Shop test) seeded roster with 1x %s since it was empty" % bone_pup.creature_name)

	_build_rows()
	reroll_button.pressed.connect(_on_reroll_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	reroll()
	_refresh_ui()


func _build_rows() -> void:
	for i in SHOP_SIZE:
		var row := HBoxContainer.new()

		var info_label := Label.new()
		info_label.custom_minimum_size = Vector2(420, 0)
		row.add_child(info_label)

		var buy_button := Button.new()
		buy_button.text = "Buy"
		buy_button.pressed.connect(_on_buy_pressed.bind(i))
		row.add_child(buy_button)

		var lock_button := Button.new()
		lock_button.text = "Lock"
		lock_button.pressed.connect(_on_lock_pressed.bind(i))
		row.add_child(lock_button)

		slots_container.add_child(row)
		_row_nodes.append(row)


func _on_reroll_pressed() -> void:
	reroll()
	_refresh_ui()


func _on_fight_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")


func _on_buy_pressed(slot_index: int) -> void:
	var bought := buy_creature(slot_index)
	if bought:
		RoundManager.add_to_roster(bought)
	_refresh_ui()


func _on_lock_pressed(slot_index: int) -> void:
	toggle_lock(slot_index)
	_refresh_ui()


func _on_toggle_active_pressed(owned: OwnedCreature) -> void:
	var currently_active: bool = owned in RoundManager.active_lineup
	var ok := RoundManager.set_active(owned, not currently_active)
	if not ok:
		print("Lineup full (%d) — bench someone first" % RoundManager.MAX_ACTIVE)
	_refresh_ui()


## Refills all non-locked (and any now-empty) slots from CreaturePool,
## weighted toward evolution lines the player already owns. Each refilled
## slot gets an independent SHINY_CHANCE roll. Costs bones; fails
## gracefully (leaving slots untouched) if the player can't afford it.
func reroll() -> bool:
	if not Economy.spend_bones(REROLL_COST):
		print("Reroll failed — not enough bones")
		return false

	var owned_lines := _count_owned_lines(RoundManager.roster)
	var owned_names := _count_owned_names(RoundManager.roster)

	for slot in slots:
		if slot.creature == null or not slot.locked:
			slot.creature = _pick_weighted(CreaturePool.purchasable_creatures, owned_lines, owned_names)
			slot.is_shiny = randf() < SHINY_CHANCE
			if slot.is_shiny:
				print("✨ Shiny %s appeared in the shop! HP: %d, Attack: %d" % [
					slot.creature.creature_name,
					OwnedCreature.calc_effective_max_hp(slot.creature, true),
					OwnedCreature.calc_effective_attack(slot.creature, true),
				])

	print("Shop rerolled")
	_print_slots()
	return true


func toggle_lock(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return

	var slot := slots[slot_index]
	slot.locked = not slot.locked
	print("Slot %d %s" % [slot_index, "locked" if slot.locked else "unlocked"])


## Returns the bought creature as an OwnedCreature (carrying its shiny
## status) for the caller to add to the player's team/bench, or null if
## the slot is empty or unaffordable.
func buy_creature(slot_index: int) -> OwnedCreature:
	if slot_index < 0 or slot_index >= slots.size():
		return null

	var slot := slots[slot_index]
	if slot.creature == null:
		print("Slot %d is empty" % slot_index)
		return null

	if not Economy.spend_bones(slot.creature.shop_cost):
		print("Can't afford %s" % slot.creature.creature_name)
		return null

	var bought := OwnedCreature.new(slot.creature, slot.is_shiny)
	slot.creature = null
	slot.is_shiny = false
	print("Bought %s%s" % [("Shiny " if bought.is_shiny else ""), bought.data.creature_name])
	return bought


## Counts owned copies per evolution line, skipping "none" (bonus)
## creatures — those are weighted individually by name instead, see
## _count_owned_names(), so owning one bonus creature doesn't boost the
## odds of every other unrelated bonus creature.
func _count_owned_lines(team: Array[OwnedCreature]) -> Dictionary:
	var counts := {}
	for owned in team:
		if owned.data.evolution_line == "none":
			continue
		counts[owned.data.evolution_line] = counts.get(owned.data.evolution_line, 0) + 1
	return counts


func _count_owned_names(team: Array[OwnedCreature]) -> Dictionary:
	var counts := {}
	for owned in team:
		if owned.data.evolution_line != "none":
			continue
		counts[owned.data.creature_name] = counts.get(owned.data.creature_name, 0) + 1
	return counts


func _weight_for(creature: CreatureData, owned_lines: Dictionary, owned_names: Dictionary) -> float:
	var owned_count: int
	if creature.evolution_line == "none":
		owned_count = owned_names.get(creature.creature_name, 0)
	else:
		owned_count = owned_lines.get(creature.evolution_line, 0)
	return 1.0 + owned_count * OWNED_LINE_WEIGHT_BONUS


func _pick_weighted(pool: Array[CreatureData], owned_lines: Dictionary, owned_names: Dictionary) -> CreatureData:
	var weights: Array[float] = []
	var total_weight := 0.0
	for creature in pool:
		var w := _weight_for(creature, owned_lines, owned_names)
		weights.append(w)
		total_weight += w

	var roll := randf() * total_weight
	var cumulative := 0.0
	for i in pool.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return pool[i]

	return pool[pool.size() - 1]


func _print_slots() -> void:
	var owned_lines := _count_owned_lines(RoundManager.roster)
	var owned_names := _count_owned_names(RoundManager.roster)
	print("Shop offers:")
	for i in slots.size():
		var slot := slots[i]
		if slot.creature == null:
			print("  [%d] (empty)%s" % [i, " [LOCKED]" if slot.locked else ""])
			continue
		var weight := _weight_for(slot.creature, owned_lines, owned_names)
		var shiny_tag := "✨ " if slot.is_shiny else ""
		var hp := OwnedCreature.calc_effective_max_hp(slot.creature, slot.is_shiny)
		var attack := OwnedCreature.calc_effective_attack(slot.creature, slot.is_shiny)
		print("  [%d] %s%s (%s) — HP: %d, Attack: %d, cost: %d bones, weight: %.1f%s" % [
			i,
			shiny_tag,
			slot.creature.creature_name,
			slot.creature.evolution_line,
			hp,
			attack,
			slot.creature.shop_cost,
			weight,
			" [LOCKED]" if slot.locked else "",
		])


func _refresh_ui() -> void:
	bones_label.text = "Bones: %d" % Economy.bones
	_refresh_lineup_rows()

	for i in slots.size():
		var slot := slots[i]
		var row := _row_nodes[i]
		var info_label: Label = row.get_child(0)
		var buy_button: Button = row.get_child(1)
		var lock_button: Button = row.get_child(2)

		if slot.creature == null:
			info_label.text = "(empty)"
			buy_button.disabled = true
			lock_button.disabled = true
			lock_button.text = "Lock"
			continue

		var shiny_tag := "✨ " if slot.is_shiny else ""
		var hp := OwnedCreature.calc_effective_max_hp(slot.creature, slot.is_shiny)
		var attack := OwnedCreature.calc_effective_attack(slot.creature, slot.is_shiny)
		info_label.text = "%s%s (%s) — HP %d, ATK %d — %d bones" % [
			shiny_tag, slot.creature.creature_name, slot.creature.evolution_line, hp, attack, slot.creature.shop_cost,
		]
		buy_button.disabled = false
		lock_button.disabled = false
		lock_button.text = "Unlock" if slot.locked else "Lock"


## Roster size changes as you buy/merge, so this section is rebuilt from
## scratch each refresh rather than reused like the fixed-size shop rows.
func _refresh_lineup_rows() -> void:
	for child in lineup_container.get_children():
		child.queue_free()

	lineup_label.text = "Roster (%d/%d active):" % [RoundManager.active_lineup.size(), RoundManager.MAX_ACTIVE]

	for owned in RoundManager.roster:
		var row := HBoxContainer.new()
		var is_active: bool = owned in RoundManager.active_lineup

		var info_label := Label.new()
		info_label.custom_minimum_size = Vector2(320, 0)
		var shiny_tag := "✨ " if owned.is_shiny else ""
		info_label.text = "%s%s (stage %d) %s" % [
			shiny_tag, owned.data.creature_name, owned.data.stage, "[ACTIVE]" if is_active else "[BENCH]",
		]
		row.add_child(info_label)

		var toggle_button := Button.new()
		toggle_button.text = "Bench" if is_active else "Activate"
		toggle_button.pressed.connect(_on_toggle_active_pressed.bind(owned))
		row.add_child(toggle_button)

		lineup_container.add_child(row)
