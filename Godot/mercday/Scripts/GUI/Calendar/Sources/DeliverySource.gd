class_name DeliverySource extends CalendarSource

#One event per Bazaar order on the day it lands: placed_day plus its delivery days.


func events_between(d0: int, d1: int) -> Array[CalendarEvent]:
	var out: Array[CalendarEvent] = []
	for order: OrderData in BazaarManager.orders:
		var day: int = order.placed_day + order.days
		if not within(day, d0, d1):
			continue
		var state: String = "delivered" if BazaarManager.is_delivered(order) else "expected"
		var count: int = order.item_count()
		out.append(make_event(day, "Order #%d %s" % [order.id, state], "%d %s - %s notes" % [count,
			"item" if count == 1 else "items", TransactionData.grouped(order.total)], order))
	return out


#The order card in the calendar's OrderDialog.
func activate(event: CalendarEvent, dialog: Node) -> void:
	var calendar: CalendarDialog = dialog as CalendarDialog
	var order: OrderData = event.ref as OrderData
	if calendar != null and order != null:
		calendar.order_dialog.open_for(order)


func change_signals() -> Array[Signal]:
	return [BazaarManager.order_placed, BazaarManager.order_arrived]
