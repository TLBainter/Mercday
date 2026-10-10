class_name LoanSlider extends PixelSlider

#A PixelSlider with a snap point and a thumb in the fill colour, for the request window and the
#loan filters.

const SLIDER_HEIGHT: float = 22.0

@export var snap_to: float
@export var snap_range: float = 0.05


func _init() -> void:
	snap_to = NAN


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


func snapped_to_marker() -> bool:
	if is_nan(snap_to):
		return false
	return is_equal_approx(value, clampf(snap_to, min_value, max_value))



#The loan sliders paint the thumb in the fill colour.
func _thumb_color() -> Color:
	return fill
