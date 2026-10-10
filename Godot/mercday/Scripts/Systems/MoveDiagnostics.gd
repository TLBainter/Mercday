class_name MoveDiagnostics extends RefCounted


#Why the raw goal from the targeter had to be shifted, for the MOVE GOAL ADJUST line.
static func goal_adjust_reason(
		raw: Vector3i,
		field: BattlefieldArea,
		state: BattleState,
		merc: MercenaryData) -> String:
	if state.is_position_occupied(Vector2i(raw.x, raw.y), merc, raw.z):
		return "occupied"
	if not PathHelper.is_standable(raw, field, int(merc.stats.get("size", 1))):
		return "obstacle"
	return "unreachable"


#Why no exact path to the goal existed, for the MOVE PARTIAL line.
static func partial_reason(goal: Vector3i, reach: Dictionary) -> String:
	if not reach.has(goal):
		return "goal_unreachable"
	if (reach[goal] as int) >= PathTargeter.JUMP_COST_OFFSET:
		return "jump_only"
	return "path_blocked"


#Diagnostic: the first three steps a refused Move faced, with their pace cost and endability.
static func refused_steps(ctx: MovementExecutor.WalkContext, path: Array[Vector3i], path_start_idx: int,
		cur_alt: int) -> String:
	var merc := ctx.merc
	var state := ctx.state
	var field := ctx.field
	var ally_passable := ctx.ally_passable
	var fall_tolerance := ctx.fall_tolerance
	var flying := ctx.flying
	var can_climb := ctx.can_climb
	var merc_size := ctx.merc_size
	var parts: Array[String] = []
	var alt := cur_alt
	for i: int in range(path_start_idx + 1, mini(path.size(), path_start_idx + 4)):
		var from_cell: Vector3i = path[i - 1]
		var cell: Vector3i = path[i]
		var cost := PathCost.cell_pace_cost(from_cell, cell, field, ally_passable, fall_tolerance, flying, can_climb,
			merc_size, alt)
		if flying:
			alt = PathCost.fly_arrival_altitude(from_cell, cell, field, alt, merc_size)
		var end := "n"
		if PathCost.is_shut_door(field, cell):
			end = "door"
		elif state.is_position_occupied(Vector2i(cell.x, cell.y), merc, cell.z):
			end = "occ"
		elif MovementExecutor.can_end_on(cell, field, merc_size, flying):
			end = "y"
		parts.append("(%d,%d,%d) cost=%d end=%s" % [cell.x, cell.y, cell.z, cost, end])
	return "; ".join(parts)


#Diagnostic: the floor changes and obstacle cells along a planned path.
static func route_summary(path: Array[Vector3i], field: BattlefieldArea) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(path.size()):
		var c: Vector3i = path[i]
		var obs: Dictionary = field.get_obs(Vector2i(c.x, c.y), c.z)
		var tag := ""
		if i > 0 and path[i - 1].z != c.z:
			if PathCost.is_well_link(path[i - 1], c, field):
				tag = "well"
			elif PathCost.is_roof_fly_link(path[i - 1], c, field):
				tag = "roof"
			else:
				tag = "F"
		elif not obs.is_empty():
			tag = str(obs.get("cell_type", "obs"))
		if tag != "":
			parts.append("(%d,%d,%d)%s" % [c.x, c.y, c.z, tag])
	return " ".join(parts)
