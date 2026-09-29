class_name FinancePlaceholder
extends Control

#What the page host shows when the scene of a tab is not in the build yet: one centred line and
#nothing else. The label is built in code as well, so a bare new() is safe in a test.

const FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const TEXT_COLOR: Color = Color("#9cc6ef")
const FONT_SIZE: int = 12
const LABEL_NAME: String = "Text"

var _text: String = ""
var _label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_label()
	_apply()


func set_label(text: String) -> void:
	_text = text
	_ensure_label()
	_apply()


func label_text() -> String:
	return _text


func _ensure_label() -> void:
	if _label != null:
		return
	_label = get_node_or_null(LABEL_NAME) as Label
	if _label != null:
		return
	_label = Label.new()
	_label.name = LABEL_NAME
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)


func _apply() -> void:
	if _label == null:
		return
	_label.text = _text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
