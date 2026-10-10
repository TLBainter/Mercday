class_name CityGrid

#Cell access for the two city grids of a BattlefieldArea (surface_grid, street_grid). Shared by the city
#generator classes, the validator, the level dump and the tests so that all of them read cells one way.

const SIDES: Array[String] = ["N", "S", "W", "E"]
#Street kind to the surface that kind paints, so rank() stays the one precedence table.
const KIND_SURF: Dictionary = {"main": BattlefieldArea.SURF_MAIN, "side": BattlefieldArea.SURF_SIDE,
	"alley": BattlefieldArea.SURF_ALLEY, "": BattlefieldArea.SURF_NONE}
const TOUCH_MIN := 3
#Neighbour offsets in x-first order; the region walks of CityPlots and CityValidator share this order.
const DX_XFIRST: Array[int] = [1, -1, 0, 0]
const DY_XFIRST: Array[int] = [0, 0, 1, -1]


#Sizes both grids to width * length: every surface SURF_NONE, every street id -1.
static func init(area: BattlefieldArea) -> void:
	var n: int = area.width * area.length
	area.surface_grid = PackedByteArray()
	area.surface_grid.resize(n)
	area.surface_grid.fill(BattlefieldArea.SURF_NONE)
	area.street_grid = PackedInt32Array()
	area.street_grid.resize(n)
	area.street_grid.fill(-1)


#SURF_* of a cell; SURF_NONE off the map.
static func surf(area: BattlefieldArea, x: int, y: int) -> int:
	if not area.in_bounds_xy(x, y):
		return BattlefieldArea.SURF_NONE
	return area.surface_grid[y * area.width + x]


#Street id of a cell; -1 off the map and on cells no street owns.
static func street_id(area: BattlefieldArea, x: int, y: int) -> int:
	if not area.in_bounds_xy(x, y):
		return -1
	return area.street_grid[y * area.width + x]


#Main street, side street, sidewalk or alley.
static func is_street(s: int) -> bool:
	return s >= BattlefieldArea.SURF_MAIN and s <= BattlefieldArea.SURF_ALLEY


#Main street or side street carriageway.
static func is_carriage(s: int) -> bool:
	return s == BattlefieldArea.SURF_MAIN or s == BattlefieldArea.SURF_SIDE


#Main street, side street or sidewalk.
static func is_paved(s: int) -> bool:
	return is_carriage(s) or s == BattlefieldArea.SURF_SIDEWALK


#Paint priority: main 4, side 3, sidewalk 2, alley 1, everything else 0.
static func rank(s: int) -> int:
	match s:
		BattlefieldArea.SURF_MAIN:
			return 4
		BattlefieldArea.SURF_SIDE:
			return 3
		BattlefieldArea.SURF_SIDEWALK:
			return 2
		BattlefieldArea.SURF_ALLEY:
			return 1
	return 0


#Paint priority of a street kind, read through the surface table so one order serves both.
static func kind_rank(kind: String) -> int:
	return rank(int(KIND_SURF.get(kind, BattlefieldArea.SURF_NONE)))


#Writes a street surface where it outranks what the cell holds; true when the cell was written.
static func paint(area: BattlefieldArea, x: int, y: int, s: int, sid: int) -> bool:
	if not area.in_bounds_xy(x, y):
		return false
	var i: int = y * area.width + x
	if rank(s) <= rank(area.surface_grid[i]):
		return false
	area.surface_grid[i] = s
	area.street_grid[i] = sid
	return true


#Writes a street surface over whatever the cell holds; the override the alley ring pass needs.
static func paint_force(area: BattlefieldArea, x: int, y: int, s: int, sid: int) -> void:
	if paint(area, x, y, s, sid):
		return
	if not area.in_bounds_xy(x, y):
		return
	var i: int = y * area.width + x
	area.surface_grid[i] = s
	area.street_grid[i] = sid


#Writes an alley cell over whatever it holds and raises it to curb height.
static func paint_alley(area: BattlefieldArea, c: Vector2i, sid: int) -> void:
	paint_force(area, c.x, c.y, BattlefieldArea.SURF_ALLEY, sid)
	area.terrain_heights[c] = CityGenerator.CURB


#Appends a street record with the next id and returns it; extra keys are merged after the common ones.
static func add_street(streets: Array, kind: String, axis: String, segments: Array, dead_end: bool,
		block: int, mouth: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = {
		"id": streets.size(),
		"kind": kind,
		"axis": axis,
		"dead_end": dead_end,
		"block": block,
		"mouth": mouth,
		"segments": segments,
	}
	rec.merge(extra)
	streets.append(rec)
	return rec


#Frontage and depth of a size seen from a front side: x is the span along the street, y the span away from it.
static func front_span(size: Vector2i, front: String) -> Vector2i:
	if front == "N" or front == "S":
		return size
	return Vector2i(size.y, size.x)


static func paint_rect(area: BattlefieldArea, rect: Rect2i, s: int, sid: int) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			paint(area, x, y, s, sid)


#SURF_LOT or SURF_NATURE on the cells of rect that still hold SURF_NONE; street cells are never touched.
static func fill_ground(area: BattlefieldArea, rect: Rect2i, s: int) -> void:
	for y: int in range(maxi(rect.position.y, 0), mini(rect.end.y, area.length)):
		for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, area.width)):
			var i: int = y * area.width + x
			if area.surface_grid[i] == BattlefieldArea.SURF_NONE:
				area.surface_grid[i] = s


#Kind of the street that owns a cell ("main", "side", "alley"); "" when no street owns it.
static func kind_at(area: BattlefieldArea, x: int, y: int) -> String:
	var sid: int = street_id(area, x, y)
	var streets: Array = area.city.get("streets", [])
	if sid < 0 or sid >= streets.size():
		return ""
	return String((streets[sid] as Dictionary).get("kind", ""))


#The cells just outside one side of rect. N is the y-min side, S the y-max side, W x-min, E x-max.
static func side_cells(rect: Rect2i, side: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match side:
		"N":
			for x: int in range(rect.position.x, rect.end.x):
				out.append(Vector2i(x, rect.position.y - 1))
		"S":
			for x: int in range(rect.position.x, rect.end.x):
				out.append(Vector2i(x, rect.end.y))
		"W":
			for y: int in range(rect.position.y, rect.end.y):
				out.append(Vector2i(rect.position.x - 1, y))
		"E":
			for y: int in range(rect.position.y, rect.end.y):
				out.append(Vector2i(rect.end.x, y))
	return out


#Street cells just outside one side of rect: {"count": cells, "kind": the widest street kind among them}.
static func side_touch(area: BattlefieldArea, rect: Rect2i, side: String) -> Dictionary:
	var count: int = 0
	var best: String = ""
	for c: Vector2i in side_cells(rect, side):
		if not is_street(surf(area, c.x, c.y)):
			continue
		count += 1
		var k: String = kind_at(area, c.x, c.y)
		if kind_rank(k) > kind_rank(best):
			best = k
	return {"count": count, "kind": best}


#A side gives street access when at least TOUCH_MIN of its outside cells (or all of a shorter side) are street cells.
static func side_has_access(area: BattlefieldArea, rect: Rect2i, side: String) -> bool:
	var span: int = rect.size.x if (side == "N" or side == "S") else rect.size.y
	return int(side_touch(area, rect, side)["count"]) >= mini(TOUCH_MIN, span)


#True when any one side of rect has street access.
static func has_any_access(area: BattlefieldArea, rect: Rect2i) -> bool:
	for side: String in SIDES:
		if side_has_access(area, rect, side):
			return true
	return false
