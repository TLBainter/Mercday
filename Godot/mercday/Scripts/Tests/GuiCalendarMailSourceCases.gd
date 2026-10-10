class_name GuiCalendarMailSourceCases
extends RefCounted

#Calendar plan source cases 6 and 7: VacationSource and BillSource over stub rows in the live VacationBook and
#MailCenter. Run under --gui-calsource-tests.


#Case 6: live rows are bars, auto rows included; closed rows are not.
static func vacation(res: Dictionary) -> void:
	var saved: VacationBook = BenefitsManager.book
	var book := VacationBook.new()
	BenefitsManager.book = book
	var today: int = GameState.day()
	var states: Array[int] = [VacationRequest.State.PENDING, VacationRequest.State.APPROVED, VacationRequest.State.TAKEN,
		VacationRequest.State.DENIED, VacationRequest.State.REJECTED, VacationRequest.State.CANCELLED]
	var made: Array[VacationRequest] = []
	for i: int in states.size():
		made.append(_request(book, 9200 + i, today + i, states[i], StringName("m%d" % i)))
	var auto: VacationRequest = _request(book, 9210, today + 2, VacationRequest.State.APPROVED, &"")
	auto.auto = true
	var refs: Array = VacationSource.new().spans_between(today - 5, today + 20).map(func(span: Dictionary) -> Variant:
		return (span["event"] as CalendarEvent).ref)
	BenefitsManager.book = saved
	TestFixtures.check(res, "vacation spans include pending, approved and taken",
		refs.has(made[0]) and refs.has(made[1]) and refs.has(made[2]), "%d spans" % refs.size())
	TestFixtures.check(res, "an auto approved row with no mail is a span", refs.has(auto), "%d spans" % refs.size())
	TestFixtures.check(res, "denied, rejected and cancelled rows are skipped",
		not refs.has(made[3]) and not refs.has(made[4]) and not refs.has(made[5]) and refs.size() == 4,
		"%d spans" % refs.size())


#Case 7: a mail-native bill is an event on its due day with its status; an AUTO notice is not.
static func bill(res: Dictionary) -> void:
	var due: int = GameState.day() + 3
	var unpaid: Bill = _bill(&"cal_unpaid", due, Bill.Status.UNPAID)
	var auto: Bill = _bill(&"cal_auto", due, Bill.Status.AUTO)
	var events: Array[CalendarEvent] = BillSource.new().events_between(due - 1, due + 1)
	MailCenter._bills.erase(unpaid.bill_id)
	MailCenter._bills.erase(auto.bill_id)
	var own: Array[CalendarEvent] = GuiCalendarSourceTests.of(events, unpaid)
	TestFixtures.check(res, "an unpaid mail bill is an event on its due day", own.size() == 1 and own[0].day == due,
		"%d events" % own.size())
	TestFixtures.check(res, "the bill event sub reads its status", own.size() == 1 and own[0].sub.ends_with(" - Unpaid"),
		str(own.map(GuiCalendarSourceTests.sub_of)))
	TestFixtures.check(res, "an AUTO mail bill gives no event", GuiCalendarSourceTests.of(events, auto).is_empty(),
		"%d events" % events.size())


static func _request(book: VacationBook, uid: int, start: int, state: int, mail: StringName) -> VacationRequest:
	var req := VacationRequest.new()
	req.merc_uid = uid
	req.start_day = start
	req.days = 3
	req.state = state
	req.mail_id = mail
	book.rows.append(req)
	return req


static func _bill(id: StringName, due: int, status: int) -> Bill:
	var stub := Bill.new()
	stub.bill_id = id
	stub.mail_id = id
	stub.amount = 250
	stub.due_day = due
	stub.status = status
	MailCenter._bills[id] = stub
	return stub
