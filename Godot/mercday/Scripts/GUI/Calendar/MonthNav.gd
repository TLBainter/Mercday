class_name MonthNav extends HBoxContainer

#The month header of the calendar: previous and next arrows round the month name, and Today at the
#right end. It only reports clicks; the dialog owns the shown month.

signal step(delta: int)
signal today_pressed

const BUTTON_SIZE: Vector2 = Vector2(36.0, 32.0)
const TODAY_SIZE: Vector2 = Vector2(88.0, 32.0)
const LABEL_WIDTH: float = 160.0
const ARROW_SCALE: int = 2

var prev_button: BevelButton = null
var next_button: BevelButton = null
var today_button: BevelButton = null
var month_label: Label = null


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	prev_button = _arrow("Prev", "caret_left", -1)
	month_label = Label.new()
	month_label.name = "MonthLabel"
	month_label.theme_type_variation = &"TitleLabel"
	month_label.custom_minimum_size.x = LABEL_WIDTH
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(month_label)
	next_button = _arrow("Next", "caret_right", 1)
	today_button = BevelButton.make("Today", &"orange", TODAY_SIZE)
	today_button.name = "Today"
	today_button.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	today_button.pressed.connect(today_pressed.emit)
	add_child(today_button)


#"Daith 212".
func show_month(year: int, month: int) -> void:
	month_label.text = "%s %d" % [String(TrynnCalendar.MONTHS[month]["name"]), year]


func _arrow(node_name: String, icon_name: String, delta: int) -> BevelButton:
	var made: BevelButton = BevelButton.make("", &"blue", BUTTON_SIZE)
	made.name = node_name
	made.icon = Icons.tinted(icon_name, GuiColors.CREAM, ARROW_SCALE, true)
	made.pressed.connect(step.emit.bind(delta))
	add_child(made)
	#The face draws the icon at the left margin, so the margin centres it.
	made.get_theme_stylebox(&"normal").content_margin_left = floorf((BUTTON_SIZE.x - made.icon.get_width()) / 2.0)
	return made
