class_name AttackSystem

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

static func execute_attack(
		attacker: MercenaryData,
		extra_enhancements: int = 0,
		extra_flaws: int = 0,
		target: MercenaryData = null,
		is_throw: bool = false,
		state: BattleState = null) -> Dictionary:
	var weapon := attacker.equipped_weapon
	var is_ranged := weapon != null and weapon.is_ranged

	if is_ranged:
		if attacker.ammo_loaded <= 0:
			return _empty_attack_result(_pick_damage_type(weapon.damage_types_1), true, false, is_throw)
		if attacker.weapon_misfired:
			return _empty_attack_result(_pick_damage_type(weapon.damage_types_1), false, true, is_throw)

	var stat_keys: Array[String] = attack_stat_keys(weapon)
	var circumstances: Array[String] = []
	for key: String in stat_keys:
		circumstances.append(attack_circumstance(key))

	var total_enhancements := extra_enhancements

	var los_windows: Array[Vector3i] = []
	if state != null and target != null and state.battlefield != null:
		var los := LineOfSight.check(state, attacker, target)
		los_windows.assign(los["windows"] as Array)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("LOS: %s->%s visible=%s cover=%s via=%s blocker=%s" % [
				attacker.merc_name, target.merc_name, str(los["visible"]),
				str(los["cover"]), str(los["via"]), str(los["blocker"])])
		if not (los["visible"] as bool):
			if EncounterLogger.is_active():
				EncounterLogger.log_line("LOS: %s cannot see %s (%s)" % [
					attacker.merc_name, target.merc_name, str(los["blocker"])])
			var dt_blocked := "Strike"
			if weapon != null:
				dt_blocked = _pick_damage_type(weapon.damage_types_1)
			var blocked_result := _empty_attack_result(dt_blocked, false, false, is_throw)
			blocked_result["no_los"] = true
			return blocked_result

	var total_flaws := extra_flaws
	var flat_threshold_bonus := 0.0

	var kind := "thrown" if is_throw else ("ranged" if is_ranged else "melee")
	var atk_mod := ConstStates.attack_modifier(attacker, kind)
	var atk_states: Array = atk_mod["states"]
	#A weapon perk exempts its wielder from the Threatened flaw.
	if atk_states.has(ConstStates.THREATENED) \
			and WeaponArmorPerkLibrary.has_weapon_passive(attacker, "weapon_passive:ignore_threatened"):
		atk_mod["flaws"] = maxi(0, int(atk_mod["flaws"]) - 1)
		atk_states.erase(ConstStates.THREATENED)
	total_flaws += int(atk_mod["flaws"])
	total_enhancements += int(atk_mod["enhancements"])
	var atk_states_text := CheckSystem.states_text(atk_states)
	if EncounterLogger.is_active() and atk_states_text != "":
		EncounterLogger.log_verbose("ATTACK STATE MOD: %s %s flaws=%d enh=%d states=%s" % [
			attacker.merc_name, kind, int(atk_mod["flaws"]), int(atk_mod["enhancements"]), atk_states_text])

	if target != null:
		var tgt_mod := ConstStates.attack_vs_modifier(target, kind)
		total_flaws += int(tgt_mod["flaws"])
		total_enhancements += int(tgt_mod["enhancements"])
		var tgt_states_text := CheckSystem.states_text(tgt_mod["states"])
		if EncounterLogger.is_active() and tgt_states_text != "":
			EncounterLogger.log_verbose("TARGET STATE MOD: %s %s flaws=%d enh=%d states=%s" % [
				target.merc_name, kind, int(tgt_mod["flaws"]), int(tgt_mod["enhancements"]), tgt_states_text])

	if is_throw and weapon != null:
		flat_threshold_bonus += float(-weapon.size * 10)

	var accuracy_formula: String
	if is_throw:
		accuracy_formula = "thrown_accuracy"
	elif is_ranged:
		accuracy_formula = "ranged_accuracy"
	else:
		accuracy_formula = "melee_accuracy"
	var check_def := {
		"stat_keys": stat_keys,
		"circumstances": circumstances,
		"knowledges": [],
		"tools": [],
		"formula": accuracy_formula,
		"enhancements": total_enhancements,
		"flaws": total_flaws,
		"flat_threshold_bonus": flat_threshold_bonus,
	}

	var check_result := CheckSystem.make_check(attacker, check_def)
	var core_successes := int(check_result["successes"])
	var critical := bool(check_result.get("critical", false))

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
			var num_dice: int = parsed["num_dice"]
			#Both hands on a flexible melee weapon add one damage die.
			if not is_ranged and not is_throw and WeaponArmorPerkLibrary.is_flex_grip(weapon) \
					and WeaponArmorPerkLibrary.is_wielding_two_handed(attacker):
				num_dice += 1
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("TWO_HANDED: %s rolls %dd%d (+1 die)" % [
						attacker.merc_name, num_dice, int(parsed["die_sides"])])
			var threshold := float(check_result["threshold"])
			var die_threshold := floori(threshold / 100.0 * float(parsed["die_sides"]))
			for _d: int in range(num_dice):
				if randi_range(1, parsed["die_sides"]) <= die_threshold:
					weapon_die_successes += 1

	var ammo_name: String = attacker.ammo_loaded_type if is_ranged else ""

	if is_ranged:
		attacker.ammo_loaded -= 1
		if weapon.chamber <= 0 and attacker.ammo_loaded_type != "":
			var _inv: int = attacker.ammo_inventory.get(attacker.ammo_loaded_type, 0)
			if _inv > 0:
				attacker.ammo_inventory[attacker.ammo_loaded_type] = _inv - 1
				if attacker.ammo_inventory[attacker.ammo_loaded_type] <= 0:
					attacker.ammo_inventory.erase(attacker.ammo_loaded_type)
		if weapon.misfire > 0 and core_successes < weapon.misfire and not critical:
			EncounterLogger.log_misfire_check(attacker.merc_name, weapon.item_name, weapon.misfire, core_successes, true)
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
				"weapon_broke": false,
				"no_los": false,
				"window_lines": [] as Array[String],
				"enhancements": total_enhancements,
				"flaws": total_flaws,
				"is_throw": is_throw,
				"critical": critical,
				"ammo_name": ammo_name,
			}
		elif weapon.misfire > 0:
			var crit_saved := critical and core_successes < weapon.misfire
			EncounterLogger.log_misfire_check(attacker.merc_name, weapon.item_name, weapon.misfire, core_successes, false, crit_saved)
			if crit_saved and EncounterLogger.is_active():
				EncounterLogger.log_verbose("MISFIRE SAVED: %s %s crit successes=%d need=%d" % [
					attacker.merc_name, weapon.item_name, core_successes, weapon.misfire])

	var window_lines: Array[String] = []
	for wp: Vector3i in los_windows:
		if state.battlefield.break_window(Vector2i(wp.x, wp.y), wp.z):
			var wl := "  The shot shatters a window at (%d,%d) F%d." % [wp.x, wp.y, wp.z]
			window_lines.append(wl)
			if EncounterLogger.is_active():
				EncounterLogger.log_line(wl)

	var weapon_broke := false
	if weapon != null and weapon.fragility > 0 and weapon.current_fragility > 0:
		weapon_broke = _roll_fragility(weapon)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("FRAGILITY: %s cf=%d/%d -> %s" % [
				weapon.item_name, weapon.current_fragility, weapon.fragility,
				"BROKE" if weapon_broke else "survived"])

	var result := _empty_attack_result(damage_type, false, false, is_throw)
	result["damage"] = core_successes + weapon_die_successes + flat_bonus
	result["core_successes"] = core_successes
	result["weapon_die_successes"] = weapon_die_successes
	result["flat_bonus"] = flat_bonus
	result["dmg_formula"] = dmg_formula
	result["check_result"] = check_result
	result["stat_used"] = check_result["stat_used"]
	result["threshold"] = check_result["threshold"]
	result["weapon_broke"] = weapon_broke
	result["window_lines"] = window_lines
	result["enhancements"] = total_enhancements
	result["flaws"] = total_flaws
	result["critical"] = critical
	result["ammo_name"] = ammo_name
	return result


static func _roll_fragility(weapon: WeaponData) -> bool:
	var threshold: int = _CONFIG.fragility_success_threshold
	var successes := 0
	for _i: int in range(weapon.current_fragility):
		if randi_range(1, 6) >= threshold:
			successes += 1
	if successes > 0:
		weapon.current_fragility -= 1
		return false
	return true


static func _empty_attack_result(damage_type: String, no_ammo: bool, misfired: bool,
		is_throw: bool = false) -> Dictionary:
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
		"weapon_broke": false,
		"no_los": false,
		"window_lines": [] as Array[String],
		"enhancements": 0,
		"flaws": 0,
		"is_throw": is_throw,
		"critical": false,
		"ammo_name": "",
	}


static func _pick_damage_type(types: Array[String]) -> String:
	if types.is_empty():
		return "Strike"
	if types.size() == 1:
		return types[0]
	return types[randi() % types.size()]


#Core dice of an attack check: the stat the weapon's Heavy or Light property selects, else the larger of the two.
static func attack_pool_size(attacker: MercenaryData, weapon: WeaponData) -> int:
	var pool := 0
	for key: String in attack_stat_keys(weapon):
		pool = maxi(pool, int(attacker.stats.get(key, 0)))
	return maxi(1, pool)


#Stat keys an attack rolls: Heavy alone picks vigor, Light alone dexterity, otherwise both.
static func attack_stat_keys(weapon: WeaponData) -> Array[String]:
	if weapon != null and weapon.has_heavy and not weapon.has_light:
		return ["vigor"]
	if weapon != null and weapon.has_light and not weapon.has_heavy:
		return ["dexterity"]
	return ["dexterity", "vigor"]


#Attack circumstance name for one stat key.
static func attack_circumstance(stat_key: String) -> String:
	if stat_key == "vigor":
		return ConstCircumstances.ATTACK_VIGOR
	return ConstCircumstances.ATTACK_DEXTERITY


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


#Total weapon_enhance value carried by the attacker's weapon passive perks.
static func get_weapon_enhance_bonus(merc: MercenaryData) -> int:
	var total: int = 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_enhance:"):
			var value_str: String = perk.effect_dsl.substr(len("weapon_enhance:"))
			total += value_str.to_int()
	return total


#Flaws the shot takes from cover and from firing beyond the weapon's designed range.
static func compute_attack_flaws(
		attacker: MercenaryData,
		target: MercenaryData,
		state: BattleState) -> int:
	if state.battlefield == null:
		return 0
	var flaws := 0
	var los := LineOfSight.check(state, attacker, target)
	if str(los["cover"]) == "partial":
		flaws += 1
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("COVER FLAW: %s partial cover from %s (%s)" % [
				target.merc_name, attacker.merc_name, str(los["via"])])
	var weapon := attacker.equipped_weapon
	if weapon == null:
		return flaws
	var dist := state.distance_to(attacker, target)
	var ignore_ext_range: bool = WeaponArmorPerkLibrary.has_weapon_passive(attacker, "weapon_passive:ignore_flaw_extended_range")
	if weapon.is_ranged and weapon.ranged_intended_range > 0:
		if dist > weapon.ranged_intended_range and not ignore_ext_range:
			return flaws + 1
	elif weapon.is_throwable:
		var t_ranges := ThrownWeaponRules.thrown_ranges(attacker, weapon)
		var effective_max: int = int(t_ranges["extended"])
		if dist > effective_max:
			return flaws + 10
		if weapon.thrown_intended_range > 0 and not ignore_ext_range \
				and dist > weapon.thrown_intended_range:
			return flaws + 1
	elif dist > WeaponArmorPerkLibrary.get_effective_melee_range(attacker):
		#An object throw has no designed range: the halved thrown_range is the only limit.
		if dist > int(ThrownWeaponRules.compute_thrown_range(attacker, weapon) / 2.0):
			return flaws + 10
		return flaws + 1
	return flaws
