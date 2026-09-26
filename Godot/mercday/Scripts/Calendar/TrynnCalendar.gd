class_name TrynnCalendar

#The Trynn calendar over CampaignClock minutes. The clock is never changed: minute 0 is Belday,
#the 1st of Daith 301, 00:00, and every suite keeps reading it as D1 00:00. Ten day weeks, the
#first and last day of a week are weekend days, and every month length is a multiple of ten, so
#every month starts on Belday and its first weekday is always the 2nd.

const MONTHS: Array[Dictionary] = [
	{"name": "Daith", "season": "spring", "days": 30},
	{"name": "Ruadd", "season": "spring", "days": 30},
	{"name": "Kier", "season": "spring", "days": 30},
	{"name": "Helki", "season": "summer", "days": 30},
	{"name": "Erta", "season": "summer", "days": 40},
	{"name": "Kusarra", "season": "autumn", "days": 30},
	{"name": "Urbai", "season": "autumn", "days": 30},
	{"name": "Saryu", "season": "autumn", "days": 30},
	{"name": "Orlin", "season": "winter", "days": 40},
	{"name": "Tek", "season": "winter", "days": 40},
]
const WEEKDAYS: Array[String] = ["Belday", "Ansday", "Rinday", "Erinday", "Felday",
	"Rahkday", "Draday", "Asulday", "Bolday", "Zelday"]
const DAYS_PER_YEAR := 330
const START_YEAR := 301
#The 2nd of Daith 301 at 8:00 AM.
const START_MINUTE := 1920
const MINUTES_PER_DAY := CampaignClock.MINUTES_PER_DAY
const MINUTES_PER_HOUR := CampaignClock.MINUTES_PER_HOUR


#Whole days since Daith 1, 301; 0 is that first day.
static func day_index(minute: int) -> int:
	var days: int = int(minute / float(MINUTES_PER_DAY))
	if minute < 0 and minute % MINUTES_PER_DAY != 0:
		days -= 1
	return days


#Minutes since midnight of the day that holds this minute.
static func minute_of_day(minute: int) -> int:
	return minute - day_index(minute) * MINUTES_PER_DAY


#Every calendar field of one minute.
static func date_of(minute: int) -> Dictionary:
	var days: int = day_index(minute)
	var year_offset: int = int(days / float(DAYS_PER_YEAR))
	if days < 0 and days % DAYS_PER_YEAR != 0:
		year_offset -= 1
	var day_of_year: int = days - year_offset * DAYS_PER_YEAR
	var month: int = 0
	while month < MONTHS.size() - 1 and day_of_year >= int(MONTHS[month]["days"]):
		day_of_year -= int(MONTHS[month]["days"])
		month += 1
	var weekday: int = posmod(days, WEEKDAYS.size())
	var rest: int = minute_of_day(minute)
	return {
		"year": START_YEAR + year_offset,
		"month": month,
		"month_name": str(MONTHS[month]["name"]),
		"season": str(MONTHS[month]["season"]),
		"day": day_of_year + 1,
		"weekday": weekday,
		"weekday_name": WEEKDAYS[weekday],
		"weekend": weekday == 0 or weekday == WEEKDAYS.size() - 1,
		"hour": int(rest / float(MINUTES_PER_HOUR)),
		"minute_of_hour": rest % MINUTES_PER_HOUR,
		"day_index": days,
	}


#Midnight of the 1st of that month.
static func month_start_minute(year: int, month: int) -> int:
	var days: int = (year - START_YEAR) * DAYS_PER_YEAR
	for i: int in mini(maxi(month, 0), MONTHS.size()):
		days += int(MONTHS[i]["days"])
	return days * MINUTES_PER_DAY


#Midnight of the 1st of the month after the one holding this minute; always later than minute.
static func next_month_start(minute: int) -> int:
	var date: Dictionary = date_of(minute)
	var month: int = int(date["month"]) + 1
	var year: int = int(date["year"])
	if month >= MONTHS.size():
		month = 0
		year += 1
	return month_start_minute(year, month)


#The 2nd of that month at hour:00, the first day that is not a weekend day.
static func first_weekday_minute(year: int, month: int, hour: int) -> int:
	return month_start_minute(year, month) + MINUTES_PER_DAY + hour * MINUTES_PER_HOUR


#Whole calendar months between two minutes; 0 while the later minute is still in the first month.
static func months_between(from_minute: int, to_minute: int) -> int:
	var a: Dictionary = date_of(from_minute)
	var b: Dictionary = date_of(to_minute)
	var months: int = (int(b["year"]) - int(a["year"])) * MONTHS.size() + int(b["month"]) - int(a["month"])
	var anchor: int = mini(int(a["day"]), int(MONTHS[int(b["month"])]["days"]))
	if int(b["day"]) < anchor or (int(b["day"]) == anchor and minute_of_day(to_minute) < minute_of_day(from_minute)):
		months -= 1
	return maxi(0, months)


#"1st", "2nd", "3rd", "11th", "21st", "32nd"; days run to 40.
static func ordinal(day: int) -> String:
	var tens: int = posmod(day, 100)
	if tens >= 11 and tens <= 13:
		return "%dth" % day
	match posmod(day, 10):
		1:
			return "%dst" % day
		2:
			return "%dnd" % day
		3:
			return "%drd" % day
	return "%dth" % day


#"Ansday, 2nd of Daith 301".
static func date_text(minute: int) -> String:
	var date: Dictionary = date_of(minute)
	return "%s, %s of %s %d" % [str(date["weekday_name"]), ordinal(int(date["day"])),
		str(date["month_name"]), int(date["year"])]


#"8:00 AM", with midnight as 12:00 AM and noon as 12:00 PM.
static func time_text(minute: int) -> String:
	var date: Dictionary = date_of(minute)
	var hour: int = int(date["hour"])
	var suffix: String = "AM" if hour < 12 else "PM"
	var shown: int = hour % 12
	if shown == 0:
		shown = 12
	return "%d:%02d %s" % [shown, int(date["minute_of_hour"]), suffix]
