class_name TraditionSigil extends Control

#The tradition sword sigil; the icon is white so modulate carries the tradition or fallback tint.

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
		pixel_scale = value
		_refresh()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	tooltip_text = tradition
	if icon != null:
		custom_minimum_size = icon.get_size() * pixel_scale
	queue_redraw()


func _draw() -> void:
	if icon == null:
		return
	draw_texture_rect(icon, Rect2(Vector2.ZERO, icon.get_size() * pixel_scale), false, color())


func color() -> Color:
	return GuiTypes.tradition_color(tradition) if tradition != "" else tint
