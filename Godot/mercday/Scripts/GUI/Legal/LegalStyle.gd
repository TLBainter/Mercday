class_name LegalStyle

#The palette, the two pixel fonts and the small builders every Legal screen shares. The body font
#is the theme default (Pixelify 14 cream); text() only changes its size and colour, while pixel()
#swaps in Silkscreen for the prototype's small caps rows.

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
const GREEN_FILL: Color = Color("#3f9a4a")
const GREEN_EDGE: Color = Color("#2a6b32")
const RED: Color = Color("#e8583f")
const YELLOW: Color = Color("#f2d33d")
const AMBER: Color = Color("#f2b33d")
const PORTRAIT_HATCH: Color = Color("#5e6b82")

const FONT_PIXEL: FontVariation = preload(
	"res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_PIXEL_BOLD: FontVariation = preload(
	"res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")

const STYLE_DIR: String = "res://Resources/GUI/Theme/Styles/"
const EDGE_PX: float = 4.0
const NOTES_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/NotesLabel.tscn")
#The dim every Legal modal lays over the page behind it.
const BACKDROP: Color = Color(0.023529, 0.039216, 0.078431, 0.72)


#A body row in the theme's default Pixelify face.
static func text(body: String, size: int, color: Color) -> Label:
	var out := Label.new()
	out.text = body
	out.add_theme_font_size_override(&"font_size", size)
	out.add_theme_color_override(&"font_color", color)
	return out


#A small caps row in Silkscreen, the face the prototype uses for heads, names and numbers.
static func pixel(body: String, size: int, color: Color, bold: bool = false) -> Label:
	var out := Label.new()
	out.text = body
	out.add_theme_font_override(&"font", FONT_PIXEL_BOLD if bold else FONT_PIXEL)
	out.add_theme_font_size_override(&"font_size", size)
	out.add_theme_color_override(&"font_color", color)
	return out


#The orange section head over a block of rows.
static func head(body: String, size: int = 9) -> Label:
	return pixel(body, size, ORANGE)


static func button(body: String, variation: StringName, height: int,
		font_size: int = 11) -> Button:
	var out: BevelButton = BevelButton.make(body, _kind_of(variation), Vector2(0.0, float(height)))
	out.add_theme_font_size_override(&"font_size", font_size)
	out.focus_mode = Control.FOCUS_NONE
	return out


#The LegalStyle.button variation name mapped to the BevelButton palette it shades with.
static func _kind_of(variation: StringName) -> StringName:
	match variation:
		&"ButtonGo":
			return &"go"
		&"ButtonDanger":
			return &"danger"
		&"ButtonOrange":
			return &"orange"
		&"ButtonNeutral":
			return &"neutral"
	return &"blue"


#A copy of one of the theme's style resources, safe to retint per instance.
static func styled(file_name: String) -> StyleBoxFlat:
	var found: StyleBoxFlat = load(STYLE_DIR + file_name) as StyleBoxFlat
	if found == null:
		return StyleBoxFlat.new()
	return found.duplicate() as StyleBoxFlat


static func card_style(ring: Color) -> StyleBoxFlat:
	var out: StyleBoxFlat = styled("legal_card.tres")
	out.border_color = ring
	return out


static func row_style(ring: Color) -> StyleBoxFlat:
	var out: StyleBoxFlat = styled("legal_row.tres")
	out.border_color = ring
	return out


static func box_style(bg: Color, ring: Color, ring_px: int, pad: int) -> StyleBoxFlat:
	var out := StyleBoxFlat.new()
	out.bg_color = bg
	out.set_border_width_all(ring_px)
	out.border_color = ring
	out.content_margin_left = float(pad)
	out.content_margin_right = float(pad)
	out.content_margin_top = float(pad)
	out.content_margin_bottom = float(pad)
	return out


#The ink cell the fact rows and the progress rows sit on.
static func cell(bg: Color = INK) -> PanelContainer:
	var out := PanelContainer.new()
	var style: StyleBoxFlat = styled("legal_cell.tres")
	style.bg_color = bg
	out.add_theme_stylebox_override(&"panel", style)
	return out


static func divider(color: Color = BLUE, px: int = 2) -> ColorRect:
	var out := ColorRect.new()
	out.name = "Divider"
	out.color = color
	out.custom_minimum_size = Vector2(0.0, float(px))
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


static func spacer() -> Control:
	var out := Control.new()
	out.name = "Spacer"
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return out


static func vbox(separation: int) -> VBoxContainer:
	var out := VBoxContainer.new()
	out.add_theme_constant_override(&"separation", separation)
	return out


static func hbox(separation: int) -> HBoxContainer:
	var out := HBoxContainer.new()
	out.add_theme_constant_override(&"separation", separation)
	return out


#The hatched placeholder box the icon and portrait cells use until real art lands.
static func hatch_box(span: Vector2, ring: Color, fill: Color = PORTRAIT_HATCH,
		back: Color = NAVY2) -> PanelContainer:
	var out := PanelContainer.new()
	out.name = "Hatch"
	out.custom_minimum_size = span
	out.add_theme_stylebox_override(&"panel", box_style(back, ring, 2, 0))
	out.clip_contents = true
	out.add_child(LegalGlyphs.hatch_rect(fill, back))
	return out


#A TextureRect sized to its art, used for the permission marks and the tab arrows.
static func icon(tex: Texture2D, span: Vector2) -> TextureRect:
	var out := TextureRect.new()
	out.name = "Mark"
	out.texture = tex
	out.custom_minimum_size = span
	out.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


#The raised or sunken 4 px bevels every Legal dialog draws over its own edges.
static func draw_edges(on: Control, hi: Color = BEVEL_HI, lo: Color = BEVEL_LO) -> void:
	var span: Vector2 = on.size
	on.draw_rect(Rect2(0.0, 0.0, span.x, EDGE_PX), hi)
	on.draw_rect(Rect2(0.0, 0.0, EDGE_PX, span.y), hi)
	on.draw_rect(Rect2(0.0, span.y - EDGE_PX, span.x, EDGE_PX), lo)
	on.draw_rect(Rect2(span.x - EDGE_PX, 0.0, EDGE_PX, span.y), lo)


#The roster view behind one uid, or null when that merc is not on the roster any more.
static func merc_view(uid: int) -> MercView:
	for view: MercView in GameState.roster:
		if view.uid == uid:
			return view
	return null


static func merc_name(uid: int) -> String:
	var view: MercView = merc_view(uid)
	return view.name if view != null else "Merc %d" % uid


#A notes figure with the pixel note glyph after it.
static func notes(value: int, size: int, color: Color, bold: bool = true) -> NotesLabel:
	var out: NotesLabel = NOTES_SCENE.instantiate() as NotesLabel
	out.amount = value
	out.font_size = size
	out.value_color = color
	out.bold = bold
	return out


static func dialog_style() -> StyleBoxFlat:
	return styled("legal_dialog.tres")


static func page_style() -> StyleBoxFlat:
	return styled("legal_page.tres")


#The dimmed sheet under a modal; it swallows the clicks meant for the page behind it.
static func backdrop() -> ColorRect:
	var out := ColorRect.new()
	out.name = "Backdrop"
	out.color = BACKDROP
	out.set_anchors_preset(Control.PRESET_FULL_RECT)
	out.mouse_filter = Control.MOUSE_FILTER_STOP
	return out


#A fixed width column label for the head line over a list.
static func column(body: String, width: int) -> Label:
	var out: Label = pixel(body, 9, MUTED)
	out.custom_minimum_size = Vector2(float(width), 0.0)
	out.clip_text = true
	return out


#The printed name of one location, or Legal when that id is not on the map.
static func location_name(loc_id: int) -> String:
	var place: LegalLocationData = LegalManager.location(loc_id)
	return place.name if place != null else "Legal"
