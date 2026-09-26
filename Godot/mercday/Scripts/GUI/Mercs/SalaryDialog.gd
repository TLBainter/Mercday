class_name SalaryDialog extends Control

#The wage popup: a dimmed backdrop over the prototype's dialog box with a held minus and plus pair.
#The wage clamps to 1 .. max_payable and the opinion preview reads SalarySystem before anything is
#written. It rides GuiFrameStack like the other modal frames, so Esc reaches the topmost one.

signal confirmed(new_salary: int, opinion_delta: int)
signal cancelled

const TITLE_TEXT: String = "Manage Salary"
const ENOUGH_TEXT: String = "Enough notes to cover this salary."
const SHORT_TEXT: String = "Not enough notes for this salary."
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
const CREAM: Color = Color("#f3ead7")
const HOLD_START_RATE: float = 4.0
const HOLD_RAMP_SECONDS: float = 2.0
const HOLD_DELAY_SECONDS: float = 0.25
const BOX_INSET: float = 4.0
const BOX_BORDER: int = 4
const BOX_BG: Color = Color("#1a2b4d")
const BOX_EDGE: Color = Color("#f28c28")
const EDGE_HI: Color = Color("#28447a")
const EDGE_LO: Color = Color("#111c33")
const EDGE_PX: float = 4.0

@export var hold_peak_rate: float = 100.0

@onready var backdrop: Panel = $Backdrop
@onready var box: PanelContainer = $Box
@onready var edges: Control = $Box/Edges
@onready var name_label: Label = $Box/Pad/Rows/MercName
@onready var current_label: Label = $Box/Pad/Rows/Current
@onready var minus_button: Button = $Box/Pad/Rows/Stepper/Minus
@onready var value_label: Label = $Box/Pad/Rows/Stepper/Value
@onready var plus_button: Button = $Box/Pad/Rows/Stepper/Plus
@onready var opinion_label: Label = $Box/Pad/Rows/Opinion
@onready var note_label: Label = $Box/Pad/Rows/Note
@onready var confirm_button: Button = $Box/Pad/Rows/Buttons/Confirm
@onready var cancel_button: Button = $Box/Pad/Rows/Buttons/Cancel

var merc_uid: int = 0
var merc_name: String = ""
var current: int = 0
var max_payable: int = 0

var _value: int = 1
var _hold_dir: int = 0
var _hold_time: float = 0.0
var _hold_carry: float = 0.0


func _ready() -> void:
	top_level = true
	size = get_viewport().get_visible_rect().size
	edges.draw.connect(_draw_edges)
	edges.resized.connect(edges.queue_redraw)
	_style_box()
	minus_button.button_down.connect(_on_hold.bind(-1))
	minus_button.button_up.connect(_stop_hold)
	plus_button.button_down.connect(_on_hold.bind(1))
	plus_button.button_up.connect(_stop_hold)
	confirm_button.pressed.connect(press_confirm)
	cancel_button.pressed.connect(press_cancel)
	set_process(false)
	_refresh()
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		GuiFrameStack.remove(self)


func open_for(view: MercView) -> void:
	if view == null:
		return
	merc_uid = view.uid
	merc_name = view.name
	current = view.monthly_salary
	max_payable = GameState.bank_notes
	set_value(current)
	size = get_viewport().get_visible_rect().size
	show()
	_center()
	GuiFrameStack.push(self)


func set_value(v: int) -> void:
	_value = clampi(v, 1, maxi(1, max_payable))
	_refresh()


func step(delta: int) -> void:
	set_value(_value + delta)


func value() -> int:
	return _value


func opinion_delta() -> int:
	return SalarySystem.opinion_delta(current, _value)


func press_confirm() -> void:
	_stop_hold()
	_dismiss()
	confirmed.emit(_value, opinion_delta())


func press_cancel() -> void:
	_stop_hold()
	_dismiss()
	cancelled.emit()


func _dismiss() -> void:
	hide()
	GuiFrameStack.remove(self)


#The box carries the ConfirmDialog look the prototype draws it with: the deep panel fill, the four
#pixel orange frame and the inset highlight the Edges child paints.
func _style_box() -> void:
	var base: StyleBoxFlat = box.get_theme_stylebox(&"panel", &"PopupBox") as StyleBoxFlat
	var style: StyleBoxFlat
	if base != null:
		style = base.duplicate()
	else:
		style = StyleBoxFlat.new()
	style.bg_color = BOX_BG
	style.border_width_left = BOX_BORDER
	style.border_width_top = BOX_BORDER
	style.border_width_right = BOX_BORDER
	style.border_width_bottom = BOX_BORDER
	style.border_color = BOX_EDGE
	style.content_margin_left = BOX_INSET
	style.content_margin_top = BOX_INSET
	style.content_margin_right = BOX_INSET
	style.content_margin_bottom = BOX_INSET
	box.add_theme_stylebox_override(&"panel", style)


func _draw_edges() -> void:
	var span: Vector2 = edges.size
	edges.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), EDGE_HI)
	edges.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), EDGE_HI)
	edges.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), EDGE_LO)
	edges.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), EDGE_LO)


func _center() -> void:
	backdrop.offset_bottom = -GuiFrameStack.bottom_reserve
	box.reset_size()
	box.position = Vector2((size.x - box.size.x) / 2.0,
		(GuiFrameStack.band_height(size.y) - box.size.y) / 2.0)
	box.position.y = maxf(box.position.y, 0.0)


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = merc_name
	current_label.text = "Current: %d" % current
	value_label.text = str(_value)
	var delta: int = opinion_delta()
	opinion_label.text = "Opinion %+d" % delta
	var tint: Color = CREAM
	if delta > 0:
		tint = GREEN
	elif delta < 0:
		tint = RED
	opinion_label.add_theme_color_override("font_color", tint)
	var covered: bool = _value <= max_payable
	note_label.text = ENOUGH_TEXT if covered else SHORT_TEXT
	note_label.add_theme_color_override("font_color", GREEN if covered else RED)


func _on_hold(direction: int) -> void:
	step(direction)
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
		step(_hold_dir)


#Ramps from a slow tap rate to the peak over HOLD_RAMP_SECONDS of holding.
static func hold_rate(held_seconds: float, peak: float) -> float:
	var t: float = clampf(held_seconds / HOLD_RAMP_SECONDS, 0.0, 1.0)
	return lerpf(HOLD_START_RATE, peak, t)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if GuiFrameStack.top() != self:
		return
	press_cancel()
	get_viewport().set_input_as_handled()
