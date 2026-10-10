class_name StatTile extends PanelContainer

#A labeled stat tile: a small caption row, a bold NotesLabel value row, and an optional sub caption
#row hidden when empty. compact swaps to the tighter padding, drops the sub row and shrinks the
#value row, matching the payroll tile spec.

const FONT_LABEL: FontVariation = GuiStyle.SILK
const FONT_SUB: FontVariation = GuiStyle.BODY
const STYLE_NORMAL: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/dark_box.tres")
const STYLE_COMPACT: StyleBoxFlat = preload("res://Resources/GUI/Theme/Styles/dark_box_compact.tres")

@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var amount: int = 0:
	set(value):
		amount = value
		_refresh()
@export var value_text: String = "":
	set(value):
		value_text = value
		_refresh()
@export var value_color: Color = GuiColors.CREAM:
	set(value):
		value_color = value
		_refresh()
@export var show_glyph: bool = true:
	set(value):
		show_glyph = value
		_refresh()
@export var sub: String = "":
	set(value):
		sub = value
		_refresh()
@export var compact: bool = false:
	set(value):
		compact = value
		_refresh()

@onready var label_text: Label = $Rows/LabelText
@onready var value_row: NotesLabel = $Rows/ValueRow
@onready var sub_text: Label = $Rows/SubText
@onready var rows: VBoxContainer = $Rows


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	add_theme_stylebox_override("panel", STYLE_COMPACT if compact else STYLE_NORMAL)
	rows.add_theme_constant_override("separation", 4 if compact else 6)
	label_text.text = label
	GuiStyle.paint(label_text, FONT_LABEL, 9, GuiColors.SKY)
	value_row.amount = amount
	value_row.text_override = value_text
	value_row.value_color = value_color
	value_row.show_glyph = show_glyph
	value_row.bold = true
	value_row.font_size = 13 if compact else 18
	value_row.glyph_scale = 2
	sub_text.text = sub
	sub_text.visible = sub != "" and not compact
	GuiStyle.paint(sub_text, FONT_SUB, 12, GuiColors.DIM_TEXT)


#Fills the tile from a row dictionary; every key is optional and keeps the current value.
func set_stat(row: Dictionary) -> void:
	if row.has("label"):
		label = String(row.get("label"))
	if row.has("amount"):
		amount = int(row.get("amount"))
	if row.has("text"):
		value_text = String(row.get("text"))
	if row.has("color"):
		value_color = row.get("color")
	if row.has("glyph"):
		show_glyph = bool(row.get("glyph"))
	if row.has("sub"):
		sub = String(row.get("sub"))
