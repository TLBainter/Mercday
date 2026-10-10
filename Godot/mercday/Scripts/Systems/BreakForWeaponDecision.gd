class_name BreakForWeaponDecision


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


static func decide_break_for_weapon(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		attack_base_cost: int,
		move_base_cost: int = 1) -> Dictionary:
	var no_action := {"type": "none", "action_name": "", "target": null}

	for w: WeaponData in WeaponEvaluator.get_available_weapons(merc):
		if w == DataManager.fight_weapon:
			continue
		if not w.is_ranged or w.is_throwable:
			return no_action

	if state.battlefield == null or state.battlefield.droppable_obs_map.is_empty():
		return no_action

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("BFW_CALL: %s" % merc.merc_name)

	var on_hand_score := WeaponEvaluator.best_on_hand_score(merc, enemies, state)

	var merc_pos := state.get_position(merc)
	var merc_floor := state.get_floor(merc)
	var viable_obs: Array[Dictionary] = _bfw_adjacent_obstacles(merc, state, merc_pos, merc_floor, attack_base_cost)

	if not viable_obs.is_empty():
		if EncounterLogger.is_active():
			var wn: String = merc.equipped_weapon.item_name if merc.equipped_weapon != null else "none"
			EncounterLogger.log_verbose("BREAK_FOR_WEAPON EVAL: %s  -  on_hand=%.2f, %d obstacle(s), weapon=%s[%s]" % [
				merc.merc_name, on_hand_score, viable_obs.size(), wn,
				_weapon_damage_label(merc.equipped_weapon, merc)])

	if _bfw_adjacent_choice(merc, enemies, state, viable_obs, on_hand_score):
		return {"type": "special", "action_name": "attack_obstacle", "target": null}

	var move_cost_check := state.move_cost(merc, "Move Close", move_base_cost)
	if not state.can_afford(merc, move_cost_check):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("BFW_SEARCH_SKIP: %s can't afford move (ap=%d+%d cost=%d)" % [
				merc.merc_name, merc.current_ap, merc.excess_ap, move_cost_check])
		return no_action

	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	var search_radius := mini(12, pace * 4)
	var merc_wp: WeaponData = merc.equipped_weapon
	if merc_wp != null and merc_wp.damage_formula_1.is_empty():
		return no_action
	var hit_rate := _melee_hit_rate(merc)
	var merc_acc: float = hit_rate["acc"]
	var merc_dmg_avg: float = hit_rate["dmg_avg"]

	var template_info: Dictionary = _bfw_nearby_templates(state, merc_pos, merc_floor, search_radius)

	if template_info.is_empty():
		return no_action

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("BREAK_FOR_WEAPON SEARCH: %s  -  %d type(s) within radius=%d, on_hand=%.2f" % [
			merc.merc_name, template_info.size(), search_radius, on_hand_score])

	var near: Dictionary = MovementDecider.nearest_enemy(merc, enemies, state, -1, true)
	var nearest_enemy_dist: int = near["dist"]
	var nearest_enemy_pos := Vector2i(-1, -1)
	if near["merc"] != null:
		nearest_enemy_pos = state.get_position(near["merc"])

	if nearest_enemy_dist <= pace - 1:
		return no_action

	var appr: Dictionary = _bfw_best_approach(merc, enemies, state, template_info, on_hand_score,
		pace, merc_acc, merc_dmg_avg, nearest_enemy_dist, nearest_enemy_pos)
	var best_move_pos: Vector2i = appr["pos"] as Vector2i
	var best_move_score: float = appr["score"] as float
	var best_move_obs_name: String = appr["obs_name"] as String
	var best_move_drop_name: String = appr["drop_name"] as String
	var best_move_turns: int = appr["turns"] as int

	if best_move_pos != Vector2i(-1, -1):
		var bmp_floor := state.get_floor(merc)
		var adj3 := PathHelper.nearest_passable_to(
			Vector3i(best_move_pos.x, best_move_pos.y, bmp_floor), state.battlefield,
			{"merc_size": int(merc.stats.get("size", 1)), "state": state, "merc": merc})
		var adj_passable := Vector2i(adj3.x, adj3.y)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("BREAK_FOR_WEAPON (approach): %s -> %s at %s adj=%s ('%s' score=%.2f, +%d extra turns, on_hand=%.2f)" % [
				merc.merc_name, best_move_obs_name, str(best_move_pos), str(adj_passable),
				best_move_drop_name, best_move_score, best_move_turns, on_hand_score])
		return {"type": "move_to_obstacle", "action_name": "Move Close", "target": null,
				"obstacle_pos": adj_passable}

	return no_action


#Droppable obstacles beside the mover it can afford to strike this turn.
static func _bfw_adjacent_obstacles(merc: MercenaryData, state: BattleState, merc_pos: Vector2i,
		merc_floor: int, attack_base_cost: int) -> Array[Dictionary]:
	var viable_obs: Array[Dictionary] = []
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var np := merc_pos + Vector2i(dx, dy)
			if not state.battlefield.droppable_obs_map.has(Vector3i(np.x, np.y, merc_floor)):
				continue
			var ao: Dictionary = state.battlefield.get_obs(np, merc_floor)
			if ao.is_empty() or ao.get("current_hp", 1) <= 0 or not (ao.get("data") is ObstacleData):
				continue
			viable_obs.append(ao)

	if not viable_obs.is_empty():
		var atk_cost := state.get_cost(merc, "attack_obstacle", attack_base_cost)
		if not state.can_afford(merc, atk_cost):
			viable_obs.clear()
	return viable_obs


#Best makeshift drop of an obstacle as {"score", "name"}; melee_only scores it as a swung weapon at range 1.
static func _best_drop(d: ObstacleData, merc: MercenaryData, enemies: Array[MercenaryData],
		state: BattleState, melee_only: bool, do_log: bool) -> Dictionary:
	var best_score := -9999.0
	var best_name := ""
	for drop_name: String in d.drops:
		var tmpl: WeaponData = DataManager.makeshift_weapons.get(drop_name) as WeaponData
		if tmpl == null:
			if do_log and EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s: drop '%s' not found in makeshift_weapons dict" % [d.obstacle_name, drop_name])
			continue
		if tmpl.has_heavy and not tmpl.has_light and int(merc.stats.get("vigor", 0)) < 2:
			if do_log and EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s: drop '%s' skipped (vigor too low)" % [d.obstacle_name, drop_name])
			continue
		var s: float
		if melee_only:
			s = WeaponEvaluator.score_weapon(tmpl, merc, enemies, state, false, 1)
		else:
			s = WeaponEvaluator.score_weapon(tmpl, merc, enemies, state)
		if do_log and EncounterLogger.is_active():
			EncounterLogger.log_verbose("  %s: drop '%s' score=%.2f" % [d.obstacle_name, drop_name, s])
		if s > best_score:
			best_score = s
			best_name = drop_name
	return {"score": best_score, "name": best_name}


#Melee accuracy (0.05 to 1.0) and average damage of the held weapon as {"acc", "dmg_avg"}.
static func _melee_hit_rate(merc: MercenaryData) -> Dictionary:
	var wp: WeaponData = merc.equipped_weapon
	return {
		"acc": clampf(float(merc.stats.get("melee_accuracy", 50)) / 100.0, 0.05, 1.0),
		"dmg_avg": maxf(1.0, WeaponEvaluator.parse_formula_for_avg(wp.damage_formula_1) if wp != null else 1.0),
	}


#True when one obstacle beside the mover drops a weapon worth the rounds it takes to break.
static func _bfw_adjacent_choice(merc: MercenaryData, enemies: Array[MercenaryData],
		state: BattleState, viable_obs: Array[Dictionary], on_hand_score: float) -> bool:
	for obs: Dictionary in viable_obs:
		var d: ObstacleData = obs.get("data") as ObstacleData
		var best: Dictionary = _best_drop(d, merc, enemies, state, true, true)
		var best_drop_score: float = best["score"]
		var best_drop_name: String = best["name"]

		var threshold := on_hand_score + 0.75
		if best_drop_score < threshold:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s REJECTED: best_drop=%.2f < threshold=%.2f (on_hand=%.2f + 0.75)" % [
					d.obstacle_name, best_drop_score, threshold, on_hand_score])
			continue

		var hp_current: int = obs.get("current_hp", ObstacleUtils.get_hp(d))
		var wp: WeaponData = merc.equipped_weapon
		if wp != null and wp.damage_formula_1.is_empty():
			continue
		var hit_rate := _melee_hit_rate(merc)
		var acc: float = hit_rate["acc"]
		var dmg_avg: float = hit_rate["dmg_avg"]
		var rounds_needed := ceili(float(hp_current) / maxf(1.0, acc * dmg_avg))
		if rounds_needed > 3:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  %s REJECTED: rounds_needed=%d > 3 (hp=%d, acc=%.0f%%, avg_dmg=%.1f)" % [
					d.obstacle_name, rounds_needed, hp_current, acc * 100.0, dmg_avg])
			continue

		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("BREAK_FOR_WEAPON: %s -> %s (rounds=%d, '%s' score=%.2f, on_hand=%.2f)" % [
				merc.merc_name, d.obstacle_name, rounds_needed, best_drop_name, best_drop_score, on_hand_score])
		return true
	return false


#Nearest live droppable obstacle of each type inside the search radius, keyed by ObstacleData.
static func _bfw_nearby_templates(state: BattleState, merc_pos: Vector2i, merc_floor: int,
		search_radius: int) -> Dictionary:
	var template_info: Dictionary = {}
	for p_k: Vector3i in state.battlefield.droppable_obs_map.keys():
		if p_k.z != merc_floor:
			continue
		var p_s := Vector2i(p_k.x, p_k.y)
		var obs_s: Dictionary = state.battlefield.get_obs(p_s, merc_floor)
		if obs_s.is_empty() or obs_s.get("current_hp", 1) <= 0:
			continue
		var dist_s := Pathfinder.chebyshev2(p_s, merc_pos)
		if dist_s <= 1 or dist_s > search_radius:
			continue
		var d_s: ObstacleData = obs_s.get("data") as ObstacleData
		if d_s == null:
			continue
		if not template_info.has(d_s) or dist_s < int(template_info[d_s]["dist"]):
			template_info[d_s] = {"pos": p_s, "dist": dist_s, "obs": obs_s}
	return template_info


#Obstacle worth walking to for its drop, with the score and detour that won it.
static func _bfw_best_approach(merc: MercenaryData, enemies: Array[MercenaryData], state: BattleState,
		template_info: Dictionary, on_hand_score: float, pace: int, merc_acc: float,
		merc_dmg_avg: float, nearest_enemy_dist: int, nearest_enemy_pos: Vector2i) -> Dictionary:
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

		var best_t: Dictionary = _best_drop(d_t, merc, enemies, state, false, false)
		var best_drop_score_t: float = best_t["score"]
		var best_drop_name_t: String = best_t["name"]

		if best_drop_score_t < on_hand_score + 2.5:
			continue

		var turns_to_reach_t := ceili(float(dist_t - 1) / float(pace))
		var hp_t: int = obs_t.get("current_hp", ObstacleUtils.get_hp(d_t))
		var turns_to_destroy_t := ceili(float(hp_t) / maxf(1.0, merc_acc * merc_dmg_avg))

		var score_gap_t := best_drop_score_t - on_hand_score
		#Opportunity cost: how many extra turns does this detour add vs heading straight to the enemy?
		var dist_obs_to_enemy_t := nearest_enemy_dist
		if nearest_enemy_pos.x >= 0:
			dist_obs_to_enemy_t = Pathfinder.chebyshev2(p_t, nearest_enemy_pos)
		var direct_turns_t := ceili(float(maxi(0, nearest_enemy_dist - 1)) / float(pace))
		var turns_via_obs_t := turns_to_reach_t + turns_to_destroy_t \
				+ ceili(float(maxi(0, dist_obs_to_enemy_t - 1)) / float(pace))
		var extra_turns_t := maxi(0, turns_via_obs_t - direct_turns_t)
		var max_extra_turns_t := clampi(roundi(score_gap_t * 1.5), 0, 3)

		#Direction bonus: prefer obstacles that are on or near the path to the enemy.
		var dir_bonus_t := 0.5 if (nearest_enemy_pos.x >= 0 and dist_obs_to_enemy_t < nearest_enemy_dist) else 0.0
		#Efficiency bonus: reward coming in well under the opportunity budget.
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
	return {"pos": best_move_pos, "score": best_move_score, "obs_name": best_move_obs_name,
			"drop_name": best_move_drop_name, "turns": best_move_turns}
