class_name WeaponEvaluator

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


static func _pace_per_move(merc: MercenaryData) -> int:
	var pace := maxi(1, int(merc.stats.get("pace", 1)))
	if ConstStates.has_state(merc, ConstStates.DEPOSED):
		pace = mini(pace, 1)
	return pace


static func melee_reach_for(merc: MercenaryData, weapon: WeaponData) -> int:
	if weapon == null:
		return 1
	if merc.equipped_weapon == weapon:
		return WeaponArmorPerkLibrary.get_effective_melee_range(merc)
	return maxi(1, weapon.melee_range)


#Fight never counts: a backup is a real weapon the merc can bring to hand once the throw is gone.


#Fight never counts: a backup is a real weapon the merc can bring to hand once the throw is gone.
static func has_backup_weapon(merc: MercenaryData, thrown: WeaponData) -> bool:
	var fight: WeaponData = DataManager.fight_weapon
	var pool: Array[WeaponData] = []
	if merc.offhand_weapon != null:
		pool.append(merc.offhand_weapon)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			var w: WeaponData = entry.get("data") as WeaponData
			if w != null:
				pool.append(w)
	for w: WeaponData in pool:
		if w == thrown or w == fight or w.is_virtual:
			continue
		if WeaponActionExecutor.hands_needed(w) <= 2:
			return true
	return false


#A Protean weapon gains its extra die only when the off hand ends up empty.
static func _offhand_free_for(merc: MercenaryData, weapon: WeaponData) -> bool:
	if merc.offhand_weapon == null or merc.offhand_weapon == weapon:
		return true
	return WeaponActionExecutor.needs_free_hands(merc, weapon)


#A ranged weapon is usable when the merc can feed it and it is not too likely to jam.


#A ranged weapon is usable when the merc can feed it and it is not too likely to jam.
static func is_ranged_usable(merc: MercenaryData, weapon: WeaponData) -> bool:
	if weapon == null or not weapon.is_ranged:
		return false
	var has_ammo := false
	if merc.equipped_weapon == weapon:
		has_ammo = merc.ammo_loaded > 0 \
				or int(merc.ammo_inventory.get(merc.ammo_loaded_type, 0)) > 0
	else:
		for ammo_type: String in merc.ammo_inventory:
			if (merc.ammo_inventory[ammo_type] as int) <= 0:
				continue
			var ammo_data: AmmoData = DataManager.ammo.get(ammo_type)
			if ammo_data != null and ammo_data.compatible.has(weapon.weapon_type):
				has_ammo = true
				break
	if not has_ammo:
		return false
	if weapon.misfire > 0 and _reliability_of(merc, weapon) < 0.50:
		return false
	return true


static func _reliability_of(merc: MercenaryData, weapon: WeaponData) -> float:
	var p := clampf(float(merc.stats.get("ranged_accuracy", 0.0)) / 100.0, 0.0, 1.0)
	var dice := int(maxf(1.0, maxf(
			maxf(0.0, float(merc.stats.get("dexterity", 0))),
			maxf(0.0, float(merc.stats.get("vigor", 0))))))
	var k := int(weapon.misfire)
	var raw := 0.0 if dice < k else FirearmReliabilityFacet.prob_at_least_k(dice, k, p)
	return FirearmReliabilityFacet.aimed_score(raw)


static func score_weapon(
		weapon: WeaponData,
		merc: MercenaryData,
		enemies: Array,
		state: BattleState,
		movement_blocked: bool = false,
		force_closest_dist: int = -1,
		ranged_plan: Dictionary = {},
		allow_two_hand_die: bool = true) -> float:
	if weapon.is_ranged and not is_ranged_usable(merc, weapon):
		return -999.0

	if state.battlefield == null or enemies.is_empty():
		return 0.0

	var closest_dist := 999999
	if force_closest_dist >= 0:
		closest_dist = force_closest_dist
	else:
		for enemy: MercenaryData in enemies:
			var d := state.distance_to(merc, enemy)
			if d < closest_dist:
				closest_dist = d

	var score := 0.0
	var damage_fragility_handled := false
	if closest_dist <= 2:
		if not weapon.is_ranged:
			var avg_dmg := parse_formula_for_avg(weapon.damage_formula_1)
			if avg_dmg > 0.0 and float(merc.stats.get("melee_accuracy", 0.0)) >= 1.0:
				score += 2.0
			if avg_dmg > 0.0:
				var acc := clampf(float(merc.stats.get("melee_accuracy", 50.0)) / 100.0, 0.01, 1.0)
				var max_dmg := avg_dmg * 2.0
				var weighted_per_use := 0.85 * (acc * avg_dmg) + 0.15 * max_dmg
				if allow_two_hand_die and WeaponArmorPerkLibrary.is_flex_grip(weapon) \
						and _offhand_free_for(merc, weapon):
					var flex := AttackSystem._parse_damage_formula(weapon.damage_formula_1)
					if not bool(flex["is_todo"]):
						weighted_per_use += 0.85 * acc * (float(flex["die_sides"]) + 1.0) / 2.0
				var uses := 6.0 if weapon.fragility <= 0 \
						else clampf(float(weapon.current_fragility), 1.0, 6.0)
				score += clampf(weighted_per_use * uses / 2.5, 0.0, 2.0)
				damage_fragility_handled = true
		else:
			#Within 2 paces the shot carries the Threatened Flaw; it scores by what it yields over the merc's punch.
			var flaws := 1
			if weapon == merc.equipped_weapon and WeaponArmorPerkLibrary.has_weapon_passive(merc, "weapon_passive:ignore_threatened"):
				flaws = 0
			var shot := expected_attack_damage(merc, weapon, flaws)
			var punch := expected_attack_damage(merc, DataManager.fight_weapon, 0)
			score += clampf(shot - punch, -1.0, 1.0)
	else:
		if weapon.is_ranged:
			var in_range := 0
			var in_intended := 0
			for enemy: MercenaryData in enemies:
				var d := state.distance_to(merc, enemy)
				if weapon.ranged_extended_range <= 0 or d <= weapon.ranged_extended_range:
					in_range += 1
				if weapon.ranged_intended_range <= 0 or d <= weapon.ranged_intended_range:
					in_intended += 1
			var ranged_avg_dmg := parse_formula_for_avg(weapon.damage_formula_1)
			var dmg_factor := clampf(ranged_avg_dmg / 7.0, 0.1, 2.0)
			score += 1.5 * float(in_range) * dmg_factor
			var melee_acc_r := maxf(1.0, float(merc.stats.get("melee_accuracy", 50.0)))
			var ranged_acc_r := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
			score *= clampf(ranged_acc_r / melee_acc_r, 0.1, 2.0)
			score -= 0.4 * float(in_range - in_intended)
			if weapon.misfire > 0:
				var misfire_risk: float = clampf(float(weapon.misfire) * 0.35, 0.0, 2.5)
				var accuracy_factor: float = clampf(1.0 - ranged_acc_r / 100.0, 0.0, 1.0)
				score -= misfire_risk * (0.3 + accuracy_factor * 0.7)
		elif weapon.is_throwable:
			var throw_avg := parse_formula_for_avg(weapon.damage_formula_1)
			var throw_acc := clampf(ThrownWeaponRules.compute_thrown_accuracy(merc, weapon) / 100.0, 0.01, 1.0)
			var weighted_throw := 0.85 * (throw_acc * throw_avg) + 0.15 * (throw_avg * 2.0)
			var throw_uses := 6.0 if weapon.fragility <= 0 \
					else clampf(float(weapon.current_fragility), 1.0, 6.0)
			var throw_dmg_score: float = clampf(weighted_throw * throw_uses / 2.5, 0.0, 2.0) \
					* ThrownWeaponRules._throw_replacement_factor(merc, weapon, state)
			var t_ranges := ThrownWeaponRules.thrown_ranges(merc, weapon)
			var ext_range: int = int(t_ranges["extended"])
			var int_range: int = int(t_ranges["intended"])
			if int_range <= 0:
				int_range = ext_range
			for enemy: MercenaryData in enemies:
				var d := state.distance_to(merc, enemy)
				if ext_range <= 0 or d > ext_range:
					continue
				var range_factor: float
				if d <= int_range:
					range_factor = 1.0
				else:
					range_factor = clampf(1.0 - 0.6 * float(d - int_range) / maxf(1.0, float(ext_range - int_range)), 0.4, 1.0)
				score += throw_dmg_score * range_factor
			damage_fragility_handled = true
		else:
			var pace := maxf(1.0, float(merc.stats.get("pace", 1)))
			var turns_to_close := float(closest_dist) / pace
			if movement_blocked:
				turns_to_close *= 3.0
			var dist_factor := clampf((turns_to_close - 1.0) / 4.0, 0.0, 2.0)
			var melee_acc := maxf(1.0, float(merc.stats.get("melee_accuracy", 50.0)))
			var ranged_acc := maxf(0.0, float(merc.stats.get("ranged_accuracy", 0.0)))
			var ranged_aptitude := clampf(ranged_acc / melee_acc, 0.0, 3.0)
			score -= dist_factor * ranged_aptitude
			var melee_preference := clampf(1.0 - ranged_aptitude, 0.0, 1.0)
			var reachability := clampf(1.0 - (turns_to_close - 1.0) / 5.0, 0.0, 1.0)
			score += melee_preference * reachability * 2.0
			var melee_avg_dmg := parse_formula_for_avg(weapon.damage_formula_1)
			var best_ranged_avg := 0.0
			for w: WeaponData in get_available_weapons(merc):
				if w.is_ranged:
					best_ranged_avg = maxf(best_ranged_avg, parse_formula_for_avg(w.damage_formula_1))
			if melee_avg_dmg > 0.0 or best_ranged_avg > 0.0:
				var dmg_ratio := (melee_avg_dmg - best_ranged_avg) / maxf(1.0, melee_avg_dmg + best_ranged_avg)
				score += clampf(dmg_ratio * 1.5, -0.5, 1.5) * reachability
	var all_types: Array = weapon.damage_types_1.duplicate()
	all_types.append_array(weapon.damage_types_2)
	if not all_types.is_empty() and not enemies.is_empty():
		var type_total := 0.0
		for enemy: MercenaryData in enemies:
			type_total += score_type_vs_enemy(all_types, enemy, merc)
		score += type_total / float(enemies.size())

	if not damage_fragility_handled and weapon.fragility > 0 and weapon.current_fragility > 0:
		var frag_ratio := float(weapon.current_fragility) / float(weapon.fragility)
		score += frag_ratio * 0.5

	#A ranged weapon still to be taken up is worth its score only once a firing stance exists.
	if weapon.is_ranged and _needs_draw_plan(merc, weapon):
		var rp := ranged_plan
		if rp.is_empty():
			rp = RangedDrawPlanner.plan(merc, weapon, enemies, state, _CONFIG.attack_base_ap)
		var mode := str(rp.get("mode", "now"))
		if mode == "none":
			return -900.0
		if mode != "now":
			score -= float(maxi(1, int(rp.get("turns", 1))))

	return score


#Expected damage of one attack: core dice and weapon dice at the accuracy, one core die lost per Flaw.


#Expected damage of one attack: core dice and weapon dice at the accuracy, one core die lost per Flaw.
static func expected_attack_damage(merc: MercenaryData, weapon: WeaponData, flaws: int) -> float:
	var ranged := weapon != null and weapon.is_ranged
	var acc_key := "ranged_accuracy" if ranged else "melee_accuracy"
	var acc := clampf(float(merc.stats.get(acc_key, 0)) / 100.0, 0.0, 1.0)
	var core := maxi(0, AttackSystem.attack_pool_size(merc, weapon) - flaws)
	var parsed := AttackSystem._parse_damage_formula(weapon.damage_formula_1 if weapon != null else "")
	var dice := 0 if bool(parsed["is_todo"]) else int(parsed["num_dice"])
	return (float(core) + float(dice)) * acc + float(parsed["flat_bonus"])


#True for a carried ranged weapon that is not already in the main hand.


#True for a carried ranged weapon that is not already in the main hand.
static func _needs_draw_plan(merc: MercenaryData, weapon: WeaponData) -> bool:
	if merc.equipped_weapon == weapon and merc.weapon_drawn:
		return false
	if merc.offhand_weapon == weapon:
		return true
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon" and entry.get("data") == weapon:
			return true
	return merc.equipped_weapon == weapon


#A Thrown-property off-hand weapon earns its place when it can answer an enemy out of melee reach.
static func _thrown_complement(merc: MercenaryData, candidate: WeaponData, enemies: Array,
		state: BattleState) -> bool:
	if candidate == null or not candidate.is_throwable or state == null or state.battlefield == null:
		return false
	var reach := melee_reach_for(merc, candidate)
	var ext: int = int(ThrownWeaponRules.thrown_ranges(merc, candidate)["extended"])
	for e: MercenaryData in enemies:
		if not BattleState._is_alive(e):
			continue
		var d := state.distance_to(merc, e)
		if d > reach and d <= ext and (LineOfSight.check(state, merc, e)["visible"] as bool):
			return true
		if bool(ThrownWeaponRules.should_throw(merc, candidate, e, enemies, state, false)["throw"]):
			return true
	return false


static func _best_available_weapon(
		merc: MercenaryData,
		enemies: Array,
		state: BattleState,
		movement_blocked: bool = false) -> WeaponData:
	var available := get_available_weapons(merc)
	if available.is_empty():
		return null
	var best: WeaponData = null
	var best_score := -9999.0
	for weapon: WeaponData in available:
		var s := score_weapon(weapon, merc, enemies, state, movement_blocked)
		if s > best_score:
			best_score = s
			best = weapon
	return best


static func _has_reserve_for(merc: MercenaryData, weapon: WeaponData) -> bool:
	if not weapon.is_ranged:
		return false
	if merc.ammo_loaded_type != "" and int(merc.ammo_inventory.get(merc.ammo_loaded_type, 0)) > 0:
		return true
	for ammo_type: String in merc.ammo_inventory:
		if int(merc.ammo_inventory[ammo_type]) <= 0:
			continue
		var ammo_data: AmmoData = DataManager.ammo.get(ammo_type)
		if ammo_data != null and ammo_data.compatible.has(weapon.weapon_type):
			return true
	return false


static func _enemy_in_melee_reach(merc: MercenaryData, enemies: Array, state: BattleState) -> bool:
	if state.battlefield == null:
		return false
	for enemy: MercenaryData in enemies:
		if state.distance_to(merc, enemy) <= 1:
			return true
	return false


static func get_available_weapons(merc: MercenaryData) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	if merc.equipped_weapon != null:
		result.append(merc.equipped_weapon)
	if merc.offhand_weapon != null and not result.has(merc.offhand_weapon):
		result.append(merc.offhand_weapon)
	for entry: Dictionary in merc.inventory:
		if entry.get("type") == "weapon":
			var w: WeaponData = entry.get("data")
			if w != null:
				result.append(w)
	var fight: WeaponData = DataManager.fight_weapon
	if fight != null and not result.has(fight):
		result.append(fight)
	return result


#Average damage of an "NdS + F" formula; 0.0 for an unauthored formula.
static func parse_formula_for_avg(formula: String) -> float:
	var parsed := AttackSystem._parse_damage_formula(formula)
	return float(parsed["flat_bonus"]) 		+ float(parsed["num_dice"]) * float(parsed["die_sides"]) * 0.5


#Returns a [-1.0, ~0.8] score for how well damage_types exploit this enemy's profile.
#Negative = bad matchup (immune, protected by state); positive = good matchup.
#Averages across all types in the list so multi-type weapons aren't over-rewarded.
#Only passive tokens the viewer's team already knows about count toward the score.


#Returns a [-1.0, ~0.8] score for how well damage_types exploit this enemy's profile.
#Negative = bad matchup (immune, protected by state); positive = good matchup.
#Averages across all types in the list so multi-type weapons aren't over-rewarded.
#Only passive tokens the viewer's team already knows about count toward the score.
static func score_type_vs_enemy(damage_types: Array, enemy: MercenaryData, viewer: MercenaryData) -> float:
	if damage_types.is_empty():
		return 0.0
	var total := 0.0
	for dtype: String in damage_types:
		total += _score_single_type(dtype, enemy, viewer)
	return total / float(damage_types.size())


static func _score_single_type(dtype: String, enemy: MercenaryData, viewer: MercenaryData) -> float:
	var score := 0.0
	var type_lower := dtype.to_lower()

	#Passive effects (traits, armor protection): immune / susceptible / protected
	for effect: String in enemy.passive_effects:
		if not BattleState.knows(viewer, enemy, effect):
			continue
		if effect == "immune:" + type_lower:
			return -1.0
		elif effect == "susceptible:" + type_lower:
			score += 0.6
		elif effect == "protected:" + type_lower:
			score -= 0.3

	#State-based interactions
	match dtype:
		"Toxic":
			if ConstStates.has_state(enemy, ConstStates.POISONED):
				score += 0.5
		"Sonic":
			if ConstStates.has_state(enemy, ConstStates.DEAFENED):
				score -= 0.4
		"Fire":
			if ConstStates.has_state(enemy, ConstStates.DRENCHED):
				score -= 0.3
		"Will":
			#Will cannot reduce HP below 1, so it is poor for finishing off low-HP targets
			var max_hp := int(enemy.stats.get("maximum_hit_points", 1))
			if float(enemy.current_hp) / float(maxi(1, max_hp)) < 0.25:
				score -= 0.5

	#Defense-profile manipulation: reward types that counter how this enemy actually defends
	var defend := float(enemy.stats.get("defend_reduction", 0))
	var dodge := float(enemy.stats.get("dodge_reduction", 0))
	var total_def := defend + dodge
	if total_def > 0.0:
		var defend_ratio := defend / total_def
		var dodge_ratio  := dodge  / total_def
		match dtype:
			"Acid":     score += 0.4  * defend_ratio
			"Holy":     score += 0.4  * dodge_ratio
			"Strike":   score += 0.25 * defend_ratio
			"Impale":   score += 0.2  * defend_ratio
			"Lacerate": score += 0.2  * dodge_ratio

	return score
