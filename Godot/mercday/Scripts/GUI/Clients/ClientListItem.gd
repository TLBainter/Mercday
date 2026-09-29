class_name ClientListItem
extends Button

#One row of the client list: a hatched portrait stand-in, the name and sub type, and how many
#contracts this client has had the guild accept.

const NORMAL_FILL: Color = Color("#0e1628")
const SELECTED_FILL: Color = Color("#15223d")
const HOVER_FILL: Color = Color("#15223d")
const NORMAL_EDGE: Color = Color("#0a0f1c")
const SELECTED_EDGE: Color = Color("#f28c28")
const EDGE_PX: int = 3
const PAD_PX: float = 6.0
const FACE_PX: int = 48
const FACE_BAND: int = 4
const ROW_HEIGHT: int = 60

@export var selected: bool = false:
	set(value):
		selected = value
		_apply_boxes()

var client: ClientData = null

@onready var face: TextureRect = $Row/FaceHolder/Fill
@onready var name_label: Label = $Row/Names/ClientName
@onready var sub_label: Label = $Row/Names/Sub
@onready var count_label: Label = $Row/Right/Count


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, float(ROW_HEIGHT))
	_apply_boxes()
	_render()


func set_client(row: ClientData) -> void:
	client = row
	if is_node_ready():
		_render()


func set_selected(on: bool) -> void:
	selected = on


func client_key() -> String:
	if client == null:
		return ""
	return client.key()


func name_text() -> String:
	return name_label.text


func sub_text() -> String:
	return sub_label.text


func count_text() -> String:
	return count_label.text


func edge_color() -> Color:
	var box: StyleBox = get_theme_stylebox(&"normal")
	if box is StyleBoxFlat:
		var edge_box: StyleBoxFlat = box
		return edge_box.border_color
	return NORMAL_EDGE


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
	var fill: Color = SELECTED_FILL if selected else NORMAL_FILL
	var edge: Color = SELECTED_EDGE if selected else NORMAL_EDGE
	add_theme_stylebox_override(&"normal", row_box(fill, edge))
	add_theme_stylebox_override(&"hover", row_box(HOVER_FILL, edge))
	add_theme_stylebox_override(&"pressed", row_box(SELECTED_FILL, edge))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())


func _render() -> void:
	face.texture = ClientGlyphs.hatch(FACE_PX, FACE_BAND)
	if client == null:
		name_label.text = ""
		sub_label.text = ""
		count_label.text = "0"
		tooltip_text = ""
		return
	name_label.text = client.name
	sub_label.text = client.sub
	count_label.text = "%d" % client.accepted
	tooltip_text = client.where_text()
