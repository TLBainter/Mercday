class_name TransactionData extends RefCounted

#One money movement the finance ledger keeps: the minute it landed, what it was for, the category
#it files under and the signed change to the bank. FinanceLedger.category_of names the category.

var day_index: int = 0
var minute: int = 0
var label: String = ""
var category: String = ""
var amount: int = 0
var reason: String = ""
#The travel mode key and distance of a travel charge or refund; "" and 0 on every other row.
var mode: String = ""
var distance_km: int = 0


#One row stamped to a minute; a minute below zero is clamped so a seeded history stays in range.
static func make(delta: int, at_minute: int, row_label: String, row_category: String,
		row_reason: String, row_mode: String = "", row_km: int = 0) -> TransactionData:
	var row := TransactionData.new()
	row.amount = delta
	row.minute = maxi(0, at_minute)
	row.day_index = TrynnCalendar.day_index(row.minute)
	row.label = row_label
	row.category = row_category
	row.reason = row_reason
	row.mode = row_mode
	row.distance_km = row_km
	return row


#Reads back a to_row dictionary; a row saved before mode existed loads with mode "" and 0 km.
static func from_row(d: Dictionary) -> TransactionData:
	var row: TransactionData = make(int(d.get("amount", 0)), int(d.get("minute", 0)),
		String(d.get("label", "")), String(d.get("category", "")), String(d.get("reason", "")),
		String(d.get("mode", "")), int(d.get("distance_km", 0)))
	return row


#"1,900", "-560": the digits in groups of three, the minus sign kept.
static func grouped(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	if value < 0:
		return "-" + out
	return out


#"Ansday, 2nd of Daith 212".
func date_text() -> String:
	return TrynnCalendar.date_text(minute)


#"+300", "-40", "0".
func amount_text() -> String:
	if amount > 0:
		return "+" + grouped(amount)
	return grouped(amount)


func to_row() -> Dictionary:
	return {"day_index": day_index, "minute": minute, "label": label, "category": category,
		"amount": amount, "reason": reason, "mode": mode, "distance_km": distance_km,
		"date_text": date_text(),
		"amount_text": amount_text()}
