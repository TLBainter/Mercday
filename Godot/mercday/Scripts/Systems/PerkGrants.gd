class_name PerkGrants

#Tokens that are permanent stat/grant effects applied immediately on acquisition.
#All others are conditional; stored and queried at runtime.
const PERMANENT_PREFIXES: PackedStringArray = [
	"stat:", "grant:", "immune:", "protected:", "susceptible:",
]

#True while resolve_deferred_grants re-runs a parked grant, so it is never parked twice.
static var _resolving_deferred: bool = false


#Appends perk to owned unless a perk of the same name is already there; false when nothing was added.
static func _add_perk(owned: Array[TraitData], perk: TraitData) -> bool:
	if perk == null:
		return false
	for held: TraitData in owned:
		if held != null and held.trait_name == perk.trait_name:
			return false
	owned.append(perk)
	return true


#The one place a weapon perk is added; returns the sheet detail, or "" when nothing was added.
static func grant_weapon_perk(merc: MercenaryData, perk: TraitData, source: String = "") -> String:
	if merc == null or not _add_perk(merc.weapon_perks, perk):
		return ""
	return _grant_detail("weapon", perk, source)


#The one place an armor perk is added; its permanent tokens apply once, here.
static func grant_armor_perk(merc: MercenaryData, perk: TraitData, source: String = "") -> String:
	if merc == null or not _add_perk(merc.armor_perks, perk):
		return ""
	_apply_permanent_tokens(merc, perk)
	return _grant_detail("armor", perk, source)


#"<kind> <gear key> perk <name>", the shape the level-up log already prints.
static func _grant_detail(kind: String, perk: TraitData, source: String) -> String:
	var detail: String = "%s %s perk %s" % [kind, perk.gear_key, WeaponArmorPerkLibrary.perk_display_name(perk)]
	if source != "":
		detail += " (%s)" % source
	return detail


#Stat and circumstance grants on an armor perk cell act the moment the perk is gained.
static func _apply_permanent_tokens(merc: MercenaryData, perk: TraitData) -> void:
	if perk.effect_dsl == "" or perk.effect_dsl.begins_with("SPECIAL:"):
		return
	var is_permanent: bool = false
	for token: String in perk.effect_dsl.split("|"):
		var t: String = token.strip_edges()
		for prefix: String in PERMANENT_PREFIXES:
			if t.begins_with(prefix):
				is_permanent = true
				break
		if is_permanent:
			break
	if not is_permanent:
		return
	if merc.stats_baseline.is_empty():
		StatCalculator.prime(merc)
	TraitDSL.apply_dsl_to_merc(merc, perk.effect_dsl, perk.trait_name)
	StatCalculator.refresh(merc)


#True when the grant was parked: generation applies trait cells before any gear is equipped.
static func defer_gear_grant(merc: MercenaryData, dsl: String, source: String) -> bool:
	if merc == null or _resolving_deferred or merc.gear_grants_resolved:
		return false
	if merc.equipped_weapon != null or merc.offhand_weapon != null or merc.equipped_armor != null:
		return false
	merc.deferred_gear_grants.append({"dsl": dsl, "source": source})
	return true


#Re-runs every parked grant now that the merc carries gear; the pools filter to what is held.
static func resolve_deferred_grants(merc: MercenaryData) -> void:
	if merc == null:
		return
	merc.gear_grants_resolved = true
	if merc.deferred_gear_grants.is_empty():
		return
	var pending: Array[Dictionary] = merc.deferred_gear_grants.duplicate()
	merc.deferred_gear_grants.clear()
	_resolving_deferred = true
	for entry: Dictionary in pending:
		TraitDSL.apply_dsl_to_merc(merc, str(entry.get("dsl", "")), str(entry.get("source", "")))
	_resolving_deferred = false


#A grant with no row for any held gear is dropped; the encounter log and the sheet both record it.
static func log_grant_skipped(merc: MercenaryData, token: String) -> void:
	if merc == null:
		return
	var line: String = "PERK GRANT SKIPPED: %s %s (no held gear)" % [merc.merc_name, token]
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose(line)
	merc.level_up_log.append({"level": int(merc.stats.get("level", 0)), "tier": "Gear",
		"option": "perk_grant_skipped", "detail": line})


#Weapon library rows; filter matches a trait_category or part of a weapon type key.
#Action rows are drawable too: choosing a weapon perk may pick either kind.
static func _weapon_perk_pool(filter: String) -> Array[TraitData]:
	var pool: Array[TraitData] = []
	for key: String in DataManager.weapon_trait_library:
		var key_match: bool = filter == "" or filter == "any" or key.to_lower().contains(filter)
		for entry: Variant in (DataManager.weapon_trait_library[key] as Array):
			var td: TraitData = entry as TraitData
			if td == null:
				continue
			if not key_match and td.trait_category.to_lower() != filter:
				continue
			pool.append(td)
	return pool


#Perk rows of the armor library, whose keys are the armor types Light, Medium, Heavy and Bulky.
static func _armor_perk_pool(filter: String) -> Array[TraitData]:
	var pool: Array[TraitData] = []
	for key: String in DataManager.armor_trait_library:
		if filter != "" and filter != "any" and key.to_lower() != filter:
			continue
		for entry: Variant in (DataManager.armor_trait_library[key] as Array):
			var td: TraitData = entry as TraitData
			if td == null or td.trait_type != "Perk":
				continue
			pool.append(td)
	return pool


#Perk rows tagged into a named group by Traits.tsv column 11 or derived from Weapons.tsv.
static func _perk_group_pool(group: String) -> Array[TraitData]:
	var pool: Array[TraitData] = []
	var key: String = DataManager.normalize_perk_group(group)
	if key == "":
		return pool
	for entry: Variant in (DataManager.perk_group_library.get(key, []) as Array):
		var td: TraitData = entry as TraitData
		if td == null or td.trait_type != "Perk":
			continue
		pool.append(td)
	return pool


#Draws count group perks the merc lacks, routes each by trait_source and applies its own cell.
#Weapon and Armor members draw only from gear the merc holds; with no gear yet the token waits.
static func grant_random_group_perks(merc: MercenaryData, group: String, count: int, token: String,
		source_name: String = "") -> void:
	var pool: Array[TraitData] = _perk_group_pool(group)
	if pool.is_empty():
		TraitDSL.warn_token_once(token, "has no perk group members")
		return
	if _pool_needs_gear(pool) and defer_gear_grant(merc, token, source_name):
		return
	var held: Dictionary = {}
	var sources: Array = [merc.weapon_perks, merc.armor_perks, merc.perks, merc.drawbacks, merc.descriptors]
	for source: Variant in sources:
		for entry: Variant in (source as Array):
			var held_td: TraitData = entry as TraitData
			if held_td:
				held[held_td.trait_name] = true
	var gear_keys: Dictionary = WeaponArmorPerkLibrary.held_gear_keys(merc)
	var weapon_keys: Array = gear_keys["weapon"]
	var armor_keys: Array = gear_keys["armor"]
	var choices: Array[TraitData] = []
	for td: TraitData in pool:
		if held.has(td.trait_name):
			continue
		if td.trait_source == "Weapon" and not weapon_keys.has(td.gear_key):
			continue
		if td.trait_source == "Armor" and not armor_keys.has(td.gear_key):
			continue
		choices.append(td)
	if choices.is_empty():
		log_grant_skipped(merc, token)
		return
	choices.shuffle()
	for i: int in range(mini(count, choices.size())):
		var drawn: TraitData = choices[i]
		match drawn.trait_source:
			"Weapon":
				grant_weapon_perk(merc, drawn, source_name)
				TraitDSL.apply_dsl_to_merc(merc, drawn.effect_dsl, drawn.trait_name)
			"Armor":
				grant_armor_perk(merc, drawn, source_name)
			_:
				TraitDSL.assign_trait(merc, drawn)
				TraitDSL.apply_dsl_to_merc(merc, drawn.effect_dsl, drawn.trait_name)
		merc.group_perk_cells_applied[drawn.trait_name] = true


static func _pool_needs_gear(pool: Array[TraitData]) -> bool:
	for td: TraitData in pool:
		if td.trait_source == "Weapon" or td.trait_source == "Armor":
			return true
	return false


#Weapon and armor perk grants draw only from held gear; with no gear yet the token waits.
static func grant_gear_perks(merc: MercenaryData, kind: String, filter: String, count: int,
		token: String, source_name: String = "") -> void:
	var pool: Array[TraitData] = _weapon_perk_pool(filter) if kind == "weapon" else _armor_perk_pool(filter)
	if pool.is_empty():
		TraitDSL.warn_token_once(token, "has no perk left to draw")
		return
	if defer_gear_grant(merc, token, source_name):
		return
	var owned: Array[TraitData] = merc.weapon_perks if kind == "weapon" else merc.armor_perks
	var keys: Array = WeaponArmorPerkLibrary.held_gear_keys(merc)[kind]
	var held: Dictionary = {}
	for td: TraitData in owned:
		if td != null:
			held[td.trait_name] = true
	var choices: Array[TraitData] = []
	for td: TraitData in pool:
		if td == null or held.has(td.trait_name) or not keys.has(td.gear_key):
			continue
		choices.append(td)
	if choices.is_empty():
		log_grant_skipped(merc, token)
		return
	choices.shuffle()
	for i: int in range(mini(count, choices.size())):
		if kind == "weapon":
			grant_weapon_perk(merc, choices[i], source_name)
		else:
			grant_armor_perk(merc, choices[i], source_name)
