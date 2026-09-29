class_name CampaignTypeDefs

#The five ad campaign types of DATA_DELTA I3, one row each, so no screen branches per type. Word
#of Mouth carries no daily price: its crew is paid as an Odd Job, so per_day stays 0 and cost()
#reads the crew instead. gate names the SubscriptionManager entitlement key that unlocks the type,
#guild_only keeps a type off the Job Ads tab, picks names the single extra choice the builder asks
#for, effect is the base effectiveness percentage the Effect column shows, no_loc lists the
#locations the type cannot reach, one_loc marks a type that takes a single location and refund
#says whether ending the campaign hands notes back. UNITS holds the duration units the builder
#offers, each with the smallest maxPromoDays cap that unlocks it.

const MIN_DAYS: int = 1
#A fixed run never passes thirty days; anything longer is an Infinite campaign, billed monthly.
const MAX_DAYS: int = 30
#One Infinite bill covers thirty days.
const BILL_DAYS: int = 30
const PICK_COMPANY: String = "company"
const PICK_COMPANY_OR_EVENT: String = "company_or_event"
const UNIT_DAYS: StringName = &"days"
const UNIT_WEEKS: StringName = &"weeks"
const UNIT_MONTHS: StringName = &"months"
const UNIT_INFINITE: StringName = &"infinite"
#The maxPromoDays value that stands for no limit. It mirrors
#SubscriptionManager.PROMO_DAYS_INFINITE, which GuiPromoTests ties to this constant.
const INFINITE_CAP: int = 1000000
#The effect of a type whose pull rides on the crew sent rather than on a percentage.
const VARIES: float = -1.0
const CAP_KEY: String = "maxPromoDays"
const BOOST_KEY: String = "adBoost"
const LONG_PROMOS_ID: String = "longpromos"
const LONG_PROMOS_TIERS: int = 5

#PLACEHOLDER
#Prices, quality stars, the effect percentages and the nine location names are the handoff's own
#placeholder numbers.
const TYPES: Array[Dictionary] = [
	{"key": &"wom", "name": "Word of Mouth", "stars": 1, "per_day": 0, "gate": "oddJobs",
		"guild_only": false, "picks": "", "icon": "wom",
		"desc": "Odd Job, pay your mercs", "effect": VARIES, "no_loc": [], "one_loc": false,
		"refund": false, "upgrade_id": "oddjobs", "upgrade_tier": 1, "upgrade_tiers": 3},
	{"key": &"flyers", "name": "Flyers", "stars": 2, "per_day": 5, "gate": "promotions",
		"guild_only": false, "picks": "", "icon": "flyers",
		"desc": "5 notes / day", "effect": 2.0, "no_loc": [], "one_loc": false,
		"refund": true, "upgrade_id": "promotions", "upgrade_tier": 1, "upgrade_tiers": 1},
	{"key": &"direct", "name": "Direct Sale", "stars": 3, "per_day": 40, "gate": "adDirect",
		"guild_only": true, "picks": PICK_COMPANY, "icon": "direct_sale",
		"desc": "40 notes / day, Guild Promo only", "effect": 9.0, "no_loc": [],
		"one_loc": false, "refund": true, "upgrade_id": "promomethods", "upgrade_tier": 1,
		"upgrade_tiers": 3},
	{"key": &"radio", "name": "Radio", "stars": 4, "per_day": 80, "gate": "adRadio",
		"guild_only": false, "picks": "", "icon": "radio",
		"desc": "80 notes / day", "effect": 12.0, "no_loc": [0, 4, 7], "one_loc": false,
		"refund": true, "upgrade_id": "promomethods", "upgrade_tier": 2, "upgrade_tiers": 3},
	{"key": &"sponsor", "name": "Sponsorship", "stars": 5, "per_day": 250, "gate": "adSponsor",
		"guild_only": false, "picks": PICK_COMPANY_OR_EVENT, "icon": "sponsorship",
		"desc": "250 notes / day, one sponsor", "effect": 15.0, "no_loc": [], "one_loc": true,
		"refund": true, "upgrade_id": "promomethods", "upgrade_tier": 3, "upgrade_tiers": 3},
]

#The nine places a campaign can reach, in the handoff order: a no_loc index reads off this list.
const LOCATIONS: Array[String] = ["Buern", "Aerdis", "Aldurstein", "Zukei", "Rossade", "Copari",
	"Miliim", "Vaernebo", "Cyfrolaef"]

#The duration units, shortest first. min_cap is the smallest maxPromoDays that unlocks the unit,
#so the Long Promos cap table [5, 10, 17, 25, 30, INFINITE_CAP] carries the tier gates.
const UNITS: Array[Dictionary] = [
	{"key": UNIT_DAYS, "name": "Days", "days": 1, "min_cap": 0, "upgrade_id": LONG_PROMOS_ID,
		"upgrade_tier": 0, "upgrade_tiers": LONG_PROMOS_TIERS},
	{"key": UNIT_WEEKS, "name": "Weeks", "days": 7, "min_cap": 10, "upgrade_id": LONG_PROMOS_ID,
		"upgrade_tier": 1, "upgrade_tiers": LONG_PROMOS_TIERS},
	{"key": UNIT_MONTHS, "name": "Months", "days": 30, "min_cap": 30,
		"upgrade_id": LONG_PROMOS_ID, "upgrade_tier": 4, "upgrade_tiers": LONG_PROMOS_TIERS},
	{"key": UNIT_INFINITE, "name": "Infinite", "days": 0, "min_cap": INFINITE_CAP,
		"upgrade_id": LONG_PROMOS_ID, "upgrade_tier": 5, "upgrade_tiers": LONG_PROMOS_TIERS},
]


static func find(key: StringName) -> Dictionary:
	for row: Dictionary in TYPES:
		if StringName(row["key"]) == key:
			return row
	return {}


static func keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in TYPES:
		out.append(StringName(row["key"]))
	return out


#True when the entitlement the type names is held: a tier key counts from 1, a flag from true.
static func unlocked(key: StringName, ent: Dictionary) -> bool:
	var row: Dictionary = find(key)
	if row.is_empty():
		return false
	return gate_met(ent, String(row["gate"]))


static func gate_met(ent: Dictionary, gate: String) -> bool:
	if gate == "":
		return true
	var value: Variant = ent.get(gate, false)
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return float(value) >= 1.0
	return String(value) != ""


#How effective the type reads once the Marketing Agency boost is in, to one decimal. VARIES comes
#back for a type whose pull rides on the crew sent.
static func effect_value(key: StringName, ent: Dictionary) -> float:
	var row: Dictionary = find(key)
	if row.is_empty():
		return VARIES
	var base: float = float(row["effect"])
	if base < 0.0:
		return VARIES
	return roundf(base * (1.0 + number_of(ent, BOOST_KEY) / 100.0) * 10.0) / 10.0


static func effect_text(key: StringName, ent: Dictionary) -> String:
	var value: float = effect_value(key, ent)
	if value < 0.0:
		return "Varies"
	if is_equal_approx(value, roundf(value)):
		return "%d%%" % roundi(value)
	return "%.1f%%" % value


#A numeric entitlement, with a flag counting one and anything else nothing.
static func number_of(ent: Dictionary, key: String) -> float:
	var value: Variant = ent.get(key, 0)
	if value is bool:
		return 1.0 if bool(value) else 0.0
	if value is int or value is float:
		return float(value)
	return 0.0


static func cap_of(ent: Dictionary) -> int:
	return int(number_of(ent, CAP_KEY))


#Keeps a location pick valid for the type: the places it cannot reach go, and a one_loc type
#keeps the first pick alone.
static func fit_locations(key: StringName, locations: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for index: int in locations:
		if location_allowed(key, index):
			out.append(index)
	var row: Dictionary = find(key)
	if bool(row.get("one_loc", false)) and out.size() > 1:
		out.resize(1)
	return out


static func location_allowed(key: StringName, index: int) -> bool:
	var row: Dictionary = find(key)
	if row.is_empty() or index < 0 or index >= LOCATIONS.size():
		return false
	return not (row["no_loc"] as Array).has(index)


static func location_name(index: int) -> String:
	if index < 0 or index >= LOCATIONS.size():
		return ""
	return LOCATIONS[index]


static func unit_of(unit_key: StringName) -> Dictionary:
	for row: Dictionary in UNITS:
		if StringName(row["key"]) == unit_key:
			return row
	return {}


static func unit_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for row: Dictionary in UNITS:
		out.append(StringName(row["key"]))
	return out


#A unit opens once the duration cap reaches its min_cap, and no unit opens without a cap at all.
static func unit_unlocked(unit_key: StringName, ent: Dictionary) -> bool:
	var unit: Dictionary = unit_of(unit_key)
	if unit.is_empty():
		return false
	return cap_of(ent) >= maxi(1, int(unit["min_cap"]))


#How many of the unit a fixed run may hold. Infinite takes no quantity, so it answers nothing.
static func unit_qty_max(unit_key: StringName, ent: Dictionary) -> int:
	var unit: Dictionary = unit_of(unit_key)
	if unit.is_empty():
		return 0
	var span: int = int(unit["days"])
	if span <= 0:
		return 0
	return int(mini(cap_of(ent), MAX_DAYS) / float(span))


static func days_of(unit_key: StringName, qty: int) -> int:
	var unit: Dictionary = unit_of(unit_key)
	if unit.is_empty():
		return 0
	return int(unit["days"]) * maxi(0, qty)


#What a fixed campaign costs up front: the daily price over its days, or its crew's Odd Job pay.
static func cost(key: StringName, days: int, crew_size: int = 0, pay_per: int = 0) -> int:
	var row: Dictionary = find(key)
	if row.is_empty():
		return 0
	var per_day: int = int(row["per_day"])
	if per_day <= 0:
		return maxi(0, crew_size) * maxi(0, pay_per)
	return per_day * maxi(0, days)


#What one Infinite bill comes to.
static func monthly_cost(key: StringName) -> int:
	var row: Dictionary = find(key)
	if row.is_empty():
		return 0
	return int(row["per_day"]) * BILL_DAYS


#True when the type is paid as an Odd Job crew rather than by the day.
static func is_crew_paid(key: StringName) -> bool:
	var row: Dictionary = find(key)
	return not row.is_empty() and int(row["per_day"]) <= 0
