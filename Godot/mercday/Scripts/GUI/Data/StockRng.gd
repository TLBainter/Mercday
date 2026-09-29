class_name StockRng extends RefCounted

#The PROTO rngM(seed) generator (mulberry32), ported step for step. Same 32 bit wrap as the
#MetricsHistory.Rng pattern, but the seed is used raw (PROTO: `let a = seed >>> 0`), not
#multiplied. No randf(), no randomize(), no global seed: every draw is a pure function of state.

var _state: int = 0


func _init(seed_value: int) -> void:
	_state = seed_value & 0xFFFFFFFF


func next() -> float:
	_state = (_state + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = _imul(_state ^ (_state >> 15), _state | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


#The shared gaussian-like step used by both the history build and advance_day: four draws.
func gauss() -> float:
	return (next() + next() + next() + next() - 2.0) * 1.73


static func _imul(x: int, y: int) -> int:
	var a: int = x & 0xFFFFFFFF
	var b: int = y & 0xFFFFFFFF
	return ((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16)) & 0xFFFFFFFF
