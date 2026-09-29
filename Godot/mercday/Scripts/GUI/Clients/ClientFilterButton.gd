class_name ClientFilterButton
extends Button

#The client list filter: one check row per sub type over one per location. The button turns orange
#while anything is hidden, so a short list never looks like a bug.

signal changed

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Shared/FilterCheckRow.tscn")
const HEAD_FONT: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const HEAD_SIZE: int = 10
const HEAD_COLOR: Color = Color("#9cc6ef")
const TYPE_HEAD: String = "Type"
const PLACE_HEAD: String = "Location"
const POPUP_WIDTH: int = 250
const POPUP_MAX_HEIGHT: int = 430
const PLAIN_FILL: Color = Color("#2b4f8a")
const PLAIN_HI: Color = Color("#3b6fb6")
const PLAIN_LO: Color = Color("#1f3560")
const PLAIN_TEXT: Color = Color("#f3ead7")
const CHANGED_FILL: Color = Color("#f28c28")
const CHANGED_HI: Color = Color("#ffb266")
const CHANGED_LO: Color = Color("#b85a12")
const CHANGED_TEXT: Color = Color("#0a0f1c")
const BEVEL_PX: float = 2.0
const PAD_X: float = 8.0
const PAD_Y: float = 4.0
const STATES: Array[String] = ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]
const TEXT_KEYS: Array[String] = ["font_color", "font_hover_color", "font_pressed_color",
	"font_focus_color", "font_disabled_color"]

@onready var menu: PopupPanel = $Menu
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
	focus_mode = Control.FOCUS_NONE
	if not pressed.is_connected(open_popup):
		pressed.connect(open_popup)
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


func open_popup() -> void:
	var rect: Rect2 = get_global_rect()
	var wanted: Vector2 = menu.get_contents_minimum_size()
	var height: int = mini(POPUP_MAX_HEIGHT, maxi(int(wanted.y), 1))
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	menu.popup(Rect2i(pos, Vector2i(POPUP_WIDTH, height)))


func popup_open() -> bool:
	return is_node_ready() and menu.visible


func row_count() -> int:
	return _sub_rows.size() + _loc_rows.size()


func fill_color() -> Color:
	return CHANGED_FILL if is_changed() else PLAIN_FILL


func text_color() -> Color:
	return CHANGED_TEXT if is_changed() else PLAIN_TEXT


func _draw() -> void:
	var hi: Color = CHANGED_HI if is_changed() else PLAIN_HI
	var lo: Color = CHANGED_LO if is_changed() else PLAIN_LO
	draw_rect(Rect2(0.0, 0.0, size.x, BEVEL_PX), hi)
	draw_rect(Rect2(0.0, 0.0, BEVEL_PX, size.y), hi)
	draw_rect(Rect2(0.0, size.y - BEVEL_PX, size.x, BEVEL_PX), lo)
	draw_rect(Rect2(size.x - BEVEL_PX, 0.0, BEVEL_PX, size.y), lo)


func _build() -> void:
	_quiet = true
	_sub_rows.clear()
	_loc_rows.clear()
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
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
	head.add_theme_font_override(&"font", HEAD_FONT)
	head.add_theme_font_size_override(&"font_size", HEAD_SIZE)
	head.add_theme_color_override(&"font_color", HEAD_COLOR)
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
	var fill: Color = fill_color()
	var ink: Color = text_color()
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.content_margin_left = PAD_X
	box.content_margin_top = PAD_Y
	box.content_margin_right = PAD_X
	box.content_margin_bottom = PAD_Y
	for state: String in STATES:
		add_theme_stylebox_override(state, box)
	for key: String in TEXT_KEYS:
		add_theme_color_override(key, ink)
	icon = ClientGlyphs.funnel(ink)
	queue_redraw()
