class_name NotificationFilterPanel extends Control

#The "Show" popup of the notification panel: a heading over one pickable row per kind. It is a
#plain Control and not a PopupPanel, so the panel places it and a headless suite can press a row.

signal picked(option: String)

const BOX_WIDTH: float = 200.0
const PAD: float = 12.0
const GAP: int = 4
const BG_COLOR: Color = GuiColors.BLUE_LO
const RING_COLOR: Color = GuiColors.ORANGE
const RING_WIDTH: float = 4.0
const SHADOW_OFFSET: float = 8.0
const SHADOW_SPREAD: float = 4.0
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const ROW_SELECTED_BG: Color = GuiColors.ORANGE
const ROW_SELECTED_FG: Color = GuiColors.INK
const ROW_IDLE_BG: Color = GuiColors.NAVY_ROW
const ROW_IDLE_FG: Color = GuiColors.CREAM
const ROW_HOVER_GAIN: float = 1.2
const ROW_FONT_SIZE: int = 14
const ROW_PAD_X: float = 8.0
const ROW_PAD_Y: float = 6.0
const POPUP_Z: int = 45

@export var heading_text: String = "Show":
	set(value):
		heading_text = value
		_apply_heading()
@export var options: Array[String] = []:
	set(value):
		options = value
		_rebuild()
@export var selected: String = "":
	set(value):
		selected = value
		_restyle()
@export var heading_path: NodePath = ^"Pad/Box/Heading"
@export var options_path: NodePath = ^"Pad/Box/Options"

var _heading: Label = null
var _options: VBoxContainer = null
var _rows: Array[Button] = []


func _ready() -> void:
	_heading = get_node_or_null(heading_path) as Label
	_options = get_node_or_null(options_path) as VBoxContainer
	z_index = POPUP_Z
	custom_minimum_size.x = BOX_WIDTH
	_apply_heading()
	_rebuild()


#Replaces the option list and the pick in one step, so the popup rebuilds once.
func set_options(list: Array[String], pick: String) -> void:
	options = list.duplicate()
	selected = pick


func set_selected(pick: String) -> void:
	selected = pick


func rows() -> Array[Button]:
	return _rows.duplicate()


func option_count() -> int:
	return _rows.size()


func row_for(option: String) -> Button:
	for row: Button in _rows:
		if row.text == option:
			return row
	return null


#Picks an option by its label; an unknown label is ignored.
func press(option: String) -> void:
	if not options.has(option):
		return
	selected = option
	picked.emit(option)


func row_bg(option: String) -> Color:
	return ROW_SELECTED_BG if option == selected else ROW_IDLE_BG


func row_fg(option: String) -> Color:
	return ROW_SELECTED_FG if option == selected else ROW_IDLE_FG


func _apply_heading() -> void:
	if _heading == null:
		return
	_heading.text = heading_text


func _rebuild() -> void:
	if _options == null:
		return
	GuiNodes.clear(_options)
	_rows.clear()
	_options.add_theme_constant_override("separation", GAP)
	for option: String in options:
		var row := Button.new()
		row.text = option
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.focus_mode = Control.FOCUS_NONE
		row.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		row.pressed.connect(press.bind(option))
		_options.add_child(row)
		_rows.append(row)
	_restyle()
	_fit()


func _restyle() -> void:
	for row: Button in _rows:
		var bg: Color = row_bg(row.text)
		var fg: Color = row_fg(row.text)
		row.add_theme_stylebox_override("normal", _row_box(bg))
		row.add_theme_stylebox_override("hover", _row_box(GuiColors.brighter(bg, ROW_HOVER_GAIN)))
		row.add_theme_stylebox_override("pressed", _row_box(GuiColors.brighter(bg, ROW_HOVER_GAIN)))
		row.add_theme_stylebox_override("focus", _row_box(bg))
		row.add_theme_color_override("font_color", fg)
		row.add_theme_color_override("font_hover_color", fg)
		row.add_theme_color_override("font_pressed_color", fg)
	queue_redraw()


func _fit() -> void:
	if _options == null:
		return
	var box: Control = _options.get_parent() as Control
	var inner: float = 0.0 if box == null else box.get_combined_minimum_size().y
	custom_minimum_size = Vector2(BOX_WIDTH, inner + PAD * 2.0)
	size = custom_minimum_size


func _row_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(0)
	box.content_margin_left = ROW_PAD_X
	box.content_margin_right = ROW_PAD_X
	box.content_margin_top = ROW_PAD_Y
	box.content_margin_bottom = ROW_PAD_Y
	return box


#The box: a hard shadow, then the orange ring outside the fill, then the fill.
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(SHADOW_OFFSET - SHADOW_SPREAD, SHADOW_OFFSET - SHADOW_SPREAD,
		w + SHADOW_SPREAD * 2.0, h + SHADOW_SPREAD * 2.0), SHADOW_COLOR)
	draw_rect(Rect2(-RING_WIDTH, -RING_WIDTH, w + RING_WIDTH * 2.0, h + RING_WIDTH * 2.0),
		RING_COLOR)
	draw_rect(Rect2(0.0, 0.0, w, h), BG_COLOR)
