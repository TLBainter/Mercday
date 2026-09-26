class_name StatCard extends PanelContainer

#One of the three small fact boxes under the posting header: a caption, a value and a note.
#The accent colour rides on the value for the Urgency card; the accent bar stays hidden.

const VALUE_FONT: String = "res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres"
const ACCENT_FONT: String = "res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres"
const VALUE_SIZE: int = 15
const ACCENT_SIZE: int = 14
const VALUE_COLOR: Color = Color("#f3ead7")
const ACCENT_CAPTION: String = "Urgency"

#When true the note rides to the right of the value instead of stacking under it.
@export var note_inline: bool = false

@onready var accent_bar: ColorRect = $Row/Accent
@onready var caption_label: Label = $Row/Text/Caption
@onready var value_label: Label = $Row/Text/ValueRow/Value
@onready var note_inline_label: Label = $Row/Text/ValueRow/NoteInline
@onready var note_label: Label = $Row/Text/Note

var caption: String = ""
var value: String = ""
var note: String = ""
var accent: Color = Color("#f28c28")


func _ready() -> void:
	_refresh()


func set_card(new_caption: String, new_value: String, new_note: String,
		new_accent: Color = Color("#f28c28")) -> void:
	caption = new_caption
	value = new_value
	note = new_note
	accent = new_accent
	_refresh()


#The value face, size and colour; the Urgency card calls it with the accent font and colour.
func set_value_style(font: Font, size_px: int, color: Color) -> void:
	if not is_node_ready():
		return
	value_label.add_theme_font_override("font", font)
	value_label.add_theme_font_size_override("font_size", size_px)
	value_label.add_theme_color_override("font_color", color)


func value_text() -> String:
	return value


func accent_color() -> Color:
	return accent


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption.to_upper()
	value_label.text = value
	if caption == ACCENT_CAPTION:
		set_value_style(load(ACCENT_FONT) as Font, ACCENT_SIZE, accent)
	else:
		set_value_style(load(VALUE_FONT) as Font, VALUE_SIZE, VALUE_COLOR)
	#a trimmed value keeps no width of its own, so the inline row trims the note instead
	if note_inline:
		value_label.clip_text = false
		value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		note_inline_label.text = note
		note_inline_label.visible = note != ""
		note_label.text = ""
		note_label.visible = false
	else:
		value_label.clip_text = true
		value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		note_inline_label.text = ""
		note_inline_label.visible = false
		note_label.text = note
		note_label.visible = note != ""
	accent_bar.color = accent
	accent_bar.visible = false


#Hours as a compact span: under a day stays in hours, longer reads as days and hours.
static func hours_text(hours: float) -> String:
	var whole: int = int(round(hours))
	if whole < 24:
		return "%dh" % whole
	return "%dd %dh" % [int(whole / 24.0), whole % 24]
