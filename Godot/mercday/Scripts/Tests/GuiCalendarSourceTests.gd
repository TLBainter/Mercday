class_name GuiCalendarSourceTests
extends RefCounted

#CalendarEvents and the calendar sources over the live services they read; cases 5 and 8-10 sit in GuiCalendarSourceCases,
#cases 6-7 in GuiCalendarMailSourceCases. Run with --gui-calsource-tests after the harness separator.

#An order id no Bazaar order uses; the delivery case adds and removes it.
const ORDER: int = 9100
const DIALOG_SCENE: String = "res://Scenes/GUI/Calendar/CalendarDialog.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	NotificationCenter.reset()
	StockMarket.reset()
	await host.get_tree().process_frame
	_case_dividend(res)
	_case_loan(res)
	_case_delivery(res)
	_case_return_minute(res)
	GuiCalendarSourceCases.contract(res)
	GuiCalendarMailSourceCases.vacation(res)
	GuiCalendarMailSourceCases.bill(res)
	GuiCalendarSourceCases.ledger(res)
	GuiCalendarSourceCases.by_day(res)
	GuiCalendarSourceCases.watch(res)
	_case_scene(res)
	StockMarket.reset()
	FinanceManager.reset()
	return TestFixtures.summarize(res, "GUI CALSOURCE")


static func _case_dividend(res: Dictionary) -> void:
	var source := DividendSource.new()
	var events: Array[CalendarEvent] = source.events_between(0, 89)
	TestFixtures.check(res, "dividend only on day 45 in 0..89", events.size() == 1 and events[0].day == 45,
		str(events.map(func(e: CalendarEvent) -> int: return e.day)))
	GameState.bank_notes = 100000
	StockMarket.buy(1, 10)
	var want: String = "Estimated %s notes" % TransactionData.grouped(StockMarket.dividend_estimate())
	var sub: String = source.events_between(45, 45)[0].sub
	TestFixtures.check(res, "dividend sub reads the estimate", StockMarket.dividend_estimate() > 0 and sub == want,
		"%s vs %s" % [sub, want])
	StockMarket.reset()
	want = "All %d companies pay shareholders" % StockMarket.company_count()
	sub = source.events_between(45, 45)[0].sub
	TestFixtures.check(res, "dividend sub generic with no shares", sub == want, "%s vs %s" % [sub, want])


static func _case_loan(res: Dictionary) -> void:
	var loan: LoanData = TestFixtures.add_loan("Lender 1", 900, 0.1, 3, 15)
	loan.paid = 1
	var today: int = GameState.day()
	var events: Array[CalendarEvent] = of(LoanSource.new().events_between(today - 400, today + 400), loan)
	TestFixtures.check(res, "loan of 3 months gives 3 events", events.size() == 3, "%d" % events.size())
	var days: Array = events.map(func(e: CalendarEvent) -> int: return dom(e.day))
	TestFixtures.check(res, "loan events all on the 15th", days == [15, 15, 15], str(days))
	var subs: Array = events.map(sub_of)
	TestFixtures.check(res, "loan paid row reads Paid", subs.size() == 3 and String(subs[0]).ends_with(" - Paid"),
		str(subs))
	TestFixtures.check(res, "loan future row reads Payment k of n",
		subs.size() == 3 and String(subs[1]).ends_with(" - Payment 2 of 3"), str(subs))
	FinanceManager.reset()


static func _case_delivery(res: Dictionary) -> void:
	var old := OrderData.new()
	old.id = ORDER
	old.placed_day = 10
	old.days = 3
	var fresh := OrderData.new()
	fresh.id = ORDER + 1
	fresh.placed_day = GameState.day()
	fresh.days = 3
	BazaarManager.orders.append(old)
	BazaarManager.orders.append(fresh)
	var source := DeliverySource.new()
	var landed: Array[CalendarEvent] = of(source.events_between(0, 20), old)
	TestFixtures.check(res, "delivery placed 10 for 3 days lands on 13", landed.size() == 1 and landed[0].day == 13,
		"%d events" % landed.size())
	var coming: Array[CalendarEvent] = of(source.events_between(fresh.placed_day, fresh.placed_day + 5), fresh)
	TestFixtures.check(res, "delivery title expected before",
		coming.size() == 1 and coming[0].title == "Order #%d expected" % fresh.id, str(coming.map(title_of)))
	TestFixtures.check(res, "delivery title delivered after",
		landed.size() == 1 and landed[0].title == "Order #%d delivered" % old.id, str(landed.map(title_of)))
	BazaarManager.orders.erase(old)
	BazaarManager.orders.erase(fresh)


static func _case_return_minute(res: Dictionary) -> void:
	var trip := ActiveRun.new()
	trip.hours = 30.0
	trip.depart_minute = 5000
	trip.dispatched_minute = 4000
	TestFixtures.check(res, "return_minute is depart plus hours", trip.return_minute() == 6800,
		"%d" % trip.return_minute())
	trip.depart_minute = -1
	TestFixtures.check(res, "return_minute falls back to dispatch", trip.return_minute() == 5800,
		"%d" % trip.return_minute())
	trip.dispatched_minute = -1
	var want: int = CampaignClock.now() + 1800
	TestFixtures.check(res, "return_minute falls back to now", trip.return_minute() == want,
		"%d vs %d" % [trip.return_minute(), want])


#The sources on CalendarDialog.tscn: each has a type, and only BillSource and LedgerBillSource share one.
static func _case_scene(res: Dictionary) -> void:
	var dialog: CalendarDialog = (load(DIALOG_SCENE) as PackedScene).instantiate() as CalendarDialog
	var by_type: Dictionary = {}
	var blank: int = 0
	for source: CalendarSource in dialog.sources:
		blank += 1 if source.type == &"" else 0
		var names: Array = by_type.get(source.type, [])
		names.append(String((source.get_script() as Script).get_global_name()))
		by_type[source.type] = names
	var count: int = dialog.sources.size()
	dialog.free()
	TestFixtures.check(res, "every dialog source has a type", count > 0 and blank == 0, "%d sources, %d blank" % [count, blank])
	var wrong: Array = []
	for names: Array in by_type.values():
		names.sort()
		if names.size() > 1 and names != ["BillSource", "LedgerBillSource"]:
			wrong.append(names)
	TestFixtures.check(res, "only BillSource and LedgerBillSource share a type", wrong.is_empty(), str(wrong))


#The events whose ref is the given record.
static func of(events: Array[CalendarEvent], ref: Variant) -> Array[CalendarEvent]:
	var out: Array[CalendarEvent] = []
	for event: CalendarEvent in events:
		if is_same(event.ref, ref):
			out.append(event)
	return out


#Day of the month of a day index.
static func dom(day: int) -> int:
	return int(TrynnCalendar.date_of(day * TrynnCalendar.MINUTES_PER_DAY)["day"])


static func title_of(event: CalendarEvent) -> String:
	return event.title


static func sub_of(event: CalendarEvent) -> String:
	return event.sub
