class_name PixelSlider extends Control

#Single-thumb pixel slider drawn in code. Click or drag anywhere on the track jumps the thumb
#to that ratio; left/right arrow keys step by `step` while the slider holds focus. The value
#always clamps to [min_value, max_value] and snaps to the step grid. `fill` colours the filled run and
#`markers` draws ticks at values on the track. DualSlider adds a second thumb through the _reclamp,
#_begin_drag, _end_drag, _held_value, _apply and _thumb_ratios hooks.

signal value_changed(new_value: float)

const TRACK_COLOR: Color = GuiColors.ROW_FILL
const TRACK_BORDER: Color = GuiColors.BLUE_LO
const FILL_COLOR: Color = GuiColors.BLUE
const THUMB_COLOR: Color = GuiColors.ORANGE
const THUMB_BORDER: Color = GuiColors.INK
const TRACK_HEIGHT: float = 8.0
const TRACK_TOP: float = 7.0
const THUMB_WIDTH: float = 12.0
const THUMB_HEIGHT: float = 20.0
const THUMB_TOP: float = 1.0
const DISABLED_ALPHA: float = 0.4
const MARKER_COLOR: Color = GuiColors.CREAM
const MARKER_WIDTH: float = 2.0

@export var min_value: float = 0.0:
	set(v):
		min_value = v
		_reclamp()
		_redraw_safe()
@export var max_value: float = 100.0:
	set(v):
		max_value = v
		_reclamp()
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
			_end_drag()
		_apply_cursor()
		_redraw_safe()
@export var fill: Color = FILL_COLOR:
	set(v):
		fill = v
		_redraw_safe()
@export var markers: Array[float] = []:
	set(v):
		markers = v
		_redraw_safe()
#With a curve set, the track ratio, the snap grid and the arrow-key step all come from it instead.
var curve: SliderCurve = null:
	set(v):
		curve = v
		_reclamp()
		_redraw_safe()

var _dragging: bool = false
var _hover: int = -1


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size.y = THUMB_TOP + THUMB_HEIGHT
	mouse_exited.connect(_set_hover.bind(-1))
	_apply_cursor()
	_redraw_safe()


#Sets value without emitting value_changed; the drawing still updates.
func set_value_silent(v: float) -> void:
	value = v


func ratio() -> float:
	return ratio_of(value)


#Where v sits along the track: 0 at min_value, 1 at max_value, clamped between the two.
func ratio_of(v: float) -> float:
	if curve != null:
		return curve.ratio_of(v, min_value, max_value)
	var span: float = max_value - min_value
	if span <= 0.0:
		return 0.0
	return clampf((v - min_value) / span, 0.0, 1.0)


func _snap(v: float) -> float:
	if curve != null:
		return curve.snap(v, min_value, max_value, step)
	var clamped: float = clampf(v, min_value, max_value)
	if step <= 0.0:
		return clamped
	var steps: float = roundf((clamped - min_value) / step)
	return clampf(min_value + steps * step, min_value, max_value)


#Pulls the value back inside the bounds after min_value or max_value moves.
func _reclamp() -> void:
	value = value


func _redraw_safe() -> void:
	if is_node_ready():
		queue_redraw()


func _apply_cursor() -> void:
	if disabled:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif _dragging:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				grab_focus()
				_begin_drag(mb.position.x)
			else:
				_end_drag()
	elif event is InputEventMouseMotion:
		var x: float = (event as InputEventMouseMotion).position.x
		if _dragging:
			_set_from_x(x)
		else:
			_set_hover(_thumb_at(x))
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed:
			if key.keycode == KEY_LEFT:
				_step_by(-1.0)
			elif key.keycode == KEY_RIGHT:
				_step_by(1.0)


func _begin_drag(x: float) -> void:
	_dragging = true
	_apply_cursor()
	_set_hover(_pick_thumb(x))
	_set_from_x(x)


#The lift stays on the thumb the pointer still covers once the drag ends.
func _end_drag() -> void:
	_dragging = false
	_apply_cursor()
	if not is_inside_tree():
		return
	var at: Vector2 = get_local_mouse_position()
	_set_hover(_thumb_at(at.x) if Rect2(Vector2.ZERO, size).has_point(at) else -1)


#The thumb a press at x would take; DualSlider picks the nearer of its two.
func _pick_thumb(_x: float) -> int:
	return 0


#The index of the thumb whose face sits under x, or -1 when x is off the thumb.
func _thumb_at(x: float) -> int:
	var i: int = _pick_thumb(x)
	var left: float = _thumb_left(_thumb_ratios()[i])
	return i if x >= left and x < left + THUMB_WIDTH else -1


func _set_hover(i: int) -> void:
	if _dragging and i < 0:
		return
	if i == _hover:
		return
	_hover = i
	_redraw_safe()


func _thumb_left(r: float) -> float:
	return clampf(size.x * r - THUMB_WIDTH * 0.5, 0.0, maxf(0.0, size.x - THUMB_WIDTH))


func _set_from_x(x: float) -> void:
	var w: float = size.x
	if w <= 0.0:
		return
	var r: float = clampf(x / w, 0.0, 1.0)
	if curve != null:
		_apply(curve.value_of(r, min_value, max_value))
		return
	_apply(min_value + r * (max_value - min_value))


func _step_by(direction: float) -> void:
	var held: float = _held_value()
	var stride: float = step if curve == null else curve.step_at(held, direction > 0.0, step)
	_apply(held + direction * stride)


#The value of the thumb the arrow keys move.
func _held_value() -> float:
	return value


#Moves the dragged thumb to v and reports the change.
func _apply(v: float) -> void:
	var before: float = value
	value = v
	if value != before:
		value_changed.emit(value)
		UiSfx.play_slider(ratio_of(value))


#Thumb positions as track ratios, left to right. The fill runs from the first thumb to the last,
#or from the left end of the track when there is only one.
func _thumb_ratios() -> PackedFloat64Array:
	return PackedFloat64Array([ratio()])


func _draw() -> void:
	var w: float = size.x
	var track_rect: Rect2 = Rect2(0.0, TRACK_TOP, w, TRACK_HEIGHT)
	draw_rect(track_rect, TRACK_COLOR, true)
	draw_rect(track_rect, TRACK_BORDER, false, 1.0)
	var thumbs: PackedFloat64Array = _thumb_ratios()
	var fill_from: float = w * thumbs[0] if thumbs.size() > 1 else 0.0
	var fill_to: float = w * thumbs[thumbs.size() - 1]
	if fill_to > fill_from:
		draw_rect(Rect2(fill_from, TRACK_TOP, fill_to - fill_from, TRACK_HEIGHT), fill, true)
	for mark: float in markers:
		var x: float = clampf(ratio_of(mark) * w - MARKER_WIDTH * 0.5, 0.0, maxf(0.0, w - MARKER_WIDTH))
		draw_rect(Rect2(x, TRACK_TOP - 2.0, MARKER_WIDTH, TRACK_HEIGHT + 4.0), MARKER_COLOR, true)
	var thumb_fill: Color = _thumb_color()
	var lit: Color = thumb_fill.lightened(BevelButton.HOVER_LIFT)
	for i: int in range(thumbs.size()):
		var thumb_rect: Rect2 = Rect2(_thumb_left(thumbs[i]), THUMB_TOP, THUMB_WIDTH, THUMB_HEIGHT)
		draw_rect(thumb_rect, THUMB_BORDER, true)
		draw_rect(thumb_rect.grow(-2.0), lit if i == _hover and not disabled else thumb_fill, true)
	if disabled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, DISABLED_ALPHA), true)


func _thumb_color() -> Color:
	return THUMB_COLOR
