@tool
class_name PoolPage extends VBoxContainer

#Base of the Appearance Pools tabs. A page builds its controls on first show and reloads them from the bound
#profile on every bind after that; edits write straight into the profile and emit edited.

signal edited

var profile: AppearanceProfile = null
var built: bool = false


func bind(p: AppearanceProfile) -> void:
	profile = p
	if built:
		_load()


func ensure_built() -> void:
	if built:
		return
	built = true
	_build()
	_load()


func _build() -> void:
	pass


func _load() -> void:
	pass


static func label(text: String) -> Label:
	var out := Label.new()
	out.text = text
	return out


static func button(text: String, on_press: Callable) -> Button:
	var out := Button.new()
	out.text = text
	out.pressed.connect(on_press)
	return out


static func weight_box(max_value: float, step: float) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = 0.0
	box.max_value = max_value
	box.step = step
	return box
