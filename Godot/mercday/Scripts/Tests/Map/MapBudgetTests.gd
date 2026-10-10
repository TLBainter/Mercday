class_name MapBudgetTests extends RefCounted

#Chunk vertex caps, Baked/ size and the stage 1 census baseline. Run after every bake:
#godot --headless --path . -- --map-budget-tests. The baseline holds for BASELINE_VERSION; a new bake_version replaces it.

const BASELINE := {"chunks_non_empty": [173, 175], "terrain_verts_max": 1700000, "side_quads": [272817, 284817]}
const BASELINE_VERSION: int = 1
#River blocks include map-core wcol blocks; block_levels counts levels above the water line.
#blocks_total is fixed by the grid, so the sea, river and land split and the level count are what can drift.
const CENSUS_BASE := {"blocks_total": 4215040, "chunks_non_empty": 174, "side_quads": 278817, "blocks_sea": 2636484,
	"blocks_river": 35658, "blocks_land": 1542898, "block_levels": 18}

static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_check_index(res)
	if MapTestFixtures.require_baked(res, "terrain/index.tres") and MapTestFixtures.require_baked(res, "manifest.tres") \
			and MapTestFixtures.require_baked(res, BakeBudgetCheck.REPORT_FILE):
		_case_disk(res)
		_case_chunks(res)
		_case_report(res)
		_case_census(res)
		_case_props(res)
	return TestFixtures.summarize(res, "MAP BUDGET")

static func _case_check_index(res: Dictionary) -> void:
	var idx: MapChunkIndex = MapChunkIndex.new()
	idx.layer = &"terrain"
	idx.coords = PackedVector2Array([Vector2(0, 0), Vector2(1, 0)])
	var cap: int = MapConst.TERRAIN_CHUNK_VERTS
	idx.vert_counts = PackedInt32Array([10, cap + 1])
	var step: BakeBudgetCheck = BakeBudgetCheck.new()
	var bad: PackedStringArray = step.check_index(idx, cap)
	var one: bool = bad.size() == 1 and bad[0].contains("1,0")
	TestFixtures.check(res, "check_index flags exactly the chunk over the cap", one, str(bad))
	idx.vert_counts = PackedInt32Array([10, cap])
	TestFixtures.check(res, "check_index passes a chunk at the cap", step.check_index(idx, cap).is_empty(), "cap %d" % cap)
	idx.layer = &"foliage"
	idx.surface_verts = [PackedInt32Array([10, MapConst.PROPS_CHUNK_VERTS + 1])]
	bad = step.check_index(idx, BakeBudgetCheck.cap_for(&"foliage"))
	TestFixtures.check(res, "check_index flags surface 1", bad.size() == 1 and bad[0].contains("surface 1"), str(bad))
	TestFixtures.check(res, "layer caps: terrain 60000, props 40000, ground 500000, others 20000",
		BakeBudgetCheck.cap_for(&"terrain") == 60000 and BakeBudgetCheck.cap_for(&"props") == 40000 \
		and BakeBudgetCheck.cap_for(&"ground") == 500000 and BakeBudgetCheck.cap_for(&"routes") == 20000,
		"constants in MapConst")

static func _case_disk(res: Dictionary) -> void:
	var bytes: int = BakeBudgetCheck.dir_bytes(MapData.BAKED_DIR)
	TestFixtures.check(res, "Baked/ is within the disk cap", bytes <= MapConst.BAKED_CAP_BYTES,
		"%d of %d bytes" % [bytes, MapConst.BAKED_CAP_BYTES])

static func _case_chunks(res: Dictionary) -> void:
	var idx: MapChunkIndex = ResourceLoader.load(MapData.TERRAIN_INDEX, "", ResourceLoader.CACHE_MODE_IGNORE) as MapChunkIndex
	if idx == null:
		TestFixtures.check(res, "terrain index loads as MapChunkIndex", false, MapData.TERRAIN_INDEX)
		return
	var over: Array[String] = []
	for i: int in idx.vert_counts.size():
		if idx.vert_counts[i] > MapConst.TERRAIN_CHUNK_VERTS:
			over.append("%s=%d" % [str(idx.coords[i]), idx.vert_counts[i]])
	TestFixtures.check(res, "every terrain chunk is within the vertex cap", over.is_empty(),
		TestFixtures.detail(over, idx.vert_counts.size(), "chunks"))
	var count: int = idx.coords.size()
	var range_: Array = BASELINE["chunks_non_empty"]
	TestFixtures.check(res, "non-empty terrain chunks within the baseline range", count >= range_[0] and count <= range_[1],
		"%d chunks, expected %d to %d" % [count, range_[0], range_[1]])
	var missing: Array[String] = []
	for p: String in idx.paths:
		if not ResourceLoader.exists(p):
			missing.append(p.get_file())
	TestFixtures.check(res, "every indexed chunk file exists", missing.is_empty() and idx.paths.size() == count,
		TestFixtures.detail(missing, idx.paths.size(), "files"))
	var total: int = idx.total_verts()
	TestFixtures.check(res, "whole map terrain vertices within the cap", total <= MapConst.TERRAIN_TOTAL_VERTS,
		"%d of %d" % [total, MapConst.TERRAIN_TOTAL_VERTS])
	var manifest: MapBakeManifest = MapBakeManifest.open()
	var layer: Dictionary = manifest.chunk_verts.get("terrain", {})
	var worst: int = 0
	var sum: int = 0
	for chunk: Variant in layer:
		worst = maxi(worst, int(layer[chunk]))
		sum += int(layer[chunk])
	TestFixtures.check(res, "manifest per chunk counts are within the cap and match the index",
		not layer.is_empty() and worst <= MapConst.TERRAIN_CHUNK_VERTS and sum == total,
		"manifest %d chunks, worst %d, sum %d, index %d" % [layer.size(), worst, sum, total])

static func _case_report(res: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MapData.BAKED_DIR + BakeBudgetCheck.REPORT_FILE))
	if not (parsed is Dictionary):
		TestFixtures.check(res, "budget_report.json parses", false, "not a JSON object")
		return
	var report: Dictionary = parsed
	var terrain: Dictionary = (report.get("layers", {}) as Dictionary).get("terrain", {})
	var problems: Array = report.get("problems", [])
	TestFixtures.check(res, "report lists terrain with a max under the cap and no problems",
		int(terrain.get("max_verts", -1)) in range(0, MapConst.TERRAIN_CHUNK_VERTS + 1) and problems.is_empty(),
		"terrain %s problems %s" % [str(terrain), str(problems)])

static func _case_census(res: Dictionary) -> void:
	var manifest: MapBakeManifest = MapBakeManifest.open()
	if manifest.version != BASELINE_VERSION:
		print("SKIP census drift | bake version %d replaces baseline %d" % [manifest.version, BASELINE_VERSION])
		return
	var census: Dictionary = manifest.census
	var drift: Array[String] = []
	var absent: Array[String] = []
	for key: String in CENSUS_BASE:
		if not census.has(key):
			absent.append(key)
			continue
		var base: float = float(CENSUS_BASE[key])
		if absf(float(census[key]) - base) > base * MapConst.CENSUS_TOLERANCE:
			drift.append("%s %d vs %d" % [key, int(census[key]), int(CENSUS_BASE[key])])
	TestFixtures.check(res, "manifest census holds every baseline key", absent.is_empty(),
		"missing %s, census keys %s" % [str(absent), str(census.keys())])
	TestFixtures.check(res, "census drift stays within 5 percent of the baseline", drift.is_empty(),
		TestFixtures.detail(drift, CENSUS_BASE.size() - absent.size(), "keys"))
	var quads: int = int(census.get("side_quads", -1))
	var bounds: Array = BASELINE["side_quads"]
	TestFixtures.check(res, "side quads within the baseline range", quads >= bounds[0] and quads <= bounds[1],
		"%d, expected %d to %d" % [quads, bounds[0], bounds[1]])
	var total: int = int(census.get("terrain_verts_total", -1))
	var top: int = BASELINE["terrain_verts_max"]
	TestFixtures.check(res, "terrain vertices within the baseline ceiling", total >= 0 and total <= top, "%d of %d" % [total, top])

static func _case_props(res: Dictionary) -> void:
	var any: bool = false
	for layer: String in ["foliage", "ground"]:
		var path: String = "%sprops/%s/index.tres" % [MapData.BAKED_DIR, layer]
		if not ResourceLoader.exists(path):
			continue
		any = true
		var idx: MapChunkIndex = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MapChunkIndex
		if idx == null:
			TestFixtures.check(res, "%s index loads as MapChunkIndex" % layer, false, path)
			continue
		var over: Array[String] = []
		var mismatch: Array[String] = []
		for i: int in idx.vert_counts.size():
			var sv: PackedInt32Array = idx.surfaces_of(i)
			var total: int = 0
			for n: int in sv:
				total += n
				if layer == "foliage" and n > MapConst.PROPS_CHUNK_VERTS:
					over.append("%s=%d" % [str(idx.coords[i]), n])
			if layer == "ground" and idx.vert_counts[i] > MapConst.GROUND_CHUNK_VERTS:
				over.append("%s=%d" % [str(idx.coords[i]), idx.vert_counts[i]])
			if total != idx.vert_counts[i]:
				mismatch.append("%s %d vs %d" % [str(idx.coords[i]), total, idx.vert_counts[i]])
		TestFixtures.check(res, "%s chunks are within the surface or chunk cap" % layer, over.is_empty(),
			TestFixtures.detail(over, idx.vert_counts.size(), "chunks"))
		TestFixtures.check(res, "%s surface sums equal the chunk totals and surface_verts parallels coords" % layer,
			mismatch.is_empty() and idx.surface_verts.size() == idx.coords.size(),
			"%s, %d vs %d entries" % [TestFixtures.detail(mismatch, idx.vert_counts.size(), "chunks"),
			idx.surface_verts.size(), idx.coords.size()])
		var bad: Array[String] = []
		for i: int in range(0, idx.paths.size(), maxi(1, (idx.paths.size() + 7) >> 3)):
			var want: PackedInt32Array = idx.surfaces_of(i)
			var got: Resource = ResourceLoader.load(idx.paths[i], "", ResourceLoader.CACHE_MODE_IGNORE)
			if got is ArrayMesh:
				var mesh: ArrayMesh = got
				var lens: PackedInt32Array = PackedInt32Array()
				for s: int in mesh.get_surface_count():
					lens.append(mesh.surface_get_array_len(s))
				if lens != want:
					bad.append("%s %s vs %s" % [idx.paths[i].get_file(), str(lens), str(want)])
			elif got is MapInstanceChunk:
				var chunk: MapInstanceChunk = got
				if chunk.parts.size() != want.size() or chunk.part_verts != want:
					bad.append("%s parts %d vs %d" % [idx.paths[i].get_file(), chunk.parts.size(), want.size()])
			else:
				bad.append("%s does not load" % idx.paths[i].get_file())
		TestFixtures.check(res, "%s sampled chunks match their index surfaces" % layer, bad.is_empty(),
			TestFixtures.detail(bad, mini(8, idx.paths.size()), "chunks"))
	if not any: print("NOTE props | no props baked")
