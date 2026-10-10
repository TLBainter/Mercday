class_name BevelEdges extends Control

#The inset bevel of a framed box: hi along the top and the left, lo along the bottom and the
#right, px wide, over the sides of the BEVEL_* mask. A ring of ring_px can wrap the outside.

@export var hi: Color = GuiColors.EDGE_HI:
	set(value):
		hi = value
		queue_redraw()
@export var lo: Color = GuiColors.EDGE_LO:
	set(value):
		lo = value
		queue_redraw()
@export var px: int = 4:
	set(value):
		px = value
		queue_redraw()
@export var sides: int = BevelButton.BEVEL_ALL:
	set(value):
		sides = value
		queue_redraw()
@export var ring: Color = GuiColors.CLEAR:
	set(value):
		ring = value
		queue_redraw()
@export var ring_px: int = 0:
	set(value):
		ring_px = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if ring_px > 0 and ring.a > 0.0:
		BevelButton.paint_ring(self, rect, ring, float(ring_px))
	BevelButton.paint_edges(self, rect, hi, lo, float(px), sides)
