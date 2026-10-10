class_name InvestValueCard extends PanelContainer

#One value card of the Invest right column: the title, the value in notes, the gain line and the
#dividends line. The Position and the Portfolio scripts extend it and fill it from their own data.

const VALUE_SIZE: int = 16
const PAD_Y: int = 2

@export var show_gain: bool = true:
	set(v):
		show_gain = v
		_apply()
@export var padded: bool = true:
	set(v):
		padded = v
		_apply()

@onready var pad: MarginContainer = $Pad
@onready var title_label: Label = $Pad/Col/TitleLabel
@onready var value_notes: NotesLabel = $Pad/Col/ValueNotes
@onready var gain_label: Label = $Pad/Col/GainLabel
@onready var dividends_label: Label = $Pad/Col/DividendsLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_apply()


#padded holds the column 2 px off the top and the bottom of the card.
func _apply() -> void:
	if not is_node_ready():
		return
	gain_label.visible = show_gain
	var inset: int = PAD_Y if padded else 0
	pad.add_theme_constant_override(&"margin_top", inset)
	pad.add_theme_constant_override(&"margin_bottom", inset)
