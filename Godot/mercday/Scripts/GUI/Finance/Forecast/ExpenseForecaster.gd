class_name ExpenseForecaster
extends RefCounted
#Projects one expense over the next PROJECT_DAYS from its ledger rows of the last WINDOW_DAYS: the daily
#rate of the window, bent by the trend of its recent half against its older half and by a driver scale a
#child may supply. A child names the reasons, how rows group and what to show when there is no history.

const WINDOW_DAYS: int = 30
const PROJECT_DAYS: int = 30
#The trend compares the last HALF_DAYS of the window with the HALF_DAYS before them.
const HALF_DAYS: int = 15
#A young ledger is read over at least this many days, so one early charge is not taken as a daily habit.
const MIN_SPAN_DAYS: int = 7
const TREND_MIN: float = 0.5
const TREND_MAX: float = 2.0
const SCALE_MIN: float = 0.5
const SCALE_MAX: float = 2.0


#The ledger reasons that are this expense.
func reasons() -> Array[String]:
	return []


#The ledger reasons that hand some of it back.
func credit_reasons() -> Array[String]:
	return []


func group_of(_row: TransactionData) -> String:
	return ""


#How much busier the coming month looks than the window; 1.0 when nothing says otherwise.
func driver_scale(_rows: Array[TransactionData], _today: int) -> float:
	return 1.0


#The guess with no history: {"total", "groups"}, or empty for none.
func fallback(_today: int) -> Dictionary:
	return {}


#{"total", "groups" {group: amount}, "trend", "scale", "estimate"}; amounts are positive costs.
func forecast(rows: Array[TransactionData], today: int) -> Dictionary:
	var picked: Array[TransactionData] = window_rows(rows, today)
	var charged: bool = false
	var by_group: Dictionary = {}
	for row: TransactionData in picked:
		charged = charged or reasons().has(row.reason)
		var key: String = group_of(row)
		by_group[key] = int(by_group.get(key, 0)) - row.amount
	if not charged:
		return _from_fallback(today)
	var span: int = span_days(rows, today)
	var trend: float = trend_of(picked, today, span)
	var scale: float = clampf(driver_scale(picked, today), SCALE_MIN, SCALE_MAX)
	var factor: float = float(PROJECT_DAYS) / float(span) * trend * scale
	var groups: Dictionary = {}
	var total: int = 0
	for key: String in by_group:
		var amount: int = roundi(float(int(by_group[key])) * factor)
		if amount > 0:
			groups[key] = amount
			total += amount
	return {"total": total, "groups": groups, "trend": trend, "scale": scale, "estimate": false}


#This expense's rows dated inside the window ending today.
func window_rows(rows: Array[TransactionData], today: int) -> Array[TransactionData]:
	var wanted: Array[String] = reasons()
	wanted.append_array(credit_reasons())
	var out: Array[TransactionData] = []
	for row: TransactionData in rows:
		if row.day_index > today or row.day_index <= today - WINDOW_DAYS:
			continue
		if wanted.has(row.reason):
			out.append(row)
	return out


#Days the window really covers: back to the first ledger row of any kind, at least MIN_SPAN_DAYS.
func span_days(rows: Array[TransactionData], today: int) -> int:
	var first: int = today
	for row: TransactionData in rows:
		first = mini(first, row.day_index)
	return clampi(today - first + 1, MIN_SPAN_DAYS, WINDOW_DAYS)


#Recent half over older half of the window, clamped; 1.0 when the older half spent nothing or has no days.
#On a young ledger the older half covers only span - HALF_DAYS days and is scaled up to HALF_DAYS.
func trend_of(picked: Array[TransactionData], today: int, span: int = WINDOW_DAYS) -> float:
	if span <= HALF_DAYS:
		return 1.0
	var split: int = today - HALF_DAYS
	var older: int = 0
	var recent: int = 0
	for row: TransactionData in picked:
		if row.day_index > split:
			recent -= row.amount
		else:
			older -= row.amount
	if older <= 0:
		return 1.0
	var older_rate: float = float(older) * float(HALF_DAYS) / float(mini(span, WINDOW_DAYS) - HALF_DAYS)
	return clampf(float(maxi(recent, 0)) / older_rate, TREND_MIN, TREND_MAX)


func _from_fallback(today: int) -> Dictionary:
	var guess: Dictionary = fallback(today)
	if guess.is_empty() or int(guess.get("total", 0)) <= 0:
		return {"total": 0, "groups": {}, "trend": 1.0, "scale": 1.0, "estimate": false}
	return {"total": int(guess["total"]), "groups": guess.get("groups", {}), "trend": 1.0, "scale": 1.0,
		"estimate": true}
