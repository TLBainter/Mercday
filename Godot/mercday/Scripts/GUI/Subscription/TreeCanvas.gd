class_name TreeCanvas extends Control

#The world the Customize tree stands on: one draw pass for every connector, and one child per
#module, category box and requirement gate. The world is a fixed 5200 by 2900, so the tree never
#reflows; SkillTree slides this node around behind the frame. Content coordinates come out of
#TreeLayout and this node adds the world offset once.

signal block_pressed(id: String)
#kind is "block", "cat" or "gate"; an empty kind means the pointer left.
signal hover_changed(kind: String, key: String, at: Rect2)

const BLOCK_SCENE: PackedScene = preload("res://Scenes/GUI/Subscription/CustomizeBlock.tscn")
const CAT_SCENE: PackedScene = preload("res://Scenes/GUI/Subscription/CategoryBox.tscn")
const GATE_SCENE: PackedScene = preload("res://Scenes/GUI/Subscription/RequirementGate.tscn")
const HALF: float = TreeLayout.LINE_WIDTH / 2.0

var _lines: Array[Dictionary] = []
var _blocks: Dictionary = {}
var _boxes: Dictionary = {}
var _gates: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = TreeLayout.WORLD
	size = TreeLayout.WORLD
	_build()
	SubscriptionManager.changed.connect(refresh)
	refresh()


func connectors() -> Array[Dictionary]:
	return _lines


func block(id: String) -> CustomizeBlock:
	return _blocks.get(id, null) as CustomizeBlock


func cat_box(cat: String) -> CategoryBox:
	return _boxes.get(cat, null) as CategoryBox


func gate(id: String) -> RequirementGate:
	return _gates.get(id, null) as RequirementGate


func block_ids() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in _blocks:
		out.append(String(key))
	return out


func gate_ids() -> Array[String]:
	var out: Array[String] = []
	for key: Variant in _gates:
		out.append(String(key))
	return out


#Where one module sits in this node's own space.
func block_position(id: String) -> Vector2:
	return TreeLayout.block_rect(id).position + Vector2(0.0, TreeLayout.OY)


#Rebuilds every connector and hands the new state to every child.
func refresh() -> void:
	var tiers: Dictionary = SubscriptionManager.tiers()
	var enterprise: bool = SubscriptionManager.plan() == SubscriptionManager.Plan.ENTERPRISE
	var built: Dictionary = TreeLayout.build(tiers, enterprise)
	_lines = built["lines"]
	for row: Dictionary in built["gates"]:
		var node: RequirementGate = gate(String(row["id"]))
		if node != null:
			node.setup(String(row["id"]), int(row["have"]), int(row["need"]))
	for id: String in block_ids():
		block(id).refresh(tiers, enterprise)
	for cat: String in TreeLayout.cat_ids():
		cat_box(cat).refresh(tiers, enterprise)
	queue_redraw()


func _build() -> void:
	for cat: String in TreeLayout.cat_ids():
		var box: CategoryBox = CAT_SCENE.instantiate() as CategoryBox
		box.name = "Cat_" + cat
		add_child(box)
		box.setup(cat)
		box.position = TreeLayout.cat_rect(cat).position + Vector2(0.0, TreeLayout.OY)
		box.mouse_entered.connect(_on_enter.bind("cat", cat, box))
		box.mouse_exited.connect(_on_exit)
		_boxes[cat] = box
	for row: Dictionary in TreeLayout.gates_for({}):
		var id: String = String(row["id"])
		var node: RequirementGate = GATE_SCENE.instantiate() as RequirementGate
		node.name = "Gate_" + id
		add_child(node)
		node.setup(id, 0, int(row["need"]))
		var lane: Rect2 = row["rect"]
		node.position = lane.position + Vector2(0.0, TreeLayout.OY)
		node.mouse_entered.connect(_on_enter.bind("gate", id, node))
		node.mouse_exited.connect(_on_exit)
		_gates[id] = node
	for id: String in TreeLayout.block_ids():
		var mod: CustomizeBlock = BLOCK_SCENE.instantiate() as CustomizeBlock
		mod.name = "Block_" + id
		add_child(mod)
		mod.setup(id)
		mod.position = block_position(id)
		mod.pressed_block.connect(block_pressed.emit)
		mod.mouse_entered.connect(_on_enter.bind("block", id, mod))
		mod.mouse_exited.connect(_on_exit)
		_blocks[id] = mod


func _on_enter(kind: String, key: String, node: Control) -> void:
	hover_changed.emit(kind, key, Rect2(node.position, node.size))


func _on_exit() -> void:
	hover_changed.emit("", "", Rect2())


func _draw() -> void:
	var lift: Vector2 = Vector2(0.0, TreeLayout.OY)
	for row: Dictionary in _lines:
		var points: PackedVector2Array = row["points"]
		if points.size() < 2:
			continue
		var a: Vector2 = points[0] + lift
		var b: Vector2 = points[points.size() - 1] + lift
		var first: Color = row["color_a"]
		var last: Color = row["color_b"]
		var ca: Color = GuiColors.fade(first, float(row["alpha"]))
		var cb: Color = GuiColors.fade(last, float(row["alpha"]))
		if ca == cb:
			draw_rect(bar_rect(a, b), ca)
			continue
		draw_polygon(quad_points(a, b), _blend(ca, cb))


#A 4 px band along one axis aligned segment.
static func bar_rect(a: Vector2, b: Vector2) -> Rect2:
	if absf(a.y - b.y) < absf(a.x - b.x):
		return Rect2(minf(a.x, b.x), a.y - HALF, absf(b.x - a.x), TreeLayout.LINE_WIDTH)
	return Rect2(a.x - HALF, minf(a.y, b.y) - HALF, TreeLayout.LINE_WIDTH,
		absf(b.y - a.y) + TreeLayout.LINE_WIDTH)


#The same band as a quad, so a two colour segment can be drawn as a gradient polygon.
static func quad_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	if absf(a.y - b.y) < absf(a.x - b.x):
		return PackedVector2Array([Vector2(a.x, a.y - HALF), Vector2(a.x, a.y + HALF),
			Vector2(b.x, b.y + HALF), Vector2(b.x, b.y - HALF)])
	var lift: float = -HALF if a.y <= b.y else HALF
	return PackedVector2Array([Vector2(a.x - HALF, a.y + lift), Vector2(a.x + HALF, a.y + lift),
		Vector2(b.x + HALF, b.y - lift), Vector2(b.x - HALF, b.y - lift)])


func _blend(ca: Color, cb: Color) -> PackedColorArray:
	return PackedColorArray([ca, ca, cb, cb])
