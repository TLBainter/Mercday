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
	for row: PackedStringArray in TsvReader.load_tsv(path).slice(1):
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
			"inflict_default": row[9].strip_edges() if row.size() > 9 else "",
		}
		ALL.append(state_name)


static func has_state(merc: MercenaryData, state_name: String) -> bool:
	var entry = merc.active_states.get(state_name)
	if entry == null:
		return false
	if entry is Dictionary:
		return entry.get("count", 0) > 0
	return int(entry) > 0


#Names of the known states the merc holds at a count above zero, in active_states order.
static func held_state_names(merc: MercenaryData) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in merc.active_states.keys():
		if key is String and DATA.has(key) and has_state(merc, key as String):
			out.append(key as String)
	return out


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
	for e: Dictionary in StateEffects.active_effects(merc, "immune"):
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
	for e: Dictionary in StateEffects.active_effects(merc, verb):
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


static func state_from_token(token: String) -> String:
	var wanted := StateTokens.normalize_token(token)
	for state_name: String in ALL:
		if StateTokens.normalize_token(state_name) == wanted:
			return state_name
	return ""


#Effect and Removal cells hold trait-style tokens: lowercase, ":"-separated, "_" for spaces, "|" between.
const EFFECT_VERBS: Array[String] = ["check", "check_vs", "attack", "attack_vs", "protected", "immune",
	"susceptible", "dot", "stat", "block", "move", "target", "defense", "damage_taken", "healing", "cost",
	"apply", "death_test", "skip_turn", "suffocate"]
const REMOVAL_VERBS: Array[String] = ["cause", "action", "interact", "damage", "effect", "time",
	"death_test", "respite", "furlough", "auto", "resist"]


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
