class_name EnemyTeamBuilder

#Builds the opposing team for a battle event from the event's Enemy and Enemy Counter cells.


static func eval_count(expr: String, ctx: Dictionary) -> int:
	var processed: String = expr
	processed = processed.replace("party.merc_count", str(int(ctx.get("merc_count", 0))))
	processed = processed.replace("party.average_level", "%.4f" % float(ctx.get("average_level", 0.0)))
	processed = processed.replace("bad_luck_roll", str(int(ctx.get("bad_luck_roll", 0))))
	var result: Variant = ContractLibrary.eval_expression(processed,
		"EnemyTeamBuilder: bad counter '%s'" % expr)
	if result == null:
		return 1
	return maxi(1, int(floorf(float(result))))


static func build(event: EventData, run: ContractRun, bad_luck_extra: int) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	if event == null or run == null:
		return out
	var living: Array[MercenaryData] = run.living_team()
	var ctx: Dictionary = PartyStats.context(living)
	ctx["bad_luck_roll"] = bad_luck_extra
	var count: int = eval_count(event.enemy_counter, ctx)
	if event.enemy == "Mercs":
		var config: ContractConfig = ContractLibrary.config()
		var top: int = PartyStats.top_level(living)
		var hi: int = maxi(config.enemy_level_min, int(floorf(float(top) / float(maxi(1, config.enemy_level_divisor)))))
		var saved_counts: Dictionary = MercGenerator._tradition_batch_counts.duplicate(true)
		var saved_penalties: Dictionary = MercGenerator._rolling_penalties.duplicate(true)
		for i: int in range(count):
			MercGenerator.forced_level = randi_range(config.enemy_level_min, hi)
			MercGenerator.forced_tradition = config.enemy_odd_tradition if i == 0 else config.enemy_tradition
			out.append(MercGenerator.generate(i))
		MercGenerator.forced_level = -1
		MercGenerator.forced_tradition = ""
		MercGenerator._tradition_batch_counts = saved_counts
		MercGenerator._rolling_penalties = saved_penalties
		return out
	out.assign(NPCGenerator.generate_batch(event.enemy, count, PartyStats.context(living)))
	return out
