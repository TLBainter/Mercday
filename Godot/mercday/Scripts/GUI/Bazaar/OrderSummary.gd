class_name OrderSummary extends PanelContainer

#The right column of the cart: the four summary rows, the order total, the notes left after the
#purchase and the checkout button. Every figure comes from BazaarManager; nothing is computed here.

signal checkout_pressed

const TITLE: String = "Order Summary"
const DELIVERY_FREE: String = "Free"
const NO_ARRIVAL: String = "-"
const TOTAL_LABEL: String = "Order Total"
const AFTER_LABEL: String = "Notes After Purchase"
const CHECKOUT_TEXT: String = "Proceed to Checkout"
const CHECKOUT_HEIGHT: float = 46.0
const LABEL_SIZE: int = 11
const VALUE_SIZE: int = 13
const TOTAL_SIZE: int = 18
const REASON_SIZE: int = 10
const ROW_GAP: int = 10
const PANEL_WIDTH: float = 300.0

var _rows: VBoxContainer = null
var _items_label: Label = null
var _items_value: NotesLabel = null
var _delivery_value: Label = null
var _arrives_value: Label = null
var _notes_value: NotesLabel = null
var _total_value: NotesLabel = null
var _after_value: NotesLabel = null
var _checkout: Button = null
var _reason: Label = null


func _ready() -> void:
	custom_minimum_size.x = PANEL_WIDTH
	add_theme_stylebox_override("panel", GuiStyle.flat(GuiColors.ROW_FILL, 2, GuiColors.BLUE_LO, 12.0))
	_build()
	refresh()


func press_checkout() -> void:
	if _checkout == null or _checkout.disabled:
		return
	_on_checkout_pressed()


func checkout_button() -> Button:
	return _checkout


func reason_text() -> String:
	return _reason.text if _reason != null else ""


func items_caption() -> String:
	return _items_label.text if _items_label != null else ""


func row_text(key: StringName) -> String:
	match key:
		&"items":
			return _items_value.value_text()
		&"delivery":
			return _delivery_value.text
		&"arrives":
			return _arrives_value.text
		&"notes":
			return _notes_value.value_text()
		&"total":
			return _total_value.value_text()
		&"after":
			return _after_value.value_text()
	return ""


func refresh() -> void:
	if not is_node_ready() or _rows == null:
		return
	var count: int = BazaarManager.cart_count()
	var total: int = BazaarManager.cart_total()
	var after: int = GameState.bank_notes - total
	_items_label.text = "Items (%d)" % count
	_items_value.amount = total
	_arrives_value.text = NO_ARRIVAL if count <= 0 else BazaarUi.eta_text(
		BazaarManager.delivery_days(), GameState.day())
	_notes_value.amount = GameState.bank_notes
	_total_value.amount = total
	_total_value.value_color = GuiColors.CREAM if after >= 0 else GuiColors.RED
	_after_value.amount = after
	_after_value.value_color = GuiColors.GREEN if after >= 0 else GuiColors.RED
	var open: bool = BazaarManager.can_checkout()
	_checkout.disabled = not open
	_checkout.modulate.a = 1.0 if open else BazaarUi.DIM
	_reason.text = BazaarManager.checkout_reason()
	_reason.visible = _reason.text != ""


func _build() -> void:
	_rows = GuiStyle.vbox(ROW_GAP)
	add_child(_rows)
	_rows.add_child(BazaarUi.heading(TITLE))
	_items_label = GuiStyle.label("Items (0)", GuiStyle.BODY, LABEL_SIZE, GuiColors.SKY)
	_items_value = GuiStyle.notes(0, VALUE_SIZE, GuiColors.CREAM)
	_rows.add_child(BazaarUi.pair_row(_items_label, _items_value))
	_delivery_value = GuiStyle.label(DELIVERY_FREE, GuiStyle.BODY, VALUE_SIZE, GuiColors.GREEN)
	_rows.add_child(BazaarUi.pair_row(
		GuiStyle.label("Delivery", GuiStyle.BODY, LABEL_SIZE, GuiColors.SKY), _delivery_value))
	_arrives_value = GuiStyle.label(NO_ARRIVAL, GuiStyle.BODY, LABEL_SIZE, GuiColors.CREAM)
	_arrives_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrives_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(BazaarUi.pair_row(
		GuiStyle.label("Arrives", GuiStyle.BODY, LABEL_SIZE, GuiColors.SKY), _arrives_value))
	_notes_value = GuiStyle.notes(0, VALUE_SIZE, GuiColors.CREAM)
	_rows.add_child(BazaarUi.pair_row(
		GuiStyle.label("Your Notes", GuiStyle.BODY, LABEL_SIZE, GuiColors.SKY), _notes_value))
	var line: Panel = Panel.new()
	line.custom_minimum_size.y = 2.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_stylebox_override("panel",
		GuiStyle.flat(GuiColors.BLUE_LO, 0, GuiColors.BLUE_LO, 0.0))
	_rows.add_child(line)
	_total_value = GuiStyle.notes(0, TOTAL_SIZE, GuiColors.ORANGE)
	_total_value.bold = true
	_rows.add_child(BazaarUi.pair_row(
		GuiStyle.label(TOTAL_LABEL, GuiStyle.SILK, LABEL_SIZE, GuiColors.CREAM), _total_value))
	_after_value = GuiStyle.notes(0, VALUE_SIZE, GuiColors.GREEN)
	_rows.add_child(BazaarUi.pair_row(
		GuiStyle.label(AFTER_LABEL, GuiStyle.BODY, LABEL_SIZE, GuiColors.SKY), _after_value))
	_checkout = BazaarUi.button(CHECKOUT_TEXT, &"go", CHECKOUT_HEIGHT, 11)
	_checkout.pressed.connect(_on_checkout_pressed)
	_rows.add_child(_checkout)
	_reason = GuiStyle.label("", GuiStyle.BODY, REASON_SIZE, GuiColors.RED)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_reason)


func _on_checkout_pressed() -> void:
	checkout_pressed.emit()
