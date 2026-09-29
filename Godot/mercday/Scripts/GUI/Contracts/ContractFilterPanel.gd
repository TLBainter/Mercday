class_name ContractFilterPanel extends PopupPanel

#The contract list filter popup: one check row per status, the difficulty, reward and distance
#ranges and a Reset that puts every pick back to the board defaults. The rows read top to bottom
#Available, Active, Completed, Failed, Unclaimed Results, Rejected, Expired (README I5), with the
#unclaimed row indented under the two outcomes it stands in for.

signal filters_changed(filter: Dictionary)

#One row per option: where it sits under Statuses and the filter key it writes. The key doubles as
#the name of the export that mirrors it.
const OPTIONS: Array[Dictionary] = [
	{"node": "Available", "key": "show_available"},
	{"node": "Active", "key": "show_active"},
	{"node": "Completed", "key": "show_completed"},
	{"node": "Failed", "key": "show_failed"},
	{"node": "UnclaimedWrap/Unclaimed", "key": "show_unclaimed"},
	{"node": "Rejected", "key": "show_rejected"},
	{"node": "Expired", "key": "show_expired"},
]
const INDENT_PX: int = 24
const RANGE_KEYS: Array[String] = ["difficulty_min", "difficulty_max", "reward_min",
	"reward_max", "max_distance"]

@export var show_available: bool = true:
	set(value):
		show_available = value
		_push("show_available")
@export var show_active: bool = true:
	set(value):
		show_active = value
		_push("show_active")
@export var show_completed: bool = false:
	set(value):
		show_completed = value
		_push("show_completed")
@export var show_failed: bool = false:
	set(value):
		show_failed = value
		_push("show_failed")
@export var show_unclaimed: bool = true:
	set(value):
		show_unclaimed = value
		_push("show_unclaimed")
@export var show_rejected: bool = false:
	set(value):
		show_rejected = value
		_push("show_rejected")
@export var show_expired: bool = false:
	set(value):
		show_expired = value
		_push("show_expired")

@onready var statuses: VBoxContainer = $Rows/Statuses
@onready var indent_wrap: MarginContainer = $Rows/Statuses/UnclaimedWrap
@onready var difficulty_min: RangeSlider = $Rows/DifficultyMin
@onready var difficulty_max: RangeSlider = $Rows/DifficultyMax
@onready var reward_min: RangeSlider = $Rows/RewardMin
@onready var reward_max: RangeSlider = $Rows/RewardMax
@onready var max_distance: RangeSlider = $Rows/MaxDistance
@onready var reset_button: Button = $Rows/Reset

var caps: Dictionary = ContractList.default_filter()
var _quiet: bool = false


func _ready() -> void:
	indent_wrap.add_theme_constant_override("margin_left", INDENT_PX)
	for option: Dictionary in OPTIONS:
		var key: String = str(option["key"])
		var row: FilterCheckRow = row_of(key)
		if row == null:
			continue
		row.on = bool(get(key))
		row.toggled.connect(_on_row_toggled.bind(key))
	for slider: RangeSlider in [difficulty_min, difficulty_max, reward_min, reward_max,
			max_distance]:
		slider.slider_changed.connect(_on_slider_changed)
	reset_button.pressed.connect(reset)
	_apply(caps)


#Reads the extremes off the contracts on the board and keeps the picks inside the new caps.
func configure(views: Array[ContractView]) -> void:
	caps = ContractList.default_filter(views)
	var current: Dictionary = filter() if is_node_ready() else caps.duplicate()
	_apply(_clamped(current))


func filter() -> Dictionary:
	var out: Dictionary = flags()
	if not is_node_ready():
		for key: String in RANGE_KEYS:
			out[key] = caps[key]
		return out
	out["difficulty_min"] = difficulty_min.value()
	out["difficulty_max"] = difficulty_max.value()
	out["reward_min"] = int(reward_min.value())
	out["reward_max"] = int(reward_max.value())
	out["max_distance"] = int(max_distance.value())
	return out


#Only the status options, in the order the popup lists them.
func flags() -> Dictionary:
	var out: Dictionary = {}
	for option: Dictionary in OPTIONS:
		var key: String = str(option["key"])
		out[key] = bool(get(key))
	return out


func set_filter(new_filter: Dictionary) -> void:
	_apply(_clamped(new_filter))
	_emit()


func reset() -> void:
	_apply(caps)
	_emit()


func popup_at(anchor: Control) -> void:
	var rect: Rect2 = anchor.get_global_rect()
	var wanted: Vector2 = get_contents_minimum_size()
	popup(Rect2i(Vector2i(int(rect.position.x), int(rect.end.y)),
		Vector2i(int(maxf(wanted.x, 260.0)), int(maxf(wanted.y, 200.0)))))


func row_of(key: String) -> FilterCheckRow:
	if not is_node_ready():
		return null
	for option: Dictionary in OPTIONS:
		if str(option["key"]) == key:
			return statuses.get_node_or_null(NodePath(str(option["node"]))) as FilterCheckRow
	return null


#The labels in popup order, which the list order test reads.
func row_labels() -> Array[String]:
	var out: Array[String] = []
	for option: Dictionary in OPTIONS:
		var row: FilterCheckRow = row_of(str(option["key"]))
		out.append(row.label if row != null else "")
	return out


func indent_of(key: String) -> int:
	var row: FilterCheckRow = row_of(key)
	if row == null:
		return 0
	var box: MarginContainer = row.get_parent() as MarginContainer
	return 0 if box == null else box.get_theme_constant("margin_left")


func _apply(values: Dictionary) -> void:
	if not is_node_ready():
		return
	_quiet = true
	for option: Dictionary in OPTIONS:
		var key: String = str(option["key"])
		if values.has(key):
			set(key, bool(values[key]))
	difficulty_min.configure(0.0, 5.0, 0.5, float(values.get("difficulty_min", 0.0)))
	difficulty_max.configure(0.0, 5.0, 0.5, float(values.get("difficulty_max", 5.0)))
	reward_min.configure(0.0, float(caps["reward_max"]), 1.0, float(values.get("reward_min", 0)))
	reward_max.configure(0.0, float(caps["reward_max"]), 1.0,
		float(values.get("reward_max", caps["reward_max"])))
	max_distance.configure(0.0, float(caps["max_distance"]), 1.0,
		float(values.get("max_distance", caps["max_distance"])))
	_quiet = false


#Every pick pulled inside the caps the board allows, so a stale filter never hides everything.
func _clamped(values: Dictionary) -> Dictionary:
	var out: Dictionary = values.duplicate()
	out["difficulty_min"] = clampf(float(values.get("difficulty_min", 0.0)), 0.0, 5.0)
	out["difficulty_max"] = clampf(float(values.get("difficulty_max", 5.0)), 0.0, 5.0)
	out["reward_min"] = clampi(int(values.get("reward_min", 0)), 0, int(caps["reward_max"]))
	out["reward_max"] = clampi(int(values.get("reward_max", caps["reward_max"])), 0,
		int(caps["reward_max"]))
	out["max_distance"] = clampi(int(values.get("max_distance", caps["max_distance"])), 0,
		int(caps["max_distance"]))
	return out


func _push(key: String) -> void:
	var row: FilterCheckRow = row_of(key)
	if row != null:
		row.on = bool(get(key))


func _on_row_toggled(on: bool, key: String) -> void:
	if bool(get(key)) == on:
		return
	set(key, on)
	_emit()


func _on_slider_changed(_value: float) -> void:
	_emit()


func _emit() -> void:
	if _quiet or not is_node_ready():
		return
	filters_changed.emit(filter())
