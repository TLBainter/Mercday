class_name RescueDirector extends RefCounted

#Runs a rescue turn: the gate run, the escort, the withdrawal and every move it pays for.

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
const _MOVE_KINDS := ["move", "jump", "climb", "move_to_pickup", "move_to_obstacle"]


#Runs the director turn that takes_turn promised; false when the normal loop should run instead.
static func run_director(merc: MercenaryData, state: BattleState, lines: Array[String],
		enhancements: int, turn: Dictionary) -> bool:
	if RescueTactics.gate_run_due(merc, state):
		gate_run(merc, state, lines, enhancements, turn)
		return true
	if RescueTactics.escort_due(merc, state):
		escort_turn(merc, state, lines, enhancements, turn)
		return true
	var p: String = RescueTactics.posture_of(state, merc)
	if p == RescueTactics.POSTURE_WITHDRAW:
		withdraw_turn(merc, state, lines, enhancements, turn)
		return true
	if p == RescueTactics.POSTURE_HIDE:
		hide_turn(merc, state, lines, enhancements, turn)
		return true
	if p == RescueTactics.POSTURE_HOLD:
		hold_turn(merc, state, lines)
		return true
	return false


#The picker walks to the cell and works the lock until it opens or the attempts run dry.
static func gate_run(merc: MercenaryData, state: BattleState, lines: Array[String],
		enhancements: int, turn: Dictionary) -> void:
	var rescue: Dictionary = state.rescue
	rescue["gate_runs"] = int(rescue["gate_runs"]) + 1
	var target: Vector3i = RescueSystem.free_target_cell(state)
	if target == PathTargeter.NO_CELL:
		return
	if not RescueGrid.is_adjacent(state.pos3(merc), target):
		var goal: Vector3i = RescueGrid.approach_cell(merc, state)
		var moved: bool = goal != PathTargeter.NO_CELL \
			and travel(merc, state, goal, lines, enhancements, turn)
		if not RescueGrid.is_adjacent(state.pos3(merc), target):
			if not moved:
				lines.append("  %s finds no way to the cell." % BattleState.colored_name(merc, state))
			return
	for _slot: int in range(RescueTactics.SLOT_CAP):
		if bool(rescue["freed"]) or not RescueTactics.pick_first(merc, state):
			break
		if not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
			break
		if not RescueSystem.try_free(merc, state, lines):
			break


static func escort_turn(merc: MercenaryData, state: BattleState, lines: Array[String],
		enhancements: int, turn: Dictionary) -> void:
	var rescue: Dictionary = state.rescue
	rescue["escort_turns"] = int(rescue["escort_turns"]) + 1
	var lead: MercenaryData = RescueSystem.picker(state)
	if lead == null:
		return
	var goal: Vector3i = RescueGrid.adjacent_free_cell(state, state.pos3(lead), merc)
	travel(merc, state, goal, lines, enhancements, turn)


#Walks out and leaves the moment the exit cell is under foot.
static func withdraw_turn(merc: MercenaryData, state: BattleState, lines: Array[String],
		enhancements: int, turn: Dictionary) -> void:
	var rescue: Dictionary = state.rescue
	rescue["withdraw_turns"] = int(rescue["withdraw_turns"]) + 1
	var said: Dictionary = rescue["withdraw_said"] as Dictionary
	if not said.has(merc):
		said[merc] = true
		lines.append("  %s pulls back toward the exit." % BattleState.colored_name(merc, state))
	var exit_cell: Vector3i = rescue["exit_cell"] as Vector3i
	if exit_cell == PathTargeter.NO_CELL:
		return
	if state.pos3(merc) != exit_cell:
		travel(merc, state, exit_cell, lines, enhancements, turn)
	if state.pos3(merc) == exit_cell and not merc.off_field and RescueTactics.may_leave(merc, state):
		leave(merc, state, lines)


static func hold_turn(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	var captive: MercenaryData = rescue["captive"] as MercenaryData
	if merc == captive:
		rescue["shelter_turns"] = int(rescue.get("shelter_turns", 0)) + 1
		lines.append("  %s keeps out of sight." % BattleState.colored_name(merc, state))
		return
	lines.append("  %s waits for %s." % [BattleState.colored_name(merc, state),
		BattleState.colored_name(captive, state)])


#The captive walks to the cover its posture picked: an unseen cell, the prison cell or an ally's side.
static func hide_turn(merc: MercenaryData, state: BattleState, lines: Array[String],
		enhancements: int, turn: Dictionary) -> void:
	var rescue: Dictionary = state.rescue
	rescue["hide_turns"] = int(rescue.get("hide_turns", 0)) + 1
	var goal: Vector3i = rescue.get("hide_goal", PathTargeter.NO_CELL) as Vector3i
	lines.append("  %s slips out of sight." % BattleState.colored_name(merc, state))
	travel(merc, state, goal, lines, enhancements, turn)


#Director walk with the real mover: it opens doors in stride and draws advantage attacks.
static func travel(merc: MercenaryData, state: BattleState, goal: Vector3i, lines: Array[String],
		enhancements: int, turn: Dictionary) -> bool:
	if goal == PathTargeter.NO_CELL or state.pos3(merc) == goal:
		return false
	var ctx: Dictionary = {"enhancements": enhancements}
	if ConstStates.has_state(merc, ConstStates.DEPOSED) \
			and state.can_afford(merc, state.get_cost(merc, "get_up", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "get_up"}, merc, state, ctx))
	var locked: bool = StateEffects.is_blocked(merc, "action:move") or PaceBudget.pace_per_move(merc) <= 0
	if locked and FleeMover._can_break_free(merc) \
			and state.can_afford(merc, state.get_cost(merc, "break_free", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "break_free"}, merc, state, ctx))
		locked = StateEffects.is_blocked(merc, "action:move") or PaceBudget.pace_per_move(merc) <= 0
	if locked:
		return false
	var moved: bool = false
	var withdrew: bool = false
	for _slot: int in range(RescueTactics.SLOT_CAP):
		if not BattleState._is_alive(merc) or state.pos3(merc) == goal:
			break
		lines.append_array(BattleStateUpdater.update_auto_states(merc, state))
		var foes: Array[MercenaryData] = state.get_enemies(merc)
		if foes.is_empty():
			break
		var nearest: MercenaryData = MovementDecider.closest_enemy(merc, foes, state)
		if RescueTactics.withdraw_enabled and not withdrew and not merc.advantage_immune \
				and FleeGoal.in_danger(merc, state) \
				and state.can_afford(merc, state.get_cost(merc, "withdraw", 2)):
			withdrew = true
			moved = true
			lines.append_array(SpecialActionSystem.execute({"action_name": "withdraw", "target": nearest},
					merc, state, ctx))
			continue
		if not state.can_afford(merc, state.move_cost(merc, "Move Far", _CONFIG.move_base_ap)):
			break
		var before: Vector3i = state.pos3(merc)
		lines.append_array(MovementExecutor.run_move_arm(merc, {"type": "move", "action_name": "Move Far",
				"target": nearest, "goal_cell": goal, "moves_allowed": 2, "reserve_ap": 0},
				state, enhancements, turn))
		if state.pos3(merc) == before:
			if _open_pending(merc, state, lines):
				moved = true
				continue
			break
		moved = true
	return moved


#A director-led merc works the shut door its walk stopped at: opens it, turns its key or picks it.
static func _open_pending(merc: MercenaryData, state: BattleState, lines: Array[String]) -> bool:
	var cell: Vector3i = state.pending_interact.get(merc, PathTargeter.NO_CELL) as Vector3i
	if cell == PathTargeter.NO_CELL or state.battlefield == null:
		return false
	if not RescueGrid.is_adjacent(state.pos3(merc), cell) or not PathCost.is_shut_door(state.battlefield, cell):
		state.pending_interact.erase(merc)
		return false
	var obs: Dictionary = state.battlefield.get_obs(Vector2i(cell.x, cell.y), cell.z)
	if obs.is_empty() or not DungeonLocks.can_open(merc, obs, state):
		state.pending_interact.erase(merc)
		return false
	if not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
		return false
	InteractionSystem.perform(merc, obs, cell, state, lines)
	state.rescue["door_opens"] = int(state.rescue.get("door_opens", 0)) + 1
	return true


static func leave(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var rescue: Dictionary = state.rescue
	state.remove_from_field(merc, "exit", lines)
	if merc != (rescue["captive"] as MercenaryData):
		rescue["party_exits"] = int(rescue["party_exits"]) + 1
		return
	rescue["captive_exited"] = true
	rescue["exit_round"] = state.round_number
	if RescueTactics.fighting(state):
		lines.append("  %s is out of the dungeon." % BattleState.colored_name(merc, state))


#Bends a fall-back merc's chosen action toward the exit; other decisions pass straight through.
static func redirect(merc: MercenaryData, decision: Dictionary, state: BattleState, turn: Dictionary,
		lines: Array[String]) -> Dictionary:
	var exit_cell: Vector3i = state.rescue["exit_cell"] as Vector3i
	if exit_cell == PathTargeter.NO_CELL:
		return decision
	if state.pos3(merc) == exit_cell and RescueTactics.may_leave(merc, state):
		leave(merc, state, lines)
		return {"type": "rescue_left"}
	if not turn.has("rescue_opened"):
		turn["rescue_opened"] = true
		state.rescue["fall_back_turns"] = int(state.rescue["fall_back_turns"]) + 1
		var opener: Dictionary = _exit_move(merc, state, turn, exit_cell)
		return opener if not opener.is_empty() else decision
	if not _MOVE_KINDS.has(str(decision.get("type", ""))):
		return decision
	if not _exposed(merc, state):
		var step: Dictionary = _exit_move(merc, state, turn, exit_cell)
		return step if not step.is_empty() else decision
	var foes: Array[MercenaryData] = state.get_enemies(merc)
	if not foes.is_empty() and not merc.advantage_immune \
			and state.can_afford(merc, state.get_cost(merc, "withdraw", 2)):
		return {"type": "special", "action_name": "withdraw",
			"target": MovementDecider.closest_enemy(merc, foes, state)}
	turn["movement_blocked"] = true
	if turn.has("rescue_retried"):
		return {"type": "rescue_done"}
	turn["rescue_retried"] = true
	return {"type": "rescue_retry"}


#One Move Far aimed at the exit, or empty when this merc cannot usefully take one now.
static func _exit_move(merc: MercenaryData, state: BattleState, turn: Dictionary,
		exit_cell: Vector3i) -> Dictionary:
	if bool(turn.get("movement_blocked", false)) or _exposed(merc, state):
		return {}
	if not state.can_afford(merc, state.move_cost(merc, "Move Far", _CONFIG.move_base_ap)):
		return {}
	var steps: int = RescueTactics.exit_steps(state, state.pos3(merc))
	if steps <= 0:
		return {}
	var goal: Vector3i = exit_cell
	if not _leaves_on_arrival(merc, state):
		if steps <= 1:
			return {}
		goal = RescueGrid.adjacent_free_cell(state, exit_cell, merc)
		if goal == PathTargeter.NO_CELL:
			return {}
	var foes: Array[MercenaryData] = state.get_enemies(merc)
	if foes.is_empty():
		return {}
	return {"type": "move", "action_name": "Move Far",
		"target": MovementDecider.closest_enemy(merc, foes, state),
		"goal_cell": goal, "moves_allowed": 1, "reserve_ap": 0}


#Stepping away draws an Advantage Attack unless this turn's Withdraw already covers the merc.
static func _exposed(merc: MercenaryData, state: BattleState) -> bool:
	return not merc.advantage_immune and FleeGoal.in_danger(merc, state)


#A fall-back merc that may not leave yet stops beside the exit cell so the captive can still use it.
static func _leaves_on_arrival(merc: MercenaryData, state: BattleState) -> bool:
	var rescue: Dictionary = state.rescue
	if merc == (rescue["captive"] as MercenaryData):
		return true
	return RescueTactics.phase(state) == RescueTactics.PHASE_DONE or bool(rescue["abandoned"])
