class_name CityBattleTests
extends RefCounted

#City battle set-up: the placed teams of a city encounter, the city lines of the generation block and
#the spawn zone guard of the generic branch. CityGenTests.run_cases calls run_cases.

const MAP_TIER := "Small"
const MAP_SEED := 7301
const GENERIC_SEED := 7401
const TEAM_SIZE := 3
const GENERIC_TEAM := 4
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
	_case_generic_zone(res)
	_case_zone_guard(res)
	_case_split(res)


#The Small map of the case seed; generate_random always returns a field for the City branch.
static func _map() -> BattlefieldArea:
	return TestFixtures.city_gen(MAP_TIER, MAP_SEED, CityGenTests.ROW)


static func _state(map: BattlefieldArea) -> BattleState:
	var team_a: Array[MercenaryData] = []
	var team_b: Array[MercenaryData] = []
	for i: int in range(TEAM_SIZE):
		team_a.append(TestFixtures.city_melee("CA%d" % (i + 1)))
		team_b.append(TestFixtures.city_melee("CB%d" % (i + 1)))
	return BattleState.create(team_a, team_b, map)


#### Encounter setup.


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
			if pos.x < 0 or pos.x >= map.width or pos.y < 0 or pos.y >= map.length:
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


#### City lines of the generation block.


static func _case_log_summary(res: Dictionary, map: BattlefieldArea) -> void:
	var lines: PackedStringArray = EncounterLogger._city_lines(map)
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
	for line: String in EncounterLogger._city_lines(map):
		if line.contains("Buildings: interior"):
			bad.append(line)
	TestFixtures.check(res, "citybattle_not_interior_label", bad.is_empty(),
		"ok" if bad.is_empty() else bad[0])


static func _case_warm_jumps(res: Dictionary, map: BattlefieldArea) -> void:
	map.bump_path_version()
	PathTargeter.clear_caches()
	var plain: BattleState = _state(map)
	var plain_n: int = PathTargeter.warm_jumps(plain)
	TestFixtures.check(res, "citybattle_warm_none", plain_n == 0 and map.jump_geom.is_empty(),
		"warmed %d, geom %d" % [plain_n, map.jump_geom.size()])
	var team_a: Array[MercenaryData] = []
	var team_b: Array[MercenaryData] = []
	for i: int in range(TEAM_SIZE):
		team_a.append(TestFixtures.city_melee("CJ%d" % (i + 1)))
		team_b.append(TestFixtures.city_melee("CK%d" % (i + 1)))
	team_a[0].stats["jump"] = WARM_JUMP
	var st: BattleState = BattleState.create(team_a, team_b, map)
	var geom_after_create: int = map.jump_geom.size()
	var slots_after_create: int = PathTargeter._reach_slots.size()
	var warm_n: int = PathTargeter.warm_jumps(st)
	TestFixtures.check(res, "citybattle_warm_jumps",
		warm_n == 1 and geom_after_create > 0 and slots_after_create == 0 and PathTargeter._reach_slots.is_empty(),
		"warmed %d, geom %d, slots %d" % [warm_n, geom_after_create, slots_after_create])
	var reach: Dictionary = PathTargeter.reachable_for(team_a[0], st)
	TestFixtures.check(res, "citybattle_warm_reach", not reach.is_empty() and map.jump_geom.size() >= geom_after_create,
		"%d cell(s), geom %d" % [reach.size(), map.jump_geom.size()])
	PathTargeter.clear_caches()
	map.bump_path_version()


static func _case_door_bump(res: Dictionary, map: BattlefieldArea) -> void:
	map.bump_path_version()
	PathTargeter.clear_caches()
	var st: BattleState = _state(map)
	var mover: MercenaryData = (st.teams[0] as Array)[0] as MercenaryData
	PathTargeter.reachable_for(mover, st)
	var first: ReachSearch = (PathTargeter._reach_slots[mover] as Dictionary)["search"] as ReachSearch
	PathTargeter.reachable_for(mover, st)
	var same: ReachSearch = (PathTargeter._reach_slots[mover] as Dictionary)["search"] as ReachSearch
	var neigh_before: int = map.neighbor_cache.size()
	var static_before: int = map.path_static.size()
	map.bump_door_version()
	PathTargeter.reachable_for(mover, st)
	var fresh: ReachSearch = (PathTargeter._reach_slots[mover] as Dictionary)["search"] as ReachSearch
	TestFixtures.check(res, "citybattle_door_bump",
		same == first and fresh != first and neigh_before > 0
		and map.neighbor_cache.size() >= neigh_before and map.path_static.size() >= static_before,
		"neigh %d -> %d, static %d -> %d" % [neigh_before, map.neighbor_cache.size(), static_before,
			map.path_static.size()])
	map.bump_path_version()
	TestFixtures.check(res, "citybattle_geometry_bump",
		map.neighbor_cache.is_empty() and map.path_static.is_empty(),
		"neigh %d, static %d" % [map.neighbor_cache.size(), map.path_static.size()])
	PathTargeter.clear_caches()


#### Spawn zones and harness split.


static func _case_generic_zone(res: Dictionary) -> void:
	seed(GENERIC_SEED)
	var map: BattlefieldArea = BattlefieldArea.generate_random()
	var team_a: Array[MercenaryData] = []
	var team_b: Array[MercenaryData] = []
	for i: int in range(GENERIC_TEAM):
		team_a.append(TestFixtures.city_melee("GA%d" % (i + 1)))
		team_b.append(TestFixtures.city_melee("GB%d" % (i + 1)))
	var state: BattleState = BattleState.create(team_a, team_b, map)
	var rosters: Array = [team_a, team_b]
	var zones: Array[Dictionary] = [map.spawn_zone_a, map.spawn_zone_b]
	var counts: Array[int] = [0, 0]
	var used: Array[bool] = [false, false]
	var bad: Array[String] = []
	for t: int in range(2):
		var zone: Dictionary = zones[t]
		for merc: MercenaryData in (rosters[t] as Array):
			if state.get_floor(merc) == 0 and zone.has(state.get_position(merc)):
				counts[t] += 1
		used[t] = not zone.is_empty() and counts[t] > 0
		if used[t] and counts[t] != (rosters[t] as Array).size():
			bad.append("team %d holds %d of %d merc(s) in its zone"
				% [t, counts[t], (rosters[t] as Array).size()])
	if not map.is_interior_map and not (used[0] and used[1]):
		bad.append("exterior map left a generated zone unused")
	var detail: String = "zone unused"
	if used[0] or used[1]:
		detail = "a=%d/%d b=%d/%d" % [counts[0], team_a.size(), counts[1], team_b.size()]
	TestFixtures.check(res, "citybattle_generic_zone", bad.is_empty(),
		detail if bad.is_empty() else "%s; %s" % [detail, bad[0]])


static func _case_zone_guard(res: Dictionary) -> void:
	var zone: Dictionary = {Vector2i(1, 1): true}
	var kept: Dictionary = SpawnPlacer._zone_for(zone, Vector3i(1, 1, 0))
	var dropped: Dictionary = SpawnPlacer._zone_for(zone, Vector3i(5, 5, 0))
	TestFixtures.check(res, "citybattle_zone_guard", kept.size() == 1 and dropped.is_empty(),
		"kept=%d dropped=%d" % [kept.size(), dropped.size()])


static func _case_split(res: Dictionary) -> void:
	var key := func(halves: Array) -> String:
		var sides: Array[String] = []
		for side: int in range(2):
			var side_names: Array[String] = []
			for m: MercenaryData in (halves[side] as Array):
				side_names.append(m.merc_name)
			side_names.sort()
			sides.append(" ".join(side_names))
		return "|".join(sides)
	var ordered := func(halves: Array, roster: Array[MercenaryData]) -> bool:
		for side: int in range(2):
			var last: int = -1
			for m: MercenaryData in (halves[side] as Array):
				var at: int = roster.find(m)
				if at <= last:
					return false
				last = at
		return true
	var four: Array[MercenaryData] = []
	for nm: String in ["S3", "S1", "S4", "S2"]:
		four.append(TestFixtures.city_melee(nm))
	var four_keys: Dictionary = {}
	var four_bad: Array[String] = []
	for i: int in range(3):
		var four_halves: Array = HarnessRoster.split_teams(four, "rotate", i)
		var four_a: Array = four_halves[0] as Array
		var four_b: Array = four_halves[1] as Array
		four_keys[key.call(four_halves)] = true
		if four_a.size() != 2 or four_b.size() != 2:
			four_bad.append("index %d splits %d/%d" % [i, four_a.size(), four_b.size()])
		var four_names: Array[String] = []
		for m: MercenaryData in four_a:
			four_names.append(m.merc_name)
		if not four_names.has("S1"):
			four_bad.append("index %d leaves S1 out of team a" % i)
		if not ordered.call(four_halves, four):
			four_bad.append("index %d reorders a team" % i)
	if key.call(HarnessRoster.split_teams(four, "rotate", 3)) != key.call(HarnessRoster.split_teams(four, "rotate", 0)):
		four_bad.append("index 3 differs from index 0")
	TestFixtures.check(res, "citybattle_split_rotate4", four_keys.size() == 3 and four_bad.is_empty(),
		"%d halving(s)%s" % [four_keys.size(), "" if four_bad.is_empty() else "; " + four_bad[0]])
	var six: Array[MercenaryData] = []
	for i: int in range(6):
		six.append(TestFixtures.city_melee("S%d" % (i + 1)))
	var six_keys: Dictionary = {}
	var six_bad: Array[String] = []
	for i: int in range(10):
		var six_halves: Array = HarnessRoster.split_teams(six, "rotate", i)
		var six_a: Array = six_halves[0] as Array
		var six_b: Array = six_halves[1] as Array
		six_keys[key.call(six_halves)] = true
		if six_a.size() != 3 or six_b.size() != 3:
			six_bad.append("index %d splits %d/%d" % [i, six_a.size(), six_b.size()])
		var six_names: Array[String] = []
		for m: MercenaryData in six_a:
			six_names.append(m.merc_name)
		if not six_names.has("S1"):
			six_bad.append("index %d leaves S1 out of team a" % i)
	if key.call(HarnessRoster.split_teams(six, "rotate", 10)) != key.call(HarnessRoster.split_teams(six, "rotate", 0)):
		six_bad.append("index 10 differs from index 0")
	TestFixtures.check(res, "citybattle_split_rotate6", six_keys.size() == 10 and six_bad.is_empty(),
		"%d halving(s)%s" % [six_keys.size(), "" if six_bad.is_empty() else "; " + six_bad[0]])
	var plain: Array = HarnessRoster.split_teams(four, "plain", 1)
	var plain_a: Array = plain[0] as Array
	var plain_b: Array = plain[1] as Array
	var plain_ok: bool = plain_a.size() == 2 and plain_b.size() == 2 \
		and plain_a[0] == four[0] and plain_a[1] == four[1] \
		and plain_b[0] == four[2] and plain_b[1] == four[3]
	var three: Array[MercenaryData] = []
	for i: int in range(3):
		three.append(TestFixtures.city_melee("S%d" % (i + 1)))
	var odd: Array = HarnessRoster.split_teams(three, "rotate", 5)
	var odd_ok: bool = (odd[0] as Array).size() == 1 and (odd[1] as Array).size() == 2 \
		and (odd[0] as Array)[0] == three[0] and (odd[1] as Array)[0] == three[1]
	TestFixtures.check(res, "citybattle_split_plain", plain_ok and odd_ok,
		"plain %s, odd %d/%d" % [str(plain_ok), (odd[0] as Array).size(), (odd[1] as Array).size()])
