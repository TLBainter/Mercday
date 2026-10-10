class_name OrderDialog extends ModalDialog

#One Bazaar order opened from the calendar: its order card under Expected Delivery while it is on
#the way, or under Delivered Order once it has landed.

const EXPECTED_TITLE: String = "Expected Delivery"
const DELIVERED_TITLE: String = "Delivered Order"

@onready var card: OrderCard = $Box/Pad/Rows/Card


func open_for(order: OrderData) -> void:
	if order == null:
		return
	title = DELIVERED_TITLE if BazaarManager.is_delivered(order) else EXPECTED_TITLE
	card.order = order
	present()
