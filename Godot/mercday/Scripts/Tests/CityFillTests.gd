class_name CityFillTests

#Fill stage of a city block map: lots and buildings, door footpaths, back lanes, outdoor objects, spawn
#zones, window posts and the battle spawn of a mixed team. CityTests.run() calls run_cases.

const PER_MAP := 2
const EPS := 0.001
const GAP := 2
const MIN_OUTDOOR := 8
const DUMP_NAME := "test_fill_dump"
const OBJ_HEAD := "=== City objects (floor 0) ==="
const RNG_SEED := 77
const BATTLE_SEED := 9800
const BATTLE_MAPS := 12
const BATTLE_USE := 3
const TAGS: Array[String] = ["nature", "lamp", "alley", "sidewalk", "square"]
const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]


static func run_cases(res: Dictionary, maps: Array[Dictionary]) -> void:
	_case_city_column(res)
	_case_lots(res, maps)
	_case_spacing(res, maps)
	_case_doors(res, maps)
	_case_lanes(res, maps)
	_case_stats(res, maps)
	_case_obj_legal(res, maps)
	_case_obj_tags(res, maps)
	_case_obj_counts(res, maps)
	_case_lamps(res, maps)
	_case_squares(res, maps)
	_case_spawn_zones(res, maps)
	_case_window_posts(res, maps)
	_case_dump(res)
	_case_spawn_battle(res)


#The city map of tier generated from seed_base; _tries is ignored and stays only for callers that pass it.
static func city_map(tier: String, seed_base: int, _tries: int = 1) -> BattlefieldArea:
	return TestFixtures.city_gen(tier, seed_base, CityGenTests.ROW)


static func _note(bad: Array[String], hits: int, text: String) -> int:
	if hits < PER_MAP:
		bad.append(text)
	return hits + 1


static func _city_objects(map: BattlefieldArea) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for obs: Dictionary in map.obstacles:
		if obs.has("city"):
			out.append(obs)
	return out


static func _cells_of(obs: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var pos: Vector3i = obs.get("pos", Vector3i.ZERO)
	for dy: int in range(maxi(1, int(obs.get("ph", 1)))):
		for dx: int in range(maxi(1, int(obs.get("pw", 1)))):
			out.append(Vector2i(pos.x + dx, pos.y + dy))
	return out


static func _names(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for n: Variant in list:
		out[String(n)] = true
	return out


#The row names the City column gives a use, as a name set.
static func _use_names(use: String) -> Dictionary:
	var out: Dictionary = {}
	for row: ObstacleData in DataManager.get_city_obstacles(use):
		out[row.obstacle_name] = true
	return out


static func _row_name(obs: Dictionary) -> String:
	var d: ObstacleData = obs.get("data") as ObstacleData
	return "?" if d == null else d.obstacle_name


static func _failed_lots(map: BattlefieldArea) -> int:
	var out: int = 0
	for lot: Dictionary in (map.city.get("lots", []) as Array):
		if lot.has("failed"):
			out += 1
	return out


#City objects that are not nature plantings.
static func _street_objects(map: BattlefieldArea) -> int:
	var out: int = 0
	for obs: Dictionary in _city_objects(map):
		if String(obs.get("city", "")) != "nature":
			out += 1
	return out


static func _mains(map: BattlefieldArea) -> int:
	var out: int = 0
	for st: Dictionary in (map.city.get("streets", []) as Array):
		if String(st.get("kind", "")) == "main":
			out += 1
	return out


static func _touches(map: BattlefieldArea, cell: Vector2i, want: Array[int]) -> bool:
	for d: int in range(4):
		if want.has(CityGrid.surf(map, cell.x + DX[d], cell.y + DY[d])):
			return true
	return false


static func _case_city_column(res: Dictionary) -> void:
	var bad: Array[String] = []
	for use: String in DataManager.CITY_USES:
		var rows: Array[ObstacleData] = DataManager.get_city_obstacles(use)
		if rows.is_empty():
			bad.append("no row with City use %s" % use)
			continue
		for row: ObstacleData in rows:
			if not row.city_uses.has(use):
				bad.append("row %s is listed under %s but does not carry it" % [row.obstacle_name, use])
	var nonbuilding: Dictionary = {}
	for o: ObstacleData in DataManager.obstacles_nonbuilding_pool:
		nonbuilding[o.obstacle_name] = true
	for o2: ObstacleData in DataManager.obstacles_pool:
		if o2.city_only and nonbuilding.has(o2.obstacle_name):
			bad.append("city only row %s sits in the non-building pool" % o2.obstacle_name)
	for keep: String in ["Crate", "Well"]:
		var row2: ObstacleData = DataManager.get_obstacle_by_name(keep)
		if row2 == null:
			bad.append("no obstacle row %s" % keep)
			continue
		var want: bool = not row2.building_only and not row2.is_building and not row2.ramp \
			and not row2.is_room
		if nonbuilding.has(keep) != want:
			bad.append("row %s in the non-building pool %s, wanted %s"
				% [keep, str(nonbuilding.has(keep)), str(want)])
	for spec: Array in [["City Statue", 6.0], ["Statue", 3.0], ["Crate", 1.0]]:
		var sname: String = String(spec[0])
		var row3: ObstacleData = DataManager.get_obstacle_by_name(sname)
		if row3 == null:
			bad.append("no obstacle row %s" % sname)
			continue
		if absf(row3.size_z - float(spec[1])) > EPS:
			bad.append("row %s has Size Z %s, wanted %s" % [sname, str(row3.size_z), str(spec[1])])
	TestFixtures.check(res, "citygen_fill_city_column", bad.is_empty(),
		"ok" if bad.is_empty() else bad[0])


static func _case_lots(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		var lots: Array = map.city.get("lots", [])
		var named: Dictionary = {}
		total += lots.size()
		for li: int in range(lots.size()):
			var lot: Dictionary = lots[li]
			var bid: int = int(lot.get("building", -1))
			var failed: bool = bool(lot.get("failed", false))
			if (bid >= 0) == failed:
				hits = _note(bad, hits, "s%d lot %d building %d failed %s"
					% [s, li, bid, str(failed)])
				continue
			if not lot.has("tried") or (lot.get("tried", []) as Array).is_empty():
				hits = _note(bad, hits, "s%d lot %d tried no row" % [s, li])
				continue
			var lr: Rect2i = lot.get("rect", Rect2i())
			if bid < 0:
				if _lot_owned(map, lr):
					hits = _note(bad, hits, "s%d failed lot %d keeps a building cell" % [s, li])
				continue
			if named.has(bid):
				hits = _note(bad, hits, "s%d lots %d and %d name building %d"
					% [s, int(named[bid]), li, bid])
				continue
			named[bid] = li
			if bid >= map.buildings.size():
				hits = _note(bad, hits, "s%d lot %d names building %d of %d"
					% [s, li, bid, map.buildings.size()])
				continue
			hits = _fit_check(map, lot, li, bid, s, bad, hits)
		for b: int in range(map.buildings.size()):
			if not named.has(b):
				hits = _note(bad, hits, "s%d building %d is named by no lot" % [s, b])
	TestFixtures.check(res, "citygen_fill_lots", bad.is_empty(), TestFixtures.detail(bad, total, "lot(s)"))


static func _lot_owned(map: BattlefieldArea, lr: Rect2i) -> bool:
	for y: int in range(lr.position.y, lr.end.y):
		for x: int in range(lr.position.x, lr.end.x):
			if map.building_id_at.has(Vector2i(x, y)):
				return true
	return false


#The record sits inside its lot with a 1 cell margin on the sides and the back, 0 on the front.
static func _fit_check(map: BattlefieldArea, lot: Dictionary, li: int, bid: int, s: int,
		bad: Array[String], hits: int) -> int:
	var lr: Rect2i = lot.get("rect", Rect2i())
	var front: String = String(lot.get("front", ""))
	var rec: Dictionary = map.buildings[bid]
	var br: Rect2i = rec.get("rect", Rect2i())
	if String(rec.get("front", "")) != front:
		return _note(bad, hits, "s%d lot %d front %s but building %d front %s"
			% [s, li, front, bid, String(rec.get("front", ""))])
	if not lr.encloses(br):
		return _note(bad, hits, "s%d building %d %s leaves lot %d %s" % [s, bid, str(br), li, str(lr)])
	var gaps: Array[int] = [br.position.y - lr.position.y, lr.end.y - br.end.y,
		br.position.x - lr.position.x, lr.end.x - br.end.x]
	var want: Array[int] = [1, 1, 1, 1]
	var fi: int = CityGrid.SIDES.find(front)
	if fi >= 0:
		want[fi] = 0
	for i: int in range(4):
		if gaps[i] < want[i]:
			return _note(bad, hits, "s%d building %d leaves %d cell(s) on side %s of lot %d"
				% [s, bid, gaps[i], String(CityGrid.SIDES[i]), li])
	return hits


static func _case_spacing(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		total += map.buildings.size()
		for key: Variant in map.building_id_at.keys():
			var cell: Vector2i = key as Vector2i
			var id: int = int(map.building_id_at[cell])
			if not _edge_cell(map, cell):
				continue
			var near: int = _near_other(map, cell, id)
			if near < 0:
				continue
			hits = _note(bad, hits, "s%d building %d cell %d,%d sits by building %d"
				% [s, id, cell.x, cell.y, near])
			if hits > PER_MAP:
				break
	TestFixtures.check(res, "citygen_fill_spacing", bad.is_empty(),
		TestFixtures.detail(bad, total, "building(s)"))


static func _edge_cell(map: BattlefieldArea, cell: Vector2i) -> bool:
	for d: int in range(4):
		if not map.building_id_at.has(Vector2i(cell.x + DX[d], cell.y + DY[d])):
			return true
	return false


static func _near_other(map: BattlefieldArea, cell: Vector2i, id: int) -> int:
	for dy: int in range(-GAP, GAP + 1):
		for dx: int in range(-GAP, GAP + 1):
			var other: int = int(map.building_id_at.get(Vector2i(cell.x + dx, cell.y + dy), -1))
			if other >= 0 and other != id:
				return other
	return -1


static func _case_doors(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	var yards: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		var access: Dictionary = map.city.get("access", {})
		var doors: Array = access.get("doors", [])
		var protected: Dictionary = access.get("protected", {})
		var reach0: PackedByteArray = access.get("reach0", PackedByteArray())
		var flood_a: PackedByteArray = CityAccess.flood(map, map.spawn_center_a, true)
		var flood_b: PackedByteArray = CityAccess.flood(map, map.spawn_center_b, true)
		var want: Dictionary = {}
		for rec: Dictionary in map.buildings:
			var id: int = int(rec.get("id", -1))
			var fd: Vector3i = rec.get("front_door", Vector3i(-1, -1, 0))
			var bd: Vector3i = rec.get("back_door", Vector3i(-1, -1, 0))
			if fd.x >= 0:
				want["%d:front" % id] = true
			if bd.x >= 0:
				want["%d:back" % id] = true
		total += doors.size()
		var seen: Dictionary = {}
		for e: Dictionary in doors:
			var key: String = "%d:%s" % [int(e.get("building", -1)), String(e.get("kind", ""))]
			if seen.has(key) or not want.has(key):
				hits = _note(bad, hits, "s%d stray door entry %s" % [s, key])
				continue
			seen[key] = true
			if bool(e.get("yard", false)):
				yards += 1
			hits = _door_check(map, e, s, protected, reach0, flood_a, flood_b, bad, hits)
		for miss: Variant in want.keys():
			if not seen.has(String(miss)):
				hits = _note(bad, hits, "s%d door %s has no entry" % [s, String(miss)])
	TestFixtures.check(res, "citygen_fill_doors", bad.is_empty(),
		"%s; doors=%d yard=%d" % [TestFixtures.detail(bad, total, "door(s)"), total, yards])


static func _door_check(map: BattlefieldArea, e: Dictionary, s: int, protected: Dictionary,
		reach0: PackedByteArray, flood_a: PackedByteArray, flood_b: PackedByteArray,
		bad: Array[String], hits: int) -> int:
	var id: int = int(e.get("building", -1))
	var kind: String = String(e.get("kind", ""))
	var door: Vector3i = e.get("door", Vector3i(-1, -1, 0))
	var outside: Vector2i = e.get("outside", Vector2i(-1, -1))
	if not CityAccess.is_ground(map, outside):
		return _note(bad, hits, "s%d building %d %s door exits %d,%d off the ground"
			% [s, id, kind, outside.x, outside.y])
	var i: int = outside.y * map.width + outside.x
	if i >= reach0.size() or reach0[i] != 1:
		return _note(bad, hits, "s%d building %d %s door exit %d,%d is not on the street net"
			% [s, id, kind, outside.x, outside.y])
	if not protected.has(outside) or map._obs_map.has(Vector3i(outside.x, outside.y, 0)):
		return _note(bad, hits, "s%d building %d %s door exit %d,%d is not a clear protected cell"
			% [s, id, kind, outside.x, outside.y])
	if i >= flood_a.size() or flood_a[i] != 1 or i >= flood_b.size() or flood_b[i] != 1:
		return _note(bad, hits, "s%d building %d %s door exit %d,%d is cut from a spawn"
			% [s, id, kind, outside.x, outside.y])
	var rec: Dictionary = map.buildings[id] if id >= 0 and id < map.buildings.size() else {}
	var side: String = String(rec.get("front", ""))
	if kind == "back":
		side = BuildingLayouts.opposite(side)
	var raw: Vector2i = Vector2i(door.x, door.y) - CityAccess._inward(side)
	if not bool(e.get("yard", false)):
		if outside != raw:
			return _note(bad, hits, "s%d building %d %s door exit %d,%d is not step %d,%d"
				% [s, id, kind, outside.x, outside.y, raw.x, raw.y])
		return hits
	if int(map.building_id_at.get(raw, -1)) != id \
			or map.footprint_cells.has(Vector3i(raw.x, raw.y, 0)):
		return _note(bad, hits, "s%d building %d %s yard door %d,%d opens on no yard cell"
			% [s, id, kind, raw.x, raw.y])
	return hits


static func _case_lanes(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		var access: Dictionary = map.city.get("access", {})
		var doors: Array = access.get("doors", [])
		var protected: Dictionary = access.get("protected", {})
		for st: Dictionary in (map.city.get("streets", []) as Array):
			if not st.has("back_door"):
				continue
			total += 1
			hits = _lane_check(map, st, s, doors, protected, bad, hits)
		for e: Dictionary in doors:
			if String(e.get("kind", "")) != "back" or int(e.get("lane", -1)) >= 0:
				continue
			total += 1
			var outside: Vector2i = e.get("outside", Vector2i(-1, -1))
			if CityGrid.is_street(CityGrid.surf(map, outside.x, outside.y)):
				continue
			if _lane_skipped(map, int(e.get("building", -1))):
				continue
			hits = _note(bad, hits, "s%d building %d back door exit %d,%d took no lane"
				% [s, int(e.get("building", -1)), outside.x, outside.y])
	TestFixtures.check(res, "citygen_fill_lanes", bad.is_empty(), TestFixtures.detail(bad, total, "lane(s)"))


static func _lane_check(map: BattlefieldArea, st: Dictionary, s: int, doors: Array,
		protected: Dictionary, bad: Array[String], hits: int) -> int:
	var id: int = int(st.get("id", -1))
	var bid: int = int(st.get("back_door", -1))
	if String(st.get("kind", "")) != "alley" or not bool(st.get("dead_end", false)) \
			or int(st.get("block", 0)) != -1:
		return _note(bad, hits, "s%d lane %d kind=%s dead_end=%s block=%d"
			% [s, id, String(st.get("kind", "")), str(st.get("dead_end", false)),
			int(st.get("block", 0))])
	var segs: Array = st.get("segments", [])
	if segs.is_empty():
		return _note(bad, hits, "s%d lane %d holds no segment" % [s, id])
	var bad_cell: Vector2i = _lane_fault(map, segs, id, protected)
	if bad_cell.x >= 0:
		return _note(bad, hits, "s%d lane %d cell %d,%d is no painted alley cell"
			% [s, id, bad_cell.x, bad_cell.y])
	if bid < 0 or bid >= map.buildings.size():
		return _note(bad, hits, "s%d lane %d names building %d" % [s, id, bid])
	var bd: Vector3i = (map.buildings[bid] as Dictionary).get("back_door", Vector3i(-1, -1, 0))
	if bd.x < 0:
		return _note(bad, hits, "s%d lane %d names building %d which has no back door" % [s, id, bid])
	var last: Rect2i = (segs[segs.size() - 1] as Dictionary).get("rect", Rect2i())
	var found: bool = false
	for e: Dictionary in doors:
		if int(e.get("building", -1)) != bid or String(e.get("kind", "")) != "back":
			continue
		if int(e.get("lane", -1)) != id:
			continue
		var outside: Vector2i = e.get("outside", Vector2i(-1, -1))
		found = found or last.has_point(outside)
	if not found:
		return _note(bad, hits, "s%d lane %d holds no back door exit of building %d" % [s, id, bid])
	var mouth: Vector2i = st.get("mouth", Vector2i(-1, -1))
	if not CityGrid.is_street(CityGrid.surf(map, mouth.x, mouth.y)) \
			or CityGrid.street_id(map, mouth.x, mouth.y) == id:
		return _note(bad, hits, "s%d lane %d mouth %d,%d is on no other street"
			% [s, id, mouth.x, mouth.y])
	return hits


#The first segment cell that is no 1 wide painted lane cell, or (-1, -1).
static func _lane_fault(map: BattlefieldArea, segs: Array, id: int, protected: Dictionary) -> Vector2i:
	for seg: Dictionary in segs:
		var rect: Rect2i = seg.get("rect", Rect2i())
		if int(seg.get("width", 0)) != 1 or mini(rect.size.x, rect.size.y) != 1:
			return rect.position
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				if CityGrid.surf(map, x, y) != BattlefieldArea.SURF_ALLEY:
					return c
				if CityGrid.street_id(map, x, y) != id or not protected.has(c):
					return c
				if absf(float(map.terrain_heights.get(c, 0.0)) - CityGenTests.CURB) > EPS:
					return c
	return Vector2i(-1, -1)


static func _lane_skipped(map: BattlefieldArea, bid: int) -> bool:
	var needle: String = "[CITY] back lane skipped: building %d " % bid
	for line: String in map.generation_log:
		if line.begins_with(needle):
			return true
	return false


static func _case_stats(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		total += 1
		var stats: Dictionary = map.city.get("stats", {})
		var lanes: int = 0
		var ring_cells: int = 0
		var link_cells: int = 0
		var links: int = 0
		var lone: int = 0
		for st: Dictionary in (map.city.get("streets", []) as Array):
			if st.has("back_door"):
				lanes += 1
			if not CityAlleys.is_wrap(st):
				continue
			var painted: int = (st.get("cells", []) as Array).size()
			if st.has("connector"):
				link_cells += painted
				links += 1
				continue
			ring_cells += painted
			if bool(st.get("isolated", false)):
				lone += 1
		var street_obs: int = _street_objects(map)
		var want: Dictionary = {"buildings": map.buildings.size(), "failed_lots": _failed_lots(map),
			"back_lanes": lanes, "nature_objects": _city_objects(map).size() - street_obs,
			"street_objects": street_obs,
			"alley_ring_cells": ring_cells, "alley_connector_cells": link_cells,
			"alley_connectors": links, "alley_isolated": lone,
			"alley_connect_d": CityAlleys.connect_d_for(mini(map.width, map.length))}
		for key: Variant in want.keys():
			if int(stats.get(key, -1)) != int(want[key]):
				hits = _note(bad, hits, "s%d stats %s %d of %d"
					% [s, String(key), int(stats.get(key, -1)), int(want[key])])
		if map.buildings.is_empty():
			hits = _note(bad, hits, "s%d holds no building" % s)
	TestFixtures.check(res, "citygen_fill_stats", bad.is_empty(), TestFixtures.detail(bad, total, "map(s)"))


static func _case_obj_legal(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		for obs: Dictionary in _city_objects(map):
			total += 1
			hits = _legal_check(map, obs, s, bad, hits)
	TestFixtures.check(res, "citygen_obj_legal", bad.is_empty(), TestFixtures.detail(bad, total, "object(s)"))


static func _legal_check(map: BattlefieldArea, obs: Dictionary, s: int, bad: Array[String],
		hits: int) -> int:
	var tag: String = String(obs.get("city", ""))
	var pos: Vector3i = obs.get("pos", Vector3i.ZERO)
	var data: ObstacleData = obs.get("data") as ObstacleData
	if not TAGS.has(tag) or data == null:
		return _note(bad, hits, "s%d object %d,%d tag %s" % [s, pos.x, pos.y, tag])
	if pos.z != 0 or int(obs.get("floor", -1)) != 0:
		return _note(bad, hits, "s%d object %d,%d floor %d z %d"
			% [s, pos.x, pos.y, int(obs.get("floor", -1)), pos.z])
	var pw: int = 1
	var ph: int = 1
	if data.obstacle_type != "Vegetation":
		pw = maxi(1, ceili(data.size_x))
		ph = maxi(1, ceili(data.size_y))
		if bool(obs.get("rotated", false)):
			var swap: int = pw
			pw = ph
			ph = swap
	if int(obs.get("pw", 0)) != pw or int(obs.get("ph", 0)) != ph:
		return _note(bad, hits, "s%d object %s %d,%d is %dx%d not %dx%d"
			% [s, data.obstacle_name, pos.x, pos.y, int(obs.get("pw", 0)), int(obs.get("ph", 0)),
			pw, ph])
	var blocking: bool = not (data.passthrough or data.ramp)
	for c: Vector2i in _cells_of(obs):
		if not map.in_bounds_xy(c.x, c.y) or map.building_id_at.has(c):
			return _note(bad, hits, "s%d object %s cell %d,%d is off the open map"
				% [s, data.obstacle_name, c.x, c.y])
		var surf: int = CityGrid.surf(map, c.x, c.y)
		if surf == BattlefieldArea.SURF_MAIN or surf == BattlefieldArea.SURF_SIDE:
			return _note(bad, hits, "s%d object %s cell %d,%d sits on the carriageway"
				% [s, data.obstacle_name, c.x, c.y])
		if _reserved(map, c) or map.spawn_zone_a.has(c) or map.spawn_zone_b.has(c):
			return _note(bad, hits, "s%d object %s cell %d,%d is reserved ground"
				% [s, data.obstacle_name, c.x, c.y])
		var held: Dictionary = map._obs_map.get(Vector3i(c.x, c.y, 0), {})
		var anchor: bool = c == Vector2i(pos.x, pos.y)
		if anchor and not is_same(held, obs):
			return _note(bad, hits, "s%d object %s anchor %d,%d holds another record"
				% [s, data.obstacle_name, c.x, c.y])
		if not anchor and String(held.get("cell_type", "")) != "reserved":
			return _note(bad, hits, "s%d object %s cell %d,%d holds no reserved entry"
				% [s, data.obstacle_name, c.x, c.y])
		if blocking and CityAccess.narrow_gap(map, c):
			return _note(bad, hits, "s%d object %s blocks the narrow gap at %d,%d"
				% [s, data.obstacle_name, c.x, c.y])
	return hits


static func _reserved(map: BattlefieldArea, cell: Vector2i) -> bool:
	var access: Dictionary = map.city.get("access", {})
	return (access.get("protected", {}) as Dictionary).has(cell)


static func _case_obj_tags(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	var area_row: Dictionary = DataManager.get_area_by_name(CityGenTests.ROW)
	var veg: Dictionary = _names(area_row.get("vegetation_list", []) as Array)
	var lamps: Dictionary = _use_names("lamp")
	var walks: Dictionary = _use_names("sidewalk")
	var alleys: Dictionary = _use_names("alley")
	var structs: Dictionary = _use_names("square")
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		for obs: Dictionary in _city_objects(map):
			total += 1
			var tag: String = String(obs.get("city", ""))
			var row_name: String = _row_name(obs)
			var pos: Vector3i = obs.get("pos", Vector3i.ZERO)
			var cell := Vector2i(pos.x, pos.y)
			var surf: int = CityGrid.surf(map, cell.x, cell.y)
			var ok: bool = true
			match tag:
				"lamp":
					ok = lamps.has(row_name) and surf == BattlefieldArea.SURF_SIDEWALK
				"sidewalk":
					ok = walks.has(row_name) \
						and surf == BattlefieldArea.SURF_SIDEWALK
				"alley":
					ok = alleys.has(row_name) \
						and surf == BattlefieldArea.SURF_ALLEY and not _on_lane(map, cell)
				"nature":
					ok = veg.has(row_name) and surf == BattlefieldArea.SURF_NATURE
				"square":
					ok = structs.has(row_name) and surf == BattlefieldArea.SURF_NATURE
				_:
					ok = false
			if not ok:
				hits = _note(bad, hits, "s%d %s %s at %d,%d surface %d"
					% [s, tag, row_name, cell.x, cell.y, surf])
	TestFixtures.check(res, "citygen_obj_tags", bad.is_empty(), TestFixtures.detail(bad, total, "object(s)"))


static func _on_lane(map: BattlefieldArea, cell: Vector2i) -> bool:
	var sid: int = CityGrid.street_id(map, cell.x, cell.y)
	var streets: Array = map.city.get("streets", [])
	if sid < 0 or sid >= streets.size():
		return false
	return (streets[sid] as Dictionary).has("back_door")


static func _case_obj_counts(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		total += 1
		var kept: Dictionary = map.city.get("objects", {})
		var count: Dictionary = {"blocking": 0}
		for tag: String in TAGS:
			count[tag] = 0
		for obs: Dictionary in _city_objects(map):
			var tag2: String = String(obs.get("city", ""))
			count[tag2] = int(count.get(tag2, 0)) + 1
			var data: ObstacleData = obs.get("data") as ObstacleData
			if tag2 == "nature" and data != null and not (data.passthrough or data.ramp):
				count["blocking"] = int(count["blocking"]) + 1
		for key: Variant in count.keys():
			var tag3: String = String(key)
			if int(kept.get(tag3, -1)) != int(count[tag3]):
				hits = _note(bad, hits, "s%d objects %s %d of %d"
					% [s, tag3, int(kept.get(tag3, -1)), int(count[tag3])])
	TestFixtures.check(res, "citygen_obj_counts", bad.is_empty(), TestFixtures.detail(bad, total, "map(s)"))


static func _case_lamps(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	var carriage: Array[int] = [BattlefieldArea.SURF_MAIN, BattlefieldArea.SURF_SIDE]
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		var lamps: int = 0
		for obs: Dictionary in _city_objects(map):
			if String(obs.get("city", "")) != "lamp":
				continue
			lamps += 1
			total += 1
			var pos: Vector3i = obs.get("pos", Vector3i.ZERO)
			var cell := Vector2i(pos.x, pos.y)
			if CityGrid.surf(map, cell.x, cell.y) != BattlefieldArea.SURF_SIDEWALK \
					or not _touches(map, cell, carriage):
				hits = _note(bad, hits, "s%d lamp %d,%d stands off the curb" % [s, cell.x, cell.y])
		var need: int = 2 * _mains(map)
		if lamps < need:
			hits = _note(bad, hits, "s%d holds %d lamp(s) of %d" % [s, lamps, need])
	TestFixtures.check(res, "citygen_lamps", bad.is_empty(), TestFixtures.detail(bad, total, "lamp(s)"))


static func _case_squares(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		var count: int = 0
		for obs: Dictionary in _city_objects(map):
			if String(obs.get("city", "")) != "square":
				continue
			count += 1
			total += 1
			hits = _square_check(map, obs, s, bad, hits)
		var mains: int = _mains(map)
		if count > mains:
			hits = _note(bad, hits, "s%d holds %d square(s) of %d main street(s)"
				% [s, count, mains])
	TestFixtures.check(res, "citygen_squares", bad.is_empty(),
		"%s; squares=%d" % [TestFixtures.detail(bad, total, "square(s)"), total])


static func _square_check(map: BattlefieldArea, obs: Dictionary, s: int, bad: Array[String],
		hits: int) -> int:
	var pos: Vector3i = obs.get("pos", Vector3i.ZERO)
	var pw: int = maxi(1, int(obs.get("pw", 1)))
	var ph: int = maxi(1, int(obs.get("ph", 1)))
	var block := Rect2i(pos.x - 1, pos.y - 1, pw + 2, ph + 2)
	var foot := Rect2i(pos.x, pos.y, pw, ph)
	var walk: bool = false
	for y: int in range(block.position.y, block.end.y):
		for x: int in range(block.position.x, block.end.x):
			if not map.in_bounds_xy(x, y):
				return _note(bad, hits, "s%d square %d,%d leaves the map" % [s, pos.x, pos.y])
			var c := Vector2i(x, y)
			if not foot.has_point(c):
				if map._obs_map.has(Vector3i(x, y, 0)) or map.building_id_at.has(c):
					return _note(bad, hits, "s%d square %d,%d is crowded at %d,%d"
						% [s, pos.x, pos.y, x, y])
			if not walk and _main_walk(map, c):
				walk = true
	if not walk:
		return _note(bad, hits, "s%d square %d,%d touches no main street walk" % [s, pos.x, pos.y])
	return hits


static func _main_walk(map: BattlefieldArea, cell: Vector2i) -> bool:
	var streets: Array = map.city.get("streets", [])
	for d: int in range(4):
		var n := Vector2i(cell.x + DX[d], cell.y + DY[d])
		if CityGrid.surf(map, n.x, n.y) != BattlefieldArea.SURF_SIDEWALK:
			continue
		var sid: int = CityGrid.street_id(map, n.x, n.y)
		if sid < 0 or sid >= streets.size():
			continue
		if String((streets[sid] as Dictionary).get("kind", "")) == "main":
			return true
	return false


static func _case_spawn_zones(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		total += 1
		var spawn: Dictionary = map.city.get("spawn", {})
		var access: Dictionary = map.city.get("access", {})
		var reach0: PackedByteArray = access.get("reach0", PackedByteArray())
		if int(spawn.get("side_b", -1)) != (int(spawn.get("side_a", -1)) ^ 1):
			hits = _note(bad, hits, "s%d spawn sides %d and %d"
				% [s, int(spawn.get("side_a", -1)), int(spawn.get("side_b", -1))])
		var centres: Array[Vector2i] = [map.spawn_center_a, map.spawn_center_b]
		var zones: Array[Dictionary] = [map.spawn_zone_a, map.spawn_zone_b]
		for t: int in range(2):
			var tag: String = "a" if t == 0 else "b"
			var centre: Vector2i = centres[t]
			var i: int = centre.y * map.width + centre.x
			if not CityAccess.is_ground(map, centre) or i < 0 or i >= reach0.size() \
					or reach0[i] != 1:
				hits = _note(bad, hits, "s%d centre %s %d,%d is off the open ground"
					% [s, tag, centre.x, centre.y])
			var outdoor: int = int(spawn.get("outdoor_" + tag, 0))
			if outdoor < MIN_OUTDOOR:
				hits = _note(bad, hits, "s%d zone %s holds %d outdoor cell(s)" % [s, tag, outdoor])
			var open: Dictionary = CitySpawns.outdoor_zone(map, t)
			if open.size() < outdoor:
				hits = _note(bad, hits, "s%d zone %s opens %d of %d cell(s)"
					% [s, tag, open.size(), outdoor])
			var kept: Array = spawn.get("buildings_" + tag, [])
			var now: Array[int] = CitySpawns.open_buildings(map, t)
			if kept.size() != now.size() or str(kept) != str(now):
				hits = _note(bad, hits, "s%d zone %s buildings %s of %s"
					% [s, tag, str(kept), str(now)])
		for obs: Dictionary in _city_objects(map):
			for c: Vector2i in _cells_of(obs):
				if zones[0].has(c) or zones[1].has(c):
					hits = _note(bad, hits, "s%d object %s at %d,%d sits in a spawn zone"
						% [s, _row_name(obs), c.x, c.y])
					break
	TestFixtures.check(res, "citygen_spawn_zones", bad.is_empty(), TestFixtures.detail(bad, total, "map(s)"))


static func _case_window_posts(res: Dictionary, maps: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var total: int = 0
	var with_post: int = 0
	for item: Dictionary in maps:
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var hits: int = 0
		total += 1
		var any: bool = false
		var spawn: Dictionary = map.city.get("spawn", {})
		for t: int in range(2):
			var tag: String = "a" if t == 0 else "b"
			var owners: Dictionary = {}
			for id: Variant in (spawn.get("buildings_" + tag, []) as Array):
				owners[int(id)] = true
			seed(RNG_SEED)
			var before: int = randi()
			seed(RNG_SEED)
			var posts: Array[Vector3i] = CitySpawns.window_posts(map, t)
			var after: int = randi()
			if before != after:
				hits = _note(bad, hits, "s%d team %d window posts roll the dice" % [s, t])
			if str(posts) != str(CitySpawns.window_posts(map, t)):
				hits = _note(bad, hits, "s%d team %d window posts differ between calls" % [s, t])
			if not posts.is_empty():
				any = true
			for p: Vector3i in posts:
				var cell := Vector2i(p.x, p.y)
				if p.z < 1 or not owners.has(int(map.building_id_at.get(cell, -1))) \
						or map.is_obstacle(cell, p.z):
					hits = _note(bad, hits, "s%d team %d post %d,%d,%d is no open window seat"
						% [s, t, p.x, p.y, p.z])
		if any:
			with_post += 1
	if with_post <= 0:
		bad.append("no map holds a window post")
	TestFixtures.check(res, "citygen_window_posts", bad.is_empty(),
		"%s; %d map(s) with a post" % [TestFixtures.detail(bad, total, "map(s)"), with_post])


static func _case_dump(res: Dictionary) -> void:
	var map: BattlefieldArea = CityGenTests.ref_map()
	if map == null:
		TestFixtures.check(res, "citygen_fill_dump", false, "no cached map")
		return
	var lines: PackedStringArray = GenFixtures.dump_lines(map, CityGenTests.SUB_DIR, DUMP_NAME)
	var seen: Dictionary = {"SPAWN A:": 0, "SPAWN B:": 0, "OBJECTS:": 0, "DOOR:": 0, "CITYOBJ:": 0,
		"LOTFAIL ": 0}
	var lanes: int = 0
	for line: String in lines:
		for key: Variant in seen.keys():
			if line.begins_with(String(key)):
				seen[key] = int(seen[key]) + 1
		if line.contains(" backdoor="):
			lanes += 1
	var bad: Array[String] = []
	_want(bad, "SPAWN A:", int(seen["SPAWN A:"]), 1)
	_want(bad, "SPAWN B:", int(seen["SPAWN B:"]), 1)
	_want(bad, "OBJECTS:", int(seen["OBJECTS:"]), 1)
	var access: Dictionary = map.city.get("access", {})
	_want(bad, "DOOR:", int(seen["DOOR:"]), (access.get("doors", []) as Array).size())
	_want(bad, "CITYOBJ:", int(seen["CITYOBJ:"]), _street_objects(map))
	_want(bad, "LOTFAIL ", int(seen["LOTFAIL "]), _failed_lots(map))
	_want(bad, "backdoor=", lanes, int((map.city.get("stats", {}) as Dictionary).get("back_lanes", -1)))
	var rows: int = GenFixtures.grid_rows(lines, OBJ_HEAD, map)
	if rows != map.length:
		bad.append("grid legend %s, %d of %d row(s)" % [str(rows >= 0), maxi(rows, 0), map.length])
	TestFixtures.check(res, "citygen_fill_dump", bad.is_empty(), TestFixtures.detail(bad, 8, "dump rule(s)"))


static func _want(bad: Array[String], label: String, got: int, want: int) -> void:
	if got != want:
		bad.append("%s %d of %d" % [label, got, want])


static func _case_spawn_battle(res: Dictionary) -> void:
	var fixture: Array[String] = []
	if not WeaponEvaluator.is_ranged_focused(TestFixtures.city_ranged("Probe R")):
		fixture.append("the ranged fixture is not ranged focused")
	if WeaponEvaluator.is_ranged_focused(TestFixtures.city_melee("Probe M")):
		fixture.append("the melee fixture counts as ranged focused")
	TestFixtures.check(res, "citygen_spawn_fixture", fixture.is_empty(),
		TestFixtures.detail(fixture, 2, "fixture(s)"))
	var picked: Array[BattlefieldArea] = []
	for i: int in range(BATTLE_MAPS):
		if picked.size() >= BATTLE_USE:
			break
		var map: BattlefieldArea = city_map("Medium", BATTLE_SEED + i)
		if CitySpawns.window_posts(map, 0).is_empty():
			continue
		picked.append(map)
	var foot: Array[String] = []
	var window: Array[String] = []
	var total: int = 0
	var on_post: int = 0
	for map2: BattlefieldArea in picked:
		var team_a: Array[MercenaryData] = [TestFixtures.city_ranged("A1"), TestFixtures.city_ranged("A2"),
			TestFixtures.city_melee("A3"), TestFixtures.city_melee("A4")]
		var team_b: Array[MercenaryData] = [TestFixtures.city_melee("B1"), TestFixtures.city_melee("B2"),
			TestFixtures.city_melee("B3"), TestFixtures.city_melee("B4")]
		var st: BattleState = BattleState.create(team_a, team_b, map2)
		var rosters: Array = [team_a, team_b]
		var taken: Dictionary = {}
		for t: int in range(2):
			var zone: Dictionary = CitySpawns.outdoor_zone(map2, t)
			var posts: Dictionary = {}
			for p: Vector3i in CitySpawns.window_posts(map2, t):
				posts[p] = true
			var roster: Array = rosters[t]
			for merc: MercenaryData in roster:
				total += 1
				var pos: Vector2i = st.get_position(merc)
				var fl: int = st.get_floor(merc)
				var key := Vector3i(pos.x, pos.y, fl)
				if taken.has(key):
					foot.append("%s shares cell %d,%d floor %d" % [merc.merc_name, pos.x, pos.y, fl])
				taken[key] = true
				var ranged: bool = WeaponEvaluator.is_ranged_focused(merc)
				if posts.has(key) and ranged:
					on_post += 1
					continue
				if fl != 0 or not zone.has(pos):
					if ranged and fl >= 1:
						window.append("%s stands at %d,%d floor %d off a post"
							% [merc.merc_name, pos.x, pos.y, fl])
					else:
						foot.append("%s stands at %d,%d floor %d off the zone"
							% [merc.merc_name, pos.x, pos.y, fl])
	TestFixtures.check(res, "citygen_spawn_on_foot", foot.is_empty() and not picked.is_empty(),
		"%s; %d map(s)" % [TestFixtures.detail(foot, total, "merc(s)"), picked.size()])
	if picked.is_empty():
		window.append("no Medium map of %d held a window post" % BATTLE_MAPS)
	elif on_post <= 0:
		window.append("no ranged merc took a window post")
	TestFixtures.check(res, "citygen_spawn_window", window.is_empty(),
		"%s; %d map(s), %d on a post" % [TestFixtures.detail(window, total, "merc(s)"), picked.size(), on_post])

