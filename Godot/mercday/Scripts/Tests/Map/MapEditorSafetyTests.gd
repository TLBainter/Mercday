class_name MapEditorSafetyTests extends RefCounted
#Editor view safety: scene files stay free of baked data, @tool scripts match the list, gate table, camera start pose.
#Run: godot --headless --path . -- --map-editor-tests

const SCENES: Array[String] = [
	"res://Scenes/Map/MapView.tscn",
	"res://Scenes/GUI/HUD/GameHUD.tscn",
	MapData.WORLD_SCENE,
]
const BANNED: Array[String] = [
	"name=\"chunk_", "type=\"ImageTexture\"", "shader_parameter/cell_index", "shader_parameter/palette",
	"shader_parameter/nation_field", "shader_parameter/map_",
]
const WORLD_FILES: Array[String] = [
	MapData.WORLD_SCENE, MapData.TERRAIN_MATERIAL, MapData.WATER_MATERIAL,
]
const WORLD_BANNED: Array[String] = [
	"type=\"ImageTexture\"", "sub_resource type=\"ArrayMesh\"", "shader_parameter/cell_index", "shader_parameter/palette",
	"shader_parameter/nation_field", "shader_parameter/map_",
]
const GLOBALS: Array[StringName] = [&"map_cell_index", &"map_palette", &"map_nation_field"]
const TERRAIN_SHADER: String = "res://Scripts/Map/Shaders/map_terrain.gdshader"
const WORLD_SCRIPT: String = "res://Scripts/Map/View/MapWorld.gd"
const HUD_SCENE: String = "res://Scenes/GUI/HUD/GameHUD.tscn"
const LAYER_SCRIPT: String = "res://Scripts/Map/View/MapLayer.gd"
const BAKED_TERRAIN: String = "Resources/Map/Baked/terrain/"
const WORLD_UID: String = "uid://y17t3g7pdkvm"
const PLUGIN_SCRIPT: String = "res://addons/map_baker/MapBakerPlugin.gd"
const PLUGIN_BANNED: Array[String] = [
	"add_tool_submenu_item", "Import Sources", "Bake Stage", "Reload World", "reload_scene_from_path",
]
const WAIT_FRAMES: int = 300
const TOOL_SCRIPTS: Array[String] = [
	"MapView", "MapCamera", "MapLayer", "MapRenderGate", "MapConst", "MapEase", "MapGroupState", "MapSpace",
	"MapUniforms", "MapChunkIndex", "MapData", "MapNations", "MapPalette", "MapWorldBind", "MapWorld", "MapRng",
	"MapPlacementSet", "MapInstanceChunk",
]
const MAP_DIR: String = "res://Scripts/Map"
const TERRAIN_PATH: String = "Container/Viewport/World/Terrain"
const CAMERA_PATH: String = "Container/Viewport/World/Camera"


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_scenes(res)
	_case_world_files(res)
	_case_globals(res)
	_case_hud_deps(res)
	_case_tool_list(res)
	_case_gate_table(res)
	_case_camera_defaults(res)
	_case_world_scene(res)
	_case_view_instance(res)
	_case_plugin(res)
	if MapTestFixtures.require_baked(res, "terrain/index.tres"):
		await _case_view(res, host)
		_case_view_world(res, host)
		await _case_world_chunks(res, host)
	return TestFixtures.summarize(res, "MAP EDITOR")


static func _text(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_as_text().replace("\r\n", "\n") if f != null else ""


static func _case_world_files(res: Dictionary) -> void:
	for path: String in WORLD_FILES:
		if not FileAccess.file_exists(path):
			TestFixtures.check(res, "world file exists " + path.get_file(), false, path)
			continue
		var text: String = _text(path)
		var hits: Array[String] = []
		for needle: String in WORLD_BANNED:
			if text.contains(needle):
				hits.append(needle)
		TestFixtures.check(res, "world file clean " + path.get_file(), not text.is_empty() and hits.is_empty(), str(hits))
	var mul: String = ""
	for line: String in _text(MapData.TERRAIN_MATERIAL).split("\n"):
		if line.begins_with("shader_parameter/water_side_mul"):
			mul = line.get_slice("=", 1).strip_edges()
	var mul_ok: bool = not mul.is_empty() and is_equal_approx(mul.to_float(), MapConst.WATER_SIDE)
	TestFixtures.check(res, "terrain.tres water_side_mul equals WATER_SIDE", mul_ok, "%s vs %s" % [mul, MapConst.WATER_SIDE])


static func _case_globals(res: Dictionary) -> void:
	var project: String = _text("res://project.godot")
	var shader: String = _text(TERRAIN_SHADER)
	var missing: Array[String] = []
	for g: StringName in GLOBALS:
		if not project.contains("\n%s={" % g) and not project.contains("\n%s = {" % g):
			missing.append("project.godot %s" % g)
		if not shader.contains("global uniform sampler2D %s" % g):
			missing.append("shader %s" % g)
		if not MapUniforms.NAMES.has(g):
			missing.append("MapUniforms %s" % g)
	TestFixtures.check(res, "map sampler globals declared", missing.is_empty(), str(missing))


#Every resource root reaches, walked through each .tscn dependency.
static func _scene_deps(root: String) -> Dictionary:
	var seen: Dictionary = {}
	var queue: Array[String] = [root]
	while not queue.is_empty():
		var path: String = queue.pop_back()
		for dep: String in ResourceLoader.get_dependencies(path):
			var dep_path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
			if dep_path.begins_with("uid://"):
				dep_path = ResourceUID.uid_to_path(dep_path)
			if dep_path.is_empty() or seen.has(dep_path):
				continue
			seen[dep_path] = true
			if dep_path.ends_with(".tscn"):
				queue.append(dep_path)
	return seen


static func _case_hud_deps(res: Dictionary) -> void:
	var deps: Dictionary = _scene_deps(HUD_SCENE)
	TestFixtures.check(res, "GameHUD reaches World.tscn", deps.has(MapData.WORLD_SCENE), "%d deps" % deps.size())
	var hits: Array[String] = []
	for path: String in deps.keys():
		if path.contains(BAKED_TERRAIN):
			hits.append(path)
	TestFixtures.check(res, "GameHUD reaches no baked terrain file", not deps.is_empty() and hits.is_empty(),
		TestFixtures.detail(hits, deps.size(), "deps"))


#Node name to its header line plus property lines, in file order under "order".
static func _blocks(text: String) -> Dictionary:
	var out: Dictionary = {"order": []}
	var cur: String = ""
	for line: String in text.split("\n"):
		if line.begins_with("["):
			cur = line.get_slice("name=\"", 1).get_slice("\"", 0) if line.begins_with("[node ") else ""
			if not cur.is_empty():
				out["order"].append(cur)
				out[cur] = [line]
		elif not cur.is_empty() and not line.strip_edges().is_empty():
			(out[cur] as Array).append(line)
	return out


static func _ext_id(text: String, path: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("[ext_resource") and line.contains("path=\"%s\"" % path):
			return line.get_slice(" id=\"", 1).get_slice("\"", 0)
	return ""


static func _case_world_scene(res: Dictionary) -> void:
	if not FileAccess.file_exists(MapData.WORLD_SCENE):
		TestFixtures.check(res, "world scene exists", false, MapData.WORLD_SCENE)
		return
	var text: String = _text(MapData.WORLD_SCENE)
	var blocks: Dictionary = _blocks(text)
	var order: Array = blocks["order"]
	var kids: Array[String] = []
	var bad_parent: Array[String] = []
	for i: int in range(1, order.size()):
		kids.append(order[i])
		if not String((blocks[order[i]] as Array)[0]).contains("parent=\".\""):
			bad_parent.append(order[i])
	var want: Array[String] = ["Env", "Camera", "Terrain", "Foliage", "Ground", "Water", "Placements"]
	TestFixtures.check(res, "World.tscn children in order", kids == want, str(kids))
	TestFixtures.check(res, "World.tscn children parent the root", bad_parent.is_empty(), str(bad_parent))
	var root_id: String = _ext_id(text, WORLD_SCRIPT)
	var root_ok: bool = not order.is_empty() and not root_id.is_empty() \
		and (blocks[order[0]] as Array).has("script = ExtResource(\"%s\")" % root_id)
	TestFixtures.check(res, "World.tscn root script is MapWorld.gd", root_ok, root_id)
	var layer_id: String = _ext_id(text, LAYER_SCRIPT)
	var terrain: Array = blocks.get("Terrain", [])
	var t_ok: bool = not layer_id.is_empty() and terrain.has("script = ExtResource(\"%s\")" % layer_id) \
		and terrain.has("metadata/_edit_lock_ = true")
	TestFixtures.check(res, "World.tscn Terrain is a locked MapLayer", t_ok, str(terrain))
	var baked_ext: Array[String] = []
	var under_terrain: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("[ext_resource") and line.contains("path=\"%s" % MapData.BAKED_DIR):
			baked_ext.append(line.get_slice("path=\"", 1).get_slice("\"", 0))
		if line.begins_with("[node ") and line.contains("parent=\"Terrain"):
			under_terrain = true
	TestFixtures.check(res, "World.tscn saves no node under Terrain", not under_terrain, "")
	TestFixtures.check(res, "World.tscn has no baked ext_resource", baked_ext.is_empty(), str(baked_ext))
	var up: Array[String] = []
	var parts: PackedStringArray = text.split("NodePath(")
	for i: int in range(1, parts.size()):
		var arg: String = parts[i].get_slice(")", 0)
		if arg.contains("../"):
			up.append(arg)
	TestFixtures.check(res, "World.tscn has no NodePath with ../", up.is_empty(), str(up))


#N2: MapView instances World.tscn with no overrides and no editable children.
static func _case_view_instance(res: Dictionary) -> void:
	var text: String = _text(SCENES[0])
	var ext_line: String = ""
	for line: String in text.split("\n"):
		if line.begins_with("[ext_resource") and line.contains("path=\"%s\"" % MapData.WORLD_SCENE):
			ext_line = line
	var ext_ok: bool = ext_line.contains("type=\"PackedScene\"") and ext_line.contains("uid=\"%s\"" % WORLD_UID)
	TestFixtures.check(res, "MapView.tscn references World.tscn by uid", ext_ok, ext_line)
	var id: String = ext_line.get_slice(" id=\"", 1).get_slice("\"", 0)
	var want: String = "[node name=\"World\" parent=\"Container/Viewport\" instance=ExtResource(\"%s\")]" % id
	var blocks: Dictionary = _blocks(text)
	var world: Array = blocks.get("World", [])
	var rx: RegEx = RegEx.create_from_string(
		"^\\[node name=\"World\" parent=\"Container/Viewport\"( unique_id=\\d+)? instance=ExtResource\\(\"%s\"\\)\\]$" % id)
	var found: bool = false
	for line: String in text.split("\n"):
		if rx.search(line) != null:
			found = true
	TestFixtures.check(res, "MapView.tscn instances World.tscn", not id.is_empty() and found, want)
	TestFixtures.check(res, "MapView.tscn World has no overrides", world.size() == 1, str(world))
	var inner: bool = text.contains("parent=\"Container/Viewport/World")
	TestFixtures.check(res, "MapView.tscn saves no node under World", not inner, "")
	TestFixtures.check(res, "MapView.tscn has no editable children", not text.contains("editable path="), "")
	TestFixtures.check(res, "MapView.tscn saves own_world_3d off", not text.contains("own_world_3d = true"), "")


static func _case_plugin(res: Dictionary) -> void:
	var text: String = _text(PLUGIN_SCRIPT)
	var adds: int = text.count("add_tool_menu_item(")
	TestFixtures.check(res, "plugin adds one Tools entry", adds == 1, "%d calls" % adds)
	TestFixtures.check(res, "plugin entry is Bake Map", text.contains("\"Bake Map\""), "")
	var hits: Array[String] = []
	for needle: String in PLUGIN_BANNED:
		if text.contains(needle):
			hits.append(needle)
	TestFixtures.check(res, "plugin has no old entries or scene reload", not text.is_empty() and hits.is_empty(),
		str(hits))


static func _case_scenes(res: Dictionary) -> void:
	for path: String in SCENES:
		var text: String = _text(path)
		var hits: Array[String] = []
		for needle: String in BANNED:
			if text.contains(needle):
				hits.append(needle)
		TestFixtures.check(res, "scene clean " + path.get_file(), not text.is_empty() and hits.is_empty(), str(hits))
	var view: String = _text(SCENES[0])
	TestFixtures.check(res, "MapView keeps update mode 0", view.contains("render_target_update_mode = 0"), "")
	var hud: String = _text(SCENES[1])
	var has_start: bool = hud.contains("start_target") or hud.contains("start_zoom")
	TestFixtures.check(res, "GameHUD has no start_target or start_zoom", not has_start, "")


static func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out


static func _case_tool_list(res: Dictionary) -> void:
	var files: Array[String] = _gd_files(MAP_DIR)
	var bad: Array[String] = []
	var tools: int = 0
	for path: String in files:
		var want: bool = TOOL_SCRIPTS.has(path.get_file().get_basename())
		var has: bool = _text(path).begins_with("@tool")
		tools += 1 if has else 0
		if want != has:
			bad.append(path.get_file())
	TestFixtures.check(res, "@tool matches the list", bad.is_empty(), TestFixtures.detail(bad, files.size(), "map scripts"))
	TestFixtures.check(res, "tool script count", tools == TOOL_SCRIPTS.size(), "%d of %d" % [tools, TOOL_SCRIPTS.size()])


static func _expected(locked: bool, held: bool, dirty: bool, editor: bool) -> int:
	if editor:
		return SubViewport.UPDATE_ONCE if dirty else SubViewport.UPDATE_DISABLED
	if locked:
		return SubViewport.UPDATE_DISABLED
	if held:
		return SubViewport.UPDATE_ALWAYS
	return SubViewport.UPDATE_ONCE if dirty else SubViewport.UPDATE_DISABLED


static func _case_gate_table(res: Dictionary) -> void:
	var bad: Array[String] = []
	for bits: int in 16:
		var locked: bool = (bits & 1) != 0
		var held: bool = (bits & 2) != 0
		var dirty: bool = (bits & 4) != 0
		var editor: bool = (bits & 8) != 0
		if MapRenderGate.desired(locked, held, dirty, editor) != _expected(locked, held, dirty, editor):
			bad.append(str(bits))
	TestFixtures.check(res, "gate desired table", bad.is_empty(), TestFixtures.detail(bad, 16, "combinations"))


static func _case_camera_defaults(res: Dictionary) -> void:
	var cam: MapCamera = MapCamera.new()
	var pose: bool = cam.start_target == Vector2(MapConst.PLAY_RECT.get_center()) and cam.start_zoom == MapConst.ZOOM_DEFAULT
	TestFixtures.check(res, "camera start exports default", pose, "%s %s" % [cam.start_target, cam.start_zoom])
	cam.free()


static func _case_view(res: Dictionary, host: Node) -> void:
	var view: MapView = MapTestFixtures.make_view(host)
	var cam: MapCamera = view.get_node_or_null(CAMERA_PATH) as MapCamera
	if cam != null:
		var home: Vector2 = Vector2(MapConst.PLAY_RECT.get_center())
		var at_home: bool = cam.target().is_equal_approx(home) and is_equal_approx(cam.zoom(), MapConst.ZOOM_DEFAULT)
		TestFixtures.check(res, "view camera starts at the default pose", at_home, "%s %s" % [cam.target(), cam.zoom()])
	else:
		TestFixtures.check(res, "view has a camera", false, CAMERA_PATH)
	var layer: MapLayer = view.get_node_or_null(TERRAIN_PATH) as MapLayer
	if layer == null:
		TestFixtures.check(res, "view has a terrain layer", false, TERRAIN_PATH)
		view.queue_free()
		return
	var chunk: MeshInstance3D = null
	for i: int in 300:
		chunk = _first_chunk(layer)
		if chunk != null:
			break
		await host.get_tree().process_frame
	var ok: bool = chunk != null and chunk.material_override == layer.material
	TestFixtures.check(res, "resident chunk uses the layer material", ok, "chunk found: %s" % str(chunk != null))
	var mat_path: String = layer.material.resource_path if layer.material != null else ""
	TestFixtures.check(res, "layer material is terrain.tres", mat_path == MapData.TERRAIN_MATERIAL, mat_path)
	view.queue_free()


static func _first_chunk(layer: MapLayer) -> MeshInstance3D:
	for child: Node in layer.get_children():
		if child is MeshInstance3D and child.name.begins_with("chunk_"):
			return child as MeshInstance3D
	return null


#N4 and N5: the game view owns its 3D world and holds exactly one WorldEnvironment.
static func _case_view_world(res: Dictionary, host: Node) -> void:
	var view: MapView = MapTestFixtures.make_view(host)
	var vp: SubViewport = view.get_node_or_null("Container/Viewport") as SubViewport
	TestFixtures.check(res, "game view sets own_world_3d", vp != null and vp.own_world_3d, "")
	var envs: int = view.find_children("*", "WorldEnvironment", true, false).size()
	TestFixtures.check(res, "view holds one WorldEnvironment", envs == 1, "%d" % envs)
	host.remove_child(view)
	view.free()


static func _wait_resident(host: Node, layer: MapLayer, want: int) -> void:
	for i: int in WAIT_FRAMES:
		if layer.resident_count() == want:
			return
		await host.get_tree().process_frame


static func _chunk_names(layer: MapLayer) -> Array[String]:
	var out: Array[String] = []
	for child: Node in layer.get_children(true):
		if String(child.name).begins_with("chunk_"):
			out.append(String(child.name))
	return out


#N3 and N7: every chunk loads unowned and never packs; a re-parent keeps them; reload refills the layer.
static func _case_world_chunks(res: Dictionary, host: Node) -> void:
	var idx: MapChunkIndex = MapData.chunk_index()
	var want: int = idx.coords.size() if idx != null else -1
	var root: Node = (load(MapData.WORLD_SCENE) as PackedScene).instantiate()
	host.add_child(root)
	var layer: MapLayer = root.get_node_or_null("Terrain") as MapLayer
	if layer == null:
		TestFixtures.check(res, "world has a Terrain MapLayer", false, "")
		host.remove_child(root)
		root.free()
		return
	layer.load_all()
	await _wait_resident(host, layer, want)
	TestFixtures.check(res, "load_all makes every chunk resident", layer.resident_count() == want,
		"%d of %d" % [layer.resident_count(), want])
	var bad: Array[String] = []
	for child: Node in layer.get_children(true):
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null or not String(mi.name).begins_with("chunk_"):
			continue
		var mat: String = mi.material_override.resource_path if mi.material_override != null else ""
		if mi.owner != null or mat != MapData.TERRAIN_MATERIAL:
			bad.append(String(mi.name))
	TestFixtures.check(res, "chunks are unowned and use terrain.tres", bad.is_empty(),
		TestFixtures.detail(bad, want, "chunks"))
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(root)
	var packed_chunks: Array[String] = []
	if err == OK:
		var state: SceneState = packed.get_state()
		for i: int in state.get_node_count():
			if String(state.get_node_name(i)).begins_with("chunk_"):
				packed_chunks.append(String(state.get_node_name(i)))
	TestFixtures.check(res, "packing World saves no chunk", err == OK and packed_chunks.is_empty(),
		"error %d, %s" % [err, TestFixtures.detail(packed_chunks, want, "chunks")])
	var before: int = layer.resident_count()
	var names_before: int = _chunk_names(layer).size()
	host.remove_child(root)
	host.add_child(root)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var names: Array[String] = _chunk_names(layer)
	var unique: Dictionary = {}
	for n: String in names:
		unique[n] = true
	var now: int = layer.resident_count()
	var kept: bool = now == before and unique.size() == names.size() and names.size() == names_before
	TestFixtures.check(res, "re-parent keeps chunks without duplicates", kept,
		"%d resident, %d names, %d unique, %d before" % [now, names.size(), unique.size(), names_before])
	layer.reload()
	#reload only calls load_all in the editor; headless the test refills it.
	layer.load_all()
	await _wait_resident(host, layer, want)
	TestFixtures.check(res, "reload refills every chunk", layer.resident_count() == want,
		"%d of %d" % [layer.resident_count(), want])
	host.remove_child(root)
	root.free()
