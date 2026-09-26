class_name GuiMetricsTests

#The Metrics Viewer screen: the graph tabs, the metric list, the two selectors, the scale buttons
#and the line chart, all driven against a live campaign with the preview history seeded onto it.
#Run: godot --headless --path . -- --gui-metrics-tests

const VIEWER_SCENE := preload("res://Scenes/GUI/Metrics/MetricsViewer.tscn")
const CHART_PATH := "Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/Chart"
const HISTORY_PATH := "res://Scripts/GUI/Autoloads/MetricsHistory.gd"
const PREVIEW_DAYS := 120
const SEED_DAYS := 50
const LONG_DAYS := 200


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	await host.get_tree().process_frame
	await _case_layout(res, host)
	await _case_series(res, host)
	await _case_scale(res, host)
	await _case_chart(res, host)
	await _case_focus(res, host)
	await _case_lock(res, host)
	await _case_seed(res, host)
	await _case_entitlements(res, host)
	await _case_new_metrics(res, host)
	await _case_team_average(res, host)
	await _case_averages_and_compare(res, host)
	_case_arrow_math(res)
	_case_x_labels(res)
	_case_combined_weight(res)
	_case_event_avg_carry(res)
	_reset()
	return TestFixtures.summarize(res, "GUI METRICS")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _reset() -> void:
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	SubscriptionManager.reset()
	MetricsHistory.clear()
	MetricsHistory.clear_preview()
	GuildRoster.reset()
	TestFixtures.reset_campaign()


static func _uids() -> Array[int]:
	var out: Array[int] = []
	for view: MercView in GameState.roster:
		out.append(view.uid)
	return out


#A fresh campaign, the preview history renamed onto its roster, and the viewer opened on it.
static func _open(host: Node) -> MetricsViewer:
	_fresh()
	MetricsHistory.seed_preview(PREVIEW_DAYS, _uids())
	var viewer: MetricsViewer = VIEWER_SCENE.instantiate()
	(viewer.get_node(CHART_PATH) as LineChart).tween_seconds = 0.0
	host.add_child(viewer)
	await host.get_tree().process_frame
	return viewer


#The same viewer moved onto the Merc tab with the first roster merc picked, where the picker would
#otherwise stand on All Mercs.
static func _open_merc(host: Node) -> MetricsViewer:
	var viewer: MetricsViewer = await _open(host)
	viewer.tabs.select_source("Merc")
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
	TestFixtures.check(res, "the graph tabs offer the three sources with Guild first and active",
		viewer.tabs.tab_count() == 3 and viewer.tabs.current() == "Guild"
			and String(viewer.tabs.get_child(0).name) == "Guild"
			and viewer.tabs.get_child(0) is TabButton,
		"got %d tabs on '%s'" % [viewer.tabs.tab_count(), viewer.tabs.current()])
	var guild_tab: TabButton = viewer.tabs.button_for("Guild") as TabButton
	var merc_tab: TabButton = viewer.tabs.button_for("Merc") as TabButton
	TestFixtures.check(res, "the active tab stands 44 px and an idle one 38 px",
		guild_tab.active and guild_tab.custom_minimum_size.y == TabButton.ACTIVE_HEIGHT
			and not merc_tab.active and merc_tab.custom_minimum_size.y == TabButton.IDLE_SIZE.y,
		"guild %s merc %s" % [guild_tab.custom_minimum_size, merc_tab.custom_minimum_size])
	TestFixtures.check(res, "an idle metrics tab keeps its label up",
		merc_tab.text_label.visible and merc_tab.text_label.text == "MERC",
		"visible %s text '%s'" % [merc_tab.text_label.visible, merc_tab.text_label.text])
	TestFixtures.check(res, "the viewer fits the 720 px window",
		viewer.get_combined_minimum_size().y <= 720.0,
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
	var guild_height: float = viewer.left_panel.size.y
	TestFixtures.check(res, "the tabs, the averages switch and the scale share the header row",
		viewer.tabs.get_parent() == viewer.header_row
			and viewer.show_averages.get_parent() == viewer.header_row
			and viewer.scale_selector.get_parent() == viewer.header_row,
		"parents '%s', '%s' and '%s'" % [viewer.tabs.get_parent().name,
			viewer.show_averages.get_parent().name, viewer.scale_selector.get_parent().name])
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
			and viewer.list_title.text == "Guild Data",
		"got %d toggles under '%s'" % [viewer.metric_list.toggle_count(), viewer.list_title.text])
	viewer.tabs.select_source("Merc")
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
	var merc_all_height: float = viewer.left_panel.size.y
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
	TestFixtures.check(res, "the list header names the source and counts the plotted metrics",
		viewer.list_title.text == "Merc Data" and viewer.on_count.text == "2/%d" % defs,
		"got '%s' and '%s'" % [viewer.list_title.text, viewer.on_count.text])
	viewer.show_all.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Show All plots every metric of the source",
		viewer.metric_list.active_keys("Merc").size() == defs and viewer.on_count.text
			== "%d/%d" % [defs, defs],
		"got %d on '%s'" % [viewer.metric_list.active_keys("Merc").size(), viewer.on_count.text])
	viewer.hide_all.pressed.emit()
	await host.get_tree().process_frame
	TestFixtures.check(res, "Hide All empties the chart and keeps the focused metric",
		viewer.metric_list.active_keys("Merc").is_empty() and viewer.chart.is_empty()
			and viewer.focused_key() != "",
		"got %d on '%s'" % [viewer.metric_list.active_keys("Merc").size(), viewer.focused_key()])
	TestFixtures.check(res, "the Merc list stands ungrouped",
		viewer.metric_list.group_count() == 0,
		"got %d headers" % viewer.metric_list.group_count())
	viewer.tabs.select_source("Contract")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Contract list carries the three group headers",
		viewer.metric_list.group_count() == 3,
		"got %d headers" % viewer.metric_list.group_count())
	var contract_height: float = viewer.left_panel.size.y
	viewer.tabs.select_source("Merc")
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
	viewer.queue_free()


static func _case_series(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open_merc(host)
	TestFixtures.check(res, "the seeded merc history fills both default series",
		viewer.chart.series_count() == 2 and viewer.chart.point_count(0) > 0,
		"got %d series and %d points" % [viewer.chart.series_count(), viewer.chart.point_count(0)])
	TestFixtures.check(res, "the merc title carries the picked merc name",
		viewer.title_label.text == "%s Metrics" % GameState.roster[0].name,
		"got '%s'" % viewer.title_label.text)
	viewer.tabs.select_source("Guild")
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
	viewer.tabs.select_source("Contract")
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


static func _case_scale(res: Dictionary, host: Node) -> void:
	var viewer: MetricsViewer = await _open_merc(host)
	TestFixtures.check(res, "all four scales stand with only Days and Weeks open at 120 days",
		viewer.scale_selector.scale_count() == 4 and viewer.scale_selector.enabled_count() == 2
			and viewer.scale_selector.current() == "Weeks",
		"got %d scales, %d open, on '%s'" % [viewer.scale_selector.scale_count(),
			viewer.scale_selector.enabled_count(), viewer.scale_selector.current()])
	var months: Button = viewer.scale_selector.button_for("Months")
	TestFixtures.check(res, "a locked scale says how much history it needs",
		months != null and months.disabled
			and months.tooltip_text == String(ScaleSelector.LOCKED_TIPS["Months"]),
		"disabled %s on '%s'" % [months.disabled, months.tooltip_text])
	viewer.scale_selector.select_scale("Days")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Days scale plots one point per recorded day",
		viewer.chart.point_count(0) == PREVIEW_DAYS,
		"expected %d points, got %d" % [PREVIEW_DAYS, viewer.chart.point_count(0)])
	viewer.scale_selector.select_scale("Weeks")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Weeks scale buckets the same history into Trynn weeks",
		viewer.chart.point_count(0) == 12 or viewer.chart.point_count(0) == 13,
		"got %d points" % viewer.chart.point_count(0))
	TestFixtures.check(res, "a week bucket is the calendar week and a day bucket is one day",
		ScaleSelector.bucket_for("Weeks") == MetricsHistory.DAYS_PER_WEEK
			and ScaleSelector.bucket_for("Days") == 1,
		"got %d and %d" % [ScaleSelector.bucket_for("Weeks"), ScaleSelector.bucket_for("Days")])
	var labels: Array[String] = viewer.chart.x_labels()
	var buckets: int = viewer.chart.point_count(0)
	var step: int = LineChart.label_step(buckets, false)
	TestFixtures.check(res, "the X axis names the scale on show and steps evenly to the end",
		labels.size() == int((buckets - 1) / float(step)) + 1 and labels[0] == "Week 1"
			and labels[labels.size() - 1] == "Week %d" % (int((buckets - 1) / float(step)) * step + 1),
		"got %s over %d buckets" % [str(labels), buckets])
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
	TestFixtures.check(res, "nearest_index picks the last point at the right edge",
		LineChart.nearest_index(rising, 400.0, 400.0) == 2
			and LineChart.nearest_index(rising, 0.0, 400.0) == 0,
		"got %d and %d" % [LineChart.nearest_index(rising, 400.0, 400.0),
			LineChart.nearest_index(rising, 0.0, 400.0)])
	TestFixtures.check(res, "x_for spreads the points across the plot width",
		is_equal_approx(LineChart.x_for(0, 3, 400.0), 0.0)
			and is_equal_approx(LineChart.x_for(2, 3, 400.0), 400.0)
			and is_equal_approx(LineChart.x_for(0, 1, 400.0), 200.0),
		"got %.1f, %.1f and %.1f" % [LineChart.x_for(0, 3, 400.0), LineChart.x_for(2, 3, 400.0),
			LineChart.x_for(0, 1, 400.0)])
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
	var points: Array[Dictionary] = MetricsHistory.series("Merc", viewer.stored_key(row.key), 0,
		viewer.scale_selector.bucket())
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
	var viewer: MetricsViewer = await _open(host)
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
	var plain: Variant = load(HISTORY_PATH).new()
	plain.merc_source = func(_day: int) -> Dictionary:
		return {"1/op": 2.0, "2/op": 4.0}
	plain.record_day(0)
	var plain_points: Array[Dictionary] = plain.combined_series("Merc", "op",
		["1", "2"] as Array[String], 0, 1)
	TestFixtures.check(res, "an AVG combine with no counts is the plain mean of the two values",
		is_equal_approx(float(plain_points[0]["value"]), 3.0),
		"got %.3f" % float(plain_points[0]["value"]))
	plain.free()
	var weighted: Variant = load(HISTORY_PATH).new()
	weighted.merc_source = func(_day: int) -> Dictionary:
		return {"1/op": 2.0, "1/op_n": 3.0, "2/op": 4.0, "2/op_n": 1.0}
	weighted.record_day(0)
	var weighted_points: Array[Dictionary] = weighted.combined_series("Merc", "op",
		["1", "2"] as Array[String], 0, 1)
	TestFixtures.check(res, "an AVG combine with counts present is the count weighted mean",
		is_equal_approx(float(weighted_points[0]["value"]), 2.5),
		"got %.3f" % float(weighted_points[0]["value"]))
	weighted.free()
	var partial: Variant = load(HISTORY_PATH).new()
	partial.merc_source = func(_day: int) -> Dictionary:
		return {"1/op": 2.0}
	partial.record_day(0)
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
	var history: Variant = load(HISTORY_PATH).new()
	history.contract_source = func(day: int) -> Dictionary: return rows[day]
	history.record_day(0)
	history.record_day(1)
	var points: Array[Dictionary] = history.combined_series("Contract", "diff",
		["1"] as Array[String], 0, 1)
	TestFixtures.check(res,
		"a combined EVENT_AVG bucket with no counts carries the previous value forward",
		points.size() == 2 and is_equal_approx(float(points[0]["value"]), 4.0)
			and is_equal_approx(float(points[1]["value"]), 4.0),
		"got %s" % str(points))
	history.free()


#The subscription stub: phase one opens every metrics screen and three merc slots, and the slot
#count decides whether the comparison picker is offered at all.
static func _case_entitlements(res: Dictionary, host: Node) -> void:
	SubscriptionManager.reset()
	var viewer: MetricsViewer = await _open_merc(host)
	var held: Dictionary = SubscriptionManager.entitlements()
	TestFixtures.check(res, "phase one pays for the guild, contract and merc metrics",
		bool(held.get("metrics", false)) and bool(held.get("contract_metrics", false))
			and SubscriptionManager.merc_slots() == 3,
		"got %s" % str(held))
	TestFixtures.check(res, "three slots offer the comparison button on a picked merc",
		viewer.compare_button.visible, "visible %s" % viewer.compare_button.visible)
	SubscriptionManager.set_entitlements({"merc_metrics": 1})
	await host.get_tree().process_frame
	TestFixtures.check(res, "one slot takes the comparison button away",
		SubscriptionManager.merc_slots() == 1 and not viewer.compare_button.visible,
		"got %d slots, visible %s" % [SubscriptionManager.merc_slots(),
			viewer.compare_button.visible])
	SubscriptionManager.reset()
	await host.get_tree().process_frame
	TestFixtures.check(res, "a reset hands the three slots and the button back",
		SubscriptionManager.merc_slots() == 3 and viewer.compare_button.visible,
		"got %d slots, visible %s" % [SubscriptionManager.merc_slots(),
			viewer.compare_button.visible])
	viewer.queue_free()


#The two metrics the handoff adds: the guild investment portfolio and the merc vacation days.
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
	var late: Variant = load(HISTORY_PATH).new()
	late.merc_source = func(day: int) -> Dictionary:
		var row: Dictionary = {"1/salary": 100.0}
		if day >= 3:
			row["7/salary"] = 200.0
		return row
	for day: int in 5:
		late.record_day(day)
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
	SubscriptionManager.reset()
	var viewer: MetricsViewer = await _open(host)
	viewer.tabs.select_source("Merc")
	await host.get_tree().process_frame
	TestFixtures.check(res, "the Merc tab opens on All Mercs and reads the team keys",
		viewer.current_uid() == -1 and viewer.stored_key("salary") == "team/salary"
			and viewer.list_title.text == String(MetricsViewer.LIST_TITLES["Merc"])
			and viewer.merc_selector.name_label.text == MercSelector.ALL_NAME,
		"got %d, '%s' and '%s'" % [viewer.current_uid(), viewer.stored_key("salary"),
			viewer.list_title.text])
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
	TestFixtures.check(res, "a value over its reference reads that rise as a percentage",
		is_equal_approx(MetricToggle.compare_pct(110.0, 100.0), 10.0)
			and is_equal_approx(MetricToggle.compare_pct(90.0, 100.0), -10.0),
		"got %.2f and %.2f" % [MetricToggle.compare_pct(110.0, 100.0),
			MetricToggle.compare_pct(90.0, 100.0)])
	TestFixtures.check(res, "a swing of fifteen percent or more straightens the arrow",
		MetricToggle.arrow_kind(10.0) == 1 and MetricToggle.arrow_kind(20.0) == 2
			and MetricToggle.arrow_kind(-20.0) == 2,
		"got %d, %d and %d" % [MetricToggle.arrow_kind(10.0), MetricToggle.arrow_kind(20.0),
			MetricToggle.arrow_kind(-20.0)])
	TestFixtures.check(res, "a gap under half a percent draws no arrow at all",
		MetricToggle.arrow_kind(0.4) == 0 and MetricToggle.arrow_kind(NAN) == 0,
		"got %d and %d" % [MetricToggle.arrow_kind(0.4), MetricToggle.arrow_kind(NAN)])
	TestFixtures.check(res, "a zero reference reads a full hundred either way",
		is_equal_approx(MetricToggle.compare_pct(5.0, 0.0), 100.0)
			and is_equal_approx(MetricToggle.compare_pct(-5.0, 0.0), -100.0)
			and is_zero_approx(MetricToggle.compare_pct(0.0, 0.0)),
		"got %.1f, %.1f and %.1f" % [MetricToggle.compare_pct(5.0, 0.0),
			MetricToggle.compare_pct(-5.0, 0.0), MetricToggle.compare_pct(0.0, 0.0)])
	TestFixtures.check(res, "a blank bucket on either side carries no comparison",
		is_nan(MetricToggle.compare_pct(NAN, 100.0))
			and is_nan(MetricToggle.compare_pct(1.0, NAN)),
		"got %.1f and %.1f" % [MetricToggle.compare_pct(NAN, 100.0),
			MetricToggle.compare_pct(1.0, NAN)])


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
