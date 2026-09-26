class_name ReachSearch
extends RefCounted

#Flood from one cell with one mover's capabilities, grown on demand; walk costs are minimal.
#create(from, field, passable, fall_tolerance, flying, can_climb, jump_range, merc_size, altitude)
#result: Vector3i -> minimal pace cost; jump-only nodes cost >= JUMP_COST_OFFSET.
#ensure_cost(limit): cost-ordered growth; settles every walk cell costing at most limit and publishes the
#jumps from every settled cell costing at most limit.
#ensure_cells(cells, limit, slack, max_settled): growth ordered by cost plus the 2D Chebyshev distance to
#the box around the listed cells, until each is settled, the flood runs out, or the heap key passes limit
#(or the first listed settle plus slack) by more than jump_range. Publishes no jumps while growing; a
#listed cell still unsettled at the end gets the best jump onto it from the settled cells within jump
#range. max_settled >= 0 stops the growth at that many settled cells and sets capped.
#ensure_until(limit, stop): cost-ordered growth that returns true at the first settled result cell stop
#takes, false once the cost limit or the flood runs out.
#nearest_settled_to(cells): the walk-settled cell closest to the box around cells; box_distance measures
#any cell against that box.
#ensure_all(): settle the whole reachable component, cost-ordered.
#walk_path(cell): the flood's walk path [from, ..., cell] once cell is walk-settled, else [].
#settled_limit: every walk cell at or below it is settled. exhausted: the flood has no cells left.

#Mirrors PathTargeter.JUMP_COST_OFFSET; held locally so the two classes stay one-directional.
const JUMP_COST_OFFSET := 1000

var result: Dictionary = {}
var settled_limit: int = -1
var exhausted: bool = false
#True when the last ensure_cells call stopped on its max_settled bound rather than on the listed cells.
var capped: bool = false
#Walk cells the flood held when its owner first grew it to the turn's reach budget; -1 until set there.
var near_cells: int = -1

var _from: Vector3i = Vector3i.ZERO
var _field: BattlefieldArea = null
var _passable: Dictionary = {}
var _fall_tolerance: float = 1.0
var _flying: bool = false
var _can_climb: bool = false
var _jump_range: int = 0
var _merc_size: int = 1
var _altitude: int = 0
var _tentative: Dictionary = {}
var _settled: Dictionary = {}
var _alt_at: Dictionary = {}
var _parent: Dictionary = {}
#Entries [key, cell, cost]; key is the cost plus the box distance while a box is set.
var _heap: Array = []
var _box_set: bool = false
var _bx0: int = 0
var _bx1: int = 0
var _by0: int = 0
var _by1: int = 0
#Cells settled under a box; their jumps are published once ensure_cost or ensure_all reaches their cost.
var _unpublished: Array[Vector3i] = []
#The one cell the last _settle_top call settled, and whether that call settled one at all.
var _last_settled: Vector3i = Vector3i.ZERO
var _did_settle: bool = false


static func create(
		from: Vector3i,
		field: BattlefieldArea,
		passable: Dictionary,
		fall_tolerance: float,
		flying: bool,
		can_climb: bool,
		jump_range: int = 0,
		merc_size: int = 1,
		altitude: int = 0) -> ReachSearch:
	var search := ReachSearch.new()
	search.init(from, field, passable, fall_tolerance, flying, can_climb, jump_range, merc_size, altitude)
	return search


func init(
		from: Vector3i,
		field: BattlefieldArea,
		passable: Dictionary,
		fall_tolerance: float,
		flying: bool,
		can_climb: bool,
		jump_range: int = 0,
		merc_size: int = 1,
		altitude: int = 0) -> void:
	_from = from
	_field = field
	_passable = passable
	_fall_tolerance = fall_tolerance
	_flying = flying
	_can_climb = can_climb
	_jump_range = maxi(0, jump_range)
	_merc_size = merc_size
	_altitude = altitude
	_tentative = {from: 0}
	_alt_at = {from: altitude}
	_settled = {}
	_parent = {}
	_heap = []
	_box_set = false
	_unpublished = []
	result = {from: 0}
	settled_limit = -1
	exhausted = false
	capped = false
	near_cells = -1
	Pathfinder.heap_insert(_heap, [0, from, 0])


func ensure_cost(limit: int) -> void:
	if limit > settled_limit:
		_set_box([])
		_publish_up_to(limit)
		if not exhausted:
			while not _heap.is_empty() and ((_heap[0] as Array)[0] as int) <= limit:
				_settle_top()
			if _heap.is_empty():
				exhausted = true
	settled_limit = maxi(settled_limit, limit)


#A jump-published cell is not settled: growth continues until a walk path to it is known or ruled out.
func ensure_cells(cells: Array, limit: int = -1, slack: int = -1, max_settled: int = -1) -> void:
	capped = false
	var pending: Array[Vector3i] = []
	for cell: Vector3i in cells:
		if not _settled.has(cell):
			pending.append(cell)
	if pending.is_empty():
		return
	_set_box(pending)
	var want: Dictionary = {}
	for cell: Vector3i in pending:
		want[cell] = true
	var bound: int = limit
	while not _heap.is_empty():
		var top_key: int = (_heap[0] as Array)[0] as int
		if bound >= 0 and top_key > bound + _jump_range:
			break
		if max_settled >= 0 and _settled.size() >= max_settled:
			capped = true
			break
		_settle_top()
		if _did_settle and want.has(_last_settled):
			want.erase(_last_settled)
			if slack >= 0:
				bound = top_key + slack if bound < 0 else mini(bound, top_key + slack)
		if want.is_empty():
			break
	if _heap.is_empty():
		exhausted = true
	var left: Array[Vector3i] = []
	for cell: Vector3i in pending:
		if want.has(cell):
			left.append(cell)
	_jump_onto(left)


func ensure_all() -> void:
	_set_box([])
	_publish_up_to(-1)
	while not _heap.is_empty():
		_settle_top()
	exhausted = true


#Cost-ordered growth that stops at the first standable cell stop takes; settled_limit is left alone.
func ensure_until(limit: int, stop: Callable) -> bool:
	_set_box([])
	_publish_up_to(limit)
	while not _heap.is_empty() and (limit < 0 or ((_heap[0] as Array)[0] as int) <= limit):
		_settle_top()
		if _did_settle and result.has(_last_settled) and bool(stop.call(_last_settled)):
			return true
	if _heap.is_empty():
		exhausted = true
	return false


#The walk-settled cell nearest the box around cells; ties go to the lower cost, then the first found.
func nearest_settled_to(cells: Array) -> Vector3i:
	var best := Vector3i(-1, -1, -1)
	if cells.is_empty():
		return best
	var box := _box_of(cells)
	var best_gap: int = -1
	var best_cost: int = -1
	for key: Variant in result.keys():
		var cell: Vector3i = key as Vector3i
		var cost: int = result[cell] as int
		if cost >= JUMP_COST_OFFSET or not _settled.has(cell):
			continue
		var gap := _box_gap(cell, box)
		if best_gap < 0 or gap < best_gap or (gap == best_gap and cost < best_cost):
			best = cell
			best_gap = gap
			best_cost = cost
	return best


#2D Chebyshev distance from cell to the box around cells; 0 when nothing is listed.
func box_distance(cell: Vector3i, cells: Array) -> int:
	if cells.is_empty():
		return 0
	return _box_gap(cell, _box_of(cells))


func walk_path(cell: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	if cell == _from:
		path.append(_from)
		return path
	if not _settled.has(cell):
		return path
	return Pathfinder.path_from_parents(_parent, cell, _from)


#Vault cells can be crossed but never stood on, and a flyer may not stop on a flyover cell.
func _excluded(cell: Vector3i) -> bool:
	if PathCost.static_entry(_field, cell, _merc_size)[PathCost.SE_VAULT_CELL]:
		return true
	return _flying and PathCost.is_flyover_cell(cell, _field)


#2D Chebyshev distance from cell to the box; 0 without a box or inside it.
func _h(cell: Vector3i) -> int:
	if not _box_set:
		return 0
	var dx := maxi(0, maxi(_bx0 - cell.x, cell.x - _bx1))
	var dy := maxi(0, maxi(_by0 - cell.y, cell.y - _by1))
	return maxi(dx, dy)


#The 2D box around cells, position and end inclusive; the caller checks for an empty list.
func _box_of(cells: Array) -> Rect2i:
	var first: Vector3i = cells[0] as Vector3i
	var box := Rect2i(first.x, first.y, 0, 0)
	for c: Vector3i in cells:
		box = box.expand(Vector2i(c.x, c.y))
	return box


#2D Chebyshev distance from cell to box; 0 inside it.
func _box_gap(cell: Vector3i, box: Rect2i) -> int:
	var dx := maxi(0, maxi(box.position.x - cell.x, cell.x - box.end.x))
	var dy := maxi(0, maxi(box.position.y - cell.y, cell.y - box.end.y))
	return maxi(dx, dy)


#Sets the box around cells (none when empty) and re-keys the heap when the box changed.
func _set_box(cells: Array) -> void:
	if cells.is_empty():
		if not _box_set:
			return
		_box_set = false
		_rekey()
		return
	var box := _box_of(cells)
	if _box_set and box.position.x == _bx0 and box.end.x == _bx1 \
			and box.position.y == _by0 and box.end.y == _by1:
		return
	_box_set = true
	_bx0 = box.position.x
	_bx1 = box.end.x
	_by0 = box.position.y
	_by1 = box.end.y
	_rekey()


#Rebuilds the heap under the current key, dropping settled and stale entries; a sorted array is a valid heap.
func _rekey() -> void:
	var old: Array = _heap
	_heap = []
	for entry: Array in old:
		var cell: Vector3i = entry[1] as Vector3i
		var cost: int = entry[2] as int
		if _settled.has(cell) or cost > (_tentative.get(cell, cost) as int):
			continue
		_heap.append([cost + _h(cell), cell, cost])
	_heap.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as int) < (b[0] as int))


#Publishes the jumps from cells settled under a box whose cost is at most limit (every one when limit < 0).
func _publish_up_to(limit: int) -> void:
	if _jump_range <= 0 or _unpublished.is_empty():
		return
	var kept: Array[Vector3i] = []
	for cell: Vector3i in _unpublished:
		var cost: int = _tentative[cell] as int
		if limit >= 0 and cost > limit:
			kept.append(cell)
		else:
			_jump_from(cell, cost)
	_unpublished = kept


func _settle_top() -> void:
	_did_settle = false
	var top: Array = Pathfinder.heap_pop(_heap)
	var cell: Vector3i = top[1] as Vector3i
	var cost: int = top[2] as int
	if _settled.has(cell) or cost > (_tentative.get(cell, cost) as int):
		return
	_settled[cell] = true
	_last_settled = cell
	_did_settle = true
	if cell == _from or not _excluded(cell):
		result[cell] = cost
	elif result.has(cell):
		result.erase(cell)
	var curr_alt: int = _altitude
	if _flying:
		curr_alt = _alt_at.get(cell, _altitude) as int
	var from_entry: Array = PathCost.static_entry(_field, cell, _merc_size)
	for nb: Vector3i in PathCost.neighbors(cell, _field):
		if _settled.has(nb):
			continue
		var edge := PathCost.cell_pace_cost(cell, nb, _field, _passable, _fall_tolerance, _flying, _can_climb, _merc_size, curr_alt, from_entry)
		if edge < 0:
			continue
		var nc := cost + edge
		if _tentative.has(nb) and (_tentative[nb] as int) <= nc:
			continue
		_tentative[nb] = nc
		_parent[nb] = cell
		if _flying:
			_alt_at[nb] = PathCost.fly_arrival_altitude(cell, nb, _field, curr_alt, _merc_size)
		Pathfinder.heap_insert(_heap, [nc + _h(nb), nb, nc])
	if not _flying:
		#Roof to roof leaps are walk edges, not terminal jump nodes: the route goes on from the landing.
		for row: Array in PathCost.roof_jumps(cell, _field, _merc_size):
			var jnb: Vector3i = row[0] as Vector3i
			if _settled.has(jnb):
				continue
			var jc: int = cost + (row[1] as int)
			if _tentative.has(jnb) and (_tentative[jnb] as int) <= jc:
				continue
			_tentative[jnb] = jc
			_parent[jnb] = cell
			Pathfinder.heap_insert(_heap, [jc + _h(jnb), jnb, jc])
	if _jump_range > 0:
		if _box_set:
			_unpublished.append(cell)
		else:
			_jump_from(cell, cost)


#Jump destinations are terminal: published, never expanded from, overwritten once a walk settles the cell.
func _jump_from(cell: Vector3i, cost: int) -> void:
	for dest: Array in PathCost.jump_dests(_field, cell, _jump_range, _merc_size):
		var jcell: Vector3i = dest[0] as Vector3i
		if _settled.has(jcell):
			continue
		var jcost: int = cost + JUMP_COST_OFFSET + (dest[1] as int)
		if result.has(jcell) and (result[jcell] as int) <= jcost:
			continue
		if PathCost.jump_row_blocked(dest):
			continue
		if not _excluded(jcell):
			result[jcell] = jcost


#Best jump onto each listed cell still unsettled, from the settled cells within jump range on its floor.
func _jump_onto(cells: Array[Vector3i]) -> void:
	if _jump_range <= 0:
		return
	for target: Vector3i in cells:
		if _settled.has(target):
			continue
		var best: int = -1
		for dx: int in range(-_jump_range, _jump_range + 1):
			for dy: int in range(-_jump_range, _jump_range + 1):
				if dx == 0 and dy == 0:
					continue
				var src := Vector3i(target.x + dx, target.y + dy, target.z)
				if not _settled.has(src):
					continue
				for dest: Array in PathCost.jump_dests(_field, src, _jump_range, _merc_size):
					if (dest[0] as Vector3i) != target:
						continue
					if PathCost.jump_row_blocked(dest):
						continue
					var jcost: int = (_tentative[src] as int) + JUMP_COST_OFFSET + (dest[1] as int)
					if best < 0 or jcost < best:
						best = jcost
		if best < 0 or _excluded(target):
			continue
		if not result.has(target) or (result[target] as int) > best:
			result[target] = best
