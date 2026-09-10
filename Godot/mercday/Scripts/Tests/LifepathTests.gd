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
	var total: int = int(res["pass"]) + int(res["fail"])
	print("LIFEPATH TESTS SUMMARY: %d/%d passed, %d failed" % [int(res["pass"]), total, int(res["fail"])])
	return int(res["fail"]) == 0


static func _check(res: Dictionary, label: String, ok: bool, detail: String) -> void:
	if ok:
		res["pass"] = int(res["pass"]) + 1
		print("PASS %s | %s" % [label, detail])
	else:
		res["fail"] = int(res["fail"]) + 1
		print("FAIL %s | %s" % [label, detail])


static func _reset() -> void:
	CampaignKnowledge.clear()
	RelationshipSystem.clear_tallies()
	LifepathTally.clear()
	LifepathProgression.clear()
	CheckSystem.forced_rolls.clear()


static func _merc(name: String) -> MercenaryData:
	var m := MercenaryData.new()
	m.merc_name = name
	m.merc_uid = CampaignKnowledge.next_uid()
	m.max_stats = {"max_vigor": 8, "max_dexterity": 8, "max_cognition": 8, "max_wile": 8, "size": 1}
	m.luck_roll = 5.0
	m.stats = {"level": 5}
	m.stats = StatCalculator.calculate_all(m)
	m.stats["pain_limit"] = 0
	m.stats_baseline = StatCalculator.calculate_all(m)
	m.current_hp = int(m.stats.get("maximum_hit_points", 1))
	m.current_ep = 0
	return m


static func _run_for(team: Array[MercenaryData]) -> ContractRun:
	var run := ContractRun.new()
	run.team.assign(team)
	return run


static func _lp(event_name: String) -> LifepathData:
	for category: String in DataManager.lifepaths_by_category:
		for lp: LifepathData in DataManager.lifepaths_by_category[category] as Array:
			if lp != null and lp.event_name == event_name:
				return lp
	return null


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
	_reset()
	var m := _merc("Ada")
	m.stats["luck"] = 0
	m.lifepath_roll_step = 0
	_check(res, "chance base", LifepathProgression.chance_for(m) == 5,
		"5 percent at step 0, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 1
	_check(res, "chance doubles", LifepathProgression.chance_for(m) == 10,
		"10 percent at step 1, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 3
	_check(res, "chance doubles again", LifepathProgression.chance_for(m) == 40,
		"40 percent at step 3, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 9
	_check(res, "chance caps", LifepathProgression.chance_for(m) == 100,
		"capped at 100, got %d" % LifepathProgression.chance_for(m))
	m.lifepath_roll_step = 0
	m.stats["luck"] = 7
	_check(res, "luck added after", LifepathProgression.chance_for(m) == 12,
		"5 plus 7 luck, got %d" % LifepathProgression.chance_for(m))


static func _case_tally(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var ghost := MercenaryData.new()
	ghost.merc_name = "Ghost"
	LifepathTally.record_check(a, "Vigor", 2, true)
	LifepathTally.record_check(a, "Vigor", 1, true)
	_check(res, "best success kept", LifepathTally.success_count(a, "vigor") == 2,
		"best of 2 and 1, got %d" % LifepathTally.success_count(a, "vigor"))
	LifepathTally.record_check(a, "Wile", 0, false)
	_check(res, "failure counted", LifepathTally.failure_count(a) == 1,
		"one failure, got %d" % LifepathTally.failure_count(a))
	_check(res, "failed stat named", LifepathTally.failed_stat(a, "wile"), "wile is the failed stat")
	LifepathTally.record_cheat_death(a, 0, false)
	_check(res, "death test is not a failure", LifepathTally.failure_count(a) == 1,
		"still one failure, got %d" % LifepathTally.failure_count(a))
	LifepathTally.record_cheat_death(a, 1, true)
	_check(res, "death test success recorded", LifepathTally.succeeded(a, "cheat_death"),
		"cheat death shows as passed")
	LifepathTally.record_damage(a, 5, 4, "Ranged")
	_check(res, "damage at tolerance", LifepathTally.damage_met_tolerance(a, "ranged"),
		"5 damage meets tolerance 4")
	LifepathTally.record_damage(a, 2, 4, "Melee")
	_check(res, "damage under tolerance", not LifepathTally.damage_met_tolerance(a, "melee"),
		"2 damage misses tolerance 4")
	_check(res, "damage any type", LifepathTally.damage_met_tolerance(a, ""), "any weapon class matched")
	LifepathTally.record_check(ghost, "Vigor", 3, true)
	_check(res, "no uid not tallied", LifepathTally.success_count(ghost, "vigor") == 0,
		"a merc with no campaign uid is skipped")


static func _case_requirements(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var run := _run_for(team)
	var dead := _merc("Cai")
	var buddy: LifepathData = _lp("Buddy")
	_check(res, "buddy row found", buddy != null, "Lifepaths.tsv holds Buddy")
	if buddy != null:
		RelationshipSystem.set_value(a, b, 4)
		_check(res, "relationship below bar", not LifepathRequirements.allows(a, buddy, run),
			"4 is under the 5 Buddy asks for")
		RelationshipSystem.set_value(a, b, 5)
		_check(res, "relationship meets bar", LifepathRequirements.allows(a, buddy, run),
			"5 meets the 5 Buddy asks for")
	var trauma: LifepathData = _lp("Death Trauma")
	_check(res, "death trauma row found", trauma != null, "Lifepaths.tsv holds Death Trauma")
	if trauma != null:
		_check(res, "no casualty no trauma", not LifepathRequirements.allows(a, trauma, run),
			"nobody died")
		run.casualties.append(dead)
		_check(res, "casualty allows trauma", LifepathRequirements.allows(a, trauma, run),
			"one casualty meets the bar")
	var survivor: LifepathData = _lp("Miraculous Survivor")
	_check(res, "survivor row found", survivor != null, "Lifepaths.tsv holds Miraculous Survivor")
	if survivor != null:
		_check(res, "no death test no survivor", not LifepathRequirements.allows(a, survivor, run),
			"no cheat death success recorded")
		LifepathTally.record_cheat_death(a, 1, true)
		_check(res, "death test allows survivor", LifepathRequirements.allows(a, survivor, run),
			"a passed cheat death meets the bar")
	var unsupported: LifepathData = _lp("Master of Disguise")
	if unsupported != null:
		_check(res, "unknown subject unsupported", not LifepathRequirements.is_supported(unsupported),
			"Has Tool is not a subject this code answers")


static func _case_pool(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var run := _run_for(team)
	RelationshipSystem.set_value(a, b, 0)
	RelationshipSystem.set_value(b, a, 0)
	var _q: Array[String] = LifepathProgression.refresh_pool(a, run)
	_check(res, "pool skips unmet", not a.lifepath_pool.has("Buddy"), "relationship 0 keeps Buddy out")
	RelationshipSystem.set_value(a, b, 7)
	var lines: Array[String] = LifepathProgression.refresh_pool(a, run)
	_check(res, "pool takes met", a.lifepath_pool.has("Buddy"), "relationship 7 qualifies for Buddy")
	_check(res, "pool line emitted", lines.size() >= 1, "%d line(s)" % lines.size())
	var before: int = a.lifepath_pool.size()
	var _again: Array[String] = LifepathProgression.refresh_pool(a, run)
	_check(res, "pool does not duplicate", a.lifepath_pool.size() == before,
		"size held at %d" % a.lifepath_pool.size())


static func _case_rarity(res: Dictionary) -> void:
	_reset()
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
	_check(res, "draw names pool entries", common + very_rare == 200,
		"%d of 200 draws named a pool entry" % (common + very_rare))
	_check(res, "draw favours common", common > very_rare * 2,
		"Common 50 vs Very Rare 9 weight: Bar Fight %d, Assassin of Kings %d" % [common, very_rare])
	_check(res, "draw reaches very rare", very_rare > 0,
		"Assassin of Kings drawn %d time(s)" % very_rare)
	_check(res, "draw pool unchanged", pool.size() == 2, "%d name(s) left" % pool.size())
	_check(res, "empty draw", LifepathProgression.draw([] as Array[String]) == "",
		"an empty pool draws nothing")
	_check(res, "unknown name draws nothing",
		LifepathProgression.draw(["No Such Event"] as Array[String]) == "",
		"a name with no Lifepaths.tsv row is skipped")


static func _case_level_up(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	a.lifepath_pool = ["Death Trauma"] as Array[String]
	_force_draw(a)
	var lines: Array[String] = LifepathProgression.on_level_up(a)
	_check(res, "level up grants", LifepathProgression.has_event(a, "Death Trauma"),
		"a 100 percent roll draws from the pool")
	_check(res, "step resets", a.lifepath_roll_step == 0,
		"step back to 0, got %d" % a.lifepath_roll_step)
	_check(res, "drawn name leaves pool", not a.lifepath_pool.has("Death Trauma"),
		"a taken event is no longer a candidate")
	_check(res, "level up line emitted", lines.size() >= 2, "%d line(s)" % lines.size())
	var b := _merc("Bo")
	_force_draw(b)
	var empty: Array[String] = LifepathProgression.on_level_up(b)
	_check(res, "empty pool gains nothing", b.lifepaths.is_empty(), "no event to draw")
	_check(res, "empty pool still steps", b.lifepath_roll_step == 7,
		"step advanced to 7, got %d" % b.lifepath_roll_step)
	_check(res, "empty pool silent", empty.is_empty(), "%d line(s)" % empty.size())


static func _case_stat_delta(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var boost: LifepathData = _fake("TEST Boost", "Another Miracle")
	var before: int = int(a.stats.get("cheat_death", 0))
	var _g: Array[String] = LifepathProgression.grant(a, "TEST Boost")
	var after: int = int(a.stats.get("cheat_death", 0))
	_check(res, "granted trait moves the stat", after == before + 5,
		"cheat death %d to %d" % [before, after])
	_check(res, "delta recorded", a.lifepath_stat_deltas.has("TEST Boost"),
		"the event stored what it moved")
	for i: int in range(LifepathProgression.MAX_EVENTS - a.lifepaths.size()):
		a.lifepaths.append(_lp("Death Trauma"))
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	_check(res, "displacement undoes the stat", int(a.stats.get("cheat_death", 0)) == before,
		"cheat death back to %d, got %d" % [before, int(a.stats.get("cheat_death", 0))])
	_check(res, "delta cleared", not a.lifepath_stat_deltas.has("TEST Boost"),
		"the record went with the event")
	_unregister(boost)


static func _case_capacity(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var filler: LifepathData = _lp("Death Trauma")
	for i: int in range(LifepathProgression.MAX_EVENTS):
		a.lifepaths.append(filler)
	var spare: LifepathData = _fake("TEST Spare", "Another Miracle")
	var blocked: Array[String] = LifepathProgression.grant(a, "TEST Spare")
	_check(res, "full list blocks a gain", blocked.is_empty(), "%d line(s)" % blocked.size())
	_check(res, "full list unchanged", a.lifepaths.size() == LifepathProgression.MAX_EVENTS,
		"still %d events" % a.lifepaths.size())
	var forced: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	_check(res, "forced displaces", LifepathProgression.has_event(a, "Buddy's Passing"),
		"a forced event makes its own room")
	_check(res, "size held at the cap", a.lifepaths.size() == LifepathProgression.MAX_EVENTS,
		"still %d events, got %d" % [LifepathProgression.MAX_EVENTS, a.lifepaths.size()])
	_check(res, "displacement reported", forced.size() >= 2, "%d line(s)" % forced.size())
	_unregister(spare)


static func _case_forced_replace(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	LifepathProgression.begin_contract(_run_for(team))
	RelationshipSystem.set_value(a, b, 8)
	var _g: Array[String] = LifepathProgression.grant(a, "Buddy")
	_check(res, "buddy granted", LifepathProgression.has_event(a, "Buddy"), "Ada holds Buddy")
	var size_before: int = a.lifepaths.size()
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	_check(res, "passing replaces buddy", not LifepathProgression.has_event(a, "Buddy"),
		"Buddy gave way to Buddy's Passing")
	_check(res, "passing held", LifepathProgression.has_event(a, "Buddy's Passing"),
		"the forced event is on the list")
	_check(res, "replacement is one for one", a.lifepaths.size() == size_before,
		"size held at %d, got %d" % [size_before, a.lifepaths.size()])


static func _case_buddy(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var c := _merc("Cai")
	var team: Array[MercenaryData] = [a, b, c]
	LifepathProgression.begin_contract(_run_for(team))
	RelationshipSystem.set_value(a, b, 3)
	RelationshipSystem.set_value(a, c, 9)
	var lines: Array[String] = LifepathProgression.grant(a, "Buddy")
	_check(res, "buddy points at the closest", a.buddy_uid == c.merc_uid,
		"Ada paired with Cai, not Bo")
	_check(res, "buddy is returned", LifepathProgression.has_event(c, "Buddy"),
		"Cai took Buddy back")
	_check(res, "buddy points both ways", c.buddy_uid == a.merc_uid, "Cai points at Ada")
	_check(res, "buddy lines emitted", lines.size() >= 3, "%d line(s)" % lines.size())
	var run := _run_for(team)
	run.team.erase(c)
	run.casualties.append(c)
	var mourn: Array[String] = LifepathProgression.end_contract(run)
	_check(res, "dead buddy forces passing", LifepathProgression.has_event(a, "Buddy's Passing"),
		"losing a buddy replaces the event")
	_check(res, "passing clears the pointer", a.buddy_uid == 0,
		"buddy uid cleared, got %d" % a.buddy_uid)
	_check(res, "mourning reported", mourn.size() >= 1, "%d line(s)" % mourn.size())


static func _case_beau(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	LifepathProgression.begin_contract(_run_for(team))
	RelationshipSystem.set_value(a, b, 6)
	var lines: Array[String] = LifepathProgression.grant(a, "In Love")
	_check(res, "in love points at a beau", a.beau_uid == b.merc_uid, "Ada pines for Bo")
	_check(res, "in love is one sided", not LifepathProgression.has_event(b, "In Love"),
		"Bo has not decided yet")
	_check(res, "in love pointer one way", b.beau_uid == 0,
		"Bo points at nobody, got %d" % b.beau_uid)
	_check(res, "in love lines emitted", lines.size() >= 2, "%d line(s)" % lines.size())
	b.stats["luck"] = 100
	RelationshipSystem.set_value(a, b, 10)
	RelationshipSystem.set_value(b, a, 10)
	var _settled: Array[String] = LifepathProgression.end_contract(_run_for(team))
	_check(res, "a sure beau answers", LifepathProgression.has_event(b, "In Love"),
		"a full relationship window returns the feeling")
	_reset()
	var c := _merc("Cai")
	var d := _merc("Dee")
	var team2: Array[MercenaryData] = [c, d]
	LifepathProgression.begin_contract(_run_for(team2))
	RelationshipSystem.set_value(c, d, 6)
	var _g2: Array[String] = LifepathProgression.grant(c, "In Love")
	d.stats["luck"] = 100
	RelationshipSystem.set_value(c, d, 0)
	RelationshipSystem.set_value(d, c, 0)
	var _turned: Array[String] = LifepathProgression.end_contract(_run_for(team2))
	_check(res, "a closed beau refuses", LifepathProgression.has_event(c, "Forever Yearning"),
		"an empty relationship window turns the merc down")
	_check(res, "refusal replaces in love", not LifepathProgression.has_event(c, "In Love"),
		"Forever Yearning stands in for In Love")


#One requirement cell as DataManager stores it; conj joins this entry to the next.
static func _req(subject: String, op: String, value: String, conj: String = "") -> Dictionary:
	return {"subject": subject, "op": op, "value": value, "conj": conj}


#A lifepath built in code, for requirement shapes no Lifepaths.tsv row carries.
static func _hand(reqs: Array[Dictionary]) -> LifepathData:
	var lp := LifepathData.new()
	lp.event_type = "Experienced"
	lp.event_name = "TEST Hand"
	lp.requirements.assign(reqs)
	return lp


static func _ok(merc: MercenaryData, run: ContractRun, subject: String, op: String,
		value: String) -> bool:
	var single: Array[Dictionary] = [_req(subject, op, value)]
	return LifepathRequirements.allows(merc, _hand(single), run)


static func _holds(merc: MercenaryData, trait_name: String) -> bool:
	if trait_name == "":
		return false
	for store: Array in [merc.perks, merc.drawbacks, merc.descriptors]:
		for i: int in range(store.size()):
			var td: TraitData = store[i] as TraitData
			if td != null and td.trait_name == trait_name:
				return true
	return false


static func _case_ops(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var run := _run_for(team)
	_check(res, "is zero with no dead", _ok(a, run, "Dead Mercs", "IS", "0"), "nobody died")
	var fallen := _run_for(team)
	fallen.casualties.append(_merc("Cai"))
	_check(res, "is zero fails with a dead", not _ok(a, fallen, "Dead Mercs", "IS", "0"),
		"one casualty is not zero")
	_check(res, "is not zero with a dead", _ok(a, fallen, "Dead Mercs", "IS NOT", "0"),
		"one casualty is not zero")
	_check(res, "is not zero fails with none", not _ok(a, run, "Dead Mercs", "IS NOT", "0"),
		"no casualty is zero")
	_check(res, "blank op reads as is", _ok(a, run, "Dead Mercs", "", "0"), "a blank op means IS")
	var wide: Array[Dictionary] = [_req("Damage Type", "CONTAINS", "Fire"),
		_req("Target Creature", "HAS TAG", "Beast")]
	_check(res, "new ops supported", LifepathRequirements.is_supported(_hand(wide)),
		"CONTAINS and HAS TAG are readable operators")
	var blank: Array[Dictionary] = [_req("Max HP", "", "")]
	_check(res, "blank row supported", LifepathRequirements.is_supported(_hand(blank)),
		"a row with no op and no value states nothing")
	_check(res, "blank row passes", LifepathRequirements.allows(a, _hand(blank), run),
		"a row with no op and no value blocks nothing")


static func _case_stat_subjects(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var run := _run_for(team)
	var wil: int = int(a.stats.get("wile", 0))
	var cgn: int = int(a.stats.get("cognition", 0))
	var lvl: int = int(a.stats.get("level", 0))
	var hp: int = int(a.stats.get("maximum_hit_points", 0))
	_check(res, "wil exact", _ok(a, run, "WIL", "IS", str(wil)), "wile is %d" % wil)
	_check(res, "wil at or above", _ok(a, run, "WIL", "IS >=", str(wil)), "wile is %d" % wil)
	_check(res, "wil above the bar fails", not _ok(a, run, "WIL", "IS >=", str(wil + 1)),
		"wile %d is under %d" % [wil, wil + 1])
	_check(res, "cgn reads", _ok(a, run, "CGN", "IS", str(cgn)), "cognition is %d" % cgn)
	_check(res, "level reads", _ok(a, run, "Level", "IS >=", str(lvl)), "level is %d" % lvl)
	_check(res, "level five", lvl == 5, "the test merc is level %d" % lvl)
	_check(res, "max hp reads", _ok(a, run, "Max HP", "IS >=", str(hp)), "max hp is %d" % hp)
	_check(res, "speed bar unmet", not _ok(a, run, "Speed", "IS >=", "1000"),
		"speed is %d" % int(a.stats.get("speed", 0)))
	var each: Array[Dictionary] = [_req("Max HP", "IS >=", "Each")]
	_check(res, "non numeric stat value unsupported",
		not LifepathRequirements.is_supported(_hand(each)), "Each is not a number")


static func _case_knowledge(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var run := _run_for(team)
	_check(res, "no knowledge counted", not _ok(a, run, "Knowledge Count", "IS >=", "3"),
		"%d knowledge(s)" % a.knowledges.size())
	for k_name: String in ["Dramaturgy", "Tactics", "Herbalism"]:
		var k := UtilityTraitData.new()
		k.utility_name = k_name
		a.knowledges.append(k)
	_check(res, "knowledge counted", _ok(a, run, "Knowledge Count", "IS >=", "3"),
		"%d knowledge(s)" % a.knowledges.size())
	_check(res, "knowledge named", _ok(a, run, "Has Knowledge", "IS", "Dramaturgy"),
		"Ada studied Dramaturgy")
	_check(res, "knowledge missing", not _ok(a, run, "Has Knowledge", "IS", "Falconry"),
		"Ada never studied Falconry")
	_check(res, "knowledge one of", _ok(a, run, "Has Knowledge", "ONE OF", "Falconry, Tactics"),
		"Tactics is on the list")


static func _case_lifepath_subject(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var run := _run_for(team)
	LifepathProgression.begin_contract(run)
	_check(res, "lifepath absent", not _ok(a, run, "Lifepath", "IS", "Buddy"),
		"Ada holds no Buddy")
	RelationshipSystem.set_value(a, b, 5)
	var _g: Array[String] = LifepathProgression.grant(a, "Buddy")
	_check(res, "lifepath present", _ok(a, run, "Lifepath", "IS", "Buddy"), "Ada holds Buddy")
	var row: Array[Dictionary] = [_req("Lifepath", "IS NOT", "Buddy")]
	_check(res, "lifepath is not unsupported", not LifepathRequirements.is_supported(_hand(row)),
		"Lifepath only answers IS")


static func _case_weapon_perks(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var run := _run_for(team)
	_check(res, "no weapon perks", not _ok(a, run, "Weapon Perk Count", "IS >=", "3"),
		"%d weapon perk(s)" % a.weapon_perks.size())
	for i: int in range(3):
		a.weapon_perks.append(TraitData.new())
	_check(res, "weapon perks counted", _ok(a, run, "Weapon Perk Count", "IS >=", "3"),
		"%d weapon perk(s)" % a.weapon_perks.size())


static func _case_location(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var run := _run_for(team)
	var spectral: LocationData = DataManager.locations.get("Spectral", null) as LocationData
	_check(res, "spectral row found", spectral != null, "Locations.tsv holds Spectral")
	if spectral != null:
		run.location = spectral
		_check(res, "location by name", _ok(a, run, "Contract Location", "IS", "Spectral"),
			"the run sits in Spectral")
		_check(res, "location by type", _ok(a, run, "Contract Location", "IS", "Domain"),
			"Spectral is a Domain")
		_check(res, "another domain refused", not _ok(a, run, "Contract Location", "IS", "Weird"),
			"Spectral is not Weird")
		_check(res, "location by environment", _ok(a, run, "Contract Location", "IS", "Sky"),
			"Spectral is a Sky domain")
	var cath: LocationData = DataManager.locations.get("Cathistii", null) as LocationData
	_check(res, "cathistii row found", cath != null, "Locations.tsv holds Cathistii")
	if cath != null:
		run.location = cath
		_check(res, "settlement environment", _ok(a, run, "Contract Location", "IS", "Urban"),
			"Cathistii is Urban")
		_check(res, "environ placeholder", _ok(a, run, "Contract Location", "IS", "[ENVIRON]"),
			"Cathistii resolves an environment")
		a.starting_location = cath
		_check(res, "merc home exact", _ok(a, run, "Contract Location", "IS", "[MERC HOME]"),
			"the run sits on Ada's home")
		run.location = DataManager.locations.get("Aerdis", null) as LocationData
		_check(res, "merc home parent", _ok(a, run, "Contract Location", "IS", "[MERC HOME]"),
			"Aerdis holds Ada's home")
		run.location = DataManager.locations.get("Zukei", null) as LocationData
		_check(res, "merc home elsewhere",
			not _ok(a, run, "Contract Location", "IS", "[MERC HOME]"), "Zukei is not Ada's home")
	_check(res, "undercity loaded", DataManager.locations.has("Undercity"),
		"Locations.tsv holds Undercity")
	if DataManager.locations.has("Undercity"):
		var under: LocationData = DataManager.locations["Undercity"] as LocationData
		_check(res, "undercity environment", under.environment == "Urban",
			"environment is %s" % under.environment)
		_check(res, "undercity parent", under.parent != null
			and under.parent.location_name == "Aerdis", "Undercity answers to Aerdis")
	var home: Array[Dictionary] = [_req("Contract Location", "IS", "[MERC HOME]")]
	_check(res, "home placeholder supported", LifepathRequirements.is_supported(_hand(home)),
		"[MERC HOME] is a value this code answers")
	var junk: Array[Dictionary] = [_req("Contract Location", "IS", "[SOMEWHERE]")]
	_check(res, "other placeholder unsupported",
		not LifepathRequirements.is_supported(_hand(junk)), "an unknown placeholder blocks the row")


static func _case_damage_subjects(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var run := _run_for(team)
	LifepathTally.record_damage_taken(a, 3, "Fire")
	_check(res, "damage type taken", _ok(a, run, "Damage Taken", "IS", "Fire"), "3 Fire recorded")
	_check(res, "damage type contains", _ok(a, run, "Damage Type", "CONTAINS", "Fire"),
		"Fire is on the list")
	_check(res, "other damage type", not _ok(a, run, "Damage Type", "IS", "Will"),
		"no Will damage recorded")
	_check(res, "damage taken is not zero", not _ok(a, run, "Damage Taken", "IS", "0"),
		"3 is not 0")
	_check(res, "damage taken at least one", _ok(a, run, "Damage Taken", "IS >=", "1"), "3 of 1")
	_check(res, "untouched merc took none", _ok(b, run, "Damage Taken", "IS", "0"),
		"Bo took nothing")
	LifepathTally.record_damage_dealt_total(a, 9)
	_check(res, "damage dealt total", _ok(a, run, "Damage Dealt", "IS >=", "9"), "9 dealt")
	_check(res, "damage dealt bar", not _ok(a, run, "Damage Dealt", "IS >=", "10"),
		"9 is under 10")
	var c := _merc("Cai")
	var solo: Array[MercenaryData] = [c]
	var run2 := _run_for(solo)
	var c_hp: int = int(c.stats.get("maximum_hit_points", 0))
	LifepathTally.record_damage_dealt_total(c, c_hp + 1)
	_check(res, "damage dealt against a stat",
		_ok(c, run2, "Damage Dealt", "IS >=", "self.maximum_hit_points"),
		"%d dealt against max hp %d" % [c_hp + 1, c_hp])
	var e := _merc("Eli")
	e.stats["tolerance"] = 3
	LifepathTally.record_damage_taken(e, 3, "Strike")
	_check(res, "tolerance met", _ok(e, run2, "Damage Taken", "IS >=", "Tolerance"),
		"a 3 hit meets tolerance 3")
	var f := _merc("Fen")
	f.stats["tolerance"] = 3
	LifepathTally.record_damage_taken(f, 2, "Strike")
	_check(res, "tolerance missed", not _ok(f, run2, "Damage Taken", "IS >=", "Tolerance"),
		"a 2 hit misses tolerance 3")


static func _case_check_kinds(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var run := _run_for(team)
	LifepathTally.record_check(a, "resist", 0, false)
	_check(res, "resist failure reads", _ok(a, run, "Failed Check", "IS", "Resist"),
		"a failed resist is a named failure")
	_check(res, "no reroll yet", not _ok(a, run, "Reroll", "IS", "Success"),
		"nothing was rerolled")
	LifepathTally.record_check(a, "reroll", 1, true, false)
	_check(res, "reroll success reads", _ok(a, run, "Reroll", "IS", "Success"),
		"a rerolled success is recorded")
	_check(res, "reroll is not a failure", LifepathTally.failure_count(a) == 1,
		"one failure stands, got %d" % LifepathTally.failure_count(a))
	_check(res, "fresh merc has no reroll", not _ok(b, run, "Reroll", "IS", "Success"),
		"Bo rerolled nothing")
	var row: Array[Dictionary] = [_req("Reroll", "IS", "Failure")]
	_check(res, "reroll failure unsupported", not LifepathRequirements.is_supported(_hand(row)),
		"Reroll only answers Success")


#A formula event naming team.negotiate records that check for every living merc, win or lose.
static func _case_contract_check_kinds(res: Dictionary) -> void:
	_reset()
	var event := EventData.new()
	event.event_name = "TEST Parley"
	event.event_type = "Mishap"
	event.success_formula = "team.negotiate - (50.0 - (target.wile * 10.0))"
	var kinds: Array[String] = FormulaEventResolver.check_kinds(event.success_formula)
	_check(res, "formula names one kind", kinds.size() == 1 and kinds[0] == "negotiate",
		"got [%s]" % ", ".join(kinds))
	var a := _merc("Ada")
	var b := _merc("Bo")
	var team: Array[MercenaryData] = [a, b]
	var run := _run_for(team)
	for merc: MercenaryData in team:
		merc.stats["negotiate"] = 1000.0
	var won: Dictionary = FormulaEventResolver.resolve(event, run)
	_check(res, "formula event succeeds", bool(won["success"]),
		"negotiate 1000 beats any roll")
	_check(res, "negotiate success recorded",
		_ok(a, run, "Succeeded Check", "IS", "Negotiate")
		and _ok(b, run, "Succeeded Check", "IS", "Negotiate"),
		"both living mercs hold a negotiate success")
	_reset()
	var c := _merc("Cyd")
	var lost_team: Array[MercenaryData] = [c]
	var lost_run := _run_for(lost_team)
	c.stats["negotiate"] = -1000.0
	var lost: Dictionary = FormulaEventResolver.resolve(event, lost_run)
	_check(res, "formula event fails", not bool(lost["success"]),
		"negotiate -1000 loses every roll")
	_check(res, "negotiate failure recorded", _ok(c, lost_run, "Failed Check", "IS", "Negotiate"),
		"the failed group check names negotiate")
	var aoe: Array[Dictionary] = [_req("Succeeded Check", "IS", "Avoid AoE")]
	_check(res, "avoid aoe supported", LifepathRequirements.is_supported(_hand(aoe)),
		"Avoid AoE is a check kind")
	var stat_row: Array[Dictionary] = [_req("Succeeded Check", "IS", "Negotiate")]
	_check(res, "stat token supported", LifepathRequirements.is_supported(_hand(stat_row)),
		"Negotiate is a Stats.tsv name")
	var bad: Array[Dictionary] = [_req("Succeeded Check", "IS", "Nonstat")]
	_check(res, "unknown stat unsupported", not LifepathRequirements.is_supported(_hand(bad)),
		"Nonstat is neither a check kind nor a stat")


static func _case_targets(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var team: Array[MercenaryData] = [a]
	var run := _run_for(team)
	var tags: Array[String] = ["beast", "merc"]
	run.target_record = {"tags": tags, "count": 4, "speed": 30, "max_hp": 12, "failed": {}}
	_check(res, "target tag held", _ok(a, run, "Target Creature", "HAS TAG", "Beast"),
		"the target is a Beast")
	_check(res, "target tag absent", not _ok(a, run, "Target Creature", "HAS TAG", "Authority"),
		"no Authority tag")
	_check(res, "target is merc", _ok(a, run, "Target Creature", "IS", "Merc"),
		"IS reads the same list as HAS TAG")
	_check(res, "target type token", _ok(a, run, "Target Creature", "IS", "[Type]"),
		"Beast is a Types.tsv creature")
	var only: Array[String] = ["merc"]
	run.target_record = {"tags": only, "count": 1, "speed": 0, "max_hp": 0, "failed": {}}
	_check(res, "no creature type", not _ok(a, run, "Target Creature", "IS", "[Type]"),
		"merc is not a Types.tsv creature")
	var ghost := MercenaryData.new()
	ghost.merc_name = "Ghost"
	LifepathTally.record_target_check(ghost, "wile", false)
	_check(res, "target failed check", _ok(a, run, "Target Failed Check", "IS", "Wile"),
		"the target failed a Wile check")
	_check(res, "target passed check", not _ok(a, run, "Target Failed Check", "IS", "Vigor"),
		"no Vigor failure recorded")
	LifepathTally.record_target_check(a, "vigor", false)
	_check(res, "a merc is not the target", not _ok(a, run, "Target Failed Check", "IS", "Vigor"),
		"a merc with a uid never lands on the target record")
	for i: int in range(3):
		LifepathTally.record_inflicted(a, "Surprised")
	var three: Array[Dictionary] = [_req("State Inflicted", "IS", "Surprised", "AND"),
		_req("Count", "IS >=", "3")]
	_check(res, "inflicted count met", LifepathRequirements.allows(a, _hand(three), run),
		"three Surprised applied")
	var four: Array[Dictionary] = [_req("State Inflicted", "IS", "Surprised", "AND"),
		_req("Count", "IS >=", "4")]
	_check(res, "inflicted count bar", not LifepathRequirements.allows(a, _hand(four), run),
		"three is under four")
	_check(res, "count without a state", not _ok(a, run, "Count", "IS >=", "1"),
		"Count needs a State Inflicted entry before it")
	_check(res, "target rows supported", LifepathRequirements.is_supported(_hand(three)),
		"State Inflicted and Count are readable")


static func _case_stat_bonus(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var boost: LifepathData = _fake("TEST Vigor Boost", "")
	boost.stat_bonus_5pct = ["Vigor"] as Array[String]
	var before: float = float(a.stat_multipliers.get("vigor", 0.0))
	var _g: Array[String] = LifepathProgression.grant(a, "TEST Vigor Boost")
	var after: float = float(a.stat_multipliers.get("vigor", 0.0))
	_check(res, "stat bonus applied", is_equal_approx(after, before + 0.05),
		"vigor multiplier %.2f to %.2f" % [before, after])
	var record: Dictionary = a.lifepath_stat_deltas.get("TEST Vigor Boost", {}) as Dictionary
	var mult: Dictionary = record.get("mult", {}) as Dictionary
	_check(res, "stat bonus recorded", mult.has("vigor"), "the delta names vigor")
	for i: int in range(LifepathProgression.MAX_EVENTS - a.lifepaths.size()):
		a.lifepaths.append(_lp("Death Trauma"))
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	_check(res, "stat bonus reverted",
		is_equal_approx(float(a.stat_multipliers.get("vigor", 0.0)), before),
		"vigor multiplier back to %.2f" % float(a.stat_multipliers.get("vigor", 0.0)))
	_unregister(boost)


static func _case_placeholder_trait(res: Dictionary) -> void:
	_reset()
	var a := _merc("Ada")
	var column: Array = DataManager.type_columns.get("TEMPLE TRAIT", []) as Array
	_check(res, "temple column loaded", not column.is_empty(),
		"Types.tsv holds %d TEMPLE TRAIT value(s)" % column.size())
	var temple: LifepathData = _fake("TEST Temple", "[TEMPLE TRAIT]")
	var _g: Array[String] = LifepathProgression.grant(a, "TEST Temple")
	var record: Dictionary = a.lifepath_stat_deltas.get("TEST Temple", {}) as Dictionary
	var names: Array = record.get("traits", []) as Array
	_check(res, "placeholder resolved once", names.size() == 1,
		"%d resolved name(s)" % names.size())
	var resolved: String = str(names[0]) if names.size() == 1 else ""
	_check(res, "resolved name from the column", column.has(resolved), "resolved %s" % resolved)
	_check(res, "merc holds the resolved trait", _holds(a, resolved),
		"%s is on the trait list" % resolved)
	for i: int in range(LifepathProgression.MAX_EVENTS - a.lifepaths.size()):
		a.lifepaths.append(_lp("Death Trauma"))
	var _f: Array[String] = LifepathProgression.force(a, "Buddy's Passing")
	_check(res, "resolved trait removed", not _holds(a, resolved), "%s is gone" % resolved)
	_unregister(temple)


static func _case_payoff_placeholder(res: Dictionary) -> void:
	_reset()
	var column: Array = DataManager.type_columns.get("PACT BEING", []) as Array
	var variants: Array[String] = MercGenerator.placeholder_variants("Pact of the [PACT BEING]")
	_check(res, "variant count matches the column", variants.size() == column.size(),
		"%d variant(s) for %d PACT BEING value(s)" % [variants.size(), column.size()])
	var prefixed: bool = not variants.is_empty()
	for variant: String in variants:
		if not variant.begins_with("Pact of the "):
			prefixed = false
	_check(res, "variants keep the literal text", prefixed,
		"every variant reads Pact of the <value>")
	var plain: Array[String] = MercGenerator.placeholder_variants("Awkward")
	_check(res, "plain name returns itself", plain.size() == 1 and plain[0] == "Awkward",
		"Awkward expands to %d name(s)" % plain.size())
	_check(res, "unknown column returns nothing",
		MercGenerator.placeholder_variants("[NO SUCH COLUMN ZZ]").is_empty(),
		"a missing Types.tsv column yields no variant")
	var pact: LifepathData = _lp("Pact")
	var steady: bool = pact != null
	for i: int in range(30):
		if not LifepathProgression.has_payoff(pact):
			steady = false
	_check(res, "placeholder payoff is deterministic", steady,
		"Pact pays off on 30 consecutive calls")
	var vow := LifepathData.new()
	vow.event_type = "Experienced"
	vow.event_name = "TEST Vow Payoff"
	vow.perks = ["[VOW]"] as Array[String]
	_check(res, "vow placeholder pays off", LifepathProgression.has_payoff(vow),
		"a [VOW] perk finds a variant with a DSL cell")
	var dud := LifepathData.new()
	dud.event_type = "Experienced"
	dud.event_name = "TEST No Payoff"
	dud.perks = ["No Such Trait Zz"] as Array[String]
	_check(res, "missing trait has no payoff", not LifepathProgression.has_payoff(dud),
		"an unknown trait name grants no payoff")


static func _case_apply_effect(res: Dictionary) -> void:
	_reset()
	TraitRuntime.clear_all()
	var a := _merc("Ada")
	var td := TraitData.new()
	td.trait_name = "TEST Apply Fatigue"
	td.trait_type = "Perk"
	td.effect_dsl = "on:state_gained:poisoned:always:apply:fatigued"
	a.perks.append(td)
	TraitRuntime.fire("state_gained:poisoned", a, {})
	_check(res, "apply sets the state", ConstStates.has_state(a, ConstStates.FATIGUED),
		"apply: put Fatigued on Ada with no resist roll")
	var b := _merc("Bo")
	TraitRuntime.fire("state_gained:poisoned", b, {})
	_check(res, "no trait no state", not ConstStates.has_state(b, ConstStates.FATIGUED),
		"Bo carries no apply: clause")
	TraitRuntime.clear_all()


static func _case_location_condition(res: Dictionary) -> void:
	_reset()
	TraitRuntime.clear_all()
	var a := _merc("Ada")
	var td := TraitData.new()
	td.trait_name = "TEST Urban Toll"
	td.trait_type = "Perk"
	td.effect_dsl = "on:contract_start:location:urban:resource:hp:-1"
	a.perks.append(td)
	var team: Array[MercenaryData] = [a]
	var urban := _run_for(team)
	urban.location = DataManager.locations.get("Cathistii", null) as LocationData
	var before: int = a.current_hp
	TraitRuntime.begin_contract(urban)
	_check(res, "environment condition fires", a.current_hp == before - 1,
		"hp %d to %d in an Urban settlement" % [before, a.current_hp])
	var forest := _run_for(team)
	forest.location = DataManager.locations.get("Zukei", null) as LocationData
	var held: int = a.current_hp
	TraitRuntime.begin_contract(forest)
	_check(res, "other environment holds", a.current_hp == held,
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


#Prints one AUDIT line per Lifepaths.tsv event so a report can be built from the code, not the sheet.
static func audit_full() -> void:
	var groups: Array = []
	for name: String in DataManager.starting_lifepaths:
		groups.append(DataManager.starting_lifepaths[name])
	for cat: String in DataManager.lifepaths_by_category:
		for lp in DataManager.lifepaths_by_category[cat]:
			groups.append(lp)
	for entry in groups:
		var lp: LifepathData = entry as LifepathData
		if lp == null:
			continue
		var reqs: Array[String] = []
		var bad: Array[String] = []
		for r: Dictionary in lp.requirements:
			var subject: String = str(r.get("subject", ""))
			var op: String = str(r.get("op", ""))
			var value: String = str(r.get("value", ""))
			reqs.append("%s [%s] %s%s" % [subject, op, value, (" " + str(r.get("conj", ""))) if str(r.get("conj", "")) != "" else ""])
			if not LifepathRequirements.SUBJECTS.has(subject):
				bad.append("subject:" + subject)
			elif op.strip_edges() == "" and value.strip_edges() == "":
				continue
			elif not LifepathRequirements._value_supported(subject,
					"IS" if op.strip_edges() == "" else op, value):
				bad.append("value:" + subject + "=" + value)
		var cells: Array[String] = []
		for trait_name: String in lp.perks + lp.drawbacks:
			var td: TraitData = MercGenerator._lookup_trait(trait_name)
			var kind := "MISSING"
			if td != null:
				if td.effect_dsl == "":
					kind = "EMPTY"
				elif td.effect_dsl.begins_with("SPECIAL:"):
					kind = "SPECIAL"
				elif td.effect_dsl.contains("SPECIAL:"):
					kind = "MIXED"
				else:
					kind = "DSL"
			cells.append("%s=%s" % [trait_name, kind])
		var allows_no_run: bool = LifepathRequirements.allows(null, lp, null) if lp.requirements.is_empty() else _allows_safe(lp)
		print("AUDIT	%s	%s	%s	%s	%s	%s	%s	%d	%d	%d	%s" % [lp.event_type, lp.event_name, lp.rarity,
			"; ".join(lp.perks), "; ".join(lp.drawbacks), "; ".join(reqs), "; ".join(bad),
			1 if LifepathRequirements.is_supported(lp) else 0, 1 if LifepathProgression.has_payoff(lp) else 0,
			1 if allows_no_run else 0, "; ".join(cells)])


#Generation filters with no run; a fresh merc stands in so subjects that need a run report what they return.
static func _allows_safe(lp: LifepathData) -> bool:
	var probe := _merc("Probe")
	return LifepathRequirements.allows(probe, lp, null)
