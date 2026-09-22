extends Node2D

# Battle scene: grave slots for player and enemy units. Combat itself is
# resolved by CombatResolver via RoundManager.resolve_combat().

const UNIT_SCENE := preload("res://scenes/unit/unit.tscn")

@onready var player_grave_slots: Array[GraveSlot] = _collect_slots($PlayerGraveSlots)
@onready var enemy_grave_slots: Array[GraveSlot] = _collect_slots($EnemyGraveSlots)


func _ready() -> void:
	RoundManager.register_battle(self)
	_run_merge_test()
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


## Temporary manual test of merge/evolve — remove once a real shop ->
## roster flow exists. Adds 3 identical (non-shiny) Bone Pups one at a
## time via add_to_roster(), which should auto-merge into 1 Bone Hound
## on the 3rd addition, then does the same with 3 shiny Skull Oozes to
## confirm shiny status carries into the evolved instance. Resets
## player_team afterward so it doesn't bleed into the tests below.
func _run_merge_test() -> void:
	var bone_pup := CreaturePool.get_by_line_and_stage("bone_beasts", 1)
	for i in 3:
		RoundManager.add_to_roster(OwnedCreature.new(bone_pup))

	var skull_ooze := CreaturePool.get_by_line_and_stage("slime_skulls", 1)
	for i in 3:
		RoundManager.add_to_roster(OwnedCreature.new(skull_ooze, true))

	print("Merge test roster (%d entries):" % RoundManager.player_team.size())
	for owned in RoundManager.player_team:
		print("  %s%s (stage %d)" % [
			"✨ " if owned.is_shiny else "",
			owned.data.creature_name,
			owned.data.stage,
		])

	RoundManager.player_team.clear()


## Temporary manual test of the round loop — remove once the shop
## exists. Manually seats a player team (one forced shiny, to prove the
## stat boost carries into combat), starts a battle phase (which
## generates + seats the enemy team), runs real combat, and feeds the
## result into end_battle_phase() to confirm the loop advances to
## round 2 correctly.
func _run_round_loop_test() -> void:
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

	_run_economy_test()


## Temporary manual test of spend_bones() — remove once the shop exists.
## Spends a small, affordable amount, then tries to overspend and
## confirms it's rejected without changing the total.
func _run_economy_test() -> void:
	var affordable := Economy.spend_bones(2)
	print("Spend 2 bones (should succeed): %s" % affordable)

	var too_much := Economy.spend_bones(9999)
	print("Spend 9999 bones (should fail): %s" % too_much)
