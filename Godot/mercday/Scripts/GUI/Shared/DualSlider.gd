class_name DualSlider extends Control

#Two-thumb pixel range slider drawn in code, styled like PixelSlider. A click or drag picks
#whichever thumb sits nearer the pointer; the thumbs never cross, so low always stays <= high.

signal range_changed(new_low: float, new_high: float)

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

enum Thumb {LOW, HIGH}

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		_clamp_range()
		_redraw_safe()
@export var max_value: float = 100.0:
	set(v):
		max_value = v
		_clamp_range()
		_redraw_safe()
@export var step: float = 1.0
@export var low: float = 0.0:
	set(v):
		low = _snap(v)
		if low > high:
			high = low
		_redraw_safe()
@export var high: float = 100.0:
	set(v):
		high = _snap(v)
		if high < low:
			low = high
		_redraw_safe()
@export var disabled: bool = false:
	set(v):
		disabled = v
		if disabled:
			_active = -1
		_redraw_safe()

var _active: int = -1


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = THUMB_TOP + THUMB_HEIGHT
	_redraw_safe()


#Sets both ends without emitting range_changed; the drawing still updates.
func set_range_silent(lo: float, hi: float) -> void:
	low = lo
	high = hi


func low_ratio() -> float:
	return _ratio_of(low)


func high_ratio() -> float:
	return _ratio_of(high)


func _ratio_of(v: float) -> float:
	var span: float = max_value - min_value
	if span <= 0.0:
		return 0.0
	return (v - min_value) / span


func _snap(v: float) -> float:
	var clamped: float = clampf(v, min_value, max_value)
	if step <= 0.0:
		return clamped
	var steps: float = roundf((clamped - min_value) / step)
	return clampf(min_value + steps * step, min_value, max_value)


func _clamp_range() -> void:
	low = low
	high = high


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
				_active = _nearest_thumb(mb.position.x)
				_set_active_from_x(mb.position.x)
			else:
				_active = -1
	elif event is InputEventMouseMotion:
		if _active != -1:
			_set_active_from_x((event as InputEventMouseMotion).position.x)
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and _active != -1:
			if key.keycode == KEY_LEFT:
				_step_active(-1.0)
			elif key.keycode == KEY_RIGHT:
				_step_active(1.0)


#Returns Thumb.LOW or Thumb.HIGH, whichever thumb's pixel position sits nearer to x.
func _nearest_thumb(x: float) -> int:
	var w: float = size.x
	var low_x: float = w * low_ratio()
	var high_x: float = w * high_ratio()
	if absf(x - low_x) <= absf(x - high_x):
		return Thumb.LOW
	return Thumb.HIGH


func _set_active_from_x(x: float) -> void:
	var w: float = size.x
	if w <= 0.0:
		return
	var r: float = clampf(x / w, 0.0, 1.0)
	var v: float = min_value + r * (max_value - min_value)
	_apply_active(v)


func _step_active(direction: float) -> void:
	var v: float = (low if _active == Thumb.LOW else high) + direction * step
	_apply_active(v)


func _apply_active(v: float) -> void:
	var before_low: float = low
	var before_high: float = high
	if _active == Thumb.LOW:
		low = v
	elif _active == Thumb.HIGH:
		high = v
	if low != before_low or high != before_high:
		range_changed.emit(low, high)


func _draw() -> void:
	var w: float = size.x
	var track_rect: Rect2 = Rect2(0.0, TRACK_TOP, w, TRACK_HEIGHT)
	draw_rect(track_rect, TRACK_COLOR, true)
	draw_rect(track_rect, TRACK_BORDER, false, 1.0)
	var low_x: float = w * low_ratio()
	var high_x: float = w * high_ratio()
	if high_x > low_x:
		draw_rect(Rect2(low_x, TRACK_TOP, high_x - low_x, TRACK_HEIGHT), FILL_COLOR, true)
	_draw_thumb(low_x, w)
	_draw_thumb(high_x, w)
	if disabled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, DISABLED_ALPHA), true)


func _draw_thumb(center_x: float, w: float) -> void:
	var thumb_x: float = clampf(center_x - THUMB_WIDTH * 0.5, 0.0, maxf(0.0, w - THUMB_WIDTH))
	var thumb_rect: Rect2 = Rect2(thumb_x, THUMB_TOP, THUMB_WIDTH, THUMB_HEIGHT)
	draw_rect(thumb_rect, THUMB_BORDER, true)
	draw_rect(thumb_rect.grow(-2.0), THUMB_COLOR, true)
