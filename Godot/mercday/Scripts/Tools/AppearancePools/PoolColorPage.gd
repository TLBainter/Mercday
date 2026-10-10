@tool
class_name PoolColorPage extends PoolPage

#The four palette groups stacked; each row is its gradient swatch, a tick and a weight, written to
#color_weights[group][row]. Traditions show the common group only.

const GROUPS: Array[String] = ["skin", "hair", "eyes", "common"]
const TRADITION_GROUPS: Array[String] = ["common"]
const SWATCH: Vector2 = Vector2(128, 8)
const ROWS_PER_LINE: int = 2

var _sections: Dictionary = {}
var _checks: Dictionary = {}
var _spins: Dictionary = {}
var _shown: Array[String] = GROUPS


func show_groups(groups: Array[String]) -> void:
	_shown = groups
	for group: String in _sections:
		(_sections[group] as Control).visible = group in _shown


func _build() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(column)
	for group: String in GROUPS:
		var section := VBoxContainer.new()
		column.add_child(section)
		_sections[group] = section
		var count: int = CharacterParts.palette_rows(group)
		var head := HBoxContainer.new()
		section.add_child(head)
		head.add_child(label("%s (%d rows)" % [group.capitalize(), count]))
		head.add_child(button("None", _tick_group.bind(group, false)))
		head.add_child(button("All", _tick_group.bind(group, true)))
		var grid := GridContainer.new()
		grid.columns = ROWS_PER_LINE * 3
		section.add_child(grid)
		var checks: Array[CheckBox] = []
		var spins: Array[SpinBox] = []
		for row: int in range(count):
			grid.add_child(_swatch(group, row))
			var check := CheckBox.new()
			check.toggled.connect(_on_row_toggled.bind(group, row))
			grid.add_child(check)
			var spin: SpinBox = weight_box(PartCell.WEIGHT_MAX, PartCell.WEIGHT_STEP)
			spin.value_changed.connect(_on_row_weight.bind(group, row))
			grid.add_child(spin)
			checks.append(check)
			spins.append(spin)
		_checks[group] = checks
		_spins[group] = spins
	show_groups(_shown)


func _load() -> void:
	for group: String in GROUPS:
		var weights: Dictionary = _weights(group)
		var checks: Array[CheckBox] = _checks[group]
		var spins: Array[SpinBox] = _spins[group]
		for row: int in range(checks.size()):
			var w: float = float(weights.get(row, 0.0))
			checks[row].set_pressed_no_signal(w > 0.0)
			spins[row].set_value_no_signal(w if w > 0.0 else PartCell.DEFAULT_WEIGHT)
			spins[row].editable = w > 0.0


func _weights(group: String) -> Dictionary:
	if profile == null:
		return {}
	return profile.color_weights.get(group, {}) as Dictionary


func _store(group: String, row: int) -> void:
	if profile == null:
		return
	var weights: Dictionary = _weights(group)
	var check: CheckBox = (_checks[group] as Array)[row] as CheckBox
	var spin: SpinBox = (_spins[group] as Array)[row] as SpinBox
	spin.editable = check.button_pressed
	if check.button_pressed:
		weights[row] = spin.value
	else:
		weights.erase(row)
	if weights.is_empty():
		profile.color_weights.erase(group)
	else:
		profile.color_weights[group] = weights


func _tick_group(group: String, on: bool) -> void:
	for check: CheckBox in _checks[group]:
		check.set_pressed_no_signal(on)
	for row: int in range((_checks[group] as Array).size()):
		_store(group, row)
	edited.emit()


func _on_row_toggled(_on: bool, group: String, row: int) -> void:
	_store(group, row)
	edited.emit()


func _on_row_weight(_value: float, group: String, row: int) -> void:
	if ((_checks[group] as Array)[row] as CheckBox).button_pressed:
		_store(group, row)
		edited.emit()


static func _swatch(group: String, row: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = SWATCH
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size_flags_vertical = SIZE_SHRINK_CENTER
	rect.tooltip_text = "%s row %d" % [group, row]
	var line: Image = CharacterParts.palette_row(group, row)
	if line != null:
		rect.texture = ImageTexture.create_from_image(line)
	return rect
