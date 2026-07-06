class_name PathCost

# Pace cost to enter `to` from `from`. Returns -1 if impassable.
static func cell_pace_cost(from: Vector2i, to: Vector2i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false,
		floor_num: int = 0) -> int:
	if field.jagged_cells.has(to):
		return -1
	if is_flying:
		return 1
	if field.fly_only_cells.has(to):
		return -1

	if passable_cells.has(to):
		var h_diff_pc: float = field.get_terrain_height(to) - field.get_terrain_height(from)
		if h_diff_pc > 0.5:
			if h_diff_pc <= 1.0:
				return 3
			if not can_climb or h_diff_pc > 2.0:
				return -1
			return 3
		if h_diff_pc <= -1.0:
			var fall_paces_pc := int(floor(-h_diff_pc))
			var fall_severity_pc: float = float(fall_paces_pc) / merc_fall_tolerance
			if fall_severity_pc >= 4.0:
				return -1
		elif absf(h_diff_pc) > 0.25 and not field.has_stairs_at(to):
			return -1
		return 1

	var obs: Dictionary = field.get_obstacle_at_floor(to, floor_num) if field.is_interior_map else field.get_obstacle_at(to)
	var base_cost: int

	if obs.is_empty():
		base_cost = 1
	else:
		var cell_type: String = obs.get("cell_type", "")
		if cell_type == "wall":
			return -1
		if cell_type == "door":
			if not obs.get("door_open", false):
				return -1
			base_cost = 1
		else:
			var data: ObstacleData = obs.get("data") as ObstacleData
			if data == null:
				return -1
			if data.ramp:
				base_cost = 1
			elif not data.passthrough:
				return -1
			elif data.pt_enter_harm > 0 or data.pt_exit_harm > 0:
				base_cost = 10
			else:
				base_cost = 2 if data.rugged else 1

	#TODO: stairwells blocked until explicit cross-floor navigation replaces automatic teleport
	if field.stairwell_connections.has(Vector3i(to.x, to.y, floor_num)):
		return -1

	var h_diff: float = field.get_terrain_height(to) - field.get_terrain_height(from)

	if h_diff > 0.5:
		if h_diff <= 1.0:
			return base_cost + 2
		elif not can_climb or h_diff > 2.0:
			return -1
		else:
			base_cost += 2

	if h_diff <= -1.0:
		var fall_paces := int(floor(-h_diff))
		var fall_severity: float = float(fall_paces) / merc_fall_tolerance
		if fall_severity >= 4.0:
			return -1
		base_cost += int(ceil(fall_paces * 4.0 / merc_fall_tolerance))

	elif absf(h_diff) > 0.25:
		if not field.has_stairs_at(to):
			return -1
		if h_diff > 0.0:
			base_cost += 1
		else:
			base_cost = maxi(0, base_cost - 1)

	return base_cost


static func has_exit_neighbor(cell: Vector2i, field: BattlefieldArea,
		passable_cells: Dictionary, merc_fall_tolerance: float,
		is_flying: bool, dirs: Array[Vector2i],
		can_climb: bool = false,
		floor_num: int = 0) -> bool:
	for d: Vector2i in dirs:
		var nb: Vector2i = cell + d
		if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
			continue
		if cell_pace_cost(cell, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb, floor_num) >= 0:
			return true
	return false


static func is_valid_jump_dest(pos: Vector2i, field: BattlefieldArea, floor_num: int = 0) -> bool:
	if pos.x < 0 or pos.x >= field.width or pos.y < 0 or pos.y >= field.length:
		return false
	var obs: Dictionary = field.get_obstacle_at_floor(pos, floor_num) if field.is_interior_map else field.get_obstacle_at(pos)
	if obs.is_empty():
		return true
	var cell_type: String = obs.get("cell_type", "")
	if cell_type == "wall":
		return false
	if cell_type == "door":
		return obs.get("door_open", false)
	var data: ObstacleData = obs.get("data") as ObstacleData
	return data == null or data.passthrough or data.ramp
