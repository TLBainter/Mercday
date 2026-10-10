class_name StateEffects


#One entry per effect token of every active state: state, token, parts, count and source.
#A non-empty verb keeps only that verb's tokens, so the caller does not parse the rest.
static func active_effects(merc: MercenaryData, verb: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for state_name: String in ConstStates.held_state_names(merc):
		var count := ConstStates.get_count(merc, state_name)
		for token: String in ConstStates.DATA[state_name]["effects"]:
			if not verb.is_empty() and token != verb and not token.begins_with(verb + ":"):
				continue
			out.append({"state": state_name, "token": token, "parts": StateTokens.token_parts(token),
				"count": count, "source": ConstStates.get_source(merc, state_name)})
	return out


static func has_effect(merc: MercenaryData, prefix: String) -> bool:
	for e: Dictionary in active_effects(merc):
		if str(e["token"]).begins_with(prefix):
			return true
	return false


#check:<stats|all>:<+n|-n|flaw:+n|enhance:+n|auto_fail>[:per_stack] on a check made with stat_key.
static func check_modifier(merc: MercenaryData, stat_key: String) -> Dictionary:
	var out := {"threshold": 0.0, "flaws": 0, "enhancements": 0, "auto_fail": false, "states": []}
	for e: Dictionary in active_effects(merc, "check"):
		var p: PackedStringArray = e["parts"]
		if p.size() < 3 or not StateTokens.spec_matches(p[1], stat_key):
			continue
		var mult: int = int(e["count"]) if p.has("per_stack") else 1
		match p[2]:
			"flaw":
				out["flaws"] += int(StateTokens.num(p, 3)) * mult
			"enhance":
				out["enhancements"] += int(StateTokens.num(p, 3)) * mult
			"auto_fail":
				out["auto_fail"] = true
			"vs_source":
				continue
			_:
				out["threshold"] += StateTokens.num(p, 2) * float(mult)
		(out["states"] as Array).append(e["state"])
	return out


#attack:<kinds|all>:<flaw|enhance>:<+n> on the attacker; kind is melee, ranged or thrown.
static func attack_modifier(merc: MercenaryData, kind: String) -> Dictionary:
	return _attack_tokens(merc, "attack", kind)


#attack_vs:<kinds|all>:<flaw|enhance>:<+n> on the target of an attack.
static func attack_vs_modifier(target: MercenaryData, kind: String) -> Dictionary:
	return _attack_tokens(target, "attack_vs", kind)


static func _attack_tokens(merc: MercenaryData, verb: String, kind: String) -> Dictionary:
	var out := {"flaws": 0, "enhancements": 0, "states": []}
	for e: Dictionary in active_effects(merc, verb):
		var p: PackedStringArray = e["parts"]
		if p.size() < 4 or not StateTokens.spec_matches(p[1], kind):
			continue
		if p[2] == "flaw":
			out["flaws"] += int(StateTokens.num(p, 3))
		elif p[2] == "enhance":
			out["enhancements"] += int(StateTokens.num(p, 3))
		(out["states"] as Array).append(e["state"])
	return out


#"immune", "susceptible", "protected" or "none" for a damage type from the active states.
static func damage_modifier(merc: MercenaryData, damage_type: String) -> String:
	var type_lower := damage_type.to_lower()
	var found := "none"
	for e: Dictionary in active_effects(merc):
		var p: PackedStringArray = e["parts"]
		if p.size() < 2 or not StateTokens.spec_matches(p[1], type_lower):
			continue
		match p[0]:
			"immune":
				return "immune"
			"susceptible":
				found = "susceptible"
			"protected":
				if found == "none":
					found = "protected"
	return found


#cost:<ap|ep>:x<n>; the product of every multiplier, 1 when none applies.
static func cost_multiplier(merc: MercenaryData, resource: String) -> int:
	var mult := 1
	for e: Dictionary in active_effects(merc, "cost"):
		var p: PackedStringArray = e["parts"]
		if p.size() >= 3 and StateTokens.spec_matches(p[1], resource) and p[2].begins_with("x"):
			mult *= maxi(1, p[2].substr(1).to_int())
	return mult


#block:<subject...>[:except:<a>,<b>]; queries read "action:move", "spend:ep:defend", "ability:fly".
static func is_blocked(merc: MercenaryData, query: String) -> bool:
	var q := query.split(":")
	for e: Dictionary in active_effects(merc, "block"):
		var p: PackedStringArray = e["parts"]
		var subject: Array[String] = []
		var exceptions: Array[String] = []
		var in_except := false
		for i: int in range(1, p.size()):
			if p[i] == "except":
				in_except = true
			elif in_except:
				exceptions.append_array(p[i].split(","))
			else:
				subject.append(p[i])
		if not _subject_matches(subject, q):
			continue
		if exceptions.has(q[q.size() - 1]):
			continue
		return true
	return false


static func _subject_matches(subject: Array[String], q: PackedStringArray) -> bool:
	if subject.size() > q.size():
		return false
	for i: int in range(subject.size()):
		if subject[i] == "all":
			return true
		if subject[i] != q[i]:
			return false
	return true


#dot:<type>:<n>; damage taken at the start of the merc's turn.
static func dot_effects(merc: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in active_effects(merc, "dot"):
		var p: PackedStringArray = e["parts"]
		if p.size() >= 3:
			out.append({"state": e["state"], "type": p[1].capitalize(), "amount": int(StateTokens.num(p, 2))})
	return out


#The "suffocate" token shares one breath countdown between Suffocating and Drowning.
static func is_suffocating(merc: MercenaryData) -> bool:
	return not active_effects(merc, "suffocate").is_empty()


#move:max_paces:<n> and stat:speed:=0; -1 when the merc's paces are not capped.
#A crawling merc is Deposed for the combat modifiers only, so that state's pace cap is ignored.
static func max_paces(merc: MercenaryData) -> int:
	var cap := -1
	for e: Dictionary in active_effects(merc):
		var p: PackedStringArray = e["parts"]
		var value := -1
		if p[0] == "move" and p.size() >= 3 and p[1] == "max_paces":
			if merc.crawling and str(e["state"]) == ConstStates.DEPOSED:
				continue
			value = int(StateTokens.num(p, 2))
		elif p[0] == "stat" and p.size() >= 3 and p[1] == "speed" and p[2] == "=0":
			value = 0
		if value >= 0 and (cap < 0 or value < cap):
			cap = value
	return cap


#move:pace:<n> summed over the held states; 0 when none.
static func pace_modifier(merc: MercenaryData) -> int:
	var total := 0
	for e: Dictionary in active_effects(merc, "move"):
		var p: PackedStringArray = e["parts"]
		if p.size() >= 3 and p[1] == "pace":
			total += int(StateTokens.num(p, 2))
	return total


#damage_taken:direct and damage_taken:+n.
static func damage_taken(merc: MercenaryData) -> Dictionary:
	var out := {"direct": false, "bonus": 0}
	for e: Dictionary in active_effects(merc, "damage_taken"):
		var p: PackedStringArray = e["parts"]
		if p.size() < 2:
			continue
		if p[1] == "direct":
			out["direct"] = true
		else:
			out["bonus"] += int(StateTokens.num(p, 1))
	return out


#target:block:source; enemies the merc may not target.
static func blocked_targets(merc: MercenaryData) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for e: Dictionary in active_effects(merc, "target"):
		var p: PackedStringArray = e["parts"]
		if p.size() >= 3 and p[1] == "block" and p[2] == "source":
			var src: MercenaryData = e["source"]
			if src != null and not out.has(src):
				out.append(src)
	return out


#move:block_toward:source and move:away_from:source:<n>; sources the merc must keep away from.
static func feared_sources(merc: MercenaryData) -> Array[MercenaryData]:
	var out: Array[MercenaryData] = []
	for e: Dictionary in active_effects(merc, "move"):
		var p: PackedStringArray = e["parts"]
		if p.size() >= 3 and (p[1] == "block_toward" or p[1] == "away_from") and p[2] == "source":
			var src: MercenaryData = e["source"]
			if src != null and not out.has(src):
				out.append(src)
	return out


static func skips_turn(merc: MercenaryData) -> bool:
	return has_effect(merc, "skip_turn")
