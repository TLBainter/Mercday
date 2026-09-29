class_name BenefitRow extends PanelContainer

#One bonus line in the Employee Benefits panel: label and description on the left, the value in the
#middle and the Adjust button that opens the benefit dialog on it.

const FONT_LABEL: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BUTTON: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_ROW: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_row.tres")

const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const OFF: Color = Color("#5e7699")
const ADJUST_TEXT: String = "Adjust"
const BUTTON_HEIGHT: float = 26.0

signal adjust_pressed(key: String)

@onready var row: HBoxContainer = $Row
@onready var label_text: Label = $Row/Left/LabelText
@onready var desc_text: Label = $Row/Left/DescText
@onready var value_row: NotesLabel = $Row/Value
@onready var adjust_button: BevelButton = $Row/Adjust

var _row: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", STYLE_ROW)
	adjust_button.pressed.connect(press_adjust)
	_style()
	_fill()


func set_row(data: Dictionary) -> void:
	_row = data
	_fill()


func key() -> String:
	return String(_row.get("key", ""))


func text(field: String) -> String:
	if not is_node_ready():
		return ""
	match field:
		"label":
			return label_text.text
		"desc":
			return desc_text.text
		"value":
			return value_row.value_text()
		_:
			return ""


func value_color() -> Color:
	var raw: Variant = _row.get("color", OFF)
	var out: Color = raw
	return out


func press_adjust() -> void:
	adjust_pressed.emit(key())


func _fill() -> void:
	if not is_node_ready():
		return
	label_text.text = String(_row.get("label", ""))
	desc_text.text = String(_row.get("desc", ""))
	value_row.text_override = String(_row.get("value_text", ""))
	value_row.show_glyph = String(_row.get("unit", "")) == "notes"
	value_row.value_color = value_color()


func _style() -> void:
	row.add_theme_constant_override("separation", 18)
	label_text.add_theme_font_override("font", FONT_LABEL)
	label_text.add_theme_font_size_override("font_size", 12)
	label_text.add_theme_color_override("font_color", CREAM)
	desc_text.add_theme_font_override("font", FONT_BODY)
	desc_text.add_theme_font_size_override("font_size", 13)
	desc_text.add_theme_color_override("font_color", SKY)
	value_row.bold = true
	value_row.font_size = 20
	value_row.glyph_scale = 2
	adjust_button.text = ADJUST_TEXT
	adjust_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	adjust_button.add_theme_font_override("font", FONT_BUTTON)
	adjust_button.add_theme_font_size_override("font_size", 10)
	adjust_button.text_color = CREAM
