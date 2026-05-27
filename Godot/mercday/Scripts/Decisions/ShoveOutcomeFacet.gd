class_name ShoveOutcomeFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var target: MercenaryData = ctx.get("current_target")
	if target == null:
		return 0.0
	var state: BattleState = ctx.get("state")
	if state == null or state.battlefield == null:
		return 0.0

	var shover_size := int(merc.stats.get("size", 1))
	var shoved_size := int(target.stats.get("size", 1))
	var target_pos := state.get_position(target)
	var shover_pos := state.get_position(merc)
	var dx := target_pos.x - shover_pos.x
	var dy := target_pos.y - shover_pos.y
	var dir := Vector2i(signi(dx), signi(dy))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)

	var field: BattlefieldArea = state.battlefield
	var walk_limit := shover_size + 2
	var dest := target_pos
	var blocked_at := walk_limit
	for i: int in walk_limit:
		var next := field.clamp_position(dest + dir)
		if next == dest:
			blocked_at = i
			break
		var obs := field.get_obstacle_at(next)
		if not obs.is_empty():
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or not d.passthrough:
				blocked_at = i
				break
		dest = next

	var score := 0.0

	# Terrain drop bonus
	var terrain_drop := field.get_terrain_height(target_pos) - field.get_terrain_height(dest)
	if terrain_drop >= 2.0:
		score += 0.4
	elif terrain_drop >= 1.0:
		score += 0.2

	# Slam damage bonus — obstacle blocks before shover_size paces
	if blocked_at < shover_size:
		score += 0.2

	# Cover removal bonus — target has cover from an ally that dest would break
	var cover_info := state.get_cover_info(target)
	if not cover_info.is_empty():
		var has_ally_cover := false
		for ally: MercenaryData in ctx.get("allies", []):
			if state.is_covered_from(target, ally, ConstStates.COVERED_FULL) or \
					state.is_covered_from(target, ally, ConstStates.COVERED_PARTIAL):
				has_ally_cover = true
				break
		if has_ally_cover:
			var obs_x := int(cover_info.get("obstacle_pos_x", -1))
			var obs_y := int(cover_info.get("obstacle_pos_y", -1))
			if obs_x >= 0 and obs_y >= 0:
				var obs_pos := Vector2i(obs_x, obs_y)
				if maxi(abs(dest.x - obs_pos.x), abs(dest.y - obs_pos.y)) > 1:
					score += 0.2

	# Ally flanking opportunity — melee allies within 2 of destination
	var flank_bonus := 0.0
	for ally: MercenaryData in ctx.get("allies", []):
		var ally_pos := state.get_position(ally)
		if maxi(abs(ally_pos.x - dest.x), abs(ally_pos.y - dest.y)) <= 2:
			var w: WeaponData = ally.equipped_weapon
			if w == null or not w.is_ranged:
				flank_bonus = minf(flank_bonus + 0.1, 0.2)

	score += flank_bonus

	# Enemy flanking ally bonus — shoving breaks flanking pressure on an ally
	for ally: MercenaryData in ctx.get("allies", []):
		if ConstStates.has_state(ally, ConstStates.FLANKED):
			if state.distance_to(target, ally) <= 1:
				score += 0.3
				break

	# Deposed setup bonus — shove likely causes Deposed and a melee ally is nearby
	if shover_size >= shoved_size:
		for ally: MercenaryData in ctx.get("allies", []):
			var ally_pos := state.get_position(ally)
			if maxi(abs(ally_pos.x - dest.x), abs(ally_pos.y - dest.y)) <= 3:
				var w: WeaponData = ally.equipped_weapon
				if w == null or not w.is_ranged:
					score += 0.15
					break

	return minf(score, 1.0)
