class_name GuiFinanceTests
extends RefCounted

#Run: godot --headless --path . with the --gui-finance-tests flag.
#The My Finance window: the frame, the five tabs and their dots, the page host, the invest only
#mode, the modal layer and the whole Overview page against FinanceLedger. The four pages of the
#other screens are never loaded: every page path points at FinanceStubPage or at nothing.
#Every case drives the public helpers, because a synthetic click never reaches a button headless.

const VIEWER: PackedScene = preload("res://Scenes/GUI/Finance/FinanceViewer.tscn")
const STUB_PATH: String = "res://Scenes/GUI/Finance/FinanceStubPage.tscn"
#A path no build holds, so the host has to fall back on the placeholder.
const MISSING_PATH: String = "res://Scenes/GUI/Finance/Nowhere/NoSuchTab.tscn"
const PAGE_KEYS: Array[StringName] = [&"loans", &"payroll", &"hiring", &"invest"]
const LABELS: Array[String] = ["Overview", "Loans", "Payroll", "Hiring", "Invest"]
const TIPS: Array[String] = ["Your finances at a glance", "Manage and request loans",
	"Manage merc pay", "Review mercs who applied to your guild",
	"Invest notes in company stocks"]
const STAT_KEYS: Array[String] = ["notes", "income", "expenses", "net"]
const EXPENSE_KEYS: Array[String] = ["payroll", "loans", "guild", "travel", "ads"]
const INCOME_KEY: String = "income"
const TOTAL_KEY: String = "total"
const EXPENSES_SUB: String = "Payroll, loans, guild, travel, ads"
const TAB_ROW_HEIGHT: float = 44.0
const TOP_LINE_HEIGHT: float = 4.0
const TAB_ICON_SCALE: int = 2
const TAB_ICON_CELL: int = 16
const TAB_ICON_IDS: Array[String] = ["eye", "piggy", "money_bag", "add_person", "invest"]
const PAGE_PAD: int = 14
const TAB_GAP: int = 8
const FRAME_BG: Color = Color("#101a30")
const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
#More rows than the list shows, so the cap of a hundred is read.
const OVER_CAP: int = 120
const FUNDS: int = 20000
const SPEND_NOTES: int = 120
const FINE_NOTES: int = 40
const OFFER_ID: int = 42
const COMPANY_ID: int = 7


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var bank: int = GameState.bank_notes
	_fresh()
	await host.get_tree().process_frame
	await _case_frame(res, host)
	await _case_tabs(res, host)
	await _case_start_tab(res, host)
	await _case_open_tab(res, host)
	await _case_pages(res, host)
	await _case_entries(res, host)
	await _case_invest_only(res, host)
	await _case_dots(res, host)
	await _case_stats(res, host)
	await _case_projection(res, host)
	await _case_projection_zero_expense(res, host)
	await _case_expenses(res, host)
	await _case_transactions(res, host)
	await _case_modal_layer(res, host)
	CampaignClock.minutes = clock
	GameState.bank_notes = bank
	NotificationCenter.reset()
	PromotionsManager.reset()
	SubscriptionManager.reset()
	FinanceLedger.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI FINANCE")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.reset()
	NotificationCenter.reset()
	PromotionsManager.reset()
	FinanceLedger.reset()


#One window with every page of another screen pointed at one path of this suite.
static func _make(host: Node, solo: bool, start: FinanceViewer.Tab, path: String) -> FinanceViewer:
	var viewer: FinanceViewer = VIEWER.instantiate() as FinanceViewer
	viewer.start_tab = start
	viewer.invest_only = solo
	for key: StringName in PAGE_KEYS:
		viewer.set_page_path(key, path)
	host.add_child(viewer)
	return viewer


static func _drop(viewer: FinanceViewer) -> void:
	var parent: Node = viewer.get_parent()
	if parent != null:
		parent.remove_child(viewer)
	viewer.queue_free()


static func _stub_of(viewer: FinanceViewer, key: StringName) -> FinanceStubPage:
	return viewer.page(key) as FinanceStubPage


#Leaves n of the seeded campaigns ongoing, which is what the Ads row counts.
static func _set_promos(n: int) -> void:
	PromotionsManager.reset()
	var left: int = n
	for campaign: CampaignData in PromotionsManager.campaigns:
		if not campaign.infinite:
			continue
		if left > 0:
			left -= 1
		else:
			campaign.infinite = false


static func _set_unseen(flag: bool) -> void:
	for applicant: ApplicantData in PromotionsManager.applicants:
		applicant.unseen = flag


#The value text a projection row is expected to show: income leads with a plus, an expense with
#a minus, and the notes and total rows print their own sign.
static func _want_text(key: String, amount: int) -> String:
	if key == INCOME_KEY:
		return "+" + NotesLabel.format_amount(absi(amount))
	if EXPENSE_KEYS.has(key):
		return "-" + NotesLabel.format_amount(absi(amount))
	return NotesLabel.format_amount(amount)


static func _want_color(key: String, amount: int) -> Color:
	if key == INCOME_KEY:
		return GREEN
	if EXPENSE_KEYS.has(key):
		return RED
	if key == TOTAL_KEY:
		return GREEN if amount >= 0 else RED
	return CREAM


static func _keys_of(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(String(row["key"]))
	return out


static func _row_of(rows: Array[Dictionary], key: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row["key"]) == key:
			return row
	return {}


static func _count_scrolls(node: Node) -> int:
	var found: int = 1 if node is ScrollContainer else 0
	for child: Node in node.get_children():
		found += _count_scrolls(child)
	return found


static func _count_floating(node: Node) -> int:
	var found: int = 0
	if node is CanvasLayer:
		found += 1
	var control: Control = node as Control
	if control != null and control.top_level:
		found += 1
	for child: Node in node.get_children():
		found += _count_floating(child)
	return found


#Case 1: the frame the window draws, before any page is asked for.
static func _case_frame(res: Dictionary, host: Node) -> void:
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var frame: Panel = viewer.get_node_or_null("Frame") as Panel
	var style: StyleBoxFlat = null
	if frame != null:
		style = frame.get_theme_stylebox("panel") as StyleBoxFlat
	TestFixtures.check(res, "the frame paints the dark blue of the prototype",
		style != null and style.bg_color.is_equal_approx(FRAME_BG),
		"style %s" % ["none" if style == null else str(style.bg_color)])
	TestFixtures.check(res, "an orange line runs over the content panel",
		viewer.top_line.color.is_equal_approx(ORANGE)
			and is_equal_approx(viewer.top_line.custom_minimum_size.y, TOP_LINE_HEIGHT),
		"%s at %.0f px" % [str(viewer.top_line.color), viewer.top_line.custom_minimum_size.y])
	var pad: MarginContainer = viewer.page_host.get_parent() as MarginContainer
	TestFixtures.check(res, "the content panel pads its page by 14 px",
		pad != null and pad.get_theme_constant("margin_left") == PAGE_PAD
			and pad.get_theme_constant("margin_bottom") == PAGE_PAD,
		"pad %d" % [0 if pad == null else pad.get_theme_constant("margin_left")])
	TestFixtures.check(res, "the tab row stands 44 px tall with a gap of eight",
		is_equal_approx(viewer.tab_row.custom_minimum_size.y, TAB_ROW_HEIGHT)
			and viewer.tab_row.get_theme_constant("separation") == TAB_GAP,
		"%.0f px, gap %d" % [viewer.tab_row.custom_minimum_size.y,
			viewer.tab_row.get_theme_constant("separation")])
	TestFixtures.check(res, "the page host clips what runs past its edge",
		viewer.page_host.clip_contents, "clip %s" % viewer.page_host.clip_contents)
	TestFixtures.check(res, "the window root is 1280 by 644 under the bottom bar",
		viewer.custom_minimum_size == Vector2(1280.0, 644.0),
		"%s" % [viewer.custom_minimum_size])
	_drop(viewer)


#Case 2: the five tabs, their texts and their icons.
static func _case_tabs(res: Dictionary, host: Node) -> void:
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var order: Array[String] = []
	for child: Node in viewer.tab_row.get_children():
		order.append((child as TabButton).label)
	TestFixtures.check(res, "the tab row holds the five tabs of the window in order",
		order == LABELS, "got %s" % str(order))
	var bad: Array[String] = []
	for i: int in FinanceViewer.TAB_KEYS.size():
		var tab: TabButton = viewer.tab_button(FinanceViewer.TAB_KEYS[i])
		if tab == null or tab.index != i or tab.label != LABELS[i]:
			bad.append(String(FinanceViewer.TAB_KEYS[i]))
	TestFixtures.check(res, "every tab key reaches the button of its own place", bad.is_empty(),
		TestFixtures.detail(bad, FinanceViewer.TAB_KEYS.size(), "tabs"))
	bad = []
	for i: int in FinanceViewer.TAB_KEYS.size():
		if viewer.tab_button(FinanceViewer.TAB_KEYS[i]).description != TIPS[i]:
			bad.append(String(FinanceViewer.TAB_KEYS[i]))
	TestFixtures.check(res, "every tab carries the tooltip of the handoff", bad.is_empty(),
		TestFixtures.detail(bad, TIPS.size(), "tooltips"))
	bad = []
	for i: int in FinanceViewer.TAB_KEYS.size():
		var tab: TabButton = viewer.tab_button(FinanceViewer.TAB_KEYS[i])
		var art: Vector2i = tab.icon_rect.icon_size()
		if tab.icon_rect.texture == null or tab.icon_rect.icon_id != TAB_ICON_IDS[i]:
			bad.append(String(FinanceViewer.TAB_KEYS[i]))
		elif tab.icon_rect.pixel_scale != TAB_ICON_SCALE:
			bad.append(String(FinanceViewer.TAB_KEYS[i]))
		elif art.x != TAB_ICON_CELL or art.y != TAB_ICON_CELL:
			bad.append(String(FinanceViewer.TAB_KEYS[i]))
		elif tab.icon_rect.texture.get_size() != Vector2(32.0, 32.0):
			bad.append(String(FinanceViewer.TAB_KEYS[i]))
	TestFixtures.check(res,
		"every tab draws its 16 by 16 atlas cell at two screen pixels an art pixel",
		bad.is_empty(), TestFixtures.detail(bad, FinanceViewer.TAB_KEYS.size(), "icons"))
	var active_tab: TabButton = viewer.tab_button(&"overview")
	var idle_tab: TabButton = viewer.tab_button(&"loans")
	TestFixtures.check(res, "the open tab two-tones its icon and an idle tab draws it plain",
		active_tab.icon_rect.mode == Icons.MODE_TWO_TONE
			and idle_tab.icon_rect.mode == Icons.MODE_PLAIN,
		"%s / %s" % [active_tab.icon_rect.mode, idle_tab.icon_rect.mode])
	TestFixtures.check(res, "the open tab shows its label and stands 44 px tall",
		active_tab.active and active_tab.text_label.visible
			and is_equal_approx(active_tab.custom_minimum_size.y, TAB_ROW_HEIGHT),
		"label %s at %.0f px" % [active_tab.text_label.visible,
			active_tab.custom_minimum_size.y])
	TestFixtures.check(res, "an idle tab hides its label and keeps the 52 by 38 square",
		not idle_tab.active and not idle_tab.text_label.visible
			and idle_tab.custom_minimum_size == TabButton.IDLE_SIZE,
		"size %s" % str(idle_tab.custom_minimum_size))
	TestFixtures.check(res, "the window opens on the Overview page",
		viewer.current_tab() == &"overview" and viewer.overview() != null
			and viewer.overview().visible, "tab %s" % String(viewer.current_tab()))
	TestFixtures.check(res, "the Overview page is the page of its own key",
		viewer.page(&"overview") == viewer.overview(), "page %s" % str(viewer.page(&"overview")))
	TestFixtures.check(res, "no page of another screen is built on opening",
		viewer.page(&"loans") == null and viewer.page(&"payroll") == null
			and viewer.page(&"hiring") == null and viewer.page(&"invest") == null,
		"host holds %d pages" % viewer.page_host.get_child_count())
	_drop(viewer)


#Case 3: the tab the owner of the window asks for.
static func _case_start_tab(res: Dictionary, host: Node) -> void:
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.PAYROLL, STUB_PATH)
	await host.get_tree().process_frame
	var page: FinanceStubPage = _stub_of(viewer, &"payroll")
	TestFixtures.check(res, "the window opens on the tab its owner asked for",
		viewer.current_tab() == &"payroll" and page != null and page.visible,
		"tab %s" % String(viewer.current_tab()))
	TestFixtures.check(res, "the Overview page waits behind the tab that opened",
		viewer.overview() != null and not viewer.overview().visible,
		"overview shown %s" % [viewer.overview() == null or viewer.overview().visible])
	TestFixtures.check(res, "the page that opens is shown once",
		page != null and page.shown == 1, "shown %d" % [0 if page == null else page.shown])
	_drop(viewer)


#Case 4: moving between the tabs.
static func _case_open_tab(res: Dictionary, host: Node) -> void:
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var seen: Array[String] = []
	viewer.tab_changed.connect(func(key: StringName) -> void: seen.append(String(key)))
	var bad: Array[String] = []
	for key: StringName in FinanceViewer.TAB_KEYS:
		viewer.open_tab(key)
		await host.get_tree().process_frame
		var node: Control = viewer.page(key) as Control
		if viewer.current_tab() != key or node == null or not node.visible:
			bad.append(String(key))
	TestFixtures.check(res, "every tab opens the page of its own key", bad.is_empty(),
		TestFixtures.detail(bad, FinanceViewer.TAB_KEYS.size(), "tabs"))
	var shown: int = 0
	for key: StringName in FinanceViewer.TAB_KEYS:
		var node: Control = viewer.page(key) as Control
		if node != null and node.visible:
			shown += 1
	TestFixtures.check(res, "one page is shown at a time", shown == 1, "%d pages shown" % shown)
	TestFixtures.check(res, "tab_changed names every tab the window moved to",
		seen == ["loans", "payroll", "hiring", "invest"], "got %s" % str(seen))
	var count: int = seen.size()
	viewer.open_tab(&"invest")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the tab that is already open fires no change",
		seen.size() == count and viewer.current_tab() == &"invest", "%d moves" % seen.size())
	viewer.open_tab(&"nonsense")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a key no tab carries changes nothing",
		seen.size() == count and viewer.current_tab() == &"invest",
		"tab %s" % String(viewer.current_tab()))
	viewer.press_tab(&"overview")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a press on a tab moves the window",
		viewer.current_tab() == &"overview" and seen.has("overview"),
		"tab %s" % String(viewer.current_tab()))
	bad = []
	for key: StringName in FinanceViewer.TAB_KEYS:
		var tab: TabButton = viewer.tab_button(key)
		if tab.active != (key == viewer.current_tab()):
			bad.append(String(key))
	TestFixtures.check(res, "only the open tab wears the active look", bad.is_empty(),
		TestFixtures.detail(bad, FinanceViewer.TAB_KEYS.size(), "tabs"))
	TestFixtures.check(res, "a page of a tab that was left stays alive",
		viewer.page(&"loans") != null and not (viewer.page(&"loans") as Control).visible,
		"page %s" % str(viewer.page(&"loans")))
	_drop(viewer)


#Case 5: the page host, the placeholder and the pinned paths.
static func _case_pages(res: Dictionary, host: Node) -> void:
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, MISSING_PATH)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a page is built only when its tab is first shown",
		viewer.page(&"payroll") == null, "page %s" % str(viewer.page(&"payroll")))
	viewer.open_tab(&"payroll")
	await host.get_tree().process_frame
	var holder: Control = viewer.page(&"payroll") as Control
	var placeholder: FinancePlaceholder = holder as FinancePlaceholder
	TestFixtures.check(res, "a page that is not in the build yet reads as the placeholder",
		placeholder != null, "page %s" % str(holder))
	TestFixtures.check(res, "the placeholder names the tab it stands in for",
		placeholder != null and placeholder.label_text() == "Payroll is not available yet",
		"line %s" % ["none" if placeholder == null else placeholder.label_text()])
	TestFixtures.check(res, "the page fills the host it was added to",
		holder != null and is_equal_approx(holder.anchor_right, 1.0)
			and is_equal_approx(holder.anchor_bottom, 1.0)
			and holder.get_parent() == viewer.page_host,
		"anchors %.1f %.1f" % [0.0 if holder == null else holder.anchor_right,
			0.0 if holder == null else holder.anchor_bottom])
	viewer.set_page_path(&"payroll", STUB_PATH)
	viewer.open_tab(&"overview")
	viewer.open_tab(&"payroll")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a path set after the page was built changes nothing",
		viewer.page(&"payroll") == holder, "page %s" % str(viewer.page(&"payroll")))
	viewer.set_page_path(&"loans", STUB_PATH)
	viewer.open_tab(&"loans")
	await host.get_tree().process_frame
	var stub: FinanceStubPage = _stub_of(viewer, &"loans")
	TestFixtures.check(res, "a path set before the first show is honoured", stub != null,
		"page %s" % str(viewer.page(&"loans")))
	viewer.open_tab(&"overview")
	viewer.open_tab(&"loans")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the same page comes back on the second visit",
		_stub_of(viewer, &"loans") == stub, "page %s" % str(viewer.page(&"loans")))
	TestFixtures.check(res, "the page is shown again on every visit",
		stub != null and stub.shown == 2, "shown %d" % [0 if stub == null else stub.shown])
	TestFixtures.check(res, "the host holds one child per page it has built",
		viewer.page_host.get_child_count() == 3,
		"%d children" % viewer.page_host.get_child_count())
	viewer.set_page_path(&"overview", STUB_PATH)
	TestFixtures.check(res, "the Overview page takes no path of its own",
		not viewer.page_paths.has(&"overview") and viewer.page(&"overview") == viewer.overview(),
		"paths %s" % str(viewer.page_paths.keys()))
	_drop(viewer)


#Case 6: the three ways the rest of the window comes in.
static func _case_entries(res: Dictionary, host: Node) -> void:
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	viewer.open_offer(OFFER_ID)
	await host.get_tree().process_frame
	var loans: FinanceStubPage = _stub_of(viewer, &"loans")
	TestFixtures.check(res, "an offer opens the Loans tab",
		viewer.current_tab() == &"loans", "tab %s" % String(viewer.current_tab()))
	TestFixtures.check(res, "the offer reaches the Loans page",
		loans != null and loans.offer_id == OFFER_ID,
		"offer %d" % [-1 if loans == null else loans.offer_id])
	viewer.open_stock(COMPANY_ID)
	await host.get_tree().process_frame
	var invest: FinanceStubPage = _stub_of(viewer, &"invest")
	TestFixtures.check(res, "a stock move opens the Invest tab",
		viewer.current_tab() == &"invest", "tab %s" % String(viewer.current_tab()))
	TestFixtures.check(res, "the company reaches the Invest page",
		invest != null and invest.stock_id == COMPANY_ID,
		"company %d" % [-1 if invest == null else invest.stock_id])
	viewer.open_hiring()
	await host.get_tree().process_frame
	var hiring: FinanceStubPage = _stub_of(viewer, &"hiring")
	TestFixtures.check(res, "View Applicants opens the Hiring tab",
		viewer.current_tab() == &"hiring", "tab %s" % String(viewer.current_tab()))
	TestFixtures.check(res, "the Hiring page is shown on arrival",
		hiring != null and hiring.shown == 1, "shown %d" % [0 if hiring == null else hiring.shown])
	_drop(viewer)
	var bare: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, MISSING_PATH)
	await host.get_tree().process_frame
	bare.open_offer(OFFER_ID)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an offer still opens the tab when the page cannot take one",
		bare.current_tab() == &"loans" and bare.page(&"loans") is FinancePlaceholder,
		"page %s" % str(bare.page(&"loans")))
	_drop(bare)


#Case 7: the invest only window ViewerPopup opens.
static func _case_invest_only(res: Dictionary, host: Node) -> void:
	var plain: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	var solo: FinanceViewer = _make(host, true, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	plain.open_tab(&"invest")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the invest only window hides the tab row",
		not solo.tab_pad.visible, "row shown %s" % solo.tab_pad.visible)
	TestFixtures.check(res, "the invest only window opens on Invest",
		solo.current_tab() == &"invest" and solo.page(&"invest") != null,
		"tab %s" % String(solo.current_tab()))
	TestFixtures.check(res, "the content panel takes the room of the tab row",
		is_equal_approx(solo.page_panel.position.y, TOP_LINE_HEIGHT)
			and is_equal_approx(plain.page_panel.position.y, TAB_ROW_HEIGHT + TOP_LINE_HEIGHT),
		"%.0f against %.0f" % [solo.page_panel.position.y, plain.page_panel.position.y])
	var page: FinanceStubPage = _stub_of(solo, &"invest")
	TestFixtures.check(res, "the invest only page is told to hide the roster",
		page != null and page.hide_roster, "hidden %s" % [page != null and page.hide_roster])
	TestFixtures.check(res, "the whole window leaves the roster of the page alone",
		_stub_of(plain, &"invest") != null and not _stub_of(plain, &"invest").hide_roster,
		"hidden %s" % [_stub_of(plain, &"invest") == null
			or _stub_of(plain, &"invest").hide_roster])
	TestFixtures.check(res, "no other page is built in the invest only window",
		solo.page(&"loans") == null and solo.page(&"payroll") == null
			and solo.page(&"hiring") == null,
		"host holds %d pages" % solo.page_host.get_child_count())
	solo.open_tab(&"overview")
	solo.open_hiring()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a tab change does nothing in the invest only window",
		solo.current_tab() == &"invest" and not solo.overview().visible,
		"tab %s" % String(solo.current_tab()))
	solo.open_offer(OFFER_ID)
	await host.get_tree().process_frame
	TestFixtures.check(res, "an offer does nothing in the invest only window",
		solo.current_tab() == &"invest" and page != null and page.offer_id == -1,
		"offer %d" % [-1 if page == null else page.offer_id])
	solo.open_stock(COMPANY_ID)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a stock move still reaches the invest only page",
		page != null and page.stock_id == COMPANY_ID,
		"company %d" % [-1 if page == null else page.stock_id])
	plain.invest_only = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "the tab row goes when invest only is set later",
		not plain.tab_pad.visible and plain.current_tab() == &"invest",
		"row shown %s on %s" % [plain.tab_pad.visible, String(plain.current_tab())])
	_drop(solo)
	_drop(plain)


#Case 8: the dots on the tabs.
static func _case_dots(res: Dictionary, host: Node) -> void:
	_fresh()
	PromotionsManager.mark_seen()
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var bad: Array[String] = []
	for key: StringName in FinanceViewer.TAB_KEYS:
		if viewer.has_dot(key) or viewer.tab_button(key).dot:
			bad.append(String(key))
	TestFixtures.check(res, "a quiet window wears no dot at all", bad.is_empty(),
		TestFixtures.detail(bad, FinanceViewer.TAB_KEYS.size(), "tabs"))
	var offer: NotificationData = NotificationCenter.push(NotificationData.TYPE_LOAN_OFFER, 1, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unread loan offer marks the Loans tab on its own",
		viewer.has_dot(&"loans") and viewer.tab_button(&"loans").dot,
		"dot %s" % viewer.tab_button(&"loans").dot)
	viewer.open_tab(&"loans")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the dot goes while its own tab is the open one",
		not viewer.has_dot(&"loans") and not viewer.tab_button(&"loans").dot,
		"dot %s" % viewer.tab_button(&"loans").dot)
	viewer.open_tab(&"overview")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the dot is back once the tab is left",
		viewer.has_dot(&"loans") and viewer.tab_button(&"loans").dot,
		"dot %s" % viewer.tab_button(&"loans").dot)
	var move: NotificationData = NotificationCenter.push(NotificationData.TYPE_STOCK_MOVE, 2,
		{"band": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unread stock move marks the Invest tab",
		viewer.has_dot(&"invest") and viewer.tab_button(&"invest").dot,
		"dot %s" % viewer.tab_button(&"invest").dot)
	TestFixtures.check(res, "Overview and Payroll never wear a dot",
		not viewer.has_dot(&"overview") and not viewer.has_dot(&"payroll"),
		"overview %s payroll %s" % [viewer.has_dot(&"overview"), viewer.has_dot(&"payroll")])
	NotificationCenter.mark_read(offer.id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a read offer drops the dot of the Loans tab",
		not viewer.has_dot(&"loans") and viewer.has_dot(&"invest"),
		"loans %s invest %s" % [viewer.has_dot(&"loans"), viewer.has_dot(&"invest")])
	NotificationCenter.mark_read(move.id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a read stock move drops the dot of the Invest tab",
		not viewer.has_dot(&"invest") and not viewer.tab_button(&"invest").dot,
		"dot %s" % viewer.tab_button(&"invest").dot)
	_set_unseen(true)
	viewer.refresh_dots()
	TestFixtures.check(res, "an applicant nobody has read marks the Hiring tab",
		PromotionsManager.has_unseen() and viewer.has_dot(&"hiring")
			and viewer.tab_button(&"hiring").dot,
		"unseen %s dot %s" % [PromotionsManager.has_unseen(),
			viewer.tab_button(&"hiring").dot])
	PromotionsManager.mark_seen()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the window follows the applicant list on its own",
		not viewer.has_dot(&"hiring") and not viewer.tab_button(&"hiring").dot,
		"dot %s" % viewer.tab_button(&"hiring").dot)
	bad = []
	for key: StringName in FinanceViewer.TAB_KEYS:
		if viewer.tab_button(key).dot != viewer.has_dot(key):
			bad.append(String(key))
	TestFixtures.check(res, "every tab shows what has_dot reports", bad.is_empty(),
		TestFixtures.detail(bad, FinanceViewer.TAB_KEYS.size(), "tabs"))
	_drop(viewer)


#Case 9: the four cards over the Projection panel.
static func _case_stats(res: Dictionary, host: Node) -> void:
	_fresh()
	GameState.refund(FUNDS)
	FinanceLedger.reset()
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var over: FinanceOverview = viewer.overview()
	var cards: Array[Dictionary] = FinanceLedger.stat_cards()
	TestFixtures.check(res, "the stat row holds the four cards of the books",
		over.stat_count() == cards.size() and cards.size() == STAT_KEYS.size(),
		"%d cards" % over.stat_count())
	TestFixtures.check(res, "the cards keep the order the books hand them over in",
		over.stat_keys() == STAT_KEYS, "got %s" % str(over.stat_keys()))
	var bad: Array[String] = []
	for row: Dictionary in cards:
		var key: String = String(row["key"])
		var tile: StatTile = over.stat_tile(key)
		if tile == null:
			bad.append(key)
			continue
		if tile.label != String(row["label"]) or tile.value_text != String(row["value"]):
			bad.append(key)
		elif tile.sub != String(row["sub"]) or not tile.value_color.is_equal_approx(row["color"]):
			bad.append(key)
	TestFixtures.check(res, "every card reads the row of the books it stands for", bad.is_empty(),
		TestFixtures.detail(bad, cards.size(), "cards"))
	TestFixtures.check(res, "the expenses card names the five lines it sums",
		over.stat_tile("expenses").sub == EXPENSES_SUB, over.stat_tile("expenses").sub)
	TestFixtures.check(res, "the income card is green and the expenses card red",
		over.stat_tile("income").value_color.is_equal_approx(GREEN)
			and over.stat_tile("expenses").value_color.is_equal_approx(RED),
		"%s and %s" % [str(over.stat_tile("income").value_color),
			str(over.stat_tile("expenses").value_color)])
	var width: float = over.stat_tile("notes").custom_minimum_size.x
	bad = []
	for key: String in STAT_KEYS:
		if not is_equal_approx(over.stat_tile(key).custom_minimum_size.x, width):
			bad.append(key)
	TestFixtures.check(res, "the four cards share the width of the row",
		width > 0.0 and bad.is_empty(), "%.0f px, %s" % [width,
			TestFixtures.detail(bad, STAT_KEYS.size(), "cards")])
	bad = []
	for key: String in STAT_KEYS:
		var sub: Label = over.stat_tile(key).get_node_or_null(FinanceOverview.SUB_PATH) as Label
		if sub == null or sub.clip_text or sub.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
			bad.append(key)
	TestFixtures.check(res, "every card wraps its description instead of clipping it",
		bad.is_empty(), TestFixtures.detail(bad, STAT_KEYS.size(), "cards"))
	var before: String = over.stat_tile("notes").value_text
	var paid: bool = GameState.spend(SPEND_NOTES, "bazaar", "Bazaar - Order")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a spend with a reason moves the notes card",
		paid and over.stat_tile("notes").value_text != before
			and over.stat_tile("notes").value_text == TransactionData.grouped(GameState.bank_notes),
		"%s against %s" % [over.stat_tile("notes").value_text, before])
	_drop(viewer)


#Case 10: the Projection panel over the three horizons of the books.
static func _case_projection(res: Dictionary, host: Node) -> void:
	_fresh()
	GameState.refund(FUNDS)
	FinanceLedger.reset()
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var proj: FinanceProjection = viewer.overview().projection()
	TestFixtures.check(res, "the panel opens on the end of the month",
		proj.horizon() == FinanceLedger.Horizon.END_OF_MONTH, "%d" % proj.horizon())
	var labels: Array[String] = []
	for opt: Dictionary in proj.horizon_button().options:
		labels.append(String(opt["label"]))
	TestFixtures.check(res, "the dropdown lists the three horizons of the books",
		labels == FinanceLedger.HORIZON_LABELS, "got %s" % str(labels))
	TestFixtures.check(res, "the button reads the horizon the panel is on",
		proj.horizon_button().button_text() == FinanceLedger.HORIZON_LABELS[0],
		proj.horizon_button().button_text())
	var ring_box: PanelContainer = proj.horizon_button().get_node_or_null("Menu/Box") as PanelContainer
	var ring: StyleBoxFlat = null
	if ring_box != null:
		ring = ring_box.get_theme_stylebox("panel") as StyleBoxFlat
	var ring_ok: bool = (ring != null and ring.border_width_left == 4 and ring.border_width_top == 4
		and ring.border_width_right == 4 and ring.border_width_bottom == 4
		and ring.border_color.is_equal_approx(ORANGE))
	TestFixtures.check(res, "the horizon popup wears a 4 px orange ring on this instance",
		ring_ok, "ring %s" % ring)
	var moves: Array[int] = []
	proj.horizon_changed.connect(func(h: int) -> void: moves.append(h))
	var bad_rows: Array[String] = []
	var bad_text: Array[String] = []
	var bad_color: Array[String] = []
	var bad_prefix: Array[String] = []
	var bad_total: Array[String] = []
	for h: int in FinanceLedger.HORIZON_LABELS.size():
		proj.set_horizon(h)
		await host.get_tree().process_frame
		var data: Dictionary = FinanceLedger.projection(h)
		var rows: Array[Dictionary] = data["rows"]
		if proj.row_keys() != _keys_of(rows) or proj.row_count() != rows.size():
			bad_rows.append(str(h))
		for row: Dictionary in rows:
			var key: String = String(row["key"])
			var amount: int = int(row["amount"])
			if proj.row_text(key) != _want_text(key, amount):
				bad_text.append("%d %s" % [h, key])
			elif proj.row_label(key) != String(row["label"]):
				bad_text.append("%d %s label" % [h, key])
			elif proj.row_sub(key) != String(row["sub"]):
				bad_text.append("%d %s sub" % [h, key])
			if not proj.row_color(key).is_equal_approx(_want_color(key, amount)):
				bad_color.append("%d %s" % [h, key])
			var want_prefix: String = "+" if key == INCOME_KEY else ("-" if EXPENSE_KEYS.has(key) else "")
			if want_prefix != "" and not proj.row_text(key).begins_with(want_prefix):
				bad_prefix.append("%d %s" % [h, key])
		var total: int = int(data["total"])
		if proj.total_text() != NotesLabel.format_amount(total):
			bad_total.append("%d total" % h)
		elif proj.when_text() != String(data["when"]):
			bad_total.append("%d date" % h)
		elif not proj.total_color().is_equal_approx(_want_color(TOTAL_KEY, total)):
			bad_total.append("%d colour" % h)
	TestFixtures.check(res, "every horizon lists the rows the books hand over", bad_rows.is_empty(),
		TestFixtures.detail(bad_rows, FinanceLedger.HORIZON_LABELS.size(), "horizons"))
	TestFixtures.check(res, "every row reads the amount, label and note of its book row",
		bad_text.is_empty(), TestFixtures.detail(bad_text, 24, "rows"))
	TestFixtures.check(res, "income reads green with a plus and every expense red with a minus",
		bad_color.is_empty() and bad_prefix.is_empty(),
		TestFixtures.detail(bad_color + bad_prefix, 24, "rows"))
	TestFixtures.check(res, "the total and the date of every horizon read the books",
		bad_total.is_empty(), TestFixtures.detail(bad_total,
			FinanceLedger.HORIZON_LABELS.size(), "horizons"))
	TestFixtures.check(res, "horizon_changed fires once for every move",
		moves == [1, 2], "got %s" % str(moves))
	proj.set_horizon(FinanceLedger.Horizon.END_OF_YEAR)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the horizon already picked fires nothing",
		moves.size() == 2 and proj.horizon() == FinanceLedger.Horizon.END_OF_YEAR,
		"%d moves" % moves.size())
	proj.horizon_button().select(&"0", true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a pick in the dropdown moves the panel",
		proj.horizon() == FinanceLedger.Horizon.END_OF_MONTH and moves.size() == 3
			and proj.horizon_button().button_text() == FinanceLedger.HORIZON_LABELS[0],
		"%s on %d moves" % [proj.horizon_button().button_text(), moves.size()])
	GameState.bank_notes = 0
	proj.refresh()
	await host.get_tree().process_frame
	var bare: Dictionary = FinanceLedger.projection(proj.horizon())
	TestFixtures.check(res, "an empty bank leaves the notes row and the total on the books",
		proj.row_text("notes") == NotesLabel.format_amount(0)
			and proj.total_text() == NotesLabel.format_amount(int(bare["total"]))
			and proj.total_color().is_equal_approx(_want_color(TOTAL_KEY, int(bare["total"]))),
		"%s and %s" % [proj.row_text("notes"), proj.total_text()])
	var pad2: MarginContainer = proj.list.get_parent() as MarginContainer
	var scroll: ScrollContainer = (pad2.get_parent() as ScrollContainer) if pad2 != null else null
	TestFixtures.check(res, "the breakdown list sits in a padded scroll container",
		pad2 != null and scroll != null
			and pad2.get_theme_constant("margin_left") == 14
			and pad2.get_theme_constant("margin_top") == 14
			and pad2.get_theme_constant("margin_right") == 14
			and pad2.get_theme_constant("margin_bottom") == 14
			and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"pad %s scroll %s" % [pad2, scroll])
	_drop(viewer)


#Case 10b: a campaign-free guild projects an ads row of 0, which still leads with a minus.
static func _case_projection_zero_expense(res: Dictionary, host: Node) -> void:
	_fresh()
	GameState.refund(FUNDS)
	FinanceLedger.reset()
	_set_promos(0)
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var proj: FinanceProjection = viewer.overview().projection()
	var data: Dictionary = FinanceLedger.projection(proj.horizon())
	var rows: Array[Dictionary] = data["rows"]
	var ads: Dictionary = _row_of(rows, "ads")
	TestFixtures.check(res, "a campaign-free guild projects an ads row of 0",
		int(ads.get("amount", -1)) == 0, "amount %s" % str(ads.get("amount", "missing")))
	TestFixtures.check(res, "an expense row of 0 still reads a leading minus",
		proj.row_text("ads") == "-" + NotesLabel.format_amount(0), proj.row_text("ads"))
	_drop(viewer)


#Case 11: the Monthly Expenses box and its bars.
static func _case_expenses(res: Dictionary, host: Node) -> void:
	_fresh()
	GameState.refund(FUNDS)
	FinanceLedger.reset()
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var box: FinanceExpenses = viewer.overview().expenses()
	var rows: Array[Dictionary] = FinanceLedger.expense_breakdown()
	TestFixtures.check(res, "the box lists the five expense rows of the books",
		box.row_keys() == EXPENSE_KEYS and box.row_count() == rows.size(),
		"got %s" % str(box.row_keys()))
	var box_pad: MarginContainer = box.get_node("Pad") as MarginContainer
	var box_rows: VBoxContainer = box.get_node("Pad/Rows") as VBoxContainer
	TestFixtures.check(res, "the expenses box pads its top instead of the title sitting flush",
		box_pad != null and box_pad.get_theme_constant("margin_top") == 14
			and box_rows != null and box_rows.get_theme_constant("separation") == 14,
		"margin %d separation %d" % [
			0 if box_pad == null else box_pad.get_theme_constant("margin_top"),
			0 if box_rows == null else box_rows.get_theme_constant("separation")])
	var bad: Array[String] = []
	for row: Dictionary in rows:
		var key: String = String(row["key"])
		if box.row_label(key) != String(row["label"]) or box.row_sub(key) != String(row["sub"]):
			bad.append(key)
		elif box.row_text(key) != NotesLabel.format_amount(int(row["amount"])):
			bad.append(key)
		elif box.row_cells(key) != int(row["cells"]):
			bad.append(key)
	TestFixtures.check(res, "every row reads the label, note, amount and bar of its book row",
		bad.is_empty(), TestFixtures.detail(bad, rows.size(), "rows"))
	bad = []
	for key: String in EXPENSE_KEYS:
		if box.row_cells(key) < 0 or box.row_cells(key) > FinanceLedger.BREAKDOWN_CELLS:
			bad.append(key)
		elif not box.row_color(key).is_equal_approx(RED):
			bad.append(key)
	TestFixtures.check(res, "every bar stays inside its twenty cells and reads red",
		bad.is_empty(), TestFixtures.detail(bad, EXPENSE_KEYS.size(), "rows"))
	_set_promos(0)
	box.refresh()
	TestFixtures.check(res, "with no campaign the Ads row is still listed and says so",
		box.row_keys().has("ads") and box.row_sub("ads") == "No ongoing promos"
			and box.row_cells("ads") == 0, box.row_sub("ads"))
	_set_promos(1)
	box.refresh()
	TestFixtures.check(res, "one ongoing campaign reads as one promo billed monthly",
		box.row_sub("ads") == "1 ongoing promo - billed monthly", box.row_sub("ads"))
	_set_promos(2)
	box.refresh()
	TestFixtures.check(res, "two ongoing campaigns read as two promos billed monthly",
		box.row_sub("ads") == "2 ongoing promos - billed monthly", box.row_sub("ads"))
	TestFixtures.check(res, "the Ads row bills what the promotions manager bills",
		box.row_text("ads") == NotesLabel.format_amount(PromotionsManager.monthly_ad_bill()),
		"%s against %d" % [box.row_text("ads"), PromotionsManager.monthly_ad_bill()])
	bad = []
	for key: String in EXPENSE_KEYS:
		var line: HBoxContainer = box.row_line(key)
		if line == null or line.get_child_count() != 3:
			bad.append(key)
		elif (not (line.get_child(0) is Label) or not (line.get_child(1) is CellBar)
				or not (line.get_child(2) is HBoxContainer)):
			bad.append(key)
	TestFixtures.check(res, "every row is one line: a title label, the bar, then the amount",
		bad.is_empty(), TestFixtures.detail(bad, EXPENSE_KEYS.size(), "rows"))
	await host.get_tree().process_frame
	var first_x: float = box.row_bar_x(EXPENSE_KEYS[0])
	bad = []
	for key: String in EXPENSE_KEYS:
		if not is_equal_approx(box.row_bar_x(key), first_x):
			bad.append(key)
	TestFixtures.check(res, "every bar starts at the same x no matter how long its sub reads",
		bad.is_empty(), TestFixtures.detail(bad, EXPENSE_KEYS.size(), "rows"))
	box.tooltip().hide_tip()
	box._on_row_hover(box.row_line("ads"), box.row_label("ads"), box.row_sub("ads"))
	TestFixtures.check(res, "hovering a row shows its description as a tooltip",
		box.tooltip().visible and box.tooltip().body_label.text == box.row_sub("ads"),
		"visible %s text %s" % [box.tooltip().visible, box.tooltip().body_label.text])
	box._on_row_exit()
	TestFixtures.check(res, "leaving the row hides the tooltip again",
		not box.tooltip().visible, "visible %s" % box.tooltip().visible)
	box._on_row_hover(box.row_line("payroll"), box.row_label("payroll"), "")
	TestFixtures.check(res, "a row with an empty sub shows no tooltip",
		not box.tooltip().visible, "visible %s" % box.tooltip().visible)
	_drop(viewer)


#Case 12: the Recent Transactions list.
static func _case_transactions(res: Dictionary, host: Node) -> void:
	_fresh()
	GameState.refund(FUNDS)
	FinanceLedger.reset()
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var list: FinanceTransactions = viewer.overview().transactions()
	var entries: Array[TransactionData] = FinanceLedger.rows(FinanceTransactions.SHOWN_ROWS)
	TestFixtures.check(res, "the list holds a row per row of the books",
		list.row_count() == entries.size() and entries.size() > 0,
		"%d against %d" % [list.row_count(), entries.size()])
	TestFixtures.check(res, "the newest row of the books sits at the top",
		list.row_text(0) == entries[0].label, list.row_text(0))
	var bad: Array[String] = []
	for i: int in entries.size():
		var entry: TransactionData = entries[i]
		if list.row_text(i) != entry.label or list.row_category(i) != entry.category:
			bad.append(str(i))
		elif list.row_amount_text(i) != entry.amount_text():
			bad.append(str(i))
		elif list.row_when(i) != entry.date_text():
			bad.append(str(i))
	TestFixtures.check(res, "every row reads the label, category, amount and date of its book row",
		bad.is_empty(), TestFixtures.detail(bad, entries.size(), "rows"))
	bad = []
	for i: int in entries.size():
		var want: Color = CREAM
		if entries[i].amount > 0:
			want = GREEN
		elif entries[i].amount < 0:
			want = RED
		if not list.row_color(i).is_equal_approx(want):
			bad.append(str(i))
	TestFixtures.check(res, "a credit reads green and a debit red", bad.is_empty(),
		TestFixtures.detail(bad, entries.size(), "rows"))
	TestFixtures.check(res, "a row past the end of the list reads as nothing",
		list.row_text(entries.size()) == "" and list.row_text(-1) == ""
			and list.row_amount_text(entries.size()) == "", "out of range rows are empty")
	var paid: bool = GameState.spend(FINE_NOTES, "fine", "City Watch - Fine")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a spend with a reason lands at the top of the list",
		paid and list.row_text(0) == "City Watch - Fine" and list.row_category(0) == "Legal",
		"%s | %s" % [list.row_text(0), list.row_category(0)])
	TestFixtures.check(res, "the transaction list and the projection breakdown scroll",
		_count_scrolls(viewer) == 2, "%d scrolls" % _count_scrolls(viewer))
	viewer.open_tab(&"loans")
	await host.get_tree().process_frame
	for i: int in OVER_CAP:
		FinanceLedger.record(-1, "bazaar", "Order %d" % i)
	TestFixtures.check(res, "a page nobody looks at waits instead of rebuilding",
		viewer.overview().is_dirty(), "dirty %s" % viewer.overview().is_dirty())
	viewer.open_tab(&"overview")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the list stops at a hundred rows and catches up when shown",
		list.row_count() == FinanceTransactions.SHOWN_ROWS and not viewer.overview().is_dirty(),
		"%d rows" % list.row_count())
	FinanceLedger.transactions.clear()
	list.refresh()
	TestFixtures.check(res, "an empty ledger says there is nothing to show",
		list.row_count() == 0 and list.empty_shown(), "%d rows" % list.row_count())
	_drop(viewer)


#Case 13: the layer the pages put their windows on.
static func _case_modal_layer(res: Dictionary, host: Node) -> void:
	var viewer: FinanceViewer = _make(host, false, FinanceViewer.Tab.OVERVIEW, STUB_PATH)
	await host.get_tree().process_frame
	var layer: Control = viewer.modal_layer()
	TestFixtures.check(res, "the window carries a modal layer of its own",
		layer != null and layer.name == "ModalLayer",
		"layer %s" % ["none" if layer == null else str(layer.name)])
	TestFixtures.check(res, "the modal layer is in the group the pages look for",
		layer != null and layer.is_in_group(&"finance_modal_host"),
		"groups %s" % ["none" if layer == null else str(layer.get_groups())])
	TestFixtures.check(res, "the modal layer lets a click through to the page under it",
		layer != null and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"filter %d" % [0 if layer == null else layer.mouse_filter])
	TestFixtures.check(res, "the modal layer is drawn over the tab row and the content panel",
		layer != null and layer.get_index() == viewer.get_child_count() - 1,
		"child %d of %d" % [0 if layer == null else layer.get_index(),
			viewer.get_child_count()])
	TestFixtures.check(res, "the modal layer covers the whole frame",
		layer != null and is_equal_approx(layer.anchor_right, 1.0)
			and is_equal_approx(layer.anchor_bottom, 1.0)
			and layer.size.is_equal_approx(viewer.size),
		"size %s against %s" % [str(layer.size), str(viewer.size)])
	var window := Control.new()
	window.name = "PageWindow"
	layer.add_child(window)
	viewer.open_tab(&"loans")
	viewer.open_tab(&"overview")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the window of a page is left alone when the tabs move",
		layer.get_child_count() == 1 and layer.get_child(0) == window and window.visible,
		"%d children" % layer.get_child_count())
	TestFixtures.check(res, "the window holds no canvas layer and nothing that floats free",
		_count_floating(viewer) == 0, "%d floating nodes" % _count_floating(viewer))
	_drop(viewer)
