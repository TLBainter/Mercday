class_name TypeSelector extends Button

#Picks which contract types the Contract graph plots. The button opens a checkbox popup, one row
#per contract type; every type checked reads the bare totals the record keeps beside the per type
#keys, one checked type reads "<type>/<key>" and any other count plots the combined series. The
#last checked box is locked, so the chart always has at least one type.

const ALL := "All"
const BOX_SIZE := Vector2(14, 14)
const DOT_SIZE := Vector2(4, 4)
const BORDER_COLOR := Color(0.949020, 0.549020, 0.156863, 1)
const OFF_BOX := Color(0.039216, 0.058824, 0.109804, 1)
const ON_TEXT := Color(0.952941, 0.917647, 0.843137, 1)
const OFF_TEXT := Color(0.541176, 0.592157, 0.678431, 1)
const LOCKED_ALPHA := 0.6
const LOCKED_TIP := "At least one type must stay selected"
const ALL_CAPTION := "All Contract Types"
const ALL_SUB := "Showing totals across every type"

signal types_changed(names: Array[String])

@export var popup_width: int = 260

var _names: Array[String] = []
var _selected: Array[String] = []

@onready var caption_label: Label = $Row/Caption
@onready var sub_label: Label = $Row/Sub
@onready var menu: PopupPanel = $Menu
@onready var list: VBoxContainer = $Menu/Margin/List


func _ready() -> void:
	pressed.connect(_on_pressed)
	rebuild()


#Reads the contract types from the library, keeping whatever of the old picks still exist.
func rebuild() -> void:
	if not is_node_ready():
		return
	_names = ContractLibrary.contract_type_names()
	var kept: Array[String] = []
	for type_name: String in _selected:
		if _names.has(type_name):
			kept.append(type_name)
	_selected = kept if not kept.is_empty() else _names.duplicate()
	_build_rows()
	_apply()


func selected_types() -> Array[String]:
	return _selected.duplicate()


func option_count() -> int:
	return _names.size()


#True while a row may not be unchecked, which is the row of the one type still on.
func option_disabled(index: int) -> bool:
	var rows: Array[Button] = _rows()
	return rows[index].disabled if index >= 0 and index < rows.size() else false


#Refused when it would leave no type checked; unknown names are dropped.
func set_types(names: Array[String]) -> void:
	var wanted: Array[String] = []
	for type_name: String in _names:
		if names.has(type_name):
			wanted.append(type_name)
	if wanted.is_empty() or wanted == _selected:
		return
	_selected = wanted
	_apply()
	types_changed.emit(selected_types())


func select_type(type_name: String) -> void:
	set_types([type_name] as Array[String])


func is_all() -> bool:
	return not _names.is_empty() and _selected.size() == _names.size()


#"All" while every type is checked or several are, else the one checked name.
func current_type() -> String:
	if _selected.size() == 1:
		return _selected[0]
	return ALL


#The stored key of one metric; only a single checked type prefixes its own key.
func key_for(metric_key: String) -> String:
	if _selected.size() == 1:
		return "%s/%s" % [_selected[0], metric_key]
	return metric_key


func _rows() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in list.get_children():
		if child is Button:
			out.append(child)
	return out


func _build_rows() -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for i: int in _names.size():
		list.add_child(_make_row(_names[i], i))


func _make_row(type_name: String, index: int) -> Button:
	var row := Button.new()
	row.name = "Row%d" % index
	row.custom_minimum_size = Vector2(0, 28)
	row.flat = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.pressed.connect(_on_row_pressed.bind(type_name))
	var line := HBoxContainer.new()
	line.name = "Line"
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 6.0
	line.offset_right = -6.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var box := Panel.new()
	box.name = "Box"
	box.custom_minimum_size = BOX_SIZE
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(box)
	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.size = DOT_SIZE
	dot.position = (BOX_SIZE - DOT_SIZE) * 0.5
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dot)
	var text_label := Label.new()
	text_label.name = "Name"
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.theme_type_variation = &"DescriptionLabel"
	text_label.clip_text = true
	text_label.text = type_name
	line.add_child(text_label)
	return row


func _apply() -> void:
	var rows: Array[Button] = _rows()
	for i: int in rows.size():
		var on: bool = _selected.has(_names[i])
		var locked: bool = on and _selected.size() == 1
		var row: Button = rows[i]
		row.disabled = locked
		row.modulate.a = LOCKED_ALPHA if locked else 1.0
		row.tooltip_text = LOCKED_TIP if locked else ""
		var box: Panel = row.get_node("Line/Box") as Panel
		box.add_theme_stylebox_override("panel", _box_style(on))
		(box.get_node("Dot") as ColorRect).color = OFF_BOX if on else Color(0, 0, 0, 0)
		(row.get_node("Line/Name") as Label).add_theme_color_override("font_color",
			ON_TEXT if on else OFF_TEXT)
	caption_label.text = ALL_CAPTION if is_all() else ", ".join(_selected)
	sub_label.text = ALL_SUB if is_all() else "%d of %d types selected" % [_selected.size(),
		_names.size()]


static func _box_style(on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BORDER_COLOR if on else OFF_BOX
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	return style


func _on_pressed() -> void:
	var rect: Rect2 = get_global_rect()
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	var height: int = int(list.get_combined_minimum_size().y) + 16
	menu.popup(Rect2i(pos, Vector2i(maxi(popup_width, int(rect.size.x)), height)))


func _on_row_pressed(type_name: String) -> void:
	var wanted: Array[String] = _selected.duplicate()
	if wanted.has(type_name):
		wanted.erase(type_name)
	else:
		wanted.append(type_name)
	set_types(wanted)
