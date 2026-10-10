@tool
class_name ToolQuantityStepper extends QuantityStepper

#QuantityStepper for editor tools, made by make() from ToolQuantityStepper.tscn; _init primes the glyph Icons.
#The editor has no UiSfx or GameSfx autoload, so there _ready, _move and _reject skip the click and reject cues.

const SCENE_PATH: String = "res://Scenes/Tools/Shared/ToolQuantityStepper.tscn"


static func make(low: int, high: int, start: int) -> ToolQuantityStepper:
	var made: ToolQuantityStepper = (load(SCENE_PATH) as PackedScene).instantiate() as ToolQuantityStepper
	made.min_value = low
	made.max_value = high
	made.value = start
	return made


func _init() -> void:
	ToolIcons.prime()


func _ready() -> void:
	if not Engine.is_editor_hint():
		UiSfx.override_click(minus_button, null)
		UiSfx.override_click(plus_button, null)
	minus_button.button_down.connect(_on_hold.bind(-1))
	minus_button.button_up.connect(hold_stop)
	plus_button.button_down.connect(_on_hold.bind(1))
	plus_button.button_up.connect(hold_stop)
	value_box.draw.connect(_on_value_box_draw)
	set_process(false)
	_apply_disabled()
	_refresh()


func _move(amount: int) -> void:
	var target: int = value + amount
	var clamped: int = clampi(target, min_value, ceiling())
	if clamped != value:
		if (clamped == target or reject_seconds <= 0.0) and not Engine.is_editor_hint():
			UiSfx.play_step(self)
		value = clamped
		value_changed.emit(value)
	if clamped != target:
		_reject(signi(target - clamped))


func _reject(side: int) -> void:
	if reject_seconds <= 0.0:
		return
	hold_stop()
	if not Engine.is_editor_hint():
		GameSfx.play_reject()
	if not is_rejecting() and is_node_ready():
		_shake_base = value_box.position.x
	_reject_side = side
	_reject_left = reject_seconds
	rejected.emit(side)
	_show_reject()
	set_process(true)
