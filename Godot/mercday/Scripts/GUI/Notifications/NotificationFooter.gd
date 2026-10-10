class_name NotificationFooter extends HBoxContainer

#The bottom line of a notification item: the game date and time on the left, the urgency name on
#the right in the urgency colour. Both texts come from NotificationData so one source spells them.

const WHEN_COLOR: Color = GuiColors.DIM_TEXT

@export var when_label_path: NodePath = ^"WhenLabel"
@export var spacer_path: NodePath = ^"Spacer"
@export var urgency_label_path: NodePath = ^"UrgencyLabel"

var _when: Label = null
var _urgency: Label = null
var _row: NotificationData = null


func _ready() -> void:
	_when = get_node_or_null(when_label_path) as Label
	_urgency = get_node_or_null(urgency_label_path) as Label
	#A STOP spacer inside the row would drop its hover and replay it on the way back.
	var spacer: Control = get_node_or_null(spacer_path) as Control
	if spacer != null:
		spacer.mouse_filter = MOUSE_FILTER_IGNORE
	_refresh()


func apply(data: NotificationData) -> void:
	_row = data
	_refresh()


func when_text() -> String:
	if _row == null:
		return ""
	return _row.when_text()


func urgency_text() -> String:
	if _row == null:
		return ""
	return _row.urgency_name()


func _refresh() -> void:
	if _when == null or _urgency == null:
		return
	_when.text = when_text()
	_when.add_theme_color_override("font_color", WHEN_COLOR)
	_urgency.text = urgency_text()
	var tint: Color = WHEN_COLOR if _row == null else _row.urgency_color()
	_urgency.add_theme_color_override("font_color", tint)
