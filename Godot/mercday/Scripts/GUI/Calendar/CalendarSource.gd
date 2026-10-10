class_name CalendarSource extends Resource

#One kind of calendar event. A subclass reads one service and maps its rows to CalendarEvents; the
#type label, icon and colour are edited on the sub-resource in CalendarDialog.tscn. type is the filter key.

@export var type: StringName = &""
@export var label: String = ""
@export var icon_id: String = ""
@export var color: Color = Color.WHITE


#The events on day indexes d0 through d1, both included.
func events_between(_d0: int, _d1: int) -> Array[CalendarEvent]:
	return []


#The multi-day bars on day indexes d0 through d1: {uid, name, start, days, state} rows.
func spans_between(_d0: int, _d1: int) -> Array[Dictionary]:
	return []


#A click on one of this source's rows.
func activate(_event: CalendarEvent, _dialog: Node) -> void:
	pass


#The pointer resting on one of this source's rows.
func hover(_event: CalendarEvent, _row: Control, _dialog: Node) -> void:
	pass


#The signals that change what events_between returns.
func change_signals() -> Array[Signal]:
	return []


#One event of this source on that day; past is read off today.
func make_event(day: int, title: String, sub: String, ref: Variant) -> CalendarEvent:
	var event := CalendarEvent.new()
	event.source = self
	event.day = day
	event.title = title
	event.sub = sub
	event.past = day < GameState.day()
	event.ref = ref
	return event


#Whether day index day lies inside d0 through d1.
static func within(day: int, d0: int, d1: int) -> bool:
	return day >= d0 and day <= d1
