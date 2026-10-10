class_name SalaryModule extends PanelContainer

#The monthly wage chip at the foot of the merc card. The colour warns as the wage eats into the
#bank (SCENES.md line 151) and a click hands the merc to the SalaryDialog.

const AFFORDABLE_SHARE: float = 0.1
const EDGE_HI: Color = GuiColors.BLUE_HI
const EDGE_LO: Color = GuiColors.BLUE_LO
const EDGE_PX: float = 3.0
const TOOLTIP: String = "Click to manage salary"

signal clicked
#UiSfx clicks on this one; clicked stays the signal callers listen to.
signal pressed

@export var monthly_salary: int = 0:
	set(value):
		monthly_salary = value
		_refresh()
@export var notes: int = 0:
	set(value):
		notes = value
		_refresh()

@onready var value_label: Label = $Row/Text/Value


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = TOOLTIP
	_refresh()


#The bevel rides the panel edge: a stylebox has no inset shadow and a child of a
#PanelContainer would be laid inside the content margins.
func _draw() -> void:
	BevelButton.paint_edges(self, Rect2(Vector2.ZERO, size), EDGE_HI, EDGE_LO, EDGE_PX,
		BevelButton.BEVEL_TOP | BevelButton.BEVEL_BOTTOM)


func set_salary(salary: int, bank_notes: int) -> void:
	monthly_salary = salary
	notes = bank_notes


func color() -> Color:
	return color_for(monthly_salary, notes)


static func color_for(salary: int, bank_notes: int) -> Color:
	if salary > bank_notes:
		return GuiColors.RED
	if float(salary) > float(bank_notes) * AFFORDABLE_SHARE:
		return GuiColors.ORANGE
	return GuiColors.GREEN


func _refresh() -> void:
	if not is_node_ready():
		return
	value_label.text = str(monthly_salary)
	value_label.add_theme_color_override("font_color", color())


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		clicked.emit()
		accept_event()
