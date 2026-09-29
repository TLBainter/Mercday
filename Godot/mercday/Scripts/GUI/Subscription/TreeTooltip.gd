class_name TreeTooltip extends PanelContainer

#The hover card of the Customize tree. A category, the Base plan and a requirement gate show the
#plain card (kind, name, description, one closing line); an upgrade module shows the rich card with
#its tier count, its monthly fee and the next tier. The card builds its own rows, so the scene file
#holds nothing but the root.

const WIDTH: float = 320.0
const PAD: int = 10
const GAP: int = 4
const PLAIN_HEIGHT: float = 150.0
const RICH_HEIGHT: float = 260.0
const MAXED_HEIGHT: float = 190.0
const EDGE_GAP: float = 2.0
const SIDE_INSET: float = 24.0
const RIGHT_ROOM: float = 340.0
const TOP_MIN: float = 4.0
const STYLE: StyleBox = preload("res://Resources/GUI/Theme/Styles/tree_tooltip.tres")
const KIND_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const NAME_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const BODY_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const KIND_COLOR: Color = Color("#f28c28")
const NAME_COLOR: Color = Color("#f3ead7")
const BODY_COLOR: Color = Color("#9cc6ef")
const NEXT_COLOR: Color = Color("#c8d3e6")
const FEE_COLOR: Color = Color("#f2d33d")
const NOTE_COLOR: Color = Color("#e8583f")
const OWNED_COLOR: Color = Color("#f3ead7")
const SUFFIX: String = "/month"
const NEXT_HEAD: String = "Next Tier"
const CAT_KIND: String = "Category"
const GATE_KIND: String = "Requirement"
const BASE_KIND: String = "Enterprise"
const BASE_NAME: String = "Base Plan"
const BASE_DESC: String = "The root of your Enterprise customizations. Every branch starts here."
const OWNED_SUFFIX: String = " upgrades owned"
const MET_TEXT: String = "Requirement met"
const GLYPH_SCALE: int = 1
const ICON_SCALE: int = 2

var _rich: bool = false
var _height: float = PLAIN_HEIGHT
var _icon: IconRect = null
var _kind: Label = null
var _name: Label = null
var _desc: Label = null
var _close: Label = null
var _stat: HBoxContainer = null
var _stat_amount: Label = null
var _stat_suffix: Label = null
var _next_head: Label = null
var _next: Label = null
var _next_fee: HBoxContainer = null
var _next_fee_amount: Label = null
var _next_fee_suffix: Label = null
var _note: Label = null


func _ready() -> void:
	z_index = TooltipPanel.TOOLTIP_Z
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0.0)
	add_theme_stylebox_override("panel", STYLE)
	_build()
	hide()


#The card of one hovered thing: kind is "cat", "base", "gate" or "block" and key names it.
func show_for(kind: String, key: String, at: Rect2, view: Vector2) -> void:
	if kind == "":
		hide_tip()
		return
	if kind == "cat":
		_fill_cat(key)
	elif kind == "gate":
		_fill_gate(key)
	elif key == "base":
		_fill_base()
	else:
		_fill_block(key)
	place(at, view)
	show()


func hide_tip() -> void:
	hide()


#Below the anchor, or above it when the card would leave the frame; never past the right edge.
func place(at: Rect2, view: Vector2) -> void:
	var x: float = minf(at.position.x + SIDE_INSET, view.x - RIGHT_ROOM)
	var below: float = at.end.y + EDGE_GAP
	var y: float = below
	if below + _height > view.y:
		y = maxf(TOP_MIN, at.position.y - _height)
	position = Vector2(x, y)


func is_rich() -> bool:
	return _rich


func tip_height() -> float:
	return _height


func kind_text() -> String:
	return _kind.text


func name_text() -> String:
	return _name.text


func desc_text() -> String:
	return _desc.text


func close_text() -> String:
	return _close.text


func stat_text() -> String:
	return _stat_amount.text + _stat_suffix.text


func next_text() -> String:
	return _next.text


func next_fee_text() -> String:
	return _next_fee_amount.text + _next_fee_suffix.text


func note_text() -> String:
	return _note.text


#"N prior upgrade(s) still required" until the gate opens.
func req_text(id: String) -> String:
	var tiers: Dictionary = SubscriptionManager.tiers()
	var short: int = UpgradeDefs.requirement_need(id) - UpgradeDefs.requirement_have(id, tiers)
	short = maxi(0, short)
	if short == 0:
		return MET_TEXT
	return "%d prior upgrade%s still required" % [short, "" if short == 1 else "s"]


func _fill_cat(cat: String) -> void:
	_set_icon(TreeIcons.id_of(cat), KIND_COLOR, Icons.MODE_PLAIN)
	var def: Dictionary = TreeLayout.cat_def(cat)
	var tiers: Dictionary = SubscriptionManager.tiers()
	var counts: Vector2i = TreeLayout.category_counts(cat, tiers)
	_plain(CAT_KIND, String(def.get("name", cat)), String(def.get("desc", "")),
		str(counts.x) + "/" + str(counts.y) + OWNED_SUFFIX, OWNED_COLOR)


func _fill_base() -> void:
	_set_icon("mercday", NAME_COLOR, Icons.MODE_GRAY)
	_plain(BASE_KIND, BASE_NAME, BASE_DESC, "", BODY_COLOR)


func _fill_gate(id: String) -> void:
	_icon.visible = false
	_plain(GATE_KIND, UpgradeDefs.name_of(id), req_text(id), "", BODY_COLOR)


func _fill_block(id: String) -> void:
	_set_icon(TreeIcons.id_of(id), NAME_COLOR, Icons.MODE_PLAIN)
	var tier: int = SubscriptionManager.tier_of(id)
	var top: int = SubscriptionManager.max_tier(id)
	var maxed: bool = tier >= top
	_rich = true
	_height = MAXED_HEIGHT if maxed else RICH_HEIGHT
	_kind.text = TreeLayout.cat_label(UpgradeDefs.category_of(id))
	_name.text = UpgradeDefs.name_of(id)
	_desc.text = String(UpgradeDefs.of(id).get("desc", ""))
	_close.text = ""
	_close.visible = false
	var fee: int = SubscriptionManager.upgrade_fee(id)
	_stat_amount.text = str(tier) + "/" + str(top) + "   " + str(fee)
	_stat_suffix.text = SUFFIX
	_stat.visible = true
	_next_head.visible = not maxed
	_next.visible = not maxed
	_next_fee.visible = not maxed
	var next_fee: int = SubscriptionManager.tier_price(id, tier + 1)
	_next.text = "" if maxed else UpgradeDefs.tier_text(id, tier + 1)
	_next_fee_amount.text = "" if maxed else "+" + str(next_fee)
	_next_fee_suffix.text = "" if maxed else SUFFIX
	var gated: bool = not UpgradeDefs.requirement_met(id, SubscriptionManager.tiers())
	_note.text = req_text(id) if gated else ""
	_note.visible = gated
	reset_size()


func _plain(kind: String, label: String, body: String, closing: String, tint: Color) -> void:
	_rich = false
	_height = PLAIN_HEIGHT
	_kind.text = kind
	_name.text = label
	_desc.text = body
	_close.text = closing
	_close.visible = closing != ""
	_close.add_theme_color_override("font_color", tint)
	_stat.visible = false
	_next_head.visible = false
	_next.visible = false
	_next_fee.visible = false
	_note.visible = false
	reset_size()


func _build() -> void:
	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Pad"
	var sides: PackedStringArray = ["left", "right", "top", "bottom"]
	for side: String in sides:
		pad.add_theme_constant_override("margin_" + side, PAD)
	add_child(pad)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", GAP)
	pad.add_child(rows)
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", GAP)
	rows.add_child(head)
	_icon = IconRect.new()
	_icon.name = "Icon"
	_icon.pixel_scale = ICON_SCALE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_icon)
	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.name = "Text"
	text_box.add_theme_constant_override("separation", GAP)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text_box)
	var head_width: float = WIDTH - float(PAD * 2) - 32.0 - float(GAP)
	_kind = _row(text_box, "Kind", KIND_FONT, 10, KIND_COLOR, head_width)
	_name = _row(text_box, "Name", NAME_FONT, 14, NAME_COLOR, head_width)
	_desc = _row(rows, "Desc", BODY_FONT, 14, BODY_COLOR)
	_close = _row(rows, "Close", BODY_FONT, 13, BODY_COLOR)
	_stat = _money_row(rows, "Stat", NAME_FONT, 12, NAME_COLOR)
	_stat_amount = _stat.get_node("Amount") as Label
	_stat_suffix = _stat.get_node("Suffix") as Label
	_next_head = _row(rows, "NextHead", NAME_FONT, 9, KIND_COLOR)
	_next_head.text = NEXT_HEAD
	_next = _row(rows, "Next", BODY_FONT, 13, NEXT_COLOR)
	_next_fee = _money_row(rows, "NextFee", BODY_FONT, 12, FEE_COLOR)
	_next_fee_amount = _next_fee.get_node("Amount") as Label
	_next_fee_suffix = _next_fee.get_node("Suffix") as Label
	_note = _row(rows, "Note", BODY_FONT, 12, NOTE_COLOR)


#A money row: the amount, the notes tile and the suffix, so every fee carries the glyph.
func _money_row(rows: VBoxContainer, label: String, font: FontVariation, size_px: int,
		tint: Color) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = label
	line.custom_minimum_size = Vector2(WIDTH - float(PAD * 2), 0.0)
	line.add_theme_constant_override("separation", 2)
	line.add_child(_cell("Amount", font, size_px, tint))
	var glyph: NoteIcon = NoteIcon.new()
	glyph.name = "Glyph"
	glyph.pixel_scale = GLYPH_SCALE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(glyph)
	line.add_child(_cell("Suffix", font, size_px, tint))
	rows.add_child(line)
	return line


func _cell(label: String, font: FontVariation, size_px: int, tint: Color) -> Label:
	var out: Label = Label.new()
	out.name = label
	out.add_theme_font_override("font", font)
	out.add_theme_font_size_override("font_size", size_px)
	out.add_theme_color_override("font_color", tint)
	return out


func _row(rows: VBoxContainer, label: String, font: FontVariation, size_px: int, tint: Color,
		width: float = WIDTH - float(PAD * 2)) -> Label:
	var out: Label = Label.new()
	out.name = label
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.custom_minimum_size = Vector2(width, 0.0)
	out.add_theme_font_override("font", font)
	out.add_theme_font_size_override("font_size", size_px)
	out.add_theme_color_override("font_color", tint)
	rows.add_child(out)
	return out


#The head icon of the hovered thing; "" when the card shows no icon.
func icon_id() -> String:
	return _icon.icon_id if _icon != null and _icon.visible else ""


func _set_icon(id: String, tint: Color, mode: StringName) -> void:
	_icon.visible = id != ""
	if id == "":
		return
	_icon.tint = tint
	_icon.set_id(id, ICON_SCALE, mode)
