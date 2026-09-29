class_name ClientList
extends PanelContainer

#The left column of the client window: the tab name and count over the sort, direction and filter
#controls, then one row per client. The panel draws its own bevel and orange top lip.

signal client_pressed(key: String)
signal query_changed

const ITEM_SCENE: PackedScene = preload("res://Scenes/GUI/Clients/ClientListItem.tscn")
const OUTLINE_PX: float = 4.0
const LIP_PX: float = 4.0
const BEVEL_PX: float = 4.0
const LIP_COLOR: Color = Color("#f28c28")
const BEVEL_HI: Color = Color("#28447a")
const BEVEL_LO: Color = Color("#111c33")
const COLUMN_WIDTH: int = 380
const FILTERED_TEXT: String = "No clients match this filter."
const EMPTY_TEXT: String = "No clients yet."

@onready var title_label: Label = $Rows/Head/Title
@onready var count_label: Label = $Rows/Head/Count
@onready var sort_button: SortButton = $Rows/SortRow/Sort
@onready var dir_toggle: SortDirToggle = $Rows/SortRow/Dir
@onready var filter: ClientFilterButton = $Rows/SortRow/Filter
@onready var scroll: ScrollContainer = $Rows/Scroll
@onready var items: VBoxContainer = $Rows/Scroll/Pad/Items
@onready var empty_panel: PanelContainer = $Rows/Scroll/Pad/Items/Empty
@onready var empty_label: Label = $Rows/Scroll/Pad/Items/Empty/EmptyText

var _rows: Array[ClientListItem] = []


func _ready() -> void:
	custom_minimum_size = Vector2(float(COLUMN_WIDTH), 0.0)
	sort_button.options = ClientRegistry.sort_labels()
	sort_button.selected = 0
	if not sort_button.sort_changed.is_connected(_on_query):
		sort_button.sort_changed.connect(_on_query)
	if not dir_toggle.direction_changed.is_connected(_on_dir):
		dir_toggle.direction_changed.connect(_on_dir)
	if not filter.changed.is_connected(_on_filter):
		filter.changed.connect(_on_filter)
	empty_panel.visible = false


func set_title(text_value: String) -> void:
	title_label.text = text_value


func set_clients(list_rows: Array[ClientData], total: int, selected_key: String) -> void:
	for row: ClientListItem in _rows:
		items.remove_child(row)
		row.queue_free()
	_rows.clear()
	for data: ClientData in list_rows:
		var item: ClientListItem = ITEM_SCENE.instantiate()
		items.add_child(item)
		item.set_client(data)
		item.selected = data.key() == selected_key
		var key: String = data.key()
		item.pressed.connect(func() -> void: client_pressed.emit(key))
		_rows.append(item)
	count_label.text = "%d/%d" % [list_rows.size(), maxi(total, list_rows.size())]
	empty_label.text = EMPTY_TEXT if total < 1 else FILTERED_TEXT
	empty_panel.visible = list_rows.is_empty()


func select_key(key: String) -> void:
	for row: ClientListItem in _rows:
		row.selected = row.client_key() == key


func row_for(key: String) -> ClientListItem:
	for row: ClientListItem in _rows:
		if row.client_key() == key:
			return row
	return null


func rows() -> Array[ClientListItem]:
	var out: Array[ClientListItem] = _rows.duplicate()
	return out


func press_row(key: String) -> bool:
	var row: ClientListItem = row_for(key)
	if row == null:
		return false
	client_pressed.emit(key)
	return true


func scroll_to(key: String) -> void:
	var row: ClientListItem = row_for(key)
	if row == null:
		return
	scroll.ensure_control_visible(row)


func sort_key() -> StringName:
	return ClientRegistry.sort_key_at(sort_button.selected)


func descending() -> bool:
	return dir_toggle.descending


func filter_button() -> ClientFilterButton:
	return filter


func sort_control() -> SortButton:
	return sort_button


func dir_control() -> SortDirToggle:
	return dir_toggle


func set_query(sort_index: int, down: bool) -> void:
	sort_button.selected = sort_index
	dir_toggle.descending = down


func title_text() -> String:
	return title_label.text


func count_text() -> String:
	return count_label.text


func empty_shown() -> bool:
	return empty_panel.visible


func empty_text() -> String:
	return empty_label.text


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, LIP_PX), LIP_COLOR)
	var left: float = OUTLINE_PX
	var top: float = LIP_PX
	var right: float = w - OUTLINE_PX
	var bottom: float = h - OUTLINE_PX
	draw_rect(Rect2(left, top, right - left, BEVEL_PX), BEVEL_HI)
	draw_rect(Rect2(left, top, BEVEL_PX, bottom - top), BEVEL_HI)
	draw_rect(Rect2(left, bottom - BEVEL_PX, right - left, BEVEL_PX), BEVEL_LO)
	draw_rect(Rect2(right - BEVEL_PX, top, BEVEL_PX, bottom - top), BEVEL_LO)


func _on_query(_index: int) -> void:
	query_changed.emit()


func _on_dir(_down: bool) -> void:
	query_changed.emit()


func _on_filter() -> void:
	query_changed.emit()
