class_name BillSource extends CalendarSource

#The mail's own bills: one event per UNPAID or PAID bill on its due day. AUTO bills are ledger notices that
#LedgerBillSource draws, so they are skipped. A click closes the calendar and opens the bill's mail in the Inbox.


func events_between(d0: int, d1: int) -> Array[CalendarEvent]:
	var out: Array[CalendarEvent] = []
	for bill: Bill in MailCenter.bills_between(d0, d1):
		if bill.status == Bill.Status.AUTO:
			continue
		var mail: MailInstance = MailCenter.get_mail(bill.mail_id)
		var title: String = "Bill"
		if mail != null:
			title = MailText.fill(String(MailCatalog.row(mail.def_id).get("subject", "")), mail)
		var sub: String = "%s notes - %s" % [TransactionData.grouped(bill.amount), BillBlock.STATUS_TEXTS[bill.status]]
		out.append(make_event(bill.due_day, title, sub, bill))
	return out


func activate(event: CalendarEvent, dialog: Node) -> void:
	var bill: Bill = event.ref as Bill if event != null else null
	if bill == null:
		return
	var calendar: CalendarDialog = dialog as CalendarDialog
	if calendar != null and calendar.is_open():
		calendar.close()
	MailCenter.request_open(bill.mail_id)


func change_signals() -> Array[Signal]:
	return [MailCenter.changed]
