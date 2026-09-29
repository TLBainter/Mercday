class_name SortDirToggle extends Button

#The shared sort direction button (README I6): two stacked arrows, the live one lit and the other
#dim. Descending wears the orange fill, ascending the blue one, and each direction names itself in
#the tooltip. BaseButton already owns the name toggled, so the flip signal is direction_changed.

signal direction_changed(descending: bool)

const TOGGLE_SIZE: Vector2 = Vector2(40, 26)
const EDGE: Color = Color("#0a0f1c")
const EDGE_PX: int = 3
const BEVEL_PX: float = 2.0
#The stacked carets: 5x3 art px each at ARROW_SCALE, TRI_GAP screen px apart.
const ARROW_SCALE: int = 2
const TRI_GAP: float = 4.0
const HOVER_LIGHTEN: float = 0.15
const PRESSED_DARKEN: float = 0.2
#One row per direction: the fill, its bevel pair, the lit and dim arrow colours and the tooltip.
const LOOKS: Dictionary = {
	true: {"fill": Color("#f28c28"), "hi": Color("#ffb266"), "lo": Color("#b85a12"),
		"lit": Color("#0a0f1c"), "dim": Color("#7a4a1a"), "tip": "Highest to lowest"},
	false: {"fill": Color("#2b4f8a"), "hi": Color("#3b6fb6"), "lo": Color("#1f3560"),
		"lit": Color("#f3ead7"), "dim": Color("#5e7699"), "tip": "Lowest to highest"},
}

@export var descending: bool = true:
	set(value):
		descending = value
		_refresh()


func _ready() -> void:
	custom_minimum_size = TOGGLE_SIZE
	pressed.connect(toggle)
	_refresh()


func toggle() -> void:
	descending = not descending
	direction_changed.emit(descending)


#The colour row the current direction draws with.
func look() -> Dictionary:
	return LOOKS[descending] as Dictionary


func fill_color() -> Color:
	return look()["fill"] as Color


func _draw() -> void:
	var row: Dictionary = look()
	var inset: float = float(EDGE_PX)
	var wide: float = size.x - inset * 2.0
	draw_rect(Rect2(inset, inset, wide, BEVEL_PX), row["hi"] as Color)
	draw_rect(Rect2(inset, size.y - inset - BEVEL_PX, wide, BEVEL_PX), row["lo"] as Color)
	var art: Vector2 = Vector2(Icons.size("caret_up")) * float(ARROW_SCALE)
	var span: float = art.y * 2.0 + TRI_GAP
	var left: float = roundf((size.x - art.x) / 2.0)
	var top: float = roundf((size.y - span) / 2.0)
	var lit: Color = row["lit"] as Color
	var dim: Color = row["dim"] as Color
	Icons.draw(self, "caret_up", Vector2(left, top), ARROW_SCALE, dim if descending else lit, true)
	Icons.draw(self, "caret_down", Vector2(left, top + art.y + TRI_GAP), ARROW_SCALE,
		lit if descending else dim, true)


func _refresh() -> void:
	if not is_node_ready():
		return
	var row: Dictionary = look()
	var fill: Color = row["fill"] as Color
	add_theme_stylebox_override("normal", _box(fill))
	add_theme_stylebox_override("hover", _box(fill.lightened(HOVER_LIGHTEN)))
	add_theme_stylebox_override("pressed", _box(fill.darkened(PRESSED_DARKEN)))
	add_theme_stylebox_override("disabled", _box(fill.darkened(PRESSED_DARKEN)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tooltip_text = String(row["tip"])
	queue_redraw()


static func _box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_width_left = EDGE_PX
	box.border_width_top = EDGE_PX
	box.border_width_right = EDGE_PX
	box.border_width_bottom = EDGE_PX
	box.border_color = EDGE
	return box
