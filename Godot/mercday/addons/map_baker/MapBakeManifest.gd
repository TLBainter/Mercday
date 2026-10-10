@tool
class_name MapBakeManifest extends Resource

#Records the bake version, per-step input checksums and output sizes, the block census and chunk vertex counts.
#Steps hand the census and vertex counts over through the context keys below; absorb copies them in.

const BAKE_VERSION := 1
const FILE_NAME := "manifest.tres"
#Value: Dictionary of census counts (blocks, side quads and so on).
const CENSUS_KEY := "manifest/census"
#Value: Dictionary layer -> Dictionary chunk name -> vertex count; a layer replaces the stored one.
const VERTS_KEY := "manifest/chunk_verts"

@export var version: int = BAKE_VERSION
#step_name -> {"inputs": {key: md5}, "outputs": {key: bytes}, "ms": int}
@export var steps: Dictionary = {}
@export var census: Dictionary = {}
@export var chunk_verts: Dictionary = {}
@export var wall_ms: int = 0


#The stored manifest, or a fresh one when it is missing or from another bake version.
static func open() -> MapBakeManifest:
	var path: String = MapData.BAKED_DIR + FILE_NAME
	if ResourceLoader.exists(path):
		var stored: MapBakeManifest = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MapBakeManifest
		if stored != null and stored.version == BAKE_VERSION:
			return stored
	return MapBakeManifest.new()


#Drops entries of steps that no longer exist.
func prune(live: PackedStringArray) -> void:
	for key: String in steps.keys():
		if not live.has(key):
			steps.erase(key)


#True when the version, the step script, every input checksum and every output file still match the last run of the step.
func is_current(step: MapBakeStep, ctx: MapBakeContext) -> bool:
	if version != BAKE_VERSION or not steps.has(String(step.step_name)):
		return false
	var entry: Dictionary = steps[String(step.step_name)]
	if entry.get("script", "") != _script_md5(step):
		return false
	var recorded: Dictionary = entry.get("inputs", {})
	for key: String in step.inputs + step.optional:
		if recorded.get(key, "") != _md5(ctx, key):
			return false
	var outs: Dictionary = entry.get("outputs", {})
	for key: String in step.outputs + step.modifies:
		if not outs.has(key) or int(outs[key]) < 0:
			return false
		if not FileAccess.file_exists(ctx.path_of(key)) and not DirAccess.dir_exists_absolute(ctx.path_of(key)):
			return false
	return true


#Output bytes are -1 for a key with no file (in-memory only), which keeps the step from ever counting as current.
func record(step: MapBakeStep, ctx: MapBakeContext, ms: int) -> void:
	var ins: Dictionary = {}
	for key: String in step.inputs + step.optional:
		ins[key] = _md5(ctx, key)
	var outs: Dictionary = {}
	for key: String in step.outputs + step.modifies:
		var path: String = ctx.path_of(key)
		if DirAccess.dir_exists_absolute(path):
			outs[key] = 0
		else:
			var file: FileAccess = FileAccess.open(path, FileAccess.READ) if FileAccess.file_exists(path) else null
			outs[key] = file.get_length() if file != null else -1
	steps[String(step.step_name)] = {"inputs": ins, "outputs": outs, "ms": ms, "script": _script_md5(step)}


func absorb(ctx: MapBakeContext) -> void:
	if ctx.has(CENSUS_KEY):
		census.merge(ctx.get_value(CENSUS_KEY) as Dictionary, true)
	if ctx.has(VERTS_KEY):
		var layers: Dictionary = ctx.get_value(VERTS_KEY)
		for layer: Variant in layers:
			chunk_verts[layer] = layers[layer]


func save_to_disk() -> Error:
	version = BAKE_VERSION
	var dir: String = MapData.BAKED_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	return ResourceSaver.save(self, dir + FILE_NAME)


static func _md5(ctx: MapBakeContext, key: String) -> String:
	var path: String = ctx.path_of(key)
	return FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""


static func _script_md5(step: MapBakeStep) -> String:
	var script: Script = step.get_script() as Script
	return FileAccess.get_md5(script.resource_path) if script != null and script.resource_path != "" else ""
