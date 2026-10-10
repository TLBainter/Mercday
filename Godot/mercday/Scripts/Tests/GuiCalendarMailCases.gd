class_name GuiCalendarMailCases
extends RefCounted

#--gui-calendar-tests cases 11 and 15 plus the ruled MailDialog layout and View in Calendar checks, over R1 and a test B1 row.


#Case 11: the bill row hands its mail to the Inbox and closes the calendar.
static func bill_row(res: Dictionary, host: Node, dialog: CalendarDialog) -> void:
	MailEffectsTests.sample_catalog()
	var mail: MailInstance = MailCenter.deliver(&"B1")
	var bill: Bill = mail.bill if mail != null else null
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var asked: Array[StringName] = []
	var spy: Callable = func(id: StringName) -> void: asked.append(id)
	MailCenter.open_requested.connect(spy)
	dialog.open_on(bill.due_day if bill != null else GameState.day())
	await host.get_tree().process_frame
	var row: EventRow = GuiCalendarDetailCases._find(dialog, bill) if bill != null else null
	if row != null:
		row.pressed.emit()
	await host.get_tree().process_frame
	MailCenter.open_requested.disconnect(spy)
	var viewer: MailViewer = hud.popup().current() as MailViewer
	var seen: StringName = viewer.selected_id() if viewer != null else &""
	TestFixtures.check(res, "a mail bill row click calls MailCenter.request_open with its mail id; the Inbox selects it",
		row != null and asked.size() == 1 and asked[0] == bill.mail_id and seen == bill.mail_id,
		"row %s asked %s viewer %s" % [row != null, asked, seen])
	TestFixtures.check(res, "a mail bill row click closes the calendar", row != null and not dialog.is_open(),
		"row %s open %s" % [row != null, dialog.is_open()])
	hud.popup().close()
	hud.queue_free()
	await host.get_tree().process_frame
	MailCatalog.parse_rows(TsvReader.load_header_rows(MailCatalog.MAIL_TSV))
	MailCenter.reset()


#Case 15 with the layout and View in Calendar checks: two mailed PENDING requests and one auto row on one day.
static func mail_dialog(res: Dictionary, host: Node, dialog: CalendarDialog) -> void:
	if GameState.mercs.is_empty():
		for what: String in ["case 15 auto bar", "MailDialog layout", "View in Calendar", "case 15 answer"]:
			TestFixtures.check(res, what, false, "no merc on the roster")
		return
	var start: int = GameState.day() + 2
	var by_mail: VacationRequest = _mailed(start)
	var by_cal: VacationRequest = _mailed(start)
	var auto: VacationRequest = GuiVacationTests._row(GameState.mercs[0].merc_uid, start, 3, VacationRequest.State.APPROVED)
	auto.auto = true
	BenefitsManager.book.rows.append(auto)
	dialog.open_on(start)
	await host.get_tree().process_frame
	var calls: Array[int] = [0]
	var on_change: Callable = func() -> void: calls[0] += 1
	var on_open: Callable = func(_id: StringName) -> void: calls[0] += 1
	MailCenter.changed.connect(on_change)
	MailCenter.open_requested.connect(on_open)
	var hit: bool = _click_bar(dialog, auto)
	MailCenter.changed.disconnect(on_change)
	MailCenter.open_requested.disconnect(on_open)
	TestFixtures.check(res, "an auto vacation bar click opens no MailDialog and calls no MailCenter method",
		hit and not dialog.mail_dialog.is_open() and calls[0] == 0 and dialog.selected_day == start,
		"hit %s dialog %s calls %d" % [hit, dialog.mail_dialog.is_open(), calls[0]])
	await _layout(res, host, dialog, by_cal)
	dialog.step_month(1)
	var links: Array[MailBlock] = _blocks(dialog.mail_dialog)
	if not links.is_empty():
		links[0].calendar_link.pressed.emit()
	await host.get_tree().process_frame
	var on_day: bool = dialog.is_open() and dialog.grid.cell_of(start) != null and dialog.selected_day == start
	TestFixtures.check(res, "View in Calendar in MailDialog closes it and moves the calendar to the request day",
		links.size() == 1 and not dialog.mail_dialog.is_open() and on_day,
		"links %d dialog %s on day %s" % [links.size(), dialog.mail_dialog.is_open(), on_day])
	_click_bar(dialog, by_cal)
	var buttons: Array[BevelButton] = dialog.mail_dialog.reader.options.buttons()
	var approve: int = dialog.mail_dialog.reader.options.indices().find(0)
	var was: Array = [_bar(dialog, by_cal).get("dashed", false), _bar(dialog, by_mail).get("dashed", false)]
	if approve >= 0:
		buttons[approve].pressed.emit()
	MailCenter.choose(by_mail.mail_id, 0)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var solid: Array = [_bar(dialog, by_cal).get("dashed", true), _bar(dialog, by_mail).get("dashed", true)]
	TestFixtures.check(res, "answering from Calendar and from Mail turns the bars solid without reopening",
		was == [true, true] and solid == [false, false] and dialog.is_open() and not dialog.mail_dialog.is_open(),
		"dashed %s then %s calendar %s mail %s" % [was, solid, dialog.is_open(), dialog.mail_dialog.is_open()])
	for req: VacationRequest in [by_mail, by_cal, auto]:
		BenefitsManager.book.rows.erase(req)
	MailCenter.reset()


#The open MailDialog on a PENDING request fits the screen, spills nothing and clips no one-line text.
static func _layout(res: Dictionary, host: Node, dialog: CalendarDialog, req: VacationRequest) -> void:
	_click_bar(dialog, req)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var mail_box: Control = dialog.mail_dialog.box
	var rect: Rect2 = mail_box.get_global_rect()
	var spill: String = GuiFrameTests._outside(mail_box, mail_box, rect)
	var clipped: String = MailViewTests._clipped(mail_box, mail_box)
	var blocks: Array[MailBlock] = _blocks(dialog.mail_dialog)
	var shown: bool = blocks.size() == 1 and dialog.mail_dialog.reader.scroll.get_global_rect().encloses(
		blocks[0].get_global_rect())
	var buttons: int = dialog.mail_dialog.reader.options.buttons().size()
	var mail: MailInstance = MailCenter.get_mail(req.mail_id)
	var want: String = "" if mail == null else MailText.fill(String(MailCatalog.row(mail.def_id).get("subject", "")), mail)
	TestFixtures.check(res, "MailDialog on a request: subject title, read, fits the screen with block and buttons, no clip",
		dialog.mail_dialog.is_open() and host.get_viewport().get_visible_rect().encloses(rect) and spill == ""
		and clipped == "" and shown and buttons == 3 and want != "" and mail.read and dialog.mail_dialog.title == want,
		"rect %s spill '%s' clipped '%s' block %s buttons %d title %s" % [rect, spill, clipped, shown, buttons, want])


#A PENDING request with its R1 mail, as VacationMail sends it.
static func _mailed(start: int) -> VacationRequest:
	var req: VacationRequest = GuiVacationTests._row(GameState.mercs[0].merc_uid, start, 3, VacationRequest.State.PENDING)
	BenefitsManager.book.rows.append(req)
	var mail: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", req)
	req.mail_id = mail.id if mail != null else &""
	return req


static func _blocks(mail: MailDialog) -> Array[MailBlock]:
	var out: Array[MailBlock] = []
	for kid: Node in mail.reader.thread_box.get_children():
		if kid is MailBlock:
			out.append(kid as MailBlock)
	return out


#The drawn bar of a request on the shown grid, or {} when none.
static func _bar(dialog: CalendarDialog, req: VacationRequest) -> Dictionary:
	for row: WeekBars in dialog.grid.week_bars:
		for bar: Dictionary in row.bars:
			var event: CalendarEvent = bar["event"] as CalendarEvent
			if event != null and is_same(event.ref, req):
				return bar
	return {}


#Clicks the first day of a request's bar in its top quarter, where a lane 2 bar overlaps lane 1; false with no bar.
static func _click_bar(dialog: CalendarDialog, req: VacationRequest) -> bool:
	for row: WeekBars in dialog.grid.week_bars:
		for bar: Dictionary in row.bars:
			var event: CalendarEvent = bar["event"] as CalendarEvent
			if event != null and is_same(event.ref, req):
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				var rect: Rect2 = bar["rect"]
				click.position = rect.position + Vector2(4.0, rect.size.y / 4.0)
				row.gui_input.emit(click)
				return true
	return false
