class_name VerdictBox extends Control

#The SUCCESS! or FAILURE slab. It slams in at the panel centre, holds, shrinks and flies to the
#dock slot above the title, where it stays. Hard shadows only: no rotation, no blur, no glow.

const SHADOW_OFFSET: Vector2 = Vector2(12.0, 12.0)
const RING_PX: float = 6.0
const INSET_COLOR_PX: float = 6.0
const INSET_DARK_PX: float = 10.0
const LETTER_SPACING: int = 4
const RING_COLOR: Color = Color("#0a0f1c")
const BOLD: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")

@onready var shadow: ColorRect = $Shadow
@onready var box: PanelContainer = $Box
@onready var text_label: Label = $Box/Text

var _color: Color = ResultsTimeline.SUCCESS
var _dark: Color = ResultsTimeline.SUCCESS_DARK


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spaced: FontVariation = BOLD.duplicate() as FontVariation
	spaced.spacing_glyph = LETTER_SPACING
	text_label.add_theme_font_override("font", spaced)
	box.draw.connect(_on_box_draw)
	visible = false
	fit()


func set_result(result: ContractResultData) -> void:
	_color = ResultsTimeline.verdict_color(result)
	_dark = ResultsTimeline.verdict_dark(result)
	text_label.text = ResultsTimeline.verdict_text(result)
	text_label.add_theme_color_override("font_color", _color)
	text_label.add_theme_color_override("font_shadow_color", _dark)
	fit()
	box.queue_redraw()


#The slab hangs free, so its size comes from the label whenever the text changes.
func fit() -> void:
	if not is_node_ready():
		return
	box.position = Vector2.ZERO
	box.size = box.get_combined_minimum_size()
	size = box.size
	pivot_offset = size / 2.0
	shadow.position = SHADOW_OFFSET
	shadow.size = box.size


#center and dock are in the coordinates of the parent; dock is the slot above the title.
func apply_time(t: float, center: Vector2, dock: Rect2) -> void:
	fit()
	var height: float = maxf(1.0, size.y)
	var dock_scale: float = dock.size.y / height
	var landing: Vector2 = Vector2(dock.position.x + size.x * dock_scale / 2.0,
			dock.get_center().y)
	var point: Vector2 = ResultsTimeline.verdict_position(t, center, landing)
	var factor: float = ResultsTimeline.verdict_scale(t, dock_scale)
	visible = t >= ResultsTimeline.VERDICT_IN
	modulate.a = ResultsTimeline.verdict_opacity(t)
	scale = Vector2(factor, factor)
	position = point - size / 2.0


func verdict_text() -> String:
	return text_label.text


func verdict_color() -> Color:
	return _color


func verdict_dark() -> Color:
	return _dark


func box_size() -> Vector2:
	return box.size


func _on_box_draw() -> void:
	var rect := Rect2(Vector2.ZERO, box.size)
	_ring(rect, RING_PX, RING_COLOR)
	_inset(rect, 0.0, INSET_COLOR_PX, _color)
	_inset(rect, INSET_COLOR_PX, INSET_DARK_PX - INSET_COLOR_PX, _dark)


#Four straight bands outside the box, the way the prototype stacks four offset shadows.
func _ring(rect: Rect2, thick: float, color: Color) -> void:
	box.draw_rect(Rect2(rect.position.x, rect.position.y - thick, rect.size.x, thick), color)
	box.draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, thick), color)
	box.draw_rect(Rect2(rect.position.x - thick, rect.position.y, thick, rect.size.y), color)
	box.draw_rect(Rect2(rect.end.x, rect.position.y, thick, rect.size.y), color)


func _inset(rect: Rect2, offset: float, thick: float, color: Color) -> void:
	var inner: Rect2 = rect.grow(-offset)
	box.draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, thick), color)
	box.draw_rect(Rect2(inner.position.x, inner.end.y - thick, inner.size.x, thick), color)
	box.draw_rect(Rect2(inner.position.x, inner.position.y, thick, inner.size.y), color)
	box.draw_rect(Rect2(inner.end.x - thick, inner.position.y, thick, inner.size.y), color)
