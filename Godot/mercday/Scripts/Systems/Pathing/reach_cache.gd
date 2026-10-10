class_name ReachCache

#Window nearest_passable_to scans around a goal, and the paces past the goal's own cost it is grown to.
const AROUND_RADIUS := 3
const AROUND_SLACK := 12
#Paces past the cheapest ring cell that the flood is still grown for the rest of the ring.
const RING_SLACK := 6
#Settled cells one approach flood may hold, as a multiple of the cells the turn's own flood holds.
const FAR_CAP_MULT := 4
#The floor that multiple never drops below, so a boxed-in mover still gets a useful horizon.
const FAR_CAP_MIN := 500
#Standable cells a map must hold before any approach flood is capped; smaller maps always flood in full.
const FAR_CAP_CELLS := 3000
#Share of the standable cells that lifts the cap floor on the largest maps.
const FAR_CAP_DIV := 8

#MercenaryData -> {"key": Array, "search": ReachSearch}: one growing flood per mover.
static var reach_slots: Dictionary = {}
#0 or more forces that cap on every mover; tests set it and hand it back to -1.
static var far_cap_override: int = -1
#[field id, path_version] and the standable cell count built for it; one field at a time.
static var _walk_key: Array = []
static var _walk_n: int = 0


static func clear_caches() -> void:
	reach_slots = {}


#Standable cells of the map for a size 1 walker: the ground floor in full, then the building floors above
#and below it and every roof level. Counted once per path_version.
static func walk_cells_of(field: BattlefieldArea) -> int:
	if field == null:
		return 0
	var key: Array = [field.get_instance_id(), field.path_version]
	if _walk_key == key:
		return _walk_n
	var n: int = 0
	for x: int in range(field.width):
		for y: int in range(field.length):
			if PathHelper.is_standable(Vector3i(x, y, 0), field, 1):
				n += 1
	for raw: Variant in field.footprint_cells.keys():
		var cell: Vector3i = raw as Vector3i
		if cell.z != 0 and PathHelper.is_standable(cell, field, 1):
			n += 1
	for raw_roof: Variant in field.roof_cells.keys():
		if PathHelper.is_standable(raw_roof as Vector3i, field, 1):
			n += 1
	_walk_key = key
	_walk_n = n
	return n


#Paces the flood covers by default: this turn's paces plus two more Moves.
static func reach_budget(merc: MercenaryData, state: BattleState) -> int:
	return int(PaceBudget.turn_paces(merc, state, 0)["paces"]) + 2 * PaceBudget.pace_per_move(merc)


#Exactly the allies and cells BattleState.ally_passable_3d puts in the passable set.
static func _ally_sig(merc: MercenaryData, state: BattleState) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for ally: MercenaryData in state.get_allies(merc):
		if not BattleState._is_alive(ally) or ConstStates.has_state(ally, ConstStates.DEPOSED):
			continue
		if not state.positions.has(ally):
			continue
		var p: Vector3i = state.pos3(ally)
		parts.append("%d,%d,%d" % [p.x, p.y, p.z])
	parts.sort()
	return "|".join(parts)


#This merc's flood with the turn's door surcharge set; null when the state has no battlefield.
static func _prepared_search(merc: MercenaryData, state: BattleState, warm: bool = false) -> ReachSearch:
	if state.battlefield == null:
		return null
	PathCost.set_mover_doors(merc, state, warm)
	return _search_for(merc, state)


#The mover's flood for the current geometry; a changed key starts a fresh one.
static func _search_for(merc: MercenaryData, state: BattleState) -> ReachSearch:
	var field := state.battlefield
	var from := state.pos3(merc)
	var jump := int(merc.stats.get("jump", 0))
	var merc_size := int(merc.stats.get("size", 1))
	var altitude := state.get_height(merc)
	var flying := PathTargeter.is_flying(merc)
	var tolerance := PathTargeter.fall_tolerance(merc)
	var key: Array = [
		from, field.path_version, field.door_version, _ally_sig(merc, state), PathCost.door_pace_penalty,
		tolerance, merc_size, flying, altitude, jump, PathCost.water_cost, PathCost.sunk_depth,
		PathCost.wanted_sig, PathCost.link_climbs, PathCost.climb_pace, int(ceil(PathCost.climb_hp / 4.0)),
		PathCost.lock_mode, PathCost.lock_pace_penalty]
	var slot: Dictionary = reach_slots.get(merc, {}) as Dictionary
	if not slot.is_empty() and (slot["key"] as Array) == key:
		return slot["search"] as ReachSearch
	var search := ReachSearch.create(
		from, field, state.ally_passable_3d(merc), tolerance,
		flying, true, jump, merc_size, altitude)
	reach_slots[merc] = {"key": key, "search": search}
	return search


#Flood fill from the merc's cell with its own capabilities, bounded to two turns of Pace.
#reachable_far_for grows the same flood further; costs are minimal, not first-touch.
#Targeter and executor must plan from the same set, so both call this.
static func reachable_for(merc: MercenaryData, state: BattleState, warm: bool = false) -> Dictionary:
	#Every later query in this merc's turn plans with its own door surcharge.
	var search := _prepared_search(merc, state, warm)
	if search == null:
		return {}
	var budget := reach_budget(merc, state)
	search.ensure_cost(budget)
	if search.near_cells < 0:
		search.near_cells = _walk_cell_count(search.result, budget)
	return search.result


#Walk-reachable entries of a flood result priced at limit or under; jump-published ones price no
#route to stand on. Costs are minimal, so the count is the same however far the flood has grown.
static func _walk_cell_count(reach: Dictionary, limit: int) -> int:
	var walk := 0
	for key: Variant in reach.keys():
		var cost: int = reach[key] as int
		if cost < PathTargeter.JUMP_COST_OFFSET and cost <= limit:
			walk += 1
	return walk


#The cap floor for a map with that many standable cells.
static func cap_floor_of(cells: int) -> int:
	return maxi(FAR_CAP_MIN, int(cells / float(FAR_CAP_DIV)))


#Settled cells one far growth may add: four turns' worth of the mover's own flood, at least FAR_CAP_MIN or a
#share of the map's standable cells. -1 (no cap) on a map with FAR_CAP_CELLS standable cells or fewer.
static func far_cap_for(merc: MercenaryData, state: BattleState) -> int:
	if far_cap_override >= 0:
		return far_cap_override
	var cells: int = walk_cells_of(state.battlefield)
	if cells <= FAR_CAP_CELLS:
		return -1
	var floor_cap: int = cap_floor_of(cells)
	var search := _prepared_search(merc, state)
	if search == null:
		return floor_cap
	if search.near_cells < 0:
		reachable_for(merc, state)
	return maxi(floor_cap, FAR_CAP_MULT * maxi(0, search.near_cells))


#True when the last far growth of this merc's flood stopped on its cap.
static func far_capped(merc: MercenaryData, state: BattleState) -> bool:
	var search := _prepared_search(merc, state)
	return search != null and search.capped


#The walk-settled cell of this merc's flood nearest the box around cells, or PathTargeter.NO_CELL.
static func far_frontier_for(merc: MercenaryData, state: BattleState, cells: Array) -> Vector3i:
	var search := _prepared_search(merc, state)
	if search == null:
		return PathTargeter.NO_CELL
	return search.nearest_settled_to(cells)


#2D Chebyshev distance from cell to the box around cells, as the flood measures it.
static func far_box_distance(merc: MercenaryData, state: BattleState, cell: Vector3i, cells: Array) -> int:
	var search := _prepared_search(merc, state)
	if search == null:
		return 0
	return search.box_distance(cell, cells)


#Grows this merc's flood until every listed cell is settled, for pace distances beyond the bound.
#With slack >= 0 the growth stops slack paces past the first listed cell that settles.
#With max_settled >= 0 it also stops once the flood holds that many settled cells.
static func reachable_far_for(merc: MercenaryData, state: BattleState, cells: Array, slack: int = -1,
		max_settled: int = -1) -> Dictionary:
	var search := _prepared_search(merc, state)
	if search == null:
		return {}
	search.ensure_cells(cells, -1, slack, max_settled)
	return search.result


#Spawn-time fill of the field's landing tables: every jumper's own turn flood runs once here, so the first
#turns find the tables around both spawn zones built. Widest jump first, since a table is built once at the
#widest range asked for so far. The flood slots are dropped after; AutoBattle.setup would drop them anyway.
#The warm-up plans without the lock branch, which would draw the RNG and shift the battle's first roll.
static func warm_jumps(state: BattleState) -> int:
	if state == null or state.battlefield == null:
		return 0
	var jumpers: Array[MercenaryData] = []
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			if not state.positions.has(merc) or not BattleState._is_alive(merc):
				continue
			if int(merc.stats.get("jump", 0)) <= 0:
				continue
			jumpers.append(merc)
	jumpers.sort_custom(func(a: MercenaryData, b: MercenaryData) -> bool:
		return int(a.stats.get("jump", 0)) > int(b.stats.get("jump", 0)))
	for merc: MercenaryData in jumpers:
		reachable_for(merc, state, true)
	clear_caches()
	return jumpers.size()


#The flood's minimal walk path from `from` to goal; [] when the mover stands elsewhere or goal is not walk-settled.
static func walk_path_for(merc: MercenaryData, state: BattleState, from: Vector3i, goal: Vector3i) -> Array[Vector3i]:
	var empty: Array[Vector3i] = []
	if state.pos3(merc) != from:
		return empty
	var search := _prepared_search(merc, state)
	if search == null:
		return empty
	search.ensure_cells([goal])
	return search.walk_path(goal)


#Grows this merc's flood to `center`. When center cannot be the goal itself, or force_window is set,
#the passable goals in the window nearest_passable_to scans are grown to as well, bounded by the
#center cost plus AROUND_SLACK paces.
static func reachable_around_for(merc: MercenaryData, state: BattleState, center: Vector3i,
		force_window: bool = false) -> Dictionary:
	var field := state.battlefield
	var search := _prepared_search(merc, state)
	if search == null:
		return {}
	search.ensure_cells([center])
	var center_cost: int = search.result.get(center, PathTargeter.JUMP_COST_OFFSET) as int
	if center_cost >= PathTargeter.JUMP_COST_OFFSET:
		return search.result
	var merc_size := int(merc.stats.get("size", 1))
	var flying := PathTargeter.is_flying(merc)
	var tolerance := PathTargeter.fall_tolerance(merc)
	var altitude := state.get_height(merc)
	if not force_window and PathHelper.is_goal_passable(center, field, tolerance, true, merc_size, flying, altitude, state, merc):
		return search.result
	var window: Array[Vector3i] = []
	for dx: int in range(-AROUND_RADIUS, AROUND_RADIUS + 1):
		for dy: int in range(-AROUND_RADIUS, AROUND_RADIUS + 1):
			var c := Vector3i(center.x + dx, center.y + dy, center.z)
			if not field.in_bounds_xy(c.x, c.y):
				continue
			if not PathHelper.is_goal_passable(c, field, tolerance, true, merc_size, flying, altitude, state, merc):
				continue
			window.append(c)
	search.ensure_cells(window, center_cost + AROUND_SLACK)
	return search.result
