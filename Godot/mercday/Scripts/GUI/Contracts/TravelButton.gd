class_name TravelButton extends BevelButton

#One travel mode on one leg: a full width tile with the mode name on it. A leg the bank cannot
#cover, or one the posting bars, greys out and refuses the press; the hovered tile explains itself
#through the travel tip.

signal mode_picked(key: String)

const DIM_ALPHA: float = 0.45

@onready var label_node: Label = $Rows/Label

var mode: Dictionary = {}
var cost: int = 0
var hours: float = 0.0
var affordable: bool = true
var picked: bool = false
#Why the tile is barred; empty when it is open.
var reason: String = ""


func _init() -> void:
	kind = &"neutral"
	active_kind = &"orange"
	click_move = ButtonFx.ClickMove.POP
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.LIFT
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)
	_refresh()


func configure(new_mode: Dictionary, new_cost: int, new_hours: float,
		new_affordable: bool, new_reason: String = "") -> void:
	mode = new_mode
	cost = new_cost
	hours = new_hours
	affordable = new_affordable
	reason = new_reason
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


func reason_text() -> String:
	return reason


func is_open() -> bool:
	return affordable and reason == ""


#A barred pick keeps the locked colours instead of the orange.
func fx_active() -> bool:
	return super() or (picked and is_open())


func _on_pressed() -> void:
	if picked:
		return
	mode_picked.emit(mode_key())


func _refresh() -> void:
	if not is_node_ready() or mode.is_empty():
		return
	label_node.text = str(mode.get("label", ""))
	disabled = not is_open()
	tooltip_text = reason
	if is_open():
		apply_palette(kind)
		label_node.remove_theme_color_override(&"font_color")
	else:
		var dim: Color = Color(GuiColors.CREAM, DIM_ALPHA)
		set_colors(GuiColors.LOCKED_BG, GuiColors.LOCKED_HI, GuiColors.LOCKED_LO, dim)
		label_node.add_theme_color_override(&"font_color", dim)
