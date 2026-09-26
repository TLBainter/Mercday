class_name CombatDecision

const _WEIGHTS := preload("res://Scripts/Actions/Resources/AIWeightsConfig.tres")
const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")
#AP a full repair of a snapped bowstring costs, paid across turns.
const REPAIR_AP := 4


#Target rule shared by actions whose .tres sets target_mode = "current_or_best".
static func current_or_best(merc: MercenaryData, ctx: Dictionary, state: BattleState) -> MercenaryData:
	var valid: Array = ctx.get("valid_targets", [])
	var cur: MercenaryData = ctx.get("current_target") as MercenaryData
	if cur != null and valid.has(cur) and not FleeSystem.has_better_quarry(cur, valid, state):
		return cur
	if valid.is_empty():
		return null
	return TargetSelector.pick_target(merc, valid, state)


static func should_attempt_defense(
		defender: MercenaryData,
		damage: int,
		damage_type: String) -> bool:
	var type_data := ConstDamageTypes.get_type(damage_type)
	if type_data.get("is_direct", false):
		return false
	if ConstStates.has_state(defender, ConstStates.VULNERABLE):
		return false
	var best_stat := maxi(
		int(defender.stats.get("defend_reduction", 0)),
		int(defender.stats.get("dodge_reduction", 0))
	)
	if best_stat <= 0:
		return false
	var max_hp := int(defender.stats.get("maximum_hit_points", 1))
	if damage >= defender.current_hp:
		return true
	var pain_limit := int(defender.stats.get("pain_limit", 0))
	if pain_limit > 0 and damage >= pain_limit:
		return true
	if float(defender.current_hp) / float(max_hp) < 0.5:
		return true
	if float(damage) / float(maxi(1, defender.current_hp)) > _WEIGHTS.defense_damage_threshold:
		return true
	return false


static func should_spend_excess_ap(
		defender: MercenaryData,
		attacker: MercenaryData,
		damage_type: String,
		state: BattleState,
		excess_needed: int = 1) -> bool:
	var type_data := ConstDamageTypes.get_type(damage_type)
	if type_data.get("is_direct", false):
		return false
	if ConstStates.has_state(defender, ConstStates.VULNERABLE):
		return false
	var best_stat := maxi(
		int(defender.stats.get("defend_reduction", 0)),
		int(defender.stats.get("dodge_reduction", 0))
	)
	if best_stat <= 0:
		return false

	var _eap: Dictionary = _excess_ap_score(defender, attacker, state, excess_needed)
	var score: float = _eap["score"] as float
	var hp_ratio: float = _eap["hp_ratio"] as float
	var eap_surplus: int = _eap["eap_surplus"] as int
	var ep_ratio: float = _eap["ep_ratio"] as float
	var ranged_threat: bool = _eap["ranged_threat"] as bool
	var nearby_melee_threat: bool = _eap["nearby_melee_threat"] as bool
	var alive_enemies: int = _eap["alive_enemies"] as int

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("EXAP_EVAL: %s score=%.2f hp=%.0f%% eap_surplus=%d ep=%.0f%% threat=%s enemies=%d" % [
			defender.merc_name, score,
			hp_ratio * 100.0, eap_surplus, ep_ratio * 100.0,
			"ranged" if ranged_threat else ("melee" if nearby_melee_threat else "none"),
			alive_enemies])

	return score >= 0.40


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
	var best := WeaponEvaluator._best_available_weapon(merc, enemies, state)
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


static func estimate_kill_likelihood(attacker: MercenaryData, target: MercenaryData) -> float:
	var weapon := attacker.equipped_weapon
	if weapon == null:
		return 0.0
	var avg_dmg := WeaponEvaluator.parse_formula_for_avg(weapon.damage_formula_1)
	var weapon_key := "vigor" if (weapon.has_heavy and not weapon.has_light) else "dexterity"
	avg_dmg += float(attacker.stats.get(weapon_key, 0)) * 0.4
	return minf(1.0, avg_dmg / maxf(1.0, float(target.current_hp)))


static func is_melee_preferred(merc: MercenaryData) -> bool:
	var melee_acc := maxf(1.0, float(merc.stats.get("melee_accuracy", 1.0)))
	var ranged_acc := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
	var best_melee_dps := 0.0
	var best_ranged_dps := 0.0
	var all_weapons: Array[WeaponData] = []
	if merc.equipped_weapon != null:
		all_weapons.append(merc.equipped_weapon)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") != "weapon":
			continue
		var w: WeaponData = entry.get("data") as WeaponData
		if w != null:
			all_weapons.append(w)
	for w: WeaponData in all_weapons:
		var avg := WeaponEvaluator.parse_formula_for_avg(w.damage_formula_1)
		if w.is_ranged:
			best_ranged_dps = maxf(best_ranged_dps, avg * ranged_acc)
		elif w.is_throwable and not w.is_ranged:
			var thrown_acc := ThrownWeaponRules.compute_thrown_accuracy(merc, w)
			best_ranged_dps = maxf(best_ranged_dps, avg * thrown_acc)
			best_melee_dps = maxf(best_melee_dps, avg * melee_acc)
		else:
			best_melee_dps = maxf(best_melee_dps, avg * melee_acc)
	return best_melee_dps > best_ranged_dps


#Weight of every reason a defender has to spend excess AP, with the facts the log line prints.
static func _excess_ap_score(defender: MercenaryData, attacker: MercenaryData,
		state: BattleState, excess_needed: int) -> Dictionary:
	var score := 0.0

	var max_hp := float(maxi(1, int(defender.stats.get("maximum_hit_points", 1))))
	var hp_ratio := float(defender.current_hp) / max_hp
	if hp_ratio <= 0.25:
		score += 0.35
	elif hp_ratio <= 0.50:
		score += 0.20
	elif hp_ratio <= 0.75:
		score += 0.05

	var eap_surplus := defender.excess_ap - excess_needed
	if eap_surplus >= 3:
		score += 0.30
	elif eap_surplus >= 2:
		score += 0.20
	elif eap_surplus >= 1:
		score += 0.10

	var max_ep := float(maxi(1, int(defender.stats.get("maximum_endurance_points", 1))))
	var ep_ratio := float(defender.current_ep) / max_ep
	if ep_ratio <= 0.25:
		score += 0.30
	elif ep_ratio <= 0.50:
		score += 0.15
	elif ep_ratio <= 0.75:
		score += 0.05

	var ranged_threat := false
	var nearby_melee_threat := false
	if attacker != null and attacker.equipped_weapon != null:
		ranged_threat = attacker.equipped_weapon.is_ranged
	var alive_enemies := 0
	for e: MercenaryData in state.get_enemies(defender):
		if not BattleState._is_alive(e):
			continue
		alive_enemies += 1
		if e == attacker:
			continue
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_threat = true
		elif state.distance_to(defender, e) <= 2:
			nearby_melee_threat = true

	if not ranged_threat and not nearby_melee_threat:
		score += 0.15
	elif not ranged_threat:
		score += 0.07

	if alive_enemies <= 1:
		score += 0.10
	elif alive_enemies <= 2:
		score += 0.05
	return {"score": score, "hp_ratio": hp_ratio, "eap_surplus": eap_surplus, "ep_ratio": ep_ratio,
			"ranged_threat": ranged_threat, "nearby_melee_threat": nearby_melee_threat,
			"alive_enemies": alive_enemies}
