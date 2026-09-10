class_name NPCGenerator

static var _rolling_penalties: Dictionary = {
	"location": {}, "ancestry": {}, "bloodline": {},
	"heritage": {}, "lifepath": {}, "tradition": {},
}
static var _rolling_penalty_age: Dictionary = {
	"location": {}, "ancestry": {}, "bloodline": {},
	"heritage": {}, "lifepath": {}, "tradition": {},
}


static func generate_batch(npc_type: String, count: int, party_context: Dictionary = {}) -> Array[MercenaryData]:
	var results: Array[MercenaryData] = []
	var template: NPCTemplate = DataManager.npc_templates.get(npc_type, null) as NPCTemplate
	if not template:
		push_error("NPCGenerator: unknown npc_type '%s'" % npc_type)
		return results
	for i: int in range(count):
		results.append(generate(template, party_context, i))
	return results


static func generate(template: NPCTemplate, party_context: Dictionary = {}, npc_index: int = 0) -> MercenaryData:
	var merc := MercenaryData.new()
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

	merc.stats["level"] = float(maxi(0, _eval_level_formula(template.level_formula, party_context)))
	merc.xp = ExperienceSystem.xp_for_level(int(merc.stats["level"]))
	#NPCs are Adult by default; an NPCs.tsv age column is a to-do.
	merc.age_category = MercGenerator.AGE_ADULT

	_npc_step_origin(merc, template)
	_npc_step_ancestry(merc, template)
	_npc_step_heritage(merc, template)
	_npc_apply_passive_tokens(merc, template)
	_npc_step_lifepaths(merc, template, party_context)

	MercGenerator._prepare_max_stats(merc)
	MercGenerator._step6_traits(merc)
	MercGenerator._step7_stats(merc)
	MercGenerator._reapply_ability_grants(merc)
	MercGenerator._clamp_floor_stats(merc)
	MercGenerator._apply_random_stat_boosts(merc)

	_npc_step_tradition(merc, template)

	merc.merc_name = _npc_generate_name(merc, template)
	merc.current_hp = int(merc.stats.get("maximum_hit_points", 1))
	merc.current_ep = int(merc.stats.get("maximum_endurance_points", 1))
	merc.current_mp = int(merc.stats.get("maximum_magic_points", 1))
	merc.current_ap = int(merc.stats.get("action_points", 5))
	merc.current_rep = int(floor(float(merc.stats.get("luck", 0.0)) / 10.0))

	_npc_step_equip(merc, template)
	merc.action_set = DefaultActionSet.create()
	_update_npc_rolling_penalties(merc)
	return merc


#NPCs.tsv Immunities tokens become passive effects before any lifepath is picked.
static func _npc_apply_passive_tokens(merc: MercenaryData, template: NPCTemplate) -> void:
	var where: String = "NPCs.tsv " + template.npc_type
	for token: String in template.passive_tokens:
		if merc.passive_effects.has(token):
			continue
		if not ConstStates.immune_token_allowed(token, where):
			continue
		merc.passive_effects.append(token)


static func _eval_level_formula(formula: String, party: Dictionary) -> int:
	if formula.is_empty():
		return 0
	var processed: String = formula
	processed = processed.replace("party.average_level", str(party.get("average_level", 0.0)))
	processed = processed.replace("party.merc_count", str(party.get("merc_count", 0)))
	var re := RegEx.new()
	re.compile("randf\\(([^,]+),\\s*([^)]+)\\)")
	for m: RegExMatch in re.search_all(processed):
		var lo: float = float(m.get_string(1))
		var hi: float = float(m.get_string(2))
		processed = processed.replace(m.get_string(), str(randf_range(lo, hi)))
	var expr := Expression.new()
	if expr.parse(processed) == OK:
		var result: Variant = expr.execute([])
		if not expr.has_execute_failed():
			return maxi(0, int(floorf(float(result))))
	push_error("NPCGenerator: failed to evaluate level formula '%s'" % formula)
	return 0


static func _eval_le_count(le_str: String, party: Dictionary) -> int:
	var s: String = le_str.strip_edges()
	if s.is_valid_int():
		return maxi(0, int(s))
	if "-" in s:
		var parts: PackedStringArray = s.split("-")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return randi_range(int(parts[0]), int(parts[1]))
	return maxi(0, _eval_level_formula(s, party))


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
	var items: Array[Dictionary] = []
	for loc: LocationData in pool:
		items.append({"name": loc.location_name, "rarity": "Uncommon"})
	var loc_name: String = WeightedTable.roll(items, _get_npc_penalty_boosts("location"))
	merc.starting_location = DataManager.locations.get(loc_name, null) as LocationData
	if merc.starting_location:
		MercGenerator._seed_odds_from_location(merc)


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

	var ancestry_items: Array[Dictionary] = []
	for a: AncestryData in ancestry_list:
		ancestry_items.append({"name": a.ancestry_name, "rarity": a.rarity})

	var combined_flat: Dictionary = {}
	if loc:
		for n: String in loc.ancestry_buffs:
			combined_flat[n] = loc.ancestry_buffs[n] as float
		for n: String in loc.ancestry_debuffs:
			combined_flat[n] = -(loc.ancestry_debuffs[n] as float)
	for pen_name: String in _rolling_penalties["ancestry"]:
		combined_flat[pen_name] = (combined_flat.get(pen_name, 0.0) as float) - (_rolling_penalties["ancestry"][pen_name] as float)

	var first_name: String = WeightedTable.roll(ancestry_items, combined_flat)
	var first_ancestry: AncestryData = DataManager.ancestries.get(first_name, null) as AncestryData
	if not first_ancestry:
		return

	merc.ancestry = first_ancestry
	merc.bloodline = _npc_roll_bloodline(first_ancestry, loc, template)

	if merc.bloodline and merc.bloodline.types.size() > 0:
		merc.creature_types = merc.bloodline.types.duplicate()
	else:
		merc.creature_types = merc.ancestry.types.duplicate()


static func _npc_roll_bloodline(ancestry: AncestryData, loc: LocationData, template: NPCTemplate) -> AncestryData:
	var forced: String = ""
	if not template.ancestry_any:
		forced = template.ancestry_constraints.get(ancestry.ancestry_name, "") as String

	if not forced.is_empty():
		if DataManager.bloodlines.has(forced):
			return DataManager.bloodlines[forced] as AncestryData
		return null

	return MercGenerator._roll_bloodline(ancestry, loc)


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

	var heritage_items: Array[Dictionary] = []
	for h: HeritageData in heritage_list:
		heritage_items.append({"name": h.heritage_name, "rarity": "Common"})

	var loc: LocationData = merc.starting_location
	var flat_boosts: Dictionary = {}
	if loc:
		flat_boosts = loc.heritage_buffs.duplicate()
	for pen_name: String in _rolling_penalties["heritage"]:
		flat_boosts[pen_name] = (flat_boosts.get(pen_name, 0.0) as float) - (_rolling_penalties["heritage"][pen_name] as float)

	var heritage_name: String = WeightedTable.roll(heritage_items, flat_boosts)
	merc.heritage = DataManager.heritages.get(heritage_name, null) as HeritageData
	if not merc.heritage:
		return

	var circ_pool: Array[Dictionary] = MercGenerator._build_circumstance_pool(merc.heritage)
	if circ_pool.size() > 0:
		var circ_name: String = WeightedTable.roll(circ_pool)
		if ConstCircumstances.DATA.has(circ_name):
			merc.circumstance_flags[circ_name] = true

	var kt_pool: Array[Dictionary] = MercGenerator._build_kt_pool(merc.heritage)
	if kt_pool.size() > 0:
		var kt_name: String = WeightedTable.roll(kt_pool)
		if DataManager.knowledges.has(kt_name):
			merc.knowledges.append(DataManager.knowledges[kt_name] as UtilityTraitData)
		elif DataManager.tools.has(kt_name):
			merc.tools.append(DataManager.tools[kt_name] as UtilityTraitData)


static func _npc_step_lifepaths(merc: MercenaryData, template: NPCTemplate, party: Dictionary) -> void:
	var count: int = _eval_le_count(template.le_count_str, party)
	if count == 0:
		return

	if template.sle_name != "None":
		var lp: LifepathData = null
		if template.sle_name == "Any":
			var items: Array[Dictionary] = []
			var sle_pool: Array = DataManager.starting_lifepaths.values()
			for ev: LifepathData in LifepathRequirements.filter(merc, sle_pool):
				items.append({"name": ev.event_name, "rarity": ev.rarity})
			if not items.is_empty():
				var picked: String = WeightedTable.roll(items, _get_npc_penalty_boosts("lifepath"))
				lp = DataManager.starting_lifepaths.get(picked, null) as LifepathData
		else:
			lp = DataManager.starting_lifepaths.get(template.sle_name, null) as LifepathData
			if not lp:
				for cat_arr: Array in DataManager.lifepaths_by_category.values():
					for ev: LifepathData in cat_arr:
						if ev.event_name == template.sle_name:
							lp = ev
							break
					if lp:
						break
		if lp:
			merc.lifepaths.append(lp)

	var remaining: int = count - 1
	if remaining <= 0:
		return
	if not template.ele_any and template.ele_pool.is_empty():
		return

	var candidates: Array[LifepathData] = []
	if template.ele_any:
		for cat_arr: Array in DataManager.lifepaths_by_category.values():
			for ev: LifepathData in cat_arr:
				candidates.append(ev)
	else:
		for ev_name: String in template.ele_pool:
			for cat_arr: Array in DataManager.lifepaths_by_category.values():
				for ev: LifepathData in cat_arr:
					if ev.event_name == ev_name:
						candidates.append(ev)
						break

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


static func _npc_step_tradition(merc: MercenaryData, template: NPCTemplate) -> void:
	if template.tradition_none:
		return
	if template.tradition_any:
		MercGenerator._step5_tradition(merc)
		return

	var trad_list: Array = []
	for t_name: String in template.tradition_pool:
		var t: TraditionData = DataManager.traditions.get(t_name, null) as TraditionData
		if t:
			trad_list.append(t)
	if trad_list.is_empty():
		return

	var items: Array[Dictionary] = []
	for trad: TraditionData in trad_list:
		items.append({"name": trad.tradition_name, "rarity": "Common"})

	var trad_boosts: Dictionary = MercGenerator._build_tradition_boosts(merc)
	for pen_name: String in _rolling_penalties["tradition"]:
		trad_boosts[pen_name] = (trad_boosts.get(pen_name, 0.0) as float) - (_rolling_penalties["tradition"][pen_name] as float)

	var trad_name: String = WeightedTable.roll(items, trad_boosts)
	merc.tradition = DataManager.traditions.get(trad_name, null) as TraditionData
	if not merc.tradition:
		return
	MercGenerator._apply_tradition_boosts(merc)

	var boost_name: String = merc.tradition.circumstance_boost
	if not boost_name.is_empty():
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

	#Runs last so the tradition boosts and circumstance flags reach the derived stats.
	MercGenerator._recalculate_stats(merc)


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
		MercGenerator._equip_starting_ammo(merc)


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
	merc.equipped_armor = armor
	for prot_type: String in armor.protection:
		var eff: String = "protected:" + prot_type.to_lower()
		if not merc.passive_effects.has(eff):
			merc.passive_effects.append(eff)


static func _get_npc_penalty_boosts(category: String) -> Dictionary:
	var boosts: Dictionary = {}
	for name: String in _rolling_penalties.get(category, {}):
		var penalty: float = _rolling_penalties[category][name] as float
		if penalty > 0.0:
			boosts[name] = -penalty
	return boosts


static func _update_npc_rolling_penalties(merc: MercenaryData) -> void:
	var rolled: Dictionary = {
		"location": {}, "ancestry": {}, "bloodline": {},
		"heritage": {}, "lifepath": {}, "tradition": {},
	}
	if merc.starting_location:
		rolled["location"][merc.starting_location.location_name] = true
	if merc.ancestry:
		rolled["ancestry"][merc.ancestry.ancestry_name] = true
	if merc.bloodline:
		rolled["bloodline"][merc.bloodline.ancestry_name] = true
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
