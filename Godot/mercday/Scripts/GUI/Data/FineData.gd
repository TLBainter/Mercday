class_name FineData extends RefCounted

#One fine the guild owes. mercs holds the uids of the mercs the fine names, paid is the total that
#settled it (0 while it stands) and previous_amount keeps the figure a renegotiation changed.

var id: int = 0
var location_id: int = 0
var crime: String = ""
var mercs: Array[int] = []
var contract_id: int = 0
var day_issued: int = 0
var day_due: int = 0
var amount: int = 0
var paid: int = 0
var day_paid: int = -1
var unread: bool = false
var previous_amount: int = 0
var note: String = ""


static func from_dict(d: Dictionary) -> FineData:
	var fine := FineData.new()
	fine.id = int(d.get("id", 0))
	fine.location_id = int(d.get("location_id", 0))
	fine.crime = str(d.get("crime", ""))
	fine.mercs.assign(d.get("mercs", []))
	fine.contract_id = int(d.get("contract_id", 0))
	fine.day_issued = int(d.get("day_issued", 0))
	fine.day_due = int(d.get("day_due", 0))
	fine.amount = int(d.get("amount", 0))
	fine.paid = int(d.get("paid", 0))
	fine.day_paid = int(d.get("day_paid", -1))
	fine.unread = bool(d.get("unread", false))
	fine.previous_amount = int(d.get("previous_amount", 0))
	fine.note = str(d.get("note", ""))
	return fine


func to_dict() -> Dictionary:
	return {"id": id, "location_id": location_id, "crime": crime, "mercs": mercs.duplicate(),
		"contract_id": contract_id, "day_issued": day_issued, "day_due": day_due,
		"amount": amount, "paid": paid, "day_paid": day_paid, "unread": unread,
		"previous_amount": previous_amount, "note": note}


func is_paid() -> bool:
	return paid > 0
