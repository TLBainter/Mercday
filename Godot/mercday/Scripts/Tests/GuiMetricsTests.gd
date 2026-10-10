class_name GuiMetricsTests

#The Metrics Viewer screen: the graph tabs, the metric list, the two selectors, the Period and
#Scale dropdowns, the subscription locks and the line chart, all driven against a live campaign
#with the preview history seeded onto it.
#Run: godot --headless --path . with the arg separator, then --gui-metrics-tests

const VIEWER_SCENE := preload("res://Scenes/GUI/Metrics/MetricsViewer.tscn")
const CHART_PATH := "Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/Chart"
const HISTORY_PATH := "res://Scripts/GUI/Autoloads/MetricsHistory.gd"
const PREVIEW_DAYS := 120
#The lock case reads the third merc, one past the start roster.
const LOCK_EXTRA := 1
const SEED_DAYS := 50
const LONG_DAYS := 200
#Three dates for the period table: the first day of a Trynn year, mid year and the last day.
const YEAR_START := 660
const YEAR_MID := 825
const YEAR_END := 989
const DEEP_HISTORY := 3000


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	await _case_layout(res, host)
	await _case_chart_size(res, host)
	await _case_series(res, host)
	await _case_window(res, host)
	await _case_chart(res, host)
	await _case_focus(res, host)
	await _case_lock(res, host)
	await _case_seed(res, host)
	await _case_entitlements(res, host)
	await _case_graph_locks(res, host)
	await _case_merc_tiers(res, host)
	await _case_metric_locks(res, host)
	_case_lock_tables(res)
	await _case_override_spellings(res, host)
	await _case_new_metrics(res, host)
	await _case_team_average(res, host)
	await _case_averages_and_compare(res, host)
	_case_period_rules(res)
	_case_scale_rules(res)
	await _case_window_math(res, host)
	_case_arrow_math(res)
	_case_x_labels(res)
	_case_combined_weight(res)
	_case_event_avg_carry(res)
	await _case_bevel_sweep(res, host)
	await _case_window_fit(res, host)
	await _case_reopen_metrics(res, host)
	_reset()
	return TestFixtures.summarize(res, "GUI METRICS")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	SubscriptionManager.max_out()


static func _reset() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.max_out()
	MetricsHistory.clear()
	MetricsHistory.clear_preview()
	GuildRoster.reset()
	TestFixtures.reset_campaign()


static func _uids() -> Array[int]:
	var out: Array[int] = []
	for view: MercView in GameState.roster:
		out.append(view.uid)
	return out


#A fresh campaign with extra mercs hired, the preview history renamed onto its roster, and the viewer opened on it.
static func _open(host: Node, extra: int = 0) -> MetricsViewer:
	_fresh()
	TestFixtures.add_mercs(extra)
	MetricsHistory.seed_preview(PREVIEW_DAYS, _uids())
	var viewer: MetricsViewer = VIEWER_SCENE.instantiate()
	(viewer.get_node(CHART_PATH) as LineChart).tween_seconds = 0.0
	host.add_child(viewer)
	await host.get_tree().process_frame
	return viewer


#The picks the designer rule resets, less the merc on show, which a re-lock moves on purpose.
static func _picks(viewer: MetricsViewer) -> Dictionary:
	return {"source": viewer.source(), "period": int(viewer.period), "scale": viewer.wanted_scale(),
		"guild": viewer.metric_list.active_keys("Guild"),
		"contract": viewer.metric_list.active_keys("Contract"),
		"merc": viewer.metric_list.active_keys("Merc"), "types": viewer.type_selector.selected_types(),
		"comparing": viewer.comparing(), "averages": viewer.averages_on()}


#Designer rule 2026-10-04: the picks reset once the Metrics window is fully closed.
static func _case_reopen_metrics(res: Dictionary, host: Node) -> void:
	_fresh()
	TestFixtures.add_mercs(LOCK_EXTRA)
	MetricsHistory.seed_preview(PREVIEW_DAYS, _uids())
	var hud: GameHUD = GuiHudTests.spawn_hud(host)
	await host.get_tree().process_frame
	var viewer: MetricsViewer = hud.open_viewer(&"metrics") as MetricsViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "the HUD opens the Metrics window", viewer != null, "viewer %s" % str(viewer))
	if viewer == null:
		await GuiClickJBTests._close(host, hud)
		_reset()
		return
	var first: Dictionary = _picks(viewer)
	var first_uid: int = viewer.merc_selector.selected_uid()
	var first_series: int = viewer.chart.series_count()
	viewer.show_all.pressed.emit()
	await host.get_tree().process_frame
	var all_series: int = viewer.chart.series_count()
	viewer.select_source("Contract")
	var types: Array[String] = viewer.type_selector.selected_types()
	types.pop_back()
	viewer.type_selector.set_types(types)
	viewer.hide_all.pressed.emit()
	viewer.select_source("Merc")
	viewer.merc_selector.select_uid(GameState.roster[0].uid)
	viewer.hide_all.pressed.emit()
	viewer.show_averages.set_pressed(true)
	var averaged: bool = viewer.averages_on()
	viewer.compare_button.pressed.emit()
	viewer.compare_selector.select_uid(GameState.roster[1].uid)
	viewer.period_drop.option_selected.emit(MetricsPeriod.period_key(
		(int(viewer.period) + 1) % MetricsPeriod.PERIOD_KEYS.size()))
	viewer.scale_drop.option_selected.emit(MetricsPeriod.scale_key(
		(viewer.wanted_scale() + 1) % MetricsPeriod.SCALE_KEYS.size()))
	await host.get_tree().process_frame
	var moved: Dictionary = _picks(viewer)
	var still: Array[String] = []
	for key: String in first:
		if key != "averages" and moved[key] == first[key]:
			still.append(key)
	TestFixtures.check(res, "the Metrics window picks under test moved",
		still.is_empty() and averaged and all_series > first_series
			and viewer.merc_selector.selected_uid() != first_uid,
		"unmoved %s averaged %s series %d of %d" % [str(still), averaged, all_series, first_series])
	hud.popup().close()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "closing the Metrics window frees its content",
		not is_instance_valid(viewer), "valid %s" % is_instance_valid(viewer))
	var again: MetricsViewer = hud.open_viewer(&"metrics") as MetricsViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var picks: Dictionary = {} if again == null else _picks(again)
	TestFixtures.check(res,
		"a fully closed Metrics window opens again with its source, lists, types and period reset",
		again != null and picks == first, "first %s again %s" % [str(first), str(picks)])
	TestFixtures.check(res, "a fully closed Metrics window opens again on All Mercs with no compare",
		again != null and again.merc_selector.selected_uid() == first_uid and not again.comparing()
			and again.chart.series_count() == first_series,
		"merc %d comparing %s series %d" % [again.merc_selector.selected_uid() if again != null else -9,
			again != null and again.comparing(), again.chart.series_count() if again != null else -1])
	if again == null:
		await GuiClickJBTests._close(host, hud)
		_reset()
		return
	#Compare holds the averages switch off, so a second close runs with averages on and no compare.
	again.select_source("Merc")
	again.merc_selector.select_uid(GameState.roster[0].uid)
	again.show_averages.set_pressed(true)
	await host.get_tree().process_frame
	var lit: bool = again.averages_on() and not again.comparing()
	hud.popup().close()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var third: MetricsViewer = hud.open_viewer(&"metrics") as MetricsViewer
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	TestFixtures.check(res, "a fully closed Metrics window opens again with its averages switch off",
		lit and third != null and not third.averages_on() and not first["averages"],
		"lit %s third %s averages %s" % [lit, third != null, third != null and third.averages_on()])
	await GuiClickJBTests._close(host, hud)
	_reset()


#The same viewer moved onto the Merc tab with the first roster merc picked, where the picker would
#otherwise stand on All Mercs.
static func _open_merc(host: Node) -> MetricsViewer:
	var viewer: MetricsViewer = await _open(host)
	viewer.select_source("Merc")
	viewer.merc_selector.select_uid(GameState.roster[0].uid)
	await host.get_tree().process_frame
	return viewer


static func _def(list: Array[MetricDef], key: String) -> MetricDef:
	for def: MetricDef in list:
		if def.key == key:
			return def
	return null


static func _points(count: int, values: Array[float]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in count:
		out.append({"day": i, "value": values[i % values.size()]})
	return out


static func _sum(points: Array[Dictionary]) -> float:
	var total: float = 0.0
	for point: Dictionary in points:
		total += float(point["value"])
	return total


static func _case_layout(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open(host)
	var seen: Dictionary = {}
	_layout_tabs(res, viewer)
	_layout_panel(res, viewer, seen)
	_layout_header(res, viewer)
	_layout_list(res, viewer)
	await _layout_picker(res, host, viewer, seen)
	await _layout_merc_list(res, host, viewer, seen)
	viewer.queue_free()


#The three tab buttons: sizes, labels, atlas icons, tones and the tab row height.
static func _layout_tabs(res: Dictionary, viewer: MetricsViewer) -> void:
	TestFixtures.check(res, "the graph tabs offer the three sources with Guild first and active",
		viewer.tabs.buttons().size() == 3 and viewer.tabs.active_key() == &"Guild"
			and String(viewer.tabs.get_child(0).name) == "Guild"
			and viewer.tabs.get_child(0) is TabButton,
		"got %d tabs on '%s'" % [viewer.tabs.buttons().size(), viewer.tabs.active_key()])
	var guild_tab: TabButton = viewer.tabs.button(&"Guild")
	var merc_tab: TabButton = viewer.tabs.button(&"Merc")
	TestFixtures.check(res, "the active tab stands 44 px and an idle one 38 px",
		guild_tab.active and guild_tab.custom_minimum_size.y == TabButton.ACTIVE_HEIGHT
			and not merc_tab.active and merc_tab.custom_minimum_size.y == TabButton.IDLE_SIZE.y,
		"guild %s merc %s" % [guild_tab.custom_minimum_size, merc_tab.custom_minimum_size])
	TestFixtures.check(res, "an idle metrics tab is an icon square with its name as the tooltip",
		not merc_tab.text_label.visible and merc_tab.custom_minimum_size == TabButton.IDLE_SIZE
			and merc_tab.tooltip_text == "Merc",
		"label %s size %s tip '%s'" % [merc_tab.text_label.visible,
			str(merc_tab.custom_minimum_size), merc_tab.tooltip_text])
	TestFixtures.check(res, "the active tab shows its icon and its label and is 44 tall",
		guild_tab.text_label.visible and guild_tab.text_label.text == "GUILD"
			and guild_tab.custom_minimum_size.y == float(TabButton.ACTIVE_HEIGHT)
			and is_equal_approx(guild_tab.custom_minimum_size.x,
				maxf(TabButton.IDLE_SIZE.x, viewer.active_width(guild_tab))),
		"size %s against %.1f" % [str(guild_tab.custom_minimum_size),
			viewer.active_width(guild_tab)])
	TestFixtures.check(res, "every tab carries its atlas icon at x2 in a 32 px box",
		guild_tab.icon_rect.icon_id == "guild_banner" and merc_tab.icon_rect.icon_id == "mercs"
			and guild_tab.icon_scale == 2
			and guild_tab.icon_rect.custom_minimum_size == Vector2(32, 32)
			and guild_tab.icon_rect.texture != null,
		"guild '%s' merc '%s' box %s" % [guild_tab.icon_rect.icon_id,
			merc_tab.icon_rect.icon_id, str(guild_tab.icon_rect.custom_minimum_size)])
	TestFixtures.check(res, "the tab ids come from the atlas",
		viewer.tabs.button(&"Guild").icon_id == "guild_banner"
			and viewer.tabs.button(&"Contract").icon_id == "contracts"
			and viewer.tabs.button(&"Merc").icon_id == "mercs"
			and Icons.has("guild_banner") and Icons.has("contracts") and Icons.has("mercs"),
		"got %s" % str(viewer.tabs.icon_ids))
	TestFixtures.check(res, "the active tab two-tones its icon and an idle tab draws it plain",
		guild_tab.icon_rect.mode == Icons.MODE_TWO_TONE
			and merc_tab.icon_rect.mode == Icons.MODE_PLAIN
			and _tab_tone_ok("guild_banner") and _tab_tone_ok("contracts")
			and _tab_tone_ok("mercs"),
		"active '%s' idle '%s'" % [guild_tab.icon_rect.mode, merc_tab.icon_rect.mode])
	TestFixtures.check(res, "the tab row stands 44 px tall",
		viewer.tabs.custom_minimum_size.y == float(TabButton.ACTIVE_HEIGHT),
		"got %s" % str(viewer.tabs.custom_minimum_size))


#The viewer height, the left panel against the chart panel and the header row against the chart edge.
static func _layout_panel(res: Dictionary, viewer: MetricsViewer, seen: Dictionary) -> void:
	var guild_tab: TabButton = viewer.tabs.button(&"Guild")
	TestFixtures.check(res, "the viewer fits the 644 px window",
		viewer.get_combined_minimum_size().y <= 644.0,
		"minimum %.1f" % viewer.get_combined_minimum_size().y)
	TestFixtures.check(res, "the metric list never scrolls",
		viewer.list_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"mode %d" % viewer.list_scroll.vertical_scroll_mode)
	var chart_panel_end: float = viewer.chart_panel.global_position.y + viewer.chart_panel.size.y
	var panel_end: float = viewer.left_panel.global_position.y + viewer.left_panel.size.y
	TestFixtures.check(res, "the left panel's bottom lands on the chart panel's bottom",
		absf(panel_end - chart_panel_end) <= 1.0,
		"panel %.1f chart %.1f" % [panel_end, chart_panel_end])
	var left_margin: MarginContainer = viewer.left_box.get_parent() as MarginContainer
	var margin_bottom: float = float(left_margin.get_theme_constant("margin_bottom"))
	var panel_box: StyleBox = viewer.left_panel.get_theme_stylebox("panel")
	if panel_box != null:
		margin_bottom += panel_box.get_margin(SIDE_BOTTOM)
	var rows_end: float = viewer.list_buttons.global_position.y + viewer.list_buttons.size.y
	TestFixtures.check(res, "the Show All / Hide All row sits above the panel's bottom margin",
		absf(rows_end - (panel_end - margin_bottom)) <= 1.0,
		"rows %.1f panel %.1f margin %.1f" % [rows_end, panel_end, margin_bottom])
	var chart_edge_top: float = viewer.chart_edge.global_position.y
	var header_bottom: float = viewer.header_row.global_position.y + viewer.header_row.size.y
	var guild_tab_bottom: float = guild_tab.global_position.y + guild_tab.size.y
	TestFixtures.check(res, "the header row and the active Guild tab meet the chart edge",
		absf(header_bottom - chart_edge_top) <= 0.5
			and absf(guild_tab_bottom - chart_edge_top) <= 0.5,
		"header %.1f tab %.1f edge %.1f" % [header_bottom, guild_tab_bottom, chart_edge_top])
	seen["guild"] = viewer.left_panel.size.y
	seen["header"] = header_bottom
	seen["edge"] = chart_edge_top


#The header row order and gaps, the two dropdowns, the tab row seat and the chart panel dressing.
static func _layout_header(res: Dictionary, viewer: MetricsViewer) -> void:
	TestFixtures.check(res, "the tabs, the switch and the two dropdowns share the header row",
		viewer.tabs.get_parent() == viewer.header_row
			and viewer.show_averages.get_parent() == viewer.header_row
			and viewer.period_drop.get_parent() == viewer.header_row
			and viewer.scale_drop.get_parent() == viewer.header_row,
		"parents '%s', '%s', '%s' and '%s'" % [viewer.tabs.get_parent().name,
			viewer.show_averages.get_parent().name, viewer.period_drop.get_parent().name,
			viewer.scale_drop.get_parent().name])
	TestFixtures.check(res, "the right of the row reads Show Averages, Period, Scale over a 16 gap",
		viewer.show_averages.get_index() < viewer.period_drop.get_index()
			and viewer.period_drop.get_index() < viewer.scale_drop.get_index()
			and viewer.header_row.get_theme_constant("separation") == 16,
		"indexes %d, %d, %d over %d" % [viewer.show_averages.get_index(),
			viewer.period_drop.get_index(), viewer.scale_drop.get_index(),
			viewer.header_row.get_theme_constant("separation")])
	TestFixtures.check(res, "the dropdowns carry the Period and Scale captions over 30 px buttons",
		viewer.period_drop.label == "PERIOD" and viewer.scale_drop.label == "SCALE"
			and viewer.period_drop.caption.text == "PERIOD"
			and viewer.period_drop.toggle.custom_minimum_size == Vector2(92, 30)
			and viewer.scale_drop.toggle.custom_minimum_size == Vector2(92, 30),
		"'%s' and '%s' over %s" % [viewer.period_drop.label, viewer.scale_drop.label,
			str(viewer.period_drop.toggle.custom_minimum_size)])
	TestFixtures.check(res, "the dropdowns open on All Time and the scale the window allows",
		viewer.period_drop.button_text() == "All Time" and viewer.scale_drop.button_text()
			== "Weeks" and viewer.period == MetricsPeriod.Period.ALL_TIME
			and viewer.chart_scale == MetricsPeriod.Scale.WEEK,
		"'%s' and '%s'" % [viewer.period_drop.button_text(), viewer.scale_drop.button_text()])
	TestFixtures.check(res, "the tab row sits straight on the chart panel",
		viewer.panel_gap() == MetricsViewer.ATTACHED_GAP
			and viewer.right_box.get_theme_constant("separation") == 0,
		"gap %d" % viewer.panel_gap())
	TestFixtures.check(res, "the chart panel carries the ink outline and the two bevel insets",
		viewer.chart_panel.get_theme_stylebox("panel").border_color == MetricsViewer.PANEL_OUTLINE
			and viewer.bevel_hi.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and viewer.bevel_lo.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"colour %s" % str(viewer.chart_panel.get_theme_stylebox("panel").border_color))
	TestFixtures.check(res, "the chart keeps its 888 px width while the viewer stands alone",
		viewer.chart.custom_minimum_size.x == 888.0 and not viewer.chart.compact,
		"got %s" % str(viewer.chart.custom_minimum_size))


#The list title, the hidden chart title, the averages switch, the metric column and the Guild toggles.
static func _layout_list(res: Dictionary, viewer: MetricsViewer) -> void:
	TestFixtures.check(res, "the list title holds one clipped line",
		viewer.list_head.caption_label.clip_text and viewer.list_head.caption_label.autowrap_mode
			== TextServer.AUTOWRAP_OFF
			and viewer.list_head.caption_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		"clip %s wrap %d overrun %d" % [viewer.list_head.caption_label.clip_text,
			viewer.list_head.caption_label.autowrap_mode, viewer.list_head.caption_label.text_overrun_behavior])
	TestFixtures.check(res, "the old chart title stays hidden behind the tabs",
		not viewer.title_label.visible, "visible %s" % viewer.title_label.visible)
	TestFixtures.check(res, "the averages switch keeps out of the Guild tab",
		not viewer.show_averages.visible, "visible %s" % viewer.show_averages.visible)
	TestFixtures.check(res, "the metric column holds the wider width",
		int(viewer.left_panel.custom_minimum_size.x) == 300,
		"got %s" % str(viewer.left_panel.custom_minimum_size))
	var guild_defs: int = MetricList.defs_for("Guild").size()
	TestFixtures.check(res, "the Guild tab opens with one toggle per Guild metric",
		viewer.metric_list.toggle_count() == guild_defs
			and viewer.list_head.caption_label.text == "Guild Data",
		"got %d toggles under '%s'" % [viewer.metric_list.toggle_count(), viewer.list_head.caption_label.text])


#The Merc tab with no merc picked, then with one picked: the tenure caption, the toggles and the picker rows.
static func _layout_picker(res: Dictionary, host: Node, viewer: MetricsViewer, seen: Dictionary) -> void:
	var guild_tab: TabButton = viewer.tabs.button(&"Guild")
	var merc_tab: TabButton = viewer.tabs.button(&"Merc")
	var header_bottom: float = seen["header"]
	var chart_edge_top: float = seen["edge"]
	viewer.select_source("Merc")
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking a source flips the active flags",
		merc_tab.active and not guild_tab.active
			and merc_tab.custom_minimum_size.y == TabButton.ACTIVE_HEIGHT,
		"merc %s guild %s" % [merc_tab.active, guild_tab.active])
	TestFixtures.check(res, "the picker hints at a merc while none is chosen",
		viewer.merc_selector.tenure_label.text == MercSelector.ALL_HINT,
		"tenure '%s'" % viewer.merc_selector.tenure_label.text)
	var merc_tab_bottom: float = merc_tab.global_position.y + merc_tab.size.y
	TestFixtures.check(res, "the header row and the active Merc tab meet the chart edge",
		absf(header_bottom - chart_edge_top) <= 0.5
			and absf(merc_tab_bottom - chart_edge_top) <= 0.5,
		"header %.1f tab %.1f edge %.1f" % [header_bottom, merc_tab_bottom, chart_edge_top])
	seen["merc_all"] = viewer.left_panel.size.y
	viewer.merc_selector.select_uid(GameState.roster[0].uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a picked merc puts its tenure back on the caption",
		viewer.merc_selector.tenure_label.text
			== MercSelector.tenure_text(GameState.roster[0].uid),
		"tenure '%s'" % viewer.merc_selector.tenure_label.text)
	var defs: int = MetricList.defs_for("Merc").size()
	TestFixtures.check(res, "the metric list holds one toggle per Merc metric",
		viewer.metric_list.toggle_count() == defs,
		"expected %d toggles, got %d" % [defs, viewer.metric_list.toggle_count()])
	var active: Array[String] = viewer.metric_list.active_keys("Merc")
	TestFixtures.check(res, "two Merc metrics start plotted", active.size() == 2,
		"got %s" % str(active))
	TestFixtures.check(res, "the merc picker lists the whole roster",
		viewer.merc_selector.item_count() == GameState.roster.size(),
		"expected %d items, got %d" % [GameState.roster.size(), viewer.merc_selector.item_count()])
	TestFixtures.check(res, "the closed picker names the merc on show with its level line",
		viewer.merc_selector.name_label.text == GameState.roster[0].name
			and viewer.merc_selector.detail_text().begins_with("LVL "),
		"got '%s' and '%s'" % [viewer.merc_selector.name_label.text,
			viewer.merc_selector.detail_text()])
	viewer.merc_selector.level_label.text = "LVL 07"
	viewer.merc_selector.tradition_label.text = ""
	TestFixtures.check(res, "detail_text has no trailing space when the tradition is empty",
		viewer.merc_selector.detail_text() == "LVL 07",
		"got '%s'" % viewer.merc_selector.detail_text())
	var never_hired: int = GameState.roster[1].uid
	GameState.merc_by_uid(never_hired).hired_minute = -1
	TestFixtures.check(res, "tenure_text is empty for a merc without a hire minute",
		MercSelector.tenure_text(never_hired) == "",
		"got '%s'" % MercSelector.tenure_text(never_hired))
	viewer.merc_selector.rebuild()
	await host.get_tree().process_frame
	var no_tenure_row: Button = viewer.merc_selector.list.get_child(2) as Button
	var no_tenure_sub: Label = no_tenure_row.get_node("Line/Text/Sub") as Label
	TestFixtures.check(res, "the row sub line for that merc ends with the level, no trailing dash",
		no_tenure_sub.text == "LVL %02d" % GameState.roster[1].level,
		"got '%s'" % no_tenure_sub.text)


#The Merc list header, Show All and Hide All, the Contract groups and the one panel height across tabs.
static func _layout_merc_list(res: Dictionary, host: Node, viewer: MetricsViewer, seen: Dictionary) -> void:
	var guild_height: float = seen["guild"]
	var merc_all_height: float = seen["merc_all"]
	var defs: int = MetricList.defs_for("Merc").size()
	TestFixtures.check(res, "the list header names the source and counts the plotted metrics",
		viewer.list_head.caption_label.text == "Merc Data" and viewer.list_head.count_label.text == "2/%d" % defs,
		"got '%s' and '%s'" % [viewer.list_head.caption_label.text, viewer.list_head.count_label.text])
	viewer.show_all.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Show All plots every metric of the source",
		viewer.metric_list.active_keys("Merc").size() == defs and viewer.list_head.count_label.text
			== "%d/%d" % [defs, defs],
		"got %d on '%s'" % [viewer.metric_list.active_keys("Merc").size(), viewer.list_head.count_label.text])
	viewer.hide_all.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Hide All empties the chart and keeps the focused metric",
		viewer.metric_list.active_keys("Merc").is_empty() and viewer.chart.is_empty()
			and viewer.focused_key() != "",
		"got %d on '%s'" % [viewer.metric_list.active_keys("Merc").size(), viewer.focused_key()])
	TestFixtures.check(res, "the Merc list stands ungrouped",
		viewer.metric_list.group_count() == 0,
		"got %d headers" % viewer.metric_list.group_count())
	viewer.select_source("Contract")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Contract list carries the three group headers",
		viewer.metric_list.group_count() == 3,
		"got %d headers" % viewer.metric_list.group_count())
	var contract_height: float = viewer.left_panel.size.y
	viewer.select_source("Merc")
	await host.get_tree().process_frame
	viewer.merc_selector.select_uid(GameState.roster[0].uid)
	await host.get_tree().process_frame
	viewer.compare_button.pressed.emit()
	viewer.compare_selector.select_uid(GameState.roster[1].uid)
	await host.get_tree().process_frame
	var compare_height: float = viewer.left_panel.size.y
	TestFixtures.check(res,
		"the left panel keeps one height across every tab and with a comparison on",
		absf(guild_height - merc_all_height) <= 0.5 and absf(guild_height - contract_height) <= 0.5
			and absf(guild_height - compare_height) <= 0.5,
		"guild %.1f merc %.1f contract %.1f compare %.1f" % [guild_height, merc_all_height,
			contract_height, compare_height])


#The widened chart column against the plan size: the standalone chart holds 888 x 474, its whole
#rect stays inside the chart panel and inside the viewer with no overflow, and the embedded chart
#still takes the compact EMBED_CHART size regardless of the standalone size on the scene.
static func _case_chart_size(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open(host)
	TestFixtures.check(res, "the standalone chart takes the widened 888 x 474 size",
		viewer.chart.custom_minimum_size == Vector2(888, 474),
		"got %s" % str(viewer.chart.custom_minimum_size))
	var chart_rect: Rect2 = Rect2(viewer.chart.global_position, viewer.chart.size)
	var panel_rect: Rect2 = Rect2(viewer.chart_panel.global_position, viewer.chart_panel.size)
	var viewer_rect: Rect2 = Rect2(viewer.global_position, viewer.size)
	TestFixtures.check(res, "the chart's rect sits inside the chart panel with no overflow",
		panel_rect.encloses(chart_rect),
		"chart %s panel %s" % [str(chart_rect), str(panel_rect)])
	TestFixtures.check(res, "the chart's rect sits inside the standalone viewer with no overflow",
		viewer_rect.encloses(chart_rect),
		"chart %s viewer %s" % [str(chart_rect), str(viewer_rect)])
	viewer.queue_free()
	var embed: MetricsViewer = await _open(host)
	embed.lock_to_merc(GameState.roster[0].uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the embedded chart still takes the compact EMBED_CHART size",
		embed.chart.custom_minimum_size == MetricsViewer.EMBED_CHART and embed.chart.compact,
		"got %s compact %s" % [str(embed.chart.custom_minimum_size), embed.chart.compact])
	embed.queue_free()


static func _case_series(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open_merc(host)
	TestFixtures.check(res, "the seeded merc history fills both default series",
		viewer.chart.series_count() == 2 and viewer.chart.point_count(0) > 0,
		"got %d series and %d points" % [viewer.chart.series_count(), viewer.chart.point_count(0)])
	TestFixtures.check(res, "the merc title carries the picked merc name",
		viewer.title_label.text == "%s Metrics" % GameState.roster[0].name,
		"got '%s'" % viewer.title_label.text)
	viewer.select_source("Guild")
	await host.get_tree().process_frame
	var guild: int = MetricList.defs_for("Guild").size()
	TestFixtures.check(res, "the Guild tab rebuilds the list and retitles the chart",
		viewer.metric_list.toggle_count() == guild and viewer.title_label.text == "Guild Metrics",
		"got %d toggles and '%s'" % [viewer.metric_list.toggle_count(), viewer.title_label.text])
	TestFixtures.check(res, "the Guild series read the bare guild keys",
		viewer.stored_key("bank") == "bank"
			and _sum(MetricsHistory.series("Guild", "bank", 0, 1)) > 0.0,
		"got '%s'" % viewer.stored_key("bank"))
	var types: Array[String] = ContractLibrary.contract_type_names()
	viewer.select_source("Contract")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Contract tab shows the type picker opened on All",
		viewer.type_selector.visible and viewer.type_selector.current_type() == TypeSelector.ALL,
		"visible %s on '%s'" % [viewer.type_selector.visible, viewer.type_selector.current_type()])
	TestFixtures.check(res, "All reads the untyped contract totals",
		viewer.stored_key("count") == "count" and viewer.title_label.text == "All Contracts",
		"got '%s' and '%s'" % [viewer.stored_key("count"), viewer.title_label.text])
	if types.is_empty():
		TestFixtures.check(res, "the library names at least one contract type", false, "none found")
	else:
		viewer.type_selector.select_type(types[0])
		await host.get_tree().process_frame
		TestFixtures.check(res, "a picked type prefixes its own count series",
			viewer.stored_key("count") == "%s/count" % types[0]
				and viewer.title_label.text == "%s Contracts" % types[0]
				and viewer.chart.point_count(0) > 0,
			"got '%s', '%s' and %d points" % [viewer.stored_key("count"), viewer.title_label.text,
				viewer.chart.point_count(0)])
		var tagged: Array[Dictionary] = MetricsHistory.series("Contract", "%s/count" % types[0], 0, 1)
		TestFixtures.check(res, "the preview rows tag a type by its own name, not an index",
			_sum(tagged) > 0.0, "got %.1f for '%s/count'" % [_sum(tagged), types[0]])
		var last_type: String = types[types.size() - 1]
		var last_tagged: Array[Dictionary] = MetricsHistory.series("Contract",
			"%s/count" % last_type, 0, 1)
		TestFixtures.check(res, "seed_preview tags every library type, not only the first three",
			_sum(last_tagged) > 0.0, "got %.1f for '%s/count'" % [_sum(last_tagged), last_type])
	if types.size() >= 2:
		var one: Array[Dictionary] = MetricsHistory.series("Contract", "%s/count" % types[0], 0, 1)
		var two: Array[Dictionary] = MetricsHistory.series("Contract", "%s/count" % types[1], 0, 1)
		var both: Array[Dictionary] = MetricsHistory.combined_series("Contract", "count",
			[types[0], types[1]] as Array[String], 0, 1)
		TestFixtures.check(res, "a combined series adds the picked types bucket by bucket",
			both.size() == one.size() and _sum(one) > 0.0
				and is_equal_approx(_sum(both), _sum(one) + _sum(two)),
			"got %.1f against %.1f and %.1f" % [_sum(both), _sum(one), _sum(two)])
		viewer.type_selector.set_types([types[0], types[1]] as Array[String])
		await host.get_tree().process_frame
		TestFixtures.check(res, "two checked types drop the prefix and title the chart All",
			viewer.type_selector.selected_types().size() == 2
				and viewer.title_label.text == "All Contracts",
			"got %s on '%s'" % [str(viewer.type_selector.selected_types()),
				viewer.title_label.text])
		viewer.type_selector.select_type(types[0])
		await host.get_tree().process_frame
		TestFixtures.check(res, "the one type still checked cannot be unchecked",
			viewer.type_selector.option_disabled(0)
				and not viewer.type_selector.option_disabled(1),
			"got %s and %s" % [viewer.type_selector.option_disabled(0),
				viewer.type_selector.option_disabled(1)])
		viewer.type_selector.set_types([] as Array[String])
		await host.get_tree().process_frame
		TestFixtures.check(res, "an empty pick is refused and leaves the one type standing",
			viewer.type_selector.selected_types().size() == 1
				and viewer.type_selector.selected_types()[0] == types[0],
			"got %s" % str(viewer.type_selector.selected_types()))
	viewer.queue_free()


static func _case_chart(res: Dictionary, host: Node) -> void:
	var rising: Array[Dictionary] = _points(3, [1.0, 2.0, 3.0])
	var scaled: PackedFloat32Array = LineChart.normalize(rising, 100.0)
	TestFixtures.check(res, "normalize spans the full height between the low and the high",
		scaled.size() == 3 and is_equal_approx(scaled[0], 0.0) and is_equal_approx(scaled[1], 50.0)
			and is_equal_approx(scaled[2], 100.0), "got %s" % str(scaled))
	var flat: PackedFloat32Array = LineChart.normalize(_points(4, [7.0]), 100.0)
	TestFixtures.check(res, "a flat series draws at mid height",
		flat.size() == 4 and is_equal_approx(flat[0], 50.0) and is_equal_approx(flat[3], 50.0),
		"got %s" % str(flat))
	var near_right: int = LineChart.nearest_index(rising, 400.0, 400.0)
	var near_left: int = LineChart.nearest_index(rising, 0.0, 400.0)
	TestFixtures.check(res, "nearest_index picks the last point at the right edge",
		near_right == 2 and near_left == 0, "got %d and %d" % [near_right, near_left])
	var x_first: float = LineChart.x_for(0, 3, 400.0)
	var x_last: float = LineChart.x_for(2, 3, 400.0)
	var x_lone: float = LineChart.x_for(0, 1, 400.0)
	TestFixtures.check(res, "x_for spreads the points across the plot width",
		is_equal_approx(x_first, 0.0) and is_equal_approx(x_last, 400.0)
			and is_equal_approx(x_lone, 200.0),
		"got %.1f, %.1f and %.1f" % [x_first, x_last, x_lone])
	var band: Vector2 = LineChart.padded_range(_points(4, [7.0]))
	TestFixtures.check(res, "a flat series still gets a band to label",
		is_equal_approx(band.x, 6.0) and is_equal_approx(band.y, 8.0), "got %s" % str(band))
	var rows: Array[float] = LineChart.y_label_values(0.0, 8.0)
	TestFixtures.check(res, "the Y axis splits its band into five rows",
		rows.size() == 5 and is_equal_approx(rows[1], 2.0) and is_equal_approx(rows[4], 8.0),
		"got %s" % str(rows))
	TestFixtures.check(res, "the axis format shortens money, signs opinion and rounds counts",
		LineChart.axis_text(12345.0, "money", 4000.0) == "12.3k"
			and LineChart.axis_text(1.5, "op", 4.0) == "+1.5"
			and LineChart.axis_text(2.0, "int", 3.0) == "2.0"
			and LineChart.axis_text(2.0, "int", 10.0) == "2",
		"got '%s', '%s', '%s' and '%s'" % [LineChart.axis_text(12345.0, "money", 4000.0),
			LineChart.axis_text(1.5, "op", 4.0), LineChart.axis_text(2.0, "int", 3.0),
			LineChart.axis_text(2.0, "int", 10.0)])
	var viewer: MetricsViewer = await _open(host)
	var chart: LineChart = viewer.chart
	chart.hover_at(Vector2(chart.plot_rect().end.x, chart.plot_rect().get_center().y))
	TestFixtures.check(res, "hovering the right edge opens the tooltip on the last bucket",
		chart.tip.visible and chart.tip.title_label.text.begins_with("Day "),
		"visible %s on title '%s'" % [chart.tip.visible, chart.tip.title_label.text])
	TestFixtures.check(res, "the hover marks the bucket the crosshair stands on",
		chart.hovered_index() == chart.point_count(0) - 1,
		"got %d of %d" % [chart.hovered_index(), chart.point_count(0)])
	chart.hide_tip()
	TestFixtures.check(res, "leaving the plot drops the crosshair",
		chart.hovered_index() == -1 and not chart.tip.visible,
		"got %d and visible %s" % [chart.hovered_index(), chart.tip.visible])
	chart.set_series([] as Array[Dictionary])
	TestFixtures.check(res, "an empty chart says so instead of drawing",
		chart.is_empty() and chart.empty_label.visible
			and chart.empty_label.text == LineChart.EMPTY_TEXT,
		"visible %s on text '%s'" % [chart.empty_label.visible, chart.empty_label.text])
	viewer.queue_free()


#The Y button hands the axis and the header to one metric.
static func _case_focus(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open_merc(host)
	var defs: Array[MetricDef] = MetricList.defs_for("Merc")
	TestFixtures.check(res, "the Y axis opens on the first plotted metric",
		viewer.focused_key() == defs[0].key and viewer.chart.focused_key() == defs[0].key,
		"got '%s' and '%s'" % [viewer.focused_key(), viewer.chart.focused_key()])
	var index: int = viewer.metric_list.toggle_count() - 1
	var row: MetricToggle = viewer.metric_list.toggle_at(index)
	row.y_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Y button moves the axis and turns that metric on",
		viewer.focused_key() == row.key and viewer.chart.focused_key() == row.key
			and viewer.metric_list.active_keys("Merc").has(row.key) and row.is_focused_metric(),
		"got '%s' among %s" % [viewer.focused_key(),
			str(viewer.metric_list.active_keys("Merc"))])
	var points: Array[Dictionary] = MetricsHistory.series("Merc", viewer.stored_key(row.key),
		viewer.window_from(), MetricsPeriod.bucket_days(viewer.chart_scale), viewer.window_days())
	var band: Vector2 = LineChart.padded_range(points)
	var want: String = LineChart.axis_text(float(points[points.size() - 1]["value"]),
		defs[index].fmt, band.y - band.x)
	TestFixtures.check(res, "the chart header names the focused metric and its latest value",
		viewer.focus_label.text == row.label and viewer.now_value.text == want,
		"got '%s' and '%s' against '%s'" % [viewer.focus_label.text, viewer.now_value.text, want])
	TestFixtures.check(res, "the header range counts the buckets in the scale on show",
		viewer.range_label.text == "Week 1 - Week %d" % points.size(),
		"got '%s' for %d buckets" % [viewer.range_label.text, points.size()])
	viewer.hide_all.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "an empty chart says no metric is picked",
		viewer.focus_label.text == MetricsViewer.EMPTY_FOCUS
			and viewer.now_value.text == MetricsViewer.EMPTY_VALUE
			and viewer.range_label.text == "",
		"got '%s', '%s' and '%s'" % [viewer.focus_label.text, viewer.now_value.text,
			viewer.range_label.text])
	viewer.queue_free()


static func _case_lock(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open(host, LOCK_EXTRA)
	var uid: int = GameState.roster[2].uid
	viewer.lock_to_merc(uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the embed locks onto the merc it was given",
		viewer.locked_uid() == uid and viewer.current_uid() == uid,
		"got %d and %d for %d" % [viewer.locked_uid(), viewer.current_uid(), uid])
	TestFixtures.check(res, "the locked embed drops the tabs and the merc picker",
		not viewer.tabs.visible and not viewer.merc_selector.visible,
		"tabs %s and picker %s" % [viewer.tabs.visible, viewer.merc_selector.visible])
	TestFixtures.check(res, "the locked title names that merc",
		viewer.title_label.text == "%s Metrics" % GameState.roster[2].name,
		"got '%s'" % viewer.title_label.text)
	TestFixtures.check(res, "the locked embed takes the compact size",
		viewer.custom_minimum_size == MetricsViewer.EMBED_SIZE,
		"got %s" % str(viewer.custom_minimum_size))
	TestFixtures.check(res, "the locked embed still holds a focused metric",
		viewer.focused_key() == MetricList.defs_for("Merc")[0].key
			and viewer.chart.focused_key() == viewer.focused_key(),
		"got '%s' and '%s'" % [viewer.focused_key(), viewer.chart.focused_key()])
	TestFixtures.check(res, "the embedded viewer keeps its 14 px gap over the chart panel",
		viewer.panel_gap() == MetricsViewer.EMBED_GAP,
		"gap %d" % viewer.panel_gap())
	TestFixtures.check(res, "the embedded chart takes the compact plot size",
		viewer.chart.custom_minimum_size == MetricsViewer.EMBED_CHART and viewer.chart.compact,
		"got %s compact %s" % [str(viewer.chart.custom_minimum_size), viewer.chart.compact])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "one merc slot shuts the embed and still shows no LockedPage",
		viewer.graph_locked() and viewer.chart.series_count() == 0 and not viewer.chart.visible
			and not viewer.locked_page.visible,
		"locked %s, %d series, page %s" % [viewer.graph_locked(), viewer.chart.series_count(),
			viewer.locked_page.visible])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 2})
	await host.get_tree().process_frame
	TestFixtures.check(res, "two merc slots open the embed again",
		not viewer.graph_locked() and viewer.chart.visible and viewer.chart.series_count() == 2,
		"locked %s with %d series" % [viewer.graph_locked(), viewer.chart.series_count()])
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	viewer.queue_free()


static func _case_seed(res: Dictionary, host: Node) -> void:
	_fresh()
	await host.get_tree().process_frame
	MetricsHistory.seed_preview(SEED_DAYS)
	var indexed: Array[Dictionary] = MetricsHistory.series("Merc", "0/salary", 0, 1)
	TestFixtures.check(res, "seed_preview without uids keeps the preview index keys",
		indexed.size() == SEED_DAYS and _sum(indexed) > 0.0,
		"got %d points summing %.1f" % [indexed.size(), _sum(indexed)])
	var uid: int = GameState.roster[0].uid
	MetricsHistory.seed_preview(SEED_DAYS, [uid])
	var named: Array[Dictionary] = MetricsHistory.series("Merc", "%d/salary" % uid, 0, 1)
	TestFixtures.check(res, "seed_preview with uids writes the roster keys instead",
		named.size() == SEED_DAYS and _sum(named) > 0.0,
		"got %d points summing %.1f" % [named.size(), _sum(named)])
	TestFixtures.check(res, "the index key is gone once the uids are given",
		is_zero_approx(_sum(MetricsHistory.series("Merc", "0/salary", 0, 1))),
		"got %.1f" % _sum(MetricsHistory.series("Merc", "0/salary", 0, 1)))
	TestFixtures.check(res, "the seeded record starts at day zero",
		MetricsHistory.days() == SEED_DAYS and MetricsHistory.first_day() == 0,
		"got %d days from day %d" % [MetricsHistory.days(), MetricsHistory.first_day()])
	TestFixtures.check(res, "a seed switches the reader onto the preview store",
		MetricsHistory.using_preview(), "using_preview %s" % MetricsHistory.using_preview())
	MetricsHistory.record_day(0)
	MetricsHistory.record_day(1)
	TestFixtures.check(res, "a recorded day leaves the preview it was seeded with alone",
		MetricsHistory.days() == SEED_DAYS,
		"got %d preview days" % MetricsHistory.days())
	MetricsHistory.use_preview(false)
	TestFixtures.check(res, "the live store keeps the two recorded days of its own",
		MetricsHistory.days() == 2 and MetricsHistory.first_day() == 0,
		"got %d live days from day %d" % [MetricsHistory.days(), MetricsHistory.first_day()])
	MetricsHistory.clear_preview()
	TestFixtures.check(res, "clearing the preview drops it and stays on the live store",
		not MetricsHistory.using_preview() and MetricsHistory.days() == 2,
		"using_preview %s on %d days" % [MetricsHistory.using_preview(), MetricsHistory.days()])


#combined_series weighting: an AVG key with no "_n" columns is the plain mean of the per type
#values; the same key with "_n" columns present is the count weighted mean instead; a type the
#row does not carry adds no weight at all.
static func _case_combined_weight(res: Dictionary) -> void:
	var plain_rows := func(_day: int) -> Dictionary: return {"1/op": 2.0, "2/op": 4.0}
	var plain: Variant = _history("merc_source", plain_rows, 1)
	var plain_points: Array[Dictionary] = plain.combined_series("Merc", "op",
		["1", "2"] as Array[String], 0, 1)
	TestFixtures.check(res, "an AVG combine with no counts is the plain mean of the two values",
		is_equal_approx(float(plain_points[0]["value"]), 3.0),
		"got %.3f" % float(plain_points[0]["value"]))
	plain.free()
	var weighted_rows := func(_day: int) -> Dictionary:
		return {"1/op": 2.0, "1/op_n": 3.0, "2/op": 4.0, "2/op_n": 1.0}
	var weighted: Variant = _history("merc_source", weighted_rows, 1)
	var weighted_points: Array[Dictionary] = weighted.combined_series("Merc", "op",
		["1", "2"] as Array[String], 0, 1)
	TestFixtures.check(res, "an AVG combine with counts present is the count weighted mean",
		is_equal_approx(float(weighted_points[0]["value"]), 2.5),
		"got %.3f" % float(weighted_points[0]["value"]))
	weighted.free()
	var partial_rows := func(_day: int) -> Dictionary: return {"1/op": 2.0}
	var partial: Variant = _history("merc_source", partial_rows, 1)
	var partial_points: Array[Dictionary] = partial.combined_series("Merc", "op",
		["1", "2"] as Array[String], 0, 1)
	TestFixtures.check(res, "an AVG combine skips a type the row does not carry",
		is_equal_approx(float(partial_points[0]["value"]), 2.0),
		"got %.3f" % float(partial_points[0]["value"]))
	partial.free()


#EVENT_AVG combines through the stored "<key>_n" day counts, not a per row weight of 1.0; a bucket
#that carries no counts repeats the previous bucket's value instead of dividing by row count.
static func _case_event_avg_carry(res: Dictionary) -> void:
	var rows: Array[Dictionary] = [
		{"1/diff": 4.0, "1/diff_n": 1.0},
		{"1/diff": 5.0},
	]
	var by_day := func(day: int) -> Dictionary: return rows[day]
	var history: Variant = _history("contract_source", by_day, 2)
	var points: Array[Dictionary] = history.combined_series("Contract", "diff",
		["1"] as Array[String], 0, 1)
	TestFixtures.check(res,
		"a combined EVENT_AVG bucket with no counts carries the previous value forward",
		points.size() == 2 and is_equal_approx(float(points[0]["value"]), 4.0)
			and is_equal_approx(float(points[1]["value"]), 4.0),
		"got %s" % str(points))
	history.free()


#A stand-alone MetricsHistory fed by one source and recorded over the given days; the caller frees it.
static func _history(source: String, rows: Callable, days: int) -> Variant:
	var history: Variant = load(HISTORY_PATH).new()
	history.set(source, rows)
	for day: int in days:
		history.record_day(day)
	return history


#One key laid over the derived table, built without a literal so the key can be a variable.
static func _one(key: String, value: Variant) -> Dictionary:
	var out: Dictionary = {}
	out[key] = value
	return out


#Whether the lock a metrics key stands behind reports itself shut, read through MetricsLocks only.
static func _lock_shut(camel: String) -> bool:
	if camel == MetricsLocks.CONTRACT_KEY:
		return MetricsLocks.graph_locked("Contract")
	if camel == MetricsLocks.MERC_KEY:
		return MetricsLocks.graph_locked("Merc")
	if camel == MetricsLocks.CLIENT_KEY:
		return MetricList.locked_key("Guild", "cop")
	return MetricList.locked_key("Guild", "mop")


#Either spelling of a metrics entitlement shuts the lock it names: set_entitlements lays the other
#spelling of the pair down as well and MetricsLocks reads the camel key first.
static func _case_override_spellings(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	var rows: Array[Array] = [
		[MetricsLocks.CONTRACT_KEY, MetricsLocks.CONTRACT_SNAKE, "the contract graph"],
		[MetricsLocks.MERC_KEY, MetricsLocks.MERC_SNAKE, "the merc graph"],
		[MetricsLocks.SURVEY_KEY, "guild_opinion", "the guild opinion row"],
		[MetricsLocks.CLIENT_KEY, "client_opinion", "the client opinion row"],
	]
	for row: Array in rows:
		var spellings: Array[String] = [String(row[0]), String(row[1])]
		for key: String in spellings:
			SubscriptionManager.set_entitlements(_one(key, 0))
			TestFixtures.check(res, "an override on %s shuts %s" % [key, String(row[2])],
				_lock_shut(String(row[0])), "the lock stayed open")
			SubscriptionManager.max_out()
	SubscriptionManager.set_entitlements(_one(MetricsLocks.MERC_KEY, 0))
	TestFixtures.check(res, "a camel override reaches the snake reader of the slot count",
		SubscriptionManager.merc_slots() == 0 and MetricsLocks.merc_slots() == 0,
		"%d slots" % SubscriptionManager.merc_slots())
	SubscriptionManager.max_out()


#The subscription stub: phase one opens every metrics screen and three merc slots, and the slot
#count decides whether the comparison picker is offered at all.
static func _case_entitlements(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var viewer: MetricsViewer = await _open_merc(host)
	var held: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "phase one pays for the guild, contract and merc metrics",
		bool(held.get("metrics", false)) and bool(held.get("contract_metrics", false))
			and SubscriptionManager.merc_slots() == 3,
		"got %s" % str(held))
	TestFixtures.check(res, "three slots offer the comparison button on a picked merc",
		viewer.compare_button.visible, "visible %s" % viewer.compare_button.visible)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "one slot takes the comparison button and the merc pick away",
		SubscriptionManager.merc_slots() == 1 and not viewer.compare_button.visible
			and viewer.current_uid() == -1,
		"got %d slots, visible %s on %d" % [SubscriptionManager.merc_slots(),
			viewer.compare_button.visible, viewer.current_uid()])
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	viewer.merc_selector.select_uid(GameState.roster[0].uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "max_out hands the three slots and the button back",
		SubscriptionManager.merc_slots() == 3 and viewer.compare_button.visible,
		"got %d slots, visible %s" % [SubscriptionManager.merc_slots(),
			viewer.compare_button.visible])
	viewer.queue_free()


#The two metrics the design prototype adds: the guild investment portfolio and the merc vacation days.
static func _case_new_metrics(res: Dictionary, host: Node) -> void:
	_fresh()
	await host.get_tree().process_frame
	MetricsHistory.seed_preview(LONG_DAYS, _uids())
	var guild: Array[MetricDef] = MetricList.defs_for("Guild")
	var merc: Array[MetricDef] = MetricList.defs_for("Merc")
	TestFixtures.check(res, "the Guild list carries seven metrics and the Merc list ten",
		guild.size() == 7 and merc.size() == 10,
		"got %d guild and %d merc defs" % [guild.size(), merc.size()])
	var port: MetricDef = _def(guild, "port")
	TestFixtures.check(res, "the portfolio is guild money read at the bucket's last day, off by default",
		port != null and port.source == "Guild" and port.agg == "LAST" and port.fmt == "money"
			and not port.default_on,
		"got %s" % ("nothing" if port == null else "%s %s %s" % [port.source, port.agg, port.fmt]))
	var vac: MetricDef = _def(merc, "vac")
	TestFixtures.check(res, "the vacation days are a merc count added over the bucket, off by default",
		vac != null and vac.source == "Merc" and vac.agg == "SUM" and vac.fmt == "int"
			and not vac.default_on,
		"got %s" % ("nothing" if vac == null else "%s %s %s" % [vac.source, vac.agg, vac.fmt]))
	var days_off: float = 0.0
	for uid: int in MetricsHistory.merc_uids():
		days_off += _sum(MetricsHistory.series("Merc", "%d/vac" % uid, 0, 1))
	TestFixtures.check(res, "the seeded history sends the roster on holiday",
		days_off > 0.0, "got %.1f vacation days over %d mercs" % [days_off,
			MetricsHistory.merc_uids().size()])
	var port_points: Array[Dictionary] = MetricsHistory.series("Guild", "port", 0, 1)
	TestFixtures.check(res, "the seeded history carries a portfolio value per day",
		port_points.size() == LONG_DAYS and _sum(port_points) > 0.0,
		"got %d points summing %.1f" % [port_points.size(), _sum(port_points)])
	MetricsHistory.use_preview(false)
	MetricsHistory.clear()
	MetricsHistory.record_day(0)
	var live: Array[Dictionary] = MetricsHistory.series("Guild", "port", 0, 1)
	TestFixtures.check(res, "the live campaign records a flat portfolio while nothing invests yet",
		live.size() == 1 and is_zero_approx(float(live[0]["value"])),
		"got %s" % str(live))
	MetricsHistory.clear_preview()


#The team average line: the mean over the mercs the record had hired in each bucket.
static func _case_team_average(res: Dictionary, host: Node) -> void:
	_fresh()
	TestFixtures.add_mercs(MetricsHistory.EMPLOYMENT.size() - GameState.mercs.size())
	await host.get_tree().process_frame
	MetricsHistory.seed_preview(PREVIEW_DAYS, _uids())
	var uids: Array[int] = MetricsHistory.merc_uids()
	var roster: Array[int] = _uids()
	roster.sort()
	TestFixtures.check(res, "merc_uids reads back every uid the record carries",
		uids == roster, "got %s against %s" % [str(uids), str(roster)])
	var team: Array[Dictionary] = MetricsHistory.team_average("level", 0, 1)
	var want: float = 0.0
	var seen: int = 0
	for uid: int in uids:
		if MetricsHistory.hire_day(uid) != 0:
			continue
		var rows: Array[Dictionary] = MetricsHistory.series("Merc", "%d/level" % uid, 0, 1)
		want += float(rows[0]["value"])
		seen += 1
	TestFixtures.check(res, "the first bucket averages the mercs already on the books",
		team.size() == PREVIEW_DAYS and seen > 0
			and is_equal_approx(float(team[0]["value"]), want / float(seen)),
		"got %.3f against %.3f over %d mercs" % [float(team[0]["value"]),
			want / float(maxi(1, seen)), seen])
	var late_rows := func(day: int) -> Dictionary:
		var row: Dictionary = {"1/salary": 100.0}
		if day >= 3:
			row["7/salary"] = 200.0
		return row
	var late: Variant = _history("merc_source", late_rows, 5)
	TestFixtures.check(res, "hire_day names the first day a merc drew a wage",
		late.hire_day(1) == 0 and late.hire_day(7) == 3 and late.hire_day(9) == -1,
		"got %d, %d and %d" % [late.hire_day(1), late.hire_day(7), late.hire_day(9)])
	var mixed: Array[Dictionary] = late.team_average("salary", 0, 1)
	TestFixtures.check(res, "a merc joins the average on the bucket the guild hired them in",
		is_equal_approx(float(mixed[0]["value"]), 100.0)
			and is_equal_approx(float(mixed[3]["value"]), 150.0),
		"got %.1f and %.1f" % [float(mixed[0]["value"]), float(mixed[3]["value"])])
	var one: Array[Dictionary] = late.team_average("salary", 0, 1, 1)
	TestFixtures.check(res, "a bucket with nobody hired yet stays blank",
		is_nan(float(one[0]["value"])) and is_nan(float(one[2]["value"]))
			and is_equal_approx(float(one[4]["value"]), 200.0),
		"got %s" % str(one))
	late.free()


#Show Averages and Merc Comparison: the ghost line, the switch lock and the arrows.
static func _case_averages_and_compare(res: Dictionary, host: Node) -> void:
	SubscriptionManager.max_out()
	var viewer: MetricsViewer = await _open(host)
	viewer.select_source("Merc")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Merc tab opens on All Mercs and reads the team keys",
		viewer.current_uid() == -1 and viewer.stored_key("salary") == "team/salary"
			and viewer.list_head.caption_label.text == String(MetricsViewer.LIST_TITLES["Merc"])
			and viewer.merc_selector.name_label.text == MercSelector.ALL_NAME,
		"got %d, '%s' and '%s'" % [viewer.current_uid(), viewer.stored_key("salary"),
			viewer.list_head.caption_label.text])
	TestFixtures.check(res, "All Mercs still plots the two default series",
		viewer.chart.series_count() == 2 and viewer.chart.point_count(0) > 0,
		"got %d series and %d points" % [viewer.chart.series_count(),
			viewer.chart.point_count(0)])
	TestFixtures.check(res, "the averages switch locks while no single merc is picked",
		viewer.show_averages.visible and viewer.show_averages.disabled
			and viewer.show_averages.tooltip_text == ShowAveragesToggle.TIP_NO_MERC
			and viewer.ghost_count() == 0,
		"disabled %s on '%s' with %d ghosts" % [viewer.show_averages.disabled,
			viewer.show_averages.tooltip_text, viewer.ghost_count()])
	viewer.merc_selector.select_uid(GameState.roster[0].uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "picking a merc opens the switch and draws no ghost yet",
		not viewer.show_averages.disabled and not viewer.averages_on()
			and viewer.ghost_count() == 0,
		"disabled %s, on %s, %d ghosts" % [viewer.show_averages.disabled, viewer.averages_on(),
			viewer.ghost_count()])
	viewer.show_averages.set_pressed(true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "Show Averages lays a team line under every plotted metric",
		viewer.averages_on() and viewer.ghost_count() == viewer.chart.series_count()
			and viewer.chart.ghost_points(0) == viewer.chart.point_count(0),
		"%d ghosts of %d series, %d ghost points against %d" % [viewer.ghost_count(),
			viewer.chart.series_count(), viewer.chart.ghost_points(0),
			viewer.chart.point_count(0)])
	var focus_row: MetricToggle = viewer.metric_list.toggle_at(0)
	var off_row: MetricToggle = viewer.metric_list.toggle_at(
		viewer.metric_list.toggle_count() - 1)
	TestFixtures.check(res, "a plotted row reads its arrow off the pair and an unplotted one has none",
		focus_row.arrow.visible == focus_row.compare_visible() and not off_row.button_pressed
			and not off_row.arrow.visible,
		"focus %s, off %s" % [focus_row.arrow.visible, off_row.arrow.visible])
	viewer.compare_button.pressed.emit()
	viewer.compare_selector.select_uid(GameState.roster[1].uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a second merc takes the ghost over and puts the averages away",
		viewer.comparing() and viewer.compare_uid() == GameState.roster[1].uid
			and not viewer.averages_on() and viewer.show_averages.disabled
			and viewer.show_averages.tooltip_text == ShowAveragesToggle.TIP_COMPARING
			and viewer.ghost_count() == viewer.chart.series_count(),
		"comparing %s with %d, averages %s, %d ghosts" % [viewer.comparing(),
			viewer.compare_uid(), viewer.averages_on(), viewer.ghost_count()])
	var compare_pick: MercSelector = viewer.compare_selector
	var compare_tenure: Label = compare_pick.tenure_label
	var compare_end: float = compare_pick.global_position.y + compare_pick.size.y
	var compare_label_end: float = compare_tenure.global_position.y + compare_tenure.size.y
	TestFixtures.check(res, "the compare box holds its whole caption",
		compare_label_end <= compare_end + 0.5
			and compare_tenure.text != "",
		"label %.1f box %.1f '%s'" % [compare_label_end, compare_end,
		compare_tenure.text])
	var merc_pick: MercSelector = viewer.merc_selector
	var merc_tenure: Label = merc_pick.tenure_label
	var merc_end: float = merc_pick.global_position.y + merc_pick.size.y
	var merc_label_end: float = merc_tenure.global_position.y + merc_tenure.size.y
	TestFixtures.check(res, "the merc picker holds its whole caption",
		merc_label_end <= merc_end + 0.5 and merc_tenure.text != "",
		"label %.1f box %.1f '%s'" % [merc_label_end, merc_end,
		merc_tenure.text])
	var merc_popup: Rect2i = merc_pick.popup_rect()
	var compare_popup: Rect2i = compare_pick.popup_rect()
	var merc_rect: Rect2 = merc_pick.get_global_rect()
	TestFixtures.check(res, "the first merc's popup opens under its own button while comparing",
		merc_popup.position.x == int(merc_rect.position.x)
			and merc_popup.position.y == int(merc_rect.end.y)
			and merc_popup.position.y < compare_popup.position.y,
		"merc %s compare %s button %s" % [str(merc_popup), str(compare_popup), str(merc_rect)])
	TestFixtures.check(res, "neither popup stands narrower than the rows it holds",
		float(merc_popup.size.x) >= merc_pick.list.get_combined_minimum_size().x
			and float(compare_popup.size.x) >= compare_pick.list.get_combined_minimum_size().x,
		"merc %d compare %d" % [merc_popup.size.x, compare_popup.size.x])
	TestFixtures.check(res, "the comparison picker leaves the merc on show out of its rows",
		viewer.compare_selector.item_count() == GameState.roster.size() - 1
			and viewer.compare_selector.exclude_uid == GameState.roster[0].uid,
		"got %d rows excluding %d" % [viewer.compare_selector.item_count(),
			viewer.compare_selector.exclude_uid])
	viewer.compare_button.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "dropping the comparison gives the switch its own state back",
		not viewer.comparing() and viewer.compare_uid() == -1 and viewer.averages_on()
			and not viewer.show_averages.disabled
			and viewer.ghost_count() == viewer.chart.series_count(),
		"comparing %s, averages %s, %d ghosts" % [viewer.comparing(), viewer.averages_on(),
			viewer.ghost_count()])
	viewer.merc_selector.select_uid(-1)
	await host.get_tree().process_frame
	TestFixtures.check(res, "going back to All Mercs drops the ghosts and locks the switch again",
		viewer.current_uid() == -1 and viewer.ghost_count() == 0
			and viewer.show_averages.disabled,
		"got %d ghosts with the switch disabled %s" % [viewer.ghost_count(),
			viewer.show_averages.disabled])
	viewer.queue_free()


#The arrow a row draws: which way it points, how far off it counts as a swing and what a blank
#bucket does to it.
static func _case_arrow_math(res: Dictionary) -> void:
	var rise: float = MetricToggle.compare_pct(110.0, 100.0)
	var fall: float = MetricToggle.compare_pct(90.0, 100.0)
	TestFixtures.check(res, "a value over its reference reads that rise as a percentage",
		is_equal_approx(rise, 10.0) and is_equal_approx(fall, -10.0),
		"got %.2f and %.2f" % [rise, fall])
	var kind_mild: int = MetricToggle.arrow_kind(10.0)
	var kind_up: int = MetricToggle.arrow_kind(20.0)
	var kind_down: int = MetricToggle.arrow_kind(-20.0)
	TestFixtures.check(res, "a swing of fifteen percent or more straightens the arrow",
		kind_mild == 1 and kind_up == 2 and kind_down == 2,
		"got %d, %d and %d" % [kind_mild, kind_up, kind_down])
	var kind_tiny: int = MetricToggle.arrow_kind(0.4)
	var kind_blank: int = MetricToggle.arrow_kind(NAN)
	TestFixtures.check(res, "a gap under half a percent draws no arrow at all",
		kind_tiny == 0 and kind_blank == 0, "got %d and %d" % [kind_tiny, kind_blank])
	var id_up: String = MetricToggle.arrow_id(2, true)
	var id_down: String = MetricToggle.arrow_id(2, false)
	var id_diag_up: String = MetricToggle.arrow_id(1, true)
	var id_diag_down: String = MetricToggle.arrow_id(1, false)
	TestFixtures.check(res, "each arrow kind names its atlas id and nothing flips",
		id_up == "trend_up" and id_down == "trend_down" and id_diag_up == "trend_diag_up"
			and id_diag_down == "trend_diag_down" and MetricToggle.arrow_id(0, true) == "",
		"'%s', '%s', '%s' and '%s'" % [id_up, id_down, id_diag_up, id_diag_down])
	var zero_up: float = MetricToggle.compare_pct(5.0, 0.0)
	var zero_down: float = MetricToggle.compare_pct(-5.0, 0.0)
	var zero_flat: float = MetricToggle.compare_pct(0.0, 0.0)
	TestFixtures.check(res, "a zero reference reads a full hundred either way",
		is_equal_approx(zero_up, 100.0) and is_equal_approx(zero_down, -100.0)
			and is_zero_approx(zero_flat),
		"got %.1f, %.1f and %.1f" % [zero_up, zero_down, zero_flat])
	var blank_value: float = MetricToggle.compare_pct(NAN, 100.0)
	var blank_ref: float = MetricToggle.compare_pct(1.0, NAN)
	TestFixtures.check(res, "a blank bucket on either side carries no comparison",
		is_nan(blank_value) and is_nan(blank_ref), "got %.1f and %.1f" % [blank_value, blank_ref])


#The X axis captions: the bucket name with a one based count, thinned to fit the plot width.
static func _case_x_labels(res: Dictionary) -> void:
	TestFixtures.check(res, "a caption names the bucket and counts from one",
		LineChart.x_label("Week", 0) == "Week 1" and LineChart.x_label("Day", 11) == "Day 12",
		"got '%s' and '%s'" % [LineChart.x_label("Week", 0), LineChart.x_label("Day", 11)])
	TestFixtures.check(res, "the wide axis steps off eight captions and the compact one five",
		LineChart.label_step(40, false) == 5 and LineChart.label_step(40, true) == 8,
		"got %d and %d" % [LineChart.label_step(40, false), LineChart.label_step(40, true)])
	TestFixtures.check(res, "a handful of buckets names every one of them",
		LineChart.label_step(3, false) == 1 and LineChart.label_step(1, true) == 1,
		"got %d and %d" % [LineChart.label_step(3, false), LineChart.label_step(1, true)])


#The Period and Scale dropdowns: the window a period cuts out of the record, the snap that keeps
#the guild's pick, the rows a short window shuts and the count since a merc's hire day.
static func _case_window(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open_merc(host)
	TestFixtures.check(res, "All Time reaches back over the whole record",
		viewer.period == MetricsPeriod.Period.ALL_TIME and viewer.span_days() == PREVIEW_DAYS
			and viewer.window_from() == 0 and viewer.window_days() == PREVIEW_DAYS,
		"span %d, from %d for %d" % [viewer.span_days(), viewer.window_from(),
			viewer.window_days()])
	var open_scales: Array[int] = MetricsPeriod.valid_scales(viewer.span_days())
	var short_set: Array[int] = [MetricsPeriod.Scale.DAY, MetricsPeriod.Scale.WEEK]
	TestFixtures.check(res, "a window of 120 days opens Days and Weeks only and shows Weeks",
		_same(open_scales, short_set) and viewer.chart_scale == MetricsPeriod.Scale.WEEK
			and viewer.wanted_scale() == MetricsPeriod.Scale.MONTH
			and viewer.scale_drop.button_text() == "Weeks",
		"scales %s, shown %d, wanted %d" % [str(open_scales), viewer.chart_scale,
			viewer.wanted_scale()])
	TestFixtures.check(res, "the Weeks bucket holds twelve Trynn weeks of the preview",
		viewer.chart.point_count(0) == 12 and viewer.range_label.text == "Week 1 - Week 12",
		"%d buckets under '%s'" % [viewer.chart.point_count(0), viewer.range_label.text])
	var count: int = viewer.chart.point_count(0)
	var step: int = LineChart.label_step(count, false)
	var labels: Array[String] = viewer.chart.x_labels()
	var want: int = int(ceilf(float(count) / float(step)))
	TestFixtures.check(res, "the X axis names the bucket on show and steps it off to fit",
		labels.size() == want and labels[0] == "Week 1"
			and labels[labels.size() - 1] == "Week %d" % ((want - 1) * step + 1),
		"got %s" % str(labels))
	TestFixtures.check(res, "every bucket takes its size from the record's own calendar",
		MetricsPeriod.bucket_days(MetricsPeriod.Scale.DAY) == 1
			and MetricsPeriod.bucket_days(MetricsPeriod.Scale.WEEK) == MetricsHistory.DAYS_PER_WEEK
			and MetricsPeriod.bucket_days(MetricsPeriod.Scale.MONTH)
				== MetricsHistory.DAYS_PER_MONTH
			and MetricsPeriod.bucket_days(MetricsPeriod.Scale.QUARTER)
				== MetricsHistory.DAYS_PER_QUARTER,
		"got %s" % str(MetricsPeriod.BUCKET_DAYS))
	viewer.set_chart_scale(MetricsPeriod.Scale.DAY)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Days scale plots one point for every recorded day",
		viewer.chart_scale == MetricsPeriod.Scale.DAY
			and viewer.wanted_scale() == MetricsPeriod.Scale.DAY
			and viewer.chart.point_count(0) == PREVIEW_DAYS
			and viewer.scale_drop.button_text() == "Days"
			and viewer.range_label.text == "Day 1 - Day %d" % PREVIEW_DAYS,
		"%d points under '%s'" % [viewer.chart.point_count(0), viewer.range_label.text])
	viewer.scale_drop.open_popup()
	await host.get_tree().process_frame
	var month_row: Button = viewer.scale_drop.row_for(
		MetricsPeriod.scale_key(MetricsPeriod.Scale.MONTH))
	var quarter_row: Button = viewer.scale_drop.row_for(
		MetricsPeriod.scale_key(MetricsPeriod.Scale.QUARTER))
	TestFixtures.check(res, "a scale the window cannot carry hands its reason to the row tooltip",
		month_row != null and quarter_row != null
			and month_row.tooltip_text == MetricsPeriod.REASON_MONTH
			and quarter_row.tooltip_text == MetricsPeriod.REASON_QUARTER,
		"month '%s' quarter '%s'" % ["" if month_row == null else month_row.tooltip_text,
			"" if quarter_row == null else quarter_row.tooltip_text])
	if month_row != null:
		month_row.pressed.emit()
		await host.get_tree().process_frame
	TestFixtures.check(res, "pressing a shut row leaves the scale where it stood",
		viewer.chart_scale == MetricsPeriod.Scale.DAY
			and viewer.wanted_scale() == MetricsPeriod.Scale.DAY,
		"shown %d wanted %d" % [viewer.chart_scale, viewer.wanted_scale()])
	viewer.scale_drop.close_popup()
	viewer.set_period(MetricsPeriod.Period.M6)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a period longer than the record reads the record and no further",
		viewer.span_days() == PREVIEW_DAYS and viewer.window_days() == PREVIEW_DAYS
			and viewer.window_from() == 0 and viewer.period_drop.button_text() == "6m",
		"span %d under '%s'" % [viewer.span_days(), viewer.period_drop.button_text()])
	viewer.set_period(MetricsPeriod.Period.YTD)
	await host.get_tree().process_frame
	var ytd: int = mini(PREVIEW_DAYS, MetricsPeriod.year_day(GameState.day()))
	TestFixtures.check(res, "YTD cuts the window to the days passed in the Trynn year",
		viewer.span_days() == ytd and viewer.window_days() == ytd
			and viewer.window_from() == PREVIEW_DAYS - ytd,
		"span %d against %d from %d" % [viewer.span_days(), ytd, viewer.window_from()])
	viewer.set_period(MetricsPeriod.Period.ALL_TIME)
	await host.get_tree().process_frame
	var late_uid: int = -1
	var late_hire: int = 0
	for view: MercView in GameState.roster:
		var hire: int = MetricsHistory.hire_day(view.uid)
		if hire > late_hire:
			late_hire = hire
			late_uid = view.uid
	TestFixtures.check(res, "the preview hires part of the roster after the record opens",
		late_uid >= 0 and late_hire > 0, "latest hire day %d" % late_hire)
	if late_uid >= 0:
		viewer.merc_selector.select_uid(late_uid)
		await host.get_tree().process_frame
		TestFixtures.check(res, "one merc on show counts their history from the hire day",
			viewer.start_row() == late_hire
				and viewer.available_days() == PREVIEW_DAYS - late_hire
				and viewer.span_days() == PREVIEW_DAYS - late_hire
				and viewer.window_from() == late_hire,
			"hire %d, start %d, span %d, from %d" % [late_hire, viewer.start_row(),
				viewer.span_days(), viewer.window_from()])
	viewer.select_source("Guild")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the guild graph counts from the first recorded day again",
		viewer.start_row() == 0 and viewer.span_days() == PREVIEW_DAYS
			and viewer.window_from() == 0,
		"start %d span %d" % [viewer.start_row(), viewer.span_days()])
	viewer.queue_free()


#The three graphs against the plan that pays for them: a shut graph plots nothing, locks its tab,
#dims both dropdowns and takes a LockedPage over the chart area.
static func _case_graph_locks(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open(host)
	SubscriptionManager.set_state(SubscriptionManager.Plan.FREE, {})
	await host.get_tree().process_frame
	var guild_tab: TabButton = viewer.tabs.button(&"Guild")
	var shut_tab: TabButton = viewer.tabs.button(&"Contract")
	TestFixtures.check(res, "the free plan shuts all three graphs and locks every tab",
		viewer.graph_locked() and viewer.tabs.button(&"Guild").locked
			and viewer.tabs.button(&"Contract").locked and viewer.tabs.button(&"Merc").locked
			and guild_tab != null and guild_tab.locked,
		"guild %s contract %s merc %s" % [viewer.tabs.button(&"Guild").locked,
			viewer.tabs.button(&"Contract").locked, viewer.tabs.button(&"Merc").locked])
	TestFixtures.check(res, "a locked tab carries the lock over its icon and reads Locked",
		guild_tab != null and guild_tab.lock_overlay.visible
			and guild_tab.tooltip_text == MetricsViewer.LOCKED_TIP
			and guild_tab.icon_rect.tint == MetricsViewer.LOCKED_TINT
			and guild_tab.idle_mode == Icons.MODE_GRAY
			and shut_tab != null and shut_tab.icon_rect.mode == Icons.MODE_GRAY,
		"overlay %s tip '%s' tint %s idle %s shut %s" % [guild_tab.lock_overlay.visible,
			guild_tab.tooltip_text, str(guild_tab.icon_rect.tint), guild_tab.idle_mode,
			shut_tab.icon_rect.mode])
	TestFixtures.check(res, "every lock in the viewer takes its atlas size",
		FeatureLock.ICON_SCALE == 2
			and viewer.compare_lock.lock_icon.custom_minimum_size == Vector2(16, 18)
			and LockedPage.ICON_SCALE == 6
			and viewer.locked_page.lock_icon.custom_minimum_size == Vector2(48, 54)
			and FeatureLockDialog.ICON_SCALE == 6,
		"row %s page %s" % [str(viewer.compare_lock.lock_icon.custom_minimum_size),
			str(viewer.locked_page.lock_icon.custom_minimum_size)])
	TestFixtures.check(res, "a shut graph plots nothing and draws no axes",
		viewer.chart.series_count() == 0 and not viewer.chart.visible,
		"%d series, visible %s" % [viewer.chart.series_count(), viewer.chart.visible])
	TestFixtures.check(res, "the standalone viewer takes a LockedPage naming the guild graph",
		viewer.locked_page.visible and viewer.locked_page.feature == "Guild Metrics"
			and viewer.locked_page.line2_label.text
				== "Upgrade to Mercday Pro to view Guild Metrics.",
		"visible %s under '%s'" % [viewer.locked_page.visible,
			viewer.locked_page.line2_label.text])
	TestFixtures.check(res, "both dropdowns fall to the disabled shade and read Locked",
		viewer.period_drop.disabled and viewer.scale_drop.disabled
			and is_equal_approx(viewer.period_drop.modulate.a, OptionDropdown.DISABLED_ALPHA)
			and is_equal_approx(viewer.scale_drop.modulate.a, OptionDropdown.DISABLED_ALPHA)
			and viewer.scale_drop.toggle.tooltip_text == OptionDropdown.LOCKED_TOOLTIP,
		"alpha %.2f tip '%s'" % [viewer.period_drop.modulate.a,
			viewer.scale_drop.toggle.tooltip_text])
	TestFixtures.check(res, "Take Me There aims at the Plans tab while the plan itself falls short",
		String(viewer.locked_page.target().get("tab", "")) == "plans",
		"got %s" % str(viewer.locked_page.target()))
	SubscriptionManager.set_state(SubscriptionManager.Plan.PRO, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "an open tab reads its icon back at full white",
		guild_tab.icon_rect.tint == Color.WHITE and not guild_tab.locked,
		"tint %s locked %s" % [str(guild_tab.icon_rect.tint), guild_tab.locked])
	TestFixtures.check(res, "the Pro plan opens the guild graph and leaves the other two shut",
		not viewer.graph_locked() and viewer.chart.visible and viewer.chart.series_count() == 2
			and not viewer.locked_page.visible and not viewer.period_drop.disabled
			and not viewer.scale_drop.disabled and not viewer.tabs.button(&"Guild").locked
			and viewer.tabs.button(&"Contract").locked and viewer.tabs.button(&"Merc").locked,
		"locked %s with %d series" % [viewer.graph_locked(), viewer.chart.series_count()])
	viewer.select_source("Contract")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the contract graph names its own feature and the Enterprise plan",
		viewer.graph_locked() and viewer.locked_page.visible
			and viewer.locked_page.feature == "Contract Metrics"
			and viewer.locked_page.plan == "Mercday Enterprise"
			and viewer.chart.series_count() == 0 and viewer.scale_drop.disabled,
		"'%s' on '%s' with %d series" % [viewer.locked_page.feature, viewer.locked_page.plan,
			viewer.chart.series_count()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"contractmetrics": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "the contract upgrade opens that graph on its own",
		not viewer.graph_locked() and viewer.chart.series_count() > 0
			and not viewer.locked_page.visible and not viewer.tabs.button(&"Contract").locked
			and viewer.tabs.button(&"Merc").locked,
		"locked %s with %d series" % [viewer.graph_locked(), viewer.chart.series_count()])
	viewer.select_source("Merc")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the merc graph asks for the first tier of its own upgrade",
		viewer.graph_locked() and viewer.locked_page.visible
			and viewer.locked_page.feature == MetricsLocks.MERC_FEATURE
			and viewer.locked_page.upgrade_id == MetricsLocks.MERC_UPGRADE_ID
			and viewer.locked_page.tier == 1
			and viewer.locked_page.tiers == MetricsLocks.MERC_TIERS,
		"'%s' tier %d of %d" % [viewer.locked_page.feature, viewer.locked_page.tier,
			viewer.locked_page.tiers])
	TestFixtures.check(res, "Take Me There aims at the upgrade once Enterprise is already paid",
		String(viewer.locked_page.target().get("tab", "")) == "customize"
			and String(viewer.locked_page.target().get("upgrade", ""))
				== MetricsLocks.MERC_UPGRADE_ID,
		"got %s" % str(viewer.locked_page.target()))
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a full plan opens every graph and hands both dropdowns back",
		not viewer.graph_locked() and viewer.chart.visible and not viewer.locked_page.visible
			and not viewer.period_drop.disabled and not viewer.scale_drop.disabled
			and not viewer.tabs.button(&"Merc").locked,
		"locked %s page %s" % [viewer.graph_locked(), viewer.locked_page.visible])
	viewer.queue_free()


#The lock tables hold ids only: UpgradeDefs owns every upgrade name and tier count.
static func _case_lock_tables(res: Dictionary) -> void:
	var repeated: Array[String] = []
	var mismatch: Array[String] = []
	for graph: String in MetricsLocks.GRAPH_LOCKS:
		var row: Dictionary = MetricsLocks.GRAPH_LOCKS[graph]
		if row.has("upgrade") or row.has("tiers"):
			repeated.append(graph)
		var id: String = String(row.get("upgrade_id", ""))
		var out: Dictionary = MetricsLocks.graph_lock(graph)
		var want_name: String = UpgradeDefs.name_of(id) if id != "" else ""
		var want_tiers: int = maxi(1, UpgradeDefs.tier_count(id)) if id != "" else 1
		if String(out.get("upgrade", "")) != want_name:
			mismatch.append("%s name %s" % [graph, out.get("upgrade", "")])
		if int(out.get("tiers", 0)) != want_tiers:
			mismatch.append("%s tiers %s" % [graph, out.get("tiers", 0)])
	for key: String in MetricsLocks.METRIC_UPGRADES:
		var metric_row: Dictionary = MetricsLocks.METRIC_UPGRADES[key]
		if metric_row.has("upgrade") or metric_row.has("tiers"):
			repeated.append(key)
		if not UpgradeDefs.has_id(String(metric_row.get("upgrade_id", ""))):
			mismatch.append("%s id %s" % [key, metric_row.get("upgrade_id", "")])
	TestFixtures.check(res, "metrics lock rows carry no upgrade name and no tier count of their own",
		repeated.is_empty(), "rows %s" % [repeated])
	TestFixtures.check(res, "metrics lock rows read the name and the tier count from UpgradeDefs",
		mismatch.is_empty() and MetricsLocks.GRAPH_LOCKS.size() == 3
			and MetricsLocks.METRIC_UPGRADES.size() == 2, "%s" % [mismatch])
	TestFixtures.check(res, "MERC_TIERS equals the tier count UpgradeDefs holds",
		MetricsLocks.MERC_TIERS == UpgradeDefs.tier_count(MetricsLocks.MERC_UPGRADE_ID)
			and MetricsLocks.MERC_TIERS == 3,
		"%d vs %d" % [MetricsLocks.MERC_TIERS,
			UpgradeDefs.tier_count(MetricsLocks.MERC_UPGRADE_ID)])
	var tier_lock: Dictionary = MetricsLocks.merc_tier_lock(MetricsLocks.PICK_TIER)
	TestFixtures.check(res, "the merc tier lock names the upgrade UpgradeDefs holds",
		String(tier_lock.get("upgrade", "")) == UpgradeDefs.name_of(MetricsLocks.MERC_UPGRADE_ID)
			and int(tier_lock.get("tiers", 0)) == MetricsLocks.MERC_TIERS,
		"%s" % [tier_lock])


#The four merc tiers: no graph, team averages only, one merc, then the comparison.
static func _case_merc_tiers(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open(host)
	viewer.select_source("Merc")
	await host.get_tree().process_frame
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {})
	await host.get_tree().process_frame
	TestFixtures.check(res, "no merc slot shuts the merc graph outright",
		MetricsLocks.merc_slots() == 0 and viewer.graph_locked() and viewer.locked_page.visible
			and viewer.chart.series_count() == 0,
		"%d slots, locked %s, page %s" % [MetricsLocks.merc_slots(), viewer.graph_locked(),
			viewer.locked_page.visible])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "one slot plots the team averages and holds the picker shut",
		not viewer.graph_locked() and not viewer.locked_page.visible
			and viewer.current_uid() == -1 and viewer.merc_selector.disabled
			and viewer.merc_selector.tooltip_text == MetricsViewer.LOCKED_TIP
			and viewer.chart.series_count() == 2,
		"picker shut %s on %d with %d series" % [viewer.merc_selector.disabled,
			viewer.current_uid(), viewer.chart.series_count()])
	TestFixtures.check(res, "team averages read the team rows and name no merc in the title",
		viewer.stored_key("salary") == "team/salary"
			and viewer.title_label.text == MetricsViewer.ALL_MERCS
			and not viewer.compare_button.visible and not viewer.compare_lock.visible,
		"'%s' under '%s'" % [viewer.stored_key("salary"), viewer.title_label.text])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 2})
	await host.get_tree().process_frame
	viewer.merc_selector.select_uid(GameState.roster[0].uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "two slots open the picker and hold the comparison behind tier three",
		not viewer.merc_selector.disabled and viewer.current_uid() == GameState.roster[0].uid
			and not MetricsLocks.can_compare() and not viewer.compare_button.visible
			and viewer.compare_lock.visible
			and viewer.compare_lock.tier == MetricsLocks.COMPARE_TIER,
		"picker shut %s, compare %s, lock %s" % [viewer.merc_selector.disabled,
			viewer.compare_button.visible, viewer.compare_lock.visible])
	var lines: Array[String] = viewer.compare_lock.copy_lines()
	TestFixtures.check(res, "the comparison lock names the third tier of the Merc Metrics upgrade",
		lines.size() == 2 and lines[0] == "%s is locked." % MetricsLocks.MERC_FEATURE
			and lines[1] == "It requires the Tier III %s upgrade!" % MetricsLocks.MERC_FEATURE,
		"got %s" % str(lines))
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 3})
	await host.get_tree().process_frame
	TestFixtures.check(res, "three slots hand the comparison button over",
		MetricsLocks.can_compare() and viewer.compare_button.visible
			and not viewer.compare_lock.visible,
		"compare %s lock %s" % [viewer.compare_button.visible, viewer.compare_lock.visible])
	viewer.compare_button.pressed.emit()
	await host.get_tree().process_frame
	viewer.compare_selector.select_uid(GameState.roster[1].uid)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the comparison runs while the third tier stands",
		viewer.comparing() and viewer.compare_uid() == GameState.roster[1].uid
			and viewer.compare_selector.visible,
		"comparing %s with %d" % [viewer.comparing(), viewer.compare_uid()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 2})
	await host.get_tree().process_frame
	TestFixtures.check(res, "dropping back to two slots ends the comparison on the spot",
		not viewer.comparing() and viewer.compare_uid() == -1
			and not viewer.compare_selector.visible and viewer.compare_lock.visible,
		"comparing %s with %d" % [viewer.comparing(), viewer.compare_uid()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "dropping back to one slot puts the picker on All Mercs again",
		viewer.current_uid() == -1 and viewer.merc_selector.disabled
			and viewer.stored_key("salary") == "team/salary",
		"got %d on '%s'" % [viewer.current_uid(), viewer.stored_key("salary")])
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	viewer.queue_free()


#The opinion metrics behind their own upgrades: a locked row cannot be plotted, sinks to the
#bottom of the list and carries a FeatureLock naming the upgrade that opens it.
static func _case_metric_locks(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open(host)
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"mercmetrics": 3, "contractmetrics": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "the survey and the client upgrades shut the three opinion metrics",
		MetricList.locked_key("Guild", "mop") and MetricList.locked_key("Guild", "cop")
			and MetricList.locked_key("Merc", "op") and not MetricList.locked_key("Guild", "bank")
			and not MetricList.locked_key("Merc", "salary"),
		"mop %s cop %s op %s" % [MetricList.locked_key("Guild", "mop"),
			MetricList.locked_key("Guild", "cop"), MetricList.locked_key("Merc", "op")])
	var guild_order: Array[String] = MetricList.row_order("Guild")
	var sunk: Array[String] = ["bank", "exp", "count", "dead", "port", "mop", "cop"]
	TestFixtures.check(res, "a shut guild row sinks under every open one and keeps the def order",
		_same_text(guild_order, sunk), "got %s" % str(guild_order))
	var merc_order: Array[String] = MetricList.row_order("Merc")
	TestFixtures.check(res, "the shut merc opinion sinks to the foot of its own list",
		merc_order.size() == 10 and merc_order[merc_order.size() - 1] == "op"
			and merc_order[0] == "salary",
		"got %s" % str(merc_order))
	var rows: Array[String] = []
	for i: int in viewer.metric_list.toggle_count():
		rows.append(viewer.metric_list.toggle_at(i).key)
	TestFixtures.check(res, "the list widget draws its rows in that same order",
		_same_text(rows, sunk), "got %s" % str(rows))
	var mop_row: MetricToggle = _row_for(viewer.metric_list, "mop")
	var cop_row: MetricToggle = _row_for(viewer.metric_list, "cop")
	TestFixtures.check(res, "a shut row refuses the press and shows its lock instead",
		mop_row != null and mop_row.locked and mop_row.disabled and mop_row.lock.visible
			and not mop_row.button_pressed and not mop_row.arrow.visible,
		"locked %s shut %s lock %s" % ["nothing" if mop_row == null else str(mop_row.locked),
			"nothing" if mop_row == null else str(mop_row.disabled),
			"nothing" if mop_row == null else str(mop_row.lock.visible)])
	TestFixtures.check(res, "the guild opinion row names the Employee Survey upgrade",
		mop_row != null and mop_row.lock.upgrade == "Employee Survey"
			and mop_row.lock.upgrade_id == "survey"
			and mop_row.lock.feature == MetricList.def_for("Guild", "mop").label,
		"got '%s' as '%s'" % ["" if mop_row == null else mop_row.lock.upgrade,
			"" if mop_row == null else mop_row.lock.upgrade_id])
	TestFixtures.check(res, "the client opinion row names the Customer Satisfaction upgrade",
		cop_row != null and cop_row.lock.upgrade == "Customer Satisfaction"
			and cop_row.lock.upgrade_id == "customer" and cop_row.lock.visible,
		"got '%s' as '%s'" % ["" if cop_row == null else cop_row.lock.upgrade,
			"" if cop_row == null else cop_row.lock.upgrade_id])
	var plotted: int = viewer.chart.series_count()
	viewer.metric_list.set_active("Guild", "mop", true)
	await host.get_tree().process_frame
	TestFixtures.check(res, "a shut metric cannot be plotted at all",
		not viewer.metric_list.active_keys("Guild").has("mop")
			and viewer.chart.series_count() == plotted,
		"keys %s with %d series" % [str(viewer.metric_list.active_keys("Guild")),
			viewer.chart.series_count()])
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE,
		{"mercmetrics": 3, "contractmetrics": 1, "survey": 1, "customer": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "both upgrades open the opinion rows and put them back in def order",
		not MetricList.locked_key("Guild", "mop") and not MetricList.locked_key("Merc", "op")
			and _same_text(MetricList.row_order("Guild"),
				["bank", "exp", "count", "dead", "mop", "cop", "port"]),
		"got %s" % str(MetricList.row_order("Guild")))
	viewer.metric_list.set_active("Guild", "mop", true)
	await host.get_tree().process_frame
	var open_row: MetricToggle = _row_for(viewer.metric_list, "mop")
	TestFixtures.check(res, "an opened metric plots like any other",
		viewer.metric_list.active_keys("Guild").has("mop")
			and viewer.chart.series_count() == plotted + 1 and open_row != null
			and not open_row.locked and not open_row.disabled and not open_row.lock.visible,
		"keys %s with %d series" % [str(viewer.metric_list.active_keys("Guild")),
			viewer.chart.series_count()])
	var dropped: bool = false
	SubscriptionManager.set_state(SubscriptionManager.Plan.ENTERPRISE, {"mercmetrics": 3})
	await host.get_tree().process_frame
	dropped = not viewer.metric_list.active_keys("Guild").has("mop")
	TestFixtures.check(res, "taking the upgrade away drops that metric from the plot again",
		dropped and viewer.chart.series_count() == plotted,
		"keys %s with %d series" % [str(viewer.metric_list.active_keys("Guild")),
			viewer.chart.series_count()])
	SubscriptionManager.max_out()
	await host.get_tree().process_frame
	viewer.queue_free()


#The period table on three dates of a Trynn year: the first day, mid year and the last day.
static func _case_period_rules(res: Dictionary) -> void:
	var all_start: int = MetricsPeriod.period_days(MetricsPeriod.Period.ALL_TIME, YEAR_START)
	var all_mid: int = MetricsPeriod.period_days(MetricsPeriod.Period.ALL_TIME, YEAR_MID)
	var all_end: int = MetricsPeriod.period_days(MetricsPeriod.Period.ALL_TIME, YEAR_END)
	TestFixtures.check(res, "All Time names no day count of its own on any date",
		all_start == -1 and all_mid == -1 and all_end == -1, "got %d" % all_mid)
	var ytd_start: int = MetricsPeriod.period_days(MetricsPeriod.Period.YTD, YEAR_START)
	var ytd_mid: int = MetricsPeriod.period_days(MetricsPeriod.Period.YTD, YEAR_MID)
	var ytd_end: int = MetricsPeriod.period_days(MetricsPeriod.Period.YTD, YEAR_END)
	TestFixtures.check(res, "YTD counts the days passed in the year, the first day counting as one",
		ytd_start == 1 and ytd_mid == 166 and ytd_end == MetricsPeriod.YEAR_DAYS,
		"got %d, %d and %d" % [ytd_start, ytd_mid, ytd_end])
	var fixed: Array[int] = [MetricsPeriod.Period.M6, MetricsPeriod.Period.Y1,
		MetricsPeriod.Period.Y3, MetricsPeriod.Period.Y5]
	var want: Array[int] = [198, 330, 990, 1650]
	var got: Array[int] = []
	var steady: bool = true
	for i: int in fixed.size():
		got.append(MetricsPeriod.period_days(fixed[i], YEAR_MID))
		for today: int in [YEAR_START, YEAR_MID, YEAR_END]:
			steady = steady and MetricsPeriod.period_days(fixed[i], today) == want[i]
	TestFixtures.check(res, "6m, 1y, 3y and 5y hold the same day count on every date",
		steady and _same(got, want), "got %s against %s" % [str(got), str(want)])
	TestFixtures.check(res, "the year of the game calendar decides the longer periods",
		MetricsPeriod.YEAR_DAYS == TrynnCalendar.DAYS_PER_YEAR
			and MetricsPeriod.HALF_YEAR == 6 * MetricsHistory.DAYS_PER_MONTH,
		"year %d, half %d" % [MetricsPeriod.YEAR_DAYS, MetricsPeriod.HALF_YEAR])
	TestFixtures.check(res, "a window never reaches past the record nor falls under a single day",
		MetricsPeriod.span(MetricsPeriod.Period.Y5, YEAR_MID, 400) == 400
			and MetricsPeriod.span(MetricsPeriod.Period.M6, YEAR_MID, 400) == 198
			and MetricsPeriod.span(MetricsPeriod.Period.ALL_TIME, YEAR_MID, 0) == 1
			and MetricsPeriod.span(MetricsPeriod.Period.Y1, YEAR_MID, 0) == 1,
		"got %d and %d" % [MetricsPeriod.span(MetricsPeriod.Period.Y5, YEAR_MID, 400),
			MetricsPeriod.span(MetricsPeriod.Period.M6, YEAR_MID, 400)])
	TestFixtures.check(res, "each scale hands back the reason a window shuts it out for",
		MetricsPeriod.reason(MetricsPeriod.Scale.DAY) == MetricsPeriod.REASON_DAY
			and MetricsPeriod.reason(MetricsPeriod.Scale.WEEK) == MetricsPeriod.REASON_WEEK
			and MetricsPeriod.reason(MetricsPeriod.Scale.MONTH) == MetricsPeriod.REASON_MONTH
			and MetricsPeriod.reason(MetricsPeriod.Scale.QUARTER) == MetricsPeriod.REASON_QUARTER
			and MetricsPeriod.reason(9) == "",
		"got '%s'" % MetricsPeriod.reason(MetricsPeriod.Scale.MONTH))
	TestFixtures.check(res, "the four reasons read as the data delta writes them",
		MetricsPeriod.REASON_DAY == "Days need a period of 6m or less"
			and MetricsPeriod.REASON_WEEK == "Weeks need a period of 1y or less"
			and MetricsPeriod.REASON_MONTH == "Months need a period of 6m or more"
			and MetricsPeriod.REASON_QUARTER == "Quarters need a period of 1y or more",
		"got %s" % str(MetricsPeriod.REASONS))
	TestFixtures.check(res, "the period captions and keys stand in enum order",
		MetricsPeriod.period_label(MetricsPeriod.Period.ALL_TIME) == "All Time"
			and MetricsPeriod.period_label(MetricsPeriod.Period.M6) == "6m"
			and MetricsPeriod.period_of(&"y3") == MetricsPeriod.Period.Y3
			and MetricsPeriod.scale_of(&"quarter") == MetricsPeriod.Scale.QUARTER
			and MetricsPeriod.scale_singular(MetricsPeriod.Scale.WEEK) == "Week",
		"got '%s' and %d" % [MetricsPeriod.period_label(MetricsPeriod.Period.M6),
			MetricsPeriod.period_of(&"y3")])


#The scales a window can carry and the snap that holds the guild's pick as near as it reaches. A
#valid set is always one unbroken run of scales, so the tie rule of snap_scale never comes up.
static func _case_scale_rules(res: Dictionary) -> void:
	var day_s: int = MetricsPeriod.Scale.DAY
	var week_s: int = MetricsPeriod.Scale.WEEK
	var month_s: int = MetricsPeriod.Scale.MONTH
	var quarter_s: int = MetricsPeriod.Scale.QUARTER
	var spans: Array[int] = [1, 197, 198, 199, 329, 330, 331, 1650]
	var sets: Array[Array] = [[day_s, week_s], [day_s, week_s], [day_s, week_s, month_s],
		[week_s, month_s], [week_s, month_s], [week_s, month_s, quarter_s],
		[month_s, quarter_s], [month_s, quarter_s]]
	var ok: bool = true
	var report: String = ""
	for i: int in spans.size():
		var got: Array[int] = MetricsPeriod.valid_scales(spans[i])
		if not _same(got, sets[i]):
			ok = false
			report += "%d gives %s; " % [spans[i], str(got)]
	TestFixtures.check(res, "each window opens the scales its own length can carry",
		ok, "got %s" % report)
	var snap_spans: Array[int] = [100, 250, 990]
	var snap_table: Array[Array] = [[day_s, week_s, week_s, week_s],
		[week_s, week_s, month_s, month_s], [month_s, month_s, month_s, quarter_s]]
	var snap_ok: bool = true
	var snap_report: String = ""
	for i: int in snap_spans.size():
		for wanted: int in MetricsPeriod.SCALE_LABELS.size():
			var got: int = MetricsPeriod.snap_scale(wanted, snap_spans[i])
			if got != int(snap_table[i][wanted]):
				snap_ok = false
				snap_report += "%d wanting %d gives %d; " % [snap_spans[i], wanted, got]
	TestFixtures.check(res, "a pick the window cannot carry snaps to the nearest scale it can",
		snap_ok, "got %s" % snap_report)
	var six: int = MetricsPeriod.span(MetricsPeriod.Period.M6, YEAR_MID, DEEP_HISTORY)
	var three: int = MetricsPeriod.span(MetricsPeriod.Period.Y3, YEAR_MID, DEEP_HISTORY)
	TestFixtures.check(res, "a deep record lets 6m reach 198 days and 3y reach 990",
		six == 198 and three == 990, "got %d and %d" % [six, three])
	TestFixtures.check(res, "Days picked under 6m reads Months under 3y and Days on the way back",
		MetricsPeriod.snap_scale(day_s, six) == day_s
			and MetricsPeriod.snap_scale(day_s, three) == month_s
			and MetricsPeriod.scale_label(MetricsPeriod.snap_scale(day_s, three)) == "Months",
		"got '%s'" % MetricsPeriod.scale_label(MetricsPeriod.snap_scale(day_s, three)))
	var rows: Array[Dictionary] = MetricsPeriod.scale_options(100)
	TestFixtures.check(res, "a scale row the window shuts is disabled and carries its reason",
		rows.size() == 4 and bool(rows[day_s]["enabled"]) and bool(rows[week_s]["enabled"])
			and not bool(rows[month_s]["enabled"]) and not bool(rows[quarter_s]["enabled"])
			and String(rows[month_s]["reason"]) == MetricsPeriod.REASON_MONTH
			and String(rows[day_s]["reason"]) == "",
		"got %s" % str(rows))
	var period_rows: Array[Dictionary] = MetricsPeriod.period_options()
	TestFixtures.check(res, "every period row can be picked whatever the record holds",
		period_rows.size() == 6 and bool(period_rows[0]["enabled"])
			and bool(period_rows[5]["enabled"]) and String(period_rows[2]["label"]) == "6m"
			and StringName(period_rows[1]["key"]) == &"ytd",
		"got %s" % str(period_rows))


#The windowed read of the record: a first row and a day count cut exactly the rows the full read
#holds, a count past the end stops at the end and a count of nothing reads nothing.
static func _case_window_math(res: Dictionary, host: Node) -> void:
	_fresh()
	await host.get_tree().process_frame
	MetricsHistory.seed_preview(SEED_DAYS, _uids())
	var full: Array[Dictionary] = MetricsHistory.series("Guild", "bank", 0, 1)
	var cut: Array[Dictionary] = MetricsHistory.series("Guild", "bank", 10, 1, 5)
	var lined_up: bool = full.size() == SEED_DAYS and cut.size() == 5
	for i: int in cut.size():
		if i + 10 >= full.size():
			lined_up = false
			break
		var same_day: bool = int(cut[i]["day"]) == int(full[i + 10]["day"])
		var same_value: bool = is_equal_approx(float(cut[i]["value"]), float(full[i + 10]["value"]))
		lined_up = lined_up and same_day and same_value
	TestFixtures.check(res, "a windowed read hands back the very rows the full read holds",
		lined_up, "%d rows of %d, first day %s" % [cut.size(), full.size(),
			"none" if cut.is_empty() else str(cut[0]["day"])])
	var past: Array[Dictionary] = MetricsHistory.series("Guild", "bank", SEED_DAYS - 5, 1, 20)
	var none: Array[Dictionary] = MetricsHistory.series("Guild", "bank", 10, 1, 0)
	TestFixtures.check(res, "a count past the end stops at the end and a count of nothing reads none",
		past.size() == 5 and none.is_empty()
			and MetricsHistory.series("Guild", "bank", 0, 1, -1).size() == SEED_DAYS,
		"%d past the end, %d of none" % [past.size(), none.size()])
	var buckets: Array[Dictionary] = MetricsHistory.series("Guild", "bank", 20, 10, 20)
	TestFixtures.check(res, "a bucketed window starts on its own first row",
		buckets.size() == 2 and int(buckets[0]["day"]) == 20 and int(buckets[1]["day"]) == 30,
		"got %d buckets from %s" % [buckets.size(),
			"none" if buckets.is_empty() else str(buckets[0]["day"])])
	var team_full: Array[Dictionary] = MetricsHistory.team_average("salary", 0, 10)
	var team_cut: Array[Dictionary] = MetricsHistory.team_average("salary", 20, 10, -1, 20)
	var team_ok: bool = team_full.size() == 5 and team_cut.size() == 2
	for i: int in team_cut.size():
		var mate: Dictionary = team_full[i + 2]
		team_ok = team_ok and int(team_cut[i]["day"]) == int(mate["day"])
		var both_nan: bool = is_nan(float(team_cut[i]["value"])) and is_nan(float(mate["value"]))
		team_ok = team_ok and (both_nan
			or is_equal_approx(float(team_cut[i]["value"]), float(mate["value"])))
	TestFixtures.check(res, "the team average windows onto the same buckets as the full read",
		team_ok, "%d buckets against %d" % [team_cut.size(), team_full.size()])
	var names: Array[String] = ContractLibrary.contract_type_names()
	var typed: Array[String] = []
	typed.append(names[0] if not names.is_empty() else "Bounty")
	var joined: Array[Dictionary] = MetricsHistory.combined_series("Contract", "count", typed,
		10, 1, 5)
	TestFixtures.check(res, "the combined read takes the same window as a single key",
		joined.size() == 5 and int(joined[0]["day"]) == 10,
		"got %d rows from %s" % [joined.size(),
			"none" if joined.is_empty() else str(joined[0]["day"])])
	TestFixtures.check(res, "the scale table of the record still answers for other callers",
		MetricsHistory.scales(SEED_DAYS).size() > 0,
		"got %s" % str(MetricsHistory.scales(SEED_DAYS)))
	_reset()


#Two int lists hold the same values in the same order.
static func _same(got: Array[int], want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i: int in got.size():
		if got[i] != int(want[i]):
			return false
	return true


#Two text lists hold the same entries in the same order.
static func _same_text(got: Array[String], want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i: int in got.size():
		if got[i] != String(want[i]):
			return false
	return true


static func _row_for(list: MetricList, key: String) -> MetricToggle:
	for i: int in list.toggle_count():
		var row: MetricToggle = list.toggle_at(i)
		if row != null and row.key == key:
			return row
	return null


#Whether the two-tone bake of one tab icon paints only the three tab tones, so the active plate's
#recolour can be counted instead of looked at.
static func _tab_tone_ok(id: String) -> bool:
	var img: Image = Icons.two_tone_image(Icons.image(id))
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return false
	var seen: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			seen += 1
			var on_tab: bool = false
			for tone: Color in [Icons.TAB_ON_LIGHT, Icons.TAB_ON_MID, Icons.TAB_ON_INK]:
				on_tab = on_tab or GuiIconTests.same_rgb(px, tone)
			if not on_tab:
				return false
	return seen > 0


#The Show All and Hide All buttons are blue BevelButton; Compare stays a plain toggle.
static func _case_bevel_sweep(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open(host)
	TestFixtures.check(res, "Show All and Hide All are blue BevelButton with their own labels",
		GuiKitTests.is_bevel(viewer.show_all, &"blue", MetricsViewer.SHOW_ALL_TEXT)
		and GuiKitTests.is_bevel(viewer.hide_all, &"blue", MetricsViewer.HIDE_ALL_TEXT),
		"show %s hide %s" % [viewer.show_all, viewer.hide_all])
	TestFixtures.check(res, "Compare stays the plain +/- toggle, not a BevelButton",
		not (viewer.compare_button is BevelButton), "%s" % [viewer.compare_button])
	var compare_icon: Texture2D = viewer.compare_button.icon
	TestFixtures.check(res, "Compare carries the baked plus at x2 and no text",
		viewer.compare_button.text == "" and compare_icon != null
		and compare_icon.get_size() == Vector2(10, 10),
		"text %s icon %s" % [viewer.compare_button.text, compare_icon])
	viewer.hide_all.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Hide All still clears every metric once it is a BevelButton",
		viewer.metric_list.active_keys(viewer.source()).is_empty(), "%s" % [
			viewer.metric_list.active_keys(viewer.source())])
	viewer.show_all.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Show All still turns every metric back on",
		not viewer.metric_list.active_keys(viewer.source()).is_empty(), "still empty")
	viewer.queue_free()


#Every graph tab fits the 1280 x 644 band and clears the close X.
static func _case_window_fit(res: Dictionary, host: Node) -> void:
	await GuiClientTests.check_tabs_fit(res, host, VIEWER_SCENE,
		"the %s graph fits the window and clears the close X",
		func(screen: Control) -> Array: return (screen as MetricsViewer).tabs.keys,
		func(screen: Control, key: StringName) -> void: (screen as MetricsViewer).select_source(String(key)))
