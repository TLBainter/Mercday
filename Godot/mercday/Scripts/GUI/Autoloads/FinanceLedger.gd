extends Node

#The guild books: every note the bank moves, the bills that are coming and what the horizon
#projects to. The Finance Overview reads rows(), projection(), expense_breakdown() and
#stat_cards(); nothing is drawn here. Two bills are charged here, the subscription on the 15th
#and the guild expenses on the 29th. Payroll is billed by GameState, loans by FinanceManager and
#ads by PromotionsManager, so none of those is charged twice.

signal changed

enum Horizon {END_OF_MONTH, END_OF_QUARTER, END_OF_YEAR}

const HORIZON_LABELS: Array[String] = ["End of Month", "End of Quarter", "End of Year"]
#Day of the calendar month each bill falls on.
const BILL_DAYS: Dictionary = {"payroll": 2, "loans": 15, "subscription": 15, "guild": 29}
#The category a money reason files under; a reason missing here files under OTHER_CATEGORY.
const CATEGORY_OF: Dictionary = {
	"contract": "Contract", "travel": "Travel", "travel_refund": "Travel",
	"loan": "Loan", "loan_payment": "Loan", "loan_payoff": "Loan", "guild": "Guild",
	"payroll": "Payroll", "subscription": "Subscription", "upgrade": "Subscription",
	"ads": "Ads", "bazaar": "Bazaar", "legal": "Legal", "fine": "Legal", "bail": "Legal",
	"permit": "Legal", "odd_job": "Odd Job", "hiring": "Hiring", "hire": "Hiring",
	"stock": "Invest", "dividend": "Invest", "benefit": "Benefit",
}
const OTHER_CATEGORY: String = "Other"
const CONTRACT_CATEGORY: String = "Contract"
const MAX_ROWS: int = 500
const BREAKDOWN_CELLS: int = 20
const SUBSCRIPTION_LABEL: String = "Mercday Subscription"
const GUILD_LABEL: String = "Guild Expenses"
const CREAM: Color = Color("#f3ead7")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")

#PLACEHOLDER
#The monthly rates the prototype prints until real books add them up, the pro-rating base of a
#projection and the nine rows of seeded history the Overview opens on. days_ago dates a seed row
#back from the current minute. The income line is the ledger income of the last RATE_DAYS days,
#read through income_in(), not a placeholder rate.
const TRAVEL_RATE: int = 600
const GUILD_RATE: int = 300
const RATE_DAYS: int = 30
const SEED_ROWS: Array[Dictionary] = [
	{"days_ago": 15, "label": "Contract 9 Name - Reward", "amount": 1600, "reason": "contract"},
	{"days_ago": 11, "label": "Lender 1 - Payment", "amount": -180, "reason": "loan_payment"},
	{"days_ago": 9, "label": "Guild Expenses", "amount": -120, "reason": "guild"},
	{"days_ago": 7, "label": "Travel - Airship (x4)", "amount": -560, "reason": "travel"},
	{"days_ago": 6, "label": "Contract 14 Name - Reward", "amount": 1900, "reason": "contract"},
	{"days_ago": 4, "label": "Lender 2 - Payment", "amount": -160, "reason": "loan_payment"},
	{"days_ago": 2, "label": "Contract 13 Name - Reward", "amount": 260, "reason": "contract"},
	{"days_ago": 1, "label": "Travel - Horse (x2)", "amount": -40, "reason": "travel"},
	{"days_ago": 0, "label": "Contract 12 Name - Reward", "amount": 300, "reason": "contract"},
]

#Oldest first; rows() hands them back newest first.
var transactions: Array[TransactionData] = []

var _seeded: bool = false
var _last_day: int = -1
var _pending_label: String = ""


func _ready() -> void:
	GameState.roster_changed.connect(_on_roster_changed)
	GameState.day_changed.connect(_on_day_changed)
	if GameState.has_signal("money_logged"):
		GameState.connect("money_logged", _on_money_logged)
	else:
		GameState.money_moved.connect(_on_money_moved)
	reset()


#Drops every row and lays the seeded history down again, dated off the current minute.
func reset() -> void:
	transactions.clear()
	_last_day = -1
	_pending_label = ""
	var now: int = CampaignClock.now()
	for row: Dictionary in SEED_ROWS:
		var reason: String = str(row["reason"])
		var minute: int = now - int(row["days_ago"]) * CampaignClock.MINUTES_PER_DAY
		transactions.append(TransactionData.make(int(row["amount"]), minute,
			str(row["label"]), category_of(reason), reason))
	_seeded = GameState.started
	changed.emit()


#The category a reason files under.
func category_of(reason: String) -> String:
	return str(CATEGORY_OF.get(reason, OTHER_CATEGORY))


#Files one money movement. An empty label reads as the category name; an unnamed credit is a
#contract reward, the one movement GameState leaves without a reason.
func record(delta: int, reason: String, label: String = "") -> void:
	var category: String = category_of(reason)
	if category == OTHER_CATEGORY and reason.is_empty() and delta > 0:
		category = CONTRACT_CATEGORY
	var text: String = label
	if text.is_empty():
		text = category
	transactions.append(TransactionData.make(delta, CampaignClock.now(), text, category, reason))
	while transactions.size() > MAX_ROWS:
		transactions.remove_at(0)
	changed.emit()


#Newest first; limit 0 hands back every row.
func rows(limit: int = 0) -> Array[TransactionData]:
	var out: Array[TransactionData] = []
	var i: int = transactions.size() - 1
	while i >= 0:
		out.append(transactions[i])
		if limit > 0 and out.size() >= limit:
			break
		i -= 1
	return out


#Whole calendar days from today to the next such day of the month; 0 when that day is today.
func next_in(day_of_month: int) -> int:
	var today: int = _today()
	for n: int in range(TrynnCalendar.DAYS_PER_YEAR + 1):
		if _day_of_month(today + n) == day_of_month:
			return n
	return 0


#How often that day of the month falls inside the window starting today.
func count_in(day_of_month: int, days: int) -> int:
	var today: int = _today()
	var found: int = 0
	for i: int in range(maxi(0, days)):
		if _day_of_month(today + i) == day_of_month:
			found += 1
	return found


#"Today", "1 Day From Now", "12 Days From Now".
func rel_text(n: int) -> String:
	if n <= 0:
		return "Today"
	if n == 1:
		return "1 Day From Now"
	return "%d Days From Now" % n


#Today through the last day of the calendar month, of the current season or of the year.
func horizon_days(h: int) -> int:
	var today: int = _today()
	var date: Dictionary = TrynnCalendar.date_of(today * CampaignClock.MINUTES_PER_DAY)
	var year: int = int(date["year"])
	var last: int = int(date["month"])
	if h == Horizon.END_OF_QUARTER:
		last = _season_end_month(last)
	elif h == Horizon.END_OF_YEAR:
		last = TrynnCalendar.MONTHS.size() - 1
	var start: int = TrynnCalendar.day_index(TrynnCalendar.month_start_minute(year, last))
	var end: int = start + int(TrynnCalendar.MONTHS[last]["days"]) - 1
	return maxi(1, end - today + 1)


func monthly_income() -> int:
	return income_in(RATE_DAYS)


#Income the ledger has recorded across the last N days, today included.
func income_in(days: int) -> int:
	var start: int = _today() - days + 1
	var total: int = 0
	for row: TransactionData in transactions:
		if row.amount > 0 and row.day_index >= start:
			total += row.amount
	return total


#What the roster costs a month; GameState owns the payroll debit itself.
func payroll() -> int:
	return GameState.month_expenses()


#Loan instalments plus the subscription bill, the two lines that go out together on the 15th.
func loans_and_services() -> int:
	var total: int = SubscriptionManager.monthly_cost()
	var finance: Node = get_node_or_null("/root/FinanceManager")
	if finance != null and finance.has_method("monthly_loans"):
		total += int(finance.call("monthly_loans"))
	return total


#What the Infinite campaigns bill a month.
func ads() -> int:
	var promos: Node = get_node_or_null("/root/PromotionsManager")
	if promos != null and promos.has_method("monthly_ad_bill"):
		return int(promos.call("monthly_ad_bill"))
	return 0


func monthly_expenses() -> int:
	return payroll() + loans_and_services() + GUILD_RATE + TRAVEL_RATE + ads()


func net_month() -> int:
	return monthly_income() - monthly_expenses()


#The Projection panel: one row per line of the horizon, the last one the running total.
func projection(h: int) -> Dictionary:
	var days: int = horizon_days(h)
	var out: Array[Dictionary] = []
	out.append(_row("notes", "Current Notes", "", GameState.bank_notes, 0))
	out.append(_row("income", "Expected Income", "", _pro_rated(monthly_income(), days), 0))
	var pay_day: int = int(BILL_DAYS["payroll"])
	var pay_count: int = count_in(pay_day, days)
	out.append(_row("payroll", "Payroll (%dx)" % pay_count, _next_sub(pay_day, pay_count),
		-(payroll() * pay_count), pay_count))
	var loan_day: int = int(BILL_DAYS["loans"])
	var loan_count: int = count_in(loan_day, days)
	var services: int = _loan_payments(loan_count)
	services += SubscriptionManager.monthly_cost() * loan_count
	out.append(_row("loans", "Loans & Services (%dx)" % loan_count,
		_next_sub(loan_day, loan_count), -services, loan_count))
	var guild_day: int = int(BILL_DAYS["guild"])
	var guild_count: int = count_in(guild_day, days)
	out.append(_row("guild", "Guild Expenses (%dx)" % guild_count,
		_next_sub(guild_day, guild_count), -(GUILD_RATE * guild_count), guild_count))
	out.append(_row("travel", "Travel (est.)", "Per contract", -_pro_rated(TRAVEL_RATE, days), 0))
	var bills: Dictionary = _ad_bills(days)
	out.append(_row("ads", "Ads", _promo_sub(""), -int(bills["amount"]), int(bills["count"])))
	var total: int = 0
	for row: Dictionary in out:
		total += int(row["amount"])
	out.append(_row("total", "Projected Notes", "", total, 0))
	return {"days": days, "when": _when_text(days), "total": total, "rows": out}


#The Monthly Expenses bars: five rows, each with how many of the twenty cells are lit.
func expense_breakdown() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"key": "payroll", "label": "Payroll", "amount": payroll(),
		"sub": _bill_sub(int(BILL_DAYS["payroll"]))})
	out.append({"key": "loans", "label": "Loans & Services", "amount": loans_and_services(),
		"sub": _bill_sub(int(BILL_DAYS["loans"]))})
	out.append({"key": "guild", "label": "Guild Expenses", "amount": GUILD_RATE,
		"sub": _bill_sub(int(BILL_DAYS["guild"]))})
	out.append({"key": "travel", "label": "Travel", "amount": TRAVEL_RATE,
		"sub": "Per contract (avg.)"})
	out.append({"key": "ads", "label": "Ads", "amount": ads(),
		"sub": _promo_sub(" - billed monthly")})
	var top: int = 0
	for row: Dictionary in out:
		top = maxi(top, int(row["amount"]))
	for row: Dictionary in out:
		row["cells"] = _cells(int(row["amount"]), top)
	return out


#The four cards over the Projection panel.
func stat_cards() -> Array[Dictionary]:
	var net: int = net_month()
	var lead: String = "+" if net >= 0 else ""
	var out: Array[Dictionary] = []
	out.append({"key": "notes", "label": "Current Notes",
		"value": TransactionData.grouped(GameState.bank_notes),
		"sub": GuiDates.day_text(_today()), "color": CREAM})
	out.append({"key": "income", "label": "Monthly Income",
		"value": TransactionData.grouped(monthly_income()),
		"sub": "Contract rewards, last %d days" % RATE_DAYS, "color": GREEN})
	out.append({"key": "expenses", "label": "Monthly Expenses",
		"value": TransactionData.grouped(monthly_expenses()),
		"sub": "Payroll, loans, guild, travel, ads", "color": RED})
	out.append({"key": "net", "label": "Net / Month",
		"value": lead + TransactionData.grouped(net),
		"sub": "Growing" if net >= 0 else "Shrinking", "color": GREEN if net >= 0 else RED})
	return out


#The clock hook: every calendar day passed since the last call is billed once, in order.
func tick(now: int) -> void:
	if _seed_if_started():
		return
	var today: int = TrynnCalendar.day_index(now)
	if _last_day < 0:
		_last_day = today
		return
	if today <= _last_day:
		return
	var day: int = _last_day
	while day < today:
		day += 1
		_bill_day(day)
	_last_day = today


#The two bills this ledger owns, for one calendar day.
func _bill_day(day_index: int) -> void:
	var dom: int = _day_of_month(day_index)
	if dom == int(BILL_DAYS["subscription"]):
		_bill(SubscriptionManager.monthly_cost(), "subscription", SUBSCRIPTION_LABEL)
	if dom == int(BILL_DAYS["guild"]):
		_bill(GUILD_RATE, "guild", GUILD_LABEL)


#A bill that always lands where GameState can take it; the money listener files the row.
func _bill(amount: int, reason: String, label: String) -> void:
	if amount <= 0:
		return
	_pending_label = label
	if GameState.has_method("charge"):
		GameState.call("charge", amount, reason, label)
	else:
		GameState.spend(amount, reason)
	_pending_label = ""


func _row(key: String, label: String, sub: String, amount: int, count: int) -> Dictionary:
	return {"key": key, "label": label, "sub": sub, "amount": amount, "count": count}


func _pro_rated(rate: int, days: int) -> int:
	return int(round(float(rate) / float(RATE_DAYS) * float(days)))


func _next_sub(day_of_month: int, count: int) -> String:
	if count <= 0:
		return "None in period"
	return "Next: %s" % rel_text(next_in(day_of_month))


func _bill_sub(day_of_month: int) -> String:
	return "%s - %s" % [TrynnCalendar.ordinal(day_of_month), rel_text(next_in(day_of_month))]


#"in 24 days - Zelday, 30th of Erta 304".
func _when_text(days: int) -> String:
	var span: int = maxi(1, days)
	var last: int = (_today() + span - 1) * CampaignClock.MINUTES_PER_DAY
	return "in %s - %s" % [GuiDates.days_text(span), TrynnCalendar.date_text(last)]


#"No ongoing promos", "1 ongoing promo<suffix>", "3 ongoing promos<suffix>".
func _promo_sub(suffix: String) -> String:
	var count: int = 0
	var promos: Node = get_node_or_null("/root/PromotionsManager")
	if promos != null and promos.has_method("infinite_count"):
		count = int(promos.call("infinite_count"))
	if count <= 0:
		return "No ongoing promos"
	return "%d ongoing %s%s" % [count, "promo" if count == 1 else "promos", suffix]


#What the Infinite campaigns bill inside the window, and how many charges that is.
func _ad_bills(days: int) -> Dictionary:
	var out: Dictionary = {"amount": 0, "count": 0}
	var promos: Node = get_node_or_null("/root/PromotionsManager")
	if promos == null or not promos.has_method("ad_bill_days"):
		return out
	var bills: Variant = promos.call("ad_bill_days", _today(), maxi(0, days))
	if not (bills is Array):
		return out
	for bill: Variant in (bills as Array):
		if not (bill is Dictionary):
			continue
		out["amount"] = int(out["amount"]) + int((bill as Dictionary).get("amount", 0))
		out["count"] = int(out["count"]) + 1
	return out


#What the active loans take over that many billing days; a copy with no loan list pays nothing.
func _loan_payments(times: int) -> int:
	if times <= 0:
		return 0
	var finance: Node = get_node_or_null("/root/FinanceManager")
	if finance == null or not finance.has_method("loan_payment"):
		return 0
	var loans: Variant = finance.get("loans")
	if not (loans is Array):
		return 0
	var total: int = 0
	for loan: Variant in (loans as Array):
		if not (loan is Object):
			continue
		var held: Object = loan as Object
		var left: int = maxi(0, _field(held, "months", 0) - _field(held, "paid", 0))
		if left <= 0:
			continue
		total += int(finance.call("loan_payment", held)) * mini(times, left)
	return total


static func _field(source: Object, key: String, fallback: int) -> int:
	if source == null:
		return fallback
	var value: Variant = source.get(key)
	if value == null:
		return fallback
	return int(value)


#How many of the twenty bar cells light for a value against the tallest row.
func _cells(value: int, top: int) -> int:
	if top <= 0:
		return 0
	var lit: int = 0
	for i: int in range(BREAKDOWN_CELLS):
		if (float(i) + 0.5) / float(BREAKDOWN_CELLS) < float(value) / float(top):
			lit += 1
	return lit


#The last month of the season this month sits in; the seasons run in blocks.
func _season_end_month(month: int) -> int:
	var season: String = str(TrynnCalendar.MONTHS[month]["season"])
	var last: int = month
	while last + 1 < TrynnCalendar.MONTHS.size():
		if str(TrynnCalendar.MONTHS[last + 1]["season"]) != season:
			break
		last += 1
	return last


func _today() -> int:
	return TrynnCalendar.day_index(CampaignClock.now())


func _day_of_month(day_index: int) -> int:
	return int(TrynnCalendar.date_of(day_index * CampaignClock.MINUTES_PER_DAY)["day"])


func _on_roster_changed() -> void:
	_seed_if_started()


func _on_day_changed(_day_index: int) -> void:
	_seed_if_started()


#Reseeds once, on the first signal after a campaign starts; true when this call did it.
func _seed_if_started() -> bool:
	if _seeded or not GameState.started:
		return false
	reset()
	return true


func _on_money_moved(delta: int, reason: String) -> void:
	var label: String = _pending_label
	_pending_label = ""
	record(delta, reason, label)


func _on_money_logged(delta: int, reason: String, label: String) -> void:
	_pending_label = ""
	record(delta, reason, label)
