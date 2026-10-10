class_name OrdersPage extends Control

#The Orders tab: the three filter buttons with their counts over a scrolling list of order cards,
#newest first. BazaarViewer rebuilds the page on order_placed, order_arrived and the day change.

signal filter_changed(key: StringName)

const CARD_SCENE: PackedScene = preload("res://Scenes/GUI/Bazaar/OrderCard.tscn")
const TITLE: String = "Your Orders"
const EMPTY_TEXT: String = "No orders here yet."
const FILTER_LABELS: Array[String] = ["All", "In Transit", "Delivered"]
const TITLE_SIZE: int = 14
const FILTER_SIZE: int = 10
const EMPTY_SIZE: int = 12
const FILTER_HEIGHT: float = 28.0
const ROW_GAP: int = 10
const LIST_GAP: int = 12

@export var filter: StringName = &"all":
	set(value):
		filter = value
		refresh()

var _title: Label = null
var _filter_row: HBoxContainer = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _empty: Label = null
var _buttons: Dictionary = {}


func _ready() -> void:
	_build()
	refresh()


func pick_filter(key: StringName) -> void:
	if not BazaarManager.ORDER_FILTERS.has(key) or filter == key:
		return
	filter = key
	filter_changed.emit(filter)


func cards() -> Array[OrderCard]:
	var out: Array[OrderCard] = []
	for child: Node in _list.get_children():
		if child is OrderCard:
			out.append(child as OrderCard)
	return out


func card_count() -> int:
	return cards().size()


func card_for(order_id: int) -> OrderCard:
	for card: OrderCard in cards():
		if card.order_id() == order_id:
			return card
	return null


func first_card() -> OrderCard:
	var found: Array[OrderCard] = cards()
	return found[0] if not found.is_empty() else null


func button_for(key: StringName) -> Button:
	return _buttons.get(key, null) as Button


func button_text(key: StringName) -> String:
	var button: Button = button_for(key)
	return button.text if button != null else ""


func empty_visible() -> bool:
	return _empty.visible


func empty_note_color() -> Color:
	return _empty.get_theme_color("font_color")


func refresh() -> void:
	if not is_node_ready() or _list == null:
		return
	var counts: Dictionary = BazaarManager.order_counts()
	for i: int in range(BazaarManager.ORDER_FILTERS.size()):
		var key: StringName = BazaarManager.ORDER_FILTERS[i]
		var button: Button = _buttons.get(key, null) as Button
		if button == null:
			continue
		button.text = "%s (%d)" % [FILTER_LABELS[i], int(counts.get(key, 0))]
		_paint(button, key == filter)
	GuiNodes.clear(_list)
	var found: Array[OrderData] = BazaarManager.orders_filtered(filter)
	for order: OrderData in found:
		var card: OrderCard = CARD_SCENE.instantiate() as OrderCard
		card.order = order
		_list.add_child(card)
	_empty.visible = found.is_empty()
	_scroll.visible = not found.is_empty()


func _build() -> void:
	var rows: VBoxContainer = GuiStyle.vbox(ROW_GAP)
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rows)
	var head: HBoxContainer = GuiStyle.hbox(12)
	rows.add_child(head)
	_title = GuiStyle.label(TITLE, GuiStyle.SILK_BOLD, TITLE_SIZE, GuiColors.CREAM)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_filter_row = GuiStyle.hbox(8)
	head.add_child(_filter_row)
	for i: int in range(BazaarManager.ORDER_FILTERS.size()):
		var key: StringName = BazaarManager.ORDER_FILTERS[i]
		var button: Button = BazaarUi.button(FILTER_LABELS[i], &"neutral", FILTER_HEIGHT,
			FILTER_SIZE)
		button.pressed.connect(pick_filter.bind(key))
		_filter_row.add_child(button)
		_buttons[key] = button
	_scroll = GuiStyle.scroll()
	rows.add_child(_scroll)
	_list = GuiStyle.vbox(LIST_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_empty = GuiStyle.label(EMPTY_TEXT, GuiStyle.BODY, EMPTY_SIZE, GuiColors.SKY)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rows.add_child(_empty)


func _paint(button: Button, picked: bool) -> void:
	var bevel: BevelButton = button as BevelButton
	if bevel != null:
		bevel.kind = &"orange" if picked else &"neutral"
