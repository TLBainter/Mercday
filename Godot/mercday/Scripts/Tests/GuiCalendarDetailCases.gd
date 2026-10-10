class_name GuiCalendarDetailCases
extends RefCounted

#Cases 8-10, 17 and 18 of --gui-calendar-tests: DayDetail, the long date width, the returning crew tooltip and OrderDialog.

#The board entry and order id of the fixtures; no posting or order uses it.
const ENTRY: int = 9200


static func run_cases(res: Dictionary, host: Node, dialog: CalendarDialog) -> void:
	var today: int = GameState.day()
	var coming := OrderData.new()
	coming.id = ENTRY
	coming.placed_day = today
	coming.days = 4
	var landed := OrderData.new()
	landed.id = ENTRY + 1
	landed.placed_day = today - 6
	landed.days = 3
	BazaarManager.orders.append(coming)
	BazaarManager.orders.append(landed)
	var run: ActiveRun = _run()
	var done: ContractResultData = _result(today - 2)
	GameState.active_contracts[ENTRY] = run
	GameState.results[ENTRY] = done
	_detail(res, dialog, today)
	await _long_date(res, host, dialog, today)
	await _tooltip(res, host, dialog, run, done)
	_order(res, dialog, coming, landed)
	await _filtered(res, host, dialog, coming)
	BazaarManager.orders.erase(coming)
	BazaarManager.orders.erase(landed)
	GameState.active_contracts.erase(ENTRY)
	GameState.results.erase(ENTRY)
	dialog.open_on(today)


static func _detail(res: Dictionary, dialog: CalendarDialog, today: int) -> void:
	var on_day: int = today + 4
	dialog.open_on(on_day)
	var listed: Array = dialog.events.by_day(on_day, on_day).get(on_day, [])
	var want: Array = listed.map(func(e: CalendarEvent) -> String: return e.title)
	var shown: Array = dialog.detail.rows().map(func(r: EventRow) -> String: return r.title_text())
	TestFixtures.check(res, "DayDetail rows match by_day for the selected day", not want.is_empty() and shown == want,
		"%s vs %s" % [str(shown), str(want)])
	var heading: String = TrynnCalendar.date_text(on_day * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "the DayDetail heading is the date text", dialog.detail.head.caption == heading,
		"%s vs %s" % [dialog.detail.head.caption, heading])
	for pair: Array in [[today - 3, "3 Days Ago"], [today, "Today"], [today + 4, "4 Days From Now"]]:
		dialog.open_on(int(pair[0]))
		var text: String = dialog.detail.head.count_text
		TestFixtures.check(res, "the relative text reads %s" % pair[1], text == String(pair[1]), text)


static func _long_date(res: Dictionary, host: Node, dialog: CalendarDialog, today: int) -> void:
	dialog.open_on(today + 4)
	await host.get_tree().process_frame
	var column: Control = dialog.detail.get_parent() as Control
	var box_before: float = dialog.box.get_global_rect().size.x
	var column_before: float = column.size.x
	var longest: int = today
	for day: int in range(today, today + 91):
		if _date(day).length() > _date(longest).length():
			longest = day
	dialog.open_on(longest)
	await host.get_tree().process_frame
	var box_rect: Rect2 = dialog.box.get_global_rect()
	var spill: String = GuiFrameTests._outside(dialog.box, dialog.box, box_rect)
	var label: Label = dialog.detail.head.caption_label
	TestFixtures.check(res, "the longest date leaves the box at 1088 and the detail column width unchanged",
		box_before == 1088.0 and box_rect.size.x == 1088.0 and column.size.x == column_before and spill == ""
		and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and label.text == _date(longest),
		"%s: box %.0f to %.0f column %.0f to %.0f %s" % [_date(longest), box_before, box_rect.size.x, column_before,
		column.size.x, spill])


static func _date(day: int) -> String:
	return TrynnCalendar.date_text(day * TrynnCalendar.MINUTES_PER_DAY)


static func _tooltip(res: Dictionary, host: Node, dialog: CalendarDialog, run: ActiveRun, done: ContractResultData) -> void:
	var tip: ReturningCrewTooltip = dialog.crew_tip
	var live_of: Callable = func() -> int: return tip.crew.columns.get_children().filter(
		func(c: Control) -> bool: return c.mouse_filter != Control.MOUSE_FILTER_IGNORE).size()
	var row: EventRow = await _hover(host, dialog, TrynnCalendar.day_index(run.return_minute()), run)
	var tip_rect: Rect2 = tip.get_global_rect()
	TestFixtures.check(res, "contract row hover shows the crew tooltip left of the panel", row != null and tip.visible
		and tip_rect.end.x <= dialog.detail.global_position.x and tip.title_label.text == ReturningCrewTooltip.RUN_TITLE,
		"row %s tip %s panel x %.0f" % [row != null, tip_rect, dialog.detail.global_position.x])
	TestFixtures.check(res, "the tooltip holds one ActiveCrew column per member", run.team.size() == 2
		and tip.crew.portrait_count() == run.team.size(), "%d columns" % tip.crew.portrait_count())
	var live: int = int(live_of.call())
	if row != null:
		row.mouse_exited.emit()
	TestFixtures.check(res, "leaving the row hides the tooltip", row != null and not tip.visible, "")
	row = await _hover(host, dialog, TrynnCalendar.day_index(done.closed_minute), done)
	TestFixtures.check(res, "a past return row shows the settled crew under Crew", row != null and tip.visible
		and tip.title_label.text == ReturningCrewTooltip.RESULT_TITLE and tip.crew.caption_label.text
		== ActiveCrew.SETTLED_CAPTION and tip.crew.portrait_count() == done.members.size(),
		"caption %s columns %d" % [tip.crew.caption_label.text, tip.crew.portrait_count()])
	live += int(live_of.call())
	TestFixtures.check(res, "every hosted column ignores the mouse", tip.crew.portrait_count() > 0 and live == 0,
		"%d take the mouse" % live)
	tip.hide_tip()


static func _order(res: Dictionary, dialog: CalendarDialog, coming: OrderData, landed: OrderData) -> void:
	var orders: OrderDialog = dialog.order_dialog
	var titles: Array[String] = []
	for order: OrderData in [coming, landed]:
		dialog.open_on(order.placed_day + order.days)
		var row: EventRow = _find(dialog, order)
		if row != null:
			row.pressed.emit()
		titles.append(orders.title_text() if orders.is_open() and orders.card.order_id() == order.id else "")
		if orders.is_open():
			orders.close()
	TestFixtures.check(res, "a delivery row click opens OrderDialog on its order", titles[0] != "" and titles[1] != "", str(titles))
	TestFixtures.check(res, "OrderDialog reads Expected Delivery, then Delivered Order",
		titles == [OrderDialog.EXPECTED_TITLE, OrderDialog.DELIVERED_TITLE], str(titles))


static func _filtered(res: Dictionary, host: Node, dialog: CalendarDialog, coming: OrderData) -> void:
	dialog.open_on(coming.placed_day + coming.days)
	var type: StringName = &"delivery"
	var before: bool = _find(dialog, coming) != null
	var row: FilterCheckRow = dialog.filter.rows.get(type, null)
	if row != null:
		row.button_pressed = false
	await host.get_tree().process_frame
	var kinds: Array = dialog.detail.rows().map(func(r: EventRow) -> StringName: return r.event.source.type)
	TestFixtures.check(res, "an unchecked type is also missing from DayDetail", row != null and before
		and not kinds.has(type), "before %s kinds %s" % [before, str(kinds)])
	if row != null:
		row.button_pressed = true


static func _hover(host: Node, dialog: CalendarDialog, day: int, ref: Variant) -> EventRow:
	dialog.open_on(day)
	await host.get_tree().process_frame
	var row: EventRow = _find(dialog, ref)
	if row != null:
		row.mouse_entered.emit()
	await host.get_tree().process_frame
	return row


static func _find(dialog: CalendarDialog, ref: Variant) -> EventRow:
	for row: EventRow in dialog.detail.rows():
		if is_same(row.event.ref, ref):
			return row
	return null


static func _run() -> ActiveRun:
	var run := ActiveRun.new()
	run.entry_id = ENTRY
	run.hours = 50.0
	run.depart_minute = CampaignClock.now()
	for uid: int in GameState.roster_uids().slice(0, 2):
		var member := TeamMember.new()
		member.merc_uid = uid
		run.team.append(member)
	return run


static func _result(on_day: int) -> ContractResultData:
	var done := ContractResultData.new()
	done.entry_id = ENTRY
	done.name = "Calendar Detail Closed"
	done.closed_minute = on_day * TrynnCalendar.MINUTES_PER_DAY + 600
	for i: int in 3:
		var member := ResultMemberData.new()
		member.uid = ENTRY + i
		member.name = "Member %d" % i
		done.members.append(member)
	return done
