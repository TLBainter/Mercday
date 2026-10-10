class_name CityDressing

#Nature and civic dressing of a city block map: the open squares off the main streets first, then the
#vegetation that seeds and grows over what is left of the nature ground. Every object goes through
#CityObjects.place, so the door paths, the spawn zones and the carriageways stay clear.

const SQUARE_STEP := 2
const SQUARE_CANDS := 64
const SQUARE_GAP := 4
const SEED_TRIES := 8
const GROW_MAX := 12
const GROW_FALLOFF := 0.75


static func build(area: BattlefieldArea, area_data: Dictionary) -> void:
	var idx: int = BattlefieldArea.COVER_AMOUNT_NAMES.find(
		String(area_data.get("vegetation_amt", "")).to_lower())
	if idx < 0:
		idx = 2
	area.cover_amount = idx
	var objects: Dictionary = area.city.get("objects", {})
	var was_nature: int = int(objects.get("nature", 0))
	var was_blocking: int = int(objects.get("blocking", 0))
	var was_rolled: int = int(objects.get("rolled_back", 0))
	var skip: Dictionary = {}
	var squares: int = _squares(area, skip)
	var seeds: int = _vegetation(area, area_data, idx, skip)
	var now: Dictionary = area.city.get("objects", objects)
	area.generation_log.append("[CITY] dressing: %d seeds, %d nature objects (%d blocking), %d squares, %d rolled back"
		% [seeds, int(now.get("nature", 0)) - was_nature,
		int(now.get("blocking", 0)) - was_blocking, squares,
		int(now.get("rolled_back", 0)) - was_rolled])


#The obstacle rows of a sheet list; a name with no row is reported once.
static func _rows(area: BattlefieldArea, names: Array) -> Array[ObstacleData]:
	var out: Array[ObstacleData] = []
	var missing: Dictionary = {}
	for n: Variant in names:
		var key: String = String(n)
		if key == "":
			continue
		var row: ObstacleData = DataManager.get_obstacle_by_name(key)
		if row == null:
			if not missing.has(key):
				missing[key] = true
				area.generation_log.append("[CITY] dressing: no obstacle row %s" % key)
			continue
		out.append(row)
	return out


#1 on every nature cell an object may take.
static func _hold_mask(area: BattlefieldArea) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(area.width * area.length)
	mask.fill(0)
	for y: int in range(area.length):
		var row: int = y * area.width
		for x: int in range(area.width):
			if area.surface_grid[row + x] != BattlefieldArea.SURF_NATURE:
				continue
			if CityAccess.can_hold(area, Vector2i(x, y)):
				mask[row + x] = 1
	return mask


#1 on every cell 4-adjacent to the sidewalk of a main street.
static func _near_main_mask(area: BattlefieldArea) -> PackedByteArray:
	var n: int = area.width * area.length
	var mains: Dictionary = {}
	for st: Dictionary in (area.city.get("streets", []) as Array):
		if String(st.get("kind", "")) == "main":
			mains[int(st.get("id", -1))] = true
	var walk := PackedByteArray()
	walk.resize(n)
	walk.fill(0)
	for i: int in range(n):
		if area.surface_grid[i] != BattlefieldArea.SURF_SIDEWALK:
			continue
		if mains.has(area.street_grid[i]):
			walk[i] = 1
	var out := PackedByteArray()
	out.resize(n)
	out.fill(0)
	var w: int = area.width
	for i2: int in range(n):
		var x: int = i2 % w
		if x > 0 and walk[i2 - 1] == 1:
			out[i2] = 1
		elif x < w - 1 and walk[i2 + 1] == 1:
			out[i2] = 1
		elif i2 >= w and walk[i2 - w] == 1:
			out[i2] = 1
		elif i2 + w < n and walk[i2 + w] == 1:
			out[i2] = 1
	return out


static func _squares(area: BattlefieldArea, skip: Dictionary) -> int:
	var rows: Array[ObstacleData] = DataManager.get_city_obstacles("square")
	if rows.is_empty():
		return 0
	var mains: int = 0
	for st: Dictionary in (area.city.get("streets", []) as Array):
		if String(st.get("kind", "")) == "main":
			mains += 1
	var count: int = randi_range(0, mains)
	if count <= 0:
		return 0
	var hold: PackedByteArray = _hold_mask(area)
	var near: PackedByteArray = _near_main_mask(area)
	var cands: Dictionary = {}
	var taken: Array[Rect2i] = []
	var placed: int = 0
	for _i: int in range(count):
		var row: ObstacleData = rows[randi() % rows.size()]
		var pw: int = maxi(1, ceili(row.size_x))
		var ph: int = maxi(1, ceili(row.size_y))
		var key: String = "%dx%d" % [pw, ph]
		if not cands.has(key):
			cands[key] = _candidates(area, hold, near, pw, ph)
		var free: Array[Vector2i] = []
		for c: Vector2i in (cands[key] as Array):
			if _clear_of(taken, Rect2i(c.x - 1, c.y - 1, pw + 2, ph + 2)):
				free.append(c)
		if free.is_empty():
			continue
		var at: Vector2i = free[randi() % free.size()]
		if CityObjects.place(area, row, at, "square").is_empty():
			continue
		var block := Rect2i(at.x - 1, at.y - 1, pw + 2, ph + 2)
		taken.append(block)
		for by: int in range(block.position.y, block.end.y):
			for bx: int in range(block.position.x, block.end.x):
				skip[Vector2i(bx, by)] = true
		placed += 1
	return placed


static func _clear_of(taken: Array[Rect2i], block: Rect2i) -> bool:
	for t: Rect2i in taken:
		if t.grow(SQUARE_GAP).intersects(block):
			return false
	return true


#Anchors whose block of (pw + 2) x (ph + 2) cells is free nature and touches a main street sidewalk.
static func _candidates(area: BattlefieldArea, hold: PackedByteArray, near: PackedByteArray,
		pw: int, ph: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var y: int = 1
	while y + ph + 1 <= area.length and out.size() < SQUARE_CANDS:
		var x: int = 1
		while x + pw + 1 <= area.width and out.size() < SQUARE_CANDS:
			if _block_ok(area, hold, near, x, y, pw, ph):
				out.append(Vector2i(x, y))
			x += SQUARE_STEP
		y += SQUARE_STEP
	return out


static func _block_ok(area: BattlefieldArea, hold: PackedByteArray, near: PackedByteArray,
		x: int, y: int, pw: int, ph: int) -> bool:
	var touches: bool = false
	for by: int in range(y - 1, y + ph + 1):
		var row: int = by * area.width
		for bx: int in range(x - 1, x + pw + 1):
			if hold[row + bx] == 0:
				return false
			if near[row + bx] == 1:
				touches = true
	return touches


static func _vegetation(area: BattlefieldArea, area_data: Dictionary, idx: int,
		skip: Dictionary) -> int:
	var rows: Array[ObstacleData] = _rows(area, area_data.get("vegetation_list", []) as Array)
	if rows.is_empty():
		return 0
	var cells: Array[Vector2i] = []
	var open: Dictionary = {}
	for y: int in range(area.length):
		var row: int = y * area.width
		for x: int in range(area.width):
			if area.surface_grid[row + x] != BattlefieldArea.SURF_NATURE:
				continue
			var c := Vector2i(x, y)
			if skip.has(c) or not CityAccess.can_hold(area, c):
				continue
			cells.append(c)
			open[c] = true
	if cells.is_empty():
		return 0
	var density: float = BattlefieldArea.COVER_DENSITY[clampi(idx, 0,
		BattlefieldArea.COVER_DENSITY.size() - 1)]
	var seeds: int = int(float(cells.size()) * density)
	for _s: int in range(seeds):
		for _t: int in range(SEED_TRIES):
			var at: Vector2i = cells[randi() % cells.size()]
			var row2: ObstacleData = rows[randi() % rows.size()]
			if CityObjects.place(area, row2, at, "nature").is_empty():
				continue
			_grow(area, row2, at, open)
			break
	return seeds


#Spreads one seed over the free nature cells the way ObstacleGenerator grows a scattered obstacle.
static func _grow(area: BattlefieldArea, row: ObstacleData, origin: Vector2i, open: Dictionary) -> void:
	var odds: int = row.growth_pct
	var added: int = 0
	var dirs: Array[Vector2i] = PathCost.DIRS8.duplicate()
	var frontier: Array[Vector2i] = [origin]
	while odds > 0 and added < GROW_MAX and not frontier.is_empty() and randi() % 100 < odds:
		var parent: Vector2i = frontier[randi() % frontier.size()]
		dirs.shuffle()
		var grew: bool = false
		for d: Vector2i in dirs:
			var np: Vector2i = parent + d
			if not open.has(np):
				continue
			if CityObjects.place(area, row, np, "nature").is_empty():
				continue
			frontier.append(np)
			added += 1
			grew = true
			break
		if not grew:
			break
		odds = int(float(odds) * GROW_FALLOFF)
