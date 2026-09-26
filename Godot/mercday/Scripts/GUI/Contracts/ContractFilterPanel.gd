class_name ContractFilterPanel extends PopupPanel

#The contract list filter popup: the closed toggle, the difficulty, reward and distance ranges and
#a Reset that puts every cap back to the extremes of the contracts currently on the board.

signal filters_changed(filter: Dictionary)

@onready var closed_box: CheckBox = $Rows/ShowClosed
@onready var difficulty_min: RangeSlider = $Rows/DifficultyMin
@onready var difficulty_max: RangeSlider = $Rows/DifficultyMax
@onready var reward_min: RangeSlider = $Rows/RewardMin
@onready var reward_max: RangeSlider = $Rows/RewardMax
@onready var max_distance: RangeSlider = $Rows/MaxDistance
@onready var reset_button: Button = $Rows/Reset

var caps: Dictionary = ContractList.default_filter()
var _quiet: bool = false


func _ready() -> void:
	closed_box.toggled.connect(_on_closed_toggled)
	for slider: RangeSlider in [difficulty_min, difficulty_max, reward_min, reward_max,
			max_distance]:
		slider.slider_changed.connect(_on_slider_changed)
	reset_button.pressed.connect(reset)
	_apply(caps)


#Reads the extremes off the contracts on the board and keeps the picks inside the new caps.
func configure(views: Array[ContractView]) -> void:
	caps = ContractList.default_filter(views)
	var current: Dictionary = filter() if is_node_ready() else caps.duplicate()
	current["show_closed"] = bool(current.get("show_closed", false))
	_apply(_clamped(current))


func filter() -> Dictionary:
	if not is_node_ready():
		return caps.duplicate()
	return {
		"show_closed": closed_box.button_pressed,
		"difficulty_min": difficulty_min.value(),
		"difficulty_max": difficulty_max.value(),
		"reward_min": int(reward_min.value()),
		"reward_max": int(reward_max.value()),
		"max_distance": int(max_distance.value()),
	}


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


func _apply(values: Dictionary) -> void:
	if not is_node_ready():
		return
	_quiet = true
	closed_box.set_pressed_no_signal(bool(values.get("show_closed", false)))
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


func _on_closed_toggled(_pressed: bool) -> void:
	_emit()


func _on_slider_changed(_value: float) -> void:
	_emit()


func _emit() -> void:
	if _quiet or not is_node_ready():
		return
	filters_changed.emit(filter())
