extends Control

# Shop scene: Gravedigger shop UI for buying/selling creatures.
# Buy/reroll/lock logic below; merge/evolve-on-buy is the next piece.

const SHOP_SIZE := 5
const REROLL_COST := 1
const OWNED_LINE_WEIGHT_BONUS := 2.0

class ShopSlot:
	var creature: CreatureData
	var locked: bool = false

var slots: Array[ShopSlot] = []


func _ready() -> void:
	for i in SHOP_SIZE:
		slots.append(ShopSlot.new())

	# Temporary: seed a fake player team so the "favor owned lines"
	# weighting is visible when running this scene standalone, ahead
	# of Battle <-> Shop scene transitions existing.
	if RoundManager.player_team.is_empty():
		var bone_pup := CreaturePool.get_by_line_and_stage("bone_beasts", 1)
		RoundManager.player_team = [bone_pup, bone_pup]
		print("(Shop test) seeded player_team with 2x %s to demonstrate weighting" % bone_pup.creature_name)

	reroll()

	# Temporary test of lock/reroll/buy — remove once shop UI exists.
	toggle_lock(0)
	reroll()
	buy_creature(1)


## Refills all non-locked (and any now-empty) slots from CreaturePool,
## weighted toward evolution lines the player already owns. Costs bones;
## fails gracefully (leaving slots untouched) if the player can't afford it.
func reroll() -> bool:
	if not Economy.spend_bones(REROLL_COST):
		print("Reroll failed — not enough bones")
		return false

	var owned_lines := _count_owned_lines(RoundManager.player_team)

	for slot in slots:
		if slot.creature == null or not slot.locked:
			slot.creature = _pick_weighted(CreaturePool.purchasable_creatures, owned_lines)

	print("Shop rerolled")
	_print_slots()
	return true


func toggle_lock(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return

	var slot := slots[slot_index]
	slot.locked = not slot.locked
	print("Slot %d %s" % [slot_index, "locked" if slot.locked else "unlocked"])


## Returns the bought CreatureData (for the caller to add to the
## player's team/bench) on success, or null if the slot is empty or
## unaffordable.
func buy_creature(slot_index: int) -> CreatureData:
	if slot_index < 0 or slot_index >= slots.size():
		return null

	var slot := slots[slot_index]
	if slot.creature == null:
		print("Slot %d is empty" % slot_index)
		return null

	if not Economy.spend_bones(slot.creature.shop_cost):
		print("Can't afford %s" % slot.creature.creature_name)
		return null

	var bought := slot.creature
	slot.creature = null
	print("Bought %s" % bought.creature_name)
	return bought


func _count_owned_lines(team: Array[CreatureData]) -> Dictionary:
	var counts := {}
	for creature in team:
		counts[creature.evolution_line] = counts.get(creature.evolution_line, 0) + 1
	return counts


func _weight_for(creature: CreatureData, owned_lines: Dictionary) -> float:
	var owned_count: int = owned_lines.get(creature.evolution_line, 0)
	return 1.0 + owned_count * OWNED_LINE_WEIGHT_BONUS


func _pick_weighted(pool: Array[CreatureData], owned_lines: Dictionary) -> CreatureData:
	var weights: Array[float] = []
	var total_weight := 0.0
	for creature in pool:
		var w := _weight_for(creature, owned_lines)
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
	var owned_lines := _count_owned_lines(RoundManager.player_team)
	print("Shop offers:")
	for i in slots.size():
		var slot := slots[i]
		if slot.creature == null:
			print("  [%d] (empty)%s" % [i, " [LOCKED]" if slot.locked else ""])
			continue
		var weight := _weight_for(slot.creature, owned_lines)
		print("  [%d] %s (%s) — cost: %d bones, weight: %.1f%s" % [
			i,
			slot.creature.creature_name,
			slot.creature.evolution_line,
			slot.creature.shop_cost,
			weight,
			" [LOCKED]" if slot.locked else "",
		])
