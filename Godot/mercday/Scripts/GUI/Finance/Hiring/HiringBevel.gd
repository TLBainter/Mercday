class_name HiringBevel extends Control

#The two tone bevel of the Hiring buttons, badges and picks: the light edge along the top and the
#left, the dark edge along the bottom and the right. It fills its host and never takes the mouse.

@export var hi: Color = Color("#ffb266"):
	set(value):
		hi = value
		queue_redraw()
@export var lo: Color = Color("#b85a12"):
	set(value):
		lo = value
		queue_redraw()
@export var px: float = 2.0:
	set(value):
		px = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func set_colors(new_hi: Color, new_lo: Color) -> void:
	hi = new_hi
	lo = new_lo


#The bevel is the one BevelButton paints, so a Hiring edge and an action button shade alike.
func _draw() -> void:
	BevelButton.paint_edges(self, Rect2(Vector2.ZERO, size), hi, lo, px)
