@tool
class_name MapRenderGate extends Node
#Owns the map SubViewport update mode: disabled while locked, always while a token is held, once when dirty.

signal frame_rendered

@export var viewport_path: NodePath = NodePath("../Container/Viewport")

var _viewport: SubViewport = null
var _tokens: Dictionary = {}
var _dirty: bool = true
var _locked: bool = false
var _once_pending: bool = false
var _once_drawn: int = 0
var _once_frame: int = 0
var _undrawn: bool = false
var _expected: int = SubViewport.UPDATE_DISABLED


func _enter_tree() -> void:
	if _viewport != null:
		reapply.call_deferred()


func _ready() -> void:
	set_process(false)
	_viewport = get_node_or_null(viewport_path) as SubViewport
	if _viewport == null:
		push_warning("MapRenderGate: no SubViewport at " + String(viewport_path))
		return
	var container: Control = _viewport.get_parent() as Control
	if container != null:
		container.visibility_changed.connect(_on_container_visibility)
	reapply.call_deferred()


#The container resets the child update mode on enter-tree and visibility change; this puts ours back.
func _process(_delta: float) -> void:
	if _viewport == null:
		return
	var drawn: int = Engine.get_frames_drawn()
	if _once_pending and drawn > _once_drawn:
		_once_pending = false
		_undrawn = false
		frame_rendered.emit()
	elif _once_pending and Engine.get_process_frames() > _once_frame + 2:
		#No window can draw (headless or minimized): frames_drawn stalls, so finish now and keep ONCE armed.
		_once_pending = false
		_undrawn = true
		frame_rendered.emit()
	elif _undrawn and drawn > _once_drawn:
		_undrawn = false
	elif _expected == SubViewport.UPDATE_ALWAYS:
		frame_rendered.emit()
	_apply()


func mark_dirty() -> void:
	_dirty = true
	if Engine.is_editor_hint():
		_apply.call_deferred()


func is_dirty() -> bool:
	return _dirty


func acquire(token: StringName) -> void:
	if _tokens.has(token):
		return
	_tokens[token] = true
	_apply()


func release(token: StringName) -> void:
	if not _tokens.has(token):
		return
	_tokens.erase(token)
	if _tokens.is_empty():
		_dirty = true
	_apply()


func is_held(token: StringName) -> bool:
	return _tokens.has(token)


func set_locked(v: bool) -> void:
	if _locked == v:
		return
	_locked = v
	if not v:
		_dirty = true
	_apply()


func is_locked() -> bool:
	return _locked


func reapply() -> void:
	_dirty = true
	_apply()


func _on_container_visibility() -> void:
	reapply.call_deferred()


func _desired() -> int:
	return desired(_locked, not _tokens.is_empty(), _dirty, Engine.is_editor_hint())


#The editor ignores the lock and tokens: one frame per dirty mark bounds GPU work in the open scene.
static func desired(locked: bool, held: bool, dirty: bool, editor: bool) -> int:
	if editor:
		return SubViewport.UPDATE_ONCE if dirty else SubViewport.UPDATE_DISABLED
	if locked:
		return SubViewport.UPDATE_DISABLED
	if held:
		return SubViewport.UPDATE_ALWAYS
	if dirty:
		return SubViewport.UPDATE_ONCE
	return SubViewport.UPDATE_DISABLED


#The scene stores the update mode as DISABLED; it is put back for the save and reapplied after.
func _notification(what: int) -> void:
	if _viewport == null:
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		reapply.call_deferred()


#Processing runs only while a token is held or a once frame is pending; idle costs no callback.
func _apply() -> void:
	if _viewport == null or not is_inside_tree():
		return
	_apply_mode()
	set_process(_once_pending or _expected == SubViewport.UPDATE_ALWAYS)


func _apply_mode() -> void:
	var want: int = _desired()
	if want == SubViewport.UPDATE_ONCE:
		_dirty = false
		_once_pending = true
		_undrawn = false
		_once_drawn = Engine.get_frames_drawn()
		_once_frame = Engine.get_process_frames()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		#UPDATE_ONCE falls back to UPDATE_DISABLED after its frame draws.
		_expected = SubViewport.UPDATE_DISABLED
		return
	_expected = want
	if (_once_pending or _undrawn) and want == SubViewport.UPDATE_DISABLED:
		#An armed ONCE has not drawn yet; only the lock may cancel it.
		if not _locked:
			return
		_once_pending = false
	_undrawn = false
	if _viewport.render_target_update_mode != want:
		_viewport.render_target_update_mode = want as SubViewport.UpdateMode
