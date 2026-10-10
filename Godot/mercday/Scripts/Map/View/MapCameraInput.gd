class_name MapCameraInput extends Node
#Turns drag, wheel and key input routed from MapView._gui_input into MapCamera pan and zoom calls.
#Ignored while the camera is locked; a lock drops any drag in progress.

const DRAG_BUTTON: MouseButton = MOUSE_BUTTON_LEFT
const KEY_PAN_PX: float = 64.0
const KEY_PAN: Dictionary = {KEY_LEFT: Vector2.LEFT, KEY_A: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_D: Vector2.RIGHT,
	KEY_UP: Vector2.UP, KEY_W: Vector2.UP, KEY_DOWN: Vector2.DOWN, KEY_S: Vector2.DOWN}
const KEY_ZOOM: Dictionary = {KEY_EQUAL: 1, KEY_KP_ADD: 1, KEY_MINUS: -1, KEY_KP_SUBTRACT: -1}
#Wheel delta px one full notch (factor 1.0) adds; matches a browser pixel-mode notch.
const WHEEL_NOTCH_PX: float = 100.0

@export var camera_path: NodePath = NodePath("../Container/Viewport/World/Camera")
@export var container_path: NodePath = NodePath("../Container")
@export var picker_path: NodePath = NodePath("../Picker")

var _dragging: bool = false
#World y of the plane through the ground grabbed at the drag press.
var _grab_y: float = 0.0
var _wheel_acc: float = 0.0


#Returns true when the event moved or zoomed the camera or started or ended a drag.
func handle(event: InputEvent) -> bool:
	var cam: MapCamera = get_node_or_null(camera_path) as MapCamera
	if cam == null or cam.locked:
		_dragging = false
		_wheel_acc = 0.0
		return false
	if event is InputEventMouseButton:
		return _button(cam, event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		if not _dragging:
			return false
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		cam.pan_by(_drag_delta(cam, mm.position - mm.relative, mm.position))
		return true
	if event is InputEventKey:
		return _key(cam, event as InputEventKey)
	return false


func is_dragging() -> bool:
	return _dragging


#Image px the ground moves at the target per band px of pointer travel; scales with zoom. Used for key pans.
func band_to_img(cam: MapCamera, d: Vector2) -> Vector2:
	var p: float = deg_to_rad(MapConst.CAM_PITCH_DEG)
	var dist: float = MapConst.CAM_HEIGHT / cam.zoom() / sin(p)
	var k: float = 2.0 * dist * tan(deg_to_rad(MapConst.CAM_FOV) * 0.5) / _band_height() / MapConst.WORLD_PER_PX
	return Vector2(d.x * k, d.y * k / sin(p))


func _button(cam: MapCamera, mb: InputEventMouseButton) -> bool:
	if mb.button_index == DRAG_BUTTON:
		_dragging = mb.pressed
		if mb.pressed:
			_grab_y = _grab_height(cam, mb.position)
		return true
	if not mb.pressed:
		return false
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_wheel(cam, 1, mb.factor)
		return true
	if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_wheel(cam, -1, mb.factor)
		return true
	return false


#Sums wheel delta so a smooth-scroll gesture zooms one step per WHEEL_STEP_ACCUM px; factor 0 means a whole notch.
func _wheel(cam: MapCamera, dir: int, factor: float) -> void:
	var f: float = factor if factor > 0.0 else 1.0
	_wheel_acc += float(dir) * f * WHEEL_NOTCH_PX
	if absf(_wheel_acc) < MapConst.WHEEL_STEP_ACCUM:
		return
	cam.zoom_step(1 if _wheel_acc > 0.0 else -1)
	_wheel_acc = 0.0


func _key(cam: MapCamera, key: InputEventKey) -> bool:
	if not key.pressed:
		return false
	if KEY_PAN.has(key.keycode):
		var dir: Vector2 = KEY_PAN[key.keycode]
		cam.pan_by(band_to_img(cam, dir * KEY_PAN_PX))
		return true
	if KEY_ZOOM.has(key.keycode) and not key.echo:
		cam.zoom_step(int(KEY_ZOOM[key.keycode]))
		return true
	return false


#Image px the target moves so the ground grabbed under from stays under to (previous minus current cursor ray hit).
func _drag_delta(cam: MapCamera, from: Vector2, to: Vector2) -> Vector2:
	var a: Vector2 = _plane_hit(cam, from)
	var b: Vector2 = _plane_hit(cam, to)
	if not a.is_finite() or not b.is_finite():
		return -band_to_img(cam, to - from)
	return a - b


#Image px where the cursor ray at band_px meets the plane y = _grab_y; INF when it points at or above the horizon.
func _plane_hit(cam: MapCamera, band_px: Vector2) -> Vector2:
	var p: float = deg_to_rad(MapConst.CAM_PITCH_DEG)
	var rect: Rect2 = _view_rect()
	var f: Vector2 = (band_px - rect.position) / rect.size
	var ty: float = tan(deg_to_rad(MapConst.CAM_FOV) * 0.5)
	var tx: float = ty * rect.size.x / rect.size.y
	var fw: Vector3 = Vector3(0.0, -sin(p), -cos(p))
	var up: Vector3 = Vector3(0.0, cos(p), -sin(p))
	var d: Vector3 = fw + Vector3((f.x * 2.0 - 1.0) * tx, 0.0, 0.0) + up * ((1.0 - f.y * 2.0) * ty)
	if d.y >= -0.0001:
		return Vector2(INF, INF)
	var eye: Vector3 = cam.transform.origin
	return MapSpace.world_to_img(eye + d * ((_grab_y - eye.y) / d.y))


#Ground height under the cursor from the picker; the camera look height when no picker is present.
func _grab_height(cam: MapCamera, band_px: Vector2) -> float:
	var look_y: float = cam.transform.origin.y - MapConst.CAM_HEIGHT / cam.zoom()
	var picker: MapPicker = get_node_or_null(picker_path) as MapPicker if not picker_path.is_empty() else null
	if picker == null:
		return look_y
	var img: Vector2 = picker.band_to_img(band_px)
	return look_y if img.x < 0.0 else picker.surface_y(img)


#Band px rect the 3D view fills: the viewport container, else the full band.
func _view_rect() -> Rect2:
	var c: Control = get_node_or_null(container_path) as Control if not container_path.is_empty() else null
	if c != null and c.size.x > 0.0 and c.size.y > 0.0:
		return Rect2(c.position, c.size)
	return Rect2(Vector2.ZERO, Vector2(MapConst.BAND_SIZE.x, _band_height()))


func _band_height() -> float:
	var host: Control = get_parent() as Control
	if host != null and host.size.y > 0.0:
		return host.size.y
	return float(MapConst.BAND_SIZE.y)
