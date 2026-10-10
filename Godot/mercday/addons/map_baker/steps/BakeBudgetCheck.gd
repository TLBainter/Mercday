@tool
class_name BakeBudgetCheck extends MapBakeStep

#Last step: fails the bake when a chunk passes its vertex cap or Baked/ passes the disk cap; writes budget_report.json.
#It reads every layer folder that holds an index.tres, so later stages need no edit here.

const STAGE := 1
const REPORT_FILE := "budget_report.json"
const PROPS_LAYERS: PackedStringArray = ["props", "foliage", "ground"]


func _init() -> void:
	step_name = &"BakeBudgetCheck"
	stage = STAGE
	inputs = PackedStringArray(["terrain/index"])
	optional = PackedStringArray(["cell_color", "palette", "props/foliage/index", "props/ground/index"])
	outputs = PackedStringArray(["budget_report"])
	run_last = true


func run(ctx: MapBakeContext) -> bool:
	var layers: Dictionary = {}
	var problems: PackedStringArray = PackedStringArray()
	var dirs: PackedStringArray = DirAccess.get_directories_at(MapData.BAKED_DIR)
	for sub: String in DirAccess.get_directories_at(MapData.BAKED_DIR + "props"):
		dirs.append("props/" + sub)
	for dir: String in dirs:
		var path: String = "%s%s/index.tres" % [MapData.BAKED_DIR, dir]
		if not ResourceLoader.exists(path):
			continue
		var idx: MapChunkIndex = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MapChunkIndex
		if idx == null:
			problems.append("%s is not a MapChunkIndex" % path)
			continue
		var cap: int = cap_for(idx.layer)
		problems.append_array(check_index(idx, cap))
		var surfaces: int = 0
		var max_surfaces: int = 0
		var max_surface_verts: int = 0
		for i: int in idx.vert_counts.size():
			var sv: PackedInt32Array = idx.surfaces_of(i)
			surfaces += sv.size()
			max_surfaces = maxi(max_surfaces, sv.size())
			max_surface_verts = maxi(max_surface_verts, _max_of(sv))
		layers[dir] = {"chunks": idx.coords.size(), "total_verts": idx.total_verts(), "max_verts": _max_of(idx.vert_counts),
			"surfaces": surfaces, "max_surfaces": max_surfaces, "max_surface_verts": max_surface_verts, "cap": cap,
			"bytes": dir_bytes("%s%s/" % [MapData.BAKED_DIR, dir])}
	var disk: int = dir_bytes(MapData.BAKED_DIR)
	if disk > MapConst.BAKED_CAP_BYTES:
		problems.append("Baked/ is %d bytes, cap %d" % [disk, MapConst.BAKED_CAP_BYTES])
	var report: Dictionary = {"layers": layers, "disk_bytes": disk, "disk_cap_bytes": MapConst.BAKED_CAP_BYTES,
		"problems": Array(problems)}
	var file: FileAccess = FileAccess.open(MapData.BAKED_DIR + REPORT_FILE, FileAccess.WRITE)
	if file == null:
		return ctx.fail("cannot write %s" % REPORT_FILE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	for msg: String in problems:
		ctx.fail(msg)
	return problems.is_empty()


#One message per chunk total over cap (not for foliage, which splits into capped surfaces) and per surface over cap.
func check_index(idx: MapChunkIndex, cap: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for i: int in idx.vert_counts.size():
		var c: Vector2 = idx.coords[i] if i < idx.coords.size() else Vector2(-1, -1)
		if idx.layer != &"foliage" and idx.vert_counts[i] > cap:
			out.append("%s chunk %d,%d has %d vertices, cap %d" % [idx.layer, int(c.x), int(c.y), idx.vert_counts[i], cap])
		if i >= idx.surface_verts.size():
			continue
		var sv: PackedInt32Array = idx.surfaces_of(i)
		for s: int in sv.size():
			if sv[s] > cap:
				out.append("%s chunk %d,%d surface %d has %d vertices, cap %d" % [idx.layer, int(c.x), int(c.y), s, sv[s], cap])
	return out


static func cap_for(layer: StringName) -> int:
	if layer == &"terrain":
		return MapConst.TERRAIN_CHUNK_VERTS
	if layer == &"ground":
		return MapConst.GROUND_CHUNK_VERTS
	if PROPS_LAYERS.has(String(layer)):
		return MapConst.PROPS_CHUNK_VERTS
	return MapConst.STRUCT_CHUNK_VERTS


static func dir_bytes(path: String) -> int:
	var total: int = 0
	for f: String in DirAccess.get_files_at(path):
		var file: FileAccess = FileAccess.open(path.path_join(f), FileAccess.READ)
		if file != null:
			total += file.get_length()
	for d: String in DirAccess.get_directories_at(path):
		total += dir_bytes(path.path_join(d))
	return total


static func _max_of(counts: PackedInt32Array) -> int:
	var best: int = 0
	for n: int in counts:
		best = maxi(best, n)
	return best
