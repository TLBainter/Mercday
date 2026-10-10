class_name MercCount extends Control

#Five merc silhouettes: required orange, up to allowed cream, the rest a hollow blue outline.

const SIL_SIZE_PX: Vector2 = Vector2(14, 14)
const GAP_PX: int = 2
const COUNT: int = 5
const HOLLOW_COLOR: Color = GuiColors.BLUE_HI

@export var required: int = 1:
	set(value):
		required = value
		_refresh()
@export var allowed: int = 1:
	set(value):
		allowed = value
		_refresh()
@export var pixel_scale: int = 2:
	set(value):
		pixel_scale = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	custom_minimum_size = Vector2((COUNT * SIL_SIZE_PX.x + (COUNT - 1) * GAP_PX) * pixel_scale,
		SIL_SIZE_PX.y * pixel_scale)
	var noun: String = "merc" if allowed == 1 else "mercs"
	tooltip_text = "Requires %d, up to %d %s" % [required, allowed, noun]
	queue_redraw()


func _draw() -> void:
	var stride: float = (SIL_SIZE_PX.x + GAP_PX) * pixel_scale
	for i: int in COUNT:
		var id: String = "person" if i < allowed else "person_outline"
		Icons.draw(self, id, Vector2(i * stride, 0.0), pixel_scale, color_at(i, required, allowed),
			true)


static func color_at(i: int, required_value: int, allowed_value: int) -> Color:
	if i < required_value:
		return GuiColors.ORANGE
	if i < allowed_value:
		return GuiColors.CREAM
	return HOLLOW_COLOR
