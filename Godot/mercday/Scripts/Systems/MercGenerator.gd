class_name MercGenerator

const _DEFAULT_ACTIONS := preload("res://Scripts/Actions/Resources/DefaultActionSet.tres")
#When >= 0 generate() writes this level before the stat step; OpponentGenerator resets it
static var forced_level: int = -1
#When it names a DataManager.traditions key GenerationSteps.step5_tradition uses it instead of the roll
static var forced_tradition: String = ""
#Tradition name to percent multiplier boost, read by the tradition roll; OpponentGenerator sets and clears it
static var tradition_odds: Dictionary = {}


static func generate(merc_index: int = 0) -> MercenaryData:
	var merc := MercenaryData.new()
	merc.merc_uid = CampaignKnowledge.next_uid()
	if merc_index == 0:
		RollingPenalties.tradition_batch_counts.clear()
	GenerationSteps.reset_generated_fields(merc)
	merc.xp = 0
	if forced_level >= 0:
		merc.stats["level"] = float(forced_level)
		merc.xp = ExperienceSystem.xp_for_level(maxi(0, forced_level))

	_step1_origin(merc)
	_step2_ancestry(merc)
	_step3_heritage(merc)
	_step4_lifepath(merc)
	GenerationSteps.prepare_max_stats(merc)
	GenerationSteps.step6_traits(merc)
	GenerationSteps.step7_stats(merc)
	GenerationSteps.clamp_floor_stats(merc)
	GenerationSteps.apply_random_stat_boosts(merc)
	GenerationSteps.step5_tradition(merc)
	AgeSystem.step_age(merc)
	merc.merc_name = NameGenerator.generate(merc.starting_location)
	GenerationSteps.seed_current_pools(merc)
	StartingGear.step_gear(merc)
	PerkGrants.resolve_deferred_grants(merc)
	StatCalculator.refresh(merc)
	LevelUpSystem.catch_up(merc)
	merc.salary_ask = SalarySystem.asking_salary(merc, [] as Array[MercenaryData])
	merc.action_set = _DEFAULT_ACTIONS
	RollingPenalties.update_rolling_penalties(merc)
	merc.appearance_seed = randi_range(1, CharacterAppearance.SEED_MAX)
	var pool: ResolvedPool = AppearanceRules.resolve(merc)
	merc.appearance = CharacterAppearance.roll(merc.appearance_seed, true, pool)
	return merc


static func _step1_origin(merc: MercenaryData) -> void:
	var settlements: Array = DataManager.get_settlement_locations()
	if settlements.is_empty():
		return
	var items: Array[Dictionary] = WeightedTable.items_from(
			settlements, "location_name", "", "Uncommon")
	var loc_name: String = WeightedTable.roll(items, RollingPenalties.get_penalty_boosts("location"))
	merc.starting_location = DataManager.locations.get(loc_name, null) as LocationData
	if merc.starting_location:
		GenerationSteps.seed_odds_from_location(merc)


static func _step2_ancestry(merc: MercenaryData) -> void:
	var loc: LocationData = merc.starting_location
	var ancestry_items: Array[Dictionary] = WeightedTable.items_from(
			DataManager.ancestries.values(), "ancestry_name", "rarity")
	var combined_flat: Dictionary = GenerationSteps.ancestry_flat_boosts(loc, RollingPenalties.rolling_penalties)

	GenerationSteps.apply_dominant_stat_penalty(ancestry_items, DataManager.ancestries, "ancestry",
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
		merc.bloodline = GenerationSteps.roll_bloodline(merc.ancestry, loc)
		merc.recessive_bloodline = GenerationSteps.roll_bloodline(merc.recessive_ancestry, loc)
	else:
		merc.ancestry = first_ancestry
		merc.bloodline = GenerationSteps.roll_bloodline(merc.ancestry, loc)

	GenerationSteps.set_creature_types(merc)


static func _can_hybridize(a1: AncestryData, a2: AncestryData) -> bool:
	if a1.hybrid_options == "None" or a2.hybrid_options == "None":
		return false
	var a1_allows: bool = a1.hybrid_options == "All" or a1.hybrid_options.split(", ").has(a2.ancestry_name)
	var a2_allows: bool = a2.hybrid_options == "All" or a2.hybrid_options.split(", ").has(a1.ancestry_name)
	return a1_allows and a2_allows


static func _step3_heritage(merc: MercenaryData) -> void:
	var loc: LocationData = merc.starting_location
	var heritage_items: Array[Dictionary] = WeightedTable.items_from(
			DataManager.heritages.values(), "heritage_name", "", "Common")
	var flat_boosts: Dictionary = GenerationSteps.heritage_flat_boosts(loc, RollingPenalties.rolling_penalties)

	GenerationSteps.apply_dominant_stat_penalty(heritage_items, DataManager.heritages, "heritage",
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

	GenerationSteps.roll_heritage(merc, heritage_items, flat_boosts, mult_boosts)


static func _apply_x20_boosts(a: AncestryData, mult_boosts: Dictionary) -> void:
	if not a:
		return
	for item_name: String in a.knowledge_odds_x20 + a.tool_odds_x20 + a.circumstance_odds_x20:
		mult_boosts[item_name] = (mult_boosts.get(item_name, 0.0) as float) + 20.0


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

