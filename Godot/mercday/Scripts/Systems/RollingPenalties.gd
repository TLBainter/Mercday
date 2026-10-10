class_name RollingPenalties

const CATEGORIES: PackedStringArray = ["location", "ancestry", "bloodline", "heritage", "lifepath", "tradition"]
const STAT_CATEGORIES: PackedStringArray = ["ancestry", "bloodline", "heritage"]

static var rolling_penalties: Dictionary = new_table(CATEGORIES)
static var rolling_penalty_age: Dictionary = new_table(CATEGORIES)
static var rolling_stat_penalties: Dictionary = new_table(STAT_CATEGORIES)
static var rolling_stat_penalty_age: Dictionary = new_table(STAT_CATEGORIES)
static var tradition_batch_counts: Dictionary = {}
#NPCs roll against their own store, so an NPC never shifts the merc odds.
static var npc_penalties: Dictionary = new_table(CATEGORIES)
static var npc_penalty_age: Dictionary = new_table(CATEGORIES)


static func new_table(categories: PackedStringArray) -> Dictionary:
	var t: Dictionary = {}
	for c: String in categories:
		t[c] = {}
	return t


#The merc store and batch counts; restore() puts them back so a probe leaves no trace on later rolls.
static func snapshot() -> Dictionary:
	return {
		"counts": tradition_batch_counts.duplicate(true),
		"penalties": rolling_penalties.duplicate(true),
		"age": rolling_penalty_age.duplicate(true),
		"stat": rolling_stat_penalties.duplicate(true),
		"stat_age": rolling_stat_penalty_age.duplicate(true),
	}


static func restore(snap: Dictionary) -> void:
	tradition_batch_counts = snap["counts"]
	rolling_penalties = snap["penalties"]
	rolling_penalty_age = snap["age"]
	rolling_stat_penalties = snap["stat"]
	rolling_stat_penalty_age = snap["stat_age"]


static func clear_all() -> void:
	for table: Dictionary in [rolling_penalties, rolling_penalty_age, rolling_stat_penalties,
			rolling_stat_penalty_age, npc_penalties, npc_penalty_age]:
		for cat: Variant in table:
			(table[cat] as Dictionary).clear()
	tradition_batch_counts.clear()


static func dominant_physical_stat(data: AncestryData) -> String:
	if data.max_vigor > data.max_dexterity:
		return "vigor"
	if data.max_dexterity > data.max_vigor:
		return "dexterity"
	if data.max_vigor > 0:
		return "balanced_physical"
	return ""


static func dominant_mental_stat(data: HeritageData) -> String:
	if data.max_cognition > data.max_wile:
		return "cognition"
	if data.max_wile > data.max_cognition:
		return "wile"
	if data.max_cognition > 0:
		return "balanced_mental"
	return ""


static func get_penalty_boosts(category: String, npc: bool = false) -> Dictionary:
	var table: Dictionary = npc_penalties if npc else rolling_penalties
	var boosts: Dictionary = {}
	for name: String in table.get(category, {}):
		var penalty: float = table[category][name] as float
		if penalty > 0.0:
			boosts[name] = -penalty
	return boosts


#Subtracts each rolling penalty of the category in table from the matching flat boost.
static func subtract_into(flat: Dictionary, table: Dictionary, category: String) -> void:
	for pen_name: String in table[category]:
		flat[pen_name] = (flat.get(pen_name, 0.0) as float) - (table[category][pen_name] as float)


#Ages one penalty table: a rolled key doubles, an unrolled one decays by 1.0 and drops at age 10 or zero.
static func step_rolling_penalties(penalties: Dictionary, ages: Dictionary, rolled: Dictionary) -> void:
	for key: String in penalties.keys():
		var penalty: float = penalties[key] as float
		if rolled.has(key):
			ages[key] = 0
			penalties[key] = penalty * 2.0 if penalty > 0.0 else penalty
		else:
			var age: int = (ages.get(key, 0) as int) + 1
			if age >= 10:
				penalties.erase(key)
				ages.erase(key)
				continue
			var updated: float = maxf(0.0, penalty - 1.0)
			if updated == 0.0:
				penalties.erase(key)
				ages.erase(key)
			else:
				penalties[key] = updated
				ages[key] = age
	for key: String in rolled:
		if not penalties.has(key):
			penalties[key] = 5.0
			ages[key] = 0


#An NPC steps only its own store and skips the recessive and stat entries.
static func update_rolling_penalties(merc: MercenaryData, npc: bool = false) -> void:
	var rolled: Dictionary = new_table(CATEGORIES)

	if merc.starting_location:
		rolled["location"][merc.starting_location.location_name] = true
	if merc.ancestry:
		rolled["ancestry"][merc.ancestry.ancestry_name] = true
	if merc.recessive_ancestry and not npc:
		rolled["ancestry"][merc.recessive_ancestry.ancestry_name] = true
	if merc.bloodline:
		rolled["bloodline"][merc.bloodline.ancestry_name] = true
	if merc.recessive_bloodline and not npc:
		rolled["bloodline"][merc.recessive_bloodline.ancestry_name] = true
	if merc.heritage:
		rolled["heritage"][merc.heritage.heritage_name] = true
	if merc.lifepaths.size() > 0:
		rolled["lifepath"][merc.lifepaths[0].event_name] = true
	if merc.tradition:
		rolled["tradition"][merc.tradition.tradition_name] = true

	var penalties: Dictionary = npc_penalties if npc else rolling_penalties
	var ages: Dictionary = npc_penalty_age if npc else rolling_penalty_age
	for category: String in penalties:
		step_rolling_penalties(penalties[category], ages[category], rolled.get(category, {}))
	if npc:
		return

	var dom_ancestry := dominant_physical_stat(merc.ancestry) if merc.ancestry else ""
	var dom_rec_ancestry := dominant_physical_stat(merc.recessive_ancestry) if merc.recessive_ancestry else ""
	var dom_bloodline := dominant_physical_stat(merc.bloodline) if merc.bloodline else ""
	var dom_rec_bloodline := dominant_physical_stat(merc.recessive_bloodline) if merc.recessive_bloodline else ""
	var dom_heritage := dominant_mental_stat(merc.heritage) if merc.heritage else ""

	var stat_triggered: Dictionary = {
		"ancestry": {},
		"bloodline": {},
		"heritage": {},
	}
	if dom_ancestry != "":
		stat_triggered["ancestry"][dom_ancestry] = true
	if dom_rec_ancestry != "" and dom_rec_ancestry != dom_ancestry:
		stat_triggered["ancestry"][dom_rec_ancestry] = true
	if dom_bloodline != "":
		stat_triggered["bloodline"][dom_bloodline] = true
	if dom_rec_bloodline != "" and dom_rec_bloodline != dom_bloodline:
		stat_triggered["bloodline"][dom_rec_bloodline] = true
	if dom_heritage != "":
		stat_triggered["heritage"][dom_heritage] = true

	for category: String in rolling_stat_penalties:
		step_rolling_penalties(rolling_stat_penalties[category], rolling_stat_penalty_age[category],
				stat_triggered.get(category, {}))
