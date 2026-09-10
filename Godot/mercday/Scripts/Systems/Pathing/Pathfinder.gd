class_name Pathfinder

#Returns A* path [from, ..., to] over the battlefield grid; nodes are Vector3i(x, y, floor).
#Empty array = no path exists (completely blocked).
static func find_path(from: Vector3i, to: Vector3i, field: BattlefieldArea,
		passable_cells: Dictionary = {},
		merc_fall_tolerance: float = 1.0,
		is_flying: bool = false,
		can_climb: bool = false,
		merc_size: int = 1,
		altitude: int = 0,
		blocked_cells: Dictionary = {}) -> Array[Vector3i]:
	if from == to:
		var r: Array[Vector3i] = [from]
		return r

	var g_of: Dictionary = {from: 0}
	var parent_of: Dictionary = {}
	var alt_of: Dictionary = {from: altitude}
	var heap: Array = [[chebyshev(from, to), from]]
	var closed: Dictionary = {}

	while not heap.is_empty():
		var top: Array = heap_pop(heap)
		var best: Vector3i = top[1]
		if closed.has(best):
			continue
		closed[best] = true

		if best == to:
			return path_from_parents(parent_of, best, from)

		var node_alt: int = altitude
		if is_flying:
			node_alt = alt_of[best] as int
		var node_g: int = g_of[best] as int
		var best_entry: Array = PathCost.static_entry(field, best, merc_size)
		relax_neighbors(best, node_alt, node_g, best_entry, field, to, passable_cells,
			merc_fall_tolerance, is_flying, can_climb, merc_size, closed, blocked_cells,
			g_of, parent_of, alt_of, heap)

	var empty: Array[Vector3i] = []
	return empty


#Relaxes every neighbour of node into the search maps and heap; cells in blocked_cells are skipped.
static func relax_neighbors(node: Vector3i, node_alt: int, node_g: int, node_entry: Array,
		field: BattlefieldArea, to: Vector3i, passable_cells: Dictionary,
		merc_fall_tolerance: float, is_flying: bool, can_climb: bool, merc_size: int,
		closed: Dictionary, blocked_cells: Dictionary, g_of: Dictionary, parent_of: Dictionary,
		alt_of: Dictionary, heap: Array) -> void:
	for nb: Vector3i in PathCost.neighbors(node, field):
		if closed.has(nb):
			continue
		if blocked_cells.has(nb):
			continue
		var cost: int = PathCost.cell_pace_cost(node, nb, field, passable_cells, merc_fall_tolerance, is_flying, can_climb, merc_size, node_alt, node_entry)
		if cost < 0:
			continue
		var nb_alt: int = node_alt
		if is_flying:
			nb_alt = PathCost.fly_arrival_altitude(node, nb, field, node_alt)
		var g: int = node_g + cost
		if g_of.has(nb) and (g_of[nb] as int) <= g:
			continue
		g_of[nb] = g
		parent_of[nb] = node
		if is_flying:
			alt_of[nb] = nb_alt
		heap_insert(heap, [g + chebyshev(nb, to), nb])


#2D Chebyshev; admissible because stair links cost 1 per cell of 2D movement.
static func chebyshev(a: Vector3i, b: Vector3i) -> int:
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


#Path [start, ..., end] from a parent map written by a search that stores one parent per cell.
static func path_from_parents(parent_of: Dictionary, end: Vector3i, start: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var curr: Vector3i = end
	while curr != start:
		path.append(curr)
		curr = parent_of[curr] as Vector3i
	path.append(start)
	path.reverse()
	return path
