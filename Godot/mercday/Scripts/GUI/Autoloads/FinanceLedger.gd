extends Node

#The guild books: every note the bank moves, the bills that are coming and what the horizon
#projects to. The Finance Overview reads rows(), projection(), expense_breakdown() and
#stat_cards(); nothing is drawn here. Two bills are charged here, both on the 2nd: the subscription
#and the guild expenses, as separate rows. Payroll is billed by GameState, loans by FinanceManager on
#each loan's own day and ads by PromotionsManager, so none of those is charged twice.

signal changed

enum Horizon {END_OF_MONTH, END_OF_QUARTER, END_OF_YEAR}

const HORIZON_LABELS: Array[String] = ["End of Month", "End of Quarter", "End of Year"]
#Day of the calendar month each bill falls on.
const BILL_DAYS: Dictionary = {"payroll": 2, "subscription": SubscriptionManager.BILL_DAY,
	"guild": 2}
#The category a money reason files under; a reason missing here files under OTHER_CATEGORY.
const CATEGORY_OF: Dictionary = {
	GameState.REASON_CONTRACT: "Contract", GameState.REASON_TRAVEL: "Travel",
	GameState.REASON_TRAVEL_REFUND: "Travel", GameState.REASON_LOAN: "Loan",
	GameState.REASON_LOAN_PAYMENT: "Loan", GameState.REASON_LOAN_PAYOFF: "Loan",
	GameState.REASON_GUILD: "Guild", GameState.REASON_PAYROLL: "Payroll",
	GameState.REASON_SUBSCRIPTION: "Subscription", GameState.REASON_UPGRADE: "Subscription",
	GameState.REASON_ADS: "Ads", GameState.REASON_BAZAAR: "Bazaar",
	GameState.REASON_LEGAL: "Legal", GameState.REASON_FINE: "Legal",
	GameState.REASON_BAIL: "Legal", GameState.REASON_PERMIT: "Legal",
	GameState.REASON_ODD_JOB: "Odd Job", GameState.REASON_HIRING: "Hiring",
	GameState.REASON_HIRE: "Hiring", GameState.REASON_STOCK: "Invest",
	GameState.REASON_DIVIDEND: "Invest", GameState.REASON_BENEFIT: "Benefit",
	GameState.REASON_BONUS: "Benefit", GameState.REASON_MAIL: OTHER_CATEGORY,
}
const OTHER_CATEGORY: String = "Other"
const CONTRACT_CATEGORY: String = "Contract"
const MAX_ROWS: int = 500
const BREAKDOWN_CELLS: int = 20
const SUBSCRIPTION_LABEL: String = "Mercday Subscription"
const GUILD_LABEL: String = "Guild Expenses"
const SERVICE_LABEL: String = "Mercday Service"
const ADDONS_LABEL: String = "Add-Ons"
#A tooltip line with this amount prints its label alone, as a heading.
const NO_AMOUNT: int = -1

#PLACEHOLDER
#The guild rate the prototype prints until real books add it up, and the pro-rating base of a
#projection. The income line is the ledger income of the last RATE_DAYS days, read through income_in(),
#not a placeholder rate.
const GUILD_RATE: int = 30
const RATE_DAYS: int = 30

#Oldest first; rows() hands them back newest first.
var transactions: Array[TransactionData] = []

var _last_day: int = -1


func _ready() -> void:
	GameState.game_started.connect(reset)
	GameState.money_logged.connect(_on_money_logged)
	reset()


#Drops every row: a new campaign opens on empty books.
func reset() -> void:
	transactions.clear()
	_last_day = -1
	changed.emit()


#The category a reason files under.
func category_of(reason: String) -> String:
	return str(CATEGORY_OF.get(reason, OTHER_CATEGORY))


#Files one money movement. An empty label reads as the category name; an unnamed credit is a
#contract reward, the one movement GameState leaves without a reason.
func record(delta: int, reason: String, label: String = "", mode: String = "", km: int = 0) -> void:
	var category: String = category_of(reason)
	if category == OTHER_CATEGORY and reason.is_empty() and delta > 0:
		category = CONTRACT_CATEGORY
	var text: String = label
	if text.is_empty():
		text = category
	transactions.append(TransactionData.make(delta, CampaignClock.now(), text, category, reason, mode, km))
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


#One instalment of every active loan.
func loans_total() -> int:
	var total: int = 0
	for loan: Object in _active_loans():
		total += _loan_payment(loan)
	return total


#The next bill of every running campaign: per_day for its days to the next bill date or its end.
func ads() -> int:
	return PromotionsManager.monthly_ad_bill()


#The monthly guild bill.
func guild_rate() -> int:
	return GUILD_RATE


#The combined Mercday bill of the 2nd: the guild rate plus the subscription and its add-ons.
func guild_bill() -> int:
	return guild_rate() + SubscriptionManager.monthly_cost()


#The monthly travel estimate in the budget.
func travel_rate() -> int:
	return int(travel_forecast()["total"])


#TravelForecaster over the books as they stand: {"total", "groups", "trend", "scale", "estimate"}.
func travel_forecast() -> Dictionary:
	return TravelForecaster.new().forecast(transactions, _today())


#BenefitForecaster over the books as they stand; the bonuses sit outside payroll(), so this adds to no row.
func benefits_forecast() -> Dictionary:
	return BenefitForecaster.new().forecast(transactions, _today())


func monthly_expenses() -> int:
	return payroll() + loans_total() + guild_bill() + travel_rate() + ads()


func net_month() -> int:
	return monthly_income() - monthly_expenses()


#The Projection panel: one row per line of the horizon, the last one the running total.
func projection(h: int) -> Dictionary:
	var days: int = horizon_days(h)
	var out: Array[Dictionary] = []
	out.append(_row("notes", "Current Notes", "", GameState.bank_notes, 0))
	out.append(_row("income", "Expected Income", "", _pro_rated(monthly_income(), days), 0))
	var pay_day: int = int(BILL_DAYS["payroll"])
	out.append(_row("payroll", "Payroll", _next_sub(next_in(pay_day)), -payroll(),
		count_in(pay_day, days)))
	var soonest: int = _soonest_loan_days()
	var loan_sub: String = "No active loans" if soonest < 0 else _next_sub(soonest)
	out.append(_row("loans", "Loans", loan_sub, -loans_total(), _loan_bills_in(days)))
	var guild_day: int = int(BILL_DAYS["guild"])
	out.append(_row("guild", GUILD_LABEL, _next_sub(next_in(guild_day)), -guild_bill(),
		count_in(guild_day, days)))
	var travel: Dictionary = travel_forecast()
	out.append(_row("travel", "Travel (est.)", _travel_sub(travel), -int(travel["total"]), 0))
	var bills: Dictionary = _ad_bills(days)
	out.append(_row("ads", "Ads", _promo_sub(""), -ads(), int(bills["count"])))
	var total: int = 0
	for row: Dictionary in out:
		total += int(row["amount"])
	out.append(_row("total", "Projected Notes", "", total, 0))
	return {"days": days, "when": _when_text(days), "total": total, "rows": out}


#The Monthly Expenses bars: five rows, each with how many of the twenty cells are lit and the
#lines its tooltip lists. Every line item sits in exactly one row.
func expense_breakdown() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"key": "payroll", "label": "Payroll", "amount": payroll(),
		"sub": _bill_sub(int(BILL_DAYS["payroll"])), "lines": payroll_lines()})
	var soonest: int = _soonest_loan_days()
	var loan_sub: String = "No active loans"
	if soonest >= 0:
		loan_sub = "Next: %s" % GuiDates.from_now_text(soonest)
	out.append({"key": "loans", "label": "Loans", "amount": loans_total(), "sub": loan_sub,
		"lines": loan_lines()})
	out.append({"key": "guild", "label": GUILD_LABEL, "amount": guild_bill(),
		"sub": _bill_sub(int(BILL_DAYS["guild"])), "lines": guild_lines()})
	var travel: Dictionary = travel_forecast()
	out.append({"key": "travel", "label": "Travel", "amount": int(travel["total"]),
		"sub": _travel_sub(travel), "lines": travel_lines(travel)})
	out.append({"key": "ads", "label": "Ads", "amount": ads(),
		"sub": _promo_sub(" - billed monthly"), "lines": ad_lines()})
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
		"sub": GuiDates.day_text(_today()), "color": GuiColors.CREAM})
	out.append({"key": "income", "label": "Monthly Income",
		"value": TransactionData.grouped(monthly_income()),
		"sub": "Contract rewards, last %d days" % RATE_DAYS, "color": GuiColors.GREEN})
	out.append({"key": "expenses", "label": "Monthly Expenses",
		"value": TransactionData.grouped(monthly_expenses()),
		"sub": "Payroll, loans, guild, travel, ads", "color": GuiColors.RED})
	out.append({"key": "net", "label": "Net / Month",
		"value": lead + TransactionData.grouped(net),
		"sub": "Growing" if net >= 0 else "Shrinking",
		"color": GuiColors.GREEN if net >= 0 else GuiColors.RED})
	return out


#The clock hook: every calendar day passed since the last call is billed once, in order.
func tick(now: int) -> void:
	_last_day = GameState.for_each_new_day(_last_day, now, _bill_day)


#The two bills this ledger owns, for one calendar day.
func _bill_day(day_index: int) -> void:
	var dom: int = _day_of_month(day_index)
	if dom == int(BILL_DAYS["subscription"]):
		GameState.charge(SubscriptionManager.monthly_cost(), GameState.REASON_SUBSCRIPTION,
			SUBSCRIPTION_LABEL)
	if dom == int(BILL_DAYS["guild"]):
		GameState.charge(guild_rate(), GameState.REASON_GUILD, GUILD_LABEL)


#Base wages of the payroll, then the benefits BenefitForecaster expects over the next 30 days.
func payroll_lines() -> Array[Dictionary]:
	var crew: int = 0
	for merc: MercenaryData in GameState.payroll_mercs():
		if not merc.is_dead and not SalarySystem.is_captive(merc):
			crew += 1
	var out: Array[Dictionary] = []
	out.append(_line("Base Wages (%d %s)" % [crew, "merc" if crew == 1 else "mercs"], payroll()))
	out.append(_line("Benefits", int(benefits_forecast()["total"])))
	return out


#One line per active loan instalment, with the day of the month it lands on.
func loan_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for loan: Object in _active_loans():
		var label: String = "%s (%s)" % [String(loan.get("lender")),
			TrynnCalendar.ordinal(_field(loan, "bill_day", 0))]
		out.append(_line(label, _loan_payment(loan)))
	return out


#The Mercday service, then the add-ons summed by the Customize category each one bills to.
func guild_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_line(SERVICE_LABEL, guild_rate() + SubscriptionManager.service_fee()))
	var by_cat: Dictionary = {}
	var order: Array[String] = TreeLayout.cat_ids()
	for id: String in UpgradeDefs.ORDER:
		var fee: int = SubscriptionManager.upgrade_fee(id)
		if fee <= 0:
			continue
		var cat: String = TreeLayout.bill_cat(id)
		if not order.has(cat):
			order.append(cat)
		by_cat[cat] = int(by_cat.get(cat, 0)) + fee
	if by_cat.is_empty():
		return out
	out.append(_line(ADDONS_LABEL, NO_AMOUNT))
	for cat: String in order:
		if int(by_cat.get(cat, 0)) > 0:
			out.append(_line(TreeLayout.cat_label(cat), int(by_cat[cat])))
	return out


#Income of the last RATE_DAYS days by category; Other is a heading with one line per label, so mail credits read Gifts.
func income_lines() -> Array[Dictionary]:
	var start: int = _today() - RATE_DAYS + 1
	var order: Array[String] = []
	var sums: Dictionary = {}
	var other: Dictionary = {}
	for row: TransactionData in transactions:
		if row.amount <= 0 or row.day_index < start:
			continue
		if row.category == OTHER_CATEGORY:
			other[row.label] = int(other.get(row.label, 0)) + row.amount
			continue
		if not sums.has(row.category):
			order.append(row.category)
		sums[row.category] = int(sums.get(row.category, 0)) + row.amount
	var out: Array[Dictionary] = []
	for category: String in order:
		out.append(_line(category, int(sums[category])))
	if not other.is_empty():
		out.append(_line(OTHER_CATEGORY, NO_AMOUNT))
		for label: String in other:
			out.append(_line(label, int(other[label])))
	return out


#One line per travel mode the forecast expects, in TRAVEL_MODES order; fares with no mode read as Other.
func travel_lines(travel: Dictionary = {}) -> Array[Dictionary]:
	if travel.is_empty():
		travel = travel_forecast()
	var groups: Dictionary = travel.get("groups", {})
	var out: Array[Dictionary] = []
	for mode: Dictionary in GuiTypes.TRAVEL_MODES:
		var key: String = String(mode["key"])
		if int(groups.get(key, 0)) > 0:
			out.append(_line(String(mode["label"]), int(groups[key])))
	for key: String in groups:
		if GuiTypes.travel_mode(key).is_empty() and int(groups[key]) > 0:
			out.append(_line("Other", int(groups[key])))
	return out


func _travel_sub(travel: Dictionary) -> String:
	if bool(travel.get("estimate", false)):
		return "Estimate"
	if int(travel.get("total", 0)) <= 0:
		return "No travel booked"
	return "Next %d days" % RATE_DAYS


#One line per campaign with a bill to come: its next bill.
func ad_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for campaign: CampaignData in PromotionsManager.campaigns:
		if campaign.next_bill_day >= 0:
			out.append(_line(campaign.name, PromotionsManager.next_bill_amount(campaign)))
	return out


func _line(label: String, amount: int) -> Dictionary:
	return {"label": label, "amount": amount}


func _row(key: String, label: String, sub: String, amount: int, count: int) -> Dictionary:
	return {"key": key, "label": label, "sub": sub, "amount": amount, "count": count}


func _pro_rated(rate: int, days: int) -> int:
	return int(round(float(rate) / float(RATE_DAYS) * float(days)))


func _next_sub(days_away: int) -> String:
	return "Next: %s" % GuiDates.from_now_text(days_away)


func _bill_sub(day_of_month: int) -> String:
	return "%s - %s" % [TrynnCalendar.ordinal(day_of_month),
		GuiDates.from_now_text(next_in(day_of_month))]


#"in 24 days - Zelday, 30th of Erta 304".
func _when_text(days: int) -> String:
	var span: int = maxi(1, days)
	var last: int = (_today() + span - 1) * CampaignClock.MINUTES_PER_DAY
	return "in %s - %s" % [GuiDates.days_text(span), TrynnCalendar.date_text(last)]


#"No ongoing promos", "1 ongoing promo<suffix>", "3 ongoing promos<suffix>".
func _promo_sub(suffix: String) -> String:
	var count: int = PromotionsManager.billed_count()
	if count <= 0:
		return "No ongoing promos"
	return "%d ongoing %s%s" % [count, "promo" if count == 1 else "promos", suffix]


#What the campaigns bill inside the window, and how many charges that is.
func _ad_bills(days: int) -> Dictionary:
	var out: Dictionary = {"amount": 0, "count": 0}
	for bill: Dictionary in PromotionsManager.ad_bill_days(_today(), maxi(0, days)):
		out["amount"] = int(out["amount"]) + int(bill.get("amount", 0))
		out["count"] = int(out["count"]) + 1
	return out


#The loans with a payment still to make; empty when no FinanceManager loan list exists.
func _active_loans() -> Array[Object]:
	var out: Array[Object] = []
	var finance: Node = get_node_or_null("/root/FinanceManager")
	if finance == null:
		return out
	var loans: Variant = finance.get("loans")
	if not (loans is Array):
		return out
	for loan: Variant in (loans as Array):
		if not (loan is Object):
			continue
		var held: Object = loan as Object
		if _field(held, "months", 0) - _field(held, "paid", 0) > 0:
			out.append(held)
	return out


func _loan_payment(loan: Object) -> int:
	var finance: Node = get_node_or_null("/root/FinanceManager")
	if finance == null or not finance.has_method("loan_payment"):
		return 0
	return int(finance.call("loan_payment", loan))


#Whole days to the next payment of any active loan; -1 when none is due.
func _soonest_loan_days() -> int:
	var best: int = -1
	for day: int in _loan_due_days():
		var away: int = maxi(0, day - _today())
		if best < 0 or away < best:
			best = away
	return best


#How many active loans make their next payment inside the window starting today.
func _loan_bills_in(days: int) -> int:
	var found: int = 0
	for day: int in _loan_due_days():
		if day < _today() + days:
			found += 1
	return found


func _loan_due_days() -> Array[int]:
	var out: Array[int] = []
	var finance: Node = get_node_or_null("/root/FinanceManager")
	if finance == null or not finance.has_method("next_due_minute"):
		return out
	for loan: Object in _active_loans():
		var minute: int = int(finance.call("next_due_minute", _field(loan, "id", -1)))
		if minute >= 0:
			out.append(TrynnCalendar.day_index(minute))
	return out


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


func _on_money_logged(delta: int, reason: String, label: String) -> void:
	record(delta, reason, label, GameState.logged_mode, GameState.logged_km)
