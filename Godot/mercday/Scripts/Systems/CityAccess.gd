class_name CityAccess

#Ground access of a city block map: the protected footpath of every door, the painted back lanes, the
#tests that gate every outdoor object and the floods that cross the open ground.

#North first order; the flood and ring walks of this file depend on it, so it is part of their contract.
const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]
const RING_X: Array[int] = [0, 1, 1, 1, 0, -1, -1, -1]
const RING_Y: Array[int] = [-1, -1, 0, 1, 1, 1, 0, -1]
const GAP_WALK := 3
const GAP_RUN := 2
const HITS_PER_RULE := 3
const OBJECT_KEYS: Array[String] = ["nature", "blocking", "lamp", "alley", "sidewalk", "square",
	"rolled_back"]


#Doors, protected cells, back lanes and the object counts; call once before any outdoor object exists.
static func build(area: BattlefieldArea) -> void:
	var objects: Dictionary = {}
	for k: String in OBJECT_KEYS:
		objects[k] = 0
	area.city["objects"] = objects
	var doors: Array[Dictionary] = []
	var protected: Dictionary = {}
	var access: Dictionary = {"doors": doors, "protected": protected, "reach0": PackedByteArray()}
	area.city["access"] = access
	for rec: Dictionary in area.buildings:
		_building(area, rec, doors, protected)
	access["reach0"] = flood(area, main_start(area), false)


static func _building(area: BattlefieldArea, rec: Dictionary, doors: Array[Dictionary],
		protected: Dictionary) -> void:
	var id: int = int(rec.get("id", -1))
	var front: String = String(rec.get("front", ""))
	var fd: Vector3i = rec.get("front_door", Vector3i(-1, -1, 0))
	var bd: Vector3i = rec.get("back_door", Vector3i(-1, -1, 0))
	if String(rec.get("shell", "")) == "Open":
		_protect_ring(area, rec.get("rect", Rect2i()), protected)
	if fd.x >= 0:
		_door(area, id, "front", fd, Vector2i(fd.x, fd.y) - _inward(front), doors, protected)
	if bd.x >= 0:
		_door(area, id, "back", bd, Vector2i(bd.x, bd.y) - _inward(BuildingLayouts.opposite(front)), doors, protected)


static func _door(area: BattlefieldArea, id: int, kind: String, door: Vector3i, outside: Vector2i,
		doors: Array[Dictionary], protected: Dictionary) -> void:
	var entry: Dictionary = {"building": id, "kind": kind, "door": door, "outside": outside, "lane": -1}
	doors.append(entry)
	if not is_ground(area, outside):
		var gap: Vector2i = _yard_exit(area, id, outside)
		if gap.x < 0:
			return
		outside = gap
		entry["outside"] = gap
		entry["yard"] = true
	protected[outside] = true
	var path: Array[Vector2i] = _path_to_street(area, outside)
	for c: Vector2i in path:
		protected[c] = true
	if kind == "back":
		entry["lane"] = _lane(area, path, id)


#A door that opens onto a fenced yard of its own building: the ground cell past the yard gap, or (-1, -1).
static func _yard_exit(area: BattlefieldArea, id: int, start: Vector2i) -> Vector2i:
	if int(area.building_id_at.get(start, -1)) != id or area.is_obstacle(start, 0):
		return Vector2i(-1, -1)
	if area.footprint_cells.has(Vector3i(start.x, start.y, 0)):
		return Vector2i(-1, -1)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: int in range(4):
			var n := Vector2i(c.x + DX[d], c.y + DY[d])
			if seen.has(n) or not area.in_bounds_xy(n.x, n.y):
				continue
			seen[n] = true
			if area.is_obstacle(n, 0):
				continue
			if is_ground(area, n):
				return n
			if int(area.building_id_at.get(n, -1)) != id or area.footprint_cells.has(Vector3i(n.x, n.y, 0)):
				continue
			queue.append(n)
	return Vector2i(-1, -1)


static func _protect_ring(area: BattlefieldArea, rect: Rect2i, protected: Dictionary) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var big: Rect2i = rect.grow(1)
	for y: int in range(big.position.y, big.end.y):
		for x: int in range(big.position.x, big.end.x):
			var c := Vector2i(x, y)
			if rect.has_point(c):
				continue
			if is_ground(area, c):
				protected[c] = true


static func _inward(side: String) -> Vector2i:
	return BuildingLayouts.inward_step(side)


static func is_ground(area: BattlefieldArea, cell: Vector2i) -> bool:
	if not area.in_bounds_xy(cell.x, cell.y):
		return false
	return not area.building_id_at.has(cell)


static func is_open(area: BattlefieldArea, cell: Vector2i) -> bool:
	return is_ground(area, cell) and not area.is_obstacle(cell, 0)


static func can_hold(area: BattlefieldArea, cell: Vector2i) -> bool:
	if not area.in_bounds_xy(cell.x, cell.y):
		return false
	if area.building_id_at.has(cell):
		return false
	if area._obs_map.has(Vector3i(cell.x, cell.y, 0)):
		return false
	if CityGrid.is_carriage(CityGrid.surf(area, cell.x, cell.y)):
		return false
	var access: Dictionary = area.city.get("access", {})
	if (access.get("protected", {}) as Dictionary).has(cell):
		return false
	return not (area.spawn_zone_a.has(cell) or area.spawn_zone_b.has(cell))


static func can_block(area: BattlefieldArea, cell: Vector2i) -> bool:
	if not can_hold(area, cell):
		return false
	if narrow_gap(area, cell):
		return false
	if not ring_safe(area, cell):
		return false
	if CityGrid.surf(area, cell.x, cell.y) != BattlefieldArea.SURF_ALLEY:
		return true
	return _alley_wide(area, cell)


static func narrow_gap(area: BattlefieldArea, cell: Vector2i) -> bool:
	for a: int in range(2):
		var dx: int = 1 if a == 0 else 0
		var dy: int = 1 - dx
		var lo: int = _gap_walk(area, cell, -dx, -dy)
		if lo % 2 == 0:
			continue
		var hi: int = _gap_walk(area, cell, dx, dy)
		if hi % 2 == 0:
			continue
		if 1 + (lo >> 1) + (hi >> 1) <= GAP_RUN:
			return true
	return false


#Ground cells within GAP_WALK of cell in one direction, doubled, plus 1 when a building stopped the walk.
static func _gap_walk(area: BattlefieldArea, cell: Vector2i, dx: int, dy: int) -> int:
	var run: int = 0
	for k: int in range(1, GAP_WALK + 1):
		var c := Vector2i(cell.x + dx * k, cell.y + dy * k)
		if not area.in_bounds_xy(c.x, c.y):
			return run << 1
		if area.building_id_at.has(c):
			return (run << 1) + 1
		run += 1
	return run << 1


#False when a blocking object here would split the open neighbours of the cell into two runs.
static func ring_safe(area: BattlefieldArea, cell: Vector2i) -> bool:
	var bits: int = 0
	for i: int in range(8):
		if is_open(area, Vector2i(cell.x + RING_X[i], cell.y + RING_Y[i])):
			bits |= 1 << i
	if bits == 255:
		return true
	var orth: int = 0
	for j: int in range(0, 8, 2):
		if ((bits >> j) & 1) == 1:
			orth += 1
	if orth <= 1:
		return true
	var base: int = 0
	for k: int in range(8):
		if ((bits >> k) & 1) == 0:
			base = k
			break
	var run: int = -1
	var want: int = -2
	for s: int in range(8):
		var idx: int = (base + s) % 8
		if ((bits >> idx) & 1) == 0:
			run = -1
			continue
		if run < 0:
			run = s
		if idx % 2 != 0:
			continue
		if want == -2:
			want = run
		elif want != run:
			return false
	return true


static func _is_alley(area: BattlefieldArea, cell: Vector2i) -> bool:
	return CityGrid.surf(area, cell.x, cell.y) == BattlefieldArea.SURF_ALLEY


#True when an open alley cell lies across the run of the alley, so the lane keeps a free cell.
static func _alley_wide(area: BattlefieldArea, cell: Vector2i) -> bool:
	var west := Vector2i(cell.x - 1, cell.y)
	var east := Vector2i(cell.x + 1, cell.y)
	var north := Vector2i(cell.x, cell.y - 1)
	var south := Vector2i(cell.x, cell.y + 1)
	var along_x: bool = _is_alley(area, west) or _is_alley(area, east)
	var along_y: bool = _is_alley(area, north) or _is_alley(area, south)
	var cross: Array[Vector2i] = [west, east, north, south]
	if along_x and not along_y:
		cross = [north, south]
	elif along_y and not along_x:
		cross = [west, east]
	for c: Vector2i in cross:
		if _is_alley(area, c) and is_open(area, c):
			return true
	return false


static func main_start(area: BattlefieldArea) -> Vector2i:
	if area == null or area.surface_grid.is_empty():
		return Vector2i(-1, -1)
	for y: int in range(area.length):
		var row: int = y * area.width
		for x: int in range(area.width):
			if area.surface_grid[row + x] == BattlefieldArea.SURF_MAIN:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func flood(area: BattlefieldArea, start: Vector2i, with_objects: bool) -> PackedByteArray:
	if area == null or area.width <= 0 or area.length <= 0:
		return PackedByteArray()
	return spread(area, start, pass_mask(area, with_objects))


#1 on every cell a flood may cross: ground, and free of obstacles when with_objects.
static func pass_mask(area: BattlefieldArea, with_objects: bool) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(area.width * area.length)
	mask.fill(0)
	var c := Vector2i.ZERO
	for y: int in range(area.length):
		c.y = y
		var row: int = y * area.width
		for x: int in range(area.width):
			c.x = x
			if area.building_id_at.has(c):
				continue
			if with_objects and area.is_obstacle(c, 0):
				continue
			mask[row + x] = 1
	return mask


static func spread(area: BattlefieldArea, start: Vector2i, mask: PackedByteArray) -> PackedByteArray:
	var w: int = area.width
	var n: int = w * area.length
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	if not area.in_bounds_xy(start.x, start.y) or mask.size() != n:
		return out
	var si: int = start.y * w + start.x
	out[si] = 1
	var queue := PackedInt32Array()
	queue.append(si)
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x: int = i % w
		if x > 0 and out[i - 1] == 0 and mask[i - 1] == 1:
			out[i - 1] = 1
			queue.append(i - 1)
		if x < w - 1 and out[i + 1] == 0 and mask[i + 1] == 1:
			out[i + 1] = 1
			queue.append(i + 1)
		if i >= w and out[i - w] == 0 and mask[i - w] == 1:
			out[i - w] = 1
			queue.append(i - w)
		if i + w < n and out[i + w] == 0 and mask[i + w] == 1:
			out[i + w] = 1
			queue.append(i + w)
	return out


#Shortest ground path from start to the first street cell, start and that cell included; [] when none.
static func _path_to_street(area: BattlefieldArea, start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not is_ground(area, start):
		return out
	var w: int = area.width
	var n: int = w * area.length
	var si: int = start.y * w + start.x
	if CityGrid.is_street(area.surface_grid[si]):
		out.append(start)
		return out
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	seen[si] = 1
	var queue := PackedInt32Array()
	queue.append(si)
	var head: int = 0
	var goal: int = -1
	while head < queue.size() and goal < 0:
		var i: int = queue[head]
		head += 1
		var x: int = i % w
		var y: int = int(i / float(w))
		for d: int in range(4):
			var nx: int = x + DX[d]
			var ny: int = y + DY[d]
			if nx < 0 or ny < 0 or nx >= w or ny >= area.length:
				continue
			var ni: int = ny * w + nx
			if seen[ni] == 1:
				continue
			seen[ni] = 1
			if area.building_id_at.has(Vector2i(nx, ny)):
				continue
			prev[ni] = i
			if CityGrid.is_street(area.surface_grid[ni]):
				goal = ni
				break
			queue.append(ni)
	if goal < 0:
		return out
	var cur: int = goal
	while cur >= 0:
		var cy: int = int(cur / float(w))
		out.append(Vector2i(cur % w, cy))
		cur = prev[cur]
	out.reverse()
	return out


#Paints the ground part of a back door path as a 1-wide dead-end alley; the new street id, or -1.
static func _lane(area: BattlefieldArea, path: Array[Vector2i], bid: int) -> int:
	if path.size() < 2 or not area.city.has("streets"):
		return -1
	var mouth: Vector2i = path[path.size() - 1]
	var cells: Array[Vector2i] = []
	for i: int in range(path.size() - 2, -1, -1):
		var c: Vector2i = path[i]
		var s: int = CityGrid.surf(area, c.x, c.y)
		if s != BattlefieldArea.SURF_NATURE:
			area.generation_log.append("[CITY] back lane skipped: building %d cell %d,%d surface %d"
				% [bid, c.x, c.y, s])
			return -1
		cells.append(c)
	var streets: Array = area.city.get("streets", [])
	var id: int = streets.size()
	for c2: Vector2i in cells:
		CityGrid.paint_alley(area, c2, id)
	var segments: Array[Dictionary] = lane_segments(cells)
	CityGrid.add_street(streets, "alley", String((segments[0] as Dictionary)["axis"]), segments, true,
		-1, mouth, {"back_door": bid})
	return id


#Maximal straight runs of a 1-wide lane, mouth end first; a corner cell belongs to the earlier run.
static func lane_segments(cells: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cells.is_empty():
		return out
	var run_start: int = 0
	var dir := Vector2i.ZERO
	for i: int in range(1, cells.size()):
		var step: Vector2i = cells[i] - cells[i - 1]
		if dir == Vector2i.ZERO:
			dir = step
			continue
		if step == dir:
			continue
		out.append(_lane_seg(cells[run_start], cells[i - 1]))
		run_start = i
		dir = Vector2i.ZERO
	out.append(_lane_seg(cells[run_start], cells[cells.size() - 1]))
	return out


static func _lane_seg(a: Vector2i, b: Vector2i) -> Dictionary:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	var rect := Rect2i(lo, hi - lo + Vector2i.ONE)
	var axis: String = "x"
	if rect.size.y > rect.size.x:
		axis = "y"
	return {"rect": rect, "axis": axis, "width": 1}
