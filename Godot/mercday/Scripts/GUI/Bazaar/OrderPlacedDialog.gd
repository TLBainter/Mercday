class_name OrderPlacedDialog extends ModalDialog

#What the guild sees after the spend: the order number, the day it lands and the two ways out.
#Keep Shopping is the cancel button and returns to the Shop tab; View Orders is the confirm button
#and opens the Orders tab on All.

const TWO_DAY_TAIL: String = " (2-Day delivery)."
const DAYS_TAIL: String = " (%d days)."
const MESSAGE_HEAD: String = "Order #%d will arrive %s"
const MESSAGE_SIZE: int = 12

var order: OrderData = null:
	set(value):
		order = value
		refresh()

var _message: Label = null


func _ready() -> void:
	super()
	_build()
	refresh()


func open_for(placed_order: OrderData) -> void:
	order = placed_order
	if order != null:
		present()


func press_view() -> void:
	press_confirm()


func message_text() -> String:
	return _message.text if _message != null else ""


func refresh() -> void:
	if not is_node_ready() or _message == null:
		return
	if order == null:
		_message.text = ""
		return
	var day_text: String = GuiDates.day_text(order.placed_day + order.days)
	var tail: String = TWO_DAY_TAIL if order.days == 2 else DAYS_TAIL % order.days
	_message.text = (MESSAGE_HEAD % [order.id, day_text]) + tail


func _build() -> void:
	_message = GuiStyle.label("", GuiStyle.BODY, MESSAGE_SIZE, GuiColors.CREAM)
	_message.custom_minimum_size.x = box_width - 60.0
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_message)
	rows.move_child(button_row, rows.get_child_count() - 1)
