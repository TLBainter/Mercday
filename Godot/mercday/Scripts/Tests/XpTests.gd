class_name XpTests

#Deterministic experience and level up cases. Run: godot --headless --path . -- --xp-tests
#Every test merc starts at level 5 with 500 xp so a tier change is easy to read.


static func run() -> bool:
	seed(4242)
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_enemy_xp(res)
	_case_level_math(res)
	_case_award(res)
	_case_level_ups(res)
	_case_more_level_ups(res)
	_case_set_level_from_xp(res)
	_case_encounter(res)
	_case_encounter_alive(res)
	_case_contract(res)
	_case_set_level_sync(res)
	_case_crit_reward(res)
	_case_generated_merc(res)
	_case_battle_state_total(res)
	_case_random_difficulty(res)
	_case_dot_credit(res)
	return TestFixtures.summarize(res, "XP")


static func _merc(name: String) -> MercenaryData:
	return TestFixtures.level_merc(name, true, true)


static func _case_enemy_xp(res: Dictionary) -> void:
	var cases: Array = [
		[5, 5, 10], [5, 4, 5], [5, 2, 1], [5, 1, 1], [5, 6, 11], [5, 10, 25], [5, 12, 25],
		[0, 0, 10], [0, 1, 25], [1, 0, 1], [10, 5, 1], [10, 6, 5], [3, 1, 1], [2, 1, 1],
	]
	for c: Array in cases:
		var got: int = ExperienceSystem.enemy_xp(int(c[0]), int(c[1]))
		TestFixtures.check(res, "enemy_xp L%d E%d" % [int(c[0]), int(c[1])], got == int(c[2]),
			"expected %d, got %d" % [int(c[2]), got])


static func _case_level_math(res: Dictionary) -> void:
	var pairs: Array = [[0, 0], [99, 0], [100, 1], [250, 2], [-5, 0]]
	for p: Array in pairs:
		var got: int = ExperienceSystem.level_for(int(p[0]))
		TestFixtures.check(res, "level_for %d" % int(p[0]), got == int(p[1]),
			"expected %d, got %d" % [int(p[1]), got])
	var xp7: int = ExperienceSystem.xp_for_level(7)
	TestFixtures.check(res, "xp_for_level 7", xp7 == 700, "expected 700, got %d" % xp7)


static func _case_award(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var m := _merc("Ada")
	var lines: Array[String] = ExperienceSystem.award(m, 100, "test")
	TestFixtures.check(res, "award adds xp", lines.size() == 1 and lines[0].contains("XP AWARD") and m.xp == 600,
		"%d lines, xp %d" % [lines.size(), m.xp])
	var none: Array[String] = ExperienceSystem.award(m, 0, "test")
	TestFixtures.check(res, "award zero ignored", none.is_empty() and m.xp == 600,
		"%d lines, xp %d" % [none.size(), m.xp])
	var ghost := _merc("Ghost")
	ghost.merc_uid = 0
	var ghost_lines: Array[String] = ExperienceSystem.award(ghost, 50, "test")
	TestFixtures.check(res, "award needs uid", ghost_lines.is_empty() and ghost.xp == 500,
		"%d lines, xp %d" % [ghost_lines.size(), ghost.xp])


static func _case_level_ups(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var m := _merc("Bran")
	m.stat_bonuses["dexterity"] = 4.0
	m.stats = StatCalculator.calculate_all(m)
	m.stats["pain_limit"] = 0
	m.stats_baseline = StatCalculator.calculate_all(m)
	ExperienceSystem.award(m, 100, "test")
	var speed_before: float = float(m.stats.get("speed", 0))
	var bsc_before: float = float(m.stats.get("base_success_chance", 0))
	var lines: Array[String] = ExperienceSystem.resolve_level_ups(m)
	var speed_after: float = float(m.stats.get("speed", 0))
	var bsc_after: float = float(m.stats.get("base_success_chance", 0))
	TestFixtures.check(res, "level up level", ExperienceSystem.current_level(m) == 6,
		"expected 6, got %d" % ExperienceSystem.current_level(m))
	TestFixtures.check(res, "level up stats", is_equal_approx(speed_after - speed_before, 1.0)
		and is_equal_approx(bsc_after - bsc_before, 1.0),
		"speed %.1f to %.1f, base_success_chance %.1f to %.1f"
		% [speed_before, speed_after, bsc_before, bsc_after])
	TestFixtures.check(res, "level up line", TestFixtures.count_lines(lines, "LEVEL UP:") == 1,
		"%d LEVEL UP lines of %d" % [TestFixtures.count_lines(lines, "LEVEL UP:"), lines.size()])
	TestFixtures.check(res, "level up roll step", m.lifepath_roll_step == 1,
		"expected 1, got %d" % m.lifepath_roll_step)
	var again: Array[String] = ExperienceSystem.resolve_level_ups(m)
	TestFixtures.check(res, "no level without xp", again.is_empty() and ExperienceSystem.current_level(m) == 6,
		"%d lines, level %d" % [again.size(), ExperienceSystem.current_level(m)])


static func _case_more_level_ups(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var m := _merc("Cass")
	ExperienceSystem.award(m, 100, "test")
	ExperienceSystem.resolve_level_ups(m)
	ExperienceSystem.award(m, 250, "test")
	var lines: Array[String] = ExperienceSystem.resolve_level_ups(m)
	TestFixtures.check(res, "two levels lines", TestFixtures.count_lines(lines, "LEVEL UP:") == 2,
		"%d LEVEL UP lines of %d at %d xp" % [TestFixtures.count_lines(lines, "LEVEL UP:"), lines.size(), m.xp])
	TestFixtures.check(res, "two levels level", ExperienceSystem.current_level(m) == 8,
		"expected 8, got %d" % ExperienceSystem.current_level(m))


static func _case_set_level_from_xp(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var m := _merc("Dree")
	var step_before: int = m.lifepath_roll_step
	m.xp = 350
	var got: int = ExperienceSystem.set_level_from_xp(m)
	TestFixtures.check(res, "set_level_from_xp down", got == 3 and ExperienceSystem.current_level(m) == 3,
		"returned %d, level %d" % [got, ExperienceSystem.current_level(m)])
	TestFixtures.check(res, "set_level_from_xp no roll", m.lifepath_roll_step == step_before,
		"step %d to %d" % [step_before, m.lifepath_roll_step])
	m.xp = 500
	var back: int = ExperienceSystem.set_level_from_xp(m)
	TestFixtures.check(res, "set_level_from_xp up", back == 5 and ExperienceSystem.current_level(m) == 5,
		"returned %d, level %d" % [back, ExperienceSystem.current_level(m)])


static func _case_encounter(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bran")
	var c := _merc("Cass")
	var e1 := _merc("Foe One")
	var e2 := _merc("Foe Two")
	var e3 := _merc("Foe Three")
	for e: MercenaryData in [e1, e2, e3]:
		e.merc_uid = 0
	e1.stats["level"] = 5
	e1.is_dead = true
	e2.stats["level"] = 5
	e2.current_hp = 3
	e3.stats["level"] = 10
	e3.current_hp = 0
	e3.is_dead = false
	c.is_dead = true
	var team: Array[MercenaryData] = [a, b, c]
	var foes: Array[MercenaryData] = [e1, e2, e3]
	var dealt: Dictionary = {a: {e1: 3, e3: 2}, b: {e1: 1}}
	var lines: Array[String] = ExperienceSystem.award_encounter(team, foes, dealt, "Skirmish")
	TestFixtures.check(res, "encounter dealer xp", a.xp == 535, "expected 535, got %d" % a.xp)
	TestFixtures.check(res, "encounter assist xp", b.xp == 522, "expected 522, got %d" % b.xp)
	TestFixtures.check(res, "encounter dead merc", c.xp == 500, "expected 500, got %d" % c.xp)
	TestFixtures.check(res, "encounter line count", lines.size() == 2, "%d lines" % lines.size())
	TestFixtures.check(res, "encounter names event", TestFixtures.count_lines(lines, "Skirmish") == lines.size(),
		"%d of %d lines name the event" % [TestFixtures.count_lines(lines, "Skirmish"), lines.size()])
	c.is_dead = false


static func _case_encounter_alive(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var e1 := _merc("Foe One")
	e1.merc_uid = 0
	e1.current_hp = 4
	e1.is_dead = false
	var team: Array[MercenaryData] = [a]
	var foes: Array[MercenaryData] = [e1]
	var dealt: Dictionary = {a: {e1: 3}}
	var lines: Array[String] = ExperienceSystem.award_encounter(team, foes, dealt, "Skirmish")
	TestFixtures.check(res, "living enemy no xp", lines.is_empty() and a.xp == 500,
		"%d lines, xp %d" % [lines.size(), a.xp])


static func _case_contract(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bran")
	var team: Array[MercenaryData] = [a, b]
	var contract_run: ContractRun = TestFixtures.run_for(team)
	contract_run.contract = ContractData.new()
	contract_run.contract.contract_type = "Rescue"
	contract_run.contract.difficulty = 2.5
	contract_run.verdict = "Succeeded"
	var lines: Array[String] = ExperienceSystem.award_contract(contract_run)
	TestFixtures.check(res, "contract award", lines.size() == 2 and a.xp == 525 and b.xp == 525,
		"%d lines, a %d b %d" % [lines.size(), a.xp, b.xp])
	contract_run.verdict = "Failed"
	var failed: Array[String] = ExperienceSystem.award_contract(contract_run)
	TestFixtures.check(res, "contract failed", failed.is_empty() and a.xp == 525,
		"%d lines, a %d" % [failed.size(), a.xp])
	contract_run.verdict = "Succeeded"
	contract_run.contract.difficulty = 1.0
	ExperienceSystem.award_contract(contract_run)
	TestFixtures.check(res, "contract difficulty one", a.xp == 535, "expected 535, got %d" % a.xp)
	contract_run.contract = null
	var none: Array[String] = ExperienceSystem.award_contract(contract_run)
	TestFixtures.check(res, "contract null", none.is_empty() and a.xp == 535,
		"%d lines, a %d" % [none.size(), a.xp])


static func _case_set_level_sync(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var m := _merc("Dree")
	ContractModifiers.set_level(m, 7)
	TestFixtures.check(res, "set_level syncs xp", m.xp == 700 and ExperienceSystem.current_level(m) == 7,
		"xp %d, level %d" % [m.xp, ExperienceSystem.current_level(m)])


static func _case_crit_reward(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var m := _merc("Ada")
	var note: String = CriticalSuccessSystem._apply_entry_effect(m,
		{"effect_dsl": "level_up", "frequency": ""})
	TestFixtures.check(res, "crit level_up", m.xp == 600 and ExperienceSystem.current_level(m) == 6
		and note.contains("LEVEL UP"),
		"xp %d, level %d, note %s" % [m.xp, ExperienceSystem.current_level(m), note])


static func _case_generated_merc(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	MercGenerator.forced_level = 4
	var merc: MercenaryData = MercGenerator.generate(0)
	MercGenerator.forced_level = -1
	var level: int = int(merc.stats.get("level", 0))
	TestFixtures.check(res, "generated xp matches level",
		ExperienceSystem.level_for(merc.xp) == level and merc.xp > 0,
		"xp %d, level %d" % [merc.xp, level])


static func _case_battle_state_total(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a: Array[MercenaryData] = [_merc("A1"), _merc("A2")]
	var b: Array[MercenaryData] = [_merc("B1"), _merc("B2")]
	var state: BattleState = BattleState.create(a, b, null, true)
	state.record_damage_dealt(a[0], b[0], 3)
	state.record_damage_dealt(a[0], b[0], 2)
	state.record_damage_dealt(a[0], a[1], 4)
	state.record_damage_dealt(a[0], a[0], 1)
	state.record_damage_dealt(a[0], b[1], 0)
	var by_target: Dictionary = state.damage_dealt_total.get(a[0], {})
	TestFixtures.check(res, "total map sums enemy damage", int(by_target.get(b[0], 0)) == 5,
		"expected 5, got %d" % int(by_target.get(b[0], 0)))
	TestFixtures.check(res, "total map skips ally", not by_target.has(a[1]),
		"ally entry present: %s" % str(by_target.has(a[1])))
	TestFixtures.check(res, "total map skips self", not by_target.has(a[0]),
		"self entry present: %s" % str(by_target.has(a[0])))
	TestFixtures.check(res, "total map skips zero", not by_target.has(b[1]),
		"zero entry present: %s" % str(by_target.has(b[1])))
	state.rotate_round_damage()
	var after: Dictionary = state.damage_dealt_total.get(a[0], {})
	TestFixtures.check(res, "total map survives rotate", int(after.get(b[0], 0)) == 5,
		"expected 5, got %d" % int(after.get(b[0], 0)))


static func _case_random_difficulty(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var seen: Dictionary = {}
	var bad: int = 0
	for _i: int in range(200):
		var d: float = ContractGenerator.roll_difficulty()
		var steps: float = d * 2.0
		if steps != floor(steps) or steps < 1.0 or steps > 10.0:
			bad += 1
		seen[d] = true
	TestFixtures.check(res, "roll_difficulty steps", bad == 0, "%d of 200 outside 0.5 to 5 in halves" % bad)
	TestFixtures.check(res, "roll_difficulty spread", seen.size() >= 5, "%d distinct values of 10" % seen.size())
	if not ContractLibrary.contract_type_names().is_empty():
		#The case builds no team, so the roster is left empty and generate() draws at the level 1 fallback.
		GuildRoster.reset()
		var off: int = 0
		var no_level: int = 0
		for _i: int in range(20):
			var c: ContractData = ContractGenerator.generate()
			if c == null:
				off += 1
				continue
			if c.contract_level < 1:
				no_level += 1
			var c_steps: float = c.difficulty * 2.0
			if c_steps != floor(c_steps) or c_steps < 1.0 or c_steps > 10.0:
				off += 1
		TestFixtures.check(res, "generated difficulty steps", off == 0, "%d of 20 outside 0.5 to 5 in halves" % off)
		TestFixtures.check(res, "generated contract level", no_level == 0, "%d of 20 under level 1" % no_level)
	var fresh := ContractData.new()
	TestFixtures.check(res, "new contract difficulty unset", fresh.difficulty == 0.0,
		"expected 0.0, got %s" % str(fresh.difficulty))


static func _case_dot_credit(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var e := _merc("Foe")
	var ta: Array[MercenaryData] = [a]
	var te: Array[MercenaryData] = [e]
	var state: BattleState = BattleState.create(ta, te, null, true)
	var hp_before: int = e.current_hp
	ConstStates.apply_state(e, ConstStates.BURNING, a)
	BattleStateUpdater.apply_dot_effects(e, state)
	var by_target: Dictionary = state.damage_dealt_total.get(a, {})
	TestFixtures.check(res, "dot credits its source", int(by_target.get(e, 0)) == 1,
		"expected 1, got %d" % int(by_target.get(e, 0)))
	TestFixtures.check(res, "dot burns the target", e.current_hp == hp_before - 1,
		"hp %d to %d" % [hp_before, e.current_hp])
	e.current_hp = 0
	var lines: Array[String] = ExperienceSystem.award_encounter(ta, te, state.damage_dealt_total, "Skirmish")
	TestFixtures.check(res, "dot kill pays the full tier", a.xp == 510 and lines.size() == 1,
		"%d lines, xp %d" % [lines.size(), a.xp])
	var f := _merc("Foe Two")
	var tf: Array[MercenaryData] = [f]
	var state_two: BattleState = BattleState.create(ta, tf, null, true)
	ConstStates.apply_state(f, ConstStates.BURNING)
	BattleStateUpdater.apply_dot_effects(f, state_two)
	TestFixtures.check(res, "sourceless dot credits nobody", state_two.damage_dealt_total.is_empty(),
		"%d attackers recorded" % state_two.damage_dealt_total.size())
