@tool
class_name PixelKitRuinsOverlap extends RefCounted

#ME:913-937 deOverlap: settle or drop interpenetrating rotated groups, then ground hanging groups.

const K: float = 1.4
const KY: float = 1.6
const E: float = 0.06
const LAT: int = 6
const SETTLE: float = 0.88
const STEPS: int = 24
const ROT_EPS: float = 1e-6
const GROUND: float = 0.2
const GAP: float = 0.05


static func de_overlap(parts: Array[PixelPart]) -> Array[PixelPart]:
	var groups: Array = _group(parts)
	var drop: Dictionary = {}
	for a: int in groups.size():
		for b: int in range(a + 1, groups.size()):
			var ga: Array = groups[a]
			var gb: Array = groups[b]
			if _any_in(ga, drop) or _any_in(gb, drop):
				continue
			if _rot(ga[0]) < ROT_EPS and _rot(gb[0]) < ROT_EPS:
				continue
			if not _clash(ga, gb):
				continue
			var a_moves: bool = _rot(ga[0]) >= _rot(gb[0])
			var mov: Array = ga if a_moves else gb
			var other: Array = gb if a_moves else ga
			var ok: bool = false
			var s: int = 0
			while s < STEPS and not ok:
				for p: PixelPart in mov:
					p.tilt = p.tilt * SETTLE
					p.pitch = p.pitch * SETTLE
					_add_keys(p)
				ok = not _clash(mov, other)
				s += 1
			if not ok:
				var small: Array = mov if _vol(mov) < _vol(other) else other
				for p: PixelPart in small:
					drop[p] = true
	var kept: Array[PixelPart] = []
	for p: PixelPart in parts:
		if not drop.has(p):
			kept.append(p)
	_ground(kept)
	return kept


static func _ground(kept: Array[PixelPart]) -> void:
	for g: Array in _group(kept):
		var y0: float = INF
		for p: PixelPart in g:
			y0 = minf(y0, p.y)
		if y0 <= GROUND:
			continue
		var base: Array[PixelPart] = []
		for p: PixelPart in g:
			if p.y - y0 < GAP:
				base.append(p)
		var top: float = 0.0
		for q: PixelPart in kept:
			if g.has(q) or not _solid(q):
				continue
			var qt: float = q.y + q.h
			if qt > y0 + GAP:
				continue
			for p: PixelPart in base:
				if absf(p.x - q.x) < (p.w + q.w) / 2 and absf(p.z - q.z) < (p.d + q.d) / 2:
					top = maxf(top, qt)
					break
		var dy: float = y0 - top
		if dy > GAP:
			for p: PixelPart in g:
				p.y = p.y - dy
				if p.has_pivot:
					p.pivot = Vector3(p.pivot.x, p.pivot.y - dy, p.pivot.z)


#Solid parts grouped by [tilt, pitch, has_pivot, pivot] in first-seen order.
static func _group(parts: Array[PixelPart]) -> Array:
	var keys: Array = []
	var groups: Array = []
	for p: PixelPart in parts:
		if not _solid(p):
			continue
		var k: Array = _key(p)
		var at: int = -1
		for i: int in keys.size():
			if keys[i] == k:
				at = i
				break
		if at < 0:
			keys.append(k)
			groups.append([])
			at = keys.size() - 1
		groups[at].append(p)
	return groups


static func _key(p: PixelPart) -> Array:
	var pv: Vector3 = p.pivot if p.has_pivot else Vector3.ZERO
	return [p.tilt + 0.0, p.pitch + 0.0, p.has_pivot, pv.x + 0.0, pv.y + 0.0, pv.z + 0.0]


static func _solid(p: PixelPart) -> bool:
	return (p.kind == &"box" or p.kind == &"lathe") and p.w > 0.0 and p.d > 0.0 and p.h > 0.0


static func _rot(p: PixelPart) -> float:
	return absf(p.tilt) + absf(p.pitch)


static func _vol(g: Array) -> float:
	var q: float = 0.0
	for p: PixelPart in g:
		q += p.w * p.d * p.h
	return q


static func _any_in(g: Array, drop: Dictionary) -> bool:
	for p: PixelPart in g:
		if drop.has(p):
			return true
	return false


static func _add_keys(p: PixelPart) -> void:
	var ks: PackedStringArray = p.js_keys.duplicate()
	for k: String in ["tilt", "pitch"]:
		if not ks.has(k):
			ks.append(k)
	p.js_keys = ks


static func _clash(ga: Array, gb: Array) -> bool:
	for pa: PixelPart in ga:
		for pb: PixelPart in gb:
			if _hits(pa, pb) or _hits(pb, pa):
				return true
	return false


#[pv.x, pv.y, pv.z, cos tilt, sin tilt, cos pitch, sin pitch]
static func _frame(p: PixelPart) -> PackedFloat64Array:
	var px: float = p.pivot.x if p.has_pivot else p.x
	var py: float = p.pivot.y if p.has_pivot else p.y
	var pz: float = p.pivot.z if p.has_pivot else p.z
	return PackedFloat64Array([px, py, pz, cos(p.tilt), sin(p.tilt), cos(p.pitch), sin(p.pitch)])


static func _hits(pa: PixelPart, pb: PixelPart) -> bool:
	var ra: PackedFloat64Array = _frame(pa)
	var rb: PackedFloat64Array = _frame(pb)
	for i: int in LAT:
		var sx: float = pa.x - pa.w / 2 + pa.w * (i + 0.5) / LAT
		for j: int in LAT:
			var sy: float = pa.y + pa.h * (j + 0.5) / LAT
			for k: int in LAT:
				var sz: float = pa.z - pa.d / 2 + pa.d * (k + 0.5) / LAT
				var dx: float = (sx - ra[0]) * K
				var dy: float = (sy - ra[1]) * KY
				var dz: float = -(sz - ra[2]) * K
				var nx: float = dx * ra[3] - dy * ra[4]
				dy = dx * ra[4] + dy * ra[3]
				dx = nx
				var nz: float = dz * ra[5] - dy * ra[6]
				dy = dz * ra[6] + dy * ra[5]
				dz = nz
				if _in_b(pb, rb, dx + ra[0] * K, dy + ra[1] * KY, dz - ra[2] * K):
					return true
	return false


static func _in_b(pb: PixelPart, rb: PackedFloat64Array, wx: float, wy: float, wz: float) -> bool:
	var dx: float = wx - rb[0] * K
	var dy: float = wy - rb[1] * KY
	var dz: float = wz + rb[2] * K
	var nz: float = dz * rb[5] + dy * rb[6]
	dy = -dz * rb[6] + dy * rb[5]
	dz = nz
	var nx: float = dx * rb[3] + dy * rb[4]
	dy = -dx * rb[4] + dy * rb[3]
	dx = nx
	var px: float = dx / K + rb[0]
	var py: float = dy / KY + rb[1]
	var pz: float = -dz / K + rb[2]
	return absf(px - pb.x) < pb.w / 2 - E and py > pb.y + E and py < pb.y + pb.h - E and absf(pz - pb.z) < pb.d / 2 - E
