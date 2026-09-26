class_name ScanlineOverlay extends Control

#CRT scanlines over the HUD and every SubWindow: a line_px high white line at line_alpha every
#period_px down the whole rect. Mouse transparent, so it never eats a click.

@export var line_alpha: float = 0.025:
	set(value):
		line_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()
@export var period_px: int = 4:
	set(value):
		period_px = maxi(1, value)
		queue_redraw()
@export var line_px: int = 2:
	set(value):
		line_px = maxi(1, value)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var tint := Color(1.0, 1.0, 1.0, line_alpha)
	var height: float = float(line_px)
	var y: float = 0.0
	while y < size.y:
		draw_rect(Rect2(0.0, y, size.x, minf(height, size.y - y)), tint)
		y += float(period_px)
