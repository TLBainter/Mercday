class_name RelationshipTests

#Deterministic relationship cases. Run: godot --headless --path . -- --relationship-tests
#No unseeded randomness: hand-built mercs, hand-placed positions, forced check rolls.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_seed(res)
	_case_clamp(res)
	_case_directional(res)
	_case_untracked(res)
	_case_best_ally(res)
	_case_proximity(res)
	_case_aid(res)
	_case_wile_roll(res)
	_case_forget(res)
	return TestFixtures.summarize(res, "RELATIONSHIP")


static func _merc(name: String, wile: int) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.merc_uid = CampaignKnowledge.next_uid()
	m.stats = {"size": 1, "maximum_hit_points": 20, "maximum_endurance_points": 5, "speed": 4.0,
		"dexterity": 2, "vigor": 2, "cognition": 2, "wile": wile, "luck": 0, "pain_limit": 0}
	BattleState.restore_pools(m, false)
	return m


#Queues count forced rolls; the default failures keep a case that is not testing the bond check from drifting.
static func _force_fail(count: int = 400, value: int = 100) -> void:
	for i: int in range(count):
		CheckSystem.forced_rolls.append(value)


#Two mercs that spend three turns at these cells with a far foe, then close a contract with forced failures.
static func _proximity_run(name_a: String, name_b: String, pos_a: Vector2i, pos_b: Vector2i) -> Dictionary:
	var a := _merc(name_a, 4)
	var b := _merc(name_b, 4)
	var foe := _merc("Foe", 4)
	foe.merc_uid = 0
	var team_a: Array[MercenaryData] = [a, b]
	var team_b: Array[MercenaryData] = [foe]
	var state := BattleState.create(team_a, team_b, TestFixtures.exterior_field())
	TestFixtures.place(state, a, pos_a)
	TestFixtures.place(state, b, pos_b)
	TestFixtures.place(state, foe, Vector2i(20, 20))
	for i: int in range(3):
		state.end_of_turn(a)
		state.end_of_turn(b)
	_force_fail()
	var lines: Array[String] = RelationshipSystem.end_contract(TestFixtures.run_for(team_a))
	return {"a": a, "b": b, "lines": lines}


static func _case_seed(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 5)
	var b := _merc("Bo", 8)
	TestFixtures.check(res, "seed a to b", RelationshipSystem.value(a, b) == 6,
		"floor((5+8)/2) got %d" % RelationshipSystem.value(a, b))
	TestFixtures.check(res, "seed b to a", RelationshipSystem.value(b, a) == 6, "both directions equal at start")
	var c := _merc("Cai", 3)
	var d := _merc("Dee", 4)
	TestFixtures.check(res, "seed odd pair", RelationshipSystem.value(c, d) == 3,
		"floor((3+4)/2) got %d" % RelationshipSystem.value(c, d))
	RelationshipSystem.adjust(a, b, 2)
	RelationshipSystem.seed_pair(a, b)
	TestFixtures.check(res, "seed does not reset", RelationshipSystem.value(a, b) == 8,
		"second seed left 8, got %d" % RelationshipSystem.value(a, b))


static func _case_clamp(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 6)
	var b := _merc("Bo", 6)
	RelationshipSystem.adjust(a, b, 20)
	TestFixtures.check(res, "clamp high", RelationshipSystem.value(a, b) == 10,
		"capped at 10, got %d" % RelationshipSystem.value(a, b))
	RelationshipSystem.adjust(a, b, -30)
	TestFixtures.check(res, "clamp low", RelationshipSystem.value(a, b) == 0,
		"floored at 0, got %d" % RelationshipSystem.value(a, b))


static func _case_directional(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 4)
	var b := _merc("Bo", 4)
	RelationshipSystem.adjust(a, b, 3)
	TestFixtures.check(res, "direction moved", RelationshipSystem.value(a, b) == 7,
		"a to b 7, got %d" % RelationshipSystem.value(a, b))
	TestFixtures.check(res, "other direction still", RelationshipSystem.value(b, a) == 4,
		"b to a 4, got %d" % RelationshipSystem.value(b, a))
	TestFixtures.check(res, "mutual average", RelationshipSystem.mutual_value(a, b) == 5,
		"floor((7+4)/2) got %d" % RelationshipSystem.mutual_value(a, b))


static func _case_untracked(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 4)
	var ghost := MercenaryData.new()
	ghost.merc_name = "Ghost"
	ghost.stats = {"wile": 4}
	TestFixtures.check(res, "untracked value", RelationshipSystem.value(a, ghost) == -1, "no campaign uid gives -1")
	RelationshipSystem.adjust(a, ghost, 5)
	TestFixtures.check(res, "untracked not stored", CampaignKnowledge.relation_count() == 0,
		"store size %d" % CampaignKnowledge.relation_count())
	TestFixtures.check(res, "self value", RelationshipSystem.value(a, a) == -1, "a merc holds no value toward itself")


static func _case_best_ally(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 4)
	var b := _merc("Bo", 4)
	var c := _merc("Cai", 4)
	RelationshipSystem.adjust(a, b, 2)
	RelationshipSystem.adjust(a, c, 5)
	var pool: Array[MercenaryData] = [a, b, c]
	var best: MercenaryData = RelationshipSystem.best_ally(a, pool)
	TestFixtures.check(res, "best ally picked", best == c,
		"expected Cai, got %s" % ("null" if best == null else best.merc_name))
	var solo: Array[MercenaryData] = [a]
	TestFixtures.check(res, "best ally none", RelationshipSystem.best_ally(a, solo) == null, "no candidate but self")


static func _case_proximity(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var near: Dictionary = _proximity_run("Ada", "Bo", Vector2i(2, 2), Vector2i(4, 2))
	var a: MercenaryData = near["a"]
	var b: MercenaryData = near["b"]
	var lines: Array[String] = near["lines"]
	TestFixtures.check(res, "near tally raises", RelationshipSystem.value(a, b) == 5,
		"seed 4 plus 1, got %d" % RelationshipSystem.value(a, b))
	TestFixtures.check(res, "near tally is mutual", RelationshipSystem.value(b, a) == 5, "both directions moved")
	TestFixtures.check(res, "near line emitted", lines.size() >= 1, "%d line(s)" % lines.size())
	TestFixtures.reset_campaign()
	var far: Dictionary = _proximity_run("Cai", "Dee", Vector2i(1, 1), Vector2i(15, 1))
	var c: MercenaryData = far["a"]
	var d: MercenaryData = far["b"]
	TestFixtures.check(res, "far tally holds", RelationshipSystem.value(c, d) == 4,
		"seed 4 unchanged, got %d" % RelationshipSystem.value(c, d))


static func _case_aid(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 4)
	var b := _merc("Bo", 4)
	RelationshipSystem.record_aid(a, b)
	var team: Array[MercenaryData] = [a, b]
	_force_fail()
	var lines: Array[String] = RelationshipSystem.end_contract(TestFixtures.run_for(team))
	TestFixtures.check(res, "aid raises helper", RelationshipSystem.value(a, b) == 5,
		"seed 4 plus 1, got %d" % RelationshipSystem.value(a, b))
	TestFixtures.check(res, "aid raises helped", RelationshipSystem.value(b, a) == 5, "both sides gain")
	TestFixtures.check(res, "aid line emitted", lines.size() >= 1, "%d line(s)" % lines.size())
	TestFixtures.reset_campaign()
	var c := _merc("Cai", 4)
	var d := _merc("Dee", 4)
	var team2: Array[MercenaryData] = [c, d]
	_force_fail()
	var _none: Array[String] = RelationshipSystem.end_contract(TestFixtures.run_for(team2))
	TestFixtures.check(res, "no aid no change", RelationshipSystem.value(c, d) == 4,
		"seed 4 unchanged, got %d" % RelationshipSystem.value(c, d))


static func _case_wile_roll(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 1)
	var b := _merc("Bo", 1)
	var c := _merc("Cai", 1)
	var team: Array[MercenaryData] = [a, b, c]
	_force_fail(24, 1)
	var _lines: Array[String] = RelationshipSystem.end_contract(TestFixtures.run_for(team))
	CheckSystem.forced_rolls.clear()
	TestFixtures.check(res, "wile pass raises toward roller", RelationshipSystem.value(a, b) == 2,
		"seed 1 plus 1, got %d" % RelationshipSystem.value(a, b))
	TestFixtures.check(res, "wile pass covers every pair", RelationshipSystem.value(b, c) == 2, "every survivor pair moved")
	TestFixtures.reset_campaign()
	var d := _merc("Dee", 1)
	var e := _merc("Eli", 1)
	var team2: Array[MercenaryData] = [d, e]
	_force_fail(24)
	var _lines2: Array[String] = RelationshipSystem.end_contract(TestFixtures.run_for(team2))
	CheckSystem.forced_rolls.clear()
	TestFixtures.check(res, "wile fail holds", RelationshipSystem.value(d, e) == 1,
		"seed 1 unchanged, got %d" % RelationshipSystem.value(d, e))


static func _case_forget(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada", 4)
	var b := _merc("Bo", 4)
	var _v: int = RelationshipSystem.value(a, b)
	TestFixtures.check(res, "store filled", CampaignKnowledge.relation_count() == 2,
		"two directions, got %d" % CampaignKnowledge.relation_count())
	CampaignKnowledge.forget(a.merc_uid)
	TestFixtures.check(res, "forget clears both ways", CampaignKnowledge.relation_count() == 0,
		"store size %d" % CampaignKnowledge.relation_count())
