class_name GuiLegalTests
extends RefCounted

#Run: godot --headless --path . with the --gui-legal-tests flag.
#The Legal window and the rules under it: the three tabs with their unread dots, the thirteen location
#cards, the permit request dialog and its confirm, the fine and bailout lists, the Review dialog
#with its rich pay confirm, and the Odd Job window that renegotiates a fine or breaks a merc out.
#Every case drives the public helpers, because a synthetic click never reaches a button headless.

const VIEWER: PackedScene = preload("res://Scenes/GUI/Legal/LegalViewer.tscn")
const RICH: int = 40000
const SHORT_NOTES: int = 10
const CARDS: int = 13
#The legal books the cases read, which _lay_legal files: one fine with time left, one overdue, one far off,
#one paid, and two mercs in custody. Days are written against LAY_TODAY and keep their age around today.
const LAY_TODAY: int = 540
const LAY_FINES: Array[Dictionary] = [
	{"loc": 2, "crime": "Crime 1", "mercs": [3, 6], "contract": 11, "issued": 530, "due": 548, "amount": 180,
		"unread": true},
	{"loc": 0, "crime": "Crime 2", "mercs": [1], "contract": 12, "issued": 520, "due": 535, "amount": 450,
		"unread": false},
	{"loc": 3, "crime": "Crime 3", "mercs": [2, 7, 8], "contract": 13, "issued": 538, "due": 561,
		"amount": 900, "unread": true},
	{"loc": 0, "crime": "Crime 4", "mercs": [5], "contract": 11, "issued": 500, "due": 520, "amount": 60,
		"paid": 60, "paid_day": 517, "unread": false},
]
const LAY_CAPTURES: Array[Dictionary] = [
	{"merc": 4, "loc": 3, "crime": "Crime 5", "contract": 13, "since": 536, "sentence": 30, "bail": 350,
		"unread": true},
	{"merc": 9, "loc": 2, "crime": "Crime 6", "contract": 11, "since": 530, "sentence": 20, "bail": 220,
		"unread": false},
]
const FINE_SOON: int = 1
const FINE_LATE: int = 2
const FINE_FAR: int = 3
const FINE_DONE: int = 4
const HELD_A: int = 1
const HELD_B: int = 2
const HELD_A_UID: int = 4
const HELD_B_UID: int = 9
#The books name mercs by uid up to nine, so the cases run on a roster of ten that holds every one of them.
const LEGAL_ROSTER: int = 10
const HOME_LOC: int = 0
const NEAR_LOC: int = 1
const SOON_LOC: int = 2
const HELD_LOC: int = 3
const FAR_LOC: int = 7
const SHORT_LOC: int = 5
const OPS_COST: int = 400
const TELE_COST: int = 250
const FAR_OPS_COST: int = 2600
const SOON_DAYS: int = 8
const AMBER_DAYS: int = 7
const LATE_DAYS: int = 5
const FAR_DAYS: int = 21
const SOON_AMOUNT: int = 180
const LATE_AMOUNT: int = 450
const FAR_AMOUNT: int = 900
const DONE_AMOUNT: int = 60
const LATE_FEE: int = 45
const LATE_TOTAL: int = 495
const SERVED_A: int = 4
const SERVED_B: int = 10
const LEFT_A: int = 26
const SENTENCE_A: int = 30
const BAIL_A: int = 350
const BAIL_B: int = 220
const DUE_A: int = 370
const DUE_B: int = 270
const CONTRACT_ENTRY: int = 11
const LEGAL_CATEGORY: String = "Legal"
const ODD_CATEGORY: String = "Odd Job"
const COUNSEL_TOP: int = 15
const OPS_TOP_TIER: int = 3
const SHORT_TIER: int = 1
const PAY_EACH: int = 50
const ONE_MERC_FINE_ODDS: int = 65
const ONE_MERC_BAIL_ODDS: int = 50
const WON_AMOUNT: int = 90
const LOST_AMOUNT: int = 1125
const LOST_BAIL: int = 330
const HALF_JOB: int = 6
const OTHER_UNTIL: int = 10
const ROWS_PATH: NodePath = ^"Margin/Rows"
const TAB_PAD_PATH: NodePath = ^"Margin/Rows/TabRowPad"
const PANEL_PATH: NodePath = ^"Margin/Rows/PagePanel"
const TAB_ROW_HEIGHT: int = 44
const TAB_ROW_GAP: int = 8
const TAB_PAD_LEFT: int = 4
const TAB_PAD_RIGHT: int = 42
const WINDOW_MARGIN: int = 14
const LAYOUT_SLACK: float = 0.5


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var clock: int = CampaignClock.minutes
	var roster: Array[MercenaryData] = GameState.mercs.duplicate()
	var board: Array[ContractView] = GameState.contracts.duplicate()
	var bank: int = GameState.bank_notes
	_fresh()
	TestFixtures.add_mercs(LEGAL_ROSTER - GameState.mercs.size())
	await host.get_tree().process_frame
	var viewer: LegalViewer = VIEWER.instantiate() as LegalViewer
	host.add_child(viewer)
	await host.get_tree().process_frame
	await _case_tabs(res, host, viewer)
	await _case_permit_frame(res, host, viewer)
	await _case_dots(res, host, viewer)
	await _case_cards(res, host, viewer)
	await _case_states(res, host, viewer)
	await _case_request(res, host, viewer)
	await _case_fines(res, host, viewer)
	await _case_bailout(res, host, viewer)
	await _case_review(res, host, viewer)
	await _case_locks(res, host, viewer)
	await _case_pay(res, host, viewer)
	await _case_outcomes(res, host, viewer)
	await _case_job_window(res, host, viewer)
	await _case_job_run(res, host, viewer)
	await _case_job_outcomes(res, host, viewer)
	await _case_holds(res, host, viewer)
	await _case_bevel_sweep(res, host, viewer)
	await _case_dot_frames(res, host, viewer)
	await _case_fit(res, host)
	await _case_reopen_legal(res, host, viewer)
	GuiFrameStack.clear()
	viewer.queue_free()
	CampaignClock.minutes = clock
	GameState.mercs = roster
	GameState.contracts = board
	GameState.bank_notes = bank
	SubscriptionManager.max_out()
	LegalManager.reset()
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.reset_campaign()
	return TestFixtures.summarize(res, "GUI LEGAL")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


#Every case starts from the laid legal state, a full plan and a bank that can pay for anything.
static func _reseed(viewer: LegalViewer) -> void:
	if viewer.confirm().visible:
		viewer.confirm().press(0)
	if viewer.odd_job_window().visible:
		viewer.odd_job_window().press_cancel()
	viewer.review_dialog().close()
	viewer.request_dialog().close()
	GuiFrameStack.clear()
	SubscriptionManager.max_out()
	GameState.bank_notes = RICH
	LegalManager.reset()
	_lay_legal()


#Files the LAY rows through add_fine and add_capture, then sets each to its row on the public fields, since
#the builders file today, unread and after the whoKnows cut. Both SOON_LOC permits go straight into permits.
static func _lay_legal() -> void:
	var today: int = GameState.day()
	for row: Dictionary in LAY_FINES:
		var mercs: Array[int] = []
		mercs.assign(row["mercs"] as Array)
		var span: int = int(row["due"]) - int(row["issued"])
		var made: FineData = LegalManager.add_fine(int(row["loc"]), str(row["crime"]), mercs,
			int(row["contract"]), int(row["amount"]), span)
		made.day_issued = today - (LAY_TODAY - int(row["issued"]))
		made.day_due = made.day_issued + span
		made.amount = int(row["amount"])
		made.previous_amount = 0
		made.note = ""
		made.paid = int(row.get("paid", 0))
		made.day_paid = today - (LAY_TODAY - int(row["paid_day"])) if row.has("paid_day") else -1
		made.unread = bool(row["unread"])
	for row: Dictionary in LAY_CAPTURES:
		var held: CaptureData = LegalManager.add_capture(int(row["merc"]), int(row["loc"]),
			str(row["crime"]), int(row["contract"]), int(row["sentence"]), int(row["bail"]))
		held.day_captured = today - (LAY_TODAY - int(row["since"]))
		held.sentence_days = int(row["sentence"])
		held.bail = int(row["bail"])
		held.previous_bail = 0
		held.note = ""
		held.unread = bool(row["unread"])
	LegalManager.permits[SOON_LOC] = {"ops": true, "tele": true}
	LegalManager.permits_changed.emit()
	LegalManager.fines_changed.emit()
	LegalManager.captures_changed.emit()


#whoKnows at its top tier waives every fine fee, so the fee cases drop that upgrade first.
static func _no_favours() -> bool:
	return SubscriptionManager.set_tier("whoknows", 0)


static func _status_of(uid: int) -> int:
	for view: MercView in GameState.roster:
		if view.uid == uid:
			return view.status
	return -1


static func _candidate_ids(config: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for row: Variant in config.get("candidates", []):
		out.append(int((row as Dictionary).get("id", 0)))
	return out


static func _fact(config: Dictionary, i: int) -> Dictionary:
	var facts: Array = config.get("facts", []) as Array
	if i < 0 or i >= facts.size():
		return {}
	return facts[i] as Dictionary


static func _fact_label(config: Dictionary, i: int) -> String:
	return str(_fact(config, i).get("label", ""))


static func _fact_value(config: Dictionary, i: int) -> String:
	return str(_fact(config, i).get("value", ""))


static func _fact_count(config: Dictionary) -> int:
	return (config.get("facts", []) as Array).size()


static func _fact_color(config: Dictionary, i: int) -> Color:
	var tint: Color = _fact(config, i).get("color", Color.BLACK)
	return tint


static func _newest_row() -> TransactionData:
	var rows: Array[TransactionData] = FinanceLedger.rows(1)
	return rows[0] if not rows.is_empty() else null


#The window frame itself must never scroll: only a page list does.
static func _frame_scrolls(viewer: LegalViewer) -> bool:
	var rows: Node = viewer.get_node_or_null(ROWS_PATH)
	if rows == null:
		return true
	for child: Node in rows.get_children():
		if child is ScrollContainer:
			return true
		for sub: Node in child.get_children():
			if sub is ScrollContainer:
				return true
	return false


static func _case_tabs(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	await host.get_tree().process_frame
	var seen: Array[int] = []
	var on_tab := func(index: int) -> void:
		seen.append(index)
	viewer.tab_changed.connect(on_tab)
	TestFixtures.check(res, "the Legal window opens the three tabs the prototype names",
		viewer.tabs().size() == 3 and LegalViewer.TAB_KEYS.size() == 3
		and LegalViewer.TAB_KEYS[0] == &"permits" and LegalViewer.TAB_KEYS[1] == &"fines"
		and LegalViewer.TAB_KEYS[2] == &"bail",
		"%d tabs, keys %s" % [viewer.tabs().size(), LegalViewer.TAB_KEYS])
	TestFixtures.check(res, "each tab carries its prototype label and description",
		viewer.tab_at(0).label == "Permits" and viewer.tab_at(1).label == "Fines"
		and viewer.tab_at(2).label == "Bailout"
		and viewer.tab_at(1).description == LegalViewer.TAB_DESCS[1],
		"%s, %s, %s" % [viewer.tab_at(0).label, viewer.tab_at(1).label,
		viewer.tab_at(2).label])
	TestFixtures.check(res, "the window opens on its first tab",
		viewer.default_tab == &"" and viewer.current_index() == 0
		and viewer.current_tab() == &"permits",
		"tab %d key %s" % [viewer.current_index(), viewer.current_tab()])
	TestFixtures.check(res, "only the Permits page shows on the first tab",
		viewer.permits_page().visible and not viewer.fines_page().visible
		and not viewer.bailout_page().visible and viewer.tab_at(0).active,
		"%s %s %s" % [viewer.permits_page().visible, viewer.fines_page().visible,
		viewer.bailout_page().visible])
	viewer.press_tab(&"fines")
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing Fines swaps the page and the active mark",
		viewer.current_index() == 1 and viewer.current_tab() == &"fines"
		and viewer.fines_page().visible and not viewer.permits_page().visible
		and viewer.tab_at(1).active and not viewer.tab_at(0).active,
		"tab %d fines %s" % [viewer.current_index(), viewer.fines_page().visible])
	viewer.press_tab(&"bail")
	await host.get_tree().process_frame
	TestFixtures.check(res, "pressing Bailout reports each tab change once",
		viewer.current_tab() == &"bail" and viewer.bailout_page().visible
		and seen.size() == 2 and seen[0] == 1 and seen[1] == 2,
		"key %s changes %s" % [viewer.current_tab(), seen])
	viewer.open_tab(&"nothing")
	TestFixtures.check(res, "an unknown tab key changes nothing",
		viewer.current_tab() == &"bail" and seen.size() == 2,
		"key %s changes %s" % [viewer.current_tab(), seen])
	viewer.open_tab(&"permits")
	await host.get_tree().process_frame
	viewer.tab_changed.disconnect(on_tab)
	TestFixtures.check(res, "opening a tab by key returns to Permits",
		viewer.current_tab() == &"permits" and viewer.permits_page().visible
		and seen.size() == 3 and seen[2] == 0,
		"key %s changes %s" % [viewer.current_tab(), seen])
	TestFixtures.check(res, "each Legal tab carries its atlas id",
		viewer.tab_at(0).icon_id == "permit" and viewer.tab_at(1).icon_id == "coin"
		and viewer.tab_at(2).icon_id == "bail_bars" and viewer.tab_at(0).icon_scale == 2,
		"got %s" % [viewer.tab_at(0).icon_id])
	TestFixtures.check(res, "the window frame never scrolls; the page list does",
		not _frame_scrolls(viewer) and viewer.permits_page().scroll_node() != null,
		"frame scrolls %s" % _frame_scrolls(viewer))


#The tab row stands above the PageContent panel so the panel's orange top line runs under the tabs,
#and the permits strip sits in a frame with its cards held clear of the horizontal bar.
static func _case_permit_frame(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	viewer.open_tab(&"permits")
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var margin: MarginContainer = viewer.get_node_or_null(^"Margin") as MarginContainer
	var pad: MarginContainer = viewer.get_node_or_null(TAB_PAD_PATH) as MarginContainer
	var panel: PanelContainer = viewer.get_node_or_null(PANEL_PATH) as PanelContainer
	var strip: TabStrip = viewer.tab_strip
	var related: bool = pad != null and panel != null and pad.get_parent() == panel.get_parent() \
		and pad.get_index() < panel.get_index()
	TestFixtures.check(res, "the tab row is a sibling above the page panel, not inside it",
		related and pad.is_ancestor_of(strip) and not panel.is_ancestor_of(strip)
		and panel.is_ancestor_of(viewer.permits_page()),
		"pad %s panel %s" % [pad, panel])
	TestFixtures.check(res, "the page panel wears the PageContent look and takes the free height",
		panel != null and panel.theme_type_variation == &"PageContent"
		and panel.size_flags_vertical == Control.SIZE_EXPAND_FILL,
		"panel %s" % panel)
	var strip_end: float = strip.get_global_rect().end.y
	var panel_top: float = panel.get_global_rect().position.y if panel != null else -1.0
	TestFixtures.check(res, "the panel's top line starts where the tab strip ends",
		absf(strip_end - panel_top) <= LAYOUT_SLACK,
		"strip ends %.1f panel starts %.1f" % [strip_end, panel_top])
	TestFixtures.check(res, "the strip stands 44 px tall with a gap of eight",
		strip.custom_minimum_size.y == float(TAB_ROW_HEIGHT)
		and strip.get_theme_constant(&"separation") == TAB_ROW_GAP,
		"min %s gap %d" % [strip.custom_minimum_size, strip.get_theme_constant(&"separation")])
	var left: int = pad.get_theme_constant(&"margin_left") if pad != null else -1
	var right: int = pad.get_theme_constant(&"margin_right") if pad != null else -1
	var edge: int = margin.get_theme_constant(&"margin_right") if margin != null else -1
	TestFixtures.check(res, "the tab row pads 4 px left and 42 px right inside a 14 px window margin",
		left == TAB_PAD_LEFT and right == TAB_PAD_RIGHT and edge == WINDOW_MARGIN
		and float(right + edge) == SubWindow.CLOSE_RESERVE,
		"left %d right %d window %d" % [left, right, edge])
	TestFixtures.check(res, "the tab strip ends one close reserve short of the window edge",
		strip.get_global_rect().end.x <= viewer.get_global_rect().end.x - SubWindow.CLOSE_RESERVE
		+ LAYOUT_SLACK,
		"strip ends %.1f window ends %.1f" % [strip.get_global_rect().end.x,
		viewer.get_global_rect().end.x])
	var page: PermitsPage = viewer.permits_page()
	var scroll: ScrollContainer = page.scroll_node()
	var frame: PanelContainer = scroll.get_parent() as PanelContainer
	TestFixtures.check(res, "the permits scroll sits in its own inset frame under the head",
		frame != null and frame.get_parent() == page and frame.theme_type_variation == &"InsetPanel"
		and frame.size_flags_vertical == Control.SIZE_EXPAND_FILL
		and frame.get_global_rect().encloses(scroll.get_global_rect()),
		"frame %s" % frame)
	TestFixtures.check(res, "the permits page still owns exactly one ScrollContainer",
		page.find_children("*", "ScrollContainer", true, false).size() == 1,
		"%d scrolls" % page.find_children("*", "ScrollContainer", true, false).size())
	var bar: HScrollBar = scroll.get_h_scroll_bar()
	var lowest: float = 0.0
	for node: Node in page.rows():
		lowest = maxf(lowest, (node as Control).get_global_rect().end.y)
	var bar_top: float = bar.get_global_rect().position.y
	TestFixtures.check(res, "the cards end the scroll bar gap above the horizontal bar",
		bar.is_visible_in_tree() and bar_top - lowest >= float(PermitsPage.SCROLLBAR_GAP)
		- LAYOUT_SLACK,
		"cards end %.1f bar starts %.1f gap %d" % [lowest, bar_top, PermitsPage.SCROLLBAR_GAP])


static func _case_dots(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the seeded unread fine and capture light their tab dots",
		not viewer.tab_at(0).dot and viewer.tab_at(1).dot and viewer.tab_at(2).dot
		and LegalManager.has_unread_fine() and LegalManager.has_unread_capture(),
		"dots %s %s %s" % [viewer.tab_at(0).dot, viewer.tab_at(1).dot, viewer.tab_at(2).dot])
	viewer.press_tab(&"fines")
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening a tab never clears its dot",
		viewer.tab_at(1).dot and LegalManager.has_unread_fine(),
		"dot %s unread %s" % [viewer.tab_at(1).dot, LegalManager.has_unread_fine()])
	viewer.open_review(LegalManager.TARGET_FINE, FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a Review clears its own row only",
		not LegalManager.fine(FINE_SOON).unread and LegalManager.has_unread_fine()
		and viewer.tab_at(1).dot and viewer.review_dialog().visible,
		"unread %s dot %s" % [LegalManager.has_unread_fine(), viewer.tab_at(1).dot])
	viewer.open_review(LegalManager.TARGET_FINE, FINE_FAR)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the last unread fine clears the Fines dot",
		not LegalManager.fine(FINE_FAR).unread and not LegalManager.has_unread_fine()
		and not viewer.tab_at(1).dot,
		"unread %s dot %s" % [LegalManager.has_unread_fine(), viewer.tab_at(1).dot])
	viewer.open_review(LegalManager.TARGET_CAPTURE, HELD_A)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the capture Review clears the Bailout dot",
		not LegalManager.capture(HELD_A).unread and not LegalManager.has_unread_capture()
		and not viewer.tab_at(2).dot and not viewer.review_dialog().is_fine(),
		"unread %s dot %s" % [LegalManager.has_unread_capture(), viewer.tab_at(2).dot])
	viewer.review_dialog().press_close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the Review leaves the modal stack empty",
		not viewer.review_dialog().visible and GuiFrameStack.top() == null,
		"visible %s top %s" % [viewer.review_dialog().visible, GuiFrameStack.top()])
	_reseed(viewer)
	await host.get_tree().process_frame
	TestFixtures.check(res, "reseeding brings the unread rows and both dots back",
		viewer.tab_at(1).dot and viewer.tab_at(2).dot,
		"dots %s %s" % [viewer.tab_at(1).dot, viewer.tab_at(2).dot])


static func _case_cards(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	viewer.open_tab(&"permits")
	await host.get_tree().process_frame
	var page: PermitsPage = viewer.permits_page()
	TestFixtures.check(res, "the Permits strip holds the thirteen locations",
		page.card_count() == CARDS, "%d cards" % page.card_count())
	var ordered: bool = true
	for i: int in range(page.card_count()):
		if page.card(i).name_text() != LegalStyle.location_name(i):
			ordered = false
	TestFixtures.check(res, "the cards stand in location order",
		ordered and page.card(0).name_text() == LegalStyle.location_name(HOME_LOC),
		"first card %s" % page.card(0).name_text())
	TestFixtures.check(res, "only the guild's own location wears the Home tag",
		page.card(HOME_LOC).is_home() and page.card(HOME_LOC).home_tag_visible()
		and not page.card(NEAR_LOC).is_home() and not page.card(NEAR_LOC).home_tag_visible(),
		"home %s near %s" % [page.card(HOME_LOC).home_tag_visible(),
		page.card(NEAR_LOC).home_tag_visible()])
	TestFixtures.check(res, "a card prints its nation and its average difficulty stars",
		page.card(SHORT_LOC).nation_text() == "Nation 4, Restricted"
		and is_equal_approx(page.card(HOME_LOC).stars.value, 1.5)
		and is_equal_approx(page.card(8).stars.value, 5.0)
		and page.card(8).stars.star_px == 2,
		"%s, %.1f" % [page.card(SHORT_LOC).nation_text(), page.card(HOME_LOC).stars.value])
	var mark: TextureRect = page.card(HOME_LOC).find_child("Mark", true, false) as TextureRect
	var mark_tex: Texture2D = null if mark == null else mark.texture
	var mark_art: Vector2 = Vector2.ZERO if mark_tex == null else mark_tex.get_size()
	TestFixtures.check(res, "a permission mark is 24 px of atlas art in a 24 px box",
		mark != null and mark.custom_minimum_size == Vector2(24, 24)
		and mark_art == Vector2(24, 24),
		"box %s art %s" % [Vector2.ZERO if mark == null else mark.custom_minimum_size, mark_art])
	TestFixtures.check(res, "every card lists three rules",
		page.card(HOME_LOC).rule_count() == 3 and page.card(8).rule_count() == 3,
		"%d rules" % page.card(HOME_LOC).rule_count())
	TestFixtures.check(res, "every card lists both permits and the standing row",
		page.card(HOME_LOC).permission_count() == 3 and page.card(FAR_LOC).permission_count() == 3,
		"%d rows" % page.card(HOME_LOC).permission_count())
	TestFixtures.check(res, "the head prints the prototype wording",
		page.head_text() == PermitsPage.HEAD_TEXT and page.sub_text() == PermitsPage.SUB_TEXT,
		"%s / %s" % [page.head_text(), page.sub_text()])
	TestFixtures.check(res, "the strip scrolls sideways only",
		page.scroll_node().horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and page.scroll_node().vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"modes %d %d" % [page.scroll_node().horizontal_scroll_mode,
		page.scroll_node().vertical_scroll_mode])
	TestFixtures.check(res, "a card can be found by its location id",
		page.card_for(FAR_LOC) != null and page.card_for(FAR_LOC).name_text()
		== LegalStyle.location_name(FAR_LOC) and page.card_for(99) == null,
		"card %s" % page.card_for(FAR_LOC))
	TestFixtures.check(res, "a live operating permit rings its card green",
		page.card(HOME_LOC).ring_color() == GuiColors.GO_LO
		and page.card(NEAR_LOC).ring_color() == GuiColors.BLUE_LO,
		"%s / %s" % [page.card(HOME_LOC).ring_color(), page.card(NEAR_LOC).ring_color()])
	TestFixtures.check(res, "a clean location and a location with cases differ on the card",
		page.card(HOME_LOC).permission_state(2) == LegalManager.STATE_NONE
		and page.card(NEAR_LOC).permission_state(2) == LegalManager.STATE_ACTIVE,
		"home %d near %d" % [page.card(HOME_LOC).permission_state(2),
		page.card(NEAR_LOC).permission_state(2)])


static func _case_states(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	viewer.open_tab(&"permits")
	await host.get_tree().process_frame
	var page: PermitsPage = viewer.permits_page()
	TestFixtures.check(res, "a permit nobody holds reads as none",
		LegalManager.permit_state(NEAR_LOC, LegalManager.PERMIT_OPS) == LegalManager.STATE_NONE
		and page.card_for(NEAR_LOC).permission_state(0) == LegalManager.STATE_NONE,
		"state %d" % LegalManager.permit_state(NEAR_LOC, LegalManager.PERMIT_OPS))
	TestFixtures.check(res, "a held permit the plan reaches reads as active",
		LegalManager.permit_state(HOME_LOC, LegalManager.PERMIT_OPS) == LegalManager.STATE_ACTIVE
		and LegalManager.permit_state(SOON_LOC, LegalManager.PERMIT_TELE)
		== LegalManager.STATE_ACTIVE
		and page.card_for(HOME_LOC).permission_state(0) == LegalManager.STATE_ACTIVE,
		"card %d" % page.card_for(HOME_LOC).permission_state(0))
	var bought: bool = LegalManager.request_permit(FAR_LOC, LegalManager.PERMIT_OPS)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a Domain permit can be bought while the plan reaches it",
		bought and LegalManager.has_permit(FAR_LOC, LegalManager.PERMIT_OPS)
		and LegalManager.permit_state(FAR_LOC, LegalManager.PERMIT_OPS)
		== LegalManager.STATE_ACTIVE,
		"bought %s state %d" % [bought,
		LegalManager.permit_state(FAR_LOC, LegalManager.PERMIT_OPS)])
	var dropped: bool = SubscriptionManager.set_tier("opspermit", SHORT_TIER)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a held permit turns inactive when the plan stops reaching it",
		dropped and LegalManager.permit_state(FAR_LOC, LegalManager.PERMIT_OPS)
		== LegalManager.STATE_INACTIVE
		and page.card_for(FAR_LOC).permission_state(0) == LegalManager.STATE_INACTIVE,
		"dropped %s state %d" % [dropped,
		LegalManager.permit_state(FAR_LOC, LegalManager.PERMIT_OPS)])
	TestFixtures.check(res, "the guild's own operating permit never falls out of reach",
		LegalManager.permit_state(HOME_LOC, LegalManager.PERMIT_OPS) == LegalManager.STATE_ACTIVE
		and page.card_for(HOME_LOC).permission_state(0) == LegalManager.STATE_ACTIVE,
		"state %d" % LegalManager.permit_state(HOME_LOC, LegalManager.PERMIT_OPS))
	var gate: Dictionary = LegalManager.can_request(SHORT_LOC, LegalManager.PERMIT_OPS)
	TestFixtures.check(res, "a location the plan cannot reach refuses the request",
		not bool(gate["ok"]) and str(gate["reason"]) == "Your plan does not reach this location.",
		"gate %s" % gate)
	TestFixtures.check(res, "the card locks the row the plan cannot reach",
		page.card_for(SHORT_LOC).permission_locked(0)
		and not page.card_for(HOME_LOC).permission_locked(0),
		"short %s home %s" % [page.card_for(SHORT_LOC).permission_locked(0),
		page.card_for(HOME_LOC).permission_locked(0)])
	var restored: bool = SubscriptionManager.set_tier("opspermit", OPS_TOP_TIER)
	await host.get_tree().process_frame
	TestFixtures.check(res, "restoring the upgrade makes the kept permit usable again",
		restored and LegalManager.permit_state(FAR_LOC, LegalManager.PERMIT_OPS)
		== LegalManager.STATE_ACTIVE,
		"restored %s state %d" % [restored,
		LegalManager.permit_state(FAR_LOC, LegalManager.PERMIT_OPS)])


static func _case_request(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	viewer.open_tab(&"permits")
	await host.get_tree().process_frame
	viewer.permits_page().press_request(NEAR_LOC)
	await host.get_tree().process_frame
	var dialog: PermitRequestDialog = viewer.request_dialog()
	TestFixtures.check(res, "the Request button opens the dialog on that location",
		dialog.visible and dialog.title_text() == LegalStyle.location_name(NEAR_LOC)
		and dialog.kicker_text() == "Request" + LegalManager.LABEL_JOIN + "Nation 1",
		"%s / %s" % [dialog.title_text(), dialog.kicker_text()])
	TestFixtures.check(res, "the operating permit row prints its price and offers the button",
		dialog.permit_row(LegalManager.PERMIT_OPS).price_amount() == OPS_COST
		and dialog.permit_row(LegalManager.PERMIT_OPS).request_visible()
		and dialog.permit_row(LegalManager.PERMIT_OPS).request_enabled(),
		"price %d" % dialog.permit_row(LegalManager.PERMIT_OPS).price_amount())
	TestFixtures.check(res, "a teleportation permit waits on the operating permit",
		dialog.permit_row(LegalManager.PERMIT_TELE).price_amount() == TELE_COST
		and not dialog.permit_row(LegalManager.PERMIT_TELE).request_enabled()
		and dialog.permit_row(LegalManager.PERMIT_TELE).reason_text()
		== "An operating permit comes first.",
		"reason %s" % dialog.permit_row(LegalManager.PERMIT_TELE).reason_text())
	TestFixtures.check(res, "a location with no cases reads as clean",
		dialog.is_clean() and dialog.violation_count() == 0
		and dialog.standing_text() == PermitRequestDialog.CLEAN_TEXT,
		"standing %s" % dialog.standing_text())
	var before: int = GameState.bank_notes
	dialog.press_permit(LegalManager.PERMIT_OPS)
	await host.get_tree().process_frame
	var labels: Array[String] = viewer.confirm().button_labels()
	TestFixtures.check(res, "the dialog asks the shared confirm before it spends",
		viewer.confirm().visible and viewer.confirm().button_count() == 2
		and labels[0] == "Cancel" and labels[1] == PermitRequestDialog.CONFIRM_CTA
		and not dialog.close_visible(),
		"labels %s close %s" % [labels, dialog.close_visible()])
	viewer.confirm().press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "cancelling the confirm spends nothing",
		GameState.bank_notes == before
		and not LegalManager.has_permit(NEAR_LOC, LegalManager.PERMIT_OPS)
		and dialog.close_visible(),
		"notes %d held %s" % [GameState.bank_notes,
		LegalManager.has_permit(NEAR_LOC, LegalManager.PERMIT_OPS)])
	dialog.press_permit(LegalManager.PERMIT_OPS)
	await host.get_tree().process_frame
	viewer.confirm().press(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "confirming buys the permit and drops the notes",
		LegalManager.has_permit(NEAR_LOC, LegalManager.PERMIT_OPS)
		and GameState.bank_notes == before - OPS_COST,
		"notes %d of %d" % [GameState.bank_notes, before])
	var row: TransactionData = _newest_row()
	TestFixtures.check(res, "the permit files one ledger row with the reason permit",
		row != null and row.reason == "permit" and row.amount == -OPS_COST
		and row.category == LEGAL_CATEGORY and row.label == LegalStyle.location_name(NEAR_LOC)
		+ LegalManager.LABEL_JOIN + "Operations Permit",
		"row %s %d %s" % [row.reason, row.amount, row.label])
	TestFixtures.check(res, "a bought permit shows as active with no price",
		dialog.permit_row(LegalManager.PERMIT_OPS).owned_text() == "Active"
		and not dialog.permit_row(LegalManager.PERMIT_OPS).request_visible()
		and dialog.permit_row(LegalManager.PERMIT_TELE).request_enabled(),
		"owned %s" % dialog.permit_row(LegalManager.PERMIT_OPS).owned_text())
	dialog.open(HOME_LOC)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the guild's own permit reads as Home",
		dialog.permit_row(LegalManager.PERMIT_OPS).owned_text() == "Home",
		"owned %s" % dialog.permit_row(LegalManager.PERMIT_OPS).owned_text())
	TestFixtures.check(res, "the dialog lists the open cases of that location",
		dialog.violation_count() == 1 and not dialog.is_clean()
		and dialog.standing_text() == "1 open case in this location."
		and dialog.violation_row(0).row_id() == FINE_LATE
		and dialog.violation_row(0).is_fine()
		and dialog.violation_row(0).kind_text() == "Fine",
		"cases %d standing %s" % [dialog.violation_count(), dialog.standing_text()])
	TestFixtures.check(res, "an overdue case row prints how late it is",
		dialog.violation_row(0).sub_text().ends_with("%s past due"
		% GuiDates.days_text(LATE_DAYS)),
		"sub %s" % dialog.violation_row(0).sub_text())
	dialog.press_review(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a case row hands the Review the fine and closes the dialog",
		not dialog.visible and viewer.review_dialog().visible
		and viewer.review_dialog().is_fine()
		and viewer.review_dialog().fine_entry().id == FINE_LATE,
		"dialog %s review %s" % [dialog.visible, viewer.review_dialog().visible])
	viewer.review_dialog().press_close()
	dialog.open(FAR_LOC)
	await host.get_tree().process_frame
	dialog.press_close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the X closes the request dialog",
		not dialog.visible and GuiFrameStack.top() == null,
		"visible %s top %s" % [dialog.visible, GuiFrameStack.top()])


#Designer rule 2026-10-04: the picks reset once the My Legal window is fully closed.
static func _case_reopen_legal(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var legal: LegalViewer = hud.open_viewer(&"legal") as LegalViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the HUD opens My Legal over the laid fines", legal != null,
		"opened %s" % str(legal != null))
	if legal == null:
		await GuiClickJBTests._close(host, hud)
		return
	var first_tab: StringName = legal.current_tab()
	var first_filter: StringName = legal.fines_page().current_filter()
	var first_rows: int = legal.fines_page().row_count()
	legal.open_tab(&"fines")
	await host.get_tree().process_frame
	legal.fines_page().paid_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the My Legal picks under test moved",
		legal.current_tab() != first_tab and legal.fines_page().current_filter() != first_filter
		and legal.fines_page().row_count() != first_rows,
		"tab %s filter %s rows %d of %d" % [legal.current_tab(), legal.fines_page().current_filter(),
		legal.fines_page().row_count(), first_rows])
	hud.popup().close()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing My Legal frees its content", not is_instance_valid(legal),
		"valid %s" % is_instance_valid(legal))
	var again: LegalViewer = hud.open_viewer(&"legal") as LegalViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a fully closed My Legal opens again on its first page and the Outstanding fines",
		again != null and again.current_tab() == first_tab and first_tab == &"permits"
		and again.fines_page().current_filter() == first_filter
		and first_filter == FinesPage.FILTER_OUTSTANDING and again.fines_page().row_count() == first_rows,
		"tab %s filter %s rows %d of %d" % [again.current_tab() if again != null else &"",
		again.fines_page().current_filter() if again != null else &"",
		again.fines_page().row_count() if again != null else -1, first_rows])
	await GuiClickJBTests._close(host, hud)


static func _case_fines(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var plain: bool = _no_favours()
	viewer.open_tab(&"fines")
	await host.get_tree().process_frame
	var page: FinesPage = viewer.fines_page()
	page.pick_filter(FinesPage.FILTER_OUTSTANDING)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Fines tab opens on the outstanding filter",
		plain and page.head_text() == FinesPage.HEAD_TEXT
		and page.current_filter() == FinesPage.FILTER_OUTSTANDING and not page.showing_paid()
		and page.row_count() == 3, "%d rows, filter %s" % [page.row_count(),
		page.current_filter()])
	TestFixtures.check(res, "the outstanding list keeps the filed order",
		page.row(0).row_id() == FINE_SOON and page.row(1).row_id() == FINE_LATE
		and page.row(2).row_id() == FINE_FAR,
		"ids %d %d %d" % [page.row(0).row_id(), page.row(1).row_id(), page.row(2).row_id()])
	TestFixtures.check(res, "the head sums what the outstanding fines owe",
		page.owed_amount() == SOON_AMOUNT + LATE_TOTAL + FAR_AMOUNT
		and page.sub_text().begins_with("3 outstanding" + LegalManager.LABEL_JOIN),
		"owed %d sub %s" % [page.owed_amount(), page.sub_text()])
	TestFixtures.check(res, "a fine row names its location and its crime",
		page.row_for(FINE_SOON).title_text() == LegalStyle.location_name(SOON_LOC)
		+ LegalManager.LABEL_JOIN + "Crime 1",
		"title %s" % page.row_for(FINE_SOON).title_text())
	TestFixtures.check(res, "a fine row totals the fine with its late fees",
		page.row_for(FINE_SOON).amount_value() == SOON_AMOUNT
		and page.row_for(FINE_LATE).amount_value() == LATE_TOTAL
		and page.row_for(FINE_FAR).amount_value() == FAR_AMOUNT,
		"amounts %d %d %d" % [page.row_for(FINE_SOON).amount_value(),
		page.row_for(FINE_LATE).amount_value(), page.row_for(FINE_FAR).amount_value()])
	TestFixtures.check(res, "a fine with time left counts the days down",
		page.row_for(FINE_SOON).due_text() == "In %s" % GuiDates.days_text(SOON_DAYS)
		and page.row_for(FINE_SOON).due_color() == GuiColors.CREAM
		and page.row_for(FINE_FAR).due_text() == "In %s" % GuiDates.days_text(FAR_DAYS),
		"soon %s far %s" % [page.row_for(FINE_SOON).due_text(),
		page.row_for(FINE_FAR).due_text()])
	TestFixtures.check(res, "a fine past its due day counts the days up in red",
		page.row_for(FINE_LATE).days_late() == LATE_DAYS
		and page.row_for(FINE_LATE).due_text() == "%s past due" % GuiDates.days_text(LATE_DAYS)
		and page.row_for(FINE_LATE).due_color() == GuiColors.RED,
		"due %s" % page.row_for(FINE_LATE).due_text())
	GuiManagerTests.advance_days(1)
	page.pick_filter(FinesPage.FILTER_OUTSTANDING)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a fine due within a week turns amber",
		page.row_for(FINE_SOON).due_text() == "In %s" % GuiDates.days_text(AMBER_DAYS)
		and page.row_for(FINE_SOON).due_color() == GuiColors.AMBER,
		"due %s colour %s" % [page.row_for(FINE_SOON).due_text(),
		page.row_for(FINE_SOON).due_color()])
	page.pick_filter(FinesPage.FILTER_PAID)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the paid filter lists the settled fine with the day it was paid",
		page.showing_paid() and page.row_count() == 1 and page.row(0).row_id() == FINE_DONE
		and page.row(0).is_paid() and page.row(0).amount_value() == DONE_AMOUNT
		and page.row(0).due_text() == GuiDates.short_text(LegalManager.fine(FINE_DONE).day_paid),
		"%d rows, due %s" % [page.row_count(), page.row(0).due_text()])
	page.pick_filter(FinesPage.FILTER_OUTSTANDING)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the outstanding filter leaves the paid fine out",
		page.row_for(FINE_DONE) == null and page.row_count() == 3,
		"%d rows" % page.row_count())
	page.press_review(FINE_LATE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Review button on a row opens that fine",
		viewer.review_dialog().visible and viewer.review_dialog().is_fine()
		and viewer.review_dialog().fine_entry().id == FINE_LATE,
		"open %s" % viewer.review_dialog().visible)
	viewer.review_dialog().press_close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an unknown filter key is ignored",
		page.current_filter() == FinesPage.FILTER_OUTSTANDING,
		"filter %s" % page.current_filter())


static func _case_bailout(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	viewer.open_tab(&"bail")
	await host.get_tree().process_frame
	var page: BailoutPage = viewer.bailout_page()
	TestFixtures.check(res, "the Bailout tab lists both mercs in custody",
		page.head_text() == BailoutPage.HEAD_TEXT and page.row_count() == 2
		and page.row(0).row_id() == HELD_A and page.row(1).row_id() == HELD_B
		and not page.empty_visible(), "%d rows" % page.row_count())
	var bars: IconRect = page.row_for(HELD_A).face_box.get_node_or_null(^"Bars") as IconRect
	TestFixtures.check(res, "the custody face cell draws the bars art at x3",
		bars != null and bars.icon_id == "bars" and bars.pixel_scale == 3
		and page.row_for(HELD_A).face_box.custom_minimum_size == Vector2(68, 68),
		"bars %s" % [bars])
	TestFixtures.check(res, "the summary counts the mercs the law holds",
		page.summary_text() == BailoutPage.HELD_TEXT % "2 mercs",
		"summary %s" % page.summary_text())
	TestFixtures.check(res, "a custody row names the merc, the location and the crime",
		page.row_for(HELD_A).merc_uid() == HELD_A_UID
		and page.row_for(HELD_A).title_text() == LegalStyle.merc_name(HELD_A_UID)
		+ LegalManager.LABEL_JOIN + LegalStyle.location_name(3)
		+ LegalManager.LABEL_JOIN + "Crime 5",
		"title %s" % page.row_for(HELD_A).title_text())
	TestFixtures.check(res, "a custody row counts the days served and the days left",
		page.row_for(HELD_A).served_days() == SERVED_A
		and page.row_for(HELD_A).served_text() == GuiDates.days_text(SERVED_A)
		and page.row_for(HELD_A).remaining_days() == LEFT_A
		and page.row_for(HELD_A).remaining_text() == GuiDates.days_text(LEFT_A),
		"served %s left %s" % [page.row_for(HELD_A).served_text(),
		page.row_for(HELD_A).remaining_text()])
	TestFixtures.check(res, "bail adds five notes of custody fees a day",
		page.row_for(HELD_A).bail_amount() == DUE_A
		and page.row_for(HELD_B).bail_amount() == DUE_B
		and LegalManager.custody_fee(LegalManager.capture(HELD_A))
		== SERVED_A * LegalManager.CUSTODY_FEE,
		"bail %d and %d" % [page.row_for(HELD_A).bail_amount(),
		page.row_for(HELD_B).bail_amount()])
	TestFixtures.check(res, "the page totals the bail of everyone held",
		page.total_bail() == DUE_A + DUE_B, "total %d" % page.total_bail())
	TestFixtures.check(res, "a captured merc is away from the guild",
		GameState.away_status(HELD_A_UID) == GuiTypes.MercStatus.CAPTURED
		and GameState.is_away(HELD_B_UID)
		and not GameState.busy_uids().is_empty(),
		"status %d" % GameState.away_status(HELD_A_UID))
	var held_team: Array[int] = [HELD_A_UID]
	var held_gate: Dictionary = LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, FINE_SOON,
		held_team, 0)
	TestFixtures.check(res, "a captured merc cannot join an Odd Job crew",
		not bool(held_gate["ok"])
		and str(held_gate["reason"]) == "One of those mercs is already busy.",
		"gate %s" % held_gate)
	page.press_review(HELD_B)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Review button on a custody row opens that capture",
		viewer.review_dialog().visible and not viewer.review_dialog().is_fine()
		and viewer.review_dialog().capture_entry().id == HELD_B,
		"open %s" % viewer.review_dialog().visible)


static func _case_review(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var review: ReviewDialog = viewer.review_dialog()
	review.open_fine(FINE_LATE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "whoKnows at its top tier waives the late fee",
		review.money_amount(1) == 0 and review.total_due() == LATE_AMOUNT
		and review.money_label(1) == "Late Fees (%s x %d%%)"
		% [GuiDates.days_text(LATE_DAYS), LegalManager.LATE_PCT],
		"fee %d total %d" % [review.money_amount(1), review.total_due()])
	var plain: bool = _no_favours()
	review.open_fine(FINE_LATE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "with no favours a fine gains two percent a day past due",
		plain and review.money_amount(1) == LATE_FEE and review.total_due() == LATE_TOTAL
		and LegalManager.late_fee(LegalManager.fine(FINE_LATE)) == LATE_FEE,
		"fee %d total %d" % [review.money_amount(1), review.total_due()])
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a fine Review kicks off with the crime and titles the place",
		review.kicker_text() == "Fine" + LegalManager.LABEL_JOIN + "Crime 1"
		and review.title_text() == LegalStyle.location_name(SOON_LOC),
		"%s / %s" % [review.kicker_text(), review.title_text()])
	TestFixtures.check(res, "a fine Review lists where, when and how late",
		review.fact_count() == 4 and review.fact_label(0) == "Where"
		and review.fact_label(1) == "Issued" and review.fact_label(2) == "Due"
		and review.fact_label(3) == "Past Due"
		and review.fact_value(0) == LegalStyle.location_name(SOON_LOC)
		and review.fact_value(3) == GuiDates.days_text(0),
		"facts %d, past due %s" % [review.fact_count(), review.fact_value(3)])
	TestFixtures.check(res, "a fine Review prints base, fees and total",
		review.money_row_count() == 3 and review.money_label(0) == "Base Fine"
		and review.money_amount(0) == SOON_AMOUNT and review.money_amount(1) == 0
		and review.money_label(2) == "Total Due" and review.money_amount(2) == SOON_AMOUNT
		and review.total_due() == SOON_AMOUNT,
		"rows %d total %d" % [review.money_row_count(), review.total_due()])
	TestFixtures.check(res, "a fine Review shows the mercs the case names",
		review.crew_module().member_count() == 2 and review.crew_module().member_uid(0) == 3
		and review.crew_module().member_uid(1) == 6
		and review.crew_module().member_role(0) == ReviewDialog.CREW_ROLE,
		"crew %d role %s" % [review.crew_module().member_count(),
		review.crew_module().member_role(0)])
	TestFixtures.check(res, "an open fine offers the Pay button and no paid stamp",
		review.pay_enabled() and not review.paid_visible() and not review.job_visible(),
		"pay %s paid %s" % [review.pay_enabled(), review.paid_visible()])
	GameState.bank_notes = SHORT_NOTES
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a guild that cannot pay has the Pay button disabled",
		not review.pay_enabled(),
		"pay %s notes %d" % [review.pay_enabled(), GameState.bank_notes])
	GameState.bank_notes = RICH
	review.open_fine(FINE_DONE)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a paid fine shows the day it was paid instead of the actions",
		review.paid_visible() and review.total_due() == DONE_AMOUNT,
		"paid %s total %d" % [review.paid_visible(), review.total_due()])
	review.open_capture(HELD_A)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a custody Review kicks off with the crime and titles the merc",
		review.kicker_text() == "Captured" + LegalManager.LABEL_JOIN + "Crime 5"
		and review.title_text() == LegalStyle.merc_name(HELD_A_UID),
		"%s / %s" % [review.kicker_text(), review.title_text()])
	TestFixtures.check(res, "a custody Review counts the sentence served and left",
		review.fact_label(0) == "Held At"
		and review.fact_value(0) == LegalStyle.location_name(HELD_LOC)
		and review.fact_label(2) == "Time Served"
		and review.fact_value(2) == GuiDates.days_text(SERVED_A)
		and review.fact_value(3) == "%s of %s" % [GuiDates.days_text(LEFT_A),
		GuiDates.days_text(SENTENCE_A)],
		"served %s left %s" % [review.fact_value(2), review.fact_value(3)])
	TestFixtures.check(res, "a custody Review prints bail, custody fees and total",
		review.money_label(0) == "Bail" and review.money_amount(0) == BAIL_A
		and review.money_label(1) == "Custody Fees (%s x %d)" % [GuiDates.days_text(SERVED_A),
		LegalManager.CUSTODY_FEE] and review.money_amount(1) == SERVED_A
		* LegalManager.CUSTODY_FEE and review.money_amount(2) == DUE_A
		and review.total_due() == DUE_A,
		"rows %s total %d" % [review.money_label(1), review.total_due()])
	TestFixtures.check(res, "a custody Review shows the held merc alone",
		review.crew_module().member_count() == 1
		and review.crew_module().member_uid(0) == HELD_A_UID
		and review.crew_module().member_role(0) == ReviewDialog.HELD_ROLE,
		"crew %d role %s" % [review.crew_module().member_count(),
		review.crew_module().member_role(0)])
	var others: Array[ContractView] = []
	for held: ContractView in GameState.contracts:
		if held.entry_id != CONTRACT_ENTRY:
			others.append(held)
	GameState.contracts = others
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a contract nobody holds hides the View Contract link",
		review.contract_entry_id() == CONTRACT_ENTRY and review.contract_view() == null
		and review.press_view_contract() == null,
		"entry %d view %s" % [review.contract_entry_id(), review.contract_view()])
	var entry := ContractView.new()
	entry.entry_id = CONTRACT_ENTRY
	entry.name = "Seeded Job"
	entry.difficulty = 2.5
	entry.reward = 1200
	GameState.contracts.append(entry)
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	var popup: ViewerPopup = review.press_view_contract()
	await host.get_tree().process_frame
	TestFixtures.check(res, "View Contract opens the pinned contract viewer",
		review.contract_view() != null and popup != null and popup.is_open(),
		"view %s popup %s" % [review.contract_view(), popup])
	if popup != null:
		popup.close()
	GameState.contracts.erase(entry)
	await host.get_tree().process_frame


static func _case_locks(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var review: ReviewDialog = viewer.review_dialog()
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a full plan locks neither the relationship nor the Odd Job",
		not review.opinion_locked() and not review.odd_locked()
		and LegalManager.odd_job_slots() == 3,
		"opinion %s odd %s" % [review.opinion_locked(), review.odd_locked()])
	var no_opinion: bool = SubscriptionManager.set_tier("customer", 0)
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "without Customer Satisfaction the relationship meter locks",
		no_opinion and review.opinion_locked(),
		"dropped %s locked %s" % [no_opinion, review.opinion_locked()])
	var no_odd: bool = SubscriptionManager.set_tier("oddjobs", 0)
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "without Odd Jobs the action locks and no slot is left",
		no_odd and review.odd_locked() and LegalManager.odd_job_slots() == 0,
		"dropped %s locked %s slots %d" % [no_odd, review.odd_locked(),
		LegalManager.odd_job_slots()])
	review.press_odd_job()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a locked action cannot open the Odd Job window",
		not viewer.odd_job_window().visible,
		"window %s" % viewer.odd_job_window().visible)
	var one: Array[int] = [1]
	var gate: Dictionary = LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, FINE_SOON,
		one, 0)
	TestFixtures.check(res, "the manager refuses a job the plan does not carry",
		not bool(gate["ok"]) and str(gate["reason"]) == "Odd Jobs are not part of your plan.",
		"gate %s" % gate)
	SubscriptionManager.max_out()
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "restoring the plan unlocks both again",
		not review.opinion_locked() and not review.odd_locked(),
		"opinion %s odd %s" % [review.opinion_locked(), review.odd_locked()])


static func _case_pay(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var plain: bool = _no_favours()
	var review: ReviewDialog = viewer.review_dialog()
	viewer.open_tab(&"fines")
	await host.get_tree().process_frame
	review.open_fine(FINE_LATE)
	await host.get_tree().process_frame
	review.press_pay()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Pay button asks a rich confirm that repeats the case",
		plain and viewer.confirm().visible and viewer.confirm().money_row_count() == 3
		and viewer.confirm().rich_kicker_text() == "Fine" + LegalManager.LABEL_JOIN + "Crime 2"
		+ LegalManager.LABEL_JOIN + LegalStyle.location_name(HOME_LOC)
		and review.crew_module().member_count() == 1 and viewer.confirm().has_outcome_box(),
		"kicker %s crew %d" % [viewer.confirm().rich_kicker_text(),
		review.crew_module().member_count()])
	TestFixtures.check(res, "the pay confirm asks by name and carries the amount on its button",
		viewer.confirm().title == "Pay this fine?"
		and viewer.confirm().button_labels()[1] == "Pay " + TransactionData.grouped(LATE_TOTAL),
		"title %s buttons %s" % [viewer.confirm().title, viewer.confirm().button_labels()])
	TestFixtures.check(res, "the confirm says the fine is paid and the place comes clear",
		viewer.confirm().outcome_text() == "The fine is marked paid. This clears your last open "
		+ "issue in " + LegalStyle.location_name(HOME_LOC) + ", restoring Good Standing there.",
		"outcome %s" % viewer.confirm().outcome_text())
	viewer.confirm().press(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "cancelling the pay confirm moves no notes",
		GameState.bank_notes == RICH and not LegalManager.fine(FINE_LATE).is_paid()
		and review.visible, "notes %d paid %s" % [GameState.bank_notes,
		LegalManager.fine(FINE_LATE).is_paid()])
	review.press_pay()
	await host.get_tree().process_frame
	viewer.confirm().press(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "confirming pays the fine with its late fees and closes the Review",
		LegalManager.fine(FINE_LATE).is_paid()
		and LegalManager.fine(FINE_LATE).paid == LATE_TOTAL
		and GameState.bank_notes == RICH - LATE_TOTAL and not review.visible,
		"notes %d paid %d" % [GameState.bank_notes, LegalManager.fine(FINE_LATE).paid])
	var row: TransactionData = _newest_row()
	TestFixtures.check(res, "a paid fine files one ledger row with the reason fine",
		row != null and row.reason == "fine" and row.amount == -LATE_TOTAL
		and row.category == LEGAL_CATEGORY and row.label == LegalStyle.location_name(HOME_LOC)
		+ LegalManager.LABEL_JOIN + "Fine",
		"row %s %d %s" % [row.reason, row.amount, row.label])
	var page: FinesPage = viewer.fines_page()
	page.pick_filter(FinesPage.FILTER_OUTSTANDING)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a paid fine leaves the outstanding list",
		page.row_for(FINE_LATE) == null and page.row_count() == 2,
		"%d rows" % page.row_count())
	page.pick_filter(FinesPage.FILTER_PAID)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a paid fine joins the paid list on the day it was paid",
		page.row_for(FINE_LATE) != null and page.row_for(FINE_LATE).is_paid()
		and page.row_for(FINE_LATE).due_text() == GuiDates.short_text(GameState.day())
		and page.row_count() == 2, "%d rows" % page.row_count())
	var cleared_one: bool = LegalManager.pay_fine(FINE_SOON)
	var cleared_two: bool = LegalManager.pay_fine(FINE_FAR)
	page.pick_filter(FinesPage.FILTER_OUTSTANDING)
	await host.get_tree().process_frame
	TestFixtures.check(res, "with every fine paid the outstanding list reads empty",
		cleared_one and cleared_two and page.row_count() == 0 and page.empty_visible()
		and page.empty_text() == FinesPage.EMPTY_OUTSTANDING and page.owed_amount() == 0,
		"rows %d text %s" % [page.row_count(), page.empty_text()])
	var notes: int = GameState.bank_notes
	viewer.open_tab(&"bail")
	await host.get_tree().process_frame
	review.open_capture(HELD_B)
	await host.get_tree().process_frame
	review.press_pay()
	await host.get_tree().process_frame
	viewer.confirm().press(1)
	await host.get_tree().process_frame
	var bail_row: TransactionData = _newest_row()
	TestFixtures.check(res, "paying bail frees the merc and files the reason bail",
		LegalManager.capture(HELD_B) == null and GameState.bank_notes == notes - DUE_B
		and not GameState.is_away(HELD_B_UID) and bail_row != null
		and bail_row.reason == "bail" and bail_row.amount == -DUE_B
		and bail_row.category == LEGAL_CATEGORY,
		"notes %d away %s" % [GameState.bank_notes, GameState.is_away(HELD_B_UID)])
	TestFixtures.check(res, "the freed merc is available to the guild again",
		_status_of(HELD_B_UID) != GuiTypes.MercStatus.CAPTURED
		and not GameState.busy_uids().has(HELD_B_UID),
		"status %d" % _status_of(HELD_B_UID))
	var freed: bool = LegalManager.pay_bail(HELD_A)
	await host.get_tree().process_frame
	var bail_page: BailoutPage = viewer.bailout_page()
	TestFixtures.check(res, "with nobody held the Bailout tab reads empty",
		freed and bail_page.row_count() == 0 and bail_page.empty_visible()
		and bail_page.summary_text() == BailoutPage.FREE_TEXT and bail_page.total_bail() == 0,
		"rows %d summary %s" % [bail_page.row_count(), bail_page.summary_text()])


#The outcome box of the pay confirm: what the payment does and what stays open at that place.
static func _case_outcomes(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var review: ReviewDialog = viewer.review_dialog()
	var box: ConfirmDialog = viewer.confirm()
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	review.press_pay()
	await host.get_tree().process_frame
	TestFixtures.check(res, "one other open case at the place is counted in the singular",
		box.outcome_text() == "The fine is marked paid. You still have 1 open issue in "
		+ LegalStyle.location_name(SOON_LOC) + ".", "outcome %s" % box.outcome_text())
	box.press(0)
	await host.get_tree().process_frame
	LegalManager.fine(FINE_LATE).location_id = HELD_LOC
	review.open_fine(FINE_FAR)
	await host.get_tree().process_frame
	review.press_pay()
	await host.get_tree().process_frame
	TestFixtures.check(res, "two other open cases at the place are counted in the plural",
		box.outcome_text() == "The fine is marked paid. You still have 2 open issues in "
		+ LegalStyle.location_name(HELD_LOC) + ".", "outcome %s" % box.outcome_text())
	box.press(0)
	await host.get_tree().process_frame
	_reseed(viewer)
	review.open_capture(HELD_B)
	await host.get_tree().process_frame
	review.press_pay()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the bail confirm names the lead, the crime and the place",
		box.rich_kicker_text() == "Bail" + LegalManager.LABEL_JOIN + "Crime 6"
		+ LegalManager.LABEL_JOIN + LegalStyle.location_name(SOON_LOC)
		and box.title == "Pay bail for " + LegalStyle.merc_name(HELD_B_UID) + "?"
		and box.button_labels()[1] == "Pay " + TransactionData.grouped(DUE_B),
		"kicker %s title %s" % [box.rich_kicker_text(), box.title])
	TestFixtures.check(res, "the bail outcome frees the merc and counts what stays open",
		box.outcome_text() == LegalStyle.merc_name(HELD_B_UID) + " is released from "
		+ LegalStyle.location_name(SOON_LOC) + " and returns to your guild. You still have 1 "
		+ "open issue in " + LegalStyle.location_name(SOON_LOC) + ".",
		"outcome %s" % box.outcome_text())
	box.press(0)
	await host.get_tree().process_frame
	var cleared: bool = LegalManager.pay_fine(FINE_SOON)
	review.open_capture(HELD_B)
	await host.get_tree().process_frame
	review.press_pay()
	await host.get_tree().process_frame
	TestFixtures.check(res, "clearing the last open case at a place restores Good Standing",
		cleared and box.outcome_text() == LegalStyle.merc_name(HELD_B_UID)
		+ " is released from " + LegalStyle.location_name(SOON_LOC)
		+ " and returns to your guild. This clears your last open issue in "
		+ LegalStyle.location_name(SOON_LOC) + ", restoring Good Standing there.",
		"outcome %s" % box.outcome_text())
	box.press(0)
	await host.get_tree().process_frame
	review.close()


static func _case_job_window(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	await host.get_tree().process_frame
	var fine_config: Dictionary = viewer.odd_job_config(LegalManager.TARGET_FINE, FINE_SOON)
	TestFixtures.check(res, "a fine opens the window as a renegotiation",
		str(fine_config["title"]) == LegalViewer.RENEGOTIATE_TITLE
		and str(fine_config["send_label"]) == LegalViewer.RENEGOTIATE_SEND
		and str(fine_config["outcome_text"]) == LegalViewer.FINE_OUTCOME
		and int(fine_config["max_mercs"]) == LegalManager.odd_job_slots()
		and int(fine_config["money"]) == GameState.bank_notes,
		"title %s send %s" % [fine_config["title"], fine_config["send_label"]])
	TestFixtures.check(res, "the fine facts name the place, the crime, the total and the duration",
		_fact_count(fine_config) == 4 and _fact_label(fine_config, 0) == "Location"
		and _fact_label(fine_config, 1) == "Crime" and _fact_label(fine_config, 2) == "Total Due"
		and _fact_label(fine_config, 3) == "Duration"
		and _fact_value(fine_config, 0) == LegalStyle.location_name(SOON_LOC)
		and _fact_value(fine_config, 1) == "Crime 1"
		and _fact_value(fine_config, 2) == TransactionData.grouped(SOON_AMOUNT)
		and _fact_value(fine_config, 3) == GuiDates.days_text(LegalManager.JOB_DAYS)
		and _fact_color(fine_config, 2)
			== (GuiColors.CREAM if GameState.can_afford(SOON_AMOUNT) else GuiColors.RED),
		"facts %s" % [fine_config["facts"]])
	TestFixtures.check(res, "Advisory Counsel prints its boost on a renegotiation",
		LegalManager.counsel_pct() == COUNSEL_TOP
		and str(fine_config["boost_text"]) == LegalViewer.BOOST_TEXT % COUNSEL_TOP,
		"pct %d text %s" % [LegalManager.counsel_pct(), fine_config["boost_text"]])
	TestFixtures.check(res, "the window borrows the shared pay default and pick wording",
		int(fine_config["default_pay"]) == BenefitsManager.benefit(LegalViewer.ODD_BENEFIT)
		and str(fine_config["tip_kind"]) == LegalViewer.TIP_KIND
		and str(fine_config["tip_text"]) == LegalViewer.FINE_TIP
		and str(fine_config["pick_desc"]) == LegalViewer.PICK_DESC,
		"pay %s tip %s" % [fine_config["default_pay"], fine_config["tip_text"]])
	var ids: Array[int] = _candidate_ids(fine_config)
	TestFixtures.check(res, "the crew picker leaves out the mercs the law holds",
		not ids.has(HELD_A_UID) and not ids.has(HELD_B_UID) and not ids.is_empty(),
		"%d candidates" % ids.size())
	var bail_config: Dictionary = viewer.odd_job_config(LegalManager.TARGET_CAPTURE, HELD_A)
	TestFixtures.check(res, "a capture opens the window as a break out",
		str(bail_config["title"]) == LegalViewer.BREAKOUT_TITLE + LegalManager.LABEL_JOIN
		+ LegalStyle.merc_name(HELD_A_UID)
		and str(bail_config["send_label"]) == LegalViewer.BREAKOUT_SEND
		and str(bail_config["outcome_text"]) == LegalViewer.CAPTURE_OUTCOME
		and str(bail_config["tip_text"]) == LegalViewer.CAPTURE_TIP,
		"title %s send %s" % [bail_config["title"], bail_config["send_label"]])
	TestFixtures.check(res, "the capture facts name the place, the crime, the time left and days",
		_fact_count(bail_config) == 4 and _fact_label(bail_config, 0) == "Held At"
		and _fact_label(bail_config, 1) == "Crime"
		and _fact_label(bail_config, 2) == "Time Remaining"
		and _fact_label(bail_config, 3) == "Duration"
		and _fact_value(bail_config, 0) == LegalStyle.location_name(HELD_LOC)
		and _fact_value(bail_config, 1) == "Crime 5"
		and _fact_value(bail_config, 2) == GuiDates.days_text(LEFT_A)
		and _fact_value(bail_config, 3) == GuiDates.days_text(LegalManager.JOB_DAYS)
		and _fact_color(bail_config, 2) == GuiColors.AMBER,
		"facts %s" % [bail_config["facts"]])
	TestFixtures.check(res, "counsel never boosts a break out",
		str(bail_config["boost_text"]) == "", "boost %s" % bail_config["boost_text"])
	var review: ReviewDialog = viewer.review_dialog()
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	review.press_odd_job()
	await host.get_tree().process_frame
	var window: OddJobWindow = viewer.odd_job_window()
	var uid: int = GuiManagerTests.free_uid()
	TestFixtures.check(res, "the window opens with no odds until a merc is on the crew",
		window.visible and window.odds_percent() == 0 and uid > 0,
		"visible %s odds %d uid %d" % [window.visible, window.odds_percent(), uid])
	window.crew().add_merc(uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "one merc on a renegotiation carries the counselled odds",
		window.odds_percent() == ONE_MERC_FINE_ODDS
		and LegalManager.odd_job_odds(1, LegalManager.JOB_RENEGOTIATE) == ONE_MERC_FINE_ODDS,
		"odds %d" % window.odds_percent())
	window.press_cancel()
	await host.get_tree().process_frame
	review.open_capture(HELD_A)
	await host.get_tree().process_frame
	review.press_odd_job()
	await host.get_tree().process_frame
	window.crew().add_merc(uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "one merc on a break out carries the plain odds",
		window.odds_percent() == ONE_MERC_BAIL_ODDS
		and LegalManager.odd_job_odds(1, LegalManager.JOB_BREAKOUT) == ONE_MERC_BAIL_ODDS,
		"odds %d" % window.odds_percent())
	window.press_cancel()
	await host.get_tree().process_frame
	TestFixtures.check(res, "cancelling the window files no job",
		not window.visible and LegalManager.odd_jobs.is_empty(),
		"visible %s jobs %d" % [window.visible, LegalManager.odd_jobs.size()])


static func _case_job_run(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var review: ReviewDialog = viewer.review_dialog()
	var started: Array[OddJobData] = []
	var on_start := func(new_job: OddJobData) -> void:
		started.append(new_job)
	viewer.odd_job_started.connect(on_start)
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	review.press_odd_job()
	await host.get_tree().process_frame
	var window: OddJobWindow = viewer.odd_job_window()
	var uid: int = GuiManagerTests.free_uid()
	window.crew().add_merc(uid)
	window.crew().set_pay(PAY_EACH)
	await host.get_tree().process_frame
	var before: int = GameState.bank_notes
	window.press_send()
	await host.get_tree().process_frame
	viewer.odd_job_started.disconnect(on_start)
	var job: OddJobData = LegalManager.active_odd_job(LegalManager.TARGET_FINE, FINE_SOON)
	TestFixtures.check(res, "Send files the job on that case and reports it",
		started.size() == 1 and job != null and started[0] == job
		and job.target_id == FINE_SOON and job.kind == LegalManager.JOB_RENEGOTIATE
		and job.days == LegalManager.JOB_DAYS and job.odds == ONE_MERC_FINE_ODDS,
		"started %d job %s" % [started.size(), job])
	if job == null:
		return
	TestFixtures.check(res, "the crew is paid up front under the reason odd_job",
		GameState.bank_notes == before - PAY_EACH and job.pay_per == PAY_EACH
		and job.total_pay() == PAY_EACH, "notes %d of %d" % [GameState.bank_notes, before])
	var row: TransactionData = _newest_row()
	TestFixtures.check(res, "the crew pay files one Odd Job ledger row",
		row != null and row.reason == "odd_job" and row.amount == -PAY_EACH
		and row.category == ODD_CATEGORY and row.label == LegalStyle.location_name(SOON_LOC)
		+ LegalManager.LABEL_JOIN + "Renegotiate",
		"row %s %d %s" % [row.reason, row.amount, row.label])
	TestFixtures.check(res, "the crew is away on the job until the day it lands",
		GameState.away_status(uid) == GuiTypes.MercStatus.ODD_JOB
		and GameState.away_until(uid) == (job.day_started + job.days)
		* CampaignClock.MINUTES_PER_DAY
		and _status_of(uid) == GuiTypes.MercStatus.ODD_JOB,
		"status %d until %d" % [GameState.away_status(uid), GameState.away_until(uid)])
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Review shows the job running with an empty bar",
		not window.visible and review.job_visible() and review.active_job() == job
		and review.job_bar.caption_text() == ReviewDialog.RENEGOTIATE_CAPTION
		and review.job_bar.filled_cells() == 0,
		"caption %s cells %d" % [review.job_bar.caption_text(), review.job_bar.filled_cells()])
	var again: Array[int] = [GuiManagerTests.free_uid()]
	var gate: Dictionary = LegalManager.can_start_odd_job(LegalManager.TARGET_FINE, FINE_SOON,
		again, 0)
	TestFixtures.check(res, "a second job on the same case is refused",
		not bool(gate["ok"])
		and str(gate["reason"]) == "A job is already running on this case.", "gate %s" % gate)
	review.press_odd_job()
	await host.get_tree().process_frame
	TestFixtures.check(res, "while the job runs neither action can be pressed",
		not window.visible and not review.pay_enabled(),
		"window %s pay %s" % [window.visible, review.pay_enabled()])
	var busy_config: Dictionary = viewer.odd_job_config(LegalManager.TARGET_FINE, FINE_FAR)
	TestFixtures.check(res, "a merc on a job is no candidate for another",
		not _candidate_ids(busy_config).has(uid),
		"candidates %d" % _candidate_ids(busy_config).size())
	GuiManagerTests.advance_days(HALF_JOB)
	review.open_fine(FINE_SOON)
	await host.get_tree().process_frame
	TestFixtures.check(res, "halfway through the job the bar is half full",
		LegalManager.job_cells(job, ReviewDialog.JOB_CELLS) == HALF_JOB
		and review.job_bar.filled_cells() == HALF_JOB
		and LegalManager.odd_job_days_left(job) == LegalManager.JOB_DAYS - HALF_JOB,
		"cells %d left %d" % [review.job_bar.filled_cells(),
		LegalManager.odd_job_days_left(job)])


static func _case_job_outcomes(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	await host.get_tree().process_frame
	var outcomes: Array[bool] = []
	var on_done := func(_target: Dictionary, success: bool) -> void:
		outcomes.append(success)
	LegalManager.odd_job_resolved.connect(on_done)
	var uid: int = GuiManagerTests.free_uid()
	var team: Array[int] = [uid]
	var won: OddJobData = LegalManager.start_odd_job(LegalManager.TARGET_FINE, FINE_SOON,
		LegalManager.JOB_RENEGOTIATE, team, 0)
	if won != null:
		won.odds = 100
	GuiManagerTests.advance_days(LegalManager.JOB_DAYS)
	await host.get_tree().process_frame
	var soon: FineData = LegalManager.fine(FINE_SOON)
	TestFixtures.check(res, "a won renegotiation halves the fine and frees the crew",
		won != null and soon.amount == WON_AMOUNT and soon.previous_amount == SOON_AMOUNT
		and soon.note == "Renegotiated." and soon.unread
		and not GameState.is_away(uid) and LegalManager.odd_jobs.is_empty(),
		"amount %d note %s" % [soon.amount, soon.note])
	var lost: OddJobData = LegalManager.start_odd_job(LegalManager.TARGET_FINE, FINE_FAR,
		LegalManager.JOB_RENEGOTIATE, team, 0)
	if lost != null:
		lost.odds = 0
	GuiManagerTests.advance_days(LegalManager.JOB_DAYS)
	await host.get_tree().process_frame
	var far: FineData = LegalManager.fine(FINE_FAR)
	TestFixtures.check(res, "a lost renegotiation raises the fine by a quarter",
		lost != null and far.amount == LOST_AMOUNT and far.previous_amount == FAR_AMOUNT
		and far.note == "Renegotiation failed." and far.unread
		and not GameState.is_away(uid), "amount %d note %s" % [far.amount, far.note])
	var out: OddJobData = LegalManager.start_odd_job(LegalManager.TARGET_CAPTURE, HELD_A,
		LegalManager.JOB_BREAKOUT, team, 0)
	if out != null:
		out.odds = 100
	GuiManagerTests.advance_days(LegalManager.JOB_DAYS)
	await host.get_tree().process_frame
	viewer.open_tab(&"bail")
	await host.get_tree().process_frame
	TestFixtures.check(res, "a won break out releases the merc with no bail paid",
		out != null and LegalManager.capture(HELD_A) == null and not GameState.is_away(HELD_A_UID)
		and viewer.bailout_page().row_count() == 1,
		"capture %s rows %d" % [LegalManager.capture(HELD_A),
		viewer.bailout_page().row_count()])
	var caught: OddJobData = LegalManager.start_odd_job(LegalManager.TARGET_CAPTURE, HELD_B,
		LegalManager.JOB_BREAKOUT, team, 0)
	if caught != null:
		caught.odds = 0
	GuiManagerTests.advance_days(LegalManager.JOB_DAYS)
	await host.get_tree().process_frame
	LegalManager.odd_job_resolved.disconnect(on_done)
	var held: CaptureData = LegalManager.capture(HELD_B)
	TestFixtures.check(res, "a lost break out raises the bail by half",
		caught != null and held != null and held.bail == LOST_BAIL and held.previous_bail == BAIL_B
		and held.note == "Break out failed." and held.unread
		and GameState.is_away(HELD_B_UID), "bail %d note %s" % [held.bail, held.note])
	TestFixtures.check(res, "every job reports its case and its outcome once",
		outcomes.size() == 4 and outcomes[0] and not outcomes[1] and outcomes[2]
		and not outcomes[3], "outcomes %s" % [outcomes])
	TestFixtures.check(res, "the crew comes back to the guild after each job",
		not GameState.is_away(uid) and _status_of(uid) != GuiTypes.MercStatus.ODD_JOB
		and LegalManager.odd_jobs.is_empty(),
		"away %s jobs %d" % [GameState.is_away(uid), LegalManager.odd_jobs.size()])


#GameState.start_new_game clears the shared away registry; no capture or running job outlives it.
static func _case_holds(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	var held: bool = _all_held(GuiTypes.MercStatus.CAPTURED)
	GameState.start_new_game()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a new game drops every capture and frees its captives",
		held and _none_held(),
		"held %s captures %d uids %d and %d read %d and %d" % [held, LegalManager.captured.size(),
		HELD_A_UID, HELD_B_UID, GameState.away_status(HELD_A_UID), GameState.away_status(HELD_B_UID)])
	_lay_legal()
	held = _all_held(GuiTypes.MercStatus.CAPTURED)
	GameState.start_new_game()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a second new game in one session drops the captures again",
		held and _none_held(),
		"held %s captures %d uids %d and %d read %d and %d" % [held, LegalManager.captured.size(),
		HELD_A_UID, HELD_B_UID, GameState.away_status(HELD_A_UID), GameState.away_status(HELD_B_UID)])
	SubscriptionManager.max_out()
	GameState.bank_notes = RICH
	_lay_legal()
	var uid: int = GuiManagerTests.free_uid()
	var team: Array[int] = [uid]
	var job: OddJobData = LegalManager.start_odd_job(LegalManager.TARGET_FINE, FINE_SOON,
		LegalManager.JOB_RENEGOTIATE, team, 0)
	var running: bool = job != null and GameState.away_status(uid) == GuiTypes.MercStatus.ODD_JOB
	GameState.start_new_game()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a new game drops a running job and frees its crew",
		running and uid > 0 and not LegalManager.odd_jobs.has(job)
		and GameState.away_status(uid) == -1 and not GameState.busy_uids().has(uid),
		"uid %d status %d jobs %d" % [uid, GameState.away_status(uid), LegalManager.odd_jobs.size()])
	_lay_legal()
	var seen: Array[int] = []
	var watch := func(away_uid: int) -> void:
		seen.append(away_uid)
	GameState.away_changed.connect(watch)
	GameState.roster_changed.emit()
	await host.get_tree().process_frame
	GameState.away_changed.disconnect(watch)
	TestFixtures.check(res, "a roster signal writes no hold while no hold is missing",
		seen.is_empty(), "signals %s" % [seen])
	GameState.clear_away(HELD_A_UID)
	GameState.set_away(HELD_A_UID, GuiTypes.MercStatus.ODD_JOB, OTHER_UNTIL)
	GameState.roster_changed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a captive that reads another away status keeps that status",
		GameState.away_status(HELD_A_UID) == GuiTypes.MercStatus.ODD_JOB
		and GameState.away_until(HELD_A_UID) == OTHER_UNTIL,
		"status %d until %d" % [GameState.away_status(HELD_A_UID),
		GameState.away_until(HELD_A_UID)])


#True when the law holds no row and neither captive of LAY_CAPTURES reads an away status.
static func _none_held() -> bool:
	return (LegalManager.captured.is_empty() and GameState.away_status(HELD_A_UID) == -1
		and GameState.away_status(HELD_B_UID) == -1)


#True while every captive reads the status and stands in the busy list.
static func _all_held(status: int) -> bool:
	if LegalManager.captured.is_empty():
		return false
	var busy: Array[int] = GameState.busy_uids()
	for row: CaptureData in LegalManager.captured:
		if GameState.away_status(row.merc_uid) != status:
			return false
		if not busy.has(row.merc_uid):
			return false
	return true


#Every Legal action button is a BevelButton and shades with the state it is in.
static func _case_bevel_sweep(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	viewer.open_tab(&"fines")
	await host.get_tree().process_frame
	var fines: FinesPage = viewer.fines_page()
	fines.pick_filter(FinesPage.FILTER_OUTSTANDING)
	await host.get_tree().process_frame
	var outstanding_bevel: BevelButton = fines.outstanding_button as BevelButton
	var paid_bevel: BevelButton = fines.paid_button as BevelButton
	TestFixtures.check(res, "the outstanding fines filter is an orange BevelButton when picked",
		GuiKitTests.is_bevel(outstanding_bevel, &"orange")
		and GuiKitTests.is_bevel(paid_bevel, &"neutral"),
		"outstanding %s paid %s" % [outstanding_bevel, paid_bevel])
	fines.pick_filter(FinesPage.FILTER_PAID)
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking Paid swaps the shading to the paid filter",
		GuiKitTests.is_bevel(outstanding_bevel, &"neutral") and GuiKitTests.is_bevel(paid_bevel, &"orange"),
		"outstanding %s paid %s" % [outstanding_bevel.kind, paid_bevel.kind])
	fines.pick_filter(FinesPage.FILTER_OUTSTANDING)
	await host.get_tree().process_frame
	var review_bevel: BevelButton = fines.row_for(FINE_SOON).review_button as BevelButton
	TestFixtures.check(res, "a fine row's Review button is a neutral BevelButton",
		GuiKitTests.is_bevel(review_bevel, &"neutral", FineRow.REVIEW_TEXT),
		"review %s" % review_bevel)
	viewer.open_tab(&"permits")
	await host.get_tree().process_frame
	var permits: PermitsPage = viewer.permits_page()
	var card_bevel: BevelButton = permits.card_for(NEAR_LOC).request_button as BevelButton
	TestFixtures.check(res, "a location card's Request button is an orange BevelButton",
		GuiKitTests.is_bevel(card_bevel, &"orange", "Request"),
		"card %s" % card_bevel)
	permits.press_request(NEAR_LOC)
	await host.get_tree().process_frame
	var dialog: PermitRequestDialog = viewer.request_dialog()
	var permit_bevel: BevelButton = dialog.permit_row(LegalManager.PERMIT_OPS).request_button \
		as BevelButton
	TestFixtures.check(res, "the permit dialog's Request button is a go BevelButton",
		GuiKitTests.is_bevel(permit_bevel, &"go", "Request"),
		"permit %s" % permit_bevel)
	dialog.press_close()
	await host.get_tree().process_frame
	var review: ReviewDialog = viewer.review_dialog()
	review.open_fine(FINE_LATE)
	await host.get_tree().process_frame
	var odd_bevel: BevelButton = review.odd_button as BevelButton
	var pay_bevel: BevelButton = review.pay_button as BevelButton
	TestFixtures.check(res, "the Review dialog's renegotiate and pay buttons shade orange and go",
		GuiKitTests.is_bevel(odd_bevel, &"orange")
		and GuiKitTests.is_bevel(pay_bevel, &"go"),
		"odd %s pay %s" % [odd_bevel, pay_bevel])
	review.press_close()


#The row-corner NotificationDot on all three Legal row types sits 2 px in from the top-left
#corner, through the 28 x 28 FRAME_SIZE.
static func _case_dot_frames(res: Dictionary, host: Node, viewer: LegalViewer) -> void:
	_reseed(viewer)
	viewer.open_tab(&"bail")
	await host.get_tree().process_frame
	var captured: CapturedRow = viewer.bailout_page().row_for(HELD_A)
	_check_dot_frame(res, "a Bailout row's dot", captured.dot)
	viewer.open_tab(&"fines")
	await host.get_tree().process_frame
	var fine: FineRow = viewer.fines_page().row_for(FINE_SOON)
	_check_dot_frame(res, "a Fines row's dot", fine.dot)
	viewer.open_tab(&"permits")
	await host.get_tree().process_frame
	viewer.permits_page().press_request(NEAR_LOC)
	await host.get_tree().process_frame
	var dialog: PermitRequestDialog = viewer.request_dialog()
	dialog.open(HOME_LOC)
	await host.get_tree().process_frame
	_check_dot_frame(res, "a permit dialog's violation row dot", dialog.violation_row(0).dot)
	dialog.press_close()
	await host.get_tree().process_frame


#The shared check: offset_top sits at the 2 px pin, offset_right 2 px off the right edge and the
#other two the 28 x 28 frame away, on the top-right corner every notification dot takes.
static func _check_dot_frame(res: Dictionary, label: String, dot: NotificationDot) -> void:
	TestFixtures.check(res, "%s pins 2 px in from the top-right corner through FRAME_SIZE" % label,
		GuiNotifyTests.dot_at(dot, CORNER_TOP_RIGHT, Vector2(2, 2)),
		"%s: left %.1f top %.1f right %.1f bottom %.1f" % [dot,
			dot.offset_left if dot != null else -1.0, dot.offset_top if dot != null else -1.0,
			dot.offset_right if dot != null else -1.0, dot.offset_bottom if dot != null else -1.0])


#Every tab on the 1280 x 644 band: fits, stays on the canvas and keeps the tab row off the X. A
#fresh viewer opens on the band the way a SubWindow lays it out.
static func _case_fit(res: Dictionary, host: Node) -> void:
	var viewer: LegalViewer = VIEWER.instantiate() as LegalViewer
	GuiAdsTests.fit_band(viewer)
	host.add_child(viewer)
	_reseed(viewer)
	var row: Control = viewer.get_node(TAB_PAD_PATH) as Control
	var pages: Array[Control] = [viewer.permits_page(), viewer.fines_page(), viewer.bailout_page()]
	for i: int in range(LegalViewer.TAB_KEYS.size()):
		viewer.open_tab(LegalViewer.TAB_KEYS[i])
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		GuiAdsTests.check_fit(res, "Legal %s" % LegalViewer.TAB_KEYS[i], viewer, pages[i], [row])
	GuiFrameStack.clear()
	host.remove_child(viewer)
	viewer.queue_free()
	await host.get_tree().process_frame
