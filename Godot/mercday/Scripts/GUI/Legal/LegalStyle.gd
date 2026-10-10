class_name LegalStyle

#The looks only the Legal screens use: the section and column heads, the button size, the theme
#style copies and the hatched portrait box. Colours and the shared builders come from GuiColors
#and GuiStyle.

const PORTRAIT_HATCH: Color = GuiColors.SLATE
const STYLE_DIR: String = "res://Resources/GUI/Theme/Styles/"


#The orange section head over a block of rows.
static func head(body: String, size: int = 9) -> Label:
	return GuiStyle.label(body, GuiStyle.SILK, size, GuiColors.ORANGE)


static func button(body: String, kind: StringName, height: int, font_size: int = 11) -> Button:
	var out: BevelButton = GuiStyle.button(body, kind, float(height))
	out.add_theme_font_size_override(&"font_size", font_size)
	return out


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


#The ink cell the fact rows and the progress rows sit on.
static func cell(bg: Color = GuiColors.INK) -> PanelContainer:
	var out := PanelContainer.new()
	var style: StyleBoxFlat = styled("legal_cell.tres")
	style.bg_color = bg
	out.add_theme_stylebox_override(&"panel", style)
	return out


static func divider(color: Color = GuiColors.BLUE_LO, px: int = 2) -> ColorRect:
	var out := ColorRect.new()
	out.name = "Divider"
	out.color = color
	out.custom_minimum_size = Vector2(0.0, float(px))
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


#The hatched placeholder box the icon and portrait cells use until real art lands.
static func hatch_box(span: Vector2, ring: Color, fill: Color = PORTRAIT_HATCH,
		back: Color = GuiColors.ROW_HOVER) -> PanelContainer:
	var out := PanelContainer.new()
	out.name = "Hatch"
	out.custom_minimum_size = span
	out.add_theme_stylebox_override(&"panel", GuiStyle.flat(back, 2, ring, 0.0))
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


#The merc's roster name, or "Merc <uid>" when that merc is not on the roster any more.
static func merc_name(uid: int) -> String:
	var view: MercView = BenefitsManager.view_of(uid)
	return view.name if view != null else "Merc %d" % uid


#The printed name of a permit kind.
static func permit_name(kind: StringName) -> String:
	return "Teleportation Permit" if kind == LegalManager.PERMIT_TELE else "Operations Permit"


#The id of the upgrade that raises a permit kind's tier; UpgradeDefs holds its printed name.
static func permit_upgrade(kind: StringName) -> String:
	return "teleport" if kind == LegalManager.PERMIT_TELE else "opspermit"


#A fixed width column label for the head line over a list.
static func column(body: String, width: int) -> Label:
	var out: Label = GuiStyle.label(body, GuiStyle.SILK, 9, GuiColors.MUTED)
	out.custom_minimum_size = Vector2(float(width), 0.0)
	out.clip_text = true
	return out


#The printed name of one location, or Legal when that id is not on the map.
static func location_name(loc_id: int) -> String:
	var place: LegalLocationData = LegalManager.location(loc_id)
	return place.name if place != null else "Legal"
