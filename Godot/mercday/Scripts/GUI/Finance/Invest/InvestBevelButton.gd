class_name InvestBevelButton extends BevelButton

#A PROTO bevelled button: the body, the bevel bands and a hard ink outline, all painted by the
#core BevelButton so the Invest page shades like every other action button. The page sets the
#colours per side through the exports below, which are mapped onto the core members in _ready.
#The fill covers the built-in text, so the caption rides in a child Label named Caption.

const BAND: float = 3.0
const OUTLINE: float = 3.0

@export var body: Color = Color(0.121569, 0.207843, 0.376471, 1.0):
	set(value):
		body = value
		fill = value
@export var hover_body: Color = Color(0.168627, 0.309804, 0.541176, 1.0):
	set(value):
		hover_body = value
		hover_fill = value
@export var band_hi: Color = Color(0.231373, 0.435294, 0.713725, 1.0):
	set(value):
		band_hi = value
		hi = value
@export var band_lo: Color = Color(0.066667, 0.109804, 0.200000, 1.0):
	set(value):
		band_lo = value
		lo = value
@export var bands: bool = true:
	set(value):
		bands = value
		edge = BAND if value else 0.0
@export var caption: String = "":
	set(v):
		caption = v
		_write_caption()

var _caption: Label = null


func _ready() -> void:
	super()
	#The built-in text is empty here, so the font colour the caption copies stays readable.
	add_theme_color_override(&"font_color", text_color)
	fill = body
	hover_fill = hover_body
	hi = band_hi
	lo = band_lo
	edge = BAND if bands else 0.0
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


#The four colours of one side of the trade, set by the panel or the dialog.
func set_colors(new_fill: Color, new_hi: Color, new_lo: Color, new_hover: Color) -> void:
	body = new_fill
	band_hi = new_hi
	band_lo = new_lo
	hover_body = new_hover
	queue_redraw()


#The Invest body never dims on its own: a panel greys an unusable button through modulate.
func body_color() -> Color:
	return hover_body if is_hovered() and not disabled else body


#The PROTO button carries no padding: the caption Label fills the whole face.
func _apply_boxes() -> void:
	var box := StyleBoxEmpty.new()
	for state: StringName in STATES:
		add_theme_stylebox_override(state, box)
