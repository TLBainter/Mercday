class_name MapHighlight extends Node
#Eases hover highlight (R) and nation dim (B); the old group fades while the new one rises. Nation hovers drive MapLift.
#Hover id 0 is open water (every nation dims); clear() is off the map or locked (nothing dims).

signal hover_changed(kind: int, id: int)

const TOKEN: StringName = &"highlight"

@export var gate_path: NodePath = NodePath("../Gate")
@export var lift_path: NodePath = NodePath("../Lift")

#Settable for fixtures; resolved from the scene on first use.
var gate: MapRenderGate = null
var lift: MapLift = null
var _hl: MapEase = MapEase.new()
var _dim: MapEase = MapEase.new()
var _hover: Vector2i = Vector2i.ZERO
var _on_map: bool = false
var _holding: bool = false


#Runs before MapView so its MapGroupState.flush picks up this frame's values.
func _init() -> void:
	process_priority = -1


func _ready() -> void:
	set_process(_holding)


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	_set_holding(false)


func set_hover(kind: int, id: int) -> void:
	_apply(Vector2i(kind, id), true)


func clear() -> void:
	_apply(Vector2i.ZERO, false)


func hovered() -> Vector2i:
	return _hover


func is_easing() -> bool:
	return _hl.is_active() or _dim.is_active()


func step(delta: float) -> void:
	for key: int in _hl.advance(delta):
		var kind: int = int(key / float(MapGroupState.COLS))
		MapGroupState.set_channel(kind, key % MapGroupState.COLS, MapGroupState.CH_HIGHLIGHT, _hl.value(key))
	for id: int in _dim.advance(delta):
		MapGroupState.set_channel(MapGroupState.Kind.NATION, id, MapGroupState.CH_DIM, _dim.value(id))
	_set_holding(is_easing())


#Settlement and other group hovers leave the nation dim and lift as they were.
func _apply(next: Vector2i, on_map: bool) -> void:
	if next.y == 0:
		next = Vector2i.ZERO
	if next == _hover and on_map == _on_map:
		return
	var moved: bool = next != _hover
	if _hover.y != 0:
		_hl.target(_key(_hover), 0.0, MapConst.LIFT_MS, MapEase.EaseCurve.SMOOTH)
	if next.y != 0:
		_hl.target(_key(next), 1.0, MapConst.LIFT_MS, MapEase.EaseCurve.SMOOTH)
	if next.y == 0 or next.x == MapGroupState.Kind.NATION:
		for n: int in range(1, MapNations.COUNT + 1):
			var to: float = 1.0 if on_map and n != next.y else 0.0
			_dim.target(n, to, MapConst.DIM_MS, MapEase.EaseCurve.SMOOTHER)
		if _lift() != null:
			lift.set_lift(MapGroupState.Kind.NATION, next.y)
	_hover = next
	_on_map = on_map
	_set_holding(is_easing())
	if moved:
		hover_changed.emit(next.x, next.y)


static func _key(g: Vector2i) -> int:
	return g.x * MapGroupState.COLS + g.y


func _lift() -> MapLift:
	if lift == null and is_inside_tree():
		lift = get_node_or_null(lift_path) as MapLift
	return lift


func _gate() -> MapRenderGate:
	if gate == null and is_inside_tree():
		gate = get_node_or_null(gate_path) as MapRenderGate
	return gate


#Processing runs only while an ease is live.
func _set_holding(v: bool) -> void:
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
