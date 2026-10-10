class_name CityGenTests

#City block generation: the area row, main streets, side streets, alleys, plots, lots, surfaces, the level
#dump and the validator, over 48 generated maps. CityTests.run() calls run_cases and run_break_case.
#Run: godot --headless --path . -- --city-tests

const ROW := "City Block"
const CURB := 0.1
const SUB_DIR := "city_gen"
const DUMP_NAME := "test_dump"
const SURFACE_HEAD := "=== Surface (floor 0) ==="
const ROLL_SEED := 9600
const DISPATCH_SEED := 9601
const FORCE_SEED := 9700
const ROLL_TIER_SEED := 9701
const RESET_SEED := 9702
const BUILDING_SEED := 9703
const EXTERIOR_SEED := 9704
const ROLLS := 40
const BREAKS := 12
const REPEAT_CHECKS := 10
const BARREL := "Barrel"
const MS_KEYS: Array[String] = ["ms", "ms_lots", "ms_spawn", "ms_alleys", "ms_objects"]
const REF_TIER := "Small"
const REF_SEED := 9200
const TIER_SEEDS: Array[Array] = [[REF_TIER, REF_SEED, 20], ["Medium", 9300, 20], ["Large", 9400, 6],
	["Massive", 9500, 2]]

static var _cache: Dictionary = {}


static func run_cases(res: Dictionary) -> void:
	_case_row(res)
	_case_dispatch(res)
	_case_clean(res)
	_case_size(res)
	_case_geometry(res)
	_case_mains(res)
	_case_grid(res)
	_case_widths(res)
	_case_surfaces(res)
	_case_plots(res)
	_case_cuts(res)
	_case_lots(res)
	_case_alleys(res)
	_case_seen(res)
	_case_repeat(res)
	_case_tier(res)
	_case_reset(res)
	_case_finish(res)
	_case_dump(res)


#Runs the case that breaks the cached Small map, then empties the cache.
static func run_break_case(res: Dictionary) -> void:
	_case_breaks(res)
	_cache.clear()


#The 48 cached maps as {"tier", "seed", "map"}, generated once per run.
static func maps() -> Array[Dictionary]:
	if _cache.has("list"):
		var kept: Array[Dictionary] = _cache["list"]
		return kept
	var list: Array[Dictionary] = []
	for spec: Array in TIER_SEEDS:
		for i: int in range(int(spec[2])):
			var s: int = int(spec[1]) + i
			list.append({"tier": String(spec[0]), "seed": s, "map": TestFixtures.city_gen(String(spec[0]), s, ROW)})
	_cache["list"] = list
	return list


static func _map_of(tier: String, seed_i: int) -> BattlefieldArea:
	for item: Dictionary in maps():
		if String(item["tier"]) == tier and int(item["seed"]) == seed_i:
			var map: BattlefieldArea = item["map"]
			return map
	return null


#The cached map the dump, finish and validator cases share.
static func ref_map() -> BattlefieldArea:
	return _map_of(REF_TIER, REF_SEED)


static func _case_row(res: Dictionary) -> void:
	var row: Dictionary = DataManager.get_area_by_name(ROW)
	var weights: Array = row.get("weights", [])
	var loud: int = 0
	for w: Variant in weights:
		if int(w) != 0:
			loud += 1
	TestFixtures.check(res, "citygen_area_row",
		not row.is_empty() and String(row.get("type", "")) == "City"
		and int(row.get("min_size", 0)) == 48 and int(row.get("max_size", 0)) == 200
		and weights.size() == 6 and loud == 0,
		"type '%s', %d..%d, %d weight(s), %d over zero" % [String(row.get("type", "")),
			int(row.get("min_size", 0)), int(row.get("max_size", 0)), weights.size(), loud])
	seed(ROLL_SEED)
	var rolled: Array[String] = []
	for kind: String in ["Exterior", "Interior"]:
		for _i: int in range(ROLLS):
			var got: Dictionary = DataManager.get_random_area(kind)
			if String(got.get("type", "")) == "City":
				rolled.append("%s rolled %s" % [kind, String(got.get("name", ""))])
	var drawn: bool = ContractTerrain.drawable(row)
	TestFixtures.check(res, "citygen_not_drawn", not drawn and rolled.is_empty(),
		"drawable %s; %s" % [str(drawn), TestFixtures.detail(rolled, ROLLS * 2, "roll(s)")])


static func _case_dispatch(res: Dictionary) -> void:
	seed(DISPATCH_SEED)
	var ctx := GenerationContext.new()
	ctx.city_tier = "Small"
	var f: BattlefieldArea = BattlefieldArea.generate_random(null, ctx, "City")
	var n: int = f.width * f.length
	TestFixtures.check(res, "citygen_dispatch",
		f.is_city and f.is_interior_map and f.surface_grid.size() == n and f.street_grid.size() == n,
		"city %s, interior %s, %dx%d, grids %d and %d" % [str(f.is_city), str(f.is_interior_map),
			f.width, f.length, f.surface_grid.size(), f.street_grid.size()])


static func _case_clean(res: Dictionary) -> void:
	for spec: Array in TIER_SEEDS:
		var tier: String = String(spec[0])
		var bad: Array[String] = []
		var total: int = 0
		for item: Dictionary in maps():
			if String(item["tier"]) != tier:
				continue
			total += 1
			var map: BattlefieldArea = item["map"]
			var issues: Array = map.city.get("issues", [])
			var tries: int = int(map.city.get("tries", 0))
			if issues.is_empty() and tries >= 1 and tries <= 6:
				continue
			var first: String = String(issues[0]) if not issues.is_empty() else "-"
			bad.append("s%d %d issue(s) in %d try(s): %s"
				% [int(item["seed"]), issues.size(), tries, first])
		TestFixtures.check(res, "citygen_clean_%s" % tier.to_lower(), bad.is_empty(),
			TestFixtures.detail(bad, total, "map(s)"))


static func _case_size(res: Dictionary) -> void:
	for spec: Array in TIER_SEEDS:
		var tier: String = String(spec[0])
		var span: Vector2i = CityGenerator.TIER_SIDE[tier]
		var bad: Array[String] = []
		var total: int = 0
		for item: Dictionary in maps():
			if String(item["tier"]) != tier:
				continue
			total += 1
			var map: BattlefieldArea = item["map"]
			if map.width < span.x or map.width > span.y or map.length < span.x or map.length > span.y:
				bad.append("s%d %dx%d" % [int(item["seed"]), map.width, map.length])
		TestFixtures.check(res, "citygen_size_%s" % tier.to_lower(), bad.is_empty(),
			"%d..%d; %s" % [span.x, span.y, TestFixtures.detail(bad, total, "map(s)")])


#A row whose Max Size is under the tier's need fails the roll instead of centring bands under EDGE_MIN.
static func _case_geometry(res: Dictionary) -> void:
	var tight: Dictionary = {"name": "Tight Row", "min_size": 48, "max_size": 128}
	var empty: int = 0
	for s: int in range(1, 9):
		seed(s)
		var probe := BattlefieldArea.new()
		if CityGenerator._roll_geometry(probe, tight, "Massive").is_empty():
			empty += 1
	TestFixtures.check(res, "citygen_geometry_refused", empty == 8, "%d of 8 roll(s) empty" % empty)
	var bad: Array[String] = []
	for s2: int in range(1, 9):
		seed(s2)
		var wide := BattlefieldArea.new()
		var g: Dictionary = CityGenerator._roll_geometry(wide, {"min_size": 48, "max_size": 200}, "Massive")
		if g.is_empty():
			bad.append("s%d empty" % s2)
			continue
		var mt: int = int(g["mt"])
		for axis: Array in [[g["rows"], wide.length], [g["cols"], wide.width]]:
			var starts: Array = axis[0] as Array
			var side: int = int(axis[1])
			if starts.is_empty():
				continue
			var first: int = int(starts[0])
			var last: int = int(starts[starts.size() - 1])
			if first < CityGenerator.EDGE_MIN or last + mt + CityGenerator.EDGE_MIN > side:
				bad.append("s%d bands %s in %d" % [s2, str(starts), side])
	TestFixtures.check(res, "citygen_geometry_edges", bad.is_empty(), TestFixtures.detail(bad, 8, "roll(s)"))
	seed(31)
	var area := BattlefieldArea.new()
	var ctx := GenerationContext.new()
	ctx.city_tier = "Massive"
	CityGenerator.generate(area, tight, ctx, "Massive")
	var issues: Array = area.city.get("issues", []) as Array
	TestFixtures.check(res, "citygen_geometry_issue",
		not issues.is_empty() and String(issues[0]).begins_with("geometry")
		and int(area.city.get("tries", 0)) == CityGenerator.MAX_ATTEMPTS
		and (area.city.get("streets", []) as Array).is_empty(),
		"%d issue(s), tries %d, first '%s'" % [issues.size(), int(area.city.get("tries", 0)),
			String(issues[0]) if not issues.is_empty() else ""])


static func _case_mains(res: Dictionary) -> void:
	var counts: Array[String] = []
	var straight: Array[String] = []
	var bands: Array[String] = []
	for item: Dictionary in maps():
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var main_w: int = int(map.city.get("main_w", 0))
		var nx: int = 0
		var ny: int = 0
		for entry: Variant in (map.city.get("streets", []) as Array):
			var st: Dictionary = entry as Dictionary
			if String(st.get("kind", "")) != "main":
				continue
			var id: int = int(st.get("id", -1))
			var axis: String = String(st.get("axis", ""))
			if axis == "x":
				nx += 1
			else:
				ny += 1
			var segs: Array = st.get("segments", [])
			if segs.size() != 1:
				straight.append("s%d main %d holds %d segment(s)" % [s, id, segs.size()])
				continue
			var r: Rect2i = (segs[0] as Dictionary).get("rect", Rect2i())
			var thick: int = r.size.y if axis == "x" else r.size.x
			var spans: bool = (r.position.x == 0 and r.size.x == map.width) if axis == "x" \
				else (r.position.y == 0 and r.size.y == map.length)
			var cell: Vector2i = _first_other(map, r, BattlefieldArea.SURF_MAIN)
			if not spans or thick != main_w or main_w < 4 or main_w > 8:
				straight.append("s%d main %d %s thick %d, main_w %d" % [s, id, str(r), thick, main_w])
			elif cell.x >= 0:
				straight.append("s%d main %d cell %d,%d holds %d"
					% [s, id, cell.x, cell.y, map.surface_at(cell)])
			var loose: Vector2i = _first_unpaved(map, r, axis)
			if loose.x >= 0:
				bands.append("s%d main %d band cell %d,%d holds %d"
					% [s, id, loose.x, loose.y, map.surface_at(loose)])
		if not _main_count_ok(String(item["tier"]), nx, ny):
			counts.append("s%d %s holds %d x and %d y" % [s, String(item["tier"]), nx, ny])
	var total: int = maps().size()
	TestFixtures.check(res, "citygen_main_count", counts.is_empty(), TestFixtures.detail(counts, total, "map(s)"))
	TestFixtures.check(res, "citygen_main_straight", straight.is_empty(),
		TestFixtures.detail(straight, total, "map(s)"))
	TestFixtures.check(res, "citygen_main_sidewalk", bands.is_empty(), TestFixtures.detail(bands, total, "map(s)"))


static func _case_grid(res: Dictionary) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for item: Dictionary in maps():
		var tier: String = String(item["tier"])
		if tier != "Large" and tier != "Massive":
			continue
		total += 1
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var pitch: int = int(map.city.get("pitch", 0))
		var main_w: int = int(map.city.get("main_w", 0))
		if pitch < 40 or pitch > 64:
			bad.append("s%d pitch %d" % [s, pitch])
			continue
		for axis: String in ["x", "y"]:
			var starts: Array[int] = []
			for entry: Variant in (map.city.get("streets", []) as Array):
				var st: Dictionary = entry as Dictionary
				if String(st.get("kind", "")) != "main" or String(st.get("axis", "")) != axis:
					continue
				var segs: Array = st.get("segments", [])
				if segs.is_empty():
					continue
				var r: Rect2i = (segs[0] as Dictionary).get("rect", Rect2i())
				starts.append(r.position.y if axis == "x" else r.position.x)
			starts.sort()
			for i: int in range(1, starts.size()):
				var gap: int = starts[i] - starts[i - 1] - main_w - 4
				if gap != pitch:
					bad.append("s%d %s gap %d for pitch %d" % [s, axis, gap, pitch])
	TestFixtures.check(res, "citygen_grid_regular", bad.is_empty(), TestFixtures.detail(bad, total, "map(s)"))


static func _case_widths(res: Dictionary) -> void:
	var sides: Array[String] = []
	var alleys: Array[String] = []
	for item: Dictionary in maps():
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		for entry: Variant in (map.city.get("streets", []) as Array):
			var st: Dictionary = entry as Dictionary
			var kind: String = String(st.get("kind", ""))
			if kind != "side" and kind != "alley":
				continue
			var lo: int = 2 if kind == "side" else 1
			var hi: int = 4 if kind == "side" else 2
			for sv: Variant in (st.get("segments", []) as Array):
				var seg: Dictionary = sv as Dictionary
				var r: Rect2i = seg.get("rect", Rect2i())
				var axis: String = String(seg.get("axis", ""))
				var across: int = r.size.y if axis == "x" else r.size.x
				if across >= lo and across <= hi and int(seg.get("width", 0)) == across:
					continue
				var text: String = "s%d street %d %s is %d cell(s) wide, says %d" % [s,
					int(st.get("id", -1)), str(r), across, int(seg.get("width", 0))]
				if kind == "side":
					sides.append(text)
				else:
					alleys.append(text)
	var total: int = maps().size()
	TestFixtures.check(res, "citygen_side_width", sides.is_empty(), TestFixtures.detail(sides, total, "map(s)"))
	TestFixtures.check(res, "citygen_alley_width", alleys.is_empty(), TestFixtures.detail(alleys, total, "map(s)"))


static func _case_surfaces(res: Dictionary) -> void:
	var curbs: Array[String] = []
	var cut: Array[String] = []
	var touch: Array[String] = []
	var blank: Array[String] = []
	for item: Dictionary in maps():
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var bad_curb: String = _curb_fault(map)
		if bad_curb != "":
			curbs.append("s%d %s" % [s, bad_curb])
		var loose: String = _reach_fault(map)
		if loose != "":
			cut.append("s%d %s" % [s, loose])
		var met: String = _touch_fault(map)
		if met != "":
			touch.append("s%d %s" % [s, met])
		var empty: String = _blank_fault(map)
		if empty != "":
			blank.append("s%d %s" % [s, empty])
	var total: int = maps().size()
	TestFixtures.check(res, "citygen_curb", curbs.is_empty(), TestFixtures.detail(curbs, total, "map(s)"))
	TestFixtures.check(res, "citygen_connected", cut.is_empty(), TestFixtures.detail(cut, total, "map(s)"))
	TestFixtures.check(res, "citygen_carriage_wrapped", touch.is_empty(), TestFixtures.detail(touch, total, "map(s)"))
	TestFixtures.check(res, "citygen_no_none", blank.is_empty(), TestFixtures.detail(blank, total, "map(s)"))


static func _case_plots(res: Dictionary) -> void:
	var th: Dictionary = CityPlots.class_thresholds()
	var bad: Array[String] = []
	for item: Dictionary in maps():
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		for pv: Variant in (map.city.get("plots", []) as Array):
			var p: Dictionary = pv as Dictionary
			var r: Rect2i = p.get("rect", Rect2i())
			var m: int = mini(r.size.x, r.size.y)
			var want: String = "Small"
			if m >= 20:
				want = "Large"
			elif m >= 13:
				want = "Medium"
			if String(p.get("class", "")) == want and m >= 6 and maxi(r.size.x, r.size.y) <= 28:
				continue
			bad.append("s%d plot %d %dx%d is %s, wants %s" % [s, int(p.get("id", -1)), r.size.x,
				r.size.y, String(p.get("class", "")), want])
	var known: bool = int(th.get("Large", 0)) == 20 and int(th.get("Medium", 0)) == 13 \
		and int(th.get("Small", 0)) == 6
	TestFixtures.check(res, "citygen_plot_class", known and bad.is_empty(),
		"thresholds %d/%d/%d; %s" % [int(th.get("Large", 0)), int(th.get("Medium", 0)),
			int(th.get("Small", 0)), TestFixtures.detail(bad, maps().size(), "map(s)")])


#A Large threshold above 22 never leaves a cut remainder under PLOT_MIN.
static func _case_cuts(res: Dictionary) -> void:
	var bad: Array[String] = []
	var total: int = 0
	for size: int in [29, 40, 60, 91]:
		for s: int in range(1, 26):
			seed(s)
			total += 1
			var cuts: Array[int] = CityPlots._cuts(0, size, 26)
			for i: int in range(1, cuts.size()):
				var piece: int = cuts[i] - cuts[i - 1]
				if piece < CityPlots.PLOT_MIN or piece > CityPlots.PLOT_MAX:
					bad.append("size %d s%d piece %d" % [size, s, piece])
					break
			if cuts[cuts.size() - 1] != size:
				bad.append("size %d s%d ends %d" % [size, s, cuts[cuts.size() - 1]])
	TestFixtures.check(res, "citygen_cuts_bounded", bad.is_empty(), TestFixtures.detail(bad, total, "cut(s)"))


static func _case_lots(res: Dictionary) -> void:
	var fit: Array[String] = []
	var access: Array[String] = []
	var cells: Array[String] = []
	for item: Dictionary in maps():
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var owner := PackedInt32Array()
		owner.resize(map.width * map.length)
		owner.fill(-1)
		var lanes: Dictionary = _lane_ids(map)
		for lv: Variant in (map.city.get("lots", []) as Array):
			var lot: Dictionary = lv as Dictionary
			_lot_fit(lot, s, fit)
			_lot_access(map, lot, s, access)
			_lot_cells(map, lot, s, lanes, owner, cells)
		_stray_lot_cell(map, s, owner, cells)
	var total: int = maps().size()
	TestFixtures.check(res, "citygen_lot_fit", fit.is_empty(), TestFixtures.detail(fit, total, "map(s)"))
	TestFixtures.check(res, "citygen_lot_access", access.is_empty(), TestFixtures.detail(access, total, "map(s)"))
	TestFixtures.check(res, "citygen_lot_cells", cells.is_empty(), TestFixtures.detail(cells, total, "map(s)"))


#Every row a lot names fits its frontage and depth, and a lot names at least one row.
static func _lot_fit(lot: Dictionary, s: int, fit: Array[String]) -> void:
	var id: int = int(lot.get("id", -1))
	var r: Rect2i = lot.get("rect", Rect2i())
	var span: Vector2i = _frontage_depth(r, String(lot.get("front", "")))
	var rows: Array = lot.get("rows", [])
	if rows.is_empty():
		fit.append("s%d lot %d names no row" % [s, id])
	for rv: Variant in rows:
		if _row_fits(String(rv), span.x, span.y):
			continue
		fit.append("s%d lot %d row %s over %dx%d" % [s, id, String(rv), span.x, span.y])


#The front of a lot meets the street kind it names, and a lot off a main street had no main side to take.
static func _lot_access(map: BattlefieldArea, lot: Dictionary, s: int, access: Array[String]) -> void:
	var id: int = int(lot.get("id", -1))
	var r: Rect2i = lot.get("rect", Rect2i())
	var front: String = String(lot.get("front", ""))
	var kind: String = String(CityGrid.side_touch(map, r, front)["kind"])
	if not CityGrid.side_has_access(map, r, front) or kind != String(lot.get("front_kind", "")):
		access.append("s%d lot %d front %s meets '%s', says '%s'"
			% [s, id, front, kind, String(lot.get("front_kind", ""))])
	elif kind != "main":
		var missed: String = _main_front_missed(map, lot, String(lot.get("class", "")))
		if missed != "":
			access.append("s%d lot %d %s" % [s, id, missed])


#The first cell of the lot with the wrong surface or an earlier lot as owner; owner marks the cells claimed so far.
static func _lot_cells(map: BattlefieldArea, lot: Dictionary, s: int, lanes: Dictionary,
		owner: PackedInt32Array, cells: Array[String]) -> void:
	var id: int = int(lot.get("id", -1))
	var r: Rect2i = lot.get("rect", Rect2i())
	for y: int in range(maxi(r.position.y, 0), mini(r.end.y, map.length)):
		for x: int in range(maxi(r.position.x, 0), mini(r.end.x, map.width)):
			var i: int = y * map.width + x
			var surf: int = map.surface_grid[i]
			var owned: bool = map.building_id_at.has(Vector2i(x, y))
			var lane: bool = surf == BattlefieldArea.SURF_ALLEY \
				and lanes.has(map.street_grid[i])
			var fine: bool = (surf == BattlefieldArea.SURF_LOT) if owned \
				else (surf == BattlefieldArea.SURF_NATURE or lane)
			if not fine:
				cells.append("s%d lot %d cell %d,%d holds %d" % [s, id, x, y, surf])
				return
			if owner[i] >= 0:
				cells.append("s%d lot %d overlaps lot %d at %d,%d" % [s, id, owner[i], x, y])
				return
			owner[i] = id


#The first lot surface cell that no lot claimed.
static func _stray_lot_cell(map: BattlefieldArea, s: int, owner: PackedInt32Array, cells: Array[String]) -> void:
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			var i: int = row + x
			if map.surface_grid[i] != BattlefieldArea.SURF_LOT or owner[i] >= 0:
				continue
			cells.append("s%d lot cell %d,%d belongs to no lot" % [s, x, y])
			return


static func _case_alleys(res: Dictionary) -> void:
	var rings: Array[String] = []
	var links: Array[String] = []
	for item: Dictionary in maps():
		var map: BattlefieldArea = item["map"]
		var s: int = int(item["seed"])
		var d: int = CityAlleys.connect_d_for(mini(map.width, map.length))
		for sv: Variant in (map.city.get("streets", []) as Array):
			var st: Dictionary = sv as Dictionary
			if not CityAlleys.is_wrap(st):
				continue
			var ring: bool = CityAlleys.is_ring(st)
			var fault: String = _ring_fault(map, st) if ring else _link_fault(map, st, d)
			if fault == "":
				continue
			if ring:
				rings.append("s%d %s" % [s, fault])
			else:
				links.append("s%d %s" % [s, fault])
	var total: int = maps().size()
	TestFixtures.check(res, "citygen_alley_rings", rings.is_empty(), TestFixtures.detail(rings, total, "map(s)"))
	TestFixtures.check(res, "citygen_alley_connectors", links.is_empty(),
		TestFixtures.detail(links, total, "map(s)"))
	var sides: Array[int] = [48, 100, 152, 200]
	var want: Array[int] = [2, 4, 5, 7]
	var reach: Array[String] = []
	for i: int in range(sides.size()):
		var got: int = CityAlleys.connect_d_for(sides[i])
		if got != want[i]:
			reach.append("side %d reaches %d, wants %d" % [sides[i], got, want[i]])
	TestFixtures.check(res, "citygen_alley_d", reach.is_empty(),
		TestFixtures.detail(reach, sides.size(), "side(s)"))


#"" when the ring names a placed building and every cell it holds stands 1 to width Paces from it.
static func _ring_fault(map: BattlefieldArea, st: Dictionary) -> String:
	var id: int = int(st.get("id", -1))
	var bid: int = int(st.get("ring", -1))
	var w: int = int(st.get("width", 0))
	if bid < 0 or bid >= map.buildings.size():
		return "ring %d names building %d" % [id, bid]
	if w < 1 or w > 2:
		return "ring %d runs %d cell(s) wide" % [id, w]
	var cells: Array = st.get("cells", []) as Array
	if cells.is_empty():
		return "ring %d paints no cell" % id
	var rect: Rect2i = (map.buildings[bid] as Dictionary).get("rect", Rect2i())
	for cv: Variant in cells:
		var c: Vector2i = cv as Vector2i
		var fault: String = _wrap_cell_fault(map, c, id)
		if fault != "":
			return "ring %d %s" % [id, fault]
		var far: int = CityAlleys._cheb(c, rect)
		if far < 1 or far > w:
			return "ring %d cell %d,%d stands %d from building %d" % [id, c.x, c.y, far, bid]
	return ""


#"" when the connector is a 4-connected strip of at most d cells that meets a street at either end.
static func _link_fault(map: BattlefieldArea, st: Dictionary, d: int) -> String:
	var id: int = int(st.get("id", -1))
	var w: int = int(st.get("width", 0))
	if w != 1:
		return "connector %d runs %d cell(s) wide" % [id, w]
	var cells: Array = st.get("cells", []) as Array
	if cells.is_empty() or cells.size() > d:
		return "connector %d paints %d cell(s) over %d" % [id, cells.size(), d]
	var last := Vector2i(-9, -9)
	for cv: Variant in cells:
		var c: Vector2i = cv as Vector2i
		var fault: String = _wrap_cell_fault(map, c, id)
		if fault != "":
			return "connector %d %s" % [id, fault]
		if last.x > -9 and absi(last.x - c.x) + absi(last.y - c.y) != 1:
			return "connector %d jumps %d,%d to %d,%d" % [id, last.x, last.y, c.x, c.y]
		last = c
	for e: Vector2i in [cells[0] as Vector2i, cells[cells.size() - 1] as Vector2i]:
		if not _joins_street(map, e, id):
			return "connector %d end %d,%d meets no other street" % [id, e.x, e.y]
	return ""


#"" when the cell carries alley paint under street id, no building and the curb height.
static func _wrap_cell_fault(map: BattlefieldArea, c: Vector2i, id: int) -> String:
	if not map.in_bounds_xy(c.x, c.y):
		return "cell %d,%d lies outside the map" % [c.x, c.y]
	var i: int = c.y * map.width + c.x
	if map.surface_grid[i] != BattlefieldArea.SURF_ALLEY:
		return "cell %d,%d holds surface %d" % [c.x, c.y, map.surface_grid[i]]
	if map.street_grid[i] != id:
		return "cell %d,%d names street %d" % [c.x, c.y, map.street_grid[i]]
	if map.building_id_at.has(c):
		return "cell %d,%d sits under a building" % [c.x, c.y]
	var h: float = float(map.terrain_heights.get(c, 0.0))
	if not is_equal_approx(h, CURB):
		return "cell %d,%d stands at %.2f" % [c.x, c.y, h]
	return ""


#True when a 4-neighbour of the cell carries street paint another street id owns.
static func _joins_street(map: BattlefieldArea, c: Vector2i, id: int) -> bool:
	for step: Vector2i in DungeonGenerator.DIRS4:
		var n: Vector2i = c + step
		if not map.in_bounds_xy(n.x, n.y):
			continue
		var i: int = n.y * map.width + n.x
		if CityGrid.is_street(map.surface_grid[i]) and map.street_grid[i] != id:
			return true
	return false


static func _case_seen(res: Dictionary) -> void:
	var many: int = 0
	var whole: int = 0
	var sides: int = 0
	var alleys: int = 0
	var dead: int = 0
	var through: int = 0
	for item: Dictionary in maps():
		var map: BattlefieldArea = item["map"]
		for pv: Variant in (map.city.get("plots", []) as Array):
			var p: Dictionary = pv as Dictionary
			var count: int = (p.get("lots", []) as Array).size()
			if count >= 2:
				many += 1
			elif count == 1 and String(p.get("class", "")) == "Large":
				whole += 1
		if String(item["tier"]) == "Small":
			continue
		for sv: Variant in (map.city.get("streets", []) as Array):
			var st: Dictionary = sv as Dictionary
			var kind: String = String(st.get("kind", ""))
			if kind == "alley":
				alleys += 1
			elif kind == "side":
				sides += 1
				if bool(st.get("dead_end", false)):
					dead += 1
				else:
					through += 1
	TestFixtures.check(res, "citygen_fillings_seen", many > 0 and whole > 0,
		"%d plot(s) with 2 or more lots, %d whole Large plot(s)" % [many, whole])
	TestFixtures.check(res, "citygen_streets_seen",
		sides > 0 and alleys > 0 and dead > 0 and through > 0,
		"%d side(s), %d alley(s), %d dead end(s), %d through" % [sides, alleys, dead, through])


static func _case_repeat(res: Dictionary) -> void:
	var bad: Array[String] = []
	for spec: Array in [["Small", 9200], ["Medium", 9300]]:
		var tier: String = String(spec[0])
		var seed_i: int = int(spec[1])
		var want: BattlefieldArea = _map_of(tier, seed_i)
		var got: BattlefieldArea = TestFixtures.city_gen(tier, seed_i, ROW)
		if want == null:
			bad.append("s%d is not cached" % seed_i)
			continue
		if got.surface_grid != want.surface_grid:
			bad.append("s%d surfaces differ" % seed_i)
		if got.street_grid != want.street_grid:
			bad.append("s%d street ids differ" % seed_i)
		if _city_text(got) != _city_text(want):
			bad.append("s%d model differs" % seed_i)
		if got.obstacles.size() != want.obstacles.size():
			bad.append("s%d object count differs" % seed_i)
		if got.buildings.size() != want.buildings.size():
			bad.append("s%d building count differs" % seed_i)
	TestFixtures.check(res, "citygen_deterministic", bad.is_empty(),
		TestFixtures.detail(bad, REPEAT_CHECKS, "check(s)"))


static func _case_tier(res: Dictionary) -> void:
	var row: Dictionary = DataManager.get_area_by_name(ROW)
	var forced := BattlefieldArea.new()
	var ctx := GenerationContext.new()
	ctx.city_tier = "Massive"
	seed(FORCE_SEED)
	CityGenerator.generate(forced, row, ctx, "Small")
	var rolled := BattlefieldArea.new()
	var ctx2 := GenerationContext.new()
	ctx2.city_tier = "Enormous"
	seed(ROLL_TIER_SEED)
	CityGenerator.generate(rolled, row, ctx2, "")
	var forced_tier: String = String(forced.city.get("tier", ""))
	var rolled_tier: String = String(rolled.city.get("tier", ""))
	TestFixtures.check(res, "citygen_tier_forced",
		forced_tier == "Small" and CityGenerator.TIERS.has(rolled_tier),
		"argument Small over context Massive gave '%s', context 'Enormous' rolled '%s'"
			% [forced_tier, rolled_tier])


static func _case_reset(res: Dictionary) -> void:
	var map: BattlefieldArea = TestFixtures.city_gen("Small", RESET_SEED, ROW)
	map.reset_generated_state()
	TestFixtures.check(res, "citygen_reset",
		not map.is_city and map.surface_grid.is_empty() and map.street_grid.is_empty()
		and map.city.is_empty(),
		"city %s, grids %d and %d, model %d key(s)" % [str(map.is_city), map.surface_grid.size(),
			map.street_grid.size(), map.city.size()])
	seed(BUILDING_SEED)
	var shop: BattlefieldArea = BattlefieldArea.generate_random(null, GenerationContext.new(),
		"Interior", DataManager.get_area_by_name("Cobbler"))
	seed(EXTERIOR_SEED)
	var field: BattlefieldArea = BattlefieldArea.generate_random(null, GenerationContext.new(),
		"Exterior", DataManager.get_random_area("Exterior"))
	TestFixtures.check(res, "citygen_other_maps",
		not shop.is_city and shop.surface_grid.is_empty() and shop.street_grid.is_empty()
		and shop.city.is_empty() and not field.is_city and field.surface_grid.is_empty()
		and field.street_grid.is_empty() and field.city.is_empty(),
		"%s city %s, %s city %s" % [shop.area_name, str(shop.is_city), field.area_name,
			str(field.is_city)])


static func _case_finish(res: Dictionary) -> void:
	var map: BattlefieldArea = ref_map()
	if map == null:
		TestFixtures.check(res, "citygen_finish", false, "no cached map")
		return
	var floors: Dictionary = map.interior_floor_elevations
	var planes: Dictionary = map.outdoor_planes
	var main: Vector2i = _find_surface(map, BattlefieldArea.SURF_MAIN)
	var ground: float = map.floor_elevation_at(main, 0) if main.x >= 0 else -1.0
	var plane0: float = float(planes.get(0, -1.0))
	var loose: int = 0
	for rec: Dictionary in map.buildings:
		for fv: Variant in (rec.get("floors", []) as Array):
			if not floors.has(int(fv)):
				loose += 1
	TestFixtures.check(res, "citygen_finish",
		not map.buildings.is_empty() and floors.has(0) and planes.has(0) and main.x >= 0
		and loose == 0 and is_equal_approx(plane0, float(floors.get(0, -2.0)))
		and is_equal_approx(ground, plane0),
		"%d building(s), floors %s, ground plane %.1f, main cell %d,%d at %.1f, %d floor(s) off the table"
			% [map.buildings.size(), str(floors.keys()), plane0, main.x, main.y, ground, loose])


static func _case_dump(res: Dictionary) -> void:
	var map: BattlefieldArea = ref_map()
	if map == null:
		TestFixtures.check(res, "citygen_dump", false, "no cached map")
		return
	var lines: PackedStringArray = GenFixtures.dump_lines(map, SUB_DIR, DUMP_NAME)
	var named: bool = false
	for line: String in lines:
		if line.begins_with("CITY:"):
			named = true
	var rows: int = GenFixtures.grid_rows(lines, SURFACE_HEAD, map)
	TestFixtures.check(res, "citygen_dump", named and rows == map.length,
		"CITY line %s, legend %s, %d of %d row(s) of %d character(s)" % [str(named), str(rows >= 0),
			maxi(rows, 0), map.length, map.width])


static func _case_breaks(res: Dictionary) -> void:
	var map: BattlefieldArea = ref_map()
	if map == null:
		TestFixtures.check(res, "citygen_validator_catches", false, "no cached map")
		return
	var missed: Array[String] = []
	var clean: Array[String] = CityValidator.validate(map)
	if not clean.is_empty():
		missed.append("the clean map reports %s" % clean[0])
	_break_curb(map, missed)
	_break_nature(map, missed)
	_break_carriage(map, missed)
	_break_segment(map, missed)
	_break_lot_surface(map, missed)
	_break_lot_building(map, missed)
	_break_spawn(map, missed)
	_break_stats(map, missed)
	_break_lane(missed)
	_break_object(map, missed)
	_break_spacing(map, missed)
	_break_ring(map, missed)
	TestFixtures.check(res, "citygen_validator_catches", missed.is_empty(),
		TestFixtures.detail(missed, BREAKS, "break(s)"))


static func _break_curb(map: BattlefieldArea, missed: Array[String]) -> void:
	var walk: Vector2i = _find_surface(map, BattlefieldArea.SURF_SIDEWALK)
	if walk.x < 0:
		missed.append("no sidewalk cell")
		return
	var old: float = float(map.terrain_heights.get(walk, 0.0))
	map.terrain_heights[walk] = 0.0
	_expect_report(map, "curb", "a flattened curb", missed)
	map.terrain_heights[walk] = old


static func _break_nature(map: BattlefieldArea, missed: Array[String]) -> void:
	var wild: Vector2i = _nature_outside_lots(map)
	if wild.x < 0:
		missed.append("no nature cell outside every lot")
		return
	var i: int = wild.y * map.width + wild.x
	map.surface_grid[i] = BattlefieldArea.SURF_LOT
	_expect_report(map, "outside every lot", "a lot cell outside every lot", missed)
	map.surface_grid[i] = BattlefieldArea.SURF_NATURE


static func _break_carriage(map: BattlefieldArea, missed: Array[String]) -> void:
	var beside: Vector2i = _carriage_neighbour(map)
	if beside.x < 0:
		missed.append("no carriageway neighbour")
		return
	var j: int = beside.y * map.width + beside.x
	var was: int = map.surface_grid[j]
	map.surface_grid[j] = BattlefieldArea.SURF_NATURE
	_expect_report(map, "touches", "nature against a carriageway", missed)
	map.surface_grid[j] = was


static func _break_segment(map: BattlefieldArea, missed: Array[String]) -> void:
	var seg: Dictionary = _any_segment(map)
	if seg.is_empty():
		missed.append("no segment")
		return
	var width: int = int(seg.get("width", 0))
	seg["width"] = width + 5
	_expect_report(map, "says width", "a wrong segment width", missed)
	seg["width"] = width


static func _break_lot_surface(map: BattlefieldArea, missed: Array[String]) -> void:
	var owned: Vector2i = _first_owned_lot_cell(map)
	if owned.x < 0:
		missed.append("no lot cell a building owns")
		return
	var i: int = owned.y * map.width + owned.x
	var was: int = map.surface_grid[i]
	map.surface_grid[i] = BattlefieldArea.SURF_NATURE
	_expect_report(map, "holds surface", "a building cell turned to nature", missed)
	map.surface_grid[i] = was


static func _break_lot_building(map: BattlefieldArea, missed: Array[String]) -> void:
	var lot: Dictionary = _lot_with_building(map)
	if lot.is_empty():
		missed.append("no lot holds a building")
		return
	var was: int = int(lot.get("building", -1))
	lot["building"] = -1
	_expect_report(map, "holds no building and did not fail", "a lot that lost its building", missed)
	lot["building"] = was


static func _break_spawn(map: BattlefieldArea, missed: Array[String]) -> void:
	var sp: Dictionary = map.city.get("spawn", {})
	if sp.is_empty():
		missed.append("no spawn record")
		return
	var was: int = int(sp.get("side_b", -1))
	sp["side_b"] = int(sp.get("side_a", -1))
	_expect_report(map, "both teams spawn on side", "both teams on one side", missed)
	sp["side_b"] = was


static func _break_stats(map: BattlefieldArea, missed: Array[String]) -> void:
	var stats: Dictionary = map.city.get("stats", {})
	if stats.is_empty():
		missed.append("no stats record")
		return
	var was: int = int(stats.get("buildings", 0))
	stats["buildings"] = was + 1
	_expect_report(map, "stats buildings", "a wrong building count", missed)
	stats["buildings"] = was


#Needs a map that holds a painted back lane, so the cached Small maps are tried in seed order.
static func _break_lane(missed: Array[String]) -> void:
	for item: Dictionary in maps():
		if String(item["tier"]) != "Small":
			continue
		var map: BattlefieldArea = item["map"]
		var lane: Dictionary = _first_lane(map)
		if lane.is_empty():
			continue
		var was: int = int(lane.get("back_door", -1))
		lane["back_door"] = 9999
		_expect_report(map, "names building 9999", "a lane that names no building", missed)
		lane["back_door"] = was
		return
	missed.append("no cached Small map holds a back lane")


#Written by hand: CityObjects.place refuses a protected cell, so the object tables take the record direct.
static func _break_object(map: BattlefieldArea, missed: Array[String]) -> void:
	var cell: Vector2i = _free_protected(map)
	var data: ObstacleData = DataManager.get_obstacle_by_name(BARREL)
	if cell.x < 0 or data == null:
		missed.append("no free protected cell")
		return
	var key := Vector3i(cell.x, cell.y, 0)
	var obs: Dictionary = {"pos": key, "size": 1, "data": data, "rotated": false, "floor": 0,
		"pw": 1, "ph": 1, "city": "alley"}
	map._obs_map[key] = obs
	map.obstacles.append(obs)
	_expect_report(map, "on a protected cell", "a blocking object on a protected cell", missed)
	map._obs_map.erase(key)
	map.obstacles.pop_back()


#A cell beside building 0 is handed to building 1, so the two stand closer than the gap of the design.
static func _break_spacing(map: BattlefieldArea, missed: Array[String]) -> void:
	if map.buildings.size() < 2:
		missed.append("fewer than 2 buildings")
		return
	var r: Rect2i = (map.buildings[0] as Dictionary).get("rect", Rect2i())
	var cell := Vector2i(r.position.x - 1, r.position.y)
	if cell.x < 0 or map.building_id_at.has(cell):
		cell = Vector2i(r.end.x, r.position.y)
	if cell.x >= map.width or map.building_id_at.has(cell):
		missed.append("no free cell beside building 0")
		return
	map.building_id_at[cell] = 1
	_expect_report(map, "stands within", "two buildings closer than the gap", missed)
	map.building_id_at.erase(cell)


#A ring painted over a cell its building owns, which no lot allows whatever street owns the paint.
static func _break_ring(map: BattlefieldArea, missed: Array[String]) -> void:
	var owned: Vector2i = _first_owned_lot_cell(map)
	if owned.x < 0:
		missed.append("no lot cell a building owns")
		return
	var i: int = owned.y * map.width + owned.x
	var was: int = map.surface_grid[i]
	var was_id: int = map.street_grid[i]
	var had: bool = map.terrain_heights.has(owned)
	var was_h: float = float(map.terrain_heights.get(owned, 0.0))
	var ring: int = _first_wrap_id(map)
	map.surface_grid[i] = BattlefieldArea.SURF_ALLEY
	if ring >= 0:
		map.street_grid[i] = ring
	map.terrain_heights[owned] = CURB
	_expect_report(map, "holds surface", "a ring over a building cell", missed)
	map.surface_grid[i] = was
	map.street_grid[i] = was_id
	if had:
		map.terrain_heights[owned] = was_h
	else:
		map.terrain_heights.erase(owned)


#Street id of the first ring or connector of the map; -1 when the alley pass painted none.
static func _first_wrap_id(map: BattlefieldArea) -> int:
	for sv: Variant in (map.city.get("streets", []) as Array):
		var st: Dictionary = sv as Dictionary
		if CityAlleys.is_wrap(st):
			return int(st.get("id", -1))
	return -1


static func _reports(map: BattlefieldArea, needle: String) -> bool:
	for text: String in CityValidator.validate(map):
		if text.contains(needle):
			return true
	return false


#Adds label to missed when the validator does not report needle on the map as broken by the caller.
static func _expect_report(map: BattlefieldArea, needle: String, label: String, missed: Array[String]) -> void:
	if not _reports(map, needle):
		missed.append(label)


static func _find_surface(map: BattlefieldArea, want: int) -> Vector2i:
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			if map.surface_grid[row + x] == want:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


#Street ids of the painted back lanes, the building rings and the connectors of the map.
static func _lane_ids(map: BattlefieldArea) -> Dictionary:
	var out: Dictionary = {}
	for sv: Variant in (map.city.get("streets", []) as Array):
		var st: Dictionary = sv as Dictionary
		if st.has("back_door") or CityAlleys.is_wrap(st):
			out[int(st.get("id", -1))] = true
	return out


static func _first_lane(map: BattlefieldArea) -> Dictionary:
	for sv: Variant in (map.city.get("streets", []) as Array):
		var st: Dictionary = sv as Dictionary
		if st.has("back_door"):
			return st
	return {}


static func _lot_with_building(map: BattlefieldArea) -> Dictionary:
	for lv: Variant in (map.city.get("lots", []) as Array):
		var lot: Dictionary = lv as Dictionary
		if int(lot.get("building", -1)) >= 0:
			return lot
	return {}


#First cell inside a lot rect that a building owns; (-1, -1) when the map holds none.
static func _first_owned_lot_cell(map: BattlefieldArea) -> Vector2i:
	for lv: Variant in (map.city.get("lots", []) as Array):
		var r: Rect2i = (lv as Dictionary).get("rect", Rect2i())
		for y: int in range(maxi(r.position.y, 0), mini(r.end.y, map.length)):
			for x: int in range(maxi(r.position.x, 0), mini(r.end.x, map.width)):
				var c := Vector2i(x, y)
				if map.building_id_at.has(c):
					return c
	return Vector2i(-1, -1)


#First nature cell that lies in no lot rect; (-1, -1) when the map holds none.
static func _nature_outside_lots(map: BattlefieldArea) -> Vector2i:
	var lots: Array = map.city.get("lots", []) as Array
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			if map.surface_grid[row + x] != BattlefieldArea.SURF_NATURE:
				continue
			var c := Vector2i(x, y)
			var held: bool = false
			for lv: Variant in lots:
				var r: Rect2i = (lv as Dictionary).get("rect", Rect2i())
				if r.has_point(c):
					held = true
					break
			if not held:
				return c
	return Vector2i(-1, -1)


#First protected cell that holds no object of its own; (-1, -1) when every one is taken.
static func _free_protected(map: BattlefieldArea) -> Vector2i:
	var access: Dictionary = map.city.get("access", {})
	for ck: Variant in (access.get("protected", {}) as Dictionary).keys():
		var c: Vector2i = ck as Vector2i
		if not map._obs_map.has(Vector3i(c.x, c.y, 0)):
			return c
	return Vector2i(-1, -1)


#A sidewalk cell that touches a main street carriageway; (-1, -1) when the map holds none.
static func _carriage_neighbour(map: BattlefieldArea) -> Vector2i:
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			if map.surface_grid[row + x] != BattlefieldArea.SURF_MAIN:
				continue
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var c := Vector2i(x + dx, y + dy)
					if CityGrid.surf(map, c.x, c.y) == BattlefieldArea.SURF_SIDEWALK:
						return c
	return Vector2i(-1, -1)


#The first side street or alley segment of the map, or the first main segment when it holds neither.
static func _any_segment(map: BattlefieldArea) -> Dictionary:
	var fallback: Dictionary = {}
	for sv: Variant in (map.city.get("streets", []) as Array):
		var st: Dictionary = sv as Dictionary
		var segs: Array = st.get("segments", [])
		if segs.is_empty():
			continue
		if String(st.get("kind", "")) == "main":
			if fallback.is_empty():
				fallback = segs[0] as Dictionary
			continue
		return segs[0] as Dictionary
	return fallback


static func _city_text(map: BattlefieldArea) -> String:
	var model: Dictionary = map.city.duplicate(true)
	for key: String in MS_KEYS:
		model.erase(key)
	return var_to_str(model)


static func _main_count_ok(tier: String, nx: int, ny: int) -> bool:
	if tier == "Small":
		return nx + ny == 1
	if tier == "Medium":
		return nx == 1 and ny == 1
	if tier == "Large":
		return nx == 2 and ny == 2
	return nx >= 3 and nx <= 4 and ny >= 3 and ny <= 4


#First cell of rect that does not hold want; (-1, -1) when every cell does.
static func _first_other(map: BattlefieldArea, rect: Rect2i, want: int) -> Vector2i:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if CityGrid.surf(map, x, y) != want:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


#First cell of the two sidewalk bands beside a main carriageway that is no street surface.
static func _first_unpaved(map: BattlefieldArea, rect: Rect2i, axis: String) -> Vector2i:
	var bands: Array[Rect2i] = []
	if axis == "x":
		bands.append(Rect2i(0, rect.position.y - 2, map.width, 2))
		bands.append(Rect2i(0, rect.end.y, map.width, 2))
	else:
		bands.append(Rect2i(rect.position.x - 2, 0, 2, map.length))
		bands.append(Rect2i(rect.end.x, 0, 2, map.length))
	for band: Rect2i in bands:
		for y: int in range(band.position.y, band.end.y):
			for x: int in range(band.position.x, band.end.x):
				if not map.in_bounds_xy(x, y):
					continue
				var s: int = map.surface_grid[y * map.width + x]
				if s != BattlefieldArea.SURF_MAIN and s != BattlefieldArea.SURF_SIDE \
						and s != BattlefieldArea.SURF_SIDEWALK:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


#"" when every curb stands where it belongs; the first wrong cell otherwise. Building cells carry their
#own floor planes, so only outdoor ground is read.
static func _curb_fault(map: BattlefieldArea) -> String:
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			var cell := Vector2i(x, y)
			if map.building_id_at.has(cell):
				continue
			var s: int = map.surface_grid[row + x]
			var want: float = CURB if (s == BattlefieldArea.SURF_SIDEWALK
				or s == BattlefieldArea.SURF_ALLEY) else 0.0
			var got: float = map.get_terrain_height(cell)
			if not is_equal_approx(got, want):
				return "cell %d,%d of surface %d stands at %.2f, not %.2f" % [x, y, s, got, want]
			if not is_equal_approx(map.walk_elevation(cell, 0), got):
				return "cell %d,%d walks at %.2f over %.2f" % [x, y, map.walk_elevation(cell, 0), got]
	return ""


#"" when every street cell reaches every other over street cells. Rings and connectors carry
#the walk but are not counted, since a ring may wrap a building no street reaches.
static func _reach_fault(map: BattlefieldArea) -> String:
	var skip: Dictionary = CityAlleys.wrap_cells(map)
	var seen := PackedByteArray()
	seen.resize(map.surface_grid.size())
	var total: int = 0
	var sx: int = -1
	var sy: int = -1
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			if not CityGrid.is_street(map.surface_grid[row + x]) or skip.has(Vector2i(x, y)):
				continue
			total += 1
			if sx < 0:
				sx = x
				sy = y
	if sx < 0:
		return "the map holds no street cell"
	var qx := PackedInt32Array()
	var qy := PackedInt32Array()
	qx.append(sx)
	qy.append(sy)
	seen[sy * map.width + sx] = 1
	var reached: int = 0
	while not qx.is_empty():
		var last: int = qx.size() - 1
		var cx: int = qx[last]
		var cy: int = qy[last]
		qx.remove_at(last)
		qy.remove_at(last)
		if not skip.has(Vector2i(cx, cy)):
			reached += 1
		for step: Vector2i in DungeonGenerator.DIRS4:
			var nx: int = cx + step.x
			var ny: int = cy + step.y
			if not map.in_bounds_xy(nx, ny):
				continue
			var i2: int = ny * map.width + nx
			if seen[i2] != 0 or not CityGrid.is_street(map.surface_grid[i2]):
				continue
			seen[i2] = 1
			qx.append(nx)
			qy.append(ny)
	if reached != total:
		return "%d of %d street cell(s) hang loose" % [total - reached, total]
	return ""


#"" when no carriageway cell touches anything but carriageway and sidewalk.
static func _touch_fault(map: BattlefieldArea) -> String:
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			if not CityGrid.is_carriage(map.surface_grid[row + x]):
				continue
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = x + dx
					var ny: int = y + dy
					if not map.in_bounds_xy(nx, ny):
						continue
					var s: int = map.surface_grid[ny * map.width + nx]
					if s == BattlefieldArea.SURF_MAIN or s == BattlefieldArea.SURF_SIDE \
							or s == BattlefieldArea.SURF_SIDEWALK:
						continue
					return "carriageway %d,%d touches surface %d at %d,%d" % [x, y, s, nx, ny]
	return ""


#"" when the map holds no blank cell and the stats count every cell.
static func _blank_fault(map: BattlefieldArea) -> String:
	for y: int in range(map.length):
		var row: int = y * map.width
		for x: int in range(map.width):
			if map.surface_grid[row + x] == BattlefieldArea.SURF_NONE:
				return "cell %d,%d carries no surface" % [x, y]
	var cells: Dictionary = (map.city.get("stats", {}) as Dictionary).get("cells", {})
	var sum: int = 0
	for key: Variant in cells.keys():
		sum += int(cells[key])
	if sum != map.width * map.length:
		return "stats count %d of %d cell(s)" % [sum, map.width * map.length]
	return ""


#"" when no side of the lot on a main street was passed over for a lesser front.
static func _main_front_missed(map: BattlefieldArea, lot: Dictionary, cls: String) -> String:
	var r: Rect2i = lot.get("rect", Rect2i())
	for side: String in CityGrid.SIDES:
		if not CityGrid.side_has_access(map, r, side):
			continue
		if String(CityGrid.side_touch(map, r, side)["kind"]) != "main":
			continue
		var span: Vector2i = _frontage_depth(r, side)
		if CityPlots.rows_that_fit(cls, span.x, span.y).is_empty():
			continue
		return "passes over main side %s for '%s'" % [side, String(lot.get("front_kind", ""))]
	return ""


#Frontage in x and depth in y of a rect whose front faces side.
static func _frontage_depth(r: Rect2i, side: String) -> Vector2i:
	var down: bool = side == "N" or side == "S"
	return Vector2i(r.size.x, r.size.y) if down else Vector2i(r.size.y, r.size.x)


static func _row_fits(row_name: String, frontage: int, depth: int) -> bool:
	var data: Dictionary = DataManager.get_area_by_name(row_name)
	if data.is_empty() or not data.has("building"):
		return false
	var b: Dictionary = data["building"]
	var w: Vector2i = b.get("width", Vector2i())
	var d: Vector2i = b.get("depth", Vector2i())
	return w.x + 4 <= frontage and d.x + 4 <= depth

