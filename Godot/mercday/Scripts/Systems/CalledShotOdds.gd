class_name CalledShotOdds


#Everything the marked-damage model needs for one merc against one target; shared by every option.
static func marked_context(merc: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int = 0) -> Dictionary:
	var weapon: WeaponData = merc.equipped_weapon
	var check_def := PerkValuation.attack_check_def(merc, target, weapon, enhancements, 0, state)
	var core := CheckSystem.success_distribution(merc, check_def)
	var dice := PerkValuation.weapon_die_distribution(weapon, float(core["threshold"]))
	var dtype := "Strike"
	var misfire := 0
	if weapon != null:
		dtype = AttackSystem._pick_damage_type(SpecialActionSystem._weapon_types(merc, weapon))
		if weapon.is_ranged:
			misfire = maxi(0, weapon.misfire)
	var core_pmf: Array[float] = core["pmf"]
	var dice_pmf: Array[float] = dice["pmf"]
	var ctx := {"core": core_pmf, "crit": float(core["crit"]), "dice": dice_pmf, "flat": int(dice["flat"]),
		"type": dtype, "misfire": misfire, "land_by_d": [] as Array[float], "dmg_by_d": [] as Array[float]}
	var max_d := core_pmf.size() - 1 + dice_pmf.size() - 1 + maxi(0, int(dice["flat"]))
	_fill_marked_tables(merc, target, state, dtype, max_d, ctx)
	return ctx


#For every damage value the swing can roll: the chance it marks HP and the mean HP it marks.
static func _fill_marked_tables(merc: MercenaryData, target: MercenaryData, state: BattleState,
		dtype: String, max_d: int, ctx: Dictionary) -> void:
	var land_by_d: Array[float] = ctx["land_by_d"]
	var dmg_by_d: Array[float] = ctx["dmg_by_d"]
	var modifier := DefenseSystem.damage_modifier_for(target, dtype)
	var free_def := state != null and state.battlefield != null \
		and state.is_covered_from(target, merc, ConstStates.COVERED_PARTIAL)
	var ep_cost := CombatApplicator.state_ep_cost(target, 1, "defend")
	var can_pay := ep_cost >= 0 and ExcessPool.available_ep(target) >= ep_cost
	var flaws := WeaponArmorPerkLibrary.defense_flaws_against(merc, target)
	var type_data: Dictionary = ConstDamageTypes.get_type(dtype)
	var defend_floor := 1 if bool(type_data.get("block_min_1", false)) else 0
	var dodge_floor := 1 if bool(type_data.get("dodge_min_1", false)) else 0
	var split: Dictionary = {}
	for d: int in range(max_d + 1):
		var hit := d
		if modifier == "immune":
			hit = 0
		elif modifier == "susceptible":
			hit = d * 2
		elif modifier == "protected":
			hit = floori(d / 2.0)
		if hit <= 0:
			land_by_d.append(0.0)
			dmg_by_d.append(0.0)
			continue
		var defends := free_def or (can_pay and CombatDecision.should_attempt_defense(target, d, dtype))
		if not defends:
			land_by_d.append(1.0)
			dmg_by_d.append(float(hit))
			continue
		if split.is_empty():
			split = _reduction_distribution(target, dtype, flaws, type_data)
		var land := 0.0
		var dmg := 0.0
		for source: String in ["defend", "dodge"]:
			var won: Array[float] = split[source]
			var floor_hp := defend_floor if source == "defend" else dodge_floor
			for r: int in range(won.size()):
				var final := maxi(floor_hp, hit - r)
				dmg += won[r] * float(final)
				if hit - r >= 1:
					land += won[r]
		land_by_d.append(land)
		dmg_by_d.append(dmg)


#Reduction spread split by the roll that wins: P(Defend wins removing r) under "defend", P(Dodge wins
#removing r) under "dodge". A tie goes to Defend as in DefenseSystem.resolve, so the two parts sum to one.
static func _reduction_distribution(target: MercenaryData, dtype: String, flaws: int,
		flags: Dictionary = {}) -> Dictionary:
	var type_data: Dictionary = flags if not flags.is_empty() else ConstDamageTypes.get_type(dtype)
	var defend: Array[float] = [1.0]
	if not bool(type_data.get("defend_blocked", false)):
		var rolled: Array[float] = CheckSystem.success_distribution(target,
			PerkValuation.defend_check_def(target, flaws))["pmf"]
		if bool(type_data.get("defend_halved", false)):
			defend = []
			for s: int in range(rolled.size()):
				var h := floori(s / 2.0)
				while defend.size() <= h:
					defend.append(0.0)
				defend[h] += rolled[s]
		else:
			defend = rolled
	var dodge: Array[float] = [1.0]
	if not bool(type_data.get("dodge_blocked", false)):
		dodge = CheckSystem.success_distribution(target, PerkValuation.dodge_check_def(target, flaws))["pmf"]
	var defend_won: Array[float] = []
	var dodge_won: Array[float] = []
	var cum_dodge := 0.0
	var cum_defend_below := 0.0
	for r: int in range(maxi(defend.size(), dodge.size())):
		var p_defend := defend[r] if r < defend.size() else 0.0
		var p_dodge := dodge[r] if r < dodge.size() else 0.0
		cum_dodge += p_dodge
		defend_won.append(p_defend * cum_dodge)
		dodge_won.append(p_dodge * cum_defend_below)
		cum_defend_below += p_defend
	return {"defend": defend_won, "dodge": dodge_won}


#Mean HP the swing marks and the chance it lands with v removed: a critical, or 1 or more HP past the defence
#with a core success left after the cost. A roll under the misfire value marks nothing.
static func expected_marked(ctx: Dictionary, v: int) -> Dictionary:
	var core: Array[float] = ctx["core"]
	var dice: Array[float] = ctx["dice"]
	var land_by_d: Array[float] = ctx["land_by_d"]
	var dmg_by_d: Array[float] = ctx["dmg_by_d"]
	var flat := int(ctx["flat"])
	var misfire := int(ctx.get("misfire", 0))
	var land := 0.0
	var dmg := 0.0
	for k: int in range(core.size()):
		if core[k] <= 0.0 or k < misfire:
			continue
		var kept := maxi(0, k - v)
		var can_land := v <= 0 or k - v >= 1
		for j: int in range(dice.size()):
			var d := kept + j + flat
			if d <= 0 or d >= land_by_d.size():
				continue
			var p := core[k] * dice[j]
			if can_land:
				land += p * land_by_d[d]
			dmg += p * dmg_by_d[d]
	var crit := float(ctx["crit"])
	return {"damage": dmg, "land": land + crit * (1.0 - land)}


#What the plain swing is expected to mark, on the same model the options are scored with.
static func plain_score(merc: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int = 0, ctx: Dictionary = {}) -> float:
	if merc == null or target == null:
		return 0.0
	if ctx.is_empty():
		ctx = marked_context(merc, target, state, enhancements)
	return float(expected_marked(ctx, 0)["damage"])


#What this option is worth against this target: the HP it still marks plus the effect when it lands.
static func option_score(merc: MercenaryData, target: MercenaryData, key: String, state: BattleState,
		enhancements: int = 0, ctx: Dictionary = {}) -> float:
	if merc == null or target == null or not CalledShotSystem.OPTIONS.has(key):
		return 0.0
	if ctx.is_empty():
		ctx = marked_context(merc, target, state, enhancements)
	var marked := expected_marked(ctx, CalledShotSystem.value(key))
	return float(marked["damage"]) + float(marked["land"]) * effect_value(merc, target, key, state)


static func effect_value(merc: MercenaryData, target: MercenaryData, key: String, state: BattleState) -> float:
	var opt: Dictionary = CalledShotSystem.OPTIONS.get(key, {})
	if opt.is_empty():
		return 0.0
	var state_name := str(opt.get("state", ""))
	if state_name != "":
		return PerkValuation.state_value(state_name, target, merc, state)
	if bool(opt.get("drop", false)):
		return CalledShotSystem.DROP_VALUE * clampf(PerkValuation.threat_of(target, merc, state) / 3.0, 0.5, 2.0)
	if bool(opt.get("crit", false)):
		for perk: TraitData in WeaponArmorPerkLibrary.get_active_weapon_perks(merc):
			if perk.effect_dsl.contains("on_crit"):
				return CalledShotSystem.WOUND_VALUE
		return 0.0
	return 0.0


#The best option worth taking against this target, or "" for a plain attack.
static func choose(merc: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int = 0) -> String:
	if merc == null or target == null:
		return ""
	if CalledShotSystem.force_every:
		return _forced(merc, target, state)
	var best := ""
	var best_score := 0.0
	var ctx: Dictionary = {}
	for key: String in CalledShotSystem.AI_OPTIONS:
		if not CalledShotSystem.is_valid(merc, target, key, state):
			continue
		if ctx.is_empty():
			ctx = marked_context(merc, target, state, enhancements)
		var score := option_score(merc, target, key, state, enhancements, ctx)
		if best == "" or score > best_score:
			best = key
			best_score = score
	if best == "":
		return ""
	var plain := plain_score(merc, target, state, enhancements, ctx)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("CALLED SHOT: %s picks %s (%d) vs %s score=%.2f plain=%.2f land=%.2f" % [
			merc.merc_name, CalledShotSystem.label(best), CalledShotSystem.value(best), target.merc_name, best_score, plain,
			float(expected_marked(ctx, CalledShotSystem.value(best))["land"])])
	if best_score > plain:
		return best
	return ""


#Forced usage: the named option when valid, else every valid option in turn.
static func _forced(merc: MercenaryData, target: MercenaryData, state: BattleState) -> String:
	if CalledShotSystem.force_option != "":
		return CalledShotSystem.force_option if CalledShotSystem.is_valid(merc, target, CalledShotSystem.force_option, state) else ""
	var valid: Array[String] = []
	for key: String in CalledShotSystem.OPTIONS:
		if CalledShotSystem.is_valid(merc, target, key, state):
			valid.append(key)
	if valid.is_empty():
		return ""
	return valid[CalledShotSystem.calls_made % valid.size()]


#Turns a plain Attack decision into a called shot when one is worth the AP.
static func upgrade(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int = 0) -> Dictionary:
	if merc == null or state == null or decision.is_empty():
		return decision
	if str(decision.get("type", "")) != "attack" or str(decision.get("action_name", "")) != "Attack":
		return decision
	var target: MercenaryData = decision.get("target") as MercenaryData
	if target == null:
		return decision
	var reduction := int(merc.active_states.get("attack_ap_reduction", 0))
	var cost := maxi(0, state.get_cost(merc, "CalledShot", AutoBattle.ATTACK_BASE_AP) - reduction)
	if not state.can_afford(merc, cost):
		return decision
	var key := choose(merc, target, state, enhancements)
	if key == "":
		return decision
	var out := decision.duplicate()
	out["called_shot"] = key
	return out
