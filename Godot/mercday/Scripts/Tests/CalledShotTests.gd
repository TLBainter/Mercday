class_name CalledShotTests

#Called Shot options, the success penalty, the effects, the AI pick and the two perk rows.
#Run: godot --headless --path . -- --calledshot-tests

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


static func run() -> bool:
	seed(7777)
	var res := {"pass": 0, "fail": 0}
	_case_options(res)
	_case_penalty(res)
	_case_misfire(res)
	_case_critical(res)
	_case_landed(res)
	_case_min_1_floor(res)
	_case_state_options(res)
	_case_immunity(res)
	_case_validity(res)
	_case_wrist(res)
	_case_wing(res)
	_case_wound(res)
	_case_face(res)
	_case_hobbled(res)
	_case_shock_gate(res)
	_case_escalation(res)
	_case_attack_arm(res)
	_case_ai(res)
	_case_binomial(res)
	_case_weapon_dice(res)
	var marked := _case_marked_context(res)
	_case_reduction_split(res, marked)
	_case_reduction_dodge(res)
	_case_estimate_ammo(res, marked)
	_case_estimate_toys(res)
	_case_option_pick(res, marked)
	_case_facing(res)
	_case_perk_rows(res)
	_case_atlas(res)
	_case_skull(res)
	_case_atlas_effects(res)
	_case_skull_effects(res)
	_case_counters(res)
	return TestFixtures.summarize(res, "CALLEDSHOT")


static func _case_options(res: Dictionary) -> void:
	var shaped := true
	for key: String in CalledShotSystem.OPTIONS:
		var opt: Dictionary = CalledShotSystem.OPTIONS[key]
		if str(opt.get("label", "")) == "" or int(opt.get("value", 0)) <= 0:
			shaped = false
	TestFixtures.check(res, "every called shot option carries a label and a cost",
		CalledShotSystem.OPTIONS.size() == 11 and shaped,
		"%d options" % CalledShotSystem.OPTIONS.size())
	var ai_ok := true
	for key: String in CalledShotSystem.AI_OPTIONS:
		if not CalledShotSystem.OPTIONS.has(key):
			ai_ok = false
	TestFixtures.check(res, "the AI list holds every option but the face",
		ai_ok and CalledShotSystem.AI_OPTIONS.size() == 10
			and not CalledShotSystem.AI_OPTIONS.has("face"),
		"%d ai options" % CalledShotSystem.AI_OPTIONS.size())
	TestFixtures.check(res, "value and label read the option table",
		CalledShotSystem.value("throat") == 5
			and CalledShotSystem.label("vital_organ") == "Vital Organ"
			and CalledShotSystem.value("nose") == 0,
		"throat %d" % CalledShotSystem.value("throat"))


static func _case_penalty(res: Dictionary) -> void:
	var m := _probe("Penalty")
	m.equipped_weapon = _light_melee()
	m.weapon_drawn = true
	CheckSystem.forced_rolls.assign([14, 14, 14] as Array[int])
	var atk := AttackSystem.execute_attack(m, 0, 0, null, false, null, false, 2)
	TestFixtures.check(res, "a called shot removes its successes from the core roll",
		int(atk["core_successes"]) == 1 and int(atk["damage"]) == 1,
		"core %d damage %d" % [int(atk["core_successes"]), int(atk["damage"])])
	TestFixtures.check(res, "the attack result reports the penalty it applied",
		int(atk["success_penalty"]) == 2 and bool(atk["called_shot"]),
		"penalty %d called %s" % [int(atk["success_penalty"]), str(atk["called_shot"])])
	var clamped := _probe("Clamped")
	clamped.equipped_weapon = _light_melee()
	clamped.weapon_drawn = true
	CheckSystem.forced_rolls.assign([14, 100, 50, 100, 50] as Array[int])
	var low := AttackSystem.execute_attack(clamped, 0, 0, null, false, null, false, 3)
	TestFixtures.check(res, "the penalty never drives the core roll below zero",
		int(low["core_successes"]) == 0 and int(low["success_penalty"]) == 1,
		"core %d penalty %d" % [int(low["core_successes"]), int(low["success_penalty"])])
	CheckSystem.forced_rolls.clear()


static func _case_misfire(res: Dictionary) -> void:
	var m := _probe("Gunner")
	m.equipped_weapon = _ranged()
	m.weapon_drawn = true
	m.ammo_loaded = 2
	CheckSystem.forced_rolls.assign([14, 14, 100, 50] as Array[int])
	var atk := AttackSystem.execute_attack(m, 0, 0, null, false, null, false, 2)
	TestFixtures.check(res, "the misfire check reads the roll before the called shot penalty",
		not bool(atk["misfired"]) and int(atk["core_successes"]) == 0,
		"misfired %s core %d" % [str(atk["misfired"]), int(atk["core_successes"])])
	var jam := _probe("Jammer")
	jam.equipped_weapon = _ranged()
	jam.weapon_drawn = true
	jam.ammo_loaded = 2
	CheckSystem.forced_rolls.assign([14, 100, 50, 100, 50] as Array[int])
	var bad := AttackSystem.execute_attack(jam, 0, 0, null, false, null, false, 2)
	TestFixtures.check(res, "a misfired called shot still reports itself as one",
		bool(bad["misfired"]) and bool(bad["called_shot"]) and int(bad["success_penalty"]) == 0,
		"misfired %s called %s" % [str(bad["misfired"]), str(bad["called_shot"])])
	CheckSystem.forced_rolls.clear()


static func _case_critical(res: Dictionary) -> void:
	var m := _probe("Critter")
	m.equipped_weapon = _light_melee()
	m.weapon_drawn = true
	var atk: Dictionary = _with_rolls([15, 15, 15],
		func() -> Dictionary: return AttackSystem.execute_attack(m, 0, 0, null, false, null, false, 3))
	TestFixtures.check(res, "a critical ignores the called shot penalty",
		bool(atk["critical"]) and int(atk["core_successes"]) == 3
			and int(atk["success_penalty"]) == 0,
		"critical %s core %d" % [str(atk["critical"]), int(atk["core_successes"])])
	TestFixtures.check(res, "a critical called shot always lands",
		CalledShotSystem.landed(atk, CalledShotSystem.hp_total(m), m),
		"critical %s" % str(atk["critical"]))


static func _case_landed(res: Dictionary) -> void:
	var t := _probe("Marked")
	var before := CalledShotSystem.hp_total(t)
	TestFixtures.check(res, "a critical lands with no hit points marked",
		CalledShotSystem.landed({"critical": true}, before, t), "hp %d" % before)
	TestFixtures.check(res, "an unmarked target turns the called shot away",
		not CalledShotSystem.landed({}, before, t), "hp %d" % before)
	t.current_hp -= 1
	TestFixtures.check(res, "one marked hit point lands the called shot",
		CalledShotSystem.landed({}, before, t),
		"hp %d of %d" % [CalledShotSystem.hp_total(t), before])
	TestFixtures.check(res, "a mark that is only the min 1 floor turns the called shot away",
		not CalledShotSystem.landed({"min_1_only": true}, before, t),
		"hp %d of %d" % [CalledShotSystem.hp_total(t), before])
	TestFixtures.check(res, "a critical lands through the min 1 floor",
		CalledShotSystem.landed({"critical": true, "min_1_only": true}, before, t),
		"hp %d of %d" % [CalledShotSystem.hp_total(t), before])
	TestFixtures.check(res, "a called shot that spends its last core success turns away",
		not CalledShotSystem.landed({"core_successes": 0}, before, t),
		"hp %d of %d" % [CalledShotSystem.hp_total(t), before])
	TestFixtures.check(res, "one core success left over lands the called shot",
		CalledShotSystem.landed({"core_successes": 1}, before, t),
		"hp %d of %d" % [CalledShotSystem.hp_total(t), before])
	TestFixtures.check(res, "a critical lands with no core success left",
		CalledShotSystem.landed({"critical": true, "core_successes": 0}, before, t),
		"hp %d of %d" % [CalledShotSystem.hp_total(t), before])


#The DefenseSystem flag that tells a min 1 floor mark apart from damage the defence let through.
static func _case_min_1_floor(res: Dictionary) -> void:
	_with_rolls([], func() -> void:
		var covered := DefenseSystem.resolve(_floor_target("Floored", 3), 2, "Impale", 0, true)
		TestFixtures.check(res, "an impale the defend roll covers marks the floor and raises the flag",
			int(covered["final_damage"]) == 1 and bool(covered["min_1_only"]),
			"final %d flag %s" % [int(covered["final_damage"]), str(covered["min_1_only"])])
		var partial := DefenseSystem.resolve(_floor_target("Grazed", 1), 3, "Impale", 0, true)
		TestFixtures.check(res, "an impale the defend roll only blunts leaves the flag down",
			int(partial["final_damage"]) == 2 and not bool(partial["min_1_only"]),
			"final %d flag %s" % [int(partial["final_damage"]), str(partial["min_1_only"])])
		var struck := DefenseSystem.resolve(_floor_target("Struck", 4), 2, "Strike", 0, true)
		TestFixtures.check(res, "a strike has no min 1 rule so a covered hit marks nothing",
			int(struck["final_damage"]) == 0 and not bool(struck["min_1_only"]),
			"final %d flag %s" % [int(struck["final_damage"]), str(struck["min_1_only"])])
		var burned := DefenseSystem.resolve(_floor_target("Burned", 3), 3, "Fire", 0, true)
		TestFixtures.check(res, "a hit that marks only its direct portion leaves the flag down",
			int(burned["final_damage"]) == 1 and not bool(burned["min_1_only"]),
			"final %d flag %s" % [int(burned["final_damage"]), str(burned["min_1_only"])])
	)


static func _case_state_options(res: Dictionary) -> void:
	var expect := {"calf": "Hobbled", "ear": "Deafened", "eye": "Blinded", "heel": "Deposed",
		"mouth": "Mute", "throat": "Vulnerable", "vital_organ": "Shocked"}
	for key: String in expect:
		var merc := _probe("Caller")
		var target := _probe("Mark")
		var state := _duel(merc, target)
		var lines := CalledShotSystem.apply_effect(merc, target, key, {}, state)
		TestFixtures.check(res, "a called shot to the %s inflicts %s" % [key, str(expect[key])],
			ConstStates.has_state(target, str(expect[key])) and not lines.is_empty(),
			"%d lines" % lines.size())
	var timer_merc := _probe("Timer")
	var timed := _probe("Timed")
	var timer_state := _duel(timer_merc, timed)
	timer_state.round_number = 4
	CalledShotSystem.apply_effect(timer_merc, timed, "eye", {}, timer_state)
	CalledShotSystem.apply_effect(timer_merc, timed, "heel", {}, timer_state)
	TestFixtures.check(res, "only a called shot state with rounds gets a timer",
		not timer_state.get_state_timer(timed, "Blinded").is_empty()
			and timer_state.get_state_timer(timed, "Deposed").is_empty(),
		"blinded %s" % str(timer_state.get_state_timer(timed, "Blinded")))


static func _case_immunity(res: Dictionary) -> void:
	var merc := _probe("Prober")
	var target := _probe("Warded")
	target.passive_effects.append("immune:blinded")
	var state := _duel(merc, target)
	var lines := CalledShotSystem.apply_effect(merc, target, "eye", {}, state)
	TestFixtures.check(res, "an immune target shrugs off the called shot state",
		not ConstStates.has_state(target, "Blinded") and TestFixtures.has_line(lines, "is immune to Blinded!"),
		"%d lines" % lines.size())
	TestFixtures.check(res, "the learned immunity takes the option off the list",
		not CalledShotSystem.is_valid(merc, target, "eye", state),
		"knows %s" % str(BattleState.knows(merc, target, "immune:blinded")))


static func _case_validity(res: Dictionary) -> void:
	var merc := _probe("Judge")
	var target := _probe("Subject")
	var state := _duel(merc, target)
	TestFixtures.check(res, "an unknown option is never valid",
		not CalledShotSystem.is_valid(merc, target, "nose", state), "nose")
	var open := CalledShotSystem.is_valid(merc, target, "eye", state)
	StateCascade.apply_state(target, "Blinded", merc, "", "test")
	TestFixtures.check(res, "a held state takes its own option off the list",
		open and not CalledShotSystem.is_valid(merc, target, "eye", state), "Blinded held")
	TestFixtures.check(res, "the wing is called only against a flyer",
		not CalledShotSystem.is_valid(merc, target, "wing", state),
		"fly %d" % int(target.stats.get("fly", 0)))
	target.stats["fly"] = 2
	TestFixtures.check(res, "a flyer opens the wing",
		CalledShotSystem.is_valid(merc, target, "wing", state), "fly 2")
	target.weapon_drawn = false
	var wrist_off := not CalledShotSystem.is_valid(merc, target, "wrist", state)
	target.is_dead = true
	TestFixtures.check(res, "the wrist needs a drawn weapon and a dead target has no options",
		wrist_off and not CalledShotSystem.is_valid(merc, target, "calf", state), "dead")


static func _case_wrist(res: Dictionary) -> void:
	var merc := _probe("Disarmer")
	var target := _probe("Holder")
	var state := _duel(merc, target)
	var held := target.equipped_weapon
	var lines := CalledShotSystem.apply_effect(merc, target, "wrist", {}, state)
	TestFixtures.check(res, "a called shot to the wrist drops the held weapon",
		TestFixtures.has_line(lines, "drops") and target.equipped_weapon != held,
		"%d lines" % lines.size())
	var again := CalledShotSystem.apply_effect(merc, target, "wrist", {}, state)
	TestFixtures.check(res, "an empty handed target has nothing to drop",
		TestFixtures.has_line(again, "has nothing to drop."), "%d lines" % again.size())


static func _case_wing(res: Dictionary) -> void:
	var merc := _probe("Clipper")
	var target := _probe("Flyer")
	target.stats["fly"] = 2
	var state := _duel(merc, target)
	state.set_height(target, 3)
	var lines := CalledShotSystem.apply_effect(merc, target, "wing", {}, state)
	TestFixtures.check(res, "a called shot to the wing grounds the flyer",
		ConstStates.has_state(target, "Grounded") and state.get_height(target) == 0,
		"height %d" % state.get_height(target))
	TestFixtures.check(res, "a grounded flyer falls the height it held",
		TestFixtures.has_line(lines, "falls 3 Paces!"), "%d lines" % lines.size())


static func _case_wound(res: Dictionary) -> void:
	var merc := _probe("Wounder")
	var target := _probe("Wounded")
	var state := _duel(merc, target)
	var lines := CalledShotSystem.apply_effect(merc, target, "wound", {}, state)
	TestFixtures.check(res, "a called shot to a wound narrates the grievous hit",
		TestFixtures.has_line(lines, "strikes a grievous wound!"), "%d lines" % lines.size())
	var plain := CalledShotOdds.effect_value(merc, target, "wound", state)
	var ballista := TestFixtures.arm(_probe("Ballista"), "Hand Ballista", "Hand Ballista|Hand Ballista Critical", true)
	var armed_worth := CalledShotOdds.effect_value(ballista, target, "wound", state)
	TestFixtures.check(res, "the wound is worth nothing without an on_crit perk",
		is_zero_approx(plain) and is_equal_approx(armed_worth, CalledShotSystem.WOUND_VALUE),
		"plain %.2f armed %.2f" % [plain, armed_worth])


static func _case_face(res: Dictionary) -> void:
	var merc := _probe("Scarrer")
	var target := _probe("Unmarred")
	var state := _duel(merc, target)
	var open := CalledShotSystem.is_valid(merc, target, "face", state)
	var lines := CalledShotSystem.apply_effect(merc, target, "face", {}, state)
	TestFixtures.check(res, "a called shot to the face scars the target",
		open and TestFixtures.has_line(lines, "is scarred!"), "%d lines" % lines.size())
	TestFixtures.check(res, "a scarred target closes the face option",
		LifepathProgression.has_event(target, "Scarred")
			and not CalledShotSystem.is_valid(merc, target, "face", state),
		"scarred %s" % str(LifepathProgression.has_event(target, "Scarred")))


static func _case_hobbled(res: Dictionary) -> void:
	var m := _probe("Limper")
	m.stats["pace"] = 5
	var base := PaceBudget.pace_per_move(m)
	StateCascade.apply_state(m, "Hobbled", null, "", "test")
	TestFixtures.check(res, "Hobbled takes two paces off every Move",
		StateEffects.pace_modifier(m) == -2 and PaceBudget.pace_per_move(m) == base - 2,
		"%d paces to %d" % [base, PaceBudget.pace_per_move(m)])
	var slow := _probe("Crawler")
	slow.stats["pace"] = 2
	StateCascade.apply_state(slow, "Hobbled", null, "", "test")
	TestFixtures.check(res, "a hobbled Move never drops below one pace",
		PaceBudget.pace_per_move(slow) == 1,
		"%d paces" % PaceBudget.pace_per_move(slow))


static func _case_shock_gate(res: Dictionary) -> void:
	var merc := _probe("Shockee")
	var foe := _probe("Onlooker")
	var state := _duel(merc, foe)
	var clear_lines: Array[String] = []
	var acts := AutoBattle.process_start_of_turn_states(merc, state, clear_lines)
	StateCascade.apply_state(merc, "Shocked", foe, "", "test")
	var lines: Array[String] = []
	var blocked := AutoBattle.process_start_of_turn_states(merc, state, lines)
	TestFixtures.check(res, "a state that blocks every action skips the turn",
		not acts and blocked, "clear %s shocked %s" % [str(acts), str(blocked)])
	TestFixtures.check(res, "the skipped turn names the state that blocked it",
		TestFixtures.has_line(lines, "is shocked and cannot act!"), "%d lines" % lines.size())


static func _case_escalation(res: Dictionary) -> void:
	var merc := _probe("Spender")
	var foe := _probe("Priced")
	var state := _duel(merc, foe)
	var base := state.get_cost(merc, "CalledShot", AutoBattle.ATTACK_BASE_AP)
	state.record_action(merc, "CalledShot")
	var second := state.get_cost(merc, "CalledShot", AutoBattle.ATTACK_BASE_AP)
	TestFixtures.check(res, "a called shot escalates its own price",
		base == AutoBattle.ATTACK_BASE_AP and second == base + 1,
		"%d AP to %d" % [base, second])
	TestFixtures.check(res, "a called shot leaves the plain Attack price alone",
		state.get_cost(merc, "Attack", AutoBattle.ATTACK_BASE_AP) == AutoBattle.ATTACK_BASE_AP,
		"attack %d AP" % state.get_cost(merc, "Attack", AutoBattle.ATTACK_BASE_AP))


static func _case_attack_arm(res: Dictionary) -> void:
	CheckSystem.forced_rolls.clear()
	var merc := _probe("Armer")
	var foe := _probe("Struck")
	var state := _duel(merc, foe)
	merc.current_ap = 6
	merc.excess_ap = 0
	var turn := {}
	var decision := {"type": "attack", "action_name": "Attack", "target": foe, "called_shot": "eye"}
	var lines := AttackArm.run_attack_arm(merc, decision, state, 0, 0, turn)
	TestFixtures.check(res, "the attack arm announces the call it was given",
		TestFixtures.has_line(lines, "calls the shot: Eye (2)!"), "%d lines" % lines.size())
	TestFixtures.check(res, "the attack arm charges the called shot bucket",
		int((state.escalation.get(merc, {}) as Dictionary).get("CalledShot", 0)) == 1
			and merc.current_ap == 6 - AutoBattle.ATTACK_BASE_AP,
		"%d AP left" % merc.current_ap)


static func _case_ai(res: Dictionary) -> void:
	var was_force := CalledShotSystem.force_every
	var merc := _probe("Picker")
	var foe := _probe("Picked")
	var state := _duel(merc, foe)
	merc.current_ap = 6
	merc.excess_ap = 0
	var move := {"type": "move", "action_name": "Move Close", "target": foe}
	TestFixtures.check(res, "upgrade leaves a decision that is not a plain Attack alone",
		not CalledShotOdds.upgrade(merc, move, state).has("called_shot"), "Move Close")
	CalledShotSystem.force_every = true
	var attack := {"type": "attack", "action_name": "Attack", "target": foe}
	var upgraded := CalledShotOdds.upgrade(merc, attack, state)
	TestFixtures.check(res, "upgrade turns a plain Attack into a valid called shot",
		CalledShotSystem.OPTIONS.has(str(upgraded.get("called_shot", ""))),
		"picked %s" % str(upgraded.get("called_shot", "")))
	merc.current_ap = 0
	merc.excess_ap = 0
	TestFixtures.check(res, "upgrade backs off when the called shot is unaffordable",
		not CalledShotOdds.upgrade(merc, attack, state).has("called_shot"), "0 AP")
	CalledShotSystem.force_every = was_force


#The binomial spread and the success spread the estimate is built on.
static func _case_binomial(res: Dictionary) -> void:
	var half := CheckSystem.binomial_distribution(2, 0.5)
	var none := CheckSystem.binomial_distribution(0, 0.3)
	var sure := CheckSystem.binomial_distribution(3, 1.0)
	TestFixtures.check(res, "the binomial spread matches the hand worked rows",
		half.size() == 3 and absf(half[0] - 0.25) < 1e-6 and absf(half[1] - 0.5) < 1e-6
			and absf(half[2] - 0.25) < 1e-6 and none.size() == 1 and absf(none[0] - 1.0) < 1e-6
			and sure.size() == 4 and absf(sure[3] - 1.0) < 1e-6 and absf(sure[0]) < 1e-6,
		"%.2f/%.2f/%.2f" % [half[0], half[1], half[2]])
	var dist_merc := _probe("Dist")
	dist_merc.equipped_weapon = _light_melee()
	dist_merc.weapon_drawn = true
	var attack_def := PerkValuation.attack_check_def(dist_merc, null, dist_merc.equipped_weapon, 0, 0, null)
	var dist := CheckSystem.success_distribution(dist_merc, attack_def)
	var pmf: Array[float] = dist["pmf"]
	var total := _sum(pmf)
	var tail := _sum(pmf, 2)
	TestFixtures.check(res, "the success spread sums to one and matches the trial chance",
		pmf.size() == int(dist["dice"]) + 1 and absf(total - 1.0) < 1e-6
			and absf(tail - CheckSystem.expected_success_chance(dist_merc, attack_def, 2)) < 1e-6,
		"%d dice sum %.4f tail %.4f" % [int(dist["dice"]), total, tail])


#The weapon die spread read off the damage formula.
static func _case_weapon_dice(res: Dictionary) -> void:
	var dice_weapon := TestFixtures.weapon("Test")
	dice_weapon.damage_formula_1 = "2d6 + 1"
	var rolled := PerkValuation.weapon_die_distribution(dice_weapon, 50.0)
	var rolled_pmf: Array[float] = rolled["pmf"]
	var varied := TestFixtures.weapon("Test")
	varied.damage_formula_1 = "Varies"
	var varied_dist := PerkValuation.weapon_die_distribution(varied, 50.0)
	var varied_pmf: Array[float] = varied_dist["pmf"]
	var bare := PerkValuation.weapon_die_distribution(null, 50.0)
	var bare_pmf: Array[float] = bare["pmf"]
	TestFixtures.check(res, "the weapon dice spread reads the damage formula",
		rolled_pmf.size() == 3 and absf(rolled_pmf[0] - 0.25) < 1e-6
			and absf(rolled_pmf[1] - 0.5) < 1e-6 and absf(rolled_pmf[2] - 0.25) < 1e-6
			and int(rolled["flat"]) == 1, "flat %d" % int(rolled["flat"]))
	TestFixtures.check(res, "a weapon without a damage formula adds no dice and no bonus",
		varied_pmf.size() == 1 and int(varied_dist["flat"]) == 0 and bare_pmf.size() == 1
			and int(bare["flat"]) == 0,
		"varies %d bare %d" % [varied_pmf.size(), bare_pmf.size()])


#The marked context of an undefended swing; the marker, the dummy and the context carry on.
static func _case_marked_context(res: Dictionary) -> Dictionary:
	var marker := _probe("Marker")
	var dummy := _probe("Dummy")
	var open_state := _duel(marker, dummy)
	_drained(dummy, 30, 0)
	var ctx := CalledShotOdds.marked_context(marker, dummy, open_state, 0)
	var core: Array[float] = ctx["core"]
	var core_tail := _sum(core, 2)
	var l0 := float(CalledShotOdds.expected_marked(ctx, 0)["land"])
	var l1 := float(CalledShotOdds.expected_marked(ctx, 1)["land"])
	var l2 := float(CalledShotOdds.expected_marked(ctx, 2)["land"])
	var l3 := float(CalledShotOdds.expected_marked(ctx, 3)["land"])
	var d0 := float(CalledShotOdds.expected_marked(ctx, 0)["damage"])
	TestFixtures.check(res, "an undefended swing lands as often as the core roll succeeds",
		absf(l0 - (1.0 - pow(0.85, 3.0))) < 1e-3 and absf(l1 - core_tail) < 1e-3 and l3 < 1e-3,
		"%.3f %.3f %.3f" % [l0, l1, l3])
	TestFixtures.check(res, "an undefended swing marks its mean core successes",
		absf(d0 - 0.45) < 1e-3 and l0 >= l1 and l1 >= l2 and l2 >= l3, "%.3f marked" % d0)
	return {"marker": marker, "dummy": dummy, "state": open_state, "ctx": ctx, "land": l0}


#The reduction split between the defend roll and the dodge roll, and what it lets land.
static func _case_reduction_split(res: Dictionary, marked: Dictionary) -> void:
	var l0: float = marked["land"]
	var striker := _probe("Striker")
	var guard := _probe("Guard")
	guard.stats["defend_reduction"] = 3
	guard.stats["dodge_reduction"] = 0
	guard.stats["maximum_hit_points"] = 10
	var guard_state := _duel(striker, guard)
	guard.current_hp = 3
	guard.excess_hp = 0
	var guard_ctx := CalledShotOdds.marked_context(striker, guard, guard_state, 0)
	var guarded := CalledShotOdds.expected_marked(guard_ctx, 0)
	TestFixtures.check(res, "a target that defends every hit turns part of the swing away",
		float(guarded["land"]) > 0.0 and float(guarded["land"]) < l0
			and float(guarded["damage"]) < 0.45,
		"land %.3f marked %.3f" % [float(guarded["land"]), float(guarded["damage"])])
	var split := CalledShotOdds._reduction_distribution(guard, "Impale",
		WeaponArmorPerkLibrary.defense_flaws_against(striker, guard))
	var defend_won: Array[float] = split["defend"]
	var dodge_won: Array[float] = split["dodge"]
	var defend_mass := _sum(defend_won)
	var dodge_mass := _sum(dodge_won)
	TestFixtures.check(res, "the split reduction sums to one and a tie goes to the defend roll",
		absf(defend_mass + dodge_mass - 1.0) < 1e-6 and dodge_won[0] < 1e-9 and defend_won[0] > 0.0,
		"defend %.4f dodge %.4f" % [defend_mass, dodge_mass])
	var guard_land: Array[float] = guard_ctx["land_by_d"]
	TestFixtures.check(res, "an impale hit the defend roll turns fully away marks 1 hp and does not land",
		guard_land.size() > 1 and absf(guard_land[1] - defend_won[0]) < 1e-6
			and guard_land[1] < defend_mass,
		"land at 1 %.4f defend at 0 %.4f of %.4f" % [guard_land[1], defend_won[0], defend_mass])
	var rule_ok := guard_land.size() > 1
	for d: int in range(1, guard_land.size()):
		if not CombatDecision.should_attempt_defense(guard, d, "Impale"):
			continue
		var want := 0.0
		for rd: int in range(mini(d, defend_won.size())):
			want += defend_won[rd]
		for rv: int in range(mini(d, dodge_won.size())):
			want += dodge_won[rv]
		if absf(guard_land[d] - want) > 1e-6:
			rule_ok = false
	TestFixtures.check(res, "a defended impale lands only on the rolls that leave a hit point past the floor",
		rule_ok, "%d damage values" % guard_land.size())


#A lacerate hit dodged fully away marks a hit point without landing one.
static func _case_reduction_dodge(res: Dictionary) -> void:
	var slasher := _probe("Slasher")
	slasher.equipped_weapon = _light_melee()
	slasher.equipped_weapon.damage_types_1 = ["Lacerate"] as Array[String]
	var dodger := _probe("Dodger")
	dodger.equipped_weapon = _light_melee()
	dodger.stats["defend_reduction"] = 0
	dodger.stats["dodge_reduction"] = 3
	dodger.stats["maximum_hit_points"] = 10
	var dodge_state := TestFixtures.duel(slasher, dodger)
	dodger.current_hp = 3
	dodger.excess_hp = 0
	var dodge_ctx := CalledShotOdds.marked_context(slasher, dodger, dodge_state, 0)
	var dodge_split := CalledShotOdds._reduction_distribution(dodger, "Lacerate",
		WeaponArmorPerkLibrary.defense_flaws_against(slasher, dodger))
	var dodge_wins: Array[float] = dodge_split["dodge"]
	var defend_wins: Array[float] = dodge_split["defend"]
	var dodge_win_mass := _sum(dodge_wins)
	var dodge_land: Array[float] = dodge_ctx["land_by_d"]
	TestFixtures.check(res, "a lacerate hit dodged fully away marks 1 hp and does not land",
		dodge_land.size() > 1 and dodge_win_mass > 0.0
			and absf(dodge_land[1] - defend_wins[0]) < 1e-6
			and dodge_land[1] < dodge_win_mass + defend_wins[0],
		"land at 1 %.4f dodge wins %.4f" % [dodge_land[1], dodge_win_mass])


#The ammo type a varies weapon takes into the estimate and the misfire value it carries.
static func _case_estimate_ammo(res: Dictionary, marked: Dictionary) -> void:
	var ctx: Dictionary = marked["ctx"]
	var shot := AmmoData.new()
	shot.item_name = "Test Impale Shot"
	shot.item_type = "Ammo"
	shot.damage_types_1 = ["Impale"] as Array[String]
	DataManager.ammo["Test Impale Shot"] = shot
	var shooter := _probe("Shooter")
	shooter.equipped_weapon = _ranged()
	shooter.equipped_weapon.damage_types_1 = ["Varies"] as Array[String]
	shooter.equipped_weapon.ranged_intended_range = 20
	shooter.equipped_weapon.ranged_extended_range = 40
	shooter.ammo_loaded = 3
	shooter.ammo_loaded_type = "Test Impale Shot"
	var plate := _probe("Plate")
	plate.equipped_weapon = _light_melee()
	plate.stats["defend_reduction"] = 3
	plate.stats["dodge_reduction"] = 0
	plate.stats["maximum_hit_points"] = 10
	var shot_state := TestFixtures.duel(shooter, plate)
	plate.current_hp = 3
	plate.excess_hp = 0
	var shot_ctx := CalledShotOdds.marked_context(shooter, plate, shot_state, 0)
	var shot_split := CalledShotOdds._reduction_distribution(plate, "Impale",
		WeaponArmorPerkLibrary.defense_flaws_against(shooter, plate))
	var shot_defend: Array[float] = shot_split["defend"]
	var shot_defend_mass := _sum(shot_defend)
	var shot_land: Array[float] = shot_ctx["land_by_d"]
	var shot_land_1 := shot_land[1] if shot_land.size() > 1 else -1.0
	TestFixtures.check(res, "a ranged varies weapon takes the loaded ammo's type in the estimate",
		str(shot_ctx["type"]) == "Impale" and absf(shot_land_1 - shot_defend[0]) < 1e-6
			and shot_land_1 < shot_defend_mass,
		"type %s land at 1 %.4f defend at 0 %.4f" % [str(shot_ctx["type"]), shot_land_1, shot_defend[0]])
	shooter.ammo_loaded_type = ""
	var dry_ctx := CalledShotOdds.marked_context(shooter, plate, shot_state, 0)
	TestFixtures.check(res, "a ranged varies weapon with nothing loaded keeps the varies type",
		str(dry_ctx["type"]) == "Varies", "type %s" % str(dry_ctx["type"]))
	DataManager.ammo.erase("Test Impale Shot")
	TestFixtures.check(res, "a ranged weapon's misfire value enters the estimate context and a melee weapon's does not",
		int(shot_ctx["misfire"]) == 2 and int(ctx["misfire"]) == 0,
		"ranged %d melee %d" % [int(shot_ctx["misfire"]), int(ctx["misfire"])])


#The toy contexts that pin the misfire floor and the core cost of a called shot.
static func _case_estimate_toys(res: Dictionary) -> void:
	var toy := {"core": [0.2, 0.3, 0.5] as Array[float], "crit": 0.0, "dice": [1.0] as Array[float], "flat": 0,
		"type": "Strike", "misfire": 2, "land_by_d": [0.0, 1.0, 1.0] as Array[float],
		"dmg_by_d": [0.0, 1.0, 2.0] as Array[float]}
	var toy_plain := CalledShotOdds.expected_marked(toy, 0)
	var toy_called := CalledShotOdds.expected_marked(toy, 1)
	toy["misfire"] = 0
	var toy_safe := CalledShotOdds.expected_marked(toy, 0)
	TestFixtures.check(res, "rolls under the misfire value mark nothing and the check reads the unreduced roll",
		absf(float(toy_plain["land"]) - 0.5) < 1e-9 and absf(float(toy_plain["damage"]) - 1.0) < 1e-9
			and absf(float(toy_called["land"]) - 0.5) < 1e-9 and absf(float(toy_called["damage"]) - 0.5) < 1e-9
			and absf(float(toy_safe["land"]) - 0.8) < 1e-9 and absf(float(toy_safe["damage"]) - 1.3) < 1e-9,
		"plain %.2f/%.2f called %.2f/%.2f safe %.2f/%.2f" % [float(toy_plain["land"]), float(toy_plain["damage"]),
			float(toy_called["land"]), float(toy_called["damage"]), float(toy_safe["land"]), float(toy_safe["damage"])])
	toy["misfire"] = 3
	toy["crit"] = 0.1
	var toy_crit := CalledShotOdds.expected_marked(toy, 0)
	TestFixtures.check(res, "a critical still lands when every roll sits under the misfire value",
		absf(float(toy_crit["land"]) - 0.1) < 1e-9 and absf(float(toy_crit["damage"])) < 1e-9,
		"land %.2f damage %.2f" % [float(toy_crit["land"]), float(toy_crit["damage"])])
	var cost_toy := {"core": [0.0, 0.0, 1.0] as Array[float], "crit": 0.0, "dice": [1.0] as Array[float],
		"flat": 1, "type": "Strike", "misfire": 0,
		"land_by_d": [0.0, 1.0, 1.0, 1.0] as Array[float],
		"dmg_by_d": [0.0, 1.0, 2.0, 3.0] as Array[float]}
	var spent := CalledShotOdds.expected_marked(cost_toy, 2)
	var kept_one := CalledShotOdds.expected_marked(cost_toy, 1)
	var uncalled := CalledShotOdds.expected_marked(cost_toy, 0)
	TestFixtures.check(res, "a called shot that spends every core success marks hp and lands nothing",
		absf(float(spent["land"])) < 1e-9 and absf(float(spent["damage"]) - 1.0) < 1e-9
			and absf(float(kept_one["land"]) - 1.0) < 1e-9 and absf(float(kept_one["damage"]) - 2.0) < 1e-9
			and absf(float(uncalled["land"]) - 1.0) < 1e-9 and absf(float(uncalled["damage"]) - 3.0) < 1e-9,
		"spent %.2f/%.2f kept %.2f/%.2f plain %.2f/%.2f" % [float(spent["land"]), float(spent["damage"]),
			float(kept_one["land"]), float(kept_one["damage"]), float(uncalled["land"]), float(uncalled["damage"])])


#The option score on a shared context and the unforced pick the ai makes.
static func _case_option_pick(res: Dictionary, marked: Dictionary) -> void:
	var marker: MercenaryData = marked["marker"]
	var dummy: MercenaryData = marked["dummy"]
	var open_state: BattleState = marked["state"]
	var fresh := CalledShotOdds.option_score(marker, dummy, "calf", open_state, 0)
	var shared := CalledShotOdds.option_score(marker, dummy, "calf", open_state, 0,
		CalledShotOdds.marked_context(marker, dummy, open_state, 0))
	TestFixtures.check(res, "an option scores the same on a shared context as on its own",
		absf(fresh - shared) < 1e-6 and CalledShotOdds.plain_score(marker, dummy, open_state, 0) > 0.0,
		"fresh %.4f shared %.4f" % [fresh, shared])
	var was_force := CalledShotSystem.force_every
	CalledShotSystem.force_every = false
	var picker := _probe("Estimator")
	var picked := _probe("Estimated")
	var pick_state := _duel(picker, picked)
	picker.current_ap = 6
	picker.excess_ap = 0
	var key := CalledShotOdds.choose(picker, picked, pick_state, 0)
	CalledShotSystem.force_every = was_force
	TestFixtures.check(res, "the unforced pick is a plain attack or an option the ai list holds",
		key == "" or CalledShotSystem.AI_OPTIONS.has(key), "picked '%s'" % key)


static func _case_facing(res: Dictionary) -> void:
	var merc := _probe("Behind")
	var target := _probe("Turned")
	var other := _probe("Ahead")
	merc.equipped_weapon = _light_melee()
	target.equipped_weapon = _light_melee()
	other.equipped_weapon = _light_melee()
	var foes: Array[MercenaryData] = [target, other]
	var state := TestFixtures.crowd(merc, foes, [Vector2i(5, 4), Vector2i(6, 4)], true)
	TestFixtures.check(res, "a target that has done nothing faces nowhere",
		not CalledShotSystem.faces_away(target, merc, state), "no facing")
	state.last_attacked[target] = other
	TestFixtures.check(res, "a target facing the one it struck turns its back on the rest",
		CalledShotSystem.faces_away(target, merc, state), "struck ahead")
	TestFixtures.place(state, other, Vector2i(3, 4))
	TestFixtures.check(res, "a target that struck past the merc still faces it",
		not CalledShotSystem.faces_away(target, merc, state), "struck behind")
	state.last_attacked.erase(target)
	state.escalation[target] = {"last_move_from": Vector3i(4, 4, 0)}
	TestFixtures.check(res, "a target with nothing struck faces the way it last moved",
		CalledShotSystem.faces_away(target, merc, state), "moved east")


static func _case_perk_rows(res: Dictionary) -> void:
	var mallet: TraitData = TestFixtures.weapon_row("Mallet|Mallet Called Shot (Atlas Vertebra)")
	var halberd: TraitData = TestFixtures.weapon_row("Halberd|Halberd Called Shot (Skull Splitter)")
	if mallet == null or halberd == null:
		TestFixtures.check(res, "the called shot perk rows load", false,
			"mallet %s halberd %s" % [str(mallet != null), str(halberd != null)])
		return
	var mallet_info := PerkValuation.parse_action(mallet)
	var mallet_parts: PackedStringArray = mallet_info["parts"]
	TestFixtures.check(res, "the Atlas Vertebra row parses as a 3 AP called shot of 6",
		str(mallet_info["effect"]) == "called_shot" and int(mallet_info["ap"]) == 3
			and int(mallet_info["effect_start"]) == 2 and int(mallet_parts[3]) == 6,
		"effect %s ap %d" % [str(mallet_info["effect"]), int(mallet_info["ap"])])
	var halberd_info := PerkValuation.parse_action(halberd)
	var halberd_parts: PackedStringArray = halberd_info["parts"]
	TestFixtures.check(res, "the Skull Splitter row parses past its EP cost to a called shot of 7",
		str(halberd_info["effect"]) == "called_shot" and int(halberd_info["ep"]) == 1
			and int(halberd_info["effect_start"]) == 4 and int(halberd_parts[5]) == 7,
		"effect %s start %d" % [str(halberd_info["effect"]), int(halberd_info["effect_start"])])
	TestFixtures.check(res, "a called shot perk is named by the trait in its parentheses",
		CalledShotSystem._perk_label(mallet) == "Atlas Vertebra"
			and CalledShotSystem._perk_label(halberd) == "Skull Splitter",
		"%s and %s" % [CalledShotSystem._perk_label(mallet), CalledShotSystem._perk_label(halberd)])


static func _case_atlas(res: Dictionary) -> void:
	var mallet := _row_or_fail(res, "Mallet|Mallet Called Shot (Atlas Vertebra)", "the Atlas Vertebra row loads")
	if mallet == null:
		return
	var merc := TestFixtures.arm(_probe("Atlas"), "Mallet", "Mallet|Mallet Called Shot (Atlas Vertebra)", true)
	var target := _probe("Necked")
	target.equipped_weapon = _light_melee()
	var state := TestFixtures.duel(merc, target)
	var info := PerkValuation.parse_action(mallet)
	TestFixtures.check(res, "Atlas Vertebra needs a neck facing away",
		not CalledShotSystem.perk_ready(merc, target, info, state), "facing unknown")
	state.escalation[target] = {"last_move_from": Vector3i(4, 4, 0)}
	TestFixtures.check(res, "Atlas Vertebra is ready against a turned back within one pace",
		CalledShotSystem.perk_ready(merc, target, info, state), "facing away")


static func _case_skull(res: Dictionary) -> void:
	var halberd := _row_or_fail(res, "Halberd|Halberd Called Shot (Skull Splitter)", "the Skull Splitter row loads")
	if halberd == null:
		return
	var merc := TestFixtures.arm(_probe("Splitter"), "Halberd", "Halberd|Halberd Called Shot (Skull Splitter)", true)
	var target := _probe("Skulled")
	target.equipped_weapon = _light_melee()
	var state := TestFixtures.duel(merc, target)
	var info := PerkValuation.parse_action(halberd)
	merc.offhand_weapon = _light_melee()
	TestFixtures.check(res, "Skull Splitter needs both hands on the halberd",
		not CalledShotSystem.perk_ready(merc, target, info, state), "offhand filled")
	merc.offhand_weapon = null
	TestFixtures.check(res, "Skull Splitter is ready in two hands within one pace",
		CalledShotSystem.perk_ready(merc, target, info, state), "two handed")
	TestFixtures.place(state, target, Vector2i(8, 4))
	TestFixtures.check(res, "Skull Splitter cannot reach past one pace",
		not CalledShotSystem.perk_ready(merc, target, info, state),
		"%d paces" % state.distance_to(merc, target))


static func _case_atlas_effects(res: Dictionary) -> void:
	var mallet := _row_or_fail(res, "Mallet|Mallet Called Shot (Atlas Vertebra)", "the Atlas Vertebra row loads for its effects")
	if mallet == null:
		return
	var merc := TestFixtures.arm(_probe("Atlas"), "Mallet", "Mallet|Mallet Called Shot (Atlas Vertebra)", true)
	merc.offhand_weapon = null
	var target := _probe("Necked")
	target.equipped_weapon = _light_melee()
	var state := TestFixtures.duel(merc, target)
	state.escalation[target] = {"last_move_from": Vector3i(4, 4, 0)}
	_drained(target, 60, 40)
	var info := PerkValuation.parse_action(mallet)
	var lines: Array[String] = _with_rolls([15, 15, 15],
		func() -> Array[String]: return CalledShotSystem.perk_called_shot(merc, mallet, target, info, state, 0))
	TestFixtures.check(res, "a called shot perk announces its call",
		TestFixtures.has_line(lines, "calls the shot: Atlas Vertebra (6)!"), "%d lines" % lines.size())
	TestFixtures.check(res, "Atlas Vertebra tops the damage up to the pain limit",
		CalledShotSystem.hp_total(target) == 20, "%d hp" % CalledShotSystem.hp_total(target))
	var frail := _probe("Frail")
	frail.equipped_weapon = _light_melee()
	var state2 := TestFixtures.duel(merc, frail)
	state2.escalation[frail] = {"last_move_from": Vector3i(4, 4, 0)}
	_drained(frail, 20, 19)
	_with_rolls([15, 15, 15],
		func() -> Array[String]: return CalledShotSystem.perk_called_shot(merc, mallet, frail, info, state2, 0))
	TestFixtures.check(res, "Atlas Vertebra debilitates a target left at one hit point",
		ConstStates.has_state(frail, "Debilitated") and CalledShotSystem.hp_total(frail) == 1,
		"%d hp" % CalledShotSystem.hp_total(frail))


static func _case_skull_effects(res: Dictionary) -> void:
	var halberd := _row_or_fail(res, "Halberd|Halberd Called Shot (Skull Splitter)",
		"the Skull Splitter row loads for its effects")
	if halberd == null:
		return
	var merc := TestFixtures.arm(_probe("Splitter"), "Halberd", "Halberd|Halberd Called Shot (Skull Splitter)", true)
	merc.offhand_weapon = null
	var target := _probe("Skulled")
	target.equipped_weapon = _light_melee()
	var state := TestFixtures.duel(merc, target)
	_drained(target, 30, 1)
	var info := PerkValuation.parse_action(halberd)
	var lines: Array[String] = _with_rolls([15, 15, 15],
		func() -> Array[String]: return CalledShotSystem.perk_called_shot(merc, halberd, target, info, state, 0))
	TestFixtures.check(res, "Skull Splitter kills a target whose pain response fired",
		target.is_dead and TestFixtures.has_line(lines, "splits the skull of"), "%d lines" % lines.size())
	var headless := _probe("Headless")
	headless.equipped_weapon = _light_melee()
	headless.stats["needs_head"] = false
	var state2 := TestFixtures.duel(merc, headless)
	_drained(headless, 30, 1)
	var lines2: Array[String] = _with_rolls([15, 15, 15],
		func() -> Array[String]: return CalledShotSystem.perk_called_shot(merc, halberd, headless, info, state2, 0))
	TestFixtures.check(res, "a creature that needs no head survives Skull Splitter",
		not headless.is_dead and TestFixtures.has_line(lines2, "survives without a head!"),
		"%d lines" % lines2.size())


static func _case_counters(res: Dictionary) -> void:
	var merc := _probe("Tally")
	var foe := _probe("Tallied")
	var state := _duel(merc, foe)
	var landed_before := CalledShotSystem.calls_landed
	var hp_before := CalledShotSystem.hp_total(foe)
	var missed := CalledShotSystem.after_hit(merc, foe, "eye", {}, hp_before, state)
	TestFixtures.check(res, "a called shot that marks nothing does nothing and is not tallied",
		TestFixtures.has_line(missed, "has no effect.") and CalledShotSystem.calls_landed == landed_before
			and not ConstStates.has_state(foe, "Blinded"), "%d lines" % missed.size())
	foe.current_hp -= 2
	var floored := CalledShotSystem.after_hit(merc, foe, "calf", {"min_1_only": true}, hp_before, state)
	TestFixtures.check(res, "a mark that is only the min 1 floor applies no state and is not tallied",
		TestFixtures.has_line(floored, "has no effect.") and CalledShotSystem.calls_landed == landed_before
			and not ConstStates.has_state(foe, "Hobbled"), "%d lines" % floored.size())
	var coreless := CalledShotSystem.after_hit(merc, foe, "ear", {"core_successes": 0}, hp_before, state)
	TestFixtures.check(res, "a called shot with no core success left applies no state and is not tallied",
		TestFixtures.has_line(coreless, "has no effect.") and CalledShotSystem.calls_landed == landed_before
			and not ConstStates.has_state(foe, "Deafened"), "%d lines" % coreless.size())
	var hit := CalledShotSystem.after_hit(merc, foe, "eye", {}, hp_before, state)
	TestFixtures.check(res, "a called shot that marks a hit point lands and is tallied",
		ConstStates.has_state(foe, "Blinded")
			and CalledShotSystem.calls_landed == landed_before + 1,
		"%d lines" % hit.size())


#A merc whose attack rolls exactly `dexterity` dice against a flat 15 threshold, luck and reroll off.
static func _probe(merc_name: String) -> MercenaryData:
	var m := TestFixtures.sheet_merc(merc_name, 0.0)
	m.stats["dexterity"] = 3
	m.stats["luck"] = 0.0
	m.stats["melee_accuracy"] = 15.0
	m.stats["ranged_accuracy"] = 15.0
	m.stats["pain_limit"] = 0
	m.stats[_CONFIG.reroll_stat] = 0.0
	m.stats[_CONFIG.base_success_chance_stat] = 0.0
	m.current_ap = 6
	m.current_ep = 8
	return m


#A target whose Defend removes exactly `reduction` every time and whose Dodge never lands a success.
static func _floor_target(merc_name: String, reduction: int) -> MercenaryData:
	var m := _probe(merc_name)
	m.stats["defend"] = 100.0
	m.stats["dodge"] = 0.0
	m.stats["defend_reduction"] = reduction
	m.stats["dodge_reduction"] = 0
	m.stats["maximum_hit_points"] = 20
	m.current_hp = 20
	m.excess_hp = 0
	return m


#A target with no excess and no EP to spend, so its defence cannot change the damage.
static func _drained(m: MercenaryData, hp: int, pain: int) -> void:
	m.current_hp = hp
	m.excess_hp = 0
	m.current_ep = 0
	m.excess_ep = 0
	m.excess_ap = 0
	m.stats["pain_limit"] = pain


#The sum of values from index start on.
static func _sum(values: Array, start: int = 0) -> float:
	var total := 0.0
	for i: int in range(start, values.size()):
		total += float(values[i])
	return total


#The weapon library row with this name, or null after a FAIL under label.
static func _row_or_fail(res: Dictionary, trait_name: String, label: String) -> TraitData:
	var row: TraitData = TestFixtures.weapon_row(trait_name)
	if row == null:
		TestFixtures.check(res, label, false, "missing")
	return row


#Calls body with critical banking on and these rolls forced, then restores banking and empties the queue.
static func _with_rolls(rolls: Array[int], body: Callable) -> Variant:
	var was_banking := CriticalSuccessSystem.banking
	CriticalSuccessSystem.banking = true
	CheckSystem.forced_rolls.assign(rolls)
	var out: Variant = body.call()
	CheckSystem.forced_rolls.clear()
	CriticalSuccessSystem.banking = was_banking
	return out


#Both mercs hold a light melee weapon on a flat field one pace apart.
static func _duel(a: MercenaryData, b: MercenaryData) -> BattleState:
	a.equipped_weapon = _light_melee()
	b.equipped_weapon = _light_melee()
	return TestFixtures.duel(a, b)


static func _light_melee() -> WeaponData:
	var w := TestFixtures.weapon("Dagger")
	w.has_light = true
	w.melee_range = 1
	w.damage_types_1 = ["Impale"] as Array[String]
	return w


static func _ranged() -> WeaponData:
	var w := TestFixtures.weapon("Pistol")
	w.has_light = true
	w.is_ranged = true
	w.misfire = 2
	w.damage_types_1 = ["Impale"] as Array[String]
	return w
