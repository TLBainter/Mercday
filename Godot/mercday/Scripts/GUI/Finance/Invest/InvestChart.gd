class_name InvestChart extends Control

#The price chart: a 120 x 70 cell grid stretched over the plot, one interpolated row per column,
#a hard shadow one cell down and right, a checker area under the line, five grid lines with their
#labels, the calendar ticks below, the average cost line and the hover readout.

const COLS: int = 120
const ROWS: int = 70
const PAD_LEFT: float = 14.0
const PAD_TOP: float = 14.0
const PAD_RIGHT: float = 62.0
const PAD_BOTTOM: float = 30.0
const MAX_SAMPLES: float = 240.0
const PAD_RATIO: float = 0.1
const FLAT_PAD_RATIO: float = 0.02
const GRID_LINES: int = 5
const GRID_BASE: float = 0.08
const GRID_STEP: float = 0.21
const GRID_WIDTH: float = 2.0
const AREA_ALPHA: float = 0.22
const COST_PERIOD: int = 4
const COST_ON: int = 2
const TICK_MARK: Vector2 = Vector2(2.0, 5.0)
const HOVER_WIDTH: float = 2.0
const HOVER_ALPHA: float = 0.6
const HOVER_SQUARE: float = 12.0
const HOVER_FLIP: float = 0.55
const TIP_GAP: float = 14.0
const TIP_WIDTH: float = 240.0
const REVEAL_SECONDS: float = 0.8
const REVEAL_STEPS: int = 48
const EVENT_MARK_WIDTH: float = 6.0
const EVENT_MARK: Vector2 = Vector2(EVENT_MARK_WIDTH, 8.0)
const EVENT_ROWS_VISIBLE: int = 3
const WHEEL_STEP: float = 16.0
const TIP_PAD_X: float = 20.0
const FRAME_PAD_X: float = 16.0
const FRAME_SLACK: float = 4.0
const SCROLL_GUTTER: float = 12.0
const ROW_GAP: int = 6
#The event text width: what the tip leaves after its margins, the frame, the gutter, the mark and the gap.
const ROW_TEXT_WIDTH: float = (TIP_WIDTH - TIP_PAD_X - FRAME_PAD_X - FRAME_SLACK - SCROLL_GUTTER
	- EVENT_MARK_WIDTH - ROW_GAP)
const FONT_SMALL: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")

#The suite seam: the wipe finishes at once so no case waits on the tween.
static var instant_reveal: bool = false

signal hover_changed(sample: int)

@onready var hover_tip: PanelContainer = $HoverTip
@onready var tip_date: Label = $HoverTip/Col/DateLabel
@onready var tip_price: Label = $HoverTip/Col/PriceLabel
@onready var tip_change: Label = $HoverTip/Col/ChangeLabel
@onready var event_frame: PanelContainer = $HoverTip/Col/EventFrame
@onready var event_scroll: ScrollContainer = $HoverTip/Col/EventFrame/EventScroll
@onready var tip_events: VBoxContainer = $HoverTip/Col/EventFrame/EventScroll/EventRows

var company_id: int = -1
var range_key: String = "1Y"

var _idx: PackedInt32Array = PackedInt32Array()
var _values: PackedFloat32Array = PackedFloat32Array()
var _rows: PackedInt32Array = PackedInt32Array()
var _i0: int = 0
var _lo: float = 0.0
var _hi: float = 1.0
var _avg: float = 0.0
var _shares: int = 0
var _hover: int = -1
var _reveal: float = 1.0
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hover_tip.visible = false
	hover_tip.custom_minimum_size.x = TIP_WIDTH
	event_scroll.get_h_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_scroll.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_tip.minimum_size_changed.connect(_refit_tip, CONNECT_DEFERRED)
	tip_events.minimum_size_changed.connect(_fit_scroll, CONNECT_DEFERRED)
	mouse_exited.connect(clear_hover)
	resized.connect(queue_redraw)


func set_series(company: int, key: String) -> void:
	company_id = company
	range_key = key
	_hover = -1
	_rebuild()
	_sync_tip()
	queue_redraw()


func sample_count() -> int:
	return _idx.size()


func sample_index(j: int) -> int:
	if j < 0 or j >= _idx.size():
		return -1
	return _idx[j]


func low() -> float:
	return _lo


func high() -> float:
	return _hi


func row_of(value: float) -> int:
	var span: float = _hi - _lo
	if span <= 0.0:
		return ROWS - 1
	return clampi(int(round((1.0 - (value - _lo) / span) * float(ROWS - 1))), 0, ROWS - 1)


func column_rows() -> PackedInt32Array:
	return _rows.duplicate()


func line_color() -> Color:
	if _values.is_empty():
		return InvestText.GREEN
	var first: float = _values[0]
	var last: float = _values[_values.size() - 1]
	return InvestText.GREEN if last >= first else InvestText.RED


func has_cost_line() -> bool:
	return _shares > 0 and _avg > 0.0


func cost_row() -> int:
	return row_of(_avg)


func cost_text() -> String:
	return "Your avg cost %s" % InvestText.price_text(_avg)


func grid_labels() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for g: int in GRID_LINES:
		out.append(InvestText.price_text(_grid_value(g)))
	return out


func tick_rows() -> Array[Dictionary]:
	return StockMarket.tick_labels(range_key)


#x_ratio is 0 at the left edge of the plot and 1 at its right edge.
func hover_at(x_ratio: float) -> void:
	if _idx.size() < 2:
		return
	var j: int = clampi(int(round(clampf(x_ratio, 0.0, 1.0) * float(_idx.size() - 1))), 0,
		_idx.size() - 1)
	if j == _hover:
		return
	_hover = j
	_sync_tip()
	hover_changed.emit(_hover)
	queue_redraw()


func clear_hover() -> void:
	if _hover < 0:
		return
	_hover = -1
	_sync_tip()
	hover_changed.emit(-1)
	queue_redraw()


func hovered() -> int:
	return _hover


func hover_price() -> float:
	if _values.is_empty():
		return 0.0
	if _hover < 0 or _hover >= _values.size():
		return _values[_values.size() - 1]
	return _values[_hover]


#date, price, change, change_color, events and the side the card sits on.
func hover_texts() -> Dictionary:
	if _hover < 0 or _values.is_empty():
		return {}
	var px: float = _values[_hover]
	var first: float = _values[0]
	var pct: float = (px / first - 1.0) * 100.0 if first > 0.0 else 0.0
	var from_day: int = StockMarket.day_of_index(_i0)
	return {
		"date": GuiDates.short_text(StockMarket.day_of_index(_idx[_hover])),
		"price": "%s per share" % InvestText.price_text(px),
		"change": "%s since %s" % [InvestText.change_text(pct), GuiDates.short_text(from_day)],
		"change_color": InvestText.gain_color(pct),
		"events": _events_at(_hover),
		"left_side": _hover_ratio() > HOVER_FLIP,
	}


func play_reveal() -> void:
	_kill_tween()
	if instant_reveal or not is_inside_tree():
		_reveal = 1.0
		queue_redraw()
		return
	_reveal = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_reveal, 0.0, 1.0, REVEAL_SECONDS)
	queue_redraw()


#Advance a live reveal by hand; nothing happens when no reveal runs.
func step_reveal(seconds: float) -> void:
	if _tween == null or not _tween.is_valid():
		return
	_tween.custom_step(maxf(0.0, seconds))


func finish_reveal() -> void:
	_kill_tween()
	_reveal = 1.0
	queue_redraw()


func reveal_ratio() -> float:
	return _reveal


func plot_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, maxf(1.0, size.x - PAD_LEFT - PAD_RIGHT),
		maxf(1.0, size.y - PAD_TOP - PAD_BOTTOM))


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _set_reveal(v: float) -> void:
	_reveal = snappedf(v, 1.0 / float(REVEAL_STEPS))
	queue_redraw()


func _rebuild() -> void:
	_idx = PackedInt32Array()
	_values = PackedFloat32Array()
	_rows = PackedInt32Array()
	_shares = 0
	_avg = 0.0
	var hist: PackedFloat32Array = StockMarket.history(company_id)
	if hist.is_empty():
		_lo = 0.0
		_hi = 1.0
		return
	var last: int = hist.size() - 1
	_i0 = clampi(StockMarket.range_start(range_key), 0, last)
	var span: int = last - _i0
	var step: int = maxi(1, int(ceil(float(span) / MAX_SAMPLES)))
	var i: int = _i0
	while i < last:
		_idx.append(i)
		i += step
	_idx.append(last)
	for at: int in _idx:
		_values.append(hist[at])
	var lo: float = _values[0]
	var hi: float = _values[0]
	for v: float in _values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var row: Dictionary = StockMarket.holding(company_id)
	_shares = int(row.get("shares", 0))
	_avg = float(row.get("avg", 0.0))
	if has_cost_line():
		lo = minf(lo, _avg)
		hi = maxf(hi, _avg)
	var pad: float = (hi - lo) * PAD_RATIO
	if is_zero_approx(pad):
		pad = hi * FLAT_PAD_RATIO
	_lo = lo - pad
	_hi = hi + pad
	_rows = _build_rows()


func _build_rows() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if _values.is_empty():
		return out
	var last: int = _values.size() - 1
	for c: int in COLS:
		var t: float = float(c) / float(COLS - 1) * float(last)
		var a: int = int(floor(t))
		var b: int = mini(last, a + 1)
		var v: float = _values[a] + (_values[b] - _values[a]) * (t - float(a))
		out.append(row_of(v))
	return out


#The cell run of column c: from the row next to the row of column c - 1 up to its own row.
func _column_run(c: int) -> Vector2i:
	var r: int = _rows[c]
	if c == 0:
		return Vector2i(r, r)
	var p: int = _rows[c - 1]
	if r > p:
		return Vector2i(p + 1, r)
	if r < p:
		return Vector2i(r, p - 1)
	return Vector2i(r, r)


func _grid_value(g: int) -> float:
	return _lo + (_hi - _lo) * (GRID_BASE + float(g) * GRID_STEP)


func _value_y(value: float) -> float:
	var plot: Rect2 = plot_rect()
	var span: float = _hi - _lo
	if span <= 0.0:
		return plot.end.y
	return plot.position.y + (1.0 - (value - _lo) / span) * plot.size.y


func _hover_ratio() -> float:
	if _hover < 0 or _idx.size() < 2:
		return 0.0
	return float(_column_of(_hover)) / float(COLS - 1)


func _column_of(j: int) -> int:
	if _idx.size() < 2:
		return 0
	return int(round(float(j) / float(_idx.size() - 1) * float(COLS - 1)))


#Every company event that lands inside the step of samples ending on sample j.
func _events_at(j: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if j < 0 or j >= _idx.size():
		return out
	var day0: int = StockMarket.day_of_index(0)
	var upper: int = _idx[j]
	var lower: int = _idx[j - 1] if j > 0 else _i0 - 1
	for row: Dictionary in StockMarket.events(company_id):
		var at: int = int(row.get("day", 0)) - day0
		if at <= lower or at > upper:
			continue
		out.append({"label": String(row.get("label", "")), "color": _event_color(row)})
	return out


static func _event_color(row: Dictionary) -> Color:
	if String(row.get("kind", "")) == "div":
		return InvestText.YELLOW
	return InvestText.GREEN if bool(row.get("win", false)) else InvestText.RED


func _sync_tip() -> void:
	if not is_node_ready():
		return
	GuiNodes.clear(tip_events)
	var texts: Dictionary = hover_texts()
	if texts.is_empty():
		hover_tip.visible = false
		return
	tip_date.text = String(texts["date"])
	tip_price.text = String(texts["price"])
	tip_change.text = String(texts["change"])
	tip_change.add_theme_color_override("font_color", texts["change_color"])
	var events: Array = texts["events"]
	for row: Variant in events:
		_add_event_row(row as Dictionary)
	event_frame.visible = not events.is_empty()
	event_scroll.scroll_vertical = 0
	_fit_scroll()
	hover_tip.visible = true
	hover_tip.reset_size()
	_place_tip(bool(texts["left_side"]))
	_refit_tip.call_deferred()


#The row joins the tree before its text is set, so the label wraps at its settled width.
func _add_event_row(row: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", ROW_GAP)
	var mark := ColorRect.new()
	mark.color = row["color"]
	mark.custom_minimum_size = EVENT_MARK
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(mark)
	var text := Label.new()
	text.custom_minimum_size.x = ROW_TEXT_WIDTH
	text.add_theme_color_override("font_color", InvestText.CREAM)
	text.add_theme_font_size_override("font_size", 12)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(text)
	tip_events.add_child(line)
	text.text = String(row["label"])


#The list is as tall as its first EVENT_ROWS_VISIBLE rows; the rest scroll.
func _fit_scroll() -> void:
	var shown: int = mini(tip_events.get_child_count(), EVENT_ROWS_VISIBLE)
	var gap: int = tip_events.get_theme_constant("separation")
	var height: int = 0
	for i: int in shown:
		var line: Control = tip_events.get_child(i) as Control
		height += int(line.get_combined_minimum_size().y) + (gap if i > 0 else 0)
	event_scroll.custom_minimum_size.y = float(height)


#A stored size is never lowered by a smaller minimum, so the tip is re-fitted once the layout settles.
func _refit_tip() -> void:
	if hover_tip.visible:
		hover_tip.reset_size()


func _place_tip(left_side: bool) -> void:
	var plot: Rect2 = plot_rect()
	var x: float = plot.position.x + _hover_ratio() * plot.size.x
	var at_x: float = x - TIP_GAP - TIP_WIDTH if left_side else x + TIP_GAP
	hover_tip.position = Vector2(clampf(at_x, 0.0, maxf(0.0, size.x - TIP_WIDTH)),
		plot.position.y + 8.0)


#The wheel over the chart moves the tip list once it holds more rows than it shows.
func _scroll_tip(wheel: InputEventMouseButton) -> bool:
	var up: bool = wheel.button_index == MOUSE_BUTTON_WHEEL_UP
	if not up and wheel.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	if not hover_tip.visible or tip_events.get_child_count() <= EVENT_ROWS_VISIBLE:
		return false
	var step: int = maxi(1, roundi(WHEEL_STEP * wheel.factor))
	var delta: int = -step if up else step
	event_scroll.scroll_vertical += delta
	return true


func _gui_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel != null:
		if wheel.pressed and _scroll_tip(wheel):
			accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	var plot: Rect2 = plot_rect()
	if not plot.has_point(motion.position):
		clear_hover()
		return
	hover_at((motion.position.x - plot.position.x) / plot.size.x)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), InvestText.NAVY, true)
	var plot: Rect2 = plot_rect()
	_draw_grid(plot)
	if _rows.is_empty():
		return
	var cell := Vector2(plot.size.x / float(COLS), plot.size.y / float(ROWS))
	var cutoff: int = clampi(int(floor(_reveal * float(COLS))), 0, COLS)
	var tint: Color = line_color()
	var area := Color(tint, AREA_ALPHA)
	for c: int in cutoff:
		var run: Vector2i = _column_run(c)
		for y: int in range(run.x, run.y + 1):
			_cell(plot, cell, c + 1, y + 1, InvestText.INK)
		for y: int in range(_rows[c] + 2, ROWS):
			if (c + y) % 2 == 0:
				_cell(plot, cell, c, y, area)
		for y: int in range(run.x, run.y + 1):
			_cell(plot, cell, c, y, tint)
	if has_cost_line():
		_draw_cost(plot, cell)
	_draw_ticks(plot)
	if _hover >= 0:
		_draw_hover(plot, cell, tint)


func _cell(plot: Rect2, cell: Vector2, c: int, y: int, tint: Color) -> void:
	if c < 0 or c >= COLS or y < 0 or y >= ROWS:
		return
	draw_rect(Rect2(plot.position.x + float(c) * cell.x, plot.position.y + float(y) * cell.y,
		cell.x + 1.0, cell.y + 1.0), tint, true)


func _draw_grid(plot: Rect2) -> void:
	for g: int in GRID_LINES:
		var value: float = _grid_value(g)
		var y: float = _value_y(value)
		draw_rect(Rect2(plot.position.x, y - GRID_WIDTH / 2.0, plot.size.x, GRID_WIDTH),
			InvestText.NAVY2, true)
		draw_string(FONT_SMALL, Vector2(plot.end.x + 8.0, y + 3.0), InvestText.price_text(value),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, InvestText.MUTED)


func _draw_cost(plot: Rect2, cell: Vector2) -> void:
	var row: int = cost_row()
	for c: int in COLS:
		if c % COST_PERIOD < COST_ON:
			_cell(plot, cell, c, row, InvestText.YELLOW)
	var at := Vector2(plot.position.x + 4.0, plot.position.y + float(row) * cell.y - 4.0)
	var text: String = cost_text()
	var box: Vector2 = FONT_SMALL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9)
	draw_rect(Rect2(at + Vector2(-2.0, -box.y), box + Vector2(4.0, 2.0)), InvestText.NAVY, true)
	draw_string(FONT_SMALL, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, InvestText.YELLOW)


func _draw_ticks(plot: Rect2) -> void:
	for row: Dictionary in tick_rows():
		var x: float = plot.position.x + float(row["x"]) * plot.size.x
		draw_rect(Rect2(x - TICK_MARK.x / 2.0, plot.end.y + 4.0, TICK_MARK.x, TICK_MARK.y),
			InvestText.BLUE3, true)
		var label: String = String(row["label"])
		var box: Vector2 = FONT_SMALL.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8)
		var align: String = String(row["align"])
		var at_x: float = x
		if align == "center":
			at_x = x - box.x / 2.0
		elif align == "end":
			at_x = x - box.x
		draw_string(FONT_SMALL, Vector2(at_x, plot.end.y + 22.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, InvestText.SKY)


func _draw_hover(plot: Rect2, cell: Vector2, tint: Color) -> void:
	var c: int = clampi(_column_of(_hover), 0, _rows.size() - 1)
	var x: float = plot.position.x + (float(c) + 0.5) * cell.x
	var line := Color(InvestText.SKY, HOVER_ALPHA)
	draw_rect(Rect2(x - HOVER_WIDTH / 2.0, plot.position.y, HOVER_WIDTH, plot.size.y), line, true)
	var y: float = plot.position.y + (float(_rows[c]) + 0.5) * cell.y
	draw_rect(Rect2(x - HOVER_SQUARE / 2.0, y - HOVER_SQUARE / 2.0, HOVER_SQUARE, HOVER_SQUARE),
		tint, true)
