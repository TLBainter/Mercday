class_name GuiTypes

#Enums, tables and color ramps every GUI scene reads. The tables are the sample_data.json rows.
#Difficulty and match keys are the half steps themselves; 0.5 to 5.0 are exact in binary.

enum MercStatus {AVAILABLE, RESTING, CONTRACT, VACATION, LOAN, DEAD, FIRED, MISSING, CAPTURED,
	ODD_JOB}
enum ContractStatus {AVAILABLE, ACTIVE, EXPIRED, COMPLETED, REJECTED, FAILED}
enum Urgency {NONE, LOW, HIGH}

const ROLES: Array[String] = ["Leader", "Support", "Driver", "Assassin", "Guide", "Escort"]

#km_per_day 0 means the trip takes no time; per_merc multiplies the cost by the team size.
const TRAVEL_MODES: Array[Dictionary] = [
	{"key": "foot", "label": "Foot", "full": "On Foot", "km_per_day": 30, "rate": 1,
		"per_km": 25, "per_merc": true},
	{"key": "caravan", "label": "Caravan", "full": "By Caravan", "km_per_day": 45, "rate": 7,
		"per_km": 25, "per_merc": false},
	{"key": "horse", "label": "Horse", "full": "By Horse", "km_per_day": 120, "rate": 5,
		"per_km": 25, "per_merc": true},
	{"key": "train", "label": "Train", "full": "By Train", "km_per_day": 250, "rate": 25,
		"per_km": 25, "per_merc": true},
	{"key": "airship", "label": "Airship", "full": "By Airship", "km_per_day": 300, "rate": 35,
		"per_km": 25, "per_merc": true},
	{"key": "teleport", "label": "Teleport", "full": "By Teleportation", "km_per_day": 0,
		"rate": 50, "per_km": 10, "per_merc": true},
]

const TRADITION_COLORS: Dictionary = {
	"Brave": Color("#5aa6e8"), "Chymist": Color("#6cc36a"), "Divine": Color("#f2d33d"),
	"Hellion": Color("#a36ce8"), "Honorable": Color("#f28c28"), "Mage": Color("#a8385a"),
	"Mystech": Color("#3fc9c0"), "Performer": Color("#f07ab8"), "Sorcerer": Color("#e8583f"),
	"Warrior": Color("#a0a8b8"),
}

const DIFFICULTY_NAMES: Dictionary = {
	0.5: "Cakewalk", 1.0: "Very Easy", 1.5: "Easy", 2.0: "Straightforward", 2.5: "Manageable",
	3.0: "Average", 3.5: "Challenging", 4.0: "Hard", 4.5: "Tough", 5.0: "Impossible",
}

const DIFFICULTY_COLORS: Dictionary = {
	0.5: Color("#3fae5a"), 1.0: Color("#6cc36a"), 1.5: Color("#64b98c"), 2.0: Color("#5fb0b8"),
	2.5: Color("#5aa6e8"), 3.0: Color("#f2b33d"), 3.5: Color("#f2a033"), 4.0: Color("#f28c28"),
	4.5: Color("#ec6a36"), 5.0: Color("#e8583f"),
}

const MATCH_COLORS: Dictionary = {
	0.5: Color("#e8583f"), 1.0: Color("#ec6a36"), 1.5: Color("#ef7c2f"), 2.0: Color("#f28c28"),
	2.5: Color("#f2a033"), 3.0: Color("#f2b33d"), 3.5: Color("#5aa6e8"), 4.0: Color("#5fb0b8"),
	4.5: Color("#64b98c"), 5.0: Color("#3fae5a"),
}

const STATUS_COLORS: Dictionary = {
	ContractStatus.AVAILABLE: Color("#6cc36a"), ContractStatus.ACTIVE: Color("#5aa6e8"),
	ContractStatus.EXPIRED: Color("#e8583f"), ContractStatus.COMPLETED: Color("#f2b33d"),
	ContractStatus.REJECTED: Color("#a0a8b8"), ContractStatus.FAILED: Color("#e8583f"),
}

const STATUS_NAMES: Dictionary = {
	ContractStatus.AVAILABLE: "Available", ContractStatus.ACTIVE: "Active",
	ContractStatus.EXPIRED: "Expired", ContractStatus.COMPLETED: "Completed",
	ContractStatus.REJECTED: "Rejected", ContractStatus.FAILED: "Failed",
}

const MERC_STATUS_NAMES: Dictionary = {
	MercStatus.AVAILABLE: "Available", MercStatus.RESTING: "Resting",
	MercStatus.CONTRACT: "On a Contract", MercStatus.VACATION: "On Vacation",
	MercStatus.LOAN: "Pursuing a Loan", MercStatus.DEAD: "Dead", MercStatus.FIRED: "Fired",
	MercStatus.MISSING: "Missing", MercStatus.CAPTURED: "Captured",
	MercStatus.ODD_JOB: "On an Odd Job",
}

#AVAILABLE reads green, DEAD and FIRED read red, LOAN and ODD_JOB read amber, the rest neutral.
const MERC_STATUS_COLORS: Dictionary = {
	MercStatus.AVAILABLE: Color("#6cc36a"), MercStatus.RESTING: Color("#f3ead7"),
	MercStatus.CONTRACT: Color("#f3ead7"), MercStatus.VACATION: Color("#f3ead7"),
	MercStatus.LOAN: Color("#f2b33d"), MercStatus.DEAD: Color("#e8583f"),
	MercStatus.FIRED: Color("#e8583f"), MercStatus.MISSING: Color("#f3ead7"),
	MercStatus.CAPTURED: Color("#f3ead7"), MercStatus.ODD_JOB: Color("#f2b33d"),
}

#The ramp runs green at None, orange at Low and red at High (C7).
const URGENCY_COLORS: Dictionary = {
	Urgency.NONE: Color("#6cc36a"), Urgency.LOW: Color("#f28c28"), Urgency.HIGH: Color("#e8583f"),
}

const URGENCY_NAMES: Dictionary = {
	Urgency.NONE: "None", Urgency.LOW: "Low", Urgency.HIGH: "High",
}

const FALLBACK_COLOR: Color = Color("#a0a8b8")

#Success odds bands of DATA.md, highest floor first; the meter and the odds tooltip read them.
const ODDS_COLORS: Array[Dictionary] = [
	{"min": 85, "color": Color("#3fae5a")}, {"min": 70, "color": Color("#6cc36a")},
	{"min": 55, "color": Color("#5aa6e8")}, {"min": 45, "color": Color("#f2b33d")},
	{"min": 25, "color": Color("#f28c28")}, {"min": 0, "color": Color("#e8583f")},
]


#The nearest authored half step; a difficulty outside 0.5 to 5.0 clamps to the nearest end.
static func snap_difficulty(d: float) -> float:
	return clampf(roundf(d * 2.0) / 2.0, 0.5, 5.0)


static func difficulty_color(d: float) -> Color:
	return DIFFICULTY_COLORS.get(snap_difficulty(d), FALLBACK_COLOR)


static func difficulty_name(d: float) -> String:
	return String(DIFFICULTY_NAMES.get(snap_difficulty(d), ""))


static func match_color(stars: float) -> Color:
	return MATCH_COLORS.get(clampf(roundf(stars * 2.0) / 2.0, 0.5, 5.0), FALLBACK_COLOR)


static func status_color(status: int) -> Color:
	return STATUS_COLORS.get(status, FALLBACK_COLOR)


static func status_text(status: int) -> String:
	return String(STATUS_NAMES.get(status, ""))


static func merc_status_text(status: int) -> String:
	return String(MERC_STATUS_NAMES.get(status, ""))


static func merc_status_color(status: int) -> Color:
	return MERC_STATUS_COLORS.get(status, FALLBACK_COLOR)


static func urgency_color(urgency: int) -> Color:
	return URGENCY_COLORS.get(urgency, FALLBACK_COLOR)


static func tradition_color(tradition: String) -> Color:
	return TRADITION_COLORS.get(tradition, FALLBACK_COLOR)


static func travel_mode(key: String) -> Dictionary:
	for mode: Dictionary in TRAVEL_MODES:
		if String(mode["key"]) == key:
			return mode
	return {}


static func odds_color(odds: int) -> Color:
	for band: Dictionary in ODDS_COLORS:
		if odds >= int(band["min"]):
			return band["color"]
	return FALLBACK_COLOR
