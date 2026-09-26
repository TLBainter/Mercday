class_name DirToggle extends Button

#Ascending/descending flip button beside a sort dropdown. Both triangles stay drawn; the live
#direction reads dark on the orange descending fill and cream on the blue ascending fill.

signal direction_changed(descending: bool)

const TRI_WIDTH: float = 9.0
const TRI_HEIGHT: float = 5.0
const TRI_GAP: float = 5.0
const TRI_ROWS: int = 5
const DESC_UP: Color = Color("#7a4a1a")
const DESC_DOWN: Color = Color("#0a0f1c")
const ASC_UP: Color = Color("#f3ead7")
const ASC_DOWN: Color = Color("#5e7699")
const ORANGE_VARIATION: StringName = &"ButtonOrange"

@export var descending: bool = true:
	set(value):
		descending = value
		_refresh()


func _ready() -> void:
	pressed.connect(toggle)
	_refresh()


func toggle() -> void:
	descending = not descending
	direction_changed.emit(descending)


func _draw() -> void:
	var left: float = roundf((size.x - (TRI_WIDTH * 2.0 + TRI_GAP)) / 2.0)
	var top: float = roundf((size.y - TRI_HEIGHT) / 2.0)
	_triangle(Vector2(left, top), true, DESC_UP if descending else ASC_UP)
	_triangle(Vector2(left + TRI_WIDTH + TRI_GAP, top), false,
		DESC_DOWN if descending else ASC_DOWN)


#Stacked one-pixel rows keep the arrows crisp where a polygon would blur on the scaled canvas.
func _triangle(at: Vector2, up: bool, color: Color) -> void:
	for r: int in TRI_ROWS:
		var step: int = r if up else TRI_ROWS - 1 - r
		var wide: float = 1.0 + 2.0 * float(step)
		var x: float = at.x + (TRI_WIDTH - wide) / 2.0
		draw_rect(Rect2(x, at.y + float(r), wide, 1.0), color)


func _refresh() -> void:
	if not is_node_ready():
		return
	theme_type_variation = ORANGE_VARIATION if descending else &""
	tooltip_text = "Descending" if descending else "Ascending"
	queue_redraw()
