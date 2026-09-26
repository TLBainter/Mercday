class_name LevelModeList extends VBoxContainer

#Radio rows for the per merc level-up preference. The rows are built once from GameState.LEVEL_MODES
#so a pick never frees the button that raised it; refreshing only moves the checked row.

signal mode_chosen(mode: String)

var modes: Array[String] = []
var selected_mode: String = "Auto"

var _rows: Array[CheckBox] = []
var _group: ButtonGroup = null
var _updating: bool = false


func _ready() -> void:
	_build()
	set_mode(selected_mode)


func set_mode(mode: String) -> void:
	selected_mode = mode
	var index: int = modes.find(mode)
	if index < 0 or index >= _rows.size():
		return
	_updating = true
	_rows[index].button_pressed = true
	_updating = false


func pick(i: int) -> void:
	if i < 0 or i >= modes.size():
		return
	set_mode(modes[i])
	mode_chosen.emit(modes[i])


func pick_mode(mode: String) -> void:
	pick(modes.find(mode))


func rows() -> Array[CheckBox]:
	return _rows


func _build() -> void:
	modes.clear()
	for mode: String in GameState.LEVEL_MODES:
		modes.append(mode)
	_group = ButtonGroup.new()
	for i: int in modes.size():
		var box := CheckBox.new()
		box.text = modes[i]
		box.button_group = _group
		box.toggled.connect(_on_toggled.bind(i))
		add_child(box)
		_rows.append(box)


func _on_toggled(on: bool, i: int) -> void:
	if not on or _updating:
		return
	selected_mode = modes[i]
	mode_chosen.emit(modes[i])
