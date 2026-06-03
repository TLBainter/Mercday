class_name Pathfinder

# Returns A* path [from, ..., to] over the battlefield grid.
# Empty array = no path exists (completely blocked).
static func find_path(from: Vector2i, to: Vector2i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false) -> Array[Vector2i]:
	if from == to:
		var r: Array[Vector2i] = [from]
		return r

	# open: pos -> {g, f, parent}; heap: [[f, pos], ...] as binary min-heap
	var open: Dictionary = {}
	var heap: Array = []
	var closed: Dictionary = {}
	var exit_cache: Dictionary = {}

	var start_f: int = _h(from, to)
	open[from] = {"g": 0, "f": start_f, "parent": Vector2i(-999, -999)}
	heap.append([start_f, from])

	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var best: Vector2i = top[1]
		if closed.has(best):
			continue  # stale heap entry
		var node: Dictionary = open[best]
		open.erase(best)
		closed[best] = node

		if best == to:
			return _reconstruct(closed, best, from)

		for d: Vector2i in dirs:
			var nb: Vector2i = best + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if closed.has(nb):
				continue
			var cost: int = cell_pace_cost(best, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb)
			if cost < 0:
				continue  # impassable
			if nb != to:
				if not exit_cache.has(nb):
					exit_cache[nb] = _has_exit(nb, field, passable_cells, merc_fall_tolerance, is_flying, dirs, can_climb)
				if not exit_cache[nb]:
					continue  # one-way pit: enterable but no way out
			var g: int = node["g"] + cost
			if not open.has(nb) or g < (open[nb] as Dictionary)["g"]:
				var f: int = g + _h(nb, to)
				open[nb] = {"g": g, "f": f, "parent": best}
				_heap_insert(heap, [f, nb])

	var empty: Array[Vector2i] = []
	return empty


# Pace cost to enter `to` from `from`. -1 = impassable.
static func cell_pace_cost(from: Vector2i, to: Vector2i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false) -> int:
	if is_flying:
		return 1  # flying mercs treat all in-bounds cells as cost 1

	if passable_cells.has(to):
		var h_diff_pc: float = field.get_terrain_height(to) - field.get_terrain_height(from)
		if h_diff_pc > 0.5:
			if h_diff_pc <= 1.0:
				return 3  # single-level step-up: all mercs
			if not can_climb or h_diff_pc > 2.0:
				return -1
			return 3  # climb cost on corridor cell
		if h_diff_pc <= -1.0:
			var fall_paces_pc := int(floor(-h_diff_pc))
			var fall_severity_pc: float = float(fall_paces_pc) / merc_fall_tolerance
			if fall_severity_pc >= 4.0:
				return -1
		elif absf(h_diff_pc) > 0.25 and not field.has_stairs_at(to):
			return -1
		return 1
	var obs: Dictionary = field.get_obstacle_at(to)
	var base_cost: int

	if obs.is_empty():
		base_cost = 1  # open ground or building interior
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
				base_cost = 1  # handled further below with height logic
			elif not data.passthrough:
				return -1
			elif data.pt_enter_harm > 0 or data.pt_exit_harm > 0:
				# Hazardous passthrough -- crossable but strongly penalised
				base_cost = 10
			else:
				base_cost = 2 if data.rugged else 1

	var h_diff: float = field.get_terrain_height(to) - field.get_terrain_height(from)

	if h_diff > 0.5:
		if h_diff <= 1.0:
			return base_cost + 2  # single-level step-up: all mercs
		elif not can_climb or h_diff > 2.0:
			return -1
		else:
			base_cost += 2  # climbing penalty for steep terrain

	if h_diff <= -1.0:
		var fall_paces := int(floor(-h_diff))
		var fall_severity: float = float(fall_paces) / merc_fall_tolerance
		if fall_severity >= 4.0:
			return -1  # too dangerous given this merc's condition
		base_cost += int(ceil(fall_paces * 4.0 / merc_fall_tolerance))

	elif absf(h_diff) > 0.25:
		if not field.has_stairs_at(to):
			return -1   # moderate slope with no stairs
		if h_diff > 0.0:
			base_cost += 1              # rugged going up stairs
		else:
			base_cost = maxi(0, base_cost - 1)  # slight discount going down

	return base_cost


# Like find_path, but when goal is unreachable returns a path to the closest
# reachable cell (by Chebyshev distance to goal). Returns [] only when no cell
# at all can be reached (completely sealed map).
static func find_path_toward(from: Vector2i, to: Vector2i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false,
		jump_range: int = 0) -> Array[Vector2i]:
	# Caller already attempted find_path; skip straight to BFS flood-fill to closest reachable cell.
	var open: Dictionary = {}
	var heap: Array = []
	var closed: Dictionary = {}
	var exit_cache: Dictionary = {}
	var start_f2: int = _h(from, to)
	open[from] = {"g": 0, "f": start_f2, "parent": Vector2i(-999, -999)}
	heap.append([start_f2, from])

	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	var best_reachable := from
	var best_dist := _h(from, to)

	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var curr: Vector2i = top[1]
		if closed.has(curr):
			continue  # stale heap entry
		var node: Dictionary = open[curr]
		open.erase(curr)
		closed[curr] = node

		var dist := _h(curr, to)
		if dist < best_dist:
			var _has_fwd := false
			for _fd: Vector2i in dirs:
				var _fn: Vector2i = curr + _fd
				if _h(_fn, to) < dist and cell_pace_cost(curr, _fn, field, passable_cells, merc_fall_tolerance, is_flying, can_climb) >= 0:
					_has_fwd = true
					break
			if _has_fwd:
				best_dist = dist
				best_reachable = curr

		for d: Vector2i in dirs:
			var nb: Vector2i = curr + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if closed.has(nb):
				continue
			var cost: int = cell_pace_cost(curr, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb)
			if cost < 0:
				continue
			if nb != to:
				if not exit_cache.has(nb):
					exit_cache[nb] = _has_exit(nb, field, passable_cells, merc_fall_tolerance, is_flying, dirs, can_climb)
				if not exit_cache[nb]:
					continue  # one-way pit: enterable but no way out
			var g: int = node["g"] + cost
			if not open.has(nb) or g < (open[nb] as Dictionary)["g"]:
				var f2: int = g + _h(nb, to)
				open[nb] = {"g": g, "f": f2, "parent": curr}
				_heap_insert(heap, [f2, nb])

	# Jump extension: from every walk-reachable cell, probe cells reachable by jumping.
	# If any jump destination is closer to `to`, update best_reachable to the launch cell
	# so the caller walks there and JumpAction handles the rest next slot.
	if jump_range > 0:
		for cell: Vector2i in closed.keys():
			var cell_h: float = field.get_terrain_height(cell)
			for dx: int in range(-jump_range, jump_range + 1):
				for dy: int in range(-jump_range, jump_range + 1):
					var chebyshev := maxi(abs(dx), abs(dy))
					if chebyshev == 0 or chebyshev > jump_range:
						continue
					var jcell := cell + Vector2i(dx, dy)
					if not is_valid_jump_dest(jcell, field):
						continue
					if closed.has(jcell):
						continue  # already walk-reachable
					var h_cost := int(ceil(maxf(0.0, field.get_terrain_height(jcell) - cell_h)))
					if chebyshev + h_cost > jump_range:
						continue
					var jdist := _h(jcell, to)
					if jdist < best_dist:
						best_dist = jdist
						best_reachable = cell  # walk to launch cell; jump handles the last gap

	if best_reachable == from:
		var empty: Array[Vector2i] = []
		return empty
	return _reconstruct(closed, best_reachable, from)


static func _has_exit(cell: Vector2i, field: BattlefieldArea,
		passable_cells: Dictionary, merc_fall_tolerance: float,
		is_flying: bool, dirs: Array[Vector2i],
		can_climb: bool = false) -> bool:
	for d: Vector2i in dirs:
		var nb: Vector2i = cell + d
		if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
			continue
		if cell_pace_cost(cell, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb) >= 0:
			return true
	return false


static func _h(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))  # Chebyshev


static func _heap_insert(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if (heap[parent] as Array)[0] <= (heap[i] as Array)[0]:
			break
		var tmp: Array = heap[parent]
		heap[parent] = heap[i]
		heap[i] = tmp
		i = parent


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last_idx := heap.size() - 1
	heap[0] = heap[last_idx]
	heap.resize(last_idx)
	var i := 0
	var n := heap.size()
	while true:
		var left := 2 * i + 1
		var right := 2 * i + 2
		var smallest := i
		if left < n and (heap[left] as Array)[0] < (heap[smallest] as Array)[0]:
			smallest = left
		if right < n and (heap[right] as Array)[0] < (heap[smallest] as Array)[0]:
			smallest = right
		if smallest == i:
			break
		var tmp: Array = heap[smallest]
		heap[smallest] = heap[i]
		heap[i] = tmp
		i = smallest
	return top


# Returns true if a merc can land on this cell during a jump (not a wall or solid obstacle).
static func is_valid_jump_dest(pos: Vector2i, field: BattlefieldArea) -> bool:
	if pos.x < 0 or pos.x >= field.width or pos.y < 0 or pos.y >= field.length:
		return false
	var obs: Dictionary = field.get_obstacle_at(pos)
	if obs.is_empty():
		return true
	var cell_type: String = obs.get("cell_type", "")
	if cell_type == "wall":
		return false
	if cell_type == "door":
		return obs.get("door_open", false)
	var data: ObstacleData = obs.get("data") as ObstacleData
	return data == null or data.passthrough or data.ramp


static func _reconstruct(closed: Dictionary, end: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var curr: Vector2i = end
	while curr != start:
		path.append(curr)
		var node: Dictionary = closed[curr]
		curr = node["parent"]
	path.append(start)
	path.reverse()
	return path
