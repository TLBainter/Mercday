@tool
class_name PixelKitHelpers extends RefCounted

#JS kit part makers (ME:58, 155-159, 389-411) with the JS key order in js_keys, the kit row interpreter,
#lean and R2, and the VR draw source (ME:410, ME:938): null VR returns the constant 0.5 and is not counted.

const BOX_KEYS: Array[String] = ["kind", "x", "z", "y", "w", "d", "h", "tex", "tint"]
const PYR_KEYS: Array[String] = ["kind", "x", "z", "y", "w", "d", "h", "tint", "tex"]
const R2_KEYS: Array[String] = ["tilt", "pitch", "piv"]
const PISE_SUB: Rect2i = Rect2i(3, 3, 1, 1)
#Ruin tile makers tw, cc, mt, sc (ME:403-404): side texture, default tint, top texture.
const CYF: Dictionary = {
	"tw": ["tower_glass", "#7484ac", "tower_conc"], "cc": ["tower_conc", "#a09a94", "tower_conc"],
	"mt": ["metal_panel", "#8a8ea0", "metal_panel"], "sc": ["tower_scorch", "#6a5e66", "tower_scorch"],
}

static var _vr: MapRng = null
static var r_calls: int = 0


static func set_vr(rng: MapRng) -> void:
	_vr = rng
	r_calls = 0


static func vr() -> float:
	if _vr == null:
		return 0.5
	r_calls += 1
	return _vr.next()


static func vv(a: float, b: float) -> float:
	return a + (b - a) * vr()


#"" is pisePlain(), the pise_plain sub of pise_wall (ME:102).
static func tex(id: String) -> Dictionary:
	if id.is_empty():
		return {"id": &"pise_wall", "sub": &"pise_plain", "r": PISE_SUB}
	return {"id": StringName(id)}


static func _base(kind: StringName, x: float, z: float, y: float, w: float, d: float, h: float, tint: String,
		keys: Array[String]) -> PixelPart:
	var p: PixelPart = PixelPart.new()
	p.kind = kind
	p.x = x
	p.z = z
	p.y = y
	p.w = w
	p.d = d
	p.h = h
	p.tint_color = tint
	p.js_keys = PackedStringArray(keys)
	return p


static func tb(x: float, z: float, y: float, w: float, d: float, h: float, side: String, tint: String,
		top: String = "") -> PixelPart:
	var p: PixelPart = _base(&"box", x, z, y, w, d, h, tint, BOX_KEYS)
	p.tex = {"top": tex(top), "front": tex(side), "left": tex(side), "right": tex(side)}
	return p


static func py(x: float, z: float, y: float, w: float, d: float, h: float, t: String, tint: String,
		kind: StringName = &"pyr") -> PixelPart:
	var p: PixelPart = _base(kind, x, z, y, w, d, h, tint, PYR_KEYS)
	p.tex = {"s": tex(t), "n": tex(t), "l": tex(t), "r": tex(t)}
	return p


static func gb(x: float, z: float, y: float, w: float, d: float, h: float, t: String, tint: String) -> PixelPart:
	return py(x, z, y, w, d, h, t, tint, &"gable")


static func trk(x: float, z: float, h: float, w: float = 0.6, c: String = "#6e5032") -> PixelPart:
	return tb(x, z, 0.0, w, w, h, "bark_g", c, "bark_g")


static func can(x: float, z: float, y: float, w: float, d: float, h: float, c: String) -> PixelPart:
	return tb(x, z, y, w, d, h, "leaf_g_side", c, "leaf_g")


static func pyr(x: float, z: float, y: float, w: float, h: float, c: String) -> PixelPart:
	return py(x, z, y, w, w, h, "leaf_g_side", c)


static func rk(x: float, z: float, y: float, w: float, d: float, h: float, c: String) -> PixelPart:
	return tb(x, z, y, w, d, h, "rock_g", c, "rock_g")


static func cyf(maker: String, x: float, z: float, y: float, w: float, d: float, h: float, tint: String = "") -> PixelPart:
	var t: Array = CYF[maker]
	return tb(x, z, y, w, d, h, t[0], t[1] if tint.is_empty() else tint, t[2])


static func glow(x: float, z: float, y: float, s: float = 0.6) -> PixelPart:
	return py(x, z, y, s, s, s * 2.4, "rock_g", "#b070e0")


#One data row: [maker, numbers..., strings...] with the JS call's arguments in order.
static func make(r: Array) -> PixelPart:
	var n: Array[float] = []
	for v: Variant in r:
		if v is float or v is int:
			n.append(float(v))
	var maker: String = r[0]
	var s: String = r[r.size() - 1] if r[r.size() - 1] is String else ""
	match maker:
		"tb":
			return tb(n[0], n[1], n[2], n[3], n[4], n[5], r[7], r[8], r[9] if r.size() > 9 else "")
		"rk":
			return rk(n[0], n[1], n[2], n[3], n[4], n[5], s)
		"can":
			return can(n[0], n[1], n[2], n[3], n[4], n[5], s)
		"trk":
			return trk(n[0], n[1], n[2], n[3] if n.size() > 3 else 0.6, s if r.size() > 5 else "#6e5032")
		"py":
			return py(n[0], n[1], n[2], n[3], n[4], n[5], r[7], r[8])
		"gb":
			return gb(n[0], n[1], n[2], n[3], n[4], n[5], r[7], r[8])
		"pyr":
			return pyr(n[0], n[1], n[2], n[3], n[4], s)
		"glow":
			return glow(n[0], n[1], n[2], n[3] if n.size() > 3 else 0.6)
	return cyf(maker, n[0], n[1], n[2], n[3], n[4], n[5], s)


#ME:408 R2: rotate a group about piv; a box standing at the pivot height gets 2 units of foot.
static func r2(parts: Array[PixelPart], tilt: float, pitch: float, piv: Vector3) -> Array[PixelPart]:
	for p: PixelPart in parts:
		if p.kind == &"box" and absf(p.y - piv.y) < 0.01:
			p.y -= 2.0
			p.h += 2.0
		p.tilt = tilt
		p.pitch = pitch
		p.pivot = piv
		p.has_pivot = true
		for k: String in R2_KEYS:
			if not p.js_keys.has(k):
				p.js_keys.append(k)
	return parts


#ME:406 lean: segments stacked straight, then tilted as one body. Row ["lean", x, z, y, w, d, segs, sh, dx, dz, maker, tint].
static func lean(r: Array) -> Array[PixelPart]:
	var x: float = float(r[1])
	var z: float = float(r[2])
	var y: float = float(r[3])
	var sh: float = float(r[7])
	var out: Array[PixelPart] = []
	for k: int in int(r[6]):
		out.append(make([r[10], x, z, y + sh * k, r[4], r[5], sh, r[11]]))
	return r2(out, -atan2(float(r[8]) * 1.4, sh * 1.6), atan2(float(r[9]) * 1.4, sh * 1.6), Vector3(x, y, z))


static func expand(rows: Array) -> Array[PixelPart]:
	var out: Array[PixelPart] = []
	for r: Array in rows:
		if r[0] == "lean":
			out.append_array(lean(r))
		else:
			out.append(make(r))
	return out


static func model(w: float, d: float, parts: Array[PixelPart], dynamic: bool) -> PixelModel:
	var m: PixelModel = PixelModelStatic.new()
	if dynamic:
		m = PixelModelDynamic.new()
	m.W = w
	m.D = d
	m.parts = parts
	return m


#Kit table entry [W, D, rows].
static func from_rows(entry: Array, dynamic: bool) -> PixelModel:
	return model(float(entry[0]), float(entry[1]), expand(entry[2]), dynamic)
