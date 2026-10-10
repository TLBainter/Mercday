class_name CalendarTests

#Trynn calendar and clock runner. Run: godot --headless --path . -- --calendar-tests
#Every case sets the campaign clock itself, so the suite is order independent.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_tables(res)
	_case_start_date(res)
	_case_day_on(res)
	_case_year_roll(res)
	_case_weekend(res)
	_case_month_starts(res)
	_case_month_helpers(res)
	_case_months_between(res)
	_case_ordinal(res)
	_case_time_text(res)
	_case_speed_grid(res)
	_case_after_hours(res)
	_case_tick(res)
	_case_boundaries(res)
	_case_hold(res)
	_case_hold_holders(res)
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
	var want_minute: int = TrynnCalendar.month_start_minute(212, 4) + 2 * TrynnCalendar.MINUTES_PER_DAY + 480
	TestFixtures.check(res, "the start minute is 176160", TrynnCalendar.START_MINUTE == 176160
		and TrynnCalendar.START_MINUTE == want_minute,
		"expected 176160 (%d), got %d" % [want_minute, TrynnCalendar.START_MINUTE])
	TestFixtures.check(res, "the start names Rinday 3 Erta 212",
		int(date["year"]) == 212 and int(date["month"]) == 4 and int(date["day"]) == 3
		and str(date["weekday_name"]) == "Rinday" and str(date["season"]) == "summer",
		"got %s, day %d of month %d, %d" % [str(date["weekday_name"]), int(date["day"]),
			int(date["month"]), int(date["year"])])
	TestFixtures.check(res, "the start is 8:00 AM on day index 122",
		int(date["hour"]) == 8 and int(date["minute_of_hour"]) == 0 and int(date["day_index"]) == 122,
		"got %02d:%02d on day index %d" % [int(date["hour"]), int(date["minute_of_hour"]),
			int(date["day_index"])])
	var text: String = TrynnCalendar.date_text(TrynnCalendar.START_MINUTE)
	TestFixtures.check(res, "the start date text", text == "Rinday, 3rd of Erta 212",
		"got %s" % text)
	var clock: String = TrynnCalendar.time_text(TrynnCalendar.START_MINUTE)
	TestFixtures.check(res, "the start time text", clock == "8:00 AM", "got %s" % clock)
	TestFixtures.check(res, "minute_of_day reads the start",
		TrynnCalendar.minute_of_day(TrynnCalendar.START_MINUTE) == 480,
		"expected 480, got %d" % TrynnCalendar.minute_of_day(TrynnCalendar.START_MINUTE))


static func _case_day_on(res: Dictionary) -> void:
	var erta: int = 120
	var cases: Array = [[0, 2, 1], [0, 15, 14], [1, 2, 31], [1, 15, 14], [13, 15, 14], [14, 15, 44],
		[13, 2, 31], [29, 2, 31], [erta + 2, 2, erta + 41], [erta + 2, 15, erta + 14], [erta + 39, 2, erta + 41],
		[329, 2, 331]]
	var bad: Array[String] = []
	for c: Array in cases:
		var got: int = TrynnCalendar.next_day_on(int(c[0]), int(c[1]))
		if got != int(c[2]):
			bad.append("day %d on the %d gave %d, want %d" % [int(c[0]), int(c[1]), got, int(c[2])])
	TestFixtures.check(res, "next_day_on finds the next strictly later day of month", bad.is_empty(),
		TestFixtures.detail(bad, cases.size(), "cases"))
	var choices: Array[int] = [2, 15]
	var picks: Array = [[0, 15], [1, 2], [13, 2], [14, 15], [29, 15], [erta + 2, 2], [erta + 14, 15],
		[erta + 20, 15]]
	bad.clear()
	for c: Array in picks:
		var got: int = TrynnCalendar.farthest_day_on(int(c[0]), choices)
		if got != int(c[1]):
			bad.append("day %d gave the %d, want the %d" % [int(c[0]), got, int(c[1])])
	TestFixtures.check(res, "farthest_day_on picks the choice whose next day is farther", bad.is_empty(),
		TestFixtures.detail(bad, picks.size(), "cases"))
	var start_day: int = TrynnCalendar.day_index(TrynnCalendar.START_MINUTE)
	var start_pick: int = TrynnCalendar.farthest_day_on(start_day, choices)
	TestFixtures.check(res, "a start on the 3rd of Erta bills on the 2nd",
		start_pick == 2 and TrynnCalendar.next_day_on(start_day, 2) == 161,
		"got the %d, next 2nd on day %d" % [start_pick, TrynnCalendar.next_day_on(start_day, 2)])


static func _case_year_roll(res: Dictionary) -> void:
	var minute: int = TrynnCalendar.DAYS_PER_YEAR * TrynnCalendar.MINUTES_PER_DAY
	var date: Dictionary = TrynnCalendar.date_of(minute)
	TestFixtures.check(res, "330 days reach Daith 1, 213",
		int(date["year"]) == 213 and int(date["month"]) == 0 and int(date["day"]) == 1
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
	TestFixtures.check(res, "Ruadd 212 starts on day 30",
		TrynnCalendar.month_start_minute(212, 1) == 30 * TrynnCalendar.MINUTES_PER_DAY,
		"expected 43200, got %d" % TrynnCalendar.month_start_minute(212, 1))
	TestFixtures.check(res, "Erta 212 starts on day 120",
		TrynnCalendar.month_start_minute(212, 4) == 120 * TrynnCalendar.MINUTES_PER_DAY,
		"expected 172800, got %d" % TrynnCalendar.month_start_minute(212, 4))
	var after_erta: int = TrynnCalendar.next_month_start(172800)
	TestFixtures.check(res, "Kusarra follows a 40 day Erta",
		after_erta == 160 * TrynnCalendar.MINUTES_PER_DAY,
		"expected 230400, got %d" % after_erta)
	var wrapped_start: int = TrynnCalendar.next_month_start(290 * TrynnCalendar.MINUTES_PER_DAY)
	TestFixtures.check(res, "Tek rolls into the next year",
		wrapped_start == 330 * TrynnCalendar.MINUTES_PER_DAY, "expected 475200, got %d" % wrapped_start)
	var payday: int = TrynnCalendar.first_weekday_minute(212, 1, 8)
	TestFixtures.check(res, "the first weekday of Ruadd 212 is the 2nd at 8:00 AM",
		payday == 31 * TrynnCalendar.MINUTES_PER_DAY + 480, "expected 45120, got %d" % payday)
	var date: Dictionary = TrynnCalendar.date_of(payday)
	TestFixtures.check(res, "the first weekday is never a weekend day",
		int(date["day"]) == 2 and not bool(date["weekend"]),
		"got %s %s" % [TrynnCalendar.date_text(payday), TrynnCalendar.time_text(payday)])


static func _case_month_helpers(res: Dictionary) -> void:
	for want: Array in [[212, 0, 0], [212, 5, 160], [212, 9, 290], [213, 0, 330]]:
		var first: int = TrynnCalendar.month_first_day(int(want[0]), int(want[1]))
		TestFixtures.check(res, "month %d of %d starts on day %d" % [int(want[1]), int(want[0]), int(want[2])],
			first == int(want[2]), "got %d" % first)
	var ahead: Vector2i = TrynnCalendar.step_month(212, 9, 1)
	TestFixtures.check(res, "a month after Tek 212 is Daith 213", ahead == Vector2i(213, 0), "got %s" % str(ahead))
	var back: Vector2i = TrynnCalendar.step_month(ahead.x, ahead.y, -1)
	TestFixtures.check(res, "a month before Daith 213 is Tek 212", back == Vector2i(212, 9), "got %s" % str(back))


static func _case_months_between(res: Dictionary) -> void:
	var hired: int = TrynnCalendar.START_MINUTE
	var next_month: int = TrynnCalendar.month_start_minute(212, 5) + 2 * TrynnCalendar.MINUTES_PER_DAY + 480
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
	var late: int = TrynnCalendar.month_start_minute(212, 4) + 34 * TrynnCalendar.MINUTES_PER_DAY
	var short_month: int = TrynnCalendar.month_start_minute(212, 5) \
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
		ClockRunner.STEPS == [1, 0, 5, 15, 60] and ClockRunner.STEPS[ClockRunner.Speed.PAUSE] == 0,
		"got %s" % str(ClockRunner.STEPS))
	var seen: Array[int] = []
	runner.speed_changed.connect(func(level: int) -> void: seen.append(level))
	runner.set_speed(ClockRunner.Speed.PLAY)
	TestFixtures.check(res, "set_speed reports the new speed",
		seen == [ClockRunner.Speed.PLAY] and runner.speed == ClockRunner.Speed.PLAY,
		"got %s with speed %d" % [str(seen), runner.speed])
	CampaignClock.reset()
	CampaignClock.advance_to(541)
	var play_one: int = runner.next_target()
	CampaignClock.advance_to(play_one)
	var play_two: int = runner.next_target()
	TestFixtures.check(res, "9:01 on Play snaps to 9:05 then 9:10",
		play_one == 545 and play_two == 550, "got %d then %d" % [play_one, play_two])
	CampaignClock.reset()
	CampaignClock.advance_to(555)
	runner.set_speed(ClockRunner.Speed.FAST)
	var fast_one: int = runner.next_target()
	CampaignClock.advance_to(fast_one)
	var fast_two: int = runner.next_target()
	TestFixtures.check(res, "9:15 on Fast steps to 9:30 then 9:45",
		fast_one == 570 and fast_two == 585, "got %d then %d" % [fast_one, fast_two])
	CampaignClock.reset()
	CampaignClock.advance_to(556)
	TestFixtures.check(res, "9:16 on Fast snaps onto the quarter hour at 9:30",
		runner.next_target() == 570, "got %d" % runner.next_target())
	CampaignClock.reset()
	CampaignClock.advance_to(540)
	runner.set_speed(ClockRunner.Speed.VERY_FAST)
	var very_one: int = runner.next_target()
	CampaignClock.advance_to(very_one)
	var very_two: int = runner.next_target()
	CampaignClock.advance_to(very_two)
	var very_three: int = runner.next_target()
	TestFixtures.check(res, "9:00 on Very Fast steps to 10:00, 11:00 then 12:00",
		very_one == 600 and very_two == 660 and very_three == 720,
		"got %d, %d then %d" % [very_one, very_two, very_three])
	CampaignClock.reset()
	CampaignClock.advance_to(1050)
	TestFixtures.check(res, "17:30 on Very Fast snaps onto the full hour at 18:00",
		runner.next_target() == 1080, "got %d" % runner.next_target())
	runner.set_speed(ClockRunner.Speed.PAUSE)
	TestFixtures.check(res, "a paused runner never moves the clock",
		runner.next_target() == CampaignClock.now(),
		"expected %d, got %d" % [CampaignClock.now(), runner.next_target()])
	runner.free()


static func _case_after_hours(res: Dictionary) -> void:
	var runner := ClockRunner.new()
	TestFixtures.check(res, "after hours spans 6:00 PM to 8:00 AM",
		not ClockRunner.is_after_hours(480) and not ClockRunner.is_after_hours(1079)
		and ClockRunner.is_after_hours(1080) and ClockRunner.is_after_hours(0)
		and ClockRunner.is_after_hours(479) and ClockRunner.is_after_hours(1439),
		"boundary minutes misclassified")
	CampaignClock.reset()
	CampaignClock.advance_to(1080)
	runner.set_speed(ClockRunner.Speed.SLOW)
	TestFixtures.check(res, "Slow after hours is unchanged at 1 minute",
		runner.next_target() == 1081, "got %d" % runner.next_target())
	runner.set_speed(ClockRunner.Speed.PLAY)
	var play_one: int = runner.next_target()
	CampaignClock.advance_to(play_one)
	var play_two: int = runner.next_target()
	TestFixtures.check(res, "6:00 PM on Play steps 30 minutes to 6:30 then 7:00",
		play_one == 1110 and play_two == 1140, "got %d then %d" % [play_one, play_two])
	CampaignClock.reset()
	CampaignClock.advance_to(1085)
	TestFixtures.check(res, "6:05 PM on Play snaps onto the half hour at 6:30",
		runner.next_target() == 1110, "got %d" % runner.next_target())
	CampaignClock.reset()
	CampaignClock.advance_to(1075)
	TestFixtures.check(res, "5:55 PM on Play still steps 5 minutes to 6:00",
		runner.next_target() == 1080, "got %d" % runner.next_target())
	CampaignClock.reset()
	CampaignClock.advance_to(450)
	TestFixtures.check(res, "7:30 AM on Play steps 30 minutes to 8:00",
		runner.next_target() == 480, "got %d" % runner.next_target())
	CampaignClock.advance_to(480)
	TestFixtures.check(res, "8:00 AM on Play is back to 5 minutes",
		runner.next_target() == 485, "got %d" % runner.next_target())
	runner.set_speed(ClockRunner.Speed.FAST)
	CampaignClock.reset()
	CampaignClock.advance_to(1080)
	var fast_one: int = runner.next_target()
	CampaignClock.advance_to(fast_one)
	TestFixtures.check(res, "6:00 PM on Fast steps 1 hour to 7:00 then 8:00",
		fast_one == 1140 and runner.next_target() == 1200,
		"got %d then %d" % [fast_one, runner.next_target()])
	CampaignClock.reset()
	CampaignClock.advance_to(1065)
	TestFixtures.check(res, "5:45 PM on Fast steps 15 minutes to 6:00",
		runner.next_target() == 1080, "got %d" % runner.next_target())
	runner.set_speed(ClockRunner.Speed.VERY_FAST)
	var day_zero: int = TrynnCalendar.day_index(TrynnCalendar.START_MINUTE) * CampaignClock.MINUTES_PER_DAY
	CampaignClock.reset()
	CampaignClock.advance_to(day_zero + 1080)
	TestFixtures.check(res, "6:00 PM on Fastest jumps to 8:00 AM the next day",
		runner.next_target() == day_zero + CampaignClock.MINUTES_PER_DAY + 480,
		"got %d" % runner.next_target())
	CampaignClock.reset()
	CampaignClock.advance_to(day_zero + 1300)
	TestFixtures.check(res, "9:40 PM on Fastest jumps to 8:00 AM the next day",
		runner.next_target() == day_zero + CampaignClock.MINUTES_PER_DAY + 480,
		"got %d" % runner.next_target())
	CampaignClock.reset()
	CampaignClock.advance_to(day_zero + 100)
	TestFixtures.check(res, "1:40 AM on Fastest jumps to 8:00 AM the same day",
		runner.next_target() == day_zero + 480, "got %d" % runner.next_target())
	CampaignClock.reset()
	CampaignClock.advance_to(day_zero + 480)
	TestFixtures.check(res, "8:00 AM on Fastest steps 1 hour to 9:00",
		runner.next_target() == day_zero + 540, "got %d" % runner.next_target())
	CampaignClock.reset()
	CampaignClock.advance_to(day_zero + 1020)
	var very_one: int = runner.next_target()
	CampaignClock.advance_to(very_one)
	TestFixtures.check(res, "5:00 PM on Fastest steps to 6:00 PM, then the next tick jumps",
		very_one == day_zero + 1080
		and runner.next_target() == day_zero + CampaignClock.MINUTES_PER_DAY + 480,
		"got %d then %d" % [very_one, runner.next_target()])
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
		CampaignClock.now() == TrynnCalendar.START_MINUTE + 15
		and ticks == [[TrynnCalendar.START_MINUTE, TrynnCalendar.START_MINUTE + 15]],
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
	TestFixtures.check(res, "jumping from 23:00 to 8:00 reports the new day",
		CampaignClock.now() == 43200 + ClockRunner.DAY_START and days == [30],
		"got minute %d with days %s" % [CampaignClock.now(), str(days)])
	TestFixtures.check(res, "crossing into Ruadd reports the month",
		months == [[212, 1]], "got %s" % str(months))
	days.clear()
	months.clear()
	runner.tick()
	TestFixtures.check(res, "a tick inside a day reports no boundary",
		days.is_empty() and months.is_empty(),
		"got days %s and months %s" % [str(days), str(months)])
	runner.free()


#One holder: the hold pauses, the clock stands still, the release brings the old speed back.
static func _case_hold(res: Dictionary) -> void:
	var runner := ClockRunner.new()
	var speeds: Array[int] = []
	var holds: Array[bool] = []
	var ticks: Array[Array] = []
	runner.speed_changed.connect(func(level: int) -> void: speeds.append(level))
	runner.hold_changed.connect(func(held: bool) -> void: holds.append(held))
	runner.ticked.connect(func(from_minute: int, to_minute: int) -> void:
		ticks.append([from_minute, to_minute]))
	var screen := RefCounted.new()
	runner.set_speed(ClockRunner.Speed.FAST)
	speeds.clear()
	runner.hold(screen)
	TestFixtures.check(res, "a hold pauses a running clock",
		runner.is_held() and runner.speed == ClockRunner.Speed.PAUSE
		and speeds == [ClockRunner.Speed.PAUSE] and holds == [true],
		"speed %d, speeds %s, holds %s" % [runner.speed, str(speeds), str(holds)])
	CampaignClock.reset()
	CampaignClock.advance_to(TrynnCalendar.START_MINUTE)
	runner.tick()
	runner._process(5.0)
	TestFixtures.check(res, "a held clock does not tick",
		ticks.is_empty() and CampaignClock.now() == TrynnCalendar.START_MINUTE,
		"got %d ticks at minute %d" % [ticks.size(), CampaignClock.now()])
	runner.release(screen)
	TestFixtures.check(res, "the release restores the speed from before the hold",
		not runner.is_held() and runner.speed == ClockRunner.Speed.FAST
		and speeds == [ClockRunner.Speed.PAUSE, ClockRunner.Speed.FAST] and holds == [true, false],
		"speed %d, speeds %s, holds %s" % [runner.speed, str(speeds), str(holds)])
	runner.tick()
	TestFixtures.check(res, "a released clock ticks again",
		CampaignClock.now() == TrynnCalendar.START_MINUTE + 15, "minute %d" % CampaignClock.now())
	runner.set_speed(ClockRunner.Speed.PAUSE)
	speeds.clear()
	holds.clear()
	runner.hold(screen)
	var paused_held: bool = runner.is_held() and runner.speed == ClockRunner.Speed.PAUSE
	runner.release(screen)
	TestFixtures.check(res, "a hold over Pause stays on Pause and sends no speed change",
		paused_held and runner.speed == ClockRunner.Speed.PAUSE and speeds.is_empty()
		and holds == [true, false],
		"speed %d, speeds %s, holds %s" % [runner.speed, str(speeds), str(holds)])
	runner.set_speed(ClockRunner.Speed.PLAY)
	runner.hold(screen)
	speeds.clear()
	runner.set_speed(ClockRunner.Speed.VERY_FAST)
	var during: int = runner.speed
	var quiet: bool = speeds.is_empty()
	runner.release(screen)
	TestFixtures.check(res, "set_speed during a hold stays paused and the release brings the new speed",
		during == ClockRunner.Speed.PAUSE and quiet and runner.speed == ClockRunner.Speed.VERY_FAST,
		"during %d, quiet %s, after %d" % [during, quiet, runner.speed])
	CampaignClock.reset()
	runner.free()


#Two holders and repeat holds: only the first hold and the last release move the clock.
static func _case_hold_holders(res: Dictionary) -> void:
	var runner := ClockRunner.new()
	var holds: Array[bool] = []
	runner.hold_changed.connect(func(held: bool) -> void: holds.append(held))
	var first := RefCounted.new()
	var second := RefCounted.new()
	runner.set_speed(ClockRunner.Speed.PLAY)
	runner.hold(first)
	runner.hold(first)
	runner.release(first)
	TestFixtures.check(res, "a second hold by the same holder needs no second release",
		not runner.is_held() and runner.speed == ClockRunner.Speed.PLAY and holds == [true, false],
		"held %s, speed %d, holds %s" % [runner.is_held(), runner.speed, str(holds)])
	holds.clear()
	runner.hold(first)
	runner.hold(second)
	runner.release(first)
	var one_left: bool = runner.is_held() and runner.speed == ClockRunner.Speed.PAUSE
	runner.release(second)
	TestFixtures.check(res, "two holders keep time paused until the last one releases",
		one_left and not runner.is_held() and runner.speed == ClockRunner.Speed.PLAY
		and holds == [true, false],
		"one left %s, speed %d, holds %s" % [one_left, runner.speed, str(holds)])
	holds.clear()
	runner.hold(first)
	runner.release(second)
	var still: bool = runner.is_held() and runner.speed == ClockRunner.Speed.PAUSE
	runner.release(first)
	runner.release(first)
	runner.release(second)
	TestFixtures.check(res, "a release by a non-holder changes nothing",
		still and not runner.is_held() and runner.speed == ClockRunner.Speed.PLAY
		and holds == [true, false],
		"still %s, speed %d, holds %s" % [still, runner.speed, str(holds)])
	runner.free()
