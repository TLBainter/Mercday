class_name WeaponArmorPerkLibrary

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


#Weapon perk names carry their gear key ahead of a "|"; armor perk names do not.
static func perk_display_name(perk: TraitData) -> String:
	if perk == null:
		return ""
	if perk.trait_name.contains("|"):
		return perk.trait_name.get_slice("|", 1)
	return perk.trait_name


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


#Sum of the third ":" field over the weapon passives whose token starts with prefix.
static func sum_passive_int(merc: MercenaryData, prefix: String) -> int:
	var total := 0
	for perk: TraitData in get_weapon_passive_perks(merc):
		if not perk.effect_dsl.begins_with(prefix):
			continue
		var parts := perk.effect_dsl.split(":")
		if parts.size() >= 3:
			total += int(parts[2])
	return total


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
	for prefix: String in prefixes:
		bonus += sum_passive_int(merc, prefix)
	return bonus


static func get_effective_melee_range(merc: MercenaryData) -> int:
	if not merc.equipped_weapon:
		return 1
	var base: int = merc.equipped_weapon.melee_range + sum_passive_int(merc, "weapon_stat:melee_range:")
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


#Recomputes the stat sheet when a drawn-weapon bonus (pace, jump) can have changed.
static func refresh_held_bonuses(merc: MercenaryData) -> void:
	if merc == null:
		return
	for perk: TraitData in merc.weapon_perks:
		if perk.effect_dsl.contains("weapon_passive:pace:") or perk.effect_dsl.contains("weapon_passive:jump:"):
			StatCalculator.refresh(merc)
			return


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
	var weapon: WeaponData = attacker.equipped_weapon
	if weapon == null or weapon.is_ranged:
		return 0
	return 1 if _ep_gated_passive(attacker, "weapon_stat_melee_range_bonus", "weapon_stat:melee_range:+1") else 0


#Spear Launcher: the decision counts the +10 band while the EP for it is still spendable.
static func perk_throw_bonus(attacker: MercenaryData) -> int:
	return 10 if _ep_gated_passive(attacker, "thrown_extended_range_bonus", "weapon_stat:thrown_extended_range:+10") else 0


#True while the bonus flag is not yet set, the passive is held and the 1 EP it costs is still spendable.
static func _ep_gated_passive(attacker: MercenaryData, flag: String, token: String) -> bool:
	if attacker.active_states.has(flag) or not has_weapon_passive(attacker, token):
		return false
	var cost := CombatApplicator.state_ep_cost(attacker, 1, "reaction", 0)
	return cost > 0 and ExcessPool.available_ep(attacker) >= cost


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


#Harness: every combatant gains N weapon perks and 1 armor perk for the gear it holds
static var force_perk_load: int = 0


#Harness only: fills a combatant with perks for the gear it already holds, once per merc.
static func load_gear_perks(merc: MercenaryData, count: int) -> Array[String]:
	var details: Array[String] = []
	if merc == null or count <= 0 or merc.has_meta("perk_load_done"):
		return details
	merc.set_meta("perk_load_done", true)
	var keys: Dictionary = held_gear_keys(merc)
	var before_w: int = merc.weapon_perks.size()
	var before_a: int = merc.armor_perks.size()
	if not (keys["weapon"] as Array).is_empty():
		PerkGrants.grant_gear_perks(merc, "weapon", "", count, "harness:perk_load", "harness")
	if not (keys["armor"] as Array).is_empty():
		PerkGrants.grant_gear_perks(merc, "armor", "", 1, "harness:perk_load", "harness")
	for td: TraitData in merc.weapon_perks.slice(before_w):
		if td != null:
			details.append("weapon %s perk %s" % [td.gear_key, perk_display_name(td)])
	for td: TraitData in merc.armor_perks.slice(before_a):
		if td != null:
			details.append("armor %s perk %s" % [td.gear_key, perk_display_name(td)])
	return details
