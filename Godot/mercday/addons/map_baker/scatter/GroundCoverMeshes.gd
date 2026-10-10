@tool
class_name GroundCoverMeshes extends RefCounted

#Ground clump looks (GV) and their lean kit meshes: VERTEX, COLOR and INDEX only.
#COLOR.rgb holds the colour factor times 0.5 and COLOR.a the colour mode over 2, since vertex colours clamp to 1.

const KN: Dictionary = {"grass": 1, "flowers": 2, "gravel": 3, "sand": 4, "wheat": 5, "snow": 6}
const VARIANTS: int = 12
const FL: Array[Color] = [Color(0.96, 0.95, 0.9), Color(0.98, 0.86, 0.3), Color(0.95, 0.55, 0.65), Color(0.7, 0.5, 0.9),
	Color(0.9, 0.35, 0.3)]
const SIDE: float = 0.72


#Kind -> 12 lists of quad dicts {t, dx, dz, w, d, h, y, cf, fl}, keys present as in the JS GV table.
static func variants(_gs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in KN:
		var list: Array = []
		for v: int in VARIANTS:
			list.append(_variant(kind, int(KN[kind]) * 100 + v))
		out[kind] = list
	return out


static func _variant(kind: String, s: int) -> Array:
	var p: Array = []
	if kind == "grass" or kind == "flowers":
		var n: int = 4 + floori(_r(s, 1) * 4.0)
		var hb: float = 2.2 + _r(s, 2) * 2.2
		var sp: float = 1.1 + _r(s, 3) * 0.6
		for i: int in n:
			var a: float = (float(i) / float(n - 1) - 0.5) * 2.0 if n > 1 else 0.0
			p.append({"t": "b", "dx": a * sp + (_r(s, 10 + i) - 0.5) * 0.4, "dz": (_r(s, 20 + i) - 0.5) * 1.4,
				"w": 0.5 + _r(s, 30 + i) * 0.4, "h": hb * (0.55 + 0.45 * (1.0 - absf(a))) * (0.8 + _r(s, 40 + i) * 0.4),
				"cf": 0.84 + _r(s, 50 + i) * 0.36})
		if kind == "flowers":
			for i: int in 2 + floori(_r(s, 4) * 3.0):
				var fh: float = hb * (0.9 + _r(s, 60 + i) * 0.5)
				var dx: float = (_r(s, 70 + i) - 0.5) * 2.0
				var dz: float = (_r(s, 80 + i) - 0.5) * 1.2
				p.append({"t": "b", "dx": dx, "dz": dz, "w": 0.28, "h": fh, "cf": 0.8})
				p.append({"t": "f", "dx": dx, "dz": dz, "y": fh, "w": 0.95, "d": 0.85, "fl": floori(_r(s, 90 + i) * 5.0)})
	elif kind == "gravel":
		for i: int in 4 + floori(_r(s, 1) * 4.0):
			p.append({"t": "l", "dx": (_r(s, 10 + i) - 0.5) * 2.4, "dz": (_r(s, 20 + i) - 0.5) * 2.0,
				"w": 0.5 + _r(s, 30 + i) * 0.9, "d": 0.45 + _r(s, 40 + i) * 0.7, "h": 0.3 + _r(s, 50 + i) * 0.5,
				"cf": 0.75 + _r(s, 60 + i) * 0.5})
	elif kind == "sand":
		var n: int = 2 + floori(_r(s, 1) * 3.0)
		for i: int in n:
			p.append({"t": "f", "dx": (_r(s, 10 + i) - 0.5) * 1.6, "dz": (float(i) - float(n) / 2.0) * 0.75,
				"w": 1.6 + _r(s, 20 + i) * 1.2, "d": 0.45, "cf": 1.1 if _r(s, 30 + i) < 0.5 else 0.9})
	elif kind == "wheat":
		for i: int in 6 + floori(_r(s, 1) * 4.0):
			var h: float = 3.2 + _r(s, 10 + i) * 1.8
			var dx: float = (_r(s, 20 + i) - 0.5) * 2.4
			var dz: float = (_r(s, 30 + i) - 0.5) * 1.6
			p.append({"t": "b", "dx": dx, "dz": dz, "w": 0.36, "h": h, "cf": 1.0 + _r(s, 40 + i) * 0.15})
			p.append({"t": "b", "dx": dx, "dz": dz + 0.01, "y": h - 0.3, "w": 0.7, "h": 1.1, "cf": 0.85})
	else:
		for i: int in 3 + floori(_r(s, 1) * 3.0):
			p.append({"t": "l", "dx": (_r(s, 10 + i) - 0.5) * 2.2, "dz": (_r(s, 20 + i) - 0.5) * 1.8,
				"w": 1.2 + _r(s, 30 + i), "d": 1.0 + _r(s, 40 + i) * 0.8, "h": 0.3 + _r(s, 50 + i) * 0.4,
				"cf": 1.0 + _r(s, 60 + i) * 0.05})
	return p


static func _r(s: int, k: int) -> float:
	return MapRng.hh(s, k)


#Clump mesh of one variant; m == 1 mirrors x.
static func mesh(kind: String, _v: int, m: int, quads: Array) -> ArrayMesh:
	var pos: PackedVector3Array = PackedVector3Array()
	var col: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	for qv: Variant in quads:
		var q: Dictionary = qv
		var fl: bool = q.has("fl")
		var md: int = 1 if fl else (2 if kind == "gravel" else 0)
		var cf: float = float(q.get("cf", 1.0))
		var c: Color = FL[int(q["fl"])] if fl else Color(cf, cf, cf)
		var x: float = float(q["dx"]) * (-1.0 if m == 1 else 1.0)
		var z: float = float(q["dz"])
		var hw: float = float(q["w"]) / 2.0
		var t: String = String(q["t"])
		if t == "b":
			var y: float = float(q.get("y", 0.0))
			var h: float = float(q["h"])
			_quad(pos, col, idx, [Vector3(x - hw, y + h, z), Vector3(x - hw, y, z), Vector3(x + hw, y + h, z),
				Vector3(x + hw, y, z)], c, md)
			continue
		var hd: float = float(q["d"]) / 2.0
		var yf: float = float(q.get("y", 0.05)) if t == "f" else float(q["h"])
		_quad(pos, col, idx, [Vector3(x - hw, yf, z - hd), Vector3(x - hw, yf, z + hd), Vector3(x + hw, yf, z - hd),
			Vector3(x + hw, yf, z + hd)], c, md)
		if t == "l":
			_quad(pos, col, idx, [Vector3(x - hw, yf, z + hd), Vector3(x - hw, 0.0, z + hd), Vector3(x + hw, yf, z + hd),
				Vector3(x + hw, 0.0, z + hd)], Color(c.r * SIDE, c.g * SIDE, c.b * SIDE), md)
	return _commit(pos, col, idx)


#Unit box x and z in [-0.5, 0.5], y in [0, 1]: top, south, east and west quads in the JS box3 order.
static func ice_box() -> ArrayMesh:
	var pos: PackedVector3Array = PackedVector3Array()
	var col: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	var x0: float = -0.5
	var x1: float = 0.5
	var z0: float = -0.5
	var z1: float = 0.5
	_quad(pos, col, idx, [Vector3(x0, 1, z0), Vector3(x0, 1, z1), Vector3(x1, 1, z0), Vector3(x1, 1, z1)], Color.WHITE, 0)
	_quad(pos, col, idx, [Vector3(x0, 1, z1), Vector3(x0, 0, z1), Vector3(x1, 1, z1), Vector3(x1, 0, z1)],
		Color(0.8, 0.8, 0.8), 0)
	_quad(pos, col, idx, [Vector3(x1, 1, z1), Vector3(x1, 0, z1), Vector3(x1, 1, z0), Vector3(x1, 0, z0)],
		Color(0.7, 0.7, 0.7), 0)
	_quad(pos, col, idx, [Vector3(x0, 1, z0), Vector3(x0, 0, z0), Vector3(x0, 1, z1), Vector3(x0, 0, z1)],
		Color(0.86, 0.86, 0.86), 0)
	return _commit(pos, col, idx)


static func _quad(pos: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array, pts: Array[Vector3], c: Color,
		md: int) -> void:
	var b: int = pos.size()
	for p: Vector3 in pts:
		pos.append(p)
		col.append(Color(c.r * 0.5, c.g * 0.5, c.b * 0.5, md / 2.0))
	idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 2, b + 1, b + 3]))


static func _commit(pos: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	if pos.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
