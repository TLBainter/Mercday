class_name MovementExecutor

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

static var _turn_path_cache: Dictionary = {}
static var _blocked_path_goals: Dictionary = {}


static func clear_caches() -> void:
	_turn_path_cache.clear()
	_blocked_path_goals.clear()
	PathTargeter.clear_caches()


#The route this merc is following this turn, from the cell it now stands on onward.
static func turn_path(merc: MercenaryData) -> Array[Vector3i]:
	var entry: Variant = _turn_path_cache.get(merc)
	if entry == null:
		return [] as Array[Vector3i]
	var full: Array[Vector3i] = (entry as Dictionary).get("path", []) as Array[Vector3i]
	var idx: int = (entry as Dictionary).get("idx", 0)
	var rest: Array[Vector3i] = []
	for i: int in range(idx, full.size()):
		rest.append(full[i])
	return rest


#Why the raw goal from the targeter had to be shifted, for the MOVE GOAL ADJUST line.
static func _goal_adjust_reason(
		raw: Vector3i,
		field: BattlefieldArea,
		state: BattleState,
		merc: MercenaryData,
		reach: Dictionary,
		blocked: bool) -> String:
	if blocked:
		return "blocked"
	if state.is_position_occupied(Vector2i(raw.x, raw.y), merc, raw.z):
		return "occupied"
	if not PathHelper.is_standable(raw, field, int(merc.stats.get("size", 1))):
		return "obstacle"
	if not reach.has(raw):
		return "unreachable"
	return "unreachable"


#Why no exact path to the goal existed, for the MOVE PARTIAL line.
static func _partial_reason(goal: Vector3i, reach: Dictionary) -> String:
	if not reach.has(goal):
		return "goal_unreachable"
	if (reach[goal] as int) >= PathTargeter.JUMP_COST_OFFSET:
		return "jump_only"
	return "path_blocked"


#Paces one Move action banks for this mover.
static func pace_per_move(merc: MercenaryData) -> int:
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var cap := ConstStates.max_paces(merc)
	if cap == 0:
		return 0
	if cap > 0:
		pace = mini(pace, cap)
	return pace


#Paces the mover can still walk this turn: the pool plus every Move it can buy while keeping reserve_ap.
static func turn_paces(merc: MercenaryData, state: BattleState, reserve_ap: int = 0, max_moves: int = 2) -> Dictionary:
	var pool := state.get_pace_pool(merc)
	var ap := merc.current_ap + merc.excess_ap
	var moves := 0
	var spent := 0
	while moves < max_moves:
		var cost := state.get_cost_after(merc, "Move Close", _CONFIG.move_base_ap, moves)
		if ap - spent - cost < reserve_ap:
			break
		spent += cost
		moves += 1
	return {"paces": pool + moves * pace_per_move(merc), "moves": moves, "ap": spent, "pool": pool}


#Buys one Move action: charges its AP, escalates it and banks its paces.
static func _buy_move(merc: MercenaryData, state: BattleState, action_name: String) -> int:
	var cost := state.get_cost(merc, action_name, _CONFIG.move_base_ap)
	state.spend_ap(merc, cost)
	state.record_action(merc, action_name)
	var paces := pace_per_move(merc)
	state.set_pace_pool(merc, state.get_pace_pool(merc) + paces)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE BUY: %s %s [%dAP] pool=%d" % [
			merc.merc_name, action_name, cost, state.get_pace_pool(merc)])
	return paces


#Moves the plan must buy so `budget` can pay `cost`; -1 with buy["why"] when it cannot afford them.
static func _fund_need(merc: MercenaryData, state: BattleState, buy: Dictionary, budget: int, cost: int) -> int:
	if budget >= cost:
		return 0
	var pp := pace_per_move(merc)
	var need := int(ceil(float(cost - budget) / float(maxi(1, pp))))
	if need > int(buy["left"]):
		buy["why"] = "moves_spent"
		return -1
	var bought := int(buy["bought"])
	var action_name: String = str(buy["action_name"])
	var total := 0
	#Moves a real walk bought are already recorded; a dry run prices past the ones it simulated.
	var ahead: int = bought if bool(buy.get("dry", false)) else 0
	for k: int in range(need):
		total += state.get_cost_after(merc, action_name, _CONFIG.move_base_ap, ahead + k)
	#A dry run books the AP of the Moves it already simulated in buy["sim_ap"].
	var ap := merc.current_ap + merc.excess_ap - int(buy.get("sim_ap", 0))
	#The first Move of an empty-pool walk was priced by the decision; every later one keeps the reserve.
	var keeps_reserve := bought > 0 or int(buy.get("pool_start", 0)) > 0
	var reserve: int = int(buy["reserve"]) if keeps_reserve else 0
	#AP the shut doors within this purchase's reach need for their Interact; every Move keeps it.
	var door_reserve: int = int(buy.get("door_reserve", 0))
	if ap < total:
		buy["why"] = "ap_short"
		return -1
	if ap - total < reserve + door_reserve:
		buy["why"] = "door_reserve" if (door_reserve > 0 and ap - total >= reserve) else "reserve"
		return -1
	buy["need_ap"] = total
	return need


#Raises `budget` until it can pay `cost`, buying Moves the plan still allows. -1 when it cannot.
static func _fund_step(merc: MercenaryData, state: BattleState, buy: Dictionary, budget: int, cost: int) -> int:
	var need := _fund_need(merc, state, buy, budget, cost)
	if need < 0:
		return -1
	for k: int in range(need):
		budget += _buy_move(merc, state, str(buy["action_name"]))
		buy["bought"] = int(buy["bought"]) + 1
		buy["left"] = int(buy["left"]) - 1
	return budget


#Paces the walk holds once it buys the Moves that let `budget` pay `cost`.
static func _purchase_reach(merc: MercenaryData, budget: int, cost: int) -> int:
	var pp := maxi(1, pace_per_move(merc))
	return budget + int(ceil(float(cost - budget) / float(pp))) * pp


#Diagnostic: the first three steps a refused Move faced, with their pace cost and endability.
static func _refused_steps(merc: MercenaryData, state: BattleState, field: BattlefieldArea, path: Array[Vector3i],
		path_start_idx: int, cur_alt: int, ally_passable: Dictionary, fall_tolerance: float, flying: bool,
		can_climb: bool, merc_size: int) -> String:
	var parts: Array[String] = []
	var alt := cur_alt
	for i: int in range(path_start_idx + 1, mini(path.size(), path_start_idx + 4)):
		var from_cell: Vector3i = path[i - 1]
		var cell: Vector3i = path[i]
		var cost := PathCost.cell_pace_cost(from_cell, cell, field, ally_passable, fall_tolerance, flying, can_climb,
			merc_size, alt)
		if flying:
			alt = PathCost.fly_arrival_altitude(from_cell, cell, field, alt)
		var end := "n"
		if PathCost.is_shut_door(field, cell):
			end = "door"
		elif state.is_position_occupied(Vector2i(cell.x, cell.y), merc, cell.z):
			end = "occ"
		elif _can_end_on(cell, field, merc_size, flying):
			end = "y"
		parts.append("(%d,%d,%d) cost=%d end=%s" % [cell.x, cell.y, cell.z, cost, end])
	return "; ".join(parts)


#AP the shut doors within `paces` of path[idx] and before the goal need for their Interact.
static func _door_reserve_ahead(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		path: Array[Vector3i], idx: int, goal: Vector3i, paces: int) -> int:
	if field == null:
		return 0
	var doors := 0
	for j: int in range(idx, path.size()):
		if path[j] == goal or j - idx > paces:
			break
		if PathCost.is_shut_door(field, path[j]):
			doors += 1
	if doors <= 0:
		return 0
	return doors * state.get_cost(merc, "Interact", 2)


#Diagnostic: the floor changes and obstacle cells along a planned path.
static func _route_summary(path: Array[Vector3i], field: BattlefieldArea) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(path.size()):
		var c: Vector3i = path[i]
		var obs: Dictionary = field.get_obs(Vector2i(c.x, c.y), c.z)
		var tag := ""
		if i > 0 and path[i - 1].z != c.z:
			tag = "well" if PathCost.is_well_link(path[i - 1], c, field) else "F"
		elif not obs.is_empty():
			tag = str(obs.get("cell_type", "obs"))
		if tag != "":
			parts.append("(%d,%d,%d)%s" % [c.x, c.y, c.z, tag])
	return " ".join(parts)


#Refunds the pace paid for cells past kept, trims the walk records and marks the dropped cells.
static func _trim_to(kept: int, traversed: Array, cost_at: Array, harm_at: Array, body_at: Array,
		path_harms: Array, body_traverse_lines: Array, rejected: Dictionary) -> int:
	if kept < 0 or kept >= traversed.size() - 1:
		return 0
	var refunded := 0
	for pk: int in range(kept + 1, traversed.size()):
		refunded += int(cost_at[pk])
		rejected[traversed[pk]] = true
	cost_at.resize(kept + 1)
	traversed.resize(kept + 1)
	for h: int in range(harm_at.size() - 1, -1, -1):
		if int(harm_at[h]) > kept:
			path_harms.remove_at(h)
			harm_at.remove_at(h)
	for b: int in range(body_at.size() - 1, -1, -1):
		if int(body_at[b]) > kept:
			body_traverse_lines.remove_at(b)
			body_at.remove_at(b)
	return refunded


#Paces a flyer needs to cross the flyover band it enters at path[idx] and land on the first
#standable free cell beyond it, altitude running along the way. -1 when no such cell exists.
static func fly_band_paces(path: Array[Vector3i], idx: int, entry_cost: int,
		field: BattlefieldArea, passable: Dictionary, fall_tolerance: float,
		can_climb: bool, merc_size: int, altitude: int, is_free: Callable) -> int:
	var need := entry_cost
	var prev: Vector3i = path[idx]
	var alt := PathCost.fly_arrival_altitude(path[idx - 1], path[idx], field, altitude)
	for j: int in range(idx + 1, path.size()):
		var step := PathCost.cell_pace_cost(prev, path[j], field, passable, fall_tolerance, true, can_climb, merc_size, alt)
		if step < 0:
			return -1
		need += step
		alt = PathCost.fly_arrival_altitude(prev, path[j], field, alt)
		prev = path[j]
		if PathHelper.is_standable(path[j], field, merc_size) and (is_free.call(path[j]) as bool):
			return need
	return -1


#A walker ends a move on a standable cell; a flyer may also hover over a flyover cell.
static func _can_end_on(cell: Vector3i, field: BattlefieldArea, merc_size: int, flying: bool) -> bool:
	if PathHelper.is_standable(cell, field, merc_size):
		return true
	return flying and PathCost.is_flyover_cell(cell, field)


static func _get_dead_body_at(pos: Vector3i, state: BattleState) -> MercenaryData:
	for m: MercenaryData in state.positions.keys():
		if m.is_dead and state.pos3(m) == pos:
			return m
	return null


static func _get_deposed_merc_at(pos: Vector3i, state: BattleState) -> MercenaryData:
	for m: MercenaryData in state.positions.keys():
		if BattleState._is_alive(m) and ConstStates.has_state(m, ConstStates.DEPOSED) and state.pos3(m) == pos:
			return m
	return null


static func _get_standing_ally_at(pos: Vector3i, merc: MercenaryData, state: BattleState) -> MercenaryData:
	for ally: MercenaryData in state.get_allies(merc):
		if BattleState._is_alive(ally) \
				and not ConstStates.has_state(ally, ConstStates.DEPOSED) \
				and state.pos3(ally) == pos:
			return ally
	return null


static func compute_move_position(
		merc: MercenaryData,
		move_target: MercenaryData,
		action_name: String,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1,
		valid_targets: Array[MercenaryData] = [],
		enemies: Array[MercenaryData] = []) -> Vector3i:
	if action_name == "Move Far":
		return PathTargeter.best_retreat_cell(merc, enemies, state, move_target, valid_targets)
	return PathTargeter.best_approach_cell(merc, move_target, state, flank_ally, stop_dist_override, valid_targets, enemies)


#Opens a shut door standing on the path so the walk can carry on through it. The Interact
#costs its own AP and its narration rides with the cell the mover opened it from.
static func _open_door_in_stride(
		merc: MercenaryData,
		state: BattleState,
		field: BattlefieldArea,
		cell: Vector3i,
		traversed: Array[Vector3i],
		body_at: Array[int],
		body_traverse_lines: Array[String]) -> bool:
	var obs: Dictionary = field.get_obs(Vector2i(cell.x, cell.y), cell.z)
	if obs.is_empty() or not PathCost.is_interactable_door(obs):
		return false
	if not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
		return false
	var door_lines: Array[String] = []
	if not InteractionSystem.perform(merc, obs, cell, state, door_lines, " during move"):
		return false
	for dl: String in door_lines:
		body_traverse_lines.append(dl)
		body_at.append(traversed.size() - 1)
	return true


#Pace the mover would spend walking `path` whole, with the same surcharges the walk charges.
#-1 when a cell on it cannot be entered at all.
static func _path_pace_cost(
		state: BattleState,
		field: BattlefieldArea,
		path: Array[Vector3i],
		ally_passable: Dictionary,
		fall_tolerance: float,
		flying: bool,
		can_climb: bool,
		merc_size: int,
		start_alt: int) -> int:
	var total := 0
	var alt := start_alt
	for i: int in range(1, path.size()):
		var c := PathCost.cell_pace_cost(path[i - 1], path[i], field, ally_passable, fall_tolerance, flying, can_climb, merc_size, alt)
		if c < 0:
			return -1
		var db := _get_dead_body_at(path[i - 1], state)
		if db != null and int(db.stats.get("size", 1)) >= merc_size:
			c += 1
		var dp := _get_deposed_merc_at(path[i - 1], state)
		if dp != null and int(dp.stats.get("size", 1)) >= merc_size:
			c += 1
		total += c
		if flying:
			alt = PathCost.fly_arrival_altitude(path[i - 1], path[i], field, alt)
	return total


#The single re-plan a Move may take: a fresh route from `from_cell` that avoids `blocked`.
#`require_goal` refuses the route unless it reaches the goal on the pace left.
static func _replan_move(
		merc: MercenaryData,
		state: BattleState,
		field: BattlefieldArea,
		reason: String,
		from_cell: Vector3i,
		blocked: Dictionary,
		budget: int,
		start_alt: int,
		goal: Vector3i,
		ally_passable: Dictionary,
		fall_tolerance: float,
		flying: bool,
		can_climb: bool,
		merc_size: int,
		known_enemies: Dictionary,
		require_goal: bool,
		rejected: Dictionary,
		traversed: Array[Vector3i],
		cost_at: Array[int],
		harm_at: Array[int],
		body_at: Array[int],
		path_harms: Array[Dictionary],
		body_traverse_lines: Array[String],
		buy: Dictionary) -> Dictionary:
	var res: Dictionary = {
		"ran": false,
		"budget": budget,
		"end": from_cell,
		"pushed": 0,
		"drop_taken": {},
		"drop_cell": PathTargeter.NO_CELL,
		"floor_change": PathTargeter.NO_CELL,
	}
	if budget <= 0 or from_cell == goal:
		return res
	var rp_path := Pathfinder.find_path(from_cell, goal, field, ally_passable, fall_tolerance,
		flying, can_climb, merc_size, start_alt, blocked)
	for rj: int in range(1, rp_path.size()):
		if blocked.has(rp_path[rj]):
			rp_path.resize(rj)
			break
	if rp_path.size() <= 1:
		return res
	if require_goal:
		if rp_path[rp_path.size() - 1] != goal:
			return res
		var need := _path_pace_cost(state, field, rp_path, ally_passable, fall_tolerance,
			flying, can_climb, merc_size, start_alt)
		if need < 0 or need > budget:
			return res
	#The pace left must reach a cell beyond this walk's trail, or the re-plan is left untaken.
	var rp_reach := from_cell
	var rp_prefix: Array[Vector3i] = [rp_path[0]]
	for rk: int in range(1, rp_path.size()):
		rp_prefix.append(rp_path[rk])
		var rp_need := _path_pace_cost(state, field, rp_prefix, ally_passable, fall_tolerance,
			flying, can_climb, merc_size, start_alt)
		if rp_need < 0 or rp_need > budget:
			break
		rp_reach = rp_path[rk]
	if traversed.has(rp_reach):
		return res
	var rp_kept := traversed.size() - 1
	var rp_lines := body_traverse_lines.size()
	var rp_walk := _walk_path(merc, state, field, rp_path, 0, budget, from_cell, start_alt,
		goal, ally_passable, fall_tolerance, flying, can_climb, merc_size, known_enemies,
		PathTargeter.is_flanked_by_known(from_cell, known_enemies), traversed, cost_at,
		harm_at, body_at, path_harms, body_traverse_lines, buy)
	var rp_budget := rp_walk["budget"] as int
	var rp_drop := rp_walk["drop_taken"] as Dictionary
	var rp_drop_cell := rp_walk["drop_cell"] as Vector3i
	#The first walk already narrated leaving the cell the re-plan starts on.
	for dl: int in range(body_traverse_lines.size() - 1, rp_lines - 1, -1):
		if body_at[dl] == rp_kept:
			body_traverse_lines.remove_at(dl)
			body_at.remove_at(dl)
	var rp_end := from_cell
	for k2: int in range(traversed.size() - 1, rp_kept, -1):
		var t2: Vector3i = traversed[k2]
		if state.is_position_occupied(Vector2i(t2.x, t2.y), merc, t2.z):
			continue
		if not _can_end_on(t2, field, merc_size, flying):
			continue
		rp_end = t2
		break
	var end_idx := traversed.find(rp_end)
	var pushed := _trim_to(end_idx, traversed, cost_at, harm_at, body_at, path_harms,
		body_traverse_lines, rejected)
	rp_budget += pushed
	if not rp_drop.is_empty() and rp_end != rp_drop_cell:
		rp_drop = {}
	res["ran"] = true
	res["budget"] = rp_budget
	res["end"] = rp_end
	res["pushed"] = pushed
	res["drop_taken"] = rp_drop
	res["drop_cell"] = rp_drop_cell
	res["floor_change"] = rp_walk["floor_change"] as Vector3i
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE REPLAN: %s from (%d,%d) budget=%d reason=%s -> (%d,%d)" % [
			merc.merc_name, from_cell.x, from_cell.y, budget, reason, rp_end.x, rp_end.y])
	return res


#Walks one planned path, charging pace per cell and collecting harms, narration and any
#drop taken. Shared by the first walk and by the re-plan that follows a push-back.
#Advantage Attacks the movers leaving melee range trigger, with their narration lines.
static func _advantage_attacks(merc: MercenaryData, state: BattleState, from2d: Vector2i,
		to2d: Vector2i, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, from2d, to2d, state)
	for entry: Dictionary in triggered:
		var reactor: MercenaryData = entry["reactor"]
		var def: ActionData = entry["reaction"]
		var react_ep := CombatApplicator.state_ep_cost(reactor, def.ep_cost, "reaction")
		if react_ep < 0 or ExcessPool.available_ep(reactor) < react_ep:
			continue
		var react_paid := ExcessPool.pay_ep(reactor, react_ep)
		state.last_attacked[reactor] = merc
		if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
			state.record_ranged_targeted(merc)
		var atk_flaws := AttackSystem.compute_attack_flaws(reactor, merc, state)
		var weapon_enh := AttackSystem.get_weapon_enhance_bonus(reactor)
		var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, merc)
		lines.append("  %s takes an Advantage Attack against %s!" % [BattleState.colored_name(reactor, state), BattleState.colored_name(merc, state)])
		if atk.get("misfired", false):
			lines.append("  %s misfires!" % BattleState.colored_name(reactor, state))
		elif atk.get("no_ammo", false):
			lines.append("  %s has no ammo!" % BattleState.colored_name(reactor, state))
			ExcessPool.refund_ep(reactor, int(react_paid["from_excess"]), int(react_paid["from_ep"]))
		elif atk["damage"] > 0:
			lines.append_array(CombatApplicator.apply_hit(reactor, merc, atk, atk["damage"], atk["damage_type"], state, enhancements))
		else:
			lines.append("  %s misses %s with the Advantage Attack." % [BattleState.colored_name(reactor, state), BattleState.colored_name(merc, state)])
	return lines


#Price of the step onto path[i] plus what it passes over: {"cost", "door", "body", "deposed"}.
#The planner's door surcharge stands in for the Interact the walk pays in AP once funded.
static func _step_price(state: BattleState, field: BattlefieldArea, path: Array[Vector3i], i: int,
		alt: int, ally_passable: Dictionary, fall_tolerance: float, flying: bool, can_climb: bool,
		merc_size: int) -> Dictionary:
	var from_cell: Vector3i = path[i - 1]
	var cell: Vector3i = path[i]
	var door := PathCost.is_shut_door(field, cell)
	var cost := PathCost.cell_pace_cost(from_cell, cell, field, ally_passable, fall_tolerance,
		flying, can_climb, merc_size, alt)
	var dead_body := _get_dead_body_at(from_cell, state)
	var deposed_merc := _get_deposed_merc_at(from_cell, state)
	if cost >= 0:
		if door:
			cost -= PathCost.door_pace_penalty
		if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
			cost += 1
		if deposed_merc != null and int(deposed_merc.stats.get("size", 1)) >= merc_size:
			cost += 1
	return {"cost": cost, "door": door, "body": dead_body, "deposed": deposed_merc}


#Cell the walk would end on with the pool and the Moves it may still buy; the start cell when it would not move.
static func _dry_walk_end(merc: MercenaryData, state: BattleState, field: BattlefieldArea, path: Array[Vector3i],
		path_start_idx: int, budget: int, start_cell: Vector3i, cur_alt: int, goal: Vector3i,
		ally_passable: Dictionary, fall_tolerance: float, flying: bool, can_climb: bool, merc_size: int,
		buy: Dictionary, known: Dictionary = {}, start_flanked: bool = false) -> Vector3i:
	var sim: Dictionary = buy.duplicate()
	sim["dry"] = true
	var end := start_cell
	var alt := cur_alt
	var occ_seen := false
	for i: int in range(path_start_idx + 1, path.size()):
		var from_cell: Vector3i = path[i - 1]
		var cell: Vector3i = path[i]
		var price := _step_price(state, field, path, i, alt, ally_passable, fall_tolerance,
			flying, can_climb, merc_size)
		var cost := int(price["cost"])
		var door: bool = price["door"]
		if cost < 0:
			break
		if cell != goal and not start_flanked and PathTargeter.is_flanked_by_known(cell, known):
			break
		if budget < cost:
			sim["door_reserve"] = _door_reserve_ahead(merc, state, field, path, i, goal, _purchase_reach(merc, budget, cost))
			var need := _fund_need(merc, state, sim, budget, cost)
			if need < 0:
				break
			budget += need * pace_per_move(merc)
			sim["bought"] = int(sim["bought"]) + need
			sim["left"] = int(sim["left"]) - need
			sim["sim_ap"] = int(sim.get("sim_ap", 0)) + int(sim.get("need_ap", 0))
		#The Interact of a door opened in stride comes out of the AP the walk has left.
		if door:
			var interact := state.get_cost(merc, "Interact", 2)
			if merc.current_ap + merc.excess_ap - int(sim.get("sim_ap", 0)) < interact:
				sim["why"] = "door_ap"
				break
			sim["sim_ap"] = int(sim.get("sim_ap", 0)) + interact
		budget -= cost
		if flying:
			alt = PathCost.fly_arrival_altitude(from_cell, cell, field, alt)
		if _can_end_on(cell, field, merc_size, flying):
			if state.is_position_occupied(Vector2i(cell.x, cell.y), merc, cell.z):
				occ_seen = true
			else:
				end = cell
		if from_cell.z != cell.z and not PathCost.drop_link(from_cell, cell, field).is_empty():
			break
	var dry_why := str(sim.get("why", ""))
	if dry_why.is_empty() and end == start_cell:
		dry_why = "occupied" if occ_seen else "no_step"
	buy["dry_why"] = dry_why
	return end


static func _walk_path(
		merc: MercenaryData,
		state: BattleState,
		field: BattlefieldArea,
		path: Array[Vector3i],
		path_start_idx: int,
		budget: int,
		start_cell: Vector3i,
		cur_alt: int,
		goal: Vector3i,
		ally_passable: Dictionary,
		fall_tolerance: float,
		flying: bool,
		can_climb: bool,
		merc_size: int,
		_known_enemies: Dictionary,
		_start_flanked: bool,
		traversed: Array[Vector3i],
		_cost_at: Array[int],
		_harm_at: Array[int],
		_body_at: Array[int],
		path_harms: Array[Dictionary],
		body_traverse_lines: Array[String],
		buy: Dictionary) -> Dictionary:
	var last := start_cell
	var drop_taken: Dictionary = {}
	var drop_cell := PathTargeter.NO_CELL
	var floor_change_cell := PathTargeter.NO_CELL
	#The walk halted because the pace pool could pay no further step.
	var _pool_stop := false
	var _band_stop := false
	var _band_need := 0
	var _band_budget := 0
	#Flyover cells of the band the walk could not cross, for the band re-plan.
	var _band_cells: Array[Vector3i] = []
	var _flanked_abort_fired := false
	var _flanked_abort_cell := PathTargeter.NO_CELL
	#Shut door the walk halted in front of; the mover opens it with the Interact action.
	var _door_stop := PathTargeter.NO_CELL
	var _is_free := func(c: Vector3i) -> bool:
		return not state.is_position_occupied(Vector2i(c.x, c.y), merc, c.z)
	for i: int in range(path_start_idx + 1, path.size()):
		var from_cell: Vector3i = path[i - 1]
		var cell: Vector3i = path[i]
		var price := _step_price(state, field, path, i, cur_alt, ally_passable, fall_tolerance,
			flying, can_climb, merc_size)
		var cost := int(price["cost"])
		var door: bool = price["door"]
		var dead_body: MercenaryData = price["body"]
		var deposed_merc: MercenaryData = price["deposed"]
		if cost < 0:
			break
		if cell != goal and not _start_flanked and PathTargeter.is_flanked_by_known(cell, _known_enemies):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("[MOVE] flanked-abort: %s at (%d,%d)" % [merc.merc_name, cell.x, cell.y])
			_flanked_abort_cell = cell
			_flanked_abort_fired = true
			break
		if budget < cost:
			buy["door_reserve"] = _door_reserve_ahead(merc, state, field, path, i, goal, _purchase_reach(merc, budget, cost))
		var funded := _fund_step(merc, state, buy, budget, cost)
		if funded < 0:
			_pool_stop = true
			break
		budget = funded
		if door and not _open_door_in_stride(merc, state, field, cell, traversed, _body_at, body_traverse_lines):
			_door_stop = cell
			break
		#A flyer may hover mid-band, but never where the path holds no standable cell ahead.
		if flying and not PathHelper.is_standable(cell, field, merc_size):
			var _la_need := fly_band_paces(path, i, cost, field, ally_passable,
				fall_tolerance, can_climb, merc_size, cur_alt, _is_free)
			if _la_need < 0:
				_band_stop = true
				_band_need = _la_need
				_band_budget = budget
				for _bj: int in range(i, path.size()):
					if PathHelper.is_standable(path[_bj], field, merc_size) and (_is_free.call(path[_bj]) as bool):
						break
					_band_cells.append(path[_bj])
				break
		budget -= cost
		if flying:
			cur_alt = PathCost.fly_arrival_altitude(from_cell, cell, field, cur_alt)
		if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
			body_traverse_lines.append("  %s moves through the body of %s." % [BattleState.colored_name(merc, state), dead_body.merc_name])
			_body_at.append(traversed.size() - 1)
		if deposed_merc != null:
			body_traverse_lines.append("  %s steps over the prone %s." % [BattleState.colored_name(merc, state), deposed_merc.merc_name])
			_body_at.append(traversed.size() - 1)
		var traversed_ally := _get_standing_ally_at(from_cell, merc, state)
		if traversed_ally != null:
			body_traverse_lines.append("  %s passes through %s's position." % [BattleState.colored_name(merc, state), traversed_ally.merc_name])
			_body_at.append(traversed.size() - 1)
		last = cell
		traversed.append(cell)
		_cost_at.append(cost)
		if from_cell.z != cell.z and floor_change_cell == PathTargeter.NO_CELL:
			floor_change_cell = cell
		var path_obs: Dictionary = field.get_obs(Vector2i(cell.x, cell.y), cell.z)
		if not path_obs.is_empty():
			var d: ObstacleData = path_obs.get("data") as ObstacleData
			if d != null and d.passthrough and d.pt_enter_harm > 0:
				path_harms.append({"damage": d.pt_enter_harm, "type": d.pt_harm_type, "name": d.obstacle_name})
				_harm_at.append(traversed.size() - 1)
		if from_cell.z != cell.z:
			var _dlk: Dictionary = PathCost.drop_link(from_cell, cell, field)
			if not _dlk.is_empty():
				drop_taken = _dlk
				drop_cell = cell
				break
	return {
		"budget": budget,
		"last": last,
		"cur_alt": cur_alt,
		"drop_taken": drop_taken,
		"drop_cell": drop_cell,
		"floor_change": floor_change_cell,
		"band_stop": _band_stop,
		"band_need": _band_need,
		"band_budget": _band_budget,
		"band_cells": _band_cells,
		"pool_stop": _pool_stop,
		"flanked_fired": _flanked_abort_fired,
		"flanked_cell": _flanked_abort_cell,
		"door_stop": _door_stop,
	}


#Smallest altitude change within budget that opens line of sight to target; -1 when none does.
static func _los_altitude(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		pos: Vector3i, cur_h: int, budget: int, target: MercenaryData) -> int:
	if field == null or target == null or budget <= 0:
		return -1
	var fly_size := maxi(1, int(merc.stats.get("size", 1)))
	var pos2d := Vector2i(pos.x, pos.y)
	var max_h := 9999
	var ceil_e := PathCost.slab_above(pos2d, pos.z, field)
	if ceil_e < PathCost.NO_CEILING:
		max_h = int(floor(ceil_e - field.cell_base_elevation(pos2d, pos.z))) - fly_size
	for step: int in range(1, budget + 1):
		var up := cur_h + step
		if up <= max_h and (LineOfSight.check_from(state, pos, up, fly_size, target)["visible"] as bool):
			return up
		var down := cur_h - step
		if down >= 0 and (LineOfSight.check_from(state, pos, down, fly_size, target)["visible"] as bool):
			return down
	return -1


#A flyer stepping down a pace or more chose the descent; it is narrated without a fall.
static func _descent_line(merc: MercenaryData, paces: int, state: BattleState) -> String:
	return "  %s descends %d Pace%s." % [BattleState.colored_name(merc, state), paces, "s" if paces != 1 else ""]


#Goal cell the mover can actually reach, with the reachability map the path search reuses.
static func _resolve_goal(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		goal: Vector3i, old_pos: Vector3i, fall_tolerance: float, can_climb: bool,
		move_size: int, flying: bool, altitude: int) -> Dictionary:
	var _raw_goal := goal
	var _reach: Dictionary = PathTargeter.reachable_for(merc, state)
	#The goal and the window nearest_passable_to scans are grown past the two-turn bound.
	_reach = PathTargeter.reachable_around_for(merc, state, _raw_goal)
	var _mover := {"fall_tolerance": fall_tolerance, "can_climb": can_climb, "merc_size": move_size,
		"flying": flying, "altitude": altitude, "state": state, "merc": merc}
	goal = PathHelper.nearest_passable_to(_raw_goal, field, _mover, {}, _reach, old_pos,
		PathTargeter.JUMP_COST_OFFSET - 1)
	if goal != _raw_goal and EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE GOAL ADJUST: (%d,%d)->(%d,%d) reason=%s" % [
			_raw_goal.x, _raw_goal.y, goal.x, goal.y,
			_goal_adjust_reason(_raw_goal, field, state, merc, _reach, false)])
	if _blocked_path_goals.has(goal):
		if (_blocked_path_goals[goal] as int) >= state.round_number:
			var _excl: Dictionary = {}
			for _bg: Vector3i in _blocked_path_goals:
				if (_blocked_path_goals[_bg] as int) >= state.round_number:
					_excl[_bg] = true
			#The goal itself is excluded here, so the cells around it are grown to.
			_reach = PathTargeter.reachable_around_for(merc, state, _raw_goal, true)
			var _alt: Vector3i = PathHelper.nearest_passable_to(_raw_goal, field, _mover, _excl,
				_reach, old_pos, PathTargeter.JUMP_COST_OFFSET - 1)
			if _alt != goal:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("MOVE GOAL ADJUST: (%d,%d)->(%d,%d) reason=blocked" % [
						goal.x, goal.y, _alt.x, _alt.y])
				goal = _alt
				state.move_goals[merc] = goal
			else:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("MOVE BLOCKED: %s goal=(%d,%d) no alt" % [merc.merc_name, goal.x, goal.y])
				return {"goal": goal, "raw_goal": _raw_goal, "reach": _reach, "abort": true}
		else:
			_blocked_path_goals.erase(goal)
	return {"goal": goal, "raw_goal": _raw_goal, "reach": _reach, "abort": false}


#Path the walk follows and the index it starts from; blocked is true when no step is possible.
static func _select_path(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		move_target: MercenaryData, old_pos: Vector3i, goal: Vector3i, _raw_goal: Vector3i,
		_reach: Dictionary, seeking: bool, ally_passable: Dictionary, fall_tolerance: float,
		flying: bool, can_climb: bool, jump_stat: int, move_size: int, altitude: int,
		_known_enemies: Dictionary) -> Dictionary:
	var blocked := false
	var path: Array[Vector3i] = []
	var path_start_idx := 0
	if not seeking:
		var _cached_tp: Variant = _turn_path_cache.get(merc)
		if _cached_tp != null:
			var _ctp := _cached_tp as Dictionary
			if (_ctp.get("goal") as Vector3i) == goal:
				var _cpath: Array[Vector3i] = _ctp.get("path", []) as Array[Vector3i]
				var _cidx: int = _ctp.get("idx", 0)
				for _cj in range(_cidx, _cpath.size()):
					if _cpath[_cj] == old_pos:
						path = _cpath
						path_start_idx = _cj
						break
	if path.is_empty():
		var _flank_blocked := PathTargeter.flanked_cells(old_pos, goal, field, _known_enemies)
		#The flood's own walk path serves unless it crosses a flanked cell; A* stays for the blocked and empty cases.
		var _flood_path := PathTargeter.walk_path_for(merc, state, old_pos, goal)
		if not _flank_blocked.is_empty():
			var _crosses := _flood_path.is_empty()
			for _fc: Vector3i in _flood_path:
				if _flank_blocked.has(_fc):
					_crosses = true
					break
			if _crosses:
				path = Pathfinder.find_path(old_pos, goal, field, ally_passable, fall_tolerance, flying, can_climb, move_size, altitude, _flank_blocked)
			else:
				path = _flood_path
		if path.is_empty():
			path = _flood_path
		if path.is_empty():
			path = Pathfinder.find_path(old_pos, goal, field, ally_passable, fall_tolerance, flying, can_climb, move_size, altitude)
		if path.is_empty():
			if seeking:
				var seek_path := PathHelper.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, flying, can_climb, jump_stat, move_size, altitude)
				if not seek_path.is_empty():
					path = seek_path
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("SEEK MOVE: partial path (%d,%d)->(%d,%d) advancing to (%d,%d)" % [
							old_pos.x, old_pos.y, goal.x, goal.y,
							seek_path[-1].x, seek_path[-1].y])
				else:
					blocked = true
					_blocked_path_goals[goal] = state.round_number
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("SEEK MOVE BLOCKED: no reachable cell toward (%d,%d)" % [goal.x, goal.y])
			else:
				var toward_path := PathHelper.find_path_toward(old_pos, goal, field, ally_passable, fall_tolerance, flying, can_climb, jump_stat, move_size, altitude)
				if not toward_path.is_empty():
					path = toward_path
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("MOVE PARTIAL: no exact path (%d,%d)->(%d,%d), advancing to (%d,%d) reason=%s" % [
							old_pos.x, old_pos.y, goal.x, goal.y,
							toward_path[-1].x, toward_path[-1].y,
							_partial_reason(goal, _reach)])
				else:
					var _alt_path: Array[Vector3i] = []
					var _alt_best_dist := 999999
					for _ad: Vector2i in PathCost.DIRS8:
						var _ag := Vector3i(_raw_goal.x + _ad.x, _raw_goal.y + _ad.y, _raw_goal.z)
						if _ag.x < 0 or _ag.x >= field.width or _ag.y < 0 or _ag.y >= field.length:
							continue
						if _blocked_path_goals.has(_ag) and (_blocked_path_goals[_ag] as int) >= state.round_number:
							continue
						var _ap: Array[Vector3i] = PathHelper.find_path_toward(old_pos, _ag, field, ally_passable, fall_tolerance, flying, can_climb, jump_stat, move_size, altitude)
						if not _ap.is_empty():
							var _ad_dist := maxi(abs(_ap[-1].x - _raw_goal.x), abs(_ap[-1].y - _raw_goal.y))
							if _ad_dist < _alt_best_dist:
								_alt_best_dist = _ad_dist
								_alt_path = _ap
					if not _alt_path.is_empty():
						path = _alt_path
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("MOVE REROUTED: (%d,%d)->(%d,%d) blocked, advancing via (%d,%d)" % [
								old_pos.x, old_pos.y, goal.x, goal.y, _alt_path[-1].x, _alt_path[-1].y])
					else:
						blocked = true
						var _static_path := PathHelper.find_path_toward(
							old_pos, _raw_goal, field, state.nav_passable_3d(),
							fall_tolerance, flying, can_climb, jump_stat, move_size, altitude)
						_blocked_path_goals[goal] = state.round_number + (1000 if _static_path.is_empty() else 0)
						if _static_path.is_empty():
							merc.active_states["_move_blocked_round"] = state.round_number
							var _mb: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
							_mb[move_target] = true
							state.movement_blocked[merc] = _mb
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("MOVE BLOCKED: no path (%d,%d)->(%d,%d)" % [
								old_pos.x, old_pos.y, goal.x, goal.y])
		if not path.is_empty() and goal.z != old_pos.z and EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE ROUTE: %s len=%d door_pen=%d %s" % [
				merc.merc_name, path.size(), PathCost.door_pace_penalty, _route_summary(path, field)])
		if not path.is_empty() and not seeking:
			_turn_path_cache[merc] = {"goal": goal, "path": path, "idx": 0}
	return {"path": path, "start_idx": path_start_idx, "blocked": blocked}


#Push-back trim, the one re-plan and the pool bookkeeping that close a walk.
static func _finish_walk(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		_walk: Dictionary, path: Array[Vector3i], path_start_idx: int, old_pos: Vector3i,
		goal: Vector3i, move_target: MercenaryData, altitude: int, flying: bool, merc_size: int,
		ally_passable: Dictionary, fall_tolerance: float, can_climb: bool, _known_enemies: Dictionary,
		traversed: Array[Vector3i], _cost_at: Array[int], _harm_at: Array[int], _body_at: Array[int],
		path_harms: Array[Dictionary], body_traverse_lines: Array[String], drop_lines: Array[String],
		_step_falls: Array[int], _buy: Dictionary, _pool_start: int, fly_top: float) -> Dictionary:
	var new_pos := old_pos
	var _stall_why := "no_path"
	var _stall_path := ""
	var _door_no_step := false
	var _hover_alt := -1
	var _pace_left := 0
	var budget := _walk["budget"] as int
	var last := _walk["last"] as Vector3i
	var drop_taken: Dictionary = _walk["drop_taken"] as Dictionary
	var drop_cell: Vector3i = _walk["drop_cell"] as Vector3i
	var floor_change_cell: Vector3i = _walk["floor_change"] as Vector3i
	var _band_stop := _walk["band_stop"] as bool
	var _band_need := _walk["band_need"] as int
	var _band_budget := _walk["band_budget"] as int
	var _band_cells: Array[Vector3i] = _walk["band_cells"] as Array[Vector3i]
	var _flanked_abort_fired := _walk["flanked_fired"] as bool
	var _flanked_abort_cell := _walk["flanked_cell"] as Vector3i
	var _door_stop := _walk["door_stop"] as Vector3i
	var _pool_stop := _walk["pool_stop"] as bool
	#Paces charged on the first walk, for the MOVE PATH line.
	var _planned := _pool_start + int(_buy["bought"]) * pace_per_move(merc) - budget
	for k: int in range(traversed.size() - 1, 0, -1):
		var _tk: Vector3i = traversed[k]
		if state.is_position_occupied(Vector2i(_tk.x, _tk.y), merc, _tk.z):
			continue
		if not _can_end_on(_tk, field, merc_size, flying):
			continue
		last = _tk
		break
	new_pos = last
	if not _can_end_on(new_pos, field, merc_size, flying):
		new_pos = old_pos
	#A push-back can leave the mover out of reach of the door it halted at, and
	#only a mover standing next to the door can spend Interact on it.
	if _door_stop != PathTargeter.NO_CELL and new_pos.z == _door_stop.z \
			and maxi(absi(new_pos.x - _door_stop.x), absi(new_pos.y - _door_stop.y)) <= 1:
		state.pending_interact[merc] = _door_stop
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE STOP: %s at (%d,%d) closed door at (%d,%d)" % [
				merc.merc_name, new_pos.x, new_pos.y, _door_stop.x, _door_stop.y])
		#The door is the very next cell, so no step was taken; only a re-plan
		#that routes around it can still earn the Move its AP.
		if new_pos == old_pos:
			_door_no_step = true
	if new_pos == old_pos:
		_stall_why = "unstandable" if traversed.size() > 1 else "no_step"
		var _sp: Array[String] = []
		for _spc: Vector3i in traversed:
			_sp.append("(%d,%d,%d)" % [_spc.x, _spc.y, _spc.z])
		_stall_path = " -> ".join(_sp)
		if _pool_stop:
			_stall_why = "pool_empty"
	#The flyer could not clear the band, so it halts on the last standable cell.
	if _band_stop:
		if new_pos == old_pos:
			_stall_why = "band_exceeds_pace band=%s" % ("none" if _band_need < 0 else str(_band_need))
		elif EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE PARTIAL: %s stopped at (%d,%d) reason=band_exceeds_pace band=%s budget=%d" % [
				merc.merc_name, new_pos.x, new_pos.y, "none" if _band_need < 0 else str(_band_need), _band_budget])
	var _kept := traversed.find(new_pos)
	#Paces paid for cells the push-back took the mover off; the pool gets them back.
	var _rejected: Dictionary = {}
	var _pushed := _trim_to(_kept, traversed, _cost_at, _harm_at, _body_at, path_harms,
		body_traverse_lines, _rejected)
	budget += _pushed
	if not drop_taken.is_empty() and new_pos != drop_cell:
		drop_taken = {}
	#Altitude the mover holds on the cell the walk left it on.
	var _rp_alt := altitude
	if flying:
		for _ri: int in range(1, traversed.size()):
			_rp_alt = PathCost.fly_arrival_altitude(traversed[_ri - 1], traversed[_ri], field, _rp_alt)
	#One re-plan per Move: whatever halted the walk names the cells the new route
	#must avoid and how much the alternative has to deliver before it is taken.
	var _rp_reason := ""
	var _rp_blocked: Dictionary = {}
	var _rp_require_goal := false
	if _door_stop != PathTargeter.NO_CELL:
		_rp_reason = "door"
		_rp_blocked[_door_stop] = true
		_rp_require_goal = true
	elif _band_stop:
		_rp_reason = "band"
		for _bc: Vector3i in _band_cells:
			_rp_blocked[_bc] = true
		_rp_require_goal = true
	elif _flanked_abort_fired and _flanked_abort_cell != PathTargeter.NO_CELL:
		_rp_reason = "flanked"
		_rp_blocked[_flanked_abort_cell] = true
	elif not drop_taken.is_empty() and new_pos == drop_cell:
		_rp_reason = "drop"
	elif _pushed > 0 and drop_taken.is_empty():
		_rp_reason = "pushback"
		_rp_blocked = _rejected
	if _rp_reason != "" and (budget <= 0 or new_pos == goal):
		_rp_reason = ""
	if _rp_reason == "drop":
		#The fall lands before the re-plan so its damage and any Deposed count.
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("LEDGE DROP: %s %s F%d->F0 (%d,%d) paces=%d" % [
				merc.merc_name, str(drop_taken["kind"]), old_pos.z, new_pos.x, new_pos.y,
				int(drop_taken["paces"])])
		_turn_path_cache.erase(merc)
		drop_lines.append_array(CombatApplicator.resolve_fall(merc, int(drop_taken["paces"]), state))
		state.set_height(merc, 0)
		drop_taken = {}
		_rp_alt = 0
		if not BattleState._is_alive(merc) or ConstStates.has_state(merc, ConstStates.DEPOSED):
			_rp_reason = ""
	if _rp_reason != "":
		var _rp_from := new_pos
		var _rp: Dictionary = _replan_move(merc, state, field, _rp_reason, new_pos,
			_rp_blocked, budget, _rp_alt, goal, ally_passable, fall_tolerance, flying,
			can_climb, merc_size, _known_enemies, _rp_require_goal, _rejected, traversed,
			_cost_at, _harm_at, _body_at, path_harms, body_traverse_lines, _buy)
		if _rp["ran"] as bool:
			budget = _rp["budget"] as int
			_pushed += _rp["pushed"] as int
			drop_taken = _rp["drop_taken"] as Dictionary
			drop_cell = _rp["drop_cell"] as Vector3i
			if floor_change_cell == PathTargeter.NO_CELL:
				floor_change_cell = _rp["floor_change"] as Vector3i
			var _rp_end := _rp["end"] as Vector3i
			if _rp_end != _rp_from:
				new_pos = _rp_end
				_turn_path_cache.erase(merc)
				if _rp_reason == "door":
					state.pending_interact.erase(merc)
					_door_no_step = false
	#A cell a push-back took the mover off is no goal for anyone this round.
	for _rc: Vector3i in _rejected:
		if (_blocked_path_goals.get(_rc, 0) as int) < state.round_number:
			_blocked_path_goals[_rc] = state.round_number
	#Paces left at a door the mover cannot open are forfeited; no later Move retries the door.
	if budget > 0 and _door_stop != PathTargeter.NO_CELL \
			and state.pending_interact.get(merc, PathTargeter.NO_CELL) == _door_stop \
			and not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("POOL DROPPED: %s %d paces at closed door (%d,%d)" % [
				merc.merc_name, budget, _door_stop.x, _door_stop.y])
		budget = 0
	state.set_pace_pool(merc, maxi(0, budget))
	var _why := str(_buy.get("why", ""))
	if _pool_stop and _why != "moves_spent" and new_pos != old_pos and new_pos != goal \
			and EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE PARTIAL: %s stopped at (%d,%d) reason=pool_empty why=%s pool=%d" % [
			merc.merc_name, new_pos.x, new_pos.y, _why, maxi(0, budget)])
	if _door_no_step and new_pos == old_pos:
		return {"new_pos": new_pos, "stall_why": _stall_why, "stall_path": _stall_path, "drop_taken": drop_taken, "floor_change": floor_change_cell, "fly_top": fly_top, "hover_alt": _hover_alt, "pace_left": _pace_left, "abort": true}
	#A flyer that ran out of paces mid-band holds the altitude it crossed it with.
	if flying and new_pos != old_pos and not PathHelper.is_standable(new_pos, field, merc_size):
		_hover_alt = altitude
		for _hi: int in range(1, traversed.size()):
			_hover_alt = PathCost.fly_arrival_altitude(traversed[_hi - 1], traversed[_hi], field, _hover_alt)
	_pace_left = maxi(0, budget)
	if flying and new_pos != old_pos:
		for _fi2: int in range(1, traversed.size()):
			var _fcell: Vector3i = traversed[_fi2]
			var _f2d := Vector2i(_fcell.x, _fcell.y)
			if field.is_stair_cell(_f2d, _fcell.z):
				continue
			var _fobs: Dictionary = field.get_obs(_f2d, _fcell.z)
			if _fobs.is_empty() or PathCost.is_ground_pass(_fobs):
				continue
			var _ftop: float = field.cell_base_elevation(_f2d, _fcell.z) + BattlefieldArea.obstacle_height(_fobs)
			if _ftop > fly_top:
				fly_top = _ftop
	if _flanked_abort_fired and new_pos != old_pos:
		if (_blocked_path_goals.get(goal, 0) as int) < state.round_number + 3:
			_blocked_path_goals[goal] = state.round_number + 3
	if _flanked_abort_fired and new_pos == old_pos and _flanked_abort_cell != PathTargeter.NO_CELL:
		var _fa_tpos := state.pos3(move_target)
		if Vector2i(_fa_tpos.x, _fa_tpos.y) != Vector2i(-1, -1):
			for _fad: Vector2i in PathCost.DIRS8:
				var _fac := Vector3i(_fa_tpos.x + _fad.x, _fa_tpos.y + _fad.y, _fa_tpos.z)
				if _fac.x < 0 or _fac.x >= field.width or _fac.y < 0 or _fac.y >= field.length:
					continue
				if (_blocked_path_goals.get(_fac, 0) as int) < state.round_number + 3:
					_blocked_path_goals[_fac] = state.round_number + 3
	if _turn_path_cache.has(merc):
		var _cti: int = path_start_idx
		for _ctj in range(path_start_idx, path.size()):
			if path[_ctj] == new_pos:
				_cti = _ctj
				break
		(_turn_path_cache[merc] as Dictionary)["idx"] = _cti
	for _sfi: int in range(1, traversed.size()):
		if traversed[_sfi].z != traversed[_sfi - 1].z:
			continue
		var _sf_drop := -PathCost.walk_h_diff(traversed[_sfi - 1], traversed[_sfi], field)
		if _sf_drop >= 1.0:
			_step_falls.append(int(floor(_sf_drop)))
	if EncounterLogger.is_active() and traversed.size() > 1:
		var parts: Array[String] = []
		for c: Vector3i in traversed:
			parts.append("(%d,%d)" % [c.x, c.y])
		var _avail := _pool_start + int(_buy["bought"]) * pace_per_move(merc)
		EncounterLogger.log_verbose("MOVE PATH: %s  planned %d, pushed back %d, moved %d of %d pool=%d" % [
			" -> ".join(parts), _planned, _pushed, _avail - budget, _avail, maxi(0, budget)])
	return {"new_pos": new_pos, "stall_why": _stall_why, "stall_path": _stall_path, "drop_taken": drop_taken, "floor_change": floor_change_cell, "fly_top": fly_top, "hover_alt": _hover_alt, "pace_left": _pace_left, "abort": false}


#Cell a flank step around an oscillation block reaches, or NO_CELL when none is affordable.
static func _oscillation_flank(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		move_target: MercenaryData, old_pos: Vector3i, altitude: int, flying: bool,
		_hist: Array) -> Vector3i:
	if field != null:
		var _enemy_pos := state.pos3(move_target)
		var _delta := Vector2i(_enemy_pos.x - old_pos.x, _enemy_pos.y - old_pos.y)
		var _len_f := maxf(1.0, Vector2(float(_delta.x), float(_delta.y)).length())
		var _perp := Vector2i(roundi(-float(_delta.y) / _len_f * 4.0), roundi(float(_delta.x) / _len_f * 4.0))
		var _ally_pass: Dictionary = state.ally_passable_3d(merc)
		var _fall_tol := PathTargeter.fall_tolerance(merc)
		var _can_cl: bool = true
		var _jmp: int = int(merc.stats.get("jump", 0))
		var _osc_size: int = int(merc.stats.get("size", 1))
		for _side: int in [1, -1]:
			var _fg2 := field.clamp_position(Vector2i(_enemy_pos.x, _enemy_pos.y) + _perp * _side)
			var _fg := Vector3i(_fg2.x, _fg2.y, _enemy_pos.z)
			var _fp := PathHelper.find_path_toward(old_pos, _fg, field, _ally_pass, _fall_tol, flying, _can_cl, _jmp, _osc_size, altitude)
			if _fp.is_empty():
				continue
			var _fb := pace_per_move(merc)
			var _fn := old_pos
			for _fi: int in range(1, _fp.size()):
				var _fc := PathCost.cell_pace_cost(_fp[_fi - 1], _fp[_fi], field, {}, _fall_tol, flying, _can_cl, _osc_size, altitude)
				if _fc < 0 or _fb - _fc < 0:
					break
				_fb -= _fc
				_fn = _fp[_fi]
			if _fn == old_pos or _hist.has(Vector2i(_fn.x, _fn.y)):
				continue
			if not PathHelper.is_standable(_fn, field, _osc_size):
				continue
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("OSCILLATION FLANK: %s flanking to (%d,%d)" % [merc.merc_name, _fn.x, _fn.y])
			return _fn
	return PathTargeter.NO_CELL


static func execute_move(
		merc: MercenaryData,
		action_name: String,
		move_target: MercenaryData,
		state: BattleState,
		flank_ally: MercenaryData = null,
		enhancements: int = 0,
		stop_dist_override: int = -1,
		seeking: bool = false,
		valid_targets: Array[MercenaryData] = [],
		enemies: Array[MercenaryData] = [],
		goal_cell: Vector3i = PathTargeter.NO_CELL) -> Array[String]:
	if move_target == null:
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []

	var old_pos := state.pos3(merc)
	var old_2d := Vector2i(old_pos.x, old_pos.y)
	#Routing may cross a shut door this mover can open, at the pace its Interact costs.
	PathCost.set_door_penalty(PathCost.door_penalty(merc))
	state.pending_interact.erase(merc)
	#The executor must plan with the same capabilities the targeter scored with.
	var flying := PathTargeter.is_flying(merc)
	#Paces above the surface of the mover's own cell; always 0 for a walker.
	var altitude := state.get_height(merc)
	#Highest absolute obstacle top the mover flew over on this move.
	var fly_top := -1.0e9
	var _known_enemies: Dictionary = merc.last_known_enemy_positions.duplicate()
	var goal := goal_cell
	if goal == PathTargeter.NO_CELL:
		goal = compute_move_position(merc, move_target, action_name, state, flank_ally, stop_dist_override, valid_targets, enemies)
	if goal == PathTargeter.NO_CELL:
		var _mb: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
		_mb[move_target] = true
		state.movement_blocked[merc] = _mb
		merc.active_states["_move_blocked_round"] = state.round_number
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE BLOCKED: %s no reachable cell near %s" % [merc.merc_name, move_target.merc_name])
		return []
	if goal == old_pos:
		var skip_field := state.battlefield
		var skip_size := maxi(1, int(merc.stats.get("size", 1)))
		#A flyer that is already in place may still pay pace to see its target.
		if flying and skip_field != null and move_target != null and state.get_height(merc) >= 1 \
				and not (LineOfSight.check_from(state, old_pos, altitude, skip_size, move_target)["visible"] as bool):
			var skip_h := state.get_height(merc)
			var skip_budget := state.get_pace_pool(merc)
			var skip_found := _los_altitude(merc, state, skip_field, old_pos, skip_h, skip_budget, move_target)
			if skip_found < 0 and state.can_afford(merc, state.get_cost(merc, action_name, _CONFIG.move_base_ap)):
				skip_found = _los_altitude(merc, state, skip_field, old_pos, skip_h,
					skip_budget + pace_per_move(merc), move_target)
				if skip_found >= 0:
					_buy_move(merc, state, action_name)
					skip_budget = state.get_pace_pool(merc)
			if skip_found >= 0:
				var skip_abs := state.absolute_height(merc)
				state.set_height(merc, skip_found)
				state.set_pace_pool(merc, maxi(0, skip_budget - absi(skip_found - skip_h)))
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("ALTITUDE: %s h%d -> h%d reason=los" % [
						merc.merc_name, skip_abs, state.absolute_height(merc)])
					EncounterLogger.log_verbose("MOVE ALTITUDE: %s at (%d,%d) h%d -> h%d pool=%d" % [
						merc.merc_name, old_pos.x, old_pos.y, skip_abs, state.absolute_height(merc),
						state.get_pace_pool(merc)])
				var skip_lines: Array[String] = []
				skip_lines.append("  %s changes altitude ([color=orange]h%d -> h%d[/color])" % [
					BattleState.colored_name(merc, state), skip_abs, state.absolute_height(merc)])
				return skip_lines
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE SKIP: %s already at goal (%d,%d)" % [merc.merc_name, goal.x, goal.y])
		return []
	var new_pos := goal
	#Why the mover ended where it started, for the MOVE STALLED line.
	var _stall_why := "no_path"
	var _stall_path := ""
	#Pace not spent on the traversal; a flyer may spend it on an altitude change.
	var _pace_left := 0
	#Altitude a flyer holds when its paces ran out over a flyover cell; -1 when it landed.
	var _hover_alt := -1
	var path_harms: Array[Dictionary] = []
	var body_traverse_lines: Array[String] = []
	var drop_taken: Dictionary = {}
	var floor_change_cell := PathTargeter.NO_CELL
	#A drop resolved early so the drop re-plan can read the landing state.
	var drop_lines: Array[String] = []
	#Paces of every same-floor step down of a pace or more, resolved as falls after the walk.
	var _step_falls: Array[int] = []
	#The walk halted on the door in front of it without taking a step.
	var _door_no_step := false
	var field := state.battlefield
	if field != null:
		var fall_tolerance := PathTargeter.fall_tolerance(merc)
		var can_climb: bool = true
		var jump_stat: int = int(merc.stats.get("jump", 0))
		var move_size: int = int(merc.stats.get("size", 1))
		var _rg: Dictionary = _resolve_goal(merc, state, field, goal, old_pos, fall_tolerance,
			can_climb, move_size, flying, altitude)
		if _rg["abort"] as bool:
			return []
		goal = _rg["goal"] as Vector3i
		var _raw_goal: Vector3i = _rg["raw_goal"] as Vector3i
		var _reach: Dictionary = _rg["reach"] as Dictionary
		var ally_passable: Dictionary = state.ally_passable_3d(merc)
		var _sp: Dictionary = _select_path(merc, state, field, move_target, old_pos, goal, _raw_goal,
			_reach, seeking, ally_passable, fall_tolerance, flying, can_climb, jump_stat, move_size,
			altitude, _known_enemies)
		var path: Array[Vector3i] = _sp["path"] as Array[Vector3i]
		var path_start_idx: int = _sp["start_idx"] as int
		if _sp["blocked"] as bool:
			new_pos = old_pos
		if not path.is_empty() and path.size() > path_start_idx + 1:
			var _mplan: Dictionary = state.move_plan.get(merc, {}) as Dictionary
			var _pool_start := state.get_pace_pool(merc)
			#Move purchases this walk may still make, and the AP it holds back for them.
			var _buy: Dictionary = {
				"action_name": action_name,
				"left": maxi(1, int(_mplan.get("moves_allowed", 1))),
				"reserve": maxi(0, int(_mplan.get("reserve_ap", 0))),
				"bought": 0,
				"pool_start": _pool_start,
				"why": "",
			}
			var traversed: Array[Vector3i] = [old_pos]
			#Which traversed cell produced each harm and each narration line, so both
			#can be dropped when the mover is pushed back off a cell it cannot stand on.
			var _harm_at: Array[int] = []
			var _body_at: Array[int] = []
			#Pace charged to enter each traversed cell; a push-back never gives it back.
			var _cost_at: Array[int] = [0]
			var merc_size := int(merc.stats.get("size", 1))
			#Altitude the mover has as it leaves the cell it currently stands on.
			var cur_alt := altitude
			var _start_flanked := PathTargeter.is_flanked_by_known(old_pos, _known_enemies)
			#A walk that cannot pay its way to any cell it may end on buys nothing.
			var _dry_end := _dry_walk_end(merc, state, field, path, path_start_idx, _pool_start, old_pos, cur_alt,
				goal, ally_passable, fall_tolerance, flying, can_climb, merc_size, _buy, _known_enemies, _start_flanked)
			if _dry_end == old_pos:
				var _dry_why := str(_buy.get("dry_why", ""))
				#An AP-short walk whose next cell is a shut door opens it with the Interact action instead.
				var _door_first := _dry_why != "occupied" and _dry_why != "no_step" \
						and PathCost.is_shut_door(field, path[path_start_idx + 1])
				if _door_first:
					state.pending_interact[merc] = path[path_start_idx + 1]
				elif (_blocked_path_goals.get(goal, 0) as int) < state.round_number:
					_blocked_path_goals[goal] = state.round_number
				_turn_path_cache.erase(merc)
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("MOVE REFUSED: %s goal=(%d,%d) reason=%s pool=%d moves=%d why=%s" % [
						merc.merc_name, goal.x, goal.y, "door_first" if _door_first else "pool_short",
						_pool_start, int(_buy["left"]), _dry_why])
					EncounterLogger.log_verbose("MOVE REFUSED STEPS: %s pp=%d ap=%d+%d reserve=%d %s" % [
						merc.merc_name, pace_per_move(merc), merc.current_ap, merc.excess_ap, int(_buy["reserve"]),
						_refused_steps(merc, state, field, path, path_start_idx, cur_alt, ally_passable, fall_tolerance,
							flying, can_climb, merc_size)])
				return []
			var _walk := _walk_path(merc, state, field, path, path_start_idx, _pool_start, old_pos, cur_alt,
				goal, ally_passable, fall_tolerance, flying, can_climb, merc_size, _known_enemies,
				_start_flanked, traversed, _cost_at, _harm_at, _body_at, path_harms, body_traverse_lines, _buy)
			var _fin: Dictionary = _finish_walk(merc, state, field, _walk, path, path_start_idx,
				old_pos, goal, move_target, altitude, flying, merc_size, ally_passable, fall_tolerance,
				can_climb, _known_enemies, traversed, _cost_at, _harm_at, _body_at, path_harms,
				body_traverse_lines, drop_lines, _step_falls, _buy, _pool_start, fly_top)
			new_pos = _fin["new_pos"] as Vector3i
			_stall_why = _fin["stall_why"] as String
			_stall_path = _fin["stall_path"] as String
			drop_taken = _fin["drop_taken"] as Dictionary
			floor_change_cell = _fin["floor_change"] as Vector3i
			fly_top = _fin["fly_top"] as float
			_hover_alt = _fin["hover_alt"] as int
			_pace_left = _fin["pace_left"] as int
			if _fin["abort"] as bool:
				return []

	if new_pos == old_pos:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE STALLED: %s goal=(%d,%d) no viable path reason=%s fly=%d path=%s" % [
				merc.merc_name, goal.x, goal.y, _stall_why, 1 if flying else 0, _stall_path])
		var _stall_pace := pace_per_move(merc)
		var _perm_block := false
		if field != null:
			var _stall_ft := PathTargeter.fall_tolerance(merc)
			var _stall_ap: Dictionary = state.ally_passable_3d(merc)
			var _any_affordable := false
			for _snb: Vector3i in PathCost.neighbors(old_pos, field):
				if _snb.x < 0 or _snb.x >= field.width or _snb.y < 0 or _snb.y >= field.length:
					continue
				var _sc := PathCost.cell_pace_cost(old_pos, _snb, field, _stall_ap, _stall_ft, flying, true, int(merc.stats.get("size", 1)), altitude)
				if _sc >= 0:
					_any_affordable = true
					break
			if not _any_affordable:
				_perm_block = true
		if _perm_block:
			merc.active_states["_move_blocked_round"] = state.round_number
			var _smb: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
			_smb[move_target] = true
			state.movement_blocked[merc] = _smb
			_blocked_path_goals[goal] = state.round_number + 1000
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("MOVE BLOCKED: %s no affordable step from (%d,%d)" % [merc.merc_name, old_pos.x, old_pos.y])
		else:
			if (_blocked_path_goals.get(goal, 0) as int) < state.round_number + 3:
				_blocked_path_goals[goal] = state.round_number + 3
			if field != null and move_target != null:
				var _target_pos := state.pos3(move_target)
				if Vector2i(_target_pos.x, _target_pos.y) != Vector2i(-1, -1):
					var _cands: Array[Vector3i] = []
					for _d: Vector2i in PathCost.DIRS8:
						var _cand := Vector3i(_target_pos.x + _d.x, _target_pos.y + _d.y, _target_pos.z)
						if _cand.x < 0 or _cand.x >= field.width or _cand.y < 0 or _cand.y >= field.length:
							continue
						_cands.append(_cand)
					var _mt_reach: Dictionary = PathTargeter.reachable_far_for(merc, state, _cands)
					for _mc: Vector3i in _cands:
						#A jump-only node is not a walkable approach cell, so it stays blacklisted.
						if _mt_reach.has(_mc) and (_mt_reach[_mc] as int) < PathTargeter.JUMP_COST_OFFSET:
							continue
						if (_blocked_path_goals.get(_mc, 0) as int) < state.round_number + 3:
							_blocked_path_goals[_mc] = state.round_number + 3
		return []

	if not seeking:
		var _hist: Array = state.position_history.get(merc, []) as Array
		if _hist.has(Vector2i(new_pos.x, new_pos.y)):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("OSCILLATION BLOCKED: %s would return to recently visited (%d,%d)" % [
					merc.merc_name, new_pos.x, new_pos.y])
			var _flank_cell := _oscillation_flank(merc, state, field, move_target, old_pos, altitude, flying, _hist)
			var _flank_ok := _flank_cell != PathTargeter.NO_CELL
			if _flank_ok:
				new_pos = _flank_cell
				body_traverse_lines.clear()
			if not _flank_ok:
				_blocked_path_goals[goal] = state.round_number
				return []
			_blocked_path_goals[goal] = state.round_number + 3

	var move_lines: Array[String] = []

	var new_2d := Vector2i(new_pos.x, new_pos.y)
	move_lines.append_array(_advantage_attacks(merc, state, old_2d, new_2d, enhancements))

	state.escalation[merc]["last_move_from"] = old_pos
	state.set_pos3(merc, new_pos)
	if new_pos.z != old_pos.z and EncounterLogger.is_active():
		var _fc: Vector3i = floor_change_cell if floor_change_cell != PathTargeter.NO_CELL else new_pos
		EncounterLogger.log_verbose("FLOOR: %s %d->%d at (%d,%d)" % [
			merc.merc_name, old_pos.z, new_pos.z, _fc.x, _fc.y])
	merc.aim_active = false

	var _goal_after_move: Vector3i = state.move_goals.get(merc, PathTargeter.NO_CELL) as Vector3i
	if _goal_after_move != PathTargeter.NO_CELL and new_pos == _goal_after_move:
		state.move_goals.erase(merc)

	move_lines.append_array(drop_lines)
	if not drop_taken.is_empty():
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("LEDGE DROP: %s %s F%d->F0 (%d,%d) paces=%d" % [
				merc.merc_name, str(drop_taken["kind"]), old_pos.z, new_pos.x, new_pos.y, int(drop_taken["paces"])])
		_turn_path_cache.erase(merc)
		if flying:
			move_lines.append(_descent_line(merc, int(drop_taken["paces"]), state))
		else:
			move_lines.append_array(CombatApplicator.resolve_fall(merc, int(drop_taken["paces"]), state))
		state.set_height(merc, 0)

	#A walker falls on each step down of a pace or more; a flyer on the ground descends and lands without harm.
	if field != null and not (flying and altitude >= 1):
		for _sf_paces: int in _step_falls:
			if flying:
				move_lines.append(_descent_line(merc, _sf_paces, state))
			else:
				move_lines.append_array(CombatApplicator.resolve_fall(merc, _sf_paces, state))
			state.set_height(merc, 0)

	#A walker standing on an obstacle top steps off it and falls that height.
	if field != null and not flying and altitude >= 1 and new_pos != old_pos:
		move_lines.append_array(CombatApplicator.resolve_fall(merc, altitude, state))
		state.set_height(merc, 0)

	move_lines.append_array(body_traverse_lines)
	for harm: Dictionary in path_harms:
		move_lines.append("  %s moves through %s." % [BattleState.colored_name(merc, state), harm["name"]])
		move_lines.append_array(CombatApplicator.apply_damage(merc, merc, harm["damage"], harm["type"], state))

	var arrow := "<-" if action_name == "Move Far" else "->"
	move_lines.append("  %s %s %s ([color=orange]%d,%d -> %d,%d[/color])" % [
		BattleState.colored_name(merc, state), arrow, BattleState.colored_name(move_target, state),
		old_pos.x, old_pos.y, new_pos.x, new_pos.y])

	#A flyer left mid-band holds the altitude the crossing gave it.
	if _hover_alt >= 0 and _hover_alt != state.get_height(merc):
		var _hvabs := state.absolute_height(merc)
		state.set_height(merc, _hover_alt)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("ALTITUDE: %s h%d -> h%d reason=hover" % [
				merc.merc_name, _hvabs, state.absolute_height(merc)])

	#The flyer ends the move above the tallest thing it flew over.
	if flying and field != null and fly_top > -1.0e8:
		var fly_size := maxi(1, int(merc.stats.get("size", 1)))
		var _oa := state.get_height(merc)
		var _na := maxi(_oa, int(ceil(fly_top - field.cell_base_elevation(new_2d, new_pos.z))))
		var _ce := PathCost.slab_above(new_2d, new_pos.z, field)
		if _ce < PathCost.NO_CEILING:
			_na = mini(_na, maxi(0, int(floor(_ce - field.cell_base_elevation(new_2d, new_pos.z))) - fly_size))
		if _na != _oa:
			var _oabs := state.absolute_height(merc)
			state.set_height(merc, _na)
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("ALTITUDE: %s h%d -> h%d reason=fly_over" % [
					merc.merc_name, _oabs, state.absolute_height(merc)])

	#Leftover pace buys the smallest altitude change that opens line of sight.
	if flying and field != null:
		var remaining_pace := _pace_left
		var cur_h := state.get_height(merc)
		var fly_size := maxi(1, int(merc.stats.get("size", 1)))
		var seen := (LineOfSight.check_from(state, new_pos, cur_h, fly_size, move_target)["visible"] as bool)
		if remaining_pace > 0 and not seen:
			var found := _los_altitude(merc, state, field, new_pos, cur_h, remaining_pace, move_target)
			if found >= 0:
				var _labs := state.absolute_height(merc)
				state.set_height(merc, found)
				state.set_pace_pool(merc, maxi(0, state.get_pace_pool(merc) - absi(found - cur_h)))
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("ALTITUDE: %s h%d -> h%d reason=los" % [
						merc.merc_name, _labs, state.absolute_height(merc)])

	return move_lines


static func execute_jump(
		merc: MercenaryData,
		jump_target_pos: Vector2i,
		jump_target_floor: int,
		action_name: String,
		state: BattleState,
		enhancements: int = 0,
		jump_why: String = "") -> Array[String]:
	if jump_target_pos == Vector2i(-1, -1):
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []
	var merc_floor := state.get_floor(merc)
	if state.is_position_occupied(jump_target_pos, merc, jump_target_floor):
		return []
	var _jsize := int(merc.stats.get("size", 1))
	var _jcell := Vector3i(jump_target_pos.x, jump_target_pos.y, jump_target_floor)
	var _jtop := false
	if state.battlefield != null:
		_jtop = PathHelper.is_top_standable(_jcell, state.battlefield, _jsize)
		var _jstand: bool = _jtop or PathHelper.is_standable(_jcell, state.battlefield, _jsize)
		if not _jstand or not PathCost.has_exit_neighbor(_jcell, state.battlefield, {}, 1.0, false, false, _jsize):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("JUMP REFUSED: %s (%d,%d) F%d why=no_landing" % [
					merc.merc_name, jump_target_pos.x, jump_target_pos.y, jump_target_floor])
			return []

	var lines: Array[String] = []
	var old_pos := state.get_position(merc)
	var field := state.battlefield

	lines.append_array(_advantage_attacks(merc, state, old_pos, jump_target_pos, enhancements))

	state.spend_ap(merc, state.get_cost(merc, action_name, _CONFIG.move_base_ap))
	state.record_action(merc, action_name)
	var _jold_h := state.get_height(merc)
	state.set_position(merc, jump_target_pos)
	if jump_target_floor != merc_floor:
		state.floors[merc] = jump_target_floor
		_turn_path_cache.erase(merc)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FLOOR: %s %d->%d at (%d,%d)" % [
				merc.merc_name, merc_floor, jump_target_floor, jump_target_pos.x, jump_target_pos.y])
	merc.aim_active = false

	var _jnew_h := 0
	if field != null:
		if _jtop:
			_jnew_h = int(ceil(BattlefieldArea.obstacle_height(field.get_obs(jump_target_pos, jump_target_floor))))
		state.set_height(merc, _jnew_h)
		var _jfrom_e := field.cell_base_elevation(old_pos, merc_floor) + float(_jold_h)
		var _jto_e := field.cell_base_elevation(jump_target_pos, jump_target_floor) + float(_jnew_h)
		var _jdrop := _jfrom_e - _jto_e
		if _jdrop >= 1.0:
			lines.append_array(CombatApplicator.resolve_fall(merc, int(floor(_jdrop)), state))

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("JUMP: %s (%d,%d) F%d h%d -> (%d,%d) F%d h%d why=%s" % [
			merc.merc_name, old_pos.x, old_pos.y, merc_floor, _jold_h,
			jump_target_pos.x, jump_target_pos.y, jump_target_floor, _jnew_h, jump_why])

	lines.append("  %s leaps! ([color=orange]%d,%d -> %d,%d[/color])" % [
		BattleState.colored_name(merc, state), old_pos.x, old_pos.y, jump_target_pos.x, jump_target_pos.y])

	return lines


#Pool paces one height of climb costs this climber.
static func climb_pace_cost(merc: MercenaryData) -> int:
	var pp := maxi(1, pace_per_move(merc))
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		return pp
	if int(merc.stats.get("climb", 0)) > 0:
		return 1
	if merc.circumstance_flags.get(ConstCircumstances.ATHLETICS_VIGOR, false):
		return maxi(1, int(ceil(float(pp) / 2.0)))
	return pp


#Banks Moves until the pool holds `need` paces; false when the AP cannot cover them.
static func _climb_fund(merc: MercenaryData, state: BattleState, action_name: String, need: int) -> bool:
	var pool := state.get_pace_pool(merc)
	if pool >= need:
		return true
	var pp := maxi(1, pace_per_move(merc))
	var moves := int(ceil(float(need - pool) / float(pp)))
	var total := 0
	for k: int in range(moves):
		total += state.get_cost_after(merc, action_name, _CONFIG.move_base_ap, k)
	if not state.can_afford(merc, total):
		return false
	for k: int in range(moves):
		_buy_move(merc, state, action_name)
	return true


static func execute_climb(
		merc: MercenaryData,
		decision: Dictionary,
		action_name: String,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var field := state.battlefield
	var is_continuing: bool = ConstStates.has_state(merc, ConstStates.CLIMBING)

	if not is_continuing:
		var target_pos: Vector2i = decision.get("climb_target_pos", Vector2i(-1, -1))
		if target_pos == Vector2i(-1, -1) or field == null:
			return []
		var merc_size := maxi(1, int(merc.stats.get("size", 0)))
		var merc_floor_h := int(round(field.get_terrain_height(state.get_position(merc))))
		#Climb height counts paces above the climber's own cell surface.
		var init_target_h := int(round(field.get_terrain_height(target_pos))) - merc_floor_h
		if init_target_h <= 0:
			var _obs := field.get_obs(target_pos, 0)
			if not _obs.is_empty() and _obs.get("cell_type", "") == "wall":
				init_target_h = 2
		var grab_h := merc_size
		var init_c := climb_pace_cost(merc)
		if not _climb_fund(merc, state, action_name, grab_h * init_c):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("CLIMB REFUSED: %s reason=ap_short" % merc.merc_name)
			return []
		var init_pool := state.get_pace_pool(merc)
		state.set_pace_pool(merc, init_pool - grab_h * init_c)
		state.climbing_data[merc] = {
			"wall_pos": target_pos,
			"current_h": grab_h,
			"target_h": init_target_h,
			"top_pos": target_pos,
		}
		ConstStates.apply_state(merc, ConstStates.CLIMBING, null, "", "engine:climb")
		state.set_height(merc, grab_h)
		merc.aim_active = false
		lines.append("  %s grabs the wall and begins climbing! (alt %d/%d)" % [
			BattleState.colored_name(merc, state), grab_h, init_target_h])
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("CLIMB: %s +%d height (%d/%d) pool %d -> %d" % [
				merc.merc_name, grab_h, grab_h, init_target_h, init_pool, state.get_pace_pool(merc)])
		if grab_h >= init_target_h:
			_complete_climb(merc, state, lines)
		return lines

	var cd: Dictionary = state.get_climbing_data(merc)
	var current_h := int(cd.get("current_h", 0))
	var target_h := int(cd.get("target_h", 0))

	var climb_c := climb_pace_cost(merc)
	var remaining := target_h - current_h
	if remaining > 0 and state.get_pace_pool(merc) < climb_c:
		if not _climb_fund(merc, state, action_name, climb_c):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("CLIMB REFUSED: %s reason=ap_short" % merc.merc_name)
			return []
	var climb_pool := state.get_pace_pool(merc)
	@warning_ignore("integer_division")
	var gained := mini(climb_pool / climb_c, remaining)
	if gained > 0:
		state.set_pace_pool(merc, climb_pool - gained * climb_c)
	var new_h := current_h + maxi(0, gained)
	cd["current_h"] = new_h
	state.climbing_data[merc] = cd
	state.set_height(merc, new_h)
	merc.aim_active = false
	if gained > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("CLIMB: %s +%d height (%d/%d) pool %d -> %d" % [
			merc.merc_name, gained, new_h, target_h, climb_pool, state.get_pace_pool(merc)])

	if new_h >= target_h:
		_complete_climb(merc, state, lines)
	else:
		lines.append("  %s climbs to height %d/%d." % [BattleState.colored_name(merc, state), new_h, target_h])
	return lines


static func _complete_climb(merc: MercenaryData, state: BattleState, lines: Array[String]) -> void:
	var cd: Dictionary = state.get_climbing_data(merc)
	var top_pos: Vector2i = cd.get("top_pos", state.get_position(merc)) as Vector2i
	var pit_pos := state.get_position(merc)
	var merc_floor := state.get_floor(merc)
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	if state.battlefield != null:
		var _obs := state.battlefield.get_obs(top_pos, merc_floor)
		if not _obs.is_empty() and _obs.get("cell_type", "") == "wall":
			var wall_pos: Vector2i = cd.get("wall_pos", top_pos) as Vector2i
			var _dir := Vector2i(signi(wall_pos.x - pit_pos.x), signi(wall_pos.y - pit_pos.y))
			var _beyond := wall_pos + _dir
			if state.battlefield.get_nav_passable_cells().has(_beyond) and not state.is_position_occupied(_beyond, merc, merc_floor):
				top_pos = _beyond
	if not state.is_position_occupied(top_pos, merc, merc_floor):
		state.set_position(merc, top_pos)
	if state.battlefield != null:
		state.set_height(merc, 0)
	lines.append("  %s hauls themselves up!" % BattleState.colored_name(merc, state))


static func execute_move_to_pos(
		merc: MercenaryData,
		target_pos: Vector2i,
		state: BattleState,
		enhancements: int = 0) -> Array[String]:
	if state.battlefield == null:
		return []
	var old_pos := state.get_position(merc)
	if old_pos == target_pos:
		return []
	#An empty pool has to buy a Move, but only once a step is known to be possible.
	var buy_first := state.get_pace_pool(merc) <= 0
	if buy_first and not state.can_afford(merc, state.get_cost(merc, "Move Close", _CONFIG.move_base_ap)):
		return []
	var budget: int = pace_per_move(merc) if buy_first else state.get_pace_pool(merc)
	var dx := target_pos.x - old_pos.x
	var dy := target_pos.y - old_pos.y
	var step := Vector2i(signi(dx), signi(dy))
	var dist := maxi(abs(dx), abs(dy))
	var steps := mini(budget, dist)
	var merc_floor := state.get_floor(merc)
	var new_pos := state.battlefield.clamp_position(old_pos + step * steps)
	if new_pos == old_pos:
		return []
	while new_pos != old_pos and state.is_position_occupied(new_pos, merc, merc_floor):
		steps -= 1
		if steps <= 0:
			return []
		new_pos = state.battlefield.clamp_position(old_pos + step * steps)
	if state.is_position_occupied(new_pos, merc, merc_floor):
		return []
	if buy_first:
		_buy_move(merc, state, "Move Close")
	state.set_pace_pool(merc, maxi(0, state.get_pace_pool(merc) - steps))
	var move_lines: Array[String] = []
	move_lines.append_array(_advantage_attacks(merc, state, old_pos, new_pos, enhancements))
	state.set_position(merc, new_pos)
	merc.aim_active = false
	move_lines.append("  %s -> weapon ([color=orange]%d,%d -> %d,%d[/color])" % [
		BattleState.colored_name(merc, state), old_pos.x, old_pos.y, new_pos.x, new_pos.y])
	return move_lines


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
		[], [], decision.get("goal_cell", PathTargeter.NO_CELL) as Vector3i)
	state.move_plan.erase(merc)
	if move_lines.is_empty():
		if _pool_before > 0:
			state.set_pace_pool(merc, 0)
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("POOL CLEARED: %s no step possible" % merc.merc_name)
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
	var jump_lines := MovementExecutor.execute_jump(
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
	var climb_lines := MovementExecutor.execute_climb(merc, decision, decision["action_name"], state)
	if climb_lines.is_empty():
		turn["movement_blocked"] = true
	else:
		_movement_succeeded(merc, turn, climb_lines, lines)
	return lines


#Walk toward a dropped weapon; a refusal blacklists the cell for the rest of the turn.
static func run_move_to_pickup_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var mv_lines := MovementExecutor.execute_move_to_pos(merc, decision["weapon_pos"], state, enhancements)
	if mv_lines.is_empty():
		turn["movement_blocked"] = true
		merc.active_states["blocked_pickup_pos"] = decision["weapon_pos"]
	else:
		lines.append_array(mv_lines)
		turn["movement_blocked"] = false
		turn["weapon_action_taken"] = true
	return lines


#Walk toward an obstacle the merc means to break.
static func run_move_to_obstacle_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var mo_lines := MovementExecutor.execute_move_to_pos(merc, decision["obstacle_pos"], state, enhancements)
	if mo_lines.is_empty():
		turn["movement_blocked"] = true
	else:
		lines.append_array(mo_lines)
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
