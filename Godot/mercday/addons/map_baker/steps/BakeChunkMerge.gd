@tool
class_name BakeChunkMerge extends MapBakeStep
#Props per chunk: foliage ArrayMesh surfaces under the cap, ground MapInstanceChunk parts; input sets never written.

const STAGE := 3
const LAYERS := {"foliage": "place_foliage", "ground": "place_ground"}
const MAX_SURFACES := 256
const INDEX_FILE := "index.tres"
const SPIN: float = 6.2832
func _init() -> void:
	step_name = &"BakeChunkMerge"
	stage = STAGE
	inputs = PackedStringArray(["kits/*", "place_foliage", "place_ground", "block_nation"])
	outputs = PackedStringArray(["props/foliage/*", "props/foliage/index", "props/ground/*", "props/ground/index"])
	run_last = true
func run(ctx: MapBakeContext) -> bool:
	var nation: Image = ctx.get_image("block_nation")
	if nation == null: return ctx.fail("BakeChunkMerge: block_nation missing")
	var kdir: String = ctx.path_of("kits/*").trim_suffix("/*") + "/"
	for layer: String in LAYERS:
		var src: MapPlacementSet = ctx.get_value(String(LAYERS[layer])) as MapPlacementSet
		if src == null: return ctx.fail("BakeChunkMerge: %s missing" % LAYERS[layer])
		var work: MapPlacementSet = src.duplicate() as MapPlacementSet
		work.sort_by_chunk()
		var dir: String = ctx.path_of("props/%s/*" % layer).trim_suffix("/*") + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var idx: MapChunkIndex = MapChunkIndex.new()
		idx.layer = StringName(layer)
		var ok: bool = _foliage(ctx, work, kdir, dir, idx, nation) if layer == "foliage" \
			else _ground(ctx, work, kdir, dir, idx, nation)
		if not ok or not _finish(ctx, idx, dir): return false
	return not ctx.failed
static func _foliage(ctx: MapBakeContext, work: MapPlacementSet, kdir: String, dir: String, idx: MapChunkIndex,
		nation: Image) -> bool:
	var kits: Dictionary = {}
	for m: String in work.models:
		kits[m] = _load(kdir + m + ".res") as ArrayMesh
		if kits[m] == null: return ctx.fail("BakeChunkMerge: kit %s%s.res missing" % [kdir, m])
	var st: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for c: Vector2i in _chunks(work):
		var mesh: ArrayMesh = merge(work, c, kits, nation)
		if mesh == null: return ctx.fail("BakeChunkMerge: foliage chunk %02d_%02d did not merge" % [c.x, c.y])
		var sv: PackedInt32Array = PackedInt32Array()
		var n: int = 0
		for s: int in mesh.get_surface_count():
			sv.append(mesh.surface_get_array_len(s))
			n += sv[s]
			st[2] = maxi(st[2], sv[s])
		st[0] += n
		st[1] += sv.size()
		if not sv.is_empty() and not _save(ctx, idx, dir, c, mesh, mesh.get_aabb(), n, sv): return false
	ctx.log("merge foliage chunks %d verts %d surfaces %d max_surface %d" % [idx.coords.size(), st[0], st[1], st[2]])
	return true
static func _ground(ctx: MapBakeContext, work: MapPlacementSet, kdir: String, dir: String, idx: MapChunkIndex,
		nation: Image) -> bool:
	var kits: Dictionary = {}
	var nv: int = GroundCoverMeshes.VARIANTS
	for kind: String in BakeGroundCover.GKI:
		for v: int in nv:
			var kit: Resource = _load(kdir + "g_%d.res" % ((int(BakeGroundCover.GKI[kind]) * nv + v) * 2))
			if kit != null: kits["g/%s/%d" % [kind, v]] = kit
	if FileAccess.file_exists(kdir + "ice_box.res"): kits["ice"] = _load(kdir + "ice_box.res")
	for m: String in work.models:
		var key: String = "ice" if m.begins_with("ice/") else m.substr(0, m.rfind("/"))
		if not kits.has(key): return ctx.fail("BakeChunkMerge: kit %s for %s missing in %s" % [key, m, kdir])
	var st: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
	for c: Vector2i in _chunks(work):
		var chunk: MapInstanceChunk = GroundInstancer.build(work, c, kits, nation)
		if chunk == null: return ctx.fail("BakeChunkMerge: ground chunk %02d_%02d did not build" % [c.x, c.y])
		var n: int = chunk.total_verts()
		if not _save(ctx, idx, dir, c, chunk, chunk.aabb, n, chunk.part_verts): return false
		st[0] += chunk.total_instances()
		st[1] += n
		st[2] += chunk.parts.size()
		st[3] = maxi(st[3], chunk.parts.size())
		st[4] = maxi(st[4], n)
	ctx.log("merge ground chunks %d instances %d verts %d parts %d max_parts %d max_verts %d" % [idx.coords.size(),
		st[0], st[1], st[2], st[3], st[4]])
	return true
#One chunk (unsorted sets sorted on a copy): kits in world space, CUSTOM0.x block_nation, UV2.y the hash angle.
static func merge(set: MapPlacementSet, c: Vector2i, kits: Dictionary, nation: Image) -> ArrayMesh:
	var work: MapPlacementSet = set
	if set.chunk_starts.is_empty():
		work = set.duplicate() as MapPlacementSet
		work.sort_by_chunk()
	var cap: int = MapConst.PROPS_CHUNK_VERTS
	var r: Vector2i = work.range_of(c)
	var data: Dictionary = {}
	var kv: PackedInt32Array = PackedInt32Array()
	for i: int in range(r.x, r.y):
		var id: String = work.model_of(i)
		if not data.has(id):
			var km: ArrayMesh = (kits[id] if kits.has(id) else kits.get(StringName(id))) as ArrayMesh
			if km == null or km.get_surface_count() == 0:
				push_error("BakeChunkMerge: kit %s missing" % id)
				return null
			data[id] = km.surface_get_arrays(0)
		kv.append(((data[id] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var plan: Dictionary = plan_surfaces(kv, cap)
	if not String(plan["error"]).is_empty():
		push_error("BakeChunkMerge: chunk %02d_%02d %s" % [c.x, c.y, plan["error"]])
		return null
	var counts: PackedInt32Array = plan["counts"]
	var mesh: ArrayMesh = ArrayMesh.new()
	var surf: Surf = Surf.new()
	for i: int in range(r.x, r.y):
		var p: Vector3 = work.pos(i)
		var b: Basis = Basis(Vector3.UP, work.xform[5 * i + 3]).scaled(Vector3.ONE * work.xform[5 * i + 4])
		var nb: int = 0 if nation == null else nation.get_pixel(clampi(int(p.x) >> 1, 0, nation.get_width() - 1),
				clampi(int(p.z) >> 1, 0, nation.get_height() - 1)).r8
		surf.add(data[work.model_of(i)], Transform3D(b, MapSpace.img_to_world(Vector2(p.x, p.z), p.y)), nb,
			MapRng.hh(int(p.x), int(p.z)) * SPIN)
		if mesh.get_surface_count() < counts.size() and surf.n == counts[mesh.get_surface_count()]:
			surf.flush(mesh)
			surf = Surf.new()
	return mesh
#Per-instance vertex counts to surface vertex counts under cap; error "" on success.
static func plan_surfaces(kit_verts: PackedInt32Array, cap: int) -> Dictionary:
	var counts: PackedInt32Array = PackedInt32Array()
	var n: int = 0
	for i: int in kit_verts.size():
		if kit_verts[i] > cap:
			return {"counts": PackedInt32Array(), "error": "kit %d has %d vertices, cap %d" % [i, kit_verts[i], cap]}
		if n + kit_verts[i] > cap and n > 0:
			counts.append(n)
			n = 0
		n += kit_verts[i]
	if n > 0: counts.append(n)
	var err: String = ("needs %d surfaces" % counts.size()) if counts.size() > MAX_SURFACES else ""
	return {"counts": counts, "error": err}
static func _chunks(work: MapPlacementSet) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: int in maxi(0, work.chunk_starts.size() - 1):
		if work.chunk_starts[k + 1] > work.chunk_starts[k]:
			out.append(Vector2i(k % MapConst.CHUNKS_X, floori(k / float(MapConst.CHUNKS_X))))
	return out
static func _load(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) if FileAccess.file_exists(path) else null
static func _save(ctx: MapBakeContext, idx: MapChunkIndex, dir: String, c: Vector2i, res: Resource, box: AABB, n: int,
		sv: PackedInt32Array) -> bool:
	var path: String = dir + "chunk_%02d_%02d.res" % [c.x, c.y]
	var err: Error = ResourceSaver.save(res, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK: return ctx.fail("BakeChunkMerge: cannot save %s (error %d)" % [path, err])
	box.size.y += MapConst.LIFT
	idx.coords.append(Vector2(c))
	idx.paths.append(path)
	idx.aabbs.append(box)
	idx.vert_counts.append(n)
	idx.surface_verts.append(sv)
	return true
static func _finish(ctx: MapBakeContext, idx: MapChunkIndex, dir: String) -> bool:
	var verts: Dictionary = {}
	for i: int in idx.paths.size():
		verts[idx.paths[i].get_file().get_basename()] = idx.vert_counts[i]
	BakeTerrainWriter._remove_stale(dir, verts)
	var err: Error = ResourceSaver.save(idx, dir + INDEX_FILE)
	if err != OK: return ctx.fail("BakeChunkMerge: cannot save %s (error %d)" % [dir + INDEX_FILE, err])
	var lv: Variant = ctx.get_value(MapBakeManifest.VERTS_KEY)
	var layers: Dictionary = lv if lv is Dictionary else {}
	layers[String(idx.layer)] = verts
	ctx.put_value(MapBakeManifest.VERTS_KEY, layers)
	return true
#Open surface buffers in the PixelMeshBuilder format; absent kit arrays read as zeros, COLOR as white.
class Surf:
	var n: int = 0
	var pos: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var col: PackedColorArray = PackedColorArray()
	var c0: PackedByteArray = PackedByteArray()
	var c1: PackedByteArray = PackedByteArray()
	var idx: PackedInt32Array = PackedInt32Array()
	func add(a: Array, t: Transform3D, nb: int, spin: float) -> void:
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var k: int = vs.size()
		var u: Variant = a[Mesh.ARRAY_TEX_UV]
		var u2: Variant = a[Mesh.ARRAY_TEX_UV2]
		var cl: Variant = a[Mesh.ARRAY_COLOR]
		var t0: PackedByteArray = _bytes(a[Mesh.ARRAY_CUSTOM0], 4 * k)
		for j: int in k:
			pos.append(t * vs[j])
			uv.append((u as PackedVector2Array)[j] if u is PackedVector2Array else Vector2.ZERO)
			uv2.append(Vector2((u2 as PackedVector2Array)[j].x if u2 is PackedVector2Array else 0.0, spin))
			col.append((cl as PackedColorArray)[j] if cl is PackedColorArray else Color.WHITE)
			t0[4 * j] = nb
		c0.append_array(t0)
		c1.append_array(_bytes(a[Mesh.ARRAY_CUSTOM1], 8 * k))
		var src: Variant = a[Mesh.ARRAY_INDEX]
		var ia: PackedInt32Array = (src as PackedInt32Array) if src is PackedInt32Array else PackedInt32Array(range(k))
		for e: int in ia:
			idx.append(e + n)
		n += k
	static func _bytes(v: Variant, size: int) -> PackedByteArray:
		var b: PackedByteArray = (v as PackedByteArray).duplicate() if v is PackedByteArray else PackedByteArray()
		b.resize(size)
		return b
	func flush(mesh: ArrayMesh) -> void:
		var arrays: Array = [pos, null, null, col, uv, uv2, c0, c1, null, null, null, null, idx]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, PixelMeshBuilder.FORMAT)
