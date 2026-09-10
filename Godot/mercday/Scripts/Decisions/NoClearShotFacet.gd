class_name NoClearShotFacet extends DecisionFacet

func evaluate(merc: MercenaryData, ctx: Dictionary) -> float:
	var weapon: WeaponData = merc.equipped_weapon if merc.weapon_drawn else null
	if weapon == null or (not weapon.is_ranged and not weapon.is_throwable):
		var state: BattleState = ctx.get("state") as BattleState
		var enemies: Array = ctx.get("enemies", [])
		if state != null and not enemies.is_empty():
			var stop := weapon.melee_range if weapon != null else 1
			var move_tgt: MercenaryData = ctx.get("current_target") as MercenaryData
			if move_tgt == null or not enemies.has(move_tgt):
				for e: MercenaryData in enemies:
					if move_tgt == null or state.distance_to(merc, e) < state.distance_to(merc, move_tgt):
						move_tgt = e
			if move_tgt != null and state.distance_to(merc, move_tgt) <= stop:
				return 0.0
		return 1.0
	if weapon.is_throwable and not weapon.is_ranged:
		var state: BattleState = ctx.get("state") as BattleState
		if state == null or weapon.thrown_intended_range <= 0:
			return 1.0 if ctx.get("valid_targets", []).is_empty() else 0.0
		var throw_acc := ThrownWeaponRules.compute_thrown_accuracy(merc, weapon)
		var melee_acc := float(merc.stats.get("melee_accuracy", 50.0))
		var throw_dominant := melee_acc > 0.0 and throw_acc >= melee_acc * 1.5
		var has_backup := false
		for inv_e: Dictionary in merc.inventory:
			if inv_e.get("type") == "weapon":
				has_backup = true
				break
		var disarm_penalty := 0.0 if has_backup else 0.5
		var throw_avg := WeaponEvaluator.parse_formula_for_avg(weapon.damage_formula_1)
		var expected_dmg := clampf(throw_acc / 100.0, 0.01, 1.0) * throw_avg
		for enemy: MercenaryData in ctx.get("valid_targets", []):
			if state.distance_to(merc, enemy) > weapon.thrown_intended_range:
				continue
			if not bool(ThrownWeaponRules.should_throw(
					merc, weapon, enemy, ctx.get("enemies", []), state, false)["throw"]):
				continue
			if not throw_dominant:
				return 1.0
			var kill_prob := clampf(expected_dmg / float(maxi(1, enemy.current_hp)), 0.0, 1.0)
			var already_armed := enemy.equipped_weapon != null and not enemy.equipped_weapon.is_virtual
			var enemy_score := WeaponEvaluator.score_weapon(weapon, enemy, [merc], state)
			var arm_risk := enemy_score * (1.0 - kill_prob) * (0.3 if already_armed else 1.0)
			if arm_risk + disarm_penalty <= 1.5:
				return 0.0
		return 1.0
	return 1.0 if ctx.get("valid_targets", []).is_empty() else 0.0
