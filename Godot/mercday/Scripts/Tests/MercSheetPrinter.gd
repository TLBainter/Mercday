class_name MercSheetPrinter
extends RefCounted

#Formats and prints merc sheets, roll lines and the 100-merc batch analysis file.

#Luck bucket rows of the batch analysis: range label, expected share and exclusive upper bound, file and console alike.
const LUCK_TABLE: Array[Array] = [[" 0- 5", "~45%", 5.0], [" 5-10", "~20%", 10.0], ["10-20", "~15%", 20.0],
	["20-30", "~10%", 30.0], ["30-40", " ~9%", 40.0], ["40-50", " ~1%", 50.0], ["   50", "~0%", INF]]


static func print_merc(merc: MercenaryData) -> void:
	print_rich(merc_to_string(merc))


static func merc_to_string(merc: MercenaryData) -> String:
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
	lines.append("XP:           %d (level %d)" % [merc.xp, int(merc.stats.get("level", 0))])
	lines.append("Age:          %d (%s)" % [merc.age, merc.age_category])
	lines.append("Heritage:     %s" % (merc.heritage.heritage_name if merc.heritage else "(none)"))

	var circ_names: Array[String] = []
	for display_name: String in merc.circumstance_flags:
		if merc.circumstance_flags[display_name]:
			var bonus: float = merc.circumstance_additional_bonus.get(display_name, 0.0)
			circ_names.append(display_name + (" (+%.0f%%)" % bonus if bonus > 0.0 else ""))
	lines.append("Circumstances: %s" % (", ".join(circ_names) if circ_names.size() > 0 else "(none)"))

	lines.append("Knowledges:   %s" % _name_list(merc.knowledges, "utility_name", ", "))
	lines.append("Tools:        %s" % _name_list(merc.tools, "utility_name", ", "))
	lines.append("Lifepath:     %s" % _name_list(merc.lifepaths, "event_name", ", "))
	lines.append("Level Ups:    %s" % LevelUpSystem.summary(merc))
	lines.append("Skill Points: %s" % LevelUpSystem.counters(merc))

	lines.append("====EQUIPMENT====")

	var armor_str := "(none)"
	if merc.equipped_armor:
		armor_str = "%s  (%s, +%d DR)" % [
			merc.equipped_armor.item_name,
			merc.equipped_armor.armor_type,
			merc.equipped_armor.armor_bonus
		]
	lines.append("Armor:        %s" % armor_str)
	if merc.armor_break > 0:
		lines.append("Armor Break:  %d" % merc.armor_break)

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
	lines.append("Weight:       %s" % Encumbrance.detail_text(merc))

	var item_parts: Array[String] = []
	for item in merc.items:
		if item is Dictionary:
			item_parts.append(item.get("item_name", "?") as String)
	lines.append("Items:        %s" % (", ".join(item_parts) if not item_parts.is_empty() else "(none)"))

	lines.append("Tradition:    %s" % (merc.tradition.tradition_name if merc.tradition else "(none)"))

	lines.append("Perks:        %s" % _name_list(merc.perks, "trait_name", " | "))
	lines.append("Weapon Perks: %s" % _name_list(merc.weapon_perks, "trait_name", " | "))
	lines.append("Armor Perks:  %s" % _name_list(merc.armor_perks, "trait_name", " | "))
	lines.append("Drawbacks:    %s" % _name_list(merc.drawbacks, "trait_name", " | "))

	var immunity_parts: Array[String] = []
	for effect: String in merc.passive_effects:
		if effect.begins_with("immune:") or effect.begins_with("protected:") or effect.begins_with("susceptible:"):
			immunity_parts.append(effect)
	lines.append("Immunities:   %s" % ((" | ".join(immunity_parts)) if immunity_parts.size() > 0 else "(none)"))

	lines.append("Descriptors:  %s" % _name_list(merc.descriptors, "trait_name", " | "))

	lines.append("")
	lines.append("======== STATS ===========================")
	var hp_now: int = maxi(0, merc.current_hp)
	for pool: Array in [["HP", hp_now, "maximum_hit_points", merc.excess_hp],
			["EP", merc.current_ep, "maximum_endurance_points", merc.excess_ep],
			["MP", merc.current_mp, "maximum_magic_points", merc.excess_mp],
			["AP", merc.current_ap, "action_points", 0]]:
		lines.append(("Current %s:" % pool[0]).rpad(30) + " " + str(pool[1]).lpad(3, "0") + " / "
			+ str(int(merc.stats.get(pool[2], 0))).lpad(3, "0") + _excess_note(int(pool[3])))

	for stat_def: Dictionary in DataManager.stat_definitions:
		var var_name: String = stat_def["var_name"]
		var stat_type: String = stat_def["type"]
		var raw_val = merc.stats.get(var_name, 0)
		var label: String = stat_def["stat"]

		match stat_type:
			"core":
				var raw_max = merc.stats.get("max_" + var_name, 0)
				lines.append((label + ":").rpad(30) + " " + fmt_val(raw_val) + " / " + fmt_val(raw_max))
			"boolean":
				lines.append((label + ":").rpad(30) + " " + ("TRUE" if float(raw_val) > 0.0 else "FALSE"))
			_:
				lines.append((label + ":").rpad(30) + " " + fmt_val(raw_val))

	lines.append(sep)
	lines.append("")
	return "\n".join(lines)


static func _excess_note(pool: int) -> String:
	return " +%d excess" % pool if pool > 0 else ""


#One resource field of every entry joined, or "(none)" when the list is empty.
static func _name_list(items: Array, field: String, joiner: String) -> String:
	var names: Array[String] = []
	for item: Resource in items:
		names.append(str(item.get(field)))
	return joiner.join(names) if names.size() > 0 else "(none)"


static func fmt_rolls(rolls: Array, threshold: float) -> String:
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


static func fmt(value: float) -> String:
	if value < 0.0:
		return "-" + fmt(-value)
	var s: String = "%.2f" % value
	var dot: int = s.find(".")
	return s.left(dot).lpad(3, "0") + s.substr(dot)


static func fmt_val(val) -> String:
	if val is int:
		if val < 0:
			return "-" + str(-val).lpad(3, "0")
		return str(val).lpad(3, "0")
	return fmt(float(val))


static func fmt_weapon_dice(rolls: Array[int], die_threshold: int, die_sides: int) -> String:
	var parts: Array[String] = []
	for val: int in rolls:
		var color: String = "green" if val <= die_threshold else "red"
		parts.append("[color=%s]%d[/color]" % [color, val])
	return "[%s]  (hit on <=%d/%d)" % [", ".join(parts), die_threshold, die_sides]


static func print_regional_names() -> void:
	print("\n====== REGIONAL NAME SAMPLES ======\n")
	for region: String in NameGenerator.get_regions():
		print("--- %s ---" % region)
		for _i: int in range(10):
			print("  " + NameGenerator.make_full_name(region))
		print("")


static func batch_analysis() -> void:
	print("Generating batch of 100 mercs...")
	var tally: Dictionary = {}
	var luck_buckets: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	var merc_blocks := ""
	for i: int in range(100):
		TestFixtures.reset_generator_rolls()
		var merc := MercGenerator.generate(i)
		var trad_name: String = merc.tradition.tradition_name if merc.tradition else "(none)"
		tally[trad_name] = tally.get(trad_name, 0) + 1
		for b: int in range(LUCK_TABLE.size()):
			if merc.luck_roll < float(LUCK_TABLE[b][2]):
				luck_buckets[b] += 1
				break
		merc_blocks += merc_to_string(merc)

	var sorted_keys: Array = tally.keys()
	sorted_keys.sort_custom(func(a: String, b: String) -> bool: return tally[a] > tally[b])

	var trad_rows: PackedStringArray = _tradition_rows(tally, sorted_keys)
	var luck_rows: PackedStringArray = _luck_rows(luck_buckets, " ")
	var summary := "BATCH ANALYSIS - 100 MERCS\n"
	summary += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	summary += "====== TRADITION TALLY ======\n"
	for row: String in trad_rows:
		summary += row + "\n"
	summary += "\n"
	summary += "====== LUCK ROLL DISTRIBUTION (expected) ======\n"
	for row: String in luck_rows:
		summary += row + "\n"
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
	for row: String in trad_rows:
		print(row)
	print("Luck roll distribution (expected):")
	for row: String in _luck_rows(luck_buckets, "  "):
		print(row)


#One line per tradition, in the order of `keys`.
static func _tradition_rows(tally: Dictionary, keys: Array) -> PackedStringArray:
	var rows: PackedStringArray = []
	for trad: String in keys:
		rows.append("  %-20s %d" % [trad + ":", tally[trad]])
	return rows


#One line per luck bucket; `indent` sits in front of every range label.
static func _luck_rows(buckets: Array[int], indent: String) -> PackedStringArray:
	var rows: PackedStringArray = []
	for i: int in range(LUCK_TABLE.size()):
		rows.append("%s%s:  %3d%%  (expected %s)" % [indent, LUCK_TABLE[i][0], buckets[i],
			LUCK_TABLE[i][1]])
	return rows
