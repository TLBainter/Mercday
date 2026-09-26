class_name WeaponArmorPerkLibrary

#Tokens that are permanent stat/grant effects applied immediately on acquisition.
#All others are conditional; stored and queried at runtime.
const PERMANENT_PREFIXES: PackedStringArray = [
	"stat:", "grant:", "immune:", "protected:", "susceptible:",
]

#Tokens that mark a perk as a combat action (not a passive).
const ACTION_PREFIXES: PackedStringArray = ["action:", "reactive_action:"]

#Effects that make a "SPECIAL: action:" row a real action; every other such row stays a passive.
const SPECIAL_ACTION_EFFECTS: PackedStringArray = [":attack_extended", ":called_shot:"]

#Armor Break rows carry this token behind a SPECIAL: prefix.
const ARMOR_BREAK_TOKEN: String = "on_pain:heavy,bulky_armor:reduce_armor_bonus:"

#Armor types whose wearer heavy-armor perks act against.
const HEAVY_ARMOR_TYPES: PackedStringArray = ["Heavy", "Bulky"]

#Weapon tiers that own a Makeshift perk row; Firearm has none.
const MAKESHIFT_TIERS: PackedStringArray = ["Basic", "Great", "Specialized"]

#True while resolve_deferred_grants re-runs a parked grant, so it is never parked twice.
static var _resolving_deferred: bool = false


#A weapon perk is active only when the merc owns it and holds a weapon of the type it belongs to.
#A makeshift weapon carries no perk of its own; only the row a spent ReP activated acts.
static func get_active_weapon_perks(merc: MercenaryData) -> Array[TraitData]:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or not merc.weapon_drawn or weapon.is_virtual or weapon.weapon_type == "":
		return []
	var owned: Array[TraitData] = owned_for_key(merc.weapon_perks, weapon_type_key(weapon))
	if weapon.base_weapon == null:
		return owned
	var active_name: String = str(merc.active_states.get("makeshift_perk_active", ""))
	var allowed: Array[TraitData] = []
	if active_name == "":
		return allowed
	for perk: TraitData in owned:
		if perk.trait_name == active_name:
			allowed.append(perk)
	return allowed


#The weapon_trait_library key of a weapon: its type with the parenthesised category dropped.
static func weapon_type_key(weapon: WeaponData) -> String:
	if weapon == null or weapon.weapon_type == "":
		return ""
	return weapon.weapon_type.get_slice(" (", 0).strip_edges()


static func get_weapon_actions(merc: MercenaryData) -> Array[TraitData]:
	return _weapon_perks_by_kind(merc, true)


static func get_weapon_passive_perks(merc: MercenaryData) -> Array[TraitData]:
	return _weapon_perks_by_kind(merc, false)


#Active weapon perks whose token is an action prefix when want_action, and the rest otherwise.
static func _weapon_perks_by_kind(merc: MercenaryData, want_action: bool) -> Array[TraitData]:
	var result: Array[TraitData] = []
	for perk: TraitData in get_active_weapon_perks(merc):
		if (action_dsl(perk) != "") == want_action:
			result.append(perk)
	return result


#The action cell of a perk row, or "" when the row is a passive; SPECIAL rows keep their prefix.
static func action_dsl(perk: TraitData) -> String:
	if perk == null:
		return ""
	for prefix: String in ACTION_PREFIXES:
		if perk.effect_dsl.begins_with(prefix):
			return perk.effect_dsl
	if not perk.effect_dsl.begins_with("SPECIAL: action:"):
		return ""
	for effect: String in SPECIAL_ACTION_EFFECTS:
		if perk.effect_dsl.contains(effect):
			return perk.effect_dsl.trim_prefix("SPECIAL: ")
	return ""


#An armor perk is active only when the merc owns it and wears armor of the type it belongs to.
static func get_active_armor_perks(merc: MercenaryData) -> Array[TraitData]:
	var armor: ArmorData = merc.equipped_armor
	if armor == null or armor.armor_type == "":
		return []
	return owned_for_key(merc.armor_perks, armor.armor_type)


#Owned rows whose gear_key matches the gear in use, deduped by trait_name.
static func owned_for_key(owned: Array[TraitData], key: String) -> Array[TraitData]:
	var result: Array[TraitData] = []
	if key == "":
		return result
	var seen: Dictionary = {}
	for perk: TraitData in owned:
		if perk == null or perk.gear_key != key or seen.has(perk.trait_name):
			continue
		seen[perk.trait_name] = true
		result.append(perk)
	return result


#The one place a weapon perk is added; returns the sheet detail, or "" when nothing was added.
static func grant_weapon_perk(merc: MercenaryData, perk: TraitData, source: String = "") -> String:
	if merc == null or perk == null:
		return ""
	for held: TraitData in merc.weapon_perks:
		if held != null and held.trait_name == perk.trait_name:
			return ""
	merc.weapon_perks.append(perk)
	return _grant_detail("weapon", perk, source)


#The one place an armor perk is added; its permanent tokens apply once, here.
static func grant_armor_perk(merc: MercenaryData, perk: TraitData, source: String = "") -> String:
	if merc == null or perk == null:
		return ""
	for held: TraitData in merc.armor_perks:
		if held != null and held.trait_name == perk.trait_name:
			return ""
	merc.armor_perks.append(perk)
	_apply_permanent_tokens(merc, perk)
	return _grant_detail("armor", perk, source)


#"<kind> <gear key> perk <name>", the shape the level-up log already prints.
static func _grant_detail(kind: String, perk: TraitData, source: String) -> String:
	var detail: String = "%s %s perk %s" % [kind, perk.gear_key, perk_display_name(perk)]
	if source != "":
		detail += " (%s)" % source
	return detail


#Weapon perk names carry their gear key ahead of a "|"; armor perk names do not.
static func perk_display_name(perk: TraitData) -> String:
	if perk == null:
		return ""
	if perk.trait_name.contains("|"):
		return perk.trait_name.get_slice("|", 1)
	return perk.trait_name


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


static func has_armor_perk_active(merc: MercenaryData, token: String) -> bool:
	for perk: TraitData in get_active_armor_perks(merc):
		if perk.effect_dsl.contains(token):
			return true
	return false


#True when an active weapon perk carries a "|"-separated effect token starting with prefix.
static func has_weapon_perk_prefix(merc: MercenaryData, prefix: String) -> bool:
	for perk: TraitData in get_active_weapon_perks(merc):
		for token: String in perk.effect_dsl.split("|"):
			if token.strip_edges().begins_with(prefix):
				return true
	return false


static func has_weapon_passive(merc: MercenaryData, key: String) -> bool:
	for perk: TraitData in get_weapon_passive_perks(merc):
		if perk.effect_dsl.contains(key):
			return true
	return false


#Both hands are on the drawn weapon whenever nothing else occupies the off hand.
static func is_wielding_two_handed(merc: MercenaryData) -> bool:
	if not merc.equipped_weapon or not merc.weapon_drawn:
		return false
	if merc.equipped_weapon.is_virtual:
		return false
	if merc.offhand_weapon != null:
		return false
	if merc.equipped_weapon.misc_properties.has("One-Handed"):
		return false
	return true


#A Protean or unmarked weapon can be held in one hand or two.
static func is_flex_grip(weapon: WeaponData, merc: MercenaryData = null) -> bool:
	if weapon == null or weapon.is_virtual:
		return false
	if weapon.misc_properties.has("One-Handed"):
		return false
	if merc != null and is_protean(merc, weapon):
		return true
	return not weapon.misc_properties.has("Two-Handed")


static func get_two_handed_damage_bonus(merc: MercenaryData, is_thrown: bool = false) -> int:
	if not is_wielding_two_handed(merc):
		return 0
	var prefixes: Array[String] = ["weapon_two_handed:damage:"]
	if is_thrown:
		prefixes.append("weapon_two_handed:thrown_damage:")
	var bonus := 0
	for perk: TraitData in get_weapon_passive_perks(merc):
		for prefix: String in prefixes:
			if not perk.effect_dsl.begins_with(prefix):
				continue
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 3:
				bonus += int(parts[2])
	return bonus


static func get_effective_melee_range(merc: MercenaryData) -> int:
	if not merc.equipped_weapon:
		return 1
	var base: int = merc.equipped_weapon.melee_range
	for perk: TraitData in get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("weapon_stat:melee_range:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 3:
				base += int(parts[2])
	var temp_bonus: int = merc.active_states.get("weapon_stat_melee_range_bonus", 0)
	return base + temp_bonus


#Basic, Great, Specialized or Firearm: the parenthesised category of the weapon type.
static func weapon_tier(weapon: WeaponData) -> String:
	if weapon == null or not weapon.weapon_type.contains("("):
		return ""
	return weapon.weapon_type.get_slice("(", 1).get_slice(")", 0).strip_edges()


#Gear keys the merc holds right now: both hands as weapon keys, the worn armor as the armor key.
static func held_gear_keys(merc: MercenaryData) -> Dictionary:
	var weapon_keys: Array[String] = []
	var armor_keys: Array[String] = []
	if merc == null:
		return {"weapon": weapon_keys, "armor": armor_keys}
	_collect_weapon_keys(merc.equipped_weapon, weapon_keys)
	_collect_weapon_keys(merc.offhand_weapon, weapon_keys)
	if merc.equipped_armor != null and merc.equipped_armor.armor_type != "":
		armor_keys.append(merc.equipped_armor.armor_type)
	return {"weapon": weapon_keys, "armor": armor_keys}


#One weapon's library key, plus the tier Makeshift key when the weapon only imitates a real one.
static func _collect_weapon_keys(weapon: WeaponData, keys: Array[String]) -> void:
	if weapon == null or weapon.is_virtual or weapon.weapon_type == "":
		return
	var key: String = weapon_type_key(weapon)
	if key != "" and not keys.has(key):
		keys.append(key)
	if weapon.base_weapon == null:
		return
	var tier: String = weapon_tier(weapon.base_weapon)
	if not MAKESHIFT_TIERS.has(tier):
		return
	var makeshift_key: String = tier + " Makeshift"
	if not keys.has(makeshift_key):
		keys.append(makeshift_key)


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
	merc.deferred_gear_grants.clear()


#Recomputes the stat sheet when a drawn-weapon bonus (pace, jump) can have changed.
static func refresh_held_bonuses(merc: MercenaryData) -> void:
	if merc == null:
		return
	for perk: TraitData in merc.weapon_perks:
		if perk.effect_dsl.contains("weapon_passive:pace:") or perk.effect_dsl.contains("weapon_passive:jump:"):
			StatCalculator.refresh(merc)
			return


#A grant with no row for any held gear is dropped; the encounter log and the sheet both record it.
static func log_grant_skipped(merc: MercenaryData, token: String) -> void:
	if merc == null:
		return
	var line: String = "PERK GRANT SKIPPED: %s %s (no held gear)" % [merc.merc_name, token]
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose(line)
	merc.level_up_log.append({"level": int(merc.stats.get("level", 0)), "tier": "Gear",
		"option": "perk_grant_skipped", "detail": line})


#EP every spend costs extra while the armor is worn, unless a perk ignores that armor's cost.
static func armor_ep_increase(merc: MercenaryData) -> int:
	if merc == null or merc.equipped_armor == null:
		return 0
	var increase: int = merc.equipped_armor.ep_cost
	if increase <= 0:
		return 0
	if has_armor_perk_active(merc, "armor_ep_ignore:" + merc.equipped_armor.armor_type.to_lower()):
		return 0
	return increase


#Armor Bonus the worn armor still provides after Armor Break; extra Defend dice.
static func effective_armor_bonus(merc: MercenaryData) -> int:
	if merc == null or merc.equipped_armor == null:
		return 0
	return maxi(0, merc.equipped_armor.armor_bonus - merc.armor_break)


#True when the merc wears Heavy or Bulky armor.
static func wears_heavy_armor(merc: MercenaryData) -> bool:
	if merc == null or merc.equipped_armor == null:
		return false
	return HEAVY_ARMOR_TYPES.has(merc.equipped_armor.armor_type)


#Flaws the attacker's weapon adds to the defender's Defend and Dodge rolls.
static func defense_flaws_against(attacker: MercenaryData, defender: MercenaryData) -> int:
	if attacker == null or not wears_heavy_armor(defender):
		return 0
	if has_weapon_passive(attacker, "pierce_heavy_armor"):
		return 1
	return 0


#Armor Bonus an Armor Break row takes off when a pain response fires against heavy armor.
static func armor_break_amount(attacker: MercenaryData, defender: MercenaryData) -> int:
	if attacker == null or not wears_heavy_armor(defender):
		return 0
	for perk: TraitData in get_weapon_passive_perks(attacker):
		var idx: int = perk.effect_dsl.find(ARMOR_BREAK_TOKEN)
		if idx < 0:
			continue
		var tail: String = perk.effect_dsl.substr(idx + ARMOR_BREAK_TOKEN.length())
		return maxi(1, int(tail.get_slice(":", 0)))
	return 0


#Threshold points the drawn weapon's passives add to every attack made with it.
static func attack_threshold_bonus(merc: MercenaryData) -> float:
	var total: float = 0.0
	if merc == null:
		return total
	for perk: TraitData in get_weapon_passive_perks(merc):
		for token: String in perk.effect_dsl.split("|"):
			var t: String = token.strip_edges()
			if t.begins_with("weapon_passive:attack_threshold:"):
				total += float(t.get_slice(":", 2).replace("+", ""))
	return total


static func is_level_20(merc: MercenaryData) -> bool:
	return merc != null and int(merc.stats.get("level", 0)) >= 20


#Stat var name -> amount the drawn weapon's passives add; StatCalculator folds it in.
static func held_stat_bonuses(merc: MercenaryData) -> Dictionary:
	var bonuses: Dictionary = {}
	if merc == null:
		return bonuses
	for perk: TraitData in get_weapon_passive_perks(merc):
		for token: String in perk.effect_dsl.split("|"):
			var t: String = token.strip_edges()
			if not t.begins_with("weapon_passive:"):
				continue
			var key: String = t.get_slice(":", 1)
			if key != "pace" and key != "jump":
				continue
			var amount: int = int(t.get_slice(":", 2).replace("+", ""))
			#Glaive Vault is the only jump row and it doubles at 20th level.
			if key == "jump" and amount > 0 and is_level_20(merc):
				amount = 2
			bonuses[key] = int(bonuses.get(key, 0)) + amount
	return bonuses


#Intended and extended ranged bands of a held weapon after the perks that move them.
static func ranged_ranges(merc: MercenaryData, weapon: WeaponData) -> Dictionary:
	var out: Dictionary = {"intended": 0, "extended": 0}
	if weapon == null:
		return out
	out["intended"] = weapon.ranged_intended_range
	out["extended"] = weapon.ranged_extended_range
	if merc == null:
		return out
	if merc.aim_active and has_weapon_passive(merc, "aimed_doubled_range"):
		out["intended"] = weapon.ranged_intended_range * 2
		out["extended"] = weapon.ranged_extended_range * 2
	#Crook-Shot narrows the extended band on a one-handed rifle.
	if held_one_handed_by_perk(merc, weapon):
		out["extended"] = out["intended"]
	return out


#Paces a melee strike reaches, the Halberd Extension pace included while its EP is spendable.
static func melee_reach(attacker: MercenaryData) -> int:
	var weapon := attacker.equipped_weapon
	if weapon == null:
		return AutoBattle.MELEE_RANGE
	return get_effective_melee_range(attacker) + _perk_reach_bonus(attacker)


#Halberd Extension: the decision counts one extra pace while the EP for it is still spendable.
static func _perk_reach_bonus(attacker: MercenaryData) -> int:
	if attacker.active_states.has("weapon_stat_melee_range_bonus"):
		return 0
	var weapon: WeaponData = attacker.equipped_weapon
	if weapon == null or weapon.is_ranged:
		return 0
	if not has_weapon_passive(attacker, "weapon_stat:melee_range:+1"):
		return 0
	var cost := CombatApplicator.state_ep_cost(attacker, 1, "reaction", 0)
	return 1 if cost > 0 and ExcessPool.available_ep(attacker) >= cost else 0


#Spear Launcher: the decision counts the +10 band while the EP for it is still spendable.
static func perk_throw_bonus(attacker: MercenaryData) -> int:
	if attacker.active_states.has("thrown_extended_range_bonus"):
		return 0
	if not has_weapon_passive(attacker, "weapon_stat:thrown_extended_range:+10"):
		return 0
	var cost := CombatApplicator.state_ep_cost(attacker, 1, "reaction", 0)
	return 10 if cost > 0 and ExcessPool.available_ep(attacker) >= cost else 0


#A Protean weapon can change grip mid-fight: the misc property or the Multigrip passive.
static func is_protean(merc: MercenaryData, weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	if weapon.misc_properties.has("Protean"):
		return true
	if merc == null or merc.equipped_weapon != weapon:
		return false
	return has_weapon_passive(merc, "weapon_passive:protean")


#Scythe Mow sets the extend flag for the rest of the merc's turn.
static func has_extend(merc: MercenaryData, weapon: WeaponData) -> bool:
	if weapon != null and weapon.misc_properties.has("Extend"):
		return true
	if merc == null:
		return false
	return bool(merc.active_states.get("weapon_extend_active", false))


#True while a Crook-Shot rifle is actually held in one hand, the off hand being busy.
static func held_one_handed_by_perk(merc: MercenaryData, weapon: WeaponData) -> bool:
	if merc == null or weapon == null or merc.equipped_weapon != weapon or not merc.weapon_drawn:
		return false
	if not weapon.misc_properties.has("Two-Handed") or merc.offhand_weapon == null:
		return false
	return has_weapon_passive(merc, "weapon_passive:one_handed:allowed")


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
	if _pool_needs_gear(pool) and WeaponArmorPerkLibrary.defer_gear_grant(merc, token, source_name):
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
		WeaponArmorPerkLibrary.log_grant_skipped(merc, token)
		return
	choices.shuffle()
	for i: int in range(mini(count, choices.size())):
		var drawn: TraitData = choices[i]
		match drawn.trait_source:
			"Weapon":
				WeaponArmorPerkLibrary.grant_weapon_perk(merc, drawn, source_name)
				TraitDSL.apply_dsl_to_merc(merc, drawn.effect_dsl, drawn.trait_name)
			"Armor":
				WeaponArmorPerkLibrary.grant_armor_perk(merc, drawn, source_name)
			_:
				MercGenerator.assign_trait(merc, drawn)
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
	if WeaponArmorPerkLibrary.defer_gear_grant(merc, token, source_name):
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
		WeaponArmorPerkLibrary.log_grant_skipped(merc, token)
		return
	choices.shuffle()
	for i: int in range(mini(count, choices.size())):
		if kind == "weapon":
			WeaponArmorPerkLibrary.grant_weapon_perk(merc, choices[i], source_name)
		else:
			WeaponArmorPerkLibrary.grant_armor_perk(merc, choices[i], source_name)
