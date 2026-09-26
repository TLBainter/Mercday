class_name FilterCheckRow extends Button

#One labelled check box in a filter popup: an orange ticked box or an empty pale box drawn at the
#left of the row, the label held clear of it by the style's left margin.

const BOX_SIZE: float = 16.0
const BOX_LEFT: float = 2.0
const BORDER: float = 2.0
const TEXT_MARGIN: float = 27.0
const ON_FILL: Color = Color("#f28c28")
const ON_BORDER: Color = Color("#b85a12")
const OFF_FILL: Color = Color("#d9dee8")
const OFF_BORDER: Color = Color("#b9c2cf")
const CHECK_COLOR: Color = Color("#f3ead7")
const ROW_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const ROW_FONT_SIZE: int = 14
const ROW_COLOR: Color = Color("#f3ead7")

@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var on: bool = true:
	set(value):
		on = value
		if is_node_ready():
			button_pressed = value
		queue_redraw()


func _ready() -> void:
	_apply_style()
	button_pressed = on
	toggled.connect(_on_toggled)
	_refresh()


func _draw() -> void:
	var box := Rect2(BOX_LEFT, (size.y - BOX_SIZE) / 2.0, BOX_SIZE, BOX_SIZE)
	draw_rect(box, ON_BORDER if on else OFF_BORDER)
	draw_rect(box.grow(-BORDER), ON_FILL if on else OFF_FILL)
	if not on:
		return
	var tex: Texture2D = GuiGlyphs.check(CHECK_COLOR)
	draw_texture(tex, box.position + (box.size - tex.get_size()) / 2.0)


func _on_toggled(now_on: bool) -> void:
	on = now_on


func _refresh() -> void:
	if not is_node_ready():
		return
	text = label
	queue_redraw()


func _apply_style() -> void:
	var box := StyleBoxEmpty.new()
	box.content_margin_left = TEXT_MARGIN
	box.content_margin_top = 2.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 2.0
	#Every state wears the same empty box so the ticked rows keep the label clear of the check.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, box)
	add_theme_font_override("font", ROW_FONT)
	add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		add_theme_color_override(key, ROW_COLOR)
