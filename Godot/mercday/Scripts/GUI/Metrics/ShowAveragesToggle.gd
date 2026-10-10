class_name ShowAveragesToggle extends BevelButton

#The header switch that lays the team average under every plotted merc metric. It locks with a
#reason when there is no merc to compare or when a second merc is already the comparison.

const BOX_FILL: Color = GuiColors.INK
const BOX_RING: Color = GuiColors.BLUE_HI
const CHECK_COLOR: Color = GuiColors.ORANGE
const FONT: FontVariation = GuiStyle.SILK
const FONT_SIZE := 10
const RING_WIDTH := 2.0
const CONTENT_LEFT := 30
const LOCKED_ALPHA := 0.4
const LABEL := "SHOW AVERAGES"
const TIP_NO_MERC := "Select a merc to compare with the team average."
const TIP_COMPARING := "Turn off Merc Comparison to show averages."

signal toggled_on(on: bool)

@onready var swatch: Control = $Swatch


func _init() -> void:
	kind = &"neutral"
	active_kind = &"neutral"
	click_move = ButtonFx.ClickMove.SHRINK
	click_shade = ButtonFx.ClickShade.FLASH
	hover_move = ButtonFx.HoverMove.NONE
	hover_shade = ButtonFx.HoverShade.LIGHTEN
	stay_move = ButtonFx.StayMove.NONE
	stay_shade = ButtonFx.StayShade.NONE
	active_move = ButtonFx.HoverMove.NONE
	active_shade = ButtonFx.HoverShade.RING


func _ready() -> void:
	super()
	text = LABEL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", FONT_SIZE)
	#Every state shares the base's empty box, so its left margin keeps the label clear of the swatch.
	get_theme_stylebox(&"normal").content_margin_left = float(CONTENT_LEFT)
	swatch.draw.connect(_draw_swatch)
	mouse_entered.connect(swatch.queue_redraw)
	mouse_exited.connect(swatch.queue_redraw)
	toggled.connect(_on_toggled)


func is_on() -> bool:
	return button_pressed


#Mirrors a state change made in code; the toggled_on signal never fires for it.
func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	if is_node_ready():
		swatch.queue_redraw()


#Greys the switch out and says why it cannot be used.
func set_locked(locked: bool, reason: String) -> void:
	disabled = locked
	swatch.modulate.a = LOCKED_ALPHA if locked else 1.0
	tooltip_text = reason


func _on_toggled(on: bool) -> void:
	swatch.queue_redraw()
	toggled_on.emit(on)


#The box lifts under the pointer the way a button face does.
func box_fill() -> Color:
	if is_hovered() and not disabled:
		return BOX_FILL.lightened(BevelButton.HOVER_LIFT)
	return BOX_FILL


func _draw_swatch() -> void:
	var rect := Rect2(Vector2.ZERO, swatch.size)
	swatch.draw_rect(rect, box_fill())
	swatch.draw_rect(rect, BOX_RING, false, RING_WIDTH)
	if not button_pressed:
		return
	var mark: Texture2D = GuiGlyphs.check(CHECK_COLOR)
	swatch.draw_texture(mark, ((rect.size - mark.get_size()) * 0.5).floor())
