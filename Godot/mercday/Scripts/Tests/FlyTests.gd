class_name FlyTests

#Deterministic flight cases. Run: godot --headless --path . -- --fly-tests
#No randomness: every field is built cell by cell and asserted against a hand computed cost.

const TABLE_H := 1.0


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_table_cost(res)
	_case_band_budget(res)
	_case_absolute_height(res)
	return TestFixtures.summarize(res, "FLY")


#Interior shell 10x10 at the origin with a basement at 0 and the ground floor at 3.
static func _basement() -> BattlefieldArea:
	var f := BattlefieldArea.new()
	f.width = 24
	f.length = 24
	f.height = 24
	f.is_interior_map = true
	f.building_footprint = Rect2i(0, 0, 10, 10)
	f.interior_floor_elevations = {-1: 0, 0: 3}
	return f


#Pace cost of a fixed route for a Size 1 flyer, altitude carried from cell to cell.
static func _route_cost(f: BattlefieldArea, cells: Array[Vector3i], altitude: int) -> int:
	var total := 0
	var alt := altitude
	for i: int in range(1, cells.size()):
		var c := PathCost.cell_pace_cost(cells[i - 1], cells[i], f, {}, 1.0, true, true, 1, alt)
		if c < 0:
			return -1
		total += c
		alt = PathCost.fly_arrival_altitude(cells[i - 1], cells[i], f, alt)
	return total


static func _case_table_cost(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	TestFixtures.put(f, Vector3i(1, 0, 0), {"cell_type": "furniture", "height": TABLE_H})
	TestFixtures.put(f, Vector3i(2, 0, 0), {"cell_type": "furniture", "height": TABLE_H})
	var route: Array[Vector3i] = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	var c0 := _route_cost(f, route, 0)
	var c1 := _route_cost(f, route, 1)
	var arrival := PathCost.fly_arrival_altitude(Vector3i(0, 0, 0), Vector3i(1, 0, 0), f, 0)
	TestFixtures.check(res, "table 1 high 2 long costs 3 from the ground", c0 == 3, "cost=%d" % c0)
	TestFixtures.check(res, "the same table costs 2 from altitude 1", c1 == 2, "cost=%d" % c1)
	TestFixtures.check(res, "altitude rises to the table top on entry", arrival == 1, "alt=%d" % arrival)


static func _case_band_budget(res: Dictionary) -> void:
	var f := TestFixtures.exterior_field()
	for x: int in [2, 3, 4]:
		TestFixtures.put(f, Vector3i(x, 0, 0), {"cell_type": "furniture", "height": TABLE_H})
	var path: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0),
		Vector3i(3, 0, 0), Vector3i(4, 0, 0), Vector3i(5, 0, 0),
	]
	var free := func(_c: Vector3i) -> bool: return true
	var entry := PathCost.cell_pace_cost(path[1], path[2], f, {}, 1.0, true, true, 1, 0)
	var need := MovementExecutor.fly_band_paces(path, 2, entry, f, {}, 1.0, true, 1, 0, free)
	TestFixtures.check(res, "band of 3 needs 5 paces to clear", need == 5, "need=%d entry=%d" % [need, entry])
	TestFixtures.check(res, "a budget of 1 cannot enter the band", need > 1, "need=%d budget=1" % need)
	TestFixtures.check(res, "a budget of 5 clears the band", need <= 5, "need=%d budget=5" % need)
	var halt: Vector3i = path[1]
	var halt_ok: bool = PathHelper.is_standable(halt, f, 1) and halt != path[0]
	TestFixtures.check(res, "the halt cell before the band is standable and not the start", halt_ok,
		"halt=(%d,%d)" % [halt.x, halt.y])


static func _case_absolute_height(res: Dictionary) -> void:
	var f := _basement()
	var st := BattleState.new()
	st.battlefield = f
	var m := MercenaryData.new()
	st.positions[m] = Vector2i(5, 5)
	st.floors[m] = -1
	var basement := st.absolute_height(m)
	st.floors[m] = 0
	var ground := st.absolute_height(m)
	st.set_height(m, 2)
	var raised := st.absolute_height(m)
	var g := TestFixtures.exterior_field()
	g.terrain_heights[Vector2i(4, 4)] = 2.0
	var st2 := BattleState.new()
	st2.battlefield = g
	var m2 := MercenaryData.new()
	st2.positions[m2] = Vector2i(4, 4)
	var ridge := st2.absolute_height(m2)
	TestFixtures.check(res, "basement F-1 prints -3", basement == -3, "h=%d" % basement)
	TestFixtures.check(res, "ground floor prints 0", ground == 0, "h=%d" % ground)
	TestFixtures.check(res, "ground floor at altitude 2 prints 2", raised == 2, "h=%d" % raised)
	TestFixtures.check(res, "a 2 pace terrain cell prints 2", ridge == 2, "h=%d" % ridge)
