class_name MovementArms extends RefCounted


#True when a walk under this name buys nothing because a climb, a leap or a scored post owns the cell.
static func move_yields(merc: MercenaryData, state: BattleState, action_name: String) -> bool:
	if state == null:
		return false
	if not state.jump_routes.is_empty() and JumpExecutor.route_ready(merc, state):
		return true
	if not state.climb_routes.is_empty() and not state.climb_route(merc).is_empty():
		if ConstStates.has_state(merc, ConstStates.CLIMBING):
			return true
		return ClimbExecutor.climb_route_ready(merc, state)
	if action_name != "Move Close" or state.battlefield == null:
		return false
	if state.battlefield.roof_cells.is_empty():
		return false
	return ClimbExecutor.post_climb_ready(merc, state)


#Move arm of the turn slot loop: prices the walk, runs it and updates the turn flags.
static func run_move_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var _is_seeking: bool = decision.get("seeking", false)
	#What the decision priced this walk with: the Moves it may buy and the AP it must leave.
	state.move_plan[merc] = {
		"moves_allowed": maxi(1, int(decision.get("moves_allowed", 1))),
		"reserve_ap": maxi(0, int(decision.get("reserve_ap", 0))),
	}
	var _pool_before := state.get_pace_pool(merc)
	var move_lines := MovementExecutor.execute_move(merc, decision["action_name"], decision["target"], state,
		decision.get("flank_ally"), enhancements, decision.get("move_stop_dist", -1), _is_seeking,
		[], decision.get("goal_cell", PathTargeter.NO_CELL) as Vector3i)
	state.move_plan.erase(merc)
	if move_lines.is_empty():
		if _pool_before > 0:
			state.set_pace_pool(merc, 0)
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("POOL CLEARED: %s no step possible" % merc.merc_name)
		#The walk stopped on the foot of a planned climb or roof leap; that action takes the next slot once.
		if not turn.has("climb_foot_seen") \
				and (ClimbExecutor.climb_route_ready(merc, state) or JumpExecutor.route_ready(merc, state)):
			turn["climb_foot_seen"] = true
			return lines
		turn["movement_blocked"] = true
		state.record_action(merc, decision["action_name"])
		if _is_seeking:
			turn["seeking_failed"] = true
			var _bt: MercenaryData = decision.get("target")
			if _bt != null:
				(turn["blocked_targets"] as Dictionary)[_bt] = true
	else:
		_movement_succeeded(merc, turn, move_lines, lines)
		turn["current_target"] = decision["target"]
		if _pool_before > 0:
			var _pm_end := state.pos3(merc)
			if _pm_end == turn["pool_move_cell"]:
				state.set_pace_pool(merc, 0)
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("POOL CLEARED: %s no progress on the pool" % merc.merc_name)
			turn["pool_move_cell"] = _pm_end
		else:
			turn["pool_move_cell"] = state.pos3(merc)
	return lines


#Jump arm of the turn slot loop.
static func run_jump_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var jump_pos: Vector2i = decision.get("jump_target_pos", Vector2i(-1, -1))
	var jump_floor: int = int(decision.get("jump_target_floor", state.get_floor(merc)))
	var jump_why: String = str(decision.get("jump_why", ""))
	var jump_lines := JumpExecutor.execute_jump(
		merc, jump_pos, jump_floor, decision["action_name"], state, enhancements, jump_why)
	if jump_lines.is_empty():
		turn["movement_blocked"] = true
	else:
		_movement_succeeded(merc, turn, jump_lines, lines)
		turn["current_target"] = decision["target"]
	return lines


#Climb arm of the turn slot loop.
static func run_climb_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var climb_lines := ClimbExecutor.execute_climb(merc, decision, decision["action_name"], state)
	if climb_lines.is_empty():
		turn["movement_blocked"] = true
	else:
		_movement_succeeded(merc, turn, climb_lines, lines)
	return lines


#Walk toward the cell decision[key] names: a dropped weapon or an obstacle the merc means to break.
#note_pickup blacklists a refused weapon cell for the rest of the turn.
static func run_move_to_cell_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary, key: String, note_pickup: bool) -> Array[String]:
	var lines: Array[String] = []
	var mv_lines := MovementExecutor.execute_move_to_pos(merc, decision[key], state, enhancements)
	if mv_lines.is_empty():
		turn["movement_blocked"] = true
		if note_pickup:
			merc.active_states["blocked_pickup_pos"] = decision[key]
	else:
		lines.append_array(mv_lines)
		turn["movement_blocked"] = false
		turn["weapon_action_taken"] = true
	return lines


#Bookkeeping shared by the move, jump and climb arms once the movement produced lines.
static func _movement_succeeded(merc: MercenaryData, turn: Dictionary, moved_lines: Array[String],
		lines: Array[String]) -> void:
	lines.append_array(moved_lines)
	turn["movement_blocked"] = false
	merc.active_states.erase("_move_blocked_round")
	turn["has_moved"] = true
	(turn["blocked_targets"] as Dictionary).clear()
