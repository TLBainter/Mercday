class_name PixelSlider extends Control

#Single-thumb pixel slider drawn in code. Click or drag anywhere on the track jumps the thumb
#to that ratio; left/right arrow keys step by `step` while the slider holds focus. The value
#always clamps to [min_value, max_value] and snaps to the step grid.

signal value_changed(new_value: float)

const TRACK_COLOR: Color = Color("#0e1628")
const TRACK_BORDER: Color = Color("#1f3560")
const FILL_COLOR: Color = Color("#2b4f8a")
const THUMB_COLOR: Color = Color("#f28c28")
const THUMB_BORDER: Color = Color("#0a0f1c")
const TRACK_HEIGHT: float = 8.0
const TRACK_TOP: float = 7.0
const THUMB_WIDTH: float = 12.0
const THUMB_HEIGHT: float = 20.0
const THUMB_TOP: float = 1.0
const DISABLED_ALPHA: float = 0.4

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		value = value
		_redraw_safe()
@export var max_value: float = 100.0:
	set(v):
		max_value = v
		value = value
		_redraw_safe()
@export var step: float = 1.0
@export var value: float = 0.0:
	set(v):
		value = _snap(v)
		_redraw_safe()
@export var disabled: bool = false:
	set(v):
		disabled = v
		if disabled:
			_dragging = false
		_redraw_safe()

var _dragging: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = THUMB_TOP + THUMB_HEIGHT
	_redraw_safe()


#Sets value without emitting value_changed; the drawing still updates.
func set_value_silent(v: float) -> void:
	value = v


func ratio() -> float:
	var span: float = max_value - min_value
	if span <= 0.0:
		return 0.0
	return (value - min_value) / span


func _snap(v: float) -> float:
	var clamped: float = clampf(v, min_value, max_value)
	if step <= 0.0:
		return clamped
	var steps: float = roundf((clamped - min_value) / step)
	return clampf(min_value + steps * step, min_value, max_value)


func _redraw_safe() -> void:
	if is_node_ready():
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				_dragging = true
				_set_from_x(mb.position.x)
			else:
				_dragging = false
	elif event is InputEventMouseMotion:
		if _dragging:
			_set_from_x((event as InputEventMouseMotion).position.x)
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed:
			if key.keycode == KEY_LEFT:
				_step_by(-1.0)
			elif key.keycode == KEY_RIGHT:
				_step_by(1.0)


func _set_from_x(x: float) -> void:
	var w: float = size.x
	if w <= 0.0:
		return
	var r: float = clampf(x / w, 0.0, 1.0)
	var before: float = value
	value = min_value + r * (max_value - min_value)
	if value != before:
		value_changed.emit(value)


func _step_by(direction: float) -> void:
	var before: float = value
	value = value + direction * step
	if value != before:
		value_changed.emit(value)


func _draw() -> void:
	var w: float = size.x
	var track_rect: Rect2 = Rect2(0.0, TRACK_TOP, w, TRACK_HEIGHT)
	draw_rect(track_rect, TRACK_COLOR, true)
	draw_rect(track_rect, TRACK_BORDER, false, 1.0)
	var fill_w: float = w * ratio()
	if fill_w > 0.0:
		draw_rect(Rect2(0.0, TRACK_TOP, fill_w, TRACK_HEIGHT), FILL_COLOR, true)
	var thumb_x: float = clampf(fill_w - THUMB_WIDTH * 0.5, 0.0, maxf(0.0, w - THUMB_WIDTH))
	var thumb_rect: Rect2 = Rect2(thumb_x, THUMB_TOP, THUMB_WIDTH, THUMB_HEIGHT)
	draw_rect(thumb_rect, THUMB_BORDER, true)
	draw_rect(thumb_rect.grow(-2.0), THUMB_COLOR, true)
	if disabled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, DISABLED_ALPHA), true)
