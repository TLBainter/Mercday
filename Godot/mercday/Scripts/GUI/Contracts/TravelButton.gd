class_name TravelButton extends Button

#One travel mode on one leg: a full width tile with the mode name on it. A leg the bank cannot
#cover greys out and refuses the press; the hovered tile explains itself through the travel tip.

signal mode_picked(key: String)

const OVER_BUDGET_FILL: Color = Color("#27324a")
const CREAM: Color = Color("#f3ead7")
const DIM_ALPHA: float = 0.45

@onready var label_node: Label = $Rows/Label

var mode: Dictionary = {}
var cost: int = 0
var hours: float = 0.0
var affordable: bool = true
var picked: bool = false


func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh()


func configure(new_mode: Dictionary, new_cost: int, new_hours: float,
		new_affordable: bool) -> void:
	mode = new_mode
	cost = new_cost
	hours = new_hours
	affordable = new_affordable
	_refresh()


func set_picked(on: bool) -> void:
	picked = on
	_refresh()


func mode_key() -> String:
	return str(mode.get("key", ""))


func mode_label() -> String:
	return str(mode.get("label", ""))


func cost_value() -> int:
	return cost


func hours_value() -> float:
	return hours


func minutes_value() -> int:
	return roundi(hours * 60.0)


func is_affordable() -> bool:
	return affordable


func _on_pressed() -> void:
	if picked:
		return
	mode_picked.emit(mode_key())


func _refresh() -> void:
	if not is_node_ready() or mode.is_empty():
		return
	label_node.text = str(mode.get("label", ""))
	theme_type_variation = &"ButtonOrange" if picked else &"ButtonNeutral"
	disabled = not affordable
	tooltip_text = ""
	if affordable:
		remove_theme_stylebox_override(&"disabled")
		remove_theme_color_override(&"font_disabled_color")
		label_node.remove_theme_color_override(&"font_color")
		return
	var style := StyleBoxFlat.new()
	style.bg_color = OVER_BUDGET_FILL
	add_theme_stylebox_override(&"disabled", style)
	var dim: Color = Color(CREAM, DIM_ALPHA)
	add_theme_color_override(&"font_disabled_color", dim)
	label_node.add_theme_color_override(&"font_color", dim)
