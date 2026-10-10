class_name HintFocus extends Control

#The focus of an open MercDave card: dims everything outside the gold box around the shown target. The box starts at
#START_SCALE times the target about its centre and eases onto it over DURATION while the dim fades in.

const DIM_ALPHA: float = 0.35
const START_SCALE: float = 1.5
const DURATION: float = 0.5
const RING_PX: int = MercdaveLayer.OUTLINE_PX

#Eased progress 0..1.
var level: float = 0.0

var _id: StringName = &""
var _t: float = 0.0
var _from: Rect2 = Rect2()
var _target: Rect2 = Rect2()

@onready var outline: Panel = $Outline


func _ready() -> void:
	set_process(false)


func follow(target: Rect2, id: StringName, on: bool) -> void:
	if not on:
		visible = false
		outline.visible = false
		_id = &""
		level = 0.0
		set_process(false)
		queue_redraw()
		return
	_target = target
	if id != _id:
		_id = id
		_t = 0.0
		var grown: Vector2 = target.size * START_SCALE
		_from = Rect2(target.get_center() - grown / 2.0, grown)
		visible = true
		outline.visible = true
		set_process(true)
	_apply()


func _process(delta: float) -> void:
	_t = minf(_t + delta, DURATION)
	_apply()
	if _t >= DURATION:
		set_process(false)


func _apply() -> void:
	var u: float = _t / DURATION
	level = 1.0 - pow(1.0 - u, 3.0)
	var rect: Rect2 = Rect2(_from.position.lerp(_target.position, level), _from.size.lerp(_target.size, level))
	var ring: Rect2 = rect.grow(RING_PX)
	outline.global_position = ring.position
	outline.size = ring.size
	queue_redraw()


func _draw() -> void:
	var hole: Rect2 = Rect2(outline.global_position - global_position, outline.size)
	var shade: Color = Color(0, 0, 0, DIM_ALPHA * level)
	var parts: Array[Rect2] = [Rect2(0, 0, size.x, hole.position.y),
		Rect2(0, hole.end.y, size.x, size.y - hole.end.y),
		Rect2(0, hole.position.y, hole.position.x, hole.size.y),
		Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y)]
	for part: Rect2 in parts:
		if part.size.x > 0.0 and part.size.y > 0.0:
			draw_rect(part, shade)


func ring_rect() -> Rect2:
	return outline.get_global_rect()


func dim_alpha() -> float:
	return DIM_ALPHA * level if visible else 0.0
