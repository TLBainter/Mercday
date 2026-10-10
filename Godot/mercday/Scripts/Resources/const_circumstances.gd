class_name ConstCircumstances

const ATHLETICS_VIGOR       := "Athletics (Vigor)"
const ATTACK_DEXTERITY      := "Attack (Dexterity)"
const ATTACK_VIGOR          := "Attack (Vigor)"
const FINESSE_DEXTERITY     := "Finesse (Dexterity)"
const GRACE_DEXTERITY       := "Grace (Dexterity)"
const INTUITION_COGNITION   := "Intuition (Cognition)"
const NOTICE_COGNITION      := "Notice (Cognition)"
const PERFORMANCE_WILE      := "Performance (Wile)"
const POWER_VIGOR           := "Power (Vigor)"
const PRESENCE_VIGOR        := "Presence (Vigor)"
const RESIST_COGNITION      := "Resist (Cognition)"
const RESIST_DEXTERITY      := "Resist (Dexterity)"
const RESIST_VIGOR          := "Resist (Vigor)"
const RESIST_WILE           := "Resist (Wile)"
const SEARCH_COGNITION      := "Search (Cognition)"
const SPEECH_WILE           := "Speech (Wile)"

#Resist circumstance for one stat key.
static func resist_name(stat: String) -> String:
	return "Resist (%s)" % stat.capitalize()

static var DATA: Dictionary = {}
static var ALL: Array[String] = []


static func load_from_tsv(path: String) -> void:
	DATA.clear()
	ALL.clear()
	for row: PackedStringArray in TsvReader.load_tsv(path).slice(1):
		if row.size() < 5:
			continue
		var stat: String = row[0].strip_edges()
		var circ_name: String = row[1].strip_edges()
		if stat == "" or circ_name == "":
			continue
		var display_name: String = "%s (%s)" % [circ_name, stat]
		DATA[display_name] = {
			"stat": stat,
			"circumstance_name": circ_name,
			"description": row[2].strip_edges(),
			"rarity": row[4].strip_edges(),
		}
		ALL.append(display_name)


static func make_flags() -> Dictionary:
	return _fill(false)


static func make_bonuses() -> Dictionary:
	return _fill(0.0)


static func _fill(value: Variant) -> Dictionary:
	var filled: Dictionary = {}
	for name: String in ALL:
		filled[name] = value
	return filled
