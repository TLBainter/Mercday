class_name RangeSlider extends HBoxContainer

#One labelled slider of the contract filter panel: a caption, the track and the live value.

signal slider_changed(value: float)

@export var caption: String = "":
	set(new_caption):
		caption = new_caption
		_refresh()
@export var suffix: String = "":
	set(new_suffix):
		suffix = new_suffix
		_refresh()
@export var decimals: int = 0:
	set(new_decimals):
		decimals = new_decimals
		_refresh()

@onready var caption_label: Label = $Caption
@onready var slider: HSlider = $Slider
@onready var value_label: Label = $Value


func _ready() -> void:
	slider.value_changed.connect(_on_value_changed)
	_refresh()


#Sets the track without firing the signal, so a rebuild never loops back into the filter.
func configure(low: float, high: float, step: float, current: float) -> void:
	if not is_node_ready():
		return
	slider.min_value = low
	slider.max_value = maxf(low, high)
	slider.step = step
	slider.set_value_no_signal(clampf(current, low, maxf(low, high)))
	_refresh()


func value() -> float:
	return slider.value if is_node_ready() else 0.0


func set_value_quiet(new_value: float) -> void:
	if not is_node_ready():
		return
	slider.set_value_no_signal(clampf(new_value, slider.min_value, slider.max_value))
	_refresh()


func _on_value_changed(new_value: float) -> void:
	_refresh()
	slider_changed.emit(new_value)


func _refresh() -> void:
	if not is_node_ready():
		return
	caption_label.text = caption
	value_label.text = value_text(slider.value)


func value_text(raw: float) -> String:
	var body: String = "%.*f" % [maxi(0, decimals), raw]
	return body + suffix
