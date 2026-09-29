class_name FitStars extends Control

#Five atlas stars showing a fit value from 0.5 to 5.0 in half steps. cell is the integer atlas
#scale, so a star is 16 px at 1 and 32 px at 2. The lit colour comes from the whole value on the
#positive end of the star ramp; unused stars keep the same blue.

const UNLIT: Color = Icons.UNUSED_STAR

@export var value: float = 0.5:
	set(v):
		value = clampf(roundf(v * 2.0) / 2.0, 0.5, 5.0)
		if is_node_ready():
			queue_redraw()

@export var cell: int = 1:
	set(v):
		cell = maxi(1, v)
		if is_node_ready():
			update_minimum_size()
			queue_redraw()


static func color_of(value_in: float) -> Color:
	return Icons.star_color(clampf(roundf(value_in * 2.0) / 2.0, 0.5, 5.0), true)


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(Icons.stars_width(cell), Icons.CELL * cell)


func _draw() -> void:
	Icons.draw_stars(self, Vector2.ZERO, cell, value, true, UNLIT, Icons.STAR_GAP)
