class_name StarRangePicker extends Control

#The Min and Max difficulty rows of a stars2 filter: five stars each, half star hit zones, the
#colour of the row taken from the difficulty ramp at its own value. Min never passes Max, so
#moving one pushes the other. Either row can be locked on its own and shows a lock instead.

signal range_changed(low: float, high: float)
signal take_me_there(target: Dictionary)

const ROW_MIN: int = 0
const ROW_MAX: int = 1
const ROW_LABELS: Array[String] = ["Min", "Max"]
const MIN_VALUE: float = 0.5
const MAX_VALUE: float = 5.0
const STEP: float = 0.5
const STAR_COUNT: int = 5
#The filter column is 290 px wide and its pad leaves 262, so its stars draw at the 16 px scale;
#a host with room for 468 px hands the picker star_scale 2.
const DEFAULT_STAR_SCALE: int = 1
const LABEL_W: float = 28.0
const LABEL_GAP: float = 10.0
const BLOCK_GAP: float = 24.0
const LOCK_W: float = 150.0
const LOCK_H: float = 30.0
const LABEL_SIZE: int = 9
const LABEL_COLOR: Color = Color("#9cc6ef")
const EMPTY_COLOR: Color = Color("#1f3560")
const LOCK_FONT_SIZE: int = 9
const FONT_LABEL: Font = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")

@export var low: float = MIN_VALUE
@export var high: float = MAX_VALUE
#One entry per row, Min first: empty leaves the row open, otherwise {feature, upgrade,
#upgrade_id, tier, tiers, verb} drives the lock that replaces its stars.
@export var row_locks: Array[Dictionary] = []
#The integer atlas scale of every star: 1 draws 16 px stars, 2 draws 32 px.
@export var star_scale: int = DEFAULT_STAR_SCALE:
	set(value):
		star_scale = maxi(1, value)
		if is_node_ready():
			custom_minimum_size = Vector2(_stars_x(ROW_MAX) + _stars_width(),
				maxf(_star_px(), LOCK_H))
			refresh()

@onready var min_lock: FeatureLock = $MinLock
@onready var max_lock: FeatureLock = $MaxLock


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(_stars_x(ROW_MAX) + _stars_width(), maxf(_star_px(), LOCK_H))
	for lock: FeatureLock in [min_lock, max_lock]:
		lock.take_me_there.connect(_on_take_me_there)
	refresh()


#Sets both ends without emitting, the path a section's set_value() takes.
func set_range(new_low: float, new_high: float) -> void:
	low = _snap(new_low)
	high = _snap(maxf(new_high, low))
	_pin_locked()
	_redraw_safe()


func set_row_locks(rows: Array[Dictionary]) -> void:
	row_locks = rows
	refresh()


func is_row_locked(row: int) -> bool:
	return not lock_props(row).is_empty()


func lock_props(row: int) -> Dictionary:
	if row < 0 or row >= row_locks.size():
		return {}
	return row_locks[row]


func lock_for(row: int) -> FeatureLock:
	if not is_node_ready():
		return null
	return min_lock if row == ROW_MIN else max_lock


func row_value(row: int) -> float:
	return low if row == ROW_MIN else high


func row_color(row: int) -> Color:
	return Icons.star_color(row_value(row), false)


#The press path a click or a headless test takes: a locked row never moves, and the other end
#gives way so the pair stays ordered.
func press_star(row: int, value: float) -> void:
	if is_row_locked(row):
		return
	var picked: float = _snap(value)
	if row == ROW_MIN:
		low = picked
		high = maxf(picked, high)
	else:
		high = picked
		low = minf(low, picked)
	_pin_locked()
	_redraw_safe()
	range_changed.emit(low, high)


func refresh() -> void:
	if not is_node_ready():
		return
	for row: int in range(ROW_LABELS.size()):
		var lock: FeatureLock = lock_for(row)
		var props: Dictionary = lock_props(row)
		lock.visible = not props.is_empty()
		if props.is_empty():
			continue
		lock.feature = String(props.get("feature", ""))
		lock.upgrade = String(props.get("upgrade", ""))
		lock.upgrade_id = String(props.get("upgrade_id", ""))
		lock.tier = int(props.get("tier", 1))
		lock.tiers = int(props.get("tiers", 1))
		lock.entitlement = String(props.get("entitlement", ""))
		lock.entitlement_tier = int(props.get("entitlement_tier", 0))
		lock.verb = String(props.get("verb", "target"))
		lock.label = "Locked"
		lock.height = LOCK_H
		lock.font_size = LOCK_FONT_SIZE
		lock.always_visible = true
		lock.position = Vector2(_stars_x(row), 0.0)
		lock.size = Vector2(LOCK_W, LOCK_H)
	queue_redraw()


func _draw() -> void:
	var baseline: float = (size.y + FONT_LABEL.get_ascent(LABEL_SIZE)
		- FONT_LABEL.get_descent(LABEL_SIZE)) / 2.0
	for row: int in range(ROW_LABELS.size()):
		draw_string(FONT_LABEL, Vector2(_block_x(row), baseline), ROW_LABELS[row],
			HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR)
		if is_row_locked(row):
			continue
		_draw_row(row)


func _draw_row(row: int) -> void:
	var top: float = (size.y - _star_px()) / 2.0
	Icons.draw_stars(self, Vector2(_stars_x(row), top), star_scale, row_value(row), false,
		EMPTY_COLOR, Icons.STAR_GAP)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var hit: Vector2 = _hit(click.position)
	if hit.x < 0.0:
		return
	press_star(int(hit.x), hit.y)
	accept_event()


#Which row and value the pointer sits on: the left half of a star reads n - 0.5.
func _hit(pos: Vector2) -> Vector2:
	for row: int in range(ROW_LABELS.size()):
		if is_row_locked(row):
			continue
		for n: int in range(1, STAR_COUNT + 1):
			var left: float = _stars_x(row) + float(n - 1) * (_star_px() + _star_gap())
			if pos.x < left or pos.x >= left + _star_px():
				continue
			var half: bool = pos.x < left + float(Icons.CELL / 2 * star_scale)
			return Vector2(float(row), float(n) - (STEP if half else 0.0))
	return Vector2(-1.0, 0.0)


func _block_x(row: int) -> float:
	return float(row) * (LABEL_W + LABEL_GAP + _stars_width() + BLOCK_GAP)


func _stars_x(row: int) -> float:
	return _block_x(row) + LABEL_W + LABEL_GAP


func _stars_width() -> float:
	return float(Icons.stars_width(star_scale))


func _star_px() -> float:
	return float(Icons.CELL * star_scale)


func _star_gap() -> float:
	return float(Icons.STAR_GAP * star_scale)


#A locked row keeps the end it is pinned to, so neither a stored pair nor the push rule of the
#other row moves it: Min sits at MIN_VALUE and Max at MAX_VALUE while the lock stands.
func _pin_locked() -> void:
	if is_row_locked(ROW_MIN):
		low = MIN_VALUE
	if is_row_locked(ROW_MAX):
		high = MAX_VALUE


func _snap(value: float) -> float:
	return clampf(snappedf(value, STEP), MIN_VALUE, MAX_VALUE)


func _redraw_safe() -> void:
	if is_node_ready():
		queue_redraw()


func _on_take_me_there(target: Dictionary) -> void:
	take_me_there.emit(target)
