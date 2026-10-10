class_name MonthGrid extends VBoxContainer

#The month as a weekday header over ROWS fixed week rows of COLUMNS day cells, with the vacation bars
#of each week laid over its row. Every month starts on Belday, so a 30-day month leaves row 4 empty.

signal day_selected(day: int)
#A week bar was clicked; the clicked day is selected first.
signal bar_pressed(event: CalendarEvent)

const COLUMNS: int = 10
const ROWS: int = 4
const CELL_SIZE: Vector2 = Vector2(68.0, 100.0)
const GAP: float = 2.0

var header: HBoxContainer = null
var weeks: VBoxContainer = null
var cells: Array[DayCell] = []
var week_bars: Array[WeekBars] = []
var first_day: int = 0
var day_count: int = 0


func _ready() -> void:
	add_theme_constant_override(&"separation", 6)
	header = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override(&"separation", int(GAP))
	add_child(header)
	for weekday: String in TrynnCalendar.WEEKDAYS:
		var label := Label.new()
		label.text = weekday
		label.theme_type_variation = &"CaptionLabel"
		label.custom_minimum_size.x = CELL_SIZE.x
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		header.add_child(label)
	weeks = VBoxContainer.new()
	weeks.name = "Weeks"
	weeks.add_theme_constant_override(&"separation", int(GAP))
	add_child(weeks)
	for row: int in ROWS:
		_add_week(row)


func weekday_labels() -> Array[Label]:
	var out: Array[Label] = []
	for child: Node in header.get_children():
		if child is Label:
			out.append(child as Label)
	return out


#The cells that hold a day of the shown month.
func filled_cells() -> Array[DayCell]:
	var out: Array[DayCell] = []
	for cell: DayCell in cells:
		if cell.visible:
			out.append(cell)
	return out


func cell_of(day: int) -> DayCell:
	var at: int = day - first_day
	return cells[at] if at >= 0 and at < day_count else null


#Fills the cells and bars for that month; events may be null for an empty grid.
func show_month(year: int, month: int, events: CalendarEvents, selected: int, today: int) -> void:
	first_day = TrynnCalendar.month_first_day(year, month)
	day_count = int(TrynnCalendar.MONTHS[month]["days"])
	var last_day: int = first_day + day_count - 1
	var days: Dictionary = {}
	var spans: Array[Dictionary] = []
	if events != null:
		days = events.by_day(first_day, last_day)
		spans = events.spans(first_day, last_day)
	var none: Array[CalendarEvent] = []
	for i: int in cells.size():
		var cell: DayCell = cells[i]
		cell.visible = i < day_count
		if not cell.visible:
			cell.selected = false
			continue
		var day: int = first_day + i
		var listed: Array[CalendarEvent] = days.get(day, none)
		var column: int = i % COLUMNS
		cell.show_day(day, i + 1, today, column == 0 or column == COLUMNS - 1, listed)
		cell.selected = day == selected
	for row: int in week_bars.size():
		var row_first: int = first_day + row * COLUMNS
		week_bars[row].show_spans(spans, row_first, clampi(day_count - row * COLUMNS, 0, COLUMNS), today)


func set_selected(day: int) -> void:
	for cell: DayCell in cells:
		cell.selected = cell.visible and cell.day == day


func _add_week(row: int) -> void:
	var holder := Control.new()
	holder.name = "Week%d" % (row + 1)
	holder.custom_minimum_size = Vector2(CELL_SIZE.x * COLUMNS + GAP * (COLUMNS - 1), CELL_SIZE.y)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weeks.add_child(holder)
	var row_cells := HBoxContainer.new()
	row_cells.name = "Cells"
	row_cells.add_theme_constant_override(&"separation", int(GAP))
	row_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row_cells)
	row_cells.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for column: int in COLUMNS:
		var cell := DayCell.new()
		cell.name = "Day%d" % (row * COLUMNS + column + 1)
		cell.custom_minimum_size = CELL_SIZE
		cell.pressed.connect(_on_cell_pressed.bind(cell))
		row_cells.add_child(cell)
		cells.append(cell)
	var bars := WeekBars.new()
	bars.name = "Bars"
	bars.cell_gap = GAP
	bars.gui_input.connect(_on_bars_input.bind(bars))
	holder.add_child(bars)
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	week_bars.append(bars)


func _on_cell_pressed(cell: DayCell) -> void:
	set_selected(cell.day)
	day_selected.emit(cell.day)


func _on_bars_input(ev: InputEvent, row_bars: WeekBars) -> void:
	var click: InputEventMouseButton = ev as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var bar: Dictionary = row_bars.bar_at(click.position)
	if bar.is_empty():
		return
	row_bars.accept_event()
	var column: int = clampi(int(click.position.x / (row_bars.column_width() + row_bars.cell_gap)), 0, COLUMNS - 1)
	var cell: DayCell = cells[week_bars.find(row_bars) * COLUMNS + column]
	if cell.visible:
		_on_cell_pressed(cell)
	bar_pressed.emit(bar["event"])
