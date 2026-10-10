@tool
class_name BakeKits extends MapBakeStep

#Writes one mesh per pixel kit and variant, the 72 lean ground clump kits and the ice box kit under Baked/kits/.
#A kit file is rewritten only when the MD5 of its surface arrays differs from hashes.json or the file is missing.

const STAGE := 3
const SCATTER_KEY := "src/map-scatter.json"
const HASHES_FILE := "hashes.json"


func _init() -> void:
	step_name = &"BakeKits"
	stage = STAGE
	outputs = PackedStringArray(["kits/*"])


func run(ctx: MapBakeContext) -> bool:
	var d2: Variant = ctx.get_value(SCATTER_KEY)
	if not (d2 is Dictionary):
		return ctx.fail("BakeKits: map-scatter.json missing")
	#BakeKits has no input key so it stays pinned; scat_ids come from the same BakeScatterRules.build call.
	var scat: Array = BakeScatterRules.build(d2, {})["scat_ids"]
	var dir: String = ctx.path_of("kits/*").trim_suffix("/*") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var old_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + HASHES_FILE)) \
		if FileAccess.file_exists(dir + HASHES_FILE) else null
	var old: Dictionary = old_v if old_v is Dictionary else {}
	var hashes: Dictionary = {}
	var written: int = 0
	var b: PixelMeshBuilder = PixelMeshBuilder.new()
	b.begin(PixelAtlas.load_default())
	for sid: String in PixelKitBuilder.ids():
		var s: float = ScatterGrid.SCAT_S if scat.has(sid) else 1.0
		for v: int in range(-1, PixelKitBuilder.variant_count(StringName(sid))):
			var m: PixelModel = PixelKitBuilder.build(StringName(sid), &"buern", 0.4, v)
			if m == null:
				return ctx.fail("BakeKits: kit %s variant %d did not build" % [sid, v])
			var got: int = _keep(dir, String(m.id), b.build(m, s), old, hashes)
			if got < 0:
				return ctx.fail("BakeKits: cannot save %s%s.res" % [dir, m.id])
			written += got
	var gv: Dictionary = GroundCoverMeshes.variants((d2 as Dictionary).get("GS", {}))
	for kind: String in BakeGroundCover.GKI:
		for v: int in GroundCoverMeshes.VARIANTS:
			var name: String = "g_%d" % ((int(BakeGroundCover.GKI[kind]) * GroundCoverMeshes.VARIANTS + v) * 2)
			var got: int = _keep(dir, name, GroundCoverMeshes.mesh(kind, v, 0, gv[kind][v]), old, hashes)
			if got < 0:
				return ctx.fail("BakeKits: cannot save %s%s.res" % [dir, name])
			written += got
	var ice: int = _keep(dir, "ice_box", GroundCoverMeshes.ice_box(), old, hashes)
	if ice < 0:
		return ctx.fail("BakeKits: cannot save %sice_box.res" % dir)
	written += ice
	var text: String = JSON.stringify(hashes, "\t", true)
	if not FileAccess.file_exists(dir + HASHES_FILE) or FileAccess.get_file_as_string(dir + HASHES_FILE) != text:
		var file: FileAccess = FileAccess.open(dir + HASHES_FILE, FileAccess.WRITE)
		if file == null:
			return ctx.fail("BakeKits: cannot write %s" % HASHES_FILE)
		file.store_string(text)
		var err: Error = file.get_error()
		file.close()
		if err != OK:
			return ctx.fail("BakeKits: write failed %s" % HASHES_FILE)
	ctx.log("kits rewritten %d of %d" % [written, hashes.size()])
	return true


#Records the digest of mesh under name; returns 1 when the file was written, 0 when kept, -1 on a save error.
static func _keep(dir: String, name: String, mesh: ArrayMesh, old: Dictionary, hashes: Dictionary) -> int:
	var h: HashingContext = HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	for s: int in mesh.get_surface_count():
		h.update(var_to_bytes(mesh.surface_get_arrays(s)))
	var digest: String = h.finish().hex_encode()
	hashes[name] = digest
	var path: String = dir + name + ".res"
	if String(old.get(name, "")) == digest and FileAccess.file_exists(path):
		return 0
	return 1 if ResourceSaver.save(mesh, path) == OK else -1
