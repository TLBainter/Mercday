class_name GenStepTests
#Generation step checks for room, record, likelihood, issuer, type, match, level and difficulty; run from GenTests.

const TRIALS: int = 1000


static func add_cases(res: Dictionary) -> void:
	_case_likelihood(res)
	_case_record(res)
	_case_match_chance(res)
	_case_level(res)
	_case_issuer(res)
	_case_type(res)
	_case_match_rows(res)
	_case_difficulty(res)
	_case_row_clamp(res)
	_case_event_branch(res)
	_case_room(res)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _merc(level: int, knowledge: String = "", tool: String = "", tradition: String = "") -> MercenaryData:
	var m := MercenaryData.new()
	m.stats = {"level": level}
	if knowledge != "":
		var k := UtilityTraitData.new()
		k.utility_name = knowledge
		m.knowledges.append(k)
	if tool != "":
		var t := UtilityTraitData.new()
		t.utility_name = tool
		m.tools.append(t)
	if tradition != "":
		m.tradition = TraditionData.new()
		m.tradition.tradition_name = tradition
	return m


static func _row(hours: int) -> ContractData:
	var row := ContractData.new()
	row.time_minutes = hours * CampaignClock.MINUTES_PER_HOUR
	return row


static func _entry(status: String, campaign_id: int = 0) -> BoardEntry:
	var item := BoardEntry.new()
	item.status = status
	item.campaign_id = campaign_id
	return item


static func _case_likelihood(res: Dictionary) -> void:
	var chances: Array[float] = [GenLikelihood.chance(0.5), GenLikelihood.chance(0.0), GenLikelihood.chance(1.0)]
	var ok: bool = is_equal_approx(chances[0], 0.60) and is_equal_approx(chances[1], 0.45) \
		and is_equal_approx(chances[2], 0.75)
	TestFixtures.check(res, "gen step: likelihood chance", ok, "0.5/0.0/1.0 read %s" % str(chances))
	var rng: RandomNumberGenerator = _rng(11)
	var total: int = 0
	for i: int in range(TRIALS):
		total += GenLikelihood.count(0.5, rng)
	var mean: float = float(total) / TRIALS
	TestFixtures.check(res, "gen step: likelihood mean count", mean >= 0.70 and mean <= 0.90,
		"mean %.3f over %d trials (want 0.70..0.90)" % [mean, TRIALS])


static func _case_record(res: Dictionary) -> void:
	var now: int = TrynnCalendar.month_start_minute(TrynnCalendar.START_YEAR, 2)
	var empty: Dictionary = GenRecord.rates(null, now)
	var empty_ok: bool = is_equal_approx(float(empty["overall"]), 0.5) and is_equal_approx(float(empty["recent"]), 0.5) \
		and is_equal_approx(float(empty["blended"]), 0.5)
	var record := GuildRecord.new()
	for win: bool in [true, true, true, false]:
		record.record(win, now)
	var rates: Dictionary = GenRecord.rates(record, now)
	var ok: bool = empty_ok and is_equal_approx(float(rates["overall"]), 0.75) \
		and is_equal_approx(float(rates["recent"]), 0.5) and is_equal_approx(float(rates["blended"]), 0.625)
	TestFixtures.check(res, "gen step: record rates", ok, "empty %s, 3-1 this month %s" % [str(empty), str(rates)])


static func _case_match_chance(res: Dictionary) -> void:
	var m: Array[float] = [GenMatch.chance(0.5), GenMatch.chance(0.0), GenMatch.chance(1.0)]
	TestFixtures.check(res, "gen step: match chance", is_equal_approx(m[0], 0.50) and is_equal_approx(m[1], 0.70)
		and is_equal_approx(m[2], 0.30), "0.5/0.0/1.0 read %s" % str(m))
	var d: Array[float] = [GenDifficulty.centre(0.5), GenDifficulty.centre(0.0), GenDifficulty.centre(1.0)]
	TestFixtures.check(res, "gen step: difficulty centre", is_equal_approx(d[0], 2.75) and is_equal_approx(d[1], 2.0)
		and is_equal_approx(d[2], 3.5), "0.5/0.0/1.0 read %s" % str(d))


static func _case_level(res: Dictionary) -> void:
	var all_living: Array[MercenaryData] = [_merc(10), _merc(20)]
	var available: Array[MercenaryData] = [_merc(10)]
	var resting: Array[MercenaryData] = [_merc(20)]
	var none: Array[MercenaryData] = []
	var full: float = GenLevel.centre(all_living, available, resting)
	TestFixtures.check(res, "gen step: level centre all groups", is_equal_approx(full, 14.5), "read %.3f (want 14.5)" % full)
	var missing: float = GenLevel.centre(all_living, available, none)
	TestFixtures.check(res, "gen step: level centre missing group", is_equal_approx(missing, 13.125),
		"no resting group read %.3f (want 13.125)" % missing)
	var empty: float = GenLevel.centre(none, none, none)
	TestFixtures.check(res, "gen step: level centre no mercs", is_equal_approx(empty, 1.0), "read %.3f" % empty)
	var rng: RandomNumberGenerator = _rng(23)
	var lo: int = roundi(full * GenConstants.LEVEL_LO)
	var hi: int = roundi(full * GenConstants.LEVEL_HI)
	var inside: bool = true
	var capped: bool = true
	var ones: bool = true
	for i: int in range(TRIALS):
		var level: int = GenLevel.roll(full, rng)
		inside = inside and level >= lo and level <= hi
		var top: int = GenLevel.roll(38.0, rng)
		capped = capped and top >= 1 and top <= GenConstants.LEVEL_CAP
		ones = ones and GenLevel.roll(1.0, rng) == 1
	TestFixtures.check(res, "gen step: level roll bounds", inside and capped,
		"centre 14.5 inside %d..%d: %s; centre 38 inside 1..%d: %s" % [lo, hi, inside, GenConstants.LEVEL_CAP, capped])
	TestFixtures.check(res, "gen step: level centre one rolls one", ones, "centre 1.0 always 1: %s" % ones)


static func _case_issuer(res: Dictionary) -> void:
	IssuerOpinion.reset(ClientRegistry.market_companies(), ClientRegistry.lender_relationships())
	var now: int = TrynnCalendar.month_start_minute(TrynnCalendar.START_YEAR, 1)
	var rng: RandomNumberGenerator = _rng(37)
	var excluded: Array[int] = [0, 5, 12]
	var hit_excluded: int = 0
	for i: int in range(TRIALS):
		if excluded.has(GenIssuer.pick(excluded, now, rng)):
			hit_excluded += 1
	TestFixtures.check(res, "gen step: issuer excluded never picked", hit_excluded == 0,
		"%d of %d picks hit an excluded seat" % [hit_excluded, TRIALS])
	var picked: int = GenIssuer.pick(IssuerOpinion.ids(), now, rng)
	TestFixtures.check(res, "gen step: issuer all excluded", picked == -1, "pick read %d" % picked)
	IssuerOpinion.seats[9]["satisfaction"] = 0
	var floor_w: float = GenIssuer.weight(9, now)
	var want: float = GenConstants.ISSUER_MIN_WEIGHT * (GenConstants.ISSUER_GROUP_BASE + 0.5)
	TestFixtures.check(res, "gen step: issuer weight floor", is_equal_approx(floor_w, want),
		"satisfaction 0 weight %.4f (want %.4f)" % [floor_w, want])
	IssuerOpinion.seats[9]["satisfaction"] = 100
	IssuerOpinion.seats[10]["satisfaction"] = 10
	var pair: Array[int] = [9, 10]
	var none: Array[int] = []
	var high: int = 0
	var outside: int = 0
	for i: int in range(TRIALS):
		var id: int = GenIssuer.pick(none, now, rng, pair)
		if id == 9:
			high += 1
		elif id != 10:
			outside += 1
	TestFixtures.check(res, "gen step: issuer satisfaction weighs", high > TRIALS - high,
		"seat at 100 picked %d of %d against seat at 10" % [high, TRIALS])
	TestFixtures.check(res, "gen step: issuer only_ids honoured", outside == 0,
		"%d picks fell outside seats 9 and 10" % outside)
	IssuerOpinion.seats.clear()
	IssuerOpinion.group_records.clear()


static func _case_type(res: Dictionary) -> void:
	var types: Array[String] = ["A", "B", "C"]
	var open_types: Array[String] = ["B", "C", "C"]
	var w: Dictionary = GenType.type_weights(types, open_types)
	var ok: bool = is_equal_approx(float(w["A"]), 1.0) and is_equal_approx(float(w["B"]), 0.25) \
		and is_equal_approx(float(w["C"]), 0.0625)
	TestFixtures.check(res, "gen step: type weights", ok, "0/1/2 open read %s" % str(w))
	var rng: RandomNumberGenerator = _rng(41)
	var long_row: ContractData = _row(30)
	var short_row: ContractData = _row(4)
	var forced_row: ContractData = _row(6)
	var rows: Array[ContractData] = [long_row, short_row]
	var forced: Array[ContractData] = [forced_row]
	var no_forced: Array[ContractData] = []
	var shorts: Array[ContractData] = [short_row]
	var forced_ok: bool = true
	var short_ok: bool = true
	var long_ok: bool = true
	var fallback_ok: bool = true
	for i: int in range(100):
		forced_ok = forced_ok and GenType.pick_row(rows, 0.5, forced, rng) == forced_row
		short_ok = short_ok and GenType.pick_row(rows, 0.8, no_forced, rng) == short_row
		long_ok = long_ok and GenType.pick_row(rows, 0.2, no_forced, rng) == long_row
		fallback_ok = fallback_ok and GenType.pick_row(shorts, 0.2, no_forced, rng) == short_row
	TestFixtures.check(res, "gen step: type forced rows win", forced_ok, "forced row always picked: %s" % forced_ok)
	TestFixtures.check(res, "gen step: type length preference", short_ok and long_ok,
		"long share 0.8 picks short: %s; 0.2 picks long: %s" % [short_ok, long_ok])
	TestFixtures.check(res, "gen step: type length fallback", fallback_ok, "no long row falls back: %s" % fallback_ok)
	var evented := ContractData.new()
	evented.assigned_primary_event = "P"
	evented.rolled_mishaps.append("M")
	var want: float = 2.0 + ContractLibrary.config().board_gap_hours
	var hours_ok: bool = is_equal_approx(GenType.row_hours(long_row), 30.0) \
		and is_equal_approx(GenType.row_hours(evented), want) and GenType.is_long(long_row) and not GenType.is_long(short_row)
	TestFixtures.check(res, "gen step: type row hours", hours_ok, "time 30 h read %.1f, two events read %.1f (want %.1f)"
		% [GenType.row_hours(long_row), GenType.row_hours(evented), want])
	var picks: Dictionary = {"A": 0, "B": 0, "C": 0}
	for i: int in range(TRIALS):
		var t: String = GenType.pick_type(w, rng)
		picks[t] = int(picks[t]) + 1
	TestFixtures.check(res, "gen step: type pick follows weights", int(picks["A"]) > int(picks["B"])
		and int(picks["B"]) > int(picks["C"]), "picks %s" % str(picks))


static func _case_match_rows(res: Dictionary) -> void:
	var row := ContractData.new()
	row.knowledge_boosts = {"Diplomacy": 15, "Medicine": 10}
	row.tool_boosts = {"Lockpick": 5}
	row.tradition_boosts = {"Faith": 5}
	var a: MercenaryData = _merc(5, "Diplomacy")
	var b: MercenaryData = _merc(5, "Diplomacy", "Lockpicks")
	var c: MercenaryData = _merc(5, "Medicine", "", "Faith")
	var pair: Array[MercenaryData] = [a, b]
	var trio: Array[MercenaryData] = [a, b, c]
	var two: int = GenMatch.matched_elements(row, pair)
	var four: int = GenMatch.matched_elements(row, trio)
	TestFixtures.check(res, "gen step: match elements count once", two == 2 and four == 4,
		"mercs a,b read %d (want 2), a,b,c read %d (want 4)" % [two, four])
	var bare := ContractData.new()
	var rows: Array[ContractData] = [row, bare]
	var matched: Array[ContractData] = GenMatch.matching_rows(rows, pair)
	TestFixtures.check(res, "gen step: match rows filter", matched.size() == 1 and matched[0] == row,
		"%d of 2 rows matched" % matched.size())


static func _case_difficulty(res: Dictionary) -> void:
	var rng: RandomNumberGenerator = _rng(53)
	var below: bool = true
	var above: bool = true
	var snapped: bool = true
	for i: int in range(TRIALS):
		var low: float = GenDifficulty.roll(2.0, 3.0, rng)
		var high: float = GenDifficulty.roll(2.0, 1.0, rng)
		below = below and low <= 2.0 and low >= GenConstants.DIFF_MIN
		above = above and high >= 2.0 and high <= GenConstants.DIFF_MAX
		snapped = snapped and is_equal_approx(fmod(low, GenConstants.DIFF_SNAP), 0.0) \
			and is_equal_approx(fmod(high, GenConstants.DIFF_SNAP), 0.0)
	TestFixtures.check(res, "gen step: difficulty roll side", below and above,
		"mean above centre stays at or below: %s; mean below stays at or above: %s" % [below, above])
	TestFixtures.check(res, "gen step: difficulty roll snap", snapped, "every roll on the 0.5 grid: %s" % snapped)
	var authored := ContractData.new()
	authored.difficulty = 4.5
	var kept: float = GenDifficulty.for_row(authored, 2.0, 1.0, rng)
	TestFixtures.check(res, "gen step: difficulty authored kept", is_equal_approx(kept, 4.5), "read %.1f" % kept)


static func _difficulty_text(contract: ContractData) -> String:
	return "null" if contract == null else "%.1f" % contract.difficulty


#Contracts.tsv Difficulty Min and Max hold the drawn, forced and Guild Ads difficulty; blank ends leave it alone.
static func _case_row_clamp(res: Dictionary) -> void:
	var row: ContractData = ContractLibrary.contract("Cat Stuck in Tree!").duplicate(true) as ContractData
	row.difficulty_min = 2.0
	row.difficulty_max = 2.5
	var drawn: ContractData = ContractGenerator.generate_row(row, 3, 5.0, "")
	TestFixtures.check(res, "gen step: row clamp draw", drawn != null and is_equal_approx(drawn.difficulty, 2.5),
		"given 5.0 on a 2.0 to 2.5 row read %s" % _difficulty_text(drawn))
	var previous: float = ContractGenerator.forced_difficulty
	ContractGenerator.forced_difficulty = 5.0
	var forced: ContractData = ContractGenerator.generate_row(row, 3, 0.0, "")
	ContractGenerator.forced_difficulty = previous
	TestFixtures.check(res, "gen step: row clamp forced", forced != null and is_equal_approx(forced.difficulty, 2.5),
		"forced 5.0 on a 2.0 to 2.5 row read %s" % _difficulty_text(forced))
	var open_row: ContractData = row.duplicate(true) as ContractData
	open_row.difficulty_min = 0.0
	open_row.difficulty_max = 0.0
	var kept: ContractData = ContractGenerator.generate_row(open_row, 3, 4.5, "")
	TestFixtures.check(res, "gen step: row clamp blank keeps", kept != null and is_equal_approx(kept.difficulty, 4.5),
		"given 4.5 on a blank row read %s" % _difficulty_text(kept))
	var cat: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	TestFixtures.check(res, "gen step: row clamp cat", cat != null and is_equal_approx(cat.difficulty, 0.5),
		"cat row read %s" % _difficulty_text(cat))
	var pinned: Array[String] = ContractLibrary.pinned_names.duplicate()
	ContractLibrary.pinned_names = ["Cat Stuck in Tree!"]
	var types: Array[String] = ["Help"]
	var places: Array[String] = []
	var ads: ContractData = ContractGenerator.generate_for(types, places, 3.0, 4.0)
	ContractLibrary.pinned_names = pinned
	TestFixtures.check(res, "gen step: row clamp generate_for", ads != null and is_equal_approx(ads.difficulty, 0.5),
		"caller range 3.0 to 4.0 on the cat row read %s" % _difficulty_text(ads))


static func _case_event_branch(res: Dictionary) -> void:
	var row: ContractData = ContractLibrary.contract("Cat Stuck in Tree!").duplicate(true) as ContractData
	row.style = "event"
	row.completion = "event:Chase"
	row.primary_event_pool.clear()
	var built: ContractData = ContractGenerator.generate_row(row, 3, 2.0, "")
	var primary: String = built.assigned_primary_event if built != null else "null"
	TestFixtures.check(res, "gen step: event branch primary", primary == "Chase", "assigned %s" % primary)


static func _case_room(res: Dictionary) -> void:
	var board := ContractBoard.new()
	for status: String in [BoardEntry.STATUS_DRAFT, BoardEntry.STATUS_DRAFT, BoardEntry.STATUS_ACTIVE,
			BoardEntry.STATUS_SUCCEEDED, BoardEntry.STATUS_FAILED, BoardEntry.STATUS_EXPIRED, BoardEntry.STATUS_REJECTED]:
		board.entries.append(_entry(status))
	board.entries.append(_entry(BoardEntry.STATUS_DRAFT, 4))
	var open: int = GenRoom.open_postings(board)
	TestFixtures.check(res, "gen step: room counts drafts", open == 3, "2 own and 1 campaign draft read %d" % open)
	var room: int = GenRoom.room(board, 5)
	var floor_room: int = GenRoom.room(board, 2)
	TestFixtures.check(res, "gen step: room never below zero", room == 2 and floor_room == 0,
		"cap 5 room %d (want 2), cap 2 room %d (want 0)" % [room, floor_room])
