class_name ContractTests

#Contract data, penalty, modifier and Overall Success cases.
#Run: godot --headless --path . -- --contract-tests


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_build(res)
	_case_old_sheet(res)
	_case_rows(res)
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
	_case_generator_mercs(res)
	_case_local_cell(res)
	_case_generator_locations(res)
	_case_location_pool(res)
	_case_local_home(res)
	_case_generate_for(res)
	_case_check_contract(res)
	_case_target_parse(res)
	_case_target_complete(res)
	_case_target_display(res)
	_case_description_pick(res)
	_case_fill_tags(res)
	_case_requestor_name(res)
	_case_target_name(res)
	_case_build_tags(res)
	await _case_manager_flow(res)
	_case_manager_end_rest(res)
	await _case_between_events(res)
	await _case_local_run(res)
	_case_log_write(res)
	_case_merc_line(res)
	_case_event_config_validator(res)
	await MatchScoreTests.add_cases(res)
	_case_one_roll(res)
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


#The contract type of that name, or null after recording a failed check under label.
static func _loaded_type(res: Dictionary, label: String, type_name: String) -> ContractData:
	var c: ContractData = ContractLibrary.contract_type(type_name)
	if c == null:
		TestFixtures.check(res, label, false, "%s contract resource did not load" % type_name)
	return c


static func _case_build(res: Dictionary) -> void:
	var out: Dictionary = ContractResourceBuilder.build_all()
	var live: int = _live_contract_count()
	TestFixtures.check(res, "build_contract_count", int(out["contracts"]) == live,
		"contracts %d of %d" % [int(out["contracts"]), live])
	TestFixtures.check(res, "build_event_count", int(out["events"]) == 23, "events %d" % int(out["events"]))
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


#The live Contracts.tsv rows build_all writes: distinct file stems of the nonblank row names (as BuilderTests counts).
static func _live_contract_count() -> int:
	var seen: Dictionary = {}
	for row: Dictionary in DataManager.contract_rows:
		var name: String = ContractResourceBuilder.row_name(row)
		if name != "":
			seen[ContractResourceBuilder.file_stem(name).to_lower()] = true
	return seen.size()


#The stock rows live in Contracts_OLD.tsv and Resources/Contracts_OLD; the live sheet and folder hold none of them.
static func _case_old_sheet(res: Dictionary) -> void:
	var old_names: Array[String] = []
	var untagged: Array[String] = []
	for row: Dictionary in DataManager.contract_rows_old:
		old_names.append(ContractResourceBuilder.row_name(row))
		if not bool(row.get("_old", false)):
			untagged.append(ContractResourceBuilder.row_name(row))
	var missing: Array[String] = []
	for stock: String in HarnessEntry.STOCK_CONTRACTS:
		if not old_names.has(stock):
			missing.append(stock)
	TestFixtures.check(res, "old_sheet_rows", missing.is_empty(),
		"%d old rows" % old_names.size() if missing.is_empty() else "missing: %s" % ", ".join(missing))
	var live_stock: Array[String] = []
	var live: Array[PackedStringArray] = TsvReader.load_tsv(DataManager.CONTRACTS_TSV)
	for i: int in range(1, live.size()):
		var name: String = TsvReader.row_get(live[i], 0)
		if HarnessEntry.STOCK_CONTRACTS.has(name):
			live_stock.append(name)
	TestFixtures.check(res, "live_rows_not_stock", live_stock.is_empty() and live.size() >= 2,
		"%d live lines; stock: %s" % [live.size(), ", ".join(live_stock)])
	var misplaced: Array[String] = []
	for stock: String in HarnessEntry.STOCK_CONTRACTS:
		var stem: String = ContractResourceBuilder.file_stem(stock)
		if FileAccess.file_exists("res://Resources/Contracts/%s.tres" % stem) \
				or not FileAccess.file_exists("res://Resources/Contracts_OLD/%s.tres" % stem):
			misplaced.append(stem)
	TestFixtures.check(res, "stock_tres_moved", misplaced.is_empty(),
		TestFixtures.detail(misplaced, HarnessEntry.STOCK_CONTRACTS.size(), "stems"))
	var live_tagged: Array[String] = []
	for row: Dictionary in DataManager.contract_rows:
		if bool(row.get("_old", false)) and not old_names.has(ContractResourceBuilder.row_name(row)):
			live_tagged.append(ContractResourceBuilder.row_name(row))
	for row: Dictionary in DataManager.contract_rows_from(live):
		if bool(row.get("_old", false)):
			live_tagged.append(ContractResourceBuilder.row_name(row))
	TestFixtures.check(res, "old_rows_tagged", untagged.is_empty() and live_tagged.is_empty() and not old_names.is_empty(),
		"untagged %s; live tagged %s" % [", ".join(untagged), ", ".join(live_tagged)])


#A row named apart from its type lists, generates, counts for rest demand and posts by its own name; build_all prunes it.
static func _case_rows(res: Dictionary) -> void:
	TestFixtures.check(res, "rows_harness_pin", ContractLibrary.pinned_names == HarnessEntry.STOCK_CONTRACTS,
		"pin %s" % ", ".join(ContractLibrary.pinned_names))
	var saved_rows: Array[Dictionary] = DataManager.contract_rows
	var saved_pin: Array[String] = ContractLibrary.pinned_names.duplicate()
	var before_names: Array[String] = ContractLibrary.contract_names()
	var military: Dictionary = {}
	for row: Dictionary in saved_rows:
		if ContractResourceBuilder.row_name(row) == "Military":
			military = row
			break
	if military.is_empty():
		TestFixtures.check(res, "rows_listed", false, "no Military row")
		return
	var extra: Dictionary = military.duplicate(true)
	extra["Contract Name"] = "TEST Row Named"
	extra["Contract Type"] = "TEST Kind"
	extra["15% Knowledge"] = "TEST Lore"
	extra["_row"] = 99
	var rows: Array[Dictionary] = []
	rows.append_array(saved_rows)
	rows.append(extra)
	DataManager.contract_rows = rows
	ContractResourceBuilder.build_all()
	var unpinned: Array[String] = []
	ContractLibrary.pinned_names = unpinned
	var names: Array[String] = ContractLibrary.row_names()
	var types: Array[String] = ContractLibrary.contract_type_names()
	TestFixtures.check(res, "rows_listed", names.has("TEST Row Named") and types.has("TEST Kind")
		and not names.has("TEST Kind") and ContractLibrary.contracts_for_type("TEST Kind").size() == 1,
		"rows %s; types %s" % [", ".join(names), ", ".join(types)])
	var named: ContractData = ContractGenerator.generate_named("TEST Row Named")
	TestFixtures.check(res, "rows_generate_named",
		named != null and named.contract_name == "TEST Row Named" and named.contract_type == "TEST Kind",
		"contract %s" % ("null" if named == null else "%s of %s" % [named.contract_name, named.contract_type]))
	var template: ContractData = ContractLibrary.contract_type("TEST Kind")
	var stock: ContractData = ContractLibrary.contract_type("Military")
	var by_type: ContractData = ContractGenerator.generate("TEST Kind")
	TestFixtures.check(res, "rows_type_template", template != null and template.contract_name == "TEST Row Named"
		and stock != null and stock.contract_name == "Military" and by_type != null and by_type.contract_type == "TEST Kind",
		"TEST Kind %s, Military %s, generate %s" % ["null" if template == null else template.contract_name,
		"null" if stock == null else stock.contract_name, "null" if by_type == null else by_type.contract_type])
	var kept_table: Dictionary = RestActions._demand_table
	var kept_max: float = RestActions._demand_max
	var kept_built: bool = RestActions._demand_built
	RestActions._demand_built = false
	RestActions._demand_table = {}
	RestActions._demand_max = 0.0
	var lore: float = RestActions.demand("knowledge:TEST Lore")
	RestActions._demand_table = kept_table
	RestActions._demand_max = kept_max
	RestActions._demand_built = kept_built
	TestFixtures.check(res, "rows_rest_demand", lore == 3.0, "knowledge:TEST Lore %.2f, want 3.00" % lore)
	var kinds: Array[String] = ["TEST Kind"]
	var anywhere: Array[String] = []
	var off: String = ""
	for _i: int in range(20):
		var drawn: ContractData = ContractGenerator.generate_for(kinds, anywhere, 0.5, 5.0)
		if off == "" and (drawn == null or drawn.contract_name != "TEST Row Named"):
			off = "null" if drawn == null else drawn.contract_name
	TestFixtures.check(res, "rows_generate_for_type", off == "", "first draw off the row: %s" % (off if off != "" else "none"))
	var board := ContractBoard.new()
	var kept_roster: Array[MercenaryData] = []
	kept_roster.assign(GuildRoster.mercs)
	GuildRoster.reset()
	board.launch(0, names.size())
	GuildRoster.set_roster(kept_roster)
	var posted: Array[String] = []
	for entry: BoardEntry in board.entries:
		posted.append(entry.contract.contract_name if entry.contract != null else "")
	posted.sort()
	TestFixtures.check(res, "rows_board_every_row", posted == names, "posted %s" % ", ".join(posted))
	var only: Array[String] = ["Military"]
	ContractLibrary.pinned_names = only.duplicate()
	var pinned_rows: Array[String] = ContractLibrary.row_names()
	var pinned_types: Array[String] = ContractLibrary.contract_type_names()
	var pin_ok: bool = (pinned_rows == only and pinned_types == only
		and ContractLibrary.contracts_for_type("TEST Kind").is_empty()
		and ContractLibrary.contracts_for_type("Military").size() == 1
		and ContractLibrary.contract_type("TEST Kind") == null
		and ContractGenerator.generate_named("TEST Row Named") != null
		and ContractLibrary.contract_names().has("TEST Row Named"))
	TestFixtures.check(res, "rows_pin_filters", pin_ok,
		"rows %s; types %s" % [", ".join(pinned_rows), ", ".join(pinned_types)])
	ContractLibrary.pinned_names = saved_pin
	DataManager.contract_rows = saved_rows
	ContractResourceBuilder.build_all()
	var after_names: Array[String] = ContractLibrary.contract_names()
	TestFixtures.check(res, "rows_cleanup", not FileAccess.file_exists(ContractResourceBuilder.contract_path("TEST Row Named"))
		and after_names == before_names, "names %s" % ", ".join(after_names))


static func _case_builder_military(res: Dictionary) -> void:
	var c: ContractData = _loaded_type(res, "builder_military", "Military")
	if c == null:
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
	var c: ContractData = _loaded_type(res, "builder_entertain", "Entertain")
	if c == null:
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
	var contract: ContractData = _loaded_type(res, "modifiers_apply_revert", "Military")
	if contract == null:
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
	var contract: ContractData = _loaded_type(res, "circumstance_boost", "Military")
	if contract == null:
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
	TestFixtures.set_level(merc, 5)
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
	TestFixtures.set_level(probe, 5)
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
	merc.tools = [ContractFixtures.utility("Scout's Kit")] as Array[UtilityTraitData]
	var contract: ContractData = _synthetic_contract()
	var team: Array[MercenaryData] = [merc]
	var info: Dictionary = OverallSuccess.for_merc(contract, team, merc, null)
	var plain_ok: bool = is_equal_approx(float(info["boost_percent"]), 15.0) \
		and is_equal_approx(float(info["relevance_percent"]), 0.0) \
		and is_equal_approx(float(info["penalty_percent"]), 10.0) \
		and is_equal_approx(float(info["net_percent"]), 5.0) \
		and absf(float(info["value"]) - 5.25) < 0.0001 and absf(float(info["delta"]) - 0.25) < 0.0001
	TestFixtures.check(res, "overall_success_no_event", plain_ok, OverallSuccess.describe(merc, info))
	merc.knowledges = [ContractFixtures.utility("Dueling")] as Array[UtilityTraitData]
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
	brewer.tools = [ContractFixtures.utility("Brewer's Kit")] as Array[UtilityTraitData]
	var plain := MercenaryData.new()
	plain.merc_name = "Plain"
	plain.stats = {}
	plain.tools = [ContractFixtures.utility("Miner's Kit")] as Array[UtilityTraitData]
	var hit: float = OverallSuccess.relevance_percent(brewer, event)
	var miss: float = OverallSuccess.relevance_percent(plain, event)
	TestFixtures.check(res, "relevance_tool_prefix", is_equal_approx(hit, 15.0), "relevance %.1f" % hit)
	TestFixtures.check(res, "relevance_no_match", is_equal_approx(miss, 0.0), "relevance %.1f" % miss)


static func _case_area_lookup(res: Dictionary) -> void:
	var tavern: Dictionary = DataManager.get_area_by_name("Tavern")
	TestFixtures.check(res, "area_lookup_tavern", String(tavern.get("type", "")) == "Interior", "area %s" % str(tavern.get("type", "")))
	TestFixtures.check(res, "area_lookup_missing", DataManager.get_area_by_name("Nowhere").is_empty(), "empty for an unknown area")
	var cathistii: LocationData = ContractFixtures.location("Cathistii")
	var aerdis: LocationData = ContractFixtures.location("Aerdis")
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
		var loc: LocationData = ContractFixtures.location(loc_name)
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
		var loc: LocationData = ContractFixtures.location(loc_name)
		var got: String = ContractTerrain.weights_text(ContractTerrain.candidates(loc))
		if got != String(expected[loc_name]):
			bad.append("%s '%s' != '%s'" % [loc_name, got, String(expected[loc_name])])
	TestFixtures.check(res, "terrain_candidates", bad.is_empty(),
		"all 7 locations map as expected" if bad.is_empty() else ", ".join(bad))
	var aerdis: LocationData = ContractFixtures.location("Aerdis")
	var sea: LocationData = ContractFixtures.location("Gledd Sea")
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
	TestFixtures.check(res, "odds_validator", odds_warnings == 2 and warnings.size() == 2,
		"%d Terrain Odds warning(s) of %d" % [odds_warnings, warnings.size()])
	var rossade: LocationData = ContractFixtures.location("Rossade")
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


static func _split_probe(entries: Array) -> ContractData:
	var probe := ContractData.new()
	probe.contract_type = "TEST Split"
	probe.terrain_odds = _terrain_odds(entries)
	return probe


#400 draws of probe at loc: forced hits per area name, "_pool" location draws in the pool, "_off" the rest.
static func _split_counts(loc: LocationData, probe: ContractData) -> Dictionary:
	var counts: Dictionary = {"_pool": 0, "_off": 0, "_hows": []}
	for _i: int in range(400):
		var drawn: Dictionary = ContractTerrain.draw(loc, probe)
		var name: String = String((drawn["area"] as Dictionary).get("name", ""))
		var how: String = String(drawn["how"])
		if how.find(" odds (") >= 0:
			counts[name] = int(counts.get(name, 0)) + 1
			(counts["_hows"] as Array).append(how)
		elif name == "Arctic Mountain" or name == "Cavern":
			counts["_pool"] = int(counts["_pool"]) + 1
		else:
			counts["_off"] = int(counts["_off"]) + 1
	return counts


#Area names of 20 draws at loc after seed(4242).
static func _seeded_names(loc: LocationData, probe: ContractData) -> Array[String]:
	var out: Array[String] = []
	seed(4242)
	for _i: int in range(20):
		out.append(String((ContractTerrain.draw(loc, probe)["area"] as Dictionary).get("name", "")))
	return out


static func _odds_warnings_of(entries: Array) -> Array[String]:
	var out: Array[String] = []
	for text: String in ContractDataValidator.validate_contract(_split_probe(entries), {"_row": 99}):
		if text.find("column Terrain Odds") >= 0:
			out.append(text)
	return out


static func _case_one_roll(res: Dictionary) -> void:
	var rossade: LocationData = ContractFixtures.location("Rossade")
	var full: Dictionary = _split_counts(rossade, _split_probe([["Cavern", 15], ["Dungeon", 85]]))
	var full_cavern: int = int(full.get("Cavern", 0))
	var full_dungeon: int = int(full.get("Dungeon", 0))
	var full_hows_ok: bool = true
	for how: String in full["_hows"]:
		if how.find("(Dungeon") >= 0 and how != "TEST Split odds (Dungeon 85)":
			full_hows_ok = false
	TestFixtures.check(res, "one_roll_full", full_cavern + full_dungeon == 400 and full_cavern >= 24
		and full_cavern <= 96 and full_hows_ok, "cavern %d dungeon %d hows ok %s" % [full_cavern, full_dungeon,
		str(full_hows_ok)])
	var clipped: Dictionary = _split_counts(rossade, _split_probe([["Cavern", 15], ["Dungeon", 100]]))
	var clipped_cavern: int = int(clipped.get("Cavern", 0))
	var clipped_forced: int = clipped_cavern + int(clipped.get("Dungeon", 0))
	TestFixtures.check(res, "one_roll_clipped", clipped_forced == 400 and clipped_cavern >= 24 and clipped_cavern <= 96,
		"forced %d cavern %d" % [clipped_forced, clipped_cavern])
	var rest: Dictionary = _split_counts(rossade, _split_probe([["Dungeon", 30]]))
	var rest_dungeon: int = int(rest.get("Dungeon", 0))
	TestFixtures.check(res, "one_roll_remainder", rest_dungeon >= 74 and rest_dungeon <= 166
		and rest_dungeon + int(rest["_pool"]) == 400, "dungeon %d pool %d off %d" % [rest_dungeon, int(rest["_pool"]),
		int(rest["_off"])])
	var invalid: Dictionary = _split_counts(rossade, _split_probe([["Forest", 50], ["Dungeon", 50]]))
	var invalid_dungeon: int = int(invalid.get("Dungeon", 0))
	TestFixtures.check(res, "one_roll_invalid_range", int(invalid.get("Forest", 0)) == 0 and invalid_dungeon >= 150
		and invalid_dungeon <= 250 and invalid_dungeon + int(invalid["_pool"]) == 400,
		"forest %d dungeon %d pool %d off %d" % [int(invalid.get("Forest", 0)), invalid_dungeon, int(invalid["_pool"]),
		int(invalid["_off"])])
	var past: Dictionary = _split_counts(rossade, _split_probe([["Dungeon", 100], ["Cavern", 50]]))
	TestFixtures.check(res, "one_roll_past_full", int(past.get("Dungeon", 0)) == 400 and int(past.get("Cavern", 0)) == 0,
		"dungeon %d cavern %d" % [int(past.get("Dungeon", 0)), int(past.get("Cavern", 0))])
	#LANE E FACT: a percent below 1 takes no range; the builder cannot store 0 (#578).
	var zero: Dictionary = _split_counts(rossade, _split_probe([["Cavern", 0], ["Dungeon", 100]]))
	TestFixtures.check(res, "one_roll_zero_share", int(zero.get("Dungeon", 0)) == 400,
		"dungeon %d of 400" % int(zero.get("Dungeon", 0)))
	var plain: Array[String] = _seeded_names(rossade, null)
	var no_roll_ok: bool = true
	var no_roll_why: String = "all equal"
	for entries: Array in [[["Forest", 50]], [["Cavern", 0]], [["Cavern", -1]]]:
		var names: Array[String] = _seeded_names(rossade, _split_probe(entries))
		if not _names_eq(names, plain):
			no_roll_ok = false
			no_roll_why = "%s drew %s, null drew %s" % [str(entries), str(names), str(plain)]
	TestFixtures.check(res, "one_roll_no_valid_no_roll", no_roll_ok, no_roll_why)
	var split: ContractData = _split_probe([["Cavern", 15], ["Dungeon", 85]])
	var single_ok: int = 0
	for s: int in range(4243, 4263):
		seed(s)
		ContractTerrain.draw(rossade, split)
		var a: int = randi()
		seed(s)
		randi_range(1, 100)
		if randi() == a:
			single_ok += 1
	TestFixtures.check(res, "one_roll_single_call", single_ok == 20, "%d of 20 seeds made one call" % single_ok)
	var past_warnings: Array[String] = _odds_warnings_of([["Dungeon", 100], ["Cavern", 50]])
	TestFixtures.check(res, "odds_validator_past_full", past_warnings.size() == 1
		and past_warnings[0].find("Cavern never draws") >= 0, str(past_warnings))
	var dup_warnings: Array[String] = _odds_warnings_of([["Cavern", 10], ["Cavern", 20]])
	TestFixtures.check(res, "odds_validator_duplicate", dup_warnings.size() == 1
		and dup_warnings[0].find("duplicate area Cavern") >= 0, str(dup_warnings))
	randomize()


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
	var state: BattleState = BattleState.create(a, b, null)
	var pools_kept: bool = a[0].current_hp == 3 and a[0].current_ep == 2
	TestFixtures.check(res, "create_keeps_pools", pools_kept, "hp %d ep %d" % [a[0].current_hp, a[0].current_ep])
	a[0].is_dead = true
	AutoBattle.finalize(state, Callable())
	var cas_ok: bool = state.casualties.size() == 1 and state.casualties[0] == a[0] \
		and a[0].is_dead and a[0].current_hp == 3
	TestFixtures.check(res, "carry_casualties_recorded", cas_ok,
		"casualties %d dead %s hp %d" % [state.casualties.size(), str(a[0].is_dead), a[0].current_hp])
	var state2: BattleState = BattleState.create(a, b, null)
	TestFixtures.check(res, "create_never_refills", a[0].is_dead and a[0].current_hp == 3,
		"dead %s hp %d" % [str(a[0].is_dead), a[0].current_hp])
	AutoBattle.finalize(state2, Callable())
	TestFixtures.check(res, "finalize_never_revives", state2.casualties.size() == 1 and a[0].is_dead,
		"casualties %d dead %s" % [state2.casualties.size(), str(a[0].is_dead)])


static func _case_forced_generation(res: Dictionary) -> void:
	MercGenerator.forced_level = 3
	MercGenerator.forced_tradition = "Brave"
	var m: MercenaryData = MercGenerator.generate(0)
	var level_ok: bool = int(m.stats.get("level", -1)) == 3 \
		and float(m.stats.get("base_success_chance", -1.0)) >= 3.0 - 0.001
	TestFixtures.check(res, "forced_level_applied", level_ok,
		"level %s base %s" % [str(m.stats.get("level", -1)), str(m.stats.get("base_success_chance", -1.0))])
	TestFixtures.check(res, "forced_tradition_applied", m.tradition != null and m.tradition.tradition_name == "Brave",
		"tradition %s" % ContractFixtures.trad_name(m))
	MercGenerator.forced_level = -1
	MercGenerator.forced_tradition = ""
	var m2: MercenaryData = MercGenerator.generate(0)
	TestFixtures.check(res, "forced_reset", int(m2.stats.get("level", 0)) == 0, "level %s" % str(m2.stats.get("level", 0)))
	MercGenerator.forced_tradition = "Nonsense"
	var m3: MercenaryData = MercGenerator.generate(0)
	TestFixtures.check(res, "forced_tradition_unknown_falls_back", m3.tradition != null,
		"tradition %s" % ContractFixtures.trad_name(m3))
	MercGenerator.forced_tradition = ""


static func _contract_run(contract_name: String, count: int, level: int) -> ContractRun:
	var r := ContractRun.new()
	r.contract = ContractLibrary.contract_type(contract_name)
	var team: Array[MercenaryData] = []
	for i: int in range(count):
		var merc: MercenaryData = MercGenerator.generate(i)
		if level > 0:
			TestFixtures.set_level(merc, level)
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
		if ContractFixtures.trad_name(mercs[i]) != want:
			trads_ok = false
		detail.append("L%d %s" % [lvl, ContractFixtures.trad_name(mercs[i])])
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
	var aerdis: LocationData = ContractFixtures.location("Aerdis")
	var austyg: LocationData = ContractFixtures.location("Austyg")
	var cathistii: LocationData = ContractFixtures.location("Cathistii")
	var brawl: EventData = ContractLibrary.event("Tavern Brawl")
	var skirmish: EventData = ContractLibrary.event("Assist with the Skirmish")
	var umbra: LocationData = ContractFixtures.location("Umbra")
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


#Card 285: the Cat row's Min and Max Mercs 1 reach the generated contract; a blank row keeps the config defaults.
static func _case_generator_mercs(res: Dictionary) -> void:
	var config: ContractConfig = ContractLibrary.config()
	var cat: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	TestFixtures.check(res, "card285_cat_solo", cat != null and cat.max_mercs == 1 and cat.min_mercs == 1
		and ContractBoard.merc_min_for(cat) == 1,
		"null" if cat == null else "max %d min %d" % [cat.max_mercs, cat.min_mercs])
	var crew: ContractData = ContractGenerator.generate("Military")
	TestFixtures.check(res, "card285_blank_defaults", crew != null and crew.max_mercs == config.default_max_mercs
		and crew.min_mercs == config.board_merc_min,
		"null" if crew == null else "max %d min %d" % [crew.max_mercs, crew.min_mercs])
	var events: Array[EventData] = []
	var row: ContractData = ContractResourceBuilder.build_contract({"Contract Name": "TEST Mercs",
		"Contract Type": "Help", "Min Mercs": "2", "Max Mercs": "4", "_row": 97}, events)
	var made: ContractData = ContractGenerator.generate_row(row, 1, 1.0, "")
	TestFixtures.check(res, "card285_generate_row_range", made != null and made.max_mercs == 4 and made.min_mercs == 2
		and row.max_mercs == 4 and row.min_mercs == 2,
		"null" if made == null else "max %d min %d" % [made.max_mercs, made.min_mercs])


#Card 736: the Local column; the Cat row reads true, a blank cell false, "yes" false with one validator warning.
static func _case_local_cell(res: Dictionary) -> void:
	var live: Array[PackedStringArray] = TsvReader.load_tsv(DataManager.CONTRACTS_TSV)
	var old: Array[PackedStringArray] = TsvReader.load_tsv(DataManager.CONTRACTS_OLD_TSV)
	var live_head: PackedStringArray = live[0] if not live.is_empty() else PackedStringArray()
	var old_head: PackedStringArray = old[0] if not old.is_empty() else PackedStringArray()
	TestFixtures.check(res, "local:sheet_42_cells", live_head.size() == 42 and live_head[41] == "Local"
		and old_head.size() == 42 and old_head[41] == "Local",
		"live %d old %d" % [live_head.size(), old_head.size()])
	var cat: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	TestFixtures.check(res, "local:cat_true", cat != null and cat.local, "null" if cat == null else str(cat.local))
	var events: Array[EventData] = []
	var blank_row: Dictionary = {"Contract Name": "TEST Local Blank", "Contract Type": "Help", "_row": 94}
	var blank: ContractData = ContractResourceBuilder.build_contract(blank_row, events)
	var blank_warned: bool = _local_warnings(ContractDataValidator.validate_contract(blank, blank_row)) > 0
	TestFixtures.check(res, "local:blank_false", not blank.local and not blank_warned, "local %s" % str(blank.local))
	var false_row: Dictionary = {"Contract Name": "TEST Local False", "Contract Type": "Help", "Local": "false", "_row": 95}
	var lower: ContractData = ContractResourceBuilder.build_contract(false_row, events)
	var true_row: Dictionary = {"Contract Name": "TEST Local True", "Contract Type": "Help", "Local": "true", "_row": 96}
	var upper: ContractData = ContractResourceBuilder.build_contract(true_row, events)
	var quiet: int = _local_warnings(ContractDataValidator.validate_contract(lower, false_row)) \
		+ _local_warnings(ContractDataValidator.validate_contract(upper, true_row))
	TestFixtures.check(res, "local:case_free", not lower.local and upper.local and quiet == 0,
		"false %s true %s warnings %d" % [str(lower.local), str(upper.local), quiet])
	var yes_row: Dictionary = {"Contract Name": "TEST Local Yes", "Contract Type": "Help", "Local": "yes", "_row": 97}
	var yes: ContractData = ContractResourceBuilder.build_contract(yes_row, events)
	var warned: Array[String] = ContractDataValidator.validate_contract(yes, yes_row)
	TestFixtures.check(res, "local:yes_false_warns", not yes.local and _local_warnings(warned) == 1,
		"local %s warnings %s" % [str(yes.local), str(warned)])


static func _local_warnings(texts: Array[String]) -> int:
	var count: int = 0
	for text: String in texts:
		if text.contains("column Local:"):
			count += 1
	return count


#Card 736: ContractManager.run on the Local Cat row has no travel or respite clock line and logs LOCAL CONTRACT once.
static func _case_local_run(res: Dictionary) -> void:
	CampaignClock.reset()
	CampaignClock.advance(8 * CampaignClock.MINUTES_PER_HOUR)
	CheckStore.reset()
	var cat: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	if cat == null:
		TestFixtures.check(res, "local:run_cat", false, "Cat Stuck in Tree! did not generate")
		return
	cat.rolled_mishaps.clear()
	var merc: MercenaryData = MercGenerator.generate(0)
	TestFixtures.set_level(merc, 5)
	var team: Array[MercenaryData] = [merc]
	GuildRoster.set_roster(team)
	EventTrigger.missed_respites = 2
	EventTrigger.forced_d100 = 1
	var contract_run: ContractRun = await ContractManager.run(cat, team, Callable())
	EventTrigger.forced_d100 = -1
	var lines: Array[String] = contract_run.log_lines
	TestFixtures.check(res, "local:run_no_travel", not TestFixtures.has_line(lines, "CLOCK: travel out")
		and not TestFixtures.has_line(lines, "CLOCK: travel back"), "a travel clock line")
	TestFixtures.check(res, "local:run_no_respite_clock", ContractFixtures.index_of_prefix(lines, "CLOCK: respite") < 0,
		"a respite clock line")
	var local_lines: int = 0
	for line: String in lines:
		if line == ContractManager.LOCAL_LINE:
			local_lines += 1
	TestFixtures.check(res, "local:run_local_line", local_lines == 1, "LOCAL CONTRACT lines %d" % local_lines)
	TestFixtures.check(res, "local:run_no_roll", not TestFixtures.has_line(lines, "AMBUSH ROLL")
		and EventTrigger.missed_respites == 2 and contract_run.outcomes.size() == 1,
		"streak %d outcomes %d" % [EventTrigger.missed_respites, contract_run.outcomes.size()])
	EventTrigger.missed_respites = 0
	CheckStore.reset()


static func _case_generator(res: Dictionary) -> void:
	var config: ContractConfig = ContractLibrary.config()
	var saved: String = config.test_primary_event
	config.test_primary_event = "Assist with the Skirmish"
	var c: ContractData = ContractGenerator.generate("Military")
	config.test_primary_event = saved
	TestFixtures.check(res, "generator_not_null", c != null, "contract %s" % ("null" if c == null else c.contract_type))
	if c == null:
		return
	TestFixtures.check(res, "generator_status", c.status == "Draft", "status %s" % c.status)
	TestFixtures.check(res, "generator_reward", c.reward_notes == 300 and c.max_mercs == 3,
		"reward %d max mercs %d" % [c.reward_notes, c.max_mercs])
	TestFixtures.check(res, "generator_primary", c.assigned_primary_event == "Assist with the Skirmish",
		"primary %s" % c.assigned_primary_event)
	TestFixtures.check(res, "generator_mishaps", _names_eq(c.rolled_mishaps, ["Tavern Brawl"]), "mishaps %s" % str(c.rolled_mishaps))
	var a: LocationData = ContractFixtures.location(c.location_a)
	TestFixtures.check(res, "generator_location_a", a != null and ContractTerrain.has_terrain(a),
		"location_a %s terrain %s" % [c.location_a, ContractTerrain.describe(a)])
	var b: LocationData = ContractFixtures.location(c.location_b)
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
	var aerdis: LocationData = ContractFixtures.location("Aerdis")
	var austyg: LocationData = ContractFixtures.location("Austyg")
	var want: String = "%s vs %s" % [_display_name(aerdis), _display_name(austyg)]
	var got: String = ContractGenerator.fill_description("[location_a.demonym] vs [location_b.demonym]", aerdis, austyg)
	TestFixtures.check(res, "fill_description", got == want and got.begins_with("Aerdan vs "), "got %s want %s" % [got, want])


#Card 736: a Local row is placed at the guild home; a row that is not Local keeps its Possible Locations pool.
static func _case_local_home(res: Dictionary) -> void:
	var cat: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	TestFixtures.check(res, "local:named_home", cat != null and cat.local and cat.location_a == GenConstants.GUILD_HOME,
		"null" if cat == null else "location %s local %s" % [cat.location_a, str(cat.local)])
	var row: ContractData = ContractGenerator.generate("Military")
	if row == null:
		TestFixtures.check(res, "local:named_pool_kept", false, "Military generated null")
		return
	row.local = false
	var pool: Array[String] = ["Aerdis"]
	row.possible_locations = pool
	var made: ContractData = ContractGenerator.generate_row(row, 3, 2.0, "")
	TestFixtures.check(res, "local:named_pool_kept", made != null and pool.has(made.location_a),
		"null" if made == null else "location %s" % made.location_a)


static func _case_location_pool(res: Dictionary) -> void:
	var c := ContractData.new()
	c.contract_type = "TEST Pool"
	var no_names: Array[String] = []
	var ad: Array[String] = ["Aerdis"]
	var row: Array[String] = ["Aerdis", "Buern"]
	var overlap: Array[String] = ["Aerdis", "Okun"]
	var disjoint: Array[String] = ["Okun"]
	var blank_row: Array[String] = ContractGenerator.location_pool(c, ad)
	TestFixtures.check(res, "location_pool_blank_row", _same_names(blank_row, ["Aerdis"]), "pool %s" % str(blank_row))
	c.possible_locations = row
	var no_ad: Array[String] = ContractGenerator.location_pool(c, no_names)
	TestFixtures.check(res, "location_pool_no_ad", _same_names(no_ad, ["Aerdis", "Buern"]), "pool %s" % str(no_ad))
	var shared: Array[String] = ContractGenerator.location_pool(c, overlap)
	TestFixtures.check(res, "location_pool_overlap", _same_names(shared, ["Aerdis"]), "pool %s" % str(shared))
	var apart: Array[String] = ContractGenerator.location_pool(c, disjoint)
	TestFixtures.check(res, "location_pool_disjoint", _same_names(apart, ["Aerdis", "Buern"]), "pool %s" % str(apart))
	var off_pool: String = ""
	for _i: int in range(20):
		var loc: LocationData = ContractGenerator.pick_location_among(ContractGenerator.location_pool(c, no_names))
		var drawn: String = loc.location_name if loc != null else "null"
		if not row.has(drawn):
			off_pool = drawn
			break
	TestFixtures.check(res, "location_pool_draws", off_pool == "",
		"20 draws in Aerdis, Buern" if off_pool == "" else "drew %s" % off_pool)
	var military: Array[String] = ["Military"]
	var made: ContractData = ContractGenerator.generate_for(military, ad, 0.5, 5.0)
	TestFixtures.check(res, "location_pool_generate_for",
		made != null and ContractGenerator.location_pool(made, ad).has(made.location_a),
		"null contract" if made == null else "location_a %s possible locations %s" % [made.location_a, str(made.possible_locations)])


#location_pool promises no order, so its names compare sorted.
static func _same_names(actual: Array, expected: Array) -> bool:
	var a: Array = actual.duplicate()
	var b: Array = expected.duplicate()
	a.sort()
	b.sort()
	return _names_eq(a, b)


static func _case_generate_for(res: Dictionary) -> void:
	var home: LocationData = ContractGenerator.pick_location_a()
	var home_name: String = home.location_name if home != null else ""
	var types: Array[String] = ["Entertain", "Military"]
	var places: Array[String] = ["Nowhere", home_name]
	var built: int = 0
	var type_bad: String = ""
	var place_bad: String = ""
	var diff_bad: String = ""
	for _i: int in range(20):
		var c: ContractData = ContractGenerator.generate_for(types, places, 1.5, 3.0)
		if c == null:
			continue
		built += 1
		if type_bad == "" and not types.has(c.contract_type):
			type_bad = c.contract_type
		if place_bad == "" and not ContractGenerator.location_pool(c, places).has(c.location_a):
			place_bad = c.location_a
		if diff_bad == "" and (c.difficulty < 1.5 or c.difficulty > 3.0):
			diff_bad = "%.1f" % c.difficulty
	TestFixtures.check(res, "generate_for_built", home_name != "" and built == 20, "%d of 20 in %s" % [built, home_name])
	TestFixtures.check(res, "generate_for_type", type_bad == "",
		"first type off the picks %s" % (type_bad if type_bad != "" else "none"))
	TestFixtures.check(res, "generate_for_location", place_bad == "",
		"first location_a off %s: %s" % [home_name, place_bad if place_bad != "" else "none"])
	TestFixtures.check(res, "generate_for_difficulty", diff_bad == "",
		"first difficulty off [1.5, 3]: %s" % (diff_bad if diff_bad != "" else "none"))
	var military: Array[String] = ["Military"]
	var nowhere: Array[String] = ["Nowhere"]
	var anywhere: Array[String] = []
	var lost: ContractData = ContractGenerator.generate_for(military, nowhere, 0.5, 5.0)
	var lost_at: LocationData = null
	if lost != null:
		lost_at = ContractFixtures.location(lost.location_a)
	TestFixtures.check(res, "generate_for_unknown_location",
		lost_at != null and ContractTerrain.has_terrain(lost_at) and ContractGenerator._hosts_contracts(lost_at),
		"location_a %s" % ("null contract" if lost == null else lost.location_a))
	var odd: Array[String] = ["Nonsense"]
	var any_type: ContractData = ContractGenerator.generate_for(odd, anywhere, 0.5, 5.0)
	TestFixtures.check(res, "generate_for_unknown_type",
		any_type != null and ContractLibrary.contract_type_names().has(any_type.contract_type),
		"contract %s" % ("null" if any_type == null else any_type.contract_type))
	var flipped: ContractData = ContractGenerator.generate_for(military, anywhere, 4.0, 2.0)
	TestFixtures.check(res, "generate_for_flipped_band",
		flipped != null and flipped.difficulty >= 2.0 and flipped.difficulty <= 4.0,
		"difficulty %s" % ("null" if flipped == null else "%.1f" % flipped.difficulty))
	var pinned: ContractData = ContractGenerator.generate_for(military, anywhere, 2.5, 2.5)
	TestFixtures.check(res, "generate_for_pinned_band", pinned != null and is_equal_approx(pinned.difficulty, 2.5),
		"difficulty %s" % ("null" if pinned == null else "%.1f" % pinned.difficulty))


static func _case_target_parse(res: Dictionary) -> void:
	var full: String = "random:level=10-20, count=party+1, tradition=Warrior, skew=Dexterity, type=Beast"
	var beast: Dictionary = {"source": "monster", "type": "Beast", "pick": "all"}
	var rounds: Array[Dictionary] = [
		{"label": "blank", "cell": "", "out": "", "want": {"source": ""}},
		{"label": "npc", "cell": "npc:Bandit Leader", "out": "npc:Bandit Leader",
			"want": {"source": "npc", "name": "Bandit Leader"}},
		{"label": "monster", "cell": "monster:Beast:all", "out": "monster:Beast:all", "want": beast},
		{"label": "monster_no_pick", "cell": "monster:Beast", "out": "monster:Beast:all", "want": beast},
		{"label": "random_full", "cell": full, "out": full, "want": {"source": "random", "level_mode": "range",
			"level_min": 10, "level_max": 20, "count_mode": "party", "party_plus": 1, "tradition": "Warrior",
			"skew": "Dexterity", "type": "Beast"}},
		{"label": "random_defaults", "cell": "random:", "out": ContractTarget.DEFAULT_RANDOM,
			"want": {"source": "random", "level_mode": "party", "count_mode": "party", "party_plus": 0}},
		{"label": "random_order", "cell": "random:count=3, level=12", "out": "random:level=12, count=3",
			"want": {"source": "random", "level_mode": "fixed", "level": 12, "count_mode": "fixed", "count": 3}},
		{"label": "random_spaces", "cell": " random: level = party , count = party+2 ",
			"out": "random:level=party, count=party+2",
			"want": {"source": "random", "level_mode": "party", "count_mode": "party", "party_plus": 2}},
		{"label": "random_zeros", "cell": "random:level=00000, count=00012", "out": "random:level=0, count=12",
			"want": {"source": "random", "level_mode": "fixed", "level": 0, "count_mode": "fixed", "count": 12}},
	]
	for entry: Dictionary in rounds:
		var spec: Dictionary = ContractTarget.parse(str(entry["cell"]))
		var out: String = ContractTarget.compose(spec)
		TestFixtures.check(res, "target_parse_" + str(entry["label"]),
			_spec_has(spec, entry["want"]) and out == str(entry["out"]),
			"'%s' composed '%s', error '%s'" % [entry["cell"], out, spec["error"]])
	TestFixtures.check(res, "target_parse_monster_same_spec",
		ContractTarget.parse("monster:Beast") == ContractTarget.parse("monster:Beast:all"),
		"monster:Beast against monster:Beast:all")
	var rejects: Array[String] = ["foo:bar", "npc:", "monster:", "monster:Beast:all:x", "random:level=x",
		"random:level=5-3", "random:level=300", "random:count=0", "random:count=100", "random:count=party+10",
		"random:skew=melee", "random:bogus=1", "random:level=1, level=2", "NPC:Bandit Leader", "random:level=00300"]
	var bad: Array[String] = []
	for cell: String in rejects:
		var spec: Dictionary = ContractTarget.parse(cell)
		var rest: Dictionary = spec.duplicate()
		rest["ok"] = true
		rest["error"] = ""
		if bool(spec["ok"]) or str(spec["error"]) == "" or rest != ContractTarget.blank_spec():
			bad.append(cell)
	TestFixtures.check(res, "target_parse_rejects", bad.is_empty(), TestFixtures.detail(bad, rejects.size(), "cells"))


#True when spec parsed ok and holds every value of want.
static func _spec_has(spec: Dictionary, want: Dictionary) -> bool:
	if not bool(spec.get("ok", false)):
		return false
	for key: String in want:
		if str(spec.get(key, "")) != str(want[key]):
			return false
	return true


#complete() is true only for a spec whose composed cell parses back to the same values.
static func _case_target_complete(res: Dictionary) -> void:
	var whole: Array[String] = ["", "random:", "npc:Bandit Leader", "monster:Beast"]
	var done: int = 0
	for cell: String in whole:
		if ContractTarget.complete(ContractTarget.parse(cell)):
			done += 1
	TestFixtures.check(res, "target_complete", done == whole.size(), "%d of %d parsed cells" % [done, whole.size()])
	var kept: Array[Dictionary] = [{"source": "npc", "name": "Bandit Leader"},
		{"source": "monster", "type": "Beast", "pick": "Dire Wolf"},
		{"source": "random", "level_mode": "range", "level_min": 5, "level_max": 9, "party_plus": 3,
			"tradition": "Warrior", "skew": "Vigor", "type": "Undead"}]
	var lost: Array[String] = []
	for want: Dictionary in kept:
		var spec: Dictionary = _target_spec(want)
		var cell: String = ContractTarget.compose(spec)
		if not ContractTarget.complete(spec) or not _spec_has(ContractTarget.parse(cell), want):
			lost.append(cell)
	TestFixtures.check(res, "target_complete_round_trip", lost.is_empty(),
		TestFixtures.detail(lost, kept.size(), "specs"))
	var broken: Array[Dictionary] = [{"source": "npc"}, {"source": "monster"}, {"source": "bogus"},
		{"source": "monster", "type": "Beast:Kin"}, {"source": "monster", "type": "Beast", "pick": "Dire:Wolf"},
		{"source": "random", "tradition": "Hedge, Wild"}, {"source": "random", "type": "Beast, Kin"},
		{"source": "random", "tradition": "Hedge, skew=Vigor"}, {"source": "random", "party_plus": 12},
		{"source": "random", "level_mode": "fixed", "level": 300}, ContractTarget.parse("garbage"),
		{"source": "random", "level_mode": "range", "level_min": 30, "level_max": 10}, ContractTarget.parse("npc:"),
		{"source": "random", "count_mode": "fixed", "count": 0}]
	var passed: Array[String] = []
	for values: Dictionary in broken:
		if ContractTarget.complete(_target_spec(values)):
			passed.append(str(values))
	TestFixtures.check(res, "target_complete_rejects", passed.is_empty(),
		TestFixtures.detail(passed, broken.size(), "specs"))


static func _target_spec(values: Dictionary) -> Dictionary:
	var spec: Dictionary = ContractTarget.blank_spec()
	spec.merge(values, true)
	return spec


static func _case_target_display(res: Dictionary) -> void:
	var cases: Array[Array] = [["npc:Bandit Leader", "Rolf", "Bandit Leader Rolf"],
		["npc:Bandit Leader", "", "Bandit Leader"], ["monster:Beast:all", "", "Beast"],
		["monster:Beast:Dire Wolf", "", "Dire Wolf"], ["random:level=party, count=party", "", "Mercenaries"],
		["random:tradition=Warrior", "", "Warrior"], ["random:type=Undead", "", "Undead"], ["garbage", "x", ""],
		["", "x", ""]]
	for i: int in range(cases.size()):
		var entry: Array = cases[i]
		var got: String = ContractTarget.display_name(str(entry[0]), str(entry[1]))
		TestFixtures.check(res, "target_display_%d" % i, got == str(entry[2]),
			"'%s' with '%s' gave '%s'" % [entry[0], entry[1], got])


static func _case_description_pick(res: Dictionary) -> void:
	var data: ContractData = ContractData.new()
	data.description_template = "T"
	var empty_pick: String = ContractGenerator.pick_description(data)
	data.descriptions.assign(["", " "])
	var blank_pick: String = ContractGenerator.pick_description(data)
	TestFixtures.check(res, "description_pick_template", empty_pick == "T" and blank_pick == "T",
		"no entries '%s', blank entries '%s'" % [empty_pick, blank_pick])
	data.descriptions.assign(["A", "B"])
	var seen: Dictionary = {}
	for _i: int in range(40):
		seen[ContractGenerator.pick_description(data)] = true
	TestFixtures.check(res, "description_pick_entries", seen.size() == 2 and seen.has("A") and seen.has("B"),
		"picked %s" % str(seen.keys()))


static func _case_fill_tags(res: Dictionary) -> void:
	var text: String = "Find %target% near %location% for %requestor%."
	var filled: String = ContractGenerator.fill_tags(text, "Bandit Leader Rolf", "Harrow", "Mira")
	TestFixtures.check(res, "fill_tags_values", filled == "Find Bandit Leader Rolf near Harrow for Mira.", filled)
	var blank: String = ContractGenerator.fill_tags(text, "", "", "")
	TestFixtures.check(res, "fill_tags_blank", blank == "Find Unknown near Unknown for Unknown.", blank)
	var plain: String = ContractGenerator.fill_tags("Escort the caravan.", "x", "y", "z")
	var token: String = ContractGenerator.fill_tags("Rescue [location_a.name]", "x", "y", "z")
	TestFixtures.check(res, "fill_tags_untouched",
		plain == "Escort the caravan." and token == "Rescue [location_a.name]", "'%s' and '%s'" % [plain, token])


static func _case_requestor_name(res: Dictionary) -> void:
	var aerdis: LocationData = ContractFixtures.location("Aerdis")
	var data: ContractData = ContractData.new()
	data.issuer_type = "place"
	data.issuer = " Aerdis "
	var place: String = ContractGenerator.requestor_name(data, aerdis)
	TestFixtures.check(res, "requestor_place", place == "Aerdis", "'%s'" % place)
	data.issuer_type = "org"
	data.issuer = "Guild"
	var org: String = ContractGenerator.requestor_name(data, aerdis)
	TestFixtures.check(res, "requestor_org", org == "Guild", "'%s'" % org)
	data.issuer_type = "person"
	var person: String = ContractGenerator.requestor_name(data, aerdis)
	var nobody: String = ContractGenerator.requestor_name(data, null)
	TestFixtures.check(res, "requestor_person", aerdis != null and person.strip_edges() != "" and nobody == "",
		"Aerdis '%s', no location '%s'" % [person, nobody])
	data.issuer_type = ""
	var unset: String = ContractGenerator.requestor_name(data, aerdis)
	TestFixtures.check(res, "requestor_unset", unset == "", "'%s'" % unset)


static func _case_target_name(res: Dictionary) -> void:
	var aerdis: LocationData = ContractFixtures.location("Aerdis")
	var data: ContractData = ContractData.new()
	var cases: Array[Array] = [["", ""], ["monster:Beast:all", "Beast"], ["random:tradition=Warrior", "Warrior"],
		["garbage", ""]]
	for i: int in range(cases.size()):
		var entry: Array = cases[i]
		data.target = str(entry[0])
		var got: String = ContractGenerator.target_name(data, aerdis)
		TestFixtures.check(res, "target_name_%d" % i, got == str(entry[1]), "'%s' gave '%s'" % [entry[0], got])
	data.target = "npc:Bandit Leader"
	var named: String = ContractGenerator.target_name(data, aerdis)
	var one_more: bool = named.begins_with("Bandit Leader ") and named.split(" ", false).size() == 3
	TestFixtures.check(res, "target_name_npc", aerdis != null and (named == "Bandit Leader" or one_more),
		"'%s'" % named)
	var alone: String = ContractGenerator.target_name(data, null)
	TestFixtures.check(res, "target_name_npc_no_place", alone == "Bandit Leader", "'%s'" % alone)


#Every row's Target and Issuer Type cells are blank today, so both generated names stay blank. _build loads its row by
#type name, so the hand-built row runs through pick_description, fill_tags and target_name.
static func _case_build_tags(res: Dictionary) -> void:
	var home: LocationData = ContractGenerator.pick_location_a()
	var home_name: String = home.location_name if home != null else ""
	var types: Array[String] = ["Entertain", "Military"]
	var places: Array[String] = ["Nowhere", home_name]
	var built: int = 0
	var bad: Array[String] = []
	for _i: int in range(10):
		var c: ContractData = ContractGenerator.generate_for(types, places, 1.5, 3.0)
		if c == null:
			continue
		built += 1
		if c.description.contains("%") or c.target_name != "" or c.requestor_name != "":
			bad.append("%s '%s' target '%s' requestor '%s'" % [c.contract_type, c.description, c.target_name,
				c.requestor_name])
	TestFixtures.check(res, "build_tags_generated", built == 10 and bad.is_empty(),
		"%d of 10 built, %s" % [built, TestFixtures.detail(bad, built, "with a percent sign or a name")])
	var row: ContractData = ContractData.new()
	row.descriptions.assign(["Rescue %target% from %location%"])
	row.target = "monster:Beast:all"
	var text: String = ContractGenerator.fill_tags(
		ContractGenerator.fill_description(ContractGenerator.pick_description(row), home, null),
		ContractGenerator.target_name(row, home), ContractGenerator._place_name(home),
		ContractGenerator.requestor_name(row, home))
	TestFixtures.check(res, "build_tags_hand_row", home_name != "" and text == "Rescue Beast from %s" % home_name,
		"'%s' at %s" % [text, home_name])


static func _case_manager_flow(res: Dictionary) -> void:
	CampaignClock.reset()
	var team: Array[MercenaryData] = []
	for i: int in range(3):
		var merc: MercenaryData = MercGenerator.generate(i)
		TestFixtures.set_level(merc, 5)
		team.append(merc)
	var combat_before: Dictionary = {}
	for merc: MercenaryData in team:
		combat_before[merc] = float(merc.stats.get("combat", 0.0))
	GuildRoster.set_roster(team)
	var contract: ContractData = ContractGenerator.generate("Military")
	contract.unsavory = false
	contract.assigned_primary_event = "Assist with the Skirmish"
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
	var spans: Dictionary = _manager_clock_spans(contract_run)
	var clock_sum: int = int(spans["sum"])
	var gap_lines: int = int(spans["gap_lines"])
	var gaps_moved: bool = bool(spans["gaps_moved"])
	var respite_lines: int = int(spans["respite_lines"])
	var respite_delta: int = int(spans["respite_delta"])
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
	var rest_time_delta: int = int(spans["rest_time"])
	TestFixtures.check(res, "manager_clock_respite",
		respite_lines == (1 if want_respite else 0)
		and (not want_respite or (respite_delta >= 1 and respite_delta == rest_time_delta)),
		"lines %d delta %d rest time %d primary %s" % [respite_lines, respite_delta, rest_time_delta,
		str(primary_ran)])
	var gap_at: int = int(spans["gap_at"])
	TestFixtures.check(res, "manager_between_events_rest",
		(gap_at >= 0) == (events_done >= 2) and bool(spans["gap_rested"]) == bool(spans["gap_rests"]),
		"gap line %d rested %s events %d" % [gap_at, str(spans["gap_rested"]), events_done])
	var back_at: int = int(spans["back_at"])
	var first_respite: int = int(spans["first_respite"])
	var primary_rested: bool = contract_run.living_team().is_empty() \
		or (first_respite >= 0 and back_at >= 0 and first_respite < back_at)
	TestFixtures.check(res, "manager_primary_respite", primary_rested,
		"respite line %d travel back %d living %d" % [first_respite, back_at, contract_run.living_team().size()])


#Reads the log of a manager run into the clock sums and line positions the clock checks compare.
static func _manager_clock_spans(contract_run: ContractRun) -> Dictionary:
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
	#The Military Avoid boost moves rest_recovery until end() reverts it, so the REST TIME line is the witness.
	var rest_time_delta: int = 0
	var respite_at: int = ContractFixtures.index_of_prefix(contract_run.log_lines, "CLOCK: respite ")
	if respite_at >= 0:
		for i: int in range(respite_at + 1, contract_run.log_lines.size()):
			var line: String = contract_run.log_lines[i]
			if line.begins_with("REST TIME: "):
				rest_time_delta = _rest_time_minutes(line)
				break
			if line.begins_with("CLOCK: ") and not _triggered_clock(line, contract_run):
				break
	var gap_at: int = ContractFixtures.index_of_prefix(contract_run.log_lines, "CLOCK: between events")
	var gap_rested: bool = false
	if gap_at >= 0:
		for i: int in range(gap_at + 1, contract_run.log_lines.size()):
			var line: String = contract_run.log_lines[i]
			if line.begins_with("CLOCK: ") and not _triggered_clock(line, contract_run):
				break
			if line.begins_with("REST TIME: ") or line.begins_with("RESPITE: ") or line.begins_with("BREATHER: "):
				gap_rested = true
				break
	return {"sum": clock_sum, "gap_lines": gap_lines, "gaps_moved": gaps_moved,
		"respite_lines": respite_lines, "respite_delta": respite_delta, "rest_time": rest_time_delta,
		"gap_at": gap_at, "gap_rests": gap_at >= 0 and contract_run.log_lines[gap_at].contains("("),
		"gap_rested": gap_rested,
		"back_at": ContractFixtures.index_of_prefix(contract_run.log_lines, "CLOCK: travel back "),
		"first_respite": ContractFixtures.index_of_prefix(contract_run.log_lines, "RESPITE: ")}


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
	var want: String = "%s L%d %s" % [merc.merc_name, int(merc.stats.get("level", 0)), ContractFixtures.trad_name(merc)]
	TestFixtures.check(res, "merc_line_generated", ContractLog.merc_line(merc) == want, "line %s" % ContractLog.merc_line(merc))
	var empty := MercenaryData.new()
	empty.merc_name = "Nobody"
	TestFixtures.check(res, "merc_line_npc", ContractLog.merc_line(empty) == "Nobody L0 NPC", "line %s" % ContractLog.merc_line(empty))


#Event Config warnings: a bad value, a cell with no event or a blank event name, and a valid Chase cell kept silent.
static func _case_event_config_validator(res: Dictionary) -> void:
	var probe: ContractData = ContractData.new()
	probe.contract_type = "TEST Event"
	probe.completion = "event:Fight Bandits"
	probe.event_config = "bandits=9"
	var warned: Array[String] = _event_config_warnings(probe)
	TestFixtures.check(res, "event_config_warns", warned.size() == 1
		and warned[0].find("bandits must be 0.5 to 4 in steps of 0.5") >= 0, "; ".join(warned))
	probe.completion = ""
	probe.event_config = "bandits=1"
	warned = _event_config_warnings(probe)
	TestFixtures.check(res, "event_config_without_event", warned.size() == 1
		and warned[0].ends_with("set without an event completion"), "; ".join(warned))
	probe.completion = "event:Chase"
	probe.event_config = "chase=foot; chasing=target"
	warned = _event_config_warnings(probe)
	TestFixtures.check(res, "event_config_valid_silent", warned.is_empty(), "; ".join(warned))
	probe.completion = "event:"
	probe.event_config = "bandits=1"
	warned = _event_config_warnings(probe)
	TestFixtures.check(res, "event_config_blank_event", warned.size() == 1
		and warned[0].ends_with("set without an event completion"), "; ".join(warned))


#The Event Config warnings validate_contract gives probe as sheet row 99.
static func _event_config_warnings(probe: ContractData) -> Array[String]:
	var out: Array[String] = []
	for text: String in ContractDataValidator.validate_contract(probe, {"_row": 99}):
		if text.find("column Event Config: ") >= 0:
			out.append(text)
	return out


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
	var lost_at: int = ContractFixtures.index_of_prefix(r.log_lines, "EXCESS LOST: ")
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
		and ContractFixtures.index_of_prefix(done, "RESPITE: ") >= 0,
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
	var rest_time_at: int = ContractFixtures.index_of_prefix(wounded.log_lines, "REST TIME: respite ")
	TestFixtures.check(res, "between_events_rest_time",
		not config.respite_between_events or rest_time_at >= 0,
		"rest time line %d flag %s" % [rest_time_at, str(config.respite_between_events)])
	var got_respite: bool = ContractFixtures.index_of_prefix(wounded.log_lines, "RESPITE: ") >= 0
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
	var got_breather: bool = ContractFixtures.index_of_prefix(tired.log_lines, "BREATHER: ") >= 0
	TestFixtures.check(res, "between_events_breather",
		got_breather == (config.breather_between_events and wants)
		and ContractFixtures.index_of_prefix(tired.log_lines, "RESPITE: ") < 0,
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
	StateCascade.apply_state(wet, ConstStates.DRENCHED)
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


#The Cat Style check contract: its "check:" primary, no build warning, Checks.tsv hours and dispatch odds above the floor.
static func _case_check_contract(res: Dictionary) -> void:
	CheckStore.reset()
	var cat: ContractData = ContractGenerator.generate_named("Cat Stuck in Tree!")
	if cat == null:
		for label: String in ["cat_primary", "cat_no_warning", "cat_hours", "cat_odds_above_1"]:
			TestFixtures.check(res, label, false, "Cat Stuck in Tree! did not generate")
		return
	cat.rolled_mishaps.clear()
	TestFixtures.check(res, "cat_primary", cat.assigned_primary_event == "check:Get Cat from Tree",
		"primary %s" % cat.assigned_primary_event)
	ContractResourceBuilder.build_all()
	var bad: Array[String] = []
	for text: String in ContractResourceBuilder.last_warnings:
		if text.contains("Cat Stuck in Tree!") or text.contains("no Checks.tsv row named Get Cat from Tree"):
			bad.append(text)
	TestFixtures.check(res, "cat_no_warning", bad.is_empty(), "warnings %s" % str(bad))
	TestFixtures.check(res, "cat_hours", ContractBoard.completion_hours(cat) == 1,
		"hours %d" % ContractBoard.completion_hours(cat))
	var team: Array[MercenaryData] = [TestFixtures.fixed_merc("Cat A", {"base_success_chance": 50.0}),
		TestFixtures.fixed_merc("Cat B", {"base_success_chance": 50.0})]
	var odds: int = OddsEstimator.for_contract(cat, team)
	TestFixtures.check(res, "cat_odds_above_1", odds > 1, "odds %d" % odds)
	CheckStore.reset()
