@tool
class_name ToolDuration extends HBoxContainer

#A duration as a count from 1 to 999 in minutes, hours or days; minutes() gives the total.
#set_minutes stays silent; a count step or a new unit emits changed once, and a unit pick keeps the count.

signal changed

const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/Tools/Shared/ToolOptionDropdown.tscn")
const COUNT_MIN: int = 1
const COUNT_MAX: int = 999
const UNITS: Array[StringName] = [&"minutes", &"hours", &"days"]
const UNIT_LABELS: Array[String] = ["Minutes", "Hours", "Days"]
const FACTORS: Array[int] = [1, 60, 1440]
const DEFAULT_UNIT: int = 1
const TOGGLE_SIZE: Vector2 = Vector2(120, 30)

var stepper: ToolQuantityStepper
var dropdown: ToolOptionDropdown

var _unit_shown: int = DEFAULT_UNIT


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	stepper = ToolQuantityStepper.make(COUNT_MIN, COUNT_MAX, 1)
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stepper.value_changed.connect(_on_count_changed)
	add_child(stepper)
	dropdown = DROPDOWN_SCENE.instantiate() as ToolOptionDropdown
	(dropdown.get_node(^"Toggle") as Control).custom_minimum_size = TOGGLE_SIZE
	dropdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var opts: Array[Dictionary] = []
	for i: int in range(UNITS.size()):
		opts.append({"key": UNITS[i], "label": UNIT_LABELS[i]})
	dropdown.set_options(opts)
	dropdown.select(UNITS[DEFAULT_UNIT])
	dropdown.option_selected.connect(_on_unit_selected)
	add_child(dropdown)


func minutes() -> int:
	return stepper.value * FACTORS[_unit_index()]


func value() -> int:
	return stepper.value


func unit() -> StringName:
	return dropdown.selected


#Silent: m <= 0 gives 1 hour; else the largest unit that divides m with a count of at most 999, else 999 minutes.
func set_minutes(m: int) -> void:
	if m <= 0:
		_show(1, DEFAULT_UNIT)
		return
	for i: int in range(UNITS.size() - 1, -1, -1):
		if m % FACTORS[i] == 0 and floori(float(m) / float(FACTORS[i])) <= COUNT_MAX:
			_show(floori(float(m) / float(FACTORS[i])), i)
			return
	_show(COUNT_MAX, 0)


func _show(count: int, unit_index: int) -> void:
	stepper.set_value_silent(count)
	dropdown.select(UNITS[unit_index])
	_unit_shown = _unit_index()


func _unit_index() -> int:
	var i: int = UNITS.find(dropdown.selected)
	return i if i >= 0 else DEFAULT_UNIT


func _on_count_changed(_new_value: int) -> void:
	changed.emit()


#The dropdown emits a re-pick of the shown unit as well; only a new unit counts as a change.
func _on_unit_selected(_key: StringName) -> void:
	if _unit_index() == _unit_shown:
		return
	_unit_shown = _unit_index()
	changed.emit()
