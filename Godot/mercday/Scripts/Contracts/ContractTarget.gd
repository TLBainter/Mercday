class_name ContractTarget
extends RefCounted

#The Contracts.tsv Target cell as a spec Dictionary; the builder page and ContractGenerator share these statics.

const SOURCE_NPC := "npc"
const SOURCE_MONSTER := "monster"
const SOURCE_RANDOM := "random"
const SOURCES: Array[String] = [SOURCE_NPC, SOURCE_MONSTER, SOURCE_RANDOM]
const PICK_ALL := "all"
const PARTY := "party"
const LEVEL_FIXED := "fixed"
const LEVEL_PARTY := "party"
const LEVEL_RANGE := "range"
const COUNT_FIXED := "fixed"
const COUNT_PARTY := "party"
const SKEW_STATS: Array[String] = ["Cognition", "Dexterity", "Vigor", "Wile"]
const LEVEL_MAX := ContractDataValidator.LEVEL_CAP
const COUNT_MAX := 99
const PARTY_PLUS_MAX := 9
const DEFAULT_RANDOM := "random:level=party, count=party"
const MERCENARIES := "Mercenaries"
const TEXT_KEYS: Array[String] = ["tradition", "skew", "type"]
const MAX_DIGITS := 4


static func blank_spec() -> Dictionary:
	return {"ok": true, "error": "", "source": "", "name": "", "type": "", "pick": "", "level_mode": LEVEL_PARTY,
			"level": 0, "level_min": 0, "level_max": 0, "count_mode": COUNT_PARTY, "count": 1, "party_plus": 0,
			"tradition": "", "skew": ""}


#"" none | npc:<Title> | monster:<Type>[:<pick>] | random:[key=value, ...] with keys level, count, tradition, skew, type.
static func parse(cell: String) -> Dictionary:
	var text: String = cell.strip_edges()
	if text == "":
		return blank_spec()
	var colon: int = text.find(":")
	var source: String = text.substr(0, colon) if colon >= 0 else ""
	var rest: String = text.substr(colon + 1).strip_edges()
	if source == SOURCE_NPC:
		if rest == "":
			return _error("npc needs a title")
		var spec: Dictionary = blank_spec()
		spec["source"] = SOURCE_NPC
		spec["name"] = rest
		return spec
	if source == SOURCE_MONSTER:
		return _parse_monster(rest)
	if source == SOURCE_RANDOM:
		return _parse_random(rest)
	return _error("expected npc:, monster: or random: in '%s'" % text)


#An OpponentRequest for a Target spec: npc template or Mercs, the spec's level and count; never errors on a bad spec.
static func request(spec_cell: String, party: Array[MercenaryData], contract: ContractData) -> OpponentRequest:
	var spec: Dictionary = parse(spec_cell)
	var req := OpponentRequest.new()
	req.party.assign(party)
	req.difficulty = contract.difficulty if contract != null else 0.0
	req.contract_level = contract.contract_level if contract != null else -1
	req.tag = "Target"
	var title: String = str(spec.get("name", ""))
	if str(spec.get("source", "")) == SOURCE_NPC and DataManager.npc_templates.has(title):
		req.source = title
	else:
		req.source = "Mercs"
		var tradition: String = str(spec.get("tradition", "")).strip_edges()
		if str(spec.get("source", "")) == SOURCE_RANDOM and tradition != "":
			req.traditions.assign([tradition])
		else:
			var config: ContractConfig = ContractLibrary.config()
			req.traditions.assign([String(config.enemy_odd_tradition), String(config.enemy_tradition)])
	var level_mode: String = str(spec.get("level_mode", LEVEL_PARTY))
	if level_mode == LEVEL_FIXED:
		req.fixed_level = clampi(int(spec.get("level", 0)), 1, LEVEL_MAX)
	elif level_mode == LEVEL_RANGE:
		req.level_min = int(spec.get("level_min", 0))
		req.level_max = int(spec.get("level_max", 0))
	if str(spec.get("count_mode", COUNT_PARTY)) == COUNT_FIXED:
		req.count = int(spec.get("count", 1))
	else:
		req.count = maxi(1, party.size() + int(spec.get("party_plus", 0)))
	return req


static func compose(spec: Dictionary) -> String:
	var source: String = str(spec.get("source", ""))
	if source == SOURCE_NPC:
		return "%s:%s" % [SOURCE_NPC, str(spec.get("name", "")).strip_edges()]
	if source == SOURCE_MONSTER:
		var pick: String = str(spec.get("pick", "")).strip_edges()
		return "%s:%s:%s" % [SOURCE_MONSTER, str(spec.get("type", "")).strip_edges(), pick if pick != "" else PICK_ALL]
	if source != SOURCE_RANDOM:
		return ""
	var tokens: PackedStringArray = PackedStringArray([_level_token(spec), _count_token(spec)])
	for key: String in TEXT_KEYS:
		var value: String = str(spec.get(key, "")).strip_edges()
		if value != "":
			tokens.append("%s=%s" % [key, value])
	return "%s:%s" % [SOURCE_RANDOM, ", ".join(tokens)]


#True when compose(spec) gives a cell that parse reads back unchanged: no parse error and no "," inside a random value.
static func complete(spec: Dictionary) -> bool:
	var source: String = str(spec.get("source", ""))
	if not bool(spec.get("ok", true)) or not (source == "" or SOURCES.has(source)):
		return false
	if source == SOURCE_RANDOM:
		for key: String in TEXT_KEYS:
			if str(spec.get(key, "")).contains(","):
				return false
	return bool(parse(compose(spec))["ok"])


#The %target% text: npc "<Title> <first name>", the monster pick else its type, random tradition, type or Mercenaries.
static func display_name(cell: String, first_name: String) -> String:
	var spec: Dictionary = parse(cell)
	var source: String = str(spec["source"])
	if source == SOURCE_NPC:
		var first: String = first_name.strip_edges()
		return str(spec["name"]) if first == "" else "%s %s" % [spec["name"], first]
	if source == SOURCE_MONSTER:
		return str(spec["type"]) if str(spec["pick"]) == PICK_ALL else str(spec["pick"])
	if source == SOURCE_RANDOM:
		for key: String in ["tradition", "type"]:
			if str(spec[key]) != "":
				return str(spec[key])
		return MERCENARIES
	return ""


static func _parse_monster(rest: String) -> Dictionary:
	var parts: PackedStringArray = rest.split(":")
	if parts.size() > 2:
		return _error("monster takes <Type>:<pick>, got '%s'" % rest)
	var type_name: String = parts[0].strip_edges()
	if type_name == "":
		return _error("monster needs a creature type")
	var pick: String = parts[1].strip_edges() if parts.size() > 1 else ""
	var spec: Dictionary = blank_spec()
	spec["source"] = SOURCE_MONSTER
	spec["type"] = type_name
	spec["pick"] = pick if pick != "" else PICK_ALL
	return spec


static func _parse_random(rest: String) -> Dictionary:
	var spec: Dictionary = blank_spec()
	spec["source"] = SOURCE_RANDOM
	var seen: Array[String] = []
	for token: String in TsvReader.split_field(rest):
		var eq: int = token.find("=")
		var key: String = token.substr(0, eq).strip_edges() if eq >= 0 else token
		if eq < 0 or not (key == "level" or key == "count" or TEXT_KEYS.has(key)):
			return _error("unknown random token '%s'" % token)
		if seen.has(key):
			return _error("random key '%s' given twice" % key)
		seen.append(key)
		var why: String = _apply(spec, key, token.substr(eq + 1).strip_edges())
		if why != "":
			return _error(why)
	return spec


#Writes one random token into spec; returns the error, or "" when the value is good.
static func _apply(spec: Dictionary, key: String, value: String) -> String:
	if key == "level":
		return _apply_level(spec, value)
	if key == "count":
		return _apply_count(spec, value)
	if value == "":
		return "random %s is blank" % key
	if key == "skew" and not SKEW_STATS.has(value):
		return "skew '%s' is not one of %s" % [value, ", ".join(SKEW_STATS)]
	spec[key] = value
	return ""


static func _apply_level(spec: Dictionary, value: String) -> String:
	if value == PARTY:
		return ""
	var dash: int = value.find("-")
	var lo: int = _whole(value if dash < 0 else value.substr(0, dash).strip_edges())
	var hi: int = lo if dash < 0 else _whole(value.substr(dash + 1).strip_edges())
	if lo < 0 or hi < lo or hi > LEVEL_MAX:
		return "level '%s' is not party, n or lo-hi inside 0-%d" % [value, LEVEL_MAX]
	if dash < 0:
		spec["level_mode"] = LEVEL_FIXED
		spec["level"] = lo
	else:
		spec["level_mode"] = LEVEL_RANGE
		spec["level_min"] = lo
		spec["level_max"] = hi
	return ""


static func _apply_count(spec: Dictionary, value: String) -> String:
	if value.begins_with(PARTY):
		var plus: String = value.substr(PARTY.length()).strip_edges()
		var extra: int = 0
		if plus != "":
			extra = _whole(plus.substr(1).strip_edges()) if plus.begins_with("+") else -1
			if extra < 1 or extra > PARTY_PLUS_MAX:
				return "count '%s' is not party+1 to party+%d" % [value, PARTY_PLUS_MAX]
		spec["party_plus"] = extra
		return ""
	var count: int = _whole(value)
	if count < 1 or count > COUNT_MAX:
		return "count '%s' is not party, party+n or 1-%d" % [value, COUNT_MAX]
	spec["count_mode"] = COUNT_FIXED
	spec["count"] = count
	return ""


static func _level_token(spec: Dictionary) -> String:
	var mode: String = str(spec.get("level_mode", LEVEL_PARTY))
	if mode == LEVEL_FIXED:
		return "level=%d" % int(spec.get("level", 0))
	if mode == LEVEL_RANGE:
		return "level=%d-%d" % [int(spec.get("level_min", 0)), int(spec.get("level_max", 0))]
	return "level=" + PARTY


static func _count_token(spec: Dictionary) -> String:
	if str(spec.get("count_mode", COUNT_PARTY)) == COUNT_FIXED:
		return "count=%d" % int(spec.get("count", 1))
	var extra: int = int(spec.get("party_plus", 0))
	return "count=" + PARTY + ("+%d" % extra if extra > 0 else "")


#A whole number in digits only, else -1; leading zeros do not count toward MAX_DIGITS, so the range check decides.
static func _whole(text: String) -> int:
	var digits: String = text.lstrip("0")
	if text == "" or text.lstrip("0123456789") != "" or digits.length() > MAX_DIGITS:
		return -1
	return digits.to_int()


static func _error(why: String) -> Dictionary:
	var spec: Dictionary = blank_spec()
	spec["ok"] = false
	spec["error"] = why
	return spec
