class_name ListRow extends BevelButton

#A selectable list row: the row fill inside a light upper and a dark lower band when idle, and the hover fill
#inside an orange frame while selected. A selected row is active, so the pointer rings it instead of lighting it.

const PICKED_EDGE: Color = GuiColors.ORANGE

@export var content_margin: float = GuiStyle.ROW_MARGIN:
	set(value):
		content_margin = value
		_apply_margin()
@export var selected: bool = false:
	set(value):
		if value == selected:
			return
		selected = value
		if selected:
			_idle = PackedColorArray([fill, hi, lo])
			set_colors(hover_color(), PICKED_EDGE, PICKED_EDGE, text_color)
		else:
			set_colors(_idle[0], _idle[1], _idle[2], text_color)

#The fill and the two bands the row wears while it is not selected.
var _idle: PackedColorArray = PackedColorArray()


func _init() -> void:
	fill = GuiColors.ROW_FILL
	hi = GuiColors.ROW_FILL.lightened(0.18)
	lo = GuiColors.ROW_EDGE_LO
	hover_fill = GuiColors.ROW_HOVER
	pressed_fill = GuiColors.ROW_HOVER
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
	_apply_margin()


func fx_active() -> bool:
	return super() or selected


#The base shares one empty box across every state, so this margin pads them all.
func _apply_margin() -> void:
	if is_node_ready():
		get_theme_stylebox(&"normal").set_content_margin_all(content_margin)
