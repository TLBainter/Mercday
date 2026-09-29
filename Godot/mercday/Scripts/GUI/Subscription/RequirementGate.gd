class_name RequirementGate extends Control

#One requirement module sitting on a connector: how many of the prior tiers an upgrade still
#wants. The module is always reachable, so it keeps full opacity while the line out of it stays
#dim. A met requirement glows on the shared pulse.

const OUTLINE: float = 5.0
const INK: Color = Color("#0a0f1c")
const BOX: Color = Color("#15223d")
const RING_WIDTH: float = 2.0
const FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenBold.tres")
const FONT_SIZE: int = 11

@export var have: int = 0:
	set(value):
		have = value
		queue_redraw()
@export var need: int = 1:
	set(value):
		need = value
		queue_redraw()
@export var upgrade_id: String = ""

var _glow: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = TreeLayout.GATE_BOX
	size = TreeLayout.GATE_BOX
	PulseClock.pulse.connect(_on_pulse)


func setup(id: String, owned: int, wanted: int) -> void:
	upgrade_id = id
	need = maxi(1, wanted)
	have = clampi(owned, 0, need)


func fraction() -> float:
	if need <= 0:
		return 1.0
	return float(have) / float(need)


func is_met() -> bool:
	return have >= need


func gate_color() -> Color:
	return GuiColors.gate_color(fraction())


func text_value() -> String:
	return str(have) + "/" + str(need)


#Brightness of the whole module: flat until the requirement is met, then on the shared pulse.
func glow_factor() -> float:
	if not is_met():
		return 1.0
	return 1.0 + _glow * 0.8


func _on_pulse(g: float, _sweep: PackedFloat32Array) -> void:
	if not is_met():
		return
	_glow = g
	queue_redraw()


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, TreeLayout.GATE_BOX)
	draw_rect(box.grow(OUTLINE), INK)
	draw_rect(box, BOX)
	var ring: Color = _lit(gate_color())
	draw_rect(box, ring, false, RING_WIDTH)
	var text: String = text_value()
	var width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		FONT_SIZE).x
	var at: Vector2 = Vector2((TreeLayout.GATE_BOX.x - width) / 2.0,
		TreeLayout.GATE_BOX.y / 2.0 + float(FONT_SIZE) / 2.0 - 1.0)
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, ring)


func _lit(c: Color) -> Color:
	var k: float = glow_factor()
	return Color(minf(1.0, c.r * k), minf(1.0, c.g * k), minf(1.0, c.b * k), c.a)
