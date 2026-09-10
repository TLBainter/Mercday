class_name MercGenerator

static var _rolling_penalties: Dictionary = {
	"location": {}, "ancestry": {}, "bloodline": {},
	"heritage": {}, "lifepath": {}, "tradition": {},
}

static var _rolling_penalty_age: Dictionary = {
	"location": {}, "ancestry": {}, "bloodline": {},
	"heritage": {}, "lifepath": {}, "tradition": {},
}

static var _rolling_stat_penalties: Dictionary = {
	"ancestry": {}, "bloodline": {}, "heritage": {},
}
static var _rolling_stat_penalty_age: Dictionary = {
	"ancestry": {}, "bloodline": {}, "heritage": {},
}
static var _tradition_batch_counts: Dictionary = {}

#When >= 0 generate() writes this level before the stat step; EnemyTeamBuilder resets it
static var forced_level: int = -1
#When it names a DataManager.traditions key _step5_tradition uses it instead of the roll
static var forced_tradition: String = ""

#Tokens already reported this run; keeps one dead token from warning once per merc
static var _warned_tokens: Dictionary = {}

#The only max_ keys StatCalculator reads; every other max_ key is unread
const CORE_MAX_KEYS: PackedStringArray = ["max_vigor", "max_dexterity", "max_cognition", "max_wile"]

#max_ spellings that name a Stats.tsv row instead of a core maximum
const MAX_STAT_ALIASES: Dictionary = {
	"max_hp": "maximum_hit_points",
	"max_ep": "maximum_endurance_points",
	"max_mp": "maximum_magic_points",
}

#Prefixes owned by combat, contract or perk code; generation skips them without a warning
const RUNTIME_PREFIXES: PackedStringArray = [
	"action:", "reactive_action:", "on_hit:", "on_pain:", "on_crit:", "on_kill:", "on_grapple:",
	"spend:", "while:", "to:", "chance:", "repeat:", "per:", "lasting:", "inflict:", "damage:",
	"resource:", "damage_dealt:", "damage_taken:", "reward:", "success_chance:", "remove_self",
	"weapon_enhance:", "weapon_stat:", "weapon_two_handed:", "weapon_passive:",
	"armor_weight_ignore:", "armor_ep_ignore:", "armor_fatigue_zero:",
]

const AGE_YOUNG := "Young"
const AGE_ADULT := "Adult"
const AGE_ELDER := "Elder"
const ELDER_XP_PERCENT := 115
const YOUNG_XP_PERCENT := 50
const AGE_PHYSICAL: Array[String] = ["vigor", "dexterity"]
const AGE_MENTAL: Array[String] = ["cognition", "wile"]
const AGE_PHYSICAL_MAX: Array[String] = ["max_vigor", "max_dexterity"]
const AGE_MENTAL_MAX: Array[String] = ["max_cognition", "max_wile"]
const AGELESS_MIN_AGE := 3
const AGELESS_MAX_AGE := 150


static func generate(_merc_index: int = 0) -> MercenaryData:
	var merc := MercenaryData.new()
	merc.merc_uid = CampaignKnowledge.next_uid()
	if _merc_index == 0:
		_tradition_batch_counts.clear()
	merc.stat_bonuses = {}
	merc.stat_flat_bonuses = {}
	merc.stat_multipliers = {}
	merc.max_stats = {}
	merc.odds_bonuses = {}
	merc.stats = {}
	merc.stats_baseline = {}
	merc.xp = 0
	if forced_level >= 0:
		merc.stats["level"] = float(forced_level)
		merc.xp = ExperienceSystem.xp_for_level(maxi(0, forced_level))
	merc.circumstance_flags = ConstCircumstances.make_flags()
	merc.circumstance_additional_bonus = ConstCircumstances.make_bonuses()
	merc.blocked_circumstances = []
	merc.passive_effects = []
	merc.min_stats = {}
	merc.cost_modifiers = {}
	merc.items = []

	_step1_origin(merc)
	_step2_ancestry(merc)
	_step3_heritage(merc)
	_step4_lifepath(merc)
	_prepare_max_stats(merc)
	_step6_traits(merc)
	_step7_stats(merc)
	_reapply_ability_grants(merc)
	_clamp_floor_stats(merc)
	_apply_random_stat_boosts(merc)
	_step5_tradition(merc)
	_step_age(merc)
	merc.merc_name = NameGenerator.generate(merc.starting_location)
	merc.current_hp = int(merc.stats.get("maximum_hit_points", 1))
	merc.current_ep = int(merc.stats.get("maximum_endurance_points", 1))
	merc.current_mp = int(merc.stats.get("maximum_magic_points", 1))
	merc.current_ap = int(merc.stats.get("action_points", 5))
	merc.current_rep = int(floor(float(merc.stats.get("luck", 0.0)) / 10.0))
	_step8_equip_weapon(merc)
	_step9_equip_armor(merc)
	merc.action_set = DefaultActionSet.create()
	_update_rolling_penalties(merc)
	return merc


static func _step1_origin(merc: MercenaryData) -> void:
	var settlements: Array = DataManager.get_settlement_locations()
	if settlements.is_empty():
		return
	var items: Array[Dictionary] = _locations_to_items(settlements)
	var loc_name: String = WeightedTable.roll(items, _get_penalty_boosts("location"))
	merc.starting_location = DataManager.locations.get(loc_name, null) as LocationData
	if merc.starting_location:
		_seed_odds_from_location(merc)


static func _locations_to_items(locs: Array) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for loc: LocationData in locs:
		items.append({"name": loc.location_name, "rarity": "Uncommon"})
	return items


static func _seed_odds_from_location(merc: MercenaryData) -> void:
	var loc: LocationData = merc.starting_location
	for key: String in loc.knowledge_buffs:
		merc.odds_bonuses[key] = loc.knowledge_buffs[key]
	for key: String in loc.tool_buffs:
		merc.odds_bonuses[key] = loc.tool_buffs[key]
	for key: String in loc.circumstance_buffs:
		merc.odds_bonuses[key] = loc.circumstance_buffs[key]


static func _step2_ancestry(merc: MercenaryData) -> void:
	var loc: LocationData = merc.starting_location
	var ancestry_items: Array[Dictionary] = _ancestries_to_items(DataManager.ancestries.values())
	var combined_flat: Dictionary = {}
	if loc:
		for n: String in loc.ancestry_buffs:
			combined_flat[n] = loc.ancestry_buffs[n] as float
		for n: String in loc.ancestry_debuffs:
			combined_flat[n] = -(loc.ancestry_debuffs[n] as float)

	for pen_name: String in _rolling_penalties["ancestry"]:
		combined_flat[pen_name] = (combined_flat.get(pen_name, 0.0) as float) - (_rolling_penalties["ancestry"][pen_name] as float)

	for item: Dictionary in ancestry_items:
		var candidate: AncestryData = DataManager.ancestries.get(item["name"], null) as AncestryData
		if candidate:
			var dom := _dominant_physical_stat(candidate)
			if dom != "" and (_rolling_stat_penalties["ancestry"].get(dom, 0.0) as float) > 0.0:
				combined_flat[item["name"]] = (combined_flat.get(item["name"], 0.0) as float) \
					- (_rolling_stat_penalties["ancestry"][dom] as float)

	var first_name: String = WeightedTable.roll(ancestry_items, combined_flat)
	var first_ancestry: AncestryData = DataManager.ancestries.get(first_name, null) as AncestryData
	if not first_ancestry:
		return

	var second_ancestry: AncestryData = null
	if randf() < 0.25:
		var candidate_items: Array[Dictionary] = []
		for item: Dictionary in ancestry_items:
			if item["name"] == first_name:
				continue
			var candidate: AncestryData = DataManager.ancestries.get(item["name"], null) as AncestryData
			if candidate and _can_hybridize(first_ancestry, candidate):
				candidate_items.append(item)
		if candidate_items.size() > 0:
			var second_name: String = WeightedTable.roll(candidate_items, combined_flat)
			second_ancestry = DataManager.ancestries.get(second_name, null) as AncestryData

	if second_ancestry:
		merc.is_hybrid = true
		if randf() < 0.5:
			merc.ancestry = first_ancestry
			merc.recessive_ancestry = second_ancestry
		else:
			merc.ancestry = second_ancestry
			merc.recessive_ancestry = first_ancestry
		merc.bloodline = _roll_bloodline(merc.ancestry, loc)
		merc.recessive_bloodline = _roll_bloodline(merc.recessive_ancestry, loc)
	else:
		merc.ancestry = first_ancestry
		merc.bloodline = _roll_bloodline(merc.ancestry, loc)

	if merc.bloodline and merc.bloodline.types.size() > 0:
		merc.creature_types = merc.bloodline.types.duplicate()
	else:
		merc.creature_types = merc.ancestry.types.duplicate()


static func _can_hybridize(a1: AncestryData, a2: AncestryData) -> bool:
	if a1.hybrid_options == "None" or a2.hybrid_options == "None":
		return false
	var a1_allows: bool = a1.hybrid_options == "All" or a1.hybrid_options.split(", ").has(a2.ancestry_name)
	var a2_allows: bool = a2.hybrid_options == "All" or a2.hybrid_options.split(", ").has(a1.ancestry_name)
	return a1_allows and a2_allows


static func _roll_bloodline(ancestry: AncestryData, loc: LocationData) -> AncestryData:
	var possible: Array[String] = ancestry.possible_bloodlines
	var bl_items: Array[Dictionary] = []
	for bl_name: String in possible:
		if DataManager.bloodlines.has(bl_name):
			var bl: AncestryData = DataManager.bloodlines[bl_name] as AncestryData
			bl_items.append({"name": bl_name, "rarity": bl.rarity})

	var bl_flat: Dictionary = {}
	if loc:
		for n: String in loc.bloodline_buffs:
			bl_flat[n] = loc.bloodline_buffs[n] as float
	for pen_name: String in _rolling_penalties["bloodline"]:
		bl_flat[pen_name] = (bl_flat.get(pen_name, 0.0) as float) - (_rolling_penalties["bloodline"][pen_name] as float)

	for bl_item: Dictionary in bl_items:
		var candidate: AncestryData = DataManager.bloodlines.get(bl_item["name"], null) as AncestryData
		if candidate:
			var dom := _dominant_physical_stat(candidate)
			if dom != "" and (_rolling_stat_penalties["bloodline"].get(dom, 0.0) as float) > 0.0:
				bl_flat[bl_item["name"]] = (bl_flat.get(bl_item["name"], 0.0) as float) \
					- (_rolling_stat_penalties["bloodline"][dom] as float)

	var bl_name: String = WeightedTable.roll(bl_items, bl_flat, {}, {"Core": 50.0})
	if bl_name.is_empty():
		bl_name = "Core"
	return null if bl_name == "Core" else DataManager.bloodlines.get(bl_name, null) as AncestryData


static func _ancestries_to_items(ancestry_list: Array) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for a: AncestryData in ancestry_list:
		items.append({"name": a.ancestry_name, "rarity": a.rarity})
	return items


static func _step3_heritage(merc: MercenaryData) -> void:
	var loc: LocationData = merc.starting_location
	var heritage_items: Array[Dictionary] = _heritages_to_items(DataManager.heritages.values())
	var flat_boosts: Dictionary = {}
	if loc:
		flat_boosts = loc.heritage_buffs.duplicate()
	for pen_name: String in _rolling_penalties["heritage"]:
		flat_boosts[pen_name] = (flat_boosts.get(pen_name, 0.0) as float) - (_rolling_penalties["heritage"][pen_name] as float)

	for item: Dictionary in heritage_items:
		var candidate: HeritageData = DataManager.heritages.get(item["name"], null) as HeritageData
		if candidate:
			var dom := _dominant_mental_stat(candidate)
			if dom != "" and (_rolling_stat_penalties["heritage"].get(dom, 0.0) as float) > 0.0:
				flat_boosts[item["name"]] = (flat_boosts.get(item["name"], 0.0) as float) \
					- (_rolling_stat_penalties["heritage"][dom] as float)

	var mult_boosts: Dictionary = {}
	if merc.is_hybrid:
		var dom_boosts: Dictionary = {}
		_apply_x20_boosts(merc.ancestry, dom_boosts)
		if merc.bloodline:
			_apply_x20_boosts(merc.bloodline, dom_boosts)
		var rec_boosts: Dictionary = {}
		_apply_x20_boosts(merc.recessive_ancestry, rec_boosts)
		if merc.recessive_bloodline:
			_apply_x20_boosts(merc.recessive_bloodline, rec_boosts)
		for key: String in dom_boosts:
			mult_boosts[key] = dom_boosts[key]
		for key: String in rec_boosts:
			mult_boosts[key] = maxf(mult_boosts.get(key, 0.0) as float, rec_boosts[key] as float)
	else:
		_apply_x20_boosts(merc.ancestry, mult_boosts)
		if merc.bloodline:
			_apply_x20_boosts(merc.bloodline, mult_boosts)

	var heritage_name: String = WeightedTable.roll(heritage_items, flat_boosts)
	merc.heritage = DataManager.heritages.get(heritage_name, null) as HeritageData
	if not merc.heritage:
		return

	var circ_pool: Array[Dictionary] = _build_circumstance_pool(merc.heritage)
	if circ_pool.size() > 0:
		var circ_name: String = WeightedTable.roll(circ_pool, {}, mult_boosts)
		if ConstCircumstances.DATA.has(circ_name):
			merc.circumstance_flags[circ_name] = true

	var kt_pool: Array[Dictionary] = _build_kt_pool(merc.heritage)
	if kt_pool.size() > 0:
		var kt_name: String = WeightedTable.roll(kt_pool, {}, mult_boosts)
		if DataManager.knowledges.has(kt_name):
			merc.knowledges.append(DataManager.knowledges[kt_name] as UtilityTraitData)
		elif DataManager.tools.has(kt_name):
			merc.tools.append(DataManager.tools[kt_name] as UtilityTraitData)


static func _heritages_to_items(heritage_list: Array) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for h: HeritageData in heritage_list:
		items.append({"name": h.heritage_name, "rarity": "Common"})
	return items


static func _dominant_physical_stat(data: AncestryData) -> String:
	if data.max_vigor > data.max_dexterity:
		return "vigor"
	if data.max_dexterity > data.max_vigor:
		return "dexterity"
	if data.max_vigor > 0:
		return "balanced_physical"
	return ""


static func _dominant_mental_stat(data: HeritageData) -> String:
	if data.max_cognition > data.max_wile:
		return "cognition"
	if data.max_wile > data.max_cognition:
		return "wile"
	if data.max_cognition > 0:
		return "balanced_mental"
	return ""


static func _apply_x20_boosts(a: AncestryData, mult_boosts: Dictionary) -> void:
	if not a:
		return
	for item_name: String in a.knowledge_odds_x20:
		mult_boosts[item_name] = (mult_boosts.get(item_name, 0.0) as float) + 20.0
	for item_name: String in a.tool_odds_x20:
		mult_boosts[item_name] = (mult_boosts.get(item_name, 0.0) as float) + 20.0
	for item_name: String in a.circumstance_odds_x20:
		mult_boosts[item_name] = (mult_boosts.get(item_name, 0.0) as float) + 20.0


static func _build_circumstance_pool(heritage: HeritageData) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if heritage.circumstances.has("Any"):
		for display_name: String in ConstCircumstances.DATA:
			items.append({"name": display_name, "rarity": ConstCircumstances.DATA[display_name]["rarity"]})
	else:
		for circ_name: String in heritage.circumstances:
			if ConstCircumstances.DATA.has(circ_name):
				items.append({"name": circ_name, "rarity": ConstCircumstances.DATA[circ_name]["rarity"]})
	return items


static func _build_kt_pool(heritage: HeritageData) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var k_names: Array[String] = DataManager.expand_heritage_knowledges(heritage)
	var t_names: Array[String] = DataManager.expand_heritage_tools(heritage)
	for n: String in k_names:
		if DataManager.knowledges.has(n):
			var k: UtilityTraitData = DataManager.knowledges[n] as UtilityTraitData
			items.append({"name": n, "rarity": k.utility_rarity})
	for n: String in t_names:
		if DataManager.tools.has(n):
			var t: UtilityTraitData = DataManager.tools[n] as UtilityTraitData
			items.append({"name": n, "rarity": t.utility_rarity})
	return items


static func _step4_lifepath(merc: MercenaryData) -> void:
	var items: Array[Dictionary] = []
	var pool: Array = DataManager.starting_lifepaths.values()
	for lp: LifepathData in LifepathRequirements.filter(merc, pool):
		items.append({"name": lp.event_name, "rarity": lp.rarity})
	if items.is_empty():
		return
	var lp_name: String = WeightedTable.roll(items, _get_penalty_boosts("lifepath"))
	var lp: LifepathData = DataManager.starting_lifepaths.get(lp_name, null) as LifepathData
	if lp:
		merc.lifepaths.append(lp)




static func _step5_tradition(merc: MercenaryData) -> void:
	var items: Array[Dictionary] = []
	for trad: TraditionData in DataManager.traditions.values():
		items.append({"name": trad.tradition_name, "rarity": "Common"})
	if items.is_empty():
		return
	var trad_boosts: Dictionary = _build_tradition_boosts(merc)
	for pen_name: String in _rolling_penalties["tradition"]:
		trad_boosts[pen_name] = (trad_boosts.get(pen_name, 0.0) as float) - (_rolling_penalties["tradition"][pen_name] as float)
	var trad_name: String = forced_tradition if (forced_tradition != "" and DataManager.traditions.has(forced_tradition)) else _resolve_tradition_with_rerolls(items, trad_boosts)
	merc.tradition = DataManager.traditions.get(trad_name, null) as TraditionData
	if not merc.tradition:
		return
	_tradition_batch_counts[trad_name] = _tradition_batch_counts.get(trad_name, 0) + 1

	_apply_tradition_boosts(merc)

	var boost_name: String = merc.tradition.circumstance_boost
	if boost_name != "":
		var already_had: bool = merc.circumstance_flags.get(boost_name, false)

		merc.circumstance_additional_bonus[boost_name] = 25.0

		if not already_had:
			if ConstCircumstances.DATA.has(boost_name):
				merc.circumstance_flags[boost_name] = true
		else:
			var extra_pool: Array[Dictionary] = []
			for display_name: String in ConstCircumstances.DATA:
				extra_pool.append({"name": display_name, "rarity": ConstCircumstances.DATA[display_name]["rarity"]})
			if extra_pool.size() > 0:
				var extra_name: String = WeightedTable.roll(extra_pool)
				if ConstCircumstances.DATA.has(extra_name):
					merc.circumstance_flags[extra_name] = true

	#Runs last so the circumstance flags and bonus set above reach the derived stats.
	_recalculate_stats(merc)


static func _step6_traits(merc: MercenaryData) -> void:
	var perk_names: Array[String] = []
	var drawback_names: Array[String] = []

	if merc.bloodline:
		perk_names.append_array(merc.bloodline.perks)
		drawback_names.append_array(merc.bloodline.drawbacks)
	elif merc.ancestry:
		perk_names.append_array(merc.ancestry.perks)
		drawback_names.append_array(merc.ancestry.drawbacks)
	if merc.recessive_bloodline:
		perk_names.append_array(merc.recessive_bloodline.perks)
		drawback_names.append_array(merc.recessive_bloodline.drawbacks)
	elif merc.recessive_ancestry:
		perk_names.append_array(merc.recessive_ancestry.perks)
		drawback_names.append_array(merc.recessive_ancestry.drawbacks)
	for lp: LifepathData in merc.lifepaths:
		perk_names.append_array(lp.perks)
		drawback_names.append_array(lp.drawbacks)

	for trait_name: String in perk_names:
		var trait_data: TraitData = _lookup_trait(trait_name)
		if trait_data:
			_assign_trait(merc, trait_data)
	for trait_name: String in drawback_names:
		var trait_data: TraitData = _lookup_trait(trait_name)
		if trait_data:
			_assign_trait(merc, trait_data)

	var perk_count_before: int = merc.perks.size()
	var drawback_count_before: int = merc.drawbacks.size()

	var all_traits: Array[TraitData] = []
	all_traits.append_array(merc.perks)
	all_traits.append_array(merc.drawbacks)
	for trait_data: TraitData in all_traits:
		_apply_dsl_to_merc(merc, trait_data.effect_dsl)

	for i: int in range(perk_count_before, merc.perks.size()):
		if merc.group_perk_cells_applied.has(merc.perks[i].trait_name):
			continue
		_apply_dsl_to_merc(merc, merc.perks[i].effect_dsl)
	for i: int in range(drawback_count_before, merc.drawbacks.size()):
		if merc.group_perk_cells_applied.has(merc.drawbacks[i].trait_name):
			continue
		_apply_dsl_to_merc(merc, merc.drawbacks[i].effect_dsl)


static func _assign_trait(merc: MercenaryData, trait_data: TraitData) -> void:
	match trait_data.trait_type:
		"Perk":
			for t: TraitData in merc.perks:
				if t.trait_name == trait_data.trait_name:
					return
			merc.perks.append(trait_data)
		"Drawback":
			for t: TraitData in merc.drawbacks:
				if t.trait_name == trait_data.trait_name:
					return
			merc.drawbacks.append(trait_data)
		_:
			for t: TraitData in merc.descriptors:
				if t.trait_name == trait_data.trait_name:
					return
			merc.descriptors.append(trait_data)


static func _apply_dsl_to_merc(merc: MercenaryData, dsl: String) -> void:
	if dsl == "" or dsl.begins_with("SPECIAL:"):
		return
	for token: String in dsl.split("|"):
		var t: String = token.strip_edges()
		if t.begins_with("SPECIAL:"):
			continue
		if t.begins_with("stat:max_"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 3:
				var stat_key: String = parts[1]
				var val_str: String = parts[2]
				var op: int = 1 if val_str.begins_with("+") else -1
				var amount: int = int(val_str.substr(1)) * op
				if MAX_STAT_ALIASES.has(stat_key):
					_add_stat_flat(merc, MAX_STAT_ALIASES[stat_key] as String, float(amount))
				else:
					if not CORE_MAX_KEYS.has(stat_key):
						_warn_token_once(t, "writes a max_stats key that nothing reads")
					merc.max_stats[stat_key] = (merc.max_stats.get(stat_key, 0) as int) + amount
		elif t.begins_with("stat:min_"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 3:
				var floor_key: String = parts[1].substr("min_".length())  # "min_state_madness" -> "state_madness"
				var val: int = int(parts[2])
				merc.min_stats[floor_key] = maxi(merc.min_stats.get(floor_key, 0) as int, val)
		elif t.begins_with("grant:ability:"):
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
		elif t.begins_with("on:"):
			pass # TODO: triggered effects are handled by the contract system, not at generation
		elif t.begins_with("block:random:circumstance:unselected:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 5:
				var count: int = int(parts[4])
				var candidates: Array[String] = []
				for d: String in ConstCircumstances.ALL:
					if not merc.blocked_circumstances.has(d) and not merc.circumstance_flags.get(d, false):
						candidates.append(d)
				candidates.shuffle()
				for i: int in range(mini(count, candidates.size())):
					merc.blocked_circumstances.append(candidates[i])
		elif t.begins_with("block:circumstance:") or t.begins_with("block_and_replace:circumstance:"):
			var do_replace: bool = t.begins_with("block_and_replace:")
			var prefix: String = "block_and_replace:circumstance:" if do_replace else "block:circumstance:"
			var targets: Array[String] = _resolve_circumstance_key(t.substr(prefix.length()))
			for display: String in targets:
				if not merc.blocked_circumstances.has(display):
					merc.blocked_circumstances.append(display)
				if merc.circumstance_flags.get(display, false):
					merc.circumstance_flags[display] = false
					if do_replace:
						var available: Array[String] = []
						for d: String in ConstCircumstances.ALL:
							if not merc.blocked_circumstances.has(d) and not merc.circumstance_flags.get(d, false):
								available.append(d)
						if not available.is_empty():
							available.shuffle()
							merc.circumstance_flags[available[0]] = true
		elif t.begins_with("grant:random:bloodline_traits:"):
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
						for trait_name: String in bl.perks:
							var td: TraitData = _lookup_trait(trait_name)
							if td:
								_assign_trait(merc, td)
						for trait_name: String in bl.drawbacks:
							var td: TraitData = _lookup_trait(trait_name)
							if td:
								_assign_trait(merc, td)
		elif t.begins_with("grant:knowledge:"):
			var k_name: String = t.substr("grant:knowledge:".length()).strip_edges()
			var k_data: UtilityTraitData = _find_knowledge(k_name)
			if k_data == null:
				_warn_token_once(t, "has no Knowledges and Tools row")
			else:
				var already: bool = false
				for k: UtilityTraitData in merc.knowledges:
					if k.utility_name == k_data.utility_name:
						already = true
						break
				if not already:
					merc.knowledges.append(k_data)
		elif t.begins_with("grant:circumstance:"):
			var circ_key: String = t.substr("grant:circumstance:".length()).strip_edges()
			for display: String in _resolve_circumstance_key(circ_key):
				if not merc.blocked_circumstances.has(display):
					merc.circumstance_flags[display] = true
		elif t.begins_with("grant:trait:"):
			var trait_name: String = t.substr("grant:trait:".length()).strip_edges()
			var td: TraitData = _lookup_trait(trait_name)
			if td:
				_assign_trait(merc, td)
		elif t.begins_with("grant:passive:"):
			merc.passive_effects.append(t)
			# TODO: passive effects are evaluated at runtime by the game/combat system, not at generation
		elif t.begins_with("grant:random:circumstance:"):
			var parts: PackedStringArray = t.split(":")
			var pool: Array[String] = []
			var count: int = 1
			if parts.size() == 4 and parts[3].is_valid_int():
				# grant:random:circumstance:<n>  (legacy, no filter)
				count = int(parts[3])
				pool = ConstCircumstances.ALL.duplicate()
			elif parts.size() == 6 and parts[3] == "from":
				# grant:random:circumstance:from:<key1,key2,...>:<n>
				count = int(parts[5])
				for raw_key: String in parts[4].split(","):
					pool.append_array(_resolve_circumstance_key(raw_key.strip_edges()))
			elif parts.size() == 5:
				# grant:random:circumstance:<stat_or_name_filter>:<n>
				count = int(parts[4])
				var filter: String = parts[3].to_lower()
				var core_stats: Array[String] = ["vigor", "dexterity", "cognition", "wile"]
				for d: String in ConstCircumstances.ALL:
					var circ_data: Dictionary = ConstCircumstances.DATA[d] as Dictionary
					if core_stats.has(filter):
						if (circ_data.get("stat", "") as String).to_lower() == filter:
							pool.append(d)
					else:
						if (circ_data.get("circumstance_name", "") as String).to_lower() == filter:
							pool.append(d)
			var available: Array[String] = []
			for d: String in pool:
				if not merc.blocked_circumstances.has(d) and not merc.circumstance_flags.get(d, false):
					available.append(d)
			available.shuffle()
			for i: int in range(mini(count, available.size())):
				merc.circumstance_flags[available[i]] = true
		elif t.begins_with("grant:random:lifepath:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() < 5:
				continue
			var category: String = parts[3].capitalize()
			var count: int = 1
			var category_lifepaths: Array = DataManager.lifepaths_by_category.get(category, []) as Array
			var candidates: Array[LifepathData] = []
			if parts.size() == 5:
				# grant:random:lifepath:<cat>:<n>
				count = int(parts[4])
				candidates.assign(category_lifepaths)
			elif parts.size() == 7 and parts[4] == "begins_with":
				# grant:random:lifepath:<cat>:begins_with:<prefix>:<n>
				var prefix: String = parts[5].replace("_", " ").to_lower()
				count = int(parts[6])
				for lp_data: LifepathData in category_lifepaths:
					if lp_data.event_name.to_lower().begins_with(prefix):
						candidates.append(lp_data)
			elif parts.size() == 7 and parts[4] == "from":
				# grant:random:lifepath:<cat>:from:<name1,name2,...>:<n>
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
				for trait_name: String in granted_lp.perks:
					var td: TraitData = _lookup_trait(trait_name)
					if td:
						_assign_trait(merc, td)
				for trait_name: String in granted_lp.drawbacks:
					var td: TraitData = _lookup_trait(trait_name)
					if td:
						_assign_trait(merc, td)
		elif t.begins_with("grant:random:knowledge:"):
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
				var already: bool = false
				for held: UtilityTraitData in merc.knowledges:
					if held.utility_name == k.utility_name:
						already = true
						break
				if not already:
					available_k.append(k)
			available_k.shuffle()
			for i: int in range(mini(count, available_k.size())):
				merc.knowledges.append(available_k[i])
		elif t.begins_with("grant:random:tool:"):
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
				var already: bool = false
				for held: UtilityTraitData in merc.tools:
					if held.utility_name == tool_data.utility_name:
						already = true
						break
				if not already:
					available_t.append(tool_data)
			available_t.shuffle()
			for i: int in range(mini(count, available_t.size())):
				merc.tools.append(available_t[i])
		elif t.begins_with("grant:random:environ_stat:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 5:
				var count: int = int(parts[3])
				var val_str: String = parts[4]
				var op: float = 1.0 if val_str.begins_with("+") else -1.0
				var amount: float = float(val_str.substr(1)) * op
				var env_pool: Array = DataManager.environment_types.duplicate()
				env_pool.shuffle()
				for i: int in range(mini(count, env_pool.size())):
					var env_key: String = (env_pool[i] as String).to_lower().replace(" ", "_")
					_add_stat_flat(merc, env_key, amount)
		elif t.begins_with("grant:random:creature_stat:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 5:
				var count: int = int(parts[3])
				var val_str: String = parts[4]
				var op: float = 1.0 if val_str.begins_with("+") else -1.0
				var amount: float = float(val_str.substr(1)) * op
				var cr_pool: Array = DataManager.creature_types.duplicate()
				cr_pool.shuffle()
				for i: int in range(mini(count, cr_pool.size())):
					var cr_key: String = (cr_pool[i] as String).to_lower().replace(" ", "_")
					_add_stat_flat(merc, cr_key, amount)
		elif t.begins_with("stat:circumstance_boost:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 4:
				var targets: Array[String] = _resolve_circumstance_key(parts[2])
				var val_str: String = parts[3]
				var op: float = 1.0 if val_str.begins_with("+") else -1.0
				var amount: float = float(val_str.substr(1)) * op
				for display: String in targets:
					merc.circumstance_additional_bonus[display] = \
							(merc.circumstance_additional_bonus.get(display, 0.0) as float) + amount
		elif t.begins_with("stat:random:core_stat_max:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 4:
				var val_str: String = parts[3]
				var op: int = 1 if val_str.begins_with("+") else -1
				var amount: int = int(val_str.substr(1)) * op
				var core_keys: Array[String] = ["max_vigor", "max_dexterity", "max_cognition", "max_wile"]
				var chosen: String = core_keys[randi() % core_keys.size()]
				merc.max_stats[chosen] = (merc.max_stats.get(chosen, 0) as int) + amount
		elif t.begins_with("stat:random:"):
			# stat:random:<key1>:<key2>:...:<val>; pick one random key from the list
			var parts: PackedStringArray = t.split(":")
			if parts.size() >= 4:
				var val_str: String = parts[parts.size() - 1]
				var op: int = 1 if val_str.begins_with("+") else -1
				var amount: int = int(val_str.substr(1)) * op
				var keys: Array[String] = []
				for i: int in range(2, parts.size() - 1):
					keys.append(parts[i])
				if not keys.is_empty():
					var chosen: String = keys[randi() % keys.size()]
					if chosen.begins_with("max_"):
						merc.max_stats[chosen] = (merc.max_stats.get(chosen, 0) as int) + amount
					else:
						_add_stat_flat(merc, chosen, float(amount))
		elif t.begins_with("grant:random:item:rarity:"):
			# grant:random:item:rarity:<rarity1,rarity2,...>:<n>
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
					merc.items.append(candidates[i])
				# TODO: convert to typed ItemData once Godot imports ItemData.gd
		elif t.begins_with("immune:") or t.begins_with("protected:") or t.begins_with("susceptible:"):
			if ConstStates.immune_token_allowed(t, "Traits.tsv") and not merc.passive_effects.has(t):
				merc.passive_effects.append(t)
		elif t.begins_with("cost:"):
			# cost:<category>:<percent>  (negative = discount)
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 3:
				var category: String = parts[1]
				var amount: float = float(parts[2].trim_suffix("%"))
				merc.cost_modifiers[category] = (merc.cost_modifiers.get(category, 0.0) as float) + amount
				_add_stat_flat(merc, category + "_cost_modifier", amount)
		elif t.begins_with("grant:random:perk_group:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() != 5:
				_warn_token_once(t, "is an unparsed perk group token")
			else:
				var count: int = int(parts[4])
				if count > 0:
					_grant_random_group_perks(merc, parts[3], count, t)
				else:
					_warn_token_once(t, "has no positive perk group count")
		elif t.begins_with("grant:random:") and t.contains("weapon_perk:"):
			var parts: PackedStringArray = t.split(":")
			var filter: String = ""
			if parts[2] == "basic_weapon_perk":
				filter = "basic"
			elif parts[2] == "specialized_weapon_perk":
				filter = "specialized"
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
				_warn_token_once(t, "is an unparsed weapon perk token")
			if count > 0:
				_grant_random_perks(merc.weapon_perks, _weapon_perk_pool(filter), count, t)
		elif t.begins_with("grant:random:armor_perk:"):
			var parts: PackedStringArray = t.split(":")
			var filter: String = ""
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
				_warn_token_once(t, "is an unparsed armor perk token")
			if count > 0:
				_grant_random_perks(merc.armor_perks, _armor_perk_pool(filter), count, t)
		elif t.begins_with("grant:random:protection:"):
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
					_warn_token_once(t, "has no damage type left in that category")
				pool.shuffle()
				for i: int in range(mini(count, pool.size())):
					merc.passive_effects.append(pool[i])
			else:
				_warn_token_once(t, "is an unparsed protection token")
		elif t.begins_with("remove:random:circumstance:"):
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
				_warn_token_once(t, "is an unparsed circumstance removal token")
			var held: Array[String] = []
			for d: String in ConstCircumstances.ALL:
				if not merc.circumstance_flags.get(d, false) or excepted.has(d):
					continue
				if _circumstance_matches_filter(d, filter):
					held.append(d)
			held.shuffle()
			for i: int in range(mini(count, held.size())):
				merc.circumstance_flags[held[i]] = false
		elif t.begins_with("stat:"):
			var parts: PackedStringArray = t.split(":")
			if parts.size() == 3 and (parts[2].begins_with("+") or parts[2].begins_with("-")):
				var key: String = parts[1]
				var val_str: String = parts[2]
				var op: float = 1.0 if val_str.begins_with("+") else -1.0
				if val_str.ends_with("%"):
					_add_stat_multiplier(merc, key, float(val_str.trim_suffix("%").substr(1)) * op / 100.0)
				else:
					_add_stat_flat(merc, key, float(val_str.substr(1)) * op)
			else:
				_warn_token_once(t, "is an unparsed stat token")
		elif t.begins_with("remove:ability:"):
			continue
		else:
			var runtime_owned: bool = false
			for prefix: String in RUNTIME_PREFIXES:
				if t.begins_with(prefix):
					runtime_owned = true
					break
			if not runtime_owned:
				_warn_token_once(t, "has no generation handler")


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


static func _clamp_floor_stats(merc: MercenaryData) -> void:
	for stat_def: Dictionary in DataManager.stat_definitions:
		if stat_def["round"] != "floor" or stat_def["type"] == "boolean":
			continue
		var var_name: String = stat_def["var_name"]
		if merc.stats.has(var_name):
			merc.stats[var_name] = maxi(0, int(merc.stats[var_name]))


static func _apply_random_stat_boosts(merc: MercenaryData) -> void:
	var core_stats: Array[String] = ["cognition", "dexterity", "vigor", "wile"]
	core_stats.shuffle()
	for i: int in range(2):
		var stat_key: String = core_stats[i]
		merc.stat_bonuses[stat_key] = (merc.stat_bonuses.get(stat_key, 0.0) as float) + 1.0
	_recalculate_stats(merc)


#Band edges for one life expectancy; young runs from 0, elder ends on the expectancy itself.
static func age_bands(le: int) -> Dictionary:
	var adult_lo: int = floori(float(le) / 3.0)
	var adult_hi: int = floori(float(le) * 4.0 / 5.0)
	return {
		"young_lo": 0, "young_hi": adult_lo - 1,
		"adult_lo": adult_lo, "adult_hi": adult_hi,
		"elder_lo": adult_hi + 1, "elder_hi": le,
	}


#Category one age falls in under one life expectancy; a missing expectancy reads as Adult.
static func age_category_for(age: int, le: int) -> String:
	if le <= 0:
		return AGE_ADULT
	var bands: Dictionary = age_bands(le)
	if age < int(bands["adult_lo"]):
		return AGE_YOUNG
	if age <= int(bands["adult_hi"]):
		return AGE_ADULT
	return AGE_ELDER


#Inclusive [lo, hi] of one third of a band; third is 0 Low, 1 Mid, 2 High.
static func age_third(lo: int, hi: int, third: int) -> Array[int]:
	var span: int = hi - lo + 1
	if span <= 0:
		return [lo, lo]
	var a: int = lo + (span * third) / 3
	var b: int = lo + (span * (third + 1)) / 3 - 1
	return [a, maxi(a, b)]


#Rolls the designer's band table and returns a uniform age inside the third it picked.
static func roll_age(le: int) -> int:
	var bands: Dictionary = age_bands(le)
	var r: float = randf() * 100.0
	var pick: Array[int] = []
	if r < 10.0:
		pick = age_third(int(bands["young_lo"]), int(bands["young_hi"]), 1)
	elif r < 15.0:
		pick = age_third(int(bands["elder_lo"]), int(bands["elder_hi"]), 0)
	elif r < 25.0:
		pick = age_third(int(bands["elder_lo"]), int(bands["elder_hi"]), 1)
	elif r < 37.0:
		pick = age_third(int(bands["adult_lo"]), int(bands["adult_hi"]), 0)
	elif r < 52.0:
		pick = age_third(int(bands["adult_lo"]), int(bands["adult_hi"]), 2)
	else:
		pick = age_third(int(bands["adult_lo"]), int(bands["adult_hi"]), 1)
	return clampi(randi_range(pick[0], pick[1]), 0, le)


#The higher life expectancy of a hybrid's two ancestries; -1 when neither ancestry has one.
static func life_expectancy_for(merc: MercenaryData) -> int:
	var primary: int = merc.ancestry.life_expectancy if merc.ancestry != null else -1
	var secondary: int = -1
	if merc.is_hybrid and merc.recessive_ancestry != null:
		secondary = merc.recessive_ancestry.life_expectancy
	return maxi(primary, secondary)


static func _step_age(merc: MercenaryData) -> void:
	var le: int = life_expectancy_for(merc)
	if le <= 0:
		merc.age = randi_range(AGELESS_MIN_AGE, AGELESS_MAX_AGE)
		merc.age_category = AGE_ADULT
		return
	merc.age = roll_age(le)
	merc.age_category = age_category_for(merc.age, le)
	apply_age_effects(merc, merc.age_category)


#Generation only stat, maximum, xp and lifepath changes for one category; a forced level keeps its xp.
static func apply_age_effects(merc: MercenaryData, category: String) -> void:
	if merc == null:
		return
	match category:
		AGE_ELDER:
			_shift_core_stat(merc, AGE_PHYSICAL, -1, 1)
			_shift_core_stat(merc, AGE_MENTAL, 1, 0)
			_shift_max_stats(merc, AGE_PHYSICAL_MAX, -1)
			_shift_max_stats(merc, AGE_MENTAL_MAX, 1)
			if forced_level < 0:
				merc.xp = floori(float(merc.xp * ELDER_XP_PERCENT) / 100.0)
				ExperienceSystem.set_level_from_xp(merc)
			_grant_age_lifepath(merc)
		AGE_YOUNG:
			_shift_core_stat(merc, AGE_PHYSICAL, 1, 0)
			_shift_core_stat(merc, AGE_MENTAL, -1, 0)
			_shift_max_stats(merc, AGE_PHYSICAL_MAX, 1)
			if forced_level < 0:
				merc.xp = floori(float(merc.xp * YOUNG_XP_PERCENT) / 100.0)
				ExperienceSystem.set_level_from_xp(merc)


#Moves one named core stat by delta; a stat that would break the floor or its maximum is skipped.
static func _shift_core_stat(merc: MercenaryData, keys: Array[String], delta: int, floor_value: int) -> String:
	var order: Array[String] = keys.duplicate()
	order.shuffle()
	for key: String in order:
		var cur: int = int(merc.stats.get(key, 0))
		var cap: int = int(merc.max_stats.get("max_" + key, 0))
		if delta < 0 and cur + delta < floor_value:
			continue
		if delta > 0 and cur + delta > cap:
			continue
		merc.stat_bonuses[key] = float(merc.stat_bonuses.get(key, 0.0)) + float(delta)
		_recalculate_stats(merc)
		return key
	return ""


static func _shift_max_stats(merc: MercenaryData, keys: Array[String], delta: int) -> void:
	for key: String in keys:
		merc.max_stats[key] = maxi(1, int(merc.max_stats.get(key, 0)) + delta)
	_recalculate_stats(merc)


#Every Experienced row with a real trait payoff that the merc does not hold yet; no requirement gate.
static func elder_event_pool(merc: MercenaryData) -> Array[String]:
	var names: Array[String] = []
	for lp: LifepathData in DataManager.lifepaths_by_category.get("Experienced", []) as Array:
		if lp == null or LifepathProgression.has_event(merc, lp.event_name):
			continue
		if LifepathProgression.CODED_EVENTS.has(lp.event_name):
			continue
		if LifepathProgression.has_payoff(lp):
			names.append(lp.event_name)
	return names


#One extra Elder event: paying Experienced rows except Buddy and In Love, by rarity, no requirement gate; else Starting.
static func _grant_age_lifepath(merc: MercenaryData) -> String:
	var names: Array[String] = elder_event_pool(merc)
	var pick: String = LifepathProgression.draw(names) if not names.is_empty() else ""
	if pick == "":
		var items: Array[Dictionary] = []
		for lp: LifepathData in LifepathRequirements.filter(merc, DataManager.starting_lifepaths.values()):
			if not LifepathProgression.has_event(merc, lp.event_name):
				items.append({"name": lp.event_name, "rarity": lp.rarity})
		if not items.is_empty():
			pick = WeightedTable.roll(items)
	if pick == "":
		return ""
	var lines: Array[String] = LifepathProgression.grant(merc, pick)
	return pick if not lines.is_empty() else ""


static func _reapply_ability_grants(merc: MercenaryData) -> void:
	StatCalculator.apply_ability_grants(merc)


static func _prepare_max_stats(merc: MercenaryData) -> void:
	if merc.heritage:
		merc.max_stats["max_cognition"] = (merc.max_stats.get("max_cognition", 0) as int) + merc.heritage.max_cognition
		merc.max_stats["max_wile"] = (merc.max_stats.get("max_wile", 0) as int) + merc.heritage.max_wile

	var base: AncestryData = merc.ancestry
	var bl: AncestryData = merc.bloodline
	if not merc.max_stats.has("max_dexterity"):
		var v: int = bl.max_dexterity if bl and bl.max_dexterity > 0 else (base.max_dexterity if base else 0)
		merc.max_stats["max_dexterity"] = v
	if not merc.max_stats.has("max_vigor"):
		var v: int = bl.max_vigor if bl and bl.max_vigor > 0 else (base.max_vigor if base else 0)
		merc.max_stats["max_vigor"] = v
	if not merc.max_stats.has("size"):
		var v: int = bl.size if bl and bl.size > 0 else (base.size if base else 0)
		merc.max_stats["size"] = v


static func _build_tradition_boosts(merc: MercenaryData) -> Dictionary:
	const STAT_KEYS: Dictionary = {
		"Wile": "max_wile", "Cognition": "max_cognition",
		"Dexterity": "max_dexterity", "Vigor": "max_vigor",
	}
	var boosts: Dictionary = {}
	for trad: TraditionData in DataManager.traditions.values():
		var net: float = 0.0
		net += _tradition_stat_weight(merc, trad.weight_plus_25, 25.0, STAT_KEYS)
		net += _tradition_stat_weight(merc, trad.weight_plus_10, 10.0, STAT_KEYS)
		net += _tradition_stat_weight(merc, trad.weight_minus_25, -25.0, STAT_KEYS)
		net += _tradition_stat_weight(merc, trad.weight_minus_5, -5.0, STAT_KEYS)
		net += _tradition_stat_threshold_weight(merc, trad.stat_boost_15, 15.0, -15.0)
		net += _tradition_stat_threshold_weight(merc, trad.stat_boost_10, 10.0, -10.0)
		for stat_name: String in trad.stat_boost_5:
			net += _tradition_stat_threshold_weight(merc, stat_name, 5.0, -5.0)
		if net != 0.0:
			boosts[trad.tradition_name] = maxf(-9.9, net)
	return boosts


static func _tradition_stat_weight(merc: MercenaryData, stat_name: String, weight_per_point: float, key_map: Dictionary) -> float:
	if stat_name == "":
		return 0.0
	var key: String = key_map.get(stat_name, "") as String
	if key == "":
		return 0.0
	return (merc.max_stats.get(key, 0) as int) * weight_per_point


static func _tradition_stat_threshold_weight(merc: MercenaryData, stat_name: String, threshold: float, penalty: float) -> float:
	if stat_name == "":
		return 0.0
	var var_name: String = stat_name.to_lower().replace(" ", "_")
	var current: float = merc.stats.get(var_name, 0.0) as float
	if current > threshold:
		return penalty
	return 0.0


static func _step7_stats(merc: MercenaryData) -> void:
	if merc.is_hybrid:
		var dom_bonuses: Dictionary = _merged_pair_stat_bonuses(merc.ancestry, merc.bloodline)
		var rec_bonuses: Dictionary = _merged_pair_stat_bonuses(merc.recessive_ancestry, merc.recessive_bloodline)
		for key: String in dom_bonuses:
			_add_stat_multiplier(merc, key, dom_bonuses[key] as float)
		for key: String in rec_bonuses:
			var dom_val: float = dom_bonuses.get(key, 0.0) as float
			var rec_val: float = rec_bonuses[key] as float
			if rec_val > dom_val:
				_add_stat_multiplier(merc, key, rec_val - dom_val)
	else:
		var empty_str_arr: Array[String] = []
		_apply_stat_bonus_5pct(merc, merc.ancestry.stat_bonus_5pct if merc.ancestry else empty_str_arr)
		if merc.bloodline:
			_apply_stat_bonus_5pct(merc, merc.bloodline.stat_bonus_5pct)
	if merc.heritage:
		_apply_stat_bonus_5pct(merc, merc.heritage.stat_bonus_5pct)
	for lp: LifepathData in merc.lifepaths:
		_apply_stat_bonus_5pct(merc, lp.stat_bonus_5pct)

	merc.luck_roll = _roll_luck()
	StatCalculator.refresh(merc)


static func _collect_stat_bonus_5pct(stat_names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	var core_stats: Array[String] = ["cognition", "dexterity", "vigor", "wile"]
	for raw_name: String in stat_names:
		var resolved: String = raw_name
		if raw_name == "Any":
			resolved = core_stats[randi() % core_stats.size()]
		var var_name: String = resolved.to_lower().replace(" ", "_")
		result[var_name] = (result.get(var_name, 0.0) as float) + 0.05
	return result


static func _merged_pair_stat_bonuses(a: AncestryData, bl: AncestryData) -> Dictionary:
	var empty: Array[String] = []
	var result: Dictionary = _collect_stat_bonus_5pct(a.stat_bonus_5pct if a else empty)
	if bl:
		var bl_bonuses: Dictionary = _collect_stat_bonus_5pct(bl.stat_bonus_5pct)
		for key: String in bl_bonuses:
			result[key] = (result.get(key, 0.0) as float) + (bl_bonuses[key] as float)
	return result


static func _apply_stat_bonus_5pct(merc: MercenaryData, stat_names: Array[String]) -> void:
	var core_stats: Array[String] = ["cognition", "dexterity", "vigor", "wile"]
	for raw_name: String in stat_names:
		var resolved: String = raw_name
		if raw_name == "Any":
			resolved = core_stats[randi() % core_stats.size()]
		_add_stat_multiplier(merc, resolved.to_lower().replace(" ", "_"), 0.05)


static func _apply_tradition_boosts(merc: MercenaryData) -> void:
	var trad: TraditionData = merc.tradition
	_apply_single_stat_boost(merc, trad.stat_boost_15, 0.15)
	_apply_single_stat_boost(merc, trad.stat_boost_10, 0.10)
	for stat_name: String in trad.stat_boost_5:
		_apply_single_stat_boost(merc, stat_name, 0.05)


static func _get_min_tradition_count() -> int:
	if _tradition_batch_counts.size() < DataManager.traditions.size():
		return 0
	var min_val: int = -1
	for v: Variant in _tradition_batch_counts.values():
		var val: int = v as int
		if min_val < 0 or val < min_val:
			min_val = val
	return maxi(0, min_val)


static func _resolve_tradition_with_rerolls(
		items: Array[Dictionary], trad_boosts: Dictionary) -> String:
	var candidate: String = WeightedTable.roll(items, trad_boosts)
	var min_count: int = _get_min_tradition_count()
	var visited: Dictionary = {}

	while true:
		if visited.has(candidate):
			var best_candidates: Array[String] = []
			var best_eff: int = -1
			for item: Dictionary in items:
				var name: String = item["name"] as String
				if visited.has(name):
					continue
				var eff: int = maxi(0, (_tradition_batch_counts.get(name, 0) as int) - min_count)
				if best_eff < 0 or eff < best_eff:
					best_eff = eff
					best_candidates.clear()
					best_candidates.append(name)
				elif eff == best_eff:
					best_candidates.append(name)
			if best_candidates.size() > 0:
				var filtered_items: Array[Dictionary] = []
				for item: Dictionary in items:
					if best_candidates.has(item["name"] as String):
						filtered_items.append(item)
				return WeightedTable.roll(filtered_items, trad_boosts)
			return candidate
		visited[candidate] = true

		var raw: int = _tradition_batch_counts.get(candidate, 0) as int
		var effective: int = maxi(0, raw - min_count)

		if effective == 0:
			return candidate

		var displaced: bool = false
		for _i: int in range(effective):
			var reroll: String = WeightedTable.roll(items, trad_boosts)
			if reroll != candidate:
				candidate = reroll
				displaced = true
				break

		if not displaced:
			return candidate

	return candidate


static func _apply_single_stat_boost(merc: MercenaryData, stat_name: String, mult: float) -> void:
	if stat_name == "":
		return
	_add_stat_multiplier(merc, stat_name.to_lower().replace(" ", "_"), mult)


static func _roll_luck() -> float:
	var r: float = randf() * 100.0
	if r < 45.0:
		return randf() * 5.0
	if r < 65.0:
		return 5.0 + randf() * 5.0
	if r < 80.0:
		return 10.0 + randf() * 10.0
	if r < 90.0:
		return 20.0 + randf() * 10.0
	if r < 99.0:
		return 30.0 + randf() * 10.0
	if r < 99.99:
		return 40.0 + randf() * 10.0
	return 50.0


static func _get_penalty_boosts(category: String) -> Dictionary:
	var boosts: Dictionary = {}
	for name: String in _rolling_penalties.get(category, {}):
		var penalty: float = _rolling_penalties[category][name] as float
		if penalty > 0.0:
			boosts[name] = -penalty
	return boosts


static func _update_rolling_penalties(merc: MercenaryData) -> void:
	var rolled: Dictionary = {
		"location": {}, "ancestry": {}, "bloodline": {},
		"heritage": {}, "lifepath": {}, "tradition": {},
	}

	if merc.starting_location:
		rolled["location"][merc.starting_location.location_name] = true
	if merc.ancestry:
		rolled["ancestry"][merc.ancestry.ancestry_name] = true
	if merc.recessive_ancestry:
		rolled["ancestry"][merc.recessive_ancestry.ancestry_name] = true
	if merc.bloodline:
		rolled["bloodline"][merc.bloodline.ancestry_name] = true
	if merc.recessive_bloodline:
		rolled["bloodline"][merc.recessive_bloodline.ancestry_name] = true
	if merc.heritage:
		rolled["heritage"][merc.heritage.heritage_name] = true
	if merc.lifepaths.size() > 0:
		rolled["lifepath"][merc.lifepaths[0].event_name] = true
	if merc.tradition:
		rolled["tradition"][merc.tradition.tradition_name] = true

	for category: String in _rolling_penalties:
		var category_rolled: Dictionary = rolled.get(category, {})
		for name: String in _rolling_penalties[category].keys():
			var penalty: float = _rolling_penalties[category][name] as float
			if category_rolled.has(name):
				var new_penalty: float = penalty * 2.0 if penalty > 0.0 else penalty
				_rolling_penalty_age[category][name] = 0
				_rolling_penalties[category][name] = new_penalty
			else:
				var age: int = (_rolling_penalty_age[category].get(name, 0) as int) + 1
				if age >= 10:
					_rolling_penalties[category].erase(name)
					_rolling_penalty_age[category].erase(name)
					continue
				var updated: float = maxf(0.0, penalty - 1.0)
				if updated == 0.0:
					_rolling_penalties[category].erase(name)
					_rolling_penalty_age[category].erase(name)
				else:
					_rolling_penalties[category][name] = updated
					_rolling_penalty_age[category][name] = age
		for name: String in category_rolled:
			if not _rolling_penalties[category].has(name):
				_rolling_penalties[category][name] = 5.0
				_rolling_penalty_age[category][name] = 0

	var dom_ancestry := _dominant_physical_stat(merc.ancestry) if merc.ancestry else ""
	var dom_rec_ancestry := _dominant_physical_stat(merc.recessive_ancestry) if merc.recessive_ancestry else ""
	var dom_bloodline := _dominant_physical_stat(merc.bloodline) if merc.bloodline else ""
	var dom_rec_bloodline := _dominant_physical_stat(merc.recessive_bloodline) if merc.recessive_bloodline else ""
	var dom_heritage := _dominant_mental_stat(merc.heritage) if merc.heritage else ""

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

	for category: String in _rolling_stat_penalties:
		var triggered: Dictionary = stat_triggered.get(category, {})
		for stat: String in _rolling_stat_penalties[category].keys():
			var penalty: float = _rolling_stat_penalties[category][stat] as float
			if triggered.has(stat):
				_rolling_stat_penalties[category][stat] = penalty * 2.0 if penalty > 0.0 else penalty
				_rolling_stat_penalty_age[category][stat] = 0
			else:
				var age: int = (_rolling_stat_penalty_age[category].get(stat, 0) as int) + 1
				if age >= 10:
					_rolling_stat_penalties[category].erase(stat)
					_rolling_stat_penalty_age[category].erase(stat)
					continue
				var updated: float = maxf(0.0, penalty - 1.0)
				if updated == 0.0:
					_rolling_stat_penalties[category].erase(stat)
					_rolling_stat_penalty_age[category].erase(stat)
				else:
					_rolling_stat_penalties[category][stat] = updated
					_rolling_stat_penalty_age[category][stat] = age
		for stat: String in triggered:
			if not _rolling_stat_penalties[category].has(stat):
				_rolling_stat_penalties[category][stat] = 5.0
				_rolling_stat_penalty_age[category][stat] = 0


static func _step8_equip_weapon(merc: MercenaryData) -> void:
	var melee_pool: Array = DataManager.weapons_ordinary_melee.filter(
		func(w: WeaponData) -> bool: return w.weapon_class != "Magical")
	var ranged_pool: Array[WeaponData] = []
	for w: WeaponData in DataManager.weapons_ordinary_ranged:
		if w.weapon_class != "Magical":
			ranged_pool.append(w)
	for w: WeaponData in DataManager.weapons_common_ranged:
		if w.weapon_class != "Magical":
			ranged_pool.append(w)

	var melee_w: WeaponData = null
	var ranged_w: WeaponData = null
	if not melee_pool.is_empty():
		melee_w = melee_pool[randi() % melee_pool.size()] as WeaponData
	if not ranged_pool.is_empty():
		ranged_w = ranged_pool[randi() % ranged_pool.size()] as WeaponData

	# Set ranged as equipped first so _equip_starting_ammo can find compatible ammo
	if ranged_w != null:
		merc.equipped_weapon = ranged_w
		_equip_starting_ammo(merc)
	elif melee_w != null:
		merc.equipped_weapon = melee_w

	# Carry the other weapon in inventory; BattleState.create() randomizes which is drawn
	if melee_w != null and ranged_w != null:
		merc.inventory.append({"type": "weapon", "data": melee_w})


static func _step9_equip_armor(merc: MercenaryData) -> void:
	var merc_vigor: int = int(merc.stats.get("vigor", 0))
	var pool: Array = []
	for a in DataManager.armor_ordinary_common:
		if a.vigor_requirement == 0 or merc_vigor >= a.vigor_requirement:
			pool.append(a)
	if pool.is_empty():
		return
	merc.equipped_armor = pool[randi() % pool.size()] as ArmorData
	for prot_type: String in merc.equipped_armor.protection:
		var eff := "protected:" + prot_type.to_lower()
		if not merc.passive_effects.has(eff):
			merc.passive_effects.append(eff)


static func _equip_starting_ammo(merc: MercenaryData) -> void:
	var weapon := merc.equipped_weapon
	if weapon == null:
		return
	var compatible_ammo: Array = []
	for a in DataManager.ammo_ordinary_common:
		if a.compatible.has(weapon.weapon_type):
			compatible_ammo.append(a)
	if compatible_ammo.is_empty():
		return
	var chosen = compatible_ammo[randi() % compatible_ammo.size()]
	merc.ammo_loaded_type = chosen.item_name
	merc.ammo_loaded = chosen.amount if weapon.chamber <= 0 else mini(weapon.chamber, chosen.amount)
	# Reserve = total supply minus what's already in the chamber, so total shots == chosen.amount
	var reserve: int = chosen.amount - merc.ammo_loaded
	if reserve > 0:
		merc.ammo_inventory[chosen.item_name] = reserve


#Adds a flat stat token amount; StatCalculator folds it inside the dependency loop.
static func _add_stat_flat(merc: MercenaryData, var_name: String, amount: float) -> void:
	StatCalculator.add_flat(merc, var_name, amount)


#Sums a fractional multiplier; two +5% boosts store 0.10 and scale the computed value once.
static func _add_stat_multiplier(merc: MercenaryData, var_name: String, amount: float) -> void:
	StatCalculator.add_percent(merc, var_name, amount)


#One warning per spelling per run, so a dead sheet cell stays visible without spamming the log.
static func _warn_token_once(key: String, reason: String) -> void:
	if _warned_tokens.has(key):
		return
	_warned_tokens[key] = true
	push_warning("MercGenerator: '%s' %s" % [key, reason])


#Substitutes every [COLUMN] placeholder with a random value from that Types.tsv column.
static func _expand_trait_placeholders(name: String) -> String:
	var result: String = name
	while true:
		var open_idx: int = result.find("[")
		if open_idx < 0:
			break
		var close_idx: int = result.find("]", open_idx)
		if close_idx < 0:
			break
		var header: String = result.substr(open_idx + 1, close_idx - open_idx - 1)
		var values: Array = DataManager.type_columns.get(header, []) as Array
		if values.is_empty():
			_warn_token_once("[" + header + "]", "has no Types.tsv column")
			return ""
		var pick: String = values[randi() % values.size()] as String
		result = result.substr(0, open_idx) + pick + result.substr(close_idx + 1)
	return result


#Every [COLUMN] expansion of a name, in Types.tsv column order; no roll, unknown column gives none.
static func placeholder_variants(name: String) -> Array[String]:
	var results: Array[String] = [name]
	while true:
		var pending: Array[String] = []
		var expanded: bool = false
		for entry: String in results:
			var open_idx: int = entry.find("[")
			var close_idx: int = entry.find("]", open_idx) if open_idx >= 0 else -1
			if open_idx < 0 or close_idx < 0:
				pending.append(entry)
				continue
			var header: String = entry.substr(open_idx + 1, close_idx - open_idx - 1)
			var values: Array = DataManager.type_columns.get(header, []) as Array
			if values.is_empty():
				_warn_token_once("[" + header + "]", "has no Types.tsv column")
				return []
			expanded = true
			for value: String in values:
				pending.append(entry.substr(0, open_idx) + value + entry.substr(close_idx + 1))
		results = pending
		if not expanded:
			break
	return results


#Traits.tsv lookup that resolves [COLUMN] placeholders first and warns once on a missing row.
static func _lookup_trait(raw_name: String) -> TraitData:
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
	_warn_token_once(warn_key, "has no Traits.tsv row")
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


#Single recalculation point; passes after _step7_stats change merc fields, never merc.stats.
static func _recalculate_stats(merc: MercenaryData) -> void:
	StatCalculator.refresh(merc)


#Perk rows of the weapon library; filter matches a trait_category or part of a weapon type key.
static func _weapon_perk_pool(filter: String) -> Array[TraitData]:
	var pool: Array[TraitData] = []
	for key: String in DataManager.weapon_trait_library:
		var key_match: bool = filter == "" or filter == "any" or key.to_lower().contains(filter)
		for entry: Variant in (DataManager.weapon_trait_library[key] as Array):
			var td: TraitData = entry as TraitData
			if td == null or td.trait_type != "Perk":
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
static func _grant_random_group_perks(merc: MercenaryData, group: String, count: int, token: String) -> void:
	var held: Dictionary = {}
	var sources: Array = [merc.weapon_perks, merc.armor_perks, merc.perks, merc.drawbacks, merc.descriptors]
	for source: Variant in sources:
		for entry: Variant in (source as Array):
			var held_td: TraitData = entry as TraitData
			if held_td:
				held[held_td.trait_name] = true
	var choices: Array[TraitData] = []
	for td: TraitData in _perk_group_pool(group):
		if not held.has(td.trait_name):
			choices.append(td)
	if choices.is_empty():
		_warn_token_once(token, "has no perk group members")
		return
	choices.shuffle()
	for i: int in range(mini(count, choices.size())):
		var drawn: TraitData = choices[i]
		match drawn.trait_source:
			"Weapon":
				merc.weapon_perks.append(drawn)
			"Armor":
				merc.armor_perks.append(drawn)
			_:
				_assign_trait(merc, drawn)
		_apply_dsl_to_merc(merc, drawn.effect_dsl)
		merc.group_perk_cells_applied[drawn.trait_name] = true


#Draws count perks the merc does not already hold and appends them to the granted list.
static func _grant_random_perks(target: Array[TraitData], pool: Array[TraitData], count: int, token: String) -> void:
	var held: Dictionary = {}
	for td: TraitData in target:
		if td:
			held[td.trait_name] = true
	var choices: Array[TraitData] = []
	for td: TraitData in pool:
		if not held.has(td.trait_name):
			choices.append(td)
	if choices.is_empty():
		_warn_token_once(token, "has no perk left to draw")
		return
	choices.shuffle()
	for i: int in range(mini(count, choices.size())):
		target.append(choices[i])


#Filter is empty, all, a stat word such as wile, or a circumstance name such as resist.
static func _circumstance_matches_filter(display: String, filter: String) -> bool:
	if filter == "" or filter == "all" or filter == "any":
		return true
	var row: Dictionary = ConstCircumstances.DATA.get(display, {}) as Dictionary
	if (row.get("stat", "") as String).to_lower() == filter:
		return true
	return (row.get("circumstance_name", "") as String).to_lower().replace(" ", "_") == filter
