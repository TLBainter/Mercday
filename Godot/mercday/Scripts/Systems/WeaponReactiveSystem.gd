class_name WeaponReactiveSystem

#Tokens that sit between the trigger and the verb in a reactive_action DSL string.
const KNOWN_CONDITIONS: PackedStringArray = [
	"any", "surprised", "deposed", "vulnerable", "two_handed",
	"size_5_or_less", "size_gte_self", "size_lte_self", "thrown",
	"within_2", "melee", "intended_range", "once_per_combat", "1hp",
	"size_1_plus",
]

const NO_CELL := Vector3i(-1, -1, -1)



static func fire_trigger(attacker: MercenaryData, trigger: String, target: MercenaryData, atk: Dictionary, state: BattleState, enhancements: int) -> Array[String]:
	return _fire_weapon_reactive(attacker, trigger, target, atk, state, enhancements)


#Extra damage from on_hit perks, added to the hit before defense. Charges 1 EP per perk.
static func on_hit_damage_bonus(
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState,
		lines: Array[String]) -> int:
	if attacker == null or target == null:
		return 0
	var total := 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		var tok := WeaponReactiveDsl.token_for(perk, "on_hit")
		if tok.is_empty() or str(tok["verb"]) != "damage":
			continue
		if not WeaponReactiveDsl.conditions_met(tok["conds"], attacker, target, atk, state, perk):
			continue
		var args: Array = tok["args"]
		var val_str: String = str(args[0]) if args.size() > 0 else "+0"
		var bonus: int = int(target.stats.get("pain_limit", 0)) if val_str == "pain_limit" else int(val_str)
		if bonus <= 0:
			continue
		var paid := _charge_reaction(attacker, perk, target, state)
		if paid.is_empty():
			continue
		_mark_fired(attacker, perk)
		total += bonus
		lines.append("  %s activates %s (+%d damage)!" % [BattleState.colored_name(attacker, state), _perk_label(perk), bonus])
	return total


#Non-damage on_hit reactions, run after the damage has landed.
static func apply_on_hit(
		attacker: MercenaryData,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null or target == null or state == null or state.battlefield == null:
		return lines
	if target.is_dead or target.off_field \
			or (target.current_hp <= 0 and not ConstStates.has_state(target, ConstStates.DYING)):
		return lines
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		var tok := WeaponReactiveDsl.token_for(perk, "on_hit")
		if tok.is_empty():
			continue
		var verb: String = str(tok["verb"])
		if verb == "damage":
			continue
		if not WeaponReactiveDsl.conditions_met(tok["conds"], attacker, target, atk, state, perk):
			continue
		var args: Array = tok["args"]
		var paces: int = maxi(1, int(str(args[0]))) if args.size() > 0 and str(args[0]).is_valid_int() else 1
		match verb:
			"pull_self":
				var self_dest := _pull_destination(attacker, target, paces, state)
				if self_dest == NO_CELL:
					continue
				if _charge_reaction(attacker, perk, target, state).is_empty():
					continue
				_mark_fired(attacker, perk)
				lines.append("  %s closes in with %s!" % [BattleState.colored_name(attacker, state), _perk_label(perk)])
				lines.append_array(_relocate(attacker, self_dest, state))
			"pull_target":
				var tgt_dest := _pull_destination(target, attacker, paces, state)
				if tgt_dest == NO_CELL:
					continue
				if _charge_reaction(attacker, perk, target, state).is_empty():
					continue
				_mark_fired(attacker, perk)
				lines.append("  %s drags %s in with %s!" % [
					BattleState.colored_name(attacker, state), BattleState.colored_name(target, state), _perk_label(perk)])
				lines.append_array(_relocate(target, tgt_dest, state))
			"move_target":
				if _charge_reaction(attacker, perk, target, state).is_empty():
					continue
				_mark_fired(attacker, perk)
				lines.append("  %s activates %s!" % [BattleState.colored_name(attacker, state), _perk_label(perk)])
				lines.append_array(ShoveResolver.lateral_move(attacker, target, paces, state))
			"catch":
				var paid_catch := _charge_reaction(attacker, perk, target, state)
				if paid_catch.is_empty():
					continue
				_mark_fired(attacker, perk)
				lines.append_array(_do_catch(attacker, target, atk, state, perk))
			"attack":
				var paid_atk := _charge_reaction(attacker, perk, target, state)
				if paid_atk.is_empty():
					continue
				_mark_fired(attacker, perk)
				var dtype_arg: String = str(args[0]) if args.size() > 0 else ""
				lines.append_array(_reaction_attack(attacker, target, state, perk,
					int(atk.get("enhancements", 0)), 0, dtype_arg))
			"move_self":
				if _charge_reaction(attacker, perk, target, state).is_empty():
					continue
				_mark_fired(attacker, perk)
				lines.append_array(_shadow_move(attacker, target, state, perk))
			_:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("REACTIVE SKIP: %s %s" % [attacker.merc_name, verb])
	return lines


static func _fire_weapon_reactive(
		attacker: MercenaryData,
		trigger: String,
		target: MercenaryData,
		atk: Dictionary,
		state: BattleState,
		enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null:
		return lines
	if bool(attacker.active_states.get("in_reaction", false)) and trigger == "after_attack":
		return lines
	if trigger == "on_crit":
		lines.append_array(fire_crit_passives(attacker, target, state))
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(attacker):
		var tok := WeaponReactiveDsl.token_for(perk, trigger)
		if tok.is_empty():
			continue
		if not WeaponReactiveDsl.conditions_met(tok["conds"], attacker, target, atk, state, perk):
			continue
		var args: Array = tok["args"]
		var verb: String = str(tok["verb"])
		var react_target: MercenaryData = target
		if verb == "attack_new_target" or verb == "attack_same_target" or verb == "attack" \
				or verb == "throw_attack":
			react_target = _verb_target(attacker, verb, target, state)
		var paid := _charge_reaction(attacker, perk, react_target, state, _verb_needs_target(verb))
		if paid.is_empty():
			continue
		var before := lines.size()
		match verb:
			"damage":
				var val_str: String = str(args[0]) if args.size() > 0 else "+0"
				var bonus: int
				if val_str == "pain_limit":
					bonus = int(react_target.stats.get("pain_limit", 0))
				else:
					bonus = int(val_str)
				if bonus > 0:
					lines.append("  %s activates %s!" % [BattleState.colored_name(attacker, state), _perk_label(perk)])
					lines.append_array(CombatApplicator.deal_direct(attacker, react_target, bonus,
						str(atk.get("damage_type", "Strike")), state, _perk_label(perk)))
			"throw_attack":
				lines.append_array(_reaction_throw(attacker, react_target, state, perk, enhancements))
			"attack_same_target", "attack_new_target", "attack":
				var dmg_mod := 0
				var extra_enh := 0
				var extra_flaws := 0
				var dtype_arg := ""
				for a: String in args:
					var arg := str(a)
					if arg == "strike":
						dtype_arg = "Strike"
					elif arg == "impale":
						dtype_arg = "Impale"
					elif arg == "sonic_above_1":
						dtype_arg = "sonic_above_1"
					elif arg == "+1_enhanced":
						extra_enh += 1
					elif arg == "+1_enhanced_per_attack_this_turn":
						extra_enh += int(attacker.turn_attacks.get(react_target, 0))
					elif arg == "+1_flawed_per_attack_this_turn":
						extra_flaws += _weapon_attacks_this_turn(attacker)
					elif arg == "max_1":
						dmg_mod = -9000
					elif arg.is_valid_int():
						dmg_mod += int(arg)
				var cap: int = 1 if dmg_mod == -9000 else -1
				if cap == 1:
					dmg_mod = 0
				lines.append_array(_reaction_attack(attacker, react_target, state, perk,
					enhancements + extra_enh, extra_flaws, dtype_arg, dmg_mod, cap))
			"reload":
				lines.append_array(WeaponActionExecutor.execute_reload(attacker, state, enhancements, true))
			"convert_to_crit":
				lines.append_array(_convert_to_crit(attacker, react_target, atk, state, perk, enhancements))
			"repeat_pain_response":
				lines.append("  %s spends 1 EP - Pain repeats!" % BattleState.colored_name(attacker, state))
				lines.append_array(CombatApplicator.apply_pain_limit_checks(react_target, 1,
					BattleState.colored_name(react_target, state)))
			"push_target":
				var push_paces: int = maxi(1, int(str(args[0]))) if args.size() > 0 and str(args[0]).is_valid_int() else 1
				if WeaponArmorPerkLibrary.is_level_20(attacker):
					push_paces = 2
				lines.append("  %s activates %s!" % [BattleState.colored_name(attacker, state), _perk_label(perk)])
				lines.append_array(ShoveResolver.forcible_move(attacker, react_target, push_paces, state))
			"swap_places":
				lines.append_array(_swap_places(attacker, react_target, state, perk))
			"reduce_max_hp":
				lines.append_array(_reduce_max_hp(attacker, react_target, atk, state, perk))
			"move_self":
				lines.append_array(_shadow_move(attacker, react_target, state, perk))
			"direct":
				var amount: int = maxi(1, int(str(args[0]))) if args.size() > 0 and str(args[0]).is_valid_int() else 1
				if WeaponArmorPerkLibrary.is_level_20(attacker):
					amount = maxi(amount, 2)
				lines.append_array(CombatApplicator.deal_direct(attacker, react_target, amount,
					_weapon_damage_type(attacker), state, _perk_label(perk)))
			"destroy_body":
				lines.append("  %s spends 1 EP (%s) and destroys the body!" % [
					BattleState.colored_name(attacker, state), _perk_label(perk)])
			"ap_cost_attack":
				var reduce: int = 1
				if args.size() > 0 and str(args[0]).begins_with("-"):
					reduce = maxi(1, absi(int(str(args[0]))))
				attacker.active_states["attack_ap_reduction"] = \
					int(attacker.active_states.get("attack_ap_reduction", 0)) + reduce
				lines.append("  %s activates %s (-%d AP attacks)." % [
					BattleState.colored_name(attacker, state), _perk_label(perk), reduce])
			"spend_rep":
				lines.append_array(_maul_impact(attacker, react_target, atk, state, perk, args))
			"damage_plus_dex":
				var dex: int = int(attacker.stats.get("dexterity", 0))
				if dex > 0:
					lines.append_array(CombatApplicator.deal_direct(attacker, react_target, dex,
						_weapon_damage_type(attacker), state, _perk_label(perk)))
				lines.append_array(CombatApplicator.pain_kill(attacker, react_target, state, _perk_label(perk)))
			"advantage_attack":
				ExcessPool.refund_ep(attacker, int(paid["from_excess"]), int(paid["from_ep"]))
				paid = {}
				lines.append_array(CombatApplicator.reaction_attack(attacker, react_target, state,
					enhancements, 0, _perk_label(perk)))
			"throw":
				lines.append_array(_reaction_throw(attacker, react_target, state, perk, enhancements))
			_:
				if EncounterLogger.is_active():
					EncounterLogger.log_verbose("REACTIVE SKIP: %s %s (unknown_verb)" % [attacker.merc_name, verb])
		if lines.size() == before and not paid.is_empty():
			ExcessPool.refund_ep(attacker, int(paid["from_excess"]), int(paid["from_ep"]))
			if EncounterLogger.is_active():
				EncounterLogger.log_verbose("REACTIVE SKIP: %s %s (no_effect)" % [
					attacker.merc_name, _perk_label(perk)])
			continue
		_mark_fired(attacker, perk)
	return lines


#Hand Ballista Critical: a critical shoves the target, and a failed Vigor check floors it.
static func fire_crit_passives(attacker: MercenaryData, target: MercenaryData,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null or target == null or state == null:
		return lines
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(attacker):
		if not perk.effect_dsl.contains("on_crit:vigor_check:3:shove_2_deposed_on_fail"):
			continue
		var check_def: Dictionary = {"stat_keys": ["vigor"], "circumstances": [], "knowledges": [],
			"tools": [], "formula": "luck", "flat_threshold_bonus": 0.0}
		var roll := CheckSystem.make_check(target, check_def)
		var passed: bool = int(roll["successes"]) >= 3 or bool(roll.get("critical", false))
		lines.append("  %s Vigor %d vs 3 (%s)." % [
			BattleState.colored_name(target, state), int(roll["successes"]), _perk_label(perk)])
		lines.append_array(ShoveResolver.forcible_move(attacker, target, 1 if passed else 2, state))
		if not passed:
			lines.append_array(StateInfliction.inflict_default(target, ConstStates.DEPOSED, attacker, state))
		break
	return lines


#Light Crossbow Shove-Shot: enemies of the shoved merc shoot it as the shove lands.
static func fire_shove_seen(shoved: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if shoved == null or state == null:
		return lines
	for reactor: MercenaryData in state.get_enemies(shoved):
		if not BattleState._is_alive(reactor) or reactor.off_field:
			continue
		lines.append_array(_fire_weapon_reactive(reactor, "on_shove_seen", shoved, {}, state, 0))
	return lines


#Short Sword Deflection: flaws the target adds to an attack aimed at it before the roll.
static func incoming_attack_flaws(attacker: MercenaryData, target: MercenaryData, state: BattleState) -> int:
	if attacker == null or target == null:
		return 0
	target.active_states.erase("deflection_vs")
	if bool(target.active_states.get("in_reaction", false)):
		return 0
	var flaws := 0
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(target):
		var tok := WeaponReactiveDsl.token_for(perk, "on_incoming_attack")
		if tok.is_empty() or str(tok["verb"]) != "flaw_on_attack":
			continue
		if not WeaponReactiveDsl.conditions_met(tok["conds"], target, attacker, {}, state, perk):
			continue
		if _charge_reaction(target, perk, attacker, state).is_empty():
			continue
		_mark_fired(target, perk)
		var amount: int = 2 if WeaponArmorPerkLibrary.is_level_20(target) else 1
		flaws += amount
		target.active_states["deflection_vs"] = attacker
		if EncounterLogger.is_active():
			EncounterLogger.log_verbose("DEFLECTION: %s +%d flaw vs %s" % [
				target.merc_name, amount, attacker.merc_name])
	return flaws


#Short Sword Parry: a melee attack that missed the holder takes direct damage back.
static func after_attack_resolved(attacker: MercenaryData, target: MercenaryData, _atk: Dictionary,
		state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if attacker == null or target == null or not BattleState._is_alive(target):
		return lines
	if bool(target.active_states.get("in_reaction", false)):
		return lines
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_actions(target):
		var tok := WeaponReactiveDsl.token_for(perk, "on_miss_vs_self")
		if tok.is_empty():
			continue
		var conds: Array = tok["conds"]
		if conds.has("melee"):
			var aw: WeaponData = attacker.equipped_weapon
			if aw != null and aw.is_ranged:
				continue
			if state != null and state.battlefield != null \
					and state.distance_to(attacker, target) > WeaponArmorPerkLibrary.get_effective_melee_range(attacker):
				continue
		if str(tok["verb"]) != "direct":
			continue
		var args: Array = tok["args"]
		var amount: int = maxi(1, int(str(args[0]))) if args.size() > 0 and str(args[0]).is_valid_int() else 1
		var free: bool = target.active_states.get("deflection_vs") == attacker
		if not free:
			if _charge_reaction(target, perk, attacker, state).is_empty():
				continue
		_mark_fired(target, perk)
		lines.append_array(CombatApplicator.deal_direct(target, attacker, amount,
			_weapon_damage_type(target), state, _perk_label(perk)))
	target.active_states.erase("deflection_vs")
	return lines


#Shotgun Overcharge: a loaded shell primed for the next shot when an enemy is close enough.
static func fire_on_load(merc: MercenaryData, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if merc == null or state == null:
		return lines
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null or not weapon.is_ranged:
		return lines
	for perk: TraitData in WeaponArmorPerkLibrary.get_weapon_passive_perks(merc):
		if not perk.effect_dsl.contains("on_load:overcharge_option"):
			continue
		var intended: int = int(WeaponArmorPerkLibrary.ranged_ranges(merc, weapon)["intended"])
		if TargetSelector.nearest_visible_enemy(merc, state, intended) == null:
			continue
		merc.active_states["shotgun_overcharged"] = true
		lines.append("  %s overcharges the shell (%s)." % [
			BattleState.colored_name(merc, state), _perk_label(perk)])
		break
	return lines


#The EP a reaction costs, paid through the excess pool; empty when the reaction is refused.
static func _charge_reaction(attacker: MercenaryData, perk: TraitData = null,
		target: MercenaryData = null, state: BattleState = null,
		needs_target: bool = false) -> Dictionary:
	if attacker == null:
		return {}
	var label: String = _perk_label(perk) if perk != null else "reaction"
	if needs_target and target == null:
		_log_skip(attacker, label, "no_target")
		return {}
	var cost := CombatApplicator.state_ep_cost(attacker, 1, "reaction")
	if cost < 0:
		_log_skip(attacker, label, "no_ep")
		return {}
	var available := ExcessPool.available_ep(attacker)
	if available < cost:
		_log_skip(attacker, label, "no_ep")
		return {}
	var verdict := PerkValuation.reaction_worth(attacker, perk, {
		"target": target, "state": state, "cost": cost, "ep_left": available - cost,
		"needs_target": needs_target})
	if not bool(verdict["ok"]):
		_log_skip(attacker, label, str(verdict["reason"]))
		return {}
	return ExcessPool.pay_ep(attacker, cost)


static func _log_skip(attacker: MercenaryData, label: String, reason: String) -> void:
	if EncounterLogger.is_active():
		EncounterLogger.log_verbose("REACTIVE SKIP: %s %s (%s)" % [attacker.merc_name, label, reason])


#A once_per_combat perk is spent for the rest of the fight the moment it fires.
static func _mark_fired(attacker: MercenaryData, perk: TraitData) -> void:
	if attacker == null or perk == null:
		return
	attacker.active_states["perk_once:" + perk.trait_name] = true


#Verbs that have nothing to act on without a target.
static func _verb_needs_target(verb: String) -> bool:
	return verb != "reload" and verb != "ap_cost_attack"


#The creature a reaction attack aims at: the one in hand, else the nearest visible enemy.
static func _verb_target(attacker: MercenaryData, verb: String, target: MercenaryData,
		state: BattleState) -> MercenaryData:
	var reach := TargetSelector.weapon_target_range(attacker)
	if verb == "attack_new_target":
		var best: MercenaryData = null
		var best_d := 9999
		if state == null:
			return null
		for enemy: MercenaryData in state.get_enemies(attacker):
			if enemy == target or not BattleState._is_alive(enemy) or enemy.off_field:
				continue
			if int(attacker.turn_attacks.get(enemy, 0)) > 0:
				continue
			if state.battlefield != null:
				var dist := state.distance_to(attacker, enemy)
				if reach > 0 and dist > reach:
					continue
				if not (LineOfSight.check(state, attacker, enemy)["visible"] as bool):
					continue
				if dist >= best_d:
					continue
				best_d = dist
			best = enemy
		return best
	if target != null and BattleState._is_alive(target) and not target.off_field:
		if state == null or state.battlefield == null:
			return target
		if reach <= 0 or state.distance_to(attacker, target) <= reach:
			return target
	return TargetSelector.nearest_visible_enemy(attacker, state, reach)


#One reaction attack with the perk's modifiers; the in_reaction flag stops it chaining.
static func _reaction_attack(attacker: MercenaryData, target: MercenaryData, state: BattleState,
		perk: TraitData, enhancements: int, flaws: int, dtype_arg: String = "",
		damage_mod: int = 0, damage_cap: int = -1) -> Array[String]:
	var lines: Array[String] = []
	if target == null or not BattleState._is_alive(target):
		return lines
	var was_in_reaction: bool = bool(attacker.active_states.get("in_reaction", false))
	attacker.active_states["in_reaction"] = true
	var weapon_enh := AttackSystem.get_weapon_enhance_bonus(attacker)
	var atk := AttackSystem.execute_attack(attacker, enhancements + weapon_enh, flaws, target, false, state)
	CombatApplicator.note_attack(attacker, target)
	lines.append("  %s reacts with %s against %s!" % [
		BattleState.colored_name(attacker, state), _perk_label(perk), BattleState.colored_name(target, state)])
	if atk.get("no_ammo", false) or atk.get("no_los", false):
		lines.resize(0)
	elif atk.get("misfired", false):
		lines.append("  %s misfires!" % BattleState.colored_name(attacker, state))
	elif int(atk["damage"]) > 0:
		var dealt: int = int(atk["damage"]) + damage_mod
		if damage_cap >= 0:
			dealt = mini(dealt, damage_cap)
		dealt = maxi(0, dealt)
		if dtype_arg == "sonic_above_1" and dealt > 1:
			lines.append_array(CombatApplicator.apply_hit(attacker, target, atk, 1, str(atk["damage_type"]), state))
			if BattleState._is_alive(target):
				lines.append_array(CombatApplicator.apply_damage(attacker, target, dealt - 1, "Sonic", state))
		else:
			var dtype: String = str(atk["damage_type"])
			if dtype_arg != "" and dtype_arg != "sonic_above_1":
				dtype = dtype_arg
			lines.append_array(CombatApplicator.apply_hit(attacker, target, atk, dealt, dtype, state))
	else:
		lines.append("  %s misses %s." % [
			BattleState.colored_name(attacker, state), BattleState.colored_name(target, state)])
		lines.append_array(after_attack_resolved(attacker, target, atk, state))
	if not was_in_reaction:
		attacker.active_states.erase("in_reaction")
	return lines


#A reactive throw: the weapon leaves the hand and lands unless a catch verb brings it back.
static func _reaction_throw(attacker: MercenaryData, target: MercenaryData, state: BattleState,
		perk: TraitData, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	var weapon: WeaponData = attacker.equipped_weapon
	if target == null or weapon == null or not BattleState._is_alive(target):
		return lines
	var was_in_reaction: bool = bool(attacker.active_states.get("in_reaction", false))
	attacker.active_states["in_reaction"] = true
	var atk := AttackSystem.execute_attack(attacker, enhancements, 0, target, true, state)
	CombatApplicator.note_attack(attacker, target)
	var hit: bool = not atk.get("misfired", false) and int(atk["damage"]) > 0
	var dmg: int = int(atk["damage"])
	lines.append("  %s throws %s (%s)!" % [
		BattleState.colored_name(attacker, state), weapon.item_name, _perk_label(perk)])
	if hit:
		var two_handed: int = WeaponArmorPerkLibrary.get_two_handed_damage_bonus(attacker, true)
		lines.append_array(CombatApplicator.apply_hit(attacker, target, atk, dmg + two_handed,
			str(atk["damage_type"]), state))
	else:
		lines.append("  %s misses %s." % [
			BattleState.colored_name(attacker, state), BattleState.colored_name(target, state)])
	attacker.active_states["thrown_weapon_hit"] = hit
	lines.append_array(apply_on_hit(attacker, target, atk, state))
	if attacker.equipped_weapon == weapon and not bool(attacker.active_states.get("weapon_caught", false)):
		lines.append_array(WeaponActionExecutor.empty_main_hand(attacker, state))
		lines.append_array(ThrownWeaponRules.land_thrown_weapon(attacker, weapon, target, hit, dmg, state))
	attacker.active_states.erase("weapon_caught")
	attacker.active_states.erase("thrown_weapon_hit")
	if not was_in_reaction:
		attacker.active_states.erase("in_reaction")
	return lines


#Mallet Rebound: the thrown weapon comes back to a free hand instead of landing.
static func _do_catch(attacker: MercenaryData, target: MercenaryData, atk: Dictionary,
		state: BattleState, perk: TraitData) -> Array[String]:
	var lines: Array[String] = []
	var weapon: WeaponData = attacker.equipped_weapon
	if weapon == null:
		return lines
	attacker.active_states["weapon_caught"] = true
	attacker.weapon_drawn = true
	WeaponArmorPerkLibrary.refresh_held_bonuses(attacker)
	lines.append("  %s catches %s on the rebound (%s)." % [
		BattleState.colored_name(attacker, state), weapon.item_name, _perk_label(perk)])
	lines.append_array(_fire_weapon_reactive(attacker, "on_catch", target, atk, state,
		int(atk.get("enhancements", 0))))
	return lines


#Hand Ballista Threat Elimination: a hit inside 2 paces counts as a critical.
static func _convert_to_crit(attacker: MercenaryData, target: MercenaryData, atk: Dictionary,
		state: BattleState, perk: TraitData, enhancements: int) -> Array[String]:
	var lines: Array[String] = []
	if target == null or bool(atk.get("critical", false)):
		return lines
	atk["critical"] = true
	lines.append("  %s turns the hit critical (%s)!" % [
		BattleState.colored_name(attacker, state), _perk_label(perk)])
	var cr: Dictionary = atk.get("check_result", {})
	var cd: Dictionary = atk.get("check_def", {})
	if not cr.is_empty() and not cd.is_empty():
		CriticalSuccessSystem.on_critical(attacker, cr, cd)
	lines.append_array(_fire_weapon_reactive(attacker, "on_crit", target, atk, state, enhancements))
	return lines


#Short Sword Shift: attacker and target trade cells when both can stand where the other stood.
static func _swap_places(attacker: MercenaryData, target: MercenaryData, state: BattleState,
		perk: TraitData) -> Array[String]:
	var lines: Array[String] = []
	if target == null or state == null or state.battlefield == null:
		return lines
	if state.get_floor(attacker) != state.get_floor(target):
		return lines
	for m: MercenaryData in [attacker, target]:
		if ConstStates.has_state(m, ConstStates.CLIMBING) or ConstStates.has_state(m, ConstStates.GRAPPLED) \
				or state.cave_in_buried.has(m) or PathTargeter.is_flying(m):
			return lines
	var a_pos := state.pos3(attacker)
	var t_pos := state.pos3(target)
	if not PathHelper.is_standable(t_pos, state.battlefield, int(attacker.stats.get("size", 1))):
		return lines
	if not PathHelper.is_standable(a_pos, state.battlefield, int(target.stats.get("size", 1))):
		return lines
	var moved: Array[String] = _relocate(attacker, t_pos, state)
	moved.append_array(_relocate(target, a_pos, state))
	lines.append("  %s shifts places with %s (%s)." % [
		BattleState.colored_name(attacker, state), BattleState.colored_name(target, state), _perk_label(perk)])
	lines.append_array(moved)
	return lines


#Glaive Rend: the damage dealt comes off the target's maximum HP until a furlough.
static func _reduce_max_hp(attacker: MercenaryData, target: MercenaryData, atk: Dictionary,
		state: BattleState, perk: TraitData) -> Array[String]:
	var lines: Array[String] = []
	if target == null:
		return lines
	var dealt: int = int(atk.get("damage_dealt", 0))
	if dealt <= 0:
		return lines
	target.max_hp_penalty += dealt
	StatCalculator.refresh(target)
	lines.append("  %s rends %s: maximum HP -%d (%s)." % [
		BattleState.colored_name(attacker, state), BattleState.colored_name(target, state),
		dealt, _perk_label(perk)])
	return lines


#Colossal Sword Shadow: a free step into reach of the target with no advantage attacks.
static func _shadow_move(attacker: MercenaryData, target: MercenaryData, state: BattleState,
		perk: TraitData) -> Array[String]:
	var lines: Array[String] = []
	if target == null or state == null or state.battlefield == null:
		return lines
	var paces: int = 2 if WeaponArmorPerkLibrary.is_level_20(attacker) else 1
	var dest := _pull_destination(attacker, target, maxi(1, paces * 2), state)
	if dest == NO_CELL:
		return lines
	state.set_pos3(attacker, dest)
	attacker.aim_active = false
	lines.append("  %s shadows %s (%s)." % [
		BattleState.colored_name(attacker, state), BattleState.colored_name(target, state), _perk_label(perk)])
	return lines


#Maul Impact: 3 ReP turns a solid hit into Vigor damage plus a splash on one neighbour.
static func _maul_impact(attacker: MercenaryData, target: MercenaryData, atk: Dictionary,
		state: BattleState, perk: TraitData, args: Array) -> Array[String]:
	var lines: Array[String] = []
	if target == null:
		return lines
	var need: int = 3
	if args.size() > 0 and str(args[0]).is_valid_int():
		need = int(str(args[0]))
	if attacker.current_rep < need:
		return lines
	var dealt: int = int(atk.get("damage_dealt", 0))
	var vigor: int = int(attacker.stats.get("vigor", 0))
	if vigor <= dealt:
		return lines
	attacker.current_rep -= need
	var dtype := _weapon_damage_type(attacker)
	lines.append("  %s drives the blow home (%s, %d ReP)!" % [
		BattleState.colored_name(attacker, state), _perk_label(perk), need])
	lines.append_array(CombatApplicator.deal_direct(attacker, target, vigor - dealt, dtype, state,
		_perk_label(perk)))
	var splash: MercenaryData = null
	var lowest := 99999
	for enemy: MercenaryData in state.get_enemies(attacker):
		if enemy == target or not BattleState._is_alive(enemy) or enemy.off_field:
			continue
		if state.battlefield != null and state.distance_to(target, enemy) > 1:
			continue
		if enemy.current_hp < lowest:
			lowest = enemy.current_hp
			splash = enemy
	if splash != null:
		lines.append_array(CombatApplicator.deal_direct(attacker, splash, 1, dtype, state, _perk_label(perk)))
	return lines


#Attacks the merc already made with the drawn weapon type this turn.
static func _weapon_attacks_this_turn(merc: MercenaryData) -> int:
	var weapon: WeaponData = merc.equipped_weapon
	if weapon == null:
		return 0
	return int(merc.turn_weapon_attacks.get(WeaponArmorPerkLibrary.weapon_type_key(weapon), 0))


static func _weapon_damage_type(merc: MercenaryData) -> String:
	return AttackSystem.damage_type_of(merc.equipped_weapon)


#Moves a pulled merc the way a forcible move does: aim drops and a terrain drop of 1 or more is a fall.
static func _relocate(mover: MercenaryData, dest: Vector3i, state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	var old_pos := state.get_position(mover)
	state.set_pos3(mover, dest)
	mover.aim_active = false
	var drop := state.battlefield.surface_height(old_pos) - state.battlefield.surface_height(Vector2i(dest.x, dest.y))
	if drop >= 1.0:
		lines.append_array(CombatApplicator.resolve_fall(mover, int(floor(drop)), state))
	return lines


#Nearest free cell adjacent to anchor that the mover can reach in max_paces, or NO_CELL.
static func _pull_destination(
		mover: MercenaryData,
		anchor: MercenaryData,
		max_paces: int,
		state: BattleState) -> Vector3i:
	var field: BattlefieldArea = state.battlefield
	if field == null or ConstStates.has_state(mover, ConstStates.CLIMBING):
		return NO_CELL
	var floor_num := state.get_floor(anchor)
	if state.get_floor(mover) != floor_num:
		return NO_CELL
	var anchor_pos := state.get_position(anchor)
	var from := state.get_position(mover)
	if maxi(abs(anchor_pos.x - from.x), abs(anchor_pos.y - from.y)) <= 1:
		return NO_CELL
	var best := NO_CELL
	var best_d := 9999
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var cell := anchor_pos + Vector2i(dx, dy)
			if field.clamp_position(cell) != cell:
				continue
			var dist := maxi(abs(cell.x - from.x), abs(cell.y - from.y))
			if dist == 0 or dist > max_paces or dist >= best_d:
				continue
			var obs := field.get_obstacle_at_3d(Vector3i(cell.x, cell.y, floor_num))
			if not obs.is_empty():
				var od: ObstacleData = obs.get("data") as ObstacleData
				if od == null or not od.passthrough:
					continue
			if state.is_position_occupied(cell, mover, floor_num):
				continue
			best = Vector3i(cell.x, cell.y, floor_num)
			best_d = dist
	return best


static func _perk_label(perk: TraitData) -> String:
	if perk == null:
		return "reaction"
	var pieces := perk.trait_name.split("|")
	return pieces[pieces.size() - 1]
