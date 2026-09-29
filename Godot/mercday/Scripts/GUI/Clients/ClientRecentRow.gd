class_name ClientRecentRow
extends Button

#One recent contract of a client. A row still on the board opens the contract window; a row that
#has left the board reads as a record only.

signal pressed_row(entry_id: int)

const IDLE_FILL: Color = Color("#15223d")
const IDLE_EDGE: Color = Color("#3b6fb6")
const HOVER_FILL: Color = Color("#1f3560")
const HOVER_EDGE: Color = Color("#f28c28")
const LINK_COLOR: Color = Color("#f28c28")
const EDGE_PX: int = 2
const PAD_PX: float = 6.0
const FACE_PX: int = 40
const FACE_BAND: int = 4
const ROW_HEIGHT: int = 65
const LINK_TEXT: String = "View Contract"

var entry_id: int = -1
var listed: bool = false

var _row: Dictionary = {}

@onready var inner: HBoxContainer = $Row
@onready var face: TextureRect = $Row/FaceHolder/Fill
@onready var name_label: Label = $Row/Names/RowName
@onready var result_label: Label = $Row/Names/Result
@onready var link_box: HBoxContainer = $Row/Names/Link
@onready var arrow: TextureRect = $Row/Names/Link/Arrow


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, float(ROW_HEIGHT))
	arrow.texture = ClientGlyphs.arrow(LINK_COLOR)
	face.texture = ClientGlyphs.hatch(FACE_PX, FACE_BAND)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_render()


func set_row(row: Dictionary) -> void:
	_row = row.duplicate(true)
	entry_id = int(_row.get("entry_id", -1))
	listed = bool(_row.get("listed", false))
	disabled = not listed
	tooltip_text = LINK_TEXT if listed else ""
	if is_node_ready():
		_render()


func _render() -> void:
	name_label.text = String(_row.get("name", ""))
	result_label.text = String(_row.get("result", ""))
	var tint: Color = IDLE_EDGE
	if _row.get("color") is Color:
		tint = _row["color"]
	result_label.add_theme_color_override(&"font_color", tint)
	link_box.visible = listed
	_apply_boxes()


func press() -> void:
	if disabled:
		return
	_on_pressed()


func name_text() -> String:
	return name_label.text


func result_text() -> String:
	return result_label.text


func result_color() -> Color:
	return result_label.get_theme_color(&"font_color")


func link_shown() -> bool:
	return link_box.visible


#The height the stacked texts need inside the row, what ROW_HEIGHT has to clear with PAD_PX.
func inner_min_height() -> float:
	return inner.get_combined_minimum_size().y


static func row_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_width_left = EDGE_PX
	box.border_width_top = EDGE_PX
	box.border_width_right = EDGE_PX
	box.border_width_bottom = EDGE_PX
	box.border_color = edge
	box.content_margin_left = PAD_PX
	box.content_margin_top = PAD_PX
	box.content_margin_right = PAD_PX
	box.content_margin_bottom = PAD_PX
	return box


func _apply_boxes() -> void:
	var idle: StyleBoxFlat = row_box(IDLE_FILL, IDLE_EDGE)
	add_theme_stylebox_override(&"normal", idle)
	add_theme_stylebox_override(&"disabled", row_box(IDLE_FILL, IDLE_EDGE))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	if listed:
		add_theme_stylebox_override(&"hover", row_box(HOVER_FILL, HOVER_EDGE))
		add_theme_stylebox_override(&"pressed", row_box(HOVER_FILL, HOVER_EDGE))
	else:
		add_theme_stylebox_override(&"hover", row_box(IDLE_FILL, IDLE_EDGE))
		add_theme_stylebox_override(&"pressed", row_box(IDLE_FILL, IDLE_EDGE))


func _on_pressed() -> void:
	if not listed or entry_id < 0:
		return
	pressed_row.emit(entry_id)
