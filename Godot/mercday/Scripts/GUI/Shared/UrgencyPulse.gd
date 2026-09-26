class_name UrgencyPulse extends ColorRect

#High urgency glow; a triangle wave alpha between 0.04 and 0.38 over one period, off when inactive.

var phase: float = 0.0

@export var active: bool = false:
	set(value):
		active = value
		_refresh()
@export var period: float = 2.6:
	set(value):
		period = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	if not active:
		phase = 0.0
		color.a = 0.0
	set_process(active)


func _process(delta: float) -> void:
	phase = fmod(phase + delta, period)
	color.a = alpha_at(phase, period)


static func alpha_at(phase_value: float, period_value: float) -> float:
	return 0.04 + 0.34 * (1.0 - absf(2.0 * phase_value / period_value - 1.0))
