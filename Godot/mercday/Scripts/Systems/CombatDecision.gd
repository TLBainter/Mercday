class_name CombatDecision

const DANGER_HP_RATIO := 0.25
const HALF_HP_RATIO   := 0.50
const SAFE_DISTANCE: int = 10  # cells -- beyond this, merc considers themselves safe from melee


# TODO: when multiple attack types exist, choose based on target, range, AP budget, etc.
static func decide_attack_action(_attacker: MercenaryData, _weights: Dictionary = {}) -> String:
	return "Attack"


static func decide_target(
		attacker: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState = null,
		_weights: Dictionary = {}) -> MercenaryData:
	if enemies.is_empty():
		return null
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


static func decide_move_action(
		mover: MercenaryData,
		enemies: Array[MercenaryData],
		allies: Array[MercenaryData],
		state: BattleState) -> Dictionary:
	if enemies.is_empty():
		return {"action": "", "target": null}

	var is_ranged := mover.equipped_weapon != null and mover.equipped_weapon.is_ranged
	var can_fly := int(mover.stats.get("fly", 0)) > 0 and not ConstStates.has_state(mover, ConstStates.GROUNDED)
	var reach := _get_weapon_melee_range(mover)
	var min_enemy_dist := _min_enemy_distance(mover, enemies, state)

	# Regroup when already at safe distance -- suppress further retreat
	if min_enemy_dist > SAFE_DISTANCE:
		if _should_seek_cover(mover) and _has_ranged_enemy(enemies):
			return {"action": "", "target": null}  # let decide_next_action handle seek_cover
		var weapon := mover.equipped_weapon
		if weapon != null and weapon.is_ranged and mover.ammo_loaded == 0:
			return {"action": "", "target": null}  # let decide_next_action handle reload
		if _is_safe_to_reengage(mover):
			return {"action": "Move Close", "target": _closest_enemy(mover, enemies, state)}
		return {"action": "", "target": null}  # too hurt to engage; pass

	if is_ranged:
		var close_threat := _closest_enemy_within(mover, enemies, 1, state)
		if close_threat != null:
			return {"action": "Move Far", "target": close_threat}

	if _is_in_danger(mover):
		var threat := _closest_reachable_enemy(mover, enemies, state)
		if threat != null:
			return {"action": "Move Far", "target": threat}

	if can_fly and is_ranged and state.battlefield != null:
		for enemy: MercenaryData in enemies:
			if state.is_covered_from(enemy, mover, ConstStates.COVERED_FULL):
				return {"action": "Move Close", "target": enemy}

	if not can_fly and is_ranged and state.battlefield != null:
		for enemy: MercenaryData in enemies:
			if state.is_covered_from(enemy, mover, ConstStates.COVERED_FULL):
				var flank_cell: Vector2i = _find_flanking_cell(mover, enemy, state)
				if flank_cell != Vector2i(-1, -1):
					return {"action": "Move Close", "target": enemy}

	if not is_ranged:
		if _closest_enemy_within(mover, enemies, reach, state) == null:
			var flank := _find_flankable_target(mover, enemies, allies, state)
			if flank["target"] != null:
				return {"action": "Move Close", "target": flank["target"], "flank_ally": flank["ally"]}
			return {"action": "Move Close", "target": _closest_enemy(mover, enemies, state)}

	var mover_pace := int(mover.stats.get("pace", 1))
	for ally: MercenaryData in allies:
		if _is_in_danger(ally):
			for enemy: MercenaryData in enemies:
				if state.distance_to(ally, enemy) <= 1 and state.distance_to(mover, enemy) <= mover_pace:
					return {"action": "Move Close", "target": enemy}

	if is_ranged and mover.ammo_loaded > 0:
		var weapon_ref := mover.equipped_weapon
		if weapon_ref != null and weapon_ref.ranged_extended_range > 0:
			var all_out_of_range := true
			for enemy: MercenaryData in enemies:
				if state.distance_to(mover, enemy) <= weapon_ref.ranged_extended_range:
					all_out_of_range = false
					break
			if all_out_of_range:
				var closest := _closest_enemy(mover, enemies, state)
				if closest != null:
					return {"action": "Move Close", "target": closest}

	return {"action": "", "target": null}


static func should_attempt_defense(
		defender: MercenaryData,
		damage: int,
		damage_type: String,
		_weights: Dictionary = {}) -> bool:
	var type_data := ConstDamageTypes.get_type(damage_type)
	if type_data.get("is_direct", false):
		return false
	if ConstStates.has_state(defender, ConstStates.VULNERABLE):
		return false
	var best_stat := maxi(
		int(defender.stats.get("defend_reduction", 0)),
		int(defender.stats.get("dodge_reduction", 0))
	)
	if best_stat <= 0:
		return false
	var max_hp := int(defender.stats.get("maximum_hit_points", 1))
	if damage >= defender.current_hp:
		return true
	var pain_limit := int(defender.stats.get("pain_limit", 0))
	if pain_limit > 0 and damage >= pain_limit:
		return true
	if float(defender.current_hp) / float(max_hp) < 0.5:
		return true
	if float(damage) / float(maxi(1, defender.current_hp)) > 0.33:
		return true
	return false


static func decide_next_action(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_attack_targets: Array[MercenaryData],
		allies: Array[MercenaryData],
		current_target: MercenaryData,
		state: BattleState,
		attack_base_cost: int,
		move_base_cost: int,
		_weights: Dictionary = {},
		movement_blocked: bool = false,
		weapon_action_taken: bool = false) -> Dictionary:

	if ConstStates.has_state(merc, ConstStates.SHOCKED) \
			or ConstStates.has_state(merc, ConstStates.DEBILITATED) \
			or ConstStates.has_state(merc, ConstStates.DYING):
		return {"type": "pass", "action_name": "", "target": null}

	if ConstStates.has_state(merc, ConstStates.GRAPPLED) \
			or ConstStates.has_state(merc, ConstStates.INHIBITED) \
			or ConstStates.has_state(merc, ConstStates.SUFFOCATING):
		var break_cost := state.get_cost(merc, "break_free", 2)
		if state.can_afford(merc, break_cost):
			return {"type": "special", "action_name": "break_free", "target": null}

	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		var get_up_cost := state.get_cost(merc, "get_up", 2)
		if state.can_afford(merc, get_up_cost):
			var immediate_threat := _closest_enemy_within(merc, enemies, 1, state)
			if immediate_threat == null or _is_in_danger(merc):
				return {"type": "special", "action_name": "get_up", "target": null}

	if _should_seek_cover(merc) and state.battlefield != null and _has_ranged_enemy(enemies):
		var seek_cost := state.get_cost(merc, "seek_cover", 2)
		if state.can_afford(merc, seek_cost):
			var merc_pos := state.get_position(merc)
			var adj_obs := state.battlefield.get_adjacent_obstacles(merc_pos)
			var cover_useful := false
			for _adj_o in adj_obs:
				var _adj_data: ObstacleData = _adj_o.get("data") as ObstacleData
				if _adj_data != null and not _adj_data.provides_cover:
					continue
				var _adj_delta: Vector2i = (_adj_o["pos"] as Vector2i) - merc_pos
				var _to_cover := Vector2(float(_adj_delta.x), float(_adj_delta.y))
				for _re: MercenaryData in enemies:
					if _re.equipped_weapon == null or not _re.equipped_weapon.is_ranged:
						continue
					var _re_pos := state.get_position(_re)
					var _to_enemy := Vector2(float(_re_pos.x - merc_pos.x), float(_re_pos.y - merc_pos.y))
					if _to_cover.dot(_to_enemy) > 0.0:
						cover_useful = true
						break
				if cover_useful:
					break
			if cover_useful:
				return {"type": "special", "action_name": "seek_cover", "target": null}

	if merc.ammo_loaded == 0 and _should_reload(merc, enemies, valid_attack_targets, state):
		return {"type": "reload", "action_name": "reload", "target": null}

	if not weapon_action_taken:
		var wp_decision := _decide_weapon_action(merc, enemies, state, attack_base_cost, movement_blocked)
		if wp_decision["type"] != "none":
			return wp_decision
		var pu_decision := _decide_pickup_action(merc, enemies, state, attack_base_cost, move_base_cost)
		if pu_decision["type"] != "none":
			return pu_decision

	if not movement_blocked and not ConstStates.has_state(merc, ConstStates.GRAPPLED) and state.battlefield != null:
		var move_decision := decide_move_action(merc, enemies, allies, state)
		var action_str: String = str(move_decision["action"])
		if action_str != "":
			if action_str == "Move Close" and ConstStates.has_state(merc, ConstStates.TERRIFIED):
				pass  # veto; fall through to attack
			else:
				var move_cost := state.get_cost(merc, action_str, move_base_cost)
				if state.can_afford(merc, move_cost):
					return {"type": "move", "action_name": action_str, "target": move_decision["target"]}

	# Goal B: when blocked with no valid targets, reroll to any enemy not in full cover
	if movement_blocked and valid_attack_targets.is_empty() and state.battlefield != null \
			and not ConstStates.has_state(merc, ConstStates.GRAPPLED):
		var reroll_target: MercenaryData = null
		for candidate: MercenaryData in enemies:
			if not state.is_covered_from(candidate, merc, ConstStates.COVERED_FULL):
				reroll_target = candidate
				break
		if reroll_target == null:
			for candidate: MercenaryData in enemies:
				var flank_cell: Vector2i = _find_flanking_cell(merc, candidate, state)
				if flank_cell != Vector2i(-1, -1):
					reroll_target = candidate
					break
		if reroll_target != null:
			var move_cost := state.get_cost(merc, "Move Close", move_base_cost)
			if state.can_afford(merc, move_cost):
				return {"type": "move", "action_name": "Move Close", "target": reroll_target}

	if merc.ammo_loaded > 0 and _should_reload(merc, enemies, valid_attack_targets, state):
		return {"type": "reload", "action_name": "reload", "target": null}

	var wp := merc.equipped_weapon
	# Goal D: Aim only when the current target is actually attackable (has a clear shot)
	var aim_target_valid := current_target != null and valid_attack_targets.has(current_target)
	if wp != null and wp.is_ranged and merc.ammo_loaded > 0 and not merc.weapon_misfired \
			and aim_target_valid and not merc.aim_active:
		var aim_cost := state.get_cost(merc, "Aim", 2)
		if state.can_afford(merc, aim_cost):
			return {"type": "special", "action_name": "aim", "target": null}

	var atk_cost := state.get_cost(merc, "Attack", attack_base_cost)
	if not state.can_afford(merc, atk_cost) or valid_attack_targets.is_empty():
		return {"type": "pass", "action_name": "", "target": null}

	var target: MercenaryData
	if current_target != null and valid_attack_targets.has(current_target):
		target = current_target
	else:
		target = decide_target(merc, valid_attack_targets, state)
	return {"type": "attack", "action_name": "Attack", "target": target}


static func _should_seek_cover(merc: MercenaryData) -> bool:
	if ConstStates.has_state(merc, ConstStates.COVERED_FULL):
		return false
	if ConstStates.has_state(merc, ConstStates.COVERED_PARTIAL):
		return false
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) < DANGER_HP_RATIO


static func _is_in_danger(merc: MercenaryData) -> bool:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) <= DANGER_HP_RATIO


static func _get_weapon_melee_range(merc: MercenaryData) -> int:
	var weapon := merc.equipped_weapon
	if weapon != null and not weapon.is_ranged:
		return weapon.melee_range
	return 1


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


static func _closest_enemy_within(
		mover: MercenaryData,
		enemies: Array[MercenaryData],
		max_dist: int,
		state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_dist := max_dist + 1
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if d <= max_dist and d < best_dist:
			best_dist = d
			best = enemy
	return best


static func _closest_reachable_enemy(
		mover: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		var enemy_pace := int(enemy.stats.get("pace", 1))
		if d <= enemy_pace and d < best_dist:
			best_dist = d
			best = enemy
	return best


static func _should_reload(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_attack_targets: Array[MercenaryData],
		state: BattleState) -> bool:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return false
	if weapon.chamber <= 0:
		# Quiver weapons: only resync ammo_loaded when it desynced from inventory
		if merc.ammo_loaded > 0:
			return false
		var ammo_type_q := merc.ammo_loaded_type
		if ammo_type_q == "" or merc.ammo_inventory.get(ammo_type_q, 0) <= 0:
			return false
		return not _is_in_danger(merc)
	var reload_cost := weapon.load_time
	if reload_cost <= 0 or not state.can_afford(merc, reload_cost):
		return false
	var ammo_type := merc.ammo_loaded_type
	if ammo_type == "" or merc.ammo_inventory.get(ammo_type, 0) <= 0:
		return false

	var in_danger := _is_in_danger(merc)
	var ammo_loaded := merc.ammo_loaded

	if ammo_loaded == 0:
		if not in_danger:
			return true
		var max_hp := float(merc.stats.get("maximum_hit_points", 1))
		var hp_ratio := float(merc.current_hp) / max_hp
		var chance := (hp_ratio / DANGER_HP_RATIO) * 0.25
		if randf() < chance:
			return true
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("RELOAD SKIPPED: %s in danger, hp_ratio=%.2f, chance=%.0f%%" % [
				merc.merc_name, hp_ratio, chance * 100.0])
		return false

	if float(ammo_loaded) < float(weapon.chamber) * 0.5:
		if in_danger:
			return false
		var chance := 0.50
		if valid_attack_targets.is_empty():
			chance = 0.75
			if not _any_enemy_in_range(merc, enemies, weapon, state):
				return true
		return randf() < chance

	return false


static func _any_enemy_in_range(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		weapon: WeaponData,
		state: BattleState) -> bool:
	if state.battlefield == null:
		return true  # No distance tracking; assume reachable
	if weapon.ranged_extended_range <= 0:
		return true
	for enemy: MercenaryData in enemies:
		if state.distance_to(merc, enemy) <= weapon.ranged_extended_range:
			return true
	return false


static func _closest_enemy(
		mover: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState) -> MercenaryData:
	var best: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best if best != null else enemies[0]


static func _min_enemy_distance(mover: MercenaryData, enemies: Array[MercenaryData], state: BattleState) -> int:
	var min_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(mover, enemy)
		if d < min_dist:
			min_dist = d
	return min_dist


static func _is_safe_to_reengage(merc: MercenaryData) -> bool:
	var max_hp := float(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / maxf(1.0, max_hp) >= 0.3 or merc.current_ep >= 1


static func _has_ranged_enemy(enemies: Array[MercenaryData]) -> bool:
	for enemy: MercenaryData in enemies:
		if enemy.equipped_weapon != null and enemy.equipped_weapon.is_ranged:
			return true
	return false


static func _flank_ally_at_current_pos(
		attacker: MercenaryData,
		target: MercenaryData,
		allies: Array[MercenaryData],
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
		# N/S axis: one is north (y < 0) and the other is south (y > 0)
		if am_y < 0 and da_y > 0:
			return ally
		if am_y > 0 and da_y < 0:
			return ally
		# E/W axis: one is west (x < 0) and the other is east (x > 0)
		if am_x < 0 and da_x > 0:
			return ally
		if am_x > 0 and da_x < 0:
			return ally
	return null


static func should_take_advantage_attack(
		reactor: MercenaryData,
		target: MercenaryData,
		new_target_pos: Vector2i,
		state: BattleState) -> bool:
	var score := 0.0

	score += _estimate_kill_likelihood(reactor, target) * 0.30

	var allies := state.get_allies(reactor)
	score += _estimate_ally_threat(target, new_target_pos, allies, state) * 0.25

	var max_ep := float(reactor.stats.get("maximum_endurance_points", 1))
	score += (float(reactor.current_ep) / maxf(1.0, max_ep)) * 0.20

	var enemy_count := state.get_enemies(reactor).size()
	score += (1.0 if enemy_count <= 1 else 1.0 / float(enemy_count)) * 0.15

	score += (0.10 if state.last_attacked.get(reactor) == target else 0.0)

	return randf() < score


static func _estimate_kill_likelihood(attacker: MercenaryData, target: MercenaryData) -> float:
	var weapon := attacker.equipped_weapon
	if weapon == null:
		return 0.0
	var avg_dmg := _parse_formula_for_avg(weapon.damage_formula_1)
	var weapon_key := "vigor" if (weapon.has_heavy and not weapon.has_light) \
		else ("dexterity" if (weapon.has_light and not weapon.has_heavy) \
		else "dexterity")
	avg_dmg += float(attacker.stats.get(weapon_key, 0)) * 0.4
	return minf(1.0, avg_dmg / maxf(1.0, float(target.current_hp)))


static func _estimate_ally_threat(
		target: MercenaryData,
		new_pos: Vector2i,
		allies: Array[MercenaryData],
		state: BattleState) -> float:
	if allies.is_empty():
		return 0.0
	var weapon := target.equipped_weapon
	var threat_range := 1
	if weapon != null:
		threat_range = weapon.ranged_intended_range if weapon.is_ranged else weapon.melee_range
	for ally: MercenaryData in allies:
		var apos := state.get_position(ally)
		if maxi(abs(new_pos.x - apos.x), abs(new_pos.y - apos.y)) <= threat_range:
			return 1.0
	return 0.0


static func is_melee_preferred(merc: MercenaryData) -> bool:
	var melee_acc := maxf(1.0, float(merc.stats.get("melee_accuracy", 1.0)))
	var ranged_acc := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
	var best_melee_dps := 0.0
	var best_ranged_dps := 0.0
	if merc.equipped_weapon != null:
		var w := merc.equipped_weapon
		var avg := _parse_formula_for_avg(w.damage_formula_1)
		if w.is_ranged:
			best_ranged_dps = avg * ranged_acc
		else:
			best_melee_dps = avg * melee_acc
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			continue
		var w: WeaponData = entry.get("data") as WeaponData
		if w == null:
			continue
		var avg := _parse_formula_for_avg(w.damage_formula_1)
		if w.is_ranged:
			best_ranged_dps = maxf(best_ranged_dps, avg * ranged_acc)
		else:
			best_melee_dps = maxf(best_melee_dps, avg * melee_acc)
	return best_melee_dps > best_ranged_dps


static func _parse_formula_for_avg(formula: String) -> float:
	var f := formula.strip_edges()
	if f == "" or f == "0" or f == "Varies":
		return 0.0
	var flat := 0.0
	var plus_idx := f.find(" + ")
	if plus_idx != -1:
		flat = float(f.substr(plus_idx + 3).strip_edges())
		f = f.left(plus_idx).strip_edges()
	var d_idx := f.find("d")
	if d_idx == -1:
		return flat
	var num_str := f.left(d_idx)
	var sides_str := f.substr(d_idx + 1)
	if not num_str.is_valid_int() or not sides_str.is_valid_int():
		return flat
	return flat + float(num_str.to_int()) * float(sides_str.to_int()) * 0.5


static func _get_available_weapons(merc: MercenaryData) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	if merc.equipped_weapon != null:
		result.append(merc.equipped_weapon)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			var w: WeaponData = entry.get("data")
			if w != null:
				result.append(w)
	var fight: WeaponData = DataManager.fight_weapon
	if fight != null and not result.has(fight):
		result.append(fight)
	return result


static func _score_weapon(
		weapon: WeaponData,
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool = false) -> float:
	if weapon.is_ranged:
		var is_equipped := merc.equipped_weapon == weapon
		var has_ammo: bool = false
		if is_equipped:
			has_ammo = merc.ammo_loaded > 0 \
					or merc.ammo_inventory.get(merc.ammo_loaded_type, 0) > 0
		else:
			for ammo_type: String in merc.ammo_inventory:
				if (merc.ammo_inventory[ammo_type] as int) <= 0:
					continue
				var _ammo_data: AmmoData = DataManager.ammo.get(ammo_type)
				if _ammo_data != null and _ammo_data.compatible.has(weapon.weapon_type):
					has_ammo = true
					break
		if not has_ammo:
			return -999.0

	if state.battlefield == null or enemies.is_empty():
		return 0.0

	var closest_dist := 999999
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(merc, enemy)
		if d < closest_dist:
			closest_dist = d

	var score := 0.0
	if closest_dist <= 2:
		# enemies are close; melee/thrown preferred
		if not weapon.is_ranged:
			if float(merc.stats.get("melee_accuracy", 0.0)) >= 1.0:
				score += 2.0
		else:
			score -= 0.5
	else:
		# enemies are far; ranged preferred
		if weapon.is_ranged:
			var in_range := 0
			var in_intended := 0
			for enemy: MercenaryData in enemies:
				var d := state.distance_to(merc, enemy)
				if weapon.ranged_extended_range <= 0 or d <= weapon.ranged_extended_range:
					in_range += 1
				if weapon.ranged_intended_range <= 0 or d <= weapon.ranged_intended_range:
					in_intended += 1
			# Weight per-enemy score by weapon damage: "Varies"/0-dmg weapons (blowguns) get 0.1x
			var ranged_avg_dmg := _parse_formula_for_avg(weapon.damage_formula_1)
			var dmg_factor := clampf(ranged_avg_dmg / 7.0, 0.1, 2.0)
			score += 1.5 * float(in_range) * dmg_factor
			var melee_acc_r := maxf(1.0, float(merc.stats.get("melee_accuracy", 50.0)))
			var ranged_acc_r := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
			score *= clampf(ranged_acc_r / melee_acc_r, 0.1, 2.0)
			# Extended-range penalty: each enemy only reachable in extended range adds 1 Flaw -> -0.4
			score -= 0.4 * float(in_range - in_intended)
			if weapon.misfire > 0:
				var misfire_risk: float = clampf(float(weapon.misfire) * 0.35, 0.0, 2.5)
				var accuracy_factor: float = clampf(1.0 - ranged_acc_r / 100.0, 0.0, 1.0)
				score -= misfire_risk * (0.3 + accuracy_factor * 0.7)
		elif weapon.is_throwable:
			for enemy: MercenaryData in enemies:
				var d := state.distance_to(merc, enemy)
				if weapon.thrown_extended_range <= 0 or d <= weapon.thrown_extended_range:
					score += 0.5
		else:
			# melee at range -- penalty scales with how long it takes to close the gap,
			# multiplied by how much better ranged would be for this merc
			var pace := maxf(1.0, float(merc.stats.get("pace", 1)))
			var turns_to_close := float(closest_dist) / pace
			if movement_blocked:
				turns_to_close *= 3.0  # proven blocked path: treat gap as effectively much larger
			# dist_factor: 0 at <=1 turn away, ~1.0 at 5 turns, capped at 2.0
			var dist_factor := clampf((turns_to_close - 1.0) / 4.0, 0.0, 2.0)
			# ranged_aptitude: 0 = no ranged skill (never switch), 1 = equal, 2+ = ranged specialist
			var melee_acc := maxf(1.0, float(merc.stats.get("melee_accuracy", 50.0)))
			var ranged_acc := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
			var ranged_aptitude := clampf(ranged_acc / melee_acc, 0.0, 3.0)
			score -= dist_factor * ranged_aptitude
			var melee_preference := clampf(1.0 - ranged_aptitude, 0.0, 1.0)
			var reachability := clampf(1.0 - (turns_to_close - 1.0) / 5.0, 0.0, 1.0)
			score += melee_preference * reachability * 2.0
			# Damage advantage: if this melee weapon out-damages the best ranged option, add bonus
			var melee_avg_dmg := _parse_formula_for_avg(weapon.damage_formula_1)
			var best_ranged_avg := 0.0
			for w: WeaponData in _get_available_weapons(merc):
				if w.is_ranged:
					best_ranged_avg = maxf(best_ranged_avg, _parse_formula_for_avg(w.damage_formula_1))
			if melee_avg_dmg > 0.0 or best_ranged_avg > 0.0:
				var dmg_ratio := (melee_avg_dmg - best_ranged_avg) / maxf(1.0, melee_avg_dmg + best_ranged_avg)
				score += clampf(dmg_ratio * 1.5, -0.5, 1.5) * reachability
	return score


static func _best_available_weapon(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool = false) -> WeaponData:
	var available := _get_available_weapons(merc)
	if available.is_empty():
		return null
	var best: WeaponData = null
	var best_score := -9999.0
	for weapon: WeaponData in available:
		var s := _score_weapon(weapon, merc, enemies, state, movement_blocked)
		if s > best_score:
			best_score = s
			best = weapon
	return best


static func _should_draw_now_vs_move(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		weapon: WeaponData,
		draw_cost: int,
		state: BattleState,
		attack_base_cost: int) -> bool:
	var ap_after_draw := (merc.current_ap + merc.excess_ap) - draw_cost
	if ap_after_draw >= attack_base_cost:
		return true  # can still attack this turn after drawing
	# Can't attack after drawing. Draw anyway only if all enemies are already in range.
	if state.battlefield == null:
		return true
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(merc, enemy)
		var in_range: bool
		if weapon.is_ranged:
			in_range = weapon.ranged_extended_range <= 0 or d <= weapon.ranged_extended_range
		else:
			in_range = d <= weapon.melee_range
		if not in_range:
			return false  # out-of-range enemy; move first, draw later
	return true


static func _should_holster_vs_drop(
		merc: MercenaryData,
		current_weapon: WeaponData,
		enemies: Array[MercenaryData]) -> bool:
	# Drop ranged weapon only when it's completely out of ammo with no restock
	if current_weapon.is_ranged and merc.ammo_loaded <= 0:
		var has_reserve := false
		for count: int in merc.ammo_inventory.values():
			if count > 0:
				has_reserve = true
				break
		if not has_reserve:
			return false  # useless; drop it
	# If it's the only weapon of its type, keep it (might need it later)
	var available := _get_available_weapons(merc)
	var other_ranged := false
	var other_melee := false
	for w: WeaponData in available:
		if w == current_weapon:
			continue
		if w.is_ranged:
			other_ranged = true
		else:
			other_melee = true
	if current_weapon.is_ranged and not other_ranged and _has_ranged_enemy(enemies):
		return true  # only ranged option; holster to keep it
	if not current_weapon.is_ranged and not other_melee:
		return true  # only melee option; holster to keep it
	return true  # default: holster (safer)


static func _decide_weapon_action(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		attack_base_cost: int,
		movement_blocked: bool = false) -> Dictionary:
	var no_action := {"type": "none", "action_name": "", "target": null, "weapon": null}

	if merc.equipped_weapon == null or not merc.weapon_drawn:
		# Need to draw a weapon
		var draw_target := _best_available_weapon(merc, enemies, state, movement_blocked)
		if draw_target == null:
			return no_action
		var draw_cost := state.get_cost(merc, "Draw", draw_target.draw)
		if not state.can_afford(merc, draw_cost):
			return no_action
		if _should_draw_now_vs_move(merc, enemies, draw_target, draw_cost, state, attack_base_cost):
			return {"type": "draw", "action_name": "Draw", "target": null, "weapon": draw_target}
		return no_action

	# Weapon is drawn; check whether switching to an inventory weapon is worth it
	if merc.inventory.is_empty():
		return no_action
	var has_inv_weapon := false
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			has_inv_weapon = true
			break
	if not has_inv_weapon:
		return no_action

	var current_score := _score_weapon(merc.equipped_weapon, merc, enemies, state, movement_blocked)
	if current_score >= 0.0:
		return no_action  # current weapon is functional; don't switch
	var best := _best_available_weapon(merc, enemies, state, movement_blocked)
	if best == null or best == merc.equipped_weapon:
		return no_action

	var best_can_reach := false
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(merc, enemy)
		var in_reach: bool = best.is_ranged \
				and (best.ranged_extended_range <= 0 or d <= best.ranged_extended_range)
		if not in_reach:
			in_reach = not best.is_ranged and d <= best.melee_range
		if in_reach:
			best_can_reach = true
			break
	if not best_can_reach:
		return no_action

	# Decide holster vs drop
	if _should_holster_vs_drop(merc, merc.equipped_weapon, enemies):
		var holster_cost := state.get_cost(merc, "Holster", merc.equipped_weapon.draw)
		var total_ap := merc.current_ap + merc.excess_ap
		if state.can_afford(merc, holster_cost) and total_ap - holster_cost - best.draw >= attack_base_cost:
			return {"type": "holster", "action_name": "Holster", "target": null, "weapon": null}
		# Holster too expensive; drop to free hands for the better weapon
		if state.can_afford(merc, best.draw):
			return {"type": "drop", "action_name": "Drop", "target": null, "weapon": null,
					"cause": "swapped for %s" % best.item_name, "swap_weapon": best}

	# Ammo exhausted with no reserve; drop useless ranged weapon
	if state.can_afford(merc, best.draw):
		return {"type": "drop", "action_name": "Drop", "target": null, "weapon": null,
				"cause": "ammo exhausted", "swap_weapon": best}

	return no_action


static func _score_weapon_at_pos(
		weapon_entry: Dictionary,
		weapon_pos: Vector2i,
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState) -> float:
	var weapon: WeaponData = weapon_entry.get("weapon")
	if weapon == null or state.battlefield == null or enemies.is_empty():
		return -999.0
	if weapon.is_ranged:
		var stored_ammo: int = weapon_entry.get("ammo_loaded", 0)
		var has_ammo := stored_ammo > 0
		if not has_ammo:
			for count: int in merc.ammo_inventory.values():
				if count > 0:
					has_ammo = true
					break
		if not has_ammo:
			return -999.0
	var closest_dist := 999999
	for enemy: MercenaryData in enemies:
		var ep := state.get_position(enemy)
		var d := maxi(abs(weapon_pos.x - ep.x), abs(weapon_pos.y - ep.y))
		if d < closest_dist:
			closest_dist = d
	var score := 0.0
	if closest_dist <= 2:
		if not weapon.is_ranged:
			score += 2.0
		else:
			score -= 0.5
	else:
		if weapon.is_ranged:
			var in_range := 0
			for enemy: MercenaryData in enemies:
				var ep := state.get_position(enemy)
				var d := maxi(abs(weapon_pos.x - ep.x), abs(weapon_pos.y - ep.y))
				if weapon.ranged_extended_range <= 0 or d <= weapon.ranged_extended_range:
					in_range += 1
			score += 1.5 * float(in_range)
		elif weapon.is_throwable:
			for enemy: MercenaryData in enemies:
				var ep := state.get_position(enemy)
				var d := maxi(abs(weapon_pos.x - ep.x), abs(weapon_pos.y - ep.y))
				if weapon.thrown_extended_range <= 0 or d <= weapon.thrown_extended_range:
					score += 0.5
	return score


static func _decide_pickup_action(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		attack_base_cost: int,
		move_base_cost: int) -> Dictionary:
	var no_action := {"type": "none", "action_name": "", "target": null, "weapon": null,
			"weapon_entry": {}, "weapon_pos": Vector2i(-1, -1)}

	var merc_pos := state.get_position(merc)
	var current_score := -9999.0
	if merc.equipped_weapon != null and merc.weapon_drawn:
		current_score = _score_weapon(merc.equipped_weapon, merc, enemies, state)

	# --- Immediate pickup (weapon already at merc's tile) ---
	var at_pos: Array = state.get_dropped_weapons_at(merc_pos)
	if not at_pos.is_empty():
		var best_entry: Dictionary = {}
		var best_score := -9999.0
		for entry: Dictionary in at_pos:
			var w: WeaponData = entry.get("weapon")
			if w == null:
				continue
			var cost := state.get_cost(merc, "PickUp", 1 + w.draw)
			if not state.can_afford(merc, cost):
				continue
			var score := _score_weapon_at_pos(entry, merc_pos, merc, enemies, state)
			if score <= current_score:
				continue  # not an upgrade
			if score <= best_score:
				continue
			# Also check pickup beats the best inventory draw option
			var best_inv := _best_available_weapon(merc, enemies, state)
			var inv_score := _score_weapon(best_inv, merc, enemies, state) if best_inv != null else -9999.0
			if score <= inv_score:
				continue
			var ap_after := (merc.current_ap + merc.excess_ap) - cost
			if ap_after < attack_base_cost and score < 0.0:
				continue  # can't attack after pickup and weapon isn't even useful
			best_score = score
			best_entry = entry
		if not best_entry.is_empty():
			return {"type": "pickup", "action_name": "PickUp", "target": null, "weapon": null,
					"weapon_entry": best_entry, "weapon_pos": merc_pos}

	# --- Move toward nearby dropped weapon ---
	# Only if merc has nothing usable in hand or inventory
	var best_on_hand := _best_available_weapon(merc, enemies, state)
	var on_hand_score := _score_weapon(best_on_hand, merc, enemies, state) if best_on_hand != null else -9999.0
	if on_hand_score >= 0.0:
		return no_action

	if state.battlefield == null or state.dropped_weapons.is_empty():
		return no_action

	var pace := int(merc.stats.get("pace", 1))
	var move_cost := state.get_cost(merc, "Move Close", move_base_cost)
	if not state.can_afford(merc, move_cost):
		return no_action

	var best_wp_entry: Dictionary = {}
	var best_wp_pos := Vector2i(-1, -1)
	var best_wp_score := -9999.0
	for pos: Vector2i in state.dropped_weapons.keys():
		var dist := maxi(abs(pos.x - merc_pos.x), abs(pos.y - merc_pos.y))
		if dist > pace or dist == 0:
			continue
		var enemies_adj := 0
		for enemy: MercenaryData in enemies:
			var ep := state.get_position(enemy)
			if maxi(abs(pos.x - ep.x), abs(pos.y - ep.y)) <= 1:
				enemies_adj += 1
		if enemies_adj > 1:
			continue  # too dangerous
		for entry: Dictionary in state.dropped_weapons[pos]:
			var score := _score_weapon_at_pos(entry, pos, merc, enemies, state)
			if score > best_wp_score:
				best_wp_score = score
				best_wp_entry = entry
				best_wp_pos = pos

	if not best_wp_entry.is_empty() and best_wp_score > 0.0:
		# Don't move away from all enemies to fetch a weapon — that creates oscillation loops.
		var moving_toward_any_enemy := false
		for enemy: MercenaryData in enemies:
			var ep := state.get_position(enemy)
			var dist_now := maxi(absi(merc_pos.x - ep.x), absi(merc_pos.y - ep.y))
			var dist_after := maxi(absi(best_wp_pos.x - ep.x), absi(best_wp_pos.y - ep.y))
			if dist_after <= dist_now:
				moving_toward_any_enemy = true
				break
		if moving_toward_any_enemy:
			return {"type": "move_to_pickup", "action_name": "Move Close", "target": null, "weapon": null,
					"weapon_entry": best_wp_entry, "weapon_pos": best_wp_pos}

	return no_action


static func _find_flankable_target(
		mover: MercenaryData,
		enemies: Array[MercenaryData],
		allies: Array[MercenaryData],
		state: BattleState) -> Dictionary:
	var mover_size := int(mover.stats.get("size", 1))
	var best_enemy: MercenaryData = null
	var best_ally: MercenaryData = null
	var best_dist := 999999
	for enemy: MercenaryData in enemies:
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
			# Ally must be on a clear axis side (not at the same position as enemy)
			if da_x == 0 and da_y == 0:
				continue
			var d := state.distance_to(mover, enemy)
			if d < best_dist:
				best_dist = d
				best_enemy = enemy
				best_ally = ally
			break  # First qualifying ally per enemy is enough
	return {"target": best_enemy, "ally": best_ally}


# Returns true if obstacle at obs_pos shields target_pos from attacker at att_pos.
# obs_pos is between att_pos and target_pos when it is closer to att_pos than target_pos
# and the dot product of (obs - att) onto (target - att) is positive (same half-plane).
static func _obstacle_covers_target_from(att_pos: Vector2i, target_pos: Vector2i, obs_pos: Vector2i) -> bool:
	var to_obs := Vector2(float(obs_pos.x - att_pos.x), float(obs_pos.y - att_pos.y))
	var to_target := Vector2(float(target_pos.x - att_pos.x), float(target_pos.y - att_pos.y))
	if to_obs.dot(to_target) <= 0.0:
		return false
	return to_obs.length_squared() < to_target.length_squared()


# Searches cells within the mover's pace range for a position where the cover obstacle
# no longer sits between the mover and the target.  Returns Vector2i(-1,-1) if none found.
static func _find_flanking_cell(mover: MercenaryData, target: MercenaryData, state: BattleState) -> Vector2i:
	if state.battlefield == null:
		return Vector2i(-1, -1)
	var cover_info := state.get_cover_info(target)
	if cover_info.is_empty():
		return Vector2i(-1, -1)
	var obs_pos := Vector2i(
		int(cover_info.get("obstacle_pos_x", -999)),
		int(cover_info.get("obstacle_pos_y", -999)))
	if obs_pos == Vector2i(-999, -999):
		return Vector2i(-1, -1)

	var mover_pos := state.get_position(mover)
	var target_pos := state.get_position(target)
	var pace := maxi(1, int(mover.stats.get("pace", 1)))
	var field := state.battlefield

	var ally_passable: Dictionary = {}
	for key: MercenaryData in state.positions.keys():
		if key != mover and BattleState._is_alive(key):
			var kp: Vector2i = state.positions[key]
			if state.get_allies(mover).has(key) and not ConstStates.has_state(key, ConstStates.DEPOSED):
				ally_passable[kp] = true
	ally_passable.merge(field.get_nav_passable_cells())

	for dx: int in range(-pace, pace + 1):
		for dy: int in range(-pace, pace + 1):
			if maxi(abs(dx), abs(dy)) > pace:
				continue
			var candidate := Vector2i(mover_pos.x + dx, mover_pos.y + dy)
			if candidate.x < 0 or candidate.x >= field.width or candidate.y < 0 or candidate.y >= field.length:
				continue
			if candidate == mover_pos:
				continue
			# Obstacle must no longer be between candidate and target
			if _obstacle_covers_target_from(candidate, target_pos, obs_pos):
				continue
			# Candidate must be reachable
			var path := Pathfinder.find_path(mover_pos, candidate, field, ally_passable)
			if path.is_empty():
				continue
			return candidate
	return Vector2i(-1, -1)


# Guard + cost comparison for the attack_obstacle decision.
# Returns either the original attack_obstacle dict, a Move Close toward a flank,
# or a direct attack dict if an enemy is already within melee reach.
static func decide_obstacle_or_flank(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_attack_targets: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool = false) -> Dictionary:
	var attack_obs_result := {"type": "special", "action_name": "attack_obstacle", "target": null}

	# Guard: enemy within melee reach -- attack them instead
	if not valid_attack_targets.is_empty():
		var wp := merc.equipped_weapon
		var melee_reach := 1
		if wp != null and not wp.is_ranged and not wp.is_throwable:
			melee_reach = wp.melee_range
		for vt: MercenaryData in valid_attack_targets:
			if state.distance_to(merc, vt) <= melee_reach:
				return {"type": "attack", "action_name": "Attack",
						"target": decide_target(merc, valid_attack_targets, state)}

	# Find the blocking obstacle at the merc's position (skip indestructible ones)
	if state.battlefield == null:
		return attack_obs_result
	var merc_pos := state.get_position(merc)
	var blocking_obs: Dictionary = {}
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(merc_pos):
		if obs.get("cell_type", "") == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.is_stairs or d.indestructible:
			continue
		blocking_obs = obs
		break
	if blocking_obs.is_empty():
		return {"type": "pass", "action_name": "", "target": null}

	# Estimate rounds to destroy
	var obs_data: ObstacleData = blocking_obs.get("data") as ObstacleData
	var obs_hp: int
	if obs_data != null and obs_data.health > 1:
		obs_hp = obs_data.health
	elif obs_data != null and (obs_data.is_building or obs_data.obstacle_type == "Structure"):
		obs_hp = 20
	elif obs_data != null:
		match obs_data.obstacle_type:
			"Vegetation", "Furniture":
				obs_hp = maxi(2, obs_data.size)
			"Terrain":
				obs_hp = maxi(4, obs_data.size * 2)
			_:
				obs_hp = maxi(3, obs_data.size)
	else:
		obs_hp = 3
	if blocking_obs.has("current_hp"):
		obs_hp = maxi(1, int(blocking_obs["current_hp"]))
	var wp2 := merc.equipped_weapon
	var acc_stat := clampf(float(merc.stats.get("melee_accuracy", 50)) / 100.0, 0.05, 1.0)
	if wp2 != null and wp2.is_ranged:
		acc_stat = clampf(float(merc.stats.get("ranged_accuracy", 50)) / 100.0, 0.05, 1.0)
	var dmg_avg := 1.0
	if wp2 != null:
		dmg_avg = maxf(1.0, _parse_formula_for_avg(wp2.damage_formula_1))
	var expected_dmg := acc_stat * dmg_avg
	var rounds_to_destroy := ceili(float(obs_hp) / maxf(1.0, expected_dmg))

	# Find flanking cell and estimate rounds to flank
	var nearest_enemy: MercenaryData = null
	var nearest_dist := 999999
	for e: MercenaryData in enemies:
		var d := state.distance_to(merc, e)
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = e
	var flank_cell := Vector2i(-1, -1)
	if nearest_enemy != null:
		flank_cell = _find_flanking_cell(merc, nearest_enemy, state)
	if flank_cell == Vector2i(-1, -1):
		# No flank available -- only destroy if it can be done quickly
		if rounds_to_destroy <= 3:
			EncounterLogger.log_verbose("  obstacle choice: destroy≈%d rounds, no flank → destroy (quick)" % rounds_to_destroy)
			return attack_obs_result
		EncounterLogger.log_verbose("  obstacle choice: destroy≈%d rounds, no flank, too slow → pass" % rounds_to_destroy)
		return {"type": "pass", "action_name": "", "target": null}
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var flank_dist := maxi(abs(flank_cell.x - merc_pos.x), abs(flank_cell.y - merc_pos.y))
	var rounds_to_flank := ceili(float(flank_dist) / float(pace))

	# Heavily prefer flanking -- only destroy if it is at least twice as fast as flanking.
	if rounds_to_destroy * 2 < rounds_to_flank:
		EncounterLogger.log_verbose("  obstacle choice: destroy≈%d rounds, flank≈%d rounds → destroy (much faster)" % [rounds_to_destroy, rounds_to_flank])
		return attack_obs_result
	# If movement is blocked, flanking is impossible this slot -- attack or pass rather than loop.
	if movement_blocked:
		if rounds_to_destroy <= 5:
			EncounterLogger.log_verbose("  obstacle choice: destroy≈%d rounds, movement blocked → destroy" % rounds_to_destroy)
			return attack_obs_result
		EncounterLogger.log_verbose("  obstacle choice: destroy≈%d rounds, movement blocked, too slow → pass" % rounds_to_destroy)
		return {"type": "pass", "action_name": "", "target": null}
	EncounterLogger.log_verbose("  obstacle choice: destroy≈%d rounds, flank≈%d rounds → flank" % [rounds_to_destroy, rounds_to_flank])
	return {"type": "move", "action_name": "Move Close",
			"target": nearest_enemy, "flank_ally": null}
