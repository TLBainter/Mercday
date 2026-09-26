class_name ContractTests

#Contract data, penalty, modifier and Overall Success cases.
#Run: godot --headless --path . -- --contract-tests


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_build(res)
	_case_builder_military(res)
	_case_builder_entertain(res)
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
	_case_terrain_odds(res)
	_case_enemy_counter(res)
	_case_carry_and_casualties(res)
	_case_forced_generation(res)
	_case_enemy_team(res)
	_case_mishap_roller(res)
	_case_formula_eval(res)
	_case_run_helpers(res)
	_case_field_for(res)
	_case_log_path(res)
	_case_generator(res)
	_case_generator_locations(res)
	await _case_manager_flow(res)
	_case_manager_end_rest(res)
	await _case_between_events(res)
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
	TestFixtures.check(res, "build_event_count", int(out["events"]) == 19, "events %d" % int(out["events"]))
	var texts: Array[String] = ContractResourceBuilder.last_warnings
	#Known TSV data gaps; tighten to warnings == 0 once the designer fills these cells.
	var allowed: Array[String] = [
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


static func _case_builder_entertain(res: Dictionary) -> void:
	var c: ContractData = ContractLibrary.contract_type("Entertain")
	if c == null:
		TestFixtures.check(res, "builder_entertain", false, "Entertain contract resource did not load")
		return
	TestFixtures.check(res, "builder_entertain_primary_pool",
		_names_eq(c.primary_event_pool, ["Put on a Show", "Competition"]),
		"primary pool %s" % str(c.primary_event_pool))


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
	var envs: Dictionary = {
		"Cathistii": "Desert", "Austyg": "Snowy", "Umbra": "Cavern", "Gledd Sea": "Sea",
	}
	var bad_env: Array[String] = []
	for loc_name: String in envs:
		var loc: LocationData = DataManager.locations.get(loc_name, null) as LocationData
		var got: String = ContractTerrain.terrain_environment(loc)
		if got != String(envs[loc_name]):
			bad_env.append("%s '%s' != '%s'" % [loc_name, got, String(envs[loc_name])])
	var orphan := LocationData.new()
	orphan.location_name = "TEST Nowhere"
	if ContractTerrain.terrain_environment(orphan) != "":
		bad_env.append("orphan '%s' != ''" % ContractTerrain.terrain_environment(orphan))
	TestFixtures.check(res, "terrain_environment", bad_env.is_empty(),
		"5 environments as expected" if bad_env.is_empty() else ", ".join(bad_env))
	var expected: Dictionary = {
		"Aerdis": "Desert Plain 100, Cavern 5",
		"Umbra": "Cavern 100",
		"Rossade": "Arctic Mountain 100, Cavern 20",
		"Miliim": "Desert Plain 100",
		"Cyfrolaef": "Desert Plain 40",
		"Gledd Sea": "",
		"Spectral": "",
	}
	var bad: Array[String] = []
	for loc_name: String in expected:
		var loc: LocationData = DataManager.locations.get(loc_name, null) as LocationData
		var got: String = ContractTerrain.weights_text(ContractTerrain.candidates(loc))
		if got != String(expected[loc_name]):
			bad.append("%s '%s' != '%s'" % [loc_name, got, String(expected[loc_name])])
	TestFixtures.check(res, "terrain_candidates", bad.is_empty(),
		"all 7 locations map as expected" if bad.is_empty() else ", ".join(bad))
	var aerdis: LocationData = DataManager.locations.get("Aerdis", null) as LocationData
	var sea: LocationData = DataManager.locations.get("Gledd Sea", null) as LocationData
	var desc_a: String = ContractTerrain.describe(aerdis)
	var desc_b: String = ContractTerrain.describe(sea)
	TestFixtures.check(res, "terrain_describe",
		desc_a == "Desert: Desert Plain 100, Cavern 5" and desc_b == "none",
		"Aerdis '%s' Gledd Sea '%s'" % [desc_a, desc_b])
	var cavern_envs: Dictionary = DataManager.get_area_by_name("Cavern").get("environments", {}) as Dictionary
	var tavern_envs: Dictionary = DataManager.get_area_by_name("Tavern").get("environments", {}) as Dictionary
	TestFixtures.check(res, "terrain_environments_parse",
		int(cavern_envs.get("cavern", 0)) == 100 and int(cavern_envs.get("mountain", 0)) == 20
			and tavern_envs.is_empty(),
		"cavern %s tavern %s" % [str(cavern_envs), str(tavern_envs)])


static func _terrain_odds(entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Array in entries:
		out.append({"area": String(entry[0]), "percent": int(entry[1])})
	return out


static func _case_terrain_odds(res: Dictionary) -> void:
	var parsed: Array[Dictionary] = ContractTerrain.parse_odds("Cavern 15, Desert Plain 5")
	var parse_ok: bool = parsed.size() == 2 \
		and String(parsed[0]["area"]) == "Cavern" and int(parsed[0]["percent"]) == 15 \
		and String(parsed[1]["area"]) == "Desert Plain" and int(parsed[1]["percent"]) == 5 \
		and ContractTerrain.parse_odds("").is_empty()
	var bare: Array[Dictionary] = ContractTerrain.parse_odds("Cavern")
	var junk: Array[Dictionary] = ContractTerrain.parse_odds("Cavern x")
	parse_ok = parse_ok and bare.size() == 1 and String(bare[0]["area"]) == "Cavern" \
		and int(bare[0]["percent"]) == -1 and junk.size() == 1 \
		and String(junk[0]["area"]) == "Cavern x" and int(junk[0]["percent"]) == -1
	TestFixtures.check(res, "odds_parse", parse_ok, "parsed %s bare %s junk %s" % [str(parsed), str(bare), str(junk)])
	var military: ContractData = ContractLibrary.contract_type("Military")
	var built_ok: bool = military != null and military.terrain_odds.size() == 1 \
		and String(military.terrain_odds[0]["area"]) == "Cavern" \
		and int(military.terrain_odds[0]["percent"]) == 15
	TestFixtures.check(res, "odds_built", built_ok,
		"odds %s" % ("null" if military == null else str(military.terrain_odds)))
	var probe := ContractData.new()
	probe.contract_type = "TEST Odds"
	probe.terrain_odds = _terrain_odds([["Nowhere", 10], ["Cavern", 0], ["Tavern", 50]])
	var warnings: Array[String] = ContractDataValidator.validate_contract(probe, {"_row": 99})
	var odds_warnings: int = 0
	for text: String in warnings:
		if text.find("column Terrain Odds") >= 0:
			odds_warnings += 1
	TestFixtures.check(res, "odds_validator", odds_warnings == 3 and warnings.size() == 3,
		"%d Terrain Odds warning(s) of %d" % [odds_warnings, warnings.size()])
	var rossade: LocationData = DataManager.locations.get("Rossade", null) as LocationData
	var forced := ContractData.new()
	forced.contract_type = "TEST Forced"
	forced.terrain_odds = _terrain_odds([["Cavern", 100]])
	var open_odds := ContractData.new()
	open_odds.contract_type = "TEST Open"
	open_odds.terrain_odds = _terrain_odds([["Desert Plain", 100]])
	var cavern_hits: int = 0
	var plain_hits: int = 0
	for _i: int in range(50):
		if String((ContractTerrain.draw(rossade, forced)["area"] as Dictionary).get("name", "")) == "Cavern":
			cavern_hits += 1
		if String((ContractTerrain.draw(rossade, open_odds)["area"] as Dictionary).get("name", "")) == "Desert Plain":
			plain_hits += 1
	var skirmish: EventData = ContractLibrary.event("Assist with the Skirmish")
	var field: BattlefieldArea = ContractTerrain.field_for(skirmish, rossade, 3, 3, forced)
	TestFixtures.check(res, "odds_force", cavern_hits == 50 and plain_hits == 50 and field.is_cavern,
		"cavern %d/50 plain %d/50 field %s" % [cavern_hits, plain_hits, field.area_name])
	var no_odds := ContractData.new()
	no_odds.contract_type = "TEST None"
	var off_pool: String = ""
	for _i: int in range(50):
		var drawn: String = String((ContractTerrain.draw(rossade, no_odds)["area"] as Dictionary).get("name", ""))
		if drawn != "Arctic Mountain" and drawn != "Cavern":
			off_pool = drawn
			break
	TestFixtures.check(res, "odds_none", off_pool == "",
		"50 draws in pool" if off_pool == "" else "drew %s" % off_pool)
	var caverns: int = 0
	for _i: int in range(300):
		if String((ContractTerrain.draw(rossade, null)["area"] as Dictionary).get("name", "")) == "Cavern":
			caverns += 1
	var share: float = float(caverns) / 3.0
	TestFixtures.check(res, "draw_statistics", share >= 5.0 and share <= 35.0,
		"cavern share %.1f%% of 300 draws" % share)


static func _case_enemy_counter(res: Dictionary) -> void:
	var ctx: Dictionary = {"merc_count": 3, "average_level": 5.0, "bad_luck_roll": 0}
	var a: int = OpponentGenerator.eval_count("party.merc_count + 2", ctx)
	TestFixtures.check(res, "enemy_counter_plus_two", a == 5, "count %d" % a)
	var ctx2: Dictionary = {"merc_count": 3, "average_level": 5.0, "bad_luck_roll": 2}
	var b: int = OpponentGenerator.eval_count("party.merc_count + bad_luck_roll", ctx2)
	TestFixtures.check(res, "enemy_counter_bad_luck", b == 5, "count %d" % b)
	var c: int = OpponentGenerator.eval_count("0", ctx)
	TestFixtures.check(res, "enemy_counter_floor_one", c == 1, "count %d" % c)
	var d: int = OpponentGenerator.eval_count("party.average_level / 2", ctx)
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
	var contract_run: ContractRun = _contract_run("Military", 3, 5)
	var skirmish: EventData = ContractLibrary.event("Assist with the Skirmish")
	var mercs: Array[MercenaryData] = EnemyTeamBuilder.build(skirmish, contract_run, 0)
	TestFixtures.check(res, "enemy_team_merc_count", mercs.size() == 5, "enemies %d" % mercs.size())
	var avg: float = float(PartyStats.context(contract_run.living_team())["average_level"])
	var lo: int = maxi(1, int(floorf(avg * 0.5)))
	var hi: int = maxi(1, int(floorf(avg * 2.0)))
	var levels_ok: bool = true
	var trads_ok: bool = mercs.size() == 5
	var detail: Array[String] = []
	for i: int in range(mercs.size()):
		var lvl: int = int(mercs[i].stats.get("level", -1))
		if lvl < lo or lvl > hi:
			levels_ok = false
		var want: String = "Brave" if i == 0 else "Warrior"
		if _trad_name(mercs[i]) != want:
			trads_ok = false
		detail.append("L%d %s" % [lvl, _trad_name(mercs[i])])
	TestFixtures.check(res, "enemy_team_merc_levels", levels_ok,
		"enemies %s against a band of %d to %d" % [", ".join(detail), lo, hi])
	TestFixtures.check(res, "enemy_team_merc_traditions", trads_ok, "enemies %s" % ", ".join(detail))
	TestFixtures.check(res, "enemy_team_statics_reset",
		MercGenerator.forced_level == -1 and MercGenerator.forced_tradition == ""
		and MercGenerator.tradition_odds.is_empty(),
		"forced_level %d forced_tradition '%s' odds %s"
		% [MercGenerator.forced_level, MercGenerator.forced_tradition, str(MercGenerator.tradition_odds)])
	var brawl: EventData = ContractLibrary.event("Tavern Brawl")
	var npcs: Array[MercenaryData] = EnemyTeamBuilder.build(brawl, contract_run, 2)
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
	var contract_run: ContractRun = _contract_run("Military", 3, 0)
	var doomed: MercenaryData = contract_run.team[1]
	doomed.is_dead = true
	TestFixtures.check(res, "run_living_team", contract_run.living_team().size() == 2,
		"living %d" % contract_run.living_team().size())
	var dead: Array[MercenaryData] = [doomed]
	var moved: Array[MercenaryData] = contract_run.remove_dead(dead)
	TestFixtures.check(res, "run_remove_dead",
		moved.size() == 1 and contract_run.team.size() == 2 and contract_run.casualties.size() == 1,
		"moved %d team %d casualties %d" % [moved.size(), contract_run.team.size(), contract_run.casualties.size()])
	var got: Array[String] = []
	contract_run.line_fn = func(line: String) -> void: got.append(line)
	contract_run.emit("x")
	TestFixtures.check(res, "run_emit", contract_run.log_lines.has("x") and got.size() == 1 and got[0] == "x",
		"log_lines %d collected %s" % [contract_run.log_lines.size(), str(got)])


static func _case_field_for(res: Dictionary) -> void:
	var aerdis: LocationData = DataManager.locations.get("Aerdis", null) as LocationData
	var austyg: LocationData = DataManager.locations.get("Austyg", null) as LocationData
	var cathistii: LocationData = DataManager.locations.get("Cathistii", null) as LocationData
	var brawl: EventData = ContractLibrary.event("Tavern Brawl")
	var skirmish: EventData = ContractLibrary.event("Assist with the Skirmish")
	var umbra: LocationData = DataManager.locations.get("Umbra", null) as LocationData
	var plain_odds := ContractData.new()
	plain_odds.contract_type = "TEST Plain"
	plain_odds.terrain_odds = _terrain_odds([["Desert Plain", 100]])
	var cavern_odds := ContractData.new()
	cavern_odds.contract_type = "TEST Cavern"
	cavern_odds.terrain_odds = _terrain_odds([["Cavern", 100]])
	var interior: BattlefieldArea = ContractTerrain.field_for(brawl, aerdis, 3, 3)
	TestFixtures.check(res, "field_for_interior", interior.is_interior_map and interior.area_name == "Tavern",
		"interior %s area %s" % [str(interior.is_interior_map), interior.area_name])
	var forced_plain: BattlefieldArea = ContractTerrain.field_for(skirmish, aerdis, 3, 3, plain_odds)
	TestFixtures.check(res, "field_for_forced_plain",
		not forced_plain.is_interior_map and not forced_plain.is_cavern
			and forced_plain.area_name == "Desert Plain",
		"interior %s cavern %s area %s" % [str(forced_plain.is_interior_map),
			str(forced_plain.is_cavern), forced_plain.area_name])
	var forced_cavern: BattlefieldArea = ContractTerrain.field_for(skirmish, austyg, 3, 3, cavern_odds)
	TestFixtures.check(res, "field_for_forced_cavern", forced_cavern.is_cavern,
		"cavern %s area %s" % [str(forced_cavern.is_cavern), forced_cavern.area_name])
	var cavern_place: BattlefieldArea = ContractTerrain.field_for(skirmish, umbra, 3, 3)
	TestFixtures.check(res, "field_for_cavern_location", cavern_place.is_cavern,
		"cavern %s area %s" % [str(cavern_place.is_cavern), cavern_place.area_name])
	var parent: BattlefieldArea = ContractTerrain.field_for(skirmish, cathistii, 3, 3, plain_odds)
	TestFixtures.check(res, "field_for_parent_environment", parent.area_name == "Desert Plain",
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
	TestFixtures.check(res, "generator_location_a", a != null and ContractTerrain.has_terrain(a),
		"location_a %s terrain %s" % [c.location_a, ContractTerrain.describe(a)])
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
		if not ContractTerrain.has_terrain(loc) or not ContractGenerator._hosts_contracts(loc):
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
	GuildRoster.set_roster(team)
	var contract: ContractData = ContractGenerator.generate("Military")
	contract.unsavory = false
	var prelude: Array[String] = ["PRELUDE TEST LINE"]
	var contract_run: ContractRun = await ContractManager.run(contract, team, Callable(), prelude)
	#A triggered event (an Ambush during a respite) adds its own outcome; the flow checks count the scheduled ones.
	var scheduled: Array[Dictionary] = []
	for outcome: Dictionary in contract_run.outcomes:
		if not contract_run.triggered_events.has(String(outcome.get("event", ""))):
			scheduled.append(outcome)
	_check_manager_outcome(res, contract_run, contract, scheduled)
	_check_manager_team(res, contract_run, team.size())
	_check_manager_rest(res, contract_run)
	_check_manager_clock(res, contract_run, scheduled.size())
	var record_empty: bool = (contract_run.modifier_record.get("stats", {}) as Dictionary).is_empty() and (contract_run.modifier_record.get("circ", {}) as Dictionary).is_empty()
	var combat_ok: bool = true
	for merc: MercenaryData in contract_run.living_team():
		if absf(float(merc.stats.get("combat", 0.0)) - float(combat_before.get(merc, 0.0))) >= 0.001:
			combat_ok = false
	TestFixtures.check(res, "manager_boosts_reverted", record_empty and combat_ok,
		"record empty %s combat restored %s" % [str(record_empty), str(combat_ok)])
	TestFixtures.check(res, "manager_penalties", contract_run.penalties_by_merc.size() == 3,
		"entries %d" % contract_run.penalties_by_merc.size())
	TestFixtures.check(res, "manager_team_uids", contract.team_uids.size() == 3, "uids %d" % contract.team_uids.size())
	#An event settled without a battle (a respite kidnapping) has an outcome and no encounter log.
	var fought: int = 0
	for outcome: Dictionary in contract_run.outcomes:
		if String(outcome.get("log_file", "")) != "":
			fought += 1
	TestFixtures.check(res, "manager_encounter_logs", contract_run.encounter_logs.size() == fought,
		"logs %d fought %d outcomes %d" % [contract_run.encounter_logs.size(), fought, contract_run.outcomes.size()])
	var has_verdict_line: bool = false
	var log_path: String = ""
	for line: String in contract_run.log_lines:
		if line.begins_with("CONTRACT SUCCESS") or line.begins_with("CONTRACT FAILED"):
			has_verdict_line = true
		if line.begins_with("CONTRACT LOG: "):
			log_path = line.substr("CONTRACT LOG: ".length())
	TestFixtures.check(res, "manager_log_lines", has_verdict_line and log_path != "",
		"verdict line %s log %s" % [str(has_verdict_line), log_path])
	TestFixtures.check(res, "manager_log_file", log_path != "" and FileAccess.file_exists(log_path), "path %s" % log_path)


#Prelude, verdict, contract status, the scheduled events and the reward the verdict pays.
static func _check_manager_outcome(res: Dictionary, contract_run: ContractRun, contract: ContractData,
		scheduled: Array[Dictionary]) -> void:
	TestFixtures.check(res, "manager_prelude_logged",
		contract_run.log_lines.size() > 0 and contract_run.log_lines[0] == "PRELUDE TEST LINE",
		"first line %s" % (contract_run.log_lines[0] if not contract_run.log_lines.is_empty() else "none"))
	TestFixtures.check(res, "manager_verdict",
		contract_run.verdict == "Succeeded" or contract_run.verdict == "Failed",
		"verdict %s" % contract_run.verdict)
	TestFixtures.check(res, "manager_status", contract.status == contract_run.verdict, "status %s verdict %s" % [contract.status, contract_run.verdict])
	TestFixtures.check(res, "manager_first_event",
		contract_run.outcomes.size() >= 1 and String(contract_run.outcomes[0].get("event", "")) == "Tavern Brawl",
		"outcomes %d first %s" % [contract_run.outcomes.size(), "none" if contract_run.outcomes.is_empty() else String(contract_run.outcomes[0].get("event", ""))])
	var second_ok: bool = false
	if scheduled.size() == 2:
		second_ok = String(scheduled[1].get("event", "")) == "Assist with the Skirmish"
	else:
		second_ok = contract_run.failed_event == "Tavern Brawl" or contract_run.triggered_events.has(contract_run.failed_event)
	TestFixtures.check(res, "manager_primary_event", second_ok,
		"outcomes %d scheduled %d failed_event %s" % [contract_run.outcomes.size(), scheduled.size(), contract_run.failed_event])
	var primary_success: bool = false
	for outcome: Dictionary in contract_run.outcomes:
		if String(outcome.get("event", "")) == "Assist with the Skirmish" and bool(outcome.get("success", false)):
			primary_success = true
	TestFixtures.check(res, "manager_verdict_rule", (contract_run.verdict == "Succeeded") == primary_success,
		"verdict %s primary success %s" % [contract_run.verdict, str(primary_success)])
	var want_reward: int = 300 if contract_run.verdict == "Succeeded" else 0
	TestFixtures.check(res, "manager_reward", contract_run.reward_paid == want_reward,
		"reward %d want %d" % [contract_run.reward_paid, want_reward])


#The source team splits across survivors, casualties, departures, defectors and captives.
static func _check_manager_team(res: Dictionary, contract_run: ContractRun, source: int) -> void:
	TestFixtures.check(res, "manager_team_split",
		contract_run.team.size() + contract_run.casualties.size() + contract_run.departed.size() + contract_run.defectors.size()
		+ contract_run.kidnapped.size() == 3 and source == 3,
		"team %d casualties %d departed %d defectors %d kidnapped %d source %d" % [contract_run.team.size(),
		contract_run.casualties.size(), contract_run.departed.size(), contract_run.defectors.size(), contract_run.kidnapped.size(),
		source])
	var dead_ok: bool = true
	for merc: MercenaryData in contract_run.casualties:
		if not merc.is_dead:
			dead_ok = false
	TestFixtures.check(res, "manager_casualties_dead", dead_ok, "casualties %d" % contract_run.casualties.size())


#Every survivor comes back healed to its cap and locked out for the respite.
static func _check_manager_rest(res: Dictionary, contract_run: ContractRun) -> void:
	var rest_ok: bool = true
	var rest_detail: Array[String] = []
	for merc: MercenaryData in contract_run.living_team():
		var max_hp: int = int(merc.stats.get("maximum_hit_points", 0))
		var cap_hp: int = _hp_cap(merc)
		var full_ep: bool = merc.current_ep == int(merc.stats.get("maximum_endurance_points", 0))
		if merc.current_hp < cap_hp or merc.current_hp > max_hp or not full_ep:
			rest_ok = false
		rest_detail.append("%d/%d cap %d ep %d" % [merc.current_hp, max_hp, cap_hp, merc.current_ep])
	TestFixtures.check(res, "manager_rest_respite", rest_ok, "hp %s" % ", ".join(rest_detail))
	var lock_ok: bool = true
	for merc: MercenaryData in contract_run.living_team():
		if merc.rest_lockout_kind != "respite" or RestSystem.is_deployable(merc):
			lock_ok = false
		var want_until: int = CampaignClock.now() + RestSystem.rest_minutes(merc, RestSystem.RESPITE_MINUTES)
		if merc.rest_lockout_until != want_until:
			lock_ok = false
	TestFixtures.check(res, "manager_rest_lockout", lock_ok,
		"living %d clock %d" % [contract_run.living_team().size(), CampaignClock.now()])


#The CLOCK lines add up to the campaign clock and carry the gap and respite rests.
static func _check_manager_clock(res: Dictionary, contract_run: ContractRun, events_done: int) -> void:
	var clock_sum: int = 0
	var gap_lines: int = 0
	var gaps_moved: bool = true
	var respite_lines: int = 0
	var respite_delta: int = 0
	for entry: String in contract_run.log_lines:
		if not entry.begins_with("CLOCK: "):
			continue
		var delta: int = _clock_delta(entry)
		clock_sum += delta
		if entry.begins_with("CLOCK: between events"):
			gap_lines += 1
			if delta < 1:
				gaps_moved = false
		elif entry.begins_with("CLOCK: respite "):
			respite_lines += 1
			respite_delta = delta
	var floor_minutes: int = 2 * CampaignClock.TRAVEL_MINUTES + CampaignClock.EVENT_MINUTES * events_done
	TestFixtures.check(res, "manager_clock",
		CampaignClock.now() == clock_sum and clock_sum >= floor_minutes,
		"clock %d sum %d floor %d after %d events" % [CampaignClock.now(), clock_sum, floor_minutes, events_done])
	TestFixtures.check(res, "manager_clock_gaps",
		gap_lines == maxi(0, events_done - 1) and gaps_moved,
		"gap lines %d events %d moved %s" % [gap_lines, events_done, str(gaps_moved)])
	var primary_ran: bool = false
	for outcome: Dictionary in contract_run.outcomes:
		if String(outcome.get("event_type", "")) == "Primary":
			primary_ran = true
	var want_respite: bool = primary_ran and not contract_run.living_team().is_empty()
	#The Military Avoid boost moves rest_recovery until end() reverts it, so the REST TIME line is the witness.
	var rest_time_delta: int = 0
	var respite_at: int = _index_of_prefix(contract_run.log_lines, "CLOCK: respite ")
	if respite_at >= 0:
		for i: int in range(respite_at + 1, contract_run.log_lines.size()):
			var line: String = contract_run.log_lines[i]
			if line.begins_with("REST TIME: "):
				rest_time_delta = _rest_time_minutes(line)
				break
			if line.begins_with("CLOCK: ") and not _triggered_clock(line, contract_run):
				break
	TestFixtures.check(res, "manager_clock_respite",
		respite_lines == (1 if want_respite else 0)
		and (not want_respite or (respite_delta >= 1 and respite_delta == rest_time_delta)),
		"lines %d delta %d rest time %d primary %s" % [respite_lines, respite_delta, rest_time_delta,
		str(primary_ran)])
	var gap_at: int = _index_of_prefix(contract_run.log_lines, "CLOCK: between events")
	var gap_rests: bool = gap_at >= 0 and contract_run.log_lines[gap_at].contains("(")
	var gap_rested: bool = false
	if gap_at >= 0:
		for i: int in range(gap_at + 1, contract_run.log_lines.size()):
			var line: String = contract_run.log_lines[i]
			if line.begins_with("CLOCK: ") and not _triggered_clock(line, contract_run):
				break
			if line.begins_with("REST TIME: ") or line.begins_with("RESPITE: ") or line.begins_with("BREATHER: "):
				gap_rested = true
				break
	TestFixtures.check(res, "manager_between_events_rest",
		(gap_at >= 0) == (events_done >= 2) and gap_rested == gap_rests,
		"gap line %d rested %s events %d" % [gap_at, str(gap_rested), events_done])
	var back_at: int = _index_of_prefix(contract_run.log_lines, "CLOCK: travel back ")
	var first_respite: int = _index_of_prefix(contract_run.log_lines, "RESPITE: ")
	var primary_rested: bool = contract_run.living_team().is_empty() \
		or (first_respite >= 0 and back_at >= 0 and first_respite < back_at)
	TestFixtures.check(res, "manager_primary_respite", primary_rested,
		"respite line %d travel back %d living %d" % [first_respite, back_at, contract_run.living_team().size()])


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
	GuildRoster.set_roster([merc] as Array[MercenaryData])
	r.contract = ContractGenerator.generate("Military")
	r.team.append(merc)
	ContractManager.end(r)
	var want_hp: int = maxi(1, _hp_cap(merc))
	TestFixtures.check(res, "manager_end_respite",
		max_hp > 0 and merc.current_hp == 1 and merc.current_ep == 0 and merc.current_mp == 0,
		"hp %d/%d, ep %d/%d, mp %d/%d" % [merc.current_hp, max_hp,
		merc.current_ep, max_ep, merc.current_mp, max_mp])
	TestFixtures.check(res, "manager_end_lockout",
		merc.rest_lockout_kind == "respite" and not RestSystem.is_deployable(merc)
		and merc.rest_lockout_until == CampaignClock.now()
		+ RestSystem.rest_minutes(merc, RestSystem.RESPITE_MINUTES),
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
	var solo: Array[MercenaryData] = [merc]
	CampaignClock.advance_to(merc.rest_lockout_until)
	var done: Array[String] = RestSystem.complete_due_rests(solo, CampaignClock.now())
	TestFixtures.check(res, "manager_end_respite_completes",
		merc.current_hp >= want_hp and merc.current_hp <= maxi(1, max_hp)
		and merc.current_ep == max_ep and merc.current_mp == max_mp
		and _index_of_prefix(done, "RESPITE: ") >= 0,
		"hp %d want %d, ep %d/%d, mp %d/%d, lines %d" % [merc.current_hp, want_hp,
		merc.current_ep, max_ep, merc.current_mp, max_mp, done.size()])
	TestFixtures.check(res, "manager_end_lockout_cleared",
		merc.rest_lockout_kind == "" and merc.rest_lockout_until == 0
		and RestSystem.is_deployable(merc),
		"kind %s until %d" % [merc.rest_lockout_kind, merc.rest_lockout_until])


#The gap between two events: a wounded party takes a Respite, a tired one a Breather.
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
	await ContractManager.between_events(wounded)
	var want_gap: int = CampaignClock.EVENT_GAP_MINUTES
	if config.respite_between_events:
		want_gap = RestSystem.party_rest_minutes(team, RestSystem.RESPITE_MINUTES)
	TestFixtures.check(res, "between_events_clock", CampaignClock.now() == want_gap,
		"clock %d want %d" % [CampaignClock.now(), want_gap])
	var rest_time_at: int = _index_of_prefix(wounded.log_lines, "REST TIME: respite ")
	TestFixtures.check(res, "between_events_rest_time",
		not config.respite_between_events or rest_time_at >= 0,
		"rest time line %d flag %s" % [rest_time_at, str(config.respite_between_events)])
	var got_respite: bool = _index_of_prefix(wounded.log_lines, "RESPITE: ") >= 0
	TestFixtures.check(res, "between_events_respite", got_respite == config.respite_between_events,
		"respite line %s flag %s lines %d" % [str(got_respite), str(config.respite_between_events), wounded.log_lines.size()])
	TestFixtures.check(res, "between_events_hp_topped",
		not config.respite_between_events or team[0].current_hp >= maxi(1, _hp_cap(team[0])),
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
	var before: int = CampaignClock.now()
	await ContractManager.between_events(tired)
	var got_breather: bool = _index_of_prefix(tired.log_lines, "BREATHER: ") >= 0
	TestFixtures.check(res, "between_events_breather",
		got_breather == (config.breather_between_events and wants)
		and _index_of_prefix(tired.log_lines, "RESPITE: ") < 0,
		"breather line %s flag %s wants %s" % [str(got_breather), str(config.breather_between_events), str(wants)])
	var want_breather_gap: int = CampaignClock.EVENT_GAP_MINUTES
	if config.breather_between_events:
		want_breather_gap = RestSystem.party_rest_minutes(team, RestSystem.BREATHER_MINUTES)
	TestFixtures.check(res, "between_events_breather_clock",
		CampaignClock.now() - before == want_breather_gap,
		"delta %d want %d" % [CampaignClock.now() - before, want_breather_gap])
	for merc: MercenaryData in team:
		merc.current_hp = int(merc.stats.get("maximum_hit_points", 0))
		merc.current_ep = int(merc.stats.get("maximum_endurance_points", 0))
	var wet: MercenaryData = team[0]
	ConstStates.apply_state(wet, ConstStates.DRENCHED)
	wet.campaign_states[ConstStates.DRENCHED] = CampaignClock.now() + 1
	var soaked := ContractRun.new()
	soaked.team.assign(team)
	await ContractManager.between_events(soaked)
	TestFixtures.check(res, "between_events_expires_due_states",
		not ConstStates.has_state(wet, ConstStates.DRENCHED),
		"states %s" % str(wet.active_states.keys()))
	var dried: bool = false
	for line: String in soaked.log_lines:
		if line.ends_with("dried up."):
			dried = true
	TestFixtures.check(res, "between_events_logs_the_expiry", dried,
		"lines %d drenched %s" % [soaked.log_lines.size(), str(wet.campaign_states.has(ConstStates.DRENCHED))])


#The Respite hit-point ceiling for this merc: half of maximum.
static func _hp_cap(merc: MercenaryData) -> int:
	var max_hp: int = int(merc.stats.get("maximum_hit_points", 0))
	return int(floor(float(max_hp) * RestSystem.PARTIAL_CAP))


static func _index_of_prefix(lines: Array[String], prefix: String) -> int:
	for i: int in range(lines.size()):
		if lines[i].begins_with(prefix):
			return i
	return -1


#A "CLOCK: <event> +1 h" line of a triggered event lands inside the rest it interrupted.
static func _triggered_clock(line: String, contract_run: ContractRun) -> bool:
	for event_name: String in contract_run.triggered_events:
		if line.begins_with("CLOCK: %s " % event_name):
			return true
	return false


#Minutes in a "CLOCK: tag +1 d 2 h -> stamp" line; 0 for a line that does not read as one.
static func _clock_delta(line: String) -> int:
	var arrow: int = line.find(" -> ")
	if arrow < 0:
		return 0
	var head: String = line.substr(0, arrow)
	var plus: int = head.rfind("+")
	if plus < 0:
		return 0
	return _sum_span(head.substr(plus + 1))


#Minutes on a "REST TIME: <kind> <span> (...)" line; 0 for a line that does not read as one.
static func _rest_time_minutes(line: String) -> int:
	if not line.begins_with("REST TIME: "):
		return 0
	var body: String = line.substr(11)
	var paren: int = body.find(" (")
	if paren >= 0:
		body = body.substr(0, paren)
	var space: int = body.find(" ")
	if space < 0:
		return 0
	return _sum_span(body.substr(space + 1))


#Every "<count> <unit>" pair of a compound span such as "8 d 8 h".
static func _sum_span(span: String) -> int:
	var parts: PackedStringArray = span.strip_edges().split(" ", false)
	var total: int = 0
	var i: int = 0
	while i + 1 < parts.size():
		total += _span_minutes(parts[i], parts[i + 1])
		i += 2
	return total


#Minutes for a CampaignClock.delta_text pair such as "4" and "h".
static func _span_minutes(count: String, unit: String) -> int:
	var scale: int = 0
	if unit == "d":
		scale = CampaignClock.MINUTES_PER_DAY
	elif unit == "h":
		scale = CampaignClock.MINUTES_PER_HOUR
	elif unit == "min":
		scale = 1
	return int(count) * scale
