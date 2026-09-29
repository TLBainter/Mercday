class_name NoteIcon extends Control

#The orange currency tile with the note glyph centered on it.

const TILE_COLOR: Color = Color("#f28c28")
const TILE_SIZE_PX: Vector2 = Vector2(9, 11)
const GLYPH_SIZE_PX: Vector2 = Vector2(5, 9)
const GLYPH_COLOR: Color = Color("#0a0f1c")

@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = tile_size(pixel_scale)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, tile_size(pixel_scale)), TILE_COLOR)
	Icons.draw(self, "note", Vector2(2, 1) * pixel_scale, pixel_scale, GLYPH_COLOR, true)


static func tile_size(scale_value: int) -> Vector2:
	return TILE_SIZE_PX * scale_value
