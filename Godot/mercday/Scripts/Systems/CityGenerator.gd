class_name CityGenerator

#City block maps: a main street grid cut by tier, the blocks between the bands, then side streets, alleys,
#plots and lots through CityStreets and CityPlots. Every attempt is validated and retried up to MAX_ATTEMPTS.

const TIERS: Array[String] = ["Small", "Medium", "Large", "Massive"]
const TIER_SIDE: Dictionary = {
	"Small": Vector2i(48, 64),
	"Medium": Vector2i(64, 88),
	"Large": Vector2i(88, 128),
	"Massive": Vector2i(128, 200),
}
const TIER_WEIGHTS: Dictionary = {"Small": 40, "Medium": 35, "Large": 20, "Massive": 5}
const CURB := 0.1
const MAX_ATTEMPTS := 6
const MAIN_W := Vector2i(4, 8)
const MAIN_SIDEWALK := 2
const BLOCK_INTERIOR := Vector2i(40, 64)
const EDGE_MIN := 14
const MAP_HEIGHT := 40
const FIT_STEPS := 512
const DEF_MIN_SIZE := 48
const DEF_MAX_SIZE := 200


#Builds one city block map into area; area.city holds the whole model when this returns.
static func generate(area: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext, tier: String = "") -> void:
	if area == null:
		return
	var t0: int = Time.get_ticks_msec()
	var pick: String = _pick_tier(ctx, tier)
	var kept: Array[String] = []
	var fails: Array[String] = []
	var issues: Array[String] = []
	var tries: int = 0
	for attempt: int in range(MAX_ATTEMPTS):
		tries = attempt + 1
		issues = _attempt(area, area_data, ctx, pick)
		if issues.is_empty():
			break
		fails.append("%d issues, first: %s" % [issues.size(), issues[0]])
		if attempt == MAX_ATTEMPTS - 1:
			break
		for line: String in area.generation_log:
			kept.append(line)
	var city: Dictionary = area.city
	city["tries"] = tries
	city["issues"] = issues
	city["ms"] = Time.get_ticks_msec() - t0
	_log(area, pick, kept, fails, tries, issues)


static func _log(area: BattlefieldArea, tier: String, kept: Array[String], fails: Array[String],
		tries: int, issues: Array[String]) -> void:
	for line: String in kept:
		area.generation_log.append(line)
	for i: int in range(fails.size()):
		area.generation_log.append("[CITY] attempt %d: %s" % [i + 1, fails[i]])
	var st: Dictionary = area.city.get("stats", {})
	var plots: Array = area.city.get("plots", [])
	var objects: int = int(st.get("nature_objects", 0)) + int(st.get("street_objects", 0))
	area.generation_log.append("[CITY] %s %dx%d mains=%d sides=%d alleys=%d dead_ends=%d plots=%d lots=%d nature=%d%% buildings=%d failed_lots=%d objects=%d tries=%d ms=%d" % [
		tier, area.width, area.length, int(st.get("mains", 0)), int(st.get("sides", 0)),
		int(st.get("alleys", 0)), int(st.get("dead_ends", 0)), plots.size(), int(st.get("lots", 0)),
		int(round(float(st.get("nature_pct", 0.0)))), int(st.get("buildings", 0)),
		int(st.get("failed_lots", 0)), objects, tries, int(area.city.get("ms", 0))])
	if issues.is_empty():
		return
	for txt: String in issues:
		area.generation_log.append("[CITY] LAYOUT ISSUE: %s" % txt)
	push_warning("CityGenerator: %s map kept with %d issues" % [tier, issues.size()])


#The forced tier, else the context tier, else a weighted roll walked in TIERS order.
static func _pick_tier(ctx: GenerationContext, forced: String) -> String:
	if TIERS.has(forced):
		return forced
	if ctx != null and TIERS.has(ctx.city_tier):
		return ctx.city_tier
	var total: int = 0
	for t: String in TIERS:
		total += int(TIER_WEIGHTS[t])
	var r: int = randi() % total
	for t2: String in TIERS:
		r -= int(TIER_WEIGHTS[t2])
		if r < 0:
			return t2
	return TIERS[0]


#One full pass: layout, lots, spawns, access, objects; the returned texts are what CityValidator left on it.
static func _attempt(area: BattlefieldArea, area_data: Dictionary, ctx: GenerationContext,
		tier: String) -> Array[String]:
	area.reset_generated_state()
	area.interior_rooms.clear()
	area.spawn_zone_a.clear()
	area.spawn_zone_b.clear()
	area.spawn_center_a = Vector2i.ZERO
	area.spawn_center_b = Vector2i.ZERO
	area.spawn_radius = 3.0
	area.is_city = true
	area.is_interior_map = true
	area.unevenness = 6
	area.height = MAP_HEIGHT
	area.area_name = String(area_data.get("name", "City Block"))
	var g: Dictionary = _roll_geometry(area, area_data, tier)
	var streets: Array[Dictionary] = []
	var blocks: Array[Dictionary] = []
	var plots: Array[Dictionary] = []
	var lots: Array[Dictionary] = []
	var issues: Array[String] = []
	area.city = {
		"tier": tier,
		"main_w": int(g.get("main_w", 0)),
		"pitch": int(g.get("pitch", 0)),
		"tries": 0,
		"ms": 0,
		"ms_lots": 0,
		"ms_spawn": 0,
		"ms_alleys": 0,
		"ms_objects": 0,
		"issues": issues,
		"streets": streets,
		"blocks": blocks,
		"plots": plots,
		"lots": lots,
		"stats": {},
	}
	if g.is_empty():
		issues.append("geometry: %s tier bands do not fit the row's Min and Max Size" % tier)
		return issues
	CityGrid.init(area)
	_stamp_mains(area, g, streets)
	_build_blocks(area, g, blocks)
	for b: Dictionary in blocks:
		CityStreets.build(area, b)
	for b2: Dictionary in blocks:
		CityPlots.build(area, b2)
	_fill_none(area)
	_curbs(area)
	area.city["stats"] = _stats(area)
	var layout: Array[String] = CityValidator.validate_layout(area)
	if not layout.is_empty():
		return layout
	var t_lots: int = Time.get_ticks_msec()
	CityLots.build(area)
	area.city["ms_lots"] = Time.get_ticks_msec() - t_lots
	var t_spawn: int = Time.get_ticks_msec()
	CitySpawns.build(area, ctx)
	area.city["ms_spawn"] = Time.get_ticks_msec() - t_spawn
	CityAccess.build(area)
	var t_alley: int = Time.get_ticks_msec()
	CityAlleys.build(area)
	area.city["ms_alleys"] = Time.get_ticks_msec() - t_alley
	var t_obj: int = Time.get_ticks_msec()
	CityStreetObjects.build(area)
	CityDressing.build(area, area_data)
	area.city["ms_objects"] = Time.get_ticks_msec() - t_obj
	BuildingStamp.finish(area)
	area.city["stats"] = _stats(area)
	return CityValidator.validate(area)


#Rolls main width, band counts, map sides and the block interior, then the band start lines of both axes.
static func _roll_geometry(area: BattlefieldArea, area_data: Dictionary, tier: String) -> Dictionary:
	var main_w: int = randi_range(MAIN_W.x, MAIN_W.y)
	var mt: int = main_w + 2 * MAIN_SIDEWALK
	var n_x: int = 0
	var n_y: int = 0
	match tier:
		"Small":
			if randi() % 2 == 0:
				n_x = 1
			else:
				n_y = 1
		"Medium":
			n_x = 1
			n_y = 1
		"Large":
			n_x = 2
			n_y = 2
		_:
			n_x = randi_range(3, 4)
			n_y = randi_range(3, 4)
	var span: Vector2i = TIER_SIDE.get(tier, TIER_SIDE["Small"])
	var lo: int = maxi(span.x, int(area_data.get("min_size", DEF_MIN_SIZE)))
	var hi: int = maxi(lo, mini(span.y, int(area_data.get("max_size", DEF_MAX_SIZE))))
	var wid: int = randi_range(lo, hi)
	var lng: int = randi_range(lo, hi)
	var bi: int = randi_range(BLOCK_INTERIOR.x, BLOCK_INTERIOR.y)
	for _step: int in range(FIT_STEPS):
		var need_l: int = _need(n_x, mt, bi)
		var need_w: int = _need(n_y, mt, bi)
		if lng >= need_l and wid >= need_w:
			break
		if bi > BLOCK_INTERIOR.x:
			bi -= 1
			continue
		var moved: bool = false
		if lng < need_l and lng < hi:
			lng = mini(hi, need_l)
			moved = true
		if wid < need_w and wid < hi:
			wid = mini(hi, need_w)
			moved = true
		if moved:
			continue
		if lng < need_l and n_x > 3:
			n_x -= 1
			moved = true
		if wid < need_w and n_y > 3:
			n_y -= 1
			moved = true
		if not moved:
			break
	if lng < _need(n_x, mt, bi) or wid < _need(n_y, mt, bi):
		return {}
	area.width = wid
	area.length = lng
	var pitch: int = 0
	if n_x >= 2 or n_y >= 2:
		pitch = bi
	var rows: Array[int] = _band_starts(n_x, mt, bi, lng)
	var cols: Array[int] = _band_starts(n_y, mt, bi, wid)
	return {
		"main_w": main_w,
		"mt": mt,
		"bi": bi,
		"pitch": pitch,
		"rows": rows,
		"cols": cols,
	}


#Map extent an axis with n bands needs: the bands, the interiors between them and the two edge strips.
static func _need(n: int, mt: int, bi: int) -> int:
	if n <= 0:
		return 0
	return n * mt + (n - 1) * bi + 2 * EDGE_MIN


static func _band_starts(n: int, mt: int, bi: int, side: int) -> Array[int]:
	var out: Array[int] = []
	if n <= 0:
		return out
	var rem: int = side - n * mt - (n - 1) * bi
	var top: int = rem - EDGE_MIN
	var e1: int = maxi(0, rem >> 1)
	if top >= EDGE_MIN:
		e1 = randi_range(EDGE_MIN, top)
	for k: int in range(n):
		out.append(e1 + k * (mt + bi))
	return out


#Sidewalk bands first, then every carriageway, so each crossing ends up all carriage with sidewalk corners.
static func _stamp_mains(area: BattlefieldArea, g: Dictionary, streets: Array[Dictionary]) -> void:
	var mt: int = int(g["mt"])
	var main_w: int = int(g["main_w"])
	var rows: Array[int] = g["rows"]
	var cols: Array[int] = g["cols"]
	var bands: Array[Rect2i] = []
	for y0: int in rows:
		bands.append(Rect2i(0, y0, area.width, mt))
		CityGrid.add_street(streets, "main", "x",
			_main_segments("x", Rect2i(0, y0 + MAIN_SIDEWALK, area.width, main_w), main_w),
			false, -1, Vector2i(-1, -1))
	for x0: int in cols:
		bands.append(Rect2i(x0, 0, mt, area.length))
		CityGrid.add_street(streets, "main", "y",
			_main_segments("y", Rect2i(x0 + MAIN_SIDEWALK, 0, main_w, area.length), main_w),
			false, -1, Vector2i(-1, -1))
	for i: int in range(bands.size()):
		CityGrid.paint_rect(area, bands[i], BattlefieldArea.SURF_SIDEWALK, i)
	for j: int in range(streets.size()):
		var segs: Array = streets[j]["segments"]
		var carriage: Rect2i = (segs[0] as Dictionary)["rect"]
		CityGrid.paint_rect(area, carriage, BattlefieldArea.SURF_MAIN, j)


static func _main_segments(axis: String, carriage: Rect2i, w: int) -> Array[Dictionary]:
	return [{"rect": carriage, "axis": axis, "width": w}]


#One block per pair of free intervals, ids row-major over the y intervals then the x intervals.
static func _build_blocks(area: BattlefieldArea, g: Dictionary, blocks: Array[Dictionary]) -> void:
	var mt: int = int(g["mt"])
	var rows: Array[int] = g["rows"]
	var cols: Array[int] = g["cols"]
	var y_iv: Array[Vector2i] = _free_intervals(rows, mt, area.length)
	var x_iv: Array[Vector2i] = _free_intervals(cols, mt, area.width)
	for yi: Vector2i in y_iv:
		for xi: Vector2i in x_iv:
			var rect := Rect2i(xi.x, yi.x, xi.y, yi.y)
			var sides: Array[String] = []
			if rect.position.y > 0:
				sides.append("N")
			if rect.end.y < area.length:
				sides.append("S")
			if rect.position.x > 0:
				sides.append("W")
			if rect.end.x < area.width:
				sides.append("E")
			blocks.append({
				"id": blocks.size(),
				"rect": rect,
				"full": sides.size() == 4,
				"main_sides": sides,
			})


#Gaps between the bands and the two map borders, as (start, size) pairs; an axis with no band gives one gap.
static func _free_intervals(starts: Array[int], thick: int, total: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at: int = 0
	for s: int in starts:
		if s > at:
			out.append(Vector2i(at, s - at))
		at = s + thick
	if total > at:
		out.append(Vector2i(at, total - at))
	return out


static func _fill_none(area: BattlefieldArea) -> void:
	for i: int in range(area.surface_grid.size()):
		if area.surface_grid[i] == BattlefieldArea.SURF_NONE:
			area.surface_grid[i] = BattlefieldArea.SURF_NATURE


#Sidewalks and alleys stand a curb above everything else; no other cell carries a terrain height.
static func _curbs(area: BattlefieldArea) -> void:
	for y: int in range(area.length):
		for x: int in range(area.width):
			var s: int = CityGrid.surf(area, x, y)
			if s == BattlefieldArea.SURF_SIDEWALK or s == BattlefieldArea.SURF_ALLEY:
				area.terrain_heights[Vector2i(x, y)] = CURB


static func _stats(area: BattlefieldArea) -> Dictionary:
	var mains: int = 0
	var sides: int = 0
	var alleys: int = 0
	var dead: int = 0
	var lanes: int = 0
	var streets: Array = area.city.get("streets", [])
	for st: Dictionary in streets:
		if st.has("ring") or st.has("connector"):
			continue
		if st.has("back_door"):
			lanes += 1
			continue
		match String(st.get("kind", "")):
			"main":
				mains += 1
			"side":
				sides += 1
			"alley":
				alleys += 1
		if bool(st.get("dead_end", false)):
			dead += 1
	var p_large: int = 0
	var p_medium: int = 0
	var p_small: int = 0
	for p: Dictionary in (area.city.get("plots", []) as Array):
		match String(p.get("class", "")):
			"Large":
				p_large += 1
			"Medium":
				p_medium += 1
			"Small":
				p_small += 1
	var cells: Dictionary = {}
	for s2: int in range(BattlefieldArea.SURF_NONE, BattlefieldArea.SURF_NATURE + 1):
		cells[s2] = 0
	for i: int in range(area.surface_grid.size()):
		var v: int = area.surface_grid[i]
		cells[v] = int(cells.get(v, 0)) + 1
	var lots: Array = area.city.get("lots", [])
	var failed: int = 0
	for lot: Dictionary in lots:
		if lot.has("failed"):
			failed += 1
	var objects: Dictionary = area.city.get("objects", {})
	var street_obs: int = int(objects.get("lamp", 0)) + int(objects.get("alley", 0)) \
		+ int(objects.get("sidewalk", 0)) + int(objects.get("square", 0))
	var total: int = maxi(1, area.width * area.length)
	var wrap_stats: Dictionary = area.city.get("alleys", {})
	return {
		"mains": mains,
		"sides": sides,
		"alleys": alleys,
		"dead_ends": dead,
		"back_lanes": lanes,
		"alley_ring_cells": int(wrap_stats.get("ring_cells", 0)),
		"alley_connector_cells": int(wrap_stats.get("connector_cells", 0)),
		"alley_connectors": int(wrap_stats.get("connectors", 0)),
		"alley_isolated": int(wrap_stats.get("isolated", 0)),
		"alley_connect_d": int(wrap_stats.get("d",
			CityAlleys.connect_d_for(mini(area.width, area.length)))),
		"plots_large": p_large,
		"plots_medium": p_medium,
		"plots_small": p_small,
		"lots": lots.size(),
		"buildings": area.buildings.size(),
		"failed_lots": failed,
		"nature_objects": int(objects.get("nature", 0)),
		"street_objects": street_obs,
		"nature_pct": 100.0 * float(int(cells[BattlefieldArea.SURF_NATURE])) / float(total),
		"cells": cells,
	}
