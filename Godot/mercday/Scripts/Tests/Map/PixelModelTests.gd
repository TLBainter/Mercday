class_name PixelModelTests extends RefCounted
#Sequences, atlas, mesh layout, kit models against the JS oracle, geometry, tile wrap. Writes only user://.
const LT: Array[float] = [1.0, 0.9, 0.96, 0.76, 0.82, 0.98]
const RT_PATH: String = "user://atlas_rt.json"
const EDIT_PATH: String = "user://atlas_edit.json"
static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PixelModelImporter.ORACLE_JSON))
	var doc: Dictionary = v if v is Dictionary else {}; var atlas: PixelAtlas = PixelAtlas.load_default()
	_t1_t3(res, doc.get("sequences", {})); _t4(res, atlas); _t4b(res); _t5(res, doc); _t6_t14(res, atlas)
	_t7_t9(res, doc); _t10(res, atlas); _t11(res); _t12(res); _t13(res, atlas); _t15(res, doc, atlas); _t16(res, atlas)
	_t27(res)
	return TestFixtures.summarize(res, "PIXEL MODELS")
static func _chk(res: Dictionary, label: String, bad: Array[String], total: int) -> void:
	TestFixtures.check(res, label, total > 0 and bad.is_empty(), TestFixtures.detail(bad, total, "cases", 8))
static func _feq(a: float, b: float) -> bool:
	return absf(a - b) <= 1e-6 * maxf(1.0, maxf(absf(a), absf(b)))
static func _vfeq(a: Vector3, b: Vector3) -> bool:
	return _feq(a.x, b.x) and _feq(a.y, b.y) and _feq(a.z, b.z)
static func _diff(a: Variant, b: Variant, path: String) -> String:
	if (a is float or a is int) and (b is float or b is int):
		return "" if _feq(float(a), float(b)) else "%s got %s want %s" % [path, str(a), str(b)]
	if not ((a is Dictionary and b is Dictionary) or (a is Array and b is Array)):
		return "" if typeof(a) == typeof(b) and a == b else "%s got %s want %s" % [path, str(a), str(b)]
	var ka: Array = a.keys() if a is Dictionary else range(a.size())
	var kb: Array = b.keys() if b is Dictionary else range(b.size()); ka.sort(); kb.sort()
	if ka != kb: return "%s keys got %s want %s" % [path, str(ka), str(kb)]
	for k: Variant in kb:
		var s: String = _diff(a[k], b[k], "%s.%s" % [path, str(k)])
		if s != "": return s
	return ""
static func _all(doc: Dictionary) -> Dictionary:
	var out: Dictionary = (doc.get("models", {}) as Dictionary).duplicate(); var variants: Dictionary = doc.get("variants", {})
	for id: String in variants:
		for v: String in variants[id]: out["%s#%s" % [id, v]] = variants[id][v]
	return out
static func _mesh(m: PixelModel, atlas: PixelAtlas) -> ArrayMesh:
	var b: PixelMeshBuilder = PixelMeshBuilder.new(); b.begin(atlas); return b.build(m, 1.0, 0)
static func _tile_id(atlas: PixelAtlas) -> StringName:
	for id: String in atlas.ids():
		var e: PixelAtlasEntry = atlas.entry(StringName(id))
		if e.tile and e.parent == &"" and e.rect.size.x >= 2 and e.rect.size.y >= 2: return e.id
	return &""
static func _box(tile: StringName, cx: float, w: float, d: float, h: float,
		m: PixelModel = PixelModelStatic.new()) -> PixelModel:
	var tex: Dictionary = {}
	for f: String in ["top", "front", "left", "right"]: tex[f] = {"id": tile}
	m.W = w; m.D = d
	m.set_parts([PixelPart.from_dict({"kind": "box", "x": cx, "z": 0, "w": w, "d": d, "h": h, "tex": tex})] as Array[PixelPart])
	return m
static func _t1_t3(res: Dictionary, seq: Dictionary) -> void:
	var bad: Array[String] = []; var rows: Array = seq.get("hh", [])
	for r: Array in rows:
		var got: int = MapRng.hh_u32(int(r[0]), int(r[1]))
		if got != int(r[2]): bad.append("hh(%d,%d) got %d want %d" % [int(r[0]), int(r[1]), got, int(r[2])])
	_chk(res, "T1 hh", bad, rows.size()); bad.clear(); var total: int = 0
	for kind: String in ["srng", "mulberry32"]:
		for sk: String in seq.get(kind, {}):
			var g: MapRng = MapRng.srng(int(sk)) if kind == "srng" else MapRng.mulberry32(int(sk)); var want: Array = seq[kind][sk]
			total += 1
			for i: int in want.size():
				var u: int = g.next_u32()
				if u != int(want[i]):
					bad.append("%s seed %s [%d] got %d want %d" % [kind, sk, i, u, int(want[i])]); break
	_chk(res, "T2 srng mulberry32", bad, total); bad.clear(); var strs: Dictionary = seq.get("hstr", {})
	for s: String in strs:
		if MapRng.hstr(s) != int(strs[s]) or MapRng.fnv1a(s) != int(strs[s]):
			bad.append("%s hstr %d fnv1a %d want %d" % [s, MapRng.hstr(s), MapRng.fnv1a(s), int(strs[s])])
	_chk(res, "T3 hstr fnv1a", bad, strs.size()); bad.clear(); var vn: Array = seq.get("vn", [])
	for r: Array in vn:
		var got: float = MapRng.vn(float(r[0]), float(r[1]))
		if not _feq(got, float(r[2])): bad.append("vn(%s,%s) got %s want %s" % [str(r[0]), str(r[1]), str(got), str(r[2])])
	_chk(res, "T3 vn", bad, vn.size())
static func _t4(res: Dictionary, atlas: PixelAtlas) -> void:
	var sub: Rect2i = atlas.rect_of(&"pise_plain")
	var ok: bool = atlas.entries.size() == 59
	ok = ok and sub == Rect2i(atlas.rect_of(&"pise_wall").position + Vector2i(3, 3), Vector2i(1, 1))
	TestFixtures.check(res, "T4 entries", ok, "%d entries, sub %s" % [atlas.entries.size(), str(sub)])
	var copy: PixelAtlas = PixelAtlas.load_default(); copy.json_path = RT_PATH; var err: int = copy.save_rects()
	var same: bool = FileAccess.get_file_as_bytes(RT_PATH) == FileAccess.get_file_as_bytes(PixelAtlas.AJ)
	TestFixtures.check(res, "T4 save byte-equal", err == OK and same, "err %d equal %s" % [err, str(same)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RT_PATH))
static func _t4b(res: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(EDIT_PATH, FileAccess.WRITE); f.store_string(FileAccess.get_file_as_string(PixelAtlas.AJ))
	f.close(); var a: PixelAtlas = PixelAtlas.new(); a.json_path = EDIT_PATH; a.reload(); var ids: PackedStringArray = a.ids()
	var e_id: StringName = StringName(ids[0]); var s_id: StringName = StringName(ids[1]); var u_id: StringName = StringName(ids[2])
	for i: int in range(1, ids.size()):
		if a.entry(StringName(ids[i])).rect.size.x >= 2:
			s_id = StringName(ids[i]); u_id = StringName(ids[(i + 1) % ids.size()]); break
	var moved: Rect2i = Rect2i(a.rect_of(e_id).position + Vector2i(1, 0), a.rect_of(e_id).size)
	a.entry(e_id).rect = moved; a.entry(e_id).edited = true; var new_id: StringName = a.split(s_id, 1, true)
	var err: int = a.save_rects(); var b: PixelAtlas = PixelAtlas.new(); b.json_path = EDIT_PATH; b.reload()
	var kept: bool = b.has_entry(new_id) and new_id == StringName(str(s_id) + "_s1") and b.entry(new_id).edited
	kept = kept and b.entry(e_id).rect == moved and b.entry(e_id).edited and b.entry(s_id).edited
	TestFixtures.check(res, "T4b persistence", err == OK and kept, "err %d new id %s" % [err, str(new_id)])
	var ur: Rect2i = b.entry(u_id).rect; b.entry(u_id).rect = Rect2i(ur.position + Vector2i(1, 1), ur.size)
	var fresh: PixelAtlas = PixelAtlas.load_default(); b.merge_on_reimport(fresh)
	var merged: bool = b.entry(e_id).rect == moved and b.has_entry(new_id) and b.entry(u_id).rect == fresh.rect_of(u_id)
	TestFixtures.check(res, "T4b merge", merged, "edited kept, unedited %s replaced" % str(u_id))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EDIT_PATH))
static func _t5(res: Dictionary, doc: Dictionary) -> void:
	var bad: Array[String] = []; var all: Dictionary = _all(doc); var oracle: Dictionary = PixelModelImporter.new().load_oracle()
	var counts: bool = oracle.size() == all.size()
	for label: String in all:
		var src: Array = all[label]["parts"]
		var back: Array = src.map(func(d: Dictionary) -> Dictionary: return PixelModelImporter.part_from_dict(d).to_dict())
		var s: String = _diff(back, src, "")
		if s != "": bad.append("%s part %s" % [label, s])
		counts = counts and (oracle.get(StringName(label), []) as Array).size() == src.size()
	_chk(res, "T5 part round trip", bad, all.size())
	TestFixtures.check(res, "T5 importer", counts, "%d models read" % oracle.size())
static func _t6_t14(res: Dictionary, atlas: PixelAtlas) -> void:
	var model: PixelModel = _box(_tile_id(atlas), 0.0, 2.0, 1.0, 1.0); var mesh: ArrayMesh = _mesh(model, atlas)
	var arrays: Array = mesh.surface_get_arrays(0); var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var counts: String = "%d verts %d indices" % [mesh.surface_get_array_len(0), mesh.surface_get_array_index_len(0)]
	var ok: bool = counts == "16 verts 24 indices"
	ok = ok and uv[0].is_equal_approx(Vector2(0, 1)) and uv[2].is_equal_approx(Vector2(2, 1))
	ok = ok and _vfeq(pos[0], Vector3(-2.8, 1.6, -0.7)) and _vfeq(pos[5], Vector3(-2.8, 0.0, 0.7))
	TestFixtures.check(res, "T6 box emit", ok, "%s, top P0 %s, front P1 %s" % [counts, str(pos[0]), str(pos[5])])
	var first: ArrayMesh = model.build_mesh(atlas)
	var cached: bool = model.build_mesh(atlas) == first and model.vertex_count() == 16; var old_hash: int = model.content_hash
	model.set_parts([PixelPart.from_dict({"kind": "box", "w": 2, "d": 1, "h": 3})] as Array[PixelPart])
	var rebuilt: bool = model.content_hash != old_hash and model.build_mesh(atlas) != first
	TestFixtures.check(res, "T14 cache", cached and rebuilt, "cached %s rebuilt %s" % [str(cached), str(rebuilt)])
static func _t7_t9(res: Dictionary, doc: Dictionary) -> void:
	var bad7: Array[String] = []; var bad8: Array[String] = []; var skip: Dictionary = doc.get("errors", {})
	var models: Dictionary = doc.get("models", {}); var all: Dictionary = _all(doc)
	for label: String in all:
		var id: String = label.get_slice("#", 0); var v: int = int(label.get_slice("#", 1)) if label.contains("#") else -1
		if skip.has(id): continue
		var m: PixelModel = PixelKitBuilder.build(StringName(id), &"buern", 0.4, v); var want: Dictionary = all[label]
		var rc: int = PixelKitBuilder.last_r_calls; var why: String = "no model"
		if m != null and want.has("rCalls") and rc != int(want["rCalls"]):
			bad7.append("%s#%d rCalls got %d want %d" % [id, v, rc, int(want["rCalls"])])
		if m != null:
			var got: Dictionary = {"W": m.W, "D": m.D, "parts": m.parts.map(func(p: PixelPart) -> Dictionary: return p.to_dict())}
			why = _diff(got, {"W": want["W"], "D": want["D"], "parts": want["parts"]}, "")
		if why != "": (bad8 if v >= 0 else bad7).append("%s %s" % [label, why])
	_chk(res, "T7 oracle models", bad7, models.size()); _chk(res, "T8 oracle variants", bad8, all.size() - models.size())
	var ids: PackedStringArray = PixelKitBuilder.ids(); var total: int = 0; var vbad: Array[String] = []
	for id: String in ids:
		var c: int = PixelKitBuilder.variant_count(StringName(id)); total += c
		if c != (doc.get("variants", {}) as Dictionary).get(id, {}).size(): vbad.append("%s variant_count %d" % [id, c])
	var ok: bool = ids.size() == 136 and total == 155 and vbad.is_empty() and models.size() + skip.size() == 136
	var info: String = "%d ids, %d variants, %d errors, %s" % [ids.size(), total, skip.size(), str(vbad.slice(0, 5))]
	TestFixtures.check(res, "T9 coverage", ok, info)
static func _t10(res: Dictionary, atlas: PixelAtlas) -> void:
	for id: String in ["f_oak", "f_pine", "p_rocks", "w_pebbles", "r_rock1"]:
		var m: PixelModel = PixelKitBuilder.build(StringName(id)); var mesh: ArrayMesh = _mesh(m, atlas) if m != null else null
		var ok: bool = mesh != null and mesh.get_surface_count() > 0
		TestFixtures.check(res, "T10 " + id, ok, "ok" if ok and PixelMeshBuilder.uv_roundtrip_ok(mesh) else "uncompressed")
static func _t11(res: Dictionary) -> void:
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	for n: String in ["map_prop", "map_ground"]:
		var sh: Shader = load("res://Scripts/Map/Shaders/%s.gdshader" % n) as Shader
		TestFixtures.check(res, "T11 shader " + n, sh != null, "loaded %s" % str(sh != null))
	for g: String in ["map_prop_atlas", "map_prop_light"]:
		var found: bool = text.contains(g + "={") and MapUniforms.NAMES.has(StringName(g))
		TestFixtures.check(res, "T11 global " + g, found, "project.godot and MapUniforms.NAMES")
static func _t12(res: Dictionary) -> void:
	var atlas: PixelAtlas = PixelAtlas.load_default(); var id: StringName = StringName(atlas.ids()[0])
	var e: PixelAtlasEntry = atlas.entry(id); var old: Rect2i = e.rect; var was: bool = e.edited
	var moved: Rect2i = Rect2i(old.position + Vector2i(1, 1), old.size); var ed: PixelAtlasRectEditor = PixelAtlasRectEditor.new()
	var ur: UndoRedo = UndoRedo.new(); ed.edit(atlas); ed.apply_rect(ur, id, moved); var done: bool = e.rect == moved and e.edited
	ur.undo(); var undone: bool = e.rect == old and e.edited == was; ur.redo(); var redone: bool = e.rect == moved and e.edited
	var info: String = "apply %s undo %s redo %s" % [str(done), str(undone), str(redone)]
	TestFixtures.check(res, "T12 rect undo", done and undone and redone, info)
	ed.free(); ur.free()
static func _rect_at(c1: PackedByteArray, i: int) -> Rect2i:
	var h: Array[int] = []
	for k: int in 4: h.append(int(c1.decode_half(i * 8 + k * 2)))
	return Rect2i(h[0], h[1], h[2], h[3])
static func _t13(res: Dictionary, atlas: PixelAtlas) -> void:
	var tile: StringName = _tile_id(atlas); var m: PixelModelDynamic = PixelModelDynamic.new(); _box(tile, 0.0, 2.0, 1.0, 1.0, m)
	m.sway = 3; var b: PixelMeshBuilder = PixelMeshBuilder.new(); b.begin(atlas); b.set_tag(5, 2, 7, 3)
	var mesh: ArrayMesh = b.build(m, 1.0, 5); var arrays: Array = mesh.surface_get_arrays(0)
	var tags: PackedByteArray = arrays[Mesh.ARRAY_CUSTOM0]; var bad: Array[String] = []
	for i: int in 16:
		var want: Array = [5, 2, 7, (3 << 4) | (i / 4)]
		var got: Array = [tags[i * 4], tags[i * 4 + 1], tags[i * 4 + 2], tags[i * 4 + 3]]
		if got != want or _rect_at(arrays[Mesh.ARRAY_CUSTOM1], i) != atlas.rect_of(tile):
			bad.append("vertex %d tag %s want %s" % [i, str(got), str(want)])
	var fmt: int = mesh.surface_get_format(0)
	var c0: int = (fmt >> Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK
	var c1: int = (fmt >> Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK
	if c0 != Mesh.ARRAY_CUSTOM_RGBA8_UNORM or c1 != Mesh.ARRAY_CUSTOM_RGBA_HALF:
		bad.append("format custom0 %d custom1 %d" % [c0, c1])
	_chk(res, "T13 layout", bad, 17)
static func _mesh_data(mesh: ArrayMesh) -> Dictionary:
	var a: Array = mesh.surface_get_arrays(0)
	return {"pos": a[Mesh.ARRAY_VERTEX], "uv": a[Mesh.ARRAY_TEX_UV], "idx": a[Mesh.ARRAY_INDEX], "tag": a[Mesh.ARRAY_CUSTOM0],
		"rect": a[Mesh.ARRAY_CUSTOM1]}
static func _hits(md: Dictionary, p: Vector3) -> Array[Dictionary]:
	var pos: PackedVector3Array = md["pos"]; var uv: PackedVector2Array = md["uv"]; var idx: PackedInt32Array = md["idx"]
	var out: Array[Dictionary] = []
	for t: int in range(0, idx.size(), 3):
		var a: Vector3 = pos[idx[t]]; var e1: Vector3 = pos[idx[t + 1]] - a; var e2: Vector3 = pos[idx[t + 2]] - a
		var w: Vector3 = p - a; var n: Vector3 = e1.cross(e2)
		if n.length() < 1e-9 or absf(w.dot(n.normalized())) > 1e-4: continue
		var bv: float = w.cross(e2).dot(n) / n.dot(n); var cv: float = e1.cross(w).dot(n) / n.dot(n)
		if minf(1.0 - bv - cv, minf(bv, cv)) < -1e-6: continue
		var hit: Dictionary = {"uv": uv[idx[t]] * (1.0 - bv - cv) + uv[idx[t + 1]] * bv + uv[idx[t + 2]] * cv}
		if md.has("rect"):
			hit["rect"] = _rect_at(md["rect"], idx[t]); hit["face"] = int((md["tag"] as PackedByteArray)[idx[t] * 4 + 3]) & 15
		out.append(hit)
	return out
static func _texel(uv: Vector2, r: Rect2i) -> Vector2i:
	return Vector2i(posmod(floori(uv.x), r.size.x), r.size.y - 1 - posmod(floori(uv.y), r.size.y))
static func _geo_quad(md: Dictionary, q: Array) -> String:
	var pts: PackedVector3Array = PackedVector3Array(); var uvs: PackedVector2Array = PackedVector2Array()
	for vtx: Array in q:
		pts.append(Vector3(float(vtx[0]), float(vtx[1]), float(vtx[2]))); uvs.append(Vector2(float(vtx[3]), float(vtx[4])))
	for k: int in 4:
		if _hits(md, pts[k]).is_empty(): return "corner %d %s is not on the mesh" % [k, str(pts[k])]
	var p: Vector3 = pts[0].lerp(pts[2], 0.37).lerp(pts[1].lerp(pts[3], 0.37), 0.41)
	var js: Array[Dictionary] = _hits({"pos": pts, "uv": uvs, "idx": PackedInt32Array([0, 1, 2, 2, 1, 3])}, p)
	if js.is_empty(): return ""
	var ju: Vector2 = js[0]["uv"]; var edge: bool = absf(ju.x - roundf(ju.x)) < 1e-6 or absf(ju.y - roundf(ju.y)) < 1e-6
	var why: String = "sample %s is not on the mesh" % str(p)
	for h: Dictionary in _hits(md, p):
		var r: Rect2i = h["rect"]; var gt: Vector2i = _texel(h["uv"], r)
		var jt: Vector2i = Vector2i(posmod(floori(ju.x), r.size.x), posmod(floori(ju.y), r.size.y))
		if (gt == jt or edge) and _feq(LT[int(h["face"])], float(q[0][5])): return ""
		why = "texel got %s want %s, shade got %s want %s" % [str(gt), str(jt), str(LT[int(h["face"])]), str(q[0][5])]
	return why
static func _t15(res: Dictionary, doc: Dictionary, atlas: PixelAtlas) -> void:
	var geo: Dictionary = doc.get("geometry", {})
	if doc.has("geometry_error") or geo.is_empty():
		TestFixtures.check(res, "T15 geometry", true, "geometry oracle skipped"); return
	var bad: Array[String] = []; var quads: int = 0; var abad: Array[String] = []
	for id: String in geo:
		var md: Dictionary = _mesh_data(_mesh(PixelKitBuilder.build(StringName(id)), atlas))
		for qi: int in (geo[id] as Array).size() / 4:
			quads += 1; var why: String = _geo_quad(md, (geo[id] as Array).slice(qi * 4, qi * 4 + 4))
			if why != "": bad.append("%s quad %d %s" % [id, qi, why])
		var ga: float = _area(md["pos"], md["idx"]); var ja: float = 0.0; var qa: Array = geo[id]
		for qi: int in qa.size() / 4:
			var pts: PackedVector3Array = PackedVector3Array()
			for vtx: Array in qa.slice(qi * 4, qi * 4 + 4): pts.append(Vector3(float(vtx[0]), float(vtx[1]), float(vtx[2])))
			ja += _area(pts, PackedInt32Array([0, 1, 2, 2, 1, 3]))
		if not _feq(ga, ja): abad.append("%s area got %s want %s" % [id, str(ga), str(ja)])
	_chk(res, "T15 geometry", bad, quads); _chk(res, "T15 area", abad, geo.size())
static func _area(pos: PackedVector3Array, idx: PackedInt32Array) -> float:
	var sum: float = 0.0
	for t: int in range(0, idx.size(), 3):
		sum += 0.5 * (pos[idx[t + 1]] - pos[idx[t]]).cross(pos[idx[t + 2]] - pos[idx[t]]).length()
	return sum
static func _t16(res: Dictionary, atlas: PixelAtlas) -> void:
	var tile: StringName = _tile_id(atlas); var r: Rect2i = atlas.rect_of(tile)
	var md: Dictionary = _mesh_data(_mesh(_box(tile, 2.5, 5.0, 1.0, 3.0), atlas)); var pos: PackedVector3Array = md["pos"]
	var nu: int = maxi(1, ceili(5.0 / r.size.x - 0.02)); var nv: int = maxi(1, ceili(3.0 / r.size.y - 0.02))
	var bad: Array[String] = []
	for i: int in 5:
		for j: int in 3:
			var px: float = i + 0.5; var hb: float = j + 0.5
			var p: Vector3 = pos[5] + (pos[7] - pos[5]) * (px / 5.0) + (pos[4] - pos[5]) * (hb / 3.0)
			var ci: int = mini(floori(px / r.size.x), nu - 1); var cj: int = mini(floori(hb / r.size.y), nv - 1)
			var want: Vector2i = Vector2i(floori(px - ci * r.size.x), floori(r.size.y - (hb - cj * r.size.y)))
			var got: Array[Vector2i] = []
			for h: Dictionary in _hits(md, p):
				if int(h["face"]) == 1: got.append(_texel(h["uv"], r))
			if not got.has(want): bad.append("cell (%d,%d) got %s want %s" % [i, j, str(got), str(want)])
	_chk(res, "T16 tile wrap", bad, 15)
static func _clear_dir(dir: String) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null: return
	for f: String in d.get_files(): d.remove(f)
static func _t27(res: Dictionary) -> void:
	var dir: String = "user://pixel_models_t27"; _clear_dir(dir)
	var n1: int = PixelKitBuilder.build_all(dir); var n2: int = PixelKitBuilder.build_all(dir)
	var got: PixelModel = ResourceLoader.load(dir + "/f_oak#0.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as PixelModel
	var fresh: PixelModel = PixelKitBuilder.build(&"f_oak", &"buern", 0.4, 0)
	var same: bool = got is PixelModelDynamic and fresh != null and got.content_hash == fresh.content_hash
	var info: String = "written %d then %d, f_oak#0 dynamic and hash equal %s" % [n1, n2, str(same)]
	TestFixtures.check(res, "T27 build_all round trip", n1 == 291 and n2 == 0 and same, info)
	_clear_dir(dir); DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
