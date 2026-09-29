class_name LoanSlider extends PixelSlider

#A PixelSlider with marker ticks, a snap point and its own fill colour, for the request window
#and the loan filters. PixelSlider itself is not edited: _snap and _draw are overridden here.

const MARKER_COLOR: Color = Color("#f3ead7")
const MARKER_WIDTH: float = 2.0
const SLIDER_HEIGHT: float = 22.0

@export var markers: Array[float] = []:
	set(v):
		markers = v
		_redraw_safe()
@export var snap_to: float = NAN
@export var snap_range: float = 0.05
@export var fill: Color = Color("#2b4f8a"):
	set(v):
		fill = v
		_redraw_safe()


func _ready() -> void:
	super()
	custom_minimum_size.y = SLIDER_HEIGHT


#The step grid of the parent first, then a pull onto snap_to when the value lands near it.
func _snap(v: float) -> float:
	var stepped: float = super(v)
	if is_nan(snap_to):
		return stepped
	var span: float = max_value - min_value
	if span <= 0.0:
		return stepped
	if absf(stepped - snap_to) <= snap_range * span:
		return clampf(snap_to, min_value, max_value)
	return stepped


func ratio_of(v: float) -> float:
	var span: float = max_value - min_value
	if span <= 0.0:
		return 0.0
	return clampf((v - min_value) / span, 0.0, 1.0)


func snapped_to_marker() -> bool:
	if is_nan(snap_to):
		return false
	return is_equal_approx(value, clampf(snap_to, min_value, max_value))


func _draw() -> void:
	var w: float = size.x
	var track: Rect2 = Rect2(0.0, TRACK_TOP, w, TRACK_HEIGHT)
	draw_rect(track, TRACK_COLOR, true)
	draw_rect(track, TRACK_BORDER, false, 1.0)
	var fill_w: float = w * ratio()
	if fill_w > 0.0:
		draw_rect(Rect2(0.0, TRACK_TOP, fill_w, TRACK_HEIGHT), fill, true)
	for mark: float in markers:
		var x: float = ratio_of(mark) * w
		x = clampf(x - MARKER_WIDTH * 0.5, 0.0, maxf(0.0, w - MARKER_WIDTH))
		draw_rect(Rect2(x, TRACK_TOP - 2.0, MARKER_WIDTH, TRACK_HEIGHT + 4.0), MARKER_COLOR, true)
	var thumb_x: float = clampf(fill_w - THUMB_WIDTH * 0.5, 0.0, maxf(0.0, w - THUMB_WIDTH))
	var thumb: Rect2 = Rect2(thumb_x, THUMB_TOP, THUMB_WIDTH, THUMB_HEIGHT)
	draw_rect(thumb, THUMB_BORDER, true)
	draw_rect(thumb.grow(-2.0), fill, true)
	if disabled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, DISABLED_ALPHA), true)
