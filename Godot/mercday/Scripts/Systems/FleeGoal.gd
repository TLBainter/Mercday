class_name FleeGoal


#Map-edge cell a fleeing merc walks toward, cached for the round; NO_CELL when there is no field or no cell.
static func escape_goal(merc: MercenaryData, state: BattleState) -> Vector3i:
	if state == null or state.battlefield == null:
		return PathTargeter.NO_CELL
	var cached := _cached_goal(merc, state)
	if cached != PathTargeter.NO_CELL:
		return cached
	var field := state.battlefield
	var floors: Array[int] = field.sorted_floors()
	if floors.is_empty():
		floors.append(0)
	var cells: Array[Vector3i] = []
	for f: int in floors:
		for x: int in range(field.width):
			cells.append(Vector3i(x, 0, f))
			if field.length > 1:
				cells.append(Vector3i(x, field.length - 1, f))
		for y: int in range(1, field.length - 1):
			cells.append(Vector3i(0, y, f))
			if field.width > 1:
				cells.append(Vector3i(field.width - 1, y, f))
	var reach := ReachCache.reachable_far_for(merc, state, cells, ReachCache.RING_SLACK)
	var scored := _score_reachable(merc, state, cells, reach, _foe_cells(merc, state))
	var goal: Vector3i = scored["goal"]
	FleeSystem.goal_cache[merc] = {"round": state.round_number, "goal": goal}
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("FLEE GOAL: %s tier %d (%d,%d,%d) cost %d"
				% [merc.merc_name, int(scored["tier"]), goal.x, goal.y, goal.z, int(reach.get(goal, -1))])
	return goal


#Goal kept from an earlier call this round; NO_CELL when there is none or it is the cell the merc stands on.
static func _cached_goal(merc: MercenaryData, state: BattleState) -> Vector3i:
	var cached: Variant = FleeSystem.goal_cache.get(merc)
	if cached is Dictionary and int((cached as Dictionary).get("round", -1)) == state.round_number:
		var prev: Vector3i = (cached as Dictionary).get("goal", PathTargeter.NO_CELL) as Vector3i
		if prev != PathTargeter.NO_CELL and prev != state.pos3(merc):
			return prev
	return PathTargeter.NO_CELL


static func _foe_cells(merc: MercenaryData, state: BattleState) -> Array[Vector3i]:
	var foe_cells: Array[Vector3i] = []
	for foe: MercenaryData in state.get_enemies(merc):
		foe_cells.append(state.pos3(foe))
	return foe_cells


#Picks the escape goal out of the reachable edge cells; returns {"goal": Vector3i, "tier": int}.
static func _score_reachable(merc: MercenaryData, state: BattleState, cells: Array[Vector3i],
		reach: Dictionary, foe_cells: Array[Vector3i]) -> Dictionary:
	var own := state.pos3(merc)
	var field := state.battlefield
	var kept: Array[Vector3i] = []
	for c: Vector3i in cells:
		if c != own and _goal_ok(c, reach, merc, state):
			kept.append(c)
	var goal := PathTargeter.NO_CELL
	var tier := 0
	var open_cell := PathTargeter.NO_CELL
	var any_cell := PathTargeter.NO_CELL
	for c: Vector3i in kept:
		if c.z != 0:
			continue
		var cost := int(reach[c])
		if any_cell == PathTargeter.NO_CELL or cost < int(reach[any_cell]):
			any_cell = c
		if (open_cell == PathTargeter.NO_CELL or cost < int(reach[open_cell])) and not _foe_beside(c, foe_cells):
			open_cell = c
	if any_cell != PathTargeter.NO_CELL:
		goal = open_cell if open_cell != PathTargeter.NO_CELL else any_cell
		tier = 1
	else:
		for c: Vector3i in kept:
			if goal == PathTargeter.NO_CELL or absi(c.z) < absi(goal.z) \
					or (absi(c.z) == absi(goal.z) and int(reach[c]) < int(reach[goal])):
				goal = c
				tier = 2
	if kept.is_empty():
		var best_d := 0
		var best_f := 0
		var best_cost := 0
		var own_d := mini(mini(own.x, own.y), mini(field.width - 1 - own.x, field.length - 1 - own.y))
		for c: Vector3i in reach:
			var cost := int(reach[c])
			var d := mini(mini(c.x, c.y), mini(field.width - 1 - c.x, field.length - 1 - c.y))
			if d >= own_d:
				continue
			var f := absi(c.z)
			if goal != PathTargeter.NO_CELL and (d > best_d or (d == best_d and (f > best_f
					or (f == best_f and cost >= best_cost)))):
				continue
			if not _goal_ok(c, reach, merc, state):
				continue
			goal = c
			tier = 3
			best_d = d
			best_f = f
			best_cost = cost
	return {"goal": goal, "tier": tier}


static func _goal_ok(cell: Vector3i, reach: Dictionary, merc: MercenaryData, state: BattleState) -> bool:
	if not reach.has(cell) or int(reach[cell]) >= PathTargeter.JUMP_COST_OFFSET:
		return false
	return PathHelper.is_goal_passable(cell, state.battlefield, PathTargeter.fall_tolerance(merc), true,
			int(merc.stats.get("size", 1)), PathTargeter.is_flying(merc), state.get_height(merc), state, merc)


static func _foe_beside(cell: Vector3i, foe_cells: Array[Vector3i]) -> bool:
	for p: Vector3i in foe_cells:
		if p.z == cell.z and maxi(absi(p.x - cell.x), absi(p.y - cell.y)) <= 1:
			return true
	return false


static func on_edge(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or state.battlefield == null:
		return true
	var field := state.battlefield
	var p := state.get_position(merc)
	return p.x <= 0 or p.y <= 0 or p.x >= field.width - 1 or p.y >= field.length - 1


#True when an enemy would take an Advantage Attack if merc stepped away from its cell now.
static func in_danger(merc: MercenaryData, state: BattleState) -> bool:
	if state == null or state.battlefield == null:
		return false
	var p := state.get_position(merc)
	return not ReactiveActionSystem.get_triggered_reactions("enemy_leaves_melee_range", merc, p, p, state).is_empty()
