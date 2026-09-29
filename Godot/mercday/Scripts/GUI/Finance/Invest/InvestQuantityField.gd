class_name InvestQuantityField extends HBoxContainer

#The trade quantity stepper: minus, a typed digits only field, plus and a Max button. A held
#minus or plus repeats after 0.35 s, one tick every 80 ms, the amount per tick rising from 1 to
#10. An attempt past a bound clamps the value, stops the hold, tints the field and shakes it.

const STEP_SIZE: Vector2 = Vector2(28.0, 28.0)
const MAX_SIZE: Vector2 = Vector2(56.0, 28.0)
const HOLD_DELAY: float = 0.35
const TICK_TIME: float = 0.08
const STEP_MIN: int = 1
const STEP_MAX: int = 10
const RAMP_SECONDS: float = 1.6
const REJECT_TIME: float = 0.4
const SHAKE_OFFSET: float = 6.0
const FIELD_PAD: float = 8.0

signal value_changed(new_value: int)

@export var value: int = 1:
	set(v):
		value = maxi(1, v)
		_show_value()
@export var min_value: int = 1:
	set(v):
		min_value = maxi(1, v)
@export var max_value: int = 1:
	set(v):
		max_value = maxi(0, v)
@export var max_tooltip: String = "":
	set(v):
		max_tooltip = v
		_show_tooltip()

@onready var minus_button: InvestBevelButton = $MinusButton
@onready var field: LineEdit = $Field
@onready var plus_button: InvestBevelButton = $PlusButton
@onready var max_button: InvestBevelButton = $MaxButton

var _dir: int = 0
var _held: float = 0.0
var _since_tick: float = 0.0
var _rejecting: bool = false
var _shake_base: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	set_process(false)
	minus_button.custom_minimum_size = STEP_SIZE
	plus_button.custom_minimum_size = STEP_SIZE
	max_button.custom_minimum_size = MAX_SIZE
	field.custom_minimum_size = Vector2(0.0, STEP_SIZE.y)
	_style_field()
	minus_button.pressed.connect(press_minus)
	plus_button.pressed.connect(press_plus)
	max_button.pressed.connect(press_max)
	minus_button.button_down.connect(_on_down.bind(-1))
	plus_button.button_down.connect(_on_down.bind(1))
	minus_button.button_up.connect(_on_up)
	plus_button.button_up.connect(_on_up)
	field.text_changed.connect(_on_text_changed)
	field.text_submitted.connect(type_text)
	field.focus_exited.connect(_on_focus_exited)
	_show_value()
	_show_tooltip()


func ceiling() -> int:
	return maxi(min_value, max_value)


func press_minus() -> void:
	_try(value - 1)


func press_plus() -> void:
	_try(value + 1)


func press_max() -> void:
	_try(ceiling())


#Digits only; anything else is dropped, an empty field falls back to the current value.
func type_text(text: String) -> void:
	var digits: String = _digits_of(text)
	if digits == "":
		_show_value()
		return
	_try(int(digits))
	_show_value()


func set_value_silent(v: int) -> void:
	value = clampi(v, min_value, ceiling())


func is_rejecting() -> bool:
	return _rejecting


func hold_start(direction: int) -> void:
	_dir = signi(direction)
	_held = 0.0
	_since_tick = 0.0


func hold_stop() -> void:
	_dir = 0
	_held = 0.0
	_since_tick = 0.0
	set_process(false)


#One slice of a held button: nothing happens before the delay, one tick as it is crossed, then a
#tick every 80 ms after that.
func step_hold(delta: float) -> void:
	if _dir == 0:
		return
	var before: float = _held
	_held += delta
	if _held < HOLD_DELAY:
		return
	if before < HOLD_DELAY:
		_since_tick = 0.0
		_try(value + _dir * step_amount())
		return
	_since_tick += delta
	while _since_tick >= TICK_TIME and _dir != 0:
		_since_tick -= TICK_TIME
		_try(value + _dir * step_amount())


func step_amount() -> int:
	var over: float = maxf(0.0, _held - HOLD_DELAY)
	var grown: float = 1.0 + over / RAMP_SECONDS * float(STEP_MAX - STEP_MIN)
	return clampi(int(floor(grown)), STEP_MIN, STEP_MAX)


func end_reject() -> void:
	_rejecting = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if is_node_ready():
		field.position.x = _shake_base
		field.add_theme_color_override("font_color", InvestText.CREAM)


#Advance a live shake by hand; nothing happens when no reject runs.
func step_reject(seconds: float) -> void:
	if _tween == null or not _tween.is_valid():
		return
	_tween.custom_step(maxf(0.0, seconds))


func _try(target: int) -> void:
	var clamped: int = clampi(target, min_value, ceiling())
	if clamped != target:
		_reject()
	if clamped == value:
		return
	value = clamped
	value_changed.emit(value)


func _reject() -> void:
	hold_stop()
	if not is_node_ready():
		return
	_rejecting = true
	field.add_theme_color_override("font_color", InvestText.RED)
	if _tween != null and _tween.is_valid():
		_tween.kill()
		field.position.x = _shake_base
	else:
		_shake_base = field.position.x
	_tween = create_tween()
	var quarter: float = REJECT_TIME / 4.0
	_tween.tween_method(_set_shake, 0.0, SHAKE_OFFSET, quarter)
	_tween.tween_method(_set_shake, SHAKE_OFFSET, -SHAKE_OFFSET, quarter)
	_tween.tween_method(_set_shake, -SHAKE_OFFSET, SHAKE_OFFSET / 2.0, quarter)
	_tween.tween_method(_set_shake, SHAKE_OFFSET / 2.0, 0.0, quarter)
	_tween.tween_callback(end_reject)


func _set_shake(off: float) -> void:
	field.position.x = _shake_base + off


func _show_value() -> void:
	if not is_node_ready():
		return
	field.text = str(value)
	field.caret_column = field.text.length()


func _show_tooltip() -> void:
	if not is_node_ready():
		return
	max_button.tooltip_text = max_tooltip


func _style_field() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = InvestText.SWITCH_BG
	box.content_margin_left = FIELD_PAD
	box.content_margin_right = FIELD_PAD
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	field.add_theme_stylebox_override("normal", box)
	field.add_theme_stylebox_override("focus", box)
	field.add_theme_color_override("font_color", InvestText.CREAM)


func _on_down(direction: int) -> void:
	hold_start(direction)
	set_process(true)


func _on_up() -> void:
	hold_stop()


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


func _process(delta: float) -> void:
	step_hold(delta)
