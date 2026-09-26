class_name WeightBar extends PanelContainer

#Carry weight as one cell per unit of capacity; the filled cells turn red and the Encumbered flag
#shows once the load passes the limit.

const TRACK_COLOR: Color = Color("#1f3560")
const FILL_COLOR: Color = Color("#f28c28")
const FILL_HI_COLOR: Color = Color("#ffb266")
const OVER_COLOR: Color = Color("#e8583f")
const VALUE_TEXT: String = "%d / %d"
const GAP_PX: float = 2.0

@onready var cells: Control = $Row/Cells
@onready var value_label: Label = $Row/Value
@onready var flag_label: Label = $Row/Flag

@export var current_wt: float = 0.0:
	set(value):
		current_wt = value
		_refresh()
@export var capacity: float = 1.0:
	set(value):
		capacity = value
		_refresh()


func _ready() -> void:
	cells.draw.connect(_draw_cells)
	cells.resized.connect(_refresh)
	_refresh()


func cell_count() -> int:
	return maxi(1, ceili(capacity))


static func filled_cells(current: float, capacity_value: float) -> int:
	return clampi(roundi(current), 0, maxi(1, ceili(capacity_value)))


static func fraction(current_wt_value: float, capacity_value: float) -> float:
	if capacity_value <= 0.0:
		return 0.0
	return clampf(current_wt_value / capacity_value, 0.0, 1.0)


static func is_over(current_wt_value: float, capacity_value: float) -> bool:
	return current_wt_value > capacity_value


func _refresh() -> void:
	if not is_node_ready():
		return
	value_label.text = VALUE_TEXT % [roundi(current_wt), roundi(capacity)]
	flag_label.visible = is_over(current_wt, capacity)
	cells.queue_redraw()


func _draw_cells() -> void:
	var count: int = cell_count()
	var width: float = (cells.size.x - GAP_PX * float(count - 1)) / float(count)
	if width <= 0.0:
		return
	var filled: int = filled_cells(current_wt, capacity)
	var over: bool = is_over(current_wt, capacity)
	for i: int in count:
		var x: float = float(i) * (width + GAP_PX)
		var body: Color = TRACK_COLOR
		if i < filled:
			body = OVER_COLOR if over else FILL_COLOR
		cells.draw_rect(Rect2(x, 0.0, width, cells.size.y), body)
		if i < filled and not over:
			cells.draw_rect(Rect2(x, 0.0, width, 1.0), FILL_HI_COLOR)
