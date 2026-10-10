class_name CalendarButton extends BarIconButton

#The calendar toggle beside the clock. It makes its CalendarDialog on first use, opens it on today or
#on the day GameState.open_calendar_requested names, and stays pressed while the dialog is open.

const DIALOG_SCENE: String = "res://Scenes/GUI/Calendar/CalendarDialog.tscn"
const TOOLTIP: String = "Calendar"

var _dialog: CalendarDialog = null


func _ready() -> void:
	super()
	tooltip_text = TOOLTIP
	toggled.connect(_on_toggled)
	GameState.open_calendar_requested.connect(open_on)


func _face_id() -> String:
	return "calendar"


func dialog() -> CalendarDialog:
	if _dialog != null and is_instance_valid(_dialog):
		return _dialog
	_dialog = (load(DIALOG_SCENE) as PackedScene).instantiate() as CalendarDialog
	add_child(_dialog)
	_dialog.closed.connect(_on_dialog_closed)
	return _dialog


#Opens the dialog on the month of day with day selected; an open dialog moves there instead.
func open_on(day: int) -> void:
	set_pressed_no_signal(true)
	queue_redraw()
	dialog().open_on(day)


func _on_toggled(on: bool) -> void:
	if on:
		open_on(GameState.day())
	elif _dialog != null and is_instance_valid(_dialog) and _dialog.is_open():
		_dialog.close()


func _on_dialog_closed() -> void:
	set_pressed_no_signal(false)
	queue_redraw()
