class_name ActionDispatcher

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

const INJECTION_POINTS: Dictionary = {
	40: "pre_move",
	60: "pre_aim",
}

const TIER_SNAP_GATES: Dictionary = {
	60: {"has_valid_target": true},
}


#The grappler holds the target with a drawn whip: Whip Choke perk, Size 5 or less, still within reach.
static func is_whip_grappler(grappler: MercenaryData, target: MercenaryData, state: BattleState) -> bool:
	if grappler == null or target == null:
		return false
	if not BattleState._is_alive(grappler) or not BattleState._is_alive(target):
		return false
	if ConstStates.get_source(target, ConstStates.GRAPPLED) != grappler:
		return false
	var weapon: WeaponData = grappler.equipped_weapon
	if weapon == null or not grappler.weapon_drawn:
		return false
	if weapon.weapon_type.get_slice(" (", 0).strip_edges() != "Whip":
		return false
	if not WeaponArmorPerkLibrary.has_weapon_perk_prefix(grappler, "on_grapple:"):
		return false
	if int(target.stats.get("size", 1)) > 5:
		return false
	return state.distance_to(grappler, target) <= maxi(1, WeaponArmorPerkLibrary.get_effective_melee_range(grappler))


#Whip Choke: one AP left at the end of the turn buys 1 Direct damage to one whip-grappled enemy.
static func do_whip_choke_ap_spend(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if not state.can_afford(merc, 1) or ConstStates.is_blocked(merc, "spend:ap"):
		return lines
	var whip_target: MercenaryData = null
	for enemy: MercenaryData in state.get_enemies(merc):
		if is_whip_grappler(merc, enemy, state):
			whip_target = enemy
			break
	if whip_target == null:
		return lines
	state.spend_ap(merc, 1)
	lines.append_array(CombatApplicator.apply_damage(merc, whip_target, 1, "Direct", state))
	lines.append("  %s tightens the whip choke for 1 Direct damage!" % BattleState.colored_name(merc, state))
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("WHIP CHOKE: %s spends 1 AP on %s" % [
			merc.merc_name, whip_target.merc_name])
	return lines


#Lowest AP cost any action could still charge this merc; 0 when nothing in reach costs AP.
static func cheapest_action_cost(merc: MercenaryData, state: BattleState) -> int:
	var cheapest := 0
	if merc.action_set != null:
		for action: ActionData in merc.action_set.actions:
			if not action.enabled or action.is_reactive:
				continue
			var base_cost := action.ap_cost
			match action.ap_cost_mode:
				"attack_base":
					base_cost = _CONFIG.attack_base_ap
				"move_base":
					base_cost = _CONFIG.move_base_ap
			if base_cost <= 0:
				continue
			var cost := state.move_cost(merc, action.action_name, base_cost) if action.ap_cost_mode == "move_base" \
				else state.get_cost(merc, action.action_name, base_cost)
			#Paces still in the pool buy a walk for nothing, so nothing is unaffordable yet.
			if action.ap_cost_mode == "move_base" and cost <= 0:
				return 0
			if cost > 0 and (cheapest == 0 or cost < cheapest):
				cheapest = cost
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(merc):
		if not perk.effect_dsl.begins_with("action:"):
			continue
		var parts := perk.effect_dsl.split(":")
		var perk_cost := int(parts[1]) if parts.size() > 1 else 0
		if perk_cost > 0 and (cheapest == 0 or perk_cost < cheapest):
			cheapest = perk_cost
	return cheapest


#can_attack false means no plain attack is open this turn, so one wile target is enough.
static func choose_perk_action(merc: MercenaryData, target: MercenaryData, state: BattleState,
		can_attack: bool = true) -> TraitData:
	if target == null:
		return null
	var best: TraitData = null
	var best_is_aoe := false
	var best_is_wile := false
	var adj_enemy_count := CombatApplicator.get_enemies_within(merc, 1, state).size()
	var candidates: Array[TraitData] = WeaponArmorPerkLibrary.get_weapon_actions(merc)
	candidates.append_array(_holstered_draw_actions(merc))
	for perk: TraitData in candidates:
		var dsl := perk.effect_dsl
		if not dsl.begins_with("action:"):
			continue
		var parts := dsl.split(":")
		var ap_cost := int(parts[1]) if parts.size() > 1 else 99
		if not state.can_afford(merc, ap_cost):
			continue
		var ep_cost := 0
		var rep_cost := 0
		for idx in range(2, parts.size() - 1):
			if parts[idx] == "ep":
				ep_cost = int(parts[idx + 1])
			elif parts[idx] == "rep":
				rep_cost = int(parts[idx + 1])
		var ep_need := CombatApplicator.state_ep_cost(merc, ep_cost, "reaction", 0)
		if ExcessPool.available_ep(merc) < ep_need or merc.current_rep < rep_cost:
			continue
		var is_wile := dsl.contains("wile_check:")
		if is_wile and not _wile_action_ready(merc, perk, _wile_spec(parts), ap_cost, state, 2 if can_attack else 1):
			continue
		var effect_start := 2
		for idx in range(2, parts.size()):
			if parts[idx] in ["ep", "rep", "once_per_combat"]:
				if idx + 1 < parts.size():
					effect_start = idx + 2
		var effect := parts[effect_start] if parts.size() > effect_start else ""
		if not is_wile and not (effect in ["attack_already_damaged", "attack_all_adjacent_max_1", "attack_fully_loaded"]):
			continue
		var is_aoe := effect == "attack_all_adjacent_max_1"
		var take := best == null
		if not take and is_aoe and not best_is_aoe and adj_enemy_count >= 2:
			take = true
		if not take and best_is_wile and not is_wile:
			take = true
		if take:
			best = perk
			best_is_aoe = is_aoe
			best_is_wile = is_wile
	return best


#Action perks a holstered weapon can still start: the ones that draw as part of the action.
static func _holstered_draw_actions(merc: MercenaryData) -> Array[TraitData]:
	var result: Array[TraitData] = []
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or merc.weapon_drawn or weapon.is_virtual or weapon.weapon_type == "":
		return result
	var key: String = weapon.weapon_type.get_slice(" (", 0).strip_edges()
	var pool: Array[TraitData] = []
	pool.append_array(merc.weapon_perks)
	for entry: Variant in (DataManager.weapon_trait_library.get(key, []) as Array):
		var lib_perk: TraitData = entry as TraitData
		if lib_perk != null:
			pool.append(lib_perk)
	var seen: Dictionary = {}
	for perk: TraitData in pool:
		if perk == null or seen.has(perk.trait_name):
			continue
		seen[perk.trait_name] = true
		if perk.effect_dsl.begins_with("action:") and perk.effect_dsl.contains(":on_draw:"):
			result.append(perk)
	return result


#Trial, Terrified duration, target radius and cost form of a "wile_check" action perk.
static func _wile_spec(parts: PackedStringArray) -> Dictionary:
	var spec := {"trial": 0, "duration": "", "radius": 0, "on_draw": false,
		"spend_ammo": false, "flaw_per_5": false, "once": false}
	for i: int in range(parts.size()):
		match parts[i]:
			"wile_check":
				if i + 1 < parts.size():
					spec["trial"] = int(parts[i + 1])
			"terrified":
				if i + 1 < parts.size() and parts[i + 1].contains("_"):
					var dur: String = parts[i + 1].replace("_", " ")
					spec["duration"] = "%s %s" % [dur.get_slice(" ", 0), dur.get_slice(" ", 1).capitalize()]
			"on_draw":
				spec["on_draw"] = true
				spec["radius"] = 5
			"spend_ammo_5s":
				spec["spend_ammo"] = true
				spec["radius"] = 300
			"+1_flawed_per_5":
				spec["flaw_per_5"] = true
			"once_per_combat":
				spec["once"] = true
	return spec


#Enemies in range of a wile action that are neither Terrified already nor known to be immune to it.
static func _wile_targets(merc: MercenaryData, spec: Dictionary, state: BattleState) -> Array[MercenaryData]:
	var result: Array[MercenaryData] = []
	var token := "immune:" + ConstStates.normalize_token(ConstStates.TERRIFIED)
	for enemy: MercenaryData in CombatApplicator.get_enemies_within(merc, int(spec["radius"]), state):
		if ConstStates.has_state(enemy, ConstStates.TERRIFIED) or BattleState.knows(merc, enemy, token):
			continue
		result.append(enemy)
	return result


#Auto-Rifle Bully spend: 5 rounds per target, at most 15, always leaving 5 in the magazine.
static func _bully_bullets(ammo_loaded: int, target_count: int) -> int:
	var spare := int(float(ammo_loaded - 5) / 5.0) * 5
	return mini(spare, mini(5 * maxi(1, target_count), 15))


#What a wile action needs past its AP: the once-per-combat mark, ammo, a payable draw and targets.
static func _wile_action_ready(merc: MercenaryData, perk: TraitData, spec: Dictionary,
		ap_cost: int, state: BattleState, min_targets: int) -> bool:
	if int(spec["radius"]) <= 0 or int(spec["trial"]) <= 0 or str(spec["duration"]) == "":
		return false
	if bool(spec["once"]) and bool(merc.active_states.get(_perk_used_key(perk), false)):
		return false
	if bool(spec["spend_ammo"]) and _bully_bullets(merc.ammo_loaded, 1) < 5:
		return false
	var extra_ap := 0
	if bool(spec["on_draw"]) and not merc.weapon_drawn:
		if merc.equipped_weapon == null:
			return false
		var swap := WeaponActionExecutor.get_swap_cost(merc, merc.equipped_weapon, state)
		if swap < 0:
			return false
		extra_ap = swap
	if not state.can_afford(merc, ap_cost + extra_ap):
		return false
	return _wile_targets(merc, spec, state).size() >= min_targets


static func _perk_used_key(perk: TraitData) -> String:
	return "perk_used_" + perk.trait_name


static func _perk_label(perk: TraitData) -> String:
	var pieces := perk.trait_name.split("|")
	return pieces[pieces.size() - 1]


#Great Club Terrorize and Auto-Rifle Bully: a Wile trial that leaves every failure Terrified.
static func _do_wile_terror(merc: MercenaryData, perk: TraitData, spec: Dictionary,
		state: BattleState, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var targets := _wile_targets(merc, spec, state)
	if targets.is_empty():
		return lines
	var bullets := 0
	if bool(spec["spend_ammo"]):
		bullets = _bully_bullets(merc.ammo_loaded, targets.size())
		if bullets < 5:
			return lines
	if bool(spec["on_draw"]) and not merc.weapon_drawn:
		var draw_lines := WeaponActionExecutor.execute_draw(merc, merc.equipped_weapon, state, enhancements)
		if draw_lines.is_empty():
			return lines
		lines.append_array(draw_lines)
	var extra_flaws := 0
	if bullets > 0:
		merc.ammo_loaded -= bullets
		if bool(spec["flaw_per_5"]):
			extra_flaws = int(float(bullets) / 5.0)
		lines.append("  %s empties %d round%s with %s!" % [
			BattleState.colored_name(merc, state), bullets, "s" if bullets != 1 else "", _perk_label(perk)])
	else:
		lines.append("  %s uses %s!" % [BattleState.colored_name(merc, state), _perk_label(perk)])
	if bool(spec["once"]):
		merc.active_states[_perk_used_key(perk)] = true
	var resist_spec := "Resist:Wile:%d" % int(spec["trial"])
	for enemy: MercenaryData in targets:
		if CombatApplicator.known_immune(merc, enemy, ConstStates.TERRIFIED, "terrified"):
			continue
		lines.append_array(StateInfliction.inflict(enemy, ConstStates.TERRIFIED, resist_spec,
			str(spec["duration"]), "", merc, state, extra_flaws))
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("TERRIFY: %s %s trial=%d targets=%d flaws=%d bullets=%d" % [
			merc.merc_name, _perk_label(perk), int(spec["trial"]), targets.size(), extra_flaws, bullets])
	return lines


#Every abort path of execute_perk_action gives back what the token loop and spend_ap took.
static func _abort_perk_action(merc: MercenaryData, ap_before: int, excess_before: int,
		ep_excess: int, ep_real: int, rep_paid: int) -> Array[String]:
	merc.current_ap = ap_before
	merc.excess_ap = excess_before
	ExcessPool.refund_ep(merc, ep_excess, ep_real)
	merc.current_rep += rep_paid
	return []


static func execute_perk_action(
		merc: MercenaryData,
		perk: TraitData,
		target: MercenaryData,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var dsl := perk.effect_dsl
	var parts := dsl.split(":")
	var ap_cost := int(parts[1])
	var ap_before := merc.current_ap
	var excess_before := merc.excess_ap
	state.spend_ap(merc, ap_cost)

	var effect_start := 2
	var j := 2
	var ep_excess := 0
	var ep_real := 0
	var rep_paid := 0
	while j < parts.size() - 1:
		if parts[j] == "ep":
			var ep_step := CombatApplicator.state_ep_cost(merc, int(parts[j + 1]), "reaction", 0)
			var pay := ExcessPool.pay_ep(merc, ep_step)
			ep_excess += int(pay["from_excess"])
			ep_real += int(pay["from_ep"])
			effect_start = j + 2
			j += 2
		elif parts[j] == "rep":
			var rep_step := int(parts[j + 1])
			merc.current_rep -= rep_step
			rep_paid += rep_step
			effect_start = j + 2
			j += 2
		elif parts[j] == "once_per_combat":
			effect_start = j + 1
			j += 1
		else:
			break

	if dsl.contains("wile_check:"):
		var wile_lines := _do_wile_terror(merc, perk, _wile_spec(parts), state, enhancements)
		if wile_lines.is_empty():
			return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		return wile_lines

	var effect := parts[effect_start] if parts.size() > effect_start else ""
	match effect:
		"attack_already_damaged":
			var attacks_taken: int = state.escalation.get(merc, {}).get("Attack", 0)
			if attacks_taken > 0 and target != null:
				lines.append_array(_perk_single_attack(
					merc, target, state, enhancements, "uses Uppercut!", "Uppercut"))
			else:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		"attack_all_adjacent_max_1":
			var adj_enemies := CombatApplicator.get_enemies_within(merc, 1, state)
			if not adj_enemies.is_empty():
				lines.append("  %s spins!" % BattleState.colored_name(merc, state))
				for enemy: MercenaryData in adj_enemies:
					var atk := AttackSystem.execute_attack(merc, enhancements, 0, enemy)
					state.record_action(merc, "Attack")
					if atk.get("misfired", false):
						lines.append("  %s misfires!" % BattleState.colored_name(merc, state))
						break
					elif atk.get("damage", 0) > 0:
						lines.append_array(CombatApplicator.apply_hit(merc, enemy, atk, 1, atk["damage_type"], state))
					else:
						lines.append("  %s misses %s with the spin." % [BattleState.colored_name(merc, state), BattleState.colored_name(enemy, state)])
			else:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		"attack_fully_loaded":
			if target != null and merc.equipped_weapon != null and merc.ammo_loaded >= merc.equipped_weapon.chamber:
				lines.append_array(_perk_single_attack(
					merc, target, state, enhancements, "fires rapidly!", "Rapid-Fire"))
			else:
				return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
		_:
			return _abort_perk_action(merc, ap_before, excess_before, ep_excess, ep_real, rep_paid)
	return lines


static func build_decision_snapshot(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_targets: Array,
		state: BattleState,
		ctx: Dictionary) -> Dictionary:
	var weapon := merc.equipped_weapon
	var weapon_drawn := weapon != null and merc.weapon_drawn
	var ranged_enemy := false
	for e: MercenaryData in enemies:
		if e.equipped_weapon != null and e.equipped_weapon.is_ranged:
			ranged_enemy = true
			break
	var enemy_adjacent := false
	if state.battlefield != null:
		for e: MercenaryData in enemies:
			if BattleState._is_alive(e) and state.distance_to(merc, e) <= 1:
				enemy_adjacent = true
				break
	var max_hp: int = merc.stats.get("maximum_hit_points", 10)
	return {
		"weapon_drawn": weapon_drawn,
		"weapon_is_ranged": weapon != null and merc.weapon_drawn and weapon.is_ranged,
		"has_ammo": merc.ammo_loaded > 0,
		"has_valid_target": not valid_targets.is_empty(),
		"ranged_enemy_present": ranged_enemy,
		"enemy_adjacent": enemy_adjacent,
		"movement_blocked": ctx.get("movement_blocked", false),
		"hp_below_half": merc.current_hp <= max_hp * 0.5,
		"seeking_mode": ctx.get("seeking_mode", false),
		"no_valid_targets": valid_targets.is_empty(),
	}


static func snap_passes(snap: Dictionary, requirements: Dictionary) -> bool:
	for key: String in requirements:
		if snap.get(key) != requirements[key]:
			return false
	return true


#One perk attack against a single target; announce is the merc line, label names the miss.
static func _perk_single_attack(merc: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int, announce: String, label: String) -> Array[String]:
	var out: Array[String] = []
	var atk := AttackSystem.execute_attack(merc, enhancements, 0, target)
	out.append("  %s %s" % [BattleState.colored_name(merc, state), announce])
	state.record_action(merc, "Attack")
	if atk.get("misfired", false):
		out.append("  %s misfires!" % BattleState.colored_name(merc, state))
	elif atk.get("no_ammo", false):
		out.append("  %s has no ammo loaded!" % BattleState.colored_name(merc, state))
	elif atk.get("damage", 0) > 0:
		out.append_array(CombatApplicator.apply_hit(merc, target, atk, atk["damage"], atk["damage_type"], state))
	else:
		out.append("  %s misses with %s against %s." % [BattleState.colored_name(merc, state), label, BattleState.colored_name(target, state)])
	return out


#The chamber-empty reload injection; {} when the merc should not reload.
static func _reload_injection(merc: MercenaryData, enemies: Array[MercenaryData],
		valid_targets: Array[MercenaryData], state: BattleState, note: String) -> Dictionary:
	if merc.ammo_loaded != 0 or not CombatDecision._should_reload(merc, enemies, valid_targets, state):
		return {}
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("INJECTED [reload]: %s (%s)" % [merc.merc_name, note])
	return {"type": "reload", "action_name": "reload", "target": null}


static func _run_pre_move_injection(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_targets: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool,
		weapon_action_taken: bool,
		is_desperate: bool) -> Dictionary:
	var reload_inj := _reload_injection(merc, enemies, valid_targets, state, "chamber empty, pre-40")
	if not reload_inj.is_empty():
		return reload_inj
	if not weapon_action_taken:
		var wp := WeaponSwapDecider._decide_weapon_action(merc, enemies, state, _CONFIG.attack_base_ap, movement_blocked)
		if wp["type"] != "none":
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("INJECTED [%s]: %s (weapon action, pre-40)" % [
					str(wp.get("action_name", wp["type"])), merc.merc_name])
			return wp
		var pu := CombatDecision._decide_pickup_action(merc, enemies, state, _CONFIG.attack_base_ap, _CONFIG.move_base_ap)
		if pu["type"] != "none":
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("INJECTED [%s]: %s -> %s" % [
					pu["action_name"], merc.merc_name,
					str(pu.get("weapon_pos", pu.get("weapon_entry", {}).get("weapon", "")))])
			return pu
	if not movement_blocked and not is_desperate and state.battlefield != null and valid_targets.is_empty():
		var bfw := CombatDecision._decide_break_for_weapon(merc, enemies, state, _CONFIG.attack_base_ap, _CONFIG.move_base_ap)
		if bfw["type"] != "none":
			return bfw
	return {"type": "none"}


static func _run_pre_aim_injection(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_targets: Array[MercenaryData],
		state: BattleState) -> Dictionary:
	if merc.ammo_loaded > 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("INJECTED [reload]: %s (pre-attack tactical)" % merc.merc_name)
		return {"type": "reload", "action_name": "reload", "target": null}
	return {"type": "none"}


#Each refused draw raises urgency; the bonus lifts Draw over its threshold and ahead of movement.
static func _draw_urgency_bonus(merc: MercenaryData) -> float:
	var urgency := WeaponActionExecutor.get_draw_urgency(merc)
	if urgency <= 0:
		return 0.0
	var bonus := minf(0.25 * float(urgency), 1.0)
	if EncounterLogger.is_active() and not bool(merc.active_states.get("draw_priority_turn", false)):
		merc.active_states["draw_priority_turn"] = true
		EncounterLogger.log_verbose("DRAW PRIORITY: %s urgency=%d bonus=%.2f" % [merc.merc_name, urgency, bonus])
	return bonus


static func choose_from_action_set(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_targets: Array[MercenaryData],
		allies: Array[MercenaryData],
		current_target: MercenaryData,
		state: BattleState,
		movement_blocked: bool,
		weapon_action_taken: bool = false,
		has_moved: bool = false,
		seeking_failed: bool = false,
		blocked_targets: Dictionary = {}) -> Dictionary:
	if merc.action_set == null:
		merc.action_set = DefaultActionSet.create()

	var ctx := {
		"enemies": enemies, "allies": allies, "valid_targets": valid_targets,
		"state": state, "current_target": current_target,
		"movement_blocked": movement_blocked, "has_moved": has_moved,
		"seeking_mode": (state.no_target_turns.get(merc, 0) as int) >= 1,
		"seeking_failed": seeking_failed,
		"blocked_targets": blocked_targets,
		"attack_base_ap": _CONFIG.attack_base_ap, "move_base_ap": _CONFIG.move_base_ap
	}
	var snap := build_decision_snapshot(merc, enemies, valid_targets, state, ctx)

	var reload_now := _reload_injection(merc, enemies, valid_targets, state, "chamber empty")
	if not reload_now.is_empty():
		return reload_now

	var _stuck_rounds := (state.no_progress_rounds.get(merc, 0) as int)
	var _no_tgt_turns := (state.no_target_turns.get(merc, 0) as int)
	var _fighting_alone := state.get_allies(merc).is_empty()
	var _is_desperate := _stuck_rounds >= 2 or _fighting_alone or _no_tgt_turns >= 5
	if _is_desperate and EncounterLogger.is_active():
		if not merc.active_states.get("_esc_logged", false):
			merc.active_states["_esc_logged"] = true
			var _esc_reason: String
			if _stuck_rounds >= 2:
				_esc_reason = "stuck %d rounds" % _stuck_rounds
			elif _fighting_alone:
				_esc_reason = "last remaining"
			else:
				_esc_reason = "no targets %d turns" % _no_tgt_turns
			EncounterLogger.log_verbose("[escalation] %s - %s" % [merc.merc_name, _esc_reason])
	elif merc.active_states.has("_esc_logged"):
		merc.active_states.erase("_esc_logged")
	if _is_desperate and movement_blocked:
		var _obs_result := CombatDecision.decide_obstacle_or_flank(merc, enemies, valid_targets, state, movement_blocked)
		if EncounterLogger.is_active():
			var _obs_type: String = _obs_result.get("type", "pass")
			if _obs_type != "pass":
				EncounterLogger.log_verbose("    obstacle/flank: %s selected" % _obs_result.get("action_name", _obs_type))
			else:
				EncounterLogger.log_verbose("    obstacle/flank: no valid target found")
		if _obs_result.get("type", "pass") != "pass":
			return _obs_result

	var sorted_actions: Array = merc.action_set.actions.duplicate()
	sorted_actions.sort_custom(func(a: ActionData, b: ActionData) -> bool: return a.priority < b.priority)

	var draw_bonus := _draw_urgency_bonus(merc)
	if draw_bonus > 0.0:
		for i: int in range(sorted_actions.size()):
			var da: ActionData = sorted_actions[i]
			if da.action_name == "Draw" and not da.is_reactive:
				sorted_actions.remove_at(i)
				sorted_actions.push_front(da)
				break

	var affordable_actions: Array = sorted_actions.filter(
		func(a: ActionData) -> bool: return a.can_execute(merc, ctx))
	if affordable_actions.is_empty():
		return {"type": "pass", "action_name": "", "target": null}

	var injected: Dictionary = {}
	var tier_blocked: Dictionary = {}

	for action: ActionData in sorted_actions:
		if action.is_reactive:
			continue
		if not action.snap_require.is_empty() and not snap_passes(snap, action.snap_require):
			continue

		var action_tier_blocked := false
		for gate_priority: int in TIER_SNAP_GATES:
			if action.priority >= gate_priority:
				if not tier_blocked.has(gate_priority):
					tier_blocked[gate_priority] = not snap_passes(snap, TIER_SNAP_GATES[gate_priority])
				if tier_blocked[gate_priority]:
					action_tier_blocked = true
					break
		if action_tier_blocked:
			continue

		if _is_desperate and action.action_name == "seek_cover":
			var _eq := merc.equipped_weapon
			var _weapon_ok := true
			if _eq != null and merc.weapon_drawn and _eq.is_ranged:
				if merc.ammo_loaded <= 0:
					_weapon_ok = MercenaryData.has_reserve_ammo(merc)
				elif _eq.misfire > 0 and not FirearmReliabilityFacet.aimed_viable(merc):
					_weapon_ok = false
			if _weapon_ok:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("    seek_cover suppressed by escalation")
				continue

		for inj_priority: int in INJECTION_POINTS:
			if action.priority >= inj_priority and not injected.has(inj_priority):
				injected[inj_priority] = true
				var inj_result: Dictionary
				match INJECTION_POINTS[inj_priority]:
					"pre_move":
						inj_result = _run_pre_move_injection(
							merc, enemies, valid_targets, state,
							movement_blocked, weapon_action_taken, _is_desperate)
					"pre_aim":
						inj_result = _run_pre_aim_injection(merc, enemies, valid_targets, state)
					_:
						inj_result = {"type": "none"}
				if inj_result["type"] != "none":
					return inj_result

		var bonus: float = draw_bonus if action.action_name == "Draw" else 0.0
		if action.can_execute(merc, ctx):
			var score: float
			var passed: bool
			if EncounterLogger.is_active():
				var verbose: Dictionary = action.decision.evaluate_verbose(merc, ctx)
				score = minf(float(verbose["score"]) + bonus, 1.0)
				passed = bool(verbose["passed"]) or bonus > 0.0
				EncounterLogger.log_verbose("DECISION [%s]: score=%.2f threshold=%.2f -> %s" % [
					action.action_name, score, action.decision.threshold,
					"PASS" if passed and score >= action.decision.threshold else "fail"])
				for fd: Dictionary in verbose["facets"]:
					var weight_str := "req" if fd["required"] else "w=%.1f" % fd["weight"]
					var score_str := "skipped" if fd.get("skipped", false) else "%.2f" % fd["score"]
					EncounterLogger.log_verbose("    %s [%s]: %s" % [fd["name"], weight_str, score_str])
			else:
				score = minf(action.decision.evaluate(merc, ctx) + bonus, 1.0)
				passed = true
			if passed and score >= action.decision.threshold:
				if action.action_name == "attack_obstacle":
					return CombatDecision.decide_obstacle_or_flank(merc, enemies, valid_targets, state, movement_blocked)
				if action.action_name == "aid_ally":
					var aid := StateReliefEvaluator.aid_decision(merc, ctx)
					if str(aid.get("type", "none")) == "none":
						continue
					return aid
				return action.to_decision_dict(merc, ctx)

	var fallback := _fallback_spend_ap(merc, enemies, valid_targets, state, movement_blocked)
	if fallback["type"] != "none":
		return fallback
	return {"type": "pass", "action_name": "", "target": null}


#No action passed and the merc cannot attack: retreat from the nearest enemy when hurt, close in when not.
static func _fallback_spend_ap(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_targets: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool) -> Dictionary:
	if not valid_targets.is_empty() or enemies.is_empty():
		return {"type": "none"}
	if movement_blocked or state.battlefield == null:
		return {"type": "none"}
	if ConstStates.has_state(merc, ConstStates.GRAPPLED):
		return {"type": "none"}
	var hurt := MovementDecider.is_in_danger(merc)
	var action_name := "Move Far" if hurt else "Move Close"
	if not hurt and ConstStates.has_state(merc, ConstStates.TERRIFIED):
		action_name = "Move Far"
		hurt = true
	if not state.can_afford(merc, state.move_cost(merc, action_name, _CONFIG.move_base_ap)):
		return {"type": "none"}
	var nearest := MovementDecider.closest_enemy(merc, enemies, state)
	if nearest == null:
		return {"type": "none"}
	if EncounterLogger.is_active():
		var max_hp: float = maxf(1.0, float(merc.stats.get("maximum_hit_points", 1)))
		EncounterLogger.log_verbose("AP FALLBACK: %s cannot attack, %s %s (hp=%.0f%% ap=%d)" % [
			merc.merc_name, action_name, nearest.merc_name,
			100.0 * float(maxi(0, merc.current_hp)) / max_hp, merc.current_ap + merc.excess_ap])
	var plan: Dictionary = MovementDecider.plan_moves(merc, enemies, state)
	return {"type": "move", "action_name": action_name, "target": nearest, "flank_ally": null,
		"moves_allowed": int(plan["moves_allowed"]), "reserve_ap": int(plan["reserve_ap"])}


#Special arm of the turn slot loop; a special that spends nothing ends the turn.
static func run_special_arm(merc: MercenaryData, decision: Dictionary, state: BattleState,
		enhancements: int, turn: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var _spec_ctx := {"enhancements": enhancements}
	var _spec_ap := merc.current_ap + merc.excess_ap
	var _spec_pool := state.get_pace_pool(merc)
	var _spec_pos := state.pos3(merc)
	var spec_lines := SpecialActionSystem.execute(decision, merc, state, _spec_ctx)
	lines.append_array(spec_lines)
	if spec_lines.is_empty():
		turn["stop"] = true
		return lines
	if merc.current_ap + merc.excess_ap == _spec_ap and state.get_pace_pool(merc) == _spec_pool \
			and state.pos3(merc) == _spec_pos:
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("SLOT %d: %s spent nothing, ending turn" % [
				int(turn["action_slot"]), str(decision["action_name"])])
		turn["stop"] = true
		return lines
	if decision["action_name"] == "aim":
		turn["weapon_action_taken"] = true
	return lines
