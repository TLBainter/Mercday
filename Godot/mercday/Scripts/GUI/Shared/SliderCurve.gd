class_name SliderCurve extends RefCounted

#Maps a slider value to its track ratio and back, and sets the snap grid and the arrow-key step.
#This base is linear, the same as a PixelSlider with no curve; a subclass overrides it with its own mapping.


func ratio_of(value: float, lo: float, hi: float) -> float:
	var span: float = hi - lo
	if span <= 0.0:
		return 0.0
	return clampf((value - lo) / span, 0.0, 1.0)


func value_of(ratio: float, lo: float, hi: float) -> float:
	return lo + clampf(ratio, 0.0, 1.0) * (hi - lo)


#The size of one arrow-key step away from value, rising or falling.
func step_at(_value: float, _rising: bool, step: float) -> float:
	return step


func snap(value: float, lo: float, hi: float, step: float) -> float:
	var clamped: float = clampf(value, lo, hi)
	if step <= 0.0:
		return clamped
	var steps: float = roundf((clamped - lo) / step)
	return clampf(lo + steps * step, lo, hi)
