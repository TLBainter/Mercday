class_name CombatDecision

const DANGER_HP_RATIO := 0.25
const HALF_HP_RATIO   := 0.50


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

	return {"action": "", "target": null}


static func should_use_excess_ap_to_defend(
		defender: MercenaryData,
		damage: int,
		damage_type: String,
		_weights: Dictionary = {}) -> bool:
	var type_data := ConstDamageTypes.get_type(damage_type)
	if type_data.get("is_direct", false):
		return false
	if ConstStates.has_state(defender, ConstStates.VULNERABLE):
		return false
	var max_hp := int(defender.stats.get("maximum_hit_points", 1))
	if damage >= defender.current_hp:
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
		movement_blocked: bool = false) -> Dictionary:

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
			if not adj_obs.is_empty():
				return {"type": "special", "action_name": "seek_cover", "target": null}

	if merc.ammo_loaded == 0 and _should_reload(merc, enemies, valid_attack_targets, state):
		return {"type": "reload", "action_name": "reload", "target": null}

	if not movement_blocked and not ConstStates.has_state(merc, ConstStates.GRAPPLED) and state.battlefield != null:
		var move_decision := decide_move_action(merc, enemies, allies, state)
		var action_str: String = str(move_decision["action"])
		if action_str != "":
			if action_str == "Move Close" and ConstStates.has_state(merc, ConstStates.TERRIFIED):
				pass  # veto — fall through to attack
			else:
				var move_cost := state.get_cost(merc, action_str, move_base_cost)
				if state.can_afford(merc, move_cost):
					return {"type": "move", "action_name": action_str, "target": move_decision["target"]}

	if merc.ammo_loaded > 0 and _should_reload(merc, enemies, valid_attack_targets, state):
		return {"type": "reload", "action_name": "reload", "target": null}

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
	return float(merc.current_hp) / float(max_hp) < HALF_HP_RATIO


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
		return randf() < chance

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
