class_name CombatDecision

const _WEIGHTS := preload("res://Scripts/Actions/Resources/AIWeightsConfig.tres")
#AP a full repair of a snapped bowstring costs, paid across turns.


#True when the damage type can be defended or dodged and the defender has a reduction to use.
static func _can_defend(defender: MercenaryData, damage_type: String) -> bool:
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
	return true


static func should_attempt_defense(
		defender: MercenaryData,
		damage: int,
		damage_type: String) -> bool:
	if not _can_defend(defender, damage_type):
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
	if not _can_defend(defender, damage_type):
		return false

	var eap: Dictionary = _excess_ap_score(defender, attacker, state, excess_needed)
	var score: float = eap["score"] as float
	var hp_ratio: float = eap["hp_ratio"] as float
	var eap_surplus: int = eap["eap_surplus"] as int
	var ep_ratio: float = eap["ep_ratio"] as float
	var ranged_threat: bool = eap["ranged_threat"] as bool
	var nearby_melee_threat: bool = eap["nearby_melee_threat"] as bool
	var alive_enemies: int = eap["alive_enemies"] as int

	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("EXAP_EVAL: %s score=%.2f hp=%.0f%% eap_surplus=%d ep=%.0f%% threat=%s enemies=%d" % [
			defender.merc_name, score,
			hp_ratio * 100.0, eap_surplus, ep_ratio * 100.0,
			"ranged" if ranged_threat else ("melee" if nearby_melee_threat else "none"),
			alive_enemies])

	return score >= 0.40


#Weight of every reason a defender has to spend excess AP, with the facts the log line prints.
static func _excess_ap_score(defender: MercenaryData, attacker: MercenaryData,
		state: BattleState, excess_needed: int) -> Dictionary:
	var score := 0.0

	var hp_ratio := defender.hp_ratio()
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
