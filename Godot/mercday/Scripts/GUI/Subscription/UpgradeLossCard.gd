class_name UpgradeLossCard extends PanelContainer

#One upgrade the guild loses on a downgrade, read the way its Customize Plan tile reads it: the tile icon tinted by the owned
#tier, the name and category, what that tier gives, the tier pips and the monthly fee. Nothing on it is clickable.

const SIDES: Array[StringName] = [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]
const FILL: Color = GuiColors.ROW_FILL
const KIND_COLOR: Color = GuiColors.SKY
const GIVE_COLOR: Color = GuiColors.CREAM
const DESC_COLOR: Color = GuiColors.MUTED
const KIND_FONT: FontVariation = GuiStyle.SILK
const TIER_FONT: FontVariation = GuiStyle.SILK_BOLD
const TEXT_FONT: FontVariation = GuiStyle.BODY
const RING_PX: int = 1
const PAD: int = 8
const GAP: int = 10
const BODY_GAP: int = 3
const NAME_GAP: int = 8
const TIER_GAP: int = 6
const WELL_PAD: float = 6.0
const ICON_SCALE: int = 2
const SMALL_SIZE: int = 8
const TEXT_SIZE: int = 12
const FEE_SIZE: int = 13

var upgrade_id: String = ""

var _tier: int = 0
var _max: int = 1
var _fee: int = 0
var _tint: Color = Color.WHITE
var _icon: IconRect = null
var _title: Label = null
var _kind: Label = null
var _give: Label = null
var _desc: Label = null
var _chunks: HBoxContainer = null
var _roman: Label = null
var _cost: NotesLabel = null


#Builds the card for one upgrade at the tier the guild owns; calling it again rebuilds the card.
func setup(id: String, owned: int) -> void:
	GuiNodes.clear(self)
	upgrade_id = id
	_max = maxi(1, UpgradeDefs.tier_count(id))
	_tier = clampi(owned, 0, _max)
	_fee = UpgradeDefs.monthly_of(id, _tier)
	_tint = TreeLayout.block_color(id, {id: _tier})
	add_theme_stylebox_override(&"panel", GuiStyle.flat(FILL, RING_PX, _tint))
	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Pad"
	for side: StringName in SIDES:
		pad.add_theme_constant_override(side, PAD)
	add_child(pad)
	var line: HBoxContainer = GuiStyle.hbox(GAP)
	line.name = "Line"
	pad.add_child(line)
	line.add_child(_build_well())
	line.add_child(_build_body())
	line.add_child(_build_fee())
	GuiNodes.ignore_mouse(self)


func tier() -> int:
	return _tier


func max_tier() -> int:
	return _max


func fee() -> int:
	return _cost.amount


#The shown fee with its suffix and no glyph.
func fee_text() -> String:
	return _cost.value_text()


func icon_id() -> String:
	return _icon.icon_id


func icon_tint() -> Color:
	return _icon.tint


func name_text() -> String:
	return _title.text


func kind_text() -> String:
	return _kind.text


func give_text() -> String:
	return _give.text


func desc_text() -> String:
	return _desc.text


func tier_text() -> String:
	return _roman.text


func pip_count() -> int:
	return _chunks.get_child_count()


func pip_color(i: int) -> Color:
	if i < 0 or i >= pip_count():
		return GuiColors.CLEAR
	return (_chunks.get_child(i) as ColorRect).color


#The ring of the card: the same colour as the icon.
func ring_color() -> Color:
	return _tint


#The face of the icon tile, the maxed shade once every tier is owned.
func well_color() -> Color:
	return CustomizeBlock.BG_MAX if _tier >= _max else CustomizeBlock.BG


func _build_well() -> PanelContainer:
	var well: PanelContainer = PanelContainer.new()
	well.name = "Well"
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.add_theme_stylebox_override(&"panel", GuiStyle.flat(well_color(), 0, GuiColors.CLEAR, WELL_PAD))
	_icon = IconRect.new()
	_icon.name = "Icon"
	_icon.pixel_scale = ICON_SCALE
	_icon.icon_id = TreeIcons.id_of(upgrade_id)
	_icon.tint = _tint
	well.add_child(_icon)
	return well


func _build_body() -> VBoxContainer:
	var body: VBoxContainer = GuiStyle.vbox(BODY_GAP)
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top: HBoxContainer = GuiStyle.hbox(NAME_GAP)
	top.name = "Top"
	_title = GuiStyle.label(UpgradeDefs.name_of(upgrade_id), CustomizeBlock.NAME_FONT,
		CustomizeBlock.NAME_SIZE, CustomizeBlock.NAME_COLOR)
	_title.name = "Name"
	top.add_child(_title)
	_kind = GuiStyle.label(TreeLayout.cat_label(UpgradeDefs.category_of(upgrade_id)), KIND_FONT,
		SMALL_SIZE, KIND_COLOR)
	_kind.name = "Kind"
	_kind.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_kind)
	body.add_child(top)
	_give = _wrapped(UpgradeDefs.tier_text(upgrade_id, _tier), GIVE_COLOR)
	_give.name = "Give"
	body.add_child(_give)
	_desc = _wrapped(String(UpgradeDefs.of(upgrade_id).get("desc", "")), DESC_COLOR)
	_desc.name = "Desc"
	body.add_child(_desc)
	body.add_child(_build_tiers())
	return body


func _wrapped(text: String, color: Color) -> Label:
	var made: Label = GuiStyle.label(text, TEXT_FONT, TEXT_SIZE, color)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.visible = text != ""
	return made


#One chunk per tier of the upgrade, filled as the Customize Plan tube fills, then the tier numeral.
func _build_tiers() -> HBoxContainer:
	var row: HBoxContainer = GuiStyle.hbox(TIER_GAP)
	row.name = "Tiers"
	_chunks = GuiStyle.hbox(int(CustomizeBlock.PIP_GAP))
	_chunks.name = "Pips"
	_chunks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i: int in range(_max):
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(CustomizeBlock.PIP_W, CustomizeBlock.PIP_H)
		pip.color = _chunk_color(i)
		_chunks.add_child(pip)
	row.add_child(_chunks)
	_roman = GuiStyle.label(SubscriptionManager.roman(_tier), TIER_FONT, SMALL_SIZE, _tint)
	_roman.name = "Roman"
	row.add_child(_roman)
	return row


func _build_fee() -> NotesLabel:
	_cost = GuiStyle.notes(_fee, FEE_SIZE, CustomizeBlock.FEE_COLOR)
	_cost.name = "Fee"
	_cost.suffix = CustomizeBlock.SUFFIX
	_cost.suffix_size = SMALL_SIZE
	_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return _cost


#The fill of one tier chunk: its own rank colour when owned, else the empty tube colour.
func _chunk_color(i: int) -> Color:
	if i < _tier:
		return GuiColors.tier_color(i, _max)
	return CustomizeBlock.CHUNK_BG
