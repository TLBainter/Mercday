class_name InteractionSystem

const RESULT_OPEN_CLOSE := "Open/Close"
const RESULT_LOOT := "Loot"


static func obstacle_name(obs: Dictionary) -> String:
	var data: ObstacleData = obs.get("data") as ObstacleData
	if data == null or data.obstacle_name == "":
		return "object"
	return data.obstacle_name


static func result_of(obs: Dictionary) -> String:
	var data: ObstacleData = obs.get("data") as ObstacleData
	if data == null or not data.interactable:
		return ""
	return data.interaction_result


#Runs the obstacle's own interaction result. Returns false when it has none.
static func interact(merc: MercenaryData, obs: Dictionary, state: BattleState, lines: Array[String]) -> bool:
	var oname := obstacle_name(obs)
	var result := result_of(obs)
	if result == RESULT_LOOT:
		return _loot(merc, obs, state, lines)
	if result != RESULT_OPEN_CLOSE:
		lines.append("  %s cannot interact with %s." % [BattleState.colored_name(merc, state), oname])
		return false
	if DungeonLocks.is_locked(obs):
		if DungeonLocks.can_pick(merc, state):
			return DungeonLocks.attempt_pick(merc, obs, state, lines)
		if DungeonLocks.holds_keys(merc, state) and DungeonLocks.is_keyed(obs) and not DungeonLocks.keep_shut(obs):
			return DungeonLocks.key_open(merc, obs, state, lines)
		lines.append("  %s finds the %s locked (lock %d)." % [BattleState.colored_name(merc, state),
			"iron bars" if DungeonLocks.has_bars(obs) else oname, DungeonLocks.lock_difficulty(obs)])
		return false
	var now_open := OpenCloseState.toggle(obs)
	lines.append("  %s %s the %s." % [BattleState.colored_name(merc, state), "opens" if now_open else "closes", oname])
	state.on_door_changed()
	if now_open and RescueSystem.is_gate(state, obs):
		RescueSystem.on_gate_opened(state, lines)
	return true


#Hands the merc one entry out of a loot container.
static func _loot(merc: MercenaryData, obs: Dictionary, state: BattleState, lines: Array[String]) -> bool:
	var index := ChestLoot.pick_index(merc, obs)
	if index < 0:
		_log_empty(merc, obs, state, lines)
		return false
	var entry := ChestLoot.take(obs, index)
	if entry.is_empty():
		return false
	ChestLoot.give(merc, entry, state, lines)
	RescueSystem.on_gear_taken(merc, state, lines)
	return true


static func _log_empty(merc: MercenaryData, obs: Dictionary, state: BattleState, lines: Array[String]) -> void:
	lines.append("  %s finds the %s empty." % [BattleState.colored_name(merc, state), obstacle_name(obs)])


#Charges the Interact AP, runs the obstacle's interaction and logs it. `suffix` marks
#an Interact taken inside another action.
static func perform(merc: MercenaryData, obs: Dictionary, cell: Vector3i, state: BattleState,
		lines: Array[String], suffix: String = "") -> bool:
	if obs.is_empty():
		return false
	var looting := result_of(obs) == RESULT_LOOT
	#Reaching into an empty container costs nothing.
	if looting and ChestLoot.is_empty(obs):
		_log_empty(merc, obs, state, lines)
		return false
	var cost := state.get_cost(merc, "Interact", 2)
	state.spend_ap(merc, cost)
	state.record_action(merc, "Interact")
	var was_locked := DungeonLocks.is_locked(obs)
	var ok := interact(merc, obs, state, lines)
	state.pending_interact.erase(merc)
	if EncounterLogger.is_active():
		var verb := "loots" if looting else ("opens" if OpenCloseState.is_open(obs) else "closes")
		if was_locked:
			verb = "fails to open" if DungeonLocks.is_locked(obs) else "unlocks"
		EncounterLogger.log_verbose("INTERACT: %s %s %s at (%d,%d) [%dAP]%s" % [
			merc.merc_name, verb, obstacle_name(obs), cell.x, cell.y, cost, suffix])
	return ok
