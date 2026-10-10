class_name GuiCalendarSourceCases
extends RefCounted

#Cases 5 and 8-10 of --gui-calsource-tests: contract returns, ledger bills and the CalendarEvents collector.

const STUB_TYPE: StringName = &"calsource_stub"
#A board entry id no posting uses; the contract case adds and removes it.
const ENTRY: int = 9100


#A source with one bar and events on fixed days; poked stands for a service signal.
class StubSource extends CalendarSource:
	signal poked(n: int)
	var on_days: Array[int] = []

	func events_between(_d0: int, _d1: int) -> Array[CalendarEvent]:
		var out: Array[CalendarEvent] = []
		for d: int in on_days:
			out.append(make_event(d, "Stub", "", null))
		return out

	func spans_between(d0: int, _d1: int) -> Array[Dictionary]:
		return [{"uid": 1, "name": "Stub", "start": d0, "days": 2, "state": 0}]

	func change_signals() -> Array[Signal]:
		return [poked, poked]


static func contract(res: Dictionary) -> void:
	var view := ContractView.new()
	view.entry_id = ENTRY
	view.name = "Calsource Test Contract"
	GameState.contracts.append(view)
	var run := ActiveRun.new()
	run.entry_id = ENTRY
	run.hours = 50.0
	run.depart_minute = CampaignClock.now()
	for uid: int in [1, 2]:
		var member := TeamMember.new()
		member.merc_uid = uid
		run.team.append(member)
	GameState.active_contracts[ENTRY] = run
	var due: int = TrynnCalendar.day_index(run.return_minute())
	var source := ContractSource.new()
	var events: Array[CalendarEvent] = GuiCalendarSourceTests.of(source.events_between(due, due), run)
	TestFixtures.check(res, "contract run returns on its return day", events.size() == 1
		and events[0].title == "2 mercs return", str(events.map(GuiCalendarSourceTests.title_of)))
	TestFixtures.check(res, "contract sub names the posting", events.size() == 1
		and events[0].sub == "Calsource Test Contract - estimated", str(events.map(GuiCalendarSourceTests.sub_of)))
	run.dispatched_minute = GameState.day() * TrynnCalendar.MINUTES_PER_DAY + 22 * 60
	run.depart_minute = ContractScheduler.next_wake_minute(run.dispatched_minute)
	GameState.queued[ENTRY] = run
	due = TrynnCalendar.day_index(run.depart_minute + 50 * 60)
	events = GuiCalendarSourceTests.of(source.events_between(due - 5, due + 5), run)
	TestFixtures.check(res, "contract night run listed once", events.size() == 1 and events[0].day == due
		and events[0].sub.ends_with("queued, estimated"), str(events.map(GuiCalendarSourceTests.sub_of)))
	var done := ContractResultData.new()
	done.entry_id = ENTRY
	done.name = "Calsource Closed"
	done.closed_minute = 0
	GameState.results[ENTRY] = done
	events = GuiCalendarSourceTests.of(source.events_between(0, 0), done)
	TestFixtures.check(res, "contract result past on its close day", events.size() == 1 and events[0].past
		and events[0].day == 0 and events[0].title == "Calsource Closed", str(events.map(GuiCalendarSourceTests.title_of)))
	done.preview = true
	events = GuiCalendarSourceTests.of(source.events_between(0, 0), done)
	TestFixtures.check(res, "contract preview result left out", events.is_empty(), "%d" % events.size())
	GameState.contracts.erase(view)
	GameState.active_contracts.erase(ENTRY)
	GameState.queued.erase(ENTRY)
	GameState.results.erase(ENTRY)


static func ledger(res: Dictionary) -> void:
	var source := LedgerBillSource.new()
	var first: int = GameState.day() - GuiCalendarSourceTests.dom(GameState.day()) + 1
	var events: Array[CalendarEvent] = source.events_between(first, first + 29)
	var pay_day: int = first + int(FinanceLedger.BILL_DAYS["payroll"]) - 1
	var guild_day: int = first + int(FinanceLedger.BILL_DAYS["guild"]) - 1
	var payroll: bool = events.any(func(e: CalendarEvent) -> bool:
		return e.day == pay_day and e.title == GameState.LABEL_PAYROLL)
	var guild: bool = events.any(func(e: CalendarEvent) -> bool:
		return e.day == guild_day and e.title == FinanceLedger.GUILD_LABEL)
	TestFixtures.check(res, "ledger payroll and guild on their bill days", payroll and guild,
		str(events.map(GuiCalendarSourceTests.title_of)))
	var fine: FineData = LegalManager.add_fine(1, "Calsource Theft", [] as Array[int], -1, 40, 6)
	events = GuiCalendarSourceTests.of(source.events_between(fine.day_due, fine.day_due), fine)
	TestFixtures.check(res, "ledger fine on its due day", events.size() == 1 and events[0].day == fine.day_due,
		str(events.map(GuiCalendarSourceTests.title_of)))
	LegalManager.fines.erase(fine)
	TestFixtures.add_loan("Lender 1", 900, 0.1, 3, 15)
	events = source.events_between(GameState.day() - 120, GameState.day() + 120)
	var loans: bool = events.any(func(e: CalendarEvent) -> bool:
		return e.ref is LoanData or e.title.begins_with("Loan"))
	var watched: bool = source.change_signals().has(PromotionsManager.campaigns_changed)
	TestFixtures.check(res, "ledger leaves loans to their source and watches campaigns", not events.is_empty()
		and not loans and watched, "watched %s %s" % [watched, str(events.map(GuiCalendarSourceTests.title_of))])
	FinanceManager.reset()


static func by_day(res: Dictionary) -> void:
	var stub := StubSource.new()
	stub.type = STUB_TYPE
	stub.on_days = [3, 10, 20, 40]
	var sources: Array[CalendarSource] = [stub]
	var collector := CalendarEvents.new(sources)
	var keys: Array = collector.by_day(10, 30).keys()
	keys.sort()
	TestFixtures.check(res, "by_day keeps only days in range", keys == [10, 20], str(keys))
	var had_events: bool = not collector.by_day(0, 50).is_empty()
	var had_spans: bool = collector.spans(0, 50).size() == 1
	CalendarEvents.set_enabled(STUB_TYPE, false)
	TestFixtures.check(res, "by_day drops a filtered type", had_events and collector.by_day(0, 50).is_empty(),
		"before %s" % had_events)
	TestFixtures.check(res, "spans drop a filtered type", had_spans and collector.spans(0, 50).is_empty(),
		"before %s" % had_spans)
	CalendarEvents.set_enabled(STUB_TYPE, true)


static func watch(res: Dictionary) -> void:
	var stub := StubSource.new()
	stub.type = STUB_TYPE
	var sources: Array[CalendarSource] = [stub]
	var collector := CalendarEvents.new(sources)
	var hits: Array[int] = [0]
	collector.changed.connect(func() -> void: hits[0] += 1)
	collector.watch(true)
	stub.poked.emit(1)
	TestFixtures.check(res, "watch relays a change once", hits[0] == 1, "%d" % hits[0])
	collector.watch(false)
	stub.poked.emit(2)
	TestFixtures.check(res, "watch false stops the relay", hits[0] == 1, "%d" % hits[0])
