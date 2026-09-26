class_name ConstStates

const BLINDED       := "Blinded"
const BURNING       := "Burning"
const CHARMED       := "Charmed"
const CLIMBING      := "Climbing"
const DEAFENED      := "Deafened"
const DEBILITATED   := "Debilitated"
const DEPOSED       := "Deposed"
const DRENCHED      := "Drenched"
const DROWNING      := "Drowning"
const DYING         := "Dying"
const EMBOLDENED    := "Emboldened"
const FATIGUED      := "Fatigued"
const FLANKED       := "Flanked"
const FLYING        := "Flying"
const GRAPPLED      := "Grappled"
const GROUNDED      := "Grounded"
const HIDDEN        := "Hidden"
const HOBBLED       := "Hobbled"
const INHIBITED     := "Inhibited"
const INVISIBLE     := "Invisible"
const MADNESS       := "Madness"
const MUTE          := "Mute"
const POISONED      := "Poisoned"
const SHOCKED       := "Shocked"
const SLOWED        := "Slowed"
const SUFFOCATING   := "Suffocating"
const SURPRISED     := "Surprised"
const TERRIFIED     := "Terrified"
const THREATENED    := "Threatened"
const UNCONSCIOUS   := "Unconscious"
const VULNERABLE    := "Vulnerable"
const COVERED_FULL    := "Covered (Full)"
const COVERED_PARTIAL := "Covered (Partial)"

const STACKING_STATES: Array[String] = [FATIGUED, MADNESS]

const SOURCE_STATES: Array[String] = [GRAPPLED, INHIBITED, SUFFOCATING, CHARMED, TERRIFIED, BURNING, DROWNING]

#A Resist against an effect that inflicts one of these adds the target's Tolerance to the threshold.
const TOLERANCE_RESIST_STATES: Array[String] = [BURNING, FATIGUED, MADNESS, POISONED]

#Dying and Climbing can never be refused by an immunity token.
const NEVER_IMMUNE: Array[String] = [DYING, CLIMBING]

#Record under active_states: state -> {"direct": bool, "roots": [...], "sources": [...]}.
const APPLIED_BY_KEY := "_applied_by"

#A source record is {"kind", "name", "removal"}; kind names the code path that applied the state.
const SOURCE_KINDS: Array[String] = ["state", "trait", "inflict", "engine"]

#An "until:<verb>" tail on an apply: token replaces the removal verbs the source is ended by.
const UNTIL_VERBS: Array[String] = ["respite", "furlough", "none"]

#Units of a "time:N:<unit>" removal that run on the campaign clock instead of inside an encounter.
const CAMPAIGN_UNITS: Array[String] = ["hour", "hours", "day", "days"]

#A held state that would outlast its encounter ends this many minutes after it instead; Drenched gets one Breather (10).
const AFTER_ENCOUNTER_MINUTES: Dictionary = {DRENCHED: 10}

static var DATA: Dictionary = {}
static var ALL: Array[String] = []


static func load_from_tsv(path: String) -> void:
	DATA.clear()
	ALL.clear()
	StateCampaign.campaign_names_count = -1
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ConstStates: cannot open %s" % path)
		return
	var source: String = path.get_file()
	AsciiNormalizer.reset_count()
	var row_index: int = -1
	var first := true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		row_index += 1
		for c: int in range(row.size()):
			row[c] = AsciiNormalizer.normalize(row[c], source, row_index)
		if first:
			first = false
			continue
		if row.size() < 1:
			continue
		var state_name: String = row[0].strip_edges() if row.size() > 0 else ""
		if state_name == "":
			continue
		var effects: Array[String] = []
		for col: int in [1, 2, 3]:
			var v: String = row[col] if col < row.size() else ""
			effects.append_array(StateTokens.parse_cell(v, EFFECT_VERBS, state_name, "Effect %d" % col))
		var removals: Array[String] = []
		for col: int in [4, 5]:
			var v: String = row[col] if col < row.size() else ""
			removals.append_array(StateTokens.parse_cell(v, REMOVAL_VERBS, state_name, "Removal %d" % (col - 3)))
		DATA[state_name] = {
			"effects":      effects,
			"removals":     removals,
			"afflict_text": row[6].strip_edges() if row.size() > 6 else "",
			"remove_text":  row[7].strip_edges() if row.size() > 7 else "",
			"special":      row[8].strip_edges() if row.size() > 8 else "",
			"is_stacking":  state_name in STACKING_STATES,
			"inflict_default": row[9].strip_edges() if row.size() > 9 else "",
		}
		ALL.append(state_name)
	file.close()
	AsciiNormalizer.report_file(source)


static func has_state(merc: MercenaryData, state_name: String) -> bool:
	var entry = merc.active_states.get(state_name)
	if entry == null:
		return false
	if entry is Dictionary:
		return entry.get("count", 0) > 0
	return int(entry) > 0


static func get_count(merc: MercenaryData, state_name: String) -> int:
	var entry = merc.active_states.get(state_name)
	if entry == null:
		return 0
	if entry is Dictionary:
		return entry.get("count", 0)
	return int(entry)


static func get_source(merc: MercenaryData, state_name: String) -> MercenaryData:
	var entry = merc.active_states.get(state_name)
	if entry is Dictionary:
		return entry.get("source", null)
	return null


#"passive" when a passive_effects token grants immunity, "state" when an active state token does, else "".
static func immune_source(merc: MercenaryData, state_name: String) -> String:
	if state_name in NEVER_IMMUNE:
		return ""
	var want := StateTokens.normalize_token(state_name)
	if merc.passive_effects.has("immune:" + want):
		return "passive"
	for e: Dictionary in active_effects(merc, "immune"):
		var p: PackedStringArray = e["parts"]
		if p.size() >= 2 and p[1].split(",").has(want):
			return "state"
	return ""


static func is_immune(merc: MercenaryData, state_name: String) -> bool:
	return immune_source(merc, state_name) != ""


#States.tsv "Inflict Default": {"inflict", "duration", "remove"} from the "|" parts, {} when there is none.
static func inflict_default(state_name: String) -> Dictionary:
	var data: Dictionary = DATA.get(state_name, {})
	var raw: String = str(data.get("inflict_default", "")).strip_edges()
	if raw == "":
		return {}
	var parts := raw.split("|")
	return {
		"inflict":  parts[0].strip_edges() if parts.size() > 0 else "",
		"duration": parts[1].strip_edges() if parts.size() > 1 else "",
		"remove":   parts[2].strip_edges() if parts.size() > 2 else "",
	}


static func has_inflict_default(state_name: String) -> bool:
	return not inflict_default(state_name).is_empty()


#True when a passive_effects token or an active effect reads "<verb>:<state_name>".
static func _has_state_token(merc: MercenaryData, verb: String, state_name: String) -> bool:
	var want := StateTokens.normalize_token(state_name)
	for tok: String in merc.passive_effects:
		var pp := tok.split(":")
		if pp.size() >= 2 and pp[0] == verb and pp[1].split(",").has(want):
			return true
	for e: Dictionary in active_effects(merc, verb):
		var p: PackedStringArray = e["parts"]
		if p.size() >= 2 and p[1].split(",").has(want):
			return true
	return false


#susceptible:<state> flaws the resist roll, protected:<state> enhances it; susceptible wins, nothing stacks.
static func resist_bias(merc: MercenaryData, state_name: String) -> Dictionary:
	if _has_state_token(merc, "susceptible", state_name):
		return {"enhancements": 0, "flaws": 1, "token": "susceptible"}
	if _has_state_token(merc, "protected", state_name):
		return {"enhancements": 1, "flaws": 0, "token": "protected"}
	return {"enhancements": 0, "flaws": 0, "token": ""}


#Size used against a knockdown; protected:deposed counts the merc as one Size larger.
static func knockdown_size(merc: MercenaryData) -> int:
	var size := int(merc.stats.get("size", 1))
	if _has_state_token(merc, "protected", DEPOSED):
		return size + 1
	return size


#False with a warning when an immune:<x> token names Dying or Climbing; other tokens pass.
static func immune_token_allowed(token: String, where: String) -> bool:
	var parts := token.split(":")
	if parts.size() < 2 or parts[0] != "immune":
		return true
	for spec: String in parts[1].split(","):
		var named := state_from_token(spec)
		if named == "":
			named = _never_immune_name(spec)
		if named in NEVER_IMMUNE:
			push_warning("%s: immunity to %s is not allowed, token %s ignored" % [where, named, token])
			return false
	return true


#Matches a NEVER_IMMUNE state by token before States.tsv has finished filling ALL.
static func _never_immune_name(spec: String) -> String:
	var wanted := StateTokens.normalize_token(spec)
	for state_name: String in NEVER_IMMUNE:
		if StateTokens.normalize_token(state_name) == wanted:
			return state_name
	return ""


#`root` names the state whose "apply:" token forces this one; "" is a direct application.
#`origin` is "<kind>:<name>" for the caller and `removal` overrides the rest verbs that may end the source.
#A direct application is refused when the merc is immune unless the merc chose it; cascade children always apply.
static func apply_state(merc: MercenaryData, state_name: String, source: MercenaryData = null,
		root: String = "", origin: String = "", removal: Array[String] = [],
		chosen: bool = false) -> bool:
	if root == "" and not chosen and is_immune(merc, state_name):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("STATE IMMUNE: %s %s" % [merc.merc_name, state_name])
		return false
	var src := StateSources.source_record(state_name, root, origin, removal)
	if state_name in STACKING_STATES:
		var current: int = get_count(merc, state_name)
		merc.active_states[state_name] = current + 1
		var tier_entry := StateSources.record_entry(merc, state_name, root == "")
		(tier_entry["sources"] as Array).append(src)
		_log_source(merc, state_name, src, current + 1)
		return true

	var was_active := has_state(merc, state_name)
	if root == "" or not was_active:
		if state_name in SOURCE_STATES:
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
	var data: Dictionary = DATA.get(state_name, {})
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
	for token: String in removal_methods(state_name):
		var verb: String = token.get_slice(":", 0)
		if verb != "" and not out.has(verb):
			out.append(verb)
	return out


#The removal verbs an "until:<verb>" tail stands for; [] when the verb is not one of UNTIL_VERBS.
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
	return has_state(merc, state_name) and StateSources.held_reason(merc, state_name, verb) == ""


#Ends what a rest of this verb may end: the newest free tier of a stacking state, else the whole state.
static func reduce_state_by(merc: MercenaryData, state_name: String, verb: String) -> Dictionary:
	var out := {"removed": false, "reason": "", "kind": "", "name": ""}
	if not has_state(merc, state_name):
		return out
	if state_name in STACKING_STATES:
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
		var current: int = get_count(merc, state_name)
		if current <= 1:
			remove_state(merc, state_name)
		else:
			merc.active_states[state_name] = current - 1
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
	var record = merc.active_states.get(APPLIED_BY_KEY)
	if not (record is Dictionary):
		return out
	var entry = (record as Dictionary).get(state_name)
	if not (entry is Dictionary):
		return out
	out.assign((entry as Dictionary).get("roots", []))
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
		merc.active_states.erase(APPLIED_BY_KEY)
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
		if child in STACKING_STATES:
			if dropped <= 0:
				continue
			var left: int = maxi(get_count(merc, child) - dropped, 0)
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


static func state_from_token(token: String) -> String:
	var wanted := StateTokens.normalize_token(token)
	for state_name: String in ALL:
		if StateTokens.normalize_token(state_name) == wanted:
			return state_name
	return ""


static func reduce_state(merc: MercenaryData, state_name: String) -> void:
	var current: int = get_count(merc, state_name)
	if current <= 1:
		remove_state(merc, state_name)
	elif state_name in STACKING_STATES:
		merc.active_states[state_name] = current - 1
		StateSources.pop_source(merc, state_name)
	else:
		merc.active_states.erase(state_name)


#Effect and Removal cells hold trait-style tokens: lowercase, ":"-separated, "_" for spaces, "|" between.
const EFFECT_VERBS: Array[String] = ["check", "check_vs", "attack", "attack_vs", "protected", "immune",
	"susceptible", "dot", "stat", "block", "move", "target", "defense", "damage_taken", "healing", "cost",
	"apply", "death_test", "skip_turn", "suffocate"]
const REMOVAL_VERBS: Array[String] = ["cause", "action", "interact", "damage", "effect", "time",
	"death_test", "respite", "furlough", "auto", "resist"]


#One entry per effect token of every active state: state, token, parts, count and source.
#A non-empty verb keeps only that verb's tokens, so the caller does not parse the rest.
static func active_effects(merc: MercenaryData, verb: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in merc.active_states.keys():
		if not (key is String) or not DATA.has(key):
			continue
		var state_name: String = key
		var count := get_count(merc, state_name)
		if count <= 0:
			continue
		for token: String in DATA[state_name]["effects"]:
			if not verb.is_empty() and token != verb and not token.begins_with(verb + ":"):
				continue
			out.append({"state": state_name, "token": token, "parts": StateTokens.token_parts(token),
				"count": count, "source": get_source(merc, state_name)})
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
		if q.size() > subject.size() and exceptions.has(q[q.size() - 1]):
			continue
		if q.size() == subject.size() and exceptions.has(q[q.size() - 1]):
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
			if merc.crawling and str(e["state"]) == DEPOSED:
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


static func removal_methods(state_name: String) -> Array[String]:
	if not DATA.has(state_name):
		return []
	var out: Array[String] = []
	out.assign(DATA[state_name]["removals"])
	return out


static func has_removal(state_name: String, prefix: String) -> bool:
	for r: String in removal_methods(state_name):
		if r.begins_with(prefix):
			return true
	return false


#Minutes of the first "time:N:hour|day" removal; 0 when the state has none.
static func removal_minutes(state_name: String) -> int:
	for r: String in removal_methods(state_name):
		var p := r.split(":")
		if p.size() < 3 or p[0] != "time" or not CAMPAIGN_UNITS.has(p[2]):
			continue
		return CampaignClock.minutes_of(p[1].to_int(), p[2])
	return 0


#Minutes a state may outlast its encounter; 0 when the full timer stands.
static func after_encounter_minutes(state_name: String) -> int:
	return int(AFTER_ENCOUNTER_MINUTES.get(state_name, 0))


#Forwarders for the callers that still reach these through ConstStates.
static func normalize_token(text: String) -> String:
	return StateTokens.normalize_token(text)


static func parse_apply_token(token: String) -> Dictionary:
	return StateTokens.parse_apply_token(token)


static func campaign_state_names() -> Array[String]:
	return StateCampaign.campaign_state_names()


static func snapshot_campaign_states(merc: MercenaryData) -> Dictionary:
	return StateCampaign.snapshot_campaign_states(merc)


static func restore_campaign_states(merc: MercenaryData, snap: Dictionary) -> void:
	StateCampaign.restore_campaign_states(merc, snap)


static func expire_campaign_states(merc: MercenaryData, now: int) -> Array[String]:
	return StateCampaign.expire_campaign_states(merc, now)
