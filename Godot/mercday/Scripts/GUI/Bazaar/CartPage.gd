class_name CartPage extends Control

#The Cart tab: the scrolling list of rows on the left and the order summary on the right. The page
#reads the cart from BazaarManager on every refresh and never keeps a copy of it.

signal checkout_pressed
signal continue_shopping

const ROW_SCENE: PackedScene = preload("res://Scenes/GUI/Bazaar/CartRow.tscn")
const SUMMARY_SCENE: PackedScene = preload("res://Scenes/GUI/Bazaar/OrderSummary.tscn")
const TITLE: String = "Shopping Cart"
const EMPTY_TITLE: String = "Your cart is empty"
const EMPTY_NOTE: String = "Items you add from the Shop appear here."
const EMPTY_BUTTON: String = "Continue Shopping"
const TITLE_SIZE: int = 14
const COUNT_SIZE: int = 11
const EMPTY_TITLE_SIZE: int = 13
const EMPTY_NOTE_SIZE: int = 11
const EMPTY_HEIGHT: float = 34.0
const COLUMN_GAP: int = 16
const LIST_GAP: int = 8

var _title: Label = null
var _count: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _empty: VBoxContainer = null
var _empty_note: Label = null
var _summary: OrderSummary = null


func _ready() -> void:
	_build()
	refresh()


func press_checkout() -> void:
	_summary.press_checkout()


func press_continue() -> void:
	_on_continue_pressed()


#The count line over the list, as the page prints it.
func count_text() -> String:
	return _count.text if _count != null else ""


func summary() -> OrderSummary:
	return _summary


func rows() -> Array[CartRow]:
	var out: Array[CartRow] = []
	for child: Node in _list.get_children():
		if child is CartRow:
			out.append(child as CartRow)
	return out


func row_count() -> int:
	return rows().size()


func empty_note_color() -> Color:
	return _empty_note.get_theme_color("font_color")


func row_for(item_id: int) -> CartRow:
	for row: CartRow in rows():
		if row.item_id() == item_id:
			return row
	return null


func refresh() -> void:
	if not is_node_ready() or _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids: Array[int] = BazaarManager.cart_ids()
	for id: int in ids:
		var found: BazaarItemData = BazaarManager.item(id)
		if found == null:
			continue
		var row: CartRow = ROW_SCENE.instantiate() as CartRow
		row.item = found
		row.qty = int(BazaarManager.cart.get(id, 0))
		_list.add_child(row)
	var count: int = BazaarManager.cart_count()
	_count.text = BazaarUi.plural(count, "item", "items")
	_empty.visible = ids.is_empty()
	_scroll.visible = not ids.is_empty()
	_summary.refresh()


func _build() -> void:
	var columns: HBoxContainer = BazaarUi.hbox(COLUMN_GAP)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(columns)
	var left: VBoxContainer = BazaarUi.vbox(LIST_GAP)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var head: HBoxContainer = BazaarUi.hbox(10)
	left.add_child(head)
	_title = BazaarUi.silk_bold(TITLE, TITLE_SIZE, BazaarUi.CREAM)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = BazaarUi.body("", COUNT_SIZE, BazaarUi.SKY)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	_scroll = BazaarUi.scroll()
	left.add_child(_scroll)
	_list = BazaarUi.vbox(LIST_GAP)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_empty = _build_empty()
	left.add_child(_empty)
	_summary = SUMMARY_SCENE.instantiate() as OrderSummary
	_summary.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_summary.checkout_pressed.connect(_on_checkout_pressed)
	columns.add_child(_summary)


func _build_empty() -> VBoxContainer:
	var box: VBoxContainer = BazaarUi.vbox(10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_centered(BazaarUi.silk_bold(EMPTY_TITLE, EMPTY_TITLE_SIZE, BazaarUi.CREAM)))
	_empty_note = BazaarUi.body(EMPTY_NOTE, EMPTY_NOTE_SIZE, BazaarUi.SKY)
	box.add_child(_centered(_empty_note))
	var button: Button = BazaarUi.button(EMPTY_BUTTON, &"ButtonOrange", EMPTY_HEIGHT, 10)
	button.pressed.connect(_on_continue_pressed)
	box.add_child(_centered(button))
	return box


func _centered(inner: Control) -> HBoxContainer:
	var row: HBoxContainer = BazaarUi.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(inner)
	return row


func _on_checkout_pressed() -> void:
	checkout_pressed.emit()


func _on_continue_pressed() -> void:
	continue_shopping.emit()
