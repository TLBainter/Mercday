class_name WeaponReactiveDsl

#Tokens that sit between the trigger and the verb in a reactive_action DSL string.
const KNOWN_CONDITIONS: PackedStringArray = [
	"any", "surprised", "deposed", "vulnerable", "two_handed",
	"size_5_or_less", "size_gte_self", "size_lte_self", "thrown",
	"within_2", "melee", "intended_range", "once_per_combat", "1hp",
	"size_1_plus", "melee_reach",
]


#Parsed DSL for a reactive perk on this trigger; empty when the perk does not match.
static func token_for(perk: TraitData, trigger: String) -> Dictionary:
	for cell: String in perk.effect_dsl.split("|"):
		var dsl: String = cell.strip_edges()
		if not dsl.begins_with("reactive_action:"):
			continue
		var tok := _split_token(dsl.split(":"))
		if str(tok["trigger"]) == trigger:
			return tok
	return {}


#reactive_action:<trigger>:<cond>*:<verb>[:<args>...]
static func _split_token(parts: PackedStringArray) -> Dictionary:
	var conds: Array[String] = []
	var args: Array[String] = []
	var out: Dictionary = {"trigger": "", "conds": conds, "verb": "", "args": args}
	if parts.size() < 2:
		return out
	out["trigger"] = parts[1]
	var i := 2
	while i < parts.size() and _is_condition(parts[i]):
		conds.append(parts[i])
		i += 1
	if i < parts.size():
		out["verb"] = parts[i]
		i += 1
	while i < parts.size():
		args.append(parts[i])
		i += 1
	return out


static func _is_condition(token: String) -> bool:
	if token == "":
		return false
	for piece: String in token.split(","):
		if not KNOWN_CONDITIONS.has(piece.strip_edges()):
			return false
	return true


static func conditions_met(
		conds: Array,
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState,
		perk: TraitData = null) -> bool:
	for cond: String in conds:
		if not _condition_met(cond, attacker, target, atk, state, perk):
			return false
	return true


#A comma inside a condition token means any of the listed conditions is enough.
static func _condition_met(
		cond: String,
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState,
		perk: TraitData = null) -> bool:
	for piece: String in cond.split(","):
		if _single_condition(piece.strip_edges(), attacker, target, atk, state, perk):
			return true
	return false


static func _single_condition(
		cond: String,
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState,
		perk: TraitData = null) -> bool:
	match cond:
		"any":
			return true
		"surprised":
			return target != null and ConstStates.has_state(target, ConstStates.SURPRISED)
		"deposed":
			return target != null and ConstStates.has_state(target, ConstStates.DEPOSED)
		"vulnerable":
			return target != null and ConstStates.has_state(target, ConstStates.VULNERABLE)
		"two_handed":
			return WeaponArmorPerkLibrary.is_wielding_two_handed(attacker)
		"size_5_or_less":
			return target != null and int(target.stats.get("size", 1)) <= 5
		"size_1_plus":
			return target != null and int(target.stats.get("size", 1)) >= 1
		"size_gte_self":
			return target != null and int(target.stats.get("size", 1)) >= int(attacker.stats.get("size", 1))
		"size_lte_self":
			return target != null and int(target.stats.get("size", 1)) <= int(attacker.stats.get("size", 1))
		"thrown":
			return bool(atk.get("is_throw", false))
		"within_2":
			if target == null or state == null or state.battlefield == null:
				return false
			return state.distance_to(attacker, target) <= 2
		"melee":
			var m_weapon: WeaponData = attacker.equipped_weapon
			return m_weapon == null or not m_weapon.is_ranged
		"melee_reach":
			if not _single_condition("melee", attacker, target, atk, state, perk):
				return false
			if state == null or state.battlefield == null:
				return true
			return state.distance_to(attacker, target) <= WeaponArmorPerkLibrary.get_effective_melee_range(attacker)
		"intended_range":
			return _within_intended(attacker, target, atk, state)
		"once_per_combat":
			return perk == null or not attacker.active_states.has("perk_once:" + perk.trait_name)
		"1hp":
			if target == null:
				return false
			return ExcessPool.hp_total(target) <= 1
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("REACTIVE UNKNOWN CONDITION: %s %s" % [attacker.merc_name, cond])
	return false


#Target inside the band the weapon is designed for: ranged, thrown or melee reach.
static func _within_intended(attacker: MercenaryData, target: MercenaryData, atk: Dictionary,
		state: BattleState) -> bool:
	if target == null or state == null or state.battlefield == null:
		return false
	var weapon: WeaponData = attacker.equipped_weapon
	var dist := state.distance_to(attacker, target)
	if weapon == null:
		return dist <= 1
	if weapon.is_ranged:
		var band: int = int(WeaponArmorPerkLibrary.ranged_ranges(attacker, weapon)["intended"])
		return band <= 0 or dist <= band
	if bool(atk.get("is_throw", false)) or weapon.is_throwable:
		var t_band: int = int(ThrownWeaponRules.thrown_ranges(attacker, weapon)["intended"])
		return t_band <= 0 or dist <= t_band
	return dist <= WeaponArmorPerkLibrary.get_effective_melee_range(attacker)
