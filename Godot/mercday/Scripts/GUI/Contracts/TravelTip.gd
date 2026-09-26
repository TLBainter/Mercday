class_name TravelTip extends PanelContainer

#The hover card above a travel tile: the mode, how long the leg takes and what it costs. One card
#serves a whole selector, so it floats free of the row and parks itself over the hovered tile.

const WIDTH: int = 200
const GAP: float = 4.0
const FILL: Color = Color("#1f3560")
const RING: Color = Color("#9cc6ef")
const RING_PX: int = 3
const PAD_PX: float = 10.0
const AFFORD: Color = Color("#6cc36a")
const OVER_BUDGET: Color = Color("#e8583f")

@onready var rows: VBoxContainer = $Rows
@onready var name_label: Label = $Rows/Name
@onready var duration_label: Label = $Rows/Duration
@onready var cost_label: Label = $Rows/Cost/Number
@onready var glyph: NoteIcon = $Rows/Cost/Glyph


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = float(WIDTH)
	add_theme_stylebox_override(&"panel", _frame())
	hide()


#"2 Days, 1 Hours" the way the handoff spells it; a mode with no travel time arrives at once.
static func duration_text(minutes: int) -> String:
	if minutes <= 0:
		return "Instant"
	return "%d Days, %d Hours" % [int(minutes / 1440.0), int((minutes % 1440) / 60.0)]


func show_for(button: TravelButton) -> void:
	if button == null or not is_node_ready():
		return
	_fill(button.mode, button.minutes_value(), button.cost_value(), button.is_affordable())
	show()
	reset_size()
	#top_level skips the popup's UI scale, so the card borrows the scale of the tile it points at
	scale = button.get_global_transform().get_scale()
	var rect: Rect2 = button.get_global_rect()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var span: Vector2 = size * scale
	var left: float = rect.get_center().x - span.x / 2.0
	left = clampf(left, 0.0, maxf(0.0, view.x - span.x))
	global_position = Vector2(left, rect.position.y - span.y - GAP)


func hide_tip() -> void:
	hide()


func mode_text() -> String:
	return name_label.text if is_node_ready() else ""


func cost_text() -> String:
	return cost_label.text if is_node_ready() else ""


func _fill(mode: Dictionary, minutes: int, cost: int, affordable: bool) -> void:
	name_label.text = "BY " + str(mode.get("label", "")).to_upper()
	duration_label.text = duration_text(minutes)
	cost_label.text = "%d" % cost
	cost_label.add_theme_color_override(&"font_color", AFFORD if affordable else OVER_BUDGET)


func _frame() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = RING
	style.border_width_left = RING_PX
	style.border_width_top = RING_PX
	style.border_width_right = RING_PX
	style.border_width_bottom = RING_PX
	style.content_margin_left = PAD_PX
	style.content_margin_top = PAD_PX
	style.content_margin_right = PAD_PX
	style.content_margin_bottom = PAD_PX
	return style
