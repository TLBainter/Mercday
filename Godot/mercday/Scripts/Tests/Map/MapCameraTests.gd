class_name MapCameraTests extends RefCounted
#Camera zoom steps, clamps, height damp, fly_to, gate token, input routing, MapSpace round trips and gate update modes.
#Run: godot --headless --path . -- --map-camera-tests

const DT: float = 0.05


class GateSpy extends MapRenderGate:
	var held: Dictionary = {}
	var dirty: int = 0

	func _ready() -> void:
		set_process(false)

	func acquire(who: StringName) -> void:
		held[who] = true

	func release(who: StringName) -> void:
		held.erase(who)

	func mark_dirty() -> void:
		dirty += 1


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_space(res)
	var vp: SubViewport = _rig(host)
	var cam: MapCamera = vp.get_node("Camera") as MapCamera
	var spy: GateSpy = vp.get_node("Gate") as GateSpy
	_case_zoom(res, cam)
	_case_clamp(res, cam)
	_case_damp(res, cam, spy)
	_case_fly(res, cam)
	_case_input(res, cam, vp.get_node("Input") as MapCameraInput)
	vp.queue_free()
	await _case_update_mode(res, host)
	return TestFixtures.summarize(res, "MAP CAMERA")


static func _rig(host: Node) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.size = MapConst.RENDER_SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var spy: GateSpy = GateSpy.new()
	spy.name = "Gate"
	vp.add_child(spy)
	var cam: MapCamera = MapCamera.new()
	cam.name = "Camera"
	cam.set_gate(spy)
	vp.add_child(cam)
	var input: MapCameraInput = MapCameraInput.new()
	input.name = "Input"
	input.camera_path = NodePath("../Camera")
	vp.add_child(input)
	host.add_child(vp)
	cam.set_process(false)
	cam.field = _flat_field(0.3)
	cam.set_target(Vector2(MapConst.PLAY_RECT.get_center()))
	cam.settle()
	return vp


static func _flat_field(h: float) -> Image:
	var w: int = ceili(float(MapConst.IMG_W) / MapConst.GRID) + 1
	var hh: int = ceili(float(MapConst.IMG_H) / MapConst.GRID) + 1
	var img: Image = Image.create_empty(w, hh, false, Image.FORMAT_RF)
	img.fill(Color(h, 0.0, 0.0))
	return img


static func _steps(cam: MapCamera, n: int) -> void:
	for _i: int in n:
		cam.step(DT)


static func _case_space(res: Dictionary) -> void:
	var p: Vector2 = Vector2(1234.0, 987.0)
	var m: Vector2 = MapSpace.img_to_map(p)
	TestFixtures.check(res, "img to map subtracts the pad", m == Vector2(434.0, 487.0), str(m))
	TestFixtures.check(res, "map to img round trip", MapSpace.map_to_img(m) == p, str(p))
	var w: Vector3 = MapSpace.img_to_world(p, 42.0)
	TestFixtures.check(res, "world round trip keeps image px and height", MapSpace.world_to_img(w) == p and w.y == 42.0, str(w))


static func _case_zoom(res: Dictionary, cam: MapCamera) -> void:
	TestFixtures.check(res, "zoom starts at the default", cam.zoom() == MapConst.ZOOM_DEFAULT, str(cam.zoom()))
	cam.zoom_step(1)
	TestFixtures.check(res, "one wheel step adds 0.25", is_equal_approx(cam.zoom_target(), 1.75), str(cam.zoom_target()))
	cam.step(DT)
	var mid: float = cam.zoom()
	_steps(cam, 40)
	var eased: bool = mid > 1.5 and mid < 1.75 and cam.zoom() == 1.75
	TestFixtures.check(res, "zoom eases then snaps to the goal", eased, "%s %s" % [mid, cam.zoom()])
	for _i: int in 4:
		cam.zoom_step(1)
	TestFixtures.check(res, "zoom stops at ZOOM_MAX", cam.zoom_target() == MapConst.ZOOM_MAX, str(cam.zoom_target()))
	cam.settle()
	var near_w: float = cam.view_rect_img().size.x
	for _i: int in 8:
		cam.zoom_step(-1)
	TestFixtures.check(res, "zoom stops at ZOOM_MIN", cam.zoom_target() == MapConst.ZOOM_MIN, str(cam.zoom_target()))
	cam.settle()
	var far_w: float = cam.view_rect_img().size.x
	TestFixtures.check(res, "zoomed out view rect is wider", far_w > near_w * 1.5, "%s %s" % [far_w, near_w])
	TestFixtures.check(res, "view rect holds the target", cam.view_rect_img().has_point(cam.target()), str(cam.view_rect_img()))
	cam.zoom_step(2)
	cam.settle()


static func _case_clamp(res: Dictionary, cam: MapCamera) -> void:
	var r: Rect2i = MapConst.PLAY_RECT
	cam.set_target(Vector2(-100.0, -100.0))
	TestFixtures.check(res, "target clamps to the play area top left", cam.target() == Vector2(r.position), str(cam.target()))
	cam.set_target(Vector2(99999.0, 99999.0))
	var br: Vector2 = Vector2(r.end - Vector2i.ONE)
	TestFixtures.check(res, "target clamps to the play area bottom right", cam.target() == br, str(cam.target()))
	cam.pan_by(Vector2(-99999.0, 0.0))
	TestFixtures.check(res, "pan stops at the west edge", cam.target() == Vector2(800.0, 2659.0), str(cam.target()))
	cam.set_target(Vector2(r.get_center()))


static func _case_damp(res: Dictionary, cam: MapCamera, spy: GateSpy) -> void:
	var y0: float = cam.global_position.y
	var goal: float = MapSpace.height_to_y(0.6)
	var gap: float = goal - MapSpace.height_to_y(0.3)
	cam.field = _flat_field(0.6)
	var start: int = spy.dirty
	cam.step(DT)
	var rise: float = cam.global_position.y - y0
	TestFixtures.check(res, "height damp eases in from rest", rise > 0.0 and rise < 0.05 * gap, str(rise))
	var held: bool = cam.is_moving() and spy.held.has(MapCamera.TOKEN)
	TestFixtures.check(res, "camera holds the gate token while damping", held, str(spy.held))
	_steps(cam, 160)
	var y: float = cam.global_position.y - MapConst.CAM_HEIGHT / cam.zoom()
	TestFixtures.check(res, "height damp converges on the field", absf(y - goal) < 0.01, "%s vs %s" % [y, goal])
	TestFixtures.check(res, "token released once still", not cam.is_moving() and spy.held.is_empty(), str(spy.held))
	TestFixtures.check(res, "moving marks the gate dirty", spy.dirty > start, str(spy.dirty - start))
	var still: int = spy.dirty
	_steps(cam, 10)
	var quiet: bool = spy.dirty == still and spy.held.is_empty()
	TestFixtures.check(res, "a still camera stops marking dirty", quiet, str(spy.dirty - still))


static func _case_fly(res: Dictionary, cam: MapCamera) -> void:
	TestFixtures.check(res, "fly duration has a 0.6 s floor", is_equal_approx(MapCamera.fly_seconds(0.0), 0.6), "")
	TestFixtures.check(res, "fly duration is 0.5 + dist / 2500", is_equal_approx(MapCamera.fly_seconds(1250.0), 1.0), "")
	TestFixtures.check(res, "fly duration has a 1.6 s cap", is_equal_approx(MapCamera.fly_seconds(9000.0), 1.6), "")
	var e: float = MapEase.ease_in_out_cubic(0.25)
	TestFixtures.check(res, "easeInOutCubic shape", e == 0.0625 and MapEase.ease_in_out_cubic(0.5) == 0.5, str(e))
	cam.set_target(Vector2(1000.0, 1000.0))
	cam.fly_to(Vector2(3500.0, 1000.0))
	_steps(cam, 15)
	TestFixtures.check(res, "fly is half way at half time", absf(cam.target().x - 2250.0) < 1.0, str(cam.target()))
	_steps(cam, 17)
	TestFixtures.check(res, "fly lands on the goal", cam.target() == Vector2(3500.0, 1000.0), str(cam.target()))
	cam.fly_to(Vector2(1000.0, 1000.0))
	cam.step(DT)
	var at: Vector2 = cam.target()
	cam.pan_by(Vector2.ZERO)
	_steps(cam, 10)
	TestFixtures.check(res, "a pan cancels the glide", cam.target() == at, str(cam.target()))
	cam.settle()


static func _case_input(res: Dictionary, cam: MapCamera, input: MapCameraInput) -> void:
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	var z: float = cam.zoom_target()
	var out: bool = input.handle(wheel) and cam.zoom_target() == z - MapConst.ZOOM_STEP
	TestFixtures.check(res, "wheel down zooms out one step", out, str(cam.zoom_target()))
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MapCameraInput.DRAG_BUTTON
	press.pressed = true
	input.handle(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(10.0, 0.0)
	var x: float = cam.target().x
	TestFixtures.check(res, "drag right moves the target west", input.handle(motion) and cam.target().x < x, str(cam.target()))
	cam.locked = true
	var at: Vector2 = cam.target()
	var used: bool = input.handle(motion) or input.handle(wheel)
	var kept: bool = cam.target() == at and cam.zoom_target() == z - MapConst.ZOOM_STEP
	TestFixtures.check(res, "locked camera ignores input", not used and kept, str(cam.target()))
	TestFixtures.check(res, "lock drops the drag", not input.is_dragging(), "")
	cam.locked = false


#The gate leaves UPDATE_ALWAYS once the map is idle and puts it back off after the container wakes it on show.
static func _case_update_mode(res: Dictionary, host: Node) -> void:
	if not MapTestFixtures.require_baked(res, "terrain/index.tres"):
		return
	var view: MapView = MapTestFixtures.make_view(host)
	var vp: SubViewport = view.get_node_or_null("Container/Viewport") as SubViewport
	if vp == null:
		TestFixtures.check(res, "MapView has Container/Viewport", false, "")
		view.queue_free()
		return
	var live: bool = view.is_visible_in_tree() and not view.gate().is_locked()
	TestFixtures.check(res, "map view is shown with an unlocked gate", live, "frames open: %d" % GuiFrameStack.depth())
	if not live:
		view.queue_free()
		return
	await _watch(host, vp, 1.0)
	var busy: int = await _watch(host, vp, 0.5)
	var why: String = "%d frames ALWAYS, mode %d" % [busy, vp.render_target_update_mode]
	TestFixtures.check(res, "idle map leaves UPDATE_ALWAYS and stays off", busy == 0 and _idle_mode(vp), why)
	view.hide()
	await host.get_tree().process_frame
	view.show()
	var woke: bool = vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS
	await _watch(host, vp, 0.5)
	busy = await _watch(host, vp, 0.5)
	why = "woke %s, %d frames ALWAYS, mode %d" % [woke, busy, vp.render_target_update_mode]
	TestFixtures.check(res, "update mode survives a hide and show", woke and busy == 0 and _idle_mode(vp), why)
	view.queue_free()


static func _idle_mode(vp: SubViewport) -> bool:
	return vp.render_target_update_mode in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED]


#Waits secs of frames and returns how many of them had the viewport on UPDATE_ALWAYS.
static func _watch(host: Node, vp: SubViewport, secs: float) -> int:
	var end: int = Time.get_ticks_msec() + int(secs * 1000.0)
	var busy: int = 0
	while Time.get_ticks_msec() < end:
		await host.get_tree().process_frame
		if vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
			busy += 1
	return busy
