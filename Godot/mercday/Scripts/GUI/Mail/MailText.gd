class_name MailText

#Fills the {tokens} of a Mail.tsv subject or body for one delivered mail. A literal \n in a cell is a line break.

const NEWLINE_MARK: String = "\\n"


static func fill(text: String, mail: MailInstance) -> String:
	var out: String = text.replace(NEWLINE_MARK, "\n")
	if not out.contains("{"):
		return out
	var who: Object = MailCatalog.sender(mail.sender_id, mail.merc_uid)
	var merc: MercenaryData = GameState.merc_by_uid(mail.merc_uid)
	var values: Dictionary = {"merc": merc.merc_name if merc != null else "", "sender": _name_of(who),
		"amount": TransactionData.grouped(mail.bill.amount) if mail.bill != null else "",
		"date": _date_of(mail), "sub_amount": TransactionData.grouped(SubscriptionManager.monthly_cost()),
		"sub_due": GuiDates.short_text(GameState.day() + FinanceLedger.next_in(SubscriptionManager.BILL_DAY))}
	if mail.request != null:
		values["vac_start"] = GuiDates.short_text(mail.request.start_day)
		values["vac_end"] = GuiDates.short_text(mail.request.end_day())
		values["vac_days"] = str(mail.request.days)
		values["vac_in"] = str(mail.request.start_day - mail.received_day)
		values["vac_start_md"] = month_day(mail.request.start_day)
		values["vac_end_md"] = month_day(mail.request.end_day())
		values["vac_start_dm"] = day_month(mail.request.start_day)
		values["vac_end_dm"] = day_month(mail.request.end_day())
	return out.format(values, "{_}")


#"6/3": the month number, then the day.
static func month_day(day_index: int) -> String:
	var date: Dictionary = TrynnCalendar.date_of(day_index * CampaignClock.MINUTES_PER_DAY)
	return "%d/%d" % [int(date["month"]) + 1, int(date["day"])]


#"3/6": the day, then the month number.
static func day_month(day_index: int) -> String:
	var date: Dictionary = TrynnCalendar.date_of(day_index * CampaignClock.MINUTES_PER_DAY)
	return "%d/%d" % [int(date["day"]), int(date["month"]) + 1]


#A bill's due day, else the row's Due counted from the delivery day; "" when neither is set.
static func _date_of(mail: MailInstance) -> String:
	if mail.bill != null:
		return GuiDates.short_text(mail.bill.due_day) if mail.bill.due_day >= 0 else ""
	var due: int = int(MailCatalog.row(mail.def_id).get("due", -1))
	return GuiDates.short_text(mail.received_day + due) if due >= 0 else ""


static func _name_of(who: Object) -> String:
	if who is MercenaryData:
		return (who as MercenaryData).merc_name
	if who is ClientData:
		return (who as ClientData).name
	return ""
