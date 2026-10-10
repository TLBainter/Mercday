@tool
class_name MapEase extends RefCounted

#Per-key eased values over a duration. Retargeting starts from the current value.
#Also holds the shared easing curves and SmoothDamp from the reference map-core.js.

enum EaseCurve { SMOOTH, SMOOTHER }

var _from: Dictionary = {}
var _to: Dictionary = {}
var _val: Dictionary = {}
var _t: Dictionary = {}
var _dur: Dictionary = {}
var _curve: Dictionary = {}
var _active: PackedInt32Array = PackedInt32Array()
var _changed: PackedInt32Array = PackedInt32Array()


static func smoothstep_q(q: float) -> float:
	return q * q * (3.0 - 2.0 * q)


static func smootherstep(q: float) -> float:
	return q * q * q * (q * (q * 6.0 - 15.0) + 10.0)


static func ease_in_out_cubic(q: float) -> float:
	if q < 0.5:
		return 4.0 * q * q * q
	return 1.0 - pow(-2.0 * q + 2.0, 3.0) / 2.0


static func smooth_damp(cur: float, to: float, vel: float, smooth: float, dt: float) -> Vector2:
	var w: float = 2.0 / maxf(smooth, 0.0001)
	var x: float = w * dt
	var e: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var ch: float = cur - to
	var tmp: float = (vel + w * ch) * dt
	return Vector2(to + (ch + tmp) * e, (vel - w * tmp) * e)


func target(key: int, to: float, ms: int, curve: int) -> void:
	var cur: float = value(key)
	if _t.has(key):
		if is_equal_approx(float(_to[key]), to):
			return
	elif is_equal_approx(cur, to):
		return
	_from[key] = cur
	_to[key] = to
	_val[key] = cur
	_dur[key] = maxf(float(ms) / 1000.0, 0.0001)
	_curve[key] = curve
	if not _t.has(key):
		_active.append(key)
	_t[key] = 0.0


func value(key: int) -> float:
	return float(_val.get(key, 0.0))


func advance(delta: float) -> PackedInt32Array:
	#Reuses member arrays so an idle or easing frame allocates nothing.
	_changed.resize(0)
	var i: int = _active.size() - 1
	while i >= 0:
		var key: int = _active[i]
		var dur: float = float(_dur[key])
		var t: float = minf(float(_t[key]) + delta, dur)
		var q: float = t / dur
		var k: float = smootherstep(q) if int(_curve[key]) == EaseCurve.SMOOTHER else smoothstep_q(q)
		var v: float = lerpf(float(_from[key]), float(_to[key]), k)
		if not is_equal_approx(v, float(_val[key])):
			_changed.append(key)
		if t >= dur:
			_val[key] = _to[key]
			_t.erase(key)
			_active.remove_at(i)
		else:
			_val[key] = v
			_t[key] = t
		i -= 1
	return _changed


func is_active() -> bool:
	return not _active.is_empty()
