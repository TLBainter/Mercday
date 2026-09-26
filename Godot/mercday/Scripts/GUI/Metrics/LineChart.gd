class_name LineChart extends Control

#Plots the active metric series. Every series is normalized on its own padded minimum and maximum,
#so a flat line sits at mid height and lines of different units share the plot. The focused metric
#owns the Y axis labels and is drawn last, heavier than the rest. The reveal tween walks the
#polylines out from the left; the tests set tween_seconds to 0 and read the finished chart.

const PAD_LEFT := 62.0
const PAD_RIGHT := 16.0
const PAD_TOP := 12.0
const PAD_BOTTOM := 30.0
const GRID_COLOR := Color(0.101961, 0.168627, 0.301961, 1)
const PLOT_BG := Color(0.054902, 0.086275, 0.156863, 1)
const PLOT_RING := Color(0.039216, 0.058824, 0.109804, 1)
const AXIS_COLOR := Color(0.231373, 0.435294, 0.713725, 1)
const LABEL_COLOR := Color(0.611765, 0.776471, 0.937255, 1)
const CROSS_COLOR := Color(0.952941, 0.917647, 0.843137, 1)
const HOVER_EDGE := Color(0.039216, 0.058824, 0.109804, 1)
const CROSS_ALPHA := 0.35
const DIM_ALPHA := 0.75
const HOVER_DOT := 10.0
const HOVER_EDGE_WIDTH := 2.0
const LABEL_SIZE := 9
const LABEL_ROWS := 5
const RANGE_PAD := 0.08
const POINT_SIZE := 3.0
const DOT_LIMIT := 60
const EMPTY_TEXT := "No history yet"
const PLOT_RING_WIDTH := 3.0
const TICK_HEIGHT := 6.0
const TICK_WIDTH := 2.0
const GHOST_ALPHA := 0.22
const GHOST_WIDTH := 3.0
const LABELS_WIDE := 8.0
const LABELS_COMPACT := 5.0
const FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")

@export var pixel_scale: int = 2
@export var tween_seconds: float = 1.6
@export var grid_rows: int = 5
@export var bucket_name: String = "Day"
@export var compact: bool = false

var reveal: float = 1.0:
	set(value):
		reveal = value
		queue_redraw()

var _series: Array[Dictionary] = []
var _tween: Tween = null
var _focus_key: String = ""
var _hovered: int = -1

@onready var empty_label: Label = $Empty
@onready var anchor: Control = $Anchor
@onready var tip: ChartTooltip = $Tip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	empty_label.text = EMPTY_TEXT
	_apply_empty()


#Each entry is {key, label, color, fmt, points: Array[Dictionary] {day, value}}.
func set_series(list: Array[Dictionary]) -> void:
	_series = list
	_hovered = -1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if tween_seconds > 0.0 and is_inside_tree() and not is_empty():
		reveal = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "reveal", 1.0, tween_seconds)
	else:
		reveal = 1.0
	_apply_empty()
	queue_redraw()


#The metric the Y axis reads and the one drawn on top of the rest.
func set_focus(key: String) -> void:
	if _focus_key == key:
		return
	_focus_key = key
	queue_redraw()


func focused_key() -> String:
	return _focus_key


func hovered_index() -> int:
	return _hovered


func series_count() -> int:
	return _series.size()


#How many series carry a comparison line under them.
func ghost_count() -> int:
	var count: int = 0
	for entry: Dictionary in _series:
		if (entry.get("ghost", []) as Array).size() > 0:
			count += 1
	return count


func ghost_points(index: int) -> int:
	if index < 0 or index >= _series.size():
		return 0
	return (_series[index].get("ghost", []) as Array).size()


func point_count(index: int) -> int:
	if index < 0 or index >= _series.size():
		return 0
	return (_series[index]["points"] as Array).size()


func is_empty() -> bool:
	for i: int in _series.size():
		if point_count(i) > 0:
			return false
	return true


#Maps the values onto 0..height measured up from the plot floor; a flat series sits at mid height.
#A low and a high may be passed to map onto a wider band than the values alone cover.
static func normalize(points: Array[Dictionary], height: float, low: float = INF,
		high: float = -INF) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if points.is_empty():
		return out
	if low > high:
		low = INF
		high = -INF
		for point: Dictionary in points:
			var value: float = float(point.get("value", 0.0))
			low = minf(low, value)
			high = maxf(high, value)
	var span: float = high - low
	for point: Dictionary in points:
		if span <= 0.0:
			out.append(height * 0.5)
		else:
			out.append((float(point.get("value", 0.0)) - low) / span * height)
	return out


#The band the labels and the line share: the values plus 8 percent of head and foot room, or one
#either side of a flat series. Gaps (NAN) take no part in the band.
static func padded_range(points: Array[Dictionary]) -> Vector2:
	if points.is_empty():
		return Vector2(0.0, 1.0)
	var low: float = INF
	var high: float = -INF
	for point: Dictionary in points:
		var value: float = float(point.get("value", 0.0))
		if is_nan(value):
			continue
		low = minf(low, value)
		high = maxf(high, value)
	if low > high:
		return Vector2(0.0, 1.0)
	if is_equal_approx(low, high):
		return Vector2(low - 1.0, high + 1.0)
	var pad: float = (high - low) * RANGE_PAD
	return Vector2(low - pad, high + pad)


#The five Y axis values, from the plot floor up.
static func y_label_values(low: float, high: float) -> Array[float]:
	var out: Array[float] = []
	for row: int in LABEL_ROWS:
		out.append(low + (high - low) * float(row) / float(LABEL_ROWS - 1))
	return out


#One axis value as text: money past a thousand shortens, a count stays whole while the band is
#wide enough to tell the rows apart, an opinion keeps its sign, the rest keep one decimal.
static func axis_text(value: float, fmt: String, span: float) -> String:
	match fmt:
		"money":
			if absf(value) >= 1000.0:
				return "%.1fk" % (value / 1000.0)
			return "%d" % roundi(value)
		"int":
			if span >= 8.0:
				return "%d" % roundi(value)
		"op":
			var sign_text: String = "+" if value > 0.0 else ""
			return "%s%.1f" % [sign_text, value]
	return "%.1f" % value


#One X axis caption: the bucket unit and the one-based bucket number.
static func x_label(unit: String, index: int) -> String:
	return "%s %d" % [unit, index + 1]


#How many buckets sit between two captions; a narrow chart carries fewer.
static func label_step(count: int, compact_mode: bool) -> int:
	var slots: float = LABELS_COMPACT if compact_mode else LABELS_WIDE
	return maxi(1, ceili(float(count) / slots))


static func x_for(index: int, count: int, width: float) -> float:
	if count <= 1:
		return width * 0.5
	return float(index) * width / float(count - 1)


static func nearest_index(points: Array[Dictionary], x: float, width: float) -> int:
	var count: int = points.size()
	if count <= 0:
		return -1
	if count == 1 or width <= 0.0:
		return 0
	return clampi(roundi(x / width * float(count - 1)), 0, count - 1)


#One plotted value as text: whole numbers stay whole, everything else keeps one decimal.
static func format_value(value: float) -> String:
	if is_equal_approx(value, float(roundi(value))):
		return "%d" % roundi(value)
	return "%.1f" % value


func plot_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, maxf(1.0, size.x - PAD_LEFT - PAD_RIGHT),
		maxf(1.0, size.y - PAD_TOP - PAD_BOTTOM))


#Moves the hover tooltip to the bucket under a local point; outside the data it closes.
func hover_at(local: Vector2) -> void:
	if is_empty():
		hide_tip()
		return
	var plot: Rect2 = plot_rect()
	var first: Array[Dictionary] = []
	first.assign(_series[0]["points"])
	var index: int = nearest_index(first, local.x - plot.position.x, plot.size.x)
	if index < 0:
		hide_tip()
		return
	var rows: Array[Dictionary] = []
	for entry: Dictionary in _series:
		var points: Array = entry["points"]
		if index >= points.size():
			continue
		var value: float = float((points[index] as Dictionary).get("value", 0.0))
		if is_nan(value):
			continue
		rows.append({"label": String(entry.get("label", "")),
			"value": format_value(value)})
	if rows.is_empty():
		hide_tip()
		return
	tip.set_point(int((first[index] as Dictionary).get("day", 0)), rows)
	anchor.position = Vector2(plot.position.x + x_for(index, first.size(), plot.size.x),
		_anchor_y(plot, index))
	tip.show_at(anchor, get_global_rect())
	_hovered = index
	queue_redraw()


#The height of the first series holding a real value at that bucket; the plot floor when none do.
func _anchor_y(plot: Rect2, index: int) -> float:
	for entry: Dictionary in _series:
		var points: Array[Dictionary] = []
		points.assign(entry["points"])
		if index >= points.size():
			continue
		if is_nan(float(points[index].get("value", 0.0))):
			continue
		var band: Vector2 = _entry_band(entry)
		var heights: PackedFloat32Array = normalize(points, plot.size.y, band.x, band.y)
		return plot.end.y - heights[index]
	return plot.end.y


func hide_tip() -> void:
	tip.hide_tip()
	if _hovered != -1:
		_hovered = -1
		queue_redraw()


func _apply_empty() -> void:
	if not is_node_ready():
		return
	empty_label.visible = is_empty()


#The entry the focus key names, else the first one holding points.
func _focus_index() -> int:
	for i: int in _series.size():
		if String(_series[i].get("key", "")) == _focus_key and point_count(i) > 0:
			return i
	for i: int in _series.size():
		if point_count(i) > 0:
			return i
	return -1


#The band a series and its ghost share, so the two lines can be read against each other.
func _entry_band(entry: Dictionary) -> Vector2:
	var points: Array[Dictionary] = []
	points.assign(entry["points"])
	var band: Vector2 = padded_range(points)
	var ghost: Array = entry.get("ghost", [])
	if ghost.is_empty():
		return band
	var low: float = band.x
	var high: float = band.y
	for point: Dictionary in ghost:
		var value: float = float(point.get("value", 0.0))
		if is_nan(value):
			continue
		low = minf(low, value)
		high = maxf(high, value)
	if is_equal_approx(low, high):
		return Vector2(low - 1.0, high + 1.0)
	return Vector2(low, high)


#The plotted run split on its gaps, so a NAN opens a new segment instead of a straight jump.
func _segments(points: Array[Dictionary], band: Vector2, plot: Rect2,
		shown: int) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var heights: PackedFloat32Array = normalize(points, plot.size.y, band.x, band.y)
	var run := PackedVector2Array()
	for i: int in mini(shown, points.size()):
		if is_nan(float(points[i].get("value", 0.0))):
			if run.size() > 0:
				out.append(run)
				run = PackedVector2Array()
			continue
		run.append(Vector2(plot.position.x + x_for(i, points.size(), plot.size.x),
			plot.end.y - heights[i]))
	if run.size() > 0:
		out.append(run)
	return out


func _shown_count(total: int) -> int:
	return clampi(ceili(float(total) * clampf(reveal, 0.0, 1.0)), 1, maxi(1, total))


#The longest run of buckets on the chart; the X axis is stepped off it.
func _longest_count() -> int:
	var count: int = 0
	for entry: Dictionary in _series:
		count = maxi(count, (entry["points"] as Array).size())
	return count


func _label_indices(count: int) -> Array[int]:
	var out: Array[int] = []
	if count <= 0:
		return out
	var step: int = label_step(count, compact)
	var i: int = 0
	while i < count:
		out.append(i)
		i += step
	return out


#The captions the X axis draws, for the tests and the probe.
func x_labels() -> Array[String]:
	var out: Array[String] = []
	for i: int in _label_indices(_longest_count()):
		out.append(x_label(bucket_name, i))
	return out


func _draw() -> void:
	var plot: Rect2 = plot_rect()
	var rows: int = maxi(2, grid_rows)
	draw_rect(plot, PLOT_BG)
	draw_rect(plot, PLOT_RING, false, PLOT_RING_WIDTH)
	for row: int in rows:
		var y: float = plot.position.y + plot.size.y * float(row) / float(rows - 1)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID_COLOR, 2.0)
	draw_line(plot.position, Vector2(plot.position.x, plot.end.y), AXIS_COLOR, 2.0)
	draw_line(Vector2(plot.position.x, plot.end.y), plot.end, AXIS_COLOR, 2.0)
	if is_empty():
		return
	_draw_axis_labels(plot)
	var focus: int = _focus_index()
	_draw_y_labels(plot, focus)
	for entry: Dictionary in _series:
		_draw_ghost(entry, plot)
	for i: int in _series.size():
		if i != focus:
			_draw_series(_series[i], plot, false)
	if focus >= 0:
		_draw_series(_series[focus], plot, true)
	_draw_hover(plot)


#A tick and a caption every few buckets, stepped off the first one.
func _draw_axis_labels(plot: Rect2) -> void:
	var count: int = _longest_count()
	if count <= 0:
		return
	var font: Font = FONT
	var baseline: float = plot.end.y + 18.0
	for i: int in _label_indices(count):
		var x: float = plot.position.x + x_for(i, count, plot.size.x)
		draw_line(Vector2(x, plot.end.y), Vector2(x, plot.end.y + TICK_HEIGHT), AXIS_COLOR,
			TICK_WIDTH)
		var text: String = x_label(bucket_name, i)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		var left: float = clampf(x - width * 0.5, plot.position.x, maxf(plot.position.x,
			plot.end.x - width))
		draw_string(font, Vector2(left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE,
			LABEL_COLOR)


#Five rows off the focused band, right aligned into the left pad in that metric's colour.
func _draw_y_labels(plot: Rect2, index: int) -> void:
	if index < 0:
		return
	var entry: Dictionary = _series[index]
	var points: Array[Dictionary] = []
	points.assign(entry["points"])
	var band: Vector2 = _entry_band(entry)
	var values: Array[float] = y_label_values(band.x, band.y)
	var fmt: String = String(entry.get("fmt", "float"))
	var color: Color = LABEL_COLOR
	if entry.has("color"):
		color = entry["color"]
	var font: Font = FONT
	for row: int in values.size():
		var text: String = axis_text(values[row], fmt, band.y - band.x)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		var y: float = plot.end.y - plot.size.y * float(row) / float(values.size() - 1)
		draw_string(font, Vector2(plot.position.x - 8.0 - width, y + 3.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)


func _draw_series(entry: Dictionary, plot: Rect2, focused: bool) -> void:
	var points: Array[Dictionary] = []
	points.assign(entry["points"])
	if points.is_empty():
		return
	var color: Color = Color.WHITE
	if entry.has("color"):
		color = entry["color"]
	if not focused:
		color.a = DIM_ALPHA
	var chart_scale: float = float(maxi(1, pixel_scale))
	var band: Vector2 = _entry_band(entry)
	var runs: Array[PackedVector2Array] = _segments(points, band, plot, _shown_count(points.size()))
	for run: PackedVector2Array in runs:
		if run.size() > 1:
			draw_polyline(run, color, (2.0 if focused else 1.0) * chart_scale)
	if points.size() > DOT_LIMIT:
		return
	var dot: float = (POINT_SIZE + (1.0 if focused else 0.0)) * chart_scale
	for run: PackedVector2Array in runs:
		for spot: Vector2 in run:
			draw_rect(Rect2(spot - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), color)


#The comparison line under a series: same band, thicker, faint, no markers.
func _draw_ghost(entry: Dictionary, plot: Rect2) -> void:
	var ghost: Array[Dictionary] = []
	ghost.assign(entry.get("ghost", []))
	if ghost.is_empty():
		return
	var color: Color = Color.WHITE
	if entry.has("color"):
		color = entry["color"]
	color.a = GHOST_ALPHA
	var chart_scale: float = float(maxi(1, pixel_scale))
	var band: Vector2 = _entry_band(entry)
	for run: PackedVector2Array in _segments(ghost, band, plot, _shown_count(ghost.size())):
		if run.size() > 1:
			draw_polyline(run, color, GHOST_WIDTH * chart_scale)


#The hovered bucket: one upright line down the plot and a boxed dot on every drawn series.
func _draw_hover(plot: Rect2) -> void:
	if _hovered < 0 or _series.is_empty():
		return
	var first: Array[Dictionary] = []
	first.assign(_series[0]["points"])
	if _hovered >= first.size():
		return
	var x: float = plot.position.x + x_for(_hovered, first.size(), plot.size.x)
	var cross: Color = CROSS_COLOR
	cross.a = CROSS_ALPHA
	draw_line(Vector2(x, PAD_TOP), Vector2(x, plot.end.y), cross, 2.0)
	for entry: Dictionary in _series:
		var points: Array[Dictionary] = []
		points.assign(entry["points"])
		if _hovered >= points.size():
			continue
		if is_nan(float(points[_hovered].get("value", 0.0))):
			continue
		var color: Color = Color.WHITE
		if entry.has("color"):
			color = entry["color"]
		var band: Vector2 = _entry_band(entry)
		var heights: PackedFloat32Array = normalize(points, plot.size.y, band.x, band.y)
		var spot := Vector2(x, plot.end.y - heights[_hovered])
		var box := Rect2(spot - Vector2(HOVER_DOT, HOVER_DOT) * 0.5, Vector2(HOVER_DOT, HOVER_DOT))
		draw_rect(box, color)
		draw_rect(box, HOVER_EDGE, false, HOVER_EDGE_WIDTH)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_at((event as InputEventMouseMotion).position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and is_node_ready():
		hide_tip()
