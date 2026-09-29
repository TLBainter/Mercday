class_name GuiResultsTests

#The contract results panel: the timeline keys and curves, then the panel itself driven through
#set_time on the seeded preview results, a bonus payout and the fit of a one and four member team.
#Run the harness on the copy with the flag gui_results_tests written as a suite flag.

const PANEL: PackedScene = preload("res://Scenes/GUI/Results/ContractResults.tscn")

const EPS: float = 0.0001
const NEAR: float = 0.02
#A hair past a key, so a double rounding never samples the frame before it.
const TICK: float = 0.01
const FRAME_H: float = 720.0
const SUCCESS_REWARD: int = 1000
const SUCCESS_EXPENSE: int = 120
const FAIL_EXPENSE: int = 150
const BONUS_PCT: int = 10
const LEVEL_NEED: int = 160
const LEVEL_NEED_AFTER: int = 180


static func run(host: Node) -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_fresh()
	await host.get_tree().process_frame
	_case_keys(res)
	_case_verdict_curve(res)
	_case_money(res)
	_case_xp_flat(res)
	_case_xp_level(res)
	_case_pay(res)
	await _case_mount_size(res, host)
	await _case_panel_pending(res, host)
	await _case_panel_fates(res, host)
	await _case_panel_verdict(res, host)
	await _case_panel_money(res, host)
	await _case_panel_failure(res, host)
	await _case_panel_bonus(res, host)
	await _case_panel_fly(res, host)
	await _case_panel_continue(res, host)
	await _case_panel_fit(res, host)
	await _case_panel_real_view(res, host)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	return TestFixtures.summarize(res, "GUI RESULTS")


static func _fresh() -> void:
	TestFixtures.reset_generator_rolls()
	seed(7)
	GameState.set_speed(ClockRunner.Speed.PAUSE)
	GameState.start_new_game()


static func _near(a: float, b: float, span: float = EPS) -> bool:
	return absf(a - b) <= span


static func _panel(host: Node) -> ContractResults:
	var node: ContractResults = PANEL.instantiate() as ContractResults
	host.add_child(node)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.size = Vector2(1280.0, FRAME_H)
	return node


#A result built by hand, so the suite owns every number the timeline reads.
static func _made(failed: bool, count: int, bonus_pct: int) -> ContractResultData:
	var result := ContractResultData.new()
	result.entry_id = -1
	result.name = "Made Contract"
	result.difficulty = 3.0
	result.failed = failed
	result.listed_reward = SUCCESS_REWARD
	result.reward = 0 if failed else SUCCESS_REWARD
	result.expenses = FAIL_EXPENSE if failed else SUCCESS_EXPENSE
	result.bonus_pct = bonus_pct
	for i: int in count:
		var member := ResultMemberData.new()
		member.uid = 900 + i
		member.name = "Made %d" % i
		member.role = ContractResultData.ROLE_LEADER if i == 0 else "Guide"
		member.tradition = "Bowman"
		member.level_before = 3
		member.level_after = 3
		member.xp_before = 20
		member.xp_need = LEVEL_NEED
		member.xp_gained = 40
		member.hp = Vector2i(24, 40)
		member.ep = Vector2i(12, 20)
		member.mp = Vector2i(6, 10)
		member.hp_before = 40
		member.ep_before = 20
		member.mp_before = 10
		result.members.append(member)
	result.pick_mvp()
	result.assign_pay()
	return result


static func _levelled() -> ResultMemberData:
	var member := ResultMemberData.new()
	member.name = "Riser"
	member.level_before = 3
	member.level_after = 4
	member.xp_before = 120
	member.xp_need = LEVEL_NEED
	member.xp_need_after = LEVEL_NEED_AFTER
	member.xp_gained = 80
	return member


static func _flat() -> ResultMemberData:
	var member := ResultMemberData.new()
	member.name = "Steady"
	member.level_before = 3
	member.level_after = 3
	member.xp_before = 20
	member.xp_need = LEVEL_NEED
	member.xp_gained = 40
	return member


static func _dead() -> ResultMemberData:
	var member: ResultMemberData = _flat()
	member.fate = ResultMemberData.Fate.DEAD
	return member


static func _row_of_fate(result: ContractResultData, fate: int) -> int:
	for i: int in result.members.size():
		if result.members[i].fate == fate:
			return i
	return -1


static func _mvp_row(result: ContractResultData) -> int:
	for i: int in result.members.size():
		if result.members[i].mvp:
			return i
	return -1


#Case 1: the keys of the timeline and the two shared curves.
static func _case_keys(res: Dictionary) -> void:
	var t: Dictionary = {
		"BARS_START": [ResultsTimeline.BARS_START, 0.2],
		"BARS_END": [ResultsTimeline.BARS_END, 1.4],
		"FATES": [ResultsTimeline.FATES, 1.2],
		"TOLD": [ResultsTimeline.TOLD, 2.5],
		"VERDICT_IN": [ResultsTimeline.VERDICT_IN, 2.3],
		"VERDICT_DOCKED": [ResultsTimeline.VERDICT_DOCKED, 3.75],
		"XP_START": [ResultsTimeline.XP_START, 3.8],
		"REWARD_START": [ResultsTimeline.REWARD_START, 6.0],
		"EXPENSE_START": [ResultsTimeline.EXPENSE_START, 6.8],
		"NET_START": [ResultsTimeline.NET_START, 7.4],
		"PAYOUT_START": [ResultsTimeline.PAYOUT_START, 8.2],
		"BONUS_START": [ResultsTimeline.BONUS_START, 8.3],
		"BONUS_END": [ResultsTimeline.BONUS_END, 9.4],
		"FLY_SECONDS": [ResultsTimeline.FLY_SECONDS, 1.6],
	}
	var bad: Array[String] = []
	for key: String in t:
		var pair: Array = t[key]
		if not _near(float(pair[0]), float(pair[1])):
			bad.append("%s %.2f" % [key, float(pair[0])])
	TestFixtures.check(res, "every timeline key holds its prototype second", bad.is_empty(),
			TestFixtures.detail(bad, t.size(), "keys"))
	TestFixtures.check(res, "clamp01 holds the unit range",
			_near(ResultsTimeline.clamp01(-1.0), 0.0) and _near(ResultsTimeline.clamp01(2.0), 1.0),
			"-1 and 2 clamp to 0 and 1")
	TestFixtures.check(res, "the easing is soft out",
			_near(ResultsTimeline.ease_out(0.0), 0.0) and _near(ResultsTimeline.ease_out(1.0), 1.0)
			and _near(ResultsTimeline.ease_out(0.5), 0.75), "0, 0.75 and 1 at 0, 0.5 and 1")
	TestFixtures.check(res, "the fate flag turns at FATES",
			not ResultsTimeline.fates_on(1.19) and ResultsTimeline.fates_on(1.2),
			"1.19 pending, 1.2 revealed")
	TestFixtures.check(res, "the told flag turns at TOLD",
			not ResultsTimeline.told(2.49) and ResultsTimeline.told(2.5),
			"2.49 pending, 2.5 told")
	var plain: ContractResultData = _made(false, 2, 0)
	var paid: ContractResultData = _made(false, 2, BONUS_PCT)
	TestFixtures.check(res, "the end is 8.2 with no bonus and 9.7 with one",
			_near(ResultsTimeline.end_time(plain), 8.2)
			and _near(ResultsTimeline.end_time(paid), 9.7),
			"%.2f and %.2f" % [ResultsTimeline.end_time(plain), ResultsTimeline.end_time(paid)])
	TestFixtures.check(res, "the total adds the money fly",
			_near(ResultsTimeline.total_time(plain), 9.8)
			and _near(ResultsTimeline.total_time(paid), 11.3),
			"%.2f and %.2f" % [ResultsTimeline.total_time(plain),
			ResultsTimeline.total_time(paid)])
	TestFixtures.check(res, "Continue waits for the total",
			not ResultsTimeline.continue_enabled(plain, 9.79)
			and ResultsTimeline.continue_enabled(plain, 9.8), "9.79 no, 9.8 yes")
	TestFixtures.check(res, "a bar counts from before to after",
			_near(ResultsTimeline.bar_value(40, 24, 0.2), 40.0)
			and _near(ResultsTimeline.bar_value(40, 24, 1.4), 24.0)
			and ResultsTimeline.bar_value(40, 24, 0.8) < 40.0,
			"40 at the start, 24 at the end")
	TestFixtures.check(res, "the fate pop starts at one and a half",
			_near(ResultsTimeline.fate_scale(1.2), 1.5)
			and _near(ResultsTimeline.fate_scale(1.4), 1.0), "1.5 then 1.0")


#Case 2: the verdict slam, hold, shrink and flight.
static func _case_verdict_curve(res: Dictionary) -> void:
	var win: ContractResultData = _made(false, 2, 0)
	var lose: ContractResultData = _made(true, 2, 0)
	TestFixtures.check(res, "the verdict text follows the outcome",
			ResultsTimeline.verdict_text(win) == "SUCCESS!"
			and ResultsTimeline.verdict_text(lose) == "FAILURE",
			"%s and %s" % [ResultsTimeline.verdict_text(win),
			ResultsTimeline.verdict_text(lose)])
	TestFixtures.check(res, "the verdict colours follow the outcome",
			ResultsTimeline.verdict_color(win) == ResultsTimeline.SUCCESS
			and ResultsTimeline.verdict_color(lose) == ResultsTimeline.FAILURE
			and ResultsTimeline.verdict_dark(win) == ResultsTimeline.SUCCESS_DARK
			and ResultsTimeline.verdict_dark(lose) == ResultsTimeline.FAILURE_DARK,
			"green and red with their darks")
	TestFixtures.check(res, "the accent turns at the dock",
			ResultsTimeline.accent_color(win, 3.74) == ResultsTimeline.ACCENT
			and ResultsTimeline.accent_color(win, 3.75) == ResultsTimeline.SUCCESS
			and ResultsTimeline.accent_color(lose, 3.75) == ResultsTimeline.FAILURE,
			"orange until 3.75")
	var dock: float = 0.3
	TestFixtures.check(res, "the verdict slams in from two and a half times",
			_near(ResultsTimeline.verdict_scale(2.0, dock), ResultsTimeline.VERDICT_BIG),
			"2.4 before the slam")
	TestFixtures.check(res, "the verdict holds at one",
			_near(ResultsTimeline.verdict_scale(2.55, dock), 1.0, NEAR),
			"%.3f at the hold" % ResultsTimeline.verdict_scale(2.55, dock))
	TestFixtures.check(res, "the verdict bounces under a twentieth",
			ResultsTimeline.verdict_scale(2.6, dock) >= 1.0
			and ResultsTimeline.verdict_scale(2.6, dock) <= 1.0 + ResultsTimeline.BOUNCE_SIZE,
			"%.3f in the bounce" % ResultsTimeline.verdict_scale(2.6, dock))
	TestFixtures.check(res, "the verdict shrinks before it flies",
			_near(ResultsTimeline.verdict_scale(3.2, dock), ResultsTimeline.VERDICT_SMALL),
			"%.3f at 3.2" % ResultsTimeline.verdict_scale(3.2, dock))
	TestFixtures.check(res, "the verdict lands on the dock scale",
			_near(ResultsTimeline.verdict_scale(3.75, dock), dock),
			"%.3f at 3.75" % ResultsTimeline.verdict_scale(3.75, dock))
	TestFixtures.check(res, "the verdict is invisible before the slam",
			_near(ResultsTimeline.verdict_opacity(2.29), 0.0)
			and _near(ResultsTimeline.verdict_opacity(2.55), 1.0), "0 then 1")
	var center := Vector2(400.0, 300.0)
	var slot := Vector2(60.0, 40.0)
	TestFixtures.check(res, "the verdict flies from the centre to the dock",
			ResultsTimeline.verdict_position(3.2, center, slot) == center
			and ResultsTimeline.verdict_position(3.75, center, slot) == slot,
			"centre at 3.2, dock at 3.75")
	TestFixtures.check(res, "the dim rises with the slam and clears after the flight",
			_near(ResultsTimeline.dim_opacity(2.29), 0.0)
			and _near(ResultsTimeline.dim_opacity(2.55), 1.0)
			and _near(ResultsTimeline.dim_opacity(3.6), 0.0),
			"0, 1 then 0 at 3.6")


#Case 3: the money rows at every key, for a success and a failure.
static func _case_money(res: Dictionary) -> void:
	var win: ContractResultData = _made(false, 2, BONUS_PCT)
	var lose: ContractResultData = _made(true, 2, BONUS_PCT)
	var at_start: Dictionary = ResultsTimeline.money_state(win, ResultsTimeline.REWARD_START)
	var at_reward: Dictionary = ResultsTimeline.money_state(win, ResultsTimeline.REWARD_END)
	var at_expense: Dictionary = ResultsTimeline.money_state(win, ResultsTimeline.EXPENSE_END)
	var at_net: Dictionary = ResultsTimeline.money_state(win, ResultsTimeline.NET_END)
	var at_bonus: Dictionary = ResultsTimeline.money_state(win, ResultsTimeline.BONUS_END)
	TestFixtures.check(res, "the reward counts from zero to the reward",
			int(at_start["reward"]) == 0 and int(at_reward["reward"]) == SUCCESS_REWARD,
			"0 then %d" % int(at_reward["reward"]))
	TestFixtures.check(res, "the expenses count to their own key",
			int(at_reward["expenses"]) == 0
			and int(at_expense["expenses"]) == SUCCESS_EXPENSE,
			"0 at 6.8 then %d" % int(at_expense["expenses"]))
	TestFixtures.check(res, "the net counts to the reward less the expenses",
			int(at_net["net"]) == win.net(), "%d of %d" % [int(at_net["net"]), win.net()])
	TestFixtures.check(res, "the bonus counts out of the net",
			int(at_bonus["bonus"]) == win.bonus()
			and int(at_bonus["net"]) == win.net() - win.bonus(),
			"%d paid, %d left" % [int(at_bonus["bonus"]), int(at_bonus["net"])])
	TestFixtures.check(res, "the bonus row waits for the payout",
			not bool(ResultsTimeline.money_state(win, 8.19)["bonus_visible"])
			and bool(ResultsTimeline.money_state(win, 8.2)["bonus_visible"]),
			"hidden at 8.19, shown at 8.2")
	TestFixtures.check(res, "the bonus row names its share",
			String(at_bonus["bonus_label"]) == "Merc Bonus (10%)",
			String(at_bonus["bonus_label"]))
	TestFixtures.check(res, "a success keeps the plain labels",
			String(at_net["reward_label"]) == ResultsTimeline.REWARD_LABEL
			and String(at_net["net_label"]) == ResultsTimeline.NET_LABEL
			and at_net["reward_color"] == ResultsTimeline.CREAM
			and at_net["net_color"] == ResultsTimeline.SUCCESS,
			"Reward and Notes Earned in cream and green")
	var lost_early: Dictionary = ResultsTimeline.money_state(lose, 2.49)
	var lost: Dictionary = ResultsTimeline.money_state(lose, ResultsTimeline.NET_END)
	TestFixtures.check(res, "a failure forfeits the reward only once it is told",
			String(lost_early["reward_label"]) == ResultsTimeline.REWARD_LABEL
			and String(lost["reward_label"]) == ResultsTimeline.REWARD_LOST_LABEL
			and lost["reward_color"] == ResultsTimeline.MUTED,
			"plain at 2.49, forfeited at 8.0")
	TestFixtures.check(res, "a failure shows the total cost",
			String(lost["net_label"]) == ResultsTimeline.COST_LABEL
			and int(lost["net"]) == -FAIL_EXPENSE
			and lost["net_color"] == ResultsTimeline.FAILURE,
			"Total Cost %d in red" % int(lost["net"]))
	TestFixtures.check(res, "a failure pays no bonus",
			lose.bonus() == 0 and int(lost["bonus"]) == 0
			and not bool(ResultsTimeline.money_state(lose, 9.4)["bonus_visible"]),
			"no bonus on a failure")
	TestFixtures.check(res, "a failure flies the expenses out and a success the guild share",
			lose.fly_amount() == -FAIL_EXPENSE and win.fly_amount() == win.guild_share(),
			"%d out, %d in" % [lose.fly_amount(), win.fly_amount()])


#Case 4: the experience column of a member who does not level.
static func _case_xp_flat(res: Dictionary) -> void:
	var member: ResultMemberData = _flat()
	var at_start: Dictionary = ResultsTimeline.xp_state(member, ResultsTimeline.XP_START)
	var full: float = ResultsTimeline.XP_START + ResultsTimeline.XP_FILL_SPAN
	var at_end: Dictionary = ResultsTimeline.xp_state(member, full)
	TestFixtures.check(res, "the fill starts at the experience carried in",
			_near(float(at_start["fill"]), 20.0 / float(LEVEL_NEED)),
			"%.3f at the start" % float(at_start["fill"]))
	TestFixtures.check(res, "the fill ends at the experience gained",
			_near(float(at_end["fill"]), 60.0 / float(LEVEL_NEED)),
			"%.3f at the end" % float(at_end["fill"]))
	TestFixtures.check(res, "the gained text counts to the gain",
			String(at_start["text"]) == "+0 XP" and String(at_end["text"]) == "+40 XP",
			"%s then %s" % [String(at_start["text"]), String(at_end["text"])])
	TestFixtures.check(res, "the number reads out of the need",
			String(at_end["number"]) == "60 / %d" % LEVEL_NEED, String(at_end["number"]))
	TestFixtures.check(res, "no level box change without a level",
			int(at_end["level"]) == 3 and not bool(at_end["plus"])
			and not bool(at_end["glow"]), "level 3, no plus, no glow")
	TestFixtures.check(res, "the fill keeps the budget colour",
			at_end["fill_color"] == ResultsTimeline.XP_FILL
			and at_end["color"] == ResultsTimeline.XP_FILL, "one colour throughout")
	var dead: Dictionary = ResultsTimeline.xp_state(_dead(), full)
	var dead_early: Dictionary = ResultsTimeline.xp_state(_dead(), 0.5)
	TestFixtures.check(res, "a lost member gains nothing",
			String(dead["text"]) == ResultsTimeline.BLANK_TEXT
			and dead["color"] == ResultsTimeline.MUTED
			and String(dead["number"]) == ""
			and _near(float(dead["fill"]), 20.0 / float(LEVEL_NEED)),
			"a dash on a muted column")
	TestFixtures.check(res, "a lost member reads pending before the fates",
			String(dead_early["text"]) == ResultsTimeline.PENDING_TEXT
			and dead_early["color"] == ResultsTimeline.XP_FILL,
			"three dots before 1.2")
	TestFixtures.check(res, "a missing member reads pending",
			String(ResultsTimeline.xp_state(null, 5.0)["text"])
			== ResultsTimeline.PENDING_TEXT, "no member, no numbers")


#Case 5: the experience column through a level-up and its carry over.
static func _case_xp_level(res: Dictionary) -> void:
	var member: ResultMemberData = _levelled()
	var mid: Dictionary = ResultsTimeline.xp_state(member,
			ResultsTimeline.XP_START + ResultsTimeline.XP_LEVEL_SPAN)
	var glow: Dictionary = ResultsTimeline.xp_state(member,
			ResultsTimeline.XP_START + ResultsTimeline.XP_GLOW_IN + TICK)
	var plus: Dictionary = ResultsTimeline.xp_state(member,
			ResultsTimeline.XP_START + ResultsTimeline.XP_PLUS_AT + TICK)
	var carry: Dictionary = ResultsTimeline.xp_state(member,
			ResultsTimeline.XP_START + ResultsTimeline.XP_FLASH_OUT
			+ ResultsTimeline.XP_CARRY_SPAN)
	var text_full: Dictionary = ResultsTimeline.xp_state(member,
			ResultsTimeline.XP_START + ResultsTimeline.XP_TEXT_SPAN_UP)
	TestFixtures.check(res, "the bar fills to the need before the level lands",
			_near(float(mid["fill"]), 1.0), "%.3f at the fill span" % float(mid["fill"]))
	TestFixtures.check(res, "the fill flashes once the bar is full",
			glow["fill_color"] == ResultsTimeline.XP_FILL_FLASH
			or glow["fill_color"] == ResultsTimeline.XP_FILL_UP,
			"gold or pale gold while it flashes")
	TestFixtures.check(res, "the level glow runs from 1.2 to 1.9",
			bool(glow["glow"]) and not bool(ResultsTimeline.xp_state(member,
			ResultsTimeline.XP_START + ResultsTimeline.XP_GLOW_OUT + TICK)["glow"]),
			"on at 1.2, off at 1.9")
	TestFixtures.check(res, "the level box and the plus turn at 1.3",
			bool(plus["plus"]) and int(plus["level"]) == 4
			and int(mid["level"]) == 3 and not bool(mid["plus"]),
			"03 then 04 with a plus one")
	TestFixtures.check(res, "the carry over fills the new need",
			_near(float(carry["fill"]), 40.0 / float(LEVEL_NEED_AFTER))
			and int(carry["need"]) == LEVEL_NEED_AFTER,
			"%.3f of %d" % [float(carry["fill"]), int(carry["need"])])
	TestFixtures.check(res, "the carry number reads out of the new need",
			String(carry["number"]) == "40 / %d" % LEVEL_NEED_AFTER, String(carry["number"]))
	TestFixtures.check(res, "the gained text counts over the longer span",
			String(text_full["text"]) == "+80 XP"
			and String(mid["text"]) != "+80 XP",
			"%s at the end" % String(text_full["text"]))
	var no_after: ResultMemberData = _levelled()
	no_after.xp_need_after = 0
	var kept: Dictionary = ResultsTimeline.xp_state(no_after,
			ResultsTimeline.XP_START + ResultsTimeline.XP_FLASH_OUT
			+ ResultsTimeline.XP_CARRY_SPAN)
	TestFixtures.check(res, "no need after keeps the old need",
			int(kept["need"]) == LEVEL_NEED, "%d kept" % int(kept["need"]))


#Case 6: the bonus paid to each row and the notes in flight.
static func _case_pay(res: Dictionary) -> void:
	var win: ContractResultData = _made(false, 4, BONUS_PCT)
	var lose: ContractResultData = _made(true, 4, BONUS_PCT)
	var member: ResultMemberData = win.members[0]
	var paid: float = ResultsTimeline.PAY_START + ResultsTimeline.PAY_SPAN
	TestFixtures.check(res, "the pay reads plus zero until it is told",
			ResultsTimeline.pay_text(member, 0, 2.49, false) == "+0"
			and ResultsTimeline.pay_color(member, 0, 2.49, false) == ResultsTimeline.SKY,
			"plus zero in sky blue")
	TestFixtures.check(res, "the pay counts to the share",
			ResultsTimeline.pay_value(member, 0, ResultsTimeline.PAY_START) == 0
			and ResultsTimeline.pay_value(member, 0, paid) == member.pay,
			"0 then %d" % member.pay)
	TestFixtures.check(res, "a paid row turns gold",
			ResultsTimeline.pay_color(member, 0, paid, false) == ResultsTimeline.GOLD
			and ResultsTimeline.pay_text(member, 0, paid, false) == "+%d" % member.pay,
			"+%d in gold" % member.pay)
	TestFixtures.check(res, "a later row is paid later",
			ResultsTimeline.pay_value(win.members[3], 3, ResultsTimeline.PAY_START + 0.1)
			<= ResultsTimeline.pay_value(member, 0, ResultsTimeline.PAY_START + 0.1),
			"the stagger holds the fourth row back")
	TestFixtures.check(res, "a lost member is paid nothing",
			ResultsTimeline.pay_text(_dead(), 0, paid, false) == ResultsTimeline.BLANK_TEXT
			and ResultsTimeline.pay_color(_dead(), 0, paid, false) == ResultsTimeline.MUTED,
			"a muted dash")
	TestFixtures.check(res, "a failure pays nobody",
			ResultsTimeline.pay_text(lose.members[0], 0, paid, true)
			== ResultsTimeline.BLANK_TEXT
			and ResultsTimeline.pay_color(lose.members[0], 0, paid, true)
			== ResultsTimeline.MUTED, "a muted dash on every row")
	TestFixtures.check(res, "the bonus sum equals the bonus",
			_pay_sum(win) == win.bonus(), "%d of %d" % [_pay_sum(win), win.bonus()])
	var flying: Array[Dictionary] = ResultsTimeline.pay_notes(win, 8.4)
	var bad: Array[String] = []
	for note: Dictionary in flying:
		var k: int = int(note["index"])
		var p: float = float(note["progress"])
		if k < 0 or k >= win.members.size() or p <= 0.0 or p >= 1.0:
			bad.append("%d at %.2f" % [k, p])
	TestFixtures.check(res, "every flying note names a row and a place on the arc",
			not flying.is_empty() and bad.is_empty(),
			TestFixtures.detail(bad, flying.size(), "notes"))
	TestFixtures.check(res, "the notes fly only inside the payout",
			ResultsTimeline.pay_notes(win, 8.19).is_empty()
			and ResultsTimeline.pay_notes(win, 9.7).is_empty(),
			"none before 8.2 or after 9.7")
	TestFixtures.check(res, "no notes fly without a bonus",
			ResultsTimeline.pay_notes(_made(false, 2, 0), 8.4).is_empty(),
			"a plain success flies nothing")
	var from := Vector2(100.0, 200.0)
	var to := Vector2(300.0, 200.0)
	var arc: Vector2 = ResultsTimeline.note_point(from, to, 0.5)
	TestFixtures.check(res, "a note arcs over the straight line",
			ResultsTimeline.note_point(from, to, 0.0) == from
			and ResultsTimeline.note_point(from, to, 1.0) == to
			and _near(arc.x, 200.0) and _near(arc.y, 200.0 - ResultsTimeline.NOTE_ARC_PX),
			"70 px over the middle")


static func _pay_sum(result: ContractResultData) -> int:
	var total: int = 0
	for member: ResultMemberData in result.members:
		total += member.pay
	return total


#GX4F-13: the panel mounts to its full size with no anchor warning.
static func _case_mount_size(res: Dictionary, host: Node) -> void:
	var panel: ContractResults = _panel(host)
	await host.get_tree().process_frame
	TestFixtures.check(res, "the panel mounts at 1280 x %d" % int(FRAME_H),
			panel.size == Vector2(1280.0, FRAME_H), "%s" % [panel.size])
	panel.queue_free()


#Case 7: the seeded success at zero, before anything is revealed.
static func _case_panel_pending(res: Dictionary, host: Node) -> void:
	var ids: Array[int] = GameState.seed_results_preview()
	TestFixtures.check(res, "the preview seeds a success and a failure", ids.size() == 2
			and GameState.has_result(ids[0]) and GameState.has_result(ids[1]),
			"entries %s" % str(ids))
	if ids.size() < 2:
		return
	var result: ContractResultData = GameState.result_of(ids[0])
	var panel: ContractResults = _panel(host)
	panel.show_result(result)
	panel.set_time(0.0)
	await host.get_tree().process_frame
	panel.set_time(0.0)
	TestFixtures.check(res, "the panel builds one row per member",
			panel.rows().size() == result.members.size(),
			"%d of %d rows" % [panel.rows().size(), result.members.size()])
	var bad: Array[String] = []
	for i: int in panel.rows().size():
		var row: ResultRow = panel.row_of(i)
		if row.status_text() != ResultsTimeline.PENDING_TEXT:
			bad.append("status %s" % row.status_text())
		if row.xp_text() != ResultsTimeline.PENDING_TEXT:
			bad.append("xp %s" % row.xp_text())
		if row.pay_text() != "+0":
			bad.append("pay %s" % row.pay_text())
		if row.ring_color() != ResultsTimeline.RING_IDLE:
			bad.append("ring %s" % str(row.ring_color()))
		if row.overlay_shown() or row.mvp_shown() or row.filtered():
			bad.append("row %d already revealed" % i)
	TestFixtures.check(res, "every row waits before the fates", bad.is_empty(),
			TestFixtures.detail(bad, panel.rows().size(), "rows"))
	var rows_node: VBoxContainer = panel.get_node("Center/Panel/Body/Rows") as VBoxContainer
	var gap: int = rows_node.get_theme_constant("separation") if rows_node != null else -1
	TestFixtures.check(res, "the rows list keeps the prototype's 8 px gap", gap == 8,
			"separation %d" % gap)
	var xp_head: Label = panel.row_of(0).get_node("Grid/XpCol/XpHead/Key") as Label
	TestFixtures.check(res, "the experience column header reads XP",
			xp_head != null and xp_head.text == "XP",
			xp_head.text if xp_head != null else "<missing>")
	var first: ResultRow = panel.row_of(0)
	var member: ResultMemberData = result.members[0]
	TestFixtures.check(res, "the bars start at the value on departure",
			_near(first.bar_fill("HP"), float(member.hp_before) / float(maxi(1, member.hp.y)),
			NEAR), "HP at %.3f" % first.bar_fill("HP"))
	panel.set_time(ResultsTimeline.BARS_END)
	TestFixtures.check(res, "the bars end at the value on return",
			_near(first.bar_fill("HP"), float(member.hp.x) / float(maxi(1, member.hp.y)), NEAR)
			and first.bar_text("HP") == "%d/%d" % [member.hp.x, member.hp.y],
			"HP %s" % first.bar_text("HP"))
	TestFixtures.check(res, "the money box starts at zero",
			panel.notes().reward_text() == "0" and panel.notes().net_text() == "0"
			and not panel.notes().bonus_shown(),
			"reward %s, net %s" % [panel.notes().reward_text(), panel.notes().net_text()])
	TestFixtures.check(res, "Continue is disabled while the panel counts",
			not panel.continue_ready() and not panel.is_finished(),
			"disabled until the total")
	panel.queue_free()


#Case 8: the fates at 1.2 and the reveal of every ring, overlay and filter.
static func _case_panel_fates(res: Dictionary, host: Node) -> void:
	var ids: Array[int] = GameState.unclaimed_ids()
	if ids.size() < 2:
		return
	var result: ContractResultData = GameState.result_of(ids[1])
	var panel: ContractResults = _panel(host)
	panel.show_result(result)
	await host.get_tree().process_frame
	panel.set_time(ResultsTimeline.FATES)
	var bad: Array[String] = []
	for i: int in panel.rows().size():
		var row: ResultRow = panel.row_of(i)
		var member: ResultMemberData = result.members[i]
		if row.status_text() != member.fate_name():
			bad.append("status %s" % row.status_text())
		if member.alive() and row.filtered():
			bad.append("row %d filtered alive" % i)
		if not member.alive() and not row.filtered():
			bad.append("row %d unfiltered" % i)
		if not member.alive() and not row.overlay_shown():
			bad.append("row %d has no overlay" % i)
		if member.alive() and row.overlay_shown():
			bad.append("row %d overlaid alive" % i)
	TestFixtures.check(res, "the fates reveal the status, the filter and the overlay",
			bad.is_empty(), TestFixtures.detail(bad, panel.rows().size(), "rows"))
	var dead_row: int = _row_of_fate(result, ResultMemberData.Fate.DEAD)
	var caught_row: int = _row_of_fate(result, ResultMemberData.Fate.CAPTURED)
	TestFixtures.check(res, "the failure preview brings home a loss and a capture",
			dead_row >= 0 and caught_row >= 0,
			"rows %d and %d" % [dead_row, caught_row])
	if dead_row >= 0:
		TestFixtures.check(res, "a lost row rings dark red",
				panel.row_of(dead_row).ring_color() == ResultsTimeline.RING_DEAD
				and panel.row_of(dead_row).status_text() == "Deceased",
				"Deceased on a dark red ring")
	if caught_row >= 0:
		TestFixtures.check(res, "a captured row rings amber",
				panel.row_of(caught_row).ring_color() == ResultsTimeline.RING_CAPTURED
				and panel.row_of(caught_row).status_text() == "Captured",
				"Captured on an amber ring")
	if dead_row >= 0 and caught_row >= 0:
		var dead_tex: Texture2D = panel.row_of(dead_row).fate_overlay.texture
		var caught_tex: Texture2D = panel.row_of(caught_row).fate_overlay.texture
		TestFixtures.check(res,
				"the deceased overlay is the 33 x 39 skull and the captured one the 48 px bars",
				dead_tex != null and dead_tex.get_size() == Vector2(33, 39)
				and caught_tex != null and caught_tex.get_size() == Vector2(48, 48),
				"skull %s bars %s" % [dead_tex, caught_tex])
		var spot: Vector2 = panel.row_of(dead_row).fate_overlay.position
		TestFixtures.check(res, "the deceased skull sits on whole pixels at the portrait centre",
				spot == Vector2(7, 4), "at %s" % spot)
	panel.set_time(ResultsTimeline.TOLD)
	var lost: Array[String] = []
	for i: int in panel.rows().size():
		var row: ResultRow = panel.row_of(i)
		if row.mvp_shown():
			lost.append("row %d wears MVP" % i)
		if not result.members[i].alive() and row.pay_text() != ResultsTimeline.BLANK_TEXT:
			lost.append("row %d paid %s" % [i, row.pay_text()])
	TestFixtures.check(res, "a failure wears no MVP badge and pays nobody", lost.is_empty(),
			TestFixtures.detail(lost, panel.rows().size(), "rows"))
	panel.queue_free()


#Case 9: the verdict and the accent of the panel, on both outcomes.
static func _case_panel_verdict(res: Dictionary, host: Node) -> void:
	var ids: Array[int] = GameState.unclaimed_ids()
	if ids.size() < 2:
		return
	var win: ContractResultData = GameState.result_of(ids[0])
	var panel: ContractResults = _panel(host)
	panel.show_result(win)
	await host.get_tree().process_frame
	panel.set_time(2.0)
	TestFixtures.check(res, "the verdict stays hidden before the slam",
			not panel.verdict_box().visible, "hidden at 2.0")
	panel.set_time(ResultsTimeline.VERDICT_HOLD)
	var box: VerdictBox = panel.verdict_box()
	TestFixtures.check(res, "the verdict slams in with the outcome text",
			box.visible and box.verdict_text() == ResultsTimeline.SUCCESS_TEXT
			and box.verdict_color() == ResultsTimeline.SUCCESS
			and box.verdict_dark() == ResultsTimeline.SUCCESS_DARK,
			"SUCCESS! in green")
	TestFixtures.check(res, "the verdict box holds the slab size",
			box.box_size().x > 0.0 and box.box_size().y > 0.0,
			"%.0f by %.0f" % [box.box_size().x, box.box_size().y])
	TestFixtures.check(res, "the title keeps the orange accent before the dock",
			panel.title_color() == ResultsTimeline.ACCENT, "orange at 2.55")
	var big: float = box.scale.x
	panel.set_time(ResultsTimeline.VERDICT_DOCKED)
	TestFixtures.check(res, "the verdict shrinks into the dock",
			box.scale.x < big and box.scale.x > 0.0,
			"%.3f down from %.3f" % [box.scale.x, big])
	TestFixtures.check(res, "the title turns the outcome colour at the dock",
			panel.title_color() == ResultsTimeline.SUCCESS, "green at 3.75")
	TestFixtures.check(res, "the dim is gone once the verdict has flown",
			not panel.dim.visible or panel.dim.color.a <= 0.01,
			"no dim at 3.75")
	panel.set_time(ResultsTimeline.TOLD)
	var mvp: int = _mvp_row(win)
	TestFixtures.check(res, "the success names one MVP", mvp >= 0, "row %d" % mvp)
	if mvp >= 0:
		var lit: Array[String] = []
		for i: int in panel.rows().size():
			if panel.row_of(i).mvp_shown() != (i == mvp):
				lit.append("row %d" % i)
		TestFixtures.check(res, "only the MVP row wears the badge and the gold ring",
				lit.is_empty() and panel.row_of(mvp).ring_color() == ResultsTimeline.GOLD,
				TestFixtures.detail(lit, panel.rows().size(), "rows"))
	panel.queue_free()


#Case 10: the money box of the panel through the tally.
static func _case_panel_money(res: Dictionary, host: Node) -> void:
	var ids: Array[int] = GameState.unclaimed_ids()
	if ids.is_empty():
		return
	var win: ContractResultData = GameState.result_of(ids[0])
	var panel: ContractResults = _panel(host)
	panel.show_result(win)
	await host.get_tree().process_frame
	panel.set_time(ResultsTimeline.REWARD_END)
	TestFixtures.check(res, "the panel counts the reward out",
			panel.notes().reward_text() == "%d" % win.reward,
			"%s of %d" % [panel.notes().reward_text(), win.reward])
	panel.set_time(ResultsTimeline.EXPENSE_END)
	TestFixtures.check(res, "the panel counts the expenses out with a minus",
			panel.notes().expense_text() == "-%d" % win.expenses,
			"%s of %d" % [panel.notes().expense_text(), win.expenses])
	panel.set_time(ResultsTimeline.NET_END)
	TestFixtures.check(res, "the panel counts the notes earned out",
			panel.notes().net_text() == "%d" % win.net()
			and panel.notes().net_label_text() == ResultsTimeline.NET_LABEL,
			"%s of %d" % [panel.notes().net_text(), win.net()])
	TestFixtures.check(res, "the net reads green while the guild is ahead",
			panel.notes().net_color() == ResultsTimeline.SUCCESS, "green net")
	var xp_row: ResultRow = panel.row_of(0)
	panel.set_time(ResultsTimeline.XP_START + ResultsTimeline.XP_TEXT_SPAN_UP + TICK)
	var member: ResultMemberData = win.members[0]
	var wanted: String = ResultsTimeline.BLANK_TEXT
	if member.alive():
		wanted = "+%d XP" % member.xp_gained
	TestFixtures.check(res, "the experience column counts on the panel",
			xp_row.xp_text() == wanted,
			"%s of %s" % [xp_row.xp_text(), wanted])
	var up: int = -1
	for i: int in win.members.size():
		if win.members[i].levelled():
			up = i
	TestFixtures.check(res, "the preview success carries one level-up", up >= 0, "row %d" % up)
	if up >= 0:
		panel.set_time(ResultsTimeline.XP_START + ResultsTimeline.XP_PLUS_AT + TICK)
		var row: ResultRow = panel.row_of(up)
		TestFixtures.check(res, "the level box turns over with a plus one",
				row.plus_shown() and row.level_text() == "%02d" % win.members[up].level_after,
				"%s with a plus" % row.level_text())
	panel.queue_free()


#Case 11: the failure panel, its labels and the Continue style.
static func _case_panel_failure(res: Dictionary, host: Node) -> void:
	var ids: Array[int] = GameState.unclaimed_ids()
	if ids.size() < 2:
		return
	var lose: ContractResultData = GameState.result_of(ids[1])
	var panel: ContractResults = _panel(host)
	panel.show_result(lose)
	await host.get_tree().process_frame
	panel.set_time(ResultsTimeline.VERDICT_HOLD)
	TestFixtures.check(res, "the failure verdict reads failure",
			panel.verdict_box().verdict_text() == ResultsTimeline.FAILURE_TEXT
			and panel.verdict_box().verdict_color() == ResultsTimeline.FAILURE,
			"FAILURE in red")
	panel.set_time(ResultsTimeline.NET_END)
	TestFixtures.check(res, "the failure box forfeits the reward",
			panel.notes().reward_label_text() == ResultsTimeline.REWARD_LOST_LABEL,
			panel.notes().reward_label_text())
	TestFixtures.check(res, "the failure box reads a total cost",
			panel.notes().net_label_text() == ResultsTimeline.COST_LABEL
			and panel.notes().net_text() == "%d" % -lose.expenses,
			"%s %s" % [panel.notes().net_label_text(), panel.notes().net_text()])
	TestFixtures.check(res, "the failure accent turns red at the dock",
			panel.title_color() == ResultsTimeline.FAILURE, "red title")
	panel.skip_to_end()
	TestFixtures.check(res, "the failure Continue is the shared BevelButton scene in blue",
			panel.continue_button is BevelButton and panel.continue_button.kind == &"blue"
			and panel.continue_style().is_equal_approx(Color("#2b4f8a")),
			str(panel.continue_style()))
	panel.queue_free()
	var panel2: ContractResults = _panel(host)
	panel2.show_result(GameState.result_of(ids[0]))
	await host.get_tree().process_frame
	panel2.skip_to_end()
	TestFixtures.check(res, "the success Continue is the shared BevelButton scene in green",
			panel2.continue_button is BevelButton
			and panel2.continue_style().is_equal_approx(Color("#6cc36a")),
			str(panel2.continue_style()))
	panel2.queue_free()


#Case 12: a made result with a bonus: the payout, the flying notes and the pay cells.
static func _case_panel_bonus(res: Dictionary, host: Node) -> void:
	var result: ContractResultData = _made(false, 4, BONUS_PCT)
	var panel: ContractResults = _panel(host)
	panel.show_result(result)
	await host.get_tree().process_frame
	panel.set_time(ResultsTimeline.BONUS_END)
	TestFixtures.check(res, "the bonus row shows what the crew took",
			panel.notes().bonus_shown()
			and panel.notes().bonus_text() == "-%d" % result.bonus()
			and panel.notes().bonus_label_text() == "Merc Bonus (%d%%)" % BONUS_PCT,
			"%s %s" % [panel.notes().bonus_label_text(), panel.notes().bonus_text()])
	panel.set_time(ResultsTimeline.end_time(result))
	var bad: Array[String] = []
	for i: int in panel.rows().size():
		var row: ResultRow = panel.row_of(i)
		if row.pay_text() != "+%d" % result.members[i].pay:
			bad.append("row %d reads %s" % [i, row.pay_text()])
	TestFixtures.check(res, "every living row is paid its share", bad.is_empty(),
			TestFixtures.detail(bad, panel.rows().size(), "rows"))
	TestFixtures.check(res, "the bonus ends the panel later",
			_near(ResultsTimeline.end_time(result), ResultsTimeline.END_WITH_BONUS),
			"%.2f" % ResultsTimeline.end_time(result))
	panel.set_time(8.4)
	TestFixtures.check(res, "the notes are in flight during the payout",
			not ResultsTimeline.pay_notes(result, panel.time()).is_empty(),
			"%d notes at 8.4" % ResultsTimeline.pay_notes(result, panel.time()).size())
	panel.queue_free()


#Case 13: the money fly is asked for once, with the amount the result carries.
static func _case_panel_fly(res: Dictionary, host: Node) -> void:
	var result: ContractResultData = _made(false, 2, 0)
	var seen: Array[int] = []
	var grab: Callable = func(amount: int) -> void: seen.append(amount)
	GameState.money_fly_requested.connect(grab)
	var panel: ContractResults = _panel(host)
	panel.show_result(result)
	await host.get_tree().process_frame
	panel.set_time(ResultsTimeline.end_time(result) - 0.1)
	TestFixtures.check(res, "the money fly waits for the end of the tally", seen.is_empty(),
			"%d requests before the end" % seen.size())
	panel.set_time(ResultsTimeline.end_time(result))
	TestFixtures.check(res, "the money fly carries the guild share",
			seen.size() == 1 and seen[0] == result.fly_amount(),
			"%s for %d" % [str(seen), result.fly_amount()])
	panel.set_time(ResultsTimeline.total_time(result))
	TestFixtures.check(res, "the money fly is asked for once only", seen.size() == 1,
			"%d requests" % seen.size())
	panel.queue_free()
	GameState.money_fly_requested.disconnect(grab)


#Case 14: Continue marks the entry seen and reports once; skip_to_end jumps the whole tally.
static func _case_panel_continue(res: Dictionary, host: Node) -> void:
	var ids: Array[int] = GameState.unclaimed_ids()
	if ids.is_empty():
		return
	var entry: int = ids[0]
	var result: ContractResultData = GameState.result_of(entry)
	var panel: ContractResults = _panel(host)
	var told: Array[int] = []
	panel.finished.connect(func(id: int) -> void: told.append(id))
	panel.show_result(result)
	await host.get_tree().process_frame
	panel.set_time(ResultsTimeline.NET_END)
	panel.press_continue()
	TestFixtures.check(res, "Continue does nothing while the panel counts",
			told.is_empty() and GameState.is_unclaimed(entry),
			"%d reports, still unclaimed" % told.size())
	panel.skip_to_end()
	TestFixtures.check(res, "skip_to_end lands on the total",
			_near(panel.time(), ResultsTimeline.total_time(result))
			and panel.is_finished() and panel.continue_ready(),
			"%.2f of %.2f" % [panel.time(), ResultsTimeline.total_time(result)])
	TestFixtures.check(res, "the close button appears with Continue",
			panel.close_button.visible, "the X is up")
	panel.press_continue()
	panel.press_continue()
	TestFixtures.check(res, "Continue reports the entry once",
			told.size() == 1 and told[0] == entry, "%s for entry %d" % [str(told), entry])
	TestFixtures.check(res, "Continue marks the entry seen",
			not GameState.is_unclaimed(entry), "entry %d claimed" % entry)
	panel.queue_free()


#Case 15: one member and four members both fit the frame with nothing to scroll.
static func _case_panel_fit(res: Dictionary, host: Node) -> void:
	var sizes: Array[float] = []
	for count: int in [1, 4]:
		var panel: ContractResults = _panel(host)
		panel.show_result(_made(false, count, BONUS_PCT))
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		panel.set_time(ResultsTimeline.total_time(panel.result()))
		await host.get_tree().process_frame
		sizes.append(panel.panel_size().y)
		TestFixtures.check(res, "a %d member panel fits the frame" % count,
				panel.panel_size().y < FRAME_H and panel.panel_size().x >= 900.0,
				"%.0f by %.0f" % [panel.panel_size().x, panel.panel_size().y])
		var scrolls: Array[String] = []
		for node: Node in panel.find_children("*", "ScrollContainer", true, false):
			scrolls.append(node.name)
		TestFixtures.check(res, "nothing on a %d member panel scrolls" % count,
				scrolls.is_empty(), TestFixtures.detail(scrolls, 1, "scrollers"))
		panel.queue_free()
		await host.get_tree().process_frame
	TestFixtures.check(res, "four rows are taller than one",
			sizes.size() == 2 and sizes[1] > sizes[0],
			"%.0f then %.0f" % [sizes[0], sizes[1]])


static func _real_member(uid: int, fate: int) -> ResultMemberData:
	var member := ResultMemberData.new()
	member.uid = uid
	member.name = "Real %d" % uid
	member.role = "Guide"
	member.tradition = "Bowman"
	member.fate = fate
	member.level_before = 3
	member.level_after = 3
	member.xp_before = 20
	member.xp_need = LEVEL_NEED
	member.xp_gained = 40
	member.hp = Vector2i(24, 40)
	member.ep = Vector2i(12, 20)
	member.mp = Vector2i(6, 10)
	member.hp_before = 40
	member.ep_before = 20
	member.mp_before = 10
	return member


#Case 16: a merc of GameState.mercs marked dead or held captive still shows a portrait; a
#member with no matching merc anywhere still hides it (GX2I-01).
static func _case_panel_real_view(res: Dictionary, host: Node) -> void:
	if GameState.mercs.size() < 2:
		return
	var dead_merc: MercenaryData = GameState.mercs[0]
	var captive_merc: MercenaryData = GameState.mercs[1]
	var was_dead: bool = dead_merc.is_dead
	dead_merc.is_dead = true
	MercPool.add_captive(captive_merc, "Escort", "Aerdis", "Day 1")
	GameState.refresh_views()
	var result := ContractResultData.new()
	result.entry_id = -1
	result.name = "Real View Contract"
	result.difficulty = 3.0
	result.failed = true
	result.members.append(_real_member(dead_merc.merc_uid, ResultMemberData.Fate.DEAD))
	result.members.append(_real_member(captive_merc.merc_uid, ResultMemberData.Fate.CAPTURED))
	result.members.append(_real_member(-999999, ResultMemberData.Fate.DEAD))
	var panel: ContractResults = _panel(host)
	panel.show_result(result)
	await host.get_tree().process_frame
	panel.set_time(ResultsTimeline.FATES)
	TestFixtures.check(res, "a real dead merc still shows a portrait",
			panel.row_of(0).portrait_shown(), "row 0 uid %d" % dead_merc.merc_uid)
	TestFixtures.check(res, "a real captive merc still shows a portrait",
			panel.row_of(1).portrait_shown(), "row 1 uid %d" % captive_merc.merc_uid)
	TestFixtures.check(res, "an unknown uid still hides the portrait",
			not panel.row_of(2).portrait_shown(), "row 2 unknown uid")
	panel.queue_free()
	dead_merc.is_dead = was_dead
	MercPool.take_captive(captive_merc.merc_uid)
	GameState.refresh_views()
