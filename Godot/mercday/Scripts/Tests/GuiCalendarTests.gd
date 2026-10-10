class_name GuiCalendarTests
extends RefCounted

#The calendar dialog over a live TimeMenu; cases 6-7, 12-14 and 16 sit in GuiCalendarCases, 8-10, 17 and 18 in
#GuiCalendarDetailCases, 11 and 15 in GuiCalendarMailCases, case 1 and the help tags in GuiCalendarHelpCases.
#Run with --gui-calendar-tests after the separator.

const MENU_SCENE: String = "res://Scenes/GUI/HUD/TimeMenu.tscn"
const RESERVE: float = 76.0


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	NotificationCenter.reset()
	StockMarket.reset()
	var reserve: float = GuiFrameStack.bottom_reserve
	GuiFrameStack.bottom_reserve = RESERVE
	var menu: TimeMenu = (load(MENU_SCENE) as PackedScene).instantiate() as TimeMenu
	host.add_child(menu)
	await host.get_tree().process_frame
	GuiCalendarHelpCases.button(res, menu)
	await _case_open_close(res, host, menu.calendar_button())
	var dialog: CalendarDialog = menu.calendar_button().dialog()
	_case_grid(res, dialog)
	_case_today(res, dialog)
	_case_nav(res, dialog)
	GuiCalendarCases.cell_icons(res)
	GuiCalendarCases.week_bars(res, host)
	await GuiCalendarMailCases.bill_row(res, host, dialog)
	await GuiCalendarCases.filter(res, host, dialog)
	await GuiCalendarCases.day_moves(res, host, dialog)
	await GuiCalendarCases.layout(res, host, dialog)
	await GuiCalendarMailCases.mail_dialog(res, host, dialog)
	await GuiCalendarCases.requested(res, host, dialog)
	await GuiCalendarDetailCases.run_cases(res, host, dialog)
	dialog.close()
	await GuiCalendarHelpCases.tags(res, host, dialog, menu)
	for source: CalendarSource in dialog.sources:
		CalendarEvents.set_enabled(source.type, true)
	menu.queue_free()
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = reserve
	await host.get_tree().process_frame
	StockMarket.reset()
	return TestFixtures.summarize(res, "GUI CALENDAR")


static func _case_open_close(res: Dictionary, host: Node, button: CalendarButton) -> void:
	button.button_pressed = true
	await host.get_tree().process_frame
	var dialog: CalendarDialog = button.dialog()
	var date: Dictionary = TrynnCalendar.date_of(GameState.day() * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "press opens the dialog on today's month", dialog.is_open()
		and dialog.shown_year == int(date["year"]) and dialog.shown_month == int(date["month"]),
		"open %s %d/%d" % [dialog.is_open(), dialog.shown_year, dialog.shown_month])
	TestFixtures.check(res, "button stays pressed while the dialog is open", button.button_pressed, "")
	dialog.close_button.pressed.emit()
	TestFixtures.check(res, "the X closes the dialog and unpresses the button",
		not dialog.is_open() and not button.button_pressed, "open %s pressed %s" % [dialog.is_open(), button.button_pressed])
	button.button_pressed = true
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	dialog.backdrop.gui_input.emit(click)
	var by_backdrop: bool = not dialog.is_open() and not button.button_pressed
	button.button_pressed = true
	await host.get_tree().process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	host.get_viewport().push_input(key)
	await host.get_tree().process_frame
	TestFixtures.check(res, "backdrop and Esc close the dialog and unpress the button",
		by_backdrop and not dialog.is_open() and not button.button_pressed,
		"backdrop %s open %s pressed %s" % [by_backdrop, dialog.is_open(), button.button_pressed])
	button.button_pressed = true
	await host.get_tree().process_frame


static func _case_grid(res: Dictionary, dialog: CalendarDialog) -> void:
	var grid: MonthGrid = dialog.grid
	TestFixtures.check(res, "header has 10 weekday labels", grid.weekday_labels().size() == 10,
		"%d" % grid.weekday_labels().size())
	var rows: Array[int] = []
	dialog.open_on(TrynnCalendar.month_first_day(212, 0))
	rows.append(grid.weeks.get_child_count())
	var thirty: int = grid.filled_cells().size()
	var row_four: int = grid.cells.slice(30, 40).filter(func(c: DayCell) -> bool: return c.visible).size()
	dialog.open_on(TrynnCalendar.month_first_day(212, 4))
	rows.append(grid.weeks.get_child_count())
	TestFixtures.check(res, "the grid always has 4 week rows", rows == [4, 4], str(rows))
	TestFixtures.check(res, "a 30-day month fills 30 cells and leaves row 4 empty", thirty == 30 and row_four == 0,
		"%d filled, %d in row 4" % [thirty, row_four])
	TestFixtures.check(res, "a 40-day month fills 40 cells", grid.filled_cells().size() == 40,
		"%d" % grid.filled_cells().size())


static func _case_today(res: Dictionary, dialog: CalendarDialog) -> void:
	var today: int = GameState.day()
	dialog.open_on(today)
	var grid: MonthGrid = dialog.grid
	var flagged: Array = grid.filled_cells().filter(func(c: DayCell) -> bool: return c.is_today).map(
		func(c: DayCell) -> int: return c.day)
	var now_cell: DayCell = grid.cell_of(today)
	var chip: Rect2 = now_cell.today_rect()
	var lane_top: float = grid.week_bars[int((today - grid.first_day) / float(MonthGrid.COLUMNS))].lane_top(0)
	var clear: bool = Rect2(Vector2.ZERO, now_cell.size).encloses(chip) and not chip.intersects(now_cell.number_rect()) \
		and chip.position.y >= DayCell.ICONS_TOP + Icons.CELL and chip.end.y <= lane_top
	TestFixtures.check(res, "only the today cell is flagged; its chip clears the number, icons and bars",
		flagged == [today] and clear, "%s chip %s lane %.1f" % [str(flagged), chip, lane_top])
	var picked: Array = grid.filled_cells().filter(func(c: DayCell) -> bool: return c.selected).map(
		func(c: DayCell) -> int: return c.day)
	TestFixtures.check(res, "selected defaults to today", dialog.selected_day == today and picked == [today], str(picked))
	var wrong: Array = []
	for cell: DayCell in grid.filled_cells():
		var date: Dictionary = TrynnCalendar.date_of(cell.day * TrynnCalendar.MINUTES_PER_DAY)
		var want: bool = String(date["weekday_name"]) in ["Belday", "Zelday"]
		if cell.weekend != want:
			wrong.append(cell.day)
	TestFixtures.check(res, "Belday and Zelday cells carry the weekend tint", wrong.is_empty(), str(wrong))


static func _case_nav(res: Dictionary, dialog: CalendarDialog) -> void:
	var nav: MonthNav = dialog.nav
	var grid: MonthGrid = dialog.grid
	var start: String = dialog.month_text()
	nav.next_button.pressed.emit()
	var next_ok: bool = dialog.month_text() == "Kusarra 212" and grid.first_day == TrynnCalendar.month_first_day(212, 5)
	nav.prev_button.pressed.emit()
	nav.prev_button.pressed.emit()
	var prev_ok: bool = dialog.month_text() == "Helki 212" and grid.first_day == TrynnCalendar.month_first_day(212, 3)
	nav.today_button.pressed.emit()
	TestFixtures.check(res, "Prev, Next and Today change the label and cells", start == "Erta 212" and next_ok and prev_ok
		and dialog.month_text() == start and grid.cell_of(GameState.day()).is_today,
		"start %s next %s prev %s now %s" % [start, next_ok, prev_ok, dialog.month_text()])
	dialog.open_on(TrynnCalendar.month_first_day(212, 9) + 5)
	nav.next_button.pressed.emit()
	TestFixtures.check(res, "Next wraps Tek 212 to Daith 213", dialog.month_text() == "Daith 213"
		and grid.first_day == TrynnCalendar.DAYS_PER_YEAR, "%s first %d" % [dialog.month_text(), grid.first_day])
	dialog.open_on(GameState.day())
