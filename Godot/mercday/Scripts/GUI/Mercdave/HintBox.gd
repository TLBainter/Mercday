class_name HintBox extends Control

#The amber box under the MercDave question mark, bevelled like a BevelButton face: light top and left edges,
#dark bottom and right ones painted last, so the top right and bottom left corners read dark.

const SIZE: Vector2 = Vector2(18, 18)
const EDGE: int = 2
const FILL: Color = GuiColors.AMBER
const HI: Color = Color("#ffd986")
const LO: Color = Color("#a67114")


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), FILL, true)
	draw_rect(Rect2(0, 0, SIZE.x, EDGE), HI, true)
	draw_rect(Rect2(0, 0, EDGE, SIZE.y), HI, true)
	draw_rect(Rect2(0, SIZE.y - EDGE, SIZE.x, EDGE), LO, true)
	draw_rect(Rect2(SIZE.x - EDGE, 0, EDGE, SIZE.y), LO, true)
