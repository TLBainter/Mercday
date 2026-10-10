class_name MovementExecutor

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

static var _turn_path_cache: Dictionary = {}
static var _blocked_path_goals: Dictionary = {}

const _SCAN_DEAD := 0
const _SCAN_DEPOSED := 1
const _SCAN_ALLY := 2


#State one Move carries from its goal through the plan and the walk to its close.
class WalkContext extends RefCounted:
	var merc: MercenaryData
	var state: BattleState
	var field: BattlefieldArea
	var action_name: String = ""
	var move_target: MercenaryData
	var seeking: bool = false
	var old_pos: Vector3i
	var altitude: int = 0
	var flying: bool = false
	var known_enemies: Dictionary = {}
	var goal: Vector3i
	var ally_passable: Dictionary = {}
	var fall_tolerance: float = 1.0
	var can_climb: bool = true
	var merc_size: int = 1
	var path: Array[Vector3i] = []
	var path_start_idx: int = 0
	var pool_start: int = 0
	var buy: Dictionary = {}
	var traversed: Array[Vector3i] = []
	#Which traversed cell produced each harm and each narration line, so both
	#can be dropped when the mover is pushed back off a cell it cannot stand on.
	var harm_at: Array[int] = []
	var body_at: Array[int] = []
	#Pace charged to enter each traversed cell; a push-back never gives it back.
	var cost_at: Array[int] = []
	var path_harms: Array[Dictionary] = []
	var body_traverse_lines: Array[String] = []
	#A drop resolved early so the drop re-plan can read the landing state.
	var drop_lines: Array[String] = []
	#Paces of every same-floor step down of a pace or more, resolved as falls after the walk.
	var step_falls: Array[int] = []
	var new_pos: Vector3i
	#Why the mover ended where it started, for the MOVE STALLED line.
	var stall_why: String = "no_path"
	var stall_path: String = ""
	#Pace not spent on the traversal; a flyer may spend it on an altitude change.
	var pace_left: int = 0
	#Altitude a flyer holds when its paces ran out over a flyover cell; -1 when it landed.
	var hover_alt: int = -1
	var drop_taken: Dictionary = {}
	var floor_change: Vector3i = PathTargeter.NO_CELL
	#Highest absolute obstacle top the mover flew over on this move.
	var fly_top: float = -1.0e9
	#Cell a kidnapped captive is pulled into: the last cell the captor leaves on this move.
	var drag_from: Vector3i
	var move_lines: Array[String] = []


static func clear_caches() -> void:
	_turn_path_cache.clear()
	_blocked_path_goals.clear()
	ReachCache.clear_caches()


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


static func forget_turn_path(merc: MercenaryData) -> void:
	_turn_path_cache.erase(merc)


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
	var alt := PathCost.fly_arrival_altitude(path[idx - 1], path[idx], field, altitude, merc_size)
	for j: int in range(idx + 1, path.size()):
		var step := PathCost.cell_pace_cost(prev, path[j], field, passable, fall_tolerance, true, can_climb, merc_size, alt)
		if step < 0:
			return -1
		need += step
		alt = PathCost.fly_arrival_altitude(prev, path[j], field, alt, merc_size)
		prev = path[j]
		if PathHelper.is_standable(path[j], field, merc_size) and (is_free.call(path[j]) as bool):
			return need
	return -1


#A walker ends a move on a standable cell; a flyer may also hover over a flyover cell.
static func can_end_on(cell: Vector3i, field: BattlefieldArea, merc_size: int, flying: bool) -> bool:
	if PathHelper.is_standable(cell, field, merc_size):
		return true
	return flying and PathCost.is_flyover_cell(cell, field)


#First merc on pos in the scanned pool: a dead body or a live Deposed merc among all placed mercs
#(_SCAN_DEAD, _SCAN_DEPOSED), or a live standing ally of merc (_SCAN_ALLY).
static func _occupant_at(pos: Vector3i, state: BattleState, mode: int, merc: MercenaryData = null) -> MercenaryData:
	var pool: Array
	if mode == _SCAN_ALLY:
		pool = state.get_allies(merc)
	else:
		pool = state.positions.keys()
	for m: MercenaryData in pool:
		var hit: bool
		if mode == _SCAN_DEAD:
			hit = m.is_dead
		elif mode == _SCAN_DEPOSED:
			hit = BattleState._is_alive(m) and ConstStates.has_state(m, ConstStates.DEPOSED)
		else:
			hit = BattleState._is_alive(m) and not ConstStates.has_state(m, ConstStates.DEPOSED)
		if hit and state.pos3(m) == pos:
			return m
	return null


static func _get_standing_ally_at(pos: Vector3i, merc: MercenaryData, state: BattleState) -> MercenaryData:
	return _occupant_at(pos, state, _SCAN_ALLY, merc)


#Extra pace for passing over a body or a prone merc at least the mover's size.
static func _surcharge(dead_body: MercenaryData, deposed_merc: MercenaryData, merc_size: int) -> int:
	var extra := 0
	if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
		extra += 1
	if deposed_merc != null and int(deposed_merc.stats.get("size", 1)) >= merc_size:
		extra += 1
	return extra


#Raises the round a goal cell stays blocked through; a later round already stored is kept.
static func _raise_blocked(key: Vector3i, level: int) -> void:
	if (_blocked_path_goals.get(key, 0) as int) < level:
		_blocked_path_goals[key] = level


#Records this round that the mover cannot close on move_target; record_target false marks only the merc.
static func _mark_blocked(merc: MercenaryData, move_target: MercenaryData, state: BattleState,
		record_target: bool = true) -> void:
	if record_target:
		var blocked: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
		blocked[move_target] = state.round_number
		state.movement_blocked[merc] = blocked
	merc.active_states["_move_blocked_round"] = state.round_number


#In-bounds cells of the eight around center, in DIRS8 order.
static func _ring8(center: Vector3i, field: BattlefieldArea) -> Array[Vector3i]:
	var ring: Array[Vector3i] = []
	for d: Vector2i in PathCost.DIRS8:
		var c := Vector3i(center.x + d.x, center.y + d.y, center.z)
		if not field.in_bounds_xy(c.x, c.y):
			continue
		ring.append(c)
	return ring


#Altitude a flyer holds after flying the traversed cells from `alt`.
static func _replay_altitude(traversed: Array[Vector3i], field: BattlefieldArea, alt: int, merc_size: int) -> int:
	for i: int in range(1, traversed.size()):
		alt = PathCost.fly_arrival_altitude(traversed[i - 1], traversed[i], field, alt, merc_size)
	return alt


static func _log_ledge_drop(merc: MercenaryData, drop_taken: Dictionary, old_z: int, new_pos: Vector3i) -> void:
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("LEDGE DROP: %s %s F%d->F%d (%d,%d) paces=%d" % [
			merc.merc_name, str(drop_taken["kind"]), old_z, new_pos.z, new_pos.x, new_pos.y,
			int(drop_taken["paces"])])


static func compute_move_position(
		merc: MercenaryData,
		move_target: MercenaryData,
		action_name: String,
		state: BattleState,
		flank_ally: MercenaryData = null,
		stop_dist_override: int = -1,
		enemies: Array[MercenaryData] = []) -> Vector3i:
	if action_name == "Move Far":
		return PathTargeter.best_retreat_cell(merc, enemies, state, move_target)
	#A ranged unit that scored a roof post walks to its foot instead of closing on the enemy.
	var post: Vector3i = RoofPostScore.goal_cell(merc, state)
	if post != PathTargeter.NO_CELL and state.get_enemies(merc).has(move_target):
		return post
	return PathTargeter.best_approach_cell(merc, move_target, state, flank_ally, stop_dist_override)


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
		c += _surcharge(_occupant_at(path[i - 1], state, _SCAN_DEAD),
			_occupant_at(path[i - 1], state, _SCAN_DEPOSED), merc_size)
		total += c
		if flying:
			alt = PathCost.fly_arrival_altitude(path[i - 1], path[i], field, alt, merc_size)
	return total


#The single re-plan a Move may take: a fresh route from `from_cell` that avoids `blocked`.
#`require_goal` refuses the route unless it reaches the goal on the pace left.
static func _replan_move(ctx: WalkContext, reason: String, from_cell: Vector3i, blocked: Dictionary,
		budget: int, start_alt: int, require_goal: bool, rejected: Dictionary) -> Dictionary:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var goal := ctx.goal
	var ally_passable := ctx.ally_passable
	var fall_tolerance := ctx.fall_tolerance
	var flying := ctx.flying
	var can_climb := ctx.can_climb
	var merc_size := ctx.merc_size
	var traversed := ctx.traversed
	var body_at := ctx.body_at
	var body_traverse_lines := ctx.body_traverse_lines
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
	var rp_need := 0
	var rp_alt := start_alt
	for rk: int in range(1, rp_path.size()):
		var c := PathCost.cell_pace_cost(rp_path[rk - 1], rp_path[rk], field, ally_passable, fall_tolerance,
			flying, can_climb, merc_size, rp_alt)
		if c < 0:
			break
		c += _surcharge(_occupant_at(rp_path[rk - 1], state, _SCAN_DEAD),
			_occupant_at(rp_path[rk - 1], state, _SCAN_DEPOSED), merc_size)
		rp_need += c
		if rp_need > budget:
			break
		if flying:
			rp_alt = PathCost.fly_arrival_altitude(rp_path[rk - 1], rp_path[rk], field, rp_alt, merc_size)
		rp_reach = rp_path[rk]
	if traversed.has(rp_reach):
		return res
	var rp_kept := traversed.size() - 1
	var rp_lines := body_traverse_lines.size()
	var rp_walk := _walk(ctx, rp_path, 0, budget, from_cell, start_alt,
		PathTargeter.is_flanked_by_known(from_cell, ctx.known_enemies))
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
		if not can_end_on(t2, field, merc_size, flying):
			continue
		rp_end = t2
		break
	var end_idx := traversed.find(rp_end)
	var pushed := _trim_to(end_idx, traversed, ctx.cost_at, ctx.harm_at, body_at, ctx.path_harms,
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


#Advantage Attacks the movers leaving melee range trigger, with their narration lines.
static func advantage_attacks(merc: MercenaryData, state: BattleState, from2d: Vector2i,
		to2d: Vector2i, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if merc.advantage_immune:
		return lines
	var triggered: Array = ReactiveActionSystem.get_triggered_reactions(
		"enemy_leaves_melee_range", merc, from2d, to2d, state)
	for entry: Dictionary in triggered:
		var reactor: MercenaryData = entry["reactor"]
		lines.append_array(CombatApplicator.reaction_attack(reactor, merc, state, enhancements, 0))
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
	var dead_body := _occupant_at(from_cell, state, _SCAN_DEAD)
	var deposed_merc := _occupant_at(from_cell, state, _SCAN_DEPOSED)
	if cost >= 0:
		if door:
			cost -= PathCost.door_pace_penalty
		cost += _surcharge(dead_body, deposed_merc, merc_size)
	return {"cost": cost, "door": door, "body": dead_body, "deposed": deposed_merc}


#Cell the walk would end on with the pool and the Moves it may still buy; the start cell when it would not move.
static func _dry_walk_end(ctx: WalkContext, path: Array[Vector3i], path_start_idx: int, budget: int,
		start_cell: Vector3i, cur_alt: int, start_flanked: bool) -> Vector3i:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var goal := ctx.goal
	var ally_passable := ctx.ally_passable
	var fall_tolerance := ctx.fall_tolerance
	var flying := ctx.flying
	var can_climb := ctx.can_climb
	var merc_size := ctx.merc_size
	var buy := ctx.buy
	var known := ctx.known_enemies
	var sim: Dictionary = buy.duplicate()
	sim["dry"] = true
	var end := start_cell
	var alt := cur_alt
	var occ_seen := false
	for i: int in range(path_start_idx + 1, path.size()):
		var from_cell: Vector3i = path[i - 1]
		var cell: Vector3i = path[i]
		#The Climb action takes the link, so the walk it is planned into ends on the foot cell.
		if not PathCost.climb_step(from_cell, cell, field, flying, fall_tolerance, merc_size).is_empty():
			break
		#The Jump action takes the roof leap, so the walk it is planned into ends on the take-off cell.
		if not PathJump.roof_jump_step(from_cell, cell, field, flying, merc_size).is_empty():
			break
		var price := _step_price(state, field, path, i, alt, ally_passable, fall_tolerance,
			flying, can_climb, merc_size)
		var cost := int(price["cost"])
		var door: bool = price["door"]
		if cost < 0:
			break
		if cell != goal and not start_flanked and PathTargeter.is_flanked_by_known(cell, known):
			break
		if budget < cost:
			sim["door_reserve"] = _door_reserve_ahead(merc, state, field, path, i, goal, PaceBudget.purchase_reach(merc, budget, cost))
			var need := PaceBudget.fund_need(merc, state, sim, budget, cost)
			if need < 0:
				break
			budget += need * PaceBudget.pace_per_move(merc)
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
			alt = PathCost.fly_arrival_altitude(from_cell, cell, field, alt, merc_size)
		if can_end_on(cell, field, merc_size, flying):
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


#Positional entry to _walk for a caller that holds no WalkContext.
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
		known_enemies: Dictionary,
		start_flanked: bool,
		traversed: Array[Vector3i],
		cost_at: Array[int],
		harm_at: Array[int],
		body_at: Array[int],
		path_harms: Array[Dictionary],
		body_traverse_lines: Array[String],
		buy: Dictionary) -> Dictionary:
	var ctx := WalkContext.new()
	ctx.merc = merc
	ctx.state = state
	ctx.field = field
	ctx.goal = goal
	ctx.ally_passable = ally_passable
	ctx.fall_tolerance = fall_tolerance
	ctx.flying = flying
	ctx.can_climb = can_climb
	ctx.merc_size = merc_size
	ctx.known_enemies = known_enemies
	ctx.traversed = traversed
	ctx.cost_at = cost_at
	ctx.harm_at = harm_at
	ctx.body_at = body_at
	ctx.path_harms = path_harms
	ctx.body_traverse_lines = body_traverse_lines
	ctx.buy = buy
	return _walk(ctx, path, path_start_idx, budget, start_cell, cur_alt, start_flanked)


#Walks one planned path, charging pace per cell and collecting harms, narration and any
#drop taken. Shared by the first walk and by the re-plan that follows a push-back.
static func _walk(ctx: WalkContext, path: Array[Vector3i], path_start_idx: int, budget: int,
		start_cell: Vector3i, cur_alt: int, start_flanked: bool) -> Dictionary:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var goal := ctx.goal
	var ally_passable := ctx.ally_passable
	var fall_tolerance := ctx.fall_tolerance
	var flying := ctx.flying
	var can_climb := ctx.can_climb
	var merc_size := ctx.merc_size
	var known_enemies := ctx.known_enemies
	var traversed := ctx.traversed
	var cost_at := ctx.cost_at
	var harm_at := ctx.harm_at
	var body_at := ctx.body_at
	var path_harms := ctx.path_harms
	var body_traverse_lines := ctx.body_traverse_lines
	var buy := ctx.buy
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
	#The mover sank into a pool on this walk and stops where it stands.
	var _sank := false
	#Climb link the walk halted at the foot of, with that foot cell; the Climb action takes it.
	var _climb_route: Dictionary = {}
	#Roof leap the walk halted at the take-off of, with that cell; the Jump action takes it.
	var _jump_route: Dictionary = {}
	var _is_free := func(c: Vector3i) -> bool:
		return not state.is_position_occupied(Vector2i(c.x, c.y), merc, c.z)
	for i: int in range(path_start_idx + 1, path.size()):
		var from_cell: Vector3i = path[i - 1]
		var cell: Vector3i = path[i]
		var climb_here: Dictionary = PathCost.climb_step(from_cell, cell, field, flying, fall_tolerance, merc_size)
		if not climb_here.is_empty():
			climb_here["foot"] = from_cell
			_climb_route = climb_here
			break
		var jump_here: Dictionary = PathJump.roof_jump_step(from_cell, cell, field, flying, merc_size)
		if not jump_here.is_empty():
			jump_here["foot"] = from_cell
			_jump_route = jump_here
			break
		var price := _step_price(state, field, path, i, cur_alt, ally_passable, fall_tolerance,
			flying, can_climb, merc_size)
		var cost := int(price["cost"])
		var door: bool = price["door"]
		var dead_body: MercenaryData = price["body"]
		var deposed_merc: MercenaryData = price["deposed"]
		if cost < 0:
			break
		if cell != goal and not start_flanked and PathTargeter.is_flanked_by_known(cell, known_enemies):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("[MOVE] flanked-abort: %s at (%d,%d)" % [merc.merc_name, cell.x, cell.y])
			_flanked_abort_cell = cell
			_flanked_abort_fired = true
			break
		if budget < cost:
			buy["door_reserve"] = _door_reserve_ahead(merc, state, field, path, i, goal, PaceBudget.purchase_reach(merc, budget, cost))
		var funded := PaceBudget.fund_step(merc, state, buy, budget, cost)
		if funded < 0:
			_pool_stop = true
			break
		budget = funded
		if door and not _open_door_in_stride(merc, state, field, cell, traversed, body_at, body_traverse_lines):
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
			cur_alt = PathCost.fly_arrival_altitude(from_cell, cell, field, cur_alt, merc_size)
		if dead_body != null and int(dead_body.stats.get("size", 1)) >= merc_size:
			body_traverse_lines.append("  %s moves through the body of %s." % [BattleState.colored_name(merc, state), dead_body.merc_name])
			body_at.append(traversed.size() - 1)
		if deposed_merc != null:
			body_traverse_lines.append("  %s steps over the prone %s." % [BattleState.colored_name(merc, state), deposed_merc.merc_name])
			body_at.append(traversed.size() - 1)
		var traversed_ally := _get_standing_ally_at(from_cell, merc, state)
		if traversed_ally != null:
			body_traverse_lines.append("  %s passes through %s's position." % [BattleState.colored_name(merc, state), traversed_ally.merc_name])
			body_at.append(traversed.size() - 1)
		last = cell
		traversed.append(cell)
		cost_at.append(cost)
		if field.is_cavern:
			var cavern_lines: Array[String] = []
			var sank := CavernRules.on_enter_cell(merc, Vector2i(from_cell.x, from_cell.y),
				Vector2i(cell.x, cell.y), state, cavern_lines)
			for cl: String in cavern_lines:
				body_traverse_lines.append(cl)
				body_at.append(traversed.size() - 1)
			if sank:
				_sank = true
				break
		if from_cell.z != cell.z and floor_change_cell == PathTargeter.NO_CELL:
			floor_change_cell = cell
		var path_obs: Dictionary = field.get_obs(Vector2i(cell.x, cell.y), cell.z)
		if not path_obs.is_empty():
			var d: ObstacleData = path_obs.get("data") as ObstacleData
			if d != null and d.passthrough and d.pt_enter_harm > 0:
				path_harms.append({"damage": d.pt_enter_harm, "type": d.pt_harm_type, "name": d.obstacle_name})
				harm_at.append(traversed.size() - 1)
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
		"sank": _sank,
		"climb_route": _climb_route,
		"jump_route": _jump_route,
	}


#Smallest altitude change within budget that opens line of sight to target; -1 when none does.
static func _los_altitude(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		pos: Vector3i, cur_h: int, budget: int, target: MercenaryData) -> int:
	if field == null or target == null or budget <= 0:
		return -1
	var fly_size := merc.unit_size()
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
	#Run for its effect: it sets this mover's door surcharge and grows its flood to two turns of Pace.
	ReachCache.reachable_for(merc, state)
	#The goal and the window nearest_passable_to scans are grown past the two-turn bound.
	var _reach: Dictionary = ReachCache.reachable_around_for(merc, state, _raw_goal)
	var _mover := {"fall_tolerance": fall_tolerance, "can_climb": can_climb, "merc_size": move_size,
		"flying": flying, "altitude": altitude, "state": state, "merc": merc}
	goal = PathHelper.nearest_passable_to(_raw_goal, field, _mover, {}, _reach, old_pos,
		PathTargeter.JUMP_COST_OFFSET - 1)
	if goal != _raw_goal and EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE GOAL ADJUST: (%d,%d)->(%d,%d) reason=%s" % [
			_raw_goal.x, _raw_goal.y, goal.x, goal.y,
			MoveDiagnostics.goal_adjust_reason(_raw_goal, field, state, merc)])
	if _blocked_path_goals.has(goal):
		if (_blocked_path_goals[goal] as int) >= state.round_number:
			var _excl: Dictionary = {}
			for _bg: Vector3i in _blocked_path_goals:
				if (_blocked_path_goals[_bg] as int) >= state.round_number:
					_excl[_bg] = true
			#The goal itself is excluded here, so the cells around it are grown to.
			_reach = ReachCache.reachable_around_for(merc, state, _raw_goal, true)
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
		move_target: MercenaryData, old_pos: Vector3i, goal: Vector3i, raw_goal: Vector3i,
		reach: Dictionary, seeking: bool, ally_passable: Dictionary, fall_tolerance: float,
		flying: bool, can_climb: bool, jump_stat: int, move_size: int, altitude: int,
		known_enemies: Dictionary) -> Dictionary:
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
		var _flank_blocked := PathTargeter.flanked_cells(old_pos, goal, field, known_enemies)
		#The flood's own walk path serves unless it crosses a flanked cell; A* stays for the blocked and empty cases.
		var _flood_path := ReachCache.walk_path_for(merc, state, old_pos, goal)
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
							MoveDiagnostics.partial_reason(goal, reach)])
				else:
					var _alt_path: Array[Vector3i] = []
					var _alt_best_dist := 999999
					for _ag: Vector3i in _ring8(raw_goal, field):
						if _blocked_path_goals.has(_ag) and (_blocked_path_goals[_ag] as int) >= state.round_number:
							continue
						var _ap: Array[Vector3i] = PathHelper.find_path_toward(old_pos, _ag, field, ally_passable, fall_tolerance, flying, can_climb, jump_stat, move_size, altitude)
						if not _ap.is_empty():
							var _ad_dist := maxi(abs(_ap[-1].x - raw_goal.x), abs(_ap[-1].y - raw_goal.y))
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
							old_pos, raw_goal, field, state.nav_passable_3d(),
							fall_tolerance, flying, can_climb, jump_stat, move_size, altitude)
						_blocked_path_goals[goal] = state.round_number + (1000 if _static_path.is_empty() else 0)
						if _static_path.is_empty():
							_mark_blocked(merc, move_target, state)
						if EncounterLogger.is_active():
							EncounterLogger.log_verbose("MOVE BLOCKED: no path (%d,%d)->(%d,%d)" % [
								old_pos.x, old_pos.y, goal.x, goal.y])
		if not path.is_empty() and goal.z != old_pos.z and EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE ROUTE: %s len=%d door_pen=%d %s" % [
				merc.merc_name, path.size(), PathCost.door_pace_penalty, MoveDiagnostics.route_summary(path, field)])
		if not path.is_empty() and not seeking:
			_turn_path_cache[merc] = {"goal": goal, "path": path, "idx": 0}
	return {"path": path, "start_idx": path_start_idx, "blocked": blocked}


#Push-back trim, the one re-plan and the pool bookkeeping that close a walk.
#Writes the walk outcome to ctx; true when the Move ends here with nothing to narrate.
static func _finish_walk(ctx: WalkContext, walk: Dictionary) -> bool:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var path := ctx.path
	var path_start_idx := ctx.path_start_idx
	var old_pos := ctx.old_pos
	var goal := ctx.goal
	var move_target := ctx.move_target
	var altitude := ctx.altitude
	var flying := ctx.flying
	var merc_size := ctx.merc_size
	var traversed := ctx.traversed
	var cost_at := ctx.cost_at
	var harm_at := ctx.harm_at
	var body_at := ctx.body_at
	var path_harms := ctx.path_harms
	var body_traverse_lines := ctx.body_traverse_lines
	var drop_lines := ctx.drop_lines
	var step_falls := ctx.step_falls
	var buy := ctx.buy
	var pool_start := ctx.pool_start
	var fly_top := ctx.fly_top
	var new_pos := old_pos
	var _stall_why := "no_path"
	var _stall_path := ""
	var _door_no_step := false
	var _hover_alt := -1
	var _pace_left := 0
	var budget := walk["budget"] as int
	var last := walk["last"] as Vector3i
	var drop_taken: Dictionary = walk["drop_taken"] as Dictionary
	var drop_cell: Vector3i = walk["drop_cell"] as Vector3i
	var floor_change_cell: Vector3i = walk["floor_change"] as Vector3i
	var _band_stop := walk["band_stop"] as bool
	var _band_need := walk["band_need"] as int
	var _band_budget := walk["band_budget"] as int
	var _band_cells: Array[Vector3i] = walk["band_cells"] as Array[Vector3i]
	var _flanked_abort_fired := walk["flanked_fired"] as bool
	var _flanked_abort_cell := walk["flanked_cell"] as Vector3i
	var _door_stop := walk["door_stop"] as Vector3i
	var _pool_stop := walk["pool_stop"] as bool
	#Paces charged on the first walk, for the MOVE PATH line.
	var _planned := pool_start + int(buy["bought"]) * PaceBudget.pace_per_move(merc) - budget
	for k: int in range(traversed.size() - 1, 0, -1):
		var _tk: Vector3i = traversed[k]
		if state.is_position_occupied(Vector2i(_tk.x, _tk.y), merc, _tk.z):
			continue
		if not can_end_on(_tk, field, merc_size, flying):
			continue
		last = _tk
		break
	new_pos = last
	if not can_end_on(new_pos, field, merc_size, flying):
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
	var _pushed := _trim_to(_kept, traversed, cost_at, harm_at, body_at, path_harms,
		body_traverse_lines, _rejected)
	budget += _pushed
	if not drop_taken.is_empty() and new_pos != drop_cell:
		drop_taken = {}
	#Altitude the mover holds on the cell the walk left it on.
	var _rp_alt := altitude
	if flying:
		_rp_alt = _replay_altitude(traversed, field, altitude, merc_size)
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
	#A mover on the bottom of a pool takes no further route this Move.
	if walk.get("sank", false):
		_rp_reason = ""
	#A walk halted at the foot of a climb ends here; the Climb action takes the link next.
	if not (walk.get("climb_route", {}) as Dictionary).is_empty():
		_rp_reason = ""
	#A walk halted on a roof leap take-off cell ends here; the Jump action takes the leap next.
	if not (walk.get("jump_route", {}) as Dictionary).is_empty():
		_rp_reason = ""
	if _rp_reason != "" and (budget <= 0 or new_pos == goal):
		_rp_reason = ""
	if _rp_reason == "drop":
		#The fall lands before the re-plan so its damage and any Deposed count.
		_log_ledge_drop(merc, drop_taken, old_pos.z, new_pos)
		_turn_path_cache.erase(merc)
		drop_lines.append_array(FallResolver.resolve_fall(merc, int(drop_taken["paces"]), state))
		state.set_height(merc, 0)
		drop_taken = {}
		_rp_alt = 0
		if not BattleState._is_alive(merc) or ConstStates.has_state(merc, ConstStates.DEPOSED):
			_rp_reason = ""
	if _rp_reason != "":
		var _rp_from := new_pos
		var _rp: Dictionary = _replan_move(ctx, _rp_reason, new_pos, _rp_blocked, budget, _rp_alt,
			_rp_require_goal, _rejected)
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
		_raise_blocked(_rc, state.round_number)
	#Paces left at a door the mover cannot open are forfeited; no later Move retries the door.
	if budget > 0 and _door_stop != PathTargeter.NO_CELL \
			and state.pending_interact.get(merc, PathTargeter.NO_CELL) == _door_stop \
			and not state.can_afford(merc, state.get_cost(merc, "Interact", 2)):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("POOL DROPPED: %s %d paces at closed door (%d,%d)" % [
				merc.merc_name, budget, _door_stop.x, _door_stop.y])
		budget = 0
	state.set_pace_pool(merc, maxi(0, budget))
	var _why := str(buy.get("why", ""))
	if _pool_stop and _why != "moves_spent" and new_pos != old_pos and new_pos != goal \
			and EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE PARTIAL: %s stopped at (%d,%d) reason=pool_empty why=%s pool=%d" % [
			merc.merc_name, new_pos.x, new_pos.y, _why, maxi(0, budget)])
	if _door_no_step and new_pos == old_pos:
		_walk_outcome(ctx, new_pos, _stall_why, _stall_path, drop_taken, floor_change_cell, fly_top, _hover_alt, _pace_left)
		return true
	#A flyer that ran out of paces mid-band holds the altitude it crossed it with.
	if flying and new_pos != old_pos and not PathHelper.is_standable(new_pos, field, merc_size):
		_hover_alt = _replay_altitude(traversed, field, altitude, merc_size)
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
		_raise_blocked(goal, state.round_number + 3)
	if _flanked_abort_fired and new_pos == old_pos and _flanked_abort_cell != PathTargeter.NO_CELL:
		var _fa_tpos := state.pos3(move_target)
		if Vector2i(_fa_tpos.x, _fa_tpos.y) != Vector2i(-1, -1):
			for _fac: Vector3i in _ring8(_fa_tpos, field):
				_raise_blocked(_fac, state.round_number + 3)
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
			step_falls.append(int(floor(_sf_drop)))
	if EncounterLogger.is_active() and traversed.size() > 1:
		var parts: Array[String] = []
		for c: Vector3i in traversed:
			parts.append("(%d,%d)" % [c.x, c.y])
		var _avail := pool_start + int(buy["bought"]) * PaceBudget.pace_per_move(merc)
		EncounterLogger.log_verbose("MOVE PATH: %s  planned %d, pushed back %d, moved %d of %d pool=%d" % [
			" -> ".join(parts), _planned, _pushed, _avail - budget, _avail, maxi(0, budget)])
	_walk_outcome(ctx, new_pos, _stall_why, _stall_path, drop_taken, floor_change_cell, fly_top, _hover_alt, _pace_left)
	return false


static func _walk_outcome(ctx: WalkContext, new_pos: Vector3i, stall_why: String, stall_path: String,
		drop_taken: Dictionary, floor_change: Vector3i, fly_top: float, hover_alt: int, pace_left: int) -> void:
	ctx.new_pos = new_pos
	ctx.stall_why = stall_why
	ctx.stall_path = stall_path
	ctx.drop_taken = drop_taken
	ctx.floor_change = floor_change
	ctx.fly_top = fly_top
	ctx.hover_alt = hover_alt
	ctx.pace_left = pace_left


#Cell a flank step around an oscillation block reaches, or NO_CELL when none is affordable.
static func _oscillation_flank(merc: MercenaryData, state: BattleState, field: BattlefieldArea,
		move_target: MercenaryData, old_pos: Vector3i, altitude: int, flying: bool,
		hist: Array) -> Vector3i:
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
			var _fb := PaceBudget.pace_per_move(merc)
			var _fn := old_pos
			for _fi: int in range(1, _fp.size()):
				var _fc := PathCost.cell_pace_cost(_fp[_fi - 1], _fp[_fi], field, {}, _fall_tol, flying, _can_cl, _osc_size, altitude)
				if _fc < 0 or _fb - _fc < 0:
					break
				_fb -= _fc
				_fn = _fp[_fi]
			if _fn == old_pos or hist.has(Vector2i(_fn.x, _fn.y)):
				continue
			if not PathHelper.is_standable(_fn, field, _osc_size):
				continue
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("OSCILLATION FLANK: %s flanking to (%d,%d)" % [merc.merc_name, _fn.x, _fn.y])
			return _fn
	return PathTargeter.NO_CELL


#True when the mover can only strike in melee: no weapon, a melee weapon, or a ranged weapon with an empty chamber.
static func _melee_only(merc: MercenaryData) -> bool:
	var w: WeaponData = merc.equipped_weapon
	if w == null:
		return true
	if w.is_throwable:
		return false
	return not w.is_ranged or merc.ammo_loaded <= 0


#True when the shooter's chamber is empty but its inventory still holds the loaded ammo type.
static func _carries_ammo(merc: MercenaryData) -> bool:
	var w: WeaponData = merc.equipped_weapon
	if w == null or not w.is_ranged or merc.ammo_loaded > 0:
		return false
	return int(merc.ammo_inventory.get(merc.ammo_loaded_type, 0)) > 0


#Records that the mover cannot close on a target above it and logs the one MOVE UNREACHABLE line.
static func _mark_unreachable(merc: MercenaryData, move_target: MercenaryData, state: BattleState,
		reach: int, gap: int) -> void:
	var reloadable := _carries_ammo(merc)
	_mark_blocked(merc, move_target, state, not reloadable)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("MOVE UNREACHABLE: %s under %s h%d dist=%d reach=%d%s" % [
			merc.merc_name, move_target.merc_name, state.absolute_height(move_target), gap, reach,
			" reloadable" if reloadable else ""])


#True while a stored move block still holds; a target now inside melee reach may be picked again.
static func move_block_holds(merc: MercenaryData, target: MercenaryData, state: BattleState,
		marked_round: int) -> bool:
	if merc == null or target == null or state == null:
		return true
	if marked_round >= state.round_number:
		return true
	var mp := state.get_position(merc)
	var tp := state.get_position(target)
	if mp == Vector2i(-1, -1) or tp == Vector2i(-1, -1):
		return true
	var reach := WeaponArmorPerkLibrary.melee_reach(merc)
	if maxi(absi(mp.x - tp.x), absi(mp.y - tp.y)) > reach:
		return true
	return absi(state.absolute_height(target) - state.absolute_height(merc)) > reach


static func execute_move(
		merc: MercenaryData,
		action_name: String,
		move_target: MercenaryData,
		state: BattleState,
		flank_ally: MercenaryData = null,
		enhancements: int = 0,
		stop_dist_override: int = -1,
		seeking: bool = false,
		enemies: Array[MercenaryData] = [],
		goal_cell: Vector3i = PathTargeter.NO_CELL) -> Array[String]:
	if move_target == null:
		return []
	if ConstStates.has_state(merc, ConstStates.CLIMBING):
		return []
	#A walker below a hovering flyer cannot close the height gap; mark the target blocked instead of a ring scan.
	if goal_cell == PathTargeter.NO_CELL and not seeking and not PathTargeter.is_flying(merc) \
			and PathTargeter.is_flying(move_target) and state.get_height(move_target) >= 1 \
			and _melee_only(merc):
		var reach := WeaponArmorPerkLibrary.melee_reach(merc)
		var mp := state.get_position(merc)
		var tp := state.get_position(move_target)
		var gap := state.distance_to(merc, move_target)
		if maxi(absi(mp.x - tp.x), absi(mp.y - tp.y)) <= reach and gap > reach:
			_mark_unreachable(merc, move_target, state, reach, gap)
			return []

	var ctx := WalkContext.new()
	ctx.merc = merc
	ctx.state = state
	ctx.action_name = action_name
	ctx.move_target = move_target
	ctx.seeking = seeking
	if not _move_goal(ctx, flank_ally, stop_dist_override, enemies, goal_cell):
		return ctx.move_lines
	ctx.field = state.battlefield
	if ctx.field != null:
		if not _move_plan(ctx):
			return []
		if not ctx.path.is_empty() and ctx.path.size() > ctx.path_start_idx + 1:
			if not _move_walk(ctx):
				return []
	return _move_finish(ctx, enhancements)


#Picks the cell the Move heads for; false when the Move ends here, with ctx.move_lines as its result.
static func _move_goal(ctx: WalkContext, flank_ally: MercenaryData, stop_dist_override: int,
		enemies: Array[MercenaryData], goal_cell: Vector3i) -> bool:
	var merc := ctx.merc
	var state := ctx.state
	var action_name := ctx.action_name
	var move_target := ctx.move_target
	var old_pos := state.pos3(merc)
	ctx.old_pos = old_pos
	ctx.drag_from = old_pos
	#Routing may cross a shut door this mover can open, a locked one it can pick or unlock, and water is priced per mover.
	PathCost.set_mover_doors(merc, state)
	state.pending_interact.erase(merc)
	#The executor must plan with the same capabilities the targeter scored with.
	var flying := PathTargeter.is_flying(merc)
	ctx.flying = flying
	#Paces above the surface of the mover's own cell; always 0 for a walker.
	var altitude := state.get_height(merc)
	ctx.altitude = altitude
	ctx.known_enemies = merc.last_known_enemy_positions.duplicate()
	var goal := goal_cell
	if goal == PathTargeter.NO_CELL:
		goal = compute_move_position(merc, move_target, action_name, state, flank_ally, stop_dist_override, enemies)
	if goal == PathTargeter.NO_CELL:
		_mark_blocked(merc, move_target, state)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE BLOCKED: %s no reachable cell near %s" % [merc.merc_name, move_target.merc_name])
		return false
	ctx.goal = goal
	if goal == old_pos:
		var skip_field := state.battlefield
		var skip_size := merc.unit_size()
		#A flyer that is already in place may still pay pace to see its target.
		if flying and skip_field != null and move_target != null and state.get_height(merc) >= 1 \
				and not (LineOfSight.check_from(state, old_pos, altitude, skip_size, move_target)["visible"] as bool):
			var skip_h := state.get_height(merc)
			var skip_budget := state.get_pace_pool(merc)
			var skip_found := _los_altitude(merc, state, skip_field, old_pos, skip_h, skip_budget, move_target)
			if skip_found < 0 and state.can_afford(merc, state.get_cost(merc, action_name, _CONFIG.move_base_ap)):
				skip_found = _los_altitude(merc, state, skip_field, old_pos, skip_h,
					skip_budget + PaceBudget.pace_per_move(merc), move_target)
				if skip_found >= 0:
					PaceBudget.buy_move(merc, state, action_name)
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
				ctx.move_lines.append("  %s changes altitude ([color=orange]h%d -> h%d[/color])" % [
					BattleState.colored_name(merc, state), skip_abs, state.absolute_height(merc)])
				return false
		#A melee-only walker whose best cell is its own cannot reach a target standing above melee reach.
		if goal_cell == PathTargeter.NO_CELL and not ctx.seeking and not flying and _melee_only(merc) \
				and not state.get_allies(merc).has(move_target):
			var up_reach := WeaponArmorPerkLibrary.melee_reach(merc)
			var up_dz := state.absolute_height(move_target) - state.absolute_height(merc)
			if up_dz > up_reach:
				_mark_unreachable(merc, move_target, state, up_reach, state.distance_to(merc, move_target))
				return false
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE SKIP: %s already at goal (%d,%d)" % [merc.merc_name, goal.x, goal.y])
		return false
	ctx.new_pos = goal
	return true


#Settles the goal against the mover's reach and picks its path; false when the Move aborts.
static func _move_plan(ctx: WalkContext) -> bool:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var fall_tolerance := PathTargeter.fall_tolerance(merc)
	ctx.fall_tolerance = fall_tolerance
	var can_climb: bool = true
	ctx.can_climb = can_climb
	var jump_stat: int = int(merc.stats.get("jump", 0))
	var move_size: int = int(merc.stats.get("size", 1))
	var rg: Dictionary = _resolve_goal(merc, state, field, ctx.goal, ctx.old_pos, fall_tolerance,
		can_climb, move_size, ctx.flying, ctx.altitude)
	if rg["abort"] as bool:
		return false
	ctx.goal = rg["goal"] as Vector3i
	var raw_goal: Vector3i = rg["raw_goal"] as Vector3i
	var reach: Dictionary = rg["reach"] as Dictionary
	var ally_passable: Dictionary = state.ally_passable_3d(merc)
	ctx.ally_passable = ally_passable
	var sp: Dictionary = _select_path(merc, state, field, ctx.move_target, ctx.old_pos, ctx.goal, raw_goal,
		reach, ctx.seeking, ally_passable, fall_tolerance, ctx.flying, can_climb, jump_stat, move_size,
		ctx.altitude, ctx.known_enemies)
	ctx.path = sp["path"] as Array[Vector3i]
	ctx.path_start_idx = sp["start_idx"] as int
	if sp["blocked"] as bool:
		ctx.new_pos = ctx.old_pos
	return true


#Walks the planned path; false when the Move ends here with nothing to narrate.
static func _move_walk(ctx: WalkContext) -> bool:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var path := ctx.path
	var path_start_idx := ctx.path_start_idx
	var old_pos := ctx.old_pos
	var goal := ctx.goal
	var mplan: Dictionary = state.move_plan.get(merc, {}) as Dictionary
	var pool_start := state.get_pace_pool(merc)
	ctx.pool_start = pool_start
	#Move purchases this walk may still make, and the AP it holds back for them.
	var buy: Dictionary = {
		"action_name": ctx.action_name,
		"left": maxi(1, int(mplan.get("moves_allowed", 1))),
		"reserve": maxi(0, int(mplan.get("reserve_ap", 0))),
		"bought": 0,
		"pool_start": pool_start,
		"why": "",
	}
	ctx.buy = buy
	ctx.traversed.append(old_pos)
	ctx.cost_at.append(0)
	ctx.merc_size = int(merc.stats.get("size", 1))
	#Altitude the mover has as it leaves the cell it currently stands on.
	var cur_alt := ctx.altitude
	var start_flanked := PathTargeter.is_flanked_by_known(old_pos, ctx.known_enemies)
	#A walk that cannot pay its way to any cell it may end on buys nothing.
	var dry_end := _dry_walk_end(ctx, path, path_start_idx, pool_start, old_pos, cur_alt, start_flanked)
	if dry_end == old_pos:
		#The route's first step is the link itself, so the walk hands the foot to the Climb action.
		var foot_climb: Dictionary = PathCost.climb_step(old_pos, path[path_start_idx + 1],
			field, ctx.flying, ctx.fall_tolerance, ctx.merc_size)
		if not foot_climb.is_empty():
			state.set_climb_route(merc, foot_climb["link"] as Dictionary,
				bool(foot_climb["down"]), old_pos)
			_turn_path_cache.erase(merc)
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("MOVE CLIMB FOOT: %s foot=(%d,%d,%d) dir=%s" % [
					merc.merc_name, old_pos.x, old_pos.y, old_pos.z,
					"down" if bool(foot_climb["down"]) else "up"])
			return false
		#The same handover for a route whose first step is a roof leap.
		var foot_jump: Dictionary = PathJump.roof_jump_step(old_pos, path[path_start_idx + 1],
			field, ctx.flying, ctx.merc_size)
		if not foot_jump.is_empty():
			state.set_jump_route(merc, foot_jump["to"] as Vector3i, old_pos)
			_turn_path_cache.erase(merc)
			if EncounterLogger.is_active():
				var fj: Vector3i = foot_jump["to"] as Vector3i
				EncounterLogger.log_verbose("MOVE JUMP FOOT: %s foot=(%d,%d,%d) land=(%d,%d,%d)" % [
					merc.merc_name, old_pos.x, old_pos.y, old_pos.z, fj.x, fj.y, fj.z])
			return false
		var dry_why := str(buy.get("dry_why", ""))
		#An AP-short walk whose next cell is a shut door opens it with the Interact action instead.
		var door_first := dry_why != "occupied" and dry_why != "no_step" \
				and PathCost.is_shut_door(field, path[path_start_idx + 1])
		if door_first:
			state.pending_interact[merc] = path[path_start_idx + 1]
		else:
			_raise_blocked(goal, state.round_number)
		_turn_path_cache.erase(merc)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE REFUSED: %s goal=(%d,%d) reason=%s pool=%d moves=%d why=%s" % [
				merc.merc_name, goal.x, goal.y, "door_first" if door_first else "pool_short",
				pool_start, int(buy["left"]), dry_why])
			EncounterLogger.log_verbose("MOVE REFUSED STEPS: %s pp=%d ap=%d+%d reserve=%d %s" % [
				merc.merc_name, PaceBudget.pace_per_move(merc), merc.current_ap, merc.excess_ap, int(buy["reserve"]),
				MoveDiagnostics.refused_steps(ctx, path, path_start_idx, cur_alt)])
		return false
	var walk := _walk(ctx, path, path_start_idx, pool_start, old_pos, cur_alt, start_flanked)
	var abort := _finish_walk(ctx, walk)
	var new_pos := ctx.new_pos
	var cr: Dictionary = walk["climb_route"] as Dictionary
	if not cr.is_empty() and new_pos == (cr["foot"] as Vector3i):
		state.set_climb_route(merc, cr["link"] as Dictionary, bool(cr["down"]), new_pos)
	var jr: Dictionary = walk["jump_route"] as Dictionary
	if not jr.is_empty() and new_pos == (jr["foot"] as Vector3i):
		state.set_jump_route(merc, jr["to"] as Vector3i, new_pos)
	if abort:
		return false
	var drag_idx := path.find(new_pos)
	if drag_idx >= 1:
		ctx.drag_from = path[drag_idx - 1]
	return true


#Applies the Move from ctx: the stall and oscillation checks, the step itself, falls, harms and altitude.
static func _move_finish(ctx: WalkContext, enhancements: int) -> Array[String]:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var action_name := ctx.action_name
	var move_target := ctx.move_target
	var old_pos := ctx.old_pos
	var old_2d := Vector2i(old_pos.x, old_pos.y)
	var goal := ctx.goal
	var new_pos := ctx.new_pos
	var flying := ctx.flying
	var altitude := ctx.altitude
	var drag_from := ctx.drag_from
	var body_traverse_lines := ctx.body_traverse_lines
	var path_harms := ctx.path_harms
	var drop_taken := ctx.drop_taken
	var floor_change_cell := ctx.floor_change
	var fly_top := ctx.fly_top
	if new_pos == old_pos:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("MOVE STALLED: %s goal=(%d,%d) no viable path reason=%s fly=%d path=%s" % [
				merc.merc_name, goal.x, goal.y, ctx.stall_why, 1 if flying else 0, ctx.stall_path])
		var _stall_pace := PaceBudget.pace_per_move(merc)
		var perm_block := false
		if field != null:
			var stall_ft := PathTargeter.fall_tolerance(merc)
			var stall_ap: Dictionary = state.ally_passable_3d(merc)
			var any_affordable := false
			for snb: Vector3i in PathCost.neighbors(old_pos, field):
				if not field.in_bounds_xy(snb.x, snb.y):
					continue
				var sc := PathCost.cell_pace_cost(old_pos, snb, field, stall_ap, stall_ft, flying, true, int(merc.stats.get("size", 1)), altitude)
				if sc >= 0:
					any_affordable = true
					break
			if not any_affordable:
				perm_block = true
		if perm_block:
			_mark_blocked(merc, move_target, state)
			_blocked_path_goals[goal] = state.round_number + 1000
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("MOVE BLOCKED: %s no affordable step from (%d,%d)" % [merc.merc_name, old_pos.x, old_pos.y])
		else:
			_raise_blocked(goal, state.round_number + 3)
			if field != null and move_target != null:
				var target_pos := state.pos3(move_target)
				if Vector2i(target_pos.x, target_pos.y) != Vector2i(-1, -1):
					var cands := _ring8(target_pos, field)
					var mt_reach: Dictionary = ReachCache.reachable_far_for(merc, state, cands)
					for mc: Vector3i in cands:
						#A jump-only node is not a walkable approach cell, so it stays blacklisted.
						if mt_reach.has(mc) and (mt_reach[mc] as int) < PathTargeter.JUMP_COST_OFFSET:
							continue
						_raise_blocked(mc, state.round_number + 3)
		return []

	if not ctx.seeking:
		var hist: Array = state.position_history.get(merc, []) as Array
		if hist.has(Vector2i(new_pos.x, new_pos.y)):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("OSCILLATION BLOCKED: %s would return to recently visited (%d,%d)" % [
					merc.merc_name, new_pos.x, new_pos.y])
			var flank_cell := _oscillation_flank(merc, state, field, move_target, old_pos, altitude, flying, hist)
			var flank_ok := flank_cell != PathTargeter.NO_CELL
			if flank_ok:
				new_pos = flank_cell
				drag_from = old_pos
				body_traverse_lines.clear()
			if not flank_ok:
				_blocked_path_goals[goal] = state.round_number
				return []
			_blocked_path_goals[goal] = state.round_number + 3

	var move_lines := ctx.move_lines

	var new_2d := Vector2i(new_pos.x, new_pos.y)
	move_lines.append_array(advantage_attacks(merc, state, old_2d, new_2d, enhancements))

	state.escalation[merc]["last_move_from"] = old_pos
	state.set_pos3(merc, new_pos)
	KidnapSystem.drag(merc, state, drag_from)
	if new_pos.z != old_pos.z and EncounterLogger.is_active():
		var fc: Vector3i = floor_change_cell if floor_change_cell != PathTargeter.NO_CELL else new_pos
		EncounterLogger.log_verbose("FLOOR: %s %d->%d at (%d,%d)" % [
			merc.merc_name, old_pos.z, new_pos.z, fc.x, fc.y])
	merc.aim_active = false

	var goal_after_move: Vector3i = state.move_goals.get(merc, PathTargeter.NO_CELL) as Vector3i
	if goal_after_move != PathTargeter.NO_CELL and new_pos == goal_after_move:
		state.move_goals.erase(merc)

	move_lines.append_array(ctx.drop_lines)
	if not drop_taken.is_empty():
		_log_ledge_drop(merc, drop_taken, old_pos.z, new_pos)
		_turn_path_cache.erase(merc)
		if flying:
			move_lines.append(_descent_line(merc, int(drop_taken["paces"]), state))
		else:
			move_lines.append_array(FallResolver.resolve_fall(merc, int(drop_taken["paces"]), state))
		state.set_height(merc, 0)

	#A walker falls on each step down of a pace or more; a flyer on the ground descends and lands without harm.
	if field != null and not (flying and altitude >= 1):
		for sf_paces: int in ctx.step_falls:
			if flying:
				move_lines.append(_descent_line(merc, sf_paces, state))
			else:
				move_lines.append_array(FallResolver.resolve_fall(merc, sf_paces, state))
			state.set_height(merc, 0)

	#A walker standing on an obstacle top steps off it and falls that height.
	if field != null and not flying and altitude >= 1 and new_pos != old_pos:
		move_lines.append_array(FallResolver.resolve_fall(merc, altitude, state))
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
	var hover_alt := ctx.hover_alt
	if hover_alt >= 0 and hover_alt != state.get_height(merc):
		var hvabs := state.absolute_height(merc)
		state.set_height(merc, hover_alt)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("ALTITUDE: %s h%d -> h%d reason=hover" % [
				merc.merc_name, hvabs, state.absolute_height(merc)])

	#The flyer ends the move above the tallest thing it flew over.
	if flying and field != null and fly_top > -1.0e8:
		var fly_size := merc.unit_size()
		var oa := state.get_height(merc)
		var na := maxi(oa, int(ceil(fly_top - field.cell_base_elevation(new_2d, new_pos.z))))
		var ce := PathCost.slab_above(new_2d, new_pos.z, field)
		if ce < PathCost.NO_CEILING:
			na = mini(na, maxi(0, int(floor(ce - field.cell_base_elevation(new_2d, new_pos.z))) - fly_size))
		if na != oa:
			var oabs := state.absolute_height(merc)
			state.set_height(merc, na)
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("ALTITUDE: %s h%d -> h%d reason=fly_over" % [
					merc.merc_name, oabs, state.absolute_height(merc)])

	#Leftover pace buys the smallest altitude change that opens line of sight.
	if flying and field != null:
		var remaining_pace := ctx.pace_left
		var cur_h := state.get_height(merc)
		var fly_size := merc.unit_size()
		var seen := (LineOfSight.check_from(state, new_pos, cur_h, fly_size, move_target)["visible"] as bool)
		if remaining_pace > 0 and not seen:
			var found := _los_altitude(merc, state, field, new_pos, cur_h, remaining_pace, move_target)
			if found >= 0:
				var labs := state.absolute_height(merc)
				state.set_height(merc, found)
				state.set_pace_pool(merc, maxi(0, state.get_pace_pool(merc) - absi(found - cur_h)))
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("ALTITUDE: %s h%d -> h%d reason=los" % [
						merc.merc_name, labs, state.absolute_height(merc)])

	return move_lines


static func climb_route_ready(merc: MercenaryData, state: BattleState) -> bool:
	return ClimbExecutor.climb_route_ready(merc, state)


static func move_yields(merc: MercenaryData, state: BattleState, action_name: String) -> bool:
	return MovementArms.move_yields(merc, state, action_name)


static func execute_climb(merc: MercenaryData, decision: Dictionary, action_name: String,
		state: BattleState) -> Array[String]:
	return ClimbExecutor.execute_climb(merc, decision, action_name, state)


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
	var budget: int = PaceBudget.pace_per_move(merc) if buy_first else state.get_pace_pool(merc)
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
		PaceBudget.buy_move(merc, state, "Move Close")
	state.set_pace_pool(merc, maxi(0, state.get_pace_pool(merc) - steps))
	var move_lines: Array[String] = []
	move_lines.append_array(advantage_attacks(merc, state, old_pos, new_pos, enhancements))
	state.set_position(merc, new_pos)
	merc.aim_active = false
	move_lines.append("  %s -> weapon ([color=orange]%d,%d -> %d,%d[/color])" % [
		BattleState.colored_name(merc, state), old_pos.x, old_pos.y, new_pos.x, new_pos.y])
	return move_lines


static func run_move_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	return MovementArms.run_move_arm(merc, decision, state, enhancements, turn)


static func run_jump_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	return MovementArms.run_jump_arm(merc, decision, state, enhancements, turn)


static func run_climb_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		turn: Dictionary) -> Array[String]:
	return MovementArms.run_climb_arm(merc, decision, state, turn)


static func run_move_to_pickup_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	return MovementArms.run_move_to_cell_arm(merc, decision, state, enhancements, turn, "weapon_pos", true)


static func run_move_to_obstacle_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	return MovementArms.run_move_to_cell_arm(merc, decision, state, enhancements, turn, "obstacle_pos", false)
