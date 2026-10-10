class_name TravelTip extends TooltipPanel

#The hover card above a travel tile: the mode, how long the leg takes, what it costs and, on a barred
#tile, why. One card serves a whole selector, so it floats free of the row and parks itself over the
#hovered tile.

const WIDTH: int = 200
const FILL: Color = GuiColors.BLUE_LO
const RING: Color = GuiColors.SKY
const RING_PX: int = 3
const PAD_PX: float = 10.0
const AFFORD: Color = GuiColors.GREEN
const OVER_BUDGET: Color = GuiColors.RED
const REASON_COLOR: Color = GuiColors.RED
const REASON_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const REASON_FONT_SIZE: int = 11

@onready var rows: VBoxContainer = $Rows
@onready var cost_label: Label = $Rows/Cost/Number
@onready var glyph: NoteIcon = $Rows/Cost/Glyph

#Built here rather than in the scene; it sits under the cost and hides on an open tile.
var reason_label: Label = null


func _ready() -> void:
	super()
	custom_minimum_size.x = float(WIDTH)
	add_theme_stylebox_override(&"panel", GuiStyle.flat(FILL, RING_PX, RING, PAD_PX))
	reason_label = Label.new()
	reason_label.name = "Reason"
	reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	#Held at the inner width of the card, so the reason wraps there and the card measures true on its first show.
	reason_label.custom_minimum_size.x = float(WIDTH) - get_theme_stylebox(&"panel").get_minimum_size().x
	reason_label.add_theme_font_override(&"font", REASON_FONT)
	reason_label.add_theme_font_size_override(&"font_size", REASON_FONT_SIZE)
	reason_label.add_theme_color_override(&"font_color", REASON_COLOR)
	reason_label.hide()
	rows.add_child(reason_label)


func show_for(button: TravelButton) -> void:
	if button == null or not is_node_ready():
		return
	_fill(button.mode, button.minutes_value(), button.cost_value(), button.is_affordable(),
		button.reason_text())
	show()
	reset_size()
	#top_level skips the popup's UI scale, so the card borrows the scale of the tile it points at
	scale = button.get_global_transform().get_scale()
	var rect: Rect2 = button.get_global_rect()
	var span: Vector2 = size * scale
	#The anchor narrows to the card width around the tile centre, so the card centres on the tile.
	var over := Rect2(rect.get_center().x - span.x / 2.0, rect.position.y, span.x, rect.size.y)
	global_position = tip_position(over, span, get_viewport().get_visible_rect(), side)


func mode_text() -> String:
	return title_label.text if is_node_ready() else ""


func cost_text() -> String:
	return cost_label.text if is_node_ready() else ""


#The barred line under the cost; empty when the hovered tile is open.
func reason_text() -> String:
	if reason_label == null or not reason_label.visible:
		return ""
	return reason_label.text


func _fill(mode: Dictionary, minutes: int, cost: int, affordable: bool, reason: String = "") -> void:
	title_label.text = "BY " + str(mode.get("label", "")).to_upper()
	body_label.text = ContractPreview.days_text(minutes / 60.0)
	cost_label.text = "%d" % cost
	cost_label.add_theme_color_override(&"font_color", AFFORD if affordable else OVER_BUDGET)
	if reason_label != null:
		reason_label.text = reason
		reason_label.visible = reason != ""
