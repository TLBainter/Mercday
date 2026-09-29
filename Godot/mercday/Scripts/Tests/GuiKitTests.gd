class_name GuiKitTests

#Shared wave 3 atoms: ViewerPopup, CellBar, NotesLabel, StatTile.
#Run with the gui-kit-tests harness flag.

const VIEWER_POPUP_SCENE := "res://Scenes/GUI/Shared/ViewerPopup.tscn"
const KIT_STUB_SCENE := "res://Scenes/GUI/Shared/KitStub.tscn"
const CELL_BAR_SCENE := "res://Scenes/GUI/Shared/CellBar.tscn"
const NOTES_LABEL_SCENE := "res://Scenes/GUI/Shared/NotesLabel.tscn"
const STAT_TILE_SCENE := "res://Scenes/GUI/Shared/StatTile.tscn"
const CONTRACT_VIEWER_SCENE := "res://Scenes/GUI/Contracts/ContractViewer.tscn"
const MERC_VIEWER_SCENE := "res://Scenes/GUI/Mercs/MercViewer.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_viewer_popup_layout(res, host)
	await _case_viewer_popup_lifecycle(res, host)
	await _case_viewer_popup_frame_stack(res, host)
	await _case_viewer_popup_show_scene(res, host)
	await _case_viewer_popup_helpers(res, host)
	_case_cell_bar_ratio(res, host)
	_case_cell_bar_min_size(res, host)
	_case_notes_label_format(res, host)
	await _case_notes_label_display(res, host)
	await _case_stat_tile(res, host)
	return TestFixtures.summarize(res, "GUI KIT")


static func _empty_scene() -> PackedScene:
	var root := Control.new()
	root.name = "Content"
	var packed := PackedScene.new()
	packed.pack(root)
	root.queue_free()
	return packed


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
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
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
	popup.open(_empty_scene())
	var holder: Control = popup.holder
	var frame: Control = popup.frame
	TestFixtures.check(res, "the holder draws the canvas 1:1",
		holder.scale.is_equal_approx(Vector2.ONE)
			and holder.size.is_equal_approx(Vector2(988, 720))
			and holder.position.is_equal_approx(Vector2(146, 0)),
		"scale %s size %s pos %s" % [holder.scale, holder.size, holder.position])
	var expected_frame_pos: Vector2 = holder.position - Vector2(4, 4)
	var expected_frame_size: Vector2 = holder.size + Vector2(8, 8)
	TestFixtures.check(res, "the frame wraps the holder with a 4px margin",
		frame.position.is_equal_approx(expected_frame_pos)
			and frame.size.is_equal_approx(expected_frame_size),
		"frame %s/%s expected %s/%s" % [frame.position, frame.size, expected_frame_pos,
			expected_frame_size])
	TestFixtures.check(res, "the close X sits inside the frame at top 10 right 10",
		popup.close_x.position.is_equal_approx(Vector2(146.0 + 988.0 - 43.0, 7.0))
			and popup.close_x.size.is_equal_approx(Vector2(36, 36))
			and popup.close_x.icon == CloseX.icon(3) and popup.close_x.text == "",
		"pos %s size %s icon %s text %s" % [popup.close_x.position, popup.close_x.size,
			popup.close_x.icon, popup.close_x.text])
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
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var popup: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	host.add_child(popup)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a fresh popup starts closed", not popup.is_open(),
		"is_open %s" % popup.is_open())

	var content_root := Control.new()
	content_root.name = "Content"
	var packed := PackedScene.new()
	packed.pack(content_root)
	content_root.queue_free()

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
	kept.open(_empty_scene())
	kept.close()
	TestFixtures.check(res, "free_on_close false leaves the popup node alive after close",
		is_instance_valid(kept), "valid %s" % is_instance_valid(kept))
	kept.queue_free()

	var freed: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	freed.free_on_close = true
	host.add_child(freed)
	await host.get_tree().process_frame
	freed.open(_empty_scene())
	freed.close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "free_on_close true frees the popup node after close",
		not is_instance_valid(freed), "valid %s" % is_instance_valid(freed))


static func _case_viewer_popup_frame_stack(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var outer: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	host.add_child(outer)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "opening the popup registers it on the frame stack",
		outer.open(_empty_scene()) != null and GuiFrameStack.top() == outer
			and GuiFrameStack.depth() == 1,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])

	var inner: ViewerPopup = (load(VIEWER_POPUP_SCENE) as PackedScene).instantiate()
	outer.holder.add_child(inner)
	await host.get_tree().process_frame
	inner.open(_empty_scene())
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
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
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
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
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
			and invest_content.scene_file_path == "res://Scenes/GUI/Finance/FinanceViewer.tscn"
			and invest_content.invest_only,
		"popup %s content %s" % [invest_popup, invest_content])
	if invest_popup != null:
		invest_popup.close()


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
	TestFixtures.check(res, "format_amount(0) has no separator", NotesLabel.format_amount(0) == "0",
		NotesLabel.format_amount(0))
	TestFixtures.check(res, "format_amount(999) has no separator",
		NotesLabel.format_amount(999) == "999", NotesLabel.format_amount(999))
	TestFixtures.check(res, "format_amount(1000) gets a thousands separator",
		NotesLabel.format_amount(1000) == "1,000", NotesLabel.format_amount(1000))
	TestFixtures.check(res, "format_amount(1250000) gets two thousands separators",
		NotesLabel.format_amount(1250000) == "1,250,000", NotesLabel.format_amount(1250000))
	TestFixtures.check(res, "format_amount keeps the minus sign ahead of the separators",
		NotesLabel.format_amount(-1250000) == "-1,250,000", NotesLabel.format_amount(-1250000))


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
