class_name LevelUpSystem

#Level up rewards. An experience level spends one point on a Level Ups.tsv option, a skill level
#banks a skill point. A pool entry a merc takes is marked and never offered again in that tier.

const LEVEL_CAP := 40
const CASTING_TRADITIONS: PackedStringArray = ["Mage", "Sorcerer", "Divine", "Mystech"]
const RARITY_RANK: Dictionary = {"Common": 1, "Uncommon": 2, "Rare": 3, "Very Rare": 4, "Legendary": 5}
const EQUIPPED_GEAR_FACTOR := 3.0
const TRADITION_PLUS_25_FACTOR := 2.0
const TRADITION_PLUS_10_FACTOR := 1.5
const TRADITION_MINUS_25_FACTOR := 0.5
const TRADITION_MINUS_5_FACTOR := 0.8
const WEAPON_STAT_FACTOR := 1.5
const TOP_STAT_FACTOR := 2.0
const EVENT_NAMED_FACTOR := 3.0
const CATEGORY_MATCH_FACTOR := 1.5
const LOW_POOL_FACTOR := 1.5
const NON_CASTER_SPELLCAST_FACTOR := 0.25
const CIRCUMSTANCE_FACTOR_CAP := 2.0
const MAGIC_POINT_BOOST := "Maximum Magic Points"
const SPELLCAST_PREFIX := "Spellcast ("

#Events.tsv knowledge names and tool name prefixes; built once and reused.
static var _event_knowledges: Dictionary = {}
static var _event_tools: Array[String] = []
#Option keys with no handler, reported once each.
static var _warned_options: Dictionary = {}
static func is_experience_level(level: int) -> bool:
	if level == 0 or level == 1:
		return true
	return level >= 2 and level <= LEVEL_CAP and level % 2 == 0


static func is_skill_level(level: int) -> bool:
	return level >= 3 and level <= 39 and level % 2 == 1


static func tier_rows(level: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in DataManager.level_up_rows:
		if (row.get("levels", []) as Array).has(level):
			rows.append(row)
	return rows


static func mark_key(row: Dictionary) -> String:
	return "%s|%s|%d" % [str(row.get("tier", "")), str(row.get("option", "")), int(row.get("ordinal", 1))]


#Runs the schedule for exactly one level: the skill point, then every experience point owed.
static func on_level(merc: MercenaryData, level: int) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	if is_skill_level(level):
		merc.skill_points += 1
		merc.level_up_log.append({"level": level, "tier": "Schedule",
			"option": "schedule_skill_point", "detail": "total %d" % merc.skill_points})
		lines.append("SKILL POINT: %s L%d total %d" % [merc.merc_name, level, merc.skill_points])
	if is_experience_level(level):
		var picks: int = 1 + merc.banked_experience_points
		merc.banked_experience_points = 0
		_refresh_lifepath_pool(merc, level)
		for _i: int in range(picks):
			var pool: Array[Dictionary] = build_pool(merc, level)
			if pool.is_empty():
				merc.banked_experience_points += picks - _i
				lines.append("EXPERIENCE POINT BANKED: %s L%d no option, banked %d"
					% [merc.merc_name, level, merc.banked_experience_points])
				break
			var drawn: Dictionary = _draw_entry(pool)
			var row: Dictionary = drawn.get("row", {}) as Dictionary
			if row.is_empty():
				merc.banked_experience_points += picks - _i
				break
			var option: String = str(row.get("option", ""))
			var outcome: Dictionary = _apply(merc, row)
			var detail: String = str(outcome.get("detail", ""))
			if option != "bank" and bool(outcome.get("applied", false)):
				merc.level_up_marks[mark_key(row)] = true
			merc.level_up_log.append({"level": level, "tier": str(row.get("tier", "")),
				"option": option, "detail": detail})
			lines.append("LEVEL UP PICK: %s L%d %s %s: %s"
				% [merc.merc_name, level, str(row.get("tier", "")), option, detail])
	merc.level_ups_resolved = maxi(merc.level_ups_resolved, level)
	return lines


#Every level the merc reached without its picks; generation callers drop the lines.
static func catch_up(merc: MercenaryData) -> Array[String]:
	var lines: Array[String] = []
	if merc == null:
		return lines
	var level: int = int(merc.stats.get("level", 0))
	for lvl: int in range(merc.level_ups_resolved + 1, level + 1):
		lines.append_array(on_level(merc, lvl))
	return lines


static func note_weapon_use(merc: MercenaryData, weapon: WeaponData) -> void:
	if merc == null:
		return
	var key: String = _weapon_key(weapon)
	if key == "":
		return
	merc.gear_use_counts["weapon:" + key] = int(merc.gear_use_counts.get("weapon:" + key, 0)) + 1


static func note_armor_use(merc: MercenaryData) -> void:
	if merc == null or merc.equipped_armor == null or merc.equipped_armor.armor_type == "":
		return
	var key: String = "armor:" + merc.equipped_armor.armor_type
	merc.gear_use_counts[key] = int(merc.gear_use_counts.get(key, 0)) + 1


#The tier entries this merc can still take, each with the weight the draw rolls against.
static func build_pool(merc: MercenaryData, level: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	if merc == null:
		return pool
	for row: Dictionary in tier_rows(level):
		if merc.level_up_marks.has(mark_key(row)):
			continue
		var factor: float = _usefulness(merc, row)
		if factor <= 0.0:
			continue
		pool.append({"row": row, "weight": float(row.get("weight", 1.0)) * factor})
	return pool


#How much this merc wants the option; 0 omits it from the pool.
static func _usefulness(merc: MercenaryData, row: Dictionary) -> float:
	var option: String = str(row.get("option", ""))
	if option.begins_with("attribute:"):
		return _best_weight(_attribute_candidates(merc, option))
	match option:
		"max_hp":
			return LOW_POOL_FACTOR if int(merc.stats.get("maximum_hit_points", 0)) < 5 else 1.0
		"max_ep":
			return LOW_POOL_FACTOR if int(merc.stats.get("maximum_endurance_points", 0)) < 3 else 1.0
		"max_mp":
			if not _is_caster(merc):
				return 0.0
			if merc.tradition != null and (merc.tradition.stat_boost_15 == MAGIC_POINT_BOOST
					or merc.tradition.stat_boost_10 == MAGIC_POINT_BOOST):
				return LOW_POOL_FACTOR
			return 1.0
		"circumstance":
			return minf(_best_weight(_circumstance_candidates(merc)), CIRCUMSTANCE_FACTOR_CAP)
		"knowledge":
			return 1.0 if not _utility_candidates(merc, true, false).is_empty() else 0.0
		"tool":
			return 1.0 if not _utility_candidates(merc, false, true).is_empty() else 0.0
		"knowledge_or_tool":
			return 1.0 if not _utility_candidates(merc, true, true).is_empty() else 0.0
		"armor_or_weapon_perk":
			return 1.0 if not _gear_candidates(merc).is_empty() else 0.0
		"lifepath_event":
			return 1.0 if not _lifepath_candidates(merc).is_empty() else 0.0
		"skill_point", "tradition_skill_point", "class_skill_tree", "action_points", "bank":
			return 1.0
		"pace":
			return LOW_POOL_FACTOR if int(merc.stats.get("pace", 0)) <= 3 else 1.0
	if not _warned_options.has(option):
		_warned_options[option] = true
		push_warning("LevelUpSystem: Level Ups.tsv option '%s' has no handler" % option)
	return 0.0


#Whether the pick landed, with the text the log and the pick line carry.
static func _granted(detail: String) -> Dictionary:
	return {"applied": true, "detail": detail}


static func _missed(detail: String) -> Dictionary:
	return {"applied": false, "detail": detail}


#Grants one drawn entry and returns the outcome the log and the pick line carry.
static func _apply(merc: MercenaryData, row: Dictionary) -> Dictionary:
	var option: String = str(row.get("option", ""))
	if option.begins_with("attribute:"):
		return _apply_attribute(merc, option)
	match option:
		"max_hp":
			merc.current_hp += 1
			return _granted(_apply_pool(merc, "maximum_hit_points", "max HP"))
		"max_ep":
			merc.current_ep += 1
			return _granted(_apply_pool(merc, "maximum_endurance_points", "max EP"))
		"max_mp":
			merc.current_mp += 1
			return _granted(_apply_pool(merc, "maximum_magic_points", "max MP"))
		"pace":
			return _granted(_apply_pool(merc, "pace", "pace"))
		"action_points":
			merc.current_ap += 1
			return _granted(_apply_pool(merc, "action_points", "max AP"))
		"circumstance":
			return _apply_circumstance(merc)
		"knowledge":
			return _apply_utility(merc, true, false)
		"tool":
			return _apply_utility(merc, false, true)
		"knowledge_or_tool":
			return _apply_utility(merc, true, true)
		"armor_or_weapon_perk":
			return _apply_gear_perk(merc)
		"lifepath_event":
			return _apply_lifepath(merc)
		"skill_point":
			merc.skill_points += 1
			return _granted("skill points %d" % merc.skill_points)
		"tradition_skill_point":
			merc.tradition_skill_points += 1
			return _granted("tradition skill points %d" % merc.tradition_skill_points)
		"class_skill_tree":
			merc.class_skill_trees += 1
			return _granted("class skill trees %d" % merc.class_skill_trees)
		"bank":
			merc.banked_experience_points += 1
			return _granted("banked %d" % merc.banked_experience_points)
	return _missed("no effect")


static func _apply_pool(merc: MercenaryData, key: String, label: String) -> String:
	StatCalculator.add_flat(merc, key, 1.0)
	StatCalculator.refresh(merc)
	return "%s %d" % [label, int(merc.stats.get(key, 0))]


static func _apply_attribute(merc: MercenaryData, option: String) -> Dictionary:
	var pick: Dictionary = _draw_entry(_attribute_candidates(merc, option))
	if pick.is_empty():
		return _missed("no attribute")
	var key: String = str(pick.get("key", ""))
	var before: int = int(merc.stats.get(key, 0))
	StatCalculator.prime(merc)
	merc.stat_bonuses[key] = float(merc.stat_bonuses.get(key, 0.0)) + 1.0
	StatCalculator.refresh(merc)
	return _granted("%s %d to %d" % [key, before, int(merc.stats.get(key, 0))])


static func _apply_circumstance(merc: MercenaryData) -> Dictionary:
	var pick: Dictionary = _draw_entry(_circumstance_candidates(merc))
	if pick.is_empty():
		return _missed("no circumstance")
	var display: String = str(pick.get("name", ""))
	StatCalculator.prime(merc)
	merc.circumstance_flags[display] = true
	StatCalculator.refresh(merc)
	return _granted(display)


static func _apply_utility(merc: MercenaryData, want_knowledge: bool, want_tool: bool) -> Dictionary:
	var pick: Dictionary = _draw_entry(_utility_candidates(merc, want_knowledge, want_tool))
	var data: UtilityTraitData = pick.get("data", null) as UtilityTraitData
	if data == null:
		return _missed("no trait")
	if str(pick.get("kind", "")) == "knowledge":
		merc.knowledges.append(data)
		return _granted("knowledge %s" % data.utility_name)
	merc.tools.append(data)
	return _granted("tool %s" % data.utility_name)


static func _apply_gear_perk(merc: MercenaryData) -> Dictionary:
	var pick: Dictionary = _draw_entry(_gear_candidates(merc))
	if pick.is_empty():
		return _missed("no gear perk")
	var perks: Array[TraitData] = []
	perks.assign(pick.get("perks", []) as Array)
	if perks.is_empty():
		return _missed("no gear perk")
	var perk: TraitData = perks[randi() % perks.size()]
	var kind: String = str(pick.get("kind", ""))
	if kind == "weapon":
		WeaponArmorPerkLibrary.grant_weapon_perk(merc, perk, "level up")
	else:
		WeaponArmorPerkLibrary.grant_armor_perk(merc, perk, "level up")
	return _granted("%s %s perk %s" % [kind, str(pick.get("key", "")), perk.trait_name])


static func _apply_lifepath(merc: MercenaryData) -> Dictionary:
	var candidates: Array[LifepathData] = _lifepath_candidates(merc)
	if candidates.is_empty():
		return _missed("no lifepath")
	var best: int = -2147483647
	var tied: Array[LifepathData] = []
	for lp: LifepathData in candidates:
		var score: int = _lifepath_score(merc, lp)
		if score > best:
			best = score
			tied.clear()
			tied.append(lp)
		elif score == best:
			tied.append(lp)
	var choice: LifepathData = tied[randi() % tied.size()]
	if LifepathProgression.grant(merc, choice.event_name).is_empty():
		return _missed("lifepath %s not granted" % choice.event_name)
	return _granted("lifepath %s (score %d)" % [choice.event_name, best])


#Rarer events score higher; payoff traits add and drawback traits take away.
static func _lifepath_score(merc: MercenaryData, lp: LifepathData) -> int:
	if lp == null:
		return 0
	var score: int = int(RARITY_RANK.get(lp.rarity, 1)) * 3 + lp.perks.size() * 2 - lp.drawbacks.size() * 2
	var top: Dictionary = _top_core_stats(merc)
	var trad_stat: String = _tradition_stat(merc)
	for stat_name: String in lp.stat_bonus_5pct:
		var key: String = stat_name.to_lower()
		if key == "any" or top.has(key) or (trad_stat != "" and key == trad_stat):
			score += 2
			break
	return score


static func _attribute_candidates(merc: MercenaryData, option: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parts: PackedStringArray = option.split(":")
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return out
	var from_value: int = int(parts[1])
	var to_value: int = int(parts[2])
	for key: String in StatCalculator.CORE_STATS:
		if int(merc.stats.get(key, 0)) != from_value:
			continue
		if int(merc.max_stats.get("max_" + key, 0)) < to_value:
			continue
		out.append({"key": key, "weight": _attribute_factor(merc, key)})
	return out


static func _attribute_factor(merc: MercenaryData, key: String) -> float:
	var factor: float = 1.0
	var trad: TraditionData = merc.tradition
	if trad != null:
		if trad.weight_plus_25.to_lower() == key:
			factor *= TRADITION_PLUS_25_FACTOR
		if trad.weight_plus_10.to_lower() == key:
			factor *= TRADITION_PLUS_10_FACTOR
		if trad.weight_minus_25.to_lower() == key:
			factor *= TRADITION_MINUS_25_FACTOR
		if trad.weight_minus_5.to_lower() == key:
			factor *= TRADITION_MINUS_5_FACTOR
	if _attack_stat_keys(merc).has(key):
		factor *= WEAPON_STAT_FACTOR
	return factor


static func _circumstance_candidates(merc: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var top: Dictionary = _top_core_stats(merc)
	var trad_stat: String = _tradition_stat(merc)
	var attack_keys: Array[String] = _attack_stat_keys(merc)
	var caster: bool = _is_caster(merc)
	for display: String in ConstCircumstances.ALL:
		if bool(merc.circumstance_flags.get(display, false)) or merc.blocked_circumstances.has(display):
			continue
		var data: Dictionary = ConstCircumstances.DATA.get(display, {}) as Dictionary
		var stat: String = str(data.get("stat", "")).to_lower()
		var circ_name: String = str(data.get("circumstance_name", ""))
		var weight: float = float(WeightedTable.TIER_WEIGHTS.get(str(data.get("rarity", "")), 50.0)) / 50.0
		if top.has(stat):
			weight *= TOP_STAT_FACTOR
		if stat != "" and stat == trad_stat:
			weight *= TRADITION_PLUS_25_FACTOR
		if circ_name == "Attack" and attack_keys.has(stat):
			weight *= WEAPON_STAT_FACTOR
		if circ_name == "Spellcast" and not caster:
			weight *= NON_CASTER_SPELLCAST_FACTOR
		out.append({"name": display, "weight": weight})
	return out


static func _utility_candidates(merc: MercenaryData, want_knowledge: bool, want_tool: bool) -> Array[Dictionary]:
	_ensure_event_sets()
	var out: Array[Dictionary] = []
	if want_knowledge:
		_collect_utilities(DataManager.knowledges, merc.knowledges, "knowledge", out)
	if want_tool:
		_collect_utilities(DataManager.tools, merc.tools, "tool", out)
	return out


static func _collect_utilities(source: Dictionary, held: Array[UtilityTraitData], kind: String,
		out: Array[Dictionary]) -> void:
	var held_names: Dictionary = {}
	var held_categories: Dictionary = {}
	for entry: UtilityTraitData in held:
		if entry == null:
			continue
		held_names[entry.utility_name] = true
		if entry.utility_category != "":
			held_categories[entry.utility_category] = true
	for entry_name: String in source:
		var data: UtilityTraitData = source[entry_name] as UtilityTraitData
		if data == null or held_names.has(data.utility_name):
			continue
		var weight: float = float(WeightedTable.TIER_WEIGHTS.get(data.utility_rarity, 50.0))
		if _event_named(data.utility_name, kind):
			weight *= EVENT_NAMED_FACTOR
		if data.utility_category != "" and held_categories.has(data.utility_category):
			weight *= CATEGORY_MATCH_FACTOR
		out.append({"data": data, "kind": kind, "weight": weight})


#A knowledge an Events.tsv row names, or a tool whose name starts with one an event row names.
static func _event_named(utility_name: String, kind: String) -> bool:
	if kind == "knowledge":
		return _event_knowledges.has(utility_name)
	for prefix: String in _event_tools:
		if utility_name.begins_with(prefix):
			return true
	return false


static func _ensure_event_sets() -> void:
	if not _event_knowledges.is_empty() or not _event_tools.is_empty():
		return
	for row: Dictionary in DataManager.event_rows:
		for known: String in TsvReader.split_field(str(row.get("Knowledges", ""))):
			_event_knowledges[known] = true
		for tool_name: String in TsvReader.split_field(str(row.get("Tools", ""))):
			if not _event_tools.has(tool_name):
				_event_tools.append(tool_name)


#Owned gear that still has a perk to give, weighted by use and by what the merc carries now.
static func _gear_candidates(merc: MercenaryData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weapon_keys: Array[String] = []
	var armor_keys: Array[String] = []
	var equipped: Dictionary = {}
	var main_key: String = _weapon_key(merc.equipped_weapon)
	if main_key != "":
		equipped["weapon:" + main_key] = true
		weapon_keys.append(main_key)
	var off_key: String = _weapon_key(merc.offhand_weapon)
	if off_key != "":
		equipped["weapon:" + off_key] = true
		if not weapon_keys.has(off_key):
			weapon_keys.append(off_key)
	if merc.equipped_armor != null and merc.equipped_armor.armor_type != "":
		equipped["armor:" + merc.equipped_armor.armor_type] = true
		armor_keys.append(merc.equipped_armor.armor_type)
	for entry: Dictionary in merc.inventory:
		var kind: String = str(entry.get("type", ""))
		if kind == "weapon":
			var key: String = _weapon_key(entry.get("data", null) as WeaponData)
			if key != "" and not weapon_keys.has(key):
				weapon_keys.append(key)
		elif kind == "armor":
			var armor: ArmorData = entry.get("data", null) as ArmorData
			if armor != null and armor.armor_type != "" and not armor_keys.has(armor.armor_type):
				armor_keys.append(armor.armor_type)
	var held_weapon: Dictionary = _perk_names(merc.weapon_perks)
	var held_armor: Dictionary = _perk_names(merc.armor_perks)
	for key: String in weapon_keys:
		var perks: Array[TraitData] = _library_perks(
			DataManager.weapon_trait_library.get(key, []) as Array, held_weapon, false)
		if perks.is_empty():
			continue
		out.append(_gear_entry(merc, "weapon", key, equipped.has("weapon:" + key), perks))
	for key: String in armor_keys:
		var perks: Array[TraitData] = _library_perks(
			DataManager.armor_trait_library.get(key, []) as Array, held_armor, true)
		if perks.is_empty():
			continue
		out.append(_gear_entry(merc, "armor", key, equipped.has("armor:" + key), perks))
	return out


static func _gear_entry(merc: MercenaryData, kind: String, key: String, is_equipped: bool,
		perks: Array[TraitData]) -> Dictionary:
	var used: float = float(int(merc.gear_use_counts.get(kind + ":" + key, 0)))
	var weight: float = (1.0 + used) * (EQUIPPED_GEAR_FACTOR if is_equipped else 1.0)
	return {"kind": kind, "key": key, "equipped": is_equipped, "perks": perks, "weight": weight}


static func _library_perks(rows: Array, held: Dictionary, perks_only: bool) -> Array[TraitData]:
	var out: Array[TraitData] = []
	for entry: Variant in rows:
		var td: TraitData = entry as TraitData
		if td == null or held.has(td.trait_name):
			continue
		if perks_only and td.trait_type != "Perk":
			continue
		if not perks_only and td.trait_type != "Perk" and td.trait_type != "Action":
			continue
		out.append(td)
	return out


static func _perk_names(owned: Array[TraitData]) -> Dictionary:
	var out: Dictionary = {}
	for perk: TraitData in owned:
		if perk != null:
			out[perk.trait_name] = true
	return out


#Pool events the merc qualified for and can still take; the contract path fills the pool.
static func _lifepath_candidates(merc: MercenaryData) -> Array[LifepathData]:
	var out: Array[LifepathData] = []
	if merc.lifepaths.size() >= LifepathProgression.MAX_EVENTS:
		return out
	var team_empty: bool = LifepathProgression.team().is_empty()
	for event_name: String in merc.lifepath_pool:
		if team_empty and LifepathProgression.CODED_EVENTS.has(event_name):
			continue
		if LifepathProgression.has_event(merc, event_name):
			continue
		var lp: LifepathData = _find_experienced(event_name)
		if lp == null or lp.rarity == "Guaranteed":
			continue
		out.append(lp)
	return out


static func _find_experienced(event_name: String) -> LifepathData:
	for entry: Variant in (DataManager.lifepaths_by_category.get("Experienced", []) as Array):
		var lp: LifepathData = entry as LifepathData
		if lp != null and lp.event_name == event_name:
			return lp
	return null


#Pools the events a merc qualifies for only when this level can still spend a pick on one.
static func _refresh_lifepath_pool(merc: MercenaryData, level: int) -> void:
	if merc.merc_uid <= 0 or merc.lifepaths.size() >= LifepathProgression.MAX_EVENTS:
		return
	for row: Dictionary in tier_rows(level):
		if str(row.get("option", "")) != "lifepath_event":
			continue
		if merc.level_up_marks.has(mark_key(row)):
			continue
		LifepathProgression.refresh_pool(merc, null)
		return


static func _is_caster(merc: MercenaryData) -> bool:
	if merc.tradition != null and CASTING_TRADITIONS.has(merc.tradition.tradition_name):
		return true
	for display: String in merc.circumstance_flags:
		if display.begins_with(SPELLCAST_PREFIX) and bool(merc.circumstance_flags[display]):
			return true
	return false


#The core stat keys sitting at the merc's highest core value; ties all count.
static func _top_core_stats(merc: MercenaryData) -> Dictionary:
	var best: int = -1
	for key: String in StatCalculator.CORE_STATS:
		best = maxi(best, int(merc.stats.get(key, 0)))
	var out: Dictionary = {}
	for key: String in StatCalculator.CORE_STATS:
		if int(merc.stats.get(key, 0)) == best:
			out[key] = true
	return out


static func _tradition_stat(merc: MercenaryData) -> String:
	if merc.tradition == null:
		return ""
	return merc.tradition.weight_plus_25.to_lower()


static func _attack_stat_keys(merc: MercenaryData) -> Array[String]:
	var out: Array[String] = []
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or weapon.is_virtual:
		return out
	out.assign(AttackSystem.attack_stat_keys(weapon))
	return out


static func _weapon_key(weapon: WeaponData) -> String:
	if weapon == null or weapon.is_virtual or weapon.weapon_type == "":
		return ""
	return WeaponArmorPerkLibrary.weapon_type_key(weapon)


static func _best_weight(entries: Array[Dictionary]) -> float:
	var best: float = 0.0
	for entry: Dictionary in entries:
		best = maxf(best, float(entry.get("weight", 0.0)))
	return best


#One entry drawn in proportion to its weight.
static func _draw_entry(entries: Array[Dictionary]) -> Dictionary:
	var total: float = 0.0
	for entry: Dictionary in entries:
		total += maxf(0.0, float(entry.get("weight", 0.0)))
	if entries.is_empty() or total <= 0.0:
		return {}
	var roll: float = randf() * total
	var acc: float = 0.0
	for entry: Dictionary in entries:
		acc += maxf(0.0, float(entry.get("weight", 0.0)))
		if roll <= acc:
			return entry
	return entries[entries.size() - 1]


static func summary(merc: MercenaryData) -> String:
	if merc == null or merc.level_up_log.is_empty():
		return "(none)"
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in merc.level_up_log:
		parts.append("L%d %s: %s" % [int(entry.get("level", 0)), str(entry.get("option", "")),
			str(entry.get("detail", ""))])
	return ", ".join(parts)


static func counters(merc: MercenaryData) -> String:
	if merc == null:
		return ""
	return "skill %d, tradition %d, class trees %d, banked XP %d" % [merc.skill_points,
		merc.tradition_skill_points, merc.class_skill_trees, merc.banked_experience_points]
