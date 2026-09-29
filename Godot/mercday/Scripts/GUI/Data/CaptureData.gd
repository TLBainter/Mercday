class_name CaptureData extends RefCounted

#One merc held at a location. sentence_days is the time the sentence runs and previous_bail keeps
#the figure a failed break out raised.

var id: int = 0
var merc_uid: int = 0
var location_id: int = 0
var crime: String = ""
var contract_id: int = 0
var day_captured: int = 0
var sentence_days: int = 0
var bail: int = 0
var unread: bool = false
var previous_bail: int = 0
var note: String = ""


static func from_dict(d: Dictionary) -> CaptureData:
	var cap := CaptureData.new()
	cap.id = int(d.get("id", 0))
	cap.merc_uid = int(d.get("merc_uid", 0))
	cap.location_id = int(d.get("location_id", 0))
	cap.crime = str(d.get("crime", ""))
	cap.contract_id = int(d.get("contract_id", 0))
	cap.day_captured = int(d.get("day_captured", 0))
	cap.sentence_days = int(d.get("sentence_days", 0))
	cap.bail = int(d.get("bail", 0))
	cap.unread = bool(d.get("unread", false))
	cap.previous_bail = int(d.get("previous_bail", 0))
	cap.note = str(d.get("note", ""))
	return cap


func to_dict() -> Dictionary:
	return {"id": id, "merc_uid": merc_uid, "location_id": location_id, "crime": crime,
		"contract_id": contract_id, "day_captured": day_captured,
		"sentence_days": sentence_days, "bail": bail, "unread": unread,
		"previous_bail": previous_bail, "note": note}


#Days already served by a day index.
func served(day_index: int) -> int:
	return maxi(0, day_index - day_captured)


#Days left of the sentence by a day index.
func remaining(day_index: int) -> int:
	return maxi(0, sentence_days - served(day_index))
