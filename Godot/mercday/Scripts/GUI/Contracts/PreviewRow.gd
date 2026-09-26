class_name PreviewRow extends PanelContainer

#One inset row in the Dispatch preview column: a caption above a value, with the notes glyph
#lit on the money rows (Travel Costs, Final Reward, Mercenary Bonus, Guild Cut).

const CAPTION_FONT: String = "res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres"
const VALUE_FONT: String = "res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres"
const CAPTION_SIZE: int = 10
const VALUE_SIZE: int = 13
const CAPTION_COLOR: Color = Color("#9cc6ef")
const CREAM_COLOR: Color = Color("#f3ead7")

@onready var caption_label: Label = $Rows/Caption
@onready var value_label: Label = $Rows/Value/Text
@onready var glyph_node: NoteIcon = $Rows/Value/Note

var caption: String = ""
var value: String = ""
var tint: Color = CREAM_COLOR
var glyph: bool = false


func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	caption_label.add_theme_font_override("font", load(CAPTION_FONT) as Font)
	caption_label.add_theme_font_size_override("font_size", CAPTION_SIZE)
	caption_label.add_theme_color_override("font_color", CAPTION_COLOR)
	value_label.add_theme_font_override("font", load(VALUE_FONT) as Font)
	value_label.add_theme_font_size_override("font_size", VALUE_SIZE)
	_refresh()


func set_row(new_caption: String, new_value: String, new_tint: Color, new_glyph: bool) -> void:
	caption = new_caption
	value = new_value
	tint = new_tint
	glyph = new_glyph
	_refresh()


func caption_text() -> String:
	return caption


func value_text() -> String:
	return value


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption.to_upper()
	value_label.text = value
	value_label.add_theme_color_override("font_color", tint)
	glyph_node.visible = glyph
