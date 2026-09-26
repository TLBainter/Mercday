class_name CheckDemos
extends RefCounted

#Console demos for the check, attack and damage systems over a roster.


const CHECK_DEFS: Dictionary = {
	"DEFEND CHECK (Dexterity)": {
		"stat_keys": ["dexterity"],
		"circumstances": [],
		"knowledges": [],
		"tools": [],
		"formula": "defend",
	},
	"URBAN CHECK (Cognition)": {
		"stat_keys": ["cognition"],
		"circumstances": ["Search (Cognition)"],
		"knowledges": [],
		"tools": [],
		"formula": "urban",
	},
	"MONSTER HUNT CHECK (Vigor)": {
		"stat_keys": ["vigor"],
		"circumstances": ["Athletics (Vigor)"],
		"knowledges": [],
		"tools": [],
		"formula": "monster_hunt",
	},
	"SOCIAL CHECK (Wile)": {
		"stat_keys": ["wile"],
		"circumstances": ["Speech (Wile)", "Performance (Wile)"],
		"knowledges": [],
		"tools": [],
		"formula": "social",
	},
	"POISON CHECK (Dexterity / Wile)": {
		"stat_keys": ["dexterity", "wile"],
		"circumstances": ["Finesse (Dexterity)", "Performance (Wile)"],
		"knowledges": ["Toxicology", "Tactics", "Botany"],
		"tools": ["Assassin's", "Poisoner's", "Herbologist's"],
		"formula": "((assassinate + espionage) / 2.0) - 40",
	},
	"PUT ON A SHOW CHECK (Wile / Dexterity)": {
		"stat_keys": ["wile", "dexterity"],
		"circumstances": ["Performance (Dexterity)", "Performance (Wile)", "Grace (Dexterity)", "Presence (Wile)", "Speech (Wile)"],
		"knowledges": ["Comedy", "Dancing", "Dramaturgy", "Music", "Illustromancy", "Magic"],
		"tools": ["Musician's", "Cinematographer's", "Dealer's"],
		"formula": "entertain - (rand_factor * 10.0)",
	},
}


#Prints the banner for one named demo check and runs it for every merc.
static func named_check(label: String, mercs: Array[MercenaryData]) -> void:
	if not CHECK_DEFS.has(label):
		print("Unknown check: %s" % label)
		return
	print("
====== %s ======
" % label)
	var check_def: Dictionary = (CHECK_DEFS[label] as Dictionary).duplicate(true)
	for merc: MercenaryData in mercs:
		_run_check(merc, check_def)


static func _run_check(merc: MercenaryData, check_def: Dictionary) -> void:
	var result: Dictionary = CheckSystem.make_check(merc, check_def)
	var rerolls := int(result["rerolls"])
	var k_bonus := int(result["k_bonus"])
	var t_bonus := int(result["t_bonus"])
	var threshold := float(result["threshold"])
	print("%s" % merc.merc_name)
	var bonus_parts: Array[String] = []
	if k_bonus > 0:
		bonus_parts.append("K+1")
	if t_bonus > 0:
		bonus_parts.append("T+1")
	var bonus_str := (" [%s]" % ", ".join(bonus_parts)) if bonus_parts.size() > 0 else ""
	print("  Stat: %-12s Threshold: %.1f%%%s" % [str(result["stat_used"]), threshold, bonus_str])
	print_rich("  Roll 1:  %s" % MercSheetPrinter.fmt_rolls(result["roll1"] as Array, threshold))
	if rerolls > 0:
		print("  Rerolls: %d" % rerolls)
		print_rich("  Roll 2:  %s" % MercSheetPrinter.fmt_rolls(result["roll2"] as Array, threshold))
	var successes := int(result["successes"])
	var failures := int(result["failures"])
	var s_str := "[color=green]%d[/color]" % successes if successes > 0 else str(successes)
	var f_str := "[color=red]%d[/color]" % failures if failures > 0 else str(failures)
	print_rich("  Result:  %s successes / %s failures\n" % [s_str, f_str])
	if bool(result.get("critical", false)):
		print_rich("  [color=yellow]** CRITICAL SUCCESS! **[/color]  %s gained: %s\n" % [
			merc.merc_name, str(result.get("crit_reward", ""))])


static func attack_check(mercs: Array[MercenaryData]) -> void:
	print("\n====== ATTACK CHECK ======\n")
	for merc: MercenaryData in mercs:
		_run_attack_check(merc)


static func _run_attack_check(merc: MercenaryData) -> void:
	var weapon: WeaponData = merc.equipped_weapon

	var stat_keys: Array[String] = []
	var circumstances: Array[String] = []
	if weapon != null and weapon.has_heavy and not weapon.has_light:
		stat_keys = ["vigor"]
		circumstances = ["Attack (Vigor)"]
	elif weapon != null and weapon.has_light and not weapon.has_heavy:
		stat_keys = ["dexterity"]
		circumstances = ["Attack (Dexterity)"]
	else:
		stat_keys = ["dexterity", "vigor"]
		circumstances = ["Attack (Dexterity)", "Attack (Vigor)"]

	var accuracy_formula: String = "ranged_accuracy" if (weapon != null and weapon.is_ranged) else "melee_accuracy"

	var check_def := {
		"stat_keys": stat_keys,
		"circumstances": circumstances,
		"knowledges": [],
		"tools": [],
		"formula": accuracy_formula,
	}

	var core_result: Dictionary = CheckSystem.make_check(merc, check_def)
	var core_successes: int = int(core_result["successes"])
	var threshold: float = float(core_result["threshold"])
	var stat_used: String = str(core_result["stat_used"])
	var rerolls: int = int(core_result["rerolls"])
	var k_bonus: int = int(core_result["k_bonus"])
	var t_bonus: int = int(core_result["t_bonus"])

	var dice: Dictionary = _roll_weapon_dice(weapon, threshold)
	var weapon_die_successes: int = dice["successes"]
	var weapon_flat_bonus: int = dice["flat_bonus"]
	var weapon_die_label: String = dice["label"]
	var dmg_formula: String = dice["formula"]
	var dmg_type: String = dice["dmg_type"]

	var total_successes: int = core_successes + weapon_die_successes + weapon_flat_bonus

	var weapon_name: String = weapon.item_name if weapon != null else "(unarmed)"
	var weapon_type_str: String = weapon.weapon_type if weapon != null else ""
	var bonus_parts: Array[String] = []
	if k_bonus > 0:
		bonus_parts.append("K+1")
	if t_bonus > 0:
		bonus_parts.append("T+1")
	var bonus_str: String = (" [%s]" % ", ".join(bonus_parts)) if bonus_parts.size() > 0 else ""

	print("%s" % merc.merc_name)
	print("  Weapon:     %s  (%s)" % [weapon_name, weapon_type_str])
	print("  Stat:       %-12s  Threshold: %.1f%%%s" % [stat_used, threshold, bonus_str])
	print_rich("  Roll 1:     %s" % MercSheetPrinter.fmt_rolls(core_result["roll1"] as Array, threshold))
	if rerolls > 0:
		print("  Rerolls:    %d" % rerolls)
		print_rich("  Roll 2:     %s" % MercSheetPrinter.fmt_rolls(core_result["roll2"] as Array, threshold))
	var core_s_str: String = "[color=green]%d[/color]" % core_successes if core_successes > 0 else str(core_successes)
	var core_f_str: String = "[color=red]%d[/color]" % int(core_result["failures"]) if int(core_result["failures"]) > 0 else str(int(core_result["failures"]))
	print_rich("  Core:       %s successes / %s failures" % [core_s_str, core_f_str])
	print_rich("  Weapon Die: %s  (formula: %s)" % [weapon_die_label, dmg_formula])
	if weapon_flat_bonus > 0:
		print("  Flat Bonus: +%d" % weapon_flat_bonus)
	print("  Dmg Type:   %s" % dmg_type)
	var total_color: String = "yellow" if total_successes > 0 else "white"
	print_rich("  Total Dmg:  [color=%s]%d[/color]  (core: %d + weapon dice: %d + flat: %d)\n" % [
		total_color, total_successes, core_successes, weapon_die_successes, weapon_flat_bonus
	])


#Damage type pick and damage dice of one weapon; keys successes, flat_bonus, label, formula, dmg_type.
static func _roll_weapon_dice(weapon: WeaponData, threshold: float) -> Dictionary:
	var out: Dictionary = {
		"successes": 0,
		"flat_bonus": 0,
		"label": "(no weapon)",
		"formula": "",
		"dmg_type": "(none)",
	}
	if weapon == null:
		return out
	var dmg_formula: String = weapon.damage_formula_1
	out["formula"] = dmg_formula
	if weapon.damage_types_1.size() > 1:
		out["dmg_type"] = weapon.damage_types_1[randi() % weapon.damage_types_1.size()]
	elif weapon.damage_types_1.size() == 1:
		out["dmg_type"] = weapon.damage_types_1[0]
	else:
		out["dmg_type"] = "Unknown"
	var parsed: Dictionary = AttackSystem._parse_damage_formula(dmg_formula)
	out["flat_bonus"] = parsed["flat_bonus"]
	if parsed["is_todo"]:
		out["label"] = dmg_formula + "  [#TODO: ammunition]"
		return out
	var num_dice: int = parsed["num_dice"]
	var die_sides: int = parsed["die_sides"]
	var die_threshold: int = floori(threshold / 100.0 * float(die_sides))
	var rolls: Array[int] = []
	var successes: int = 0
	for _d: int in range(num_dice):
		var roll_val: int = randi_range(1, die_sides)
		rolls.append(roll_val)
		if roll_val <= die_threshold:
			successes += 1
	out["successes"] = successes
	out["label"] = MercSheetPrinter.fmt_weapon_dice(rolls, die_threshold, die_sides)
	return out


static func damage_check(mercs: Array[MercenaryData]) -> void:
	var raw_damage: int = randi_range(1, 4)
	var all_types: Array = ConstDamageTypes.all_type_names()
	var damage_type: String = all_types[randi() % all_types.size()]
	var type_data: Dictionary = ConstDamageTypes.get_type(damage_type)
	print("\n====== DAMAGE CHECK  -  %d %s (%s) ======\n" % [raw_damage, damage_type, type_data.get("category", "?")])
	for merc: MercenaryData in mercs:
		_run_damage_check(merc, raw_damage, damage_type)


static func _run_damage_check(merc: MercenaryData, raw_damage: int, damage_type: String) -> void:
	var max_hp: int = int(merc.stats.get("maximum_hit_points", 1))
	var max_ep: int = int(merc.stats.get("maximum_endurance_points", 1))
	var hp_before: int = merc.current_hp
	var ep_before: int = merc.current_ep

	var res: Dictionary = DefenseSystem.resolve(merc, raw_damage, damage_type)

	print("%s   (HP: %d/%d  EP: %d/%d)" % [merc.merc_name, maxi(0, hp_before), max_hp, ep_before, max_ep])

	if res["is_immune"]:
		print_rich("  [color=cyan]IMMUNE  -  no damage taken.[/color]\n")
		return

	match str(res["modifier"]):
		"susceptible":
			print_rich("  Modifier:   [color=yellow]SUSCEPTIBLE[/color]  %d x 2 = %d" % [raw_damage, res["modified_damage"]])
		"protected":
			print_rich("  Modifier:   [color=cyan]PROTECTED[/color]  %d / 2 = %d" % [raw_damage, res["modified_damage"]])
		_:
			print("  Modifier:   none")

	var is_direct: bool = res["is_direct"]
	var fire_first: bool = res["direct_portion"] > 0 and not is_direct

	if is_direct:
		print_rich("  [color=orange]DIRECT (%s)  -  defense bypassed.[/color]" % damage_type)
	elif fire_first:
		print("  Fire split: 1 direct + %d reducible" % res["reducible"])

	if not is_direct and res["reducible"] > 0:
		if ep_before <= 0:
			print_rich("  [color=red]No EP  -  cannot defend. Full damage taken.[/color]")
		else:
			print("  EP spent:   1  (%d -> %d)" % [ep_before, merc.current_ep])

			var def_result: Dictionary = res["defend_result"]
			if def_result.is_empty():
				print_rich("  Defend:     [color=gray]blocked (%s)[/color]" % damage_type)
			else:
				var def_threshold: float = float(def_result["threshold"])
				var raw_suc: int = int(def_result["successes"])
				var final_suc: int = res["defend_reduction"]
				var halved_note: String = "  (halved -> %d)" % final_suc if raw_suc != final_suc else ""
				print_rich("  Defend:     %s  threshold: %.1f%%  -> %d successes%s" % [
					MercSheetPrinter.fmt_rolls(def_result["roll1"] as Array, def_threshold), def_threshold, raw_suc, halved_note
				])

			var dodge_result: Dictionary = res["dodge_result"]
			if dodge_result.is_empty():
				print_rich("  Dodge:      [color=gray]blocked (%s)[/color]" % damage_type)
			else:
				var dodge_threshold: float = float(dodge_result["threshold"])
				print_rich("  Dodge:      %s  threshold: %.1f%%  -> %d successes" % [
					MercSheetPrinter.fmt_rolls(dodge_result["roll1"] as Array, dodge_threshold), dodge_threshold, res["dodge_reduction"]
				])

			var src: String = res["reduction_source"]
			print("  Best:       %s (%d reduction)" % [src, res["best_reduction"]])
			print("  Reducible:  %d - %d = %d" % [res["reducible"], res["best_reduction"], res["final_reducible"]])

	var final_dmg: int = res["final_damage"]
	var dmg_color: String = "red" if final_dmg > 0 else "white"
	print_rich("  Final Dmg:  [color=%s]%d[/color]" % [dmg_color, final_dmg])
	print("  HP:         %d -> %d   EP: %d -> %d\n" % [maxi(0, hp_before), maxi(0, merc.current_hp), ep_before, merc.current_ep])

	if merc.current_hp <= 0:
		print_rich("[color=red]*** %s has been reduced to 0 HP! ***[/color]\n" % merc.merc_name)


static func drop_mercs(mercs: Array[MercenaryData]) -> void:
	print("\n====== DROP MERCS ======\n")
	var team_a: Array[MercenaryData] = []
	team_a.assign(mercs)
	var empty_team: Array[MercenaryData] = []
	var state := BattleState.create(team_a, empty_team, null)
	for merc: MercenaryData in mercs:
		var fall_distance := randi_range(1, 6)
		state.set_height(merc, fall_distance)
		print_rich("  [color=cyan]%s dropped from height %d[/color]" % [merc.merc_name, fall_distance])
		var lines := CombatApplicator.resolve_fall(merc, fall_distance, state)
		for line: String in lines:
			print_rich(line)
		state.set_height(merc, 0)
