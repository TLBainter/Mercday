extends Node

#Finance: the lenders the guild can ask, the loan requests envoys are carrying, the offers waiting
#for an answer and the loans the guild is paying off. The formulas live in LoanLogic.gd.
#The screens come later; this is the data layer they read.

signal offers_changed
signal loans_changed
signal requests_changed

#PLACEHOLDER: every lender, loan, offer and budget figure below is prototype data.
const LENDER_ROWS: Array[Dictionary] = [
	{"name": "Lender 1", "rel": 4, "base": 0.08, "cap": 3000, "away_hours": 124},
	{"name": "Lender 2", "rel": 2, "base": 0.1, "cap": 1500, "away_hours": 76},
	{"name": "Lender 3", "rel": -1, "base": 0.18, "cap": 6000, "away_hours": 170},
	{"name": "Lender 4", "rel": 3, "base": 0.07, "cap": 2500, "away_hours": 98},
	{"name": "Lender 5", "rel": 0, "base": 0.12, "cap": 2000, "away_hours": 60},
	{"name": "Lender 6", "rel": -3, "base": 0.22, "cap": 5000, "away_hours": 150},
	{"name": "Lender 7", "rel": 1, "base": 0.11, "cap": 1800, "away_hours": 88},
	{"name": "Lender 8", "rel": 5, "base": 0.06, "cap": 4000, "away_hours": 110},
]
const SEED_LOANS: Array[Dictionary] = [
	{"id": 1, "lender": "Lender 1", "principal": 2000, "rate": 0.08, "months": 12, "paid": 4},
	{"id": 2, "lender": "Lender 2", "principal": 800, "rate": 0.12, "months": 6, "paid": 1},
]
const SEED_CLOSED: Array[Dictionary] = [
	{"id": 201, "lender": "Lender 2", "principal": 600, "rate": 0.12, "months": 6, "paid": 6,
		"closed_as": "Paid in Full", "paid_total": 672},
	{"id": 202, "lender": "Lender 1", "principal": 1200, "rate": 0.08, "months": 12, "paid": 7,
		"closed_as": "Paid Off Early", "paid_total": 1263},
]
const SEED_OFFERS: Array[Dictionary] = [
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
#The day of every month a loan payment lands on, and how long an offer stands.
const BILL_DAY: int = 15
const OFFER_HOURS: int = 72
#Days after the last payment a payoff row is stamped with.
const PAYOFF_TAIL_DAYS: int = 6
const MONTHS_PER_YEAR: int = 10
const KIND_FINANCE: String = "Finance"
const REQUEST_SEED_MULT: int = 7919
#Ids of the seeded rows are the prototype ones, so new rows start above them.
const FIRST_OFFER_ID: int = 105
const FIRST_LOAN_ID: int = 203
const EVENT_GUARD: int = 256

var offers: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var loans: Array[LoanData] = []
var closed_loans: Array[LoanData] = []

var _seeded: bool = false
var _next_id: int = FIRST_OFFER_ID
var _next_loan_id: int = FIRST_LOAN_ID
#The last calendar day the day rule handled; -1 until the first tick after a reset.
var _last_day: int = -1


func _ready() -> void:
	GameState.roster_changed.connect(_on_roster_changed)
	_register_rule()
	reset()


func reset() -> void:
	offers.clear()
	requests.clear()
	loans.clear()
	closed_loans.clear()
	_next_id = FIRST_OFFER_ID
	_next_loan_id = FIRST_LOAN_ID
	_last_day = -1
	var now: int = CampaignClock.now()
	for row: Dictionary in SEED_LOANS:
		loans.append(_loan_from(row, now))
	for row: Dictionary in SEED_CLOSED:
		closed_loans.append(_loan_from(row, now))
	for row: Dictionary in SEED_OFFERS:
		offers.append(_offer_from(row, now))
	_seeded = GameState.started
	for row: Dictionary in offers:
		if hours_left(int(row["id"])) >= float(OFFER_HOURS):
			_push_offer(int(row["id"]))
	offers_changed.emit()
	loans_changed.emit()
	requests_changed.emit()


func _loan_from(row: Dictionary, now: int) -> LoanData:
	var loan: LoanData = LoanData.new()
	loan.id = int(row["id"])
	loan.lender = String(row["lender"])
	loan.principal = int(row["principal"])
	loan.rate = float(row["rate"])
	loan.months = int(row["months"])
	loan.paid = int(row.get("paid", 0))
	loan.first_due = int(row.get("first_due", 0))
	loan.start_minute = now
	loan.closed_as = String(row.get("closed_as", ""))
	loan.paid_total = int(row.get("paid_total", 0))
	return loan


func _offer_from(row: Dictionary, now: int) -> Dictionary:
	var out: Dictionary = row.duplicate(true)
	out.erase("hours")
	out["expires_minute"] = now + int(row.get("hours", OFFER_HOURS)) * CampaignClock.MINUTES_PER_HOUR
	out["unseen"] = true
	out["rate_pct"] = roundi(float(row["offer_rate"]) * 100.0)
	out["months"] = int(row["offer_term"])
	return out


func _on_roster_changed() -> void:
	if _seeded or not GameState.started:
		return
	reset()


#An unread offer; the Finance tab dot reads this. An expired offer never counts, unseen or not.
func has_offers() -> bool:
	for row: Dictionary in offers:
		if bool(row.get("expired", false)):
			continue
		if bool(row.get("unseen", false)):
			return true
	return false


func mark_offers_seen() -> void:
	for row: Dictionary in offers:
		row["unseen"] = false
	offers_changed.emit()


func offer(id: int) -> Dictionary:
	for row: Dictionary in offers:
		if int(row.get("id", -1)) == id:
			return row
	return {}


#True once an offer has passed its deadline and stayed as a grayed-out row.
func offer_expired(id: int) -> bool:
	return bool(offer(id).get("expired", false))


#The month at a glance. The subscription line reads SubscriptionManager when it can price itself.
#Income is the ledger income of the last RATE_DAYS days; other_expenses is payroll, guild,
#travel and ads, since the Loan Request window adds the subscription and the loan instalments
#itself.
func budget() -> Dictionary:
	var subscription: int = 0
	if SubscriptionManager.has_method("monthly_cost"):
		subscription = int(SubscriptionManager.call("monthly_cost"))
	var income: int = FinanceLedger.income_in(FinanceLedger.RATE_DAYS)
	var other_expenses: int = FinanceLedger.monthly_expenses() - FinanceLedger.loans_and_services()
	return {"income": income, "other_expenses": other_expenses, "subscription": subscription}


func net() -> int:
	var rows: Dictionary = budget()
	return int(rows["income"]) - int(rows["other_expenses"]) - int(rows["subscription"])


func lenders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in LENDER_ROWS:
		out.append(row.duplicate(true))
	return out


func lender_row(lender: String) -> Dictionary:
	for row: Dictionary in LENDER_ROWS:
		if String(row["name"]) == lender:
			return row.duplicate(true)
	return {}


#A lender is busy while it holds an open offer or an envoy is still on the road to it.
func lender_busy(lender: String) -> bool:
	for row: Dictionary in offers:
		if String(row.get("lender", "")) == lender:
			return true
	for row: Dictionary in requests:
		if String(row.get("lender", "")) == lender:
			return true
	return false


#Where the request sliders start for one lender.
func fair_draft(lender: String) -> Dictionary:
	var row: Dictionary = lender_row(lender)
	if row.is_empty():
		return {}
	return LoanLogic.fair_draft(row, GameState.bank_notes)


#What one draft of a request works out to, with the envoys who would carry it.
func request_calc(lender: String, draft: Dictionary, team: Array[int]) -> Dictionary:
	var row: Dictionary = lender_row(lender)
	if row.is_empty():
		return {}
	return LoanLogic.request(row, draft, GameState.bank_notes, _team_fit(team))


#The loan match of one merc as stars, 0.5 to 5.0.
func merc_fit(uid: int) -> float:
	return LoanLogic.fit_stars(_merc_fit_raw(uid))


func _merc_fit_raw(uid: int) -> float:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return 0.0
	var tradition: String = merc.tradition.tradition_name if merc.tradition != null else ""
	return LoanLogic.loan_fit(tradition, int(merc.stats.get("wile", 0)),
		int(merc.stats.get("vigor", 0)))


func _team_fit(team: Array[int]) -> float:
	var total: float = 0.0
	for uid: int in team:
		total += _merc_fit_raw(uid)
	return total


#Sends the envoys out with a request. The lender must be free, every envoy must be at the guild
#and the guild must hold the fee for all of them.
func request_loan(req: Dictionary) -> bool:
	var lender: String = String(req.get("lender", ""))
	var row: Dictionary = lender_row(lender)
	if row.is_empty() or lender_busy(lender):
		return false
	var team: Array = req.get("team", []) as Array
	for raw: Variant in team:
		if not _can_leave(int(raw)):
			return false
	var per: int = int(req.get("per", 0))
	var fee: int = per * team.size()
	if fee > GameState.bank_notes:
		return false
	if fee > 0:
		GameState.spend(fee, GameState.REASON_ODD_JOB, "Odd Job - Loan Request (%s)" % lender)
	var now: int = CampaignClock.now()
	var arrival: int = now + int(row["away_hours"]) * CampaignClock.MINUTES_PER_HOUR
	var uids: Array[int] = []
	for raw: Variant in team:
		uids.append(int(raw))
	for uid: int in uids:
		GameState.set_away(uid, GuiTypes.MercStatus.LOAN, arrival)
	requests.append({"id": _take_id(), "lender": lender, "amount": int(req.get("amount", 0)),
		"rate": float(req.get("rate", 0.0)), "term": int(req.get("term", 0)),
		"first_due": int(req.get("first_due", LoanLogic.FIRST_DUE_FAIR)), "team": uids,
		"odds": int(req.get("odds", 0)), "per": per, "sent_minute": now,
		"arrival_minute": arrival})
	requests_changed.emit()
	return true


#An envoy has to be at the guild: resting is allowed, everything else is not.
func _can_leave(uid: int) -> bool:
	var merc: MercenaryData = GameState.merc_by_uid(uid)
	if merc == null:
		return false
	var status: int = int(GameState.merc_status(merc)["status"])
	return status == GuiTypes.MercStatus.AVAILABLE or status == GuiTypes.MercStatus.RESTING


func _take_id() -> int:
	var id: int = _next_id
	_next_id += 1
	return id


#The clock moved: first every minute event in the order it happened, then every calendar day.
func tick(now: int) -> void:
	_minute_events(now)
	_run_days(now)


#An arriving request becomes an offer and an offer past its hour is gone. A jump of days can hold
#several of both, so they are handled one at a time, earliest first.
func _minute_events(now: int) -> void:
	var guard: int = 0
	while guard < EVENT_GUARD:
		guard += 1
		var when: int = -1
		var request_id: int = -1
		var offer_id: int = -1
		for row: Dictionary in requests:
			var at: int = int(row["arrival_minute"])
			if at <= now and (when < 0 or at < when):
				when = at
				request_id = int(row["id"])
				offer_id = -1
		for row: Dictionary in offers:
			if bool(row.get("expired", false)):
				continue
			var at: int = int(row["expires_minute"])
			if at <= now and (when < 0 or at < when):
				when = at
				offer_id = int(row["id"])
				request_id = -1
		if when < 0:
			return
		if request_id >= 0:
			_land_request(request_id, when)
		else:
			_expire_offer(offer_id)


#The envoys are back with the lender's answer. The three rolls come from one generator seeded by
#the request, so the same request always ends the same way.
func _land_request(id: int, arrival: int) -> void:
	var index: int = -1
	for i: int in range(requests.size()):
		if int(requests[i]["id"]) == id:
			index = i
			break
	if index < 0:
		return
	var req: Dictionary = requests[index]
	requests.remove_at(index)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = id * REQUEST_SEED_MULT + int(req["sent_minute"])
	var result: Dictionary = LoanLogic.resolve(req, rng.randf(), rng.randf(), rng.randf())
	var row: Dictionary = {"id": id, "lender": String(req["lender"]), "amount": int(req["amount"]),
		"rate": float(req["rate"]), "term": int(req["term"]), "first_due": int(req["first_due"]),
		"team": req["team"], "odds": int(req["odds"]), "outcome": String(result["outcome"]),
		"approved": bool(result["approved"]), "offer_amount": int(result["offer_amount"]),
		"offer_rate": float(result["offer_rate"]), "offer_term": int(result["offer_term"]),
		"offer_first_due": int(result["offer_first_due"]), "unseen": true,
		"expires_minute": arrival + OFFER_HOURS * CampaignClock.MINUTES_PER_HOUR}
	row["rate_pct"] = roundi(float(row["offer_rate"]) * 100.0)
	row["months"] = int(row["offer_term"])
	offers.append(row)
	for raw: Variant in req["team"] as Array:
		GameState.clear_away(int(raw))
	_push_offer(id)
	requests_changed.emit()
	offers_changed.emit()


func _resolve_offer_notice(id: int) -> void:
	var center: Node = get_node_or_null("/root/NotificationCenter")
	if center != null and center.has_method("resolve"):
		center.call("resolve", NotificationData.TYPE_LOAN_OFFER, id)


#An offer nobody answered stays, grayed out and marked expired, until Dismiss removes it.
func _expire_offer(id: int) -> void:
	var row: Dictionary = offer(id)
	if row.is_empty() or bool(row.get("expired", false)):
		return
	row["expired"] = true
	row["unseen"] = false
	_resolve_offer_notice(id)
	offers_changed.emit()


func _drop_offer(id: int) -> bool:
	for i: int in range(offers.size()):
		if int(offers[i]["id"]) != id:
			continue
		offers.remove_at(i)
		_resolve_offer_notice(id)
		return true
	return false


#Removes an expired offer with no ledger row and no notification of its own; a live offer stays.
func dismiss_offer(id: int) -> void:
	if not offer_expired(id):
		return
	if _drop_offer(id):
		offers_changed.emit()


#Every calendar day passed since the last tick, in order. The first tick after a reset only
#records the day it is on.
func _run_days(now: int) -> void:
	var today: int = TrynnCalendar.day_index(now)
	if _last_day < 0:
		_last_day = today
		return
	while _last_day < today:
		_last_day += 1
		_day_passed(_last_day)


func _day_passed(day: int) -> void:
	var date: Dictionary = TrynnCalendar.date_of(day * CampaignClock.MINUTES_PER_DAY)
	if int(date["day"]) != BILL_DAY:
		return
	_bill_loans(int(date["year"]) * MONTHS_PER_YEAR + int(date["month"]))


#The 15th: every loan whose first payment month has come pays one month. The last payment closes
#the loan.
func _bill_loans(month_index: int) -> void:
	var billed: bool = false
	for loan: LoanData in loans.duplicate():
		if loan.is_closed() or month_index < _first_month(loan):
			continue
		var due: int = loan_payment(loan)
		GameState.charge(due, GameState.REASON_LOAN_PAYMENT, "%s - Payment" % loan.lender)
		loan.paid += 1
		billed = true
		if loan.paid >= loan.months:
			_close_loan(loan, "Paid in Full", due * loan.months)
	if billed:
		loans_changed.emit()


#The month index a loan's first payment lands in: the month it was taken plus its first due delay.
func _first_month(loan: LoanData) -> int:
	var date: Dictionary = TrynnCalendar.date_of(loan.start_minute)
	return int(date["year"]) * MONTHS_PER_YEAR + int(date["month"]) + loan.first_due


func _close_loan(loan: LoanData, reason: String, total: int) -> void:
	loan.closed_as = reason
	loan.paid_total = total
	loan.closed_minute = CampaignClock.now()
	loans.erase(loan)
	closed_loans.append(loan)


#Takes the offer: the notes land in the bank, the loan starts and every other offer is turned down.
func accept_offer(id: int) -> bool:
	var row: Dictionary = offer(id)
	if row.is_empty() or bool(row.get("expired", false)):
		return false
	var loan: LoanData = LoanData.new()
	loan.id = _next_loan_id
	_next_loan_id += 1
	loan.lender = String(row["lender"])
	loan.principal = int(row["offer_amount"])
	loan.rate = float(row["offer_rate"])
	loan.months = int(row["offer_term"])
	loan.first_due = int(row["offer_first_due"])
	loan.start_minute = CampaignClock.now()
	loans.append(loan)
	GameState.refund(loan.principal, GameState.REASON_LOAN, "%s - Loan" % loan.lender)
	var open_ids: Array[int] = []
	for other: Dictionary in offers:
		open_ids.append(int(other["id"]))
	for other_id: int in open_ids:
		_drop_offer(other_id)
	offers_changed.emit()
	loans_changed.emit()
	return true


func reject_offer(id: int) -> void:
	if bool(offer(id).get("expired", false)):
		return
	if _drop_offer(id):
		offers_changed.emit()


func loan_payment(loan: LoanData) -> int:
	if loan == null:
		return 0
	return LoanLogic.payment(loan.principal, loan.rate, loan.months)


func loan_by_id(loan_id: int) -> LoanData:
	for loan: LoanData in loans:
		if loan.id == loan_id:
			return loan
	return null


#What it costs to clear one loan today.
func payoff_amount(loan_id: int) -> int:
	var loan: LoanData = loan_by_id(loan_id)
	if loan == null:
		return 0
	return LoanLogic.payoff(loan.principal, loan.months, loan.paid)


#Clears a loan early; a guild that cannot pay the whole rest keeps the loan.
func pay_off(loan_id: int) -> bool:
	var loan: LoanData = loan_by_id(loan_id)
	if loan == null:
		return false
	var amount: int = payoff_amount(loan_id)
	if not GameState.spend(amount, GameState.REASON_LOAN_PAYOFF, "%s - Payoff" % loan.lender):
		return false
	_close_loan(loan, "Paid Off Early", loan_payment(loan) * loan.paid + amount)
	loans_changed.emit()
	return true


func monthly_loans() -> int:
	var total: int = 0
	for loan: LoanData in loans:
		total += loan_payment(loan)
	return total


#How long an offer still stands, in hours; 0.0 once it is gone.
func hours_left(offer_id: int) -> float:
	var row: Dictionary = offer(offer_id)
	if row.is_empty() or bool(row.get("expired", false)):
		return 0.0
	return float(int(row["expires_minute"]) - CampaignClock.now()) \
		/ float(CampaignClock.MINUTES_PER_HOUR)


#What the roster says under an envoy's name.
func loan_note(uid: int) -> String:
	for row: Dictionary in requests:
		if (row["team"] as Array).has(uid):
			return "Requesting %d notes from %s." % [int(row["amount"]), String(row["lender"])]
	return ""


func _open_offer_ids() -> Array:
	var out: Array = []
	for row: Dictionary in offers:
		out.append(int(row["id"]))
	return out


#What a notification row about one offer prints.
func offer_snap(id: int) -> Dictionary:
	var row: Dictionary = offer(id)
	if row.is_empty():
		return {}
	return {"lender": String(row["lender"]), "amount": int(row["amount"]),
		"rate": float(row["rate"]), "term": int(row["term"]), "first_due": int(row["first_due"]),
		"offer_amount": int(row["offer_amount"]), "offer_rate": float(row["offer_rate"]),
		"offer_term": int(row["offer_term"]), "offer_first_due": int(row["offer_first_due"]),
		"outcome": String(row["outcome"]), "expires_in": hours_left(id),
		"odds": int(row["odds"]), "team": row["team"], "approved": bool(row["approved"])}


func _push_offer(id: int) -> void:
	var center: Node = get_node_or_null("/root/NotificationCenter")
	if center == null or not center.has_method("push"):
		return
	center.call("push", NotificationData.TYPE_LOAN_OFFER, id, offer_snap(id),
		NotificationData.Urgency.INFORMATIONAL, KIND_FINANCE)


func _register_rule() -> void:
	var center: Node = get_node_or_null("/root/NotificationCenter")
	if center == null or not center.has_method("add_rule"):
		return
	center.call("add_rule", NotificationData.TYPE_LOAN_OFFER, {"open": _open_offer_ids,
		"hours_left": hours_left, "make": offer_snap, "kind": KIND_FINANCE})


#Every payment of one loan, active or closed, for the payment cells of the Loans page.
func payment_rows(loan_id: int) -> Array[Dictionary]:
	var loan: LoanData = loan_by_id(loan_id)
	if loan == null:
		loan = closed_by_id(loan_id)
	if loan == null:
		return []
	if loan.is_closed():
		return _closed_rows(loan)
	return _active_rows(loan)


func closed_by_id(loan_id: int) -> LoanData:
	for loan: LoanData in closed_loans:
		if loan.id == loan_id:
			return loan
	return null


func _active_rows(loan: LoanData) -> Array[Dictionary]:
	var pay: int = loan_payment(loan)
	var total: int = pay * loan.months
	var first: int = _first_month(loan)
	var out: Array[Dictionary] = []
	for k: int in loan.months:
		var future: bool = k >= loan.paid
		var label: String = "Scheduled Payment %d" % (k + 1)
		if not future:
			label = "Payment %d Sent" % (k + 1)
		out.append(_payment_row(label, _bill_minute(first + k), pay,
			maxi(0, total - pay * (k + 1)), future))
	return out


func _closed_rows(loan: LoanData) -> Array[Dictionary]:
	var pay: int = loan_payment(loan)
	var total: int = pay * loan.months
	var end_minute: int = loan.closed_minute if loan.closed_minute > 0 else CampaignClock.now()
	var end_month: int = _month_index(end_minute)
	var out: Array[Dictionary] = []
	var last: int = end_minute
	for k: int in loan.paid:
		last = _bill_minute(end_month - (loan.paid - 1 - k))
		out.append(_payment_row("Payment %d Sent" % (k + 1), last, pay,
			maxi(0, total - pay * (k + 1)), false))
	if loan.paid < loan.months:
		var minute: int = end_minute
		if loan.paid > 0:
			minute = last + PAYOFF_TAIL_DAYS * CampaignClock.MINUTES_PER_DAY
		out.append(_payment_row("Payoff Sent", minute,
			maxi(0, loan.paid_total - pay * loan.paid), 0, false))
	return out


func _payment_row(label: String, minute: int, amount: int, after: int,
		future: bool) -> Dictionary:
	return {"label": label, "minute": minute,
		"date": GuiDates.day_text(TrynnCalendar.day_index(minute)), "amount": amount,
		"after": after, "future": future}


#The minute a payment of that absolute month index lands on: the 15th, at midnight.
func _bill_minute(month_index: int) -> int:
	var year: int = floori(float(month_index) / float(MONTHS_PER_YEAR))
	var month: int = month_index - year * MONTHS_PER_YEAR
	return TrynnCalendar.month_start_minute(year, month) \
		+ (BILL_DAY - 1) * CampaignClock.MINUTES_PER_DAY


func _month_index(minute: int) -> int:
	var date: Dictionary = TrynnCalendar.date_of(minute)
	return int(date["year"]) * MONTHS_PER_YEAR + int(date["month"])


#When the next payment of a running loan lands; -1 when the loan has none left.
func next_due_minute(loan_id: int) -> int:
	var loan: LoanData = loan_by_id(loan_id)
	if loan == null or loan.is_closed() or loan.paid >= loan.months:
		return -1
	return _bill_minute(_first_month(loan) + loan.paid)


func next_due_text(loan_id: int) -> String:
	var minute: int = next_due_minute(loan_id)
	if minute < 0:
		return ""
	var days: int = TrynnCalendar.day_index(minute) - TrynnCalendar.day_index(CampaignClock.now())
	if days <= 0:
		return "today"
	return "in %s" % GuiDates.days_text(days)


func mark_offer_seen(id: int) -> void:
	var row: Dictionary = offer(id)
	if row.is_empty() or not bool(row.get("unseen", false)):
		return
	row["unseen"] = false
	offers_changed.emit()


#An offer still waiting for an answer: the notification row decides, the offer key is the fallback.
func offer_unread(id: int) -> bool:
	var row: Dictionary = offer(id)
	if row.is_empty():
		return false
	var center: Node = get_node_or_null("/root/NotificationCenter")
	if center != null and center.has_method("rows_of"):
		var rows: Array = center.call("rows_of", NotificationData.TYPE_LOAN_OFFER, id) as Array
		if not rows.is_empty():
			for item: Variant in rows:
				var data: NotificationData = item as NotificationData
				if data != null and not data.read:
					return true
			return false
	return bool(row.get("unseen", false))


#Every offer still standing, oldest first.
func open_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in offers:
		if bool(row.get("expired", false)):
			continue
		if hours_left(int(row["id"])) > 0.0:
			out.append(row)
	out.sort_custom(_by_offer_id)
	return out


func _by_offer_id(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("id", 0)) < int(b.get("id", 0))
