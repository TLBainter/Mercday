class_name MapGroundTests extends RefCounted

#E55 ground cases: lean kits, ice box, ice stacks, instancer, both merge paths, caps, wiring text and the real bake.
#Run: godot --headless --path . -- --map-ground-tests. Step cases write kits/ and props/ under the bake test scratch dir.

const GROUND_INDEX: String = "props/ground/index"
const FL: Array = [[0.96, 0.95, 0.9], [0.98, 0.86, 0.3], [0.95, 0.55, 0.65], [0.7, 0.5, 0.9], [0.9, 0.35, 0.3]]
const W0: Color = Color(0.97, 0.99, 1.0)
const W1: Color = Color(0.88, 0.94, 0.98)
const C8: float = 1.0 / 255.0
const TOL: float = 1e-4

static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	var d2: Dictionary = MapBakeContext.new().get_value(BakeScatterRules.SCATTER_KEY)
	var grass: ArrayMesh = GroundCoverMeshes.mesh("grass", 0, 0, d2["GV"]["grass"][0])
	_case_kit(res, grass, d2); _case_ice(res); _case_instancer(res, grass)
	var root: String = ProjectSettings.globalize_path(MapBakeTests.SCRATCH_DIR)
	_wipe(root.path_join("kits")); _wipe(root.path_join("props"))
	DirAccess.make_dir_recursive_absolute(root.path_join("kits"))
	_case_ground_step(res, grass); _case_foliage_step(res)
	_wipe(root.path_join("kits")); _wipe(root.path_join("props")); DirAccess.remove_absolute(root)
	_case_caps(res); _case_text(res); _case_baked(res)
	return TestFixtures.summarize(res, "MAP GROUND")
static func _rows(res: Dictionary, rows: Array) -> void:
	for row: Array in rows:
		TestFixtures.check(res, str(row[0]), row[1] == row[2], "got %s want %s" % [str(row[1]), str(row[2])])
static func _close(a: Array, b: Array, tol: float) -> bool:
	var ok: bool = a.size() == b.size()
	for i: int in mini(a.size(), b.size()): ok = ok and absf(float(a[i]) - float(b[i])) <= tol
	return ok
static func _ints(v: Variant) -> Array:
	var out: Array = []
	for x: Variant in (v if v != null else []): out.append(int(x))
	return out
static func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if ResourceLoader.exists(path) else null
static func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir): return
	for d: String in DirAccess.get_directories_at(dir): _wipe(dir.path_join(d))
	for f: String in DirAccess.get_files_at(dir): DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
#The G4 fixture, unsorted: two mirrored grass clumps and one ty 0 ice stack, all in chunk 0.
static func _fixture() -> MapPlacementSet:
	var ps: MapPlacementSet = MapPlacementSet.new(); var c: Color = Color(0.5, 0.6, 0.7)
	ps.add(&"g/grass/0/0", Vector3(10, 1, 20), 0.0, 1.0, Vector4i.ZERO, -1, c)
	ps.add(&"g/grass/0/1", Vector3(12, 1, 20), 0.0, 1.0, Vector4i.ZERO, -1, c)
	ps.add(&"ice/0", Vector3(30, 2, 40), 0.0, 1.0, Vector4i.ZERO, -1, W0)
	return ps
static func _nation() -> Image:
	var img: Image = Image.create_empty(MapConst.BLOCKS_X, MapConst.BLOCKS_Y, false, Image.FORMAT_R8)
	img.fill(Color8(7, 0, 0)); return img
static func _ctx(foliage: MapPlacementSet, ground: MapPlacementSet) -> MapBakeContext:
	var ctx: MapBakeContext = MapBakeTests.FileCtx.new(); ctx.put_value("place_foliage", foliage)
	ctx.put_value("place_ground", ground); ctx.put_value("block_nation", _nation()); return ctx
static func _case_kit(res: Dictionary, grass: ArrayMesh, d2: Dictionary) -> void:
	var a: Array = grass.surface_get_arrays(0); var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var alpha0: bool = not cols.is_empty(); var head: bool = false
	for c: Color in cols: alpha0 = alpha0 and c.a == 0.0
	var fl: Array = FL[floori(MapRng.hh(200, 90) * 5.0)]; var want: Array = [fl[0] * 0.5, fl[1] * 0.5, fl[2] * 0.5]
	var flowers: ArrayMesh = GroundCoverMeshes.mesh("flowers", 0, 0, d2["GV"]["flowers"][0])
	for c: Color in flowers.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		head = head or (absf(c.a - 0.5) <= C8 and _close([c.r, c.g, c.b], want, C8))
	_rows(res, [["G1 one surface", grass.get_surface_count(), 1], ["G1 no UV", a[Mesh.ARRAY_TEX_UV] == null, true],
		["G1 no CUSTOM0", a[Mesh.ARRAY_CUSTOM0] == null, true],
		["G1 colour per vertex", cols.size(), (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()],
		["G1 alpha 0", alpha0, true], ["G1 flower head FL * 0.5", head, true]])
static func _case_ice(res: Dictionary) -> void:
	var a: Array = GroundCoverMeshes.ice_box().surface_get_arrays(0); var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]; var lo: Vector3 = Vector3.INF; var hi: Vector3 = -Vector3.INF
	var counts: Array = [0, 0]; var shades: Array = []; var want: Array = []
	for v: Vector3 in vs:
		lo = lo.min(v); hi = hi.max(v)
		counts[0] += 1 if absf(v.z + 0.5) < TOL else 0; counts[1] += 1 if absf(v.y) < TOL else 0
	for q: int in mini(4, cols.size() >> 2): shades.append_array([cols[q * 4].r, cols[q * 4].g, cols[q * 4].b])
	for s: float in [0.5, 0.4, 0.35, 0.43]: want.append_array([s, s, s])
	_rows(res, [["G2 vertices", vs.size(), 16], ["G2 indices", (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 24],
		["G2 min", lo.is_equal_approx(Vector3(-0.5, 0, -0.5)), true], ["G2 max", hi.is_equal_approx(Vector3(0.5, 1, 0.5)),
		true], ["G2 z -0.5 and y 0 counts", counts, [6, 6]], ["G2 quad shades", _close(shades, want, C8), true]])
	var b0: Array[PackedFloat32Array] = IceStacks.boxes(0, 100, 200, 5.0)
	var b5: Array[PackedFloat32Array] = IceStacks.boxes(5, 100, 200, 5.0)
	var box0: Array = [100.0, 200.0, 5.0 + MapRng.hh(131, 217) * 4.0, 3.0 + MapRng.hh(162, 234) * 3.0, 5.0, 0.9, 1.0]
	var tower: bool = b5.size() == 4; var n4: int = IceStacks.boxes(4, 100, 200, 5.0).size()
	for k: int in maxi(0, b5.size() - 1):
		tower = tower and b5[k + 1][4] > b5[k][4] and absf(b5[k + 1][2] - b5[k][2] * 0.68) <= TOL
	_rows(res, [["G3 ty 0 box", b0.size() == 1 and _close(Array(b0[0]), box0, TOL), true], ["G3 ty 5 tower", tower, true],
		["G3 ty 2 count", IceStacks.boxes(2, 100, 200, 5.0).size(), 5 + floori(MapRng.hh(131, 217) * 3.0)],
		["G3 ty 1 count", IceStacks.boxes(1, 100, 200, 5.0).size(), 2],
		["G3 ty 3 count", IceStacks.boxes(3, 100, 200, 5.0).size(), 2], ["G3 ty 4 count 4..6", n4 >= 4 and n4 <= 6, true],
		["G3 ty 6 count", IceStacks.boxes(6, 100, 200, 5.0).size(), 5]])
static func _case_instancer(res: Dictionary, grass: ArrayMesh) -> void:
	var ps: MapPlacementSet = _fixture(); ps.sort_by_chunk(); var before: PackedFloat32Array = ps.xform.duplicate()
	var kits: Dictionary = {"g/grass/0": grass, "ice": GroundCoverMeshes.ice_box()}
	var ch: MapInstanceChunk = GroundInstancer.build(ps, Vector2i.ZERO, kits, _nation())
	if ch == null or ch.parts.size() != 2:
		TestFixtures.check(res, "G4 instancer chunk", false, "build returned null or not two parts"); return
	var g: PackedFloat32Array = ch.parts[0].buffer; var ice: PackedFloat32Array = ch.parts[1].buffer
	var sizes: Array = [g.size(), ice.size()]; g.resize(32); ice.resize(16)
	var o1: Vector3 = MapSpace.img_to_world(Vector2(10, 20), 1.0); var o2: Vector3 = MapSpace.img_to_world(Vector2(12, 20), 1.0)
	var box: AABB = ch.aabb.grow(0.001); var gv: int = grass.surface_get_array_len(0)
	var ice_want: Array = [5.0 + MapRng.hh(61, 57) * 4.0, 0.9, 3.0 + MapRng.hh(92, 74) * 3.0, W1.r, W1.g, W1.b, 2.0]
	_rows(res, [["G4 models", Array(ch.models), ["g/grass/0", "ice"]], ["G4 instance_counts", _ints(ch.instance_counts),
		[2, 1]], ["G4 buffer sizes", sizes, [32, 16]],
		["G4 row x", _close(Array(g.slice(0, 4)), [1.0, 0.0, 0.0, o1.x], TOL), true], ["G4 mirror", g[16], -1.0],
		["G4 custom", _close(Array(g.slice(12, 16)), [0.5, 0.6, 0.7, 7.0], C8), true],
		["G4 ice", _close([ice[0], ice[5], ice[10], ice[12], ice[13], ice[14], ice[7]], ice_want, TOL), true],
		["G4 part_verts", _ints(ch.part_verts), [2 * gv, 16]], ["G4 aabb", box.has_point(o1) and box.has_point(o2), true],
		["G4 set unchanged", ps.xform == before, true]])
static func _case_ground_step(res: Dictionary, grass: ArrayMesh) -> void:
	var dir: String = MapBakeTests.SCRATCH_DIR
	var errs: int = ResourceSaver.save(grass, dir + "kits/g_0.res")
	errs += ResourceSaver.save(GroundCoverMeshes.ice_box(), dir + "kits/ice_box.res")
	var ok: bool = BakeChunkMerge.new().run(_ctx(MapPlacementSet.new(), _fixture()))
	var idx: MapChunkIndex = _load(dir + "props/ground/index.tres") as MapChunkIndex
	_rows(res, [["G5 kits saved", errs, OK], ["G5 run", ok, true], ["G5 index", idx != null and idx.paths.size() == 1, true]])
	if idx == null or idx.paths.size() != 1: return
	var gv: int = grass.surface_get_array_len(0); var ch: MapInstanceChunk = _load(idx.paths[0]) as MapInstanceChunk
	var p0: MultiMesh = ch.parts[0] if ch != null and ch.parts.size() > 0 else null
	_rows(res, [["G5 coords", Array(idx.coords), [Vector2(0, 0)]], ["G5 surfaces_of", _ints(idx.surfaces_of(0)), [2 * gv, 16]],
		["G5 vert_counts", idx.vert_counts[0], 2 * gv + 16], ["G5 aabb lift", idx.aabbs[0].size.y >= MapConst.LIFT, true],
		["G5 chunk parts", ch.parts.size() if ch != null else -1, 2],
		["G5 part 0 instances", p0.instance_count if p0 != null else -1, 2],
		["G5 kit referenced", p0 != null and p0.mesh != null and p0.mesh.resource_path.ends_with("kits/g_0.res"), true],
		["G5 part 0 buffer", p0.buffer.size() if p0 != null else -1, 32]])
static func _case_foliage_step(res: Dictionary) -> void:
	var dir: String = MapBakeTests.SCRATCH_DIR; var fol: MapPlacementSet = MapPlacementSet.new()
	for i: int in 3: fol.add(&"k16", Vector3(10 + 40 * i, 1, 10 + 20 * i), 0.0, 1.0, Vector4i.ZERO)
	var err: int = ResourceSaver.save(MapScatterTests._quads(4), dir + "kits/k16.res")
	var ok: bool = BakeChunkMerge.new().run(_ctx(fol, MapPlacementSet.new()))
	var idx: MapChunkIndex = _load(dir + "props/foliage/index.tres") as MapChunkIndex
	var plan: Array = _ints(BakeChunkMerge.plan_surfaces(PackedInt32Array([16, 16, 16]), MapConst.PROPS_CHUNK_VERTS)["counts"])
	var has: bool = idx != null and not idx.coords.is_empty()
	var sv: Array = _ints(idx.surface_verts[0]) if has and not idx.surface_verts.is_empty() else []
	_rows(res, [["G6 kit saved", err, OK], ["G6 run", ok, true], ["G6 plan", plan, [48]], ["G6 surface_verts", sv, plan],
		["G6 surfaces_of", _ints(idx.surfaces_of(0)) if has else [], plan]])
static func _case_caps(res: Dictionary) -> void:
	var bc: BakeBudgetCheck = BakeBudgetCheck.new(); var cap: int = BakeBudgetCheck.cap_for(&"ground")
	var over: PackedStringArray = bc.check_index(_index([10, 500001], [[10], [200000, 200001]]), cap)
	var under: PackedStringArray = bc.check_index(_index([10], [[10]]), cap)
	_rows(res, [["G7 cap_for ground", cap, MapConst.GROUND_CHUNK_VERTS], ["G7 cap value", MapConst.GROUND_CHUNK_VERTS, 500000],
		["G7 one message", over.size(), 1], ["G7 no message", under.size(), 0],
		["G7 chunk message", over.size() == 1 and over[0].contains("chunk 1,0 has 500001"), true]])
static func _index(counts: Array, sv: Array) -> MapChunkIndex:
	var idx: MapChunkIndex = MapChunkIndex.new(); idx.layer = &"ground"
	for i: int in counts.size():
		idx.coords.append(Vector2(i, 0)); idx.vert_counts.append(int(counts[i]))
		idx.surface_verts.append(PackedInt32Array(sv[i]))
	return idx
static func _case_text(res: Dictionary) -> void:
	var sh: String = FileAccess.get_file_as_string("res://Scripts/Map/Shaders/map_ground.gdshader")
	var ly: String = FileAccess.get_file_as_string("res://Scripts/Map/View/MapLayer.gd")
	var vw: String = FileAccess.get_file_as_string("res://Scripts/Map/View/MapView.gd")
	_rows(res, [["G8 shader INSTANCE_CUSTOM", sh.contains("INSTANCE_CUSTOM"), true],
		["G8 shader no CUSTOM0", sh.contains("CUSTOM0"), false], ["G8 layer MapInstanceChunk", ly.contains("MapInstanceChunk"), true],
		["G8 layer hint", ly.contains("load_threaded_request(path, \"\")"), true],
		["G8 view find_children", vw.contains("find_children"), true], ["G8 view no _terrain", vw.contains("_terrain"), false]])
static func _case_baked(res: Dictionary) -> void:
	if not MapTestFixtures.require_baked(res, GROUND_INDEX): return
	var b: String = MapData.BAKED_DIR; var idx: MapChunkIndex = _load(b + GROUND_INDEX + ".tres") as MapChunkIndex
	if idx == null or idx.paths.is_empty():
		TestFixtures.check(res, "G9 index", false, "props/ground/index.tres is not a non-empty MapChunkIndex"); return
	var surf: bool = true; var even: bool = true; var total: int = idx.total_verts()
	for i: int in idx.vert_counts.size():
		var sum: int = 0
		for n: int in idx.surfaces_of(i): sum += n
		surf = surf and idx.surfaces_of(i).size() <= 73 and sum == idx.vert_counts[i]
	var ch: MapInstanceChunk = _load(idx.paths[idx.paths.size() >> 1]) as MapInstanceChunk
	var ground: Array = Array(DirAccess.get_files_at(b + "kits")).filter(
		func(f: String) -> bool: return f.begins_with("g_") and f.ends_with(".res"))
	for mid: int in range(0, 144, 2): even = even and ground.has("g_%d.res" % mid)
	_rows(res, [["G9 coords > 100", idx.coords.size() > 100, true],
		["G9 total 10M..20M", total >= 10000000 and total <= 20000000, true], ["G9 surfaces", surf, true],
		["G9 chunk", ch != null and ch.parts.size() > 0 and ch.parts[0].mesh != null, true],
		["G9 ground kits", [ground.size(), even], [72, true]], ["G9 ice kit", FileAccess.file_exists(b + "kits/ice_box.res"), true],
		["G9 Baked bytes", BakeBudgetCheck.dir_bytes(b) <= MapConst.BAKED_CAP_BYTES, true]])
