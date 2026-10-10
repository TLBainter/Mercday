class_name WeaponFitnessFacet extends DecisionFacet

#invert = false: returns high score when weapon is a POOR fit (use for MoveClose / AttackMelee)
#invert = true: returns high score when weapon is a GOOD fit (use for MoveFar / AttackRangeAimed)
#Applies invert inside evaluate, where the flip is not 1.0 - raw.
func score(merc: MercenaryData, ctx: Dictionary) -> float:
	return evaluate(merc, ctx)


func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var weapon := merc.equipped_weapon
	if weapon == null:
		return 0.5

	#A ranged weapon with no ammo and no reload option is worthless at range; treat as poor fit.
	if weapon.is_ranged and merc.ammo_loaded == 0:
		if not MercenaryData.has_reserve_ammo(merc):
			return 1.0

	var dex: float = maxf(0.0, float(merc.stats.get("dexterity", 0)))
	var vig: float = maxf(0.0, float(merc.stats.get("vigor", 0)))
	var best_stat: float = maxf(1.0, maxf(dex, vig))

	var weapon_stat_val: float
	if weapon.has_heavy and not weapon.has_light:
		weapon_stat_val = vig
	elif weapon.has_light and not weapon.has_heavy:
		weapon_stat_val = dex
	else:
		weapon_stat_val = maxf(dex, vig)

	#0.0 = weapon stat matches best stat (good fit), 1.0 = weapon stat is near zero (poor fit)
	var fitness: float = 1.0 - clampf(weapon_stat_val / best_stat, 0.0, 1.0)
	var result: float = fitness if not invert else 1.0 - fitness
	if weapon.fragility > 0:
		var dur_ratio := clampf(float(weapon.current_fragility) / float(weapon.fragility), 0.0, 1.0)
		result *= 0.5 + 0.5 * dur_ratio
	return result
