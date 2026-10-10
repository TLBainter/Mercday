@tool
class_name MapBakerPlugin extends EditorPlugin

#Adds the one Project > Tools entry Bake Map: runs every step under the manifest skip rule, then refreshes the
#MapLayers of the open scene in place. Steps are found by scanning res://addons/map_baker/steps/.
#Raises the editor far plane and freelook speed for the world scene; an open 3D viewport reads default_z_far at
#editor start only.

const MENU_ITEM := "Bake Map"
const Z_FAR_SETTING := "editors/3d/default_z_far"
const Z_FAR_MIN := 10000.0
const FREELOOK_SETTING := "editors/3d/freelook/freelook_base_speed"
const FREELOOK_MIN := 200.0

var _runner: MapBakeRunner = null


func _enter_tree() -> void:
	_runner = MapBakeRunner.new()
	_runner.finished.connect(_on_finished)
	add_tool_menu_item(MENU_ITEM, _bake_map)
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	_raise_setting(settings, Z_FAR_SETTING, Z_FAR_MIN)
	_raise_setting(settings, FREELOOK_SETTING, FREELOOK_MIN)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	_runner.wait()
	_runner = null


static func _raise_setting(settings: EditorSettings, key: String, low: float) -> void:
	if not settings.has_setting(key) or float(settings.get_setting(key)) < low:
		settings.set_setting(key, low)


func _bake_map() -> void:
	_start(MapBakeRunner.load_steps(), false)


func _start(steps: Array[MapBakeStep], downstream: bool) -> void:
	if _runner.busy:
		push_warning("map_baker: a bake is already running")
		return
	_runner.run(steps, downstream)


func _on_finished(ok: bool, lines: PackedStringArray) -> void:
	if ok:
		print("map_baker: finished, %d log lines" % lines.size())
		_refresh()
	else:
		push_error("map_baker: bake failed: %s" % (lines[lines.size() - 1] if not lines.is_empty() else "no log"))


#Drops the cached bake data and chunk meshes, rebinds the globals, then reloads every MapLayer of the open scene.
func _refresh() -> void:
	MapData.reset()
	MapWorldBind.reset()
	if ResourceLoader.exists(MapData.TERRAIN_INDEX):
		ResourceLoader.load(MapData.TERRAIN_INDEX, "", ResourceLoader.CACHE_MODE_REPLACE)
	var idx: MapChunkIndex = MapData.chunk_index()
	if idx != null:
		for path: String in idx.paths:
			ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_REPLACE)
	var kits: PackedStringArray = DirAccess.get_files_at(MapData.BAKED_DIR + "kits")
	kits.sort()
	for f: String in kits:
		if f.ends_with(".res"):
			ResourceLoader.load(MapData.BAKED_DIR + "kits/" + f, "", ResourceLoader.CACHE_MODE_REPLACE)
	for index_path: String in [MapData.BAKED_DIR + "props/foliage/index.tres", MapData.BAKED_DIR + "props/ground/index.tres"]:
		if not ResourceLoader.exists(index_path):
			continue
		var props: MapChunkIndex = ResourceLoader.load(index_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MapChunkIndex
		if props == null:
			continue
		for path: String in props.paths:
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	MapWorldBind.bind_globals()
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return
	for layer: Node in root.find_children("*", "MapLayer", true, false):
		(layer as MapLayer).reload()
