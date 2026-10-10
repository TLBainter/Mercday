@tool
class_name ScatterGrid extends RefCounted

#Scatter cell layers (one cell = 2 image px) and the prop footprint test (C12, MC:594-616); K is EL.K, MC:460.

const K: float = 1.4
const SCAT_S: float = 1.5

var rw: int = 0
var rh: int = 0
var w: int = 0
var h: int = 0
var dry0: PackedByteArray = PackedByteArray()
var occ: PackedByteArray = PackedByteArray()
var paint: PackedByteArray = PackedByteArray()
var rail: PackedByteArray = PackedByteArray()
var pond: PackedByteArray = PackedByteArray()
var lvl: PackedByteArray = PackedByteArray()
var river: PackedByteArray = PackedByteArray()
var hgt: PackedFloat32Array = PackedFloat32Array()
var set: MapPlacementSet
var rules: Dictionary = {}
var counts: Dictionary = {"blocked": 0, "spread": 0}
var kits: Dictionary = {}
var _spread: RegEx = null

func setup(levels: Image, river_img: Image, rail_mask: Image, occupancy: Image, paint_img: Image, rule_set: Dictionary,
		placement: MapPlacementSet) -> void:
	rw = levels.get_width()
	rh = levels.get_height()
	w = rw * 2
	h = rh * 2
	lvl = bytes_of(levels, rw, rh)
	river = bytes_of(river_img, rw, rh)
	rail = bytes_of(rail_mask, rw, rh)
	occ = bytes_of(occupancy, rw, rh)
	paint = bytes_of(paint_img, rw, rh)
	pond = bytes_of(null, rw, rh)
	dry0 = bytes_of(null, rw, rh)
	hgt.resize(rw * rh)
	for j: int in rw * rh:
		dry0[j] = 1 if lvl[j] > MapConst.LEVEL_WATER and river[j] == 0 else 0
		hgt[j] = MapSpace.level_height(lvl[j])
	rules = rule_set
	set = placement
	counts = {"blocked": 0, "spread": 0}
	_spread = regex_of(rules.get("spread_ids", {}))

static func regex_of(spec: Variant) -> RegEx:
	if not (spec is Dictionary) or String((spec as Dictionary).get("re", "")).is_empty():
		return null
	var pre: String = "(?i)" if String((spec as Dictionary).get("flags", "")).contains("i") else ""
	return RegEx.create_from_string(pre + String((spec as Dictionary)["re"]))

func j_at(x: int, z: int) -> int:
	return clampi(z >> 1, 0, rh - 1) * rw + clampi(x >> 1, 0, rw - 1)

#Keyed by the full id; "#v" builds variant v of the base kit (MC kitOf).
func kit_of(id: StringName) -> Dictionary:
	for key: Variant in [id, String(id)]:
		if kits.has(key):
			return kits[key]
	var base: String = String(id).get_slice("#", 0)
	var v: int = int(String(id).get_slice("#", 1)) if String(id).contains("#") else -1
	var m: PixelModel = PixelKitBuilder.build(StringName(base), &"buern", 0.4, v)
	var k: Dictionary = {}
	if m != null:
		var s: float = SCAT_S if (rules.get("scat_ids", []) as Array).has(base) else 1.0
		var ex: Dictionary = PixelKitRuins.ext_of(m if s == 1.0 else scaled_copy(m, s))
		k = {"W": m.W * s, "D": m.D * s, "ext": ex["rect"] if bool(ex["tilted"]) else [], "tilted": bool(ex["tilted"])}
	kits[id] = k
	return k

#Copy of m with W, D and every part x, z, y, w, d, h times s; pivots stay; m is left untouched.
static func scaled_copy(m: PixelModel, s: float) -> PixelModel:
	var out: PixelModel = PixelModel.new()
	out.id = m.id
	out.W = m.W * s
	out.D = m.D * s
	var ps: Array[PixelPart] = []
	for p0: PixelPart in m.parts:
		var p: PixelPart = p0.duplicate() as PixelPart
		for key: String in ["x", "z", "y", "w", "d", "h"]:
			p.set(key, float(p.get(key)) * s)
		ps.append(p)
	out.parts = ps
	return out

func place(id: StringName, x: float, gy: float, z: float, zi: int, scale: float = 1.0) -> int:
	return set.add(id, Vector3(x, MapSpace.height_to_y(gy), z), 0.0, scale, Vector4i.ZERO, zi)

func free_at(j: int) -> bool:
	return dry0[j] != 0 and occ[j] == 0 and paint[j] == 0 and pond[j] == 0 and rail[j] != 2

func near_at(j: int) -> bool:
	return rail[j] != 0

#Footprint cells (x0, z0, x1, z1 inclusive) of a kit centred on (x, z), as MC:606.
static func span(k: Dictionary, x: float, z: float) -> Vector4i:
	var fw: float = float(k["W"]) * K
	var fd: float = float(k["D"]) * K
	var x0: float = x - fw / 2.0
	var z0: float = z - fd / 2.0
	return Vector4i(floori(x0 / 2.0), floori(z0 / 2.0), ceili((x0 + fw) / 2.0) - 1, ceili((z0 + fd) / 2.0) - 1)

func prop(id: StringName, x: int, z: int, zi: int = -1) -> bool:
	var k: Dictionary = kit_of(id)
	if k.is_empty():
		counts["missing_kit"] = int(counts.get("missing_kit", 0)) + 1
		return false
	var base: String = String(id).get_slice("#", 0)
	var kw: float = float(k["W"])
	var fd: float = float(k["D"]) * K
	var z0: float = float(z) - fd / 2.0
	var r: Vector4i = span(k, x, z)
	var lo: int = 1 << 30
	var hi: int = -1
	var gmin: float = 1e9
	for zz: int in range(r.y, r.w + 1):
		for xx: int in range(r.x, r.z + 1):
			var j: int = zz * rw + xx
			if xx < 0 or zz < 0 or xx >= rw or zz >= rh or not free_at(j):
				counts["blocked"] = int(counts["blocked"]) + 1
				return false
			lo = mini(lo, lvl[j])
			hi = maxi(hi, lvl[j])
			gmin = minf(gmin, hgt[j])
	var flat: bool = (rules.get("flat_ids", []) as Array).has(base)
	var limit: int = 0 if flat else (3 if _spread != null and _spread.search(base) != null else 1)
	if hi - lo > limit:
		counts["spread"] = int(counts["spread"]) + 1
		return false
	if bool(k.get("tilted", false)) and (k["ext"] as Array).size() == 4:
		var ex: Array = k["ext"]
		var a0: Vector2 = Vector2(x + (float(ex[0]) - kw / 2.0) * K - 2.0, z0 + fd - float(ex[3]) * K - 2.0)
		var a1: Vector2 = Vector2(x + (float(ex[1]) - kw / 2.0) * K + 2.0, z0 + fd - float(ex[2]) * K + 2.0)
		var reserve: PackedInt32Array = PackedInt32Array()
		for zz: int in range(floori(a0.y / 2.0), ceili(a1.y / 2.0)):
			for xx: int in range(floori(a0.x / 2.0), ceili(a1.x / 2.0)):
				var inside: bool = xx >= r.x and xx <= r.z and zz >= r.y and zz <= r.w
				if xx < 0 or zz < 0 or xx >= rw or zz >= rh or (occ[zz * rw + xx] != 0 and not inside):
					counts["blocked"] = int(counts["blocked"]) + 1
					return false
				reserve.append(zz * rw + xx)
		mark(reserve, 3)
	for zz: int in range(r.y, r.w + 1):
		for xx: int in range(r.x, r.z + 1):
			occ[zz * rw + xx] = 3
	place(id, x, maxf(MapConst.WATER_H + MapConst.TERRACE, gmin), z0 + fd, zi)
	return true

func mark(cells: PackedInt32Array, v: int) -> void:
	for j: int in cells:
		occ[j] = v

func to_image() -> Image:
	var out: PackedByteArray = PackedByteArray()
	out.resize(rw * rh)
	for j: int in rw * rh:
		out[j] = 255 if occ[j] != 0 else 0
	return Image.create_from_data(rw, rh, false, Image.FORMAT_L8, out)

static func bytes_of(img: Image, img_w: int, img_h: int) -> PackedByteArray:
	var c: Image = img
	if img == null:
		c = Image.create_empty(maxi(img_w, 1), maxi(img_h, 1), false, Image.FORMAT_R8)
	elif img.get_format() != Image.FORMAT_R8 and img.get_format() != Image.FORMAT_L8:
		c = img.duplicate()
		c.convert(Image.FORMAT_R8)
	return c.get_data()
