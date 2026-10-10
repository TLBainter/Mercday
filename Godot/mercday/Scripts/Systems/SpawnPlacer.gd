class_name SpawnPlacer
extends RefCounted

#Places both teams on the battlefield at encounter start and logs the spawn choices.

#Batch option: each team spawns across its half of the floors instead of one floor per team.
static var spawn_floor_split: bool = false

#Walk budget a roof post's way down has to fit inside, and the flood cap one merc may spend looking.
const ROOF_EXIT_BUDGET: int = 60
const ROOF_EXIT_FLOODS: int = 8


static func assign(
		state: BattleState,
		team_a: Array[MercenaryData],
		team_b: Array[MercenaryData]) -> void:
	var field := state.battlefield
	var passable_cells: Dictionary = field.reserved_corridor_cells
	if field.is_cavern:
		_assign_floor_positions(state, field, passable_cells, team_a, team_b, 0, 0, true)
		return
	if field.is_dungeon:
		#Team A holds the Foyer, team B its own floor.
		_assign_floor_positions(state, field, passable_cells, team_a, team_b,
			field.spawn_floor_a, field.spawn_floor_b, false)
		return
	if field.is_city:
		_assign_city_positions(state, field, passable_cells, team_a, team_b)
		return
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
	var seed_a := Vector3i(field.width >> 1, 2, floor_a)
	var seed_b := Vector3i(field.width >> 1, field.length - 3, 0)
	#Exterior maps start each team at its generated centre, inside its generated zone.
	if not field.is_interior_map and not field.spawn_zone_a.is_empty() and not field.spawn_zone_b.is_empty():
		seed_a = Vector3i(field.spawn_center_a.x, field.spawn_center_a.y, 0)
		seed_b = Vector3i(field.spawn_center_b.x, field.spawn_center_b.y, 0)
	var center_a := _walkable_center(field, passable_cells, seed_a)
	var center_b := _walkable_center(field, passable_cells, seed_b)
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
	_log_centers(field, center_a, center_b)
	var taken: Dictionary = {}
	_place_team(state, field, passable_cells, team_a, center_a, reach_b, taken, zone_for(field.spawn_zone_a, center_a))
	_place_team(state, field, passable_cells, team_b, center_b, reach_a, taken, zone_for(field.spawn_zone_b, center_b))


#The generated zone when it holds the team's centre cell; {} (no zone limit) otherwise.
static func zone_for(zone: Dictionary, center: Vector3i) -> Dictionary:
	return zone if zone.has(Vector2i(center.x, center.y)) else {}


#Cavern and dungeon maps: the generator picks both centres and both zones; each team stays inside its own zone.
static func _assign_floor_positions(state: BattleState, field: BattlefieldArea, passable_cells: Dictionary,
		team_a: Array[MercenaryData], team_b: Array[MercenaryData], floor_a: int, floor_b: int,
		reset_water: bool) -> void:
	var pro: Array = _spawn_prologue(field, passable_cells, floor_a, floor_b, reset_water)
	_place_team(state, field, passable_cells, team_a, pro[0], pro[3], pro[4], field.spawn_zone_a)
	_place_team(state, field, passable_cells, team_b, pro[1], pro[2], pro[4], field.spawn_zone_b)


#City maps: a ranged-focused merc holds an upper window facing the enemy, the rest start on foot in the zone.
static func _assign_city_positions(state: BattleState, field: BattlefieldArea, passable_cells: Dictionary,
		team_a: Array[MercenaryData], team_b: Array[MercenaryData]) -> void:
	var pro: Array = _spawn_prologue(field, passable_cells, 0, 0, true)
	var taken: Dictionary = pro[4]
	var rosters: Array = [team_a, team_b]
	var centers: Array[Vector3i] = [pro[0] as Vector3i, pro[1] as Vector3i]
	var reaches: Array[Dictionary] = [pro[2] as Dictionary, pro[3] as Dictionary]
	var roof_part_at: Dictionary = roof_part_index(field)
	for t: int in range(2):
		var posts: Array[Vector3i] = CitySpawns.window_posts(field, t)
		var roofs: Array[Vector3i] = CitySpawns.roof_posts(field, t)
		var own_reach: Dictionary = reaches[t]
		var on_foot: Array[MercenaryData] = []
		for merc: MercenaryData in (rosters[t] as Array):
			var merc_size: int = merc.unit_size()
			var post := Vector3i(-1, -1, -1)
			var on_roof: bool = false
			if WeaponEvaluator.is_ranged_focused(merc):
				for cand: Vector3i in posts:
					if not own_reach.has(cand):
						continue
					if not _spawnable(field, passable_cells, cand, taken, merc_size):
						continue
					post = cand
					break
				if post.x < 0:
					post = _pick_roof_post(field, passable_cells, roofs, roof_part_at, taken, merc, merc_size)
					on_roof = post.x >= 0
			if post.x < 0:
				on_foot.append(merc)
				continue
			taken[post] = true
			_write_spawn(state, merc, post)
			if on_roof:
				field.generation_log.append("SPAWN POST: %s ROOF L%d (%d,%d)"
					% [merc.merc_name, post.z, post.x, post.y])
			else:
				field.generation_log.append("SPAWN POST: %s F%d (%d,%d)" % [merc.merc_name, post.z, post.x, post.y])
		_place_team(state, field, passable_cells, on_foot, centers[t], reaches[1 - t], taken,
			CitySpawns.outdoor_zone(field, t))


#First roof post this merc can stand on and leave again; logs the refusal and returns (-1,-1,-1) when none.
static func _pick_roof_post(field: BattlefieldArea, passable_cells: Dictionary, roofs: Array[Vector3i],
		roof_part_at: Dictionary, taken: Dictionary, merc: MercenaryData, merc_size: int) -> Vector3i:
	var floods: int = 0
	var refused: Dictionary = {}
	var denied: bool = false
	for roof: Vector3i in roofs:
		if not _spawnable(field, passable_cells, roof, taken, merc_size):
			continue
		var part_key: Variant = roof_part_at.get(roof, roof)
		if refused.has(part_key):
			continue
		if floods >= ROOF_EXIT_FLOODS:
			break
		floods += 1
		if not _can_leave_roof(field, passable_cells, roof, merc):
			refused[part_key] = true
			denied = true
			continue
		return roof
	if denied:
		field.generation_log.append("SPAWN POST: %s roof refused, no way down (size %d)"
			% [merc.merc_name, int(merc.stats.get("size", 1))])
	return Vector3i(-1, -1, -1)


#Roof cell -> its roof_parts row, so one refused part is not flooded once per cell it owns.
static func roof_part_index(field: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(field.roof_parts.size()):
		var part: Dictionary = field.roof_parts[i]
		var level: int = int(part.get("level", 0))
		for cell: Vector2i in (part.get("cells", []) as Array):
			out[Vector3i(cell.x, cell.y, level)] = i
	return out


#True when this unit can get itself off that roof: a route down to open ground inside a short walk
#budget, priced with its own flight, climb links and drop links.
static func _can_leave_roof(field: BattlefieldArea, passable_cells: Dictionary, roof: Vector3i,
		merc: MercenaryData) -> bool:
	var snap := PathCost.climb_snapshot()
	PathCost.set_climb(merc)
	var search := ReachSearch.create(roof, field, passable_cells,
		PathTargeter.fall_tolerance(merc), PathTargeter.is_flying(merc), true,
		int(merc.stats.get("jump", 0)),
		int(merc.stats.get("size", 1)), 0)
	var out: bool = search.ensure_until(ROOF_EXIT_BUDGET,
		func(cell: Vector3i) -> bool: return cell.z == 0 and not field.roof_cells.has(cell))
	PathCost.restore_climb(snap)
	return out


#Both spawn centres, both reachable sets and the shared taken set for one map type.
#Returns [center_a, center_b, reach_a, reach_b, taken]; reset_water is off where the map keeps its water cost.
static func _spawn_prologue(field: BattlefieldArea, passable_cells: Dictionary, floor_a: int,
		floor_b: int, reset_water: bool) -> Array:
	PathCost.set_door_penalty(0)
	if reset_water:
		PathCost.set_water_cost(null, null)
	var center_a := Vector3i(field.spawn_center_a.x, field.spawn_center_a.y, floor_a)
	var center_b := Vector3i(field.spawn_center_b.x, field.spawn_center_b.y, floor_b)
	var reach_a := PathTargeter.reachable_from(center_a, field, passable_cells, 1.0, false, true, 0, 1)
	var reach_b := PathTargeter.reachable_from(center_b, field, passable_cells, 1.0, false, true, 0, 1)
	_log_centers(field, center_a, center_b)
	return [center_a, center_b, reach_a, reach_b, {}]


static func _log_centers(field: BattlefieldArea, center_a: Vector3i, center_b: Vector3i) -> void:
	field.generation_log.append("SPAWN CENTER: Team 0 F%d (%d,%d)" % [center_a.z, center_a.x, center_a.y])
	field.generation_log.append("SPAWN CENTER: Team 1 F%d (%d,%d)" % [center_b.z, center_b.x, center_b.y])


#One team placed around its spawn centre, two RNG offsets drawn per merc in team order.
static func _place_team(state: BattleState, field: BattlefieldArea, passable_cells: Dictionary,
		team: Array[MercenaryData], center: Vector3i, enemy_reach: Dictionary,
		taken: Dictionary, zone: Dictionary = {}) -> void:
	for merc: MercenaryData in team:
		_place_one(state, field, passable_cells, merc, center, center.z, enemy_reach, taken, zone)


#One merc placed around a spawn centre; the two offset draws stay in caller order.
static func _place_one(state: BattleState, field: BattlefieldArea, passable_cells: Dictionary,
		merc: MercenaryData, center: Vector3i, target_floor: int, enemy_reach: Dictionary,
		taken: Dictionary, zone: Dictionary = {}) -> Vector3i:
	var merc_size: int = merc.unit_size()
	var offset := Vector2i(randi_range(-2, 2), randi_range(-2, 2))
	var start := field.clamp_position(Vector2i(center.x, center.y) + offset)
	var pos := _find_free_cell(field, passable_cells, Vector3i(start.x, start.y, target_floor),
		center, enemy_reach, taken, merc_size, merc.merc_name, zone)
	taken[pos] = true
	_log_unreachable_spawn(field, pos, enemy_reach, merc.merc_name)
	_write_spawn(state, merc, pos)
	return pos


#Stands a placed merc on the battle state at pos.
static func _write_spawn(state: BattleState, merc: MercenaryData, pos: Vector3i) -> void:
	state.positions[merc] = Vector2i(pos.x, pos.y)
	state.heights[merc] = 0
	state.floors[merc] = pos.z


#Moves one already-placed merc to a free cell touching the anchor; false when no such cell exists.
static func place_adjacent(state: BattleState, merc: MercenaryData, anchor: MercenaryData) -> bool:
	if state == null or merc == null or anchor == null:
		return false
	var field := state.battlefield
	if field == null:
		return false
	var passable_cells: Dictionary = field.reserved_corridor_cells
	var anchor_cell := state.pos3(anchor)
	var taken: Dictionary = {}
	for other: MercenaryData in state.positions.keys():
		if other != merc:
			taken[state.pos3(other)] = true
	var merc_size: int = merc.unit_size()
	var cell := _find_free_cell(field, passable_cells, anchor_cell, anchor_cell,
		{anchor_cell: true}, taken, merc_size, merc.merc_name, {})
	if cell == anchor_cell or taken.has(cell):
		return false
	state.set_pos3(merc, cell)
	state.set_height(merc, 0)
	return true


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
		var pos := _place_one(state, field, passable_cells, merc, center, f, enemy_reach, taken)
		field.generation_log.append("SPAWN CENTER: %s F%d (%d,%d)" % [merc.merc_name, pos.z, pos.x, pos.y])


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
	if not field.in_bounds_xy(cell.x, cell.y):
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
	#Nobody starts an encounter in a pool or bent double under a low roof.
	if field.is_cavern and (field.is_water(c2) or field.clearance(c2) < float(merc_size)):
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


#True when no zone was given or the cell belongs to it.
static func _in_zone(cell: Vector3i, zone: Dictionary) -> bool:
	if zone.is_empty():
		return true
	return zone.has(Vector2i(cell.x, cell.y))


#Unbounded BFS on the floor of start for a spawnable cell; (-1,-1,-1) when none.
#A non-empty zone narrows which cells may be returned, never which cells are searched through.
static func _bfs_spawnable(field: BattlefieldArea, passable_cells: Dictionary, start: Vector3i,
		taken: Dictionary, merc_size: int, zone: Dictionary = {}) -> Vector3i:
	var visited: Dictionary = {start: true}
	var queue: Array[Vector3i] = [start]
	var qi := 0
	while qi < queue.size():
		var curr: Vector3i = queue[qi]
		qi += 1
		for d: Vector2i in PathCost.DIRS8:
			var nb := Vector3i(curr.x + d.x, curr.y + d.y, curr.z)
			if not field.in_bounds_xy(nb.x, nb.y):
				continue
			if visited.has(nb):
				continue
			visited[nb] = true
			if _in_zone(nb, zone) and _spawnable(field, passable_cells, nb, taken, merc_size):
				return nb
			queue.append(nb)
	return Vector3i(-1, -1, -1)


static func _find_free_cell(field: BattlefieldArea, passable_cells: Dictionary, start: Vector3i,
		fallback: Vector3i, required_nb_set: Dictionary = {}, taken: Dictionary = {},
		merc_size: int = 1, merc_name: String = "", zone: Dictionary = {}) -> Vector3i:
	if _in_zone(start, zone) and _spawnable(field, passable_cells, start, taken, merc_size) \
			and _touches_set(start, required_nb_set):
		return start
	for radius: int in range(1, 5):
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				var c2 := field.clamp_position(Vector2i(start.x + dx, start.y + dy))
				var candidate := Vector3i(c2.x, c2.y, start.z)
				if not _in_zone(candidate, zone):
					continue
				if not _spawnable(field, passable_cells, candidate, taken, merc_size):
					continue
				if _touches_set(candidate, required_nb_set):
					return candidate
	if not zone.is_empty():
		var zoned := _bfs_spawnable(field, passable_cells, start, taken, merc_size, zone)
		if zoned.x >= 0:
			return zoned
		field.generation_log.append("[SPAWN] spawn zone full for %s near (%d,%d) F%d" % [
			merc_name, start.x, start.y, start.z])
		return _find_free_cell(field, passable_cells, start, fallback, required_nb_set, taken,
			merc_size, merc_name, {})
	if not required_nb_set.is_empty():
		field.generation_log.append("[SPAWN] enemy-adjacency rule dropped for %s near (%d,%d) F%d" % [
			merc_name, start.x, start.y, start.z])
		return _find_free_cell(field, passable_cells, start, fallback, {}, taken, merc_size, merc_name)
	var wide := _bfs_spawnable(field, passable_cells, start, taken, merc_size)
	if wide.x >= 0:
		return wide
	field.generation_log.append("[SPAWN] no free cell for %s" % merc_name)
	return fallback
