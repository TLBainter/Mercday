class_name LocalSimTests

#The "--local-sim" driver's matcher and stats aggregation on hand-built matrices and records.


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	_case_assignment(res)
	_case_counts(res)
	_case_attributes(res)
	_case_attributes_one_sided(res)
	_case_traditions(res)
	_case_utilities(res)
	_case_income(res)
	_case_prefixes(res)
	return TestFixtures.summarize(res, "LOCALSIM")


static func _record(test: int, row: String, tradition: String, success: bool, reward: int, stats: Array,
		knowledge: int, tool: int) -> Dictionary:
	return {"test": test, "row": row, "merc_name": "M", "tradition": tradition, "cognition": stats[0],
		"dexterity": stats[1], "vigor": stats[2], "wile": stats[3], "chance": 0.5 if success else 0.25,
		"verdict": "Succeeded" if success else "Failed", "success": success, "reward": reward,
		"knowledge_hits": knowledge, "tool_hits": tool, "tradition_points": 0, "casualties": 0, "errors": []}


#Twelve runs over two rows: Brave 4 of 6, Mage 1 of 4, Divine 2 of 2.
static func _records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var specs: Array = [
		[0, "A", "Brave", true, 100, [2, 1, 9, 1], 1, 0], [0, "B", "Brave", true, 50, [2, 1, 7, 1], 0, 1],
		[1, "A", "Brave", false, 0, [2, 1, 3, 1], 0, 0], [1, "B", "Mage", false, 0, [2, 1, 3, 1], 0, 0],
		[2, "A", "Brave", true, 100, [2, 1, 9, 1], 1, 1], [2, "B", "Mage", true, 50, [2, 1, 9, 1], 1, 0],
		[3, "A", "Brave", false, 0, [2, 1, 3, 1], 0, 0], [3, "B", "Mage", false, 0, [2, 1, 3, 1], 0, 0],
		[4, "A", "Brave", true, 100, [2, 1, 9, 1], 0, 0], [4, "B", "Mage", false, 0, [2, 1, 3, 1], 1, 0],
		[5, "A", "Divine", true, 100, [2, 1, 9, 1], 0, 0], [5, "B", "Divine", true, 50, [2, 1, 9, 1], 0, 1],
	]
	for s: Array in specs:
		out.append(_record(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7]))
	return out


static func _case_assignment(res: Dictionary) -> void:
	var three: Array = [[0.1, 0.9, 0.2], [0.8, 0.1, 0.3], [0.2, 0.3, 0.7]]
	var pick: Array[int] = HarnessLocalSim.best_assignment(three)
	TestFixtures.check(res, "localsim:assign_3x3_max", pick == [1, 0, 2], str(pick))
	var flat: Array = [[0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [0.5, 0.5, 0.5]]
	pick = HarnessLocalSim.best_assignment(flat)
	TestFixtures.check(res, "localsim:assign_3x3_tie_first", pick == [0, 1, 2], str(pick))
	var six: Array = []
	for m: int in range(6):
		var line: Array = []
		for c: int in range(6):
			line.append(0.9 if c == (m + 2) % 6 else 0.1)
		six.append(line)
	pick = HarnessLocalSim.best_assignment(six)
	TestFixtures.check(res, "localsim:assign_6x6_max", pick == [2, 3, 4, 5, 0, 1], str(pick))
	#Swapping mercs 0 and 1 between contracts 0 and 1 ties; the lexically first permutation wins.
	var tied: Array = [[0.6, 0.4, 0.0], [0.6, 0.4, 0.0], [0.0, 0.0, 0.9]]
	pick = HarnessLocalSim.best_assignment(tied)
	TestFixtures.check(res, "localsim:assign_tie_lexical", pick == [0, 1, 2], str(pick))


static func _case_counts(res: Dictionary) -> void:
	var lines: Array[String] = HarnessLocalSim.contract_lines(_records(), ["A", "B"])
	var want_a: String = "CONTRACT A: runs 6 successes 4 failures 2 success 67% mean_chance 41.7% mean_reward_success 100.0"
	var want_b: String = "CONTRACT B: runs 6 successes 3 failures 3 success 50% mean_chance 37.5% mean_reward_success 50.0"
	TestFixtures.check(res, "localsim:contract_lines", lines.size() == 2 and lines[0] == want_a and lines[1] == want_b,
		" | ".join(PackedStringArray(lines)))


static func _case_attributes(res: Dictionary) -> void:
	var ranked: Array[Dictionary] = HarnessLocalSim.attribute_deltas(_records())
	var order: Array[String] = []
	for entry: Dictionary in ranked:
		order.append(String(entry["stat"]))
	TestFixtures.check(res, "localsim:attribute_order", order == ["vigor", "cognition", "dexterity", "wile"],
		", ".join(PackedStringArray(order)))
	var vigor: Dictionary = ranked[0] if not ranked.is_empty() else {}
	TestFixtures.check(res, "localsim:attribute_delta", is_equal_approx(float(vigor.get("success_mean", 0.0)), 61.0 / 7.0)
		and is_equal_approx(float(vigor.get("fail_mean", 0.0)), 3.0)
		and is_equal_approx(float(vigor.get("delta", 0.0)), 61.0 / 7.0 - 3.0), str(vigor))


static func _case_attributes_one_sided(res: Dictionary) -> void:
	var records: Array[Dictionary] = [_record(0, "C", "Brave", true, 10, [3, 1, 5, 2], 0, 0),
		_record(1, "C", "Brave", true, 10, [1, 1, 3, 2], 0, 0)]
	var ranked: Array[Dictionary] = HarnessLocalSim.attribute_deltas(records)
	var order: Array[String] = []
	var all_nan: bool = ranked.size() == 4
	for entry: Dictionary in ranked:
		order.append(String(entry["stat"]))
		all_nan = all_nan and is_nan(float(entry["delta"])) and int(entry["won"]) == 2 and int(entry["lost"]) == 0
	TestFixtures.check(res, "localsim:attribute_one_sided_nan", all_nan
		and order == ["cognition", "dexterity", "vigor", "wile"], str(ranked))
	var lines: Array[String] = HarnessLocalSim.attribute_lines(records, ["C"])
	var want: String = "ATTRIBUTE DELTAS C: cognition n/a dexterity n/a vigor n/a wile n/a"
	var untagged: bool = true
	for line: String in lines:
		untagged = untagged and not line.contains("valuable")
	TestFixtures.check(res, "localsim:attribute_one_sided_lines", lines.size() == 5 and lines[4] == want
		and lines[0].ends_with("delta n/a") and untagged, " | ".join(PackedStringArray(lines)))


static func _case_traditions(res: Dictionary) -> void:
	var stats: Array[Dictionary] = HarnessLocalSim.tradition_stats(_records())
	var order: Array[String] = []
	for entry: Dictionary in stats:
		order.append("%s %d/%d" % [entry["name"], int(entry["successes"]), int(entry["runs"])])
	TestFixtures.check(res, "localsim:tradition_order", order == ["Divine 2/2", "Brave 4/6", "Mage 1/4"],
		", ".join(PackedStringArray(order)))
	var ends: Array[Dictionary] = HarnessLocalSim.best_worst_tradition(stats)
	TestFixtures.check(res, "localsim:tradition_fallback", ends.size() == 2 and ends[0]["name"] == "Divine"
		and ends[1]["name"] == "Mage", str(ends))
	var big: Array[Dictionary] = [{"name": "Few", "runs": 3, "successes": 3, "rate": 1.0},
		{"name": "Many", "runs": 12, "successes": 6, "rate": 0.5}, {"name": "Most", "runs": 10, "successes": 2,
		"rate": 0.2}]
	ends = HarnessLocalSim.best_worst_tradition(big)
	TestFixtures.check(res, "localsim:tradition_min_runs", ends.size() == 2 and ends[0]["name"] == "Many"
		and ends[1]["name"] == "Most", str(ends))


static func _case_utilities(res: Dictionary) -> void:
	var knowledge: Array[int] = HarnessLocalSim.split_counts(_records(), "knowledge_hits")
	var tool: Array[int] = HarnessLocalSim.split_counts(_records(), "tool_hits")
	TestFixtures.check(res, "localsim:utility_split", knowledge == [3, 4, 4, 8] and tool == [3, 3, 4, 9],
		"knowledge %s tool %s" % [str(knowledge), str(tool)])


static func _case_income(res: Dictionary) -> void:
	var records: Array[Dictionary] = _records()
	records.append(_record(6, "A", "Mage", false, -20, [1, 1, 1, 1], 0, 0))
	var money: Dictionary = HarnessLocalSim.income(records)
	TestFixtures.check(res, "localsim:income_tests", int(money["increased"]) == 4 and int(money["decreased"]) == 1
		and int(money["flat"]) == 2, str(money))
	TestFixtures.check(res, "localsim:income_runs", int(money["paid"]) == 7 and int(money["unpaid"]) == 6
		and int(money["sinks"]) == 1 and int(money["min"]) == -20 and int(money["max"]) == 150
		and is_equal_approx(float(money["mean"]), 530.0 / 7.0), str(money))


static func _case_prefixes(res: Dictionary) -> void:
	var lines: Array[String] = HarnessLocalSim.summary_lines(_records(), ["A", "B"], 7, 1, ["test 6: A did not generate"])
	var off: Array[String] = []
	for line: String in lines:
		if not line.begins_with(HarnessLocalSim.PREFIX):
			off.append(line)
	var first: String = lines[0] if not lines.is_empty() else ""
	TestFixtures.check(res, "localsim:prefixes", off.is_empty() and lines.size() > 15, "%d lines, off %s"
		% [lines.size(), " | ".join(PackedStringArray(off))])
	TestFixtures.check(res, "localsim:tests_line", first == "LOCALSIM TESTS: run 6 skipped 1 runs 12 anomalies 1", first)
	var best: bool = lines.has("LOCALSIM BEST TRADITION: Divine 100% of 2") \
		and lines.has("LOCALSIM WORST TRADITION: Mage 25% of 4")
	TestFixtures.check(res, "localsim:best_worst_lines", best, "best and worst tradition lines")
