class_name ClockTests

#Campaign clock arithmetic and stamps. Run: godot --headless --path . -- --clock-tests
#Every case resets the clock first, so the suite is order independent.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_reset(res)
	_case_advance(res)
	_case_advance_to(res)
	_case_minutes_of(res)
	_case_line(res)
	_case_rollover(res)
	_case_contract_span(res)
	CampaignClock.reset()
	return TestFixtures.summarize(res, "CLOCK")


static func _case_reset(res: Dictionary) -> void:
	CampaignClock.advance(500)
	CampaignClock.reset()
	TestFixtures.check(res, "reset returns to zero", CampaignClock.now() == 0,
		"expected 0, got %d" % CampaignClock.now())
	TestFixtures.check(res, "zero stamps as D1 00:00", CampaignClock.stamp() == "D1 00:00",
		"expected D1 00:00, got %s" % CampaignClock.stamp())


static func _case_advance(res: Dictionary) -> void:
	CampaignClock.reset()
	var total: int = CampaignClock.advance(90)
	TestFixtures.check(res, "advance returns the new total", total == 90 and CampaignClock.now() == 90,
		"expected 90, got %d with now %d" % [total, CampaignClock.now()])
	TestFixtures.check(res, "90 minutes stamps as D1 01:30", CampaignClock.stamp() == "D1 01:30",
		"expected D1 01:30, got %s" % CampaignClock.stamp())
	CampaignClock.advance(0)
	CampaignClock.advance(-60)
	TestFixtures.check(res, "advance ignores zero and negative", CampaignClock.now() == 90,
		"expected 90 after +0 and -60, got %d" % CampaignClock.now())
	TestFixtures.check(res, "stamp reads an absolute minute", CampaignClock.stamp(860) == "D1 14:20",
		"expected D1 14:20, got %s" % CampaignClock.stamp(860))


static func _case_advance_to(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(600)
	var back: int = CampaignClock.advance_to(120)
	TestFixtures.check(res, "advance_to never runs backwards", back == 600 and CampaignClock.now() == 600,
		"expected 600, got %d with now %d" % [back, CampaignClock.now()])
	var forward: int = CampaignClock.advance_to(1000)
	TestFixtures.check(res, "advance_to moves forward", forward == 1000 and CampaignClock.now() == 1000,
		"expected 1000, got %d with now %d" % [forward, CampaignClock.now()])


static func _case_minutes_of(res: Dictionary) -> void:
	var cases: Array = [
		[2, "hour", 120], [1, "hours", 60], [1, "day", 1440], [3, "days", 4320],
		[45, "minute", 45], [45, "minutes", 45], [1, "round", 0], [5, "week", 0],
		[2, " Hour ", 120],
	]
	for c: Array in cases:
		var got: int = CampaignClock.minutes_of(int(c[0]), str(c[1]))
		TestFixtures.check(res, "minutes_of %d %s" % [int(c[0]), str(c[1]).strip_edges()],
			got == int(c[2]), "expected %d, got %d" % [int(c[2]), got])


static func _case_line(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(360)
	var hours: String = CampaignClock.line("respite", 360)
	TestFixtures.check(res, "line prints whole hours", hours.contains("+6 h"),
		"expected +6 h in %s" % hours)
	TestFixtures.check(res, "line ends at the current stamp", hours == "CLOCK: respite +6 h -> D1 06:00",
		"got %s" % hours)
	CampaignClock.advance(10)
	var mins: String = CampaignClock.line("breather", 10)
	TestFixtures.check(res, "line prints minutes below an hour", mins.contains("+10 min"),
		"expected +10 min in %s" % mins)
	var odd: String = CampaignClock.delta_text(90)
	TestFixtures.check(res, "delta_text prints a part hour in hours and minutes", odd == "+1 h 30 min",
		"expected +1 h 30 min, got %s" % odd)
	var part_hour: String = CampaignClock.delta_text(400)
	TestFixtures.check(res, "delta_text splits a span below a day", part_hour == "+6 h 40 min",
		"expected +6 h 40 min, got %s" % part_hour)
	var ten_days: String = CampaignClock.delta_text(14400)
	TestFixtures.check(res, "delta_text prints whole days", ten_days == "+10 d",
		"expected +10 d, got %s" % ten_days)
	var one_day: String = CampaignClock.delta_text(1440)
	TestFixtures.check(res, "delta_text prints one whole day", one_day == "+1 d",
		"expected +1 d, got %s" % one_day)
	var part_day: String = CampaignClock.delta_text(1500)
	TestFixtures.check(res, "delta_text prints a part day in days and hours", part_day == "+1 d 1 h",
		"expected +1 d 1 h, got %s" % part_day)
	var many_days: String = CampaignClock.delta_text(12000)
	TestFixtures.check(res, "delta_text splits a span above a day", many_days == "+8 d 8 h",
		"expected +8 d 8 h, got %s" % many_days)


static func _case_rollover(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(CampaignClock.MINUTES_PER_DAY)
	TestFixtures.check(res, "a full day rolls to D2", CampaignClock.stamp() == "D2 00:00",
		"expected D2 00:00, got %s" % CampaignClock.stamp())
	CampaignClock.advance(CampaignClock.MINUTES_PER_DAY + 495)
	TestFixtures.check(res, "two days and 08:15 stamps as D3 08:15", CampaignClock.stamp() == "D3 08:15",
		"expected D3 08:15, got %s" % CampaignClock.stamp())


static func _case_contract_span(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(CampaignClock.TRAVEL_MINUTES)
	CampaignClock.advance(CampaignClock.EVENT_MINUTES)
	CampaignClock.advance(CampaignClock.EVENT_GAP_MINUTES)
	CampaignClock.advance(CampaignClock.EVENT_MINUTES)
	CampaignClock.advance(CampaignClock.TRAVEL_MINUTES)
	TestFixtures.check(res, "one mishap contract spans a day", CampaignClock.now() == 1440,
		"expected 1440 minutes, got %d" % CampaignClock.now())
