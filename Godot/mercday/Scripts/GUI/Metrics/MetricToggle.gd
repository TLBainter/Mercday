class_name MetricToggle extends BevelButton

#One row of the MetricList: a ring checkbox in the metric colour, the metric name, a compare arrow
#and a Y button that asks for this metric's axis. The colour comes from the list's palette, by def
#index; the description fills the row tooltip. The arrow reads the merc against the reference the
#viewer picked, either the team average or a second merc. A row whose metric needs an upgrade the
#guild has not bought shows the gold lock in place of the arrow and refuses to switch on.

const ON_TEXT: Color = GuiColors.CREAM
const OFF_TEXT: Color = GuiColors.DIM_TEXT
const OFF_BG := Color(0.086275, 0.137255, 0.247059, 1)
const OFF_BORDER: Color = GuiColors.BLUE_LO
const Y_OFF_BG := Color(0.086275, 0.137255, 0.247059, 1)
const Y_OFF_TEXT: Color = GuiColors.MUTED
const Y_ON_TEXT: Color = GuiColors.INK
const ARROW_GOOD: Color = GuiColors.GREEN
const ARROW_BAD: Color = GuiColors.RED
const ARROW_FLAT: Color = GuiColors.LIGHT_BLUE
const SWATCH_RING := 2.0
const SWATCH_DOT := 4.0
const PCT_FLOOR := 0.5
#The 9x8 arrow window of the 16x16 cell, the value Icons.centered_box(9, 8) returns.
const ARROW_BOX: Rect2i = Rect2i(3, 4, 9, 8)
const ARROW_SCALE: int = 1
const PCT_STRAIGHT := 15.0
const Y_TIP := "Use as Y-axis"
const Y_TEXT_KEYS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color"]

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
@export var color: Color = GuiColors.ORANGE:
	set(value):
		color = value
		refresh()
@export var locked: bool = false:
	set(value):
		locked = value
		refresh()

var _focused: bool = false
var _pct: float
var _good: int = 0

@onready var swatch: Control = $Row/Swatch
@onready var name_label: Label = $Row/Name
@onready var lock: FeatureLock = $Row/Lock
@onready var arrow: Control = $Row/Arrow
@onready var y_button: Button = $Row/Y


#An off row paints OFF_BG with OFF_BORDER as the lit bevel; an on row paints the blue palette.
func _init() -> void:
	_pct = NAN
	set_colors(OFF_BG, OFF_BORDER, OFF_BG.darkened(0.25), OFF_TEXT)
	active_kind = &"blue"
	click_move = ButtonFx.ClickMove.NONE
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
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
	swatch.queue_redraw()
	arrow.visible = compare_visible() and not locked
	arrow.queue_redraw()
	var lit: bool = _focused and button_pressed
	var box: StyleBoxFlat = GuiStyle.flat(color if lit else Y_OFF_BG)
	GuiStyle.set_all_boxes(y_button, box, STATES)
	GuiStyle.set_all_font_colors(y_button, Y_ON_TEXT if lit else Y_OFF_TEXT, Y_TEXT_KEYS)


func _draw_swatch() -> void:
	var rect := Rect2(Vector2.ZERO, swatch.size)
	swatch.draw_rect(rect, color, false, SWATCH_RING)
	if not button_pressed:
		return
	var middle: Vector2 = rect.get_center()
	swatch.draw_rect(Rect2(middle - Vector2(SWATCH_DOT, SWATCH_DOT) * 0.5,
		Vector2(SWATCH_DOT, SWATCH_DOT)), color)


#A 9x8 atlas arrow: upright when the gap is wide, slanted when it is small, up when the merc leads.
func _draw_arrow() -> void:
	var shape: int = arrow_kind(_pct)
	if shape == 0:
		return
	Icons.draw_texture(arrow, Icons.baked(arrow_id(shape, _pct > 0.0), ARROW_SCALE,
		Icons.MODE_GRAY, false, ARROW_BOX), Vector2.ZERO, 1, compare_color())


#The atlas id of one arrow: shape 2 is the upright pair, shape 1 the slanted pair, shape 0 no arrow.
static func arrow_id(shape: int, up: bool) -> String:
	if shape == 2:
		return "trend_up" if up else "trend_down"
	if shape == 1:
		return "trend_diag_up" if up else "trend_diag_down"
	return ""
