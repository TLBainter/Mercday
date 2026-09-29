class_name MetricToggle extends Button

#One row of the MetricList: a ring checkbox in the metric colour, the metric name, a compare arrow
#and a Y button that asks for this metric's axis. The colour comes from the list's palette, by def
#index; the description fills the row tooltip. The arrow reads the merc against the reference the
#viewer picked, either the team average or a second merc. A row whose metric needs an upgrade the
#guild has not bought shows the gold lock in place of the arrow and refuses to switch on.

const ON_TEXT := Color(0.952941, 0.917647, 0.843137, 1)
const OFF_TEXT := Color(0.541176, 0.592157, 0.678431, 1)
const OFF_BOX := Color(0.039216, 0.058824, 0.109804, 1)
const ON_BG := Color(0.168627, 0.309804, 0.541176, 1)
const ON_BORDER := Color(0.231373, 0.435294, 0.713725, 1)
const OFF_BG := Color(0.086275, 0.137255, 0.247059, 1)
const OFF_BORDER := Color(0.121569, 0.207843, 0.376471, 1)
const Y_OFF_BG := Color(0.086275, 0.137255, 0.247059, 1)
const Y_OFF_TEXT := Color(0.368627, 0.462745, 0.600000, 1)
const Y_ON_TEXT := Color(0.039216, 0.058824, 0.109804, 1)
const ARROW_GOOD := Color(0.423529, 0.764706, 0.415686, 1)
const ARROW_BAD := Color(0.909804, 0.345098, 0.247059, 1)
const ARROW_FLAT := Color(0.352941, 0.650980, 0.909804, 1)
const BORDER_WIDTH := 2
const SWATCH_RING := 2.0
const SWATCH_DOT := 4.0
const PCT_FLOOR := 0.5
const PCT_STRAIGHT := 15.0
const Y_TIP := "Use as Y-axis"

signal focus_requested

@export var key: String = "":
	set(value):
		key = value
		refresh()
@export var label: String = "":
	set(value):
		label = value
		refresh()
@export var description: String = "":
	set(value):
		description = value
		refresh()
@export var color: Color = Color(0.949020, 0.549020, 0.156863, 1):
	set(value):
		color = value
		refresh()
@export var locked: bool = false:
	set(value):
		locked = value
		refresh()

var _focused: bool = false
var _pct: float = NAN
var _good: int = 0

@onready var swatch: Control = $Row/Swatch
@onready var name_label: Label = $Row/Name
@onready var lock: FeatureLock = $Row/Lock
@onready var arrow: Control = $Row/Arrow
@onready var y_button: Button = $Row/Y


func _ready() -> void:
	toggled.connect(_on_toggled)
	swatch.draw.connect(_draw_swatch)
	arrow.draw.connect(_draw_arrow)
	y_button.tooltip_text = Y_TIP
	y_button.pressed.connect(_on_y_pressed)
	refresh()


func set_metric(metric_key: String, metric_label: String, metric_color: Color,
		metric_description: String = "") -> void:
	key = metric_key
	label = metric_label
	description = metric_description if metric_description != "" else metric_label
	color = metric_color


#Locks or opens this row; info carries the FeatureLock copy of MetricsLocks.metric_lock().
func set_locked(on: bool, info: Dictionary = {}) -> void:
	if not is_node_ready():
		locked = on
		return
	lock.feature = String(info.get("feature", ""))
	lock.plan = String(info.get("plan", "")) if on else ""
	lock.entitlement = String(info.get("entitlement", "")) if on else ""
	lock.entitlement_tier = int(info.get("entitlement_tier", 0))
	lock.required_plan = _plan_rank(on)
	lock.upgrade = String(info.get("upgrade", ""))
	lock.upgrade_id = String(info.get("upgrade_id", "")) if on else ""
	lock.tier = int(info.get("tier", 1))
	lock.tiers = int(info.get("tiers", 1))
	lock.always_visible = on
	locked = on


#An open row pins its lock shut: no key, no upgrade and the lowest plan rank, so a later plan
#change never pops it back into the layout.
static func _plan_rank(on: bool) -> int:
	if on:
		return SubscriptionManager.Plan.ENTERPRISE
	return SubscriptionManager.Plan.FREE


#Mirrors a state change made in code; the pressed signal never fires for it.
func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	refresh()


#Marks this row as the one the Y axis is scaled to.
func set_focused(on: bool) -> void:
	_focused = on
	refresh()


func is_focused_metric() -> bool:
	return _focused


#The gap between this merc and the reference, and whether a rise is the good way for the metric.
func set_compare(pct: float, good: int) -> void:
	_pct = pct
	_good = good
	refresh()


func compare_visible() -> bool:
	return arrow_kind(_pct) != 0


func compare_color() -> Color:
	if _good == 0:
		return ARROW_FLAT
	var rising: bool = _pct > 0.0
	var wanted: bool = _good > 0
	return ARROW_GOOD if rising == wanted else ARROW_BAD


#0 no arrow, 1 a slanted arrow for a small move, 2 an upright one for a wide gap.
static func arrow_kind(pct: float) -> int:
	if is_nan(pct) or absf(pct) < PCT_FLOOR:
		return 0
	if absf(pct) >= PCT_STRAIGHT:
		return 2
	return 1


#The merc value against the reference as a percentage; a zero reference reads as a full swing.
static func compare_pct(mv: float, am: float) -> float:
	if is_nan(mv) or is_nan(am):
		return NAN
	if is_zero_approx(am):
		if is_zero_approx(mv):
			return 0.0
		return 100.0 if mv > 0.0 else -100.0
	return (mv - am) / absf(am) * 100.0


func _on_toggled(_on: bool) -> void:
	refresh()


func _on_y_pressed() -> void:
	focus_requested.emit()


func refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = label
	tooltip_text = description
	name_label.add_theme_color_override("font_color", ON_TEXT if button_pressed else OFF_TEXT)
	disabled = locked
	y_button.disabled = locked
	_style_row()
	swatch.queue_redraw()
	arrow.visible = compare_visible() and not locked
	arrow.queue_redraw()
	var lit: bool = _focused and button_pressed
	var box := StyleBoxFlat.new()
	box.bg_color = color if lit else Y_OFF_BG
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		y_button.add_theme_stylebox_override(style_name, box)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		y_button.add_theme_color_override(color_name, Y_ON_TEXT if lit else Y_OFF_TEXT)


func _style_row() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = ON_BG if button_pressed else OFF_BG
	box.border_color = ON_BORDER if button_pressed else OFF_BORDER
	box.set_border_width_all(BORDER_WIDTH)
	for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, box)


func _draw_swatch() -> void:
	var rect := Rect2(Vector2.ZERO, swatch.size)
	swatch.draw_rect(rect, color, false, SWATCH_RING)
	if not button_pressed:
		return
	var middle: Vector2 = rect.get_center()
	swatch.draw_rect(Rect2(middle - Vector2(SWATCH_DOT, SWATCH_DOT) * 0.5,
		Vector2(SWATCH_DOT, SWATCH_DOT)), color)


#A 12x12 arrow: upright when the gap is wide, slanted when it is small, up when the merc leads.
func _draw_arrow() -> void:
	var kind: int = arrow_kind(_pct)
	if kind == 0:
		return
	var tint: Color = compare_color()
	var up: bool = _pct > 0.0
	if kind == 2:
		_arrow_rect(Rect2(5, 4, 2, 7), up, tint)
		_arrow_rect(Rect2(5, 1, 2, 1), up, tint)
		_arrow_rect(Rect2(4, 2, 4, 1), up, tint)
		_arrow_rect(Rect2(3, 3, 6, 1), up, tint)
		return
	_arrow_rect(Rect2(2, 8, 2, 2), up, tint)
	_arrow_rect(Rect2(4, 6, 2, 2), up, tint)
	_arrow_rect(Rect2(6, 4, 2, 2), up, tint)
	_arrow_rect(Rect2(7, 2, 4, 2), up, tint)
	_arrow_rect(Rect2(9, 2, 2, 4), up, tint)


#Draws one arrow block, flipped to the bottom of the box when the arrow points down.
func _arrow_rect(rect: Rect2, up: bool, tint: Color) -> void:
	if up:
		arrow.draw_rect(rect, tint)
		return
	arrow.draw_rect(Rect2(rect.position.x, arrow.size.y - rect.position.y - rect.size.y,
		rect.size.x, rect.size.y), tint)
