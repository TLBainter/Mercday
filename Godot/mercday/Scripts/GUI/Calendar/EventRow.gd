class_name EventRow extends ListRow

#One calendar event in the day list: the type icon, the title and the sub line. The click and the
#hover go out with the event, so DayDetail hands them to its source and the row knows no type.

signal activated(event: CalendarEvent)
signal hovered(event: CalendarEvent)
signal unhovered

const ROW_HEIGHT: int = 48
const ICON_SCALE: int = 2

@onready var icon_rect: IconRect = $Row/Icon
@onready var title_label: Label = $Row/Texts/Title
@onready var sub_label: Label = $Row/Texts/Sub

var event: CalendarEvent = null


func _ready() -> void:
	super()
	custom_minimum_size.y = ROW_HEIGHT
	pressed.connect(func() -> void: activated.emit(event))
	mouse_entered.connect(func() -> void: hovered.emit(event))
	mouse_exited.connect(unhovered.emit)
	_refresh()


func set_event(new_event: CalendarEvent) -> void:
	event = new_event
	_refresh()


func title_text() -> String:
	return title_label.text if is_node_ready() else ""


func sub_text() -> String:
	return sub_label.text if is_node_ready() else ""


func _refresh() -> void:
	if not is_node_ready() or event == null:
		return
	icon_rect.set_id(event.source.icon_id, ICON_SCALE)
	title_label.text = event.title
	sub_label.text = event.sub
	sub_label.visible = event.sub != ""
