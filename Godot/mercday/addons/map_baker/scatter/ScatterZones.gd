@tool
class_name ScatterZones extends RefCounted

#Zone lookup for the foliage lattice. Filters: cls, clsNot, tone, nation, region, island, zMax, zMin, near, at, seg, ell, patch.
const CS_SHIFT: int = 3
const CS: int = 1 << CS_SHIFT
const FAR: float = -1.0e9
var counts: Dictionary = {"filter_missing": 0}
var _w: int = 0
var _h: int = 0
var _cw: int = 0
var _ch: int = 0
var _land: PackedByteArray = PackedByteArray()
var _nat: PackedByteArray = PackedByteArray()
var _nat_w: int = 1
var _nat_h: int = 0
var _reg_img: Image = null
var _reg_ids: Dictionary = {}
var _regions: Array = []
var _pts: Dictionary = {}
var _rows: Array[Dictionary] = []
var _comp: Array[Dictionary] = []
var _masks: Dictionary = {}
var _island: PackedByteArray = PackedByteArray()
var _by_name: Dictionary = {}
var _nm: int = 0

func setup(rules: Dictionary, land_codes: PackedByteArray, nation_img: Image, region_img: Image, region: Dictionary,
		labels: Dictionary) -> void:
	_land = land_codes
	_reg_img = region_img
	_regions = region.get("regions", [])
	for r: Dictionary in _regions:
		_reg_ids[Color.html(String(r["color"])).to_rgba32()] = int(r["id"])
	_w = region_img.get_width() if region_img != null else nation_img.get_width() * 2
	_h = region_img.get_height() if region_img != null else nation_img.get_height() * 2
	_nat = nation_img.get_data() if nation_img != null else PackedByteArray()
	_nat_w = nation_img.get_width() if nation_img != null else 1
	_nat_h = int(_nat.size() / float(_nat_w))
	_cw = ceili(float(_w) / CS)
	_ch = ceili(float(_h) / CS)
	for r: Dictionary in labels.get("points", []):
		if not _pts.has(r["name"]):
			_pts[r["name"]] = Vector2(float(r["x"]), float(r["y"]))
	_island = _islands()
	var zones: Array = rules.get("zones", [])
	for zi: int in zones.size():
		var z: Dictionary = (zones[zi] as Dictionary).duplicate()
		z["zi"] = zi
		_rows.append(z)
		_by_name[String(z["name"])] = zi
		if not String(z["name"]).begins_with("class_") and z["name"] != "jungle": _nm = zi + 1
		_comp.append(_compile(zi, z.get("filters", {})))

func zone_at(x: int, z: int, code: int) -> Dictionary:
	var cls: int = code >> 2
	var cbit: int = 1 << cls
	var ci: int = (z >> CS_SHIFT) * _cw + (x >> CS_SHIFT)
	var p: Vector2 = Vector2(x, z)
	for zi: int in _nm:
		var c: Dictionary = _comp[zi]
		if (c["cm"] != 0 and (c["cm"] & cbit) == 0) or (c["xm"] & cbit) != 0 or (c["tm"] != 0 and (c["tm"] & (1 << (code & 3))) == 0):
			continue
		if (c.has("nat") and c["nat"][_nation_at(x, z)] == 0) or (c.has("reg") and c["reg"][_region_at(x, z)] == 0):
			continue
		if (c.has("island") and _island[ci] == 0) or z > c.get("zMax", INF) or z < c.get("zMin", -INF):
			continue
		if _masks.has(zi) and (_masks[zi] as PackedByteArray)[ci] == 0:
			continue
		if c.has("at") and p.distance_to(c["at"]) > c["px"]:
			continue
		if c.has("seg"):
			var v: Vector2 = c["seg"]["b"] - c["seg"]["a"]
			var t: float = clampf((p - c["seg"]["a"]).dot(v) / maxf(v.length_squared(), 1.0e-9), 0.0, 1.0)
			if p.distance_to(c["seg"]["a"] + v * t) > c["seg"]["w"]:
				continue
		if c.has("eo"):
			var d: Vector2 = (p - Vector2(c["eo"])) / Vector2(c["er"])
			if d.x * d.x + d.y * d.y > 1.0:
				continue
		if c.has("patch"):
			var pv: float = MapRng.vn(x / 500.0 + 31.0, z / 500.0 + 17.0)
			if pv < c["patch"][0] or pv >= c["patch"][1]:
				continue
		return _rows[zi]
	var key: String = "jungle" if cls == 2 and z > _h * 0.62 else "class_%d" % cls
	return _rows[_by_name[key]] if _by_name.has(key) else {}

func near_mask(zi: int) -> PackedByteArray:
	return _masks.get(zi, PackedByteArray())

func seg_of(zi: int) -> Dictionary:
	return _comp[zi].get("seg", {}) if zi >= 0 and zi < _comp.size() else {}

func _compile(zi: int, f: Dictionary) -> Dictionary:
	var c: Dictionary = f.duplicate()
	c.merge({"cm": 0, "xm": 0, "tm": 0})
	for k: Array in [["cls", "cm"], ["clsNot", "xm"], ["tone", "tm"]]:
		for q: Variant in f.get(k[0], []):
			c[k[1]] |= 1 << int(q)
	if f.has("nation"):
		c["nat"] = _nation_set(f["nation"])
	if f.has("region") or f.has("regionCat"):
		c["reg"] = _region_set(f.get("region", []), f.get("regionCat", []))
	var near: Dictionary = f.get("near", {})
	c["px"] = float(near.get("px", 0.0))
	var reach: int = ceili(c["px"] / CS)
	if near.has("region"):
		_masks[zi] = _near_cells(_region_set([near["region"]], []), false, reach)
	elif near.has("nation") or near.has("mask"):
		_masks[zi] = _near_cells(_nation_set([near.get("nation", near.get("mask"))]), true, reach)
	if near.has("at"):
		c["at"] = _label(String(near["at"]))
	if f.has("seg"):
		var s: Dictionary = f["seg"]
		c["seg"] = {"a": Vector2(s["a"][0], s["a"][1]), "b": Vector2(s["b"][0], s["b"][1]), "w": float(s["w"])}
	if f.has("ell"):
		var e: Dictionary = f["ell"]
		c["eo"] = _label(String(e["at"])) + Vector2(float(e["dx"]), float(e["dz"]))
		c["er"] = Vector2(float(e["rx"]), float(e["rz"]))
	return c

func _nation_set(names: Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(256)
	for id: int in range(1, 128):
		for q: Variant in names:
			out[id] |= int(MapNations.name_of(id).contains(String(q)))
	return out

func _region_set(names: Array, cats: Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(256)
	for r: Dictionary in _regions:
		if names.has(r.get("name")) or cats.has(r.get("category")):
			out[int(r["id"]) & 255] = 1
	return out

func _nation_at(x: int, z: int) -> int:
	return 0 if _nat.is_empty() else _nat[mini(z >> 1, _nat_h - 1) * _nat_w + mini(x >> 1, _nat_w - 1)] & 0x7F

func _region_at(x: int, z: int) -> int:
	var col: Color = _reg_img.get_pixel(clampi(x, 0, _w - 1), clampi(z, 0, _h - 1)) if _reg_img != null else Color()
	return int(_reg_ids.get(col.to_rgba32(), 0)) if col.a >= 0.5 else 0

func _centre(i: int) -> Vector2i:
	return Vector2i(mini(_w - 1, (i % _cw) * CS + (CS >> 1)), mini(_h - 1, int(i / float(_cw)) * CS + (CS >> 1)))

func _flood(dist: PackedInt32Array, queue: PackedInt32Array, reach: int) -> void:
	var head: int = 0
	while head < queue.size():
		var j: int = queue[head]
		head += 1
		for off: int in [-1, 1, -_cw, _cw]:
			var nb: int = j + off
			var wrap: bool = (off == -1 and j % _cw == 0) or (off == 1 and j % _cw == _cw - 1)
			if (reach >= 0 and dist[j] >= reach) or wrap or nb < 0 or nb >= dist.size() or dist[nb] != -1:
				continue
			dist[nb] = dist[j] + 1
			queue.append(nb)

func _near_cells(ids: PackedByteArray, by_nation: bool, reach: int) -> PackedByteArray:
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(_cw * _ch)
	dist.fill(-1)
	var queue: PackedInt32Array = PackedInt32Array()
	for i: int in dist.size():
		var p: Vector2i = _centre(i)
		var v: int = _nation_at(p.x, p.y) if by_nation else _region_at(p.x, p.y)
		if v > 0 and v < ids.size() and ids[v] != 0:
			dist[i] = 0
			queue.append(i)
	_flood(dist, queue, reach)
	var out: PackedByteArray = PackedByteArray()
	for v: int in dist:
		out.append(1 if v >= 0 else 0)
	return out

func _islands() -> PackedByteArray:
	var n: int = _cw * _ch
	var out: PackedByteArray = PackedByteArray()
	out.resize(n)
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(n)
	for i: int in n:
		var p: Vector2i = _centre(i)
		dist[i] = -1 if p.y * _w + p.x < _land.size() and _land[p.y * _w + p.x] != 255 else -2
	for i: int in n:
		if dist[i] != -1:
			continue
		var queue: PackedInt32Array = PackedInt32Array([i])
		dist[i] = 0
		_flood(dist, queue, -1)
		if queue.size() < 1500:
			for k: int in queue:
				out[k] = 1
	return out

func _label(lname: String) -> Vector2:
	if _pts.has(lname):
		return _pts[lname]
	counts["filter_missing"] = int(counts["filter_missing"]) + 1
	return Vector2(FAR, FAR)
