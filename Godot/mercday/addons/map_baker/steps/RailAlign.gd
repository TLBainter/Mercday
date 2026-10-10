@tool
class_name RailAlign extends MapBakeStep

#Shifts each railroad line sideways to flatter, drier ground. Port of the JS prepRail (MC:461-479), no grade pass.
#rail_aligned: Array of {id, from, to, pts (flat x, z in image px), off}. Also written to Baked/rail_aligned.json.

const STAGE := 3
const SRC_KEY := "src/map-paths-railroad.json"
const SEA_BYTE: int = 128
const WANDER_PX: int = 8
const OFF_COST: float = 0.015
const STEP_COST: float = 0.05
const WATER_COST: float = 4.0
const D1_COST: float = 1.5
const DN_COST: float = 30.0
const SMOOTH_R: int = 6
const SMOOTH_PASSES: int = 3
const TAPER_PX: float = 12.0
const NRM_R: int = 4
const BIG: float = 1e9


func _init() -> void:
	step_name = &"RailAlign"
	stage = STAGE
	inputs = PackedStringArray([SRC_KEY, "block_level", "sea_frac", "river_mask"])
	outputs = PackedStringArray(["rail_aligned"])


func run(ctx: MapBakeContext) -> bool:
	var src: Variant = ctx.get_value(SRC_KEY)
	var levels: Image = ctx.get_image("block_level")
	var sea: Image = ctx.get_image("sea_frac")
	var rivers: Image = ctx.get_image("river_mask")
	if not (src is Dictionary) or levels == null or sea == null or rivers == null:
		return ctx.fail("RailAlign: map-paths-railroad.json, block_level, sea_frac or river_mask missing")
	for img: Image in [sea, rivers]:
		if img.get_size() != levels.get_size():
			return ctx.fail("RailAlign: size %s does not match block_level %s" % [img.get_size(), levels.get_size()])
	var lvl: Callable = _level_reader(levels.get_data(), sea.get_data(), rivers.get_data(), levels.get_width(),
		levels.get_height())
	var out: Array = []
	var samples: int = 0
	var max_off: float = 0.0
	for line: Dictionary in (src as Dictionary).get("lines", []):
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Array in line["points"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		var res: Dictionary = align(pts, lvl)
		var aligned: PackedVector2Array = res["pts"]
		var off: PackedFloat32Array = res["off"]
		var flat: Array = []
		var offs: Array = []
		for i: int in aligned.size():
			flat.append(aligned[i].x)
			flat.append(aligned[i].y)
			offs.append(off[i])
			max_off = maxf(max_off, absf(off[i]))
		samples += aligned.size()
		out.append({"id": line["id"], "from": line["from"], "to": line["to"], "pts": flat, "off": offs})
	ctx.put_value("rail_aligned", out)
	var file: FileAccess = FileAccess.open(ctx.path_of("rail_aligned.json"), FileAccess.WRITE)
	if file == null:
		return ctx.fail("RailAlign: cannot write rail_aligned.json")
	file.store_string(JSON.stringify(out, "", false, true))
	if file.get_error() != OK:
		file.close()
		return ctx.fail("RailAlign: write failed rail_aligned.json")
	file.close()
	ctx.log("RailAlign: %d lines, %d samples, max |off| %.3f" % [out.size(), samples, max_off])
	return not ctx.failed


static func _level_reader(codes: PackedByteArray, sea: PackedByteArray, rivers: PackedByteArray, rw: int,
		rh: int) -> Callable:
	return func(x: float, z: float) -> int:
		var cx: int = clampi(int(MapRng.jround(x)) >> 1, 0, rw - 1)
		var cz: int = clampi(int(MapRng.jround(z)) >> 1, 0, rh - 1)
		var j: int = cz * rw + cx
		if sea[j] >= SEA_BYTE or rivers[j] != 0:
			return -1
		return codes[j]


static func resample(pts: PackedVector2Array, st: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([pts[0]])
	var carry: float = st
	for k: int in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var dist: float = a.distance_to(b)
		var s: float = carry
		while s <= dist:
			out.append(a + (b - a) * (s / dist))
			s += st
		carry = s - dist
	var e: Vector2 = pts[pts.size() - 1]
	if e.distance_to(out[out.size() - 1]) > 0.3:
		out.append(e)
	else:
		out[out.size() - 1] = e
	return out


static func align(pts: PackedVector2Array, lvl: Callable) -> Dictionary:
	var p: PackedVector2Array = resample(pts, 1.0)
	var n: int = p.size()
	var nrm: PackedVector2Array = PackedVector2Array()
	nrm.resize(n)
	for i: int in n:
		var d: Vector2 = p[mini(n - 1, i + NRM_R)] - p[maxi(0, i - NRM_R)]
		var dist: float = d.length()
		if dist == 0.0:
			dist = 1.0
		nrm[i] = Vector2(-d.y / dist, d.x / dist)
	var s: int = 2 * WANDER_PX + 1
	var lv: PackedInt32Array = PackedInt32Array()
	lv.resize(n * s)
	for i: int in n:
		for k: int in s:
			var q: Vector2 = p[i] + nrm[i] * float(k - WANDER_PX)
			lv[i * s + k] = int(lvl.call(q.x, q.y))
	var cost: PackedFloat32Array = PackedFloat32Array()
	cost.resize(n * s)
	cost.fill(BIG)
	var back: PackedInt32Array = PackedInt32Array()
	back.resize(n * s)
	cost[WANDER_PX] = 0.0
	for i: int in range(1, n):
		for k: int in s:
			var l: int = lv[i * s + k]
			var off: int = k - WANDER_PX
			var best: float = BIG
			var bk: int = 0
			for dk: int in [-1, 0, 1]:
				var kp: int = k + dk
				if kp < 0 or kp >= s:
					continue
				var lp: int = lv[(i - 1) * s + kp]
				var tc: float = 0.0
				if l >= 0 and lp >= 0:
					var d: int = absi(l - lp)
					tc = 0.0 if d == 0 else (D1_COST if d == 1 else DN_COST * d)
				var c: float = cost[(i - 1) * s + kp] + tc + absi(dk) * STEP_COST
				if c < best:
					best = c
					bk = dk
			cost[i * s + k] = best + OFF_COST * off * off + (WATER_COST if l < 0 else 0.0)
			back[i * s + k] = bk
	var offs: PackedFloat32Array = PackedFloat32Array()
	offs.resize(n)
	var kk: int = WANDER_PX
	for i: int in range(n - 1, -1, -1):
		offs[i] = kk - WANDER_PX
		kk += back[i * s + kk]
	offs = _smooth(offs, SMOOTH_R, SMOOTH_PASSES)
	var p2: PackedVector2Array = PackedVector2Array()
	p2.resize(n)
	for i: int in n:
		offs[i] *= minf(1.0, minf(i / TAPER_PX, (n - 1 - i) / TAPER_PX))
		p2[i] = p[i] + nrm[i] * offs[i]
	return {"pts": p2, "off": offs}


static func _smooth(a: PackedFloat32Array, r: int, passes: int) -> PackedFloat32Array:
	var x: PackedFloat32Array = a.duplicate()
	var n: int = x.size()
	for _pass: int in passes:
		var y: PackedFloat32Array = PackedFloat32Array()
		y.resize(n)
		for i: int in n:
			var sum: float = 0.0
			var lo: int = maxi(0, i - r)
			var hi: int = mini(n - 1, i + r)
			for k: int in range(lo, hi + 1):
				sum += x[k]
			y[i] = sum / (hi - lo + 1)
		x = y
	return x
