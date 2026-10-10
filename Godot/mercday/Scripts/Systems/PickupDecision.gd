class_name PickupDecision


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
		var d := Pathfinder.chebyshev2(weapon_pos, ep)
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
				var d := Pathfinder.chebyshev2(weapon_pos, ep)
				if weapon.ranged_extended_range <= 0 or d <= weapon.ranged_extended_range:
					in_range += 1
			score += 1.5 * float(in_range)
		elif weapon.is_throwable:
			for enemy: MercenaryData in enemies:
				var ep := state.get_position(enemy)
				var d := Pathfinder.chebyshev2(weapon_pos, ep)
				if weapon.thrown_extended_range <= 0 or d <= weapon.thrown_extended_range:
					score += 0.5
	return score


#Pickup score after the weight it would add, with the packed item worth shedding to soften it.
static func _burden_adjust(merc: MercenaryData, w: WeaponData, score: float) -> Dictionary:
	if w == null:
		return {"score": score, "shed": {}}
	var pb: float = LoadoutDecision.pickup_burden(merc, w)
	if pb <= 0.0:
		return {"score": score, "shed": {}}
	var carried: int = Encumbrance.carried_weight(merc)
	var limit: int = Encumbrance.weight_limit(merc)
	var wt: int = Encumbrance.weapon_weight(w)
	var penalty: float = pb * LoadoutDecision.PICKUP_BURDEN_SCALE
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("PICKUP BURDEN: %s %s wt %d would be %d/%d (score -%.2f)" % [
			merc.merc_name, w.item_name, wt, carried + wt, limit, penalty])
	var kept_score: float = score - penalty
	var shed: Dictionary = LoadoutDecision.shed_for(merc, w)
	if shed.is_empty():
		return {"score": kept_score, "shed": {}}
	var over_after: int = (carried - limit) - int(shed["weight"])
	var alt_burden: float = LoadoutDecision.burden(over_after + wt) - LoadoutDecision.burden(over_after)
	var alt_score: float = score - (alt_burden + float(shed["value"])) * LoadoutDecision.PICKUP_BURDEN_SCALE
	if alt_score <= kept_score:
		return {"score": kept_score, "shed": {}}
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("PICKUP SHED: %s would drop %s (wt %d) for %s" % [
			merc.merc_name, str(shed["name"]), int(shed["weight"]), w.item_name])
	return {"score": alt_score, "shed": shed}


#Interact cost plus the stow or drop the hands need first; -1 if no plan can free them.
static func _pickup_total_cost(
		merc: MercenaryData,
		weapon: WeaponData,
		enemies: Array[MercenaryData],
		state: BattleState,
		attack_base_cost: int) -> int:
	var plan := WeaponActionExecutor.plan_free_hands(merc, weapon, enemies, state, attack_base_cost)
	if not bool(plan.get("ok", false)):
		return -1
	return state.get_cost(merc, "Interact", InteractTargetFacet.INTERACT_AP) + int(plan.get("cost", 0))


static func decide_pickup_action(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		state: BattleState,
		attack_base_cost: int,
		move_base_cost: int) -> Dictionary:
	var no_action := {"type": "none", "action_name": "", "target": null, "weapon": null,
			"weapon_entry": {}, "weapon_pos": Vector2i(-1, -1)}

	var ctx: Dictionary = _pickup_context(merc, enemies, state)
	var merc_pos: Vector2i = ctx["merc_pos"] as Vector2i
	var current_score: float = ctx["current_score"] as float
	var reach_paces: int = ctx["reach_paces"] as int
	var enemy_far: bool = ctx["enemy_far"] as bool
	var enemy_adjacent: bool = ctx["enemy_adjacent"] as bool
	var ranged_priority: bool = ctx["ranged_priority"] as bool

	var gates: Dictionary = _pickup_gates(merc, enemies, state, attack_base_cost, ranged_priority, enemy_adjacent)

	var at_pos: Array = state.get_dropped_weapons_at(merc_pos, state.get_floor(merc))
	if not at_pos.is_empty():
		var at_best: Dictionary = _pickup_at_pos(merc, enemies, state, attack_base_cost,
			merc_pos, current_score, enemy_far, at_pos, gates)
		var best_entry: Dictionary = at_best["entry"] as Dictionary
		if not best_entry.is_empty():
			return {"type": "pickup", "action_name": "PickUp", "target": null, "weapon": null,
					"weapon_entry": best_entry, "weapon_pos": merc_pos,
					"shed": at_best["shed"] as Dictionary}
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP AT-POS SKIP: %s  -  %d weapon(s) at pos, none passed gates (current=%.2f)" % [
				merc.merc_name, at_pos.size(), current_score])

	var on_hand_score := WeaponEvaluator.best_on_hand_score(merc, enemies, state)

	if state.battlefield == null or state.dropped_weapons.is_empty():
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  no dropped weapons on battlefield" % merc.merc_name)
		return no_action

	var pace := reach_paces
	var move_cost := state.move_cost(merc, "Move Close", move_base_cost)
	if not state.can_afford(merc, move_cost):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  can't afford move (ap=%d+%d cost=%d)" % [
				merc.merc_name, merc.current_ap, merc.excess_ap, move_cost])
		return no_action

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("PICKUP EVAL: %s  -  on_hand=%.2f, scanning %d drop location(s) within pace=%d" % [
			merc.merc_name, on_hand_score, state.dropped_weapons.size(), pace])

	var scan: Dictionary = _pickup_scan(merc, enemies, state, merc_pos, pace, enemy_far, gates)
	var best_wp_entry: Dictionary = scan["entry"] as Dictionary
	var best_wp_pos: Vector2i = scan["pos"] as Vector2i
	var best_wp_score: float = scan["score"] as float
	var best_is_priority: bool = scan["priority"] as bool
	var best_wp_shed: Dictionary = scan["shed"] as Dictionary
	if best_wp_entry.is_empty():
		return no_action
	if not best_is_priority and best_wp_score <= on_hand_score + 0.5:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP SKIP: %s  -  score=%.2f below threshold (on_hand=%.2f+0.5)" % [
				merc.merc_name, best_wp_score, on_hand_score])
		return no_action
	var dist_to_wp := Pathfinder.chebyshev2(best_wp_pos, merc_pos)
	if dist_to_wp == 0:
		var pw0: WeaponData = best_wp_entry.get("weapon") as WeaponData
		var pu_cost := _pickup_total_cost(merc, pw0, enemies, state, attack_base_cost) if pw0 != null else -1
		if pu_cost < 0 or not state.can_afford(merc, pu_cost):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("PICKUP SKIP: %s  -  cannot free hands for %s (need=%d have=%d)" % [
					merc.merc_name, pw0.item_name if pw0 != null else "?", pu_cost,
					merc.current_ap + merc.excess_ap])
			return no_action
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("PICKUP: %s -> '%s' at %s (score=%.2f, at-pos)" % [
				merc.merc_name, pw0.item_name if pw0 != null else "?", str(best_wp_pos), best_wp_score])
		return {"type": "pickup", "action_name": "PickUp", "target": null, "weapon": null,
				"weapon_entry": best_wp_entry, "weapon_pos": best_wp_pos, "shed": best_wp_shed}
	if not enemies.is_empty():
		var near: Dictionary = MovementDecider.nearest_enemy(merc, enemies, state, -1, true)
		var nearest_d: int = near["dist"]
		var nearest_ep := Vector2i(-1, -1)
		if near["merc"] != null:
			nearest_ep = state.get_position(near["merc"])
		if nearest_ep != Vector2i(-1, -1):
			var wp_to_enemy := Pathfinder.chebyshev2(best_wp_pos, nearest_ep)
			var detour := maxi(0, dist_to_wp + wp_to_enemy - nearest_d)
			var max_detour := maxi(1, int(best_wp_score - on_hand_score))
			if detour > max_detour:
				if EncounterLogger.is_active():
					var wn: String = (best_wp_entry.get("weapon") as WeaponData).item_name \
						if best_wp_entry.get("weapon") != null else "?"
					EncounterLogger.log_verbose("PICKUP SKIP: %s  -  '%s' at %s detour=%d > max=%d (improvement=%.1f)" % [
						merc.merc_name, wn, str(best_wp_pos), detour, max_detour, best_wp_score - on_hand_score])
				return no_action
	var pw: WeaponData = best_wp_entry.get("weapon") as WeaponData
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("PICKUP: %s -> '%s' at %s (score=%.2f)" % [
			merc.merc_name, pw.item_name if pw != null else "?", str(best_wp_pos), best_wp_score])
	merc.active_states["target_weapon_pos"] = best_wp_pos
	return {"type": "move_to_pickup", "action_name": "Move Close", "target": null, "weapon": null,
			"weapon_entry": best_wp_entry, "weapon_pos": best_wp_pos, "shed": best_wp_shed}


#Position, held-weapon score, reach and enemy spread one pickup decision reads.
static func _pickup_context(merc: MercenaryData, enemies: Array[MercenaryData],
		state: BattleState) -> Dictionary:
	var merc_pos := state.get_position(merc)
	var current_score := -9999.0
	if merc.equipped_weapon != null and merc.weapon_drawn:
		current_score = WeaponEvaluator.score_weapon(merc.equipped_weapon, merc, enemies, state)

	var reach_paces := int(PaceBudget.turn_paces(merc, state, 0)["paces"])
	var enemy_far := true
	var enemy_adjacent := false
	for enemy: MercenaryData in enemies:
		var ed := state.distance_to(merc, enemy)
		if ed <= reach_paces:
			enemy_far = false
		if ed <= 1:
			enemy_adjacent = true
	var has_ranged := false
	for w_av: WeaponData in WeaponEvaluator.get_available_weapons(merc):
		if w_av.is_ranged:
			has_ranged = true
			break
	var ranged_priority := enemy_far and not has_ranged
	return {"merc_pos": merc_pos, "current_score": current_score, "reach_paces": reach_paces,
			"enemy_far": enemy_far, "enemy_adjacent": enemy_adjacent, "ranged_priority": ranged_priority}


#Gate callables every dropped entry must clear, keyed priority, ranged and stow.
static func _pickup_gates(merc: MercenaryData, enemies: Array[MercenaryData], state: BattleState,
		attack_base_cost: int, ranged_priority: bool, enemy_adjacent: bool) -> Dictionary:
	var entry_usable := func(entry: Dictionary) -> bool:
		var w: WeaponData = entry.get("weapon")
		if w == null:
			return false
		return WeaponEvaluator.is_ranged_usable(merc, w) or int(entry.get("ammo_loaded", 0)) > 0
	var priority_pick := func(entry: Dictionary) -> bool:
		var w: WeaponData = entry.get("weapon")
		if w == null or not w.is_ranged or not ranged_priority:
			return false
		return entry_usable.call(entry) as bool
	#A ranged weapon on the ground is only worth the Interact when it can be fired from there.
	var ranged_gate := func(entry: Dictionary, pos: Vector2i) -> bool:
		var w: WeaponData = entry.get("weapon")
		if w == null or not w.is_ranged:
			return true
		if not (entry_usable.call(entry) as bool):
			return false
		var cell := Vector3i(pos.x, pos.y, state.get_floor(merc))
		var rp := RangedDrawPlanner.plan(merc, w, enemies, state, attack_base_cost, cell)
		var mode := str(rp.get("mode", "none"))
		if mode == "now" or mode == "move_then_draw":
			return true
		if ranged_priority and mode != "none":
			return true
		return false
	var stow_gate := func(w: WeaponData) -> bool:
		if not enemy_adjacent or w == null:
			return true
		var fh := WeaponActionExecutor.plan_free_hands(merc, w, enemies, state, attack_base_cost)
		if not bool(fh.get("ok", false)):
			return false
		for step: Dictionary in (fh.get("steps", []) as Array):
			if str(step.get("mode", "drop")) == "stow":
				if EncounterLogger.is_active():
					var held: WeaponData = step.get("weapon")
					EncounterLogger.log_verbose("PICKUP SKIP: %s  -  enemy in reach, no time to stow %s" % [
						merc.merc_name, held.item_name if held != null else "?"])
				return false
		return true
	return {"priority": priority_pick, "ranged": ranged_gate, "stow": stow_gate}


#Best dropped weapon on the mover's own cell that clears every gate, with the shed it wants.
static func _pickup_at_pos(merc: MercenaryData, enemies: Array[MercenaryData], state: BattleState,
		attack_base_cost: int, merc_pos: Vector2i, current_score: float, enemy_far: bool,
		at_pos: Array, gates: Dictionary) -> Dictionary:
	var priority_pick: Callable = gates["priority"] as Callable
	var ranged_gate: Callable = gates["ranged"] as Callable
	var stow_gate: Callable = gates["stow"] as Callable
	var best_entry: Dictionary = {}
	var best_shed: Dictionary = {}
	var best_score := -9999.0
	var inv_score := WeaponEvaluator.best_on_hand_score(merc, enemies, state)
	for entry: Dictionary in at_pos:
		var w: WeaponData = entry.get("weapon")
		if w == null:
			continue
		var cost := _pickup_total_cost(merc, w, enemies, state, attack_base_cost)
		if cost < 0:
			if EncounterLogger.is_active():
				var hh: WeaponData = merc.equipped_weapon
				EncounterLogger.log_verbose("PICKUP SKIP: %s  -  keeps %s in hand (hands_full)" % [
					merc.merc_name, hh.item_name if hh != null else "?"])
			continue
		if not state.can_afford(merc, cost):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("PICKUP SKIP: %s  -  cannot free hands for %s (need=%d have=%d)" % [
					merc.merc_name, w.item_name, cost, merc.current_ap + merc.excess_ap])
			continue
		if not (ranged_gate.call(entry, merc_pos) as bool):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("PICKUP SKIP: %s  -  %s has no firing plan here" % [
					merc.merc_name, w.item_name])
			continue
		if not (stow_gate.call(w) as bool):
			continue
		var is_priority := priority_pick.call(entry) as bool
		var adjusted: Dictionary = _burden_adjust(merc, w, _score_weapon_at_pos(entry, merc_pos, merc, enemies, state))
		var score: float = float(adjusted["score"])
		if is_priority:
			score += 2.0
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("PICKUP PRIORITY: %s ranged %s far=%d no_ranged=1" % [
					merc.merc_name, w.item_name, 1 if enemy_far else 0])
		if score < current_score and not is_priority:
			continue
		if score <= best_score:
			continue
		if score < inv_score and not is_priority:
			continue
		var ap_after := (merc.current_ap + merc.excess_ap) - cost
		if ap_after < attack_base_cost and score < 0.0 and not is_priority:
			continue
		best_score = score
		best_entry = entry
		best_shed = adjusted["shed"] as Dictionary
	return {"entry": best_entry, "shed": best_shed}


#Best dropped weapon within reach, with its cell and score; entry is empty when none qualifies.
static func _pickup_scan(merc: MercenaryData, enemies: Array[MercenaryData], state: BattleState,
		merc_pos: Vector2i, pace: int, enemy_far: bool, gates: Dictionary) -> Dictionary:
	var priority_pick: Callable = gates["priority"] as Callable
	var ranged_gate: Callable = gates["ranged"] as Callable
	var stow_gate: Callable = gates["stow"] as Callable
	var best_wp_entry: Dictionary = {}
	var best_wp_pos := Vector2i(-1, -1)
	var best_wp_score := -9999.0
	var best_is_priority := false
	var best_shed: Dictionary = {}
	var blocked_pu: Vector2i = merc.active_states.get("blocked_pickup_pos", Vector2i(-1, -1)) as Vector2i
	for pos: Vector2i in state.dropped_weapons.keys():
		var dist := Pathfinder.chebyshev2(pos, merc_pos)
		if dist > pace or dist == 0:
			continue
		if pos == blocked_pu:
			continue
		var enemies_adj := 0
		for enemy: MercenaryData in enemies:
			var ep := state.get_position(enemy)
			if Pathfinder.chebyshev2(pos, ep) <= 1:
				enemies_adj += 1
		if enemies_adj > 1:
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  skip pos %s: %d enemies adjacent (too dangerous)" % [str(pos), enemies_adj])
			continue
		var bfw_pos: Vector2i = merc.active_states.get("bfw_drop_pos", Vector2i(-1, -1))
		var tgt_pos: Vector2i = merc.active_states.get("target_weapon_pos", Vector2i(-1, -1))
		for entry: Dictionary in state.get_dropped_weapons_at(pos, state.get_floor(merc)):
			var w: WeaponData = entry.get("weapon") as WeaponData
			var w_name: String = w.item_name if w != null else "?"
			if not (ranged_gate.call(entry, pos) as bool):
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("PICKUP SKIP: %s  -  '%s' at %s has no firing plan" % [
						merc.merc_name, w_name, str(pos)])
				continue
			if not (stow_gate.call(w) as bool):
				continue
			var scan_priority := priority_pick.call(entry) as bool
			var adjusted: Dictionary = _burden_adjust(merc, w, _score_weapon_at_pos(entry, pos, merc, enemies, state))
			var score: float = float(adjusted["score"])
			if pos == bfw_pos:
				score += 2.0
			if pos == tgt_pos:
				score += 1.0
			if scan_priority:
				score += 2.0
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("PICKUP PRIORITY: %s ranged %s far=%d no_ranged=1" % [
						merc.merc_name, w_name, 1 if enemy_far else 0])
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("  dropped '%s' at %s (dist=%d) score=%.2f" % [w_name, str(pos), dist, score])
			if score > best_wp_score:
				best_wp_score = score
				best_wp_entry = entry
				best_wp_pos = pos
				best_is_priority = scan_priority
				best_shed = adjusted["shed"] as Dictionary

	return {"entry": best_wp_entry, "pos": best_wp_pos, "score": best_wp_score,
			"priority": best_is_priority, "shed": best_shed}
