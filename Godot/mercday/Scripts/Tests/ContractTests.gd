class_name ContractTests

#Contract data, penalty, modifier and Overall Success cases.
#Run: godot --headless --path . -- --contract-tests


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_build(res)
	_case_builder_military(res)
	_case_builder_events(res)
	_case_events_for(res)
	_case_penalty_parse(res)
	_case_penalty_match(res)
	_case_modifiers_apply_revert(res)
	_case_circumstance_boost(res)
	_case_bad_luck(res)
	_case_set_level(res)
	_case_overall_success(res)
	_case_relevance(res)
	_case_area_lookup(res)
	_case_terrain_rule(res)
	_case_enemy_counter(res)
	_case_carry_and_casualties(res)
	_case_forced_generation(res)
	_case_enemy_team(res)
	_case_mishap_roller(res)
	_case_formula_eval(res)
	_case_run_helpers(res)
	_case_field_for(res)
	_case_log_path(res)
	_case_wireframe_keys(res)
	_case_generator(res)
	_case_generator_locations(res)
	await _case_manager_flow(res)
	_case_manager_end_rest(res)
	_case_between_events(res)
	_case_log_write(res)
	_case_merc_line(res)
	return TestFixtures.summarize(res, "CONTRACT")


static func _names_eq(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i: int in range(actual.size()):
		if String(actual[i]) != String(expected[i]):
			return false
	return true


static func _pct(boosts: Dictionary, name: String) -> float:
	return float(boosts.get(name, -1.0))


static func _utility(name: String) -> UtilityTraitData:
	var u := UtilityTraitData.new()
	u.utility_name = name
	return u


static func _case_build(res: Dictionary) -> void:
	var out: Dictionary = ContractResourceBuilder.build_all()
	TestFixtures.check(res, "build_contract_count", int(out["contracts"]) == 8, "contracts %d" % int(out["contracts"]))
	TestFixtures.check(res, "build_event_count", int(out["events"]) == 10, "events %d" % int(out["events"]))
	var texts: Array[String] = ContractResourceBuilder.last_warnings
	#Known TSV data gaps; tighten to warnings == 0 once the designer fills these cells.
	var allowed: Array[String] = [
		"ContractResourceBuilder: Events.tsv row 7 column Enemy: Battle event has no enemy",
		"ContractResourceBuilder: Events.tsv row 7 column Enemy Counter: Battle event has no enemy counter",
		"ContractResourceBuilder: Events.tsv row 7 column Map: Battle event has no map rule",
		"ContractResourceBuilder: Contracts.tsv row 8 column 10% Stat: duplicate entry Luck",
	]
	var unexpected: Array[String] = []
	for text: String in texts:
		if not allowed.has(text):
			unexpected.append(text)
	TestFixtures.check(res, "build_warnings", unexpected.is_empty() and int(out["warnings"]) <= allowed.size(),
		"warnings %d, all known data gaps; unexpected: %s"
		% [int(out["warnings"]), "none" if unexpected.is_empty() else ", ".join(unexpected)])


static func _case_builder_military(res: Dictionary) -> void:
	var c: ContractData = ContractLibrary.contract_type("Military")
	if c == null:
		TestFixtures.check(res, "builder_military", false, "Military contract resource did not load")
		return
	TestFixtures.check(res, "builder_military_primary_pool",
		_names_eq(c.primary_event_pool, ["Assist with the Skirmish", "Battle"]),
		"primary pool %s" % str(c.primary_event_pool))
	TestFixtures.check(res, "builder_military_mishap_pool", _names_eq(c.mishap_pool, ["Tavern Brawl"]),
		"mishap pool %s" % str(c.mishap_pool))
	var stats_ok: bool = _pct(c.stat_boosts, "Combat") == 15.0 and _pct(c.stat_boosts, "Accuracy") == 10.0 \
		and _pct(c.stat_boosts, "Negotiate") == 5.0 and _pct(c.stat_boosts, "Support") == 15.0 \
		and _pct(c.stat_boosts, "Assassinate") == 5.0
	TestFixtures.check(res, "builder_military_stat_boosts", stats_ok, "stat boosts %s" % str(c.stat_boosts))
	var circ_ok: bool = _pct(c.circumstance_boosts, "Attack (Dexterity)") == 15.0 \
		and _pct(c.circumstance_boosts, "Speech (Wile)") == 5.0
	TestFixtures.check(res, "builder_military_circumstance_boosts", circ_ok, "circumstance boosts %s" % str(c.circumstance_boosts))
	var tool_ok: bool = _pct(c.tool_boosts, "Scout's") == 15.0 and _pct(c.tool_boosts, "Assassin's") == 5.0
	TestFixtures.check(res, "builder_military_tool_boosts", tool_ok, "tool boosts %s" % str(c.tool_boosts))
	var know_ok: bool = _pct(c.knowledge_boosts, "Dueling") == 15.0 and _pct(c.knowledge_boosts, "History") == 10.0 \
		and _pct(c.knowledge_boosts, "Psychology") == 5.0
	TestFixtures.check(res, "builder_military_knowledge_boosts", know_ok, "knowledge boosts %s" % str(c.knowledge_boosts))
	var trad_ok: bool = _pct(c.tradition_boosts, "Warrior") == 15.0 and _pct(c.tradition_boosts, "Brave") == 10.0 \
		and _pct(c.tradition_boosts, "Honorable") == 5.0
	TestFixtures.check(res, "builder_military_tradition_boosts", trad_ok, "tradition boosts %s" % str(c.tradition_boosts))
	var pen_ok: bool = c.penalties.size() == 3 and String(c.penalties[0].get("expr", "")) == "tradition = mage" \
		and float(c.penalties[0].get("percent", 0.0)) == 15.0
	TestFixtures.check(res, "builder_military_penalties", pen_ok, "penalties %s" % str(c.penalties))
	TestFixtures.check(res, "builder_military_description",
		c.description_template.begins_with("Assist the [location_a.demonym]"),
		"template %s" % c.description_template)


static func _case_builder_events(res: Dictionary) -> void:
	var brawl: EventData = ContractLibrary.event("Tavern Brawl")
	if brawl == null:
		TestFixtures.check(res, "builder_events", false, "Tavern Brawl event did not load")
		return
	var brawl_ok: bool = brawl.event_type == "Mishap" and brawl.enemy == "Taverngoer" \
		and brawl.enemy_counter == "party.merc_count + bad_luck_roll" and brawl.map_rule == "Interior:Tavern" \
		and brawl.is_battle() and brawl.knowledges.has("Dueling") and _names_eq(brawl.tools, ["Brewer's"]) \
		and brawl.possible_contracts.size() == 6
	TestFixtures.check(res, "builder_events_tavern_brawl", brawl_ok,
		"type %s enemy %s counter %s map %s tools %s contracts %d"
		% [brawl.event_type, brawl.enemy, brawl.enemy_counter, brawl.map_rule, str(brawl.tools), brawl.possible_contracts.size()])
	var skirmish: EventData = ContractLibrary.event("Assist with the Skirmish")
	var skirmish_ok: bool = skirmish != null and skirmish.event_type == "Primary" and skirmish.enemy == "Mercs" \
		and skirmish.enemy_counter == "party.merc_count + 2" and skirmish.map_rule == "Location"
	TestFixtures.check(res, "builder_events_skirmish", skirmish_ok,
		"type %s enemy %s counter %s map %s" % [skirmish.event_type, skirmish.enemy, skirmish.enemy_counter, skirmish.map_rule] if skirmish != null else "event missing")
	var poison: EventData = ContractLibrary.event("Poison the Target")
	var poison_ok: bool = poison != null and not poison.is_battle() and poison.enemy == ""
	TestFixtures.check(res, "builder_events_poison", poison_ok,
		"battle %s enemy '%s'" % [str(poison.is_battle()), poison.enemy] if poison != null else "event missing")


static func _case_events_for(res: Dictionary) -> void:
	var military_mishaps: Array[String] = _event_names(ContractLibrary.events_for("Military", "Mishap"))
	TestFixtures.check(res, "events_for_military_mishap", _names_eq(military_mishaps, ["Tavern Brawl"]),
		"names %s" % str(military_mishaps))
	var escort_mishaps: Array[String] = _event_names(ContractLibrary.events_for("Escort", "Mishap"))
	TestFixtures.check(res, "events_for_escort_mishap", escort_mishaps.has("Tavern Brawl"), "names %s" % str(escort_mishaps))
	var hunt_mishaps: Array[String] = _event_names(ContractLibrary.events_for("Monster Hunt", "Mishap"))
	TestFixtures.check(res, "events_for_monster_hunt_mishap", hunt_mishaps.is_empty(), "names %s" % str(hunt_mishaps))
	var military_primary: Array[String] = _event_names(ContractLibrary.events_for("Military", "Primary"))
	TestFixtures.check(res, "events_for_military_primary",
		_names_eq(military_primary, ["Assist with the Skirmish", "Battle"]), "names %s" % str(military_primary))


static func _event_names(events: Array[EventData]) -> Array[String]:
	var out: Array[String] = []
	for e: EventData in events:
		out.append(e.event_name)
	return out


static func _case_penalty_parse(res: Dictionary) -> void:
	var a: Dictionary = ContractPenalty.parse("tradition = mage")
	TestFixtures.check(res, "penalty_parse_tradition",
		bool(a["ok"]) and String(a["kind"]) == "tradition" and String(a["value"]) == "mage",
		"parsed %s" % str(a))
	var b: Dictionary = ContractPenalty.parse("2 >= cognition")
	TestFixtures.check(res, "penalty_parse_number_first",
		bool(b["ok"]) and String(b["kind"]) == "stat" and String(b["operand"]) == "cognition" \
			and String(b["op"]) == "<=" and is_equal_approx(float(b["value"]), 2.0),
		"parsed %s" % str(b))
	var c: Dictionary = ContractPenalty.parse("3 <= team.merc_count")
	TestFixtures.check(res, "penalty_parse_team",
		bool(c["ok"]) and String(c["kind"]) == "team" and String(c["op"]) == ">=" \
			and is_equal_approx(float(c["value"]), 3.0),
		"parsed %s" % str(c))
	var d: Dictionary = ContractPenalty.parse("3>=team.merc_count")
	TestFixtures.check(res, "penalty_parse_no_spaces", bool(d["ok"]) and String(d["op"]) == "<=", "parsed %s" % str(d))
	var e: Dictionary = ContractPenalty.parse("cognition <= 2")
	TestFixtures.check(res, "penalty_parse_operand_first",
		bool(e["ok"]) and String(e["operand"]) == "cognition" and String(e["op"]) == "<=", "parsed %s" % str(e))
	var f: Dictionary = ContractPenalty.parse("")
	TestFixtures.check(res, "penalty_parse_empty", not bool(f["ok"]), "parsed %s" % str(f))
	var g: Dictionary = ContractPenalty.parse("banana")
	TestFixtures.check(res, "penalty_parse_garbage", not bool(g["ok"]), "parsed %s" % str(g))
	var h: Dictionary = ContractPenalty.parse("2 >= ")
	TestFixtures.check(res, "penalty_parse_missing_operand", not bool(h["ok"]), "parsed %s" % str(h))


static func _case_penalty_match(res: Dictionary) -> void:
	var expr_stat: Dictionary = ContractPenalty.parse("2 >= cognition")
	var low := MercenaryData.new()
	low.merc_name = "Low"
	low.stats = {"cognition": 2}
	var high := MercenaryData.new()
	high.merc_name = "High"
	high.stats = {"cognition": 3}
	TestFixtures.check(res, "penalty_match_stat",
		ContractPenalty.matches(expr_stat, low, 1) and not ContractPenalty.matches(expr_stat, high, 1),
		"cognition 2 matched %s, cognition 3 matched %s"
		% [str(ContractPenalty.matches(expr_stat, low, 1)), str(ContractPenalty.matches(expr_stat, high, 1))])
	var expr_team: Dictionary = ContractPenalty.parse("3 <= team.merc_count")
	TestFixtures.check(res, "penalty_match_team",
		ContractPenalty.matches(expr_team, low, 3) and not ContractPenalty.matches(expr_team, low, 2),
		"team 3 matched %s, team 2 matched %s"
		% [str(ContractPenalty.matches(expr_team, low, 3)), str(ContractPenalty.matches(expr_team, low, 2))])
	var expr_trad: Dictionary = ContractPenalty.parse("tradition = mage")
	var mage := MercenaryData.new()
	mage.merc_name = "Mage"
	mage.stats = {}
	mage.tradition = DataManager.traditions.get("Mage") as TraditionData
	var warrior := MercenaryData.new()
	warrior.merc_name = "Warrior"
	warrior.stats = {}
	warrior.tradition = DataManager.traditions.get("Warrior") as TraditionData
	var none := MercenaryData.new()
	none.merc_name = "None"
	none.stats = {}
	var trad_ok: bool = ContractPenalty.matches(expr_trad, mage, 1) \
		and not ContractPenalty.matches(expr_trad, warrior, 1) \
		and not ContractPenalty.matches(expr_trad, none, 1)
	TestFixtures.check(res, "penalty_match_tradition", trad_ok,
		"mage %s warrior %s none %s" % [str(ContractPenalty.matches(expr_trad, mage, 1)),
			str(ContractPenalty.matches(expr_trad, warrior, 1)), str(ContractPenalty.matches(expr_trad, none, 1))])
	var expr_size: Dictionary = ContractPenalty.parse("3 <= size")
	var sized := MercenaryData.new()
	sized.merc_name = "Sized"
	sized.stats = {}
	sized.max_stats = {"size": 3}
	TestFixtures.check(res, "penalty_match_max_stat_fallback", ContractPenalty.matches(expr_size, sized, 1),
		"size from max_stats matched %s" % str(ContractPenalty.matches(expr_size, sized, 1)))


static func _case_modifiers_apply_revert(res: Dictionary) -> void:
	var contract: ContractData = ContractLibrary.contract_type("Military")
	if contract == null:
		TestFixtures.check(res, "modifiers_apply_revert", false, "Military contract resource did not load")
		return
	#A clean probe carries no trait multipliers, so the boosted values stay exact.
	var probe := MercenaryData.new()
	probe.merc_name = "BoostProbe"
	probe.max_stats = {"size": 0, "max_cognition": 8, "max_dexterity": 8, "max_vigor": 8, "max_wile": 8}
	probe.stats = StatCalculator.calculate_all(probe)
	var combat_before: float = float(probe.stats.get("combat", 0.0))
	var accuracy_before: float = float(probe.stats.get("accuracy", 0.0))
	var probe_team: Array[MercenaryData] = [probe]
	ContractModifiers.apply(contract, probe_team)
	var combat_after: float = float(probe.stats.get("combat", 0.0))
	var accuracy_after: float = float(probe.stats.get("accuracy", 0.0))
	var want_combat: float = combat_before * 1.15
	#Accuracy adds combat with a coefficient of one, so the combat boost reaches it before its own 10%.
	var want_accuracy: float = (accuracy_before - combat_before + want_combat) * 1.10
	TestFixtures.check(res, "modifiers_combat_boost", absf(combat_after - want_combat) < 0.01,
		"combat %.3f -> %.3f (expected %.3f)" % [combat_before, combat_after, want_combat])
	TestFixtures.check(res, "modifiers_accuracy_boost", absf(accuracy_after - want_accuracy) < 0.01,
		"accuracy %.3f -> %.3f (expected %.3f)" % [accuracy_before, accuracy_after, want_accuracy])
	var merc: MercenaryData = MercGenerator.generate(0)
	var snapshot: Dictionary = merc.stats.duplicate()
	var team: Array[MercenaryData] = [merc]
	var record: Dictionary = ContractModifiers.apply(contract, team)
	ContractModifiers.revert(record)
	var drift: String = ""
	for key: String in snapshot:
		if not merc.stats.has(key):
			drift = "%s missing" % key
			break
		if snapshot[key] is int:
			if int(merc.stats[key]) != int(snapshot[key]):
				drift = "%s %d -> %d" % [key, int(snapshot[key]), int(merc.stats[key])]
				break
		elif absf(float(merc.stats[key]) - float(snapshot[key])) > 0.001:
			drift = "%s %.4f -> %.4f" % [key, float(snapshot[key]), float(merc.stats[key])]
			break
	TestFixtures.check(res, "modifiers_revert", drift == "", "drift: %s" % ("none" if drift == "" else drift))


static func _case_circumstance_boost(res: Dictionary) -> void:
	var contract: ContractData = ContractLibrary.contract_type("Military")
	if contract == null:
		TestFixtures.check(res, "circumstance_boost", false, "Military contract resource did not load")
		return
	var display: String = ConstCircumstances.ATTACK_DEXTERITY
	var flagged: MercenaryData = MercGenerator.generate(0)
	flagged.circumstance_flags[display] = true
	flagged.circumstance_additional_bonus[display] = 0.0
	var unflagged: MercenaryData = MercGenerator.generate(1)
	unflagged.circumstance_flags[display] = false
	unflagged.circumstance_additional_bonus[display] = 0.0
	var team: Array[MercenaryData] = [flagged, unflagged]
	var record: Dictionary = ContractModifiers.apply(contract, team)
	var got: float = float(flagged.circumstance_additional_bonus.get(display, -1.0))
	TestFixtures.check(res, "circumstance_boost_applied", absf(got - 2.25) < 0.001, "additional bonus %.4f" % got)
	var skipped: float = float(unflagged.circumstance_additional_bonus.get(display, -1.0))
	TestFixtures.check(res, "circumstance_boost_skipped", absf(skipped) < 0.001, "unflagged additional bonus %.4f" % skipped)
	ContractModifiers.revert(record)
	var reverted: float = float(flagged.circumstance_additional_bonus.get(display, -1.0))
	TestFixtures.check(res, "circumstance_boost_reverted", absf(reverted) < 0.001, "additional bonus %.4f" % reverted)


static func _case_bad_luck(res: Dictionary) -> void:
	var merc := MercenaryData.new()
	merc.merc_name = "Lucky"
	merc.stats = {"luck": 20.0}
	var team: Array[MercenaryData] = [merc]
	var step: int = 10
	BadLuckRoll.forced_d100 = 65
	var a: Dictionary = BadLuckRoll.roll(team, step)
	TestFixtures.check(res, "bad_luck_above", int(a["extra"]) == 4, a["line"])
	BadLuckRoll.forced_d100 = 10
	var b: Dictionary = BadLuckRoll.roll(team, step)
	TestFixtures.check(res, "bad_luck_below", int(b["extra"]) == 0, b["line"])
	BadLuckRoll.forced_d100 = 100
	var c: Dictionary = BadLuckRoll.roll(team, step)
	TestFixtures.check(res, "bad_luck_max", int(c["extra"]) == 8, c["line"])
	TestFixtures.check(res, "bad_luck_forced_consumed", BadLuckRoll.forced_d100 == -1,
		"forced_d100 %d" % BadLuckRoll.forced_d100)


#The multiplier factor StatCalculator applies to one stat; the factor never goes below zero.
static func _stat_factor(merc: MercenaryData, key: String) -> float:
	return maxf(0.0, 1.0 + float(merc.stat_multipliers.get(key, 0.0)))


static func _case_set_level(res: Dictionary) -> void:
	var merc: MercenaryData = MercGenerator.generate(0)
	var level_before: float = float(merc.stats.get("level", 0.0))
	var base_before: float = float(merc.stats.get("base_success_chance", 0.0))
	ContractModifiers.set_level(merc, 5)
	TestFixtures.check(res, "set_level_level", int(merc.stats.get("level", 0)) == 5, "level %s" % str(merc.stats.get("level", 0)))
	var base_after: float = float(merc.stats.get("base_success_chance", -1.0))
	#Base success chance is the level, so a generated multiplier on either stat scales the delta.
	var want_delta: float = (5.0 - level_before) * _stat_factor(merc, "level") * _stat_factor(merc, "base_success_chance")
	TestFixtures.check(res, "set_level_base_success", absf((base_after - base_before) - want_delta) < 0.001,
		"base success chance %.4f -> %.4f want delta %.4f" % [base_before, base_after, want_delta])
	#Speed is (dexterity - size * 10) + level floored at 0, so the probe uses size 0 to stay off the clamp.
	var probe := MercenaryData.new()
	probe.merc_name = "SpeedProbe"
	probe.max_stats = {"size": 0, "max_cognition": 4, "max_dexterity": 20, "max_vigor": 4, "max_wile": 4}
	probe.stats = StatCalculator.calculate_all(probe)
	var speed_before: float = float(probe.stats.get("speed", 0.0))
	ContractModifiers.set_level(probe, 5)
	var speed_after: float = float(probe.stats.get("speed", 0.0))
	TestFixtures.check(res, "set_level_speed", absf(speed_after - (speed_before + 5.0)) < 0.001,
		"speed %.3f -> %.3f" % [speed_before, speed_after])
	var probe_base: float = float(probe.stats.get("base_success_chance", -1.0))
	TestFixtures.check(res, "set_level_probe_base_success", absf(probe_base - 5.0) < 0.001,
		"base success chance %.4f" % probe_base)


static func _synthetic_contract() -> ContractData:
	var c := ContractData.new()
	c.contract_type = "Probe"
	c.tool_boosts = {"Scout's": 15.0}
	var penalties: Array[Dictionary] = [{"expr": "2 >= cognition", "percent": 10.0}]
	c.penalties = penalties
	return c


static func _case_overall_success(res: Dictionary) -> void:
	var merc := MercenaryData.new()
	merc.merc_name = "Probe"
	merc.stats = {"base_success_chance": 5.0, "cognition": 2, "level": 5.0}
	merc.tools = [_utility("Scout's Kit")] as Array[UtilityTraitData]
	var contract: ContractData = _synthetic_contract()
	var team: Array[MercenaryData] = [merc]
	var info: Dictionary = OverallSuccess.for_merc(contract, team, merc, null)
	var plain_ok: bool = is_equal_approx(float(info["boost_percent"]), 15.0) \
		and is_equal_approx(float(info["relevance_percent"]), 0.0) \
		and is_equal_approx(float(info["penalty_percent"]), 10.0) \
		and is_equal_approx(float(info["net_percent"]), 5.0) \
		and absf(float(info["value"]) - 5.25) < 0.0001 and absf(float(info["delta"]) - 0.25) < 0.0001
	TestFixtures.check(res, "overall_success_no_event", plain_ok, OverallSuccess.describe(merc, info))
	merc.knowledges = [_utility("Dueling")] as Array[UtilityTraitData]
	var event: EventData = ContractLibrary.event("Tavern Brawl")
	var with_event: Dictionary = OverallSuccess.for_merc(contract, team, merc, event)
	var event_ok: bool = is_equal_approx(float(with_event["relevance_percent"]), 15.0) \
		and is_equal_approx(float(with_event["net_percent"]), 20.0) \
		and absf(float(with_event["value"]) - 6.0) < 0.0001
	TestFixtures.check(res, "overall_success_with_event", event_ok, OverallSuccess.describe(merc, with_event))
	var record: Dictionary = OverallSuccess.apply_event_delta(contract, team, event)
	var applied: float = float(merc.stats["base_success_chance"])
	TestFixtures.check(res, "overall_success_apply", absf(applied - 6.0) < 0.0001, "base success chance %.4f" % applied)
	OverallSuccess.revert_event_delta(record)
	var restored: float = float(merc.stats["base_success_chance"])
	TestFixtures.check(res, "overall_success_revert", restored == 5.0, "base success chance %.4f" % restored)


static func _case_relevance(res: Dictionary) -> void:
	var event: EventData = ContractLibrary.event("Tavern Brawl")
	var brewer := MercenaryData.new()
	brewer.merc_name = "Brewer"
	brewer.stats = {}
	brewer.tools = [_utility("Brewer's Kit")] as Array[UtilityTraitData]
	var plain := MercenaryData.new()
	plain.merc_name = "Plain"
	plain.stats = {}
	plain.tools = [_utility("Miner's Kit")] as Array[UtilityTraitData]
	var hit: float = OverallSuccess.relevance_percent(brewer, event)
	var miss: float = OverallSuccess.relevance_percent(plain, event)
	TestFixtures.check(res, "relevance_tool_prefix", is_equal_approx(hit, 15.0), "relevance %.1f" % hit)
	TestFixtures.check(res, "relevance_no_match", is_equal_approx(miss, 0.0), "relevance %.1f" % miss)


static func _case_area_lookup(res: Dictionary) -> void:
	var tavern: Dictionary = DataManager.get_area_by_name("Tavern")
	TestFixtures.check(res, "area_lookup_tavern", String(tavern.get("type", "")) == "Interior", "area %s" % str(tavern.get("type", "")))
	TestFixtures.check(res, "area_lookup_missing", DataManager.get_area_by_name("Nowhere").is_empty(), "empty for an unknown area")
	var cathistii: LocationData = DataManager.locations.get("Cathistii") as LocationData
	var aerdis: LocationData = DataManager.locations.get("Aerdis") as LocationData
	var raw_a: String = String(cathistii.get_meta("temperature_raw", "x")) if cathistii != null else "missing"
	var raw_b: String = String(aerdis.get_meta("temperature_raw", "x")) if aerdis != null else "missing"
	TestFixtures.check(res, "location_temperature_raw", raw_a == "" and raw_b == "Above 25",
		"Cathistii '%s' Aerdis '%s'" % [raw_a, raw_b])
static func _case_terrain_rule(res: Dictionary) -> void:
	var cold: String = ContractTerrain.COLD_AREA
	var warm: String = ContractTerrain.WARM_AREA
	var temp_ok: bool = ContractTerrain.terrain_for_temperature("Above 25") == warm \
		and ContractTerrain.terrain_for_temperature("Above 50") == warm \
		and ContractTerrain.terrain_for_temperature("Below 0") == cold \
		and ContractTerrain.terrain_for_temperature("Below -50") == cold \
		and ContractTerrain.terrain_for_temperature("0") == "" \
		and ContractTerrain.terrain_for_temperature("Above 0") == "" \
		and ContractTerrain.terrain_for_temperature("") == "" \
		and ContractTerrain.terrain_for_temperature("Above 24") == ""
	TestFixtures.check(res, "terrain_rule_temperature", temp_ok,
		"Above 25 '%s' Below -50 '%s' 0 '%s' Above 24 '%s'" % [
			ContractTerrain.terrain_for_temperature("Above 25"),
			ContractTerrain.terrain_for_temperature("Below -50"),
			ContractTerrain.terrain_for_temperature("0"),
			ContractTerrain.terrain_for_temperature("Above 24")])
	var expected: Dictionary = {
		"Gledd Sea": "", "Umbra": "", "Aerdis": warm, "Cathistii": warm,
		"Austyg": cold, "Miliim": "", "Cyfrolaef": "",
	}
	var bad: Array[String] = []
	for loc_name: String in expected:
		var loc: LocationData = DataManager.locations.get(loc_name, null) as LocationData
		var got: String = ContractTerrain.area_name_for(loc)
		if got != String(expected[loc_name]):
			bad.append("%s '%s' != '%s'" % [loc_name, got, String(expected[loc_name])])
	TestFixtures.check(res, "terrain_rule_locations", bad.is_empty(),
		"all 7 locations map as expected" if bad.is_empty() else ", ".join(bad))


static func _case_enemy_counter(res: Dictionary) -> void:
	var ctx: Dictionary = {"merc_count": 3, "average_level": 5.0, "bad_luck_roll": 0}
	var a: int = EnemyTeamBuilder.eval_count("party.merc_count + 2", ctx)
	TestFixtures.check(res, "enemy_counter_plus_two", a == 5, "count %d" % a)
	var ctx2: Dictionary = {"merc_count": 3, "average_level": 5.0, "bad_luck_roll": 2}
	var b: int = EnemyTeamBuilder.eval_count("party.merc_count + bad_luck_roll", ctx2)
	TestFixtures.check(res, "enemy_counter_bad_luck", b == 5, "count %d" % b)
	var c: int = EnemyTeamBuilder.eval_count("0", ctx)
	TestFixtures.check(res, "enemy_counter_floor_one", c == 1, "count %d" % c)
	var d: int = EnemyTeamBuilder.eval_count("party.average_level / 2", ctx)
	TestFixtures.check(res, "enemy_counter_average_level", d == 2, "count %d" % d)


static func _case_carry_and_casualties(res: Dictionary) -> void:
	var a: Array[MercenaryData] = [MercGenerator.generate(0)]
	var b: Array[MercenaryData] = [MercGenerator.generate(1)]
	a[0].current_hp = 3
	a[0].current_ep = 2
	var state: BattleState = BattleState.create(a, b, null, true)
	var carry_ok: bool = a[0].current_hp == 3 and a[0].current_ep == 2 and state.carry_resources
	TestFixtures.check(res, "carry_resources_kept", carry_ok,
		"hp %d ep %d carry %s" % [a[0].current_hp, a[0].current_ep, str(state.carry_resources)])
	a[0].is_dead = true
	AutoBattle._finalize(state, Callable())
	var cas_ok: bool = state.casualties.size() == 1 and state.casualties[0] == a[0] \
		and a[0].is_dead and a[0].current_hp == 3
	TestFixtures.check(res, "carry_casualties_recorded", cas_ok,
		"casualties %d dead %s hp %d" % [state.casualties.size(), str(a[0].is_dead), a[0].current_hp])
	var state2: BattleState = BattleState.create(a, b, null)
	var reset_ok: bool = not a[0].is_dead and a[0].current_hp == int(a[0].stats.get("maximum_hit_points", -1))
	TestFixtures.check(res, "carry_off_resets", reset_ok,
		"dead %s hp %d max %d" % [str(a[0].is_dead), a[0].current_hp, int(a[0].stats.get("maximum_hit_points", -1))])
	AutoBattle._finalize(state2, Callable())
	TestFixtures.check(res, "carry_off_no_casualties", state2.casualties.is_empty(),
		"casualties %d" % state2.casualties.size())


static func _case_forced_generation(res: Dictionary) -> void:
	MercGenerator.forced_level = 3
	MercGenerator.forced_tradition = "Brave"
	var m: MercenaryData = MercGenerator.generate(0)
	var level_ok: bool = int(m.stats.get("level", -1)) == 3 \
		and float(m.stats.get("base_success_chance", -1.0)) >= 3.0 - 0.001
	TestFixtures.check(res, "forced_level_applied", level_ok,
		"level %s base %s" % [str(m.stats.get("level", -1)), str(m.stats.get("base_success_chance", -1.0))])
	TestFixtures.check(res, "forced_tradition_applied", m.tradition != null and m.tradition.tradition_name == "Brave",
		"tradition %s" % _trad_name(m))
	MercGenerator.forced_level = -1
	MercGenerator.forced_tradition = ""
	var m2: MercenaryData = MercGenerator.generate(0)
	TestFixtures.check(res, "forced_reset", int(m2.stats.get("level", 0)) == 0, "level %s" % str(m2.stats.get("level", 0)))
	MercGenerator.forced_tradition = "Nonsense"
	var m3: MercenaryData = MercGenerator.generate(0)
	TestFixtures.check(res, "forced_tradition_unknown_falls_back", m3.tradition != null, "tradition %s" % _trad_name(m3))
	MercGenerator.forced_tradition = ""


static func _trad_name(merc: MercenaryData) -> String:
	if merc == null or merc.tradition == null:
		return "null"
	return merc.tradition.tradition_name


static func _contract_run(contract_name: String, count: int, level: int) -> ContractRun:
	var r := ContractRun.new()
	r.contract = ContractLibrary.contract_type(contract_name)
	var team: Array[MercenaryData] = []
	for i: int in range(count):
		var merc: MercenaryData = MercGenerator.generate(i)
		if level > 0:
			ContractModifiers.set_level(merc, level)
		team.append(merc)
	r.team = team
	return r


static func _case_enemy_team(res: Dictionary) -> void:
	var run: ContractRun = _contract_run("Military", 3, 5)
	var skirmish: EventData = ContractLibrary.event("Assist with the Skirmish")
	var mercs: Array[MercenaryData] = EnemyTeamBuilder.build(skirmish, run, 0)
	TestFixtures.check(res, "enemy_team_merc_count", mercs.size() == 5, "enemies %d" % mercs.size())
	var levels_ok: bool = true
	var trads_ok: bool = mercs.size() == 5
	var detail: Array[String] = []
	for i: int in range(mercs.size()):
		var lvl: int = int(mercs[i].stats.get("level", -1))
		if lvl < 1 or lvl > 2:
			levels_ok = false
		var want: String = "Brave" if i == 0 else "Warrior"
		if _trad_name(mercs[i]) != want:
			trads_ok = false
		detail.append("L%d %s" % [lvl, _trad_name(mercs[i])])
	TestFixtures.check(res, "enemy_team_merc_levels", levels_ok, "enemies %s" % ", ".join(detail))
	TestFixtures.check(res, "enemy_team_merc_traditions", trads_ok, "enemies %s" % ", ".join(detail))
	TestFixtures.check(res, "enemy_team_statics_reset",
		MercGenerator.forced_level == -1 and MercGenerator.forced_tradition == "",
		"forced_level %d forced_tradition '%s'" % [MercGenerator.forced_level, MercGenerator.forced_tradition])
	var brawl: EventData = ContractLibrary.event("Tavern Brawl")
	var npcs: Array[MercenaryData] = EnemyTeamBuilder.build(brawl, run, 2)
	var npc_ok: bool = npcs.size() == 5
	for npc: MercenaryData in npcs:
		if npc.tradition != null:
			npc_ok = false
	TestFixtures.check(res, "enemy_team_npc", npc_ok, "enemies %d, Taverngoers carry no tradition" % npcs.size())


static func _case_mishap_roller(res: Dictionary) -> void:
	var config: ContractConfig = ContractLibrary.config().duplicate() as ContractConfig
	var military: ContractData = ContractLibrary.contract_type("Military")
	config.mishap_chance = 100.0
	config.max_mishaps = 1
	var a: Array[String] = MishapRoller.roll(military, config)
	TestFixtures.check(res, "mishap_always", _names_eq(a, ["Tavern Brawl"]), "picked %s" % str(a))
	config.mishap_chance = 0.0
	var b: Array[String] = MishapRoller.roll(military, config)
	TestFixtures.check(res, "mishap_never", b.is_empty(), "picked %s" % str(b))
	config.mishap_chance = 100.0
	config.max_mishaps = 3
	var c: Array[String] = MishapRoller.roll(military, config)
	TestFixtures.check(res, "mishap_no_repeat", _names_eq(c, ["Tavern Brawl"]), "picked %s" % str(c))
	config.max_mishaps = 1
	var hunt: ContractData = ContractLibrary.contract_type("Monster Hunt")
	var d: Array[String] = MishapRoller.roll(hunt, config)
	TestFixtures.check(res, "mishap_empty_pool", d.is_empty(), "picked %s" % str(d))


static func _case_formula_eval(res: Dictionary) -> void:
	var merc := MercenaryData.new()
	merc.merc_name = "Formula"
	merc.stats = {"cognition": 2, "rescue": 40}
	var a: float = FormulaEventResolver.evaluate("team.rescue - (location.difficulty - 10.0)", merc)
	TestFixtures.check(res, "formula_location_zero", absf(a - 50.0) < 0.001, "value %.3f" % a)
	var b: float = FormulaEventResolver.evaluate("team.cognition * 10.0 - target.luck", merc)
	TestFixtures.check(res, "formula_target_zero", absf(b - 20.0) < 0.001, "value %.3f" % b)
	var c: float = FormulaEventResolver.evaluate("", merc)
	TestFixtures.check(res, "formula_empty", absf(c) < 0.001, "value %.3f" % c)


static func _case_run_helpers(res: Dictionary) -> void:
	var run: ContractRun = _contract_run("Military", 3, 0)
	var doomed: MercenaryData = run.team[1]
	doomed.is_dead = true
	TestFixtures.check(res, "run_living_team", run.living_team().size() == 2, "living %d" % run.living_team().size())
	var dead: Array[MercenaryData] = [doomed]
	var moved: Array[MercenaryData] = run.remove_dead(dead)
	TestFixtures.check(res, "run_remove_dead",
		moved.size() == 1 and run.team.size() == 2 and run.casualties.size() == 1,
		"moved %d team %d casualties %d" % [moved.size(), run.team.size(), run.casualties.size()])
	var got: Array[String] = []
	run.line_fn = func(line: String) -> void: got.append(line)
	run.emit("x")
	TestFixtures.check(res, "run_emit", run.log_lines.has("x") and got.size() == 1 and got[0] == "x",
		"log_lines %d collected %s" % [run.log_lines.size(), str(got)])


static func _case_field_for(res: Dictionary) -> void:
	var aerdis: LocationData = DataManager.locations.get("Aerdis", null) as LocationData
	var austyg: LocationData = DataManager.locations.get("Austyg", null) as LocationData
	var cathistii: LocationData = DataManager.locations.get("Cathistii", null) as LocationData
	var brawl: EventData = ContractLibrary.event("Tavern Brawl")
	var skirmish: EventData = ContractLibrary.event("Assist with the Skirmish")
	var interior: BattlefieldArea = ContractTerrain.field_for(brawl, aerdis, 3, 3)
	TestFixtures.check(res, "field_for_interior", interior.is_interior_map and interior.area_name == "Tavern",
		"interior %s area %s" % [str(interior.is_interior_map), interior.area_name])
	var warm: BattlefieldArea = ContractTerrain.field_for(skirmish, aerdis, 3, 3)
	TestFixtures.check(res, "field_for_warm", not warm.is_interior_map and warm.area_name == ContractTerrain.WARM_AREA,
		"interior %s area %s" % [str(warm.is_interior_map), warm.area_name])
	var cold: BattlefieldArea = ContractTerrain.field_for(skirmish, austyg, 3, 3)
	TestFixtures.check(res, "field_for_cold", cold.area_name == ContractTerrain.COLD_AREA, "area %s" % cold.area_name)
	var parent: BattlefieldArea = ContractTerrain.field_for(skirmish, cathistii, 3, 3)
	TestFixtures.check(res, "field_for_parent_temperature", parent.area_name == ContractTerrain.WARM_AREA,
		"area %s" % parent.area_name)


static func _case_log_path(res: Dictionary) -> void:
	var path: String = EncounterLogger.current_log_path()
	TestFixtures.check(res, "log_path_shape", path == "" or path.ends_with(".txt"), "path '%s'" % path)


static func _display_name(loc: LocationData) -> String:
	if loc == null:
		return "Unknown"
	if loc.demonym != "":
		return loc.demonym
	return loc.location_name


static func _case_generator(res: Dictionary) -> void:
	var c: ContractData = ContractGenerator.generate("Military")
	TestFixtures.check(res, "generator_not_null", c != null, "contract %s" % ("null" if c == null else c.contract_type))
	if c == null:
		return
	TestFixtures.check(res, "generator_status", c.status == "Draft", "status %s" % c.status)
	TestFixtures.check(res, "generator_reward", c.reward_notes == 300 and c.max_mercs == 3,
		"reward %d max mercs %d" % [c.reward_notes, c.max_mercs])
	TestFixtures.check(res, "generator_primary", c.assigned_primary_event == "Assist with the Skirmish",
		"primary %s" % c.assigned_primary_event)
	TestFixtures.check(res, "generator_mishaps", _names_eq(c.rolled_mishaps, ["Tavern Brawl"]), "mishaps %s" % str(c.rolled_mishaps))
	var a: LocationData = DataManager.locations.get(c.location_a, null) as LocationData
	TestFixtures.check(res, "generator_location_a", a != null and ContractTerrain.area_name_for(a) != "",
		"location_a %s terrain %s" % [c.location_a, ContractTerrain.area_name_for(a)])
	var b: LocationData = DataManager.locations.get(c.location_b, null) as LocationData
	TestFixtures.check(res, "generator_location_b",
		b != null and b.location_type == "Country" and b.demonym != "" and (a == null or b.demonym != a.demonym),
		"location_b %s type %s demonym %s" % [c.location_b, "none" if b == null else b.location_type, "none" if b == null else b.demonym])
	TestFixtures.check(res, "generator_description",
		not c.description.contains("[") and c.description.contains(_display_name(a)) and c.description.contains(_display_name(b)),
		"description %s" % c.description)
	var bad: ContractData = ContractGenerator.generate("Nonsense")
	TestFixtures.check(res, "generator_unknown_type", bad == null, "contract %s" % ("null" if bad == null else bad.contract_type))


static func _case_generator_locations(res: Dictionary) -> void:
	var all_ok: bool = true
	var bad_name: String = ""
	for _i: int in range(50):
		var loc: LocationData = ContractGenerator.pick_location_a()
		if loc == null:
			all_ok = false
			bad_name = "null"
			break
		if ContractTerrain.area_name_for(loc) == "":
			all_ok = false
			bad_name = loc.location_name
			break
	TestFixtures.check(res, "pick_location_a_terrain", all_ok, "50 rolls, first bad %s" % (bad_name if bad_name != "" else "none"))
	var b: LocationData = ContractGenerator.pick_location_b(null)
	TestFixtures.check(res, "pick_location_b_country",
		b != null and b.location_type == "Country" and b.demonym != "",
		"location %s" % ("null" if b == null else "%s %s %s" % [b.location_name, b.location_type, b.demonym]))
	var aerdis: LocationData = DataManager.locations.get("Aerdis", null) as LocationData
	var austyg: LocationData = DataManager.locations.get("Austyg", null) as LocationData
	var want: String = "%s vs %s" % [_display_name(aerdis), _display_name(austyg)]
	var got: String = ContractGenerator.fill_description("[location_a.demonym] vs [location_b.demonym]", aerdis, austyg)
	TestFixtures.check(res, "fill_description", got == want and got.begins_with("Aerdan vs "), "got %s want %s" % [got, want])


static func _case_manager_flow(res: Dictionary) -> void:
	CampaignClock.reset()
	var team: Array[MercenaryData] = []
	for i: int in range(3):
		var merc: MercenaryData = MercGenerator.generate(i)
		ContractModifiers.set_level(merc, 5)
		team.append(merc)
	var combat_before: Dictionary = {}
	for merc: MercenaryData in team:
		combat_before[merc] = float(merc.stats.get("combat", 0.0))
	var contract: ContractData = ContractGenerator.generate("Military")
	var run: ContractRun = await ContractManager.run(contract, team, Callable())
	TestFixtures.check(res, "manager_verdict", run.verdict == "Succeeded" or run.verdict == "Failed", "verdict %s" % run.verdict)
	TestFixtures.check(res, "manager_status", contract.status == run.verdict, "status %s verdict %s" % [contract.status, run.verdict])
	TestFixtures.check(res, "manager_first_event",
		run.outcomes.size() >= 1 and String(run.outcomes[0].get("event", "")) == "Tavern Brawl",
		"outcomes %d first %s" % [run.outcomes.size(), "none" if run.outcomes.is_empty() else String(run.outcomes[0].get("event", ""))])
	var second_ok: bool = false
	if run.outcomes.size() == 2:
		second_ok = String(run.outcomes[1].get("event", "")) == "Assist with the Skirmish"
	else:
		second_ok = run.failed_event == "Tavern Brawl"
	TestFixtures.check(res, "manager_primary_event", second_ok, "outcomes %d failed_event %s" % [run.outcomes.size(), run.failed_event])
	var primary_success: bool = false
	for outcome: Dictionary in run.outcomes:
		if String(outcome.get("event", "")) == "Assist with the Skirmish" and bool(outcome.get("success", false)):
			primary_success = true
	TestFixtures.check(res, "manager_verdict_rule", (run.verdict == "Succeeded") == primary_success,
		"verdict %s primary success %s" % [run.verdict, str(primary_success)])
	var want_reward: int = 300 if run.verdict == "Succeeded" else 0
	TestFixtures.check(res, "manager_reward", run.reward_paid == want_reward, "reward %d want %d" % [run.reward_paid, want_reward])
	TestFixtures.check(res, "manager_team_split",
		run.team.size() + run.casualties.size() == 3 and team.size() == 3,
		"team %d casualties %d source %d" % [run.team.size(), run.casualties.size(), team.size()])
	var dead_ok: bool = true
	for merc: MercenaryData in run.casualties:
		if not merc.is_dead:
			dead_ok = false
	TestFixtures.check(res, "manager_casualties_dead", dead_ok, "casualties %d" % run.casualties.size())
	var rest_ok: bool = true
	var rest_detail: Array[String] = []
	for merc: MercenaryData in run.living_team():
		var max_hp: int = int(merc.stats.get("maximum_hit_points", 0))
		var cap_hp: int = _hp_cap(merc)
		var full_ep: bool = merc.current_ep == int(merc.stats.get("maximum_endurance_points", 0))
		if merc.current_hp < cap_hp or merc.current_hp > max_hp or not full_ep:
			rest_ok = false
		rest_detail.append("%d/%d cap %d ep %d" % [merc.current_hp, max_hp, cap_hp, merc.current_ep])
	TestFixtures.check(res, "manager_rest_respite", rest_ok, "hp %s" % ", ".join(rest_detail))
	var lock_ok: bool = true
	for merc: MercenaryData in run.living_team():
		if merc.rest_lockout_kind != "respite" or RestSystem.is_deployable(merc):
			lock_ok = false
		if merc.rest_lockout_until != CampaignClock.now() + RestSystem.RESPITE_MINUTES:
			lock_ok = false
	TestFixtures.check(res, "manager_rest_lockout", lock_ok,
		"living %d clock %d" % [run.living_team().size(), CampaignClock.now()])
	var events_done: int = run.outcomes.size()
	var want_minutes: int = 2 * CampaignClock.TRAVEL_MINUTES + CampaignClock.EVENT_MINUTES * events_done \
		+ CampaignClock.EVENT_GAP_MINUTES * maxi(0, events_done - 1)
	TestFixtures.check(res, "manager_clock", CampaignClock.now() == want_minutes,
		"clock %d want %d after %d events" % [CampaignClock.now(), want_minutes, events_done])
	var gap_at: int = _index_of_prefix(run.log_lines, "CLOCK: between events ")
	var gap_rested: bool = false
	if gap_at >= 0:
		for i: int in range(gap_at + 1, run.log_lines.size()):
			var line: String = run.log_lines[i]
			if line.begins_with("CLOCK: "):
				break
			if line.begins_with("RESPITE: ") or line.begins_with("BREATHER: "):
				gap_rested = true
				break
	TestFixtures.check(res, "manager_between_events_rest",
		(gap_at >= 0) == (events_done >= 2) and (gap_at < 0 or gap_rested),
		"gap line %d rested %s events %d" % [gap_at, str(gap_rested), events_done])
	var back_at: int = _index_of_prefix(run.log_lines, "CLOCK: travel back ")
	var first_respite: int = _index_of_prefix(run.log_lines, "RESPITE: ")
	var primary_rested: bool = run.living_team().is_empty() \
		or (first_respite >= 0 and back_at >= 0 and first_respite < back_at)
	TestFixtures.check(res, "manager_primary_respite", primary_rested,
		"respite line %d travel back %d living %d" % [first_respite, back_at, run.living_team().size()])
	var record_empty: bool = (run.modifier_record.get("stats", {}) as Dictionary).is_empty() and (run.modifier_record.get("circ", {}) as Dictionary).is_empty()
	var combat_ok: bool = true
	for merc: MercenaryData in run.living_team():
		if absf(float(merc.stats.get("combat", 0.0)) - float(combat_before.get(merc, 0.0))) >= 0.001:
			combat_ok = false
	TestFixtures.check(res, "manager_boosts_reverted", record_empty and combat_ok,
		"record empty %s combat restored %s" % [str(record_empty), str(combat_ok)])
	TestFixtures.check(res, "manager_penalties", run.penalties_by_merc.size() == 3, "entries %d" % run.penalties_by_merc.size())
	TestFixtures.check(res, "manager_team_uids", contract.team_uids.size() == 3, "uids %d" % contract.team_uids.size())
	TestFixtures.check(res, "manager_encounter_logs", run.encounter_logs.size() == run.outcomes.size(),
		"logs %d outcomes %d" % [run.encounter_logs.size(), run.outcomes.size()])
	var has_verdict_line: bool = false
	var log_path: String = ""
	for line: String in run.log_lines:
		if line.begins_with("CONTRACT SUCCESS") or line.begins_with("CONTRACT FAILED"):
			has_verdict_line = true
		if line.begins_with("CONTRACT LOG: "):
			log_path = line.substr("CONTRACT LOG: ".length())
	TestFixtures.check(res, "manager_log_lines", has_verdict_line and log_path != "",
		"verdict line %s log %s" % [str(has_verdict_line), log_path])
	TestFixtures.check(res, "manager_log_file", log_path != "" and FileAccess.file_exists(log_path), "path %s" % log_path)


static func _case_log_write(res: Dictionary) -> void:
	var r := ContractRun.new()
	r.log_lines.assign(["alpha", "beta"])
	var path: String = ContractLog.write(r)
	TestFixtures.check(res, "log_write_name",
		path != "" and path.get_file().begins_with("contract_log_") and path.ends_with(".txt"),
		"path %s" % path)
	var text: String = FileAccess.get_file_as_string(path) if path != "" else ""
	TestFixtures.check(res, "log_write_content", text == "alpha\nbeta\n", "text %s" % text.replace("\n", "|"))


static func _case_merc_line(res: Dictionary) -> void:
	var merc: MercenaryData = MercGenerator.generate(0)
	var want: String = "%s L%d %s" % [merc.merc_name, int(merc.stats.get("level", 0)), _trad_name(merc)]
	TestFixtures.check(res, "merc_line_generated", ContractLog.merc_line(merc) == want, "line %s" % ContractLog.merc_line(merc))
	var empty := MercenaryData.new()
	empty.merc_name = "Nobody"
	TestFixtures.check(res, "merc_line_npc", ContractLog.merc_line(empty) == "Nobody L0 NPC", "line %s" % ContractLog.merc_line(empty))


static func _case_manager_end_rest(res: Dictionary) -> void:
	CampaignClock.reset()
	var merc: MercenaryData = MercGenerator.generate(0)
	var max_hp: int = int(merc.stats.get("maximum_hit_points", 0))
	var max_ep: int = int(merc.stats.get("maximum_endurance_points", 0))
	var max_mp: int = int(merc.stats.get("maximum_magic_points", 0))
	merc.current_hp = 1
	merc.current_ep = 0
	merc.current_mp = 0
	merc.excess_hp = 2
	merc.excess_ep = 1
	var r := ContractRun.new()
	r.contract = ContractGenerator.generate("Military")
	r.team.append(merc)
	ContractManager.end(r)
	var want_hp: int = maxi(1, _hp_cap(merc))
	TestFixtures.check(res, "manager_end_respite",
		max_hp > 0 and merc.current_hp == want_hp and merc.current_ep == max_ep and merc.current_mp == max_mp,
		"hp %d/%d want %d, ep %d/%d, mp %d/%d" % [merc.current_hp, max_hp, want_hp,
		merc.current_ep, max_ep, merc.current_mp, max_mp])
	TestFixtures.check(res, "manager_end_lockout",
		merc.rest_lockout_kind == "respite" and not RestSystem.is_deployable(merc)
		and merc.rest_lockout_until == CampaignClock.now() + RestSystem.RESPITE_MINUTES,
		"kind %s until %d clock %d" % [merc.rest_lockout_kind, merc.rest_lockout_until, CampaignClock.now()])
	var lost_at: int = _index_of_prefix(r.log_lines, "EXCESS LOST: ")
	var lost_line: String = r.log_lines[lost_at] if lost_at >= 0 else ""
	TestFixtures.check(res, "manager_end_excess_cleared",
		merc.excess_hp == 0 and lost_line.contains("2 ExHP, 1 ExEP") and lost_line.ends_with("(contract return)"),
		"excess hp %d line %s" % [merc.excess_hp, lost_line])
	TestFixtures.check(res, "manager_end_travel",
		CampaignClock.now() == CampaignClock.TRAVEL_MINUTES and not merc.on_contract,
		"clock %d on contract %s" % [CampaignClock.now(), str(merc.on_contract)])
	TestFixtures.check(res, "manager_end_no_events",
		r.verdict == "Failed" and r.reward_paid == 0 and r.contract.status == "Failed",
		"verdict %s reward %d status %s" % [r.verdict, r.reward_paid, r.contract.status])


#The six hour gap between two events: a wounded party takes a Respite, a tired one a Breather.
static func _case_between_events(res: Dictionary) -> void:
	CampaignClock.reset()
	var team: Array[MercenaryData] = []
	for i: int in range(2):
		var merc: MercenaryData = MercGenerator.generate(i)
		merc.current_hp = int(merc.stats.get("maximum_hit_points", 0))
		merc.current_ep = int(merc.stats.get("maximum_endurance_points", 0))
		team.append(merc)
	var config: ContractConfig = ContractLibrary.config()
	team[0].current_hp = 1
	var wounded := ContractRun.new()
	wounded.team.assign(team)
	ContractManager._between_events(wounded)
	TestFixtures.check(res, "between_events_clock", CampaignClock.now() == CampaignClock.EVENT_GAP_MINUTES,
		"clock %d want %d" % [CampaignClock.now(), CampaignClock.EVENT_GAP_MINUTES])
	var got_respite: bool = _index_of_prefix(wounded.log_lines, "RESPITE: ") >= 0
	TestFixtures.check(res, "between_events_respite", got_respite == config.respite_between_events,
		"respite line %s flag %s lines %d" % [str(got_respite), str(config.respite_between_events), wounded.log_lines.size()])
	TestFixtures.check(res, "between_events_hp_topped",
		not config.respite_between_events or team[0].current_hp == maxi(1, _hp_cap(team[0])),
		"hp %d cap %d" % [team[0].current_hp, _hp_cap(team[0])])
	for merc: MercenaryData in team:
		merc.current_hp = int(merc.stats.get("maximum_hit_points", 0))
		merc.current_ep = 0
	var tired := ContractRun.new()
	tired.team.assign(team)
	var wants: bool = false
	for merc: MercenaryData in team:
		if RestSystem.wants_breather(merc, ContractManager.urgency_for(tired)):
			wants = true
	ContractManager._between_events(tired)
	var got_breather: bool = _index_of_prefix(tired.log_lines, "BREATHER: ") >= 0
	TestFixtures.check(res, "between_events_breather",
		got_breather == (config.breather_between_events and wants)
		and _index_of_prefix(tired.log_lines, "RESPITE: ") < 0,
		"breather line %s flag %s wants %s" % [str(got_breather), str(config.breather_between_events), str(wants)])


#The Respite hit-point ceiling for this merc: half of maximum, scaled by Rest Recovery.
static func _hp_cap(merc: MercenaryData) -> int:
	var max_hp: int = int(merc.stats.get("maximum_hit_points", 0))
	return int(floor(float(max_hp) * RestSystem.cap_fraction(merc, RestSystem.PARTIAL_CAP)))


static func _index_of_prefix(lines: Array[String], prefix: String) -> int:
	for i: int in range(lines.size()):
		if lines[i].begins_with(prefix):
			return i
	return -1


static func _case_wireframe_keys(res: Dictionary) -> void:
	var f := BattlefieldArea.new()
	f.width = 8
	f.length = 8
	f.height = 4
	f.building_interiors[Vector2i(2, 3)] = true
	f.building_interiors[Vector3i(4, 5, 1)] = true
	var data: Dictionary = HtmlWireframeGenerator._extract_data(f)
	var bi: Array = data.get("building_interiors", []) as Array
	TestFixtures.check(res, "wireframe_building_keys", bi.size() == 2 and bi.has([2, 3, 0]) and bi.has([4, 5, 1]), "entries %s" % str(bi))
