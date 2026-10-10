class_name OpponentGenerator

#Builds opponents from an OpponentRequest: Mercs, one NPCs.tsv template, or a comma crew cell.

const LEVEL_CAP: int = 40
const LEVEL_BAND_TOKEN: String = "level_band"
#Difficulty row to [low, peak, high] multipliers on the party average level; half steps interpolate.
const LEVEL_BANDS: Dictionary = {
	1: [0.5, 0.75, 1.25],
	2: [0.5, 1.0, 1.5],
	3: [0.5, 1.25, 1.5],
	4: [0.5, 1.25, 2.0],
	5: [1.0, 1.5, 2.0],
}


#Scale on enemy counts; a contract with no rolled difficulty reads as 1.0.
static func difficulty_factor(difficulty: float) -> float:
	if difficulty <= 0.0:
		return 1.0
	return 0.5 + (difficulty - 1.0) * 0.375


#An unrolled difficulty reads as the row for 2; anything else clamps to 1..5 and lerps between its two rows.
static func level_band_bounds(difficulty: float) -> Array[float]:
	var d: float = 2.0 if difficulty <= 0.0 else clampf(difficulty, 1.0, 5.0)
	var lo: int = int(floorf(d))
	var hi: int = int(ceilf(d))
	var t: float = d - float(lo)
	var row_lo: Array = LEVEL_BANDS[lo]
	var row_hi: Array = LEVEL_BANDS[hi]
	var out: Array[float] = []
	for i: int in range(3):
		out.append(lerpf(float(row_lo[i]), float(row_hi[i]), t))
	return out


#One triangular draw between low and high, skewed towards mode; a flat range spends no roll.
static func triangular(low: float, mode: float, high: float) -> float:
	if high <= low:
		return low
	var f: float = (mode - low) / (high - low)
	var u: float = randf()
	if u < f:
		return low + sqrt(u * (high - low) * (mode - low))
	return high - sqrt((1.0 - u) * (high - low) * (high - mode))


#One triangular draw: the ends are the low and high multipliers, the peak is the skew point.
static func level_band(difficulty: float) -> float:
	var bounds: Array[float] = level_band_bounds(difficulty)
	return triangular(bounds[0], bounds[1], bounds[2])


#A pinned context value covers every token; otherwise each token gets its own draw.
static func _apply_level_band(formula: String, ctx: Dictionary, difficulty: float) -> String:
	if not formula.contains(LEVEL_BAND_TOKEN):
		return formula
	if ctx.has(LEVEL_BAND_TOKEN):
		return formula.replace(LEVEL_BAND_TOKEN, "%.6f" % float(ctx[LEVEL_BAND_TOKEN]))
	var out: String = formula
	var at: int = out.find(LEVEL_BAND_TOKEN)
	while at >= 0:
		var text: String = "%.6f" % level_band(difficulty)
		out = out.substr(0, at) + text + out.substr(at + LEVEL_BAND_TOKEN.length())
		at = out.find(LEVEL_BAND_TOKEN, at + text.length())
	return out


static func context(req: OpponentRequest) -> Dictionary:
	var ctx: Dictionary = PartyStats.context(req.party)
	#A contract level replaces the party average, so the formulas scale to the contract, not the team.
	if req.contract_level >= 1:
		ctx["average_level"] = float(req.contract_level)
	ctx["difficulty"] = req.difficulty
	ctx["difficulty_factor"] = difficulty_factor(req.difficulty)
	for key: Variant in req.extra_ctx:
		ctx[key] = req.extra_ctx[key]
	return ctx


#Null for a blank formula or any parse or execute failure; pushes nothing, so each caller words its own error.
static func eval_formula(formula: String, ctx: Dictionary) -> Variant:
	if formula.strip_edges() == "":
		return null
	var difficulty: float = float(ctx.get("difficulty", 0.0))
	var factor: float = difficulty_factor(difficulty)
	if ctx.has("difficulty_factor"):
		factor = float(ctx["difficulty_factor"])
	var processed: String = _apply_level_band(formula, ctx, difficulty)
	processed = processed.replace("party.merc_count", str(int(ctx.get("merc_count", 0))))
	processed = processed.replace("party.average_level", "%.6f" % float(ctx.get("average_level", 0.0)))
	processed = processed.replace("bad_luck_roll", str(int(ctx.get("bad_luck_roll", 0))))
	processed = processed.replace("difficulty_factor", "%.6f" % factor)
	processed = processed.replace("contract.difficulty", "%.6f" % difficulty)
	processed = processed.replace("npc.level", "%.6f" % float(ctx.get("npc_level", 0.0)))
	var re := RegEx.new()
	re.compile("randf\\(([^,]+),\\s*([^)]+)\\)")
	var matches: Array = re.search_all(processed)
	#Walked in reverse so each splice leaves the earlier match offsets valid.
	for i: int in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i] as RegExMatch
		var lo: float = _eval_number(m.get_string(1), float(m.get_string(1)))
		var hi: float = _eval_number(m.get_string(2), float(m.get_string(2)))
		var start: int = m.get_start(0)
		var end: int = m.get_end(0)
		processed = processed.substr(0, start) + str(randf_range(lo, hi)) + processed.substr(end)
	var expr := Expression.new()
	if expr.parse(processed) != OK:
		return null
	var result: Variant = expr.execute([], null, false)
	if expr.has_execute_failed():
		return null
	return result


static func _eval_number(text: String, fallback: float) -> float:
	var expr := Expression.new()
	if expr.parse(text.strip_edges()) == OK:
		var result: Variant = expr.execute([])
		if not expr.has_execute_failed():
			return float(result)
	push_warning("OpponentGenerator: failed to evaluate number '%s'" % text)
	return fallback


static func eval_count(formula: String, ctx: Dictionary, tag: String = "") -> int:
	if formula.strip_edges() == "":
		return 1
	var result: Variant = eval_formula(formula, ctx)
	if result == null:
		push_error("OpponentGenerator: bad counter '%s'%s" % [formula, _tag_suffix(tag)])
		return 1
	return maxi(1, int(floorf(float(result))))


static func eval_level(formula: String, ctx: Dictionary) -> int:
	if formula.strip_edges() == "":
		return 0
	var result: Variant = eval_formula(formula, ctx)
	if result == null:
		push_error("OpponentGenerator: bad level formula '%s'" % formula)
		return 0
	return maxi(0, int(floorf(float(result))))


#A fixed level skips every formula and clamp; otherwise the request, template and config formulas, then the clamps.
static func roll_level(req: OpponentRequest, template_formula: String = "") -> int:
	if req.fixed_level >= 0:
		return req.fixed_level
	var formula: String = req.level_formula
	if formula.strip_edges() == "":
		formula = template_formula
	if formula.strip_edges() == "":
		var config: ContractConfig = ContractLibrary.config()
		formula = config.opponent_level_formula if config != null else ""
	var level: int = eval_level(formula, req.resolved_ctx)
	if req.level_min >= 0:
		level = maxi(level, req.level_min)
	if req.level_max >= 0:
		level = mini(level, req.level_max)
	level = mini(level, LEVEL_CAP)
	return level


static func generate(req: OpponentRequest) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if req == null:
		return out
	req.resolved_ctx = context(req)
	req.resolved_count = req.count
	if req.count < 0:
		req.resolved_count = eval_count(req.count_formula, req.resolved_ctx, req.tag)
	req.rolled_levels.clear()
	if req.resolved_count <= 0:
		return out
	if req.source == "Mercs":
		out.assign(_generate_mercs(req))
	elif req.source.contains(","):
		out.assign(_build_crew(req.source, req.resolved_count, req))
	else:
		var template: NPCTemplate = DataManager.npc_templates.get(req.source, null) as NPCTemplate
		if template == null:
			push_error("OpponentGenerator: unknown opponent source '%s'%s" % [req.source, _tag_suffix(req.tag)])
			return out
		for i: int in range(req.resolved_count):
			out.append(NPCGenerator.generate(template, req.resolved_ctx, roll_level(req, template.level_formula)))
	for i: int in range(out.size()):
		_apply_skew(out[i], req.stat_skew, req.tag)
		for hook: Callable in req.hooks:
			hook.call(out[i], i, req)
	for merc: MercenaryData in out:
		req.rolled_levels.append(int(merc.stats.get("level", 0)))
	return out


#The MercGenerator statics are saved at entry and restored at exit, so a request leaves no trace on later rolls.
static func _generate_mercs(req: OpponentRequest) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	var saved_rolls: Dictionary = RollingPenalties.snapshot()
	var saved_level: int = MercGenerator.forced_level
	var saved_tradition: String = MercGenerator.forced_tradition
	var saved_odds: Dictionary = MercGenerator.tradition_odds
	for i: int in range(req.resolved_count):
		if req.independent_traditions:
			RollingPenalties.tradition_batch_counts.clear()
			(RollingPenalties.rolling_penalties["tradition"] as Dictionary).clear()
			(RollingPenalties.rolling_penalty_age["tradition"] as Dictionary).clear()
		MercGenerator.forced_level = roll_level(req)
		MercGenerator.forced_tradition = ""
		if not req.traditions.is_empty():
			MercGenerator.forced_tradition = req.traditions[mini(i, req.traditions.size() - 1)]
		MercGenerator.tradition_odds = req.tradition_odds
		out.append(MercGenerator.generate(i))
	RollingPenalties.restore(saved_rolls)
	MercGenerator.forced_level = saved_level
	MercGenerator.forced_tradition = saved_tradition
	MercGenerator.tradition_odds = saved_odds
	return out


#A comma cell is a crew: the first term leads and spawns once, the rest fill the roster.
static func _build_crew(cell: String, count: int, req: OpponentRequest) -> Array[MercenaryData]:
	var crew: Array[MercenaryData] = []
	var terms: Array[String] = []
	for raw: String in cell.split(","):
		var term: String = raw.strip_edges()
		if term != "":
			terms.append(term)
	if terms.is_empty():
		return crew
	_add_crew_member(crew, terms[0], req)
	var rest: Array[String] = terms.slice(1)
	if rest.is_empty():
		rest = terms
	for i: int in range(1, count):
		_add_crew_member(crew, rest[randi() % rest.size()], req)
	_bump_leader(crew)
	return crew


#An unknown term leaves its slot empty.
static func _add_crew_member(crew: Array[MercenaryData], term: String, req: OpponentRequest) -> void:
	var template: NPCTemplate = DataManager.npc_templates.get(term, null) as NPCTemplate
	if template == null:
		push_error("OpponentGenerator: unknown crew term '%s'%s" % [term, _tag_suffix(req.tag)])
		return
	crew.append(NPCGenerator.generate(template, req.resolved_ctx, roll_level(req, template.level_formula)))


#The crew's first member outranks it: at least 110 percent of the mean level of the rest.
static func _bump_leader(crew: Array[MercenaryData]) -> void:
	if crew.size() < 2 or crew[0] == null:
		return
	var total: float = 0.0
	var counted: int = 0
	for i: int in range(1, crew.size()):
		if crew[i] == null:
			continue
		total += float(crew[i].stats.get("level", 0.0))
		counted += 1
	if counted == 0:
		return
	var leader: MercenaryData = crew[0]
	var wanted: int = mini(int(ceilf(total / float(counted) * 1.1)), LEVEL_CAP)
	if wanted <= int(leader.stats.get("level", 0.0)):
		return
	leader.stats["level"] = float(wanted)
	leader.xp = ExperienceSystem.xp_for_level(wanted)
	StatCalculator.refresh(leader)
	LevelUpSystem.catch_up(leader)


#Adds core points one at a time; a point that cannot lift its core by exactly one is reverted with a warning.
static func _apply_skew(merc: MercenaryData, skew: Dictionary, tag: String) -> void:
	if merc == null or skew.is_empty():
		return
	if merc.stats_baseline.is_empty():
		StatCalculator.prime(merc)
	var hp_max: int = int(merc.stats.get("maximum_hit_points", 0))
	var ep_max: int = int(merc.stats.get("maximum_endurance_points", 0))
	var mp_max: int = int(merc.stats.get("maximum_magic_points", 0))
	for key: Variant in skew:
		var stat: String = str(key).to_lower()
		if not StatCalculator.CORE_STATS.has(stat):
			push_warning("OpponentGenerator: skew key '%s' is not a core stat%s" % [str(key), _tag_suffix(tag)])
			continue
		for _point: int in range(int(skew[key])):
			if not _skew_point(merc, stat):
				push_warning("OpponentGenerator: could not raise %s of %s by one%s"
					% [stat, merc.merc_name, _tag_suffix(tag)])
	#Carried battles read the pools as they stand, so a raised maximum is added to the current value.
	merc.current_hp += int(merc.stats.get("maximum_hit_points", 0)) - hp_max
	merc.current_ep += int(merc.stats.get("maximum_endurance_points", 0)) - ep_max
	merc.current_mp += int(merc.stats.get("maximum_magic_points", 0)) - mp_max


#Tries a bonus point; a rise of 2 from a percent multiplier retries with a half then a quarter point,
#and no rise at the max retries with a cap two wider, then one wider for a bonus already past it.
static func _skew_point(merc: MercenaryData, stat: String) -> bool:
	var max_key: String = "max_" + stat
	var before: float = float(merc.stats.get(stat, 0))
	var overshot: bool = false
	for attempt: int in range(3):
		var bonus_was: Variant = merc.stat_bonuses.get(stat)
		var max_was: Variant = merc.max_stats.get(max_key)
		if attempt == 0 or overshot:
			merc.stat_bonuses[stat] = float(merc.stat_bonuses.get(stat, 0.0)) + pow(0.5, float(attempt))
		elif attempt == 1:
			merc.max_stats[max_key] = int(merc.max_stats.get(max_key, 0)) + 2
		else:
			merc.max_stats[max_key] = int(merc.max_stats.get(max_key, 0)) + 1
		StatCalculator.refresh(merc)
		var rise: float = float(merc.stats.get(stat, 0)) - before
		if is_equal_approx(rise, 1.0):
			return true
		if attempt == 0:
			overshot = rise > 1.0
		_restore_key(merc.stat_bonuses, stat, bonus_was)
		_restore_key(merc.max_stats, max_key, max_was)
		StatCalculator.refresh(merc)
	return false


static func _restore_key(dict: Dictionary, key: String, was: Variant) -> void:
	if was == null:
		dict.erase(key)
	else:
		dict[key] = was


static func _tag_suffix(tag: String) -> String:
	return " (%s)" % tag if tag != "" else ""
