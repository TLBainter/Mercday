class_name DungeonGenerator

#Dungeon maps: F0 at street level with up to three carved floors under it, one stair band,
#chambers and barred cells joined by halls. Contract Difficulty sets every size.

const MAX_ATTEMPTS := 10
const STREET := 2
const PLACE_TRIES := 200
const SHRINK_STEPS := 40
const BIG := 1073741823

const K_WALL := 0
const K_ROOM := 1
const K_CELL := 2
const K_HALL := 3
const K_BAND := 4
const K_DOOR := 5

const FOYER_ROW := "Dungeon Foyer"
const CELL_ROW := "Dungeon Cell"
const HALL_NARROW := "Dungeon Hall (Narrow)"
const HALL_WIDE := "Dungeon Hall (Wide)"
const STORAGE_ROW := "Dungeon Storage"
const ARMORY_ROW := "Dungeon Armory"

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

const FLOOR_LO: Array[int] = [1, 1, 2, 2, 3]
const FLOOR_HI: Array[int] = [1, 2, 2, 3, 4]
const ROOM_LO: Array[int] = [5, 7, 10, 14, 18]
const ROOM_HI: Array[int] = [7, 10, 14, 18, 24]
const SIDE_LO: Array[int] = [20, 22, 24, 26, 28]
const SIDE_HI: Array[int] = [24, 26, 30, 32, 34]
const CANVAS_SLACK := 6
const CLUSTER_TRIES := 24
const GAP_LO := 3
const GAP_HI := 6
const BLOCK_TRIES := 40
const FILL_BOXY := 97

const BLOCK_CHANCE: Array[int] = [50, 100, 100, 100, 100]
const BLOCK_TWO: Array[int] = [0, 0, 0, 50, 50]
const BLOCK_CELL_LO: Array[int] = [4, 4, 4, 4, 5]
const BLOCK_CELL_HI: Array[int] = [4, 4, 5, 6, 6]
const CELLS_MIN := 4
const CELLS_MAX := 10


#Floors, chamber count, cell block count and the interior side range of a dungeon of Difficulty d.
static func size_for(d: float, min_blocks: int = 0) -> Dictionary:
	var b: int = clampi(floori(d), 1, 5) - 1
	var floors: int = FLOOR_LO[b]
	if FLOOR_HI[b] > FLOOR_LO[b] and randi() % 2 == 1:
		floors = FLOOR_HI[b]
	return {
		"floors": floors,
		"rooms": randi_range(ROOM_LO[b], ROOM_HI[b]),
		"blocks": maxi(blocks_for(b), min_blocks),
		"side": Vector2i(SIDE_LO[b], SIDE_HI[b]),
	}


#Cell blocks of a dungeon in band b; band 1 often has none, bands 4 and 5 sometimes have two.
static func blocks_for(b: int) -> int:
	if randi() % 100 >= BLOCK_CHANCE[b]:
		return 0
	if BLOCK_TWO[b] > 0 and randi() % 100 < BLOCK_TWO[b]:
		return 2
	return 1


static func generate(area: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext) -> void:
	var t0: int = Time.get_ticks_msec()
	var d: float = ctx.difficulty if ctx != null else 0.0
	if d <= 0.0:
		d = float(randi_range(2, 10)) / 2.0
	var min_blocks: int = ctx.min_cell_blocks if ctx != null else 0
	var issues: Array[String] = []
	for _attempt: int in range(MAX_ATTEMPTS):
		issues = _build(area, area_data, d, min_blocks)
		if issues.is_empty():
			issues = validate(area)
		if issues.is_empty():
			break
	var total_ms: int = Time.get_ticks_msec() - t0
	area.dungeon_stats["ms"] = total_ms
	area.dungeon_stats["violations"] = issues.size()
	if not issues.is_empty():
		area.generation_log.append("[GEN] dungeon violations: %s" % ", ".join(issues))
	_log_generation(area, total_ms)


static func _log_generation(area: BattlefieldArea, total_ms: int) -> void:
	var st: Dictionary = area.dungeon_stats
	area.generation_log.append("Area: %s  terrain: %s" % [area.area_name, BattlefieldArea.UNEVENNESS_NAMES[6]])
	area.generation_log.append("[GEN] dungeon D=%.1f floors: %d  floor_w: %d  fh: %d  floor_d: %d  map: %dx%d" % [
		area.dungeon_difficulty, int(st.get("floors", 0)), int(st.get("floor_w", 0)),
		area.interior_floor_height, area.interior_floor_depth, area.width, area.length])
	area.generation_log.append("[GEN] dungeon rooms: %d  cells: %d  halls: %d  loops: %d  dead ends: %d" % [
		int(st.get("chambers", 0)), int(st.get("cells", 0)), int(st.get("halls", 0)),
		int(st.get("loops", 0)), int(st.get("dead_ends", 0))])
	area.log_total(total_ms)


#One full layout pass; the returned texts name what the pass could not satisfy.
static func _build(area: BattlefieldArea, area_data: Dictionary, d: float,
		min_blocks: int = 0) -> Array[String]:
	var problems: Array[String] = []
	area.reset_generated_state()
	area.spawn_zone_a.clear()
	area.spawn_zone_b.clear()
	area.interior_rooms.clear()
	var g: DungeonGeom = _init_geometry(area, area_data, d, min_blocks)
	if g == null:
		problems.append("missing Wall row")
		return problems
	_carve_shell(area, g)
	_carve_band(area, g)
	_place_rooms(g, problems)
	_pick_doors(g, problems)
	for f: int in _floor_list(g):
		_carve_halls(g, f, problems)
	_place_entrance(area, g, problems)
	_place_doors(area, g)
	_apply_masks(area, g)
	_fill_walls(area, g)
	_finish(area, g)
	return problems


#Layout state shared by every pass of one dungeon build.
class DungeonGeom extends RefCounted:
	var area_data: Dictionary = {}
	var d: float = 0.0
	var fh: int = 0
	var floors: int = 1
	var fm: int = 0
	var bld_x: int = 0
	var top_y: int = 0
	var floor_w: int = 0
	var floor_d: int = 0
	var ix0: int = 0
	var ix1: int = 0
	var iy0: int = 0
	var iy1: int = 0
	var wall: ObstacleData
	var door: ObstacleData
	var stairs: ObstacleData
	var chambers: int = 0
	var blocks: int = 0
	var blocks_made: int = 0
	var kinds: Dictionary = {}
	var blocked: Dictionary = {}
	var rooms: Array = []
	var used: Dictionary = {}
	var rings: Dictionary = {}
	var wide: Dictionary = {}
	var has_band: bool = false
	var band: Rect2i = Rect2i()
	var sx: int = -1
	var run0: int = 0
	var run1: int = 0
	var foyer_side: int = 0
	var entrance: Vector2i = Vector2i.ZERO
	var seed_halls: Dictionary = {}
	var block_floors: Dictionary = {}
	var block_by_floor: Dictionary = {}


static func _init_geometry(area: BattlefieldArea, area_data: Dictionary, d: float,
		min_blocks: int = 0) -> DungeonGeom:
	var wall_data: ObstacleData = DataManager.get_obstacle_by_name("Wall")
	if wall_data == null:
		push_error("DungeonGenerator: Wall obstacle missing")
		return null
	var spec: Dictionary = size_for(d, min_blocks)
	var floors: int = maxi(1, mini(int(spec["floors"]), 1 + int(area_data.get("f_minus", 3))))
	var min_sz: int = int(area_data.get("min_size", 20))
	var max_sz: int = maxi(int(area_data.get("max_size", 34)), min_sz)
	var side: Vector2i = spec["side"] as Vector2i
	var fh: int = randi_range(3, 4)
	var floor_w: int = clampi(randi_range(side.x, side.y) + CANVAS_SLACK, min_sz, max_sz)
	var floor_d: int = clampi(randi_range(side.x, side.y) + CANVAS_SLACK, min_sz, max_sz)
	area.width = floor_w + 2 + 2 * STREET
	area.length = floor_d + 1 + 2 * STREET
	area.height = 20
	area.cover_amount = 2
	area.unevenness = 6
	area.is_interior_map = true
	area.is_dungeon = true
	area.interior_floor_height = fh
	area.interior_floor_depth = floor_d
	area.interior_top_y = STREET
	area.area_name = String(area_data.get("name", "Dungeon"))
	area.dungeon_difficulty = d
	for i: int in range(floors):
		area.interior_floor_elevations[i - floors + 1] = i * fh
	var g := DungeonGeom.new()
	g.area_data = area_data
	g.d = d
	g.fh = fh
	g.floors = floors
	g.fm = floors - 1
	g.bld_x = STREET
	g.top_y = STREET
	g.floor_w = floor_w
	g.floor_d = floor_d
	g.ix0 = STREET + 1
	g.ix1 = STREET + floor_w
	g.iy0 = STREET + 1
	g.iy1 = STREET + floor_d
	g.wall = wall_data
	g.door = DataManager.door_data()
	g.stairs = DataManager.get_obstacle_by_name("Stairs")
	g.chambers = int(spec["rooms"])
	g.blocks = int(spec["blocks"])
	g.has_band = floors > 1
	var rings: Dictionary = g.rings
	for i: int in range(floors):
		rings[-i] = {}
	if floors > 1:
		var sx: int = STREET + 2 + (randi() % maxi(1, floor_w - 3))
		var rows: Vector2i = InteriorGenerator.stair_run_rows(STREET, floor_d, fh)
		g.sx = sx
		g.run0 = rows.x
		g.run1 = rows.y
		g.band = Rect2i(sx, rows.x - 1, 2, rows.y - rows.x + 3)
		var blocked: Dictionary = g.blocked
		for y: int in range(rows.x, rows.y + 1):
			blocked[Vector2i(sx - 1, y)] = true
			blocked[Vector2i(sx + 2, y)] = true
	return g


#Floors from F0 down to the deepest.
static func _floor_list(g: DungeonGeom) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(g.floors):
		out.append(-i)
	return out


#The canvas starts solid in the kind map and open in building_interiors; the outline comes from the mask.
static func _carve_shell(area: BattlefieldArea, g: DungeonGeom) -> void:
	var ix0: int = g.ix0
	var ix1: int = g.ix1
	var iy0: int = g.iy0
	var iy1: int = g.iy1
	var kinds: Dictionary = g.kinds
	for f: int in _floor_list(g):
		var kind: Dictionary = {}
		for y: int in range(iy0, iy1 + 1):
			for x: int in range(ix0, ix1 + 1):
				kind[Vector2i(x, y)] = K_WALL
				area.building_interiors[Vector3i(x, y, f)] = true
		kinds[f] = kind
	InteriorGenerator.mark_ceiling_cells(area, 0, g.fm, g.bld_x,
		g.floor_w, g.floor_d, g.top_y)


#The one stair band: both columns open on every floor, the runs cut by the interior builder.
static func _carve_band(area: BattlefieldArea, g: DungeonGeom) -> void:
	if not g.has_band:
		return
	var band: Rect2i = g.band
	for f: int in _floor_list(g):
		for y: int in range(band.position.y, band.end.y):
			for x: int in range(band.position.x, band.end.x):
				_set_kind(g, f, Vector2i(x, y), K_BAND)
	var sx: int = g.sx
	var xs: Dictionary = {}
	var axs: Dictionary = {}
	for f: int in range(0, -g.fm, -1):
		xs[f] = sx
		axs[f] = sx + 1
	InteriorGenerator.place_stairwells(area, 0, g.fm, g.bld_x, g.floor_w,
		g.floor_d, g.stairs, xs, axs, g.top_y)
	for f: int in _floor_list(g):
		for y: int in range(band.position.y, band.end.y):
			for x: int in range(band.position.x, band.end.x):
				var p3 := Vector3i(x, y, f)
				if area._obs_map.has(p3):
					continue
				if area.stair_run_cells.has(p3):
					area._obs_map[p3] = {"cell_type": "stair_run", "floor": f}
				else:
					area._obs_map[p3] = {"cell_type": "reserved_stairwell", "floor": f}


static func _set_kind(g: DungeonGeom, f: int, p: Vector2i, k: int) -> void:
	(g.kinds[f] as Dictionary)[p] = k


static func _kind_of(g: DungeonGeom, f: int, p: Vector2i) -> int:
	return int((g.kinds[f] as Dictionary).get(p, -1))


#Chambers spread evenly over the floors, cell blocks on the deepest; F0 always holds the Foyer.
static func _place_rooms(g: DungeonGeom, problems: Array[String]) -> void:
	var floors: int = g.floors
	var chamber_q: Array[int] = _quota(g.chambers, floors)
	var block_floors: Dictionary = _block_floors(g)
	g.block_floors = block_floors
	for i: int in range(floors):
		var f: int = -i
		var want: int = chamber_q[i]
		if f == 0:
			if _place_foyer(g):
				want -= 1
			else:
				problems.append("foyer did not fit")
		if block_floors.has(f):
			if _place_block(g, f):
				g.blocks_made = g.blocks_made + 1
			else:
				problems.append("cell block did not fit on F%d" % f)
		for _c: int in range(want):
			if not _place_chamber(g, f):
				problems.append("chamber did not fit on F%d" % f)
			_roll_extra_cell(g, f)


#Block floors: the deepest first, a second block on a random other floor, never two on one floor.
static func _block_floors(g: DungeonGeom) -> Dictionary:
	var out: Dictionary = {}
	var floors: int = g.floors
	var want: int = mini(g.blocks, floors)
	if want <= 0:
		return out
	out[-(floors - 1)] = true
	if want > 1:
		var others: Array[int] = []
		for i: int in range(floors):
			if not out.has(-i):
				others.append(-i)
		if not others.is_empty():
			out[others[randi() % others.size()]] = true
	return out


#The more cells a block floor already holds, the likelier a chamber turns into one more cell.
static func _roll_extra_cell(g: DungeonGeom, f: int) -> void:
	if not g.block_floors.has(f):
		return
	var n: int = _cells_on(g, f)
	if n <= 0 or n >= CELLS_MAX:
		return
	if randi() % 100 >= mini(80, 15 * n):
		return
	_extend_block(g, f)


static func _cells_on(g: DungeonGeom, f: int) -> int:
	var n: int = 0
	for entry: Dictionary in g.rooms:
		if int(entry["floor"]) == f and bool(entry["is_cell"]):
			n += 1
	return n


static func _quota(total: int, n: int) -> Array[int]:
	var out: Array[int] = []
	var base: int = int(total / float(n))
	var rem: int = total % n
	for i: int in range(n):
		out.append(base + (1 if i < rem else 0))
	return out


static func _place_foyer(g: DungeonGeom) -> bool:
	var row: ObstacleData = DataManager.get_obstacle_by_name(FOYER_ROW)
	if row == null:
		return false
	var side: int = randi() % 4
	var w: int = maxi(2, int(row.size_x))
	var h: int = maxi(2, int(row.size_y))
	for _s: int in range(SHRINK_STEPS):
		for _t: int in range(PLACE_TRIES):
			var r: Rect2i = _flush_rect(g, side, w, h)
			if r.size.x > 0 and _rect_free(g, 0, r):
				_stamp(g, 0, row, r, false)
				g.foyer_side = side
				return true
		if w <= 2 and h <= 2:
			break
		w = maxi(2, w - 1)
		h = maxi(2, h - 1)
	return false


#A rect flush against one interior side, drawn at random along it.
static func _flush_rect(g: DungeonGeom, side: int, w: int, h: int) -> Rect2i:
	var ix0: int = g.ix0
	var ix1: int = g.ix1
	var iy0: int = g.iy0
	var iy1: int = g.iy1
	if w > ix1 - ix0 + 1 or h > iy1 - iy0 + 1:
		return Rect2i()
	if side <= 1:
		var ylo: int = iy0 + 1
		var yhi: int = iy1 - h
		if yhi < ylo:
			return Rect2i()
		return Rect2i(ix0 if side == 0 else ix1 - w + 1, randi_range(ylo, yhi), w, h)
	var xlo: int = ix0 + 1
	var xhi: int = ix1 - w
	if xhi < xlo:
		return Rect2i()
	return Rect2i(randi_range(xlo, xhi), iy0 if side == 2 else iy1 - h + 1, w, h)


static func _place_chamber(g: DungeonGeom, f: int) -> bool:
	var row: ObstacleData = _pick_row(g, f)
	if row == null:
		return false
	var r: Rect2i = _cluster_rect(g, f, maxi(2, int(row.size_x)), maxi(2, int(row.size_y)), true)
	if r.size.x == 0:
		return false
	_stamp(g, f, row, r, false)
	return true


#A room row for this floor: one still under the twice-per-dungeon cap, else a least used row.
static func _pick_row(g: DungeonGeom, f: int) -> ObstacleData:
	var used: Dictionary = g.used
	var pool: Array[ObstacleData] = []
	var spare: Array[ObstacleData] = []
	var best: int = BIG
	for row: ObstacleData in RoomCatalog.get_dungeon_rooms_for_floor(g.area_data, f):
		var n: String = row.obstacle_name
		if n == FOYER_ROW or n == CELL_ROW or n == HALL_NARROW or n == HALL_WIDE:
			continue
		var c: int = int(used.get(n, 0))
		if c < 2:
			pool.append(row)
		spare.append(row)
		best = mini(best, c)
	if not pool.is_empty():
		return pool[randi() % pool.size()]
	var least: Array[ObstacleData] = []
	for row: ObstacleData in spare:
		if int(used.get(row.obstacle_name, 0)) == best:
			least.append(row)
	if least.is_empty():
		return null
	return least[randi() % least.size()]


#Rooms cluster: tries grown off a room already on the floor, then anywhere, then a shrinking fit.
static func _cluster_rect(g: DungeonGeom, f: int, w: int, h: int, shrink: bool) -> Rect2i:
	for _t: int in range(CLUSTER_TRIES):
		var r: Rect2i = _grown_rect(g, f, w, h)
		if r.size.x > 0 and _rect_free(g, f, r):
			return r
	var r2: Rect2i = _random_rect(g, f, w, h)
	if r2.size.x > 0 or not shrink:
		return r2
	return _shrink_fit(g, f, w, h)


#A rect beyond one side of a room already on the floor, three to six cells of gap between interiors.
static func _grown_rect(g: DungeonGeom, f: int, w: int, h: int) -> Rect2i:
	var anchors: Array[Rect2i] = []
	for entry: Dictionary in g.rooms:
		if int(entry["floor"]) == f:
			anchors.append(entry["rect"] as Rect2i)
	if anchors.is_empty() and g.has_band:
		anchors.append(g.band)
	if anchors.is_empty():
		return Rect2i()
	var a: Rect2i = anchors[randi() % anchors.size()]
	var gap: int = randi_range(GAP_LO, GAP_HI)
	var p := Vector2i.ZERO
	match randi() % 4:
		0:
			p = Vector2i(a.position.x - gap - w, a.position.y + randi_range(-h, a.size.y))
		1:
			p = Vector2i(a.end.x + gap, a.position.y + randi_range(-h, a.size.y))
		2:
			p = Vector2i(a.position.x + randi_range(-w, a.size.x), a.position.y - gap - h)
		_:
			p = Vector2i(a.position.x + randi_range(-w, a.size.x), a.end.y + gap)
	return _clamp_rect(g, Rect2i(p, Vector2i(w, h)))


static func _clamp_rect(g: DungeonGeom, r: Rect2i) -> Rect2i:
	var xlo: int = g.ix0 + 1
	var xhi: int = g.ix1 - r.size.x
	var ylo: int = g.iy0 + 1
	var yhi: int = g.iy1 - r.size.y
	if xhi < xlo or yhi < ylo:
		return Rect2i()
	return Rect2i(clampi(r.position.x, xlo, xhi), clampi(r.position.y, ylo, yhi), r.size.x, r.size.y)


#One cell block: a straight hall with 2x2 cells on one or both sides, each gated onto that hall.
static func _place_block(g: DungeonGeom, f: int) -> bool:
	var row: ObstacleData = DataManager.get_obstacle_by_name(CELL_ROW)
	if row == null:
		return false
	var b: int = clampi(floori(g.d), 1, 5) - 1
	var n: int = randi_range(BLOCK_CELL_LO[b], BLOCK_CELL_HI[b])
	for _t: int in range(BLOCK_TRIES):
		var axis: int = randi() % 2
		var sides: Array[int] = []
		match randi() % 3:
			0:
				sides = [-1]
			1:
				sides = [1]
			_:
				sides = [-1, 1]
		var slots: int = ceili(float(n) / float(sides.size()))
		var span: int = 3 * slots + 1
		var across: int = 5 if sides.size() == 1 else 9
		var w: int = span if axis == 0 else across
		var h: int = across if axis == 0 else span
		var r: Rect2i = _cluster_rect(g, f, w, h, false)
		if r.size.x == 0:
			continue
		var lo: int = r.position.x if axis == 0 else r.position.y
		var base: int = r.position.y if axis == 0 else r.position.x
		var hp: int = base + 4 if sides.has(-1) else base
		var blk: Dictionary = {"axis": axis, "hp": hp, "lo": lo, "hi": lo + span - 1, "sides": sides}
		g.block_by_floor[f] = blk
		_stamp_hall(g, f, axis, lo, lo + span - 1, hp)
		for i: int in range(slots):
			for s: int in sides:
				_stamp_cell(g, f, row, axis, lo + 1 + 3 * i, hp, s)
		return true
	return false


#One more slot at a random end of the floor's block; the roll is spent when neither end fits.
static func _extend_block(g: DungeonGeom, f: int) -> bool:
	var row: ObstacleData = DataManager.get_obstacle_by_name(CELL_ROW)
	if row == null:
		return false
	var blk: Dictionary = g.block_by_floor.get(f, {}) as Dictionary
	if blk.is_empty():
		return false
	var sides: Array = blk["sides"] as Array
	if _cells_on(g, f) + sides.size() > CELLS_MAX:
		return false
	var axis: int = int(blk["axis"])
	var hp: int = int(blk["hp"])
	var ends: Array[int] = [1, -1]
	if randi() % 2 == 0:
		ends = [-1, 1]
	for e: int in ends:
		var lo: int = int(blk["lo"])
		var hi: int = int(blk["hi"])
		var a_lo: int = hi + 1 if e > 0 else lo - 3
		var a_hi: int = a_lo + 2
		if not _rect_free(g, f, _block_rect(axis, a_lo, a_hi, hp, sides)):
			continue
		_stamp_hall(g, f, axis, a_lo, a_hi, hp)
		for s: Variant in sides:
			_stamp_cell(g, f, row, axis, a_lo if e > 0 else a_lo + 1, hp, int(s))
		if e > 0:
			blk["hi"] = a_hi
		else:
			blk["lo"] = a_lo
		return true
	return false


#Along the hall axis at a, across it at p.
static func _block_point(axis: int, a: int, p: int) -> Vector2i:
	return Vector2i(a, p) if axis == 0 else Vector2i(p, a)


#The whole block over the along range, rings inclusive: the hall row plus four rows per used side.
static func _block_rect(axis: int, a_lo: int, a_hi: int, hp: int, sides: Array) -> Rect2i:
	var p_lo: int = hp
	var p_hi: int = hp
	for s: Variant in sides:
		if int(s) < 0:
			p_lo = hp - 4
		else:
			p_hi = hp + 4
	if axis == 0:
		return Rect2i(a_lo, p_lo, a_hi - a_lo + 1, p_hi - p_lo + 1)
	return Rect2i(p_lo, a_lo, p_hi - p_lo + 1, a_hi - a_lo + 1)


static func _stamp_hall(g: DungeonGeom, f: int, axis: int, a_lo: int, a_hi: int, hp: int) -> void:
	var seeds: Array = g.seed_halls.get(f, []) as Array
	for a: int in range(a_lo, a_hi + 1):
		var p: Vector2i = _block_point(axis, a, hp)
		_set_kind(g, f, p, K_HALL)
		seeds.append(p)
	g.seed_halls[f] = seeds


#A 2x2 cell one row off the hall, its gate fixed on the hall side at one of the cell's two columns.
static func _stamp_cell(g: DungeonGeom, f: int, row: ObstacleData, axis: int,
		a0: int, hp: int, s: int) -> void:
	var p0: int = hp + 2 if s > 0 else hp - 3
	var r: Rect2i = Rect2i(a0, p0, 2, 2) if axis == 0 else Rect2i(p0, a0, 2, 2)
	_stamp(g, f, row, r, true)
	var entry: Dictionary = g.rooms.back() as Dictionary
	var ga: int = a0 + (randi() % 2)
	var side: int = (2 if s < 0 else 3) if axis == 0 else (0 if s < 0 else 1)
	entry["doors"] = [{"pos": _block_point(axis, ga, hp + s), "out": _block_point(axis, ga, hp),
		"side": side, "orient": "h" if axis == 0 else "v"}]


static func _shrink_fit(g: DungeonGeom, f: int, w: int, h: int) -> Rect2i:
	if randi() % 2 == 1:
		var t: int = w
		w = h
		h = t
	for _s: int in range(SHRINK_STEPS):
		var r: Rect2i = _random_rect(g, f, w, h)
		if r.size.x > 0:
			return r
		if w <= 2 and h <= 2:
			break
		w = maxi(2, w - 1)
		h = maxi(2, h - 1)
	return Rect2i()


static func _random_rect(g: DungeonGeom, f: int, w: int, h: int) -> Rect2i:
	var xlo: int = g.ix0 + 1
	var xhi: int = g.ix1 - w
	var ylo: int = g.iy0 + 1
	var yhi: int = g.iy1 - h
	if xhi < xlo or yhi < ylo:
		return Rect2i()
	for _t: int in range(PLACE_TRIES):
		var r := Rect2i(randi_range(xlo, xhi), randi_range(ylo, yhi), w, h)
		if _rect_free(g, f, r):
			return r
	return Rect2i()


#Solid interior under the rect, a clear cell to its neighbours, and the free interior left in one piece.
static func _rect_free(g: DungeonGeom, f: int, r: Rect2i) -> bool:
	if r.size.x <= 0 or r.size.y <= 0:
		return false
	var blocked: Dictionary = g.blocked
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var p := Vector2i(x, y)
			if _kind_of(g, f, p) != K_WALL or blocked.has(p):
				return false
	var grown: Rect2i = r.grow(1)
	if g.has_band and grown.intersects(g.band):
		return false
	for entry: Dictionary in g.rooms:
		if int(entry["floor"]) != f:
			continue
		if grown.intersects(entry["rect"] as Rect2i):
			return false
	return not _splits_free(g, f, r)


#True when the rect and its ring would cut the carveable interior of the floor into two regions.
static func _splits_free(g: DungeonGeom, f: int, r: Rect2i) -> bool:
	var ix0: int = g.ix0
	var ix1: int = g.ix1
	var iy0: int = g.iy0
	var iy1: int = g.iy1
	var grown: Rect2i = r.grow(1)
	var outer: Rect2i = r.grow(2)
	var ring_ok: bool = true
	for x: int in range(outer.position.x, outer.end.x):
		if not _is_free(g, f, Vector2i(x, outer.position.y), grown):
			ring_ok = false
			break
		if not _is_free(g, f, Vector2i(x, outer.end.y - 1), grown):
			ring_ok = false
			break
	if ring_ok:
		for y: int in range(outer.position.y, outer.end.y):
			if not _is_free(g, f, Vector2i(outer.position.x, y), grown):
				ring_ok = false
				break
			if not _is_free(g, f, Vector2i(outer.end.x - 1, y), grown):
				ring_ok = false
				break
	if ring_ok:
		return false
	var open_cells: Dictionary = {}
	var start := Vector2i(-1, -1)
	for y: int in range(iy0, iy1 + 1):
		for x: int in range(ix0, ix1 + 1):
			var p := Vector2i(x, y)
			if _is_free(g, f, p, grown):
				open_cells[p] = true
				start = p
	if open_cells.is_empty():
		return false
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var qi: int = 0
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		for d: Vector2i in DIRS4:
			var nb: Vector2i = c + d
			if open_cells.has(nb) and not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
	return seen.size() < open_cells.size()


#A cell the halls could still carve or walk: interior band, or untouched wall outside every ring.
static func _is_free(g: DungeonGeom, f: int, p: Vector2i, grown: Rect2i) -> bool:
	if p.x < g.ix0 or p.x > g.ix1 or p.y < g.iy0 or p.y > g.iy1:
		return false
	var k: int = _kind_of(g, f, p)
	if k == K_BAND:
		return true
	if k != K_WALL:
		return false
	if g.blocked.has(p):
		return false
	if (g.rings[f] as Dictionary).has(p):
		return false
	return not grown.has_point(p)


static func _stamp(g: DungeonGeom, f: int, row: ObstacleData, r: Rect2i,
		is_cell: bool) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			_set_kind(g, f, Vector2i(x, y), K_CELL if is_cell else K_ROOM)
	var used: Dictionary = g.used
	used[row.obstacle_name] = int(used.get(row.obstacle_name, 0)) + 1
	g.rooms.append({"room": row, "rect": r, "floor": f, "is_cell": is_cell,
		"doors": []})
	_add_ring(g, f, r)


#Every cell of every room ring, per floor; halls never carve these, so rooms open by door only.
static func _add_ring(g: DungeonGeom, f: int, r: Rect2i) -> void:
	var ring: Dictionary = g.rings[f]
	var gr: Rect2i = r.grow(1)
	for x: int in range(gr.position.x, gr.end.x):
		ring[Vector2i(x, gr.position.y)] = true
		ring[Vector2i(x, gr.end.y - 1)] = true
	for y: int in range(gr.position.y, gr.end.y):
		ring[Vector2i(gr.position.x, y)] = true
		ring[Vector2i(gr.end.x - 1, y)] = true


static func _pick_doors(g: DungeonGeom, problems: Array[String]) -> void:
	var rings: Dictionary = g.rings
	for entry: Dictionary in g.rooms:
		if not (entry["doors"] as Array).is_empty():
			continue
		var f: int = int(entry["floor"])
		var r: Rect2i = entry["rect"] as Rect2i
		var want: int = _door_count(g, entry)
		var cands: Array[Dictionary] = _door_sites(g, f, r, rings[f] as Dictionary)
		cands.shuffle()
		var chosen: Array[Dictionary] = []
		var sides: Dictionary = {}
		for site: Dictionary in cands:
			if chosen.size() >= want:
				break
			if sides.has(int(site["side"])):
				continue
			sides[int(site["side"])] = true
			chosen.append(site)
		if chosen.is_empty():
			problems.append("room at (%d,%d) F%d has no door site" % [r.position.x, r.position.y, f])
		entry["doors"] = chosen


static func _door_count(g: DungeonGeom, entry: Dictionary) -> int:
	if bool(entry["is_cell"]):
		return 1
	var r: Rect2i = entry["rect"] as Rect2i
	if (entry["room"] as ObstacleData).obstacle_name == FOYER_ROW:
		if g.floors == 1 and g.chambers >= 6:
			return 3
		return 2
	if r.size.x * r.size.y >= 40 and randi() % 100 < 40:
		return 2
	return 1


#Ring cells minus the corners whose outward neighbour is free interior the halls can still reach.
static func _door_sites(g: DungeonGeom, f: int, r: Rect2i, ring: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gr: Rect2i = r.grow(1)
	for x: int in range(r.position.x, r.end.x):
		_add_site(g, f, ring, out, Vector2i(x, gr.position.y), Vector2i(0, -1), 2)
		_add_site(g, f, ring, out, Vector2i(x, gr.end.y - 1), Vector2i(0, 1), 3)
	for y: int in range(r.position.y, r.end.y):
		_add_site(g, f, ring, out, Vector2i(gr.position.x, y), Vector2i(-1, 0), 0)
		_add_site(g, f, ring, out, Vector2i(gr.end.x - 1, y), Vector2i(1, 0), 1)
	return out


static func _add_site(g: DungeonGeom, f: int, ring: Dictionary, out: Array[Dictionary],
		p: Vector2i, normal: Vector2i, side: int) -> void:
	var blocked: Dictionary = g.blocked
	if _kind_of(g, f, p) != K_WALL or blocked.has(p):
		return
	for d: Vector2i in DIRS4:
		if d == -normal:
			continue
		var k: int = _kind_of(g, f, p + d)
		if k == K_ROOM or k == K_CELL:
			return
	var o: Vector2i = p + normal
	var ok: int = _kind_of(g, f, o)
	if (ok != K_WALL and ok != K_BAND) or blocked.has(o) or ring.has(o):
		return
	out.append({"pos": p, "out": o, "side": side, "orient": "v" if normal.y == 0 else "h"})


#Spanning tree from the band (or the Foyer door) to every door, then loops, stubs and one wide route.
static func _carve_halls(g: DungeonGeom, f: int, problems: Array[String]) -> void:
	var kind: Dictionary = g.kinds[f]
	var no_carve: Dictionary = _no_carve_set(g, f)
	var wt: Dictionary = {}
	for p: Vector2i in kind.keys():
		if no_carve.has(p):
			continue
		var k: int = int(kind[p])
		if k == K_WALL:
			wt[p] = randi_range(1, 4)
		elif k == K_HALL or k == K_BAND:
			wt[p] = 1
	var targets: Array[Vector2i] = []
	var seen: Dictionary = {}
	var rooms_here: int = 0
	for entry: Dictionary in g.rooms:
		if int(entry["floor"]) != f:
			continue
		rooms_here += 1
		for door: Dictionary in (entry["doors"] as Array):
			var o: Vector2i = door["out"] as Vector2i
			if not seen.has(o):
				seen[o] = true
				targets.append(o)
	var connected: Dictionary = {}
	if g.has_band:
		var band: Rect2i = g.band
		for y: int in range(band.position.y, band.end.y):
			for x: int in range(band.position.x, band.end.x):
				connected[Vector2i(x, y)] = true
	elif not targets.is_empty():
		var seed_cell: Vector2i = targets[0]
		_carve_hall_cell(g, f, seed_cell, wt)
		connected[seed_cell] = true
	var first_path: Array[Vector2i] = []
	for _step: int in range(targets.size() + 1):
		var left: Array[Vector2i] = []
		for t: Vector2i in targets:
			if not connected.has(t):
				left.append(t)
		if left.is_empty():
			break
		var res: Dictionary = _dijkstra(connected, wt)
		var dist: Dictionary = res["dist"]
		var best: Vector2i = Vector2i(-1, -1)
		var best_d: int = BIG
		for t: Vector2i in left:
			var dv: int = int(dist.get(t, BIG))
			if dv < best_d:
				best_d = dv
				best = t
		if best_d >= BIG:
			problems.append("door unreachable on F%d" % f)
			break
		var path: Array[Vector2i] = _trace(res["prev"] as Dictionary, connected, best)
		for p: Vector2i in path:
			_carve_hall_cell(g, f, p, wt)
			connected[p] = true
		if first_path.is_empty():
			first_path = path
	if not first_path.is_empty():
		_widen(g, f, first_path, wt, no_carve)
	for _l: int in range(maxi(1, int(rooms_here / 4.0))):
		_add_loop(g, f, wt, no_carve)
	for _s: int in range(randi_range(1, 2) + int(rooms_here / 3.0)):
		_add_stub(g, f, wt, no_carve)


static func _no_carve_set(g: DungeonGeom, f: int) -> Dictionary:
	var out: Dictionary = {}
	for p: Variant in g.blocked.keys():
		out[p as Vector2i] = true
	for p: Variant in (g.rings[f] as Dictionary).keys():
		out[p as Vector2i] = true
	for entry: Dictionary in g.rooms:
		if int(entry["floor"]) != f:
			continue
		for door: Dictionary in (entry["doors"] as Array):
			out[door["pos"] as Vector2i] = true
	return out


static func _carve_hall_cell(g: DungeonGeom, f: int, p: Vector2i, wt: Dictionary) -> void:
	if _kind_of(g, f, p) != K_WALL:
		return
	_set_kind(g, f, p, K_HALL)
	wt[p] = 1


#Cheapest route cost to every reachable cell of wt, out of the already connected cells.
static func _dijkstra(sources: Dictionary, wt: Dictionary) -> Dictionary:
	var dist: Dictionary = {}
	var prev: Dictionary = {}
	var heap: Array = []
	for s: Variant in sources.keys():
		var sp: Vector2i = s as Vector2i
		dist[sp] = 0
		Pathfinder.heap_insert(heap, [0, sp])
	while not heap.is_empty():
		var top: Array = Pathfinder.heap_pop(heap)
		var d0: int = top[0]
		var c0: Vector2i = top[1]
		if d0 > int(dist.get(c0, BIG)):
			continue
		for dir: Vector2i in DIRS4:
			var nb: Vector2i = c0 + dir
			var w: int = int(wt.get(nb, -1))
			if w < 0:
				continue
			var nd: int = d0 + w
			if nd < int(dist.get(nb, BIG)):
				dist[nb] = nd
				prev[nb] = c0
				Pathfinder.heap_insert(heap, [nd, nb])
	return {"dist": dist, "prev": prev}


static func _trace(prev: Dictionary, sources: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cur: Vector2i = target
	for _g: int in range(4096):
		if sources.has(cur):
			break
		out.append(cur)
		if not prev.has(cur):
			break
		cur = prev[cur] as Vector2i
	out.reverse()
	return out


static func _widen(g: DungeonGeom, f: int, path: Array[Vector2i], wt: Dictionary,
		no_carve: Dictionary) -> void:
	var wide: Dictionary = g.wide.get(f, {}) as Dictionary
	for i: int in range(path.size()):
		var p: Vector2i = path[i]
		var dir: Vector2i = Vector2i(1, 0)
		if i + 1 < path.size():
			dir = path[i + 1] - p
		elif i > 0:
			dir = p - path[i - 1]
		var perp := Vector2i(-dir.y, dir.x)
		for cand: Vector2i in [p + perp, p - perp]:
			if no_carve.has(cand) or _kind_of(g, f, cand) != K_WALL:
				continue
			_carve_hall_cell(g, f, cand, wt)
			wide[cand] = true
			wide[p] = true
			break
	g.wide[f] = wide


#A second route between two carved cells, cut through untouched wall so the floor gains a ring.
static func _add_loop(g: DungeonGeom, f: int, wt: Dictionary, no_carve: Dictionary) -> void:
	var open_cells: Array[Vector2i] = _cells_of_kind(g, f, [K_HALL, K_BAND])
	if open_cells.size() < 2:
		return
	var virgin: Dictionary = {}
	for p: Variant in wt.keys():
		var pv: Vector2i = p as Vector2i
		if _kind_of(g, f, pv) == K_WALL and not no_carve.has(pv):
			virgin[pv] = int(wt[pv])
	if virgin.is_empty():
		return
	for _t: int in range(20):
		var a: Vector2i = open_cells[randi() % open_cells.size()]
		var b: Vector2i = open_cells[randi() % open_cells.size()]
		if absi(a.x - b.x) + absi(a.y - b.y) < 6:
			continue
		virgin[b] = 1
		var res: Dictionary = _dijkstra({a: true}, virgin)
		virgin.erase(b)
		if not (res["dist"] as Dictionary).has(b):
			continue
		for p: Vector2i in _trace(res["prev"] as Dictionary, {a: true}, b):
			_carve_hall_cell(g, f, p, wt)
		return


#A short blind corridor off the hall net; it stops before it can touch anything else.
static func _add_stub(g: DungeonGeom, f: int, wt: Dictionary, no_carve: Dictionary) -> void:
	var open_cells: Array[Vector2i] = _cells_of_kind(g, f, [K_HALL])
	if open_cells.is_empty():
		return
	var cur: Vector2i = open_cells[randi() % open_cells.size()]
	var dir: Vector2i = DIRS4[randi() % DIRS4.size()]
	for _i: int in range(randi_range(2, 5)):
		var nxt: Vector2i = cur + dir
		if no_carve.has(nxt) or _kind_of(g, f, nxt) != K_WALL:
			return
		var touches: int = 0
		for d: Vector2i in DIRS4:
			if _kind_of(g, f, nxt + d) != K_WALL and _kind_of(g, f, nxt + d) != -1:
				touches += 1
		if touches != 1:
			return
		_carve_hall_cell(g, f, nxt, wt)
		cur = nxt


static func _cells_of_kind(g: DungeonGeom, f: int, kinds: Array[int]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var kind: Dictionary = g.kinds[f]
	for p: Variant in kind.keys():
		if kinds.has(int(kind[p])):
			out.append(p as Vector2i)
	return out


#The one way in: a door in the F0 shell against the Foyer wall.
static func _place_entrance(area: BattlefieldArea, g: DungeonGeom, problems: Array[String]) -> void:
	var foyer: Dictionary = _foyer_entry(g)
	if foyer.is_empty():
		problems.append("no foyer")
		return
	var r: Rect2i = foyer["rect"] as Rect2i
	var side: int = g.foyer_side
	var cands: Array[Vector2i] = []
	if side <= 1:
		var wx: int = g.bld_x if side == 0 else g.bld_x + g.floor_w + 1
		if (side == 0 and r.position.x != g.ix0) or (side == 1 and r.end.x - 1 != g.ix1):
			problems.append("foyer is not flush")
			return
		for y: int in range(r.position.y, r.end.y):
			cands.append(Vector2i(wx, y))
	else:
		var wy: int = g.top_y if side == 2 else g.top_y + g.floor_d + 1
		if (side == 2 and r.position.y != g.iy0) or (side == 3 and r.end.y - 1 != g.iy1):
			problems.append("foyer is not flush")
			return
		for x: int in range(r.position.x, r.end.x):
			cands.append(Vector2i(x, wy))
	if cands.is_empty():
		problems.append("no entrance site")
		return
	var pos: Vector2i = cands[randi() % cands.size()]
	InteriorGenerator.place_door_at(area, Vector3i(pos.x, pos.y, 0), g.door,
		g.fh, "v" if side <= 1 else "h")
	area.entrance_cells.append(pos)
	g.entrance = pos


static func _foyer_entry(g: DungeonGeom) -> Dictionary:
	for entry: Dictionary in g.rooms:
		if (entry["room"] as ObstacleData).obstacle_name == FOYER_ROW:
			return entry
	return {}


static func _place_doors(area: BattlefieldArea, g: DungeonGeom) -> void:
	var fh: int = g.fh
	var lockable: int = 0
	var locked: int = 0
	for entry: Dictionary in g.rooms:
		var f: int = int(entry["floor"])
		var is_cell: bool = bool(entry["is_cell"])
		var lock_room: bool = false
		if not is_cell:
			var can_lock: bool = _lockable(entry["room"] as ObstacleData)
			if can_lock:
				lockable += 1
			lock_room = can_lock and randf() < DungeonLocks.lock_chance(g.d)
			entry["locked"] = lock_room
			if lock_room:
				locked += 1
		var room: Dictionary = {"rect": entry["rect"] as Rect2i, "floor": f,
			"name": (entry["room"] as ObstacleData).obstacle_name}
		for door: Dictionary in (entry["doors"] as Array):
			var p: Vector2i = door["pos"] as Vector2i
			var p3 := Vector3i(p.x, p.y, f)
			if is_cell:
				DungeonLocks.place_bar_door(area, p3, fh, String(door["orient"]), g.d,
					room)
			else:
				InteriorGenerator.place_door_at(area, p3, g.door, fh,
					String(door["orient"]))
				if lock_room:
					DungeonLocks.lock_door(area, p3, g.d, room)
			_set_kind(g, f, p, K_DOOR)
	area.generation_log.append("[LOCKS] Storage/Armory rooms locked %d of %d" % [locked, lockable])


#Only a Storage or an Armory room ever locks its doors.
static func _lockable(row: ObstacleData) -> bool:
	if row == null:
		return false
	return row.obstacle_name == STORAGE_ROW or row.obstacle_name == ARMORY_ROW


#The canvas box, shell ring included.
static func _box(g: DungeonGeom) -> Rect2i:
	return Rect2i(g.bld_x, g.top_y, g.floor_w + 2, g.floor_d + 2)


#The outline of one floor: every carved cell of the kind map grown by one in all eight directions.
static func _floor_mask(g: DungeonGeom, f: int) -> Dictionary:
	var out: Dictionary = {}
	var box: Rect2i = _box(g)
	var kind: Dictionary = g.kinds[f]
	for p: Variant in kind.keys():
		if int(kind[p]) == K_WALL:
			continue
		var pv: Vector2i = p as Vector2i
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var q := Vector2i(pv.x + dx, pv.y + dy)
				if box.has_point(q):
					out[q] = true
	return out


static func _apply_masks(area: BattlefieldArea, g: DungeonGeom) -> void:
	for f: int in _floor_list(g):
		for p: Variant in _floor_mask(g, f).keys():
			var pv: Vector2i = p as Vector2i
			area.footprint_cells[Vector3i(pv.x, pv.y, f)] = true
	area.set_footprint_from_cells()


#Mask cells the layout never carved become solid rock; cells outside the mask are void.
static func _fill_walls(area: BattlefieldArea, g: DungeonGeom) -> void:
	var wall_data: ObstacleData = g.wall
	var fh: int = g.fh
	var box: Rect2i = _box(g)
	for f: int in _floor_list(g):
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				var p := Vector2i(x, y)
				var p3 := Vector3i(x, y, f)
				if not area.in_footprint_floor(p, f):
					area.building_interiors.erase(p3)
					continue
				if _kind_of(g, f, p) > K_WALL:
					continue
				InteriorGenerator.place_wall_if_empty(area, p3, 4, wall_data, fh)
				area.building_interiors.erase(p3)


static func _finish(area: BattlefieldArea, g: DungeonGeom) -> void:
	var furn: Array[Dictionary] = []
	for entry: Dictionary in g.rooms:
		furn.append({"room": entry["room"], "rect": entry["rect"], "floor": entry["floor"]})
		area.interior_rooms.append({"rect": entry["rect"], "floor": entry["floor"],
			"name": (entry["room"] as ObstacleData).obstacle_name})
	InteriorGenerator.place_furniture_in_rooms(area, furn)
	_record_halls(area, g)
	_assign_spawns(area, g)
	NavLinkBuilder.build_stair_links(area)
	area._rebuild_cover_obstacles()
	area._rebuild_droppable_obs_map()
	_fill_stats(area, g)


#Straight runs of hall, so the dump and the viewer can name them.
static func _record_halls(area: BattlefieldArea, g: DungeonGeom) -> void:
	var ix0: int = g.ix0
	var ix1: int = g.ix1
	var iy0: int = g.iy0
	var iy1: int = g.iy1
	for f: int in _floor_list(g):
		var wide: Dictionary = g.wide.get(f, {}) as Dictionary
		for y: int in range(iy0, iy1 + 1):
			var run: int = -1
			for x: int in range(ix0, ix1 + 2):
				var hall: bool = x <= ix1 and _kind_of(g, f, Vector2i(x, y)) == K_HALL
				if hall and run < 0:
					run = x
				elif not hall and run >= 0:
					_append_hall(area, f, Rect2i(run, y, x - run, 1), wide)
					run = -1
		for x: int in range(ix0, ix1 + 1):
			var run_y: int = -1
			for y: int in range(iy0, iy1 + 2):
				var hall: bool = y <= iy1 and _kind_of(g, f, Vector2i(x, y)) == K_HALL
				if hall and run_y < 0:
					run_y = y
				elif not hall and run_y >= 0:
					_append_hall(area, f, Rect2i(x, run_y, 1, y - run_y), wide)
					run_y = -1


static func _append_hall(area: BattlefieldArea, f: int, r: Rect2i, wide: Dictionary) -> void:
	if maxi(r.size.x, r.size.y) < 3:
		return
	var is_wide: bool = false
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			if wide.has(Vector2i(x, y)):
				is_wide = true
	area.dungeon_halls.append({"rect": r, "floor": f,
		"name": HALL_WIDE if is_wide else HALL_NARROW})


#Team A holds the Foyer; team B holds the chamber furthest from the entrance by walked steps.
static func _assign_spawns(area: BattlefieldArea, g: DungeonGeom) -> void:
	var foyer: Dictionary = _foyer_entry(g)
	if foyer.is_empty():
		return
	area.spawn_radius = 3.0
	var zone_a: Dictionary = _free_zone(area, foyer["rect"] as Rect2i, 0)
	area.spawn_zone_a = zone_a
	area.spawn_center_a = _zone_center(zone_a, foyer["rect"] as Rect2i)
	area.spawn_floor_a = 0
	var ent: Vector2i = g.entrance
	var dist: Dictionary = _walk_dist(area, Vector3i(ent.x, ent.y, 0), true)
	var best: Dictionary = {}
	var best_d: int = -1
	for entry: Dictionary in g.rooms:
		if bool(entry["is_cell"]) or entry == foyer:
			continue
		var f: int = int(entry["floor"])
		var dv: int = _room_dist(dist, entry["rect"] as Rect2i, f)
		if dv < 0:
			continue
		if dv > best_d or (dv == best_d and f < int(best.get("floor", 1))):
			best_d = dv
			best = entry
	if best.is_empty():
		best = foyer
		best_d = 0
	var rb: Rect2i = best["rect"] as Rect2i
	var fb: int = int(best["floor"])
	var zone_b: Dictionary = _free_zone(area, rb, fb)
	area.spawn_zone_b = zone_b
	area.spawn_center_b = _zone_center(zone_b, rb)
	area.spawn_floor_b = fb
	area.generation_log.append("[SPAWN] dungeon A Foyer F0 (%d,%d) zone=%d  B %s F%d (%d,%d) zone=%d depth=%d" % [
		area.spawn_center_a.x, area.spawn_center_a.y, zone_a.size(),
		(best["room"] as ObstacleData).obstacle_name, fb,
		area.spawn_center_b.x, area.spawn_center_b.y, zone_b.size(), best_d])


static func _free_zone(area: BattlefieldArea, r: Rect2i, f: int) -> Dictionary:
	var out: Dictionary = {}
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			if area._obs_map.has(Vector3i(x, y, f)):
				continue
			out[Vector2i(x, y)] = true
	return out


static func _zone_center(zone: Dictionary, r: Rect2i) -> Vector2i:
	var want := Vector2i(r.position.x + (r.size.x >> 1), r.position.y + (r.size.y >> 1))
	if zone.has(want):
		return want
	var best: Vector2i = want
	var best_d: int = BIG
	for p: Variant in zone.keys():
		var pv: Vector2i = p as Vector2i
		var dv: int = absi(pv.x - want.x) + absi(pv.y - want.y)
		if dv < best_d:
			best_d = dv
			best = pv
	return best


static func _room_dist(dist: Dictionary, r: Rect2i, f: int) -> int:
	var best: int = -1
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var dv: int = int(dist.get(Vector3i(x, y, f), -1))
			if dv >= 0 and (best < 0 or dv < best):
				best = dv
	return best


#Walked step count from one cell, through doors and the stair links.
static func _walk_dist(area: BattlefieldArea, start: Vector3i, allow_locked: bool) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[Vector3i] = [start]
	var qi: int = 0
	while qi < queue.size():
		var c: Vector3i = queue[qi]
		qi += 1
		var nd: int = int(dist[c]) + 1
		for nb: Vector3i in _open_neighbors(area, c, allow_locked):
			if dist.has(nb):
				continue
			dist[nb] = nd
			queue.append(nb)
	return dist


static func _open_neighbors(area: BattlefieldArea, c: Vector3i, allow_locked: bool) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for d: Vector2i in DIRS4:
		var nb := Vector3i(c.x + d.x, c.y + d.y, c.z)
		if _passable(area, nb, allow_locked):
			out.append(nb)
	if area.stairwell_connections.has(c):
		var link: Vector3i = area.stairwell_connections[c] as Vector3i
		if _passable(area, link, allow_locked):
			out.append(link)
	return out


#Structural passability: inside the shell and not sealed by wall, window or a locked gate.
static func _passable(area: BattlefieldArea, c: Vector3i, allow_locked: bool) -> bool:
	if not area.interior_floor_elevations.has(c.z):
		return false
	if not area.in_footprint_floor(Vector2i(c.x, c.y), c.z):
		return false
	var obs: Dictionary = area._obs_map.get(c, {}) as Dictionary
	var ct: String = obs.get("cell_type", "")
	if ct == "wall" or ct == "window":
		return false
	if ct == "door" and not allow_locked and DungeonLocks.is_locked(obs):
		return false
	return true


static func _fill_stats(area: BattlefieldArea, g: DungeonGeom) -> void:
	var chambers: int = 0
	var cells: int = 0
	for entry: Dictionary in g.rooms:
		if bool(entry["is_cell"]):
			cells += 1
		else:
			chambers += 1
	var loops: int = 0
	var dead_ends: int = 0
	var floor_loops: Dictionary = {}
	var floor_dead: Dictionary = {}
	for f: int in _floor_list(g):
		var st: Dictionary = floor_graph(area, f)
		floor_loops[f] = int(st["loops"])
		floor_dead[f] = int(st["dead_ends"])
		loops += int(st["loops"])
		dead_ends += int(st["dead_ends"])
	var walls: int = 0
	for obs: Dictionary in area.obstacles:
		if obs.get("cell_type", "") == "wall":
			walls += 1
	var mask: Dictionary = {}
	var fill: Dictionary = {}
	var fill_min: int = 100
	for f: int in _floor_list(g):
		var info: Dictionary = mask_info(area, f)
		mask[f] = int(info["count"])
		fill[f] = int(info["fill"])
		fill_min = mini(fill_min, int(info["fill"]))
	area.dungeon_stats = {
		"floors": g.floors, "chambers": chambers, "cells": cells,
		"halls": area.dungeon_halls.size(), "loops": loops, "dead_ends": dead_ends,
		"floor_loops": floor_loops, "floor_dead_ends": floor_dead, "walls": walls,
		"floor_w": g.floor_w, "floor_d": g.floor_d,
		"blocks": g.blocks_made, "mask": mask, "fill": fill, "fill_min": fill_min,
		"difficulty": g.d, "ms": 0, "violations": 0,
	}


#Mask cell count of one floor, its bounding rect, and how much of that box those cells fill.
static func mask_info(area: BattlefieldArea, f: int) -> Dictionary:
	var n: int = 0
	var lo := Vector2i(BIG, BIG)
	var hi := Vector2i(-BIG, -BIG)
	for key: Variant in area.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if c.z != f:
			continue
		n += 1
		lo.x = mini(lo.x, c.x)
		lo.y = mini(lo.y, c.y)
		hi.x = maxi(hi.x, c.x)
		hi.y = maxi(hi.y, c.y)
	if n == 0:
		return {"count": 0, "rect": Rect2i(), "fill": 0}
	var rect := Rect2i(lo.x, lo.y, hi.x - lo.x + 1, hi.y - lo.y + 1)
	return {"count": n, "rect": rect, "fill": int(float(n * 100) / float(maxi(1, rect.size.x * rect.size.y)))}


#Loop count and dead end count of the hall net on one floor; rooms and doors are not nodes.
static func floor_graph(area: BattlefieldArea, f: int) -> Dictionary:
	var rects: Array[Rect2i] = []
	for entry: Dictionary in area.interior_rooms:
		if int(entry.get("floor", 0)) == f:
			rects.append(entry["rect"] as Rect2i)
	var nodes: Dictionary = {}
	for key: Variant in area.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if c.z != f:
			continue
		var p := Vector2i(c.x, c.y)
		if not _passable(area, c, true):
			continue
		if area.cell_type_at(c) == "door":
			continue
		var inside: bool = false
		for r: Rect2i in rects:
			if r.has_point(p):
				inside = true
				break
		if not inside:
			nodes[p] = true
	var edges: int = 0
	var dead_ends: int = 0
	for p: Variant in nodes.keys():
		var pv: Vector2i = p as Vector2i
		var deg: int = 0
		for d: Vector2i in DIRS4:
			if nodes.has(pv + d):
				deg += 1
		edges += deg
		if deg == 1:
			dead_ends += 1
	edges = edges >> 1
	var comps: int = 0
	var seen: Dictionary = {}
	for p: Variant in nodes.keys():
		var pv: Vector2i = p as Vector2i
		if seen.has(pv):
			continue
		comps += 1
		var stack: Array[Vector2i] = [pv]
		seen[pv] = true
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			for d: Vector2i in DIRS4:
				var nb: Vector2i = cur + d
				if nodes.has(nb) and not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
	return {"loops": maxi(0, edges - nodes.size() + comps), "dead_ends": dead_ends,
		"cells": nodes.size()}


#Everything Build 1 promises about a finished dungeon; an empty array means the map is sound.
static func validate(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	if not area.is_dungeon:
		out.append("is_dungeon false")
	if not area.is_interior_map:
		out.append("is_interior_map false")
	if area.unevenness != 6:
		out.append("unevenness %d" % area.unevenness)
	var floors: int = area.interior_floor_elevations.size()
	var want_floors: int = int(area.dungeon_stats.get("floors", floors))
	if floors != want_floors:
		out.append("floors %d want %d" % [floors, want_floors])
	if area.stair_runs.size() != floors - 1:
		out.append("stair_runs %d want %d" % [area.stair_runs.size(), floors - 1])
	if floors > 1 and area.stair_run_cells.is_empty():
		out.append("no stair band")
	out.append_array(_check_shell(area))
	out.append_array(_check_counts(area))
	out.append_array(_check_doors(area))
	out.append_array(_check_reach(area))
	out.append_array(_check_shape(area))
	if area.spawn_zone_a.is_empty():
		out.append("spawn zone A empty")
	if area.spawn_zone_b.is_empty():
		out.append("spawn zone B empty")
	if area.spawn_floor_b > area.spawn_floor_a:
		out.append("spawn floor B %d above A %d" % [area.spawn_floor_b, area.spawn_floor_a])
	return out


#Every mask edge cell walled, one F0 door in it, and no carved cell touching that edge.
static func _check_shell(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	var doors: int = 0
	var holes: int = 0
	for key: Variant in area.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		var p := Vector2i(c.x, c.y)
		var edge: bool = false
		for d: Vector2i in DIRS4:
			if not area.in_footprint_floor(p + d, c.z):
				edge = true
				break
		if not edge:
			continue
		var ct: String = area.cell_type_at(c)
		if ct == "door":
			doors += 1
		elif ct != "wall":
			holes += 1
	for key: Variant in area.building_interiors.keys():
		var c: Vector3i = key as Vector3i
		if not _mask_inner(area, c):
			out.append("carved cell on the mask edge (%d,%d) F%d" % [c.x, c.y, c.z])
			break
	if doors != 1:
		out.append("shell doors %d want 1" % doors)
	if holes > 0:
		out.append("shell gaps %d" % holes)
	if area.entrance_cells.size() != 1:
		out.append("entrance_cells %d want 1" % area.entrance_cells.size())
	elif doors == 1 and not area.entrance_cells.is_empty():
		var e: Vector2i = area.entrance_cells[0]
		if area.cell_type_at(Vector3i(e.x, e.y, 0)) != "door":
			out.append("entrance cell holds no door")
	return out


#True when all eight neighbours of the cell are in its own floor mask.
static func _mask_inner(area: BattlefieldArea, c: Vector3i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not area.in_footprint_floor(Vector2i(c.x + dx, c.y + dy), c.z):
				return false
	return true


static func _check_counts(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	var b: int = clampi(floori(area.dungeon_difficulty), 1, 5) - 1
	var chambers: int = 0
	var cells: int = 0
	var foyers: int = 0
	var per_floor: Dictionary = {}
	for entry: Dictionary in area.interior_rooms:
		var n: String = String(entry.get("name", ""))
		if n == CELL_ROW:
			cells += 1
			var f: int = int(entry.get("floor", 0))
			per_floor[f] = int(per_floor.get(f, 0)) + 1
		else:
			chambers += 1
		if n == FOYER_ROW:
			foyers += 1
	if chambers < ROOM_LO[b] or chambers > ROOM_HI[b]:
		out.append("chambers %d outside %d-%d" % [chambers, ROOM_LO[b], ROOM_HI[b]])
	var blocks: int = int(area.dungeon_stats.get("blocks", 0))
	if cells < blocks * CELLS_MIN or cells > blocks * CELLS_MAX:
		out.append("cells %d outside %d-%d" % [cells, blocks * CELLS_MIN, blocks * CELLS_MAX])
	for key: Variant in per_floor.keys():
		var f2: int = int(key)
		var n2: int = int(per_floor[key])
		if n2 < CELLS_MIN or n2 > CELLS_MAX:
			out.append("F%d cells %d want 0 or 4 to 10" % [f2, n2])
		if not _one_cell_hall(area, f2):
			out.append("F%d cells sit on more than one hall" % f2)
	if foyers != 1:
		out.append("foyers %d want 1" % foyers)
	for obs: Dictionary in area.obstacles:
		if obs.get("cell_type", "") == "window":
			out.append("window in a dungeon")
			break
	return out


#Every cell gate of the floor faces one straight run of open, doorless cells.
static func _one_cell_hall(area: BattlefieldArea, f: int) -> bool:
	var fronts: Array[Vector2i] = []
	for entry: Dictionary in area.interior_rooms:
		if String(entry.get("name", "")) != CELL_ROW or int(entry.get("floor", 0)) != f:
			continue
		var r: Rect2i = entry["rect"] as Rect2i
		for obs: Dictionary in _ring_doors(area, r, f):
			var p: Vector3i = obs.get("pos", Vector3i(-1, -1, 0)) as Vector3i
			var front: Vector2i = _gate_front(r, Vector2i(p.x, p.y))
			if front.x < 0:
				return false
			fronts.append(front)
	if fronts.is_empty():
		return true
	var same_x: bool = true
	var same_y: bool = true
	for p2: Vector2i in fronts:
		if p2.x != fronts[0].x:
			same_x = false
		if p2.y != fronts[0].y:
			same_y = false
	if not same_x and not same_y:
		return false
	var lo: int = BIG
	var hi: int = -BIG
	for p3: Vector2i in fronts:
		var v: int = p3.y if same_x else p3.x
		lo = mini(lo, v)
		hi = maxi(hi, v)
	for v2: int in range(lo, hi + 1):
		var c: Vector3i = Vector3i(fronts[0].x, v2, f) if same_x else Vector3i(v2, fronts[0].y, f)
		if not _passable(area, c, true):
			return false
		if area.cell_type_at(c) == "door":
			return false
	return true


#The cell the gate opens onto, away from the room; (-1,-1) when the gate is not on the ring.
static func _gate_front(r: Rect2i, gate: Vector2i) -> Vector2i:
	if gate.y == r.position.y - 1 and gate.x >= r.position.x and gate.x < r.end.x:
		return gate + Vector2i(0, -1)
	if gate.y == r.end.y and gate.x >= r.position.x and gate.x < r.end.x:
		return gate + Vector2i(0, 1)
	if gate.x == r.position.x - 1 and gate.y >= r.position.y and gate.y < r.end.y:
		return gate + Vector2i(-1, 0)
	if gate.x == r.end.x and gate.y >= r.position.y and gate.y < r.end.y:
		return gate + Vector2i(1, 0)
	return Vector2i(-1, -1)


#Door counts per room and the lock carried by every cell gate.
static func _check_doors(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	var want_lock: int = DungeonLocks.lock_difficulty_for(area.dungeon_difficulty)
	for entry: Dictionary in area.interior_rooms:
		var r: Rect2i = entry["rect"] as Rect2i
		var f: int = int(entry.get("floor", 0))
		var n: String = String(entry.get("name", ""))
		var found: Array[Dictionary] = _ring_doors(area, r, f)
		if n == CELL_ROW:
			if found.size() != 1:
				out.append("cell (%d,%d) F%d has %d doors" % [r.position.x, r.position.y, f, found.size()])
				continue
			var obs: Dictionary = found[0]
			if not DungeonLocks.is_locked(obs):
				out.append("cell gate (%d,%d) F%d not locked" % [r.position.x, r.position.y, f])
			if not DungeonLocks.has_bars(obs):
				out.append("cell gate (%d,%d) F%d has no bars" % [r.position.x, r.position.y, f])
			if DungeonLocks.lock_difficulty(obs) != want_lock:
				out.append("cell gate (%d,%d) F%d lock %d want %d" % [r.position.x, r.position.y, f,
					DungeonLocks.lock_difficulty(obs), want_lock])
		else:
			if found.size() < 1 or found.size() > 3:
				out.append("chamber (%d,%d) F%d has %d doors" % [r.position.x, r.position.y, f,
					found.size()])
			for door: Dictionary in found:
				if not DungeonLocks.is_locked(door):
					continue
				if DungeonLocks.has_bars(door):
					out.append("chamber (%d,%d) F%d locked with bars" % [r.position.x, r.position.y, f])
				if DungeonLocks.lock_difficulty(door) != want_lock:
					out.append("chamber (%d,%d) F%d lock %d want %d" % [r.position.x, r.position.y, f,
						DungeonLocks.lock_difficulty(door), want_lock])
				if n != STORAGE_ROW and n != ARMORY_ROW:
					out.append("chamber (%d,%d) F%d locked but not Storage or Armory" % [
						r.position.x, r.position.y, f])
		if not InteriorGenerator.room_accessible_from_doors(area, r, f):
			out.append("room (%d,%d) F%d is cut off inside" % [r.position.x, r.position.y, f])
	return out


static func _ring_doors(area: BattlefieldArea, r: Rect2i, f: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var gr: Rect2i = r.grow(1)
	var seen: Dictionary = {}
	for x: int in range(gr.position.x, gr.end.x):
		for y: int in [gr.position.y, gr.end.y - 1]:
			if area.entrance_cells.has(Vector2i(x, y)):
				continue
			_add_door(area, Vector3i(x, y, f), seen, out)
	for y: int in range(gr.position.y + 1, gr.end.y - 1):
		for x: int in [gr.position.x, gr.end.x - 1]:
			if area.entrance_cells.has(Vector2i(x, y)):
				continue
			_add_door(area, Vector3i(x, y, f), seen, out)
	return out


static func _add_door(area: BattlefieldArea, c: Vector3i, seen: Dictionary,
		out: Array[Dictionary]) -> void:
	if seen.has(c):
		return
	seen[c] = true
	var obs: Dictionary = area._obs_map.get(c, {}) as Dictionary
	if obs.get("cell_type", "") == "door":
		out.append(obs)


#Every carved cell reachable from the Foyer, and every chamber reachable without a locked gate.
static func _check_reach(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	var start := Vector3i(-1, -1, 0)
	for entry: Dictionary in area.interior_rooms:
		if String(entry.get("name", "")) != FOYER_ROW:
			continue
		var r: Rect2i = entry["rect"] as Rect2i
		start = Vector3i(r.position.x, r.position.y, int(entry.get("floor", 0)))
		break
	if start.x < 0:
		out.append("no foyer to start from")
		return out
	var open_dist: Dictionary = _walk_dist(area, start, true)
	var missed: int = 0
	for key: Variant in area.footprint_cells.keys():
		var c: Vector3i = key as Vector3i
		if _passable(area, c, true) and not open_dist.has(c):
			missed += 1
	if missed > 0:
		out.append("%d carved cells unreachable from the Foyer" % missed)
	var free_dist: Dictionary = _walk_dist(area, start, false)
	for entry: Dictionary in area.interior_rooms:
		var n: String = String(entry.get("name", ""))
		if n == CELL_ROW:
			continue
		var rr: Rect2i = entry["rect"] as Rect2i
		var ff: int = int(entry.get("floor", 0))
		if _room_dist(free_dist, rr, ff) < 0 and not locked_room(area, rr, ff):
			out.append("chamber (%d,%d) F%d needs a locked gate" % [rr.position.x, rr.position.y, ff])
	return out


#True when the room carries doors and every one of them is locked, as a locked Storage or Armory does.
static func locked_room(area: BattlefieldArea, r: Rect2i, f: int) -> bool:
	var doors: Array[Dictionary] = _ring_doors(area, r, f)
	if doors.is_empty():
		return false
	for door: Dictionary in doors:
		if not DungeonLocks.is_locked(door):
			return false
	return true


#Busy floors owe the party at least one ring and one blind corridor.
static func _check_shape(area: BattlefieldArea) -> Array[String]:
	var out: Array[String] = []
	var per_floor: Dictionary = {}
	for entry: Dictionary in area.interior_rooms:
		if String(entry.get("name", "")) == CELL_ROW:
			continue
		var f: int = int(entry.get("floor", 0))
		per_floor[f] = int(per_floor.get(f, 0)) + 1
	for f: Variant in per_floor.keys():
		if int(per_floor[f]) < 4:
			continue
		var st: Dictionary = floor_graph(area, f as int)
		if int(st["loops"]) < 1:
			out.append("F%d has no hall loop" % int(f))
		if int(st["dead_ends"]) < 1:
			out.append("F%d has no dead end" % int(f))
	var fill_min: int = int(area.dungeon_stats.get("fill_min", 0))
	if fill_min >= FILL_BOXY:
		out.append("every floor fills its box (%d%% min)" % fill_min)
	return out
