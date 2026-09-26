class_name RescueDoors extends RefCounted

#Why a party merc may pick a locked door during a rescue: the captive's cell or the gear chest.

const CAPTIVE_CELL := "captive_cell"
const BLOCKED_GATE := "blocked_gate"
const GEAR_CHEST := "gear_chest"


#The rescue's reason for this locked door; BLOCKED_GATE means nobody wants the gate open now.
static func reason(merc: MercenaryData, obs: Dictionary, state: BattleState) -> String:
	if merc == null or obs.is_empty() or not RescueSystem.is_active(state):
		return ""
	if RescueSystem.is_gate(state, obs):
		return CAPTIVE_CELL if RescueTactics.gate_wanted(state) else BLOCKED_GATE
	var rescue: Dictionary = state.rescue
	if merc != (rescue.get("captive") as MercenaryData):
		return ""
	if not bool(rescue.get("freed", false)) or RescueSystem.needs(state) <= 0:
		return ""
	return GEAR_CHEST if _holds_chest(state, obs) else ""


#True when the room the door guards holds the captive's gear chest.
static func _holds_chest(state: BattleState, obs: Dictionary) -> bool:
	var chest: Vector3i = state.rescue.get("chest_cell", PathTargeter.NO_CELL) as Vector3i
	if chest == PathTargeter.NO_CELL:
		return false
	var room: Dictionary = DungeonLocks.room_of(state.battlefield, obs)
	if room.is_empty() or int(room.get("floor", 0)) != chest.z:
		return false
	return (room.get("rect", Rect2i()) as Rect2i).has_point(Vector2i(chest.x, chest.y))
