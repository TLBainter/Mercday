extends Node

var mercs: Array[MercenaryData] = []


func _ready() -> void:
	$ButtonBar/RerollMercs.pressed.connect(_on_reroll_mercs)
	$ButtonBar/AddMerc.pressed.connect(_on_add_merc)
	$ButtonBar/RemoveMerc.pressed.connect(_on_remove_merc)
	$ButtonBar/RerollNames.pressed.connect(_on_reroll_names)
	$ButtonBar/DefendCheck.pressed.connect(_on_defend_check)
	$ButtonBar/UrbanCheck.pressed.connect(_on_urban_check)
	$ButtonBar/MonsterHuntCheck.pressed.connect(_on_monster_hunt_check)
	$ButtonBar/SocialCheck.pressed.connect(_on_social_check)
	$ButtonBar/PoisonCheck.pressed.connect(_on_poison_check)
	$ButtonBar/PutOnAShowCheck.pressed.connect(_on_put_on_a_show_check)
	$ButtonBar/BatchAnalysis.pressed.connect(_on_batch_analysis)
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
	var merc_blocks := ""
	for i: int in range(100):
		var merc := MercGenerator.generate(i)
		var trad_name: String = merc.tradition.tradition_name if merc.tradition else "(none)"
		tally[trad_name] = tally.get(trad_name, 0) + 1
		merc_blocks += _merc_to_string(merc)

	var sorted_keys: Array = tally.keys()
	sorted_keys.sort_custom(func(a: String, b: String) -> bool: return tally[a] > tally[b])

	var summary := "BATCH ANALYSIS - 100 MERCS\n"
	summary += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	summary += "====== TRADITION TALLY ======\n"
	for trad: String in sorted_keys:
		summary += "  %-20s %d\n" % [trad + ":", tally[trad]]
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


func _print_merc(merc: MercenaryData) -> void:
	print(_merc_to_string(merc))


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
