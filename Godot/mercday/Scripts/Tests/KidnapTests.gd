class_name KidnapTests
#Run: godot --headless --path . -- --kidnap-tests
#The battle kidnap and the Respite kidnap: eligibility, the roll, the grapple, the drag and the settle.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_fresh()
	MercPool.clear()
	_case_humanoid(res)
	_case_gate_aware(res)
	_case_team_threshold(res)
	_case_edge_closeness(res)
	_case_bonus_cap(res)
	_case_grapple_estimate(res)
	_case_reach(res)
	_case_roll_before_flee(res)
	_case_roll_each_turn(res)
	_case_force_team_flee(res)
	_case_grapple_success(res)
	_case_grapple_failure(res)
	_case_pending_give_up(res)
	_case_drag_pace(res)
	_case_drag_cell(res)
	_case_grapple_broken(res)
	_case_captor_death(res)
	_case_escape(res)
	_case_remove_from_field_reason(res)
	_case_settle(res)
	_case_trigger_candidates(res)
	_case_respite_pair(res)
	_case_respite_target(res)
	_case_notice_worst(res)
	_case_break_free_combined(res)
	_case_break_free_contested(res)
	_case_respite_to_battle(res)
	_case_respite_capture(res)
	_case_respite_no_mark(res)
	_case_mark_name(res)
	_case_held_weapon_grapple(res)
	_fresh()
	MercPool.clear()
	return TestFixtures.summarize(res, "KIDNAP")


static func _fresh() -> void:
	KidnapSystem.reset()
	FleeSystem.reset()
	CheckSystem.forced_rolls.clear()


static func _reset_trigger() -> void:
	EventTrigger.forced_d100 = -1
	EventTrigger.missed_respites = 0
	EventTrigger.last_line = ""
	var config: ContractConfig = ContractLibrary.config()
	if config != null:
		config.force_trigger_event = ""


#A hand merc with an explicit stat dictionary, so every check threshold is arithmetic.
static func _merc(merc_name: String, extras: Dictionary = {}) -> MercenaryData:
	return TestFixtures.fixed_merc(merc_name, extras)


static func _hominid(merc_name: String, extras: Dictionary = {}) -> MercenaryData:
	var m := _merc(merc_name, extras)
	m.creature_types.append("Hominid")
	return m


static func _state(a: Array[MercenaryData], b: Array[MercenaryData],
		field: BattlefieldArea = null) -> BattleState:
	return TestFixtures.battle_state(a, b, field)


#One merc a side, the shape most case functions open with.
static func _duo(one: MercenaryData, two: MercenaryData, field: BattlefieldArea = null) -> BattleState:
	var a: Array[MercenaryData] = [one]
	var b: Array[MercenaryData] = [two]
	return _state(a, b, field)


#Grappled with this captor as the source, the way a landed grapple leaves it.
static func _grapple(captive: MercenaryData, captor: MercenaryData) -> bool:
	var rm: Array[String] = ["action:break_free"]
	return ConstStates.apply_state(captive, ConstStates.GRAPPLED, captor, "", "engine:test", rm)


static func _run(team: Array[MercenaryData]) -> ContractRun:
	var r := ContractRun.new()
	var c := ContractData.new()
	c.contract_type = "Escort"
	r.contract = c
	var loc := LocationData.new()
	loc.location_name = "Aerdis"
	r.location = loc
	r.team = team
	return r


#A run on the loaded wilderness location, so the Trigger rows are in scope.
static func _wild_run(team: Array[MercenaryData]) -> ContractRun:
	var r := ContractRun.new()
	r.location = DataManager.locations.get("Aerdis", null) as LocationData
	r.team = team
	return r


static func _has_line(lines: Array[String], want: String) -> bool:
	for line: String in lines:
		if line == want:
			return true
	return false


static func _has_prefix(lines: Array[String], prefix: String) -> bool:
	for line: String in lines:
		if line.begins_with(prefix):
			return true
	return false


static func _event_name(e: EventData) -> String:
	return e.event_name if e != null else "null"


static func _names(mercs: Array[MercenaryData]) -> Array[String]:
	var out: Array[String] = []
	for merc: MercenaryData in mercs:
		if merc != null:
			out.append(merc.merc_name)
	return out


static func _case_humanoid(res: Dictionary) -> void:
	_fresh()
	var yes: MercenaryData = _hominid("Bandit")
	var blank: MercenaryData = _merc("Blank")
	var beast: MercenaryData = _merc("Wolf")
	beast.creature_types.append("Beast")
	TestFixtures.check(res, "only a Hominid kidnaps",
		KidnapSystem.is_humanoid(yes) and not KidnapSystem.is_humanoid(blank)
		and not KidnapSystem.is_humanoid(beast),
		"hominid %s blank %s beast %s" % [KidnapSystem.is_humanoid(yes),
		KidnapSystem.is_humanoid(blank), KidnapSystem.is_humanoid(beast)])


static func _case_gate_aware(res: Dictionary) -> void:
	_fresh()
	var guard: MercenaryData = _hominid("Guard")
	var hot: MercenaryData = _hominid("Hot", {"flee": 60.0})
	var cold: MercenaryData = _hominid("Cold", {"flee": 5.0})
	var a: Array[MercenaryData] = [guard]
	var b: Array[MercenaryData] = [hot, cold]
	var st: BattleState = _state(a, b)
	hot.current_hp = 12
	cold.current_hp = 12
	var over: float = KidnapSystem.gate_aware_chance(hot, st)
	var under: float = KidnapSystem.gate_aware_chance(cold, st)
	var average: float = KidnapSystem.team_flee_average(st, 1)
	TestFixtures.check(res, "an enemy under the gate contributes nothing",
		is_equal_approx(under, 0.0) and is_equal_approx(FleeSystem.swing(cold, st), 40.0),
		"chance %.1f swing %.1f" % [under, FleeSystem.swing(cold, st)])
	TestFixtures.check(res, "an enemy over the gate contributes its clamped chance",
		is_equal_approx(over, 100.0), "chance %.1f" % over)
	TestFixtures.check(res, "the team average is the mean of the two",
		is_equal_approx(average, 50.0), "average %.4f" % average)


static func _case_team_threshold(res: Dictionary) -> void:
	_fresh()
	var guard: MercenaryData = _hominid("Guard")
	var hot: MercenaryData = _hominid("Hot", {"flee": 60.0})
	var cold: MercenaryData = _hominid("Cold", {"flee": 5.0})
	var stone: MercenaryData = _hominid("Stone", {"flee": 90.0})
	stone.passive_effects.append("immune:terrified")
	var flat_a: Array[MercenaryData] = [guard]
	var flat_b: Array[MercenaryData] = [hot, cold, stone]
	var flat: BattleState = _state(flat_a, flat_b)
	hot.current_hp = 12
	cold.current_hp = 12
	stone.current_hp = 12
	var even: float = KidnapSystem.team_flee_average(flat, 1)
	TestFixtures.check(res, "an average of exactly 50 opens no kidnap roll",
		is_equal_approx(even, 50.0) and not KidnapSystem.team_ready(hot, flat),
		"average %.4f ready %s" % [even, KidnapSystem.team_ready(hot, flat)])
	var watch: MercenaryData = _hominid("Watch")
	var one: MercenaryData = _hominid("One", {"flee": 26.8})
	var two: MercenaryData = _hominid("Two", {"flee": 26.8})
	var three: MercenaryData = _hominid("Three", {"flee": 26.8})
	var four: MercenaryData = _hominid("Four", {"flee": 0.0})
	var ready_a: Array[MercenaryData] = [watch]
	var ready_b: Array[MercenaryData] = [one, two, three, four]
	var ready: BattleState = _state(ready_a, ready_b)
	for merc: MercenaryData in ready_b:
		merc.current_hp = 12
	var tipped: float = KidnapSystem.team_flee_average(ready, 1)
	TestFixtures.check(res, "an average just over 50 opens kidnap rolls",
		tipped > 50.0 and tipped < 50.2 and KidnapSystem.team_ready(one, ready),
		"average %.4f ready %s" % [tipped, KidnapSystem.team_ready(one, ready)])
	_fresh()
	var watcher: MercenaryData = _merc("Watcher", {"vigor": 1})
	var calm: MercenaryData = _hominid("Calm", {"flee": 30.0, "base_success_chance": 100.0})
	calm.passive_effects.append("immune:terrified")
	var runner: MercenaryData = _hominid("Runner", {"flee": 30.0})
	var imm_a: Array[MercenaryData] = [watcher]
	var imm_b: Array[MercenaryData] = [calm, runner]
	var imm: BattleState = _state(imm_a, imm_b)
	calm.current_hp = 15
	runner.current_hp = 15
	watcher.current_hp = 20
	TestFixtures.place(imm, calm, Vector2i(12, 12))
	TestFixtures.place(imm, watcher, Vector2i(12, 13))
	TestFixtures.place(imm, runner, Vector2i(12, 11))
	KidnapSystem.forced_rolls.append(1)
	var quiet: Array[String] = []
	var rolled: bool = KidnapSystem.start_of_turn(calm, imm, quiet)
	TestFixtures.check(res, "a Terrified-immune enemy never rolls to kidnap",
		not rolled and KidnapSystem.rolls_made == 0 and not _has_prefix(quiet, "  KIDNAP ROLL:")
		and KidnapSystem.team_ready(calm, imm),
		"rolled %s rolls %d ready %s lines %s" % [rolled, KidnapSystem.rolls_made,
		KidnapSystem.team_ready(calm, imm), str(quiet)])
	KidnapSystem.forced_rolls.clear()


static func _case_edge_closeness(res: Dictionary) -> void:
	_fresh()
	var mover: MercenaryData = _merc("Mover")
	var a: Array[MercenaryData] = [mover]
	var b: Array[MercenaryData] = []
	var st: BattleState = _state(a, b)
	TestFixtures.place(st, mover, Vector2i(0, 10))
	var border: float = KidnapSystem.edge_closeness(mover, st)
	TestFixtures.place(st, mover, Vector2i(6, 6))
	var half: float = KidnapSystem.edge_closeness(mover, st)
	TestFixtures.place(st, mover, Vector2i(12, 12))
	var middle: float = KidnapSystem.edge_closeness(mover, st)
	TestFixtures.check(res, "a mover on the border is fully close",
		is_equal_approx(border, 1.0), "closeness %.4f" % border)
	TestFixtures.check(res, "a mover halfway in returns the expected fraction",
		is_equal_approx(half, 0.5), "closeness %.4f" % half)
	TestFixtures.check(res, "the map centre is the lowest closeness on the field",
		is_equal_approx(middle, 1.0 / 12.0) and middle > 0.0 and middle < half,
		"closeness %.4f" % middle)


static func _case_bonus_cap(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var grabber: MercenaryData = _merc("Grabber", {"base_success_chance": 100.0, "flee": 80.0})
	var st: BattleState = _duo(mark, grabber)
	TestFixtures.place(st, grabber, Vector2i(0, 0))
	TestFixtures.place(st, mark, Vector2i(1, 0))
	var closeness: float = KidnapSystem.edge_closeness(grabber, st)
	var bonus: float = KidnapSystem.kidnap_bonus(grabber, mark, st, true)
	var chance: float = KidnapSystem.kidnap_chance(grabber, mark, st, true)
	TestFixtures.check(res, "likelihood and closeness of 1 give the full 50 point bonus",
		is_equal_approx(closeness, 1.0) and is_equal_approx(bonus, 50.0),
		"closeness %.4f bonus %.1f" % [closeness, bonus])
	TestFixtures.check(res, "the total kidnap chance clamps at 100 percent",
		is_equal_approx(chance, 100.0), "chance %.1f from flee %.1f" % [chance,
		KidnapSystem.flee_chance(grabber, st)])


static func _case_grapple_estimate(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var grabber: MercenaryData = _merc("Grabber", {"base_success_chance": 100.0})
	var st: BattleState = _duo(mark, grabber)
	TestFixtures.place(st, grabber, Vector2i(0, 10))
	TestFixtures.place(st, mark, Vector2i(1, 10))
	var blind: float = KidnapSystem.grapple_estimate(grabber, mark, st)
	var unrelated: Array[String] = ["immune:terrified"]
	grabber.known_immunities[mark] = unrelated
	var other: float = KidnapSystem.grapple_estimate(grabber, mark, st)
	var seen: Array[String] = ["immune:" + StateTokens.normalize_token(ConstStates.GRAPPLED)]
	grabber.known_immunities[mark] = seen
	var known: float = KidnapSystem.grapple_estimate(grabber, mark, st)
	var no_state: float = KidnapSystem.grapple_estimate(grabber, mark, null)
	TestFixtures.check(res, "a known Grappled immunity zeroes the estimate",
		is_equal_approx(known, 0.0), "estimate %.4f from blind %.4f" % [known, blind])
	TestFixtures.check(res, "an unrelated known immunity leaves the estimate alone",
		is_equal_approx(other, blind) and blind > 0.9,
		"estimate %.4f blind %.4f" % [other, blind])
	TestFixtures.check(res, "a null state consults no knowledge",
		is_equal_approx(no_state, blind), "estimate %.4f blind %.4f" % [no_state, blind])


static func _case_reach(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var grabber: MercenaryData = _merc("Grabber", {"base_success_chance": 100.0})
	var st: BattleState = _duo(mark, grabber)
	TestFixtures.place(st, mark, Vector2i(0, 0))
	TestFixtures.place(st, grabber, Vector2i(5, 0))
	var far: Dictionary = KidnapSystem.best_target(grabber, st)
	TestFixtures.place(st, grabber, Vector2i(4, 0))
	var near: Dictionary = KidnapSystem.best_target(grabber, st)
	TestFixtures.check(res, "a merc five paces away is out of reach",
		far.get("merc") == null, "target %s" % str(far.get("merc")))
	TestFixtures.check(res, "a merc four paces away is in reach",
		near.get("merc") == mark and float(near.get("chance", 0.0)) > 0.9,
		"target %s chance %.4f" % [str(near.get("merc")), float(near.get("chance", 0.0))])


#The eligible team: one enemy at 15 of 20 HP with flee 30 makes an average of 55.
static func _ready_state(grabber: MercenaryData, guard: MercenaryData) -> BattleState:
	var st: BattleState = _duo(guard, grabber)
	grabber.current_hp = 15
	guard.current_hp = 20
	return st


static func _case_roll_before_flee(res: Dictionary) -> void:
	_fresh()
	var guard: MercenaryData = _merc("Guard", {"vigor": 1})
	var grabber: MercenaryData = _hominid("Grabber", {"flee": 30.0, "base_success_chance": 100.0})
	var st: BattleState = _ready_state(grabber, guard)
	TestFixtures.place(st, grabber, Vector2i(12, 12))
	TestFixtures.place(st, guard, Vector2i(12, 13))
	var flee: float = KidnapSystem.flee_chance(grabber, st)
	var bonus: float = KidnapSystem.kidnap_bonus(grabber, guard, st, false)
	var chance: float = clampf(flee + bonus, 0.0, 100.0)
	CheckSystem.forced_rolls.append(50)
	KidnapSystem.forced_rolls.append(100)
	var miss: Array[String] = []
	var tried: bool = KidnapSystem.start_of_turn(grabber, st, miss)
	var head: String = "  KIDNAP ROLL: Grabber d100 100 vs %.1f%% (flee %.1f + bonus %.1f) target Guard" % [
		chance, flee, bonus]
	TestFixtures.check(res, "a failed kidnap roll leaves the turn alone",
		not tried and _has_line(miss, head + " -> tries") and not st.kidnap_triggered,
		"passed %s lines %s" % [tried, str(miss)])
	KidnapSystem.forced_rolls.append(1)
	var hit: Array[String] = []
	var passed: bool = KidnapSystem.start_of_turn(grabber, st, hit)
	var head2: String = "  KIDNAP ROLL: Grabber d100 1 vs %.1f%% (flee %.1f + bonus %.1f) target Guard" % [
		chance, flee, bonus]
	TestFixtures.check(res, "a passed kidnap roll takes the turn",
		passed and _has_line(hit, head2 + " -> passes") and st.kidnap_triggered
		and st.kidnap_pending == grabber and st.kidnap_pending_target == guard,
		"passed %s lines %s" % [passed, str(hit)])
	TestFixtures.check(res, "the kidnap roll draws no flee check",
		CheckSystem.forced_rolls.size() == 1 and FleeSystem.is_fleeing(grabber),
		"check dice left %d fleeing %s" % [CheckSystem.forced_rolls.size(),
		FleeSystem.is_fleeing(grabber)])
	CheckSystem.forced_rolls.clear()


static func _case_roll_each_turn(res: Dictionary) -> void:
	_fresh()
	var guard: MercenaryData = _merc("Guard", {"vigor": 1})
	var grabber: MercenaryData = _hominid("Grabber", {"flee": 30.0, "base_success_chance": 100.0})
	var st: BattleState = _ready_state(grabber, guard)
	TestFixtures.place(st, grabber, Vector2i(12, 12))
	TestFixtures.place(st, guard, Vector2i(12, 13))
	KidnapSystem.forced_rolls.append(100)
	KidnapSystem.forced_rolls.append(100)
	var one: Array[String] = []
	KidnapSystem.start_of_turn(grabber, st, one)
	KidnapSystem.start_of_turn(grabber, st, one)
	TestFixtures.check(res, "a second eligible turn rolls again",
		KidnapSystem.rolls_made == 2 and one.size() == 2,
		"rolls %d lines %d" % [KidnapSystem.rolls_made, one.size()])
	grabber.flee_intent = true
	FleeSystem.forced[grabber] = true
	var fleeing: Array[String] = []
	var rolled: bool = KidnapSystem.start_of_turn(grabber, st, fleeing)
	TestFixtures.check(res, "a fleeing enemy makes no kidnap roll",
		not rolled and KidnapSystem.rolls_made == 2 and fleeing.is_empty(),
		"rolls %d lines %d" % [KidnapSystem.rolls_made, fleeing.size()])
	_fresh()
	var calm_guard: MercenaryData = _merc("Calm Guard", {"vigor": 1})
	var calm: MercenaryData = _hominid("Calm", {"flee": 5.0, "base_success_chance": 100.0})
	var quiet: BattleState = _ready_state(calm, calm_guard)
	TestFixtures.place(quiet, calm, Vector2i(12, 12))
	TestFixtures.place(quiet, calm_guard, Vector2i(12, 13))
	var low: Array[String] = []
	var low_rolled: bool = KidnapSystem.start_of_turn(calm, quiet, low)
	TestFixtures.check(res, "a team average of 50 or less makes no kidnap roll",
		not low_rolled and KidnapSystem.rolls_made == 0 and low.is_empty(),
		"average %.1f rolls %d" % [KidnapSystem.team_flee_average(quiet, 1),
		KidnapSystem.rolls_made])


static func _case_force_team_flee(res: Dictionary) -> void:
	_fresh()
	var guard: MercenaryData = _merc("Guard", {"vigor": 1})
	var grabber: MercenaryData = _hominid("Grabber", {"flee": 30.0, "base_success_chance": 100.0})
	var ally: MercenaryData = _hominid("Ally", {"flee": 30.0})
	ally.passive_effects.append("immune:terrified")
	var a: Array[MercenaryData] = [guard]
	var b: Array[MercenaryData] = [grabber, ally]
	var st: BattleState = _state(a, b)
	grabber.current_hp = 15
	ally.current_hp = 15
	guard.current_hp = 20
	TestFixtures.place(st, grabber, Vector2i(0, 10))
	TestFixtures.place(st, ally, Vector2i(0, 11))
	TestFixtures.place(st, guard, Vector2i(1, 10))
	KidnapSystem.forced_rolls.append(1)
	var lines: Array[String] = []
	var passed: bool = KidnapSystem.start_of_turn(grabber, st, lines)
	TestFixtures.check(res, "a passed roll breaks off the whole crew",
		passed and grabber.flee_intent and ally.flee_intent and grabber.flee_abandons
		and ally.flee_abandons and ally.flee_escape_paces == 0
		and FleeSystem.forced.has(grabber) and FleeSystem.forced.has(ally),
		"intent %s/%s forced %s/%s" % [grabber.flee_intent, ally.flee_intent,
		FleeSystem.forced.has(grabber), FleeSystem.forced.has(ally)])
	TestFixtures.check(res, "a Terrified immune ally runs without the state",
		ConstStates.is_immune(ally, ConstStates.TERRIFIED)
		and not ConstStates.has_state(ally, ConstStates.TERRIFIED) and ally.flee_intent,
		"immune %s state %s" % [ConstStates.is_immune(ally, ConstStates.TERRIFIED),
		ConstStates.has_state(ally, ConstStates.TERRIFIED)])
	TestFixtures.check(res, "the break off line counts the allies",
		_has_line(lines, "  KIDNAP FLEE: Grabber and 1 allies break off"), str(lines))


static func _case_grapple_success(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var grabber: MercenaryData = _hominid("Grabber", {"base_success_chance": 100.0})
	var st: BattleState = _duo(mark, grabber)
	TestFixtures.place(st, grabber, Vector2i(0, 10))
	TestFixtures.place(st, mark, Vector2i(1, 10))
	st.kidnap_triggered = true
	st.kidnap_pending = grabber
	st.kidnap_pending_target = mark
	grabber.current_ap = 2
	CheckSystem.forced_rolls.append(50)
	CheckSystem.forced_rolls.append(50)
	CheckSystem.forced_rolls.append(99)
	CheckSystem.forced_rolls.append(99)
	var lines: Array[String] = []
	KidnapSystem.run_turn(grabber, st, lines, 0)
	TestFixtures.check(res, "a landed grapple registers the pair",
		st.kidnap_captor.get(grabber) == mark and KidnapSystem.drag_size(grabber) == 1
		and KidnapSystem.kidnaps_total == 1,
		"captive %s drag %d kidnaps %d" % [str(st.kidnap_captor.get(grabber)),
		KidnapSystem.drag_size(grabber), KidnapSystem.kidnaps_total])
	TestFixtures.check(res, "a landed grapple clears the pending kidnapper",
		st.kidnap_pending == null and st.kidnap_pending_target == null and not st.kidnap_closed,
		"pending %s closed %s" % [str(st.kidnap_pending), st.kidnap_closed])
	TestFixtures.check(res, "the grapple line reads holds",
		_has_line(lines, "  GRAPPLE: Grabber vs Mark -> holds")
		and CheckSystem.forced_rolls.is_empty(),
		"dice left %d lines %s" % [CheckSystem.forced_rolls.size(), str(lines)])
	CheckSystem.forced_rolls.clear()


static func _case_grapple_failure(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var clumsy: MercenaryData = _hominid("Clumsy")
	var second: MercenaryData = _hominid("Second", {"flee": 30.0, "base_success_chance": 100.0})
	var a: Array[MercenaryData] = [mark]
	var b: Array[MercenaryData] = [clumsy, second]
	var st: BattleState = _state(a, b)
	TestFixtures.place(st, clumsy, Vector2i(0, 10))
	TestFixtures.place(st, mark, Vector2i(1, 10))
	TestFixtures.place(st, second, Vector2i(0, 11))
	st.kidnap_pending = clumsy
	st.kidnap_pending_target = mark
	clumsy.current_ap = 2
	for i: int in range(4):
		CheckSystem.forced_rolls.append(50)
	var lines: Array[String] = []
	KidnapSystem.run_turn(clumsy, st, lines, 0)
	TestFixtures.check(res, "a failed grapple gives up and closes the encounter",
		_has_line(lines, "  GRAPPLE: Clumsy vs Mark -> fails")
		and _has_line(lines, "  KIDNAP GRAPPLE: Clumsy gives up on Mark (grapple failed)")
		and st.kidnap_closed, "closed %s lines %s" % [st.kidnap_closed, str(lines)])
	TestFixtures.check(res, "a failed grapple registers no pair",
		st.kidnap_captor.is_empty() and st.kidnap_pending == null
		and st.kidnap_pending_target == null and KidnapSystem.kidnaps_total == 0,
		"pairs %d pending %s" % [st.kidnap_captor.size(), str(st.kidnap_pending)])
	KidnapSystem.rolls_made = 0
	KidnapSystem.forced_rolls.append(1)
	var later: Array[String] = []
	var rolled: bool = KidnapSystem.start_of_turn(second, st, later)
	TestFixtures.check(res, "a closed encounter makes no further kidnap roll",
		not rolled and KidnapSystem.rolls_made == 0 and later.is_empty()
		and KidnapSystem.forced_rolls.size() == 1,
		"rolls %d dice left %d" % [KidnapSystem.rolls_made, KidnapSystem.forced_rolls.size()])
	CheckSystem.forced_rolls.clear()


static func _case_pending_give_up(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var grabber: MercenaryData = _hominid("Grabber")
	var st: BattleState = _duo(mark, grabber)
	TestFixtures.place(st, grabber, Vector2i(0, 10))
	TestFixtures.place(st, mark, Vector2i(5, 10))
	st.kidnap_triggered = true
	st.kidnap_pending = grabber
	st.kidnap_pending_target = mark
	grabber.current_ap = 0
	var gone: Array[String] = []
	KidnapSystem.run_turn(grabber, st, gone, 0)
	TestFixtures.check(res, "a target out of reach ends the attempt",
		_has_line(gone, "  KIDNAP GRAPPLE: Grabber gives up on Mark (out of reach)")
		and st.kidnap_closed and st.kidnap_pending == null,
		"closed %s lines %s" % [st.kidnap_closed, str(gone)])
	_fresh()
	var near_mark: MercenaryData = _merc("Near Mark", {"vigor": 1})
	var holder: MercenaryData = _hominid("Holder")
	var a2: Array[MercenaryData] = [near_mark]
	var b2: Array[MercenaryData] = [holder]
	var st2: BattleState = _state(a2, b2)
	TestFixtures.place(st2, holder, Vector2i(0, 10))
	TestFixtures.place(st2, near_mark, Vector2i(1, 10))
	st2.kidnap_triggered = true
	st2.kidnap_pending = holder
	st2.kidnap_pending_target = near_mark
	holder.current_ap = 0
	var kept: Array[String] = []
	KidnapSystem.run_turn(holder, st2, kept, 0)
	TestFixtures.check(res, "a target in reach keeps the scripted turn",
		kept.is_empty() and not st2.kidnap_closed and st2.kidnap_pending == holder
		and st2.kidnap_pending_target == near_mark,
		"closed %s pending %s lines %s" % [st2.kidnap_closed, str(st2.kidnap_pending), str(kept)])


static func _case_drag_pace(res: Dictionary) -> void:
	_fresh()
	var small: MercenaryData = _merc("Small", {"size": 2})
	var huge: MercenaryData = _merc("Huge", {"size": 9})
	var captor: MercenaryData = _merc("Captor", {"pace": 4})
	var a: Array[MercenaryData] = [small, huge]
	var b: Array[MercenaryData] = [captor]
	var st: BattleState = _state(a, b)
	var free_pace: int = MovementExecutor.pace_per_move(captor)
	KidnapSystem.register(captor, small, st)
	var with_small: int = MovementExecutor.pace_per_move(captor)
	KidnapSystem.unregister(captor, st)
	KidnapSystem.register(captor, huge, st)
	var with_huge: int = MovementExecutor.pace_per_move(captor)
	TestFixtures.check(res, "a Size 2 captive costs the captor two paces",
		free_pace == 4 and with_small == 2, "free %d held %d" % [free_pace, with_small])
	TestFixtures.check(res, "a Size 9 captive leaves the captor one pace",
		with_huge == 1, "pace %d" % with_huge)


static func _case_drag_cell(res: Dictionary) -> void:
	_fresh()
	var captive: MercenaryData = _merc("Captive", {"vigor": 1})
	var captor: MercenaryData = _merc("Captor")
	var st: BattleState = _duo(captive, captor)
	TestFixtures.place(st, captor, Vector2i(5, 5))
	TestFixtures.place(st, captive, Vector2i(5, 6))
	_grapple(captive, captor)
	KidnapSystem.register(captor, captive, st)
	var from_cell: Vector3i = st.pos3(captor)
	st.set_pos3(captor, Vector3i(6, 5, 0))
	st.set_pace_pool(captive, 3)
	KidnapSystem.drag(captor, st, from_cell)
	TestFixtures.check(res, "the captive stands in the cell the captor left",
		st.pos3(captive) == from_cell and st.get_pace_pool(captive) == 0,
		"captive at %s pool %d" % [str(st.pos3(captive)), st.get_pace_pool(captive)])
	_fresh()
	var held: MercenaryData = _merc("Held", {"vigor": 1})
	var puller: MercenaryData = _merc("Puller")
	var blocker: MercenaryData = _merc("Blocker")
	var a2: Array[MercenaryData] = [held, blocker]
	var b2: Array[MercenaryData] = [puller]
	var st2: BattleState = _state(a2, b2)
	TestFixtures.place(st2, puller, Vector2i(10, 10))
	TestFixtures.place(st2, held, Vector2i(10, 11))
	_grapple(held, puller)
	KidnapSystem.register(puller, held, st2)
	var blocked_cell: Vector3i = st2.pos3(puller)
	st2.set_pos3(puller, Vector3i(11, 10, 0))
	TestFixtures.place(st2, blocker, Vector2i(10, 10))
	KidnapSystem.drag(puller, st2, blocked_cell)
	TestFixtures.check(res, "a taken cell leaves the captive where it stands",
		st2.pos3(held) == Vector3i(10, 11, 0), "captive at %s" % str(st2.pos3(held)))
	_fresh()
	MovementExecutor.clear_caches()
	var walked: MercenaryData = _merc("Walked", {"vigor": 1})
	var mover: MercenaryData = _merc("Mover", {"pace": 6})
	var lure: MercenaryData = _merc("Lure")
	var a3: Array[MercenaryData] = [walked, lure]
	var b3: Array[MercenaryData] = [mover]
	var st3: BattleState = _state(a3, b3)
	TestFixtures.place(st3, mover, Vector2i(5, 5))
	TestFixtures.place(st3, walked, Vector2i(5, 6))
	TestFixtures.place(st3, lure, Vector2i(9, 5))
	_grapple(walked, mover)
	KidnapSystem.register(mover, walked, st3)
	st3.start_of_turn(mover)
	var start3: Vector3i = st3.pos3(mover)
	var none: Array[MercenaryData] = []
	MovementExecutor.execute_move(mover, "Move Close", lure, st3, null, 0, -1, false, none, none,
		Vector3i(8, 5, 0))
	var end3: Vector3i = st3.pos3(mover)
	var pulled: Vector3i = st3.pos3(walked)
	var stepped: int = maxi(absi(end3.x - start3.x), absi(end3.y - start3.y))
	var gap: int = maxi(absi(pulled.x - end3.x), absi(pulled.y - end3.y))
	TestFixtures.check(res, "a walked move leaves the captive in the cell the captor stepped out of",
		stepped >= 2 and gap == 1 and pulled != start3 and pulled != end3,
		"captor %s -> %s captive %s" % [str(start3), str(end3), str(pulled)])
	MovementExecutor.clear_caches()


static func _case_grapple_broken(res: Dictionary) -> void:
	_fresh()
	var captive: MercenaryData = _merc("Captive", {"vigor": 1})
	var captor: MercenaryData = _merc("Captor")
	var st: BattleState = _duo(captive, captor)
	TestFixtures.place(st, captor, Vector2i(5, 5))
	TestFixtures.place(st, captive, Vector2i(5, 6))
	_grapple(captive, captor)
	KidnapSystem.register(captor, captive, st)
	var held_pace: int = MovementExecutor.pace_per_move(captor)
	ConstStates.remove_state(captive, ConstStates.GRAPPLED)
	var still: bool = KidnapSystem.holds(captor, st)
	TestFixtures.check(res, "a broken grapple unregisters the pair",
		not still and st.kidnap_captor.is_empty() and KidnapSystem.drag_size(captor) == 0,
		"holds %s pairs %d drag %d" % [still, st.kidnap_captor.size(),
		KidnapSystem.drag_size(captor)])
	TestFixtures.check(res, "a broken grapple restores the captor pace",
		held_pace == 2 and MovementExecutor.pace_per_move(captor) == 3,
		"held %d free %d" % [held_pace, MovementExecutor.pace_per_move(captor)])


static func _case_captor_death(res: Dictionary) -> void:
	_fresh()
	var captive: MercenaryData = _merc("Captive", {"vigor": 1})
	var captor: MercenaryData = _merc("Captor")
	var st: BattleState = _duo(captive, captor)
	TestFixtures.place(st, captor, Vector2i(5, 5))
	TestFixtures.place(st, captive, Vector2i(5, 6))
	_grapple(captive, captor)
	KidnapSystem.register(captor, captive, st)
	captor.is_dead = true
	var lines: Array[String] = []
	StateInfliction.release_held_by(captor, st, lines)
	var released: String = "  %s is no longer grappled: %s is dead" % [
		BattleState.colored_name(captive, st), BattleState.colored_name(captor, st)]
	TestFixtures.check(res, "a dead source ends the grapple and the pair",
		not ConstStates.has_state(captive, ConstStates.GRAPPLED) and _has_line(lines, released)
		and st.kidnap_captor.is_empty() and KidnapSystem.drag_size(captor) == 0,
		"held %s pairs %d drag %d lines %s" % [
		ConstStates.has_state(captive, ConstStates.GRAPPLED), st.kidnap_captor.size(),
		KidnapSystem.drag_size(captor), str(lines)])
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var doomed: MercenaryData = _merc("Doomed", {"maximum_hit_points": 1})
	var a2: Array[MercenaryData] = [mark]
	var b2: Array[MercenaryData] = [doomed]
	var st2: BattleState = _state(a2, b2)
	TestFixtures.place(st2, doomed, Vector2i(5, 5))
	TestFixtures.place(st2, mark, Vector2i(5, 6))
	_grapple(mark, doomed)
	KidnapSystem.register(doomed, mark, st2)
	ConstStates.apply_state(doomed, ConstStates.DYING, null, "", "engine:dying")
	doomed.death_test_hp_loss = 1
	var death: Array[String] = []
	AutoBattle._run_death_test(doomed, st2, death)
	var freed: String = "  %s is no longer grappled: %s is dead" % [
		BattleState.colored_name(mark, st2), BattleState.colored_name(doomed, st2)]
	TestFixtures.check(res, "a captor killed by the death test lets its captive go",
		doomed.is_dead and _has_line(death, "  %s dies!" % BattleState.colored_name(doomed, st2))
		and _has_line(death, freed) and not ConstStates.has_state(mark, ConstStates.GRAPPLED)
		and st2.kidnap_captor.is_empty() and KidnapSystem.drag_size(doomed) == 0,
		"dead %s pairs %d lines %s" % [doomed.is_dead, st2.kidnap_captor.size(), str(death)])


static func _case_escape(res: Dictionary) -> void:
	_fresh()
	var captive: MercenaryData = _merc("Captive", {"vigor": 1})
	var captor: MercenaryData = _merc("Captor")
	var st: BattleState = _duo(captive, captor)
	TestFixtures.place(st, captor, Vector2i(0, 10))
	TestFixtures.place(st, captive, Vector2i(1, 10))
	_grapple(captive, captor)
	KidnapSystem.register(captor, captive, st)
	captor.flee_escape_paces = 3
	captor.current_ap = 2
	var lines: Array[String] = []
	FleeSystem.bank(captor, st, lines)
	TestFixtures.check(res, "banking the fifth pace writes the flee and kidnap lines",
		_has_line(lines, "  FLEE TRACK: Captor +2 paces (5/5)")
		and _has_line(lines, "FLED: Captor escapes the battle")
		and _has_line(lines, "KIDNAPPED: Captive is carried off the field by Captor"),
		str(lines))
	TestFixtures.check(res, "both captor and captive leave the field",
		st.escaped.has(captor) and st.kidnapped.has(captive) and captive.off_field
		and str(st.kidnap_taken.get(captive, "")) == "Captor",
		"escaped %d kidnapped %d taken %s" % [st.escaped.size(), st.kidnapped.size(),
		str(st.kidnap_taken.get(captive, ""))])
	TestFixtures.check(res, "the escape unregisters the pair",
		st.kidnap_captor.is_empty() and KidnapSystem.drag_size(captor) == 0,
		"pairs %d drag %d" % [st.kidnap_captor.size(), KidnapSystem.drag_size(captor)])
	var runner: MercenaryData = _merc("Runner", {"pace": 2})
	var free_a: Array[MercenaryData] = [runner]
	var free_b: Array[MercenaryData] = []
	var free_st: BattleState = _state(free_a, free_b)
	TestFixtures.place(free_st, runner, Vector2i(0, 10))
	runner.flee_escape_paces = 3
	runner.current_ap = 2
	var free_lines: Array[String] = []
	FleeSystem.bank(runner, free_st, free_lines)
	TestFixtures.check(res, "a plain flee-er still banks toward fifteen",
		_has_line(free_lines, "  FLEE TRACK: Runner +2 paces (5/15)")
		and not runner.off_field and free_st.escaped.is_empty(),
		"off_field %s escaped %d lines %s" % [runner.off_field, free_st.escaped.size(),
		str(free_lines)])


static func _case_remove_from_field_reason(res: Dictionary) -> void:
	_fresh()
	var merc: MercenaryData = _merc("Nobody")
	var a: Array[MercenaryData] = [merc]
	var b: Array[MercenaryData] = []
	var st: BattleState = _state(a, b)
	var lines: Array[String] = []
	st.remove_from_field(merc, "nonsense", lines)
	TestFixtures.check(res, "an unknown removal reason removes nobody",
		not merc.off_field and lines.is_empty() and st.escaped.is_empty()
		and st.kidnapped.is_empty() and st.removed_from_field.is_empty(),
		"off_field %s lines %d" % [merc.off_field, lines.size()])


static func _case_settle(res: Dictionary) -> void:
	_fresh()
	MercPool.clear()
	var taken: MercenaryData = _merc("Taken")
	var kept: MercenaryData = _merc("Kept")
	var roster: Array[MercenaryData] = [taken, kept]
	var team: Array[MercenaryData] = [taken, kept]
	var contract_run: ContractRun = _run(team)
	var empty_b: Array[MercenaryData] = []
	var st: BattleState = _state(roster, empty_b)
	st.kidnapped.append(taken)
	st.kidnap_taken[taken] = "Bandit"
	var lines: Array[String] = KidnapSystem.settle(contract_run, st, roster)
	var marks: Array = contract_run.merc_marks.get(taken, [])
	var captives: Array[Dictionary] = MercPool.captives()
	var entry: Dictionary = captives[0] if not captives.is_empty() else {}
	TestFixtures.check(res, "the captive leaves the party and carries the mark",
		marks.has(KidnapSystem.MARK) and not contract_run.team.has(taken) and contract_run.kidnapped.has(taken)
		and contract_run.team.has(kept) and not contract_run.casualties.has(taken),
		"marks %s team %d kidnapped %d" % [str(marks), contract_run.team.size(), contract_run.kidnapped.size()])
	TestFixtures.check(res, "the captive is stored with contract, place and stamp",
		captives.size() == 1 and entry.get("merc") == taken
		and str(entry.get("contract_type", "")) == "Escort"
		and str(entry.get("location", "")) == "Aerdis"
		and not str(entry.get("stamp", "")).is_empty(),
		"captives %d entry %s" % [captives.size(), str(entry)])
	TestFixtures.check(res, "the settle writes the mark and taken lines",
		_has_line(lines, "KIDNAP MARK: Taken (Bandit)")
		and _has_line(lines, "KIDNAPPED: Taken taken by Bandit"), str(lines))
	MercPool.clear()


static func _case_trigger_candidates(res: Dictionary) -> void:
	_fresh()
	_reset_trigger()
	var team: Array[MercenaryData] = [_merc("Scout", {"luck": 40.0})]
	var contract_run: ContractRun = _wild_run(team)
	contract_run.triggered_events.append("Kidnapping")
	EventTrigger.forced_d100 = 1
	var ambush: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, contract_run)
	TestFixtures.check(res, "a spent Kidnapping row leaves only the Ambush",
		ambush != null and ambush.event_name == "Ambush"
		and EventTrigger.last_line.ends_with("TRIGGER PICK: Ambush of 1 candidates"),
		"event %s line '%s'" % [_event_name(ambush), EventTrigger.last_line])
	_reset_trigger()
	contract_run.triggered_events.clear()
	contract_run.triggered_events.append("Ambush")
	EventTrigger.forced_d100 = 1
	var kidnap: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, contract_run)
	TestFixtures.check(res, "a spent Ambush row leaves only the Kidnapping",
		kidnap != null and kidnap.event_name == "Kidnapping"
		and EventTrigger.last_line.ends_with("TRIGGER PICK: Kidnapping of 1 candidates"),
		"event %s line '%s'" % [_event_name(kidnap), EventTrigger.last_line])
	_reset_trigger()
	contract_run.triggered_events.clear()
	var seen: Dictionary = {}
	var misses: int = 0
	for i: int in range(40):
		EventTrigger.forced_d100 = 1
		var drawn: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, contract_run)
		if drawn == null:
			misses += 1
			continue
		seen[drawn.event_name] = true
	TestFixtures.check(res, "both trigger rows are drawn and nothing else is",
		misses == 0 and seen.size() == 2 and seen.has("Ambush") and seen.has("Kidnapping"),
		"misses %d names %s" % [misses, str(seen.keys())])
	_reset_trigger()


static func _case_respite_pair(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var alpha: MercenaryData = _merc("Alpha", {"base_success_chance": 100.0})
	var bravo: MercenaryData = _merc("Bravo", {"base_success_chance": 80.0})
	var charlie: MercenaryData = _merc("Charlie", {"base_success_chance": 50.0, "vigor": 1})
	var delta: MercenaryData = _merc("Delta", {"base_success_chance": 10.0, "vigor": 1})
	var crew: Array[MercenaryData] = [charlie, alpha, delta, bravo]
	var pair: Array[MercenaryData] = RespiteKidnapResolver.best_pair(mark, crew)
	TestFixtures.check(res, "the two best estimates make the pair",
		pair.size() == 2 and pair[0] == alpha and pair[1] == bravo,
		"pair %s" % str(_names(pair)))
	TestFixtures.check(res, "the estimates fall in crew order",
		KidnapSystem.grapple_estimate(alpha, mark, null)
		> KidnapSystem.grapple_estimate(bravo, mark, null)
		and KidnapSystem.grapple_estimate(bravo, mark, null)
		> KidnapSystem.grapple_estimate(charlie, mark, null)
		and KidnapSystem.grapple_estimate(charlie, mark, null)
		> KidnapSystem.grapple_estimate(delta, mark, null),
		"alpha %.4f bravo %.4f charlie %.4f delta %.4f" % [
		KidnapSystem.grapple_estimate(alpha, mark, null),
		KidnapSystem.grapple_estimate(bravo, mark, null),
		KidnapSystem.grapple_estimate(charlie, mark, null),
		KidnapSystem.grapple_estimate(delta, mark, null)])


static func _case_respite_target(res: Dictionary) -> void:
	_fresh()
	var one: MercenaryData = _merc("Kidnapper One", {"base_success_chance": 100.0})
	var two: MercenaryData = _merc("Kidnapper Two", {"base_success_chance": 100.0})
	var crew: Array[MercenaryData] = [one, two]
	var strong: MercenaryData = _merc("Strong", {"base_success_chance": 90.0, "vigor": 3})
	var weak: MercenaryData = _merc("Weak", {"vigor": 1})
	var shielded: MercenaryData = _merc("Shielded", {"vigor": 1})
	shielded.passive_effects.append("immune:surprised")
	var team: Array[MercenaryData] = [strong, weak, shielded]
	var contract_run: ContractRun = _run(team)
	var pool: Array[MercenaryData] = RespiteKidnapResolver.target_pool(contract_run)
	var picked: MercenaryData = RespiteKidnapResolver._pick_target(pool, crew)
	TestFixtures.check(res, "a Surprised immune merc is never targeted",
		not pool.has(shielded) and pool.size() == 2,
		"pool %s" % str(_names(pool)))
	TestFixtures.check(res, "the lowest Break Free odds is targeted",
		picked == weak and RespiteKidnapResolver.break_free_odds(weak, crew)
		< RespiteKidnapResolver.break_free_odds(strong, crew),
		"picked %s weak %.4f strong %.4f" % [picked.merc_name if picked != null else "null",
		RespiteKidnapResolver.break_free_odds(weak, crew),
		RespiteKidnapResolver.break_free_odds(strong, crew)])
	var ironhide: MercenaryData = _merc("Ironhide", {"vigor": 1})
	ironhide.passive_effects.append("immune:grappled")
	var iron_team: Array[MercenaryData] = [ironhide]
	var iron_run: ContractRun = _run(iron_team)
	var iron_pool: Array[MercenaryData] = RespiteKidnapResolver.target_pool(iron_run)
	CheckSystem.forced_rolls.append(50)
	var lines: Array[String] = []
	var broke: bool = RespiteKidnapResolver.break_free_roll(ironhide, crew, lines)
	TestFixtures.check(res, "a Grappled immune merc stays in the pool and cannot be held",
		iron_pool.has(ironhide) and broke and CheckSystem.forced_rolls.size() == 1
		and _has_line(lines,
		"KIDNAP BREAK FREE: Ironhide cannot be held (immune to Grappled) -> breaks free"),
		"pool %d dice left %d lines %s" % [iron_pool.size(), CheckSystem.forced_rolls.size(),
		str(lines)])
	CheckSystem.forced_rolls.clear()


static func _case_notice_worst(res: Dictionary) -> void:
	_fresh()
	var watcher: MercenaryData = _merc("Watcher", {"base_success_chance": 100.0})
	watcher.passive_effects.append("immune:surprised")
	var team: Array[MercenaryData] = [watcher]
	var contract_run: ContractRun = _run(team)
	var guard_a: MercenaryData = _merc("GuardA", {"base_success_chance": 100.0})
	var guard_b: MercenaryData = _merc("GuardB", {"base_success_chance": 0.0, "dexterity": 1})
	var pair: Array[MercenaryData] = [guard_a, guard_b]
	for i: int in range(6):
		CheckSystem.forced_rolls.append(50)
	var lines: Array[String] = []
	var spotter: MercenaryData = RespiteKidnapResolver.notice_interrupt(contract_run, pair, lines)
	TestFixtures.check(res, "the Notice check is opposed by the worst kidnapper",
		spotter == watcher and CheckSystem.forced_rolls.is_empty()
		and _has_line(lines, "KIDNAP NOTICE: Watcher 2 successes vs GuardB 0 -> spots them"),
		"spotter %s dice left %d lines %s" % [spotter.merc_name if spotter != null else "null",
		CheckSystem.forced_rolls.size(), str(lines)])
	CheckSystem.forced_rolls.clear()
	var even_b: MercenaryData = _merc("GuardB", {"base_success_chance": 100.0})
	var even_pair: Array[MercenaryData] = [guard_a, even_b]
	for i: int in range(6):
		CheckSystem.forced_rolls.append(50)
	var tie_lines: Array[String] = []
	var tied: MercenaryData = RespiteKidnapResolver.notice_interrupt(contract_run, even_pair, tie_lines)
	TestFixtures.check(res, "a tie goes to the kidnappers",
		tied == null and CheckSystem.forced_rolls.is_empty()
		and _has_line(tie_lines, "KIDNAP NOTICE: Watcher 2 successes vs GuardA 2 -> misses them"),
		"spotter %s dice left %d lines %s" % [tied.merc_name if tied != null else "null",
		CheckSystem.forced_rolls.size(), str(tie_lines)])
	CheckSystem.forced_rolls.clear()
	var lucky: MercenaryData = _merc("Watcher", {"luck": 100.0, "cognition": 1})
	lucky.passive_effects.append("immune:surprised")
	var lucky_team: Array[MercenaryData] = [lucky]
	var lucky_run: ContractRun = _run(lucky_team)
	var was_banking: bool = CriticalSuccessSystem.banking
	CriticalSuccessSystem.banking = true
	for i: int in range(5):
		CheckSystem.forced_rolls.append(50)
	var crit_lines: Array[String] = []
	var crit_spotter: MercenaryData = RespiteKidnapResolver.notice_interrupt(lucky_run,
		even_pair, crit_lines)
	CriticalSuccessSystem.banking = was_banking
	TestFixtures.check(res, "a lone critical wins the Notice",
		crit_spotter == lucky and CheckSystem.forced_rolls.is_empty()
		and _has_line(crit_lines, "KIDNAP NOTICE: Watcher 1 successes vs GuardA 2 -> spots them"),
		"spotter %s dice left %d lines %s" % [
		crit_spotter.merc_name if crit_spotter != null else "null",
		CheckSystem.forced_rolls.size(), str(crit_lines)])
	CheckSystem.forced_rolls.clear()


static func _case_break_free_combined(res: Dictionary) -> void:
	_fresh()
	var ann: MercenaryData = _merc("Ann", {"base_success_chance": 100.0, "vigor": 1})
	var bo: MercenaryData = _merc("Bo", {"base_success_chance": 100.0, "vigor": 1})
	var pair: Array[MercenaryData] = [ann, bo]
	var held: MercenaryData = _merc("Held", {"base_success_chance": 100.0})
	for i: int in range(4):
		CheckSystem.forced_rolls.append(50)
	var tie_lines: Array[String] = []
	var tied: bool = RespiteKidnapResolver.break_free_roll(held, pair, tie_lines)
	TestFixtures.check(res, "an equal total loses the Break Free",
		not tied and CheckSystem.forced_rolls.is_empty()
		and _has_line(tie_lines, "KIDNAP BREAK FREE: Held 2 successes vs 2 combined -> is taken"),
		"free %s dice left %d lines %s" % [tied, CheckSystem.forced_rolls.size(), str(tie_lines)])
	CheckSystem.forced_rolls.clear()
	var freer: MercenaryData = _merc("Freer", {"base_success_chance": 100.0, "vigor": 3})
	for i: int in range(5):
		CheckSystem.forced_rolls.append(50)
	var win_lines: Array[String] = []
	var won: bool = RespiteKidnapResolver.break_free_roll(freer, pair, win_lines)
	TestFixtures.check(res, "exceeding the combined total wins the Break Free",
		won and CheckSystem.forced_rolls.is_empty()
		and _has_line(win_lines, "KIDNAP BREAK FREE: Freer 3 successes vs 2 combined -> breaks free"),
		"free %s dice left %d lines %s" % [won, CheckSystem.forced_rolls.size(), str(win_lines)])
	CheckSystem.forced_rolls.clear()
	var penned: MercenaryData = _merc("Penned", {"base_success_chance": 100.0, "vigor": 1})
	for i: int in range(3):
		CheckSystem.forced_rolls.append(95)
	var pen_lines: Array[String] = []
	var penned_free: bool = RespiteKidnapResolver.break_free_roll(penned, pair, pen_lines)
	TestFixtures.check(res, "two holds beat a single die",
		not penned_free and CheckSystem.forced_rolls.is_empty()
		and _has_line(pen_lines, "KIDNAP BREAK FREE: Penned 1 successes vs 2 combined -> is taken"),
		"free %s dice left %d lines %s" % [penned_free, CheckSystem.forced_rolls.size(),
		str(pen_lines)])
	CheckSystem.forced_rolls.clear()
	var loner: MercenaryData = _merc("Loner", {"base_success_chance": 100.0, "vigor": 1})
	var empty_pair: Array[MercenaryData] = []
	CheckSystem.forced_rolls.append(95)
	var lone_lines: Array[String] = []
	var lone_free: bool = RespiteKidnapResolver.break_free_roll(loner, empty_pair, lone_lines)
	TestFixtures.check(res, "no kidnapper leaves nothing to beat",
		lone_free and CheckSystem.forced_rolls.is_empty()
		and _has_line(lone_lines,
		"KIDNAP BREAK FREE: Loner 1 successes vs 0 combined -> breaks free"),
		"free %s dice left %d lines %s" % [lone_free, CheckSystem.forced_rolls.size(),
		str(lone_lines)])
	CheckSystem.forced_rolls.clear()
	var shape: Dictionary = SpecialActionSystem.break_free_def()
	var circs: Array = shape.get("circumstances", [])
	TestFixtures.check(res, "the Break Free def carries both hold circumstances and no bonus",
		is_equal_approx(float(shape.get("flat_threshold_bonus", -1.0)), 0.0) and circs.size() == 2
		and circs[0] == ConstCircumstances.ATHLETICS_VIGOR
		and circs[1] == ConstCircumstances.POWER_VIGOR,
		"bonus %s circumstances %s" % [str(shape.get("flat_threshold_bonus")), str(circs)])


static func _case_break_free_contested(res: Dictionary) -> void:
	_fresh()
	var captive: MercenaryData = _merc("Captive", {"base_success_chance": 100.0})
	var captor: MercenaryData = _merc("Captor", {"base_success_chance": 100.0, "vigor": 1})
	var st: BattleState = _duo(captive, captor)
	TestFixtures.place(st, captive, Vector2i(5, 5))
	TestFixtures.place(st, captor, Vector2i(5, 6))
	_grapple(captive, captor)
	captive.current_ap = 2
	for i: int in range(3):
		CheckSystem.forced_rolls.append(50)
	var won: Array[String] = SpecialActionSystem.execute({"action_name": "break_free"}, captive, st,
		{"enhancements": 0})
	var win_line: String = "  BREAK FREE: %s 2 successes vs %s 1 -> breaks free" % [
		BattleState.colored_name(captive, st), BattleState.colored_name(captor, st)]
	TestFixtures.check(res, "the grappler contests the roll and loses it",
		not ConstStates.has_state(captive, ConstStates.GRAPPLED) and _has_line(won, win_line)
		and CheckSystem.forced_rolls.is_empty(),
		"held %s dice left %d lines %s" % [
		ConstStates.has_state(captive, ConstStates.GRAPPLED), CheckSystem.forced_rolls.size(),
		str(won)])
	CheckSystem.forced_rolls.clear()
	_grapple(captive, captor)
	captor.stats["vigor"] = 2
	captive.current_ap = 2
	for i: int in range(4):
		CheckSystem.forced_rolls.append(50)
	var tied: Array[String] = SpecialActionSystem.execute({"action_name": "break_free"}, captive, st,
		{"enhancements": 0})
	var tie_line: String = "  BREAK FREE: %s 2 successes vs %s 2 -> stays held" % [
		BattleState.colored_name(captive, st), BattleState.colored_name(captor, st)]
	TestFixtures.check(res, "an equal contest keeps the hold",
		ConstStates.has_state(captive, ConstStates.GRAPPLED) and _has_line(tied, tie_line)
		and _has_line(tied, "  %s fails to break free!" % BattleState.colored_name(captive, st))
		and CheckSystem.forced_rolls.is_empty(),
		"held %s dice left %d lines %s" % [
		ConstStates.has_state(captive, ConstStates.GRAPPLED), CheckSystem.forced_rolls.size(),
		str(tied)])
	CheckSystem.forced_rolls.clear()
	ConstStates.remove_state(captive, ConstStates.GRAPPLED)
	captor.is_dead = true
	captive.stats["base_success_chance"] = 50.0
	_grapple(captive, captor)
	captive.current_ap = 2
	CheckSystem.forced_rolls.append(60)
	CheckSystem.forced_rolls.append(60)
	var resisted: Array[String] = SpecialActionSystem.execute({"action_name": "break_free"}, captive,
		st, {"enhancements": 0})
	var resist_line: String = "  BREAK FREE: %s Resist 2 successes vs trial 2 -> breaks free" % \
		BattleState.colored_name(captive, st)
	TestFixtures.check(res, "a dead grappler leaves the state Resist to beat",
		not ConstStates.has_state(captive, ConstStates.GRAPPLED) and _has_line(resisted, resist_line)
		and CheckSystem.forced_rolls.is_empty(),
		"held %s dice left %d lines %s" % [
		ConstStates.has_state(captive, ConstStates.GRAPPLED), CheckSystem.forced_rolls.size(),
		str(resisted)])
	CheckSystem.forced_rolls.clear()
	var ghost: MercenaryData = _merc("Ghost")
	ghost.is_dead = true
	_grapple(captive, ghost)
	captive.current_ap = 2
	for i: int in range(4):
		CheckSystem.forced_rolls.append(70)
	var kept: Array[String] = SpecialActionSystem.execute({"action_name": "break_free"}, captive, st,
		{"enhancements": 0})
	var kept_line: String = "  BREAK FREE: %s Resist 0 successes vs trial 2 -> stays held" % \
		BattleState.colored_name(captive, st)
	TestFixtures.check(res, "a failed Resist keeps an uncontested hold",
		ConstStates.has_state(captive, ConstStates.GRAPPLED) and _has_line(kept, kept_line)
		and CheckSystem.forced_rolls.is_empty(),
		"held %s dice left %d lines %s" % [
		ConstStates.has_state(captive, ConstStates.GRAPPLED), CheckSystem.forced_rolls.size(),
		str(kept)])
	CheckSystem.forced_rolls.clear()


static func _case_respite_to_battle(res: Dictionary) -> void:
	_fresh()
	var plain: MercenaryData = _merc("Plain", {"vigor": 1})
	var watcher: MercenaryData = _merc("Watcher", {"base_success_chance": 100.0})
	watcher.passive_effects.append("immune:surprised")
	var team: Array[MercenaryData] = [plain, watcher]
	var contract_run: ContractRun = _run(team)
	var surprised: Array[MercenaryData] = []
	for merc: MercenaryData in contract_run.living_team():
		if not ConstStates.is_immune(merc, ConstStates.SURPRISED):
			surprised.append(merc)
	TestFixtures.check(res, "only the non immune mercs are caught out",
		surprised.size() == 1 and surprised[0] == plain, "surprised %s" % str(_names(surprised)))
	var one: MercenaryData = _merc("Kidnapper One", {"base_success_chance": 100.0})
	var two: MercenaryData = _merc("Kidnapper Two", {"base_success_chance": 100.0})
	var crew: Array[MercenaryData] = [one, two]
	var empty_b: Array[MercenaryData] = []
	var st: BattleState = _state(team, empty_b)
	TestFixtures.place(st, plain, Vector2i(10, 10))
	TestFixtures.place(st, watcher, Vector2i(2, 2))
	var set_one: bool = SpawnPlacer.place_adjacent(st, one, plain)
	var set_two: bool = SpawnPlacer.place_adjacent(st, two, plain)
	TestFixtures.check(res, "both kidnappers start beside their mark",
		set_one and set_two and st.distance_to(one, plain) == 1
		and st.distance_to(two, plain) == 1 and st.pos3(one) != st.pos3(two),
		"one %s two %s mark %s" % [str(st.pos3(one)), str(st.pos3(two)), str(st.pos3(plain))])
	var rm: Array[String] = ["time"]
	var on_plain: bool = ConstStates.apply_state(plain, ConstStates.SURPRISED, null, "",
		"engine:kidnap", rm)
	var on_watcher: bool = ConstStates.apply_state(watcher, ConstStates.SURPRISED, null, "",
		"engine:kidnap", rm)
	TestFixtures.check(res, "a Notice or Break Free win opens a battle with the full crew",
		crew.size() == 2 and on_plain and not on_watcher
		and ConstStates.has_state(plain, ConstStates.SURPRISED)
		and not ConstStates.has_state(watcher, ConstStates.SURPRISED),
		"plain %s watcher %s" % [on_plain, on_watcher])
	ConstStates.remove_state(plain, ConstStates.SURPRISED)


static func _case_respite_capture(res: Dictionary) -> void:
	_fresh()
	MercPool.clear()
	var ann: MercenaryData = _merc("Ann", {"base_success_chance": 100.0, "vigor": 1})
	var bo: MercenaryData = _merc("Bo", {"base_success_chance": 100.0, "vigor": 1})
	var pair: Array[MercenaryData] = [ann, bo]
	var held: MercenaryData = _merc("Held", {"base_success_chance": 100.0})
	var kept: MercenaryData = _merc("Kept")
	var team: Array[MercenaryData] = [held, kept]
	var contract_run: ContractRun = _run(team)
	for i: int in range(4):
		CheckSystem.forced_rolls.append(50)
	var roll_lines: Array[String] = []
	var broke: bool = RespiteKidnapResolver.break_free_roll(held, pair, roll_lines)
	var pair_names: String = " and ".join(contract_run.merc_names(pair))
	var lines: Array[String] = KidnapSystem.take_captive(contract_run, held, pair_names)
	var captives: Array[Dictionary] = MercPool.captives()
	TestFixtures.check(res, "a failed Break Free captures with no battle",
		not broke and pair_names == "Ann and Bo"
		and _has_line(lines, "KIDNAP MARK: Held (Ann and Bo)")
		and _has_line(lines, "KIDNAPPED: Held taken by Ann and Bo"),
		"free %s names '%s' lines %s" % [broke, pair_names, str(lines)])
	var marks: Array = contract_run.merc_marks.get(held, [])
	TestFixtures.check(res, "the captured merc is marked, stored and out of the party",
		marks.has(KidnapSystem.MARK) and not contract_run.team.has(held) and contract_run.kidnapped.has(held)
		and contract_run.team.has(kept) and not contract_run.casualties.has(held) and captives.size() == 1
		and captives[0].get("merc") == held,
		"marks %s team %d captives %d" % [str(marks), contract_run.team.size(), captives.size()])
	CheckSystem.forced_rolls.clear()
	MercPool.clear()


static func _case_respite_no_mark(res: Dictionary) -> void:
	_fresh()
	var sentinel: MercenaryData = _merc("Sentinel")
	sentinel.passive_effects.append("immune:surprised")
	var team: Array[MercenaryData] = [sentinel]
	var contract_run: ContractRun = _run(team)
	var pool: Array[MercenaryData] = RespiteKidnapResolver.target_pool(contract_run)
	var out: Dictionary = RespiteKidnapResolver.crew_leaves(contract_run, EventRunner.outcome(null), 3)
	var notes: Array = out.get("notes", [])
	var taken: Array = out.get("kidnapped", [])
	TestFixtures.check(res, "a respite with no mark leaves the party alone",
		pool.is_empty() and notes.size() == 1 and str(notes[0]) == "kidnap no target"
		and taken.is_empty() and contract_run.team.has(sentinel) and not bool(out.get("success", true)),
		"pool %d notes %s taken %d team %d" % [pool.size(), str(notes), taken.size(),
		contract_run.team.size()])
	TestFixtures.check(res, "the crew leaving is written to the run log",
		_has_line(contract_run.log_lines, "RESPITE KIDNAP: no mark among 1 resting mercs, 3 bandits leave"),
		str(contract_run.log_lines))


static func _case_mark_name(res: Dictionary) -> void:
	_fresh()
	var row: EventData = ContractLibrary.event("Kidnapping")
	TestFixtures.check(res, "the merc mark and the event row name differ",
		KidnapSystem.MARK == "Kidnapped" and RespiteKidnapResolver.EVENT_NAME == "Kidnapping"
		and KidnapSystem.MARK != RespiteKidnapResolver.EVENT_NAME
		and row != null and row.event_name == "Kidnapping",
		"mark '%s' event '%s' row '%s'" % [KidnapSystem.MARK, RespiteKidnapResolver.EVENT_NAME,
		_event_name(row)])


static func _case_held_weapon_grapple(res: Dictionary) -> void:
	_fresh()
	var mark: MercenaryData = _merc("Mark", {"vigor": 1})
	var whip: MercenaryData = _hominid("Whip", {"flee": 30.0, "base_success_chance": 100.0})
	var other: MercenaryData = _hominid("Other", {"flee": 30.0})
	var a: Array[MercenaryData] = [mark]
	var b: Array[MercenaryData] = [whip, other]
	var st: BattleState = _state(a, b)
	whip.current_hp = 15
	other.current_hp = 15
	mark.current_hp = 20
	TestFixtures.place(st, whip, Vector2i(0, 10))
	TestFixtures.place(st, mark, Vector2i(1, 10))
	TestFixtures.place(st, other, Vector2i(0, 11))
	CheckSystem.forced_rolls.append(99)
	CheckSystem.forced_rolls.append(99)
	StateInfliction.inflict_default(mark, ConstStates.GRAPPLED, whip, st)
	TestFixtures.check(res, "a weapon perk grapple registers no pair on its own",
		ConstStates.has_state(mark, ConstStates.GRAPPLED)
		and ConstStates.get_source(mark, ConstStates.GRAPPLED) == whip
		and not KidnapSystem.holds(whip, st) and st.kidnap_captor.is_empty()
		and CheckSystem.forced_rolls.is_empty(),
		"grappled %s pairs %d" % [ConstStates.has_state(mark, ConstStates.GRAPPLED),
		st.kidnap_captor.size()])
	var pick: Dictionary = KidnapSystem.best_target(whip, st)
	TestFixtures.check(res, "the holder scans its captive at likelihood 1 and nobody else does",
		is_equal_approx(KidnapSystem.grapple_estimate(whip, mark, st), 1.0)
		and is_equal_approx(KidnapSystem.grapple_estimate(other, mark, st), 0.0)
		and pick.get("merc") == mark and bool(pick.get("grappling", false)),
		"whip %.4f other %.4f grappling %s" % [
		KidnapSystem.grapple_estimate(whip, mark, st),
		KidnapSystem.grapple_estimate(other, mark, st), str(pick.get("grappling"))])
	KidnapSystem.forced_rolls.append(1)
	var lines: Array[String] = []
	var passed: bool = KidnapSystem.start_of_turn(whip, st, lines)
	TestFixtures.check(res, "a passed roll registers the held pair at once",
		passed and st.kidnap_captor.get(whip) == mark and KidnapSystem.drag_size(whip) == 1
		and KidnapSystem.kidnaps_total == 1 and _has_prefix(lines, "  KIDNAP ROLL: Whip"),
		"passed %s captive %s drag %d" % [passed, str(st.kidnap_captor.get(whip)),
		KidnapSystem.drag_size(whip)])
	var turn: Array[String] = []
	KidnapSystem.run_turn(whip, st, turn, 0)
	TestFixtures.check(res, "the holder takes the Kidnap Flee turn instead of a fresh grapple",
		_has_line(turn, "  KIDNAP FLEE: Whip carries Mark toward the edge (0/5 paces)")
		and not _has_prefix(turn, "  GRAPPLE:"), str(turn))
	CheckSystem.forced_rolls.clear()
