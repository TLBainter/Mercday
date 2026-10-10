class_name HirePoolTests
#The weekly hire pool, job posting rolls, the pro-rated first pay and the red gate; run from SalaryTests.

const SEED: int = 4242
const ROSTER_FOR_TIMING: int = 20
const FUNDS: int = 5000
const BUDGET: int = 1350


static func add_cases(res: Dictionary) -> void:
	var held_seed: int = PromotionsManager.fixed_seed
	PromotionsManager.fixed_seed = SEED
	_case_numbers(res)
	_case_job_rolls(res)
	_case_fit(res)
	_case_start_pool(res)
	_case_refresh(res)
	_case_landing(res)
	_case_charge(res)
	_case_hire(res)
	_case_timing(res)
	PromotionsManager.fixed_seed = held_seed
	GameState.start_new_game()
	PromotionsManager.reset()


static func _check(res: Dictionary, label: String, passed: bool, why: String) -> void:
	TestFixtures.check(res, "hire pool: " + label, passed, why)


static func _fresh() -> void:
	GameState.start_new_game()
	PromotionsManager.reset()


#Launches a job posting with the bank and the budget topped up, so the launch is never refused for money.
static func _launch(spec: Dictionary) -> CampaignData:
	var cap: int = maxi(30, int(SubscriptionManager.entitlements().get("maxPromoDays", 0)))
	SubscriptionManager.set_entitlements({"promotions": true, "jobPostings": true, "maxPromoDays": cap})
	GameState.bank_notes = maxi(GameState.bank_notes, FUNDS)
	TestFixtures.fund_budget(BUDGET)
	return TestFixtures.launch_campaign(spec)


static func _minute(day: int) -> int:
	return day * TrynnCalendar.MINUTES_PER_DAY + 8 * TrynnCalendar.MINUTES_PER_HOUR


static func _refresh_minute(after_day: int, want_refresh: bool) -> int:
	var day: int = after_day
	while HirePool.is_refresh_day(TrynnCalendar.date_of(_minute(day))) != want_refresh:
		day += 1
	return _minute(day)


static func _pool_cards() -> Array[ApplicantData]:
	var out: Array[ApplicantData] = []
	for a: ApplicantData in PromotionsManager.applicants:
		if a.pool:
			out.append(a)
	return out


static func _ids(list: Array[ApplicantData]) -> Array[int]:
	var out: Array[int] = []
	for a: ApplicantData in list:
		out.append(a.id)
	return out


static func _case_numbers(res: Dictionary) -> void:
	var caps: Array[int] = [HirePool.pool_cap(3, 5), HirePool.pool_cap(0, 5), HirePool.pool_cap(3, 8),
		HirePool.pool_cap(0, 0)]
	_check(res, "pool_cap", caps == [8, 2, 10, 1], str(caps))
	var sizes: Array[int] = []
	for cap: int in [8, 2, 10]:
		for op: float in [0.0, 0.5, 1.0]:
			sizes.append(HirePool.pool_size(op, cap))
	_check(res, "pool_size", sizes == [1, 5, 8, 1, 2, 2, 1, 6, 10], str(sizes))
	var draws: Array[int] = [HirePool.quality_draws(0.0), HirePool.quality_draws(0.5), HirePool.quality_draws(1.0)]
	_check(res, "quality_draws", draws == [1, 2, 3], str(draws))
	var both: float = HirePool.overall_opinion([SalarySystem.OPINION_MAX], [0])
	var merc_only: float = HirePool.overall_opinion([SalarySystem.OPINION_MAX], [])
	var client_only: float = HirePool.overall_opinion([], [50])
	var none: float = HirePool.overall_opinion([], [])
	_check(res, "overall_opinion sides", is_equal_approx(both, 0.5) and is_equal_approx(merc_only, 1.0)
		and is_equal_approx(client_only, 0.5) and is_equal_approx(none, HirePool.NEUTRAL_OPINION),
		"%s %s %s %s" % [both, merc_only, client_only, none])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var lo: int = 999
	var hi: int = -1
	var sum: int = 0
	for _i: int in 1000:
		var lv: int = HirePool.level_for(10.0, rng)
		lo = mini(lo, lv)
		hi = maxi(hi, lv)
		sum += lv
	var mean: float = sum / 1000.0
	_check(res, "level_for centre 10", lo >= 3 and hi <= 12 and mean >= 6.6 and mean <= 7.4,
		"lo %d hi %d mean %.2f" % [lo, hi, mean])
	var ones: bool = true
	for _i: int in 200:
		ones = ones and HirePool.level_for(1.0, rng) == 1
	_check(res, "level_for centre 1", ones, "a draw left level 1")
	var charges: Array[int] = [HirePool.hire_charge(30, 15, 30), HirePool.hire_charge(30, 39, 40),
		HirePool.hire_charge(10, 1, 30), HirePool.hire_charge(30, 0, 30), HirePool.hire_charge(30, 60, 30)]
	_check(res, "hire_charge", charges == [15, 30, 1, 0, 30], str(charges))
	_check(res, "job_quality", is_equal_approx(HirePool.job_quality(0.4, 1.0), 0.85)
		and is_equal_approx(HirePool.job_quality(0.3, 0.0), 0.3), str(HirePool.job_quality(0.4, 1.0)))
	var weekdays: Array[bool] = []
	for wd: int in 7:
		weekdays.append(HirePool.is_refresh_day({"weekday": wd}))
	_check(res, "refresh weekday 1 only", weekdays.count(true) == 1 and weekdays[HirePool.REFRESH_WEEKDAY],
		str(weekdays))


static func _case_job_rolls(res: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var active: Array[String] = ["tradition"]
	var days_hit: int = 0
	var zero_hits: int = 0
	for _i: int in 1000:
		if not GenPromo.roll(12.0, active, rng).is_empty():
			days_hit += 1
		zero_hits += GenPromo.roll(0.0, active, rng).size()
	_check(res, "effect 12 lands on 9% to 15% of days", days_hit >= 90 and days_hit <= 150, "%d of 1000" % days_hit)
	_check(res, "effect 0 lands none", zero_hits == 0, "%d hits" % zero_hits)
	_fresh()
	var campaign: CampaignData = _launch({"name": "Pool Job"})
	_check(res, "job posting next_arrival_day -1", campaign != null and campaign.next_arrival_day == -1,
		"null" if campaign == null else str(campaign.next_arrival_day))
	if campaign == null:
		return
	var rows: Array[Dictionary] = PromotionsManager.job_campaigns()
	_check(res, "job_campaigns lists the posting", rows.size() == 1 and int(rows[0]["id"]) == campaign.id
		and float(rows[0]["effect"]) > 0.0, str(rows))
	var cap: int = HirePool.pool_cap(PromotionsManager.free_slots(), PromotionsManager.max_mercs())
	while PromotionsManager.open_applicants() < cap:
		PromotionsManager.land_applicant(campaign)
	var before: int = PromotionsManager.open_applicants()
	var results_before: int = PromotionsManager.results_of(campaign)
	var day: int = GameState.day() + 1
	for _i: int in 60:
		var at: int = _refresh_minute(day, false)
		PromotionsManager.hire_round(at)
		day = TrynnCalendar.day_index(at) + 1
	_check(res, "job roll at the cap lands nothing", PromotionsManager.open_applicants() == before
		and PromotionsManager.results_of(campaign) == results_before,
		"%d -> %d" % [before, PromotionsManager.open_applicants()])
	_fresh()
	var trad: String = TraitFilterDefs.traditions()[0]
	var picky: CampaignData = _launch({"name": "Picky", "traditions": [trad]})
	if picky == null:
		_check(res, "launch Picky", false, "refused")
		return
	var rows2: Array[Dictionary] = PromotionsManager.job_campaigns()
	var active2: Array = rows2[0]["active"] if not rows2.is_empty() else []
	_check(res, "job_campaigns active keys", active2 == ["tradition"], str(active2))
	var held: bool = true
	for _i: int in 4:
		var card: ApplicantData = PromotionsManager.land_applicant(picky, {"criteria": ["tradition"], "match_pct": 1.0})
		held = held and card.tradition == trad
	_check(res, "an applied filter holds", held, "tradition %s not kept" % trad)


static func _case_fit(res: Dictionary) -> void:
	_fresh()
	var open: Array[ContractData] = []
	for entry: BoardEntry in GameState.board.available():
		if entry != null and entry.contract != null:
			open.append(entry.contract)
	if open.is_empty() or GameState.mercs.is_empty():
		_check(res, "fit fixtures", false, "board %d mercs %d" % [open.size(), GameState.mercs.size()])
		return
	var none: Array[MercenaryData] = []
	_check(res, "needs with no roster is every contract", HirePool.needs(open, none).size() == open.size(),
		str(HirePool.needs(open, none).size()))
	var m: MercenaryData = GameState.mercs[0]
	var c: ContractData = open[0]
	var stars: float = MatchScore.stars(MatchScore.solo_net(c, m))
	var one: Array[MercenaryData] = [m]
	var excluded: bool = HirePool.needs([c], one).is_empty()
	_check(res, "needs excludes a contract matched at 3.5 stars", excluded == (stars >= HirePool.GOOD_MATCH_STARS),
		"stars %.2f excluded %s" % [stars, excluded])
	var single: Array[ContractData] = [c]
	_check(res, "fit is the stars of the one need", is_equal_approx(HirePool.fit(m, single), stars),
		"%.2f vs %.2f" % [HirePool.fit(m, single), stars])
	var empty: Array[ContractData] = []
	_check(res, "fit without contracts is 0", HirePool.fit(m, empty) == 0.0 and HirePool.fit(null, open) == 0.0, "")


static func _case_start_pool(res: Dictionary) -> void:
	GameState.start_new_game()
	var pool: Array[ApplicantData] = _pool_cards()
	var shape: bool = true
	for a: ApplicantData in pool:
		shape = shape and a.campaign_id == ApplicantData.WALK_IN and PromotionsManager.merc_of(a) != null
	_check(res, "a new game holds exactly 3 pool applicants", pool.size() == HirePool.POOL_START
		and PromotionsManager.applicants.size() == HirePool.POOL_START and shape,
		"%d pool of %d" % [pool.size(), PromotionsManager.applicants.size()])
	var start_hires: int = 0
	for row: TransactionData in FinanceLedger.rows():
		if row.reason == GameState.REASON_HIRE:
			start_hires += 1
	_check(res, "a start merc pays nothing", start_hires == 0, "%d hire rows" % start_hires)
	PromotionsManager.reset()
	_check(res, "reset after a new game leaves 0", PromotionsManager.applicants.is_empty(),
		str(PromotionsManager.applicants.size()))


static func _case_refresh(res: Dictionary) -> void:
	GameState.start_new_game()
	var start: Array[int] = _ids(_pool_cards())
	var counted: ApplicantData = _pool_cards()[0]
	counted.status = ApplicantData.STATUS_COUNTERED
	var campaign: CampaignData = _launch({"name": "Keep Me"})
	if campaign == null:
		_check(res, "launch Keep Me", false, "refused")
		return
	var job_card: ApplicantData = PromotionsManager.land_applicant(campaign)
	var count_before: int = PromotionsManager.applicants.size()
	PromotionsManager.hire_round(_refresh_minute(GameState.day() + 1, false))
	_check(res, "no refresh off weekday 1", PromotionsManager.applicants.size() == count_before,
		"%d -> %d" % [count_before, PromotionsManager.applicants.size()])
	PromotionsManager.hire_round(_refresh_minute(GameState.day() + 1, true))
	var after: Array[int] = _ids(_pool_cards())
	var replaced: bool = true
	for id: int in start:
		if id != counted.id and after.has(id):
			replaced = false
	_check(res, "refresh replaces pool applicants", replaced and after.size() > 1, "%s -> %s" % [start, after])
	_check(res, "refresh keeps a pending counter", PromotionsManager.applicants.has(counted)
		and PromotionsManager.merc_of(counted) != null, "countered card dropped")
	_check(res, "refresh leaves campaign applicants", PromotionsManager.applicants.has(job_card), "job card dropped")
	GameState.start_new_game()
	var n0: int = PromotionsManager.applicants.size()
	TestFixtures.pass_days(maxi(0, 132 - GameState.day()))
	_check(res, "pass_days across day 131 adds nothing", PromotionsManager.applicants.size() == n0,
		"%d -> %d" % [n0, PromotionsManager.applicants.size()])
	var runs: Array[String] = []
	for _run: int in 2:
		GameState.start_new_game()
		var shape: Array[int] = []
		for a: ApplicantData in PromotionsManager.applicants:
			shape.append(a.level)
		PromotionsManager.hire_round(_refresh_minute(GameState.day() + 1, true))
		shape.append(-1)
		for a: ApplicantData in PromotionsManager.applicants:
			shape.append(a.level)
		runs.append(str(shape))
	_check(res, "seeded pool repeats sizes and levels", runs[0] == runs[1], "%s vs %s" % [runs[0], runs[1]])


static func _case_landing(res: Dictionary) -> void:
	_fresh()
	var campaign: CampaignData = _launch({"name": "Count"})
	if campaign == null:
		_check(res, "launch Count", false, "refused")
		return
	var r0: int = PromotionsManager.results_of(campaign)
	var a: ApplicantData = PromotionsManager.land_applicant(campaign)
	var b: ApplicantData = PromotionsManager.land_applicant(campaign)
	var r2: int = PromotionsManager.results_of(campaign)
	_check(res, "land_applicant credits 1 per card", r2 == r0 + 2 and a.campaign_id == campaign.id
		and not a.pool, "%d -> %d" % [r0, r2])
	PromotionsManager.reject(b.id)
	var r3: int = PromotionsManager.results_of(campaign)
	PromotionsManager.hire(a.id, a.ask)
	var r4: int = PromotionsManager.results_of(campaign)
	_check(res, "reject and hire keep the credit", r3 == r2 and r4 == r2, "%d %d %d" % [r2, r3, r4])
	var cap: int = HirePool.pool_cap(PromotionsManager.free_slots(), PromotionsManager.max_mercs())
	for _i: int in cap + 2:
		PromotionsManager.land_applicant(campaign)
	_check(res, "land_applicant applies no cap", PromotionsManager.open_applicants() >= cap + 2,
		"%d open, cap %d" % [PromotionsManager.open_applicants(), cap])
	var card: ApplicantData = PromotionsManager.land_applicant(campaign)
	var ask: int = card.ask
	var stamped: int = PromotionsManager.merc_of(card).salary_ask
	TestFixtures.add_mercs(3)
	_check(res, "the ask is frozen at arrival", card.ask == ask and stamped == ask
		and PromotionsManager.merc_of(card).salary_ask == ask, "%d %d" % [ask, card.ask])


static func _case_charge(res: Dictionary) -> void:
	_fresh()
	var day122: int = PromotionsManager.hire_charge_for(40)
	_check(res, "day 122 at salary 40 charges 39", GameState.day() == 122 and day122 == 39,
		"day %d charge %d" % [GameState.day(), day122])
	var payday: int = GameState.next_payday_minute()
	CampaignClock.advance_to(payday - TrynnCalendar.MINUTES_PER_HOUR)
	var before_hour: int = PromotionsManager.hire_charge_for(40)
	CampaignClock.advance_to(payday + TrynnCalendar.MINUTES_PER_HOUR)
	var after_hour: int = PromotionsManager.hire_charge_for(40)
	_check(res, "payday before SALARY_HOUR charges 0, after it the salary", before_hour == 0 and after_hour == 40,
		"%d %d" % [before_hour, after_hour])


static func _case_hire(res: Dictionary) -> void:
	_fresh()
	var campaign: CampaignData = _launch({"name": "Hire"})
	if campaign == null:
		_check(res, "launch Hire", false, "refused")
		return
	var a: ApplicantData = PromotionsManager.land_applicant(campaign)
	var charge: int = PromotionsManager.hire_charge_for(a.ask)
	var bank0: int = GameState.bank_notes
	var ok: bool = PromotionsManager.hire(a.id, a.ask)
	var row: TransactionData = FinanceLedger.rows(1)[0] if not FinanceLedger.rows(1).is_empty() else null
	_check(res, "a hire charges the pro-rated pay", ok and GameState.bank_notes == bank0 - charge and charge > 0
		and row != null and row.reason == GameState.REASON_HIRE, "%d -> %d charge %d" % [bank0, GameState.bank_notes,
		charge])
	var c: ApplicantData = PromotionsManager.land_applicant(campaign)
	var offer: int = maxi(1, c.ask - 1)
	PromotionsManager.counter(c.id, offer)
	c.counter_odds = 100
	var bank1: int = GameState.bank_notes
	var charge1: int = PromotionsManager.hire_charge_for(offer)
	PromotionsManager._resolve_counter(c)
	_check(res, "a counter-accept charges the same", c.status == ApplicantData.STATUS_HIRED
		and GameState.bank_notes == bank1 - charge1, "%d -> %d charge %d" % [bank1, GameState.bank_notes, charge1])
	var d: ApplicantData = PromotionsManager.land_applicant(campaign)
	var need: int = PromotionsManager.hire_charge_for(d.ask)
	GameState.bank_notes = need - 1
	var short: Dictionary = PromotionsManager.can_hire(d.id, d.ask)
	GameState.bank_notes = need
	var even: Dictionary = PromotionsManager.can_hire(d.id, d.ask)
	_check(res, "a bank one short of the charge refuses, the charge allows", not bool(short["ok"]) and bool(even["ok"]),
		"%s / %s" % [short, even])
	GameState.bank_notes = -1
	var red_hire: Dictionary = PromotionsManager.can_hire(d.id, d.ask)
	var red_counter: Dictionary = PromotionsManager.can_counter(d.id, maxi(1, d.ask - 1))
	_check(res, "in the red hire and counter refuse", not bool(red_hire["ok"]) and not bool(red_counter["ok"])
		and String(red_hire["reason"]) == PromotionsManager.RED_TEXT
		and String(red_counter["reason"]) == "The guild is in the red.", "%s / %s" % [red_hire, red_counter])
	GameState.bank_notes = GameState.START_BANK


static func _case_timing(res: Dictionary) -> void:
	_fresh()
	TestFixtures.add_mercs(maxi(0, ROSTER_FOR_TIMING - GameState.mercs.size()))
	PromotionsManager.fill_start_pool()
	var at: int = _refresh_minute(GameState.day() + 1, true)
	var t0: int = Time.get_ticks_usec()
	PromotionsManager.hire_round(at)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("HIRE POOL REFRESH MS %.1f roster %d pool %d" % [ms, GameState.mercs.size(), _pool_cards().size()])
	_check(res, "refresh at a 20 merc roster under 250 ms", GameState.mercs.size() == ROSTER_FOR_TIMING and ms < 250.0,
		"%.1f ms roster %d" % [ms, GameState.mercs.size()])
