class_name BenefitDialog extends Control

#The modal that edits one bonus: a stepper in the unit the benefit pays, the change it would make
#and what it pays now. Confirm writes through BenefitsManager; Cancel, the X and Escape write
#nothing. The page parks this dialog on the finance modal layer when the shell offers one.

const FONT_TITLE: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_KICKER: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const STYLE_BACKDROP: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_backdrop.tres")
const STYLE_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/payroll_dialog.tres")

const ORANGE: Color = Color("#f28c28")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const DARK: Color = Color("#0a0f1c")
const CLOSE_COLOR: Color = Color("#ff3b2f")
const KICKER_TEXT: String = "Employee Benefits"
const CANCEL_TEXT: String = "Cancel"
const CONFIRM_TEXT: String = "Confirm"
const WAS_PREFIX: String = "Was "
const BOX_WIDTH: float = 520.0
#A wrapping label reports its height at its narrowest, so the box asks for a column of single
#characters unless the label carries the width it wraps at.
const WRAP_PAD: float = 60.0
const BUTTON_HEIGHT: float = 36.0

signal confirmed(key: String, value: int)
signal cancelled

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Center/Box
@onready var rows: VBoxContainer = $Center/Box/Rows
@onready var kicker: Label = $Center/Box/Rows/Kicker
@onready var title: Label = $Center/Box/Rows/Title
@onready var desc: Label = $Center/Box/Rows/Desc
@onready var step_box: PayrollStepper = $Center/Box/Rows/Step
@onready var cancel_button: BevelButton = $Center/Box/Rows/Buttons/Cancel
@onready var confirm_button: BevelButton = $Center/Box/Rows/Buttons/Confirm
@onready var close_button: BevelButton = $Center/Box/Overlay/Close

var _key: String = ""
var _was: int = 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.add_theme_stylebox_override("panel", STYLE_BACKDROP)
	box.add_theme_stylebox_override("panel", STYLE_BOX)
	box.custom_minimum_size = Vector2(BOX_WIDTH, 0.0)
	cancel_button.pressed.connect(press_cancel)
	confirm_button.pressed.connect(press_confirm)
	close_button.pressed.connect(press_cancel)
	step_box.value_changed.connect(_on_value_changed)
	_style()
	ModalFrame.fit(self, backdrop, box)


func open_for(benefit_key: String) -> void:
	var def: Dictionary = BenefitsManager.benefit_def(benefit_key)
	if def.is_empty():
		return
	_key = benefit_key
	_was = BenefitsManager.benefit(benefit_key)
	title.text = String(def.get("label", ""))
	desc.text = String(def.get("desc", ""))
	step_box.label = BenefitsManager.step_label(benefit_key)
	step_box.min_value = 0
	step_box.max_value = BenefitsManager.step_max(benefit_key)
	step_box.show_glyph = String(def.get("unit", "")) == "notes"
	step_box.set_value_silent(_was)
	visible = true
	ModalFrame.fit(self, backdrop, box)
	GuiFrameStack.push(self)
	_fill()


func is_open() -> bool:
	return visible


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
			return kicker.text
		"title":
			return title.text
		"desc":
			return desc.text
		"sub":
			return step_box.sub
		"note":
			return step_box.note
		_:
			return ""


func press_confirm() -> void:
	if not visible:
		return
	var wanted: int = value()
	BenefitsManager.set_benefit(_key, wanted)
	var done: String = _key
	_close()
	confirmed.emit(done, wanted)


func press_cancel() -> void:
	if not visible:
		return
	_close()
	cancelled.emit()


func _close() -> void:
	visible = false
	_key = ""
	GuiFrameStack.remove(self)


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


func _on_value_changed(_new_value: int) -> void:
	_fill()


func _fill() -> void:
	if not is_node_ready() or _key == "":
		return
	var change: Dictionary = BenefitsManager.benefit_change(_key, value())
	step_box.sub = String(change.get("text", ""))
	var raw: Variant = change.get("color", CREAM)
	var tint: Color = raw
	step_box.sub_color = tint
	step_box.note = WAS_PREFIX + BenefitsManager.benefit_text(_key, _was)


func _style() -> void:
	rows.add_theme_constant_override("separation", 16)
	kicker.text = KICKER_TEXT
	kicker.add_theme_font_override("font", FONT_KICKER)
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", SKY)
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ORANGE)
	desc.add_theme_font_override("font", FONT_BODY)
	desc.custom_minimum_size = Vector2(BOX_WIDTH - WRAP_PAD, 0.0)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", SKY)
	_style_button(cancel_button, CANCEL_TEXT, CREAM)
	_style_button(confirm_button, CONFIRM_TEXT, DARK)
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(56.0, 56.0)
	close_button.add_theme_font_override("font", FONT_KICKER)
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.text_color = CLOSE_COLOR


func _style_button(btn: BevelButton, body: String, tint: Color) -> void:
	btn.text = body
	btn.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", FONT_KICKER)
	btn.add_theme_font_size_override("font_size", 12)
	btn.text_color = tint


#Esc answers this dialog only while it is the top frame of the stack.
func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		press_cancel()
