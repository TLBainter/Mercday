class_name WeekBars extends Control

#The vacation bars of one week row, laid over its day cells. Bars take the lowest free lane of
#LANES; lanes 2 and 3 overlap the lane before them by half a lane. A pending span is dashed, a span
#that ended before today is faded, and the spans no lane can take show as one "+N" chip at the row end.
#Only a bar takes the pointer; MonthGrid reads a click on one through bar_at.

const LANES: int = 4
const LANE_H: float = 12.0
#Lane tops in lane heights, measured down from the top of the lane area.
const LANE_TOPS: Array[float] = [0.0, 1.0, 1.5, 2.0]
const BOTTOM_PAD: float = 4.0
const TEXT_SIZE: int = 9
const TEXT_PAD: float = 3.0
const DASH: float = 3.0
const PAST_ALPHA: float = 0.4
const PENDING_FILL_ALPHA: float = 0.35
const BAR_COLOR: Color = GuiColors.LIGHT_BLUE
const BAR_TEXT: Color = GuiColors.INK
const CHIP_FILL: Color = GuiColors.DIM_TEXT

#Pixel gap between day columns, set by MonthGrid to match the cell row.
var cell_gap: float = 2.0
#The drawn bars: {uid, name, lane, rect, dashed, faded, color, event}, sorted by lane, low to high.
var bars: Array[Dictionary] = []
#How many spans found no lane, and where their chip sits.
var more: int = 0
var chip_rect: Rect2 = Rect2()

var _spans: Array[Dictionary] = []
var _first_day: int = 0
var _columns: int = 0
var _today: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_relayout)


#spans are CalendarEvents.spans rows; first_day is the day in column 0; columns is how many cells hold a day.
func show_spans(spans: Array[Dictionary], first_day: int, columns: int, today: int) -> void:
	_spans = spans.duplicate()
	_first_day = first_day
	_columns = columns
	_today = today
	_relayout()


func more_text() -> String:
	return "+%d" % more if more > 0 else ""


#Offset of a lane's top from the top of the row.
func lane_top(lane: int) -> float:
	return size.y - BOTTOM_PAD - LANE_H * (LANE_TOPS[LANES - 1] + 1.0) + LANE_H * LANE_TOPS[lane]


func column_width() -> float:
	return (size.x - cell_gap * 9.0) / 10.0


func _relayout() -> void:
	bars.clear()
	more = 0
	chip_rect = Rect2()
	var rows: Array[Dictionary] = []
	for span: Dictionary in _spans:
		var start: int = maxi(int(span["start"]), _first_day)
		var stop: int = mini(int(span["start"]) + int(span["days"]) - 1, _first_day + _columns - 1)
		if stop >= start:
			rows.append({"span": span, "start": start, "stop": stop})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["start"]) < int(b["start"]) or (a["start"] == b["start"] and int(a["stop"]) > int(b["stop"])))
	var lane_end: Array[int] = []
	lane_end.resize(LANES)
	lane_end.fill(-2147483648)
	for row: Dictionary in rows:
		var lane: int = lane_end.find_custom(func(last: int) -> bool: return last < int(row["start"]))
		if lane < 0:
			more += 1
			continue
		lane_end[lane] = int(row["stop"])
		bars.append(_bar(row, lane))
	bars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["lane"]) < int(b["lane"]))
	if more > 0:
		var font: Font = GuiStyle.SILK_BOLD
		var span_size: Vector2 = font.get_string_size(more_text(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, TEXT_SIZE)
		var chip_w: float = ceilf(span_size.x + TEXT_PAD * 2.0)
		chip_rect = Rect2(size.x - chip_w, lane_top(0) - LANE_H, chip_w, LANE_H)
	queue_redraw()


func _bar(row: Dictionary, lane: int) -> Dictionary:
	var span: Dictionary = row["span"]
	var step: float = column_width() + cell_gap
	var left: float = (int(row["start"]) - _first_day) * step
	var right: float = (int(row["stop"]) - _first_day) * step + column_width()
	return {
		"uid": span.get("uid", ""),
		"name": str(span.get("name", "")),
		"lane": lane,
		"rect": Rect2(left, lane_top(lane), right - left, LANE_H),
		"dashed": int(span.get("state", -1)) == VacationRequest.State.PENDING,
		"faded": int(span["start"]) + int(span["days"]) - 1 < _today,
		"color": span.get("color", BAR_COLOR),
		"event": span.get("event", null),
	}


#The topmost drawn bar under point, in this row's coordinates; {} when none.
func bar_at(point: Vector2) -> Dictionary:
	for i: int in range(bars.size() - 1, -1, -1):
		if (bars[i]["rect"] as Rect2).has_point(point):
			return bars[i]
	return {}


func _has_point(point: Vector2) -> bool:
	return not bar_at(point).is_empty()


func _draw() -> void:
	var font: Font = GuiStyle.SILK_BOLD
	for bar: Dictionary in bars:
		var rect: Rect2 = bar["rect"]
		var tone: Color = bar["color"]
		if bar["faded"]:
			tone.a *= PAST_ALPHA
		if bar["dashed"]:
			draw_rect(rect, Color(tone, tone.a * PENDING_FILL_ALPHA))
			_dash_ring(rect.grow(-0.5), tone)
		else:
			draw_rect(rect, tone)
		var baseline: float = rect.position.y + (LANE_H + font.get_ascent(TEXT_SIZE)) / 2.0 - 1.0
		draw_string(font, Vector2(rect.position.x + TEXT_PAD, baseline), str(bar["name"]), HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - TEXT_PAD * 2.0, TEXT_SIZE, Color(BAR_TEXT, tone.a))
	if more > 0:
		draw_rect(chip_rect, CHIP_FILL)
		var chip_base: float = chip_rect.position.y + (LANE_H + font.get_ascent(TEXT_SIZE)) / 2.0 - 1.0
		draw_string(font, Vector2(chip_rect.position.x + TEXT_PAD, chip_base), more_text(), HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, TEXT_SIZE, BAR_TEXT)


func _dash_ring(rect: Rect2, tone: Color) -> void:
	var corners: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], tone, 1.0, DASH)
