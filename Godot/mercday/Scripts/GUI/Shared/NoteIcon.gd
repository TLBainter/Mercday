class_name NoteIcon extends Control

#The orange currency tile with the ink note glyph centered on it.

const TILE_COLOR: Color = Color("#f28c28")
const TILE_SIZE_PX: Vector2 = Vector2(9, 11)
const GLYPH_SIZE_PX: Vector2 = Vector2(7, 9)
const GLYPH: Texture2D = preload("res://Art/GUI/Icons/icon_note_currency.png")

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
	var box_size: Vector2 = tile_size(pixel_scale)
	draw_rect(Rect2(Vector2.ZERO, box_size), TILE_COLOR)
	var glyph_size: Vector2 = GLYPH_SIZE_PX * pixel_scale
	var origin: Vector2 = (box_size - glyph_size) / 2.0
	draw_texture_rect(GLYPH, Rect2(origin, glyph_size), false)


static func tile_size(scale_value: int) -> Vector2:
	return TILE_SIZE_PX * scale_value
