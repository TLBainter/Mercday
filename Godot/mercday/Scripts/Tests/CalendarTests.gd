class_name CalendarTests

#Trynn calendar and clock runner. Run: godot --headless --path . -- --calendar-tests
#Every case sets the campaign clock itself, so the suite is order independent.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_tables(res)
	_case_start_date(res)
	_case_year_roll(res)
	_case_weekend(res)
	_case_month_starts(res)
	_case_months_between(res)
	_case_ordinal(res)
	_case_time_text(res)
	_case_speed_grid(res)
	_case_tick(res)
	_case_boundaries(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "CALENDAR")


static func _case_tables(res: Dictionary) -> void:
	var total: int = 0
	for month: Dictionary in TrynnCalendar.MONTHS:
		total += int(month["days"])
	TestFixtures.check(res, "the ten months hold 330 days",
		total == TrynnCalendar.DAYS_PER_YEAR and TrynnCalendar.MONTHS.size() == 10,
		"expected 330 over 10 months, got %d over %d" % [total, TrynnCalendar.MONTHS.size()])
	TestFixtures.check(res, "the long months carry 40 days",
		int(TrynnCalendar.MONTHS[4]["days"]) == 40 and int(TrynnCalendar.MONTHS[8]["days"]) == 40
		and int(TrynnCalendar.MONTHS[9]["days"]) == 40,
		"Erta %d, Orlin %d, Tek %d" % [int(TrynnCalendar.MONTHS[4]["days"]),
			int(TrynnCalendar.MONTHS[8]["days"]), int(TrynnCalendar.MONTHS[9]["days"])])
	TestFixtures.check(res, "a week is ten days", TrynnCalendar.WEEKDAYS.size() == 10
		and TrynnCalendar.WEEKDAYS[0] == "Belday" and TrynnCalendar.WEEKDAYS[9] == "Zelday",
		"got %d days, %s to %s" % [TrynnCalendar.WEEKDAYS.size(), TrynnCalendar.WEEKDAYS[0],
			TrynnCalendar.WEEKDAYS[9]])
	TestFixtures.check(res, "a day is the campaign clock day",
		TrynnCalendar.MINUTES_PER_DAY == CampaignClock.MINUTES_PER_DAY,
		"expected %d, got %d" % [CampaignClock.MINUTES_PER_DAY, TrynnCalendar.MINUTES_PER_DAY])


static func _case_start_date(res: Dictionary) -> void:
	var date: Dictionary = TrynnCalendar.date_of(TrynnCalendar.START_MINUTE)
	TestFixtures.check(res, "the start minute is 1920", TrynnCalendar.START_MINUTE == 1920,
		"expected 1920, got %d" % TrynnCalendar.START_MINUTE)
	TestFixtures.check(res, "the start names Ansday 2 Daith 301",
		int(date["year"]) == 301 and int(date["month"]) == 0 and int(date["day"]) == 2
		and str(date["weekday_name"]) == "Ansday" and str(date["season"]) == "spring",
		"got %s, day %d of month %d, %d" % [str(date["weekday_name"]), int(date["day"]),
			int(date["month"]), int(date["year"])])
	TestFixtures.check(res, "the start is 8:00 AM on day index 1",
		int(date["hour"]) == 8 and int(date["minute_of_hour"]) == 0 and int(date["day_index"]) == 1,
		"got %02d:%02d on day index %d" % [int(date["hour"]), int(date["minute_of_hour"]),
			int(date["day_index"])])
	var text: String = TrynnCalendar.date_text(TrynnCalendar.START_MINUTE)
	TestFixtures.check(res, "the start date text", text == "Ansday, 2nd of Daith 301",
		"got %s" % text)
	var clock: String = TrynnCalendar.time_text(TrynnCalendar.START_MINUTE)
	TestFixtures.check(res, "the start time text", clock == "8:00 AM", "got %s" % clock)
	TestFixtures.check(res, "minute_of_day reads the start",
		TrynnCalendar.minute_of_day(TrynnCalendar.START_MINUTE) == 480,
		"expected 480, got %d" % TrynnCalendar.minute_of_day(TrynnCalendar.START_MINUTE))


static func _case_year_roll(res: Dictionary) -> void:
	var minute: int = TrynnCalendar.DAYS_PER_YEAR * TrynnCalendar.MINUTES_PER_DAY
	var date: Dictionary = TrynnCalendar.date_of(minute)
	TestFixtures.check(res, "330 days reach Daith 1, 302",
		int(date["year"]) == 302 and int(date["month"]) == 0 and int(date["day"]) == 1
		and str(date["weekday_name"]) == "Belday",
		"got %s" % TrynnCalendar.date_text(minute))
	TestFixtures.check(res, "day_index counts whole days",
		TrynnCalendar.day_index(1439) == 0 and TrynnCalendar.day_index(1440) == 1
		and TrynnCalendar.day_index(minute) == 330,
		"got %d, %d, %d" % [TrynnCalendar.day_index(1439), TrynnCalendar.day_index(1440),
			TrynnCalendar.day_index(minute)])


static func _case_weekend(res: Dictionary) -> void:
	var bad: Array[String] = []
	for day: int in 10:
		var day_date: Dictionary = TrynnCalendar.date_of(day * TrynnCalendar.MINUTES_PER_DAY)
		var want: bool = day == 0 or day == 9
		if bool(day_date["weekend"]) != want:
			bad.append("day %d" % day)
	TestFixtures.check(res, "only the first and last day of a week are weekend", bad.is_empty(),
		TestFixtures.detail(bad, 10, "days"))
	var long_month: int = (120 + 39) * TrynnCalendar.MINUTES_PER_DAY
	var date: Dictionary = TrynnCalendar.date_of(long_month)
	TestFixtures.check(res, "Erta carries a 40th on Zelday",
		str(date["month_name"]) == "Erta" and int(date["day"]) == 40
		and str(date["weekday_name"]) == "Zelday" and bool(date["weekend"]),
		"got %s" % TrynnCalendar.date_text(long_month))


static func _case_month_starts(res: Dictionary) -> void:
	TestFixtures.check(res, "Ruadd 301 starts on day 30",
		TrynnCalendar.month_start_minute(301, 1) == 30 * TrynnCalendar.MINUTES_PER_DAY,
		"expected 43200, got %d" % TrynnCalendar.month_start_minute(301, 1))
	TestFixtures.check(res, "Erta 301 starts on day 120",
		TrynnCalendar.month_start_minute(301, 4) == 120 * TrynnCalendar.MINUTES_PER_DAY,
		"expected 172800, got %d" % TrynnCalendar.month_start_minute(301, 4))
	var after_erta: int = TrynnCalendar.next_month_start(172800)
	TestFixtures.check(res, "Kusarra follows a 40 day Erta",
		after_erta == 160 * TrynnCalendar.MINUTES_PER_DAY,
		"expected 230400, got %d" % after_erta)
	var wrapped_start: int = TrynnCalendar.next_month_start(290 * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "Tek rolls into the next year",
		wrapped_start == 330 * TrynnCalendar.MINUTES_PER_DAY, "expected 475200, got %d" % wrapped_start)
	var payday: int = TrynnCalendar.first_weekday_minute(301, 1, 8)
	TestFixtures.check(res, "the first weekday of Ruadd 301 is the 2nd at 8:00 AM",
		payday == 31 * TrynnCalendar.MINUTES_PER_DAY + 480, "expected 45120, got %d" % payday)
	var date: Dictionary = TrynnCalendar.date_of(payday)
	TestFixtures.check(res, "the first weekday is never a weekend day",
		int(date["day"]) == 2 and not bool(date["weekend"]),
		"got %s %s" % [TrynnCalendar.date_text(payday), TrynnCalendar.time_text(payday)])


static func _case_months_between(res: Dictionary) -> void:
	var hired: int = TrynnCalendar.START_MINUTE
	var next_month: int = TrynnCalendar.first_weekday_minute(301, 1, 8)
	TestFixtures.check(res, "the hire month counts zero months",
		TrynnCalendar.months_between(hired, hired) == 0
		and TrynnCalendar.months_between(hired, next_month - 1) == 0,
		"got %d and %d" % [TrynnCalendar.months_between(hired, hired),
			TrynnCalendar.months_between(hired, next_month - 1)])
	TestFixtures.check(res, "the same day and hour next month counts one",
		TrynnCalendar.months_between(hired, next_month) == 1,
		"got %d" % TrynnCalendar.months_between(hired, next_month))
	var year_on: int = hired + TrynnCalendar.DAYS_PER_YEAR * TrynnCalendar.MINUTES_PER_DAY
	TestFixtures.check(res, "a whole year counts ten months",
		TrynnCalendar.months_between(hired, year_on) == 10,
		"got %d" % TrynnCalendar.months_between(hired, year_on))
	var late: int = TrynnCalendar.month_start_minute(301, 4) + 34 * TrynnCalendar.MINUTES_PER_DAY
	var short_month: int = TrynnCalendar.month_start_minute(301, 5) \
		+ 29 * TrynnCalendar.MINUTES_PER_DAY
	TestFixtures.check(res, "a 35th of Erta counts a month on the last day of Kusarra",
		TrynnCalendar.months_between(late, short_month) == 1,
		"got %d" % TrynnCalendar.months_between(late, short_month))
	TestFixtures.check(res, "a later start never counts backwards",
		TrynnCalendar.months_between(next_month, hired) == 0,
		"got %d" % TrynnCalendar.months_between(next_month, hired))


static func _case_ordinal(res: Dictionary) -> void:
	var cases: Array = [[1, "1st"], [2, "2nd"], [3, "3rd"], [4, "4th"], [11, "11th"],
		[12, "12th"], [13, "13th"], [21, "21st"], [22, "22nd"], [23, "23rd"], [31, "31st"],
		[32, "32nd"], [33, "33rd"], [40, "40th"]]
	var bad: Array[String] = []
	for c: Array in cases:
		var got: String = TrynnCalendar.ordinal(int(c[0]))
		if got != str(c[1]):
			bad.append("%d gave %s" % [int(c[0]), got])
	TestFixtures.check(res, "ordinal suffixes", bad.is_empty(),
		TestFixtures.detail(bad, cases.size(), "days"))


static func _case_time_text(res: Dictionary) -> void:
	var cases: Array = [[0, "12:00 AM"], [720, "12:00 PM"], [480, "8:00 AM"], [785, "1:05 PM"],
		[1439, "11:59 PM"], [60, "1:00 AM"]]
	var bad: Array[String] = []
	for c: Array in cases:
		var got: String = TrynnCalendar.time_text(int(c[0]))
		if got != str(c[1]):
			bad.append("%d gave %s" % [int(c[0]), got])
	TestFixtures.check(res, "twelve hour clock text", bad.is_empty(),
		TestFixtures.detail(bad, cases.size(), "minutes"))


static func _case_speed_grid(res: Dictionary) -> void:
	var runner := ClockRunner.new()
	TestFixtures.check(res, "the five speeds carry their step minutes",
		ClockRunner.STEPS == [1, 0, 5, 60, 480] and ClockRunner.STEPS[ClockRunner.Speed.PAUSE] == 0,
		"got %s" % str(ClockRunner.STEPS))
	var seen: Array[int] = []
	runner.speed_changed.connect(func(level: int) -> void: seen.append(level))
	runner.set_speed(ClockRunner.Speed.PLAY)
	TestFixtures.check(res, "set_speed reports the new speed",
		seen == [ClockRunner.Speed.PLAY] and runner.speed == ClockRunner.Speed.PLAY,
		"got %s with speed %d" % [str(seen), runner.speed])
	CampaignClock.reset()
	CampaignClock.advance_to(181)
	var play_one: int = runner.next_target()
	CampaignClock.advance_to(play_one)
	var play_two: int = runner.next_target()
	TestFixtures.check(res, "3:01 on Play snaps to 3:05 then 3:10",
		play_one == 185 and play_two == 190, "got %d then %d" % [play_one, play_two])
	CampaignClock.reset()
	CampaignClock.advance_to(195)
	runner.set_speed(ClockRunner.Speed.FAST)
	var fast_one: int = runner.next_target()
	CampaignClock.advance_to(fast_one)
	var fast_two: int = runner.next_target()
	TestFixtures.check(res, "3:15 on Fast snaps to 4:00 then 5:00",
		fast_one == 240 and fast_two == 300, "got %d then %d" % [fast_one, fast_two])
	CampaignClock.reset()
	CampaignClock.advance_to(1020)
	runner.set_speed(ClockRunner.Speed.VERY_FAST)
	var very_one: int = runner.next_target()
	CampaignClock.advance_to(very_one)
	var very_two: int = runner.next_target()
	CampaignClock.advance_to(very_two)
	var very_three: int = runner.next_target()
	TestFixtures.check(res, "17:00 on Very Fast snaps to 0:00, 8:00 then 16:00",
		very_one == 1440 and very_two == 1920 and very_three == 2400,
		"got %d, %d then %d" % [very_one, very_two, very_three])
	runner.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.check(res, "a paused runner never moves the clock",
		runner.next_target() == CampaignClock.now(),
		"expected %d, got %d" % [CampaignClock.now(), runner.next_target()])
	runner.free()


static func _case_tick(res: Dictionary) -> void:
	var runner := ClockRunner.new()
	var ticks: Array[Array] = []
	runner.ticked.connect(func(from_minute: int, to_minute: int) -> void:
		ticks.append([from_minute, to_minute]))
	CampaignClock.reset()
	CampaignClock.advance_to(TrynnCalendar.START_MINUTE)
	runner.set_speed(ClockRunner.Speed.PAUSE)
	runner.tick()
	TestFixtures.check(res, "a paused tick does nothing",
		ticks.is_empty() and CampaignClock.now() == TrynnCalendar.START_MINUTE,
		"got %d ticks at minute %d" % [ticks.size(), CampaignClock.now()])
	runner.set_speed(ClockRunner.Speed.FAST)
	runner.tick()
	TestFixtures.check(res, "a tick moves one step and reports the span",
		CampaignClock.now() == 1980 and ticks == [[1920, 1980]],
		"got minute %d with %s" % [CampaignClock.now(), str(ticks)])
	TestFixtures.check(res, "a finished tick is not busy", not runner.busy, "busy stayed set")
	runner.free()


static func _case_boundaries(res: Dictionary) -> void:
	var runner := ClockRunner.new()
	var days: Array[int] = []
	var months: Array[Array] = []
	runner.day_changed.connect(func(day: int) -> void: days.append(day))
	runner.month_changed.connect(func(year: int, month: int) -> void: months.append([year, month]))
	CampaignClock.reset()
	CampaignClock.advance_to(43140)
	runner.set_speed(ClockRunner.Speed.VERY_FAST)
	runner.tick()
	TestFixtures.check(res, "crossing midnight reports the new day",
		CampaignClock.now() == 43200 and days == [30],
		"got minute %d with days %s" % [CampaignClock.now(), str(days)])
	TestFixtures.check(res, "crossing into Ruadd reports the month",
		months == [[301, 1]], "got %s" % str(months))
	days.clear()
	months.clear()
	runner.tick()
	TestFixtures.check(res, "a tick inside a day reports no boundary",
		days.is_empty() and months.is_empty(),
		"got days %s and months %s" % [str(days), str(months)])
	runner.free()
