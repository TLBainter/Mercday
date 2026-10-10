class_name InvestBevelButton extends BevelButton

#A PROTO bevelled button: the body, the bevel bands and a hard ink outline, all painted by the
#core BevelButton so the Invest page shades like every other action button. The scenes set the
#core fill, hover_fill, hi and lo; a panel or a dialog retints one side by setting those four.
#The fill covers the built-in text, so the caption rides in a child Label named Caption.

const BAND: float = 3.0
const OUTLINE: float = 3.0

@export var caption: String = "":
	set(v):
		caption = v
		_write_caption()

var _caption: Label = null


func _ready() -> void:
	super()
	#The built-in text is empty here, so the font colour the caption copies stays readable.
	add_theme_color_override(&"font_color", text_color)
	edge = BAND
	outline = OUTLINE
	_caption = InvestText.caption_label(self)
	if caption == "" and text != "":
		caption = text
	text = ""
	_write_caption()


func caption_text() -> String:
	return caption


func caption_node() -> Label:
	return _caption


func _write_caption() -> void:
	if _caption == null:
		return
	_caption.text = caption


#The Invest body never dims on its own: a panel greys an unusable button through modulate.
func body_color() -> Color:
	return hover_color() if is_hovered() and not disabled else fill


#The PROTO button carries no padding: the caption Label fills the whole face.
func _apply_boxes() -> void:
	var box := StyleBoxEmpty.new()
	for state: StringName in STATES:
		add_theme_stylebox_override(state, box)
