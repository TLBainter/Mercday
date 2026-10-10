class_name CombatApplicator

const _CONFIG := preload("res://Scripts/Actions/Resources/BattleConfig.tres")

#Whether the last apply_damage marked hit points only through a damage type's min 1 floor.
static var last_min_1_only: bool = false

static func get_enemies_within(merc: MercenaryData, paces: int, state: BattleState) -> Array[MercenaryData]:
	var result: Array[MercenaryData] = []
	for enemy: MercenaryData in state.get_enemies(merc):
		if not BattleState._is_alive(enemy):
			continue
		if state.battlefield == null or state.distance_to(merc, enemy) <= paces:
			result.append(enemy)
	return result


#hit_dealt then damage_taken on the resolved damage; re-applies the HP loss the way defence does.
#res carries the pre-defence pools and the split DefenseSystem already took.
static func _fire_damage_triggers(attacker: MercenaryData, defender: MercenaryData, final_dmg: int,
		damage_type: String, state: BattleState, lines: Array[String], res: Dictionary) -> int:
	var hp_pre: int = int(res.get("hp_pre_defense", 0))
	var adjusted: int = final_dmg
	if attacker != null and TraitRuntime.has(attacker, "hit_dealt"):
		var hd: Dictionary = {"damage": adjusted, "damage_type": damage_type, "state": state,
			"target": defender, "lines": lines}
		TraitRuntime.fire("hit_dealt", attacker, hd)
		adjusted = int(hd["damage"])
	if TraitRuntime.has(defender, "damage_taken"):
		var dt: Dictionary = {"damage": adjusted, "damage_type": damage_type, "state": state,
			"target": attacker, "lines": lines}
		TraitRuntime.fire("damage_taken", defender, dt)
		adjusted = int(dt["damage"])
	if adjusted == final_dmg:
		return final_dmg
	adjusted = maxi(0, adjusted)
	var excess_pre: int = int(res.get("excess_pre_defense", 0))
	var hp_floor := 0
	if bool(ConstDamageTypes.get_type(damage_type).get("will_hp_floor", false)):
		hp_floor = 1
		adjusted = mini(adjusted, maxi(0, excess_pre + hp_pre - 1))
	var absorbed: int = int(res.get("excess_hp_absorbed", 0)) + int(res.get("hp_absorbed", 0))
	var wanted: int = mini(adjusted, excess_pre + maxi(0, hp_pre - hp_floor))
	if wanted < absorbed:
		var back: int = absorbed - wanted
		var hp_back: int = mini(back, int(res.get("hp_absorbed", 0)))
		ExcessPool.refund_hp(defender, back - hp_back, hp_back)
	elif wanted > absorbed:
		ExcessPool.take_hp(defender, wanted - absorbed, hp_floor)
	return adjusted


static func apply_damage(
		attacker: MercenaryData,
		defender: MercenaryData,
		damage: int,
		damage_type: String,
		state: BattleState,
		extra_enhancements: int = 0,
		force_direct: bool = false,
		defense_flaws: int = 0) -> Array[String]:
	var lines: Array[String] = []
	last_min_1_only = false
	if defender == null:
		push_error("apply_damage: defender is null (attacker=%s damage=%d type=%s)" % [
			attacker.merc_name if attacker != null else "null", damage, damage_type])
		return lines
	CaveInSystem.note_damage(state, damage_type, damage)
	var was_dying := ConstStates.has_state(defender, ConstStates.DYING)
	var res: Dictionary = {}
	if force_direct:
		res = _resolve_direct(defender, damage, damage_type, state, lines)
		if attacker != null and not res.is_empty():
			res["atk_name"] = BattleState.colored_name(attacker, state)
	else:
		res = _resolve_defence(attacker, defender, damage, damage_type, state, extra_enhancements, lines,
			defense_flaws)
	if res.is_empty():
		last_min_1_only = false
		return lines
	#Nested damage resolves its own defence, so this hit's flag is held here and written back at the end.
	var floor_only: bool = bool(res.get("min_1_only", false))
	var def_name: String = res["def_name"]
	var final_dmg := _apply_hp_and_states(attacker, defender, damage_type, state, res, lines)
	_check_pain_and_dying(attacker, defender, damage_type, state, final_dmg, was_dying,
		def_name, bool(res["free_def"]), lines)
	state.record_damage_dealt(attacker, defender, final_dmg)
	LifepathTally.record_damage_taken(defender, final_dmg, damage_type)
	if attacker != null and attacker != defender and state != null \
			and int(state._merc_team_index.get(attacker, -1)) \
			!= int(state._merc_team_index.get(defender, -2)):
		LifepathTally.record_damage_dealt_total(attacker, final_dmg)
	_apply_element_effects(attacker, defender, damage_type, state, final_dmg, def_name, lines)
	last_min_1_only = floor_only
	return lines


#Records who struck whom and the defender state before defence on a resolved hit.
static func _fill_result(res: Dictionary, atk_name: String, def_name: String, free_def: bool, used_excess_ap: bool,
		excess_needed: int, hp_pre_defense: int, excess_pre_defense: int) -> void:
	res["atk_name"] = atk_name
	res["def_name"] = def_name
	res["free_def"] = free_def
	res["used_excess_ap"] = used_excess_ap
	res["excess_needed"] = excess_needed
	res["hp_pre_defense"] = hp_pre_defense
	res["excess_pre_defense"] = excess_pre_defense


#A hit with no attacker behind it: no cover, no defence roll, the damage lands direct.
static func _resolve_direct(defender: MercenaryData, damage: int, damage_type: String,
		state: BattleState, lines: Array[String]) -> Dictionary:
	var hp_pre_defense: int = defender.current_hp
	var excess_pre_defense: int = defender.excess_hp
	var res := DefenseSystem.resolve(defender, damage, damage_type, 0, false, true, true)
	var def_name := BattleState.colored_name(defender, state)
	if res["is_immune"]:
		lines.append("  %s is immune to %s." % [def_name, damage_type])
		return {}
	_fill_result(res, "the rubble", def_name, false, false, 0, hp_pre_defense, excess_pre_defense)
	return res


#Cover, excess AP and the defence roll; an empty return means the defender was immune.
static func _resolve_defence(attacker: MercenaryData, defender: MercenaryData, damage: int,
		damage_type: String, state: BattleState, extra_enhancements: int,
		lines: Array[String], defense_flaws: int = 0) -> Dictionary:
	var used_excess_ap := false
	var free_def := false
	if state.battlefield != null:
		free_def = state.is_covered_from(defender, attacker, ConstStates.COVERED_PARTIAL)
		if free_def and EncounterLogger.is_active():
			EncounterLogger.log_verbose("FREE DEF: %s has terrain/cover advantage over %s" % [
				defender.merc_name, attacker.merc_name])

	var excess_needed := StateEffects.cost_multiplier(defender, "ap")

	var worth_defending := free_def or CombatDecision.should_attempt_defense(defender, damage, damage_type)

	if not free_def \
			and defender.excess_ap >= excess_needed \
			and not StateEffects.is_blocked(defender, "spend:ap") \
			and CombatDecision.should_spend_excess_ap(defender, attacker, damage_type, state, excess_needed):
		defender.excess_ap -= excess_needed
		used_excess_ap = true
		if not worth_defending:
			worth_defending = true

	if EncounterLogger.is_active() and not worth_defending and damage > 0:
		EncounterLogger.log_verbose("DEF SKIP: %s - no EP threshold, no ExAP" % defender.merc_name)
	var defense_free := free_def or used_excess_ap
	var hp_pre_defense: int = defender.current_hp
	var excess_pre_defense: int = defender.excess_hp
	var res := DefenseSystem.resolve(defender, damage, damage_type, extra_enhancements, defense_free,
		not worth_defending, false, defense_flaws)
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
	var atk_name := BattleState.colored_name(attacker, state)
	var def_name := BattleState.colored_name(defender, state)

	var passive := str(res.get("passive_modifier", "none"))
	if attacker != null and attacker != defender and passive != "none" and passive == str(res["modifier"]):
		state.learn_token(attacker, defender, passive + ":" + damage_type.to_lower())

	if res["is_immune"]:
		lines.append("  %s is immune to %s." % [def_name, damage_type])
		return {}

	_fill_result(res, atk_name, def_name, free_def, used_excess_ap, excess_needed, hp_pre_defense, excess_pre_defense)
	return res


#Damage triggers and the damage lines; returns the damage that landed.
static func _apply_hp_and_states(attacker: MercenaryData, defender: MercenaryData,
		damage_type: String, state: BattleState, res: Dictionary, lines: Array[String]) -> int:
	var in_dmg: int = res["modified_damage"]
	var final_dmg: int = res["final_damage"]
	var used_excess_ap: bool = res["used_excess_ap"]
	var atk_name: String = res["atk_name"]
	var def_name: String = res["def_name"]
	if final_dmg > 0:
		final_dmg = _fire_damage_triggers(attacker, defender, final_dmg, damage_type, state,
			lines, res)
		in_dmg = maxi(in_dmg, final_dmg)
	if final_dmg > 0:
		defender.aim_active = false
		defender.combat_idle_rounds = 0
	var defended: bool = res["ep_spent"] > 0
	var res_type := "ExAP" if used_excess_ap else "EP"
	var res_amount: int = int(res["excess_needed"]) if used_excess_ap else int(res["ep_spent"])

	lines.append("  %s [color=red][%d][/color] %s v %s" % [atk_name, in_dmg, damage_type, def_name])
	if defended or used_excess_ap:
		var def_label := "Dodge" if res.get("reduction_source", "") == "dodge" else "Defend"
		lines.append("  %s -%d %s, %s [color=red][%d][/color]" % [def_name, res_amount, res_type, def_label, in_dmg - final_dmg])
	if final_dmg > 0:
		lines.append("  %s: HP [color=red]%d[/color]" % [def_name, maxi(0, defender.current_hp)])
	return final_dmg


#Pain limit checks, the dying and death transitions and the states damage removes.
static func _check_pain_and_dying(attacker: MercenaryData, defender: MercenaryData,
		damage_type: String, state: BattleState, final_dmg: int, was_dying: bool,
		def_name: String, free_def: bool, lines: Array[String]) -> void:
	var pain_limit := int(defender.stats.get("pain_limit", 0))
	var pain_fired := false
	if not was_dying and pain_limit > 0 and final_dmg >= pain_limit:
		_pain_checks_with_grip(attacker, defender, state, 1 + (final_dmg - pain_limit), def_name, true, lines)
		pain_fired = true
	elif not was_dying and pain_limit > 0 and final_dmg > 0 and attacker != null:
		for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
			if perk.effect_dsl.begins_with("weapon_passive:force_pain_response_within:"):
				var reach: int = int(perk.effect_dsl.get_slice(":", 2))
				if WeaponArmorPerkLibrary.is_level_20(attacker):
					reach *= 2
				if state.battlefield == null or state.distance_to(attacker, defender) <= reach:
					_pain_checks_with_grip(attacker, defender, state, 1, def_name, false, lines)
					pain_fired = true
				break
	if pain_fired:
		defender.active_states["pain_fired"] = true
		_armor_break(attacker, defender, def_name, lines)

	if state.no_death_removal and (final_dmg >= 1 or defender.current_hp <= 0) \
			and ExcessPool.hp_total(defender) <= 1:
		BattleStateUpdater.remove_without_death(defender, state, lines)
	elif final_dmg >= 1 and was_dying:
		BattleStateUpdater.kill(defender, attacker, state, lines, "  %s is dead!" % def_name,
			"DEATH CONFIRMED: %s - struck while Dying (final_dmg=%d)" % [defender.merc_name, final_dmg])
	elif final_dmg >= 1 and _try_obliterate(attacker, defender, state, def_name, lines):
		pass
	elif defender.current_hp <= 0 and not was_dying:
		BattleStateUpdater.mark_dying(defender, def_name, lines)
		state.dying_source[defender] = attacker
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DYING STATE: %s - hp reached 0, cheat death roll pending next turn" % defender.merc_name)

	if final_dmg >= 1 and not defender.is_dead and not ConstStates.has_state(defender, ConstStates.DYING) \
			and not defender.off_field:
		lines.append_array(remove_on_damage(defender, damage_type, state))

	if final_dmg > 0 and EncounterLogger.is_active():
		EncounterLogger.log_verbose("HP RESULT: %s hp=%d (final_dmg=%d free_def=%s)" % [
			defender.merc_name, maxi(0, defender.current_hp), final_dmg, str(free_def)])


#Great Club Obliteration: a living target left at 1 HP is destroyed outright for 1 EP.
static func _try_obliterate(attacker: MercenaryData, defender: MercenaryData, state: BattleState,
		def_name: String, lines: Array[String]) -> bool:
	if attacker == null or defender == null or defender.is_dead or defender.off_field:
		return false
	if ConstStates.has_state(defender, ConstStates.DYING):
		return false
	if ExcessPool.hp_total(defender) > 1:
		return false
	if "Ethereal" in defender.creature_types:
		return false
	var found: TraitData = null
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		if perk.effect_dsl.contains("on_kill:1hp:destroy_body"):
			found = perk
			break
	if found == null:
		return false
	var cost := state_ep_cost(attacker, 1, "reaction")
	if cost < 0 or ExcessPool.available_ep(attacker) < cost:
		return false
	ExcessPool.pay_ep(attacker, cost)
	BattleStateUpdater.kill(defender, attacker, state, lines,
		"  %s obliterates %s!" % [BattleState.colored_name(attacker, state), def_name],
		"OBLITERATION: %s destroys %s (no death test)" % [attacker.merc_name, defender.merc_name])
	return true


#Kills the defender outright with no death test; line_fmt takes the attacker name then the defender name.
static func slay(attacker: MercenaryData, defender: MercenaryData, state: BattleState,
		line_fmt: String) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null or defender == null or not BattleState._is_alive(defender):
		return lines
	var def_name := BattleState.colored_name(defender, state)
	lines.append(line_fmt % [BattleState.colored_name(attacker, state), def_name])
	BattleStateUpdater.kill(defender, attacker, state, lines, "  %s is dead!" % def_name,
		"SLAIN: %s kills %s (no death test)" % [attacker.merc_name, defender.merc_name])
	return lines


#Handgun Headshot: a Pain Response raised by this attack can finish the target outright.
static func pain_kill(attacker: MercenaryData, defender: MercenaryData, state: BattleState,
		label: String) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null or defender == null or not BattleState._is_alive(defender):
		return lines
	if not bool(defender.active_states.get("pain_fired", false)):
		return lines
	if "Ethereal" in defender.creature_types:
		return lines
	var trial: int = int(defender.stats.get("pain_limit", 0))
	if trial <= 0:
		return lines
	var check := CheckSystem.make_check(defender, {
		"stat_keys": ["vigor"],
		"circumstances": [],
		"knowledges": [],
		"tools": [],
		"formula": "luck",
		"flat_threshold_bonus": 0.0,
	})
	var passed: bool = int(check["successes"]) >= trial or bool(check.get("critical", false))
	lines.append("  %s: %s Vigor %d vs trial %d -> %s" % [label,
		BattleState.colored_name(defender, state), int(check["successes"]), trial,
		"holds on" if passed else "goes down"])
	defender.active_states.erase("pain_fired")
	if passed:
		return lines
	BattleStateUpdater.kill(defender, attacker, state, lines,
		"  %s is killed outright!" % BattleState.colored_name(defender, state),
		"HEADSHOT: %s kills %s (no death test)" % [attacker.merc_name, defender.merc_name])
	return lines


#An Armor Break weapon takes Armor Bonus off the defender's heavy armor until a furlough repairs it.
static func _armor_break(attacker: MercenaryData, defender: MercenaryData, def_name: String,
		lines: Array[String]) -> void:
	var amount: int = WeaponArmorPerkLibrary.armor_break_amount(attacker, defender)
	if amount <= 0:
		return
	var before: int = defender.armor_break
	defender.armor_break = mini(defender.equipped_armor.armor_bonus, before + amount)
	var lost: int = defender.armor_break - before
	if lost <= 0:
		return
	lines.append("  %s's armor is damaged (Armor Bonus -%d)." % [def_name, lost])
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("ARMOR BREAK: %s -%d (total %d)" % [
			defender.merc_name, lost, defender.armor_break])


#Pain checks and, for a climber, the grip loss any spent resource implies.
static func _pain_checks_with_grip(attacker: MercenaryData, defender: MercenaryData, state: BattleState,
		num_checks: int, def_name: String, with_perks: bool, lines: Array[String]) -> void:
	var eap_pre := defender.excess_ap
	var ap_pre := defender.current_ap
	var eep_pre := defender.excess_ep
	var ep_pre := defender.current_ep
	var ehp_pre := defender.excess_hp
	var hp_pre := defender.current_hp
	lines.append_array(apply_pain_limit_checks(defender, num_checks, def_name))
	if with_perks:
		lines.append_array(handle_on_pain_perks(attacker, defender, state))
	if not ConstStates.has_state(defender, ConstStates.CLIMBING):
		return
	if defender.excess_ap == eap_pre and defender.current_ap == ap_pre \
			and defender.excess_ep == eep_pre and defender.current_ep == ep_pre \
			and defender.excess_hp == ehp_pre and defender.current_hp == hp_pre:
		return
	lines.append("  %s loses their grip from the pain!" % def_name)
	lines.append_array(FallResolver.fall_from_wall(defender, state))


#Frost, Rot and Toxic side effects of a landed hit.
static func _apply_element_effects(attacker: MercenaryData, defender: MercenaryData,
		damage_type: String, state: BattleState, final_dmg: int, def_name: String,
		lines: Array[String]) -> void:
	if damage_type == "Frost" and final_dmg > 0:
		var cur_spd := int(defender.stats.get("speed", 0))
		if cur_spd > 0:
			defender.stats["speed"] = max(0, cur_spd - 10)
			lines.append("  %s's Speed reduced by 10 from Frost!" % def_name)

	if damage_type == "Rot" and final_dmg > 0:
		defender.rot_hp_loss += final_dmg
		lines.append("  %s's maximum HP reduced by %d from Rot!" % [def_name, final_dmg])

	var toxic := final_dmg > 0 and attacker != null and damage_type == "Toxic"
	if toxic and BattleState._is_alive(defender):
		if ConstStates.has_state(defender, ConstStates.POISONED):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("INFLICT SKIP: %s already Poisoned" % defender.merc_name)
		elif not known_immune(attacker, defender, ConstStates.POISONED, "poisoned"):
			lines.append_array(StateInfliction.inflict_default(
				defender, ConstStates.POISONED, attacker, state))


#One weapon hit on a merc: the damage, then the weapon and ammo Inflict rolls.
static func apply_hit(attacker: MercenaryData, defender: MercenaryData, atk: Dictionary, damage: int,
		damage_type: String, state: BattleState, extra_enhancements: int = 0) -> Array[String]:
	var hp_before: int = ExcessPool.hp_total(defender)
	var lines := apply_damage(attacker, defender, damage, damage_type, state, extra_enhancements, false,
		WeaponArmorPerkLibrary.defense_flaws_against(attacker, defender))
	atk["min_1_only"] = last_min_1_only
	_tally_damage(attacker, defender, atk, hp_before)
	lines.append_array(apply_item_inflicts(attacker, defender, atk, hp_before, state))
	return lines


#Counts one attack this merc made, for the perks that scale on attacks made this turn.
static func note_attack(attacker: MercenaryData, target: MercenaryData) -> void:
	if attacker == null:
		return
	attacker.turn_attack_total += 1
	if target != null:
		attacker.turn_attacks[target] = int(attacker.turn_attacks.get(target, 0)) + 1
		target.active_states.erase("pain_fired")
	var weapon: WeaponData = attacker.equipped_weapon
	if weapon != null:
		var key: String = WeaponArmorPerkLibrary.weapon_type_key(weapon)
		if key != "":
			attacker.turn_weapon_attacks[key] = int(attacker.turn_weapon_attacks.get(key, 0)) + 1


#One free attack made outside the reactor's turn: advantage attacks and the perks that copy them.
static func reaction_attack(reactor: MercenaryData, target: MercenaryData, state: BattleState,
		enhancements: int, flaws: int, label: String = "") -> Array[String]:
	var lines: Array[String] = []
	if reactor == null or target == null or not BattleState._is_alive(target):
		return lines
	var react_ep := state_ep_cost(reactor, 1, "reaction")
	if react_ep < 0 or ExcessPool.available_ep(reactor) < react_ep:
		return lines
	var react_paid := ExcessPool.pay_ep(reactor, react_ep)
	state.last_attacked[reactor] = target
	if reactor.equipped_weapon != null and reactor.equipped_weapon.is_ranged:
		state.record_ranged_targeted(target)
	var was_in_reaction: bool = bool(reactor.active_states.get("in_reaction", false))
	reactor.active_states["in_reaction"] = true
	var atk_flaws := flaws + AttackSystem.compute_attack_flaws(reactor, target, state)
	var weapon_enh := AttackSystem.get_weapon_enhance_bonus(reactor)
	var atk := AttackSystem.execute_attack(reactor, enhancements + weapon_enh, atk_flaws, target, false, state)
	note_attack(reactor, target)
	var title: String = label if label != "" else "Advantage Attack"
	lines.append("  %s takes an %s against %s!" % [
		BattleState.colored_name(reactor, state), title, BattleState.colored_name(target, state)])
	if atk.get("misfired", false):
		lines.append("  %s misfires!" % BattleState.colored_name(reactor, state))
	elif atk.get("no_ammo", false) or atk.get("no_los", false):
		lines.append("  %s has no shot!" % BattleState.colored_name(reactor, state))
		ExcessPool.refund_ep(reactor, int(react_paid["from_excess"]), int(react_paid["from_ep"]))
	elif int(atk["damage"]) > 0:
		lines.append_array(apply_hit(reactor, target, atk, atk["damage"], atk["damage_type"], state, enhancements))
	else:
		lines.append("  %s misses %s with the %s." % [
			BattleState.colored_name(reactor, state), BattleState.colored_name(target, state), title])
		lines.append_array(WeaponReactiveSystem.after_attack_resolved(reactor, target, atk, state))
	if not was_in_reaction:
		reactor.active_states.erase("in_reaction")
	return lines


#Damage with no defence roll behind it; label names the perk or effect that dealt it.
static func deal_direct(attacker: MercenaryData, target: MercenaryData, amount: int,
		damage_type: String, state: BattleState, label: String = "") -> Array[String]:
	var lines: Array[String] = []
	if target == null or amount <= 0:
		return lines
	if label != "":
		lines.append("  %s: %s [color=red][%d][/color] %s" % [
			BattleState.colored_name(target, state), label, amount, damage_type])
	lines.append_array(apply_damage(attacker, target, amount, damage_type, state, 0, true))
	return lines


#Records a hit that met the target Tolerance, under the weapon class the attack used.
static func _tally_damage(attacker: MercenaryData, defender: MercenaryData, atk: Dictionary,
		hp_before: int) -> void:
	if attacker == null or defender == null:
		return
	var dealt: int = hp_before - ExcessPool.hp_total(defender)
	atk["damage_dealt"] = maxi(0, dealt)
	if dealt <= 0:
		return
	var kind := "melee"
	if bool(atk.get("is_throw", false)):
		kind = "thrown"
	elif attacker.equipped_weapon != null and attacker.equipped_weapon.is_ranged:
		kind = "ranged"
	LifepathTally.record_damage(attacker, dealt, int(defender.stats.get("tolerance", 0)), kind)


#Weapon and ammo Inflict states rolled once each after a hit that took HP off a living defender.
static func apply_item_inflicts(attacker: MercenaryData, defender: MercenaryData, atk: Dictionary,
		hp_before: int, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null or defender == null:
		return lines
	if ExcessPool.hp_total(defender) >= hp_before or not BattleState._is_alive(defender):
		return lines
	var weapon := attacker.equipped_weapon
	if weapon == null:
		return lines
	var names: Array[String] = []
	for state_name: String in weapon.inflict_states:
		if state_name != "" and not names.has(state_name):
			names.append(state_name)
	if weapon.is_ranged:
		var ammo: AmmoData = DataManager.ammo.get(str(atk.get("ammo_name", "")))
		if ammo != null:
			for state_name: String in ammo.inflict_states:
				if state_name != "" and not names.has(state_name):
					names.append(state_name)
	var toxic_hit := str(atk.get("damage_type", "")) == "Toxic"
	for state_name: String in names:
		if toxic_hit and state_name == ConstStates.POISONED:
			continue
		if ConstStates.has_state(defender, state_name):
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("INFLICT SKIP: %s already %s" % [
					defender.merc_name, state_name])
			continue
		if known_immune(attacker, defender, state_name, "inflict"):
			continue
		lines.append_array(StateInfliction.inflict_default(defender, state_name, attacker, state))
	return lines


static func apply_pain_limit_checks(
		defender: MercenaryData,
		num_checks: int,
		def_name: String) -> Array[String]:
	var lines: Array[String] = []
	var tolerance := clampf(float(defender.stats.get("tolerance", 0.0)), 0.0, 100.0)
	var excess_ap_lost := 0
	var ap_lost := 0
	var excess_ep_lost := 0
	var ep_lost := 0
	var excess_hp_lost := 0
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
			elif ExcessPool.available_ep(defender) > 0:
				var p := ExcessPool.pay_ep(defender, 1)
				excess_ep_lost += int(p["from_excess"])
				ep_lost += int(p["from_ep"])
			else:
				var t := ExcessPool.take_hp(defender, 1)
				excess_hp_lost += int(t["from_excess"])
				hp_lost += int(t["from_hp"])

	var total_failures := excess_ap_lost + ap_lost + excess_ep_lost + ep_lost + excess_hp_lost + hp_lost
	if total_failures == 0:
		lines.append("  %s passes %d pain." % [def_name, num_checks])
	else:
		var lost_parts: Array[String] = []
		if excess_ap_lost > 0: lost_parts.append("%d ExAP" % excess_ap_lost)
		if ap_lost > 0: lost_parts.append("%d AP" % ap_lost)
		if excess_ep_lost > 0: lost_parts.append("%d ExEP" % excess_ep_lost)
		if ep_lost > 0: lost_parts.append("%d EP" % ep_lost)
		if excess_hp_lost > 0: lost_parts.append("%d ExHP" % excess_hp_lost)
		if hp_lost > 0: lost_parts.append("%d HP" % hp_lost)
		lines.append("  %s fails %d/%d pain: -%s." % [
			def_name, total_failures, num_checks, ", ".join(lost_parts)])
	return lines


static func handle_on_kill_perks(
		attacker: MercenaryData, defender: MercenaryData,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null:
		return lines
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
			lines.append("  %s gains %s ReP (Severance)!" % [BattleState.colored_name(attacker, state), val])

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
		#destroy_body is resolved by _try_obliterate before the target ever reaches Dying.
		if kill_effect != "attack_new_target":
			continue
		var kill_ep := state_ep_cost(attacker, 1, "reaction")
		if kill_ep < 0 or ExcessPool.available_ep(attacker) < kill_ep:
			continue
		var nearby := get_enemies_within(attacker, 2, state)
		nearby.erase(defender)
		var new_target: MercenaryData = null
		for cand: MercenaryData in nearby:
			if state.battlefield != null and not (LineOfSight.check(state, attacker, cand)["visible"] as bool):
				continue
			new_target = cand
			break
		if new_target == null:
			continue
		ExcessPool.pay_ep(attacker, kill_ep)
		var was_in_reaction: bool = bool(attacker.active_states.get("in_reaction", false))
		attacker.active_states["in_reaction"] = true
		var atk := AttackSystem.execute_attack(attacker, 0, 0, new_target, false, state)
		note_attack(attacker, new_target)
		lines.append("  %s spends 1 EP (Chain) to attack %s!" % [BattleState.colored_name(attacker, state), BattleState.colored_name(new_target, state)])
		if atk.get("damage", 0) > 0:
			lines.append_array(apply_hit(attacker, new_target, atk, atk["damage"], atk["damage_type"], state))
		else:
			lines.append("  %s misses %s." % [BattleState.colored_name(attacker, state), BattleState.colored_name(new_target, state)])
			lines.append_array(WeaponReactiveSystem.after_attack_resolved(attacker, new_target, atk, state))
		if not was_in_reaction:
			attacker.active_states.erase("in_reaction")

	return lines


static func handle_on_pain_perks(
		attacker: MercenaryData,
		defender: MercenaryData,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null:
		return lines
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
					BattleState.colored_name(defender, state), amt, timing])
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		if perk.effect_dsl.begins_with("reactive_action:on_pain:repeat_pain_response"):
			var pain_ep := state_ep_cost(attacker, 1, "reaction")
			if pain_ep >= 0 and ExcessPool.available_ep(attacker) >= pain_ep:
				ExcessPool.pay_ep(attacker, pain_ep)
				lines.append("  %s spends 1 EP - Pain repeats!" % BattleState.colored_name(attacker, state))
				lines.append_array(apply_pain_limit_checks(defender, 1, BattleState.colored_name(defender, state)))
			break
	return lines


#EP a spend costs after the state multipliers; blocked is returned when a state blocks the spend.
static func state_ep_cost(merc: MercenaryData, base: int, purpose: String, blocked: int = -1) -> int:
	if StateEffects.is_blocked(merc, "spend:ep:" + purpose):
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("EP BLOCKED: %s %s" % [merc.merc_name, purpose])
		return blocked
	var cost := base * StateEffects.cost_multiplier(merc, "ep")
	if base > 0:
		cost += WeaponArmorPerkLibrary.armor_ep_increase(merc)
	if cost != base and EncounterLogger.is_active():
		EncounterLogger.log_verbose("EP COST MOD: %s %s base=%d cost=%d" % [merc.merc_name, purpose, base, cost])
	return cost


#True when the attacker already knows the defender is immune to the state.
static func known_immune(attacker: MercenaryData, defender: MercenaryData, state_name: String, alt: String) -> bool:
	if not BattleState.knows(attacker, defender, "immune:" + StateTokens.normalize_token(state_name)):
		return false
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("IMMUNITY KNOWN: %s skips %s vs %s" % [attacker.merc_name, alt, defender.merc_name])
	return true


#Damage that lands ends the states removed by damage or by their damage type.
static func remove_on_damage(defender: MercenaryData, damage_type: String, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var tag := "effect:tag:" + damage_type.to_lower()
	for state_name: String in defender.active_states.keys():
		if not ConstStates.DATA.has(state_name) or not ConstStates.has_state(defender, state_name):
			continue
		if ConstStates.has_removal(state_name, "damage:"):
			lines.append_array(StateInfliction.remove_timed(defender, state_name, state, "damage", "damage"))
		elif ConstStates.has_removal(state_name, tag):
			lines.append_array(StateInfliction.remove_timed(defender, state_name, state, "effect", damage_type))
	return lines


#Artillery Suppress: the shell suppresses everyone near the target. Build C sets suppress_pending.
static func resolve_suppress(merc: MercenaryData, target: MercenaryData, damage_type: String,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if not bool(merc.active_states.get("suppress_pending", false)):
		return lines
	merc.active_states.erase("suppress_pending")
	if target == null or state == null or state.battlefield == null:
		return lines
	var nearby: Array[MercenaryData] = []
	nearby.append_array(state.get_enemies(merc))
	nearby.append_array(state.get_allies(merc))
	var caught: Array[MercenaryData] = []
	for other: MercenaryData in nearby:
		if other == merc or not BattleState._is_alive(other) or other.off_field:
			continue
		if state.get_floor(other) != state.get_floor(target) or state.distance_to(other, target) > 5:
			continue
		caught.append(other)
	for other: MercenaryData in caught:
		if ExcessPool.hp_total(other) > 2:
			lines.append_array(deal_direct(merc, other, 1, damage_type, state, "Artillery Suppress"))
		else:
			lines.append_array(StateInfliction.inflict_default(other, ConstStates.DEPOSED, merc, state))
	return lines

