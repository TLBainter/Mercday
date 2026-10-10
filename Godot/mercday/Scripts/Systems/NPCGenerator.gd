class_name NPCGenerator

const _DEFAULT_ACTIONS := preload("res://Scripts/Actions/Resources/DefaultActionSet.tres")


static func generate(template: NPCTemplate, party_context: Dictionary = {},
		level: int = -1) -> MercenaryData:
	var merc := MercenaryData.new()
	GenerationSteps.reset_generated_fields(merc)

	if level >= 0:
		merc.stats["level"] = float(level)
	else:
		merc.stats["level"] = float(maxi(0, OpponentGenerator.eval_level(template.level_formula, party_context)))
	merc.xp = ExperienceSystem.xp_for_level(int(merc.stats["level"]))
	#NPCs are Adult by default; an NPCs.tsv age column is a to-do.
	merc.age_category = AgeSystem.AGE_ADULT

	_npc_step_origin(merc, template)
	_npc_step_ancestry(merc, template)
	_npc_step_heritage(merc, template)
	_npc_apply_passive_tokens(merc, template)
	_npc_step_lifepaths(merc, template, party_context)

	GenerationSteps.prepare_max_stats(merc)
	GenerationSteps.step6_traits(merc)
	GenerationSteps.step7_stats(merc)
	GenerationSteps.clamp_floor_stats(merc)
	GenerationSteps.apply_random_stat_boosts(merc)

	_npc_step_tradition(merc, template)
	_npc_step_traits(merc, template)

	merc.merc_name = _npc_generate_name(merc, template)
	GenerationSteps.seed_current_pools(merc)

	_npc_step_equip(merc, template)
	PerkGrants.resolve_deferred_grants(merc)
	merc.max_ammo = template.max_ammo
	StartingGear.cap_carried_ammo(merc, template.max_ammo)
	StatCalculator.refresh(merc)
	LevelUpSystem.catch_up(merc)
	merc.action_set = _DEFAULT_ACTIONS
	RollingPenalties.update_rolling_penalties(merc, true)
	merc.appearance_seed = randi_range(1, CharacterAppearance.SEED_MAX)
	var pool: ResolvedPool = AppearanceRules.resolve(merc)
	merc.appearance = CharacterAppearance.roll(merc.appearance_seed, true, pool)
	return merc


#NPCs.tsv Traits rows, applied before the gear draw so an aura is in place when gear is chosen.
static func _npc_step_traits(merc: MercenaryData, template: NPCTemplate) -> void:
	if template.traits.is_empty():
		return
	for trait_name: String in template.traits:
		var td: TraitData = TraitDSL.lookup_trait(trait_name)
		if td == null:
			push_warning("NPCGenerator: %s names unknown trait '%s'" % [template.npc_type, trait_name])
			continue
		TraitDSL.apply_dsl_to_merc(merc, td.effect_dsl, td.trait_name)
	StatCalculator.refresh(merc)


#NPCs.tsv Immunities tokens become passive effects before any lifepath is picked.
static func _npc_apply_passive_tokens(merc: MercenaryData, template: NPCTemplate) -> void:
	var where: String = "NPCs.tsv " + template.npc_type
	for token: String in template.passive_tokens:
		if merc.passive_effects.has(token):
			continue
		if not ConstStates.immune_token_allowed(token, where):
			continue
		merc.passive_effects.append(token)


static func _eval_le_count(le_str: String, party: Dictionary) -> int:
	var s: String = le_str.strip_edges()
	if s.is_valid_int():
		return maxi(0, int(s))
	if "-" in s:
		var parts: PackedStringArray = s.split("-")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return randi_range(int(parts[0]), int(parts[1]))
	return maxi(0, OpponentGenerator.eval_level(s, party))


static func _npc_step_origin(merc: MercenaryData, template: NPCTemplate) -> void:
	var pool: Array[LocationData] = []
	if template.origin_pool.is_empty():
		pool.assign(DataManager.get_settlement_locations())
	else:
		var all_settlements: Array = DataManager.get_settlement_locations()
		for entry: String in template.origin_pool:
			var loc: LocationData = DataManager.locations.get(entry, null) as LocationData
			if loc:
				if loc.location_type == "Settlement":
					pool.append(loc)
				else:
					for s: LocationData in all_settlements:
						if _location_is_in_region(s, entry):
							if not pool.has(s):
								pool.append(s)
		if pool.is_empty():
			pool.assign(all_settlements)

	if pool.is_empty():
		return
	var items: Array[Dictionary] = WeightedTable.items_from(pool, "location_name", "", "Uncommon")
	var loc_name: String = WeightedTable.roll(items, RollingPenalties.get_penalty_boosts("location", true))
	merc.starting_location = DataManager.locations.get(loc_name, null) as LocationData
	if merc.starting_location:
		GenerationSteps.seed_odds_from_location(merc)


static func _location_is_in_region(loc: LocationData, region_name: String) -> bool:
	var cur: LocationData = loc.parent
	while cur:
		if cur.location_name == region_name:
			return true
		cur = cur.parent
	return false


static func _npc_step_ancestry(merc: MercenaryData, template: NPCTemplate) -> void:
	var loc: LocationData = merc.starting_location
	var ancestry_list: Array
	if template.ancestry_any:
		ancestry_list = DataManager.ancestries.values()
	else:
		ancestry_list = []
		for a_name: String in template.ancestry_constraints:
			var a: AncestryData = DataManager.ancestries.get(a_name, null) as AncestryData
			if a:
				ancestry_list.append(a)
	if ancestry_list.is_empty():
		ancestry_list = DataManager.ancestries.values()

	var ancestry_items: Array[Dictionary] = WeightedTable.items_from(ancestry_list, "ancestry_name", "rarity")

	var combined_flat: Dictionary = GenerationSteps.ancestry_flat_boosts(loc, RollingPenalties.npc_penalties)

	var first_name: String = WeightedTable.roll(ancestry_items, combined_flat)
	var first_ancestry: AncestryData = DataManager.ancestries.get(first_name, null) as AncestryData
	if not first_ancestry:
		return

	merc.ancestry = first_ancestry
	merc.bloodline = _npc_roll_bloodline(first_ancestry, loc, template)
	GenerationSteps.set_creature_types(merc)


static func _npc_roll_bloodline(ancestry: AncestryData, loc: LocationData, template: NPCTemplate) -> AncestryData:
	var forced: String = ""
	if not template.ancestry_any:
		forced = template.ancestry_constraints.get(ancestry.ancestry_name, "") as String

	if not forced.is_empty():
		if DataManager.bloodlines.has(forced):
			return DataManager.bloodlines[forced] as AncestryData
		return null

	return GenerationSteps.roll_bloodline(ancestry, loc)


static func _npc_step_heritage(merc: MercenaryData, template: NPCTemplate) -> void:
	var heritage_list: Array
	if template.heritage_any:
		heritage_list = DataManager.heritages.values()
	else:
		heritage_list = []
		for h_name: String in template.heritage_pool:
			var h: HeritageData = DataManager.heritages.get(h_name, null) as HeritageData
			if h:
				heritage_list.append(h)
	if heritage_list.is_empty():
		heritage_list = DataManager.heritages.values()

	var heritage_items: Array[Dictionary] = WeightedTable.items_from(
			heritage_list, "heritage_name", "", "Common")

	var flat_boosts: Dictionary = GenerationSteps.heritage_flat_boosts(merc.starting_location, RollingPenalties.npc_penalties)
	GenerationSteps.roll_heritage(merc, heritage_items, flat_boosts, {})


static func _npc_step_lifepaths(merc: MercenaryData, template: NPCTemplate, party: Dictionary) -> void:
	var count_ctx: Dictionary = party.duplicate()
	count_ctx["npc_level"] = float(merc.stats.get("level", 0.0))
	var count: int = _eval_le_count(template.le_count_str, count_ctx)
	if count == 0:
		return

	var sle_added: bool = false
	if template.sle_name != "None":
		var lp: LifepathData = null
		if template.sle_name == "Any":
			var sle_pool: Array = DataManager.starting_lifepaths.values()
			var items: Array[Dictionary] = WeightedTable.items_from(
					LifepathRequirements.filter(merc, sle_pool), "event_name", "rarity")
			if not items.is_empty():
				var picked: String = WeightedTable.roll(items, RollingPenalties.get_penalty_boosts("lifepath", true))
				lp = DataManager.starting_lifepaths.get(picked, null) as LifepathData
		else:
			lp = DataManager.starting_lifepaths.get(template.sle_name, null) as LifepathData
			if not lp:
				var found: Array[LifepathData] = _find_lifepaths(template.sle_name)
				if not found.is_empty():
					lp = found[0]
		if lp:
			merc.lifepaths.append(lp)
			sle_added = true

	var remaining: int = count - 1 if sle_added else count
	if remaining <= 0:
		return
	if not template.ele_any and template.ele_pool.is_empty():
		return

	var candidates: Array[LifepathData] = []
	if template.ele_any:
		for ev: LifepathData in DataManager.lifepaths_by_category.get("Experienced", []) as Array:
			if _ele_any_allows(ev):
				candidates.append(ev)
	else:
		for ev_name: String in template.ele_pool:
			candidates.append_array(_find_lifepaths(ev_name))

	candidates.assign(LifepathRequirements.filter(merc, candidates))
	candidates.shuffle()
	var added: int = 0
	for lp: LifepathData in candidates:
		if added >= remaining:
			break
		var already: bool = false
		for held: LifepathData in merc.lifepaths:
			if held.event_name == lp.event_name:
				already = true
				break
		if not already:
			merc.lifepaths.append(lp)
			added += 1


#The first lifepath named event_name in each non Starting category, in category order.
static func _find_lifepaths(event_name: String) -> Array[LifepathData]:
	var found: Array[LifepathData] = []
	for cat_arr: Array in DataManager.lifepaths_by_category.values():
		for ev: LifepathData in cat_arr:
			if ev.event_name == event_name:
				found.append(ev)
				break
	return found


#An eLE "Any" draw takes Experienced rows only, skipping Guaranteed rarity and placeholder payoffs.
static func _ele_any_allows(ev: LifepathData) -> bool:
	if ev.rarity.strip_edges() == "Guaranteed":
		return false
	for entry: String in ev.perks:
		if "[" in entry:
			return false
	for entry: String in ev.drawbacks:
		if "[" in entry:
			return false
	return true


static func _npc_step_tradition(merc: MercenaryData, template: NPCTemplate) -> void:
	if template.tradition_none:
		return
	if template.tradition_any:
		GenerationSteps.step5_tradition(merc)
		return

	var trad_list: Array = []
	for t_name: String in template.tradition_pool:
		var t: TraditionData = DataManager.traditions.get(t_name, null) as TraditionData
		if t:
			trad_list.append(t)
	if trad_list.is_empty():
		return

	var items: Array[Dictionary] = WeightedTable.items_from(trad_list, "tradition_name", "", "Common")

	var trad_boosts: Dictionary = GenerationSteps.tradition_flat_boosts(merc, RollingPenalties.npc_penalties)

	var trad_name: String = WeightedTable.roll(items, trad_boosts)
	merc.tradition = DataManager.traditions.get(trad_name, null) as TraditionData
	if not merc.tradition:
		return
	GenerationSteps.finish_tradition(merc)


static func _npc_generate_name(merc: MercenaryData, template: NPCTemplate) -> String:
	var base: String = ""
	var mode: String = template.name_mode
	if mode == "Random":
		base = NameGenerator.generate(merc.starting_location)
	elif mode == "Random First":
		var full: String = NameGenerator.generate(merc.starting_location)
		base = full.split(" ")[0]
	elif mode == "Random Last":
		var full: String = NameGenerator.generate(merc.starting_location)
		var parts: PackedStringArray = full.split(" ")
		base = parts[parts.size() - 1]
	else:
		base = mode

	if template.npc_type.is_empty():
		return base
	return template.npc_type + " " + base


static func _npc_step_equip(merc: MercenaryData, template: NPCTemplate) -> void:
	_npc_equip_armor(merc, template)

	if template.loadout_pool.is_empty():
		return
	var loadout: String = template.loadout_pool[randi() % template.loadout_pool.size()]
	if loadout == "None":
		return

	var slots: PackedStringArray = loadout.split("|")
	var first_ranged_equipped: bool = false
	for slot: String in slots:
		slot = slot.strip_edges()
		var parts: PackedStringArray = slot.split(" ")
		if parts.size() < 2:
			continue
		var slot_count: int = int(parts[0]) if parts[0].is_valid_int() else 1
		var slot_type: String = parts[1].to_lower()

		match slot_type:
			"melee":
				var candidates: Array[WeaponData] = _filter_weapon_pool(template.weapon_pool, false)
				_equip_from_candidates(merc, candidates, slot_count, false)
			"ranged":
				var candidates: Array[WeaponData] = _filter_weapon_pool(template.weapon_pool, true)
				if _equip_from_candidates(merc, candidates, slot_count, true):
					first_ranged_equipped = true
			_:
				pass

	if first_ranged_equipped and merc.equipped_weapon != null and merc.equipped_weapon.is_ranged:
		StartingGear.equip_starting_ammo(merc)


static func _filter_weapon_pool(weapon_pool: Array[String], want_ranged: bool) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for w_name: String in weapon_pool:
		if w_name == "None":
			continue
		var w: WeaponData = DataManager.weapons.get(w_name, null) as WeaponData
		if w and w.is_ranged == want_ranged:
			result.append(w)
	return result


static func _equip_from_candidates(merc: MercenaryData, candidates: Array[WeaponData], count: int, is_ranged: bool) -> bool:
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var equipped_first: bool = false
	for i: int in range(mini(count, candidates.size())):
		var w: WeaponData = candidates[i]
		if merc.equipped_weapon == null:
			merc.equipped_weapon = w
			equipped_first = true
		else:
			merc.inventory.append({"type": "weapon", "data": w})
	return equipped_first and is_ranged


static func _npc_equip_armor(merc: MercenaryData, template: NPCTemplate) -> void:
	var non_none: Array[String] = []
	var has_none: bool = false
	for a_name: String in template.armor_pool:
		if a_name == "None":
			has_none = true
		else:
			non_none.append(a_name)

	var pool_with_none: Array[String] = non_none.duplicate()
	if has_none:
		pool_with_none.append("None")
	if pool_with_none.is_empty():
		return

	var chosen: String = pool_with_none[randi() % pool_with_none.size()]
	if chosen == "None":
		return

	var armor: ArmorData = DataManager.armor.get(chosen, null) as ArmorData
	if not armor:
		return
	StartingGear.wear_armor(merc, armor)

