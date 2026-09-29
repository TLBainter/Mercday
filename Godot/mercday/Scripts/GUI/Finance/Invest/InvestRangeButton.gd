class_name InvestRangeButton extends Button

#One range of the chart row. The active button is orange with its light bevel; an idle one is
#blue. Hover brightens the body by 15 percent, as the PROTO does. The bevel fill covers the
#built-in text, so the range key rides in a child Label named Caption.

const BAND: float = 3.0
const OUTLINE: float = 3.0
const HOVER_GAIN: float = 1.15

var range_key: String = ""

var _active: bool = false
var _hovered: bool = false
var _caption: Label = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size.y = 28.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption = InvestText.caption_label(self)
	text = ""
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	_paint()


func setup(key: String) -> void:
	range_key = key
	_paint()


func caption_text() -> String:
	return _caption.text if _caption != null else ""


func caption_node() -> Label:
	return _caption


func set_active(on: bool) -> void:
	_active = on
	_paint()
	queue_redraw()


func is_active() -> bool:
	return _active


func body_color() -> Color:
	var body: Color = InvestText.ORANGE if _active else InvestText.BLUE2
	return _brighter(body) if _hovered else body


func text_color() -> Color:
	return InvestText.INK if _active else InvestText.CREAM


func _paint() -> void:
	add_theme_color_override("font_color", text_color())
	add_theme_color_override("font_hover_color", text_color())
	add_theme_color_override("font_pressed_color", text_color())
	if _caption == null:
		return
	_caption.text = range_key
	_caption.add_theme_color_override("font_color", text_color())


func _on_hover_in() -> void:
	_hovered = true
	queue_redraw()


func _on_hover_out() -> void:
	_hovered = false
	queue_redraw()


static func _brighter(c: Color) -> Color:
	return Color(minf(1.0, c.r * HOVER_GAIN), minf(1.0, c.g * HOVER_GAIN),
		minf(1.0, c.b * HOVER_GAIN), c.a)


func _draw() -> void:
	var hi: Color = InvestText.ORANGE_HI if _active else InvestText.BLUE3
	var lo: Color = InvestText.ORANGE_LO if _active else InvestText.BLUE
	InvestText.draw_bevel(self, Rect2(Vector2.ZERO, size), body_color(), hi, lo, BAND, OUTLINE)
