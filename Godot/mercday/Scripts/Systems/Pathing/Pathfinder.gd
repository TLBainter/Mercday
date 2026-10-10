class_name Pathfinder

#Blocked set for a search that blocks no cell; read only.
const NO_BLOCKED: Dictionary = {}

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
	var heap: Array = [[chebyshev(from, to), from, 0]]
	var closed: Dictionary = {}
	var goal_box := Rect2i(to.x, to.y, 0, 0)

	while true:
		var node: Array = pop_node(heap, closed, g_of, alt_of, is_flying, altitude)
		if node.is_empty():
			break
		var best: Vector3i = node[0] as Vector3i
		if best == to:
			return path_from_parents(parent_of, best, from)
		relax_neighbors(best, node[1] as int, node[2] as int, PathCost.static_entry(field, best, merc_size), field,
			goal_box, true, passable_cells, merc_fall_tolerance, is_flying, can_climb, merc_size,
			not is_flying and can_climb, closed, blocked_cells, g_of, parent_of, alt_of, heap)

	var empty: Array[Vector3i] = []
	return empty


#Pops entries until one holds a cell not yet closed and closes it: [cell, altitude, g], or [] once the heap is empty.
static func pop_node(heap: Array, closed: Dictionary, g_of: Dictionary, alt_of: Dictionary,
		is_flying: bool, altitude: int) -> Array:
	while not heap.is_empty():
		var top: Array = heap_pop(heap)
		var cell: Vector3i = top[1]
		if closed.has(cell):
			continue
		closed[cell] = true
		return [cell, (alt_of[cell] as int) if is_flying else altitude, g_of[cell] as int]
	return []


#Relaxes each neighbour of node into the maps and heap as [g + box gap, cell, g], skipping closed and blocked cells.
static func relax_neighbors(node: Vector3i, node_alt: int, node_g: int, node_entry: Array,
		field: BattlefieldArea, box: Rect2i, has_box: bool, passable_cells: Dictionary,
		merc_fall_tolerance: float, is_flying: bool, can_climb: bool, merc_size: int, leaps: bool,
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
		var g: int = node_g + cost
		if g_of.has(nb) and (g_of[nb] as int) <= g:
			continue
		g_of[nb] = g
		parent_of[nb] = node
		if is_flying:
			alt_of[nb] = PathCost.fly_arrival_altitude(node, nb, field, node_alt, merc_size)
		heap_insert(heap, [g + (box_gap(nb, box) if has_box else 0), nb, g])
	if not leaps:
		return
	#Roof to roof leaps are the walker's own edges: empty for a mover with no jump stat and off roofs.
	for row: Array in PathJump.roof_jumps(node, field, merc_size):
		var jnb: Vector3i = row[0] as Vector3i
		if closed.has(jnb) or blocked_cells.has(jnb):
			continue
		var jg: int = node_g + (row[1] as int)
		if g_of.has(jnb) and (g_of[jnb] as int) <= jg:
			continue
		g_of[jnb] = jg
		parent_of[jnb] = node
		heap_insert(heap, [jg + (box_gap(jnb, box) if has_box else 0), jnb, jg])


#2D Chebyshev; admissible because stair links cost 1 per cell of 2D movement.
static func chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(abs(a.x - b.x), abs(a.y - b.y))


static func chebyshev2(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


#2D Chebyshev distance from cell to box, position and end inclusive; 0 inside it.
static func box_gap(cell: Vector3i, box: Rect2i) -> int:
	var dx := maxi(0, maxi(box.position.x - cell.x, cell.x - box.end.x))
	var dy := maxi(0, maxi(box.position.y - cell.y, cell.y - box.end.y))
	return maxi(dx, dy)


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
