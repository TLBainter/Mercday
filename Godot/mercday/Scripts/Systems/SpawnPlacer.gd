class_name SpawnPlacer
extends RefCounted

#Places both teams on the battlefield at encounter start and logs the spawn choices.

#Batch option: each team spawns across its half of the floors instead of one floor per team.
static var spawn_floor_split: bool = false


static func assign(
		state: BattleState,
		team_a: Array[MercenaryData],
		team_b: Array[MercenaryData]) -> void:
	var field := state.battlefield
	var passable_cells: Dictionary = field.get_nav_passable_cells()
	if spawn_floor_split and field.is_interior_map and field.interior_floor_elevations.size() >= 2:
		_assign_split_positions(state, field, passable_cells, team_a, team_b)
		return
	var floor_a := 0
	if field.is_interior_map:
		for f: int in field.interior_floor_elevations.keys():
			if f > floor_a:
				floor_a = f
	#A closed interactable door is a route a merc can open, so spawn reach counts it free.
	PathCost.set_door_penalty(0)
	var center_a := _walkable_center(field, passable_cells, Vector3i(field.width >> 1, 2, floor_a))
	var center_b := _walkable_center(field, passable_cells, Vector3i(field.width >> 1, field.length - 3, 0))
	var reach_a := PathTargeter.reachable_from(center_a, field, passable_cells, 1.0, false, true, 0, 1)
	var reach_b := PathTargeter.reachable_from(center_b, field, passable_cells, 1.0, false, true, 0, 1)
	if center_a.z != center_b.z and not reach_a.has(center_b):
		var reached_floors: Dictionary = {}
		for cell: Vector3i in reach_a.keys():
			reached_floors[cell.z] = true
		field.generation_log.append("[SPAWN] no cross-floor route from (%d,%d) F%d to (%d,%d) F%d; floors reached %s" % [
			center_a.x, center_a.y, center_a.z, center_b.x, center_b.y, center_b.z, str(reached_floors.keys())])
		center_a = _walkable_center(field, passable_cells, Vector3i(field.width >> 1, 2, 0))
		reach_a = PathTargeter.reachable_from(center_a, field, passable_cells, 1.0, false, true, 0, 1)
	field.generation_log.append("SPAWN CENTER: Team 0 F%d (%d,%d)" % [center_a.z, center_a.x, center_a.y])
	field.generation_log.append("SPAWN CENTER: Team 1 F%d (%d,%d)" % [center_b.z, center_b.x, center_b.y])
	var taken: Dictionary = {}
	_place_team(state, field, passable_cells, team_a, center_a, reach_b, taken)
	_place_team(state, field, passable_cells, team_b, center_b, reach_a, taken)


#One team placed around its spawn centre, two RNG offsets drawn per merc in team order.
static func _place_team(state: BattleState, field: BattlefieldArea, passable_cells: Dictionary,
		team: Array[MercenaryData], center: Vector3i, enemy_reach: Dictionary,
		taken: Dictionary) -> void:
	for merc: MercenaryData in team:
		var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
		var offset := Vector2i(randi_range(-2, 2), randi_range(-2, 2))
		var start := field.clamp_position(Vector2i(center.x, center.y) + offset)
		var pos := _find_free_cell(field, passable_cells, Vector3i(start.x, start.y, center.z),
			center, enemy_reach, taken, merc_size, merc.merc_name)
		taken[pos] = true
		_log_unreachable_spawn(field, pos, enemy_reach, merc.merc_name)
		state.positions[merc] = Vector2i(pos.x, pos.y)
		state.heights[merc] = 0
		state.floors[merc] = pos.z


#Top half of the floors for team A, bottom half for team B; an odd middle floor belongs to both.
static func _assign_split_positions(state: BattleState, field: BattlefieldArea, passable_cells: Dictionary,
		team_a: Array[MercenaryData], team_b: Array[MercenaryData]) -> void:
	var levels: Array = field.interior_floor_elevations.keys()
	levels.sort()
	var half: int = (levels.size() + 1) >> 1
	var floors_a: Array = levels.slice(levels.size() - half)
	var floors_b: Array = levels.slice(0, half)
	PathCost.set_door_penalty(0)
	var centers_a: Dictionary = {}
	var centers_b: Dictionary = {}
	var reach_a: Dictionary = {}
	var reach_b: Dictionary = {}
	for f: int in floors_a:
		var c := _walkable_center(field, passable_cells, Vector3i(field.width >> 1, 2, f))
		centers_a[f] = c
		reach_a.merge(PathTargeter.reachable_from(c, field, passable_cells, 1.0, false, true, 0, 1))
	for f: int in floors_b:
		var c := _walkable_center(field, passable_cells, Vector3i(field.width >> 1, field.length - 3, f))
		centers_b[f] = c
		reach_b.merge(PathTargeter.reachable_from(c, field, passable_cells, 1.0, false, true, 0, 1))
	floors_a = _drop_unreached_floors(field, floors_a, centers_a, reach_b, 0)
	floors_b = _drop_unreached_floors(field, floors_b, centers_b, reach_a, 1)
	var taken: Dictionary = {}
	_place_team_split(state, field, passable_cells, team_a, floors_a, centers_a, reach_b, taken)
	_place_team_split(state, field, passable_cells, team_b, floors_b, centers_b, reach_a, taken)


#Floors whose spawn centre the other team cannot walk to are left out unless none would remain.
static func _drop_unreached_floors(field: BattlefieldArea, floor_list: Array, centers: Dictionary,
		enemy_reach: Dictionary, team: int) -> Array:
	var kept: Array = []
	for f: int in floor_list:
		var c: Vector3i = centers[f]
		if enemy_reach.has(c):
			kept.append(f)
		else:
			field.generation_log.append("[SPAWN] team %d floor F%d (%d,%d) has no route from the enemy spawns" % [
				team, f, c.x, c.y])
	if kept.is_empty():
		return floor_list
	return kept


static func _place_team_split(state: BattleState, field: BattlefieldArea, passable_cells: Dictionary,
		team: Array[MercenaryData], floor_list: Array, centers: Dictionary, enemy_reach: Dictionary,
		taken: Dictionary) -> void:
	var order: Array = floor_list.duplicate()
	order.shuffle()
	for i: int in range(team.size()):
		var merc: MercenaryData = team[i]
		var f: int = order[i % order.size()]
		var center: Vector3i = centers[f]
		var merc_size: int = maxi(1, int(merc.stats.get("size", 1)))
		var offset := Vector2i(randi_range(-2, 2), randi_range(-2, 2))
		var start := field.clamp_position(Vector2i(center.x, center.y) + offset)
		var pos := _find_free_cell(field, passable_cells, Vector3i(start.x, start.y, f),
			center, enemy_reach, taken, merc_size, merc.merc_name)
		taken[pos] = true
		_log_unreachable_spawn(field, pos, enemy_reach, merc.merc_name)
		field.generation_log.append("SPAWN CENTER: %s F%d (%d,%d)" % [merc.merc_name, pos.z, pos.x, pos.y])
		state.positions[merc] = Vector2i(pos.x, pos.y)
		state.heights[merc] = 0
		state.floors[merc] = pos.z


#Spawn the opposing team cannot walk to; enemy_reach is empty on exterior fallbacks.
static func _log_unreachable_spawn(field: BattlefieldArea, pos: Vector3i,
		enemy_reach: Dictionary, merc_name: String) -> void:
	if enemy_reach.is_empty() or enemy_reach.has(pos):
		return
	field.generation_log.append("[SPAWN] %s at (%d,%d) F%d outside the enemy reachable set" % [
		merc_name, pos.x, pos.y, pos.z])


#Legal spawn node: free, on the floor, off stairs, clear of blocking obstacles.
static func _spawnable(field: BattlefieldArea, passable_cells: Dictionary, cell: Vector3i,
		taken: Dictionary = {}, merc_size: int = 1) -> bool:
	if cell.x < 0 or cell.x >= field.width or cell.y < 0 or cell.y >= field.length:
		return false
	if not PathCost.floor_exists(field, cell.z):
		return false
	if taken.has(cell):
		return false
	var c2 := Vector2i(cell.x, cell.y)
	if field.is_stair_cell(c2, cell.z):
		return false
	if PathCost.is_landing_alias(cell, field):
		return false
	if PathCost.under_stair_blocked(cell, field, merc_size):
		return false
	if field.jagged_cells.has(c2):
		return false
	if field.is_obstacle(c2, cell.z):
		return false
	if PathCost.is_vault_cell(cell, field, merc_size):
		return false
	var obs: Dictionary = field.get_obs(c2, cell.z)
	if obs.get("cell_type", "") == "door" and not OpenCloseState.is_open(obs):
		return false
	return PathCost.has_exit_neighbor(cell, field, passable_cells, 1.0, false, true, merc_size)


#BFS outward from start on its own floor until a spawnable cell is found.
static func _walkable_center(field: BattlefieldArea, passable_cells: Dictionary, start: Vector3i) -> Vector3i:
	if _spawnable(field, passable_cells, start):
		return start
	var found := _bfs_spawnable(field, passable_cells, start, {}, 1)
	return start if found.x < 0 else found


#True when required_nb_set is empty or the cell touches one of its cells.
static func _touches_set(cell: Vector3i, required_nb_set: Dictionary) -> bool:
	if required_nb_set.is_empty():
		return true
	for d: Vector2i in PathCost.DIRS8:
		if required_nb_set.has(Vector3i(cell.x + d.x, cell.y + d.y, cell.z)):
			return true
	return false


#Unbounded BFS on the floor of start for a spawnable cell; (-1,-1,-1) when none.
static func _bfs_spawnable(field: BattlefieldArea, passable_cells: Dictionary, start: Vector3i,
		taken: Dictionary, merc_size: int) -> Vector3i:
	var visited: Dictionary = {start: true}
	var queue: Array[Vector3i] = [start]
	var qi := 0
	while qi < queue.size():
		var curr: Vector3i = queue[qi]
		qi += 1
		for d: Vector2i in PathCost.DIRS8:
			var nb := Vector3i(curr.x + d.x, curr.y + d.y, curr.z)
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if visited.has(nb):
				continue
			visited[nb] = true
			if _spawnable(field, passable_cells, nb, taken, merc_size):
				return nb
			queue.append(nb)
	return Vector3i(-1, -1, -1)


static func _find_free_cell(field: BattlefieldArea, passable_cells: Dictionary, start: Vector3i,
		fallback: Vector3i, required_nb_set: Dictionary = {}, taken: Dictionary = {},
		merc_size: int = 1, merc_name: String = "") -> Vector3i:
	if _spawnable(field, passable_cells, start, taken, merc_size) and _touches_set(start, required_nb_set):
		return start
	for radius: int in range(1, 5):
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				var c2 := field.clamp_position(Vector2i(start.x + dx, start.y + dy))
				var candidate := Vector3i(c2.x, c2.y, start.z)
				if not _spawnable(field, passable_cells, candidate, taken, merc_size):
					continue
				if _touches_set(candidate, required_nb_set):
					return candidate
	if not required_nb_set.is_empty():
		field.generation_log.append("[SPAWN] enemy-adjacency rule dropped for %s near (%d,%d) F%d" % [
			merc_name, start.x, start.y, start.z])
		return _find_free_cell(field, passable_cells, start, fallback, {}, taken, merc_size, merc_name)
	var wide := _bfs_spawnable(field, passable_cells, start, taken, merc_size)
	if wide.x >= 0:
		return wide
	field.generation_log.append("[SPAWN] no free cell for %s" % merc_name)
	return fallback
