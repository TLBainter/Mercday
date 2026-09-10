class_name RangedRetreatViabilityFacet extends DecisionFacet


func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var state: BattleState = ctx.get("state") as BattleState
	if state == null:
		return 0.0
	var stuck := state.no_progress_rounds.get(merc, 0) as int
	var no_tgt := state.no_target_turns.get(merc, 0) as int
	if stuck >= 2 or state.get_allies(merc).is_empty() or no_tgt >= 5:
		return 0.0
	var enemies: Array = ctx.get("enemies", [])
	if enemies.is_empty():
		return 0.0
	var pace: int = maxi(1, int(MovementExecutor.turn_paces(merc, state, 0)["paces"]))
	var closest := 999999
	for enemy: MercenaryData in enemies:
		closest = mini(closest, state.distance_to(merc, enemy))
	var ranged_acc := float(merc.stats.get("ranged_accuracy", 0.0))
	var melee_acc := float(merc.stats.get("melee_accuracy", 0.0))
	var best_weapon_score := -9999.0
	var has_viable := false
	var is_drawn := false
	var enemy_in_range := false
	var check_entries: Array[Dictionary] = []
	if merc.equipped_weapon != null and merc.weapon_drawn:
		check_entries.append({"weapon": merc.equipped_weapon, "drawn": true})
	for inv_e: Dictionary in merc.inventory:
		if inv_e.get("type") == "weapon":
			var inv_w: WeaponData = inv_e.get("data") as WeaponData
			if inv_w != null:
				check_entries.append({"weapon": inv_w, "drawn": false})
	for entry: Dictionary in check_entries:
		var w: WeaponData = entry.get("weapon") as WeaponData
		var drawn: bool = entry.get("drawn", false)
		if w == null:
			continue
		var viable := false
		var in_range := false
		if w.is_ranged and not w.is_throwable:
			var has_ammo := merc.ammo_loaded > 0 or MercenaryData.has_reserve_ammo(merc)
			if has_ammo:
				viable = true
				for enemy: MercenaryData in enemies:
					if w.ranged_extended_range <= 0 or state.distance_to(merc, enemy) <= w.ranged_extended_range:
						in_range = true
						break
		elif w.is_throwable and not w.is_ranged and w.thrown_intended_range >= pace:
			viable = true
			for enemy: MercenaryData in enemies:
				if state.distance_to(merc, enemy) <= w.thrown_intended_range:
					in_range = true
					break
		if not viable:
			continue
		#The retreat breaks melee contact, so the weapon is scored from outside it.
		var s := WeaponEvaluator.score_weapon(w, merc, enemies, state, false, maxi(3, closest))
		if s > best_weapon_score:
			best_weapon_score = s
		has_viable = true
		if in_range:
			enemy_in_range = true
		if drawn:
			is_drawn = true
	if not has_viable or best_weapon_score <= 0.0:
		return 0.0
	var score := 0.45 if enemy_in_range else 0.05
	if is_drawn:
		score += 0.1
	if ranged_acc > melee_acc:
		score += 0.15
	score += minf(0.15, best_weapon_score * 0.05)
	var max_hp := maxf(1.0, float(merc.stats.get("maximum_hit_points", 1)))
	var hp_ratio := float(merc.current_hp) / max_hp
	if hp_ratio < 0.5:
		score += (0.5 - hp_ratio) * 0.3
	return clampf(score, 0.0, 1.0)
