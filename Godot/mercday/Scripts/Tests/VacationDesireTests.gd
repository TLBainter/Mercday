class_name VacationDesireTests

#Vacation desire v2 (Mail plan 3.6): terms, shape, curve, accumulators and the stat-key check.
#Plan tests 68-73, 75, 83-86 and 99. Run inside the gui-mail-tests harness flag.

const PROBE_UID: int = 990001
const GONE_UID: int = 990002
const POOL: int = 10
const HALF: int = 5
const STEPS: int = 20
const NEAR: float = 0.01
const TINY: float = 0.000001
const WILE: Array[float] = [4.0, 2.0, 0.0]
const VIGOR: Array[float] = [4.0, 2.0, 0.0]
const HEALTH: Array[float] = [50.0, 0.0, -50.0]
const FURLOUGH: Array[float] = [0.0, 20.0, 330.0]
const DEFICIT: Array[float] = [0.0, 30.0, 120.0]
const OPINION: Array[int] = [5, 1, -5]
const RELATION: Array[int] = [10, 3, 0]
const FAIL: Array[float] = [0.0, 1.0, 3.0]
const SWEEP: Array[String] = ["furlough", "deficit", "sev", "opinion", "relation", "health", "fail"]
const SHAPE_IN: Array[float] = [0.25, 0.5, 0.75, 0.9, 1.0]
const SHAPE_OUT: Array[float] = [17.97, 31.25, 53.91, 77.85, 100.0]
const STAT_KEYS: Array[String] = ["healthiness", "wile", "vigor"]


#Counts the error lines that name a missing healthiness stat; hears them through OS.add_logger.
class ErrorLog extends Logger:
	var hits: int = 0

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_ERROR and (code + rationale).contains("healthiness"):
			hits += 1


static func run(res: Dictionary) -> void:
	_fresh()
	_case_endpoints(res)
	_case_term(res)
	_case_peer(res)
	_case_monotonic(res)
	_case_curve(res)
	_case_length(res)
	_case_deficit(res)
	_case_vulnerability(res)
	_case_accumulator(res)
	_case_shape(res)
	_case_stat_keys(res)
	CampaignKnowledge.forget(PROBE_UID)


static func _fresh() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


static func _peer() -> MercenaryData:
	return GameState.mercs[0]


#A merc with every desire input at best (0), average (1) or worst (2); its one tracked pair is toward roster merc 0.
static func _probe(level: int) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_uid = PROBE_UID
	m.merc_name = "Probe"
	m.stats = {"wile": WILE[level], "vigor": VIGOR[level], "healthiness": HEALTH[level], RestSystem.MAX_HP: POOL,
		RestSystem.MAX_EP: POOL, RestSystem.MAX_MP: POOL}
	m.current_hp = POOL if level == 0 else HALF
	m.current_ep = POOL
	m.current_mp = POOL
	m.furlough_pressure = FURLOUGH[level]
	m.deficit_pressure = DEFICIT[level]
	m.guild_opinion = OPINION[level]
	m.fail_stress = FAIL[level]
	CampaignKnowledge.forget(PROBE_UID)
	CampaignKnowledge.set_relation(PROBE_UID, _peer().merc_uid, RELATION[level])
	return m


static func _near(a: float, b: float, tol: float = NEAR) -> bool:
	return absf(a - b) <= tol


static func _case_endpoints(res: Dictionary) -> void:
	var got: Array[float] = [VacationDesire.compute(_probe(1)), VacationDesire.compute(_probe(0)),
		VacationDesire.compute(_probe(2))]
	TestFixtures.check(res, "68 every input at average = 0, at best = -100, at worst = +100",
		_near(got[0], 0.0) and _near(got[1], -100.0) and _near(got[2], 100.0), str(got))


static func _case_term(res: Dictionary) -> void:
	var rising: Array[float] = []
	for x: float in [20.0, 0.0, 330.0, -5.0, 400.0]:
		rising.append(VacationDesire.term(x, 0.0, 20.0, 330.0))
	var falling: Array[float] = []
	for x: float in [1.0, 5.0, -5.0, 9.0, -9.0]:
		falling.append(VacationDesire.term(x, 5.0, 1.0, -5.0))
	var want: Array[float] = [0.0, -1.0, 1.0, -1.0, 1.0]
	var past: MercenaryData = _probe(2)
	past.furlough_pressure = 400.0
	past.fail_stress = 5.0
	TestFixtures.check(res, "69 term is 0 at avg, -1 at best, +1 at worst and clamps past both; beyond worst stays +100",
		rising == want and falling == want and _near(VacationDesire.compute(past), 100.0),
		"%s %s %.3f" % [rising, falling, VacationDesire.compute(past)])


static func _case_peer(res: Dictionary) -> void:
	var lone: MercenaryData = _probe(2)
	CampaignKnowledge.forget(PROBE_UID)
	var untracked: float = VacationDesire.mean_relation(lone)
	var no_pair: float = VacationDesire.compute(lone)
	TestFixtures.check(res, "70 no tracked pair gives tP 0 (all else worst reads shape(0.9) = 77.85)",
		_near(untracked, -1.0, TINY) and _near(no_pair, 77.85), "mean %.3f desire %.3f" % [untracked, no_pair])
	var gone: MercenaryData = GameState.mercs[1]
	CampaignKnowledge.set_relation(PROBE_UID, _peer().merc_uid, 10)
	CampaignKnowledge.set_relation(PROBE_UID, gone.merc_uid, 0)
	CampaignKnowledge.set_relation(PROBE_UID, GONE_UID, 0)
	var with_both: float = VacationDesire.mean_relation(lone)
	gone.is_dead = true
	var without: float = VacationDesire.mean_relation(lone)
	gone.is_dead = false
	TestFixtures.check(res, "70 a removed merc's relation entry is left out of the mean",
		_near(with_both, 5.0, TINY) and _near(without, 10.0, TINY), "both %.2f without %.2f" % [with_both, without])


static func _set_input(m: MercenaryData, key: String, t: float) -> void:
	match key:
		"furlough":
			m.furlough_pressure = lerpf(FURLOUGH[0], FURLOUGH[2], t)
		"deficit":
			m.current_hp = HALF
			m.deficit_pressure = lerpf(DEFICIT[0], DEFICIT[2], t)
		"sev":
			m.deficit_pressure = DEFICIT[2]
			m.current_hp = POOL - roundi(t * HALF)
		"opinion":
			m.guild_opinion = roundi(lerpf(OPINION[0], OPINION[2], t))
		"relation":
			CampaignKnowledge.set_relation(PROBE_UID, _peer().merc_uid, roundi(lerpf(RELATION[0], RELATION[2], t)))
		"health":
			m.stats["healthiness"] = lerpf(HEALTH[0], HEALTH[2], t)
		"fail":
			m.fail_stress = lerpf(FAIL[0], FAIL[2], t)


static func _case_monotonic(res: Dictionary) -> void:
	var bad: Array[String] = []
	for key: String in SWEEP:
		var m: MercenaryData = _probe(0)
		var last: float = -INF
		var first: float = 0.0
		for i: int in range(STEPS + 1):
			_set_input(m, key, i / float(STEPS))
			var d: float = VacationDesire.compute(m)
			first = d if i == 0 else first
			if d < last - TINY:
				bad.append("%s step %d" % [key, i])
			last = d
		if last <= first:
			bad.append("%s flat %.2f" % [key, last])
	TestFixtures.check(res, "71 each input alone from best to worst never lowers desire over 20 steps", bad.is_empty(),
		str(bad))


static func _case_curve(res: Dictionary) -> void:
	var chances: Array[float] = [VacationDesire.daily_chance(0.0), VacationDesire.daily_chance(0.5),
		VacationDesire.daily_chance(10.0), VacationDesire.daily_chance(50.0), VacationDesire.daily_chance(100.0)]
	var shaped: bool = chances[0] == 0.0 and chances[1] == 0.0 and _near(chances[2], 0.0006, TINY)
	shaped = shaped and _near(chances[3], 0.015, TINY) and _near(chances[4], 0.06, TINY)
	var bad: Array[int] = []
	for d: int in range(2, 100):
		var lo: float = VacationDesire.daily_chance(d - 1.0)
		var mid: float = VacationDesire.daily_chance(float(d))
		var hi: float = VacationDesire.daily_chance(d + 1.0)
		if mid < lo or hi - 2.0 * mid + lo < -TINY:
			bad.append(d)
	TestFixtures.check(res, "72 no roll below +1; 0.06%, 1.5%, 6.0% at +10/+50/+100; monotonic and convex",
		shaped and bad.is_empty(), "%s bad %s" % [chances, bad])


static func _case_length(res: Dictionary) -> void:
	var bad: Array[String] = []
	for cap: int in range(1, 13):
		if VacationDesire.length(cap, 1.0) != 1 or VacationDesire.length(cap, 100.0) != cap:
			bad.append("cap %d ends" % cap)
		for d: int in range(1, 101):
			var days: int = VacationDesire.length(cap, float(d))
			if days < 1 or days > cap:
				bad.append("cap %d d %d -> %d" % [cap, d, days])
	var uid: int = _peer().merc_uid
	var book := VacationBook.new()
	var today: int = GameState.day()
	var caps: Array[int] = [book.wish_cap(uid, today)]
	BenefitsManager.set_vacation({"start": 30})
	caps.append(book.wish_cap(uid, today))
	BenefitsManager.add_vacation_taken(uid, BenefitsManager.vacation_days_left(uid))
	caps.append(book.wish_cap(uid, today))
	var crave: MercenaryData = _peer()
	crave.furlough_pressure = 400.0
	var before: int = book.rng.state
	var miss: Vector2i = VacationDesire.wish(crave, book, book.rng, today)
	TestFixtures.check(res, "73 days in [1, cap]; cap = min(free_days, max_len_days); cap < 1 makes no roll",
		bad.is_empty() and caps == [3, 10, 0] and miss == Vector2i(-1, 0) and book.rng.state == before,
		"%s caps %s miss %s" % [bad.slice(0, 5), caps, miss])
	_fresh()


static func _case_deficit(res: Dictionary) -> void:
	var m: MercenaryData = _probe(1)
	m.deficit_pressure = 0.0
	m.current_hp = 8
	var v: float = VacationDesire.vulnerability(m)
	for _i: int in range(3):
		VacationDesire.day_tick(m)
	var grown: float = m.deficit_pressure
	m.current_hp = POOL
	VacationDesire.day_tick(m)
	var zero_start: bool = GameState.mercs.all(func(r: MercenaryData) -> bool:
		return r.furlough_pressure == 0.0 and r.deficit_pressure == 0.0)
	var hired: MercenaryData = TestFixtures.add_mercs(1)[0]
	TestFixtures.check(res, "75 deficit_pressure grows by v a day at sev >= 0.10, resets below; 0 at start and hire",
		_near(grown, 3.0 * v, TINY) and m.deficit_pressure == 0.0 and zero_start and hired.furlough_pressure == 0.0
		and hired.deficit_pressure == 0.0, "grown %.3f v %.3f after %.3f start %s" % [grown, v, m.deficit_pressure,
			zero_start])
	_fresh()


static func _case_vulnerability(res: Dictionary) -> void:
	var v: Array[float] = [VacationDesire.vulnerability(_probe(1)), VacationDesire.vulnerability(_probe(0)),
		VacationDesire.vulnerability(_probe(2))]
	var m: MercenaryData = _probe(2)
	m.furlough_pressure = 0.0
	for _i: int in range(10):
		VacationDesire.day_tick(m)
	TestFixtures.check(res, "83 vulnerability 1.0 / 0.5 / 2.0; furlough_pressure after 10 ticks = 10 x v",
		_near(v[0], 1.0, TINY) and _near(v[1], 0.5, TINY) and _near(v[2], 2.0, TINY)
		and _near(m.furlough_pressure, 10.0 * v[2], TINY), "%s fp %.3f" % [v, m.furlough_pressure])


static func _case_accumulator(res: Dictionary) -> void:
	var m: MercenaryData = _probe(1)
	m.furlough_pressure = 0.0
	for _i: int in range(5):
		VacationDesire.day_tick(m)
	var built: float = m.furlough_pressure
	m.stats["wile"] = WILE[0]
	var v_late: float = VacationDesire.vulnerability(m)
	for _i: int in range(5):
		VacationDesire.day_tick(m)
	TestFixtures.check(res, "84 a Wile rise mid-span alters only later growth; built pressure is not rescaled",
		_near(built, 5.0, TINY) and v_late < 1.0 and _near(m.furlough_pressure, 5.0 + 5.0 * v_late, TINY),
		"built %.3f late v %.3f fp %.3f" % [built, v_late, m.furlough_pressure])


static func _case_shape(res: Dictionary) -> void:
	var got: Array[float] = []
	var ok: bool = true
	for i: int in range(SHAPE_IN.size()):
		got.append(100.0 * VacationDesire.shape(SHAPE_IN[i]))
		ok = ok and _near(got[i], SHAPE_OUT[i], 0.005)
	for s: float in [-1.0, -0.3, 0.0]:
		ok = ok and VacationDesire.shape(s) == s
	for i: int in range(100):
		ok = ok and VacationDesire.shape((i + 1) / 100.0) >= VacationDesire.shape(i / 100.0)
	TestFixtures.check(res, "85 shape gives 17.97/31.25/53.91/77.85/100.00; s <= 0 unchanged; monotonic on [0, 1]", ok,
		str(got))


static func _case_stat_keys(res: Dictionary) -> void:
	var sheet: MercenaryData = TestFixtures.sheet_merc("Hale", 85.0, {"max_vigor": 2, "max_wile": 1})
	var live: Array[String] = DataValidator.require_stat_keys(DataManager.stat_definitions, STAT_KEYS, "VacationDesireTests")
	TestFixtures.check(res, "86 healthiness() reads the Stats.tsv Healthiness key; the live Stats table misses no key",
		sheet.stats.has("healthiness") and VacationDesire.healthiness(sheet) == 50.0
		and VacationDesire.healthiness(sheet) != VacationDesire.HEALTH_AVG and live.is_empty(),
		"health %.2f missing %s" % [VacationDesire.healthiness(sheet), live])
	var bare: MercenaryData = _probe(1)
	bare.stats.erase("healthiness")
	var rows: Array[Dictionary] = []
	for row: Dictionary in DataManager.stat_definitions:
		if String(row["var_name"]) != "healthiness":
			rows.append(row)
	print("VacationDesireTests: the two errors below about a missing healthiness stat are expected")
	var sink: ErrorLog = ErrorLog.new()
	OS.add_logger(sink)
	var read: float = VacationDesire.healthiness(bare)
	var read_errors: int = sink.hits
	var missing: Array[String] = DataValidator.require_stat_keys(rows, STAT_KEYS, "VacationDesireTests")
	OS.remove_logger(sink)
	TestFixtures.check(res, "99 a merc without healthiness push_errors and reads average; the missing key is returned",
		read_errors == 1 and sink.hits == 2 and read == VacationDesire.HEALTH_AVG and missing == ["healthiness"],
		"errors %d then %d read %.2f missing %s" % [read_errors, sink.hits, read, missing])
