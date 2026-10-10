class_name GuiCalendarCases
extends RefCounted

#Cases 6-7, 12-14 and 16 of --gui-calendar-tests; GuiCalendarTests runs them.


static func cell_icons(res: Dictionary) -> void:
	var events: Array[CalendarEvent] = []
	for i: int in 5:
		var source := CalendarSource.new()
		source.type = StringName("t%d" % i)
		source.icon_id = "coin"
		events.append(source.make_event(10, "e%d" % i, "", null))
		events.append(source.make_event(10, "again%d" % i, "", null))
	var cell := DayCell.new()
	cell.size = MonthGrid.CELL_SIZE
	cell.show_day(10, 30, 0, false, events)
	var plus: Rect2 = cell.more_rect()
	var fits: bool = Rect2(Vector2.ZERO, cell.size).encloses(plus) and not plus.intersects(cell.number_rect())
	TestFixtures.check(res, "a day cell shows at most 3 icons then a +N that fits beside the number",
		cell.shown_icons.size() == 3 and cell.more_text() == "+2" and fits,
		"%d icons, %s at %s" % [cell.shown_icons.size(), cell.more_text(), plus])
	cell.free()


static func week_bars(res: Dictionary, host: Node) -> void:
	var bars := WeekBars.new()
	host.add_child(bars)
	bars.size = Vector2(MonthGrid.CELL_SIZE.x * 10.0 + MonthGrid.GAP * 9.0, MonthGrid.CELL_SIZE.y)
	var single: Array[Dictionary] = [_span(1, 2, 3)]
	bars.show_spans(single, 0, 10, 0)
	var one: Dictionary = bars.bars[0] if bars.bars.size() == 1 else {}
	var wide: float = bars.column_width() * 3.0 + MonthGrid.GAP * 2.0
	TestFixtures.check(res, "a 3-day span draws in lane 0", int(one.get("lane", -1)) == 0
		and is_equal_approx((one["rect"] as Rect2).size.x, wide), str(one))
	var four: Array[Dictionary] = [_span(1, 0, 5), _span(2, 1, 5), _span(3, 2, 5), _span(4, 3, 5)]
	bars.show_spans(four, 0, 10, 0)
	var lane_one: Rect2 = _lane_rect(bars, 1)
	var lane_two: Rect2 = _lane_rect(bars, 2)
	TestFixtures.check(res, "lane 2 starts half a lane above the bottom of lane 1",
		lane_one.size.y > 0.0 and is_equal_approx(lane_two.position.y, lane_one.end.y - WeekBars.LANE_H / 2.0),
		"%s %s" % [lane_one, lane_two])
	var lanes: Array = bars.bars.map(func(bar: Dictionary) -> int: return int(bar["lane"]))
	TestFixtures.check(res, "four overlapping spans fill lanes 0-3", lanes == [0, 1, 2, 3] and bars.more == 0, str(lanes))
	four.append(_span(5, 4, 2))
	bars.show_spans(four, 0, 10, 0)
	TestFixtures.check(res, "a fifth overlapping span draws as a +N chip at the row end", bars.bars.size() == 4
		and bars.more_text() == "+1" and is_equal_approx(bars.chip_rect.end.x, bars.size.x) and bars.chip_rect.size.x > 0.0,
		"%d bars %s chip %s" % [bars.bars.size(), bars.more_text(), bars.chip_rect])
	bars.show_spans([_span(1, 1, 10), _span(2, 1, 3), _span(3, 2, 7), _span(4, 4, 3)] as Array[Dictionary], 0, 10, 0)
	var order: Array = bars.bars.map(func(bar: Dictionary) -> int: return int(bar["lane"]))
	var hits: Array = [3, 5].map(func(day: int) -> int: return int(bars.bar_at(Vector2(day * (bars.column_width()
		+ bars.cell_gap) + bars.column_width() / 2.0, bars.lane_top(2) + 3.0)).get("uid", 0)))
	TestFixtures.check(res, "a higher lane paints over the lane before and takes the click in their shared strip",
		order == [0, 1, 1, 2] and hits == [3, 3], "lanes %s hits %s" % [str(order), str(hits)])
	bars.free()


static func filter(res: Dictionary, host: Node, dialog: CalendarDialog) -> void:
	dialog.open_on(GameState.day())
	var listed: Dictionary = dialog.events.by_day(dialog.grid.first_day, dialog.grid.first_day + dialog.grid.day_count - 1)
	var source: CalendarSource = null
	for day: int in listed:
		source = (listed[day] as Array[CalendarEvent])[0].source
		break
	var icon_id: String = source.icon_id if source != null else ""
	var row: FilterCheckRow = dialog.filter.rows.get(source.type if source != null else &"", null)
	var before: int = _cells_with(dialog, icon_id)
	if row != null:
		row.button_pressed = false
	await host.get_tree().process_frame
	var hidden: int = _cells_with(dialog, icon_id)
	TestFixtures.check(res, "unchecking a filter hides the type from the grid", row != null and before > 0 and hidden == 0,
		"%s before %d after %d" % [icon_id, before, hidden])
	if row != null:
		row.button_pressed = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "re-checking the filter restores the type", _cells_with(dialog, icon_id) == before,
		"%d vs %d" % [_cells_with(dialog, icon_id), before])
	var types: Array[StringName] = []
	for each: CalendarSource in dialog.sources:
		if not types.has(each.type):
			types.append(each.type)
	TestFixtures.check(res, "one filter row per distinct type", dialog.filter.get_child_count() == types.size()
		and dialog.filter.rows.size() == types.size(), "%d rows %d types" % [dialog.filter.get_child_count(), types.size()])


static func day_moves(res: Dictionary, host: Node, dialog: CalendarDialog) -> void:
	dialog.open_on(GameState.day())
	var was: int = GameState.day()
	TestFixtures.pass_days(1)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var now_cell: DayCell = dialog.grid.cell_of(was + 1)
	TestFixtures.check(res, "day_changed while open moves the Today chip", now_cell != null and now_cell.is_today
		and not dialog.grid.cell_of(was).is_today, "today %d" % GameState.day())


static func layout(res: Dictionary, host: Node, dialog: CalendarDialog) -> void:
	dialog.open_on(GameState.day())
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var band := Rect2(Vector2.ZERO, Vector2(view.x, view.y - GuiCalendarTests.RESERVE))
	var box_rect: Rect2 = dialog.box.get_global_rect()
	TestFixtures.check(res, "the dialog sits inside the band", view == Vector2(1280, 720) and band.encloses(box_rect),
		"%s in %s" % [box_rect, band])
	var spill: String = GuiFrameTests._outside(dialog.box, dialog.box, box_rect)
	TestFixtures.check(res, "no child overflows the dialog box", spill == "", spill)
	var pad: MarginContainer = dialog.box.get_node(^"Pad") as MarginContainer
	var margins: Array = ["left", "top", "right", "bottom"].map(
		func(side: String) -> int: return pad.get_theme_constant(StringName("margin_" + side)))
	TestFixtures.check(res, "the dialog pads its content by 14 px", margins == [14, 14, 14, 14]
		and dialog.rows.position.is_equal_approx(Vector2(14, 14)), "%s at %s" % [str(margins), dialog.rows.position])
	var backdrop_end: float = dialog.backdrop.get_global_rect().end.y
	TestFixtures.check(res, "with bottom_reserve 76 the backdrop ends 76 px above the viewport bottom",
		is_equal_approx(backdrop_end, view.y - GuiCalendarTests.RESERVE), "%.1f" % backdrop_end)


static func requested(res: Dictionary, host: Node, dialog: CalendarDialog) -> void:
	dialog.close()
	var day: int = GameState.day() + 60
	GameState.open_calendar(day)
	await host.get_tree().process_frame
	var date: Dictionary = TrynnCalendar.date_of(day * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "open_calendar_requested opens the dialog on that day's month", dialog.is_open()
		and dialog.shown_year == int(date["year"]) and dialog.shown_month == int(date["month"]),
		"open %s %d/%d" % [dialog.is_open(), dialog.shown_year, dialog.shown_month])
	var cell: DayCell = dialog.grid.cell_of(day)
	TestFixtures.check(res, "open_calendar_requested selects that day", dialog.selected_day == day and cell != null
		and cell.selected, "selected %d" % dialog.selected_day)


static func _span(uid: int, start: int, days: int) -> Dictionary:
	return {"uid": uid, "name": "Merc %d" % uid, "start": start, "days": days, "state": VacationRequest.State.APPROVED}


static func _lane_rect(bars: WeekBars, lane: int) -> Rect2:
	for bar: Dictionary in bars.bars:
		if int(bar["lane"]) == lane:
			return bar["rect"]
	return Rect2()


static func _cells_with(dialog: CalendarDialog, icon_id: String) -> int:
	var count: int = 0
	for cell: DayCell in dialog.grid.filled_cells():
		count += 1 if cell.shown_icons.has(icon_id) else 0
	return count
