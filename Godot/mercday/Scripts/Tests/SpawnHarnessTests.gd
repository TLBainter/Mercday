class_name SpawnHarnessTests
extends RefCounted

#Spawn zone placement of the generic battle branch and the roster halving of the test harness.
#CityTests.run() calls run_cases.

const GENERIC_SEED := 7401
const GENERIC_TEAM := 4


static func run_cases(res: Dictionary) -> void:
	_case_generic_zone(res)
	_case_zone_guard(res)
	_case_split(res)


static func _case_generic_zone(res: Dictionary) -> void:
	seed(GENERIC_SEED)
	var map: BattlefieldArea = BattlefieldArea.generate_random()
	var rosters: Array = GenFixtures.rival_teams("GA", "GB", GENERIC_TEAM, TestFixtures.city_melee)
	var state: BattleState = BattleState.create(rosters[0], rosters[1], map)
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
		if used[t] and counts[t] != GENERIC_TEAM:
			bad.append("team %d holds %d of %d merc(s) in its zone" % [t, counts[t], GENERIC_TEAM])
	if not map.is_interior_map and not (used[0] and used[1]):
		bad.append("exterior map left a generated zone unused")
	var detail: String = "zone unused"
	if used[0] or used[1]:
		detail = "a=%d/%d b=%d/%d" % [counts[0], GENERIC_TEAM, counts[1], GENERIC_TEAM]
	TestFixtures.check(res, "citybattle_generic_zone", bad.is_empty(),
		detail if bad.is_empty() else "%s; %s" % [detail, bad[0]])


static func _case_zone_guard(res: Dictionary) -> void:
	var zone: Dictionary = {Vector2i(1, 1): true}
	var kept: Dictionary = SpawnPlacer.zone_for(zone, Vector3i(1, 1, 0))
	var dropped: Dictionary = SpawnPlacer.zone_for(zone, Vector3i(5, 5, 0))
	TestFixtures.check(res, "citybattle_zone_guard", kept.size() == 1 and dropped.is_empty(),
		"kept=%d dropped=%d" % [kept.size(), dropped.size()])


static func _case_split(res: Dictionary) -> void:
	var four: Array[MercenaryData] = []
	for nm: String in ["S3", "S1", "S4", "S2"]:
		four.append(TestFixtures.city_melee(nm))
	_check_rotate(res, "citybattle_split_rotate4", four, 3)
	var six: Array[MercenaryData] = []
	for i: int in range(6):
		six.append(TestFixtures.city_melee("S%d" % (i + 1)))
	_check_rotate(res, "citybattle_split_rotate6", six, 10)
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


#Rotate indices 0 to count - 1 give count different even halvings that keep roster order and the first
#merc in team a; index count repeats index 0.
static func _check_rotate(res: Dictionary, label: String, roster: Array[MercenaryData], count: int) -> void:
	var half: int = floori(roster.size() * 0.5)
	var keys: Dictionary = {}
	var bad: Array[String] = []
	for i: int in range(count):
		var halves: Array = HarnessRoster.split_teams(roster, "rotate", i)
		var team_a: Array = halves[0] as Array
		var team_b: Array = halves[1] as Array
		keys[_split_key(halves)] = true
		if team_a.size() != half or team_b.size() != half:
			bad.append("index %d splits %d/%d" % [i, team_a.size(), team_b.size()])
		if not _names(team_a).has("S1"):
			bad.append("index %d leaves S1 out of team a" % i)
		if not _in_roster_order(halves, roster):
			bad.append("index %d reorders a team" % i)
	if _split_key(HarnessRoster.split_teams(roster, "rotate", count)) \
			!= _split_key(HarnessRoster.split_teams(roster, "rotate", 0)):
		bad.append("index %d differs from index 0" % count)
	TestFixtures.check(res, label, keys.size() == count and bad.is_empty(),
		"%d halving(s)%s" % [keys.size(), "" if bad.is_empty() else "; " + bad[0]])


static func _names(team: Array) -> Array[String]:
	var out: Array[String] = []
	for m: MercenaryData in team:
		out.append(m.merc_name)
	return out


static func _split_key(halves: Array) -> String:
	var sides: Array[String] = []
	for side: int in range(2):
		var side_names: Array[String] = _names(halves[side] as Array)
		side_names.sort()
		sides.append(" ".join(side_names))
	return "|".join(sides)


static func _in_roster_order(halves: Array, roster: Array[MercenaryData]) -> bool:
	for side: int in range(2):
		var last: int = -1
		for m: MercenaryData in (halves[side] as Array):
			var at: int = roster.find(m)
			if at <= last:
				return false
			last = at
	return true
