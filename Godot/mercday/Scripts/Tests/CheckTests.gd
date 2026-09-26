class_name CheckTests

#Deterministic check cases: every d100 is drawn from CheckSystem.forced_rolls, so no case depends on luck.
#Run: godot --headless --path . -- --check-tests

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_normal(res)
	_case_hard_pair(res)
	_case_reroll(res)
	_case_auto_fail(res)
	_case_odds(res)
	_case_mixed_pool(res)
	_case_banking(res)
	_case_resist(res)
	_case_item_inflict(res)
	_case_toxic_damage(res)
	_case_attack_result(res)
	_case_reward_pool(res)
	_case_apply_hit(res)
	_case_perk_abort(res)
	_case_whip_pull(res)
	_case_resolve_hit(res)
	_case_formula_kinds(res)
	return TestFixtures.summarize(res, "CHECK")


static func _merc(vigor: int, luck: float, reroll: float) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = "Probe"
	m.stats = {"vigor": vigor, "luck": luck, "level": 1}
	m.stats[_CONFIG.reroll_stat] = reroll
	m.stats[_CONFIG.base_success_chance_stat] = 0.0
	return m


static func _def() -> Dictionary:
	return {"stat_keys": ["vigor"], "circumstances": [], "knowledges": [], "tools": [], "formula": "15"}


static func _roll(merc: MercenaryData, forced: Array[int]) -> Dictionary:
	CheckSystem.forced_rolls.assign(forced)
	return CheckSystem.make_check(merc, _def())


static func _drained(res: Dictionary, label: String) -> void:
	TestFixtures.check(res, label, CheckSystem.forced_rolls.is_empty(),
		"forced queue left %d entries" % CheckSystem.forced_rolls.size())


static func _case_normal(res: Dictionary) -> void:
	var forced: Array[int] = [15, 15]
	var m := _merc(2, 0.0, 0.0)
	var r := _roll(m, forced)
	TestFixtures.check(res, "two dice crit", int(r["successes"]) == 2 and bool(r["critical"]),
		"successes %d critical %s" % [int(r["successes"]), str(r["critical"])])
	TestFixtures.check(res, "crit reward rolled", str(r["crit_reward"]) != "", "reward %s" % str(r["crit_reward"]))
	_drained(res, "crit queue drained")

	forced = [15, 14]
	m = _merc(2, 0.0, 0.0)
	r = _roll(m, forced)
	TestFixtures.check(res, "success without crit", int(r["successes"]) == 2 and not bool(r["critical"]),
		"successes %d critical %s" % [int(r["successes"]), str(r["critical"])])
	TestFixtures.check(res, "no reward without crit", str(r["crit_reward"]) == "", "reward '%s'" % str(r["crit_reward"]))
	_drained(res, "no-crit queue drained")

	forced = [12, 15]
	m = _merc(2, 5.0, 0.0)
	r = _roll(m, forced)
	TestFixtures.check(res, "luck widens the window", bool(r["critical"]),
		"12 and 15 against threshold %.2f luck 5" % float(r["threshold"]))
	_drained(res, "luck queue drained")

	forced = [10, 20, 50]
	m = _merc(2, 0.0, 0.0)
	r = _roll(m, forced)
	TestFixtures.check(res, "one failure", int(r["failures"]) == 1 and not bool(r["critical"]),
		"failures %d critical %s" % [int(r["failures"]), str(r["critical"])])
	_drained(res, "failure queue drained")


static func _case_hard_pair(res: Dictionary) -> void:
	var forced: Array[int] = [30, 15, 50]
	var m := _merc(0, 0.0, 0.0)
	var r := _roll(m, forced)
	var pair: Array = r["roll2"]
	var shape: bool = pair.size() == 1 and (pair[0] as Array).size() == 2
	var sorted_high: bool = shape and int((pair[0] as Array)[0]) == 15 and int((pair[0] as Array)[1]) == 30
	TestFixtures.check(res, "hard pair takes the worst", sorted_high and int(r["failures"]) == 1,
		"roll2 %s failures %d" % [str(pair), int(r["failures"])])
	_drained(res, "hard pair queue drained")

	forced = [10, 15]
	m = _merc(0, 0.0, 0.0)
	r = _roll(m, forced)
	TestFixtures.check(res, "hard pair crit", int(r["successes"]) == 1 and bool(r["critical"]),
		"successes %d critical %s" % [int(r["successes"]), str(r["critical"])])
	_drained(res, "hard pair crit queue drained")


static func _case_reroll(res: Dictionary) -> void:
	var forced: Array[int] = [50, 1, 15]
	var m := _merc(1, 0.0, 100.0)
	var r := _roll(m, forced)
	TestFixtures.check(res, "failed die rerolled", int(r["rerolls"]) == 1 and int(r["successes"]) == 1,
		"rerolls %d successes %d" % [int(r["rerolls"]), int(r["successes"])])
	_drained(res, "reroll queue drained")


static func _case_auto_fail(res: Dictionary) -> void:
	var forced: Array[int] = []
	var m := _merc(2, 0.0, 0.0)
	m.active_states = {ConstStates.SHOCKED: 1}
	var r := _roll(m, forced)
	TestFixtures.check(res, "auto fail", int(r["successes"]) == 0 and not bool(r["critical"]),
		"successes %d critical %s" % [int(r["successes"]), str(r["critical"])])
	TestFixtures.check(res, "auto fail has no reward", str(r["crit_reward"]) == "", "reward '%s'" % str(r["crit_reward"]))
	TestFixtures.check(res, "auto fail rolls nothing", (r["roll2"] as Array).is_empty(), "roll2 %s" % str(r["roll2"]))
	_drained(res, "auto fail queue drained")


static func _case_odds(res: Dictionary) -> void:
	var m := _merc(2, 10.0, 0.0)
	var over := CheckSystem.expected_success_chance(m, _def(), 3)
	TestFixtures.check(res, "trial above dice is the crit chance", is_equal_approx(over, 0.11 * 0.11),
		"got %.6f want %.6f" % [over, 0.11 * 0.11])
	var within := CheckSystem.expected_success_chance(m, _def(), 2)
	TestFixtures.check(res, "trial within dice unchanged", is_equal_approx(within, 0.15 * 0.15),
		"got %.6f want %.6f" % [within, 0.15 * 0.15])
	var hard := _merc(0, 0.0, 0.0)
	var hard_crit := CheckSystem.crit_chance(hard, _def())
	var want := 0.15 * 0.15 - 0.14 * 0.14
	TestFixtures.check(res, "hard pair crit chance", is_equal_approx(hard_crit, want),
		"got %.6f want %.6f" % [hard_crit, want])
	_drained(res, "odds queue drained")


#A net-zero core pool rolls one hard pair plus one normal die per enhancement.
#The estimator has to model that same mixed pool, so rolled frequency and estimate must agree.
static func _case_mixed_pool(res: Dictionary) -> void:
	var m := _merc(0, 0.0, 0.0)
	var def := _def()
	def["formula"] = "50"
	def["enhancements"] = 2
	CheckSystem.forced_rolls.clear()
	var estimate := CheckSystem.expected_success_chance(m, def, 2)
	var dist := CheckSystem.success_distribution(m, def)
	var pmf: Array = dist["pmf"]
	TestFixtures.check(res, "a 0-stat pool counts the hard pair and the enhancement dice",
		int(dist["dice"]) == 3 and pmf.size() == 4,
		"%d dice %d pmf entries" % [int(dist["dice"]), pmf.size()])
	var was_banking: bool = CriticalSuccessSystem.banking
	CriticalSuccessSystem.banking = true
	seed(20260922)
	var rounds := 20000
	var hits := 0
	for _i: int in rounds:
		if int(CheckSystem.make_check(m, def)["successes"]) >= 2:
			hits += 1
	CriticalSuccessSystem.banking = was_banking
	m.pending_crit_rewards.clear()
	randomize()
	var rolled := float(hits) / float(rounds)
	TestFixtures.check(res, "the trial 2 estimate matches the rolled frequency",
		absf(rolled - estimate) < 0.02,
		"rolled %.4f estimate %.4f" % [rolled, estimate])
	_drained(res, "mixed pool queue drained")


static func _case_banking(res: Dictionary) -> void:
	var forced: Array[int] = [15, 15]
	var m := _merc(2, 0.0, 0.0)
	var stats_before: int = m.stats.size()
	CriticalSuccessSystem.banking = true
	var r := _roll(m, forced)
	var level_before: int = int(m.stats.get("level", 0))
	TestFixtures.check(res, "reward banked", bool(r["critical"]) and m.pending_crit_rewards.size() == 1,
		"critical %s pending %d" % [str(r["critical"]), m.pending_crit_rewards.size()])
	TestFixtures.check(res, "banked stats untouched",
		m.stats.size() == stats_before and int(m.stats.get("vigor", 0)) == 2,
		"stats %d vigor %d" % [m.stats.size(), int(m.stats.get("vigor", 0))])
	var applied := CriticalSuccessSystem.apply_pending(m)
	var changed: bool = int(m.stats.get("level", 0)) > level_before or not m.stat_bonuses.is_empty() \
		or not m.max_stats.is_empty() or not m.circumstance_flags.is_empty() \
		or not m.stat_flat_bonuses.is_empty() or not m.stat_multipliers.is_empty()
	TestFixtures.check(res, "pending applied", applied.size() == 1 and m.pending_crit_rewards.is_empty(),
		"applied %s pending %d" % [str(applied), m.pending_crit_rewards.size()])
	TestFixtures.check(res, "pending changed the merc", changed, "reward %s" % str(r["crit_reward"]))
	CriticalSuccessSystem.banking = false
	_drained(res, "banking queue drained")


static func _case_resist(res: Dictionary) -> void:
	var m := _merc(2, 0.0, 0.0)
	CheckSystem.forced_rolls.assign([15, 15] as Array[int])
	var r := StateInfliction.resist_check(m, {"stat": "vigor", "trial": 3}, ConstStates.POISONED)
	TestFixtures.check(res, "resist crit passes trial 3", bool(r["passed"]) and bool(r["critical"]) and int(r["successes"]) == 2,
		"passed %s critical %s successes %d" % [str(r["passed"]), str(r["critical"]), int(r["successes"])])
	TestFixtures.check(res, "resist no bias", str(r["bias"]) == "", "bias %s" % str(r["bias"]))
	_drained(res, "resist crit queue drained")
	var s := _merc(2, 0.0, 0.0)
	s.passive_effects.assign(["susceptible:poisoned"] as Array[String])
	CheckSystem.forced_rolls.assign([10] as Array[int])
	r = StateInfliction.resist_check(s, {"stat": "vigor", "trial": 2}, ConstStates.POISONED)
	TestFixtures.check(res, "susceptible drops a die", int(r["successes"]) == 1 and not bool(r["passed"]) and str(r["bias"]) == "susceptible",
		"successes %d passed %s bias %s" % [int(r["successes"]), str(r["passed"]), str(r["bias"])])
	_drained(res, "susceptible queue drained")
	var p := _merc(2, 0.0, 0.0)
	p.passive_effects.assign(["protected:poisoned"] as Array[String])
	CheckSystem.forced_rolls.assign([15, 15, 50, 50] as Array[int])
	r = StateInfliction.resist_check(p, {"stat": "vigor", "trial": 2}, ConstStates.POISONED)
	TestFixtures.check(res, "protected adds a die", int(r["successes"]) == 2 and bool(r["passed"]) and str(r["bias"]) == "protected",
		"successes %d passed %s bias %s" % [int(r["successes"]), str(r["passed"]), str(r["bias"])])
	_drained(res, "protected queue drained")
	var f := _merc(2, 0.0, 0.0)
	CheckSystem.forced_rolls.assign([15, 15] as Array[int])
	r = StateInfliction.resist_check(f, {"stat": "vigor", "trial": 2}, ConstStates.POISONED, -3)
	TestFixtures.check(res, "negative extra flaws clamped", int(r["successes"]) == 2 and bool(r["passed"]),
		"successes %d passed %s" % [int(r["successes"]), str(r["passed"])])
	_drained(res, "clamp queue drained")
	var spec := {"stat": "vigor", "trial": 2}
	var chance_0 := StateInfliction.resist_chance(f, spec, ConstStates.POISONED, 0)
	var chance_neg := StateInfliction.resist_chance(f, spec, ConstStates.POISONED, -3)
	var chance_pos := StateInfliction.resist_chance(f, spec, ConstStates.POISONED, 1)
	TestFixtures.check(res, "negative extra flaws add no dice", is_equal_approx(chance_0, chance_neg) and chance_pos < chance_0,
		"chance 0 %.4f neg %.4f pos %.4f" % [chance_0, chance_neg, chance_pos])
	var chance_enh := StateInfliction.resist_chance(f, spec, ConstStates.POISONED, 0, 1)
	TestFixtures.check(res, "extra enhancement adds a die", chance_enh > chance_0,
		"chance 0 %.4f enh %.4f" % [chance_0, chance_enh])
	var g := _merc(2, 0.0, 0.0)
	CheckSystem.forced_rolls.assign([10] as Array[int])
	r = StateInfliction.resist_check(g, {"stat": "vigor", "trial": 2}, ConstStates.POISONED, 1)
	TestFixtures.check(res, "extra flaw drops a die", int(r["successes"]) == 1 and not bool(r["passed"]) and not bool(r["critical"]),
		"successes %d passed %s critical %s" % [int(r["successes"]), str(r["passed"]), str(r["critical"])])
	_drained(res, "extra flaw queue drained")
	var plain := _merc(2, 0.0, 0.0)
	CheckSystem.forced_rolls.assign([15, 50, 50] as Array[int])
	r = StateInfliction.resist_check(plain, {"stat": "vigor", "trial": 2})
	TestFixtures.check(res, "unnamed resist keeps the old form", int(r["successes"]) == 1 and not bool(r["passed"]) and str(r["bias"]) == "",
		"successes %d passed %s bias %s" % [int(r["successes"]), str(r["passed"]), str(r["bias"])])
	_drained(res, "unnamed queue drained")


#Attacker "Ash", defender "Mark" at hp and any extra defenders, placed in a row on a flat arena.
static func _arena(hp: int, extra_names: Array[String] = []) -> Dictionary:
	var atk_m := _merc(2, 0.0, 0.0)
	atk_m.merc_name = "Ash"
	var def_m := _merc(2, 0.0, 0.0)
	def_m.merc_name = "Mark"
	def_m.stats["maximum_hit_points"] = 20
	var team_a: Array[MercenaryData] = [atk_m]
	var team_b: Array[MercenaryData] = [def_m]
	var extras: Array[MercenaryData] = []
	for extra_name: String in extra_names:
		var e := _merc(2, 0.0, 0.0)
		e.merc_name = extra_name
		e.stats["maximum_hit_points"] = 20
		extras.append(e)
		team_b.append(e)
	var state := BattleState.create(team_a, team_b, null)
	state.battlefield = TestFixtures.exterior_field()
	var col := 0
	for m: MercenaryData in team_a + team_b:
		TestFixtures.place(state, m, Vector2i(2 + col, 2))
		col += 1
	def_m.current_hp = hp
	for e: MercenaryData in extras:
		e.current_hp = hp
	return {"atk": atk_m, "def": def_m, "extras": extras, "team_a": team_a, "team_b": team_b,
		"state": state}


static func _case_item_inflict(res: Dictionary) -> void:
	var ar := _arena(15, ["Mona", "Mira"] as Array[String])
	var atk_m: MercenaryData = ar["atk"]
	var def_m: MercenaryData = ar["def"]
	var state: BattleState = ar["state"]
	var extras: Array = ar["extras"]
	var def_2: MercenaryData = extras[0]
	var def_3: MercenaryData = extras[1]
	var team_b: Array[MercenaryData] = ar["team_b"]
	var team_a: Array[MercenaryData] = ar["team_a"]
	var col: int = team_a.size() + team_b.size()
	var w := WeaponData.new()
	w.inflict_states.assign(["Poisoned"] as Array[String])
	atk_m.equipped_weapon = w
	var atk := {"damage_type": "Strike", "ammo_name": ""}
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	var lines := CombatApplicator.apply_item_inflicts(atk_m, def_m, atk, 20, state)
	TestFixtures.check(res, "item inflict applies", ConstStates.has_state(def_m, ConstStates.POISONED) and not lines.is_empty(),
		"Poisoned %s lines %d" % [str(ConstStates.has_state(def_m, ConstStates.POISONED)), lines.size()])
	_drained(res, "item inflict queue drained")
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	lines = CombatApplicator.apply_item_inflicts(atk_m, def_m, atk, 20, state)
	TestFixtures.check(res, "item inflict skips a held state", lines.is_empty() and CheckSystem.forced_rolls.size() == 4,
		"lines %d queue %d" % [lines.size(), CheckSystem.forced_rolls.size()])
	lines = CombatApplicator.apply_item_inflicts(atk_m, def_2, atk, 15, state)
	TestFixtures.check(res, "item inflict needs hp loss", lines.is_empty() and CheckSystem.forced_rolls.size() == 4,
		"lines %d queue %d" % [lines.size(), CheckSystem.forced_rolls.size()])
	lines = CombatApplicator.apply_item_inflicts(atk_m, def_2, {"damage_type": "Toxic", "ammo_name": ""}, 20, state)
	TestFixtures.check(res, "toxic hit skips the item Poisoned roll", lines.is_empty() and CheckSystem.forced_rolls.size() == 4,
		"lines %d queue %d" % [lines.size(), CheckSystem.forced_rolls.size()])
	atk_m.known_immunities[def_3] = ["immune:poisoned"]
	lines = CombatApplicator.apply_item_inflicts(atk_m, def_3, atk, 20, state)
	TestFixtures.check(res, "known immunity skips the roll", lines.is_empty() and CheckSystem.forced_rolls.size() == 4,
		"lines %d queue %d" % [lines.size(), CheckSystem.forced_rolls.size()])
	CheckSystem.forced_rolls.clear()
	var def_4 := _merc(2, 0.0, 0.0)
	def_4.merc_name = "Mila"
	def_4.stats["maximum_hit_points"] = 20
	def_4.stats["cognition"] = 2
	def_4.current_hp = 15
	team_b.append(def_4)
	state.positions[def_4] = Vector2i(2 + col, 2)
	state.heights[def_4] = 0
	state.floors[def_4] = 0
	var gun := WeaponData.new()
	gun.is_ranged = true
	atk_m.equipped_weapon = gun
	var shot := {"damage_type": "Impale", "ammo_name": "Fang Dart"}
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	lines = CombatApplicator.apply_item_inflicts(atk_m, def_4, shot, 20, state)
	var ammo_ok := ConstStates.has_state(def_4, ConstStates.SURPRISED) and not ConstStates.has_state(def_4, ConstStates.POISONED)
	TestFixtures.check(res, "ammo inflict applies", ammo_ok and not lines.is_empty(),
		"Surprised %s lines %d" % [str(ConstStates.has_state(def_4, ConstStates.SURPRISED)), lines.size()])
	_drained(res, "ammo inflict queue drained")
	gun.is_ranged = false
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	lines = CombatApplicator.apply_item_inflicts(atk_m, def_2, shot, 20, state)
	TestFixtures.check(res, "melee weapon ignores ammo", lines.is_empty() and CheckSystem.forced_rolls.size() == 4,
		"lines %d queue %d" % [lines.size(), CheckSystem.forced_rolls.size()])
	CheckSystem.forced_rolls.clear()
	var empty := AttackSystem._empty_attack_result("Strike", true, false, true)
	var keys_ok := empty.has("enhancements") and empty.has("flaws") and empty.has("critical") \
		and empty.has("ammo_name") and bool(empty["is_throw"])
	TestFixtures.check(res, "empty attack carries the new keys", keys_ok, "keys %s" % str(empty.keys()))


static func _case_reward_pool(res: Dictionary) -> void:
	var m := _merc(2, 0.0, 0.0)
	m.stats["dexterity"] = 1
	m.stats["max_dexterity"] = 5
	var pool: Array = CriticalSuccessSystem.build_option_pool({"stat_used": "defend_reduction"}, m, {"formula": "defend"})
	TestFixtures.check(res, "defend crit draws the plain Dexterity rows and the Defend row", _defense_pool_ok(pool, "defend"),
		"pool %d plain rows %d" % [pool.size(), _plain_dex_rows()])
	pool = CriticalSuccessSystem.build_option_pool({"stat_used": "dodge_reduction"}, m, {"formula": "dodge"})
	TestFixtures.check(res, "dodge crit draws the plain Dexterity rows and the Dodge row", _defense_pool_ok(pool, "dodge"),
		"pool %d plain rows %d" % [pool.size(), _plain_dex_rows()])
	#The Combat rows grant a perk of the swung weapon's type, so the pool needs a weapon with unowned rows.
	var swung := WeaponData.new()
	swung.item_name = "Dirk"
	swung.weapon_type = "Dagger (Basic)"
	pool = CriticalSuccessSystem.build_option_pool({"stat_used": "dexterity"}, m,
		{"formula": "melee_accuracy", "weapon": swung})
	var has_combat := false
	var all_dex := not pool.is_empty()
	for entry: Dictionary in pool:
		if str(entry["formula_stat_required"]) == "Combat":
			has_combat = true
		if str(entry["stat"]) != "Dexterity":
			all_dex = false
	TestFixtures.check(res, "accuracy crit reaches the Combat rows", has_combat and all_dex,
		"pool %d combat %s dexterity only %s" % [pool.size(), str(has_combat), str(all_dex)])


static func _case_toxic_damage(res: Dictionary) -> void:
	var atk_m := _merc(2, 0.0, 0.0)
	atk_m.merc_name = "Ash"
	var def_m := _merc(2, 0.0, 0.0)
	def_m.merc_name = "Mark"
	def_m.stats["maximum_hit_points"] = 20
	var def_2 := _merc(2, 0.0, 0.0)
	def_2.merc_name = "Mona"
	def_2.stats["maximum_hit_points"] = 20
	var team_a: Array[MercenaryData] = [atk_m]
	var team_b: Array[MercenaryData] = [def_m, def_2]
	var state := BattleState.create(team_a, team_b, null)
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	var lines := CombatApplicator.apply_damage(atk_m, def_m, 3, "Toxic", state)
	TestFixtures.check(res, "toxic damage rolls Poisoned", ConstStates.has_state(def_m, ConstStates.POISONED) and def_m.current_hp == 17,
		"Poisoned %s hp %d lines %d" % [str(ConstStates.has_state(def_m, ConstStates.POISONED)), def_m.current_hp, lines.size()])
	_drained(res, "toxic damage queue drained")
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	lines = CombatApplicator.apply_damage(atk_m, def_m, 3, "Toxic", state)
	TestFixtures.check(res, "toxic damage skips a held Poisoned", def_m.current_hp == 13 and CheckSystem.forced_rolls.size() == 4,
		"hp %d (Toxic on Poisoned +1) queue %d" % [def_m.current_hp, CheckSystem.forced_rolls.size()])
	atk_m.known_immunities[def_2] = ["immune:poisoned"]
	lines = CombatApplicator.apply_damage(atk_m, def_2, 3, "Toxic", state)
	var immune_ok := not ConstStates.has_state(def_2, ConstStates.POISONED) and def_2.current_hp == 17 and CheckSystem.forced_rolls.size() == 4
	TestFixtures.check(res, "toxic damage honours a known immunity", immune_ok,
		"Poisoned %s hp %d queue %d" % [str(ConstStates.has_state(def_2, ConstStates.POISONED)), def_2.current_hp,
		CheckSystem.forced_rolls.size()])
	CheckSystem.forced_rolls.clear()


static func _case_attack_result(res: Dictionary) -> void:
	var m := _merc(2, 0.0, 0.0)
	m.stats["dexterity"] = 1
	m.stats["ranged_accuracy"] = 15.0
	var w := WeaponData.new()
	w.item_name = "Probe Gun"
	w.is_ranged = true
	w.has_light = true
	w.misfire = 2
	w.damage_types_1.assign(["Impale"] as Array[String])
	m.equipped_weapon = w
	m.ammo_loaded = 2
	m.ammo_loaded_type = "Fang Dart"
	CheckSystem.forced_rolls.assign([100, 50] as Array[int])
	var r := AttackSystem.execute_attack(m)
	var mis_ok := bool(r["misfired"]) and m.weapon_misfired and not bool(r["critical"]) and str(r["ammo_name"]) == "Fang Dart" and r.has("enhancements") and r.has("flaws") and not bool(r["is_throw"])
	TestFixtures.check(res, "misfire result carries the new keys", mis_ok,
		"misfired %s critical %s ammo %s" % [str(r["misfired"]), str(r["critical"]), str(r["ammo_name"])])
	_drained(res, "misfire queue drained")
	m.weapon_misfired = false
	CheckSystem.forced_rolls.assign([15] as Array[int])
	r = AttackSystem.execute_attack(m)
	var crit_ok := bool(r["critical"]) and not bool(r["misfired"]) and not m.weapon_misfired and int(r["core_successes"]) == 1 and m.ammo_loaded == 0 and str(r["ammo_name"]) == "Fang Dart"
	TestFixtures.check(res, "crit saves the misfire", crit_ok,
		"critical %s misfired %s successes %d ammo_loaded %d" % [str(r["critical"]), str(r["misfired"]),
		int(r["core_successes"]), m.ammo_loaded])
	_drained(res, "crit misfire queue drained")
	r = AttackSystem.execute_attack(m)
	var empty_ok := bool(r["no_ammo"]) and r.has("critical") and r.has("ammo_name") and r.has("enhancements") and r.has("flaws")
	TestFixtures.check(res, "empty gun result carries the new keys", empty_ok, "no_ammo %s keys %d" % [str(r["no_ammo"]), r.keys().size()])


static func _case_apply_hit(res: Dictionary) -> void:
	var ar := _arena(15)
	var atk_m: MercenaryData = ar["atk"]
	var def_m: MercenaryData = ar["def"]
	var state: BattleState = ar["state"]
	var w := WeaponData.new()
	w.inflict_states.assign(["Poisoned"] as Array[String])
	atk_m.equipped_weapon = w
	var atk := {"damage_type": "Strike", "ammo_name": ""}
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	var lines := CombatApplicator.apply_hit(atk_m, def_m, atk, 3, "Strike", state)
	var hit_ok := def_m.current_hp == 12 and ConstStates.has_state(def_m, ConstStates.POISONED)
	TestFixtures.check(res, "apply_hit deals damage then rolls the weapon inflict", hit_ok,
		"hp %d Poisoned %s lines %d" % [def_m.current_hp, str(ConstStates.has_state(def_m, ConstStates.POISONED)), lines.size()])
	_drained(res, "apply_hit queue drained")
	CheckSystem.forced_rolls.assign([50, 50, 50, 50] as Array[int])
	lines = CombatApplicator.apply_hit(atk_m, def_m, atk, 0, "Strike", state)
	TestFixtures.check(res, "apply_hit without damage rolls no inflict", def_m.current_hp == 12 and CheckSystem.forced_rolls.size() == 4,
		"hp %d queue %d" % [def_m.current_hp, CheckSystem.forced_rolls.size()])
	CheckSystem.forced_rolls.clear()


static func _case_perk_abort(res: Dictionary) -> void:
	var m := _merc(2, 0.0, 0.0)
	m.merc_name = "Ash"
	var t := _merc(2, 0.0, 0.0)
	t.merc_name = "Mark"
	var team_a: Array[MercenaryData] = [m]
	var team_b: Array[MercenaryData] = [t]
	var state := BattleState.create(team_a, team_b, null)
	m.current_ap = 1
	m.excess_ap = 1
	m.current_ep = 2
	m.current_rep = 1
	var perk := TraitData.new()
	perk.effect_dsl = "action:1:ep:1:rep:1:no_such_effect"
	var lines := PerkActionExecutor.execute_perk_action(m, perk, t, state, 0)
	var ok := lines.is_empty() and m.current_ap == 1 and m.excess_ap == 1 and m.current_ep == 2 and m.current_rep == 1
	TestFixtures.check(res, "perk abort refunds AP, excess AP, EP and ReP", ok,
		"ap %d excess %d ep %d rep %d lines %d" % [m.current_ap, m.excess_ap, m.current_ep, m.current_rep, lines.size()])
	m.current_ap = 2
	m.excess_ap = 0
	perk.effect_dsl = "action:1:attack_already_damaged"
	lines = PerkActionExecutor.execute_perk_action(m, perk, t, state, 0)
	TestFixtures.check(res, "perk abort without a prior attack refunds the AP", lines.is_empty() and m.current_ap == 2 and m.excess_ap == 0,
		"ap %d excess %d lines %d" % [m.current_ap, m.excess_ap, lines.size()])


#True when the pool is exactly the plain Dexterity rows plus the own_req row.
static func _defense_pool_ok(pool: Array, own_req: String) -> bool:
	var plain_dex := 0
	var own := 0
	for entry: Dictionary in pool:
		var req := str(entry["formula_stat_required"]).strip_edges().to_lower()
		if req == "" and str(entry["stat"]) == "Dexterity":
			plain_dex += 1
		elif req == own_req:
			own += 1
		else:
			return false
	return plain_dex == _plain_dex_rows() and own == 1


static func _case_whip_pull(res: Dictionary) -> void:
	var ar := _arena(10)
	var atk_m: MercenaryData = ar["atk"]
	var def_m: MercenaryData = ar["def"]
	var state: BattleState = ar["state"]
	state.positions[atk_m] = Vector2i(2, 2)
	state.positions[def_m] = Vector2i(4, 2)
	var w := WeaponData.new()
	w.item_name = "Probe Whip"
	w.weapon_type = "Probe Whip (Specialized)"
	atk_m.equipped_weapon = w
	atk_m.weapon_drawn = true
	var perk := TraitData.new()
	perk.effect_dsl = "reactive_action:on_hit:size_lte_self:pull_target:1"
	perk.gear_key = "Probe Whip"
	atk_m.weapon_perks.assign([perk] as Array[TraitData])
	atk_m.current_ep = 2
	ConstStates.apply_state(def_m, ConstStates.GRAPPLED, atk_m)
	var lines := WeaponReactiveSystem.apply_on_hit(atk_m, def_m, {"damage_type": "Strike"}, state)
	var pulled := state.distance_to(atk_m, def_m) == 1 and ConstStates.has_state(def_m, ConstStates.GRAPPLED) and atk_m.current_ep == 1
	TestFixtures.check(res, "whip pull drags a grappled target adjacent", pulled,
		"distance %d Grappled %s ep %d lines %d" % [state.distance_to(atk_m, def_m),
		str(ConstStates.has_state(def_m, ConstStates.GRAPPLED)), atk_m.current_ep, lines.size()])


#Count of the reward rows whose Stat is Dexterity and whose Success Formula Stat Required is blank.
static func _plain_dex_rows() -> int:
	var n := 0
	for entry: Dictionary in DataManager.critical_success_options:
		if str(entry["stat"]) == "Dexterity" and str(entry["formula_stat_required"]).strip_edges() == "":
			n += 1
	return n


static func _case_resolve_hit(res: Dictionary) -> void:
	var ar := _arena(10)
	var atk_m: MercenaryData = ar["atk"]
	var def_m: MercenaryData = ar["def"]
	var state: BattleState = ar["state"]
	state.positions[atk_m] = Vector2i(2, 2)
	state.positions[def_m] = Vector2i(4, 2)
	var w := WeaponData.new()
	w.item_name = "Probe Whip"
	w.weapon_type = "Probe Whip (Specialized)"
	atk_m.equipped_weapon = w
	atk_m.weapon_drawn = true
	var perk := TraitData.new()
	perk.effect_dsl = "reactive_action:on_hit:size_lte_self:pull_target:1"
	perk.gear_key = "Probe Whip"
	atk_m.weapon_perks.assign([perk] as Array[TraitData])
	atk_m.current_ep = 2
	ConstStates.apply_state(def_m, ConstStates.GRAPPLED, atk_m)
	var atk := {"damage_type": "Strike", "ammo_name": ""}
	var lines := AutoBattle._resolve_hit(atk_m, def_m, atk, 3, true, def_m.current_hp, state, 0)
	var chosen_ok := def_m.current_hp == 10 and state.distance_to(atk_m, def_m) == 1 and atk_m.current_ep == 1
	TestFixtures.check(res, "a hit whose damage a choose arm replaced still fires the whip pull", chosen_ok,
		"hp %d distance %d ep %d lines %d" % [def_m.current_hp, state.distance_to(atk_m, def_m), atk_m.current_ep, lines.size()])
	state.positions[def_m] = Vector2i(4, 2)
	atk_m.current_ep = 2
	lines = AutoBattle._resolve_hit(atk_m, def_m, atk, 3, false, def_m.current_hp, state, 0)
	var plain_ok := def_m.current_hp == 7 and state.distance_to(atk_m, def_m) == 1 and atk_m.current_ep == 1
	TestFixtures.check(res, "a plain hit deals damage and then fires the whip pull", plain_ok,
		"hp %d distance %d ep %d lines %d" % [def_m.current_hp, state.distance_to(atk_m, def_m), atk_m.current_ep, lines.size()])


#A Success Formula names its contract checks with team.<stat>; target and location terms name none.
static func _case_formula_kinds(res: Dictionary) -> void:
	var one: Array[String] = FormulaEventResolver.check_kinds("team.negotiate - (50.0 - (target.wile * 10.0))")
	TestFixtures.check(res, "one team stat is one check kind", _kinds_eq(one, ["negotiate"] as Array[String]),
		"got [%s]" % ", ".join(one))
	var two: Array[String] = FormulaEventResolver.check_kinds("team.negotiate + team.stealth - location.difficulty")
	TestFixtures.check(res, "two team stats are two check kinds", _kinds_eq(two, ["negotiate", "stealth"] as Array[String]),
		"got [%s]" % ", ".join(two))
	var dup: Array[String] = FormulaEventResolver.check_kinds("(team.wile * 2.0) + team.wile")
	TestFixtures.check(res, "a repeated team stat is named once", _kinds_eq(dup, ["wile"] as Array[String]),
		"got [%s]" % ", ".join(dup))
	var none: Array[String] = FormulaEventResolver.check_kinds("100.0 - (target.wile * 10.0)")
	TestFixtures.check(res, "target terms are not check kinds", none.is_empty(), "got [%s]" % ", ".join(none))
	TestFixtures.check(res, "a blank formula names no check", FormulaEventResolver.check_kinds("").is_empty(),
		"blank formula")


static func _kinds_eq(actual: Array[String], want: Array[String]) -> bool:
	if actual.size() != want.size():
		return false
	for i: int in range(want.size()):
		if actual[i] != want[i]:
			return false
	return true
