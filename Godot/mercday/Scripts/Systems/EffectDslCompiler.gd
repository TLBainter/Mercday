class_name EffectDslCompiler

#Validates trait effect cells against the token DSL used by the trait system.

#Prefixes applied at generation; the prefixes owned by combat and contract code are TraitDSL.RUNTIME_PREFIXES.
const DSL_PREFIXES: PackedStringArray = [
	"stat:", "grant:", "remove:", "on:", "block:", "block_and_replace:", "immune:", "protected:",
	"susceptible:", "cost:", "SPECIAL:", "apply:", "aura:"
]


static func convert_legacy_effect(raw: String, where: String = "") -> String:
	if raw == "" or raw == "No special effect.":
		return ""
	if looks_like_dsl(raw):
		_warn_mixed_special(raw, where)
		return raw
	push_error("%s: effect cell is not DSL, kept as SPECIAL: text (%s)" % [where, raw])
	return "SPECIAL:" + raw


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


static func looks_like_dsl(s: String) -> bool:
	if s == "":
		return true
	for part: String in s.split("|"):
		var p: String = part.strip_edges()
		if p == "":
			continue
		var known := false
		for prefix: String in DSL_PREFIXES + TraitDSL.RUNTIME_PREFIXES:
			if p.begins_with(prefix):
				known = true
				break
		if not known:
			return false
	return true
