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
	var target_floor := state.get_floor(target)
	var dir := _shove_dir(merc, target, state)

	var field: BattlefieldArea = state.battlefield
	var walk_limit := shover_size + 2
	var dest := target_pos
	var blocked_at := walk_limit
	for i: int in walk_limit:
		var next := field.clamp_position(dest + dir)
		if next == dest:
			blocked_at = i
			break
		var obs := field.get_obs(next, target_floor)
		if not obs.is_empty():
			var d: ObstacleData = obs.get("data") as ObstacleData
			if d == null or not d.passthrough:
				blocked_at = i
				break
		dest = next

	var value := terrain_drop_score(field, target_pos, dest)

	#Slam damage bonus when an obstacle blocks before shover_size paces.
	if blocked_at < shover_size:
		value += 0.2

	var allies: Array = ctx.get("allies", [])
	var dest3 := Vector3i(dest.x, dest.y, target_floor)
	value += cover_break_score(state, target, allies, dest3, shoved_size)
	value += flank_bonus(state, allies, dest)

	#Shoving breaks flanking pressure on an ally.
	for ally: MercenaryData in allies:
		if ConstStates.has_state(ally, ConstStates.FLANKED):
			if state.distance_to(target, ally) <= 1:
				value += 0.3
				break

	value += deposed_setup_score(merc, target, state, allies, dest, shover_size, shoved_size)

	return minf(value, 1.0)


#Push direction from the shover to the target; east when they share a cell.
static func _shove_dir(merc: MercenaryData, target: MercenaryData, state: BattleState) -> Vector2i:
	var target_pos := state.get_position(target)
	var shover_pos := state.get_position(merc)
	var dir := Vector2i(signi(target_pos.x - shover_pos.x), signi(target_pos.y - shover_pos.y))
	return Vector2i(1, 0) if dir == Vector2i.ZERO else dir


#Scores a single-pace shove of the target: terrain drop, cover break, flanking, Deposed setup.
static func single_pace_score(merc: MercenaryData, target: MercenaryData, state: BattleState, allies: Array) -> float:
	if target == null or state == null or state.battlefield == null:
		return 0.0
	var field: BattlefieldArea = state.battlefield
	var target_pos := state.get_position(target)
	var dest := field.clamp_position(target_pos + _shove_dir(merc, target, state))
	var target_floor := state.get_floor(target)
	if dest == target_pos:
		return 0.0
	var obs := field.get_obs(dest, target_floor)
	if not obs.is_empty():
		var od: ObstacleData = obs.get("data") as ObstacleData
		if od == null or not od.passthrough:
			return 0.0
	if state.is_position_occupied(dest, target, target_floor):
		return 0.0
	var dest3 := Vector3i(dest.x, dest.y, target_floor)
	var value := terrain_drop_score(field, target_pos, dest)
	value += cover_break_score(state, target, allies, dest3, int(target.stats.get("size", 1)))
	value += flank_bonus(state, allies, dest)
	value += deposed_setup_score(merc, target, state, allies, dest, int(merc.stats.get("size", 1)),
			int(target.stats.get("size", 1)))
	return clampf(value, 0.0, 1.0)


#Height the shove drops the target: 0.4 for two paces or more, 0.2 for one.
static func terrain_drop_score(field: BattlefieldArea, from_pos: Vector2i, dest: Vector2i) -> float:
	var terrain_drop := field.surface_height(from_pos) - field.surface_height(dest)
	if terrain_drop >= 2.0:
		return 0.4
	elif terrain_drop >= 1.0:
		return 0.2
	return 0.0


#Cover the destination takes away, counted only for the first covering ally.
static func cover_break_score(state: BattleState, target: MercenaryData, allies: Array,
		dest3: Vector3i, shoved_size: int) -> float:
	for ally: MercenaryData in allies:
		if not (state.is_covered_from(target, ally, ConstStates.COVERED_FULL) \
				or state.is_covered_from(target, ally, ConstStates.COVERED_PARTIAL)):
			continue
		if str(LineOfSight.check_cell(state, ally, dest3, shoved_size)["cover"]) == "none":
			return 0.2
		break
	return 0.0


#Melee allies within 2 of the destination, 0.1 each and capped at 0.2.
static func flank_bonus(state: BattleState, allies: Array, dest: Vector2i) -> float:
	var bonus := 0.0
	for ally: MercenaryData in allies:
		var ally_pos := state.get_position(ally)
		if Pathfinder.chebyshev2(ally_pos, dest) <= 2:
			var w: WeaponData = ally.equipped_weapon
			if w == null or not w.is_ranged:
				bonus = minf(bonus + 0.1, 0.2)
	return bonus


#Shove likely lands Deposed and a melee ally stands within 3 of the destination.
static func deposed_setup_score(merc: MercenaryData, target: MercenaryData, state: BattleState,
		allies: Array, dest: Vector2i, shover_size: int, shoved_size: int) -> float:
	if shover_size < shoved_size or BattleState.knows(merc, target, "immune:deposed"):
		return 0.0
	for ally: MercenaryData in allies:
		var ally_pos := state.get_position(ally)
		if Pathfinder.chebyshev2(ally_pos, dest) <= 3:
			var w: WeaponData = ally.equipped_weapon
			if w == null or not w.is_ranged:
				return 0.15
	return 0.0
