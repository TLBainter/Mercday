@tool
class_name MapRng extends RefCounted

#Bit-exact ports of the JS hashes and generators used by the kits and the scatter.

const M: int = 0xFFFFFFFF
const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619

var _s: int = 0
var _kind: int = 0

static func imul32(a: int, b: int) -> int:
	var ub: int = b & M
	return ((a & 0xFFFF) * ub + (((((a & M) >> 16) * ub) & 0xFFFF) << 16)) & M

static func hh_u32(x: int, z: int) -> int:
	var h: int = (imul32(x & M, 73856093) ^ imul32(z & M, 19349663)) & M
	h = imul32(h ^ (h >> 13), 1274126177)
	return (h ^ (h >> 16)) & M

static func hh(x: int, z: int) -> float:
	return float(hh_u32(x, z)) / 4294967296.0

static func vn(x: float, z: float) -> float:
	var xi: int = int(floor(x))
	var zi: int = int(floor(z))
	var fx: float = x - float(xi)
	var fz: float = z - float(zi)
	return ((hh(xi, zi) * (1.0 - fx) + hh(xi + 1, zi) * fx) * (1.0 - fz)
		+ (hh(xi, zi + 1) * (1.0 - fx) + hh(xi + 1, zi + 1) * fx) * fz)

static func hstr(s: String) -> int:
	var h: int = FNV_OFFSET
	for i: int in s.length():
		h = imul32(h ^ s.unicode_at(i), FNV_PRIME)
	return h & M

static func fnv1a(s: String) -> int:
	return hstr(s)

static func jround(x: float) -> float:
	return floor(x + 0.5)

static func pick(k: Array, q01: float) -> Variant:
	var tot: float = 0.0
	for row: Array in k:
		tot += float(row[1])
	var q: float = q01 * tot
	var id: Variant = k[0][0]
	for row: Array in k:
		q -= float(row[1])
		if q <= 0.0:
			id = row[0]
			break
	return id

static func mulberry32(s0: int) -> MapRng:
	var r: MapRng = MapRng.new()
	r._s = s0 & M
	r._kind = 0
	return r

static func srng(s0: int) -> MapRng:
	var r: MapRng = MapRng.new()
	r._s = s0 & M
	if r._s == 0:
		r._s = 1
	r._kind = 1
	return r

func next_u32() -> int:
	if _kind == 1:
		_s = (imul32(_s ^ (_s >> 15), 2246822507) + 0x9E3779B9) & M
		_s ^= _s >> 13
		return _s
	_s = (_s + 0x6D2B79F5) & M
	var t: int = imul32(_s ^ (_s >> 15), _s | 1)
	t = ((t + imul32(t ^ (t >> 7), t | 61)) & M) ^ t
	return (t ^ (t >> 14)) & M

func next() -> float:
	return float(next_u32()) / 4294967296.0

func vv(a: float, b: float) -> float:
	return a + (b - a) * next()
