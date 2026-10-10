class_name SortDirToggle extends BevelButton

#The shared sort direction button (README I6): two stacked arrows, the live one lit and the other
#dim. Descending wears the orange fill, ascending the blue one, and each direction names itself in
#the tooltip. BaseButton already owns the name toggled, so the flip signal is direction_changed.

signal direction_changed(descending: bool)

const TOGGLE_SIZE: Vector2 = Vector2(40, 26)
#The stacked carets: 5x3 art px each at ARROW_SCALE, TRI_GAP screen px apart.
const ARROW_SCALE: int = 2
const TRI_GAP: float = 4.0
#One row per direction: the fill, its bevel pair, the lit and dim arrow colours and the tooltip.
const LOOKS: Dictionary = {
	true: {"fill": GuiColors.ORANGE, "hi": GuiColors.ORANGE_HI, "lo": GuiColors.ORANGE_LO,
		"lit": GuiColors.INK, "dim": Color("#7a4a1a"), "tip": "Highest to lowest"},
	false: {"fill": GuiColors.BLUE, "hi": GuiColors.BLUE_HI, "lo": GuiColors.BLUE_LO,
		"lit": GuiColors.CREAM, "dim": GuiColors.MUTED, "tip": "Lowest to highest"},
}

@export var descending: bool = true:
	set(value):
		descending = value
		_refresh()


func _init() -> void:
	kind = &"neutral"
	click_move = ButtonFx.ClickMove.ROCK
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	custom_minimum_size = TOGGLE_SIZE
	pressed.connect(toggle)
	_refresh()


func toggle() -> void:
	descending = not descending
	direction_changed.emit(descending)


#The colour row the current direction draws with.
func look() -> Dictionary:
	return LOOKS[descending] as Dictionary


func fill_color() -> Color:
	return look()["fill"] as Color


func _draw_face(rect: Rect2) -> void:
	var row: Dictionary = look()
	var art: Vector2 = Vector2(Icons.size("caret_up")) * float(ARROW_SCALE)
	var span: float = art.y * 2.0 + TRI_GAP
	var left: float = rect.position.x + roundf((rect.size.x - art.x) / 2.0)
	var top: float = rect.position.y + roundf((rect.size.y - span) / 2.0)
	var lit: Color = _fx.label(row["lit"] as Color)
	var dim: Color = _fx.label(row["dim"] as Color)
	Icons.draw(self, "caret_up", Vector2(left, top), ARROW_SCALE, dim if descending else lit, true)
	Icons.draw(self, "caret_down", Vector2(left, top + art.y + TRI_GAP), ARROW_SCALE,
		lit if descending else dim, true)


#The direction palette goes to the bevel body.
func _refresh() -> void:
	if not is_node_ready():
		return
	var row: Dictionary = look()
	set_colors(row["fill"] as Color, row["hi"] as Color, row["lo"] as Color, row["lit"] as Color)
	tooltip_text = String(row["tip"])
	queue_redraw()
