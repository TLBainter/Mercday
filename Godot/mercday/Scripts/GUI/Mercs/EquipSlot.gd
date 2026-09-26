class_name EquipSlot extends PanelContainer

#One equipment cell: the hatched icon box beside the slot caption over the item name. A container
#slot carries the blue bottom edge the Containers column uses.

const EMPTY_TEXT: String = "Empty"
const EMPTY_COLOR: Color = Color("#5e7699")
const FILLED_COLOR: Color = Color("#f3ead7")
const CARRIED_CAPTION: String = "Carried"
const PANEL_FILL: Color = Color("#0e1628")
const EDGE_COLOR: Color = Color("#2b4f8a")
const EDGE_PX: int = 3
const ICON_FILL: Color = Color("#1f3560")
const ICON_RING: Color = Color("#3b6fb6")
const EMPTY_FILL: Color = Color("#0a0f1c")
const EMPTY_RING: Color = Color("#1f3560")
const HATCH_COLOR: Color = Color("#2b4f8a")
const HATCH_ALPHA: float = 0.5
const HATCH_STEP: float = 4.0
const RING_PX: float = 2.0

@export var caption: String = "":
	set(value):
		caption = value
		_refresh()
@export var item_name: String = "":
	set(value):
		item_name = value
		_refresh()
@export var container: bool = false:
	set(value):
		container = value
		_refresh()

@onready var icon_box: Control = $Row/IconBox
@onready var caption_label: Label = $Row/Lines/Caption
@onready var item_label: Label = $Row/Lines/Item


func _ready() -> void:
	icon_box.draw.connect(_draw_icon)
	_refresh()


func set_slot(new_slot: String, new_item: String) -> void:
	caption = new_slot
	item_name = new_item


func is_filled() -> bool:
	return item_name != ""


func caption_text() -> String:
	return caption_label.text if is_node_ready() else caption.to_upper()


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption.to_upper()
	item_label.text = item_name if is_filled() else EMPTY_TEXT
	item_label.add_theme_color_override("font_color", FILLED_COLOR if is_filled() else EMPTY_COLOR)
	add_theme_stylebox_override(&"panel", slot_box(container))
	icon_box.queue_redraw()


static func slot_box(with_edge: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_FILL
	box.border_color = EDGE_COLOR
	box.border_width_bottom = EDGE_PX if with_edge else 0
	box.content_margin_left = 8.0
	box.content_margin_top = 6.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 6.0
	return box


#The placeholder art box: a flat fill, diagonal hatching over it and a ring on the inside edge.
static func draw_hatch_box(target: Control, fill: Color, ring: Color) -> void:
	var box := Rect2(Vector2.ZERO, target.size)
	target.draw_rect(box, fill)
	var hatch := Color(HATCH_COLOR, HATCH_ALPHA)
	var x: float = -box.size.y
	while x < box.size.x:
		target.draw_line(Vector2(x, box.size.y), Vector2(x + box.size.y, 0.0), hatch, 1.0)
		x += HATCH_STEP
	var inner := Rect2(Vector2(RING_PX * 0.5, RING_PX * 0.5), box.size - Vector2.ONE * RING_PX)
	target.draw_rect(inner, ring, false, RING_PX)


func _draw_icon() -> void:
	draw_hatch_box(icon_box, ICON_FILL if is_filled() else EMPTY_FILL,
		ICON_RING if is_filled() else EMPTY_RING)
