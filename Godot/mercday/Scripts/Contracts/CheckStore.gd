class_name CheckStore
extends RefCounted

#Checks.tsv rows for Style check contracts: lookup, parsing, stand-in events, row boosts, roller and rival.

const PREFIX := "check:"
const BASE_SUCCESSES := 2

#Test hooks: test_rows replaces DataManager.check_rows while non-empty; make_rival returns forced_rival while set.
static var test_rows: Array[Dictionary] = []
static var forced_rival: MercenaryData = null

const _RESOLVER_PATH := "res://Scripts/Contracts/CompetitionResolver.gd"
const _GENERATOR_PATH := "res://Scripts/Systems/OpponentGenerator.gd"


static func rows() -> Array[Dictionary]:
	if not test_rows.is_empty():
		return test_rows
	return DataManager.check_rows


static func bare_name(name: String) -> String:
	return name.strip_edges().trim_prefix(PREFIX).strip_edges()


#Exact Check Name first, then case-insensitive; the first row in file order wins. Callers must not write to it.
static func find(name: String) -> Dictionary:
	var bare: String = bare_name(name)
	if bare == "":
		return {}
	var all: Array[Dictionary] = rows()
	for row: Dictionary in all:
		if _cell(row, CheckSheet.NAME) == bare:
			return row
	var lower: String = bare.to_lower()
	for row: Dictionary in all:
		if _cell(row, CheckSheet.NAME).to_lower() == lower:
			return row
	return {}


static func has_row(name: String) -> bool:
	return not find(name).is_empty()


static func is_check_name(name: String) -> bool:
	return name.begins_with(PREFIX) and has_row(name)


static func parse(row: Dictionary) -> Dictionary:
	if row.is_empty():
		return {}
	var time: int = CheckSheet.parse_time(_cell(row, CheckSheet.TIME))
	return {
		"name": _cell(row, CheckSheet.NAME),
		"attributes": CheckSheet.parse_names(_cell(row, CheckSheet.ATTRIBUTES)),
		"circumstances": CheckSheet.parse_percents(_cell(row, CheckSheet.CIRCUMSTANCES)),
		"knowledges": CheckSheet.parse_percents(_cell(row, CheckSheet.KNOWLEDGES)),
		"tools": CheckSheet.parse_percents(_cell(row, CheckSheet.TOOLS)),
		"traditions": CheckSheet.parse_signed(_cell(row, CheckSheet.TRADITIONS)),
		"multiplier": CheckSheet.parse_multiplier(_cell(row, CheckSheet.MULTIPLIER)),
		"time": time,
		"minutes": time if time > 0 else CheckSheet.TIME_DEFAULT,
		"opposed": CheckSheet.parse_opposed(_cell(row, CheckSheet.OPPOSED)),
		"opposed_check": _cell(row, CheckSheet.OPPOSED_CHECK),
		"consequence": CheckSheet.parse_consequence(_cell(row, CheckSheet.CONSEQUENCE)),
	}


#Empty Attributes give an empty stat_keys list and CheckSystem rolls stat 0; Checks.tsv has no validator.
#bonus is flat per-die threshold points, the contract difficulty points on the merc side (#720).
static func check_def(parsed: Dictionary, bonus: float = 0.0) -> Dictionary:
	var stat_keys: Array = []
	for attribute: String in parsed.get("attributes", []):
		stat_keys.append(ContractModifiers.stat_key(attribute))
	return {
		"stat_keys": stat_keys,
		"circumstances": _names(parsed.get("circumstances", [])),
		"knowledges": _names(parsed.get("knowledges", [])),
		"tools": _names(parsed.get("tools", [])),
		"formula": "0",
		"flat_threshold_bonus": bonus,
	}


#Contract difficulty as per-die threshold points (#720): linear between half steps, clamped to 0.5..5; unset gives 0.
static func difficulty_points(contract: ContractData) -> float:
	if contract == null or contract.difficulty <= 0.0:
		return 0.0
	var table: Array[float] = ContractLibrary.config().difficulty_check_points
	if table.is_empty():
		return 0.0
	var at: float = clampf((contract.difficulty - 0.5) * 2.0, 0.0, float(table.size() - 1))
	var low: int = floori(at)
	var high: int = mini(low + 1, table.size() - 1)
	return lerpf(table[low], table[high], at - float(low))


#The retry def: the flat bonus lands the unclamped sum on half the clamped first-roll threshold.
static func half_def(def: Dictionary, raw: float, threshold: float) -> Dictionary:
	var out: Dictionary = def.duplicate(true)
	out["flat_threshold_bonus"] = float(def.get("flat_threshold_bonus", 0.0)) - (raw - threshold / 2.0)
	return out


static func rival_def(parsed: Dictionary) -> Dictionary:
	var other: Dictionary = parse(find(String(parsed.get("opposed_check", ""))))
	if not other.is_empty():
		return check_def(other)
	return check_def(parsed)


static func needed(multiplier: float, base: int = BASE_SUCCESSES) -> int:
	return maxi(1, ceili(base * multiplier))


static func opposed_needed(rival_successes: int, multiplier: float) -> int:
	return maxi(1, ceili(rival_successes * multiplier))


static func hours(parsed: Dictionary) -> int:
	if parsed.is_empty():
		return 1
	return maxi(1, ceili(float(parsed.get("minutes", CheckSheet.TIME_DEFAULT)) / 60.0))


#A fresh Primary EventData named as passed (prefix added when missing); null when no row has the name.
static func stand_in(name: String) -> EventData:
	var parsed: Dictionary = parse(find(name))
	if parsed.is_empty():
		return null
	var event := EventData.new()
	event.event_name = name if name.begins_with(PREFIX) else PREFIX + name
	event.event_type = "Primary"
	event.check_stats.assign(parsed["attributes"])
	event.circumstances.assign(_names(parsed["circumstances"]))
	event.knowledges.assign(_names(parsed["knowledges"]))
	event.tools.assign(_names(parsed["tools"]))
	event.success_formula = ""
	event.fail_ends_contract = false
	return event


#Matched knowledge, tool and own-tradition values of the row, summed as threshold points (#719).
static func row_points(merc: MercenaryData, parsed: Dictionary) -> float:
	if merc == null or parsed.is_empty():
		return 0.0
	var total: float = 0.0
	for entry: Dictionary in parsed.get("knowledges", []):
		if ContractModifiers.knowledge_matches(merc, String(entry.get("name", ""))):
			total += float(entry.get("percent", 0))
	for entry: Dictionary in parsed.get("tools", []):
		if ContractModifiers.tool_matches(merc, String(entry.get("name", ""))):
			total += float(entry.get("percent", 0))
	for entry: Dictionary in parsed.get("traditions", []):
		if ContractModifiers.tradition_matches(merc, String(entry.get("name", ""))):
			total += float(entry.get("value", 0))
	return total


#Row points as one delta that never takes the stat below 0; then circumstance percents.
static func apply_boosts(merc: MercenaryData, parsed: Dictionary, base0: float,
		floor_delta: float = 0.0) -> Dictionary:
	var lines: Array[String] = []
	var record: Dictionary = {"merc": merc, "delta": 0.0, "circ": {}, "lines": lines}
	if merc == null or parsed.is_empty():
		return record
	var points: float = row_points(merc, parsed)
	if points != 0.0:
		var delta: float = maxf(-(base0 + floor_delta), points)
		OverallSuccess.apply_delta(merc, delta)
		record["delta"] = delta
		lines.append("CHECK BOOST: %s row %+d points -> delta %.1f" % [merc.merc_name, roundi(points), delta])
	var circ: Dictionary = record["circ"]
	for entry: Dictionary in parsed.get("circumstances", []):
		var display: String = String(entry.get("name", ""))
		var circ_percent: float = float(entry.get("percent", 0))
		if circ_percent <= 0.0 or not bool(merc.circumstance_flags.get(display, false)):
			continue
		var existing: float = float(merc.circumstance_additional_bonus.get(display, 0.0))
		var circ_delta: float = circ_percent / 100.0 * (15.0 + existing)
		StatCalculator.prime(merc)
		merc.circumstance_additional_bonus[display] = existing + circ_delta
		StatCalculator.refresh(merc)
		circ[display] = float(circ.get(display, 0.0)) + circ_delta
		lines.append("CHECK CIRCUMSTANCE: %s %s +%.2f" % [merc.merc_name, display, circ_delta])
	return record


static func revert_boosts(record: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if record.is_empty():
		return lines
	var merc: MercenaryData = record.get("merc") as MercenaryData
	if merc != null:
		var circ: Dictionary = record.get("circ", {}) as Dictionary
		var displays: Array = circ.keys()
		displays.reverse()
		for display: String in displays:
			var circ_delta: float = float(circ[display])
			StatCalculator.prime(merc)
			merc.circumstance_additional_bonus[display] = float(
				merc.circumstance_additional_bonus.get(display, 0.0)) - circ_delta
			StatCalculator.refresh(merc)
			lines.append("CHECK BOOST REVERTED: %s %s -%.2f" % [merc.merc_name, display, circ_delta])
		var delta: float = float(record.get("delta", 0.0))
		if delta != 0.0:
			OverallSuccess.revert_event_delta({merc: delta})
			lines.append("CHECK BOOST REVERTED: %s row delta %.1f" % [merc.merc_name, delta])
	record.clear()
	return lines


#The living merc with the most expected successes under the row boosts; ties go to the leader, else the earliest.
#bonus is the difficulty_points the roll itself uses, so the ranking reads the same threshold.
static func rank_roller(team: Array[MercenaryData], parsed: Dictionary, leader: MercenaryData,
		bonus: float = 0.0) -> MercenaryData:
	var def: Dictionary = check_def(parsed, bonus)
	var best: float = 0.0
	var tied: Array[MercenaryData] = []
	for merc: MercenaryData in team:
		if merc == null or merc.is_dead:
			continue
		var record: Dictionary = apply_boosts(merc, parsed, OverallSuccess.base(merc))
		var expected: float = CheckSystem.expected_successes(merc, def)
		revert_boosts(record)
		if tied.is_empty() or (expected > best and not is_equal_approx(expected, best)):
			best = expected
			tied.clear()
			tied.append(merc)
		elif is_equal_approx(expected, best):
			tied.append(merc)
	if tied.is_empty():
		return null
	if leader != null and tied.has(leader):
		return leader
	return tied[0]


#Both scripts load at call time: a static reference puts MercGenerator inside DataManager's own load through the
#validator, and its action set preload then comes back as a plain Resource.
static func make_rival(team: Array[MercenaryData], contract: ContractData) -> MercenaryData:
	if forced_rival != null:
		return forced_rival
	if contract == null:
		return null
	var req: OpponentRequest = load(_RESOLVER_PATH).call("rival_request", team, contract.difficulty,
		contract.contract_level, "Check")
	req.count = 1
	req.count_formula = ""
	var rivals: Array = load(_GENERATOR_PATH).call("generate", req)
	return rivals[0] as MercenaryData if not rivals.is_empty() else null


static func reset() -> void:
	test_rows = []
	forced_rival = null


static func _cell(row: Dictionary, column: int) -> String:
	return str(row.get(CheckSheet.HEADER[column], "")).strip_edges()


static func _names(entries: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in entries:
		out.append(String(entry.get("name", "")))
	return out
