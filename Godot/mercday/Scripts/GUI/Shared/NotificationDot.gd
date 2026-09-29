class_name NotificationDot extends Control

#A small unread marker: a pixel dot with a dark outline and four fading pulse rings, no counts
#and no colour variants beyond tint. attach() anchors an instance to a host control's corner.

const DOT_SIZE: Vector2 = Vector2(10, 10)
const DOT_COLOR: Color = Color("#e8583f")
const OUTLINE_COLOR: Color = Color("#0a0f1c")
const OUTLINE_WIDTH: float = 2.0
const SCENE_PATH: String = "res://Scenes/GUI/Shared/NotificationDot.tscn"
const FRAME_SIZE: Vector2 = Vector2(28, 28)
const CELL: int = 2
#The dot draws over the rest of its host, so a later sibling never covers it.
const DOT_Z: int = 1
const DOT_MAP: PackedStringArray = ["..####..", ".######.", "########", "########", "########",
	"########", ".######.", "..####.."]
const RING_CELLS: PackedInt32Array = [8, 10, 12, 14]
const RING_PEAKS: PackedFloat32Array = [0.9, 0.75, 0.55, 0.35]
const RING_RISE: float = 0.08
const RING_FALL: float = 0.55

static var _dot_cells: PackedVector2Array = PackedVector2Array()
static var _ring_cells: Array[PackedVector2Array] = []
static var _cache_built: bool = false

@export var on: bool = true:
	set(value):
		on = value
		visible = on

@export var color: Color = DOT_COLOR
@export var pulse: bool = true
@export var blink: bool = true

var _pin_offset: Vector2 = Vector2(2, 2)
var _pin_corner: Corner = CORNER_TOP_RIGHT


#The control carries the whole ring box, so the rings and the outline never paint outside it and
#a host that clips its content cannot cut them off.
func _ready() -> void:
	custom_minimum_size = FRAME_SIZE
	size = FRAME_SIZE
	z_index = DOT_Z
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = on


func _enter_tree() -> void:
	PulseClock.pulse.connect(_on_pulse)


func _exit_tree() -> void:
	if PulseClock.pulse.is_connected(_on_pulse):
		PulseClock.pulse.disconnect(_on_pulse)


func _on_pulse(_g: float, _sweep: PackedFloat32Array) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	NotificationDot.paint(self, FRAME_SIZE / 2.0, color, PulseClock.phase(), pulse, blink)


#The 16 x 16 rect of the lit dot cells in local coordinates, centred on the frame box centre.
func dot_rect() -> Rect2:
	var centre: Vector2 = FRAME_SIZE / 2.0
	return Rect2(centre - Vector2(8.0, 8.0), Vector2(16.0, 16.0))


#The 28 x 28 frame around the same centre as dot_rect().
func frame_rect() -> Rect2:
	var centre: Vector2 = FRAME_SIZE / 2.0
	return Rect2(centre - Vector2(14.0, 14.0), FRAME_SIZE)


#Fraction of a ring's own cycle lit at a clock phase: rises to 1 by RING_RISE, back to 0 by
#RING_FALL, then dark; ring i trails ring 0 by index / 6 of the cycle. Prototype lines 13, 29-31.
static func ring_alpha(index: int, phase: float) -> float:
	var x: float = fposmod(phase - float(index) / 6.0, 1.0)
	var value: float = 0.0
	if x < RING_RISE:
		value = x / RING_RISE
	elif x < RING_FALL:
		value = 1.0 - (x - RING_RISE) / (RING_FALL - RING_RISE)
	return value * RING_PEAKS[index]


#Dot brightness gain: 0.95 at phase 0, 1.4 at phase 0.5, 0.95 at phase 1, smoothstep eased.
static func blink_gain(phase: float) -> float:
	var p: float = fposmod(phase, 1.0)
	var tri: float = 1.0 - absf(p * 2.0 - 1.0)
	return lerpf(0.95, 1.4, smoothstep(0.0, 1.0, tri))


#The one drawing routine: the dark outline, the tinted dot, then the pulse rings. Every cell is
#a whole-pixel CELL x CELL rect from a static cache built once, never rebuilt per frame.
static func paint(canvas: CanvasItem, centre: Vector2, tint: Color, phase: float, rings: bool,
		blinks: bool) -> void:
	_ensure_cache()
	var cell_size: Vector2 = Vector2(float(CELL), float(CELL))
	var edges: Array[Vector2] = [Vector2(-OUTLINE_WIDTH, 0.0), Vector2(OUTLINE_WIDTH, 0.0),
		Vector2(0.0, -OUTLINE_WIDTH), Vector2(0.0, OUTLINE_WIDTH)]
	for cell: Vector2 in _dot_cells:
		for edge: Vector2 in edges:
			canvas.draw_rect(Rect2(centre + cell + edge, cell_size), OUTLINE_COLOR)
	var gain: float = blink_gain(phase) if blinks else 1.0
	var lit: Color = Color(minf(tint.r * gain, 1.0), minf(tint.g * gain, 1.0),
		minf(tint.b * gain, 1.0), tint.a)
	for cell: Vector2 in _dot_cells:
		canvas.draw_rect(Rect2(centre + cell, cell_size), lit)
	if not rings:
		return
	for i: int in RING_CELLS.size():
		var alpha: float = ring_alpha(i, phase)
		if alpha <= 0.0:
			continue
		var ring_color: Color = Color(tint.r, tint.g, tint.b, alpha)
		for cell: Vector2 in _ring_cells[i]:
			canvas.draw_rect(Rect2(centre + cell, cell_size), ring_color)


static func _ensure_cache() -> void:
	if _cache_built:
		return
	_cache_built = true
	_dot_cells = _build_dot_cells()
	for n: int in RING_CELLS:
		_ring_cells.append(_build_ring_cells(n))


static func _build_dot_cells() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for row: int in DOT_MAP.size():
		var line: String = DOT_MAP[row]
		for col: int in line.length():
			if line[col] == "#":
				out.append(Vector2(float(col * CELL - 8), float(row * CELL - 8)))
	return out


static func _build_ring_cells(n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var c: float = float(n - 1) / 2.0
	var half: float = float(n * CELL) / 2.0
	for row: int in n:
		for col: int in n:
			if absf(Vector2(col, row).distance_to(Vector2(c, c)) - c) < 0.6:
				out.append(Vector2(float(col * CELL) - half, float(row * CELL) - half))
	return out


#Anchors this dot to a corner of its current parent, offset pixels in from that corner. A parent
#that is a Container (PanelContainer and the like) fits every visible direct child into its own
#content rect on NOTIFICATION_SORT_CHILDREN, which overwrites anchors and offsets set here the
#moment this dot turns visible; a Container-derived host must call repin() from its own
#NOTIFICATION_SORT_CHILDREN handler (after the base class runs) to hold this corner.
func pin(offset: Vector2, corner: Corner = CORNER_TOP_RIGHT) -> void:
	_pin_offset = offset
	_pin_corner = corner
	if corner == CORNER_TOP_LEFT:
		anchor_left = 0.0
		anchor_right = 0.0
		offset_left = offset.x
		offset_right = offset.x + FRAME_SIZE.x
	else:
		anchor_left = 1.0
		anchor_right = 1.0
		offset_right = -offset.x
		offset_left = -offset.x - FRAME_SIZE.x
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_top = offset.y
	offset_bottom = offset.y + FRAME_SIZE.y
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


#Re-applies the last pin() geometry, undoing a Container's own child-fit pass.
func repin() -> void:
	pin(_pin_offset, _pin_corner)


#Adds a dot anchored to a corner of host, offset pixels in from that corner. The host's own
#resize repins it, so a host that lays its children out again cannot drag the dot off its corner.
static func attach(host: Control, offset: Vector2 = Vector2(2, 2),
		corner: Corner = CORNER_TOP_RIGHT) -> NotificationDot:
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	var dot: NotificationDot = scene.instantiate() as NotificationDot
	host.add_child(dot)
	dot.pin(offset, corner)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not host.resized.is_connected(dot.repin):
		host.resized.connect(dot.repin)
	return dot
