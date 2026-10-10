class_name ResourceBar extends VBoxContainer

#HP/EP/MP cell bar: a head row of the name and the reading over the cell track. The Cells control
#draws through its own draw signal since it is expand-filled.

const EMPTY_COLOR: Color = GuiColors.BLUE_LO
const TRACK_COLOR: Color = GuiColors.INK
const CELL_HEIGHT_PX: int = 4
const MIN_CELL_WIDTH: int = 2
const GAP_PX: int = 1
const TRACK_HEIGHT: int = 16
const TRACK_INSET: float = 2.0
const CELL_GAP: float = 2.0

@onready var name_label: Label = $Head/Name
@onready var value_label: Label = $Head/Value
@onready var cells: Control = $Cells

@export var label: String = "":
	set(value):
		label = value
		_refresh()
@export var current: int = 0:
	set(value):
		current = value
		_refresh()
@export var max_value: int = 1:
	set(value):
		max_value = value
		_refresh()
@export var fill_color: Color = Color("#d6453d"):
	set(value):
		fill_color = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	cells.draw.connect(_draw_cells)
	cells.resized.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	name_label.text = label
	name_label.add_theme_color_override("font_color", fill_color)
	value_label.text = "%d/%d" % [current, max_value]
	cells.custom_minimum_size.y = TRACK_HEIGHT
	cells.queue_redraw()


#The track is the ink plate; the cells sit inside a 2 px inset with a 2 px gap between them. The
#width comes from the pinned static, fed the room the gaps leave; the pixels that width leaves
#over go one each to the leading cells, so the last cell ends on the inset instead of short of it.
func _draw_cells() -> void:
	cells.draw_rect(Rect2(0.0, 0.0, cells.size.x, cells.size.y), TRACK_COLOR)
	if max_value < 1:
		return
	var inner: float = cells.size.x - TRACK_INSET * 2.0
	var cell_room: float = inner - CELL_GAP * float(max_value - 1)
	var width: int = cell_width(cell_room + float(max_value - 1), max_value)
	var extra: int = maxi(0, floori(cell_room) - width * max_value)
	var height: float = maxf(0.0, cells.size.y - TRACK_INSET * 2.0)
	var colors: PackedColorArray = CellBar.split(max_value, filled(current, max_value),
		fill_color, EMPTY_COLOR)
	var x: float = TRACK_INSET
	for i: int in max_value:
		var cell_w: float = float(width + (1 if i < extra else 0))
		cells.draw_rect(Rect2(x, TRACK_INSET, cell_w, height), colors[i])
		x += cell_w + CELL_GAP


static func cell_width(available: float, count: int) -> int:
	if count < 1:
		return 0
	var gaps: int = count - 1
	var raw: int = floori((available - gaps) / float(count))
	return maxi(MIN_CELL_WIDTH, raw)


static func filled(current_value: int, max_value_arg: int) -> int:
	return clampi(current_value, 0, maxi(0, max_value_arg))
