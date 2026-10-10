class_name StateTokens


static func normalize_token(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_")


static func parse_cell(cell: String, verbs: Array[String], state_name: String, column: String) -> Array[String]:
	var out: Array[String] = []
	for raw: String in cell.split("|"):
		var token := normalize_token(raw)
		if token == "":
			continue
		if not verbs.has(token.get_slice(":", 0)):
			push_warning("ConstStates: %s %s unknown token '%s'" % [state_name, column, token])
		if token.begins_with("immune:") and not ConstStates.immune_token_allowed(token, "States.tsv " + state_name):
			continue
		out.append(token)
	return out


static func num(parts: PackedStringArray, index: int) -> float:
	if index >= parts.size():
		return 0.0
	return parts[index].trim_prefix("+").to_float()


static func spec_matches(spec: String, key: String) -> bool:
	if spec == "all":
		return true
	return spec.split(",").has(key)


#"tag:<name>" in the second slot collapses to one part; tags are not implemented yet and match nothing.
static func token_parts(token: String) -> PackedStringArray:
	var parts := token.split(":")
	if parts.size() > 2 and parts[1] == "tag":
		var merged := PackedStringArray([parts[0], "tag:" + parts[2]])
		for i: int in range(3, parts.size()):
			merged.append(parts[i])
		return merged
	return parts


#Reads apply:<states>[:<n>:<unit>][:until:<verb>] into {"states", "duration", "removal", "error"}.
static func parse_apply_token(token: String) -> Dictionary:
	var states: Array[String] = []
	var removal: Array[String] = []
	var duration: String = ""
	var error: String = ""
	var parts := token.split(":")
	var count: int = parts.size()
	for spec: String in (parts[1] if count > 1 else "").split(","):
		var named := ConstStates.state_from_token(spec)
		if named != "":
			states.append(named)
	var has_until: bool = false
	var verb: String = ""
	if count == 2:
		pass
	elif count == 4 and parts[2] == "until":
		has_until = true
		verb = parts[3]
	elif count == 4:
		duration = parts[2] + " " + parts[3]
	elif count == 6 and parts[4] == "until":
		duration = parts[2] + " " + parts[3]
		has_until = true
		verb = parts[5]
	else:
		error = "unreadable duration"
	if has_until:
		if ConstStates.UNTIL_VERBS.has(verb):
			removal = StateCascade.until_removal(verb)
		else:
			error = "unknown until"
	return {"states": states, "duration": duration, "removal": removal, "error": error}
