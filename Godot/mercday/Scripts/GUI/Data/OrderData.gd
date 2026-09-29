class_name OrderData extends RefCounted

#One Bazaar order. lines holds {"item_id": int, "qty": int} rows, days is the delivery time the
#order was bought at and arrived is set by the day tick that fired order_arrived for it.

var id: int = 0
var placed_day: int = 0
var days: int = 0
var lines: Array[Dictionary] = []
var total: int = 0
var arrived: bool = false
var seen: bool = false


static func from_dict(d: Dictionary) -> OrderData:
	var order := OrderData.new()
	order.id = int(d.get("id", 0))
	order.placed_day = int(d.get("placed_day", 0))
	order.days = int(d.get("days", 0))
	order.total = int(d.get("total", 0))
	order.arrived = bool(d.get("arrived", false))
	order.seen = bool(d.get("seen", false))
	var rows: Array[Dictionary] = []
	for row: Variant in (d.get("lines", []) as Array):
		rows.append((row as Dictionary).duplicate())
	order.lines = rows
	return order


func to_dict() -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in lines:
		rows.append(row.duplicate())
	return {"id": id, "placed_day": placed_day, "days": days, "lines": rows, "total": total,
		"arrived": arrived, "seen": seen}


#How many of one item the order carries.
func qty_of(item_id: int) -> int:
	for row: Dictionary in lines:
		if int(row.get("item_id", -1)) == item_id:
			return int(row.get("qty", 0))
	return 0


#Every item in the order counted together.
func item_count() -> int:
	var total_qty: int = 0
	for row: Dictionary in lines:
		total_qty += int(row.get("qty", 0))
	return total_qty
