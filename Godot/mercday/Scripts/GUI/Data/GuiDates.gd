class_name GuiDates

#Date and duration text for the GUI screens, over TrynnCalendar day indices. A day index counts
#whole days from minute 0, so every reading converts with CampaignClock.MINUTES_PER_DAY first.

const MONTH_LETTERS := 3


#"2 Daith 212" for a day index.
static func day_text(day_index: int) -> String:
	var date: Dictionary = TrynnCalendar.date_of(day_index * CampaignClock.MINUTES_PER_DAY)
	return "%d %s %d" % [int(date["day"]), str(date["month_name"]), int(date["year"])]


#"2 Dai": the same date without the year, the month cut to its first three letters.
static func short_text(day_index: int) -> String:
	var date: Dictionary = TrynnCalendar.date_of(day_index * CampaignClock.MINUTES_PER_DAY)
	return "%d %s" % [int(date["day"]), str(date["month_name"]).substr(0, MONTH_LETTERS)]


#"1 Day", "3 Days": the count, then the word with an s unless the count is exactly one.
static func plural(n: int, word: String) -> String:
	return str(n) + " " + word + ("" if n == 1 else "s")


#"1 day", "12 days"; minus one reads singular as well.
static func days_text(n: int) -> String:
	return "%d day" % n if n == -1 else plural(n, "day")


#"Today", "1 Day From Now", "12 Days From Now".
static func from_now_text(n: int) -> String:
	return "Today" if n <= 0 else plural(n, "Day") + " From Now"


#"Today", "1 Day Ago", "3 Days Ago" for n days in the past.
static func ago_text(n: int) -> String:
	return "Today" if n <= 0 else plural(n, "Day") + " Ago"


#"2 Days, 5 Hours" for a count of hours; a part hour is dropped and a count under zero reads as zero.
static func duration_text(hours: float) -> String:
	var whole: int = maxi(0, int(floor(hours)))
	return "%d Days, %d Hours" % [floori(float(whole) / 24.0), whole % 24]


#The delivery line of an order: past its arrival day it reads Delivered.
static func eta_text(days_left: int) -> String:
	if days_left < 0:
		return "Delivered"
	if days_left == 0:
		return "Arrives today"
	return "Arrives in %s" % days_text(days_left)
