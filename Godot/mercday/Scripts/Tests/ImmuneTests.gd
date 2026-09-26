class_name ImmuneTests

#Deterministic immunity cases. Run: godot --headless --path . -- --immune-tests
#No randomness: hand-built mercs and positions; each branch is asserted against the expected refusal or knowledge.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_tokens(res)
	_case_cascade(res)
	_case_battle(res)
	return TestFixtures.summarize(res, "IMMUNE")


static func _merc(name: String, tokens: Array[String], speed: float) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.stats = {"size": 1, "maximum_hit_points": 20, "maximum_endurance_points": 5, "speed": speed,
		"dexterity": 2, "vigor": 2, "pain_limit": 0}
	m.passive_effects.assign(tokens)
	return m


static func _ranged() -> WeaponData:
	var w := WeaponData.new()
	w.is_ranged = true
	return w


static func _case_tokens(res: Dictionary) -> void:
	TestFixtures.check(res, "token deposed allowed", ConstStates.immune_token_allowed("immune:deposed", "test"), "immune:deposed")
	TestFixtures.check(res, "token fire allowed", ConstStates.immune_token_allowed("immune:fire", "test"), "immune:fire")
	TestFixtures.check(res, "token dying refused", not ConstStates.immune_token_allowed("immune:dying", "test"), "immune:dying")
	TestFixtures.check(res, "token climbing refused", not ConstStates.immune_token_allowed("immune:climbing", "test"), "immune:climbing")
	var forced: Array[String] = ["immune:dying"]
	var m := _merc("Never", forced, 1.0)
	TestFixtures.check(res, "dying never immune", not ConstStates.is_immune(m, ConstStates.DYING), "is_immune false with a forced token")
	var applied := ConstStates.apply_state(m, ConstStates.DYING)
	TestFixtures.check(res, "dying applies", applied and ConstStates.has_state(m, ConstStates.DYING), "apply_state Dying true")


static func _case_cascade(res: Dictionary) -> void:
	var tokens: Array[String] = ["immune:deposed"]
	var m := _merc("Dena", tokens, 1.0)
	var direct := ConstStates.apply_state(m, ConstStates.DEPOSED)
	TestFixtures.check(res, "direct refused", not direct and not ConstStates.has_state(m, ConstStates.DEPOSED), "apply_state Deposed false")
	var root_ok := ConstStates.apply_state(m, ConstStates.UNCONSCIOUS)
	TestFixtures.check(res, "cascade applies", root_ok and ConstStates.has_state(m, ConstStates.DEPOSED), "Unconscious forces Deposed on an immune merc")
	var removed: bool = ConstStates.remove_state(m, ConstStates.UNCONSCIOUS)["removed"]
	TestFixtures.check(res, "cascade ends", removed and not ConstStates.has_state(m, ConstStates.DEPOSED), "Deposed ends with Unconscious")
	TestFixtures.check(res, "direct still refused", not ConstStates.apply_state(m, ConstStates.DEPOSED), "apply_state Deposed false after the cascade")
	var plain: Array[String] = []
	var c := _merc("Cade", plain, 1.0)
	ConstStates.apply_state(c, ConstStates.DYING)
	var un: Array[Dictionary] = StateSources.state_sources(c, ConstStates.UNCONSCIOUS)
	TestFixtures.check(res, "cascade names its root",
		un.size() == 1 and str(un[0].get("kind", "")) == "state"
		and str(un[0].get("name", "")) == ConstStates.DYING, "Unconscious sources %s" % str(un))
	var dep: Array[Dictionary] = StateSources.state_sources(c, ConstStates.DEPOSED)
	TestFixtures.check(res, "second rank names its own root",
		dep.size() == 1 and str(dep[0].get("kind", "")) == "state"
		and str(dep[0].get("name", "")) == ConstStates.UNCONSCIOUS, "Deposed sources %s" % str(dep))
	ConstStates.apply_state(c, ConstStates.DEPOSED)
	dep = StateSources.state_sources(c, ConstStates.DEPOSED)
	TestFixtures.check(res, "direct apply adds a second source",
		dep.size() == 2 and str(dep[1].get("kind", "")) == "engine", "Deposed sources %s" % str(dep))
	ConstStates.remove_state(c, ConstStates.DYING)
	dep = StateSources.state_sources(c, ConstStates.DEPOSED)
	TestFixtures.check(res, "kept state keeps only its own source",
		ConstStates.has_state(c, ConstStates.DEPOSED) and dep.size() == 1
		and str(dep[0].get("kind", "")) == "engine",
		"held %s sources %s" % [str(ConstStates.has_state(c, ConstStates.DEPOSED)), str(dep)])


static func _case_battle(res: Dictionary) -> void:
	var a_tokens: Array[String] = ["immune:deposed", "immune:fire", "immune:slowed", "immune:threatened", "immune:flanked"]
	var a1 := _merc("Ada", a_tokens, 5.0)
	var a2_tokens: Array[String] = ["protected:fire"]
	var a2 := _merc("Ana", a2_tokens, 4.0)
	var none: Array[String] = []
	var b1 := _merc("Bo", none, 3.0)
	var b2 := _merc("Bea", none, 2.0)
	var b3 := _merc("Ben", none, 1.0)
	var team_a: Array[MercenaryData] = [a1, a2]
	var team_b: Array[MercenaryData] = [b1, b2, b3]
	var state := BattleState.create(team_a, team_b, null)
	b3.is_dead = true
	b3.current_hp = 0
	var field := TestFixtures.exterior_field()
	state.battlefield = field
	TestFixtures.place(state, a1, Vector2i(5, 5))
	TestFixtures.place(state, a2, Vector2i(3, 5))
	TestFixtures.place(state, b1, Vector2i(4, 5))
	TestFixtures.place(state, b2, Vector2i(10, 10))
	TestFixtures.place(state, b3, Vector2i(20, 20))

	TestFixtures.check(res, "ally seeded", BattleState.knows(a2, a1, "immune:deposed") and BattleState.knows(a2, a1, "immune:fire"), "a2 knows a1 at create")
	TestFixtures.check(res, "self known", BattleState.knows(a1, a1, "immune:deposed"), "a merc knows its own tokens")
	TestFixtures.check(res, "enemy unknown", not BattleState.knows(b1, a1, "immune:deposed") and not BattleState.knows(b1, a1, "immune:fire"), "b1 knows nothing of a1 at create")

	var before := WeaponEvaluator.score_type_vs_enemy(["Fire"], a1, b2)
	var lines := CombatApplicator.apply_damage(b1, a1, 4, "Fire", state)
	TestFixtures.check(res, "fire immune", TestFixtures.has_line(lines, "is immune to Fire") and a1.current_hp == 20, "no Fire damage, hp %d" % a1.current_hp)
	TestFixtures.check(res, "fire learned", BattleState.knows(b1, a1, "immune:fire") and BattleState.knows(b2, a1, "immune:fire"), "b1 and b2 know immune:fire")
	TestFixtures.check(res, "dead ally skipped", not BattleState.knows(b3, a1, "immune:fire"), "b3 (dead) learned nothing")
	var after := WeaponEvaluator.score_type_vs_enemy(["Fire"], a1, b2)
	TestFixtures.check(res, "type score gated", before > -1.0 and is_equal_approx(after, -1.0), "score %.2f before, %.2f after" % [before, after])
	lines = CombatApplicator.apply_damage(b1, a2, 4, "Fire", state)
	TestFixtures.check(res, "protected learned", BattleState.knows(b1, a2, "protected:fire") and a2.current_hp < 20, "b1 knows protected:fire, hp %d" % a2.current_hp)

	TestFixtures.check(res, "perk alt unknown", not CombatApplicator.known_immune(b1, a1, ConstStates.SLOWED, "slowed"), "an unlearned immunity does not skip the alternative")
	lines = StateInfliction.inflict(a1, ConstStates.SLOWED, "Resist:Vigor:2", "1 Minute", "Resist:Vigor:2:End Turn", b2, state)
	TestFixtures.check(res, "inflict immune", TestFixtures.has_line(lines, "is immune to Slowed") and not ConstStates.has_state(a1, ConstStates.SLOWED), "inflict refused")
	TestFixtures.check(res, "perk alt known", CombatApplicator.known_immune(b1, a1, ConstStates.SLOWED, "slowed"), "b1 learned from the attempt of b2")
	state.learn_state_immunity(b1, a1, ConstStates.TERRIFIED)
	TestFixtures.check(res, "no false learning", not BattleState.knows(b1, a1, "immune:terrified"), "a merc without the immunity teaches nothing")

	lines = ShoveResolver.forcible_move(b1, a1, 1, state)
	var pushed := state.get_position(a1) == Vector2i(6, 5)
	TestFixtures.check(res, "shove immune", pushed and TestFixtures.has_line(lines, "is immune to Deposed") and not ConstStates.has_state(a1, ConstStates.DEPOSED), "pushed to (6,5), no Deposed")
	TestFixtures.check(res, "shove learned", BattleState.knows(b1, a1, "immune:deposed") and BattleState.knows(b2, a1, "immune:deposed"), "b1 and b2 know immune:deposed")
	TestFixtures.place(state, a1, Vector2i(9, 10))
	lines = ShoveResolver.forcible_move(a1, b2, 1, state)
	TestFixtures.check(res, "shove control", TestFixtures.has_line(lines, "Deposed") and ConstStates.has_state(b2, ConstStates.DEPOSED), "b2 falls Deposed")

	lines = CombatApplicator.resolve_fall(a1, 3, state)
	TestFixtures.check(res, "fall immune", TestFixtures.has_line(lines, "immune to Deposed") and not ConstStates.has_state(a1, ConstStates.DEPOSED) and a1.current_hp < 20, "no Deposed, hp %d" % a1.current_hp)
	lines = CombatApplicator.resolve_fall(b1, 3, state)
	TestFixtures.check(res, "fall control", ConstStates.has_state(b1, ConstStates.DEPOSED), "b1 falls Deposed, hp %d" % b1.current_hp)

	a1.equipped_weapon = _ranged()
	a1.weapon_drawn = true
	b1.equipped_weapon = _ranged()
	b1.weapon_drawn = true
	TestFixtures.place(state, a1, Vector2i(5, 5))
	TestFixtures.place(state, a2, Vector2i(3, 5))
	TestFixtures.place(state, b1, Vector2i(4, 5))
	TestFixtures.place(state, b2, Vector2i(6, 5))
	BattleStateUpdater.update_auto_states(a1, state)
	TestFixtures.check(res, "threatened immune", not ConstStates.has_state(a1, ConstStates.THREATENED), "ranged a1 beside b1 is not Threatened")
	TestFixtures.check(res, "flanked immune", not ConstStates.has_state(a1, ConstStates.FLANKED), "a1 between b1 and b2 is not Flanked")
	BattleStateUpdater.update_auto_states(b1, state)
	TestFixtures.check(res, "threatened control", ConstStates.has_state(b1, ConstStates.THREATENED), "ranged b1 beside a1 is Threatened")
	TestFixtures.check(res, "flanked control", ConstStates.has_state(b1, ConstStates.FLANKED), "b1 between a2 and a1 is Flanked")
