class_name GuildRecord extends RefCounted

#Contract successes and failures, lifetime and per calendar month, read as overall, last-month and blended rates.

#What a rate reads while its sample is empty.
const EMPTY_RATE: float = 0.5
#The last month's share of the blended rate; overall holds the rest.
const RECENT_WEIGHT: float = 0.5

#The guild's own record.
static var guild: GuildRecord = GuildRecord.new()

var successes: int = 0
var failures: int = 0
#"year-month" -> [successes, failures].
var by_month: Dictionary = {}


static func reset() -> void:
	guild = GuildRecord.new()


func record(success: bool, minute: int) -> void:
	var key: String = month_key(minute)
	var tally: Array = by_month.get(key, [0, 0])
	if success:
		successes += 1
		tally[0] = int(tally[0]) + 1
	else:
		failures += 1
		tally[1] = int(tally[1]) + 1
	by_month[key] = tally


func overall() -> float:
	return _rate(successes, failures)


#The previous calendar month's rate; the month that holds now_minute never counts.
func recent(now_minute: int) -> float:
	var date: Dictionary = TrynnCalendar.date_of(now_minute)
	var start: int = TrynnCalendar.month_start_minute(int(date["year"]), int(date["month"]))
	var tally: Array = by_month.get(month_key(start - 1), [0, 0])
	return _rate(int(tally[0]), int(tally[1]))


func blended(now_minute: int) -> float:
	return (1.0 - RECENT_WEIGHT) * overall() + RECENT_WEIGHT * recent(now_minute)


#The by_month key of the calendar month that holds this minute.
static func month_key(minute: int) -> String:
	var date: Dictionary = TrynnCalendar.date_of(minute)
	return "%d-%d" % [int(date["year"]), int(date["month"])]


static func _rate(wins: int, losses: int) -> float:
	var total: int = wins + losses
	if total <= 0:
		return EMPTY_RATE
	return float(wins) / float(total)
