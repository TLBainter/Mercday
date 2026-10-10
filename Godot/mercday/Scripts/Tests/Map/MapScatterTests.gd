@tool
class_name MapScatterTests extends RefCounted

#C17 scatter, pond, rail and ground cover cases on in-memory fixtures; wave 4 cases skip until their files exist.
#Run: godot --headless --path . -- --map-scatter-tests. Json writers resolve under SCRATCH, which run() clears.

const GCM: String = "res://addons/map_baker/scatter/GroundCoverMeshes.gd"
const BCM: String = "res://addons/map_baker/steps/BakeChunkMerge.gd"
const KITS: String = "res://addons/map_baker/steps/BakeKits.gd"
const FOL_INDEX: String = "props/foliage/index"
const SCRATCH: String = "user://map_scatter_tests/"
const CLEAR: Color = Color(0, 0, 0, 0)
const GRASS_BASE: String = "#6c9e48"
const SHALLOWS: String = "#689cb2"

#Images stay in memory and every non-source key resolves under user://, so no step touches Baked/ through the ctx.
class Ctx extends MapBakeContext:
	func put_image(key: String, img: Image, _save: bool) -> void:
		put_value(key, img)
	func path_of(key: String) -> String:
		if key.begins_with(SOURCE_PREFIX): return super.path_of(key)
		return "user://map_scatter_tests/" + key.replace("/", "_") + ".res"

static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}; DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	_case_baked(res); var ctx: Ctx = Ctx.new(); var d2: Dictionary = ctx.get_value(BakeScatterRules.SCATTER_KEY)
	var pk: Dictionary = BakePalette.pack(ctx.get_value(BakePalette.LAND_KEY), ctx.get_value(BakePalette.WATER_KEY))
	var rules: Dictionary = BakeScatterRules.build(d2, pk["table"]); _case_rules(res, d2, rules); _case_wave4(res, d2)
	_case_zones(res); _case_grid(res, rules); _case_scatter(res, rules); _case_ground(res, rules); _case_sort(res)
	_case_ponds(res); _case_pond_bake(res); _case_runner(res); _case_rail(res)
	var dir: String = ProjectSettings.globalize_path(SCRATCH)
	for f: String in DirAccess.get_files_at(dir): DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	return TestFixtures.summarize(res, "MAP SCATTER")
static func _rows(res: Dictionary, rows: Array) -> void:
	for row: Array in rows:
		TestFixtures.check(res, str(row[0]), row[1] == row[2], "got %s want %s" % [str(row[1]), str(row[2])])
static func _near(a: float, b: float, tol: float = 1e-6) -> bool:
	return absf(a - b) <= tol * maxf(1.0, maxf(absf(a), absf(b)))
static func _built(res: Dictionary, tn: String, path: String) -> bool:
	if ResourceLoader.exists(path): return true
	print("SKIP %s | %s not built (wave 4)" % [tn, path]); res["pass"] = int(res["pass"]) + 1; return false
static func _r8(w: int, h: int, v: int, cells: Dictionary = {}) -> Image:
	var d: PackedByteArray = PackedByteArray(); d.resize(w * h); d.fill(v)
	for j: int in cells: d[j] = int(cells[j])
	return Image.create_from_data(w, h, false, Image.FORMAT_R8, d)
static func _rgba(w: int, h: int, c: Color) -> Image:
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8); img.fill(c); return img
static func _ints(v: Variant) -> Array:
	var out: Array = []
	for x: Variant in (v if v != null else []): out.append(int(x))
	return out
static func _deep(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return a == b if a is int and b is int else _near(float(a), float(b))
	if a is Array and b is Array:
		var ok: bool = (a as Array).size() == (b as Array).size()
		for i: int in mini((a as Array).size(), (b as Array).size()): ok = ok and _deep(a[i], b[i])
		return ok
	if a is Dictionary and b is Dictionary:
		var same: bool = (a as Dictionary).size() == (b as Dictionary).size()
		for k: Variant in b: same = same and (a as Dictionary).has(k) and _deep(a[k], b[k])
		return same
	return str(a) == str(b)
static func _water_only(fs: MapPlacementSet, c: Vector2i) -> bool:
	var r: Vector2i = fs.range_of(c) if fs != null else Vector2i.ZERO; var ok: bool = fs != null
	for i: int in range(r.x, r.y): ok = ok and fs.model_of(i).begins_with("w_")
	return ok
static func _ice_only(gi: MapChunkIndex, i: int) -> bool:
	var ok: bool = i < gi.paths.size() and ResourceLoader.exists(gi.paths[i])
	var ch: MapInstanceChunk = load(gi.paths[i]) as MapInstanceChunk if ok else null
	return ch != null and ch.models == PackedStringArray(["ice"])
static func _case_baked(res: Dictionary) -> void:
	var b: String = MapData.BAKED_DIR
	if _built(res, "T16", b + FOL_INDEX + ".tres") and MapTestFixtures.require_baked(res, FOL_INDEX):
		var fi: MapChunkIndex = load(b + FOL_INDEX + ".tres") as MapChunkIndex
		var ti: MapChunkIndex = load(MapData.TERRAIN_INDEX) as MapChunkIndex; var sub: bool = fi != null and ti != null
		var occ: Image = load(b + "scatter_occ.res") as Image
		var fol: MapPlacementSet = load(b + "place_foliage.res") as MapPlacementSet
		var fs: MapPlacementSet = fol.duplicate() as MapPlacementSet if fol != null else null
		if fs != null: fs.sort_by_chunk()
		for c: Vector2 in (fi.coords if sub else PackedVector2Array()):
			sub = sub and (ti.coords.has(c) or _water_only(fs, Vector2i(c)))
		var gi: MapChunkIndex = load(b + "props/ground/index.tres") as MapChunkIndex; var gok: bool = gi != null and ti != null
		for i: int in (gi.coords.size() if gok else 0): gok = gok and (ti.coords.has(gi.coords[i]) or _ice_only(gi, i))
		var kits_ok: bool = fol != null and fol.count() > 0; var want: PackedVector2Array = PackedVector2Array()
		var cs: PackedInt32Array = fs.chunk_starts if fs != null else PackedInt32Array()
		for k: int in maxi(0, cs.size() - 1):
			if cs[k + 1] > cs[k]: want.append(Vector2(k % MapConst.CHUNKS_X, int(k / float(MapConst.CHUNKS_X))))
		var got: PackedVector2Array = fi.coords.duplicate() if fi != null else PackedVector2Array(); got.sort(); want.sort()
		for m: String in (fol.models if fol != null else PackedStringArray()):
			kits_ok = kits_ok and FileAccess.file_exists(b + "kits/" + m + ".res")
		_rows(res, [["T16 foliage coords in terrain or water", sub, true], ["T16 ground coords in terrain or ice", gok, true],
			["T16 coords from starts", got, want],
			["T16 verts", fi != null and fi.total_verts() > 0, true], ["T16 kits", kits_ok, true],
			["T16 scatter_occ", [occ.get_size(), occ.get_format()] if occ != null else [], [Vector2i(2848, 1480), Image.FORMAT_L8]]])
	if MapTestFixtures.require_baked(res, "rail_aligned"):
		var al: Variant = JSON.parse_string(FileAccess.get_file_as_string(b + "rail_aligned.json"))
		var rp: String = MapBakeContext.SOURCE_DIR + "map-paths-railroad.json"
		var sj: Variant = JSON.parse_string(FileAccess.get_file_as_string(rp))
		var lines: Array = al if al is Array else []; var src: Array = sj["lines"] if sj is Dictionary else []
		var ends: bool = lines.size() == src.size()
		for i: int in mini(lines.size(), src.size()):
			var pts: Array = lines[i]["pts"]; var sp: Array = src[i]["points"]; var n: int = pts.size()
			ends = ends and _near(pts[0], sp[0][0]) and _near(pts[1], sp[0][1])
			ends = ends and _near(pts[n - 2], sp[-1][0]) and _near(pts[n - 1], sp[-1][1])
		_rows(res, [["T36 lines", lines.size(), 14], ["T36 end points", ends, true]])
static func _case_rules(res: Dictionary, d2: Dictionary, rules: Dictionary) -> void:
	var fz: Array = d2["FOLIAGE_ZONES"]; var zones: Array = rules["zones"]; var tot_ok: bool = true
	for z: Dictionary in zones:
		var sum: float = 0.0
		for k: Array in z["kits"]: sum += float(k[1])
		tot_ok = tot_ok and _near(float(z["tot"]), sum)
	var names: Array = zones.slice(0, fz.size()).map(func(z: Dictionary) -> String: return String(z["name"]))
	var ids: Array = fz.map(func(z: Dictionary) -> String: return String(z["id"]))
	_rows(res, [["T4 zones", fz.size(), 56], ["T4 order", names, ids], ["T4 tot", tot_ok, true],
		["T20 scat_ids", [rules["scat_ids"].has("w_lily"), rules["scat_ids"].has("f_reeds")], [true, true]]])
static func _quads(nq: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: int in nq:
		for c: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			st.set_color(Color.WHITE); st.set_normal(Vector3.BACK); st.set_uv(c)
			st.add_vertex(Vector3(c.x + q * 0.01, c.y, 0.0))
		for t: int in [0, 1, 2, 0, 2, 3]: st.add_index(q * 4 + t)
	return st.commit()
static func _per_instance(vals: Array, k: int) -> bool:
	var ok: bool = vals.size() == 2 * k
	for i: int in vals.size(): ok = ok and vals[i] == vals[i - i % k]
	return ok
static func _case_wave4(res: Dictionary, d2: Dictionary) -> void:
	if _built(res, "T1-T3", GCM):
		var g: Script = load(GCM) as Script; var q: Array = d2["GV"]["grass"][0]; var xs: Array = [[], []]
		for m: int in 2:
			var mm: ArrayMesh = g.call("mesh", "grass", 0, m, q)
			for v: Vector3 in mm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: xs[m].append(v.x if m == 0 else -v.x)
			xs[m].sort()
		var mir: bool = xs[0].size() == xs[1].size(); var top: float = 0.0
		for i: int in mini(xs[0].size(), xs[1].size()):
			mir = mir and _near(xs[1][i], xs[0][i]); top = maxf(top, absf(xs[0][i]))
		_rows(res, [["T1 GV", _deep(g.call("variants", d2["GS"]), d2["GV"]), true],
			["T2 blades", q.size(), 4 + floori(MapRng.hh(100, 1) * 4.0)], ["T3 mirror", mir, true],
			["T3 nonzero", top > 1e-4, true]])
	if not _built(res, "T18 T39 T40", BCM): return
	var b: Script = load(BCM) as Script; var o: Vector2 = Vector2(10, 10)
	var nat: Image = _r8(MapConst.BLOCKS_X, MapConst.BLOCKS_Y, 5)
	var two: MapPlacementSet = MapPlacementSet.new(); var three: MapPlacementSet = MapPlacementSet.new()
	for i: int in 3:
		var p3: Vector3 = Vector3(o.x + 40.0 * i, 1.0, o.y + 20.0 * i); three.add(&"k20k", p3, 0.0, 1.0, Vector4i.ZERO)
		if i < 2: two.add(&"k16", p3, 0.0, 1.0, Vector4i.ZERO)
	var before: PackedFloat32Array = two.xform.duplicate()
	var m2: ArrayMesh = b.call("merge", two, Vector2i.ZERO, {"k16": _quads(4)}, nat)
	var arr: Array = m2.surface_get_arrays(0) if m2 != null and m2.get_surface_count() > 0 else []; var u: Array = []
	var cu: Array = []
	if arr.size() == Mesh.ARRAY_MAX and arr[Mesh.ARRAY_TEX_UV2] is PackedVector2Array:
		for e: Vector2 in arr[Mesh.ARRAY_TEX_UV2]: u.append(e.y)
	if arr.size() == Mesh.ARRAY_MAX and arr[Mesh.ARRAY_CUSTOM0] is PackedByteArray:
		for i: int in range(0, (arr[Mesh.ARRAY_CUSTOM0] as PackedByteArray).size(), 4): cu.append(arr[Mesh.ARRAY_CUSTOM0][i])
	var m3: ArrayMesh = b.call("merge", three, Vector2i.ZERO, {"k20k": _quads(5000)}, nat); var lens: Array = []
	var uvh: bool = u.size() == 32
	for i: int in mini(2, u.size() >> 4):
		uvh = uvh and _near(u[i * 16], MapRng.hh(int(before[5 * i]), int(before[5 * i + 2])) * 6.2832)
	for s: int in (m3.get_surface_count() if m3 != null else 0): lens.append(m3.surface_get_array_len(s))
	var many: PackedInt32Array = PackedInt32Array(); many.resize(2501); many.fill(16)
	var full: PackedInt32Array = PackedInt32Array(); full.resize(257); full.fill(40000)
	var cap: int = MapConst.PROPS_CHUNK_VERTS
	_rows(res, [["T18 verts", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() if arr.size() > 0 else 0, 32],
		["T18 UV2.y per instance", _per_instance(u, 16), true], ["T18 CUSTOM0.x per instance", _per_instance(cu, 16), true],
		["T18 CUSTOM0.x nation", [cu.size(), cu.count(5)], [32, 32]], ["T18 UV2.y hash", uvh, true],
		["T18 input unchanged", two.xform == before, true],
		["T39 plan 2501 x 16", _ints(b.call("plan_surfaces", many, 40000)["counts"]), [40000, 16]],
		["T39 plan 3", _ints(b.call("plan_surfaces", PackedInt32Array([30000, 20000, 10000]), 40000)["counts"]),
			[30000, 30000]],
		["T39 merge surfaces", lens, _ints(b.call("plan_surfaces", PackedInt32Array([20000, 20000, 20000]), cap)["counts"])],
		["T39 two surfaces", lens.size(), 2],
		["T40 kit over cap", String(b.call("plan_surfaces", PackedInt32Array([40001]), 40000)["error"]).contains("40001"),
			true], ["T40 surfaces", String(b.call("plan_surfaces", full, 40000)["error"]).contains("257 surfaces"), true]])
static func _zn(f: Dictionary, x: int, z: int, code: int, w: int = 64, codes: PackedByteArray = PackedByteArray(),
		reg_img: Image = null, reg: Dictionary = {}) -> String:
	var lc: PackedByteArray = codes if not codes.is_empty() else _r8(w, w, 1).get_data()
	var zs: ScatterZones = ScatterZones.new()
	zs.setup({"zones": [{"name": "t", "kits": [], "filters": f}, {"name": "class_0", "kits": [], "filters": {}}]}, lc,
		_r8(w >> 1, w >> 1, 0), reg_img, reg, {"points": []})
	return String(zs.zone_at(x, z, code).get("name", ""))
static func _case_zones(res: Dictionary) -> void:
	var p: float = MapRng.vn(10 / 500.0 + 31.0, 10 / 500.0 + 17.0); var isl: PackedByteArray = _r8(480, 480, 255).get_data()
	for r: Rect2i in [Rect2i(8, 8, 40, 40), Rect2i(64, 64, 400, 400)]:
		for z: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x): isl[z * 480 + x] = 1
	var reg: Image = _rgba(160, 160, CLEAR); reg.set_pixel(100, 100, Color("#1eff96"))
	var rj: Dictionary = {"regions": [{"id": 1, "name": "Zed", "category": "plains", "color": "#1eff96"}]}
	var nf: Dictionary = {"near": {"region": "Zed", "px": 16}}; var none: PackedByteArray = PackedByteArray()
	_rows(res, [["T5 cls in", _zn({"cls": [0]}, 10, 10, 1), "t"], ["T5 cls out", _zn({"cls": [0]}, 10, 10, 5), ""],
		["T5 clsNot in", _zn({"clsNot": [5]}, 10, 10, 1), "t"], ["T5 clsNot out", _zn({"clsNot": [5]}, 10, 10, 21), ""],
		["T5 tone in", _zn({"tone": [2]}, 10, 10, 2), "t"], ["T5 tone out", _zn({"tone": [2]}, 10, 10, 1), "class_0"],
		["T5 zMax in", _zn({"zMax": 30}, 10, 30, 1), "t"], ["T5 zMax out", _zn({"zMax": 30}, 10, 31, 1), "class_0"],
		["T5 patch lo", _zn({"patch": [p, p + 1e-6]}, 10, 10, 1), "t"],
		["T5 patch hi", _zn({"patch": [p - 1e-6, p]}, 10, 10, 1), "class_0"],
		["T5 patch above", _zn({"patch": [p + 1e-6, p + 0.05]}, 10, 10, 1), "class_0"],
		["T6 small island", _zn({"island": true}, 28, 28, 1, 480, isl), "t"],
		["T6 large land", _zn({"island": true}, 264, 264, 1, 480, isl), "class_0"],
		["T7 near in", _zn(nf, 116, 100, 1, 160, none, reg, rj), "t"],
		["T7 near out", _zn(nf, 124, 100, 1, 160, none, reg, rj), "class_0"]])
static func _grid(rules: Dictionary, n: int, lv: int, cells: Dictionary = {}) -> ScatterGrid:
	var g: ScatterGrid = ScatterGrid.new()
	g.setup(_r8(n, n, lv, cells), _r8(n, n, 0), _r8(n, n, 0), null, null, rules, MapPlacementSet.new())
	for id: String in ["t_box", "cy_b01", "cy_s01", "f_reeds", "t_one"]:
		var s: float = 3.0 if id == "f_reeds" else (1.0 if id == "t_one" else 2.0)
		g.kits[id] = {"W": s, "D": s, "ext": [], "tilted": false}
	return g
static func _spr(rules: Dictionary, id: StringName, a: int, b: int) -> Dictionary:
	var g: ScatterGrid = _grid(rules, 64, a, {3186: b, 3250: b}); var c: Dictionary = {"ok": g.prop(id, 100, 100)}
	c.merge(g.counts); return c
static func _case_grid(res: Dictionary, rules: Dictionary) -> void:
	var g: ScatterGrid = _grid(rules, 64, 6); var first: bool = g.prop(&"t_box", 100, 100)
	var marked: bool = g.occ.count(3) == 4
	for j: int in [3185, 3186, 3249, 3250]: marked = marked and g.occ[j] == 3
	var k: Array = [["a", 1], ["b", 3]]; g.rail[5] = 2; g.rail[6] = 1; var s6: Dictionary = _spr(rules, &"cy_b01", 2, 6)
	var gk: ScatterGrid = _grid(rules, 4, 6); var slab: Array = gk.kit_of(&"p_slab").get("ext", [])
	var kv: Array = [gk.kit_of(&"f_oak"), gk.kit_of(&"f_oak#1")]; var kk: bool = gk.kits.has(&"f_oak") and gk.kits.has(&"f_oak#1")
	_rows(res, [["T8 jitter", BakeScatter.jitter(9, 15), Vector2i(10, 17)],
		["T9 q 0.5", MapRng.pick(k, 0.125), "a"], ["T9 q 1.0", MapRng.pick(k, 0.25), "a"],
		["T9 q 3.99", MapRng.pick(k, 3.99 / 4.0), "b"], ["T9 q 4.5", MapRng.pick(k, 1.125), "a"],
		["T10 prop", first, true], ["T10 cells", marked, true], ["T10 blocked", g.prop(&"t_box", 101, 100), false],
		["T11 flat 2/4", _spr(rules, &"t_box", 2, 4)["ok"], false],
		["T11 cy_b 2/4", _spr(rules, &"cy_b01", 2, 4)["ok"], true], ["T38 cy_s 2/4", _spr(rules, &"cy_s01", 2, 4)["ok"], false],
		["T38 cy_b 2/5", _spr(rules, &"cy_b01", 2, 5)["ok"], true],
		["T38 cy_b 2/6", [s6["ok"], s6["spread"], s6["blocked"]], [false, 1, 0]],
		["T10 p_slab ext", slab.size() == 4 and _near(float(slab[0]), -1.99778, 1e-4), true], ["T10 variant keys", kk, true],
		["T10 variant footprint", [kv[0]["W"], kv[0]["D"], kv[0]["ext"]] != [kv[1]["W"], kv[1]["D"], kv[1]["ext"]], true],
		["T37 rail 2", g.free_at(5), false], ["T37 rail 1", [g.free_at(6), g.near_at(6)], [true, true]]])
static func _scatter_run(rules: Dictionary) -> MapPlacementSet:
	var ctx: Ctx = Ctx.new(); var land: Image = _rgba(192, 192, CLEAR); land.fill_rect(Rect2i(0, 0, 64, 192), Color(GRASS_BASE))
	var water: Image = _rgba(192, 192, Color(SHALLOWS)); water.fill_rect(Rect2i(0, 0, 64, 192), CLEAR); var lv: Dictionary = {}
	for j: int in 96 * 96:
		if j % 96 < 32: lv[j] = 6
	lv[40 * 96 + 10] = 6 | MapConst.POND_BIT
	for kv: Array in [["scatter_rules", rules], [BakeCellColor.LAND_KEY, land], [BakeCellColor.WATER_KEY, water],
			["block_level", _r8(96, 96, 0, lv)], ["block_nation", _r8(96, 96, 0)], ["river_mask", _r8(96, 96, 0, {50 * 96 + 10: 1})],
			["rail_mask", _r8(96, 96, 0)], ["src/map-region.png", _rgba(192, 192, CLEAR)],
			["src/map-region.json", {"regions": []}], ["src/map-label-points.json", {"points": []}]]:
		ctx.put_value(kv[0], kv[1])
	return ctx.get_value("place_foliage") as MapPlacementSet if BakeScatter.new().run(ctx) else null
static func _case_scatter(res: Dictionary, rules: Dictionary) -> void:
	var wr: Dictionary = {"water": {"shallow": {"re": "shallow", "flags": "i"}, "d": 0.5, "k": [["t_one", 1]]},
		"water_palette": [{"name": "Shallows", "cls": 3}]}
	var lv: Dictionary = {}; var rg: ScatterGrid = ScatterGrid.new(); var rs: ScatterWater = ScatterWater.new()
	for j: int in 1024:
		if (j & 31) < 8: lv[j] = 6
	rg.setup(_r8(2, 2, BakeHeightBlocks.block_level(0.5, true)), _r8(2, 2, 1), _r8(2, 2, 0), null, null, rules,
		MapPlacementSet.new()); rs.setup(rg, PackedByteArray()); var t: float = MapConst.TERRACE
	var g: ScatterGrid = _grid(wr, 32, 0, lv); var sw: ScatterWater = ScatterWater.new()
	sw.setup(g, _r8(64, 64, 13).get_data()); var placed: int = sw.water(); var want: int = 0
	for z: int in range(5, 59, 10):
		for x: int in range(5, 59, 10):
			var jx: int = x + floori(MapRng.hh(x + 3, z) * 7) - 3; var jz: int = z + floori(MapRng.hh(x, z + 5) * 7) - 3
			var r: Vector4i = ScatterGrid.span(g.kits["t_one"], jx, jz)
			var ok: bool = MapRng.hh(jx * 7 + 3, jz * 3 + 1) <= 0.5 and r.x >= 0 and r.y >= 0 and r.z < 32 and r.w < 32
			for zz: int in range(r.y, r.w + 1):
				for xx: int in range(r.x, r.z + 1): ok = ok and g.lvl[zz * 32 + xx] == 0
			want += 1 if ok else 0
	var a: MapPlacementSet = _scatter_run(rules); var b: MapPlacementSet = _scatter_run(rules)
	var same: bool = a != null and b != null and a.xform == b.xform and a.model_idx == b.model_idx and a.models == b.models
	same = same and a.zone == b.zone and a.tag == b.tag and a.color == b.color
	_rows(res, [["T12 water", placed, want], ["T12 some", want > 0, true], ["T15 deterministic", same, true],
		["T15 placed", a != null and a.count() > 0, true],
		["T12 river top", _near(rs.rtop(0), maxf(MapConst.WATER_H, floorf(0.5 / t) * t - t)), true]])
static func _gc(rules: Dictionary, n: int, lv: int, cells: Dictionary, rail: Dictionary) -> BakeGroundCover:
	var bg: BakeGroundCover = BakeGroundCover.new(); bg._grid = _grid(rules, n, lv, cells)
	for j: int in rail: bg._grid.rail[j] = int(rail[j])
	bg._sw = ScatterWater.new(); bg._sw.setup(bg._grid, PackedByteArray()); bg._socc = _r8(n, n, 0).get_data(); return bg
static func _ground(rules: Dictionary, rail: Dictionary, code: int = 0, meadow: int = 0) -> Dictionary:
	var bg: BakeGroundCover = _gc(rules, 16, 6, {}, rail); var ps: MapPlacementSet = bg._grid.set
	bg.ground(_r8(32, 32, code).get_data(), {}, _r8(32, 32, meadow).get_data(), {}); var out: Dictionary = {}
	for i: int in ps.count():
		var p: Vector3 = ps.pos(i)
		out[(int(p.z) >> 1) * 16 + (int(p.x) >> 1)] = [int(ps.model_of(i).get_slice("/", 2)), p.x, ps.model_of(i), ps.zone[i], p.y]
	return out
static func _ice_n(rules: Dictionary, code: int) -> int:
	var bg: BakeGroundCover = _gc(rules, 300, 0, {}, {}); var wi: Image = _r8(600, 600, 255)
	wi.fill_rect(Rect2i(30, 500, 540, 80), Color8(code, 0, 0)); bg.ice(wi.get_data(), {"water_classes": {"Icy Sea": 149}})
	return range(bg._grid.set.count()).filter(func(i: int) -> bool: return bg._grid.set.pos(i).z >= MapConst.PAD_T).size()
static func _case_ground(res: Dictionary, rules: Dictionary) -> void:
	var base: Dictionary = _ground(rules, {}); var ok: bool = true; var want: int = 0; var t: float = MapConst.TERRACE
	var c3: Dictionary = _ground(rules, {}, 12); var md: Dictionary = _ground(rules, {}, 0, 1); var mok: Array = [true, 0]
	var gy: float = MapSpace.height_to_y(maxf(MapConst.WATER_H + t, MapRng.jround(MapSpace.level_height(6) / t) * t)) + 0.02
	for cz: int in range(2, 14):
		for cx: int in range(2, 14):
			var j: int = cz * 16 + cx; var fl: bool = MapRng.hh(cx + 29, cz + 31) < 0.4
			var v: int = floori(MapRng.hh(cx + 17, cz + 23) * 12.0); var mi: int = 1 if MapRng.hh(cx + 61, cz + 67) < 0.5 else 0
			mok[0] = mok[0] and c3.has(j) == (MapRng.hh(cx * 3 + 11, cz * 7 + 5) <= 0.35) and md.has(j) == base.has(j)
			if md.has(j):
				mok[0] = mok[0] and md[j][2] == "g/%s/%d/%d" % ["flowers" if fl else "grass", v, mi]
				mok[0] = mok[0] and md[j][3] == (1 if fl else 0) and _near(md[j][4], gy); mok[1] += 1 if fl else 0
			if MapRng.hh(cx * 3 + 11, cz * 7 + 5) <= 0.8:
				want += 1; ok = ok and base.has(j) and base[j][0] == v
				ok = ok and _near(base[j][1], cx * 2 + 1 + (MapRng.hh(cx + 5, cz + 3) - 0.5) * 0.6)
	var p0: float = float((rules.get("gs_ice", {}) as Dictionary).get("p0", 0.03)); var iw: int = 0
	for z: int in range(500, 600, 10):
		for x: int in range(0, 600, 10):
			var jx: int = x + floori(MapRng.hh(x, z + 77) * 6); var jz: int = z + floori(MapRng.hh(x + 77, z) * 6)
			iw += 1 if Rect2i(30, 500, 540, 80).has_point(Vector2i(jx, jz)) and MapRng.hh(jx * 3, jz * 5 + 1) <= p0 else 0
	var kept: Array = base.keys(); kept.sort(); var r2: Dictionary = _ground(rules, {int(kept[0]) + 1: 2, int(kept[-1]) - 1: 1})
	var bi: BakeGroundCover = _gc(rules, 32, 0, {0: 6}, {})
	var ty_ok: bool = bi.ice(_r8(64, 64, 0).get_data(), {"water_classes": {"Icy Sea": 149}}) > 0
	for i: int in bi._grid.set.count():
		var ty: int = int(bi._grid.set.model_of(i).get_slice("/", 1))
		ty_ok = ty_ok and ty >= 0 and ty <= 6 and bi._grid.set.pos(i).z < MapConst.PAD_T
	_rows(res, [["T13 kept count", base.size(), want], ["T13 v and ox", ok, true],
		["T13 cell 4 4", base.has(68), MapRng.hh(23, 33) <= 0.8], ["T37 rail 2 neighbour", r2.has(kept[0]), false],
		["T37 rail 1 neighbour", r2.has(kept[-1]), true], ["T14 land", bi._open(1, 1), false],
		["T14 sea", bi._open(40, 40), true], ["T14 dense ice", ty_ok, true],
		["T13 forest and meadow", [mok[0], mok[1] > 0], [true, true]],
		["T14 icy iff hh <= p", [_ice_n(rules, 20), iw > 0], [iw, true]], ["T14 non-icy sea", _ice_n(rules, 4), 0]])
static func _case_sort(res: Dictionary) -> void:
	var ps: MapPlacementSet = MapPlacementSet.new(); var cp: int = MapConst.CHUNK_PX
	for v: Vector2 in [Vector2(10, 10), Vector2(cp + 10, 10), Vector2(20, 10), Vector2(10, cp + 10), Vector2(cp + 20, 10)]:
		ps.add(&"a", Vector3(v.x, 0.0, v.y), float(ps.count()), 1.0, Vector4i.ZERO)
	ps.sort_by_chunk(); var yaws: Array = []; var one: MapPlacementSet = MapPlacementSet.new()
	for i: int in 5: yaws.append(int(ps.xform[5 * i + 3]))
	one.add(&"a", Vector3(900, 0.0, 600), 0.0, 1.0, Vector4i.ZERO); var g: ScatterGrid = _grid({}, 4, 6); var xs: Array = []
	for v: Vector2i in [Vector2i(300, 10), Vector2i(10, 10), Vector2i(20, 300), Vector2i(310, 20), Vector2i(30, 10)]:
		g.place(&"a", v.x, 0.5, v.y, -1)
	g.set.sort_by_chunk()
	for i: int in g.set.count(): xs.append([int(g.set.pos(i).x), g.set.chunk_of(i)])
	_rows(res, [["T17 order", yaws, [0, 2, 1, 4, 3]], ["T17 ranges", [ps.range_of(Vector2i(0, 0)),
		ps.range_of(Vector2i(1, 0)), ps.range_of(Vector2i(0, 1))], [Vector2i(0, 2), Vector2i(2, 4), Vector2i(4, 5)]],
		["T17 starts", ps.chunk_starts.size(), MapConst.CHUNKS_X * MapConst.CHUNKS_Y + 1],
		["T17 chunk of px", one.chunk_of(0), 2 * MapConst.CHUNKS_X + 3],
		["T17 place order", xs, [[10, 0], [30, 0], [300, 1], [310, 1], [20, MapConst.CHUNKS_X]]]])
static func _pond(cells: Dictionary = {}, wc: PackedByteArray = PackedByteArray()) -> ScatterPonds:
	var p: ScatterPonds = ScatterPonds.new(); p.setup(_grid({}, 64, 6, cells), wc, {}); return p
static func _cells(p: ScatterPonds) -> Array:
	var out: Array = []
	for j: int in p._grid.pond.size():
		if p._grid.pond[j] != 0: out.append(j)
	return out
static func _at(p: ScatterPonds, model: String, want: Array) -> bool:
	var got: Array = []
	for i: int in p._grid.set.count():
		if p._grid.set.model_of(i) == model: got.append(Vector2(p._grid.set.pos(i).x, p._grid.set.pos(i).z))
	var ok: bool = got.size() == want.size()
	for i: int in mini(got.size(), want.size()):
		var w: Vector2 = want[i] + Vector2(0, ScatterPonds.LILY_DZ); ok = ok and _near(got[i].x, w.x) and _near(got[i].y, w.y)
	return ok
static func _lily(j: int) -> Vector2:
	return Vector2((j & 63) * 2 + 1, (j >> 6) * 2 + 1)
static func _case_ponds(res: Dictionary) -> void:
	var t: float = MapConst.TERRACE; var pw: ScatterPonds = _pond(); var pm: ScatterPonds = _pond()
	var pb: ScatterPonds = _pond()
	var ok: Array = [pw.carve(64, 64, true, 0), pm.carve(64, 64, false, 0), pb.carve(41, 77, true, 0)]
	var c9: Array = [2015, 2016, 2017, 2079, 2080, 2081, 2082, 2143, 2144]; var cb: Array = _cells(pb)
	var ly: float = MapSpace.height_to_y(maxf(MapConst.WATER_H + t, MapSpace.level_height(6)) - 0.3 * t + 0.01 * t)
	var rej: bool = true
	for k: int in 4:
		var p: ScatterPonds = _pond({2083: 7} if k == 0 else {}); var g: ScatterGrid = p._grid
		if k == 1: g.dry0[2083] = 0
		if k == 2: g.occ[2080] = 3
		var snap: Array = [g.occ.duplicate(), g.pond.duplicate(), g.paint.duplicate()]
		rej = rej and not p.carve(6 if k == 3 else 64, 64, true, 0) and snap == [g.occ, g.pond, g.paint]
		rej = rej and g.set.count() == 0
	var pe: ScatterPonds = _pond(); pe._grid.occ[2083] = 3; var bfs: bool = _pond({}, _wc_img(13, -1))._wc.count(13) == 256
	var keys: Array = []; var lsc: Array = []
	for i: int in pw._grid.set.count():
		if pw._grid.set.model_of(i) == "w_lily": lsc.append(pw._grid.set.xform[5 * i + 4])
	for pair: int in [15, 14]:
		var wq: PackedInt32Array = _pond({}, _wc_img(5, pair))._wc
		for i: int in 256: bfs = bfs and wq[i] == (5 if (i & 15) <= 7 else 9)
	for x: int in [40, 88, 60]:
		var pk: ScatterPonds = _pond({}, _wc_img(5, 14))
		keys.append(pk._grid.pond[pk._grid.j_at(x, 64)] if pk.carve(x, 64, true, 0) else -1)
	_rows(res, [["T19 carve", ok, [true, true, true]], ["T19 cells", _cells(pw), c9], ["T19 key", pw._grid.pond[2080], 2],
		["T20 lilies", _at(pw, "w_lily", [Vector2(67, 65), Vector2(67, 65)]), true],
		["T20 y", _near(pw._grid.set.pos(0).y, ly), true], ["T20 lily scale", lsc, [1.0, 1.0]],
		["T21 wet reeds", _at(pw, "f_reeds", [Vector2(58, 65), Vector2(65, 74), Vector2(65, 57)]), true],
		["T21 mud", [_cells(pm), pm._grid.pond[2080], _at(pm, "w_lily", [])], [c9, 1, true]],
		["T21 mud reeds", _at(pm, "f_reeds", [Vector2(58, 65)]), true],
		["T22 cells", [cb.size(), cb[0] if cb.size() > 0 else -1, cb[-1] if cb.size() > 0 else -1], [33, 2258, 2708]],
		["T22 lilies", _at(pb, "w_lily", [_lily(2385), _lily(2325), _lily(2323)]), true],
		["T22 reeds", _at(pb, "f_reeds", [Vector2(39, 67), Vector2(30, 76), Vector2(51, 81)]), true],
		["T23 rejections", rej, true], ["T23 occupied ring", [pe.carve(64, 64, true, 0), _cells(pe).size()], [true, 9]],
		["T25 BFS", bfs, true], ["T25 keys", keys, [9, 13, 9]]])
static func _wc_img(a: int, i_b: int) -> PackedByteArray:
	var d: PackedByteArray = _r8(128, 128, 255).get_data(); d[4 * 128 + 4] = a
	if i_b >= 0: d[4 * 128 + i_b * 8 + 4] = 9
	return d
static func _rgb(img: Image, i: int) -> Array:
	var c: Color = img.get_pixel(i, 0); return [c.r8, c.g8, c.b8]
static func _case_pond_bake(res: Dictionary) -> void:
	var ctx: Ctx = Ctx.new()
	var pk: Dictionary = BakePalette.pack(ctx.get_value(BakePalette.LAND_KEY), ctx.get_value(BakePalette.WATER_KEY))
	var p2: Dictionary = BakePalette.pack(ctx.get_value(BakePalette.LAND_KEY), ctx.get_value(BakePalette.WATER_KEY))
	var fresh: Dictionary = BakePalette.pack(ctx.get_value(BakePalette.LAND_KEY), ctx.get_value(BakePalette.WATER_KEY))
	var img: Image = pk["image"]; var hex0: Dictionary = (p2["table"]["hex"] as Dictionary).duplicate()
	var spare: Array = range(BakePalette.EMPTY_INDEX).filter(func(i: int) -> bool: return hex0.find_key(i) == null)
	var lk: int = 4 + int(hex0.get("#40808c", 0)) - BakePalette.WATER_BASE
	TestFixtures.check(res, "T28 lake hex", hex0.has("#40808c"), "palette has no #40808c")
	var ov: Array = [BakePalette.pond_slots(img, pk["table"], [1, 2, lk]), BakePalette.pond_slots(p2["image"], p2["table"],
		[1, 2, 17])]
	var pond: Dictionary = pk["table"]["pond"]; var s2: Dictionary = p2["table"]["pond"]; var lv: Image = _r8(33, 33, 6)
	var pl: Array = pond.get(str(lk), [-1, -1])
	var blk: Image = _r8(33, 33, 0, {32 * 33 + 31: lk, 31 * 33 + 32: 2, 5: 1}); var cb: Array = []
	for pm: Image in [blk, null, _r8(33, 33, 0)]:
		cb.append((BakeCellColor.color_blocks(_rgba(66, 66, CLEAR), _rgba(66, 66, CLEAR), lv, _r8(33, 33, 0), pk["table"],
			pm)["image"] as Image).get_data())
	var l4: Image = _r8(4, 1, 6); var n4: Image = _r8(4, 1, 0); var m4: Image = _r8(4, 1, 0, {1: 1, 2: 1})
	var q: PackedInt32Array = BakeTerrainGreedy.merge_chunk(l4, n4, Vector2i.ZERO, null, m4)
	var s: PackedInt32Array = BakeTerrainSides.sides_chunk(l4, n4, n4, Vector2i.ZERO, m4); var faces: Array = []
	for i: int in range(0, s.size(), 8):
		if s[i + 5] == 134: faces.append([s[i], s[i + 3], s[i + 4]])
	var ql: Array = []
	for i: int in range(4, q.size(), 5): ql.append(q[i] & 255)
	var c2: Ctx = Ctx.new()
	var pal0: bool = BakePalette.new().run(c2) and not (c2.get_value("palette_table") as Dictionary).has("pond")
	pal0 = pal0 and (c2.get_value("palette") as Image).get_data() == (fresh["image"] as Image).get_data()
	var c3: Ctx = Ctx.new(); c3.put_value("pond_keys", range(1, 256)); var ok3: bool = BakePalette.new().run(c3)
	var mud: int = maxi(0, 255 - (spare.size() >> 1))
	var t3: Dictionary = c3.get_value("palette_table") if ok3 else {"pond": {}}
	_rows(res, [["T24 lake", [_rgb(img, maxi(0, pl[0])), _rgb(img, maxi(0, pl[1])), pl[0] >= 0],
			[[51, 102, 112], [46, 92, 101], true]],
		["T24 d", [_rgb(img, pond["2"][0]), _rgb(img, pond["2"][1])], [[48, 80, 96], [43, 72, 86]]],
		["T24 mud", [_rgb(img, pond["1"][0]), _rgb(img, pond["1"][1])], [[86, 62, 40], [70, 50, 32]]],
		["T24 blocks", [cb[0][32 * 33 + 31], cb[0][31 * 33 + 32], cb[0][5]], [pl[0], pond["2"][0], pond["1"][1]]],
		["T28 slots", s2["1"] + s2["2"] + s2["17"], spare.slice(0, 6)], ["T28 hex", p2["table"]["hex"] == hex0, true],
		["T28 overflow", [ov, c3.lines.has("BakePalette: 255 pond keys, %d on mud slots" % mud)], [[0, 0], true]],
		["T28 tail on mud", t3["pond"].get("255", []), t3["pond"].get("1", [0])], ["T26 greedy", ql, [6, 134, 6]],
		["T26 y", _near(MapSpace.level_to_y(134), MapSpace.level_to_y(6) - 1.976471, 1e-6), true],
		["T26 sides", [faces.size(), faces.has([0, 3, 6]), faces.has([3, 2, 6])], [2, true, true]],
		["T27 pond height", _near(MapSpace.level_height(134), MapSpace.level_height(6) - 0.3 * MapConst.TERRACE), true],
		["T27 level 6", _near(MapSpace.level_height(6), 11.0 * MapConst.TERRACE), true],
		["T30 colour", cb[1] == cb[2], true], ["T30 palette", pal0, true],
		["T30 greedy", BakeTerrainGreedy.merge_chunk(l4, n4, Vector2i.ZERO) == BakeTerrainGreedy.merge_chunk(l4, n4,
			Vector2i.ZERO, null, n4), true],
		["T30 sides", BakeTerrainSides.sides_chunk(l4, n4, n4, Vector2i.ZERO) == BakeTerrainSides.sides_chunk(l4, n4, n4,
			Vector2i.ZERO, n4), true]])
static func _case_runner(res: Dictionary) -> void:
	var steps: Array[MapBakeStep] = MapBakeRunner.load_steps()
	var ordered: Array[MapBakeStep] = MapBakeRunner.new().order(steps)
	var names: Array = ordered.map(func(s: MapBakeStep) -> String: return String(s.step_name))
	var pin3: Array = []
	for s: MapBakeStep in MapBakeRunner._pinned(ordered):
		if s.stage >= 3: pin3.append(String(s.step_name))
	var before: bool = true
	for pair: Array in [["RailAlign", "BakeScatter"], ["BakeRailMask", "BakeScatter"], ["BakeScatter", "BakePalette"],
			["BakeScatter", "BakeCellColor"], ["BakeScatter", "BakeTerrainGreedy"], ["BakeScatter", "BakeTerrainSides"],
			["BakeChunkMerge", "BakeBudgetCheck"]]:
		var a: int = names.find(pair[0])
		before = before and ((a >= 0 and a < names.find(pair[1])) or (a < 0 and pair[0] == "BakeChunkMerge"))
	_rows(res, [["T29 no cycle", ordered.size(), steps.size()], ["T29 order", before, true],
		["T29 pinned stage 3+", pin3, ["BakeKits"] if ResourceLoader.exists(KITS) else []]])
static func _rail(base: int, lv: Dictionary, sea: Dictionary, line: Array) -> Array:
	var lr: Callable = RailAlign._level_reader(_r8(32, 32, base, lv).get_data(), _r8(32, 32, 0, sea).get_data(),
		_r8(32, 32, 0).get_data(), 32, 32)
	var r: Dictionary = RailAlign.align(PackedVector2Array(line), lr); var img: Image = _r8(32, 32, 0)
	for p: Vector2 in r["pts"]: BakeRailMask.stamp(img, p.x, p.y)
	var off: PackedFloat32Array = r["off"]; var pk: Vector2 = Vector2(0, -1)
	for i: int in off.size(): pk = Vector2(absf(off[i]), i) if absf(off[i]) > pk.x else pk
	return [off, img.get_data(), pk]
static func _case_rail(res: Dictionary) -> void:
	var flat: Array = _rail(3, {}, {}, [Vector2(20, 32), Vector2(44, 32)]); var hill: Dictionary = {}; var sea: Dictionary = {}
	for z: int in range(14, 18):
		for x: int in range(14, 18):
			hill[z * 32 + x] = 6
			if z == 15 or z == 16: sea[z * 32 + x] = 255
	var hl: Array = _rail(3, hill, {}, [Vector2(8, 32), Vector2(56, 32)])
	var wt: Array = _rail(3, {}, sea, [Vector2(8, 32), Vector2(56, 32)]); var want2: Array = []
	for row: Vector3i in [Vector3i(14, 10, 22), Vector3i(15, 9, 23), Vector3i(16, 8, 24), Vector3i(17, 9, 23),
			Vector3i(18, 10, 22)]:
		for x: int in range(row.y, row.z + 1): want2.append(row.x * 32 + x)
	var got2: Array = []
	for j: int in 1024:
		if flat[1][j] == 2: got2.append(j)
	var dot: Image = _r8(32, 32, 0); BakeRailMask.stamp(dot, 30.7, 30.2)
	var hoff: Array = [0.0, 0.02, 0.18, 0.75, 1.46, 2.09, 2.31, 1.96, 1.27, 0.6, 0.13, 0.01, 0.0]
	var hok: bool = (hl[0] as PackedFloat32Array).size() == 49
	for i: int in mini(13, ((hl[0] as PackedFloat32Array).size() + 3) >> 2): hok = hok and absf(hl[0][i * 4] - hoff[i]) <= 0.01
	var taper: bool = true
	for f: Array in [flat, hl, wt]:
		var off: PackedFloat32Array = f[0]; taper = taper and off.size() > 1 and off[0] == 0.0 and off[-1] == 0.0
	_rows(res, [["T31 off", flat[2].x, 0.0], ["T31 hard cells", got2, want2],
		["T31 counts", [flat[1].count(1), flat[1].count(0)], [256, 1024 - 329]],
		["T32 point", [dot.get_data().count(2), dot.get_data().count(1), dot.get_pixel(15, 15).r8], [13, 136, 2]],
		["T33 samples", hok, true], ["T33 peak", [absf(hl[2].x - 2.313) <= 0.01, int(hl[2].y)], [true, 23]],
		["T33 mask", [hl[1].count(2), hl[1].count(1)], [135, 331]],
		["T34 water", absf(wt[2].x - 0.982) <= 0.001, true], ["T35 taper", taper, true]])
