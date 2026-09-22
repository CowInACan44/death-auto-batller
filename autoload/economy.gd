extends Node

## Player's bone currency. Bones are earned when creatures die in combat
## and spent in the Gravedigger shop. Real per-unit death tracking doesn't
## exist yet — RoundManager currently simulates deaths as a placeholder.

const STARTING_BONES := 10

var bones: int = STARTING_BONES


func award_bones(amount: int) -> void:
	bones += amount
	print("+%d bones, total: %d" % [amount, bones])


func spend_bones(amount: int) -> bool:
	if amount > bones:
		print("Can't spend %d bones, only have %d" % [amount, bones])
		return false

	bones -= amount
	print("-%d bones, total: %d" % [amount, bones])
	return true


## Called on a fresh run (see RoundManager.reset_run()) so a retry starts
## with the same baseline bones as a brand new game.
func reset() -> void:
	bones = STARTING_BONES
	print("Bones reset to %d" % bones)
