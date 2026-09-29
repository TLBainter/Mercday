class_name LoanStyle

#The palette, fonts and small node builders the Loans page screens share, so every card, cell
#and dialog reads the same colours without a theme resource of its own.

const BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const REGULAR: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const PIXEL: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const NOTES_SCENE: String = "res://Scenes/GUI/Shared/NotesLabel.tscn"

const INK: Color = Color("#0a0f1c")
const NAVY: Color = Color("#0e1628")
const NAVY2: Color = Color("#15223d")
const PANEL: Color = Color("#1a2b4d")
const BLUE: Color = Color("#1f3560")
const BLUE2: Color = Color("#2b4f8a")
const BLUE3: Color = Color("#3b6fb6")
const BEVEL_HI: Color = Color("#28447a")
const BEVEL_LO: Color = Color("#111c33")
const ORANGE: Color = Color("#f28c28")
const ORANGE_HI: Color = Color("#ffb266")
const ORANGE_LO: Color = Color("#b85a12")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#5e7699")
const GREEN: Color = Color("#6cc36a")
const GREEN_HI: Color = Color("#9be29a")
const RED: Color = Color("#e8583f")
const RED_X: Color = Color("#ff3b2f")
const YELLOW: Color = Color("#f2b33d")
const DIM_TEXT: Color = Color("#8a97ad")
const BACKDROP: Color = Color(0.0235, 0.0392, 0.0784, 0.72)
const CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)


static func flat(bg: Color, border_px: int = 0, border: Color = CLEAR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	if border_px > 0:
		style.border_color = border
		style.set_border_width_all(border_px)
	return style


static func padded(bg: Color, left: int, top: int, right: int, bottom: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = flat(bg)
	style.content_margin_left = float(left)
	style.content_margin_top = float(top)
	style.content_margin_right = float(right)
	style.content_margin_bottom = float(bottom)
	return style


static func panel(bg: Color, pad_h: int, pad_v: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", padded(bg, pad_h, pad_v, pad_h, pad_v))
	return box


static func text(value: String, size: int, color: Color, bold: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_override("font", BOLD if bold else REGULAR)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


#A body line in the Pixelify face, for the sentences that are not pixel captions.
static func body(value: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_override("font", PIXEL)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


#Every page button is the core BevelButton scene, shaded from the colour the caller asks for.
static func button(value: String, bg: Color, fg: Color, height: float) -> Button:
	var node: BevelButton = BevelButton.make(value, &"blue", Vector2(0.0, height))
	node.set_colors(bg, bg.lightened(0.25), bg.darkened(0.35), fg)
	node.add_theme_font_override("font", BOLD)
	node.add_theme_font_size_override("font_size", 13)
	return node


static func vbox(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


#An amount with the notes glyph; the caller adds it to the tree.
static func notes(amount: int, color: Color, size: int, glyph: bool = true) -> NotesLabel:
	var scene: PackedScene = load(NOTES_SCENE) as PackedScene
	var node: NotesLabel = scene.instantiate() as NotesLabel
	node.amount = amount
	node.value_color = color
	node.font_size = size
	node.show_glyph = glyph
	return node


#One stat cell of a card or a dialog: a small caption over a value node.
static func stat_cell(caption: String, value: Control, bg: Color = NAVY2) -> PanelContainer:
	var box: PanelContainer = panel(bg, 10, 8)
	var col: VBoxContainer = vbox(2)
	col.add_child(text(caption, 8, SKY))
	col.add_child(value)
	box.add_child(col)
	return box


#The 4 px ring and inner padding of a modal window.
static func window_style(ring: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = padded(PANEL, 22, 18, 22, 20)
	style.border_color = ring
	style.set_border_width_all(4)
	return style


static func dim_backdrop() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = BACKDROP
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect
