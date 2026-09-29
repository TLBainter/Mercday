class_name GuiFrameTests

#Frames, dialogs and menus: SubWindow, ConfirmDialog, SlotTooltip, SortButton, SortDirToggle,
#FilterSortButton. Run: the headless harness flag gui-frame-tests.

const SUBWINDOW_SCENE := "res://Scenes/GUI/Shared/SubWindow.tscn"
const CONFIRM_SCENE := "res://Scenes/GUI/Shared/ConfirmDialog.tscn"
const SLOT_TOOLTIP_SCENE := "res://Scenes/GUI/Shared/SlotTooltip.tscn"
const SORT_BUTTON_SCENE := "res://Scenes/GUI/Shared/SortButton.tscn"
const SORT_DIR_TOGGLE_SCENE := "res://Scenes/GUI/Shared/SortDirToggle.tscn"
const FILTER_SORT_SCENE := "res://Scenes/GUI/Shared/FilterSortButton.tscn"
const FILTER_BUTTON_SCENE := "res://Scenes/GUI/Shared/FilterButton.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_sub_window(res, host)
	await _case_frame_stack(res, host)
	await _case_frame_stack_freed(res, host)
	await _case_z_ladder(res, host)
	await _case_consume_escape(res, host)
	await _case_modal_fit(res, host)
	await _case_loan_modal_frame(res, host)
	await _case_backdrop(res, host)
	await _case_bottom_band(res, host)
	await _case_viewport_resize(res, host)
	await _case_confirm_dialog(res, host)
	await _case_dialog_severity(res, host)
	await _case_dialog_recap(res, host)
	await _case_slot_tooltip(res, host)
	await _case_sort_button(res, host)
	await _case_sort_dir_toggle(res, host)
	await _case_filter_sort_button(res, host)
	await _case_filter_button(res, host)
	return TestFixtures.summarize(res, "GUI FRAME")


static func _case_sub_window(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var view: Rect2 = host.get_viewport().get_visible_rect()
	TestFixtures.check(res, "the window covers the viewport and stays top level",
		win.top_level and win.size.is_equal_approx(view.size),
		"top_level %s size %s expected %s" % [win.top_level, win.size, view.size])
	var holder: Control = win.holder
	var frame: Control = win.frame
	TestFixtures.check(res, "the holder draws the canvas 1:1",
		holder.scale.is_equal_approx(Vector2.ONE)
			and holder.size.is_equal_approx(Vector2(1280, 720))
			and holder.position.is_equal_approx(Vector2.ZERO),
		"scale %s size %s pos %s" % [holder.scale, holder.size, holder.position])
	var expected_frame_pos: Vector2 = holder.position - Vector2(4, 4)
	var expected_frame_size: Vector2 = holder.size + Vector2(8, 8)
	TestFixtures.check(res, "the frame wraps the holder with a 4px margin",
		frame.position.is_equal_approx(expected_frame_pos)
			and frame.size.is_equal_approx(expected_frame_size),
		"frame %s/%s expected %s/%s" % [frame.position, frame.size, expected_frame_pos,
			expected_frame_size])
	TestFixtures.check(res, "the close X sits inside the frame at top 10 right 10",
		win.close_x.position.is_equal_approx(Vector2(1237, 7))
			and win.close_x.size.is_equal_approx(Vector2(36, 36))
			and win.close_x.icon == CloseX.icon(3) and win.close_x.text == "",
		"pos %s size %s icon %s text %s" % [win.close_x.position, win.close_x.size,
			win.close_x.icon, win.close_x.text])
	GuiFrameStack.bottom_reserve = 76.0
	win._layout()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the band above the bottom bar shortens the window",
		holder.size.is_equal_approx(Vector2(1280, 644))
			and holder.position.is_equal_approx(Vector2.ZERO)
			and win.close_x.position.is_equal_approx(Vector2(1237, 7))
			and frame.size.is_equal_approx(Vector2(1288, 652)),
		"holder %s/%s close %s frame %s" % [holder.size, holder.position,
			win.close_x.position, frame.size])
	win.frame_h = 600.0
	win._layout()
	TestFixtures.check(res, "frame_h pins the height and recentres the window in the band",
		holder.size.is_equal_approx(Vector2(1280, 600))
			and is_equal_approx(holder.position.y, 22.0),
		"holder %s pos %s" % [holder.size, holder.position])
	win.frame_h = 0.0
	GuiFrameStack.bottom_reserve = 0.0
	win._layout()

	var content_root := Control.new()
	content_root.name = "Content"
	var packed := PackedScene.new()
	packed.pack(content_root)
	content_root.queue_free()

	win.open(packed, Callable(), 988.0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a width passed to open narrows the window",
		is_equal_approx(holder.size.x, 988.0) and is_equal_approx(holder.position.x, 146.0)
			and is_equal_approx(win.close_x.position.x, 146.0 + 988.0 - 43.0),
		"size %s pos %s close %s" % [holder.size, holder.position, win.close_x.position])
	win.close()
	win.content_width = 1280.0

	var setup_ran_detached: Array[bool] = [false]
	var setup := func(node: Node) -> void: setup_ran_detached[0] = not node.is_inside_tree()
	var instance: Node = win.open(packed, setup)
	TestFixtures.check(res, "open returns the instance and runs setup before adding it",
		instance != null and setup_ran_detached[0] and win.current() == instance and win.is_open(),
		"instance %s setup_ran %s" % [instance, setup_ran_detached[0]])

	var closed_fired: Array[bool] = [false]
	win.closed.connect(func() -> void: closed_fired[0] = true)
	win.close()
	TestFixtures.check(res, "close frees the content, hides and emits closed",
		closed_fired[0] and win.current() == null and not win.visible,
		"closed %s current %s visible %s" % [closed_fired[0], win.current(), win.visible])

	var nested_root := Control.new()
	var nested_win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	nested_root.add_child(nested_win)
	nested_win.owner = nested_root
	var nested_packed := PackedScene.new()
	nested_packed.pack(nested_root)
	nested_root.queue_free()
	var placed: Node = win.open(nested_packed)
	await host.get_tree().process_frame
	var placed_inner: SubWindow = placed.get_node("SubWindow")
	var inner_scale: Vector2 = placed_inner.get_global_transform().get_scale()
	TestFixtures.check(res, "a nested sub window stays at full screen scale",
		placed_inner.size.is_equal_approx(view.size) and inner_scale.is_equal_approx(Vector2.ONE),
		"size %s scale %s" % [placed_inner.size, inner_scale])

	var kids: Array[Node] = win.get_children()
	TestFixtures.check(res, "a scanline overlay sits after the holder and ignores the mouse",
		win.scanline != null and win.scanline.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and kids.find(win.scanline) > kids.find(win.holder),
		"overlay %s filter %s order %d/%d" % [win.scanline, win.scanline.mouse_filter,
			kids.find(win.scanline), kids.find(win.holder)])

	win.queue_free()


static func _empty_scene() -> PackedScene:
	var root := Control.new()
	root.name = "Content"
	var packed := PackedScene.new()
	packed.pack(root)
	root.queue_free()
	return packed


static func _left_click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _push_escape(host: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	host.get_viewport().push_input(event)


static func _case_frame_stack(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(_empty_scene())
	dlg.ask("Stop?", "Stop the run?")
	TestFixtures.check(res, "the dialog stacks above the open window",
		GuiFrameStack.top() == dlg and GuiFrameStack.depth() == 2,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the first escape closes the dialog and leaves the window open",
		not dlg.visible and win.visible and GuiFrameStack.top() == win,
		"dialog %s window %s top %s" % [dlg.visible, win.visible, GuiFrameStack.top()])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the second escape closes the window and empties the stack",
		not win.visible and GuiFrameStack.depth() == 0,
		"window %s depth %d" % [win.visible, GuiFrameStack.depth()])

	win.open(_empty_scene())
	var inner: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	win.holder.add_child(inner)
	await host.get_tree().process_frame
	inner.open(_empty_scene())
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "escape closes the nested window before the outer one",
		not inner.visible and win.visible and GuiFrameStack.top() == win,
		"inner %s outer %s top %s" % [inner.visible, win.visible, GuiFrameStack.top()])
	win.close()
	dlg.queue_free()
	win.queue_free()


static func _case_frame_stack_freed(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var ghost := Control.new()
	host.add_child(ghost)
	await host.get_tree().process_frame
	GuiFrameStack.push(ghost)
	host.remove_child(ghost)
	ghost.free()
	TestFixtures.check(res, "a freed frame is pruned off the stack",
		GuiFrameStack.top() == null and GuiFrameStack.depth() == 0,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])

	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(_empty_scene())
	var lost := Control.new()
	host.add_child(lost)
	await host.get_tree().process_frame
	GuiFrameStack.push(lost)
	host.remove_child(lost)
	lost.free()
	TestFixtures.check(res, "a freed entry above a live frame does not hide it",
		GuiFrameStack.top() == win and GuiFrameStack.depth() == 1,
		"top %s depth %d" % [GuiFrameStack.top(), GuiFrameStack.depth()])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "escape still closes the live frame under a freed entry",
		not win.visible and GuiFrameStack.depth() == 0,
		"window %s depth %d" % [win.visible, GuiFrameStack.depth()])
	win.queue_free()


static func _case_backdrop(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(_empty_scene())
	var closed_fired: Array[bool] = [false]
	win.closed.connect(func() -> void: closed_fired[0] = true)
	win.backdrop.gui_input.emit(_left_click())
	TestFixtures.check(res, "a backdrop click closes the window",
		closed_fired[0] and not win.visible,
		"closed %s visible %s" % [closed_fired[0], win.visible])
	dlg.ask("Stop?", "Stop the run?")
	dlg.backdrop.gui_input.emit(_left_click())
	TestFixtures.check(res, "the dialog backdrop click is inert", dlg.visible,
		"visible %s" % dlg.visible)
	dlg.press(0)
	dlg.queue_free()
	win.queue_free()


static func _case_bottom_band(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var bar: BottomBar = (load("res://Scenes/GUI/HUD/BottomBar.tscn") as PackedScene).instantiate()
	var reserve: float = bar.custom_minimum_size.y
	bar.queue_free()
	TestFixtures.check(res, "the bottom bar reserves 76 px of the viewport",
		is_equal_approx(reserve, 76.0), "got %.1f" % reserve)
	GuiFrameStack.bottom_reserve = reserve

	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(_empty_scene())
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var win_backdrop_bottom: float = win.backdrop.position.y + win.backdrop.size.y
	var win_scanline_bottom: float = win.scanline.position.y + win.scanline.size.y
	var win_frame_bottom: float = win.frame.position.y + win.frame.size.y
	var win_holder_bottom: float = win.holder.position.y + win.holder.size.y
	TestFixtures.check(res, "the sub window backdrop stops above the bottom bar",
		absf(win_backdrop_bottom - (view.y - reserve)) <= 0.5,
		"backdrop bottom %.1f expected %.1f" % [win_backdrop_bottom, view.y - reserve])
	TestFixtures.check(res, "the scanline stops at the same edge as the backdrop",
		absf(win_scanline_bottom - (view.y - reserve)) <= 0.5,
		"scanline bottom %.1f expected %.1f" % [win_scanline_bottom, view.y - reserve])
	TestFixtures.check(res, "the frame border ends 4 px below the band, by plan",
		win_frame_bottom <= view.y - reserve + SubWindow.BORDER + 0.5,
		"frame bottom %.1f limit %.1f" % [win_frame_bottom,
			view.y - reserve + SubWindow.BORDER])
	TestFixtures.check(res, "the content box stays inside the band above the bar",
		win_holder_bottom <= view.y - reserve + 0.5,
		"content bottom %.1f limit %.1f" % [win_holder_bottom, view.y - reserve])
	TestFixtures.check(res, "the close X stays on screen",
		win.close_x.position.y >= -0.5, "close x top %.1f" % win.close_x.position.y)
	TestFixtures.check(res, "the sub window root ignores the mouse so clicks reach the bar",
		win.mouse_filter == Control.MOUSE_FILTER_IGNORE, "filter %d" % win.mouse_filter)
	var holder_centre_x: float = win.holder.position.x + win.holder.size.x * win.holder.scale.x / 2.0
	TestFixtures.check(res, "the holder stays centred horizontally",
		absf(holder_centre_x - view.x / 2.0) <= 1.0,
		"centre %.1f expected %.1f" % [holder_centre_x, view.x / 2.0])
	win.close()
	win.queue_free()

	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	dlg.ask("Stop?", "Stop the run?")
	var dlg_backdrop_bottom: float = dlg.backdrop.position.y + dlg.backdrop.size.y
	var dlg_box_bottom: float = dlg.box.position.y + dlg.box.size.y
	TestFixtures.check(res, "the confirm dialog backdrop stops above the bottom bar",
		absf(dlg_backdrop_bottom - (view.y - reserve)) <= 0.5,
		"backdrop bottom %.1f expected %.1f" % [dlg_backdrop_bottom, view.y - reserve])
	TestFixtures.check(res, "the confirm dialog box stays inside the band above the bar",
		dlg_box_bottom <= view.y - reserve + 0.5,
		"box bottom %.1f limit %.1f" % [dlg_box_bottom, view.y - reserve])
	var dlg_band: float = GuiFrameStack.band_height(view.y)
	var dlg_expected_top: float = (dlg_band - dlg.box.size.y) / 2.0
	TestFixtures.check(res, "the confirm dialog box centres in the band",
		absf(dlg.box.position.y - dlg_expected_top) <= 1.0,
		"box top %.1f expected %.1f" % [dlg.box.position.y, dlg_expected_top])
	TestFixtures.check(res, "the confirm dialog root ignores the mouse",
		dlg.mouse_filter == Control.MOUSE_FILTER_IGNORE, "filter %d" % dlg.mouse_filter)
	dlg.press(0)
	dlg.queue_free()

	var salary: SalaryDialog = (load("res://Scenes/GUI/Mercs/SalaryDialog.tscn") as PackedScene).instantiate()
	host.add_child(salary)
	await host.get_tree().process_frame
	var probe_view := MercView.new()
	probe_view.uid = 1
	probe_view.name = "Probe"
	probe_view.monthly_salary = 50
	salary.open_for(probe_view)
	var salary_backdrop_bottom: float = salary.backdrop.position.y + salary.backdrop.size.y
	var salary_box_bottom: float = salary.box.position.y + salary.box.size.y
	TestFixtures.check(res, "the salary dialog backdrop stops above the bottom bar",
		absf(salary_backdrop_bottom - (view.y - reserve)) <= 0.5,
		"backdrop bottom %.1f expected %.1f" % [salary_backdrop_bottom, view.y - reserve])
	TestFixtures.check(res, "the salary dialog box stays inside the band above the bar",
		salary_box_bottom <= view.y - reserve + 0.5,
		"box bottom %.1f limit %.1f" % [salary_box_bottom, view.y - reserve])
	TestFixtures.check(res, "the salary dialog root ignores the mouse",
		salary.mouse_filter == Control.MOUSE_FILTER_IGNORE, "filter %d" % salary.mouse_filter)
	salary.queue_free()

	var hud: GameHUD = (load("res://Scenes/GUI/HUD/GameHUD.tscn") as PackedScene).instantiate()
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	await host.get_tree().process_frame
	TestFixtures.check(res, "GameHUD sets the reserve to the bottom bar's height",
		is_equal_approx(GuiFrameStack.bottom_reserve, hud.bottom_bar.custom_minimum_size.y),
		"reserve %.1f bar %.1f" % [GuiFrameStack.bottom_reserve, hud.bottom_bar.custom_minimum_size.y])
	hud.queue_free()

	GuiFrameStack.bottom_reserve = 0.0
	GuiFrameStack.clear()


static func _case_viewport_resize(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(_empty_scene())
	dlg.ask("Stop?", "Stop the run?")
	var view: Viewport = host.get_viewport()
	var win_hooked: bool = view.size_changed.is_connected(Callable(win, "_on_viewport_resized"))
	var dlg_hooked: bool = view.size_changed.is_connected(Callable(dlg, "_on_viewport_resized"))
	TestFixtures.check(res, "the window and the dialog listen for a viewport resize",
		win_hooked and dlg_hooked, "window %s dialog %s" % [win_hooked, dlg_hooked])
	var game_window: Window = host.get_window()
	var old_scale: Vector2i = game_window.content_scale_size
	var rect_before: Vector2 = view.get_visible_rect().size
	var frame_before: Vector2 = win.frame.position
	var box_before: Vector2 = dlg.box.position
	game_window.content_scale_size = Vector2i(1024, 600)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var rect_after: Vector2 = view.get_visible_rect().size
	var moved: bool = not win.frame.position.is_equal_approx(frame_before)
	if not dlg.box.position.is_equal_approx(box_before):
		moved = true
	TestFixtures.check(res, "a resize relayouts the frame and recentres the dialog box",
		moved, "rect %s to %s frame %s to %s box %s to %s" % [rect_before, rect_after,
			frame_before, win.frame.position, box_before, dlg.box.position])
	var moved_box: Vector2 = win.content_size()
	var moved_art: float = float(CloseX.ART * CloseX.SCALE_WINDOW)
	var moved_rim: float = float(CloseX.SCALE_WINDOW)
	var moved_expected: Vector2 = win.holder.position + Vector2(
		moved_box.x - SubWindow.CLOSE_INSET - moved_art - moved_rim,
		SubWindow.CLOSE_INSET - moved_rim)
	TestFixtures.check(res, "the close X follows the content corner after a resize",
		win.close_x.position.distance_to(moved_expected) <= 1.0,
		"position %s expected %s" % [win.close_x.position, moved_expected])
	game_window.content_scale_size = old_scale
	await host.get_tree().process_frame
	dlg.press(0)
	win.close()
	dlg.queue_free()
	win.queue_free()


static func _case_confirm_dialog(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	dlg.ask("Reject?", "Reject this contract?")
	TestFixtures.check(res, "ask shows the pair of buttons",
		dlg.visible and dlg.button_count() == 2,
		"visible %s count %d" % [dlg.visible, dlg.button_count()])
	var labels: Array[String] = dlg.button_labels()
	TestFixtures.check(res, "ask puts the cancel label first and confirms on button 1",
		labels.size() == 2 and labels[0] == "No" and labels[1] == "Yes",
		"labels %s" % str(labels))
	var confirmed: Array[bool] = [false]
	dlg.confirmed.connect(func() -> void: confirmed[0] = true)
	dlg.press(1)
	TestFixtures.check(res, "the confirm button emits confirmed and hides",
		confirmed[0] and not dlg.visible, "confirmed %s visible %s" % [confirmed[0], dlg.visible])

	dlg.ask("Reject?", "Reject this contract?")
	var cancelled: Array[bool] = [false]
	dlg.cancelled.connect(func() -> void: cancelled[0] = true)
	dlg.press(0)
	TestFixtures.check(res, "the cancel button emits cancelled and hides",
		cancelled[0] and not dlg.visible, "cancelled %s visible %s" % [cancelled[0], dlg.visible])

	dlg.ask_buttons("Clear team?", "Remove every merc from the slots.",
		["Cancel", "Keep Leader", "Clear All"])
	TestFixtures.check(res, "ask_buttons builds one button per label",
		dlg.button_count() == 3, "got %d" % dlg.button_count())
	var chosen_index: Array[int] = [-1]
	dlg.chosen.connect(func(i: int) -> void: chosen_index[0] = i)
	dlg.press(2)
	TestFixtures.check(res, "pressing a labeled button emits chosen with its index",
		chosen_index[0] == 2, "got %d" % chosen_index[0])

	dlg.queue_free()


static func _border_text(style: StyleBoxFlat) -> String:
	if style == null:
		return "no style"
	return str(style.border_color)


static func _case_dialog_severity(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	dlg.ask("Reject?", "Reject this contract?")
	var style: StyleBoxFlat = dlg.box.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "the default ask keeps the orange border",
		dlg.severity() == ConfirmDialog.Severity.ORANGE and style != null
			and style.border_color.is_equal_approx(Color("#f28c28")),
		"severity %d colour %s" % [dlg.severity(), _border_text(style)])
	dlg.ask("Dismiss?", "Dismiss this merc?", "Yes", "No", ConfirmDialog.Severity.RED)
	style = dlg.box.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "a red ask paints the box border red",
		dlg.severity() == ConfirmDialog.Severity.RED and style != null
			and style.border_color.is_equal_approx(Color("#e8583f")),
		"severity %d colour %s" % [dlg.severity(), _border_text(style)])
	dlg.ask_buttons("Clear team?", "Remove every merc.", ["Clear All", "Cancel"],
		ConfirmDialog.Severity.INFO)
	style = dlg.box.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "ask_buttons takes a severity and keeps its labels",
		dlg.button_count() == 2 and style != null
			and style.border_color.is_equal_approx(Color("#9cc6ef")),
		"count %d colour %s" % [dlg.button_count(), _border_text(style)])
	await host.get_tree().process_frame
	TestFixtures.check(res, "the dialog box holds the prototype width",
		dlg.box.size.x >= 460.0, "width %.1f" % dlg.box.size.x)
	dlg.press(1)
	dlg.queue_free()


static func _case_dialog_recap(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var team: Array[Dictionary] = [{"name": "Rook", "role": "Leader"},
		{"name": "Wren", "role": "Scout"}]
	var stats: Array[Dictionary] = [{"label": "ODDS", "value": "72%", "color": Color("#6cc36a")},
		{"label": "PAY", "value": "450", "color": Color("#f2d43d")},
		{"label": "DAYS", "value": "6", "color": Color("#9cc6ef")}]
	dlg.ask_recap("Dispatch", "Guard the Caravan", team, stats, ["Go Back", "Dispatch"])
	await host.get_tree().process_frame
	TestFixtures.check(res, "ask_recap builds one node per team row",
		dlg.team_row_count() == 2, "got %d" % dlg.team_row_count())
	TestFixtures.check(res, "ask_recap builds one node per stat row",
		dlg.stat_row_count() == 3, "got %d" % dlg.stat_row_count())
	TestFixtures.check(res, "the first stat value reads back",
		dlg.stat_value_text(0) == "72%", dlg.stat_value_text(0))
	var style: StyleBoxFlat = dlg.box.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "the recap defaults to the green border",
		dlg.severity() == ConfirmDialog.Severity.GREEN and style != null
			and style.border_color.is_equal_approx(Color("#6cc36a")),
		"severity %d colour %s" % [dlg.severity(), _border_text(style)])
	var chosen_index: Array[int] = [-1]
	dlg.chosen.connect(func(i: int) -> void: chosen_index[0] = i)
	dlg.press(1)
	TestFixtures.check(res, "the last recap button is the continue action",
		chosen_index[0] == 1 and not dlg.visible,
		"index %d visible %s" % [chosen_index[0], dlg.visible])
	dlg.ask("Reject?", "Reject this contract?")
	TestFixtures.check(res, "a plain ask frees the recap rows",
		dlg.team_row_count() == 0 and dlg.stat_row_count() == 0,
		"team %d stats %d" % [dlg.team_row_count(), dlg.stat_row_count()])
	dlg.press(0)
	dlg.queue_free()


static func _case_slot_tooltip(res: Dictionary, host: Node) -> void:
	var tip: SlotTooltip = (load(SLOT_TOOLTIP_SCENE) as PackedScene).instantiate()
	host.add_child(tip)
	await host.get_tree().process_frame
	tip.set_slot("weapon", "Sword", "text")
	var kind_text: String = tip.kind_field.text
	var title_text: String = tip.title_label.text
	var body_text: String = tip.body_label.text
	TestFixtures.check(res, "set_slot uppercases the kind and sets the title and body",
		kind_text == "WEAPON" and title_text == "Sword" and body_text == "text",
		"kind %s title %s body %s" % [kind_text, title_text, body_text])

	var anchor := Control.new()
	anchor.position = Vector2(100, 100)
	anchor.size = Vector2(50, 20)
	host.add_child(anchor)
	await host.get_tree().process_frame
	tip.show_at(anchor, Rect2(0, 0, 1280, 720))
	TestFixtures.check(res, "the tooltip opens below the anchor",
		is_equal_approx(tip.global_position.y, 124.0)
			and is_equal_approx(tip.global_position.x, 100.0),
		"got %s" % str(tip.global_position))

	var far_anchor := Control.new()
	far_anchor.position = Vector2(390, 290)
	far_anchor.size = Vector2(20, 20)
	host.add_child(far_anchor)
	await host.get_tree().process_frame
	var bounds := Rect2(0, 0, 400, 300)
	tip.show_at(far_anchor, bounds)
	TestFixtures.check(res, "a bottom right anchor flips above and clamps inside the bounds",
		tip.global_position.y < far_anchor.global_position.y
			and tip.global_position.x >= bounds.position.x
			and tip.global_position.x <= bounds.end.x,
		"got %s" % str(tip.global_position))

	tip.hide_tip()
	TestFixtures.check(res, "hide_tip hides the tooltip", not tip.visible,
		"visible %s" % tip.visible)

	anchor.queue_free()
	far_anchor.queue_free()
	tip.queue_free()


static func _case_sort_button(res: Dictionary, host: Node) -> void:
	var btn: SortButton = (load(SORT_BUTTON_SCENE) as PackedScene).instantiate()
	host.add_child(btn)
	await host.get_tree().process_frame
	btn.options = ["Level", "Guild Opinion"]
	var picked: Array[int] = [-1]
	btn.sort_changed.connect(func(i: int) -> void: picked[0] = i)
	btn.pick(1)
	TestFixtures.check(res, "pick emits sort_changed and the label reads the option upper case",
		picked[0] == 1 and btn.text == "GUILD OPINION",
		"picked %d text %s" % [picked[0], btn.text])
	TestFixtures.check(res, "the sort button wears the drawn lines glyph",
		btn.icon != null and btn.icon.get_size() == Vector2(10, 10),
		"icon %s" % str(btn.icon))
	var rows: Array[Node] = btn.list.get_children()
	var picked_box: StyleBoxFlat = (rows[1] as Button).get_theme_stylebox("normal") as StyleBoxFlat
	var idle_box: StyleBoxFlat = (rows[0] as Button).get_theme_stylebox("normal") as StyleBoxFlat
	TestFixtures.check(res, "the popup fills the picked row orange and the others navy",
		rows.size() == 2 and picked_box.bg_color.is_equal_approx(Color("#f28c28"))
			and idle_box.bg_color.is_equal_approx(Color("#16233f")),
		"rows %d picked %s idle %s" % [rows.size(), picked_box.bg_color, idle_box.bg_color])
	btn.queue_free()


static func _case_sort_dir_toggle(res: Dictionary, host: Node) -> void:
	var toggle_btn: SortDirToggle = (load(SORT_DIR_TOGGLE_SCENE) as PackedScene).instantiate()
	host.add_child(toggle_btn)
	await host.get_tree().process_frame
	var seen: Array[bool] = []
	toggle_btn.direction_changed.connect(func(descending: bool) -> void: seen.append(descending))
	var down: Dictionary = SortDirToggle.LOOKS[true]
	var up: Dictionary = SortDirToggle.LOOKS[false]
	TestFixtures.check(res, "the toggle is a SortDirToggle sized 40 by 26 with no glyph",
		toggle_btn is SortDirToggle and toggle_btn.custom_minimum_size == Vector2(40, 26)
			and toggle_btn.text == "",
		"size %s text '%s'" % [str(toggle_btn.custom_minimum_size), toggle_btn.text])
	TestFixtures.check(res, "the toggle opens descending on the orange fill",
		toggle_btn.descending and toggle_btn.fill_color() == Color("#f28c28")
			and toggle_btn.tooltip_text == "Highest to lowest",
		"descending %s fill %s tip '%s'" % [toggle_btn.descending,
			str(toggle_btn.fill_color()), toggle_btn.tooltip_text])
	toggle_btn.toggle()
	TestFixtures.check(res, "toggle flips to ascending and takes the blue fill",
		seen == [false] and not toggle_btn.descending
			and toggle_btn.fill_color() == Color("#2b4f8a")
			and toggle_btn.tooltip_text == "Lowest to highest",
		"seen %s fill %s" % [str(seen), str(toggle_btn.fill_color())])
	toggle_btn.toggle()
	TestFixtures.check(res, "toggling again returns to descending and the orange fill",
		seen == [false, true] and toggle_btn.descending
			and toggle_btn.fill_color() == Color("#f28c28"),
		"seen %s fill %s" % [str(seen), str(toggle_btn.fill_color())])
	var box: StyleBoxFlat = toggle_btn.get_theme_stylebox("normal") as StyleBoxFlat
	TestFixtures.check(res, "the toggle wears its own box with a 3 px black outline",
		box != null and box.bg_color == Color("#f28c28") and box.border_color == Color("#0a0f1c")
			and box.border_width_left == 3,
		"box %s edge %s" % [str(box.bg_color) if box != null else "none",
			str(box.border_color) if box != null else "none"])
	TestFixtures.check(res, "the lit arrow reads dark while descending and cream while ascending",
		Color(down["lit"]) == Color("#0a0f1c") and Color(up["lit"]) == Color("#f3ead7")
			and Color(down["dim"]) == Color("#7a4a1a") and Color(up["dim"]) == Color("#5e7699"),
		"down %s up %s" % [str(down["lit"]), str(up["lit"])])
	toggle_btn.queue_free()


static func _case_filter_sort_button(res: Dictionary, host: Node) -> void:
	var fsb: FilterSortButton = (load(FILTER_SORT_SCENE) as PackedScene).instantiate()
	host.add_child(fsb)
	await host.get_tree().process_frame
	fsb.sort_options = ["Name", "Level", "Salary"]
	fsb.filter_options = ["All", "Available", "Resting", "On a Contract"]
	var events: Array[Vector2i] = []
	fsb.changed.connect(func(sort: int, filter: int) -> void: events.append(Vector2i(sort, filter)))
	fsb.pick_sort(1)
	fsb.pick_filter(2)
	TestFixtures.check(res, "picking sort then filter emits changed for each",
		events == [Vector2i(1, 0), Vector2i(1, 2)], "got %s" % str(events))
	fsb.set_selection(0, 1)
	TestFixtures.check(res, "set_selection stores the pair without a signal",
		events.size() == 2 and fsb.sort_index == 0 and fsb.filter_index == 1,
		"events %d sort %d filter %d" % [events.size(), fsb.sort_index, fsb.filter_index])
	fsb.queue_free()


static func _case_filter_button(res: Dictionary, host: Node) -> void:
	var btn: FilterButton = (load(FILTER_BUTTON_SCENE) as PackedScene).instantiate()
	host.add_child(btn)
	await host.get_tree().process_frame
	var events: Array[Dictionary] = []
	btn.changed.connect(func(states: Dictionary) -> void: events.append(states))
	var shown: int = 0
	for i: int in btn.labels().size():
		if btn.is_on(i):
			shown += 1
	TestFixtures.check(res, "the filter popup lists nine statuses with five shown",
		btn.labels().size() == 9 and shown == 5 and btn.text == "FILTER",
		"labels %d shown %d text %s" % [btn.labels().size(), shown, btn.text])
	TestFixtures.check(res, "the statuses read in the designer's order",
		btn.labels()[0] == "Available" and btn.labels()[4] == "Pursuing a Loan"
			and btn.labels()[8] == "Captured",
		"labels %s" % str(btn.labels()))
	btn.toggle(5)
	TestFixtures.check(res, "toggling Dead turns it on and reports every state",
		btn.is_on(5) and events.size() == 1 and bool(events[0]["Dead"])
			and events[0].size() == 9,
		"dead %s events %d" % [btn.is_on(5), events.size()])
	btn.reset()
	TestFixtures.check(res, "reset restores the defaults and reports once more",
		not btn.is_on(5) and btn.is_on(0) and events.size() == 2
			and bool(events[1]["Available"]),
		"dead %s events %d" % [btn.is_on(5), events.size()])
	TestFixtures.check(res, "the filter button wears the drawn funnel glyph",
		btn.icon != null and btn.icon.get_size() == Vector2(10, 10),
		"icon %s" % str(btn.icon))
	btn.queue_free()


#The z ladder: every open frame gets its own rung above the HUD popups, capped under MoneyFly.
static func _case_z_ladder(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	TestFixtures.check(res, "the ladder starts at 100, climbs 10 a rung and caps at 190",
		GuiFrameStack.z_for(0) == 100 and GuiFrameStack.z_for(1) == 110
			and GuiFrameStack.z_for(3) == 130 and GuiFrameStack.z_for(9) == 190
			and GuiFrameStack.z_for(40) == 190,
		"0 %d 1 %d 3 %d 9 %d 40 %d" % [GuiFrameStack.z_for(0), GuiFrameStack.z_for(1),
			GuiFrameStack.z_for(3), GuiFrameStack.z_for(9), GuiFrameStack.z_for(40)])
	var frames: Array[Control] = []
	for i: int in 12:
		var rung := Control.new()
		rung.name = "Rung%d" % i
		rung.top_level = true
		host.add_child(rung)
		frames.append(rung)
	await host.get_tree().process_frame
	for rung: Control in frames:
		GuiFrameStack.push(rung)
	TestFixtures.check(res, "three frames pushed in order take 110, 120 and 130",
		frames[0].z_index == 110 and frames[1].z_index == 120 and frames[2].z_index == 130,
		"%d %d %d" % [frames[0].z_index, frames[1].z_index, frames[2].z_index])
	TestFixtures.check(res, "the tenth frame and the ones above it stop at 190",
		frames[8].z_index == 190 and frames[9].z_index == 190 and frames[11].z_index == 190,
		"ninth %d tenth %d twelfth %d" % [frames[8].z_index, frames[9].z_index,
			frames[11].z_index])
	var fly: Control = (load("res://Scenes/GUI/HUD/MoneyFly.tscn") as PackedScene).instantiate()
	TestFixtures.check(res, "MoneyFly at 200 still draws above the capped ladder",
		fly.z_index == 200 and fly.z_index > GuiFrameStack.MAX_Z,
		"fly %d cap %d" % [fly.z_index, GuiFrameStack.MAX_Z])
	TestFixtures.check(res, "a tooltip at 250 draws above MoneyFly and every frame",
		TooltipPanel.TOOLTIP_Z == 250 and TooltipPanel.TOOLTIP_Z > fly.z_index,
		"tooltip %d fly %d" % [TooltipPanel.TOOLTIP_Z, fly.z_index])
	fly.queue_free()
	var plain := Control.new()
	plain.name = "Plain"
	plain.z_index = 5
	host.add_child(plain)
	await host.get_tree().process_frame
	GuiFrameStack.push(plain)
	TestFixtures.check(res, "a frame that is not top level keeps the z of its scene",
		plain.z_index == 5 and GuiFrameStack.top() == plain, "z %d" % plain.z_index)
	plain.queue_free()
	for rung: Control in frames:
		rung.queue_free()
	GuiFrameStack.clear()


#Esc belongs to the top frame alone, and the frame that takes it also swallows the event.
static func _case_consume_escape(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	var lower := Control.new()
	lower.name = "Lower"
	host.add_child(lower)
	var upper := Control.new()
	upper.name = "Upper"
	host.add_child(upper)
	await host.get_tree().process_frame
	GuiFrameStack.push(lower)
	GuiFrameStack.push(upper)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	var idle := InputEventAction.new()
	idle.action = &"ui_accept"
	idle.pressed = false
	host.get_viewport().push_input(idle)
	TestFixtures.check(res, "a frame under the top never takes the escape",
		not GuiFrameStack.consume_escape(lower, esc)
			and not host.get_viewport().is_input_handled(),
		"handled %s" % host.get_viewport().is_input_handled())
	TestFixtures.check(res, "the top frame takes the escape and marks the event handled",
		GuiFrameStack.consume_escape(upper, esc) and host.get_viewport().is_input_handled(),
		"handled %s" % host.get_viewport().is_input_handled())
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	TestFixtures.check(res, "an action that is not the escape is left alone",
		not GuiFrameStack.consume_escape(upper, accept), "ui_accept was taken")
	upper.visible = false
	TestFixtures.check(res, "a hidden frame never takes the escape",
		not GuiFrameStack.consume_escape(upper, esc), "a hidden frame took it")
	TestFixtures.check(res, "a null frame or a null event is answered with false",
		not GuiFrameStack.consume_escape(null, esc)
			and not GuiFrameStack.consume_escape(lower, null), "null was taken")
	lower.queue_free()
	upper.queue_free()
	GuiFrameStack.clear()


#ModalFrame.fit lifts a dialog off the scaled canvas and onto the viewport band.
static func _case_modal_fit(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var frame := Control.new()
	frame.name = "Modal"
	var back := ColorRect.new()
	back.name = "Backdrop"
	frame.add_child(back)
	var box := PanelContainer.new()
	box.name = "Box"
	box.custom_minimum_size = Vector2(300, 200)
	frame.add_child(box)
	host.add_child(frame)
	await host.get_tree().process_frame
	GuiFrameStack.bottom_reserve = 76.0
	ModalFrame.fit(frame, back, box)
	await host.get_tree().process_frame
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	TestFixtures.check(res, "a fitted frame goes top level and covers the viewport",
		frame.top_level and frame.position.is_equal_approx(Vector2.ZERO)
			and frame.size.is_equal_approx(view),
		"top_level %s pos %s size %s view %s" % [frame.top_level, frame.position, frame.size,
			view])
	var back_bottom: float = back.position.y + back.size.y
	TestFixtures.check(res, "the backdrop of a fitted frame stops above the bottom bar",
		absf(back_bottom - (view.y - 76.0)) <= 0.5 and absf(back.size.x - view.x) <= 0.5,
		"bottom %.1f expected %.1f width %.1f" % [back_bottom, view.y - 76.0, back.size.x])
	var band: float = GuiFrameStack.band_height(view.y)
	var want: Vector2 = Vector2((view.x - box.size.x) / 2.0, (band - box.size.y) / 2.0)
	TestFixtures.check(res, "the box of a fitted frame centres in the band above the bar",
		box.position.distance_to(want) <= 1.0, "box %s expected %s" % [box.position, want])
	var before: float = box.position.y
	GuiFrameStack.bottom_reserve = 240.0
	var hook: ModalFrame = ModalFrame.hook_of(frame)
	hook.apply()
	TestFixtures.check(res, "a taller reserve lifts the box and shortens the backdrop",
		box.position.y < before - 1.0
			and absf(back.position.y + back.size.y - (view.y - 240.0)) <= 0.5,
		"box %.1f was %.1f backdrop %.1f" % [box.position.y, before,
			back.position.y + back.size.y])
	TestFixtures.check(res, "the fitted frame listens for a viewport resize",
		host.get_viewport().size_changed.is_connected(Callable(hook, "_on_resized")),
		"the viewport hook is missing")
	GuiFrameStack.bottom_reserve = 76.0
	var game_window: Window = host.get_window()
	var old_scale: Vector2i = game_window.content_scale_size
	game_window.content_scale_size = Vector2i(1024, 600)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var grown: Vector2 = host.get_viewport().get_visible_rect().size
	TestFixtures.check(res, "a resize refits the frame to the new viewport",
		frame.size.is_equal_approx(grown), "frame %s view %s" % [frame.size, grown])
	game_window.content_scale_size = old_scale
	await host.get_tree().process_frame
	frame.queue_free()
	GuiFrameStack.bottom_reserve = 0.0
	GuiFrameStack.clear()


#A Loans window over an open SubWindow: it fits the viewport, takes its own rung and answers Esc
#alone while the frames under it stay open.
static func _case_loan_modal_frame(res: Dictionary, host: Node) -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	var modal := LoanModal.new()
	modal.name = "LoanShell"
	host.add_child(modal)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(_empty_scene())
	modal.open_window()
	await host.get_tree().process_frame
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	TestFixtures.check(res, "a Loans window covers the viewport, not the scaled canvas",
		modal.top_level and modal.size.is_equal_approx(view),
		"top_level %s size %s view %s" % [modal.top_level, modal.size, view])
	TestFixtures.check(res, "a Loans window over an open window draws above the HUD popups",
		GuiFrameStack.top() == modal and modal.z_index > 100 and win.z_index < modal.z_index,
		"top %s modal z %d window z %d" % [GuiFrameStack.top(), modal.z_index, win.z_index])
	var box: PanelContainer = modal.frame_box()
	var band: float = GuiFrameStack.band_height(view.y)
	var centre_x: float = box.global_position.x + box.size.x / 2.0
	var centre_y: float = box.global_position.y + box.size.y / 2.0
	TestFixtures.check(res, "the Loans window centres on the viewport band",
		absf(centre_x - view.x / 2.0) <= 1.0 and absf(centre_y - band / 2.0) <= 1.0,
		"centre %.1f/%.1f expected %.1f/%.1f" % [centre_x, centre_y, view.x / 2.0, band / 2.0])
	modal.set_dimmed(true)
	TestFixtures.check(res, "a Loans window dims while a confirm of its own sits over it",
		modal.dimmed(), "the window did not dim")
	modal.set_dimmed(false)
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	dlg.ask("Stop?", "Stop the run?")
	TestFixtures.check(res, "a confirm over a Loans window takes the rung above it",
		GuiFrameStack.top() == dlg and dlg.z_index > modal.z_index,
		"top %s dialog z %d modal z %d" % [GuiFrameStack.top(), dlg.z_index, modal.z_index])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the first escape closes the confirm alone",
		not dlg.visible and modal.visible and win.visible and GuiFrameStack.top() == modal,
		"dialog %s modal %s window %s" % [dlg.visible, modal.visible, win.visible])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the second escape closes the Loans window alone",
		not modal.visible and not modal.is_open() and win.visible
			and GuiFrameStack.top() == win,
		"modal %s window %s top %s" % [modal.visible, win.visible, GuiFrameStack.top()])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the third escape closes the window under it and empties the stack",
		not win.visible and GuiFrameStack.depth() == 0,
		"window %s depth %d" % [win.visible, GuiFrameStack.depth()])
	dlg.queue_free()
	modal.queue_free()
	win.queue_free()
	GuiFrameStack.clear()
