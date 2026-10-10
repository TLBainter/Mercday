class_name LedgerBillSource extends CalendarSource

#The recurring bills of the books: payroll, the subscription and the guild bill on their days of the
#month, the promotion bills still to come and every fine on its due day. Loans keep their own source.

#FinanceLedger.BILL_DAYS key, then the title of its event.
const MONTHLY: Array[Array] = [["payroll", GameState.LABEL_PAYROLL],
	["subscription", FinanceLedger.SUBSCRIPTION_LABEL], ["guild", FinanceLedger.GUILD_LABEL]]


func events_between(d0: int, d1: int) -> Array[CalendarEvent]:
	var out: Array[CalendarEvent] = []
	var amounts: Dictionary = {}
	for bill: Array in MONTHLY:
		amounts[bill[0]] = monthly_amount(String(bill[0]))
	for day: int in range(d0, d1 + 1):
		var dom: int = int(TrynnCalendar.date_of(day * TrynnCalendar.MINUTES_PER_DAY)["day"])
		for bill: Array in MONTHLY:
			var key: String = bill[0]
			var amount: int = int(amounts[key])
			if dom == int(FinanceLedger.BILL_DAYS[key]) and amount > 0:
				out.append(make_event(day, String(bill[1]), _notes(amount), {"key": key, "amount": amount}))
	var start: int = maxi(d0, GameState.day())
	for row: Dictionary in PromotionsManager.ad_bill_days(start, d1 + 1 - start):
		out.append(make_event(int(row["day"]), "Promotion - %s" % PromotionsManager.campaign_name(
			int(row["campaign_id"])), _notes(int(row["amount"])), row))
	for fine: FineData in LegalManager.fines:
		if within(fine.day_due, d0, d1):
			out.append(make_event(fine.day_due, "Fine - %s" % fine.crime, "%s - %s" % [
				_notes(LegalManager.fine_due(fine)), "Paid" if fine.is_paid() else "Unpaid"], fine))
	return out


#What one monthly bill comes to at today's books.
static func monthly_amount(key: String) -> int:
	match key:
		"payroll":
			return FinanceLedger.payroll()
		"subscription":
			return SubscriptionManager.monthly_cost()
		"guild":
			return FinanceLedger.guild_rate()
	return 0


static func _notes(amount: int) -> String:
	return "%s notes" % TransactionData.grouped(amount)


func change_signals() -> Array[Signal]:
	return [FinanceLedger.changed, LegalManager.fines_changed, PromotionsManager.campaigns_changed]
