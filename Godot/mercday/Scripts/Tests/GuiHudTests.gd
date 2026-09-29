class_name GuiHudTests
extends RefCounted

#Suite for the Game HUD: the 3 x 3 menu grid and its locks and dots, the top-right cluster, the
#bottom bar, the money and time menus, viewer routing and the money fly. Flag --gui-hud-tests.

const HUD_SCENE := "res://Scenes/GUI/HUD/GameHUD.tscn"

#The nine tiles of the design, row by row; the suite holds them itself so a table edit shows up
#as a failure rather than agreeing with whatever GameHUD lists.
const LABELS: Array[String] = ["My Mercs", "My Contracts", "My Clients", "My Promotions",
	"My Mercday", "My Finance", "My Legal", "My Bazaar", "My Metrics"]
const KEYS: Array[StringName] = [&"mercs", &"contracts", &"clients", &"promotions", &"mercday",
	&"finance", &"legal", &"bazaar", &"metrics"]
const PLAN_TIP := "Locked. Requires Mercday Enterprise."
const PLAN_LINE1 := "This feature of Mercday is not available on your plan!"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await _case_layout(res, host)
	await _case_entries(res, host)
	await _case_money(res, host)
	await _case_time(res, host)
	await _case_menus(res, host)
	await _case_locks(res, host)
	await _case_lock_tables(res, host)
	await _case_dots(res, host)
	await _case_routing(res, host)
	await _case_fly(res, host)
	await _case_harness(res, host)
	_case_glyphs(res)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	CampaignClock.reset()
	SubscriptionManager.reset()
	return TestFixtures.summarize(res, "GUI HUD")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	SubscriptionManager.reset()
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
	var labels_ok := true
	var icons_ok := true
	for i in 9:
		var tile: GridMenuButton = hud.button(i)
		if tile == null:
			labels_ok = false
			continue
		if tile.label != LABELS[i]:
			labels_ok = false
		if tile.icon_rect.texture == null:
			icons_ok = false
	TestFixtures.check(res, "hud layout reads the nine design labels row by row", labels_ok,
		"%s / %s / %s" % [hud.button(0).label, hud.button(4).label, hud.button(8).label])
	TestFixtures.check(res, "hud layout gives every tile an icon texture", icons_ok, "9 icons")
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
	TestFixtures.check(res, "hud menu opens the mercs viewer", hud.popup().is_open()
		and hud.popup().current() is MercViewer, "popup %s" % hud.popup().current())
	hud.popup().close()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud menu closes", not hud.popup().is_open(), "popup closed")
	hud.open_menu(9)
	hud.open_menu(-1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud menu index out of range is a no-op", not hud.popup().is_open(),
		"popup stays closed")
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


static func _case_entries(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var order_ok := true
	var tips_ok := true
	var live_ok := true
	for i in 9:
		var tile: GridMenuButton = hud.button(i)
		if tile == null or hud.entry_key(i) != KEYS[i] or tile.label != LABELS[i]:
			order_ok = false
			continue
		if tile.description == "" or tile.tooltip_text != tile.description:
			tips_ok = false
		if tile.disabled or tile.locked:
			live_ok = false
	TestFixtures.check(res, "hud grid orders the nine viewer keys row by row", order_ok,
		"first %s last %s" % [hud.entry_key(0), hud.entry_key(8)])
	TestFixtures.check(res, "hud grid hover descriptions double as tooltips", tips_ok,
		"tile 3 tooltip %s" % hud.button(3).tooltip_text)
	TestFixtures.check(res, "hud grid tiles are live while the guild owns everything", live_ok,
		"plan %d" % SubscriptionManager.plan())
	TestFixtures.check(res, "hud grid keeps the 516 x 516 footprint in three columns",
		hud.menu_grid.columns == 3 and hud.menu_grid.size.is_equal_approx(Vector2(516, 516)),
		"columns %d size %s" % [hud.menu_grid.columns, hud.menu_grid.size])
	var tile_zero: GridMenuButton = hud.button(0)
	tile_zero.hover(true)
	TestFixtures.check(res, "hud grid draws over the bottom bar and a hovered tile over its row",
		hud.menu_grid.z_index == 3 and tile_zero.z_index == GridMenuButton.HOVER_Z_INDEX
			and hud.bottom_bar.z_index == 0 and hud.description_label.text == "",
		"grid %d hovered %d bar %d" % [hud.menu_grid.z_index, tile_zero.z_index,
			hud.bottom_bar.z_index])
	tile_zero.hover(false)
	var promotions: GridMenuButton = hud.button_of(&"promotions")
	TestFixtures.check(res, "hud promotions tile reads the design description and icon",
		promotions != null and promotions.description == "Run ad campaigns and hire mercs who apply"
			and promotions.icon_rect.texture != null
			and promotions.icon_rect.custom_minimum_size == Vector2(64, 64),
		"description %s" % promotions.description)
	var bazaar: GridMenuButton = hud.button_of(&"bazaar")
	TestFixtures.check(res, "hud bazaar tile reads the design description and icon",
		bazaar != null and bazaar.description == "Buy gear for your mercs and track your orders"
			and bazaar.icon_rect.texture != null
			and bazaar.icon_rect.custom_minimum_size == Vector2(64, 64),
		"description %s" % bazaar.description)
	var note_icon: IconRect = hud.button_of(&"finance").icon_rect
	TestFixtures.check(res, "hud finance tile draws the runtime note glyph at 7 px per art pixel",
		note_icon.texture != null and note_icon.custom_minimum_size == Vector2(49, 63),
		"min %s texture %s" % [note_icon.custom_minimum_size, note_icon.texture])
	var slot_rect: Rect2 = hud.bell_slot.get_global_rect()
	var gear_rect: Rect2 = hud.settings_button.get_global_rect()
	TestFixtures.check(res, "hud top right holds a 56 x 56 bell slot left of the settings gear",
		hud.bell_slot != null and hud.bell_slot.custom_minimum_size == Vector2(56, 56)
			and slot_rect.end.x <= gear_rect.position.x
			and absf(slot_rect.position.y - gear_rect.position.y) <= 1.0,
		"slot %s gear %s" % [slot_rect, gear_rect])
	hud.queue_free()


#Presses Take Me There on the open lock dialog and reports the target it asked GameState for.
#The HUD answers that request by opening My Mercday, so the popup is closed again here.
static func _take_me_there(hud: GameHUD) -> Dictionary:
	var dialog: FeatureLockDialog = hud.lock_dialog()
	if dialog == null:
		return {}
	var seen: Array[Dictionary] = []
	var catcher := func(target: Dictionary) -> void: seen.append(target)
	GameState.go_to_plans_requested.connect(catcher)
	dialog.press_take_me_there()
	GameState.go_to_plans_requested.disconnect(catcher)
	hud.popup().close()
	return {} if seen.is_empty() else seen[0]


static func _lines(hud: GameHUD) -> Array[String]:
	var dialog: FeatureLockDialog = hud.lock_dialog()
	if dialog == null:
		return ["", ""]
	return [dialog.line1_label.text, dialog.line2_label.text]


static func _case_locks(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var bazaar: GridMenuButton = hud.button_of(&"bazaar")
	var promotions: GridMenuButton = hud.button_of(&"promotions")
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud locks the bazaar and promotions tiles below Enterprise",
		bazaar.locked and promotions.locked and bazaar.visible and promotions.visible
			and bazaar.tooltip_text == PLAN_TIP and promotions.tooltip_text == PLAN_TIP,
		"bazaar %s / %s promotions %s / %s" % [bazaar.locked, bazaar.tooltip_text,
			promotions.locked, promotions.tooltip_text])
	TestFixtures.check(res, "hud locked tile greys its icon, dims its label and shows the badge",
		bazaar.icon_rect.modulate.is_equal_approx(GridMenuButton.GRAY_TINT)
			and bazaar.text_color().is_equal_approx(GuiColors.LOCKED_TEXT)
			and bazaar.lock_badge.visible and bazaar.lock_icon.texture != null,
		"modulate %s label %s badge %s" % [bazaar.icon_rect.modulate, bazaar.text_color(),
			bazaar.lock_badge.visible])
	bazaar.press()
	await host.get_tree().process_frame
	var plan_lines: Array[String] = _lines(hud)
	TestFixtures.check(res, "hud bazaar plan lock names the plan and never opens the window",
		hud.lock_dialog() != null and hud.lock_dialog().visible and not hud.popup().is_open()
			and plan_lines[0] == PLAN_LINE1
			and plan_lines[1] == "Upgrade to Mercday Enterprise to use the Bazaar.",
		"lines %s open %s" % [plan_lines, hud.popup().is_open()])
	var plan_target: Dictionary = _take_me_there(hud)
	TestFixtures.check(res, "hud plan lock take me there asks for the plans page",
		String(plan_target.get("tab", "")) == "plans" and not plan_target.has("upgrade"),
		"target %s" % plan_target)
	promotions.press()
	await host.get_tree().process_frame
	var promo_plan_lines: Array[String] = _lines(hud)
	TestFixtures.check(res, "hud promotions plan lock names promotions in its second line",
		promo_plan_lines[0] == PLAN_LINE1
			and promo_plan_lines[1] == "Upgrade to Mercday Enterprise to use Promotions.",
		"lines %s" % [promo_plan_lines])
	hud.lock_dialog().press_close()
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud upgrade lock tooltips point at Enterprise Customize",
		bazaar.locked and promotions.locked
			and bazaar.tooltip_text
				== "Locked. Requires the Bazaar upgrade (Mercday Enterprise > Customize)."
			and promotions.tooltip_text
				== "Locked. Requires the Promotions upgrade (Mercday Enterprise > Customize).",
		"bazaar %s promotions %s" % [bazaar.tooltip_text, promotions.tooltip_text])
	bazaar.press()
	await host.get_tree().process_frame
	var up_lines: Array[String] = _lines(hud)
	TestFixtures.check(res, "hud bazaar upgrade lock names the bazaar upgrade",
		not hud.popup().is_open() and up_lines[0] == "The Bazaar is locked."
			and up_lines[1] == "It requires the Bazaar upgrade!",
		"lines %s open %s" % [up_lines, hud.popup().is_open()])
	var up_target: Dictionary = _take_me_there(hud)
	TestFixtures.check(res, "hud upgrade lock take me there asks for the bazaar upgrade row",
		String(up_target.get("tab", "")) == "customize"
			and String(up_target.get("upgrade", "")) == "bazaar"
			and int(up_target.get("tier", 0)) == 1,
		"target %s" % up_target)
	promotions.press()
	await host.get_tree().process_frame
	var promo_up_lines: Array[String] = _lines(hud)
	TestFixtures.check(res, "hud promotions upgrade lock names the promotions upgrade",
		promo_up_lines[0] == "Promotions is locked."
			and promo_up_lines[1] == "It requires the Promotions upgrade.",
		"lines %s" % [promo_up_lines])
	var promo_up_target: Dictionary = _take_me_there(hud)
	TestFixtures.check(res, "hud promotions upgrade take me there asks for its own row",
		String(promo_up_target.get("tab", "")) == "customize"
			and String(promo_up_target.get("upgrade", "")) == "promotions"
			and int(promo_up_target.get("tier", 0)) == 1,
		"target %s" % promo_up_target)
	SubscriptionManager.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud clears both locks once the upgrades are owned",
		not bazaar.locked and not promotions.locked and not bazaar.lock_badge.visible
			and bazaar.tooltip_text == bazaar.description,
		"bazaar %s promotions %s" % [bazaar.locked, promotions.locked])
	promotions.press()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud unlocked promotions tile opens its window", hud.popup().is_open(),
		"popup %s" % hud.popup().current())
	hud.popup().close()
	hud.queue_free()


#The lock table holds ids only: UpgradeDefs owns every upgrade name and tier count.
static func _case_lock_tables(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var repeated: Array[String] = []
	var mismatch: Array[String] = []
	for key: StringName in GameHUD.LOCK_DEFS:
		var row: Dictionary = GameHUD.LOCK_DEFS[key]
		if row.has("upgrade") or row.has("tiers"):
			repeated.append(String(key))
		var id: String = String(row["upgrade_id"])
		var props: Dictionary = hud.lock_props(key)
		if String(props.get("upgrade", "")) != UpgradeDefs.name_of(id):
			mismatch.append("%s name %s" % [key, props.get("upgrade", "")])
		if int(props.get("tiers", 0)) != maxi(1, UpgradeDefs.tier_count(id)):
			mismatch.append("%s tiers %s" % [key, props.get("tiers", 0)])
	TestFixtures.check(res, "hud lock rows carry no upgrade name and no tier count of their own",
		repeated.is_empty(), "rows %s" % [repeated])
	TestFixtures.check(res, "hud lock props read the name and the tier count from UpgradeDefs",
		mismatch.is_empty() and GameHUD.LOCK_DEFS.size() == 2,
		"%d rows, %s" % [GameHUD.LOCK_DEFS.size(), mismatch])
	hud.queue_free()


#Every dot source reports nothing unseen, so a dot that stays on is the HUD's own fault.
static func _quiet_managers() -> void:
	FinanceManager.mark_offers_seen()
	PromotionsManager.mark_seen()
	LegalManager.mark_fines_seen()
	LegalManager.mark_captures_seen()
	for id: int in GameState.unclaimed_ids():
		GameState.mark_seen(id)


static func _dots_on(hud: GameHUD) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in 9:
		if hud.button(i).dot_node.on:
			out.append(KEYS[i])
	return out


static func _only_dot(hud: GameHUD, key: StringName) -> bool:
	var on: Array[StringName] = _dots_on(hud)
	return on.size() == 1 and on.has(key)


static func _case_dots(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	_quiet_managers()
	hud.refresh_dots()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud shows no dot while every manager is caught up",
		_dots_on(hud).is_empty(), "on %s" % [_dots_on(hud)])
	var none: Array[int] = []
	LegalManager.add_fine(1, "Trespass", none, -1, 50, 10)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud legal dot follows an unread fine on the manager signal",
		_only_dot(hud, &"legal"), "on %s" % [_dots_on(hud)])
	var legal_dot: NotificationDot = hud.button_of(&"legal").dot_node
	TestFixtures.check(res, "the unlocked tile pins its dot through NotificationDot.pin",
		legal_dot.offset_right == -GridMenuButton.DOT_INSET
			and legal_dot.offset_left
				== -GridMenuButton.DOT_INSET - NotificationDot.FRAME_SIZE.x
			and legal_dot.offset_top == GridMenuButton.DOT_INSET
			and legal_dot.offset_bottom
				== GridMenuButton.DOT_INSET + NotificationDot.FRAME_SIZE.y,
		"left %.1f right %.1f top %.1f bottom %.1f" % [legal_dot.offset_left,
			legal_dot.offset_right, legal_dot.offset_top, legal_dot.offset_bottom])
	LegalManager.mark_fines_seen()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud legal dot clears on the manager signal once the fines are seen",
		_dots_on(hud).is_empty(), "on %s" % [_dots_on(hud)])
	LegalManager.add_capture(-1, 1, "Brawling", -1, 10, 120)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud legal dot follows an unread capture on the manager signal",
		_only_dot(hud, &"legal"), "on %s" % [_dots_on(hud)])
	LegalManager.mark_captures_seen()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud legal dot clears on the manager signal once the captures are seen",
		_dots_on(hud).is_empty(), "on %s" % [_dots_on(hud)])
	FinanceManager.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud finance dot follows an unread loan offer",
		_only_dot(hud, &"finance"), "on %s" % [_dots_on(hud)])
	FinanceManager.mark_offers_seen()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud finance dot clears once the offers are seen",
		_dots_on(hud).is_empty(), "on %s" % [_dots_on(hud)])
	PromotionsManager.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud finance dot also reads unseen applicants",
		PromotionsManager.has_unseen() and _only_dot(hud, &"finance"),
		"unseen %s on %s" % [PromotionsManager.has_unseen(), _dots_on(hud)])
	PromotionsManager.mark_seen()
	await host.get_tree().process_frame
	var seeded: Array[int] = GameState.seed_results_preview()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud contracts dot follows an unclaimed result",
		seeded.size() == 2 and _only_dot(hud, &"contracts"),
		"seeded %d on %s" % [seeded.size(), _dots_on(hud)])
	for id: int in GameState.unclaimed_ids():
		GameState.mark_seen(id)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud contracts dot clears once the results are opened",
		_dots_on(hud).is_empty(), "on %s" % [_dots_on(hud)])
	TestFixtures.check(res, "hud never dots the tiles the design leaves clean",
		not hud.dot_state(&"bazaar") and not hud.dot_state(&"promotions")
			and not hud.dot_state(&"mercs") and not hud.dot_state(&"metrics"),
		"bazaar %s promotions %s" % [hud.dot_state(&"bazaar"), hud.dot_state(&"promotions")])
	LegalManager.reset()
	FinanceManager.mark_offers_seen()
	hud.queue_free()


#The line the in-memory placeholder window carries, or "" when the popup holds a real viewer.
static func _placeholder_text(hud: GameHUD) -> String:
	var content: Node = hud.popup().current()
	if content == null:
		return ""
	var line: Label = content.get_node_or_null(^"DescriptionLabel") as Label
	if line == null:
		return ""
	return line.text


#True when the popup holds what this key routes to: the real viewer scene once a later wave has
#built it, or the placeholder named after the tile until then.
static func _shows(hud: GameHUD, key: StringName) -> bool:
	var content: Node = hud.popup().current()
	if content == null:
		return false
	var want: String = String(GameHUD.VIEWER_SCENES.get(key, ""))
	if want != "" and content.scene_file_path == want:
		return true
	return _placeholder_text(hud) == "%s is not available yet" % hud.label_of(key)


static func _case_routing(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var made: Node = hud.open_viewer(&"nowhere")
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud open_viewer shows a placeholder for a viewer it cannot load",
		made != null and hud.popup().current() == made
			and _placeholder_text(hud) == "nowhere is not available yet",
		"made %s text %s" % [made, _placeholder_text(hud)])
	hud.popup().close()
	hud.open_menu(2)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud clients tile routes to the client viewer",
		hud.popup().is_open() and _shows(hud, &"clients"),
		"content %s" % hud.popup().current())
	hud.popup().close()
	var in_tree: Array[bool] = []
	var setup := func(opened: Node) -> void: in_tree.append(opened.is_inside_tree())
	var merc_view: Node = hud.open_viewer(&"mercs", setup)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud open_viewer runs its setup after the viewer joined the tree",
		merc_view is MercViewer and in_tree.size() == 1 and in_tree[0],
		"view %s in_tree %s" % [merc_view, in_tree])
	hud.popup().close()
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	var blocked: Node = hud.open_viewer(&"bazaar")
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud open_viewer refuses a locked key and opens the dialog instead",
		blocked == null and not hud.popup().is_open()
			and hud.lock_dialog() != null and hud.lock_dialog().visible,
		"blocked %s open %s" % [blocked, hud.popup().is_open()])
	hud.lock_dialog().press_close()
	SubscriptionManager.reset()
	await host.get_tree().process_frame
	GameState.go_to_plans({"tab": "plans"})
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud opens My Mercday when a lock asks for the plans page",
		hud.popup().is_open() and _shows(hud, &"mercday"),
		"content %s" % hud.popup().current())
	GameState.open_hiring(1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud swaps to My Finance when a campaign asks for hiring",
		hud.popup().is_open() and _shows(hud, &"finance"),
		"content %s" % hud.popup().current())
	hud.popup().close()
	NotificationCenter.reset()
	var entry_id: int = -1
	if not GameState.contracts.is_empty():
		entry_id = GameState.contracts[0].entry_id
	var row: NotificationData = NotificationCenter.push(NotificationData.TYPE_CONTRACT_COMPLETED,
		entry_id)
	var view: Node = hud.open_notification(row)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud contract notice opens the contract viewer on its own posting",
		view is ContractViewer and (view as ContractViewer).selected_id == entry_id and row.read,
		"view %s selected %d entry %d read %s" % [view,
			(view as ContractViewer).selected_id if view is ContractViewer else -2, entry_id,
			row.read])
	hud.popup().close()
	var offer_row: NotificationData = NotificationCenter.push(NotificationData.TYPE_LOAN_OFFER, 1)
	var offer_view: Node = hud.open_notification(offer_row)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud loan notice routes to My Finance and marks itself read",
		offer_view != null and _shows(hud, &"finance") and offer_row.read,
		"content %s read %s" % [hud.popup().current(), offer_row.read])
	hud.popup().close()
	var odd_row: NotificationData = NotificationCenter.push(&"somethingElse", 1)
	var odd_view: Node = hud.open_notification(odd_row)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud reads a notice it has no route for and opens nothing",
		odd_view == null and not hud.popup().is_open() and odd_row.read,
		"view %s open %s read %s" % [odd_view, hud.popup().is_open(), odd_row.read])
	TestFixtures.check(res, "hud open_notification ignores a null notice",
		hud.open_notification(null) == null and not hud.popup().is_open(), "null notice")
	NotificationCenter.reset()
	hud.queue_free()


static func _case_fly(res: Dictionary, host: Node) -> void:
	_fresh()
	var hud := _spawn(host)
	await host.get_tree().process_frame
	var fly: MoneyFly = hud.money_fly()
	var money: MoneyMenu = hud.bottom_bar.money_menu()
	TestFixtures.check(res, "hud money fly waits idle over the HUD and aims at the counter",
		fly != null and not fly.is_flying() and not fly.visible and fly.counter() == money
			and fly.z_index == 200 and fly.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"flying %s visible %s counter %s z %d" % [fly.is_flying(), fly.visible, fly.counter(),
			fly.z_index])
	GameState.fly_money(0)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud money fly ignores a zero amount", not fly.is_flying(),
		"flying %s" % fly.is_flying())
	var before: int = GameState.bank_notes
	GameState.fly_money(500)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud money fly runs an income and tints the counter green",
		fly.is_flying() and fly.amount() == 500 and fly.visible
			and money.tint().is_equal_approx(MoneyMenu.GAIN_COLOR)
			and GameState.bank_notes == before,
		"amount %d tint %s notes %d" % [fly.amount(), money.tint(), GameState.bank_notes])
	fly.set_time(0.0)
	var start_pos: Vector2 = fly.note_position(0)
	fly.set_time(MoneyFly.NOTE_SPAN * 0.5)
	var mid_pos: Vector2 = fly.note_position(0)
	var mid_alpha: float = fly.note_opacity(0)
	fly.set_time(MoneyFly.NOTE_SPAN)
	var end_pos: Vector2 = fly.note_position(0)
	TestFixtures.check(res, "hud money fly arcs sixteen notes into the counter",
		start_pos.is_equal_approx(fly.note_start(0))
			and end_pos.is_equal_approx(fly.counter_point())
			and mid_pos.y < (start_pos.y + end_pos.y) * 0.5
			and fly.note_positions().size() == MoneyFly.NOTE_COUNT
			and mid_alpha == 1.0 and fly.note_opacity(0) == 0.0,
		"start %s mid %s end %s alpha %.1f" % [start_pos, mid_pos, end_pos, mid_alpha])
	GameState.bank_notes = 777
	GameState.money_changed.emit(777)
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud counter value follows money_changed while a fly is running",
		money.text().contains("777") and fly.is_flying(), "text %s" % money.text())
	var done: Array[int] = []
	fly.finished.connect(func(paid: int) -> void: done.append(paid))
	fly.finish_now()
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud money fly reports what it carried and clears the tint",
		not fly.is_flying() and not fly.visible and done.size() == 1 and done[0] == 500
			and money.tint().is_equal_approx(MoneyMenu.IDLE_COLOR),
		"done %s tint %s" % [done, money.tint()])
	GameState.fly_money(-250)
	await host.get_tree().process_frame
	fly.set_time(0.0)
	var loss_start: Vector2 = fly.note_position(0)
	fly.set_time(MoneyFly.NOTE_SPAN)
	var loss_end: Vector2 = fly.note_position(0)
	TestFixtures.check(res, "hud money fly runs a spend out of the counter and tints it red",
		fly.is_flying() and fly.amount() == -250
			and money.tint().is_equal_approx(MoneyMenu.LOSS_COLOR)
			and loss_start.is_equal_approx(fly.counter_point())
			and loss_end.is_equal_approx(fly.note_start(0)),
		"amount %d tint %s start %s end %s" % [fly.amount(), money.tint(), loss_start, loss_end])
	fly.set_time(MoneyFly.DURATION - 0.001)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "hud money fly stops itself at the end of its run and drops the tint",
		not fly.is_flying() and not fly.visible and done.size() == 2 and done[1] == -250
			and money.tint().is_equal_approx(MoneyMenu.IDLE_COLOR),
		"flying %s done %s tint %s" % [fly.is_flying(), done, money.tint()])
	hud.queue_free()


#The runtime HUD glyphs: a key the map table does not hold draws nothing at all.
static func _case_glyphs(res: Dictionary) -> void:
	var bogus: StringName = &"no_such_glyph"
	var known: Array[String] = HudGlyphs.map_of(HudGlyphs.MERCDAY)
	TestFixtures.check(res, "a known glyph key still gives its own map and size",
		HudGlyphs.has(HudGlyphs.MERCDAY) and known.size() == 16
			and HudGlyphs.size_of(HudGlyphs.MERCDAY) == Vector2i(16, 16),
		"rows %d size %s" % [known.size(), HudGlyphs.size_of(HudGlyphs.MERCDAY)])
	TestFixtures.check(res, "a known glyph key builds a texture at its scale",
		HudGlyphs.texture(HudGlyphs.MERCDAY, 2).get_size() == Vector2(32.0, 32.0),
		"size %s" % HudGlyphs.texture(HudGlyphs.MERCDAY, 2).get_size())
	TestFixtures.check(res, "an unknown glyph key gives an empty map and a zero size",
		not HudGlyphs.has(bogus) and HudGlyphs.map_of(bogus).is_empty()
			and HudGlyphs.size_of(bogus) == Vector2i.ZERO,
		"map %s size %s" % [HudGlyphs.map_of(bogus), HudGlyphs.size_of(bogus)])
	var blank: ImageTexture = HudGlyphs.texture(bogus, 2)
	var pixel: Color = blank.get_image().get_pixel(0, 0)
	TestFixtures.check(res, "an unknown glyph key draws a single transparent pixel",
		blank.get_size() == Vector2(1.0, 1.0) and is_zero_approx(pixel.a),
		"size %s alpha %.2f" % [blank.get_size(), pixel.a])
