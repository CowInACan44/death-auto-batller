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
