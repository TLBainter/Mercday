class_name ClientRecentRow
extends ClientListItem

#One recent contract of a client. A row still on the board opens the contract window; a row that
#has left the board reads as a record only.

signal pressed_row(entry_id: int)

const LINK_TEXT: String = "View Contract"

var entry_id: int = -1
var listed: bool = false

var _row: Dictionary = {}

@onready var inner: HBoxContainer = $Row
@onready var link_box: HBoxContainer = $Row/Names/Link
@onready var arrow: TextureRect = $Row/Names/Link/Arrow


#A record row is disabled yet keeps its idle look: no dimming, and no ring under the pointer.
func _init() -> void:
	super()
	disabled_solid = true
	active_shade = ButtonFx.HoverShade.NONE


func _ready() -> void:
	super()
	arrow.texture = Icons.tinted("caret_right", GuiColors.ORANGE, 2, true)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func set_row(row: Dictionary) -> void:
	_row = row.duplicate(true)
	entry_id = int(_row.get("entry_id", -1))
	listed = bool(_row.get("listed", false))
	disabled = not listed
	tooltip_text = LINK_TEXT if listed else ""
	if is_node_ready():
		_render()


func press() -> void:
	if disabled:
		return
	_on_pressed()


func result_color() -> Color:
	return sub_label.get_theme_color(&"font_color")


func link_shown() -> bool:
	return link_box.visible


#The height the stacked texts need inside the row, what the row minimum height has to clear with
#the content margin on both sides.
func inner_min_height() -> float:
	return inner.get_combined_minimum_size().y


func _render() -> void:
	name_label.text = String(_row.get("name", ""))
	sub_label.text = String(_row.get("result", ""))
	var tint: Color = GuiColors.BLUE_HI
	if _row.get("color") is Color:
		tint = _row["color"]
	sub_label.add_theme_color_override(&"font_color", tint)
	link_box.visible = listed


func _on_pressed() -> void:
	if not listed or entry_id < 0:
		return
	pressed_row.emit(entry_id)
