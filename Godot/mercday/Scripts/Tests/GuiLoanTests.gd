class_name GuiLoanTests

#The loan formulas against the prototype figures, then the FinanceManager flow: requests carried
#by envoys, the offers they come back with, the payments on each loan's own bill day and the two ways
#a loan ends. Every case starts a fresh campaign with 1000 notes, which is the money the prototype worked
#from; a new game holds no loans and no offers, so the cases that need some build them with _fresh_seeded.

const MONEY: int = 1000
const HOUR: int = CampaignClock.MINUTES_PER_HOUR
const DAY: int = CampaignClock.MINUTES_PER_DAY
#Day indexes after the start on the 3rd of Erta (day 122); Erta and Orlin run 40 days.
const ERTA_START: int = 122
const ERTA_13: int = 132
const ERTA_14: int = 133
const ERTA_15: int = 134
const KUSARRA_1: int = 160
const KUSARRA_2: int = 161
const KUSARRA_15: int = 174
const KUSARRA_16: int = 175
const URBAI_2: int = 191
const URBAI_15: int = 204
const ORLIN_2: int = 251
const TEK_15: int = 304
const SEED_PAY_1: int = 180
const SEED_PAY_2: int = 150
const SEED_BILL: int = SEED_PAY_1 + SEED_PAY_2
#The ids the fixture loans take from FinanceManager.FIRST_LOAN_ID, in the order _seed_fixture adds them.
const LOAN_1: int = 203
const LOAN_2: int = 204
const CLOSED_1: int = 205
const CLOSED_2: int = 206
const NEW_LOAN: int = 207
#The fixture offers: what was asked, what came back and the hours each still stands.
const FIXTURE_OFFERS: Array[Dictionary] = [
	{"id": 101, "lender": "Lender 1", "amount": 1500, "rate": 0.08, "term": 6, "first_due": 2,
		"team": [3], "odds": 71, "outcome": "exact", "approved": true, "offer_amount": 1500,
		"offer_rate": 0.08, "offer_term": 6, "offer_first_due": 2, "hours": 90},
	{"id": 102, "lender": "Lender 2", "amount": 1000, "rate": 0.12, "term": 6, "first_due": 2,
		"team": [3, 8], "odds": 83, "outcome": "better", "approved": true, "offer_amount": 1200,
		"offer_rate": 0.1, "offer_term": 6, "offer_first_due": 3, "hours": 30},
	{"id": 103, "lender": "Lender 3", "amount": 4000, "rate": 0.25, "term": 12, "first_due": 3,
		"team": [5], "odds": 34, "outcome": "worse", "approved": false, "offer_amount": 2800,
		"offer_rate": 0.29, "offer_term": 12, "offer_first_due": 1, "hours": 8},
	{"id": 104, "lender": "Lender 4", "amount": 2000, "rate": 0.14, "term": 12, "first_due": 2,
		"team": [], "odds": 58, "outcome": "exact", "approved": true, "offer_amount": 2000,
		"offer_rate": 0.14, "offer_term": 12, "offer_first_due": 2, "hours": 60},
]


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	_case_fit(res)
	_case_terms(res)
	_case_limits(res)
	_case_lender_1(res)
	_case_lender_3(res)
	_case_lender_5(res)
	_case_payments(res)
	_case_resolve(res)
	_case_text(res)
	_case_seed(res)
	_case_lenders(res)
	_case_refusals(res)
	_case_envoys(res)
	_case_no_envoys(res)
	_case_expiry(res)
	_case_expired_offer(res)
	_case_accept(res)
	_case_reject(res)
	_case_bill_day(res)
	_case_own_bill_day(res)
	_case_long_month(res)
	_case_first_due(res)
	_case_pay_off(res)
	_case_history(res)
	_case_seed_alerts(res)
	_case_expired_escalation(res)
	_case_offer_urgency(res)
	_case_default_urgency(res)
	_case_seeded_raises(res)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	FinanceManager.reset()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI LOAN")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	_set_money(MONEY)
	NotificationCenter.reset()
	FinanceManager.reset()


#A fresh campaign holding the prototype books: two running loans, two closed ones and four offers.
static func _fresh_seeded() -> void:
	_fresh()
	_seed_fixture()


#Loan 1 is taken today and bills on the day bill_day_from gives (the 2nd); loan 2 is pinned to the 15th.
#Offers outside their last day are announced the way a landed offer is; 103 is left to escalate.
static func _seed_fixture() -> void:
	var first: LoanData = TestFixtures.add_loan("Lender 1", 2000, 0.08, 12, -1, LoanLogic.FIRST_DUE_MIN)
	first.paid = 4
	var second: LoanData = TestFixtures.add_loan("Lender 2", 800, 0.12, 6, 15, LoanLogic.FIRST_DUE_MIN)
	second.paid = 1
	var full: LoanData = TestFixtures.add_loan("Lender 2", 600, 0.12, 6, -1, LoanLogic.FIRST_DUE_MIN)
	full.paid = 6
	FinanceManager._close_loan(full, "Paid in Full", 672)
	var early: LoanData = TestFixtures.add_loan("Lender 1", 1200, 0.08, 12, -1, LoanLogic.FIRST_DUE_MIN)
	early.paid = 7
	FinanceManager._close_loan(early, "Paid Off Early", 1263)
	var now: int = CampaignClock.now()
	for source: Dictionary in FIXTURE_OFFERS:
		FinanceManager.offers.append(FinanceManager._make_offer(int(source["id"]), source,
			now + int(source["hours"]) * HOUR))
	for source: Dictionary in FIXTURE_OFFERS:
		if float(source["hours"]) > FinanceManager.OFFER_URGENT_HOURS:
			FinanceManager._push_offer(int(source["id"]))
	FinanceManager.offers_changed.emit()
	FinanceManager.loans_changed.emit()


static func _set_money(amount: int) -> void:
	if GameState.bank_notes > amount:
		GameState.spend(GameState.bank_notes - amount)
	elif GameState.bank_notes < amount:
		GameState.refund(amount - GameState.bank_notes)


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0005


static func _lender(index: int) -> Dictionary:
	return FinanceManager.LENDER_ROWS[index]


#A sorted copy of GameState.busy_uids(), so two reads compare by value.
static func _busy_now() -> Array[int]:
	var out: Array[int] = GameState.busy_uids().duplicate()
	out.sort()
	return out


static func _draft(amount: int, term_idx: int, rate_mul: float, first_due: int) -> Dictionary:
	return {"amount": amount, "term_idx": term_idx, "rate_mul": rate_mul,
		"first_due": first_due}


#Moves the clock and hands the new minute to the manager, the way process_until does.
static func _tick_at(minute: int) -> void:
	CampaignClock.advance_to(minute)
	FinanceManager.tick(CampaignClock.now())


static func _uids(count: int) -> Array[int]:
	var out: Array[int] = []
	for merc: MercenaryData in GameState.mercs:
		if out.size() >= count:
			break
		out.append(merc.merc_uid)
	return out


#Case 1: the envoy fit and its stars.
static func _case_fit(res: Dictionary) -> void:
	TestFixtures.check(res, "a Performer counts 40 per cent of the fit",
		_near(LoanLogic.loan_fit("Performer", 8, 9), 0.91),
		"%f" % LoanLogic.loan_fit("Performer", 8, 9))
	TestFixtures.check(res, "a Warrior counts the same as a Performer",
		_near(LoanLogic.loan_fit("Warrior", 8, 9), LoanLogic.loan_fit("Performer", 8, 9)),
		"%f" % LoanLogic.loan_fit("Warrior", 8, 9))
	TestFixtures.check(res, "another tradition brings Wile and Vigor only",
		_near(LoanLogic.loan_fit("Mage", 3, 4), 0.21),
		"%f" % LoanLogic.loan_fit("Mage", 3, 4))
	TestFixtures.check(res, "the best envoy is five stars",
		_near(LoanLogic.fit_stars(LoanLogic.loan_fit("Warrior", 10, 10)), 5.0),
		"%f" % LoanLogic.fit_stars(LoanLogic.loan_fit("Warrior", 10, 10)))
	TestFixtures.check(res, "a strong envoy is four and a half stars",
		_near(LoanLogic.fit_stars(0.91), 4.5), "%f" % LoanLogic.fit_stars(0.91))
	TestFixtures.check(res, "a poor envoy is one and a half stars",
		_near(LoanLogic.fit_stars(0.21), 1.5), "%f" % LoanLogic.fit_stars(0.21))
	TestFixtures.check(res, "no fit at all is still half a star",
		_near(LoanLogic.fit_stars(0.0), 0.5), "%f" % LoanLogic.fit_stars(0.0))


#Case 2: the terms a lender offers and how they read.
static func _case_terms(res: Dictionary) -> void:
	var terms: Array[int] = LoanLogic.term_options()
	TestFixtures.check(res, "there are 24 terms from 3 months to 6 years",
		terms.size() == 24 and terms[0] == 3 and terms[23] == 72,
		"%d terms, %d to %d" % [terms.size(), terms[0], terms[terms.size() - 1]])
	TestFixtures.check(res, "under a year a term reads in months",
		LoanLogic.term_label(3) == "3 Months" and LoanLogic.term_label(9) == "9 Months",
		"%s / %s" % [LoanLogic.term_label(3), LoanLogic.term_label(9)])
	TestFixtures.check(res, "a whole year reads as one year",
		LoanLogic.term_label(12) == "1 Year", LoanLogic.term_label(12))
	TestFixtures.check(res, "a year and a part reads both",
		LoanLogic.term_label(21) == "1 Year, 9 Mo", LoanLogic.term_label(21))
	TestFixtures.check(res, "whole years read in the plural",
		LoanLogic.term_label(24) == "2 Years" and LoanLogic.term_label(72) == "6 Years",
		"%s / %s" % [LoanLogic.term_label(24), LoanLogic.term_label(72)])


#Case 3: how much a lender will lend and how long for.
static func _case_limits(res: Dictionary) -> void:
	TestFixtures.check(res, "a friendly lender lends its capacity and half the guild notes",
		LoanLogic.amount_max(_lender(0), MONEY) == 4500,
		"%d" % LoanLogic.amount_max(_lender(0), MONEY))
	TestFixtures.check(res, "a cold lender lends less than its capacity says",
		LoanLogic.amount_max(_lender(2), MONEY) == 6000,
		"%d" % LoanLogic.amount_max(_lender(2), MONEY))
	TestFixtures.check(res, "a lender with no feeling either way lends its capacity",
		LoanLogic.amount_max(_lender(4), MONEY) == 2500,
		"%d" % LoanLogic.amount_max(_lender(4), MONEY))
	TestFixtures.check(res, "a request above twice the notes needs six months",
		LoanLogic.months_min(2300, MONEY) == 6 and LoanLogic.months_min(500, MONEY) == 3,
		"%d / %d" % [LoanLogic.months_min(2300, MONEY), LoanLogic.months_min(500, MONEY)])
	TestFixtures.check(res, "the longest term grows with the relationship",
		LoanLogic.months_max(4) == 72 and LoanLogic.months_max(0) == 48
		and LoanLogic.months_max(-1) == 24 and LoanLogic.months_max(-3) == 12,
		"%d %d %d %d" % [LoanLogic.months_max(4), LoanLogic.months_max(0),
		LoanLogic.months_max(-1), LoanLogic.months_max(-3)])
	TestFixtures.check(res, "asking a month early is worth five odds",
		_near(LoanLogic.first_due_odds(1), 5.0), "%f" % LoanLogic.first_due_odds(1))
	TestFixtures.check(res, "the suggested month costs nothing",
		_near(LoanLogic.first_due_odds(2), 0.0), "%f" % LoanLogic.first_due_odds(2))
	TestFixtures.check(res, "every month later than that costs twice the one before",
		_near(LoanLogic.first_due_odds(3), -5.0) and _near(LoanLogic.first_due_odds(4), -15.0)
		and _near(LoanLogic.first_due_odds(6), -75.0),
		"%f %f %f" % [LoanLogic.first_due_odds(3), LoanLogic.first_due_odds(4),
		LoanLogic.first_due_odds(6)])


#Case 4: three drafts to the friendliest lender.
static func _case_lender_1(res: Dictionary) -> void:
	var row: Dictionary = _lender(0)
	var fair: Dictionary = LoanLogic.fair_draft(row, MONEY)
	TestFixtures.check(res, "the fair draft is half the maximum over 21 months",
		int(fair["amount"]) == 2300 and int(fair["term_idx"]) == 6
		and _near(float(fair["rate_mul"]), 1.0) and int(fair["first_due"]) == 2, "%s" % [fair])
	var a: Dictionary = LoanLogic.request(row, fair, MONEY, 0.0)
	TestFixtures.check(res, "the fair draft asks 2300 over 21 months",
		int(a["amount"]) == 2300 and int(a["months"]) == 21 and int(a["min_months"]) == 6
		and int(a["max_months"]) == 72,
		"%d over %d months" % [int(a["amount"]), int(a["months"])])
	TestFixtures.check(res, "the fair rate of that draft is 7.8 per cent",
		_near(float(a["fair"]), 0.0779444) and _near(float(a["rate"]), 0.078),
		"fair %f, rate %f" % [float(a["fair"]), float(a["rate"])])
	TestFixtures.check(res, "it costs 179 in interest and 119 a month",
		int(a["interest"]) == 179 and int(a["monthly"]) == 119,
		"%d interest, %d monthly" % [int(a["interest"]), int(a["monthly"])])
	TestFixtures.check(res, "the odds of the fair draft are 57 with no envoys",
		int(a["odds"]) == 57, "%d" % int(a["odds"]))
	var b: Dictionary = LoanLogic.request(row, _draft(500, 0, 1.6, 1), MONEY, 0.7)
	TestFixtures.check(res, "a small early request over the fair rate is certain",
		int(b["months"]) == 3 and _near(float(b["rate"]), 0.075) and int(b["odds"]) == 95,
		"%d months, rate %f, odds %d" % [int(b["months"]), float(b["rate"]), int(b["odds"])])
	TestFixtures.check(res, "a three month loan of 500 costs 180 a month",
		int(b["interest"]) == 38 and int(b["monthly"]) == 180,
		"%d interest, %d monthly" % [int(b["interest"]), int(b["monthly"])])
	var c: Dictionary = LoanLogic.request(row, _draft(1000000, 23, 0.6, 6), MONEY, 2.1)
	TestFixtures.check(res, "everything the lender has over six years is hopeless",
		int(c["amount"]) == 4500 and int(c["months"]) == 72 and int(c["odds"]) == 5,
		"%d over %d months, odds %d" % [int(c["amount"]), int(c["months"]), int(c["odds"])])
	TestFixtures.check(res, "the rate under the fair one is held at 60 per cent of it",
		_near(float(c["fair"]), 0.14) and _near(float(c["rate"]), 0.084),
		"fair %f, rate %f" % [float(c["fair"]), float(c["rate"])])
	TestFixtures.check(res, "the biggest loan costs 378 in interest and 68 a month",
		int(c["interest"]) == 378 and int(c["monthly"]) == 68,
		"%d interest, %d monthly" % [int(c["interest"]), int(c["monthly"])])
	TestFixtures.check(res, "the fair term index follows the share asked for",
		int(a["fair_idx"]) == 6 and int(b["fair_idx"]) == 2 and int(c["fair_idx"]) == 11,
		"%d %d %d" % [int(a["fair_idx"]), int(b["fair_idx"]), int(c["fair_idx"])])


#Case 5: the same three drafts to a lender that dislikes the guild.
static func _case_lender_3(res: Dictionary) -> void:
	var row: Dictionary = _lender(2)
	var fair: Dictionary = LoanLogic.fair_draft(row, MONEY)
	TestFixtures.check(res, "the cold lender starts at 3000 over 21 months",
		int(fair["amount"]) == 3000 and int(fair["term_idx"]) == 6, "%s" % [fair])
	var a: Dictionary = LoanLogic.request(row, fair, MONEY, 0.0)
	TestFixtures.check(res, "it holds the term to two years",
		int(a["max_months"]) == 24 and int(a["lo"]) == 1 and int(a["hi"]) == 7,
		"max %d, lo %d, hi %d" % [int(a["max_months"]), int(a["lo"]), int(a["hi"])])
	TestFixtures.check(res, "its fair rate is 22.75 per cent",
		_near(float(a["fair"]), 0.2275) and _near(float(a["rate"]), 0.227),
		"fair %f, rate %f" % [float(a["fair"]), float(a["rate"])])
	TestFixtures.check(res, "3000 from it costs 681 in interest and 176 a month",
		int(a["interest"]) == 681 and int(a["monthly"]) == 176 and int(a["odds"]) == 32,
		"%d interest, %d monthly, odds %d"
		% [int(a["interest"]), int(a["monthly"]), int(a["odds"])])
	var b: Dictionary = LoanLogic.request(row, _draft(500, 0, 1.6, 1), MONEY, 0.7)
	TestFixtures.check(res, "paying it well over the fair rate buys good odds",
		_near(float(b["rate"]), 0.313) and int(b["odds"]) == 86,
		"rate %f, odds %d" % [float(b["rate"]), int(b["odds"])])
	var c: Dictionary = LoanLogic.request(row, _draft(1000000, 23, 0.6, 6), MONEY, 2.1)
	TestFixtures.check(res, "its whole capacity is 6000 over two years at 15 per cent",
		int(c["amount"]) == 6000 and int(c["months"]) == 24 and _near(float(c["rate"]), 0.15),
		"%d over %d at %f" % [int(c["amount"]), int(c["months"]), float(c["rate"])])
	TestFixtures.check(res, "the biggest loan from it costs 900 and 288 a month",
		_near(float(c["fair"]), 0.25) and int(c["interest"]) == 900 and int(c["monthly"]) == 288,
		"fair %f, %d interest, %d monthly"
		% [float(c["fair"]), int(c["interest"]), int(c["monthly"])])


#Case 6: a lender with no feeling either way.
static func _case_lender_5(res: Dictionary) -> void:
	var row: Dictionary = _lender(4)
	var fair: Dictionary = LoanLogic.fair_draft(row, MONEY)
	TestFixtures.check(res, "it starts at 1300 over 21 months",
		int(fair["amount"]) == 1300 and int(fair["term_idx"]) == 6, "%s" % [fair])
	var a: Dictionary = LoanLogic.request(row, fair, MONEY, 0.0)
	TestFixtures.check(res, "a request inside twice the notes may run three months",
		int(a["min_months"]) == 3 and int(a["lo"]) == 0 and int(a["max_months"]) == 48,
		"min %d, lo %d, max %d" % [int(a["min_months"]), int(a["lo"]), int(a["max_months"])])
	TestFixtures.check(res, "1300 from it costs 205 in interest and 72 a month",
		_near(float(a["rate"]), 0.158) and int(a["interest"]) == 205 and int(a["monthly"]) == 72
		and int(a["odds"]) == 37, "rate %f, %d interest, %d monthly, odds %d"
		% [float(a["rate"]), int(a["interest"]), int(a["monthly"]), int(a["odds"])])
	var b: Dictionary = LoanLogic.request(row, _draft(500, 0, 1.6, 1), MONEY, 0.7)
	TestFixtures.check(res, "a small request early at a high rate is nearly certain",
		_near(float(b["rate"]), 0.209) and int(b["odds"]) == 88 and int(b["fair_idx"]) == 3,
		"rate %f, odds %d, fair term %d"
		% [float(b["rate"]), int(b["odds"]), int(b["fair_idx"])])
	var c: Dictionary = LoanLogic.request(row, _draft(1000000, 23, 0.6, 6), MONEY, 2.1)
	TestFixtures.check(res, "its whole capacity runs four years at 12 per cent",
		int(c["amount"]) == 2500 and int(c["months"]) == 48 and _near(float(c["rate"]), 0.12)
		and int(c["monthly"]) == 59, "%d over %d at %f, %d monthly"
		% [int(c["amount"]), int(c["months"]), float(c["rate"]), int(c["monthly"])])


#Case 7: what a loan costs a month and what clearing it costs.
static func _case_payments(res: Dictionary) -> void:
	TestFixtures.check(res, "a 2000 loan over a year at 8 per cent pays 180 a month",
		LoanLogic.payment(2000, 0.08, 12) == 180, "%d" % LoanLogic.payment(2000, 0.08, 12))
	TestFixtures.check(res, "an 800 loan over six months at 12 per cent pays 150",
		LoanLogic.payment(800, 0.12, 6) == 150, "%d" % LoanLogic.payment(800, 0.12, 6))
	TestFixtures.check(res, "a 1500 loan over six months at 8 per cent pays 270",
		LoanLogic.payment(1500, 0.08, 6) == 270, "%d" % LoanLogic.payment(1500, 0.08, 6))
	TestFixtures.check(res, "clearing the 2000 loan after four payments costs 1334",
		LoanLogic.payoff(2000, 12, 4) == 1334, "%d" % LoanLogic.payoff(2000, 12, 4))
	TestFixtures.check(res, "clearing the 800 loan after one payment costs 667",
		LoanLogic.payoff(800, 6, 1) == 667, "%d" % LoanLogic.payoff(800, 6, 1))
	TestFixtures.check(res, "a loan paid to the end costs nothing to clear",
		LoanLogic.payoff(800, 6, 6) == 0, "%d" % LoanLogic.payoff(800, 6, 6))


#Case 8: the three answers a lender can come back with.
static func _case_resolve(res: Dictionary) -> void:
	var req: Dictionary = {"amount": 1500, "rate": 0.08, "term": 6, "first_due": 2, "odds": 71,
		"team": [3]}
	var better: Dictionary = LoanLogic.resolve(req, 0.1, 0.5, 0.5)
	TestFixtures.check(res, "a low roll with envoys beats the request",
		String(better["outcome"]) == "better" and int(better["offer_amount"]) == 1800
		and _near(float(better["offer_rate"]), 0.06), "%s" % [better])
	TestFixtures.check(res, "a better offer puts the first payment a month later",
		int(better["offer_first_due"]) == 3 and bool(better["approved"]),
		"first due %d, approved %s" % [int(better["offer_first_due"]),
		bool(better["approved"])])
	var exact: Dictionary = LoanLogic.resolve(req, 0.5, 0.5, 0.5)
	TestFixtures.check(res, "a roll under the odds matches the request",
		String(exact["outcome"]) == "exact" and int(exact["offer_amount"]) == 1500
		and _near(float(exact["offer_rate"]), 0.08) and int(exact["offer_first_due"]) == 2,
		"%s" % [exact])
	var worse: Dictionary = LoanLogic.resolve(req, 0.99, 0.5, 0.5)
	TestFixtures.check(res, "a roll over the odds comes back with less at a higher rate",
		String(worse["outcome"]) == "worse" and int(worse["offer_amount"]) == 1100
		and _near(float(worse["offer_rate"]), 0.13), "%s" % [worse])
	TestFixtures.check(res, "a worse offer is not approved and wants paying a month sooner",
		not bool(worse["approved"]) and int(worse["offer_first_due"]) == 1,
		"approved %s, first due %d" % [bool(worse["approved"]),
		int(worse["offer_first_due"])])
	var worst: Dictionary = LoanLogic.resolve(req, 0.99, 1.0, 1.0)
	TestFixtures.check(res, "the second and third rolls size the worse offer",
		int(worst["offer_amount"]) == 1300 and _near(float(worst["offer_rate"]), 0.15),
		"%s" % [worst])
	var alone: Dictionary = LoanLogic.resolve({"amount": 1500, "rate": 0.08, "term": 6,
		"first_due": 2, "odds": 71, "team": []}, 0.1, 0.5, 0.5)
	TestFixtures.check(res, "a request with nobody carrying it can never beat itself",
		String(alone["outcome"]) == "exact", "%s" % [alone])
	TestFixtures.check(res, "the term of an offer is the term that was asked for",
		int(better["offer_term"]) == 6 and int(worse["offer_term"]) == 6,
		"%d / %d" % [int(better["offer_term"]), int(worse["offer_term"])])


#The text and the colours the screens print.
static func _case_text(res: Dictionary) -> void:
	TestFixtures.check(res, "an offer deadline reads in days and hours",
		LoanLogic.deadline_text(90.0) == "Offer Expires in 3 Days, 18 Hours",
		LoanLogic.deadline_text(90.0))
	TestFixtures.check(res, "a deadline inside a day reads no days",
		LoanLogic.deadline_text(8.0) == "Offer Expires in 0 Days, 8 Hours",
		LoanLogic.deadline_text(8.0))
	TestFixtures.check(res, "a deadline over two days is calm, one day is late",
		LoanLogic.deadline_color(90.0) == LoanLogic.DEADLINE_CALM
		and LoanLogic.deadline_color(30.0) == LoanLogic.DEADLINE_WARN
		and LoanLogic.deadline_color(8.0) == LoanLogic.DEADLINE_LATE, "colours differ")
	TestFixtures.check(res, "the odds colour follows the six prototype bands",
		LoanLogic.odds_color(95) == GuiColors.DEEP_GREEN
		and LoanLogic.odds_color(71) == GuiColors.GREEN
		and LoanLogic.odds_color(57) == GuiColors.LIGHT_BLUE
		and LoanLogic.odds_color(45) == GuiColors.AMBER
		and LoanLogic.odds_color(30) == GuiColors.ORANGE
		and LoanLogic.odds_color(10) == GuiColors.RED, "colours differ")


#Case 10: a new game starts with empty books; the fixture loans, closed loans and offers read back.
static func _case_seed(res: Dictionary) -> void:
	_fresh()
	TestFixtures.check(res, "a new game holds no loans, no closed loans, no offers and no requests",
		FinanceManager.loans.is_empty() and FinanceManager.closed_loans.is_empty()
		and FinanceManager.offers.is_empty() and FinanceManager.requests.is_empty()
		and not FinanceManager.has_offers() and FinanceManager.monthly_loans() == 0,
		"%d loans, %d closed, %d offers" % [FinanceManager.loans.size(),
		FinanceManager.closed_loans.size(), FinanceManager.offers.size()])
	_seed_fixture()
	TestFixtures.check(res, "two loans run and two are closed",
		FinanceManager.loans.size() == 2 and FinanceManager.closed_loans.size() == 2,
		"%d loans, %d closed" % [FinanceManager.loans.size(),
		FinanceManager.closed_loans.size()])
	var first: LoanData = FinanceManager.loans[0]
	TestFixtures.check(res, "the first loan owes 2000 over a year with four payments made",
		first.id == LOAN_1 and first.principal == 2000 and first.months == 12 and first.paid == 4
		and first.first_due == LoanLogic.FIRST_DUE_MIN and not first.is_closed(), "%s" % [first.to_row()])
	TestFixtures.check(res, "a loan taken on the 3rd of Erta bills on the 2nd, a pinned one on the 15th",
		first.bill_day == 2 and FinanceManager.loans[1].bill_day == 15,
		"%d and %d" % [first.bill_day, FinanceManager.loans[1].bill_day])
	TestFixtures.check(res, "the first loan pays 180 a month with eight months left",
		FinanceManager.loan_payment(first) == SEED_PAY_1 and first.months_left() == 8,
		"%d a month, %d left" % [FinanceManager.loan_payment(first), first.months_left()])
	TestFixtures.check(res, "the two loans together cost 330 a month",
		FinanceManager.monthly_loans() == SEED_BILL, "%d" % FinanceManager.monthly_loans())
	var closed: LoanData = FinanceManager.closed_loans[1]
	TestFixtures.check(res, "a closed loan keeps how it ended and what it cost",
		closed.closed_as == "Paid Off Early" and closed.paid_total == 1263,
		"%s for %d" % [closed.closed_as, closed.paid_total])
	TestFixtures.check(res, "adding loans without the accept path leaves the bank alone",
		GameState.bank_notes == MONEY, "%d notes" % GameState.bank_notes)
	TestFixtures.check(res, "four offers arrive unread",
		FinanceManager.offers.size() == 4 and FinanceManager.has_offers(),
		"%d offers, unread %s" % [FinanceManager.offers.size(), FinanceManager.has_offers()])
	var offer: Dictionary = FinanceManager.offer(101)
	TestFixtures.check(res, "an offer carries what was asked and what came back",
		int(offer["amount"]) == 1500 and int(offer["offer_amount"]) == 1500
		and String(offer["outcome"]) == "exact" and bool(offer["approved"]),
		"%s" % [offer])
	TestFixtures.check(res, "an offer still carries the old rate and month keys",
		int(offer["rate_pct"]) == 8 and int(offer["months"]) == 6,
		"%d per cent over %d months" % [int(offer["rate_pct"]), int(offer["months"])])
	TestFixtures.check(res, "the first offer stands for 90 hours",
		int(offer["expires_minute"]) == CampaignClock.now() + 90 * HOUR
		and _near(FinanceManager.hours_left(101), 90.0),
		"%f hours" % FinanceManager.hours_left(101))
	TestFixtures.check(res, "an offer nobody has is gone and has no hours",
		FinanceManager.offer(999).is_empty() and _near(FinanceManager.hours_left(999), 0.0),
		"%f hours" % FinanceManager.hours_left(999))
	var rows: Array[NotificationData] = NotificationCenter.rows_of(
		NotificationData.TYPE_LOAN_OFFER, 101)
	TestFixtures.check(res, "the offer with three days left is announced once",
		rows.size() == 1 and rows[0].urgency == NotificationData.Urgency.INFORMATIONAL
		and rows[0].kind == "Finance", "%d rows" % rows.size())
	TestFixtures.check(res, "an offer already inside its last day is left to escalate",
		NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 103).is_empty(),
		"%d rows" % NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 103).size())
	var announced: Array[int] = []
	for id: int in [101, 102, 104]:
		var notice: NotificationData = NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER, id)
		var row_count: int = NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, id).size()
		if row_count == 1 and notice.alerted and notice.urgency == NotificationData.Urgency.INFORMATIONAL:
			announced.append(id)
	TestFixtures.check(res, "every offer outside its last day is announced once and alerted",
		announced.size() == 3, "announced %s" % [announced])
	var snap: Dictionary = FinanceManager.offer_snap(101)
	TestFixtures.check(res, "the snap of an offer carries every pinned key",
		snap.has("lender") and snap.has("amount") and snap.has("rate") and snap.has("term")
		and snap.has("first_due") and snap.has("offer_amount") and snap.has("offer_rate")
		and snap.has("offer_term") and snap.has("offer_first_due") and snap.has("outcome")
		and snap.has("expires_in") and snap.has("odds") and snap.has("team")
		and snap.has("approved"), "keys %s" % [snap.keys()])
	FinanceManager.mark_offers_seen()
	TestFixtures.check(res, "marking the offers seen clears the Finance dot",
		not FinanceManager.has_offers(), "unread %s" % FinanceManager.has_offers())


#Case 11: what the manager tells a lender screen.
static func _case_lenders(res: Dictionary) -> void:
	_fresh_seeded()
	var rows: Array[Dictionary] = FinanceManager.lenders()
	TestFixtures.check(res, "eight lenders are listed with a standing, a rate, a cap and a road",
		rows.size() == 8 and rows[0].has("name") and rows[0].has("rel") and rows[0].has("base")
		and rows[0].has("cap") and rows[0].has("away_hours"), "%d rows %s" % [rows.size(),
		rows[0].keys() if rows.size() > 0 else []])
	TestFixtures.check(res, "one lender row reads out and an unknown name is empty",
		int(FinanceManager.lender_row("Lender 3")["cap"]) == 6000
		and FinanceManager.lender_row("Nobody").is_empty(),
		"%s" % [FinanceManager.lender_row("Lender 3")])
	TestFixtures.check(res, "a lender holding an offer is busy and a free one is not",
		FinanceManager.lender_busy("Lender 1") and not FinanceManager.lender_busy("Lender 5"),
		"one %s, five %s" % [FinanceManager.lender_busy("Lender 1"),
		FinanceManager.lender_busy("Lender 5")])
	var draft: Dictionary = FinanceManager.fair_draft("Lender 1")
	TestFixtures.check(res, "the sliders of a lender open on its fair draft",
		int(draft["amount"]) == 2300 and int(draft["term_idx"]) == 6
		and _near(float(draft["rate_mul"]), 1.0) and int(draft["first_due"]) == 2, "%s" % [draft])
	TestFixtures.check(res, "an unknown lender has no draft and no figures",
		FinanceManager.fair_draft("Nobody").is_empty()
		and FinanceManager.request_calc("Nobody", draft, [] as Array[int]).is_empty(), "read out")
	var calc: Dictionary = FinanceManager.request_calc("Lender 1", draft, [] as Array[int])
	TestFixtures.check(res, "the fair draft of a lender asks 2300 over 21 months at 119 a month",
		int(calc["amount"]) == 2300 and int(calc["months"]) == 21 and int(calc["monthly"]) == 119
		and int(calc["odds"]) == 57, "%d over %d at %d, odds %d" % [int(calc["amount"]),
		int(calc["months"]), int(calc["monthly"]), int(calc["odds"])])
	var team: Array[int] = _uids(2)
	var with_team: Dictionary = FinanceManager.request_calc("Lender 1", draft, team)
	TestFixtures.check(res, "sending envoys never lowers the odds of a draft",
		int(with_team["odds"]) >= int(calc["odds"]),
		"%d against %d" % [int(with_team["odds"]), int(calc["odds"])])
	var stars: float = FinanceManager.merc_fit(team[0])
	TestFixtures.check(res, "a merc is worth between half a star and five",
		stars >= 0.5 and stars <= 5.0 and _near(stars, float(roundi(stars * 2.0)) / 2.0),
		"%f stars" % stars)
	TestFixtures.check(res, "a merc nobody has is worth half a star",
		_near(FinanceManager.merc_fit(-1), 0.5), "%f stars" % FinanceManager.merc_fit(-1))


#One request the way a lender screen would hand it over.
static func _request(lender: String, team: Array[int], per: int) -> Dictionary:
	var calc: Dictionary = FinanceManager.request_calc(lender,
		FinanceManager.fair_draft(lender), team)
	return {"lender": lender, "amount": int(calc["amount"]), "rate": float(calc["rate"]),
		"term": int(calc["months"]), "first_due": int(calc["first_due"]), "team": team,
		"odds": int(calc["odds"]), "per": per}


#Case 12: the requests the manager turns down.
static func _case_refusals(res: Dictionary) -> void:
	_fresh_seeded()
	var team: Array[int] = _uids(2)
	var unknown: Dictionary = _request("Lender 5", team, 25)
	unknown["lender"] = "Nobody"
	TestFixtures.check(res, "a lender nobody knows takes no request",
		not FinanceManager.request_loan(unknown) and FinanceManager.requests.is_empty(),
		"%d requests" % FinanceManager.requests.size())
	TestFixtures.check(res, "a lender already holding an offer takes no request",
		not FinanceManager.request_loan(_request("Lender 1", team, 25)),
		"the busy lender took it")
	GameState.set_away(team[0], GuiTypes.MercStatus.CAPTURED)
	TestFixtures.check(res, "an envoy who is not at the guild cannot be sent",
		not FinanceManager.request_loan(_request("Lender 5", team, 25)), "the captive went")
	GameState.clear_away(team[0])
	var nobody: Dictionary = _request("Lender 5", [] as Array[int], 0)
	nobody["team"] = [-1] as Array[int]
	TestFixtures.check(res, "an envoy the guild does not have cannot be sent",
		not FinanceManager.request_loan(nobody), "a stranger went")
	TestFixtures.check(res, "a fee over the bank turns the request down and spends nothing",
		not FinanceManager.request_loan(_request("Lender 5", team, 600))
		and GameState.bank_notes == MONEY and FinanceManager.requests.is_empty(),
		"%d notes, %d requests" % [GameState.bank_notes, FinanceManager.requests.size()])


#Case 13: the envoys leave, the road takes 60 hours and they come back with an answer.
static func _case_envoys(res: Dictionary) -> void:
	_fresh_seeded()
	var team: Array[int] = _uids(2)
	var req: Dictionary = _request("Lender 5", team, 25)
	var sent: int = CampaignClock.now()
	var arrival: int = sent + int(_lender(4)["away_hours"]) * HOUR
	TestFixtures.check(res, "the request leaves and the fee is paid for every envoy",
		FinanceManager.request_loan(req) and GameState.bank_notes == MONEY - 50
		and FinanceManager.requests.size() == 1,
		"%d notes, %d requests" % [GameState.bank_notes, FinanceManager.requests.size()])
	TestFixtures.check(res, "both envoys are away on loan business until they arrive",
		GameState.away_status(team[0]) == GuiTypes.MercStatus.LOAN
		and GameState.away_until(team[0]) == arrival
		and GameState.away_status(team[1]) == GuiTypes.MercStatus.LOAN,
		"%d until %d" % [GameState.away_status(team[0]), GameState.away_until(team[0])])
	TestFixtures.check(res, "an envoy counts as busy and the roster reads the loan status",
		GameState.busy_uids().has(team[0])
		and int(GameState.merc_status(GameState.merc_by_uid(team[0]))["status"])
		== GuiTypes.MercStatus.LOAN,
		"%s" % [GameState.merc_status(GameState.merc_by_uid(team[0]))])
	TestFixtures.check(res, "the roster says what the envoy went to ask for",
		FinanceManager.loan_note(team[0]) == "Requesting 1300 notes from Lender 5."
		and FinanceManager.loan_note(-1) == "", "%s" % FinanceManager.loan_note(team[0]))
	TestFixtures.check(res, "a lender with envoys on the road takes no second request",
		not FinanceManager.request_loan(_request("Lender 5", _uids(3), 25)),
		"a second request went out")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = FinanceManager.FIRST_OFFER_ID * FinanceManager.REQUEST_SEED_MULT + sent
	var want: Dictionary = LoanLogic.resolve({"amount": int(req["amount"]),
		"rate": float(req["rate"]), "term": int(req["term"]),
		"first_due": int(req["first_due"]), "odds": int(req["odds"]), "team": team},
		rng.randf(), rng.randf(), rng.randf())
	_tick_at(arrival)
	var row: Dictionary = FinanceManager.offer(FinanceManager.FIRST_OFFER_ID)
	TestFixtures.check(res, "arriving turns the request into an offer of its own",
		FinanceManager.requests.is_empty() and not row.is_empty()
		and int(row["id"]) == FinanceManager.FIRST_OFFER_ID,
		"%d requests, %s" % [FinanceManager.requests.size(), row])
	TestFixtures.check(res, "the sixty hours on the road expires three seeded offers, not removes them",
		FinanceManager.offers.size() == 5 and not FinanceManager.offer(101).is_empty()
		and not FinanceManager.offer_expired(101)
		and FinanceManager.offer_expired(102) and FinanceManager.offer_expired(104),
		"%d offers" % FinanceManager.offers.size())
	TestFixtures.check(res, "the answer is the one the request rolls out to",
		String(row["outcome"]) == String(want["outcome"])
		and int(row["offer_amount"]) == int(want["offer_amount"])
		and _near(float(row["offer_rate"]), float(want["offer_rate"]))
		and int(row["offer_term"]) == int(want["offer_term"])
		and int(row["offer_first_due"]) == int(want["offer_first_due"]), "%s against %s" % [row,
		want])
	TestFixtures.check(res, "the new offer stands for three days and is announced",
		int(row["expires_minute"]) == arrival + FinanceManager.OFFER_HOURS * HOUR
		and bool(row["unseen"]) and NotificationCenter.rows_of(
		NotificationData.TYPE_LOAN_OFFER, FinanceManager.FIRST_OFFER_ID).size() == 1,
		"expires %d" % int(row["expires_minute"]))
	TestFixtures.check(res, "the envoys are home and free again",
		GameState.away_status(team[0]) == -1 and GameState.away_status(team[1]) == -1
		and not GameState.busy_uids().has(team[0]), "%d away" % GameState.away_status(team[0]))


#Case 14: a request sent with nobody to carry it costs nothing and never beats the ask.
static func _case_no_envoys(res: Dictionary) -> void:
	_fresh()
	var busy_before: Array[int] = _busy_now()
	var req: Dictionary = _request("Lender 7", [] as Array[int], 0)
	var arrival: int = CampaignClock.now() + int(_lender(6)["away_hours"]) * HOUR
	TestFixtures.check(res, "a request with no envoys goes out for nothing",
		FinanceManager.request_loan(req) and GameState.bank_notes == MONEY
		and FinanceManager.requests.size() == 1,
		"%d notes, %d requests" % [GameState.bank_notes, FinanceManager.requests.size()])
	TestFixtures.check(res, "nobody is away and nobody has a note",
		_busy_now() == busy_before and FinanceManager.loan_note(_uids(1)[0]) == "",
		"busy %s was %s" % [str(_busy_now()), str(busy_before)])
	_tick_at(arrival)
	var row: Dictionary = FinanceManager.offer(FinanceManager.FIRST_OFFER_ID)
	TestFixtures.check(res, "the answer comes back and is never better than the ask",
		not row.is_empty() and String(row["outcome"]) != LoanLogic.OUTCOME_BETTER,
		"%s" % [row.get("outcome", "no offer")])
	var exact: bool = String(row["outcome"]) == LoanLogic.OUTCOME_EXACT
	var kept: bool = int(row["offer_amount"]) == int(row["amount"]) \
		and _near(float(row["offer_rate"]), float(row["rate"])) and bool(row["approved"])
	var cut: bool = int(row["offer_amount"]) <= int(row["amount"]) \
		and float(row["offer_rate"]) > float(row["rate"]) and not bool(row["approved"])
	TestFixtures.check(res, "matching the ask keeps its terms and a worse answer costs more",
		kept if exact else cut, "%s" % [row])


#Case 15: an offer nobody answered stays in the list, grayed out and marked expired.
static func _case_expiry(res: Dictionary) -> void:
	_fresh_seeded()
	var start: int = CampaignClock.now()
	_tick_at(start + 9 * HOUR)
	TestFixtures.check(res, "the offer with eight hours on it stays and is marked expired",
		FinanceManager.offers.size() == 4 and not FinanceManager.offer(103).is_empty()
		and FinanceManager.offer_expired(103), "%d offers" % FinanceManager.offers.size())
	TestFixtures.check(res, "an offer that was never announced leaves no notification row",
		NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 103).is_empty(),
		"%d rows" % NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 103).size())
	TestFixtures.check(res, "the longest offer has nine hours less on it and is not expired",
		_near(FinanceManager.hours_left(101), 81.0) and not FinanceManager.offer_expired(101),
		"%f hours" % FinanceManager.hours_left(101))
	_tick_at(start + 31 * HOUR)
	var expired_count: int = 0
	for row: Dictionary in FinanceManager.offers:
		if bool(row.get("expired", false)):
			expired_count += 1
	TestFixtures.check(res, "a jump past two deadlines keeps all four offers with two marked expired",
		FinanceManager.offers.size() == 4 and expired_count == 2
		and FinanceManager.offer_expired(102) and not FinanceManager.offer_expired(104),
		"%d offers, %d expired" % [FinanceManager.offers.size(), expired_count])


#What an expired offer allows once it has been marked, and what Dismiss does to it.
#Offer 103 expires first, so ticking just past it leaves 101, 102 and 104 live. Offers 101, 102 and 104
#are announced by the fixture and 103 is not; the notification-row checks run on 101 after its own deadline.
static func _case_expired_offer(res: Dictionary) -> void:
	_fresh_seeded()
	var row_103: Dictionary = FinanceManager.offer(103)
	_tick_at(int(row_103["expires_minute"]) + 1)
	TestFixtures.check(res, "hours_left never goes negative on an expired offer",
		_near(FinanceManager.hours_left(103), 0.0), "%f hours" % FinanceManager.hours_left(103))
	FinanceManager.mark_offer_seen(101)
	FinanceManager.mark_offer_seen(102)
	FinanceManager.mark_offer_seen(104)
	var forced: Dictionary = FinanceManager.offer(103)
	forced["unseen"] = true
	TestFixtures.check(res, "an expired offer never counts against the Finance dot, even if unseen",
		not FinanceManager.has_offers(), "unread %s" % FinanceManager.has_offers())
	forced["unseen"] = false
	var open_ids: Array[int] = []
	for row: Dictionary in FinanceManager.open_offers():
		open_ids.append(int(row["id"]))
	TestFixtures.check(res, "open_offers leaves the expired offer off the live list",
		not open_ids.has(103) and open_ids.has(101), "%s" % [open_ids])
	var bank_before: int = GameState.bank_notes
	TestFixtures.check(res, "accepting an expired offer is refused and spends nothing",
		not FinanceManager.accept_offer(103) and FinanceManager.loans.size() == 2
		and GameState.bank_notes == bank_before, "%d loans" % FinanceManager.loans.size())
	FinanceManager.reject_offer(103)
	TestFixtures.check(res, "rejecting an expired offer is ignored",
		not FinanceManager.offer(103).is_empty() and FinanceManager.offer_expired(103),
		"still there")
	FinanceManager.dismiss_offer(102)
	TestFixtures.check(res, "dismissing a live offer does nothing",
		not FinanceManager.offer(102).is_empty() and not FinanceManager.offer_expired(102),
		"live offer untouched")
	var ledger_before: int = FinanceLedger.transactions.size()
	FinanceManager.dismiss_offer(103)
	TestFixtures.check(res, "dismissing the expired offer removes it, writing no ledger row",
		FinanceManager.offer(103).is_empty() and FinanceManager.offers.size() == 3
		and GameState.bank_notes == bank_before
		and FinanceLedger.transactions.size() == ledger_before, "%d offers" % FinanceManager.offers.size())
	TestFixtures.check(res, "dismiss of an offer with no notice writes none of its own",
		NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 103).is_empty(),
		"%d rows" % NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 103).size())
	FinanceManager.dismiss_offer(999)
	TestFixtures.check(res, "dismissing an offer nobody has changes nothing",
		FinanceManager.offers.size() == 3, "%d offers" % FinanceManager.offers.size())
	_tick_at(int(FinanceManager.offer(101)["expires_minute"]) + 1)
	var rows: Array[NotificationData] = NotificationCenter.rows_of(
		NotificationData.TYPE_LOAN_OFFER, 101)
	TestFixtures.check(res, "the notification row of an announced offer is resolved at expiry",
		FinanceManager.offer_expired(101) and rows.size() == 1 and rows[0].read,
		"%d rows" % rows.size())
	var ledger_before_2: int = FinanceLedger.transactions.size()
	FinanceManager.dismiss_offer(101)
	TestFixtures.check(res, "dismissing an announced expired offer writes no ledger row",
		FinanceManager.offer(101).is_empty() and GameState.bank_notes == bank_before
		and FinanceLedger.transactions.size() == ledger_before_2, "dismissed")
	TestFixtures.check(res, "dismiss writes no notification of its own",
		NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 101).size() == 1,
		"%d rows" % NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 101).size())


#Case 16: taking an offer.
static func _case_accept(res: Dictionary) -> void:
	_fresh_seeded()
	TestFixtures.check(res, "an offer nobody has cannot be taken",
		not FinanceManager.accept_offer(999) and FinanceManager.loans.size() == 2,
		"%d loans" % FinanceManager.loans.size())
	TestFixtures.check(res, "taking the first offer puts 1500 notes in the bank",
		FinanceManager.accept_offer(101) and GameState.bank_notes == MONEY + 1500,
		"%d notes" % GameState.bank_notes)
	var loan: LoanData = FinanceManager.loan_by_id(NEW_LOAN)
	TestFixtures.check(res, "the offer becomes a third loan on the offered terms",
		FinanceManager.loans.size() == 3 and loan != null and loan.lender == "Lender 1"
		and loan.principal == 1500 and _near(loan.rate, 0.08) and loan.months == 6
		and loan.first_due == 2 and loan.paid == 0, "%s" % [loan.to_row() if loan != null else {}])
	TestFixtures.check(res, "an offer taken on the 3rd of Erta bills on the 2nd",
		loan != null and loan.bill_day == 2
		and loan.bill_day == FinanceManager.bill_day_from(TrynnCalendar.day_index(CampaignClock.now())),
		"bill day %d" % [loan.bill_day if loan != null else -1])
	TestFixtures.check(res, "the third loan raises the monthly bill to 600",
		FinanceManager.monthly_loans() == 600, "%d a month" % FinanceManager.monthly_loans())
	TestFixtures.check(res, "taking one offer turns down every other offer",
		FinanceManager.offers.is_empty() and not FinanceManager.has_offers(),
		"%d offers" % FinanceManager.offers.size())
	var rows: Array[NotificationData] = NotificationCenter.rows_of(
		NotificationData.TYPE_LOAN_OFFER, 101)
	TestFixtures.check(res, "answering the offer closes the row that announced it",
		rows.size() == 1 and rows[0].read, "%d rows, read %s" % [rows.size(),
		rows[0].read if rows.size() > 0 else false])
	TestFixtures.check(res, "the loan starts today and is numbered above the closed ones",
		loan.start_minute == CampaignClock.now() and loan.id == NEW_LOAN
		and loan.id > FinanceManager.closed_loans[1].id,
		"loan %d at %d" % [loan.id, loan.start_minute])


#Case 17: turning an offer down.
static func _case_reject(res: Dictionary) -> void:
	_fresh_seeded()
	FinanceManager.reject_offer(101)
	TestFixtures.check(res, "turning an offer down leaves the other three standing",
		FinanceManager.offers.size() == 3 and FinanceManager.offer(101).is_empty(),
		"%d offers" % FinanceManager.offers.size())
	var rows: Array[NotificationData] = NotificationCenter.rows_of(
		NotificationData.TYPE_LOAN_OFFER, 101)
	TestFixtures.check(res, "the row about the offer turned down is closed",
		rows.size() == 1 and rows[0].read, "%d rows" % rows.size())
	FinanceManager.reject_offer(101)
	FinanceManager.reject_offer(999)
	TestFixtures.check(res, "turning down an offer twice changes nothing",
		FinanceManager.offers.size() == 3 and FinanceManager.loans.size() == 2,
		"%d offers, %d loans" % [FinanceManager.offers.size(), FinanceManager.loans.size()])
	TestFixtures.check(res, "turning an offer down leaves the bank alone",
		GameState.bank_notes == MONEY, "%d notes" % GameState.bank_notes)


#Case 18: each loan pays on its own bill day: loan 1 on the 2nd, loan 2 on the 15th, both from Kusarra on.
static func _case_bill_day(res: Dictionary) -> void:
	_fresh_seeded()
	FinanceManager.tick(CampaignClock.now())
	TestFixtures.check(res, "the first tick of a campaign bills nothing",
		GameState.bank_notes == MONEY and FinanceManager.loans[0].paid == 4,
		"%d notes, %d paid" % [GameState.bank_notes, FinanceManager.loans[0].paid])
	_tick_at(ERTA_15 * DAY)
	TestFixtures.check(res, "the 15th of Erta bills nothing, the first payment falls a month out",
		GameState.bank_notes == MONEY and FinanceManager.loans[1].paid == 1,
		"%d notes, %d paid" % [GameState.bank_notes, FinanceManager.loans[1].paid])
	_tick_at(KUSARRA_2 * DAY)
	TestFixtures.check(res, "the 2nd of Kusarra takes 180 for the loan that bills on the 2nd alone",
		GameState.bank_notes == MONEY - SEED_PAY_1 and FinanceManager.loans[0].paid == 5
		and FinanceManager.loans[1].paid == 1,
		"%d notes, %d and %d paid" % [GameState.bank_notes, FinanceManager.loans[0].paid,
		FinanceManager.loans[1].paid])
	_tick_at(KUSARRA_2 * DAY + 8 * HOUR)
	TestFixtures.check(res, "a second tick on the same day bills nothing again",
		GameState.bank_notes == MONEY - SEED_PAY_1 and FinanceManager.loans[0].paid == 5,
		"%d notes, %d paid" % [GameState.bank_notes, FinanceManager.loans[0].paid])
	_tick_at(KUSARRA_15 * DAY)
	TestFixtures.check(res, "the 15th of Kusarra takes 150 for the loan that bills on the 15th only",
		GameState.bank_notes == MONEY - SEED_BILL and FinanceManager.loans[0].paid == 5
		and FinanceManager.loans[1].paid == 2,
		"%d notes, %d and %d paid" % [GameState.bank_notes, FinanceManager.loans[0].paid,
		FinanceManager.loans[1].paid])
	_fresh_seeded()
	FinanceManager.tick(CampaignClock.now())
	_tick_at(URBAI_15 * DAY)
	TestFixtures.check(res, "a jump to the 15th of Urbai bills two 15ths and two 2nds",
		GameState.bank_notes == MONEY - 2 * SEED_BILL
		and FinanceManager.loans[0].paid == 6 and FinanceManager.loans[1].paid == 3,
		"%d notes, %d and %d" % [GameState.bank_notes, FinanceManager.loans[0].paid,
		FinanceManager.loans[1].paid])


#Case 18b: the bill day a loan keeps is the farther of the 2nd and the 15th, strictly ahead of the day taken.
static func _case_own_bill_day(res: Dictionary) -> void:
	var want: Dictionary = {ERTA_START: 2, ERTA_14: 2, ERTA_15: 15, KUSARRA_1: 15, KUSARRA_2: 2,
		KUSARRA_16: 15}
	var got: Dictionary = {}
	for day: int in want:
		got[day] = FinanceManager.bill_day_from(day)
	TestFixtures.check(res, "the bill day is the farther of the 2nd and the 15th ahead of the day taken",
		got == want, "%s" % [got])
	_fresh()
	_tick_at(KUSARRA_1 * DAY)
	var added: LoanData = TestFixtures.add_loan("Lender 2", 800, 0.12, 6)
	TestFixtures.check(res, "a loan taken on the 1st of Kusarra bills on the 15th",
		added.bill_day == 15, "bill day %d" % added.bill_day)
	_fresh()
	_tick_at(ERTA_13 * DAY)
	var sent: bool = FinanceManager.request_loan(_request("Lender 5", [] as Array[int], 0))
	_tick_at(ERTA_13 * DAY + int(_lender(4)["away_hours"]) * HOUR)
	var taken_day: int = TrynnCalendar.day_index(CampaignClock.now())
	var took: bool = FinanceManager.accept_offer(FinanceManager.FIRST_OFFER_ID)
	var loan: LoanData = FinanceManager.loan_by_id(FinanceManager.FIRST_LOAN_ID)
	TestFixtures.check(res, "an offer taken on the 15th of Erta makes a loan that bills on the 15th",
		sent and took and taken_day == ERTA_15 and loan != null and loan.bill_day == 15,
		"sent %s, took %s on day %d, bill day %d" % [sent, took, taken_day,
		loan.bill_day if loan != null else -1])
	if loan == null:
		return
	var bank: int = GameState.bank_notes
	var pay: int = FinanceManager.loan_payment(loan)
	var due: int = FinanceManager.next_due_minute(loan.id)
	var due_day: int = TrynnCalendar.day_index(due)
	TestFixtures.check(res, "its first payment is due on a 15th",
		int(TrynnCalendar.date_of(due)["day"]) == 15 and due_day > taken_day,
		"due on day %d" % due_day)
	_tick_at((due_day - 13) * DAY)
	TestFixtures.check(res, "the 2nd of the month it is due in bills nothing",
		loan.paid == 0 and GameState.bank_notes == bank, "%d paid, %d notes" % [loan.paid,
		GameState.bank_notes])
	_tick_at(due)
	TestFixtures.check(res, "its own day takes one payment",
		loan.paid == 1 and GameState.bank_notes == bank - pay,
		"%d paid, %d notes" % [loan.paid, GameState.bank_notes])
	var next_2nd: int = TrynnCalendar.next_day_on(due_day, 2)
	_tick_at(next_2nd * DAY)
	TestFixtures.check(res, "the 2nd after it bills nothing",
		loan.paid == 1 and GameState.bank_notes == bank - pay,
		"%d paid, %d notes" % [loan.paid, GameState.bank_notes])
	_tick_at(TrynnCalendar.next_day_on(next_2nd, 15) * DAY)
	TestFixtures.check(res, "the next 15th takes the second payment",
		loan.paid == 2 and GameState.bank_notes == bank - 2 * pay,
		"%d paid, %d notes" % [loan.paid, GameState.bank_notes])


#Case 19: five payments of each loan, two of the months 40 days long, and the loan that runs out.
static func _case_long_month(res: Dictionary) -> void:
	_fresh_seeded()
	FinanceManager.tick(CampaignClock.now())
	_tick_at(TEK_15 * DAY)
	TestFixtures.check(res, "five 15ths and five 2nds passed and five payments were taken for each loan",
		GameState.bank_notes == MONEY - 5 * SEED_BILL, "%d notes" % GameState.bank_notes)
	TestFixtures.check(res, "the loans keep paying after the bank runs dry",
		GameState.bank_notes < 0, "%d notes" % GameState.bank_notes)
	TestFixtures.check(res, "the six month loan is paid off and closed",
		FinanceManager.loans.size() == 1 and FinanceManager.closed_loans.size() == 3
		and FinanceManager.loan_by_id(LOAN_2) == null,
		"%d loans, %d closed" % [FinanceManager.loans.size(),
		FinanceManager.closed_loans.size()])
	var closed: LoanData = FinanceManager.closed_loans[2]
	TestFixtures.check(res, "the closed loan says it was paid in full and what it cost",
		closed.id == LOAN_2 and closed.closed_as == "Paid in Full"
		and closed.paid_total == SEED_PAY_2 * 6 and closed.paid == 6,
		"%s for %d" % [closed.closed_as, closed.paid_total])
	TestFixtures.check(res, "the year long loan has nine of its twelve payments made",
		FinanceManager.loans[0].paid == 9 and FinanceManager.loans[0].months_left() == 3
		and FinanceManager.monthly_loans() == SEED_PAY_1,
		"%d paid, %d a month" % [FinanceManager.loans[0].paid, FinanceManager.monthly_loans()])


#Case 20: a loan with two months of grace pays nothing until its month comes, on the 2nd it keeps.
static func _case_first_due(res: Dictionary) -> void:
	_fresh_seeded()
	FinanceManager.tick(CampaignClock.now())
	FinanceManager.loans.clear()
	FinanceManager.accept_offer(101)
	var loan: LoanData = FinanceManager.loan_by_id(NEW_LOAN)
	var bank: int = GameState.bank_notes
	TestFixtures.check(res, "the new loan is the only one and waits two months",
		FinanceManager.loans.size() == 1 and loan != null and loan.first_due == 2
		and loan.bill_day == 2 and bank == MONEY + 1500,
		"%d loans, %d notes" % [FinanceManager.loans.size(), bank])
	if loan == null:
		return
	_tick_at(ERTA_15 * DAY)
	TestFixtures.check(res, "the month it was taken in asks for nothing",
		loan.paid == 0 and GameState.bank_notes == bank, "%d paid" % loan.paid)
	_tick_at(KUSARRA_15 * DAY)
	TestFixtures.check(res, "the next month asks for nothing either",
		loan.paid == 0 and GameState.bank_notes == bank, "%d paid" % loan.paid)
	_tick_at(URBAI_2 * DAY)
	TestFixtures.check(res, "the 2nd of the third month takes the first payment of 270",
		loan.paid == 1 and GameState.bank_notes == bank - 270,
		"%d paid, %d notes" % [loan.paid, GameState.bank_notes])
	_tick_at(URBAI_15 * DAY)
	TestFixtures.check(res, "the 15th of that month takes nothing",
		loan.paid == 1 and GameState.bank_notes == bank - 270,
		"%d paid, %d notes" % [loan.paid, GameState.bank_notes])
	_tick_at(ORLIN_2 * DAY)
	TestFixtures.check(res, "the months after it keep taking one payment each",
		loan.paid == 3 and GameState.bank_notes == bank - 810,
		"%d paid, %d notes" % [loan.paid, GameState.bank_notes])


#Case 21: clearing a loan early.
static func _case_pay_off(res: Dictionary) -> void:
	_fresh_seeded()
	TestFixtures.check(res, "clearing the first loan costs 1334 notes",
		FinanceManager.payoff_amount(LOAN_1) == 1334 and FinanceManager.payoff_amount(999) == 0,
		"%d notes" % FinanceManager.payoff_amount(LOAN_1))
	TestFixtures.check(res, "a guild that cannot pay the rest keeps the loan",
		not FinanceManager.pay_off(LOAN_1) and FinanceManager.loans.size() == 2
		and GameState.bank_notes == MONEY,
		"%d loans, %d notes" % [FinanceManager.loans.size(), GameState.bank_notes])
	TestFixtures.check(res, "a loan nobody has cannot be cleared",
		not FinanceManager.pay_off(999), "it cleared")
	_set_money(2000)
	TestFixtures.check(res, "paying the rest clears the loan and takes the notes",
		FinanceManager.pay_off(LOAN_1) and GameState.bank_notes == 2000 - 1334
		and FinanceManager.loans.size() == 1 and FinanceManager.loan_by_id(LOAN_1) == null,
		"%d notes, %d loans" % [GameState.bank_notes, FinanceManager.loans.size()])
	var closed: LoanData = FinanceManager.closed_loans[2]
	TestFixtures.check(res, "the closed loan says it was paid off early and what it cost",
		closed.id == LOAN_1 and closed.closed_as == "Paid Off Early"
		and closed.paid_total == SEED_PAY_1 * 4 + 1334 and closed.is_closed(),
		"%s for %d" % [closed.closed_as, closed.paid_total])
	TestFixtures.check(res, "only the other loan is still billed",
		FinanceManager.monthly_loans() == SEED_PAY_2,
		"%d a month" % FinanceManager.monthly_loans())


#Case 22: the payment history of a loan, when the next payment lands and the unread mark.
static func _case_history(res: Dictionary) -> void:
	_fresh_seeded()
	var rows: Array[Dictionary] = FinanceManager.payment_rows(LOAN_1)
	TestFixtures.check(res, "a running loan lists one payment row per month",
		rows.size() == 12, "%d rows" % rows.size())
	TestFixtures.check(res, "the last payment sent says so and what is left after it",
		String(rows[3]["label"]) == "Payment 4 Sent" and int(rows[3]["amount"]) == SEED_PAY_1
		and int(rows[3]["after"]) == 1440 and not bool(rows[3]["future"]),
		"%s leaves %d" % [rows[3]["label"], int(rows[3]["after"])])
	TestFixtures.check(res, "the months still to come are scheduled",
		String(rows[4]["label"]) == "Scheduled Payment 5" and bool(rows[4]["future"])
		and int(rows[4]["after"]) == 1260, "%s" % [rows[4]["label"]])
	TestFixtures.check(res, "a loan nobody has has no payment rows",
		FinanceManager.payment_rows(999).is_empty(), "rows came back")
	var full: Array[Dictionary] = FinanceManager.payment_rows(CLOSED_1)
	TestFixtures.check(res, "a loan paid in full ends on its last payment",
		full.size() == 6 and String(full[5]["label"]) == "Payment 6 Sent"
		and int(full[5]["after"]) == 0 and not bool(full[5]["future"]),
		"%d rows ending %s" % [full.size(), full[5]["label"]])
	var early: Array[Dictionary] = FinanceManager.payment_rows(CLOSED_2)
	TestFixtures.check(res, "a loan cleared early ends on the payoff it took",
		early.size() == 8 and String(early[7]["label"]) == "Payoff Sent"
		and int(early[7]["amount"]) == 507 and int(early[7]["after"]) == 0,
		"%d rows ending %s for %d" % [early.size(), early[7]["label"], int(early[7]["amount"])])
	TestFixtures.check(res, "the next payment of a running loan is still ahead",
		FinanceManager.next_due_minute(LOAN_1) > CampaignClock.now()
		and FinanceManager.next_due_text(LOAN_1).begins_with("in "),
		FinanceManager.next_due_text(LOAN_1))
	TestFixtures.check(res, "a loan that ended has no next payment",
		FinanceManager.next_due_minute(CLOSED_1) == -1 and FinanceManager.next_due_text(CLOSED_1) == ""
		and FinanceManager.next_due_text(999) == "", FinanceManager.next_due_text(CLOSED_1))
	TestFixtures.check(res, "an offer nobody has is never unread",
		not FinanceManager.offer_unread(999), "it read unread")
	TestFixtures.check(res, "an offer with an unread notice reads unread",
		FinanceManager.offer_unread(101) and FinanceManager.offer_unread(103), "both unread")
	FinanceManager.mark_offer_seen(103)
	TestFixtures.check(res, "marking an offer seen clears its own unread mark",
		not FinanceManager.offer_unread(103), "still unread")
	FinanceManager.mark_offer_seen(101)
	TestFixtures.check(res, "an unread notice keeps the offer unread anyway",
		FinanceManager.offer_unread(101), "the notice was ignored")
	FinanceManager.mark_offer_seen(999)
	TestFixtures.check(res, "marking an offer nobody has changes nothing",
		FinanceManager.offers.size() == 4, "%d offers" % FinanceManager.offers.size())


#Case 23: a new game opens no offers, so nothing escalates, and an offer the envoys bring back alerts on arrival.
static func _case_seed_alerts(res: Dictionary) -> void:
	_fresh()
	FinanceManager._register_rule()
	var alerts: Array[int] = []
	var on_alert: Callable = func(alerted_row: NotificationData) -> void: alerts.append(alerted_row.trigger_id)
	NotificationCenter.alerted.connect(on_alert)
	NotificationCenter.escalate(CampaignClock.now())
	TestFixtures.check(res, "a new game has no offer to escalate and raises no offer row",
		FinanceManager.offers.is_empty() and alerts.is_empty()
		and NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER, FinanceManager.FIRST_OFFER_ID) == null,
		"%d offers, alerted %s" % [FinanceManager.offers.size(), alerts])
	var team: Array[int] = _uids(2)
	var arrival: int = CampaignClock.now() + int(_lender(4)["away_hours"]) * HOUR
	var sent: bool = FinanceManager.request_loan(_request("Lender 5", team, 25))
	_tick_at(arrival)
	var landed: NotificationData = NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER,
		FinanceManager.FIRST_OFFER_ID)
	TestFixtures.check(res, "an offer the envoys bring back alerts on arrival",
		sent and landed != null and landed.alerted and alerts.has(FinanceManager.FIRST_OFFER_ID),
		"sent %s, alerted %s" % [sent, alerts])
	NotificationCenter.alerted.disconnect(on_alert)


#Case 24: an offer that expires leaves the escalation pass, so its read urgent row never re-fires or alerts.
static func _case_expired_escalation(res: Dictionary) -> void:
	_fresh_seeded()
	FinanceManager._register_rule()
	var expiry: int = int(FinanceManager.offer(101)["expires_minute"])
	_tick_at(expiry - 12 * HOUR)
	NotificationCenter.escalate(CampaignClock.now())
	var urgent: NotificationData = NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER, 101)
	_tick_at(expiry + 1)
	var alerts: Array[int] = []
	var on_alert: Callable = func(alerted_row: NotificationData) -> void: alerts.append(alerted_row.trigger_id)
	NotificationCenter.alerted.connect(on_alert)
	NotificationCenter.escalate(CampaignClock.now())
	var rows: Array[NotificationData] = NotificationCenter.rows_of(
		NotificationData.TYPE_LOAN_OFFER, 101)
	TestFixtures.check(res, "at its deadline an expired offer keeps one read urgent row and alerts nothing",
		urgent != null and urgent.urgency == NotificationData.Urgency.URGENT and alerts.is_empty()
		and rows.size() == 1 and rows[0] == urgent and urgent.read,
		"alerts %s, %d rows" % [alerts, rows.size()])
	_tick_at(CampaignClock.now() + NotificationCenter.REFIRE_MINUTES)
	NotificationCenter.escalate(CampaignClock.now())
	rows = NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, 101)
	TestFixtures.check(res, "eight hours on the expired offer is still listed and its read row never re-fires",
		alerts.is_empty() and rows.size() == 1 and rows[0] == urgent and urgent.read
		and FinanceManager.offers.size() == 4 and FinanceManager.offer_expired(101),
		"alerts %s, %d rows, %d offers" % [alerts, rows.size(), FinanceManager.offers.size()])
	NotificationCenter.alerted.disconnect(on_alert)


#Case 25: an offer notice goes urgent inside its last 24 hours, where other notices use 72, and that raise alerts.
static func _case_offer_urgency(res: Dictionary) -> void:
	_fresh()
	FinanceManager._register_rule()
	var team: Array[int] = _uids(2)
	var arrival: int = CampaignClock.now() + int(_lender(4)["away_hours"]) * HOUR
	var sent: bool = FinanceManager.request_loan(_request("Lender 5", team, 25))
	_tick_at(arrival)
	var id: int = FinanceManager.FIRST_OFFER_ID
	var landed: NotificationData = NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER, id)
	var expiry: int = int(FinanceManager.offer(id).get("expires_minute", arrival))
	var alerts: Array[int] = []
	var on_alert: Callable = func(alerted_row: NotificationData) -> void:
		if alerted_row.type == NotificationData.TYPE_LOAN_OFFER:
			alerts.append(alerted_row.trigger_id)
	NotificationCenter.alerted.connect(on_alert)
	_tick_at(expiry - 30 * HOUR)
	NotificationCenter.escalate(CampaignClock.now())
	TestFixtures.check(res, "an offer with 30 hours left stays informational and alerts nothing",
		sent and landed != null and landed.urgency == NotificationData.Urgency.INFORMATIONAL
		and NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER, id) == landed and alerts.is_empty(),
		"sent %s, %.1f hours left, alerted %s" % [sent, FinanceManager.hours_left(id), alerts])
	_tick_at(expiry - 23 * HOUR)
	NotificationCenter.escalate(CampaignClock.now())
	var rows: Array[NotificationData] = NotificationCenter.rows_of(NotificationData.TYPE_LOAN_OFFER, id)
	TestFixtures.check(res, "at 23 hours left the offer goes urgent in one row with one alert",
		rows.size() == 1 and rows[0].urgency == NotificationData.Urgency.URGENT
		and alerts.size() == 1 and alerts[0] == id, "%d rows, alerted %s" % [rows.size(), alerts])
	NotificationCenter.alerted.disconnect(on_alert)


#Case 26: a notice rule that sets no urgent_hours keeps the 72 hour default.
static func _case_default_urgency(res: Dictionary) -> void:
	_fresh()
	var probe: StringName = &"loanTestProbe"
	var table: Dictionary = {1: 72.0, 2: 50.0}
	var open_fn: Callable = func() -> Array: return table.keys()
	var hours_fn: Callable = func(trigger: int) -> float: return float(table.get(trigger, 100.0))
	var alerts: Array[int] = []
	var on_alert: Callable = func(alerted_row: NotificationData) -> void:
		if alerted_row.type == probe:
			alerts.append(alerted_row.trigger_id)
	NotificationCenter.alerted.connect(on_alert)
	NotificationCenter.add_rule(probe, {"open": open_fn, "hours_left": hours_fn,
		"kind": FinanceManager.KIND_FINANCE})
	NotificationCenter.escalate(CampaignClock.now())
	var far: NotificationData = NotificationCenter.latest(probe, 1)
	var near: NotificationData = NotificationCenter.latest(probe, 2)
	TestFixtures.check(res, "a rule without urgent_hours raises at 50 hours left and leaves 72 hours alone",
		far == null and near != null and near.urgency == NotificationData.Urgency.URGENT
		and alerts.size() == 1 and alerts[0] == 2,
		"far %s, near %s, alerted %s" % [far != null, near != null, alerts])
	NotificationCenter.alerted.disconnect(on_alert)
	NotificationCenter.remove_rule(probe)


#Case 27: every offer goes urgent inside its last day with an alert, and a read urgent row re-fires with another.
static func _case_seeded_raises(res: Dictionary) -> void:
	_fresh_seeded()
	FinanceManager._register_rule()
	var lead: int = (int(FinanceManager.OFFER_URGENT_HOURS) - 1) * HOUR
	var raise_at: Array[int] = []
	for offer_row: Dictionary in FinanceManager.offers:
		raise_at.append(maxi(CampaignClock.now(), int(offer_row["expires_minute"]) - lead))
	raise_at.sort()
	var alerts: Array[int] = []
	var on_alert: Callable = func(alerted_row: NotificationData) -> void:
		if alerted_row.type == NotificationData.TYPE_LOAN_OFFER:
			alerts.append(alerted_row.trigger_id)
	NotificationCenter.alerted.connect(on_alert)
	for minute: int in raise_at:
		_tick_at(minute)
		NotificationCenter.escalate(CampaignClock.now())
	var raised: Array[int] = []
	for id: int in [101, 102, 103, 104]:
		var row: NotificationData = NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER, id)
		if row != null and row.alerted and row.urgency == NotificationData.Urgency.URGENT:
			raised.append(id)
	var sorted_alerts: Array[int] = alerts.duplicate()
	sorted_alerts.sort()
	var all_four: Array[int] = [101, 102, 103, 104]
	TestFixtures.check(res, "each fixture offer goes urgent inside its last day with one alert",
		raised.size() == 4 and sorted_alerts == all_four,
		"raised %s, alerted %s" % [raised, alerts])
	var urgent: NotificationData = NotificationCenter.latest(NotificationData.TYPE_LOAN_OFFER, 101)
	if urgent != null:
		NotificationCenter.mark_read(urgent.id)
	_tick_at(CampaignClock.now() + NotificationCenter.REFIRE_MINUTES)
	NotificationCenter.escalate(CampaignClock.now())
	TestFixtures.check(res, "a read urgent offer row re-fires with an alert of its own",
		alerts.size() == 5 and alerts[4] == 101, "alerted %s" % [alerts])
	NotificationCenter.alerted.disconnect(on_alert)
