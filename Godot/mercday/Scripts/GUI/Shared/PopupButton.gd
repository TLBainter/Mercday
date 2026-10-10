class_name PopupButton extends BevelButton

#A button that drops its DropPanel child Menu under itself when pressed. The popup is as wide as
#the widest of popup_width, the button and the rows; popup_align_right lines up the right edges.
#The button counts as active while its menu is open.

@export var popup_width: int = 0
@export var popup_align_right: bool = false

@onready var menu: DropPanel = $Menu


func _ready() -> void:
	super()
	pressed.connect(open_popup)
	menu.visibility_changed.connect(queue_redraw)


func open_popup() -> void:
	_fill_popup()
	menu.popup(place_below(self, _popup_size(), popup_align_right), self)


func close_popup() -> void:
	menu.hide()


func popup_open() -> bool:
	return is_node_ready() and menu.visible


func fx_active() -> bool:
	return super() or popup_open()


#The padded, click-through line a popup row lays its parts in; it fills the row.
static func row_line(row: Control) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Line"
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 6.0
	line.offset_right = -6.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	return line


static func place_below(anchor: Control, wanted: Vector2, align_right: bool = false) -> Rect2i:
	return place_below_rect(anchor.get_global_rect(), wanted, align_right)


#The popup rect of size wanted right under rect, left edges lined up or, with align_right, right edges.
static func place_below_rect(rect: Rect2, wanted: Vector2, align_right: bool = false) -> Rect2i:
	var width: int = int(wanted.x)
	var x: int = int(rect.end.x) - width if align_right else int(rect.position.x)
	return Rect2i(Vector2i(x, int(rect.end.y)), Vector2i(width, int(wanted.y)))


#Rebuilds the rows right before the popup shows; rows kept current elsewhere need nothing here.
func _fill_popup() -> void:
	pass


func _popup_size() -> Vector2:
	var wanted: Vector2 = menu.get_combined_minimum_size()
	return Vector2(maxi(popup_width, maxi(int(get_global_rect().size.x), int(wanted.x))), wanted.y)
