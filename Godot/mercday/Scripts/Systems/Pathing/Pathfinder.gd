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

	var open: Dictionary = {}
	var heap: Array = []
	var closed: Dictionary = {}
	var exit_cache: Dictionary = {}

	var start_f: int = chebyshev(from, to)
	open[from] = {"g": 0, "f": start_f, "parent": Vector2i(-999, -999)}
	heap.append([start_f, from])

	var dirs: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]

	while not heap.is_empty():
		var top: Array = heap_pop(heap)
		var best: Vector2i = top[1]
		if closed.has(best):
			continue
		var node: Dictionary = open[best]
		open.erase(best)
		closed[best] = node

		if best == to:
			return reconstruct_path(closed, best, from)

		for d: Vector2i in dirs:
			var nb: Vector2i = best + d
			if nb.x < 0 or nb.x >= field.width or nb.y < 0 or nb.y >= field.length:
				continue
			if closed.has(nb):
				continue
			var cost: int = PathCost.cell_pace_cost(best, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb)
			if cost < 0:
				continue
			if nb != to:
				if not exit_cache.has(nb):
					exit_cache[nb] = PathCost.has_exit_neighbor(nb, field, passable_cells, merc_fall_tolerance, is_flying, dirs, can_climb)
				if not exit_cache[nb]:
					continue
			var g: int = node["g"] + cost
			if not open.has(nb) or g < (open[nb] as Dictionary)["g"]:
				var f: int = g + chebyshev(nb, to)
				open[nb] = {"g": g, "f": f, "parent": best}
				heap_insert(heap, [f, nb])

	var empty: Array[Vector2i] = []
	return empty


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


static func heap_insert(heap: Array, entry: Array) -> void:
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


static func heap_pop(heap: Array) -> Array:
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


static func reconstruct_path(closed: Dictionary, end: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var curr: Vector2i = end
	while curr != start:
		path.append(curr)
		var node: Dictionary = closed[curr]
		curr = node["parent"]
	path.append(start)
	path.reverse()
	return path
