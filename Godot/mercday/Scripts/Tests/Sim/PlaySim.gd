class_name PlaySim
#Playability sim: a new game on the designer's start, run day by day through the clock under SimPolicy.

#Summary lines printed since launch; SimTests reads it instead of stdout.
static var summaries: int = 0


#True when every threshold held over the run.
static func run(host: Node, days: int, seed_value: int) -> bool:
	var started_ms: int = Time.get_ticks_msec()
	var pinned: Array[String] = ContractLibrary.pinned_names.duplicate()
	var previous_seed: int = PromotionsManager.fixed_seed
	TestFixtures.reset_generator_rolls()
	seed(seed_value)
	PromotionsManager.fixed_seed = seed_value
	ContractLibrary.pinned_names = [] as Array[String]
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()
	GameState.seed_round(seed_value)
	var first_day: int = TrynnCalendar.day_index(CampaignClock.now())
	var c: Dictionary = SimCounters.new_state(first_day)
	c["wins_base"] = GuildRecord.guild.successes
	c["losses_base"] = GuildRecord.guild.failures
	c["dead_last"] = int(GameState.get("_dead_counted"))
	SimCounters.end_of_day(c)
	var on_posted: Callable = func(count: int) -> void: c["posted"] = int(c["posted"]) + count
	var on_rejected: Callable = func(_entry_id: int) -> void: c["rejected"] = int(c["rejected"]) + 1
	GameState.contracts_posted.connect(on_posted)
	GameState.contract_rejected.connect(on_rejected)
	for line: String in SimReport.header_lines(days, seed_value, _plan_name()):
		print(line)
	var reported: int = int(first_day / float(_week_days())) - 1
	var last_day: int = first_day
	for i: int in range(days):
		if i > 0 and not await _advance_day(host):
			print("PLAYABILITY: the clock stopped before day %d" % (i + 1))
			break
		last_day = TrynnCalendar.day_index(CampaignClock.now())
		SimCounters.after_round(c)
		SimPolicy.act(c)
		SimCounters.end_of_day(c)
		if posmod(last_day, _week_days()) == SimThresholds.VERDICT_WEEKDAY:
			var key: int = int(last_day / float(_week_days())) - 1
			while reported < key:
				reported += 1
				_week_row(c, reported, last_day, first_day, last_day)
	var end_key: int = int(last_day / float(_week_days()))
	while reported < end_key:
		reported += 1
		_week_row(c, reported, last_day, first_day, last_day)
	GameState.contracts_posted.disconnect(on_posted)
	GameState.contract_rejected.disconnect(on_rejected)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	var held: bool = SimReport.finish(c)
	summaries += 1
	print("PLAYABILITY WALL: %.1f s" % ((Time.get_ticks_msec() - started_ms) / 1000.0))
	ContractLibrary.pinned_names = pinned
	PromotionsManager.fixed_seed = previous_seed
	return held


static func _week_days() -> int:
	return TrynnCalendar.WEEKDAYS.size()


#A week is full when the run saw every one of its rounds (the start day has none).
static func _week_row(c: Dictionary, key: int, day_index: int, first_day: int, last_day: int) -> void:
	var start: int = key * _week_days()
	var partial: bool = start <= first_day or start + _week_days() - 1 > last_day
	var gen: int = SimCounters.week_generated(c, key)
	(c["weeks"] as Array).append({"key": key, "gen": gen, "partial": partial})
	var verdict: String = "partial" if partial else ("ok" if gen >= SimThresholds.GEN_MIN_PER_WEEK else "LOW")
	print(SimReport.row(c, key, day_index - int(c["first_day"]), verdict))


#Ticks the GameState clock to 8:00 of the next day so the day and month signals fire as in play.
static func _advance_day(host: Node) -> bool:
	var target: int = TrynnCalendar.day_index(CampaignClock.now()) + 1
	var guard: int = 0
	GameState.set_speed(ClockRunner.Speed.VERY_FAST)
	while guard < SimThresholds.DAY_TICK_GUARD:
		var now: int = CampaignClock.now()
		if TrynnCalendar.day_index(now) >= target and TrynnCalendar.minute_of_day(now) >= ClockRunner.DAY_START:
			break
		await GameState.clock.tick()
		if CampaignClock.now() == now:
			await host.get_tree().process_frame
		guard += 1
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	return guard < SimThresholds.DAY_TICK_GUARD


static func _plan_name() -> String:
	var plan: int = SubscriptionManager.plan()
	for key: String in SubscriptionManager.Plan.keys():
		if int(SubscriptionManager.Plan[key]) == plan:
			return key
	return str(plan)
