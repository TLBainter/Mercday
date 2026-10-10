@tool
class_name PixelKitRuins extends RefCounted

#Cyfrolaef ruin kits cy_b01..cy_b26 and cy_s01..cy_s15 (ME:534-561, ME:640-654), parts in JS push order.

const M: int = 0xFFFFFFFF
const IDS: PackedStringArray = [
	"cy_b01", "cy_b02", "cy_b03", "cy_b04", "cy_b05", "cy_b06", "cy_b07", "cy_b08", "cy_b09", "cy_b10", "cy_b11",
	"cy_b12", "cy_b13", "cy_b14", "cy_b15", "cy_b16", "cy_b17", "cy_b18", "cy_b19", "cy_b20", "cy_b21", "cy_b22",
	"cy_b23", "cy_b24", "cy_b25", "cy_b26", "cy_s01", "cy_s02", "cy_s03", "cy_s04", "cy_s05", "cy_s06", "cy_s07",
	"cy_s08", "cy_s09", "cy_s10", "cy_s11", "cy_s12", "cy_s13", "cy_s14", "cy_s15"]
const BOX_KEYS: PackedStringArray = ["kind", "x", "z", "y", "w", "d", "h", "tex", "tint"]
const PYR_KEYS: PackedStringArray = ["kind", "x", "z", "y", "w", "d", "h", "tint", "tex"]


#ME:16 with JS double math and ToInt32 wraps.
static func n(x: int, y: int) -> float:
	var u: int = int(fposmod(float(x) * 374761393.0 + float(y) * 668265263.0, 4294967296.0))
	u = (u ^ (u >> 13)) & M
	var hs: int = u - 4294967296 if u >= 2147483648 else u
	var m: int = int(fposmod(float(hs) * 1274126177.0, 4294967296.0))
	return float((m ^ (m >> 16)) & M) / 4294967296.0


static func build_raw(id: StringName) -> PixelModel:
	return _make(id, false)


static func build(id: StringName) -> PixelModel:
	return _make(id, String(id).begins_with("cy_b"))


static func _make(id: StringName, settle: bool) -> PixelModel:
	var src: Array = _kit(id)
	if src.is_empty():
		push_error("PixelKitRuins: unknown id " + String(id))
		return null
	var m: PixelModelStatic = PixelModelStatic.new()
	m.id = id
	m.W = float(src[0])
	m.D = float(src[1])
	var parts: Array[PixelPart] = _cat(src[2])
	if settle:
		parts = PixelKitRuinsOverlap.de_overlap(parts)
	m.set_parts(parts)
	return m


static func r2(parts: Array[PixelPart], tilt: float, pitch: float, piv: Vector3) -> Array[PixelPart]:
	var out: Array[PixelPart] = []
	for p: PixelPart in parts:
		var q: PixelPart = p.duplicate() as PixelPart
		if q.kind == &"box" and absf(q.y - piv.y) < 0.01:
			q.y -= 2.0
			q.h += 2.0
		q.tilt = tilt
		q.pitch = pitch
		q.pivot = piv
		q.has_pivot = true
		_keys(q, ["tilt", "pitch", "piv"])
		out.append(q)
	return out


static func jag(x: float, z: float, y: float, w: float, d: float, cx: int, cz: int, hm: float, f: Callable,
		sd: int) -> Array[PixelPart]:
	var out: Array[PixelPart] = []
	for i: int in cx:
		for k: int in cz:
			var h: float = hm * n(sd + i * 7, k * 5 + sd)
			if h < hm * 0.25:
				continue
			out.append(f.call(x - w / 2 + (i + 0.5) * w / cx, z - d / 2 + (k + 0.5) * d / cz, y, w / cx, d / cz, h))
	return out


static func deb(x: float, z: float, cnt: int, sp: float, sd: int) -> Array[PixelPart]:
	var out: Array[PixelPart] = []
	for k: int in cnt:
		out.append(_rk(x + (n(sd + k, 3) - 0.5) * sp, z + (n(sd, k + 9) - 0.5) * sp * 0.6, 0,
			0.8 + n(k, sd) * 1.4, 0.7 + n(sd + 2, k) * 1.1, 0.4 + n(k + 4, sd) * 0.9,
			"#8a8480" if k % 3 != 0 else "#6a6460"))
	return out


static func lean(x: float, z: float, y: float, w: float, d: float, segs: int, sh: float, dx: float, dz: float,
		f: Callable) -> Array[PixelPart]:
	var parts: Array[PixelPart] = []
	for k: int in segs:
		parts.append(f.call(x, z, y + sh * k, w, d, sh))
	return r2(parts, -atan2(dx * 1.4, sh * 1.6), atan2(dz * 1.4, sh * 1.6), Vector3(x, y, z))


#MC:601-605 extOf: model-unit rect [x0, x1, z0, z1] over every tilted part, plus "tilted".
static func ext_of(m: PixelModel) -> Dictionary:
	var kx: float = PixelKitRuinsOverlap.K
	var ky: float = PixelKitRuinsOverlap.KY
	var r: Array[float] = [0.0, m.W, 0.0, m.D]
	var tl: bool = false
	for p: PixelPart in m.parts:
		if p.tilt == 0.0 and p.pitch == 0.0:
			continue
		tl = true
		var pv: Vector3 = p.pivot if p.has_pivot else Vector3(p.x, p.y, p.z)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				for yy: float in [p.y, p.y + p.h]:
					var dx: float = (p.x + sx * p.w / 2 - pv.x) * kx
					var dy: float = (yy - pv.y) * ky
					var dz: float = -(p.z + sz * p.d / 2 - pv.z) * kx
					if p.tilt != 0.0:
						var nx: float = dx * cos(p.tilt) - dy * sin(p.tilt)
						dy = dx * sin(p.tilt) + dy * cos(p.tilt)
						dx = nx
					if p.pitch != 0.0:
						var nz: float = dz * cos(p.pitch) - dy * sin(p.pitch)
						dy = dz * sin(p.pitch) + dy * cos(p.pitch)
						dz = nz
					var px: float = pv.x + dx / kx
					var pz: float = pv.z - dz / kx
					r = [minf(r[0], px), maxf(r[1], px), minf(r[2], pz), maxf(r[3], pz)]
	return {"rect": r, "tilted": tl}


static func _keys(p: PixelPart, names: Array[String]) -> void:
	var ks: PackedStringArray = p.js_keys.duplicate()
	for k: String in names:
		if not ks.has(k):
			ks.append(k)
	p.js_keys = ks


static func _cat(items: Array) -> Array[PixelPart]:
	var out: Array[PixelPart] = []
	for it: Variant in items:
		if it is PixelPart:
			out.append(it)
		else:
			out.append_array(_cat(it))
	return out


static func _part(kind: StringName, x: float, z: float, y: float, w: float, d: float, h: float, tint: String,
		tex: Dictionary, keys: PackedStringArray) -> PixelPart:
	var p: PixelPart = PixelPart.new()
	p.kind = kind
	var v: Array[float] = [x, z, y, w, d, h]
	for i: int in 6:
		p.set(PixelPart.FLOATS[i], v[i])
	p.tint_color = tint
	p.tex = tex
	p.js_keys = keys.duplicate()
	return p


static func _tb(x: float, z: float, y: float, w: float, d: float, h: float, side: StringName, tint: String,
		top: StringName) -> PixelPart:
	var tex: Dictionary = {"top": {"id": top}, "front": {"id": side}, "left": {"id": side}, "right": {"id": side}}
	return _part(&"box", x, z, y, w, d, h, tint, tex, BOX_KEYS)


static func _py(x: float, z: float, y: float, w: float, d: float, h: float, t: StringName, tint: String) -> PixelPart:
	var tex: Dictionary = {"s": {"id": t}, "n": {"id": t}, "l": {"id": t}, "r": {"id": t}}
	return _part(&"pyr", x, z, y, w, d, h, tint, tex, PYR_KEYS)


static func _tw(x: float, z: float, y: float, w: float, d: float, h: float, t: String = "#7484ac") -> PixelPart:
	return _tb(x, z, y, w, d, h, &"tower_glass", t, &"tower_conc")


static func _cc(x: float, z: float, y: float, w: float, d: float, h: float, t: String = "#a09a94") -> PixelPart:
	return _tb(x, z, y, w, d, h, &"tower_conc", t, &"tower_conc")


static func _mt(x: float, z: float, y: float, w: float, d: float, h: float, t: String = "#8a8ea0") -> PixelPart:
	return _tb(x, z, y, w, d, h, &"metal_panel", t, &"metal_panel")


static func _sc(x: float, z: float, y: float, w: float, d: float, h: float, t: String = "#6a5e66") -> PixelPart:
	return _tb(x, z, y, w, d, h, &"tower_scorch", t, &"tower_scorch")


static func _rk(x: float, z: float, y: float, w: float, d: float, h: float, c: String) -> PixelPart:
	return _tb(x, z, y, w, d, h, &"rock_g", c, &"rock_g")


static func _glow(x: float, z: float, y: float, s: float = 0.6) -> PixelPart:
	return _py(x, z, y, s, s, s * 2.4, &"rock_g", "#b070e0")


static func _r2(items: Array, tilt: float, pitch: float, px: float, py: float, pz: float) -> Array[PixelPart]:
	return r2(_cat(items), tilt, pitch, Vector3(px, py, pz))


static func _loop(id: StringName) -> Array[PixelPart]:
	var out: Array[PixelPart] = []
	match id:
		&"cy_b06":
			for k: int in 6:
				out.append(_mt(8, 1.5 + k * 1.8, k * 1.1, 14 - absf(k - 2.5) * 2.4, 1.8, 1.2, "#9aa0b4"))
		&"cy_b07":
			for k: int in 7:
				out.append(_mt(1.5 + k * 2.1, 3.5, k * 0.9, 2.2, 4.6 - k * 0.25, 2.6))
		&"cy_b09":
			for i: int in 3:
				for k: int in 3:
					out.append(_mt(1.5 + i * 3.5, 1.5 + k * 3.5, 0, 0.6, 0.6, maxf(2, 12 - (i + k) * 1.6), "#8a6a5a"))
		&"cy_b10":
			for k: int in [0, 1, 2, 3, 5, 6]:
				out.append(_cc(6 + cos(k * PI / 4) * 4.4, 6 + sin(k * PI / 4) * 4.4, 1.5, 2.2, 2.2, 2 + n(k, 101) * 4))
		&"cy_b19":
			for k: int in 5:
				out.append(_mt(8, 1.4 + k * 2.3, 7 + k * 0.6, 13, 2.3, 0.8, "#9aa0b4"))
		&"cy_b24":
			for k: int in 6:
				var p: PixelPart = _tw(4, 4, 1.5 + k * 3, 4.5, 4.5, 3)
				p.tilt = -0.07 * k * (k + 1) / 2
				p.pivot = Vector3(4, 1.5 + k * 3, 4)
				p.has_pivot = true
				_keys(p, ["tilt", "piv"])
				out.append(p)
		&"cy_s09":
			for k: int in 4:
				out.append(_cc(0.8 + k * 1.5, 1, 0, 1.2, 0.8, 0.5 if k == 2 else 0.9, "#c8b040" if (k & 1) == 1 else "#b0aca4"))
	return out


#[W, D, items]; items nest and are flattened by _cat.
static func _kit(id: StringName) -> Array:
	match id:
		&"cy_b01": return [10, 9, [_r2([_tw(5, 5, 0, 6, 6, 18), jag(5, 5, 18, 6, 6, 3, 3, 5, _tw, 11)], 0.22, 0, 5, 0, 5), _tw(7.5,
			1.5, 0, 5, 2, 2), deb(5, 1.2, 5, 8, 1)]]
		&"cy_b02": return [12, 9, [_cc(3.5, 5, 0, 6, 6, 1.5), lean(3.5, 5, 1.5, 5, 5, 6, 3.2, 0.7, 0, _tw), deb(9, 2, 5, 6, 2),
			_glow(9.5, 6, 0)]]
		&"cy_b03": return [13, 9, [_tw(3.5, 5, 0, 4.5, 4.5, 22, "#7080a8"), jag(3.5, 5, 22, 4.5, 4.5, 2, 2, 4, _tw, 21), _r2([_tw(9.5,
			5, 0, 4.5, 4.5, 11, "#7080a8"), jag(9.5, 5, 11, 4.5, 4.5, 3, 3, 6, _sc, 23)], -0.4, 0, 9.5, 0, 5), _mt(6.5, 5, 8, 3, 1, 0.8),
			deb(9.5, 1.5, 6, 6, 4)]]
		&"cy_b04": return [10, 10, [_cc(5, 8.6, 0, 9, 0.8, 9), _cc(1, 5, 0, 0.8, 8, 7), _cc(9, 5, 0, 0.8, 8, 5), _cc(2.6, 1.4, 0, 3.4,
			0.8, 6), _cc(7.6, 1.4, 0, 2.4, 0.8, 3), jag(5, 8.6, 9, 9, 0.8, 5, 1, 3, _cc, 31), deb(5, 5, 6, 6, 5)]]
		&"cy_b05": return [12, 11, [_cc(6, 5.5, 0, 11, 10, 4), _cc(6, 6, 4, 8, 7.5, 4), _cc(5.4, 6.4, 8, 5, 5, 4), jag(5.4, 6.4, 12,
			5, 5, 3, 3, 3, _cc, 41), _sc(9.4, 2, 4, 2.4, 2, 2), deb(10, 1.4, 4, 5, 6)]]
		&"cy_b06": return [16, 12, [_loop(id), _tw(8, 6.5, 6.5, 5, 3, 2, "#90a0d0"), _mt(5, 8, 6, 0.6, 0.6, 6), _mt(11, 8.4, 7, 0.5,
			0.5, 4.5), _glow(3, 2, 0, 0.8), _glow(13, 3, 0), deb(8, 0.8, 7, 12, 7)]]
		&"cy_b07": return [16, 7, [_loop(id), _mt(13.5, 1.4, 6, 0.4, 2.2, 3), _mt(13.5, 5.6, 6, 0.4, 2.2, 3), _sc(4, 3.5, 0, 3, 5,
			1.2), _tw(8, 1.2, 4.2, 8, 0.6, 0.8, "#90a0d0")]]
		&"cy_b08": return [18, 6, [_cc(2, 3, 0, 3.6, 4.2, 5), jag(2, 3, 5, 3.6, 4.2, 2, 2, 2, _cc, 81), _tw(10.5, 3, 0, 13, 3.8, 3.4),
			_tw(17, 3, 0, 1.8, 3, 2.2), deb(6, 1, 6, 5, 8)]]
		&"cy_b09": return [10, 10, [_loop(id), _mt(5, 5, 4, 8, 8, 0.5, "#9a9490"), _mt(4, 5.5, 8, 6, 7, 0.5, "#9a9490"), _mt(3.5, 6,
			11, 4, 4, 0.4, "#9a9490"), deb(7, 1.4, 5, 6, 9)]]
		&"cy_b10": return [12, 12, [_cc(6, 6, 0, 11, 11, 1.5), _loop(id), _tw(5, 7, 5.5, 5, 4, 1.2, "#8090c0"), _glow(7, 4, 1.5, 0.8),
			deb(9, 1.2, 4, 4, 10)]]
		&"cy_b11": return [10, 9, [_cc(3, 6, 0, 3, 3, 1.2), _mt(3, 6, 1.2, 1.2, 1.2, 19), _mt(3, 6, 20, 0.5, 0.5, 5), _mt(3, 6, 8, 3,
			0.4, 0.4), _mt(3, 6, 14, 2.4, 0.4, 0.4), _mt(7.5, 3, 0, 4.5, 3.5, 0.8, "#b0b4c0"), _mt(7.5, 3, 0.8, 2.5, 2, 0.6,
			"#b0b4c0")]]
		&"cy_b12": return [14, 7, [_r2([_cc(5, 4, 0, 9, 5, 16), jag(5, 4, 16, 9, 5, 4, 2, 2, _cc, 123)], 0, 0.18, 5, 0, 4), _cc(11, 4,
			0, 4, 5, 7), jag(11, 4, 7, 4, 5, 3, 2, 5, _cc, 121), _sc(12.6, 1, 0, 2.6, 1.8, 1.2), deb(12, 1.2, 6, 4, 12)]]
		&"cy_b13": return [12, 8, [_r2([_tw(4, 4.5, 0, 5, 5, 10, "#8a90c8"), _tw(4, 4.5, 10, 3.4, 3.4, 8, "#8a90c8"), _tw(4, 4.5, 18,
			2, 2, 4, "#8a90c8"), _mt(4, 4.5, 22, 0.6, 0.6, 2)], -0.3, 0, 4, 0, 4.5), _mt(9, 2, 0, 6, 0.8, 0.8), _mt(11.6, 2, 0, 1, 1,
			1.2), _glow(9, 5.5, 0)]]
		&"cy_b14": return [16, 12, [_cc(5, 8, 0, 9, 7, 4.5), _cc(12, 4, 0, 6, 7, 3.5), _tw(5, 4.4, 0, 9, 0.6, 3.6, "#7888b0"), _sc(12,
			7.8, 3.5, 4, 2, 1), jag(5, 8, 4.5, 9, 7, 4, 3, 2, _cc, 141), deb(10, 1.2, 6, 8, 14)]]
		&"cy_b15": return [18, 6, [_cc(2, 3, 0, 3, 3, 12), _cc(16, 3, 0, 3, 3, 9), jag(2, 3, 12, 3, 3, 2, 2, 2, _cc, 151), _mt(5.5, 3,
			10, 5, 2, 1), _mt(13, 3, 7.5, 4, 2, 1), _mt(8.6, 3, 0, 3, 2, 1.2), deb(9, 2, 5, 5, 15), _glow(10, 4.6, 0)]]
		&"cy_b16": return [14, 14, [_cc(7, 7, 0, 13, 13, 1.2), _py(7, 7, 1.2, 12, 12, 19, &"tower_glass", "#7a8cc0"), _sc(10.5, 4,
			1.2, 4, 3, 6), deb(4, 1.2, 6, 6, 16), _glow(2, 2, 0)]]
		&"cy_b17": return [14, 8, [_mt(6, 4, 0, 10, 6, 0.5), _mt(6, 4, 0.5, 9, 5, 5), _mt(11.2, 4, 0, 0.8, 6, 6, "#6a6e80"), _mt(12.8,
			4, 0.6, 1.2, 4, 4.6, "#4a4e60"), _sc(2, 4, 0, 3, 4.4, 3), _glow(12.8, 4, 5.2), deb(7, 0.8, 5, 9, 17)]]
		&"cy_b18": return [12, 12, [_cc(6, 6, 0, 10, 10, 3), _cc(6, 6, 3, 8, 8, 4), _cc(6, 6, 7, 7, 7, 3), _cc(6, 6, 10, 8, 8, 2),
			jag(6, 6, 12, 8, 8, 4, 4, 3, _cc, 181), _glow(6, 3, 12.5, 1), _glow(9, 6, 12, 0.8)]]
		&"cy_b19": return [16, 12, [_mt(3, 3, 0, 1, 1, 7), _mt(13, 3, 0, 1, 1, 9), _mt(3, 9, 0, 1, 1, 8), _mt(13, 9, 0, 1, 1, 3),
			_loop(id), _tw(6, 7, 9.5, 4, 3, 3, "#90a0d0"), deb(12, 1.2, 5, 5, 19)]]
		&"cy_b20": return [14, 9, [_tw(2.5, 5, 0, 3.6, 3.6, 9), _sc(7, 5, 0, 3.6, 3.6, 6), _tw(11.5, 5, 0, 3.6, 3.6, 13), jag(2.5, 5,
			9, 3.6, 3.6, 2, 2, 3, _tw, 201), jag(11.5, 5, 13, 3.6, 3.6, 2, 2, 4, _tw, 203), _mt(9.2, 5, 10, 4.5, 2.4, 0.5), _mt(7, 2, 0,
			5, 1, 0.8), deb(7, 1.4, 5, 6, 20)]]
		&"cy_b21": return [22, 8, [_cc(3, 4, 0, 5, 6, 2), _r2([_tw(3, 4, 0, 5, 5, 18), jag(3, 4, 18, 5, 5, 3, 3, 3, _tw, 211)],
			-PI / 2 + 0.06, 0, 3, 0, 4), deb(12, 1, 8, 16, 21), _glow(20, 6, 0)]]
		&"cy_b22": return [14, 8, [_tw(10.5, 4, 0, 4, 4, 16), jag(10.5, 4, 16, 4, 4, 2, 2, 3, _tw, 221), _r2([_tw(3.5, 4, 0, 4, 4, 15,
			"#6a7aa4"), jag(3.5, 4, 15, 4, 4, 2, 2, 2, _sc, 223)], -0.62, 0, 3.5, 0, 4), deb(6, 1, 5, 8, 22)]]
		&"cy_b23": return [12, 9, [_r2([_tw(6, 4.5, 0, 4, 4, 14, "#8a90c8"), _py(6, 4.5, 14, 4, 4, 8, &"tower_glass", "#8a90c8"),
			_mt(6, 4.5, -1.2, 5, 5, 1.2)], PI * 0.84, 0, 6, 6, 4.5), _sc(6, 4.5, 0, 9, 7, 0.4), deb(6, 2, 8, 10, 23), _glow(2, 7, 0,
			0.8)]]
		&"cy_b24": return [12, 8, [_cc(4, 4, 0, 5.5, 5.5, 1.5), _loop(id), deb(9, 1.4, 5, 5, 24)]]
		&"cy_b25": return [12, 18, [_r2([_tw(6, 3, 0, 5, 5, 20, "#7484ac"), jag(6, 3, 20, 5, 5, 3, 3, 3, _tw, 251)], 0, 0.78, 6, 0,
			3), _cc(6, 3, 0, 7, 6, 1.2), deb(6, 1, 6, 9, 25)]]
		&"cy_b26": return [21, 8, [_tw(4, 4, 0, 5, 5, 9), jag(4, 4, 9, 5, 5, 3, 3, 2, _sc, 261), _r2([_tw(9.5, 4, 0, 5, 5, 10),
			jag(9.5, 4, 10, 5, 5, 3, 3, 2, _sc, 263)], -1.3, 0, 9.5, 0, 4), deb(14, 1, 7, 10, 26)]]
		&"cy_s01": return [5, 5, [_cc(2.5, 2.5, 0, 4.6, 4.6, 0.7), _tb(2.5, 2.5, 0.7, 3.6, 3.6, 0.08, &"plain_white", "#3a3640",
			&"plain_white"), _cc(2.5, 2.5, 0, 1, 1, 2.2), _cc(2.5, 2.5, 2.2, 2, 2, 0.4), _rk(1.2, 1.2, 0, 0.8, 0.6, 0.4, "#8a8480")]]
		&"cy_s02": return [2, 2, [_mt(1, 1, 0, 0.4, 0.4, 6), _mt(1.5, 1, 5.8, 1.2, 0.4, 0.3), _mt(2, 1, 5.4, 0.5, 0.5, 0.4,
			"#e0d080")]]
		&"cy_s03": return [6, 2, [_mt(3, 1, 0, 5.6, 0.4, 0.4), _mt(0.4, 1, 0, 0.6, 0.6, 0.3), _mt(5.6, 1, 0, 0.6, 0.5, 0.6,
			"#c0b070")]]
		&"cy_s04": return [5, 3, [_mt(2.5, 1.5, 0, 3.6, 1.8, 0.4, "#3a3a40"), _mt(2.5, 1.5, 0.4, 4.6, 2.4, 1, "#7a5a6a"), _tw(2.3,
			1.5, 1.4, 2.4, 2, 0.8, "#5a6a90")]]
		&"cy_s05": return [9, 3, [_mt(4.5, 1.5, 0, 8.6, 2.6, 2.6, "#8a7a50"), _tw(4.5, 0.15, 0.9, 7.8, 0.2, 1, "#506080"), _sc(7.5,
			1.5, 2.6, 2, 2.2, 0.3)]]
		&"cy_s06": return [4, 2, [_mt(0.6, 1, 0, 0.3, 0.8, 0.6), _mt(3.4, 1, 0, 0.3, 0.8, 0.6), _mt(2, 1, 0.6, 3.6, 1, 0.25,
			"#6a5a4a"), _mt(2, 1.4, 0.85, 3.6, 0.2, 0.8, "#6a5a4a")]]
		&"cy_s07": return [4, 4, [_cc(2, 2, 0, 3, 3, 1.4), _cc(2, 2, 1.4, 1.2, 1, 2, "#c8c0b0"), _cc(1.4, 2, 3.4, 0.6, 0.6, 0.8,
			"#c8c0b0"), _rk(3.4, 0.8, 0, 1, 0.8, 0.6, "#c8c0b0"), _rk(0.6, 0.6, 0, 0.8, 0.6, 0.5, "#c8c0b0")]]
		&"cy_s08": return [6, 2, [_mt(1.5, 1, 0, 0.4, 0.4, 5), _mt(4.5, 1, 0, 0.4, 0.4, 3.5), _tb(3, 1, 3.6, 5.6, 0.3, 2.4,
			&"tower_scorch", "#a060a0", &"metal_panel")]]
		&"cy_s09": return [6, 2, [_loop(id)]]
		&"cy_s10": return [6, 5, [_tb(3, 2.5, 0, 5.4, 4.4, 0.1, &"plain_white", "#3a3236", &"plain_white"), _rk(1, 1, 0, 1, 0.8, 0.6,
			"#6a6460"), _rk(5, 3.8, 0, 1.2, 1, 0.8, "#5a5450"), _mt(3.4, 2.6, 0, 1.6, 0.4, 0.6), _glow(3, 2.5, 0, 0.5)]]
		&"cy_s11": return [8, 2, [_mt(4, 1, 0, 7.6, 0.6, 0.6, "#8a6a5a"), _mt(4, 1, 0.6, 7.6, 0.2, 0.2, "#8a6a5a"), _mt(1, 1, 0, 0.6,
			1.6, 0.8, "#8a6a5a")]]
		&"cy_s12": return [3, 2, [_mt(1.5, 1, 0, 2, 1.2, 2.6, "#6a7080"), _tw(1.5, 0.35, 1.4, 1.4, 0.1, 0.9, "#60a0c0"), _mt(1.5, 1,
			2.6, 2.6, 1.6, 0.3)]]
		&"cy_s13": return [5, 3, [_mt(1.5, 1.5, 0, 0.5, 0.5, 8), _mt(3.5, 1.5, 0, 0.5, 0.5, 5), _mt(2.5, 1.5, 5, 2.6, 0.4, 0.4),
			_mt(2, 1.5, 7.5, 1.8, 0.3, 0.3), _mt(4.2, 0.6, 0, 1.6, 0.3, 0.3)]]
		&"cy_s14": return [3, 3, [_cc(1.5, 1.5, 0, 2.6, 2.6, 0.9), _tb(1.5, 1.5, 0, 0.4, 0.4, 4, &"bark_g", "#4a4048", &"bark_g"),
			_tb(1, 1.5, 2.6, 1, 0.3, 0.3, &"bark_g", "#4a4048", &"bark_g"), _tb(2.1, 1.5, 3.2, 1, 0.3, 0.3, &"bark_g", "#4a4048",
			&"bark_g")]]
		&"cy_s15": return [4, 3, [_mt(1.4, 1.5, 0, 1.8, 1.2, 2.8, "#7a3a4a"), _tw(1.4, 0.85, 1, 1.2, 0.1, 1.4, "#c0b060"), _mt(3, 1.4,
			0, 1.6, 1.4, 0.6, "#5a5a66"), _mt(3, 1.4, 0.6, 0.4, 0.4, 0.6), _glow(3.6, 2.4, 0, 0.4)]]
	return []
