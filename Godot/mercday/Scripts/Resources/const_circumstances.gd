class_name ConstCircumstances

const ATHLETICS_VIGOR       := "Athletics (Vigor)"
const ATTACK_DEXTERITY      := "Attack (Dexterity)"
const ATTACK_VIGOR          := "Attack (Vigor)"
const CLEVER_COGNITION      := "Clever (Cognition)"
const FINESSE_DEXTERITY     := "Finesse (Dexterity)"
const GRACE_DEXTERITY       := "Grace (Dexterity)"
const INTUITION_COGNITION   := "Intuition (Cognition)"
const INTUITION_WILE        := "Intuition (Wile)"
const NOTICE_COGNITION      := "Notice (Cognition)"
const PERFORMANCE_DEXTERITY := "Performance (Dexterity)"
const PERFORMANCE_WILE      := "Performance (Wile)"
const POWER_VIGOR           := "Power (Vigor)"
const PRESENCE_VIGOR        := "Presence (Vigor)"
const PRESENCE_WILE         := "Presence (Wile)"
const RESIST_COGNITION      := "Resist (Cognition)"
const RESIST_DEXTERITY      := "Resist (Dexterity)"
const RESIST_VIGOR          := "Resist (Vigor)"
const RESIST_WILE           := "Resist (Wile)"
const SEARCH_COGNITION      := "Search (Cognition)"
const SPEECH_WILE           := "Speech (Wile)"
const SPELLCAST_COGNITION   := "Spellcast (Cognition)"
const SPELLCAST_DEXTERITY   := "Spellcast (Dexterity)"
const SPELLCAST_VIGOR       := "Spellcast (Vigor)"
const SPELLCAST_WILE        := "Spellcast (Wile)"

static var DATA: Dictionary = {}
static var ALL: Array[String] = []


static func load_from_tsv(path: String) -> void:
	DATA.clear()
	ALL.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ConstCircumstances: cannot open %s" % path)
		return
	var first := true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line("\t")
		if first:
			first = false
			continue
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
			"base_bonus": 15.0,
		}
		ALL.append(display_name)
	file.close()


static func make_flags() -> Dictionary:
	var flags: Dictionary = {}
	for name: String in ALL:
		flags[name] = false
	return flags


static func make_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}
	for name: String in ALL:
		bonuses[name] = 0.0
	return bonuses
