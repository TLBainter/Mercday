class_name SlotChip extends PanelContainer

#One lifepath, knowledge or tool slot. A filled chip carries the name and opens the shared
#SlotTooltip on hover; an empty chip reads "Empty" in the faint blue and never opens a tooltip.

const EMPTY_TEXT: String = "Empty"
const EMPTY_COLOR: Color = GuiColors.MUTED
const FILLED_COLOR: Color = GuiColors.CREAM
const EMPTY_FILL: Color = GuiColors.ROW_FILL
const EMPTY_EDGE: Color = GuiColors.BLUE_LO
const FILLED_FILL: Color = GuiColors.BLUE
const BEVEL_HI: Color = GuiColors.BLUE_HI
const BEVEL_LO: Color = GuiColors.BLUE_LO
const BEVEL_PX: float = 3.0

@export var kind: String = "":
	set(value):
		kind = value
		_refresh()
@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var description: String = "":
	set(value):
		description = value
		_refresh()

@onready var name_label: Label = $Name


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_refresh()


func set_slot(new_kind: String, new_label: String, new_description: String) -> void:
	kind = new_kind
	label = new_label
	description = new_description


func set_empty(new_kind: String) -> void:
	set_slot(new_kind, "", "")


func is_filled() -> bool:
	return label != ""


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = label if is_filled() else EMPTY_TEXT
	name_label.add_theme_color_override("font_color", FILLED_COLOR if is_filled() else EMPTY_COLOR)
	tooltip_text = ""
	add_theme_stylebox_override("panel", filled_box() if is_filled() else empty_box())
	queue_redraw()


#A filled chip carries the prototype's raised bevel; a stylebox cannot draw one, so it is painted.
func _draw() -> void:
	if not is_filled():
		return
	BevelButton.paint_edges(self, Rect2(Vector2.ZERO, size), BEVEL_HI, BEVEL_LO, BEVEL_PX,
		BevelButton.BEVEL_TOP | BevelButton.BEVEL_BOTTOM)


static func empty_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = _chip_box(EMPTY_FILL)
	box.set_border_width_all(2)
	box.border_color = EMPTY_EDGE
	return box


static func filled_box() -> StyleBoxFlat:
	return _chip_box(FILLED_FILL)


static func _chip_box(fill: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = GuiStyle.flat(fill, 0, GuiColors.CLEAR, 0.0)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	return box
