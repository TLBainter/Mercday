class_name OddJobData extends RefCounted

#One Odd Job running against a fine or a capture. target_kind is &"fine" or &"capture", kind
#is &"renegotiate" or &"breakout", team holds merc uids and pay_per is what each was paid.

var id: int = 0
var target_kind: StringName = &""
var target_id: int = 0
var kind: StringName = &""
var team: Array[int] = []
var pay_per: int = 0
var day_started: int = 0
var days: int = 0
var odds: int = 0


static func from_dict(d: Dictionary) -> OddJobData:
	var job := OddJobData.new()
	job.id = int(d.get("id", 0))
	job.target_kind = StringName(d.get("target_kind", ""))
	job.target_id = int(d.get("target_id", 0))
	job.kind = StringName(d.get("kind", ""))
	job.team.assign(d.get("team", []))
	job.pay_per = int(d.get("pay_per", 0))
	job.day_started = int(d.get("day_started", 0))
	job.days = int(d.get("days", 0))
	job.odds = int(d.get("odds", 0))
	return job


func to_dict() -> Dictionary:
	return {"id": id, "target_kind": String(target_kind), "target_id": target_id,
		"kind": String(kind), "team": team.duplicate(), "pay_per": pay_per,
		"day_started": day_started, "days": days, "odds": odds}


#What the crew cost up front.
func total_pay() -> int:
	return pay_per * team.size()
