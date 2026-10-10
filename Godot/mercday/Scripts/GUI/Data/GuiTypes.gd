class_name GuiTypes

#Enums, tables and color ramps every GUI scene reads. ROLES adds Investigator to the sample_data.json roles.
#Difficulty and match keys are the half steps themselves; 0.5 to 5.0 are exact in binary.

enum MercStatus {AVAILABLE, RESTING, CONTRACT, VACATION, LOAN, DEAD, FIRED, MISSING, CAPTURED,
	ODD_JOB, PREPARING, DEFECTED}
enum ContractStatus {AVAILABLE, ACTIVE, EXPIRED, COMPLETED, REJECTED, FAILED}
enum Urgency {NONE, LOW, HIGH}

const ROLES: Array[String] = ["Leader", "Support", "Driver", "Assassin", "Guide", "Escort", "Investigator"]

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
	"Brave": GuiColors.LIGHT_BLUE, "Chymist": GuiColors.GREEN, "Divine": GuiColors.RAMP_YELLOW,
	"Hellion": Color("#a36ce8"), "Honorable": GuiColors.ORANGE, "Mage": Color("#a8385a"),
	"Mystech": Color("#3fc9c0"), "Performer": Color("#f07ab8"), "Sorcerer": GuiColors.RED,
	"Warrior": GuiColors.GRAY,
}

const DIFFICULTY_NAMES: Dictionary = {
	0.5: "Cakewalk", 1.0: "Very Easy", 1.5: "Easy", 2.0: "Straightforward", 2.5: "Manageable",
	3.0: "Average", 3.5: "Challenging", 4.0: "Hard", 4.5: "Tough", 5.0: "Impossible",
}

const DIFFICULTY_COLORS: Dictionary = {
	0.5: GuiColors.DEEP_GREEN, 1.0: GuiColors.GREEN, 1.5: GuiColors.SEA_GREEN, 2.0: GuiColors.TEAL,
	2.5: GuiColors.LIGHT_BLUE, 3.0: GuiColors.AMBER, 3.5: GuiColors.LIGHT_ORANGE, 4.0: GuiColors.ORANGE,
	4.5: GuiColors.RED_ORANGE, 5.0: GuiColors.RED,
}

const MATCH_COLORS: Dictionary = {
	0.5: GuiColors.RED, 1.0: GuiColors.RED_ORANGE, 1.5: GuiColors.DARK_ORANGE, 2.0: GuiColors.ORANGE,
	2.5: GuiColors.LIGHT_ORANGE, 3.0: GuiColors.AMBER, 3.5: GuiColors.LIGHT_BLUE, 4.0: GuiColors.TEAL,
	4.5: GuiColors.SEA_GREEN, 5.0: GuiColors.DEEP_GREEN,
}

const STATUS_COLORS: Dictionary = {
	ContractStatus.AVAILABLE: GuiColors.GREEN, ContractStatus.ACTIVE: GuiColors.LIGHT_BLUE,
	ContractStatus.EXPIRED: GuiColors.RED, ContractStatus.COMPLETED: GuiColors.AMBER,
	ContractStatus.REJECTED: GuiColors.GRAY, ContractStatus.FAILED: GuiColors.RED,
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
	MercStatus.ODD_JOB: "On an Odd Job", MercStatus.PREPARING: "Preparing",
	MercStatus.DEFECTED: "Defected",
}

#AVAILABLE reads green, DEAD, FIRED and DEFECTED read red, LOAN and ODD_JOB read amber, the rest neutral.
const MERC_STATUS_COLORS: Dictionary = {
	MercStatus.AVAILABLE: GuiColors.GREEN, MercStatus.RESTING: GuiColors.CREAM,
	MercStatus.CONTRACT: GuiColors.CREAM, MercStatus.VACATION: GuiColors.CREAM,
	MercStatus.LOAN: GuiColors.AMBER, MercStatus.DEAD: GuiColors.RED,
	MercStatus.FIRED: GuiColors.RED, MercStatus.MISSING: GuiColors.CREAM,
	MercStatus.CAPTURED: GuiColors.CREAM, MercStatus.ODD_JOB: GuiColors.AMBER,
	MercStatus.PREPARING: GuiColors.CREAM, MercStatus.DEFECTED: GuiColors.RED,
}

#Statuses still holding a roster place; DEAD, DEFECTED and FIRED have left it.
const ROSTER_STATUSES: Array[int] = [MercStatus.AVAILABLE, MercStatus.PREPARING, MercStatus.CONTRACT,
	MercStatus.RESTING, MercStatus.CAPTURED, MercStatus.MISSING, MercStatus.VACATION, MercStatus.LOAN,
	MercStatus.ODD_JOB]

#Status badges that never change colour; every other badge reads the ramp off the time left.
const BADGE_FIXED_COLORS: Dictionary = {
	MercStatus.CAPTURED: GuiColors.ORANGE, MercStatus.DEAD: GuiColors.RED,
	MercStatus.DEFECTED: GuiColors.RED,
}
#Badges that run red to green as their time runs out; the rest run green to red.
const BADGE_RISING: Array[int] = [MercStatus.CONTRACT, MercStatus.RESTING, MercStatus.VACATION]
const BADGE_UNKNOWN_FRACTION: float = 0.5
#The atlas art of each portrait badge; a status missing here (Available, Loan, Odd Job, Fired) shows none.
const BADGE_IDS: Dictionary = {
	MercStatus.PREPARING: "status_preparing", MercStatus.CONTRACT: "status_contract",
	MercStatus.RESTING: "status_resting", MercStatus.CAPTURED: "status_captured",
	MercStatus.DEAD: "status_dead", MercStatus.DEFECTED: "status_defected",
	MercStatus.MISSING: "status_missing", MercStatus.VACATION: "status_vacation",
}

#The ramp runs green at None, orange at Low and red at High (C7).
const URGENCY_COLORS: Dictionary = {
	Urgency.NONE: GuiColors.GREEN, Urgency.LOW: GuiColors.ORANGE, Urgency.HIGH: GuiColors.RED,
}

const URGENCY_NAMES: Dictionary = {
	Urgency.NONE: "None", Urgency.LOW: "Low", Urgency.HIGH: "High",
}

const FALLBACK_COLOR: Color = GuiColors.GRAY

#Success odds bands of DATA.md, highest floor first; the meter and the odds tooltip read them.
const ODDS_COLORS: Array[Dictionary] = [
	{"min": 85, "color": GuiColors.DEEP_GREEN}, {"min": 70, "color": GuiColors.GREEN},
	{"min": 55, "color": GuiColors.LIGHT_BLUE}, {"min": 45, "color": GuiColors.AMBER},
	{"min": 25, "color": GuiColors.ORANGE}, {"min": 0, "color": GuiColors.RED},
]


#The nearest half step from 0.5 to 5.0; a value outside that range clamps to the nearest end.
static func snap_half(v: float) -> float:
	return clampf(roundf(v * 2.0) / 2.0, 0.5, 5.0)


#The nearest authored half step of a difficulty.
static func snap_difficulty(d: float) -> float:
	return snap_half(d)


static func difficulty_color(d: float) -> Color:
	return DIFFICULTY_COLORS.get(snap_difficulty(d), FALLBACK_COLOR)


static func difficulty_name(d: float) -> String:
	return String(DIFFICULTY_NAMES.get(snap_difficulty(d), ""))


static func match_color(stars: float) -> Color:
	return MATCH_COLORS.get(snap_half(stars), FALLBACK_COLOR)


static func status_color(status: int) -> Color:
	return STATUS_COLORS.get(status, FALLBACK_COLOR)


static func status_text(status: int) -> String:
	return String(STATUS_NAMES.get(status, ""))


static func merc_status_text(status: int) -> String:
	return String(MERC_STATUS_NAMES.get(status, ""))


static func merc_status_color(status: int) -> Color:
	return MERC_STATUS_COLORS.get(status, FALLBACK_COLOR)


static func counts_toward_roster(status: int) -> bool:
	return ROSTER_STATUSES.has(status)


static func badge_id(status: int) -> String:
	return String(BADGE_IDS.get(status, ""))


#The badge tint off the fraction of the status time left (1 just began, 0 over); under 0 is unknown.
static func badge_color(status: int, fraction_left: float) -> Color:
	if BADGE_FIXED_COLORS.has(status):
		return BADGE_FIXED_COLORS[status]
	if fraction_left < 0.0:
		return GuiColors.ramp_color(BADGE_UNKNOWN_FRACTION)
	if BADGE_RISING.has(status):
		return GuiColors.ramp_color(1.0 - fraction_left)
	return GuiColors.ramp_color(fraction_left)


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
