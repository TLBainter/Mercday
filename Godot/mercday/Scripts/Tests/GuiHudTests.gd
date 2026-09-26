class_name GuiHudTests
extends RefCounted

#Suite for the Game HUD (menu grid, settings, bottom bar, money and time menus). Flag --gui-hud-tests.

const HUD_SCENE := "res://Scenes/GUI/HUD/GameHUD.tscn"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_layout(res, host)
	await _case_money(res, host)
	await _case_time(res, host)
	await _case_menus(res, host)
	await _case_harness(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "GUI HUD")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _spawn(host: Node) -> GameHUD:
	var scene: PackedScene = load(HUD_SCENE)
	var hud: GameHUD = scene.instantiate()
	hud.autostart = false
	host.add_child(hud)
	hud.wire_for_test()
	return hud


static func _case_layout(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var all_present := true
	for i in 9:
		if hud.button(i) == null:
			all_present = false
	TestFixtures.check(res, "hud layout buttons present", all_present, "9 grid buttons")
	TestFixtures.check(res, "hud layout merc label", hud.button(0).label == "Merc Viewer", hud.button(0).label)
	TestFixtures.check(res, "hud layout contract label", hud.button(1).label == "Contract Viewer", hud.button(1).label)
	TestFixtures.check(res, "hud layout metrics label", hud.button(2).label == "Metrics Viewer", hud.button(2).label)
	var blanks_ok := true
	for i in range(3, 9):
		var btn := hud.button(i)
		if not btn.disabled or btn.label != "":
			blanks_ok = false
	TestFixtures.check(res, "hud layout blank buttons disabled", blanks_ok, "buttons 3..8")
	TestFixtures.check(res, "hud layout settings button", hud.settings_button != null, "settings button")
	TestFixtures.check(res, "hud layout bottom bar height", hud.bottom_bar.custom_minimum_size.y == 76.0,
		str(hud.bottom_bar.custom_minimum_size.y))
	var root_children: Array[Node] = hud.root.get_children()
	var overlay: ScanlineOverlay = null
	for child: Node in root_children:
		if child is ScanlineOverlay:
			overlay = child
			break
	var overlay_index: int = root_children.find(overlay)
	var bottom_index: int = root_children.find(hud.bottom_bar)
	var popup_index: int = root_children.find(hud.popup())
	TestFixtures.check(res, "hud scanline overlay sits between the bottom bar and the popup",
		overlay != null and overlay.visible
			and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and overlay.size.is_equal_approx(hud.root.size)
			and overlay_index > bottom_index and overlay_index < popup_index,
		"overlay %s index %d bottom %d popup %d size %s root %s" % [overlay, overlay_index,
			bottom_index, popup_index, str(overlay.size) if overlay != null else "none", hud.root.size])
	var bar: BottomBar = hud.bottom_bar
	var inset: PanelContainer = bar.inset()
	var inset_style: StyleBoxFlat = null
	if inset != null:
		inset_style = inset.get_theme_stylebox(&"panel") as StyleBoxFlat
	TestFixtures.check(res, "hud bottom bar inset row fill and frame",
		inset_style != null and inset_style.bg_color.is_equal_approx(Color("#0e1628"))
			and inset_style.border_width_top == 3
			and inset_style.border_color.is_equal_approx(Color("#0a0f1c")),
		"inset %s" % inset)
	var lines: Array[ColorRect] = bar.dividers()
	var lines_ok: bool = lines.size() == 2
	for line: ColorRect in lines:
		if not line.custom_minimum_size.is_equal_approx(Vector2(4, 24)):
			lines_ok = false
		if not line.color.is_equal_approx(Color("#2b4f8a")):
			lines_ok = false
	TestFixtures.check(res, "hud bottom bar carries two 4x24 dividers", lines_ok,
		"%d dividers" % lines.size())
	await host.get_tree().process_frame
	var tm: TimeMenu = bar.time_menu()
	var clock_div: ColorRect = tm.clock_divider()
	TestFixtures.check(res, "hud clock divider is a 4x24 #2b4f8a line",
		clock_div != null and clock_div.custom_minimum_size.is_equal_approx(Vector2(4, 24))
			and clock_div.color.is_equal_approx(Color("#2b4f8a")),
		"clock_div %s" % clock_div)
	var date_rect: Rect2 = tm.date_label().get_global_rect()
	var clock_div_rect: Rect2 = clock_div.get_global_rect()
	var time_rect: Rect2 = tm.time_label().get_global_rect()
	var main_div: ColorRect = tm.get_node("Divider") as ColorRect
	var main_div_rect: Rect2 = main_div.get_global_rect()
	var speed_rect: Rect2 = tm.speed_row.get_global_rect()
	TestFixtures.check(res, "hud clock row reads date, divider, time, divider, speed buttons left to right",
		date_rect.end.x <= clock_div_rect.position.x and clock_div_rect.end.x <= time_rect.position.x
			and time_rect.end.x <= main_div_rect.position.x and main_div_rect.end.x <= speed_rect.position.x,
		"date %s clock_div %s time %s div %s speed %s" % [date_rect, clock_div_rect, time_rect,
			main_div_rect, speed_rect])
	TestFixtures.check(res, "hud date and time share the TitleLabel size",
		tm.date_label().theme_type_variation == &"TitleLabel"
			and tm.time_label().theme_type_variation == &"TitleLabel"
			and tm.date_label().vertical_alignment == VERTICAL_ALIGNMENT_CENTER
			and tm.time_label().vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
		"date variation %s time variation %s" % [tm.date_label().theme_type_variation,
			tm.time_label().theme_type_variation])
	var inset_rect: Rect2 = inset.get_global_rect()
	var inset_mid: float = inset_rect.position.y + inset_rect.size.y * 0.5
	var row_mid_ok := true
	for r: Rect2 in [date_rect, clock_div_rect, time_rect, speed_rect]:
		var mid: float = r.position.y + r.size.y * 0.5
		if absf(mid - inset_mid) > 1.0:
			row_mid_ok = false
	TestFixtures.check(res, "hud clock row centres vertically", row_mid_ok,
		"inset_mid %.2f" % inset_mid)
	var tm_rect: Rect2 = tm.get_global_rect()
	TestFixtures.check(res, "hud time menu sits at the right edge of the inset",
		absf(tm_rect.end.x - inset_rect.end.x) <= 9.0 and inset_rect.encloses(tm_rect),
		"time_menu %s inset %s" % [tm_rect, inset_rect])
	var grid_btn: GridMenuButton = hud.button(0)
	var grid_icon: IconRect = grid_btn.icon_rect
	var grid_icon_rect: Rect2 = grid_icon.get_global_rect()
	var grid_btn_rect: Rect2 = grid_btn.get_global_rect()
	TestFixtures.check(res, "hud grid icon is centred and 4x",
		grid_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and grid_icon.custom_minimum_size == Vector2(64, 64)
			and grid_icon.size == Vector2(64, 64)
			and absf(grid_icon_rect.get_center().x - grid_btn_rect.get_center().x) <= 1.0,
		"stretch %d min %s size %s icon_center %.2f btn_center %.2f" % [grid_icon.stretch_mode,
			grid_icon.custom_minimum_size, grid_icon.size, grid_icon_rect.get_center().x,
			grid_btn_rect.get_center().x])
	var gear_icon: IconRect = hud.settings_button.icon_rect
	TestFixtures.check(res, "hud settings gear centres its icon",
		gear_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and gear_icon.custom_minimum_size == Vector2(48, 48),
		"stretch %d min %s" % [gear_icon.stretch_mode, gear_icon.custom_minimum_size])
	var win: Window = host.get_window()
	var scale_mode: int = win.content_scale_mode
	var scale_aspect: int = win.content_scale_aspect
	var stretch_setting: Variant = ProjectSettings.get_setting("display/window/stretch/mode")
	TestFixtures.check(res, "hud window scales canvas items and keeps the aspect",
		scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			and scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP
			and stretch_setting == "canvas_items",
		"scale_mode %d scale_aspect %d stretch_setting %s" % [scale_mode, scale_aspect, stretch_setting])
	TestFixtures.check(res, "hud bottom bar menus stay reachable",
		bar.money_menu() != null and bar.time_menu() != null,
		"money %s time %s" % [bar.money_menu(), bar.time_menu()])
	hud.queue_free()


static func _case_money(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var money := hud.bottom_bar.money_menu()
	TestFixtures.check(res, "hud money start text", money.text().contains("100"), money.text())
	GameState.bank_notes = 90
	GameState.money_changed.emit(90)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud money updated text", money.text().contains("90"), money.text())
	var expected_expenses := "- %d expenses" % GameState.month_expenses()
	TestFixtures.check(res, "hud money expenses line", money.expenses_text() == expected_expenses, money.expenses_text())
	hud.queue_free()


static func _case_time(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var time_menu := hud.bottom_bar.time_menu()
	var expected_date := TrynnCalendar.date_text(CampaignClock.now())
	TestFixtures.check(res, "hud time date label", time_menu.date_label().text == expected_date, time_menu.date_label().text)
	var pause_btn := time_menu.speed_button(ClockRunner.Speed.PAUSE)
	var play_btn := time_menu.speed_button(ClockRunner.Speed.PLAY)
	TestFixtures.check(res, "hud time pause pressed", pause_btn.button_pressed, "pause pressed")
	TestFixtures.check(res, "hud time play not pressed", not play_btn.button_pressed, "play not pressed")
	play_btn.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud time play speed set", GameState.clock.speed == ClockRunner.Speed.PLAY, str(GameState.clock.speed))
	TestFixtures.check(res, "hud time play pressed after click", play_btn.button_pressed, "play pressed")
	var first_group: ButtonGroup = time_menu.speed_button(0).button_group
	var groups_ok: bool = first_group != null
	for m in range(5):
		if time_menu.speed_button(m).button_group != first_group:
			groups_ok = false
	TestFixtures.check(res, "hud speed buttons share one ButtonGroup", groups_ok,
		"first_group %s" % first_group)
	var fast_btn := time_menu.speed_button(ClockRunner.Speed.FAST)
	fast_btn.button_pressed = true
	fast_btn.pressed.emit()
	await host.get_tree().process_frame
	var fast_pressed_count := 0
	for m in range(5):
		if time_menu.speed_button(m).button_pressed:
			fast_pressed_count += 1
	TestFixtures.check(res, "hud fast click presses only fast in the shared group",
		GameState.clock.speed == ClockRunner.Speed.FAST and fast_btn.button_pressed
			and not play_btn.button_pressed and not pause_btn.button_pressed
			and fast_pressed_count == 1 and fast_btn.button_group.get_pressed_button() == fast_btn,
		"speed %s pressed_count %d" % [str(GameState.clock.speed), fast_pressed_count])
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	await host.get_tree().process_frame
	var pause_pressed_count := 0
	for m in range(5):
		if time_menu.speed_button(m).button_pressed:
			pause_pressed_count += 1
	TestFixtures.check(res, "hud pause resync presses only pause in the shared group",
		pause_pressed_count == 1 and pause_btn.button_pressed, "pause_pressed_count %d" % pause_pressed_count)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	hud.queue_free()


static func _case_menus(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	hud.open_menu(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud menu opens placeholder", hud.popup().is_open(), "popup open")
	hud.popup().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud menu closes", not hud.popup().is_open(), "popup closed")
	hud.open_menu(3)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud disabled menu no-op", not hud.popup().is_open(), "popup stays closed")
	hud.queue_free()


static func _case_harness(res: Dictionary, host: Node) -> void:
	_fresh()
	var roster_events: Array[int] = [0]
	var counter := func() -> void: roster_events[0] += 1
	GameState.roster_changed.connect(counter)
	var started_before := GameState.started
	var hud := _spawn(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud harness no restart", GameState.started == started_before and roster_events[0] == 0,
		"started=%s events=%d" % [str(GameState.started), roster_events[0]])
	TestFixtures.check(res, "hud harness wants_harness", HarnessEntry.wants_harness(), "wants_harness true in suite run")
	GameState.roster_changed.disconnect(counter)
	hud.queue_free()
