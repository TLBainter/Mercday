class_name HiringDot extends Control

#The unseen marker of an applicant card. NotificationDot pins itself to 10 x 10, so the card carries
#this owned 28 x 28 dot instead, painted with the shared pixel dot, outline and pulse rings.

const DOT_SIZE: Vector2 = Vector2(28, 28)

@export var on: bool = true:
	set(value):
		on = value
		visible = on
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = DOT_SIZE
	size = DOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = on
	queue_redraw()


func _enter_tree() -> void:
	PulseClock.pulse.connect(_on_pulse)


func _exit_tree() -> void:
	if PulseClock.pulse.is_connected(_on_pulse):
		PulseClock.pulse.disconnect(_on_pulse)


func _on_pulse(_g: float, _sweep: PackedFloat32Array) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	NotificationDot.paint(self, DOT_SIZE / 2.0, NotificationDot.DOT_COLOR, PulseClock.phase(),
		true, true)
