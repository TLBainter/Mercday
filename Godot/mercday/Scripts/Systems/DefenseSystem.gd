class_name DefenseSystem

static func resolve(merc: MercenaryData, raw_damage: int, damage_type: String, extra_enhancements: int = 0, free_defense: bool = false, skip_defense: bool = false) -> Dictionary:
	var type_data: Dictionary = ConstDamageTypes.get_type(damage_type)
	var type_lower: String = damage_type.to_lower()

	var out: Dictionary = {
		"raw_damage":       raw_damage,
		"modified_damage":  raw_damage,
		"modifier":         "none",
		"direct_portion":   0,
		"reducible":        raw_damage,
		"defend_reduction": 0,
		"dodge_reduction":  0,
		"best_reduction":   0,
		"reduction_source": "none",
		"final_reducible":  raw_damage,
		"final_damage":     raw_damage,
		"ep_spent":         0,
		"is_direct":        type_data.get("is_direct", false),
		"is_immune":        false,
		"defend_blocked":   type_data.get("defend_blocked", false),
		"dodge_blocked":    type_data.get("dodge_blocked", false),
		"defend_result":    {},
		"dodge_result":     {},
		"notes":            [],
	}

	if ConstStates.has_state(merc, ConstStates.VULNERABLE):
		raw_damage += 1
		out["raw_damage"] = raw_damage
		# Force direct (overrides type_data below)
		out["is_direct"] = true

	for effect: String in merc.passive_effects:
		if effect == "immune:" + type_lower:
			out["modifier"] = "immune"
			out["is_immune"] = true
			out["modified_damage"] = 0
			out["reducible"] = 0
			out["final_reducible"] = 0
			out["final_damage"] = 0
			return out

	if damage_type == "Toxic" and ConstStates.has_state(merc, ConstStates.POISONED):
		raw_damage += 1
		out["raw_damage"] = raw_damage

	var modified_damage: int = raw_damage
	for effect: String in merc.passive_effects:
		if effect == "susceptible:" + type_lower:
			modified_damage = raw_damage * 2
			out["modifier"] = "susceptible"
			break
		elif effect == "protected:" + type_lower:
			modified_damage = floori(raw_damage / 2.0)
			out["modifier"] = "protected"
			break
	if damage_type == "Sonic" and ConstStates.has_state(merc, ConstStates.DEAFENED) \
			and out["modifier"] != "immune":
		modified_damage = floori(modified_damage / 2.0)
		if out["modifier"] == "none":
			out["modifier"] = "protected"

	out["modified_damage"] = modified_damage

	# Vulnerable state may have set out["is_direct"] = true above; merge with type flags.
	# TODO Electric: should be is_direct when target wears metal armor; waiting on 'metal' property on ArmorData.
	var is_direct: bool = type_data.get("is_direct", false) or out.get("is_direct", false)
	var fire_first: bool = type_data.get("fire_first_point", false)
	var direct_portion: int = 0
	var reducible: int = modified_damage

	if is_direct:
		direct_portion = modified_damage
		reducible = 0
	elif fire_first and modified_damage > 0:
		direct_portion = 1
		reducible = modified_damage - 1

	out["direct_portion"] = direct_portion
	out["reducible"] = reducible
	out["final_reducible"] = reducible

	if is_direct or reducible == 0:
		out["final_damage"] = direct_portion
		if type_data.get("will_hp_floor", false):
			out["final_damage"] = mini(direct_portion, maxi(0, merc.current_hp - 1))
		merc.current_hp = maxi(0, merc.current_hp - int(out["final_damage"]))
		return out

	if (merc.current_ep <= 0 and not free_defense) or skip_defense:
		out["final_damage"] = modified_damage
		merc.current_hp = maxi(0, merc.current_hp - modified_damage)
		return out

	if not free_defense:
		merc.current_ep -= 1
		out["ep_spent"] = 1

	var defend_successes: int = 0
	var dodge_successes: int = 0
	var defend_blocked: bool = type_data.get("defend_blocked", false)
	var dodge_blocked: bool = type_data.get("dodge_blocked", false)
	var defend_halved: bool = type_data.get("defend_halved", false)

	if not defend_blocked:
		var def_check: Dictionary = {
			"stat_keys":    ["defend_reduction"],
			"circumstances": [],
			"knowledges":   [],
			"tools":        [],
			"formula":      "defend",
			"enhancements": extra_enhancements,
			"flat_threshold_bonus": 0.0,
		}
		var def_result: Dictionary = CheckSystem.make_check(merc, def_check)
		out["defend_result"] = def_result
		defend_successes = int(def_result["successes"])
		if defend_halved:
			defend_successes = floori(defend_successes / 2.0)

	if not dodge_blocked:
		var dodge_check: Dictionary = {
			"stat_keys":    ["dodge_reduction"],
			"circumstances": [],
			"knowledges":   [],
			"tools":        [],
			"formula":      "dodge",
			"enhancements": extra_enhancements,
		}
		var dodge_result: Dictionary = CheckSystem.make_check(merc, dodge_check)
		out["dodge_result"] = dodge_result
		dodge_successes = int(dodge_result["successes"])

	out["defend_reduction"] = defend_successes
	out["dodge_reduction"] = dodge_successes

	var best: int
	var source: String
	if defend_successes >= dodge_successes:
		best = defend_successes
		source = "defend"
	else:
		best = dodge_successes
		source = "dodge"
	out["best_reduction"] = best
	out["reduction_source"] = source

	var block_min_1: bool = type_data.get("block_min_1", false)
	var dodge_min_1: bool = type_data.get("dodge_min_1", false)
	var final_reducible: int
	if source == "defend" and block_min_1 and reducible > 0:
		final_reducible = maxi(1, reducible - best)
	elif source == "dodge" and dodge_min_1 and reducible > 0:
		final_reducible = maxi(1, reducible - best)
	else:
		final_reducible = maxi(0, reducible - best)
	out["final_reducible"] = final_reducible

	var final_dmg: int = direct_portion + final_reducible
	if type_data.get("will_hp_floor", false):
		final_dmg = mini(final_dmg, maxi(0, merc.current_hp - 1))
	out["final_damage"] = final_dmg

	merc.current_hp = maxi(0, merc.current_hp - final_dmg)
	return out
