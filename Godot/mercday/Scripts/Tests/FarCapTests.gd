class_name FarCapTests

#The PathTargeter approach flood cap on bare flat fields: how far one capped growth settles, what it
#then aims at, and when it gives the cap up. CityTests.run() calls run_cases.

const FAR_DIM := 60
const FAR_START := Vector3i(2, 2, 0)
const FAR_MID := Vector3i(30, 30, 0)
const FAR_FOE := Vector3i(57, 57, 0)
const FAR_CAP_SMALL := 30
const FAR_CAP_TURN := 100
const FAR_WALL_X := 11
const FAR_WALL_LEN := 40
const FAR_WALLED := Vector3i(10, 10, 0)
const FAR_BOX := Vector3i(20, 20, 0)
const FAR_BOX_CELLS := 3
const FAR_WIDE_DIM := 100
const FAR_SMALL_DIM := 30
const FAR_SMALL_FOE := Vector3i(27, 27, 0)


#The approach flood cap: a capped growth stops short and aims at the frontier it settled, and gives the
#cap up for good when nothing it settled stands nearer the ring than the mover already does.
static func run_cases(res: Dictionary) -> void:
	PathCost.set_door_penalty(0)
	PathCost.set_water_cost(null, null)
	PathCost.clear_climb()
	ReachCache.clear_caches()
	ReachCache.far_cap_override = -1
	_case_capped_growth(res)
	_case_walled_off(res)
	_case_cap_scales(res)
	_case_boxed_in(res)
	_case_wide_floor(res)
	_case_small_uncapped(res)
	ReachCache.clear_caches()
	PathCost.set_door_penalty(-1)


static func _case_capped_growth(res: Dictionary) -> void:
	var open_map: BattlefieldArea = TestFixtures.exterior_field(FAR_DIM)
	var ring := Vector3i(FAR_FOE.x - 1, FAR_FOE.y - 1, 0)
	var listed: Array[Vector3i] = [ring]

	var short_flood: ReachSearch = _far_flood(open_map, FAR_START)
	short_flood.ensure_cells(listed, -1, ReachCache.RING_SLACK, FAR_CAP_SMALL)
	var full_flood: ReachSearch = _far_flood(open_map, FAR_START)
	full_flood.ensure_cells(listed, -1, ReachCache.RING_SLACK)
	TestFixtures.check(res, "city_far a capped growth stops on its settled bound",
		short_flood.capped and short_flood.result.size() <= FAR_CAP_SMALL
		and not short_flood.result.has(ring),
		"%d of %d cell(s)" % [short_flood.result.size(), FAR_CAP_SMALL])
	TestFixtures.check(res, "city_far the same growth with no cap settles the listed cell",
		not full_flood.capped and full_flood.result.has(ring)
		and full_flood.result.size() > FAR_CAP_SMALL,
		"%d cell(s), listed %s" % [full_flood.result.size(), str(full_flood.result.has(ring))])

	var frontier: Vector3i = short_flood.nearest_settled_to(listed)
	var start_gap: int = short_flood.box_distance(FAR_START, listed)
	var frontier_gap: int = short_flood.box_distance(frontier, listed)
	TestFixtures.check(res, "city_far the capped flood names a frontier nearer the listed cell",
		frontier != PathTargeter.NO_CELL and not short_flood.walk_path(frontier).is_empty()
		and frontier_gap < start_gap,
		"frontier %s at %d, start at %d" % [str(frontier), frontier_gap, start_gap])

	var walker: MercenaryData = _far_merc("Far Walker")
	var foe: MercenaryData = _far_merc("Far Foe")
	var open_st: BattleState = _far_state(open_map, walker, foe, FAR_START, FAR_FOE)
	ReachCache.far_cap_override = FAR_CAP_TURN
	var goal: Vector3i = PathTargeter.best_approach_cell(walker, foe, open_st)
	var walk: Array[Vector3i] = ReachCache.walk_path_for(walker, open_st, FAR_START, goal)
	var goal_gap: int = ReachCache.far_box_distance(walker, open_st, goal, listed)
	TestFixtures.check(res, "city_far a capped approach heads for the frontier it settled",
		goal != PathTargeter.NO_CELL and not walk.is_empty() and not open_st.far_full.has(walker)
		and (open_st.move_goals.get(walker, PathTargeter.NO_CELL) as Vector3i) == goal
		and (open_st.move_targets.get(walker) as MercenaryData) == foe and goal_gap < start_gap,
		"goal %s at %d, %d step(s)" % [str(goal), goal_gap, walk.size()])
	ReachCache.far_cap_override = -1


static func _case_walled_off(res: Dictionary) -> void:
	ReachCache.clear_caches()
	ReachCache.far_cap_override = FAR_CAP_TURN
	var wall_map: BattlefieldArea = TestFixtures.exterior_field(FAR_DIM)
	for y: int in range(0, FAR_WALL_LEN + 1):
		TestFixtures.put(wall_map, Vector3i(FAR_WALL_X, y, 0), {"cell_type": "wall", "height": 4.0})
	for x: int in range(1, FAR_WALL_LEN + 1):
		TestFixtures.put(wall_map, Vector3i(x, FAR_WALL_X, 0), {"cell_type": "wall", "height": 4.0})
	var walled: MercenaryData = _far_merc("Far Walled")
	var walled_foe: MercenaryData = _far_merc("Far Walled Foe")
	var wall_st: BattleState = _far_state(wall_map, walled, walled_foe, FAR_WALLED, FAR_FOE)
	var wall_goal: Vector3i = PathTargeter.best_approach_cell(walled, walled_foe, wall_st)
	TestFixtures.check(res, "city_far a mover walled off the ring drops its cap and still gets a goal",
		wall_st.far_full.has(walled) and wall_goal != PathTargeter.NO_CELL and wall_goal != FAR_WALLED,
		"goal %s, uncapped %s" % [str(wall_goal), str(wall_st.far_full.has(walled))])
	ReachCache.far_cap_override = -1


static func _case_cap_scales(res: Dictionary) -> void:
	ReachCache.clear_caches()
	var mid_map: BattlefieldArea = TestFixtures.exterior_field(FAR_DIM)
	var scaler: MercenaryData = _far_merc("Far Scaler")
	var scale_foe: MercenaryData = _far_merc("Far Scale Foe")
	var mid_st: BattleState = _far_state(mid_map, scaler, scale_foe, FAR_MID, FAR_FOE)
	var mid_reach: Dictionary = ReachCache.reachable_for(scaler, mid_st)
	var mid_budget: int = ReachCache.reach_budget(scaler, mid_st)
	var mid_walk: int = 0
	for key: Variant in mid_reach.keys():
		var mid_cost: int = mid_reach[key] as int
		if mid_cost < PathTargeter.JUMP_COST_OFFSET and mid_cost <= mid_budget:
			mid_walk += 1
	var mid_cap: int = ReachCache.far_cap_for(scaler, mid_st)
	var mid_floor: int = ReachCache.cap_floor_of(ReachCache.walk_cells_of(mid_map))
	TestFixtures.check(res, "city_far the cap scales with the flood of the mover's own turn",
		mid_cap == maxi(mid_floor, ReachCache.FAR_CAP_MULT * mid_walk),
		"%d cell(s), cap %d" % [mid_walk, mid_cap])


static func _case_boxed_in(res: Dictionary) -> void:
	var box_map: BattlefieldArea = TestFixtures.exterior_field(FAR_DIM)
	_box_in(box_map, FAR_BOX)
	var boxed: MercenaryData = _far_merc("Far Boxed")
	var boxed_foe: MercenaryData = _far_merc("Far Boxed Foe")
	var box_st: BattleState = _far_state(box_map, boxed, boxed_foe, FAR_BOX, FAR_FOE)
	var box_reach: int = ReachCache.reachable_for(boxed, box_st).size()
	var box_cap: int = ReachCache.far_cap_for(boxed, box_st)
	var box_floor: int = ReachCache.cap_floor_of(ReachCache.walk_cells_of(box_map))
	TestFixtures.check(res, "city_far a mover boxed in keeps the floor of the cap",
		box_reach == FAR_BOX_CELLS and box_cap == box_floor,
		"%d cell(s), cap %d" % [box_reach, box_cap])


static func _case_wide_floor(res: Dictionary) -> void:
	ReachCache.clear_caches()
	var wide_map: BattlefieldArea = TestFixtures.exterior_field(FAR_WIDE_DIM)
	_box_in(wide_map, FAR_BOX)
	var wide: MercenaryData = _far_merc("Far Wide")
	var wide_foe: MercenaryData = _far_merc("Far Wide Foe")
	var wide_st: BattleState = _far_state(wide_map, wide, wide_foe, FAR_BOX, FAR_FOE)
	var wide_cells: int = ReachCache.walk_cells_of(wide_map)
	var wide_cap: int = ReachCache.far_cap_for(wide, wide_st)
	TestFixtures.check(res, "city_far the cap floor grows with the standable cells of a wide map",
		wide_cells > ReachCache.FAR_CAP_CELLS and wide_cap > ReachCache.FAR_CAP_MIN
		and wide_cap == ReachCache.cap_floor_of(wide_cells),
		"%d cell(s), cap %d" % [wide_cells, wide_cap])


static func _case_small_uncapped(res: Dictionary) -> void:
	ReachCache.clear_caches()
	var small_map: BattlefieldArea = TestFixtures.exterior_field(FAR_SMALL_DIM)
	var small: MercenaryData = _far_merc("Far Small")
	var small_foe: MercenaryData = _far_merc("Far Small Foe")
	var small_st: BattleState = _far_state(small_map, small, small_foe, FAR_START, FAR_SMALL_FOE)
	var small_cells: int = ReachCache.walk_cells_of(small_map)
	var small_cap: int = ReachCache.far_cap_for(small, small_st)
	var small_goal: Vector3i = PathTargeter.best_approach_cell(small, small_foe, small_st)
	TestFixtures.check(res, "city_far a map under the cell threshold floods with no cap",
		small_cells <= ReachCache.FAR_CAP_CELLS and small_cap == -1 and small_goal != PathTargeter.NO_CELL
		and not small_st.far_full.has(small) and not ReachCache.far_capped(small, small_st),
		"%d cell(s), cap %d, goal %s" % [small_cells, small_cap, str(small_goal)])


#Walls the cells around at into a pocket of FAR_BOX_CELLS free cells, leaving the row at stands on open.
static func _box_in(map: BattlefieldArea, at: Vector3i) -> void:
	for dx: int in range(-1, FAR_BOX_CELLS + 1):
		for dy: int in range(-1, 2):
			if dy == 0 and dx >= 0 and dx < FAR_BOX_CELLS:
				continue
			TestFixtures.put(map, Vector3i(at.x + dx, at.y + dy, 0), {"cell_type": "wall", "height": 4.0})


#Bare walker: no weapon, so its ring is the cells around the target, and no climb or jump.
static func _far_merc(merc_name: String) -> MercenaryData:
	var overrides: Dictionary = {"climb": 0, "melee_accuracy": 8.0, "ranged_accuracy": 1.0}
	return TestFixtures.flat_merc(merc_name, overrides)


#One walker against one enemy, each alone on its own team and on the ground floor.
static func _far_state(field: BattlefieldArea, walker: MercenaryData, foe: MercenaryData,
		at: Vector3i, foe_at: Vector3i) -> BattleState:
	var st := BattleState.new()
	st.battlefield = field
	st.teams = [[walker], [foe]]
	st._merc_team_index[walker] = 0
	st._merc_team_index[foe] = 1
	st.set_pos3(walker, at)
	st.set_pos3(foe, foe_at)
	return st


#A bare walking flood: no jumping and no climbing, so only a cap or the map stops it.
static func _far_flood(field: BattlefieldArea, at: Vector3i) -> ReachSearch:
	return ReachSearch.create(at, field, {}, 1.0, false, false, 0, 1, 0)
