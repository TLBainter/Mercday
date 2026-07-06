class_name WeaponEvaluator


static func compute_thrown_accuracy(merc: MercenaryData, weapon: WeaponData) -> float:
	# thrown_accuracy stat = max(melee_acc, ranged_acc) + merc_size*10 + any stat bonus
	return float(merc.stats.get("thrown_accuracy", 0.0)) - float(weapon.size * 10)


static func compute_thrown_range(merc: MercenaryData, weapon: WeaponData) -> int:
	# thrown_range stat is baseline with object_weight=0: vigor*20 + any stat bonus
	# for weighted objects, adjust from that baseline back to (vigor-weight)*10 + bonus
	var vigor: int = int(merc.stats.get("vigor", 0))
	var stat_base: int = int(merc.stats.get("thrown_range", vigor * 20))
	var bonus: int = stat_base - vigor * 20
	var effective_weight: int = weapon.weight
	if effective_weight == 0 and weapon.base_weapon != null:
		effective_weight = weapon.base_weapon.weight
	if effective_weight > 0:
		return maxi(0, (vigor - effective_weight) * 10 + bonus)
	return maxi(0, stat_base)


static func select_attack_stat(weapon: WeaponData) -> Array[String]:
	if weapon.has_heavy and not weapon.has_light:
		return ["vigor"]
	if weapon.has_light and not weapon.has_heavy:
		return ["dexterity"]
	return ["dexterity", "vigor"]


static func score_weapon(
		weapon: WeaponData,
		merc: MercenaryData,
		enemies: Array,
		state: BattleState,
		movement_blocked: bool = false,
		force_closest_dist: int = -1) -> float:
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
	if force_closest_dist >= 0:
		closest_dist = force_closest_dist
	else:
		for enemy: MercenaryData in enemies:
			var d := state.distance_to(merc, enemy)
			if d < closest_dist:
				closest_dist = d

	var score := 0.0
	var damage_fragility_handled := false
	if closest_dist <= 2:
		if not weapon.is_ranged:
			var avg_dmg := _parse_formula_for_avg(weapon.damage_formula_1)
			if avg_dmg > 0.0 and float(merc.stats.get("melee_accuracy", 0.0)) >= 1.0:
				score += 2.0
			if avg_dmg > 0.0:
				var acc := clampf(float(merc.stats.get("melee_accuracy", 50.0)) / 100.0, 0.01, 1.0)
				var max_dmg := avg_dmg * 2.0
				var weighted_per_use := 0.85 * (acc * avg_dmg) + 0.15 * max_dmg
				var uses := 6.0 if weapon.fragility <= 0 \
						else clampf(float(weapon.current_fragility), 1.0, 6.0)
				score += clampf(weighted_per_use * uses / 2.5, 0.0, 2.0)
				damage_fragility_handled = true
		else:
			score -= 0.5
	else:
		if weapon.is_ranged:
			var in_range := 0
			var in_intended := 0
			for enemy: MercenaryData in enemies:
				var d := state.distance_to(merc, enemy)
				if weapon.ranged_extended_range <= 0 or d <= weapon.ranged_extended_range:
					in_range += 1
				if weapon.ranged_intended_range <= 0 or d <= weapon.ranged_intended_range:
					in_intended += 1
			var ranged_avg_dmg := _parse_formula_for_avg(weapon.damage_formula_1)
			var dmg_factor := clampf(ranged_avg_dmg / 7.0, 0.1, 2.0)
			score += 1.5 * float(in_range) * dmg_factor
			var melee_acc_r := maxf(1.0, float(merc.stats.get("melee_accuracy", 50.0)))
			var ranged_acc_r := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
			score *= clampf(ranged_acc_r / melee_acc_r, 0.1, 2.0)
			score -= 0.4 * float(in_range - in_intended)
			if weapon.misfire > 0:
				var misfire_risk: float = clampf(float(weapon.misfire) * 0.35, 0.0, 2.5)
				var accuracy_factor: float = clampf(1.0 - ranged_acc_r / 100.0, 0.0, 1.0)
				score -= misfire_risk * (0.3 + accuracy_factor * 0.7)
		elif weapon.is_throwable:
			var merc_thrown_range := compute_thrown_range(merc, weapon)
			if merc_thrown_range <= 0 and weapon.weight > 0:
				damage_fragility_handled = true
			else:
				var throw_avg := _parse_formula_for_avg(weapon.damage_formula_1)
				var throw_acc := clampf(compute_thrown_accuracy(merc, weapon) / 100.0, 0.01, 1.0)
				var weighted_throw := 0.85 * (throw_acc * throw_avg) + 0.15 * (throw_avg * 2.0)
				var throw_uses := 6.0 if weapon.fragility <= 0 \
						else clampf(float(weapon.current_fragility), 1.0, 6.0)
				var throw_dmg_score: float = clampf(weighted_throw * throw_uses / 2.5, 0.0, 2.0) \
						* _throw_replacement_factor(merc, weapon, state)
				var has_designed_range: bool = weapon.range_thrown != ""
				var ext_range: int
				var int_range: int
				if has_designed_range:
					ext_range = mini(weapon.thrown_extended_range, merc_thrown_range) if weapon.thrown_extended_range > 0 else merc_thrown_range
					int_range = mini(weapon.thrown_intended_range, merc_thrown_range) if weapon.thrown_intended_range > 0 else ext_range
				else:
					ext_range = int(merc_thrown_range / 2.0)
					int_range = 0
				for enemy: MercenaryData in enemies:
					var d := state.distance_to(merc, enemy)
					if d > ext_range:
						continue
					var range_factor: float
					if not has_designed_range:
						range_factor = 0.4
					elif d <= int_range:
						range_factor = 1.0
					else:
						range_factor = clampf(1.0 - 0.6 * float(d - int_range) / maxf(1.0, float(ext_range - int_range)), 0.4, 1.0)
					score += throw_dmg_score * range_factor
				damage_fragility_handled = true
		else:
			var pace := maxf(1.0, float(merc.stats.get("pace", 1)))
			var turns_to_close := float(closest_dist) / pace
			if movement_blocked:
				turns_to_close *= 3.0
			var dist_factor := clampf((turns_to_close - 1.0) / 4.0, 0.0, 2.0)
			var melee_acc := maxf(1.0, float(merc.stats.get("melee_accuracy", 50.0)))
			var ranged_acc := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
			var ranged_aptitude := clampf(ranged_acc / melee_acc, 0.0, 3.0)
			score -= dist_factor * ranged_aptitude
			var melee_preference := clampf(1.0 - ranged_aptitude, 0.0, 1.0)
			var reachability := clampf(1.0 - (turns_to_close - 1.0) / 5.0, 0.0, 1.0)
			score += melee_preference * reachability * 2.0
			var melee_avg_dmg := _parse_formula_for_avg(weapon.damage_formula_1)
			var best_ranged_avg := 0.0
			for w: WeaponData in _get_available_weapons(merc):
				if w.is_ranged:
					best_ranged_avg = maxf(best_ranged_avg, _parse_formula_for_avg(w.damage_formula_1))
			if melee_avg_dmg > 0.0 or best_ranged_avg > 0.0:
				var dmg_ratio := (melee_avg_dmg - best_ranged_avg) / maxf(1.0, melee_avg_dmg + best_ranged_avg)
				score += clampf(dmg_ratio * 1.5, -0.5, 1.5) * reachability
	var all_types: Array = weapon.damage_types_1.duplicate()
	all_types.append_array(weapon.damage_types_2)
	if not all_types.is_empty() and not enemies.is_empty():
		var type_total := 0.0
		for enemy: MercenaryData in enemies:
			type_total += TargetSelector.score_type_vs_enemy(all_types, enemy)
		score += type_total / float(enemies.size())

	if not damage_fragility_handled and weapon.fragility > 0 and weapon.current_fragility > 0:
		var frag_ratio := float(weapon.current_fragility) / float(weapon.fragility)
		score += frag_ratio * 0.5

	return score


static func decide_action(
		merc: MercenaryData,
		state: BattleState,
		ctx: Dictionary) -> Dictionary:
	var enemies: Array = ctx.get("enemies", [])
	var attack_base_cost: int = ctx.get("attack_base_ap", 3)
	var movement_blocked: bool = ctx.get("movement_blocked", false)
	return _decide_weapon_action(merc, enemies, state, attack_base_cost, movement_blocked)


static func _decide_weapon_action(
		merc: MercenaryData,
		enemies: Array,
		state: BattleState,
		attack_base_cost: int,
		movement_blocked: bool = false) -> Dictionary:
	var no_action := {"type": "none", "action_name": "", "target": null, "weapon": null}

	if merc.equipped_weapon == null or not merc.weapon_drawn:
		var draw_target := _best_available_weapon(merc, enemies, state, movement_blocked)
		if draw_target == null:
			return no_action
		var draw_cost := state.get_cost(merc, "Draw", draw_target.draw)
		if not state.can_afford(merc, draw_cost):
			return no_action
		if _should_draw_now_vs_move(merc, enemies, draw_target, draw_cost, state, attack_base_cost):
			return {"type": "draw", "action_name": "Draw", "target": null, "weapon": draw_target}
		return no_action

	if merc.inventory.is_empty():
		return no_action
	var has_inv_weapon := false
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			has_inv_weapon = true
			break
	if not has_inv_weapon:
		return no_action

	var current_score := score_weapon(merc.equipped_weapon, merc, enemies, state, movement_blocked)
	if current_score >= 0.0:
		return no_action
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

	if _should_holster_vs_drop(merc, merc.equipped_weapon, enemies):
		var holster_cost := state.get_cost(merc, "Holster", merc.equipped_weapon.draw)
		var total_ap := merc.current_ap + merc.excess_ap
		if state.can_afford(merc, holster_cost) and total_ap - holster_cost - best.draw >= attack_base_cost:
			return {"type": "holster", "action_name": "Holster", "target": null, "weapon": null}
		if state.can_afford(merc, best.draw):
			return {"type": "drop", "action_name": "Drop", "target": null, "weapon": null,
					"cause": "swapped for %s" % best.item_name, "swap_weapon": best}

	if state.can_afford(merc, best.draw):
		return {"type": "drop", "action_name": "Drop", "target": null, "weapon": null,
				"cause": "ammo exhausted", "swap_weapon": best}

	return no_action


static func _best_available_weapon(
		merc: MercenaryData,
		enemies: Array,
		state: BattleState,
		movement_blocked: bool = false) -> WeaponData:
	var available := _get_available_weapons(merc)
	if available.is_empty():
		return null
	var best: WeaponData = null
	var best_score := -9999.0
	for weapon: WeaponData in available:
		var s := score_weapon(weapon, merc, enemies, state, movement_blocked)
		if s > best_score:
			best_score = s
			best = weapon
	return best


static func _should_draw_now_vs_move(
		merc: MercenaryData,
		enemies: Array,
		weapon: WeaponData,
		draw_cost: int,
		state: BattleState,
		attack_base_cost: int) -> bool:
	var ap_after_draw := (merc.current_ap + merc.excess_ap) - draw_cost
	if ap_after_draw >= attack_base_cost:
		return true
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
			return false
	return true


static func _should_holster_vs_drop(
		merc: MercenaryData,
		current_weapon: WeaponData,
		enemies: Array) -> bool:
	if current_weapon.is_ranged and merc.ammo_loaded <= 0:
		var has_reserve := false
		for count: int in merc.ammo_inventory.values():
			if count > 0:
				has_reserve = true
				break
		if not has_reserve:
			return false
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
		return true
	if not current_weapon.is_ranged and not other_melee:
		return true
	return true


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


static func _has_ranged_enemy(enemies: Array) -> bool:
	for enemy: MercenaryData in enemies:
		if enemy.equipped_weapon != null and enemy.equipped_weapon.is_ranged:
			return true
	return false


static func _throw_replacement_factor(merc: MercenaryData, weapon: WeaponData, state: BattleState) -> float:
	var fight := DataManager.fight_weapon
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			var w: WeaponData = entry.get("data") as WeaponData
			if w != null and w != weapon and w != fight:
				return 1.0
	if merc.equipped_weapon != null and merc.equipped_weapon != weapon and merc.equipped_weapon != fight:
		return 1.0
	if state.battlefield == null:
		return 0.25
	var merc_pos := state.get_position(merc)
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	for pos: Vector2i in state.dropped_weapons.keys():
		if maxi(abs(pos.x - merc_pos.x), abs(pos.y - merc_pos.y)) <= pace * 2:
			return 0.6
	for obs: Dictionary in state.battlefield.obstacles:
		if obs.get("cell_type", "") == "wall":
			continue
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d == null or d.health == 0 or d.drops.is_empty():
			continue
		var _raw_wep = obs.get("pos", Vector2i(-1, -1))
		var p: Vector2i = Vector2i((_raw_wep as Vector3i).x, (_raw_wep as Vector3i).y) if typeof(_raw_wep) == TYPE_VECTOR3I else _raw_wep as Vector2i
		if p.x < 0:
			continue
		if maxi(abs(p.x - merc_pos.x), abs(p.y - merc_pos.y)) <= 6:
			return 0.4
	return 0.25


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
