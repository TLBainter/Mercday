@tool
class_name IceStacks extends RefCounted

#Sea ice box stacks per type (E46, MC:1294-1301); one entry per box [cx, cz, w, d, y0, h, ci] in emission order.

const WHITES: Array[Color] = [Color(0.97, 0.99, 1.0), Color(0.88, 0.94, 0.98), Color(0.76, 0.86, 0.93)]


static func boxes(ty: int, jx: int, jz: int, wy: float) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	var r1: float = _r(jx, jz, 1)
	var r2: float = _r(jx, jz, 2)
	var r3: float = _r(jx, jz, 3)
	if ty == 0:
		out.append(_box(jx, jz, 5.0 + r1 * 4.0, 3.0 + r2 * 3.0, wy, 0.9, 1))
	elif ty == 1:
		var w: float = 10.0 + r1 * 6.0
		var d: float = 7.0 + r2 * 4.0
		out.append(_box(jx, jz, w, d, wy, 2.0, 1))
		out.append(_box(jx + (r3 - 0.5) * w * 0.3, jz - d * 0.1, w * 0.5, d * 0.5, wy + 2.0, 1.2, 0))
	elif ty == 2:
		var n: int = 5 + floori(r1 * 3.0)
		for k: int in n:
			out.append(_box(jx + (k - n / 2.0) * 2.2, jz + (_r(jx, jz, k + 2) - 0.5) * 1.5, 2.4,
				2.0 + _r(jx, jz, k + 5) * 1.2, wy, 1.4 + _r(jx, jz, k + 9) * 2.0, 1 if k % 2 == 1 else 2))
	elif ty == 3:
		var h: float = 4.5 + r3 * 2.0
		out.append(_box(jx, jz, 8.0 + r1 * 3.0, 5.0 + r2 * 2.0, wy, h, 1))
		out.append(_box(jx - 0.5, jz - 0.3, 6.0, 3.5, wy + h, 0.4, 0))
	elif ty == 4:
		var n: int = 4 + floori(r1 * 3.0)
		for k: int in n:
			out.append(_box(jx + (_r(jx, jz, k + 2) - 0.5) * 9.0, jz + (_r(jx, jz, k + 7) - 0.5) * 7.0,
				1.6 + _r(jx, jz, k + 4) * 2.4, 1.2 + _r(jx, jz, k + 5) * 2.0, wy, 0.5 + _r(jx, jz, k + 6) * 0.6, 1))
	elif ty == 5:
		var y: float = wy
		var w: float = 4.0 + r1 * 1.5
		for k: int in 4:
			var h: float = 1.4 + _r(jx, jz, k + 2) * 1.2
			out.append(_box(jx + (_r(jx, jz, k + 5) - 0.5) * 0.8, jz, w, w * 0.8, y, h, 0 if k == 3 else 1))
			y += h
			w *= 0.68
	else:
		var sd: float = -1.0 if r3 < 0.5 else 1.0
		var l2: float = 12.0 + r1 * 4.0
		out.append(_box(jx, jz, l2, 1.8, wy, 2.4 + r2, 1))
		out.append(_box(jx + sd * l2 * 0.42, jz - 3.0, 1.8, 6.0, wy, 2.2 + _r(jx, jz, 4), 2))
		for k: int in 3:
			out.append(_box(jx + (_r(jx, jz, k + 6) - 0.5) * l2, jz + 1.6, 1.0, 0.9, wy, 0.6 + _r(jx, jz, k + 8) * 0.5, 0))
	return out


static func _r(jx: int, jz: int, k: int) -> float:
	return MapRng.hh(jx + k * 31, jz + k * 17)


static func _box(cx: float, cz: float, w: float, d: float, y0: float, h: float, ci: int) -> PackedFloat32Array:
	return PackedFloat32Array([cx, cz, w, d, y0, h, float(ci)])
