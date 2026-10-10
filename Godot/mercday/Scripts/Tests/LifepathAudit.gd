class_name LifepathAudit

#The lifepath sheet report. Run: godot --headless --path . -- --lifepath-audit
#One tab separated AUDIT row per Lifepaths.tsv event, for checking the sheet against the code.


#Prints one AUDIT line per Lifepaths.tsv event so a report can be built from the code, not the sheet.
static func audit_full() -> void:
	for lp: LifepathData in _all_lifepaths():
		print(_audit_line(lp))


#Prints which Experienced events the level up pool can actually draw.
static func pool_summary() -> void:
	var supported: Array[String] = []
	var blocked: Array[String] = []
	for lp: LifepathData in DataManager.lifepaths_by_category.get("Experienced", []) as Array:
		if lp == null:
			continue
		if LifepathRequirements.is_supported(lp) and LifepathProgression.has_payoff(lp):
			supported.append(lp.event_name)
		else:
			blocked.append(lp.event_name)
	print("LIFEPATH POOL AUDIT: %d drawable, %d blocked" % [supported.size(), blocked.size()])
	print("  DRAWABLE: %s" % ", ".join(supported))


static func _all_lifepaths() -> Array[LifepathData]:
	var groups: Array[LifepathData] = []
	for name: String in DataManager.starting_lifepaths:
		var start: LifepathData = DataManager.starting_lifepaths[name] as LifepathData
		if start != null:
			groups.append(start)
	for cat: String in DataManager.lifepaths_by_category:
		for entry in DataManager.lifepaths_by_category[cat]:
			var lp: LifepathData = entry as LifepathData
			if lp != null:
				groups.append(lp)
	return groups


static func _audit_line(lp: LifepathData) -> String:
	var reqs: Array[String] = []
	var bad: Array[String] = []
	for r: Dictionary in lp.requirements:
		var subject: String = str(r.get("subject", ""))
		var value: String = str(r.get("value", ""))
		var conj: String = str(r.get("conj", ""))
		var conj_text: String = (" " + conj) if conj != "" else ""
		reqs.append("%s [%s] %s%s" % [subject, str(r.get("op", "")), value, conj_text])
		if not LifepathRequirements.SUBJECTS.has(subject):
			bad.append("subject:" + subject)
		elif not LifepathRequirements.is_supported(TestFixtures.hand([r])):
			bad.append("value:" + subject + "=" + value)
	return "AUDIT	%s	%s	%s	%s	%s	%s	%s	%d	%d	%d	%s" % [lp.event_type, lp.event_name, lp.rarity,
		"; ".join(lp.perks), "; ".join(lp.drawbacks), "; ".join(reqs), "; ".join(bad),
		1 if LifepathRequirements.is_supported(lp) else 0, 1 if LifepathProgression.has_payoff(lp) else 0,
		1 if _allows_safe(lp) else 0, "; ".join(_trait_cells(lp))]


static func _trait_cells(lp: LifepathData) -> Array[String]:
	var cells: Array[String] = []
	for trait_name: String in lp.perks + lp.drawbacks:
		var td: TraitData = TraitDSL.lookup_trait(trait_name)
		var kind := "MISSING"
		if td != null:
			if td.effect_dsl == "":
				kind = "EMPTY"
			elif td.effect_dsl.begins_with("SPECIAL:"):
				kind = "SPECIAL"
			elif td.effect_dsl.contains("SPECIAL:"):
				kind = "MIXED"
			else:
				kind = "DSL"
		cells.append("%s=%s" % [trait_name, kind])
	return cells


#Generation filters with no run; a fresh merc stands in so subjects that need a run report what they return.
static func _allows_safe(lp: LifepathData) -> bool:
	var probe := TestFixtures.level_merc("Probe")
	return LifepathRequirements.allows(probe, lp, null)
