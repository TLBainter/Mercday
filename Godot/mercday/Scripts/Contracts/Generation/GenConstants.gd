class_name GenConstants
#Tunable numbers of the daily contract round, the pool and the generation steps.

#Likelihood of a posting per round.
static var LIKELY_BASE: float = 0.60
static var LIKELY_SLOPE: float = 0.30
static var LIKELY_MIN: float = 0.30
static var LIKELY_MAX: float = 0.90
static var CHAIN_DECAY: float = 0.50

static var STORY_INTERVAL_DAYS: int = 10

#Promo campaign rolls.
static var PROMO_CHANCE_SCALE: float = 1.0
static var PROMO_CHAIN_DECAY: float = 0.75
static var PROMO_CHANCE_CAP: float = 0.95

static var ISSUER_MIN_WEIGHT: float = 0.05
static var ISSUER_GROUP_BASE: float = 0.5

#Contract level from the roster.
static var LEVEL_W_ALL: float = 0.5
static var LEVEL_W_AVAILABLE: float = 0.3
static var LEVEL_W_RESTING: float = 0.2
static var LEVEL_LO: float = 0.75
static var LEVEL_HI: float = 1.25
static var LEVEL_CAP: int = 40

static var DIFF_CENTRE: float = 2.75
static var DIFF_SLOPE: float = 1.5
static var DIFF_MIN: float = 0.5
static var DIFF_MAX: float = 5.0
static var DIFF_SNAP: float = 0.5

static var MATCH_BASE: float = 0.50
static var MATCH_SLOPE: float = 0.40
static var MATCH_MIN: float = 0.10
static var MATCH_MAX: float = 0.90

static var TYPE_REPEAT_FACTOR: float = 0.25
static var BALANCE_SHARE: float = 0.5
static var LONG_HOURS: int = 20
static var NEAR_KM: int = 40
static var FAR_KM: int = 80

#Distance from the guild by country name.
const DISTANCE_KM: Dictionary = {
	"Buern": 10, "Aerdis": 25, "Aldurstein": 40, "Zukei": 55, "Rossade": 70, "Copari": 85,
	"Miliim": 100, "Vaernebo": 115, "Cyfrolaef": 120, "Kathaya": 130, "Suorr": 140, "Kahfald": 150, "Cipex": 160,
}
static var DISTANCE_JITTER: float = 0.2
const GUILD_HOME: String = "Buern"

#Travel mode by contract level; "mode" holds a Reachability.MODES key.
const EXPENSE_TIERS: Array[Dictionary] = [
	{"max_level": 9, "mode": "foot"},
	{"max_level": 19, "mode": "caravan"},
	{"max_level": 29, "mode": "horse"},
	{"max_level": 39, "mode": "train"},
	{"max_level": 999, "mode": "airship"},
]
static var TRAVEL_ADD_LO: float = 0.25
static var TRAVEL_ADD_HI: float = 1.75

static var QUALITY_W_NEAR: float = 0.30
static var QUALITY_W_SHORT: float = 0.20
static var QUALITY_W_GENEROUS: float = 0.20
static var QUALITY_W_MATCH: float = 0.30
static var QUALITY_KM_SPAN: float = 120.0
static var QUALITY_HOURS_SPAN: float = 40.0
static var QUALITY_MATCH_FULL: float = 3.0
static var PROMO_QUALITY_LIFT: float = 0.75

#Contract value: (level, value) anchors, point weights and the normaliser's mean inputs.
const VALUE_ANCHORS: Array[Vector2] = [
	Vector2(1, 10), Vector2(10, 50), Vector2(20, 75), Vector2(25, 100), Vector2(30, 250), Vector2(35, 275),
	Vector2(40, 500),
]
static var CSAT_POINTS: float = 1.0
static var TIME_POINTS_PER_8H: float = 2.0
static var URGENCY_POINTS: float = 3.0
static var EXPENSE_WEIGHT: float = 1.0
static var VALUE_MEAN_FACE: int = 0
static var VALUE_MEAN_DIFFICULTY: float = 2.75
static var VALUE_MEAN_HOURS: float = 8.0
static var VALUE_MEAN_URGENCY: float = 0.5
static var VALUE_MEAN_KM: int = 70
static var VALUE_MEAN_TEAM: int = 2
static var QUALITY_MULT_LO: float = 0.75
static var QUALITY_MULT_HI: float = 1.25
static var VALUE_TRIM: float = 1.0

#Rejects and deadlines.
static var REJECT_VALUE_STEP: float = 22.5
static var SLACK_LO: float = 0.10
static var SLACK_HI: float = 1.00
static var SLACK_OPINION_H: int = 4
static var DEADLINE_MIN_H: int = 12
static var URGENT_H: int = 24
static var SOON_H: int = 48
