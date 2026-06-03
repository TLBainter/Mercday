class_name ConnectivityVerifier

const _SPAWN_BUFFER := 3


static func spawns_connected(area) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for seed_y: int in range(_SPAWN_BUFFER + 2):
		for seed_x: int in range(area.width):
			var seed_cell := Vector2i(seed_x, seed_y)
			if not area._is_obstacle_at(seed_cell) and not visited.has(seed_cell) \
					and _spawn_cell_has_exit(area, seed_cell, dirs):
				visited[seed_cell] = true
				queue.append(seed_cell)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		if curr.y >= area.length - _SPAWN_BUFFER - 2:
			return true
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if nxt.x < 0 or nxt.x >= area.width or nxt.y < 0 or nxt.y >= area.length:
				continue
			if visited.has(nxt):
				continue
			if not _spawn_step_ok(area, curr, nxt):
				continue
			if nxt.y < area.length - _SPAWN_BUFFER - 2 and not _spawn_cell_has_exit(area, nxt, dirs):
				continue
			visited[nxt] = true
			queue.append(nxt)
	return false


static func carve_corridor(area) -> void:
	var max_carve: int = (area.width + area.length) * 4
	var passes := 0
	while not spawns_connected(area) and passes < max_carve:
		var step_log: Array[String] = _carve_spawn_corridor_step(area)
		for entry: String in step_log:
			area.generation_log.append("Carve step %d: %s" % [passes + 1, entry.strip_edges()])
		passes += 1
	if not spawns_connected(area):
		push_warning("Hard guarantee pass: direct corridor carve between spawns")
		var spawn_a := Vector2i(area.width >> 1, 2)
		var spawn_b := Vector2i(area.width >> 1, area.length - 3)
		_carve_direct_corridor(area, spawn_a, spawn_b)
	area.generation_log.append("Connectivity: %s after %d carve step(s)" % [
		"CONNECTED" if spawns_connected(area) else "DISCONNECTED", passes])


static func remove_pockets(area) -> void:
	var dirs8: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = []
	for seed_y: int in range(_SPAWN_BUFFER + 2):
		for seed_x: int in range(area.width):
			var seed_cell := Vector2i(seed_x, seed_y)
			if not area._is_obstacle_at(seed_cell) and not reachable.has(seed_cell):
				reachable[seed_cell] = true
				queue.append(seed_cell)
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in dirs8:
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
	for y: int in range(_SPAWN_BUFFER, area.length - _SPAWN_BUFFER):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			if not area._is_obstacle_at(pos) and not reachable.has(pos) and not area.building_interiors.has(pos):
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
			area._obs_map.erase(step)
			var idx: int = area.obstacles.size() - 1
			while idx >= 0:
				if (area.obstacles[idx]["pos"] as Vector2i) == step:
					area.obstacles.remove_at(idx)
				idx -= 1
			area.building_interiors.erase(step)
			area.terrain_heights[step] = 0.0
			area.reserved_corridor_cells[step] = true
			reachable[step] = true
			carved += 1
		reachable[pc] = true

	area.generation_log.append("Pocket check: %d pocket cell(s) found, %d cell(s) carved to connect" % [pockets.size(), carved])


static func _spawn_step_ok(area, from: Vector2i, to: Vector2i) -> bool:
	if to.x < 0 or to.x >= area.width or to.y < 0 or to.y >= area.length:
		return false
	var obs: Dictionary = area.get_obstacle_at(to)
	if not obs.is_empty():
		var ct: String = obs.get("cell_type", "")
		if ct == "wall":
			return false
		if ct == "door":
			if not obs.get("door_open", false):
				return false
		else:
			var d_data: ObstacleData = obs.get("data") as ObstacleData
			if d_data != null and not d_data.passthrough and not d_data.ramp:
				return false
	var h_diff: float = area.get_terrain_height(to) - area.get_terrain_height(from)
	if h_diff > 0.5:
		return false
	if h_diff <= -1.0:
		if int(floor(-h_diff)) >= 4:
			return false
	elif absf(h_diff) > 0.25 and not area.has_stairs_at(to):
		return false
	return true


static func _spawn_cell_has_exit(area, cell: Vector2i, dirs: Array[Vector2i]) -> bool:
	for d: Vector2i in dirs:
		if _spawn_step_ok(area, cell, cell + d):
			return true
	return false


static func _carve_spawn_corridor_step(area) -> Array[String]:
	var spawn_a := Vector2i(area.width >> 1, 2)
	var spawn_b := Vector2i(area.width >> 1, area.length - 3)

	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [spawn_a]
	visited[spawn_a] = true
	var dirs8: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in dirs8:
			var nxt: Vector2i = curr + d
			if visited.has(nxt):
				continue
			if not _spawn_step_ok(area, curr, nxt):
				continue
			if not _spawn_cell_has_exit(area, nxt, dirs8):
				continue
			visited[nxt] = true
			queue.append(nxt)

	var best_pos := Vector2i(-1, -1)
	var best_score := INF

	for y: int in range(area.length):
		for x: int in range(area.width):
			var pos := Vector2i(x, y)
			var obs: Dictionary = area.get_obstacle_at(pos)
			var is_blocking := false
			if not obs.is_empty():
				var ct: String = obs.get("cell_type", "")
				if ct == "wall" or ct == "door":
					is_blocking = true
				elif ct != "furniture":
					var d_data: ObstacleData = obs.get("data") as ObstacleData
					if d_data != null and not d_data.passthrough and not d_data.ramp:
						is_blocking = true
			if not is_blocking:
				if not _spawn_cell_has_exit(area, pos, dirs8):
					is_blocking = true
				else:
					var dirs_t: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
					for d: Vector2i in dirs_t:
						var nb: Vector2i = pos + d
						if nb.x < 0 or nb.x >= area.width or nb.y < 0 or nb.y >= area.length:
							continue
						var h_diff: float = area.get_terrain_height(pos) - area.get_terrain_height(nb)
						var terrain_blocks: bool
						if h_diff > 0.5:
							terrain_blocks = true
						elif h_diff <= -1.0:
							terrain_blocks = int(floor(-h_diff)) >= 4
						elif absf(h_diff) > 0.25 and not area.has_stairs_at(pos):
							terrain_blocks = true
						else:
							terrain_blocks = false
						if terrain_blocks:
							is_blocking = true
							break
				if not is_blocking:
					continue

			var adj_to_frontier := false
			for d: Vector2i in dirs8:
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

	var delta := spawn_b - spawn_a
	var perp: Vector2i
	if abs(delta.y) >= abs(delta.x):
		perp = Vector2i(1, 0)
	else:
		perp = Vector2i(0, 1)

	var half_w: int = area.path_width >> 1
	var carve_candidates: Array[Vector2i] = [best_pos]
	for w: int in range(1, half_w + 1):
		carve_candidates.append(best_pos + perp * w)
		carve_candidates.append(best_pos - perp * w)
	if half_w == 0:
		carve_candidates.append(best_pos + perp)
		carve_candidates.append(best_pos - perp)

	for cp: Vector2i in carve_candidates:
		if cp.x < 0 or cp.x >= area.width or cp.y < 0 or cp.y >= area.length:
			continue
		var cp_obs: Dictionary = area.get_obstacle_at(cp)
		var cp_blocking := false
		var cp_prev_type := "terrain"
		if not cp_obs.is_empty():
			var ct: String = cp_obs.get("cell_type", "")
			if ct == "wall" or ct == "door":
				cp_blocking = true
				cp_prev_type = ct
			elif ct != "furniture":
				var d_data: ObstacleData = cp_obs.get("data") as ObstacleData
				if d_data != null and not d_data.passthrough and not d_data.ramp:
					cp_blocking = true
					cp_prev_type = d_data.obstacle_name if d_data != null else "obstacle"
		if not cp_blocking:
			if not _spawn_cell_has_exit(area, cp, dirs8):
				cp_blocking = true
				cp_prev_type = "steep-terrain"
			else:
				var dirs_t: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
				for d: Vector2i in dirs_t:
					var nb: Vector2i = cp + d
					if nb.x < 0 or nb.x >= area.width or nb.y < 0 or nb.y >= area.length:
						continue
					var h_diff: float = area.get_terrain_height(cp) - area.get_terrain_height(nb)
					var cp_terrain_blocks: bool
					if h_diff > 0.5:
						cp_terrain_blocks = true
					elif h_diff <= -1.0:
						cp_terrain_blocks = int(floor(-h_diff)) >= 4
					elif absf(h_diff) > 0.25 and not area.has_stairs_at(cp):
						cp_terrain_blocks = true
					else:
						cp_terrain_blocks = false
					if cp_terrain_blocks:
						cp_blocking = true
						cp_prev_type = "steep-terrain"
						break
		if not cp_blocking:
			continue

		area._obs_map.erase(cp)
		var idx: int = area.obstacles.size() - 1
		while idx >= 0:
			if (area.obstacles[idx]["pos"] as Vector2i) == cp:
				area.obstacles.remove_at(idx)
			idx -= 1
		area.building_interiors.erase(cp)
		if cp_prev_type == "steep-terrain":
			var dirs_c: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
			var matched := false
			for d: Vector2i in dirs_c:
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


static func _carve_direct_corridor(area, from: Vector2i, to: Vector2i) -> void:
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
		var candidates: Array[Vector2i] = [center]
		for w: int in range(1, half_w + 1):
			candidates.append(center + perp * w)
			candidates.append(center - perp * w)
		if half_w == 0:
			candidates.append(center + perp)
			candidates.append(center - perp)

		for cell: Vector2i in candidates:
			if cell.x < 0 or cell.x >= area.width or cell.y < 0 or cell.y >= area.length:
				continue
			area._obs_map.erase(cell)
			var idx: int = area.obstacles.size() - 1
			while idx >= 0:
				if (area.obstacles[idx]["pos"] as Vector2i) == cell:
					area.obstacles.remove_at(idx)
				idx -= 1
			area.building_interiors.erase(cell)
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
