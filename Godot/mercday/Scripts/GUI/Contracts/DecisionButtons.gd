class_name DecisionButtons extends HBoxContainer

#The posting's action row: take it, turn it down, or call back a team that has not left yet.
#README A2 pins the three faces, their bevels and the hover and pressed shades in PALETTES.
#Accept, Reject and CancelDispatch are the shared BevelButton scene; each carries a DecisionFace
#(Glyph and Text) that overlays it unchanged, painted after its own bevel body.
#The row reads Reject, Accept, then CancelDispatch, with the positive verb on the right.

signal accepted
signal rejected
signal cancel_requested

const ACCEPT: int = 0
const REJECT: int = 1
const CANCEL: int = 2
const ACCEPT_FILL: Color = GuiColors.GO_FILL
const REJECT_FILL: Color = GuiColors.DANGER_FILL
const CANCEL_FILL: Color = GuiColors.MUTED
const GLYPH_FILL: Color = Color.WHITE
const LABEL_COLOR: Color = GuiColors.CREAM
const SHADOW_COLOR: Color = GuiColors.INK
const SHADOW_PX: int = 2
const EDGE_PX: int = 3
const GLYPH_SCALE: int = 3
#The gap between the glyph and the text on the face (PROTO gap 14).
const FACE_GAP: int = 14
const FACE_NODE: String = "Face"
const GLYPH_NODE: String = "Face/Glyph"
const TEXT_NODE: String = "Face/Text"
#One row per verb: the face, its bevel pair and the hover and pressed faces. The Cancel row keeps
#the shades the muted fill carried before the design named the Accept and Reject ones.
const PALETTES: Array[Dictionary] = [
	{"fill": ACCEPT_FILL, "hi": GuiColors.GREEN, "lo": GuiColors.GO_LO,
		"hover": Color("#4fb05a"), "pressed": GuiColors.GO_LO},
	{"fill": REJECT_FILL, "hi": GuiColors.RED, "lo": GuiColors.DANGER_LO,
		"hover": Color("#cc4a36"), "pressed": GuiColors.DANGER_LO},
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
	_set_glyph(accept_button, Icons.solid_outlined("check_lg", GLYPH_FILL, SHADOW_COLOR,
		GLYPH_SCALE, true))
	_set_glyph(reject_button, Icons.solid_outlined("x_lg", GLYPH_FILL, SHADOW_COLOR,
		GLYPH_SCALE, true))
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


#The label a button draws its verb with, flat and without a text shadow.
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


#The atlas glyph arrives already solid and ringed, so the face only hangs it on the rect.
func _set_glyph(button: Button, tex: Texture2D) -> void:
	var glyph: TextureRect = button.get_node_or_null(GLYPH_NODE) as TextureRect
	if glyph == null:
		return
	glyph.texture = tex
	glyph.visible = glyph.texture != null

