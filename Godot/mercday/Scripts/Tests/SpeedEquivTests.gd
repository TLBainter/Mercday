class_name SpeedEquivTests
extends RefCounted

#Equivalence guards for the city speed work: the lazy ray loop in LineOfSight._compute, the skipped
#floor test on open outdoor city cells and the bounded cover score in CoverSearch.find_cover_cell.
#CityTests.run() calls run_cases.

const CITY_TIER := "Small"
const CITY_SEED := 7503
const CITY_TRIES := 5
const PAIRS := 300
const STRIDE_A := 11
const STRIDE_B := 29
const OFFSET_B := 7
const REPORT_MAX := 3
const TEAM_SIZE := 4
const DEEP_LOW := -50.0
const DEEP_HIGH := 50.0


static func run_cases(res: Dictionary) -> void:
	var field: BattlefieldArea = CityFillTests.city_map(CITY_TIER, CITY_SEED, CITY_TRIES)
	_case_los_rays(res, field)
	_case_floor_block_outdoor(res, field)
	_case_cover_bound(res, field)


static func _passable(field: BattlefieldArea) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(field.width):
		for y: int in range(field.length):
			var pos := Vector2i(x, y)
			if field.has_walkable_surface(pos, 0):
				out.append(pos)
	return out


#Lazy ray loop.


#A copy of the pre-change _compute: all three rays traced, then the clean, graze and blocked returns.
static func _reference_compute(field: BattlefieldArea, from: Vector3i, from_height: int,
		from_size: int, tp: Vector3i, t_height: int, t_size: int) -> Dictionary:
	var f2 := Vector2i(from.x, from.y)
	var t2 := Vector2i(tp.x, tp.y)
	var t_own := LineOfSight._own_cell_top(field, t2, tp.z)
	var f_own := LineOfSight._own_cell_top(field, f2, from.z)
	if from.z == tp.z and from_height == 0 and t_height == 0 \
			and absi(f2.x - t2.x) + absi(f2.y - t2.y) == 1 \
			and t_own.is_empty() and f_own.is_empty():
		var adjacent := LineOfSight.clear_result()
		adjacent["via"] = "adjacent"
		return adjacent
	var cross_floor := from.z != tp.z
	var steps := LineOfSight.line_steps(f2, t2)
	if steps.is_empty():
		if not cross_floor:
			return LineOfSight.clear_result()
		steps.append({"c": t2, "o": [] as Array[Vector2i]})

	var t_base := field.cell_base_elevation(t2, tp.z)
	var oz := field.cell_base_elevation(f2, from.z) + float(from_height) + float(from_size) \
		- LineOfSight.EPS
	var base := t_base + float(t_height)
	var stair_skip := t_base if t_height == 0 else LineOfSight.NO_SKIP
	var targets: Array[float] = [
		base + float(t_size) * 0.5,
		base + float(t_size) - LineOfSight.EPS,
		base + LineOfSight.EPS,
	]
	var names: Array[String] = ["center", "top", "bottom"]
	if field.is_cavern:
		oz = minf(oz, LineOfSight._ceiling_at(field, f2) - LineOfSight.EPS)
		var t_cap := LineOfSight._ceiling_at(field, t2) - LineOfSight.EPS
		for i: int in range(targets.size()):
			targets[i] = minf(targets[i], t_cap)

	if not f_own.is_empty() and oz < float(f_own["top"]) - LineOfSight.EPS * 0.5:
		return {"visible": false, "cover": "full", "via": "", "blocker": str(f_own["label"]),
			"windows": [] as Array[Vector3i]}

	var own_blocked: Array[bool] = []
	for tz: float in targets:
		own_blocked.append(not t_own.is_empty() and tz < float(t_own["top"]) - LineOfSight.EPS * 0.5)

	var rays: Array[Dictionary] = []
	for i: int in range(targets.size()):
		if own_blocked[i]:
			rays.append({"state": "blocked", "blocker": str(t_own["label"]),
				"windows": [] as Array[Vector3i]})
		else:
			rays.append(LineOfSight._trace(field, f2, t2, steps, oz, targets[i], stair_skip))

	var own_cover := own_blocked.has(true)
	for i: int in range(rays.size()):
		if str(rays[i]["state"]) == "clean":
			return {"visible": true, "cover": "partial" if own_cover else "none", "via": names[i],
				"blocker": "", "windows": rays[i]["windows"]}
	for i: int in range(rays.size()):
		if str(rays[i]["state"]) == "graze":
			return {"visible": true, "cover": "partial", "via": names[i], "blocker": "",
				"windows": rays[i]["windows"]}
	return {"visible": false, "cover": "full", "via": "", "blocker": str(rays[0]["blocker"]),
		"windows": [] as Array[Vector3i]}


static func _same_result(a: Dictionary, b: Dictionary) -> String:
	if (a["visible"] as bool) != (b["visible"] as bool):
		return "visible %s of %s" % [str(a["visible"]), str(b["visible"])]
	if str(a["cover"]) != str(b["cover"]):
		return "cover %s of %s" % [str(a["cover"]), str(b["cover"])]
	if str(a["via"]) != str(b["via"]):
		return "via %s of %s" % [str(a["via"]), str(b["via"])]
	if str(a["blocker"]) != str(b["blocker"]):
		return "blocker %s of %s" % [str(a["blocker"]), str(b["blocker"])]
	var wa: Array = a["windows"] as Array
	var wb: Array = b["windows"] as Array
	if wa.size() != wb.size():
		return "windows %d of %d" % [wa.size(), wb.size()]
	for i: int in range(wa.size()):
		if (wa[i] as Vector3i) != (wb[i] as Vector3i):
			return "window %d %s of %s" % [i, str(wa[i]), str(wb[i])]
	return ""


static func _case_los_rays(res: Dictionary, field: BattlefieldArea) -> void:
	if field == null:
		TestFixtures.check(res, "speedequiv_los_rays", false, "no Small map")
		return
	var cells: Array[Vector2i] = _passable(field)
	if cells.size() < 2:
		TestFixtures.check(res, "speedequiv_los_rays", false, "%d passable cell(s)" % cells.size())
		return
	var bad: Array[String] = []
	var pairs: int = 0
	var seen: int = 0
	for i: int in range(PAIRS):
		var ca: Vector2i = cells[(i * STRIDE_A) % cells.size()]
		var cb: Vector2i = cells[(i * STRIDE_B + OFFSET_B) % cells.size()]
		if ca == cb:
			continue
		var a := Vector3i(ca.x, ca.y, 0)
		var b := Vector3i(cb.x, cb.y, 0)
		var got := LineOfSight._compute(field, a, 0, 1, b, 0, 1)
		var want := _reference_compute(field, a, 0, 1, b, 0, 1)
		pairs += 1
		if got["visible"] as bool:
			seen += 1
		var diff: String = _same_result(got, want)
		if diff != "" and bad.size() < REPORT_MAX:
			bad.append("%d,%d to %d,%d: %s" % [ca.x, ca.y, cb.x, cb.y, diff])
	TestFixtures.check(res, "speedequiv_los_rays", bad.is_empty(),
		"%d pair(s) %d visible" % [pairs, seen] if bad.is_empty() else "; ".join(bad))


#Open outdoor city cells never hit a floor plane.


static func _case_floor_block_outdoor(res: Dictionary, field: BattlefieldArea) -> void:
	if field == null:
		TestFixtures.check(res, "speedequiv_floor_block_outdoor", false, "no Small map")
		return
	var lowest: int = LineOfSight._lowest_floor(field)
	var bad: Array[String] = []
	var checked: int = 0
	for x: int in range(field.width):
		for y: int in range(field.length):
			var cell := Vector2i(x, y)
			if field.building_at(cell) >= 0 or field.roof_span.has(cell):
				continue
			checked += 1
			var hit: String = LineOfSight._floor_block(field, cell, DEEP_LOW, DEEP_HIGH, lowest)
			if hit != "" and bad.size() < REPORT_MAX:
				bad.append("%d,%d: %s" % [x, y, hit])
	TestFixtures.check(res, "speedequiv_floor_block_outdoor", bad.is_empty(),
		"%d cell(s)" % checked if bad.is_empty() else "; ".join(bad))


#Bounded cover score picks the same cell.


static func _state(map: BattlefieldArea) -> BattleState:
	var team_a: Array[MercenaryData] = []
	var team_b: Array[MercenaryData] = []
	for i: int in range(TEAM_SIZE):
		team_a.append(TestFixtures.city_melee("SA%d" % (i + 1)))
		team_b.append(TestFixtures.city_ranged("SB%d" % (i + 1)))
	return BattleState.create(team_a, team_b, map)


#A copy of find_cover_cell that scores every cell with the plain cover_score.
static func _reference_cover_cell(merc: MercenaryData, enemies: Array, state: BattleState) -> Vector3i:
	if state.battlefield == null:
		return PathTargeter.NO_CELL
	var ranged := CoverSearch.ranged_enemies(enemies)
	if ranged.is_empty():
		return PathTargeter.NO_CELL
	var here := state.pos3(merc)
	var pace: int = maxi(1, int(merc.stats.get("pace", 1)))
	var merc_size: int = merc.unit_size()
	var reach: Dictionary = ReachCache.reachable_for(merc, state)
	var base := CoverSearch.cover_score(here, merc_size, ranged, state)
	var best := PathTargeter.NO_CELL
	var best_full: int = base["full"]
	var best_partial: int = base["partial"]
	var best_cost := 0
	var here_floor := state.get_floor(merc)
	for cell: Vector3i in reach.keys():
		var cost: int = reach[cell] as int
		if cost <= 0 or cost > pace:
			continue
		if cell.z != here_floor:
			continue
		if state.is_position_occupied(Vector2i(cell.x, cell.y), merc, cell.z):
			continue
		var sc := CoverSearch.cover_score(cell, merc_size, ranged, state)
		var f: int = sc["full"]
		var pa: int = sc["partial"]
		var better := f > best_full
		if not better and f == best_full:
			better = pa > best_partial
		if not better and f == best_full and pa == best_partial:
			better = best != PathTargeter.NO_CELL and cost < best_cost
		if better:
			best_full = f
			best_partial = pa
			best_cost = cost
			best = cell
	return best


static func _case_cover_bound(res: Dictionary, field: BattlefieldArea) -> void:
	if field == null:
		TestFixtures.check(res, "speedequiv_cover_bound", false, "no Small map")
		return
	var state: BattleState = _state(field)
	if state == null:
		TestFixtures.check(res, "speedequiv_cover_bound", false, "no battle state")
		return
	var bad: Array[String] = []
	var mercs: int = 0
	var found: int = 0
	for merc: MercenaryData in (state.teams[0] as Array):
		var enemies: Array = state.get_enemies(merc)
		var want: Vector3i = _reference_cover_cell(merc, enemies, state)
		var got: Vector3i = CoverSearch.find_cover_cell(merc, enemies, state)
		mercs += 1
		if got != PathTargeter.NO_CELL:
			found += 1
		if got != want and bad.size() < REPORT_MAX:
			bad.append("%s picked %s of %s" % [merc.merc_name, str(got), str(want)])
	TestFixtures.check(res, "speedequiv_cover_bound", bad.is_empty(),
		"%d merc(s) %d with cover" % [mercs, found] if bad.is_empty() else "; ".join(bad))
