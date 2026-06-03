class_name DrawAction extends ActionData

func can_execute(merc: MercenaryData, ctx: Dictionary) -> bool:
	if not enabled:
		return false
	var weapon := _resolve_draw_weapon(merc)
	if weapon == null:
		return false
	if weapon == merc.equipped_weapon and merc.weapon_drawn:
		return false
	var state: BattleState = ctx["state"]
	var draw_cost := state.get_cost(merc, action_name, WeaponActionExecutor.get_draw_cost(merc, weapon))
	return state.can_afford(merc, draw_cost)

func _resolve_draw_weapon(merc: MercenaryData) -> WeaponData:
	var current := merc.equipped_weapon
	var _too_unreliable := current != null and current.is_ranged and current.misfire > 0 \
		and (FirearmReliabilityFacet.compute(merc) * 2.5 + 2.0) / 4.5 < 0.50
	var current_is_useless := (current != null and current.is_ranged and merc.ammo_loaded == 0 and _has_no_ammo(merc)) \
		or _too_unreliable
	if not current_is_useless:
		var result := super._resolve_draw_weapon(merc)
		return result if result != null else DataManager.fight_weapon
	# Current ranged weapon is out of ammo with no reload option -- find a better alternative.
	var fallback: WeaponData = null
	for entry in merc.inventory:
		if entry.get("type") != "weapon":
			continue
		var w: WeaponData = entry.get("data")
		if w == current:
			continue
		if not w.is_ranged:
			return w
		if fallback == null:
			fallback = w
	return fallback if fallback != null else DataManager.fight_weapon

static func _has_no_ammo(merc: MercenaryData) -> bool:
	for v in merc.ammo_inventory.values():
		if int(v) > 0:
			return false
	return true
