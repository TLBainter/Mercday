class_name AttackSystem

static func execute_attack(
		attacker: MercenaryData,
		extra_enhancements: int = 0,
		extra_flaws: int = 0,
		target: MercenaryData = null) -> Dictionary:
	var weapon := attacker.equipped_weapon
	var is_ranged := weapon != null and weapon.is_ranged

	if is_ranged:
		if attacker.weapon_misfired:
			return _empty_attack_result(_pick_damage_type(weapon.damage_types_1), false, true)
		if attacker.ammo_loaded <= 0:
			return _empty_attack_result(_pick_damage_type(weapon.damage_types_1), true, false)

	var stat_keys: Array[String]
	var circumstances: Array[String]
	if weapon != null and weapon.has_heavy and not weapon.has_light:
		stat_keys = ["vigor"]
		circumstances = ["Attack (Vigor)"]
	elif weapon != null and weapon.has_light and not weapon.has_heavy:
		stat_keys = ["dexterity"]
		circumstances = ["Attack (Dexterity)"]
	else:
		stat_keys = ["dexterity", "vigor"]
		circumstances = ["Attack (Dexterity)", "Attack (Vigor)"]

	var total_enhancements := extra_enhancements
	if target != null and ConstStates.has_state(target, ConstStates.INHIBITED):
		total_enhancements += 1
	if target != null and ConstStates.has_state(target, ConstStates.FLANKED):
		total_enhancements += 1

	var flat_threshold_bonus := 0.0
	if is_ranged and ConstStates.has_state(attacker, ConstStates.THREATENED) \
			and not WeaponArmorPerkLibrary.has_weapon_passive(attacker, "weapon_passive:ignore_threatened"):
		flat_threshold_bonus -= 30.0

	var accuracy_formula := "ranged_accuracy" if is_ranged else "melee_accuracy"
	var check_def := {
		"stat_keys": stat_keys,
		"circumstances": circumstances,
		"knowledges": [],
		"tools": [],
		"formula": accuracy_formula,
		"enhancements": total_enhancements,
		"flaws": extra_flaws,
		"flat_threshold_bonus": flat_threshold_bonus,
	}

	var check_result := CheckSystem.make_check(attacker, check_def)
	var core_successes := int(check_result["successes"])

	var dmg_formula := ""
	var damage_type := "Strike"
	var weapon_die_successes := 0
	var flat_bonus := 0

	if weapon != null:
		dmg_formula = weapon.damage_formula_1
		damage_type = _pick_damage_type(weapon.damage_types_1)
		if is_ranged and damage_type == "Varies" and attacker.ammo_loaded_type != "":
			var ammo_data: AmmoData = DataManager.ammo.get(attacker.ammo_loaded_type)
			if ammo_data != null and not ammo_data.damage_types_1.is_empty():
				damage_type = _pick_damage_type(ammo_data.damage_types_1)
		var parsed := _parse_damage_formula(dmg_formula)
		flat_bonus = parsed["flat_bonus"]
		if not parsed["is_todo"]:
			var threshold := float(check_result["threshold"])
			var die_threshold := floori(threshold / 100.0 * float(parsed["die_sides"]))
			for _d: int in range(parsed["num_dice"]):
				if randi_range(1, parsed["die_sides"]) <= die_threshold:
					weapon_die_successes += 1

	if is_ranged:
		attacker.ammo_loaded -= 1
		if weapon.chamber <= 0 and attacker.ammo_loaded_type != "":
			var _inv: int = attacker.ammo_inventory.get(attacker.ammo_loaded_type, 0)
			if _inv > 0:
				attacker.ammo_inventory[attacker.ammo_loaded_type] = _inv - 1
				if attacker.ammo_inventory[attacker.ammo_loaded_type] <= 0:
					attacker.ammo_inventory.erase(attacker.ammo_loaded_type)
		if weapon.misfire > 0 and core_successes < weapon.misfire:
			attacker.weapon_misfired = true
			return {
				"damage": 0,
				"damage_type": damage_type,
				"core_successes": 0,
				"weapon_die_successes": 0,
				"flat_bonus": 0,
				"dmg_formula": dmg_formula,
				"check_result": check_result,
				"stat_used": check_result["stat_used"],
				"threshold": check_result["threshold"],
				"misfired": true,
				"no_ammo": false,
			}

	return {
		"damage": core_successes + weapon_die_successes + flat_bonus,
		"damage_type": damage_type,
		"core_successes": core_successes,
		"weapon_die_successes": weapon_die_successes,
		"flat_bonus": flat_bonus,
		"dmg_formula": dmg_formula,
		"check_result": check_result,
		"stat_used": check_result["stat_used"],
		"threshold": check_result["threshold"],
		"misfired": false,
		"no_ammo": false,
	}


static func _empty_attack_result(damage_type: String, no_ammo: bool, misfired: bool) -> Dictionary:
	return {
		"damage": 0,
		"damage_type": damage_type,
		"core_successes": 0,
		"weapon_die_successes": 0,
		"flat_bonus": 0,
		"dmg_formula": "",
		"check_result": {},
		"stat_used": "",
		"threshold": 0.0,
		"misfired": misfired,
		"no_ammo": no_ammo,
	}


static func _pick_damage_type(types: Array[String]) -> String:
	if types.is_empty():
		return "Strike"
	if types.size() == 1:
		return types[0]
	return types[randi() % types.size()]


static func _parse_damage_formula(formula: String) -> Dictionary:
	var result := {"num_dice": 0, "die_sides": 0, "flat_bonus": 0, "is_todo": false}
	var f: String = formula.strip_edges()
	if f == "0" or f == "Varies" or f == "":
		result["is_todo"] = true
		return result
	var flat: int = 0
	var plus_idx: int = f.find(" + ")
	if plus_idx != -1:
		flat = int(f.substr(plus_idx + 3).strip_edges())
		f = f.left(plus_idx).strip_edges()
	result["flat_bonus"] = flat
	var d_idx: int = f.find("d")
	if d_idx == -1:
		result["is_todo"] = true
		return result
	var num_str: String = f.left(d_idx)
	var sides_str: String = f.substr(d_idx + 1)
	if not num_str.is_valid_int() or not sides_str.is_valid_int():
		result["is_todo"] = true
		return result
	result["num_dice"] = int(num_str)
	result["die_sides"] = int(sides_str)
	return result
