class_name SimTests
#Playability sim checks: thresholds and counters on synthetic data, the request builder, GenTune, a 3-day smoke run.

const RULE_NAMES: Array[String] = ["bank floor", "generated per week", "roster empty run", "success rate",
	"mercs by day", "value bands"]
const DISPATCH_KEYS: Array[String] = ["evaluated", "no_pool", "low_p", "no_team", "no_fare", "dispatch_failed"]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_thresholds(res)
	_case_counters(res)
	_case_gen_set(res)
	await _case_smoke(res, host)
	_case_request(res)
	return TestFixtures.summarize(res, "SIM")


#A series every rule holds on; each broken copy breaks exactly one rule.
static func _good_series() -> Dictionary:
	var mercs: Array = []
	for day: int in SimThresholds.MERCS_BY_DAY:
		mercs.append(2 if day < 10 else SimThresholds.MERCS_TARGET)
	var values: Array = []
	var levels: Array = []
	for i: int in SimThresholds.BAND_MIN_SAMPLES:
		values.append(GenValue.anchor(5))
		levels.append(5.0)
	return {"bank": [100, 40, 0], "weeks": [{"gen": 1, "partial": true}, {"gen": SimThresholds.GEN_MIN_PER_WEEK,
		"partial": false}], "roster_open": [1, 0, 0, 0, 2], "mercs": mercs, "succeeded": 6, "failed": 4,
		"values": values, "levels": levels}


static func _broken(rule: int) -> Dictionary:
	var s: Dictionary = _good_series()
	match rule:
		0:
			s["bank"] = [100, -1, 50]
		1:
			s["weeks"] = [{"gen": SimThresholds.GEN_MIN_PER_WEEK - 1, "partial": false}]
		2:
			s["roster_open"] = [1, 0, 0, 0, 0, 1]
		3:
			s["succeeded"] = 9
			s["failed"] = 1
		4:
			var low: Array = []
			low.resize(SimThresholds.MERCS_BY_DAY)
			low.fill(SimThresholds.MERCS_TARGET - 1)
			s["mercs"] = low
		5:
			var high: Array = []
			for value: Variant in (s["values"] as Array):
				high.append(float(value) * (1.0 + 2.0 * SimThresholds.BAND_TOLERANCE))
			s["values"] = high
	return s


static func _case_thresholds(res: Dictionary) -> void:
	var good: Array[Dictionary] = SimReport.thresholds(_good_series())
	for i: int in RULE_NAMES.size():
		var rule: Dictionary = good[i]
		TestFixtures.check(res, "the %s rule holds on a passing series" % RULE_NAMES[i], bool(rule["held"]),
			"%s: %s" % [str(rule["name"]), str(rule["text"])])
		var broken: Dictionary = SimReport.thresholds(_broken(i))[i]
		TestFixtures.check(res, "the %s rule breaks on a failing series" % RULE_NAMES[i], not bool(broken["held"]),
			"%s: %s" % [str(broken["name"]), str(broken["text"])])


static func _entry(status: String, expires: int) -> BoardEntry:
	var entry: BoardEntry = BoardEntry.new()
	entry.status = status
	entry.expires_minute = expires
	return entry


static func _case_counters(res: Dictionary) -> void:
	var c: Dictionary = SimCounters.new_state(0)
	var moved: BoardEntry = _entry(BoardEntry.STATUS_POOLED, 2000)
	var lapsed: BoardEntry = _entry(BoardEntry.STATUS_POOLED, 2000)
	var cut: BoardEntry = _entry(BoardEntry.STATUS_DRAFT, 1000)
	var timed: BoardEntry = _entry(BoardEntry.STATUS_DRAFT, 1000)
	SimCounters.snapshot(c, [moved, lapsed] as Array[BoardEntry], [cut, timed] as Array[BoardEntry], 3)
	var fresh_pool: BoardEntry = _entry(BoardEntry.STATUS_POOLED, 3000)
	var fresh_board: BoardEntry = _entry(BoardEntry.STATUS_DRAFT, 3000)
	fresh_pool.quality = 1.25
	fresh_pool.distance_km = 40
	fresh_board.quality = 0.75
	fresh_board.distance_km = 120
	moved.status = BoardEntry.STATUS_DRAFT
	cut.status = BoardEntry.STATUS_EXPIRED
	cut.expires_minute = 900
	timed.status = BoardEntry.STATUS_EXPIRED
	var change: Dictionary = SimCounters.diff(c, [fresh_pool] as Array[BoardEntry],
		[moved, cut, timed, fresh_board] as Array[BoardEntry])
	var generated: Array[BoardEntry] = change["generated"]
	TestFixtures.check(res, "entries unseen at the snapshot count as generated, pool or board",
		generated.size() == 2 and generated.has(fresh_pool) and generated.has(fresh_board), "%d" % generated.size())
	TestFixtures.check(res, "board entries absent at the snapshot count as provisioned",
		int(change["provisioned"]) == 2, "%d" % int(change["provisioned"]))
	TestFixtures.check(res, "a pooled entry gone without reaching the board counts as pool expired",
		int(change["pool_expired"]) == 1, "%d" % int(change["pool_expired"]))
	TestFixtures.check(res, "only a Draft expired before its first-seen minute counts as auto-rejected",
		int(change["auto_rejected"]) == 1, "%d" % int(change["auto_rejected"]))
	var day: int = 3 * TrynnCalendar.WEEKDAYS.size() + 4
	SimCounters.add_round(c, change, day, 7.0)
	TestFixtures.check(res, "a folded round adds its generated entries to the week and the band samples",
		SimCounters.week_generated(c, 3) == 2 and SimCounters.week_generated(c, 2) == 0
		and (c["values"] as Array).size() == 2 and (c["levels"] as Array) == [7.0, 7.0],
		"week %d samples %d" % [SimCounters.week_generated(c, 3), (c["values"] as Array).size()])
	TestFixtures.check(res, "a folded round records each generated entry's quality and distance",
		(c["qualities"] as Array) == [1.25, 0.75] and (c["kms"] as Array) == [40, 120],
		"qualities %s kms %s" % [c["qualities"], c["kms"]])
	var rows: Array[Dictionary] = SimReport.band_rows(c["values"], c["levels"], c["qualities"], c["kms"])
	var row: Dictionary = rows[SimReport.band_of(7.0)]
	TestFixtures.check(res, "the band table averages quality and distance over the band's samples",
		int(row["n"]) == 2 and is_equal_approx(float(row["mean_q"]), 1.0) and is_equal_approx(float(row["mean_km"]), 80.0),
		"n %d mean_q %.2f mean_km %.1f" % [int(row["n"]), float(row["mean_q"]), float(row["mean_km"])])
	_case_dispatch_keys(res)


#Fresh state holds every dispatch skip counter at 0; one bookkeeping pass bumps only the key it names.
static func _case_dispatch_keys(res: Dictionary) -> void:
	var c: Dictionary = SimCounters.new_state(0)
	var zeros: bool = typeof(c.get("p_max")) == TYPE_FLOAT and float(c["p_max"]) == 0.0
	var shown: Array = []
	for key: String in DISPATCH_KEYS:
		zeros = zeros and c.has(key) and int(c[key]) == 0
		shown.append(c.get(key))
	TestFixtures.check(res, "new sim state starts every dispatch skip counter and p_max at 0", zeros,
		"counters %s p_max %s" % [shown, c.get("p_max")])
	SimPolicy.tally(c, "no_fare")
	var others: bool = true
	for key: String in DISPATCH_KEYS:
		others = others and (key == "no_fare" or int(c[key]) == 0)
	TestFixtures.check(res, "a dispatch bookkeeping pass bumps its own counter and leaves the rest at 0",
		int(c["no_fare"]) == 1 and others, "no_fare %d" % int(c["no_fare"]))


static func _case_gen_set(res: Dictionary) -> void:
	var before: Dictionary = {}
	for key: String in GenTune.keys():
		before[key] = GenTune.value(key)
	GenTune.reset()
	var target: float = snappedf(GenTune.value("LIKELY_BASE") + 0.05, 0.01)
	var errors: Array[String] = GenTune.apply_spec("LIKELY_BASE:%s" % str(target))
	var header: Array[String] = SimReport.header_lines(1, 1, "FREE")
	var shown: bool = false
	for line: String in header:
		shown = shown or (line.begins_with("GEN SET: LIKELY_BASE") and line.ends_with(str(target)))
	TestFixtures.check(res, "a --gen-set spec changes a constant the sim header reports",
		errors.is_empty() and is_equal_approx(GenTune.value("LIKELY_BASE"), target) and shown,
		"errors %s header %s" % [errors, header])
	GenTune.reset()
	for key: String in before:
		GenTune.set_value(key, before[key])


static func _case_smoke(res: Dictionary, host: Node) -> void:
	var printed: int = PlaySim.summaries
	var result: Variant = await PlaySim.run(host, 3, 7)
	TestFixtures.check(res, "a 3-day sim returns a bool", typeof(result) == TYPE_BOOL, "type %d" % typeof(result))
	TestFixtures.check(res, "a 3-day sim prints one summary line", PlaySim.summaries == printed + 1,
		"summaries %d -> %d" % [printed, PlaySim.summaries])


static func _case_request(res: Dictionary) -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	var roster: Array[MercView] = GameState.roster
	var entry: BoardEntry = GameState.board.entries[0] if not GameState.board.entries.is_empty() else null
	if roster.size() < 2 or entry == null or entry.contract == null:
		TestFixtures.check(res, "a new game offers two mercs and a posting for the request cases", false,
			"roster %d entry %s" % [roster.size(), entry])
		return
	var busy: Array[int] = [roster[0].uid]
	var pool: Array[MercView] = SimPolicy.candidates(roster, busy)
	var view: ContractView = ContractView.from_entry(entry, CampaignClock.now())
	view.merc_min = 3
	view.merc_max = DispatchWindow.SLOT_COUNT + 4
	var wide: Dictionary = SimPolicy.request_for(view, pool, [] as Array[String], 0, [] as Array[ContractData])
	var uids: Array[int] = wide["uids"]
	TestFixtures.check(res, "the request leaves out busy mercs and keeps the free ones",
		not uids.has(roster[0].uid) and uids.has(roster[1].uid) and uids.size() == roster.size() - 1,
		"uids %s busy %s" % [uids, busy])
	TestFixtures.check(res, "a wide posting caps the team at the dispatch slots",
		int(wide["cap"]) == DispatchWindow.SLOT_COUNT and int(wide["lo"]) == 3 and int(wide["seed"]) == view.entry_id,
		"lo %d cap %d" % [int(wide["lo"]), int(wide["cap"])])
	view.merc_max = 2
	var narrow: Dictionary = SimPolicy.request_for(view, pool, [] as Array[String], 0, [] as Array[ContractData])
	TestFixtures.check(res, "lo never exceeds the posting's cap", int(narrow["lo"]) == 2 and int(narrow["cap"]) == 2,
		"lo %d cap %d" % [int(narrow["lo"]), int(narrow["cap"])])
