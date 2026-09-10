class_name InteractionSystem

const RESULT_OPEN_CLOSE := "Open/Close"


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
	if result_of(obs) != RESULT_OPEN_CLOSE:
		lines.append("  %s cannot interact with %s." % [BattleState.colored_name(merc, state), oname])
		return false
	var now_open := OpenCloseState.toggle(obs)
	lines.append("  %s %s the %s." % [BattleState.colored_name(merc, state), "opens" if now_open else "closes", oname])
	#Passability and opacity both changed, so every cached route and sight line is stale.
	if state.battlefield != null:
		state.battlefield.los_version += 1
		state.battlefield.bump_path_version()
	state.los_cache.clear()
	MovementExecutor.clear_caches()
	return true


#Charges the Interact AP, runs the obstacle's interaction and logs it. `suffix` marks
#an Interact taken inside another action.
static func perform(merc: MercenaryData, obs: Dictionary, cell: Vector3i, state: BattleState,
		lines: Array[String], suffix: String = "") -> bool:
	if obs.is_empty():
		return false
	var cost := state.get_cost(merc, "Interact", 2)
	state.spend_ap(merc, cost)
	state.record_action(merc, "Interact")
	var ok := interact(merc, obs, state, lines)
	state.pending_interact.erase(merc)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("INTERACT: %s %s %s at (%d,%d) [%dAP]%s" % [
			merc.merc_name, "opens" if OpenCloseState.is_open(obs) else "closes",
			obstacle_name(obs), cell.x, cell.y, cost, suffix])
	return ok
