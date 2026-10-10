@tool
class_name MapCamera extends Camera3D
#Fixed-pitch camera over a look-at target in image px: stepped eased zoom, SmoothDamp height over cam_field, fly_to.
#World is map px (MapSpace); the target is clamped to MapConst.PLAY_RECT; holds the gate token while it moves.

signal view_rect_changed(r: Rect2)

const TOKEN: StringName = &"camera"
const NEAR: float = 10.0
const DT_MAX: float = 0.05
const EPS: float = 0.01
const RAY_MAX: float = 4000.0
const CORNERS: Array[Vector2] = [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]

#Start pose; in the editor a change re-settles the camera so the open scene follows the inspector.
@export var start_target: Vector2 = Vector2(MapConst.PLAY_RECT.get_center()):
	set(v):
		start_target = v
		_target = clamp_img(v)
		if Engine.is_editor_hint() and is_inside_tree():
			settle()
@export_range(1.0, 2.0, 0.25) var start_zoom: float = MapConst.ZOOM_DEFAULT:
	set(v):
		start_zoom = v
		_zoom = v
		_zoom_to = v
		if Engine.is_editor_hint() and is_inside_tree():
			settle()

var locked: bool = false
#Blurred ground height field (RF, one texel per GRID image px); null falls back to the water line.
var field: Image = null
var _target: Vector2 = clamp_img(start_target)
var _zoom: float = start_zoom
var _zoom_to: float = start_zoom
var _y: float = 0.0
var _vy: float = 0.0
var _fly_from: Vector2 = Vector2.ZERO
var _fly_to: Vector2 = Vector2.ZERO
var _fly_t: float = 1.0
var _fly_dur: float = 0.0
var _holding: bool = false
var _gate_ref: MapRenderGate = null
var _rect: Rect2 = Rect2()
#Editor only: the saved camera values, put back before each scene save.
var _saved: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		_saved = MapWorldBind.capture(self, PackedStringArray(["transform", "fov", "near", "far"]))
		_editor_pose()
		return
	fov = MapConst.CAM_FOV
	near = NEAR
	far = MapConst.FAR_PLANE
	current = true
	field = MapData.cam_field()
	settle()


#The first camera in the viewport is current in the editor already, so current is not written.
func _editor_pose() -> void:
	fov = MapConst.CAM_FOV
	near = NEAR
	far = MapConst.FAR_PLANE
	field = MapData.cam_field()
	settle()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or _saved.is_empty():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		MapWorldBind.restore(self, _saved)
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_editor_pose.call_deferred()


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	_set_holding(false)


#Advances the glide, height damp and zoom ease by delta seconds and holds or releases the gate token.
func step(delta: float) -> void:
	var dt: float = minf(DT_MAX, delta)
	if _fly_dur > 0.0:
		_fly_t = minf(1.0, _fly_t + dt / _fly_dur)
		_target = _fly_from.lerp(_fly_to, MapEase.ease_in_out_cubic(_fly_t))
		if _fly_t >= 1.0:
			_target = _fly_to
			_fly_dur = 0.0
	var ground: float = ground_y(_target)
	var d: Vector2 = MapEase.smooth_damp(_y, ground, _vy, MapConst.CAM_SMOOTH_S, dt)
	_y = d.x
	_vy = d.y
	_zoom += (_zoom_to - _zoom) * (1.0 - exp(-dt * MapConst.ZOOM_RATE))
	if absf(_zoom_to - _zoom) < MapConst.ZOOM_SNAP:
		_zoom = _zoom_to
	_apply()
	_set_holding(_fly_dur > 0.0 or absf(_vy) > EPS or absf(_y - ground) > EPS or _zoom != _zoom_to)


func set_target(img_p: Vector2) -> void:
	_fly_dur = 0.0
	_target = clamp_img(img_p)
	_apply()
	set_process(true)


func pan_by(img_delta: Vector2) -> void:
	set_target(_target + img_delta)


#dir +1 zooms in one step, -1 out; the goal snaps to the 0.25 grid inside ZOOM_MIN..ZOOM_MAX.
func zoom_step(dir: int) -> void:
	var s: float = MapConst.ZOOM_STEP
	_zoom_to = clampf(roundf((_zoom_to + float(dir) * s) / s) * s, MapConst.ZOOM_MIN, MapConst.ZOOM_MAX)
	set_process(true)


func fly_to(img_p: Vector2) -> void:
	_fly_from = _target
	_fly_to = clamp_img(img_p)
	_fly_t = 0.0
	_fly_dur = fly_seconds(_fly_from.distance_to(_fly_to))
	set_process(true)


#Finishes any glide, zoom and height ease at once.
func settle() -> void:
	if _fly_dur > 0.0:
		_target = _fly_to
		_fly_dur = 0.0
	_zoom = _zoom_to
	_y = ground_y(_target)
	_vy = 0.0
	_apply()
	_set_holding(false)


func view_rect_img() -> Rect2:
	return _rect


func zoom() -> float:
	return _zoom


func zoom_target() -> float:
	return _zoom_to


func target() -> Vector2:
	return _target


func is_moving() -> bool:
	return _holding


#World y of the blurred ground under image px p, bilinear over the field.
func ground_y(p: Vector2) -> float:
	if field == null:
		return MapSpace.height_to_y(MapConst.WATER_H)
	var g: Vector2 = p / float(MapConst.GRID)
	var w: int = field.get_width()
	var h: int = field.get_height()
	var x0: int = clampi(floori(g.x), 0, w - 1)
	var y0: int = clampi(floori(g.y), 0, h - 1)
	var x1: int = mini(x0 + 1, w - 1)
	var y1: int = mini(y0 + 1, h - 1)
	var fx: float = clampf(g.x - float(x0), 0.0, 1.0)
	var fy: float = clampf(g.y - float(y0), 0.0, 1.0)
	var top: float = lerpf(field.get_pixel(x0, y0).r, field.get_pixel(x1, y0).r, fx)
	var bot: float = lerpf(field.get_pixel(x0, y1).r, field.get_pixel(x1, y1).r, fx)
	return MapSpace.height_to_y(lerpf(top, bot, fy))


static func clamp_img(p: Vector2) -> Vector2:
	var r: Rect2i = MapConst.PLAY_RECT
	return Vector2(clampf(p.x, r.position.x, r.end.x - 1), clampf(p.y, r.position.y, r.end.y - 1))


static func fly_seconds(dist: float) -> float:
	return clampf(MapConst.FLY_BASE_S + dist / MapConst.FLY_PX_PER_S, MapConst.FLY_MIN_S, MapConst.FLY_MAX_S)


func _apply() -> void:
	var p: float = deg_to_rad(MapConst.CAM_PITCH_DEG)
	var hgt: float = MapConst.CAM_HEIGHT / _zoom
	var look: Vector3 = MapSpace.img_to_world(_target, _y)
	var t: Transform3D = Transform3D(Basis.from_euler(Vector3(-p, 0.0, 0.0)), look + Vector3(0.0, hgt, hgt / tan(p)))
	if t.is_equal_approx(transform) and _rect.has_area():
		return
	transform = t
	_mark_dirty()
	var r: Rect2 = _ground_rect(t.origin, p)
	if not r.is_equal_approx(_rect):
		_rect = r
		view_rect_changed.emit(r)


#Image px bounding rect of the four frustum corner rays hitting the plane at the damped ground height.
func _ground_rect(eye: Vector3, p: float) -> Rect2:
	var view: Vector2 = Vector2(MapConst.RENDER_SIZE)
	if is_inside_tree():
		view = get_viewport().get_visible_rect().size
	var ty: float = tan(deg_to_rad(MapConst.CAM_FOV) * 0.5)
	var tx: float = ty * view.x / maxf(view.y, 1.0)
	var fw: Vector3 = Vector3(0.0, -sin(p), -cos(p))
	var up: Vector3 = Vector3(0.0, cos(p), -sin(p))
	var r: Rect2 = Rect2()
	for i: int in CORNERS.size():
		var c: Vector2 = CORNERS[i]
		var d: Vector3 = (fw + Vector3(c.x * tx, 0.0, 0.0) + up * (c.y * ty)).normalized()
		var s: float = RAY_MAX if d.y >= -0.0001 else minf(RAY_MAX, (_y - eye.y) / d.y)
		var q: Vector2 = MapSpace.world_to_img(eye + d * s)
		r = Rect2(q, Vector2.ZERO) if i == 0 else r.expand(q)
	return r


#MapView injects its gate after this camera readies; a World.tscn opened alone has none.
func set_gate(g: MapRenderGate) -> void:
	_gate_ref = g
	if g != null and _holding and not Engine.is_editor_hint():
		g.acquire(TOKEN)


func _gate() -> MapRenderGate:
	return _gate_ref


func _mark_dirty() -> void:
	var g: MapRenderGate = _gate()
	if g != null:
		g.mark_dirty()


#Processing stops once settled; set_target, zoom_step and fly_to wake it.
func _set_holding(v: bool) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		_holding = v
		return
	set_process(v)
	if v == _holding:
		return
	_holding = v
	var g: MapRenderGate = _gate()
	if g == null:
		return
	if v:
		g.acquire(TOKEN)
	else:
		g.release(TOKEN)
