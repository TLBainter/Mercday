@tool
class_name ToolDualSlider extends DualSlider

#DualSlider for editor tools, made in code by make() with the PixelSlider.tscn root properties.
#The editor has no UiSfx autoload, so there _apply moves the thumbs without the slider sound.


static func make() -> ToolDualSlider:
	var slider: ToolDualSlider = ToolDualSlider.new()
	slider.custom_minimum_size = Vector2(120, 21)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_filter = Control.MOUSE_FILTER_PASS
	return slider


func _apply(v: float) -> void:
	if not Engine.is_editor_hint():
		super(v)
		return
	var before_low: float = low
	var before_high: float = high
	if _active == Thumb.LOW:
		low = v
	elif _active == Thumb.HIGH:
		high = v
	if low != before_low or high != before_high:
		range_changed.emit(low, high)
