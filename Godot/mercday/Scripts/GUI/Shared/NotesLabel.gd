class_name NotesLabel extends HBoxContainer

#A number (or an override string) followed by the note currency glyph, or led by it when glyph_first
#is set, with an optional prefix before the number and an optional suffix last, at its own size when
#suffix_size is set. Every node ignores the mouse so a host tooltip still reaches the row behind it.

const FONT_BOLD: FontVariation = GuiStyle.SILK_BOLD
const FONT_REGULAR: FontVariation = GuiStyle.SILK

@export var amount: int = 0:
	set(value):
		amount = value
		_refresh()
@export var text_override: String = "":
	set(value):
		text_override = value
		_refresh()
@export var prefix: String = "":
	set(value):
		prefix = value
		_refresh()
@export var suffix: String = "":
	set(value):
		suffix = value
		_refresh()
@export var suffix_size: int = 0:
	set(value):
		suffix_size = maxi(0, value)
		_refresh()
@export var signed: bool = false:
	set(value):
		signed = value
		_refresh()
@export var value_color: Color = GuiColors.CREAM:
	set(value):
		value_color = value
		_refresh()
@export var font_size: int = 13:
	set(value):
		font_size = maxi(1, value)
		_refresh()
@export var bold: bool = true:
	set(value):
		bold = value
		_refresh()
@export var glyph_scale: int = 2:
	set(value):
		glyph_scale = maxi(1, value)
		_refresh()
@export var show_glyph: bool = true:
	set(value):
		show_glyph = value
		_refresh()
@export var glyph_first: bool = false:
	set(value):
		glyph_first = value
		_refresh()
@export var separation: int = 4:
	set(value):
		separation = maxi(0, value)
		_refresh()

@onready var value_label: Label = $ValueLabel
@onready var glyph: NoteIcon = $Glyph
@onready var suffix_label: Label = $SuffixLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suffix_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	add_theme_constant_override("separation", separation)
	var font: FontVariation = FONT_BOLD if bold else FONT_REGULAR
	value_label.text = prefix + _core_text()
	GuiStyle.paint(value_label, font, font_size, value_color)
	glyph.visible = show_glyph
	move_child(glyph, 0 if glyph_first else 1)
	glyph.pixel_scale = glyph_scale
	suffix_label.text = suffix
	suffix_label.visible = suffix != ""
	suffix_label.add_theme_color_override("font_color", value_color)
	suffix_label.add_theme_font_size_override("font_size",
		font_size if suffix_size <= 0 else suffix_size)
	suffix_label.add_theme_font_override("font", font)


func _core_text() -> String:
	if text_override != "":
		return text_override
	var body: String = TransactionData.grouped(amount)
	if signed and amount > 0:
		body = "+" + body
	return body


#The whole shown text (prefix, number or override, suffix) with the glyph left out.
func value_text() -> String:
	return prefix + _core_text() + suffix
