@tool
class_name MapLayer extends Node3D
#Keeps the chunk meshes of one baked layer resident, loading on threads. The editor keeps every chunk resident as
#internal unsaved children; the game streams by view rect plus a margin. Chunks share material (map global samplers).

signal chunk_loaded(c: Vector2i)

const LOAD_MARGIN: int = 1
const FREE_MARGIN: int = 2

@export var index_path: String = ""
@export var material: Material = null

var _index: MapChunkIndex = null
var _index_stamp: int = 0
var _gate: MapRenderGate = null
var _resident: Dictionary = {}
var _pending: Dictionary = {}
var _failed: Dictionary = {}
var _keep_rect: Rect2i = Rect2i()
var _first: bool = true


#A script reload resets _resident but keeps the old internal chunk children; those go so chunks never double.
func _enter_tree() -> void:
	var keep: Array = _resident.values()
	for child: Node in get_children(true):
		if child.name.begins_with("chunk_") and not keep.has(child):
			remove_child(child)
			child.queue_free()
	if _resident.is_empty():
		_first = true
	if Engine.is_editor_hint() and _index != null:
		if _resident.size() < _index.coords.size() or _stamp() != _index_stamp:
			load_all.call_deferred()


func _ready() -> void:
	set_process(false)
	_load_index(ResourceLoader.CACHE_MODE_REUSE)
	if Engine.is_editor_hint():
		load_all.call_deferred()


func set_gate(g: MapRenderGate) -> void:
	_gate = g


#Requests every chunk not resident, pending or failed; _process adds them as they finish.
func load_all() -> void:
	if _index == null or _stamp() != _index_stamp:
		_load_index(ResourceLoader.CACHE_MODE_REUSE)
	if _index == null:
		return
	_keep_rect = Rect2i(0, 0, MapConst.CHUNKS_X, MapConst.CHUNKS_Y)
	for i: int in _index.coords.size():
		var c: Vector2i = Vector2i(_index.coords[i])
		if _resident.has(c) or _pending.has(c) or _failed.has(c):
			continue
		var path: String = _index.paths[i]
		if _sync():
			_add(c, load(path))
		elif ResourceLoader.load_threaded_request(path, "") == OK:
			_pending[c] = path
		else:
			_fail(c, path)
	set_process(not _pending.is_empty())


#Drops every chunk and rereads the index from disk; Bake Map calls it after a bake.
func reload() -> void:
	for c: Vector2i in _pending.keys():
		ResourceLoader.load_threaded_get(_pending[c])
	for child: Node in get_children(true):
		if child.name.begins_with("chunk_"):
			remove_child(child)
			child.queue_free()
	_resident.clear()
	_pending.clear()
	_failed.clear()
	_first = true
	set_process(false)
	_load_index(ResourceLoader.CACHE_MODE_REPLACE)
	if Engine.is_editor_hint():
		load_all()


func _load_index(mode: ResourceLoader.CacheMode) -> void:
	_index = null
	if index_path.is_empty() or not ResourceLoader.exists(index_path):
		return
	_index = ResourceLoader.load(index_path, "", mode) as MapChunkIndex
	_index_stamp = _stamp()


#Editor only: the index file time, so a tab that missed a bake reloads; 0 in the game and for a missing file.
func _stamp() -> int:
	if not Engine.is_editor_hint() or not FileAccess.file_exists(index_path):
		return 0
	return FileAccess.get_modified_time(index_path)


#Threaded MultiMesh loads corrupt RIDs in the headless dummy renderer (crash at exit), so headless loads inline.
static func _sync() -> bool:
	return DisplayServer.get_name() == "headless"


func has_index() -> bool:
	return _index != null


func resident_count() -> int:
	return _resident.size()


#r is the camera ground rect in image px. The first call loads the visible chunks blocking.
func set_view_rect(r: Rect2) -> void:
	if _index == null or Engine.is_editor_hint():
		return
	var cs: Array[Vector2i] = MapSpace.chunks_in_rect(r)
	if cs.is_empty():
		_keep_rect = Rect2i()
		_free_outside()
		return
	var view: Rect2i = Rect2i(cs[0], cs[cs.size() - 1] - cs[0] + Vector2i.ONE)
	var load_rect: Rect2i = view.grow(LOAD_MARGIN)
	_keep_rect = view.grow(FREE_MARGIN)
	_free_outside()
	for i: int in _index.coords.size():
		var c: Vector2i = Vector2i(_index.coords[i])
		if not load_rect.has_point(c) or _resident.has(c) or _pending.has(c) or _failed.has(c):
			continue
		var path: String = _index.paths[i]
		if (_first and view.has_point(c)) or _sync():
			_add(c, load(path))
		elif ResourceLoader.load_threaded_request(path, "") == OK:
			_pending[c] = path
		else:
			_fail(c, path)
	_first = false
	set_process(not _pending.is_empty())


func _process(_delta: float) -> void:
	for c: Vector2i in _pending.keys():
		var path: String = _pending[c]
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_pending.erase(c)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			if status == ResourceLoader.THREAD_LOAD_FAILED:
				ResourceLoader.load_threaded_get(path)
			_fail(c, path)
			continue
		var res: Resource = ResourceLoader.load_threaded_get(path)
		if _keep_rect.has_point(c):
			_add(c, res)
	if _pending.is_empty():
		set_process(false)


#Drains in-flight loads so the loader releases their tasks when the layer leaves the tree.
func _exit_tree() -> void:
	for c: Vector2i in _pending.keys():
		ResourceLoader.load_threaded_get(_pending[c])
	_pending.clear()
	set_process(false)


#A failed chunk warns once and is never requested again for the life of the layer.
func _fail(c: Vector2i, path: String) -> void:
	_failed[c] = true
	push_warning("MapLayer: failed to load " + path)


#A Mesh chunk is one MeshInstance3D; a MapInstanceChunk is a Node3D with one MultiMeshInstance3D per part.
func _add(c: Vector2i, res: Resource) -> void:
	if res == null:
		return
	var node: Node3D = null
	if res is Mesh:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = res as Mesh
		_setup(mi)
		node = mi
	elif res is MapInstanceChunk:
		node = _chunk_node(res as MapInstanceChunk)
	else:
		_fail(c, res.resource_path)
		return
	node.name = "chunk_%02d_%02d" % [c.x, c.y]
	if Engine.is_editor_hint():
		add_child(node, false, Node.INTERNAL_MODE_BACK)
	else:
		add_child(node)
	_resident[c] = node
	chunk_loaded.emit(c)
	if _gate != null:
		_gate.mark_dirty()


func _chunk_node(chunk: MapInstanceChunk) -> Node3D:
	var root: Node3D = Node3D.new()
	for i: int in chunk.parts.size():
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = chunk.models[i].replace("/", "_")
		mmi.multimesh = chunk.parts[i]
		_setup(mmi)
		root.add_child(mmi)
	return root


func _setup(gi: GeometryInstance3D) -> void:
	gi.material_override = material
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	#The vertex shader lifts hovered nations above the baked AABB.
	gi.extra_cull_margin = MapConst.LIFT


func _free_outside() -> void:
	for c: Vector2i in _resident.keys():
		if _keep_rect.has_point(c):
			continue
		var mi: Node3D = _resident[c]
		_resident.erase(c)
		mi.queue_free()
