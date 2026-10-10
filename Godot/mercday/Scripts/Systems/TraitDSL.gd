class_name TraitDSL

#max_ spellings that name a Stats.tsv row instead of a core maximum
const MAX_STAT_ALIASES: Dictionary = {
	"max_hp": "maximum_hit_points",
	"max_ep": "maximum_endurance_points",
	"max_mp": "maximum_magic_points",
}

#Tokens already reported this run; keeps one dead token from warning once per merc
static var _warned_tokens: Dictionary = {}

#Prefixes owned by combat, contract or perk code; generation skips them without a warning
const RUNTIME_PREFIXES: PackedStringArray = [
	"action:", "reactive_action:", "on_hit:", "on_pain:", "on_crit:", "on_kill:", "on_grapple:",
	"spend:", "while:", "to:", "chance:", "repeat:", "per:", "lasting:", "inflict:", "damage:",
	"resource:", "damage_dealt:", "damage_taken:", "reward:", "success_chance:", "remove_self",
	"weapon_enhance:", "weapon_stat:", "weapon_two_handed:", "weapon_passive:",
	"armor_weight_ignore:", "armor_ep_ignore:", "armor_fatigue_zero:",
]


#source_name names the trait the cell came from; it rides along on the auras it grants.
static func apply_dsl_to_merc(merc: MercenaryData, dsl: String, source_name: String = "") -> void:
	if dsl == "" or dsl.begins_with("SPECIAL:"):
		return
	for token: String in dsl.split("|"):
		var t: String = token.strip_edges()
		if t.begins_with("SPECIAL:"):
			continue
		if t.begins_with("stat:max_"):
			_tok_stat_max(merc, t)
		elif t.begins_with("stat:min_"):
			_tok_stat_min(merc, t)
		elif t.begins_with("grant:ability:"):
			_tok_grant_ability(merc, t)
		elif t.begins_with("on:"):
			pass #Triggered effects are handled by the contract system, not at generation.
		elif t.begins_with("block:random:circumstance:unselected:"):
			_tok_block_random_circumstance(merc, t)
		elif t.begins_with("block:circumstance:") or t.begins_with("block_and_replace:circumstance:"):
			_tok_block_circumstance(merc, t)
		elif t.begins_with("grant:random:bloodline_traits:"):
			_tok_grant_random_bloodline_traits(merc, t)
		elif t.begins_with("grant:knowledge:"):
			_tok_grant_knowledge(merc, t)
		elif t.begins_with("grant:circumstance:"):
			_tok_grant_circumstance(merc, t)
		elif t.begins_with("grant:trait:"):
			_tok_grant_trait(merc, t)
		elif t.begins_with("grant:passive:"):
			merc.passive_effects.append(t)
			#Passive effects are evaluated at runtime by the game and combat code, not at generation.
		elif t.begins_with("grant:random:circumstance:"):
			_tok_grant_random_circumstance(merc, t)
		elif t.begins_with("grant:random:lifepath:"):
			_tok_grant_random_lifepath(merc, t)
		elif t.begins_with("grant:random:knowledge:"):
			_tok_grant_random_knowledge(merc, t)
		elif t.begins_with("grant:random:tool:"):
			_tok_grant_random_tool(merc, t)
		elif t.begins_with("grant:random:environ_stat:"):
			_grant_random_pool_stat(merc, t, DataManager.environment_types)
		elif t.begins_with("grant:random:creature_stat:"):
			_grant_random_pool_stat(merc, t, DataManager.creature_types)
		elif t.begins_with("stat:circumstance_boost:"):
			_tok_stat_circumstance_boost(merc, t)
		elif t.begins_with("stat:random:core_stat_max:"):
			_tok_stat_random_core_stat_max(merc, t)
		elif t.begins_with("stat:random:"):
			_tok_stat_random(merc, t)
		elif t.begins_with("grant:random:item:rarity:"):
			_tok_grant_random_item_rarity(merc, t)
		elif t.begins_with("aura:"):
			_apply_aura_token(merc, t, source_name)
		elif t.begins_with("immune:") or t.begins_with("protected:") or t.begins_with("susceptible:"):
			if ConstStates.immune_token_allowed(t, "Traits.tsv") and not merc.passive_effects.has(t):
				merc.passive_effects.append(t)
		elif t.begins_with("cost:"):
			_tok_cost(merc, t)
		elif t.begins_with("grant:random:perk_group:"):
			_tok_grant_random_perk_group(merc, t, source_name)
		elif t.begins_with("grant:random:") and t.contains("weapon_perk:"):
			_tok_grant_random_weapon_perk(merc, t, source_name)
		elif t.begins_with("grant:random:armor_perk:"):
			_tok_grant_random_armor_perk(merc, t, source_name)
		elif t.begins_with("grant:random:protection:"):
			_tok_grant_random_protection(merc, t)
		elif t.begins_with("remove:random:circumstance:"):
			_tok_remove_random_circumstance(merc, t)
		elif t.begins_with("stat:"):
			_tok_stat(merc, t)
		elif t.begins_with("remove:ability:"):
			continue
		else:
			_tok_unhandled(t)


static func _tok_stat_max(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 3:
		var stat_key: String = parts[1]
		var amount: int = _signed_int(parts[2])
		if MAX_STAT_ALIASES.has(stat_key):
			StatCalculator.add_flat(merc, MAX_STAT_ALIASES[stat_key] as String, float(amount))
		else:
			#StatCalculator reads only the core max_ keys
			if not TraitRuntime.CORE_STATS.has(stat_key.trim_prefix("max_")):
				warn_token_once(t, "writes a max_stats key that nothing reads")
			merc.max_stats[stat_key] = (merc.max_stats.get(stat_key, 0) as int) + amount


static func _tok_stat_min(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 3:
		#A key written as min_state_madness stores under state_madness.
		var floor_key: String = parts[1].substr("min_".length())
		var val: int = int(parts[2])
		merc.min_stats[floor_key] = maxi(merc.min_stats.get(floor_key, 0) as int, val)


static func _tok_grant_ability(merc: MercenaryData, t: String) -> void:
	var ability: String = t.substr("grant:ability:".length())
	match ability:
		"flying_pace":
			merc.stats["fly"] = 1.0
		"swimming_pace":
			merc.stats["swim"] = 1.0
		"climbing_pace":
			merc.stats["climb"] = 1.0
		"darksight":
			merc.stats["darksight"] = 1.0


static func _tok_block_random_circumstance(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 5:
		var count: int = int(parts[4])
		var candidates: Array[String] = available_circumstances(merc, ConstCircumstances.ALL)
		candidates.shuffle()
		for i: int in range(mini(count, candidates.size())):
			merc.blocked_circumstances.append(candidates[i])


static func _tok_block_circumstance(merc: MercenaryData, t: String) -> void:
	var do_replace: bool = t.begins_with("block_and_replace:")
	var prefix: String = "block_and_replace:circumstance:" if do_replace else "block:circumstance:"
	var targets: Array[String] = _resolve_circumstance_key(t.substr(prefix.length()))
	for display: String in targets:
		if not merc.blocked_circumstances.has(display):
			merc.blocked_circumstances.append(display)
		if merc.circumstance_flags.get(display, false):
			merc.circumstance_flags[display] = false
			if do_replace:
				var available: Array[String] = available_circumstances(merc, ConstCircumstances.ALL)
				if not available.is_empty():
					available.shuffle()
					merc.circumstance_flags[available[0]] = true


static func _tok_grant_random_bloodline_traits(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 5:
		var ancestry_names: Array = Array(parts[3].split(","))
		var count: int = int(parts[4])
		ancestry_names.shuffle()
		for i: int in range(mini(count, ancestry_names.size())):
			var ancestry: AncestryData = DataManager.ancestries.get(
					(ancestry_names[i] as String).strip_edges(), null) as AncestryData
			if not ancestry:
				continue
			var bl_names: Array[String] = []
			for bl_name: String in ancestry.possible_bloodlines:
				if bl_name != "Core" and DataManager.bloodlines.has(bl_name):
					bl_names.append(bl_name)
			if bl_names.is_empty():
				continue
			bl_names.shuffle()
			var bl: AncestryData = DataManager.bloodlines.get(bl_names[0], null) as AncestryData
			if bl:
				for trait_name: String in bl.perks + bl.drawbacks:
					var td: TraitData = lookup_trait(trait_name)
					if td:
						assign_trait(merc, td)


static func _tok_grant_knowledge(merc: MercenaryData, t: String) -> void:
	var k_name: String = t.substr("grant:knowledge:".length()).strip_edges()
	var k_data: UtilityTraitData = _find_knowledge(k_name)
	if k_data == null:
		warn_token_once(t, "has no Knowledges and Tools row")
	elif not _holds_utility(merc.knowledges, k_data):
		merc.knowledges.append(k_data)


static func _tok_grant_circumstance(merc: MercenaryData, t: String) -> void:
	var circ_key: String = t.substr("grant:circumstance:".length()).strip_edges()
	for display: String in _resolve_circumstance_key(circ_key):
		if not merc.blocked_circumstances.has(display):
			merc.circumstance_flags[display] = true


static func _tok_grant_trait(merc: MercenaryData, t: String) -> void:
	var trait_name: String = t.substr("grant:trait:".length()).strip_edges()
	var td: TraitData = lookup_trait(trait_name)
	if td:
		assign_trait(merc, td)


static func _tok_grant_random_circumstance(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	var pool: Array[String] = []
	var count: int = 1
	if parts.size() == 4 and parts[3].is_valid_int():
		#grant:random:circumstance:<n>  (legacy, no filter)
		count = int(parts[3])
		pool = ConstCircumstances.ALL.duplicate()
	elif parts.size() == 6 and parts[3] == "from":
		#grant:random:circumstance:from:<key1,key2,...>:<n>
		count = int(parts[5])
		for raw_key: String in parts[4].split(","):
			pool.append_array(_resolve_circumstance_key(raw_key.strip_edges()))
	elif parts.size() == 5:
		#grant:random:circumstance:<stat_or_name_filter>:<n>
		count = int(parts[4])
		var filter: String = parts[3].to_lower()
		for d: String in ConstCircumstances.ALL:
			var circ_data: Dictionary = ConstCircumstances.DATA[d] as Dictionary
			if TraitRuntime.CORE_STATS.has(filter):
				if (circ_data.get("stat", "") as String).to_lower() == filter:
					pool.append(d)
			else:
				if (circ_data.get("circumstance_name", "") as String).to_lower() == filter:
					pool.append(d)
	var available: Array[String] = available_circumstances(merc, pool)
	available.shuffle()
	for i: int in range(mini(count, available.size())):
		merc.circumstance_flags[available[i]] = true


static func _tok_grant_random_lifepath(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() < 5:
		return
	var category: String = parts[3].capitalize()
	var count: int = 1
	var category_lifepaths: Array = DataManager.lifepaths_by_category.get(category, []) as Array
	var candidates: Array[LifepathData] = []
	if parts.size() == 5:
		#grant:random:lifepath:<cat>:<n>
		count = int(parts[4])
		candidates.assign(category_lifepaths)
	elif parts.size() == 7 and parts[4] == "begins_with":
		#grant:random:lifepath:<cat>:begins_with:<prefix>:<n>
		var prefix: String = parts[5].replace("_", " ").to_lower()
		count = int(parts[6])
		for lp_data: LifepathData in category_lifepaths:
			if lp_data.event_name.to_lower().begins_with(prefix):
				candidates.append(lp_data)
	elif parts.size() == 7 and parts[4] == "from":
		#grant:random:lifepath:<cat>:from:<name1,name2,...>:<n>
		count = int(parts[6])
		var names: Array = []
		for raw: String in parts[5].split(","):
			names.append(raw.strip_edges().replace("_", " ").to_lower())
		for lp_data: LifepathData in category_lifepaths:
			if names.has(lp_data.event_name.to_lower()):
				candidates.append(lp_data)
	candidates.assign(LifepathRequirements.filter(merc, candidates))
	candidates.shuffle()
	for i: int in range(mini(count, candidates.size())):
		var granted_lp: LifepathData = candidates[i]
		merc.lifepaths.append(granted_lp)
		for trait_name: String in LifepathProgression.trait_names(granted_lp):
			var td: TraitData = lookup_trait(trait_name)
			if td:
				assign_trait(merc, td)


static func _tok_grant_random_knowledge(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	var count: int = 1
	var candidates: Array[UtilityTraitData] = []
	if parts.size() == 4 and parts[3].is_valid_int():
		count = int(parts[3])
		for k_key: String in DataManager.knowledges:
			candidates.append(DataManager.knowledges[k_key] as UtilityTraitData)
	elif parts.size() == 6 and parts[3] == "rarity":
		count = int(parts[5])
		var rarity_filter: String = parts[4].to_lower()
		for k_key: String in DataManager.knowledges:
			var k: UtilityTraitData = DataManager.knowledges[k_key] as UtilityTraitData
			if k.utility_rarity.to_lower() == rarity_filter:
				candidates.append(k)
	var available_k: Array[UtilityTraitData] = []
	for k: UtilityTraitData in candidates:
		if not _holds_utility(merc.knowledges, k):
			available_k.append(k)
	available_k.shuffle()
	for i: int in range(mini(count, available_k.size())):
		merc.knowledges.append(available_k[i])


static func _tok_grant_random_tool(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	var count: int = 1
	var candidates: Array[UtilityTraitData] = []
	if parts.size() == 4 and parts[3].is_valid_int():
		count = int(parts[3])
		for tool_key: String in DataManager.tools:
			candidates.append(DataManager.tools[tool_key] as UtilityTraitData)
	elif parts.size() == 6 and parts[3] == "from":
		count = int(parts[5])
		for raw: String in parts[4].split(","):
			var search: String = raw.strip_edges().replace("_", " ").to_lower()
			for stored: String in DataManager.tools:
				if stored.to_lower().begins_with(search):
					candidates.append(DataManager.tools[stored] as UtilityTraitData)
					break
	var available_t: Array[UtilityTraitData] = []
	for tool_data: UtilityTraitData in candidates:
		if not _holds_utility(merc.tools, tool_data):
			available_t.append(tool_data)
	available_t.shuffle()
	for i: int in range(mini(count, available_t.size())):
		merc.tools.append(available_t[i])


#grant:random:environ_stat or creature_stat:<n>:<value>; n shuffled pool entries each gain the value as a flat stat.
static func _grant_random_pool_stat(merc: MercenaryData, t: String, pool: Array) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 5:
		var count: int = int(parts[3])
		var amount: float = _signed_float(parts[4])
		var picks: Array = pool.duplicate()
		picks.shuffle()
		for i: int in range(mini(count, picks.size())):
			var stat_key: String = (picks[i] as String).to_lower().replace(" ", "_")
			StatCalculator.add_flat(merc, stat_key, amount)


static func _tok_stat_circumstance_boost(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 4:
		var targets: Array[String] = _resolve_circumstance_key(parts[2])
		var amount: float = _signed_float(parts[3])
		for display: String in targets:
			merc.circumstance_additional_bonus[display] = \
					(merc.circumstance_additional_bonus.get(display, 0.0) as float) + amount


static func _tok_stat_random_core_stat_max(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 4:
		var amount: int = _signed_int(parts[3])
		var chosen: String = "max_" + TraitRuntime.CORE_STATS[randi() % TraitRuntime.CORE_STATS.size()]
		merc.max_stats[chosen] = (merc.max_stats.get(chosen, 0) as int) + amount


static func _tok_stat_random(merc: MercenaryData, t: String) -> void:
	#stat:random:<key1>:<key2>:...:<val>; pick one random key from the list
	var parts: PackedStringArray = t.split(":")
	if parts.size() >= 4:
		var amount: int = _signed_int(parts[parts.size() - 1])
		var keys: Array[String] = []
		for i: int in range(2, parts.size() - 1):
			keys.append(parts[i])
		if not keys.is_empty():
			var chosen: String = keys[randi() % keys.size()]
			if chosen.begins_with("max_"):
				merc.max_stats[chosen] = (merc.max_stats.get(chosen, 0) as int) + amount
			else:
				StatCalculator.add_flat(merc, chosen, float(amount))


static func _tok_grant_random_item_rarity(merc: MercenaryData, t: String) -> void:
	#grant:random:item:rarity:<rarity1,rarity2,...>:<n>
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 6:
		var rarities: Array = []
		for r: String in parts[4].split(","):
			rarities.append(r.strip_edges().to_lower())
		var count: int = int(parts[5])
		var candidates: Array = []
		for item_name: String in DataManager.items:
			var item: Dictionary = DataManager.items[item_name] as Dictionary
			if rarities.has((item.get("item_rarity", "") as String).to_lower()):
				candidates.append(item)
		candidates.shuffle()
		for i: int in range(mini(count, candidates.size())):
			var row: Dictionary = candidates[i] as Dictionary
			var item := ItemData.new()
			item.item_name = String(row.get("item_name", ""))
			item.item_rarity = String(row.get("item_rarity", ""))
			item.item_type = String(row.get("item_type", ""))
			merc.items.append(item)


static func _tok_cost(merc: MercenaryData, t: String) -> void:
	#cost:<category>:<percent>  (negative = discount)
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 3:
		var category: String = parts[1]
		var amount: float = float(parts[2].trim_suffix("%"))
		merc.cost_modifiers[category] = (merc.cost_modifiers.get(category, 0.0) as float) + amount
		StatCalculator.add_flat(merc, category + "_cost_modifier", amount)


static func _tok_grant_random_perk_group(merc: MercenaryData, t: String, source_name: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() != 5:
		warn_token_once(t, "is an unparsed perk group token")
	else:
		var count: int = int(parts[4])
		if count > 0:
			PerkGrants.grant_random_group_perks(merc, parts[3], count, t, source_name)
		else:
			warn_token_once(t, "has no positive perk group count")


static func _tok_grant_random_weapon_perk(merc: MercenaryData, t: String, source_name: String) -> void:
	var tier: String = t.split(":")[2]
	var filter: String = ""
	if tier == "basic_weapon_perk":
		filter = "basic"
	elif tier == "specialized_weapon_perk":
		filter = "specialized"
	_grant_random_gear_perk(merc, t, source_name, "weapon", filter)


static func _tok_grant_random_armor_perk(merc: MercenaryData, t: String, source_name: String) -> void:
	_grant_random_gear_perk(merc, t, source_name, "armor", "")


#<n>, <filter>:<n> or type:<filter>:<n> after the perk name; a filter in the cell replaces the default one.
static func _grant_random_gear_perk(merc: MercenaryData, t: String, source_name: String,
		kind: String, filter: String) -> void:
	var parts: PackedStringArray = t.split(":")
	var count: int = 0
	if parts.size() == 4:
		count = int(parts[3])
	elif parts.size() == 5:
		filter = parts[3].to_lower()
		count = int(parts[4])
	elif parts.size() == 6 and parts[3] == "type":
		filter = parts[4].to_lower()
		count = int(parts[5])
	else:
		warn_token_once(t, "is an unparsed %s perk token" % kind)
	if count > 0:
		PerkGrants.grant_gear_perks(merc, kind, filter, count, t, source_name)


static func _tok_grant_random_protection(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 5:
		var category: String = parts[3].to_lower()
		var count: int = int(parts[4])
		var pool: Array[String] = []
		for type_name: String in ConstDamageTypes.DAMAGE_TYPES:
			var type_row: Dictionary = ConstDamageTypes.DAMAGE_TYPES[type_name] as Dictionary
			if (type_row.get("category", "") as String).to_lower() != category:
				continue
			var protect_token: String = "protected:" + type_name.to_lower()
			if not merc.passive_effects.has(protect_token):
				pool.append(protect_token)
		if pool.is_empty():
			warn_token_once(t, "has no damage type left in that category")
		pool.shuffle()
		for i: int in range(mini(count, pool.size())):
			merc.passive_effects.append(pool[i])
	else:
		warn_token_once(t, "is an unparsed protection token")


static func _tok_remove_random_circumstance(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	var filter: String = ""
	var count: int = 0
	var excepted: Array[String] = []
	if parts.size() == 5:
		filter = parts[3].to_lower()
		count = int(parts[4])
	elif parts.size() == 7 and parts[4] == "except":
		filter = parts[3].to_lower()
		count = int(parts[6])
		for raw_key: String in parts[5].split(","):
			excepted.append_array(_resolve_circumstance_key(raw_key.strip_edges()))
	else:
		warn_token_once(t, "is an unparsed circumstance removal token")
	var held: Array[String] = []
	for d: String in ConstCircumstances.ALL:
		if not merc.circumstance_flags.get(d, false) or excepted.has(d):
			continue
		if _circumstance_matches_filter(d, filter):
			held.append(d)
	held.shuffle()
	for i: int in range(mini(count, held.size())):
		merc.circumstance_flags[held[i]] = false


static func _tok_stat(merc: MercenaryData, t: String) -> void:
	var parts: PackedStringArray = t.split(":")
	if parts.size() == 3 and (parts[2].begins_with("+") or parts[2].begins_with("-")):
		var key: String = parts[1]
		var val_str: String = parts[2]
		if val_str.ends_with("%"):
			StatCalculator.add_percent(merc, key, _signed_float(val_str.trim_suffix("%")) / 100.0)
		else:
			StatCalculator.add_flat(merc, key, _signed_float(val_str))
	else:
		warn_token_once(t, "is an unparsed stat token")


static func _tok_unhandled(t: String) -> void:
	var runtime_owned: bool = false
	for prefix: String in RUNTIME_PREFIXES:
		if t.begins_with(prefix):
			runtime_owned = true
			break
	if not runtime_owned:
		warn_token_once(t, "has no generation handler")


#aura:<state>:<paces>[:<gate>]; the gate names the senses that carry the state to an ally.
static func _apply_aura_token(merc: MercenaryData, token: String, source_name: String) -> void:
	var parts: PackedStringArray = token.split(":")
	if parts.size() < 3 or not parts[2].is_valid_int():
		warn_token_once(token, "is an unparsed aura token")
		return
	var state_name: String = ConstStates.state_from_token(parts[1])
	if state_name == "":
		warn_token_once(token, "names no States.tsv row")
		state_name = parts[1].strip_edges().capitalize()
	var gate: String = "sight_or_hearing"
	if parts.size() > 3 and parts[3].strip_edges() != "":
		gate = parts[3].strip_edges()
	var paces: int = int(parts[2])
	for held: Dictionary in merc.auras:
		if held.get("state", "") != state_name or held.get("gate", "") != gate:
			continue
		if int(held.get("paces", 0)) == paces:
			return
	merc.auras.append({"state": state_name, "paces": paces, "gate": gate, "source": source_name})


#The pool entries the merc can still gain: not blocked and not already held, in pool order.
static func available_circumstances(merc: MercenaryData, pool: Array) -> Array[String]:
	var available: Array[String] = []
	for d: String in pool:
		if not merc.blocked_circumstances.has(d) and not merc.circumstance_flags.get(d, false):
			available.append(d)
	return available


#A leading + adds the rest of the cell and any other first character subtracts it; int and float read 1e3 differently.
static func _signed_int(val_str: String) -> int:
	return int(val_str.substr(1)) * (1 if val_str.begins_with("+") else -1)


static func _signed_float(val_str: String) -> float:
	return float(val_str.substr(1)) * (1.0 if val_str.begins_with("+") else -1.0)


static func _resolve_circumstance_key(key: String) -> Array[String]:
	var parts: PackedStringArray = key.split("_")
	if parts.size() < 2:
		return []
	var stat_part: String = parts[-1].capitalize()
	var name_psa: PackedStringArray = parts.slice(0, parts.size() - 1)
	var circ_name: String = " ".join(name_psa).capitalize()
	if stat_part == "All":
		var result: Array[String] = []
		for display: String in ConstCircumstances.DATA:
			if (ConstCircumstances.DATA[display] as Dictionary).get("circumstance_name", "") == circ_name:
				result.append(display)
		return result
	var display: String = "%s (%s)" % [circ_name, stat_part]
	var single: Array[String] = []
	if ConstCircumstances.DATA.has(display):
		single.append(display)
	return single


#One warning per spelling per run, so a dead sheet cell stays visible without spamming the log.
static func warn_token_once(key: String, reason: String) -> void:
	if _warned_tokens.has(key):
		return
	_warned_tokens[key] = true
	push_warning("TraitDSL: '%s' %s" % [key, reason])


#Substitutes every [COLUMN] placeholder with a random value from that Types.tsv column.
static func _expand_trait_placeholders(name: String) -> String:
	var result: String = name
	while true:
		var span: Dictionary = _placeholder_span(result)
		if span.is_empty():
			break
		var values: Array = span["values"]
		if values.is_empty():
			return ""
		var pick: String = values[randi() % values.size()] as String
		result = result.substr(0, int(span["open"])) + pick + result.substr(int(span["close"]) + 1)
	return result


#Every [COLUMN] expansion of a name, in Types.tsv column order; no roll, unknown column gives none.
static func placeholder_variants(name: String) -> Array[String]:
	var results: Array[String] = [name]
	while true:
		var pending: Array[String] = []
		var expanded: bool = false
		for entry: String in results:
			var span: Dictionary = _placeholder_span(entry)
			if span.is_empty():
				pending.append(entry)
				continue
			var values: Array = span["values"]
			if values.is_empty():
				return []
			expanded = true
			for value: String in values:
				pending.append(entry.substr(0, int(span["open"])) + value + entry.substr(int(span["close"]) + 1))
		results = pending
		if not expanded:
			break
	return results


#The first [COLUMN] in text as {"open", "close", "values"}; {} when there is none.
#A column missing from Types.tsv warns once and comes back with no values.
static func _placeholder_span(text: String) -> Dictionary:
	var open_idx: int = text.find("[")
	var close_idx: int = text.find("]", open_idx) if open_idx >= 0 else -1
	if open_idx < 0 or close_idx < 0:
		return {}
	var header: String = text.substr(open_idx + 1, close_idx - open_idx - 1)
	var values: Array = DataManager.type_columns.get(header, []) as Array
	if values.is_empty():
		warn_token_once("[" + header + "]", "has no Types.tsv column")
	return {"open": open_idx, "close": close_idx, "values": values}


#Traits.tsv lookup that resolves [COLUMN] placeholders first and warns once on a missing row.
static func lookup_trait(raw_name: String) -> TraitData:
	var name: String = raw_name.strip_edges()
	if name == "":
		return null
	var warn_key: String = name
	if DataManager.traits.has(name):
		return DataManager.traits[name] as TraitData
	if name.contains("["):
		name = _expand_trait_placeholders(name)
		if name == "":
			return null
		if DataManager.traits.has(name):
			return DataManager.traits[name] as TraitData
	#Dedupes on the unexpanded name so a broken placeholder warns once, not once per random pick.
	warn_token_once(warn_key, "has no Traits.tsv row")
	return null


#Exact knowledge match first, then a case insensitive scan so grant:knowledge:tactics resolves.
static func _find_knowledge(k_name: String) -> UtilityTraitData:
	if DataManager.knowledges.has(k_name):
		return DataManager.knowledges[k_name] as UtilityTraitData
	var lower: String = k_name.to_lower()
	for key: String in DataManager.knowledges:
		if key.to_lower() == lower:
			return DataManager.knowledges[key] as UtilityTraitData
	return null


static func _holds_utility(held: Array[UtilityTraitData], utility: UtilityTraitData) -> bool:
	for h: UtilityTraitData in held:
		if h.utility_name == utility.utility_name:
			return true
	return false


#Filter is empty, all, a stat word such as wile, or a circumstance name such as resist.
static func _circumstance_matches_filter(display: String, filter: String) -> bool:
	if filter == "" or filter == "all" or filter == "any":
		return true
	var row: Dictionary = ConstCircumstances.DATA.get(display, {}) as Dictionary
	if (row.get("stat", "") as String).to_lower() == filter:
		return true
	return (row.get("circumstance_name", "") as String).to_lower().replace(" ", "_") == filter


static func assign_trait(merc: MercenaryData, trait_data: TraitData) -> void:
	var target: Array[TraitData] = merc.descriptors
	if trait_data.trait_type == "Perk":
		target = merc.perks
	elif trait_data.trait_type == "Drawback":
		target = merc.drawbacks
	for t: TraitData in target:
		if t.trait_name == trait_data.trait_name:
			return
	target.append(trait_data)
