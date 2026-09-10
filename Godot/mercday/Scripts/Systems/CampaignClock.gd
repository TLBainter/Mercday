class_name CampaignClock

#Campaign time in whole in-game minutes. Every advance is instant; nothing waits in real time.
#Day 1 starts at minute 0, so minute 1440 is D2 00:00.

const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 1440
const TRAVEL_MINUTES := 480
const EVENT_MINUTES := 60
const EVENT_GAP_MINUTES := 360
const UNIT_MINUTES: Dictionary = {
	"minute": 1, "minutes": 1,
	"hour": MINUTES_PER_HOUR, "hours": MINUTES_PER_HOUR,
	"day": MINUTES_PER_DAY, "days": MINUTES_PER_DAY,
}

static var minutes: int = 0


static func now() -> int:
	return minutes


#Moves the clock forward by n minutes and returns the new total; n <= 0 changes nothing.
static func advance(n: int) -> int:
	if n > 0:
		minutes += n
	return minutes


#Moves the clock to an absolute minute, forward only.
static func advance_to(minute: int) -> int:
	if minute > minutes:
		minutes = minute
	return minutes


static func reset() -> void:
	minutes = 0


#Minutes in n of a named unit; 0 for a unit the campaign clock does not measure, such as round.
static func minutes_of(n: int, unit: String) -> int:
	var key: String = unit.strip_edges().to_lower()
	if not UNIT_MINUTES.has(key):
		return 0
	return n * int(UNIT_MINUTES[key])


#"D3 14:20" for an absolute minute; -1 reads the current time.
static func stamp(minute: int = -1) -> String:
	var m: int = minutes if minute < 0 else minute
	m = maxi(0, m)
	var day: int = m / MINUTES_PER_DAY + 1
	var rest: int = m % MINUTES_PER_DAY
	return "D%d %02d:%02d" % [day, rest / MINUTES_PER_HOUR, rest % MINUTES_PER_HOUR]


#"CLOCK: travel out +8 h -> D1 08:00"; the caller advances first, this only reports.
static func line(tag: String, delta: int) -> String:
	return "CLOCK: %s %s -> %s" % [tag, delta_text(delta), stamp()]


#"+6 h" for whole hours, "+90 min" otherwise.
static func delta_text(delta: int) -> String:
	var sign_text: String = "+" if delta >= 0 else "-"
	var size: int = absi(delta)
	if size >= MINUTES_PER_HOUR and size % MINUTES_PER_HOUR == 0:
		return "%s%d h" % [sign_text, size / MINUTES_PER_HOUR]
	return "%s%d min" % [sign_text, size]
