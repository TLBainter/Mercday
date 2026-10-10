class_name CityTests

#Building records on one map: stamping, floor planes per building, stair run lists, reach, LOS and site clamps.
#Run: godot --headless --path . -- --city-tests

const SEED := 9100
const GROUND := 4
#A cell of the open ground of the fixture map, inside the margin and outside every stamped footprint.
const OUTDOOR_CELL := Vector2i(1, 1)
const MANOR := 0
const TOWER := 1
const COBBLER := 2
const COBBLER_ROOF := 7
const TOWER_FH := 3
const SINGLE_SEED := 7100
const SITE_SEEDS := 40
const SITE_BUILD_BASE := 9200
const SITE_BUILD_SEEDS := 6
const SITE_CAP := 16
const DUMP_STEM := "user://city_test"


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var city: Dictionary = CityFixtures.city(SEED)
	_case_records(res, city)
	_case_ownership(res, city)
	_case_ground(res, city)
	_case_planes(res, city)
	_case_roofs(res, city)
	_case_roof_posts(res, city)
	_case_runs(res, city)
	_case_reach(res, city)
	FarCapTests.run_cases(res)
	_case_path(res, city)
	_case_stamp(res, city)
	_case_los(res, city)
	_case_under_ground(res)
	_case_dump(res, city)
	#Breaks a window, so it runs after every other case that reads the shared fixture.
	_case_drop(res, city)
	_case_single(res)
	_case_site(res)
	_case_site_build(res)
	_case_refuses(res)
	_case_determinism(res)
	CityGenTests.run_cases(res)
	CityFillTests.run_cases(res, CityGenTests.maps())
	CityBattleTests.run_cases(res)
	SpawnHarnessTests.run_cases(res)
	JumpTableTests.run_cases(res)
	SpeedEquivTests.run_cases(res)
	#Breaks the cached Small map on purpose, so it runs after every case that reads it.
	CityGenTests.run_break_case(res)
	randomize()
	return TestFixtures.summarize(res, "CITY")


static func _case_records(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var ids: Array[int] = city["ids"]
	var bad_ids: Array[String] = []
	for i: int in range(ids.size()):
		if ids[i] != i:
			bad_ids.append("%d got %d" % [i, ids[i]])
	TestFixtures.check(res, "three buildings stamp with the ids 0 to 2",
		bad_ids.is_empty() and map.buildings.size() == CityFixtures.SPECS.size(),
		"%d record(s); %s" % [map.buildings.size(), TestFixtures.detail(bad_ids, ids.size(), "id(s)")])
	var outside: Array[String] = []
	for rec: Dictionary in map.buildings:
		var r: Rect2i = rec["rect"]
		if r.position.x < 0 or r.position.y < 0 or r.end.x > map.width or r.end.y > map.length:
			outside.append("%d %s" % [int(rec["id"]), str(r)])
	TestFixtures.check(res, "every record rect lies inside the map", outside.is_empty(),
		TestFixtures.detail(outside, map.buildings.size(), "record(s)"))
	var close: Array[String] = []
	var pairs: int = 0
	for a: int in range(map.buildings.size()):
		for b: int in range(a + 1, map.buildings.size()):
			pairs += 1
			var ra: Rect2i = (map.buildings[a] as Dictionary)["rect"]
			var rb: Rect2i = (map.buildings[b] as Dictionary)["rect"]
			if ra.grow(1).intersects(rb.grow(1)):
				close.append("%d/%d %s %s" % [a, b, str(ra), str(rb)])
	TestFixtures.check(res, "two cells stay free between any two records", close.is_empty(),
		TestFixtures.detail(close, pairs, "pair(s)"))
	var issues: Array[String] = []
	for rec2: Dictionary in map.buildings:
		for text: Variant in (rec2["issues"] as Array):
			issues.append("%s %s" % [String(rec2["name"]), String(text)])
	TestFixtures.check(res, "no stamped building carries a validation issue", issues.is_empty(),
		TestFixtures.detail(issues, map.buildings.size(), "record(s)"))


static func _case_ownership(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var pre: Array[Dictionary] = city["pre"]
	var counts: Array[int] = []
	for _i: int in range(pre.size()):
		counts.append(0)
	for ck: Variant in map.building_id_at.keys():
		var bid: int = int(map.building_id_at[ck])
		if bid >= 0 and bid < counts.size():
			counts[bid] = counts[bid] + 1
	var bad: Array[String] = []
	for i: int in range(pre.size()):
		var want: int = int(pre[i]["cells"])
		if counts[i] != want:
			bad.append("%d got %d want %d" % [i, counts[i], want])
	TestFixtures.check(res, "every building owns the cells its scratch map used", bad.is_empty(),
		TestFixtures.detail(bad, pre.size(), "building(s)"))
	var corner: int = map.building_at(Vector2i(0, 0))
	TestFixtures.check(res, "the map corner has no owner", corner == -1, "owner %d" % corner)
	var orphan: int = 0
	for fk: Variant in map.footprint_cells.keys():
		var c: Vector3i = fk as Vector3i
		if not map.building_id_at.has(Vector2i(c.x, c.y)):
			orphan += 1
	TestFixtures.check(res, "every footprint cell names an owner", orphan == 0,
		"%d of %d cell(s)" % [orphan, map.footprint_cells.size()])


static func _case_ground(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var base: float = map.floor_base_elevation(0)
	TestFixtures.check(res, "the ground plane sits at %d" % GROUND, is_equal_approx(base, float(GROUND)),
		"floor 0 at %.1f" % base)
	TestFixtures.check(res, "outdoor_planes carries the ground plane alone",
		map.outdoor_planes.size() == 1 and int(map.outdoor_planes.get(0, -1)) == GROUND,
		str(map.outdoor_planes))
	var street: Vector2i = OUTDOOR_CELL
	var bad: Array[String] = []
	var street_e: float = map.floor_elevation_at(street, 0)
	if not is_equal_approx(street_e, float(GROUND)):
		bad.append("street %.1f" % street_e)
	for i: int in range(map.buildings.size()):
		var c: Vector3i = _foot_cell(map, i, 0)
		if c.x < 0:
			bad.append("%d no floor 0 cell" % i)
			continue
		var e: float = map.floor_elevation_at(Vector2i(c.x, c.y), 0)
		if not is_equal_approx(e, float(GROUND)):
			bad.append("%d %.1f" % [i, e])
	TestFixtures.check(res, "floor 0 of every building meets the ground plane", bad.is_empty(),
		TestFixtures.detail(bad, map.buildings.size() + 1, "cell(s)"))
	var foot: Vector3i = _foot_cell(map, MANOR, 0)
	var walk_out: float = map.walk_elevation(street, 0)
	var walk_in: float = map.walk_elevation(Vector2i(foot.x, foot.y), 0)
	TestFixtures.check(res, "a street cell and a floor 0 cell stand at the same height",
		is_equal_approx(walk_out, 0.0) and is_equal_approx(walk_in, 0.0),
		"street %.1f, indoors %.1f" % [walk_out, walk_in])


static func _case_planes(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var bad: Array[String] = []
	var checked: int = 0
	for rec: Dictionary in map.buildings:
		var id: int = int(rec["id"])
		var fh: int = int(rec["fh"])
		var planes: Dictionary = map.building_planes[id]
		for fv: Variant in (rec["floors"] as Array):
			var f: int = fv as int
			checked += 1
			var want: int = GROUND + f * fh
			if int(planes.get(f, -9999)) != want:
				bad.append("%d f%d plane %s want %d" % [id, f, str(planes.get(f, "-")), want])
				continue
			var c: Vector3i = _foot_cell(map, id, f)
			if c.x < 0:
				bad.append("%d f%d no cell" % [id, f])
				continue
			var e: float = map.floor_elevation_at(Vector2i(c.x, c.y), f)
			if not is_equal_approx(e, float(want)):
				bad.append("%d f%d cell %.1f want %d" % [id, f, e, want])
	TestFixtures.check(res, "each building keeps planes of its own floor height", bad.is_empty(),
		TestFixtures.detail(bad, checked, "floor(s)"))
	var manor: Dictionary = map.buildings[MANOR]
	var manor_planes: Dictionary = map.building_planes[MANOR]
	TestFixtures.check(res, "the manor basement sits at 0",
		int(manor["fh"]) == 4 and int(manor_planes.get(-1, -9999)) == 0,
		"fh %d, floor -1 at %s" % [int(manor["fh"]), str(manor_planes.get(-1, "-"))])
	var tower: Dictionary = map.buildings[TOWER]
	var tower_planes: Dictionary = map.building_planes[TOWER]
	TestFixtures.check(res, "the watchtower floor 2 sits at 10",
		int(tower["fh"]) == TOWER_FH and int(tower_planes.get(2, -9999)) == 10,
		"fh %d, floor 2 at %s" % [int(tower["fh"]), str(tower_planes.get(2, "-"))])
	var street_planes: Dictionary = map.floor_planes_at(OUTDOOR_CELL)
	TestFixtures.check(res, "a street cell carries the ground plane alone",
		street_planes.size() == 1 and street_planes.has(0), str(street_planes))


static func _case_roofs(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var bad: Array[String] = []
	var cells: int = 0
	for ck: Variant in map.footprint_cells.keys():
		var c: Vector3i = ck as Vector3i
		var xy := Vector2i(c.x, c.y)
		if map.building_at(xy) != COBBLER:
			continue
		cells += 1
		if int(map.roof_elevations.get(xy, -1)) != COBBLER_ROOF:
			bad.append("%s %s" % [str(xy), str(map.roof_elevations.get(xy, "-"))])
	TestFixtures.check(res, "the cobbler roof sits at %d" % COBBLER_ROOF, bad.is_empty() and cells > 0,
		TestFixtures.detail(bad, cells, "cobbler cell(s)"))
	var street: Vector2i = OUTDOOR_CELL
	TestFixtures.check(res, "no street cell carries a roof", not map.roof_elevations.has(street),
		"%s roof %s" % [str(street), str(map.roof_elevations.get(street, "-"))])
	var tower: Dictionary = map.buildings[TOWER]
	var fp: int = int(tower["fp"])
	var top: Vector3i = _foot_cell(map, TOWER, fp)
	var want: int = GROUND + (fp + 1) * TOWER_FH
	var got: int = int(map.roof_elevations.get(Vector2i(top.x, top.y), -1))
	TestFixtures.check(res, "the watchtower roof sits one floor above its top floor", got == want,
		"got %d want %d over %s" % [got, want, str(top)])


#Roof spawn posts over one building of the zone, ordered and never on a roof object.
static func _case_roof_posts(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var rect: Rect2i = (map.buildings[COBBLER] as Dictionary).get("rect", Rect2i())
	var zone_keep: Dictionary = map.spawn_zone_a.duplicate()
	var centre_keep: Vector2i = map.spawn_center_b
	map.spawn_zone_a = {}
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			map.spawn_zone_a[Vector2i(x, y)] = true
	map.spawn_center_b = Vector2i(map.width - 1, map.length - 1)
	var posts: Array[Vector3i] = CitySpawns.roof_posts(map, 0)
	var bad: Array[String] = []
	var last: int = 1 << 30
	for post: Vector3i in posts:
		if post.z > last:
			bad.append("%s out of order" % str(post))
		last = post.z
		if not map.is_roof_footing(Vector2i(post.x, post.y), post.z):
			bad.append("%s no footing" % str(post))
		elif not map.get_obs(Vector2i(post.x, post.y), post.z).is_empty():
			bad.append("%s occupied" % str(post))
		elif map.building_at(Vector2i(post.x, post.y)) != COBBLER:
			bad.append("%s off the building" % str(post))
	TestFixtures.check(res, "city_roofpost every roof post is an open footing of the zone building",
		not posts.is_empty() and bad.is_empty(), TestFixtures.detail(bad, posts.size(), "post(s)"))
	map.spawn_zone_a = zone_keep
	map.spawn_center_b = centre_keep


static func _case_runs(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var pre: Array[Dictionary] = city["pre"]
	var want_runs: int = 0
	for entry: Dictionary in pre:
		want_runs += int(entry["runs"])
	var total: int = 0
	for fk: Variant in map.stair_runs.keys():
		total += (map.stair_runs[fk] as Array).size()
	TestFixtures.check(res, "every scratch stair run reaches the map", total == want_runs,
		"%d run(s) for %d expected" % [total, want_runs])
	var on_one: int = (map.stair_runs.get(1, []) as Array).size()
	TestFixtures.check(res, "floor 1 holds a run for the manor and the watchtower", on_one >= 2,
		"%d run(s) on floor 1" % on_one)
	var bad_lookup: Array[String] = []
	var bad_elev: Array[String] = []
	var seen: int = 0
	for rk: Variant in map.stair_runs.keys():
		var f: int = rk as int
		for item: Variant in (map.stair_runs[f] as Array):
			var stair_run: Dictionary = item as Dictionary
			seen += 1
			var sx: int = int(stair_run["sx"])
			for y: int in [int(stair_run["uy"]), int(stair_run["ly"])]:
				var got: Dictionary = map.stair_run_at(Vector2i(sx, y), f)
				if got.is_empty() or int(got["sx"]) != sx or int(got["ly"]) != int(stair_run["ly"]) \
						or int(got["uy"]) != int(stair_run["uy"]):
					bad_lookup.append("f%d %d,%d" % [f, sx, y])
			var top := Vector2i(sx, BattlefieldArea.run_top_y(stair_run))
			var bottom := Vector2i(sx, BattlefieldArea.run_bottom_y(stair_run))
			var want_top: float = map.floor_elevation_at(top, f)
			var want_bottom: float = map.floor_elevation_at(bottom, f - 1)
			var got_top: float = map.cell_base_elevation(top, f)
			var got_bottom: float = map.cell_base_elevation(bottom, f)
			if not is_equal_approx(got_top, want_top) or not is_equal_approx(got_bottom, want_bottom):
				bad_elev.append("f%d %.1f/%.1f want %.1f/%.1f" % [f, got_top, got_bottom,
					want_top, want_bottom])
	TestFixtures.check(res, "stair_run_at finds the run under each of its ends", bad_lookup.is_empty(),
		TestFixtures.detail(bad_lookup, seen * 2, "run end(s)"))
	TestFixtures.check(res, "a run meets the plane of its floor and of the one below", bad_elev.is_empty(),
		TestFixtures.detail(bad_elev, seen, "run(s)"))


static func _case_reach(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var no_start: Array[String] = []
	var cut_off: Array[String] = []
	for rec: Dictionary in map.buildings:
		var id: int = int(rec["id"])
		var door: Vector3i = rec["front_door"]
		if door.x < 0:
			no_start.append("%d %s" % [id, String(rec["name"])])
			continue
		var start: Vector3i = door + BuildingLayouts.inward(String(rec["front"]))
		var owned: Array[Vector3i] = []
		for ck: Variant in map.footprint_cells.keys():
			var c: Vector3i = ck as Vector3i
			if map.building_at(Vector2i(c.x, c.y)) == id:
				owned.append(c)
		var orphans: int = GenFixtures.orphan_count(map, start, owned)
		if orphans > 0:
			cut_off.append("%d %d of %d cell(s)" % [id, orphans, owned.size()])
	TestFixtures.check(res, "every stamped building keeps its front door", no_start.is_empty(),
		TestFixtures.detail(no_start, map.buildings.size(), "building(s)"))
	TestFixtures.check(res, "every open footprint cell reaches its own entrance", cut_off.is_empty(),
		TestFixtures.detail(cut_off, map.buildings.size(), "building(s)"))


static func _case_path(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	#Doors generate shut; the default penalty of -1 plans no route through a shut door.
	PathCost.set_door_penalty(0)
	var manor: Dictionary = map.buildings[MANOR]
	var tower: Dictionary = map.buildings[TOWER]
	var door: Vector3i = manor["front_door"]
	var target: Vector3i = _free_cell(map, TOWER, int(tower["fp"]))
	var ok: bool = false
	var detail: String = "manor door %s, watchtower cell %s" % [str(door), str(target)]
	if door.x >= 0 and target.x >= 0:
		var from: Vector3i = door - BuildingLayouts.inward(String(manor["front"]))
		var path: Array[Vector3i] = Pathfinder.find_path(from, target, map)
		ok = not path.is_empty()
		detail = "%s to %s, %d step(s)" % [str(from), str(target), path.size()]
	PathCost.set_door_penalty(-1)
	TestFixtures.check(res, "a merc walks from the manor door to the watchtower top floor", ok, detail)


static func _case_stamp(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var pre: Array[Dictionary] = city["pre"]
	var want_obs: int = 0
	var want_map: int = 0
	for entry: Dictionary in pre:
		want_obs += int(entry["obs"])
		want_map += int(entry["omap"])
	TestFixtures.check(res, "every scratch obstacle reaches the map", map.obstacles.size() == want_obs,
		"%d of %d obstacle(s)" % [map.obstacles.size(), want_obs])
	TestFixtures.check(res, "the obstacle map keeps every scratch entry", map._obs_map.size() == want_map,
		"%d of %d entry(s)" % [map._obs_map.size(), want_map])
	var loose: Array[String] = []
	for obs: Dictionary in map.obstacles:
		if not is_same(map._obs_map.get(obs["pos"]), obs):
			loose.append(str(obs["pos"]))
	TestFixtures.check(res, "every obstacle sits under its own shifted map key", loose.is_empty(),
		TestFixtures.detail(loose, map.obstacles.size(), "obstacle(s)"))
	var bad: Array[String] = []
	for room: Dictionary in map.interior_rooms:
		if not room.has("building"):
			bad.append("%s has no building" % String(room.get("name", "?")))
			continue
		var bid: int = int(room["building"])
		if bid < 0 or bid >= map.buildings.size():
			bad.append("%s building %d" % [String(room.get("name", "?")), bid])
			continue
		var rect: Rect2i = room.get("rect", Rect2i())
		var owner_rect: Rect2i = (map.buildings[bid] as Dictionary)["rect"]
		if not owner_rect.encloses(rect):
			bad.append("%s %s outside %s" % [String(room.get("name", "?")), str(rect), str(owner_rect)])
	TestFixtures.check(res, "every room names its building and fits inside it", bad.is_empty(),
		TestFixtures.detail(bad, map.interior_rooms.size(), "room(s)"))


static func _case_los(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var west := Vector3i(1, 1, 0)
	var east := Vector3i(map.width - 2, 1, 0)
	var along: Dictionary = LineOfSight._compute(map, west, 0, 1, east, 0, 1)
	TestFixtures.check(res, "two street cells see each other", bool(along.get("visible", false)),
		"%s to %s, blocker %s" % [str(west), str(east), String(along.get("blocker", ""))])
	var cellar: Vector3i = _free_cell(map, MANOR, -1)
	var down: Dictionary = {}
	if cellar.x >= 0:
		down = LineOfSight._compute(map, cellar, 0, 1, west, 0, 1)
	TestFixtures.check(res, "a manor cellar cell sees no street cell",
		cellar.x >= 0 and not bool(down.get("visible", false)),
		"%s, blocker %s" % [str(cellar), String(down.get("blocker", "none"))])
	var tower: Dictionary = map.buildings[TOWER]
	var perch: Vector3i = _free_cell(map, TOWER, int(tower["fp"]))
	var shop: Vector3i = _free_cell(map, COBBLER, 0)
	var across: Dictionary = {}
	if perch.x >= 0 and shop.x >= 0:
		across = LineOfSight._compute(map, perch, 0, 1, shop, 0, 1)
	TestFixtures.check(res, "a watchtower top cell sees no cell inside the cobbler",
		perch.x >= 0 and shop.x >= 0 and not bool(across.get("visible", false)),
		"%s to %s, blocker %s" % [str(perch), str(shop), String(across.get("blocker", "none"))])
	var roof_block: String = LineOfSight._floor_block(map, Vector2i(shop.x, shop.y), 9.0, 5.0, 0)
	TestFixtures.check(res, "a ray down through the cobbler roof reports it",
		roof_block.begins_with("roof"), "got '%s' over %s" % [roof_block, str(shop)])
	var street: Vector2i = OUTDOOR_CELL
	var free_block: String = LineOfSight._floor_block(map, street, 9.0, 5.0, 0)
	TestFixtures.check(res, "a ray down over the street crosses no plane", free_block == "",
		"got '%s'" % free_block)
	var tower_cell: Vector3i = _foot_cell(map, TOWER, 2)
	var manor_cell: Vector3i = _foot_cell(map, MANOR, 1)
	var street_f: int = LineOfSight._floor_at_cell(map, street, 20.0)
	var tower_f: int = LineOfSight._floor_at_cell(map, Vector2i(tower_cell.x, tower_cell.y), 10.5)
	var manor_f: int = LineOfSight._floor_at_cell(map, Vector2i(manor_cell.x, manor_cell.y), 10.5)
	TestFixtures.check(res, "each cell reads its own floor at one height",
		street_f == 0 and tower_f == 2 and manor_f == 1,
		"street %d, watchtower %d, manor %d" % [street_f, tower_f, manor_f])


#One hand-built building: a cellar in two halves with earth between them under its own floor 0.
static func _case_under_ground(res: Dictionary) -> void:
	var f := BattlefieldArea.new()
	f.width = 12
	f.length = 12
	f.height = 24
	f.is_interior_map = true
	f.interior_floor_elevations = {-1: 1, 0: GROUND}
	f.outdoor_planes = {0: GROUND}
	f.buildings.append({"id": 0})
	f.building_planes.append({-1: 0, 0: GROUND})
	for x: int in range(2, 9):
		f.building_id_at[Vector2i(x, 5)] = 0
		f.footprint_cells[Vector3i(x, 5, 0)] = true
		if x != 5:
			f.footprint_cells[Vector3i(x, 5, -1)] = true
	f.set_footprint_from_cells()
	var west := Vector3i(2, 5, -1)
	var east := Vector3i(8, 5, -1)
	var split: Dictionary = LineOfSight._compute(f, west, 0, 1, east, 0, 1)
	TestFixtures.check(res, "earth between two cellar halves stops the ray",
		not bool(split.get("visible", true)) and String(split.get("blocker", "")).begins_with("ground"),
		"blocker '%s'" % String(split.get("blocker", "")))
	f.footprint_cells[Vector3i(5, 5, -1)] = true
	var joined: Dictionary = LineOfSight._compute(f, west, 0, 1, east, 0, 1)
	TestFixtures.check(res, "one joined cellar lets the ray through", bool(joined.get("visible", false)),
		"blocker '%s'" % String(joined.get("blocker", "")))
	var over: Dictionary = LineOfSight._compute(f, Vector3i(2, 5, 0), 0, 1, Vector3i(8, 5, 0), 0, 1)
	TestFixtures.check(res, "floor 0 over the cellar keeps its own sight line", bool(over.get("visible", false)),
		"blocker '%s'" % String(over.get("blocker", "")))


static func _case_dump(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	LevelDumpWriter.save(map, DUMP_STEM)
	var text: String = FileAccess.get_file_as_string(DUMP_STEM + "_level.txt")
	var records: int = 0
	var stairs: int = 0
	for line: String in text.split("\n"):
		if line.begins_with("BUILDING: id="):
			records += 1
		elif line.begins_with("STAIRS:"):
			stairs += 1
	var want_runs: int = 0
	for fk: Variant in map.stair_runs.keys():
		want_runs += (map.stair_runs[fk] as Array).size()
	var header: bool = text.contains("BUILDINGS: %d" % map.buildings.size())
	TestFixtures.check(res, "the dump names every stamped building",
		header and records == map.buildings.size(),
		"header %s, %d of %d line(s)" % [str(header), records, map.buildings.size()])
	TestFixtures.check(res, "the dump writes one line per stair run", stairs == want_runs,
		"%d of %d line(s)" % [stairs, want_runs])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DUMP_STEM + "_level.txt"))


static func _case_drop(res: Dictionary, city: Dictionary) -> void:
	var map: BattlefieldArea = city["map"]
	var best := Vector3i(-1, -1, 0)
	for wk: Variant in map._obs_map.keys():
		if typeof(wk) != TYPE_VECTOR3I:
			continue
		var c: Vector3i = wk as Vector3i
		if c.z < 1 or map.building_at(Vector2i(c.x, c.y)) != TOWER:
			continue
		var obs: Dictionary = map._obs_map[wk] as Dictionary
		if String(obs.get("cell_type", "")) != "window" or bool(obs.get("broken", false)):
			continue
		if best.x < 0 or _before(c, best):
			best = c
	if best.x < 0:
		TestFixtures.check(res, "an upper watchtower window breaks", false, "no upper window found")
		return
	TestFixtures.check(res, "an upper watchtower window breaks",
		map.break_window(Vector2i(best.x, best.y), best.z), str(best))
	var sources: int = 0
	var links: int = 0
	var bad: Array[String] = []
	for dk: Variant in map.drop_links.keys():
		var from: Vector3i = dk as Vector3i
		if from.z == best.z:
			sources += 1
		var from2 := Vector2i(from.x, from.y)
		var from_e: float = map.cell_base_elevation(from2, from.z) \
				if map.is_roof_footing(from2, from.z) else map.floor_elevation_at(from2, from.z)
		for item: Variant in (map.drop_links[dk] as Array):
			var link: Dictionary = item as Dictionary
			links += 1
			var to: Vector3i = link["to"] as Vector3i
			var want: int = int(floor(from_e - map.cell_base_elevation(Vector2i(to.x, to.y), to.z)))
			var paces: int = int(link["paces"])
			if paces != want or paces <= 0:
				bad.append("%s %d want %d" % [str(from), paces, want])
	TestFixtures.check(res, "the broken window opens a drop on its own floor", sources > 0,
		"%d source(s) on floor %d" % [sources, best.z])
	TestFixtures.check(res, "every drop counts paces from the plane it starts on", bad.is_empty(),
		TestFixtures.detail(bad, links, "link(s)"))


static func _case_single(res: Dictionary) -> void:
	var f: BattlefieldArea = GenFixtures.building_field("Inn", "W", SINGLE_SEED)
	TestFixtures.check(res, "a single building map keeps no building record but roofs its cells",
		f.buildings.is_empty() and f.building_id_at.is_empty() and f.building_planes.is_empty()
		and not f.roof_elevations.is_empty(),
		"%d record(s), %d owned cell(s), %d plane set(s), %d roofed cell(s)" % [f.buildings.size(),
			f.building_id_at.size(), f.building_planes.size(), f.roof_elevations.size()])
	var centre: Vector2i = f.building_footprint.position + Vector2i(f.building_footprint.size.x >> 1,
		f.building_footprint.size.y >> 1)
	var bad: Array[String] = []
	var checked: int = 0
	for fk: Variant in f.interior_floor_elevations.keys():
		var fl: int = fk as int
		for cell: Vector2i in [Vector2i(0, 0), centre]:
			checked += 1
			if not is_equal_approx(f.floor_elevation_at(cell, fl), f.floor_base_elevation(fl)):
				bad.append("f%d %s %.1f" % [fl, str(cell), f.floor_elevation_at(cell, fl)])
			if not is_same(f.floor_planes_at(cell), f.interior_floor_elevations):
				bad.append("f%d %s reads another table" % [fl, str(cell)])
	TestFixtures.check(res, "every cell reads the map floor table", bad.is_empty(),
		TestFixtures.detail(bad, checked, "cell(s)"))
	var bad_runs: Array[String] = []
	for rk: Variant in f.stair_runs.keys():
		var runs: Array = f.stair_runs[rk] as Array
		if runs.size() != 1:
			bad_runs.append("f%d %d run(s)" % [rk as int, runs.size()])
	TestFixtures.check(res, "each floor of one building holds one run", bad_runs.is_empty(),
		TestFixtures.detail(bad_runs, f.stair_runs.size(), "floor(s)"))


static func _case_site(res: Dictionary) -> void:
	var data: Dictionary = DataManager.get_area_by_name("Manor")
	var drift: Array[String] = []
	var extra: Array[String] = []
	var bad: Array[String] = []
	for s: int in range(SITE_SEEDS):
		seed(s)
		var plain: Dictionary = BuildingRules.roll_plan(data, "W", 0)
		var ra: int = randi()
		seed(s)
		var empty: Dictionary = BuildingRules.roll_plan(data, "W", 0, {})
		var rb: int = randi()
		if str(plain) != str(empty) or ra != rb:
			drift.append("s%d" % s)
		if plain.has("no_ext_rooms"):
			extra.append("s%d" % s)
		seed(s)
		var sized: Dictionary = BuildingRules.roll_plan(data, "W", 0,
			{"max_w": 14, "max_d": 16, "no_wings": true, "no_ext_rooms": true})
		if int(sized["floor_w"]) > 14 or int(sized["floor_d"]) > 16 or int(sized["wing_count"]) != 0 \
				or not bool(sized.get("no_ext_rooms", false)):
			bad.append("s%d %dx%d wings=%d ext=%s" % [s, int(sized["floor_w"]), int(sized["floor_d"]),
				int(sized["wing_count"]), str(sized.get("no_ext_rooms", false))])
	TestFixtures.check(res, "an empty site rolls the plan the old call rolls", drift.is_empty(),
		TestFixtures.detail(drift, SITE_SEEDS, "seed(s)"))
	TestFixtures.check(res, "an empty site adds no site key", extra.is_empty(),
		TestFixtures.detail(extra, SITE_SEEDS, "seed(s)"))
	TestFixtures.check(res, "a site clamps width, depth, wings and exterior rooms", bad.is_empty(),
		TestFixtures.detail(bad, SITE_SEEDS, "seed(s)"))


static func _case_site_build(res: Dictionary) -> void:
	var data: Dictionary = DataManager.get_area_by_name("Manor")
	var big: Array[String] = []
	var issues: int = 0
	for s: int in range(SITE_BUILD_BASE, SITE_BUILD_BASE + SITE_BUILD_SEEDS):
		seed(s)
		var scratch: BattlefieldArea = BuildingStamp.build_scratch(data, "S", 0,
			{"max_w": 14, "max_d": 14, "no_wings": true, "no_ext_rooms": true})
		if scratch == null:
			big.append("s%d built nothing" % s)
			continue
		var size: Vector2i = BuildingStamp.used_rect(scratch).size
		if size.x > SITE_CAP or size.y > SITE_CAP:
			big.append("s%d %dx%d" % [s, size.x, size.y])
		if not (scratch.building_plan.get("issues", []) as Array).is_empty():
			issues += 1
	TestFixtures.check(res, "a clamped lot builds inside %d by %d cells" % [SITE_CAP, SITE_CAP],
		big.is_empty(),
		"%s; %d map(s) with issues" % [TestFixtures.detail(big, SITE_BUILD_SEEDS, "seed(s)"), issues])


static func _case_refuses(res: Dictionary) -> void:
	var city: Dictionary = CityFixtures.city(SEED + 1)
	var map: BattlefieldArea = city["map"]
	var scratch: BattlefieldArea = BuildingStamp.build_scratch(
		DataManager.get_area_by_name("Cobbler"), "N", 0)
	var records: int = map.buildings.size()
	var obs: int = map.obstacles.size()
	var omap: int = map._obs_map.size()
	var owned: int = map.building_id_at.size()
	var taken: Rect2i = (map.buildings[0] as Dictionary)["rect"]
	var over: int = BuildingStamp.place(map, scratch, BuildingStamp.offset_for(scratch, taken.position))
	var off: int = BuildingStamp.place(map, scratch, Vector2i(-50, -50))
	TestFixtures.check(res, "a stamp over another building is refused", over == -1, "got %d" % over)
	TestFixtures.check(res, "a stamp off the map is refused", off == -1, "got %d" % off)
	TestFixtures.check(res, "a refused stamp writes nothing",
		map.buildings.size() == records and map.obstacles.size() == obs
		and map._obs_map.size() == omap and map.building_id_at.size() == owned,
		"%d/%d record(s), %d/%d obstacle(s), %d/%d entry(s), %d/%d owned" % [map.buildings.size(),
			records, map.obstacles.size(), obs, map._obs_map.size(), omap,
			map.building_id_at.size(), owned])


static func _case_determinism(res: Dictionary) -> void:
	var first: Dictionary = CityFixtures.city(SEED)
	var second: Dictionary = CityFixtures.city(SEED)
	var a: BattlefieldArea = first["map"]
	var b: BattlefieldArea = second["map"]
	var bad: Array[String] = []
	for i: int in range(mini(a.buildings.size(), b.buildings.size())):
		var ra: Rect2i = (a.buildings[i] as Dictionary)["rect"]
		var rb: Rect2i = (b.buildings[i] as Dictionary)["rect"]
		if ra != rb:
			bad.append("%d %s/%s" % [i, str(ra), str(rb)])
	TestFixtures.check(res, "one seed stamps the same rects twice",
		a.buildings.size() == b.buildings.size() and bad.is_empty(),
		TestFixtures.detail(bad, a.buildings.size(), "record(s)"))
	var ha: int = _obs_hash(a)
	var hb: int = _obs_hash(b)
	TestFixtures.check(res, "one seed stamps the same obstacles twice", ha == hb, "%d/%d" % [ha, hb])
	b.reset_generated_state()
	TestFixtures.check(res, "reset empties every city table",
		b.buildings.is_empty() and b.building_planes.is_empty() and b.building_id_at.is_empty()
		and b.outdoor_planes.is_empty() and b.roof_elevations.is_empty(),
		"%d/%d/%d/%d/%d left" % [b.buildings.size(), b.building_planes.size(), b.building_id_at.size(),
			b.outdoor_planes.size(), b.roof_elevations.size()])


#First footprint cell of floor f owned by building id, scanning x then y over its record rect.
static func _foot_cell(map: BattlefieldArea, id: int, f: int) -> Vector3i:
	if id < 0 or id >= map.buildings.size():
		return Vector3i(-1, -1, 0)
	var rect: Rect2i = (map.buildings[id] as Dictionary)["rect"]
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			if map.footprint_cells.has(Vector3i(x, y, f)) and map.building_at(Vector2i(x, y)) == id:
				return Vector3i(x, y, f)
	return Vector3i(-1, -1, 0)


#First open interior cell of floor f owned by building id: no obstacle, no stair run, inside the mask.
static func _free_cell(map: BattlefieldArea, id: int, f: int) -> Vector3i:
	if id < 0 or id >= map.buildings.size():
		return Vector3i(-1, -1, 0)
	var rect: Rect2i = (map.buildings[id] as Dictionary)["rect"]
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			var c := Vector3i(x, y, f)
			if not map.building_interiors.has(c) or not map.footprint_cells.has(c):
				continue
			if map.building_at(Vector2i(x, y)) != id or map.stair_run_cells.has(c):
				continue
			if map._obs_map.has(c) or not map.get_obs(Vector2i(x, y), f).is_empty():
				continue
			return c
	return Vector3i(-1, -1, 0)


static func _before(a: Vector3i, b: Vector3i) -> bool:
	if a.z != b.z:
		return a.z < b.z
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


static func _obs_hash(map: BattlefieldArea) -> int:
	var parts: Array[String] = []
	for obs: Dictionary in map.obstacles:
		var data: ObstacleData = obs.get("data") as ObstacleData
		parts.append("%s|%s|%s;" % [str(obs["pos"]),
			data.obstacle_name if data != null else "-", str(obs.get("cell_type", ""))])
	return "".join(parts).hash()
