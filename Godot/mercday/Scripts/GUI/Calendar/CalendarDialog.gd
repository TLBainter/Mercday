class_name CalendarDialog extends ModalDialog

#The calendar: a month grid with its nav on the left, the selected day's events and the type filter
#on the right. It holds the shown month and the selected day; while open it redraws once per frame
#at most when a source or the day changes. The event types are the sources sub-resources on this
#scene; a source opens its crew tooltip, order dialog or mail dialog on the calendar's own instances.

@export var sources: Array[CalendarSource] = []

@onready var nav: MonthNav = $Box/Pad/Rows/Body/Left/MonthNav
@onready var grid: MonthGrid = $Box/Pad/Rows/Body/Left/MonthGrid
@onready var detail: DayDetail = $Box/Pad/Rows/Body/Right/DayDetail
@onready var filter: CalendarFilter = $Box/Pad/Rows/Body/Right/Filter
@onready var crew_tip: ReturningCrewTooltip = $Tip
@onready var order_dialog: OrderDialog = $Order
@onready var mail_dialog: MailDialog = $Mail

var events: CalendarEvents = null
var shown_year: int = TrynnCalendar.START_YEAR
var shown_month: int = 0
var selected_day: int = 0
var _dirty: bool = false


func _ready() -> void:
	super()
	events = CalendarEvents.new(sources)
	filter.build(sources)
	nav.step.connect(step_month)
	nav.today_pressed.connect(go_today)
	grid.day_selected.connect(select_day)
	grid.bar_pressed.connect(_on_bar_pressed)
	filter.filters_changed.connect(refresh)
	detail.host = self
	detail.row_left.connect(crew_tip.hide_tip)
	crew_tip.beside = detail
	closed.connect(_on_closed)


#Opens on the month of day with that day selected; an open dialog moves there.
func open_on(day: int) -> void:
	_show_day_month(day)
	selected_day = day
	if not is_open():
		present()
	refresh()


func step_month(delta: int) -> void:
	var next: Vector2i = TrynnCalendar.step_month(shown_year, shown_month, delta)
	shown_year = next.x
	shown_month = next.y
	refresh()


func go_today() -> void:
	open_on(GameState.day())


func select_day(day: int) -> void:
	selected_day = day
	grid.set_selected(day)
	_show_detail()


func month_text() -> String:
	return nav.month_label.text


func refresh() -> void:
	_dirty = false
	nav.show_month(shown_year, shown_month)
	grid.show_month(shown_year, shown_month, events, selected_day, GameState.day())
	_show_detail()


func _on_present() -> void:
	filter.sync()
	events.watch(true)
	if not events.changed.is_connected(_queue_refresh):
		events.changed.connect(_queue_refresh)
	if not GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.connect(_on_day_changed)


func _on_closed() -> void:
	crew_tip.hide_tip()
	if order_dialog.is_open():
		order_dialog.close()
	if mail_dialog.is_open():
		mail_dialog.close()
	events.watch(false)
	if events.changed.is_connected(_queue_refresh):
		events.changed.disconnect(_queue_refresh)
	if GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.disconnect(_on_day_changed)


#A week bar click: MonthGrid has selected the clicked day; the bar's event goes to its source.
func _on_bar_pressed(event: CalendarEvent) -> void:
	if event != null:
		event.source.activate(event, self)


func _on_day_changed(_day: int) -> void:
	_queue_refresh()


func _queue_refresh() -> void:
	if _dirty:
		return
	_dirty = true
	refresh.call_deferred()


#The selected day's events in DayDetail, filtered as the grid is.
func _show_detail() -> void:
	var day_events: Array[CalendarEvent] = []
	day_events.assign(events.by_day(selected_day, selected_day).get(selected_day, []))
	detail.show_day(selected_day, GameState.day(), day_events)


func _show_day_month(day: int) -> void:
	var date: Dictionary = TrynnCalendar.date_of(day * TrynnCalendar.MINUTES_PER_DAY)
	shown_year = int(date["year"])
	shown_month = int(date["month"])
