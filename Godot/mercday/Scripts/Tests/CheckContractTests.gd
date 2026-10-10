class_name CheckContractTests

#Style check contracts: CheckStore lookup and parsing, CheckEventResolver, board hours, clock, validator, manager flow.
#Run: godot --headless --path . -- --checkcontract-tests

const CAT := "Get Cat from Tree"
const CAT_CONTRACT := "Cat Stuck in Tree!"
const PASS_ROLL := 1
const FAIL_ROLL := 99


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_store_lookup(res)
	_case_store_parse_columns(res)
	_case_store_numbers(res)
	_case_store_half_def(res)
	_case_stand_in(res)
	_case_boosts(res)
	_case_tradition_points(res)
	_case_roller(res)
	_case_knowledge_points(res)
	_case_tool_points_floor(res)
	_case_difficulty_points(res)
	_case_difficulty_def(res)
	_case_difficulty_roller(res)
	_case_difficulty_resolve(res)
	_case_resolve_basic(res)
	_case_resolve_drains(res)
	_case_resolve_guild(res)
	_case_resolve_contract_row(res)
	_case_resolve_outcome(res)
	_case_resolve_tally(res)
	_case_resolve_critical(res)
	_case_resolve_opposed(res)
	await _case_runner_routes(res)
	_case_generator_board(res)
	await _case_clock(res)
	_case_validator(res)
	await _case_manager_flow(res)
	_case_odds_kind(res)
	_end()
	CampaignClock.reset()
	return TestFixtures.summarize(res, "CHECKCONTRACT")


static func _begin() -> void:
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()


static func _end() -> void:
	CheckStore.reset()
	CheckSystem.forced_rolls.clear()


#A Checks.tsv row keyed by the CheckSheet header; Attributes default to the Cat row's pair.
static func _row(check_name: String, cells: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {}
	for key: String in CheckSheet.HEADER:
		row[key] = ""
	row[CheckSheet.HEADER[CheckSheet.NAME]] = check_name
	row[CheckSheet.HEADER[CheckSheet.ATTRIBUTES]] = "Dexterity, Wile"
	for key: String in cells:
		row[key] = cells[key]
	return row


static func _use_rows(rows: Array[Dictionary]) -> void:
	CheckStore.test_rows.assign(rows)


static func _merc(merc_name: String, extras: Dictionary = {}) -> MercenaryData:
	var all: Dictionary = {"base_success_chance": 50.0}
	all.merge(extras, true)
	return TestFixtures.fixed_merc(merc_name, all)


static func _run(team: Array[MercenaryData], leader_uid: int = -1, consequence: String = "") -> ContractRun:
	var contract := ContractData.new()
	contract.style = "check"
	contract.consequence = consequence
	return ContractRun.make(contract, team, Callable(), leader_uid)


static func _dice(merc: MercenaryData, def: Dictionary) -> int:
	return int(CheckSystem.success_distribution(merc, def)["dice"])


static func _row_dice(merc: MercenaryData, check_name: String) -> int:
	return _dice(merc, CheckStore.check_def(CheckStore.parse(CheckStore.find(check_name))))


static func _passes(dice: int) -> Array[int]:
	var out: Array[int] = []
	for _i: int in range(dice):
		out.append(PASS_ROLL)
	return out


#A failed die draws its roll and the reroll test, so each one takes two forced rolls.
static func _fails(dice: int, attempts: int) -> Array[int]:
	var out: Array[int] = []
	for _i: int in range(dice * attempts * 2):
		out.append(FAIL_ROLL)
	return out


static func _resolve(check_name: String, team: Array[MercenaryData], rolls: Array[int], leader_uid: int = -1,
		consequence: String = "") -> Dictionary:
	var contract_run: ContractRun = _run(team, leader_uid, consequence)
	CheckSystem.forced_rolls.clear()
	CheckSystem.forced_rolls.append_array(rolls)
	var out: Dictionary = CheckEventResolver.resolve(CheckStore.stand_in(check_name), contract_run)
	return {"out": out, "run": contract_run, "left": CheckSystem.forced_rolls.size()}


static func _lines(result: Dictionary) -> Array[String]:
	return (result["run"] as ContractRun).log_lines


static func _first_line(lines: Array[String], prefix: String) -> String:
	for line: String in lines:
		if line.begins_with(prefix):
			return line
	return ""


static func _line_threshold(line: String) -> float:
	var at: int = line.find("threshold ")
	if at < 0:
		return -1.0
	return line.substr(at + "threshold ".length()).split(" ", false)[0].to_float()


static func _names_eq(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i: int in range(actual.size()):
		if str(actual[i]) != str(expected[i]):
			return false
	return true


static func _case_store_lookup(res: Dictionary) -> void:
	_begin()
	var p: Dictionary = CheckStore.parse(CheckStore.find(CAT))
	var cons: Dictionary = p.get("consequence", {})
	TestFixtures.check(res, "store_parse_cat",
		not p.is_empty() and is_equal_approx(float(p["multiplier"]), 0.5) and int(p["minutes"]) == 60
		and not bool(p["opposed"]) and int(cons.get("retry", 0)) == -1 and int(cons.get("ep", 0)) == -1
		and _names_eq(p.get("attributes", []), ["Dexterity", "Wile"]),
		"parsed %s" % str(p))
	var exact: Dictionary = CheckStore.find(CAT)
	TestFixtures.check(res, "store_find_case",
		not exact.is_empty() and CheckStore.find("get cat from tree") == exact, "found %s" % str(
			CheckStore.find("get cat from tree").get("Check Name", "")))
	TestFixtures.check(res, "store_find_prefix",
		not exact.is_empty() and CheckStore.find("check:" + CAT) == exact, "found %s" % str(
			CheckStore.find("check:" + CAT).get("Check Name", "")))
	TestFixtures.check(res, "store_missing",
		CheckStore.find("Nope").is_empty() and not CheckStore.has_row("Nope"),
		"find %s has_row %s" % [str(CheckStore.find("Nope")), str(CheckStore.has_row("Nope"))])
	TestFixtures.check(res, "store_is_check_name",
		CheckStore.is_check_name("check:" + CAT) and not CheckStore.is_check_name(CAT)
		and not CheckStore.is_check_name("check:"),
		"prefixed %s bare %s prefix only %s" % [str(CheckStore.is_check_name("check:" + CAT)),
			str(CheckStore.is_check_name(CAT)), str(CheckStore.is_check_name("check:"))])
	var rows: Array[Dictionary] = [_row("Twin", {"Multiplier": "2"}), _row("Twin", {"Multiplier": "3"})]
	_use_rows(rows)
	var twin: Dictionary = CheckStore.parse(CheckStore.find("Twin"))
	TestFixtures.check(res, "store_first_row_wins",
		not twin.is_empty() and is_equal_approx(float(twin["multiplier"]), 2.0),
		"multiplier %s" % str(twin.get("multiplier", "none")))
	_end()


static func _case_store_parse_columns(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Full", {"Circumstances": "Finesse (Dexterity) 5",
		"Knowledges": "Zoology 15", "Tools": "Tracker's 10", "Traditions": "Mage -5", "Multiplier": "1.5",
		"Time": "90", "Opposed": "Yes", "Opposed Check": "Other", "Consequence": "retry -2, hp -1"})]
	_use_rows(rows)
	var p: Dictionary = CheckStore.parse(CheckStore.find("Full"))
	var ok: bool = not p.is_empty()
	if ok:
		var circ: Array = p["circumstances"]
		var know: Array = p["knowledges"]
		var tools: Array = p["tools"]
		var trad: Array = p["traditions"]
		var cons: Dictionary = p["consequence"]
		ok = circ.size() == 1 and String(circ[0]["name"]) == "Finesse (Dexterity)" and int(circ[0]["percent"]) == 5
		ok = ok and know.size() == 1 and String(know[0]["name"]) == "Zoology" and int(know[0]["percent"]) == 15
		ok = ok and tools.size() == 1 and String(tools[0]["name"]) == "Tracker's" and int(tools[0]["percent"]) == 10
		ok = ok and trad.size() == 1 and String(trad[0]["name"]) == "Mage" and int(trad[0]["value"]) == -5
		ok = ok and is_equal_approx(float(p["multiplier"]), 1.5) and int(p["time"]) == 90 and int(p["minutes"]) == 90
		ok = ok and bool(p["opposed"]) and String(p["opposed_check"]) == "Other"
		ok = ok and int(cons["retry"]) == -2 and int(cons["hp"]) == -1 and int(cons["ep"]) == 0
		ok = ok and int(cons["mp"]) == 0 and int(cons["guild"]) == 0
	TestFixtures.check(res, "store_parse_columns", ok, "parsed %s" % str(p))
	_end()


static func _case_store_numbers(res: Dictionary) -> void:
	_begin()
	var n: Array[int] = [CheckStore.needed(0.5), CheckStore.needed(1.0), CheckStore.needed(1.5), CheckStore.needed(4.0)]
	TestFixtures.check(res, "store_needed", _names_eq(n, [1, 2, 3, 8]), "needed %s" % str(n))
	TestFixtures.check(res, "store_needed_base",
		CheckStore.BASE_SUCCESSES == 2 and CheckStore.needed(1.0, 3) == 3,
		"base %d needed(1.0, 3) %d" % [CheckStore.BASE_SUCCESSES, CheckStore.needed(1.0, 3)])
	TestFixtures.check(res, "store_opposed_needed",
		CheckStore.opposed_needed(0, 1.0) == 1 and CheckStore.opposed_needed(3, 1.5) == 5,
		"0 -> %d, 3 at 1.5 -> %d" % [CheckStore.opposed_needed(0, 1.0), CheckStore.opposed_needed(3, 1.5)])
	var hours: Array[int] = []
	for cell: String in ["0", "60", "90", "150"]:
		hours.append(CheckStore.hours(CheckStore.parse(_row("Hours", {"Time": cell}))))
	TestFixtures.check(res, "store_hours", _names_eq(hours, [1, 1, 2, 3]), "hours %s" % str(hours))
	var def: Dictionary = CheckStore.check_def(CheckStore.parse(CheckStore.find(CAT)))
	TestFixtures.check(res, "store_def_keys",
		_names_eq(def.get("stat_keys", []), ["dexterity", "wile"]) and String(def.get("formula", "")) == "0",
		"stat_keys %s formula %s" % [str(def.get("stat_keys", [])), str(def.get("formula", ""))])
	_end()


static func _case_store_half_def(res: Dictionary) -> void:
	_begin()
	var def: Dictionary = CheckStore.check_def(CheckStore.parse(CheckStore.find(CAT)))
	var high_def: Dictionary = def.duplicate(true)
	high_def["flat_threshold_bonus"] = 30.0
	var high: MercenaryData = _merc("High", {"base_success_chance": 90.0})
	var low: MercenaryData = _merc("Low")
	var why: PackedStringArray = []
	var ok: bool = true
	for pair: Array in [[high, high_def], [low, def]]:
		var merc: MercenaryData = pair[0]
		var first_def: Dictionary = pair[1]
		var raw: float = CheckSystem.threshold_for(merc, first_def)
		var first: float = float(CheckSystem.success_distribution(merc, first_def)["threshold"])
		var half: Dictionary = CheckStore.half_def(first_def, raw, first)
		var got: float = float(CheckSystem.success_distribution(merc, half)["threshold"])
		ok = ok and absf(got - first / 2.0) <= 0.01
		why.append("%s raw %.2f first %.2f half %.2f" % [merc.merc_name, raw, first, got])
	var high_raw: float = CheckSystem.threshold_for(high, high_def)
	TestFixtures.check(res, "store_half_def", ok and high_raw > 100.0 and CheckSystem.threshold_for(low, def) < 100.0,
		"; ".join(why))
	_end()


static func _case_stand_in(res: Dictionary) -> void:
	_begin()
	var event: EventData = CheckStore.stand_in(CAT)
	var p: Dictionary = CheckStore.parse(CheckStore.find(CAT))
	var names: Array = []
	for entry: Dictionary in p.get("knowledges", []):
		names.append(String(entry["name"]))
	TestFixtures.check(res, "stand_in_fields",
		event != null and event.event_name == "check:" + CAT and event.event_type == "Primary"
		and event.success_formula == "" and not names.is_empty() and _names_eq(event.knowledges, names),
		"event %s" % ("null" if event == null else "%s %s knowledges %s" % [event.event_name, event.event_type,
			str(event.knowledges)]))
	var missing: EventData = ContractLibrary.event("check:Nope")
	TestFixtures.check(res, "stand_in_null", missing == null, "event %s" % str(missing))
	_end()


static func _case_boosts(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Know", {"Knowledges": "Zoology 20"}),
		_row("Circ", {"Circumstances": "Finesse (Dexterity) 50"})]
	_use_rows(rows)
	var merc: MercenaryData = _merc("Booster")
	var zoology := UtilityTraitData.new()
	zoology.utility_name = "Zoology"
	merc.knowledges.append(zoology)
	merc.circumstance_flags["Finesse (Dexterity)"] = true
	var old: float = OverallSuccess.base(merc)
	var know_rec: Dictionary = CheckStore.apply_boosts(merc, CheckStore.parse(CheckStore.find("Know")), old)
	var raised: float = OverallSuccess.base(merc)
	CheckStore.revert_boosts(know_rec)
	var back: float = OverallSuccess.base(merc)
	var bonus_old: float = float(merc.circumstance_additional_bonus.get("Finesse (Dexterity)", 0.0))
	var circ_rec: Dictionary = CheckStore.apply_boosts(merc, CheckStore.parse(CheckStore.find("Circ")),
		OverallSuccess.base(merc))
	var bonus_up: float = float(merc.circumstance_additional_bonus.get("Finesse (Dexterity)", 0.0))
	CheckStore.revert_boosts(circ_rec)
	var bonus_back: float = float(merc.circumstance_additional_bonus.get("Finesse (Dexterity)", 0.0))
	TestFixtures.check(res, "boosts_apply_revert",
		is_equal_approx(raised, old + 20.0) and back == old
		and is_equal_approx(bonus_up, bonus_old + 0.5 * (15.0 + bonus_old)) and is_equal_approx(bonus_back, bonus_old),
		"base %.2f -> %.2f -> %.2f; circ %.2f -> %.2f -> %.2f" % [old, raised, back, bonus_old, bonus_up, bonus_back])
	_end()


static func _hellion(merc: MercenaryData) -> MercenaryData:
	merc.tradition = TraditionData.new()
	merc.tradition.tradition_name = "Hellion"
	return merc


#Own-tradition values (#703) and knowledge and tool values (#719) add points to the base.
static func _case_tradition_points(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Trad", {"Traditions": "Hellion +15"}),
		_row("Mix", {"Knowledges": "Zoology 20", "Traditions": "Hellion +15"})]
	_use_rows(rows)
	var merc: MercenaryData = _hellion(_merc("Trad", {"base_success_chance": 1.0}))
	var parsed: Dictionary = CheckStore.parse(CheckStore.find("Trad"))
	var def: Dictionary = CheckStore.check_def(parsed)
	var raw_before: float = CheckSystem.threshold_for(merc, def)
	var record: Dictionary = CheckStore.apply_boosts(merc, parsed, OverallSuccess.base(merc))
	var delta: float = float(record.get("delta", 0.0))
	var raised: float = OverallSuccess.base(merc)
	var raw_after: float = CheckSystem.threshold_for(merc, def)
	var lines: Array[String] = []
	lines.assign(record.get("lines", []))
	CheckStore.revert_boosts(record)
	var back: float = OverallSuccess.base(merc)
	TestFixtures.check(res, "boosts_tradition_points",
		is_equal_approx(delta, 15.0) and is_equal_approx(raised, 16.0) and is_equal_approx(back, 1.0),
		"delta %.2f, raised base %.2f, reverted base %.2f" % [delta, raised, back])
	TestFixtures.check(res, "boosts_tradition_threshold", is_equal_approx(raw_after - raw_before, 15.0),
		"raw %.2f before, %.2f after" % [raw_before, raw_after])
	var want: String = "CHECK BOOST: Trad row +15 points -> delta 15.0"
	TestFixtures.check(res, "boosts_tradition_log", lines.has(want), "lines %s" % str(lines))
	var mixed: MercenaryData = _hellion(_merc("Mixed", {"base_success_chance": 50.0}))
	var zoology := UtilityTraitData.new()
	zoology.utility_name = "Zoology"
	mixed.knowledges.append(zoology)
	var mix_rec: Dictionary = CheckStore.apply_boosts(mixed, CheckStore.parse(CheckStore.find("Mix")),
		OverallSuccess.base(mixed))
	var mixed_base: float = OverallSuccess.base(mixed)
	CheckStore.revert_boosts(mix_rec)
	TestFixtures.check(res, "boosts_mixed", is_equal_approx(mixed_base, 85.0),
		"base 50 with Zoology 20 and Hellion +15 read %.2f" % mixed_base)
	_end()


static func _case_roller(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Climb", {"Attributes": "Dexterity"})]
	_use_rows(rows)
	var parsed: Dictionary = CheckStore.parse(CheckStore.find("Climb"))
	var weak: MercenaryData = _merc("Weak")
	var strong: MercenaryData = _merc("Strong", {"dexterity": 4})
	var team: Array[MercenaryData] = [weak, strong]
	var got: MercenaryData = CheckStore.rank_roller(team, parsed, null)
	TestFixtures.check(res, "roller_highest", got == strong, "roller %s" % (got.merc_name if got != null else "null"))
	var first: MercenaryData = _merc("First")
	var second: MercenaryData = _merc("Second")
	var pair: Array[MercenaryData] = [first, second]
	got = CheckStore.rank_roller(pair, parsed, second)
	TestFixtures.check(res, "roller_tie_leader", got == second,
		"roller %s" % (got.merc_name if got != null else "null"))
	got = CheckStore.rank_roller(pair, parsed, null)
	TestFixtures.check(res, "roller_tie_order", got == first, "roller %s" % (got.merc_name if got != null else "null"))
	got = CheckStore.rank_roller(team, parsed, weak)
	TestFixtures.check(res, "roller_non_leader", got == strong,
		"roller %s" % (got.merc_name if got != null else "null"))
	_end()


#A Checks.tsv knowledge value is threshold points, not a percent of the stat (#719).
static func _case_knowledge_points(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Zoo", {"Knowledges": "Zoology 15"})]
	_use_rows(rows)
	var merc: MercenaryData = _merc("Zoologist")
	var zoology := UtilityTraitData.new()
	zoology.utility_name = "Zoology"
	merc.knowledges.append(zoology)
	var old: float = OverallSuccess.base(merc)
	var record: Dictionary = CheckStore.apply_boosts(merc, CheckStore.parse(CheckStore.find("Zoo")), old)
	var raised: float = OverallSuccess.base(merc)
	CheckStore.revert_boosts(record)
	TestFixtures.check(res, "#719 knowledge Zoology 15 adds 15 points", is_equal_approx(raised - old, 15.0),
		"base %.2f -> %.2f" % [old, raised])
	_end()


#Tool values add points like knowledges (#719); negative row points stop the base at 0.
static func _case_tool_points_floor(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Trap", {"Tools": "Trapper's 15"}), _row("Low", {"Traditions": "Mage -80"})]
	_use_rows(rows)
	var trapper: MercenaryData = _merc("Trapper", {"base_success_chance": 50.0})
	var kit := UtilityTraitData.new()
	kit.utility_name = "Trapper's Tools"
	trapper.tools.append(kit)
	var old: float = OverallSuccess.base(trapper)
	var record: Dictionary = CheckStore.apply_boosts(trapper, CheckStore.parse(CheckStore.find("Trap")), old)
	var raised: float = OverallSuccess.base(trapper)
	CheckStore.revert_boosts(record)
	TestFixtures.check(res, "#719 tool Trapper's 15 adds 15 points", is_equal_approx(raised - old, 15.0),
		"base %.2f -> %.2f" % [old, raised])
	var mage: MercenaryData = _merc("Mage", {"base_success_chance": 50.0})
	mage.tradition = TraditionData.new()
	mage.tradition.tradition_name = "Mage"
	var base0: float = OverallSuccess.base(mage)
	var low: Dictionary = CheckStore.apply_boosts(mage, CheckStore.parse(CheckStore.find("Low")), base0)
	var low_delta: float = float(low.get("delta", 0.0))
	var floored: float = OverallSuccess.base(mage)
	CheckStore.revert_boosts(low)
	TestFixtures.check(res, "#719 negative row points stop the base at 0",
		base0 > 0.0 and is_equal_approx(low_delta, -base0) and is_equal_approx(floored, 0.0),
		"base %.2f delta %.2f floored %.2f" % [base0, low_delta, floored])
	_end()


static func _difficulty_contract(stars: float) -> ContractData:
	var contract := ContractData.new()
	contract.style = "check"
	contract.difficulty = stars
	return contract


static func _case_difficulty_points(res: Dictionary) -> void:
	var want: Dictionary = {0.5: 25.0, 3.0: 0.0, 5.0: -12.0, 0.75: 21.5, 0.0: 0.0, 6.0: -12.0}
	var why: PackedStringArray = []
	var ok: bool = true
	for stars: float in want:
		var got: float = CheckStore.difficulty_points(_difficulty_contract(stars))
		ok = ok and is_equal_approx(got, float(want[stars]))
		why.append("%.2f -> %.2f" % [stars, got])
	var none: float = CheckStore.difficulty_points(null)
	TestFixtures.check(res, "#720 difficulty_points table, interpolation and clamps", ok and none == 0.0,
		"%s; null -> %.2f" % [", ".join(why), none])


static func _case_difficulty_def(res: Dictionary) -> void:
	_begin()
	var parsed: Dictionary = CheckStore.parse(CheckStore.find(CAT))
	var plain: Dictionary = CheckStore.check_def(parsed)
	var def: Dictionary = CheckStore.check_def(parsed, 25.0)
	var merc: MercenaryData = _merc("Graded", {"base_success_chance": 20.0})
	var before: float = float(CheckSystem.success_distribution(merc, plain)["threshold"])
	var first: float = float(CheckSystem.success_distribution(merc, def)["threshold"])
	var half: Dictionary = CheckStore.half_def(def, CheckSystem.threshold_for(merc, def), first)
	var retry: float = float(CheckSystem.success_distribution(merc, half)["threshold"])
	TestFixtures.check(res, "#720 check_def bonus rides flat_threshold_bonus",
		is_equal_approx(float(def["flat_threshold_bonus"]), 25.0) and is_equal_approx(first - before, 25.0),
		"bonus %.2f threshold %.2f -> %.2f" % [float(def["flat_threshold_bonus"]), before, first])
	TestFixtures.check(res, "#720 half_def halves the difficulty points with the threshold",
		is_equal_approx(retry, first / 2.0), "first %.2f retry %.2f" % [first, retry])
	_end()


#Many dice on a low base lose to one die on a high base until the difficulty points lift every die.
static func _case_difficulty_roller(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Climb", {"Attributes": "Dexterity"})]
	_use_rows(rows)
	var parsed: Dictionary = CheckStore.parse(CheckStore.find("Climb"))
	var many: MercenaryData = _merc("Many", {"dexterity": 6, "base_success_chance": 1.0})
	var one: MercenaryData = _merc("One", {"dexterity": 1, "base_success_chance": 40.0})
	var team: Array[MercenaryData] = [many, one]
	var plain: MercenaryData = CheckStore.rank_roller(team, parsed, null)
	var easy: MercenaryData = CheckStore.rank_roller(team, parsed, null, 25.0)
	var contract_run: ContractRun = ContractRun.make(_difficulty_contract(0.5), team, Callable())
	CheckEventResolver.resolve(CheckStore.stand_in("Climb"), contract_run)
	var header: String = _first_line(contract_run.log_lines, "CHECK: Climb roller ")
	TestFixtures.check(res, "#720 rank_roller takes the difficulty points",
		plain == one and easy == many, "plain %s easy %s" % [
			plain.merc_name if plain != null else "null", easy.merc_name if easy != null else "null"])
	TestFixtures.check(res, "#720 resolve rolls with the rank_roller pick at 0.5 stars",
		header.begins_with("CHECK: Climb roller Many "), "header '%s'" % header)
	_end()


static func _case_difficulty_resolve(res: Dictionary) -> void:
	_begin()
	var merc: MercenaryData = _merc("Graded")
	var team: Array[MercenaryData] = [merc]
	var dice: int = _row_dice(merc, CAT)
	var thresholds: Array[float] = []
	var lines: Array[String] = []
	for stars: float in [0.0, 0.5]:
		var contract_run: ContractRun = ContractRun.make(_difficulty_contract(stars), team, Callable())
		CheckSystem.forced_rolls.clear()
		CheckSystem.forced_rolls.append_array(_passes(dice))
		CheckEventResolver.resolve(CheckStore.stand_in(CAT), contract_run)
		thresholds.append(_line_threshold(_first_line(contract_run.log_lines, "CHECK ROLL 1:")))
		lines = contract_run.log_lines
	var at: int = -1
	for i: int in range(lines.size()):
		if lines[i].begins_with("CHECK: "):
			at = i
			break
	var next: String = lines[at + 1] if at >= 0 and at + 1 < lines.size() else ""
	TestFixtures.check(res, "#720 resolve threshold rises by the difficulty points",
		is_equal_approx(thresholds[1] - thresholds[0], 25.0), "thresholds %s" % str(thresholds))
	TestFixtures.check(res, "#720 CHECK DIFFICULTY line follows the check header",
		next == "CHECK DIFFICULTY: 0.5 stars +25.0 points", "line '%s'" % next)
	var retried: ContractRun = ContractRun.make(_difficulty_contract(0.5), team, Callable())
	CheckSystem.forced_rolls.clear()
	CheckSystem.forced_rolls.append_array(_fails(dice, 2))
	CheckEventResolver.resolve(CheckStore.stand_in(CAT), retried)
	var emits: int = retried.log_lines.filter(
		func(l: String) -> bool: return l.begins_with("CHECK DIFFICULTY:")).size()
	var retry_line: String = _first_line(retried.log_lines, "CHECK RETRY 1/")
	TestFixtures.check(res, "#720 CHECK DIFFICULTY prints once per check, retry included",
		emits == 1 and retry_line != "", "%d lines, retry '%s'" % [emits, retry_line])
	_end()


static func _case_resolve_basic(res: Dictionary) -> void:
	_begin()
	var merc: MercenaryData = _merc("Climber")
	var team: Array[MercenaryData] = [merc]
	var dice: int = _row_dice(merc, CAT)
	var r: Dictionary = _resolve(CAT, team, _passes(dice))
	var out: Dictionary = r["out"]
	TestFixtures.check(res, "resolve_pass",
		bool(out["success"]) and int(out["attempts"]) == 1 and int(out["minutes"]) == 60 and int(out["needed"]) == 1
		and (out["consequences"] as Array).is_empty(),
		"success %s attempts %d minutes %d needed %d consequences %s" % [str(out["success"]), int(out["attempts"]),
			int(out["minutes"]), int(out["needed"]), str(out["consequences"])])
	TestFixtures.check(res, "resolve_mark", (r["run"] as ContractRun).event_marks.has(CAT),
		"marks %s" % str((r["run"] as ContractRun).event_marks))

	var first: float = float(CheckSystem.success_distribution(merc,
		CheckStore.check_def(CheckStore.parse(CheckStore.find(CAT))))["threshold"])
	var rolls: Array[int] = _fails(dice, 1)
	rolls.append_array(_passes(dice))
	r = _resolve(CAT, team, rolls)
	out = r["out"]
	var retry_line: String = _first_line(_lines(r), "CHECK RETRY 1/")
	var retry_t: float = _line_threshold(retry_line)
	TestFixtures.check(res, "resolve_retry_pass",
		bool(out["success"]) and int(out["attempts"]) == 2 and int(out["minutes"]) == 120
		and absf(retry_t - first / 2.0) <= 0.05,
		"attempts %d minutes %d retry threshold %.2f first %.2f line '%s'" % [int(out["attempts"]),
			int(out["minutes"]), retry_t, first, retry_line])

	var tired: MercenaryData = _merc("Tired")
	var solo: Array[MercenaryData] = [tired]
	r = _resolve(CAT, solo, _fails(_row_dice(tired, CAT), 2))
	out = r["out"]
	var want: String = "CHECK CONSEQUENCE: Tired loses 1 EP (5 -> 4)"
	TestFixtures.check(res, "resolve_fail_ep",
		not bool(out["success"]) and int(out["attempts"]) == 2 and tired.current_ep == 4 and _lines(r).has(want),
		"attempts %d EP %d consequences %s" % [int(out["attempts"]), tired.current_ep, str(out["consequences"])])
	_end()


static func _case_resolve_drains(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Hurt2", {"Consequence": "hp -2"}), _row("Hurt9", {"Consequence": "hp -9"}),
		_row("Mana", {"Consequence": "mp -1"}), _row("Tire", {"Consequence": "ep -1"})]
	_use_rows(rows)
	var hurt: MercenaryData = _merc("Hurt")
	var team: Array[MercenaryData] = [hurt]
	var dice: int = _row_dice(hurt, "Hurt2")
	_resolve("Hurt2", team, _fails(dice, 1))
	TestFixtures.check(res, "resolve_fail_hp", hurt.current_hp == 16, "HP %d" % hurt.current_hp)

	var low: MercenaryData = _merc("Low")
	low.current_hp = 2
	team = [low]
	_resolve("Hurt9", team, _fails(dice, 1))
	TestFixtures.check(res, "resolve_hp_floor", low.current_hp == 1, "HP %d" % low.current_hp)

	var plain: MercenaryData = _merc("Plain")
	var had_max: bool = plain.stats.has("maximum_magic_points")
	var mp_before: int = plain.current_mp
	team = [plain]
	var r: Dictionary = _resolve("Mana", team, _fails(dice, 1))
	var none_line: String = _first_line(_lines(r), "CHECK CONSEQUENCE: Plain MP")
	TestFixtures.check(res, "resolve_mp_none",
		not had_max and not plain.stats.has("maximum_magic_points") and plain.current_mp == mp_before
		and none_line.contains("none (no maximum)"),
		"max before %s after %s MP %d -> %d line '%s'" % [str(had_max), str(plain.stats.has("maximum_magic_points")),
			mp_before, plain.current_mp, none_line])

	var spent: MercenaryData = _merc("Spent")
	spent.current_ep = 0
	team = [spent]
	_resolve("Tire", team, _fails(dice, 1))
	TestFixtures.check(res, "resolve_ep_floor", spent.current_ep == 0, "EP %d" % spent.current_ep)

	var drained: MercenaryData = _merc("Drained", {"maximum_magic_points": 10})
	drained.current_mp = 0
	team = [drained]
	_resolve("Mana", team, _fails(dice, 1))
	TestFixtures.check(res, "resolve_mp_floor", drained.current_mp == 0, "MP %d" % drained.current_mp)
	_end()


static func _case_resolve_guild(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Shame", {"Consequence": "guild -1"})]
	_use_rows(rows)
	var a: MercenaryData = _merc("Ann")
	var b: MercenaryData = _merc("Bo")
	a.guild_opinion = 2
	b.guild_opinion = 2
	var team: Array[MercenaryData] = [a, b]
	var dice: int = _row_dice(a, "Shame")
	_resolve("Shame", team, _fails(dice, 1))
	TestFixtures.check(res, "resolve_guild", a.guild_opinion == 1 and b.guild_opinion == 1,
		"opinions %d %d" % [a.guild_opinion, b.guild_opinion])

	var c: MercenaryData = _merc("Cy")
	var d: MercenaryData = _merc("Dee")
	c.guild_opinion = 2
	d.guild_opinion = 2
	d.is_dead = true
	team = [c, d]
	_resolve("Shame", team, _fails(dice, 1))
	TestFixtures.check(res, "resolve_guild_living", c.guild_opinion == 1 and d.guild_opinion == 2,
		"living %d dead %d" % [c.guild_opinion, d.guild_opinion])
	_end()


static func _case_resolve_contract_row(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Plain")]
	_use_rows(rows)
	var merc: MercenaryData = _merc("Rowan")
	var team: Array[MercenaryData] = [merc]
	var dice: int = _row_dice(merc, "Plain")
	var r: Dictionary = _resolve("Plain", team, _fails(dice, 1), -1, "ep -1")
	var out: Dictionary = r["out"]
	var want: String = "CONTRACT CONSEQUENCE: Rowan loses 1 EP (5 -> 4)"
	TestFixtures.check(res, "resolve_contract_row",
		int(out["attempts"]) == 1 and merc.current_ep == 4 and _lines(r).has(want)
		and _first_line(_lines(r), "CHECK CONSEQUENCE:") == "",
		"attempts %d EP %d consequences %s" % [int(out["attempts"]), merc.current_ep, str(out["consequences"])])

	CheckStore.reset()
	var cat_merc: MercenaryData = _merc("Tabby")
	team = [cat_merc]
	r = _resolve(CAT, team, _fails(_row_dice(cat_merc, CAT), 3), -1, "retry -1")
	out = r["out"]
	var check_ep: bool = false
	var contract_line: bool = false
	for line: String in out["consequences"]:
		if line.begins_with("CHECK CONSEQUENCE:") and line.contains(" EP "):
			check_ep = true
		if line.begins_with("CONTRACT CONSEQUENCE:"):
			contract_line = true
	TestFixtures.check(res, "resolve_contract_retry_add",
		int(out["attempts"]) == 3 and int(out["minutes"]) == 180 and check_ep and not contract_line,
		"attempts %d minutes %d consequences %s" % [int(out["attempts"]), int(out["minutes"]),
			str(out["consequences"])])
	_end()


static func _case_resolve_outcome(res: Dictionary) -> void:
	_begin()
	var merc: MercenaryData = _merc("Keys")
	var team: Array[MercenaryData] = [merc]
	var r: Dictionary = _resolve(CAT, team, _passes(_row_dice(merc, CAT)))
	var out: Dictionary = r["out"]
	var ok: bool = typeof(out.get("check")) == TYPE_STRING and typeof(out.get("roller")) == TYPE_INT
	ok = ok and typeof(out.get("successes")) == TYPE_INT and typeof(out.get("needed")) == TYPE_INT
	ok = ok and typeof(out.get("attempts")) == TYPE_INT and typeof(out.get("rival_successes")) == TYPE_INT
	ok = ok and int(out.get("rival_successes", 0)) == -1 and typeof(out.get("consequences")) == TYPE_ARRAY
	ok = ok and typeof(out.get("minutes")) == TYPE_INT and out.has("success") and out.has("winner")
	ok = ok and out.has("rounds")
	TestFixtures.check(res, "resolve_outcome_keys", ok, "outcome %s" % str(out))
	TestFixtures.check(res, "resolve_drained", int(r["left"]) == 0 and CheckSystem.forced_rolls.is_empty(),
		"left %d" % int(r["left"]))
	_end()


static func _case_resolve_tally(res: Dictionary) -> void:
	_begin()
	LifepathTally.clear()
	var rows: Array[Dictionary] = [_row("Plain")]
	_use_rows(rows)
	var merc: MercenaryData = _merc("Tally")
	var team: Array[MercenaryData] = [merc]
	var before: int = LifepathTally.failure_count(merc)
	_resolve("Plain", team, _fails(_row_dice(merc, "Plain"), 1))
	var once: int = LifepathTally.failure_count(merc) - before
	TestFixtures.check(res, "resolve_tally_once", once == 1, "failures grew %d" % once)

	CheckStore.reset()
	before = LifepathTally.failure_count(merc)
	_resolve(CAT, team, _fails(_row_dice(merc, CAT), 2))
	var twice: int = LifepathTally.failure_count(merc) - before
	TestFixtures.check(res, "resolve_tally_retry", twice == 2, "failures grew %d" % twice)
	LifepathTally.clear()
	_end()


#Every die lands inside the luck band under the threshold, so the roll is a critical and passes with needed 8.
static func _case_resolve_critical(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Hard", {"Multiplier": "4.0"})]
	_use_rows(rows)
	var merc: MercenaryData = _merc("Lucky", {"luck": 10.0})
	var team: Array[MercenaryData] = [merc]
	var def: Dictionary = CheckStore.check_def(CheckStore.parse(CheckStore.find("Hard")))
	var dist: Dictionary = CheckSystem.success_distribution(merc, def)
	var value: int = int(floor(float(dist["threshold"]) - 5.0))
	var rolls: Array[int] = []
	for _i: int in range(int(dist["dice"])):
		rolls.append(value)
	CriticalSuccessSystem.banking = true
	var r: Dictionary = _resolve("Hard", team, rolls)
	merc.pending_crit_rewards.clear()
	CriticalSuccessSystem.banking = false
	var out: Dictionary = r["out"]
	var roll_line: String = _first_line(_lines(r), "CHECK ROLL 1:")
	TestFixtures.check(res, "resolve_critical",
		bool(out["success"]) and int(out["needed"]) == 8 and roll_line.ends_with(" CRITICAL -> PASS"),
		"success %s needed %d dice %d roll %d line '%s'" % [str(out["success"]), int(out["needed"]),
			int(dist["dice"]), value, roll_line])
	_end()


static func _case_resolve_opposed(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Duel", {"Opposed": "Yes", "Multiplier": "1.5"}),
		_row("Duel0", {"Opposed": "Yes"})]
	_use_rows(rows)
	var merc: MercenaryData = _merc("Duelist")
	var team: Array[MercenaryData] = [merc]
	var rival: MercenaryData = _merc("Rival")
	CheckStore.forced_rival = rival
	var parsed: Dictionary = CheckStore.parse(CheckStore.find("Duel"))
	var rival_dice: int = _dice(rival, CheckStore.rival_def(parsed))
	var dice: int = _row_dice(merc, "Duel")
	var rolls: Array[int] = _passes(mini(2, rival_dice))
	rolls.append_array(_fails(maxi(0, rival_dice - 2), 1))
	rolls.append_array(_fails(dice, 1))
	var r: Dictionary = _resolve("Duel", team, rolls)
	var out: Dictionary = r["out"]
	TestFixtures.check(res, "resolve_opposed",
		int(out["needed"]) == 3 and int(out["rival_successes"]) == 2,
		"needed %d rival %d rival dice %d" % [int(out["needed"]), int(out["rival_successes"]), rival_dice])

	CheckStore.forced_rival = rival
	rolls = _fails(rival_dice, 1)
	rolls.append_array(_passes(dice))
	r = _resolve("Duel0", team, rolls)
	out = r["out"]
	TestFixtures.check(res, "resolve_opposed_zero",
		int(out["needed"]) == 1 and int(out["rival_successes"]) == 0,
		"needed %d rival %d" % [int(out["needed"]), int(out["rival_successes"])])
	TestFixtures.check(res, "resolve_opposed_blank", CheckStore.rival_def(parsed) == CheckStore.check_def(parsed),
		"rival %s check %s" % [str(CheckStore.rival_def(parsed)), str(CheckStore.check_def(parsed))])

	CheckStore.forced_rival = null
	var contract := ContractData.new()
	contract.difficulty = 3.0
	contract.contract_level = 5
	var generated: MercenaryData = CheckStore.make_rival(team, contract)
	var req: OpponentRequest = CompetitionResolver.rival_request(team, contract.difficulty, contract.contract_level,
		"Check")
	req.count = 1
	req.count_formula = ""
	var count: int = OpponentGenerator.generate(req).size()
	TestFixtures.check(res, "make_rival_generated",
		generated != null and generated != merc and generated != rival and count == 1,
		"rival %s count %d" % [str(generated), count])
	_end()


static func _case_runner_routes(res: Dictionary) -> void:
	_begin()
	var merc: MercenaryData = _merc("Router")
	var team: Array[MercenaryData] = [merc]
	var contract_run: ContractRun = _run(team)
	CheckSystem.forced_rolls.append_array(_passes(_row_dice(merc, CAT)))
	var out: Dictionary = await EventRunner.run(CheckStore.stand_in(CAT), contract_run)
	TestFixtures.check(res, "runner_routes", out.has("check") and String(out["check"]) == CAT,
		"keys %s" % str(out.keys()))
	_end()


static func _case_generator_board(res: Dictionary) -> void:
	_begin()
	var cat: ContractData = ContractGenerator.generate_named(CAT_CONTRACT)
	TestFixtures.check(res, "generator_cat", cat != null and cat.assigned_primary_event == "check:" + CAT,
		"primary %s" % (cat.assigned_primary_event if cat != null else "null contract"))
	var live_hours: int = -1
	var long_hours: int = -1
	if cat != null:
		cat.rolled_mishaps.clear()
		live_hours = ContractBoard.completion_hours(cat)
		var rows: Array[Dictionary] = [_row(CAT, {"Time": "150"})]
		_use_rows(rows)
		long_hours = ContractBoard.completion_hours(cat)
		CheckStore.reset()
	TestFixtures.check(res, "board_hours_cat", live_hours == 1 and long_hours == 3,
		"live %d time 150 %d" % [live_hours, long_hours])
	var plain := ContractData.new()
	plain.style = "event"
	plain.assigned_primary_event = "Tavern Brawl"
	plain.rolled_mishaps.assign(["Mishap A", "Mishap B"])
	var want: int = 3 + 2 * ContractLibrary.config().board_gap_hours
	TestFixtures.check(res, "board_hours_plain", ContractBoard.completion_hours(plain) == want,
		"hours %d want %d" % [ContractBoard.completion_hours(plain), want])
	_end()


static func _case_clock(res: Dictionary) -> void:
	_begin()
	var rows: Array[Dictionary] = [_row("Slow", {"Time": "90"}), _row("SlowRetry", {"Time": "90",
		"Consequence": "retry -1"})]
	_use_rows(rows)
	var merc: MercenaryData = _merc("Clocker")
	var team: Array[MercenaryData] = [merc]
	var dice: int = _row_dice(merc, "Slow")
	var contract_run: ContractRun = _run(team)
	var event: EventData = CheckStore.stand_in("Slow")
	CampaignClock.reset()
	CheckSystem.forced_rolls.append_array(_passes(dice))
	await ContractManager.run_one_event(contract_run, event, event.event_name, true)
	TestFixtures.check(res, "clock_minutes", CampaignClock.now() == 90, "clock %d" % CampaignClock.now())

	contract_run = _run(team)
	event = CheckStore.stand_in("SlowRetry")
	CampaignClock.reset()
	CheckSystem.forced_rolls.clear()
	CheckSystem.forced_rolls.append_array(_fails(dice, 1))
	CheckSystem.forced_rolls.append_array(_passes(dice))
	await ContractManager.run_one_event(contract_run, event, event.event_name, true)
	var minutes: int = -1
	if not contract_run.outcomes.is_empty():
		minutes = int(contract_run.outcomes[0].get("minutes", -1))
	TestFixtures.check(res, "clock_two_attempts", CampaignClock.now() == 180 and minutes == 180,
		"clock %d outcome minutes %d" % [CampaignClock.now(), minutes])
	CampaignClock.reset()
	_end()


static func _case_validator(res: Dictionary) -> void:
	_begin()
	var want: String = "row 2 column Completion: no Checks.tsv row named Nope"
	var data := ContractData.new()
	data.style = "check"
	data.completion = "check:Nope"
	var warnings: Array[String] = ContractDataValidator.validate_contract(data, {"_row": 2})
	TestFixtures.check(res, "validator_missing_row", TestFixtures.has_line(warnings, want),
		"warnings %s" % str(warnings))
	var good := ContractData.new()
	good.style = "check"
	good.completion = "check:" + CAT
	var clean: Array[String] = ContractDataValidator.validate_contract(good, {"_row": 2})
	TestFixtures.check(res, "validator_row_ok", not TestFixtures.has_line(clean, "no Checks.tsv row named"),
		"warnings %s" % str(clean))
	_end()


#A respite trigger is forced to miss so a random ambush never joins the run.
static func _flow(cat: ContractData, rolls: Array[int]) -> ContractRun:
	var a: MercenaryData = _merc("Flow A")
	var b: MercenaryData = _merc("Flow B")
	var team: Array[MercenaryData] = [a, b]
	var missed: int = EventTrigger.missed_respites
	EventTrigger.missed_respites = 0
	EventTrigger.forced_d100 = 100
	CampaignClock.reset()
	CheckSystem.forced_rolls.clear()
	CheckSystem.forced_rolls.append_array(rolls)
	var contract_run: ContractRun = await ContractManager.run(cat, team, Callable())
	EventTrigger.forced_d100 = -1
	EventTrigger.missed_respites = missed
	CheckSystem.forced_rolls.clear()
	return contract_run


static func _case_manager_flow(res: Dictionary) -> void:
	_begin()
	var probe: MercenaryData = _merc("Probe")
	var dice: int = _row_dice(probe, CAT)
	var cat: ContractData = ContractGenerator.generate_named(CAT_CONTRACT)
	if cat == null:
		for label: String in ["manager_flow_cat", "manager_flow_fail", "manager_flow_missing"]:
			TestFixtures.check(res, label, false, "Cat contract did not generate")
		_end()
		return
	cat.rolled_mishaps.clear()
	var r: ContractRun = await _flow(cat, _passes(dice))
	TestFixtures.check(res, "manager_flow_cat",
		r.verdict == BoardEntry.STATUS_SUCCEEDED and r.reward_paid == cat.reward_notes
		and TestFixtures.has_line(r.log_lines, "CHECK RESULT: %s SUCCESS" % CAT),
		"verdict %s reward %d of %d failed %s" % [r.verdict, r.reward_paid, cat.reward_notes, r.failed_event])

	cat = ContractGenerator.generate_named(CAT_CONTRACT)
	cat.rolled_mishaps.clear()
	r = await _flow(cat, _fails(dice, 2))
	TestFixtures.check(res, "manager_flow_fail",
		r.verdict == BoardEntry.STATUS_FAILED and r.reward_paid == 0
		and TestFixtures.has_line(r.log_lines, "CHECK RESULT: %s FAILED" % CAT),
		"verdict %s reward %d" % [r.verdict, r.reward_paid])

	cat = ContractGenerator.generate_named(CAT_CONTRACT)
	cat.rolled_mishaps.clear()
	cat.assigned_primary_event = "check:Nope"
	r = await _flow(cat, [] as Array[int])
	TestFixtures.check(res, "manager_flow_missing",
		r.failed_event != "" and TestFixtures.has_line(r.log_lines, "EVENT MISSING: check:Nope"),
		"failed %s" % r.failed_event)
	CampaignClock.reset()
	_end()


static func _case_odds_kind(res: Dictionary) -> void:
	_begin()
	var cat: ContractData = ContractGenerator.generate_named(CAT_CONTRACT)
	var kind: String = "none"
	if cat != null:
		cat.rolled_mishaps.clear()
		var team: Array[MercenaryData] = [_merc("Odds A"), _merc("Odds B")]
		var model: OddsModel = OddsEstimator.prepare(cat, team)
		for entry: Dictionary in model.events:
			if bool(entry.get("primary", false)):
				kind = String(entry.get("kind", ""))
	TestFixtures.check(res, "odds_kind_check", kind == "check", "primary kind %s" % kind)
	_end()
