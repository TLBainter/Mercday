@tool
class_name MapView extends Control
#Root of the map band: wires camera, gate, layers, picker and highlight, routes input and applies the HUD lock.

signal hovered(kind: int, id: int)
signal clicked(kind: int, id: int)

const CLICK_SLOP: float = 4.0

@onready var _container: SubViewportContainer = $Container
@onready var _camera: MapCamera = $Container/Viewport/World/Camera
@onready var _gate: MapRenderGate = $Gate
@onready var _input: MapCameraInput = $Input
@onready var _picker: MapPicker = $Picker
@onready var _highlight: MapHighlight = $Highlight
var _layers: Array[MapLayer] = []
var _locked: bool = false
var _menu_open: bool = false
var _saved_filters: Dictionary = {}
var _press_at: Vector2 = Vector2.ZERO
#kind, id and 1 when the cursor is over the map image (0 is off the map).
var _hover: Vector3i = Vector3i.ZERO
var _mouse_in: bool = false


#The saved scene shares the editor world so the map shows in the 3D tab; the game gets a private world.
func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		(get_node("Container/Viewport") as SubViewport).own_world_3d = true


func _ready() -> void:
	for n: Node in $Container/Viewport/World.find_children("*", "MapLayer", true, false):
		_layers.append(n as MapLayer)
	if Engine.is_editor_hint():
		_editor_preview()
		return
	if not MapData.has_bake():
		push_warning("MapView: no baked terrain at " + MapData.TERRAIN_INDEX + "; the map stays hidden")
		_container.visible = false
		_gate.set_locked(true)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		return
	MapUniforms.set_gate(_gate)
	_camera.set_gate(_gate)
	for layer: MapLayer in _layers:
		layer.set_gate(_gate)
		_camera.view_rect_changed.connect(layer.set_view_rect)
		layer.set_view_rect(_camera.view_rect_img())
	MapGroupState.set_dirty_hook(set_process.bind(true))
	_camera.view_rect_changed.connect(_repick.unbind(1))
	resized.connect(_gate.mark_dirty)
	GuiFrameStack.add_changed_hook(_on_frames_changed)
	_on_frames_changed()


#The editor tab shows the start pose only: no gate statics, dirty hook, frame hooks, picker or input.
func _editor_preview() -> void:
	set_process(false)
	if not MapData.has_bake():
		push_warning("MapView: no baked terrain at " + MapData.TERRAIN_INDEX + "; the map stays hidden")
	_camera.set_gate(_gate)
	for layer: MapLayer in _layers:
		layer.set_gate(_gate)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	GuiFrameStack.remove_changed_hook(_on_frames_changed)
	MapGroupState.set_dirty_hook(Callable())


#Runs after the highlight and lift eases; stops once no ease writes group state.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	MapGroupState.flush()
	set_process(_group_easing())


func _group_easing() -> bool:
	var lift: MapLift = _highlight.lift
	return _highlight.is_easing() or (lift != null and lift.is_easing())


func camera() -> MapCamera:
	return _camera


func gate() -> MapRenderGate:
	return _gate


func picker() -> MapPicker:
	return _picker


func is_locked() -> bool:
	return _locked


#MainMenuToggle calls it (ESC now, MenuToggleButton in stage 9); the menu locks input, the gate follows frames only.
func set_menu_open(v: bool) -> void:
	_menu_open = v
	if MapData.has_bake():
		_refresh_lock()


func is_menu_open() -> bool:
	return _menu_open


#Mouse filters go to IGNORE recursively and come back as they were; nothing is ever disabled.
func set_locked(v: bool) -> void:
	if _locked == v:
		return
	_locked = v
	_camera.locked = v
	if v:
		_input.handle(InputEventMouseButton.new())
		_set_hover(0, 0, false)
		_saved_filters.clear()
		_ignore_mouse(self)
		return
	for key: Variant in _saved_filters.keys():
		if is_instance_valid(key):
			(key as Control).mouse_filter = _saved_filters[key]
	_saved_filters.clear()


func _on_frames_changed() -> void:
	_refresh_lock()


func _refresh_lock() -> void:
	var frames: bool = GuiFrameStack.depth() > 0
	_gate.set_locked(frames)
	set_locked(frames or _menu_open)


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _locked:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MapCameraInput.DRAG_BUTTON:
		if mb.pressed:
			_press_at = mb.position
		elif mb.position.distance_to(_press_at) <= CLICK_SLOP:
			var hit: Vector3i = _pick(mb.position)
			if hit.y != 0:
				clicked.emit(hit.x, hit.y)
	if _input.handle(event):
		accept_event()
	if event is InputEventMouse and not _input.is_dragging():
		_hover_at((event as InputEventMouse).position)


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	if what == NOTIFICATION_MOUSE_ENTER:
		_mouse_in = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_mouse_in = false
		if not _locked:
			_set_hover(0, 0, false)


#The ground moves under a still cursor on zoom, key pan and fly, so the hover is picked again.
func _repick() -> void:
	if _mouse_in and not _locked and not _input.is_dragging():
		_hover_at(get_local_mouse_position())


func _hover_at(band_px: Vector2) -> void:
	var hit: Vector3i = _pick(band_px)
	_set_hover(hit.x, hit.y, hit.z != 0)


func _pick(band_px: Vector2) -> Vector3i:
	var hit: Dictionary = _picker.pick(band_px)
	var img: Vector2 = hit.get("img", Vector2(-1.0, -1.0))
	var on_map: bool = Rect2(Vector2.ZERO, Vector2(MapConst.IMG_W, MapConst.IMG_H)).has_point(img)
	return Vector3i(int(hit.get("kind", 0)), int(hit.get("id", 0)), 1 if on_map else 0)


#Id 0 on the map is open water and dims every nation; off the map nothing dims.
func _set_hover(kind: int, id: int, on_map: bool) -> void:
	var next: Vector3i = Vector3i(kind, id, 1 if on_map else 0)
	if next == _hover:
		return
	_hover = next
	if on_map:
		_highlight.set_hover(kind, id)
	else:
		_highlight.clear()
	set_process(true)
	hovered.emit(kind, id)


func _ignore_mouse(node: Node) -> void:
	var c: Control = node as Control
	if c != null:
		_saved_filters[c] = c.mouse_filter
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
