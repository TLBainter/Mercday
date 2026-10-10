class_name FleeMover

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
const _SLOT_CAP := 8
const _BANK_CAP := 20


static func run_turn(merc: MercenaryData, state: BattleState, lines: Array[String], enhancements: int) -> void:
	var turn: Dictionary = AutoBattle.new_turn(merc, state)
	var ctx := {"enhancements": enhancements}
	var field := state.battlefield
	if field != null and field.is_cavern:
		_cavern_posture(merc, state, lines, ctx)
		if _climb_out(merc, state, lines, turn):
			return
	elif ConstStates.has_state(merc, ConstStates.DEPOSED) and state.can_afford(merc, state.get_cost(merc, "get_up", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "get_up"}, merc, state, ctx))
	var locked := StateEffects.is_blocked(merc, "action:move") or PaceBudget.pace_per_move(merc) <= 0
	if locked and _can_break_free(merc) and state.can_afford(merc, state.get_cost(merc, "break_free", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "break_free"}, merc, state, ctx))
		locked = StateEffects.is_blocked(merc, "action:move") or PaceBudget.pace_per_move(merc) <= 0
	if locked:
		return
	#A runner caught on a wall finishes that climb before it looks for anywhere else to go.
	if not state.is_sunk(merc) and _continue_climb(merc, state, lines, turn):
		return
	var banked := false
	var withdrew := false
	for _slot: int in range(_SLOT_CAP):
		if not BattleState._is_alive(merc):
			break
		lines.append_array(BattleStateUpdater.update_auto_states(merc, state))
		if FleeGoal.on_edge(merc, state):
			bank(merc, state, lines)
			banked = true
			break
		var foes := state.get_enemies(merc)
		if foes.is_empty():
			break
		var nearest := MovementDecider.closest_enemy(merc, foes, state)
		if not withdrew and not merc.advantage_immune and FleeGoal.in_danger(merc, state) \
				and state.can_afford(merc, state.get_cost(merc, "withdraw", 2)):
			withdrew = true
			lines.append_array(SpecialActionSystem.execute({"action_name": "withdraw", "target": nearest},
					merc, state, ctx))
			continue
		if not state.can_afford(merc, state.move_cost(merc, "Move Far", _CONFIG.move_base_ap)):
			break
		var before := state.pos3(merc)
		lines.append_array(MovementExecutor.run_move_arm(merc, {"type": "move", "action_name": "Move Far",
				"target": nearest, "goal_cell": FleeGoal.escape_goal(merc, state), "moves_allowed": 2, "reserve_ap": 0},
				state, enhancements, turn))
		if not BattleState._is_alive(merc):
			break
		if state.pos3(merc) == before and not _handover(merc, state, lines, turn, nearest, enhancements):
			break
	if not banked and BattleState._is_alive(merc) and FleeGoal.on_edge(merc, state):
		bank(merc, state, lines)


#Runs a climb already under way to its end; true when the turn is over, false once the climb is done.
static func _continue_climb(merc: MercenaryData, state: BattleState, lines: Array[String],
		turn: Dictionary) -> bool:
	if not ConstStates.has_state(merc, ConstStates.CLIMBING):
		return false
	for _step: int in range(_SLOT_CAP):
		if not BattleState._is_alive(merc):
			return true
		if not ConstStates.has_state(merc, ConstStates.CLIMBING):
			return false
		var cd := state.get_climbing_data(merc)
		if int(cd.get("current_h", 0)) >= int(cd.get("target_h", 0)):
			return true
		if not ClimbExecutor.can_fund_climb(merc, state, "Climb", ClimbExecutor.climb_pace_cost(merc)):
			return true
		var out := MovementExecutor.run_climb_arm(merc,
			{"type": "climb", "action_name": "Climb", "climb_continuing": true}, state, turn)
		if out.is_empty():
			return true
		lines.append_array(out)
	return true


#The climb or leap a blocked walk left this runner at the foot of; true when the turn goes on.
static func _handover(merc: MercenaryData, state: BattleState, lines: Array[String], turn: Dictionary,
		nearest: MercenaryData, enhancements: int) -> bool:
	var foot := state.pos3(merc)
	if MovementExecutor.climb_route_ready(merc, state):
		var found := ClimbAction.find_target(merc, state)
		if found.is_empty():
			return false
		var down: bool = bool(found.get("down", false))
		var decision: Dictionary = {"type": "climb", "action_name": "Initiate Climb",
			"climb_target_pos": found["pos"] as Vector2i}
		var link: Dictionary = found.get("link", {}) as Dictionary
		if not link.is_empty():
			decision["climb_link"] = link
			decision["climb_down"] = down
		var out := MovementExecutor.run_climb_arm(merc, decision, state, turn)
		if out.is_empty():
			return false
		lines.append_array(out)
		turn.erase("climb_foot_seen")
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FLEE CLIMB: %s foot=(%d,%d,%d) dir=%s" % [
				merc.merc_name, foot.x, foot.y, foot.z, "down" if down else "up"])
		return not _continue_climb(merc, state, lines, turn)
	if JumpExecutor.route_ready(merc, state):
		var land := JumpAction.routed_landing_for(merc, state)
		if land == JumpAction.NO_JUMP:
			return false
		var jumped := MovementExecutor.run_jump_arm(merc, {"type": "jump", "action_name": "Jump",
			"target": nearest, "jump_target_pos": Vector2i(land.x, land.y),
			"jump_target_floor": land.z, "jump_why": "roof"}, state, enhancements, turn)
		if jumped.is_empty():
			return false
		lines.append_array(jumped)
		turn.erase("climb_foot_seen")
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FLEE LEAP: %s to=(%d,%d,%d)" % [
				merc.merc_name, land.x, land.y, land.z])
		return true
	return false


static func _can_break_free(merc: MercenaryData) -> bool:
	for key: Variant in merc.active_states.keys():
		if key is String and ConstStates.DATA.has(key) and ConstStates.has_removal(key as String, "action:break_free"):
			#Water and crawl hold the merc through the cavern itself; no action shakes them off.
			if CavernRules.is_cavern_sourced(merc, key as String):
				continue
			return true
	return false


#Standing, dropping to a crawl, or the plain GetUp, whichever the rock roof overhead allows.
static func _cavern_posture(merc: MercenaryData, state: BattleState, lines: Array[String], ctx: Dictionary) -> void:
	var field := state.battlefield
	var size := merc.unit_size()
	var room: bool = field.clearance(state.get_position(merc)) >= float(size)
	if merc.crawling:
		if room and _spend_pace(merc, state, 1):
			CavernRules.stand(merc, state, lines)
		return
	if not ConstStates.has_state(merc, ConstStates.DEPOSED):
		return
	if not room:
		CavernRules.start_crawl(merc, state, lines)
		return
	if state.can_afford(merc, state.get_cost(merc, "get_up", 2)):
		lines.append_array(SpecialActionSystem.execute({"action_name": "get_up"}, merc, state, ctx))


#Takes paces out of the pool, buying one Move first when the pool is short and the AP allows it.
static func _spend_pace(merc: MercenaryData, state: BattleState, paces: int) -> bool:
	var pool := state.get_pace_pool(merc)
	if pool < paces:
		if PaceBudget.pace_per_move(merc) <= 0:
			return false
		if not state.can_afford(merc, state.get_cost(merc, "Move Far", _CONFIG.move_base_ap)):
			return false
		PaceBudget.buy_move(merc, state, "Move Far")
		pool = state.get_pace_pool(merc)
		if pool < paces:
			return false
	state.set_pace_pool(merc, pool - paces)
	return true


#A merc on the bottom of a pool climbs out before it flees anywhere; true when it spent the turn on that.
static func _climb_out(merc: MercenaryData, state: BattleState, lines: Array[String], turn: Dictionary) -> bool:
	if not state.is_sunk(merc):
		return false
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		lines.append_array(MovementExecutor.run_climb_arm(merc,
			{"type": "climb", "action_name": "Climb", "climb_continuing": true}, state, turn))
		return true
	var target := ClimbAction.find_climb_target(merc, state)
	if target == Vector2i(-1, -1):
		return false
	lines.append_array(MovementExecutor.run_climb_arm(merc,
		{"type": "climb", "action_name": "Initiate Climb", "climb_target_pos": target}, state, turn))
	return true


#Buys Moves with the AP left and banks the pool as paces off the map; a captor needs fewer than a plain flee-er.
static func bank(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var buys := 0
	while buys < _BANK_CAP and PaceBudget.pace_per_move(merc) > 0 \
			and state.can_afford(merc, state.get_cost(merc, "Move Far", _CONFIG.move_base_ap)):
		PaceBudget.buy_move(merc, state, "Move Far")
		buys += 1
	var paces := state.get_pace_pool(merc)
	state.set_pace_pool(merc, 0)
	if paces <= 0:
		return
	var need: int = _CONFIG.kidnap_escape_paces if KidnapSystem.holds(merc, state) \
			else _CONFIG.flee_escape_paces
	merc.flee_escape_paces += paces
	lines.append("  FLEE TRACK: %s +%d paces (%d/%d)" % [merc.merc_name, paces, merc.flee_escape_paces,
			need])
	if merc.flee_escape_paces >= need:
		state.remove_from_field(merc, "fled", lines)
		if merc.off_field:
			KidnapSystem.on_escape(merc, state, lines)
