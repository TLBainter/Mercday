class_name InvestQuantityField extends QuantityStepper

#The trade quantity stepper: minus, a typed digits only field, plus and a Max button. The field is
#the value box of the base stepper, which clamps, holds and rejects: a press steps at once, a held
#minus or plus repeats after 0.35 s, one tick every 80 ms, the amount per tick rising from 1 to 10,
#and an attempt past a bound stops the hold, tints the field and shakes it.

const STEP_SIZE: Vector2 = Vector2(28.0, 28.0)
const MAX_SIZE: Vector2 = Vector2(56.0, 28.0)
const HOLD_DELAY: float = 0.35
const TICK_TIME: float = 0.08
const STEP_MAX: int = 10
const RAMP_SECONDS: float = 1.6
const REJECT_TIME: float = 0.4
const SHAKE_OFFSET: float = 6.0

@onready var field: LineEdit = $ValueBox
@onready var max_button: InvestBevelButton = $MaxButton


func _init() -> void:
	min_value = 1
	max_value = 1
	value = 1
	hold_delay = HOLD_DELAY
	hold_tick = TICK_TIME
	hold_step_max = STEP_MAX
	hold_ramp = RAMP_SECONDS
	reject_seconds = REJECT_TIME
	shake_steps = PackedFloat32Array([SHAKE_OFFSET, -SHAKE_OFFSET, SHAKE_OFFSET / 2.0, 0.0])


func _ready() -> void:
	super()
	#The minus and plus art rides in their Glyph children, so the icon the base paints is dropped.
	minus_button.icon = null
	plus_button.icon = null
	minus_button.custom_minimum_size = STEP_SIZE
	plus_button.custom_minimum_size = STEP_SIZE
	max_button.custom_minimum_size = MAX_SIZE
	field.custom_minimum_size = Vector2(0.0, STEP_SIZE.y)
	max_button.pressed.connect(press_max)
	field.text_changed.connect(_on_text_changed)
	field.text_submitted.connect(type_text)
	field.focus_exited.connect(_on_focus_exited)


func press_max() -> void:
	_move(ceiling() - value)


#Digits only; anything else is dropped, an empty field falls back to the current value.
func type_text(text: String) -> void:
	var digits: String = _digits_of(text)
	if digits != "":
		_move(int(digits) - value)
	_refresh()


func _refresh() -> void:
	super()
	if not is_node_ready():
		return
	field.text = str(value)
	field.caret_column = field.text.length()


#A LineEdit draws its normal and focus styles and never the panel the base swaps, so both turn red.
func _show_reject() -> void:
	super()
	if is_node_ready():
		var style: StyleBoxFlat = reject_style()
		field.add_theme_stylebox_override(&"normal", style)
		field.add_theme_stylebox_override(&"focus", style)


#The shake moves linearly from 0 through each shake step in turn, one equal share of the reject per step.
func shake_offset() -> float:
	if not is_rejecting() or shake_steps.is_empty():
		return 0.0
	var at: float = (1.0 - _reject_left / maxf(0.001, reject_seconds)) * float(shake_steps.size())
	var leg: int = clampi(int(at), 0, shake_steps.size() - 1)
	var start: float = 0.0 if leg == 0 else shake_steps[leg - 1]
	return lerpf(start, shake_steps[leg], at - float(leg))


#A step past a bound starts the reject before the new value is reported; only a move that stays
#inside the bounds plays the step click.
func _move(amount: int) -> void:
	var target: int = value + amount
	var clamped: int = clampi(target, min_value, ceiling())
	if clamped != target:
		_reject(signi(target - clamped))
	if clamped != value:
		if clamped == target or reject_seconds <= 0.0:
			UiSfx.play_step(self)
		value = clamped
		value_changed.emit(value)


func _on_focus_exited() -> void:
	type_text(field.text)


func _on_text_changed(new_text: String) -> void:
	var digits: String = _digits_of(new_text)
	if digits == new_text:
		return
	field.text = digits
	field.caret_column = digits.length()


static func _digits_of(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var c: String = text[i]
		if c >= "0" and c <= "9":
			out += c
	return out
