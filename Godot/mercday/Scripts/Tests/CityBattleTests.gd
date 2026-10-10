class_name CityBattleTests
extends RefCounted

#City battle set-up: the placed teams of a city encounter and the city lines of the generation block.
#CityTests.run() calls run_cases.

const MAP_TIER := "Small"
const MAP_SEED := 7301
const TEAM_SIZE := 3
const WARM_JUMP := 2


static func run_cases(res: Dictionary) -> void:
	var map: BattlefieldArea = _map()
	var state: BattleState = _state(map)
	_case_runs(res, map, state)
	_case_placed(res, map, state)
	_case_log_summary(res, map)
	_case_not_interior(res, map)
	_case_warm_jumps(res, map)
	_case_door_bump(res, map)


#The Small map of the case seed; generate_random always returns a field for the City branch.
static func _map() -> BattlefieldArea:
	return TestFixtures.city_gen(MAP_TIER, MAP_SEED, CityGenTests.ROW)


static func _state(map: BattlefieldArea) -> BattleState:
	var teams: Array = GenFixtures.rival_teams("CA", "CB", TEAM_SIZE, TestFixtures.city_melee)
	return BattleState.create(teams[0], teams[1], map)


#The rounds themselves stay out: AutoBattle.step_round is a coroutine and this suite is synchronous.
static func _case_runs(res: Dictionary, map: BattlefieldArea, state: BattleState) -> void:
	var was: bool = EncounterLogger.suppressed
	EncounterLogger.suppressed = true
	AutoBattle.setup(state, Callable(), "city")
	EncounterLogger.suppressed = was
	CriticalSuccessSystem.banking = false
	var ok: bool = true
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			var pos: Vector2i = state.get_position(merc)
			if not map.in_bounds_xy(pos.x, pos.y):
				ok = false
	TestFixtures.check(res, "citybattle_runs", ok,
		"rounds=%d winner=%d" % [state.round_number, state.get_winner()])


static func _case_placed(res: Dictionary, map: BattlefieldArea, state: BattleState) -> void:
	var bad: Array[String] = []
	var taken: Dictionary = {}
	var total: int = 0
	for team: Array in state.teams:
		for merc: MercenaryData in team:
			total += 1
			if not state.positions.has(merc):
				bad.append("%s holds no position" % merc.merc_name)
				continue
			var pos: Vector2i = state.get_position(merc)
			var fl: int = state.get_floor(merc)
			var key := Vector3i(pos.x, pos.y, fl)
			if taken.has(key):
				bad.append("%s shares cell %d,%d floor %d" % [merc.merc_name, pos.x, pos.y, fl])
			taken[key] = true
			if fl == 0 and not CityAccess.is_ground(map, pos) and not map.in_footprint(pos):
				bad.append("%s stands at %d,%d off the open ground" % [merc.merc_name, pos.x, pos.y])
	TestFixtures.check(res, "citybattle_placed", bad.is_empty(),
		TestFixtures.detail(bad, total, "merc(s)"))


static func _case_log_summary(res: Dictionary, map: BattlefieldArea) -> void:
	var lines: PackedStringArray = BattlefieldSummary.city_lines(map)
	var bad: Array[String] = []
	if lines.size() != 2:
		bad.append("%d line(s) of 2" % lines.size())
	else:
		if not lines[0].begins_with("City: tier=%s" % MAP_TIER):
			bad.append("line 1 reads '%s'" % lines[0])
		if not lines[1].begins_with("City spawn: A side="):
			bad.append("line 2 reads '%s'" % lines[1])
		var want: int = int((map.city.get("stats", {}) as Dictionary).get("buildings", -1))
		var got: int = _field_int(lines[0], "buildings=")
		if got != want:
			bad.append("buildings=%d of %d" % [got, want])
	TestFixtures.check(res, "citybattle_log_summary", bad.is_empty(),
		"ok" if bad.is_empty() else bad[0])


#The number that follows label on line; -1 when the label is missing.
static func _field_int(line: String, label: String) -> int:
	var at: int = line.find(label)
	if at < 0:
		return -1
	return line.substr(at + label.length()).get_slice(" ", 0).to_int()


static func _case_not_interior(res: Dictionary, map: BattlefieldArea) -> void:
	var bad: Array[String] = []
	for line: String in BattlefieldSummary.city_lines(map):
		if line.contains("Buildings: interior"):
			bad.append(line)
	TestFixtures.check(res, "citybattle_not_interior_label", bad.is_empty(),
		"ok" if bad.is_empty() else bad[0])


static func _case_warm_jumps(res: Dictionary, map: BattlefieldArea) -> void:
	map.bump_path_version()
	ReachCache.clear_caches()
	var plain: BattleState = _state(map)
	var plain_n: int = ReachCache.warm_jumps(plain)
	TestFixtures.check(res, "citybattle_warm_none", plain_n == 0 and map.jump_geom.is_empty(),
		"warmed %d, geom %d" % [plain_n, map.jump_geom.size()])
	var teams: Array = GenFixtures.rival_teams("CJ", "CK", TEAM_SIZE, TestFixtures.city_melee)
	var jumper: MercenaryData = (teams[0] as Array)[0] as MercenaryData
	jumper.stats["jump"] = WARM_JUMP
	var st: BattleState = BattleState.create(teams[0], teams[1], map)
	var geom_after_create: int = map.jump_geom.size()
	var slots_after_create: int = ReachCache.reach_slots.size()
	var warm_n: int = ReachCache.warm_jumps(st)
	TestFixtures.check(res, "citybattle_warm_jumps",
		warm_n == 1 and geom_after_create > 0 and slots_after_create == 0 and ReachCache.reach_slots.is_empty(),
		"warmed %d, geom %d, slots %d" % [warm_n, geom_after_create, slots_after_create])
	var reach: Dictionary = ReachCache.reachable_for(jumper, st)
	TestFixtures.check(res, "citybattle_warm_reach", not reach.is_empty() and map.jump_geom.size() >= geom_after_create,
		"%d cell(s), geom %d" % [reach.size(), map.jump_geom.size()])
	ReachCache.clear_caches()
	map.bump_path_version()


static func _case_door_bump(res: Dictionary, map: BattlefieldArea) -> void:
	map.bump_path_version()
	ReachCache.clear_caches()
	var st: BattleState = _state(map)
	var mover: MercenaryData = (st.teams[0] as Array)[0] as MercenaryData
	ReachCache.reachable_for(mover, st)
	var first: ReachSearch = (ReachCache.reach_slots[mover] as Dictionary)["search"] as ReachSearch
	ReachCache.reachable_for(mover, st)
	var same: ReachSearch = (ReachCache.reach_slots[mover] as Dictionary)["search"] as ReachSearch
	var neigh_before: int = map.neighbor_cache.size()
	var static_before: int = map.path_static.size()
	map.bump_door_version()
	ReachCache.reachable_for(mover, st)
	var fresh: ReachSearch = (ReachCache.reach_slots[mover] as Dictionary)["search"] as ReachSearch
	TestFixtures.check(res, "citybattle_door_bump",
		same == first and fresh != first and neigh_before > 0
		and map.neighbor_cache.size() >= neigh_before and map.path_static.size() >= static_before,
		"neigh %d -> %d, static %d -> %d" % [neigh_before, map.neighbor_cache.size(), static_before,
			map.path_static.size()])
	map.bump_path_version()
	TestFixtures.check(res, "citybattle_geometry_bump",
		map.neighbor_cache.is_empty() and map.path_static.is_empty(),
		"neigh %d, static %d" % [map.neighbor_cache.size(), map.path_static.size()])
	ReachCache.clear_caches()
