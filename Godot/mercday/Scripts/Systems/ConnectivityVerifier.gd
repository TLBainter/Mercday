class_name ConnectivityVerifier

const DIRS8: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const DIRS4: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]


static func spawns_connected(area: BattlefieldArea) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	for seed_cell: Vector2i in area.spawn_zone_a.keys():
		if not area.is_obstacle(seed_cell) and not visited.has(seed_cell) \
				and _spawn_cell_has_exit(area, seed_cell, DIRS8):
			visited[seed_cell] = true
			queue.append(seed_cell)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if area.spawn_zone_b.has(curr):
			return true
		for d: Vector2i in DIRS8:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= area.width or nxt.y < 0 or nxt.y >= area.length:
				continue
			if visited.has(nxt):
				continue
			if not _spawn_step_ok(area, curr, nxt):
				continue
			if not area.spawn_zone_b.has(nxt) and not _spawn_cell_has_exit(area, nxt, DIRS8):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


static func carve_corridor(area: BattlefieldArea) -> void:
	var max_carve: int = (area.width + area.length) * 4
	var passes := 0
	while not spawns_connected(area) and passes < max_carve:
		var step_log: Array[String] = _carve_spawn_corridor_step(area)
		for entry: String in step_log:
			area.generation_log.append("Carve step %d: %s" % [passes + 1, entry.strip_edges()])
		passes += 1
	if not spawns_connected(area):
		push_warning("Hard guarantee pass: direct corridor carve between spawns")
		_carve_direct_corridor(area, area.spawn_center_a, area.spawn_center_b)
	area.generation_log.append("Connectivity: %s after %d carve step(s)" % [
		"CONNECTED" if spawns_connected(area) else "DISCONNECTED", passes])


static func remove_pockets(area: BattlefieldArea) -> void:
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = []
	for seed_cell: Vector2i in area.spawn_zone_a.keys():
		if not area.is_obstacle(seed_cell) and not reachable.has(seed_cell):
			reachable[seed_cell] = true
			queue.append(seed_cell)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS8:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= area.width or nxt.y < 0 or nxt.y >= area.length:
				continue
			if reachable.has(nxt):
				continue
			if not _spawn_step_ok(area, curr, nxt):
				continue
			reachable[nxt] = true
			queue.append(nxt)

	var pockets: Array[Vector2i] = []
	for y: int in range(area.length):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			if area._in_spawn_zone(pos):
				continue
			if not area.is_obstacle(pos) and not reachable.has(pos) \
					and not area.building_interiors.has(pos) and not area.jagged_cells.has(pos):
				pockets.append(pos)

	if pockets.is_empty():
		area.generation_log.append("Pocket check: no isolated walkable cells")
		return

	var carved := 0
	for pc: Vector2i in pockets:
		if reachable.has(pc):
			continue
		var best := Vector2i(-1, -1)
		var best_d := 9999
		for rc: Vector2i in reachable.keys():
			var cheby: int = maxi(absi(pc.x - rc.x), absi(pc.y - rc.y))
			if cheby < best_d:
				best_d = cheby
				best = rc
		if best == Vector2i(-1, -1):
			continue
		var cx := best.x
		var cy := best.y
		while Vector2i(cx, cy) != pc:
			if cx != pc.x:
				cx += signi(pc.x - cx)
			elif cy != pc.y:
				cy += signi(pc.y - cy)
			var step := Vector2i(cx, cy)
			_erase_cell(area, step)
			area.terrain_heights[step] = 0.0
			area.reserved_corridor_cells[step] = true
			reachable[step] = true
			carved += 1
		reachable[pc] = true

	area.generation_log.append("Pocket check: %d pocket cell(s) found, %d cell(s) carved to connect" % [pockets.size(), carved])


static func _spawn_step_ok(area: BattlefieldArea, from: Vector2i, to: Vector2i) -> bool:
	if to.x < 0 or to.x >= area.width or to.y < 0 or to.y >= area.length:
		return false
	if area.jagged_cells.has(to):
		return false
	var obs: Dictionary = area.get_obs(to, 0)
	if not obs.is_empty():
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			return false
		if ct == "door":
			if not OpenCloseState.is_open(obs):
				return false
		else:
			var d_data: ObstacleData = obs.get("data") as ObstacleData
			if d_data != null and not d_data.passthrough and not d_data.ramp:
				return false
	return not _step_blocked(area, from, to)


static func _spawn_cell_has_exit(area: BattlefieldArea, cell: Vector2i, dirs: Array[Vector2i]) -> bool:
	for d: Vector2i in dirs:
		if _spawn_step_ok(area, cell, cell + d):
			return true
	return false


static func _carve_spawn_corridor_step(area: BattlefieldArea) -> Array[String]:
	var spawn_a: Vector2i = area.spawn_center_a
	var spawn_b: Vector2i = area.spawn_center_b

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [spawn_a]
	visited[spawn_a] = true
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS8:
			var nxt: Vector2i = curr + d
			if visited.has(nxt):
				continue
			if not _spawn_step_ok(area, curr, nxt):
				continue
			if not _spawn_cell_has_exit(area, nxt, DIRS8):
				continue
			visited[nxt] = true
			queue.append(nxt)

	var best_pos := Vector2i(-1, -1)
	var best_score := INF

	for y: int in range(area.length):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			var obs: Dictionary = area.get_obs(pos, 0)
			var is_blocking: bool = _blocking_type(obs) != ""
			if not is_blocking:
				if not _spawn_cell_has_exit(area, pos, DIRS8):
					is_blocking = true
				elif _terrain_blocks(area, pos):
					is_blocking = true
				if not is_blocking:
					continue

			var adj_to_frontier := false
			for d: Vector2i in DIRS8:
				if visited.has(pos + d):
					adj_to_frontier = true
					break
			if not adj_to_frontier:
				continue

			var cheby_b: float = float(maxi(absi(x - spawn_b.x), absi(y - spawn_b.y)))

			var ax := float(spawn_a.x)
			var ay := float(spawn_a.y)
			var bx := float(spawn_b.x)
			var by_ := float(spawn_b.y)
			var px := float(x)
			var py := float(y)
			var seg_len := Vector2(bx - ax, by_ - ay).length()
			var perp_dist: float
			if seg_len < 0.001:
				perp_dist = Vector2(px - ax, py - ay).length()
			else:
				perp_dist = absf((by_ - ay) * px - (bx - ax) * py + bx * ay - by_ * ax) / seg_len

			var score := cheby_b * 10.0 + perp_dist
			if score < best_score:
				best_score = score
				best_pos = pos

	var carved_log: Array[String] = []
	if best_pos == Vector2i(-1, -1):
		return carved_log

	var delta: Vector2i = spawn_b - spawn_a
	var perp: Vector2i
	if abs(delta.y) >= abs(delta.x):
		perp = Vector2i(1, 0)
	else:
		perp = Vector2i(0, 1)

	var half_w: int = area.path_width >> 1
	var carve_candidates: Array[Vector2i] = _widen(best_pos, perp, half_w)

	for cp: Vector2i in carve_candidates:
		if cp.x < 0 or cp.x >= area.width or cp.y < 0 or cp.y >= area.length:
			continue
		if area.jagged_cells.has(cp):
			continue
		var cp_obs: Dictionary = area.get_obs(cp, 0)
		var cp_label: String = _blocking_type(cp_obs)
		var cp_blocking: bool = cp_label != ""
		var cp_prev_type: String = cp_label if cp_blocking else "terrain"
		if not cp_blocking:
			if not _spawn_cell_has_exit(area, cp, DIRS8) or _terrain_blocks(area, cp):
				cp_blocking = true
				cp_prev_type = "steep-terrain"
		if not cp_blocking:
			continue

		_erase_cell(area, cp)
		if cp_prev_type == "steep-terrain":
			var matched := false
			for d: Vector2i in DIRS4:
				var nb: Vector2i = cp + d
				if visited.has(nb):
					area.terrain_heights[cp] = area.terrain_heights.get(nb, 0.0)
					matched = true
					break
			if not matched:
				area.terrain_heights[cp] = 0.0
		else:
			area.terrain_heights[cp] = 0.0
		area.reserved_corridor_cells[cp] = true
		var label := "center" if cp == best_pos else ("wing+%d,%d" % [cp.x - best_pos.x, cp.y - best_pos.y])
		carved_log.append("  carve (%d,%d) [%s] prev=%s" % [cp.x, cp.y, label, cp_prev_type])

	return carved_log


static func _carve_direct_corridor(area: BattlefieldArea, from: Vector2i, to: Vector2i) -> void:
	var half_w: int = area.path_width >> 1
	var delta := to - from
	var perp: Vector2i
	if abs(delta.y) >= abs(delta.x):
		perp = Vector2i(1, 0)
	else:
		perp = Vector2i(0, 1)

	var cx: int = from.x
	var cy: int = from.y
	var steps: int = absi(to.y - from.y) + absi(to.x - from.x)
	for _s: int in range(steps + 1):
		var center := Vector2i(cx, cy)
		var candidates: Array[Vector2i] = _widen(center, perp, half_w)

		for cell: Vector2i in candidates:
			if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
				continue
			if area.jagged_cells.has(cell):
				continue
			_erase_cell(area, cell)
			area.terrain_heights[cell] = area.terrain_heights.get(from, 0.0)
			area.reserved_corridor_cells[cell] = true
			area.generation_log.append("Direct corridor carve (%d,%d)" % [cell.x, cell.y])

		if cx != to.x:
			cx += signi(to.x - cx)
		elif cy != to.y:
			cy += signi(to.y - cy)

	var final_connected: bool = spawns_connected(area)
	area.generation_log.append("Direct corridor result: %s" % ["CONNECTED" if final_connected else "STILL DISCONNECTED"])
	if not final_connected:
		push_warning("_carve_direct_corridor: spawns STILL disconnected after hard guarantee pass")


static func verify_spawn_approaches(area: BattlefieldArea) -> void:
	var total_carved := 0
	var zone_pairs: Array[Array] = [
		[area.spawn_zone_a, area.spawn_zone_b],
		[area.spawn_zone_b, area.spawn_zone_a],
	]
	for pair: Array in zone_pairs:
		var source_zone: Dictionary = pair[0] as Dictionary
		var target_zone: Dictionary = pair[1] as Dictionary
		var reachable: Dictionary = {}
		var queue: Array[Vector2i] = []
		var qi := 0
		for sz_cell: Vector2i in source_zone.keys():
			if not area.is_obstacle(sz_cell) and not reachable.has(sz_cell):
				reachable[sz_cell] = true
				queue.append(sz_cell)
		while qi < queue.size():
			var curr: Vector2i = queue[qi]
			qi += 1
			for d: Vector2i in DIRS8:
				var nb: Vector2i = curr + d
				if nb.x < 0 or nb.x >= area.width or nb.y < 0 or nb.y >= area.length:
					continue
				if reachable.has(nb):
					continue
				if PathCost.cell_pace_cost(
						Vector3i(curr.x, curr.y, 0), Vector3i(nb.x, nb.y, 0),
						area, {}, 1.0, false, true, 1) < 0:
					continue
				reachable[nb] = true
				queue.append(nb)
		for cell: Vector2i in target_zone.keys():
			if area.is_obstacle(cell):
				continue
			var has_reachable_nb := false
			for d: Vector2i in DIRS8:
				if reachable.has(cell + d):
					has_reachable_nb = true
					break
			if has_reachable_nb:
				continue
			var best_nb := Vector2i(-1, -1)
			var best_dist := 9999
			for d: Vector2i in DIRS8:
				var nb: Vector2i = cell + d
				if nb.x < 0 or nb.x >= area.width or nb.y < 0 or nb.y >= area.length:
					continue
				if area.jagged_cells.has(nb):
					continue
				for rc: Vector2i in reachable.keys():
					var cheby := maxi(absi(nb.x - rc.x), absi(nb.y - rc.y))
					if cheby < best_dist:
						best_dist = cheby
						best_nb = nb
			if best_nb == Vector2i(-1, -1):
				continue
			var nearest_rc := Vector2i(-1, -1)
			var nearest_d := 9999
			for rc: Vector2i in reachable.keys():
				var cheby := maxi(absi(best_nb.x - rc.x), absi(best_nb.y - rc.y))
				if cheby < nearest_d:
					nearest_d = cheby
					nearest_rc = rc
			if nearest_rc == Vector2i(-1, -1):
				continue
			var carve_h: float = area.terrain_heights.get(nearest_rc, 0.0)
			var cx := nearest_rc.x
			var cy := nearest_rc.y
			while Vector2i(cx, cy) != best_nb:
				if cx != best_nb.x:
					cx += signi(best_nb.x - cx)
				elif cy != best_nb.y:
					cy += signi(best_nb.y - cy)
				var step := Vector2i(cx, cy)
				if not area.jagged_cells.has(step) and not reachable.has(step):
					_erase_cell(area, step)
					area.terrain_heights[step] = carve_h
					area.reserved_corridor_cells[step] = true
					total_carved += 1
				reachable[step] = true
	area.generation_log.append("Spawn approach check: %d cell(s) carved" % total_carved)


#Clears one cell: obstacle map entry, obstacle array entries and building interior flag.
static func _erase_cell(area: BattlefieldArea, pos: Vector2i) -> void:
	area._obs_map.erase(pos)
	var idx: int = area.obstacles.size() - 1
	while idx >= 0:
		if (area.obstacles[idx]["pos"] as Vector2i) == pos:
			area.obstacles.remove_at(idx)
		idx -= 1
	area.building_interiors.erase(pos)


#One carve point widened across "perp", centre first so the carve loop keeps its visit order.
static func _widen(center: Vector2i, perp: Vector2i, half_w: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [center]
	for w: int in range(1, half_w + 1):
		out.append(center + perp * w)
		out.append(center - perp * w)
	if half_w == 0:
		out.append(center + perp)
		out.append(center - perp)
	return out


#Blocking label for an obstacle dict, or "" when the obstacle does not block movement.
static func _blocking_type(obs: Dictionary) -> String:
	if obs.is_empty():
		return ""
	var ct: String = obs.get("cell_type", "")
	if ct == "wall" or ct == "door":
		return ct
	if ct == "furniture":
		return ""
	var d_data: ObstacleData = obs.get("data") as ObstacleData
	if d_data != null and not d_data.passthrough and not d_data.ramp:
		return d_data.obstacle_name
	return ""


#True when the height step to any orthogonal neighbour is impassable.
static func _terrain_blocks(area: BattlefieldArea, pos: Vector2i) -> bool:
	for d: Vector2i in DIRS4:
		var nb: Vector2i = pos + d
		if nb.x < 0 or nb.x >= area.width or nb.y < 0 or nb.y >= area.length:
			continue
		if _step_blocked(area, nb, pos):
			return true
	return false


#True when the height step from "from" to "to" is impassable.
static func _step_blocked(area: BattlefieldArea, from: Vector2i, to: Vector2i) -> bool:
	var h_diff: float = area.get_terrain_height(to) - area.get_terrain_height(from)
	if h_diff > 0.5:
		return true
	if h_diff <= -1.0:
		if int(floor(-h_diff)) >= 4:
			return true
	elif absf(h_diff) > 0.25 and not area.has_stairs_at(to):
		return true
	return false
