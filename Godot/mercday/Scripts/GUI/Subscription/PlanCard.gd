class_name PlanCard extends Control

#One Mercday plan card. Every label, colour and disabled rule comes from the handoff prototype's
#planCards table: the card is dead while it is the current plan, while the roster is over the
#plan's cap, or while the bank cannot cover one month of the fee. Enterprise is the exception; as
#the current plan its button opens the Customize tab instead.

signal switch_requested(plan: int)
signal customize_requested

const ENTERPRISE_KEY: String = "enterprise"
const RING_CURRENT: Color = Color("#6cc36a")
const RING_IDLE: Color = Color("#1f3560")
const OUTLINE: Color = Color("#0a0f1c")
const RING_PX: float = 3.0
const OUTLINE_PX: float = 5.0
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#5e7699")
const RED: Color = Color("#e8583f")
const ORANGE: Color = Color("#f28c28")
const PILL_BG: Color = Color("#6cc36a")
const PILL_TEXT: Color = Color("#0a0f1c")
const PILL_RIGHT: float = 12.0
const PILL_TOP: float = 10.0
const DISABLED_ALPHA: float = 0.45
const ORANGE_HI: Color = Color("#ffb266")
const ORANGE_LO: Color = Color("#b85a12")
const DEAD_FILL: Color = Color("#1a2b4d")
const DEAD_HI: Color = Color("#28447a")
const DEAD_LO: Color = Color("#111c33")
const ACCENT_HEIGHT: int = 6
const BUTTON_HEIGHT: int = 42
const TAGLINE_MIN_HEIGHT: int = 42
const REASON_MIN_HEIGHT: int = 15
const CARD_MIN_WIDTH: int = 240

@export var plan_id: String = "free":
	set(value):
		plan_id = value
		refresh()

@onready var ring: Control = $Ring
@onready var bg: Panel = $Bg
@onready var name_label: Label = $Pad/Rows/PlanName
@onready var price_label: Label = $Pad/Rows/Prices/Price
@onready var estimate_label: Label = $Pad/Rows/Prices/Estimate
@onready var tagline_label: Label = $Pad/Rows/Tagline
@onready var reason_label: Label = $Pad/Rows/Reason
@onready var switch_button: BevelButton = $Pad/Rows/Switch
@onready var divider: ColorRect = $Pad/Rows/Divider
@onready var features_box: VBoxContainer = $Pad/Rows/Features
@onready var accent: ColorRect = $Accent
@onready var pill: PanelContainer = $Pill
@onready var pill_label: Label = $Pill/PillText

var _check_row: PackedScene = preload("res://Scenes/GUI/Shared/CheckRow.tscn")
var _current: bool = false
var _custom: bool = false
var _too_many: bool = false
var _poor: bool = false
var _enabled: bool = false
var _crew: int = 0
var _fee: int = 0
var _cap: int = 0


func _ready() -> void:
	custom_minimum_size.x = float(CARD_MIN_WIDTH)
	ring.draw.connect(_draw_ring)
	ring.resized.connect(ring.queue_redraw)
	switch_button.pressed.connect(press_switch)
	switch_button.custom_minimum_size.y = float(BUTTON_HEIGHT)
	tagline_label.custom_minimum_size.y = float(TAGLINE_MIN_HEIGHT)
	reason_label.custom_minimum_size.y = float(REASON_MIN_HEIGHT)
	accent.custom_minimum_size.y = float(ACCENT_HEIGHT)
	divider.color = RING_IDLE
	pill_label.add_theme_color_override(&"font_color", PILL_TEXT)
	pill.add_theme_stylebox_override(&"panel", _pill_style())
	price_label.add_theme_color_override(&"font_color", SKY)
	estimate_label.add_theme_color_override(&"font_color", MUTED)
	tagline_label.add_theme_color_override(&"font_color", CREAM)
	reason_label.add_theme_color_override(&"font_color", RED)
	name_label.add_theme_color_override(&"font_color", CREAM)
	SubscriptionManager.changed.connect(refresh)
	GameState.money_changed.connect(_on_money_changed)
	GameState.roster_changed.connect(refresh)
	resized.connect(_place_pill)
	refresh()


func plan_index() -> int:
	return (UpgradeDefs.PLANS.keys() as Array).find(plan_id)


func is_current() -> bool:
	return _current


func is_enabled() -> bool:
	return _enabled


func button_text() -> String:
	if _custom:
		return "Customize Plan"
	if _current:
		return "Current Plan"
	var short: String = String(_data().get("short", plan_id))
	return "Switch to %s Plan" % short


func button_tooltip() -> String:
	if _custom:
		return "Open the Customize tab"
	if _current:
		return "This is your current plan"
	if _too_many:
		return "You have %d mercs. %s allows up to %d." % [_crew, _plan_name(), _cap]
	if _poor:
		return "You need at least %d notes (1 month of service) to switch." % _fee
	return ""


func reason_text() -> String:
	if _current:
		return ""
	if _too_many:
		var over: int = _crew - _cap
		return "You must fire %d merc%s before you are eligible to downgrade" % [over,
			"" if over == 1 else "s"]
	if _poor:
		return "Not enough notes: 1 month costs %d." % _fee
	return ""


func price_text() -> String:
	var per_merc: int = int(_data().get("per_merc", 0))
	if per_merc > 0:
		return "%d notes per merc / month" % per_merc
	return "Free"


func estimate_text() -> String:
	if int(_data().get("per_merc", 0)) > 0:
		return "%d notes / month for your %d mercs" % [_fee, _crew]
	return "No service fee"


func features() -> Array[String]:
	var out: Array[String] = []
	for line: Variant in _data().get("features", []) as Array:
		out.append(String(line))
	return out


func accent_color() -> Color:
	return _data().get("accent", ORANGE) as Color


#The button does nothing while the card is dead; on the current Enterprise card it changes tabs.
func press_switch() -> void:
	if _custom:
		customize_requested.emit()
		return
	if not _enabled:
		return
	switch_requested.emit(plan_index())


func refresh() -> void:
	if not is_node_ready():
		return
	var data: Dictionary = _data()
	if data.is_empty():
		return
	var per_merc: int = int(data.get("per_merc", 0))
	_crew = SubscriptionManager.employed()
	_fee = per_merc * _crew
	_cap = int(data.get("max_mercs", 0))
	_current = SubscriptionManager.plan_key() == plan_id
	_custom = _current and plan_id == ENTERPRISE_KEY
	_too_many = _crew > _cap
	_poor = per_merc > 0 and GameState.bank_notes < _fee
	_enabled = not ((_current and not _custom) or _too_many or _poor)
	name_label.text = String(data.get("name", ""))
	price_label.text = price_text()
	estimate_label.text = estimate_text()
	tagline_label.text = String(data.get("tagline", ""))
	reason_label.text = reason_text()
	switch_button.text = button_text()
	switch_button.tooltip_text = button_tooltip()
	_style_button()
	accent.color = accent_color()
	pill.visible = _current
	_build_features()
	ring.queue_redraw()
	_place_pill()


func _data() -> Dictionary:
	return UpgradeDefs.PLANS.get(plan_id, {}) as Dictionary


func _plan_name() -> String:
	return String(_data().get("name", ""))


func _on_money_changed(_bank_notes: int) -> void:
	refresh()


func _build_features() -> void:
	for child: Node in features_box.get_children():
		child.queue_free()
		features_box.remove_child(child)
	for line: String in features():
		var row: CheckRow = _check_row.instantiate() as CheckRow
		features_box.add_child(row)
		row.color = accent_color()
		row.text = line


#The prototype's 3 px plan ring with the 5 px ink edge around it, both outside the card body.
func _draw_ring() -> void:
	var box: Vector2 = ring.size
	var edge: Color = RING_CURRENT if _current else RING_IDLE
	ring.draw_rect(Rect2(Vector2.ONE * -OUTLINE_PX, box + Vector2.ONE * OUTLINE_PX * 2.0), OUTLINE)
	ring.draw_rect(Rect2(Vector2.ONE * -RING_PX, box + Vector2.ONE * RING_PX * 2.0), edge)


#A dead card keeps its button in place, dimmed and in the locked palette, so the tooltip still
#explains why the switch is refused.
func _style_button() -> void:
	var live: bool = _enabled or _custom
	if live:
		switch_button.set_colors(ORANGE, ORANGE_HI, ORANGE_LO, OUTLINE)
	else:
		switch_button.set_colors(DEAD_FILL, DEAD_HI, DEAD_LO, GuiColors.LOCKED_TEXT)
	switch_button.modulate.a = 1.0 if live else DISABLED_ALPHA
	switch_button.mouse_default_cursor_shape = (Control.CURSOR_POINTING_HAND if live
		else Control.CURSOR_FORBIDDEN)


func _pill_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PILL_BG
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


#The "Current Plan" tag sits over the top edge, its right side 12 px in from the card corner.
func _place_pill() -> void:
	if not is_node_ready():
		return
	pill.reset_size()
	pill.anchor_left = 1.0
	pill.anchor_top = 0.0
	pill.anchor_right = 1.0
	pill.anchor_bottom = 0.0
	pill.offset_right = -PILL_RIGHT
	pill.offset_left = -PILL_RIGHT - pill.size.x
	pill.offset_top = -PILL_TOP
	pill.offset_bottom = -PILL_TOP + pill.size.y
