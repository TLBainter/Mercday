class_name QuantityStepper extends HBoxContainer

#Minus, value, plus stepper. Holding a button repeats at the SalaryDialog ramp: a slow first
#step, silent until HOLD_DELAY_SECONDS, then climbing to hold_peak_rate over HOLD_RAMP_SECONDS.
#The value always clamps between min_value and max_value; it never wraps and never rejects.

signal value_changed(new_value: int)

const HOLD_START_RATE: float = 4.0
const HOLD_RAMP_SECONDS: float = 2.0
const HOLD_DELAY_SECONDS: float = 0.25
const DISABLED_ALPHA: float = 0.4
const ICON_SCALE: int = 2
const ICON_COLOR: Color = Color("#f3ead7")
const ICON_HOVER: Color = Color("#ffffff")
const ICON_PRESSED: Color = Color("#0a0f1c")
const ICON_DISABLED: Color = Color("#5e7699")

@export var value: int = 0:
	set(v):
		value = clampi(v, min_value, maxi(min_value, max_value))
		_refresh()
@export var min_value: int = 0:
	set(v):
		min_value = v
		value = value
		_refresh()
@export var max_value: int = 999:
	set(v):
		max_value = v
		value = value
		_refresh()
@export var step: int = 1
@export var hold_peak_rate: float = 100.0
@export var disabled: bool = false:
	set(v):
		disabled = v
		_apply_disabled()

@onready var minus_button: Button = $Minus
@onready var value_label: Label = $ValueBox/Value
@onready var plus_button: Button = $Plus

var _hold_dir: int = 0
var _hold_time: float = 0.0
var _hold_carry: float = 0.0


func _ready() -> void:
	_paint(minus_button, "minus")
	_paint(plus_button, "plus")
	minus_button.button_down.connect(_on_hold.bind(-1))
	minus_button.button_up.connect(_stop_hold)
	plus_button.button_down.connect(_on_hold.bind(1))
	plus_button.button_up.connect(_stop_hold)
	set_process(false)
	_apply_disabled()
	_refresh()


#The two buttons carry atlas art instead of a font glyph, tinted by the button state.
static func _paint(button: Button, id: String) -> void:
	button.text = ""
	button.icon = Icons.baked(id, ICON_SCALE, Icons.MODE_PLAIN, true)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.add_theme_color_override(&"icon_normal_color", ICON_COLOR)
	button.add_theme_color_override(&"icon_hover_color", ICON_HOVER)
	button.add_theme_color_override(&"icon_pressed_color", ICON_PRESSED)
	button.add_theme_color_override(&"icon_disabled_color", ICON_DISABLED)


#Sets value without emitting value_changed; the label still updates.
func set_value_silent(v: int) -> void:
	value = v


func press_minus() -> void:
	if disabled:
		return
	_step(-1)


func press_plus() -> void:
	if disabled:
		return
	_step(1)


func _step(direction: int) -> void:
	var before: int = value
	value = value + direction * step
	if value != before:
		value_changed.emit(value)


func _refresh() -> void:
	if not is_node_ready():
		return
	value_label.text = str(value)


func _apply_disabled() -> void:
	if not is_node_ready():
		return
	minus_button.disabled = disabled
	plus_button.disabled = disabled
	modulate.a = DISABLED_ALPHA if disabled else 1.0
	if disabled:
		_stop_hold()


func _on_hold(direction: int) -> void:
	if disabled:
		return
	_step(direction)
	_hold_dir = direction
	_hold_time = 0.0
	_hold_carry = 0.0
	set_process(true)


func _stop_hold() -> void:
	_hold_dir = 0
	_hold_carry = 0.0
	set_process(false)


func _process(delta: float) -> void:
	if _hold_dir == 0:
		set_process(false)
		return
	_hold_time += delta
	if _hold_time < HOLD_DELAY_SECONDS:
		return
	_hold_carry += hold_rate(_hold_time - HOLD_DELAY_SECONDS, hold_peak_rate) * delta
	while _hold_carry >= 1.0:
		_hold_carry -= 1.0
		_step(_hold_dir)


#Ramps from a slow tap rate to the peak over HOLD_RAMP_SECONDS of holding.
static func hold_rate(held_seconds: float, peak: float) -> float:
	var t: float = clampf(held_seconds / HOLD_RAMP_SECONDS, 0.0, 1.0)
	return lerpf(HOLD_START_RATE, peak, t)
