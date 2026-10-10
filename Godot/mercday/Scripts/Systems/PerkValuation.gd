class_name PerkValuation

#The one valuation behind the perk action choice, the reaction EP gate and the perk spend gates.

const EP_RESERVE: int = 1
const EP_WEIGHT: float = 1.5
const REP_WEIGHT: float = 1.0
const KILL_VALUE: float = 3.0
const LAST_ENEMY_VALUE: float = 5.0
const PUSH_VALUE: float = 0.5
const REACH_VALUE: float = 1.0
const REACH_IDLE_VALUE: float = 0.25
const TERROR_ODDS: float = 0.5
const SNAP_PENALTY: float = 4.0

const STATE_VALUES: Dictionary = {
	"Deposed": 2.0,
	"Terrified": 2.0,
	"Grappled": 1.5,
	"Vulnerable": 1.5,
	"Slowed": 1.0,
	"Distracted": 1.0,
	"Flanked": 1.0,
	"Shocked": 3.0,
	"Blinded": 1.5,
	"Grounded": 1.5,
	"Hobbled": 0.75,
	"Deafened": 0.5,
	"Mute": 0.5,
}

#Cost tokens and conditions the action parser walks past to reach the effect token.
const SKIP_TOKENS: Array[String] = ["once_per_combat", "two_handed"]


#What one swing is worth against this target once the defence it can raise is taken off.
static func expected_damage(merc: MercenaryData, target: MercenaryData, weapon: WeaponData = null,
		enhancements: int = 0, flaws: int = 0, state: BattleState = null) -> float:
	if merc == null:
		return 0.0
	var w: WeaponData = weapon if weapon != null else merc.equipped_weapon
	var hit := hit_chance(merc, target, w, enhancements, flaws, state)
	return maxf(0.0, hit * raw_damage(merc, w, flaws) - expected_defense(target))


#The attack check as AttackSystem builds it, asked for its chance of one success.
static func hit_chance(merc: MercenaryData, target: MercenaryData, weapon: WeaponData,
		enhancements: int = 0, flaws: int = 0, state: BattleState = null) -> float:
	if merc == null:
		return 0.0
	return CheckSystem.expected_success_chance(merc,
		attack_check_def(merc, target, weapon, enhancements, flaws, state), 1)


#The attack check def AttackSystem would build for this swing.
static func attack_check_def(merc: MercenaryData, target: MercenaryData, weapon: WeaponData,
		enhancements: int = 0, flaws: int = 0, state: BattleState = null) -> Dictionary:
	if merc == null:
		return {}
	var is_ranged: bool = weapon != null and weapon.is_ranged
	var total_flaws := flaws
	if state != null and state.battlefield != null and target != null:
		total_flaws += AttackSystem.compute_attack_flaws(merc, target, state)
	return AttackSystem.attack_check_def(weapon, false, is_ranged, enhancements + AttackSystem.get_weapon_enhance_bonus(merc),
		total_flaws, WeaponArmorPerkLibrary.attack_threshold_bonus(merc))


#Core dice plus weapon dice, then the formula's flat bonus, as a two-entry list.
static func damage_dice(merc: MercenaryData, weapon: WeaponData, flaws: int) -> Array[float]:
	var core := maxi(0, AttackSystem.attack_pool_size(merc, weapon) - flaws)
	var parsed := AttackSystem.parse_damage_formula(weapon.damage_formula_1 if weapon != null else "")
	var dice := 0 if bool(parsed["is_todo"]) else int(parsed["num_dice"])
	return [float(core) + float(dice), float(parsed["flat_bonus"])]


#Core dice plus weapon dice plus the flat bonus, before the accuracy is applied.
static func raw_damage(merc: MercenaryData, weapon: WeaponData, flaws: int = 0) -> float:
	if merc == null:
		return 0.0
	var parts := damage_dice(merc, weapon, flaws)
	return parts[0] + parts[1]


#Mean Defend successes the target would land, armor dice included.
static func expected_defense(target: MercenaryData) -> float:
	if target == null:
		return 0.0
	return CheckSystem.expected_successes(target, defend_check_def(target))


#The Defend check DefenseSystem.resolve rolls for this target, armor dice included.
static func defend_check_def(target: MercenaryData, flaws: int = 0, enhancements: int = 0) -> Dictionary:
	return {
		"stat_keys": ["defend_reduction"],
		"circumstances": [],
		"knowledges": [],
		"tools": [],
		"formula": "defend",
		"enhancements": enhancements,
		"flaws": flaws,
		"dice_bonus": WeaponArmorPerkLibrary.effective_armor_bonus(target),
		"flat_threshold_bonus": 0.0,
	}


#The Dodge check DefenseSystem.resolve rolls beside the Defend check.
static func dodge_check_def(_target: MercenaryData, flaws: int = 0, enhancements: int = 0) -> Dictionary:
	return {
		"stat_keys": ["dodge_reduction"],
		"circumstances": [],
		"knowledges": [],
		"tools": [],
		"formula": "dodge",
		"enhancements": enhancements,
		"flaws": flaws,
	}


#Successes the weapon dice add beside the core roll, at the attack check's threshold, and the flat bonus.
static func weapon_die_distribution(weapon: WeaponData, threshold: float) -> Dictionary:
	var out := {"pmf": [1.0] as Array[float], "flat": 0}
	if weapon == null:
		return out
	var parsed := AttackSystem.parse_damage_formula(weapon.damage_formula_1)
	out["flat"] = int(parsed["flat_bonus"])
	if bool(parsed["is_todo"]):
		return out
	var sides := int(parsed["die_sides"])
	var per_die := float(floori(threshold / 100.0 * float(sides))) / float(maxi(1, sides))
	out["pmf"] = CheckSystem.binomial_distribution(int(parsed["num_dice"]), per_die)
	return out


#What putting this state on this target is worth, scaled by the threat the target poses.
static func state_value(state_name: String, target: MercenaryData, merc: MercenaryData = null,
		state: BattleState = null) -> float:
	var base := float(STATE_VALUES.get(state_name, 0.0))
	if base <= 0.0:
		return 0.0
	return base * clampf(threat_of(target, merc, state) / 3.0, 0.5, 2.0)


#The damage the target is expected to do back to the merc.
static func threat_of(target: MercenaryData, merc: MercenaryData, state: BattleState) -> float:
	if target == null:
		return 0.0
	return expected_damage(target, merc, target.equipped_weapon, 0, 0, state)


#What taking this target off the field is worth.
static func kill_value(target: MercenaryData, state: BattleState) -> float:
	if target == null:
		return 0.0
	var value := KILL_VALUE
	if is_last_enemy(target, state):
		value += LAST_ENEMY_VALUE
	return value


static func is_last_enemy(target: MercenaryData, state: BattleState) -> bool:
	if target == null or state == null:
		return false
	for other: MercenaryData in state.get_allies(target):
		if other != target and BattleState._is_alive(other) and not other.off_field:
			return false
	return true


#Cost prefix and effect token of an "action:" row.
static func parse_action(perk: TraitData) -> Dictionary:
	var out: Dictionary = {"ap": 99, "ep": 0, "rep": 0, "effect": "", "effect_start": 2,
		"parts": PackedStringArray()}
	var dsl := WeaponArmorPerkLibrary.action_dsl(perk)
	if dsl == "" or not dsl.begins_with("action:"):
		return out
	var parts := dsl.split(":")
	out["parts"] = parts
	out["ap"] = int(parts[1]) if parts.size() > 1 else 99
	var j := 2
	while j < parts.size():
		if parts[j] == "ep" and j + 1 < parts.size():
			out["ep"] = int(parts[j + 1])
			j += 2
		elif parts[j] == "rep" and j + 1 < parts.size():
			out["rep"] = int(parts[j + 1])
			j += 2
		elif parts[j] in SKIP_TOKENS:
			j += 1
		else:
			break
	out["effect_start"] = j
	out["effect"] = parts[j] if parts.size() > j else ""
	return out


#The worth of one perk action, its costs and its worth per AP.
static func action_score(merc: MercenaryData, perk: TraitData, target: MercenaryData,
		state: BattleState) -> Dictionary:
	var info := parse_action(perk)
	var out: Dictionary = {"score": 0.0, "score_per_ap": 0.0, "ok": false,
		"ap": int(info["ap"]), "ep": int(info["ep"]), "rep": int(info["rep"]), "perk": perk}
	if merc == null or perk == null or state == null or int(info["ap"]) > 90:
		return out
	if not _affordable(merc, state, info):
		return out
	if not _feasible(merc, perk, info, target, state):
		return out
	var value := effect_value(merc, perk, info, target, state)
	if value <= 0.0:
		return out
	var score := value - EP_WEIGHT * float(info["ep"]) - REP_WEIGHT * float(info["rep"])
	out["ok"] = true
	out["score"] = score
	out["score_per_ap"] = score / float(maxi(1, int(info["ap"])))
	return out


#The action is only taken while its worth per AP beats what a plain attack buys with the same AP.
static func beats_attack(merc: MercenaryData, scored: Dictionary, target: MercenaryData,
		state: BattleState, enhancements: int = 0, ap_reduction: int = 0) -> bool:
	if merc == null or scored.is_empty():
		return false
	var plain := 0.0
	if target != null and state != null:
		var cost := maxi(1, state.get_cost(merc, "Attack", AutoBattle.ATTACK_BASE_AP) - ap_reduction)
		plain = expected_damage(merc, target, merc.equipped_weapon, enhancements, 0, state) / float(cost)
	return float(scored.get("score_per_ap", 0.0)) > plain


static func _affordable(merc: MercenaryData, state: BattleState, info: Dictionary) -> bool:
	if not state.can_afford(merc, int(info["ap"])):
		return false
	if merc.current_rep < int(info["rep"]):
		return false
	var ep_need := CombatApplicator.state_ep_cost(merc, int(info["ep"]), "reaction", 0)
	if int(info["ep"]) > 0 and ep_need <= 0:
		return false
	return ExcessPool.available_ep(merc) >= ep_need


#A target the merc can see; a state without positions hides nothing.
static func sees_target(merc: MercenaryData, target: MercenaryData, state: BattleState) -> bool:
	if target == null:
		return false
	if state == null or state.battlefield == null:
		return true
	return LineOfSight.check(state, merc, target)["visible"] as bool


#Everything past AP, EP and ReP that an action row needs before it can be taken.
static func _feasible(merc: MercenaryData, perk: TraitData, info: Dictionary,
		target: MercenaryData, state: BattleState) -> bool:
	var dsl := perk.effect_dsl
	if dsl.contains("two_handed") and not WeaponArmorPerkLibrary.is_wielding_two_handed(merc):
		return false
	if dsl.contains("wile_check:"):
		return true
	var weapon: WeaponData = merc.equipped_weapon
	var effect := str(info["effect"])
	var seen := sees_target(merc, target, state)
	#Each key answered here needs the matching arm in effect_value; the two lists move together.
	match effect:
		"attack_already_damaged":
			return seen and int(state.escalation.get(merc, {}).get("Attack", 0)) > 0
		"attack_all_adjacent_max_1":
			return not CombatApplicator.get_enemies_within(merc, 1, state).is_empty()
		"attack_fully_loaded":
			return seen and weapon != null and merc.ammo_loaded >= weapon.chamber
		"attack_plus_2", "attack":
			return seen
		"attack_within_1":
			return seen and state.battlefield != null and state.distance_to(merc, target) <= 1
		"called_shot":
			return CalledShotSystem.perk_ready(merc, target, info, state)
		"dex_check":
			return true
		"enhance_attacks_vs_target":
			return target != null and merc.active_states.get("oppress_target") != target
		"after_damage":
			return seen and int(state.damage_dealt_this_round.get(merc, {}).get(target, 0)) > 0
		"weapon_stat":
			return _reach_worth(merc, state) > 0.0
		"direct_1_all":
			return arc_targets(merc, state).size() >= 2
		"spend_ep":
			return rampage_ep(merc) >= 1
		"move_to_target":
			return target != null and state.battlefield != null \
				and WeaponReactiveSystem.pull_destination(merc, target, 3, state) != WeaponReactiveSystem.NO_CELL
		"attack_up_to_3":
			return seen and merc.ammo_loaded > 0
		"15_bullets_min":
			return seen and merc.ammo_loaded >= 15
		"spend_ammo":
			return seen and wild_shot_bullets(merc) >= 1
		"attack_extended":
			return weapon != null and weapon.is_ranged and not weapon.string_snapped \
				and merc.ammo_loaded > 0 and seen and state.battlefield != null \
				and state.distance_to(merc, target) <= weapon.ranged_extended_range \
				and expected_damage(merc, target, weapon, 0, 0, state) > 0.0
	return false


#The worth of what the action does, before its EP and ReP are charged against it.
static func effect_value(merc: MercenaryData, perk: TraitData, info: Dictionary,
		target: MercenaryData, state: BattleState) -> float:
	var dsl := perk.effect_dsl
	if dsl.contains("wile_check:"):
		var spec := PerkActionExecutor.wile_spec(info["parts"] as PackedStringArray)
		var crowd := PerkActionExecutor.wile_targets(merc, spec, state)
		var worth := 0.0
		for enemy: MercenaryData in crowd:
			worth += state_value(ConstStates.TERRIFIED, enemy, merc, state) * TERROR_ODDS
		return worth
	var weapon: WeaponData = merc.equipped_weapon
	var effect := str(info["effect"])
	#Each key answered here needs the matching arm in _feasible; the two lists move together.
	match effect:
		"attack_already_damaged", "attack_fully_loaded":
			return _attack_value(merc, target, weapon, 0, 0, state)
		"attack_all_adjacent_max_1":
			var adj := CombatApplicator.get_enemies_within(merc, 1, state)
			var spin := 0.0
			for enemy: MercenaryData in adj:
				spin += hit_chance(merc, enemy, weapon, 0, 0, state)
			return spin
		"attack_plus_2":
			return _attack_value(merc, target, weapon, 0, 0, state) \
				+ 2.0 * hit_chance(merc, target, weapon, 0, 0, state) + 1.0
		"attack_within_1":
			return _attack_value(merc, target, weapon, 1, 0, state) \
				+ 2.0 * hit_chance(merc, target, weapon, 1, 0, state)
		"called_shot":
			return CalledShotSystem.perk_value(merc, target, info, state)
		"attack":
			return _attack_value(merc, target, weapon, 0, 0, state) + PUSH_VALUE
		"dex_check":
			return REP_WEIGHT * CheckSystem.expected_successes(merc, dex_check_def())
		"enhance_attacks_vs_target":
			return 1.0
		"after_damage":
			var swings := int(merc.turn_weapon_attacks.get(WeaponArmorPerkLibrary.weapon_type_key(weapon), 0))
			return _attack_value(merc, target, weapon, 0, swings, state)
		"weapon_stat":
			return _reach_worth(merc, state)
		"direct_1_all":
			var amount := 2 if WeaponArmorPerkLibrary.is_level_20(merc) else 1
			return float(arc_targets(merc, state).size() * amount)
		"spend_ep":
			return float(rampage_ep(merc))
		"move_to_target":
			var paces := state.distance_to(merc, target) - 1 if state.battlefield != null else 1
			return _attack_value(merc, target, weapon, maxi(1, paces), 0, state)
		"attack_up_to_3":
			var worth := 0.0
			for enemy: MercenaryData in burst_targets(merc, target, state):
				worth += _attack_value(merc, enemy, weapon, 0, 0, state)
			return worth
		"15_bullets_min":
			return float(int(float(merc.ammo_loaded) / 5.0))
		"spend_ammo":
			var bullets := wild_shot_bullets(merc)
			return minf(_attack_value(merc, target, weapon, bullets, 0, state), float(bullets))
		"attack_extended":
			var p := hit_chance(merc, target, weapon, 0, 0, state)
			var dmg := maxf(float(target.stats.get("pain_limit", 0)),
				expected_damage(merc, target, weapon, 0, 0, state))
			var worth := p * dmg
			if dmg >= float(maxi(1, ExcessPool.hp_total(target))):
				worth += kill_value(target, state)
			return worth - (1.0 - p) * SNAP_PENALTY
	return 0.0


#Expected damage plus the kill it is expected to land.
static func _attack_value(merc: MercenaryData, target: MercenaryData, weapon: WeaponData,
		enhancements: int, flaws: int, state: BattleState) -> float:
	var damage := expected_damage(merc, target, weapon, enhancements, flaws, state)
	if target != null and damage >= float(maxi(1, ExcessPool.hp_total(target))):
		damage += kill_value(target, state)
	return damage


#One more pace of reach only pays when an enemy stands just outside the current reach.
static func _reach_worth(merc: MercenaryData, state: BattleState) -> float:
	if state == null or state.battlefield == null:
		return REACH_IDLE_VALUE
	var reach := WeaponArmorPerkLibrary.get_effective_melee_range(merc)
	for enemy: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(enemy) or enemy.off_field:
			continue
		if state.distance_to(merc, enemy) == reach + 1:
			return REACH_VALUE
	return REACH_IDLE_VALUE


static func dex_check_def() -> Dictionary:
	return {
		"stat_keys": ["dexterity"],
		"circumstances": [],
		"knowledges": [],
		"tools": [],
		"formula": "luck",
		"enhancements": 0,
		"flaws": 0,
		"flat_threshold_bonus": 0.0,
	}


#Colossal Sword Arc: 2 or 3 enemies in reach that stand in one adjacent chain.
static func arc_targets(merc: MercenaryData, state: BattleState) -> Array[MercenaryData]:
	var picked: Array[MercenaryData] = []
	if state == null or state.battlefield == null:
		return picked
	var reach := maxi(1, WeaponArmorPerkLibrary.get_effective_melee_range(merc))
	var pool := CombatApplicator.get_enemies_within(merc, reach, state)
	for enemy: MercenaryData in pool:
		if picked.is_empty():
			picked.append(enemy)
			continue
		if picked.size() >= 3:
			break
		for held: MercenaryData in picked:
			if state.distance_to(held, enemy) <= 1:
				picked.append(enemy)
				break
	return picked


#Artillery Burst: the target plus the nearest others standing within 5 paces of it.
static func burst_targets(merc: MercenaryData, target: MercenaryData,
		state: BattleState) -> Array[MercenaryData]:
	var picked: Array[MercenaryData] = []
	if target == null or state == null:
		return picked
	picked.append(target)
	if state.battlefield == null:
		return picked
	var ammo := merc.ammo_loaded
	for enemy: MercenaryData in state.get_enemies(merc):
		if picked.size() >= 3 or picked.size() >= ammo:
			break
		if enemy == target or not BattleState._is_alive(enemy) or enemy.off_field:
			continue
		if state.get_floor(enemy) != state.get_floor(target) or state.distance_to(enemy, target) > 5:
			continue
		if not (LineOfSight.check(state, merc, enemy)["visible"] as bool):
			continue
		picked.append(enemy)
	return picked


#A reaction is refused when it gains nothing or when it would leave the reserve short.
static func reaction_worth(merc: MercenaryData, perk: TraitData, ctx: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": true, "reason": ""}
	if merc == null:
		return {"ok": false, "reason": "no_target"}
	var target: MercenaryData = ctx.get("target") as MercenaryData
	var state: BattleState = ctx.get("state") as BattleState
	var cost := int(ctx.get("cost", 1))
	if bool(ctx.get("needs_target", false)) and target == null:
		return {"ok": false, "reason": "no_target"}
	if cost < 0:
		return {"ok": false, "reason": "no_ep"}
	var gain := reaction_gain(merc, perk, target, state)
	if gain <= 0.0:
		return {"ok": false, "reason": "not_worth"}
	if cost <= 0:
		return out
	var ep_left := int(ctx.get("ep_left", ExcessPool.available_ep(merc) - cost))
	if ep_left >= EP_RESERVE:
		return out
	if target != null and state != null and is_last_enemy(target, state) \
			and expected_damage(merc, target, merc.equipped_weapon, 0, 0, state) \
				>= float(maxi(1, ExcessPool.hp_total(target))):
		return out
	return {"ok": false, "reason": "ep_reserve"}


#What one reaction is expected to gain: its damage, the kill it lands or the state it sets.
static func reaction_gain(merc: MercenaryData, perk: TraitData, target: MercenaryData,
		state: BattleState) -> float:
	if perk == null or target == null:
		return 1.0
	if not BattleState._is_alive(target) or target.off_field:
		return 0.0
	var dsl := perk.effect_dsl
	if dsl.contains("terrified"):
		return state_value(ConstStates.TERRIFIED, target, merc, state)
	if dsl.contains("deposed") or dsl.contains("shove"):
		return state_value(ConstStates.DEPOSED, target, merc, state)
	if dsl.contains("attack"):
		var hit := hit_chance(merc, target, merc.equipped_weapon, 0, 0, state)
		if hit <= 0.0:
			return 0.0
		return maxf(_attack_value(merc, target, merc.equipped_weapon, 0, 0, state), hit * 0.5)
	return 1.0


#Longbow Quick-Shot only pays when two more attacks fit inside the AP it leaves.
static func quick_shot_worth(merc: MercenaryData, state: BattleState, reduction: int,
		cost: int) -> bool:
	if merc == null or state == null:
		return false
	if ExcessPool.available_ep(merc) - cost < EP_RESERVE:
		return false
	var attack_cost := maxi(1, state.get_cost(merc, "Attack", AutoBattle.ATTACK_BASE_AP) - reduction)
	return merc.current_ap + merc.excess_ap >= attack_cost * 2


#Artillery Suppress only pays when the shell catches 2 or more enemies.
static func suppress_worth(merc: MercenaryData, target: MercenaryData, state: BattleState) -> bool:
	if merc == null or target == null or state == null or state.battlefield == null:
		return false
	if merc.current_rep < 2:
		return false
	var caught := 0
	for enemy: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(enemy) or enemy.off_field:
			continue
		if state.get_floor(enemy) != state.get_floor(target):
			continue
		if state.distance_to(enemy, target) <= 5:
			caught += 1
	return caught >= 2


#Auto-Pistol Spray spends bullets only when 2 or more can go into the shot.
static func spray_bullets(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	var extra := mini(merc.ammo_loaded - 1, 3)
	if extra < 2:
		return 0
	var cost := CombatApplicator.state_ep_cost(merc, 1, "reaction", 0)
	if cost <= 0 or ExcessPool.available_ep(merc) - cost < EP_RESERVE:
		return 0
	return extra


#Great Axe Rampage spends what the reserve can spare, at most 3 EP.
static func rampage_ep(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	if int(merc.active_states.get("rampage_bonus", 0)) > 0:
		return 0
	var cost := CombatApplicator.state_ep_cost(merc, 1, "reaction", 0)
	if cost <= 0:
		return 0
	return mini(3, int(float(ExcessPool.available_ep(merc) - EP_RESERVE) / float(cost)))


#Auto-Rifle Wild-Shot spends at most 5 extra bullets and never the last one.
static func wild_shot_bullets(merc: MercenaryData) -> int:
	if merc == null:
		return 0
	return maxi(0, mini(merc.ammo_loaded - 1, 5))


#The perk a makeshift weapon borrows: an enhancer first, then a damage row, then any row.
static func pick_makeshift_perk(merc: MercenaryData, weapon: WeaponData) -> TraitData:
	if merc == null or weapon == null:
		return null
	var key := WeaponArmorPerkLibrary.weapon_type_key(weapon)
	if key == "":
		key = WeaponArmorPerkLibrary.weapon_type_key(weapon.base_weapon)
	var pool := WeaponArmorPerkLibrary.owned_for_key(merc.weapon_perks, key)
	for owned: TraitData in pool:
		if owned.effect_dsl.begins_with("weapon_enhance:"):
			return owned
	for owned: TraitData in pool:
		if owned.effect_dsl.contains("damage"):
			return owned
	return pool[0] if not pool.is_empty() else null
