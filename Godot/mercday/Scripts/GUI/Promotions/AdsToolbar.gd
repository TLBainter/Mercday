class_name AdsToolbar extends HBoxContainer

#The right half of the My Promotions header: how many campaigns the filters leave standing, the
#two show toggles and the five sorts. The toolbar never sorts or filters a list itself; it reports
#what the reader picked and PromotionsManager does the work.

signal filter_changed(show_concluded: bool, show_infinite: bool)
signal sort_changed(key: StringName)
signal direction_changed(ascending: bool)

const FONT_SILK: FontVariation = preload("res://Resources/GUI/Theme/Fonts/SilkscreenRegular.tres")
const FONT_BODY: FontVariation = preload("res://Resources/GUI/Theme/Fonts/PixelifyRegular.tres")
const CAPTION_COLOR: Color = Color("#9cc6ef")
const CREAM: Color = Color("#f3ead7")
const FIELD_BG: Color = Color("#15223d")
const RING_PLAIN: Color = Color("#3b6fb6")
const RING_CUSTOM: Color = Color("#f28c28")
const CAPTION_SIZE: int = 9
const COUNT_SIZE: int = 11
const FILTER_SIZE: Vector2 = Vector2(150, 32)
const SORT_SIZE: Vector2 = Vector2(170, 32)
const FILTER_POPUP_WIDTH: int = 190
const ROW_HEIGHT: float = 34.0
const RING_PX: int = 2
const GAP: int = 10
const LABEL_ACTIVE: String = "Active"
const LABEL_CUSTOM: String = "Custom"
const CONCLUDED_LABEL: String = "Show Concluded"
const INFINITE_LABEL: String = "Show Infinite"
const SHOWN_FORMAT: String = "%d of %d shown"
const DEFAULT_CONCLUDED: bool = false
const DEFAULT_INFINITE: bool = true

@onready var count: Label = $Count
@onready var filter_caption: Label = $FilterBox/Caption
@onready var filter_button: Button = $FilterBox/Button
@onready var filter_menu: PopupPanel = $FilterBox/Button/Menu
@onready var concluded_row: FilterCheckRow = $FilterBox/Button/Menu/List/Concluded
@onready var infinite_row: FilterCheckRow = $FilterBox/Button/Menu/List/Infinite
@onready var sort_caption: Label = $SortBox/Caption
@onready var sort_button: SortButton = $SortBox/Row/Sort
@onready var dir_toggle: SortDirToggle = $SortBox/Row/Direction

var _concluded: bool = DEFAULT_CONCLUDED
var _infinite: bool = DEFAULT_INFINITE
var _key: StringName = PromotionsManager.CAMPAIGN_SORT_DEFAULT
var _ascending: bool = PromotionsManager.CAMPAIGN_ASCENDING_DEFAULT
#True while the toolbar writes the rows itself, so a set_filter call reports nothing back.
var _quiet: bool = false


func _ready() -> void:
	add_theme_constant_override(&"separation", GAP)
	_style_caption(filter_caption, "Filter")
	_style_caption(sort_caption, "Sort")
	count.add_theme_font_override(&"font", FONT_BODY)
	count.add_theme_font_size_override(&"font_size", COUNT_SIZE)
	count.add_theme_color_override(&"font_color", CAPTION_COLOR)
	filter_button.custom_minimum_size = FILTER_SIZE
	filter_button.add_theme_font_override(&"font", FONT_BODY)
	filter_button.add_theme_font_size_override(&"font_size", 13)
	filter_button.add_theme_color_override(&"font_color", CREAM)
	filter_button.pressed.connect(open_filter)
	concluded_row.label = CONCLUDED_LABEL
	infinite_row.label = INFINITE_LABEL
	for row: FilterCheckRow in [concluded_row, infinite_row]:
		row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		row.toggled.connect(_on_row_toggled.unbind(1))
	sort_button.custom_minimum_size = SORT_SIZE
	sort_button.options = _sort_labels()
	sort_button.sort_changed.connect(_on_sort_picked)
	dir_toggle.direction_changed.connect(_on_direction_changed)
	_apply()


func set_count(shown: int, total: int) -> void:
	if not is_node_ready():
		return
	count.text = SHOWN_FORMAT % [shown, total]


func shown_text() -> String:
	return count.text if is_node_ready() else ""


func set_filter(concluded_on: bool, infinite_on: bool) -> void:
	_concluded = concluded_on
	_infinite = infinite_on
	if is_node_ready():
		_quiet = true
		concluded_row.on = _concluded
		infinite_row.on = _infinite
		_quiet = false
		_apply()


func show_concluded() -> bool:
	return _concluded


func show_infinite() -> bool:
	return _infinite


func filter_text() -> String:
	return LABEL_ACTIVE if _at_defaults() else LABEL_CUSTOM


func open_filter() -> void:
	if not is_node_ready():
		return
	var rect: Rect2 = filter_button.get_global_rect()
	var wanted: Vector2 = filter_menu.get_contents_minimum_size()
	var width: int = maxi(FILTER_POPUP_WIDTH, int(wanted.x))
	var pos := Vector2i(int(rect.position.x), int(rect.end.y))
	filter_menu.popup(Rect2i(pos, Vector2i(width, int(wanted.y))))


func filter_open() -> bool:
	return is_node_ready() and filter_menu.visible


func press_row(concluded: bool) -> void:
	if not is_node_ready():
		return
	var row: FilterCheckRow = concluded_row if concluded else infinite_row
	row.button_pressed = not row.button_pressed


func pick_sort(key: StringName) -> void:
	var index: int = _index_of(key)
	if index < 0:
		return
	_key = key
	if is_node_ready():
		sort_button.selected = index
	sort_changed.emit(_key)


func sort_key() -> StringName:
	return _key


func toggle_direction() -> void:
	if is_node_ready():
		dir_toggle.toggle()
		return
	_ascending = not _ascending
	direction_changed.emit(_ascending)


func set_direction(ascending_on: bool) -> void:
	_ascending = ascending_on
	if is_node_ready():
		dir_toggle.descending = not ascending_on


func ascending() -> bool:
	return _ascending


func _sort_labels() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in PromotionsManager.CAMPAIGN_SORTS:
		out.append(String(row["label"]))
	return out


func _index_of(key: StringName) -> int:
	for i: int in range(PromotionsManager.CAMPAIGN_SORTS.size()):
		if StringName(PromotionsManager.CAMPAIGN_SORTS[i]["key"]) == key:
			return i
	return -1


func _key_at(index: int) -> StringName:
	if index < 0 or index >= PromotionsManager.CAMPAIGN_SORTS.size():
		return PromotionsManager.CAMPAIGN_SORT_DEFAULT
	return StringName(PromotionsManager.CAMPAIGN_SORTS[index]["key"])


func _at_defaults() -> bool:
	return _concluded == DEFAULT_CONCLUDED and _infinite == DEFAULT_INFINITE


func _style_caption(node: Label, text: String) -> void:
	node.text = text
	node.add_theme_font_override(&"font", FONT_SILK)
	node.add_theme_font_size_override(&"font_size", CAPTION_SIZE)
	node.add_theme_color_override(&"font_color", CAPTION_COLOR)


func _apply() -> void:
	filter_button.text = filter_text()
	var ring: Color = RING_PLAIN if _at_defaults() else RING_CUSTOM
	var box := StyleBoxFlat.new()
	box.bg_color = FIELD_BG
	box.set_border_width_all(RING_PX)
	box.border_color = ring
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		filter_button.add_theme_stylebox_override(state, box)
	sort_button.selected = maxi(0, _index_of(_key))
	dir_toggle.descending = not _ascending


func _on_row_toggled() -> void:
	if _quiet:
		return
	_concluded = concluded_row.on
	_infinite = infinite_row.on
	_apply()
	filter_changed.emit(_concluded, _infinite)


func _on_sort_picked(index: int) -> void:
	_key = _key_at(index)
	sort_changed.emit(_key)


func _on_direction_changed(descending: bool) -> void:
	_ascending = not descending
	direction_changed.emit(_ascending)
