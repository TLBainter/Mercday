class_name ClientViewer
extends Control
#The My Clients window: three kind tabs over the client list, and the picked client's overview
#with its relationship, its contract history and, for a company, its stock chart. The frame that
#hosts the viewer supplies the scanline, so only the flat background is painted here.

const TAB_SCENE: PackedScene = preload("res://Scenes/GUI/Mercs/TabButton.tscn")
const TAB_LABELS: Array[String] = ["People", "Places", "Orgs"]
const TAB_TIPS: Array[String] = ["Clients who are people", "Clients who are places",
	"Companies that issue contracts"]
const BG_COLOR: Color = Color("#101a30")
const TAB_ICON_IDS: Dictionary = {&"people": "person", &"places": "house", &"orgs": "building"}
const TAB_ICON_SCALE: int = 2
const ORGS: StringName = &"orgs"
const RANGE_KEY: String = "1Y"
const RANGE_FALLBACK: int = 330

signal client_selected(kind: StringName, index: int)
signal contract_requested(entry_id: int)
signal invest_requested(company_id: int)

@export var start_tab: StringName = &"orgs":
	set(value):
		start_tab = value
		if is_node_ready():
			open_tab(value)

@export var auto_refresh: bool = true

@onready var tab_row: HBoxContainer = $Margin/Columns/Left/TabsWrap/Tabs
@onready var list: ClientList = $Margin/Columns/Left/List
@onready var overview: ClientOverview = $Margin/Columns/Overview

var _tabs: Array[TabButton] = []
var _registry: ClientRegistry = ClientRegistry.new()
var _tab: StringName = &"orgs"
var _sort_key: StringName = &"recent"
var _descending: bool = true
var _hidden_subs: Dictionary = {}
var _hidden_locations: Dictionary = {}
var _picked: Dictionary = {}
var _pinned: int = -1
var _popup: ViewerPopup = null
var _queued: bool = false


func _ready() -> void:
	_build_tabs()
	list.client_pressed.connect(_on_row_pressed)
	list.query_changed.connect(_on_query_changed)
	overview.recent_pressed.connect(_on_recent_pressed)
	overview.stock_pressed.connect(_on_stock_pressed)
	overview.take_me_there.connect(_on_take_me_there)
	_tab = _tab_of(start_tab)
	if auto_refresh:
		_hook_game()
		refresh()
	else:
		_render()


func _exit_tree() -> void:
	_unhook_game()


#The flat window fill; the SubWindow frame draws the scanline over every viewer.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)


func open_tab(key: StringName) -> void:
	_tab = _tab_of(key)
	_render()


func current_tab() -> StringName:
	return _tab


func tabs() -> Array[TabButton]:
	return _tabs


func selected() -> ClientData:
	var key: String = String(_picked.get(_tab, ""))
	if key.is_empty():
		return null
	return _client_of(key)


func select_client(kind: StringName, index: int) -> bool:
	var wanted: StringName = _tab_of(kind)
	var data: ClientData = _registry.client(wanted, index)
	if data == null:
		return false
	_tab = wanted
	_picked[wanted] = data.key()
	_render()
	list.scroll_to(data.key())
	client_selected.emit(wanted, index)
	return true


#The Invest tab opens a company here: the Orgs tab, the company listed even with no contract.
func show_client(company_id: int) -> bool:
	if company_id < 0 or company_id >= _registry.count(ORGS):
		return false
	var data: ClientData = _registry.client(ORGS, company_id)
	if data == null:
		return false
	_pinned = company_id
	_clear_filter_for(data)
	return select_client(ORGS, company_id)


func registry() -> ClientRegistry:
	return _registry


func set_registry(reg: ClientRegistry) -> void:
	if reg == null:
		return
	_registry = reg
	_render()


func refresh() -> void:
	_registry = ClientRegistry.from_game()
	_render()


func sort_key() -> StringName:
	return _sort_key


func descending() -> bool:
	return _descending


func pinned() -> int:
	return _pinned


func popup() -> ViewerPopup:
	return _popup


func _build_tabs() -> void:
	for i: int in TAB_LABELS.size():
		var button: TabButton = TAB_SCENE.instantiate()
		tab_row.add_child(button)
		button.index = i
		button.label = TAB_LABELS[i]
		button.description = TAB_TIPS[i]
		button.icon_id = String(TAB_ICON_IDS[ClientRegistry.KINDS[i]])
		button.icon_scale = TAB_ICON_SCALE
		button.idle_mode = Icons.MODE_PLAIN
		button.tab_pressed.connect(_on_tab_pressed)
		_tabs.append(button)


func _render() -> void:
	if not is_node_ready():
		return
	var idx: int = ClientRegistry.kind_index(_tab)
	for i: int in _tabs.size():
		_tabs[i].active = i == idx
	var pin: int = _pinned if _tab == ORGS else -1
	var subs: Array[String] = _hidden_list(_hidden_subs, _tab)
	var places: Array[String] = _hidden_list(_hidden_locations, _tab)
	list.set_title(TAB_LABELS[idx])
	list.set_query(_sort_index(), _descending)
	list.filter_button().set_options(_registry.sub_types(_tab, pin),
		_registry.location_names(_tab, pin), subs, places)
	var rows: Array[ClientData] = _registry.sorted(_tab, _sort_key, _descending, subs, places, pin)
	var key: String = String(_picked.get(_tab, ""))
	if _index_of(rows, key) < 0:
		key = rows[0].key() if not rows.is_empty() else ""
	_picked[_tab] = key
	list.set_clients(rows, _registry.total(_tab, pin), key)
	var data: ClientData = _client_of(key)
	if data != null and data.kind == ORGS:
		overview.set_stock(data.index, _prices_for(data))
	else:
		overview.hide_stock()
	overview.show_client(data)


#The last game year of the company's price history, or nothing when no market answers.
func _prices_for(data: ClientData) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if data == null or data.kind != ORGS:
		return out
	var market: Node = ClientRegistry.autoload_node(&"StockMarket")
	if market == null or not market.has_method("history"):
		return out
	var raw: Variant = market.call("history", data.index)
	if not (raw is PackedFloat32Array):
		return out
	var full: PackedFloat32Array = raw
	var days: int = int(StockMarket.RANGE_DAYS.get(RANGE_KEY, RANGE_FALLBACK))
	if days < 1 or full.size() <= days:
		return full
	return full.slice(full.size() - days)


func _tab_of(key: StringName) -> StringName:
	if ClientRegistry.KINDS.has(key):
		return key
	return _tab


func _sort_index() -> int:
	for i: int in ClientRegistry.SORTS.size():
		if ClientRegistry.sort_key_at(i) == _sort_key:
			return i
	return 0


func _hidden_list(map: Dictionary, kind: StringName) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = map.get(kind, [])
	if raw is Array:
		for value: Variant in raw:
			out.append(String(value))
	return out


func _index_of(rows: Array[ClientData], key: String) -> int:
	if key.is_empty():
		return -1
	for i: int in rows.size():
		if rows[i].key() == key:
			return i
	return -1


#A row key is "<kind>:<index>", the form ClientData.key() writes.
func _client_of(key: String) -> ClientData:
	var parts: PackedStringArray = key.split(":")
	if parts.size() != 2:
		return null
	return _registry.client(StringName(parts[0]), int(parts[1]))


func _clear_filter_for(data: ClientData) -> void:
	var subs: Array[String] = _hidden_list(_hidden_subs, ORGS)
	var places: Array[String] = _hidden_list(_hidden_locations, ORGS)
	if not subs.has(data.sub) and not places.has(data.location):
		return
	var none: Array[String] = []
	_hidden_subs[ORGS] = none
	_hidden_locations[ORGS] = none.duplicate()


func _open_popup(made: ViewerPopup) -> void:
	if made == null:
		return
	_popup = made
	made.closed.connect(_on_popup_closed)


func _hook_game() -> void:
	if not GameState.contracts_changed.is_connected(_queue_refresh):
		GameState.contracts_changed.connect(_queue_refresh)
	if not GameState.results_recorded.is_connected(_on_entry_event):
		GameState.results_recorded.connect(_on_entry_event)
	if not GameState.results_seen.is_connected(_on_entry_event):
		GameState.results_seen.connect(_on_entry_event)
	var market: Node = ClientRegistry.autoload_node(&"StockMarket")
	if market != null and market.has_signal(&"changed"):
		if not market.is_connected(&"changed", _queue_refresh):
			market.connect(&"changed", _queue_refresh)


func _unhook_game() -> void:
	if GameState.contracts_changed.is_connected(_queue_refresh):
		GameState.contracts_changed.disconnect(_queue_refresh)
	if GameState.results_recorded.is_connected(_on_entry_event):
		GameState.results_recorded.disconnect(_on_entry_event)
	if GameState.results_seen.is_connected(_on_entry_event):
		GameState.results_seen.disconnect(_on_entry_event)
	var market: Node = ClientRegistry.autoload_node(&"StockMarket")
	if market != null and market.has_signal(&"changed"):
		if market.is_connected(&"changed", _queue_refresh):
			market.disconnect(&"changed", _queue_refresh)


#At most one rebuild per frame, however many sources fired.
func _queue_refresh() -> void:
	if _queued:
		return
	_queued = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_queued = false
	if is_inside_tree():
		refresh()


func _on_entry_event(_entry_id: int) -> void:
	_queue_refresh()


func _on_tab_pressed(index: int) -> void:
	if index < 0 or index >= ClientRegistry.KINDS.size():
		return
	open_tab(ClientRegistry.KINDS[index])


func _on_row_pressed(key: String) -> void:
	var data: ClientData = _client_of(key)
	if data == null:
		return
	_picked[_tab] = key
	_render()
	client_selected.emit(data.kind, data.index)


func _on_query_changed() -> void:
	_sort_key = list.sort_key()
	_descending = list.descending()
	var filter: ClientFilterButton = list.filter_button()
	_hidden_subs[_tab] = filter.hidden_subs()
	_hidden_locations[_tab] = filter.hidden_locations()
	_render()


func _on_recent_pressed(entry_id: int) -> void:
	if _popup != null:
		return
	contract_requested.emit(entry_id)
	_open_popup(ViewerPopup.show_contract(self, entry_id))


func _on_stock_pressed(company_id: int) -> void:
	if _popup != null:
		return
	invest_requested.emit(company_id)
	_open_popup(ViewerPopup.show_invest(self, company_id))


func _on_popup_closed() -> void:
	_popup = null
	if auto_refresh:
		refresh()
	else:
		_render()


func _on_take_me_there(target: Dictionary) -> void:
	GameState.go_to_plans(target)
