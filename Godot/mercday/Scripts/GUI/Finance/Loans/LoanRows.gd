class_name LoanRows extends RefCounted

#Turns what FinanceManager holds into the rows the Loans page draws: one row per offer, request,
#active loan and closed loan, with the metrics the sort and the filters read.
#Static only; the page keeps the chosen view, the sort and the ranges.

const KIND_OFFER: StringName = &"offer"
const KIND_REQUEST: StringName = &"request"
const KIND_ACTIVE: StringName = &"active"
const KIND_CLOSED: StringName = &"closed"
const VIEW_ACTIVE: StringName = &"active"
const VIEW_PENDING: StringName = &"pending"
const VIEW_CLOSED: StringName = &"closed"
const SORT_KEYS: Array[String] = ["monthly", "payoff", "duration"]
const SORT_LABELS: Dictionary = {"monthly": "Monthly Payment", "payoff": "Payoff Amount",
	"duration": "Duration"}
const FILTER_DEFS: Array[Dictionary] = [
	{"key": "monthly", "label": "Monthly Payment", "step": 10.0, "format": "notes"},
	{"key": "remaining", "label": "Remaining Payment", "step": 50.0, "format": "notes"},
	{"key": "rate", "label": "Interest", "step": 1.0, "format": "percent"},
	{"key": "paid", "label": "Payments Made", "step": 1.0, "format": "plain"},
	{"key": "payoff", "label": "Payoff Amount", "step": 50.0, "format": "notes"},
]
const EMPTY_FILTERED: String = "No loans match these filters."
const NO_TEAM_TEXT: String = "No mercs sent"
const AWAITING_TEXT: String = "Awaiting Offer"
const REVIEW_TEXT: String = "Review Offer"
const REVIEW_NOTE: String = "Accept or decline"
const DISMISS_TEXT: String = "Dismiss"
const EXPIRED_NOTE: String = "Offer expired"
const EXPIRED_DEADLINE_TEXT: String = "Expired"
const PAY_OFF_TEXT: String = "Pay Off"
const CLOSE_NOTE: String = "to close"


#Every row of every view, keyed by the view name.
static func sets(show_requests: bool, show_expired: bool) -> Dictionary:
	var pending: Array[Dictionary] = []
	for row: Dictionary in FinanceManager.offers:
		var built: Dictionary = offer_row(row)
		if show_expired or not bool(built.get("expired", false)):
			pending.append(built)
	if show_requests:
		for row: Dictionary in FinanceManager.requests:
			pending.append(request_row(row))
	var active: Array[Dictionary] = []
	for loan: LoanData in FinanceManager.loans:
		active.append(active_row(loan))
	var closed: Array[Dictionary] = []
	for loan: LoanData in FinanceManager.closed_loans:
		closed.append(closed_row(loan))
	return {VIEW_PENDING: pending, VIEW_ACTIVE: active, VIEW_CLOSED: closed}


#The view that is really shown: an empty view falls back to Active.
static func view_for(chosen: StringName, all: Dictionary) -> StringName:
	var rows: Array = all.get(chosen, []) as Array
	if not rows.is_empty() or chosen == VIEW_ACTIVE:
		return chosen
	return VIEW_ACTIVE


static func offer_row(row: Dictionary) -> Dictionary:
	var id: int = int(row["id"])
	var amount: int = int(row["offer_amount"])
	var rate: float = float(row["offer_rate"])
	var term: int = int(row["offer_term"])
	var first_due: int = int(row.get("offer_first_due", LoanLogic.FIRST_DUE_FAIR))
	var monthly: int = LoanLogic.payment(amount, rate, term)
	var hours: float = FinanceManager.hours_left(id)
	var expired: bool = bool(row.get("expired", false))
	var out: Dictionary = _base(KIND_OFFER, id, String(row["lender"]), amount, rate, term, monthly)
	out["first_due"] = first_due
	out["hours"] = hours
	out["expired"] = expired
	out["unread"] = false if expired else FinanceManager.offer_unread(id)
	out["metrics"] = _metrics(monthly, monthly * term, rate, 0, amount, term)
	var text: Dictionary = out["text"] as Dictionary
	text["first_due"] = LoanLogic.months_label(first_due)
	if expired:
		text["deadline"] = EXPIRED_DEADLINE_TEXT
		text["right"] = DISMISS_TEXT
		text["note"] = EXPIRED_NOTE
	else:
		text["deadline"] = GuiDates.duration_text(hours)
		text["right"] = REVIEW_TEXT
		text["note"] = REVIEW_NOTE
	return out


#Every open offer but the one given: the offers that taking it throws away.
static func other_offers(offer_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in FinanceManager.open_offers():
		if int(row.get("id", -1)) != offer_id:
			out.append(row)
	return out


static func request_row(row: Dictionary) -> Dictionary:
	var id: int = int(row["id"])
	var amount: int = int(row["amount"])
	var rate: float = float(row["rate"])
	var term: int = int(row["term"])
	var monthly: int = LoanLogic.payment(amount, rate, term)
	var out: Dictionary = _base(KIND_REQUEST, id, String(row["lender"]), amount, rate, term,
		monthly)
	var odds: int = int(row.get("odds", 0))
	var team: Array[int] = []
	for raw: Variant in row.get("team", []) as Array:
		team.append(int(raw))
	out["odds"] = odds
	out["team"] = team
	out["team_rows"] = team_rows(team)
	out["metrics"] = _metrics(monthly, monthly * term, rate, 0, amount, term)
	var text: Dictionary = out["text"] as Dictionary
	text["odds"] = "%d%%" % odds
	text["team"] = NO_TEAM_TEXT if team.is_empty() else _team_names(out["team_rows"] as Array)
	text["right"] = AWAITING_TEXT
	text["note"] = ""
	return out


static func active_row(loan: LoanData) -> Dictionary:
	var monthly: int = FinanceManager.loan_payment(loan)
	var remaining: int = monthly * loan.months_left()
	var payoff: int = FinanceManager.payoff_amount(loan.id)
	var out: Dictionary = _base(KIND_ACTIVE, loan.id, loan.lender, loan.principal, loan.rate,
		loan.months, monthly)
	out["remaining"] = remaining
	out["payoff"] = payoff
	out["paid"] = loan.paid
	out["months"] = loan.months
	out["can_pay"] = payoff <= GameState.bank_notes
	out["metrics"] = _metrics(monthly, remaining, loan.rate, loan.paid, payoff, loan.months)
	var text: Dictionary = out["text"] as Dictionary
	text["remaining"] = TransactionData.grouped(remaining)
	text["due"] = due_text(loan.id)
	text["due_rel"] = FinanceManager.next_due_text(loan.id)
	text["progress"] = "%d / %d paid" % [loan.paid, loan.months]
	text["right"] = PAY_OFF_TEXT
	text["note"] = "%s %s" % [TransactionData.grouped(payoff), CLOSE_NOTE]
	return out


static func closed_row(loan: LoanData) -> Dictionary:
	var monthly: int = FinanceManager.loan_payment(loan)
	var interest: int = loan.paid_total - loan.principal
	var out: Dictionary = _base(KIND_CLOSED, loan.id, loan.lender, loan.principal, loan.rate,
		loan.months, monthly)
	out["total_paid"] = loan.paid_total
	out["interest"] = interest
	out["paid"] = loan.paid
	out["months"] = loan.months
	out["closed_as"] = loan.closed_as
	out["metrics"] = _metrics(monthly, 0, loan.rate, loan.paid, 0, loan.months)
	var text: Dictionary = out["text"] as Dictionary
	text["total_paid"] = TransactionData.grouped(loan.paid_total)
	text["interest"] = TransactionData.grouped(interest)
	text["progress"] = progress_text(loan)
	text["closed_as"] = loan.closed_as
	text["right"] = ""
	text["note"] = ""
	return out


static func progress_text(loan: LoanData) -> String:
	if loan.paid < loan.months:
		return "%d payments + payoff" % loan.paid
	return "%d / %d paid" % [loan.paid, loan.months]


static func due_text(loan_id: int) -> String:
	var minute: int = FinanceManager.next_due_minute(loan_id)
	if minute < 0:
		return ""
	return GuiDates.day_text(TrynnCalendar.day_index(minute))


static func team_rows(team: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for uid: int in team:
		out.append(merc_row(uid))
	return out


static func merc_row(uid: int) -> Dictionary:
	var view: MercView = GameState.view_by_uid(uid)
	var merc_name: String = "Merc %d" % uid if view == null else view.name
	var tradition: String = "" if view == null else view.tradition
	return {"uid": uid, "name": merc_name, "tradition": tradition,
		"fit": FinanceManager.merc_fit(uid)}


#The highest value of each metric in the view, rounded up to the step of that filter.
static func caps(base: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for def: Dictionary in FILTER_DEFS:
		var key: String = String(def["key"])
		var step: float = float(def["step"])
		var top: float = 0.0
		for row: Dictionary in base:
			top = maxf(top, float((row["metrics"] as Dictionary)[key]))
		out[key] = maxf(step, ceilf(top / step) * step)
	return out


#One filter range clamped into its cap; an unset range is the whole span.
static func range_of(key: String, ranges: Dictionary, cap_rows: Dictionary) -> Vector2:
	var cap: float = float(cap_rows.get(key, 0.0))
	var raw: Vector2 = ranges.get(key, Vector2(0.0, cap)) as Vector2
	var high: float = minf(raw.y, cap)
	return Vector2(minf(raw.x, high), high)


static func passes(row: Dictionary, ranges: Dictionary, cap_rows: Dictionary) -> bool:
	var metrics: Dictionary = row["metrics"] as Dictionary
	for def: Dictionary in FILTER_DEFS:
		var key: String = String(def["key"])
		var span: Vector2 = range_of(key, ranges, cap_rows)
		var value: float = float(metrics[key])
		if value < span.x or value > span.y:
			return false
	return true


#Live rows sorted by key, then expired rows sorted by key, appended after: expired always last,
#in both sort directions.
static func apply(base: Array[Dictionary], ranges: Dictionary, cap_rows: Dictionary,
		sort_key: String, descending: bool) -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	var expired: Array[Dictionary] = []
	for row: Dictionary in base:
		if bool(row.get("expired", false)):
			expired.append(row)
		else:
			live.append(row)
	var out: Array[Dictionary] = _sorted(live, ranges, cap_rows, sort_key, descending)
	out.append_array(_sorted(expired, ranges, cap_rows, sort_key, descending))
	return out


static func _sorted(rows: Array[Dictionary], ranges: Dictionary, cap_rows: Dictionary,
		sort_key: String, descending: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in rows:
		if passes(row, ranges, cap_rows):
			out.append(row)
	var key: String = sort_key if SORT_KEYS.has(sort_key) else SORT_KEYS[0]
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float((a["metrics"] as Dictionary)[key]) > float((b["metrics"] as Dictionary)[key]))
	if not descending:
		out.reverse()
	return out


#True while any range is narrower than its cap, or the requests or the expired offers are hidden.
static func filters_active(show_requests: bool, show_expired: bool, ranges: Dictionary,
		cap_rows: Dictionary) -> bool:
	if not show_requests:
		return true
	if not show_expired:
		return true
	for def: Dictionary in FILTER_DEFS:
		var key: String = String(def["key"])
		var span: Vector2 = range_of(key, ranges, cap_rows)
		if span.x > 0.0 or span.y < float(cap_rows.get(key, 0.0)):
			return true
	return false


static func filter_def(key: String) -> Dictionary:
	for def: Dictionary in FILTER_DEFS:
		if String(def["key"]) == key:
			return def
	return {}


static func value_text(key: String, value: float) -> String:
	var def: Dictionary = filter_def(key)
	var style: String = String(def.get("format", "plain"))
	if style == "notes":
		return TransactionData.grouped(roundi(value))
	if style == "percent":
		return "%d%%" % roundi(value)
	return "%d" % roundi(value)


static func range_text(key: String, low: float, high: float) -> String:
	return "%s - %s" % [value_text(key, low), value_text(key, high)]


static func empty_text(view: StringName, base_rows: int) -> String:
	if base_rows > 0:
		return EMPTY_FILTERED
	return "No %s loans." % String(view)


static func terms_text(rate: float, term: int) -> String:
	return "at %d%% - %d months" % [roundi(rate * 100.0), term]


static func _base(kind: StringName, id: int, lender: String, amount: int, rate: float, term: int,
		monthly: int) -> Dictionary:
	return {"kind": kind, "id": id, "lender": lender, "amount": amount, "rate": rate,
		"term": term, "monthly": monthly,
		"text": {"lender": lender, "amount": TransactionData.grouped(amount),
			"terms": terms_text(rate, term), "monthly": TransactionData.grouped(monthly)}}


static func _metrics(monthly: int, remaining: int, rate: float, paid: int, payoff: int,
		duration: int) -> Dictionary:
	return {"monthly": monthly, "remaining": remaining, "rate": roundi(rate * 100.0),
		"paid": paid, "payoff": payoff, "duration": duration}


static func _team_names(rows: Array) -> String:
	var names: Array[String] = []
	for raw: Variant in rows:
		names.append(String((raw as Dictionary)["name"]))
	return ", ".join(names)
