class_name MetricsViewer extends Control

#The metrics screen: the metric list and the selectors on the left, the icon tabs, the averages
#switch, the Period and Scale dropdowns and the chart on the right. The Merc Viewer embeds the same
#scene through lock_to_merc, which drops the tabs and the merc picker. On the Merc tab the picker
#can stand on All Mercs, which plots the team average, and a picked merc can be laid against the
#team average or against a second merc, drawn as a ghost line under each series. The period sets how
#many recorded days the window holds and the scale sets the bucket; a scale the period cannot carry
#snaps to the nearest one it can while the pick is kept for a period that allows it again. What the
#subscription has not paid for is locked: a whole graph, the merc picker, the compare picker or one
#metric row.

const LIST_TITLES: Dictionary = {"Merc": "Merc Data", "Contract": "Contract Data",
	"Guild": "Guild Data"}
const GOOD_DIRECTION: Dictionary = {"salary": 0, "xp": 1, "level": 1, "wins": 1, "losses": -1,
	"sRoll": 1, "fRoll": -1, "kills": 1, "op": 1, "vac": 0}
const LEGEND_SWATCH := Vector2(12, 12)
const EMBED_SIZE := Vector2(680, 596)
const EMBED_CHART := Vector2(434, 466)
const EMBED_COLUMN := Vector2(200, 0)
const EMPTY_FOCUS := "No metric selected"
const EMPTY_VALUE := "-"
const ALL_MERCS := "All Mercs"
const TEAM_PREFIX := "team/"
const COMPARE_OFF := "+"
const COMPARE_ON := "-"
const EMPTY_COLOR := Color(0.231373, 0.435294, 0.713725, 1)
const ALL_BUTTON_BG := Color(0.168627, 0.309804, 0.541176, 1)
const ALL_BUTTON_TEXT := Color(0.952941, 0.917647, 0.843137, 1)
const PANEL_OUTLINE := Color(0.039216, 0.058824, 0.109804, 1)
#The tab row sits straight on the chart panel; the embed in the Merc Viewer keeps a gap.
const ATTACHED_GAP := 0
const EMBED_GAP := 14
const LOCKED_TIP := "Locked"
const LIST_BUTTON_FONT: FontVariation = \
	preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const LIST_BUTTON_SIZE: int = 10
const LIST_BUTTON_HEIGHT: float = 28.0
const SHOW_ALL_TEXT: String = "Show All"
const HIDE_ALL_TEXT: String = "Hide All"

@onready var left_panel: PanelContainer = $Margin/Columns/LeftPanel
@onready var left_box: VBoxContainer = $Margin/Columns/LeftPanel/LeftMargin/LeftBox
@onready var list_title: Label = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/ListHeader/ListTitle
@onready var on_count: Label = $Margin/Columns/LeftPanel/LeftMargin/LeftBox/ListHeader/OnCount
@onready var selector_slot: VBoxContainer = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/SelectorSlot
@onready var merc_selector: MercSelector = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/SelectorSlot/MercSelector
@onready var compare_box: HBoxContainer = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/SelectorSlot/CompareBox
@onready var compare_button: Button = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/SelectorSlot/CompareBox/CompareButton
@onready var compare_lock: FeatureLock = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/SelectorSlot/CompareBox/CompareLock
@onready var compare_selector: MercSelector = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/SelectorSlot/CompareBox/CompareSelector
@onready var type_selector: TypeSelector = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/SelectorSlot/TypeSelector
@onready var list_scroll: ScrollContainer = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/ListScroll
@onready var metric_list: MetricList = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/ListScroll/Pad/MetricList
@onready var list_buttons: HBoxContainer = \
	$Margin/Columns/LeftPanel/LeftMargin/LeftBox/ListButtons
@onready var right_box: VBoxContainer = $Margin/Columns/RightBox
@onready var header_row: HBoxContainer = $Margin/Columns/RightBox/HeaderRow
@onready var title_label: Label = $Margin/Columns/RightBox/HeaderRow/Title
@onready var tabs: GraphTabs = $Margin/Columns/RightBox/HeaderRow/GraphTabs
@onready var show_averages: ShowAveragesToggle = $Margin/Columns/RightBox/HeaderRow/ShowAverages
@onready var period_drop: OptionDropdown = $Margin/Columns/RightBox/HeaderRow/PeriodDrop
@onready var scale_drop: OptionDropdown = $Margin/Columns/RightBox/HeaderRow/ScaleDrop
@onready var chart_column: VBoxContainer = $Margin/Columns/RightBox/ChartColumn
@onready var chart_edge: ColorRect = $Margin/Columns/RightBox/ChartColumn/ChartEdge
@onready var chart_panel: PanelContainer = $Margin/Columns/RightBox/ChartColumn/ChartPanel
@onready var bevel_hi: Panel = $Margin/Columns/RightBox/ChartColumn/ChartPanel/BevelHi
@onready var bevel_lo: Panel = $Margin/Columns/RightBox/ChartColumn/ChartPanel/BevelLo
@onready var locked_page: LockedPage = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/LockedPage
@onready var chart_header: HBoxContainer = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/ChartHeader
@onready var focus_swatch: ColorRect = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/ChartHeader/Swatch
@onready var focus_label: Label = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/ChartHeader/FocusLabel
@onready var now_text: Label = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/ChartHeader/NowText
@onready var now_value: Label = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/ChartHeader/NowValue
@onready var range_label: Label = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/ChartHeader/RangeLabel
@onready var chart: LineChart = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/Chart
@onready var legend: HBoxContainer = \
	$Margin/Columns/RightBox/ChartColumn/ChartPanel/ChartMargin/ChartBox/Legend

#The window the chart reads: period picks its length, chart_scale the bucket. chart_scale always
#holds the scale on show; the pick the guild made lives in _wanted_scale. Control owns scale and
#set_scale already, so the member carries the chart_ prefix.
@export var period: MetricsPeriod.Period = MetricsPeriod.Period.ALL_TIME:
	set(value):
		period = value
		if not _resolving:
			_refresh()
@export var chart_scale: MetricsPeriod.Scale = MetricsPeriod.Scale.MONTH:
	set(value):
		chart_scale = value
		if not _resolving:
			_wanted_scale = value
			_refresh()

var _source: String = "Guild"
var _locked_uid: int = -1
var _focus: Dictionary = {}
var _compare_on: bool = false
var _compare_uid: int = -1
var _averages_held: bool = false
var _wanted_scale: MetricsPeriod.Scale = MetricsPeriod.Scale.MONTH
var _resolving: bool = false
var _forcing: bool = false

var show_all: BevelButton = null
var hide_all: BevelButton = null


func _ready() -> void:
	tabs.tab_changed.connect(_on_tab_changed)
	merc_selector.merc_selected.connect(_on_merc_selected)
	compare_selector.merc_selected.connect(_on_compare_selected)
	compare_button.pressed.connect(_on_compare_pressed)
	show_averages.toggled_on.connect(_on_averages_toggled)
	type_selector.types_changed.connect(_on_types_changed)
	metric_list.metrics_changed.connect(_on_metrics_changed)
	metric_list.focus_requested.connect(_on_focus_requested)
	period_drop.option_selected.connect(_on_period_picked)
	scale_drop.option_selected.connect(_on_scale_picked)
	_build_list_buttons()
	show_all.pressed.connect(_on_show_all)
	hide_all.pressed.connect(_on_hide_all)
	_style_all_button(compare_button)
	_outline_panel()
	right_box.add_theme_constant_override("separation", ATTACHED_GAP)
	GameState.roster_changed.connect(_refresh)
	GameState.day_changed.connect(_on_day_changed)
	SubscriptionManager.changed.connect(_refresh)
	if _locked_uid >= 0:
		lock_to_merc(_locked_uid)
	else:
		_refresh()


#The compact embed of the Merc Viewer's Metrics tab: one merc, no tabs and no picker.
func lock_to_merc(uid: int) -> void:
	_locked_uid = uid
	if not is_node_ready():
		return
	_source = "Merc"
	tabs.select_source("Merc")
	tabs.visible = false
	merc_selector.select_uid(uid)
	merc_selector.visible = false
	type_selector.visible = false
	custom_minimum_size = EMBED_SIZE
	left_panel.custom_minimum_size = EMBED_COLUMN
	chart.custom_minimum_size = EMBED_CHART
	chart.compact = true
	right_box.add_theme_constant_override("separation", EMBED_GAP)
	_refresh()


func locked_uid() -> int:
	return _locked_uid


func source() -> String:
	return _source


#The gap between the tab row and the chart panel: none standalone, 14 px in the Merc Viewer.
func panel_gap() -> int:
	return right_box.get_theme_constant("separation")


#The metric owning the Y axis and the chart header, remembered per source.
func focused_key() -> String:
	return String(_focus.get(_source, ""))


#The plotted merc: the locked one for the embed, else whatever the picker holds. -1 is All Mercs.
func current_uid() -> int:
	return _locked_uid if _locked_uid >= 0 else merc_selector.selected_uid()


func comparing() -> bool:
	return _compare_on and _compare_uid >= 0


func compare_uid() -> int:
	return _compare_uid if comparing() else -1


func averages_on() -> bool:
	return show_averages.is_on()


func ghost_count() -> int:
	return chart.ghost_count()


func set_period(wanted: int) -> void:
	period = clampi(wanted, 0, MetricsPeriod.PERIOD_KEYS.size() - 1) as MetricsPeriod.Period


func set_chart_scale(wanted: int) -> void:
	chart_scale = clampi(wanted, 0, MetricsPeriod.SCALE_KEYS.size() - 1) as MetricsPeriod.Scale


#The scale the guild picked, kept even while a shorter period forces another one on the chart.
func wanted_scale() -> int:
	return _wanted_scale


func _valid_scales(span: int) -> Array[int]:
	return MetricsPeriod.valid_scales(span)


func _snap_scale(want: int, span: int) -> int:
	return MetricsPeriod.snap_scale(want, span)


#How many recorded days the window holds: the period's days, capped by the history behind it.
func span_days() -> int:
	return MetricsPeriod.span(period, GameState.day(), available_days())


#The recorded days the window may draw on; one merc on show counts from their hire day.
func available_days() -> int:
	return maxi(0, MetricsHistory.days() - start_row())


#The first record row the window may reach back to.
func start_row() -> int:
	if _source != "Merc" or MetricsHistory.days() <= 0:
		return 0
	var uid: int = current_uid()
	if uid < 0:
		return 0
	var hire: int = MetricsHistory.hire_day(uid)
	if hire < 0:
		return 0
	return clampi(hire, 0, MetricsHistory.days())


func window_from() -> int:
	return maxi(0, MetricsHistory.days() - span_days())


func window_days() -> int:
	return mini(span_days(), MetricsHistory.days())


#True while the subscription keeps the graph on show shut.
func graph_locked() -> bool:
	if _locked_uid >= 0:
		return not MetricsLocks.embed_unlocked()
	return MetricsLocks.graph_locked(_source)


#The stored key one metric reads, with the uid, contract type or team prefix the record uses.
func stored_key(metric_key: String) -> String:
	match _source:
		"Merc":
			var uid: int = current_uid()
			if uid < 0:
				return TEAM_PREFIX + metric_key
			return "%d/%s" % [uid, metric_key]
		"Contract":
			return type_selector.key_for(metric_key)
		_:
			return metric_key


func _on_tab_changed(source_name: String) -> void:
	_source = source_name
	_refresh()


func _on_merc_selected(_uid: int) -> void:
	if _forcing:
		return
	_end_compare()
	_refresh()


func _on_compare_selected(uid: int) -> void:
	_compare_uid = uid
	_refresh()


func _on_compare_pressed() -> void:
	if _compare_on:
		_end_compare()
	elif current_uid() >= 0 and MetricsLocks.can_compare():
		_compare_on = true
		_averages_held = show_averages.is_on()
		show_averages.set_on(false)
	_refresh()


func _on_averages_toggled(_on: bool) -> void:
	_refresh()


#Drops the second merc and gives the averages switch its own state back.
func _end_compare() -> void:
	if not _compare_on:
		return
	_compare_on = false
	_compare_uid = -1
	show_averages.set_on(_averages_held)


func _on_types_changed(_names: Array[String]) -> void:
	_refresh()


func _on_metrics_changed(source_name: String) -> void:
	if source_name == _source:
		_refresh()


#The Y button on a row lights that metric and turns it on when it was off.
func _on_focus_requested(key: String) -> void:
	if MetricList.locked_key(_source, key):
		return
	_focus[_source] = key
	if not metric_list.active_keys(_source).has(key):
		metric_list.set_active(_source, key, true)
		return
	_refresh()


func _on_show_all() -> void:
	metric_list.set_all(_source, true)


func _on_hide_all() -> void:
	metric_list.set_all(_source, false)


func _on_period_picked(key: StringName) -> void:
	set_period(MetricsPeriod.period_of(key))


func _on_scale_picked(key: StringName) -> void:
	set_chart_scale(MetricsPeriod.scale_of(key))


func _on_day_changed(_day_index: int) -> void:
	_refresh()


#Item 11: the one core BevelButton scene, added where the scene used to hold plain Buttons.
func _build_list_buttons() -> void:
	show_all = BevelButton.make(SHOW_ALL_TEXT, &"blue", Vector2(0.0, LIST_BUTTON_HEIGHT))
	hide_all = BevelButton.make(HIDE_ALL_TEXT, &"blue", Vector2(0.0, LIST_BUTTON_HEIGHT))
	for button: BevelButton in [show_all, hide_all]:
		button.add_theme_font_override(&"font", LIST_BUTTON_FONT)
		button.add_theme_font_size_override(&"font_size", LIST_BUTTON_SIZE)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		list_buttons.add_child(button)


func _style_all_button(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = ALL_BUTTON_BG
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", ALL_BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", ALL_BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", ALL_BUTTON_TEXT)


#The left panel keeps the raised bevel but rings it in ink, as the handoff draws it.
func _outline_panel() -> void:
	var base: StyleBox = left_panel.get_theme_stylebox("panel", "RaisedPanel")
	var flat: StyleBoxFlat = base as StyleBoxFlat
	if flat == null:
		return
	var box: StyleBoxFlat = flat.duplicate()
	box.border_color = PANEL_OUTLINE
	box.set_border_width_all(4)
	left_panel.add_theme_stylebox_override("panel", box)


func _refresh() -> void:
	if not is_node_ready():
		return
	var merc_source: bool = _source == "Merc"
	var shut: bool = graph_locked()
	_apply_tab_locks()
	if merc_source and _locked_uid < 0 and not MetricsLocks.can_pick_merc():
		_force_all_mercs()
	merc_selector.visible = merc_source and _locked_uid < 0
	compare_box.visible = merc_source and _locked_uid < 0
	type_selector.visible = _source == "Contract"
	show_averages.visible = merc_source
	_apply_compare_state()
	_resolve_scale(shut)
	_apply_lock_page(shut)
	if metric_list.source != _source:
		metric_list.source = _source
	var active: Array[String] = metric_list.active_keys(_source)
	var defs: Array[MetricDef] = MetricList.defs_for(_source)
	list_title.text = _list_title()
	on_count.text = "%d/%d" % [active.size(), defs.size()]
	title_label.text = _title()
	_ensure_focus(active, defs)
	metric_list.set_focus(focused_key())
	chart.set_focus(focused_key())
	if shut:
		var none: Array[String] = []
		_rebuild_series(none, defs)
		return
	_rebuild_series(active, defs)


#Each tab carries the lock of its own graph, so a shut source reads as shut before it is opened.
func _apply_tab_locks() -> void:
	for source_name: String in GraphTabs.SOURCES:
		tabs.set_source_locked(source_name, MetricsLocks.graph_locked(source_name))


#A plan that pays for team averages only holds the picker on All Mercs.
func _force_all_mercs() -> void:
	if merc_selector.selected_uid() < 0:
		return
	_forcing = true
	merc_selector.select_uid(-1)
	_forcing = false
	_end_compare()


#Resolves the picked scale against the window the period leaves and feeds both dropdowns.
func _resolve_scale(shut: bool) -> void:
	var span: int = span_days()
	_resolving = true
	chart_scale = MetricsPeriod.snap_scale(_wanted_scale, span) as MetricsPeriod.Scale
	_resolving = false
	period_drop.set_options(MetricsPeriod.period_options())
	period_drop.select(MetricsPeriod.period_key(period))
	period_drop.disabled = shut
	scale_drop.set_options(MetricsPeriod.scale_options(span))
	scale_drop.select(MetricsPeriod.scale_key(chart_scale))
	scale_drop.disabled = shut


#A shut graph plots nothing and draws no axes; standalone it takes a LockedPage over the chart.
func _apply_lock_page(shut: bool) -> void:
	chart.visible = not shut
	var page: bool = shut and _locked_uid < 0
	if page:
		var info: Dictionary = MetricsLocks.graph_lock(_source)
		locked_page.feature = String(info.get("feature", ""))
		locked_page.plan = String(info.get("plan", ""))
		locked_page.upgrade = String(info.get("upgrade", ""))
		locked_page.upgrade_id = String(info.get("upgrade_id", ""))
		locked_page.tier = int(info.get("tier", 1))
		locked_page.tiers = int(info.get("tiers", 1))
	locked_page.visible = page


#The compare button, its lock and the averages switch follow the merc on show and the merc tier.
func _apply_compare_state() -> void:
	var uid: int = current_uid()
	var can_pick: bool = MetricsLocks.can_pick_merc()
	var can_compare: bool = MetricsLocks.can_compare()
	var on_row: bool = _source == "Merc" and _locked_uid < 0 and uid >= 0
	merc_selector.disabled = _source == "Merc" and not can_pick
	merc_selector.tooltip_text = LOCKED_TIP if merc_selector.disabled else ""
	if not can_compare:
		_end_compare()
	compare_button.visible = on_row and can_compare
	compare_button.text = COMPARE_ON if _compare_on else COMPARE_OFF
	compare_lock.always_visible = on_row and not can_compare
	compare_lock.visible = on_row and not can_compare
	compare_selector.visible = _compare_on
	if compare_selector.exclude_uid != uid:
		compare_selector.exclude_uid = uid
	if uid < 0:
		show_averages.set_locked(true, ShowAveragesToggle.TIP_NO_MERC)
	elif _compare_on:
		show_averages.set_locked(true, ShowAveragesToggle.TIP_COMPARING)
	else:
		show_averages.set_locked(false, "")


#Keeps the Y axis on a metric that is on; an empty list leaves the last choice standing.
func _ensure_focus(active: Array[String], defs: Array[MetricDef]) -> void:
	if active.is_empty():
		return
	if active.has(focused_key()):
		return
	for def: MetricDef in defs:
		if active.has(def.key):
			_focus[_source] = def.key
			return


func _list_title() -> String:
	return String(LIST_TITLES.get(_source, ""))


func _title() -> String:
	match _source:
		"Merc":
			var uid: int = current_uid()
			if uid < 0:
				return ALL_MERCS
			return "%s Metrics" % _merc_name(uid)
		"Contract":
			return "%s Contracts" % type_selector.current_type()
		_:
			return "Guild Metrics"


func _merc_name(uid: int) -> String:
	for view: MercView in GameState.roster:
		if view.uid == uid:
			return view.name
	return "Merc"


#The rows behind one metric over the window on show: every checked contract type added together,
#the team average when the picker stands on All Mercs, else the one stored key.
func _points_for(metric_key: String, bucket: int) -> Array[Dictionary]:
	var from: int = window_from()
	var days: int = window_days()
	if _source == "Contract":
		var types: Array[String] = type_selector.selected_types()
		if types.size() > 1 and not type_selector.is_all():
			return MetricsHistory.combined_series("Contract", metric_key, types, from, bucket,
				days)
	if _source == "Merc" and current_uid() < 0:
		return MetricsHistory.team_average(metric_key, from, bucket, -1, days)
	return MetricsHistory.series(_source, stored_key(metric_key), from, bucket, days)


#The line laid under a series: the second merc while comparing, else the team average when the
#averages switch is on.
func _ghost_for(metric_key: String, bucket: int) -> Array[Dictionary]:
	var uid: int = current_uid()
	if _source != "Merc" or uid < 0:
		return []
	if comparing():
		return _merc_ghost(_compare_uid, metric_key, bucket)
	if show_averages.is_on():
		return MetricsHistory.team_average(metric_key, window_from(), bucket, uid, window_days())
	return []


#The second merc's own buckets, blank for every bucket that closed before the guild hired them.
func _merc_ghost(uid: int, metric_key: String, bucket: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = MetricsHistory.series("Merc", "%d/%s" % [uid, metric_key],
		window_from(), bucket, window_days())
	var hire: int = MetricsHistory.hire_day(uid)
	var span: int = maxi(1, bucket)
	for i: int in rows.size():
		var day: int = int(rows[i].get("day", 0))
		if hire < 0 or hire >= day + span:
			rows[i]["value"] = NAN
	return rows


func _rebuild_series(active: Array[String], defs: Array[MetricDef]) -> void:
	var bucket: int = MetricsPeriod.bucket_days(chart_scale)
	chart.bucket_name = MetricsPeriod.scale_singular(chart_scale)
	var list: Array[Dictionary] = []
	for i: int in defs.size():
		if not active.has(defs[i].key) or MetricsLocks.metric_locked(defs[i]):
			continue
		var entry: Dictionary = {"key": defs[i].key, "label": defs[i].label, "fmt": defs[i].fmt,
			"color": MetricList.color_for(i), "points": _points_for(defs[i].key, bucket)}
		var ghost: Array[Dictionary] = _ghost_for(defs[i].key, bucket)
		if not ghost.is_empty():
			entry["ghost"] = ghost
		list.append(entry)
	chart.set_series(list)
	_update_header(list)
	_rebuild_legend(list)
	_update_arrows(list)


#Every row reads its own last bucket against the reference line under it, or drops its arrow.
func _update_arrows(list: Array[Dictionary]) -> void:
	for i: int in metric_list.toggle_count():
		var row: MetricToggle = metric_list.toggle_at(i)
		if row == null:
			continue
		var pct: float = NAN
		for entry: Dictionary in list:
			if String(entry["key"]) != row.key:
				continue
			var mine: Array = entry.get("points", [])
			var other: Array = entry.get("ghost", [])
			pct = MetricToggle.compare_pct(_last_value(mine), _last_value(other))
		row.set_compare(pct, int(GOOD_DIRECTION.get(row.key, 0)))


static func _last_value(points: Array) -> float:
	if points.is_empty():
		return NAN
	return float((points[points.size() - 1] as Dictionary).get("value", 0.0))


#The band over the plot: the focused metric's swatch, name, latest value and the buckets on show.
func _update_header(list: Array[Dictionary]) -> void:
	var focused: Dictionary = {}
	for entry: Dictionary in list:
		if String(entry["key"]) == focused_key():
			focused = entry
			break
	var points: Array[Dictionary] = []
	if not focused.is_empty():
		points.assign(focused["points"])
	if points.is_empty():
		focus_swatch.color = EMPTY_COLOR
		focus_label.text = EMPTY_FOCUS if focused.is_empty() else String(focused["label"])
		now_value.text = EMPTY_VALUE
		now_value.add_theme_color_override("font_color", EMPTY_COLOR)
		range_label.text = ""
		return
	var color: Color = focused["color"]
	var band: Vector2 = LineChart.padded_range(points)
	var last: float = _last_value(points)
	focus_swatch.color = color
	focus_label.text = String(focused["label"])
	now_value.text = EMPTY_VALUE if is_nan(last) else LineChart.axis_text(last,
		String(focused["fmt"]), band.y - band.x)
	now_value.add_theme_color_override("font_color", color)
	range_label.text = _range_text(points.size())


#"Day 1" for a single bucket, else "Day 1 - Day 120" in the scale the window resolved to.
func _range_text(count: int) -> String:
	var unit: String = MetricsPeriod.scale_singular(chart_scale)
	if count <= 1:
		return "%s 1" % unit
	return "%s 1 - %s %d" % [unit, unit, count]


func _rebuild_legend(list: Array[Dictionary]) -> void:
	for child: Node in legend.get_children():
		legend.remove_child(child)
		child.queue_free()
	for entry: Dictionary in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = LEGEND_SWATCH
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = entry["color"]
		row.add_child(swatch)
		var text := Label.new()
		text.theme_type_variation = &"DescriptionLabel"
		text.text = String(entry["label"])
		row.add_child(text)
		legend.add_child(row)
