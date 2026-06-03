class_name ActionDispatcher

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

const INJECTION_POINTS: Dictionary = {
	40: "pre_move",
	60: "pre_aim",
}

const TIER_SNAP_GATES: Dictionary = {
	60: {"has_valid_target": true},
}


static func _cn(merc: MercenaryData, state: BattleState) -> String:
	var first := merc.merc_name.get_slice(" ", 0)
	for i: int in range(state.teams.size()):
		if (state.teams[i] as Array).has(merc):
			return "[color=%s]%s[/color]" % ["white" if i == 0 else "yellow", first]
	return first


static func get_enemies_within(merc: MercenaryData, paces: int, state: BattleState) -> Array[MercenaryData]:
	var result: Array[MercenaryData] = []
	for enemy: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(enemy):
			continue
		if state.battlefield == null or state.distance_to(merc, enemy) <= paces:
			result.append(enemy)
	return result


static func do_whip_choke_ap_spend(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var whip_target: MercenaryData = null
	for enemy: MercenaryData in state.get_enemies(merc):
		if enemy.active_states.get("whip_grappled_by") == merc and BattleState._is_alive(enemy):
			whip_target = enemy
			break
	if whip_target == null:
		return lines
	var has_whip_choke := false
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if perk.effect_dsl.begins_with("on_grapple:"):
			has_whip_choke = true
			break
	if not has_whip_choke:
		return lines
	while state.can_afford(merc, 1):
		state.spend_ap(merc, 1)
		lines.append_array(CombatApplicator.apply_damage(merc, whip_target, 1, "Direct", state))
		lines.append("  %s tightens the whip choke for 1 Direct damage!" % _cn(merc, state))
		if not BattleState._is_alive(whip_target):
			whip_target.active_states.erase("whip_grappled_by")
			break
	return lines


static func choose_perk_action(merc: MercenaryData, target: MercenaryData, state: BattleState) -> TraitData:
	if target == null:
		return null
	var best: TraitData = null
	var best_is_aoe := false
	var adj_enemy_count := get_enemies_within(merc, 1, state).size()
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(merc):
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
		if merc.current_ep < ep_cost or merc.current_rep < rep_cost:
			continue
		var effect_start := 2
		for idx in range(2, parts.size()):
			if parts[idx] in ["ep", "rep", "once_per_combat"]:
				if idx + 1 < parts.size():
					effect_start = idx + 2
		var effect := parts[effect_start] if parts.size() > effect_start else ""
		var is_aoe := effect == "attack_all_adjacent_max_1"
		if best == null or (is_aoe and not best_is_aoe and adj_enemy_count >= 2):
			best = perk
			best_is_aoe = is_aoe
	return best


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
	state.spend_ap(merc, ap_cost)

	var effect_start := 2
	var j := 2
	while j < parts.size() - 1:
		if parts[j] == "ep":
			merc.current_ep -= int(parts[j + 1])
			effect_start = j + 2
			j += 2
		elif parts[j] == "rep":
			merc.current_rep -= int(parts[j + 1])
			effect_start = j + 2
			j += 2
		elif parts[j] == "once_per_combat":
			effect_start = j + 1
			j += 1
		else:
			break

	var effect := parts[effect_start] if parts.size() > effect_start else ""
	match effect:
		"attack_already_damaged":
			var attacks_taken: int = state.escalation.get(merc, {}).get("Attack", 0)
			if attacks_taken > 0 and target != null:
				var atk := AttackSystem.execute_attack(merc, enhancements, 0, target)
				lines.append("  %s uses Uppercut!" % _cn(merc, state))
				state.record_action(merc, "Attack")
				if atk.get("misfired", false):
					lines.append("  %s misfires!" % _cn(merc, state))
				elif atk.get("no_ammo", false):
					lines.append("  %s has no ammo loaded!" % _cn(merc, state))
				elif atk.get("damage", 0) > 0:
					lines.append_array(CombatApplicator.apply_damage(merc, target, atk["damage"], atk["damage_type"], state))
				else:
					lines.append("  %s misses with Uppercut against %s." % [_cn(merc, state), _cn(target, state)])
			else:
				merc.current_ap += ap_cost
				return []
		"attack_all_adjacent_max_1":
			var adj_enemies := get_enemies_within(merc, 1, state)
			if not adj_enemies.is_empty():
				lines.append("  %s spins!" % _cn(merc, state))
				for enemy: MercenaryData in adj_enemies:
					var atk := AttackSystem.execute_attack(merc, enhancements, 0, enemy)
					state.record_action(merc, "Attack")
					if atk.get("misfired", false):
						lines.append("  %s misfires!" % _cn(merc, state))
						break
					elif atk.get("damage", 0) > 0:
						lines.append_array(CombatApplicator.apply_damage(merc, enemy, 1, atk["damage_type"], state))
					else:
						lines.append("  %s misses %s with the spin." % [_cn(merc, state), _cn(enemy, state)])
			else:
				merc.current_ap += ap_cost
				return []
		"attack_fully_loaded":
			if target != null and merc.equipped_weapon != null:
				var w := merc.equipped_weapon
				if merc.ammo_loaded >= w.chamber:
					var atk := AttackSystem.execute_attack(merc, enhancements, 0, target)
					lines.append("  %s fires rapidly!" % _cn(merc, state))
					state.record_action(merc, "Attack")
					if atk.get("misfired", false):
						lines.append("  %s misfires!" % _cn(merc, state))
					elif atk.get("no_ammo", false):
						lines.append("  %s has no ammo loaded!" % _cn(merc, state))
					elif atk.get("damage", 0) > 0:
						lines.append_array(CombatApplicator.apply_damage(merc, target, atk["damage"], atk["damage_type"], state))
					else:
						lines.append("  %s misses with Rapid-Fire against %s." % [_cn(merc, state), _cn(target, state)])
				else:
					merc.current_ap += ap_cost
					return []
			else:
				merc.current_ap += ap_cost
				return []
		_:
			merc.current_ap += ap_cost
			return []
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


static func _run_pre_move_injection(
		merc: MercenaryData,
		enemies: Array[MercenaryData],
		valid_targets: Array[MercenaryData],
		state: BattleState,
		movement_blocked: bool,
		weapon_action_taken: bool,
		is_desperate: bool) -> Dictionary:
	if merc.ammo_loaded == 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("INJECTED [reload]: %s (chamber empty, pre-40)" % merc.merc_name)
		return {"type": "reload", "action_name": "reload", "target": null}
	if not weapon_action_taken:
		var wp := CombatDecision._decide_weapon_action(merc, enemies, state, _CONFIG.attack_base_ap, movement_blocked)
		if wp["type"] != "none":
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
		return CombatDecision.decide_next_action(
			merc, enemies, valid_targets, allies, current_target, state,
			_CONFIG.attack_base_ap, _CONFIG.move_base_ap, {}, movement_blocked, weapon_action_taken)

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

	if merc.ammo_loaded == 0 and CombatDecision._should_reload(merc, enemies, valid_targets, state):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("INJECTED [reload]: %s (chamber empty)" % merc.merc_name)
		return {"type": "reload", "action_name": "reload", "target": null}

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
		return {"type": "pass", "action_name": "", "target": null}

	var sorted_actions: Array = merc.action_set.actions.duplicate()
	sorted_actions.sort_custom(func(a: ActionData, b: ActionData) -> bool: return a.priority < b.priority)

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
					_weapon_ok = false
					for _sv in merc.ammo_inventory.values():
						if int(_sv) > 0:
							_weapon_ok = true
							break
				elif _eq.misfire > 0 and (FirearmReliabilityFacet.compute(merc) * 2.5 + 2.0) / 4.5 < 0.50:
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

		if action.can_execute(merc, ctx):
			if EncounterLogger.is_active():
				var verbose: Dictionary = action.decision.evaluate_verbose(merc, ctx)
				EncounterLogger.log_verbose("DECISION [%s]: score=%.2f threshold=%.2f -> %s" % [
					action.action_name, verbose["score"], action.decision.threshold,
					"PASS" if verbose["passed"] and verbose["score"] >= action.decision.threshold else "fail"])
				for fd: Dictionary in verbose["facets"]:
					var weight_str := "req" if fd["required"] else "w=%.1f" % fd["weight"]
					var score_str := "skipped" if fd.get("skipped", false) else "%.2f" % fd["score"]
					EncounterLogger.log_verbose("    %s [%s]: %s" % [fd["name"], weight_str, score_str])
				if verbose["passed"] and verbose["score"] >= action.decision.threshold:
					if action.action_name == "attack_obstacle":
						return CombatDecision.decide_obstacle_or_flank(merc, enemies, valid_targets, state, movement_blocked)
					return action.to_decision_dict(merc, ctx)
			else:
				var score: float = action.decision.evaluate(merc, ctx)
				if score >= action.decision.threshold:
					if action.action_name == "attack_obstacle":
						return CombatDecision.decide_obstacle_or_flank(merc, enemies, valid_targets, state, movement_blocked)
					return action.to_decision_dict(merc, ctx)

	return {"type": "pass", "action_name": "", "target": null}
