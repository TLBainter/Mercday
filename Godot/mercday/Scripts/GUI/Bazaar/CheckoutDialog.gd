class_name CheckoutDialog extends Control

#The confirmation before the spend: the lines of the cart, the four stats and Place Order. This is
#the only place the Bazaar calls BazaarManager.place_order(), and it calls it once per press.

signal placed(order: OrderData)
signal cancelled

const KICKER: String = "Checkout"
const TITLE: String = "Review Your Order"
const CANCEL_TEXT: String = "Cancel"
const PLACE_TEXT: String = "Place Order"
const DELIVERY_FREE: String = "Free"
const STAT_LABELS: Array[String] = ["Subtotal", "Delivery", "Estimated Arrival",
	"Notes After Purchase"]
const BOX_WIDTH: float = 520.0
const KICKER_SIZE: int = 9
const TITLE_SIZE: int = 16
const LINE_SIZE: int = 11
const STAT_SIZE: int = 11
const VALUE_SIZE: int = 13
const BUTTON_HEIGHT: float = 38.0
const ROW_GAP: int = 14
const LIST_GAP: int = 6

var _box: PanelContainer = null
var _rows: VBoxContainer = null
var _backdrop: Panel = null
var _centre: CenterContainer = null
var _lines: VBoxContainer = null
var _subtotal: NotesLabel = null
var _arrival: Label = null
var _after: NotesLabel = null
var _place: Button = null
var _cancel: Button = null


func _ready() -> void:
	visible = false
	_build()


func open() -> void:
	refresh()
	visible = true
	ModalFrame.fit(self, _backdrop, _centre)
	GuiFrameStack.push(self)


func close() -> void:
	visible = false
	GuiFrameStack.remove(self)


func _exit_tree() -> void:
	GuiFrameStack.remove(self)


func is_open() -> bool:
	return visible


func press_place() -> void:
	_on_place_pressed()


func press_cancel() -> void:
	_on_cancel_pressed()


func place_button() -> Button:
	return _place


func cancel_button() -> Button:
	return _cancel


func line_count() -> int:
	return _lines.get_child_count() if _lines != null else 0


func arrival_text() -> String:
	return _arrival.text if _arrival != null else ""


func refresh() -> void:
	if not is_node_ready() or _rows == null:
		return
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
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
	_after.value_color = BazaarUi.GREEN if after >= 0 else BazaarUi.RED
	var open_now: bool = BazaarManager.can_checkout()
	_place.disabled = not open_now
	_place.modulate.a = 1.0 if open_now else BazaarUi.DIM


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = Panel.new()
	_backdrop.theme_type_variation = &"BackdropPanel"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_centre = CenterContainer.new()
	_centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centre)
	ModalFrame.fit(self, _backdrop, _centre)
	_box = BazaarUi.panel_box(BazaarUi.PANEL, 4, BazaarUi.GREEN, 22.0)
	_box.custom_minimum_size.x = BOX_WIDTH
	_centre.add_child(_box)
	_rows = BazaarUi.vbox(ROW_GAP)
	_box.add_child(_rows)
	_rows.add_child(BazaarUi.silk(KICKER, KICKER_SIZE, BazaarUi.ORANGE))
	_rows.add_child(BazaarUi.silk_bold(TITLE, TITLE_SIZE, BazaarUi.CREAM))
	var list_box: PanelContainer = BazaarUi.panel_box(BazaarUi.NAVY, 2, BazaarUi.BLUE, 10.0)
	_rows.add_child(list_box)
	_lines = BazaarUi.vbox(LIST_GAP)
	list_box.add_child(_lines)
	_subtotal = BazaarUi.notes(0, VALUE_SIZE, BazaarUi.CREAM)
	_rows.add_child(_stat_row(STAT_LABELS[0], _subtotal))
	_rows.add_child(_stat_row(STAT_LABELS[1],
		BazaarUi.body(DELIVERY_FREE, VALUE_SIZE, BazaarUi.GREEN)))
	_arrival = BazaarUi.body("", STAT_SIZE, BazaarUi.CREAM)
	_rows.add_child(_stat_row(STAT_LABELS[2], _arrival))
	_after = BazaarUi.notes(0, VALUE_SIZE, BazaarUi.GREEN)
	_rows.add_child(_stat_row(STAT_LABELS[3], _after))
	var buttons: HBoxContainer = BazaarUi.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	_rows.add_child(buttons)
	_cancel = BazaarUi.button(CANCEL_TEXT, &"ButtonNeutral", BUTTON_HEIGHT, 10)
	_cancel.pressed.connect(_on_cancel_pressed)
	buttons.add_child(_cancel)
	_place = BazaarUi.button(PLACE_TEXT, &"ButtonGo", BUTTON_HEIGHT, 11)
	_place.pressed.connect(_on_place_pressed)
	buttons.add_child(_place)


func _line_row(found: BazaarItemData, qty: int) -> HBoxContainer:
	var row: HBoxContainer = BazaarUi.hbox(10)
	var name_label: Label = BazaarUi.body("%d x %s" % [qty, found.name], LINE_SIZE, BazaarUi.CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(BazaarUi.notes(found.price * qty, LINE_SIZE, BazaarUi.SKY))
	return row


func _stat_row(caption: String, value: Control) -> HBoxContainer:
	var row: HBoxContainer = BazaarUi.hbox(8)
	var caption_label: Label = BazaarUi.body(caption, STAT_SIZE, BazaarUi.SKY)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption_label)
	row.add_child(value)
	return row


#Esc answers this dialog only while it is the top frame of the stack.
func _unhandled_input(event: InputEvent) -> void:
	if GuiFrameStack.consume_escape(self, event):
		press_cancel()


func _on_place_pressed() -> void:
	if not visible or not BazaarManager.can_checkout():
		return
	var order: OrderData = BazaarManager.place_order()
	if order == null:
		refresh()
		return
	placed.emit(order)


func _on_cancel_pressed() -> void:
	close()
	cancelled.emit()
