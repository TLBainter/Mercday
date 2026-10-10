@tool
class_name PixelPrimLathe extends PixelPrim

#Lathe (MC:1181-1186): prof [t, r] pairs swept over LATHE_SEGMENTS; shade l rides in COLOR with face code 0.

const TAU_JS: float = 6.2832
const L_MAX: float = 1.05


func emit(p: PixelPart, model_w: float, b: PixelMeshBuilder) -> void:
	setup(p, model_w, b)
	var tex: Dictionary = tex_of(p, "side")
	var tint: Color = tint_of(p, "side")
	var rect: Rect2i = b.rect_for(tex)
	var tw: float = float(rect.size.x)
	var th: float = float(rect.size.y)
	var segs: int = MapConst.LATHE_SEGMENTS
	var r0: float = p.w / 2.0
	for k: int in range(0, (p.prof.size() >> 1) - 1):
		var ta: float = p.prof[k * 2]
		var ra: float = p.prof[k * 2 + 1]
		var tb: float = p.prof[k * 2 + 2]
		var rb: float = p.prof[k * 2 + 3]
		var ya: float = wy(p.y + ta * p.h)
		var yb: float = wy(p.y + tb * p.h)
		for j: int in segs:
			var a0: float = TAU_JS * float(j) / float(segs)
			var a1: float = TAU_JS * float(j + 1) / float(segs)
			var am: float = (a0 + a1) / 2.0
			var cs: float = cos(am)
			var sn: float = sin(am)
			var l: float = (0.76 if cs > 0.0 else 0.96) * cs * cs + (0.95 if sn < 0.0 else 0.82) * sn * sn
			if rb < ra:
				l += 0.05 * (ra - rb) / maxf(0.01, tb - ta)
			l = minf(L_MAX, l)
			var pts: Array[Vector3] = quad4(_q(p, r0, rb, a0, yb), _q(p, r0, ra, a0, ya), _q(p, r0, rb, a1, yb),
				_q(p, r0, ra, a1, ya))
			var col: Color = Color(tint.r * l, tint.g * l, tint.b * l, tint.a)
			var uv0: Vector2 = Vector2(float(j) / float(segs) * tw, ta * th)
			b.emit_quad(pts, 0, rect, col, tw / float(segs), (tb - ta) * th, uv0)


func _q(p: PixelPart, r0: float, r: float, a: float, y: float) -> Vector3:
	return Vector3(wx(p.x + cos(a) * r * r0), y, wz(p.z + sin(a) * r * r0))
