class_name ClientFilterButton
extends PopupButton

#The client list filter: one check row per sub type over one per location. The button turns orange
#while anything is hidden, so a short list never looks like a bug.

signal changed

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterCheckRow.tscn")
const TYPE_HEAD: String = "Type"
const PLACE_HEAD: String = "Location"
const POPUP_MAX_HEIGHT: int = 430

@onready var rows: VBoxContainer = $Menu/Box/Scroll/Rows
@onready var reset_button: Button = $Menu/Box/Reset

var _subs: Array[String] = []
var _locs: Array[String] = []
var _hidden_subs: Array[String] = []
var _hidden_locs: Array[String] = []
var _sub_rows: Dictionary = {}
var _loc_rows: Dictionary = {}
var _quiet: bool = false


func _ready() -> void:
	super()
	focus_mode = Control.FOCUS_NONE
	if not reset_button.pressed.is_connected(reset):
		reset_button.pressed.connect(reset)
	_build()


func set_options(subs: Array[String], locations: Array[String], hidden_subs_in: Array[String],
		hidden_locations_in: Array[String]) -> void:
	_subs = subs.duplicate()
	_locs = locations.duplicate()
	_locs.sort()
	_hidden_subs = hidden_subs_in.duplicate()
	_hidden_locs = hidden_locations_in.duplicate()
	if is_node_ready():
		_build()


func hidden_subs() -> Array[String]:
	return _hidden_subs.duplicate()


func hidden_locations() -> Array[String]:
	return _hidden_locs.duplicate()


func is_changed() -> bool:
	return not _hidden_subs.is_empty() or not _hidden_locs.is_empty()


func toggle_sub(sub_name: String) -> void:
	_set_row(_sub_rows, sub_name, not _is_on(_sub_rows, sub_name))


func toggle_location(place_name: String) -> void:
	_set_row(_loc_rows, place_name, not _is_on(_loc_rows, place_name))


func reset() -> void:
	_quiet = true
	for key: Variant in _sub_rows:
		_set_row(_sub_rows, String(key), true)
	for key: Variant in _loc_rows:
		_set_row(_loc_rows, String(key), true)
	_quiet = false
	_collect()
	changed.emit()


func row_count() -> int:
	return _sub_rows.size() + _loc_rows.size()


func fill_color() -> Color:
	return fill


func caption_color() -> Color:
	return text_color


#The popup keeps the width the base picks but stops at POPUP_MAX_HEIGHT; past that the rows scroll.
func _popup_size() -> Vector2:
	var wanted: Vector2 = super()
	return Vector2(wanted.x, mini(POPUP_MAX_HEIGHT, maxi(int(wanted.y), 1)))


func _build() -> void:
	_quiet = true
	_sub_rows.clear()
	_loc_rows.clear()
	GuiNodes.clear(rows)
	if not _subs.is_empty():
		rows.add_child(_heading(TYPE_HEAD))
	for sub: String in _subs:
		_sub_rows[sub] = _add_row(sub, not _hidden_subs.has(sub))
	if not _locs.is_empty():
		rows.add_child(_heading(PLACE_HEAD))
	for place: String in _locs:
		_loc_rows[place] = _add_row(place, not _hidden_locs.has(place))
	_quiet = false
	_apply_look()


func _heading(text_value: String) -> Label:
	var head := Label.new()
	head.text = text_value
	head.theme_type_variation = &"CaptionLabel"
	return head


func _add_row(text_value: String, on: bool) -> FilterCheckRow:
	var row: FilterCheckRow = ROW_SCENE.instantiate()
	row.label = text_value
	row.on = on
	rows.add_child(row)
	row.toggled.connect(_on_row_toggled)
	return row


func _on_row_toggled(_now_on: bool) -> void:
	if _quiet:
		return
	_collect()
	changed.emit()


func _collect() -> void:
	_hidden_subs = _hidden_of(_sub_rows, _subs)
	_hidden_locs = _hidden_of(_loc_rows, _locs)
	_apply_look()


func _hidden_of(map: Dictionary, order: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for key: String in order:
		if not _is_on(map, key):
			out.append(key)
	return out


func _is_on(map: Dictionary, key: String) -> bool:
	var row: FilterCheckRow = _row_of(map, key)
	return row == null or row.on


func _set_row(map: Dictionary, key: String, on: bool) -> void:
	var row: FilterCheckRow = _row_of(map, key)
	if row != null:
		row.on = on


func _row_of(map: Dictionary, key: String) -> FilterCheckRow:
	if not map.has(key):
		return null
	var row: Variant = map[key]
	if row is FilterCheckRow:
		return row
	return null


func _apply_look() -> void:
	apply_palette(&"orange" if is_changed() else kind)
	icon = GuiGlyphs.funnel(caption_color())
