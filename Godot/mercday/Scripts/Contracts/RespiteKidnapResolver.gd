class_name RespiteKidnapResolver

#The Respite kidnapping: a crew picks the easiest target, two of them grab it, and a Notice or a
#Break Free win turns the ambush into a battle instead; with no mark at all the crew just leaves.

const EVENT_NAME := "Kidnapping"


static func resolve(event: EventData, run: ContractRun, opts: Dictionary = {}) -> Dictionary:
	var out: Dictionary = EventRunner.outcome(event)
	if event == null or run == null:
		return out
	if run.living_team().is_empty():
		var no_team: Array[String] = ["no living mercs"]
		out["notes"] = no_team
		run.emit("EVENT SKIPPED: %s (no living mercs)" % event.event_name)
		return out
	var crew_list: Array[MercenaryData] = crew(event, run)
	if crew_list.is_empty():
		var no_crew: Array[String] = ["no enemies"]
		out["notes"] = no_crew
		run.emit("EVENT FAILED: %s (no enemies generated)" % event.event_name)
		return out
	var target: MercenaryData = _pick_target(target_pool(run), crew_list)
	var pair: Array[MercenaryData] = best_pair(target, crew_list)
	run.emit("RESPITE KIDNAP: %d bandits, %s targeted" % [crew_list.size(),
		target.merc_name if target != null else "nobody"])
	if target == null or pair.is_empty():
		return crew_leaves(run, out, crew_list.size())
	var lines: Array[String] = []
	var spotter: MercenaryData = notice_interrupt(run, pair, lines)
	for line: String in lines:
		run.emit(line)
	if spotter != null:
		return await to_battle(event, run, crew_list, pair, target, "notice", opts)
	var roll_lines: Array[String] = []
	var broke: bool = break_free_roll(target, pair, roll_lines)
	for line: String in roll_lines:
		run.emit(line)
	if broke:
		return await to_battle(event, run, crew_list, pair, target, "break_free", opts)
	var pair_names: String = " and ".join(run.merc_names(pair))
	run.emit("RESPITE KIDNAP: %s taken by %s" % [target.merc_name, pair_names])
	for line: String in KidnapSystem.take_captive(run, target, pair_names, crew_list, event.enemy):
		run.emit(line)
	var taken: Array[String] = [target.merc_name]
	out["kidnapped"] = taken
	out["success"] = false
	return out


#Nobody can be taken: the crew slips away and the rest goes on; the row still counts as fired.
static func crew_leaves(run: ContractRun, out: Dictionary, crew_size: int) -> Dictionary:
	if run == null:
		return out
	run.emit("RESPITE KIDNAP: no mark among %d resting mercs, %d bandits leave" % [
		run.living_team().size(), crew_size])
	var notes: Array[String] = ["kidnap no target"]
	out["notes"] = notes
	return out


#The whole crew the row's Enemy and Enemy Counter cells build; only the pair acts before a battle.
static func crew(event: EventData, run: ContractRun) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if event == null or run == null:
		return out
	out.assign(EnemyTeamBuilder.build(event, run, 0))
	return out


#Resting mercs a fresh crew would try for: Surprised immunity is the only bar.
static func target_pool(run: ContractRun) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if run == null:
		return out
	for merc: MercenaryData in run.living_team():
		if ConstStates.is_immune(merc, ConstStates.SURPRISED):
			continue
		out.append(merc)
	return out


static func best_pair(target: MercenaryData, crew_list: Array[MercenaryData]) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if target == null:
		return out
	var config: ContractConfig = ContractLibrary.config()
	var want: int = config.kidnap_pair_size if config != null else 2
	var left: Array[MercenaryData] = []
	left.assign(crew_list)
	while out.size() < want and not left.is_empty():
		var best: MercenaryData = null
		var best_score: float = -1.0
		for member: MercenaryData in left:
			if member == null:
				continue
			var score: float = KidnapSystem.grapple_estimate(member, target, null)
			if best == null or score > best_score:
				best = member
				best_score = score
		if best == null:
			break
		out.append(best)
		left.erase(best)
	return out


#Ordering proxy only: the target's mean Break Free successes less both kidnappers' mean holds.
static func break_free_odds(target: MercenaryData, pair: Array[MercenaryData]) -> float:
	if target == null:
		return 0.0
	var odds: float = CheckSystem.expected_successes(target,
		SpecialActionSystem.break_free_def())
	for member: MercenaryData in pair:
		if member == null:
			continue
		odds -= CheckSystem.expected_successes(member,
			SpecialActionSystem.break_free_def())
	return odds


#Every merc immune to Surprised watches; the kidnapper that rolls worst is the one it beats.
static func notice_interrupt(run: ContractRun, pair: Array[MercenaryData], lines: Array[String]) -> MercenaryData:
	if run == null or pair.is_empty():
		return null
	for merc: MercenaryData in run.living_team():
		if not ConstStates.is_immune(merc, ConstStates.SURPRISED):
			continue
		var watch: Dictionary = CheckSystem.make_check(merc, _notice_def())
		var worst: Dictionary = {}
		var worst_name: String = ""
		for member: MercenaryData in pair:
			if member == null:
				continue
			var guard: Dictionary = CheckSystem.make_check(member, _grace_def())
			if worst.is_empty() or int(guard["successes"]) < int(worst["successes"]):
				worst = guard
				worst_name = member.merc_name
		if worst.is_empty():
			continue
		var spots: bool = CheckSystem.result_wins(watch, worst)
		lines.append("KIDNAP NOTICE: %s %d successes vs %s %d -> %s" % [merc.merc_name,
			int(watch["successes"]), worst_name, int(worst["successes"]),
			"spots them" if spots else "misses them"])
		if spots:
			return merc
	return null


#One roll against the summed Athletics or Power hold of both kidnappers; a target that cannot be held wins with no dice.
static func break_free_roll(target: MercenaryData, pair: Array[MercenaryData], lines: Array[String]) -> bool:
	if target == null:
		return true
	if ConstStates.is_immune(target, ConstStates.GRAPPLED):
		lines.append("KIDNAP BREAK FREE: %s cannot be held (immune to Grappled) -> breaks free"
			% target.merc_name)
		return true
	var check_def: Dictionary = SpecialActionSystem.break_free_def()
	var result: Dictionary = CheckSystem.make_check(target, check_def)
	var combined: int = 0
	var held_crit: bool = false
	for member: MercenaryData in pair:
		if member == null:
			continue
		var hold: Dictionary = CheckSystem.make_check(member,
			SpecialActionSystem.break_free_def())
		combined += int(hold["successes"])
		if bool(hold.get("critical", false)):
			held_crit = true
	var free: bool = CheckSystem.result_wins(result, {"successes": combined, "critical": held_crit})
	lines.append("KIDNAP BREAK FREE: %s %d successes vs %d combined -> %s" % [target.merc_name,
		int(result["successes"]), combined, "breaks free" if free else "is taken"])
	return free


#The full party against the full crew, the pair beside its mark and everyone else caught out.
static func to_battle(event: EventData, run: ContractRun, crew_list: Array[MercenaryData],
		pair: Array[MercenaryData], target: MercenaryData, reason: String,
		base_opts: Dictionary = {}) -> Dictionary:
	var surprised: Array[MercenaryData] = []
	for merc: MercenaryData in run.living_team():
		if not ConstStates.is_immune(merc, ConstStates.SURPRISED):
			surprised.append(merc)
	var adjacent: Dictionary = {}
	if target != null:
		for member: MercenaryData in pair:
			if member != null:
				adjacent[member] = target
	var battle_opts: Dictionary = base_opts.duplicate()
	battle_opts["enemies"] = crew_list
	battle_opts["surprised"] = surprised
	battle_opts["adjacent"] = adjacent
	var out: Dictionary = await BattleEventResolver.resolve(event, run, battle_opts)
	var notes: Array[String] = ["kidnap %s" % reason]
	notes.append_array(out.get("notes", []))
	out["notes"] = notes
	return out


#The pool member the pair holds most easily; null when nobody may be taken.
static func _pick_target(pool: Array[MercenaryData], crew_list: Array[MercenaryData]) -> MercenaryData:
	var best: MercenaryData = null
	var best_odds: float = 0.0
	for merc: MercenaryData in pool:
		if merc == null:
			continue
		var odds: float = break_free_odds(merc, best_pair(merc, crew_list))
		if best == null or odds < best_odds:
			best = merc
			best_odds = odds
	return best


static func _notice_def() -> Dictionary:
	return {
		"stat_keys": ["cognition"],
		"circumstances": [ConstCircumstances.NOTICE_COGNITION],
		"knowledges": [],
		"tools": [],
		"formula": "luck",
		"flat_threshold_bonus": 0.0,
	}


static func _grace_def() -> Dictionary:
	return {
		"stat_keys": ["dexterity"],
		"circumstances": [ConstCircumstances.GRACE_DEXTERITY],
		"knowledges": [],
		"tools": [],
		"formula": "luck",
		"flat_threshold_bonus": 0.0,
	}
