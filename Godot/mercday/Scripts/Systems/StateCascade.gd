class_name StateCascade


#`root` names the state whose "apply:" token forces this one; "" is a direct application.
#`origin` is "<kind>:<name>" for the caller and `removal` overrides the rest verbs that may end the source.
#A direct application is refused when the merc is immune unless the merc chose it; cascade children always apply.
static func apply_state(merc: MercenaryData, state_name: String, source: MercenaryData = null,
		root: String = "", origin: String = "", removal: Array[String] = [],
		chosen: bool = false) -> bool:
	if root == "" and not chosen and ConstStates.is_immune(merc, state_name):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("STATE IMMUNE: %s %s" % [merc.merc_name, state_name])
		return false
	var src := StateSources.source_record(state_name, root, origin, removal)
	if state_name in ConstStates.STACKING_STATES:
		var current: int = ConstStates.get_count(merc, state_name)
		merc.active_states[state_name] = current + 1
		var tier_entry := StateSources.record_entry(merc, state_name, root == "")
		(tier_entry["sources"] as Array).append(src)
		_log_source(merc, state_name, src, current + 1)
		return true

	var was_active := ConstStates.has_state(merc, state_name)
	if root == "" or not was_active:
		if state_name in ConstStates.SOURCE_STATES:
			merc.active_states[state_name] = {"count": 1, "source": source}
		else:
			merc.active_states[state_name] = 1
	var forced := StateSources.record_source(merc, state_name, root, was_active)
	StateSources.add_source(merc, state_name, src, root == "")
	_log_source(merc, state_name, src, 0)
	if forced or root == "":
		_apply_children(merc, state_name)
	return true


static func _log_source(merc: MercenaryData, state_name: String, src: Dictionary, tier: int) -> void:
	if not EncounterLogger.is_active():
		return
	var name: String = str(src.get("name", ""))
	if name == "":
		name = "none"
	var raw: Array = src.get("removal", [])
	var verbs := PackedStringArray(raw)
	var line: String = "STATE SOURCE: %s %s %s=%s removal=%s" % [merc.merc_name, state_name,
		str(src.get("kind", "")), name, ",".join(verbs)]
	if tier > 0:
		line += " tier=%d" % tier
	EncounterLogger.log_verbose(line)


#"apply:<a>,<b>" tokens force those states; each gains this state as a root source.
static func _apply_children(merc: MercenaryData, state_name: String) -> void:
	var data: Dictionary = ConstStates.DATA.get(state_name, {})
	for token: String in data.get("effects", []):
		if not token.begins_with("apply:"):
			continue
		var parsed := StateTokens.parse_apply_token(token)
		var child_removal: Array[String] = parsed["removal"]
		for child: String in parsed["states"]:
			apply_state(merc, child, null, state_name, "", child_removal)


#The first ":" segment of every States.tsv Removal token, in cell order; [] for an unknown state.
static func removal_verbs(state_name: String) -> Array[String]:
	var out: Array[String] = []
	for token: String in ConstStates.removal_methods(state_name):
		var verb: String = token.get_slice(":", 0)
		if verb != "" and not out.has(verb):
			out.append(verb)
	return out


#The removal verbs an "until:<verb>" tail stands for; [] when the verb is not one of ConstStates.UNTIL_VERBS.
static func until_removal(verb: String) -> Array[String]:
	var out: Array[String] = []
	if verb == "respite":
		out.append("respite")
	elif verb == "furlough":
		out.append("furlough")
	elif verb == "none":
		out.append("cause")
	return out


static func rest_removable(merc: MercenaryData, state_name: String, verb: String) -> bool:
	return ConstStates.has_state(merc, state_name) and StateSources.held_reason(merc, state_name, verb) == ""


#Ends what a rest of this verb may end: the newest free tier of a stacking state, else the whole state.
static func reduce_state_by(merc: MercenaryData, state_name: String, verb: String) -> Dictionary:
	var out := {"removed": false, "reason": "", "kind": "", "name": ""}
	if not ConstStates.has_state(merc, state_name):
		return out
	if state_name in ConstStates.STACKING_STATES:
		var sources: Array = StateSources.sources_ref(merc, state_name)
		var pick: int = -1
		for i: int in range(sources.size() - 1, -1, -1):
			var src: Dictionary = sources[i]
			if StateSources.source_allows(src, verb) and not StateSources.source_ongoing(merc, src):
				pick = i
				break
		if pick < 0 and not (sources.is_empty() and removal_verbs(state_name).has(verb)):
			out["reason"] = StateSources.held_reason(merc, state_name, verb)
			return out
		if pick >= 0:
			out["kind"] = str(sources[pick].get("kind", ""))
			out["name"] = str(sources[pick].get("name", ""))
			sources.remove_at(pick)
		_decrement_stack(merc, state_name)
		out["removed"] = true
		return out
	for src: Dictionary in StateSources.effective_sources(merc, state_name):
		if StateSources.source_allows(src, verb) and not StateSources.source_ongoing(merc, src):
			out["kind"] = str(src.get("kind", ""))
			out["name"] = str(src.get("name", ""))
			out["removed"] = true
			break
	if not out["removed"]:
		out["reason"] = StateSources.held_reason(merc, state_name, verb)
		return out
	out["removed"] = bool(remove_state(merc, state_name)["removed"])
	if not out["removed"]:
		out["kind"] = ""
		out["name"] = ""
		out["reason"] = StateSources.held_reason(merc, state_name, verb)
	return out


#States whose "apply:" token still forces this one; empty when nothing else holds it up.
static func applied_roots(merc: MercenaryData, state_name: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(StateSources.applied_entry(merc, state_name).get("roots", []))
	return out


#Ends the state unless a root still applies it; states it applied lose that source and end with their last one.
static func remove_state(merc: MercenaryData, state_name: String) -> Dictionary:
	var result := {"removed": false, "cascade": [] as Array[String], "kept": [] as Array[String]}
	var record := StateSources.applied_by(merc)
	if record.has(state_name):
		record[state_name]["direct"] = false
		var roots: Array = record[state_name]["roots"]
		if not roots.is_empty():
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("STATE KEPT: %s %s roots=%s" % [
					merc.merc_name, state_name, ",".join(PackedStringArray(roots))])
			return result
	result["removed"] = true
	_remove_cascade(merc, state_name, result)
	if record.is_empty():
		merc.active_states.erase(ConstStates.APPLIED_BY_KEY)
	var parts := PackedStringArray()
	if not result["cascade"].is_empty():
		parts.append(",".join(result["cascade"]))
	if not result["kept"].is_empty():
		parts.append("kept=" + ",".join(result["kept"]))
	if EncounterLogger.is_active() and not parts.is_empty():
		EncounterLogger.log_verbose("STATE CASCADE: %s %s -> %s" % [merc.merc_name, state_name, " ".join(parts)])
	return result


static func _remove_cascade(merc: MercenaryData, state_name: String, result: Dictionary) -> void:
	merc.active_states.erase(state_name)
	merc.campaign_states.erase(state_name)
	var record := StateSources.applied_by(merc)
	record.erase(state_name)
	for child: String in record.keys():
		if not record.has(child):
			continue
		var entry: Dictionary = record[child]
		var dropped: int = StateSources.drop_state_sources(entry, state_name)
		if child in ConstStates.STACKING_STATES:
			if dropped <= 0:
				continue
			var left: int = maxi(ConstStates.get_count(merc, child) - dropped, 0)
			if left > 0:
				merc.active_states[child] = left
				result["kept"].append(child)
				continue
			merc.active_states.erase(child)
			merc.campaign_states.erase(child)
			record.erase(child)
			result["cascade"].append(child)
			continue
		var roots: Array = entry["roots"]
		if not (state_name in roots):
			continue
		roots.erase(state_name)
		if roots.is_empty() and not bool(entry["direct"]):
			result["cascade"].append(child)
			_remove_cascade(merc, child, result)
		else:
			result["kept"].append(child)
			if roots.is_empty() and (entry.get("sources", []) as Array).is_empty():
				record.erase(child)


static func reduce_state(merc: MercenaryData, state_name: String) -> void:
	if state_name in ConstStates.STACKING_STATES:
		if _decrement_stack(merc, state_name):
			StateSources.pop_source(merc, state_name)
	elif ConstStates.get_count(merc, state_name) <= 1:
		remove_state(merc, state_name)
	else:
		merc.active_states.erase(state_name)


#Takes one tier off a stacking state, or removes it at the last tier; true when tiers remain.
static func _decrement_stack(merc: MercenaryData, state_name: String) -> bool:
	var current: int = ConstStates.get_count(merc, state_name)
	if current <= 1:
		remove_state(merc, state_name)
		return false
	merc.active_states[state_name] = current - 1
	return true
