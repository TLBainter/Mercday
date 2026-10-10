class_name MailBlockTests

#Mail blocks and the sender card on a MailReader: tests 40, 46 and 51, the client opinion lock, the reader's own
#answer path, the bill chip repaint and every authored row inside the reader at 1280 x 720. Run under gui-mail-tests.

const READER_SCENE: PackedScene = preload("res://Scenes/GUI/Mail/MailReader.tscn")
const RENT_RAISE: int = 650
const VAC_START: int = 50
const VAC_DAYS: int = 3


static func run(res: Dictionary, host: Node) -> void:
	await _case_blocks(res, host)
	await _case_card(res, host)
	await _case_answer(res, host)
	await _case_authored(res, host)
	SubscriptionManager.max_out()


static func _reader(host: Node, compact: bool) -> MailReader:
	var reader: MailReader = READER_SCENE.instantiate() as MailReader
	reader.compact = compact
	host.add_child(reader)
	await host.get_tree().process_frame
	return reader


static func _blocks_of(reader: MailReader) -> Array[MailBlock]:
	var out: Array[MailBlock] = []
	for kid: Node in reader.thread_box.get_children():
		if kid is MailBlock:
			out.append(kid as MailBlock)
	return out


#A PENDING request of the first merc on the book, VAC_START days out.
static func _request() -> VacationRequest:
	var req: VacationRequest = GuiVacationTests._row(GameState.mercs[0].merc_uid, GameState.day() + VAC_START,
		VAC_DAYS, VacationRequest.State.PENDING)
	BenefitsManager.book.rows.append(req)
	return req


static func _case_blocks(res: Dictionary, host: Node) -> void:
	MailEffectsTests._boot_with([GuiMailTests._cells("B9", "landlord", {"Folder": "Bills", "Bill Id": "rent",
		"Amount": str(RENT_RAISE), "Due": "14"})])
	MailCenter._due.clear()
	if GameState.mercs.is_empty():
		TestFixtures.check(res, "40 MailReader instances BillBlock and VacationRequestBlock", false, "no merc")
		return
	var reader: MailReader = await _reader(host, false)
	var days: Array[int] = []
	var listen: Callable = func(day: int) -> void: days.append(day)
	GameState.open_calendar_requested.connect(listen)
	var bill: MailInstance = MailCenter.deliver(&"B1")
	reader.show_mail(bill.id)
	var bill_blocks: Array[MailBlock] = _blocks_of(reader)
	var bill_link: bool = not bill_blocks.is_empty() and bill_blocks[0].calendar_link.visible
	if bill_blocks.size() == 1 and bill_blocks[0] is BillBlock:
		_check_bill(res, bill_blocks[0] as BillBlock)
		bill_blocks[0].calendar_link.pressed.emit()
	var req: VacationRequest = _request()
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", req)
	var nudge: MailInstance = MailCenter.deliver(MailCatalog.VAC_REMIND, ask.id, req)
	reader.show_mail(nudge.id)
	var thread: Array[MailBlock] = _blocks_of(reader)
	reader.compact = true
	reader.show_mail(nudge.id)
	var compact: Array[MailBlock] = _blocks_of(reader)
	TestFixtures.check(res, "40 MailReader instances BillBlock for a bill and VacationRequestBlock for each request mail",
		bill_blocks.size() == 1 and bill_blocks[0] is BillBlock and bill_blocks[0].mail == bill
		and thread.size() == 2 and thread.all(func(b: MailBlock) -> bool: return b is VacationRequestBlock)
		and thread[0].mail == ask and thread[1].mail == nudge and compact.size() == 1 and compact[0].mail == nudge,
		"bill %d thread %d compact %d" % [bill_blocks.size(), thread.size(), compact.size()])
	var vac_link: bool = not compact.is_empty() and compact[0].calendar_link.visible
	if compact.size() == 1 and compact[0] is VacationRequestBlock:
		_check_vacation(res, compact[0] as VacationRequestBlock, req)
		compact[0].calendar_link.pressed.emit()
	GameState.open_calendar_requested.disconnect(listen)
	_close_calendars(host)
	var want: Array[int] = [bill.bill.due_day, req.start_day]
	TestFixtures.check(res, "46 View in Calendar on BillBlock and VacationRequestBlock emits open_calendar_requested",
		days == want and bill_link and vac_link, "days %s want %s links %s %s" % [days, want, bill_link, vac_link])
	var notice: MailInstance = MailCenter.deliver(&"I1")
	reader.show_mail(notice.id)
	var auto: Array[MailBlock] = _blocks_of(reader)
	var auto_text: String = (auto[0] as BillBlock).status_label.text if auto.size() == 1 and auto[0] is BillBlock else ""
	TestFixtures.check(res, "an AUTO bill block reads Auto-paid", notice.bill != null
		and notice.bill.status == Bill.Status.AUTO and auto_text == "Auto-paid", "status text '%s'" % auto_text)
	reader.compact = false
	await _check_chip_repaint(res, host, reader, bill)
	reader.queue_free()
	await host.get_tree().process_frame


#The host HUD's CalendarButton also answers open_calendar_requested; close what it opened so later scopes start clean.
static func _close_calendars(host: Node) -> void:
	for node: Node in host.get_tree().root.find_children("*", "CalendarDialog", true, false):
		var dialog: CalendarDialog = node as CalendarDialog
		if dialog != null and dialog.is_open():
			dialog.close()


static func _check_bill(res: Dictionary, block: BillBlock) -> void:
	var due: String = BillBlock.DUE_TEXT % GuiDates.short_text(block.mail.bill.due_day)
	TestFixtures.check(res, "BillBlock shows the amount in notes, the due day and Unpaid with the bang mark",
		block.amount_label.amount == 400 and block.due_label.text == due and block.status_label.text == "Unpaid"
		and block.status_mark.kind == StatusMark.Mark.BANG, "amount %d due '%s' status '%s'"
		% [block.amount_label.amount, block.due_label.text, block.status_label.text])


static func _check_vacation(res: Dictionary, vac: VacationRequestBlock, req: VacationRequest) -> void:
	var merc: MercenaryData = GameState.merc_by_uid(req.merc_uid)
	var span: String = VacationRequestBlock.SPAN_TEXT % [GuiDates.short_text(req.start_day),
		GuiDates.short_text(req.end_day()), req.days]
	var left: String = VacationRequestBlock.LEFT_TEXT % BenefitsManager.vacation_days_left(req.merc_uid)
	TestFixtures.check(res, "VacationRequestBlock shows the merc, the span, the days left and the PENDING state",
		vac.merc_label.text == merc.merc_name and vac.span_label.text == span and vac.left_label.text == left
		and vac.state_label.text == "Pending" and vac.state_mark.kind == StatusMark.Mark.NONE,
		"'%s' '%s' '%s' '%s'" % [vac.merc_label.text, vac.span_label.text, vac.left_label.text, vac.state_label.text])


#Item 4: a later mail of the same bill thread replaces the shared amount; the earlier mail's chip follows.
static func _check_chip_repaint(res: Dictionary, host: Node, reader: MailReader, bill: MailInstance) -> void:
	reader.show_mail(bill.id)
	var before: Array[BevelButton] = reader.options.buttons()
	var old_amount: int = reader.options.chips()[0].amount if not reader.options.chips().is_empty() else 0
	MailCenter.deliver(&"B9")
	reader.show_mail(bill.id)
	await host.get_tree().process_frame
	var chips: Array[NotesLabel] = reader.options.chips()
	var now: int = chips[0].amount if not chips.is_empty() else 0
	TestFixtures.check(res, "a later bill row's amount repaints the earlier mail's chip without rebuilding its buttons",
		old_amount == -405 and now == -RENT_RAISE - 5 and chips[0].visible and reader.options.buttons() == before,
		"chip %d then %d same buttons %s" % [old_amount, now, reader.options.buttons() == before])


static func _case_card(res: Dictionary, host: Node) -> void:
	MailEffectsTests._boot_with([])
	MailCenter._due.clear()
	if GameState.mercs.is_empty():
		TestFixtures.check(res, "51 SenderCard for a merc sender", false, "no merc")
		return
	var reader: MailReader = await _reader(host, false)
	var req: VacationRequest = _request()
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", req)
	var merc: MercenaryData = GameState.merc_by_uid(req.merc_uid)
	reader.show_mail(ask.id)
	SubscriptionManager.reset()
	reader.from_label.mouse_entered.emit()
	var card: SenderCard = reader.sender_card
	var want: Array[String] = [SenderCard.LEVEL_TEXT % ExperienceSystem.current_level(merc),
		GuiTypes.merc_status_text(int(GameState.merc_status(merc)["status"])),
		SenderCard.LEFT_TEXT % BenefitsManager.vacation_days_left(merc.merc_uid),
		"Guild Opinion: requires Mercday Enterprise"]
	var buttons: Array[Node] = card.find_children("*", "BaseButton", true, false)
	TestFixtures.check(res, "51 SenderCard for a merc shows level, status, days left and Guild Opinion locked as text",
		card.visible and card.title_label.text == merc.merc_name and card.row_texts() == want and buttons.is_empty(),
		"rows %s buttons %d" % [card.row_texts(), buttons.size()])
	reader.from_label.mouse_exited.emit()
	TestFixtures.check(res, "leaving the From line hides the sender card", not card.visible, "visible %s" % card.visible)
	SubscriptionManager.max_out()
	reader.show_sender_card()
	var value: int = clampi(merc.guild_opinion, -5, 5)
	var open_text: String = SenderCard.GUILD_TEXT % value if value != 0 else SenderCard.GUILD_NEUTRAL_TEXT
	TestFixtures.check(res, "SenderCard shows Guild Opinion in its mood colour once the plan covers it",
		card.locked_text() == "" and card.opinion_label.visible and card.row_texts().back() == open_text
		and card.opinion_label.get_theme_color(&"font_color") == MoodFace.GUILD_COLORS[value + 5],
		"rows %s" % [card.row_texts()])
	_check_client_card(res, reader)
	var client_id: StringName = reader.mail.id if reader.mail != null else &""
	_check_follow(res, reader, ask, merc)
	_check_upgrade_locks(res, reader, ask, client_id)
	_check_mail_senders(res, card)
	card.hide_tip()
	reader.queue_free()
	await host.get_tree().process_frame


#M4 late item 7: an open card follows show_mail to the new sender; no mail hides it.
static func _check_follow(res: Dictionary, reader: MailReader, ask: MailInstance, merc: MercenaryData) -> void:
	var card: SenderCard = reader.sender_card
	var was_open: bool = card.visible and card.title_label.text != merc.merc_name
	reader.show_mail(ask.id)
	var followed: bool = card.visible and card.title_label.text == merc.merc_name
	reader.show_mail(&"")
	TestFixtures.check(res, "an open sender card follows show_mail to the new sender and hides when no mail shows",
		was_open and followed and not card.visible, "open on another sender %s followed %s title '%s' visible %s"
		% [was_open, followed, card.title_label.text, card.visible])


#M4 late item 5: on Enterprise a lock with an upgrade names that upgrade, not the plan the guild already has.
static func _check_upgrade_locks(res: Dictionary, reader: MailReader, ask: MailInstance, client_id: StringName) -> void:
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	var card: SenderCard = reader.sender_card
	reader.show_mail(client_id)
	reader.show_sender_card()
	var client_lock: String = card.locked_text()
	reader.show_mail(ask.id)
	reader.show_sender_card()
	var merc_lock: String = card.locked_text()
	SubscriptionManager.max_out()
	var want_client: String = "Client Opinion: requires the %s upgrade" % UpgradeDefs.display_name("customer")
	var want_merc: String = "Guild Opinion: requires the %s upgrade" % UpgradeDefs.display_name("survey")
	TestFixtures.check(res, "on Enterprise with no upgrades the client and merc locks name the upgrade, never the plan",
		client_id != &"" and UpgradeDefs.display_name("customer") != "" and UpgradeDefs.display_name("survey") != ""
		and client_lock == want_client and merc_lock == want_merc and not client_lock.contains("Mercday")
		and not merc_lock.contains("Mercday"), "client '%s' merc '%s'" % [client_lock, merc_lock])


#M4 late item 6: a Mail Senders row has no opinion or lock row on any plan; a blank Km prints no distance.
static func _check_mail_senders(res: Dictionary, card: SenderCard) -> void:
	var mercday: Object = MailCatalog.sender("mercday")
	SubscriptionManager.reset()
	card.set_sender(mercday)
	var free_rows: Array[String] = card.row_texts()
	SubscriptionManager.max_out()
	card.set_sender(mercday)
	var max_rows: Array[String] = card.row_texts()
	var healer: ClientData = MailCatalog.sender("healer") as ClientData
	card.set_sender(healer)
	var healer_rows: Array[String] = card.row_texts()
	var no_km: bool = free_rows.all(func(row: String) -> bool: return not row.contains("km"))
	var want_healer: Array[String] = []
	if healer != null:
		want_healer = [healer.kind_line(), healer.where_text()]
	var want_mercday: Array[String] = []
	var blank_km: bool = false
	if mercday is ClientData:
		var office: ClientData = mercday as ClientData
		want_mercday = [office.kind_line(), office.location]
		blank_km = office.kind == MailSenders.MAIL_KIND and office.km == -1 and office.location != ""
	TestFixtures.check(res, "a Mail Senders row shows kind and where only; a blank Km prints no distance",
		blank_km and free_rows == want_mercday and free_rows == max_rows and no_km and card.locked_text() == ""
		and healer != null and healer.km >= 0 and healer.where_text().contains("km") and healer_rows == want_healer,
		"free %s max %s healer %s" % [free_rows, max_rows, healer_rows])


static func _check_client_card(res: Dictionary, reader: MailReader) -> void:
	var mail: MailInstance = MailCenter.deliver(&"I2")
	var client: ClientData = MailCatalog.sender(mail.sender_id) as ClientData
	reader.show_mail(mail.id)
	SubscriptionManager.reset()
	reader.show_sender_card()
	var card: SenderCard = reader.sender_card
	var locked: Array[String] = card.row_texts()
	SubscriptionManager.max_out()
	reader.show_sender_card()
	var open: Array[String] = card.row_texts()
	if client == null:
		TestFixtures.check(res, "SenderCard for a client sender", false, "org3 resolves to no client")
		return
	var value: int = clampi(client.relationship, -5, 5)
	var want_locked: Array[String] = [client.kind_line(), client.where_text(),
		"Client Opinion: requires Mercday Enterprise"]
	var want_open: Array[String] = [client.kind_line(), client.where_text(), ClientOverview.relationship_line(value)]
	TestFixtures.check(res, "SenderCard for a client shows kind, where and km, and rel or its lock text naming the plan",
		locked == want_locked and open == want_open
		and card.opinion_label.get_theme_color(&"font_color") == MoodFace.GUILD_COLORS[value + 5],
		"locked %s open %s" % [locked, open])


#Late item 5: a reader alone answers through MailCenter itself.
static func _case_answer(res: Dictionary, host: Node) -> void:
	MailEffectsTests._boot_with([])
	MailCenter._due.clear()
	var reader: MailReader = await _reader(host, true)
	var bill: MailInstance = MailCenter.deliver(&"B1")
	reader.show_mail(bill.id)
	var shown: bool = reader.options.visible and not reader.options.buttons().is_empty()
	var first: int = reader.options.indices()[0] if shown else -2
	if shown:
		await MailViewTests._press(host, reader.options.buttons()[0])
	reader.show_mail(bill.id)
	TestFixtures.check(res, "a compact MailReader alone answers with the pressed option and then shows its reply row",
		shown and bill.choice == first and not reader.options.visible and reader.reply_row(bill) != null,
		"shown %s choice %d want %d options %s" % [shown, bill.choice, first, reader.options.visible])
	reader.queue_free()
	await host.get_tree().process_frame


#Late item 6b: every authored row a test can deliver fits inside the reader with no clipped text.
static func _case_authored(res: Dictionary, host: Node) -> void:
	MailEffectsTests._boot_real()
	MailCenter._due.clear()
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	hud.open_viewer(&"mail")
	await host.get_tree().process_frame
	var view: MailViewer = hud.popup().current() as MailViewer
	var ids: Array = MailCatalog._rows.keys()
	ids.sort()
	var misses: Array[String] = []
	var skipped: Array[String] = []
	var shown: int = 0
	for id: StringName in ids:
		var req: VacationRequest = _request() if String(id).begins_with("R1") and not GameState.mercs.is_empty() else null
		var mail: MailInstance = MailCenter.deliver(id, &"", req) if view != null else null
		if mail == null:
			skipped.append(String(id))
			continue
		view.select_mail(mail.id)
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		shown += 1
		var miss: String = _miss(view.reader, mail)
		if miss != "":
			misses.append("%s: %s" % [id, miss])
	TestFixtures.check(res, "every authored mail row fits inside the reader at 1280 x 720 with no clipped text",
		view != null and shown > 0 and misses.is_empty(), "shown %d skipped %s misses %s" % [shown, skipped, misses])
	await MailViewTests._close(host, hud)


static func _miss(reader: MailReader, mail: MailInstance) -> String:
	var spill: String = GuiFrameTests._outside(reader, reader, reader.get_global_rect())
	if spill != "":
		return spill
	var clipped: String = MailViewTests._clipped(reader, reader)
	if clipped != "":
		return clipped
	var want: int = 0 if mail.kind() == MailInstance.KIND_PLAIN else 1
	if _blocks_of(reader).size() != want:
		return "%d blocks for kind %s" % [_blocks_of(reader).size(), mail.kind()]
	return ""
