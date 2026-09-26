class_name ContractImageBox extends Control

#The contract thumbnail: a flat fill under 45 degree stripes with an inset ring, used at 56 px in
#the roster row and at 150 px in the detail header. Whatever the scene hangs inside it (the status
#band, the caption) draws on top. When a contract image file exists it is drawn over the stripes.

const FILL: Color = Color("#0e1628")

@export var stripe_color: Color = Color("#1f3560"):
	set(value):
		stripe_color = value
		queue_redraw()
@export var cadence: int = 4:
	set(value):
		cadence = maxi(1, value)
		queue_redraw()
@export var ring_color: Color = Color("#3b6fb6"):
	set(value):
		ring_color = value
		queue_redraw()
@export var ring_px: int = 2:
	set(value):
		ring_px = maxi(0, value)
		queue_redraw()
@export var image_px: int = 48:
	set(value):
		image_px = maxi(1, value)
		queue_redraw()

var image_texture: Texture2D = null


func _ready() -> void:
	clip_contents = true
	texture_filter = TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	queue_redraw()


#The view carries a path today and no art ships yet, so anything that does not load keeps the stripes.
func set_image_path(path: String) -> void:
	var loaded: Texture2D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		loaded = load(path) as Texture2D
	image_texture = loaded
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), FILL)
	var offset: float = -h
	while offset < w:
		draw_line(Vector2(offset, 0.0), Vector2(offset + h, h), stripe_color, 1.0)
		offset += float(cadence)
	if image_texture != null:
		var side: float = float(image_px)
		draw_texture_rect(image_texture, Rect2((w - side) * 0.5, (h - side) * 0.5, side, side), false)
	if ring_px > 0:
		var half: float = float(ring_px) * 0.5
		draw_rect(Rect2(half, half, w - float(ring_px), h - float(ring_px)), ring_color, false,
			float(ring_px))
