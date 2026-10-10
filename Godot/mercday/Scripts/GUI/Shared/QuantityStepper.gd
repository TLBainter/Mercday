class_name QuantityStepper extends HBoxContainer

#Minus, value, plus stepper. A held button steps at once, waits hold_delay, then repeats. With
#hold_tick at zero it follows the SalaryDialog ramp, the rate climbing from HOLD_START_RATE to
#hold_peak_rate over hold_ramp seconds; with hold_tick set it steps once as the delay passes and
#then every hold_tick seconds, the amount per tick growing to hold_step_max steps over hold_ramp.
#The value always clamps between min_value and the ceiling and never wraps. A real move plays the
#step click; a step past a bound plays the reject cue instead, stops the hold, reports rejected and
#turns the value box red and shakes it. A reject_seconds of zero clamps silently.

signal value_changed(new_value: int)
signal rejected(side: int)

const HOLD_START_RATE: float = 4.0
const HOLD_RAMP_SECONDS: float = 2.0
const HOLD_DELAY_SECONDS: float = 0.25
const DISABLED_ALPHA: float = 0.4
const REJECT_SECONDS: float = 0.4
const VALUE_BEVEL: float = 2.0
const STYLE_REST: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/stepper_value_box.tres")
const STYLE_REJECT: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/filter_check_reject.tres")

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
@export var hold_delay: float = HOLD_DELAY_SECONDS
@export var hold_ramp: float = HOLD_RAMP_SECONDS
@export var hold_tick: float = 0.0
@export var hold_step_max: int = 1
@export var reject_seconds: float = REJECT_SECONDS
#Offsets in pixels the value box steps through over one reject.
@export var shake_steps: PackedFloat32Array = PackedFloat32Array([-5.0, 5.0, -3.0, 3.0, 0.0])
#Tooltip for a MaxButton child that jumps to the ceiling; the base scene has no such button.
@export var ceiling_tooltip: String = "":
	set(v):
		ceiling_tooltip = v
		_refresh()
@export var disabled: bool = false:
	set(v):
		disabled = v
		_apply_disabled()

@onready var minus_button: Button = $Minus
@onready var value_box: Control = $ValueBox
@onready var value_label: Label = $ValueBox/Value
@onready var plus_button: Button = $Plus

var _hold_dir: int = 0
var _hold_time: float = 0.0
var _hold_carry: float = 0.0
var _since_tick: float = 0.0
var _reject_left: float = 0.0
var _reject_side: int = 0
var _shake_base: float = 0.0


func _ready() -> void:
	#Each real move plays the step click itself, so the release click of the two buttons stays silent.
	UiSfx.override_click(minus_button, null)
	UiSfx.override_click(plus_button, null)
	minus_button.button_down.connect(_on_hold.bind(-1))
	minus_button.button_up.connect(hold_stop)
	plus_button.button_down.connect(_on_hold.bind(1))
	plus_button.button_up.connect(hold_stop)
	value_box.draw.connect(_on_value_box_draw)
	set_process(false)
	_apply_disabled()
	_refresh()


#The value box's raised two tone edge, painted over its flat stylebox; red while a reject shows.
func _on_value_box_draw() -> void:
	var rect := Rect2(Vector2.ZERO, value_box.size)
	var hi: Color = GuiColors.DANGER_HI if is_rejecting() else GuiColors.EDGE_HI
	var lo: Color = GuiColors.DANGER_LO if is_rejecting() else GuiColors.EDGE_LO
	BevelButton.paint_edges(value_box, rect, hi, lo, VALUE_BEVEL)


func ceiling() -> int:
	return maxi(min_value, max_value)


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


func hold_start(direction: int) -> void:
	_hold_dir = signi(direction)
	_hold_time = 0.0
	_hold_carry = 0.0
	_since_tick = 0.0


func hold_stop() -> void:
	_hold_dir = 0
	_hold_time = 0.0
	_hold_carry = 0.0
	_since_tick = 0.0
	set_process(is_rejecting())


#One slice of a held button; nothing happens before hold_delay.
func step_hold(delta: float) -> void:
	if _hold_dir == 0:
		return
	var before: float = _hold_time
	_hold_time += delta
	if _hold_time < hold_delay:
		return
	if hold_tick > 0.0:
		if before < hold_delay:
			_since_tick = 0.0
			_move(_hold_dir * step_amount())
			return
		_since_tick += delta
		while _since_tick >= hold_tick and _hold_dir != 0:
			_since_tick -= hold_tick
			_move(_hold_dir * step_amount())
		return
	_hold_carry += hold_rate(_hold_time - hold_delay, hold_peak_rate, hold_ramp) * delta
	while _hold_carry >= 1.0 and _hold_dir != 0:
		_hold_carry -= 1.0
		_step(_hold_dir)


#The amount one hold tick moves: step, times a count that grows from 1 to hold_step_max.
func step_amount() -> int:
	if hold_tick <= 0.0 or hold_step_max <= 1:
		return step
	var over: float = maxf(0.0, _hold_time - hold_delay)
	var grown: float = 1.0 + over / maxf(0.001, hold_ramp) * float(hold_step_max - 1)
	return step * clampi(floori(grown), 1, hold_step_max)


func is_rejecting() -> bool:
	return _reject_left > 0.0


#1 after a step past the ceiling, -1 after one under min_value, 0 once the reject ends.
func rejected_side() -> int:
	return _reject_side


func reject_style() -> StyleBoxFlat:
	return STYLE_REJECT if is_rejecting() else STYLE_REST


func shake_offset() -> float:
	if _reject_left <= 0.0 or shake_steps.is_empty():
		return 0.0
	var done: float = 1.0 - _reject_left / maxf(0.001, reject_seconds)
	var index: int = clampi(int(done * float(shake_steps.size())), 0, shake_steps.size() - 1)
	return shake_steps[index]


#Advances a live reject by hand; nothing happens when no reject runs.
func step_reject(seconds: float) -> void:
	if not is_rejecting():
		return
	var left: float = _reject_left - maxf(0.0, seconds)
	#The reject must still be live when end_reject runs, or the rest style never returns.
	if left <= 0.0:
		end_reject()
	else:
		_reject_left = left
		_show_reject()


func end_reject() -> void:
	var was_rejecting: bool = is_rejecting()
	_reject_left = 0.0
	_reject_side = 0
	if was_rejecting:
		_show_reject()
	set_process(_hold_dir != 0)


func _step(direction: int) -> void:
	_move(direction * step)


#A real move plays the step click unless the same move runs past a bound, which plays the reject.
func _move(amount: int) -> void:
	var target: int = value + amount
	var clamped: int = clampi(target, min_value, ceiling())
	if clamped != value:
		if clamped == target or reject_seconds <= 0.0:
			UiSfx.play_step(self)
		value = clamped
		value_changed.emit(value)
	if clamped != target:
		_reject(signi(target - clamped))


func _reject(side: int) -> void:
	if reject_seconds <= 0.0:
		return
	hold_stop()
	GameSfx.play_reject()
	if not is_rejecting() and is_node_ready():
		_shake_base = value_box.position.x
	_reject_side = side
	_reject_left = reject_seconds
	rejected.emit(side)
	_show_reject()
	set_process(true)


#The value box turns red for the whole shake; the number keeps its own colour.
func _show_reject() -> void:
	if not is_node_ready():
		return
	value_box.add_theme_stylebox_override(&"panel", reject_style())
	value_box.position.x = _shake_base + shake_offset()
	value_box.queue_redraw()


func _refresh() -> void:
	if not is_node_ready():
		return
	value_label.text = str(value)
	var ceiling_button: Control = get_node_or_null(^"MaxButton") as Control
	if ceiling_button != null:
		ceiling_button.tooltip_text = ceiling_tooltip


func _apply_disabled() -> void:
	if not is_node_ready():
		return
	minus_button.disabled = disabled
	plus_button.disabled = disabled
	modulate.a = DISABLED_ALPHA if disabled else 1.0
	if disabled:
		hold_stop()


func _on_hold(direction: int) -> void:
	if disabled:
		return
	_step(direction)
	#A press that runs into a bound arms no hold; a reject still shaking on the other side does not block one.
	if is_rejecting() and _reject_side == signi(direction):
		return
	hold_start(direction)
	set_process(true)


func _process(delta: float) -> void:
	step_reject(delta)
	step_hold(delta)
	set_process(_hold_dir != 0 or is_rejecting())


#Ramps from a slow tap rate to the peak over ramp seconds of holding.
static func hold_rate(held_seconds: float, peak: float, ramp: float = HOLD_RAMP_SECONDS) -> float:
	var t: float = clampf(held_seconds / ramp, 0.0, 1.0)
	return lerpf(HOLD_START_RATE, peak, t)
