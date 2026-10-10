class_name LosTests

#Deterministic LineOfSight cases. Run: godot --headless --path . -- --los-tests
#No randomness: every field is built cell by cell and asserted against a hand computed ray.

const WALL_H := 4.0
const FENCE_H := 0.75
const POST_H := 4.0


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_wall(res)
	_case_window_intact(res)
	_case_window_broken(res)
	_case_fence_partial(res)
	_case_sight_cover(res)
	_case_flyer_over_fence(res)
	_case_big_shooter(res)
	_case_size2_top_only(res)
	_case_terrain_ridge(res)
	_case_adjacent(res)
	_case_corner(res)
	_case_doors(res)
	_case_slab(res)
	_case_stairwell(res)
	_case_balcony(res)
	_case_basement(res)
	_case_stair_run(res)
	_case_under_stairs(res)
	_case_roof_object(res)
	return TestFixtures.summarize(res, "LOS")


static func _fmt(r: Dictionary) -> String:
	return "visible=%s cover=%s via=%s blocker=%s windows=%d" % [
		str(r["visible"]), str(r["cover"]), str(r["via"]), str(r["blocker"]),
		(r["windows"] as Array).size()]


static func _los(f: BattlefieldArea, from: Vector3i, fh: int, fs: int,
		tp: Vector3i, th: int, ts: int) -> Dictionary:
	return LineOfSight._compute(f, from, fh, fs, tp, th, ts)


static func _case_wall(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(2, 0, 0), {"cell_type": "wall", "height": WALL_H})
	var r := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(4, 0, 0), 0, 1)
	TestFixtures.check(res, "wall blocks", not (r["visible"] as bool), _fmt(r))


static func _case_window_intact(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(2, 0, 0), {"cell_type": "window", "height": WALL_H})
	var r := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(4, 0, 0), 0, 1)
	var wins: Array = r["windows"] as Array
	var ok: bool = (r["visible"] as bool) and wins.size() == 1 and wins[0] == Vector3i(2, 0, 0)
	TestFixtures.check(res, "intact window visible and listed", ok, _fmt(r))


static func _case_window_broken(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(2, 0, 0), {"cell_type": "window", "height": WALL_H, "broken": true})
	var r := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(4, 0, 0), 0, 1)
	var ok: bool = (r["visible"] as bool) and (r["windows"] as Array).is_empty()
	TestFixtures.check(res, "broken window visible and not listed", ok, _fmt(r))


static func _case_fence_partial(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(2, 0, 0), {"cell_type": "fence", "height": FENCE_H})
	var r := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(4, 0, 0), 0, 1)
	var ok: bool = (r["visible"] as bool) and str(r["cover"]) == "partial"
	TestFixtures.check(res, "fence gives partial cover", ok, _fmt(r))


#A Lamp Post copy: tall and narrow, Sight=Cover unless the case asks for the plain rule.
static func _post_data(sight: bool) -> ObstacleData:
	var d := ObstacleData.new()
	d.obstacle_name = "Lamp Post"
	d.size_z = POST_H
	d.height = POST_H
	d.narrow = true
	d.sight_cover = sight
	return d


static func _put_post(f: BattlefieldArea, cell: Vector3i, sight: bool) -> void:
	TestFixtures.put(f, cell, {"cell_type": "furniture", "height": POST_H, "data": _post_data(sight)})


static func _case_sight_cover(res: Dictionary) -> void:
	var mid := TestFixtures.exterior_field()
	_put_post(mid, Vector3i(3, 0, 0), true)
	var r_mid := _los(mid, Vector3i(0, 0, 0), 0, 1, Vector3i(6, 0, 0), 0, 1)
	var mid_ok: bool = (r_mid["visible"] as bool) and str(r_mid["cover"]) == "none"
	TestFixtures.check(res, "los_sight_mid", mid_ok, _fmt(r_mid))

	var near := TestFixtures.exterior_field()
	_put_post(near, Vector3i(5, 0, 0), true)
	var r_near := _los(near, Vector3i(0, 0, 0), 0, 1, Vector3i(6, 0, 0), 0, 1)
	var near_ok: bool = (r_near["visible"] as bool) and str(r_near["cover"]) == "partial"
	TestFixtures.check(res, "los_sight_near", near_ok, _fmt(r_near))

	var shoot := TestFixtures.exterior_field()
	_put_post(shoot, Vector3i(1, 0, 0), true)
	var r_shoot := _los(shoot, Vector3i(0, 0, 0), 0, 1, Vector3i(6, 0, 0), 0, 1)
	var shoot_ok: bool = (r_shoot["visible"] as bool) and str(r_shoot["cover"]) == "none"
	TestFixtures.check(res, "los_sight_near_shooter", shoot_ok, _fmt(r_shoot))

	var diag := TestFixtures.exterior_field()
	_put_post(diag, Vector3i(6, 5, 0), true)
	_put_post(diag, Vector3i(5, 6, 0), true)
	var r_diag := _los(diag, Vector3i(5, 5, 0), 0, 1, Vector3i(6, 6, 0), 0, 1)
	TestFixtures.check(res, "los_sight_diagonal_corner", r_diag["visible"] as bool, _fmt(r_diag))

	var plain := TestFixtures.exterior_field()
	_put_post(plain, Vector3i(3, 0, 0), false)
	var r_plain := _los(plain, Vector3i(0, 0, 0), 0, 1, Vector3i(6, 0, 0), 0, 1)
	var plain_ok: bool = not (r_plain["visible"] as bool) and str(r_plain["cover"]) == "full"
	TestFixtures.check(res, "los_sight_plain_narrow", plain_ok, _fmt(r_plain))


static func _case_flyer_over_fence(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(2, 0, 0), {"cell_type": "fence", "height": FENCE_H})
	var r := _los(f, Vector3i(0, 0, 0), 2, 1, Vector3i(4, 0, 0), 0, 1)
	var ok: bool = (r["visible"] as bool) and str(r["cover"]) == "none"
	TestFixtures.check(res, "shooter at height 2 clears the fence", ok, _fmt(r))


static func _case_big_shooter(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(1, 0, 0), {"cell_type": "furniture", "height": 2.0})
	var r := _los(f, Vector3i(0, 0, 0), 0, 3, Vector3i(3, 0, 0), 0, 1)
	var small := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(3, 0, 0), 0, 1)
	var ok: bool = (r["visible"] as bool) and not (small["visible"] as bool)
	TestFixtures.check(res, "size 3 shooter sees over a height 2 obstacle", ok,
		"%s / size1 %s" % [_fmt(r), _fmt(small)])


static func _case_size2_top_only(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(5, 0, 0), {"cell_type": "furniture", "height": 2.0})
	var big := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(6, 0, 0), 0, 2)
	var small := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(6, 0, 0), 0, 1)
	var ok: bool = (big["visible"] as bool) and str(big["via"]) == "top" \
		and not (small["visible"] as bool)
	TestFixtures.check(res, "size 2 target seen only at the top point", ok,
		"%s / size1 %s" % [_fmt(big), _fmt(small)])


static func _case_terrain_ridge(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	f.terrain_heights[Vector2i(2, 0)] = 5.0
	var r := _los(f, Vector3i(0, 0, 0), 0, 1, Vector3i(4, 0, 0), 0, 1)
	var ok: bool = not (r["visible"] as bool) and str(r["blocker"]).begins_with("terrain")
	TestFixtures.check(res, "terrain ridge blocks outdoors", ok, _fmt(r))


static func _case_adjacent(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	var r := _los(f, Vector3i(5, 5, 0), 0, 1, Vector3i(6, 5, 0), 0, 1)
	TestFixtures.check(res, "orthogonal adjacency shortcut", (r["visible"] as bool) and str(r["via"]) == "adjacent", _fmt(r))


static func _case_corner(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(6, 5, 0), {"cell_type": "wall", "height": WALL_H})
	TestFixtures.put(f, Vector3i(5, 6, 0), {"cell_type": "wall", "height": WALL_H})
	var two := _los(f, Vector3i(5, 5, 0), 0, 1, Vector3i(6, 6, 0), 0, 1)
	var g := TestFixtures.exterior_field()
	TestFixtures.put(g, Vector3i(6, 5, 0), {"cell_type": "wall", "height": WALL_H})
	var one := _los(g, Vector3i(5, 5, 0), 0, 1, Vector3i(6, 6, 0), 0, 1)
	var ok: bool = not (two["visible"] as bool) and (one["visible"] as bool)
	TestFixtures.check(res, "diagonal neighbour behind two walls is blocked", ok,
		"%s / one wall %s" % [_fmt(two), _fmt(one)])


static func _case_doors(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	var door := TestFixtures.put(f, Vector3i(2, 0, 0), {"cell_type": "door", OpenCloseState.KEY: false, "height": WALL_H})
	var st := BattleState.new()
	st.battlefield = f
	var closed := LineOfSight._cached(st, Vector3i(0, 0, 0), 0, 1, Vector3i(4, 0, 0), 0, 1)
	TestFixtures.check(res, "closed door blocks", not (closed["visible"] as bool), _fmt(closed))
	OpenCloseState.set_open(door, true)
	f.los_version += 1
	var opened := LineOfSight._cached(st, Vector3i(0, 0, 0), 0, 1, Vector3i(4, 0, 0), 0, 1)
	var ok: bool = (opened["visible"] as bool) and str(opened["cover"]) == "none"
	TestFixtures.check(res, "open door clears and bumping los_version drops the cache", ok, _fmt(opened))


static func _case_slab(res: Dictionary) -> void:
	var f := TestFixtures.interior_field({0: 0, 1: 3})
	var r := _los(f, Vector3i(2, 5, 0), 0, 1, Vector3i(5, 5, 1), 0, 1)
	var ok: bool = not (r["visible"] as bool) and str(r["blocker"]).begins_with("slab")
	TestFixtures.check(res, "slab blocks F0 to F1", ok, _fmt(r))


static func _case_stairwell(res: Dictionary) -> void:
	var f := TestFixtures.interior_field({0: 0, 1: 3})
	f.stair_run_cells[Vector3i(5, 5, 1)] = true
	var r := _los(f, Vector3i(2, 5, 0), 0, 1, Vector3i(5, 5, 1), 0, 1)
	TestFixtures.check(res, "stairwell opening lets F0 see F1", r["visible"] as bool, _fmt(r))


static func _case_balcony(res: Dictionary) -> void:
	var f := TestFixtures.interior_field({0: 0, 1: 3})
	f.building_interiors[Vector3i(10, 5, 1)] = true
	var r := _los(f, Vector3i(10, 5, 1), 0, 1, Vector3i(14, 5, 0), 0, 1)
	TestFixtures.check(res, "balcony sees the street", r["visible"] as bool, _fmt(r))


static func _case_basement(res: Dictionary) -> void:
	var f := TestFixtures.interior_field({-1: 0, 0: 3})
	var fa_ok: bool = LineOfSight._floor_at(f, 1.5) == -1 and LineOfSight._floor_at(f, 4.0) == 0 \
		and LineOfSight._floor_at(f, -1.0) == -1
	TestFixtures.check(res, "_floor_at picks the basement below F0", fa_ok,
		"z1.5=%d z4.0=%d z-1.0=%d" % [LineOfSight._floor_at(f, 1.5), LineOfSight._floor_at(f, 4.0),
			LineOfSight._floor_at(f, -1.0)])
	var blocked := _los(f, Vector3i(2, 5, -1), 0, 1, Vector3i(5, 5, 0), 0, 1)
	var g := TestFixtures.interior_field({-1: 0, 0: 3})
	g.stair_run_cells[Vector3i(5, 5, 0)] = true
	var open := _los(g, Vector3i(2, 5, -1), 0, 1, Vector3i(5, 5, 0), 0, 1)
	var ok: bool = not (blocked["visible"] as bool) and (open["visible"] as bool)
	TestFixtures.check(res, "basement F-1 blocked by the F0 slab, open at the stairs", ok,
		"%s / stairs %s" % [_fmt(blocked), _fmt(open)])


#Straight run on F1 at x 4..6 from y 2 (elevation 0) up to y 8 (elevation 3), three cells wide.
static func _stair_run() -> BattlefieldArea:
	var f := TestFixtures.interior_field({0: 0, 1: 3})
	f.stair_runs[1] = [{"sx": 5, "ly": 2, "uy": 8}]
	_fill_stair_run(f, 1)
	return f


#Marks the run cells x 4..6, y 2..8 on floor_num as stair run cells.
static func _fill_stair_run(f: BattlefieldArea, floor_num: int) -> void:
	for x: int in range(4, 7):
		for y: int in range(2, 9):
			f.stair_run_cells[Vector3i(x, y, floor_num)] = true


static func _case_stair_run(res: Dictionary) -> void:
	var f := _stair_run()
	var e_ok: bool = is_equal_approx(f.cell_base_elevation(Vector2i(5, 5), 1), 1.5) \
		and is_equal_approx(f.cell_base_elevation(Vector2i(5, 2), 1), 0.0) \
		and is_equal_approx(f.cell_base_elevation(Vector2i(5, 8), 1), 3.0)
	TestFixtures.check(res, "stair run interpolates 0 to 3", e_ok, "mid=%.2f" % f.cell_base_elevation(Vector2i(5, 5), 1))
	var bottom := _los(f, Vector3i(5, 1, 0), 0, 1, Vector3i(5, 5, 1), 0, 1)
	TestFixtures.check(res, "bottom of the stairs sees a merc halfway up", bottom["visible"] as bool, _fmt(bottom))
	var top := _los(f, Vector3i(5, 9, 1), 0, 1, Vector3i(5, 5, 1), 0, 1)
	TestFixtures.check(res, "top landing sees a merc halfway up", top["visible"] as bool, _fmt(top))
	var beside := _los(f, Vector3i(8, 5, 1), 0, 1, Vector3i(5, 5, 1), 0, 1)
	TestFixtures.check(res, "F1 beside the well sees a merc halfway up", beside["visible"] as bool, _fmt(beside))
	var up := _los(f, Vector3i(5, 1, 0), 0, 1, Vector3i(5, 9, 1), 0, 1)
	TestFixtures.check(res, "bottom of the stairs sees the top landing", up["visible"] as bool, _fmt(up))
	var down := _los(f, Vector3i(5, 5, 1), 0, 1, Vector3i(5, 0, 0), 0, 1)
	TestFixtures.check(res, "merc halfway up sees the ground floor below", down["visible"] as bool, _fmt(down))
	var under := _los(f, Vector3i(5, 7, 0), 0, 1, Vector3i(5, 3, 1), 0, 1)
	var under_ok: bool = not (under["visible"] as bool) and str(under["blocker"]).begins_with("stairs")
	TestFixtures.check(res, "under the stairs cannot see through the steps", under_ok, _fmt(under))
	var across := _los(f, Vector3i(2, 6, 0), 0, 1, Vector3i(8, 6, 0), 0, 1)
	TestFixtures.check(res, "two mercs under the stairs see each other", across["visible"] as bool, _fmt(across))
	var low := _los(f, Vector3i(2, 4, 0), 0, 1, Vector3i(8, 4, 0), 0, 1)
	var low_ok: bool = not (low["visible"] as bool) and str(low["blocker"]).begins_with("stairs")
	TestFixtures.check(res, "the low end of the run blocks a ground floor ray at eye height", low_ok, _fmt(low))
	var to_top := _los(f, Vector3i(5, 6, 0), 0, 1, Vector3i(5, 8, 1), 0, 1)
	var to_top_ok: bool = not (to_top["visible"] as bool) and str(to_top["blocker"]).begins_with("stairs")
	TestFixtures.check(res, "a merc under the stairs cannot see the top landing through the steps", to_top_ok, _fmt(to_top))
	var rv := TestFixtures.interior_field({0: 0, 1: 3})
	rv.stair_runs[1] = [{"sx": 5, "ly": 2, "uy": 8, "up": -1}]
	_fill_stair_run(rv, 1)
	var rv_e: bool = is_equal_approx(rv.cell_base_elevation(Vector2i(5, 8), 1), 0.0) and is_equal_approx(rv.cell_base_elevation(Vector2i(5, 2), 1), 3.0)
	TestFixtures.check(res, "reversed run interpolates 3 down to 0", rv_e, "y8=%.2f" % rv.cell_base_elevation(Vector2i(5, 8), 1))
	var rv_b := _los(rv, Vector3i(5, 9, 0), 0, 1, Vector3i(5, 5, 1), 0, 1)
	TestFixtures.check(res, "bottom of the reversed stairs sees a merc halfway up", rv_b["visible"] as bool, _fmt(rv_b))
	var g := TestFixtures.interior_field({0: 0, 1: 3, 2: 6})
	g.stair_runs[2] = [{"sx": 5, "ly": 2, "uy": 8}]
	_fill_stair_run(g, 2)
	var far_below := _los(g, Vector3i(2, 6, 0), 0, 1, Vector3i(8, 6, 0), 0, 1)
	TestFixtures.check(res, "a staircase two floors up leaves the ground floor open", far_below["visible"] as bool, _fmt(far_below))

#A size-2 merc whose head touches the underside of a tread sees the merc standing under it, and back.
static func _case_under_stairs(res: Dictionary) -> void:
	var f := _stair_run()
	var down := _los(f, Vector3i(3, 7, 0), 0, 2, Vector3i(5, 7, 0), 0, 1)
	var back := _los(f, Vector3i(5, 7, 0), 0, 1, Vector3i(3, 7, 0), 0, 2)
	var ok: bool = (down["visible"] as bool) and (back["visible"] as bool)
	TestFixtures.check(res, "head under a tread sees the merc beneath the stairs both ways", ok,
		"%s / back %s" % [_fmt(down), _fmt(back)])
	var through := _los(f, Vector3i(3, 7, 0), 0, 2, Vector3i(5, 8, 1), 0, 1)
	var t_ok: bool = not (through["visible"] as bool) and str(through["blocker"]).begins_with("stairs")
	TestFixtures.check(res, "a ray rising through a tread stays blocked", t_ok, _fmt(through))


#A one storey shell under a flat roof at level 1, plane 3; the city variant hands the cells to building 0.
static func _roof_map(exterior: bool, city: bool) -> BattlefieldArea:
	var f: BattlefieldArea = TestFixtures.exterior_field() if exterior else TestFixtures.interior_field({0: 0, 1: 3})
	if not exterior:
		f.interior_floor_elevations = {0: 0}
	for x: int in range(0, 10):
		for y: int in range(0, 10):
			f.roof_cells[Vector3i(x, y, 1)] = RoofBuilder.FLAT
			f.roof_elevations[Vector2i(x, y)] = 3
			if city:
				f.building_id_at[Vector2i(x, y)] = 0
	if city:
		f.building_planes.append({0: 0})
		f.outdoor_planes = {0: 0}
	return f


#A roof object between two roof standers blocks the ray on every map kind, and the bare roof never does.
static func _case_roof_object(res: Dictionary) -> void:
	var from := Vector3i(2, 5, 1)
	var to := Vector3i(8, 5, 1)
	var seen: Array[String] = []
	var blocked: Array[String] = []
	for spec: Array in [["exterior", true, false], ["interior", false, false], ["city", false, true]]:
		var name: String = String(spec[0])
		var bare: BattlefieldArea = _roof_map(bool(spec[1]), bool(spec[2]))
		var clear: Dictionary = _los(bare, from, 0, 1, to, 0, 1)
		if not (clear["visible"] as bool):
			seen.append("%s bare: %s" % [name, _fmt(clear)])
		if bool(spec[1]):
			continue
		var walled: BattlefieldArea = _roof_map(bool(spec[1]), bool(spec[2]))
		TestFixtures.put(walled, Vector3i(5, 5, 1), {"cell_type": "wall", "height": 2.0})
		var hit: Dictionary = _los(walled, from, 0, 1, to, 0, 1)
		if hit["visible"] as bool:
			blocked.append("%s walled: %s" % [name, _fmt(hit)])
	TestFixtures.check(res, "roof object: bare roof planes see across on every map kind", seen.is_empty(),
		"; ".join(seen) if not seen.is_empty() else "3 map kind(s) clear")
	TestFixtures.check(res, "roof object: a wall on the roof level blocks on interior and city maps", blocked.is_empty(),
		"; ".join(blocked) if not blocked.is_empty() else "2 map kind(s) blocked")
