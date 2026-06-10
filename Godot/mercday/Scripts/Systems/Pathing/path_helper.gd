class_name PathHelper

# Like Pathfinder.find_path, but when the goal is unreachable returns a path
# to the closest reachable cell by Chebyshev distance to goal.
# Returns [] only when no cell at all can be reached.
static func find_path_toward(from: Vector2i, to: Vector2i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false,
		jump_range: int = 0) -> Array[Vector2i]:
	var open: Dictionary = {}
	var heap: Array = []
	var closed: Dictionary = {}
	var exit_cache: Dictionary = {}
	var start_f2: int = Pathfinder.chebyshev(from, to)
	open[from] = {"g": 0, "f": start_f2, "parent": Vector2i(-999, -999)}
	heap.append([start_f2, from])

	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	var best_reachable := from
	var best_dist := Pathfinder.chebyshev(from, to)

	while not heap.is_empty():
		var top: Array = Pathfinder.heap_pop(heap)
		var curr: Vector2i = top[1]
		if closed.has(curr):
			continue
		var node: Dictionary = open[curr]
		open.erase(curr)
		closed[curr] = node

		var dist := Pathfinder.chebyshev(curr, to)
		if dist < best_dist:
			var has_fwd := false
			for fd: Vector2i in dirs:
				var fn: Vector2i = curr + fd
				if Pathfinder.chebyshev(fn, to) < dist and PathCost.cell_pace_cost(curr, fn, field, passable_cells, merc_fall_tolerance, is_flying, can_climb) >= 0:
					has_fwd = true
					break
			if has_fwd:
				best_dist = dist
				best_reachable = curr

		for d: Vector2i in dirs:
			var nb: Vector2i = curr + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if closed.has(nb):
				continue
			var cost: int = PathCost.cell_pace_cost(curr, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb)
			if cost < 0:
				continue
			if nb != to:
				if not exit_cache.has(nb):
					exit_cache[nb] = PathCost.has_exit_neighbor(nb, field, passable_cells, merc_fall_tolerance, is_flying, dirs, can_climb)
				if not exit_cache[nb]:
					continue
			var g: int = node["g"] + cost
			if not open.has(nb) or g < (open[nb] as Dictionary)["g"]:
				var f2: int = g + Pathfinder.chebyshev(nb, to)
				open[nb] = {"g": g, "f": f2, "parent": curr}
				Pathfinder.heap_insert(heap, [f2, nb])

	if jump_range > 0:
		for cell: Vector2i in closed.keys():
			var cell_h: float = field.get_terrain_height(cell)
			for dx: int in range(-jump_range, jump_range + 1):
				for dy: int in range(-jump_range, jump_range + 1):
					var chebyshev_dist := maxi(abs(dx), abs(dy))
					if chebyshev_dist == 0 or chebyshev_dist > jump_range:
						continue
					var jcell := cell + Vector2i(dx, dy)
					if not PathCost.is_valid_jump_dest(jcell, field):
						continue
					if closed.has(jcell):
						continue
					var h_cost := int(ceil(maxf(0.0, field.get_terrain_height(jcell) - cell_h)))
					if chebyshev_dist + h_cost > jump_range:
						continue
					var jdist := Pathfinder.chebyshev(jcell, to)
					if jdist < best_dist:
						best_dist = jdist
						best_reachable = cell

	if best_reachable == from:
		var empty: Array[Vector2i] = []
		return empty
	return Pathfinder.reconstruct_path(closed, best_reachable, from)


# BFS search in a 3-cell radius for the nearest passable cell to pos.
# Returns pos itself if already passable.
static func nearest_passable_to(pos: Vector2i, field: BattlefieldArea,
		p_fall_tolerance: float = 1.0, p_can_climb: bool = false,
		p_excluded: Dictionary = {}) -> Vector2i:
	var cardinals: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
	]
	var all_dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var is_passable := func(cell: Vector2i) -> bool:
		for cd: Vector2i in cardinals:
			var nb: Vector2i = cell + cd
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if PathCost.cell_pace_cost(nb, cell, field, {}, p_fall_tolerance, false, p_can_climb) >= 0:
				return true
		return false

	if is_passable.call(pos) and not p_excluded.has(pos):
		return pos

	var visited: Dictionary = {pos: true}
	var queue: Array[Vector2i] = [pos]
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in all_dirs:
			var nb: Vector2i = curr + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if visited.has(nb):
				continue
			visited[nb] = true
			if is_passable.call(nb) and not p_excluded.has(nb):
				return nb
			if maxi(abs(nb.x - pos.x), abs(nb.y - pos.y)) < 3:
				queue.append(nb)
	return pos
