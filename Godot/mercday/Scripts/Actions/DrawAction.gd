class_name DrawAction extends ActionData

const _BATTLE_CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

func can_execute(merc: MercenaryData, ctx: Dictionary) -> bool:
	if not enabled:
		return false
	var state: BattleState = ctx["state"]
	var weapon := _resolve_draw_weapon(merc)
	if weapon == null:
		WeaponActionExecutor.log_draw_refusal(merc, null, "no_weapon", 0)
		return false
	if weapon == merc.equipped_weapon and merc.weapon_drawn:
		return false
	var draw_cost := WeaponActionExecutor.get_swap_cost(merc, weapon, state)
	if draw_cost < 0:
		WeaponActionExecutor.log_draw_refusal(merc, weapon, "hands_full", 0, false)
		return false
	if not state.can_afford(merc, draw_cost):
		WeaponActionExecutor.log_draw_refusal(merc, weapon, "ap_short", draw_cost)
		return false
	if weapon.is_ranged:
		var plan := RangedDrawPlanner.plan(
			merc, weapon, state.get_enemies(merc), state, _BATTLE_CONFIG.attack_base_ap)
		if str(plan.get("mode", "none")) != "now":
			WeaponActionExecutor.log_draw_refusal(merc, weapon, "no_los_plan", draw_cost, false)
			return false
	return true

func _resolve_draw_weapon(merc: MercenaryData) -> WeaponData:
	var current := merc.equipped_weapon
	if not WeaponEvaluator.drawn_ranged_useless(merc, current):
		var result := super._resolve_draw_weapon(merc)
		return result if result != null else DataManager.fight_weapon
	#The ranged weapon in hand is empty with no reload, so look for a better alternative.
	if merc.offhand_weapon != null and not merc.offhand_weapon.is_ranged:
		return merc.offhand_weapon
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
