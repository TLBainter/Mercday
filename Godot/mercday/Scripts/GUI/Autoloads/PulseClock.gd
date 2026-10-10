extends Node

#One tick behind every glow in the GUI: no screen runs its own looping tween. One cycle is 1.6 s,
#rising over the first 14 percent, back to nothing by 50 percent, then flat until the cycle ends.
#A whole-item glow (a complete category icon, a met requirement module, a maxed tier icon) sets
#its brightness through glow_of. A left to right sweep (the chunks of a maxed tier bar) sets chunk
#i through sweep_of, so each chunk runs STEP seconds behind the one before it.
#One-shot effects (a reject shake, a tier up or down flash) stay one-off tweens.

signal pulse(g: float, sweep: PackedFloat32Array)

const CYCLE := 1.6
const STEP := 0.14
const CHUNKS := 8
#Cycle fractions: the rise ends at RISE, the fall ends at REST.
const RISE := 0.14
const FALL := REST - RISE
const REST := 0.5
const GLOW_GAIN := 0.8
const SWEEP_GAIN := 0.9

var g: float = 0.0
var sweep: PackedFloat32Array = PackedFloat32Array()
var running: bool = true

var _time: float = 0.0


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	if not running:
		return
	_time = fposmod(_time + delta, CYCLE)
	_publish()


#Where the clock stands in its cycle, 0 to 1.
func phase() -> float:
	return _time / CYCLE


#Test hook.
func set_running(on: bool) -> void:
	running = on


func reset() -> void:
	_time = 0.0
	_publish()


#Brightness of a whole-item glow at pulse value g.
func glow_of(value: float) -> float:
	return 1.0 + value * GLOW_GAIN


#Brightness of sweep chunk i; flat when no sweep has been published.
func sweep_of(values: PackedFloat32Array, i: int) -> float:
	if values.is_empty():
		return 1.0
	return 1.0 + values[i % values.size()] * SWEEP_GAIN


#The pulse shape at a cycle fraction. Held on the singleton so no caller reaches it statically.
func shape(x: float) -> float:
	if x < RISE:
		return x / RISE
	if x < REST:
		return 1.0 - (x - RISE) / FALL
	return 0.0


#[g, sweep 0 to 7] at a cycle fraction; chunk i trails chunk i minus one by STEP seconds.
func sample(at: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(CHUNKS + 1)
	out[0] = shape(fposmod(at, 1.0))
	for i: int in range(CHUNKS):
		out[i + 1] = shape(fposmod(at - float(i) * STEP / CYCLE, 1.0))
	return out


func _publish() -> void:
	var values: PackedFloat32Array = sample(phase())
	g = values[0]
	sweep = values.slice(1)
	pulse.emit(g, sweep)
