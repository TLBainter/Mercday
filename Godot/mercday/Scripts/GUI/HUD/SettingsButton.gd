class_name SettingsButton extends BevelButton

#Cosmetic toggle only: the shared face of the bell, mail and settings buttons; subclasses add
#their state. The gear swaps between cream and ink with the toggle. No settings menu yet.

const BG_IDLE: Color = GuiColors.BLUE
const BG_OPEN: Color = GuiColors.ORANGE
const BEVEL_HI_IDLE: Color = GuiColors.BLUE_HI
const BEVEL_LO_IDLE: Color = GuiColors.EDGE_LO
const BEVEL_HI_OPEN: Color = GuiColors.ORANGE_HI
const BEVEL_LO_OPEN: Color = GuiColors.ORANGE_LO
const OUTLINE_COLOR: Color = GuiColors.INK
const OUTLINE_WIDTH: float = 4.0
const BEVEL_WIDTH: float = 4.0
const GLYPH_IDLE: Color = GuiColors.CREAM
const GLYPH_OPEN: Color = GuiColors.INK
const GLYPH_SCALE: int = 2
const DOT_OFFSET: Vector2 = Vector2(2, 2)
const GLYPH_ON: Color = GLYPH_OPEN
const TOOLTIP: String = "Settings (not yet available)"

@onready var icon_rect: IconRect = $Icon


func _init() -> void:
	set_colors(BG_IDLE, BEVEL_HI_IDLE, BEVEL_LO_IDLE, GLYPH_IDLE)
	active_kind = &"orange"
	edge = BEVEL_WIDTH
	click_move = ButtonFx.ClickMove.ROCK
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.TILT
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	tooltip_text = TOOLTIP
	toggled.connect(_on_toggled)
	_on_toggled(button_pressed)


func _on_toggled(on: bool) -> void:
	icon_rect.tint = GLYPH_ON if on else GLYPH_IDLE
	queue_redraw()


#The ink outline of the button, just outside it.
func _draw_face(rect: Rect2) -> void:
	draw_rect(rect.grow(OUTLINE_WIDTH / 2.0), OUTLINE_COLOR, false, OUTLINE_WIDTH)
