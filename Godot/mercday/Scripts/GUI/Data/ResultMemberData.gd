class_name ResultMemberData extends RefCounted

#One merc's line on the contract results panel: how they came home, what they gained and what they are paid.
#The bar fields hold the value at the end of the contract; the _before fields hold the value at departure.

enum Fate {ALIVE, DEAD, CAPTURED}

const FATE_NAMES: Array[String] = ["Alive", "Deceased", "Captured"]

var uid: int = 0
var name: String = ""
var role: String = ""
var tradition: String = ""
var fate: int = Fate.ALIVE
var level_before: int = 0
var level_after: int = 0
#Progress inside level_before when the team left, and how much of the next level is needed.
var xp_before: int = 0
var xp_need: int = 0
var xp_gained: int = 0
#The need of the level gained, used by the carry over fill; 0 keeps xp_need.
var xp_need_after: int = 0
#Each bar is (value at return, maximum).
var hp: Vector2i = Vector2i.ZERO
var ep: Vector2i = Vector2i.ZERO
var mp: Vector2i = Vector2i.ZERO
var hp_before: int = 0
var ep_before: int = 0
var mp_before: int = 0
var mvp: bool = false
var pay: int = 0


func fate_name() -> String:
	return FATE_NAMES[clampi(fate, 0, FATE_NAMES.size() - 1)]


func alive() -> bool:
	return fate == Fate.ALIVE


func levelled() -> bool:
	return level_after > level_before
