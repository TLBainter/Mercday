class_name InvestRangeButton extends InvestBevelButton

#One range of the chart row: the core orange palette while active, the blue one while idle, with
#bevel bands on the top and the bottom only. Hover brightens the body by 15 percent, as the
#PROTO does.

const HOVER_GAIN: float = 1.15

var range_key: String = ""

var _active: bool = false


func _ready() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	edge_sides = BevelButton.BEVEL_TOP | BevelButton.BEVEL_BOTTOM
	custom_minimum_size.y = 28.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint()


func setup(key: String) -> void:
	range_key = key
	caption = key


func set_active(on: bool) -> void:
	_active = on
	_paint()


func is_active() -> bool:
	return _active


func fx_active() -> bool:
	return is_active()


func _paint() -> void:
	kind = &"orange" if _active else &"blue"
	hover_fill = GuiColors.brighter(fill, HOVER_GAIN)
	add_theme_color_override(&"font_color", text_color)
	if caption_node() != null:
		caption_node().add_theme_color_override(&"font_color", text_color)
