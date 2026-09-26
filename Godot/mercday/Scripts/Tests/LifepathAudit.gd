class_name LifepathAudit

#The lifepath sheet report. Run: godot --headless --path . -- --lifepath-audit
#One tab separated AUDIT row per Lifepaths.tsv event, for checking the sheet against the code.


#Prints one AUDIT line per Lifepaths.tsv event so a report can be built from the code, not the sheet.
static func audit_full() -> void:
	var groups: Array = []
	for name: String in DataManager.starting_lifepaths:
		groups.append(DataManager.starting_lifepaths[name])
	for cat: String in DataManager.lifepaths_by_category:
		for lp in DataManager.lifepaths_by_category[cat]:
			groups.append(lp)
	for entry in groups:
		var lp: LifepathData = entry as LifepathData
		if lp == null:
			continue
		var reqs: Array[String] = []
		var bad: Array[String] = []
		for r: Dictionary in lp.requirements:
			var subject: String = str(r.get("subject", ""))
			var op: String = str(r.get("op", ""))
			var value: String = str(r.get("value", ""))
			var conj: String = str(r.get("conj", ""))
			var conj_text: String = (" " + conj) if conj != "" else ""
			reqs.append("%s [%s] %s%s" % [subject, op, value, conj_text])
			if not LifepathRequirements.SUBJECTS.has(subject):
				bad.append("subject:" + subject)
			elif op.strip_edges() == "" and value.strip_edges() == "":
				continue
			elif not LifepathRequirements._value_supported(subject,
					"IS" if op.strip_edges() == "" else op, value):
				bad.append("value:" + subject + "=" + value)
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
		var allows_no_run: bool = false
		if lp.requirements.is_empty():
			allows_no_run = LifepathRequirements.allows(null, lp, null)
		else:
			allows_no_run = _allows_safe(lp)
		print("AUDIT	%s	%s	%s	%s	%s	%s	%s	%d	%d	%d	%s" % [lp.event_type, lp.event_name, lp.rarity,
			"; ".join(lp.perks), "; ".join(lp.drawbacks), "; ".join(reqs), "; ".join(bad),
			1 if LifepathRequirements.is_supported(lp) else 0, 1 if LifepathProgression.has_payoff(lp) else 0,
			1 if allows_no_run else 0, "; ".join(cells)])


#Generation filters with no run; a fresh merc stands in so subjects that need a run report what they return.
static func _allows_safe(lp: LifepathData) -> bool:
	var probe := TestFixtures.level_merc("Probe")
	return LifepathRequirements.allows(probe, lp, null)
