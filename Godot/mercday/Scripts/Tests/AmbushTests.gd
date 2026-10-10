class_name AmbushTests
#Run: godot --headless --path . -- --ambush-tests
#The wilderness Respite ambush: Trigger cell, luck roll, bandit crew and the Leadership aura.

const AMBUSH := "Ambush"
#The other wilderness Trigger row; spent first so a pick that must be the Ambush has one candidate.
const KIDNAP := "Kidnapping"
const LEADER_PREFIX := "Bandit Leader "
const LE_FORMULA := "min(8, 1 + floor(npc.level / 5))"
#Curse rows carry no requirement and no payload, so an eLE pool of them draws the same way every run.
const CURSE_POOL: Array[String] = ["Curse of Aging", "Curse of Bards", "Curse of Certainty"]


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_reset_statics()
	_case_trigger_column(res)
	_case_pools_exclude(res)
	_case_wilderness(res)
	_case_chance(res)
	_case_escalation(res)
	_case_one_per_contract(res)
	_case_forced_pick(res)
	_case_contract_type(res)
	_case_blank_row(res)
	_case_crew_size(res)
	_case_crew(res)
	_case_level_bounds(res)
	_case_ammo_cap(res)
	_case_aura_range(res)
	_case_aura_senses(res)
	_case_aura_source_lost(res)
	_case_target_preference(res)
	_case_le_count_formula(res)
	_case_randf_arithmetic(res)
	_case_randf_independence(res)
	_case_lifepath_slot_count(res)
	_case_ele_any_pool(res)
	_case_leader_lifepaths(res)
	_reset_statics()
	return TestFixtures.summarize(res, "AMBUSH")


static func _reset_statics() -> void:
	EventTrigger.forced_d100 = -1
	EventTrigger.missed_respites = 0
	EventTrigger.last_line = ""
	CheckSystem.forced_rolls.clear()
	var config: ContractConfig = ContractLibrary.config()
	if config != null:
		config.force_trigger_event = ""


#A merc with no gear, so the weapon branches of the auto states never run.
static func _merc(name: String, luck: float) -> MercenaryData:
	return TestFixtures.fixed_merc(name, {"luck": luck})


static func _leader(name: String) -> MercenaryData:
	var m := _merc(name, 40.0)
	m.auras.append({"state": ConstStates.EMBOLDENED, "paces": 5,
		"gate": "sight_or_hearing", "source": "Leadership"})
	return m


#A child location with no Environment cell of its own, so the parent chain answers for it.
static func _child_of(parent: LocationData, type_name: String) -> LocationData:
	var loc := LocationData.new()
	loc.location_name = "Test Reach"
	loc.location_type = type_name
	loc.environment = ""
	loc.parent = parent
	return loc


static func _event_row(name: String) -> Dictionary:
	for row: Dictionary in DataManager.event_rows:
		if String(row.get("Event Name", "")).strip_edges() == name:
			return row
	return {}


static func _ammo_total(merc: MercenaryData) -> int:
	var total: int = merc.ammo_loaded
	for key: String in merc.ammo_inventory.keys():
		total += int(merc.ammo_inventory[key])
	return total


static func _le_count(level: int) -> int:
	return NPCGenerator._eval_le_count(LE_FORMULA, {"npc_level": level})


#A stripped template: no gear and no tradition, so only the lifepath step moves.
static func _lifepath_template(sle: String, le_count: String, pool: Array[String]) -> NPCTemplate:
	var t := NPCTemplate.new()
	t.npc_type = "Test Bandit"
	t.name_mode = "Random First"
	t.ancestry_any = true
	t.heritage_any = true
	t.tradition_none = true
	t.level_formula = "5"
	t.sle_name = sle
	t.ele_pool = pool
	t.le_count_str = le_count
	return t


#A bare merc for the lifepath step alone, so no trait grant can inflate the held count.
static func _lifepath_merc(level: int) -> MercenaryData:
	var m: MercenaryData = _merc("Bandit Probe", 40.0)
	m.stats["level"] = float(level)
	return m


static func _starting_held(merc: MercenaryData) -> int:
	var total: int = 0
	for lp: LifepathData in merc.lifepaths:
		if lp.event_type == "Starting":
			total += 1
	return total


static func _has_placeholder(lp: LifepathData) -> bool:
	for entry: String in lp.perks:
		if "[" in entry:
			return true
	for entry: String in lp.drawbacks:
		if "[" in entry:
			return true
	return false


static func _case_trigger_column(res: Dictionary) -> void:
	var row: Dictionary = _event_row(AMBUSH)
	TestFixtures.check(res, "Events.tsv holds an Ambush row", not row.is_empty(),
		"%d event rows loaded" % DataManager.event_rows.size())
	if row.is_empty():
		return
	TestFixtures.check(res, "the row carries a Trigger cell",
		String(row.get("Trigger", "")).strip_edges() == "respite:wilderness",
		"Trigger '%s'" % String(row.get("Trigger", "")))
	var built: EventData = ContractResourceBuilder.build_event(row)
	TestFixtures.check(res, "build_event reads the Trigger cell", built.trigger == "respite:wilderness",
		"trigger '%s'" % built.trigger)
	var fresh := EventData.new()
	TestFixtures.check(res, "EventData defaults to no trigger", fresh.trigger == "",
		"trigger '%s'" % fresh.trigger)
	var ambush: EventData = ContractLibrary.event(AMBUSH)
	TestFixtures.check(res, "the built Ambush resource keeps its trigger",
		ambush != null and ambush.trigger == "respite:wilderness",
		"trigger '%s'" % ("<missing>" if ambush == null else ambush.trigger))
	var brawl: EventData = ContractLibrary.event("Tavern Brawl")
	TestFixtures.check(res, "a pooled mishap has a blank trigger",
		brawl != null and brawl.trigger == "",
		"trigger '%s'" % ("<missing>" if brawl == null else brawl.trigger))


static func _case_pools_exclude(res: Dictionary) -> void:
	var names: Array[String] = ContractLibrary.contract_type_names()
	var offenders: Array[String] = []
	for type_name: String in names:
		var c: ContractData = ContractLibrary.contract_type(type_name)
		if c == null:
			continue
		if c.mishap_pool.has(AMBUSH) or c.primary_event_pool.has(AMBUSH):
			offenders.append(type_name)
	TestFixtures.check(res, "a triggered event reaches no contract pool",
		not names.is_empty() and offenders.is_empty(),
		"%d contracts, offenders %s" % [names.size(),
			"none" if offenders.is_empty() else ", ".join(offenders)])
	var military: ContractData = ContractLibrary.contract_type("Military")
	TestFixtures.check(res, "an untriggered mishap still pools",
		military != null and military.mishap_pool.has("Tavern Brawl"),
		"Military mishaps %s" % ("<missing>" if military == null else str(military.mishap_pool)))


static func _case_wilderness(res: Dictionary) -> void:
	var town: LocationData = ContractFixtures.location("Cathistii")
	var country: LocationData = ContractFixtures.location("Aerdis")
	var sea: LocationData = ContractFixtures.location("Gledd Sea")
	if town == null or country == null or sea == null:
		TestFixtures.check(res, "wilderness classification", false, "Locations.tsv rows did not load")
		return
	TestFixtures.check(res, "a Settlement is never wilderness", not EventTrigger.is_wilderness(town),
		"%s type %s env %s" % [town.location_name, town.location_type, town.environment])
	TestFixtures.check(res, "a Country outside a town is wilderness", EventTrigger.is_wilderness(country),
		"%s type %s env %s" % [country.location_name, country.location_type, country.environment])
	TestFixtures.check(res, "a sea Area is wilderness", EventTrigger.is_wilderness(sea),
		"%s type %s env %s" % [sea.location_name, sea.location_type, sea.environment])
	TestFixtures.check(res, "a missing location is not wilderness", not EventTrigger.is_wilderness(null),
		"null location")
	var urban_child: LocationData = _child_of(town, "Area")
	TestFixtures.check(res, "a blank Environment takes the Urban parent",
		not EventTrigger.is_wilderness(urban_child),
		"parent %s resolves to '%s'" % [town.location_name,
			LifepathRequirements.environment_of(urban_child)])
	var wild_child: LocationData = _child_of(country, "Area")
	TestFixtures.check(res, "a blank Environment takes a wild parent",
		EventTrigger.is_wilderness(wild_child),
		"parent %s resolves to '%s'" % [country.location_name,
			LifepathRequirements.environment_of(wild_child)])


static func _case_chance(res: Dictionary) -> void:
	_reset_statics()
	var team: Array[MercenaryData] = [_merc("Scout", 40.0)]
	TestFixtures.check(res, "Luck buys the base chance down",
		is_equal_approx(EventTrigger.chance(team), 15.0),
		"chance %.1f at Luck 40" % EventTrigger.chance(team))
	EventTrigger.missed_respites = 3
	TestFixtures.check(res, "three quiet Respites add 15 points",
		is_equal_approx(EventTrigger.chance(team), 30.0),
		"chance %.1f at streak 3" % EventTrigger.chance(team))
	EventTrigger.missed_respites = 0
	var lucky: Array[MercenaryData] = [_merc("Fortunate", 400.0)]
	TestFixtures.check(res, "the floor holds at 5 percent",
		is_equal_approx(EventTrigger.chance(lucky), 5.0),
		"chance %.1f at Luck 400" % EventTrigger.chance(lucky))
	EventTrigger.missed_respites = 40
	TestFixtures.check(res, "the ceiling holds at 100 percent",
		is_equal_approx(EventTrigger.chance(team), 100.0),
		"chance %.1f at streak 40" % EventTrigger.chance(team))
	_reset_statics()


static func _case_escalation(res: Dictionary) -> void:
	_reset_statics()
	var team: Array[MercenaryData] = [_merc("Scout", 40.0)]
	var contract_run: ContractRun = ContractFixtures.run_at(team, "Aerdis")
	contract_run.triggered_events.append(KIDNAP)
	EventTrigger.forced_d100 = 100
	var miss: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, contract_run)
	TestFixtures.check(res, "a failed roll springs nothing and counts the miss",
		miss == null and EventTrigger.missed_respites == 1,
		"event %s, streak %d" % [ContractFixtures.event_name(miss), EventTrigger.missed_respites])
	EventTrigger.forced_d100 = 100
	EventTrigger.pick(RestSystem.KIND_RESPITE, contract_run)
	TestFixtures.check(res, "each miss adds 5 points to the chance",
		EventTrigger.missed_respites == 2 and is_equal_approx(EventTrigger.chance(team), 25.0),
		"chance %.1f at streak %d" % [EventTrigger.chance(team), EventTrigger.missed_respites])
	EventTrigger.forced_d100 = 1
	var fired: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, contract_run)
	TestFixtures.check(res, "a passed roll springs the Ambush and clears the streak",
		fired != null and fired.event_name == AMBUSH and EventTrigger.missed_respites == 0,
		"event %s, streak %d" % [ContractFixtures.event_name(fired), EventTrigger.missed_respites])
	TestFixtures.check(res, "the firing roll prints its line",
		EventTrigger.last_line.begins_with("AMBUSH ROLL: d100 1 "),
		"line '%s'" % EventTrigger.last_line)
	EventTrigger.forced_d100 = 1
	var breather: EventData = EventTrigger.pick(RestSystem.KIND_BREATHER, contract_run)
	TestFixtures.check(res, "a Breather is never ambushed", breather == null,
		"event %s" % ContractFixtures.event_name(breather))
	_reset_statics()


static func _case_one_per_contract(res: Dictionary) -> void:
	_reset_statics()
	var team: Array[MercenaryData] = [_merc("Scout", 40.0)]
	var contract_run: ContractRun = ContractFixtures.run_at(team, "Aerdis")
	contract_run.triggered_events.append(AMBUSH)
	contract_run.triggered_events.append(KIDNAP)
	EventTrigger.forced_d100 = 1
	var again: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, contract_run)
	TestFixtures.check(res, "one ambush per contract", again == null,
		"event %s after %s" % [ContractFixtures.event_name(again), str(contract_run.triggered_events)])
	_reset_statics()
	var town_run: ContractRun = ContractFixtures.run_at(team, "Cathistii")
	EventTrigger.forced_d100 = 1
	var in_town: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, town_run)
	TestFixtures.check(res, "a settlement Respite is not ambushed",
		in_town == null and EventTrigger.missed_respites == 0,
		"event %s, streak %d" % [ContractFixtures.event_name(in_town), EventTrigger.missed_respites])
	_reset_statics()


static func _case_forced_pick(res: Dictionary) -> void:
	_reset_statics()
	var config: ContractConfig = ContractLibrary.config()
	config.force_trigger_event = AMBUSH
	EventTrigger.missed_respites = 4
	var team: Array[MercenaryData] = [_merc("Fortunate", 400.0)]
	var town_run: ContractRun = ContractFixtures.run_at(team, "Cathistii")
	var forced: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, town_run)
	TestFixtures.check(res, "the forced event skips the place test and the roll",
		forced != null and forced.event_name == AMBUSH and EventTrigger.missed_respites == 0,
		"event %s, streak %d" % [ContractFixtures.event_name(forced), EventTrigger.missed_respites])
	town_run.triggered_events.append(AMBUSH)
	var twice: EventData = EventTrigger.pick(RestSystem.KIND_RESPITE, town_run)
	TestFixtures.check(res, "the forced event still fires only once", twice == null,
		"event %s" % ContractFixtures.event_name(twice))
	_reset_statics()


static func _typed_run(contract_type: String, local: bool) -> ContractRun:
	var team: Array[MercenaryData] = [_merc("Scout", 40.0)]
	var contract_run: ContractRun = ContractFixtures.run_at(team, "Aerdis")
	contract_run.contract = ContractData.new()
	contract_run.contract.contract_type = contract_type
	contract_run.contract.local = local
	return contract_run


#Cards 467 and 736: a trigger row answers only the contract types it lists (blank lists all); a Local run never rolls.
static func _case_contract_type(res: Dictionary) -> void:
	_reset_statics()
	var kind: String = RestSystem.KIND_RESPITE
	var help_run: ContractRun = _typed_run("Help", false)
	var help_list: Array[EventData] = EventTrigger._candidates(kind, help_run)
	EventTrigger.forced_d100 = 1
	var help_pick: EventData = EventTrigger.pick(kind, help_run)
	TestFixtures.check(res, "trig:help_no_candidates", help_list.is_empty() and help_pick == null
		and EventTrigger.last_line == "" and EventTrigger.missed_respites == 0,
		"candidates %d event %s" % [help_list.size(), ContractFixtures.event_name(help_pick)])
	var open_event := EventData.new()
	open_event.event_name = "TEST Open Trigger"
	TestFixtures.check(res, "trig:blank_types_any", EventTrigger.type_allowed(open_event, help_run)
		and EventTrigger.type_allowed(open_event, _typed_run("Military", false)), "blank cell refused a type")
	var military_list: Array[EventData] = EventTrigger._candidates(kind, _typed_run("Military", false))
	var names: Array[String] = []
	for event: EventData in military_list:
		names.append(event.event_name)
	TestFixtures.check(res, "trig:listed_type_candidate", names.has(AMBUSH) and names.has(KIDNAP),
		"candidates %s" % str(names))
	_reset_statics()
	EventTrigger.missed_respites = 3
	EventTrigger.forced_d100 = 1
	var local_pick: EventData = EventTrigger.pick(kind, _typed_run("Military", true))
	TestFixtures.check(res, "trig:local_no_roll", local_pick == null and EventTrigger.missed_respites == 3
		and EventTrigger.last_line == "", "event %s streak %d" % [ContractFixtures.event_name(local_pick),
			EventTrigger.missed_respites])
	_reset_statics()


#A stub Trigger row read through _candidates: a blank Possible Contracts cell answers a Help run, a listed type does not.
static func _case_blank_row(res: Dictionary) -> void:
	_reset_statics()
	var name: String = "TEST Open Trigger Row"
	var row: Dictionary = {"Event Name": name, "Trigger": "respite:wilderness"}
	var path: String = ContractResourceBuilder.event_path(name)
	DataManager.event_rows.append(row)
	_save_trigger_stub(name, path, [])
	var help_run: ContractRun = _typed_run("Help", false)
	TestFixtures.check(res, "trig:blank_row_candidate", _candidate_names(help_run).has(name),
		"candidates %s" % str(_candidate_names(help_run)))
	_save_trigger_stub(name, path, ["Military"])
	TestFixtures.check(res, "trig:listed_row_excluded", not _candidate_names(help_run).has(name),
		"candidates %s" % str(_candidate_names(help_run)))
	DataManager.event_rows.erase(row)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_reset_statics()


static func _save_trigger_stub(name: String, path: String, types: Array[String]) -> void:
	var e := EventData.new()
	e.event_name = name
	e.event_type = "Mishap"
	e.trigger = "respite:wilderness"
	e.possible_contracts = types
	ResourceTextWriter.save(e, path, "EventData", ContractResourceBuilder.EVENT_SCRIPT)


static func _candidate_names(contract_run: ContractRun) -> Array[String]:
	var names: Array[String] = []
	for event: EventData in EventTrigger._candidates(RestSystem.KIND_RESPITE, contract_run):
		names.append(event.event_name)
	return names


static func _case_crew_size(res: Dictionary) -> void:
	var d1: float = OpponentGenerator.difficulty_factor(1.0)
	var d3: float = OpponentGenerator.difficulty_factor(3.0)
	var d5: float = OpponentGenerator.difficulty_factor(5.0)
	TestFixtures.check(res, "difficulty_factor spans 0.5 to 2.0",
		is_equal_approx(d1, 0.5) and is_equal_approx(d3, 1.25) and is_equal_approx(d5, 2.0),
		"D1 %.4f D3 %.4f D5 %.4f" % [d1, d3, d5])
	var ambush: EventData = ContractLibrary.event(AMBUSH)
	if ambush == null:
		TestFixtures.check(res, "crew size at difficulty 1, 3 and 5", false, "Ambush event did not load")
		return
	var expr: String = ambush.enemy_counter
	var n1: int = OpponentGenerator.eval_count(expr, {"merc_count": 4, "average_level": 6.0, "difficulty": 1.0})
	var n3: int = OpponentGenerator.eval_count(expr, {"merc_count": 4, "average_level": 6.0, "difficulty": 3.0})
	var n5: int = OpponentGenerator.eval_count(expr, {"merc_count": 4, "average_level": 6.0, "difficulty": 5.0})
	TestFixtures.check(res, "crew size at difficulty 1, 3 and 5", n1 == 2 and n3 == 5 and n5 == 8,
		"a party of 4 faces %d, %d and %d" % [n1, n3, n5])
	var small: int = OpponentGenerator.eval_count(expr,
		{"merc_count": 2, "average_level": 6.0, "difficulty": 1.0})
	TestFixtures.check(res, "the crew never drops below two", small == 2,
		"a party of 2 at difficulty 1 faces %d" % small)


static func _case_crew(res: Dictionary) -> void:
	var ambush: EventData = ContractLibrary.event(AMBUSH)
	if ambush == null:
		TestFixtures.check(res, "ambush crew", false, "Ambush event did not load")
		return
	var req := OpponentRequest.new()
	req.source = ambush.enemy
	req.count = 5
	req.extra_ctx = {"merc_count": 4, "average_level": 6.0, "difficulty": 3.0,
		"difficulty_factor": 1.25}
	req.tag = AMBUSH
	var crew: Array[MercenaryData] = OpponentGenerator.generate(req)
	TestFixtures.check(res, "the crew fills the counted size", crew.size() == 5, "crew %d" % crew.size())
	if crew.size() < 2:
		return
	var leaders: int = 0
	var aura_bearers: int = 0
	var roster: Array[String] = []
	for m: MercenaryData in crew:
		if m.merc_name.begins_with(LEADER_PREFIX):
			leaders += 1
		if not m.auras.is_empty():
			aura_bearers += 1
		roster.append("%s L%d" % [m.merc_name, int(m.stats.get("level", 0))])
	TestFixtures.check(res, "a crew holds exactly one Bandit Leader", leaders == 1,
		"%d leaders in %s" % [leaders, ", ".join(roster)])
	TestFixtures.check(res, "only the leader carries the aura",
		aura_bearers == 1 and not crew[0].auras.is_empty()
		and crew[0].merc_name.begins_with(LEADER_PREFIX),
		"%d aura bearers, first is %s" % [aura_bearers, crew[0].merc_name])
	var total: float = 0.0
	for i: int in range(1, crew.size()):
		total += float(crew[i].stats.get("level", 0.0))
	var mean: float = total / float(crew.size() - 1)
	var lead_level: int = int(crew[0].stats.get("level", 0))
	TestFixtures.check(res, "the leader outranks the crew mean by a tenth",
		float(lead_level) >= ceilf(mean * 1.1),
		"leader L%d against a crew mean of %.2f" % [lead_level, mean])
	var aura: Dictionary = crew[0].auras[0] if not crew[0].auras.is_empty() else {}
	TestFixtures.check(res, "Leadership reads as a 5 pace Emboldened aura",
		String(aura.get("state", "")) == ConstStates.EMBOLDENED and int(aura.get("paces", 0)) == 5
		and String(aura.get("gate", "")) == "sight_or_hearing", "aura %s" % str(aura))


#Lowest (x) and highest (y) level the formula rolls over the given number of rolls.
static func _level_span(formula: String, ctx: Dictionary, rolls: int) -> Vector2i:
	var span := Vector2i(9999, 0)
	for _i: int in range(rolls):
		var lvl: int = OpponentGenerator.eval_level(formula, ctx)
		span = Vector2i(mini(span.x, lvl), maxi(span.y, lvl))
	return span


static func _case_level_bounds(res: Dictionary) -> void:
	var template: NPCTemplate = DataManager.npc_templates.get("Bandit Melee", null) as NPCTemplate
	if template == null:
		TestFixtures.check(res, "bandit level bounds", false, "Bandit Melee template did not load")
		return
	var ctx: Dictionary = {"average_level": 6.0, "merc_count": 4, "difficulty": 3.0}
	var span: Vector2i = _level_span(template.level_formula, ctx, 200)
	TestFixtures.check(res, "bandit level stays inside the difficulty 3 band, half to 1.5x the party average",
		span.x >= 3 and span.y <= 9, "%d to %d over 200 rolls against an average of 6" % [span.x, span.y])
	var hard_ctx: Dictionary = {"average_level": 6.0, "merc_count": 4, "difficulty": 5.0}
	var hard: Vector2i = _level_span(template.level_formula, hard_ctx, 200)
	TestFixtures.check(res, "difficulty 5 bandits reach the top of the 1x to 2x band",
		hard.x >= 6 and hard.y <= 12 and hard.y >= 10,
		"%d to %d over 200 rolls against an average of 6" % [hard.x, hard.y])
	var floor_ctx: Dictionary = {"average_level": 0.0, "merc_count": 4, "difficulty": 3.0}
	var floor_low: int = _level_span(template.level_formula, floor_ctx, 50).x
	TestFixtures.check(res, "the clamp never drops a bandit below level 1", floor_low >= 1,
		"lowest %d over 50 rolls against an average of 0" % floor_low)


static func _case_ammo_cap(res: Dictionary) -> void:
	var template: NPCTemplate = DataManager.npc_templates.get("Bandit Ranged", null) as NPCTemplate
	if template == null:
		TestFixtures.check(res, "bandit ammo cap", false, "Bandit Ranged template did not load")
		return
	TestFixtures.check(res, "the Bandit Ranged template caps at 10 rounds", template.max_ammo == 10,
		"max_ammo %d" % template.max_ammo)
	var ctx: Dictionary = {"average_level": 6.0, "merc_count": 4, "difficulty_factor": 1.25}
	var bandit: MercenaryData = NPCGenerator.generate(template, ctx)
	TestFixtures.check(res, "the cap rides on the generated bandit",
		bandit.max_ammo == 10 and _ammo_total(bandit) <= 10,
		"max_ammo %d, carrying %d" % [bandit.max_ammo, _ammo_total(bandit)])
	BattleState._reset_starting_ammo(bandit)
	var carried: int = _ammo_total(bandit)
	TestFixtures.check(res, "the battle re-roll honours the cap of 10", carried <= 10,
		"%d rounds after the re-roll" % carried)
	bandit.max_ammo = 3
	BattleState._reset_starting_ammo(bandit)
	var trimmed: int = _ammo_total(bandit)
	TestFixtures.check(res, "a tighter cap trims the re-rolled bundle", trimmed <= 3,
		"%d rounds under a cap of 3" % trimmed)


static func _case_aura_range(res: Dictionary) -> void:
	var leader: MercenaryData = _leader("Bandit Leader Reach")
	var grunt: MercenaryData = _merc("Bandit Melee Reach", 40.0)
	var watcher: MercenaryData = _merc("Merc Watcher", 40.0)
	var crew: Array[MercenaryData] = [leader, grunt]
	var foes: Array[MercenaryData] = [watcher]
	var st: BattleState = TestFixtures.battle_state(crew, foes)
	TestFixtures.place(st, leader, Vector2i(5, 5))
	TestFixtures.place(st, grunt, Vector2i(5, 9))
	TestFixtures.place(st, watcher, Vector2i(20, 20))
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "an ally inside 5 Paces is Emboldened",
		ConstStates.has_state(grunt, ConstStates.EMBOLDENED),
		"distance %d" % st.distance_to(grunt, leader))
	BattleStateUpdater.update_auto_states(leader, st)
	TestFixtures.check(res, "the source is not Emboldened by its own aura",
		not ConstStates.has_state(leader, ConstStates.EMBOLDENED),
		"the leader carries %d aura entries" % leader.auras.size())
	TestFixtures.place(st, grunt, Vector2i(5, 12))
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "the aura stops at its radius",
		not ConstStates.has_state(grunt, ConstStates.EMBOLDENED),
		"distance %d" % st.distance_to(grunt, leader))


static func _case_aura_senses(res: Dictionary) -> void:
	var leader: MercenaryData = _leader("Bandit Leader Sense")
	var grunt: MercenaryData = _merc("Bandit Melee Sense", 40.0)
	var watcher: MercenaryData = _merc("Merc Listener", 40.0)
	var crew: Array[MercenaryData] = [leader, grunt]
	var foes: Array[MercenaryData] = [watcher]
	var st: BattleState = TestFixtures.battle_state(crew, foes)
	#Orthogonally adjacent, so the sight half of the gate needs no obstacle-free ray to be argued.
	TestFixtures.place(st, leader, Vector2i(5, 5))
	TestFixtures.place(st, grunt, Vector2i(5, 6))
	TestFixtures.place(st, watcher, Vector2i(20, 20))
	StateCascade.apply_state(grunt, ConstStates.BLINDED)
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "a blinded ally still hears the leader",
		ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "Blinded alone")
	StateCascade.remove_state(grunt, ConstStates.BLINDED)
	StateCascade.apply_state(grunt, ConstStates.DEAFENED)
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "a deafened ally still sees the leader",
		ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "Deafened alone")
	StateCascade.apply_state(grunt, ConstStates.BLINDED)
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "losing both senses denies the aura",
		not ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "Blinded and Deafened together")
	StateCascade.remove_state(grunt, ConstStates.BLINDED)
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "one restored sense brings the aura back",
		ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "Deafened alone again")
	StateCascade.remove_state(grunt, ConstStates.DEAFENED)


static func _case_aura_source_lost(res: Dictionary) -> void:
	var leader: MercenaryData = _leader("Bandit Leader Fallen")
	var grunt: MercenaryData = _merc("Bandit Melee Fallen", 40.0)
	var watcher: MercenaryData = _merc("Merc Killer", 40.0)
	var crew: Array[MercenaryData] = [leader, grunt]
	var foes: Array[MercenaryData] = [watcher]
	var st: BattleState = TestFixtures.battle_state(crew, foes)
	TestFixtures.place(st, leader, Vector2i(5, 5))
	TestFixtures.place(st, grunt, Vector2i(5, 8))
	TestFixtures.place(st, watcher, Vector2i(20, 20))
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "the aura holds while the leader stands",
		ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "leader at full health")
	StateCascade.apply_state(leader, ConstStates.DYING)
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "a dying leader projects nothing",
		not ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "leader is Dying")
	StateCascade.remove_state(leader, ConstStates.DYING)
	StateCascade.remove_state(leader, ConstStates.UNCONSCIOUS)
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "the aura returns when the leader recovers",
		ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "leader is standing again")
	leader.is_dead = true
	BattleStateUpdater.update_auto_states(grunt, st)
	TestFixtures.check(res, "the aura drops when the leader dies",
		not ConstStates.has_state(grunt, ConstStates.EMBOLDENED), "leader is dead")


static func _case_target_preference(res: Dictionary) -> void:
	var hunter: MercenaryData = _merc("Merc Hunter", 40.0)
	var leader: MercenaryData = _leader("Bandit Leader Mark")
	var plain: MercenaryData = _merc("Bandit Melee Mark", 40.0)
	var side_a: Array[MercenaryData] = [hunter]
	var side_b: Array[MercenaryData] = [leader, plain]
	var st: BattleState = TestFixtures.battle_state(side_a, side_b)
	#Equal range on opposite sides, so the only weight that separates the two is the aura.
	TestFixtures.place(st, hunter, Vector2i(5, 5))
	TestFixtures.place(st, leader, Vector2i(5, 2))
	TestFixtures.place(st, plain, Vector2i(5, 8))
	var lead_bonus: float = AuraTactics.leader_bonus(leader, st)
	var plain_bonus: float = AuraTactics.leader_bonus(plain, st)
	TestFixtures.check(res, "only an aura source scores the leader bonus",
		is_equal_approx(lead_bonus, 0.5) and is_equal_approx(plain_bonus, 0.0),
		"leader %.2f, follower %.2f" % [lead_bonus, plain_bonus])
	var enemies: Array[MercenaryData] = [leader, plain]
	var picked: int = 0
	for _i: int in range(400):
		if TargetSelector.pick_target(hunter, enemies, st) == leader:
			picked += 1
	TestFixtures.check(res, "TargetSelector prefers the aura source", picked > 400 - picked,
		"leader picked %d of 400 against an equal target at equal range" % picked)
	StateCascade.apply_state(plain, ConstStates.EMBOLDENED)
	TestFixtures.check(res, "a held follower raises the leader bonus",
		is_equal_approx(AuraTactics.leader_bonus(leader, st), 0.65),
		"bonus %.2f with one follower held" % AuraTactics.leader_bonus(leader, st))
	var deny_lead: float = AuraTactics.sense_denial_value(leader, st)
	var deny_plain: float = AuraTactics.sense_denial_value(plain, st)
	TestFixtures.check(res, "sense denial is worth more against the source", deny_lead > deny_plain,
		"leader %.2f, follower %.2f" % [deny_lead, deny_plain])
	StateCascade.remove_state(plain, ConstStates.EMBOLDENED)


static func _case_le_count_formula(res: Dictionary) -> void:
	var steps: Dictionary = {4: 1, 5: 2, 9: 2, 14: 3}
	var step_got: Array[String] = []
	var step_ok: bool = true
	for level: int in steps:
		var got: int = _le_count(level)
		step_got.append("L%d->%d" % [level, got])
		if got != int(steps[level]):
			step_ok = false
	TestFixtures.check(res, "the LE# formula opens a slot every fifth level", step_ok,
		"wanted L4->1 L5->2 L9->2 L14->3, got %s" % ", ".join(step_got))
	var caps: Dictionary = {39: 8, 40: 8, 99: 8}
	var cap_got: Array[String] = []
	var cap_ok: bool = true
	for capped_level: int in caps:
		var capped: int = _le_count(capped_level)
		cap_got.append("L%d->%d" % [capped_level, capped])
		if capped != int(caps[capped_level]):
			cap_ok = false
	TestFixtures.check(res, "the LE# formula caps at eight slots", cap_ok,
		"wanted L39->8 L40->8 L99->8, got %s" % ", ".join(cap_got))


static func _case_randf_arithmetic(res: Dictionary) -> void:
	var formula: String = "randf(party.average_level * 0.5, party.average_level * 2.0)"
	var ctx: Dictionary = {"average_level": 10.0}
	var low: int = 9999
	var high: int = 0
	var under: int = 0
	for _i: int in range(300):
		var lvl: int = OpponentGenerator.eval_level(formula, ctx)
		low = mini(low, lvl)
		high = maxi(high, lvl)
		if lvl < 10:
			under += 1
	TestFixtures.check(res, "a randf argument is arithmetic, not a truncated literal",
		under > 0 and high >= 10,
		"%d of 300 rolls under 10, spread %d to %d" % [under, low, high])
	TestFixtures.check(res, "the roll stays inside its evaluated arguments", low >= 5 and high <= 20,
		"spread %d to %d against a range of 5 to 20" % [low, high])


static func _case_randf_independence(res: Dictionary) -> void:
	#Each half of the result carries one draw, so a shared substitution reads as a tie every time.
	var formula: String = "floor(randf(1.0, 100.0)) * 1000 + floor(randf(1.0, 100.0))"
	var apart: int = 0
	var strayed: int = 0
	for _i: int in range(200):
		var packed: int = OpponentGenerator.eval_level(formula, {})
		var first: int = int(packed / 1000.0)
		var second: int = packed % 1000
		if first != second:
			apart += 1
		if first < 1 or first > 99 or second < 1 or second > 99:
			strayed += 1
	TestFixtures.check(res, "two randf calls in one formula roll apart", apart > 0,
		"%d of 200 samples drew two different values" % apart)
	TestFixtures.check(res, "each draw lands inside its own range", strayed == 0,
		"%d of 200 samples fell outside 1 to 99" % strayed)


static func _case_lifepath_slot_count(res: Dictionary) -> void:
	var ctx: Dictionary = {"average_level": 6.0, "merc_count": 4, "difficulty_factor": 1.25}
	var none_template: NPCTemplate = _lifepath_template("None", "3", CURSE_POOL)
	var none_sizes: Array[String] = []
	var none_ok: bool = true
	for _i: int in range(10):
		var lean: MercenaryData = NPCGenerator.generate(none_template, ctx)
		none_sizes.append(str(lean.lifepaths.size()))
		if lean.lifepaths.size() != 3:
			none_ok = false
	TestFixtures.check(res, "an sLE of None spends every LE slot on eLE draws", none_ok,
		"an LE# of 3 produced %s" % ", ".join(none_sizes))
	var sle_template: NPCTemplate = _lifepath_template("Bored", "3", CURSE_POOL)
	var sle_sizes: Array[String] = []
	var sle_ok: bool = true
	for _i: int in range(10):
		var named: MercenaryData = NPCGenerator.generate(sle_template, ctx)
		sle_sizes.append("%d/%d" % [named.lifepaths.size(), _starting_held(named)])
		if named.lifepaths.size() != 3 or _starting_held(named) != 1:
			sle_ok = false
	TestFixtures.check(res, "a named sLE still spends one of the LE slots", sle_ok,
		"total over starting per merc %s" % ", ".join(sle_sizes))


static func _case_ele_any_pool(res: Dictionary) -> void:
	var template: NPCTemplate = DataManager.npc_templates.get("Bandit Melee", null) as NPCTemplate
	if template == null:
		TestFixtures.check(res, "the eLE Any pool", false, "Bandit Melee template did not load")
		return
	var curses: Array = DataManager.lifepaths_by_category.get("Curse", []) as Array
	var forced: Array = DataManager.lifepaths_by_category.get("Forced", []) as Array
	TestFixtures.check(res, "the Curse and Forced categories are loaded",
		not curses.is_empty() and not forced.is_empty(),
		"%d Curse rows and %d Forced rows" % [curses.size(), forced.size()])
	var ctx: Dictionary = {"average_level": 6.0, "merc_count": 4, "difficulty_factor": 1.25}
	var drawn: int = 0
	var off_type: Array[String] = []
	var off_row: Array[String] = []
	#The step is called direct; generate() also appends the rows a drawn perk grants.
	for i: int in range(12):
		var probe: MercenaryData = _lifepath_merc(20 + i)
		NPCGenerator._npc_step_lifepaths(probe, template, ctx)
		for lp: LifepathData in probe.lifepaths:
			if lp.event_type == "Starting":
				continue
			drawn += 1
			if lp.event_type != "Experienced":
				off_type.append("%s (%s)" % [lp.event_name, lp.event_type])
			elif lp.rarity.strip_edges() == "Guaranteed" or _has_placeholder(lp):
				off_row.append(lp.event_name)
	TestFixtures.check(res, "an eLE Any draw takes Experienced rows only",
		drawn > 0 and off_type.is_empty(),
		"%d eLE draws over 12 bandits, offenders %s" % [drawn,
			"none" if off_type.is_empty() else ", ".join(off_type)])
	TestFixtures.check(res, "the eLE Any pool drops Guaranteed rows and placeholder payoffs",
		off_row.is_empty(),
		"offenders %s" % ("none" if off_row.is_empty() else ", ".join(off_row)))


static func _case_leader_lifepaths(res: Dictionary) -> void:
	var template: NPCTemplate = DataManager.npc_templates.get("Bandit Leader", null) as NPCTemplate
	if template == null:
		TestFixtures.check(res, "leader lifepaths", false, "Bandit Leader template did not load")
		return
	var ctx: Dictionary = {"average_level": 6.0, "merc_count": 4, "difficulty_factor": 1.25}
	var start_ok: bool = true
	var cap_ok: bool = true
	var seen: Array[String] = []
	#Levels walk the whole LE# curve, one slot at level 4 up to the cap of 8 past level 35.
	for i: int in range(12):
		var level: int = 1 + i * 4
		var probe: MercenaryData = _lifepath_merc(level)
		NPCGenerator._npc_step_lifepaths(probe, template, ctx)
		var cap: int = mini(8, 1 + int(level / 5.0))
		var held: int = probe.lifepaths.size()
		seen.append("L%d %d of %d" % [level, held, cap])
		if _starting_held(probe) != 1:
			start_ok = false
		if held > cap:
			cap_ok = false
	TestFixtures.check(res, "a leader carries exactly one Starting lifepath", start_ok,
		"level, held and cap per leader: %s" % ", ".join(seen))
	TestFixtures.check(res, "a leader never holds more lifepaths than its LE# allows", cap_ok,
		"level, held and cap per leader: %s" % ", ".join(seen))
	var full_ok: bool = true
	var full_seen: Array[String] = []
	for _i: int in range(12):
		var leader: MercenaryData = NPCGenerator.generate(template, ctx)
		full_seen.append(str(_starting_held(leader)))
		if _starting_held(leader) != 1:
			full_ok = false
	TestFixtures.check(res, "a fully generated leader still carries one Starting lifepath", full_ok,
		"starting rows per leader: %s" % ", ".join(full_seen))
