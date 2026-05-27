class_name DefaultActionSet

const _DIR := "res://Scripts/Actions/Resources/"

static func create() -> MercActionSet:
	var action_set := MercActionSet.new()
	action_set.actions = [
		load(_DIR + "Pass.tres"),
		load(_DIR + "BreakFree.tres"),
		load(_DIR + "GetUp.tres"),
		load(_DIR + "EndBurning.tres"),
		load(_DIR + "BreakFall.tres"),
		load(_DIR + "SeekCover.tres"),
		load(_DIR + "OpenDoor.tres"),
		load(_DIR + "Draw.tres"),
		load(_DIR + "MoveFar.tres"),
		load(_DIR + "RepositionToAlly.tres"),
		load(_DIR + "MoveClose.tres"),
		load(_DIR + "Shove.tres"),
		load(_DIR + "Evade.tres"),
		load(_DIR + "Aim.tres"),
		load(_DIR + "AttackMelee.tres"),
		load(_DIR + "AttackRange.tres"),
		load(_DIR + "AdvantageAttack.tres"),
		load(_DIR + "Assist.tres"),
		load(_DIR + "Resist.tres"),
		load(_DIR + "DeathTest.tres"),
		load(_DIR + "UseItem.tres"),
	]
	return action_set
