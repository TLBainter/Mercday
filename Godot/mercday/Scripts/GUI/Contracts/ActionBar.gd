class_name ActionBar extends PanelContainer

#The dispatch window's bottom bar: the odds block on the left, the three small actions beside it and
#the Dispatch tile on the right. The window owns the rules; the bar only reports the presses.
#Optimize, Clear, Cancel and Dispatch are the shared BevelButton scene; Clear keeps its own grey
#through set_colors since it has no dedicated kind, and disabled now dims through BevelButton
#itself instead of a stylebox swap.

signal optimize_pressed
signal clear_pressed
signal cancel_pressed
signal dispatch_pressed

const CLEAR_FILL: Color = Color("#6b7488")
const CLEAR_INK: Color = GuiColors.CREAM
const CLEAR_DIM: float = 0.4

@onready var odds_label: Label = $Pad/Row/Odds/Head/OddsLabel
@onready var meter: SuccessMeter = $Pad/Row/Odds/Meter
@onready var hint_label: Label = $Pad/Row/Odds/Hint
@onready var optimize_button: BevelButton = $Pad/Row/Buttons/Optimize
@onready var clear_button: BevelButton = $Pad/Row/Buttons/Clear
@onready var cancel_button: BevelButton = $Pad/Row/Buttons/Cancel
@onready var dispatch_button: BevelButton = $Pad/Row/Dispatch


func _ready() -> void:
	optimize_button.pressed.connect(func() -> void: optimize_pressed.emit())
	clear_button.pressed.connect(func() -> void: clear_pressed.emit())
	cancel_button.pressed.connect(func() -> void: cancel_pressed.emit())
	dispatch_button.pressed.connect(func() -> void: dispatch_pressed.emit())
	clear_button.set_colors(CLEAR_FILL, CLEAR_FILL.lightened(0.15), CLEAR_FILL.darkened(0.2),
		CLEAR_INK)
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
