class_name MapLift extends Node
#Eases group lift (G) so the old group falls while the new one rises; any number of groups ease at once.
#Islets stay flat in the terrain shader (CUSTOM0 bit 7), so the lift value is per group only.

const TOKEN: StringName = &"lift"

@export var gate_path: NodePath = NodePath("../Gate")

#Settable for fixtures; _ready fills it from the scene.
var gate: MapRenderGate = null
var _ease: MapEase = MapEase.new()
var _current: Vector2i = Vector2i.ZERO
var _holding: bool = false


#Runs before MapView so its MapGroupState.flush picks up this frame's values.
func _init() -> void:
	process_priority = -1


func _ready() -> void:
	if gate == null:
		gate = get_node_or_null(gate_path) as MapRenderGate
	set_process(_holding)


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	_set_holding(false)


#id 0 lowers the current group and lifts nothing.
func set_lift(kind: int, id: int) -> void:
	var next: Vector2i = Vector2i(kind, id) if id != 0 else Vector2i.ZERO
	if next == _current:
		return
	if _current.y != 0:
		_ease.target(_key(_current.x, _current.y), 0.0, MapConst.LIFT_MS, MapEase.EaseCurve.SMOOTH)
	_current = next
	if id != 0:
		_ease.target(_key(kind, id), 1.0, MapConst.LIFT_MS, MapEase.EaseCurve.SMOOTH)
	_set_holding(_ease.is_active())


func lifted() -> Vector2i:
	return _current


func lift_px(kind: int, id: int) -> float:
	return _ease.value(_key(kind, id)) * MapConst.LIFT


func is_easing() -> bool:
	return _ease.is_active()


func step(delta: float) -> void:
	for key: int in _ease.advance(delta):
		var kind: int = int(key / float(MapGroupState.COLS))
		var id: int = key % MapGroupState.COLS
		MapGroupState.set_channel(kind, id, MapGroupState.CH_LIFT, _ease.value(key))
	_set_holding(_ease.is_active())


static func _key(kind: int, id: int) -> int:
	return kind * MapGroupState.COLS + id


#Processing runs only while an ease is live.
func _set_holding(v: bool) -> void:
	set_process(v)
	if v == _holding:
		return
	_holding = v
	if gate == null:
		return
	if v:
		gate.acquire(TOKEN)
	else:
		gate.release(TOKEN)
