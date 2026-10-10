class_name ForecastTests
extends RefCounted

#Run: godot --headless --path . with the --forecast-tests flag.
#ExpenseForecaster and TravelForecaster over hand built ledger rows: the window, the span floor, the trend
#and driver clamps, refunds, mode groups, the no history estimate, and the mode GameState stamps on a fare;
#day-based campaign billing through the real launch path, the benefits forecast and loan origination.

const TODAY: int = 400
const TRIP_KM: int = 60
const FARE: int = 100
const HALF_FARE: int = 50
#Half again as far as TRIP_KM.
const FAR_KM: int = 90
const RUN_KM: int = 75


static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_parent(res)
	_case_history(res)
	_case_refund(res)
	_case_window(res)
	_case_trend(res)
	_case_scale(res)
	_case_fallback(res)
	_case_row_mode(res)
	_case_stamp(res)
	_case_lines(res)
	_case_first_charge(res)
	_case_first_refund(res)
	_case_fixed_bills(res)
	_case_benefits(res)
	_case_loan_origination(res)
	return TestFixtures.summarize(res, "FORECAST")


static func _fare(day: int, mode: String, km: int = TRIP_KM, amount: int = FARE) -> TransactionData:
	var row: TransactionData = TransactionData.make(-amount, 0, "Fare", "Travel", GameState.REASON_TRAVEL,
		mode, km)
	row.day_index = day
	return row


static func _other(day: int) -> TransactionData:
	var row: TransactionData = TransactionData.make(-5, 0, "Guild", "Guild", "guild")
	row.day_index = day
	return row


static func _offer(km: int, crew: int = 1, status: int = GuiTypes.ContractStatus.AVAILABLE) -> ContractView:
	var contract: ContractView = ContractView.new()
	contract.distance_km = km
	contract.merc_min = crew
	contract.status = status
	return contract


static func _travel(offers: Array[ContractView]) -> TravelForecaster:
	var forecaster: TravelForecaster = TravelForecaster.new()
	forecaster.set_offers(offers)
	return forecaster


#Books that began 29 days ago, so the window reads its full 30 days.
static func _books(rows: Array[TransactionData]) -> Array[TransactionData]:
	var out: Array[TransactionData] = [_other(TODAY - 29)]
	out.append_array(rows)
	return out


static func _case_parent(res: Dictionary) -> void:
	var out: Dictionary = ExpenseForecaster.new().forecast(_books([_fare(TODAY - 3, "foot")]), TODAY)
	TestFixtures.check(res, "the bare parent names no reasons and projects nothing",
		int(out["total"]) == 0 and not bool(out["estimate"]), str(out))


static func _case_history(res: Dictionary) -> void:
	var rows: Array[TransactionData] = _books([_fare(TODAY - 20, "foot"), _fare(TODAY - 5, "horse")])
	var out: Dictionary = _travel([_offer(TRIP_KM)]).forecast(rows, TODAY)
	var groups: Dictionary = out["groups"]
	TestFixtures.check(res, "a month of fares projects a month the same, split by mode",
		int(out["total"]) == 2 * FARE and int(groups.get("foot", 0)) == FARE
		and int(groups.get("horse", 0)) == FARE and not bool(out["estimate"]), str(out))
	TestFixtures.check(res, "an even month and offers as far as the trips leave trend and scale at 1",
		is_equal_approx(float(out["trend"]), 1.0) and is_equal_approx(float(out["scale"]), 1.0), str(out))
	var young: Array[TransactionData] = [_fare(TODAY, "foot")]
	var fresh: Dictionary = _travel([_offer(TRIP_KM)]).forecast(young, TODAY)
	var want: int = roundi(float(FARE) * ExpenseForecaster.PROJECT_DAYS / ExpenseForecaster.MIN_SPAN_DAYS)
	TestFixtures.check(res, "books a day old are read over the span floor, not one day",
		int(fresh["total"]) == want, "%d want %d" % [int(fresh["total"]), want])


static func _case_refund(res: Dictionary) -> void:
	var back: TransactionData = TransactionData.make(HALF_FARE, 0, "Refund", "Travel",
		GameState.REASON_TRAVEL_REFUND, "horse", TRIP_KM)
	back.day_index = TODAY - 3
	var rows: Array[TransactionData] = _books([_fare(TODAY - 5, "foot"), _fare(TODAY - 4, "horse"), back])
	var out: Dictionary = _travel([_offer(TRIP_KM)]).forecast(rows, TODAY)
	TestFixtures.check(res, "a refund comes off the fares of its own mode",
		int(out["groups"].get("horse", 0)) == HALF_FARE and int(out["groups"].get("foot", 0)) == FARE,
		str(out))
	var only: Array[TransactionData] = _books([back])
	var none: Dictionary = _travel([]).forecast(only, TODAY)
	TestFixtures.check(res, "a refund alone projects nothing", int(none["total"]) == 0, str(none))
	var full: TransactionData = TransactionData.make(FARE, 0, "Refund", "Travel",
		GameState.REASON_TRAVEL_REFUND, "foot", TRIP_KM)
	full.day_index = TODAY - 2
	var even: Dictionary = _travel([_offer(TRIP_KM)]).forecast(_books([_fare(TODAY - 5, "foot"), full]), TODAY)
	TestFixtures.check(res, "fares refunded in full project 0 and are not replaced by the estimate",
		int(even["total"]) == 0 and not bool(even["estimate"]), str(even))


static func _case_window(res: Dictionary) -> void:
	var old: TransactionData = _fare(TODAY - ExpenseForecaster.WINDOW_DAYS, "train", TRIP_KM, 1000)
	var later: TransactionData = _fare(TODAY + 1, "train", TRIP_KM, 1000)
	var rows: Array[TransactionData] = _books([old, later, _fare(TODAY - 10, "foot")])
	var out: Dictionary = _travel([_offer(TRIP_KM)]).forecast(rows, TODAY)
	TestFixtures.check(res, "fares outside the 30 day window are left out",
		not out["groups"].has("train") and int(out["total"]) == FARE, str(out))


static func _case_trend(res: Dictionary) -> void:
	var rising: Array[TransactionData] = _books([_fare(TODAY - 20, "foot"),
		_fare(TODAY - 3, "foot", TRIP_KM, FARE * 4)])
	var up: Dictionary = _travel([_offer(TRIP_KM)]).forecast(rising, TODAY)
	TestFixtures.check(res, "a recent half four times the older one is clamped to a trend of 2",
		is_equal_approx(float(up["trend"]), ExpenseForecaster.TREND_MAX), str(up))
	var falling: Array[TransactionData] = _books([_fare(TODAY - 20, "foot", TRIP_KM, FARE * 4),
		_fare(TODAY - 3, "foot")])
	var down: Dictionary = _travel([_offer(TRIP_KM)]).forecast(falling, TODAY)
	TestFixtures.check(res, "a recent half a quarter of the older one is clamped to a trend of 0.5",
		is_equal_approx(float(down["trend"]), ExpenseForecaster.TREND_MIN)
		and int(down["total"]) == roundi(FARE * 5 * ExpenseForecaster.TREND_MIN), str(down))
	var young: Array[TransactionData] = []
	for back: int in 20:
		young.append(_fare(TODAY - back, "foot", TRIP_KM, 10))
	var level: Dictionary = _travel([_offer(TRIP_KM)]).forecast(young, TODAY)
	TestFixtures.check(res, "20 day books spent evenly read a trend of 1 and project 30 days of it",
		is_equal_approx(float(level["trend"]), 1.0) and int(level["total"]) == 300, str(level))


static func _case_scale(res: Dictionary) -> void:
	var rows: Array[TransactionData] = _books([_fare(TODAY - 20, "foot"), _fare(TODAY - 5, "foot")])
	var far: Dictionary = _travel([_offer(FAR_KM)]).forecast(rows, TODAY)
	TestFixtures.check(res, "offers half again as far as the trips scale the month by 1.5",
		is_equal_approx(float(far["scale"]), 1.5) and int(far["total"]) == 3 * FARE, str(far))
	var huge: Dictionary = _travel([_offer(TRIP_KM * 10)]).forecast(rows, TODAY)
	var tiny: Dictionary = _travel([_offer(1)]).forecast(rows, TODAY)
	TestFixtures.check(res, "the driver scale is clamped to 0.5 through 2",
		is_equal_approx(float(huge["scale"]), ExpenseForecaster.SCALE_MAX)
		and is_equal_approx(float(tiny["scale"]), ExpenseForecaster.SCALE_MIN),
		"%s %s" % [huge["scale"], tiny["scale"]])
	var taken: Dictionary = _travel([_offer(TRIP_KM * 10, 1, GuiTypes.ContractStatus.ACTIVE)]).forecast(
		rows, TODAY)
	TestFixtures.check(res, "only contracts still on offer drive the scale",
		is_equal_approx(float(taken["scale"]), 1.0), str(taken))


static func _case_fallback(res: Dictionary) -> void:
	var offers: Array[ContractView] = [_offer(60, 2), _offer(120, 2)]
	var out: Dictionary = _travel(offers).forecast(_books([]), TODAY)
	var best: int = -1
	var best_key: String = ""
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var fare: int = DispatchLogic.travel_cost(mode, 2, 2, 90) * 2
		if fare > 0 and (best < 0 or fare < best):
			best = fare
			best_key = String(mode["key"])
	TestFixtures.check(res, "with no fares the estimate is a round trip to an average offer at the cheapest mode",
		bool(out["estimate"]) and int(out["total"]) == best and int(out["groups"].get(best_key, 0)) == best,
		"%s want %s %d" % [str(out), best_key, best])
	var empty: Dictionary = _travel([]).forecast(_books([]), TODAY)
	TestFixtures.check(res, "with no fares and no offers there is no estimate",
		int(empty["total"]) == 0 and not bool(empty["estimate"]), str(empty))


static func _case_row_mode(res: Dictionary) -> void:
	var row: TransactionData = _fare(TODAY, "airship", 300)
	var saved: Dictionary = row.to_row()
	var back: TransactionData = TransactionData.from_row(saved)
	TestFixtures.check(res, "a travel row keeps its mode and distance through to_row and from_row",
		String(saved.get("mode", "")) == "airship" and back.mode == "airship" and back.distance_km == 300
		and back.amount == -FARE and back.reason == GameState.REASON_TRAVEL, str(saved))
	var legacy: Dictionary = saved.duplicate()
	legacy.erase("mode")
	legacy.erase("distance_km")
	var old: TransactionData = TransactionData.from_row(legacy)
	TestFixtures.check(res, "a row saved before the mode field loads with mode empty and 0 km",
		old.mode == "" and old.distance_km == 0 and old.amount == -FARE, "%s %d" % [old.mode, old.distance_km])


static func _case_stamp(res: Dictionary) -> void:
	var bank: int = GameState.bank_notes
	var books: Array[TransactionData] = FinanceLedger.transactions.duplicate()
	var trip: ActiveRun = ActiveRun.new()
	trip.travel_mode = "horse"
	trip.travel_cost = FARE
	GameState._travel_money(trip, RUN_KM, false)
	var paid: TransactionData = FinanceLedger.transactions.back()
	TestFixtures.check(res, "a dispatch fare is filed with its mode and distance",
		paid.reason == GameState.REASON_TRAVEL and paid.mode == "horse" and paid.distance_km == RUN_KM
		and paid.amount == -FARE, "%s %s %d" % [paid.reason, paid.mode, paid.distance_km])
	GameState._travel_money(trip, RUN_KM, true)
	var back: TransactionData = FinanceLedger.transactions.back()
	TestFixtures.check(res, "a call off refund is filed with the same mode",
		back.reason == GameState.REASON_TRAVEL_REFUND and back.mode == "horse" and back.amount == FARE,
		"%s %s" % [back.reason, back.mode])
	FinanceLedger.record(-1, "guild", "After")
	var after: TransactionData = FinanceLedger.transactions.back()
	TestFixtures.check(res, "the stamp clears once the fare is filed",
		GameState.logged_mode == "" and GameState.logged_km == 0 and after.mode == "", after.mode)
	FinanceLedger.transactions = books
	GameState.bank_notes = bank


static func _case_lines(res: Dictionary) -> void:
	var lines: Array[Dictionary] = FinanceLedger.travel_lines({"groups": {"": 5, "horse": 10, "foot": 3}})
	var texts: Array[String] = []
	for line: Dictionary in lines:
		texts.append("%s %d" % [String(line["label"]), int(line["amount"])])
	TestFixtures.check(res, "the Travel tooltip lists modes in travel order, unknown modes as Other",
		texts == (["Foot 3", "Horse 10", "Other 5"] as Array[String]), ", ".join(texts))
	TestFixtures.check(res, "the Travel row says Estimate when the figure has no history",
		FinanceLedger._travel_sub({"total": 9, "estimate": true}) == "Estimate"
		and FinanceLedger._travel_sub({"total": 0, "estimate": false}) == "No travel booked",
		FinanceLedger._travel_sub({"total": 9, "estimate": true}))


static func _case_first_charge(res: Dictionary) -> void:
	var texts: Array[String] = []
	var ok: bool = true
	for day: int in [0, 1, 13, 14, 122, 135, 160]:
		var gap: int = TrynnCalendar.next_day_on(day, FinanceManager.bill_day_from(day)) - day
		var got: int = PromotionsManager.first_charge(&"flyers", day)
		ok = ok and PromotionsManager.first_bill_days(day) == gap and got == 5 * gap
		texts.append("%d:%d/%d" % [day, got, 5 * gap])
	TestFixtures.check(res, "an Infinite launch pays per_day for each day to its first calendar bill",
		ok, ", ".join(texts))
	TestFixtures.check(res, "a launch on the 3rd of Erta pays 39 days and one on the 1st of Daith pays 14",
		PromotionsManager.first_bill_days(122) == 39 and PromotionsManager.first_bill_days(0) == 14
		and PromotionsManager.first_charge(&"flyers", 122) == 195
		and PromotionsManager.first_charge(&"radio", 122) == 3120,
		"%d %d" % [PromotionsManager.first_bill_days(122), PromotionsManager.first_bill_days(0)])
	TestFixtures.check(res, "a fixed run pays to its first bill date or its end, whichever is sooner",
		PromotionsManager.first_charge(&"flyers", 122, 30) == 150
		and PromotionsManager.first_charge(&"flyers", 122, 60) == 195
		and PromotionsManager.first_bill_days(122, 5) == 5,
		"%d %d" % [PromotionsManager.first_charge(&"flyers", 122, 30),
		PromotionsManager.first_charge(&"flyers", 122, 60)])


#Launch rights for radio and runs of any length on top of the promo suite's launch set.
static func promo_ent() -> Dictionary:
	var ent: Dictionary = GuiPromoTests._launch_ent()
	ent.merge({"adRadio": true, "maxPromoDays": SubscriptionManager.PROMO_DAYS_INFINITE}, true)
	return ent


#The ads charges booked since the ledger held mark rows.
static func _ads_since(mark: int) -> Array[int]:
	var out: Array[int] = []
	for row: TransactionData in FinanceLedger.transactions.slice(mark):
		if row.reason == PromotionsManager.REASON_ADS:
			out.append(row.amount)
	return out


static func _case_first_refund(res: Dictionary) -> void:
	GuiPromoTests._fresh(promo_ent())
	GameState.bank_notes = 100000
	var today: int = GameState.day()
	var mark: int = FinanceLedger.transactions.size()
	var radio: CampaignData = TestFixtures.launch_campaign({"type": &"radio", "infinite": true})
	TestFixtures.check(res, "an Infinite radio launch on day 122 pays 39 days and bills on day 161",
		radio != null and today == 122 and _ads_since(mark) == ([-3120] as Array[int])
		and radio.next_bill_day == 161 and radio.budget_remaining(today) == 3120,
		"%s next %d" % [str(_ads_since(mark)), -1 if radio == null else radio.next_bill_day])
	if radio == null:
		return
	var after: int = TrynnCalendar.next_day_on(161, radio.bill_day)
	TestFixtures.check(res, "the next bill is per_day for the days to the following bill date",
		PromotionsManager.next_bill_amount(radio) == 80 * (after - 161)
		and FinanceLedger.ads() == 80 * (after - 161),
		"%d against %d" % [PromotionsManager.next_bill_amount(radio), 80 * (after - 161)])
	mark = FinanceLedger.transactions.size()
	TestFixtures.pass_days(161 - today)
	TestFixtures.check(res, "on the bill date it charges that period and moves to the next bill date",
		_ads_since(mark) == ([-80 * (after - 161)] as Array[int]) and radio.next_bill_day == after,
		"%s next %d" % [str(_ads_since(mark)), radio.next_bill_day])
	TestFixtures.pass_days(9)
	var now: int = GameState.day()
	TestFixtures.check(res, "a cancel refunds every unused day of the billed period, with no 30 day cap",
		radio.unused_days(now) == after - now and radio.budget_remaining(now) == 80 * (after - now),
		"%d days %d notes" % [radio.unused_days(now), radio.budget_remaining(now)])


static func _case_fixed_bills(res: Dictionary) -> void:
	GuiPromoTests._fresh(promo_ent())
	GameState.bank_notes = 100000
	TestFixtures.pass_days(28)
	var day: int = GameState.day()
	var first: int = PromotionsManager.first_bill_days(day)
	var mark: int = FinanceLedger.transactions.size()
	var run_ad: CampaignData = TestFixtures.launch_campaign({"type": &"flyers", "days": 30})
	TestFixtures.check(res, "a 30 day flyer run on day 150 pays its 24 days to the 15th now and owes 6 then",
		run_ad != null and day == 150 and first == 24 and _ads_since(mark) == ([-120] as Array[int])
		and run_ad.next_bill_day == 174 and PromotionsManager.next_bill_amount(run_ad) == 30,
		"day %d first %d %s" % [day, first, str(_ads_since(mark))])
	if run_ad == null:
		return
	var bills: Array[Dictionary] = PromotionsManager.ad_bill_days(day, 120)
	TestFixtures.check(res, "the forecast lists one bill for a fixed run, ending at the end of the run",
		bills.size() == 1 and int(bills[0]["day"]) == 174 and int(bills[0]["amount"]) == 30, str(bills))
	mark = FinanceLedger.transactions.size()
	TestFixtures.pass_days(174 - day)
	TestFixtures.check(res, "its last bill covers only the days up to its end and no bill follows",
		_ads_since(mark) == ([-30] as Array[int]) and run_ad.next_bill_day == -1
		and PromotionsManager.next_bill_amount(run_ad) == 0 and run_ad.budget_remaining(174) == 30,
		"%s next %d" % [str(_ads_since(mark)), run_ad.next_bill_day])
	var short: CampaignData = TestFixtures.launch_campaign({"type": &"flyers", "days": 5})
	TestFixtures.check(res, "a run shorter than the gap pays in full at launch and never bills",
		short != null and short.next_bill_day == -1 and short.total_cost == 25, "%s" % [short != null])


static func _bonus(day: int, amount: int) -> TransactionData:
	var row: TransactionData = TransactionData.make(-amount, 0, "Bonus", "Payroll", GameState.REASON_BONUS)
	row.day_index = day
	return row


static func _case_benefits(res: Dictionary) -> void:
	var forecaster: BenefitForecaster = BenefitForecaster.new()
	var none: Dictionary = forecaster.forecast([_other(TODAY - 2)] as Array[TransactionData], TODAY)
	TestFixtures.check(res, "with no bonus paid the benefits forecast is 0 and not an estimate",
		int(none["total"]) == 0 and not bool(none["estimate"]), str(none))
	var rows: Array[TransactionData] = [_bonus(TODAY - 3, 100), _bonus(TODAY - 20, 100), _other(TODAY - 4)]
	var got: Dictionary = forecaster.forecast(rows, TODAY)
	var want: int = roundi(200.0 * ExpenseForecaster.PROJECT_DAYS / 21.0 * ExpenseForecaster.TREND_MIN)
	TestFixtures.check(res, "bonuses of the window project over the next 30 days, grouped as bonus",
		int(got["total"]) == want
		and int((got["groups"] as Dictionary).get(GameState.REASON_BONUS, 0)) == want,
		"%d against %d" % [int(got["total"]), want])
	TestFixtures.check(res, "backpay has a hook and no reasons yet",
		forecaster.backpay_reasons().is_empty()
		and forecaster.reasons() == ([GameState.REASON_BONUS] as Array[String]),
		str(forecaster.reasons()))
	var books: Array[TransactionData] = FinanceLedger.transactions.duplicate()
	var wages: int = FinanceLedger.payroll()
	FinanceLedger.transactions = [_bonus(GameState.day(), 300)] as Array[TransactionData]
	var lines: Array[Dictionary] = FinanceLedger.payroll_lines()
	var benefits: int = roundi(300.0 * ExpenseForecaster.PROJECT_DAYS / ExpenseForecaster.MIN_SPAN_DAYS)
	TestFixtures.check(res, "the Payroll Benefits line is a 300 bonus today read over 7 days; the row stays wages",
		String(lines[1]["label"]) == "Benefits" and int(lines[1]["amount"]) == benefits
		and FinanceLedger.payroll() == wages,
		"%s want %d, wages %d/%d" % [str(lines[1]), benefits, FinanceLedger.payroll(), wages])
	FinanceLedger.transactions = books


static func _case_loan_origination(res: Dictionary) -> void:
	var bank: int = GameState.bank_notes
	var books: Array[TransactionData] = FinanceLedger.transactions.duplicate()
	var id: int = 9901
	var source: Dictionary = {"lender": "Test Lender", "amount": 1200, "rate": 0.1, "term": 12,
		"first_due": 1, "team": [], "odds": 50, "outcome": "approved", "approved": true, "offer_amount": 1200,
		"offer_rate": 0.1, "offer_term": 12, "offer_first_due": 1}
	FinanceManager.offers.append(FinanceManager._make_offer(id, source, CampaignClock.now() + 6000))
	var took: bool = FinanceManager.accept_offer(id)
	var loan: LoanData = FinanceManager.loans.back() if took else null
	var charged: int = 0
	for row: TransactionData in FinanceLedger.transactions.slice(books.size()):
		if row.amount < 0:
			charged -= row.amount
	TestFixtures.check(res, "a loan due a month out charges nothing when it is taken",
		took and charged == 0 and GameState.bank_notes == bank + 1200, "charged %d" % charged)
	if loan == null:
		return
	var want: int = FinanceManager._bill_minute(FinanceManager._month_index(loan.start_minute) + 1, loan.bill_day)
	TestFixtures.check(res, "its first payment is the full instalment on its bill day in its first due month",
		FinanceManager.next_due_minute(loan.id) == want and FinanceManager.loan_payment(loan) > 0
		and FinanceManager.loan_payment(loan) * loan.months >= loan.principal,
		"due %d want %d pay %d" % [FinanceManager.next_due_minute(loan.id), want,
		FinanceManager.loan_payment(loan)])
	FinanceManager.loans.erase(loan)
	FinanceLedger.transactions = books
	GameState.bank_notes = bank
