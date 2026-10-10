class_name DayDetail extends ListPanel

#The selected day's events under its date and how far it lies from today. A row's click and hover
#go to the event's own source with the calendar as host; row_left goes out when the pointer leaves.

signal row_left

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Calendar/EventRow.tscn")

#The calendar the sources open their dialogs and tooltip on.
var host: Node = null
var day: int = 0


func show_day(on_day: int, today: int, events: Array[CalendarEvent]) -> void:
	day = on_day
	head.caption = TrynnCalendar.date_text(on_day * TrynnCalendar.MINUTES_PER_DAY)
	head.count_text = relative_text(on_day, today)
	clear_items()
	row_left.emit()
	for event: CalendarEvent in events:
		var row: EventRow = ROW_SCENE.instantiate() as EventRow
		items().add_child(row)
		row.set_event(event)
		row.activated.connect(_on_activated)
		row.hovered.connect(_on_hovered.bind(row))
		row.unhovered.connect(row_left.emit)


func rows() -> Array[EventRow]:
	var out: Array[EventRow] = []
	for child: Node in items().get_children():
		if child is EventRow:
			out.append(child as EventRow)
	return out


#"Today", "4 Days From Now" or "3 Days Ago".
static func relative_text(on_day: int, today: int) -> String:
	if on_day < today:
		return GuiDates.ago_text(today - on_day)
	return GuiDates.from_now_text(on_day - today)


func _on_activated(event: CalendarEvent) -> void:
	event.source.activate(event, host)


func _on_hovered(event: CalendarEvent, row: EventRow) -> void:
	event.source.hover(event, row, host)
