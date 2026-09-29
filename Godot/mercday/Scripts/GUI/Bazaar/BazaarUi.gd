class_name BazaarUi extends RefCounted

#The shapes every Bazaar screen repeats: pixel labels, the bevelled buttons, the inset boxes and
#the atoms the kit already owns. Nothing here holds state; it reads BazaarManager.RARITIES only,
#for the rarity name and colour.

const FONT_SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_SILK_BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const NOTES_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/NotesLabel.tscn")
const CELL_BAR_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/CellBar.tscn")
const FEATURE_LOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FeatureLock.tscn")
const DROPDOWN_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/OptionDropdown.tscn")

const INK: Color = Color("#0a0f1c")
const NAVY: Color = Color("#0e1628")
const NAVY2: Color = Color("#15223d")
const PANEL: Color = Color("#1a2b4d")
const BLUE: Color = Color("#1f3560")
const BLUE2: Color = Color("#2b4f8a")
const BLUE3: Color = Color("#3b6fb6")
const ORANGE: Color = Color("#f28c28")
const ORANGE_HI: Color = Color("#ffb266")
const ORANGE_LO: Color = Color("#b85a12")
const CREAM: Color = Color("#f3ead7")
const SKY: Color = Color("#9cc6ef")
const MUTED: Color = Color("#5e7699")
const GREEN: Color = Color("#6cc36a")
const RED: Color = Color("#e8583f")
const DIM: float = 0.4


static func silk(body_text: String, font_size: int, tint: Color) -> Label:
	return _label(body_text, FONT_SILK, font_size, tint)


static func silk_bold(body_text: String, font_size: int, tint: Color) -> Label:
	return _label(body_text, FONT_SILK_BOLD, font_size, tint)


static func body(body_text: String, font_size: int, tint: Color) -> Label:
	return _label(body_text, FONT_BODY, font_size, tint)


#A section heading of the filter panel and of every card strip.
static func heading(body_text: String) -> Label:
	return silk(body_text, 11, ORANGE)


static func _label(body_text: String, font: FontVariation, font_size: int, tint: Color) -> Label:
	var made: Label = Label.new()
	made.text = body_text
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_font_override("font", font)
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", tint)
	return made


#A bevelled button of the theme: variation is ButtonOrange, ButtonGo, ButtonNeutral or ButtonDanger.
static func button(body_text: String, variation: StringName, height: float,
		font_size: int) -> Button:
	var made: BevelButton = BevelButton.make(body_text, _kind_of(variation), Vector2(0.0, height))
	made.focus_mode = Control.FOCUS_NONE
	made.add_theme_font_override("font", FONT_SILK)
	made.add_theme_font_size_override("font_size", font_size)
	return made


#The BazaarUi.button variation name mapped to the BevelButton palette it shades with.
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


#The underlined text buttons: Clear all filters and Remove.
static func link(body_text: String, tint: Color, font_size: int) -> Button:
	var made: Button = Button.new()
	made.text = body_text
	made.focus_mode = Control.FOCUS_NONE
	made.flat = true
	made.add_theme_font_override("font", FONT_SILK)
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", tint)
	made.add_theme_color_override("font_hover_color", CREAM)
	made.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	made.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	made.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	made.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return made


static func flat(fill: Color, border_px: int, border: Color, pad: float = 0.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = border_px
	style.border_width_top = border_px
	style.border_width_right = border_px
	style.border_width_bottom = border_px
	style.border_color = border
	style.content_margin_left = pad
	style.content_margin_top = pad
	style.content_margin_right = pad
	style.content_margin_bottom = pad
	return style


static func panel_box(fill: Color, border_px: int, border: Color, pad: float) -> PanelContainer:
	var made: PanelContainer = PanelContainer.new()
	made.add_theme_stylebox_override("panel", flat(fill, border_px, border, pad))
	return made


static func vbox(separation: int) -> VBoxContainer:
	var made: VBoxContainer = VBoxContainer.new()
	made.add_theme_constant_override("separation", separation)
	return made


static func hbox(separation: int) -> HBoxContainer:
	var made: HBoxContainer = HBoxContainer.new()
	made.add_theme_constant_override("separation", separation)
	return made


#The only scroll bars the Bazaar shows are vertical; the window itself never scrolls.
static func scroll() -> ScrollContainer:
	var made: ScrollContainer = ScrollContainer.new()
	made.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	made.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


static func notes(amount: int, font_size: int, tint: Color, glyph_scale: int = 2) -> NotesLabel:
	var made: NotesLabel = NOTES_SCENE.instantiate() as NotesLabel
	made.amount = amount
	made.font_size = font_size
	made.value_color = tint
	made.glyph_scale = glyph_scale
	return made


static func cell_bar(cells: int, height: int, gap: int) -> CellBar:
	var made: CellBar = CELL_BAR_SCENE.instantiate() as CellBar
	made.cells = cells
	made.cell_height = height
	made.gap = gap
	return made


static func dropdown() -> OptionDropdown:
	return DROPDOWN_SCENE.instantiate() as OptionDropdown


#A greyed locked control that opens the FeatureLock dialog; the caller adds it to its own row.
static func feature_lock(body_text: String, upgrade: String, upgrade_id: String, tier: int,
		tiers: int, height: float) -> FeatureLock:
	var made: FeatureLock = FEATURE_LOCK_SCENE.instantiate() as FeatureLock
	made.plan = "Mercday Enterprise"
	made.verb = "use"
	made.feature = body_text
	made.label = body_text
	made.upgrade = upgrade
	made.upgrade_id = upgrade_id
	made.tier = tier
	made.tiers = tiers
	made.height = height
	made.always_visible = true
	return made


static func rarity_name(rarity: int) -> String:
	var rows: Array[Dictionary] = BazaarManager.RARITIES
	return str(rows[clampi(rarity, 0, rows.size() - 1)]["name"])


static func rarity_color(rarity: int) -> Color:
	var rows: Array[Dictionary] = BazaarManager.RARITIES
	return Color(str(rows[clampi(rarity, 0, rows.size() - 1)]["color"]))


#"Arrives 4 Daith 301 (2-Day)" for the shop and cart lines; days come from the manager.
static func eta_text(days: int, day_index: int) -> String:
	var tail: String = "2-Day" if days == 2 else GuiDates.days_text(days)
	return "%s (%s)" % [GuiDates.day_text(day_index + days), tail]


static func plural(count: int, one: String, many: String) -> String:
	return "%d %s" % [count, one if count == 1 else many]
