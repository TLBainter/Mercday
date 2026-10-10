class_name MapHighlightTests extends RefCounted

#Hover and lift easing on a stepped clock: 140 ms lift, 450 ms dim, 0.25 dim factor, two-slot lift, islet rule,
#gate tokens and the MapGroupState values after the eases finish. Run: godot --headless --path . -- --map-highlight-tests

const DT: float = 0.01
const TOL: float = 0.012
const LIFT_PX: float = 10.0
const NAT: int = MapGroupState.Kind.NATION
const SETTLE: int = MapGroupState.Kind.SETTLEMENT
const IDS: Array[int] = [0, 1, 2, 3, 5]


class Rig extends RefCounted:
	var gate: MapRenderGate = MapRenderGate.new()
	var hl: MapHighlight = MapHighlight.new()
	var lift: MapLift = MapLift.new()

	func _init() -> void:
		hl.gate = gate
		hl.lift = lift
		lift.gate = gate
		for kind: int in [NAT, SETTLE]:
			for id: int in IDS:
				for ch: int in 4:
					MapGroupState.set_channel(kind, id, ch, 0.0)

	func tick(seconds: float) -> void:
		for _i: int in roundi(seconds / DT):
			hl.step(DT)
			lift.step(DT)

	func free_all() -> void:
		hl.free()
		lift.free()
		gate.free()


static func run(_host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_constants(res)
	_case_lift(res)
	_case_islet(res)
	_case_hover(res)
	_case_water_and_clear(res)
	_case_texture(res)
	return TestFixtures.summarize(res, "MAP HIGHLIGHT")


static func _near(a: float, b: float) -> bool:
	return absf(a - b) <= TOL


static func _ch(kind: int, id: int, ch: int) -> float:
	return MapGroupState.get_channel(kind, id, ch)


static func _case_constants(res: Dictionary) -> void:
	TestFixtures.check(res, "lift 10 px over 140 ms, dim 450 ms, dim factor 0.25", is_equal_approx(MapConst.LIFT, LIFT_PX)
		and MapConst.LIFT_MS == 140 and MapConst.DIM_MS == 450 and is_equal_approx(MapConst.DIM, 0.25),
		"%f %d %d %f" % [MapConst.LIFT, MapConst.LIFT_MS, MapConst.DIM_MS, MapConst.DIM])
	var e: MapEase = MapEase.new()
	e.target(1, 1.0, MapConst.LIFT_MS, MapEase.EaseCurve.SMOOTH)
	e.advance(0.07)
	TestFixtures.check(res, "smoothstep is 0.5 at half of 140 ms", _near(e.value(1), 0.5), str(e.value(1)))
	e.advance(0.07)
	TestFixtures.check(res, "ease ends exactly on target and goes idle", e.value(1) == 1.0 and not e.is_active(), "")
	e.target(2, 1.0, MapConst.DIM_MS, MapEase.EaseCurve.SMOOTHER)
	e.advance(0.225)
	TestFixtures.check(res, "smootherstep is 0.5 at half of 450 ms", _near(e.value(2), 0.5), str(e.value(2)))


static func _case_lift(res: Dictionary) -> void:
	var rig: Rig = Rig.new()
	rig.lift.set_lift(NAT, 1)
	TestFixtures.check(res, "lift token held on set_lift", rig.gate.is_held(&"lift"), "")
	rig.tick(0.07)
	TestFixtures.check(res, "mid rise: G 0.5 and lift_px 5", _near(_ch(NAT, 1, MapGroupState.CH_LIFT), 0.5)
		and absf(rig.lift.lift_px(NAT, 1) - LIFT_PX * 0.5) < 0.2, str(rig.lift.lift_px(NAT, 1)))
	#The gate is off-tree, so nothing clears its initial dirty flag; clear it here so the release must set it.
	rig.gate._dirty = false
	rig.tick(0.08)
	TestFixtures.check(res, "rise ends at G 1, lift_px 10, token released, gate dirty", _ch(NAT, 1, MapGroupState.CH_LIFT) == 1.0
		and is_equal_approx(rig.lift.lift_px(NAT, 1), LIFT_PX) and not rig.gate.is_held(&"lift") and rig.gate.is_dirty(), "")
	rig.lift.set_lift(NAT, 2)
	rig.tick(0.03)
	var fall: float = 1.0 - MapEase.smoothstep_q(0.03 / 0.14)
	TestFixtures.check(res, "old group falls while the new one rises (two live slots)",
		_near(_ch(NAT, 1, MapGroupState.CH_LIFT), fall) and _near(_ch(NAT, 2, MapGroupState.CH_LIFT), 1.0 - fall), "%f" % fall)
	rig.lift.set_lift(NAT, 1)
	rig.tick(0.01)
	var back: float = _ch(NAT, 1, MapGroupState.CH_LIFT)
	TestFixtures.check(res, "mid-fall re-entry starts from the current value", back >= fall - TOL and back < fall + 0.05, str(back))
	rig.tick(0.2)
	TestFixtures.check(res, "after the eases: 1 up, 2 down, token released", _ch(NAT, 1, MapGroupState.CH_LIFT) == 1.0
		and _ch(NAT, 2, MapGroupState.CH_LIFT) == 0.0 and not rig.gate.is_held(&"lift"), "")
	rig.free_all()


static func _case_islet(res: Dictionary) -> void:
	var rig: Rig = Rig.new()
	rig.lift.set_lift(NAT, 1)
	rig.tick(0.2)
	rig.lift.set_lift(NAT, 0)
	rig.tick(0.07)
	TestFixtures.check(res, "id 0 lifts nothing and lowers the current group", rig.lift.lifted() == Vector2i.ZERO
		and _ch(NAT, 0, MapGroupState.CH_LIFT) == 0.0 and rig.lift.lift_px(NAT, 0) == 0.0
		and _near(_ch(NAT, 1, MapGroupState.CH_LIFT), 0.5), "")
	rig.tick(0.2)
	TestFixtures.check(res, "islet row 0 stays flat after the eases", _ch(NAT, 0, MapGroupState.CH_LIFT) == 0.0
		and _ch(NAT, 1, MapGroupState.CH_LIFT) == 0.0, "")
	rig.free_all()


static func _case_hover(res: Dictionary) -> void:
	var rig: Rig = Rig.new()
	var events: Array[Vector2i] = []
	rig.hl.hover_changed.connect(func(k: int, i: int) -> void: events.append(Vector2i(k, i)))
	rig.hl.set_hover(NAT, 1)
	TestFixtures.check(res, "set_hover reports and holds the highlight token", rig.hl.hovered() == Vector2i(NAT, 1)
		and events == [Vector2i(NAT, 1)] and rig.gate.is_held(&"highlight") and rig.gate.is_held(&"lift"), str(events))
	rig.tick(0.07)
	var dim: float = MapEase.smootherstep(0.07 / 0.45)
	TestFixtures.check(res, "mid hover: R 0.5, other nations dim along the 450 ms curve, hovered stays 0",
		_near(_ch(NAT, 1, MapGroupState.CH_HIGHLIGHT), 0.5) and _near(_ch(NAT, 2, MapGroupState.CH_DIM), dim)
		and _ch(NAT, 1, MapGroupState.CH_DIM) == 0.0, "dim %f" % dim)
	rig.tick(0.5)
	TestFixtures.check(res, "hover done: R and G 1 on the hovered nation, others dim 1, tokens released",
		_ch(NAT, 1, MapGroupState.CH_HIGHLIGHT) == 1.0 and _ch(NAT, 1, MapGroupState.CH_LIFT) == 1.0
		and _ch(NAT, 2, MapGroupState.CH_DIM) == 1.0 and _ch(NAT, 3, MapGroupState.CH_DIM) == 1.0
		and not rig.gate.is_held(&"highlight") and not rig.gate.is_held(&"lift"), "")
	rig.hl.set_hover(NAT, 2)
	rig.tick(0.07)
	TestFixtures.check(res, "move 1 to 2: R and G cross at once",
		_near(_ch(NAT, 1, MapGroupState.CH_HIGHLIGHT), 0.5) and _near(_ch(NAT, 2, MapGroupState.CH_HIGHLIGHT), 0.5)
		and _near(_ch(NAT, 1, MapGroupState.CH_LIFT), 0.5) and _near(_ch(NAT, 2, MapGroupState.CH_LIFT), 0.5), "")
	rig.tick(0.5)
	TestFixtures.check(res, "move done: dim swaps, dim factor 1 - 0.25 * B", _ch(NAT, 2, MapGroupState.CH_DIM) == 0.0
		and _ch(NAT, 1, MapGroupState.CH_DIM) == 1.0
		and _near(1.0 - MapConst.DIM * _ch(NAT, 1, MapGroupState.CH_DIM), 0.75), "")
	rig.hl.set_hover(SETTLE, 5)
	rig.tick(0.5)
	TestFixtures.check(res, "settlement hover leaves nation dim and lift as they were", _ch(SETTLE, 5, MapGroupState.CH_HIGHLIGHT) == 1.0
		and _ch(NAT, 2, MapGroupState.CH_HIGHLIGHT) == 0.0 and _ch(NAT, 2, MapGroupState.CH_LIFT) == 1.0
		and _ch(NAT, 1, MapGroupState.CH_DIM) == 1.0 and _ch(NAT, 2, MapGroupState.CH_DIM) == 0.0, "")
	rig.free_all()


static func _case_water_and_clear(res: Dictionary) -> void:
	var rig: Rig = Rig.new()
	rig.hl.set_hover(NAT, 1)
	rig.tick(0.6)
	rig.hl.set_hover(NAT, 0)
	rig.tick(0.6)
	TestFixtures.check(res, "water hover: every nation dims, nothing lifted or highlighted", _ch(NAT, 1, MapGroupState.CH_DIM) == 1.0
		and _ch(NAT, 2, MapGroupState.CH_DIM) == 1.0 and _ch(NAT, 1, MapGroupState.CH_LIFT) == 0.0
		and _ch(NAT, 1, MapGroupState.CH_HIGHLIGHT) == 0.0, "")
	rig.hl.clear()
	rig.tick(0.6)
	TestFixtures.check(res, "clear: dim, lift and highlight all return to 0 and tokens release", _ch(NAT, 1, MapGroupState.CH_DIM) == 0.0
		and _ch(NAT, 2, MapGroupState.CH_DIM) == 0.0 and _ch(NAT, 1, MapGroupState.CH_LIFT) == 0.0
		and not rig.gate.is_held(&"highlight") and not rig.gate.is_held(&"lift") and rig.hl.hovered() == Vector2i.ZERO, "")
	rig.free_all()


static func _case_texture(res: Dictionary) -> void:
	var rig: Rig = Rig.new()
	rig.hl.set_hover(NAT, 3)
	rig.tick(0.6)
	var tex: ImageTexture = MapGroupState.texture()
	var was_dirty: bool = MapGroupState._dirty
	MapGroupState.flush()
	TestFixtures.check(res, "group state texture is 256x8", tex.get_width() == MapGroupState.COLS
		and tex.get_height() == MapGroupState.ROWS, "%d x %d" % [tex.get_width(), tex.get_height()])
	TestFixtures.check(res, "eases mark the image dirty and flush uploads it", was_dirty and not MapGroupState._dirty, "")
	var data: PackedByteArray = MapGroupState._image.get_data()
	var hov: int = (NAT * MapGroupState.COLS + 3) * 4
	var other: int = (NAT * MapGroupState.COLS + 1) * 4
	TestFixtures.check(res, "image bytes (row kind, column id): hovered R,G 255, B 0; other B 255, R 0",
		data[hov + MapGroupState.CH_HIGHLIGHT] == 255 and data[hov + MapGroupState.CH_LIFT] == 255
		and data[hov + MapGroupState.CH_DIM] == 0 and data[other + MapGroupState.CH_DIM] == 255
		and data[other + MapGroupState.CH_HIGHLIGHT] == 0, "%s %s" % [data.slice(hov, hov + 4), data.slice(other, other + 4)])
	var img: Image = tex.get_image()
	if img != null and not img.is_empty() and DisplayServer.get_name() != "headless":
		TestFixtures.check(res, "uploaded texels match the image", img.get_data() == data, "")
	rig.free_all()
