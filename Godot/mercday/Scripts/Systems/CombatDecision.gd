class_name CombatDecision

const _WEIGHTS := preload("res://Scripts/Actions/Resources/AIWeightsConfig.tres")


# TODO: when multiple attack types exist, choose based on target, range, AP budget, etc.
static func decide_attack_action(_attacker: MercenaryData, _weights: Dictionary = {}) -> String:
	return "Attack"


static func decide_target(
		attacker: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState = null,
		_weights: Dictionary = {}) -> MercenaryData:
	return TargetSelector.pick_target(attacker, enemies, state, _weights)


static func decide_move_action(
		mover: MercenaryData,
		enemies: Array[MercenaryData],
		allies: Array[MercenaryData],
		state: BattleState) -> Dictionary:
	return MovementDecider.decide_move(mover, enemies, allies, state)


static func _decide_weapon_action(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		attack_base_cost: int,
		movement_blocked: bool = false) -> Dictionary:
	return WeaponEvaluator._decide_weapon_action(merc, enemies, state, attack_base_cost, movement_blocked)


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
	if float(damage) / float(maxi(1, defender.current_hp)) > _WEIGHTS.defense_damage_threshold:
		return true
	return false


static func should_spend_excess_ap(
		defender: MercenaryData,
		attacker: MercenaryData,
		damage_type: String,
		state: BattleState,
		excess_needed: int = 1) -> bool:
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

	var score := 0.0

	var max_hp := float(maxi(1, int(defender.stats.get("maximum_hit_points", 1))))
	var hp_ratio := float(defender.current_hp) / max_hp
	if hp_ratio <= 0.25:
		score += 0.35
	elif hp_ratio <= 0.50:
		score += 0.20
	elif hp_ratio <= 0.75:
		score += 0.05

	var eap_surplus := defender.excess_ap - excess_needed
	if eap_surplus >= 3:
		score += 0.30
	elif eap_surplus >= 2:
		score += 0.20
	elif eap_surplus >= 1:
		score += 0.10

	var max_ep := float(maxi(1, int(defender.stats.get("maximum_endurance_points", 1))))
	var ep_ratio := float(defender.current_ep) / max_ep
	if ep_ratio <= 0.25:
		score += 0.30
	elif ep_ratio <= 0.50:
		score += 0.15
	elif ep_ratio <= 0.75:
		score += 0.05

	var ranged_threat := false
	var nearby_melee_threat := false
	if attacker != null and attacker.equipped_weapon != null:
		ranged_threat = attacker.equipped_weapon.is_ranged
	var alive_enemies := 0
	for e: MercenaryData in state.get_enemies(defender):
		if not BattleState._is_alive(e):
			continue
		alive_enemies += 1
		if e == attacker:
			continue
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_threat = true
		elif state.distance_to(defender, e) <= 2:
			nearby_melee_threat = true

	if not ranged_threat and not nearby_melee_threat:
		score += 0.15
	elif not ranged_threat:
		score += 0.07

	if alive_enemies <= 1:
		score += 0.10
	elif alive_enemies <= 2:
		score += 0.05

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("EXAP_EVAL: %s score=%.2f hp=%.0f%% eap_surplus=%d ep=%.0f%% threat=%s enemies=%d" % [
			defender.merc_name, score,
			hp_ratio * 100.0, eap_surplus, ep_ratio * 100.0,
			"ranged" if ranged_threat else ("melee" if nearby_melee_threat else "none"),
			alive_enemies])

	return score >= 0.40


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
				if _adj_data != null and not _adj_data.covers:
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
		var ctx := {
			"enemies": enemies, "allies": allies, "valid_targets": valid_attack_targets,
			"state": state, "current_target": current_target,
			"movement_blocked": movement_blocked,
			"attack_base_ap": attack_base_cost, "move_base_ap": move_base_cost
		}
		var wp_decision := WeaponEvaluator.decide_action(merc, state, ctx)
		if wp_decision["type"] != "none":
			return wp_decision
		var pu_decision := _decide_pickup_action(merc, enemies, state, attack_base_cost, move_base_cost)
		if pu_decision["type"] != "none":
			return pu_decision

	if not movement_blocked and not ConstStates.has_state(merc, ConstStates.GRAPPLED) and state.battlefield != null:
		var break_dec := _decide_break_for_weapon(merc, enemies, state, attack_base_cost, move_base_cost)
		if break_dec["type"] != "none":
			return break_dec

	if not movement_blocked and not ConstStates.has_state(merc, ConstStates.GRAPPLED) and state.battlefield != null:
		var move_decision := MovementDecider.decide_move(merc, enemies, allies, state)
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
				var flank_cell: Vector2i = MovementDecider.find_flanking_cell(merc, candidate, state)
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
		target = TargetSelector.pick_target(merc, valid_attack_targets, state)
	return {"type": "attack", "action_name": "Attack", "target": target}


static func _should_seek_cover(merc: MercenaryData) -> bool:
	if ConstStates.has_state(merc, ConstStates.COVERED_FULL):
		return false
	if ConstStates.has_state(merc, ConstStates.COVERED_PARTIAL):
		return false
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) < _WEIGHTS.danger_hp_ratio


static func _is_in_danger(merc: MercenaryData) -> bool:
	var max_hp := int(merc.stats.get("maximum_hit_points", 1))
	return float(merc.current_hp) / float(max_hp) <= _WEIGHTS.danger_hp_ratio


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


static func _should_reload(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_attack_targets: Array[MercenaryData],
		state: BattleState) -> bool:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return false
	if weapon.chamber <= 0:
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
		var chance := (hp_ratio / _WEIGHTS.danger_hp_ratio) * 0.25
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
		return true
	if weapon.ranged_extended_range <= 0:
		return true
	for enemy: MercenaryData in enemies:
		if state.distance_to(merc, enemy) <= weapon.ranged_extended_range:
			return true
	return false


static func _has_ranged_enemy(enemies: Array[MercenaryData]) -> bool:
	for enemy: MercenaryData in enemies:
		if enemy.equipped_weapon != null and enemy.equipped_weapon.is_ranged:
			return true
	return false


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
	var all_weapons: Array[WeaponData] = []
	if merc.equipped_weapon != null:
		all_weapons.append(merc.equipped_weapon)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			continue
		var w: WeaponData = entry.get("data") as WeaponData
		if w != null:
			all_weapons.append(w)
	for w: WeaponData in all_weapons:
		var avg := _parse_formula_for_avg(w.damage_formula_1)
		if w.is_ranged:
			best_ranged_dps = maxf(best_ranged_dps, avg * ranged_acc)
		elif w.is_throwable and not w.is_ranged:
			var thrown_acc := WeaponEvaluator.compute_thrown_accuracy(merc, w)
			best_ranged_dps = maxf(best_ranged_dps, avg * thrown_acc)
			best_melee_dps = maxf(best_melee_dps, avg * melee_acc)
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


static func _weapon_damage_label(wp: WeaponData, merc: MercenaryData) -> String:
	if wp == null:
		return "none"
	var stat: String
	if wp.has_heavy and not wp.has_light:
		stat = "VGR(%d)" % int(merc.stats.get("vigor", 0))
	elif wp.has_light and not wp.has_heavy:
		stat = "DEX(%d)" % int(merc.stats.get("dexterity", 0))
	else:
		stat = "DEX(%d)/VGR(%d)" % [int(merc.stats.get("dexterity", 0)), int(merc.stats.get("vigor", 0))]
	return stat if wp.damage_formula_1.is_empty() else stat + " + " + wp.damage_formula_1


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
		current_score = WeaponEvaluator.score_weapon(merc.equipped_weapon, merc, enemies, state)

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
			if score < current_score:
				continue
			if score <= best_score:
				continue
			var best_inv := WeaponEvaluator._best_available_weapon(merc, enemies, state)
			var inv_score := WeaponEvaluator.score_weapon(best_inv, merc, enemies, state) if best_inv != null else -9999.0
			if score < inv_score:
				continue
			var ap_after := (merc.current_ap + merc.excess_ap) - cost
			if ap_after < attack_base_cost and score < 0.0:
				continue
			best_score = score
			best_entry = entry
		if not best_entry.is_empty():
			return {"type": "pickup", "action_name": "PickUp", "target": null, "weapon": null,
					"weapon_entry": best_entry, "weapon_pos": merc_pos}
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP AT-POS SKIP: %s  -  %d weapon(s) at pos, none passed gates (current=%.2f)" % [
				merc.merc_name, at_pos.size(), current_score])

	var best_on_hand := WeaponEvaluator._best_available_weapon(merc, enemies, state)
	var on_hand_score := WeaponEvaluator.score_weapon(best_on_hand, merc, enemies, state) if best_on_hand != null else -9999.0

	if state.battlefield == null or state.dropped_weapons.is_empty():
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  no dropped weapons on battlefield" % merc.merc_name)
		return no_action

	var pace := int(merc.stats.get("pace", 1))
	var move_cost := state.get_cost(merc, "Move Close", move_base_cost)
	if not state.can_afford(merc, move_cost):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  can't afford move (ap=%d+%d cost=%d)" % [
				merc.merc_name, merc.current_ap, merc.excess_ap, move_cost])
		return no_action

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("PICKUP EVAL: %s  -  on_hand=%.2f, scanning %d drop location(s) within pace=%d" % [
			merc.merc_name, on_hand_score, state.dropped_weapons.size(), pace])

	var best_wp_entry: Dictionary = {}
	var best_wp_pos := Vector2i(-1, -1)
	var best_wp_score := -9999.0
	var _blocked_pu: Vector2i = merc.active_states.get("blocked_pickup_pos", Vector2i(-1, -1)) as Vector2i
	for pos: Vector2i in state.dropped_weapons.keys():
		var dist := maxi(abs(pos.x - merc_pos.x), abs(pos.y - merc_pos.y))
		if dist > pace or dist == 0:
			continue
		if pos == _blocked_pu:
			continue
		var enemies_adj := 0
		for enemy: MercenaryData in enemies:
			var ep := state.get_position(enemy)
			if maxi(abs(pos.x - ep.x), abs(pos.y - ep.y)) <= 1:
				enemies_adj += 1
		if enemies_adj > 1:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  skip pos %s: %d enemies adjacent (too dangerous)" % [str(pos), enemies_adj])
			continue
		var bfw_pos: Vector2i = merc.active_states.get("bfw_drop_pos", Vector2i(-1, -1))
		var tgt_pos: Vector2i = merc.active_states.get("target_weapon_pos", Vector2i(-1, -1))
		for entry: Dictionary in state.dropped_weapons[pos]:
			var w: WeaponData = entry.get("weapon") as WeaponData
			var w_name: String = w.item_name if w != null else "?"
			var score := _score_weapon_at_pos(entry, pos, merc, enemies, state)
			if pos == bfw_pos:
				score += 2.0
			if pos == tgt_pos:
				score += 1.0
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  dropped '%s' at %s (dist=%d) score=%.2f" % [w_name, str(pos), dist, score])
			if score > best_wp_score:
				best_wp_score = score
				best_wp_entry = entry
				best_wp_pos = pos

	if best_wp_entry.is_empty():
		return no_action
	if best_wp_score <= on_hand_score + 0.5:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  score=%.2f below threshold (on_hand=%.2f+0.5)" % [
				merc.merc_name, best_wp_score, on_hand_score])
		return no_action
	var dist_to_wp := maxi(abs(best_wp_pos.x - merc_pos.x), abs(best_wp_pos.y - merc_pos.y))
	if dist_to_wp == 0:
		var _pw0: WeaponData = best_wp_entry.get("weapon") as WeaponData
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP: %s -> '%s' at %s (score=%.2f, at-pos)" % [
				merc.merc_name, _pw0.item_name if _pw0 != null else "?", str(best_wp_pos), best_wp_score])
		return {"type": "pickup", "action_name": "PickUp", "target": null, "weapon": null,
				"weapon_entry": best_wp_entry, "weapon_pos": best_wp_pos}
	if not enemies.is_empty():
		var _nearest_d := 999999
		var _nearest_ep := Vector2i(-1, -1)
		for _ne: MercenaryData in enemies:
			var _ep := state.get_position(_ne)
			var _d := maxi(absi(merc_pos.x - _ep.x), absi(merc_pos.y - _ep.y))
			if _d < _nearest_d:
				_nearest_d = _d
				_nearest_ep = _ep
		if _nearest_ep != Vector2i(-1, -1):
			var _wp_to_enemy := maxi(absi(best_wp_pos.x - _nearest_ep.x), absi(best_wp_pos.y - _nearest_ep.y))
			var _detour := maxi(0, dist_to_wp + _wp_to_enemy - _nearest_d)
			var _max_detour := maxi(1, int(best_wp_score - on_hand_score))
			if _detour > _max_detour:
				if EncounterLogger.is_active():
					var _wn: String = (best_wp_entry.get("weapon") as WeaponData).item_name \
						if best_wp_entry.get("weapon") != null else "?"
					EncounterLogger.log_verbose("PICKUP SKIP: %s  -  '%s' at %s detour=%d > max=%d (improvement=%.1f)" % [
						merc.merc_name, _wn, str(best_wp_pos), _detour, _max_detour, best_wp_score - on_hand_score])
				return no_action
	var _pw: WeaponData = best_wp_entry.get("weapon") as WeaponData
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("PICKUP: %s -> '%s' at %s (score=%.2f)" % [
			merc.merc_name, _pw.item_name if _pw != null else "?", str(best_wp_pos), best_wp_score])
	merc.active_states["target_weapon_pos"] = best_wp_pos
	return {"type": "move_to_pickup", "action_name": "Move Close", "target": null, "weapon": null,
			"weapon_entry": best_wp_entry, "weapon_pos": best_wp_pos}


static func _decide_break_for_weapon(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		attack_base_cost: int,
		move_base_cost: int = 1) -> Dictionary:
	var no_action := {"type": "none", "action_name": "", "target": null}

	for w: WeaponData in _get_available_weapons(merc):
		if w == DataManager.fight_weapon:
			continue
		if not w.is_ranged or w.is_throwable:
			return no_action

	if state.battlefield == null or state.battlefield.droppable_obs_map.is_empty():
		return no_action

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("BFW_CALL: %s" % merc.merc_name)

	var best_on_hand := WeaponEvaluator._best_available_weapon(merc, enemies, state)
	var on_hand_score := WeaponEvaluator.score_weapon(best_on_hand, merc, enemies, state) \
			if best_on_hand != null else -9999.0

	var merc_pos := state.get_position(merc)
	var viable_obs: Array[Dictionary] = []
	for _dx: int in [-1, 0, 1]:
		for _dy: int in [-1, 0, 1]:
			if _dx == 0 and _dy == 0:
				continue
			var _np := merc_pos + Vector2i(_dx, _dy)
			if not state.battlefield.droppable_obs_map.has(_np):
				continue
			var _ao: Dictionary = state.battlefield.get_obstacle_at(_np)
			if _ao.is_empty() or _ao.get("current_hp", 1) <= 0:
				continue
			viable_obs.append(_ao)

	if not viable_obs.is_empty():
		var atk_cost := state.get_cost(merc, "attack_obstacle", attack_base_cost)
		if not state.can_afford(merc, atk_cost):
			viable_obs.clear()

	if not viable_obs.is_empty():
		if EncounterLogger.is_active():
			var _wn: String = merc.equipped_weapon.item_name if merc.equipped_weapon != null else "none"
			EncounterLogger.log_verbose("BREAK_FOR_WEAPON EVAL: %s  -  on_hand=%.2f, %d obstacle(s), weapon=%s[%s]" % [
				merc.merc_name, on_hand_score, viable_obs.size(), _wn,
				_weapon_damage_label(merc.equipped_weapon, merc)])

	for obs: Dictionary in viable_obs:
		var d: ObstacleData = obs.get("data") as ObstacleData
		var best_drop_score := -9999.0
		var best_drop_name := ""
		for drop_name: String in d.drops:
			var tmpl: WeaponData = DataManager.makeshift_weapons.get(drop_name) as WeaponData
			if tmpl == null:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("  %s: drop '%s' not found in makeshift_weapons dict" % [d.obstacle_name, drop_name])
				continue
			if tmpl.has_heavy and not tmpl.has_light:
				if int(merc.stats.get("vigor", 0)) < 2:
					if EncounterLogger.is_active():
						EncounterLogger.log_verbose("  %s: drop '%s' skipped (vigor too low)" % [d.obstacle_name, drop_name])
					continue
			var s := WeaponEvaluator.score_weapon(tmpl, merc, enemies, state, false, 1)
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s: drop '%s' score=%.2f" % [d.obstacle_name, drop_name, s])
			if s > best_drop_score:
				best_drop_score = s
				best_drop_name = drop_name

		var threshold := on_hand_score + 0.75
		if best_drop_score < threshold:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s REJECTED: best_drop=%.2f < threshold=%.2f (on_hand=%.2f + 0.75)" % [
					d.obstacle_name, best_drop_score, threshold, on_hand_score])
			continue

		var hp_current: int = obs.get("current_hp", ObstacleUtils.get_hp(d))
		var acc: float = clampf(float(merc.stats.get("melee_accuracy", 50)) / 100.0, 0.05, 1.0)
		var wp: WeaponData = merc.equipped_weapon
		if wp != null and wp.damage_formula_1.is_empty():
			continue
		var dmg_avg := maxf(1.0, _parse_formula_for_avg(wp.damage_formula_1) if wp != null else 1.0)
		var rounds_needed := ceili(float(hp_current) / maxf(1.0, acc * dmg_avg))
		if rounds_needed > 3:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s REJECTED: rounds_needed=%d > 3 (hp=%d, acc=%.0f%%, avg_dmg=%.1f)" % [
					d.obstacle_name, rounds_needed, hp_current, acc * 100.0, dmg_avg])
			continue

		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("BREAK_FOR_WEAPON: %s -> %s (rounds=%d, '%s' score=%.2f, on_hand=%.2f)" % [
				merc.merc_name, d.obstacle_name, rounds_needed, best_drop_name, best_drop_score, on_hand_score])
		return {"type": "special", "action_name": "attack_obstacle", "target": null}

	# --- Search for nearby obstacles worth approaching ---
	var move_cost_check := state.get_cost(merc, "Move Close", move_base_cost)
	if not state.can_afford(merc, move_cost_check):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("BFW_SEARCH_SKIP: %s can't afford move (ap=%d+%d cost=%d)" % [
				merc.merc_name, merc.current_ap, merc.excess_ap, move_cost_check])
		return no_action

	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var search_radius := mini(12, pace * 4)
	var merc_acc: float = clampf(float(merc.stats.get("melee_accuracy", 50)) / 100.0, 0.05, 1.0)
	var merc_wp: WeaponData = merc.equipped_weapon
	if merc_wp != null and merc_wp.damage_formula_1.is_empty():
		return no_action
	var merc_dmg_avg := maxf(1.0, _parse_formula_for_avg(merc_wp.damage_formula_1) if merc_wp != null else 1.0)

	var template_info: Dictionary = {}
	for p_s: Vector2i in state.battlefield.droppable_obs_map.keys():
		var obs_s: Dictionary = state.battlefield.get_obstacle_at(p_s)
		if obs_s.is_empty() or obs_s.get("current_hp", 1) <= 0:
			continue
		var dist_s := maxi(abs(p_s.x - merc_pos.x), abs(p_s.y - merc_pos.y))
		if dist_s <= 1 or dist_s > search_radius:
			continue
		var d_s: ObstacleData = obs_s.get("data") as ObstacleData
		if d_s == null:
			continue
		if not template_info.has(d_s) or dist_s < int(template_info[d_s]["dist"]):
			template_info[d_s] = {"pos": p_s, "dist": dist_s, "obs": obs_s}

	if template_info.is_empty():
		return no_action

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("BREAK_FOR_WEAPON SEARCH: %s  -  %d type(s) within radius=%d, on_hand=%.2f" % [
			merc.merc_name, template_info.size(), search_radius, on_hand_score])

	var nearest_enemy_dist := 999999
	var nearest_enemy_pos := Vector2i(-1, -1)
	for _ne: MercenaryData in enemies:
		var _ep := state.get_position(_ne)
		var _d := maxi(abs(_ep.x - merc_pos.x), abs(_ep.y - merc_pos.y))
		if _d < nearest_enemy_dist:
			nearest_enemy_dist = _d
			nearest_enemy_pos = _ep

	if nearest_enemy_dist <= pace - 1:
		return no_action

	var best_move_pos := Vector2i(-1, -1)
	var best_move_score := -9999.0
	var best_move_obs_name := ""
	var best_move_drop_name := ""
	var best_move_turns := 0

	for d_t: ObstacleData in template_info.keys():
		var info: Dictionary = template_info[d_t]
		var p_t: Vector2i = info["pos"]
		var dist_t: int = info["dist"]
		var obs_t: Dictionary = info["obs"]

		var best_drop_score_t := -9999.0
		var best_drop_name_t := ""
		for drop_name_t: String in d_t.drops:
			var tmpl_t: WeaponData = DataManager.makeshift_weapons.get(drop_name_t) as WeaponData
			if tmpl_t == null:
				continue
			if tmpl_t.has_heavy and not tmpl_t.has_light:
				if int(merc.stats.get("vigor", 0)) < 2:
					continue
			var s_t := WeaponEvaluator.score_weapon(tmpl_t, merc, enemies, state)
			if s_t > best_drop_score_t:
				best_drop_score_t = s_t
				best_drop_name_t = drop_name_t

		if best_drop_score_t < on_hand_score + 2.5:
			continue

		var turns_to_reach_t := ceili(float(dist_t - 1) / float(pace))
		var hp_t: int = obs_t.get("current_hp", ObstacleUtils.get_hp(d_t))
		var turns_to_destroy_t := ceili(float(hp_t) / maxf(1.0, merc_acc * merc_dmg_avg))

		var score_gap_t := best_drop_score_t - on_hand_score
		# Opportunity cost: how many extra turns does this detour add vs heading straight to the enemy?
		var dist_obs_to_enemy_t := nearest_enemy_dist
		if nearest_enemy_pos.x >= 0:
			dist_obs_to_enemy_t = maxi(abs(p_t.x - nearest_enemy_pos.x), abs(p_t.y - nearest_enemy_pos.y))
		var direct_turns_t := ceili(float(maxi(0, nearest_enemy_dist - 1)) / float(pace))
		var turns_via_obs_t := turns_to_reach_t + turns_to_destroy_t \
				+ ceili(float(maxi(0, dist_obs_to_enemy_t - 1)) / float(pace))
		var extra_turns_t := maxi(0, turns_via_obs_t - direct_turns_t)
		var max_extra_turns_t := clampi(roundi(score_gap_t * 1.5), 0, 3)

		# Direction bonus: prefer obstacles that are on or near the path to the enemy.
		var dir_bonus_t := 0.5 if (nearest_enemy_pos.x >= 0 and dist_obs_to_enemy_t < nearest_enemy_dist) else 0.0
		# Efficiency bonus: reward coming in well under the opportunity budget.
		var eff_bonus_t := float(maxi(0, max_extra_turns_t - extra_turns_t)) * 0.15
		var effective_score_t := best_drop_score_t + dir_bonus_t + eff_bonus_t

		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("  [approach] %s dist=%d: '%s' score=%.2f gap=%.2f dir=+%.1f extra=%d/max=%d" % [
				d_t.obstacle_name, dist_t, best_drop_name_t, best_drop_score_t,
				score_gap_t, dir_bonus_t, extra_turns_t, max_extra_turns_t])

		if extra_turns_t > max_extra_turns_t:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  [approach] %s REJECTED: extra_turns=%d > max=%d (gap=%.2f)" % [
					d_t.obstacle_name, extra_turns_t, max_extra_turns_t, score_gap_t])
			continue

		if effective_score_t > best_move_score:
			best_move_score = effective_score_t
			best_move_pos = p_t
			best_move_obs_name = d_t.obstacle_name
			best_move_drop_name = best_drop_name_t
			best_move_turns = extra_turns_t

	if best_move_pos != Vector2i(-1, -1):
		var adj_passable := PathHelper.nearest_passable_to(best_move_pos, state.battlefield)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("BREAK_FOR_WEAPON (approach): %s -> %s at %s adj=%s ('%s' score=%.2f, +%d extra turns, on_hand=%.2f)" % [
				merc.merc_name, best_move_obs_name, str(best_move_pos), str(adj_passable),
				best_move_drop_name, best_move_score, best_move_turns, on_hand_score])
		return {"type": "move_to_obstacle", "action_name": "Move Close", "target": null,
				"obstacle_pos": adj_passable}

	return no_action


static func decide_obstacle_or_flank(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_attack_targets: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool = false) -> Dictionary:
	var attack_obs_result := {"type": "special", "action_name": "attack_obstacle", "target": null}

	if not valid_attack_targets.is_empty():
		var wp := merc.equipped_weapon
		var melee_reach := 1
		if wp != null and not wp.is_ranged and not wp.is_throwable:
			melee_reach = wp.melee_range
		for vt: MercenaryData in valid_attack_targets:
			if state.distance_to(merc, vt) <= melee_reach:
				return {"type": "attack", "action_name": "Attack",
						"target": TargetSelector.pick_target(merc, valid_attack_targets, state)}

	if state.battlefield == null:
		return attack_obs_result
	var merc_pos := state.get_position(merc)
	var blocking_obs: Dictionary = {}
	for obs: Dictionary in state.battlefield.get_adjacent_obstacles(merc_pos):
		if obs.get("cell_type", "") == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.passthrough or d.ramp or d.health == 0:
			continue
		blocking_obs = obs
		break
	if blocking_obs.is_empty():
		return {"type": "pass", "action_name": "", "target": null}

	var obs_data: ObstacleData = blocking_obs.get("data") as ObstacleData
	var obs_hp: int
	if obs_data != null and obs_data.health > 1:
		obs_hp = obs_data.health
	elif obs_data != null and (obs_data.is_building or obs_data.obstacle_type == "Structure"):
		obs_hp = 20
	elif obs_data != null:
		obs_hp = ObstacleUtils.get_hp(obs_data)
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

	var nearest_enemy: MercenaryData = null
	var nearest_dist := 999999
	for e: MercenaryData in enemies:
		var d := state.distance_to(merc, e)
		if d < nearest_dist:
			nearest_dist = d
			nearest_enemy = e
	var flank_cell := Vector2i(-1, -1)
	if nearest_enemy != null:
		flank_cell = MovementDecider.find_flanking_cell(merc, nearest_enemy, state)
	if flank_cell == Vector2i(-1, -1):
		if rounds_to_destroy <= 3:
			EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, no flank -> destroy (quick)" % rounds_to_destroy)
			return attack_obs_result
		EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, no flank, too slow -> pass" % rounds_to_destroy)
		return {"type": "pass", "action_name": "", "target": null}
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var flank_dist := maxi(abs(flank_cell.x - merc_pos.x), abs(flank_cell.y - merc_pos.y))
	var rounds_to_flank := ceili(float(flank_dist) / float(pace))

	if rounds_to_destroy * 2 < rounds_to_flank:
		EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, flank~%d rounds -> destroy (much faster)" % [rounds_to_destroy, rounds_to_flank])
		return attack_obs_result
	if movement_blocked:
		if rounds_to_destroy <= 5:
			EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, movement blocked -> destroy" % rounds_to_destroy)
			return attack_obs_result
		EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, movement blocked, too slow -> pass" % rounds_to_destroy)
		return {"type": "pass", "action_name": "", "target": null}
	EncounterLogger.log_verbose("  obstacle choice: destroy~%d rounds, flank~%d rounds -> flank" % [rounds_to_destroy, rounds_to_flank])
	return {"type": "move", "action_name": "Move Close",
			"target": nearest_enemy, "flank_ally": null}
