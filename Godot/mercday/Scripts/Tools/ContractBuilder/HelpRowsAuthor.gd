class_name HelpRowsAuthor

#Card 745: the five local Help contracts, each a copy of the Cat Stuck in Tree! row with its own check and
#descriptions, written through ContractRowWriter. Run once with -- --author-help-rows; a name already on the sheet
#is skipped.

const LOCATIONS: Array[String] = ["Aerdis", "Aldurstein", "Miliim", "Zukei", "Kathaya", "Copari", "Suorr", "Rossade",
	"Buern", "Vaernebo", "Cyfrolaef"]
const TERRAIN_ODDS: String = "Urban 70, Forest 30"
const LEVEL_MAX: int = 4
const ISSUER: String = "Commoner"
const DIFFICULTY: float = 0.5
const MULTIPLIER: float = 0.5
const CHECK_TIME: int = 60
const CONSEQUENCE: Dictionary = {"retry": -1, "ep": -1}

#Per contract: name, check, attributes, circumstances, knowledges, tools, traditions, descriptions.
const ROWS: Array = [
	["Move My Heavy Furniture", "Move Heavy Furniture", ["Vigor", "Dexterity"],
		[["Athletics (Vigor)", 10], ["Power (Vigor)", 10], ["Grace (Dexterity)", 5], ["Finesse (Dexterity)", 0]],
		[["Logistics", 15], ["Engineering", 10], ["Architecture", 5], ["Assembly", 5], ["Lowborn", 5],
			["Mechanology", 5]],
		[["Carpenter's", 10], ["Mason's", 10], ["Climber's", 5], ["Cooper's", 5]],
		[["Warrior", 15], ["Brave", 10], ["Honorable", 5], ["Hellion", 5], ["Mage", -10], ["Sorcerer", -10],
			["Mystech", -5], ["Performer", -5], ["Divine", -5]],
		["I bought a wardrobe twice the size of my doorway. Move it in, and the bed too, without breaking either.",
			"My back gave out and the landlord wants the place empty by sundown. "
			+ "Carry everything down three flights of stairs."]],
	["Pose for a Painting", "Pose for a Painting", ["Wile", "Vigor"],
		[["Presence (Wile)", 10], ["Performance (Wile)", 5], ["Presence (Vigor)", 5], ["Athletics (Vigor)", 0]],
		[["High Society", 15], ["Dramaturgy", 10], ["Dancing", 5], ["Philosophy", 5], ["Psychology", 5],
			["Illustromancy", 5]],
		[["Artist's", 15], ["Groomer's", 10], ["Tailor's", 5], ["Perfumer's", 5]],
		[["Performer", 15], ["Divine", 10], ["Honorable", 5], ["Mage", 5], ["Sorcerer", 5], ["Hellion", -10],
			["Warrior", -10], ["Brave", -5], ["Mystech", -5]],
		["I am painting a portrait of a bold adventurer and need someone to stand still in armor for an afternoon.",
			"My patron wants a heroic canvas. Hold the pose, look fierce and do not sneeze on the easel."]],
	["Weed My Garden", "Weed the Garden", ["Vigor", "Cognition"],
		[["Notice (Cognition)", 10], ["Search (Cognition)", 5], ["Athletics (Vigor)", 5], ["Power (Vigor)", 0]],
		[["Agriculture", 15], ["Botany", 15], ["Plant", 10], ["Biology", 5]],
		[["Gardener's", 15], ["Herbologist's", 10], ["Survivalist's", 5], ["Scavenger's", 5]],
		[["Chymist", 15], ["Divine", 10], ["Honorable", 5], ["Brave", 5], ["Mage", 5], ["Hellion", -10],
			["Performer", -10], ["Sorcerer", -5], ["Mystech", -5]],
		["The weeds have taken my vegetable beds. Pull every one and leave the carrots standing.",
			"My knees are done and the thistles are winning. Clear the garden before the frost."]],
	["Cook Dinner for Me", "Cook the Dinner", ["Cognition", "Dexterity"],
		[["Clever (Cognition)", 10], ["Finesse (Dexterity)", 10], ["Intuition (Cognition)", 5],
			["Grace (Dexterity)", 0]],
		[["Culinary", 15], ["High Society", 10], ["Agriculture", 5], ["Botany", 5], ["Toxicology", 5],
			["Biology", 5]],
		[["Chef's", 15], ["Brewer's", 10], ["Herbologist's", 5], ["Fisherman's", 5]],
		[["Chymist", 15], ["Performer", 10], ["Divine", 5], ["Honorable", 5], ["Hellion", 5], ["Warrior", -10],
			["Mystech", -10], ["Brave", -5], ["Sorcerer", -5]],
		["My in-laws arrive tonight and I cannot boil water. Cook a dinner for six that they will remember kindly.",
			"The cook quit an hour before the feast. Take the kitchen and get a meal on the table."]],
	["Officiate My Wedding", "Officiate the Wedding", ["Wile", "Cognition"],
		[["Speech (Wile)", 15], ["Presence (Wile)", 10], ["Intuition (Wile)", 5], ["Clever (Cognition)", 5],
			["Notice (Cognition)", 0]],
		[["Theology", 15], ["Diplomacy", 10], ["High Society", 10], ["Law", 5], ["Linguistics", 5]],
		[["Calligrapher's", 10], ["Missionary's", 10], ["Book Binder's", 5], ["Groomer's", 5]],
		[["Divine", 15], ["Honorable", 15], ["Performer", 5], ["Mage", 5], ["Hellion", -15], ["Sorcerer", -10],
			["Warrior", -5], ["Brave", -5], ["Mystech", -5]],
		["Our priest fell ill and the wedding is tomorrow. Stand up front, say the words and keep both families calm.",
			"Two families, one small chapel, no officiant. Run the ceremony and make it feel proper."]],
]


static func drafts() -> Array[ContractDraft]:
	var out: Array[ContractDraft] = []
	for spec: Array in ROWS:
		out.append(_draft(spec))
	return out


#One {"name", "ok", "error", "exists", "line", "check"} per draft in ROWS order; a name on the sheet is not written.
static func author() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for draft: ContractDraft in drafts():
		var record: Dictionary = {"name": draft.contract_name, "ok": false, "error": "", "exists": false, "line": -1,
			"check": false}
		if _on_sheet(draft.contract_name):
			record["exists"] = true
			out.append(record)
			continue
		var written: Dictionary = ContractRowWriter.write(draft)
		record["ok"] = bool(written["ok"])
		record["error"] = String(written["error"])
		record["line"] = int(written["line"])
		record["check"] = bool(written["check"])
		out.append(record)
	return out


static func _on_sheet(title: String) -> bool:
	for known: String in ContractBuilderData.contract_names():
		if known.to_lower() == title.to_lower():
			return true
	return false


static func _draft(spec: Array) -> ContractDraft:
	var draft: ContractDraft = ContractDraft.new()
	draft.contract_name = spec[0]
	draft.contract_type = "Help"
	draft.possible_locations.assign(LOCATIONS)
	draft.terrain_odds = TERRAIN_ODDS
	draft.level_min = 0
	draft.level_max = LEVEL_MAX
	draft.issuer_type = "person"
	draft.issuer = ISSUER
	draft.difficulty_min = DIFFICULTY
	draft.difficulty_max = DIFFICULTY
	draft.story = false
	draft.style = ContractRowWriter.CHECK_STYLE
	draft.completion = ContractRowWriter.CHECK_PREFIX + String(spec[1])
	draft.merc_min = 1
	draft.merc_max = 1
	draft.local = true
	draft.descriptions.assign(spec[7])
	var attributes: Array[String] = []
	attributes.assign(spec[2])
	draft.check_row = [String(spec[1]), CheckSheet.format_names(attributes),
		CheckSheet.format_percents(_entries(spec[3], "percent")), CheckSheet.format_percents(_entries(spec[4], "percent")),
		CheckSheet.format_percents(_entries(spec[5], "percent")), CheckSheet.format_signed(_entries(spec[6], "value")),
		CheckSheet.format_multiplier(MULTIPLIER), CheckSheet.format_time(CHECK_TIME), CheckSheet.format_opposed(false),
		"", CheckSheet.format_consequence(CONSEQUENCE)]
	return draft


static func _entries(pairs: Array, number_key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pair: Array in pairs:
		out.append({"name": String(pair[0]), number_key: int(pair[1])})
	return out
