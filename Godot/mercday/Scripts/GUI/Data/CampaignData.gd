class_name CampaignData extends RefCounted

#One ad campaign, as the builder agreed it and the card reads it back. mode is "job" for the Job
#Ads tab and "promo" for Guild Ads. filters holds one entry per TraitFilterDefs key of the
#matching def list; the guild-only picks sit in their own fields so a card never digs through the
#filter dictionary. PromotionsManager stamps day_started, per_day and total_cost at launch and
#nothing else writes them. A campaign pays per_day for the days it runs: launch pays up to the first
#bill_day date, and each bill pays up to the next one or to the end of a fixed run, whichever is sooner.
#An infinite campaign holds no days and bills until the player ends it. results counts the arrivals no
#listed applicant stands for any more.

const MODE_JOB: String = "job"
const MODE_PROMO: String = "promo"
#Who a guild campaign speaks to; sponsor_target names the picked company or event.
const TO_EVERYONE: StringName = &"everyone"
const TO_COMPANY: StringName = &"company"
const TO_EVENT: StringName = &"event"
#No pick made yet, for sponsor_index.
const NO_PICK: int = -1

var id: int = -1
var name: String = ""
var type_key: StringName = &"flyers"
var mode: String = MODE_JOB
#The duration the builder agreed: unit_key and days together, with days 0 while infinite is on.
var unit_key: StringName = &"days"
var days: int = 30
var infinite: bool = false
var day_started: int = -1
var per_day: int = 0
var total_cost: int = 0
var filters: Dictionary = {}
var advertise_to: StringName = TO_EVERYONE
var sponsor_target: String = ""
var sponsor_index: int = NO_PICK
var advertise_targets: Array[int] = []
var difficulty_lo: float = 0.5
var difficulty_hi: float = 5.0
var contract_types: Array[String] = []
var locations: Array[int] = []
var crew: Array[int] = []
var pay_per: int = 0
#Arrivals this campaign already pulled that no live applicant stands for.
var results: int = 0
#The day the next placeholder applicant is due; -1 while nothing is due.
var next_arrival_day: int = -1
#The day the next bill falls due, which is also the last day the current bill paid for; -1 once a
#fixed run has paid through its end, or for a crew campaign.
var next_bill_day: int = -1
#The day of the month the campaign bills on, picked at launch; -1 for a crew campaign.
var bill_day: int = -1


#A campaign only carries an id once it has launched.
func is_launched() -> bool:
	return id >= 0


#How many days the campaign has been up, which is never negative.
func used(today: int) -> int:
	return maxi(0, today - day_started)


#Days to go. An infinite campaign answers the sentinel, so a sort reads it as the largest value.
func days_left(today: int) -> int:
	if infinite:
		return CampaignTypeDefs.INFINITE_CAP
	if not is_launched():
		return maxi(0, days)
	return maxi(0, day_started + days - today)


#A fixed campaign that has run out. An infinite one never concludes on its own.
func is_concluded(today: int) -> bool:
	return not infinite and is_launched() and days_left(today) <= 0


#The days that count towards its results: everything so far, but never past a fixed run.
func run_days(today: int) -> int:
	if infinite:
		return used(today)
	return mini(used(today), maxi(0, days))


#The days already paid for that the campaign has not spent yet: the rest of the period the current
#bill covers, or the rest of a fixed run that has paid through its end.
func unused_days(today: int) -> int:
	if per_day <= 0:
		return 0
	if next_bill_day >= 0:
		return maxi(0, next_bill_day - today)
	if infinite:
		return CampaignTypeDefs.BILL_DAYS - used(today) % CampaignTypeDefs.BILL_DAYS
	return maxi(0, days - used(today))


#The bill date after day: the same day of the next month, or BILL_DAYS on when no bill day is set.
func next_bill_after(day: int) -> int:
	if bill_day <= 0:
		return day + CampaignTypeDefs.BILL_DAYS
	return TrynnCalendar.next_day_on(day, bill_day)


#Where the period billed on from_day stops: the next bill date, or the end of a fixed run if sooner.
func period_end(from_day: int) -> int:
	var stop: int = next_bill_after(from_day)
	if not infinite:
		stop = mini(stop, end_day())
	return stop


#What the bill on from_day charges: per_day for every day up to period_end.
func period_cost(from_day: int) -> int:
	return per_day * maxi(0, period_end(from_day) - from_day)


#The bill that follows the one on from_day, or -1 when that period runs to the end of a fixed run.
func bill_after(from_day: int) -> int:
	var stop: int = period_end(from_day)
	if not infinite and stop >= end_day():
		return -1
	return stop


#What the campaign has cost so far. A crew campaign paid its mercs once, at launch.
func spent_so_far(today: int) -> int:
	if per_day <= 0:
		return crew.size() * maxi(0, pay_per)
	return per_day * run_days(today)


#What is left of the notes already committed, and so what ending the campaign hands back.
func budget_remaining(today: int) -> int:
	return per_day * unused_days(today)


func total_committed(today: int) -> int:
	return spent_so_far(today) + budget_remaining(today)


#How far through its run the campaign is. An infinite one always reads full.
func progress(today: int) -> float:
	if infinite:
		return 1.0
	if days <= 0 or not is_launched():
		return 1.0
	return clampf(float(used(today)) / float(days), 0.0, 1.0)


func end_day() -> int:
	return day_started + days


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "type_key": String(type_key), "mode": mode,
		"unit_key": String(unit_key), "days": days, "infinite": infinite,
		"day_started": day_started, "per_day": per_day, "total_cost": total_cost,
		"filters": filters.duplicate(true), "advertise_to": String(advertise_to),
		"sponsor_target": sponsor_target, "sponsor_index": sponsor_index,
		"advertise_targets": advertise_targets.duplicate(), "difficulty_lo": difficulty_lo,
		"difficulty_hi": difficulty_hi, "contract_types": contract_types.duplicate(),
		"locations": locations.duplicate(), "crew": crew.duplicate(), "pay_per": pay_per,
		"results": results, "next_arrival_day": next_arrival_day, "next_bill_day": next_bill_day,
		"bill_day": bill_day}


static func from_dict(d: Dictionary) -> CampaignData:
	var out := CampaignData.new()
	out.id = int(d.get("id", -1))
	out.name = String(d.get("name", ""))
	out.type_key = StringName(d.get("type_key", "flyers"))
	out.mode = String(d.get("mode", MODE_JOB))
	out.unit_key = StringName(d.get("unit_key", "days"))
	out.days = int(d.get("days", 30))
	out.infinite = bool(d.get("infinite", false))
	out.day_started = int(d.get("day_started", -1))
	out.per_day = int(d.get("per_day", 0))
	out.total_cost = int(d.get("total_cost", 0))
	out.filters = (d.get("filters", {}) as Dictionary).duplicate(true)
	out.advertise_to = StringName(d.get("advertise_to", TO_EVERYONE))
	out.sponsor_target = String(d.get("sponsor_target", ""))
	out.sponsor_index = int(d.get("sponsor_index", NO_PICK))
	out.advertise_targets.assign(d.get("advertise_targets", []))
	out.difficulty_lo = float(d.get("difficulty_lo", 0.5))
	out.difficulty_hi = float(d.get("difficulty_hi", 5.0))
	out.contract_types = type_names_of(d.get("contract_types", []))
	out.locations.assign(d.get("locations", []))
	out.crew.assign(d.get("crew", []))
	out.pay_per = int(d.get("pay_per", 0))
	out.results = int(d.get("results", 0))
	out.next_arrival_day = int(d.get("next_arrival_day", -1))
	out.next_bill_day = int(d.get("next_bill_day", -1))
	out.bill_day = int(d.get("bill_day", -1))
	return out


#An older dictionary stored indices into the sorted type list; they map once through the current list.
static func type_names_of(saved: Variant) -> Array[String]:
	var names: Array[String] = []
	if not (saved is Array):
		return names
	var known: Array[String] = ContractLibrary.contract_type_names()
	for entry: Variant in saved as Array:
		var type_name: String = ""
		if entry is int or (entry is float and float(entry) == roundf(float(entry))):
			var index: int = int(entry)
			if index >= 0 and index < known.size():
				type_name = known[index]
		elif entry is String or entry is StringName:
			type_name = String(entry)
		if type_name != "" and not names.has(type_name):
			names.append(type_name)
	return names
