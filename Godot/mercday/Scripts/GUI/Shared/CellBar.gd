class_name CellBar extends Control

#A row of filled/empty cells, drawn flat: the expense breakdown bar and any other N-of-M meter
#that is not the 20 cell odds ramp SuccessMeter already owns. mouse_filter IGNORE, display only.

@export var cells: int = 20:
	set(value):
		cells = maxi(1, value)
		filled = clampi(filled, 0, cells)
		_refresh()
@export var filled: int = 0:
	set(value):
		filled = clampi(value, 0, cells)
		queue_redraw()
@export var fill_color: Color = GuiColors.ORANGE:
	set(value):
		fill_color = value
		queue_redraw()
@export var empty_color: Color = GuiColors.BLUE_LO:
	set(value):
		empty_color = value
		queue_redraw()
@export var cell_height: int = 12:
	set(value):
		cell_height = maxi(1, value)
		_refresh()
@export var gap: int = 2:
	set(value):
		gap = maxi(0, value)
		_refresh()
@export var cell_width: int = 0:
	set(value):
		cell_width = maxi(0, value)
		_refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _refresh() -> void:
	if not is_node_ready():
		return
	if cell_width > 0:
		custom_minimum_size = Vector2(float(cells * cell_width + maxi(0, cells - 1) * gap),
			float(cell_height))
	else:
		custom_minimum_size = Vector2(0.0, float(cell_height))
	queue_redraw()


func _draw() -> void:
	var width: float = float(cell_width) if cell_width > 0 else _even_width()
	paint(self, Vector2.ZERO, Vector2(width, float(cell_height)), width + float(gap),
		split(cells, filled, fill_color, empty_color))


func _even_width() -> float:
	if cells <= 0:
		return 0.0
	return maxf(1.0, (size.x - float(gap) * float(cells - 1)) / float(cells))


func set_ratio(value: float) -> void:
	filled = clampi(roundi(value * float(cells)), 0, cells)


func ratio() -> float:
	if cells <= 0:
		return 0.0
	return float(filled) / float(cells)


static func cells_for(value: float, total: int) -> int:
	return clampi(roundi(value * float(total)), 0, total)


#Paints one cell per colour, left to right from origin, each cell sized cell and stride apart. A
#plate under the row or a trim over it stays with the caller.
static func paint(canvas: CanvasItem, origin: Vector2, cell: Vector2, stride: float,
		colors: PackedColorArray) -> void:
	for i: int in colors.size():
		canvas.draw_rect(Rect2(origin.x + float(i) * stride, origin.y, cell.x, cell.y), colors[i])


#The colours of count cells: the first lit take fill and the rest take empty.
static func split(count: int, lit: int, fill: Color, empty: Color) -> PackedColorArray:
	var out := PackedColorArray()
	for i: int in count:
		out.append(fill if i < lit else empty)
	return out
