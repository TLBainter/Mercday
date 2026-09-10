class_name ContractModifiers

#Applies a contract's stat and circumstance boosts to a team and reverts them from the same record.


static func stat_key(display: String) -> String:
	return display.to_lower().replace(" ", "_")


static func set_level(merc: MercenaryData, level: int) -> void:
	if merc == null:
		return
	StatCalculator.prime(merc)
	merc.stats["level"] = float(level)
	merc.xp = ExperienceSystem.xp_for_level(level)
	StatCalculator.refresh(merc)


static func apply(contract: ContractData, team: Array[MercenaryData]) -> Dictionary:
	var record: Dictionary = {"stats": {}, "circ": {}, "lines": []}
	var lines: Array[String] = []
	if contract == null:
		record["lines"] = lines
		return record
	for merc: MercenaryData in team:
		if merc == null:
			continue
		var base_values: Dictionary = merc.stats.duplicate()
		var stat_deltas: Dictionary = (record["stats"] as Dictionary).get(merc, {})
		for display: String in contract.stat_boosts:
			var key: String = stat_key(display)
			if not merc.stats.has(key):
				lines.append("CONTRACT BOOST SKIPPED: %s %s (no stat)" % [merc.merc_name, display])
				continue
			var percent: float = float(contract.stat_boosts[display])
			var old_value: float = float(base_values.get(key, merc.stats[key]))
			#A contract boost is a percent of the computed value, so it rides the multiplier channel.
			var fraction: float = percent / 100.0
			StatCalculator.add_percent(merc, key, fraction)
			StatCalculator.refresh(merc)
			stat_deltas[key] = float(stat_deltas.get(key, 0.0)) + fraction
			lines.append("CONTRACT BOOST: %s %s +%s%% (%.1f -> %.1f)"
				% [merc.merc_name, display, _pct_text(percent), old_value, float(merc.stats[key])])
		if not stat_deltas.is_empty():
			(record["stats"] as Dictionary)[merc] = stat_deltas
		var circ_deltas: Dictionary = (record["circ"] as Dictionary).get(merc, {})
		for display: String in contract.circumstance_boosts:
			if not bool(merc.circumstance_flags.get(display, false)):
				continue
			var percent: float = float(contract.circumstance_boosts[display])
			var existing: float = float(merc.circumstance_additional_bonus.get(display, 0.0))
			var delta: float = percent / 100.0 * (15.0 + existing)
			StatCalculator.prime(merc)
			merc.circumstance_additional_bonus[display] = existing + delta
			StatCalculator.refresh(merc)
			circ_deltas[display] = float(circ_deltas.get(display, 0.0)) + delta
			lines.append("CONTRACT CIRCUMSTANCE: %s %s +%.2f" % [merc.merc_name, display, delta])
		if not circ_deltas.is_empty():
			(record["circ"] as Dictionary)[merc] = circ_deltas
	record["lines"] = lines
	return record


static func revert(record: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if record == null or record.is_empty():
		return lines
	var circ_map: Dictionary = record.get("circ", {}) as Dictionary
	for merc: MercenaryData in circ_map:
		if merc == null:
			continue
		var deltas: Dictionary = circ_map[merc] as Dictionary
		var displays: Array = deltas.keys()
		displays.reverse()
		for display: String in displays:
			var delta: float = float(deltas[display])
			StatCalculator.prime(merc)
			merc.circumstance_additional_bonus[display] = float(merc.circumstance_additional_bonus.get(display, 0.0)) - delta
			StatCalculator.refresh(merc)
			lines.append("CONTRACT BOOST REVERTED: %s %s -%.2f" % [merc.merc_name, display, delta])
	var stat_map: Dictionary = record.get("stats", {}) as Dictionary
	for merc: MercenaryData in stat_map:
		if merc == null:
			continue
		var deltas: Dictionary = stat_map[merc] as Dictionary
		var keys: Array = deltas.keys()
		keys.reverse()
		for key: String in keys:
			var fraction: float = float(deltas[key])
			StatCalculator.add_percent(merc, key, -fraction)
			StatCalculator.refresh(merc)
			lines.append("CONTRACT BOOST REVERTED: %s %s -%s%%" % [merc.merc_name, key, _pct_text(fraction * 100.0)])
	record["stats"] = {}
	record["circ"] = {}
	return lines


static func knowledge_matches(merc: MercenaryData, name: String) -> bool:
	if merc == null:
		return false
	for k: UtilityTraitData in merc.knowledges:
		if k != null and k.utility_name == name:
			return true
	return false


static func tool_matches(merc: MercenaryData, name: String) -> bool:
	if merc == null or name == "":
		return false
	for t: UtilityTraitData in merc.tools:
		if t != null and t.utility_name.begins_with(name):
			return true
	return false


static func tradition_matches(merc: MercenaryData, name: String) -> bool:
	if merc == null or merc.tradition == null:
		return false
	return merc.tradition.tradition_name.to_lower() == name.to_lower()


static func boost_percent(contract: ContractData, merc: MercenaryData) -> float:
	if contract == null or merc == null:
		return 0.0
	var total: float = 0.0
	for name: String in contract.tool_boosts:
		if tool_matches(merc, name):
			total += float(contract.tool_boosts[name])
	for name: String in contract.knowledge_boosts:
		if knowledge_matches(merc, name):
			total += float(contract.knowledge_boosts[name])
	for name: String in contract.tradition_boosts:
		if tradition_matches(merc, name):
			total += float(contract.tradition_boosts[name])
	return total


static func _pct_text(percent: float) -> String:
	if is_equal_approx(percent, floor(percent)):
		return "%d" % int(percent)
	return "%.1f" % percent
