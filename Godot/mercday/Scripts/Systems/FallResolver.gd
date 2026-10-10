class_name FallResolver

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")


#Decision context for the break fall reaction.
static func _fall_ctx(merc: MercenaryData, fall_distance: int, state: BattleState) -> Dictionary:
	return {
		"state": state,
		"fall_distance": fall_distance,
		"allies": state.get_allies(merc),
		"enemies": state.get_enemies(merc),
		"valid_targets": [],
		"current_target": null,
		"attack_base_ap": _CONFIG.attack_base_ap,
		"move_base_ap": _CONFIG.move_base_ap,
	}


static func resolve_fall(merc: MercenaryData, fall_distance: int, state: BattleState) -> Array[String]:
	if fall_distance <= 0:
		return []
	var lines: Array[String] = []
	lines.append("  %s falls %d Pace%s!" % [BattleState.colored_name(merc, state), fall_distance,
		"s" if fall_distance != 1 else ""])
	var damage := fall_distance
	var break_fall_attempted := false
	if merc.action_set != null:
		for action: ActionData in merc.action_set.actions:
			if not action.is_reactive or action.trigger != "merc_falls":
				continue
			var fall_ep := CombatApplicator.state_ep_cost(merc, action.ep_cost, "reaction")
			if fall_ep >= 0 and ExcessPool.available_ep(merc) >= fall_ep \
					and action.decision.evaluate(merc, _fall_ctx(merc, fall_distance, state)) >= action.decision.threshold:
				ExcessPool.pay_ep(merc, fall_ep)
				damage = do_break_fall(merc, fall_distance, state, lines)
				break_fall_attempted = true
			break
	if damage > 0:
		if EncounterLogger.is_active() and not break_fall_attempted:
			EncounterLogger.log_verbose("Fall damage: %d raw (no break fall attempt)" % fall_distance)
		lines.append_array(CombatApplicator.apply_damage(merc, merc, damage, "Fall", state))
		var size := ConstStates.knockdown_size(merc)
		if EncounterLogger.is_active():
			if damage >= size:
				EncounterLogger.log_verbose("Deposed check: final_damage (%d) >= knockdown size (%d) -> Deposed" % [damage, size])
			else:
				EncounterLogger.log_verbose("Deposed check: final_damage (%d) < knockdown size (%d) -> no Deposed" % [damage, size])
		if damage >= size and not ConstStates.has_state(merc, ConstStates.DEPOSED):
			if StateCascade.apply_state(merc, ConstStates.DEPOSED, null, "", "engine:fall"):
				lines.append("  %s lands hard and is [b]Deposed[/b]!" % BattleState.colored_name(merc, state))
			else:
				lines.append("  %s lands hard but is immune to Deposed." % BattleState.colored_name(merc, state))
	return lines


static func do_break_fall(merc: MercenaryData, fall_distance: int, state: BattleState, lines: Array[String]) -> int:
	if int(merc.stats.get("fly", 0)) > 0 and not StateEffects.is_blocked(merc, "ability:fly"):
		lines.append("  %s uses their flight to land safely!" % BattleState.colored_name(merc, state))
		return 0
	var dex_def := {
		"stat_keys": ["dexterity"],
		"circumstances": ["Resist (Dexterity)", "Grace (Dexterity)"],
		"knowledges": ["Urban", "Colosseum"],
		"formula": "parkour",
	}
	var vig_def := {
		"stat_keys": ["vigor"],
		"circumstances": ["Athletics (Vigor)"],
		"knowledges": ["Urban", "Colosseum"],
		"formula": "tolerance",
	}
	var chosen_def: Dictionary = dex_def if break_fall_expected(merc, dex_def) >= break_fall_expected(merc, vig_def) else vig_def
	var result := CheckSystem.make_check(merc, chosen_def)
	var successes: int = result["successes"]
	var formula_label := "Parkour" if str(chosen_def["formula"]) == "parkour" else "Tolerance"
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("BREAK FALL (%s): rolls=%s vs %.0f%% -> %d success %d fail" % [
			merc.merc_name, str(result["roll2"]), result["threshold"],
			successes, result["failures"]])
	lines.append("  %s Break Fall [%s: %d]" % [BattleState.colored_name(merc, state), formula_label, successes])
	var final_damage := maxi(0, fall_distance - successes)
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("Fall damage: %d raw - %d reduced = %d final" % [
			fall_distance, mini(successes, fall_distance), final_damage])
	return final_damage


static func break_fall_expected(merc: MercenaryData, def: Dictionary) -> float:
	var stat_key := str((def["stat_keys"] as Array)[0])
	var formula_key := str(def.get("formula", ""))
	var bsc := clampf(float(merc.stats.get("base_success_chance", 0.0)), 0.0, 100.0)
	var formula_val := clampf(float(merc.stats.get(formula_key, 0.0)), 0.0, 100.0)
	var circ_bonus := 0.0
	for circ: String in def.get("circumstances", []):
		if circ.ends_with("(" + stat_key.capitalize() + ")") and merc.circumstance_flags.get(circ, false):
			circ_bonus = 15.0 + merc.circumstance_additional_bonus.get(circ, 0.0)
			break
	var k_bonus := 0
	var k_name := ""
	for kname: String in def.get("knowledges", []):
		for k: UtilityTraitData in merc.knowledges:
			if k.utility_name == kname:
				k_bonus = 1
				k_name = k.utility_name
				break
		if k_bonus > 0:
			break
	if k_name != "":
		k_bonus += int(merc.trained_bonus.get("knowledge:" + k_name, 0))
	var threshold := clampf(formula_val + circ_bonus + bsc, 0.01, 100.0)
	var p_reroll := clampf(float(merc.stats.get("reroll", 0.0)) / 100.0, 0.0, 1.0)
	var p_base := threshold / 100.0
	var p_eff := p_base + (1.0 - p_base) * p_reroll * p_base
	return (maxi(1, int(merc.stats.get(stat_key, 0))) + k_bonus) * p_eff


static func fall_from_wall(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var cd: Dictionary = state.get_climbing_data(merc)
	var fall_h := int(cd.get("current_h", 0))
	#A down climber holds the height still under it, not the paces it has covered.
	if cd.get("down", false):
		fall_h = int(cd.get("target_h", 0)) - fall_h
	state.clear_climbing(merc)
	StateCascade.remove_state(merc, ConstStates.CLIMBING)
	state.set_height(merc, 0)
	if fall_h > 0:
		lines.append_array(resolve_fall(merc, fall_h, state))
	return lines
