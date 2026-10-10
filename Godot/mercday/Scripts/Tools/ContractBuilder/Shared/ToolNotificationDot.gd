@tool
class_name ToolNotificationDot extends NotificationDot

#NotificationDot for editor tools. The editor has no PulseClock, so there the dot paints still at phase 0.


func _init() -> void:
	ToolIcons.prime()


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		super()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		super()


func _draw() -> void:
	if Engine.is_editor_hint():
		NotificationDot.paint(self, FRAME_SIZE / 2.0, color, 0.0, false, false)
	else:
		super()
