class_name BenefitDialog extends ModalDialog

#The modal that edits one bonus: a stepper in the unit the benefit pays, the change it would make
#and what it pays now. Confirm writes through BenefitsManager; Cancel, the X and Escape write
#nothing. The page parks this dialog on the finance modal layer when the shell offers one.

const KICKER_TEXT: String = "Employee Benefits"
const WAS_PREFIX: String = "Was "
const BOX_WIDTH: float = 520.0
#A wrapping label reports its height at its narrowest, so the box asks for a column of single
#characters unless the label carries the width it wraps at.
const WRAP_PAD: float = 60.0

@onready var desc: Label = $Box/Pad/Rows/Desc
@onready var step_box: PayrollStepper = $Box/Pad/Rows/Step

var _key: String = ""
var _was: int = 0


func _ready() -> void:
	box_width = BOX_WIDTH
	super()
	kicker = KICKER_TEXT
	step_box.value_changed.connect(_on_value_changed)
	_style()


func open_for(benefit_key: String) -> void:
	var def: Dictionary = BenefitsManager.benefit_def(benefit_key)
	if def.is_empty():
		return
	_key = benefit_key
	_was = BenefitsManager.benefit(benefit_key)
	title = String(def.get("label", ""))
	desc.text = String(def.get("desc", ""))
	step_box.label = BenefitsManager.step_label(benefit_key)
	step_box.min_value = 0
	step_box.max_value = BenefitsManager.step_max(benefit_key)
	step_box.show_glyph = String(def.get("unit", "")) == "notes"
	step_box.set_value_silent(_was)
	present()
	_fill()


func key() -> String:
	return _key


func value() -> int:
	return step_box.value


func set_value(v: int) -> void:
	step_box.set_value_silent(v)
	_fill()


func stepper() -> PayrollStepper:
	return step_box


func text(field: String) -> String:
	if not is_node_ready():
		return ""
	match field:
		"kicker":
			return kicker_text()
		"title":
			return title_text()
		"desc":
			return desc.text
		"sub":
			return step_box.sub
		"note":
			return step_box.note
		_:
			return ""


#Replaces the base confirm because confirmed carries the bonus key and the value it wrote.
func press_confirm() -> void:
	if not visible:
		return
	var wanted: int = value()
	BenefitsManager.set_benefit(_key, wanted)
	var done: String = _key
	close()
	confirmed.emit(done, wanted)


func close() -> void:
	_key = ""
	super()


func _on_value_changed(_new_value: int) -> void:
	_fill()


func _fill() -> void:
	if not is_node_ready() or _key == "":
		return
	var change: Dictionary = BenefitsManager.benefit_change(_key, value())
	step_box.sub = String(change.get("text", ""))
	step_box.sub_color = change.get("color", GuiColors.CREAM) as Color
	step_box.note = WAS_PREFIX + BenefitsManager.benefit_text(_key, _was)


func _style() -> void:
	GuiStyle.paint(kicker_label, GuiStyle.SILK, 11, GuiColors.SKY)
	GuiStyle.paint(title_label, GuiStyle.SILK_BOLD, 18, GuiColors.ORANGE)
	GuiStyle.paint(desc, GuiStyle.BODY, 14, GuiColors.SKY)
	desc.custom_minimum_size = Vector2(BOX_WIDTH - WRAP_PAD, 0.0)
	for button: BevelButton in [cancel_button, confirm_button]:
		button.add_theme_font_override("font", GuiStyle.SILK)
		button.add_theme_font_size_override("font_size", 12)
