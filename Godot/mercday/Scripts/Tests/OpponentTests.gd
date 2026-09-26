class_name OpponentTests
#Run: godot --headless --path . -- --opponent-tests
#OpponentGenerator: formula tokens, count and level rolls, the Mercs, template and crew branches, skew and hooks.

const TAG := "OpponentTests"
const AMBUSH := "Ambush"
const SKIRMISH := "Assist with the Skirmish"
const BANDIT := "Bandit Melee"
const CORE: Array[String] = ["vigor", "cognition", "wile", "dexterity"]


static func run() -> bool:
	var res: Dictionary = {"pass": 0, "fail": 0}
	ContractResourceBuilder.build_all()
	_case_difficulty_factor(res)
	_case_level_band(res)
	_case_tokens(res)
	_case_randf(res)
	_case_bad_formula(res)
	_case_floors(res)
	_case_level_order(res)
	_case_mercs_levels(res)
	_case_traditions(res)
	_case_statics_restored(res)
	_case_weighted_multiplier(res)
	_case_tradition_odds(res)
	_case_skew(res)
	_case_hooks(res)
	_case_outputs(res)
	_case_npc_fixed_level(res)
	_case_crew(res)
	_case_level_wrapper(res)
	_case_enemy_team(res)
	_reset_statics()
	return TestFixtures.summarize(res, "OPPONENT")


static func _reset_statics() -> void:
	MercGenerator.forced_level = -1
	MercGenerator.forced_tradition = ""
	MercGenerator.tradition_odds = {}


#Bare mercs with a set level; PartyStats reads nothing else.
static func _party(count: int, level: float) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for i: int in range(count):
		var m := MercenaryData.new()
		m.merc_name = "Party %d" % i
		m.stats = {"level": level}
		out.append(m)
	return out


static func _mercs_request(count: int, avg: float, difficulty: float) -> OpponentRequest:
	var req := OpponentRequest.new()
	req.source = "Mercs"
	req.count = count
	req.party = _party(4, avg)
	req.difficulty = difficulty
	req.tag = TAG
	return req


static func _trad_name(merc: MercenaryData) -> String:
	if merc == null or merc.tradition == null:
		return "null"
	return merc.tradition.tradition_name


static func _levels(mercs: Array[MercenaryData]) -> Array[int]:
	var out: Array[int] = []
	for merc: MercenaryData in mercs:
		out.append(int(merc.stats.get("level", -1)))
	return out


static func _statics_snapshot() -> String:
	return "%s|%s|%s|%s|%s|%d|%s|%s" % [str(RollingPenalties.tradition_batch_counts),
		str(RollingPenalties.rolling_penalties), str(RollingPenalties.rolling_penalty_age),
		str(RollingPenalties.rolling_stat_penalties), str(RollingPenalties.rolling_stat_penalty_age),
		MercGenerator.forced_level, MercGenerator.forced_tradition, str(MercGenerator.tradition_odds)]


static func _case_difficulty_factor(res: Dictionary) -> void:
	_reset_statics()
	var d0: float = OpponentGenerator.difficulty_factor(0.0)
	var d1: float = OpponentGenerator.difficulty_factor(1.0)
	var d3: float = OpponentGenerator.difficulty_factor(3.0)
	var d5: float = OpponentGenerator.difficulty_factor(5.0)
	TestFixtures.check(res, "difficulty_factor spans 0.5 to 2.0",
		is_equal_approx(d1, 0.5) and is_equal_approx(d3, 1.25) and is_equal_approx(d5, 2.0),
		"D1 %.4f D3 %.4f D5 %.4f" % [d1, d3, d5])
	TestFixtures.check(res, "an unrolled difficulty reads as 1.0", is_equal_approx(d0, 1.0), "D0 %.4f" % d0)


static func _bounds_match(got: Array[float], want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i: int in range(got.size()):
		if absf(got[i] - float(want[i])) > 0.0005:
			return false
	return true


static func _bounds_text(bounds: Array[float]) -> String:
	return "%.4f / %.4f / %.4f" % [bounds[0], bounds[1], bounds[2]]


static func _case_level_band(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	for d: float in [1.0, 2.0, 3.0, 4.0, 5.0]:
		var bounds: Array[float] = OpponentGenerator.level_band_bounds(d)
		var want_mean: float = (bounds[0] + bounds[1] + bounds[2]) / 3.0
		var low: float = 9999.0
		var high: float = -9999.0
		var total: float = 0.0
		for _i: int in range(2000):
			var draw: float = OpponentGenerator.level_band(d)
			low = minf(low, draw)
			high = maxf(high, draw)
			total += draw
		var mean: float = total / 2000.0
		TestFixtures.check(res, "difficulty %.0f draws stay in band around their mean" % d,
			low >= bounds[0] - 0.0005 and high <= bounds[2] + 0.0005 and absf(mean - want_mean) <= 0.05,
			"2000 draws, %.3f to %.3f, mean %.3f against %.3f in a band of %s"
			% [low, high, mean, want_mean, _bounds_text(bounds)])
	var half_low: Array[float] = OpponentGenerator.level_band_bounds(2.5)
	var half_high: Array[float] = OpponentGenerator.level_band_bounds(4.5)
	TestFixtures.check(res, "a half step interpolates between the two rows",
		_bounds_match(half_low, [0.5, 1.125, 1.5]) and _bounds_match(half_high, [0.75, 1.375, 2.0]),
		"2.5 gives %s, 4.5 gives %s" % [_bounds_text(half_low), _bounds_text(half_high)])
	var unrolled: Array[float] = OpponentGenerator.level_band_bounds(0.0)
	var over: Array[float] = OpponentGenerator.level_band_bounds(7.0)
	var under: Array[float] = OpponentGenerator.level_band_bounds(0.5)
	TestFixtures.check(res, "an unrolled difficulty reads as the row for 2 and the ends clamp",
		_bounds_match(unrolled, [0.5, 1.0, 1.5]) and _bounds_match(over, [1.0, 1.5, 2.0])
		and _bounds_match(under, [0.5, 0.75, 1.25]),
		"0.0 gives %s, 7.0 gives %s, 0.5 gives %s"
		% [_bounds_text(unrolled), _bounds_text(over), _bounds_text(under)])
	var pinned: Variant = OpponentGenerator.eval_formula("level_band", {"level_band": 1.3})
	TestFixtures.check(res, "a pinned level_band beats the draw",
		pinned != null and is_equal_approx(float(pinned), 1.3), "got %s" % str(pinned))
	var drawn: Variant = OpponentGenerator.eval_formula("level_band", {"difficulty": 5.0})
	TestFixtures.check(res, "the level_band token draws inside its difficulty band",
		drawn != null and float(drawn) >= 1.0 and float(drawn) <= 2.0, "got %s against 1.0 to 2.0" % str(drawn))
	var differed: bool = false
	for _i: int in range(20):
		var diff: Variant = OpponentGenerator.eval_formula("level_band - level_band", {"difficulty": 5.0})
		if diff != null and not is_zero_approx(float(diff)):
			differed = true
			break
	TestFixtures.check(res, "two level_band tokens in one formula draw apart", differed,
		"a nonzero difference within 20 tries" if differed else "every try gave 0")
	var tall := OpponentRequest.new()
	tall.resolved_ctx = {"average_level": 20.0, "merc_count": 4, "difficulty": 5.0}
	tall.level_formula = "party.average_level * 3"
	var capped: int = OpponentGenerator.roll_level(tall)
	tall.level_max = 45
	var capped_max: int = OpponentGenerator.roll_level(tall)
	TestFixtures.check(res, "the level cap of 40 holds over the formula and a wider level_max",
		capped == 40 and capped_max == 40, "60 gives %d, 60 with a max of 45 gives %d" % [capped, capped_max])
	var crew_req := OpponentRequest.new()
	crew_req.source = "Bandit Leader, Bandit Melee"
	crew_req.count = 3
	crew_req.party = _party(4, 6.0)
	crew_req.fixed_level = 39
	crew_req.tag = TAG
	var crew: Array[int] = _levels(OpponentGenerator.generate(crew_req))
	TestFixtures.check(res, "the leader bump stops at the level cap",
		crew.size() == 3 and crew[0] == 40 and crew[1] == 39 and crew[2] == 39,
		"levels %s; the bump asked for 43" % str(crew))


static func _case_tokens(res: Dictionary) -> void:
	_reset_statics()
	var cases: Array = [
		["party.merc_count", {"merc_count": 4}, 4.0],
		["party.average_level", {"average_level": 6.5}, 6.5],
		["bad_luck_roll", {"bad_luck_roll": 3}, 3.0],
		["difficulty_factor", {"difficulty_factor": 1.7}, 1.7],
		["difficulty_factor", {"difficulty": 5.0}, 2.0],
		["contract.difficulty", {"difficulty": 3.5}, 3.5],
		["npc.level", {"npc_level": 9}, 9.0],
	]
	for entry: Array in cases:
		var formula: String = str(entry[0])
		var ctx: Dictionary = entry[1]
		var want: float = float(entry[2])
		var got: Variant = OpponentGenerator.eval_formula(formula, ctx)
		TestFixtures.check(res, "token %s read from %s" % [formula, str(ctx.keys())],
			got != null and is_equal_approx(float(got), want), "got %s, want %s" % [str(got), str(want)])


static func _case_randf(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var two: Variant = OpponentGenerator.eval_formula("randf(1, 1) + randf(1, 1)", {})
	TestFixtures.check(res, "two randf calls in one formula both resolve",
		two != null and is_equal_approx(float(two), 2.0), "got %s" % str(two))
	var differed: bool = false
	for _i: int in range(20):
		var diff: Variant = OpponentGenerator.eval_formula("randf(0, 1000) - randf(0, 1000)", {})
		if diff != null and not is_zero_approx(float(diff)):
			differed = true
			break
	TestFixtures.check(res, "identical randf calls roll apart", differed,
		"a nonzero difference within 20 tries" if differed else "every try gave 0")
	var six: Variant = OpponentGenerator.eval_formula("randf(2 * 3, 2 * 3)", {})
	TestFixtures.check(res, "randf bounds are expressions",
		six != null and is_equal_approx(float(six), 6.0), "got %s" % str(six))


static func _case_bad_formula(res: Dictionary) -> void:
	_reset_statics()
	var broken: Variant = OpponentGenerator.eval_formula("max(1,", {})
	TestFixtures.check(res, "a formula that does not parse gives null", broken == null, "got %s" % str(broken))
	var blank: Variant = OpponentGenerator.eval_formula("", {})
	TestFixtures.check(res, "a blank formula gives null", blank == null, "got %s" % str(blank))


static func _case_floors(res: Dictionary) -> void:
	_reset_statics()
	var zero: int = OpponentGenerator.eval_count("0", {})
	var negative: int = OpponentGenerator.eval_count("-3", {})
	TestFixtures.check(res, "eval_count never drops below 1", zero == 1 and negative == 1,
		"0 gives %d, -3 gives %d" % [zero, negative])
	var level: int = OpponentGenerator.eval_level("-5", {})
	TestFixtures.check(res, "eval_level never drops below 0", level == 0, "-5 gives %d" % level)


static func _case_level_order(res: Dictionary) -> void:
	_reset_statics()
	var req := OpponentRequest.new()
	req.resolved_ctx = {"average_level": 0.0, "merc_count": 4, "difficulty": 0.0, "difficulty_factor": 1.0}
	req.fixed_level = 9
	req.level_formula = "3"
	req.level_min = 1
	req.level_max = 5
	var fixed: int = OpponentGenerator.roll_level(req, "4")
	TestFixtures.check(res, "a fixed level beats every formula and clamp", fixed == 9, "level %d" % fixed)
	req.fixed_level = -1
	req.level_min = -1
	req.level_max = -1
	var request_first: int = OpponentGenerator.roll_level(req, "4")
	TestFixtures.check(res, "the request formula beats the template one", request_first == 3,
		"level %d" % request_first)
	req.level_formula = ""
	var template_next: int = OpponentGenerator.roll_level(req, "4")
	TestFixtures.check(res, "the template formula beats the config one", template_next == 4,
		"level %d" % template_next)
	var config_last: int = OpponentGenerator.roll_level(req, "")
	TestFixtures.check(res, "the config formula fills in when both are blank", config_last == 1,
		"an average of 0 gives %d; a blank formula would give 0" % config_last)
	req.level_formula = "3"
	req.level_min = 5
	var raised: int = OpponentGenerator.roll_level(req, "")
	req.level_formula = "30"
	req.level_min = -1
	req.level_max = 12
	var capped: int = OpponentGenerator.roll_level(req, "")
	TestFixtures.check(res, "level_min and level_max clamp the roll", raised == 5 and capped == 12,
		"3 with a min of 5 gives %d, 30 with a max of 12 gives %d" % [raised, capped])


static func _case_mercs_levels(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var avg: float = 6.0
	var lo: int = maxi(1, int(floorf(avg * 0.5)))
	var hi: int = maxi(1, int(floorf(avg * 1.5)))
	var req: OpponentRequest = _mercs_request(4, avg, 3.0)
	req.resolved_ctx = OpponentGenerator.context(req)
	var low: int = 9999
	var high: int = 0
	for _i: int in range(200):
		var lvl: int = OpponentGenerator.roll_level(req)
		low = mini(low, lvl)
		high = maxi(high, lvl)
	TestFixtures.check(res, "200 Mercs level rolls stay inside the difficulty 3 band", low >= lo and high <= hi,
		"%d to %d against a band of %d to %d" % [low, high, lo, hi])
	var mercs: Array[MercenaryData] = OpponentGenerator.generate(req)
	var levels: Array[int] = _levels(mercs)
	var inside: bool = mercs.size() == 4
	for lvl: int in levels:
		if lvl < lo or lvl > hi:
			inside = false
	TestFixtures.check(res, "generated Mercs keep a level inside the difficulty 3 band", inside,
		"levels %s against a band of %d to %d" % [str(levels), lo, hi])


static func _case_traditions(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var req: OpponentRequest = _mercs_request(4, 6.0, 3.0)
	req.fixed_level = 3
	req.traditions.assign(["Brave", "Warrior"])
	var mercs: Array[MercenaryData] = OpponentGenerator.generate(req)
	var names: Array[String] = []
	for merc: MercenaryData in mercs:
		names.append(_trad_name(merc))
	var joined: String = ", ".join(names)
	TestFixtures.check(res, "traditions force each index and the last one repeats",
		joined == "Brave, Warrior, Warrior, Warrior", joined)
	var free: OpponentRequest = _mercs_request(3, 6.0, 3.0)
	free.fixed_level = 3
	var rolled: Array[MercenaryData] = OpponentGenerator.generate(free)
	var all_named: bool = rolled.size() == 3
	var rolled_names: Array[String] = []
	for merc: MercenaryData in rolled:
		if merc.tradition == null:
			all_named = false
		rolled_names.append(_trad_name(merc))
	TestFixtures.check(res, "an empty traditions list leaves the roll free",
		all_named and MercGenerator.forced_tradition == "", ", ".join(rolled_names))


static func _case_statics_restored(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var warm_a: MercenaryData = MercGenerator.generate(0)
	var warm_b: MercenaryData = MercGenerator.generate(1)
	MercGenerator.forced_level = 4
	MercGenerator.forced_tradition = "Mage"
	MercGenerator.tradition_odds = {"Mage": 10.0}
	var before: String = _statics_snapshot()
	var req: OpponentRequest = _mercs_request(2, 6.0, 3.0)
	req.fixed_level = 3
	req.traditions.assign(["Brave"])
	req.tradition_odds = {"Performer": 50.0}
	req.independent_traditions = true
	var mercs: Array[MercenaryData] = OpponentGenerator.generate(req)
	var after: String = _statics_snapshot()
	TestFixtures.check(res, "generate leaves the eight MercGenerator statics as it found them",
		warm_a != null and warm_b != null and mercs.size() == 2 and before == after,
		"snapshots match" if before == after else "before %s | after %s" % [before, after])
	_reset_statics()


static func _case_weighted_multiplier(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var items: Array[Dictionary] = [
		{"name": "A", "rarity": "Common"},
		{"name": "B", "rarity": "Common"},
		{"name": "C", "rarity": "Common"},
	]
	var boost: Dictionary = {"B": 100.0}
	var table: Array[Dictionary] = WeightedTable._build_table(items, {}, boost, {})
	var total: float = 0.0
	var b_pct: float = 0.0
	for entry: Dictionary in table:
		total += float(entry.get("pct", 0.0))
		if str(entry.get("name", "")) == "B":
			b_pct = float(entry.get("pct", 0.0))
	TestFixtures.check(res, "a percent multiplier leaves the table summing to 100", is_equal_approx(total, 100.0),
		"total %.4f, B %.2f%%" % [total, b_pct])
	var hits: int = 0
	for _i: int in range(2000):
		if WeightedTable.roll(items, {}, boost) == "B":
			hits += 1
	TestFixtures.check(res, "a +100% multiplier lifts its item well above a third", hits > 1000,
		"B won %d of 2000 rolls, table share %.2f%%" % [hits, b_pct])


static func _case_tradition_odds(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var req: OpponentRequest = _mercs_request(100, 6.0, 3.0)
	req.fixed_level = 1
	#Flat tradition boosts can leave a sibling a working share in the hundreds, so the multiplier has to dwarf it.
	req.tradition_odds = {"Performer": 1.0e9}
	req.independent_traditions = true
	var mercs: Array[MercenaryData] = OpponentGenerator.generate(req)
	var performers: int = 0
	for merc: MercenaryData in mercs:
		if _trad_name(merc) == "Performer":
			performers += 1
	#Performer is unavailable to some ancestries, so a few rolls land elsewhere whatever the multiplier.
	TestFixtures.check(res, "a huge Performer multiplier wins at least 90 of 100 independent rolls",
		mercs.size() == 100 and performers >= 90, "%d of %d are Performer" % [performers, mercs.size()])
	TestFixtures.check(res, "tradition_odds is empty again after generate", MercGenerator.tradition_odds.is_empty(),
		"odds %s" % str(MercGenerator.tradition_odds))


static func _case_skew(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var req: OpponentRequest = _mercs_request(3, 6.0, 3.0)
	req.fixed_level = 6
	var mercs: Array[MercenaryData] = OpponentGenerator.generate(req)
	if mercs.size() != 3:
		TestFixtures.check(res, "skew fixtures", false, "generated %d of 3 opponents" % mercs.size())
		return
	var pool_merc: MercenaryData = mercs[2]
	var ep_max: int = int(pool_merc.stats.get("maximum_endurance_points", 0))
	var ep_gap: int = pool_merc.current_ep - ep_max
	var hp_gap: int = pool_merc.current_hp - int(pool_merc.stats.get("maximum_hit_points", 0))
	var amounts: Array[int] = [1, 2, 4]
	for k: int in range(amounts.size()):
		var merc: MercenaryData = mercs[k]
		var n: int = amounts[k]
		var skew: Dictionary = {}
		var before: Dictionary = {}
		for stat: String in CORE:
			skew[stat] = n
			before[stat] = int(merc.stats.get(stat, 0))
		OpponentGenerator._apply_skew(merc, skew, TAG)
		var ok: bool = true
		var detail: Array[String] = []
		for stat: String in CORE:
			var rise: int = int(merc.stats.get(stat, 0)) - int(before[stat])
			if rise != n:
				ok = false
			detail.append("%s %d" % [stat, rise])
		TestFixtures.check(res, "a skew of %d lifts each core stat by exactly %d" % [n, n], ok,
			"%s: %s" % [merc.merc_name, ", ".join(detail)])
	var ep_max_after: int = int(pool_merc.stats.get("maximum_endurance_points", 0))
	var ep_gap_after: int = pool_merc.current_ep - ep_max_after
	var hp_gap_after: int = pool_merc.current_hp - int(pool_merc.stats.get("maximum_hit_points", 0))
	TestFixtures.check(res, "a skew raises the current pools with their maxima",
		ep_max_after > ep_max and ep_gap_after == ep_gap and hp_gap_after == hp_gap,
		"max EP %d to %d, EP gap %d to %d, HP gap %d to %d" % [ep_max, ep_max_after, ep_gap, ep_gap_after,
		hp_gap, hp_gap_after])
	var capped: MercenaryData = mercs[0]
	var max_wile: int = int(capped.max_stats.get("max_wile", 0))
	capped.stat_bonuses["wile"] = float(max_wile) + 10.0
	StatCalculator.refresh(capped)
	var at_max: int = int(capped.stats.get("wile", 0))
	OpponentGenerator._apply_skew(capped, {"wile": 2}, TAG)
	var cap_rise: int = int(capped.stats.get("wile", 0)) - at_max
	TestFixtures.check(res, "a stat already at its max still rises by the skew", cap_rise == 2,
		"wile %d at max_wile %d rose %d" % [at_max, max_wile, cap_rise])
	var scaled: MercenaryData = mercs[1]
	scaled.stat_multipliers["cognition"] = 0.5
	scaled.max_stats["max_cognition"] = 100
	StatCalculator.refresh(scaled)
	var scaled_before: int = int(scaled.stats.get("cognition", 0))
	OpponentGenerator._apply_skew(scaled, {"cognition": 4}, TAG)
	var scaled_rise: int = int(scaled.stats.get("cognition", 0)) - scaled_before
	TestFixtures.check(res, "a +50% multiplier on the stat still takes the skew exactly", scaled_rise == 4,
		"cognition %d rose %d, bonus now %.2f" % [scaled_before, scaled_rise,
		float(scaled.stat_bonuses.get("cognition", 0.0))])
	#Core stats settle before the name and gear rolls, so one opponent per request repeats under one seed.
	seed(4242)
	var plain: OpponentRequest = _mercs_request(1, 6.0, 3.0)
	plain.fixed_level = 6
	var base: Array[MercenaryData] = OpponentGenerator.generate(plain)
	seed(4242)
	var skewed: OpponentRequest = _mercs_request(1, 6.0, 3.0)
	skewed.fixed_level = 6
	skewed.stat_skew = {"vigor": 2, "wile": 1}
	var lifted: Array[MercenaryData] = OpponentGenerator.generate(skewed)
	var dv: int = -99
	var dw: int = -99
	if base.size() == 1 and lifted.size() == 1:
		dv = int(lifted[0].stats.get("vigor", 0)) - int(base[0].stats.get("vigor", 0))
		dw = int(lifted[0].stats.get("wile", 0)) - int(base[0].stats.get("wile", 0))
	TestFixtures.check(res, "generate applies the request skew", dv == 2 and dw == 1,
		"vigor %d, wile %d over the unskewed twin" % [dv, dw])


static func _case_hooks(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var req := OpponentRequest.new()
	req.source = BANDIT
	req.count = 3
	req.party = _party(4, 6.0)
	req.difficulty = 3.0
	req.fixed_level = 4
	req.tag = TAG
	var calls: Array = []
	var hook := func(merc: MercenaryData, index: int, r: OpponentRequest) -> void: calls.append([merc, index, r])
	req.hooks.append(hook)
	var out: Array[MercenaryData] = OpponentGenerator.generate(req)
	var ok: bool = out.size() == 3 and calls.size() == out.size()
	var order: Array[int] = []
	for i: int in range(mini(calls.size(), out.size())):
		var entry: Array = calls[i]
		order.append(int(entry[1]))
		if entry[0] != out[i] or int(entry[1]) != i or entry[2] != req:
			ok = false
	TestFixtures.check(res, "hooks run once per opponent in index order with the request", ok,
		"%d calls for %d opponents, indexes %s" % [calls.size(), out.size(), str(order)])


static func _case_outputs(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var req := OpponentRequest.new()
	req.source = BANDIT
	req.count_formula = "party.merc_count - 1"
	req.party = _party(4, 6.0)
	req.difficulty = 5.0
	req.extra_ctx = {"bad_luck_roll": 2, "marker": "x"}
	req.tag = TAG
	var out: Array[MercenaryData] = OpponentGenerator.generate(req)
	var ctx: Dictionary = req.resolved_ctx
	TestFixtures.check(res, "resolved_ctx carries difficulty_factor and the extra keys",
		is_equal_approx(float(ctx.get("difficulty_factor", 0.0)), 2.0) and int(ctx.get("bad_luck_roll", 0)) == 2
		and str(ctx.get("marker", "")) == "x" and int(ctx.get("merc_count", 0)) == 4, str(ctx))
	TestFixtures.check(res, "resolved_count matches the list", req.resolved_count == 3 and out.size() == 3,
		"resolved %d, list %d" % [req.resolved_count, out.size()])
	var levels: Array[int] = _levels(out)
	TestFixtures.check(res, "rolled_levels matches the final levels", levels == req.rolled_levels,
		"list %s, rolled %s" % [str(levels), str(req.rolled_levels)])


static func _case_npc_fixed_level(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var req := OpponentRequest.new()
	req.source = BANDIT
	req.count = 3
	req.party = _party(4, 6.0)
	req.fixed_level = 7
	req.tag = TAG
	var levels: Array[int] = _levels(OpponentGenerator.generate(req))
	var ok: bool = levels.size() == 3
	for lvl: int in levels:
		if lvl != 7:
			ok = false
	TestFixtures.check(res, "a fixed level of 7 holds for every template opponent", ok, "levels %s" % str(levels))


static func _case_crew(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var ambush: EventData = ContractLibrary.event(AMBUSH)
	if ambush == null:
		TestFixtures.check(res, "crew leader", false, "Ambush event did not load")
		return
	var req := OpponentRequest.new()
	req.source = ambush.enemy
	req.count = 5
	req.party = _party(4, 6.0)
	req.difficulty = 3.0
	req.tag = AMBUSH
	var crew: Array[MercenaryData] = OpponentGenerator.generate(req)
	var prefix: String = ambush.enemy.split(",")[0].strip_edges() + " "
	var ok: bool = crew.size() == 5 and crew[0].merc_name.begins_with(prefix)
	var mean: float = 0.0
	var lead: int = -1
	if crew.size() > 1:
		for i: int in range(1, crew.size()):
			mean += float(crew[i].stats.get("level", 0.0))
		mean /= float(crew.size() - 1)
		lead = int(crew[0].stats.get("level", 0))
		if float(lead) < ceilf(mean * 1.1):
			ok = false
	TestFixtures.check(res, "the first crew member leads and outranks the rest by a tenth", ok,
		"%d members, first %s at L%d against a mean of %.2f" % [crew.size(),
		crew[0].merc_name if not crew.is_empty() else "none", lead, mean])


static func _case_level_wrapper(res: Dictionary) -> void:
	_reset_statics()
	var ctx: Dictionary = {"average_level": 6.5, "merc_count": 4}
	var wrapped: int = NPCGenerator._eval_level_formula("party.average_level * 2", ctx)
	var direct: int = OpponentGenerator.eval_level("party.average_level * 2", ctx)
	TestFixtures.check(res, "_eval_level_formula wraps eval_level", wrapped == direct and direct == 13,
		"wrapper %d, direct %d" % [wrapped, direct])


static func _case_enemy_team(res: Dictionary) -> void:
	_reset_statics()
	seed(12345)
	var skirmish: EventData = ContractLibrary.event(SKIRMISH)
	if skirmish == null:
		TestFixtures.check(res, "EnemyTeamBuilder Mercs event", false, "%s did not load" % SKIRMISH)
		return
	var contract_run := ContractRun.new()
	contract_run.contract = ContractLibrary.contract_type("Military")
	contract_run.team = _party(3, 5.0)
	var mercs: Array[MercenaryData] = EnemyTeamBuilder.build(skirmish, contract_run, 0)
	var names: Array[String] = []
	for merc: MercenaryData in mercs:
		names.append(_trad_name(merc))
	var joined: String = ", ".join(names)
	TestFixtures.check(res, "EnemyTeamBuilder gives a Mercs event Brave then Warrior",
		joined == "Brave, Warrior, Warrior, Warrior, Warrior", joined)
	TestFixtures.check(res, "EnemyTeamBuilder leaves the MercGenerator statics clear",
		MercGenerator.forced_level == -1 and MercGenerator.forced_tradition == ""
		and MercGenerator.tradition_odds.is_empty(),
		"forced_level %d forced_tradition '%s' odds %s"
		% [MercGenerator.forced_level, MercGenerator.forced_tradition, str(MercGenerator.tradition_odds)])
