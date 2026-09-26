class_name CityStreetObjects

#Lamp posts, sidewalk furniture and alley scatter of a city block map. Every placement rule lives in
#CityObjects.place; this class only decides where an object is wanted.

const LAMP_MAIN := Vector2i(8, 12)
const LAMP_SIDE := Vector2i(12, 16)
const RUN_MAIN := 3
const RUN_SIDE := 5
const POST_SHIFTS: Array[int] = [0, -1, 1, -2, 2]
const FURN_CLEAR := 3
const FURN_TRIES := 8
const FURN_SPAN := 40.0
const GROUP_CELLS := 14.0
const GROUP_MAX := 4
const GROUP_TRIES := 6
const GROUP_SIZE := Vector2i(1, 3)
const SIDES: Array[int] = [-1, 1]
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


#Lamp posts, then sidewalk objects, then alley scatter. Runs after CityAccess.build.
static func build(area: BattlefieldArea) -> void:
	if area == null or not area.city.has("streets"):
		return
	var lamps: Array[ObstacleData] = _use_rows(area, "lamp")
	var walks: Array[ObstacleData] = _use_rows(area, "sidewalk")
	var alleys: Array[ObstacleData] = _use_rows(area, "alley")
	var taken: Dictionary = {}
	var lamp: int = _lamp_posts(area, lamps, taken)
	var walk: int = _furniture(area, walks, taken)
	var alley: int = _scatter(area, alleys)
	area.generation_log.append("[CITY] street objects: lamp=%d sidewalk=%d alley=%d" % [lamp, walk, alley])


#The Obstacles.tsv rows whose City cell names the use; an empty list is reported once.
static func _use_rows(area: BattlefieldArea, use: String) -> Array[ObstacleData]:
	var out: Array[ObstacleData] = DataManager.get_city_obstacles(use)
	if out.is_empty():
		area.generation_log.append("[CITY] street objects: no obstacle row with City use %s" % use)
	return out


#### Lamp posts.


static func _lamp_posts(area: BattlefieldArea, lamps: Array[ObstacleData], taken: Dictionary) -> int:
	if lamps.is_empty():
		return 0
	var placed: int = 0
	for street: Dictionary in (area.city["streets"] as Array):
		var kind: String = String(street.get("kind", ""))
		if kind != "main" and kind != "side":
			continue
		var data: ObstacleData = lamps[randi() % lamps.size()]
		var sid: int = int(street.get("id", -1))
		var carriage: int = BattlefieldArea.SURF_MAIN if kind == "main" else BattlefieldArea.SURF_SIDE
		var span: Vector2i = LAMP_MAIN if kind == "main" else LAMP_SIDE
		var spacing: int = randi_range(span.x, span.y)
		var shortest: int = RUN_MAIN if kind == "main" else RUN_SIDE
		for seg: Dictionary in (street.get("segments", []) as Array):
			for side: int in SIDES:
				for run: Array in _curb_runs(area, sid, seg, carriage, side):
					placed += _run_posts(area, data, run, spacing, shortest, taken)
	return placed


#Maximal runs of curb cells on one side of a segment; side -1 is the low cross line, 1 the high one.
static func _curb_runs(area: BattlefieldArea, sid: int, seg: Dictionary, carriage: int,
		side: int) -> Array[Array]:
	var runs: Array[Array] = []
	var rect: Rect2i = seg.get("rect", Rect2i())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return runs
	var along_x: bool = String(seg.get("axis", "x")) == "x"
	var a0: int = rect.position.x if along_x else rect.position.y
	var a1: int = (rect.end.x if along_x else rect.end.y) - 1
	var lo: int = rect.position.y if along_x else rect.position.x
	var hi: int = (rect.end.y if along_x else rect.end.x) - 1
	var curb: int = lo - 1 if side < 0 else hi + 1
	var inner: int = lo if side < 0 else hi
	var run: Array[Vector2i] = []
	for a: int in range(a0, a1 + 1):
		var cc: Vector2i = Vector2i(a, curb) if along_x else Vector2i(curb, a)
		var rc: Vector2i = Vector2i(a, inner) if along_x else Vector2i(inner, a)
		if _is_curb(area, sid, cc, rc, carriage):
			run.append(cc)
			continue
		if not run.is_empty():
			runs.append(run)
			run = []
	if not run.is_empty():
		runs.append(run)
	return runs


#A sidewalk cell that lies against the carriageway of street sid.
static func _is_curb(area: BattlefieldArea, sid: int, cell: Vector2i, road: Vector2i, carriage: int) -> bool:
	if CityGrid.surf(area, cell.x, cell.y) != BattlefieldArea.SURF_SIDEWALK:
		return false
	if CityGrid.surf(area, road.x, road.y) != carriage:
		return false
	return CityGrid.street_id(area, road.x, road.y) == sid


#One post on each end of the run plus evenly spaced ones between them.
static func _run_posts(area: BattlefieldArea, data: ObstacleData, run: Array, spacing: int,
		shortest: int, taken: Dictionary) -> int:
	if run.size() < shortest:
		return 0
	var span: int = run.size() - 1
	var wanted: Array[int] = [0]
	if span > 0:
		var n: int = maxi(0, roundi(float(span) / float(maxi(spacing, 1))) - 1)
		for i: int in range(1, n + 1):
			wanted.append(roundi(float(i) * float(span) / float(n + 1)))
		wanted.append(span)
	var placed: int = 0
	for at: int in wanted:
		if _try_post(area, data, run, at, taken):
			placed += 1
	return placed


#The wanted cell, then the cells 1 and 2 away along the run, low side first.
static func _try_post(area: BattlefieldArea, data: ObstacleData, run: Array, at: int,
		taken: Dictionary) -> bool:
	for off: int in POST_SHIFTS:
		var idx: int = at + off
		if idx < 0 or idx >= run.size():
			continue
		var cell: Vector2i = run[idx]
		if String(taken.get(cell, "")) == "lamp":
			return false
		if CityObjects.place(area, data, cell, "lamp").is_empty():
			continue
		taken[cell] = "lamp"
		return true
	return false


#### Sidewalk objects.


static func _furniture(area: BattlefieldArea, walks: Array[ObstacleData], taken: Dictionary) -> int:
	if walks.is_empty():
		return 0
	var placed: int = 0
	for street: Dictionary in (area.city["streets"] as Array):
		if String(street.get("kind", "")) != "main":
			continue
		var sid: int = int(street.get("id", -1))
		var along_x: bool = String(street.get("axis", "x")) == "x"
		var curbs: Dictionary = {}
		for seg: Dictionary in (street.get("segments", []) as Array):
			_wall_cells(area, sid, seg, curbs)
		if curbs.is_empty():
			continue
		var cells: Array[Vector2i] = _sorted(area, curbs)
		var want: int = 0
		for _r: int in range(maxi(1, int(float(_street_len(street)) / FURN_SPAN))):
			want += randi_range(0, 2)
		for _o: int in range(want):
			var data: ObstacleData = walks[randi() % walks.size()]
			for _t: int in range(FURN_TRIES):
				var cell: Vector2i = cells[randi() % cells.size()]
				if _try_furniture(area, data, cell, along_x, curbs, taken):
					placed += 1
					break
	return placed


#Wall side sidewalk cells of a main segment, each mapped to its curb cell.
static func _wall_cells(area: BattlefieldArea, sid: int, seg: Dictionary, out: Dictionary) -> void:
	var rect: Rect2i = seg.get("rect", Rect2i())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var along_x: bool = String(seg.get("axis", "x")) == "x"
	var a0: int = rect.position.x if along_x else rect.position.y
	var a1: int = (rect.end.x if along_x else rect.end.y) - 1
	var lo: int = rect.position.y if along_x else rect.position.x
	var hi: int = (rect.end.y if along_x else rect.end.x) - 1
	for side: int in SIDES:
		var curb: int = lo - 1 if side < 0 else hi + 1
		var inner: int = lo if side < 0 else hi
		var wall: int = curb - 1 if side < 0 else curb + 1
		for a: int in range(a0, a1 + 1):
			var cc: Vector2i = Vector2i(a, curb) if along_x else Vector2i(curb, a)
			var rc: Vector2i = Vector2i(a, inner) if along_x else Vector2i(inner, a)
			if not _is_curb(area, sid, cc, rc, BattlefieldArea.SURF_MAIN):
				continue
			var wc: Vector2i = Vector2i(a, wall) if along_x else Vector2i(wall, a)
			if CityGrid.surf(area, wc.x, wc.y) != BattlefieldArea.SURF_SIDEWALK:
				continue
			out[wc] = cc


static func _try_furniture(area: BattlefieldArea, data: ObstacleData, cell: Vector2i, along_x: bool,
		curbs: Dictionary, taken: Dictionary) -> bool:
	var step: Vector2i = Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var far: Vector2i = cell + step
	if not curbs.has(far) or taken.has(cell) or taken.has(far):
		return false
	var curb_a: Vector2i = curbs[cell]
	var curb_b: Vector2i = curbs[far]
	if not _free(area, curb_a) or not _free(area, curb_b):
		return false
	var off: Vector2i = curb_a - cell
	if not _clear(taken, cell, far, step, off):
		return false
	if data.preferred_position == "Any Wall":
		if not _is_wall(area, cell - off) or not _is_wall(area, far - off):
			return false
	if CityObjects.place(area, data, cell, "sidewalk", not along_x).is_empty():
		return false
	taken[cell] = "sidewalk"
	taken[far] = "sidewalk"
	return true


#No lamp post and no other sidewalk object within FURN_CLEAR cells along the street axis.
static func _clear(taken: Dictionary, lo: Vector2i, hi: Vector2i, step: Vector2i, off: Vector2i) -> bool:
	for k: int in range(1, FURN_CLEAR + 1):
		var before: Vector2i = lo - step * k
		var after: Vector2i = hi + step * k
		if taken.has(before) or taken.has(after):
			return false
		if taken.has(before + off) or taken.has(after + off):
			return false
	return true


#### Alley scatter.


static func _scatter(area: BattlefieldArea, pool: Array[ObstacleData]) -> int:
	if pool.is_empty():
		return 0
	var placed: int = 0
	for street: Dictionary in (area.city["streets"] as Array):
		if String(street.get("kind", "")) != "alley" or street.has("back_door"):
			continue
		if CityAlleys.is_wrap(street):
			continue
		var found: Dictionary = _alley_cells(area, int(street.get("id", -1)), street)
		var edges: Array[Vector2i] = found["edges"]
		if edges.is_empty():
			continue
		var groups: int = clampi(roundi(float(int(found["count"])) / GROUP_CELLS), 0, GROUP_MAX)
		for _g: int in range(groups):
			placed += _group(area, pool, edges, found["set"] as Dictionary)
	return placed


#Cells of one alley: {"count", "edges": the cells against a wall in y then x order, "set"}.
static func _alley_cells(area: BattlefieldArea, sid: int, street: Dictionary) -> Dictionary:
	var owned: Dictionary = {}
	for seg: Dictionary in (street.get("segments", []) as Array):
		var rect: Rect2i = seg.get("rect", Rect2i())
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				if CityGrid.surf(area, x, y) != BattlefieldArea.SURF_ALLEY:
					continue
				if CityGrid.street_id(area, x, y) != sid:
					continue
				owned[Vector2i(x, y)] = true
	var edge: Dictionary = {}
	for cell: Vector2i in owned.keys():
		for d: Vector2i in DIRS:
			var n: Vector2i = cell + d
			if CityGrid.inside(area, n.x, n.y) and CityGrid.is_street(CityGrid.surf(area, n.x, n.y)):
				continue
			edge[cell] = true
			break
	return {"count": owned.size(), "edges": _sorted(area, edge), "set": edge}


#One scatter group: a rolled edge cell, then further objects on edge cells beside the last one.
static func _group(area: BattlefieldArea, pool: Array[ObstacleData], edges: Array[Vector2i],
		eset: Dictionary) -> int:
	var size: int = randi_range(GROUP_SIZE.x, GROUP_SIZE.y)
	var at := Vector2i(-1, -1)
	for _t: int in range(GROUP_TRIES):
		var cell: Vector2i = edges[randi() % edges.size()]
		if CityObjects.place(area, pool[randi() % pool.size()], cell, "alley").is_empty():
			continue
		at = cell
		break
	if at.x < 0:
		return 0
	var placed: int = 1
	for _k: int in range(size - 1):
		var next: Vector2i = _beside(area, at, eset, pool)
		if next.x < 0:
			break
		at = next
		placed += 1
	return placed


#Places one more object on an edge cell beside `from`; returns that cell, or (-1, -1) when none took it.
static func _beside(area: BattlefieldArea, from: Vector2i, eset: Dictionary,
		pool: Array[ObstacleData]) -> Vector2i:
	var open: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		if eset.has(from + d):
			open.append(from + d)
	while not open.is_empty():
		var i: int = randi() % open.size()
		var cell: Vector2i = open[i]
		open.remove_at(i)
		if CityObjects.place(area, pool[randi() % pool.size()], cell, "alley").is_empty():
			continue
		return cell
	return Vector2i(-1, -1)


#### Cell helpers.


static func _street_len(street: Dictionary) -> int:
	var total: int = 0
	for seg: Dictionary in (street.get("segments", []) as Array):
		var rect: Rect2i = seg.get("rect", Rect2i())
		if String(seg.get("axis", "x")) == "x":
			total += rect.size.x
		else:
			total += rect.size.y
	return total


static func _sorted(area: BattlefieldArea, cells: Dictionary) -> Array[Vector2i]:
	var idx := PackedInt32Array()
	for c: Vector2i in cells.keys():
		idx.append(c.y * area.width + c.x)
	idx.sort()
	var out: Array[Vector2i] = []
	for i: int in idx:
		var y: int = int(i / float(area.width))
		out.append(Vector2i(i - y * area.width, y))
	return out


static func _free(area: BattlefieldArea, cell: Vector2i) -> bool:
	return area.building_at(cell) < 0 and area.get_obs(cell, 0).is_empty()


static func _is_wall(area: BattlefieldArea, cell: Vector2i) -> bool:
	if area.building_at(cell) < 0:
		return false
	return String(area.get_obs(cell, 0).get("cell_type", "")) == "wall"
