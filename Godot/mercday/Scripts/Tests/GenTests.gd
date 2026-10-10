class_name GenTests

#Generator stores and steps: GuildRecord, IssuerOpinion, later the GenX scripts.
#Run: godot --headless --path . -- --gen-tests


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_guild_static(res)
	_case_guild_empty(res)
	_case_guild_overall(res)
	_case_guild_recent(res)
	_case_guild_blended(res)
	_case_guild_month_key(res)
	_case_seat_layout(res)
	_case_issuer_reset(res)
	_case_issuer_seed(res)
	_case_seat_kind_seeds(res)
	_case_issuer_writers(res)
	_case_issuer_groups(res)
	_case_issuer_lookups(res)
	_case_issuer_of_entry(res)
	_case_registry_from_game(res)
	_case_market_issuer(res)
	GenStepTests.add_cases(res)
	GenTuneTests.run(res)
	_clear_issuers()
	GuildRecord.reset()
	return TestFixtures.summarize(res, "GEN")


#Midnight of the 1st of a month in the first calendar year.
static func _month(month: int) -> int:
	return TrynnCalendar.month_start_minute(TrynnCalendar.START_YEAR, month)


static func _clear_issuers() -> void:
	IssuerOpinion.seats.clear()
	IssuerOpinion.group_records.clear()


static func _seed_issuers() -> void:
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())


static func _set_sat(id: int, value: int) -> void:
	IssuerOpinion.seats[id]["satisfaction"] = value


#Mirror of the seat draws (distance, relationship): seeded by index and kind index, people 0, places 1, orgs 2.
static func _draws(kind: String, index: int) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = index * ClientRegistry.SEED_INDEX_STEP \
		+ maxi(ClientRegistry.kind_index(StringName(kind)), 0) * ClientRegistry.SEED_KIND_STEP
	var draws: Array[float] = [rng.randf()]
	draws.append(rng.randf())
	return draws


static func _rolled(kind: String, index: int) -> int:
	return clampi(roundi(_draws(kind, index)[1] * 10.0 - 4.0), ClientRegistry.REL_MIN, ClientRegistry.REL_MAX)


static func _rolled_km(kind: String, index: int) -> int:
	return ClientRegistry.KM_MIN + int(_draws(kind, index)[0] * float(ClientRegistry.KM_SPAN))


static func _span(ids: Array[int]) -> String:
	if ids.is_empty():
		return "none"
	return "%d..%d" % [ids.front(), ids.back()]


static func _offered(reg: ClientRegistry, kind: StringName, index: int) -> int:
	var row: ClientData = reg.client(kind, index)
	return row.offered if row != null else -1


static func _rel(reg: ClientRegistry, kind: StringName, index: int) -> int:
	var row: ClientData = reg.client(kind, index)
	return row.relationship if row != null else 99


static func _km(reg: ClientRegistry, kind: StringName, index: int) -> int:
	var row: ClientData = reg.client(kind, index)
	return row.km if row != null else -1


static func _is_issuer(issuer: Dictionary, kind: StringName, index: int) -> bool:
	return StringName(issuer.get("kind", &"")) == kind and int(issuer.get("index", -1)) == index


static func _case_guild_static(res: Dictionary) -> void:
	var exists: bool = GuildRecord.guild != null
	if exists:
		GuildRecord.guild.record(true, TrynnCalendar.START_MINUTE)
	var before: GuildRecord = GuildRecord.guild
	GuildRecord.reset()
	var after: GuildRecord = GuildRecord.guild
	TestFixtures.check(res, "guild_static_ready", exists, "the guild record exists before any reset: %s" % exists)
	var fresh: bool = after != null and after != before and after.successes == 0 and after.failures == 0
	fresh = fresh and after.by_month.is_empty()
	TestFixtures.check(res, "guild_reset_fresh", fresh, "reset swaps in a new empty record: %s" % fresh)


static func _case_guild_empty(res: Dictionary) -> void:
	var g := GuildRecord.new()
	var now: int = _month(3)
	TestFixtures.check(res, "guild_empty_overall", is_equal_approx(g.overall(), 0.5),
			"overall %.3f" % g.overall())
	TestFixtures.check(res, "guild_empty_recent", is_equal_approx(g.recent(now), 0.5),
			"recent %.3f" % g.recent(now))
	TestFixtures.check(res, "guild_empty_blended", is_equal_approx(g.blended(now), 0.5),
			"blended %.3f" % g.blended(now))


static func _case_guild_overall(res: Dictionary) -> void:
	var g := GuildRecord.new()
	for i: int in range(3):
		g.record(true, _month(1) + i)
	g.record(false, _month(2))
	var ok: bool = is_equal_approx(g.overall(), 0.75) and g.successes == 3 and g.failures == 1
	TestFixtures.check(res, "guild_overall_three_one", ok,
			"overall %.3f from %d-%d" % [g.overall(), g.successes, g.failures])
	var same := GuildRecord.new()
	for i: int in range(5):
		same.record(i % 2 == 0, TrynnCalendar.START_MINUTE)
	var tally: Array = same.by_month.get(GuildRecord.month_key(TrynnCalendar.START_MINUTE), [0, 0])
	var counted: bool = same.successes == 3 and same.failures == 2 and int(tally[0]) == 3 and int(tally[1]) == 2
	TestFixtures.check(res, "guild_record_counts_every_call", counted,
			"5 calls in one minute: %d-%d, month tally %s" % [same.successes, same.failures, str(tally)])


#Records land two months back, last month and this month; recent reads last month only.
static func _case_guild_recent(res: Dictionary) -> void:
	var two_back: int = _month(1)
	var prev: int = TrynnCalendar.next_month_start(two_back)
	var cur: int = TrynnCalendar.next_month_start(prev)
	var now: int = cur + 3 * TrynnCalendar.MINUTES_PER_DAY
	var only_prev := GuildRecord.new()
	var only_cur := GuildRecord.new()
	var only_old := GuildRecord.new()
	var mixed := GuildRecord.new()
	for g: GuildRecord in [only_prev, mixed]:
		for i: int in range(3):
			g.record(true, prev + i)
		g.record(false, prev + TrynnCalendar.MINUTES_PER_DAY)
	for g: GuildRecord in [only_cur, mixed]:
		g.record(false, cur)
		g.record(false, now)
	for g: GuildRecord in [only_old, mixed]:
		g.record(false, two_back)
		g.record(false, two_back + TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "guild_recent_previous_month", is_equal_approx(only_prev.recent(now), 0.75),
			"3-1 last month reads %.3f" % only_prev.recent(now))
	TestFixtures.check(res, "guild_recent_skips_current_month", is_equal_approx(only_cur.recent(now), 0.5),
			"0-2 this month reads %.3f" % only_cur.recent(now))
	TestFixtures.check(res, "guild_recent_skips_two_back", is_equal_approx(only_old.recent(now), 0.5),
			"0-2 two months back reads %.3f" % only_old.recent(now))
	TestFixtures.check(res, "guild_recent_mixed_months", is_equal_approx(mixed.recent(now), 0.75),
			"all three months read %.3f" % mixed.recent(now))
	var edge := GuildRecord.new()
	edge.record(true, cur - 1)
	edge.record(false, cur)
	var edge_ok: bool = is_equal_approx(edge.recent(now), 1.0) and is_equal_approx(edge.recent(cur), 1.0)
	TestFixtures.check(res, "guild_recent_month_edges", edge_ok,
			"a win at the last minute of last month and a loss at this month's first: %.3f, %.3f at the 1st"
			% [edge.recent(now), edge.recent(cur)])
	var last: int = _month(TrynnCalendar.MONTHS.size() - 1)
	var next_year: int = TrynnCalendar.next_month_start(last)
	var turn := GuildRecord.new()
	turn.record(true, last + TrynnCalendar.MINUTES_PER_DAY)
	var date: Dictionary = TrynnCalendar.date_of(next_year)
	var wrap_ok: bool = int(date["year"]) == TrynnCalendar.START_YEAR + 1 and int(date["month"]) == 0
	wrap_ok = wrap_ok and is_equal_approx(turn.recent(next_year + 60), 1.0)
	TestFixtures.check(res, "guild_recent_year_wrap", wrap_ok,
			"a win in the last month of %d reads %.3f in month %d of %d" % [TrynnCalendar.START_YEAR,
			turn.recent(next_year + 60), int(date["month"]), int(date["year"])])


static func _case_guild_blended(res: Dictionary) -> void:
	var g := GuildRecord.new()
	var now: int = _month(3) + 60
	g.record(true, _month(2))
	g.record(true, _month(2) + 1)
	g.record(true, _month(1))
	g.record(false, _month(1) + 1)
	var ok: bool = is_equal_approx(g.overall(), 0.75) and is_equal_approx(g.recent(now), 1.0)
	ok = ok and is_equal_approx(g.blended(now), 0.5 * 0.75 + 0.5 * 1.0)
	TestFixtures.check(res, "guild_blended_mix", ok, "overall %.3f, recent %.3f, blended %.3f (want 0.875)"
			% [g.overall(), g.recent(now), g.blended(now)])


static func _case_guild_month_key(res: Dictionary) -> void:
	var start: int = TrynnCalendar.START_MINUTE
	var date: Dictionary = TrynnCalendar.date_of(start)
	var g := GuildRecord.new()
	g.record(true, start)
	var ok: bool = int(date["year"]) == 212 and int(date["month"]) == 4 and GuildRecord.month_key(start) == "212-4"
	ok = ok and g.by_month.has("212-4") and g.by_month.size() == 1
	TestFixtures.check(res, "guild_month_key_start", ok, "START_MINUTE is %d-%d, keys %s"
			% [int(date["year"]), int(date["month"]), str(g.by_month.keys())])


static func _case_seat_layout(res: Dictionary) -> void:
	var bad: Array[String] = []
	var seen: Array[int] = []
	for kind: StringName in ContractIssuer.KINDS:
		var group: String = String(kind)
		for index: int in range(ContractIssuer.group_size(group)):
			var seat: int = ContractIssuer.seat_id(group, index)
			seen.append(seat)
			if ContractIssuer.kind_of_seat(seat) != group or ContractIssuer.index_of_seat(seat) != index:
				bad.append("%s %d -> %d" % [group, index, seat])
	seen.sort()
	var unique: bool = seen.size() == 25
	for i: int in range(seen.size()):
		unique = unique and seen[i] == i
	TestFixtures.check(res, "seat_round_trip", bad.is_empty() and unique,
			"%s, ids %s" % [TestFixtures.detail(bad, seen.size(), "seats"), _span(seen)])
	var bounds: bool = ContractIssuer.seat_id("orgs", 0) == 0 and ContractIssuer.seat_id("orgs", 8) == 8
	bounds = bounds and ContractIssuer.seat_id("people", 0) == 9 and ContractIssuer.seat_id("people", 7) == 16
	bounds = bounds and ContractIssuer.seat_id("places", 0) == 17 and ContractIssuer.seat_id("places", 7) == 24
	TestFixtures.check(res, "seat_bounds", bounds, "orgs 0..8, people 9..16, places 17..24: %s" % bounds)
	var off: bool = ContractIssuer.seat_id("orgs", 9) == -1 and ContractIssuer.seat_id("people", -1) == -1
	off = off and ContractIssuer.seat_id("dragons", 0) == -1 and ContractIssuer.kind_of_seat(25) == ""
	off = off and ContractIssuer.kind_of_seat(-1) == "" and ContractIssuer.index_of_seat(25) == -1
	TestFixtures.check(res, "seat_off_layout", off, "off-layout kinds, indexes and seats read -1 or empty: %s" % off)


static func _case_issuer_reset(res: Dictionary) -> void:
	_clear_issuers()
	var was_empty: bool = IssuerOpinion.seat_count() == 0 and IssuerOpinion.ids().is_empty()
	_seed_issuers()
	var ids: Array[int] = IssuerOpinion.ids()
	var ok: bool = was_empty and IssuerOpinion.seat_count() == 25 and ids.size() == 25
	ok = ok and ids.front() == 0 and ids.back() == 24
	TestFixtures.check(res, "issuer_seat_count", ok, "%d seats, ids %s" % [IssuerOpinion.seat_count(), _span(ids)])
	var orgs: int = IssuerOpinion.ids_in_group("orgs").size()
	var people: int = IssuerOpinion.ids_in_group("people").size()
	var places: int = IssuerOpinion.ids_in_group("places").size()
	TestFixtures.check(res, "issuer_group_sizes", orgs == 9 and people == 8 and places == 8,
			"orgs %d, people %d, places %d" % [orgs, people, places])
	var edges: Array[String] = [IssuerOpinion.group_of(8), IssuerOpinion.group_of(9), IssuerOpinion.group_of(16),
			IssuerOpinion.group_of(17)]
	var edges_ok: bool = edges[0] == "orgs" and edges[1] == "people" and edges[2] == "people" and edges[3] == "places"
	TestFixtures.check(res, "issuer_group_bounds", edges_ok, "seats 8/9/16/17: %s" % "/".join(edges))
	var seeded: int = IssuerOpinion.satisfaction(9)
	_set_sat(9, 0)
	IssuerOpinion.on_fail(0, _month(2))
	_seed_issuers()
	var cleared: bool = IssuerOpinion.satisfaction(9) == seeded and IssuerOpinion.group_record("orgs").failures == 0
	TestFixtures.check(res, "issuer_reset_clears", cleared, "seat 9 back to %d (seed %d), orgs failures %d"
			% [IssuerOpinion.satisfaction(9), seeded, IssuerOpinion.group_record("orgs").failures])


static func _case_issuer_seed(res: Dictionary) -> void:
	var companies: Array[Dictionary] = ClientRegistry.market_companies()
	var lenders: Dictionary = ClientRegistry.lender_relationships()
	IssuerOpinion.reset(companies, lenders)
	var lender: String = String(companies[0].get("lender", "")) if not companies.is_empty() else ""
	var lent: int = int(lenders.get(lender, 99))
	var org_ok: bool = lenders.has(lender) and ClientRegistry.seed_relationship("orgs", 0, companies, lenders) == lent
	org_ok = org_ok and IssuerOpinion.satisfaction(0) == (lent + 5) * 10
	TestFixtures.check(res, "issuer_seed_lender_org", org_ok, "seat 0 lender %s rel %d, satisfaction %d"
			% [lender, lent, IssuerOpinion.satisfaction(0)])
	var person: int = _rolled("people", 0)
	var person_ok: bool = ClientRegistry.seed_relationship("people", 0, companies, lenders) == person
	person_ok = person_ok and IssuerOpinion.satisfaction(9) == (person + 5) * 10
	TestFixtures.check(res, "issuer_seed_person", person_ok, "seat 9 roll %d, satisfaction %d"
			% [person, IssuerOpinion.satisfaction(9)])
	var place: int = _rolled("places", 0)
	var place_ok: bool = ClientRegistry.seed_relationship("places", 0, companies, lenders) == place
	place_ok = place_ok and IssuerOpinion.satisfaction(17) == (place + 5) * 10
	TestFixtures.check(res, "issuer_seed_place", place_ok, "seat 17 roll %d, satisfaction %d"
			% [place, IssuerOpinion.satisfaction(17)])
	var none: Array[ContractView] = []
	var reg := ClientRegistry.new()
	reg.build(none, companies, [], {}, [], lenders)
	var bad: Array[String] = []
	for id: int in IssuerOpinion.ids():
		var kind: StringName = StringName(ContractIssuer.kind_of_seat(id))
		var row: ClientData = reg.client(kind, ContractIssuer.index_of_seat(id))
		if row == null or row.relationship != IssuerOpinion.face(id) or row.name != IssuerOpinion.name_of(id):
			bad.append("seat %d" % id)
	TestFixtures.check(res, "issuer_seed_matches_registry", bad.is_empty() and IssuerOpinion.seat_count() == 25,
			"registry rows whose relationship or name differ from the seat: %s"
			% TestFixtures.detail(bad, IssuerOpinion.seat_count(), "seats"))
	var inverts: Array[String] = []
	for f: int in range(ClientRegistry.REL_MIN, ClientRegistry.REL_MAX + 1):
		_set_sat(9, (f + 5) * 10)
		if IssuerOpinion.face(9) != f:
			inverts.append("face %d reads %d" % [f, IssuerOpinion.face(9)])
	TestFixtures.check(res, "issuer_face_inverts_seed", inverts.is_empty(), TestFixtures.detail(inverts, 11, "faces"))
	var reads: Array[int] = []
	for sat: int in [44, 45, 0, 100]:
		_set_sat(9, sat)
		reads.append(IssuerOpinion.face(9))
	var rounds_ok: bool = reads[0] == -1 and reads[1] == 0 and reads[2] == -5 and reads[3] == 5
	TestFixtures.check(res, "issuer_face_rounds", rounds_ok, "satisfaction 44/45/0/100 read faces %s" % str(reads))


#Seats seed by kind index, so people and places at one index roll apart and the location steps by kind index.
static func _case_seat_kind_seeds(res: Dictionary) -> void:
	var none: Array[ContractView] = []
	var reg := ClientRegistry.new()
	reg.build(none, ClientRegistry.market_companies(), [], {}, [], ClientRegistry.lender_relationships())
	var got: Array[int] = [_km(reg, &"people", 1), _rel(reg, &"people", 1), _km(reg, &"places", 1),
			_rel(reg, &"places", 1)]
	var want: Array[int] = [_rolled_km("people", 1), _rolled("people", 1), _rolled_km("places", 1),
			_rolled("places", 1)]
	var apart: bool = got == want and got[0] != got[2] and _draws("people", 1) != _draws("places", 1)
	TestFixtures.check(res, "seat_rolls_people_places_apart", apart,
			"people 1 / places 1 km and rel %s, kind index mirror %s" % [str(got), str(want)])
	var bad: Array[String] = []
	var total: int = 0
	for kind: StringName in ClientRegistry.KINDS:
		var step: int = ClientRegistry.kind_index(kind) * ClientRegistry.LOC_KIND_STEP
		for row: ClientData in reg.clients(kind):
			total += 1
			var want_at: String = ClientRegistry.LOCATIONS[posmod(row.index * ClientRegistry.LOC_INDEX_STEP + step,
					ClientRegistry.LOCATIONS.size())]
			if row.location != want_at:
				bad.append("%s %d at %s, want %s" % [kind, row.index, row.location, want_at])
	var spots: Array[String] = []
	for kind: StringName in ClientRegistry.KINDS:
		var row: ClientData = reg.client(kind, 1)
		spots.append(row.location if row != null else "?")
	var spread: bool = spots[0] != spots[1] and spots[1] != spots[2] and spots[0] != spots[2]
	TestFixtures.check(res, "seat_location_by_kind_index", bad.is_empty() and total == 25 and spread,
			"%s, people/places/orgs 1 at %s" % [TestFixtures.detail(bad, total, "rows"), "/".join(spots)])


static func _case_issuer_writers(res: Dictionary) -> void:
	_seed_issuers()
	var at: int = _month(2)
	_set_sat(9, 50)
	IssuerOpinion.on_success(9, at, false)
	var added: int = IssuerOpinion.satisfaction(9)
	_set_sat(9, 95)
	IssuerOpinion.on_success(9, at, false)
	var top: int = IssuerOpinion.satisfaction(9)
	TestFixtures.check(res, "issuer_success_adds", added == 60, "50 and a win read %d" % added)
	TestFixtures.check(res, "issuer_success_clamps", top == 100, "95 and a win read %d" % top)
	_set_sat(9, 50)
	IssuerOpinion.on_fail(9, at)
	var lowered: int = IssuerOpinion.satisfaction(9)
	_set_sat(9, 10)
	IssuerOpinion.on_fail(9, at)
	var bottom: int = IssuerOpinion.satisfaction(9)
	TestFixtures.check(res, "issuer_fail_subtracts", lowered == 35, "50 and a failure read %d" % lowered)
	TestFixtures.check(res, "issuer_fail_clamps", bottom == 0, "10 and a failure read %d" % bottom)
	_set_sat(9, 80)
	IssuerOpinion.on_reject(9)
	var scaled: int = IssuerOpinion.satisfaction(9)
	_set_sat(9, 45)
	IssuerOpinion.on_reject(9)
	var rounded: int = IssuerOpinion.satisfaction(9)
	TestFixtures.check(res, "issuer_reject_scales", scaled == 60, "80 and a reject read %d" % scaled)
	TestFixtures.check(res, "issuer_reject_rounds", rounded == 34, "45 and a reject read %d" % rounded)
	var people: GuildRecord = IssuerOpinion.group_record("people")
	var wins: int = people.successes
	_set_sat(9, 50)
	IssuerOpinion.on_success(9, at, true)
	var red_ok: bool = IssuerOpinion.satisfaction(9) == 50 and people.successes == wins + 1
	TestFixtures.check(res, "issuer_red_success_keeps", red_ok, "in the red: satisfaction %d, people wins %d to %d"
			% [IssuerOpinion.satisfaction(9), wins, people.successes])


static func _case_issuer_groups(res: Dictionary) -> void:
	_seed_issuers()
	var at: int = _month(2)
	IssuerOpinion.on_success(0, at, false)
	IssuerOpinion.on_success(1, at, true)
	IssuerOpinion.on_fail(2, at)
	IssuerOpinion.on_fail(9, at)
	IssuerOpinion.on_reject(10)
	IssuerOpinion.on_reject(17)
	var orgs: GuildRecord = IssuerOpinion.group_record("orgs")
	var people: GuildRecord = IssuerOpinion.group_record("people")
	var places: GuildRecord = IssuerOpinion.group_record("places")
	var counts: bool = orgs.successes == 2 and orgs.failures == 1 and people.successes == 0 and people.failures == 1
	counts = counts and places.successes == 0 and places.failures == 0
	TestFixtures.check(res, "issuer_group_record_counts", counts, "orgs %d-%d, people %d-%d, places %d-%d"
			% [orgs.successes, orgs.failures, people.successes, people.failures, places.successes, places.failures])
	var same_month: int = at + 60
	TestFixtures.check(res, "issuer_group_blended_empty",
			is_equal_approx(IssuerOpinion.group_blended("places", same_month), 0.5),
			"places blended %.3f" % IssuerOpinion.group_blended("places", same_month))
	var next_month: int = _month(3) + 60
	var now_want: float = 0.5 * (2.0 / 3.0) + 0.5 * 0.5
	var later_want: float = 2.0 / 3.0
	var blend_ok: bool = is_equal_approx(IssuerOpinion.group_blended("orgs", same_month), now_want)
	blend_ok = blend_ok and is_equal_approx(IssuerOpinion.group_blended("orgs", next_month), later_want)
	TestFixtures.check(res, "issuer_group_blended_reads_record", blend_ok,
			"orgs blended %.3f this month (want %.3f), %.3f next month (want %.3f)"
			% [IssuerOpinion.group_blended("orgs", same_month), now_want,
			IssuerOpinion.group_blended("orgs", next_month), later_want])
	var unknown: GuildRecord = IssuerOpinion.group_record("dragons")
	var unknown_ok: bool = unknown != null and unknown.successes + unknown.failures == 0
	unknown_ok = unknown_ok and not IssuerOpinion.group_records.has("dragons")
	TestFixtures.check(res, "issuer_group_unknown", unknown_ok, "an unknown group reads an empty record it does not keep")


static func _case_issuer_lookups(res: Dictionary) -> void:
	var picks: Array[int] = []
	for id: int in [0, 8, 9, 17, -1, 25]:
		picks.append(IssuerOpinion.company_index(id))
	var company_ok: bool = picks[0] == 0 and picks[1] == 8 and picks[2] == -1 and picks[3] == -1
	company_ok = company_ok and picks[4] == -1 and picks[5] == -1
	TestFixtures.check(res, "issuer_company_index", company_ok, "seats 0/8/9/17/-1/25 read %s" % str(picks))
	var bad: Array[String] = []
	for id: int in range(1, 13):
		var kind: String = String(ContractIssuer.kind_of(id))
		var index: int = ContractIssuer.index_of(id, ContractIssuer.group_size(kind))
		var seat: int = IssuerOpinion.seat_for_entry(id)
		if ContractIssuer.kind_of_seat(seat) != kind or ContractIssuer.index_of_seat(seat) != index:
			bad.append("%d -> %d" % [id, seat])
	var pins: Array[int] = [IssuerOpinion.seat_for_entry(10), IssuerOpinion.seat_for_entry(11),
			IssuerOpinion.seat_for_entry(12)]
	var pinned: bool = pins[0] == 12 and pins[1] == 20 and pins[2] == 4
	TestFixtures.check(res, "issuer_seat_for_entry", bad.is_empty() and pinned,
			"%s, entries 10/11/12 sit at %s" % [TestFixtures.detail(bad, 12, "entry ids"), str(pins)])
	_seed_issuers()
	var seats: int = IssuerOpinion.seat_count()
	IssuerOpinion.on_success(99, _month(2), false)
	IssuerOpinion.on_fail(-1, _month(2))
	IssuerOpinion.on_reject(99)
	var unknown_ok: bool = IssuerOpinion.satisfaction(99) == 50 and IssuerOpinion.face(99) == 0
	unknown_ok = unknown_ok and IssuerOpinion.name_of(99) == "" and IssuerOpinion.group_of(99) == ""
	unknown_ok = unknown_ok and IssuerOpinion.satisfaction(-1) == 50 and IssuerOpinion.face(-1) == 0
	unknown_ok = unknown_ok and IssuerOpinion.seat_count() == seats and not IssuerOpinion.has_seat(99)
	TestFixtures.check(res, "issuer_unknown_id", unknown_ok, "seat 99: satisfaction %d, face %d, name '%s'"
			% [IssuerOpinion.satisfaction(99), IssuerOpinion.face(99), IssuerOpinion.name_of(99)])
	var companies: Array[Dictionary] = ClientRegistry.market_companies()
	var first: String = String(companies[0].get("name", "")) if not companies.is_empty() else "?"
	var names: Array[String] = [IssuerOpinion.name_of(0), IssuerOpinion.name_of(9), IssuerOpinion.name_of(17)]
	var names_ok: bool = names[0] == first and names[1] == "Person 1 Name" and names[2] == "Place 1 Name"
	TestFixtures.check(res, "issuer_names", names_ok, "seats 0/9/17: %s" % " / ".join(names))


static func _case_issuer_of_entry(res: Dictionary) -> void:
	var entry := BoardEntry.new()
	entry.id = 12
	var legacy: Dictionary = ClientRegistry.issuer_of_entry(entry)
	entry.issuer_id = 10
	var seated: Dictionary = ClientRegistry.issuer_of_entry(entry)
	entry.issuer_id = 99
	var off: Dictionary = ClientRegistry.issuer_of_entry(entry)
	TestFixtures.check(res, "registry_issuer_of_entry_legacy", _is_issuer(legacy, &"orgs", 4),
			"entry 12 without a seat: %s" % str(legacy))
	TestFixtures.check(res, "registry_issuer_of_entry_seat", _is_issuer(seated, &"people", 1),
			"entry 12 at seat 10: %s" % str(seated))
	TestFixtures.check(res, "registry_issuer_of_entry_off_layout", _is_issuer(off, &"orgs", 4),
			"entry 12 at seat 99: %s" % str(off))


#from_game files a seated entry under its seat and reads faces from the opinion store only while it holds seats.
static func _case_registry_from_game(res: Dictionary) -> void:
	var saved: ContractBoard = GameState.board
	var board := ContractBoard.new()
	var seated := BoardEntry.new()
	seated.id = 12
	seated.issuer_id = ContractIssuer.seat_id("people", 1)
	var legacy := BoardEntry.new()
	legacy.id = 13
	board.entries.append(seated)
	board.entries.append(legacy)
	GameState.board = board
	_seed_issuers()
	_set_sat(ContractIssuer.seat_id("orgs", 2), 0)
	_set_sat(ContractIssuer.seat_id("people", 1), 100)
	var reg: ClientRegistry = ClientRegistry.from_game()
	var routed: Array[int] = [_offered(reg, &"people", 1), _offered(reg, &"orgs", 4), _offered(reg, &"people", 4)]
	TestFixtures.check(res, "registry_routes_by_seat", routed[0] == 1 and routed[1] == 0 and routed[2] == 1,
			"people 1 / orgs 4 / people 4 offered %s" % str(routed))
	var bad: Array[String] = []
	var total: int = 0
	for kind: StringName in ContractIssuer.KINDS:
		for row: ClientData in reg.clients(kind):
			total += 1
			if row.relationship != IssuerOpinion.face(ContractIssuer.seat_id(String(kind), row.index)):
				bad.append("%s %d" % [kind, row.index])
	var faces_ok: bool = bad.is_empty() and total == 25 and _rel(reg, &"orgs", 2) == -5
	faces_ok = faces_ok and _rel(reg, &"people", 1) == 5
	TestFixtures.check(res, "registry_faces_from_opinion", faces_ok, "%s, orgs 2 face %d, people 1 face %d"
			% [TestFixtures.detail(bad, total, "rows"), _rel(reg, &"orgs", 2), _rel(reg, &"people", 1)])
	_clear_issuers()
	var plain: ClientRegistry = ClientRegistry.from_game()
	var companies: Array[Dictionary] = ClientRegistry.market_companies()
	var lenders: Dictionary = ClientRegistry.lender_relationships()
	var org_seed: int = ClientRegistry.seed_relationship("orgs", 2, companies, lenders)
	var person_seed: int = ClientRegistry.seed_relationship("people", 1, companies, lenders)
	var seeded_ok: bool = _rel(plain, &"orgs", 2) == org_seed and _rel(plain, &"people", 1) == person_seed
	TestFixtures.check(res, "registry_faces_seeded_without_store", seeded_ok,
			"empty store: orgs 2 rel %d (seed %d), people 1 rel %d (seed %d)"
			% [_rel(plain, &"orgs", 2), org_seed, _rel(plain, &"people", 1), person_seed])
	GameState.board = saved


#StockMarket credits a seated entry to its org seat's company and an unseated or unlisted one by the id rule.
static func _case_market_issuer(res: Dictionary) -> void:
	var saved: ContractBoard = GameState.board
	var board := ContractBoard.new()
	var seated := BoardEntry.new()
	seated.id = 13
	seated.issuer_id = ContractIssuer.seat_id("orgs", 3)
	var legacy := BoardEntry.new()
	legacy.id = 12
	board.entries.append(seated)
	board.entries.append(legacy)
	GameState.board = board
	var count: int = StockMarket.company_count()
	var picks: Array[int] = [StockMarket.issuer_company(13), StockMarket.issuer_company(12),
			StockMarket.issuer_company(999)]
	var ok: bool = picks[0] == 3 and picks[1] == ContractIssuer.company_of(12, count)
	ok = ok and picks[2] == ContractIssuer.company_of(999, count)
	TestFixtures.check(res, "market_issuer_company", ok, "entries 13 (seat 3) / 12 / 999 (unlisted) credit %s"
			% str(picks))
	GameState.board = saved
