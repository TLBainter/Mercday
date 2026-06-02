class_name CombatApplicator

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

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


static func apply_damage(
		attacker: MercenaryData,
		defender: MercenaryData,
		damage: int,
		damage_type: String,
		state: BattleState,
		extra_enhancements: int = 0) -> Array[String]:
	var lines: Array[String] = []
	if defender == null:
		push_error("apply_damage: defender is null (attacker=%s damage=%d type=%s)" % [
			attacker.merc_name if attacker != null else "null", damage, damage_type])
		return lines
	var was_dying := ConstStates.has_state(defender, ConstStates.DYING)
	var used_excess_ap := false

	var free_def := false
	if state.battlefield != null:
		free_def = state.is_covered_from(defender, attacker, ConstStates.COVERED_PARTIAL)
		if free_def and EncounterLogger.is_active():
			EncounterLogger.log_verbose("FREE DEF: %s has terrain/cover advantage over %s" % [
				defender.merc_name, attacker.merc_name])

	var excess_needed := 2 if ConstStates.has_state(defender, ConstStates.SLOWED) else 1

	var worth_defending := free_def or CombatDecision.should_attempt_defense(defender, damage, damage_type)

	if worth_defending and not free_def:
		if defender.excess_ap >= excess_needed \
				and not ConstStates.has_state(defender, ConstStates.DEBILITATED):
			defender.excess_ap -= excess_needed
			used_excess_ap = true

	var defense_free := free_def or used_excess_ap
	var res := DefenseSystem.resolve(defender, damage, damage_type, extra_enhancements, defense_free, not worth_defending)
	if EncounterLogger.is_active():
		for key: String in ["defend_result", "dodge_result"]:
			if res.has(key) and not (res[key] as Dictionary).is_empty():
				var dr: Dictionary = res[key]
				EncounterLogger.log_verbose("DEFENSE ROLL (%s): %s vs %.0f%% -> %d hit %d miss  blocked=%d" % [
					key.replace("_result", ""), str(dr["roll2"]), dr["threshold"],
					dr["successes"], dr["failures"],
					int(res.get("defend_reduction" if key == "defend_result" else "dodge_reduction", 0))])
		if res["final_damage"] == 0 and res["modified_damage"] > 0:
			EncounterLogger.log_verbose("DAMAGE BLOCKED: %d %s fully blocked by defense (free_def=%s)" % [
				res["modified_damage"], damage_type, str(free_def)])
	var atk_name := _cn(attacker, state)
	var def_name := _cn(defender, state)

	if res["is_immune"]:
		lines.append("  %s is immune to %s." % [def_name, damage_type])
		return lines

	var in_dmg: int = res["modified_damage"]
	var final_dmg: int = res["final_damage"]
	if final_dmg > 0:
		defender.aim_active = false
		defender.combat_idle_rounds = 0
	var defended: bool = res["ep_spent"] > 0
	var res_type := "ExAP" if used_excess_ap else "EP"
	var res_amount: int = excess_needed if used_excess_ap else res["ep_spent"]

	lines.append("  %s [color=red][%d][/color] %s v %s" % [atk_name, in_dmg, damage_type, def_name])
	if defended or used_excess_ap:
		var def_label := "Dodge" if res.get("reduction_source", "") == "dodge" else "Defend"
		lines.append("  %s -%d %s, %s [color=red][%d][/color]" % [def_name, res_amount, res_type, def_label, in_dmg - final_dmg])
	if final_dmg > 0:
		lines.append("  %s: HP [color=red]%d[/color]" % [def_name, defender.current_hp])

	var pain_limit := int(defender.stats.get("pain_limit", 0))
	if not was_dying and pain_limit > 0 and final_dmg >= pain_limit:
		var num_checks := 1 + (final_dmg - pain_limit)
		var _eap_pre := defender.excess_ap; var _ap_pre := defender.current_ap
		var _ep_pre := defender.current_ep; var _hp_pre := defender.current_hp
		lines.append_array(apply_pain_limit_checks(defender, num_checks, def_name))
		lines.append_array(handle_on_pain_perks(attacker, defender, num_checks, state))
		if ConstStates.has_state(defender, ConstStates.CLIMBING):
			var _pain_failed := (defender.excess_ap != _eap_pre or defender.current_ap != _ap_pre
				or defender.current_ep != _ep_pre or defender.current_hp != _hp_pre)
			if _pain_failed:
				lines.append("  %s loses their grip from the pain!" % def_name)
				lines.append_array(fall_from_wall(defender, state))
	elif not was_dying and pain_limit > 0 and final_dmg > 0:
		for _perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
			if _perk.effect_dsl.begins_with("weapon_passive:force_pain_response_within:"):
				var _range: int = int(_perk.effect_dsl.get_slice(":", 2))
				if state.battlefield == null or state.distance_to(attacker, defender) <= _range:
					var _eap_pre2 := defender.excess_ap; var _ap_pre2 := defender.current_ap
					var _ep_pre2 := defender.current_ep; var _hp_pre2 := defender.current_hp
					lines.append_array(apply_pain_limit_checks(defender, 1, def_name))
					if ConstStates.has_state(defender, ConstStates.CLIMBING):
						var _pain_failed2 := (defender.excess_ap != _eap_pre2 or defender.current_ap != _ap_pre2
							or defender.current_ep != _ep_pre2 or defender.current_hp != _hp_pre2)
						if _pain_failed2:
							lines.append("  %s loses their grip from the pain!" % def_name)
							lines.append_array(fall_from_wall(defender, state))
				break

	if final_dmg >= 1 and was_dying:
		defender.current_hp = -1
		ConstStates.remove_state(defender, ConstStates.DYING)
		lines.append("  %s is dead!" % def_name)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DEATH CONFIRMED: %s - struck while Dying (final_dmg=%d)" % [
				defender.merc_name, final_dmg])
		lines.append_array(handle_on_kill_perks(attacker, defender, state))
	elif defender.current_hp <= 0 and not was_dying:
		defender.current_hp = 0
		ConstStates.apply_state(defender, ConstStates.DYING)
		lines.append("  %s is dying!" % def_name)
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DYING STATE: %s - hp reached 0, cheat death roll pending next turn" % defender.merc_name)

	if final_dmg > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("HP RESULT: %s hp=%d (final_dmg=%d free_def=%s)" % [
			defender.merc_name, defender.current_hp, final_dmg, str(free_def)])

	state.record_damage_dealt(attacker, defender, final_dmg)

	if damage_type == "Frost" and final_dmg > 0:
		var cur_spd := int(defender.stats.get("speed", 0))
		if cur_spd > 0:
			defender.stats["speed"] = max(0, cur_spd - 10)
			lines.append("  %s's Speed reduced by 10 from Frost!" % def_name)

	if damage_type == "Rot" and final_dmg > 0:
		defender.rot_hp_loss += final_dmg
		lines.append("  %s's maximum HP reduced by %d from Rot!" % [def_name, final_dmg])

	return lines


static func apply_pain_limit_checks(
		defender: MercenaryData,
		num_checks: int,
		def_name: String) -> Array[String]:
	var lines: Array[String] = []
	var tolerance := clampf(float(defender.stats.get("tolerance", 0.0)), 0.0, 100.0)
	var excess_ap_lost := 0
	var ap_lost := 0
	var ep_lost := 0
	var hp_lost := 0

	var max_ap := int(defender.stats.get("action_points", 5))
	for _i in range(num_checks):
		if randi_range(1, 100) > tolerance:
			if defender.excess_ap > 0:
				defender.excess_ap -= 1
				excess_ap_lost += 1
			elif defender.current_ap > 0:
				defender.current_ap -= 1
				ap_lost += 1
			elif defender.ap_debt < max_ap:
				defender.ap_debt += 1
				ap_lost += 1
			elif defender.current_ep > 0:
				defender.current_ep -= 1
				ep_lost += 1
			else:
				defender.current_hp -= 1
				hp_lost += 1

	var total_failures := excess_ap_lost + ap_lost + ep_lost + hp_lost
	if total_failures == 0:
		lines.append("  %s passes %d pain." % [def_name, num_checks])
	else:
		var lost_parts: Array[String] = []
		if excess_ap_lost > 0: lost_parts.append("%d ExAP" % excess_ap_lost)
		if ap_lost > 0: lost_parts.append("%d AP" % ap_lost)
		if ep_lost > 0: lost_parts.append("%d EP" % ep_lost)
		if hp_lost > 0: lost_parts.append("%d HP" % hp_lost)
		lines.append("  %s fails %d/%d pain: -%s." % [
			def_name, total_failures, num_checks, ", ".join(lost_parts)])
	return lines


static func handle_on_kill_perks(
		attacker: MercenaryData, defender: MercenaryData,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var two_handed := WeaponArmorPerkLibrary.is_wielding_two_handed(attacker)
	var target_size := int(defender.stats.get("size", 1))

	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
		if not perk.effect_dsl.begins_with("on_kill:"):
			continue
		var parts := perk.effect_dsl.split(":")
		var cond    := parts[1] if parts.size() > 1 else ""
		var subcond := parts[2] if parts.size() > 2 else ""
		var effect  := parts[3] if parts.size() > 3 else ""
		var val     := parts[4] if parts.size() > 4 else "0"
		if cond == "two_handed" and not two_handed:
			continue
		if subcond == "size_1_plus" and target_size < 1:
			continue
		if effect == "gain_rep":
			attacker.current_rep += int(val)
			lines.append("  %s gains %s ReP (Severance)!" % [_cn(attacker, state), val])

	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		if not perk.effect_dsl.begins_with("reactive_action:on_kill:"):
			continue
		var parts := perk.effect_dsl.split(":")
		if parts.size() < 4:
			continue
		var kill_cond   := parts[2]
		var kill_effect := parts[3]
		if kill_cond == "two_handed" and not two_handed:
			continue
		if attacker.current_ep < 1:
			continue
		if kill_effect == "attack_new_target":
			var nearby := get_enemies_within(attacker, 2, state)
			nearby.erase(defender)
			if nearby.is_empty():
				continue
			attacker.current_ep -= 1
			var new_target := nearby[0] as MercenaryData
			var atk := AttackSystem.execute_attack(attacker, 0, 0, new_target)
			lines.append("  %s spends 1 EP (Chain) to attack %s!" % [_cn(attacker, state), _cn(new_target, state)])
			if atk.get("damage", 0) > 0:
				lines.append_array(apply_damage(attacker, new_target, atk["damage"], atk["damage_type"], state))
			else:
				lines.append("  %s misses %s." % [_cn(attacker, state), _cn(new_target, state)])
		elif kill_effect == "destroy_body":
			attacker.current_ep -= 1
			lines.append("  %s spends 1 EP (Obliteration) and destroys the body!" % _cn(attacker, state))

	return lines


static func handle_on_pain_perks(
		attacker: MercenaryData,
		defender: MercenaryData,
		_num_checks: int,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
		if perk.effect_dsl.begins_with("on_pain:direct:"):
			var parts := perk.effect_dsl.split(":")
			if parts.size() >= 4:
				var amt: int = int(parts[2])
				var timing: String = parts[3]
				attacker.deferred_effects.append({
					"target": defender, "damage": amt,
					"type": "Direct", "timing": timing
				})
				lines.append("  %s will take %d Direct damage at %s (bleedout)." % [
					_cn(defender, state), amt, timing])
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		if perk.effect_dsl.begins_with("reactive_action:on_pain:repeat_pain_response"):
			if attacker.current_ep >= 1:
				attacker.current_ep -= 1
				lines.append("  %s spends 1 EP - Pain repeats!" % _cn(attacker, state))
				lines.append_array(apply_pain_limit_checks(defender, 1, _cn(defender, state)))
			break
	return lines


static func resolve_fall(merc: MercenaryData, fall_distance: int, state: BattleState) -> Array[String]:
	if fall_distance <= 0:
		return []
	var lines: Array[String] = []
	lines.append("  %s falls %d Pace%s!" % [_cn(merc, state), fall_distance, "s" if fall_distance != 1 else ""])
	var damage := fall_distance
	var break_fall_attempted := false
	if merc.action_set != null:
		for action: ActionData in merc.action_set.actions:
			if action.is_reactive and action.trigger == "merc_falls":
				if merc.current_ep >= action.ep_cost:
					var ctx := {
						"state": state,
						"fall_distance": fall_distance,
						"allies": state.get_allies(merc),
						"enemies": state.get_enemies(merc),
						"valid_targets": [],
						"current_target": null,
						"attack_base_ap": _CONFIG.attack_base_ap,
						"move_base_ap": _CONFIG.move_base_ap,
					}
					if action.decision.evaluate(merc, ctx) >= action.decision.threshold:
						merc.current_ep -= action.ep_cost
						damage = do_break_fall(merc, fall_distance, state, lines)
						break_fall_attempted = true
				break
	if damage > 0:
		if EncounterLogger.is_active() and not break_fall_attempted:
			EncounterLogger.log_verbose("Fall damage: %d raw (no break fall attempt)" % fall_distance)
		lines.append_array(apply_damage(merc, merc, damage, "Fall", state))
		var size := int(merc.stats.get("size", 1))
		if EncounterLogger.is_active():
			if damage >= size:
				EncounterLogger.log_verbose("Deposed check: final_damage (%d) >= size (%d) -> Deposed" % [damage, size])
			else:
				EncounterLogger.log_verbose("Deposed check: final_damage (%d) < size (%d) -> no Deposed" % [damage, size])
		if damage >= size:
			if not ConstStates.has_state(merc, ConstStates.DEPOSED):
				ConstStates.apply_state(merc, ConstStates.DEPOSED)
				lines.append("  %s lands hard and is [b]Deposed[/b]!" % _cn(merc, state))
	return lines


static func do_break_fall(merc: MercenaryData, fall_distance: int, state: BattleState, lines: Array[String]) -> int:
	if int(merc.stats.get("fly", 0)) > 0 and not ConstStates.has_state(merc, ConstStates.GROUNDED):
		lines.append("  %s uses their flight to land safely!" % _cn(merc, state))
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
			_cn(merc, state), str(result["roll2"]), result["threshold"],
			successes, result["failures"]])
	lines.append("  %s Break Fall [%s: %d]" % [_cn(merc, state), formula_label, successes])
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
	for kname: String in def.get("knowledges", []):
		for k: UtilityTraitData in merc.knowledges:
			if k.utility_name == kname:
				k_bonus = 1
				break
		if k_bonus > 0:
			break
	var threshold := clampf(formula_val + circ_bonus + bsc, 0.01, 100.0)
	var p_reroll := clampf(float(merc.stats.get("reroll", 0.0)) / 100.0, 0.0, 1.0)
	var p_base := threshold / 100.0
	var p_eff := p_base + (1.0 - p_base) * p_reroll * p_base
	return (maxi(1, int(merc.stats.get(stat_key, 0))) + k_bonus) * p_eff


static func fall_from_wall(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var cd: Dictionary = state.get_climbing_data(merc)
	var fall_h := int(cd.get("current_h", 0))
	state.clear_climbing(merc)
	ConstStates.remove_state(merc, ConstStates.CLIMBING)
	var ground_h := int(round(state.battlefield.get_terrain_height(state.get_position(merc)))) if state.battlefield != null else 0
	state.set_height(merc, ground_h)
	if fall_h > 0:
		lines.append_array(resolve_fall(merc, fall_h, state))
	return lines
