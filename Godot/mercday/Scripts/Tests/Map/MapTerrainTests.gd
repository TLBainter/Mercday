class_name MapTerrainTests extends RefCounted

#Baked terrain output: chunk index integrity, AABBs, vertex caps, CUSTOM0 decode and nation border skirts.
#Run: godot --headless --path . -- --map-terrain-tests. Reads Baked/ only; skips when the bake is absent.

const SAMPLE_STEP: int = 9
const QUADS_PER_CHUNK: int = 6
const SCAN_ROW_STEP: int = 4
const EPS: float = 0.05


static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	if MapTestFixtures.require_baked(res, "terrain/index.tres"):
		var idx: MapChunkIndex = MapData.chunk_index()
		_case_index(res, idx)
		_case_aabb(res, idx)
		_case_caps(res, idx)
		var level: Image = MapData.block_level()
		var nation: Image = MapData.block_nation()
		TestFixtures.check(res, "baked block_level and block_nation load", level != null and nation != null,
			"level %s nation %s" % [level != null, nation != null])
		if level != null and nation != null:
			_case_custom0(res, idx, level, nation)
			_case_skirt(res, level, nation)
	return TestFixtures.summarize(res, "MAP TERRAIN")


static func _case_index(res: Dictionary, idx: MapChunkIndex) -> void:
	var n: int = idx.coords.size()
	TestFixtures.check(res, "index parallel arrays agree",
		n > 0 and idx.paths.size() == n and idx.aabbs.size() == n and idx.vert_counts.size() == n, "coords %d" % n)
	var seen: Dictionary = {}
	var dup: int = 0
	var missing: int = 0
	var outside: int = 0
	for i: int in n:
		var c: Vector2i = Vector2i(idx.coords[i])
		if seen.has(c):
			dup += 1
		seen[c] = true
		if c.x < 0 or c.y < 0 or c.x >= MapConst.CHUNKS_X or c.y >= MapConst.CHUNKS_Y:
			outside += 1
		if not ResourceLoader.exists(idx.paths[i]):
			missing += 1
	TestFixtures.check(res, "chunk count 173 to 175", n >= 173 and n <= 175, "chunks %d" % n)
	TestFixtures.check(res, "no duplicate coords, none outside the grid", dup == 0 and outside == 0,
		"dup %d outside %d" % [dup, outside])
	TestFixtures.check(res, "every chunk path resolves", missing == 0, "missing %d" % missing)
	TestFixtures.check(res, "find() round trips every coord", _find_ok(idx), "find")
	TestFixtures.check(res, "find() reports -1 for an empty chunk", idx.find(Vector2i(-1, -1)) == -1, "find(-1,-1)")


static func _find_ok(idx: MapChunkIndex) -> bool:
	for i: int in idx.coords.size():
		if idx.find(Vector2i(idx.coords[i])) != i:
			return false
	return true


static func _case_aabb(res: Dictionary, idx: MapChunkIndex) -> void:
	var map_rect: Rect2 = Rect2(-MapConst.PAD_L, -MapConst.PAD_T, MapConst.IMG_W, MapConst.IMG_H).grow(EPS)
	var bad: Array[String] = []
	for i: int in idx.coords.size():
		var box: AABB = idx.aabbs[i]
		var c: Vector2i = Vector2i(idx.coords[i])
		var cr: Rect2i = MapSpace.chunk_rect_img(c)
		var own: Rect2 = Rect2(MapSpace.img_to_map(Vector2(cr.position)), Vector2(cr.size)).grow(EPS)
		var flat: Rect2 = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if not map_rect.encloses(flat) or not own.encloses(flat) or box.size.y <= 0.0 or box.position.y < 0.0:
			bad.append("%d,%d" % [c.x, c.y])
	TestFixtures.check(res, "every AABB inside the map and its own chunk",
		bad.is_empty(), TestFixtures.detail(bad, idx.coords.size(), "chunks"))


static func _case_caps(res: Dictionary, idx: MapChunkIndex) -> void:
	var over: Array[String] = []
	for i: int in idx.coords.size():
		if idx.vert_counts[i] > MapConst.TERRAIN_CHUNK_VERTS or idx.vert_counts[i] <= 0:
			over.append("%d:%d" % [i, idx.vert_counts[i]])
	TestFixtures.check(res, "no chunk above 60000 vertices", over.is_empty(),
		TestFixtures.detail(over, idx.coords.size(), "chunks"))
	var mism: Array[String] = []
	for i: int in range(0, idx.coords.size(), SAMPLE_STEP):
		var mesh: ArrayMesh = load(idx.paths[i]) as ArrayMesh
		if mesh == null or mesh.get_surface_count() != 1 or mesh.surface_get_array_len(0) != idx.vert_counts[i]:
			mism.append(idx.paths[i].get_file())
	TestFixtures.check(res, "sampled meshes match vert_counts", mism.is_empty(), ", ".join(mism))


static func _case_custom0(res: Dictionary, idx: MapChunkIndex, level: Image, nation: Image) -> void:
	var bad_tag: Array[String] = []
	var bad_nation: Array[String] = []
	var bad_height: Array[String] = []
	var tops: int = 0
	var sides: int = 0
	for i: int in range(0, idx.coords.size(), SAMPLE_STEP):
		var file: String = idx.paths[i].get_file()
		var mesh: ArrayMesh = load(idx.paths[i]) as ArrayMesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var pos: PackedVector3Array = _positions(mesh)
		var tags: PackedByteArray = arrays[Mesh.ARRAY_CUSTOM0]
		if tags.size() != pos.size() * 4:
			bad_tag.append("%s size %d" % [file, tags.size()])
			continue
		var total: int = pos.size() / 4
		var stride: int = maxi(total / QUADS_PER_CHUNK, 1)
		for qi: int in range(0, total, stride):
			var base: int = qi * 4
			var face: int = tags[base * 4 + 3]
			var code: int = face & 7
			if tags[base * 4 + 1] != 0 or tags[base * 4 + 2] != 0 or code > 4 or (face & 0xf0) != 0:
				bad_tag.append("%s v%d" % [file, base])
				continue
			if code != 0:
				sides += 1
				continue
			tops += 1
			var mid: Vector3 = (pos[base] + pos[base + 1] + pos[base + 2] + pos[base + 3]) / 4.0
			var b: Vector2i = MapSpace.img_to_block(MapSpace.map_to_img(Vector2(mid.x, mid.z)))
			if (tags[base * 4] & MapData.NATION_MASK) != (nation.get_pixel(b.x, b.y).r8 & MapData.NATION_MASK):
				bad_nation.append("%s v%d" % [file, base])
			if absf(mid.y - MapSpace.level_to_y(level.get_pixel(b.x, b.y).r8)) > EPS:
				bad_height.append("%s v%d" % [file, base])
	TestFixtures.check(res, "CUSTOM0 y and z zero, face code 0 to 4, sway bits clear", bad_tag.is_empty(),
		TestFixtures.detail(bad_tag, tops + sides, "quads"))
	TestFixtures.check(res, "top quad nation byte decodes to the block nation", tops > 0 and bad_nation.is_empty(),
		TestFixtures.detail(bad_nation, tops, "top quads"))
	TestFixtures.check(res, "top quad height decodes to the block level", bad_height.is_empty(),
		TestFixtures.detail(bad_height, tops, "top quads"))
	TestFixtures.check(res, "sampled chunks include side quads", sides > 0, "sides %d" % sides)


#Vertex-only compressed positions do not decode through surface_get_arrays; read the RGBA16 stream against the AABB.
static func _positions(mesh: ArrayMesh) -> PackedVector3Array:
	var surf: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var data: PackedByteArray = surf.get("vertex_data", PackedByteArray())
	var box: AABB = surf.get("aabb", AABB())
	var out: PackedVector3Array = PackedVector3Array()
	for o: int in range(0, data.size() - 7, 8):
		var q: Vector3 = Vector3(data.decode_u16(o), data.decode_u16(o + 2), data.decode_u16(o + 4)) / 65535.0
		out.append(box.position + q * box.size)
	return out


static func _case_skirt(res: Dictionary, level: Image, nation: Image) -> void:
	var found: Vector2i = _find_border(level, nation)
	TestFixtures.check(res, "a nation border exists at equal solid level", found.x >= 0, "scan")
	if found.x < 0:
		return
	var c: Vector2i = MapSpace.block_to_chunk(found)
	var runs: PackedInt32Array = BakeTerrainSides.sides_chunk(level, nation, null, c)
	var hit: bool = false
	for i: int in range(0, runs.size(), BakeTerrainSides.STRIDE):
		var covers: bool = runs[i] == found.x and found.y >= runs[i + 1] and found.y < runs[i + 1] + runs[i + 2]
		if covers and runs[i + 3] == 3 and runs[i + 4] == runs[i + 5]:
			hit = true
	TestFixtures.check(res, "skirt run (equal top and bottom) on the east face of a border block", hit,
		"block %s chunk %s runs %d" % [found, c, runs.size() / BakeTerrainSides.STRIDE])
	TestFixtures.check(res, "the border chunk is in the index", MapData.chunk_index().find(c) >= 0, str(c))


#First block whose east neighbour has the same solid level and a different non-zero nation; (-1, -1) when none.
static func _find_border(level: Image, nation: Image) -> Vector2i:
	var w: int = nation.get_width()
	var lv: PackedByteArray = _bytes(level)
	var nb: PackedByteArray = _bytes(nation)
	var solid: PackedByteArray = BakeTerrainGreedy.top_levels()
	for y: int in range(0, nation.get_height(), SCAN_ROW_STEP):
		for x: int in w - 1:
			var p: int = y * w + x
			var a: int = nb[p] & MapData.NATION_MASK
			var b: int = nb[p + 1] & MapData.NATION_MASK
			if a != 0 and b != 0 and a != b and lv[p] == lv[p + 1] and solid[lv[p]] != 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _bytes(img: Image) -> PackedByteArray:
	if img.get_format() == Image.FORMAT_R8:
		return img.get_data()
	var copy: Image = img.duplicate()
	copy.convert(Image.FORMAT_R8)
	return copy.get_data()
