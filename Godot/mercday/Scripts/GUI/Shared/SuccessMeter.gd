class_name SuccessMeter extends Control

#Twenty cell odds meter; the first filled_cells(odds) cells take the odds ramp colour. Stretched it
#drops its width minimum and spreads the twenty cells over whatever width the row hands it.

const CELL_SIZE_PX: Vector2 = Vector2(5, 8)
const GAP_PX: int = 1
const CELL_COUNT: int = 20
const EMPTY_COLOR: Color = Color("#1f3560")

@export var odds: int = 0:
	set(value):
		odds = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()
@export var stretch: bool = false:
	set(value):
		stretch = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	if stretch:
		custom_minimum_size = Vector2(0.0, CELL_SIZE_PX.y * pixel_scale)
	else:
		custom_minimum_size = Vector2(
			(CELL_COUNT * CELL_SIZE_PX.x + (CELL_COUNT - 1) * GAP_PX) * pixel_scale,
			CELL_SIZE_PX.y * pixel_scale)
	tooltip_text = "%d%%" % odds
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and stretch:
		queue_redraw()


func _draw() -> void:
	var filled: int = filled_cells(odds)
	var fill_color: Color = GuiTypes.odds_color(odds)
	var stride: float = (CELL_SIZE_PX.x + GAP_PX) * pixel_scale
	var cell_size: Vector2 = CELL_SIZE_PX * pixel_scale
	if stretch:
		stride = size.x / float(CELL_COUNT)
		cell_size = Vector2(maxf(1.0, stride - GAP_PX * pixel_scale),
			CELL_SIZE_PX.y * pixel_scale)
	for i: int in CELL_COUNT:
		var cell_color: Color = fill_color if i < filled else EMPTY_COLOR
		draw_rect(Rect2(i * stride, 0, cell_size.x, cell_size.y), cell_color)


static func filled_cells(odds_value: int) -> int:
	return clampi(roundi(float(odds_value) / 5.0), 0, CELL_COUNT)
