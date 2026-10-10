@tool
class_name ConsequenceSteppers extends VBoxContainer

#One stepper per consequence kind in CheckSheet.CONSEQUENCE_KINDS order, CONSEQUENCE_MIN to 0 each.
#set_values and clear stay silent; a user step emits changed once.

signal changed

const CAPTIONS: Dictionary = {"retry": "Retry", "hp": "HP", "ep": "EP", "mp": "MP", "guild": "Guild"}
const CAPTION_WIDTH: float = 60.0
const ROW_GAP: int = 8

var _steppers: Dictionary = {}


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	for kind: String in CheckSheet.CONSEQUENCE_KINDS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", ROW_GAP)
		var caption: Label = Label.new()
		caption.text = String(CAPTIONS.get(kind, kind))
		caption.theme_type_variation = &"DescriptionLabel"
		caption.custom_minimum_size = Vector2(CAPTION_WIDTH, 0)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(caption)
		var made: ToolQuantityStepper = ToolQuantityStepper.make(CheckSheet.CONSEQUENCE_MIN, 0, 0)
		made.value_changed.connect(_on_value_changed)
		row.add_child(made)
		add_child(row)
		_steppers[kind] = made


func values() -> Dictionary:
	var out: Dictionary = {}
	for kind: String in CheckSheet.CONSEQUENCE_KINDS:
		out[kind] = stepper(kind).value
	return out


#Silent; a kind missing from amounts goes to 0.
func set_values(amounts: Dictionary) -> void:
	for kind: String in CheckSheet.CONSEQUENCE_KINDS:
		stepper(kind).set_value_silent(int(amounts.get(kind, 0)))


func clear() -> void:
	set_values({})


func stepper(kind: String) -> ToolQuantityStepper:
	return _steppers.get(kind, null) as ToolQuantityStepper


func _on_value_changed(_new_value: int) -> void:
	changed.emit()
