class_name GuiKitTests

#Shared atoms: ViewerPopup, CellBar, NotesLabel, StatTile.
#Run with the gui-kit-tests harness flag.

const VIEWER_POPUP_SCENE := "res://Scenes/GUI/Shared/ViewerPopup.tscn"
const KIT_STUB_SCENE := "res://Scenes/Tests/KitStub.tscn"
const CELL_BAR_SCENE := "res://Scenes/GUI/Shared/CellBar.tscn"
const NOTES_LABEL_SCENE := "res://Scenes/GUI/Shared/NotesLabel.tscn"
const STAT_TILE_SCENE := "res://Scenes/GUI/Shared/StatTile.tscn"
const CONTRACT_VIEWER_SCENE := "res://Scenes/GUI/Contracts/ContractViewer.tscn"
const MERC_VIEWER_SCENE := "res://Scenes/GUI/Mercs/MercViewer.tscn"
const FINANCE_VIEWER_SCENE := "res://Scenes/GUI/Finance/FinanceViewer.tscn"
#The posting the View Applicants case opens: campaign 1 of GuiHiringTests._lay_board sent one applicant.
const VIEW_CAMPAIGN: int = 1
#Content heights the fit case opens: under FIT_MIN_H, inside the band and past it.
const FIT_SHORT_H: float = 100.0
const FIT_MID_H: float = 400.0
const FIT_TALL_H: float = 900.0


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_viewer_popup_layout(res, host)
	await _case_viewer_popup_lifecycle(res, host)
	await _case_viewer_popup_frame_stack(res, host)
	await _case_viewer_popup_show_scene(res, host)
	await _case_viewer_popup_helpers(res, host)
	await _case_viewer_popup_hiring(res, host)
	await _case_viewer_popup_fit(res, host)
	_case_cell_bar_ratio(res, host)
	_case_cell_bar_min_size(res, host)
	_case_notes_label_format(res, host)
	await _case_notes_label_display(res, host)
	await _case_stat_tile(res, host)
	return TestFixtures.summarize(res, "GUI KIT")


#Returns the first descendant (or node itself) whose mouse_filter stops the mouse, null when
#every node in the tree is a pass-through.
static func _find_stopping_mouse(node: Node) -> Node:
	if node is Control and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		return node
	for child: Node in node.get_children():
		var hit: Node = _find_stopping_mouse(child)
		if hit != null:
			return hit
	return null


static func _push_escape(host: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	host.get_viewport().push_input(event)


static func _case_viewer_popup_layout(res: Dictionary, host: Node) -> void:
	GuiFrameTests.reset_frames()
	var popup: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	popup.content_width = float(ViewerPopup.CONTRACT["width"])
	TestFixtures.check(res, "the CONTRACT preset reports a 940 wide frame at 1:1",
		popup.frame_size().is_equal_approx(Vector2(940.0, 720.0)),
		"got %s" % [popup.frame_size()])
	popup.content_width = float(ViewerPopup.INVEST["width"])
	TestFixtures.check(res, "the INVEST preset reports a 1280 wide frame at 1:1",
		popup.frame_size().is_equal_approx(Vector2(1280.0, 720.0)),
		"got %s" % [popup.frame_size()])
	popup.content_width = float(ViewerPopup.MERC["width"])
	TestFixtures.check(res, "the MERC preset reports a 988 wide frame at 1:1",
		popup.frame_size().is_equal_approx(Vector2(988.0, 720.0)),
		"got %s" % [popup.frame_size()])

	host.add_child(popup)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	popup.open(GuiFrameTests.empty_scene())
	var holder: Control = popup.holder
	GuiFrameTests.check_frame_layout(res, popup, Rect2(146.0, 0.0, 988.0, 720.0))
	GuiFrameStack.bottom_reserve = 76.0
	popup._layout()
	TestFixtures.check(res, "the band above the bottom bar shortens the popup",
		popup.frame_size().is_equal_approx(Vector2(988, 644))
			and holder.size.is_equal_approx(Vector2(988, 644)),
		"frame_size %s holder %s" % [popup.frame_size(), holder.size])
	GuiFrameStack.bottom_reserve = 0.0
	popup.close()
	popup.queue_free()


static func _case_viewer_popup_lifecycle(res: Dictionary, host: Node) -> void:
	GuiFrameTests.reset_frames()
	var popup: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	host.add_child(popup)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a fresh popup starts closed", not popup.is_open(),
		"is_open %s" % popup.is_open())

	var packed: PackedScene = GuiFrameTests.empty_scene()

	var setup_ran_detached: Array[bool] = [false]
	var setup := func(node: Node) -> void: setup_ran_detached[0] = not node.is_inside_tree()
	var instance: Node = popup.open(packed, setup)
	TestFixtures.check(res, "open returns the instance and runs setup before adding it",
		instance != null and setup_ran_detached[0] and popup.current() == instance
			and popup.is_open(),
		"instance %s setup_ran %s is_open %s" % [instance, setup_ran_detached[0], popup.is_open()])

	var closed_count: Array[int] = [0]
	popup.closed.connect(func() -> void: closed_count[0] += 1)
	popup.close()
	TestFixtures.check(res, "close frees the content, hides and emits closed exactly once",
		closed_count[0] == 1 and popup.current() == null and not popup.is_open(),
		"closed %d current %s is_open %s" % [closed_count[0], popup.current(), popup.is_open()])
	popup.queue_free()

	var kept: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	kept.free_on_close = false
	host.add_child(kept)
	await host.get_tree().process_frame
	kept.open(GuiFrameTests.empty_scene())
	kept.close()
	TestFixtures.check(res, "free_on_close false leaves the popup node alive after close",
		is_instance_valid(kept), "valid %s" % is_instance_valid(kept))
	kept.queue_free()

	var freed: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	freed.free_on_close = true
	host.add_child(freed)
	await host.get_tree().process_frame
	freed.open(GuiFrameTests.empty_scene())
	freed.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "free_on_close true frees the popup node after close",
		not is_instance_valid(freed), "valid %s" % is_instance_valid(freed))


static func _case_viewer_popup_frame_stack(res: Dictionary, host: Node) -> void:
	GuiFrameTests.reset_frames()
	var outer: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	host.add_child(outer)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening the popup registers it on the frame stack",
		outer.open(GuiFrameTests.empty_scene()) != null and GuiFrameStack.top() == outer
			and GuiFrameStack.depth() == 1,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])

	var inner: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	outer.holder.add_child(inner)
	await host.get_tree().process_frame
	inner.open(GuiFrameTests.empty_scene())
	TestFixtures.check(res, "a nested popup goes on top of the stack",
		GuiFrameStack.top() == inner and GuiFrameStack.depth() == 2,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])

	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "escape closes the nested popup before the outer one",
		not inner.is_open() and outer.is_open() and GuiFrameStack.top() == outer,
		"inner %s outer %s top %s" % [inner.is_open(), outer.is_open(), GuiFrameStack.top()])

	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the popup leaves the frame stack empty",
		not outer.is_open() and GuiFrameStack.depth() == 0,
		"outer %s depth %d" % [outer.is_open(), GuiFrameStack.depth()])
	inner.queue_free()
	outer.queue_free()


static func _case_viewer_popup_show_scene(res: Dictionary, host: Node) -> void:
	GuiFrameTests.reset_frames()
	var missing: ViewerPopup = ViewerPopup.show_scene(host,
		"res://Scenes/GUI/Shared/DoesNotExist.tscn", ViewerPopup.CONTRACT)
	TestFixtures.check(res, "show_scene with a missing path returns null", missing == null,
		"got %s" % missing)

	var setup := func(node: Node) -> void:
		if "hide_list" in node:
			node.hide_list = true
	var popup: ViewerPopup = ViewerPopup.show_scene(host, KIT_STUB_SCENE, ViewerPopup.CONTRACT, setup)
	await host.get_tree().process_frame
	var content: KitStub = popup.current() as KitStub
	var hide_list_set: bool = content != null and content.hide_list
	TestFixtures.check(res, "show_scene runs the setup callable's property guard on the real content",
		popup != null and hide_list_set,
		"popup %s hide_list %s" % [popup, hide_list_set])
	popup.close()


static func _case_viewer_popup_helpers(res: Dictionary, host: Node) -> void:
	GuiFrameTests.reset_frames()
	var contract_popup: ViewerPopup = ViewerPopup.show_contract(host, 7)
	await host.get_tree().process_frame
	var contract_content: Node = contract_popup.current() if contract_popup != null else null
	TestFixtures.check(res, "show_contract opens the pinned ContractViewer scene",
		contract_popup != null and contract_popup.is_open() and contract_content is ContractViewer
			and contract_content.scene_file_path == CONTRACT_VIEWER_SCENE,
		"popup %s content %s" % [contract_popup, contract_content])
	if contract_popup != null:
		contract_popup.close()

	var applicant: ApplicantData = ApplicantData.new()
	var merc_popup: ViewerPopup = ViewerPopup.show_applicant(host, applicant)
	await host.get_tree().process_frame
	var merc_content: Node = merc_popup.current() if merc_popup != null else null
	TestFixtures.check(res, "show_applicant opens the pinned MercViewer scene",
		merc_popup != null and merc_popup.is_open() and merc_content is MercViewer
			and merc_content.scene_file_path == MERC_VIEWER_SCENE,
		"popup %s content %s" % [merc_popup, merc_content])
	if merc_popup != null:
		merc_popup.close()

	var invest_popup: ViewerPopup = ViewerPopup.show_invest(host, 3)
	var invest_content: Node = invest_popup.current() if invest_popup != null else null
	TestFixtures.check(res, "show_invest opens the pinned FinanceViewer scene in invest mode",
		invest_popup != null and invest_popup.is_open() and invest_content is FinanceViewer
			and invest_content.scene_file_path == FINANCE_VIEWER_SCENE
			and invest_content.invest_only,
		"popup %s content %s" % [invest_popup, invest_content])
	if invest_popup != null:
		invest_popup.close()


#show_hiring: the Finance window at the invest width on its Hiring page alone, held to one campaign, and the
#applicant popup it opens closing first on Esc.
static func _case_viewer_popup_hiring(res: Dictionary, host: Node) -> void:
	GuiFrameTests.reset_frames()
	PromotionsManager.reset()
	GuiHiringTests._lay_board()
	TestFixtures.check(res, "the HIRING preset takes the INVEST width",
		is_equal_approx(float(ViewerPopup.HIRING["width"]), float(ViewerPopup.INVEST["width"]))
			and is_equal_approx(float(ViewerPopup.HIRING["width"]), ViewerPopup.FINANCE_WIDTH),
		"hiring %s invest %s" % [ViewerPopup.HIRING, ViewerPopup.INVEST])
	var popup: ViewerPopup = ViewerPopup.show_hiring(host, VIEW_CAMPAIGN)
	await TestFixtures.frames(host, 3)
	var content: Node = popup.current() if popup != null else null
	var viewer: FinanceViewer = content as FinanceViewer
	TestFixtures.check(res, "show_hiring opens the pinned FinanceViewer scene in hiring mode at 1280",
		popup != null and popup.is_open() and viewer != null
			and viewer.scene_file_path == FINANCE_VIEWER_SCENE and viewer.hiring_only
			and not viewer.invest_only and is_equal_approx(popup.content_width, ViewerPopup.FINANCE_WIDTH),
		"popup %s content %s" % [popup, content])
	if viewer == null:
		if popup != null:
			popup.close()
		return
	var page: HiringTab = viewer.page(FinanceViewer.HIRING_KEY) as HiringTab
	var want: Array[int] = []
	for a: ApplicantData in PromotionsManager.applicants:
		if a.campaign_id == VIEW_CAMPAIGN:
			want.append(a.id)
	var got: Array[int] = []
	if page != null:
		got = page.card_ids()
	got.sort()
	TestFixtures.check(res, "the window opens on a Hiring page held to the campaign",
		viewer.current_tab() == FinanceViewer.HIRING_KEY and page != null
			and page.fixed_campaign == VIEW_CAMPAIGN,
		"tab %s page %s" % [String(viewer.current_tab()), page])
	TestFixtures.check(res, "the window hides the tab row and the filter column",
		not viewer.tab_pad.visible and page != null and not page.filter_column().visible,
		"row shown %s" % [viewer.tab_pad.visible])
	TestFixtures.check(res, "the window lists the applicants of that campaign alone",
		not want.is_empty() and got == want, "%s against %s" % [got, want])
	if page == null or want.is_empty():
		popup.close()
		return
	var toggle: Rect2 = page.sort_toggle().get_global_rect()
	var close_rect: Rect2 = popup.close_x.get_global_rect()
	TestFixtures.check(res, "the Sort controls end left of the close X", toggle.end.x <= close_rect.position.x,
		"toggle ends %.1f, X starts %.1f" % [toggle.end.x, close_rect.position.x])
	page.press_view(want[0])
	await TestFixtures.frames(host, 2)
	var inner: ViewerPopup = page.applicant_popup()
	TestFixtures.check(res, "an applicant opened in the window goes on top of it",
		inner != null and GuiFrameStack.top() == inner and GuiFrameStack.depth() == 2,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])
	_push_escape(host)
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "Esc closes the applicant before the window",
		popup.is_open() and GuiFrameStack.top() == popup and GuiFrameStack.depth() == 1,
		"open %s depth %d" % [popup.is_open(), GuiFrameStack.depth()])
	_push_escape(host)
	await TestFixtures.frames(host, 2)
	TestFixtures.check(res, "the second Esc closes the window and empties the frame stack",
		GuiFrameStack.depth() == 0 and (not is_instance_valid(popup) or not popup.is_open()),
		"depth %d" % [GuiFrameStack.depth()])
	PromotionsManager.reset()


#COMPLETED keeps the contract width and fits the canvas to the content: a short content takes FIT_MIN_H,
#a taller one its own height plus the border, one past the band stops at the band, and the next open
#lets the window go back to the band.
static func _case_viewer_popup_fit(res: Dictionary, host: Node) -> void:
	GuiFrameTests.reset_frames()
	TestFixtures.check(res, "the COMPLETED preset keeps the contract width and fits, the CONTRACT one does not",
		is_equal_approx(float(ViewerPopup.COMPLETED["width"]), ViewerPopup.CONTRACT_WIDTH)
		and is_equal_approx(float(ViewerPopup.CONTRACT["width"]), ViewerPopup.CONTRACT_WIDTH)
		and bool(ViewerPopup.COMPLETED.get("fit", false))
		and not bool(ViewerPopup.CONTRACT.get("fit", false)),
		"completed %s contract %s" % [ViewerPopup.COMPLETED, ViewerPopup.CONTRACT])
	var view_size: Vector2 = host.get_viewport().get_visible_rect().size
	GuiFrameStack.bottom_reserve = view_size.y - GuiAcceptTests.BAND_SIZE.y
	var band: float = GuiFrameStack.band_height(view_size.y)
	var popup: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	popup.content_width = ViewerPopup.CONTRACT_WIDTH
	host.add_child(popup)
	await host.get_tree().process_frame
	var content: Control = popup.open(_sized_scene(FIT_SHORT_H)) as Control
	popup.fit_to_content()
	var holder: Control = popup.holder
	var fit_floor := Vector2(ViewerPopup.CONTRACT_WIDTH, SubWindow.FIT_MIN_H)
	var centred := Vector2(floorf((view_size.x - fit_floor.x) / 2.0), floorf((band - fit_floor.y) / 2.0))
	TestFixtures.check(res, "a short content takes the shortest fitted canvas, centred in the band",
		popup.is_fitted() and holder.size.is_equal_approx(fit_floor)
		and holder.position.is_equal_approx(centred)
		and popup.frame.get_rect().is_equal_approx(holder.get_rect())
		and popup.border.get_rect().is_equal_approx(holder.get_rect())
		and holder.get_global_rect().encloses(popup.close_x.get_global_rect()),
		"holder %s at %s frame %s border %s x %s" % [holder.size, holder.position,
		popup.frame.get_rect(), popup.border.get_rect(), popup.close_x.get_global_rect()])
	content.custom_minimum_size = Vector2(0.0, FIT_MID_H)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a taller content takes its own height plus the border",
		is_equal_approx(holder.size.y, FIT_MID_H + 2.0 * SubWindow.BORDER),
		"holder %s" % holder.size)
	content.custom_minimum_size = Vector2(0.0, FIT_TALL_H)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a content past the band stops at the band",
		is_equal_approx(holder.size.y, band) and is_equal_approx(popup.band_cap(), band),
		"holder %s band %.0f cap %.0f" % [holder.size, band, popup.band_cap()])
	popup.open(GuiFrameTests.empty_scene())
	TestFixtures.check(res, "the next open lets the window go back to the band",
		not popup.is_fitted() and is_equal_approx(holder.size.y, band),
		"fitted %s holder %s" % [popup.is_fitted(), holder.size])
	popup.close()
	popup.queue_free()
	var shown: ViewerPopup = ViewerPopup.show_scene(host, KIT_STUB_SCENE, ViewerPopup.COMPLETED)
	await host.get_tree().process_frame
	TestFixtures.check(res, "show_scene fits a COMPLETED popup to its content",
		shown != null and shown.is_fitted() and shown.holder.size.is_equal_approx(fit_floor),
		"popup %s holder %s" % [shown, shown.holder.size if shown != null else Vector2.ZERO])
	if shown != null:
		shown.close()
	GuiFrameTests.reset_frames()


#A one node scene whose root asks for h of height, for the fit case.
static func _sized_scene(h: float) -> PackedScene:
	var root := Control.new()
	root.name = "Sized"
	root.custom_minimum_size = Vector2(0.0, h)
	var packed := PackedScene.new()
	packed.pack(root)
	root.queue_free()
	return packed


static func _case_cell_bar_ratio(res: Dictionary, host: Node) -> void:
	var bar: CellBar = (load(CELL_BAR_SCENE) as PackedScene).instantiate()
	host.add_child(bar)
	bar.cells = 20

	var cases: Array[Dictionary] = [
		{"ratio": 0.0, "expect": 0},
		{"ratio": 0.024, "expect": 0},
		{"ratio": 0.5, "expect": 10},
		{"ratio": 0.976, "expect": 20},
		{"ratio": 1.0, "expect": 20},
		{"ratio": 1.5, "expect": 20},
		{"ratio": -0.5, "expect": 0},
	]
	for c: Dictionary in cases:
		bar.set_ratio(c["ratio"])
		TestFixtures.check(res, "set_ratio(%.3f) fills %d of 20 cells" % [c["ratio"], c["expect"]],
			bar.filled == c["expect"], "got %d" % bar.filled)

	bar.set_ratio(0.5)
	TestFixtures.check(res, "ratio reports the filled fraction back",
		is_equal_approx(bar.ratio(), 0.5), "got %.3f" % bar.ratio())

	TestFixtures.check(res, "cells_for rounds a fraction of a total to the nearest cell",
		CellBar.cells_for(0.3, 10) == 3 and CellBar.cells_for(0.97, 10) == 10
			and CellBar.cells_for(-1.0, 10) == 0,
		"0.3/10=%d 0.97/10=%d -1/10=%d" % [CellBar.cells_for(0.3, 10), CellBar.cells_for(0.97, 10),
			CellBar.cells_for(-1.0, 10)])
	bar.queue_free()


static func _case_cell_bar_min_size(res: Dictionary, host: Node) -> void:
	var bar: CellBar = (load(CELL_BAR_SCENE) as PackedScene).instantiate()
	host.add_child(bar)
	bar.cells = 5
	bar.gap = 2
	bar.cell_height = 12
	bar.cell_width = 15
	var expected: Vector2 = Vector2(5.0 * 15.0 + 4.0 * 2.0, 12.0)
	TestFixtures.check(res, "a fixed cell width sets the minimum size to fit every cell and gap",
		bar.custom_minimum_size.is_equal_approx(expected),
		"got %s expected %s" % [bar.custom_minimum_size, expected])
	bar.cell_width = 0
	TestFixtures.check(res, "clearing cell_width falls back to sharing the row width",
		bar.custom_minimum_size.is_equal_approx(Vector2(0.0, 12.0)),
		"got %s" % bar.custom_minimum_size)
	bar.queue_free()


static func _case_notes_label_format(res: Dictionary, _host: Node) -> void:
	TestFixtures.check(res, "grouped(0) has no separator", TransactionData.grouped(0) == "0",
		TransactionData.grouped(0))
	TestFixtures.check(res, "grouped(999) has no separator",
		TransactionData.grouped(999) == "999", TransactionData.grouped(999))
	TestFixtures.check(res, "grouped(1000) gets a thousands separator",
		TransactionData.grouped(1000) == "1,000", TransactionData.grouped(1000))
	TestFixtures.check(res, "grouped(1250000) gets two thousands separators",
		TransactionData.grouped(1250000) == "1,250,000", TransactionData.grouped(1250000))
	TestFixtures.check(res, "grouped keeps the minus sign ahead of the separators",
		TransactionData.grouped(-1250000) == "-1,250,000", TransactionData.grouped(-1250000))


static func _case_notes_label_display(res: Dictionary, host: Node) -> void:
	var label: NotesLabel = (load(NOTES_LABEL_SCENE) as PackedScene).instantiate()
	host.add_child(label)
	await host.get_tree().process_frame

	TestFixtures.check(res, "the value, glyph and suffix rows are vertically centred",
		label.value_label.size_flags_vertical == Control.SIZE_SHRINK_CENTER
			and label.glyph.size_flags_vertical == Control.SIZE_SHRINK_CENTER
			and label.suffix_label.size_flags_vertical == Control.SIZE_SHRINK_CENTER,
		"value %d glyph %d suffix %d" % [label.value_label.size_flags_vertical,
			label.glyph.size_flags_vertical, label.suffix_label.size_flags_vertical])

	label.amount = 500
	label.prefix = "+"
	TestFixtures.check(res, "prefix sits ahead of the formatted amount",
		label.value_text() == "+500", label.value_text())

	label.prefix = ""
	label.suffix = "/mo"
	TestFixtures.check(res, "suffix sits after the glyph in the shown text",
		label.value_text() == "500/mo", label.value_text())

	label.suffix = ""
	label.signed = true
	label.amount = 250
	TestFixtures.check(res, "signed adds a plus sign to a positive amount",
		label.value_text() == "+250", label.value_text())
	label.amount = -250
	TestFixtures.check(res, "signed leaves the minus sign alone on a negative amount",
		label.value_text() == "-250", label.value_text())

	label.signed = false
	label.text_override = "N/A"
	TestFixtures.check(res, "text_override replaces the formatted amount",
		label.value_text() == "N/A", label.value_text())

	label.text_override = ""
	label.show_glyph = false
	TestFixtures.check(res, "show_glyph false hides the glyph node",
		not label.glyph.visible, "visible %s" % label.glyph.visible)
	label.show_glyph = true
	TestFixtures.check(res, "show_glyph true shows the glyph node again",
		label.glyph.visible, "visible %s" % label.glyph.visible)
	label.queue_free()


static func _case_stat_tile(res: Dictionary, host: Node) -> void:
	var tile: StatTile = (load(STAT_TILE_SCENE) as PackedScene).instantiate()
	host.add_child(tile)
	await host.get_tree().process_frame

	var blocker: Node = _find_stopping_mouse(tile)
	TestFixtures.check(res, "no node in the stat tile stops the mouse",
		blocker == null, "blocker %s" % blocker)

	tile.set_stat({"label": "PAYROLL", "amount": 450, "sub": "per week",
		"color": Color("#6cc36a"), "glyph": false})
	TestFixtures.check(res, "set_stat with a full row fills every field",
		tile.label == "PAYROLL" and tile.amount == 450 and tile.sub == "per week"
			and tile.value_color.is_equal_approx(Color("#6cc36a")) and not tile.show_glyph,
		"label %s amount %d sub %s color %s glyph %s" % [tile.label, tile.amount, tile.sub,
			tile.value_color, tile.show_glyph])

	tile.set_stat({"amount": 900})
	TestFixtures.check(res, "set_stat with a partial row only touches the given keys",
		tile.label == "PAYROLL" and tile.amount == 900 and tile.sub == "per week",
		"label %s amount %d sub %s" % [tile.label, tile.amount, tile.sub])

	tile.compact = false
	tile.sub = "per week"
	await host.get_tree().process_frame
	TestFixtures.check(res, "a non compact tile shows its sub row",
		tile.sub_text.visible, "visible %s" % tile.sub_text.visible)
	TestFixtures.check(res, "a non compact tile separates its rows by 6px",
		tile.rows.get_theme_constant("separation") == 6,
		"got %d" % tile.rows.get_theme_constant("separation"))
	tile.compact = true
	await host.get_tree().process_frame
	TestFixtures.check(res, "compact hides the sub row and shrinks the value row",
		not tile.sub_text.visible and tile.value_row.font_size == 13,
		"sub visible %s value font %d" % [tile.sub_text.visible, tile.value_row.font_size])
	TestFixtures.check(res, "a compact tile separates its rows by 4px",
		tile.rows.get_theme_constant("separation") == 4,
		"got %d" % tile.rows.get_theme_constant("separation"))

	tile.value_color = Color("#e8583f")
	await host.get_tree().process_frame
	TestFixtures.check(res, "value_color reaches the NotesLabel value row",
		tile.value_row.value_color.is_equal_approx(Color("#e8583f")),
		"got %s" % tile.value_row.value_color)
	tile.queue_free()


static func is_bevel(node: Variant, kind: StringName, text: String = "") -> bool:
	var bevel: BevelButton = node as BevelButton
	return bevel != null and bevel.kind == kind and (text == "" or bevel.text == text)
