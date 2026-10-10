class_name DualSlider extends PixelSlider

#Two-thumb pixel range slider on the PixelSlider track. A click or drag picks whichever thumb
#sits nearer the pointer; the thumbs never cross, so low always stays <= high. The inherited
#value is unused here: low and high carry the range and range_changed reports it.

signal range_changed(new_low: float, new_high: float)

enum Thumb {LOW, HIGH}

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

var _active: int = -1


#Sets both ends without emitting range_changed; the drawing still updates.
func set_range_silent(lo: float, hi: float) -> void:
	low = lo
	high = hi


func low_ratio() -> float:
	return ratio_of(low)


func high_ratio() -> float:
	return ratio_of(high)


func _reclamp() -> void:
	low = low
	high = high


func _begin_drag(x: float) -> void:
	_active = _nearest_thumb(x)
	super(x)


func _end_drag() -> void:
	_active = -1
	super()


#Returns Thumb.LOW or Thumb.HIGH, whichever thumb's pixel position sits nearer to x.
func _nearest_thumb(x: float) -> int:
	var w: float = size.x
	var low_x: float = w * low_ratio()
	var high_x: float = w * high_ratio()
	if absf(x - low_x) <= absf(x - high_x):
		return Thumb.LOW
	return Thumb.HIGH


func _pick_thumb(x: float) -> int:
	return _nearest_thumb(x)


func _held_value() -> float:
	return low if _active == Thumb.LOW else high


#Moves the thumb picked by the press; with no thumb picked nothing moves and nothing is reported.
func _apply(v: float) -> void:
	var before_low: float = low
	var before_high: float = high
	if _active == Thumb.LOW:
		low = v
	elif _active == Thumb.HIGH:
		high = v
	if low != before_low or high != before_high:
		range_changed.emit(low, high)
		UiSfx.play_slider(ratio_of(v))


func _thumb_ratios() -> PackedFloat64Array:
	return PackedFloat64Array([low_ratio(), high_ratio()])
