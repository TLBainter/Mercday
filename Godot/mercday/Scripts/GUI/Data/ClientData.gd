class_name ClientData
extends RefCounted
#One client of the guild, derived from the contract board until a real issuer system exists.

var kind: StringName = &"people"
var index: int = 0
var name: String = ""
var kind_label: String = "Person"
var sub: String = ""
var location: String = ""
var km: int = 0
var relationship: int = 0
var about: String = ""
var offered: int = 0
var accepted: int = 0
var succeeded: int = 0
var failed: int = 0
var paid: int = 0
var avg_difficulty: float = 0.0
var recency: int = -1
var recent: Array[Dictionary] = []

func key() -> String:
	return "%s:%d" % [String(kind), index]

func kind_line() -> String:
	if sub.is_empty():
		return kind_label
	return "%s - %s" % [kind_label, sub]

func where_text() -> String:
	if location.is_empty():
		return "%d km away" % km
	return "%s - %d km away" % [location, km]

static func recent_row(entry_id: int, entry_name: String, result: String, color: Color,
		listed: bool) -> Dictionary:
	return {
		"entry_id": entry_id,
		"name": entry_name,
		"result": result,
		"color": color,
		"listed": listed,
	}
