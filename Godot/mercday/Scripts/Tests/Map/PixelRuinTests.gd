class_name PixelRuinTests extends RefCounted

#Ruin kit hash, raw kits, deOverlap and the models.json oracle (C10 T17-T26, C18). Nothing is written.
#Run: godot --headless --path . -- --pixel-ruin-tests

const MODELS_PATH: String = "res://Scripts/Tests/Map/Fixtures/models.json"
const SCATTER_PATH: String = "res://Art/Map/Source/map-scatter.json"

static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var oracle: Variant = JSON.parse_string(FileAccess.get_file_as_string(MODELS_PATH))
	if not (oracle is Dictionary):
		TestFixtures.check(res, "models.json loads", false, "cannot parse " + MODELS_PATH)
		return TestFixtures.summarize(res, "PIXEL RUINS")
	var o: Dictionary = oracle
	_t17(res, o["n_samples"])
	_t18_21(res, o["ruins_raw"])
	_t22(res)
	_t23(res)
	_t24(res)
	_t25(res, o["models"])
	_t26(res, o["ruins_raw"], o["models"])
	return TestFixtures.summarize(res, "PIXEL RUINS")

static func _same(a: Variant, b: Variant) -> bool:
	var an: bool = a is int or a is float
	var bn: bool = b is int or b is float
	if an and bn:
		var fa: float = a
		var fb: float = b
		return absf(fa - fb) <= 1e-6 * maxf(1.0, maxf(absf(fa), absf(fb)))
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var xa: Array = a
		var xb: Array = b
		if xa.size() != xb.size():
			return false
		for i: int in xa.size():
			if not _same(xa[i], xb[i]):
				return false
		return true
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if Array(da.keys()) != Array(db.keys()):
			return false
		for k: Variant in da:
			if not _same(da[k], db[k]):
				return false
		return true
	return a == b

static func _part_diff(id: String, idx: int, want: Dictionary, got: Dictionary) -> String:
	for k: Variant in want:
		if not got.has(k):
			return "%s part %d field %s: want %s got <missing>" % [id, idx, str(k), str(want[k])]
		if not _same(want[k], got[k]):
			return "%s part %d field %s: want %s got %s" % [id, idx, str(k), str(want[k]), str(got[k])]
	for k: Variant in got:
		if not want.has(k):
			return "%s part %d field %s: want <absent> got %s" % [id, idx, str(k), str(got[k])]
	if Array(want.keys()) != Array(got.keys()):
		return "%s part %d key order: want %s got %s" % [id, idx, str(want.keys()), str(got.keys())]
	return ""

static func _parts_diff(id: String, want: Array, parts: Array[PixelPart]) -> String:
	if want.size() != parts.size():
		return "%s part count: want %d got %d" % [id, want.size(), parts.size()]
	for i: int in want.size():
		var why: String = _part_diff(id, i, want[i], parts[i].to_dict())
		if not why.is_empty():
			return why
	return ""

static func _parts_of(rows: Array) -> Array[PixelPart]:
	var out: Array[PixelPart] = []
	for r: Variant in rows:
		out.append(PixelPart.from_dict(r))
	return out

static func _flag(res: Dictionary, label: String, bad: Array[String], total: int) -> void:
	var why: String = "%d of %d failed: %s" % [bad.size(), total, " | ".join(bad.slice(0, 5))]
	TestFixtures.check(res, label, bad.is_empty(), why)

static func _t17(res: Dictionary, rows: Array) -> void:
	var bad: Array[String] = []
	for r: Array in rows:
		var got: float = PixelKitRuins.n(int(r[0]), int(r[1]))
		#Godot JSON can misparse the last bit; n is u / 2^32, so compare the exact uint32.
		var gu: int = int(got * 4294967296.0)
		if float(gu) != got * 4294967296.0 or gu != roundi(float(r[2]) * 4294967296.0):
			bad.append("n(%d, %d) want %s got %s" % [int(r[0]), int(r[1]), str(r[2]), str(got)])
	_flag(res, "T17 n_samples exact", bad, rows.size())
	TestFixtures.check(res, "T17 rows are 258", rows.size() == 258, str(rows.size()))
	TestFixtures.check(res, "T17 n(1, 0)", PixelKitRuins.n(1, 0) == 0.5081244604662061, str(PixelKitRuins.n(1, 0)))
	TestFixtures.check(res, "T17 n(0, 0)", PixelKitRuins.n(0, 0) == 0.0, str(PixelKitRuins.n(0, 0)))

static func _t18_21(res: Dictionary, raw: Dictionary) -> void:
	var bad: Array[String] = []
	for id: String in raw:
		var why: String = _parts_diff(id, raw[id], PixelKitRuins.build_raw(StringName(id)).parts)
		if not why.is_empty():
			bad.append(why)
	_flag(res, "T18-T21 build_raw equals ruins_raw", bad, raw.size())
	TestFixtures.check(res, "T18-T21 ruins_raw holds 26 ids", raw.size() == 26, str(raw.size()))
	var b1: Array[PixelPart] = PixelKitRuins.build_raw(&"cy_b01").parts
	var p0: PixelPart = b1[0]
	var foot: bool = p0.kind == &"box" and p0.x == 5.0 and p0.z == 5.0 and p0.y == -2.0 and p0.w == 6.0
	foot = foot and p0.d == 6.0 and p0.h == 20.0 and p0.tilt == 0.22 and p0.pitch == 0.0
	foot = foot and p0.has_pivot and p0.pivot == Vector3(5.0, 0.0, 5.0) and p0.js_keys.has("pitch")
	TestFixtures.check(res, "T18 cy_b01 R2 foot", foot, str(p0.to_dict()))
	var cells: Array[Vector2] = [Vector2(3, 3), Vector2(3, 5), Vector2(5, 3), Vector2(5, 5), Vector2(5, 7),
		Vector2(7, 3), Vector2(7, 5)]
	var heights: Array[float] = [1.631304, 3.204851, 3.81267, 4.41515, 4.046697, 2.849966, 3.235018]
	var jag_bad: Array[String] = []
	for i: int in 7:
		var q: PixelPart = b1[1 + i]
		if Vector2(q.x, q.z) != cells[i] or absf(q.h - heights[i]) > 5e-6:
			jag_bad.append("stub %d at (%s, %s) h %s" % [i, str(q.x), str(q.z), str(q.h)])
	_flag(res, "T19 cy_b01 jag keeps 7 stubs", jag_bad, 7)
	TestFixtures.check(res, "T19 part 8 follows the stubs", b1[8].w == 5.0 and b1[8].h == 2.0, str(b1[8].to_dict()))
	var rock: PixelPart = b1[9]
	var want: Array[float] = [3.809778, 2.451519, 1.875584, 1.069873, 1.198121]
	var got: Array[float] = [rock.x, rock.z, rock.w, rock.d, rock.h]
	var deb_ok: bool = rock.tint_color == "#6a6460" and rock.y == 0.0
	for i: int in 5:
		deb_ok = deb_ok and absf(got[i] - want[i]) <= 5e-6
	TestFixtures.check(res, "T20 cy_b01 deb rock 0", deb_ok, str(rock.to_dict()))
	var seg: PixelPart = PixelKitRuins.build_raw(&"cy_b02").parts[1]
	var lean_ok: bool = _same(seg.tilt, -0.18911884892608394) and seg.pitch == 0.0 and seg.y == -0.5 and _same(seg.h, 5.2)
	TestFixtures.check(res, "T21 cy_b02 lean tilt and foot", lean_ok, str(seg.to_dict()))

static func _t22(res: Dictionary) -> void:
	var base: Dictionary = {"kind": "box", "x": 5, "z": 5, "y": 0, "w": 6, "d": 6, "h": 1.5}
	var tower: Dictionary = {"kind": "box", "x": 5, "z": 5, "y": 0, "w": 4, "d": 4, "h": 10, "tilt": 0.5, "piv": [5, 0, 5]}
	var parts: Array[PixelPart] = _parts_of([base, tower])
	var out: Array[PixelPart] = PixelKitRuinsOverlap.de_overlap(parts)
	TestFixtures.check(res, "T22 case 1 base dropped", out.size() == 1 and out[0] == parts[1], "kept %d" % out.size())
	var t1: float = out[0].tilt if not out.is_empty() else NAN
	TestFixtures.check(res, "T22 case 1 tower tilt", absf(t1 - 0.02325702372672991) <= 1e-12, str(t1))
	var a: Dictionary = {"kind": "box", "x": 2, "z": 2, "y": 0, "w": 2, "d": 2, "h": 10}
	var b: Dictionary = {"kind": "box", "x": 6, "z": 2, "y": 0, "w": 2, "d": 2, "h": 10, "tilt": 1.0, "piv": [6, 0, 2]}
	var parts2: Array[PixelPart] = _parts_of([a, b])
	var out2: Array[PixelPart] = PixelKitRuinsOverlap.de_overlap(parts2)
	var t2: float = parts2[1].tilt
	TestFixtures.check(res, "T22 case 2 keeps both", out2.size() == 2, "kept %d" % out2.size())
	TestFixtures.check(res, "T22 case 2 settles with tilt", absf(t2 - 0.1897906171230793) <= 1e-12, str(t2))
	TestFixtures.check(res, "T22 case 2 is step 13", absf(t2 - pow(0.88, 13.0)) <= 1e-12, str(t2))

static func _t23(res: Dictionary) -> void:
	var parts: Array[PixelPart] = PixelKitRuins.build(&"cy_b10").parts
	var want: Array[float] = [5.739469, 3.794936, 4.593266, 3.108787, 3.939228, 4.67923]
	var got: Array[String] = []
	var ok: bool = parts.size() > 6
	for i: int in 6:
		if parts.size() > 1 + i:
			got.append(str(parts[1 + i].h))
			ok = ok and absf(parts[1 + i].h - want[i]) <= 5e-6
	TestFixtures.check(res, "T23 cy_b10 ring heights", ok, ", ".join(got))

static func _t24(res: Dictionary) -> void:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCATTER_PATH))
	if not (src is Dictionary) or not (src as Dictionary).has("CYF"):
		TestFixtures.check(res, "T24 CYF loads", false, "missing CYF in " + SCATTER_PATH)
		return
	var tot: float = 0.0
	var sb: float = 0.0
	var ss: float = 0.0
	for row: Array in (src as Dictionary)["CYF"]:
		var w: float = float(row[1])
		tot += w
		if String(row[0]).begins_with("cy_b"):
			sb += w
		elif String(row[0]).begins_with("cy_s"):
			ss += w
	TestFixtures.check(res, "T24 CYF tot 26.35", _same(tot, 26.35), str(tot))
	TestFixtures.check(res, "T24 cy_b weights 9.6", _same(sb, 9.6), str(sb))
	TestFixtures.check(res, "T24 cy_s weights 6.75", _same(ss, 6.75), str(ss))

static func _t25(res: Dictionary, models: Dictionary) -> void:
	var bad: Array[String] = []
	var count: int = 0
	for id: StringName in PixelKitRuins.IDS:
		count += 1
		if not models.has(String(id)):
			bad.append("%s missing in models.json" % id)
			continue
		var want: Dictionary = models[String(id)]
		var m: PixelModel = PixelKitRuins.build(id)
		if not _same(want["W"], m.W) or not _same(want["D"], m.D):
			bad.append("%s W/D: want %s x %s got %s x %s" % [id, str(want["W"]), str(want["D"]), str(m.W), str(m.D)])
			continue
		var why: String = _parts_diff(String(id), want["parts"], m.parts)
		if not why.is_empty():
			bad.append(why)
	_flag(res, "T25 build equals models.json", bad, count)
	TestFixtures.check(res, "T25 41 ruin ids", count == 41, str(count))

static func _t26(res: Dictionary, raw: Dictionary, models: Dictionary) -> void:
	var bad: Array[String] = []
	for id: String in raw:
		var kept: Array[PixelPart] = PixelKitRuinsOverlap.de_overlap(_parts_of(raw[id]))
		var why: String = _parts_diff(id, models[id]["parts"], kept)
		if not why.is_empty():
			bad.append(why)
	_flag(res, "T26 de_overlap of ruins_raw equals models.json", bad, raw.size())
