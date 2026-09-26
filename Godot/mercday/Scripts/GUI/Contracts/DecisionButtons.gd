class_name DecisionButtons extends HBoxContainer

#The posting's action row: take it, turn it down, or call back a team that has not left yet.

signal accepted
signal rejected
signal cancel_requested

const ACCEPT_FILL: Color = Color("#6cc36a")
const REJECT_FILL: Color = Color("#e8583f")
const CANCEL_FILL: Color = Color("#5e7699")
const GLYPH_COLOR: Color = Color("#ffffff")
const EDGE: Color = Color("#0a0f1c")
const EDGE_PX: int = 3
const PAD_H: float = 14.0
const PAD_V: float = 10.0
const GLYPH_SCALE: int = 2
const HI_LIGHTEN: float = 0.3
const LO_DARKEN: float = 0.35
const HOVER_LIGHTEN: float = 0.15
const PRESSED_DARKEN: float = 0.2

@onready var accept_button: Button = $Accept
@onready var reject_button: Button = $Reject
@onready var cancel_button: Button = $CancelDispatch


func _ready() -> void:
	_style(accept_button, ACCEPT_FILL)
	_style(reject_button, REJECT_FILL)
	_style(cancel_button, CANCEL_FILL)
	accept_button.icon = _scaled_glyph(GuiGlyphs.check(GLYPH_COLOR))
	reject_button.icon = _scaled_glyph(GuiGlyphs.cross(GLYPH_COLOR))
	accept_button.pressed.connect(func() -> void: accepted.emit())
	reject_button.pressed.connect(func() -> void: rejected.emit())
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())


func set_state(status: int, queued: bool) -> void:
	if not is_node_ready():
		return
	var open: bool = status == GuiTypes.ContractStatus.AVAILABLE
	accept_button.visible = open and not queued
	reject_button.visible = open and not queued
	cancel_button.visible = queued


#The face colour drives the states and the bevel rects, so each button reads as its own verb.
func _style(button: Button, fill: Color) -> void:
	button.add_theme_stylebox_override("normal", _box(fill))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(HOVER_LIGHTEN)))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(PRESSED_DARKEN)))
	button.add_theme_stylebox_override("disabled", _box(fill.darkened(PRESSED_DARKEN)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var hi: ColorRect = button.get_node_or_null("Hi") as ColorRect
	if hi != null:
		hi.color = fill.lightened(HI_LIGHTEN)
	var lo: ColorRect = button.get_node_or_null("Lo") as ColorRect
	if lo != null:
		lo.color = fill.darkened(LO_DARKEN)


static func _box(fill: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_width_left = EDGE_PX
	box.border_width_top = EDGE_PX
	box.border_width_right = EDGE_PX
	box.border_width_bottom = EDGE_PX
	box.border_color = EDGE
	box.content_margin_left = PAD_H
	box.content_margin_top = PAD_V
	box.content_margin_right = PAD_H
	box.content_margin_bottom = PAD_V
	return box


#The runtime glyphs are 10 px; nearest-neighbour doubling keeps the pixel edges crisp next to
#the 18 px label.
static func _scaled_glyph(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var copy: Image = img.duplicate() as Image
	copy.resize(copy.get_width() * GLYPH_SCALE, copy.get_height() * GLYPH_SCALE,
		Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(copy)
