class_name GuiStyle

#The GUI fonts plus the small stylebox and node builders every screen shares; a page kit keeps only
#the looks that are its own. Colours come from GuiColors.

const SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const SILK_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const BACKDROP_BOX: StyleBoxFlat = preload("res://Resources/GUI/Theme/BackdropDim.tres")
const NOTES_SCENE: String = "res://Scenes/GUI/Shared/NotesLabel.tscn"
#List rows: the edge width and the even content margin of every row box.
const ROW_EDGE_PX: int = 3
const ROW_MARGIN: float = 6.0
const BOX_STATES: Array[StringName] = [&"normal", &"hover", &"pressed", &"focus"]
const FONT_STATES: Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color",
	&"font_focus_color"]
#One lifted copy per face box, shared, so callers never edit it.
static var _lifted: Dictionary = {}


#A flat box with an even border; a negative margin leaves the content margins at the StyleBox default.
static func flat(bg: Color, border_px: int = 0, border: Color = GuiColors.CLEAR,
		margin: float = -1.0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(border_px)
	box.border_color = border
	if margin >= 0.0:
		box.set_content_margin_all(margin)
	return box


#A list row: the hover fill when hovered or selected, the high edge only when selected.
static func row_box(selected: bool, hovered: bool, fill: Color = GuiColors.ROW_FILL,
		hover_fill: Color = GuiColors.ROW_HOVER, edge_hi: Color = GuiColors.ORANGE,
		edge_lo: Color = GuiColors.ROW_EDGE_LO, edge_px: int = ROW_EDGE_PX,
		margin: float = ROW_MARGIN) -> StyleBoxFlat:
	var bg: Color = hover_fill if selected or hovered else fill
	return flat(bg, edge_px, edge_hi if selected else edge_lo, margin)


#A face under the pointer: the same box with its fill lifted the way a BevelButton lifts its own.
static func lifted(box: StyleBoxFlat) -> StyleBoxFlat:
	if not _lifted.has(box):
		var lift: StyleBoxFlat = box.duplicate() as StyleBoxFlat
		lift.bg_color = box.bg_color.lightened(BevelButton.HOVER_LIFT)
		_lifted[box] = lift
	return _lifted[box]


#The one dim laid behind every modal; shared, so callers never edit it.
static func backdrop() -> StyleBox:
	return BACKDROP_BOX


#Gives a themed panel its own copy of the theme panel box with an even content margin; -1 keeps the border width.
static func pad_panel(panel: Control, margin: float) -> void:
	var base: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	if base == null:
		return
	var padded: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	padded.set_content_margin_all(margin)
	panel.add_theme_stylebox_override(&"panel", padded)


static func label(text: String, font: Font, size: int, color: Color) -> Label:
	var made: Label = Label.new()
	made.text = text
	paint(made, font, size, color)
	return made


#Sets the font, size and colour overrides of a Label or a Button in one call.
static func paint(target: Control, font: Font, size: int, color: Color) -> void:
	target.add_theme_font_override("font", font)
	target.add_theme_font_size_override("font_size", size)
	target.add_theme_color_override("font_color", color)


static func vbox(separation: int) -> VBoxContainer:
	var made: VBoxContainer = VBoxContainer.new()
	made.add_theme_constant_override("separation", separation)
	return made


static func hbox(separation: int) -> HBoxContainer:
	var made: HBoxContainer = HBoxContainer.new()
	made.add_theme_constant_override("separation", separation)
	return made


#An empty Control that takes the free room of its box along one axis.
static func spacer(vertical: bool = false) -> Control:
	var made: Control = Control.new()
	made.name = "Spacer"
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


#A vertical-only scroll that fills its box.
static func scroll() -> ScrollContainer:
	var made: ScrollContainer = ScrollContainer.new()
	made.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	made.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


#An amount with the notes glyph; the caller adds it to the tree.
static func notes(amount: int, size: int, color: Color) -> NotesLabel:
	var scene: PackedScene = load(NOTES_SCENE) as PackedScene
	var made: NotesLabel = scene.instantiate() as NotesLabel
	made.amount = amount
	made.font_size = size
	made.value_color = color
	return made


#One stat cell of a card or a dialog: a small caption over a value node.
static func stat_cell(caption: String, value: Control, bg: Color = GuiColors.ROW_HOVER) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = flat(bg)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	box.add_theme_stylebox_override("panel", style)
	var col: VBoxContainer = vbox(2)
	col.add_child(label(caption, SILK, 8, GuiColors.SKY))
	col.add_child(value)
	box.add_child(col)
	return box


#A bevelled BevelButton of one palette kind that never takes keyboard focus.
static func button(text: String, kind: StringName = &"blue", height: float = 0.0) -> BevelButton:
	var made: BevelButton = BevelButton.make(text, kind, Vector2(0.0, height))
	made.focus_mode = Control.FOCUS_NONE
	return made


#The theme button variation name mapped to the BevelButton palette it shades with.
static func kind_of(variation: StringName) -> StringName:
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


static func set_all_boxes(target: Control, box: StyleBox, states: Array[StringName] = BOX_STATES) -> void:
	for state: StringName in states:
		target.add_theme_stylebox_override(state, box)


static func set_all_font_colors(target: Control, color: Color, keys: Array[StringName] = FONT_STATES) -> void:
	for key: StringName in keys:
		target.add_theme_color_override(key, color)
