class_name ReloadDecision

const _WEIGHTS := preload("res://Scripts/Actions/Resources/AIWeightsConfig.tres")
const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
const REPAIR_AP := 4


#Quick-Reload trades the load time for the attack cost when the attack is cheaper.
static func reload_ap_cost(merc: MercenaryData, weapon: WeaponData, state: BattleState) -> int:
	if weapon == null:
		return 0
	var cost := weapon.load_time
	if cost <= 0 or not WeaponArmorPerkLibrary.has_weapon_passive(merc, "attack_as_reload"):
		return cost
	var attack_cost := maxi(1, state.get_cost(merc, "Attack", _CONFIG.attack_base_ap)
			- int(merc.active_states.get("attack_ap_reduction", 0)))
	return mini(cost, attack_cost)


#A snapped bowstring is worth repairing when the merc carries nothing better to fight with.
static func decide_repair_action(merc: MercenaryData, enemies: Array[MercenaryData],
		state: BattleState) -> Dictionary:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.string_snapped or not merc.weapon_drawn:
		return {"type": "none"}
	if weapon.repair_ap_paid >= REPAIR_AP:
		return {"type": "none"}
	if merc.current_ap + merc.excess_ap <= 0:
		return {"type": "none"}
	var best := WeaponEvaluator.best_available_weapon(merc, enemies, state)
	if best != null and best != weapon and best != DataManager.fight_weapon:
		return {"type": "none"}
	return {"type": "repair", "action_name": "repair", "target": null}


static func should_reload(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_attack_targets: Array[MercenaryData],
		state: BattleState) -> bool:
	var weapon := merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return false
	if weapon.chamber <= 0:
		if merc.ammo_loaded > 0:
			return false
		var ammo_type_q := merc.ammo_loaded_type
		if ammo_type_q == "" or merc.ammo_inventory.get(ammo_type_q, 0) <= 0:
			return false
		return not MovementDecider.is_in_danger(merc)
	var reload_cost := reload_ap_cost(merc, weapon, state)
	if reload_cost <= 0 or not state.can_afford(merc, reload_cost):
		return false
	var ammo_type := merc.ammo_loaded_type
	if ammo_type == "" or merc.ammo_inventory.get(ammo_type, 0) <= 0:
		return false

	var in_danger := MovementDecider.is_in_danger(merc)
	var ammo_loaded := merc.ammo_loaded

	if ammo_loaded == 0:
		if not in_danger:
			return true
		var max_hp := float(merc.stats.get("maximum_hit_points", 1))
		var hp_ratio := float(merc.current_hp) / max_hp
		var chance := (hp_ratio / _WEIGHTS.danger_hp_ratio) * 0.25
		if randf() < chance:
			return true
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("RELOAD SKIPPED: %s in danger, hp_ratio=%.2f, chance=%.0f%%" % [
				merc.merc_name, hp_ratio, chance * 100.0])
		return false

	if float(ammo_loaded) < float(weapon.chamber) * 0.5:
		if in_danger:
			return false
		var chance := 0.50
		if valid_attack_targets.is_empty():
			chance = 0.75
			if not _any_enemy_in_range(merc, enemies, weapon, state):
				return true
		return randf() < chance

	return false


static func _any_enemy_in_range(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		weapon: WeaponData,
		state: BattleState) -> bool:
	if state.battlefield == null:
		return true
	if weapon.ranged_extended_range <= 0:
		return true
	for enemy: MercenaryData in enemies:
		if state.distance_to(merc, enemy) <= weapon.ranged_extended_range:
			return true
	return false
