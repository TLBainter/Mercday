class_name BuildingTests

#Planned buildings: the rolled plan, the shell, doors, reach, rooms, windows, furniture and spawns.
#Run: godot --headless --path . -- --building-tests

const SEEDS := 6
const SEED_BASE := 7100
const FRONTS: Array[String] = ["N", "S", "E", "W"]
const TAVERN := "Tavern"
const TAVERN_SEED_BASE := 9001
const TAVERN_SEEDS := 6
const DRAWS := 300
const ROWS := 26
const ROOM_ROWS := 87
const GATE_TRIES := 12
const GATE_DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0)]


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var fields: Array[Dictionary] = _all_fields()
	_case_data(res)
	_case_plan(res, fields)
	_case_validate(res, fields)
	_case_front_door(res, fields)
	_case_reach(res, fields)
	_case_movement(res, fields)
	_case_main_room(res, fields)
	_case_required(res, fields)
	_case_layout(res, fields)
	_case_windows(res, fields)
	_case_furniture(res, fields)
	_case_sizes(res, fields)
	_case_tavern(res)
	_case_spawns(res, fields)
	_case_patio_gate(res, fields)
	_print_summary(fields)
	randomize()
	return TestFixtures.summarize(res, "BUILDING")


static func _field(area_name: String, front: String, seed_i: int) -> BattlefieldArea:
	seed(seed_i)
	var ctx := GenerationContext.new()
	ctx.building_front = front
	return BattlefieldArea.generate_random(null, ctx, "Interior", DataManager.get_area_by_name(area_name))


#Every Buildings.tsv row that carries a layout, in sheet order.
static func _planned_names() -> Array[String]:
	var out: Array[String] = []
	for entry: String in DataManager.get_building_names():
		if not BuildingRules.is_legacy(DataManager.get_area_by_name(entry)):
			out.append(entry)
	return out


static func _all_fields() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for area_name: String in _planned_names():
		for front: String in FRONTS:
			for s: int in range(SEEDS):
				var t0: int = Time.get_ticks_msec()
				var field: BattlefieldArea = _field(area_name, front, SEED_BASE + s)
				out.append({"name": area_name, "front": front, "seed": SEED_BASE + s, "si": s,
					"field": field, "ms": Time.get_ticks_msec() - t0})
	return out


static func _tag(e: Dictionary) -> String:
	return "%s %s s%d" % [String(e["name"]), String(e["front"]), int(e["seed"])]


static func _case_data(res: Dictionary) -> void:
	var rows: int = 0
	for area: Dictionary in DataManager.areas_pool:
		if area.has("building"):
			rows += 1
	var names: Array[String] = DataManager.get_building_names()
	var planned: Array[String] = _planned_names()
	TestFixtures.check(res, "Buildings.tsv carries %d rows" % ROWS, rows == ROWS, "%d row(s)" % rows)
	TestFixtures.check(res, "get_building_names lists every row", names.size() == rows,
		"%d name(s) for %d row(s)" % [names.size(), rows])
	var legacy_tavern: bool = BuildingRules.is_legacy(DataManager.get_area_by_name(TAVERN))
	TestFixtures.check(res, "%d rows are planned and the tavern is legacy" % (ROWS - 1),
		planned.size() == ROWS - 1 and legacy_tavern,
		"%d planned, tavern legacy %s" % [planned.size(), str(legacy_tavern)])
	var bad: Array[String] = []
	for area_name: String in names:
		var b: Dictionary = DataManager.get_area_by_name(area_name).get("building", {})
		var wanted: Array[String] = []
		if String(b.get("main_room", "")) != "":
			wanted.append(String(b.get("main_room", "")))
		for entry: Variant in (b.get("required_rooms", []) as Array):
			wanted.append(String(entry))
		for entry2: Variant in (b.get("other_rooms", []) as Array):
			wanted.append(String(entry2))
		for room_name: String in wanted:
			var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
			if d == null or not d.is_room:
				bad.append("%s/%s" % [area_name, room_name])
	TestFixtures.check(res, "every room name in every row resolves", bad.is_empty(),
		TestFixtures.detail(bad, names.size(), "row name(s)"))
	var room_rows: int = DataManager.room_sheet_rows.size()
	TestFixtures.check(res, "Rooms.tsv carries %d rooms" % ROOM_ROWS, room_rows == ROOM_ROWS,
		"%d room(s)" % room_rows)
	seed(SEED_BASE)
	var small_hits: int = 0
	var tavern_hits: int = 0
	for _i: int in range(DRAWS):
		var drawn: Dictionary = DataManager.get_random_area("Interior")
		var b2: Dictionary = drawn.get("building", {})
		if String(b2.get("size_class", "")) == "Small":
			small_hits += 1
		if String(drawn.get("name", "")) == TAVERN:
			tavern_hits += 1
	TestFixtures.check(res, "the interior draw never returns a small building", small_hits == 0,
		"%d of %d draw(s)" % [small_hits, DRAWS])
	TestFixtures.check(res, "the interior draw still returns the tavern", tavern_hits > 0,
		"%d of %d draw(s)" % [tavern_hits, DRAWS])


static func _case_plan(res: Dictionary, fields: Array[Dictionary]) -> void:
	var empty: Array[String] = []
	var wrong_front: Array[String] = []
	var bad_size: Array[String] = []
	var bad_floors: Array[String] = []
	var small_wings: Array[String] = []
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var plan: Dictionary = f.building_plan
		if plan.is_empty() or not plan.has("floor_w"):
			empty.append(_tag(e))
			continue
		if String(plan.get("front", "")) != String(e["front"]):
			wrong_front.append("%s got %s" % [_tag(e), String(plan.get("front", ""))])
		var b: Dictionary = DataManager.get_area_by_name(String(e["name"])).get("building", {})
		var w_range: Vector2i = b.get("width", Vector2i.ONE)
		var d_range: Vector2i = b.get("depth", Vector2i.ONE)
		var fw: int = int(plan.get("floor_w", 0))
		var fd: int = int(plan.get("floor_d", 0))
		var fh: int = int(plan.get("fh", 3))
		var fp: int = int(plan.get("fp", 0))
		var fm: int = int(plan.get("fm", 0))
		var w_lo: int = d_range.x
		var w_hi: int = d_range.y
		var d_lo: int = w_range.x
		var d_hi: int = w_range.y
		if String(e["front"]) == "N" or String(e["front"]) == "S":
			w_lo = w_range.x
			w_hi = w_range.y
			d_lo = d_range.x
			d_hi = d_range.y
		if fp + fm > 0:
			d_hi = maxi(d_hi, 2 * fh + 3)
			w_hi = maxi(w_hi, 5)
		if fw < w_lo or fw > w_hi or fd < d_lo or fd > d_hi:
			bad_size.append("%s %dx%d" % [_tag(e), fw, fd])
		var fp_range: Vector2i = b.get("f_plus", Vector2i.ZERO)
		var fm_range: Vector2i = b.get("f_minus", Vector2i.ZERO)
		var fp_ok: bool = fp == 0 or (fp >= fp_range.x and fp <= fp_range.y)
		var fm_ok: bool = fm == 0 or (fm >= fm_range.x and fm <= fm_range.y)
		if not fp_ok or not fm_ok:
			bad_floors.append("%s +%d/-%d" % [_tag(e), fp, fm])
		if String(b.get("size_class", "")) == "Small" and int(plan.get("wing_count", 0)) > 0:
			small_wings.append(_tag(e))
	var n: int = fields.size()
	TestFixtures.check(res, "every field keeps its rolled plan", empty.is_empty(),
		TestFixtures.detail(empty, n, "field(s)"))
	TestFixtures.check(res, "every plan faces the requested front", wrong_front.is_empty(),
		TestFixtures.detail(wrong_front, n, "field(s)"))
	TestFixtures.check(res, "floor_w and floor_d stay inside the row ranges", bad_size.is_empty(),
		TestFixtures.detail(bad_size, n, "field(s)"))
	TestFixtures.check(res, "fp and fm stay inside the row ranges", bad_floors.is_empty(),
		TestFixtures.detail(bad_floors, n, "field(s)"))
	TestFixtures.check(res, "no small building carries a wing", small_wings.is_empty(),
		TestFixtures.detail(small_wings, n, "field(s)"))


static func _case_validate(res: Dictionary, fields: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var bad_tries: Array[String] = []
	var ext_unreached: int = 0
	var retried: int = 0
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var hard: Array[String] = []
		for text: String in BuildingRules.validate(f):
			if _is_exterior_issue(text):
				ext_unreached += 1
				continue
			hard.append(text)
		if not hard.is_empty():
			bad.append("%s %s" % [_tag(e), hard[0]])
		var tries: int = int((f.building_plan as Dictionary).get("tries", 0))
		if tries < 1 or tries > BuildingRules.TRIES:
			bad_tries.append("%s tries=%d" % [_tag(e), tries])
		if tries > 1:
			retried += 1
	var n: int = fields.size()
	TestFixtures.check(res, "the validator reports no structural violation", bad.is_empty(),
		TestFixtures.detail(bad, n, "field(s)"))
	TestFixtures.check(res, "no field passes the retry limit", bad_tries.is_empty(),
		TestFixtures.detail(bad_tries, n, "field(s)"))
	print("BUILDING RETRIES: %d%% of %d field(s) needed more than one try; %d unreached exterior room(s)"
		% [roundi(100.0 * float(retried) / float(maxi(1, n))), n, ext_unreached])


#An "unreached <name> f<n>" line for a Patio or a Balcony; those rooms sit outside the floor mask.
static func _is_exterior_issue(text: String) -> bool:
	if not text.begins_with("unreached "):
		return false
	var body: String = text.substr(10)
	var cut: int = body.rfind(" f")
	if cut < 0:
		return false
	var d: ObstacleData = DataManager.get_obstacle_by_name(body.substr(0, cut))
	return d != null and d.room_type.begins_with("Exterior")


static func _case_front_door(res: Dictionary, fields: Array[Dictionary]) -> void:
	var bad_door: Array[String] = []
	var bad_outside: Array[String] = []
	var solid_shell: Array[String] = []
	var walled: int = 0
	var open_shells: int = 0
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var front: String = String(e["front"])
		if String((f.building_plan as Dictionary).get("shell", "Walled")) == "Open":
			open_shells += 1
			var solid: int = 0
			for obs: Dictionary in f.obstacles:
				var ct: String = String(obs.get("cell_type", ""))
				if ct == "door" or ct == "wall" or ct == "window":
					solid += 1
			if solid > 0:
				solid_shell.append("%s %d cell(s)" % [_tag(e), solid])
			continue
		walled += 1
		var door: Vector3i = (f.building_plan as Dictionary).get("front_door", Vector3i(-1, -1, 0))
		var kind: String = String((f._obs_map.get(door, {}) as Dictionary).get("cell_type", ""))
		if door.x < 0 or door.z != 0 or kind != "door" or not _on_front_wall(f, door, front):
			bad_door.append("%s at %s" % [_tag(e), str(door)])
			continue
		var outside: Vector3i = door - BuildingLayouts.inward(front)
		if f.footprint_cells.has(outside) or f._obs_map.has(outside):
			bad_outside.append("%s at %s" % [_tag(e), str(outside)])
	TestFixtures.check(res, "the front door sits in the front wall", bad_door.is_empty(),
		TestFixtures.detail(bad_door, walled, "walled field(s)"))
	TestFixtures.check(res, "the cell outside the front door is free street", bad_outside.is_empty(),
		TestFixtures.detail(bad_outside, walled, "walled field(s)"))
	TestFixtures.check(res, "an open shell carries no wall, door or window", solid_shell.is_empty(),
		TestFixtures.detail(solid_shell, open_shells, "open shell field(s)"))


static func _case_reach(res: Dictionary, fields: Array[Dictionary]) -> void:
	var no_start: Array[String] = []
	var cut_off: Array[String] = []
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var start: Vector3i = _start_cell(f, String(e["front"]))
		if start.x < 0:
			no_start.append(_tag(e))
			continue
		var dist: Dictionary = DungeonGenerator._walk_dist(f, start, true)
		var orphans: int = 0
		for key: Variant in f.footprint_cells.keys():
			var c: Vector3i = key as Vector3i
			if DungeonGenerator._passable(f, c, true) and not dist.has(c):
				orphans += 1
		if orphans > 0:
			cut_off.append("%s %d cell(s)" % [_tag(e), orphans])
	var n: int = fields.size()
	TestFixtures.check(res, "every field has a walk start", no_start.is_empty(),
		TestFixtures.detail(no_start, n, "field(s)"))
	TestFixtures.check(res, "every open footprint cell reaches the entrance", cut_off.is_empty(),
		TestFixtures.detail(cut_off, n, "field(s)"))


static func _case_movement(res: Dictionary, fields: Array[Dictionary]) -> void:
	var blocked: Array[String] = []
	var unreached: Array[String] = []
	var rooms_seen: int = 0
	#Doors generate shut; the default penalty of -1 plans no route through a shut door.
	PathCost.set_door_penalty(0)
	for e: Dictionary in fields:
		if int(e["si"]) != 0:
			continue
		var f: BattlefieldArea = e["field"]
		var front: String = String(e["front"])
		var from: Vector3i = _street_cell(f, front)
		if from.x < 0:
			continue
		for entry: Dictionary in f.interior_rooms:
			var rect: Rect2i = entry.get("rect", Rect2i())
			var fl: int = int(entry.get("floor", 0))
			if not _rect_in_mask(f, rect, fl):
				continue
			rooms_seen += 1
			var target: Vector3i = _free_cell(f, rect, fl)
			if target.x < 0:
				blocked.append("%s %s f%d" % [_tag(e), String(entry.get("name", "")), fl])
				continue
			if Pathfinder.find_path(from, target, f).is_empty():
				unreached.append("%s %s f%d" % [_tag(e), String(entry.get("name", "")), fl])
	PathCost.set_door_penalty(-1)
	TestFixtures.check(res, "every room keeps one free cell", blocked.is_empty(),
		TestFixtures.detail(blocked, rooms_seen, "room(s)"))
	TestFixtures.check(res, "a merc walks from the street into every room", unreached.is_empty(),
		TestFixtures.detail(unreached, rooms_seen, "room(s)"))


static func _case_main_room(res: Dictionary, fields: Array[Dictionary]) -> void:
	var bad_count: Array[String] = []
	var bad_name: Array[String] = []
	var far: Array[String] = []
	var walled: int = 0
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var plan: Dictionary = f.building_plan
		var want: String = String(plan.get("main_room", ""))
		var mains: Array[Dictionary] = []
		for entry: Dictionary in f.interior_rooms:
			if bool(entry.get("main", false)):
				mains.append(entry)
		if mains.size() != 1:
			bad_count.append("%s %d main(s)" % [_tag(e), mains.size()])
			continue
		var main: Dictionary = mains[0]
		if String(main.get("name", "")) != want or int(main.get("floor", 0)) != 0:
			bad_name.append("%s got %s f%d" % [_tag(e), String(main.get("name", "")),
				int(main.get("floor", 0))])
			continue
		if String(plan.get("shell", "Walled")) == "Open":
			continue
		walled += 1
		var door: Vector3i = plan.get("front_door", Vector3i(-1, -1, 0))
		if door.x < 0:
			continue
		var inside: Vector3i = door + BuildingLayouts.inward(String(e["front"]))
		if not (main.get("rect", Rect2i()) as Rect2i).grow(3).has_point(Vector2i(inside.x, inside.y)):
			far.append(_tag(e))
	var n: int = fields.size()
	TestFixtures.check(res, "every field carries one main room", bad_count.is_empty(),
		TestFixtures.detail(bad_count, n, "field(s)"))
	TestFixtures.check(res, "the main room carries the row name on floor 0", bad_name.is_empty(),
		TestFixtures.detail(bad_name, n, "field(s)"))
	TestFixtures.check(res, "the main room meets the front door", far.is_empty(),
		TestFixtures.detail(far, walled, "walled field(s)"))


static func _case_required(res: Dictionary, fields: Array[Dictionary]) -> void:
	var missing: Array[String] = []
	var wanted: int = 0
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var plan: Dictionary = f.building_plan
		var fp: int = int(plan.get("fp", 0))
		var fm: int = int(plan.get("fm", 0))
		for req: Variant in (plan.get("required_rooms", []) as Array):
			var req_name: String = String(req)
			var fits: bool = false
			var found: bool = false
			for fl: int in range(fp, -fm - 1, -1):
				if not BuildingRules.room_fits_floor(req_name, fl, fp):
					continue
				fits = true
				for entry: Dictionary in f.interior_rooms:
					if int(entry.get("floor", 0)) == fl and String(entry.get("name", "")) == req_name:
						found = true
						break
				if found:
					break
			if not fits:
				continue
			wanted += 1
			if not found:
				missing.append("%s %s" % [_tag(e), req_name])
	TestFixtures.check(res, "every required room lands on a floor it fits", missing.is_empty(),
		TestFixtures.detail(missing, wanted, "required room(s)"))


static func _case_layout(res: Dictionary, fields: Array[Dictionary]) -> void:
	var bad_rooms: Array[String] = []
	var bad_stairs: Array[String] = []
	var bad_band: Array[String] = []
	var counted: int = 0
	var banded: int = 0
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var plan: Dictionary = f.building_plan
		var layout: String = String(plan.get("layout_f0", "Open"))
		var rect: Rect2i = _inner_rect(f)
		if layout != "Corridor":
			counted += 1
			var rooms: int = 0
			for entry: Dictionary in f.interior_rooms:
				if int(entry.get("floor", 0)) != 0:
					continue
				if rect.encloses(entry.get("rect", Rect2i()) as Rect2i):
					rooms += 1
			var ok: bool = rooms >= 1
			if layout == "Open":
				ok = rooms == 1
			elif layout == "Shop":
				ok = rooms >= 2 and rooms <= 4
			if not ok:
				bad_rooms.append("%s %s %d room(s)" % [_tag(e), layout, rooms])
		var band_x0: int = int(plan.get("band_x0", -1))
		if band_x0 < 0:
			continue
		banded += 1
		var stray: int = 0
		for key: Variant in f.stair_run_cells.keys():
			var c: Vector3i = key as Vector3i
			if c.x != band_x0 and c.x != band_x0 + 1:
				stray += 1
		if stray > 0:
			bad_stairs.append("%s %d cell(s)" % [_tag(e), stray])
		var hits: int = 0
		for obs: Dictionary in f.obstacles:
			var ct: String = String(obs.get("cell_type", ""))
			if ct != "wall" and ct != "furniture":
				continue
			var p: Vector3i = obs["pos"] as Vector3i
			if p.x != band_x0 and p.x != band_x0 + 1:
				continue
			if p.y < rect.position.y or p.y > rect.end.y - 1:
				continue
			if ct == "wall" and _layout_of(plan, p.z) == "Corridor":
				continue
			hits += 1
		if hits > 0:
			bad_band.append("%s %d cell(s)" % [_tag(e), hits])
	TestFixtures.check(res, "each floor 0 layout holds its room count", bad_rooms.is_empty(),
		TestFixtures.detail(bad_rooms, counted, "field(s)"))
	TestFixtures.check(res, "every stair cell stays inside the band", bad_stairs.is_empty(),
		TestFixtures.detail(bad_stairs, banded, "banded field(s)"))
	TestFixtures.check(res, "no wall or furniture sits on a band cell", bad_band.is_empty(),
		TestFixtures.detail(bad_band, banded, "banded field(s)"))


static func _case_windows(res: Dictionary, fields: Array[Dictionary]) -> void:
	var none_bad: Array[String] = []
	var basement: Array[String] = []
	var band_bad: Array[String] = []
	var lit: Dictionary = {}
	var want_lit: Dictionary = {}
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var plan: Dictionary = f.building_plan
		var level: String = String(plan.get("windows", "Normal"))
		var walled: bool = String(plan.get("shell", "Walled")) != "Open"
		var area_name: String = String(e["name"])
		if walled and (level == "Normal" or level == "Many"):
			want_lit[area_name] = true
			if not lit.has(area_name):
				lit[area_name] = 0
		var band_x0: int = int(plan.get("band_x0", -1))
		var total: int = 0
		for obs: Dictionary in f.obstacles:
			if String(obs.get("cell_type", "")) != "window":
				continue
			var p: Vector3i = obs["pos"] as Vector3i
			total += 1
			if p.z < 0:
				basement.append("%s at %s" % [_tag(e), str(p)])
			if p.z == 0 and want_lit.has(area_name):
				lit[area_name] = int(lit[area_name]) + 1
			if band_x0 < 0:
				continue
			var inn: Vector3i = _inward_cell(f, p)
			if inn.x == band_x0 or inn.x == band_x0 + 1:
				band_bad.append("%s at %s" % [_tag(e), str(p)])
		if level == "None" and total > 0:
			none_bad.append("%s %d window(s)" % [_tag(e), total])
	var dark: Array[String] = []
	for key: Variant in want_lit.keys():
		if int(lit.get(key, 0)) == 0:
			dark.append(String(key))
	var n: int = fields.size()
	TestFixtures.check(res, "window level None places no window", none_bad.is_empty(),
		TestFixtures.detail(none_bad, n, "field(s)"))
	TestFixtures.check(res, "no window sits on a basement floor", basement.is_empty(),
		TestFixtures.detail(basement, n, "field(s)"))
	TestFixtures.check(res, "no window sits beside a band cell", band_bad.is_empty(),
		TestFixtures.detail(band_bad, n, "field(s)"))
	TestFixtures.check(res, "every lit building carries a floor 0 window", dark.is_empty(),
		TestFixtures.detail(dark, want_lit.size(), "building(s)"))


static func _case_furniture(res: Dictionary, fields: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	var hit: Dictionary = {}
	var posts: Array[String] = []
	var stalls: int = 0
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		var area_name: String = String(e["name"])
		for entry: Dictionary in f.interior_rooms:
			var room_name: String = String(entry.get("name", ""))
			var d: ObstacleData = DataManager.get_obstacle_by_name(room_name)
			if d == null or d.guaranteed_structures.is_empty():
				continue
			var key: String = "%s/%s" % [area_name, room_name]
			seen[key] = true
			if hit.has(key):
				continue
			if _rect_holds_any(f, entry.get("rect", Rect2i()) as Rect2i, int(entry.get("floor", 0)),
					d.guaranteed_structures):
				hit[key] = true
		if String((f.building_plan as Dictionary).get("shell", "Walled")) != "Open":
			continue
		stalls += 1
		var corners: Dictionary = _ring_corners(f)
		var found: int = 0
		for obs: Dictionary in f.obstacles:
			var data: ObstacleData = obs.get("data") as ObstacleData
			if data == null or data.obstacle_name != "Awning Post":
				continue
			found += 1
			var p: Vector3i = obs["pos"] as Vector3i
			corners.erase(Vector2i(p.x, p.y))
		if found != 4 or not corners.is_empty():
			posts.append("%s %d post(s), %d corner(s) bare" % [_tag(e), found, corners.size()])
	var missing: Array[String] = []
	for key2: Variant in seen.keys():
		if not hit.has(key2):
			missing.append(String(key2))
	TestFixtures.check(res, "every guaranteed structure reaches its room", missing.is_empty(),
		TestFixtures.detail(missing, seen.size(), "room name(s)"))
	TestFixtures.check(res, "the market stall carries four awning posts", posts.is_empty(),
		TestFixtures.detail(posts, stalls, "open shell field(s)"))


static func _case_sizes(res: Dictionary, fields: Array[Dictionary]) -> void:
	var small_cap: int = 0
	var large_floor: int = 1 << 20
	for area_name: String in _planned_names():
		var b: Dictionary = DataManager.get_area_by_name(area_name).get("building", {})
		var w_range: Vector2i = b.get("width", Vector2i.ONE)
		var d_range: Vector2i = b.get("depth", Vector2i.ONE)
		var size_class: String = String(b.get("size_class", ""))
		if size_class == "Small":
			small_cap = maxi(small_cap, maxi(w_range.y, d_range.y))
		elif size_class == "Large":
			large_floor = mini(large_floor, mini(w_range.x, d_range.x))
	var big_small: Array[String] = []
	var small_n: int = 0
	var large_n: int = 0
	var large_hits: int = 0
	for e: Dictionary in fields:
		var plan: Dictionary = (e["field"] as BattlefieldArea).building_plan
		var side: int = maxi(int(plan.get("floor_w", 0)), int(plan.get("floor_d", 0)))
		var size_class2: String = String(plan.get("size_class", ""))
		if size_class2 == "Small":
			small_n += 1
			if side > small_cap:
				big_small.append("%s %d" % [_tag(e), side])
		elif size_class2 == "Large":
			large_n += 1
			if side >= large_floor:
				large_hits += 1
	TestFixtures.check(res, "no small building passes %d cells" % small_cap, big_small.is_empty(),
		TestFixtures.detail(big_small, small_n, "small field(s)"))
	TestFixtures.check(res, "large buildings reach %d cells on one axis" % large_floor,
		large_hits * 2 >= large_n, "%d of %d large field(s)" % [large_hits, large_n])


static func _case_tavern(res: Dictionary) -> void:
	var drift: Array[String] = []
	var bad_wings: Array[String] = []
	for s: int in range(TAVERN_SEEDS):
		var seed_i: int = TAVERN_SEED_BASE + s
		var a: BattlefieldArea = _field(TAVERN, "", seed_i)
		var b: BattlefieldArea = _field(TAVERN, "", seed_i)
		if a.width != b.width or a.length != b.length or a.obstacles.size() != b.obstacles.size() \
				or a.interior_rooms.size() != b.interior_rooms.size():
			drift.append("s%d %dx%d/%dx%d obs %d/%d rooms %d/%d" % [seed_i, a.width, a.length,
				b.width, b.length, a.obstacles.size(), b.obstacles.size(),
				a.interior_rooms.size(), b.interior_rooms.size()])
		var wings: int = InteriorTests.wing_count(a)
		if wings < InteriorTests.WING_MIN or wings > InteriorTests.WING_MAX:
			bad_wings.append("s%d %d wing(s)" % [seed_i, wings])
	TestFixtures.check(res, "one seed builds the same tavern twice", drift.is_empty(),
		TestFixtures.detail(drift, TAVERN_SEEDS, "seed(s)"))
	TestFixtures.check(res, "every tavern keeps its wing count", bad_wings.is_empty(),
		TestFixtures.detail(bad_wings, TAVERN_SEEDS, "seed(s)"))


static func _case_spawns(res: Dictionary, fields: Array[Dictionary]) -> void:
	var empty: Array[String] = []
	var taken: Array[String] = []
	for e: Dictionary in fields:
		var f: BattlefieldArea = e["field"]
		if f.spawn_zone_a.is_empty() or f.spawn_zone_b.is_empty():
			empty.append("%s %d/%d" % [_tag(e), f.spawn_zone_a.size(), f.spawn_zone_b.size()])
			continue
		var busy: int = 0
		for zone: Dictionary in [f.spawn_zone_a, f.spawn_zone_b]:
			for key: Variant in zone.keys():
				var p: Vector2i = key as Vector2i
				if f._obs_map.has(Vector3i(p.x, p.y, 0)):
					busy += 1
		if busy > 0:
			taken.append("%s %d cell(s)" % [_tag(e), busy])
	var n: int = fields.size()
	TestFixtures.check(res, "both spawn zones carry cells", empty.is_empty(),
		TestFixtures.detail(empty, n, "field(s)"))
	TestFixtures.check(res, "no spawn cell holds an obstacle", taken.is_empty(),
		TestFixtures.detail(taken, n, "field(s)"))


#A patio gate and the yard cell inside it carry no obstacle, so the fence gap stays walkable.
static func _case_patio_gate(res: Dictionary, fields: Array[Dictionary]) -> void:
	var bad: Array[String] = []
	var gates: int = 0
	for e: Dictionary in fields:
		gates += _gate_hits(e["field"] as BattlefieldArea, _tag(e), bad)
	if gates == 0:
		for i: int in range(GATE_TRIES):
			var front: String = FRONTS[i % FRONTS.size()]
			var s: int = TAVERN_SEED_BASE + i
			var extra: BattlefieldArea = _field(TAVERN, front, s)
			gates += _gate_hits(extra, "%s %s s%d" % [TAVERN, front, s], bad)
			if gates > 0:
				break
	if gates == 0:
		TestFixtures.check(res, "the patio gate stays clear", false, "no gate generated")
		return
	TestFixtures.check(res, "the patio gate stays clear", bad.is_empty(),
		"%s; gates=%d" % [TestFixtures.detail(bad, gates, "gate(s)"), gates])


#Counts the gates of one field and notes every gate cell or inside cell that holds an obstacle.
static func _gate_hits(field: BattlefieldArea, tag: String, bad: Array[String]) -> int:
	var gates: int = 0
	for key: Variant in field.gate_cells.keys():
		var g: Vector3i = key as Vector3i
		gates += 1
		if field._obs_map.has(g):
			bad.append("%s gate %d,%d,%d is blocked" % [tag, g.x, g.y, g.z])
			continue
		for off: Vector3i in GATE_DIRS:
			var n: Vector3i = g + off
			if not field.building_interiors.has(n):
				continue
			if field._obs_map.has(n):
				bad.append("%s gate %d,%d,%d is sealed at %d,%d" % [tag, g.x, g.y, g.z, n.x, n.y])
			break
	return gates


static func _print_summary(fields: Array[Dictionary]) -> void:
	for area_name: String in _planned_names():
		var count: int = 0
		var tries: int = 0
		var rooms: int = 0
		var ms: int = 0
		for e: Dictionary in fields:
			if String(e["name"]) != area_name:
				continue
			var f: BattlefieldArea = e["field"]
			count += 1
			tries += int((f.building_plan as Dictionary).get("tries", 0))
			rooms += f.interior_rooms.size()
			ms += int(e["ms"])
		if count == 0:
			continue
		print("BUILDING %s: fields=%d tries=%.2f rooms=%.1f ms=%.1f" % [area_name, count,
			float(tries) / float(count), float(rooms) / float(count), float(ms) / float(count)])


#Interior rect of the main block on floor 0, walls excluded; the generator clamps both sides to 3.
static func _inner_rect(field: BattlefieldArea) -> Rect2i:
	var plan: Dictionary = field.building_plan
	var street: int = maxi(1, int(plan.get("street", 3)))
	var fw: int = maxi(3, int(plan.get("floor_w", 3)))
	var fd: int = maxi(3, int(plan.get("floor_d", 3)))
	return Rect2i(street + 1, field.interior_top_y + 1, fw, fd)


static func _ring_corners(field: BattlefieldArea) -> Dictionary:
	var rect: Rect2i = _inner_rect(field).grow(1)
	return {rect.position: true, Vector2i(rect.end.x - 1, rect.position.y): true,
		Vector2i(rect.position.x, rect.end.y - 1): true, Vector2i(rect.end.x - 1, rect.end.y - 1): true}


static func _on_front_wall(field: BattlefieldArea, door: Vector3i, front: String) -> bool:
	var rect: Rect2i = _inner_rect(field)
	if front == "W" or front == "E":
		if door.y < rect.position.y or door.y > rect.end.y - 1:
			return false
		return door.x == (rect.position.x - 1 if front == "W" else rect.end.x)
	if door.x < rect.position.x or door.x > rect.end.x - 1:
		return false
	return door.y == (rect.position.y - 1 if front == "N" else rect.end.y)


#Cell the walk starts from: inside the front door, or the middle of an open shell.
static func _start_cell(field: BattlefieldArea, front: String) -> Vector3i:
	var plan: Dictionary = field.building_plan
	var rect: Rect2i = _inner_rect(field)
	if String(plan.get("shell", "Walled")) == "Open":
		return Vector3i(rect.position.x + (rect.size.x >> 1), rect.position.y + (rect.size.y >> 1), 0)
	var door: Vector3i = plan.get("front_door", Vector3i(-1, -1, 0))
	if door.x < 0:
		return Vector3i(-1, -1, 0)
	return door + BuildingLayouts.inward(front)


#Street cell a merc walks in from: outside the front door, or the middle of an open shell.
static func _street_cell(field: BattlefieldArea, front: String) -> Vector3i:
	var plan: Dictionary = field.building_plan
	if String(plan.get("shell", "Walled")) == "Open":
		return _start_cell(field, front)
	var door: Vector3i = plan.get("front_door", Vector3i(-1, -1, 0))
	if door.x < 0:
		return Vector3i(-1, -1, 0)
	return door - BuildingLayouts.inward(front)


static func _layout_of(plan: Dictionary, fl: int) -> String:
	if fl == 0:
		return String(plan.get("layout_f0", "Open"))
	var other: String = String(plan.get("layout_other", ""))
	return other if other != "" else String(plan.get("layout_f0", "Open"))


static func _rect_in_mask(field: BattlefieldArea, rect: Rect2i, fl: int) -> bool:
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			if field.footprint_cells.has(Vector3i(x, y, fl)):
				return true
	return false


static func _free_cell(field: BattlefieldArea, rect: Rect2i, fl: int) -> Vector3i:
	for x: int in range(rect.position.x, rect.end.x):
		for y: int in range(rect.position.y, rect.end.y):
			var c := Vector3i(x, y, fl)
			if field.footprint_cells.has(c) and not field._obs_map.has(c):
				return c
	return Vector3i(-1, -1, 0)


static func _rect_holds_any(field: BattlefieldArea, rect: Rect2i, fl: int, names: Array[String]) -> bool:
	for obs: Dictionary in field.obstacles:
		var p: Vector3i = obs["pos"] as Vector3i
		if p.z != fl or not rect.has_point(Vector2i(p.x, p.y)):
			continue
		var data: ObstacleData = obs.get("data") as ObstacleData
		if data != null and names.has(data.obstacle_name):
			return true
	return false


#Cell just inside an outside wall cell; the wall side is the one neighbour outside the outline.
static func _inward_cell(field: BattlefieldArea, cell: Vector3i) -> Vector3i:
	for d: Vector2i in InteriorGenerator.DIRS4:
		if field.footprint_union.has(Vector2i(cell.x + d.x, cell.y + d.y)):
			continue
		return Vector3i(cell.x - d.x, cell.y - d.y, cell.z)
	return cell
