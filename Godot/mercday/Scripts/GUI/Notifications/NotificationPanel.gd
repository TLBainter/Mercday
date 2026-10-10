class_name NotificationPanel extends Control

#The notification panel under the bell: the Unread and Read tabs, the sort and filter row with its
#two popups, and the scrolling list of items. The rows always come from NotificationCenter.listed.

signal item_pressed(data: NotificationData)
signal tab_changed(tab: String)
signal sort_changed(sort: StringName)
signal filter_changed(filter: String)

const PANEL_SIZE: Vector2 = Vector2(440, 520)
const PAD: float = 14.0
const TAB_UNREAD: String = "unread"
const TAB_READ: String = "read"
const ITEM_SCENE: PackedScene = preload("res://Scenes/GUI/Notifications/NotificationItem.tscn")

const BG_COLOR: Color = GuiColors.BOX_BG
const RING_COLOR: Color = GuiColors.ORANGE
const BEVEL_WIDTH: float = 4.0
const RING_WIDTH: float = 4.0
const SHADOW_OFFSET: float = 10.0
const SHADOW_SPREAD: float = 4.0
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)

const LIST_BG: Color = GuiColors.INK
const TAB_HOVER_GAIN: float = 1.12
const BELL_HOVER_GAIN: float = 1.15
const POPUP_DROP: float = 36.0
const POPUP_WIDTH: float = 200.0
const EMPTY_UNREAD: String = "No unread notifications."
const EMPTY_READ: String = "No read notifications."

@export var title_path: NodePath = ^"Pad/Col/Title"
@export var unread_tab_path: NodePath = ^"Pad/Col/TabRow/UnreadTab"
@export var read_tab_path: NodePath = ^"Pad/Col/TabRow/ReadTab"
@export var tool_row_path: NodePath = ^"Pad/Col/ToolWrap/ToolRow"
@export var sort_button_path: NodePath = ^"Pad/Col/ToolWrap/ToolRow/SortBtn"
@export var filter_button_path: NodePath = ^"Pad/Col/ToolWrap/ToolRow/FilterBtn"
@export var list_frame_path: NodePath = ^"Pad/Col/ListFrame"
@export var items_path: NodePath = ^"Pad/Col/ListFrame/Scroll/Pad2/Items"
@export var empty_label_path: NodePath = ^"Pad/Col/ListFrame/Scroll/Pad2/Items/EmptyLabel"
@export var sort_popup_path: NodePath = ^"SortPopup"
@export var filter_popup_path: NodePath = ^"FilterPopup"

var tab: String = TAB_UNREAD
var sort: StringName = NotificationCenter.SORT_URGENCY
var filter: String = NotificationCenter.FILTER_ALL

var _unread_tab: BevelButton = null
var _read_tab: BevelButton = null
var _tool_row: Control = null
var _sort_btn: BevelButton = null
var _filter_btn: BevelButton = null
var _list_frame: PanelContainer = null
var _items: VBoxContainer = null
var _empty: Label = null
var _sort_popup: NotificationSortPanel = null
var _filter_popup: NotificationFilterPanel = null
var _cards: Array[NotificationItem] = []


func _ready() -> void:
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	_unread_tab = get_node_or_null(unread_tab_path) as BevelButton
	_read_tab = get_node_or_null(read_tab_path) as BevelButton
	_tool_row = get_node_or_null(tool_row_path) as Control
	_sort_btn = get_node_or_null(sort_button_path) as BevelButton
	_filter_btn = get_node_or_null(filter_button_path) as BevelButton
	_list_frame = get_node_or_null(list_frame_path) as PanelContainer
	_items = get_node_or_null(items_path) as VBoxContainer
	_empty = get_node_or_null(empty_label_path) as Label
	_sort_popup = get_node_or_null(sort_popup_path) as NotificationSortPanel
	_filter_popup = get_node_or_null(filter_popup_path) as NotificationFilterPanel
	_wire()
	refresh()


func _wire() -> void:
	if _unread_tab != null:
		_unread_tab.pressed.connect(set_tab.bind(TAB_UNREAD))
	if _read_tab != null:
		_read_tab.pressed.connect(set_tab.bind(TAB_READ))
	if _sort_btn != null:
		_sort_btn.pressed.connect(toggle_sort_popup)
	if _filter_btn != null:
		_filter_btn.pressed.connect(toggle_filter_popup)
	if _list_frame != null:
		_list_frame.add_theme_stylebox_override("panel", _list_box())
	if _sort_popup != null:
		_sort_popup.set_options(NotificationSortPanel.SORT_LABELS, _sort_label())
		_sort_popup.picked.connect(_on_sort_picked)
		_sort_popup.visible = false
	if _filter_popup != null:
		_filter_popup.set_options(_filter_options(), filter)
		_filter_popup.picked.connect(_on_filter_picked)
		_filter_popup.visible = false
	if not NotificationCenter.changed.is_connected(refresh):
		NotificationCenter.changed.connect(refresh)


func set_tab(value: String) -> void:
	if value != TAB_UNREAD and value != TAB_READ:
		return
	if tab == value:
		return
	tab = value
	tab_changed.emit(tab)
	refresh()


func set_sort(value: StringName) -> void:
	if sort == value:
		return
	sort = value
	if _sort_popup != null:
		_sort_popup.set_selected(_sort_label())
	sort_changed.emit(sort)
	refresh()


func set_filter(value: String) -> void:
	if filter == value:
		return
	filter = value
	if _filter_popup != null:
		_filter_popup.set_selected(filter)
	filter_changed.emit(filter)
	refresh()


func reset_picks() -> void:
	set_tab(TAB_UNREAD)
	set_sort(NotificationCenter.SORT_URGENCY)
	set_filter(NotificationCenter.FILTER_ALL)


func unread_tab() -> Button:
	return _unread_tab


func read_tab() -> Button:
	return _read_tab


func sort_button() -> Button:
	return _sort_btn


func filter_button() -> Button:
	return _filter_btn


func tool_row() -> Control:
	return _tool_row


#The list scroller; only this box scrolls and it scrolls up and down alone.
func scroll() -> ScrollContainer:
	if _items == null:
		return null
	return _items.get_parent().get_parent() as ScrollContainer


#The rows the panel shows, straight from the store.
func rows() -> Array[NotificationData]:
	return NotificationCenter.listed(tab == TAB_UNREAD, sort, filter)


func cards() -> Array[NotificationItem]:
	return _cards.duplicate()


func card_for(id: int) -> NotificationItem:
	for card: NotificationItem in _cards:
		if card.row_id() == id:
			return card
	return null


func press_item(id: int) -> void:
	var card: NotificationItem = card_for(id)
	if card != null:
		card.press()


func press_mark_read(id: int) -> void:
	var card: NotificationItem = card_for(id)
	if card != null:
		card.press_mark_read()


func tab_text(unread: bool) -> String:
	if unread:
		return "Unread (%d)" % NotificationCenter.unread_count()
	return "Read (%d)" % NotificationCenter.read_count()


func empty_text() -> String:
	return EMPTY_UNREAD if tab == TAB_UNREAD else EMPTY_READ


func empty_visible() -> bool:
	return _cards.is_empty()


func filter_label() -> String:
	return "Filter" if filter == NotificationCenter.FILTER_ALL else filter


func sort_popup_open() -> bool:
	return _sort_popup != null and _sort_popup.visible


func filter_popup_open() -> bool:
	return _filter_popup != null and _filter_popup.visible


func toggle_sort_popup() -> void:
	var want: bool = not sort_popup_open()
	close_popups()
	if want and _sort_popup != null:
		_sort_popup.visible = true
		_place_popups()


func toggle_filter_popup() -> void:
	var want: bool = not filter_popup_open()
	close_popups()
	if want and _filter_popup != null:
		_filter_popup.visible = true
		_place_popups()


func close_popups() -> void:
	if _sort_popup != null:
		_sort_popup.visible = false
	if _filter_popup != null:
		_filter_popup.visible = false


func sort_popup() -> NotificationSortPanel:
	return _sort_popup


func filter_popup() -> NotificationFilterPanel:
	return _filter_popup


#Rebuilds the list and restyles the tabs and the tool row.
func refresh() -> void:
	_style_tabs()
	_style_tools()
	_rebuild_list()
	_place_popups()
	queue_redraw()


func _on_sort_picked(option: String) -> void:
	close_popups()
	set_sort(NotificationSortPanel.key_for(option))


func _on_filter_picked(option: String) -> void:
	close_popups()
	set_filter(option)


func _sort_label() -> String:
	return NotificationSortPanel.label_for(sort)


func _filter_options() -> Array[String]:
	var out: Array[String] = [NotificationCenter.FILTER_ALL]
	for kind: String in NotificationData.KINDS:
		out.append(kind)
	return out


func _rebuild_list() -> void:
	if _items == null:
		return
	for card: NotificationItem in _cards:
		_items.remove_child(card)
		card.queue_free()
	_cards.clear()
	for row: NotificationData in rows():
		var card: NotificationItem = ITEM_SCENE.instantiate() as NotificationItem
		_items.add_child(card)
		card.apply(row)
		card.item_pressed.connect(_on_card_pressed)
		_cards.append(card)
	if _empty != null:
		_empty.text = empty_text()
		_empty.visible = empty_visible()
		_items.move_child(_empty, _items.get_child_count() - 1)


func _on_card_pressed(data: NotificationData) -> void:
	item_pressed.emit(data)


func _style_tabs() -> void:
	_paint_tab(_unread_tab, tab == TAB_UNREAD, tab_text(true))
	_paint_tab(_read_tab, tab == TAB_READ, tab_text(false))


func _paint_tab(btn: BevelButton, active: bool, label: String) -> void:
	if btn == null:
		return
	btn.text = label
	var bg: Color = GuiColors.ORANGE if active else GuiColors.BLUE
	var fg: Color = GuiColors.INK if active else GuiColors.CREAM
	var hi: Color = GuiColors.ORANGE_HI if active else GuiColors.BLUE_HI
	var lo: Color = GuiColors.ORANGE_LO if active else GuiColors.BLUE_LO
	_dress(btn, bg, fg, hi, lo, TAB_HOVER_GAIN)


func _style_tools() -> void:
	if _sort_btn != null:
		_sort_btn.text = _sort_label()
		_sort_btn.icon = GuiGlyphs.lines(GuiColors.CREAM)
		_dress(_sort_btn, GuiColors.BLUE, GuiColors.CREAM, GuiColors.BLUE_HI, GuiColors.BLUE_LO,
			1.0, GuiColors.BLUE_HI)
	if _filter_btn == null:
		return
	var on: bool = filter != NotificationCenter.FILTER_ALL
	var bg: Color = GuiColors.ORANGE if on else GuiColors.BLUE
	var fg: Color = GuiColors.INK if on else GuiColors.CREAM
	var hi: Color = GuiColors.ORANGE_HI if on else GuiColors.BLUE_HI
	var lo: Color = GuiColors.ORANGE_LO if on else GuiColors.BLUE_LO
	_filter_btn.icon = GuiGlyphs.funnel(fg)
	_dress(_filter_btn, bg, fg, hi, lo, BELL_HOVER_GAIN)


#Colours one bevel button: the face, the text, the hover and press fill and its hi and lo bars.
func _dress(btn: BevelButton, bg: Color, fg: Color, hi: Color, lo: Color, gain: float,
		hover_bg: Color = GuiColors.CLEAR) -> void:
	var hover: Color = hover_bg if hover_bg.a > 0.0 else GuiColors.brighter(bg, gain)
	btn.set_colors(bg, hi, lo, fg)
	btn.hover_fill = hover
	btn.pressed_fill = hover
	var edges: BevelEdges = btn.get_node_or_null(^"Edges") as BevelEdges
	if edges != null:
		edges.hi = hi
		edges.lo = lo


func _list_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = LIST_BG
	box.set_corner_radius_all(0)
	box.content_margin_left = 4.0
	box.content_margin_top = 4.0
	box.content_margin_right = 6.0
	box.content_margin_bottom = 4.0
	return box


#The sort popup hangs from the left of the tool row, the filter popup from its right.
func _place_popups() -> void:
	if _tool_row == null:
		return
	var origin: Vector2 = _tool_row.global_position - global_position
	var drop: float = origin.y + POPUP_DROP
	if _sort_popup != null:
		_sort_popup.position = Vector2(origin.x, drop)
	if _filter_popup != null:
		_filter_popup.position = Vector2(origin.x + _tool_row.size.x - POPUP_WIDTH, drop)


#The frame: a hard shadow, the orange ring outside, the panel fill and the inset bevel.
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(SHADOW_OFFSET - SHADOW_SPREAD, SHADOW_OFFSET - SHADOW_SPREAD,
		w + SHADOW_SPREAD * 2.0, h + SHADOW_SPREAD * 2.0), SHADOW_COLOR)
	draw_rect(Rect2(-RING_WIDTH, -RING_WIDTH, w + RING_WIDTH * 2.0, h + RING_WIDTH * 2.0),
		RING_COLOR)
	draw_rect(Rect2(0.0, 0.0, w, h), BG_COLOR)
	BevelButton.paint_edges(self, Rect2(0.0, 0.0, w, h), GuiColors.EDGE_HI, GuiColors.EDGE_LO,
		BEVEL_WIDTH)
