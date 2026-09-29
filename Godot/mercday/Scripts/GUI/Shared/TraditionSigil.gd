class_name TraditionSigil extends Control

#The tradition sigil. A tradition with an atlas id draws its own colour art unmodulated; anything
#else falls back to the icon export, which is white art so modulate carries the tint.

const CREAM: Color = Color("#f3ead7")

@export var tradition: String = "":
	set(value):
		tradition = value
		_refresh()
@export var icon: Texture2D:
	set(value):
		icon = value
		_refresh()
@export var tint: Color = CREAM:
	set(value):
		tint = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = maxi(1, value)
		_refresh()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	tooltip_text = tradition
	custom_minimum_size = Vector2(Icons.CELL, Icons.CELL) * pixel_scale
	queue_redraw()


func sigil_id() -> String:
	return Icons.sigil_id(tradition)


func _draw() -> void:
	var box: Vector2 = Vector2(Icons.CELL, Icons.CELL) * pixel_scale
	var id: String = sigil_id()
	if id != "":
		Icons.draw(self, id, Vector2.ZERO, pixel_scale, Color.WHITE, false)
		return
	if icon == null:
		return
	var art: Vector2 = icon.get_size() * pixel_scale
	draw_texture_rect(icon, Rect2(((box - art) * 0.5).floor(), art), false, color())


func color() -> Color:
	return GuiTypes.tradition_color(tradition) if tradition != "" else tint
