class_name SalaryModule extends PanelContainer

#The monthly wage chip at the foot of the merc card. The colour warns as the wage eats into the
#bank (SCENES.md line 151) and a click hands the merc to the SalaryDialog.

const AFFORDABLE_SHARE: float = 0.1
const GREEN: Color = Color("#6cc36a")
const ORANGE: Color = Color("#f28c28")
const RED: Color = Color("#e8583f")
const EDGE_HI: Color = Color("#3b6fb6")
const EDGE_LO: Color = Color("#1f3560")
const EDGE_PX: float = 3.0
const TOOLTIP: String = "Click to manage salary"

signal clicked

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
	tooltip_text = TOOLTIP
	_refresh()


#The bevel rides the panel edge: a stylebox has no inset shadow and a child of a
#PanelContainer would be laid inside the content margins.
func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, EDGE_PX), EDGE_HI)
	draw_rect(Rect2(0.0, size.y - EDGE_PX, size.x, EDGE_PX), EDGE_LO)


func set_salary(salary: int, bank_notes: int) -> void:
	monthly_salary = salary
	notes = bank_notes


func color() -> Color:
	return color_for(monthly_salary, notes)


static func color_for(salary: int, bank_notes: int) -> Color:
	if salary > bank_notes:
		return RED
	if float(salary) > float(bank_notes) * AFFORDABLE_SHARE:
		return ORANGE
	return GREEN


func _refresh() -> void:
	if not is_node_ready():
		return
	value_label.text = str(monthly_salary)
	value_label.add_theme_color_override("font_color", color())


func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()
