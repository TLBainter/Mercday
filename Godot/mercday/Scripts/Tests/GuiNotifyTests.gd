class_name GuiNotifyTests
extends RefCounted

#The HUD notification bell and its panel: the bell face and unread dot, the Unread and Read tabs,
#the sort and filter popups, the three item bodies, mark as read and the opened signal the HUD
#routes. NotificationCenter is the only row source; the bell never marks a row read by itself.

const BELL_SCENE: String = "res://Scenes/GUI/Notifications/NotificationBell.tscn"
const FRAME_SIZE: Vector2 = Vector2(1280, 720)
const BELL_AT: Vector2 = Vector2(1140.0, 16.0)
const PANEL_AT: Vector2 = Vector2(756.0, 86.0)
const CONTRACT_NAME: String = "Caravan Watch"
const SECOND_NAME: String = "Ridge Patrol"
const LOAN_LENDER: String = "House of Coin"
const STOCK_COMPANY: String = "Ironvein"
const UNKNOWN_TYPE := &"weatherTurn"
const UNKNOWN_NAME: String = "Storm"
const HOURS_PLURAL: float = 50.0
const HOURS_SINGULAR: float = 25.0
const REWARD: int = 1250
const OFFER_AMOUNT: int = 12500
const OFFER_RATE: float = 0.12
const OFFER_TERM: int = 6
const DIFFICULTY: float = 3.5
const STOCK_UP_PCT: float = 3.2
const STOCK_DOWN_PCT: float = -4.0
#An id FinanceManager never holds, and the id its SEED_OFFERS seeds live on every reset().
const NO_OFFER_ID: int = 9901
const LIVE_OFFER_ID: int = 101


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	await host.get_tree().process_frame
	await _case_bell_face(res, host)
	await _case_bell_dot(res, host)
	await _case_tabs(res, host)
	await _case_sort(res, host)
	await _case_filter(res, host)
	await _case_popups(res, host)
	await _case_open_item(res, host)
	await _case_mark_read(res, host)
	await _case_item_style(res, host)
	await _case_contract_body(res, host)
	await _case_loan_body(res, host)
	await _case_stock_body(res, host)
	await _case_unknown_type(res, host)
	await _case_footer(res, host)
	await _case_glyphs(res, host)
	await _case_frame_fit(res, host)
	_case_dot_shape(res)
	_case_dot_pulse_math(res)
	await _case_dot_lifecycle(res, host)
	await _case_dot_placements(res, host)
	LoanOfferBody.hours_override = Callable()
	NotificationCenter.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI NOTIFY")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _bell(host: Node) -> NotificationBell:
	NotificationCenter.reset()
	var scene: PackedScene = load(BELL_SCENE) as PackedScene
	var bell: NotificationBell = scene.instantiate() as NotificationBell
	host.add_child(bell)
	await host.get_tree().process_frame
	return bell


static func _drop(bell: NotificationBell, host: Node) -> void:
	bell.queue_free()
	await host.get_tree().process_frame


static func _brighter(base: Color, gain: float) -> Color:
	return Color(minf(base.r * gain, 1.0), minf(base.g * gain, 1.0), minf(base.b * gain, 1.0),
		base.a)


static func _contract_row(row_name: String, failed: bool = false) -> NotificationData:
	var type: StringName = NotificationData.TYPE_CONTRACT_FAILED if failed \
		else NotificationData.TYPE_CONTRACT_COMPLETED
	return NotificationCenter.push(type, 11, {"name": row_name, "difficulty": DIFFICULTY,
		"reward": REWARD})


static func _loan_row(urgency: int = NotificationData.Urgency.IMPORTANT,
		offer_id: int = NO_OFFER_ID) -> NotificationData:
	return NotificationCenter.push(NotificationData.TYPE_LOAN_OFFER, offer_id,
		{"lender": LOAN_LENDER, "offer_amount": OFFER_AMOUNT, "offer_rate": OFFER_RATE,
		"offer_term": OFFER_TERM}, urgency)


static func _stock_row(pct: float, band: int) -> NotificationData:
	return NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 7,
		{"company_id": 7, "company": STOCK_COMPANY, "pct": pct, "band": band})


static func _ids_of(rows: Array[NotificationData]) -> Array[int]:
	var out: Array[int] = []
	for row: NotificationData in rows:
		out.append(row.id)
	return out


static func _box_fill(btn: Button) -> Color:
	var box: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
	return Color(0.0, 0.0, 0.0, 0.0) if box == null else box.bg_color


#Case 1: the bell frame, the two faces, the glyph and where the panel hangs.
static func _case_bell_face(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	TestFixtures.check(res, "the bell is 56 x 56 and names itself in a tooltip",
		bell.size == NotificationBell.BELL_SIZE and bell.tooltip_text == "Notifications",
		"size %s tooltip %s" % [str(bell.size), bell.tooltip_text])
	TestFixtures.check(res, "the closed bell wears the blue face",
		bell.bg_color() == NotificationBell.BG_IDLE, str(bell.bg_color()))
	TestFixtures.check(res, "the closed bell wears the blue bevel and the cream glyph",
		bell.bevel_hi() == NotificationBell.BEVEL_HI_IDLE
			and bell.bevel_lo() == NotificationBell.BEVEL_LO_IDLE
			and bell.glyph_color() == NotificationBell.GLYPH_IDLE,
		"%s %s %s" % [str(bell.bevel_hi()), str(bell.bevel_lo()), str(bell.glyph_color())])
	var glyph: Control = bell.glyph()
	var want_glyph: Vector2 = Vector2(32.0, 32.0) + Vector2(NotifyGlyphs.SHADOW_STEP,
		NotifyGlyphs.SHADOW_STEP)
	TestFixtures.check(res, "the bell glyph is the 16 x 16 bell at 2 px over its shadow",
		glyph != null and glyph.custom_minimum_size == want_glyph,
		"glyph %s" % ("null" if glyph == null else str(glyph.custom_minimum_size)))
	var bell_face: TextureRect = glyph.get_child(1) as TextureRect if glyph != null else null
	var bell_plain: Texture2D = Icons.baked("bell", NotificationBell.GLYPH_SCALE, Icons.MODE_PLAIN)
	var face_ok: bool = bell_face != null and bell_face.name == "Face"
	face_ok = face_ok and bell_face.texture == bell_plain
	face_ok = face_ok and bell_face.texture.get_size() == Vector2(32.0, 32.0)
	TestFixtures.check(res, "the closed bell face is the plain bell cell baked at 32 x 32",
		face_ok, "face %s" % ("null" if bell_face == null else str(bell_face.texture.get_size())))
	TestFixtures.check(res, "the panel is a 440 x 520 child of the bell",
		panel != null and panel.size == NotificationPanel.PANEL_SIZE,
		"panel %s" % ("null" if panel == null else str(panel.size)))
	TestFixtures.check(res, "the panel hangs 14 px under the bell with the right edges aligned",
		panel.position == Vector2(NotificationBell.BELL_SIZE.x - NotificationPanel.PANEL_SIZE.x,
			NotificationBell.BELL_SIZE.y + NotificationBell.PANEL_GAP),
		str(panel.position))
	TestFixtures.check(res, "the panel draws above the HUD at z 40",
		panel.z_index == NotificationBell.PANEL_Z, "z %d" % panel.z_index)
	var title_lbl: Label = panel.get_node_or_null(panel.title_path) as Label
	var title_font: FontVariation = title_lbl.get_theme_font("font") as FontVariation \
		if title_lbl != null else null
	TestFixtures.check(res, "the panel title carries 1 px of glyph spacing",
		title_font != null and title_font.spacing_glyph == 1,
		"font %s" % ("null" if title_font == null else str(title_font.spacing_glyph)))
	TestFixtures.check(res, "the bell starts closed", not bell.panel_open() and not panel.visible,
		"open %s visible %s" % [str(bell.panel_open()), str(panel.visible)])
	bell.open_panel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "open_panel shows the panel and turns the bell orange",
		bell.panel_open() and panel.visible and bell.bg_color() == NotificationBell.BG_OPEN,
		"open %s fill %s" % [str(bell.panel_open()), str(bell.bg_color())])
	TestFixtures.check(res, "the open bell wears the orange bevel and the ink glyph",
		bell.bevel_hi() == NotificationBell.BEVEL_HI_OPEN
			and bell.bevel_lo() == NotificationBell.BEVEL_LO_OPEN
			and bell.glyph_color() == NotificationBell.GLYPH_OPEN,
		"%s %s %s" % [str(bell.bevel_hi()), str(bell.bevel_lo()), str(bell.glyph_color())])
	var open_face: TextureRect = bell.glyph().get_child(1) as TextureRect
	var bell_two_tone: Texture2D = Icons.baked("bell", 2, Icons.MODE_TWO_TONE)
	TestFixtures.check(res, "the open bell swaps the face to the two tone bell cell",
		open_face != null and open_face.texture == bell_two_tone
			and open_face.texture != bell_plain,
		"open face %s" % ("null" if open_face == null else str(open_face.texture.get_size())))
	bell.set_hovered(true)
	TestFixtures.check(res, "hovering brightens the face by 15 percent",
		bell.hovered() and bell.bg_color() == _brighter(NotificationBell.BG_OPEN,
			NotificationBell.HOVER_GAIN), str(bell.bg_color()))
	bell.set_hovered(false)
	bell.close_panel()
	TestFixtures.check(res, "close_panel hides the panel and restores the blue face",
		not bell.panel_open() and not panel.visible
			and bell.bg_color() == NotificationBell.BG_IDLE,
		"open %s fill %s" % [str(bell.panel_open()), str(bell.bg_color())])
	bell.toggle_panel()
	var opened: bool = bell.panel_open()
	bell.toggle_panel()
	TestFixtures.check(res, "toggle_panel flips the panel both ways",
		opened and not bell.panel_open(), "opened %s then %s" % [str(opened),
			str(bell.panel_open())])
	await _drop(bell, host)


#Case 2: the unread dot follows the store and sits on the bell corner.
static func _case_bell_dot(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var dot: NotificationDot = bell.dot()
	TestFixtures.check(res, "the bell carries a NotificationDot that ignores the mouse",
		dot != null and dot.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"dot %s" % ("null" if dot == null else str(dot.mouse_filter)))
	TestFixtures.check(res, "the bell hangs its whole dot frame off its top right corner",
		dot.anchor_left == 1.0 and dot.anchor_right == 1.0 and dot.anchor_top == 0.0
			and dot.offset_right == -NotificationBell.DOT_OFFSET.x
			and dot.offset_left == dot.offset_right - NotificationDot.FRAME_SIZE.x
			and dot.offset_top == NotificationBell.DOT_OFFSET.y
			and dot.offset_bottom == dot.offset_top + NotificationDot.FRAME_SIZE.y,
		"anchors %.1f %.1f offsets %.1f %.1f %.1f %.1f" % [dot.anchor_left, dot.anchor_top,
			dot.offset_left, dot.offset_top, dot.offset_right, dot.offset_bottom])
	TestFixtures.check(res, "an empty store hides the dot",
		not bell.dot_visible() and not NotificationCenter.has_unread(),
		"visible %s" % str(bell.dot_visible()))
	var row: NotificationData = _contract_row(CONTRACT_NAME)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a pushed row lights the dot", bell.dot_visible(),
		"visible %s unread %d" % [str(bell.dot_visible()), NotificationCenter.unread_count()])
	NotificationCenter.mark_read(row.id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "reading the last row hides the dot again", not bell.dot_visible(),
		"visible %s" % str(bell.dot_visible()))
	await _drop(bell, host)


#Case 3: the tab texts, the tab switch and the two empty texts.
static func _case_tabs(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var first: NotificationData = _contract_row(CONTRACT_NAME)
	var second: NotificationData = _contract_row(SECOND_NAME)
	var third: NotificationData = _loan_row()
	NotificationCenter.mark_read(third.id)
	bell.open_panel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the tab texts count the unread and the read rows",
		panel.tab_text(true) == "Unread (2)" and panel.tab_text(false) == "Read (1)",
		"%s / %s" % [panel.tab_text(true), panel.tab_text(false)])
	TestFixtures.check(res, "both tab buttons print those counts",
		panel.unread_tab().text == "Unread (2)" and panel.read_tab().text == "Read (1)",
		"%s / %s" % [panel.unread_tab().text, panel.read_tab().text])
	TestFixtures.check(res, "the unread tab is the one the panel opens on",
		panel.tab == NotificationPanel.TAB_UNREAD
			and _ids_of(panel.rows()) == [second.id, first.id],
		"tab %s ids %s" % [panel.tab, str(_ids_of(panel.rows()))])
	TestFixtures.check(res, "the list builds one card per listed row",
		panel.cards().size() == 2 and panel.card_for(first.id) != null
			and panel.card_for(third.id) == null,
		"cards %d" % panel.cards().size())
	TestFixtures.check(res, "the active tab wears the orange fill and the idle tab the blue",
		_box_fill(panel.unread_tab()) == NotificationPanel.ORANGE
			and _box_fill(panel.read_tab()) == NotificationPanel.BLUE2,
		"%s / %s" % [str(_box_fill(panel.unread_tab())), str(_box_fill(panel.read_tab()))])
	var switches: Array[String] = []
	panel.tab_changed.connect(func(value: String) -> void: switches.append(value))
	panel.set_tab(NotificationPanel.TAB_READ)
	await host.get_tree().process_frame
	TestFixtures.check(res, "set_tab switches the list and reports the switch once",
		panel.tab == NotificationPanel.TAB_READ and panel.cards().size() == 1
			and switches == [NotificationPanel.TAB_READ] and panel.card_for(third.id) != null,
		"cards %d switches %s" % [panel.cards().size(), str(switches)])
	panel.set_tab(NotificationPanel.TAB_READ)
	TestFixtures.check(res, "setting the tab it already shows reports nothing",
		switches.size() == 1, "switches %s" % str(switches))
	TestFixtures.check(res, "a filled list hides the empty text", not panel.empty_visible(),
		"visible %s" % str(panel.empty_visible()))
	panel.set_filter("Mercenary")
	await host.get_tree().process_frame
	TestFixtures.check(res, "an empty read tab prints the read empty text",
		panel.empty_visible() and panel.empty_text() == NotificationPanel.EMPTY_READ,
		"visible %s text %s" % [str(panel.empty_visible()), panel.empty_text()])
	panel.set_tab(NotificationPanel.TAB_UNREAD)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an empty unread tab prints the unread empty text",
		panel.empty_visible() and panel.empty_text() == NotificationPanel.EMPTY_UNREAD,
		"visible %s text %s" % [str(panel.empty_visible()), panel.empty_text()])
	panel.set_filter(NotificationCenter.FILTER_ALL)
	await _drop(bell, host)


#Case 4: the two sort orders and the sort button text.
static func _case_sort(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var quiet: NotificationData = _contract_row(CONTRACT_NAME)
	var loud: NotificationData = _loan_row(NotificationData.Urgency.URGENT)
	var middle: NotificationData = _stock_row(STOCK_UP_PCT, 2)
	middle.urgency = NotificationData.Urgency.IMPORTANT
	bell.open_panel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the panel sorts by urgency first",
		panel.sort == NotificationCenter.SORT_URGENCY
			and _ids_of(panel.rows()) == [loud.id, middle.id, quiet.id],
		"ids %s" % str(_ids_of(panel.rows())))
	TestFixtures.check(res, "the sort button prints the urgency order",
		panel.sort_button().text == NotificationSortPanel.SORT_URGENCY_LABEL,
		panel.sort_button().text)
	var orders: Array[StringName] = []
	panel.sort_changed.connect(func(value: StringName) -> void: orders.append(value))
	panel.set_sort(NotificationCenter.SORT_RECENCY)
	await host.get_tree().process_frame
	TestFixtures.check(res, "recency sort puts the newest row first",
		_ids_of(panel.rows()) == [middle.id, loud.id, quiet.id],
		"ids %s" % str(_ids_of(panel.rows())))
	TestFixtures.check(res, "set_sort reports the order once and prints it",
		orders == [NotificationCenter.SORT_RECENCY]
			and panel.sort_button().text == NotificationSortPanel.SORT_RECENCY_LABEL,
		"orders %s text %s" % [str(orders), panel.sort_button().text])
	panel.set_sort(NotificationCenter.SORT_RECENCY)
	TestFixtures.check(res, "setting the order it already uses reports nothing",
		orders.size() == 1, "orders %s" % str(orders))
	TestFixtures.check(res, "the cards follow the sorted rows",
		_ids_of(panel.rows()) == [panel.cards()[0].row_id(), panel.cards()[1].row_id(),
			panel.cards()[2].row_id()], "cards %d" % panel.cards().size())
	panel.set_sort(NotificationCenter.SORT_URGENCY)
	await _drop(bell, host)


#Case 5: every filter option, the button text and the orange style while a kind is picked.
static func _case_filter(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var contract: NotificationData = _contract_row(CONTRACT_NAME)
	var loan: NotificationData = _loan_row()
	var stock: NotificationData = _stock_row(STOCK_UP_PCT, 1)
	bell.open_panel()
	await host.get_tree().process_frame
	var want: Array[String] = [NotificationCenter.FILTER_ALL]
	for kind: String in NotificationData.KINDS:
		want.append(kind)
	var got: Array[String] = []
	for row: Button in panel.filter_popup().rows():
		got.append(row.text)
	TestFixtures.check(res, "the filter popup lists All and every kind in order",
		got == want, "options %s" % str(got))
	TestFixtures.check(res, "the All filter lists every row and prints Filter",
		panel.rows().size() == 3 and panel.filter_label() == "Filter"
			and _box_fill(panel.filter_button()) == NotificationPanel.BLUE2,
		"rows %d label %s" % [panel.rows().size(), panel.filter_label()])
	var picks: Array[String] = []
	panel.filter_changed.connect(func(value: String) -> void: picks.append(value))
	panel.set_filter("Contract")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Contract filter keeps the contract row alone",
		_ids_of(panel.rows()) == [contract.id] and picks == ["Contract"],
		"ids %s picks %s" % [str(_ids_of(panel.rows())), str(picks)])
	TestFixtures.check(res, "a picked kind turns the filter button orange and prints the kind",
		panel.filter_label() == "Contract"
			and _box_fill(panel.filter_button()) == NotificationPanel.ORANGE,
		"label %s fill %s" % [panel.filter_label(), str(_box_fill(panel.filter_button()))])
	panel.set_filter("Finance")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Finance filter keeps the loan and the stock rows",
		_ids_of(panel.rows()) == [loan.id, stock.id]
			or _ids_of(panel.rows()) == [stock.id, loan.id],
		"ids %s" % str(_ids_of(panel.rows())))
	panel.set_filter("Mercenary")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Mercenary filter lists nothing while no type uses that kind",
		panel.rows().is_empty() and panel.cards().is_empty() and panel.empty_visible(),
		"rows %d" % panel.rows().size())
	panel.set_filter("Metrics")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Metrics filter lists nothing while no type uses that kind",
		panel.rows().is_empty() and panel.empty_visible(), "rows %d" % panel.rows().size())
	panel.set_filter(NotificationCenter.FILTER_ALL)
	await host.get_tree().process_frame
	TestFixtures.check(res, "going back to All lists every row and reports every pick",
		panel.rows().size() == 3 and picks == ["Contract", "Finance", "Mercenary", "Metrics",
			NotificationCenter.FILTER_ALL], "rows %d picks %s" % [panel.rows().size(), str(picks)])
	TestFixtures.check(res, "the filter counts follow the kind",
		NotificationCenter.unread_count("Contract") == 1
			and NotificationCenter.unread_count("Finance") == 2
			and NotificationCenter.unread_count() == 3,
		"contract %d finance %d" % [NotificationCenter.unread_count("Contract"),
			NotificationCenter.unread_count("Finance")])
	await _drop(bell, host)


#Case 6: the two popups, their boxes, where they hang and how a pick closes them.
static func _case_popups(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	_contract_row(CONTRACT_NAME)
	bell.open_panel()
	await host.get_tree().process_frame
	var sorter: NotificationSortPanel = panel.sort_popup()
	var shower: NotificationFilterPanel = panel.filter_popup()
	TestFixtures.check(res, "both popups start closed",
		not panel.sort_popup_open() and not panel.filter_popup_open(),
		"sort %s filter %s" % [str(panel.sort_popup_open()), str(panel.filter_popup_open())])
	TestFixtures.check(res, "the sort popup is a 200 wide box headed Sort by with two orders",
		sorter.size.x == NotificationFilterPanel.BOX_WIDTH and sorter.heading_text == "Sort by"
			and sorter.option_count() == 2, "width %.0f heading %s options %d"
			% [sorter.size.x, sorter.heading_text, sorter.option_count()])
	TestFixtures.check(res, "the filter popup is the same box headed Show with five options",
		shower.size.x == NotificationFilterPanel.BOX_WIDTH and shower.heading_text == "Show"
			and shower.option_count() == 5, "width %.0f heading %s options %d"
			% [shower.size.x, shower.heading_text, shower.option_count()])
	TestFixtures.check(res, "both popups draw over the panel at z 45",
		sorter.z_index == NotificationFilterPanel.POPUP_Z
			and shower.z_index == NotificationFilterPanel.POPUP_Z,
		"z %d %d" % [sorter.z_index, shower.z_index])
	panel.toggle_sort_popup()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the sort button opens the sort popup alone",
		panel.sort_popup_open() and not panel.filter_popup_open(),
		"sort %s filter %s" % [str(panel.sort_popup_open()), str(panel.filter_popup_open())])
	var origin: Vector2 = panel.tool_row().global_position - panel.global_position
	TestFixtures.check(res, "the sort popup hangs 36 px below the tool row on its left",
		is_equal_approx(sorter.position.y, origin.y + NotificationPanel.POPUP_DROP)
			and is_equal_approx(sorter.position.x, origin.x),
		"at %s origin %s" % [str(sorter.position), str(origin)])
	panel.toggle_filter_popup()
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening the filter popup closes the sort popup",
		panel.filter_popup_open() and not panel.sort_popup_open(),
		"sort %s filter %s" % [str(panel.sort_popup_open()), str(panel.filter_popup_open())])
	var right: float = origin.x + panel.tool_row().size.x - NotificationPanel.POPUP_WIDTH
	TestFixtures.check(res, "the filter popup hangs from the right of the tool row",
		is_equal_approx(shower.position.x, right), "x %.1f want %.1f" % [shower.position.x, right])
	TestFixtures.check(res, "the picked row wears the orange fill and the ink text",
		shower.row_bg(NotificationCenter.FILTER_ALL) == NotificationFilterPanel.ROW_SELECTED_BG
			and shower.row_fg(NotificationCenter.FILTER_ALL)
				== NotificationFilterPanel.ROW_SELECTED_FG,
		"bg %s" % str(shower.row_bg(NotificationCenter.FILTER_ALL)))
	TestFixtures.check(res, "an unpicked row keeps the dark fill and the cream text",
		shower.row_bg("Contract") == NotificationFilterPanel.ROW_IDLE_BG
			and shower.row_fg("Contract") == NotificationFilterPanel.ROW_IDLE_FG,
		"bg %s" % str(shower.row_bg("Contract")))
	shower.press("Contract")
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking a kind closes the popup and sets the filter",
		not panel.filter_popup_open() and panel.filter == "Contract"
			and shower.selected == "Contract",
		"open %s filter %s" % [str(panel.filter_popup_open()), panel.filter])
	panel.toggle_sort_popup()
	sorter.press(NotificationSortPanel.SORT_RECENCY_LABEL)
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking an order closes the popup and sets the sort",
		not panel.sort_popup_open() and panel.sort == NotificationCenter.SORT_RECENCY,
		"open %s sort %s" % [str(panel.sort_popup_open()), String(panel.sort)])
	sorter.press("Nothing")
	TestFixtures.check(res, "a label the popup does not list is ignored",
		not panel.sort_popup_open() and panel.sort == NotificationCenter.SORT_RECENCY,
		"sort %s" % String(panel.sort))
	panel.toggle_filter_popup()
	bell.close_panel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the panel closes both popups",
		not panel.sort_popup_open() and not panel.filter_popup_open() and not bell.panel_open(),
		"sort %s filter %s" % [str(panel.sort_popup_open()), str(panel.filter_popup_open())])
	panel.set_filter(NotificationCenter.FILTER_ALL)
	panel.set_sort(NotificationCenter.SORT_URGENCY)
	await _drop(bell, host)


#Case 7: pressing an item routes the row out of the bell and never marks it read.
static func _case_open_item(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var row: NotificationData = _contract_row(CONTRACT_NAME)
	bell.open_panel()
	await host.get_tree().process_frame
	var seen: Array[NotificationData] = []
	bell.notification_opened.connect(func(data: NotificationData) -> void: seen.append(data))
	bell.press_item(row.id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing an unread item opens it once with that row",
		seen.size() == 1 and seen[0] == row, "opened %d" % seen.size())
	TestFixtures.check(res, "opening an item closes the panel",
		not bell.panel_open(), "open %s" % str(bell.panel_open()))
	TestFixtures.check(res, "the item leaves the row unread for the HUD to mark",
		not row.read and NotificationCenter.unread_count() == 1,
		"read %s unread %d" % [str(row.read), NotificationCenter.unread_count()])
	bell.press_item(999)
	TestFixtures.check(res, "an id the panel does not list opens nothing", seen.size() == 1,
		"opened %d" % seen.size())
	NotificationCenter.mark_read(row.id)
	bell.open_panel()
	panel.set_tab(NotificationPanel.TAB_READ)
	await host.get_tree().process_frame
	bell.press_item(row.id)
	TestFixtures.check(res, "a read item opens nothing and keeps the panel open",
		seen.size() == 1 and bell.panel_open(),
		"opened %d open %s" % [seen.size(), str(bell.panel_open())])
	await _drop(bell, host)


#Case 8: the X marks the row read inside the panel and opens nothing.
static func _case_mark_read(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var first: NotificationData = _contract_row(CONTRACT_NAME)
	var second: NotificationData = _loan_row()
	bell.open_panel()
	await host.get_tree().process_frame
	var seen: Array[NotificationData] = []
	bell.notification_opened.connect(func(data: NotificationData) -> void: seen.append(data))
	var card: NotificationItem = panel.card_for(first.id)
	TestFixtures.check(res, "an unread card shows its mark read button",
		card != null and card.mark_button() != null and card.mark_button().visible,
		"card %s" % ("null" if card == null else str(card.mark_button() != null)))
	await host.get_tree().process_frame
	var mark: Button = card.mark_button()
	var mark_ok: bool = mark.tooltip_text == "Mark as read" and mark.text == ""
	mark_ok = mark_ok and mark.icon == CloseX.icon(CloseX.SCALE_MINI)
	mark_ok = mark_ok and mark.custom_minimum_size == CloseX.size(CloseX.SCALE_MINI)
	mark_ok = mark_ok and mark.flat and mark.size == Vector2(18.0, 18.0)
	TestFixtures.check(res, "the mark read button is an 18 px mini close with the 12 px x art",
		mark_ok, "text %s min %s size %s" % [mark.text, str(mark.custom_minimum_size),
			str(mark.size)])
	bell.press_mark_read(first.id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "press_mark_read marks the row and opens nothing",
		first.read and seen.is_empty() and bell.panel_open(),
		"read %s opened %d" % [str(first.read), seen.size()])
	TestFixtures.check(res, "the unread tab drops the row it just marked",
		panel.card_for(first.id) == null and panel.cards().size() == 1
			and panel.card_for(second.id) != null, "cards %d" % panel.cards().size())
	panel.set_tab(NotificationPanel.TAB_READ)
	await host.get_tree().process_frame
	var read_card: NotificationItem = panel.card_for(first.id)
	TestFixtures.check(res, "the read tab lists the row and hides its X",
		read_card != null and not read_card.mark_button().visible,
		"card %s" % ("null" if read_card == null else str(read_card.mark_button().visible)))
	bell.press_mark_read(first.id)
	TestFixtures.check(res, "marking a read row again changes nothing",
		NotificationCenter.read_count() == 1 and seen.is_empty(),
		"read %d" % NotificationCenter.read_count())
	await _drop(bell, host)


#Case 9: the unread, hover and read styles of one card.
static func _case_item_style(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var row: NotificationData = _contract_row(CONTRACT_NAME)
	bell.open_panel()
	await host.get_tree().process_frame
	var card: NotificationItem = panel.card_for(row.id)
	TestFixtures.check(res, "an unread card wears the dark fill and the blue ring",
		card.bg_color() == NotificationItem.BG_IDLE
			and card.ring_color() == NotificationItem.RING_IDLE
			and is_equal_approx(card.modulate.a, 1.0),
		"fill %s ring %s" % [str(card.bg_color()), str(card.ring_color())])
	card.set_hovered(true)
	TestFixtures.check(res, "hovering an unread card lifts the fill and turns the ring orange",
		card.bg_color() == NotificationItem.BG_HOVER
			and card.ring_color() == NotificationItem.RING_HOVER,
		"fill %s ring %s" % [str(card.bg_color()), str(card.ring_color())])
	var box: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the card frame is a 2 px ring with 8 px padding",
		box != null and box.border_width_left == NotificationItem.RING_WIDTH
			and box.content_margin_left == float(NotificationItem.PAD),
		"border %d pad %.0f" % [0 if box == null else box.border_width_left,
			0.0 if box == null else box.content_margin_left])
	card.set_hovered(false)
	NotificationCenter.mark_read(row.id)
	panel.set_tab(NotificationPanel.TAB_READ)
	await host.get_tree().process_frame
	var read_card: NotificationItem = panel.card_for(row.id)
	read_card.set_hovered(true)
	TestFixtures.check(res, "a read card fades and keeps the idle fill and ring when hovered",
		is_equal_approx(read_card.modulate.a, NotificationItem.READ_OPACITY)
			and read_card.bg_color() == NotificationItem.BG_IDLE
			and read_card.ring_color() == NotificationItem.RING_IDLE,
		"alpha %.2f fill %s" % [read_card.modulate.a, str(read_card.bg_color())])
	TestFixtures.check(res, "a read card carries the arrow cursor and an unread card the hand",
		read_card.mouse_default_cursor_shape == Control.CURSOR_ARROW,
		"cursor %d" % read_card.mouse_default_cursor_shape)
	TestFixtures.check(res, "the icon box holds a glyph plate for a contract row",
		read_card.icon_glyph() != null, "glyph %s" % str(read_card.icon_glyph() != null))
	var card_face: TextureRect = read_card.icon_glyph().get_child(1) as TextureRect
	TestFixtures.check(res, "a contract row faces the alert cell baked at 32 x 32",
		card_face != null and card_face.texture == Icons.baked("alert", 2, Icons.MODE_PLAIN)
			and card_face.texture.get_size() == Vector2(32.0, 32.0),
		"face %s" % ("null" if card_face == null else str(card_face.texture.get_size())))
	await _drop(bell, host)


#Case 10: the contract body, with the same title for a completed and a failed run.
static func _case_contract_body(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var done: NotificationData = _contract_row(CONTRACT_NAME)
	bell.open_panel()
	await host.get_tree().process_frame
	var card: NotificationItem = panel.card_for(done.id)
	var body: ContractCompletedBody = card.body() as ContractCompletedBody
	TestFixtures.check(res, "a contract row builds the contract body",
		body != null, "body %s" % ("null" if card.body() == null else card.body().get_class()))
	TestFixtures.check(res, "the contract title and name read off the snap",
		card.title_text() == "Contract Complete" and card.name_text() == CONTRACT_NAME
			and done.title_color() == NotificationData.TITLE_CONTRACT,
		"%s / %s" % [card.title_text(), card.name_text()])
	TestFixtures.check(res, "the body shows the difficulty stars at 1 px per art pixel",
		body.stars() != null and is_equal_approx(body.stars().rating, DIFFICULTY)
			and body.stars().star_size == ContractCompletedBody.STAR_SIZE
			and body.stars().custom_minimum_size == Vector2(Icons.stars_width(1), 16.0),
		"rating %.1f" % (0.0 if body.stars() == null else body.stars().rating))
	TestFixtures.check(res, "the reward prints with thousands separators",
		body.reward_text() == "1,250", body.reward_text())
	var failed: NotificationData = _contract_row(CONTRACT_NAME, true)
	await host.get_tree().process_frame
	var failed_card: NotificationItem = panel.card_for(failed.id)
	TestFixtures.check(res, "a failed contract reads the same as a completed one",
		failed_card.title_text() == "Contract Complete"
			and failed.title_color() == NotificationData.TITLE_CONTRACT
			and failed.kind == "Contract",
		"%s %s" % [failed_card.title_text(), str(failed.title_color())])
	TestFixtures.check(res, "the failed row builds the same body with the same reward",
		failed_card.body() is ContractCompletedBody
			and (failed_card.body() as ContractCompletedBody).reward_text() == "1,250",
		"body %s" % ("null" if failed_card.body() == null else failed_card.body().get_class()))
	await _drop(bell, host)


#The loan body of one listed row; a fresh push rebuilds the cards, so never hold an old one.
static func _loan_body(panel: NotificationPanel, id: int) -> LoanOfferBody:
	var card: NotificationItem = panel.card_for(id)
	if card == null:
		return null
	return card.body() as LoanOfferBody


#Case 11: the loan offer body and its live countdown.
static func _case_loan_body(res: Dictionary, host: Node) -> void:
	LoanOfferBody.hours_override = Callable()
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var row: NotificationData = _loan_row()
	bell.open_panel()
	await host.get_tree().process_frame
	var card: NotificationItem = panel.card_for(row.id)
	var body: LoanOfferBody = card.body() as LoanOfferBody
	TestFixtures.check(res, "a loan row builds the loan body",
		body != null, "body %s" % ("null" if card.body() == null else card.body().get_class()))
	TestFixtures.check(res, "the loan title and lender read off the snap",
		card.title_text() == "Loan Offer Received" and card.name_text() == LOAN_LENDER
			and row.title_color() == NotificationData.TITLE_LOAN,
		"%s / %s" % [card.title_text(), card.name_text()])
	TestFixtures.check(res, "the offer amount prints with thousands separators",
		body.amount_text() == "12,500", body.amount_text())
	TestFixtures.check(res, "the terms print the whole percent and the months",
		body.terms_text() == "12% - 6 months", body.terms_text())
	TestFixtures.check(res, "without a live offer the countdown hides",
		not body.remaining_visible() and body.remaining_text() == "",
		"visible %s text %s" % [str(body.remaining_visible()), body.remaining_text()])
	TestFixtures.check(res, "the finance layer still seeds the live offer id",
		not FinanceManager.offer(LIVE_OFFER_ID).is_empty(),
		"offer %s" % str(FinanceManager.offer(LIVE_OFFER_ID)))
	var live_row: NotificationData = _loan_row(NotificationData.Urgency.IMPORTANT, LIVE_OFFER_ID)
	await host.get_tree().process_frame
	var live_offer_body: LoanOfferBody = _loan_body(panel, live_row.id)
	TestFixtures.check(res, "a seeded live offer on the real finance layer shows its countdown",
		live_offer_body != null and live_offer_body.remaining_visible()
			and live_offer_body.remaining_text() != "",
		"body %s" % ("null" if live_offer_body == null else live_offer_body.remaining_text()))
	#The push above rebuilt the list, so the card and body from before it are gone; refetch.
	body = _loan_body(panel, row.id)
	LoanOfferBody.hours_override = func(_id: int) -> float: return HOURS_PLURAL
	body.apply(row)
	TestFixtures.check(res, "a live offer prints the days and hours left",
		body.remaining_visible() and body.remaining_text() == "2 Days, 2 Hours to accept",
		body.remaining_text())
	LoanOfferBody.hours_override = func(_id: int) -> float: return HOURS_SINGULAR
	body.apply(row)
	TestFixtures.check(res, "one day and one hour print in the singular",
		body.remaining_text() == "1 Day, 1 Hour to accept", body.remaining_text())
	TestFixtures.check(res, "an important row prints the countdown in sky blue",
		body.remaining_color() == LoanOfferBody.TERMS_COLOR, str(body.remaining_color()))
	var urgent: NotificationData = _loan_row(NotificationData.Urgency.URGENT)
	await host.get_tree().process_frame
	var urgent_body: LoanOfferBody = _loan_body(panel, urgent.id)
	TestFixtures.check(res, "an urgent row prints the countdown in red",
		urgent_body != null and urgent_body.remaining_color() == LoanOfferBody.URGENT_COLOR,
		"body %s" % str(urgent_body != null))
	LoanOfferBody.hours_override = func(_id: int) -> float: return -1.0
	var live: LoanOfferBody = _loan_body(panel, row.id)
	if live != null:
		live.apply(row)
	TestFixtures.check(res, "an offer that is gone hides the countdown instead of lying",
		live != null and not live.remaining_visible() and live.remaining_text() == "",
		"body %s" % str(live != null))
	LoanOfferBody.hours_override = func(_id: int) -> float: return 0.0
	var zero_live: LoanOfferBody = _loan_body(panel, row.id)
	if zero_live != null:
		zero_live.apply(row)
	TestFixtures.check(res, "a stub with zero hours also hides the countdown",
		zero_live != null and not zero_live.remaining_visible() and zero_live.remaining_text() == "",
		"body %s" % str(zero_live != null))
	LoanOfferBody.hours_override = Callable()
	await _drop(bell, host)


#Case 12: the stock move body on a rise and on a fall.
static func _case_stock_body(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var up: NotificationData = _stock_row(STOCK_UP_PCT, 2)
	bell.open_panel()
	await host.get_tree().process_frame
	var card: NotificationItem = panel.card_for(up.id)
	var body: StockMoveBody = card.body() as StockMoveBody
	TestFixtures.check(res, "a stock row builds the stock body",
		body != null, "body %s" % ("null" if card.body() == null else card.body().get_class()))
	TestFixtures.check(res, "a rising title reads the band as five percent steps in green",
		card.title_text() == "Stock Up 10%" and up.title_color() == NotificationData.TITLE_STOCK_UP
			and card.name_text() == STOCK_COMPANY,
		"%s %s" % [card.title_text(), str(up.title_color())])
	TestFixtures.check(res, "a rising body prints the signed percent since the last check",
		body.line_text() == "+3.2% since you last checked"
			and body.line_color() == NotificationData.TITLE_STOCK_UP, body.line_text())
	var down: NotificationData = _stock_row(STOCK_DOWN_PCT, -1)
	await host.get_tree().process_frame
	var down_card: NotificationItem = panel.card_for(down.id)
	var down_body: StockMoveBody = down_card.body() as StockMoveBody
	TestFixtures.check(res, "a falling title turns red and keeps the step count",
		down_card.title_text() == "Stock Down 5%"
			and down.title_color() == NotificationData.TITLE_STOCK_DOWN,
		"%s %s" % [down_card.title_text(), str(down.title_color())])
	TestFixtures.check(res, "a falling body prints a minus sign in red",
		down_body.line_text() == "-4.0% since you last checked"
			and down_body.line_color() == NotificationData.TITLE_STOCK_DOWN,
		down_body.line_text())
	var up_card: NotificationItem = panel.card_for(up.id)
	TestFixtures.check(res, "the stock rows carry the icon glyph of their direction",
		up_card != null and up_card.icon_glyph() != null and down_card.icon_glyph() != null,
		"up %s down %s" % [str(up_card != null), str(down_card.icon_glyph() != null)])
	var up_face: TextureRect = up_card.icon_glyph().get_child(1) as TextureRect
	var down_face: TextureRect = down_card.icon_glyph().get_child(1) as TextureRect
	var arrows_ok: bool = up_face.texture == Icons.baked("trend_up", 4, Icons.MODE_GRAY, true)
	arrows_ok = arrows_ok and down_face.texture == Icons.baked("trend_down", 4, Icons.MODE_GRAY,
		true)
	arrows_ok = arrows_ok and up_face.texture.get_size() == Vector2(28.0, 32.0)
	arrows_ok = arrows_ok and down_face.texture.get_size() == Vector2(28.0, 32.0)
	TestFixtures.check(res, "each stock face is its own grey arrow baked at 28 x 32",
		arrows_ok, "up %s down %s" % [str(up_face.texture.get_size()),
			str(down_face.texture.get_size())])
	TestFixtures.check(res, "each stock face wears the title colour of its row",
		up_face.modulate == up.title_color() and down_face.modulate == down.title_color(),
		"up %s down %s" % [str(up_face.modulate), str(down_face.modulate)])
	await _drop(bell, host)


#Case 13: a type the panel does not know renders without a body and never errors.
static func _case_unknown_type(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var row: NotificationData = NotificationCenter.push(UNKNOWN_TYPE, 3,
		{"name": UNKNOWN_NAME}, NotificationData.Urgency.IMPORTANT, "Metrics")
	bell.open_panel()
	await host.get_tree().process_frame
	var card: NotificationItem = panel.card_for(row.id)
	TestFixtures.check(res, "an unknown type still builds a card",
		card != null and panel.cards().size() == 1, "cards %d" % panel.cards().size())
	TestFixtures.check(res, "an unknown type titles itself and keeps the cream text",
		card.title_text() == String(UNKNOWN_TYPE)
			and row.title_color() == NotificationData.TITLE_UNKNOWN,
		"%s %s" % [card.title_text(), str(row.title_color())])
	TestFixtures.check(res, "an unknown type still prints its name line",
		card.name_text() == UNKNOWN_NAME, card.name_text())
	TestFixtures.check(res, "an unknown type builds no body and keeps its caller kind",
		card.body() == null and row.kind == "Metrics",
		"body %s kind %s" % [str(card.body() != null), row.kind])
	TestFixtures.check(res, "an unknown type still fills the footer",
		card.footer() != null and card.footer().urgency_text() == "Important",
		"urgency %s" % ("none" if card.footer() == null else card.footer().urgency_text()))
	await _drop(bell, host)


#Case 14: the footer date, time and urgency.
static func _case_footer(res: Dictionary, host: Node) -> void:
	var bell: NotificationBell = await _bell(host)
	var panel: NotificationPanel = bell.panel()
	var row: NotificationData = _contract_row(CONTRACT_NAME)
	var urgent: NotificationData = _loan_row(NotificationData.Urgency.URGENT)
	bell.open_panel()
	await host.get_tree().process_frame
	var footer: NotificationFooter = panel.card_for(row.id).footer()
	var want: String = TrynnCalendar.date_text(row.minute) + " - "
	want += TrynnCalendar.time_text(row.minute)
	TestFixtures.check(res, "the footer prints the game date and time of the row",
		footer != null and footer.when_text() == want and row.when_text() == want,
		"when %s want %s" % ["none" if footer == null else footer.when_text(), want])
	TestFixtures.check(res, "the footer names the urgency in its own colour",
		footer.urgency_text() == "Informational"
			and row.urgency_color() == NotificationData.URGENCY_COLORS[0],
		"%s %s" % [footer.urgency_text(), str(row.urgency_color())])
	var loud: NotificationFooter = panel.card_for(urgent.id).footer()
	TestFixtures.check(res, "an urgent row names Urgent in red",
		loud.urgency_text() == "Urgent"
			and urgent.urgency_color() == NotificationData.URGENCY_COLORS[2],
		"%s %s" % [loud.urgency_text(), str(urgent.urgency_color())])
	await _drop(bell, host)


#Case 15: the glyph sizes, the separate up and down arrows, the shadow plate and the cache.
static func _case_glyphs(res: Dictionary, host: Node) -> void:
	await host.get_tree().process_frame
	var bell_two: ImageTexture = Icons.baked("bell", NotificationBell.GLYPH_SCALE,
		Icons.MODE_PLAIN)
	TestFixtures.check(res, "the bell glyph bakes the 16 x 16 cell at 2 px per art pixel",
		bell_two.get_size() == Vector2(32, 32), str(bell_two.get_size()))
	TestFixtures.check(res, "the loan note is the note cell tinted gold at 4 px per art pixel",
		Icons.tinted("note", NotificationItem.LOAN_GLYPH, 4, true).get_size() == Vector2(20, 36),
		str(Icons.tinted("note", NotificationItem.LOAN_GLYPH, 4, true).get_size()))
	var up_img: Image = Icons.image("trend_up", true)
	var down_img: Image = Icons.image("trend_down", true)
	TestFixtures.check(res, "both trend arrows are 7 x 8 cells of their own",
		Icons.size("trend_up") == Vector2i(7, 8) and Icons.size("trend_down") == Vector2i(7, 8),
		"%s %s" % [str(Icons.size("trend_up")), str(Icons.size("trend_down"))])
	var same: bool = true
	var mirrored: bool = true
	for y: int in 8:
		for x: int in 7:
			if up_img.get_pixel(x, y) != down_img.get_pixel(x, y):
				same = false
			if up_img.get_pixel(x, y) != down_img.get_pixel(x, 7 - y):
				mirrored = false
	TestFixtures.check(res, "the fall arrow is separate art, not a flip of the rise arrow",
		not same and not mirrored, "same %s mirrored %s" % [str(same), str(mirrored)])
	var stripes: ImageTexture = NotifyGlyphs.stripes(NotificationItem.STRIPE_FILL,
		NotificationItem.STRIPE_BACK)
	TestFixtures.check(res, "the icon stripes tile in 8 px squares",
		stripes.get_size() == Vector2(NotifyGlyphs.STRIPE_TILE, NotifyGlyphs.STRIPE_TILE),
		str(stripes.get_size()))
	var plate: Control = NotifyGlyphs.shadowed(bell_two)
	TestFixtures.check(res, "a shadowed glyph adds the 2 px drop step",
		plate.custom_minimum_size == Vector2(34, 34) and plate.get_child_count() == 2,
		"%s children %d" % [str(plate.custom_minimum_size), plate.get_child_count()])
	var shadow: TextureRect = plate.get_child(0) as TextureRect
	var face: TextureRect = plate.get_child(1) as TextureRect
	TestFixtures.check(res, "the shadow sits behind the face in ink",
		shadow.name == "Shadow" and face.name == "Face"
			and shadow.modulate == NotifyGlyphs.SHADOW_COLOR
			and shadow.position == Vector2(NotifyGlyphs.SHADOW_STEP, NotifyGlyphs.SHADOW_STEP),
		"%s %s at %s" % [shadow.name, str(shadow.modulate), str(shadow.position)])
	TestFixtures.check(res, "both plates keep the art centred and never stretch it",
		shadow.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED
			and face.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED,
		"%d %d" % [shadow.stretch_mode, face.stretch_mode])
	plate.queue_free()
	var tinted_plate: Control = NotifyGlyphs.shadowed(bell_two, NotifyGlyphs.SHADOW_STEP,
		NotificationItem.LOAN_GLYPH)
	var tinted_shadow: TextureRect = tinted_plate.get_child(0) as TextureRect
	var tinted_face: TextureRect = tinted_plate.get_child(1) as TextureRect
	TestFixtures.check(res, "a face tint colours the face alone and leaves the shadow ink",
		tinted_face.modulate == NotificationItem.LOAN_GLYPH
			and tinted_shadow.modulate == NotifyGlyphs.SHADOW_COLOR,
		"%s %s" % [str(tinted_face.modulate), str(tinted_shadow.modulate)])
	tinted_plate.queue_free()
	TestFixtures.check(res, "a stripe tile of the same colours comes from the cache",
		NotifyGlyphs.stripes(NotificationItem.STRIPE_FILL, NotificationItem.STRIPE_BACK) == stripes,
		"cache miss")
	NotifyGlyphs.clear_cache()
	TestFixtures.check(res, "clear_cache drops the built tiles",
		NotifyGlyphs.stripes(NotificationItem.STRIPE_FILL, NotificationItem.STRIPE_BACK) != stripes,
		"cache kept")


#Case 16: the panel stays inside the 1280 x 720 frame with the bell at the top right.
static func _case_frame_fit(res: Dictionary, host: Node) -> void:
	NotificationCenter.reset()
	var frame := Control.new()
	frame.size = FRAME_SIZE
	host.add_child(frame)
	var scene: PackedScene = load(BELL_SCENE) as PackedScene
	var bell: NotificationBell = scene.instantiate() as NotificationBell
	frame.add_child(bell)
	bell.position = BELL_AT
	_contract_row(CONTRACT_NAME)
	bell.open_panel()
	await host.get_tree().process_frame
	var rect: Rect2 = bell.panel().get_global_rect()
	TestFixtures.check(res, "the panel opens 756, 86 with the bell at 1140, 16",
		rect.position == PANEL_AT and rect.size == NotificationPanel.PANEL_SIZE,
		"rect %s" % str(rect))
	TestFixtures.check(res, "the panel stays inside the 1280 x 720 frame",
		rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= FRAME_SIZE.x
			and rect.end.y <= FRAME_SIZE.y, "rect %s" % str(rect))
	var scroll: ScrollContainer = bell.panel().scroll()
	TestFixtures.check(res, "only the list scrolls and it scrolls up and down alone",
		scroll != null and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"scroll %s" % ("null" if scroll == null else str(scroll.horizontal_scroll_mode)))
	TestFixtures.check(res, "the panel never grows past its 440 x 520 box",
		bell.panel().size == NotificationPanel.PANEL_SIZE, str(bell.panel().size))
	frame.queue_free()
	await host.get_tree().process_frame


#Case 17: the dot geometry and the paint constants the prototype fixes.
static func _case_dot_shape(res: Dictionary) -> void:
	TestFixtures.check(res, "the dot art is the 8 x 8 atlas cell",
		Icons.size("dot") == Vector2i(8, 8)
			and Icons.tex("dot", true).get_size() == Vector2(8, 8),
		"%s %s" % [str(Icons.size("dot")), str(Icons.tex("dot", true).get_size())])
	var dot_img: Image = Icons.image("dot", true)
	var lit: int = 0
	for y: int in 8:
		for x: int in 8:
			if dot_img.get_pixel(x, y).a > 0.0:
				lit += 1
	TestFixtures.check(res, "the dot cell lights 52 of its 64 pixels",
		lit == 52, "lit %d" % lit)
	TestFixtures.check(res, "the dot is 10 x 10 and its frame is 28 x 28 at a 2 px cell",
		NotificationDot.DOT_SIZE == Vector2(10, 10) and NotificationDot.FRAME_SIZE == Vector2(28, 28)
			and NotificationDot.CELL == 2, "dot %s frame %s cell %d"
			% [str(NotificationDot.DOT_SIZE), str(NotificationDot.FRAME_SIZE), NotificationDot.CELL])
	TestFixtures.check(res, "the fill, outline and outline width match the prototype",
		NotificationDot.DOT_COLOR == Color("#e8583f")
			and NotificationDot.OUTLINE_COLOR == Color("#0a0f1c")
			and NotificationDot.OUTLINE_WIDTH == 2.0,
		"fill %s outline %s width %.1f" % [str(NotificationDot.DOT_COLOR),
			str(NotificationDot.OUTLINE_COLOR), NotificationDot.OUTLINE_WIDTH])
	TestFixtures.check(res, "the four ring sizes and their peaks come straight off the prototype",
		NotificationDot.RING_CELLS == PackedInt32Array([8, 10, 12, 14])
			and NotificationDot.RING_PEAKS == PackedFloat32Array([0.9, 0.75, 0.55, 0.35]),
		"cells %s peaks %s" % [str(NotificationDot.RING_CELLS), str(NotificationDot.RING_PEAKS)])
	var dot := NotificationDot.new()
	TestFixtures.check(res, "dot_rect is the 16 x 16 lit box centred in the 28 x 28 control",
		dot.dot_rect() == Rect2(Vector2(6, 6), Vector2(16, 16)), str(dot.dot_rect()))
	TestFixtures.check(res, "frame_rect fills the control from its own origin",
		dot.frame_rect() == Rect2(Vector2(0, 0), Vector2(28, 28))
			and dot.frame_rect().encloses(dot.dot_rect()), str(dot.frame_rect()))


#Case 18: the ring and blink timing the prototype's keyframes give in CSS percents.
static func _case_dot_pulse_math(res: Dictionary) -> void:
	TestFixtures.check(res, "a ring is dark at phase 0 and peaks right at its 8 percent rise",
		is_equal_approx(NotificationDot.ring_alpha(0, 0.0), 0.0)
			and is_equal_approx(NotificationDot.ring_alpha(0, 0.08), 0.9),
		"%.3f %.3f" % [NotificationDot.ring_alpha(0, 0.0), NotificationDot.ring_alpha(0, 0.08)])
	TestFixtures.check(res, "ring 0 is back to dark by the 55 percent mark of its cycle",
		is_equal_approx(NotificationDot.ring_alpha(0, 0.55), 0.0),
		"%.3f" % NotificationDot.ring_alpha(0, 0.55))
	TestFixtures.check(res, "ring 1 peaks a sixth of a cycle later at its own 75 percent peak",
		is_equal_approx(NotificationDot.ring_alpha(1, 0.08 + 1.0 / 6.0), 0.75),
		"%.3f" % NotificationDot.ring_alpha(1, 0.08 + 1.0 / 6.0))
	TestFixtures.check(res, "ring 3 keeps its own lower 35 percent peak",
		is_equal_approx(NotificationDot.ring_alpha(3, 0.08 + 3.0 / 6.0), 0.35),
		"%.3f" % NotificationDot.ring_alpha(3, 0.08 + 3.0 / 6.0))
	TestFixtures.check(res, "the dot dims to 0.95 gain at phase 0 and at phase 1 alike",
		is_equal_approx(NotificationDot.blink_gain(0.0), 0.95)
			and is_equal_approx(NotificationDot.blink_gain(1.0), 0.95),
		"%.3f %.3f" % [NotificationDot.blink_gain(0.0), NotificationDot.blink_gain(1.0)])
	TestFixtures.check(res, "the dot brightens to 1.4 gain at the half phase",
		is_equal_approx(NotificationDot.blink_gain(0.5), 1.4),
		"%.3f" % NotificationDot.blink_gain(0.5))
	TestFixtures.check(res, "the blink eases through the quarter phase at 1.175 gain",
		is_equal_approx(NotificationDot.blink_gain(0.25), 1.175),
		"%.3f" % NotificationDot.blink_gain(0.25))


#Case 19: the clock connection lives only while the dot is in the tree, and attach() places it.
static func _case_dot_lifecycle(res: Dictionary, host: Node) -> void:
	var dot := NotificationDot.new()
	host.add_child(dot)
	await host.get_tree().process_frame
	var cb: Callable = dot._on_pulse
	TestFixtures.check(res, "entering the tree subscribes the dot to the shared pulse clock",
		PulseClock.pulse.is_connected(cb), "connected %s" % str(PulseClock.pulse.is_connected(cb)))
	dot.queue_free()
	await host.get_tree().process_frame
	TestFixtures.check(res, "leaving the tree drops the subscription",
		not PulseClock.pulse.is_connected(cb),
		"connected %s" % str(PulseClock.pulse.is_connected(cb)))
	var plain: Control = Control.new()
	host.add_child(plain)
	var default_dot: NotificationDot = NotificationDot.attach(plain)
	TestFixtures.check(res, "attach() with no corner pins the dot 2 px inside the top right",
		default_dot.anchor_left == 1.0 and default_dot.anchor_right == 1.0
			and default_dot.anchor_top == 0.0 and default_dot.offset_right == -2.0
			and default_dot.offset_left == -30.0 and default_dot.offset_top == 2.0
			and default_dot.offset_bottom == 30.0,
		"anchor %.1f offsets %.1f %.1f" % [default_dot.anchor_left, default_dot.offset_left,
			default_dot.offset_right])
	var left_dot: NotificationDot = NotificationDot.attach(plain, Vector2(6, 2), CORNER_TOP_LEFT)
	TestFixtures.check(res, "attach() with CORNER_TOP_LEFT pins inside the opposite corner",
		left_dot.anchor_left == 0.0 and left_dot.anchor_right == 0.0
			and left_dot.offset_left == 6.0 and left_dot.offset_right == 34.0
			and left_dot.offset_top == 2.0 and left_dot.offset_bottom == 30.0,
		"anchor %.1f offsets %.1f %.1f" % [left_dot.anchor_left, left_dot.offset_left,
			left_dot.offset_right])
	plain.queue_free()
	await host.get_tree().process_frame


#Case 20: every fixed caller puts its dot on the corner the prototype draws it on.
static func _case_dot_placements(res: Dictionary, host: Node) -> void:
	var fine := FineRow.new()
	host.add_child(fine)
	await host.get_tree().process_frame
	var fine_data := FineData.new()
	fine_data.unread = true
	fine.entry = fine_data
	TestFixtures.check(res, "an unread fine row centres its dot on the top left corner",
		fine.dot.on and fine.dot.anchor_left == 0.0 and fine.dot.anchor_top == 0.0
			and fine.dot.offset_left == 2.0 and fine.dot.offset_top == 2.0,
		"anchor %.1f offset %.1f" % [fine.dot.anchor_left, fine.dot.offset_left])
	fine.notification(Container.NOTIFICATION_SORT_CHILDREN)
	TestFixtures.check(res, "a fine row's dot keeps its corner through the panel's own child sort",
		fine.dot.anchor_left == 0.0 and fine.dot.offset_left == 2.0
			and fine.dot.offset_top == 2.0,
		"anchor %.1f offset %.1f" % [fine.dot.anchor_left, fine.dot.offset_left])
	fine.queue_free()
	await host.get_tree().process_frame
	var captured := CapturedRow.new()
	host.add_child(captured)
	await host.get_tree().process_frame
	var capture_data := CaptureData.new()
	capture_data.unread = true
	captured.entry = capture_data
	TestFixtures.check(res, "an unread captured row centres its dot on the top left corner too",
		captured.dot.on and captured.dot.anchor_left == 0.0 and captured.dot.offset_left == 2.0
			and captured.dot.offset_top == 2.0,
		"anchor %.1f offset %.1f" % [captured.dot.anchor_left, captured.dot.offset_left])
	captured.notification(Container.NOTIFICATION_SORT_CHILDREN)
	TestFixtures.check(res, "a captured row's dot keeps its corner through the panel's own sort",
		captured.dot.anchor_left == 0.0 and captured.dot.offset_left == 2.0
			and captured.dot.offset_top == 2.0,
		"anchor %.1f offset %.1f" % [captured.dot.anchor_left, captured.dot.offset_left])
	captured.queue_free()
	await host.get_tree().process_frame
	var violation := ViolationRow.new()
	host.add_child(violation)
	await host.get_tree().process_frame
	violation.dot.on = true
	TestFixtures.check(res, "an unread violation row centres its dot on the top left corner",
		violation.dot.on and violation.dot.anchor_left == 0.0 and violation.dot.offset_left == 2.0
			and violation.dot.offset_top == 2.0,
		"anchor %.1f offset %.1f" % [violation.dot.anchor_left, violation.dot.offset_left])
	violation.notification(Container.NOTIFICATION_SORT_CHILDREN)
	TestFixtures.check(res, "a violation row's dot keeps its corner through the panel's own sort",
		violation.dot.anchor_left == 0.0 and violation.dot.offset_left == 2.0
			and violation.dot.offset_top == 2.0,
		"anchor %.1f offset %.1f" % [violation.dot.anchor_left, violation.dot.offset_left])
	violation.queue_free()
	await host.get_tree().process_frame
	var loan_scene: PackedScene = load(LoanCard.SCENE_PATH) as PackedScene
	var loan: LoanCard = loan_scene.instantiate() as LoanCard
	host.add_child(loan)
	await host.get_tree().process_frame
	loan.set_row({"kind": LoanRows.KIND_OFFER, "unread": true, "text": {}, "amount": 0,
		"monthly": 0, "hours": 0.0})
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unread loan offer hangs its dot on the Review Offer button",
		loan.dot_on() and loan.dot().get_parent() == loan.action_button(),
		"parent %s" % str(loan.dot().get_parent()))
	TestFixtures.check(res, "the loan offer dot sits inside the button's own top right corner",
		loan.dot().anchor_left == 1.0 and loan.dot().anchor_right == 1.0
			and loan.dot().offset_right == -2.0
			and loan.dot().offset_left == -2.0 - NotificationDot.FRAME_SIZE.x
			and loan.dot().offset_top == 2.0
			and loan.dot().offset_bottom == 2.0 + NotificationDot.FRAME_SIZE.y,
		"anchor %.1f offsets %.1f %.1f" % [loan.dot().anchor_left, loan.dot().offset_left,
			loan.dot().offset_right])
	loan.notification(Container.NOTIFICATION_SORT_CHILDREN)
	TestFixtures.check(res, "a loan card's dot keeps its corner through the panel's own child sort",
		loan.dot().anchor_left == 1.0 and loan.dot().offset_right == -2.0
			and loan.dot().offset_left == -2.0 - NotificationDot.FRAME_SIZE.x
			and loan.dot().offset_top == 2.0,
		"anchor %.1f offsets %.1f %.1f" % [loan.dot().anchor_left, loan.dot().offset_left,
			loan.dot().offset_right])
	loan.queue_free()
	await host.get_tree().process_frame
	var item_scene: PackedScene = load("res://Scenes/GUI/Finance/Invest/InvestCompanyItem.tscn") \
		as PackedScene
	var item: InvestCompanyItem = item_scene.instantiate() as InvestCompanyItem
	host.add_child(item)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an invest row pins its dot inside its own top right corner",
		item.dot() != null and item.dot().anchor_left == 1.0 and item.dot().anchor_right == 1.0
			and item.dot().offset_right == -2.0
			and item.dot().offset_left == -2.0 - NotificationDot.FRAME_SIZE.x
			and item.dot().offset_top == 2.0
			and item.dot().offset_bottom == 2.0 + NotificationDot.FRAME_SIZE.y,
		"anchor %.1f offsets %.1f %.1f" % [item.dot().anchor_left, item.dot().offset_left,
			item.dot().offset_right])
	item.queue_free()
	await host.get_tree().process_frame
	var hiring := HiringDot.new()
	host.add_child(hiring)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the hiring dot keeps its own 28 x 28 box for the applicant card",
		hiring.custom_minimum_size == HiringDot.DOT_SIZE and hiring.size == Vector2(28, 28),
		"box %s" % str(hiring.custom_minimum_size))
	hiring.queue_free()
	await host.get_tree().process_frame
