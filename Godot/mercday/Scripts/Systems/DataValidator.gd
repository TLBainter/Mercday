class_name DataValidator
extends RefCounted

#Cross-table checks over loaded state, trait and NPC data; reports through push_warning only.

const PERK_GROUP_PREFIX: String = "grant:random:perk_group:"


static func is_damage_target(token: String) -> bool:
	for dt: String in ConstDamageTypes.DAMAGE_TYPES.keys():
		if StateTokens.normalize_token(dt) == token:
			return true
	var categories := PackedStringArray([ConstDamageTypes.STANDARD, ConstDamageTypes.ELEMENTAL,
		ConstDamageTypes.ESOTERIC])
	for cat: String in categories:
		if StateTokens.normalize_token(cat) == token:
			return true
	return false


#Warns about immune, protected and susceptible tokens naming neither a state nor a damage type.
static func validate_effect_tokens(traits: Dictionary) -> void:
	for state_name: String in ConstStates.DATA.keys():
		var data: Dictionary = ConstStates.DATA[state_name]
		for token: String in data.get("effects", []):
			check_effect_token(token, "States.tsv " + state_name)
	for trait_name: String in traits.keys():
		var trait_data: TraitData = traits[trait_name]
		for part: String in trait_data.effect_dsl.split("|"):
			var token: String = part.strip_edges()
			check_effect_token(token, "Traits.tsv " + trait_name)
			check_perk_group_token(token, "Traits.tsv " + trait_name, trait_data)


static func check_effect_token(token: String, where: String) -> void:
	if token == "":
		return
	var parts: PackedStringArray = token.split(":")
	if parts.size() < 2:
		return
	var verb: String = StateTokens.normalize_token(parts[0])
	if not (verb in ["immune", "protected", "susceptible"]):
		return
	if StateTokens.normalize_token(parts[1]) == "tag":
		return
	for spec: String in parts[1].split(","):
		var target: String = StateTokens.normalize_token(spec)
		if target == "":
			continue
		if ConstStates.state_from_token(target) != "" or is_damage_target(target):
			continue
		push_warning("%s: unresolvable target %s in token %s" % [where, target, token])


#grant:random:perk_group:<group>:<n> needs five parts, a stocked group, a positive count and a non-member row.
static func check_perk_group_token(token: String, where: String, trait_data: TraitData = null) -> void:
	if not token.begins_with(PERK_GROUP_PREFIX):
		return
	var parts: PackedStringArray = token.split(":")
	if parts.size() != 5:
		push_warning("%s: perk group token %s does not read grant:random:perk_group:<group>:<n>" % [where, token])
		return
	var count: String = parts[4].strip_edges()
	if not count.is_valid_int() or int(count) <= 0:
		push_warning("%s: perk group count %s is not a positive number in token %s" % [where, count, token])
	var group: String = DataManager.normalize_perk_group(parts[3])
	if group == "" or (DataManager.perk_group_library.get(group, []) as Array).is_empty():
		push_warning("%s: perk group %s has no member row in token %s" % [where, group, token])
	if trait_data != null and trait_data.trait_type == "Perk" and not trait_data.perk_groups.is_empty():
		push_warning("%s: perk group member carries the nested perk group token %s" % [where, token])


#"None" or blank yields nothing; each token must read <immune|protected|susceptible>:<state|damage type>.
static func parse_npc_immunities(raw: String, title: String) -> Array[String]:
	var out: Array[String] = []
	var where: String = "NPCs.tsv " + title
	if raw.strip_edges() == "" or raw.strip_edges().to_lower() == "none":
		return out
	for part: String in raw.split("|"):
		var token: String = part.strip_edges()
		if token == "":
			continue
		var pieces: PackedStringArray = token.split(":")
		if pieces.size() < 2:
			push_warning("%s: unknown immunity token %s" % [where, token])
			continue
		var verb: String = StateTokens.normalize_token(pieces[0])
		var target: String = StateTokens.normalize_token(pieces[1])
		if not (verb in ["immune", "protected", "susceptible"]) or target == "":
			push_warning("%s: unknown immunity token %s" % [where, token])
			continue
		if ConstStates.state_from_token(target) == "" and not is_damage_target(target):
			push_warning("%s: unknown immunity token %s" % [where, token])
			continue
		var normalized: String = verb + ":" + target
		if not ConstStates.immune_token_allowed(normalized, where):
			continue
		out.append(normalized)
	return out
