class_name HintMarkers extends Control

#The marker pool of a MercdaveLayer: one question mark HintMarker per mark of Mercdave, hidden until a
#mark needs it. Every shown marker glows in step: _process moves one phase and set_glow paints the halo
#alpha and the icon brightness.

signal marker_pressed(index: int)

const PULSE_PERIOD: float = 2.0

var buttons: Array[HintMarker] = []
var phase: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var first: HintMarker = get_child(0) as HintMarker
	first.pressed.connect(marker_pressed.emit.bind(0))
	buttons.append(first)


func ensure(count: int) -> void:
	while buttons.size() < count:
		var marker: HintMarker = HintMarker.new()
		marker.name = "Marker%d" % buttons.size()
		marker.visible = false
		marker.pressed.connect(marker_pressed.emit.bind(buttons.size()))
		buttons.append(marker)
		add_child(marker)


#Markers at the top left of their targets, hidden while a target is clipped; they ignore the pointer while a card is open.
func follow(layer: MercdaveLayer, on: bool) -> void:
	ensure(Mercdave.marks.size())
	for i: int in buttons.size():
		buttons[i].mouse_filter = MOUSE_FILTER_IGNORE if Mercdave.card_open else MOUSE_FILTER_STOP
		var box: Control = layer.control_for(Mercdave.marks[i]) if i < Mercdave.marks.size() else null
		buttons[i].visible = on and box != null and box.is_visible_in_tree() and HintScope.on_screen(box)
		if buttons[i].visible:
			buttons[i].global_position = box.get_global_rect().position + MercdaveLayer.MARK_OFFSET


static func glow_at(phase_value: float, period: float = PULSE_PERIOD) -> float:
	var half: float = period / 2.0
	return absf(fposmod(phase_value, period) - half) / half


func _process(delta: float) -> void:
	phase = fposmod(phase + delta, PULSE_PERIOD)
	for marker: HintMarker in buttons:
		if marker.visible:
			marker.set_glow(glow_at(phase))


func shown() -> int:
	return buttons.filter(func(marker: HintMarker) -> bool: return marker.visible).size()


func has_point(point: Vector2) -> bool:
	return buttons.any(func(m: HintMarker) -> bool: return m.visible and m.get_global_rect().has_point(point))
