class_name GuiFinanceDataTests

#FinanceLedger and TransactionData off a fresh campaign. Every case restarts the game, puts the
#clock on a named calendar day and reseeds the ledger, so the projection, the breakdown and the
#two bills read the same way on every run. GameState on this copy already has charge() and the
#money_logged signal, and FinanceLedger already connects to it; the cases still call record() and
#tick() themselves because they pin the ledger's own arithmetic, not the GameState wiring.
#Calendar days used here: day 0 is Daith 1, day 14 Daith 15, day 28 Daith 29,
#day 44 Ruadd 15, day 120 Erta 1 (a 40 day month), day 250 Orlin 1, day 320 Tek 31, day 329 Tek 40.

const ENTERPRISE_PER_MERC: int = 15
#The category every money reason files under, written out here so the check reads the books
#and not the table it is checking.
const CATEGORY_TABLE: Dictionary = {
	"contract": "Contract", "travel": "Travel", "travel_refund": "Travel", "loan": "Loan",
	"loan_payment": "Loan", "loan_payoff": "Loan", "guild": "Guild", "payroll": "Payroll",
	"subscription": "Subscription", "upgrade": "Subscription", "ads": "Ads", "bazaar": "Bazaar",
	"legal": "Legal", "fine": "Legal", "bail": "Legal", "permit": "Legal", "odd_job": "Odd Job",
	"hiring": "Hiring", "hire": "Hiring", "stock": "Invest", "dividend": "Invest",
	"benefit": "Benefit",
}

#The spend reasons the wave map pins. Every one has to file under a category of its own, so a
#reason nobody mapped cannot sit in Other unnoticed.
const PINNED_REASONS: Array[String] = ["subscription", "upgrade", "loan", "loan_payment",
	"loan_payoff", "bazaar", "fine", "bail", "permit", "odd_job", "ads", "hire", "hiring",
	"stock", "dividend", "benefit", "guild", "travel", "travel_refund", "payroll", "contract"]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	_case_constants(res)
	_case_categories(res)
	_case_pinned_reasons(res)
	_case_record(res)
	_case_trim(res)
	_case_listener(res)
	_case_seed(res)
	_case_income_window(res)
	_case_schedule_month(res)
	_case_schedule_long_month(res)
	_case_schedule_year_end(res)
	_case_horizons(res)
	_case_projection(res)
	_case_projection_seeded_loans(res)
	_case_projection_one_day(res)
	_case_projection_loans(res, host)
	_case_projection_ads(res)
	_case_breakdown(res)
	_case_stat_cards(res)
	_case_tick_subscription(res)
	_case_tick_guild(res)
	_case_tick_jump(res)
	_case_tick_free_plan(res)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.reset()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI FINDATA")


#Every case starts bare: Enterprise with no upgrade tier, so the subscription bill is the plan fee
#for the roster alone.
static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	FinanceManager.reset()
	FinanceLedger.reset()


#Puts the clock on 8:00 of that day index; the clock only ever runs forward, so it resets first.
static func _at_day(day_index: int) -> void:
	CampaignClock.reset()
	CampaignClock.advance_to(day_index * CampaignClock.MINUTES_PER_DAY
		+ 8 * CampaignClock.MINUTES_PER_HOUR)


static func _fund(amount: int) -> void:
	GameState.refund(amount)


#The seeded campaigns bill ads; a case that wants a clean projection drops them.
static func _no_promos() -> void:
	PromotionsManager.campaigns.clear()


#The seeded campaign owes two loans on the 15th; a case that wants the subscription alone on
#the services row drops them.
static func _no_loans() -> void:
	FinanceManager.loans.clear()


static func _row_of(list: Array, key: String) -> Dictionary:
	for row: Variant in list:
		if row is Dictionary and str((row as Dictionary)["key"]) == key:
			return row
	return {}


static func _keys_of(list: Array) -> Array[String]:
	var out: Array[String] = []
	for row: Variant in list:
		if row is Dictionary:
			out.append(str((row as Dictionary)["key"]))
	return out


static func _labels_of(list: Array) -> Array[String]:
	var out: Array[String] = []
	for row: Variant in list:
		if row is Dictionary:
			out.append(str((row as Dictionary)["label"]))
	return out


static func _case_constants(res: Dictionary) -> void:
	TestFixtures.check(res, "payroll bills on the 2nd",
		int(FinanceLedger.BILL_DAYS["payroll"]) == 2, "got %s" % FinanceLedger.BILL_DAYS)
	TestFixtures.check(res, "the subscription and the loans bill on the 15th",
		int(FinanceLedger.BILL_DAYS["subscription"]) == 15
		and int(FinanceLedger.BILL_DAYS["loans"]) == 15, "got %s" % FinanceLedger.BILL_DAYS)
	TestFixtures.check(res, "the guild expenses bill on the 29th",
		int(FinanceLedger.BILL_DAYS["guild"]) == 29, "got %s" % FinanceLedger.BILL_DAYS)
	TestFixtures.check(res, "the ledger keeps 500 rows", FinanceLedger.MAX_ROWS == 500,
		"got %d" % FinanceLedger.MAX_ROWS)
	TestFixtures.check(res, "a breakdown bar holds 20 cells", FinanceLedger.BREAKDOWN_CELLS == 20,
		"got %d" % FinanceLedger.BREAKDOWN_CELLS)
	TestFixtures.check(res, "the three horizons are named",
		FinanceLedger.HORIZON_LABELS == ["End of Month", "End of Quarter", "End of Year"],
		"got %s" % str(FinanceLedger.HORIZON_LABELS))


static func _case_categories(res: Dictionary) -> void:
	_fresh()
	var bad: Array[String] = []
	for reason: Variant in CATEGORY_TABLE:
		var key: String = str(reason)
		if FinanceLedger.category_of(key) != str(CATEGORY_TABLE[reason]):
			bad.append(key)
	TestFixtures.check(res, "every mapped reason files under its category", bad.is_empty(),
		TestFixtures.detail(bad, CATEGORY_TABLE.size(), "reasons"))
	TestFixtures.check(res, "the ledger maps the reasons the books name and no others",
		FinanceLedger.CATEGORY_OF.size() == CATEGORY_TABLE.size(),
		"%d against %d" % [FinanceLedger.CATEGORY_OF.size(), CATEGORY_TABLE.size()])
	TestFixtures.check(res, "a loan payment files under Loan",
		FinanceLedger.category_of("loan_payment") == "Loan",
		FinanceLedger.category_of("loan_payment"))
	TestFixtures.check(res, "a travel refund files under Travel",
		FinanceLedger.category_of("travel_refund") == "Travel",
		FinanceLedger.category_of("travel_refund"))
	TestFixtures.check(res, "an empty reason files under Other",
		FinanceLedger.category_of("") == "Other", FinanceLedger.category_of(""))
	TestFixtures.check(res, "an unknown reason files under Other",
		FinanceLedger.category_of("nonsense") == "Other", FinanceLedger.category_of("nonsense"))
	FinanceLedger.transactions.clear()
	FinanceLedger.record(120, "")
	TestFixtures.check(res, "an unnamed credit files under Contract",
		FinanceLedger.rows()[0].category == "Contract", FinanceLedger.rows()[0].category)
	FinanceLedger.transactions.clear()
	FinanceLedger.record(-120, "")
	TestFixtures.check(res, "an unnamed debit files under Other",
		FinanceLedger.rows()[0].category == "Other", FinanceLedger.rows()[0].category)


static func _case_pinned_reasons(res: Dictionary) -> void:
	_fresh()
	var bad: Array[String] = []
	for reason: String in PINNED_REASONS:
		var category: String = FinanceLedger.category_of(reason)
		if category.is_empty() or category == FinanceLedger.OTHER_CATEGORY:
			bad.append(reason)
	TestFixtures.check(res, "every pinned spend reason files under a category of its own",
		bad.is_empty(), TestFixtures.detail(bad, PINNED_REASONS.size(), "reasons"))
	var named: Array[String] = [GameState.REASON_TRAVEL, GameState.REASON_PAYROLL,
		GameState.REASON_CONTRACT, GameState.REASON_TRAVEL_REFUND, GameState.REASON_LOAN,
		GameState.REASON_LOAN_PAYMENT, GameState.REASON_LOAN_PAYOFF, GameState.REASON_ODD_JOB,
		GameState.REASON_STOCK, GameState.REASON_DIVIDEND]
	bad = []
	for reason: String in named:
		if not PINNED_REASONS.has(reason):
			bad.append(reason)
		elif FinanceLedger.category_of(reason) == FinanceLedger.OTHER_CATEGORY:
			bad.append(reason)
	TestFixtures.check(res, "every reason GameState names is one the ledger files", bad.is_empty(),
		TestFixtures.detail(bad, named.size(), "reasons"))
	TestFixtures.check(res, "a fine, a bail and a permit all file under Legal",
		FinanceLedger.category_of("fine") == "Legal" and FinanceLedger.category_of("bail") == "Legal"
			and FinanceLedger.category_of("permit") == "Legal",
		"%s, %s, %s" % [FinanceLedger.category_of("fine"), FinanceLedger.category_of("bail"),
			FinanceLedger.category_of("permit")])
	TestFixtures.check(res, "hiring a merc files under Hiring",
		FinanceLedger.category_of("hire") == "Hiring"
			and FinanceLedger.category_of("hiring") == "Hiring",
		"%s and %s" % [FinanceLedger.category_of("hire"), FinanceLedger.category_of("hiring")])
	TestFixtures.check(res, "an upgrade files where the subscription files",
		FinanceLedger.category_of("upgrade") == FinanceLedger.category_of("subscription"),
		"%s against %s" % [FinanceLedger.category_of("upgrade"),
			FinanceLedger.category_of("subscription")])
	bad = []
	for reason: String in PINNED_REASONS:
		FinanceLedger.transactions.clear()
		FinanceLedger.record(-25, reason)
		var row: TransactionData = FinanceLedger.rows()[0]
		if row.category != FinanceLedger.category_of(reason) or row.reason != reason:
			bad.append(reason)
		elif row.label != row.category:
			bad.append(reason)
	TestFixtures.check(res, "a row recorded under a pinned reason keeps its category and name",
		bad.is_empty(), TestFixtures.detail(bad, PINNED_REASONS.size(), "reasons"))


static func _case_record(res: Dictionary) -> void:
	_fresh()
	_at_day(10)
	FinanceLedger.transactions.clear()
	TestFixtures.check(res, "a cleared ledger has no rows", FinanceLedger.rows().is_empty(),
		"%d rows" % FinanceLedger.rows().size())
	var counter := _Counter.new()
	FinanceLedger.changed.connect(counter.bump)
	FinanceLedger.record(300, "contract", "Contract 12 Name - Reward")
	FinanceLedger.record(-40, "travel")
	FinanceLedger.record(-1560, "payroll", "Payroll")
	FinanceLedger.changed.disconnect(counter.bump)
	TestFixtures.check(res, "record emits changed once per row", counter.count == 3,
		"%d emits" % counter.count)
	TestFixtures.check(res, "three rows are kept", FinanceLedger.transactions.size() == 3,
		"%d rows" % FinanceLedger.transactions.size())
	var newest: Array[TransactionData] = FinanceLedger.rows()
	TestFixtures.check(res, "rows hands back the newest row first", newest[0].label == "Payroll",
		newest[0].label)
	TestFixtures.check(res, "rows hands back the oldest row last",
		newest[2].label == "Contract 12 Name - Reward", newest[2].label)
	TestFixtures.check(res, "a limit cuts the list", FinanceLedger.rows(2).size() == 2,
		"%d rows" % FinanceLedger.rows(2).size())
	TestFixtures.check(res, "a limited list still starts at the newest row",
		FinanceLedger.rows(2)[0].label == "Payroll", FinanceLedger.rows(2)[0].label)
	TestFixtures.check(res, "an empty label reads as the category", newest[1].label == "Travel",
		newest[1].label)
	TestFixtures.check(res, "a row is stamped with the current minute",
		newest[0].minute == CampaignClock.now(), "%d" % newest[0].minute)
	TestFixtures.check(res, "a row carries the day index of its minute", newest[0].day_index == 10,
		"%d" % newest[0].day_index)
	TestFixtures.check(res, "a credit reads with a plus and a thousands comma",
		newest[2].amount_text() == "+300", newest[2].amount_text())
	TestFixtures.check(res, "a debit keeps its minus sign", newest[0].amount_text() == "-1,560",
		newest[0].amount_text())
	TestFixtures.check(res, "a row reads its date off the game calendar",
		newest[0].date_text() == TrynnCalendar.date_text(CampaignClock.now()),
		newest[0].date_text())
	var dict: Dictionary = newest[0].to_row()
	TestFixtures.check(res, "to_row carries every field",
		dict.has("day_index") and dict.has("minute") and dict.has("label")
		and dict.has("category") and dict.has("amount") and dict.has("reason")
		and dict.has("date_text") and dict.has("amount_text"), "got %s" % str(dict.keys()))


static func _case_trim(res: Dictionary) -> void:
	_fresh()
	FinanceLedger.transactions.clear()
	for i: int in range(FinanceLedger.MAX_ROWS + 20):
		FinanceLedger.record(1, "contract", "r%d" % i)
	TestFixtures.check(res, "the ledger never grows past MAX_ROWS",
		FinanceLedger.transactions.size() == FinanceLedger.MAX_ROWS,
		"%d rows" % FinanceLedger.transactions.size())
	TestFixtures.check(res, "the trim drops the oldest rows",
		FinanceLedger.transactions[0].label == "r20", FinanceLedger.transactions[0].label)
	TestFixtures.check(res, "the trim keeps the newest row",
		FinanceLedger.rows()[0].label == "r519", FinanceLedger.rows()[0].label)


static func _case_listener(res: Dictionary) -> void:
	_fresh()
	_at_day(10)
	FinanceLedger.transactions.clear()
	var spent: bool = GameState.spend(40, GameState.REASON_TRAVEL)
	TestFixtures.check(res, "a travel debit the bank can take goes through", spent, "refused")
	TestFixtures.check(res, "a debit lands as one ledger row",
		FinanceLedger.transactions.size() == 1, "%d rows" % FinanceLedger.transactions.size())
	var row: TransactionData = FinanceLedger.rows()[0]
	TestFixtures.check(res, "the debit row files under Travel", row.category == "Travel",
		row.category)
	TestFixtures.check(res, "the debit row keeps the signed amount", row.amount == -40,
		"%d" % row.amount)
	FinanceLedger.transactions.clear()
	GameState.refund(60, GameState.REASON_CONTRACT)
	TestFixtures.check(res, "a credit lands as one Contract row",
		FinanceLedger.transactions.size() == 1
		and FinanceLedger.rows()[0].amount == 60
		and FinanceLedger.rows()[0].category == "Contract",
		"%d rows" % FinanceLedger.transactions.size())
	FinanceLedger.transactions.clear()
	var refused: bool = GameState.spend(GameState.bank_notes + 1, GameState.REASON_TRAVEL)
	TestFixtures.check(res, "a refused debit files no row",
		not refused and FinanceLedger.transactions.is_empty(),
		"%d rows" % FinanceLedger.transactions.size())


static func _case_seed(res: Dictionary) -> void:
	_fresh()
	_at_day(20)
	var bank: int = GameState.bank_notes
	FinanceLedger.reset()
	TestFixtures.check(res, "reset lays down the seeded history",
		FinanceLedger.transactions.size() == FinanceLedger.SEED_ROWS.size(),
		"%d rows" % FinanceLedger.transactions.size())
	TestFixtures.check(res, "the seeded history never moves the bank", GameState.bank_notes == bank,
		"%d notes" % GameState.bank_notes)
	var newest: Array[TransactionData] = FinanceLedger.rows()
	TestFixtures.check(res, "the newest seeded row is today's contract reward",
		newest[0].label == "Contract 12 Name - Reward" and newest[0].day_index == 20,
		"%s on day %d" % [newest[0].label, newest[0].day_index])
	TestFixtures.check(res, "the oldest seeded row sits fifteen days back",
		newest[8].label == "Contract 9 Name - Reward" and newest[8].day_index == 5,
		"%s on day %d" % [newest[8].label, newest[8].day_index])
	TestFixtures.check(res, "a seeded row reads its date off the game calendar",
		newest[8].date_text() == TrynnCalendar.date_text(newest[8].minute), newest[8].date_text())
	TestFixtures.check(res, "a seeded lender row files under Loan",
		newest[7].category == "Loan" and newest[7].label == "Lender 1 - Payment",
		"%s %s" % [newest[7].category, newest[7].label])
	var total: int = 0
	for held: TransactionData in FinanceLedger.transactions:
		total += held.amount
	TestFixtures.check(res, "the seeded history nets 3000 notes", total == 3000, "%d" % total)
	_at_day(1)
	FinanceLedger.reset()
	TestFixtures.check(res, "a seeded row never falls before the first day",
		FinanceLedger.rows()[8].minute == 0, "%d" % FinanceLedger.rows()[8].minute)


#The window sums positive rows in the ledger, not a placeholder rate.
static func _case_income_window(res: Dictionary) -> void:
	_fresh()
	_at_day(60)
	FinanceLedger.reset()
	var seeded_income: int = 0
	var today_income: int = 0
	for row: Dictionary in FinanceLedger.SEED_ROWS:
		var amount: int = int(row["amount"])
		if amount > 0:
			seeded_income += amount
			if int(row["days_ago"]) == 0:
				today_income += amount
	TestFixtures.check(res, "the 30 day income sums the positive seeded rows",
		FinanceLedger.income_in(FinanceLedger.RATE_DAYS) == seeded_income,
		"%d against %d" % [FinanceLedger.income_in(FinanceLedger.RATE_DAYS), seeded_income])
	FinanceLedger.record(500, "contract")
	TestFixtures.check(res, "a new contract reward raises the window",
		FinanceLedger.income_in(FinanceLedger.RATE_DAYS) == seeded_income + 500,
		"%d" % FinanceLedger.income_in(FinanceLedger.RATE_DAYS))
	var today: int = TrynnCalendar.day_index(CampaignClock.now())
	var old_minute: int = (today - 40) * CampaignClock.MINUTES_PER_DAY
	FinanceLedger.transactions.append(TransactionData.make(400, old_minute, "Old Reward",
		"Contract", "contract"))
	TestFixtures.check(res, "a row forty days back falls outside the thirty day window",
		FinanceLedger.income_in(FinanceLedger.RATE_DAYS) == seeded_income + 500,
		"%d" % FinanceLedger.income_in(FinanceLedger.RATE_DAYS))
	TestFixtures.check(res, "income_in(1) counts only today",
		FinanceLedger.income_in(1) == today_income + 500,
		"%d against %d" % [FinanceLedger.income_in(1), today_income + 500])
	FinanceLedger.reset()


static func _case_schedule_month(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	TestFixtures.check(res, "payroll is one day off Daith 1", FinanceLedger.next_in(2) == 1,
		"%d" % FinanceLedger.next_in(2))
	TestFixtures.check(res, "the 15th is fourteen days off Daith 1",
		FinanceLedger.next_in(15) == 14, "%d" % FinanceLedger.next_in(15))
	TestFixtures.check(res, "the 29th is twenty eight days off Daith 1",
		FinanceLedger.next_in(29) == 28, "%d" % FinanceLedger.next_in(29))
	TestFixtures.check(res, "one day off reads as a single day",
		FinanceLedger.rel_text(FinanceLedger.next_in(2)) == "1 Day From Now",
		FinanceLedger.rel_text(FinanceLedger.next_in(2)))
	TestFixtures.check(res, "twelve days off reads in the plural",
		FinanceLedger.rel_text(12) == "12 Days From Now", FinanceLedger.rel_text(12))
	TestFixtures.check(res, "payroll falls once in the month", FinanceLedger.count_in(2, 30) == 1,
		"%d" % FinanceLedger.count_in(2, 30))
	TestFixtures.check(res, "the 15th falls three times in the spring quarter",
		FinanceLedger.count_in(15, 90) == 3, "%d" % FinanceLedger.count_in(15, 90))
	TestFixtures.check(res, "the 29th falls once in the month",
		FinanceLedger.count_in(29, 30) == 1, "%d" % FinanceLedger.count_in(29, 30))
	TestFixtures.check(res, "a one day window holds no later bill",
		FinanceLedger.count_in(29, 1) == 0, "%d" % FinanceLedger.count_in(29, 1))
	_at_day(14)
	TestFixtures.check(res, "a bill due today is zero days off", FinanceLedger.next_in(15) == 0,
		"%d" % FinanceLedger.next_in(15))
	TestFixtures.check(res, "zero days off reads as today", FinanceLedger.rel_text(0) == "Today",
		FinanceLedger.rel_text(0))
	TestFixtures.check(res, "a window starting on the bill day counts it",
		FinanceLedger.count_in(15, 16) == 1, "%d" % FinanceLedger.count_in(15, 16))
	TestFixtures.check(res, "payroll is gone for this month", FinanceLedger.count_in(2, 16) == 0,
		"%d" % FinanceLedger.count_in(2, 16))


static func _case_schedule_long_month(res: Dictionary) -> void:
	_fresh()
	_at_day(250)
	TestFixtures.check(res, "the 40th of Orlin is thirty nine days off",
		FinanceLedger.next_in(40) == 39, "%d" % FinanceLedger.next_in(40))
	TestFixtures.check(res, "a forty day window reaches the 40th",
		FinanceLedger.count_in(40, 40) == 1, "%d" % FinanceLedger.count_in(40, 40))
	TestFixtures.check(res, "a thirty nine day window stops short of it",
		FinanceLedger.count_in(40, 39) == 0, "%d" % FinanceLedger.count_in(40, 39))
	_at_day(60)
	TestFixtures.check(res, "a 40th ninety nine days off is found across three months",
		FinanceLedger.next_in(40) == 99, "%d" % FinanceLedger.next_in(40))
	TestFixtures.check(res, "a thirty day month never holds a 40th",
		FinanceLedger.count_in(40, 30) == 0, "%d" % FinanceLedger.count_in(40, 30))


static func _case_schedule_year_end(res: Dictionary) -> void:
	_fresh()
	_at_day(320)
	TestFixtures.check(res, "payroll is found in the next year",
		FinanceLedger.next_in(2) == 11, "%d" % FinanceLedger.next_in(2))
	TestFixtures.check(res, "a window over the year end counts the next payroll",
		FinanceLedger.count_in(2, 20) == 1, "%d" % FinanceLedger.count_in(2, 20))
	TestFixtures.check(res, "a window inside the old year counts none",
		FinanceLedger.count_in(2, 10) == 0, "%d" % FinanceLedger.count_in(2, 10))


static func _case_horizons(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	TestFixtures.check(res, "Daith 1 to the end of the month is thirty days",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH) == 30,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH))
	TestFixtures.check(res, "Daith 1 to the end of spring is ninety days",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_QUARTER) == 90,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_QUARTER))
	TestFixtures.check(res, "Daith 1 to the end of the year is the whole year",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_YEAR) == 330,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_YEAR))
	_at_day(14)
	TestFixtures.check(res, "Daith 15 to the end of the month is sixteen days",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH) == 16,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH))
	TestFixtures.check(res, "Daith 15 to the end of spring is seventy six days",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_QUARTER) == 76,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_QUARTER))
	TestFixtures.check(res, "Daith 15 to the end of the year is 316 days",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_YEAR) == 316,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_YEAR))
	_at_day(29)
	TestFixtures.check(res, "the last day of a month is a one day horizon",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH) == 1,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH))
	_at_day(120)
	TestFixtures.check(res, "Erta 1 to the end of the month is forty days",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH) == 40,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_MONTH))
	TestFixtures.check(res, "Erta ends the summer, so the quarter is forty days too",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_QUARTER) == 40,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_QUARTER))
	_at_day(329)
	TestFixtures.check(res, "the last day of the year is a one day horizon",
		FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_YEAR) == 1,
		"%d" % FinanceLedger.horizon_days(FinanceLedger.Horizon.END_OF_YEAR))


static func _case_projection(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	_no_promos()
	_no_loans()
	_fund(5000)
	FinanceLedger.reset()
	var sub_cost: int = SubscriptionManager.monthly_cost()
	var pay: int = GameState.month_expenses()
	var proj: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_MONTH)
	TestFixtures.check(res, "the projection spans the calendar month", int(proj["days"]) == 30,
		"%d" % int(proj["days"]))
	TestFixtures.check(res, "the projection rows come in the prototype order",
		_keys_of(proj["rows"]) == ["notes", "income", "payroll", "loans", "guild", "travel",
		"ads", "total"], "got %s" % str(_keys_of(proj["rows"])))
	var notes: Dictionary = _row_of(proj["rows"], "notes")
	TestFixtures.check(res, "the first row is the bank", int(notes["amount"]) == GameState.bank_notes
		and str(notes["label"]) == "Current Notes", "%d" % int(notes["amount"]))
	var income: Dictionary = _row_of(proj["rows"], "income")
	TestFixtures.check(res, "a full month of income is the monthly rate",
		int(income["amount"]) == FinanceLedger.monthly_income(), "%d" % int(income["amount"]))
	var payroll: Dictionary = _row_of(proj["rows"], "payroll")
	TestFixtures.check(res, "the payroll row counts one billing day and names it",
		str(payroll["label"]) == "Payroll (1x)" and int(payroll["count"]) == 1,
		str(payroll["label"]))
	TestFixtures.check(res, "the payroll row debits one month of wages",
		int(payroll["amount"]) == -pay, "%d against %d" % [int(payroll["amount"]), pay])
	TestFixtures.check(res, "the payroll row names the next billing day",
		str(payroll["sub"]) == "Next: 1 Day From Now", str(payroll["sub"]))
	var loans: Dictionary = _row_of(proj["rows"], "loans")
	TestFixtures.check(res, "with no loans the services row is the subscription alone",
		int(loans["amount"]) == -sub_cost and str(loans["label"]) == "Loans & Services (1x)",
		"%d against %d" % [int(loans["amount"]), sub_cost])
	var guild: Dictionary = _row_of(proj["rows"], "guild")
	TestFixtures.check(res, "the guild row debits one monthly rate",
		int(guild["amount"]) == -FinanceLedger.GUILD_RATE
		and str(guild["label"]) == "Guild Expenses (1x)", "%d" % int(guild["amount"]))
	var travel: Dictionary = _row_of(proj["rows"], "travel")
	TestFixtures.check(res, "the travel row debits one monthly estimate",
		int(travel["amount"]) == -FinanceLedger.TRAVEL_RATE
		and str(travel["sub"]) == "Per contract", "%d" % int(travel["amount"]))
	var ads: Dictionary = _row_of(proj["rows"], "ads")
	TestFixtures.check(res, "with no campaigns the ads row is empty",
		int(ads["amount"]) == 0 and str(ads["sub"]) == "No ongoing promos", "%d"
		% int(ads["amount"]))
	var want: int = GameState.bank_notes + FinanceLedger.monthly_income() - pay - sub_cost
	want -= FinanceLedger.GUILD_RATE + FinanceLedger.TRAVEL_RATE
	TestFixtures.check(res, "the projected notes add every row above",
		int(proj["total"]) == want, "%d against %d" % [int(proj["total"]), want])
	var last: Dictionary = _row_of(proj["rows"], "total")
	TestFixtures.check(res, "the last row carries the same total",
		int(last["amount"]) == int(proj["total"]) and str(last["label"]) == "Projected Notes",
		"%d" % int(last["amount"]))
	var end_minute: int = 29 * CampaignClock.MINUTES_PER_DAY
	TestFixtures.check(res, "the horizon names its last calendar day",
		str(proj["when"]) == "in 30 days - %s" % TrynnCalendar.date_text(end_minute),
		str(proj["when"]))


#The seeded loans ride the same 15th as the subscription, so the services row carries both.
static func _case_projection_seeded_loans(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	_no_promos()
	FinanceLedger.reset()
	var sub_cost: int = SubscriptionManager.monthly_cost()
	var due: int = FinanceManager.monthly_loans()
	TestFixtures.check(res, "the campaign opens owing loan instalments", due > 0, "%d" % due)
	var proj: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_MONTH)
	var loans: Dictionary = _row_of(proj["rows"], "loans")
	TestFixtures.check(res, "the services row adds the loan instalments to the subscription",
		int(loans["amount"]) == -(sub_cost + due),
		"%d against %d" % [int(loans["amount"]), -(sub_cost + due)])


static func _case_projection_one_day(res: Dictionary) -> void:
	_fresh()
	_at_day(29)
	_no_promos()
	FinanceLedger.reset()
	var proj: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_MONTH)
	var payroll: Dictionary = _row_of(proj["rows"], "payroll")
	TestFixtures.check(res, "a bill outside the window is counted zero times",
		str(payroll["label"]) == "Payroll (0x)" and int(payroll["amount"]) == 0,
		"%s %d" % [str(payroll["label"]), int(payroll["amount"])])
	TestFixtures.check(res, "a bill outside the window says so",
		str(payroll["sub"]) == "None in period", str(payroll["sub"]))
	var income: Dictionary = _row_of(proj["rows"], "income")
	var want_income: int = int(round(float(FinanceLedger.monthly_income()) / 30.0))
	TestFixtures.check(res, "one day of income is the ledger rate over thirty",
		int(income["amount"]) == want_income,
		"%d against %d" % [int(income["amount"]), want_income])
	var travel: Dictionary = _row_of(proj["rows"], "travel")
	TestFixtures.check(res, "one day of travel is the rate over thirty",
		int(travel["amount"]) == -20, "%d" % int(travel["amount"]))
	TestFixtures.check(res, "a one day horizon reads in the singular",
		str(proj["when"]) == "in 1 day - %s"
		% TrynnCalendar.date_text(29 * CampaignClock.MINUTES_PER_DAY), str(proj["when"]))


static func _case_projection_loans(res: Dictionary, host: Node) -> void:
	_fresh()
	_at_day(0)
	_no_promos()
	FinanceLedger.reset()
	var root: Node = host.get_tree().root
	var real: Node = root.get_node_or_null("FinanceManager")
	if real == null:
		TestFixtures.check(res, "the FinanceManager autoload is reachable", false, "no node")
		return
	real.name = "FinanceManagerHeld"
	var stub := _LoanStub.new()
	stub.name = "FinanceManager"
	root.add_child(stub)
	var active := _LoanRow.new()
	active.months = 12
	active.paid = 0
	var done := _LoanRow.new()
	done.months = 3
	done.paid = 3
	stub.loans = [active, done]
	var sub_cost: int = SubscriptionManager.monthly_cost()
	TestFixtures.check(res, "loans and services adds the monthly loans to the subscription",
		FinanceLedger.loans_and_services() == sub_cost + _LoanStub.PAYMENT,
		"%d against %d" % [FinanceLedger.loans_and_services(), sub_cost + _LoanStub.PAYMENT])
	var proj: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_MONTH)
	var loans: Dictionary = _row_of(proj["rows"], "loans")
	TestFixtures.check(res, "the services row counts the one 15th of the month",
		int(loans["count"]) == 1, "%d" % int(loans["count"]))
	TestFixtures.check(res, "an active loan pays once and a finished loan pays nothing",
		int(loans["amount"]) == -(_LoanStub.PAYMENT + sub_cost),
		"%d against %d" % [int(loans["amount"]), -(_LoanStub.PAYMENT + sub_cost)])
	var quarter: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_QUARTER)
	var over: Dictionary = _row_of(quarter["rows"], "loans")
	TestFixtures.check(res, "three billing days take three instalments",
		int(over["amount"]) == -(_LoanStub.PAYMENT * 3 + sub_cost * 3),
		"%d over %d days" % [int(over["amount"]), int(quarter["days"])])
	active.months = 2
	active.paid = 1
	var capped: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_QUARTER)
	var left: Dictionary = _row_of(capped["rows"], "loans")
	TestFixtures.check(res, "a loan never pays past its remaining months",
		int(left["amount"]) == -(_LoanStub.PAYMENT + sub_cost * 3), "%d" % int(left["amount"]))
	stub.loans = []
	var bare: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_MONTH)
	TestFixtures.check(res, "with no loans only the subscription is left",
		int(_row_of(bare["rows"], "loans")["amount"]) == -sub_cost,
		"%d" % int(_row_of(bare["rows"], "loans")["amount"]))
	root.remove_child(stub)
	stub.free()
	real.name = "FinanceManager"


static func _case_projection_ads(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	PromotionsManager.reset()
	FinanceLedger.reset()
	TestFixtures.check(res, "the seeded promotions hold two ongoing campaigns",
		PromotionsManager.infinite_count() == 2, "%d" % PromotionsManager.infinite_count())
	var proj: Dictionary = FinanceLedger.projection(FinanceLedger.Horizon.END_OF_MONTH)
	var ads: Dictionary = _row_of(proj["rows"], "ads")
	var bills: Array[Dictionary] = PromotionsManager.ad_bill_days(0, int(proj["days"]))
	var want: int = 0
	for bill: Dictionary in bills:
		want += int(bill["amount"])
	TestFixtures.check(res, "the ads row debits every campaign bill in the window",
		int(ads["amount"]) == -want, "%d against %d" % [int(ads["amount"]), -want])
	TestFixtures.check(res, "the ads row counts the bills it found",
		int(ads["count"]) == bills.size(), "%d against %d" % [int(ads["count"]), bills.size()])
	TestFixtures.check(res, "the ads row names the ongoing campaigns",
		str(ads["sub"]) == "2 ongoing promos", str(ads["sub"]))
	TestFixtures.check(res, "the monthly ads figure follows the promotions manager",
		FinanceLedger.ads() == PromotionsManager.monthly_ad_bill(),
		"%d" % FinanceLedger.ads())
	_no_promos()
	TestFixtures.check(res, "with the campaigns gone the monthly ads figure is zero",
		FinanceLedger.ads() == 0, "%d" % FinanceLedger.ads())


static func _case_breakdown(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	_no_promos()
	FinanceLedger.reset()
	var rows: Array[Dictionary] = FinanceLedger.expense_breakdown()
	TestFixtures.check(res, "the breakdown holds the five prototype rows",
		_keys_of(rows) == ["payroll", "loans", "guild", "travel", "ads"],
		"got %s" % str(_keys_of(rows)))
	TestFixtures.check(res, "the breakdown rows are labelled as the prototype does",
		_labels_of(rows) == ["Payroll", "Loans & Services", "Guild Expenses", "Travel", "Ads"],
		"got %s" % str(_labels_of(rows)))
	TestFixtures.check(res, "the payroll row names its billing day and the wait",
		str(_row_of(rows, "payroll")["sub"]) == "2nd - 1 Day From Now",
		str(_row_of(rows, "payroll")["sub"]))
	TestFixtures.check(res, "the services row names the 15th",
		str(_row_of(rows, "loans")["sub"]) == "15th - 14 Days From Now",
		str(_row_of(rows, "loans")["sub"]))
	TestFixtures.check(res, "the guild row names the 29th",
		str(_row_of(rows, "guild")["sub"]) == "29th - 28 Days From Now",
		str(_row_of(rows, "guild")["sub"]))
	TestFixtures.check(res, "the travel row is an average per contract",
		str(_row_of(rows, "travel")["sub"]) == "Per contract (avg.)",
		str(_row_of(rows, "travel")["sub"]))
	TestFixtures.check(res, "with no campaigns the ads row says so",
		str(_row_of(rows, "ads")["sub"]) == "No ongoing promos",
		str(_row_of(rows, "ads")["sub"]))
	TestFixtures.check(res, "the breakdown reads the same figures as the month",
		int(_row_of(rows, "payroll")["amount"]) == FinanceLedger.payroll()
		and int(_row_of(rows, "loans")["amount"]) == FinanceLedger.loans_and_services()
		and int(_row_of(rows, "guild")["amount"]) == FinanceLedger.GUILD_RATE
		and int(_row_of(rows, "travel")["amount"]) == FinanceLedger.TRAVEL_RATE
		and int(_row_of(rows, "ads")["amount"]) == 0, "rows do not match the month")
	var top: int = 0
	for row: Dictionary in rows:
		top = maxi(top, int(row["amount"]))
	var bad: Array[String] = []
	for row: Dictionary in rows:
		var cells: int = int(row["cells"])
		if cells < 0 or cells > FinanceLedger.BREAKDOWN_CELLS:
			bad.append(str(row["key"]))
		elif int(row["amount"]) == top and cells != FinanceLedger.BREAKDOWN_CELLS:
			bad.append(str(row["key"]))
		elif int(row["amount"]) == 0 and cells != 0:
			bad.append(str(row["key"]))
	TestFixtures.check(res, "the tallest row fills the bar and an empty row lights nothing",
		bad.is_empty(), TestFixtures.detail(bad, rows.size(), "rows"))
	TestFixtures.check(res, "a larger expense never lights fewer cells",
		int(_row_of(rows, "travel")["cells"]) >= int(_row_of(rows, "guild")["cells"]),
		"%d against %d" % [int(_row_of(rows, "travel")["cells"]),
		int(_row_of(rows, "guild")["cells"])])
	GameState.mercs.clear()
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	var halved: Array[Dictionary] = FinanceLedger.expense_breakdown()
	TestFixtures.check(res, "half of the tallest expense lights half the bar",
		int(_row_of(halved, "guild")["cells"]) == 10
		and int(_row_of(halved, "travel")["cells"]) == 20,
		"guild %d travel %d" % [int(_row_of(halved, "guild")["cells"]),
		int(_row_of(halved, "travel")["cells"])])
	TestFixtures.check(res, "an all zero breakdown lights nothing",
		int(_row_of(halved, "payroll")["cells"]) == 0
		and int(_row_of(halved, "ads")["cells"]) == 0,
		"payroll %d" % int(_row_of(halved, "payroll")["cells"]))


static func _case_stat_cards(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	_no_promos()
	_fund(5000)
	FinanceLedger.reset()
	var cards: Array[Dictionary] = FinanceLedger.stat_cards()
	TestFixtures.check(res, "the overview shows four cards",
		_keys_of(cards) == ["notes", "income", "expenses", "net"], "got %s" % str(_keys_of(cards)))
	TestFixtures.check(res, "the cards are labelled as the prototype does",
		_labels_of(cards) == ["Current Notes", "Monthly Income", "Monthly Expenses",
		"Net / Month"], "got %s" % str(_labels_of(cards)))
	var notes: Dictionary = _row_of(cards, "notes")
	TestFixtures.check(res, "the notes card reads the bank with a thousands comma",
		str(notes["value"]) == TransactionData.grouped(GameState.bank_notes), str(notes["value"]))
	TestFixtures.check(res, "the notes card dates itself off the game calendar",
		str(notes["sub"]) == GuiDates.day_text(GameState.day()), str(notes["sub"]))
	TestFixtures.check(res, "the income card reads the ledger income",
		str(_row_of(cards, "income")["value"])
		== TransactionData.grouped(FinanceLedger.monthly_income())
		and str(_row_of(cards, "income")["sub"]) == "Contract rewards, last 30 days",
		str(_row_of(cards, "income")["value"]))
	TestFixtures.check(res, "the expenses card adds the five monthly lines",
		str(_row_of(cards, "expenses")["value"])
		== TransactionData.grouped(FinanceLedger.monthly_expenses()),
		str(_row_of(cards, "expenses")["value"]))
	TestFixtures.check(res, "the expenses card names the lines it adds",
		str(_row_of(cards, "expenses")["sub"]) == "Payroll, loans, guild, travel, ads",
		str(_row_of(cards, "expenses")["sub"]))
	var net: int = FinanceLedger.net_month()
	var card: Dictionary = _row_of(cards, "net")
	TestFixtures.check(res, "the net card follows the sign of the month",
		str(card["sub"]) == ("Growing" if net >= 0 else "Shrinking")
		and (card["color"] as Color) == (FinanceLedger.GREEN if net >= 0 else FinanceLedger.RED),
		"net %d reads %s" % [net, str(card["sub"])])
	TestFixtures.check(res, "the monthly expenses add up to the five lines",
		FinanceLedger.monthly_expenses() == FinanceLedger.payroll()
		+ FinanceLedger.loans_and_services() + FinanceLedger.GUILD_RATE
		+ FinanceLedger.TRAVEL_RATE + FinanceLedger.ads(),
		"%d" % FinanceLedger.monthly_expenses())
	GameState.mercs.clear()
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	_no_loans()
	var rich: Array[Dictionary] = FinanceLedger.stat_cards()
	var grown: Dictionary = _row_of(rich, "net")
	var want_net: int = FinanceLedger.monthly_income() - FinanceLedger.GUILD_RATE - FinanceLedger.TRAVEL_RATE
	TestFixtures.check(res, "a guild with no wages nets the income less guild and travel",
		FinanceLedger.net_month() == want_net,
		"%d against %d" % [FinanceLedger.net_month(), want_net])
	TestFixtures.check(res, "a positive net reads with a plus and says it is growing",
		str(grown["value"]) == "+" + TransactionData.grouped(want_net)
		and str(grown["sub"]) == "Growing"
		and (grown["color"] as Color) == FinanceLedger.GREEN, str(grown["value"]))


static func _case_tick_subscription(res: Dictionary) -> void:
	_fresh()
	_at_day(13)
	_no_promos()
	_fund(20000)
	FinanceLedger.reset()
	FinanceLedger.transactions.clear()
	var cost: int = SubscriptionManager.monthly_cost()
	TestFixtures.check(res, "a bare Enterprise plan bills the roster fee",
		cost == ENTERPRISE_PER_MERC * GameState.mercs.size(), "%d" % cost)
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "the first tick after a reset only records the day",
		FinanceLedger.transactions.is_empty(), "%d rows" % FinanceLedger.transactions.size())
	CampaignClock.advance_to(14 * CampaignClock.MINUTES_PER_DAY
		+ 8 * CampaignClock.MINUTES_PER_HOUR)
	var before: int = GameState.bank_notes
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "the 15th bills the subscription once",
		FinanceLedger.transactions.size() == 1, "%d rows" % FinanceLedger.transactions.size())
	var row: TransactionData = FinanceLedger.rows()[0]
	TestFixtures.check(res, "the subscription bill files under Subscription",
		row.category == "Subscription" and row.reason == "subscription", row.category)
	TestFixtures.check(res, "the subscription bill carries the prototype label",
		row.label == FinanceLedger.SUBSCRIPTION_LABEL, row.label)
	TestFixtures.check(res, "the subscription bill debits the monthly cost", row.amount == -cost,
		"%d against %d" % [row.amount, -cost])
	TestFixtures.check(res, "the subscription bill leaves the bank short",
		GameState.bank_notes == before - cost, "%d" % GameState.bank_notes)
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "a second tick on the same day bills nothing again",
		FinanceLedger.transactions.size() == 1, "%d rows" % FinanceLedger.transactions.size())


static func _case_tick_guild(res: Dictionary) -> void:
	_fresh()
	_at_day(27)
	_no_promos()
	_fund(20000)
	FinanceLedger.reset()
	FinanceLedger.transactions.clear()
	FinanceLedger.tick(CampaignClock.now())
	CampaignClock.advance_to(28 * CampaignClock.MINUTES_PER_DAY
		+ 8 * CampaignClock.MINUTES_PER_HOUR)
	var before: int = GameState.bank_notes
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "the 29th bills the guild expenses once",
		FinanceLedger.transactions.size() == 1, "%d rows" % FinanceLedger.transactions.size())
	var row: TransactionData = FinanceLedger.rows()[0]
	TestFixtures.check(res, "the guild bill files under Guild with the prototype label",
		row.category == "Guild" and row.label == FinanceLedger.GUILD_LABEL,
		"%s %s" % [row.category, row.label])
	TestFixtures.check(res, "the guild bill debits the monthly rate",
		row.amount == -FinanceLedger.GUILD_RATE
		and GameState.bank_notes == before - FinanceLedger.GUILD_RATE, "%d" % row.amount)


static func _case_tick_jump(res: Dictionary) -> void:
	_fresh()
	_at_day(0)
	_no_promos()
	_fund(20000)
	FinanceLedger.reset()
	FinanceLedger.transactions.clear()
	var cost: int = SubscriptionManager.monthly_cost()
	FinanceLedger.tick(CampaignClock.now())
	var before: int = GameState.bank_notes
	CampaignClock.advance_to(45 * CampaignClock.MINUTES_PER_DAY
		+ 8 * CampaignClock.MINUTES_PER_HOUR)
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "a forty five day jump bills every day it passed",
		FinanceLedger.transactions.size() == 3,
		"%d rows" % FinanceLedger.transactions.size())
	var order: Array[String] = []
	for held: TransactionData in FinanceLedger.transactions:
		order.append(held.category)
	TestFixtures.check(res, "the bills of a jump land in calendar order",
		order == ["Subscription", "Guild", "Subscription"], "got %s" % str(order))
	TestFixtures.check(res, "a jump debits two subscriptions and one guild bill",
		GameState.bank_notes == before - cost * 2 - FinanceLedger.GUILD_RATE,
		"%d against %d" % [GameState.bank_notes, before - cost * 2 - FinanceLedger.GUILD_RATE])
	TestFixtures.check(res, "the rows of a jump are stamped at the end of the jump",
		FinanceLedger.rows()[0].day_index == 45, "%d" % FinanceLedger.rows()[0].day_index)
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "a tick with no day passed bills nothing",
		FinanceLedger.transactions.size() == 3, "%d rows" % FinanceLedger.transactions.size())


static func _case_tick_free_plan(res: Dictionary) -> void:
	_fresh()
	_at_day(13)
	_no_promos()
	_fund(20000)
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	FinanceLedger.reset()
	FinanceLedger.transactions.clear()
	TestFixtures.check(res, "the free plan costs nothing a month",
		SubscriptionManager.monthly_cost() == 0, "%d" % SubscriptionManager.monthly_cost())
	FinanceLedger.tick(CampaignClock.now())
	CampaignClock.advance_to(14 * CampaignClock.MINUTES_PER_DAY
		+ 8 * CampaignClock.MINUTES_PER_HOUR)
	var before: int = GameState.bank_notes
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "a subscription that costs nothing files no bill",
		FinanceLedger.transactions.is_empty() and GameState.bank_notes == before,
		"%d rows" % FinanceLedger.transactions.size())
	CampaignClock.advance_to(28 * CampaignClock.MINUTES_PER_DAY
		+ 8 * CampaignClock.MINUTES_PER_HOUR)
	FinanceLedger.tick(CampaignClock.now())
	TestFixtures.check(res, "the guild bill still lands on the free plan",
		FinanceLedger.transactions.size() == 1
		and FinanceLedger.rows()[0].category == "Guild",
		"%d rows" % FinanceLedger.transactions.size())


#Counts the changed emissions of one case.
class _Counter extends RefCounted:
	var count: int = 0

	func bump() -> void:
		count += 1


#One loan of the stub below: the months it runs and the months already paid.
class _LoanRow extends RefCounted:
	var months: int = 0
	var paid: int = 0


#Stands in for the FinanceManager of GX2F, which carries no loans on this copy.
class _LoanStub extends Node:
	const PAYMENT: int = 100

	var loans: Array = []

	func monthly_loans() -> int:
		var total: int = 0
		for loan: Variant in loans:
			var row: _LoanRow = loan as _LoanRow
			if row != null and row.paid < row.months:
				total += PAYMENT
		return total

	func loan_payment(_loan: Object) -> int:
		return PAYMENT
