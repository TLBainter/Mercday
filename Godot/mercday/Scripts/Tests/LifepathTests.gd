class_name LifepathTests

#Deterministic lifepath progression cases. Run: godot --headless --path . -- --lifepath-tests
#Every roll is forced by setting the chance to 100, so no case depends on unseeded randomness.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_chance(res)
	_case_tally(res)
	_case_requirements(res)
	_case_pool(res)
	_case_rarity(res)
	_case_level_up(res)
	_case_stat_delta(res)
	_case_capacity(res)
	_case_forced_replace(res)
	_case_buddy(res)
	_case_beau(res)
	_case_ops(res)
	_case_stat_subjects(res)
	_case_knowledge(res)
	_case_lifepath_subject(res)
	_case_weapon_perks(res)
	_case_location(res)
	_case_damage_subjects(res)
	_case_check_kinds(res)
	_case_contract_check_kinds(res)
	_case_targets(res)
	_case_stat_bonus(res)
	_case_placeholder_trait(res)
	_case_payoff_placeholder(res)
	_case_apply_effect(res)
	_case_location_condition(res)
	_audit()
	return TestFixtures.summarize(res, "LIFEPATH")


static func _merc(name: String) -> MercenaryData:
	return TestFixtures.level_merc(name)


#A stand-in event registered in the Experienced pool so grant and force can find it by name.
static func _fake(event_name: String, perk: String) -> LifepathData:
	var lp := LifepathData.new()
	lp.event_type = "Experienced"
	lp.event_name = event_name
	lp.perks = [perk] as Array[String]
	if not DataManager.lifepaths_by_category.has("Experienced"):
		DataManager.lifepaths_by_category["Experienced"] = []
	(DataManager.lifepaths_by_category["Experienced"] as Array).append(lp)
	return lp


static func _unregister(lp: LifepathData) -> void:
	(DataManager.lifepaths_by_category["Experienced"] as Array).erase(lp)


#Sets the roll step high enough that chance_for returns 100, so a level up always draws.
static func _force_draw(merc: MercenaryData) -> void:
	merc.lifepath_roll_step = 6


static func _case_chance(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var m := _merc("Ada")
	m.stats["luck"] = 0
	m.lifepath_roll_step = 0
	TestFixtures.check(res, "chance base", LifepathProgression.chance_for(m) == 5,
		"5 percent at step 0, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 1
	TestFixtures.check(res, "chance doubles", LifepathProgression.chance_for(m) == 10,
		"10 percent at step 1, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 3
	TestFixtures.check(res, "chance doubles again", LifepathProgression.chance_for(m) == 40,
		"40 percent at step 3, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 9
	TestFixtures.check(res, "chance caps", LifepathProgression.chance_for(m) == 100,
		"capped at 100, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 0
	m.stats["luck"] = 7
	TestFixtures.check(res, "luck added after", LifepathProgression.chance_for(m) == 12,
		"5 plus 7 luck, got %d" % LifepathProgression.chance_for(m))


static func _case_tally(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var ghost := MercenaryData.new()
	ghost.merc_name = "Ghost"
	LifepathTally.record_check(a, "Vigor", 2, true)
	LifepathTally.record_check(a, "Vigor", 1, true)
	TestFixtures.check(res, "best success kept", LifepathTally.success_count(a, "vigor") == 2,
		"best of 2 and 1, got %d" % LifepathTally.success_count(a, "vigor"))
	LifepathTally.record_check(a, "Wile", 0, false)
	TestFixtures.check(res, "failure counted", LifepathTally.failure_count(a) == 1,
		"one failure, got %d" % LifepathTally.failure_count(a))
	TestFixtures.check(res, "failed stat named", LifepathTally.failed_stat(a, "wile"), "wile is the failed stat")
	LifepathTally.record_cheat_death(a, 0, false)
	TestFixtures.check(res, "death test is not a failure", LifepathTally.failure_count(a) == 1,
		"still one failure, got %d" % LifepathTally.failure_count(a))
	LifepathTally.record_cheat_death(a, 1, true)
	TestFixtures.check(res, "death test success recorded", LifepathTally.succeeded(a, "cheat_death"),
		"cheat death shows as passed")
	LifepathTally.record_damage(a, 5, 4, "Ranged")
	TestFixtures.check(res, "damage at tolerance", LifepathTally.damage_met_tolerance(a, "ranged"),
		"5 damage meets tolerance 4")
	LifepathTally.record_damage(a, 2, 4, "Melee")
	TestFixtures.check(res, "damage under tolerance", not LifepathTally.damage_met_tolerance(a, "melee"),
		"2 damage misses tolerance 4")
	TestFixtures.check(res, "damage any type", LifepathTally.damage_met_tolerance(a, ""), "any weapon class matched")
	LifepathTally.record_check(ghost, "Vigor", 3, true)
	TestFixtures.check(res, "no uid not tallied", LifepathTally.success_count(ghost, "vigor") == 0,
		"a merc with no campaign uid is skipped")


static func _case_requirements(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var contract_run := TestFixtures.run_for(team)
	var dead := _merc("Cai")
	var buddy: LifepathData = TestFixtures.lifepath("Buddy")
	TestFixtures.check(res, "buddy row found", buddy != null, "Lifepaths.tsv holds Buddy")
	if buddy != null:
		RelationshipSystem.set_value(a, b, 4)
		TestFixtures.check(res, "relationship below bar", not LifepathRequirements.allows(a, buddy, contract_run),
			"4 is under the 5 Buddy asks for")
		RelationshipSystem.set_value(a, b, 5)
		TestFixtures.check(res, "relationship meets bar", LifepathRequirements.allows(a, buddy, contract_run),
			"5 meets the 5 Buddy asks for")
	var trauma: LifepathData = TestFixtures.lifepath("Death Trauma")
	TestFixtures.check(res, "death trauma row found", trauma != null, "Lifepaths.tsv holds Death Trauma")
	if trauma != null:
		TestFixtures.check(res, "no casualty no trauma", not LifepathRequirements.allows(a, trauma, contract_run),
			"nobody died")
		contract_run.casualties.append(dead)
		TestFixtures.check(res, "casualty allows trauma", LifepathRequirements.allows(a, trauma, contract_run),
			"one casualty meets the bar")
	var survivor: LifepathData = TestFixtures.lifepath("Miraculous Survivor")
	TestFixtures.check(res, "survivor row found", survivor != null, "Lifepaths.tsv holds Miraculous Survivor")
	if survivor != null:
		TestFixtures.check(res, "no death test no survivor", not LifepathRequirements.allows(a, survivor, contract_run),
			"no cheat death success recorded")
		LifepathTally.record_cheat_death(a, 1, true)
		TestFixtures.check(res, "death test allows survivor", LifepathRequirements.allows(a, survivor, contract_run),
			"a passed cheat death meets the bar")
	var unsupported: LifepathData = TestFixtures.lifepath("Master of Disguise")
	if unsupported != null:
		TestFixtures.check(res, "unknown subject unsupported", not LifepathRequirements.is_supported(unsupported),
			"Has Tool is not a subject this code answers")


static func _case_pool(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var contract_run := TestFixtures.run_for(team)
	RelationshipSystem.set_value(a, b, 0)
	RelationshipSystem.set_value(b, a, 0)
	var _q: Array[String] = LifepathProgression.refresh_pool(a, contract_run)
	TestFixtures.check(res, "pool skips unmet", not a.lifepath_pool.has("Buddy"), "relationship 0 keeps Buddy out")
	RelationshipSystem.set_value(a, b, 7)
	var lines: Array[String] = LifepathProgression.refresh_pool(a, contract_run)
	TestFixtures.check(res, "pool takes met", a.lifepath_pool.has("Buddy"), "relationship 7 qualifies for Buddy")
	TestFixtures.check(res, "pool line emitted", lines.size() >= 1, "%d line(s)" % lines.size())
	var before: int = a.lifepath_pool.size()
	var _again: Array[String] = LifepathProgression.refresh_pool(a, contract_run)
	TestFixtures.check(res, "pool does not duplicate", a.lifepath_pool.size() == before,
		"size held at %d" % a.lifepath_pool.size())


static func _case_rarity(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	seed(4242)
	var pool: Array[String] = ["Assassin of Kings", "Bar Fight"] as Array[String]
	var common := 0
	var very_rare := 0
	for i: int in range(200):
		var pick: String = LifepathProgression.draw(pool)
		if pick == "Bar Fight":
			common += 1
		elif pick == "Assassin of Kings":
			very_rare += 1
	randomize()
	TestFixtures.check(res, "draw names pool entries", common + very_rare == 200,
		"%d of 200 draws named a pool entry" % (common + very_rare))
	TestFixtures.check(res, "draw favours common", common > very_rare * 2,
		"Common 50 vs Very Rare 9 weight: Bar Fight %d, Assassin of Kings %d" % [common, very_rare])
	TestFixtures.check(res, "draw reaches very rare", very_rare > 0,
		"Assassin of Kings drawn %d time(s)" % very_rare)
	TestFixtures.check(res, "draw pool unchanged", pool.size() == 2, "%d name(s) left" % pool.size())
	TestFixtures.check(res, "empty draw", LifepathProgression.draw([] as Array[String]) == "",
		"an empty pool draws nothing")
	TestFixtures.check(res, "unknown name draws nothing",
		LifepathProgression.draw(["No Such Event"] as Array[String]) == "",
		"a name with no Lifepaths.tsv row is skipped")


static func _case_level_up(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	a.lifepath_pool = ["Death Trauma"] as Array[String]
	_force_draw(a)
	var lines: Array[String] = LifepathProgression.on_level_up(a)
	TestFixtures.check(res, "level up grants", LifepathProgression.has_event(a, "Death Trauma"),
		"a 100 percent roll draws from the pool")
	TestFixtures.check(res, "step resets", a.lifepath_roll_step == 0,
		"step back to 0, got %d" % a.lifepath_roll_step)
	TestFixtures.check(res, "drawn name leaves pool", not a.lifepath_pool.has("Death Trauma"),
		"a taken event is no longer a candidate")
	TestFixtures.check(res, "level up line emitted", lines.size() >= 2, "%d line(s)" % lines.size())
	var b := _merc("Bo")
	_force_draw(b)
	var empty: Array[String] = LifepathProgression.on_level_up(b)
	TestFixtures.check(res, "empty pool gains nothing", b.lifepaths.is_empty(), "no event to draw")
	TestFixtures.check(res, "empty pool still steps", b.lifepath_roll_step == 7,
		"step advanced to 7, got %d" % b.lifepath_roll_step)
	TestFixtures.check(res, "empty pool silent", empty.is_empty(), "%d line(s)" % empty.size())


static func _case_stat_delta(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var boost: LifepathData = _fake("TEST Boost", "Another Miracle")
	var before: int = int(a.stats.get("cheat_death", 0))
	var _g: Array[String] = LifepathProgression.grant(a, "TEST Boost")
	var after: int = int(a.stats.get("cheat_death", 0))
	TestFixtures.check(res, "granted trait moves the stat", after == before + 5,
		"cheat death %d to %d" % [before, after])
	TestFixtures.check(res, "delta recorded", a.lifepath_stat_deltas.has("TEST Boost"),
		"the event stored what it moved")
	for i: int in range(LifepathProgression.MAX_EVENTS - a.lifepaths.size()):
		a.lifepaths.append(TestFixtures.lifepath("Death Trauma"))
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	TestFixtures.check(res, "displacement undoes the stat", int(a.stats.get("cheat_death", 0)) == before,
		"cheat death back to %d, got %d" % [before, int(a.stats.get("cheat_death", 0))])
	TestFixtures.check(res, "delta cleared", not a.lifepath_stat_deltas.has("TEST Boost"),
		"the record went with the event")
	_unregister(boost)


static func _case_capacity(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var filler: LifepathData = TestFixtures.lifepath("Death Trauma")
	for i: int in range(LifepathProgression.MAX_EVENTS):
		a.lifepaths.append(filler)
	var spare: LifepathData = _fake("TEST Spare", "Another Miracle")
	var blocked: Array[String] = LifepathProgression.grant(a, "TEST Spare")
	TestFixtures.check(res, "full list blocks a gain", blocked.is_empty(), "%d line(s)" % blocked.size())
	TestFixtures.check(res, "full list unchanged", a.lifepaths.size() == LifepathProgression.MAX_EVENTS,
		"still %d events" % a.lifepaths.size())
	var forced: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	TestFixtures.check(res, "forced displaces", LifepathProgression.has_event(a, "Buddy's Passing"),
		"a forced event makes its own room")
	TestFixtures.check(res, "size held at the cap", a.lifepaths.size() == LifepathProgression.MAX_EVENTS,
		"still %d events, got %d" % [LifepathProgression.MAX_EVENTS, a.lifepaths.size()])
	TestFixtures.check(res, "displacement reported", forced.size() >= 2, "%d line(s)" % forced.size())
	_unregister(spare)


static func _case_forced_replace(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	LifepathProgression.begin_contract(TestFixtures.run_for(team))
	RelationshipSystem.set_value(a, b, 8)
	var _g: Array[String] = LifepathProgression.grant(a, "Buddy")
	TestFixtures.check(res, "buddy granted", LifepathProgression.has_event(a, "Buddy"), "Ada holds Buddy")
	var size_before: int = a.lifepaths.size()
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	TestFixtures.check(res, "passing replaces buddy", not LifepathProgression.has_event(a, "Buddy"),
		"Buddy gave way to Buddy's Passing")
	TestFixtures.check(res, "passing held", LifepathProgression.has_event(a, "Buddy's Passing"),
		"the forced event is on the list")
	TestFixtures.check(res, "replacement is one for one", a.lifepaths.size() == size_before,
		"size held at %d, got %d" % [size_before, a.lifepaths.size()])


static func _case_buddy(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var c := _merc("Cai")
	var team: Array[MercenaryData] = [a, b, c]
	LifepathProgression.begin_contract(TestFixtures.run_for(team))
	RelationshipSystem.set_value(a, b, 3)
	RelationshipSystem.set_value(a, c, 9)
	var lines: Array[String] = LifepathProgression.grant(a, "Buddy")
	TestFixtures.check(res, "buddy points at the closest", a.buddy_uid == c.merc_uid,
		"Ada paired with Cai, not Bo")
	TestFixtures.check(res, "buddy is returned", LifepathProgression.has_event(c, "Buddy"),
		"Cai took Buddy back")
	TestFixtures.check(res, "buddy points both ways", c.buddy_uid == a.merc_uid, "Cai points at Ada")
	TestFixtures.check(res, "buddy lines emitted", lines.size() >= 3, "%d line(s)" % lines.size())
	var contract_run := TestFixtures.run_for(team)
	contract_run.team.erase(c)
	contract_run.casualties.append(c)
	var mourn: Array[String] = LifepathProgression.end_contract(contract_run)
	TestFixtures.check(res, "dead buddy forces passing", LifepathProgression.has_event(a, "Buddy's Passing"),
		"losing a buddy replaces the event")
	TestFixtures.check(res, "passing clears the pointer", a.buddy_uid == 0,
		"buddy uid cleared, got %d" % a.buddy_uid)
	TestFixtures.check(res, "mourning reported", mourn.size() >= 1, "%d line(s)" % mourn.size())


static func _case_beau(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	LifepathProgression.begin_contract(TestFixtures.run_for(team))
	RelationshipSystem.set_value(a, b, 6)
	var lines: Array[String] = LifepathProgression.grant(a, "In Love")
	TestFixtures.check(res, "in love points at a beau", a.beau_uid == b.merc_uid, "Ada pines for Bo")
	TestFixtures.check(res, "in love is one sided", not LifepathProgression.has_event(b, "In Love"),
		"Bo has not decided yet")
	TestFixtures.check(res, "in love pointer one way", b.beau_uid == 0,
		"Bo points at nobody, got %d" % b.beau_uid)
	TestFixtures.check(res, "in love lines emitted", lines.size() >= 2, "%d line(s)" % lines.size())
	b.stats["luck"] = 100
	RelationshipSystem.set_value(a, b, 10)
	RelationshipSystem.set_value(b, a, 10)
	var _settled: Array[String] = LifepathProgression.end_contract(TestFixtures.run_for(team))
	TestFixtures.check(res, "a sure beau answers", LifepathProgression.has_event(b, "In Love"),
		"a full relationship window returns the feeling")
	TestFixtures.reset_campaign()
	var c := _merc("Cai")
	var d := _merc("Dee")
	var team2: Array[MercenaryData] = [c, d]
	LifepathProgression.begin_contract(TestFixtures.run_for(team2))
	RelationshipSystem.set_value(c, d, 6)
	var _g2: Array[String] = LifepathProgression.grant(c, "In Love")
	d.stats["luck"] = 100
	RelationshipSystem.set_value(c, d, 0)
	RelationshipSystem.set_value(d, c, 0)
	var _turned: Array[String] = LifepathProgression.end_contract(TestFixtures.run_for(team2))
	TestFixtures.check(res, "a closed beau refuses", LifepathProgression.has_event(c, "Forever Yearning"),
		"an empty relationship window turns the merc down")
	TestFixtures.check(res, "refusal replaces in love", not LifepathProgression.has_event(c, "In Love"),
		"Forever Yearning stands in for In Love")


static func _case_ops(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var contract_run := TestFixtures.run_for(team)
	TestFixtures.check(res, "is zero with no dead", TestFixtures.ok(a, contract_run, "Dead Mercs", "IS", "0"), "nobody died")
	var fallen := TestFixtures.run_for(team)
	fallen.casualties.append(_merc("Cai"))
	TestFixtures.check(res, "is zero fails with a dead", not TestFixtures.ok(a, fallen, "Dead Mercs", "IS", "0"),
		"one casualty is not zero")
	TestFixtures.check(res, "is not zero with a dead", TestFixtures.ok(a, fallen, "Dead Mercs", "IS NOT", "0"),
		"one casualty is not zero")
	TestFixtures.check(res, "is not zero fails with none", not TestFixtures.ok(a, contract_run, "Dead Mercs", "IS NOT", "0"),
		"no casualty is zero")
	TestFixtures.check(res, "blank op reads as is", TestFixtures.ok(a, contract_run, "Dead Mercs", "", "0"), "a blank op means IS")
	var wide: Array[Dictionary] = [TestFixtures.req("Damage Type", "CONTAINS", "Fire"),
		TestFixtures.req("Target Creature", "HAS TAG", "Beast")]
	TestFixtures.check(res, "new ops supported", LifepathRequirements.is_supported(TestFixtures.hand(wide)),
		"CONTAINS and HAS TAG are readable operators")
	var blank: Array[Dictionary] = [TestFixtures.req("Max HP", "", "")]
	TestFixtures.check(res, "blank row supported", LifepathRequirements.is_supported(TestFixtures.hand(blank)),
		"a row with no op and no value states nothing")
	TestFixtures.check(res, "blank row passes", LifepathRequirements.allows(a, TestFixtures.hand(blank), contract_run),
		"a row with no op and no value blocks nothing")


static func _case_stat_subjects(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var contract_run := TestFixtures.run_for(team)
	var wil: int = int(a.stats.get("wile", 0))
	var cgn: int = int(a.stats.get("cognition", 0))
	var lvl: int = int(a.stats.get("level", 0))
	var hp: int = int(a.stats.get("maximum_hit_points", 0))
	TestFixtures.check(res, "wil exact", TestFixtures.ok(a, contract_run, "WIL", "IS", str(wil)), "wile is %d" % wil)
	TestFixtures.check(res, "wil at or above", TestFixtures.ok(a, contract_run, "WIL", "IS >=", str(wil)), "wile is %d" % wil)
	TestFixtures.check(res, "wil above the bar fails", not TestFixtures.ok(a, contract_run, "WIL", "IS >=", str(wil + 1)),
		"wile %d is under %d" % [wil, wil + 1])
	TestFixtures.check(res, "cgn reads", TestFixtures.ok(a, contract_run, "CGN", "IS", str(cgn)), "cognition is %d" % cgn)
	TestFixtures.check(res, "level reads", TestFixtures.ok(a, contract_run, "Level", "IS >=", str(lvl)), "level is %d" % lvl)
	TestFixtures.check(res, "level five", lvl == 5, "the test merc is level %d" % lvl)
	TestFixtures.check(res, "max hp reads", TestFixtures.ok(a, contract_run, "Max HP", "IS >=", str(hp)), "max hp is %d" % hp)
	TestFixtures.check(res, "speed bar unmet", not TestFixtures.ok(a, contract_run, "Speed", "IS >=", "1000"),
		"speed is %d" % int(a.stats.get("speed", 0)))
	var each: Array[Dictionary] = [TestFixtures.req("Max HP", "IS >=", "Each")]
	TestFixtures.check(res, "non numeric stat value unsupported",
		not LifepathRequirements.is_supported(TestFixtures.hand(each)), "Each is not a number")


static func _case_knowledge(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var contract_run := TestFixtures.run_for(team)
	TestFixtures.check(res, "no knowledge counted", not TestFixtures.ok(a, contract_run, "Knowledge Count", "IS >=", "3"),
		"%d knowledge(s)" % a.knowledges.size())
	for k_name: String in ["Dramaturgy", "Tactics", "Herbalism"]:
		var k := UtilityTraitData.new()
		k.utility_name = k_name
		a.knowledges.append(k)
	TestFixtures.check(res, "knowledge counted", TestFixtures.ok(a, contract_run, "Knowledge Count", "IS >=", "3"),
		"%d knowledge(s)" % a.knowledges.size())
	TestFixtures.check(res, "knowledge named", TestFixtures.ok(a, contract_run, "Has Knowledge", "IS", "Dramaturgy"),
		"Ada studied Dramaturgy")
	TestFixtures.check(res, "knowledge missing", not TestFixtures.ok(a, contract_run, "Has Knowledge", "IS", "Falconry"),
		"Ada never studied Falconry")
	TestFixtures.check(res, "knowledge one of", TestFixtures.ok(a, contract_run, "Has Knowledge", "ONE OF", "Falconry, Tactics"),
		"Tactics is on the list")


static func _case_lifepath_subject(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var contract_run := TestFixtures.run_for(team)
	LifepathProgression.begin_contract(contract_run)
	TestFixtures.check(res, "lifepath absent", not TestFixtures.ok(a, contract_run, "Lifepath", "IS", "Buddy"),
		"Ada holds no Buddy")
	RelationshipSystem.set_value(a, b, 5)
	var _g: Array[String] = LifepathProgression.grant(a, "Buddy")
	TestFixtures.check(res, "lifepath present", TestFixtures.ok(a, contract_run, "Lifepath", "IS", "Buddy"), "Ada holds Buddy")
	var row: Array[Dictionary] = [TestFixtures.req("Lifepath", "IS NOT", "Buddy")]
	TestFixtures.check(res, "lifepath is not unsupported", not LifepathRequirements.is_supported(TestFixtures.hand(row)),
		"Lifepath only answers IS")


static func _case_weapon_perks(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var contract_run := TestFixtures.run_for(team)
	TestFixtures.check(res, "no weapon perks", not TestFixtures.ok(a, contract_run, "Weapon Perk Count", "IS >=", "3"),
		"%d weapon perk(s)" % a.weapon_perks.size())
	for i: int in range(3):
		a.weapon_perks.append(TraitData.new())
	TestFixtures.check(res, "weapon perks counted", TestFixtures.ok(a, contract_run, "Weapon Perk Count", "IS >=", "3"),
		"%d weapon perk(s)" % a.weapon_perks.size())


static func _case_location(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var contract_run := TestFixtures.run_for(team)
	var spectral: LocationData = DataManager.locations.get("Spectral", null) as LocationData
	TestFixtures.check(res, "spectral row found", spectral != null, "Locations.tsv holds Spectral")
	if spectral != null:
		contract_run.location = spectral
		TestFixtures.check(res, "location by name", TestFixtures.ok(a, contract_run, "Contract Location", "IS", "Spectral"),
			"the run sits in Spectral")
		TestFixtures.check(res, "location by type", TestFixtures.ok(a, contract_run, "Contract Location", "IS", "Domain"),
			"Spectral is a Domain")
		TestFixtures.check(res, "another domain refused", not TestFixtures.ok(a, contract_run, "Contract Location", "IS", "Weird"),
			"Spectral is not Weird")
		TestFixtures.check(res, "location by environment", TestFixtures.ok(a, contract_run, "Contract Location", "IS", "Sky"),
			"Spectral is a Sky domain")
	var cath: LocationData = DataManager.locations.get("Cathistii", null) as LocationData
	TestFixtures.check(res, "cathistii row found", cath != null, "Locations.tsv holds Cathistii")
	if cath != null:
		contract_run.location = cath
		TestFixtures.check(res, "settlement environment", TestFixtures.ok(a, contract_run, "Contract Location", "IS", "Urban"),
			"Cathistii is Urban")
		TestFixtures.check(res, "environ placeholder", TestFixtures.ok(a, contract_run, "Contract Location", "IS", "[ENVIRON]"),
			"Cathistii resolves an environment")
		a.starting_location = cath
		TestFixtures.check(res, "merc home exact", TestFixtures.ok(a, contract_run, "Contract Location", "IS", "[MERC HOME]"),
			"the run sits on Ada's home")
		contract_run.location = DataManager.locations.get("Aerdis", null) as LocationData
		TestFixtures.check(res, "merc home parent", TestFixtures.ok(a, contract_run, "Contract Location", "IS", "[MERC HOME]"),
			"Aerdis holds Ada's home")
		contract_run.location = DataManager.locations.get("Zukei", null) as LocationData
		TestFixtures.check(res, "merc home elsewhere",
			not TestFixtures.ok(a, contract_run, "Contract Location", "IS", "[MERC HOME]"), "Zukei is not Ada's home")
	TestFixtures.check(res, "undercity loaded", DataManager.locations.has("Undercity"),
		"Locations.tsv holds Undercity")
	if DataManager.locations.has("Undercity"):
		var under: LocationData = DataManager.locations["Undercity"] as LocationData
		TestFixtures.check(res, "undercity environment", under.environment == "Urban",
			"environment is %s" % under.environment)
		TestFixtures.check(res, "undercity parent", under.parent != null
			and under.parent.location_name == "Aerdis", "Undercity answers to Aerdis")
	var home: Array[Dictionary] = [TestFixtures.req("Contract Location", "IS", "[MERC HOME]")]
	TestFixtures.check(res, "home placeholder supported", LifepathRequirements.is_supported(TestFixtures.hand(home)),
		"[MERC HOME] is a value this code answers")
	var junk: Array[Dictionary] = [TestFixtures.req("Contract Location", "IS", "[SOMEWHERE]")]
	TestFixtures.check(res, "other placeholder unsupported",
		not LifepathRequirements.is_supported(TestFixtures.hand(junk)), "an unknown placeholder blocks the row")


static func _case_damage_subjects(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var contract_run := TestFixtures.run_for(team)
	LifepathTally.record_damage_taken(a, 3, "Fire")
	TestFixtures.check(res, "damage type taken", TestFixtures.ok(a, contract_run, "Damage Taken", "IS", "Fire"), "3 Fire recorded")
	TestFixtures.check(res, "damage type contains", TestFixtures.ok(a, contract_run, "Damage Type", "CONTAINS", "Fire"),
		"Fire is on the list")
	TestFixtures.check(res, "other damage type", not TestFixtures.ok(a, contract_run, "Damage Type", "IS", "Will"),
		"no Will damage recorded")
	TestFixtures.check(res, "damage taken is not zero", not TestFixtures.ok(a, contract_run, "Damage Taken", "IS", "0"),
		"3 is not 0")
	TestFixtures.check(res, "damage taken at least one", TestFixtures.ok(a, contract_run, "Damage Taken", "IS >=", "1"), "3 of 1")
	TestFixtures.check(res, "untouched merc took none", TestFixtures.ok(b, contract_run, "Damage Taken", "IS", "0"),
		"Bo took nothing")
	LifepathTally.record_damage_dealt_total(a, 9)
	TestFixtures.check(res, "damage dealt total", TestFixtures.ok(a, contract_run, "Damage Dealt", "IS >=", "9"), "9 dealt")
	TestFixtures.check(res, "damage dealt bar", not TestFixtures.ok(a, contract_run, "Damage Dealt", "IS >=", "10"),
		"9 is under 10")
	var c := _merc("Cai")
	var solo: Array[MercenaryData] = [c]
	var run2 := TestFixtures.run_for(solo)
	var c_hp: int = int(c.stats.get("maximum_hit_points", 0))
	LifepathTally.record_damage_dealt_total(c, c_hp + 1)
	TestFixtures.check(res, "damage dealt against a stat",
		TestFixtures.ok(c, run2, "Damage Dealt", "IS >=", "self.maximum_hit_points"),
		"%d dealt against max hp %d" % [c_hp + 1, c_hp])
	var e := _merc("Eli")
	e.stats["tolerance"] = 3
	LifepathTally.record_damage_taken(e, 3, "Strike")
	TestFixtures.check(res, "tolerance met", TestFixtures.ok(e, run2, "Damage Taken", "IS >=", "Tolerance"),
		"a 3 hit meets tolerance 3")
	var f := _merc("Fen")
	f.stats["tolerance"] = 3
	LifepathTally.record_damage_taken(f, 2, "Strike")
	TestFixtures.check(res, "tolerance missed", not TestFixtures.ok(f, run2, "Damage Taken", "IS >=", "Tolerance"),
		"a 2 hit misses tolerance 3")


static func _case_check_kinds(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var contract_run := TestFixtures.run_for(team)
	LifepathTally.record_check(a, "resist", 0, false)
	TestFixtures.check(res, "resist failure reads", TestFixtures.ok(a, contract_run, "Failed Check", "IS", "Resist"),
		"a failed resist is a named failure")
	TestFixtures.check(res, "no reroll yet", not TestFixtures.ok(a, contract_run, "Reroll", "IS", "Success"),
		"nothing was rerolled")
	LifepathTally.record_check(a, "reroll", 1, true, false)
	TestFixtures.check(res, "reroll success reads", TestFixtures.ok(a, contract_run, "Reroll", "IS", "Success"),
		"a rerolled success is recorded")
	TestFixtures.check(res, "reroll is not a failure", LifepathTally.failure_count(a) == 1,
		"one failure stands, got %d" % LifepathTally.failure_count(a))
	TestFixtures.check(res, "fresh merc has no reroll", not TestFixtures.ok(b, contract_run, "Reroll", "IS", "Success"),
		"Bo rerolled nothing")
	var row: Array[Dictionary] = [TestFixtures.req("Reroll", "IS", "Failure")]
	TestFixtures.check(res, "reroll failure unsupported", not LifepathRequirements.is_supported(TestFixtures.hand(row)),
		"Reroll only answers Success")


#A formula event naming team.negotiate records that check for every living merc, win or lose.
static func _case_contract_check_kinds(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var event := EventData.new()
	event.event_name = "TEST Parley"
	event.event_type = "Mishap"
	event.success_formula = "team.negotiate - (50.0 - (target.wile * 10.0))"
	var kinds: Array[String] = FormulaEventResolver.check_kinds(event.success_formula)
	TestFixtures.check(res, "formula names one kind", kinds.size() == 1 and kinds[0] == "negotiate",
		"got [%s]" % ", ".join(kinds))
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var contract_run := TestFixtures.run_for(team)
	for merc: MercenaryData in team:
		merc.stats["negotiate"] = 1000.0
	var won: Dictionary = FormulaEventResolver.resolve(event, contract_run)
	TestFixtures.check(res, "formula event succeeds", bool(won["success"]),
		"negotiate 1000 beats any roll")
	TestFixtures.check(res, "negotiate success recorded",
		TestFixtures.ok(a, contract_run, "Succeeded Check", "IS", "Negotiate")
		and TestFixtures.ok(b, contract_run, "Succeeded Check", "IS", "Negotiate"),
		"both living mercs hold a negotiate success")
	TestFixtures.reset_campaign()
	var c := _merc("Cyd")
	var lost_team: Array[MercenaryData] = [c]
	var lost_run := TestFixtures.run_for(lost_team)
	c.stats["negotiate"] = -1000.0
	var lost: Dictionary = FormulaEventResolver.resolve(event, lost_run)
	TestFixtures.check(res, "formula event fails", not bool(lost["success"]),
		"negotiate -1000 loses every roll")
	TestFixtures.check(res, "negotiate failure recorded", TestFixtures.ok(c, lost_run, "Failed Check", "IS", "Negotiate"),
		"the failed group check names negotiate")
	var aoe: Array[Dictionary] = [TestFixtures.req("Succeeded Check", "IS", "Avoid AoE")]
	TestFixtures.check(res, "avoid aoe supported", LifepathRequirements.is_supported(TestFixtures.hand(aoe)),
		"Avoid AoE is a check kind")
	var stat_row: Array[Dictionary] = [TestFixtures.req("Succeeded Check", "IS", "Negotiate")]
	TestFixtures.check(res, "stat token supported", LifepathRequirements.is_supported(TestFixtures.hand(stat_row)),
		"Negotiate is a Stats.tsv name")
	var bad: Array[Dictionary] = [TestFixtures.req("Succeeded Check", "IS", "Nonstat")]
	TestFixtures.check(res, "unknown stat unsupported", not LifepathRequirements.is_supported(TestFixtures.hand(bad)),
		"Nonstat is neither a check kind nor a stat")


static func _case_targets(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var contract_run := TestFixtures.run_for(team)
	var tags: Array[String] = ["beast", "merc"]
	contract_run.target_record = {"tags": tags, "count": 4, "speed": 30, "max_hp": 12, "failed": {}}
	TestFixtures.check(res, "target tag held", TestFixtures.ok(a, contract_run, "Target Creature", "HAS TAG", "Beast"),
		"the target is a Beast")
	TestFixtures.check(res, "target tag absent", not TestFixtures.ok(a, contract_run, "Target Creature", "HAS TAG", "Authority"),
		"no Authority tag")
	TestFixtures.check(res, "target is merc", TestFixtures.ok(a, contract_run, "Target Creature", "IS", "Merc"),
		"IS reads the same list as HAS TAG")
	TestFixtures.check(res, "target type token", TestFixtures.ok(a, contract_run, "Target Creature", "IS", "[Type]"),
		"Beast is a Types.tsv creature")
	var only: Array[String] = ["merc"]
	contract_run.target_record = {"tags": only, "count": 1, "speed": 0, "max_hp": 0, "failed": {}}
	TestFixtures.check(res, "no creature type", not TestFixtures.ok(a, contract_run, "Target Creature", "IS", "[Type]"),
		"merc is not a Types.tsv creature")
	var ghost := MercenaryData.new()
	ghost.merc_name = "Ghost"
	LifepathTally.record_target_check(ghost, "wile", false)
	TestFixtures.check(res, "target failed check", TestFixtures.ok(a, contract_run, "Target Failed Check", "IS", "Wile"),
		"the target failed a Wile check")
	TestFixtures.check(res, "target passed check", not TestFixtures.ok(a, contract_run, "Target Failed Check", "IS", "Vigor"),
		"no Vigor failure recorded")
	LifepathTally.record_target_check(a, "vigor", false)
	TestFixtures.check(res, "a merc is not the target", not TestFixtures.ok(a, contract_run, "Target Failed Check", "IS", "Vigor"),
		"a merc with a uid never lands on the target record")
	for i: int in range(3):
		LifepathTally.record_inflicted(a, "Surprised")
	var three: Array[Dictionary] = [TestFixtures.req("State Inflicted", "IS", "Surprised", "AND"),
		TestFixtures.req("Count", "IS >=", "3")]
	TestFixtures.check(res, "inflicted count met", LifepathRequirements.allows(a, TestFixtures.hand(three), contract_run),
		"three Surprised applied")
	var four: Array[Dictionary] = [TestFixtures.req("State Inflicted", "IS", "Surprised", "AND"),
		TestFixtures.req("Count", "IS >=", "4")]
	TestFixtures.check(res, "inflicted count bar", not LifepathRequirements.allows(a, TestFixtures.hand(four), contract_run),
		"three is under four")
	TestFixtures.check(res, "count without a state", not TestFixtures.ok(a, contract_run, "Count", "IS >=", "1"),
		"Count needs a State Inflicted entry before it")
	TestFixtures.check(res, "target rows supported", LifepathRequirements.is_supported(TestFixtures.hand(three)),
		"State Inflicted and Count are readable")


static func _case_stat_bonus(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var boost: LifepathData = _fake("TEST Vigor Boost", "")
	boost.stat_bonus_5pct = ["Vigor"] as Array[String]
	var before: float = float(a.stat_multipliers.get("vigor", 0.0))
	var _g: Array[String] = LifepathProgression.grant(a, "TEST Vigor Boost")
	var after: float = float(a.stat_multipliers.get("vigor", 0.0))
	TestFixtures.check(res, "stat bonus applied", is_equal_approx(after, before + 0.05),
		"vigor multiplier %.2f to %.2f" % [before, after])
	var record: Dictionary = a.lifepath_stat_deltas.get("TEST Vigor Boost", {}) as Dictionary
	var mult: Dictionary = record.get("mult", {}) as Dictionary
	TestFixtures.check(res, "stat bonus recorded", mult.has("vigor"), "the delta names vigor")
	for i: int in range(LifepathProgression.MAX_EVENTS - a.lifepaths.size()):
		a.lifepaths.append(TestFixtures.lifepath("Death Trauma"))
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	TestFixtures.check(res, "stat bonus reverted",
		is_equal_approx(float(a.stat_multipliers.get("vigor", 0.0)), before),
		"vigor multiplier back to %.2f" % float(a.stat_multipliers.get("vigor", 0.0)))
	_unregister(boost)


static func _case_placeholder_trait(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var a := _merc("Ada")
	var column: Array = DataManager.type_columns.get("TEMPLE TRAIT", []) as Array
	TestFixtures.check(res, "temple column loaded", not column.is_empty(),
		"Types.tsv holds %d TEMPLE TRAIT value(s)" % column.size())
	var temple: LifepathData = _fake("TEST Temple", "[TEMPLE TRAIT]")
	var _g: Array[String] = LifepathProgression.grant(a, "TEST Temple")
	var record: Dictionary = a.lifepath_stat_deltas.get("TEST Temple", {}) as Dictionary
	var names: Array = record.get("traits", []) as Array
	TestFixtures.check(res, "placeholder resolved once", names.size() == 1,
		"%d resolved name(s)" % names.size())
	var resolved: String = str(names[0]) if names.size() == 1 else ""
	TestFixtures.check(res, "resolved name from the column", column.has(resolved), "resolved %s" % resolved)
	TestFixtures.check(res, "merc holds the resolved trait", TestFixtures.holds_trait(a, resolved),
		"%s is on the trait list" % resolved)
	for i: int in range(LifepathProgression.MAX_EVENTS - a.lifepaths.size()):
		a.lifepaths.append(TestFixtures.lifepath("Death Trauma"))
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	TestFixtures.check(res, "resolved trait removed", not TestFixtures.holds_trait(a, resolved), "%s is gone" % resolved)
	_unregister(temple)


static func _case_payoff_placeholder(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	var column: Array = DataManager.type_columns.get("PACT BEING", []) as Array
	var variants: Array[String] = TraitDSL.placeholder_variants("Pact of the [PACT BEING]")
	TestFixtures.check(res, "variant count matches the column", variants.size() == column.size(),
		"%d variant(s) for %d PACT BEING value(s)" % [variants.size(), column.size()])
	var prefixed: bool = not variants.is_empty()
	for variant: String in variants:
		if not variant.begins_with("Pact of the "):
			prefixed = false
	TestFixtures.check(res, "variants keep the literal text", prefixed,
		"every variant reads Pact of the <value>")
	var plain: Array[String] = TraitDSL.placeholder_variants("Awkward")
	TestFixtures.check(res, "plain name returns itself", plain.size() == 1 and plain[0] == "Awkward",
		"Awkward expands to %d name(s)" % plain.size())
	TestFixtures.check(res, "unknown column returns nothing",
		TraitDSL.placeholder_variants("[NO SUCH COLUMN ZZ]").is_empty(),
		"a missing Types.tsv column yields no variant")
	var pact: LifepathData = TestFixtures.lifepath("Pact")
	var steady: bool = pact != null
	for i: int in range(30):
		if not LifepathProgression.has_payoff(pact):
			steady = false
	TestFixtures.check(res, "placeholder payoff is deterministic", steady,
		"Pact pays off on 30 consecutive calls")
	var vow := LifepathData.new()
	vow.event_type = "Experienced"
	vow.event_name = "TEST Vow Payoff"
	vow.perks = ["[VOW]"] as Array[String]
	TestFixtures.check(res, "vow placeholder pays off", LifepathProgression.has_payoff(vow),
		"a [VOW] perk finds a variant with a DSL cell")
	var dud := LifepathData.new()
	dud.event_type = "Experienced"
	dud.event_name = "TEST No Payoff"
	dud.perks = ["No Such Trait Zz"] as Array[String]
	TestFixtures.check(res, "missing trait has no payoff", not LifepathProgression.has_payoff(dud),
		"an unknown trait name grants no payoff")


static func _case_apply_effect(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	TraitRuntime.clear_all()
	var a := _merc("Ada")
	var td := TraitData.new()
	td.trait_name = "TEST Apply Fatigue"
	td.trait_type = "Perk"
	td.effect_dsl = "on:state_gained:poisoned:always:apply:fatigued"
	a.perks.append(td)
	TraitRuntime.fire("state_gained:poisoned", a, {})
	TestFixtures.check(res, "apply sets the state", ConstStates.has_state(a, ConstStates.FATIGUED),
		"apply: put Fatigued on Ada with no resist roll")
	var b := _merc("Bo")
	TraitRuntime.fire("state_gained:poisoned", b, {})
	TestFixtures.check(res, "no trait no state", not ConstStates.has_state(b, ConstStates.FATIGUED),
		"Bo carries no apply: clause")
	TraitRuntime.clear_all()


static func _case_location_condition(res: Dictionary) -> void:
	TestFixtures.reset_campaign()
	TraitRuntime.clear_all()
	var a := _merc("Ada")
	var td := TraitData.new()
	td.trait_name = "TEST Urban Toll"
	td.trait_type = "Perk"
	td.effect_dsl = "on:contract_start:location:urban:resource:hp:-1"
	a.perks.append(td)
	var team: Array[MercenaryData] = [a]
	var urban := TestFixtures.run_for(team)
	urban.location = DataManager.locations.get("Cathistii", null) as LocationData
	var before: int = a.current_hp
	TraitRuntime.begin_contract(urban)
	TestFixtures.check(res, "environment condition fires", a.current_hp == before - 1,
		"hp %d to %d in an Urban settlement" % [before, a.current_hp])
	var forest := TestFixtures.run_for(team)
	forest.location = DataManager.locations.get("Zukei", null) as LocationData
	var held: int = a.current_hp
	TraitRuntime.begin_contract(forest)
	TestFixtures.check(res, "other environment holds", a.current_hp == held,
		"hp held at %d in a Forest country" % a.current_hp)
	TraitRuntime.clear_all()


#Prints which Experienced events the level up pool can actually draw, for the sheet audit.
static func _audit() -> void:
	var supported: Array[String] = []
	var blocked: Array[String] = []
	for lp: LifepathData in DataManager.lifepaths_by_category.get("Experienced", []) as Array:
		if lp == null:
			continue
		if LifepathRequirements.is_supported(lp) and LifepathProgression.has_payoff(lp):
			supported.append(lp.event_name)
		else:
			blocked.append(lp.event_name)
	print("LIFEPATH POOL AUDIT: %d drawable, %d blocked" % [supported.size(), blocked.size()])
	print("  DRAWABLE: %s" % ", ".join(supported))
