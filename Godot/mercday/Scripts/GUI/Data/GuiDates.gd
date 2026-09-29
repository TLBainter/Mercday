class_name GuiDates

#Date and duration text for the GUI screens, over TrynnCalendar day indices. A day index counts
#whole days from minute 0, so every reading converts with CampaignClock.MINUTES_PER_DAY first.

const MONTH_LETTERS := 3


#"2 Daith 301" for a day index.
static func day_text(day_index: int) -> String:
	var date: Dictionary = TrynnCalendar.date_of(day_index * CampaignClock.MINUTES_PER_DAY)
	return "%d %s %d" % [int(date["day"]), str(date["month_name"]), int(date["year"])]


#"2 Dai": the same date without the year, the month cut to its first three letters.
static func short_text(day_index: int) -> String:
	var date: Dictionary = TrynnCalendar.date_of(day_index * CampaignClock.MINUTES_PER_DAY)
	return "%d %s" % [int(date["day"]), str(date["month_name"]).substr(0, MONTH_LETTERS)]


#"1 day", "12 days".
static func days_text(n: int) -> String:
	if n == 1 or n == -1:
		return "%d day" % n
	return "%d days" % n


#The delivery line of an order: past its arrival day it reads Delivered.
static func eta_text(days_left: int) -> String:
	if days_left < 0:
		return "Delivered"
	if days_left == 0:
		return "Arrives today"
	return "Arrives in %s" % days_text(days_left)
