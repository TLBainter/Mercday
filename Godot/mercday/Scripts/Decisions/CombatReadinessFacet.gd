class_name CombatReadinessFacet extends DecisionFacet

#invert = false: returns LOW when ready (use for MoveFar; healthy mercs retreat less)
#invert = true:  returns HIGH when ready (use for MoveClose; healthy mercs advance more)
@export var invert: bool = false

func evaluate(merc: MercenaryData, _ctx: Dictionary) -> float:
	var max_hp := float(maxi(1, int(merc.stats.get("maximum_hit_points", 1))))
	var hp_depletion := 1.0 - clampf(float(merc.current_hp) / max_hp, 0.0, 1.0)

	var weapon := merc.equipped_weapon
	var ammo_depletion := 0.0
	if weapon != null and weapon.is_ranged:
		var has_ammo := merc.ammo_loaded > 0 or MercenaryData.has_reserve_ammo(merc)
		ammo_depletion = 0.0 if has_ammo else 1.0

	var max_ep := float(maxi(1, int(merc.stats.get("maximum_endurance_points", 1))))
	var ep_depletion := 1.0 - clampf(float(merc.current_ep) / max_ep, 0.0, 1.0)

	var depletion := clampf(hp_depletion * 0.5 + ammo_depletion * 0.3 + ep_depletion * 0.2, 0.0, 1.0)
	return depletion if not invert else 1.0 - depletion
