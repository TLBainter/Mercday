class_name EffectDslCompiler
extends RefCounted

#Converts English trait effect cells into the token DSL used by the trait system.

const DSL_PREFIXES: PackedStringArray = [
	"stat:", "grant:", "remove:", "on:", "block:", "block_and_replace:", "immune:", "protected:",
	"susceptible:", "cost:", "SPECIAL:", "armor_weight_ignore:", "armor_ep_ignore:", "armor_fatigue_zero:",
	"weapon_enhance:", "weapon_stat:", "weapon_two_handed:", "weapon_passive:", "on_hit:", "on_pain:",
	"on_crit:", "spend:", "action:", "reactive_action:", "on_kill:", "on_grapple:", "while:", "to:", "chance:",
	"repeat:", "per:", "lasting:", "inflict:", "apply:", "damage:", "resource:", "damage_dealt:", "damage_taken:",
	"reward:", "success_chance:", "remove_self"
]

const EFFECT_PREFIXES: PackedStringArray = ["immune to ", "protected from ", "susceptible to "]
const EFFECT_DSLS: PackedStringArray = ["immune:", "protected:", "susceptible:"]

const STAT_VAR_MAP: Dictionary = {
	"Maximum Hit Points": "max_hp", "Maximum HP": "max_hp",
	"Maximum Endurance Points": "max_ep", "Maximum EP": "max_ep",
	"Maximum Magic Points": "max_mp", "Maximum MP": "max_mp",
	"Maximum Cognition": "max_cognition", "Maximum Dexterity": "max_dexterity",
	"Maximum Vigor": "max_vigor", "Maximum Wile": "max_wile",
	"Defense": "defense", "Speed": "speed", "Pace": "pace",
	"Accuracy": "accuracy", "Combat": "combat", "Luck": "luck",
	"Avoid": "avoid", "Block": "block", "Dodge": "dodge",
	"Health": "health", "Social": "social", "Intellect": "intellect",
	"Vigor": "vigor",
}


static func convert_legacy_effect(raw: String, where: String = "") -> String:
	if raw == "" or raw == "No special effect.":
		return ""
	if looks_like_dsl(raw):
		_warn_mixed_special(raw, where)
		return raw
	var parts: Array[String] = []
	for sentence: String in raw.split(". "):
		var s: String = sentence.strip_edges().trim_suffix(".")
		if s != "":
			parts.append(s)
	var dsl_parts: Array[String] = []
	for part: String in parts:
		dsl_parts.append(_convert_one_effect(part))
	var result: String = "|".join(dsl_parts)
	return result if looks_like_dsl(result) else "SPECIAL:" + raw


#A cell that mixes tokens with a SPECIAL: part keeps the tokens; the SPECIAL: half is dropped.
static func _warn_mixed_special(raw: String, where: String) -> void:
	if where == "":
		return
	var has_special: bool = false
	var has_token: bool = false
	for part: String in raw.split("|"):
		var p: String = part.strip_edges()
		if p == "":
			continue
		if p.begins_with("SPECIAL:"):
			has_special = true
		else:
			has_token = true
	if has_special and has_token:
		push_warning("%s: SPECIAL: text dropped, only the DSL tokens are applied (%s)" % [where, raw])


static func _convert_one_effect(s: String) -> String:
	var lower: String = s.to_lower()
	if lower == "flying pace":
		return "grant:ability:flying_pace"
	if lower == "swimming pace":
		return "grant:ability:swimming_pace"
	if lower == "climbing pace":
		return "grant:ability:climbing_pace"
	if lower == "darksight":
		return "grant:ability:darksight"
	for i: int in range(EFFECT_PREFIXES.size()):
		var pfx: String = EFFECT_PREFIXES[i]
		if lower.begins_with(pfx):
			return EFFECT_DSLS[i] + s.substr(pfx.length()).strip_edges().to_lower().replace(" ", "_")
	if s.contains("random"):
		var count: int = _extract_count(s)
		if s.contains("Esoteric"):
			return "grant:random:esoteric:%d" % count
		if s.contains("Resist") and s.contains("Circumstance"):
			return "grant:random:circumstance:resist:%d" % count
		if s.contains("Circumstance"):
			return "grant:random:circumstance:%d" % count
		if s.contains("Tool"):
			return "grant:random:tool:%d" % count
		if s.contains("Knowledge"):
			return "grant:random:knowledge:%d" % count
	return _try_stat_dsl(s)


static func _try_stat_dsl(s: String) -> String:
	for display_name: String in STAT_VAR_MAP:
		for op: String in ["+", "-"]:
			var pattern: String = display_name + " " + op
			if s.begins_with(pattern):
				var num: String = s.substr(pattern.length()).strip_edges()
				return "stat:%s:%s%s" % [str(STAT_VAR_MAP[display_name]), op, num]
	return "SPECIAL:" + s


static func _extract_count(s: String) -> int:
	if s.contains("three") or s.contains("3"):
		return 3
	if s.contains("two") or s.contains("2"):
		return 2
	return 1


static func looks_like_dsl(s: String) -> bool:
	if s == "":
		return true
	for part: String in s.split("|"):
		var p: String = part.strip_edges()
		if p == "":
			continue
		var known := false
		for prefix: String in DSL_PREFIXES:
			if p.begins_with(prefix):
				known = true
				break
		if not known:
			return false
	return true
