class_name RoofObjects
extends RefCounted

#Parapets, chimneys and dormers on the roof parts RoofBuilder made; writes obstacles and the obstacle map.


const OBJECTS: Array[String] = ["Chimney", "Large Chimney", "Dormer"]


const HEARTH_ROOMS: Array[String] = ["Kitchen", "Forge", "Bakehouse", "Common Room", "Cottage Room", "Living Room",
	"Great Hall"]


const PARAPET_MIN := 5


#Parapets, chimneys and dormers on a finished roof; geometry alone decides every cell, no die is rolled.
static func place_objects(area: BattlefieldArea, objects: Array) -> void:
	if not RoofBuilder.enabled or area == null or area.roof_parts.is_empty():
		return
	var placed: int = 0
	for part: Dictionary in area.roof_parts:
		if String(part.get("kind", "")) == "dome":
			continue
		placed += _place_parapets(area, part)
	var main_id: int = RoofBuilder.main_part(area.roof_parts)
	if main_id >= 0 and String((area.roof_parts[main_id] as Dictionary).get("kind", "")) != "dome":
		var main: Dictionary = area.roof_parts[main_id]
		for entry: Variant in objects:
			var rec: Dictionary = entry as Dictionary
			var obj_name: String = String(rec.get("name", ""))
			var count: int = maxi(1, int(rec.get("count", 1)))
			if obj_name == "Chimney":
				placed += _place_chimneys(area, main, count)
			elif obj_name == "Large Chimney":
				placed += _place_large_chimney(area, main)
			elif obj_name == "Dormer":
				placed += _place_dormers(area, main, count)
	if placed > 0:
		area._rebuild_cover_obstacles()
		area._rebuild_droppable_obs_map()


#Cell set of one part, for the ring and block tests.
static func _cell_set(part: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in (part.get("cells", []) as Array):
		out[cell] = true
	return out


#Ring cells of a part in y then x order, each with the outward step that leaves the part.
static func _ring_of(part: Dictionary, cells: Dictionary) -> Array:
	var out: Array = []
	for cell: Vector2i in (part.get("cells", []) as Array):
		for dir: Vector2i in RoofBuilder.DIRS4:
			if cells.has(cell + dir):
				continue
			out.append([cell, dir])
			break
	return out


#One roof object on a cell; false when the cell is taken. Covered cells share the stored dictionary.
static func _put_object(area: BattlefieldArea, cell: Vector2i, level: int, d: ObstacleData,
		pw: int = 1, ph: int = 1) -> bool:
	if d == null:
		return false
	for dx: int in range(pw):
		for dy: int in range(ph):
			if not area.get_obs(Vector2i(cell.x + dx, cell.y + dy), level).is_empty():
				return false
	var pos := Vector3i(cell.x, cell.y, level)
	var obs: Dictionary = {"pos": pos, "size": pw * ph, "data": d, "cell_type": "roof_object",
		"pw": pw, "ph": ph, "height": d.height, "floor": level, "roof_object": true}
	area.add_obstacle(obs, pos, pw, ph)
	return true


#Parapet ring of one flat part; a Battlement part alternates merlons and parapets, corners merlon.
static func _place_parapets(area: BattlefieldArea, part: Dictionary) -> int:
	if String(part.get("kind", "")) != "flat":
		return 0
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	if rect.size.x < PARAPET_MIN or rect.size.y < PARAPET_MIN:
		return 0
	var battlement: bool = String(part.get("shape", "")) == "Battlement"
	var parapet: ObstacleData = DataManager.get_obstacle_by_name("Parapet")
	var merlon: ObstacleData = DataManager.get_obstacle_by_name("Merlon")
	if parapet == null or (battlement and merlon == null):
		return 0
	var level: int = int(part.get("level", 0))
	var cells: Dictionary = _cell_set(part)
	var corners: Dictionary = {
		Vector2i(rect.position.x, rect.position.y): true,
		Vector2i(rect.end.x - 1, rect.position.y): true,
		Vector2i(rect.position.x, rect.end.y - 1): true,
		Vector2i(rect.end.x - 1, rect.end.y - 1): true,
	}
	var placed: int = 0
	for row: Array in _ring_of(part, cells):
		var cell: Vector2i = row[0] as Vector2i
		var out: Vector2i = cell + (row[1] as Vector2i)
		if int(area.roof_cells.get(Vector3i(cell.x, cell.y, level), RoofBuilder.FLAT)) == RoofBuilder.SOLID:
			continue
		#A wing meeting a taller wall keeps its ring open; there is no fall to guard.
		if area.in_footprint(out):
			continue
		var d: ObstacleData = parapet
		if battlement and (corners.has(cell) or (cell.x + cell.y) % 2 == 0):
			d = merlon
		if _put_object(area, cell, level, d):
			placed += 1
	return placed


#Part cells that may carry a standing object: inside the ring, free, neither solid nor peak.
static func _object_cells(area: BattlefieldArea, part: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if String(part.get("kind", "")) == "dome":
		return out
	var cells: Dictionary = _cell_set(part)
	var ring: Dictionary = {}
	for row: Array in _ring_of(part, cells):
		ring[row[0] as Vector2i] = true
	var level: int = int(part.get("level", 0))
	for cell: Vector2i in (part.get("cells", []) as Array):
		if ring.has(cell):
			continue
		var t: int = int(area.roof_cells.get(Vector3i(cell.x, cell.y, level), -1))
		if t == RoofBuilder.SOLID or t == RoofBuilder.PEAK or t < 0:
			continue
		if not area.get_obs(cell, level).is_empty():
			continue
		out.append(cell)
	return out


#Squared distance of a cell centre from the rect centre, in doubled integer coordinates.
static func _centre_d2(rect: Rect2i, cell: Vector2i) -> int:
	var cx: int = 2 * rect.position.x + rect.size.x - 1
	var cy: int = 2 * rect.position.y + rect.size.y - 1
	var dx: int = 2 * cell.x - cx
	var dy: int = 2 * cell.y - cy
	return dx * dx + dy * dy


#Chimneys stand away from the roof centre; each further one stands away from those already up.
static func _place_chimneys(area: BattlefieldArea, part: Dictionary, count: int) -> int:
	var d: ObstacleData = DataManager.get_obstacle_by_name("Chimney")
	if d == null:
		return 0
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var level: int = int(part.get("level", 0))
	var free: Array[Vector2i] = _object_cells(area, part)
	var hearths: Array[Rect2i] = _hearth_rects(area)
	var taken: Array[Vector2i] = []
	var placed: int = 0
	for i: int in range(count):
		var best := Vector2i(-1, -1)
		if i < hearths.size():
			best = _nearest_free(free, taken, hearths[i])
		if best.x < 0:
			best = _spread_pick(area, free, taken, rect, level, true)
		if best.x < 0:
			best = _spread_pick(area, free, taken, rect, level, false)
		if best.x < 0 or not _put_object(area, best, level, d):
			break
		taken.append(best)
		placed += 1
	return placed


#Rooms that hold a fire, in HEARTH_ROOMS order, upper floors first within one name.
static func _hearth_rects(area: BattlefieldArea) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for want: String in HEARTH_ROOMS:
		var rows: Array[Array] = []
		for rec: Dictionary in area.interior_rooms:
			if String(rec.get("name", "")).contains(want):
				var r: Rect2i = rec.get("rect", Rect2i()) as Rect2i
				rows.append([-int(rec.get("floor", 0)), r.position.y, r.position.x, r])
		rows.sort_custom(func(a: Array, b: Array) -> bool:
			for k: int in range(3):
				if (a[k] as int) != (b[k] as int):
					return (a[k] as int) < (b[k] as int)
			return false)
		for row: Array in rows:
			if not out.has(row[3] as Rect2i):
				out.append(row[3] as Rect2i)
	return out


#The free cell inside room nearest its centre; (-1, -1) when the room lies under no free roof cell.
static func _nearest_free(free: Array[Vector2i], taken: Array[Vector2i], room: Rect2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for cell: Vector2i in free:
		if taken.has(cell) or not room.has_point(cell):
			continue
		var dist: int = _centre_d2(room, cell)
		if dist < best_d:
			best = cell
			best_d = dist
	return best


#First pick nearest the roof centre, later picks farthest from those taken; ridge_only keeps to cells beside a peak.
static func _spread_pick(area: BattlefieldArea, free: Array[Vector2i], taken: Array[Vector2i], rect: Rect2i,
		level: int, ridge_only: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: int = -(1 << 30)
	for cell: Vector2i in free:
		if taken.has(cell):
			continue
		if ridge_only:
			var beside: bool = false
			for dir: Vector2i in RoofBuilder.DIRS4:
				var n: Vector2i = cell + dir
				if int(area.roof_cells.get(Vector3i(n.x, n.y, level), -1)) == RoofBuilder.PEAK:
					beside = true
					break
			if not beside:
				continue
		var score: int = -_centre_d2(rect, cell)
		if not taken.is_empty():
			score = 1 << 30
			for other: Vector2i in taken:
				score = mini(score, maxi(absi(cell.x - other.x), absi(cell.y - other.y)))
		if score > best_score:
			best = cell
			best_score = score
	return best


#One 2x2 chimney over a forge when the top floor holds one, else nearest the roof centre.
static func _place_large_chimney(area: BattlefieldArea, part: Dictionary) -> int:
	var d: ObstacleData = DataManager.get_obstacle_by_name("Large Chimney")
	if d == null:
		return _place_chimneys(area, part, 1)
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	var level: int = int(part.get("level", 0))
	var free: Dictionary = {}
	for cell: Vector2i in _object_cells(area, part):
		free[cell] = true
	var blocks: Array[Vector2i] = []
	for cell: Vector2i in (part.get("cells", []) as Array):
		if free.has(cell) and free.has(cell + Vector2i(1, 0)) and free.has(cell + Vector2i(0, 1)) \
				and free.has(cell + Vector2i(1, 1)):
			blocks.append(cell)
	if blocks.is_empty():
		return _place_chimneys(area, part, 1)
	var forge: Rect2i = _forge_rect(area, level - 1)
	var best: Vector2i = _nearest_block(rect, blocks, forge)
	if best.x < 0:
		best = _nearest_block(rect, blocks, Rect2i())
	if best.x < 0 or not _put_object(area, best, level, d, 2, 2):
		return _place_chimneys(area, part, 1)
	return 1


#The block closest to the rect centre, only among blocks inside the filter when it is not empty; (-1,-1) when none.
static func _nearest_block(rect: Rect2i, blocks: Array[Vector2i], filter: Rect2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score: int = 0
	for block: Vector2i in blocks:
		if filter.size.x > 0 and not filter.encloses(Rect2i(block, Vector2i(2, 2))):
			continue
		var score: int = _centre_d2(rect, block)
		if best.x < 0 or score < best_score:
			best = block
			best_score = score
	return best


#Rect of the first room of that floor whose name names a forge; an empty rect when none does.
static func _forge_rect(area: BattlefieldArea, floor_num: int) -> Rect2i:
	for rec: Dictionary in area.interior_rooms:
		if int(rec.get("floor", -1)) != floor_num:
			continue
		if not String(rec.get("name", "")).contains("Forge"):
			continue
		return rec.get("rect", Rect2i()) as Rect2i
	return Rect2i()


#Dormers sit one cell in from the eave on the two long sides, evenly spaced and split over both.
static func _place_dormers(area: BattlefieldArea, part: Dictionary, count: int) -> int:
	var d: ObstacleData = DataManager.get_obstacle_by_name("Dormer")
	if d == null:
		return 0
	var rect: Rect2i = part.get("rect", Rect2i()) as Rect2i
	if rect.size.x < 3 or rect.size.y < 3:
		return 0
	var level: int = int(part.get("level", 0))
	var cells: Dictionary = _cell_set(part)
	var ring: Dictionary = {}
	for row: Array in _ring_of(part, cells):
		ring[row[0] as Vector2i] = true
	var along_x: bool = rect.size.x >= rect.size.y
	var side_len: int = rect.size.x if along_x else rect.size.y
	var lines: Array[int] = [rect.position.x + 1, rect.end.x - 2]
	if along_x:
		lines = [rect.position.y + 1, rect.end.y - 2]
	var placed: int = 0
	for s: int in range(2):
		var n_side: int = int(count / 2.0) + (1 if s == 0 and count % 2 == 1 else 0)
		for i: int in range(n_side):
			var step: int = int(float(side_len * (i + 1)) / float(n_side + 1))
			var cell := Vector2i(rect.position.x + step, lines[s]) if along_x \
				else Vector2i(lines[s], rect.position.y + step)
			if not _dormer_ok(area, cells, ring, cell, level):
				continue
			if _put_object(area, cell, level, d):
				placed += 1
	return placed


#A dormer cell is a free slope of the part whose outward neighbour is a ring cell.
static func _dormer_ok(area: BattlefieldArea, cells: Dictionary, ring: Dictionary, cell: Vector2i,
		level: int) -> bool:
	if not cells.has(cell) or ring.has(cell):
		return false
	if int(area.roof_cells.get(Vector3i(cell.x, cell.y, level), -1)) != RoofBuilder.SLOPE:
		return false
	if not area.get_obs(cell, level).is_empty():
		return false
	for dir: Vector2i in RoofBuilder.DIRS4:
		if ring.has(cell + dir):
			return true
	return false
