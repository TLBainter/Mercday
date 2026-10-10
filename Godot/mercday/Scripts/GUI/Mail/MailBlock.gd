class_name MailBlock extends PanelContainer

#The special part of one mail, shown under its body and picked by MailInstance.kind(). Its View in Calendar link
#opens the calendar on calendar_day(). The Calendar MailDialog reuses the same scenes through MailReader.

@export var calendar_path: NodePath

var mail: MailInstance = null
var calendar_link: BaseButton = null


func _ready() -> void:
	calendar_link = get_node(calendar_path) as BaseButton
	calendar_link.pressed.connect(_on_calendar_pressed)
	_refresh()


func set_mail(m: MailInstance) -> void:
	mail = m
	_refresh()


#The day the View in Calendar link opens on; -1 hides the link.
func calendar_day() -> int:
	return -1


func _refresh() -> void:
	if not is_node_ready():
		return
	calendar_link.visible = mail != null and calendar_day() >= 0
	if mail != null:
		_render()


func _render() -> void:
	pass


func _on_calendar_pressed() -> void:
	if mail != null and calendar_day() >= 0:
		GameState.open_calendar(calendar_day())
