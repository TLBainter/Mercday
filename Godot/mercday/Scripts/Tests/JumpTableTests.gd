class_name JumpTableTests
extends RefCounted

#Shared jump landing table: PathJump.jump_dests must match a live rebuild of the old loop on a city
#map and on an interior map, the table must grow with the range, and bump_path_version must clear it.
#CityTests.run() calls run_cases.

const CITY_TIER := "Small"
const CITY_SEED := 7501
const CITY_TRIES := 5
const CITY_STRIDE := 7
const CITY_CAP := 400
const INTERIOR_SEED := 7502
const INTERIOR_CAP := 600
const CITY_REQUESTS: Array[Array] = [[4, 3], [1, 0], [2, 2], [3, 1], [4, 1]]
const INTERIOR_REQUESTS: Array[Array] = [[1, 1], [4, 3], [2, 0]]
const GROW_RANGE := 4


static func run_cases(res: Dictionary) -> void:
	_case_city(res)
	var interior: BattlefieldArea = TestFixtures.seeded_tavern(INTERIOR_SEED)
	_case_interior(res, interior)
	_case_grows(res, interior)
	_case_door_kept(res, interior)
	_case_cleared(res, interior)


#Floors of the map: floor 0 plus every interior floor above it, in order.
static func _floors(field: BattlefieldArea) -> Array[int]:
	var out: Array[int] = [0]
	var above: Array[int] = []
	for f: int in field.interior_floor_elevations.keys():
		if f > 0:
			above.append(f)
	above.sort()
	out.append_array(above)
	return out


#Floor 0 cells thinned by stride, plus every walkable cell of the floors above.
static func _sample_cells(field: BattlefieldArea, stride: int, cap: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var seen: int = 0
	for f: int in _floors(field):
		for x: int in range(field.width):
			for y: int in range(field.length):
				var pos := Vector2i(x, y)
				if not field.has_walkable_surface(pos, f):
					continue
				if f == 0:
					seen += 1
					if stride > 1 and (seen % stride) != 0:
						continue
				out.append(Vector3i(x, y, f))
				if out.size() >= cap:
					return out
	return out


#A private copy of the pre-table jump_dests loop; reads nothing cached.
static func _reference(field: BattlefieldArea, cell: Vector3i, jump_range: int, merc_size: int) -> Array:
	var out: Array = []
	var cell_h: float = field.cell_base_elevation(Vector2i(cell.x, cell.y), cell.z)
	for dx: int in range(-jump_range, jump_range + 1):
		for dy: int in range(-jump_range, jump_range + 1):
			var cdist := maxi(abs(dx), abs(dy))
			if cdist == 0 or cdist > jump_range:
				continue
			var jcell := Vector3i(cell.x + dx, cell.y + dy, cell.z)
			var kind := PathJump.jump_dest_kind(jcell, field, merc_size)
			if kind == PathJump.JUMP_DEST_NONE:
				continue
			var h_cost := int(ceil(maxf(0.0,
				field.cell_base_elevation(Vector2i(jcell.x, jcell.y), jcell.z) - cell_h)))
			if cdist + h_cost > jump_range:
				continue
			if PathJump.leap_wall_blocked(field, cell, jcell):
				continue
			var door: Dictionary = {}
			if kind == PathJump.JUMP_DEST_DOOR:
				door = field.get_obs(Vector2i(jcell.x, jcell.y), jcell.z)
			out.append([jcell, cdist + h_cost, door, PathJump.leap_doors(field, cell, jcell)])
	return out


static func _same_doors(a: Dictionary, b: Dictionary) -> bool:
	if is_same(a, b):
		return true
	return a.is_empty() and b.is_empty()


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		var ra: Array = a[i]
		var rb: Array = b[i]
		if (ra[0] as Vector3i) != (rb[0] as Vector3i):
			return false
		if (ra[1] as int) != (rb[1] as int):
			return false
		if not _same_doors(ra[2] as Dictionary, rb[2] as Dictionary):
			return false
		var ca: Array = ra[3]
		var cb: Array = rb[3]
		if ca.size() != cb.size():
			return false
		for j: int in range(ca.size()):
			if not is_same(ca[j], cb[j]):
				return false
	return true


#Runs every request over every cell and reports the first mismatch.
static func _compare(field: BattlefieldArea, cells: Array[Vector3i],
		requests: Array[Array]) -> Dictionary:
	var rows: int = 0
	for req: Array in requests:
		var jump_range: int = req[0]
		var merc_size: int = req[1]
		for cell: Vector3i in cells:
			var got: Array = PathJump.jump_dests(field, cell, jump_range, merc_size)
			var want: Array = _reference(field, cell, jump_range, merc_size)
			rows += want.size()
			if not _same(got, want):
				return {"bad": "cell %d,%d,%d range %d size %d: %d row(s) of %d"
					% [cell.x, cell.y, cell.z, jump_range, merc_size, got.size(), want.size()],
					"rows": rows}
	return {"bad": "", "rows": rows}


#Fails `label` and reports true when the map is missing, so the case can return at once.
static func _guard_map(res: Dictionary, field: BattlefieldArea, label: String,
		detail: String = "no interior map") -> bool:
	if field != null:
		return false
	TestFixtures.check(res, label, false, detail)
	return true


#The first sample cell with a range GROW_RANGE row; fails `label` and returns a negative cell when none has one.
static func _pick_cell(res: Dictionary, field: BattlefieldArea, label: String) -> Vector3i:
	for cell: Vector3i in _sample_cells(field, 1, INTERIOR_CAP):
		if not _reference(field, cell, GROW_RANGE, 0).is_empty():
			return cell
	TestFixtures.check(res, label, false, "no cell with a range %d row" % GROW_RANGE)
	return Vector3i(-1, -1, -1)


static func _case_city(res: Dictionary) -> void:
	var field: BattlefieldArea = CityFillTests.city_map(CITY_TIER, CITY_SEED, CITY_TRIES)
	if _guard_map(res, field, "jumptable_city_matches", "no Small map"):
		return
	var cells: Array[Vector3i] = _sample_cells(field, CITY_STRIDE, CITY_CAP)
	var out: Dictionary = _compare(field, cells, CITY_REQUESTS)
	var bad: String = String(out["bad"])
	TestFixtures.check(res, "jumptable_city_matches", bad.is_empty(),
		"%d cell(s) %d row(s)" % [cells.size(), int(out["rows"])] if bad.is_empty() else bad)


static func _case_interior(res: Dictionary, field: BattlefieldArea) -> void:
	if _guard_map(res, field, "jumptable_interior_matches"):
		return
	var cells: Array[Vector3i] = _sample_cells(field, 1, INTERIOR_CAP)
	var out: Dictionary = _compare(field, cells, INTERIOR_REQUESTS)
	var bad: String = String(out["bad"])
	TestFixtures.check(res, "jumptable_interior_matches", bad.is_empty(),
		"%d cell(s) %d row(s)" % [cells.size(), int(out["rows"])] if bad.is_empty() else bad)


static func _case_grows(res: Dictionary, field: BattlefieldArea) -> void:
	if _guard_map(res, field, "jumptable_grows"):
		return
	var pick: Vector3i = _pick_cell(res, field, "jumptable_grows")
	if pick.z < 0:
		return
	field.bump_path_version()
	var near: Array = PathJump.jump_dests(field, pick, 1, 0)
	var far: Array = PathJump.jump_dests(field, pick, GROW_RANGE, 0)
	var entry: Array = field.jump_geom[pick]
	var bad: Array[String] = []
	if (entry[0] as int) != GROW_RANGE:
		bad.append("built_range=%d of %d" % [entry[0] as int, GROW_RANGE])
	if not _same(near, _reference(field, pick, 1, 0)):
		bad.append("range 1 rows differ")
	if not _same(far, _reference(field, pick, GROW_RANGE, 0)):
		bad.append("range %d rows differ" % GROW_RANGE)
	TestFixtures.check(res, "jumptable_grows", bad.is_empty(),
		"near=%d far=%d" % [near.size(), far.size()] if bad.is_empty() else bad[0])


static func _case_door_kept(res: Dictionary, field: BattlefieldArea) -> void:
	if _guard_map(res, field, "jumptable_door_kept"):
		return
	field.bump_path_version()
	var pick: Vector3i = _pick_cell(res, field, "jumptable_door_kept")
	if pick.z < 0:
		return
	PathJump.jump_dests(field, pick, GROW_RANGE, 0)
	var geom_before: int = field.jump_geom.size()
	var path_before: int = field.path_version
	var door_before: int = field.door_version
	field.bump_door_version()
	var ok: bool = geom_before > 0 and field.jump_geom.size() == geom_before \
		and field.path_version == path_before and field.door_version == door_before + 1
	TestFixtures.check(res, "jumptable_door_kept", ok,
		"geom %d -> %d, path %d -> %d, door %d -> %d" % [geom_before, field.jump_geom.size(), path_before,
			field.path_version, door_before, field.door_version])


static func _case_cleared(res: Dictionary, field: BattlefieldArea) -> void:
	if _guard_map(res, field, "jumptable_cleared"):
		return
	field.bump_path_version()
	var ok: bool = field.jump_geom.is_empty() and field.jump_kind_static.is_empty() \
		and field.jump_static.is_empty()
	TestFixtures.check(res, "jumptable_cleared", ok,
		"geom=%d kind=%d static=%d" % [field.jump_geom.size(), field.jump_kind_static.size(),
			field.jump_static.size()])
