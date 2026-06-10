extends Node

const _ThrownWeaponsTest := preload("res://Scripts/Tests/ThrownWeaponsTest.gd")

@export var reroll_mercs: NodePath
@export var add_merc: NodePath
@export var remove_merc: NodePath
@export var reroll_names: NodePath
@export var add_taverngoer: NodePath
@export var defend_check: NodePath
@export var urban_check: NodePath
@export var monster_hunt_check: NodePath
@export var social_check: NodePath
@export var poison_check: NodePath
@export var put_on_a_show_check: NodePath
@export var batch_analysis: NodePath
@export var attack_check: NodePath
@export var damage_check: NodePath
@export var start_battle: NodePath
@export var drop_mercs: NodePath
@export var makeshift_test: NodePath
@export var thrown_test: NodePath
@export var gen_outhouse_map: NodePath
@export var gen_terrain_batch: NodePath

var mercs: Array[MercenaryData] = []

var _battle_state: BattleState = null
var _battle_line_fn: Callable
var _battle_team_a: Array[MercenaryData] = []
var _battle_team_b: Array[MercenaryData] = []


func _ready() -> void:
	(get_node(reroll_mercs) as Button).pressed.connect(_on_reroll_mercs)
	(get_node(add_merc) as Button).pressed.connect(_on_add_merc)
	(get_node(remove_merc) as Button).pressed.connect(_on_remove_merc)
	(get_node(reroll_names) as Button).pressed.connect(_on_reroll_names)
	(get_node(add_taverngoer) as Button).pressed.connect(_on_add_taverngoer)
	(get_node(defend_check) as Button).pressed.connect(_on_defend_check)
	(get_node(urban_check) as Button).pressed.connect(_on_urban_check)
	(get_node(monster_hunt_check) as Button).pressed.connect(_on_monster_hunt_check)
	(get_node(social_check) as Button).pressed.connect(_on_social_check)
	(get_node(poison_check) as Button).pressed.connect(_on_poison_check)
	(get_node(put_on_a_show_check) as Button).pressed.connect(_on_put_on_a_show_check)
	(get_node(batch_analysis) as Button).pressed.connect(_on_batch_analysis)
	(get_node(attack_check) as Button).pressed.connect(_on_attack_check)
	(get_node(damage_check) as Button).pressed.connect(_on_damage_check)
	(get_node(start_battle) as Button).pressed.connect(_on_start_battle)
	(get_node(drop_mercs) as Button).pressed.connect(_on_drop_mercs)
	(get_node(makeshift_test) as Button).pressed.connect(_on_makeshift_test)
	(get_node(thrown_test) as Button).pressed.connect(_on_thrown_test)
	(get_node(gen_outhouse_map) as Button).pressed.connect(_on_gen_outhouse_map)
	(get_node(gen_terrain_batch) as Button).pressed.connect(_on_gen_terrain_batch)
	for i: int in range(3):
		var merc := MercGenerator.generate(i)
		mercs.append(merc)
		_print_merc(merc)


func _on_reroll_mercs() -> void:
	mercs.clear()
	print("\n====== REROLLING MERCS ======\n")
	for i: int in range(3):
		var merc := MercGenerator.generate(i)
		mercs.append(merc)
		_print_merc(merc)


func _on_add_merc() -> void:
	var merc := MercGenerator.generate(mercs.size())
	mercs.append(merc)
	print("\n====== ADDED MERC ======\n")
	_print_merc(merc)


func _on_remove_merc() -> void:
	if mercs.is_empty():
		print("No mercs to remove.")
		return
	var idx := randi() % mercs.size()
	var removed := mercs[idx]
	mercs.remove_at(idx)
	print("\n====== REMOVED MERC: %s ======\n" % removed.merc_name)


func _on_reroll_names() -> void:
	_print_regional_names()


func _on_add_taverngoer() -> void:
	var avg_level: float = 0.0
	for m: MercenaryData in mercs:
		avg_level += float(m.stats.get("level", 0))
	if mercs.size() > 0:
		avg_level /= float(mercs.size())
	var party := {"average_level": avg_level, "merc_count": mercs.size()}
	print("\n====== TAVERNGOER ======\n")
	var npc := NPCGenerator.generate_batch("Taverngoer", 1, party)
	if npc.is_empty():
		print("ERROR: NPCGenerator returned no results.")
		return
	mercs.append(npc[0])
	_print_merc(npc[0])


func _on_defend_check() -> void:
	print("\n====== DEFEND CHECK (Dexterity) ======\n")
	var check_def := {
		"stat_keys": ["dexterity"],
		"circumstances": [],
		"knowledges": [],
		"tools": [],
		"formula": "defend",
	}
	for merc: MercenaryData in mercs:
		_run_check(merc, check_def)


func _on_urban_check() -> void:
	print("\n====== URBAN CHECK (Cognition) ======\n")
	var check_def := {
		"stat_keys": ["cognition"],
		"circumstances": ["Search (Cognition)"],
		"knowledges": [],
		"tools": [],
		"formula": "urban",
	}
	for merc: MercenaryData in mercs:
		_run_check(merc, check_def)


func _on_monster_hunt_check() -> void:
	print("\n====== MONSTER HUNT CHECK (Vigor) ======\n")
	var check_def := {
		"stat_keys": ["vigor"],
		"circumstances": ["Athletics (Vigor)"],
		"knowledges": [],
		"tools": [],
		"formula": "monster_hunt",
	}
	for merc: MercenaryData in mercs:
		_run_check(merc, check_def)


func _on_social_check() -> void:
	print("\n====== SOCIAL CHECK (Wile) ======\n")
	var check_def := {
		"stat_keys": ["wile"],
		"circumstances": ["Speech (Wile)", "Performance (Wile)"],
		"knowledges": [],
		"tools": [],
		"formula": "social",
	}
	for merc: MercenaryData in mercs:
		_run_check(merc, check_def)


func _on_poison_check() -> void:
	print("\n====== POISON CHECK (Dexterity / Wile) ======\n")
	var check_def := {
		"stat_keys": ["dexterity", "wile"],
		"circumstances": ["Finesse (Dexterity)", "Performance (Wile)"],
		"knowledges": ["Toxicology", "Tactics", "Botany"],
		"tools": ["Assassin's", "Poisoner's", "Herbologist's"],
		"formula": "((assassinate + espionage) / 2.0) - 40",
	}
	for merc: MercenaryData in mercs:
		_run_check(merc, check_def)


func _on_put_on_a_show_check() -> void:
	print("\n====== PUT ON A SHOW CHECK (Wile / Dexterity) ======\n")
	var check_def := {
		"stat_keys": ["wile", "dexterity"],
		"circumstances": ["Performance (Dexterity)", "Performance (Wile)", "Grace (Dexterity)", "Presence (Wile)", "Speech (Wile)"],
		"knowledges": ["Comedy", "Dancing", "Dramaturgy", "Music", "Illustromancy", "Magic"],
		"tools": ["Musician's", "Cinematographer's", "Dealer's"],
		"formula": "entertain - (rand_factor * 10.0)",
	}
	for merc: MercenaryData in mercs:
		_run_check(merc, check_def)


func _run_check(merc: MercenaryData, check_def: Dictionary) -> void:
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
	print_rich("  Roll 1:  %s" % _fmt_rolls(result["roll1"] as Array, threshold))
	if rerolls > 0:
		print("  Rerolls: %d" % rerolls)
		print_rich("  Roll 2:  %s" % _fmt_rolls(result["roll2"] as Array, threshold))
	var successes := int(result["successes"])
	var failures := int(result["failures"])
	var s_str := "[color=green]%d[/color]" % successes if successes > 0 else str(successes)
	var f_str := "[color=red]%d[/color]" % failures if failures > 0 else str(failures)
	print_rich("  Result:  %s successes / %s failures\n" % [s_str, f_str])
	if CriticalSuccessSystem.is_critical_success(result, merc):
		var pool: Array = CriticalSuccessSystem.build_option_pool(result, merc, check_def)
		var reward: String = CriticalSuccessSystem.roll_and_apply(merc, pool)
		print_rich("  [color=yellow]** CRITICAL SUCCESS! **[/color]  %s gained: %s\n" % [merc.merc_name, reward])


func _print_regional_names() -> void:
	print("\n====== REGIONAL NAME SAMPLES ======\n")
	for region: String in NameGenerator.get_regions():
		print("--- %s ---" % region)
		for _i: int in range(10):
			print("  " + NameGenerator.generate_for_region(region))
		print("")


func _on_batch_analysis() -> void:
	print("Generating batch of 100 mercs...")
	var tally: Dictionary = {}
	var luck_buckets: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	var merc_blocks := ""
	for i: int in range(100):
		var merc := MercGenerator.generate(i)
		var trad_name: String = merc.tradition.tradition_name if merc.tradition else "(none)"
		tally[trad_name] = tally.get(trad_name, 0) + 1
		var lr: float = merc.luck_roll
		if lr < 5.0:
			luck_buckets[0] += 1
		elif lr < 10.0:
			luck_buckets[1] += 1
		elif lr < 20.0:
			luck_buckets[2] += 1
		elif lr < 30.0:
			luck_buckets[3] += 1
		elif lr < 40.0:
			luck_buckets[4] += 1
		elif lr < 50.0:
			luck_buckets[5] += 1
		else:
			luck_buckets[6] += 1
		merc_blocks += _merc_to_string(merc)

	var sorted_keys: Array = tally.keys()
	sorted_keys.sort_custom(func(a: String, b: String) -> bool: return tally[a] > tally[b])

	var summary := "BATCH ANALYSIS - 100 MERCS\n"
	summary += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	summary += "====== TRADITION TALLY ======\n"
	for trad: String in sorted_keys:
		summary += "  %-20s %d\n" % [trad + ":", tally[trad]]
	summary += "\n"
	summary += "====== LUCK ROLL DISTRIBUTION (expected) ======\n"
	summary += "  0- 5:  %3d%%  (expected ~45%%)\n" % luck_buckets[0]
	summary += "  5-10:  %3d%%  (expected ~20%%)\n" % luck_buckets[1]
	summary += " 10-20:  %3d%%  (expected ~15%%)\n" % luck_buckets[2]
	summary += " 20-30:  %3d%%  (expected ~10%%)\n" % luck_buckets[3]
	summary += " 30-40:  %3d%%  (expected  ~9%%)\n" % luck_buckets[4]
	summary += " 40-50:  %3d%%  (expected  ~1%%)\n" % luck_buckets[5]
	summary += "    50:  %3d%%  (expected ~0%%)\n" % luck_buckets[6]
	summary += "\n\n"

	var path := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/merc_batch_analysis.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("ERROR: Could not open file for writing: " + path)
		return
	file.store_string(summary + merc_blocks)
	file.close()

	print("Batch written to: " + path)
	print("Tradition tally:")
	for trad: String in sorted_keys:
		print("  %-20s %d" % [trad + ":", tally[trad]])
	print("Luck roll distribution (expected):")
	print("   0- 5:  %3d%%  (expected ~45%%)" % luck_buckets[0])
	print("   5-10:  %3d%%  (expected ~20%%)" % luck_buckets[1])
	print("  10-20:  %3d%%  (expected ~15%%)" % luck_buckets[2])
	print("  20-30:  %3d%%  (expected ~10%%)" % luck_buckets[3])
	print("  30-40:  %3d%%  (expected  ~9%%)" % luck_buckets[4])
	print("  40-50:  %3d%%  (expected  ~1%%)" % luck_buckets[5])
	print("     50:  %3d%%  (expected ~0%%)" % luck_buckets[6])


func _print_merc(merc: MercenaryData) -> void:
	print_rich(_merc_to_string(merc))


func _merc_to_string(merc: MercenaryData) -> String:
	var sep := "======================================"
	var lines: Array[String] = []
	lines.append(sep)
	lines.append("  %s" % merc.merc_name.to_upper())
	lines.append(sep)

	var loc_line := "(none)"
	if merc.starting_location:
		var loc := merc.starting_location
		var parent_name := loc.parent.location_name if loc.parent else ""
		loc_line = "%s (%s%s)" % [
			loc.location_name,
			loc.location_type,
			(", " + parent_name) if parent_name != "" else ""
		]
	lines.append("Location:     %s" % loc_line)
	if merc.is_hybrid:
		lines.append("Ancestry:     %s / %s" % [merc.ancestry.ancestry_name, merc.recessive_ancestry.ancestry_name])
		lines.append("Bloodline:    %s / %s" % [
			(merc.bloodline.ancestry_name if merc.bloodline else "Core"),
			(merc.recessive_bloodline.ancestry_name if merc.recessive_bloodline else "Core")
		])
	else:
		lines.append("Ancestry:     %s" % (merc.ancestry.ancestry_name if merc.ancestry else "(none)"))
		lines.append("Bloodline:    %s" % (merc.bloodline.ancestry_name if merc.bloodline else "Core"))
	lines.append("Types:        %s" % (", ".join(merc.creature_types) if merc.creature_types.size() > 0 else "(none)"))
	lines.append("Heritage:     %s" % (merc.heritage.heritage_name if merc.heritage else "(none)"))

	var circ_names: Array[String] = []
	for display_name: String in merc.circumstance_flags:
		if merc.circumstance_flags[display_name]:
			var bonus: float = merc.circumstance_additional_bonus.get(display_name, 0.0)
			circ_names.append(display_name + (" (+%.0f%%)" % bonus if bonus > 0.0 else ""))
	lines.append("Circumstances: %s" % (", ".join(circ_names) if circ_names.size() > 0 else "(none)"))

	var k_names: Array[String] = []
	for k: UtilityTraitData in merc.knowledges:
		k_names.append(k.utility_name)
	lines.append("Knowledges:   %s" % (", ".join(k_names) if k_names.size() > 0 else "(none)"))

	var t_names: Array[String] = []
	for t: UtilityTraitData in merc.tools:
		t_names.append(t.utility_name)
	lines.append("Tools:        %s" % (", ".join(t_names) if t_names.size() > 0 else "(none)"))

	var lp_names: Array[String] = []
	for lp: LifepathData in merc.lifepaths:
		lp_names.append(lp.event_name)
	lines.append("Lifepath:     %s" % (", ".join(lp_names) if lp_names.size() > 0 else "(none)"))

	lines.append("====EQUIPMENT====")

	var armor_str := "(none)"
	if merc.equipped_armor:
		armor_str = "%s  (%s, +%d DR)" % [
			merc.equipped_armor.item_name,
			merc.equipped_armor.armor_type,
			merc.equipped_armor.armor_bonus
		]
	lines.append("Armor:        %s" % armor_str)

	var weapon_lines: Array[String] = []
	if merc.equipped_weapon != null:
		var w := merc.equipped_weapon
		weapon_lines.append("[color=cyan][E][/color] %s  (%s)  Draw:%d" % [w.item_name, w.weapon_type, w.draw])
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			var w: WeaponData = entry.get("data")
			if w != null:
				weapon_lines.append("    %s  (%s)  Draw:%d" % [w.item_name, w.weapon_type, w.draw])
	if weapon_lines.is_empty():
		lines.append("Weapons:      (none)")
	else:
		lines.append("Weapons:      %s" % weapon_lines[0])
		for i: int in range(1, weapon_lines.size()):
			lines.append("              %s" % weapon_lines[i])

	var ammo_parts: Array[String] = []
	var shown_loaded := false
	for ammo_name: String in merc.ammo_inventory:
		var count: int = merc.ammo_inventory[ammo_name]
		if ammo_name == merc.ammo_loaded_type and merc.ammo_loaded > 0:
			ammo_parts.append("%s x%d  (%d loaded)" % [ammo_name, count, merc.ammo_loaded])
			shown_loaded = true
		else:
			ammo_parts.append("%s x%d" % [ammo_name, count])
	if merc.ammo_loaded > 0 and not shown_loaded:
		ammo_parts.append("%s  (%d loaded, no reserve)" % [merc.ammo_loaded_type, merc.ammo_loaded])
	lines.append("Ammo:         %s" % (", ".join(ammo_parts) if not ammo_parts.is_empty() else "(none)"))

	var item_parts: Array[String] = []
	for item in merc.items:
		if item is Dictionary:
			item_parts.append(item.get("item_name", "?") as String)
	lines.append("Items:        %s" % (", ".join(item_parts) if not item_parts.is_empty() else "(none)"))

	lines.append("Tradition:    %s" % (merc.tradition.tradition_name if merc.tradition else "(none)"))

	var perk_names: Array[String] = []
	for trait_item: TraitData in merc.perks:
		perk_names.append(trait_item.trait_name)
	lines.append("Perks:        %s" % ((" | ".join(perk_names)) if perk_names.size() > 0 else "(none)"))

	var drawback_names: Array[String] = []
	for trait_item: TraitData in merc.drawbacks:
		drawback_names.append(trait_item.trait_name)
	lines.append("Drawbacks:    %s" % ((" | ".join(drawback_names)) if drawback_names.size() > 0 else "(none)"))

	var desc_names: Array[String] = []
	for trait_item: TraitData in merc.descriptors:
		desc_names.append(trait_item.trait_name)
	lines.append("Descriptors:  %s" % ((" | ".join(desc_names)) if desc_names.size() > 0 else "(none)"))

	lines.append("")
	lines.append("======== STATS ===========================")
	lines.append(("Current HP:").rpad(30) + " " + str(merc.current_hp).lpad(3, "0") + " / " + str(int(merc.stats.get("maximum_hit_points", 0))).lpad(3, "0"))
	lines.append(("Current EP:").rpad(30) + " " + str(merc.current_ep).lpad(3, "0") + " / " + str(int(merc.stats.get("maximum_endurance_points", 0))).lpad(3, "0"))
	lines.append(("Current MP:").rpad(30) + " " + str(merc.current_mp).lpad(3, "0") + " / " + str(int(merc.stats.get("maximum_magic_points", 0))).lpad(3, "0"))
	lines.append(("Current AP:").rpad(30) + " " + str(merc.current_ap).lpad(3, "0") + " / " + str(int(merc.stats.get("action_points", 0))).lpad(3, "0"))

	for stat_def: Dictionary in DataManager.stat_definitions:
		var var_name: String = stat_def["var_name"]
		var stat_type: String = stat_def["type"]
		var raw_val = merc.stats.get(var_name, 0)
		var label: String = stat_def["stat"]

		match stat_type:
			"core":
				var raw_max = merc.stats.get("max_" + var_name, 0)
				lines.append((label + ":").rpad(30) + " " + _fmt_val(raw_val) + " / " + _fmt_val(raw_max))
			"boolean":
				lines.append((label + ":").rpad(30) + " " + ("TRUE" if float(raw_val) > 0.0 else "FALSE"))
			_:
				lines.append((label + ":").rpad(30) + " " + _fmt_val(raw_val))

	lines.append(sep)
	lines.append("")
	return "\n".join(lines)


func _print_check_test(merc: MercenaryData) -> void:
	var check_def := {
		"stat_keys": ["vigor", "dexterity"],
		"circumstances": ["Attack (Vigor)", "Attack (Dexterity)"],
		"knowledges": [],
		"tools": [],
		"formula": "30",
	}
	var result: Dictionary = CheckSystem.make_check(merc, check_def)
	var threshold := float(result["threshold"])
	print("======== COMBAT CHECK TEST =================")
	print("  Stat: %-12s Threshold: %.1f%%" % [str(result["stat_used"]), threshold])
	var rerolls := int(result["rerolls"])
	print_rich("  Roll 1:     %s" % _fmt_rolls(result["roll1"] as Array, threshold))
	if rerolls > 0:
		print("  Rerolls:    %d" % rerolls)
		print_rich("  Roll 2:     %s" % _fmt_rolls(result["roll2"] as Array, threshold))
	var successes := int(result["successes"])
	var failures := int(result["failures"])
	var s_str := "[color=green]%d[/color]" % successes if successes > 0 else str(successes)
	var f_str := "[color=red]%d[/color]" % failures if failures > 0 else str(failures)
	print_rich("  Result:     %s successes / %s failures" % [s_str, f_str])
	print("")


func _fmt_rolls(rolls: Array, threshold: float) -> String:
	var parts: Array[String] = []
	for r: Variant in rolls:
		if r is int:
			var val := r as int
			var color := "green" if float(val) <= threshold else "red"
			parts.append("[color=%s]%d[/color]" % [color, val])
		else:
			var pair := r as Array
			var kept := pair[1] as int
			var color := "green" if float(kept) <= threshold else "red"
			parts.append("[color=%s]%d/%d[/color]" % [color, pair[0], pair[1]])
	return "[" + ", ".join(parts) + "]"


func _fmt(value: float) -> String:
	value = maxf(0.0, value)
	var s: String = "%.2f" % value
	var dot: int = s.find(".")
	return s.left(dot).lpad(3, "0") + s.substr(dot)


func _fmt_val(val) -> String:
	if val is int:
		return str(maxi(0, val)).lpad(3, "0")
	return _fmt(float(val))


func _on_attack_check() -> void:
	print("\n====== ATTACK CHECK ======\n")
	for merc: MercenaryData in mercs:
		_run_attack_check(merc)


func _run_attack_check(merc: MercenaryData) -> void:
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

	var weapon_die_successes: int = 0
	var weapon_flat_bonus: int = 0
	var weapon_die_label: String = "(no weapon)"
	var dmg_formula: String = ""
	var dmg_type: String = "(none)"

	if weapon != null:
		dmg_formula = weapon.damage_formula_1
		if weapon.damage_types_1.size() > 1:
			dmg_type = weapon.damage_types_1[randi() % weapon.damage_types_1.size()]
		elif weapon.damage_types_1.size() == 1:
			dmg_type = weapon.damage_types_1[0]
		else:
			dmg_type = "Unknown"

		var parsed: Dictionary = _parse_damage_formula(dmg_formula)
		var num_dice: int = parsed["num_dice"]
		var die_sides: int = parsed["die_sides"]
		weapon_flat_bonus = parsed["flat_bonus"]

		if parsed["is_todo"]:
			weapon_die_label = dmg_formula + "  [#TODO: ammunition]"
		else:
			var die_threshold: int = floori(threshold / 100.0 * float(die_sides))
			var rolls: Array[int] = []
			for _d: int in range(num_dice):
				var roll_val: int = randi_range(1, die_sides)
				rolls.append(roll_val)
				if roll_val <= die_threshold:
					weapon_die_successes += 1
			weapon_die_label = _fmt_weapon_dice(rolls, die_threshold, die_sides)

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
	print_rich("  Roll 1:     %s" % _fmt_rolls(core_result["roll1"] as Array, threshold))
	if rerolls > 0:
		print("  Rerolls:    %d" % rerolls)
		print_rich("  Roll 2:     %s" % _fmt_rolls(core_result["roll2"] as Array, threshold))
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


func _run_battle_loop() -> void:
	while _battle_state != null:
		var ongoing: bool = await AutoBattle.step_round(_battle_state, _battle_line_fn)
		if not ongoing:
			_print_battle_result()
			_battle_state = null


func _on_start_battle() -> void:
	if mercs.size() < 2:
		print("Need at least 2 mercs to start a battle.")
		return
	if _battle_state != null:
		print("Battle already in progress.")
		return
	print("\n====== AUTOBATTLE ======\n")
	mercs.shuffle()
	var mid: int = mercs.size() >> 1
	_battle_team_a.clear()
	_battle_team_b.clear()
	_battle_team_a.assign(mercs.slice(0, mid))
	_battle_team_b.assign(mercs.slice(mid))
	var field := BattlefieldArea.generate_random()
	_battle_state = BattleState.create(_battle_team_a, _battle_team_b, field)
	_battle_line_fn = func(s: String) -> void: print_rich(s)
	var a_names := ", ".join(_battle_team_a.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var b_names := ", ".join(_battle_team_b.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var order_parts: Array[String] = []
	for i: int in range(_battle_state.turn_queue.size()):
		var m: MercenaryData = _battle_state.turn_queue[i]
		var color := "white" if _battle_team_a.has(m) else "yellow"
		order_parts.append("[color=%s]%s[/color]" % [color, m.merc_name.get_slice(" ", 0)])
	print_rich("[color=white]Team A:[/color] %s" % a_names)
	print_rich("[color=yellow]Team B:[/color] %s" % b_names)
	print_rich("Turn order: %s" % ", ".join(order_parts))
	AutoBattle.setup(_battle_state, _battle_line_fn)
	_run_battle_loop()


func _print_battle_result() -> void:
	var winner_idx: int = _battle_state.get_winner()
	if winner_idx >= 0:
		var winning_team: Array = _battle_state.teams[winner_idx]
		var winner_names: Array[String] = []
		for m: MercenaryData in winning_team:
			winner_names.append(m.merc_name.get_slice(" ", 0))
		var w_color := "white" if winner_idx == 0 else "yellow"
		print_rich("[color=gray]=== Battle over in %d rounds ===[/color]" % _battle_state.round_number)
		print_rich("[color=%s]Team %s wins!  (%s)[/color]" % [w_color, "A" if winner_idx == 0 else "B", ", ".join(winner_names)])
	else:
		print_rich("[color=gray]=== Draw / timeout after %d rounds ===[/color]" % _battle_state.round_number)


func _on_damage_check() -> void:
	var raw_damage: int = randi_range(1, 4)
	var all_types: Array = ConstDamageTypes.all_type_names()
	var damage_type: String = all_types[randi() % all_types.size()]
	var type_data: Dictionary = ConstDamageTypes.get_type(damage_type)
	print("\n====== DAMAGE CHECK  -  %d %s (%s) ======\n" % [raw_damage, damage_type, type_data.get("category", "?")])
	for merc: MercenaryData in mercs:
		_run_damage_check(merc, raw_damage, damage_type)


func _run_damage_check(merc: MercenaryData, raw_damage: int, damage_type: String) -> void:
	var max_hp: int = int(merc.stats.get("maximum_hit_points", 1))
	var max_ep: int = int(merc.stats.get("maximum_endurance_points", 1))
	var hp_before: int = merc.current_hp
	var ep_before: int = merc.current_ep

	var res: Dictionary = DefenseSystem.resolve(merc, raw_damage, damage_type)

	print("%s   (HP: %d/%d  EP: %d/%d)" % [merc.merc_name, hp_before, max_hp, ep_before, max_ep])

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
					_fmt_rolls(def_result["roll1"] as Array, def_threshold), def_threshold, raw_suc, halved_note
				])

			var dodge_result: Dictionary = res["dodge_result"]
			if dodge_result.is_empty():
				print_rich("  Dodge:      [color=gray]blocked (%s)[/color]" % damage_type)
			else:
				var dodge_threshold: float = float(dodge_result["threshold"])
				print_rich("  Dodge:      %s  threshold: %.1f%%  -> %d successes" % [
					_fmt_rolls(dodge_result["roll1"] as Array, dodge_threshold), dodge_threshold, res["dodge_reduction"]
				])

			var src: String = res["reduction_source"]
			print("  Best:       %s (%d reduction)" % [src, res["best_reduction"]])
			print("  Reducible:  %d ? %d = %d" % [res["reducible"], res["best_reduction"], res["final_reducible"]])

	var final_dmg: int = res["final_damage"]
	var dmg_color: String = "red" if final_dmg > 0 else "white"
	print_rich("  Final Dmg:  [color=%s]%d[/color]" % [dmg_color, final_dmg])
	print("  HP:         %d -> %d   EP: %d -> %d\n" % [hp_before, merc.current_hp, ep_before, merc.current_ep])

	if merc.current_hp <= 0:
		print_rich("[color=red]*** %s has been reduced to 0 HP! ***[/color]\n" % merc.merc_name)


func _parse_damage_formula(formula: String) -> Dictionary:
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


func _on_drop_mercs() -> void:
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


func _on_thrown_test() -> void:
	if _battle_state != null:
		print("Battle already in progress.")
		return
	print("\n====== THROWN WEAPONS TEST ======\n")
	_battle_state = _ThrownWeaponsTest.create_state()
	_battle_line_fn = func(s: String) -> void: print_rich(s)
	_battle_team_a.clear()
	_battle_team_b.clear()
	_battle_team_a.assign(_battle_state.teams[0])
	_battle_team_b.assign(_battle_state.teams[1])
	var a_names := ", ".join(_battle_team_a.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var b_names := ", ".join(_battle_team_b.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	print_rich("[color=white]Team A:[/color] %s  [color=gray](thrown wpns, +%d acc, +%d range)[/color]" % [a_names, _ThrownWeaponsTest.THROWN_ACCURACY_BONUS, _ThrownWeaponsTest.THROWN_RANGE_BONUS])
	print_rich("[color=yellow]Team B:[/color] %s  [color=gray](thrown wpns, +%d acc, +%d range)[/color]" % [b_names, _ThrownWeaponsTest.THROWN_ACCURACY_BONUS, _ThrownWeaponsTest.THROWN_RANGE_BONUS])
	var order_parts: Array[String] = []
	for m: MercenaryData in _battle_state.turn_queue:
		var color := "white" if _battle_team_a.has(m) else "yellow"
		order_parts.append("[color=%s]%s[/color]" % [color, m.merc_name.get_slice(" ", 0)])
	print_rich("Turn order: %s" % ", ".join(order_parts))
	AutoBattle.setup(_battle_state, _battle_line_fn)
	_run_battle_loop()


func _on_makeshift_test() -> void:
	if _battle_state != null:
		print("Battle already in progress.")
		return
	print("\n====== MAKESHIFT WEAPONS TEST ======\n")
	_battle_state = MakeshiftWeaponsTest.create_state()
	_battle_line_fn = func(s: String) -> void: print_rich(s)
	_battle_team_a.clear()
	_battle_team_b.clear()
	_battle_team_a.assign(_battle_state.teams[0])
	_battle_team_b.assign(_battle_state.teams[1])
	var a_names := ", ".join(_battle_team_a.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	var b_names := ", ".join(_battle_team_b.map(func(m: MercenaryData) -> String: return m.merc_name.get_slice(" ", 0)))
	print_rich("[color=white]Team A:[/color] %s  [color=gray](disarmed)[/color]" % a_names)
	print_rich("[color=yellow]Team B:[/color] %s  [color=gray](disarmed)[/color]" % b_names)
	var order_parts: Array[String] = []
	for m: MercenaryData in _battle_state.turn_queue:
		var color := "white" if _battle_team_a.has(m) else "yellow"
		order_parts.append("[color=%s]%s[/color]" % [color, m.merc_name.get_slice(" ", 0)])
	print_rich("Turn order: %s" % ", ".join(order_parts))
	AutoBattle.setup(_battle_state, _battle_line_fn)
	_run_battle_loop()


func _on_gen_terrain_batch() -> void:
	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var time_str := "%02d-%02d-%02d" % [dt["hour"], dt["minute"], dt["second"]]
	var path := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/terrain_batch_%s_%s.txt" % [date_str, time_str]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("ERROR: Could not open terrain batch log.")
		return
	print("Generating 50 terrain levels...")
	var lines: PackedStringArray = []
	lines.append("TERRAIN BATCH - 50 LEVELS")
	lines.append("Generated: %s %s" % [date_str, time_str.replace("-", ":")])
	lines.append("Legend:  ! jagged  # solid  D door  s ramp  ~ passthrough  * damaging  | corridor  > spawn-row")
	lines.append("Heights: = very-deep(h<-4)  _ deep(h<-2)  , dip(h<-0.5)  . flat  ' rise(h<1.5)  n moderate(h<3)  ^ hill(h<5)  A high(h<7)  M peak(h>=7)")
	lines.append("")
	for i: int in range(50):
		var field := BattlefieldArea.generate_random()
		if (i + 1) % 10 == 0:
			print("  Generated %d/50..." % (i + 1))
		lines.append("=".repeat(64))
		lines.append("LEVEL %d - %s" % [i + 1, field.to_header_string()])
		lines.append("Jagged: %d  |  Obstacles: %d  |  Buildings: %d  |  Corridors: %d" % [
			field.jagged_cells.size(), field.obstacles.size(),
			field.building_data.size(), field.reserved_corridor_cells.size()])
		for log_entry: String in field.generation_log:
			lines.append("  " + log_entry)
		lines.append("")
		lines.append(_field_to_ascii_map(field))
		lines.append("")
		lines.append(_field_height_summary(field))
		lines.append("")
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("Terrain batch written to: " + path)


func _field_to_ascii_map(field: BattlefieldArea) -> String:
	var rows: Array[String] = []
	for y: int in range(field.length):
		var any_spawn := false
		for _cx: int in range(field.width):
			if field._in_spawn_zone(Vector2i(_cx, y)):
				any_spawn = true
				break
		var row := "%2d%s " % [y, ">" if any_spawn else " "]
		for x: int in range(field.width):
			row += _map_cell(field, Vector2i(x, y))
		rows.append(row)
	return "\n".join(rows)


func _map_cell(field: BattlefieldArea, pos: Vector2i) -> String:
	if field.jagged_cells.has(pos):
		return "!"
	var obs: Dictionary = field._obs_map.get(pos, {}) as Dictionary
	if not obs.is_empty():
		var d: ObstacleData = obs.get("data") as ObstacleData
		var ct: String = obs.get("cell_type", "")
		if ct == "door":
			return "D"
		if ct == "wall":
			return "#"
		if d != null and d.ramp:
			return "s"
		if d != null and d.passthrough:
			return "*" if (d.pt_enter_harm > 0 or d.pt_exit_harm > 0) else "~"
		return "#"
	if field.reserved_corridor_cells.has(pos):
		return "|"
	var h: float = float(field.terrain_heights.get(pos, 0.0))
	if h <= -4.0:
		return "="
	if h <= -2.0:
		return "_"
	if h <= -0.5:
		return ","
	if h < 0.5:
		return "."
	if h < 1.5:
		return "'"
	if h < 3.0:
		return "n"
	if h < 5.0:
		return "^"
	if h < 7.0:
		return "A"
	return "M"


func _field_height_summary(field: BattlefieldArea) -> String:
	var min_h: float = 0.0
	var max_h: float = 0.0
	var sum_h: float = 0.0
	var count: int = 0
	for cell: Variant in field.terrain_heights.keys():
		var h: float = float(field.terrain_heights[cell])
		if count == 0:
			min_h = h
			max_h = h
		else:
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)
		sum_h += h
		count += 1
	var avg_h: float = (sum_h / float(count)) if count > 0 else 0.0
	var obs_tally: Dictionary = {}
	for obs: Dictionary in field.obstacles:
		var d: ObstacleData = obs.get("data") as ObstacleData
		if d != null:
			var n: String = d.obstacle_name
			obs_tally[n] = (obs_tally.get(n, 0) as int) + 1
	var obs_parts: Array[String] = []
	for k: Variant in obs_tally.keys():
		obs_parts.append("%s x%d" % [k as String, obs_tally[k] as int])
	return "Height: min=%.2f  max=%.2f  avg=%.2f  |  %s" % [
		min_h, max_h, avg_h,
		", ".join(obs_parts) if not obs_parts.is_empty() else "no obstacles"]


func _fmt_weapon_dice(rolls: Array[int], die_threshold: int, die_sides: int) -> String:
	var parts: Array[String] = []
	for val: int in rolls:
		var color: String = "green" if val <= die_threshold else "red"
		parts.append("[color=%s]%d[/color]" % [color, val])
	return "[%s]  (hit on <=%d/%d)" % [", ".join(parts), die_threshold, die_sides]


func _on_gen_outhouse_map() -> void:
	var outhouse_data: ObstacleData = DataManager.get_obstacle_by_name("Outhouse")
	if outhouse_data == null:
		print("Outhouse not found in DataManager.")
		return
	var config := BuildingConfig.new()
	config.forced_template = outhouse_data
	config.max_count = 20
	var field := BattlefieldArea.generate_random(config)
	_write_outhouse_map(field)
	print("Outhouse map written to encounter_logs.")


func _write_outhouse_map(field: BattlefieldArea) -> void:
	DirAccess.make_dir_absolute("user://encounter_logs")
	var dt := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	var time_str := "%02d-%02d-%02d" % [dt["hour"], dt["minute"], dt["second"]]
	var path := "user://encounter_logs/outhouse_map_%s_%s.txt" % [date_str, time_str]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("Could not write outhouse map.")
		return
	var lines: PackedStringArray = []
	var outhouse_count: int = 0
	for b: Dictionary in field.building_data:
		if (b["name"] as String) == "Outhouse":
			outhouse_count += 1
	lines.append("=== OUTHOUSE MAP DEBUG ===")
	lines.append("Date: %s %s" % [date_str, time_str.replace("-", ":")])
	lines.append("Field: %dx%d  Outhouses: %d / %d total buildings" % [
		field.width, field.length, outhouse_count, field.building_data.size()])
	lines.append("Legend: # wall  D door  W window  T toilet  f furniture  . floor  (space) open")
	var _b_perim: Dictionary = {}
	var _b_interior: Dictionary = {}
	var _b_doors: Dictionary = {}
	for _b: Dictionary in field.building_data:
		var _br: Rect2i = _b["rect"]
		var _bdp: Array = _b["door_positions"]
		for _bx: int in range(_br.size.x):
			for _by: int in range(_br.size.y):
				var _bc := _br.position + Vector2i(_bx, _by)
				var _on_perim: bool = (_bx == 0 or _bx == _br.size.x - 1 or _by == 0 or _by == _br.size.y - 1)
				if _on_perim:
					_b_perim[_bc] = true
					if _bdp.has(_bc):
						_b_doors[_bc] = true
				else:
					_b_interior[_bc] = true
	lines.append("")
	for y: int in range(field.length):
		var row := ""
		for x: int in range(field.width):
			var p := Vector2i(x, y)
			if _b_doors.has(p):
				row += "D"
			elif _b_perim.has(p):
				if field._obs_map.has(p) and (field._obs_map[p] as Dictionary).get("cell_type", "") == "window":
					row += "W"
				else:
					row += "#"
			elif _b_interior.has(p):
				if field._obs_map.has(p):
					var obs: Dictionary = field._obs_map[p]
					var ct: String = obs.get("cell_type", "")
					if ct == "furniture":
						var d: ObstacleData = obs.get("data") as ObstacleData
						row += "T" if d != null and d.obstacle_name == "Toilet" else "f"
					elif ct == "wall":
						row += "."
					else:
						row += "*"
				else:
					row += "."
			elif field._obs_map.has(p):
				var obs: Dictionary = field._obs_map[p]
				var ct: String = obs.get("cell_type", "")
				if ct == "wall":
					row += "#"
				elif ct == "door":
					row += "D"
				elif ct == "window":
					row += "W"
				elif ct == "furniture":
					var d: ObstacleData = obs.get("data") as ObstacleData
					row += "T" if d != null and d.obstacle_name == "Toilet" else "f"
				else:
					row += "*"
			else:
				row += " "
		lines.append(row)
	lines.append("")
	lines.append("--- BUILDINGS ---")
	for i: int in range(field.building_data.size()):
		var b: Dictionary = field.building_data[i]
		var rect: Rect2i = b["rect"]
		var df: Vector2i = b["door_facing"]
		var guaranteed: Array = b.get("guaranteed_structures", [])
		var excluded: Array = b.get("excluded_structures", [])
		lines.append("Building %d: %s  pos=(%d,%d) size=%dx%d  door=(%d,%d)" % [
			i + 1, b["name"], rect.position.x, rect.position.y,
			rect.size.x, rect.size.y, df.x, df.y])
		if not guaranteed.is_empty():
			lines.append("  Guaranteed: %s" % ", ".join(guaranteed))
		if not excluded.is_empty():
			lines.append("  Excluded: %s" % ", ".join(excluded))
		for ix: int in range(rect.position.x + 1, rect.end.x - 1):
			for iy: int in range(rect.position.y + 1, rect.end.y - 1):
				var p := Vector2i(ix, iy)
				if field._obs_map.has(p):
					var obs: Dictionary = field._obs_map[p]
					var d: ObstacleData = obs.get("data") as ObstacleData
					if d != null:
						lines.append("  (%d,%d) %s" % [p.x, p.y, d.obstacle_name])
		if b.get("guaranteed_structures", []).size() > 0:
			var has_contents := false
			for ix: int in range(rect.position.x + 1, rect.end.x - 1):
				for iy: int in range(rect.position.y + 1, rect.end.y - 1):
					if field._obs_map.has(Vector2i(ix, iy)):
						has_contents = true
			if not has_contents:
				lines.append("  (empty - placement failed)")
	f.store_string("\n".join(lines) + "\n")
	f.close()
