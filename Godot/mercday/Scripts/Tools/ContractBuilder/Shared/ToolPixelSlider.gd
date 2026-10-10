@tool
class_name ToolPixelSlider extends PixelSlider

#PixelSlider for editor tools, made in code by make() with the PixelSlider.tscn root properties.
#The editor has no UiSfx autoload, so there _apply moves the thumb without the slider sound.


static func make() -> ToolPixelSlider:
	var slider: ToolPixelSlider = ToolPixelSlider.new()
	slider.custom_minimum_size = Vector2(120, 21)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_filter = Control.MOUSE_FILTER_PASS
	return slider


func _apply(v: float) -> void:
	if not Engine.is_editor_hint():
		super(v)
		return
	var before: float = value
	value = v
	if value != before:
		value_changed.emit(value)
