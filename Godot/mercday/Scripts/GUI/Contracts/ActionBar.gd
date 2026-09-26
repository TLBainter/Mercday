class_name ActionBar extends PanelContainer

#The dispatch window's bottom bar: the odds block on the left, the three small actions beside it and
#the Dispatch tile on the right. The window owns the rules; the bar only reports the presses.

signal optimize_pressed
signal clear_pressed
signal cancel_pressed
signal dispatch_pressed

const CLEAR_FILL: Color = Color("#6b7488")
const CLEAR_INK: Color = Color("#f3ead7")
const CLEAR_DIM: float = 0.4
const DEAD_FILL: Color = Color("#2a3550")
const DEAD_INK: Color = Color("#5e7699")
const EDGE: Color = Color("#0a0f1c")
const EDGE_PX: int = 3
const PAD_X: float = 8.0
const PAD_Y: float = 6.0

@onready var odds_label: Label = $Pad/Row/Odds/Head/OddsLabel
@onready var meter: SuccessMeter = $Pad/Row/Odds/Meter
@onready var hint_label: Label = $Pad/Row/Odds/Hint
@onready var optimize_button: Button = $Pad/Row/Buttons/Optimize
@onready var clear_button: Button = $Pad/Row/Buttons/Clear
@onready var cancel_button: Button = $Pad/Row/Buttons/Cancel
@onready var dispatch_button: Button = $Pad/Row/Dispatch


func _ready() -> void:
	optimize_button.pressed.connect(func() -> void: optimize_pressed.emit())
	clear_button.pressed.connect(func() -> void: clear_pressed.emit())
	cancel_button.pressed.connect(func() -> void: cancel_pressed.emit())
	dispatch_button.pressed.connect(func() -> void: dispatch_pressed.emit())
	_style_clear()
	set_odds(0)
	set_ready(false)
	set_dirty(false)


func set_odds(value: int) -> void:
	if not is_node_ready():
		return
	meter.odds = value
	odds_label.text = "%d%%" % value
	odds_label.add_theme_color_override(&"font_color", GuiTypes.odds_color(value))


func set_hint(text: String) -> void:
	if is_node_ready():
		hint_label.text = text


func set_ready(on: bool) -> void:
	if not is_node_ready():
		return
	dispatch_button.disabled = not on
	if on:
		dispatch_button.remove_theme_stylebox_override(&"disabled")
		dispatch_button.remove_theme_color_override(&"font_disabled_color")
		return
	dispatch_button.add_theme_stylebox_override(&"disabled", _box(DEAD_FILL))
	dispatch_button.add_theme_color_override(&"font_disabled_color", DEAD_INK)


#A clean form has nothing to clear, so Clear sits dim and inert until the first change lands.
func set_dirty(on: bool) -> void:
	if not is_node_ready():
		return
	clear_button.disabled = not on
	clear_button.modulate.a = 1.0 if on else CLEAR_DIM


func hint_text() -> String:
	return hint_label.text if is_node_ready() else ""


func odds_text() -> String:
	return odds_label.text if is_node_ready() else ""


func _style_clear() -> void:
	var box: StyleBoxFlat = _box(CLEAR_FILL)
	clear_button.add_theme_stylebox_override(&"normal", box)
	clear_button.add_theme_stylebox_override(&"hover", box)
	clear_button.add_theme_stylebox_override(&"pressed", box)
	clear_button.add_theme_stylebox_override(&"disabled", box)
	clear_button.add_theme_color_override(&"font_color", CLEAR_INK)
	clear_button.add_theme_color_override(&"font_hover_color", CLEAR_INK)
	clear_button.add_theme_color_override(&"font_pressed_color", CLEAR_INK)
	clear_button.add_theme_color_override(&"font_disabled_color", CLEAR_INK)


func _box(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = EDGE
	style.border_width_left = EDGE_PX
	style.border_width_top = EDGE_PX
	style.border_width_right = EDGE_PX
	style.border_width_bottom = EDGE_PX
	style.content_margin_left = PAD_X
	style.content_margin_right = PAD_X
	style.content_margin_top = PAD_Y
	style.content_margin_bottom = PAD_Y
	return style
