class_name WeaponSwapDecider
extends RefCounted

#Picks the weapon action for a turn: attack, draw, holster, drop or a two hand grip change.


static func decide_action(
		merc: MercenaryData,
		enemies: Array,
		state: BattleState,
		attack_base_cost: int,
		movement_blocked: bool = false) -> Dictionary:
	var no_action := {"type": "none", "action_name": "", "target": null, "weapon": null}

	if merc.equipped_weapon == null or not merc.weapon_drawn:
		var draw_target := WeaponEvaluator._best_available_weapon(merc, enemies, state, movement_blocked)
		if draw_target == null:
			WeaponActionExecutor.log_draw_refusal(merc, null, "no_weapon", 0)
			return no_action
		var draw_cost := WeaponActionExecutor.get_swap_cost(merc, draw_target, state)
		if draw_cost < 0:
			WeaponActionExecutor.log_draw_refusal(merc, draw_target, "hands_full", 0, false)
			return no_action
		if not state.can_afford(merc, draw_cost):
			WeaponActionExecutor.log_draw_refusal(merc, draw_target, "ap_short", draw_cost)
			return no_action
		if draw_target.is_ranged:
			var first_plan := RangedDrawPlanner.plan(merc, draw_target, enemies, state, attack_base_cost)
			var first_move := _plan_move_decision(first_plan, movement_blocked)
			if not first_move.is_empty():
				return first_move
			if str(first_plan.get("mode", "none")) != "now":
				WeaponActionExecutor.log_draw_refusal(merc, draw_target, "no_los_plan", draw_cost, false)
				return no_action
		if _should_draw_now_vs_move(merc, enemies, draw_target, draw_cost, state, attack_base_cost):
			return {"type": "draw", "action_name": "Draw", "target": null, "weapon": draw_target}
		return no_action

	#Bare hands are always a candidate; a held weapon that scores well stays unless an enemy is within 2 paces.
	var current_score := WeaponEvaluator.score_weapon(merc.equipped_weapon, merc, enemies, state, movement_blocked)
	var enemy_close := merc.equipped_weapon.is_virtual
	for enemy: MercenaryData in enemies:
		if enemy_close:
			break
		if state.distance_to(merc, enemy) <= 2:
			enemy_close = true
	if current_score >= 0.0 and not enemy_close:
		return no_action
	var best := WeaponEvaluator._best_available_weapon(merc, enemies, state, movement_blocked)
	if best == null or best == merc.equipped_weapon:
		return no_action

	var best_can_reach := best.is_ranged
	for enemy: MercenaryData in enemies:
		if best_can_reach:
			break
		if state.distance_to(merc, enemy) <= best.melee_range:
			best_can_reach = true
	if not best_can_reach:
		return no_action

	if best.is_ranged:
		var best_plan := RangedDrawPlanner.plan(merc, best, enemies, state, attack_base_cost)
		var best_move := _plan_move_decision(best_plan, movement_blocked)
		if not best_move.is_empty():
			return best_move
		if str(best_plan.get("mode", "none")) != "now":
			WeaponActionExecutor.log_draw_refusal(merc, best, "no_los_plan", 0, false)
			return no_action

	#The off-hand weapon is already in hand, so taking it up costs nothing and stows nothing.
	if best == merc.offhand_weapon:
		return {"type": "draw", "action_name": "Draw", "target": null, "weapon": best}
	#Hands with room for both weapons make this a plain draw, unless two hands on `best` beat the pair.
	var grip_frees := WeaponActionExecutor.grip_frees_main(merc, best, enemies, state, true)
	if not WeaponActionExecutor.needs_free_hands(merc, best) and not grip_frees:
		var free_draw := state.get_cost(merc, "Draw", WeaponActionExecutor.get_draw_cost(merc, best))
		if not state.can_afford(merc, free_draw):
			WeaponActionExecutor.log_draw_refusal(merc, best, "ap_short", free_draw)
			return no_action
		return {"type": "draw", "action_name": "Draw", "target": null, "weapon": best}
	var current := merc.equipped_weapon
	var swap := should_holster_vs_drop(merc, current, best, enemies, state, attack_base_cost)
	if grip_frees and swap == "drop" and is_worth_keeping(merc, current, best, enemies, state):
		swap = "keep"
	var best_draw := state.get_cost(merc, "Draw", WeaponActionExecutor.get_draw_cost(merc, best))
	if swap == "stow":
		return {"type": "holster", "action_name": "Draw", "target": null, "weapon": null}
	if swap == "drop":
		if not state.can_afford(merc, best_draw):
			WeaponActionExecutor.log_draw_refusal(merc, best, "ap_short", best_draw)
			return no_action
		var cause := "swapped for %s" % best.item_name
		if current.is_ranged and merc.ammo_loaded <= 0 and not WeaponEvaluator._has_reserve_for(merc, current):
			cause = "ammo exhausted"
		return {"type": "drop", "action_name": "Drop", "target": null, "weapon": null,
				"cause": cause, "swap_weapon": best}
	#"keep": bare hands stow nothing, and a weapon kept for the off hand rides along at no cost.
	if current.is_virtual or grip_frees:
		if not state.can_afford(merc, best_draw):
			WeaponActionExecutor.log_draw_refusal(merc, best, "ap_short", best_draw)
			return no_action
		return {"type": "draw", "action_name": "Draw", "target": null, "weapon": best}
	WeaponActionExecutor.log_draw_refusal(merc, best, "hands_full", best_draw, false)
	return no_action


#A ranged plan that walks first becomes a Move toward the firing cell instead of a Draw.
static func _plan_move_decision(plan: Dictionary, movement_blocked: bool) -> Dictionary:
	var mode := str(plan.get("mode", "none"))
	if movement_blocked or mode == "now" or mode == "none":
		return {}
	var cell: Vector3i = plan.get("cell", RangedDrawPlanner.NO_CELL)
	var target: MercenaryData = plan.get("target")
	if target == null or cell == RangedDrawPlanner.NO_CELL:
		return {}
	var reserve := 0
	if int(plan.get("turns", 2)) <= 1:
		reserve = int(plan.get("draw_ap", 0))
		if bool(plan.get("shoots", false)):
			reserve += int(plan.get("attack_ap", 0))
	return {"type": "move", "action_name": "Move Close", "target": target, "weapon": null,
			"goal_cell": cell, "moves_allowed": maxi(1, int(plan.get("moves", 1))), "reserve_ap": reserve}


#Two hands on a flexible weapon add a damage die; the off hand keeps a second weapon only
#when that weapon is worth more than the die.
static func prefer_two_hands(
		merc: MercenaryData,
		main: WeaponData,
		candidate: WeaponData,
		enemies: Array,
		state: BattleState,
		do_log: bool = false) -> bool:
	if main == null or candidate == null or main == candidate:
		return false
	if not WeaponArmorPerkLibrary.is_flex_grip(main, merc):
		return false
	var parsed := AttackSystem._parse_damage_formula(main.damage_formula_1)
	if bool(parsed["is_todo"]):
		return false
	var acc := clampf(float(merc.stats.get("melee_accuracy", 50.0)) / 100.0, 0.01, 1.0)
	var die_value := (float(parsed["die_sides"]) + 1.0) / 2.0 * acc
	var offhand_value := WeaponEvaluator.score_weapon(candidate, merc, enemies, state, false, -1, {}, false)
	var complement := "melee"
	var hold := false
	if candidate.is_virtual:
		hold = false
	elif candidate.is_ranged and not main.is_ranged:
		hold = WeaponEvaluator.is_ranged_usable(merc, candidate)
		complement = "ranged"
	elif main.is_ranged and not candidate.is_ranged:
		hold = true
	#A Thrown-property off-hand weapon earns its place when it can answer an enemy out of melee reach.
	elif candidate.is_throwable and WeaponEvaluator._thrown_complement(merc, candidate, enemies, state):
		hold = true
		complement = "thrown"
	else:
		hold = offhand_value >= die_value
	if do_log and EncounterLogger.is_active():
		if hold:
			EncounterLogger.log_verbose("GRIP: %s holds %s in the off hand (offhand=%.2f vs die=%.1f complement=%s)" % [
				merc.merc_name, candidate.item_name, offhand_value, die_value, complement])
		else:
			EncounterLogger.log_verbose("GRIP: %s two-hands %s over holding %s (die=%.1f vs offhand=%.2f)" % [
				merc.merc_name, main.item_name, candidate.item_name, die_value, offhand_value])
	return not hold


static func _should_draw_now_vs_move(
		merc: MercenaryData,
		enemies: Array,
		weapon: WeaponData,
		draw_cost: int,
		state: BattleState,
		attack_base_cost: int) -> bool:
	if weapon.is_ranged:
		var rp := RangedDrawPlanner.plan(merc, weapon, enemies, state, attack_base_cost)
		return str(rp.get("mode", "none")) == "now"
	if state.can_afford(merc, draw_cost + attack_base_cost):
		return true
	if state.battlefield == null:
		return true
	for enemy: MercenaryData in enemies:
		var d := state.distance_to(merc, enemy)
		var in_range := d <= weapon.melee_range
		if not in_range:
			return false
	return true


#Stowing costs the weapon's Draw again, dropping is free: pick by AP left and by what the weapon is worth.
static func should_holster_vs_drop(
		merc: MercenaryData,
		current: WeaponData,
		best: WeaponData,
		enemies: Array,
		state: BattleState,
		attack_base_cost: int,
		log_decision: bool = true,
		prior_draws: int = 0) -> String:
	var ap: int = state.spendable_ap(merc)
	var stow_cost := 0
	if not current.is_virtual:
		stow_cost = state.get_cost_after(merc, "Draw", WeaponActionExecutor.get_draw_cost(merc, current), prior_draws)
	var best_base := WeaponActionExecutor.get_draw_cost(merc, best)
	var draw_cost := state.get_cost_after(merc, "Draw", best_base, prior_draws)
	#A stow is a Draw action, so the draw that follows it costs one escalation step more.
	var draw_after_stow := state.get_cost_after(merc, "Draw", best_base, prior_draws + 1)
	var attack_cost := state.get_cost(merc, "Attack", attack_base_cost)
	if current.is_virtual:
		if log_decision:
			_log_swap_decision(merc, "keep", current, best, "bare_hands", ap, stow_cost, draw_cost, attack_cost)
		return "keep"

	var worth_keeping := is_worth_keeping(merc, current, best, enemies, state)
	var result := "keep"
	var reason := "ap_too_low_to_swap"
	if worth_keeping and ap - stow_cost - draw_after_stow >= attack_cost:
		result = "stow"
		reason = "worth_keeping_ap_ok"
	elif ap - draw_cost >= attack_cost or ap < attack_cost:
		if not worth_keeping:
			result = "drop"
			reason = "not_worth_keeping"
		elif ap - stow_cost - draw_after_stow >= 0 and not WeaponEvaluator._enemy_in_melee_reach(merc, enemies, state):
			result = "stow"
			reason = "worth_keeping_ap_tight"
		else:
			result = "drop"
			reason = "worth_keeping_ap_short"
	if log_decision:
		var _shown_draw := draw_after_stow if result == "stow" else draw_cost
		_log_swap_decision(merc, result, current, best, reason, ap, stow_cost, _shown_draw, attack_cost)
	return result


static func _log_swap_decision(
		merc: MercenaryData,
		result: String,
		current: WeaponData,
		best: WeaponData,
		reason: String,
		ap: int,
		stow_cost: int,
		draw_cost: int,
		attack_cost: int) -> void:
	if not EncounterLogger.is_active():
		return
	EncounterLogger.log_verbose("SWAP DECISION: %s %s %s for %s reason=%s ap=%d stow=%d draw=%d attack=%d" % [
		merc.merc_name, result, current.item_name, best.item_name, reason,
		ap, stow_cost, draw_cost, attack_cost])


static func is_worth_keeping(
		merc: MercenaryData,
		current: WeaponData,
		best: WeaponData,
		enemies: Array,
		state: BattleState) -> bool:
	if current.is_ranged and WeaponEvaluator._has_reserve_for(merc, current):
		return true
	var rarity := current.item_rarity.strip_edges()
	if rarity != "" and rarity != "Ordinary" and rarity != "Common":
		return true
	var best_score := WeaponEvaluator.score_weapon(best, merc, enemies, state)
	return WeaponEvaluator.score_weapon(current, merc, enemies, state) >= 0.5 * best_score
