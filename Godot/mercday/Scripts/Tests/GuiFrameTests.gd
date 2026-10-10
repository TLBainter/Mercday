class_name GuiFrameTests

#Frames, dialogs and menus: SubWindow, ConfirmDialog, SlotTooltip, SortButton, SortDirToggle,
#FilterSortButton. Run: the headless harness flag gui-frame-tests.

const SUBWINDOW_SCENE := "res://Scenes/GUI/Shared/SubWindow.tscn"
const CONFIRM_SCENE := "res://Scenes/GUI/Shared/ConfirmDialog.tscn"
const MODAL_SCENE := "res://Scenes/GUI/Shared/ModalDialog.tscn"
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
	await _case_close_pin(res, host)
	await _case_permit_frame(res, host)
	await _case_upgrade_tier_frame(res, host)
	await _case_salary_frame(res, host)
	await _case_feature_lock_frame(res, host)
	await _case_crew_picker_frame(res, host)
	await _case_coach_frame(res, host)
	await _case_odd_job_frame(res, host)
	await _case_confirm_frame(res, host)
	await _case_plan_switch_frame(res, host)
	return TestFixtures.summarize(res, "GUI FRAME")


static func _case_sub_window(res: Dictionary, host: Node) -> void:
	reset_frames()
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
	check_frame_layout(res, win, Rect2(0.0, 0.0, 1280.0, 720.0))
	GuiFrameStack.bottom_reserve = 76.0
	win._layout()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the band above the bottom bar shortens the window",
		holder.size.is_equal_approx(Vector2(1280, 644))
			and holder.position.is_equal_approx(Vector2.ZERO)
			and win.close_x.position.is_equal_approx(Vector2(1237, 7))
			and frame.size.is_equal_approx(Vector2(1280, 644)),
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

	var packed: PackedScene = empty_scene()

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


static func empty_scene() -> PackedScene:
	var root := Control.new()
	root.name = "Content"
	var packed := PackedScene.new()
	packed.pack(root)
	root.queue_free()
	return packed


static func reset_frames() -> void:
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = 0.0


#The layout contract SubWindow and ViewerPopup share: a 1:1 holder at want, a frame equal to it, the X on its corner.
static func check_frame_layout(res: Dictionary, shell: Node, want: Rect2) -> void:
	var holder: Control = shell.get(&"holder") as Control
	var frame: Control = shell.get(&"frame") as Control
	var close_x: Button = shell.get(&"close_x") as Button
	TestFixtures.check(res, "the holder draws the canvas 1:1",
		holder.scale.is_equal_approx(Vector2.ONE) and holder.size.is_equal_approx(want.size)
			and holder.position.is_equal_approx(want.position),
		"scale %s size %s pos %s" % [holder.scale, holder.size, holder.position])
	TestFixtures.check(res, "the frame rect equals the holder canvas rect",
		frame.position.is_equal_approx(holder.position) and frame.size.is_equal_approx(holder.size),
		"frame %s/%s expected %s/%s" % [frame.position, frame.size, holder.position, holder.size])
	TestFixtures.check(res, "the close X sits inside the frame at top 10 right 10",
		close_x.position.is_equal_approx(Vector2(want.end.x - 43.0, 7.0))
			and close_x.size.is_equal_approx(Vector2(36, 36))
			and close_x.icon == CloseX.icon(3) and close_x.text == "",
		"pos %s size %s icon %s text %s" % [close_x.position, close_x.size, close_x.icon, close_x.text])


static func mount_confirm(host: Node) -> ConfirmDialog:
	reset_frames()
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return dlg


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
	win.open(empty_scene())
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

	win.open(empty_scene())
	var inner: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	win.holder.add_child(inner)
	await host.get_tree().process_frame
	inner.open(empty_scene())
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
	win.open(empty_scene())
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
	win.open(empty_scene())
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
	win.open(empty_scene())
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

	reset_frames()


static func _case_viewport_resize(res: Dictionary, host: Node) -> void:
	reset_frames()
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(empty_scene())
	dlg.ask("Stop?", "Stop the run?")
	var view: Viewport = host.get_viewport()
	var win_hooked: bool = view.size_changed.is_connected(Callable(win, "_on_viewport_resized"))
	var dlg_hooked: bool = view.size_changed.is_connected(Callable(dlg, "_on_viewport_resized"))
	TestFixtures.check(res, "the window and the dialog listen for a viewport resize",
		win_hooked and dlg_hooked, "window %s dialog %s" % [win_hooked, dlg_hooked])
	var rect_before: Vector2 = view.get_visible_rect().size
	var frame_before: Vector2 = win.frame.position
	var box_before: Vector2 = dlg.box.position
	var after_resize := func() -> void:
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
	await _with_view_size(host, Vector2i(1024, 600), after_resize)
	dlg.press(0)
	win.close()
	dlg.queue_free()
	win.queue_free()


static func _case_confirm_dialog(res: Dictionary, host: Node) -> void:
	var dlg: ConfirmDialog = await mount_confirm(host)
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
	var dlg: ConfirmDialog = await mount_confirm(host)
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
	var dlg: ConfirmDialog = await mount_confirm(host)
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
	TestFixtures.check(res, "the toggle paints the orange palette on its bevel while descending",
		toggle_btn.fill == Color("#f28c28") and toggle_btn.hi == Color("#ffb266")
			and toggle_btn.lo == Color("#b85a12") and toggle_btn.text_color == Color("#0a0f1c"),
		"fill %s hi %s lo %s text %s" % [str(toggle_btn.fill), str(toggle_btn.hi), str(toggle_btn.lo),
			str(toggle_btn.text_color)])
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
	reset_frames()
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
	reset_frames()
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
	var refit := func() -> void:
		var grown: Vector2 = host.get_viewport().get_visible_rect().size
		TestFixtures.check(res, "a resize refits the frame to the new viewport",
			frame.size.is_equal_approx(grown), "frame %s view %s" % [frame.size, grown])
	await _with_view_size(host, Vector2i(1024, 600), refit)
	frame.queue_free()
	reset_frames()


#A modal window over an open SubWindow: it fits the viewport, takes its own rung and answers Esc
#alone while the frames under it stay open.
static func _case_loan_modal_frame(res: Dictionary, host: Node) -> void:
	reset_frames()
	var win: SubWindow = (load(SUBWINDOW_SCENE) as PackedScene).instantiate()
	host.add_child(win)
	var modal: ModalDialog = (load(MODAL_SCENE) as PackedScene).instantiate()
	modal.name = "ModalShell"
	host.add_child(modal)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	win.open(empty_scene())
	modal.present()
	await host.get_tree().process_frame
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	TestFixtures.check(res, "a modal window covers the viewport, not the scaled canvas",
		modal.top_level and modal.size.is_equal_approx(view),
		"top_level %s size %s view %s" % [modal.top_level, modal.size, view])
	TestFixtures.check(res, "a modal window over an open window draws above the HUD popups",
		GuiFrameStack.top() == modal and modal.z_index > 100 and win.z_index < modal.z_index,
		"top %s modal z %d window z %d" % [GuiFrameStack.top(), modal.z_index, win.z_index])
	var box: PanelContainer = modal.box
	var band: float = GuiFrameStack.band_height(view.y)
	var centre_x: float = box.global_position.x + box.size.x / 2.0
	var centre_y: float = box.global_position.y + box.size.y / 2.0
	TestFixtures.check(res, "the modal window centres on the viewport band",
		absf(centre_x - view.x / 2.0) <= 1.0 and absf(centre_y - band / 2.0) <= 1.0,
		"centre %.1f/%.1f expected %.1f/%.1f" % [centre_x, centre_y, view.x / 2.0, band / 2.0])
	modal.set_dimmed(true)
	TestFixtures.check(res, "a modal window dims while a confirm of its own sits over it",
		modal.dimmed(), "the window did not dim")
	modal.set_dimmed(false)
	var dlg: ConfirmDialog = (load(CONFIRM_SCENE) as PackedScene).instantiate()
	host.add_child(dlg)
	await host.get_tree().process_frame
	dlg.ask("Stop?", "Stop the run?")
	TestFixtures.check(res, "a confirm over a modal window takes the rung above it",
		GuiFrameStack.top() == dlg and dlg.z_index > modal.z_index,
		"top %s dialog z %d modal z %d" % [GuiFrameStack.top(), dlg.z_index, modal.z_index])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the first escape closes the confirm alone",
		not dlg.visible and modal.visible and win.visible and GuiFrameStack.top() == modal,
		"dialog %s modal %s window %s" % [dlg.visible, modal.visible, win.visible])
	_push_escape(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the second escape closes the modal window alone",
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

const BAR_RESERVE: float = 76.0
#The X of a dialog sits no further than CORNER_PX in from the top right corner of its box.
const CORNER_PX: float = 12.0
const PERMIT_SCENE := "res://Scenes/GUI/Legal/PermitRequestDialog.tscn"
const TIER_SCENE := "res://Scenes/GUI/Subscription/UpgradeTierDialog.tscn"
const SALARY_SCENE := "res://Scenes/GUI/Mercs/SalaryDialog.tscn"
const BENEFIT_SCENE := "res://Scenes/GUI/Finance/Payroll/BenefitDialog.tscn"
const VACATION_SCENE := "res://Scenes/GUI/Finance/Payroll/VacationDialog.tscn"
const LOCK_SCENE := "res://Scenes/GUI/Shared/FeatureLockDialog.tscn"
const CREW_PICKER_SCENE := "res://Scenes/GUI/Shared/MercPicker.tscn"
const COACH_SCENE := "res://Scenes/GUI/Mercs/CoachDialog.tscn"
const ODD_JOB_SCENE := "res://Scenes/GUI/Shared/OddJobWindow.tscn"
const PLAN_SWITCH_SCENE := "res://Scenes/GUI/Subscription/PlanSwitchDialog.tscn"
#A window short enough that the plan switch box has to give up part of its set height.
const SHORT_VIEW: Vector2i = Vector2i(1280, 560)


static func _band(host: Node) -> Rect2:
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	return Rect2(Vector2.ZERO, Vector2(view.x, GuiFrameStack.band_height(view.y)))


static func _settle(host: Node) -> void:
	await host.get_tree().process_frame
	await host.get_tree().process_frame


#The first frame fault of one dialog box, or "" when the box is sound: in the band, no scroll
#around it, every shown child inside it, and the X (when closer is set) on its top right corner.
static func _frame_miss(box: Control, closer: Button, band: Rect2) -> String:
	var rect: Rect2 = box.get_global_rect()
	if not band.grow(0.5).encloses(rect):
		return "box %s outside band %s" % [str(rect), str(band)]
	var up: Node = box.get_parent()
	while up != null:
		if up is ScrollContainer:
			return "the whole box scrolls inside %s" % up.name
		up = up.get_parent()
	var out: String = _outside(box, box, rect.grow(0.5))
	if out != "":
		return out
	if closer == null:
		return ""
	if not box.is_ancestor_of(closer):
		return "the X %s is not inside the box" % closer.name
	if not closer.is_visible_in_tree():
		return "the X is hidden"
	var x_rect: Rect2 = closer.get_global_rect()
	var gap_x: float = rect.end.x - x_rect.end.x
	var gap_y: float = x_rect.position.y - rect.position.y
	if gap_x < -0.5 or gap_y < -0.5 or gap_x > CORNER_PX or gap_y > CORNER_PX:
		return "the X %s is %.1f/%.1f px off the corner of %s" % [str(x_rect), gap_x, gap_y, str(rect)]
	return ""


#A scroll or clipping child may hold more than it shows, so the walk stops at its own rect.
static func _outside(box: Control, node: Node, rect: Rect2) -> String:
	for kid: Node in node.get_children():
		var part: Control = kid as Control
		if part == null or not part.visible or part.top_level:
			continue
		if not rect.encloses(part.get_global_rect()):
			return "%s %s outside the box %s" % [str(box.get_path_to(part)), str(part.get_global_rect()),
				str(rect)]
		if part is ScrollContainer or part.clip_contents:
			continue
		var deeper: String = _outside(box, part, rect)
		if deeper != "":
			return deeper
	return ""


static func _spawn(host: Node, path: String) -> Control:
	var made: Control = (load(path) as PackedScene).instantiate() as Control
	host.add_child(made)
	await host.get_tree().process_frame
	return made


static func _drop(made: Node, was: float) -> void:
	made.queue_free()
	GuiFrameStack.clear()
	GuiFrameStack.bottom_reserve = was


#Runs body, awaited, after the window content scale changes to size and settles, then restores the scale.
static func _with_view_size(host: Node, size: Vector2i, body: Callable) -> void:
	var game_window: Window = host.get_window()
	var old_scale: Vector2i = game_window.content_scale_size
	game_window.content_scale_size = size
	await _settle(host)
	await body.call()
	game_window.content_scale_size = old_scale
	await host.get_tree().process_frame


static func _cancel(dlg: Control) -> void:
	dlg.call(&"press_cancel")


#Opens one dialog inside the band and checks its box fits, with its X on the corner when with_x is set.
static func _check_fits(res: Dictionary, host: Node, label: String, path: String, open: Callable,
		shut: Callable = Callable(), with_x: bool = true, ready: bool = true) -> void:
	var was: float = GuiFrameStack.bottom_reserve
	GuiFrameStack.bottom_reserve = BAR_RESERVE
	var dlg: Control = await _spawn(host, path)
	open.call(dlg)
	await _settle(host)
	var closer: Button = (dlg.get(&"close_button") as Button) if with_x else null
	var miss: String = _frame_miss(dlg.get(&"box") as Control, closer, _band(host))
	TestFixtures.check(res, label, ready and dlg.visible and miss == "", miss)
	if shut.is_valid():
		shut.call(dlg)
	_drop(dlg, was)


#CloseX.pin puts the X on the outer top right corner of a box and keeps it there.
static func _case_close_pin(res: Dictionary, host: Node) -> void:
	var holder := Control.new()
	host.add_child(holder)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override(&"panel", style)
	var body := Label.new()
	body.text = "Body"
	panel.add_child(body)
	holder.add_child(panel)
	panel.position = Vector2(100.0, 50.0)
	panel.size = Vector2(300.0, 200.0)
	var shut: Button = CloseX.make(CloseX.SCALE_WINDOW)
	holder.add_child(shut)
	CloseX.pin(shut, panel, CloseX.SCALE_WINDOW, 7.0)
	await _settle(host)
	var got: Rect2 = shut.get_global_rect()
	var want: Rect2 = Rect2(Vector2(100.0 + 300.0 - 7.0 - 36.0, 50.0 + 7.0), Vector2(36.0, 36.0))
	TestFixtures.check(res, "a pinned X sits inset px in from the outer top right corner of its box",
		panel.is_ancestor_of(shut) and got.position.distance_to(want.position) <= 0.5
			and got.size.is_equal_approx(want.size)
			and panel.get_child(panel.get_child_count() - 1).name == CloseX.OVERLAY,
		"x %s expected %s" % [str(got), str(want)])
	panel.size = Vector2(420.0, 260.0)
	panel.position = Vector2(20.0, 30.0)
	await _settle(host)
	got = shut.get_global_rect()
	want.position = Vector2(20.0 + 420.0 - 7.0 - 36.0, 30.0 + 7.0)
	TestFixtures.check(res, "a pinned X follows its box when the box moves and grows",
		got.position.distance_to(want.position) <= 0.5, "x %s expected %s" % [str(got), str(want)])
	holder.queue_free()


#The Legal > Permits > Request X sits on the corner of the dialog box.
static func _case_permit_frame(res: Dictionary, host: Node) -> void:
	GameState.start_new_game()
	await _check_fits(res, host, "the permit request box sits in the band with its X on the corner",
		PERMIT_SCENE, func(dlg: Control) -> void: (dlg as PermitRequestDialog).open(1))


#Every upgrade opens a whole 400x400 popover in the band, with an X.
static func _case_upgrade_tier_frame(res: Dictionary, host: Node) -> void:
	var was: float = GuiFrameStack.bottom_reserve
	GuiFrameStack.bottom_reserve = BAR_RESERVE
	GameState.start_new_game()
	var dlg: UpgradeTierDialog = await _spawn(host, TIER_SCENE) as UpgradeTierDialog
	var band: Rect2 = _band(host)
	var miss: String = ""
	var spots: Array[Vector2] = [Vector2(100.0, 100.0), Vector2(1100.0, 500.0), Vector2(-50.0, -50.0),
		Vector2(900.0, 640.0)]
	for id: String in UpgradeDefs.ORDER:
		for at: Vector2 in spots:
			dlg.open_for(id, at)
			await _settle(host)
			var why: String = ""
			if not dlg.size.is_equal_approx(UpgradeTierDialog.BOX):
				why = "size %s" % str(dlg.size)
			if why == "":
				why = _frame_miss(dlg, dlg.close_button(), band)
			if why != "" and miss == "":
				miss = "%s at %s: %s" % [id, str(at), why]
			dlg.close()
		if miss != "":
			break
	TestFixtures.check(res, "every upgrade popover stays 400x400 inside the band with the X shown",
		miss == "", miss)
	dlg.open_for("seats", Vector2(100.0, 100.0))
	await _settle(host)
	dlg.close_button().pressed.emit()
	TestFixtures.check(res, "the popover X closes it",
		not dlg.visible and GuiFrameStack.top() != dlg, "visible %s" % dlg.visible)
	_drop(dlg, was)


#The wage, bonus and holiday dialogs hold their steppers and X.
static func _case_salary_frame(res: Dictionary, host: Node) -> void:
	GameState.start_new_game()
	var notes: int = GameState.bank_notes
	GameState.bank_notes = 99999999
	var open_salary := func(dlg: Control) -> void:
		var probe_view := MercView.new()
		probe_view.uid = 1
		probe_view.name = "Probe"
		probe_view.monthly_salary = 99999999
		(dlg as SalaryDialog).open_for(probe_view)
		(dlg as SalaryDialog).step(3)
	await _check_fits(res, host, "the salary box holds its stepper and X at the largest wage",
		SALARY_SCENE, open_salary, _cancel)
	GameState.bank_notes = notes
	var open_bonus := func(dlg: Control) -> void:
		var bonus: BenefitDialog = dlg as BenefitDialog
		bonus.open_for("profit")
		bonus.stepper().set_value_silent(bonus.stepper().max_value)
	await _check_fits(res, host, "the benefit box holds its stepper and X", BENEFIT_SCENE, open_bonus, _cancel)
	await _check_fits(res, host, "the vacation box holds its five steppers and X", VACATION_SCENE,
		func(dlg: Control) -> void: (dlg as VacationDialog).open(), _cancel)


#The feature lock X is part of its box.
static func _case_feature_lock_frame(res: Dictionary, host: Node) -> void:
	var open_lock := func(dlg: Control) -> void:
		(dlg as FeatureLockDialog).open({"feature": "Customize", "upgrade": "Seats", "upgrade_id": "seats",
			"tier": 2, "tiers": 4})
	await _check_fits(res, host, "the feature lock box sits in the band with its X on the corner",
		LOCK_SCENE, open_lock)


#The merc picker X is part of its box.
static func _case_crew_picker_frame(res: Dictionary, host: Node) -> void:
	await _check_fits(res, host, "the merc picker box sits in the band with its X on the corner",
		CREW_PICKER_SCENE, func(dlg: Control) -> void: (dlg as MercPicker).open_for(1, [], false))


#The coach dialog X is part of its box.
static func _case_coach_frame(res: Dictionary, host: Node) -> void:
	GameState.start_new_game()
	var first: MercView = GameState.roster[0] if not GameState.roster.is_empty() else null
	await _check_fits(res, host, "the coach box sits in the band with its X on the corner", COACH_SCENE,
		func(dlg: Control) -> void: (dlg as CoachDialog).open_for(first), Callable(), true, first != null)


#The odd job window box sits in the band and holds its crew row.
static func _case_odd_job_frame(res: Dictionary, host: Node) -> void:
	var odds_fn := func(team: Array[int]) -> int:
		return 0 if team.is_empty() else 50
	var open_window := func(dlg: Control) -> void:
		(dlg as OddJobWindow).open({
			"title": "Renegotiate the Fine",
			"facts": [{"label": "Fine", "value": "500"}, {"label": "Days Left", "value": "3"}],
			"max_mercs": 3,
			"candidates": [{"id": 401, "name": "Ash", "fit": 4.0}, {"id": 402, "name": "Bell", "fit": 3.0}],
			"default_pay": 40,
			"money": 1000,
			"odds": odds_fn,
			"send_label": "Send",
		})
	await _check_fits(res, host, "the odd job box sits in the band and holds its rows", ODD_JOB_SCENE,
		open_window, _cancel, false)


#A confirm with a long message still fits the band.
static func _case_confirm_frame(res: Dictionary, host: Node) -> void:
	var ask_long := func(dlg: Control) -> void:
		(dlg as ConfirmDialog).ask("Stop the run?", "Stopping now ends the contract early. ".repeat(12))
	await _check_fits(res, host, "a long confirm box sits in the band and holds its text", CONFIRM_SCENE,
		ask_long, func(dlg: Control) -> void: (dlg as ConfirmDialog).press(0), false)


#The height the plan switch box takes while its upgrade list shows: the set height held to the band less the gap.
static func _plan_box_h(host: Node) -> float:
	return minf(PlanSwitchDialog.BOX_H, _band(host).size.y - PlanSwitchDialog.BAND_GAP)


#The plan switch box keeps to the band whatever it lists, in a tall window and in a short one.
static func _case_plan_switch_frame(res: Dictionary, host: Node) -> void:
	GameState.start_new_game()
	var board: Array[ContractView] = GameState.contracts.duplicate()
	var saved: ContractBoard = GameState.board
	GuiSubsTests._set_live_board(GuiSubsTests.FULL_BOARD)
	SubscriptionManager.max_out()
	var cards: Array[int] = []
	var heads: Array[String] = []
	var to_free := func(dlg: Control) -> void:
		(dlg as PlanSwitchDialog).open_for(SubscriptionManager.Plan.FREE)
	var to_pro := func(dlg: Control) -> void:
		(dlg as PlanSwitchDialog).open_for(SubscriptionManager.Plan.PRO)
	var count_cards := func(dlg: Control) -> void:
		cards.append((dlg as PlanSwitchDialog).module_count())
		heads.append_array((dlg as PlanSwitchDialog).sections())
	await _check_fits(res, host, "the plan switch box holds its heads and the whole upgrade list in the band",
		PLAN_SWITCH_SCENE, to_free, count_cards, false)
	var free_cap: int = UpgradeDefs.plan_max_contracts(SubscriptionManager.Plan.FREE, 0)
	var lead: String = "%d postings are over the Free cap of %d" % [GuiSubsTests.FULL_BOARD - free_cap, free_cap]
	TestFixtures.check(res, "the box under test shows the Free head for the postings over the cap",
		not heads.is_empty() and heads[0].begins_with(lead), "heads %s" % [heads])
	TestFixtures.check(res, "the box under test lists every upgrade of the table",
		cards == [UpgradeDefs.ORDER.size()], "cards %s" % [cards])
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	await _check_fits(res, host, "the plan switch box sits in the band for an upgrade", PLAN_SWITCH_SCENE,
		to_pro, Callable(), false)
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await _check_fits(res, host, "the plan switch box sits in the band for a downgrade from Pro",
		PLAN_SWITCH_SCENE, to_free, Callable(), false)
	SubscriptionManager.max_out()
	var was: float = GuiFrameStack.bottom_reserve
	GuiFrameStack.bottom_reserve = BAR_RESERVE
	var live: PlanSwitchDialog = await _spawn(host, PLAN_SWITCH_SCENE) as PlanSwitchDialog
	to_free.call(live)
	await _settle(host)
	var tall_h: float = live.box.size.y
	var seen: Dictionary = {}
	var shrink := func() -> void:
		seen["want"] = _plan_box_h(host)
		seen["box"] = live.box.size.y
		seen["miss"] = _frame_miss(live.box, null, _band(host))
	await _with_view_size(host, SHORT_VIEW, shrink)
	await _settle(host)
	var back_h: float = live.box.size.y
	_drop(live, was)
	var short_want: float = float(seen.get("want", 0.0))
	TestFixtures.check(res, "the plan switch box takes its set height in the normal window",
		is_equal_approx(tall_h, PlanSwitchDialog.BOX_H), "box %f set %f" % [tall_h, PlanSwitchDialog.BOX_H])
	TestFixtures.check(res, "the short window leaves the box less than its set height to take",
		short_want > 0.0 and short_want < PlanSwitchDialog.BOX_H,
		"cap %f set %f" % [short_want, PlanSwitchDialog.BOX_H])
	TestFixtures.check(res, "a short window shortens the plan switch box to the band less its gap",
		is_equal_approx(float(seen.get("box", 0.0)), short_want) and String(seen.get("miss", "unread")) == "",
		"box %s cap %f miss %s" % [seen.get("box"), short_want, seen.get("miss")])
	TestFixtures.check(res, "the plan switch box takes its set height again when the window grows back",
		is_equal_approx(back_h, PlanSwitchDialog.BOX_H), "box %f set %f" % [back_h, PlanSwitchDialog.BOX_H])
	var fresh := func() -> void:
		await _check_fits(res, host, "a plan switch box opened in a short window sits in the band",
			PLAN_SWITCH_SCENE, to_free, Callable(), false)
	await _with_view_size(host, SHORT_VIEW, fresh)
	GameState.contracts = board
	GameState.board = saved
	SubscriptionManager.max_out()
