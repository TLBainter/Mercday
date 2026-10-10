class_name MailViewTests

#Mail views on the fixture rows: MailViewer through GameHUD, MailRow, MailList, MailReader and MailOptions. Tests 34,
#36-39 and 41, the view halves of 28 and 49, the closed-request rule, the folder tab icons, the reply date and time and
#the 1280 x 720 layout. Run under gui-mail-tests.

const RAW_WORDS: Array[String] = ["rel", "person", "face", "+1"]
#Spam borrows the Rejected status icon until the atlas has a spam icon (card 669).
const TAB_ICONS: Array[String] = ["mail", "request", "bill", "news", "spam"]
#The 460 px left column less the tab row's 4 px margin on each side.
const TAB_ROW_WIDTH: float = 452.0
#F1 is answered this many minutes after it arrives, so the reply time differs from the received time.
const ANSWER_DELAY: int = 95


static func run(res: Dictionary, host: Node) -> void:
	await _case_viewer(res, host)
	await _case_options(res, host)


#A booted fixture campaign with the start rows dropped and a HUD showing the mail viewer.
static func _open(host: Node, extra: Array[Dictionary]) -> GameHUD:
	MailEffectsTests._boot_with(extra)
	MailCenter._due.clear()
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	hud.open_viewer(&"mail")
	await host.get_tree().process_frame
	return hud


static func _close(host: Node, hud: GameHUD) -> void:
	hud.popup().close()
	hud.queue_free()
	await host.get_tree().process_frame


static func _press(host: Node, button: BaseButton) -> void:
	button.pressed.emit()
	await host.get_tree().process_frame


static func _ids(rows: Array[MailRow]) -> Array[StringName]:
	var out: Array[StringName] = []
	for row: MailRow in rows:
		out.append(row.mail.id)
	return out


static func _case_options(res: Dictionary, host: Node) -> void:
	var tones: Dictionary = {"Option 1": "Gain", "Fx 1": "money:5", "Option 2": "Pay", "Fx 2": "money:-5",
		"Option 3": "Skip"}
	var wide: Dictionary = {"Option 1": "Ask for Later Dates", "Fx 1": "money:5", "Option 2": "Dispute the Charge",
		"Fx 2": "money:-5", "Option 3": "We're Interested"}
	var rows: Array[Dictionary] = [GuiMailTests._cells("OT", "landlord", tones),
		MailEffectsTests._one("RL", "rel:person5:1"), GuiMailTests._cells("WL", "landlord", wide)]
	var hud: GameHUD = await _open(host, rows)
	var view: MailViewer = hud.popup().current() as MailViewer
	if view == null:
		TestFixtures.check(res, "34 the mail viewer opens for the options case", false, "no view")
		await _close(host, hud)
		return
	var ot: MailInstance = MailCenter.deliver(&"OT")
	view.select_mail(ot.id)
	var options: MailOptions = view.reader.options
	var labels: Array[String] = []
	var kinds: Array[StringName] = []
	var chips: Array[bool] = []
	for button: BevelButton in options.buttons():
		labels.append(button.text)
		kinds.append(button.kind)
	for chip: NotesLabel in options.chips():
		chips.append(chip.visible)
	var want_labels: Array[String] = ["Pay", "Skip", "Gain"]
	var want_kinds: Array[StringName] = [&"danger", &"neutral", &"go"]
	var want_chips: Array[bool] = [true, false, true]
	TestFixtures.check(res, "34 options run negative to positive, left to right, with a chip only where notes move",
		labels == want_labels and kinds == want_kinds and chips == want_chips,
		"labels %s kinds %s chips %s" % [labels, kinds, chips])
	view.select_mail(MailCenter.deliver(&"WL").id)
	await _check_layout(res, host, view, "with the longest authored option labels showing")
	await _check_rel(res, host, view)
	await _check_closed_request(res, host, view)
	await _close(host, hud)


#Ruling 1: a rel-only option shows no rel token, person name or face count anywhere in the view.
static func _check_rel(res: Dictionary, host: Node, view: MailViewer) -> void:
	var rl: MailInstance = MailCenter.deliver(&"RL")
	view.select_mail(rl.id)
	var options: MailOptions = view.reader.options
	var seen: Array[String] = []
	for button: BevelButton in options.buttons():
		seen.append(button.text)
		seen.append(button.tooltip_text)
	var chip_hidden: bool = options.chips().size() == 1 and not options.chips()[0].visible
	if not options.buttons().is_empty():
		await _press(host, options.buttons()[0])
	var reply: ValueRow = view.reader.reply_row(rl)
	if reply != null:
		seen.append_array([reply.caption, reply.sub_text, reply.value_text])
	var raw: String = ""
	for text: String in seen:
		for word: String in RAW_WORDS:
			if text.to_lower().contains(word):
				raw = "'%s' in '%s'" % [word, text]
	TestFixtures.check(res, "28 a rel-only option shows no rel, person or face count on button, chip, tooltip or reply",
		chip_hidden and rl.choice == 0 and reply != null and raw == "", "chip hidden %s choice %d raw %s"
		% [chip_hidden, rl.choice, raw])


#Ruling 3: once the request is answered through R1, the reminder R1M offers no options.
static func _check_closed_request(res: Dictionary, host: Node, view: MailViewer) -> void:
	if GameState.mercs.is_empty():
		TestFixtures.check(res, "options on a vacation mail hide once its request is no longer PENDING", false,
			"no merc on the roster")
		return
	var asker: MercenaryData = GameState.mercs[0]
	var req: VacationRequest = GuiVacationTests._row(asker.merc_uid, GameState.day() + 50, 3,
		VacationRequest.State.PENDING)
	BenefitsManager.book.rows.append(req)
	var ask: MailInstance = MailCenter.deliver(MailCatalog.VAC_REQUEST, &"", req)
	var nudge: MailInstance = MailCenter.deliver(MailCatalog.VAC_REMIND, ask.id, req)
	view.select_mail(nudge.id)
	var open_before: bool = view.reader.options.visible
	view.select_mail(ask.id)
	var at: int = view.reader.options.indices().find(1)
	if at >= 0:
		await _press(host, view.reader.options.buttons()[at])
	view.select_mail(nudge.id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "options on a vacation mail hide once its request is no longer PENDING",
		open_before and req.state == VacationRequest.State.DENIED and nudge.choice < 0
		and not view.reader.options.visible, "before %s state %d nudge %d visible %s"
		% [open_before, req.state, nudge.choice, view.reader.options.visible])


static func _case_viewer(res: Dictionary, host: Node) -> void:
	var hud: GameHUD = await _open(host, [])
	var view: MailViewer = hud.popup().current() as MailViewer
	var keys: Array[StringName] = []
	if view != null:
		for tab: TabButton in view.tabs():
			keys.append(StringName(tab.name))
	TestFixtures.check(res, "36 MailViewer opens through GameHUD.open_viewer(&\"mail\") with five folder tabs",
		view != null and keys == MailCatalog.FOLDERS, "view %s keys %s" % [view, keys])
	if view == null:
		await _close(host, hud)
		return
	await _check_tabs(res, host, view)
	var f1: MailInstance = MailCenter.deliver(&"F1")
	var i2: MailInstance = MailCenter.deliver(&"I2")
	MailCenter.deliver(&"B1")
	var i1: MailInstance = MailCenter.deliver(&"I1")
	MailCenter.archive(i2.id)
	await host.get_tree().process_frame
	var badges: Array[int] = []
	var live: Array[int] = []
	for key: StringName in MailCatalog.FOLDERS:
		badges.append(view.tab_button(key).badge)
		live.append(MailCenter.unread(key))
	TestFixtures.check(res, "38 TabStrip badge equals live unread per folder", badges == live and badges[0] == 1
		and badges[2] == 1, "badges %s unread %s" % [badges, live])
	_check_lit(res, view)
	var row: MailRow = view.list.row_for(f1.id)
	var read_row: MailRow = view.list.row_for(i1.id)
	var marked: bool = row != null and row.unread_dot.on and row.unread_dot.color == GuiColors.ORANGE
	TestFixtures.check(res, "37 MailRow shows the orange unread mark on unread mail only", marked and read_row != null
		and not read_row.unread_dot.on, "row %s read row %s" % [row, read_row])
	if row != null:
		await _press(host, row)
	TestFixtures.check(res, "37 selecting the row marks it read and clears the mark", row != null and f1.read
		and not row.unread_dot.on and row.selected and view.selected_id() == f1.id
		and view.tab_button(&"inbox").badge == 0, "read %s selected %s" % [f1.read, view.selected_id()])
	TestFixtures.check(res, "38 the inbox tab goes plain once its last unread mail is read",
		not view.tab_button(&"inbox").lit, "lit %s" % view.tab_button(&"inbox").lit)
	await _check_answer(res, host, view, f1)
	view.select_mail(i1.id)
	var reply: ValueRow = view.reader.reply_row(i1)
	TestFixtures.check(res, "49 a Read row with one option shows no options and its answer in the reply row",
		i1.choice == 0 and not view.reader.options.visible and reply != null and reply.sub_text == "Ok"
		and reply.caption == "You to %s" % MailText.fill("{sender}", i1), "reply %s" % [reply])
	await _check_layout(res, host, view, "on a read mail")
	await _check_archive(res, host, view, f1, i2)
	_check_redraw(res, view)
	await _close(host, hud)


#Card 679: the lit flag follows live unread; only an idle lit tab tints its icon orange.
static func _check_lit(res: Dictionary, view: MailViewer) -> void:
	var ok: bool = true
	var idle_lit: int = 0
	var seen: Array[String] = []
	for key: StringName in MailCatalog.FOLDERS:
		var tab: TabButton = view.tab_button(key)
		var unread: bool = MailCenter.unread(key) > 0
		var want: Color = GuiColors.ORANGE if unread and not tab.active else Color.WHITE
		ok = ok and tab.lit == unread and tab.icon_rect.tint == want
		if unread and not tab.active:
			idle_lit += 1
		seen.append("%s lit %s tint %s" % [key, tab.lit, tab.icon_rect.tint])
	TestFixtures.check(res, "38 a folder with unread mail lights its tab; the active tab and empty folders stay plain",
		ok and idle_lit > 0 and view.tab_button(view.current_tab()).active, "%s" % [seen])


#Card 670: an atlas icon on every folder tab, the label on the open tab only, and the row fits whichever tab is open.
static func _check_tabs(res: Dictionary, host: Node, view: MailViewer) -> void:
	var ids: Array[String] = []
	var shown: Array[bool] = []
	for tab: TabButton in view.tabs():
		ids.append(tab.icon_id)
		shown.append(tab.text_label.visible)
	var widest: float = 0.0
	for i: int in view.tabs().size():
		view.select_tab(i)
		await host.get_tree().process_frame
		widest = maxf(widest, _tab_row_width(view))
	view.select_tab(0)
	var want_shown: Array[bool] = [true, false, false, false, false]
	TestFixtures.check(res, "the folder tabs carry their atlas icons, label only the open tab and fit the left column",
		ids == TAB_ICONS and shown == want_shown and widest <= TAB_ROW_WIDTH,
		"ids %s labels %s widest row %.0f of %.0f" % [ids, shown, widest, TAB_ROW_WIDTH])


#The least width of the tab row: per tab its box or its icon and label, whichever is wider, plus the gaps between tabs.
static func _tab_row_width(view: MailViewer) -> float:
	var tabs: Array[TabButton] = view.tabs()
	var width: float = float(view.tab_strip.get_theme_constant(&"separation") * (tabs.size() - 1))
	for tab: TabButton in tabs:
		var content: Control = tab.text_label.get_parent() as Control
		width += maxf(tab.get_combined_minimum_size().x, content.get_combined_minimum_size().x)
	return width


#Same ids with new instances (a reload) redraw the rows from the new instances.
static func _check_redraw(res: Dictionary, view: MailViewer) -> void:
	var live: Array[MailInstance] = MailCenter.mail_in(&"inbox", false)
	var twins: Array[MailInstance] = []
	for m: MailInstance in live:
		var twin: MailInstance = MailInstance.new()
		twin.id = m.id
		twin.def_id = m.def_id
		twin.sender_id = m.sender_id
		twin.folder = m.folder
		twin.read = not m.read
		twins.append(twin)
	var before: Array[MailRow] = view.list.rows()
	view.list.set_mail(twins)
	var ok: bool = not twins.is_empty() and view.list.rows() == before
	for row: MailRow in view.list.rows():
		ok = ok and twins.has(row.mail) and row.unread_dot.on != row.mail.read
	view.list.set_mail(live)
	TestFixtures.check(res, "MailList redraws rows from new instances that keep the same ids", ok,
		"rows %d twins %d" % [view.list.rows().size(), twins.size()])


static func _check_answer(res: Dictionary, host: Node, view: MailViewer, f1: MailInstance) -> void:
	var options: MailOptions = view.reader.options
	var heard: Array[int] = []
	var spy: Callable = func(index: int) -> void: heard.append(index)
	options.chosen.connect(spy)
	var open: bool = options.visible and options.buttons().size() == 2
	var at: int = options.indices().find(1)
	var minute: int = CampaignClock.advance(ANSWER_DELAY)
	if at >= 0:
		await _press(host, options.buttons()[at])
	options.chosen.disconnect(spy)
	var reply: ValueRow = view.reader.reply_row(f1)
	TestFixtures.check(res, "41 MailOptions emits chosen(index) and hides once answered", open and heard.size() == 1
		and heard[0] == 1 and f1.choice == 1 and not options.visible and reply != null and reply.sub_text == "Range",
		"open %s heard %s choice %d visible %s" % [open, heard, f1.choice, options.visible])
	var stamp: String = GuiDates.short_text(TrynnCalendar.day_index(minute)) + " " + TrynnCalendar.time_text(minute)
	var value: String = reply.value_text if reply != null else ""
	TestFixtures.check(res, "the reply row shows the date and time of the answer", value == stamp,
		"value '%s' want '%s'" % [value, stamp])


static func _check_archive(res: Dictionary, host: Node, view: MailViewer, f1: MailInstance, i2: MailInstance) -> void:
	view.select_mail(f1.id)
	var live_text: String = view.reader.archive_button.text
	var live_icon: Texture2D = view.reader.archive_button.icon
	await _press(host, view.reader.archive_button)
	view.list.archived_button.button_pressed = true
	await host.get_tree().process_frame
	var shown: Array[StringName] = _ids(view.list.rows())
	var want: Array[StringName] = _ids_of(MailCenter.mail_in(&"inbox", true))
	TestFixtures.check(res, "39 the Archived toggle lists the current folder's archived mail",
		view.showing_archived() and f1.archived and shown == want and shown.has(f1.id) and shown.has(i2.id)
		and shown.size() == 2, "shown %s want %s" % [shown, want])
	var row: MailRow = view.list.row_for(f1.id)
	if row != null:
		await _press(host, row)
	var archived_text: String = view.reader.archive_button.text
	var archived_icon: Texture2D = view.reader.archive_button.icon
	await _press(host, view.reader.archive_button)
	TestFixtures.check(res, "39 the reader button reads Archive on live mail and Restore on archived mail",
		live_text == "Archive" and archived_text == "Restore" and not f1.archived
		and view.list.rows().size() == 1 and view.list.row_for(i2.id) != null,
		"live '%s' archived '%s'" % [live_text, archived_text])
	view.select_mail(f1.id)
	var restored_icon: Texture2D = view.reader.archive_button.icon
	var want_size: Vector2 = Vector2(Icons.size("archive")) * 2.0
	TestFixtures.check(res, "the Archive button carries the archive icon while live and none once archived",
		live_icon != null and live_icon.get_size() == want_size and archived_icon == null and restored_icon != null,
		"live %s archived %s restored %s want %s" % [live_icon, archived_icon, restored_icon, want_size])
	view.list.archived_button.button_pressed = false
	await host.get_tree().process_frame


static func _ids_of(list: Array[MailInstance]) -> Array[StringName]:
	var out: Array[StringName] = []
	for m: MailInstance in list:
		out.append(m.id)
	return out


static func _check_layout(res: Dictionary, host: Node, view: MailViewer, what: String) -> void:
	await host.get_tree().process_frame
	var screen: Rect2 = host.get_viewport().get_visible_rect()
	var box: Rect2 = view.get_global_rect()
	var spill: String = GuiFrameTests._outside(view, view, box)
	var clipped: String = _clipped(view, view)
	var shown: int = view.reader.options.buttons().size() if view.reader.options.visible else 0
	TestFixtures.check(res, "the mail viewer fits 1280 x 720 with no spill and no clipped text " + what,
		screen.size == Vector2(1280, 720) and screen.encloses(box) and spill == "" and clipped == "",
		"screen %s box %s buttons %d spill %s clipped %s" % [screen, box, shown, spill, clipped])


#The first visible label or button whose one-line text is wider than its box; "" when none is.
static func _clipped(root: Control, node: Node) -> String:
	for kid: Node in node.get_children():
		var part: Control = kid as Control
		if part == null or not part.is_visible_in_tree():
			continue
		var text: String = ""
		if part is Label and (part as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			text = (part as Label).text
		elif part is Button:
			text = (part as Button).text
		if text != "" and not text.contains("\n"):
			var font: Font = part.get_theme_font(&"font")
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				part.get_theme_font_size(&"font_size")).x
			if width > part.size.x + 1.0:
				return "%s '%s' %.0f > %.0f" % [str(root.get_path_to(part)), text, width, part.size.x]
		var deeper: String = _clipped(root, part)
		if deeper != "":
			return deeper
	return ""
