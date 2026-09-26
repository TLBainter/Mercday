class_name MercGenerator

#When >= 0 generate() writes this level before the stat step; OpponentGenerator resets it
static var forced_level: int = -1
#Harness: every combatant gains N weapon perks and 1 armor perk for the gear it holds
static var force_perk_load: int = 0
#When it names a DataManager.traditions key _step5_tradition uses it instead of the roll
static var forced_tradition: String = ""
#Tradition name to percent multiplier boost, read by the tradition roll; OpponentGenerator sets and clears it
static var tradition_odds: Dictionary = {}

#max_ spellings that name a Stats.tsv row instead of a core maximum
const MAX_STAT_ALIASES: Dictionary = {
	"max_hp": "maximum_hit_points",
	"max_ep": "maximum_endurance_points",
	"max_mp": "maximum_magic_points",
}


static func generate(_merc_index: int = 0) -> MercenaryData:
	var merc := MercenaryData.new()
	merc.merc_uid = CampaignKnowledge.next_uid()
	if _merc_index == 0:
		RollingPenalties.tradition_batch_counts.clear()
	_reset_generated_fields(merc)
	merc.xp = 0
	if forced_level >= 0:
		merc.stats["level"] = float(forced_level)
		merc.xp = ExperienceSystem.xp_for_level(maxi(0, forced_level))

	_step1_origin(merc)
	_step2_ancestry(merc)
	_step3_heritage(merc)
	_step4_lifepath(merc)
	_prepare_max_stats(merc)
	_step6_traits(merc)
	_step7_stats(merc)
	StatCalculator.apply_ability_grants(merc)
	_clamp_floor_stats(merc)
	_apply_random_stat_boosts(merc)
	_step5_tradition(merc)
	AgeSystem.step_age(merc)
	merc.merc_name = NameGenerator.generate(merc.starting_location)
	_seed_current_pools(merc)
	StartingGear.step_gear(merc)
	WeaponArmorPerkLibrary.resolve_deferred_grants(merc)
	StatCalculator.refresh(merc)
	LevelUpSystem.catch_up(merc)
	merc.action_set = DefaultActionSet.create()
	RollingPenalties.update_rolling_penalties(merc)
	return merc


#Blanks every field the pipeline fills, so no value survives from a previous roll.
static func _reset_generated_fields(merc: MercenaryData) -> void:
	merc.stat_bonuses = {}
	merc.stat_flat_bonuses = {}
	merc.stat_multipliers = {}
	merc.max_stats = {}
	merc.odds_bonuses = {}
	merc.stats = {}
	merc.stats_baseline = {}
	merc.circumstance_flags = ConstCircumstances.make_flags()
	merc.circumstance_additional_bonus = ConstCircumstances.make_bonuses()
	merc.blocked_circumstances = []
	merc.passive_effects = []
	merc.min_stats = {}
	merc.cost_modifiers = {}
	merc.items = []


#Fills the current pools from the finished stats; reputation starts at one point per ten luck.
static func _seed_current_pools(merc: MercenaryData) -> void:
	merc.current_hp = int(merc.stats.get("maximum_hit_points", 1))
	merc.current_ep = int(merc.stats.get("maximum_endurance_points", 1))
	merc.current_mp = int(merc.stats.get("maximum_magic_points", 1))
	merc.current_ap = int(merc.stats.get("action_points", 5))
	merc.current_rep = int(floor(float(merc.stats.get("luck", 0.0)) / 10.0))


static func _step1_origin(merc: MercenaryData) -> void:
	var settlements: Array = DataManager.get_settlement_locations()
	if settlements.is_empty():
		return
	var items: Array[Dictionary] = WeightedTable.items_from(
			settlements, "location_name", "", "Uncommon")
	var loc_name: String = WeightedTable.roll(items, RollingPenalties.get_penalty_boosts("location"))
	merc.starting_location = DataManager.locations.get(loc_name, null) as LocationData
	if merc.starting_location:
		_seed_odds_from_location(merc)


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
	var ancestry_items: Array[Dictionary] = WeightedTable.items_from(
			DataManager.ancestries.values(), "ancestry_name", "rarity")
	var combined_flat: Dictionary = {}
	if loc:
		for n: String in loc.ancestry_buffs:
			combined_flat[n] = loc.ancestry_buffs[n] as float
		for n: String in loc.ancestry_debuffs:
			combined_flat[n] = -(loc.ancestry_debuffs[n] as float)

	for pen_name: String in RollingPenalties.rolling_penalties["ancestry"]:
		combined_flat[pen_name] = (combined_flat.get(pen_name, 0.0) as float) - (RollingPenalties.rolling_penalties["ancestry"][pen_name] as float)

	_apply_dominant_stat_penalty(ancestry_items, DataManager.ancestries, "ancestry",
			RollingPenalties.dominant_physical_stat, combined_flat)

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
	for pen_name: String in RollingPenalties.rolling_penalties["bloodline"]:
		bl_flat[pen_name] = (bl_flat.get(pen_name, 0.0) as float) - (RollingPenalties.rolling_penalties["bloodline"][pen_name] as float)

	_apply_dominant_stat_penalty(bl_items, DataManager.bloodlines, "bloodline",
			RollingPenalties.dominant_physical_stat, bl_flat)

	var bl_name: String = WeightedTable.roll(bl_items, bl_flat, {}, {"Core": 50.0})
	if bl_name.is_empty():
		bl_name = "Core"
	return null if bl_name == "Core" else DataManager.bloodlines.get(bl_name, null) as AncestryData


static func _step3_heritage(merc: MercenaryData) -> void:
	var loc: LocationData = merc.starting_location
	var heritage_items: Array[Dictionary] = WeightedTable.items_from(
			DataManager.heritages.values(), "heritage_name", "", "Common")
	var flat_boosts: Dictionary = {}
	if loc:
		flat_boosts = loc.heritage_buffs.duplicate()
	for pen_name: String in RollingPenalties.rolling_penalties["heritage"]:
		flat_boosts[pen_name] = (flat_boosts.get(pen_name, 0.0) as float) - (RollingPenalties.rolling_penalties["heritage"][pen_name] as float)

	_apply_dominant_stat_penalty(heritage_items, DataManager.heritages, "heritage",
			RollingPenalties.dominant_mental_stat, flat_boosts)

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


#Subtracts the rolling stat penalty of each candidate's dominant stat from its flat boost.
static func _apply_dominant_stat_penalty(items: Array[Dictionary], source: Dictionary,
		category: String, dominant: Callable, flat_boosts: Dictionary) -> void:
	for item: Dictionary in items:
		var candidate: Variant = source.get(item["name"], null)
		if candidate:
			var dom: String = dominant.call(candidate)
			if dom != "" and (RollingPenalties.rolling_stat_penalties[category].get(dom, 0.0) as float) > 0.0:
				flat_boosts[item["name"]] = (flat_boosts.get(item["name"], 0.0) as float) \
					- (RollingPenalties.rolling_stat_penalties[category][dom] as float)


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
	var pool: Array = DataManager.starting_lifepaths.values()
	var items: Array[Dictionary] = WeightedTable.items_from(
			LifepathRequirements.filter(merc, pool), "event_name", "rarity")
	if items.is_empty():
		return
	var lp_name: String = WeightedTable.roll(items, RollingPenalties.get_penalty_boosts("lifepath"))
	var lp: LifepathData = DataManager.starting_lifepaths.get(lp_name, null) as LifepathData
	if lp:
		merc.lifepaths.append(lp)




static func _step5_tradition(merc: MercenaryData) -> void:
	var items: Array[Dictionary] = WeightedTable.items_from(
			DataManager.traditions.values(), "tradition_name", "", "Common")
	if items.is_empty():
		return
	var trad_boosts: Dictionary = _build_tradition_boosts(merc)
	for pen_name: String in RollingPenalties.rolling_penalties["tradition"]:
		trad_boosts[pen_name] = (trad_boosts.get(pen_name, 0.0) as float) - (RollingPenalties.rolling_penalties["tradition"][pen_name] as float)
	var trad_name: String = forced_tradition if (forced_tradition != "" \
		and DataManager.traditions.has(forced_tradition)) else _resolve_tradition_with_rerolls(items, trad_boosts)
	merc.tradition = DataManager.traditions.get(trad_name, null) as TraditionData
	if not merc.tradition:
		return
	RollingPenalties.tradition_batch_counts[trad_name] = RollingPenalties.tradition_batch_counts.get(trad_name, 0) + 1

	_apply_tradition_boosts(merc)

	_apply_tradition_circumstance(merc)

	#Runs last so the circumstance flags and bonus set above reach the derived stats.
	StatCalculator.refresh(merc)


#Grants the tradition circumstance; one already held keeps its bonus and rolls one extra instead.
static func _apply_tradition_circumstance(merc: MercenaryData) -> void:
	var boost_name: String = merc.tradition.circumstance_boost
	if boost_name == "":
		return
	var already_had: bool = merc.circumstance_flags.get(boost_name, false)
	merc.circumstance_additional_bonus[boost_name] = 25.0
	if not already_had:
		if ConstCircumstances.DATA.has(boost_name):
			merc.circumstance_flags[boost_name] = true
		return
	var extra_pool: Array[Dictionary] = []
	for display_name: String in ConstCircumstances.DATA:
		extra_pool.append({"name": display_name, "rarity": ConstCircumstances.DATA[display_name]["rarity"]})
	if extra_pool.size() > 0:
		var extra_name: String = WeightedTable.roll(extra_pool)
		if ConstCircumstances.DATA.has(extra_name):
			merc.circumstance_flags[extra_name] = true


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
		var trait_data: TraitData = TraitDSL.lookup_trait(trait_name)
		if trait_data:
			assign_trait(merc, trait_data)
	for trait_name: String in drawback_names:
		var trait_data: TraitData = TraitDSL.lookup_trait(trait_name)
		if trait_data:
			assign_trait(merc, trait_data)

	var perk_count_before: int = merc.perks.size()
	var drawback_count_before: int = merc.drawbacks.size()

	var all_traits: Array[TraitData] = []
	all_traits.append_array(merc.perks)
	all_traits.append_array(merc.drawbacks)
	for trait_data: TraitData in all_traits:
		TraitDSL.apply_dsl_to_merc(merc, trait_data.effect_dsl, trait_data.trait_name)

	for i: int in range(perk_count_before, merc.perks.size()):
		if merc.group_perk_cells_applied.has(merc.perks[i].trait_name):
			continue
		TraitDSL.apply_dsl_to_merc(merc, merc.perks[i].effect_dsl, merc.perks[i].trait_name)
	for i: int in range(drawback_count_before, merc.drawbacks.size()):
		if merc.group_perk_cells_applied.has(merc.drawbacks[i].trait_name):
			continue
		TraitDSL.apply_dsl_to_merc(merc, merc.drawbacks[i].effect_dsl, merc.drawbacks[i].trait_name)


static func assign_trait(merc: MercenaryData, trait_data: TraitData) -> void:
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


static func _clamp_floor_stats(merc: MercenaryData) -> void:
	for stat_def: Dictionary in DataManager.stat_definitions:
		if stat_def["round"] != "floor" or stat_def["type"] == "boolean":
			continue
		var var_name: String = stat_def["var_name"]
		if merc.stats.has(var_name):
			merc.stats[var_name] = maxi(0, int(merc.stats[var_name]))


static func _apply_random_stat_boosts(merc: MercenaryData) -> void:
	var core_stats: Array[String] = []
	core_stats.assign(StatCalculator.CORE_STATS)
	core_stats.shuffle()
	for i: int in range(2):
		var stat_key: String = core_stats[i]
		merc.stat_bonuses[stat_key] = (merc.stat_bonuses.get(stat_key, 0.0) as float) + 1.0
	StatCalculator.refresh(merc)


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


static func _tradition_stat_weight(merc: MercenaryData, stat_name: String, weight_per_point: float,
		key_map: Dictionary) -> float:
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
			StatCalculator.add_percent(merc, key, dom_bonuses[key] as float)
		for key: String in rec_bonuses:
			var dom_val: float = dom_bonuses.get(key, 0.0) as float
			var rec_val: float = rec_bonuses[key] as float
			if rec_val > dom_val:
				StatCalculator.add_percent(merc, key, rec_val - dom_val)
	else:
		var empty_str_arr: Array[String] = []
		apply_stat_bonus_5pct(merc, merc.ancestry.stat_bonus_5pct if merc.ancestry else empty_str_arr)
		if merc.bloodline:
			apply_stat_bonus_5pct(merc, merc.bloodline.stat_bonus_5pct)
	if merc.heritage:
		apply_stat_bonus_5pct(merc, merc.heritage.stat_bonus_5pct)
	for lp: LifepathData in merc.lifepaths:
		apply_stat_bonus_5pct(merc, lp.stat_bonus_5pct)

	merc.luck_roll = _roll_luck()
	StatCalculator.refresh(merc)


static func _collect_stat_bonus_5pct(stat_names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for raw_name: String in stat_names:
		var resolved: String = raw_name
		if raw_name == "Any":
			resolved = StatCalculator.CORE_STATS[randi() % StatCalculator.CORE_STATS.size()]
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


static func apply_stat_bonus_5pct(merc: MercenaryData, stat_names: Array[String]) -> void:
	var bonuses: Dictionary = _collect_stat_bonus_5pct(stat_names)
	for var_name: String in bonuses:
		StatCalculator.add_percent(merc, var_name, bonuses[var_name] as float)


static func _apply_tradition_boosts(merc: MercenaryData) -> void:
	var trad: TraditionData = merc.tradition
	_apply_single_stat_boost(merc, trad.stat_boost_15, 0.15)
	_apply_single_stat_boost(merc, trad.stat_boost_10, 0.10)
	for stat_name: String in trad.stat_boost_5:
		_apply_single_stat_boost(merc, stat_name, 0.05)


static func _get_min_tradition_count() -> int:
	if RollingPenalties.tradition_batch_counts.size() < DataManager.traditions.size():
		return 0
	var min_val: int = -1
	for v: Variant in RollingPenalties.tradition_batch_counts.values():
		var val: int = v as int
		if min_val < 0 or val < min_val:
			min_val = val
	return maxi(0, min_val)


static func _resolve_tradition_with_rerolls(
		items: Array[Dictionary], trad_boosts: Dictionary) -> String:
	var candidate: String = WeightedTable.roll(items, trad_boosts, tradition_odds)
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
				var eff: int = maxi(0, (RollingPenalties.tradition_batch_counts.get(name, 0) as int) - min_count)
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
				return WeightedTable.roll(filtered_items, trad_boosts, tradition_odds)
			return candidate
		visited[candidate] = true

		var raw: int = RollingPenalties.tradition_batch_counts.get(candidate, 0) as int
		var effective: int = maxi(0, raw - min_count)

		if effective == 0:
			return candidate

		var displaced: bool = false
		for _i: int in range(effective):
			var reroll: String = WeightedTable.roll(items, trad_boosts, tradition_odds)
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
	StatCalculator.add_percent(merc, stat_name.to_lower().replace(" ", "_"), mult)


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


#Harness only: fills a combatant with perks for the gear it already holds, once per merc.
static func load_gear_perks(merc: MercenaryData, count: int) -> Array[String]:
	var details: Array[String] = []
	if merc == null or count <= 0 or merc.has_meta("perk_load_done"):
		return details
	merc.set_meta("perk_load_done", true)
	var keys: Dictionary = WeaponArmorPerkLibrary.held_gear_keys(merc)
	var before_w: int = merc.weapon_perks.size()
	var before_a: int = merc.armor_perks.size()
	if not (keys["weapon"] as Array).is_empty():
		WeaponArmorPerkLibrary.grant_gear_perks(merc, "weapon", "", count, "harness:perk_load", "harness")
	if not (keys["armor"] as Array).is_empty():
		WeaponArmorPerkLibrary.grant_gear_perks(merc, "armor", "", 1, "harness:perk_load", "harness")
	for td: TraitData in merc.weapon_perks.slice(before_w):
		if td != null:
			details.append("weapon %s perk %s" % [td.gear_key, WeaponArmorPerkLibrary.perk_display_name(td)])
	for td: TraitData in merc.armor_perks.slice(before_a):
		if td != null:
			details.append("armor %s perk %s" % [td.gear_key, WeaponArmorPerkLibrary.perk_display_name(td)])
	return details


#Entry points kept for callers outside generation; the bodies live in the scripts named here.
static func apply_dsl_to_merc(merc: MercenaryData, dsl: String, source_name: String = "") -> void:
	TraitDSL.apply_dsl_to_merc(merc, dsl, source_name)


static func cap_carried_ammo(merc: MercenaryData, cap: int) -> void:
	StartingGear.cap_carried_ammo(merc, cap)


static func _equip_starting_ammo(merc: MercenaryData) -> void:
	StartingGear.equip_starting_ammo(merc)
