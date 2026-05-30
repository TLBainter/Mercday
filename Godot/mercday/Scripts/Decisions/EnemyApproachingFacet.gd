class_name EnemyApproachingFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	# Gate: veto Move Far unless an enemy is actively closing within ~2 turns,
	# or the merc is already Threatened (enemy in melee threat range).
	if ConstStates.has_state(merc, ConstStates.THREATENED):
		return 1.0
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0
	var enemies: Array = ctx.get("enemies", [])
	if enemies.is_empty():
		return 0.0
	var merc_pos := state.get_position(merc)
	for enemy: MercenaryData in enemies:
		var enemy_pace: int = maxi(1, int(enemy.stats.get("pace", 1)))
		var cur_dist := state.distance_to(merc, enemy)
		# Only care about enemies that could reach this merc in at most 2 turns
		if cur_dist > enemy_pace * 2:
			continue
		var hist: Array = state.position_history.get(enemy, []) as Array
		if hist.is_empty():
			# No prior position recorded (first round): proximity alone permits retreat
			return 1.0
		var prev_pos: Vector2i = hist[-1] as Vector2i
		var prev_dist := maxi(absi(prev_pos.x - merc_pos.x), absi(prev_pos.y - merc_pos.y))
		# Permit retreat when enemy closed 1 pace for every 3 paces of their speed
		if (prev_dist - cur_dist) * 3 >= enemy_pace:
			return 1.0
	return 0.0
