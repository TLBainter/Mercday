class_name VacationPolicy extends RefCounted

#The guild vacation rules: the days a merc starts with, what service earns and the limits on
#taking it. BenefitsManager keeps one of these and the Benefits panel edits it through
#set_vacation. Every count is clamped per unit, so a unit change can shrink its count.

#PLACEHOLDER defaults and caps: the prototype ships no cap for the starting days, the earned
#days or the simultaneous mercs, so these three read as placeholders until the designer sets them.
const DEFAULT_START: int = 3
const DEFAULT_ADD_DAYS: int = 1
const DEFAULT_EVERY: int = 1
const DEFAULT_UNIT: String = "years"
const DEFAULT_MAX_LEN: int = 1
const DEFAULT_MAX_UNIT: String = "weeks"
const DEFAULT_MAX_AT: int = 2
const DEFAULT_GAP: int = 3
const DEFAULT_GAP_UNIT: String = "months"
const DEFAULT_APPROVAL: bool = true
const START_MAX: int = 60
const ADD_MAX: int = 30
const MAX_AT_MAX: int = 50

const EVERY_UNITS: Array[String] = ["months", "years"]
const LEN_UNITS: Array[String] = ["days", "weeks"]
const GAP_UNITS: Array[String] = ["weeks", "months"]
const EVERY_MAX: Dictionary = {"months": 24, "years": 10}
const LEN_MAX: Dictionary = {"days": 60, "weeks": 12}
const GAP_MAX: Dictionary = {"weeks": 52, "months": 24}
const UNIT_WORDS: Dictionary = {"days": "Day", "weeks": "Week", "months": "Month",
	"years": "Year"}

var start: int = DEFAULT_START
var add_days: int = DEFAULT_ADD_DAYS
var every: int = DEFAULT_EVERY
var unit: String = DEFAULT_UNIT
var max_len: int = DEFAULT_MAX_LEN
var max_unit: String = DEFAULT_MAX_UNIT
var max_at: int = DEFAULT_MAX_AT
var gap: int = DEFAULT_GAP
var gap_unit: String = DEFAULT_GAP_UNIT
var approval: bool = DEFAULT_APPROVAL


func to_dict() -> Dictionary:
	return {"start": start, "add_days": add_days, "every": every, "unit": unit,
		"max_len": max_len, "max_unit": max_unit, "max_at": max_at, "gap": gap,
		"gap_unit": gap_unit, "approval": approval}


#A missing key keeps the default; an unknown unit falls back the way the prototype does.
static func from_dict(d: Dictionary) -> VacationPolicy:
	var out: VacationPolicy = VacationPolicy.new()
	out.merge(d)
	return out


func merge(d: Dictionary) -> void:
	start = int(d.get("start", start))
	add_days = int(d.get("add_days", add_days))
	every = int(d.get("every", every))
	unit = String(d.get("unit", unit))
	max_len = int(d.get("max_len", max_len))
	max_unit = String(d.get("max_unit", max_unit))
	max_at = int(d.get("max_at", max_at))
	gap = int(d.get("gap", gap))
	gap_unit = String(d.get("gap_unit", gap_unit))
	approval = bool(d.get("approval", approval))
	clamp_all()


func clamp_all() -> void:
	if not EVERY_UNITS.has(unit):
		unit = "months"
	if not LEN_UNITS.has(max_unit):
		max_unit = DEFAULT_MAX_UNIT
	if not GAP_UNITS.has(gap_unit):
		gap_unit = DEFAULT_GAP_UNIT
	start = clampi(start, 0, START_MAX)
	add_days = clampi(add_days, 0, ADD_MAX)
	every = clampi(every, 1, every_max())
	max_len = clampi(max_len, 1, len_max())
	max_at = clampi(max_at, 0, MAX_AT_MAX)
	gap = clampi(gap, 0, gap_max())


func every_max() -> int:
	return int(EVERY_MAX.get(unit, 24))


func len_max() -> int:
	return int(LEN_MAX.get(max_unit, 12))


func gap_max() -> int:
	return int(GAP_MAX.get(gap_unit, 24))


#Calendar lengths the vacation rules read: a week is 10 days, a month 33.
static func week_days() -> int:
	return TrynnCalendar.WEEKDAYS.size()


static func month_days() -> int:
	return int(TrynnCalendar.DAYS_PER_YEAR / float(TrynnCalendar.MONTHS.size()))


func max_len_days() -> int:
	return max_len * (week_days() if max_unit == "weeks" else 1)


func gap_days() -> int:
	return gap * (month_days() if gap_unit == "months" else week_days())


func duplicate_policy() -> VacationPolicy:
	return VacationPolicy.from_dict(to_dict())


#The service the accrual counts, in the unit the policy earns on.
func served(months: int) -> int:
	if unit == "months":
		return maxi(0, months)
	return int(maxi(0, months) / float(TrynnCalendar.MONTHS.size()))


func days_max(months: int) -> int:
	return start + add_days * int(served(months) / float(maxi(1, every)))


static func unit_word(key: String) -> String:
	return String(UNIT_WORDS.get(key, "Month"))


#The Earned row: "+1 Day / Year" at every 1, "+1 Day / 2 Years" above it, "None" at 0 days.
func accrual_text() -> String:
	if add_days <= 0:
		return "None"
	var period: String = unit_word(unit) if every == 1 else GuiDates.plural(every, unit_word(unit))
	return "+" + GuiDates.plural(add_days, "Day") + " / " + period


func rows() -> Array[Dictionary]:
	return [
		{"key": "start", "label": "Starting", "value_text": GuiDates.plural(start, "Day")},
		{"key": "earned", "label": "Earned", "value_text": accrual_text()},
		{"key": "max_len", "label": "Max Length",
			"value_text": GuiDates.plural(max_len, unit_word(max_unit))},
		{"key": "max_at", "label": "Simultaneous", "value_text": GuiDates.plural(max_at, "Merc")},
		{"key": "gap", "label": "Min Gap", "value_text": GuiDates.plural(gap, unit_word(gap_unit))},
		{"key": "approval", "label": "Approval",
			"value_text": "Required" if approval else "Not Required"},
	]
