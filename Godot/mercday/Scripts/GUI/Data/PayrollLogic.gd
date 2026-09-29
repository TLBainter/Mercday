class_name PayrollLogic

#The pure formulas of the Payroll tab: the salary colour bands, the opinion a wage change moves,
#the opinion a firing costs, the hold-to-repeat rate of the steppers, the signed change text and
#the rarest trait of a merc. BenefitsManager owns the state; this file only computes.

const OVER_COLOR: Color = Color("#e8583f")
const WARN_COLOR: Color = Color("#f28c28")
const OK_COLOR: Color = Color("#6cc36a")
const FLAT_COLOR: Color = Color("#9cc6ef")
const OFF_COLOR: Color = Color("#5e7699")
const NOTE_COLOR: Color = Color("#f2b33d")

#Above the bank the wage reads red, above this share of it orange, below it green.
const WARN_SHARE: float = 0.1
#A cut that leaves this wage or less drops the merc to the lowest opinion (prototype tank rule).
const TANK_SALARY: int = 1
const FIRE_DROP_SHARE: float = 0.75
const HOLD_DELAY_SECONDS: float = 0.35
const HOLD_RATE_BASE: float = 4.0
const HOLD_RATE_RAMP: float = 48.0
const HOLD_RATE_MAX: float = 100.0
const PLUS_MINUS: String = "+/-"

#PLACEHOLDER the eleven guild mood labels of the prototype (guildDefs); no label table exists in
#the project yet, and the colours stay in MoodFace.GUILD_COLORS so they are written once.
const MOOD_DEFS: Array[Dictionary] = [
	{"level": -5, "label": "-5"},
	{"level": -4, "label": "-4"},
	{"level": -3, "label": "-3"},
	{"level": -2, "label": "-2"},
	{"level": -1, "label": "-1"},
	{"level": 0, "label": "Neutral"},
	{"level": 1, "label": "+1"},
	{"level": 2, "label": "+2"},
	{"level": 3, "label": "+3"},
	{"level": 4, "label": "+4"},
	{"level": 5, "label": "+5"},
]


static func salary_color(salary: int, money: int) -> Color:
	if salary > money:
		return OVER_COLOR
	if float(salary) > float(money) * WARN_SHARE:
		return WARN_COLOR
	return OK_COLOR


#The opinion a wage change moves, kept inside the SalarySystem range for the opinion held now.
static func opinion_shift(old_salary: int, new_salary: int, opinion: int) -> int:
	var shift: int = SalarySystem.opinion_delta(old_salary, new_salary)
	if new_salary < old_salary and new_salary <= TANK_SALARY:
		shift = SalarySystem.OPINION_MIN - opinion
	var after: int = clampi(opinion + shift, SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX)
	return after - opinion


static func fire_drop(opinion: int) -> int:
	return floori(float(opinion - SalarySystem.OPINION_MIN) * FIRE_DROP_SHARE)


#Steps per second while a stepper button is held: nothing until the delay, then a rising ramp.
static func hold_rate(seconds: float) -> float:
	if seconds < HOLD_DELAY_SECONDS:
		return 0.0
	return minf(HOLD_RATE_MAX,
		HOLD_RATE_BASE + (seconds - HOLD_DELAY_SECONDS) * HOLD_RATE_RAMP)


static func sign_text(value: int) -> String:
	if value > 0:
		return "+"
	if value < 0:
		return "-"
	return PLUS_MINUS


static func percent_text(old_value: int, new_value: int) -> String:
	var pct: float = 0.0
	if old_value != 0:
		pct = float(new_value - old_value) / float(old_value) * 100.0
	var rounded: int = int(round(pct))
	return sign_text(rounded) + str(absi(rounded)) + "%"


#"+15 (+15%)" for a raise, "-10 (-10%)" for a cut, "+/-0 (+/-0%)" for no change.
static func delta_text(old_value: int, new_value: int) -> String:
	var delta: int = new_value - old_value
	return sign_text(delta) + str(absi(delta)) + " (" + percent_text(old_value, new_value) + ")"


static func delta_color(delta: int) -> Color:
	if delta > 0:
		return OK_COLOR
	if delta < 0:
		return OVER_COLOR
	return FLAT_COLOR


static func mood_label(level: int) -> String:
	var wanted: int = clampi(level, SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX)
	for row: Dictionary in MOOD_DEFS:
		if int(row["level"]) == wanted:
			return String(row["label"])
	return "Neutral"


static func mood_color(level: int) -> Color:
	var wanted: int = clampi(level, SalarySystem.OPINION_MIN, SalarySystem.OPINION_MAX)
	return MoodFace.GUILD_COLORS[wanted - SalarySystem.OPINION_MIN]


#The dialog title: the mood the preview lands on and the signed shift that gets it there.
static func mood_title(level: int, shift: int) -> String:
	var mark: String = "+" if shift > 0 else ""
	return mood_label(level) + " (" + mark + str(shift) + ")"


#The name of `names` the fewest holders carry; ties go to the first name listed. Every row of
#`rows` is one holder as {"names": Array[String]}. An empty name list gives an empty result.
static func unique_of(rows: Array[Dictionary], names: Array[String]) -> Dictionary:
	if names.is_empty():
		return {}
	var total: int = rows.size()
	var best: String = ""
	var best_holders: int = -1
	for key: String in names:
		var holders: int = 0
		for row: Dictionary in rows:
			var held: Variant = row.get("names", [])
			if held is Array and (held as Array).has(key):
				holders += 1
		if best_holders < 0 or holders < best_holders:
			best = key
			best_holders = holders
	if best_holders < 0:
		return {}
	return {"name": best, "holders": best_holders, "total": total,
		"rarity": rarity_text(best_holders, total)}


static func rarity_text(holders: int, total: int) -> String:
	if holders <= 1:
		return "Only this merc"
	return str(holders) + " of " + str(total) + " mercs"
