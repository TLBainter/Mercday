class_name TargetSelector


static func pick_target(
		attacker: MercenaryData,
		enemies: Array,
		state: BattleState = null) -> MercenaryData:
	if enemies.is_empty():
		return null
	var barred := ConstStates.blocked_targets(attacker)
	if not barred.is_empty():
		var allowed: Array = enemies.filter(func(e: MercenaryData) -> bool: return not barred.has(e))
		if allowed.size() != enemies.size():
			log_target_blocked(attacker, enemies, barred)
			if not allowed.is_empty():
				enemies = allowed
	var weapon := attacker.equipped_weapon
	var is_ranged := weapon != null and weapon.is_ranged
	var avoid_key := "avoid_ranged" if is_ranged else "avoid_melee"

	var most_damage_dealer: MercenaryData = null
	if is_ranged and state != null:
		var max_dmg := 0
		for enemy: MercenaryData in enemies:
			var dmg := int(state.damage_dealt_last_round.get(enemy, {}).get(attacker, 0))
			if dmg <= 0:
				continue
			var in_range := _enemy_in_intended_range(attacker, enemy, weapon, state)
			if in_range and dmg > max_dmg:
				max_dmg = dmg
				most_damage_dealer = enemy

	var allies := state.get_allies(attacker) if state != null else []

	var weights: Array[int] = []
	for enemy: MercenaryData in enemies:
		var avoid_val := float(enemy.stats.get(avoid_key, 0))
		if ConstStates.has_state(enemy, ConstStates.FLANKED):
			avoid_val = maxf(0.0, avoid_val - 15.0)
		var base := maxi(1, 100 - int(avoid_val))
		var mult := 1.0

		if state != null and state.battlefield != null and weapon != null:
			var dist := state.distance_to(attacker, enemy)
			if is_ranged:
				if weapon.ranged_intended_range <= 0 or dist <= weapon.ranged_intended_range:
					mult += 0.5
			else:
				if dist <= weapon.melee_range:
					mult += 0.5 + 1.0

		if is_ranged and state != null and state.last_attacked.get(attacker) == enemy:
			mult += 0.5

		if is_ranged and enemy == most_damage_dealer:
			mult += 0.25

		if ConstStates.has_state(enemy, ConstStates.FLANKED):
			mult += 0.5

		if state != null and _flank_ally_at_current_pos(attacker, enemy, allies, state) != null:
			mult += 0.25

		mult += AuraTactics.leader_bonus(enemy, state)
		mult += FleeSystem.escaping_bonus(enemy, state)

		if state != null and state.battlefield != null:
			var att_pos := state.get_position(attacker)
			var emy_pos := state.get_position(enemy)
			var to_enemy := Vector2(float(emy_pos.x - att_pos.x), float(emy_pos.y - att_pos.y))
			var emy_dist := to_enemy.length()
			for other: MercenaryData in enemies:
				if other == enemy:
					continue
				var other_pos := state.get_position(other)
				var to_other := Vector2(float(other_pos.x - att_pos.x), float(other_pos.y - att_pos.y))
				var other_dist := to_other.length()
				if emy_dist >= other_dist:
					continue
				if emy_dist < 0.5:
					continue
				var dot := to_enemy.normalized().dot(to_other.normalized())
				if dot >= 0.7:
					mult += 0.4
					break

		if weapon != null and not weapon.damage_types_1.is_empty():
			var all_types: Array = weapon.damage_types_1.duplicate()
			all_types.append_array(weapon.damage_types_2)
			mult += WeaponEvaluator.score_type_vs_enemy(all_types, enemy, attacker)

		weights.append(maxi(1, int(base * mult)))

	var total := 0
	for w: int in weights:
		total += w
	var roll := randi() % total
	var cumulative := 0
	for i: int in range(enemies.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return enemies[i]
	return enemies[-1]


static func find_flankable_target(
		mover: MercenaryData,
		enemies: Array,
		allies: Array,
		state: BattleState) -> Dictionary:
	var mover_size := int(mover.stats.get("size", 1))
	var best_enemy: MercenaryData = null
	var best_ally: MercenaryData = null
	var best_dist := 999999
	var barred := ConstStates.blocked_targets(mover)
	var barred_logged := false
	for enemy: MercenaryData in enemies:
		if barred.has(enemy):
			if not barred_logged:
				barred_logged = true
				log_target_blocked(mover, enemies, barred)
			continue
		var target_size := int(enemy.stats.get("size", 1))
		if mover_size < target_size - 1:
			continue
		var enemy_pos := state.get_position(enemy)
		for ally: MercenaryData in allies:
			if int(ally.stats.get("size", 1)) < target_size - 1:
				continue
			var ally_pos := state.get_position(ally)
			var da_x := ally_pos.x - enemy_pos.x
			var da_y := ally_pos.y - enemy_pos.y
			if da_x == 0 and da_y == 0:
				continue
			var d := state.distance_to(mover, enemy)
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
				best_ally = ally
			break
	return {"target": best_enemy, "ally": best_ally}


static func _enemy_in_intended_range(
		attacker: MercenaryData,
		enemy: MercenaryData,
		weapon: WeaponData,
		state: BattleState) -> bool:
	if state.battlefield == null or weapon == null:
		return true
	if weapon.ranged_intended_range <= 0:
		return true
	return state.distance_to(attacker, enemy) <= weapon.ranged_intended_range


static func pick_move_target(
		merc: MercenaryData,
		ctx: Dictionary,
		state: BattleState) -> MercenaryData:
	var blocked: Dictionary = ctx.get("blocked_targets", {})
	var perm: Dictionary = state.movement_blocked.get(merc, {}) as Dictionary
	for pb: MercenaryData in perm.keys():
		if MovementExecutor.move_block_holds(merc, pb, state, int(perm[pb])):
			blocked[pb] = true

	var enemies: Array = ctx.get("enemies", [])
	var barred := ConstStates.blocked_targets(merc)
	if not barred.is_empty():
		var removed := false
		for b: MercenaryData in barred:
			if enemies.has(b) and not blocked.has(b):
				blocked[b] = true
				removed = true
		if removed:
			log_target_blocked(merc, enemies, barred)

	var valid: Array = ctx.get("valid_targets", [])

	var candidates: Array = enemies.filter(func(e: MercenaryData) -> bool: return not blocked.has(e))
	if candidates.is_empty():
		candidates = enemies.filter(func(e: MercenaryData) -> bool: return not perm.has(e))
	if candidates.is_empty():
		candidates = enemies

	var _team_pref: Array = candidates.filter(func(e: MercenaryData) -> bool:
		var _r: int = state.team_blocked_round.get(e, -1) as int
		if _r != state.round_number: return true
		return (state.team_blocked_count.get(e, 0) as int) < 2)
	if not _team_pref.is_empty():
		candidates = _team_pref

	if not valid.is_empty():
		var valid_candidates: Array = valid.filter(func(e: MercenaryData) -> bool: return candidates.has(e))
		if not valid_candidates.is_empty():
			var nearest: MercenaryData = null
			var best_score := INF
			var _interior := state.battlefield != null and state.battlefield.is_interior_map
			for enemy: MercenaryData in valid_candidates:
				var d := state.path_distance_to(merc, enemy) if _interior else state.distance_to(merc, enemy)
				var max_hp := float(enemy.stats.get("maximum_hit_points", 1))
				var hp_ratio := clampf(float(enemy.current_hp) / max_hp, 0.0, 1.0)
				var s := d - (1.0 - hp_ratio) - FleeSystem.pursuit_paces(enemy, state)
				if s < best_score:
					best_score = s
					nearest = enemy
			if nearest != null:
				return nearest

	if merc.last_seen_position != Vector3i(-1, -1, -1) and not candidates.is_empty():
		var best_enemy: MercenaryData = null
		var best_dist := INF
		for enemy: MercenaryData in candidates:
			var epos := state.pos3(enemy)
			var d := float(maxi(absi(merc.last_seen_position.x - epos.x), absi(merc.last_seen_position.y - epos.y))
				+ absi(merc.last_seen_position.z - epos.z) * 4)
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
		if best_enemy != null:
			return best_enemy

	if not merc.last_known_enemy_positions.is_empty():
		var merc_pos := state.pos3(merc)
		var best_dist := INF
		var best_enemy: MercenaryData = null
		for enemy: MercenaryData in merc.last_known_enemy_positions.keys():
			if not candidates.has(enemy):
				continue
			var known_pos: Vector3i = merc.last_known_enemy_positions[enemy] as Vector3i
			var d := float(maxi(absi(known_pos.x - merc_pos.x), absi(known_pos.y - merc_pos.y))
				+ absi(known_pos.z - merc_pos.z) * 4)
			d -= FleeSystem.pursuit_paces(enemy, state)
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
		if best_enemy != null:
			return best_enemy

	if not candidates.is_empty():
		var _interior2 := state.battlefield != null and state.battlefield.is_interior_map
		var nearest: MercenaryData = null
		var best_dist := INF
		for enemy: MercenaryData in candidates:
			var d := float(state.path_distance_to(merc, enemy)) if _interior2 else float(state.distance_to(merc, enemy))
			d -= FleeSystem.pursuit_paces(enemy, state)
			if d < best_dist:
				best_dist = d
				nearest = enemy
		return nearest

	return null


static func _flank_ally_at_current_pos(
		attacker: MercenaryData,
		target: MercenaryData,
		allies: Array,
		state: BattleState) -> MercenaryData:
	var target_size := int(target.stats.get("size", 1))
	if int(attacker.stats.get("size", 1)) < target_size - 1:
		return null
	var target_pos := state.get_position(target)
	var attacker_pos := state.get_position(attacker)
	var am_x := attacker_pos.x - target_pos.x
	var am_y := attacker_pos.y - target_pos.y
	for ally: MercenaryData in allies:
		if int(ally.stats.get("size", 1)) < target_size - 1:
			continue
		var ally_pos := state.get_position(ally)
		var da_x := ally_pos.x - target_pos.x
		var da_y := ally_pos.y - target_pos.y
		if am_y < 0 and da_y > 0:
			return ally
		if am_y > 0 and da_y < 0:
			return ally
		if am_x < 0 and da_x > 0:
			return ally
		if am_x > 0 and da_x < 0:
			return ally
	return null


#One line per candidate a target:block:source state bars this merc from attacking.
static func log_target_blocked(merc: MercenaryData, enemies: Array, barred: Array) -> void:
	if not EncounterLogger.is_active():
		return
	for enemy: MercenaryData in enemies:
		if barred.has(enemy):
			EncounterLogger.log_verbose("TARGET BLOCKED: %s -> %s states=%s" % [
				merc.merc_name, enemy.merc_name, _blocking_states(merc, enemy)])


#States whose target:block:source token names this source.
static func _blocking_states(merc: MercenaryData, source: MercenaryData) -> String:
	var names: Array[String] = []
	for e: Dictionary in ConstStates.active_effects(merc):
		if str(e["token"]).begins_with("target:block:source") and e["source"] == source:
			names.append(str(e["state"]))
	return CheckSystem.states_text(names)


#Nearest living enemy with line of sight inside reach_or_range paces.
static func nearest_visible_enemy(merc: MercenaryData, state: BattleState, reach_or_range: int) -> MercenaryData:
	if merc == null or state == null:
		return null
	var best: MercenaryData = null
	var best_d := 9999
	for enemy: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(enemy) or enemy.off_field:
			continue
		if state.battlefield == null:
			return enemy
		var dist := state.distance_to(merc, enemy)
		if reach_or_range > 0 and dist > reach_or_range:
			continue
		if not (LineOfSight.check(state, merc, enemy)["visible"] as bool):
			continue
		if dist < best_d:
			best_d = dist
			best = enemy
	return best


#The reach or range the merc's drawn weapon reaches with right now.
static func weapon_target_range(merc: MercenaryData) -> int:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null:
		return 1
	if weapon.is_ranged:
		return int(WeaponArmorPerkLibrary.ranged_ranges(merc, weapon)["extended"])
	if weapon.is_throwable:
		return int(ThrownWeaponRules.thrown_ranges(merc, weapon)["extended"])
	return WeaponArmorPerkLibrary.get_effective_melee_range(merc)
