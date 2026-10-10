class_name SimThresholds
#Every policy and threshold number of the playability sim (proposal section 9, PLAN_G 3.3).

const DEFAULT_DAYS: int = 120
const DEFAULT_SEED: int = 7
#Clock ticks allowed to reach the next 8:00; a day takes about a dozen at the fastest speed.
const DAY_TICK_GUARD: int = 64
#The weekday the verdict and report row of the week just ended land on (Ansday).
const VERDICT_WEEKDAY: int = 1

const DISPATCH_P: float = 0.50
const HIRE_BANK_FACTOR: int = 3
const TIER_BANK_FACTOR: int = 3
const PLAN_BANK_FACTOR: int = 3
const TIER_IDS: Array[String] = ["contracts", "seats"]

const BANK_FLOOR: int = 0
const GEN_MIN_PER_WEEK: int = 3
const ROSTER_EMPTY_MAX_DAYS: int = 3
const SUCCESS_LO: float = 0.50
const SUCCESS_HI: float = 0.70
const SUCCESS_MIN_SETTLED: int = 10
const MERCS_BY_DAY: int = 60
const MERCS_TARGET: int = 5
const BAND_TOLERANCE: float = 0.15
const BAND_MIN_SAMPLES: int = 5
#Level bands of the value table as [low, high]; the last band holds every level from its low up.
const BANDS: Array[Vector2i] = [Vector2i(1, 9), Vector2i(10, 19), Vector2i(20, 24), Vector2i(25, 29),
	Vector2i(30, 34), Vector2i(35, 39), Vector2i(40, 40)]
