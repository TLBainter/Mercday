class_name DecisionButtons extends HBoxContainer

#The posting's action row: take it, turn it down, or call back a team that has not left yet.
#README A2 pins the three faces, their bevels and the hover and pressed shades in PALETTES.
#Accept, Reject and CancelDispatch are the shared BevelButton scene; the Face, Glyph and Text
#children still overlay it unchanged, painted after its own bevel body.

signal accepted
signal rejected
signal cancel_requested

const ACCEPT: int = 0
const REJECT: int = 1
const CANCEL: int = 2
const ACCEPT_FILL: Color = Color("#3f9a4a")
const REJECT_FILL: Color = Color("#b8402e")
const CANCEL_FILL: Color = Color("#5e7699")
const GLYPH_COLOR: Color = Color("#f3ead7")
const LABEL_COLOR: Color = Color("#f3ead7")
const SHADOW_COLOR: Color = Color("#0a0f1c")
const SHADOW_PX: int = 2
const EDGE_PX: int = 3
const GLYPH_SCALE: int = 2
#The gap between the glyph and the text on the face (PROTO gap 14).
const FACE_GAP: int = 14
const FACE_NODE: String = "Face"
const GLYPH_NODE: String = "Face/Glyph"
const TEXT_NODE: String = "Face/Text"
#One row per verb: the face, its bevel pair and the hover and pressed faces. The Cancel row keeps
#the shades the muted fill carried before the design named the Accept and Reject ones.
const PALETTES: Array[Dictionary] = [
	{"fill": ACCEPT_FILL, "hi": Color("#6cc36a"), "lo": Color("#2a6b32"),
		"hover": Color("#4fb05a"), "pressed": Color("#2a6b32")},
	{"fill": REJECT_FILL, "hi": Color("#e8583f"), "lo": Color("#7a2a1e"),
		"hover": Color("#cc4a36"), "pressed": Color("#7a2a1e")},
	{"fill": CANCEL_FILL, "hi": Color("#8e9fb8"), "lo": Color("#3d4c63"),
		"hover": Color("#768aa8"), "pressed": Color("#4b5e7a")},
]

@onready var accept_button: BevelButton = $Accept
@onready var reject_button: BevelButton = $Reject
@onready var cancel_button: BevelButton = $CancelDispatch


func _ready() -> void:
	_style(accept_button, PALETTES[ACCEPT])
	_style(reject_button, PALETTES[REJECT])
	_style(cancel_button, PALETTES[CANCEL])
	_set_glyph(accept_button, GuiGlyphs.check(GLYPH_COLOR))
	_set_glyph(reject_button, GuiGlyphs.cross(GLYPH_COLOR))
	_set_glyph(cancel_button, null)
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


#The label a button draws its verb with; Button owns no shadow item, so a Label child carries it.
func label_of(button: Button) -> Label:
	return button.get_node_or_null(TEXT_NODE) as Label


#The palette row drives the BevelButton colours and the face labels, so each button reads as
#its own verb. The bevel band is BevelButton's own edge paint, at the same 3 px width as before.
func _style(button: BevelButton, palette: Dictionary) -> void:
	button.set_colors(palette["fill"] as Color, palette["hi"] as Color, palette["lo"] as Color,
		LABEL_COLOR)
	button.hover_fill = palette["hover"] as Color
	button.pressed_fill = palette["pressed"] as Color
	button.edge = float(EDGE_PX)
	var face: HBoxContainer = button.get_node_or_null(FACE_NODE) as HBoxContainer
	if face != null:
		face.add_theme_constant_override("separation", FACE_GAP)
	var text: Label = label_of(button)
	if text != null:
		text.add_theme_color_override("font_color", LABEL_COLOR)
		text.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
		text.add_theme_constant_override("shadow_offset_x", SHADOW_PX)
		text.add_theme_constant_override("shadow_offset_y", SHADOW_PX)


#The glyph wears the same 2 px drop as the text, so the two read as one line (PROTO 338 to 348).
func _set_glyph(button: Button, tex: Texture2D) -> void:
	var glyph: TextureRect = button.get_node_or_null(GLYPH_NODE) as TextureRect
	if glyph == null:
		return
	glyph.texture = _shadowed_glyph(tex)
	glyph.visible = glyph.texture != null


#The drop is baked into the image: the glyph in the shadow colour at 2,2 under the cream at 0,0.
static func _shadowed_glyph(tex: Texture2D) -> Texture2D:
	var scaled: Texture2D = _scaled_glyph(tex)
	if scaled == null:
		return null
	var src: Image = scaled.get_image()
	if src == null:
		return scaled
	var out: Image = Image.create_empty(src.get_width() + SHADOW_PX,
		src.get_height() + SHADOW_PX, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in src.get_height():
		for x: int in src.get_width():
			if src.get_pixel(x, y).a < 0.5:
				continue
			out.set_pixel(x + SHADOW_PX, y + SHADOW_PX, SHADOW_COLOR)
	for y: int in src.get_height():
		for x: int in src.get_width():
			if src.get_pixel(x, y).a < 0.5:
				continue
			out.set_pixel(x, y, GLYPH_COLOR)
	return ImageTexture.create_from_image(out)


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
