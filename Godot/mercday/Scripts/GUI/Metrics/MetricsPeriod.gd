class_name MetricsPeriod

#Period and scale rules of the Metrics Viewer. They live apart from the scene so a suite can read
#them without a viewer. Day counts follow the game calendar (33 days a month, 330 days a year)
#instead of the prototype's 30 and 360.

enum Period {ALL_TIME, YTD, M6, Y1, Y3, Y5}
enum Scale {DAY, WEEK, MONTH, QUARTER}

const PERIOD_LABELS: Array[String] = ["All Time", "YTD", "6m", "1y", "3y", "5y"]
const PERIOD_KEYS: Array[String] = ["all", "ytd", "m6", "y1", "y3", "y5"]
const SCALE_LABELS: Array[String] = ["Days", "Weeks", "Months", "Quarters"]
const SCALE_KEYS: Array[String] = ["day", "week", "month", "quarter"]
#The chart names one bucket in the singular under its x axis.
const SCALE_SINGULAR: Array[String] = ["Day", "Week", "Month", "Quarter"]

#The bucket sizes mirror the DAYS_PER_ consts of MetricsHistory; a suite case checks they match.
const WEEK_DAYS: int = 10
const MONTH_DAYS: int = 33
const QUARTER_DAYS: int = 99
const BUCKET_DAYS: Array[int] = [1, WEEK_DAYS, MONTH_DAYS, QUARTER_DAYS]

const YEAR_DAYS: int = TrynnCalendar.DAYS_PER_YEAR
const HALF_YEAR: int = 6 * MONTH_DAYS

const REASON_DAY: String = "Days need a period of 6m or less"
const REASON_WEEK: String = "Weeks need a period of 1y or less"
const REASON_MONTH: String = "Months need a period of 6m or more"
const REASON_QUARTER: String = "Quarters need a period of 1y or more"
const REASONS: Array[String] = [REASON_DAY, REASON_WEEK, REASON_MONTH, REASON_QUARTER]


#A day count of -1 stands for the whole record: All Time has no length of its own.
static func period_days(period: int, today: int) -> int:
	match period:
		Period.YTD:
			return year_day(today)
		Period.M6:
			return HALF_YEAR
		Period.Y1:
			return YEAR_DAYS
		Period.Y3:
			return 3 * YEAR_DAYS
		Period.Y5:
			return 5 * YEAR_DAYS
	return -1


#The days passed in the current calendar year, the first day of a year counting as one.
static func year_day(today: int) -> int:
	return posmod(today, YEAR_DAYS) + 1


#The window the chart reads: never longer than the record, never shorter than one day.
static func span(period: int, today: int, available: int) -> int:
	var days: int = period_days(period, today)
	if days < 0:
		return maxi(1, available)
	return maxi(1, mini(available, days))


static func scale_valid(scale: int, span_days: int) -> bool:
	match scale:
		Scale.DAY:
			return span_days <= HALF_YEAR
		Scale.WEEK:
			return span_days <= YEAR_DAYS
		Scale.MONTH:
			return span_days >= HALF_YEAR
		Scale.QUARTER:
			return span_days >= YEAR_DAYS
	return false


static func valid_scales(span_days: int) -> Array[int]:
	var out: Array[int] = []
	for s: int in range(SCALE_LABELS.size()):
		if scale_valid(s, span_days):
			out.append(s)
	return out


#The nearest valid scale by index; a tie goes to the larger bucket.
static func snap_scale(want: int, span_days: int) -> int:
	if scale_valid(want, span_days):
		return want
	var valid: Array[int] = valid_scales(span_days)
	if valid.is_empty():
		return Scale.MONTH
	var best: int = valid[0]
	for s: int in valid:
		var gap: int = absi(s - want)
		var best_gap: int = absi(best - want)
		if gap < best_gap or (gap == best_gap and s > best):
			best = s
	return best


static func reason(scale: int) -> String:
	if scale < 0 or scale >= REASONS.size():
		return ""
	return REASONS[scale]


static func bucket_days(scale: int) -> int:
	return BUCKET_DAYS[clampi(scale, 0, BUCKET_DAYS.size() - 1)]


static func period_label(period: int) -> String:
	return PERIOD_LABELS[clampi(period, 0, PERIOD_LABELS.size() - 1)]


static func scale_label(scale: int) -> String:
	return SCALE_LABELS[clampi(scale, 0, SCALE_LABELS.size() - 1)]


static func scale_singular(scale: int) -> String:
	return SCALE_SINGULAR[clampi(scale, 0, SCALE_SINGULAR.size() - 1)]


static func period_key(period: int) -> StringName:
	return StringName(PERIOD_KEYS[clampi(period, 0, PERIOD_KEYS.size() - 1)])


static func scale_key(scale: int) -> StringName:
	return StringName(SCALE_KEYS[clampi(scale, 0, SCALE_KEYS.size() - 1)])


static func period_of(key: StringName) -> int:
	return PERIOD_KEYS.find(String(key))


static func scale_of(key: StringName) -> int:
	return SCALE_KEYS.find(String(key))


#Rows for the Period dropdown; every period can be picked whatever the record holds.
static func period_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: int in range(PERIOD_LABELS.size()):
		out.append({"key": period_key(p), "label": PERIOD_LABELS[p], "enabled": true, "reason": ""})
	return out


#Rows for the Scale dropdown; a scale the window cannot carry is disabled with its reason.
static func scale_options(span_days: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: int in range(SCALE_LABELS.size()):
		var ok: bool = scale_valid(s, span_days)
		var why: String = "" if ok else reason(s)
		out.append({"key": scale_key(s), "label": SCALE_LABELS[s], "enabled": ok, "reason": why})
	return out
