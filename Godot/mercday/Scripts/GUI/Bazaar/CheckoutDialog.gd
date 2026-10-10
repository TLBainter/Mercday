class_name CheckoutDialog extends ModalDialog

#The confirmation before the spend: the lines of the cart, the four stats and Place Order. This is
#the only place the Bazaar calls BazaarManager.place_order(), and it calls it once per press.

signal placed(order: OrderData)

const DELIVERY_FREE: String = "Free"
const STAT_LABELS: Array[String] = ["Subtotal", "Delivery", "Estimated Arrival",
	"Notes After Purchase"]
const LINE_SIZE: int = 11
const STAT_SIZE: int = 11
const VALUE_SIZE: int = 13
const LIST_GAP: int = 6

var _lines: VBoxContainer = null
var _subtotal: NotesLabel = null
var _arrival: Label = null
var _after: NotesLabel = null


func _ready() -> void:
	super()
	_build()


func open() -> void:
	refresh()
	present()


func press_place() -> void:
	press_confirm()


func line_count() -> int:
	return _lines.get_child_count() if _lines != null else 0


func arrival_text() -> String:
	return _arrival.text if _arrival != null else ""


func refresh() -> void:
	if not is_node_ready() or _lines == null:
		return
	GuiNodes.clear(_lines)
	for id: int in BazaarManager.cart_ids():
		var found: BazaarItemData = BazaarManager.item(id)
		if found == null:
			continue
		var qty: int = int(BazaarManager.cart.get(id, 0))
		_lines.add_child(_line_row(found, qty))
	var total: int = BazaarManager.cart_total()
	_subtotal.amount = total
	_arrival.text = BazaarUi.eta_text(BazaarManager.delivery_days(), GameState.day())
	var after: int = GameState.bank_notes - total
	_after.amount = after
	_after.value_color = GuiColors.GREEN if after >= 0 else GuiColors.RED
	var open_now: bool = BazaarManager.can_checkout()
	confirm_button.disabled = not open_now
	confirm_button.modulate.a = 1.0 if open_now else BazaarUi.DIM


#The cart list and the four stats sit between the head and the buttons of the base scene.
func _build() -> void:
	var list_box: PanelContainer = BazaarUi.panel_box(GuiColors.ROW_FILL, 2, GuiColors.BLUE_LO, 10.0)
	rows.add_child(list_box)
	_lines = GuiStyle.vbox(LIST_GAP)
	list_box.add_child(_lines)
	_subtotal = GuiStyle.notes(0, VALUE_SIZE, GuiColors.CREAM)
	rows.add_child(_stat_row(STAT_LABELS[0], _subtotal))
	rows.add_child(_stat_row(STAT_LABELS[1],
		GuiStyle.label(DELIVERY_FREE, GuiStyle.BODY, VALUE_SIZE, GuiColors.GREEN)))
	_arrival = GuiStyle.label("", GuiStyle.BODY, STAT_SIZE, GuiColors.CREAM)
	rows.add_child(_stat_row(STAT_LABELS[2], _arrival))
	_after = GuiStyle.notes(0, VALUE_SIZE, GuiColors.GREEN)
	rows.add_child(_stat_row(STAT_LABELS[3], _after))
	rows.move_child(button_row, rows.get_child_count() - 1)


func _line_row(found: BazaarItemData, qty: int) -> HBoxContainer:
	var row: HBoxContainer = GuiStyle.hbox(10)
	var name_label: Label = GuiStyle.label("%d x %s" % [qty, found.name], GuiStyle.BODY, LINE_SIZE,
		GuiColors.CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(GuiStyle.notes(found.price * qty, LINE_SIZE, GuiColors.SKY))
	return row


func _stat_row(caption: String, value: Control) -> HBoxContainer:
	return BazaarUi.pair_row(GuiStyle.label(caption, GuiStyle.BODY, STAT_SIZE, GuiColors.SKY), value)


#A closed dialog places nothing. A refused order, such as a cart the bank no longer covers, plays the
#reject and keeps the dialog open on the redrawn cart.
func _on_confirm() -> bool:
	if not visible:
		return false
	var order: OrderData = BazaarManager.place_order()
	if order == null:
		UiSfx.reject_press(confirm_button)
		refresh()
		return false
	placed.emit(order)
	return true
