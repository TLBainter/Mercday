class_name PayrollBadge extends PanelContainer

#The orange level plate the payroll rows and the fire dialog wear: a small LVL caption over the
#level itself. plate sets the square size and the two font sizes follow the caller. The plate pads
#the level to two digits and prints a level of ten or more as it stands.

const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_VALUE: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const STYLE_BADGE: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_badge.tres")
const TEXT_COLOR: Color = Color("#0a0f1c")

@export var level: int = 1:
	set(value):
		level = maxi(0, value)
		_refresh()
@export var plate: int = 40:
	set(value):
		plate = maxi(8, value)
		_refresh()
@export var kicker_size: int = 7:
	set(value):
		kicker_size = maxi(1, value)
		_refresh()
@export var value_size: int = 15:
	set(value):
		value_size = maxi(1, value)
		_refresh()

@onready var kicker: Label = $Rows/Kicker
@onready var value_label: Label = $Rows/Value


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	add_theme_stylebox_override("panel", STYLE_BADGE)
	custom_minimum_size = Vector2(plate, plate)
	kicker.text = "LVL"
	kicker.add_theme_font_override("font", FONT_KICKER)
	kicker.add_theme_font_size_override("font_size", kicker_size)
	kicker.add_theme_color_override("font_color", TEXT_COLOR)
	value_label.text = level_text()
	value_label.add_theme_font_override("font", FONT_VALUE)
	value_label.add_theme_font_size_override("font_size", value_size)
	value_label.add_theme_color_override("font_color", TEXT_COLOR)


func text() -> String:
	return value_label.text if is_node_ready() else level_text()


#The padded form the plate prints.
func level_text() -> String:
	return "%02d" % level
